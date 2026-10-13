# Yapay Zekâ Tabanlı Hibrit Akıllı Gözetim Sistemi

### TÜBİTAK 2209-A Destekli Bitirme Projesi

Gerçek zamanlı güvenlik kamerası görüntülerini analiz ederek tehlikeli nesneleri ve şüpheli davranışları tespit etmeyi amaçlayan, bilgisayarlı görü ve derin öğrenme tabanlı hibrit bir akıllı gözetim sistemi.

<p align="center">
  <strong>Computer Vision</strong> · <strong>Deep Learning</strong> · <strong>YOLO</strong> · <strong>LSTM</strong> · <strong>Flutter</strong> · <strong>FastAPI</strong>
</p>

---

## 📌 Proje Hakkında

Geleneksel güvenlik sistemleri çoğunlukla kamera görüntülerinin insan operatörler tarafından sürekli izlenmesine dayanır. Bu yaklaşım, uzun süreli izleme sırasında dikkat kaybına ve kritik olayların geç fark edilmesine neden olabilir.

Bu proje kapsamında, güvenlik kamerası görüntülerini gerçek zamanlı analiz ederek potansiyel tehditleri otomatik olarak tespit etmeyi amaçlayan **Yapay Zekâ Tabanlı Hibrit Akıllı Gözetim Sistemi** geliştirilmiştir.

Sistem, nesne tespiti ve davranış analizi modüllerini bir araya getirir. Python tabanlı yapay zekâ altyapısı, FastAPI üzerinden Flutter arayüzüyle haberleşir. Böylece tespit edilen tehditlerin operatör ekranında görüntülenmesi ve olayların takip edilmesi hedeflenir.

Proje, **TÜBİTAK 2209-A Üniversite Öğrencileri Araştırma Projeleri Destekleme Programı** kapsamında desteklenmiştir.

## 🎯 Projenin Amaçları

* Güvenlik kamerası görüntülerinden tehlikeli nesneleri tespit etmek.
* İnsanların iskelet ve hareket bilgilerini analiz ederek saldırı davranışlarını sınıflandırmak.
* Görüntü işleme ve derin öğrenme yöntemlerini tek bir hibrit sistemde birleştirmek.
* Tespit edilen tehditleri operatör arayüzüne gerçek zamanlı olarak iletmek.
* Güvenlik operatörlerinin olayları daha hızlı değerlendirmesine yardımcı olmak.
* İnsan gözetimine duyulan bağımlılığı azaltmaya yönelik bir prototip geliştirmek.

## 🧠 Sistem Mimarisi

Sistem iki temel yapay zekâ modülünden ve bu modüllerle iletişim kuran bir yazılım altyapısından oluşur.

```text
              GÜVENLİK KAMERASI
                      │
                      ▼
             GERÇEK ZAMANLI GÖRÜNTÜ
                      │
             ┌────────┴────────┐
             ▼                 ▼
     NESNE TESPİTİ       DAVRANIŞ ANALİZİ
       YOLOv5m             YOLO-Pose
             │                 │
     Silah / Bıçak       İskelet Anahtar
         Tespiti          Noktaları (17)
             │                 │
             │                 ▼
             │           Zamansal Özellikler
             │                 │
             │                 ▼
             │                LSTM
             │                 │
             │          Saldırı Sınıflandırma
             │                 │
             └────────┬────────┘
                      ▼
               TEHDİT DEĞERLENDİRME
                      │
                      ▼
               PYTHON + FASTAPI
                      │
                   WebSocket
                      │
                      ▼
                FLUTTER ARAYÜZÜ
                      │
                      ▼
             OPERATÖR BİLDİRİMİ
```

*Not: Diyagram, sistemin kavramsal işleyişini göstermektedir. Gerçek çalışma akışı, uygulamadaki entegrasyon ve tehdit değerlendirme mantığına bağlıdır.*

## 🔍 Temel Modüller

### 1. Tehlikeli Nesne Tespiti

Güvenlik kamerası görüntülerinde silah ve bıçak gibi tehlikeli nesnelerin tespit edilmesi için YOLO tabanlı nesne tespit yaklaşımı kullanılmıştır.

**Kullanılan teknolojiler:**

* YOLOv5m
* OpenCV
* PyTorch
* Python

**Modülün işlevleri:**

* Kamera görüntülerinin gerçek zamanlı işlenmesi
* Tehlikeli nesnelerin tespit edilmesi
* Tespit sonuçlarının sınıf ve güven skoru ile değerlendirilmesi
* Tehdit içeren görüntülerin arayüze aktarılmasına altyapı sağlanması

### 2. Saldırı Davranışı Analizi

İnsan hareketlerinin zamansal özelliklerini analiz ederek saldırı davranışlarını sınıflandırmak amacıyla YOLO-Pose ve LSTM modelleri bir arada kullanılmıştır.

**Kullanılan teknolojiler:**

* YOLOv8n-Pose
* LSTM
* TensorFlow / Keras
* NumPy
* Python

**Çalışma prensibi:**

1. YOLO-Pose ile görüntüdeki kişilerin iskelet anahtar noktaları tespit edilir.
2. COCO formatındaki 17 vücut anahtar noktasının normalize edilmiş X ve Y koordinatları çıkarılır.
3. Her kişi için toplam 34 koordinat değerinden oluşan özellik vektörleri hazırlanır.
4. Ardışık karelerden elde edilen özellikler zamansal diziler hâline getirilir.
5. LSTM modeli, hareketlerin zaman içindeki değişimini analiz ederek saldırı davranışını sınıflandırır.

Bu yaklaşım, tek bir karedeki görüntü özelliklerinin yanı sıra hareketin zamansal örüntülerini de değerlendirmeyi amaçlar.

### 3. Gerçek Zamanlı İletişim ve Operatör Arayüzü

Yapay zekâ modellerinin sonuçları Python tabanlı backend üzerinden Flutter arayüzüne iletilir.

**Backend:**

* Python
* FastAPI
* WebSocket
* OpenCV
* JSON tabanlı veri aktarımı

**Frontend:**

* Flutter
* Dart
* WebSocket iletişimi
* fl_chart ile grafikler
* Gerçek zamanlı olay ve tehdit gösterimi

Backend, kamera görüntülerini işleyerek tespit sonuçlarını üretir ve WebSocket üzerinden istemciye iletir. Flutter arayüzü ise gelen olayların operatör tarafından takip edilmesini sağlar.

Arayüzde tehdit bilgileri, olay kayıtları ve sistem durumunun görselleştirilmesi hedeflenmiştir.

## 📊 Deneysel Sonuçlar

Proje kapsamında gerçekleştirilen deneylerde aşağıdaki sonuçlar elde edilmiştir:

| Modül                           | Model / Yöntem   |                       Sonuç |
| ------------------------------- | ---------------- | --------------------------: |
| Tehlikeli nesne tespiti         | YOLOv5m          |                %88,1 mAP@50 |
| Saldırı davranışı sınıflandırma | YOLO-Pose + LSTM | %73 sınıflandırma doğruluğu |

### Sonuçların Değerlendirilmesi

* **Tehlikeli nesne tespiti:** YOLOv5m modeliyle silah ve bıçak tespitine yönelik deneylerde %88,1 mAP@50 sonucu elde edilmiştir.
* **Davranış analizi:** YOLO-Pose ile çıkarılan iskelet özelliklerinin LSTM modeliyle zamansal analizi sonucunda saldırı davranışı sınıflandırmasında %73 doğruluk elde edilmiştir.

Bu sonuçlar, geliştirilen iki modülün ilgili deney koşullarındaki performansını göstermektedir. Gerçek saha performansı; kamera açısı, aydınlatma, nesne boyutu, örtülme, hareket çeşitliliği ve veri setinin temsil gücü gibi faktörlerden etkilenebilir.

> **Değerlendirme notu:** mAP@50 ve sınıflandırma doğruluğu farklı performans ölçütleridir. Bu değerler doğrudan birbirleriyle karşılaştırılmamalıdır.

## 🛠️ Kullanılan Teknolojiler

| Alan                      | Teknolojiler                |
| ------------------------- | --------------------------- |
| Programlama dilleri       | Python, Dart                |
| Nesne tespiti             | YOLOv5m                     |
| Poz tahmini               | YOLOv8n-Pose                |
| Zamansal davranış analizi | LSTM                        |
| Derin öğrenme             | PyTorch, TensorFlow / Keras |
| Görüntü işleme            | OpenCV                      |
| Backend API               | FastAPI                     |
| Gerçek zamanlı iletişim   | WebSocket                   |
| Kullanıcı arayüzü         | Flutter                     |
| Grafikler                 | fl_chart                    |
| Veri işleme               | NumPy, Pandas               |

## 📁 Proje Yapısı

```text
akilli-gozetim-sistemi/
│
├── flutter_app/
│   ├── lib/
│   │   └── main.dart
│   ├── web/
│   │   ├── icons/
│   │   ├── favicon.png
│   │   ├── index.html
│   │   └── manifest.json
│   └── pubspec.yaml
│
├── python_backend/
│   ├── hibrit.py
│   └── requirements.txt
│
├── .env.example
└── .gitignore
```

**Not:** Eğitilmiş model dosyaları (`.pt`, `.keras` vb.) ve gerçek ortam değişkenlerini içeren `.env` dosyası Git deposuna eklenmemiştir. Model dosyalarının, projeyi yerel ortamda çalıştırmadan önce uygun konumlara yerleştirilmesi gerekir.

## ⚙️ Kurulum

### Gereksinimler

* Python
* Flutter SDK
* Dart SDK (Flutter ile birlikte gelir)
* Git
* Bilgisayarda kullanılabilir bir kamera
* Projede kullanılan eğitilmiş model dosyaları

Kütüphane sürümleri, işletim sistemi ve donanım özellikleri çalıştırma ortamını etkileyebilir.

### 1. Depoyu klonlayın

```bash
git clone https://github.com/fyuceer/Yapayzeka-Tabanli-Hibrit-Akilli-Gozetim-Sistemi.git
cd Yapayzeka-Tabanli-Hibrit-Akilli-Gozetim-Sistemi
```

### 2. Python ortamını hazırlayın

Proje ana klasöründeyken sanal ortam oluşturun:

```bash
python -m venv .venv
```

Windows üzerinde sanal ortamı etkinleştirin:

```powershell
.venv\Scripts\Activate.ps1
```

CMD kullanıyorsanız:

```cmd
.venv\Scripts\activate.bat
```

Backend bağımlılıklarını yükleyin:

```bash
pip install -r python_backend/requirements.txt
```

### 3. Ortam değişkenlerini yapılandırın

Proje ana dizinindeki `.env.example` dosyasını `.env` adıyla kopyalayın.

Windows CMD:

```cmd
copy .env.example .env
```

`.env` dosyasını açarak `API_TOKEN` değişkenine kendi token değerinizi girin:

```env
API_TOKEN=KENDI_TOKEN_DEGERINIZ
```

Gerçek token'ınızı GitHub'a yüklemeyin veya herkese açık biçimde paylaşmayın.

### 4. Model dosyalarını yerleştirin

Gerekli eğitilmiş modelleri `python_backend/` klasörüne yerleştirin:

```text
python_backend/
├── hibrit.py
├── requirements.txt
├── best_yolov5.pt
├── yolov8n-pose.pt
└── en_iyi_saldiri_modeli.keras
```

Model dosyalarının projede belirtilen adlarla ve beklenen konumlarda bulunması gerekir.

### 5. Backend'i başlatın

Proje ana klasöründen:

```bash
python python_backend/hibrit.py
```

Backend'in kullandığı kamera, model yolları ve ortam değişkenleri doğru yapılandırılmış olmalıdır.

> **Not:** Bu komutun çalışması, `hibrit.py` dosyasındaki başlatma yapılandırmasının ve bağımlılıkların mevcut ortamla uyumlu olmasına bağlıdır.

### 6. Flutter bağımlılıklarını yükleyin

Yeni bir terminal açarak Flutter klasörüne geçin:

```bash
cd flutter_app
flutter pub get
```

### 7. Flutter uygulamasını başlatın

Backend'in çalıştığından emin olduktan sonra, Flutter Web uygulamasını şu komutla başlatabilirsiniz:

```bash
flutter run -d chrome --dart-define=API_TOKEN=KENDI_TOKEN_DEGERINIZ
```

`KENDI_TOKEN_DEGERINIZ` yerine `.env` dosyasındaki token ile aynı değeri kullanın.

**Bağlantı notu:** Mevcut Flutter yapılandırmasında `localhost:8000` adresi kullanılıyorsa frontend ve backend aynı bilgisayarda çalışmalıdır. Uzak sunucuya dağıtım için WebSocket adresinin ayrıca yapılandırılması gerekir. Flutter Web uygulamalarında istemciye verilen token gizli tutulamaz; bu nedenle üretim ortamlarında erişim denetimi ve kimlik doğrulama tasarımı ayrıca ele alınmalıdır.

## 🔐 Güvenlik ve Gizlilik

* `.env` dosyası `.gitignore` ile Git takibinin dışında tutulur.
* Eğitilmiş model dosyaları (`.pt`, `.keras`, `.h5`, `.onnx` vb.) depoya eklenmez.
* Gerçek token değerleri kaynak kodlarda saklanmamalıdır.
* Flutter Web uygulamasında kullanılan token'ın kullanıcı tarafından incelenebilir olabileceği dikkate alınmalıdır.
* Gerçek ortamlarda HTTPS/WSS, güvenli kimlik doğrulama, erişim yetkilendirmesi ve uygun CORS politikaları kullanılmalıdır.
* Kamera görüntüleri ve güvenlik kayıtları işlenirken ilgili gizlilik ve veri koruma gerekliliklerine uyulmalıdır.

## 🚧 Sınırlılıklar ve Gelecek Çalışmalar

Sistemin daha geniş kullanım senaryolarına uyarlanabilmesi için aşağıdaki geliştirmeler değerlendirilebilir:

* Farklı kamera açıları, aydınlatma koşulları ve kalabalık ortamlarda testlerin genişletilmesi
* Davranış analizi veri setinin çeşitlendirilmesi
* Saldırı sınıflandırma performansının iyileştirilmesi
* Gerçek zamanlı performans ve gecikme ölçümlerinin yapılması
* Yanlış pozitif ve yanlış negatif tespitlerin analiz edilmesi
* Model çıkarım süresinin ve kaynak tüketiminin ölçülmesi
* Operatör bildirim mekanizmasının ve olay geçmişinin geliştirilmesi
* Kimlik doğrulama ve dağıtım güvenliğinin güçlendirilmesi


## 👩‍💻 Geliştirici

**FeyzaSultanYüceer**

GitHub: [@fyuceer](https://github.com/fyuceer)

---

*Bu proje, yapay zekâ ve bilgisayarlı görü yöntemlerinin akıllı güvenlik sistemlerinde kullanımını araştırmak ve gerçek zamanlı tehdit analizine yönelik bir prototip geliştirmek amacıyla hazırlanmıştır.*
