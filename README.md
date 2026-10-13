# 🧠 Yapay Zekâ Tabanlı Hibrit Akıllı Gözetim Sistemi

### TÜBİTAK 2209-A Destekli Bitirme Projesi

Gerçek zamanlı güvenlik kamerası görüntülerini analiz ederek tehlikeli nesneleri tespit etmeyi, nesnelerin görüntü içerisindeki hareketlerini takip etmeyi ve saldırı davranışlarını sınıflandırmayı amaçlayan yapay zekâ tabanlı hibrit bir akıllı gözetim sistemi.

<p align="center">
  <strong>Computer Vision</strong> ·
  <strong>Deep Learning</strong> ·
  <strong>YOLO</strong> ·
  <strong>CSRT Tracking</strong> ·
  <strong>LSTM</strong> ·
  <strong>FastAPI</strong> ·
  <strong>Flutter</strong>
</p>

---

##  Proje Hakkında

Geleneksel güvenlik sistemlerinde kamera görüntülerinin sürekli olarak insanlar tarafından izlenmesi gerekebilir. Uzun süreli izleme, dikkat kaybına ve kritik olayların geç fark edilmesine neden olabilir.

Bu proje kapsamında, güvenlik kamerası görüntülerini gerçek zamanlı analiz ederek potansiyel tehditlerin belirlenmesine yardımcı olan **Yapay Zekâ Tabanlı Hibrit Akıllı Gözetim Sistemi** geliştirilmiştir.

Sistem, iki temel yapay zekâ modülünü bir araya getirir:

* **Tehlikeli nesne tespiti ve hedef takibi:** YOLOv5m ile silah ve bıçak gibi nesnelerin tespit edilmesi; OpenCV CSRT takip algoritması ve IoU tabanlı eşleştirme ile tespit edilen nesnelerin görüntü içerisindeki takibinin sürdürülmesi.
* **Saldırı davranışı analizi:** YOLOv8n-Pose ile insan vücudunun iskelet anahtar noktalarının çıkarılması ve LSTM ile ardışık karelerdeki hareket örüntülerinin analiz edilmesi.

Python tabanlı backend, yapay zekâ modellerinin sonuçlarını işler ve WebSocket üzerinden Flutter arayüzüne iletir. Flutter uygulaması ise tehdit bilgilerinin, olayların ve sistem durumunun operatör tarafından takip edilebilmesini sağlar.

Proje, **TÜBİTAK 2209-A Üniversite Öğrencileri Araştırma Projeleri Destekleme Programı** kapsamında desteklenmiştir.

##  Projenin Amaçları

* Güvenlik kamerası görüntülerinde silah ve bıçak gibi tehlikeli nesneleri tespit etmek.
* Tespit edilen nesnelerin görüntü içerisindeki konumlarını takip etmek.
* IoU tabanlı eşleştirme ile yeni nesne tespitlerini mevcut takiplerle ilişkilendirmek.
* İnsan iskelet anahtar noktalarından hareket özellikleri çıkararak saldırı davranışlarını sınıflandırmak.
* Nesne tespiti, nesne takibi ve davranış analizini hibrit bir mimaride birleştirmek.
* Yapay zekâ modellerinin sonuçlarını gerçek zamanlı olarak operatör arayüzüne aktarmak.
* Tehditlerin daha hızlı değerlendirilmesine yardımcı olan bir prototip geliştirmek.

##  Sistem Mimarisi

Sistem; nesne tespiti ve takibi, saldırı davranışı analizi, backend iletişimi ve Flutter tabanlı operatör arayüzünden oluşur.

```text
                    GÜVENLİK KAMERASI
                            │
                            ▼
                  GERÇEK ZAMANLI GÖRÜNTÜ
                            │
                ┌───────────┴───────────┐
                ▼                       ▼
        NESNE TESPİTİ             DAVRANIŞ ANALİZİ
          YOLOv5m                  YOLOv8n-Pose
                │                       │
                ▼                       ▼
        Silah / Bıçak             17 İskelet Anahtar
            Tespiti                 Noktası
                │                       │
                ▼                       ▼
        OpenCV CSRT               34 Koordinat
          Takibi                  Özellik Vektörü
                │                       │
                ▼                       ▼
        IoU Tabanlı                 Zamansal Dizi
         Eşleştirme                      │
                │                       ▼
                ▼                      LSTM
         Hedef Takibi                    │
                │                       ▼
                │                Saldırı Sınıflandırma
                │                       │
                └───────────┬───────────┘
                            ▼
                     TEHDİT BİLGİLERİ
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
              Gerçek Zamanlı İzleme ve
                  Operatör Bildirimleri
```

*Not: Diyagram, sistemin temel bileşenlerini ve aralarındaki iletişimi kavramsal olarak göstermektedir.*

##  Temel Modüller

### 1. Tehlikeli Nesne Tespiti ve Hedef Takibi

Sistemin nesne tespiti modülünde, güvenlik kamerası görüntülerinde silah ve bıçak gibi tehlikeli nesnelerin belirlenmesi amacıyla YOLOv5m modeli kullanılmaktadır.

Tespit edilen nesnelerin yalnızca tek bir karede belirlenmesiyle yetinilmez. OpenCV'nin CSRT takip algoritması ve IoU tabanlı eşleştirme mekanizması kullanılarak nesnelerin sonraki karelerdeki konumları takip edilmeye çalışılır.

**Kullanılan teknolojiler:**

* YOLOv5m
* OpenCV
* CSRT Object Tracking
* Intersection over Union (IoU)
* PyTorch
* Python

**Çalışma prensibi:**

1. Kamera görüntüsü YOLOv5m modeline iletilir.
2. Model, belirlenen güven eşiğini karşılayan tehlikeli nesne tespitlerini üretir.
3. Tespit edilen nesnelerin sınıf bilgileri ve sınırlayıcı kutu koordinatları alınır.
4. OpenCV CSRT takip algoritması, nesnelerin görüntü içerisindeki konumlarını ardışık karelerde izler.
5. Yeni YOLO tespitleri ile mevcut takipler IoU değerleri üzerinden karşılaştırılır.
6. IoU eşik değerini karşılayan eşleşmelerde takip kutusu güncellenir ve nesne etiketi korunur.
7. Bir nesne yeterli süre yeniden tespit edilemezse ilgili takip kaydı sistemden kaldırılır.

**Hedef kilitleme ve takip mekanizması:**

Sistemdeki hedef kilitleme yaklaşımı, tespit edilen nesnenin görüntü içerisindeki konumunu takip etmeye dayanır. IoU, iki sınırlayıcı kutunun kesişim alanının birleşim alanına oranını hesaplayarak yeni tespit ile mevcut takip arasındaki örtüşmeyi değerlendirir.

Mevcut kodda kullanılan temel yapılandırmalar şunlardır:

| Parametre           | Değer | Açıklama                                                              |
| ------------------- | ----: | --------------------------------------------------------------------- |
| YOLO güven eşiği    |  0,60 | Nesne tespitlerinde kullanılan minimum güven değeri                   |
| IoU eşik değeri     |  0,25 | Yeni tespit ile mevcut takip arasında eşleştirme için kullanılan eşik |
| Kayıp tespit sınırı |    15 | Takibin kaldırılmasından önce kullanılan kayıp tespit sayısı          |

Takip edilen nesneler, görüntü üzerinde sınırlayıcı kutular ve `[TAKIP]` etiketiyle görselleştirilir.

> **Önemli:** Buradaki hedef kilitleme, bilgisayarlı görü kapsamında görüntü içerisindeki nesnenin tespit edilmesi ve takibinin sürdürülmesi anlamına gelir. Fiziksel bir silahı, aracı veya başka bir platformu yönlendiren mekanik bir kilitleme sistemi değildir. CSRT takibi ile YOLO tespitleri birbirini destekler; takip performansı nesnenin görünürlüğüne, hareketine ve görüntü koşullarına bağlıdır.

### 2. Saldırı Davranışı Analizi

Saldırı davranışı analizi modülünde, insan vücudunun iskelet anahtar noktalarından çıkarılan zamansal özellikler LSTM modeliyle değerlendirilir.

**Kullanılan teknolojiler:**

* YOLOv8n-Pose
* LSTM
* TensorFlow / Keras
* NumPy
* Pandas
* Python

**Çalışma prensibi:**

1. YOLOv8n-Pose modeliyle görüntüdeki kişilerin vücut anahtar noktaları çıkarılır.
2. COCO formatındaki 17 iskelet anahtar noktasının normalize edilmiş X ve Y koordinatları alınır.
3. Her kişi için 34 koordinat değerinden oluşan özellik vektörü hazırlanır.
4. Ardışık karelerden elde edilen özellikler zaman sırasına göre bir araya getirilir.
5. LSTM modeli, 30 zaman adımından oluşan hareket dizisini değerlendirerek saldırı davranışını sınıflandırır.
6. Modelin tahmin skoru, belirlenen eşik değerine göre değerlendirilir.

Bu yaklaşım, tek bir görüntü karesini değerlendirmek yerine vücut hareketlerinin zaman içerisindeki değişimini de dikkate alır.

**Davranış analizi için kullanılan temel parametreler:**

| Parametre            |            Değer | Açıklama                                                |
| -------------------- | ---------------: | ------------------------------------------------------- |
| Poz modeli           |     YOLOv8n-Pose | İskelet anahtar noktalarının çıkarılması                |
| Anahtar nokta sayısı |               17 | COCO vücut iskeleti anahtar noktaları                   |
| Özellik boyutu       |               34 | Her anahtar nokta için X ve Y koordinatları             |
| Dizi uzunluğu        |               30 | LSTM modeline verilen ardışık özellik sayısı            |
| Poz işleme aralığı   | Her 2 karede bir | Poz çıkarımı için kullanılan kare atlama yapılandırması |
| Saldırı skoru eşiği  |             0,60 | Alarm değerlendirmesinde kullanılan eşik                |

### 3. Gerçek Zamanlı Backend ve İletişim

Backend, kamera görüntülerinin işlenmesini, yapay zekâ modellerinin çalıştırılmasını ve sonuçların Flutter uygulamasına iletilmesini sağlar.

**Kullanılan teknolojiler:**

* Python
* FastAPI
* WebSocket
* OpenCV
* JSON
* Base64

**Temel işlevler:**

* Kamera görüntülerinin alınması ve işlenmesi
* Nesne tespiti ve takip sonuçlarının oluşturulması
* Saldırı davranışı analizinin yürütülmesi
* Tehdit bilgilerinin WebSocket üzerinden aktarılması
* Tehdit anına ait görüntünün JPEG biçiminde hazırlanarak Base64 ile iletilmesi
* İstemci bağlantısının yönetilmesi

Backend, tehdit görüntüsünü aktarırken görüntüyü 640 × 360 boyutlarına küçültür ve JPEG sıkıştırması uygular. Bu yaklaşım, WebSocket üzerinden iletilen görüntü verisinin boyutunu azaltmayı amaçlar.

Flutter uygulaması, backend'den gelen JSON verilerini işleyerek ilgili bilgileri arayüzde gösterir.

### 4. Flutter Operatör Arayüzü

Sistemin operatör arayüzü Flutter ve Dart kullanılarak geliştirilmiştir. Arayüz, yapay zekâ modüllerinden elde edilen sonuçların operatör tarafından takip edilebilmesini ve sistem durumunun tek bir ekran üzerinden izlenebilmesini amaçlar.

**Kullanılan teknolojiler:**

* Flutter
* Dart
* WebSocket
* `web_socket_channel`
* `fl_chart`
* `intl`
* JSON veri işleme

**Arayüzün temel işlevleri:**

* **Gerçek zamanlı veri iletişimi:** Backend'den WebSocket üzerinden gelen olay ve tehdit bilgilerinin alınması.
* **Tehdit gösterimi:** Silah, bıçak ve saldırı davranışı gibi tehdit sınıflarına ilişkin bilgilerin arayüzde sunulması.
* **Tehdit görüntüsünün gösterilmesi:** Backend tarafından Base64 biçiminde gönderilen tehdit karesinin çözülerek görüntülenmesi.
* **Sistem modu yönetimi:** Yarı otonom ve tam otonom çalışma modlarını temsil eden arayüz seçeneklerinin kullanılması.
* **Risk seviyelerinin gösterimi:** Düşük, orta, yüksek ve kritik gibi risk seviyelerinin görsel olarak ayrıştırılması.
* **Olayların izlenmesi:** Tespit edilen olayların ve tehdit bilgilerinin operatör tarafından takip edilebilmesi.
* **Grafiklerle görselleştirme:** `fl_chart` kütüphanesi üzerinden desteklenen grafiklerin oluşturulması.
* **Bağlantı yönetimi:** WebSocket bağlantısının izlenmesi ve bağlantı kesildiğinde yeniden bağlanma mekanizmasının kullanılması.

**WebSocket iletişim akışı:**

1. Flutter uygulaması backend'in WebSocket uç noktasına bağlanır.
2. Backend tarafından gönderilen JSON mesajları alınır.
3. Gelen mesajlar Dart tarafında çözümlenir.
4. Tehdit bilgileri, olay verileri ve varsa tehdit görüntüsü arayüzün ilgili bileşenlerine aktarılır.
5. Bağlantı kesilirse uygulama, tanımlanan yeniden bağlanma mekanizmasıyla bağlantıyı tekrar kurmayı dener.

Arayüzde kullanılan renkler ve görsel bileşenler, farklı tehdit ve risk seviyelerinin operatör tarafından daha kolay ayırt edilmesine yardımcı olacak şekilde tasarlanmıştır.

*Not: Arayüzdeki işlevlerin kullanılabilirliği, ilgili bileşenlerin backend ve frontend kodundaki mevcut entegrasyonuna bağlıdır. Yarı otonom ve tam otonom mod adları, tek başına sistemin fiziksel bir cihazı otonom biçimde kontrol ettiği anlamına gelmez.*

##  Deneysel Sonuçlar

Proje kapsamında gerçekleştirilen deneylerde aşağıdaki sonuçlar elde edilmiştir:

| Modül                           | Model / Yöntem      |                       Sonuç |
| ------------------------------- | ------------------- | --------------------------: |
| Tehlikeli nesne tespiti         | YOLOv5m             |                %88,1 mAP@50 |
| Saldırı davranışı sınıflandırma | YOLOv8n-Pose + LSTM | %73 sınıflandırma doğruluğu |

### Sonuçların Değerlendirilmesi

* **Tehlikeli nesne tespiti:** YOLOv5m ile silah ve bıçak tespitine yönelik deneylerde %88,1 mAP@50 sonucu elde edilmiştir.
* **Saldırı davranışı analizi:** YOLOv8n-Pose ile çıkarılan iskelet özelliklerinin LSTM ile zamansal analizi sonucunda %73 sınıflandırma doğruluğu elde edilmiştir.

Bu sonuçlar, ilgili modüllerin gerçekleştirilen deneyler kapsamındaki performansını göstermektedir. Gerçek ortamlardaki performans; kamera açısı, aydınlatma, nesne boyutu, örtülme, hareket çeşitliliği ve veri setinin temsil gücü gibi faktörlerden etkilenebilir.

> **Ölçüm notu:** mAP@50 ve sınıflandırma doğruluğu farklı performans ölçütleridir. Bu değerler doğrudan birbiriyle karşılaştırılmamalıdır. Ayrıca nesne takip modülünün başarısı, nesne tespiti mAP değerinden ayrı olarak değerlendirilmelidir.

##  Kullanılan Teknolojiler

| Alan                      | Teknolojiler                |
| ------------------------- | --------------------------- |
| Programlama dilleri       | Python, Dart                |
| Nesne tespiti             | YOLOv5m                     |
| Nesne takibi              | OpenCV CSRT                 |
| Nesne eşleştirme          | IoU                         |
| Poz tahmini               | YOLOv8n-Pose                |
| Zamansal davranış analizi | LSTM                        |
| Derin öğrenme             | PyTorch, TensorFlow / Keras |
| Görüntü işleme            | OpenCV                      |
| Backend                   | FastAPI                     |
| Gerçek zamanlı iletişim   | WebSocket                   |
| Kullanıcı arayüzü         | Flutter                     |
| Grafikler                 | fl_chart                    |
| Veri işleme               | NumPy, Pandas               |
| Ortam değişkenleri        | python-dotenv               |

##  Proje Yapısı

```text
Yapayzeka-Tabanli-Hibrit-Akilli-Gozetim-Sistemi/
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

**Önemli:** Eğitilmiş model dosyaları (`.pt`, `.keras` vb.) ve gerçek ortam değişkenlerini içeren `.env` dosyası Git deposuna eklenmemiştir. Modeller, uygulamanın çalışabilmesi için yerel ortamda beklenen dosya adları ve konumlarıyla sağlanmalıdır.

## ⚙️ Kurulum

### Gereksinimler

* Python
* Flutter SDK
* Git
* Uygun bir kamera
* Projede kullanılan eğitilmiş model dosyaları

İşletim sistemi, donanım ve bağımlılık sürümleri çalıştırma ortamını etkileyebilir.

### 1. Depoyu klonlayın

```bash
git clone https://github.com/fyuceer/Yapayzeka-Tabanli-Hibrit-Akilli-Gozetim-Sistemi.git
cd Yapayzeka-Tabanli-Hibrit-Akilli-Gozetim-Sistemi
```

### 2. Python sanal ortamını oluşturun

```bash
python -m venv .venv
```

Windows PowerShell:

```powershell
.venv\Scripts\Activate.ps1
```

Windows CMD:

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

`.env` dosyasını açarak kendi token değerinizi girin:

```env
API_TOKEN=KENDI_TOKEN_DEGERINIZ
```

Gerçek token değerlerini kaynak kodlara eklemeyin veya herkese açık depolarda paylaşmayın.

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

Model dosyalarının adları ve konumları backend kodundaki yapılandırmayla eşleşmelidir.

### 5. Backend'i başlatın

Proje ana dizinindeyken:

```bash
python python_backend/hibrit.py
```

Kamera erişiminin, model dosyalarının, Python bağımlılıklarının ve `.env` yapılandırmasının doğru olduğundan emin olun.

### 6. Flutter bağımlılıklarını yükleyin

Yeni bir terminal açın ve Flutter klasörüne geçin:

```bash
cd flutter_app
flutter pub get
```

### 7. Flutter uygulamasını başlatın

Backend'in çalıştığından emin olduktan sonra:

```bash
flutter run -d chrome --dart-define=API_TOKEN=KENDI_TOKEN_DEGERINIZ
```

`KENDI_TOKEN_DEGERINIZ` yerine `.env` dosyasında yapılandırdığınız token değerini kullanın.

**Bağlantı notları:**

* Frontend ve backend aynı bilgisayarda çalışıyorsa `localhost` adresi kullanılabilir.
* Farklı cihazlarda çalıştırma veya uzaktan dağıtım için WebSocket adresi ve ağ yapılandırması düzenlenmelidir.
* Flutter Web uygulamasına derleme sırasında verilen token istemci tarafında incelenebilir. Bu nedenle `--dart-define` kullanılması token'ı gizli tutmaya tek başına yetmez.
* Üretim ortamlarında uygun kimlik doğrulama, erişim denetimi ve güvenli bağlantı yapılandırması kullanılmalıdır.

##  Güvenlik ve Gizlilik

* `.env` dosyası Git takibinin dışında tutulmalıdır.
* Eğitilmiş model dosyaları, depo boyutunu ve dağıtım koşullarını yönetmek amacıyla Git deposuna eklenmemiştir.
* Gerçek token değerleri kaynak kodlarda saklanmamalıdır.
* İstemci tarafında kullanılan erişim bilgilerinin gizli kalacağı varsayılmamalıdır.
* Gerçek ortamlarda HTTPS/WSS ve uygun kimlik doğrulama mekanizmaları değerlendirilmelidir.
* Kamera görüntüleri ve güvenlik kayıtları işlenirken gizlilik ve veri koruma gerekliliklerine uyulmalıdır.

##  Sınırlılıklar ve Gelecek Çalışmalar

Sistemin daha geniş kullanım senaryolarına uyarlanması için aşağıdaki geliştirmeler değerlendirilebilir:

* Farklı kamera açıları, aydınlatma koşulları ve kalabalık ortamlarda testlerin genişletilmesi
* Nesne takip performansının kimlik sürekliliği, takip kaybı ve yeniden tespit ölçütleriyle değerlendirilmesi
* Davranış analizi veri setinin çeşitlendirilmesi
* Saldırı sınıflandırma performansının iyileştirilmesi
* Gerçek zamanlı işlem hızı ve uçtan uca gecikmenin ölçülmesi
* Yanlış pozitif ve yanlış negatif sonuçların analiz edilmesi
* Operatör arayüzündeki olay geçmişi ve bildirim mekanizmalarının geliştirilmesi
* Kimlik doğrulama ve dağıtım güvenliğinin güçlendirilmesi

##  Geliştirici

**Feyza Sultan Yüceer**

GitHub: [@fyuceer](https://github.com/fyuceer)

---

*Bu proje, yapay zekâ ve bilgisayarlı görü yöntemlerinin akıllı gözetim sistemlerinde kullanımını araştırmak ve gerçek zamanlı tehdit analizine yönelik hibrit bir prototip geliştirmek amacıyla hazırlanmıştır.*
