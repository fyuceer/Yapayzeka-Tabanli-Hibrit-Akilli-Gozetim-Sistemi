from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
import asyncio, json, threading, time, base64
import numpy as np
import torch
import cv2
from collections import deque
from ultralytics import YOLO
from tensorflow.keras.models import load_model
import os
from pathlib import Path
from dotenv import load_dotenv
# ──────────────────────────────────────────────────────────────
#  AYARLAR
# ──────────────────────────────────────────────────────────────
ENV_PATH = Path(__file__).resolve().parent.parent / ".env"
load_dotenv(ENV_PATH)

API_TOKEN = os.getenv("API_TOKEN")

if not API_TOKEN:
    raise RuntimeError("API_TOKEN ana dizindeki .env dosyasında bulunamadı!")

WEAPON_MODEL_PATH = "best_yolov5.pt"
POSE_MODEL_PATH   = "yolov8n-pose.pt"
LSTM_MODEL_PATH   = "en_iyi_saldiri_modeli.keras"

CONF_WEAPON    = 0.60
CONF_POSE      = 0.60
SALDIRI_ESIGI  = 0.60
SEQUENCE_LEN   = 30
POSE_SKIP      = 2
IOU_ESIGI      = 0.25
KAYIP_ESIGI    = 15
CAM_W, CAM_H   = 1280, 720

# Görsel kalitesi — düşük tut ki WebSocket'i tıkamayalım
JPEG_QUALITY   = 50

# ──────────────────────────────────────────────────────────────
#  FASTAPI
# ──────────────────────────────────────────────────────────────
app = FastAPI()
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

connected_clients: list[WebSocket] = []

async def broadcast(data: dict):
    message = json.dumps(data, ensure_ascii=False)
    disconnected = []
    for ws in connected_clients:
        try:
            await ws.send_text(message)
        except Exception:
            disconnected.append(ws)
    for ws in disconnected:
        if ws in connected_clients:
            connected_clients.remove(ws)

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    token = websocket.query_params.get("token")
    if token != API_TOKEN:
        await websocket.close(code=1008)
        return
    await websocket.accept()
    connected_clients.append(websocket)
    print(f"Istemci baglandi. Toplam: {len(connected_clients)}")
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        if websocket in connected_clients:
            connected_clients.remove(websocket)
        print(f"Istemci ayrildi. Kalan: {len(connected_clients)}")

@app.get("/status")
def status():
    return {"status": "aktif", "clients": len(connected_clients)}

# ──────────────────────────────────────────────────────────────
#  PAYLAŞILAN DURUM
# ──────────────────────────────────────────────────────────────
shared_state = {
    "weapon_detected": False,
    "davranis_alarm":  False,
    "tehditler":       [],
    "saldiri_skoru":   0.0,
    "fps":             0.0,
}
state_lock = threading.Lock()

# ──────────────────────────────────────────────────────────────
#  TRACKER
# ──────────────────────────────────────────────────────────────
class TrackerYoneticisi:
    def __init__(self):
        self.izlenenler = []

    @staticmethod
    def _iou(a, b):
        ax2, ay2 = a[0]+a[2], a[1]+a[3]
        bx2, by2 = b[0]+b[2], b[1]+b[3]
        ix = max(0, min(ax2, bx2) - max(a[0], b[0]))
        iy = max(0, min(ay2, by2) - max(a[1], b[1]))
        inter = ix * iy
        if inter == 0:
            return 0.0
        return inter / (a[2]*a[3] + b[2]*b[3] - inter)

    @staticmethod
    def _to_xywh(x1, y1, x2, y2):
        return (int(x1), int(y1), int(x2-x1), int(y2-y1))

    def guncelle(self, frame, yolo_tespitler):
        canli = []
        for iz in self.izlenenler:
            ok, bbox = iz["tracker"].update(frame)
            if ok:
                iz["bbox"] = (int(bbox[0]), int(bbox[1]),
                              int(bbox[2]), int(bbox[3]))
                canli.append(iz)
        self.izlenenler = canli

        yeni = [self._to_xywh(*d[:4]) + (d[4],) for d in yolo_tespitler]
        eslesilen = set()

        for iz in self.izlenenler:
            en_iou, en_i = 0.0, -1
            for i, (nx, ny, nw, nh, _) in enumerate(yeni):
                iou = self._iou(iz["bbox"], (nx, ny, nw, nh))
                if iou > en_iou:
                    en_iou, en_i = iou, i

            if en_iou >= IOU_ESIGI and en_i not in eslesilen:
                nx, ny, nw, nh, nlabel = yeni[en_i]
                iz["tracker"] = cv2.legacy.TrackerCSRT_create()
                iz["tracker"].init(frame, (nx, ny, nw, nh))
                iz["bbox"]       = (nx, ny, nw, nh)
                iz["label"]      = nlabel
                iz["yolo_kayip"] = 0
                eslesilen.add(en_i)
            elif en_iou > 0 and en_i not in eslesilen:
                iz["label"] = yeni[en_i][4]
                iz["yolo_kayip"] += 1
            else:
                iz["yolo_kayip"] += 1

        self.izlenenler = [iz for iz in self.izlenenler
                           if iz["yolo_kayip"] < KAYIP_ESIGI]

        for i, (nx, ny, nw, nh, nlabel) in enumerate(yeni):
            if i not in eslesilen:
                t = cv2.legacy.TrackerCSRT_create()
                t.init(frame, (nx, ny, nw, nh))
                self.izlenenler.append({
                    "tracker":    t,
                    "bbox":       (nx, ny, nw, nh),
                    "label":      nlabel,
                    "yolo_kayip": 0,
                })

        return [(*iz["bbox"], iz["label"]) for iz in self.izlenenler]

# ──────────────────────────────────────────────────────────────
#  FRAME → BASE64
# ──────────────────────────────────────────────────────────────
def frame_to_b64(frame: np.ndarray) -> str:
    """Frame'i küçült ve JPEG base64'e çevir."""
    small = cv2.resize(frame, (640, 360))
    _, buf = cv2.imencode('.jpg', small,
                          [cv2.IMWRITE_JPEG_QUALITY, JPEG_QUALITY])
    return base64.b64encode(buf).decode('utf-8')

# ──────────────────────────────────────────────────────────────
#  KAMERA THREAD
# ──────────────────────────────────────────────────────────────
def kamera_thread(loop: asyncio.AbstractEventLoop):
    torch.backends.cudnn.benchmark = True
    device   = "cuda" if torch.cuda.is_available() else "cpu"
    use_half = device == "cuda"

    weapon_model = YOLO(WEAPON_MODEL_PATH)
    pose_model   = YOLO(POSE_MODEL_PATH)
    weapon_model.to(device)
    pose_model.to(device)

    lstm_model = load_model(LSTM_MODEL_PATH)
    lstm_model(np.zeros((1, SEQUENCE_LEN, 34), dtype=np.float32), training=False)

    cap = cv2.VideoCapture(0, cv2.CAP_DSHOW)
    cap.set(cv2.CAP_PROP_FRAME_WIDTH,  CAM_W)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, CAM_H)

    sequence_deque = deque(maxlen=SEQUENCE_LEN)
    lstm_sonuc     = {"skor": 0.0, "alarm": False}
    lstm_lock      = threading.Lock()
    stop_lstm      = threading.Event()
    tracker_yon    = TrackerYoneticisi()
    frame_count    = 0

    # Son tehdit anındaki görsel — sadece tehdit varken gönder
    last_threat_frame_b64 = None
    prev_weapon           = False

    def lstm_fn():
        while not stop_lstm.is_set():
            if len(sequence_deque) == SEQUENCE_LEN:
                data = np.expand_dims(np.array(sequence_deque), axis=0)
                skor = float(lstm_model(data, training=False)[0][0])
                with lstm_lock:
                    lstm_sonuc["skor"]  = skor
                    lstm_sonuc["alarm"] = skor > SALDIRI_ESIGI
            else:
                time.sleep(0.01)

    threading.Thread(target=lstm_fn, daemon=True).start()
    print("Kamera thread baslatildi.")

    while cap.isOpened():
        ret, frame = cap.read()
        if not ret:
            break

        t0 = time.perf_counter()
        frame_count += 1

        # ── Silah tespiti ──────────────────────────────────────
        w_results = weapon_model.predict(
            source=frame, imgsz=640, conf=CONF_WEAPON,
            verbose=False, device=device, half=use_half,
        )

        yolo_tespitler = []
        for r in w_results:
            for box in r.boxes:
                x1, y1, x2, y2 = map(float, box.xyxy[0])
                label = weapon_model.names[int(box.cls[0])]
                conf  = float(box.conf[0])
                yolo_tespitler.append((x1, y1, x2, y2,
                                       f"{label} %{int(conf*100)}"))

        aktif           = tracker_yon.guncelle(frame, yolo_tespitler)
        weapon_detected = len(aktif) > 0
        tehditler       = [t[4] for t in aktif]

        # ── Tehdit anı görselini yakala ────────────────────────
        # Silah ilk kez göründüğü anda frame'i kaydet
        if weapon_detected and not prev_weapon:
            last_threat_frame_b64 = frame_to_b64(frame)
        if not weapon_detected:
            last_threat_frame_b64 = None
        prev_weapon = weapon_detected

        # ── Pose ──────────────────────────────────────────────
        if frame_count % POSE_SKIP == 0:
            p_results = pose_model.predict(
                source=frame, imgsz=640, conf=CONF_POSE,
                verbose=False, device=device, half=use_half,
            )
            for r in p_results:
                if r.keypoints is not None and len(r.keypoints.xyn) > 0:
                    kp = r.keypoints.xyn[0].cpu().numpy().flatten()
                    coords = kp if len(kp) == 34 else np.zeros(34, dtype=np.float32)
                    sequence_deque.append(coords)
                    break

        with lstm_lock:
            davranis_alarm = lstm_sonuc["alarm"]
            skor           = lstm_sonuc["skor"]

        fps = 1.0 / max(time.perf_counter() - t0, 1e-6)

        # ── Ekran görselleştirmesi ─────────────────────────────
        display = frame.copy()

        # Tracker kutuları — köşe çizgileri
        for (x, y, w_box, h_box, label) in aktif:
            x2, y2 = x + w_box, y + h_box
            k = min(w_box, h_box) // 5
            renk = (0, 0, 255) if davranis_alarm else (0, 200, 255)
            for (cx, cy, dx, dy) in [
                (x, y, 1, 1), (x2, y, -1, 1),
                (x, y2, 1, -1), (x2, y2, -1, -1)
            ]:
                cv2.line(display, (cx, cy), (cx + dx * k, cy), renk, 3)
                cv2.line(display, (cx, cy), (cx, cy + dy * k), renk, 3)
            cv2.putText(display, f"[TAKIP] {label}",
                        (x, y - 10), cv2.FONT_HERSHEY_SIMPLEX,
                        0.65, renk, 2, cv2.LINE_AA)

        # Üst bilgi şeridi
        overlay = display.copy()
        cv2.rectangle(overlay, (0, 0), (CAM_W, 70), (0, 0, 0), -1)
        cv2.addWeighted(overlay, 0.5, display, 0.5, 0, display)

        # Durum yazısı
        if weapon_detected and davranis_alarm:
            durum      = "!! CIFTE ALARM: NESNE + SALDIRI !!"
            renk_yazi  = (0, 0, 255)
        elif weapon_detected:
            durum      = "ALARM: TEHLIKELI NESNE"
            renk_yazi  = (0, 140, 255)
        elif davranis_alarm:
            durum      = "ALARM: SALDIRGAN DAVRANIS"
            renk_yazi  = (0, 140, 255)
        else:
            durum      = "SISTEM: GUVENLI"
            renk_yazi  = (0, 210, 0)

        cv2.putText(display, durum, (15, 45),
                    cv2.FONT_HERSHEY_DUPLEX, 0.9, renk_yazi, 2, cv2.LINE_AA)
        cv2.putText(display, f"FPS:{int(fps)}  Skor:{skor:.2f}",
                    (CAM_W - 230, 45),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.75, (255, 255, 0), 2, cv2.LINE_AA)

        # Kenar çerçeve
        c_renk = (0, 0, 255) if (weapon_detected or davranis_alarm) else (0, 210, 0)
        c_k    = 8 if (weapon_detected or davranis_alarm) else 3
        cv2.rectangle(display, (0, 0), (CAM_W - 1, CAM_H - 1), c_renk, c_k)

        cv2.imshow("Hibrit Guvenlik Sistemi - Kamera", display)
        if cv2.waitKey(1) & 0xFF == ord("q"):
            break

        with state_lock:
            shared_state["weapon_detected"] = weapon_detected
            shared_state["davranis_alarm"]  = davranis_alarm
            shared_state["tehditler"]       = tehditler
            shared_state["saldiri_skoru"]   = round(skor, 2)
            shared_state["fps"]             = round(fps, 1)

        # ── Payload ────────────────────────────────────────────
        payload = {
            "weapon_detected":  weapon_detected,
            "davranis_alarm":   davranis_alarm,
            "tehditler":        tehditler,
            "saldiri_skoru":    round(skor, 2),
            "fps":              round(fps, 1),
            "timestamp":        time.strftime("%H:%M:%S"),
            # Görsel: sadece tehdit ilk kez ortaya çıktığında
            "threat_frame":     last_threat_frame_b64
                                if (weapon_detected and not prev_weapon is False)
                                else None,
        }

        asyncio.run_coroutine_threadsafe(broadcast(payload), loop)

    cap.release()
    cv2.destroyAllWindows()
    stop_lstm.set()
    print("Kamera durdu.")

# ──────────────────────────────────────────────────────────────
#  STARTUP
# ──────────────────────────────────────────────────────────────
@app.on_event("startup")
async def startup_event():
    loop = asyncio.get_event_loop()
    threading.Thread(target=kamera_thread, args=(loop,), daemon=True).start()

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)