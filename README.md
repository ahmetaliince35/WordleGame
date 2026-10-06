# 📚 Kelime Dünyası - Türkçe Kelime Oyunları Platformu

**Kelime Dünyası**, 92.408 kelimelik zengin Türk Dil Kurumu (TDK) sözlük veritabanı ile güçlendirilmiş, modern, minimalist ve akıcı bir Flutter kelime oyunları uygulamasıdır.

Gözü yormayan yumuşak pastel renk paleti, ergonomik Türkçe Q klavyesi, tam çevrimdışı (offline) çalışabilen SQLite altyapısı ve her yaşa hitap eden 5 farklı oyun modu sunar.

---

## 🎮 Oyun Modları

### 1. 🟩 Türkçe Wordle
- **Özelleştirilebilir Harf Sayısı:** 4, 5, 6 ve 7 harfli kelime seçenekleri.
- **Klasik Kurallar:** 6 denemede gizli kelimeyi bulmaya çalışın.
- **Akıllı Renk Geri Bildirimi:**
  - 🟩 **Yeşil:** Harf doğru yerde.
  - 🟨 **Sarı:** Harf kelimede var ancak yeri yanlış.
  - ⬛ **Gri:** Harf kelimede bulunmuyor.
- **İstatistik Takibi:** Oynanan oyun, kazanma oranı, mevcut ve en yüksek galibiyet serisi, tahmin dağılım grafiği.
- **TDK Anlamı:** Oyun sonunda gizli kelimenin resmi TDK sözlük anlamını öğrenme fırsatı.

### 2. Dinamik Çengel Bulmaca (Genişletildi)
- **Genişletilmiş 25 Kelimelik Matris:** 20-25 arası kesişen kelimeyle zenginleştirilmiş, TDK sözlük anlamlarıyla dolu büyük bulmaca tahtası.
- **Kaydırılabilir & Yakınlaştırılabilir Izgara:** `InteractiveViewer` pan ve zoom desteğiyle küçük/büyük tüm ekranlarda taşma olmadan rahat navigasyon.
- **Şeffaf Hücre Sistemi:** Boş kutular gizlenerek sadece harf hücreleri ve ipucu numaraları gösterilir.
- **Harf Aç (İpucu) Özelliği:** Takıldığınızda aktif kelimedeki bir harfin yerini ve kendisini doğrudan ızgarada açar.
- **Çift Yönlü Navigasyon:** Hücrelere dokunarak yatay ve dikey yönler arasında anında geçiş.

### 3. Kelime Türetmece
- **Pes Et Özelliği:** Takıldığınızda tek dokunuşla tüm türetilebilir kelimeleri harf uzunluklarına göre listeler, bulduklarınızı ve bulamadıklarınızı ayrıştırır; kelimelere dokunarak TDK anlamlarını inceleyebilirsiniz.
- **3 Yıldız Hedef Sistemi:** Bronz, Gümüş ve Altın puan hedefleriyle ilerleme çubuğu.
- **Kelime Dağılım Takibi:** Harf havuzundan türetilebilecek toplam geçerli kelime sayısını görme imkanı.
- **Dinamik Karıştırma:** Harf tablasını tek dokunuşla karıştırabilme.

### 4. Adam Asmaca
- **Standart Sanal Q Klavye:** Ana Wordle klavyesiyle uyumlu, geniş tuşlu Türkçe Sanal Klavye.
- **Sıfır Taşma (Overflow Koruması):** Esnek ve kaydırılabilir yerleşim sayesinde küçük ekranlarda dahi taşma yaşanmaz.
- **Sınırsız Kelime Havuzu & Boşluk Desteği:** Harf sınırı olmaksızın kısa/uzun sözcükler ve boşluklu tamlamalar.
- **Çizgisel Çizim & TDK Anlamı:** 6 can hakkı ve tek tuşla TDK tanımı ipucu.

### 5. Anagram Çözücü
- **Otomatik Hata Temizleme:** Yanlış kelime girildiğinde harfler beklemeden otomatik olarak geri havuza döner.
- **Anlam Gösterimi & Kontrollü Geçiş:** Kelime doğru bilindiğinde TDK anlamı ekranda gösterilir ve oyuncu "Devam Et" butonuna basınca sonraki kelimeye geçilir.
- **Kademeli Seviye İlerlemesi:** 4 harfliden 7 harfe uzanan seviye sistemi.

### 6. 🔢 Bir İşlem (Matematiksel 4 İşlem Modu)
- **Kural & Mekanik:** Verilen 5-6 sayı (her biri en fazla 50) ile 4 işlem (`+`, `-`, `×`, `÷`) yapılarak hedef sayıya ulaşmaya çalışılır.
- **Tek Kullanım Kuralı:** Verilen her sayı yalnızca bir kez kullanılabilir; işlem sonucunda elde edilen yeni sayılar sonraki işlemlerde kullanılabilir.
- **Zorluk Seviyeleri:** Kolay (50-250), Orta (100-500) ve Zor (150-999) modları.
- **Geri Al & Sıfırla:** Yapılan her işlem adım adım geri alınabilir veya başlangıç sayılarına sıfırlanabilir.
- **Otomatik Çözücü & Pes Et:** Takıldığınızda rekürsif Countdown çözücü algoritması ile adım adım en kısa çözümü anında inceleyebilirsiniz.
- **En Yakın Sonuç Puanlaması:** Tam hedefe ulaşılamasa bile en yakın bulunan değere göre adil puanlama yapılır.

### 7. 🧩 Sudoku (9x9 Zeka Oyunu)
- **4 Kademeli Zorluk:** Kolay, Orta, Zor ve Çok Zor seviyeleri.
- **Kusursuz Bulmaca Üretimi:** 9x9 matris ve 3x3 blok kurallarına uygun dinamik üretim motoru.
- **Not (Kalem) Modu:** Hücrelere olası aday sayıları 3x3 minik notlar halinde kaydedebilme.
- **Akıllı Vurgulama:** Seçili hücrenin satırı, sütunu, 3x3 kutusu ve aynı sayıya sahip tüm tahta hücreleri anında parlaklaşır.
- **Geri Al, Sil, İpucu & Hata Takibi:** Hamle geçmişi, yanlış hamle uyarısı ve doğrudan doğru sayıyı açan ipucu desteği.

### 8. 🔍 Sözcük Avı (12x12 Matris)
- **12x12 Harf Izgarası:** 8 farklı yönde (yatay, dikey ve 45° çapraz, ileri/geri) gizlenmiş Türkçe kelimeler.
- **Akıcı Dokunmatik Seçim:** Parmağı sürükleyerek veya başlangıç-bitiş harflerine dokunarak kelimeyi işaretleme.
- **Kalıcı Renkli Vurgular:** Bulunan her kelimeye özel renk atanır ve tahta üzerinde silinmeden korunur.
- **TDK Sözlük Anlamları:** Bulunan veya listedeki kelimelere dokunarak resmi TDK anlamını okuyabilme.
- **İpucu Sistemi:** Takıldığınızda henüz bulunmamış bir kelimenin ilk harfi tahtada altın sarısı renkle parlar.

---

## ✨ Öne Çıkan Özellikler

- ⌨️ **Ergonomik Türkçe Q Klavye:**
  - Türkçe alfabeye özel karakterler (`Ğ`, `Ü`, `Ş`, `İ`, `Ö`, `Ç`) tam entegredir.
  - **SİL** ve **GİRİŞ** butonları harflerin üst kısmındaki özel eylem barında konumlandırılmıştır; kazara basımları engeller ve rahat yazım sunar.
  - İri ve okunaklı tuş puntoları ile her ekran boyutunda parmakla kolay basım sağlar.
- 🗄️ **Yerel SQLite Veritabanı (`data/sozluk.db`):**
  - 92.408 kayıtlı kelime ve anlam.
  - `LIMIT 1 OFFSET ...` sorgu mimarisiyle 0 milisaniyede rastgele kelime seçimi.
  - İnternet bağlantısı gerektirmez; tamamen çevrimdışı çalışır.
- 🌓 **Zarif Tema Desteği:**
  - Gözü yormayan yumuşak tonlar (Adaçayı Yeşili, Bal Sarısı, Gece Grisi).
  - Tek tıkla Açık (Light) ve Koyu (Dark) mod geçişi.
- ⚡ **Yüksek Performans & Kararlılık:**
  - Android cihazlarda Impeller uyumluluğu yapılandırılmıştır.
  - Dokunsal geri bildirimler (Haptic Feedback) ile fiziksel hissiyat.

---

## 📁 Proje Dizin Yapısı

```
lib/
├── main.dart                  # Uygulama başlangıç noktası ve tema yönetimi
├── models/
│   ├── crossword_model.dart   # Çengel bulmaca veri modelleri
│   ├── game_stats.dart        # İstatistik modelleri
│   └── letter_state.dart      # Harf durumları ve kelime modelleri
├── screens/
│   ├── anagram_screen.dart    # Anagram Çözücü ekranı
│   ├── cengel_bulmaca_screen.dart # Çengel Bulmaca ekranı
│   ├── game_hub_screen.dart   # Ana Menü / Oyun Merkezi
│   ├── hangman_screen.dart    # Adam Asmaca ekranı
│   ├── islem_oyunu_screen.dart # Bir İşlem (4 İşlem Matematik) ekranı
│   ├── sudoku_screen.dart     # Sudoku (Kolay, Orta, Zor, Çok Zor) ekranı
│   ├── word_builder_screen.dart # Kelime Türetmece ekranı
│   ├── word_search_screen.dart # Sözcük Avı (12x12 Matris) ekranı
│   └── wordle_screen.dart     # Türkçe Wordle oyun ekranı
├── services/
│   ├── crossword_service.dart # Dinamik çengel bulmaca üretim motoru
│   ├── database_service.dart  # SQLite veritabanı sorguları ve önbellek
│   ├── number_puzzle_service.dart # Bir İşlem bulmaca üretimi ve çözücü motoru
│   ├── stats_service.dart     # İstatistik ve yerel kayıt servisi
│   ├── sudoku_service.dart    # Sudoku 9x9 tahta üretim ve doğrulama motoru
│   └── word_search_service.dart # 12x12 Sözcük Avı üretim motoru
├── theme/
│   └── app_theme.dart         # Renk paletleri ve stiller
├── utils/
│   └── turkish_helper.dart    # Türkçe karakter dönüşüm ve normalizasyon araçları
└── widgets/
    ├── length_selector.dart   # Harf sayısı seçici barı
    ├── stats_modal.dart       # Başarı istatistikleri penceresi
    ├── virtual_keyboard.dart  # Özelleştirilmiş Türkçe Q klavye bileşeni
    └── word_grid.dart         # Wordle ızgarası ve çevirme animasyonları
```

---

## 🚀 Kurulum ve Çalıştırma

### Gereksinimler
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.x veya üzeri)
- Dart SDK (3.x veya üzeri)
- Android Studio / VS Code / Antigravity IDE

### Adımlar

1. **Projeyi indirin ve proje dizinine geçin:**
   ```bash
   cd TurkishWordleGame
   ```

2. **Bağımlılıkları yükleyin:**
   ```bash
   flutter pub get
   ```

3. **Uygulamayı çalıştırın:**
   ```bash
   flutter run
   ```

*(Not: Windows üzerinde test ederken `sqflite_common_ffi` otomatik olarak devreye girer. Android cihazlarda yerel `data/sozluk.db` varlığı otomatik olarak cihaza kopyalanır.)*

---

## 🛠️ Kullanılan Teknolojiler

- **Framework:** Flutter & Dart
- **Veritabanı:** SQLite (`sqflite`, `sqflite_common_ffi`)
- **Dosya ve Yol Yönetimi:** `path`, `path_provider`
- **Tasarım:** Material 3, Özel Animasyonlar, Haptic Feedback

---

## 📄 Lisans
Bu proje kişisel gelişim ve eğitim amaçlı geliştirilmiştir. Kelime tanımları TDK kaynaklıdır.
