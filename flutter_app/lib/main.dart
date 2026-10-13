import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

// pubspec.yaml:
// fl_chart: ^0.68.0
// web_socket_channel: ^2.4.0
// intl: ^0.19.0

void main() {
  runApp(const SecurityApp());
}

// ──────────────────────────────────────────────────────────────
//  SES ALARMI
// ──────────────────────────────────────────────────────────────
void _playAlarm() {
  try {
    js.context.callMethod('eval', [
      '''
      (function() {
        var ctx = new (window.AudioContext || window.webkitAudioContext)();
        function bip(freq, start, dur) {
          var o = ctx.createOscillator();
          var g = ctx.createGain();
          o.connect(g); g.connect(ctx.destination);
          o.frequency.value = freq; o.type = "square";
          g.gain.setValueAtTime(0.3, ctx.currentTime + start);
          g.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + start + dur);
          o.start(ctx.currentTime + start);
          o.stop(ctx.currentTime + start + dur);
        }
        bip(880,0.0,0.15); bip(660,0.2,0.15);
        bip(880,0.4,0.15); bip(660,0.6,0.15); bip(880,0.8,0.3);
      })();
    ''',
    ]);
  } catch (_) {}
}

// ──────────────────────────────────────────────────────────────
//  MOD
// ──────────────────────────────────────────────────────────────
enum SistemModu { yariOtonom, tamOtonom }

class SecurityApp extends StatelessWidget {
  const SecurityApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Akilli Guvenlik Sistemi',
      theme: ThemeData(
        fontFamily: 'Arial',
        scaffoldBackgroundColor: const Color(0xFF07152B),
      ),
      home: const DashboardPage(),
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  SABİTLER
// ──────────────────────────────────────────────────────────────
const String API_TOKEN = String.fromEnvironment('API_TOKEN');
const String WS_URL = 'ws://localhost:8000/ws?token=$API_TOKEN';

const String CAM_LABEL = 'KAMERA-01';

// ──────────────────────────────────────────────────────────────
//  MODEL
// ──────────────────────────────────────────────────────────────
enum ThreatClass { silah, bicak, saldiri, kisi }

class SecurityEvent {
  final String id;
  final ThreatClass type;
  final String camera;
  final String confidence;
  final double confidenceScore;
  final DateTime timestamp;
  final Color color;
  final Uint8List? frameBytes;
  final bool otonomKaydedildi; // Tam otonom modda otomatik kaydedildi mi

  SecurityEvent({
    required this.id,
    required this.type,
    required this.camera,
    required this.confidence,
    required this.confidenceScore,
    required this.timestamp,
    required this.color,
    this.frameBytes,
    this.otonomKaydedildi = false,
  });
}

// ──────────────────────────────────────────────────────────────
//  RİSK SKORU
// ──────────────────────────────────────────────────────────────
class RiskAnaliz {
  static double hesapla(List<SecurityEvent> events) {
    if (events.isEmpty) return 0.0;
    double skor = 0.0;
    final now = DateTime.now();
    for (final e in events) {
      double ag;
      switch (e.type) {
        case ThreatClass.silah:
          ag = 3.0;
          break;
        case ThreatClass.saldiri:
          ag = 2.5;
          break;
        case ThreatClass.bicak:
          ag = 2.0;
          break;
        case ThreatClass.kisi:
          ag = 0.5;
          break;
      }
      if (now.difference(e.timestamp).inMinutes < 60) ag *= 1.5;
      skor += ag;
    }
    return skor;
  }

  static String seviye(double s) {
    if (s >= 12) return "KRITIK";
    if (s >= 6) return "YUKSEK";
    if (s >= 3) return "ORTA";
    return "DUSUK";
  }

  static Color renk(double s) {
    if (s >= 12) return Colors.red;
    if (s >= 6) return Colors.deepOrange;
    if (s >= 3) return Colors.orange;
    return Colors.green;
  }
}

// ──────────────────────────────────────────────────────────────
//  YARDIMCI
// ──────────────────────────────────────────────────────────────
ThreatClass _labelToClass(String label) {
  final l = label.toLowerCase();
  if (l.contains('gun') || l.contains('silah') || l.contains('pistol'))
    return ThreatClass.silah;
  if (l.contains('knife') || l.contains('bicak')) return ThreatClass.bicak;
  if (l.contains('saldiri') || l.contains('attack')) return ThreatClass.saldiri;
  return ThreatClass.kisi;
}

Color _classToColor(ThreatClass t, bool cifte) {
  if (cifte) return Colors.red;
  switch (t) {
    case ThreatClass.silah:
      return Colors.red;
    case ThreatClass.bicak:
      return Colors.orange;
    case ThreatClass.saldiri:
      return Colors.deepOrange;
    case ThreatClass.kisi:
      return Colors.blue;
  }
}

double _parseConf(List<String> tehdit, double fallback) {
  if (tehdit.isEmpty) return fallback;
  final match = RegExp(r'%(\d+)').firstMatch(tehdit.first);
  if (match != null) return int.parse(match.group(1)!) / 100.0;
  return fallback;
}

// ──────────────────────────────────────────────────────────────
//  WEBSOCKET
// ──────────────────────────────────────────────────────────────
class WebSocketService {
  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _controller =
      StreamController.broadcast();
  Stream<Map<String, dynamic>> get stream => _controller.stream;
  bool connected = false;

  void connect() {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(WS_URL));
      connected = true;
      _channel!.stream.listen(
        (msg) {
          connected = true;
          _controller.add(jsonDecode(msg as String) as Map<String, dynamic>);
        },
        onError: (_) {
          connected = false;
          Future.delayed(const Duration(seconds: 3), connect);
        },
        onDone: () {
          connected = false;
          Future.delayed(const Duration(seconds: 3), connect);
        },
      );
    } catch (_) {
      connected = false;
      Future.delayed(const Duration(seconds: 3), connect);
    }
  }

  void dispose() {
    _channel?.sink.close();
    _controller.close();
  }
}

// ──────────────────────────────────────────────────────────────
//  DASHBOARD
// ──────────────────────────────────────────────────────────────
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final WebSocketService _ws = WebSocketService();

  // Sistem modu
  SistemModu _mod = SistemModu.yariOtonom;

  // Canlı
  bool _weaponDetected = false;
  bool _davranisAlarm = false;
  List<String> _tehditler = [];
  double _saldiriSkoru = 0.0;
  double _fps = 0.0;
  bool _connected = false;

  // Grafik
  final List<double> _fpsHistory = [];
  final List<int> _saatlikOlay = List.filled(24, 0);

  // Skor grafiği — onaylanan olaylardan
  List<double> get _skorHistory => historyEvents.reversed
      .take(30)
      .toList()
      .reversed
      .map((e) => e.confidenceScore)
      .toList();

  // UI
  SecurityEvent? pendingThreat;
  Uint8List? pendingFrame;
  bool redAlarmMode = false;
  bool _pendingShown = false;
  int _eventCounter = 101;

  List<SecurityEvent> historyEvents = [];
  ThreatClass? activeFilter;

  @override
  void initState() {
    super.initState();
    _ws.connect();
    _ws.stream.listen(_onData);
    Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) setState(() => _connected = _ws.connected);
    });
  }

  void _onData(Map<String, dynamic> data) {
    if (!mounted) return;

    final bool weapon = data['weapon_detected'] ?? false;
    final bool alarm = data['davranis_alarm'] ?? false;
    final List<String> tehdit = List<String>.from(data['tehditler'] ?? []);
    final double skor = (data['saldiri_skoru'] as num?)?.toDouble() ?? 0.0;
    final double f = (data['fps'] as num?)?.toDouble() ?? 0.0;
    final String? frameB64 = data['threat_frame'] as String?;
    final double yoloConf = _parseConf(tehdit, skor);

    setState(() {
      _weaponDetected = weapon;
      _davranisAlarm = alarm;
      _tehditler = tehdit;
      _saldiriSkoru = skor;
      _fps = f;
      _connected = true;

      _fpsHistory.add(f);
      if (_fpsHistory.length > 30) _fpsHistory.removeAt(0);

      if ((weapon || alarm) && !_pendingShown && pendingThreat == null) {
        _pendingShown = true;

        if (frameB64 != null && frameB64.isNotEmpty) {
          pendingFrame = base64Decode(frameB64);
        }

        final raw = tehdit.isNotEmpty
            ? tehdit.first
            : (alarm ? 'saldiri' : 'tehdit');
        final cifte = weapon && alarm;
        final cls = alarm && !weapon ? ThreatClass.saldiri : _labelToClass(raw);
        final conf = weapon ? yoloConf : skor;

        final event = SecurityEvent(
          id: '#$_eventCounter',
          type: cls,
          camera: CAM_LABEL,
          confidence: '%${(conf * 100).toInt()}',
          confidenceScore: conf,
          timestamp: DateTime.now(),
          color: _classToColor(cls, cifte),
          frameBytes: pendingFrame,
          otonomKaydedildi: _mod == SistemModu.tamOtonom,
        );
        _eventCounter++;
        _saatlikOlay[DateTime.now().hour]++;

        // ── MOD AYRIMI ─────────────────────────────────────────
        if (_mod == SistemModu.tamOtonom) {
          // Tam otonom: direkt logla, alarm çal, kart gösterme
          historyEvents.insert(0, event);
          redAlarmMode = true;
          _playAlarm();
          // 3 saniye sonra alarm görselini kaldır
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) setState(() => redAlarmMode = false);
          });
        } else {
          // Yarı otonom: doğrulama kartı göster
          pendingThreat = event;
          redAlarmMode = true;
          _playAlarm();
        }
      }

      if (!weapon && !alarm) _pendingShown = false;
    });
  }

  void _confirmEvent() => setState(() {
    if (pendingThreat != null) historyEvents.insert(0, pendingThreat!);
    pendingThreat = null;
    pendingFrame = null;
    redAlarmMode = false;
  });

  void _rejectEvent() => setState(() {
    pendingThreat = null;
    pendingFrame = null;
    redAlarmMode = false;
  });

  List<SecurityEvent> get filteredList => activeFilter == null
      ? historyEvents
      : historyEvents.where((e) => e.type == activeFilter).toList();

  @override
  void dispose() {
    _ws.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────
  //  BUILD
  // ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bg = redAlarmMode
        ? const LinearGradient(
            colors: [Color(0xFF220000), Color(0xFF4A0000), Color(0xFF07152B)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          )
        : const LinearGradient(
            colors: [Color(0xFF07152B), Color(0xFF0D1F3A), Color(0xFF132C4C)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          );

    return Scaffold(
      key: _scaffoldKey,
      endDrawer: _buildDrawerMenu(),
      body: Container(
        decoration: BoxDecoration(gradient: bg),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  _buildModSecici(), // MOD SEÇİCİ
                  const SizedBox(height: 16),
                  _buildSystemStatusPanel(),
                  const SizedBox(height: 12),
                  _buildLiveBar(),
                  const SizedBox(height: 25),
                  if (pendingThreat != null) _buildDangerCard(),
                  const SizedBox(height: 28),
                  const Text(
                    "Kategori Secin",
                    style: TextStyle(
                      color: Colors.white54,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _filterChip(null, "Tumu"),
                        _filterChip(ThreatClass.silah, "Silah"),
                        _filterChip(ThreatClass.bicak, "Bicak"),
                        _filterChip(ThreatClass.saldiri, "Saldiri"),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  _sectionHeader(
                    Icons.history,
                    "Olay Gecmisi",
                    const Color(0xFF3A4A67),
                  ),
                  const SizedBox(height: 12),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredList.length,
                    itemBuilder: (_, i) => _buildEventCard(filteredList[i]),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Mod Seçici ──────────────────────────────────────────────
  Widget _buildModSecici() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF15233D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          _modButon(
            SistemModu.yariOtonom,
            Icons.supervised_user_circle,
            "Yari Otonom",
            "Onay gerektirir",
            const Color(0xFF2043D7),
          ),
          const SizedBox(width: 4),
          _modButon(
            SistemModu.tamOtonom,
            Icons.smart_toy,
            "Tam Otonom",
            "Otomatik loglar",
            Colors.deepOrange,
          ),
        ],
      ),
    );
  }

  Widget _modButon(
    SistemModu mod,
    IconData icon,
    String baslik,
    String aciklama,
    Color renk,
  ) {
    final secili = _mod == mod;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _mod = mod),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            color: secili ? renk.withOpacity(0.25) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: secili ? renk : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: secili ? renk : Colors.white38, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      baslik,
                      style: TextStyle(
                        color: secili ? renk : Colors.white38,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      aciklama,
                      style: TextStyle(
                        color: secili ? renk.withOpacity(0.7) : Colors.white24,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              if (secili) Icon(Icons.check_circle, color: renk, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────
  Widget _buildHeader() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      const Text(
        "AKILLI GOZETIM SISTEMI",
        style: TextStyle(
          color: Colors.white70,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
      Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: _connected ? Colors.greenAccent : Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _connected ? "CANLI" : "BAGLANTI YOK",
            style: TextStyle(
              color: _connected ? Colors.greenAccent : Colors.red,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            backgroundColor: const Color(0xFF2043D7),
            child: IconButton(
              onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
              icon: const Icon(Icons.menu, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    ],
  );

  // ── Canlı Bar ───────────────────────────────────────────────
  Widget _buildLiveBar() {
    final Color c = (_weaponDetected && _davranisAlarm)
        ? Colors.red
        : _weaponDetected
        ? Colors.orange
        : _davranisAlarm
        ? Colors.deepOrange
        : Colors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _liveItem("FPS", _fps.toStringAsFixed(0), Colors.yellow),
          _liveItem(
            "Saldiri",
            _saldiriSkoru.toStringAsFixed(2),
            _saldiriSkoru > 0.6 ? Colors.red : Colors.white,
          ),
          _liveItem(
            "Nesne",
            _tehditler.isNotEmpty ? _tehditler.first : "-",
            _weaponDetected ? Colors.orange : Colors.white54,
          ),
          _liveItem(
            "Durum",
            (_weaponDetected || _davranisAlarm) ? "TEHLIKE" : "GUVENLI",
            c,
          ),
        ],
      ),
    );
  }

  Widget _liveItem(String label, String value, Color color) => Column(
    children: [
      Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
      const SizedBox(height: 4),
      Text(
        value,
        style: TextStyle(
          color: color,
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      ),
    ],
  );

  // ── Status Panel ────────────────────────────────────────────
  Widget _buildSystemStatusPanel() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFF15233D),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: Colors.white10),
    ),
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _statusItem("Durum", "Aktif", Colors.greenAccent),
            _statusItem(
              "Mod",
              _mod == SistemModu.tamOtonom ? "OTONOM" : "YARI",
              _mod == SistemModu.tamOtonom
                  ? Colors.deepOrange
                  : const Color(0xFF2043D7),
            ),
            _statusItem(
              "Toplam Tespit",
              historyEvents.length.toString(),
              Colors.white,
            ),
          ],
        ),
        if (pendingThreat != null && _mod == SistemModu.yariOtonom) ...[
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Row(
              children: const [
                Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
                SizedBox(width: 8),
                Text(
                  "1 aktif tehdit — onay bekleniyor",
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );

  Widget _statusItem(String label, String value, Color valColor) => Column(
    children: [
      Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
      const SizedBox(height: 5),
      Text(
        value,
        style: TextStyle(
          color: valColor,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    ],
  );

  // ── Danger Card — SADECE YARI OTONOM ─────────────────────────
  Widget _buildDangerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFC4001A),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.redAccent, width: 3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.white,
                size: 50,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "TEHLIKE TESPIT EDILDI",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      pendingThreat!.type.name.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Görsel — tam genişlik, sabit yükseklik, BoxFit.contain ──
          if (pendingThreat!.frameBytes != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                height: 220,
                color: Colors.black,
                child: Image.memory(
                  pendingThreat!.frameBytes!,
                  width: double.infinity,
                  height: 220,
                  fit: BoxFit.contain, // Tam sığacak, kırpılmayacak
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Bilgi satırı
          Text(
            "Guven: ${pendingThreat!.confidence}  |  "
            "Kamera: ${pendingThreat!.camera}  |  "
            "Saat: ${DateFormat('HH:mm:ss').format(pendingThreat!.timestamp)}",
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),

          const SizedBox(height: 18),

          // Butonlar — sadece yarı otonom modda görünür
          Row(
            children: [
              Expanded(
                child: _actionBtn(
                  Icons.check_circle,
                  "DOGRULA",
                  Colors.green,
                  _confirmEvent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _actionBtn(
                  Icons.cancel,
                  "IPTAL",
                  Colors.black38,
                  _rejectEvent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(
    IconData icon,
    String label,
    Color color,
    VoidCallback fn,
  ) => ElevatedButton.icon(
    style: ElevatedButton.styleFrom(
      backgroundColor: color,
      padding: const EdgeInsets.all(14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    onPressed: fn,
    icon: Icon(icon, color: Colors.white, size: 18),
    label: Text(
      label,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    ),
  );

  // ── Tam Otonom Alarm Bandı ───────────────────────────────────
  // Tam otonom modda kart yerine üstte küçük bir bildirim bandı göster
  Widget _buildOtonomAlarmBandi() {
    if (_mod != SistemModu.tamOtonom || !redAlarmMode) return const SizedBox();
    final son = historyEvents.isNotEmpty ? historyEvents.first : null;
    if (son == null) return const SizedBox();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_fix_high, color: Colors.redAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "OTONOM: ${son.type.name.toUpperCase()} tespit edildi — "
              "loglara kaydedildi (${son.confidence})",
              style: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(ThreatClass? type, String label) {
    bool isSel = activeFilter == type;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isSel,
        onSelected: (_) => setState(() => activeFilter = type),
        selectedColor: const Color(0xFF2043D7),
        backgroundColor: const Color(0xFF1B2A44),
        labelStyle: TextStyle(color: isSel ? Colors.white : Colors.white54),
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title, Color color) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(width: 14),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );

  Widget _buildEventCard(SecurityEvent e) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2A44),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: e.otonomKaydedildi
              ? Colors.deepOrange.withOpacity(0.4)
              : Colors.white10,
          width: e.otonomKaydedildi ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: e.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          e.type.name.toUpperCase(),
                          style: TextStyle(
                            color: e.color,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (e.otonomKaydedildi) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.deepOrange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.deepOrange.withOpacity(0.5),
                              ),
                            ),
                            child: const Text(
                              "OTONOM",
                              style: TextStyle(
                                color: Colors.deepOrange,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      e.camera,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    e.confidence,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    DateFormat('HH:mm:ss').format(e.timestamp),
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2043D7),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => EventDetailPage(event: e)),
              ),
              icon: const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white,
                size: 18,
              ),
              label: const Text(
                "DETAYLAR",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  //  DRAWER
  // ──────────────────────────────────────────────────────────────
  Widget _buildDrawerMenu() {
    final total = historyEvents.length;
    final weaponCount = historyEvents
        .where((e) => e.type == ThreatClass.silah)
        .length;
    final knifeCount = historyEvents
        .where((e) => e.type == ThreatClass.bicak)
        .length;
    final otonomCount = historyEvents.where((e) => e.otonomKaydedildi).length;
    final riskSkor = RiskAnaliz.hesapla(historyEvents);
    final riskSeviye = RiskAnaliz.seviye(riskSkor);
    final riskRenk = RiskAnaliz.renk(riskSkor);

    return Drawer(
      backgroundColor: const Color(0xFF101B33),
      child: SafeArea(
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                child: const Text(
                  "AI ANALIZ PANELI",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const TabBar(
                indicatorColor: Color(0xFF2043D7),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white38,
                tabs: [
                  Tab(text: "OZET"),
                  Tab(text: "GRAFIKLER"),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    // ── OZET ──────────────────────────────────────────
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1B2A44),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Column(
                              children: [
                                _drawerStat(
                                  "Toplam Olay",
                                  total.toString(),
                                  Icons.analytics,
                                  Colors.blue,
                                ),
                                const SizedBox(height: 15),
                                _drawerStat(
                                  "Silah Tespiti",
                                  weaponCount.toString(),
                                  Icons.gps_fixed,
                                  Colors.red,
                                ),
                                const SizedBox(height: 15),
                                _drawerStat(
                                  "Bicak Tespiti",
                                  knifeCount.toString(),
                                  Icons.warning,
                                  Colors.orange,
                                ),
                                const SizedBox(height: 15),
                                _drawerStat(
                                  "Otonom Kayit",
                                  otonomCount.toString(),
                                  Icons.smart_toy,
                                  Colors.deepOrange,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Risk
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1B2A44),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Risk Analizi",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      "Risk Skoru",
                                      style: TextStyle(color: Colors.white54),
                                    ),
                                    Text(
                                      riskSkor.toStringAsFixed(1),
                                      style: TextStyle(
                                        color: riskRenk,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    value: (riskSkor / 20).clamp(0.0, 1.0),
                                    backgroundColor: Colors.white12,
                                    color: riskRenk,
                                    minHeight: 10,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      "Risk Seviyesi",
                                      style: TextStyle(color: Colors.white54),
                                    ),
                                    Text(
                                      riskSeviye,
                                      style: TextStyle(
                                        color: riskRenk,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      "Aktif Mod",
                                      style: TextStyle(color: Colors.white54),
                                    ),
                                    Text(
                                      _mod == SistemModu.tamOtonom
                                          ? "TAM OTONOM"
                                          : "YARI OTONOM",
                                      style: TextStyle(
                                        color: _mod == SistemModu.tamOtonom
                                            ? Colors.deepOrange
                                            : const Color(0xFF2043D7),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      "AI Durumu",
                                      style: TextStyle(color: Colors.white54),
                                    ),
                                    Text(
                                      _connected ? "AKTIF" : "BAGLANTI YOK",
                                      style: TextStyle(
                                        color: _connected
                                            ? Colors.greenAccent
                                            : Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    "Skor = Silah×3 + Saldiri×2.5 + Bicak×2\n"
                                    "Son 1 saatteki olaylar 1.5x agirlik alir.",
                                    style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: Colors.redAccent.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: const [
                                Icon(Icons.shield, color: Colors.redAccent),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    "AI Guvenlik Sistemi Aktif",
                                    style: TextStyle(
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── GRAFİKLER ─────────────────────────────────────
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          _grafikBaslik("FPS Gecmisi (Canli)"),
                          const SizedBox(height: 8),
                          _fpsGrafik(),
                          const SizedBox(height: 24),
                          _grafikBaslik("Onaylanan Olaylarin Guven Skoru"),
                          const SizedBox(height: 8),
                          _skorGrafik(),
                          const SizedBox(height: 24),
                          _grafikBaslik("Tehdit Turu Dagilimi"),
                          const SizedBox(height: 8),
                          _tehditPastaGrafik(),
                          const SizedBox(height: 24),
                          _grafikBaslik("Saatlik Olay Dagilimi"),
                          const SizedBox(height: 8),
                          _saatlikBarGrafik(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _grafikBaslik(String title) => Align(
    alignment: Alignment.centerLeft,
    child: Text(
      title,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  Widget _fpsGrafik() {
    if (_fpsHistory.isEmpty) return _bosGrafik("Veri bekleniyor...");
    return Container(
      height: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2A44),
        borderRadius: BorderRadius.circular(16),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            getDrawingHorizontalLine: (_) =>
                FlLine(color: Colors.white10, strokeWidth: 1),
            getDrawingVerticalLine: (_) =>
                FlLine(color: Colors.white10, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (v, _) => Text(
                  v.toInt().toString(),
                  style: const TextStyle(color: Colors.white38, fontSize: 9),
                ),
              ),
            ),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: _fpsHistory
                  .asMap()
                  .entries
                  .map((e) => FlSpot(e.key.toDouble(), e.value))
                  .toList(),
              isCurved: true,
              color: Colors.yellow,
              barWidth: 2,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.yellow.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _skorGrafik() {
    if (_skorHistory.isEmpty) return _bosGrafik("Henuz onaylanan olay yok");
    return Container(
      height: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2A44),
        borderRadius: BorderRadius.circular(16),
      ),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 1,
          gridData: FlGridData(
            getDrawingHorizontalLine: (_) =>
                FlLine(color: Colors.white10, strokeWidth: 1),
            getDrawingVerticalLine: (_) =>
                FlLine(color: Colors.white10, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (v, _) => Text(
                  '%${(v * 100).toInt()}',
                  style: const TextStyle(color: Colors.white38, fontSize: 9),
                ),
              ),
            ),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: 0.6,
                color: Colors.red.withOpacity(0.5),
                strokeWidth: 1,
                dashArray: [4, 4],
              ),
            ],
          ),
          lineBarsData: [
            LineChartBarData(
              spots: _skorHistory
                  .asMap()
                  .entries
                  .map((e) => FlSpot(e.key.toDouble(), e.value))
                  .toList(),
              isCurved: true,
              color: Colors.deepOrange,
              barWidth: 2,
              dotData: FlDotData(
                show: true,
                getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                  radius: 4,
                  color: Colors.orange,
                  strokeWidth: 1,
                  strokeColor: Colors.white,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.deepOrange.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tehditPastaGrafik() {
    final silah = historyEvents
        .where((e) => e.type == ThreatClass.silah)
        .length;
    final bicak = historyEvents
        .where((e) => e.type == ThreatClass.bicak)
        .length;
    final saldiri = historyEvents
        .where((e) => e.type == ThreatClass.saldiri)
        .length;
    if (silah + bicak + saldiri == 0) return _bosGrafik("Henuz olay yok");
    return Container(
      height: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2A44),
        borderRadius: BorderRadius.circular(16),
      ),
      child: PieChart(
        PieChartData(
          sectionsSpace: 3,
          centerSpaceRadius: 35,
          sections: [
            if (silah > 0)
              PieChartSectionData(
                value: silah.toDouble(),
                color: Colors.red,
                title: 'Silah\n$silah',
                titleStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            if (bicak > 0)
              PieChartSectionData(
                value: bicak.toDouble(),
                color: Colors.orange,
                title: 'Bicak\n$bicak',
                titleStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            if (saldiri > 0)
              PieChartSectionData(
                value: saldiri.toDouble(),
                color: Colors.deepOrange,
                title: 'Saldiri\n$saldiri',
                titleStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _saatlikBarGrafik() {
    final maxVal = _saatlikOlay.reduce((a, b) => a > b ? a : b);
    if (maxVal == 0) return _bosGrafik("Henuz olay yok");
    return Container(
      height: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2A44),
        borderRadius: BorderRadius.circular(16),
      ),
      child: BarChart(
        BarChartData(
          maxY: (maxVal + 1).toDouble(),
          gridData: FlGridData(
            getDrawingHorizontalLine: (_) =>
                FlLine(color: Colors.white10, strokeWidth: 1),
            drawVerticalLine: false,
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  final h = v.toInt();
                  if (h % 6 != 0) return const SizedBox();
                  return Text(
                    '${h}:00',
                    style: const TextStyle(color: Colors.white38, fontSize: 9),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (v, _) => Text(
                  v.toInt().toString(),
                  style: const TextStyle(color: Colors.white38, fontSize: 9),
                ),
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(
            24,
            (i) => BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: _saatlikOlay[i].toDouble(),
                  color: _saatlikOlay[i] > 0
                      ? const Color(0xFF2043D7)
                      : Colors.white12,
                  width: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bosGrafik(String msg) => Container(
    height: 80,
    decoration: BoxDecoration(
      color: const Color(0xFF1B2A44),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Center(
      child: Text(
        msg,
        style: const TextStyle(color: Colors.white38, fontSize: 13),
      ),
    ),
  );

  Widget _drawerStat(String title, String value, IconData icon, Color color) =>
      Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.15),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      );
}

// ──────────────────────────────────────────────────────────────
//  DETAIL PAGE
// ──────────────────────────────────────────────────────────────
class EventDetailPage extends StatelessWidget {
  final SecurityEvent event;
  const EventDetailPage({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07152B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Olay Detayi", style: TextStyle(color: Colors.white)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Görsel — BoxFit.contain ile tam sığdır
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: double.infinity,
                  height: 260,
                  color: Colors.black,
                  child: event.frameBytes != null
                      ? Image.memory(
                          event.frameBytes!,
                          width: double.infinity,
                          height: 260,
                          fit: BoxFit.contain,
                        )
                      : Center(
                          child: Icon(
                            Icons.videocam,
                            color: event.color,
                            size: 90,
                          ),
                        ),
                ),
              ),

              // Otonom badge
              if (event.otonomKaydedildi) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.deepOrange.withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.smart_toy, color: Colors.deepOrange, size: 16),
                      SizedBox(width: 6),
                      Text(
                        "Tam Otonom Mod — Otomatik Kaydedildi",
                        style: TextStyle(
                          color: Colors.deepOrange,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),
              Text(
                "Tehdit Turu",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                event.type.name.toUpperCase(),
                style: TextStyle(
                  color: event.color,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              _detailItem(Icons.camera_alt, "Kamera", event.camera),
              _detailItem(Icons.analytics, "Guven Orani", event.confidence),
              _detailItem(
                Icons.access_time,
                "Timestamp",
                DateFormat('dd.MM.yyyy HH:mm:ss').format(event.timestamp),
              ),
              const SizedBox(height: 25),
              const Text(
                "AI Aciklamasi",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B2A44),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  "Yapay zeka modeli, kamera goruntusu uzerinde potansiyel bir "
                  "${event.type.name} tehdidi algıladi. "
                  "${event.otonomKaydedildi ? 'Tam otonom mod aktif oldugundan olay kullanici onayı beklenmeden loglara kaydedildi.' : 'Olay kullanici tarafindan onaylandi ve loglara kaydedildi.'}",
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailItem(IconData icon, String title, String value) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF1B2A44),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        CircleAvatar(
          backgroundColor: Colors.white10,
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
