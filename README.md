# Web TÜFE Mobile

Bu proje, webtufe.com sitesinin mobil versiyonudur. Turkish Consumer Price Index (TÜFE) verilerini görselleştiren Flutter uygulamasıdır.

## Özellikler

- 📊 Aylık TÜFE değişim oranlarını yatay çubuk grafiği ile gösterir
- 📱 Mobil cihazlar için optimize edilmiş arayüz
- 📈 CSV dosyalarından veri okuma
- 🎨 Web sitesine benzer tasarım

## Projeyi Çalıştırma

### Web Versiyonu
Canlı web versiyonu: https://kaboya19.github.io/WebTufeMobile/

### Lokal Geliştirme Ortamında Çalıştırma

#### Gereksinimler
1. **Flutter SDK** (3.4.3 veya üzeri)
   - Flutter'ı [flutter.dev](https://flutter.dev/docs/get-started/install) adresinden indirip yükleyin
   - Windows için: Flutter SDK'yı indirin ve PATH'e ekleyin

2. **Geliştirme Ortamı**
   - Android Studio / VS Code (Flutter eklentileri ile)
   - Veya herhangi bir kod editörü + terminal

#### Kurulum Adımları

1. **Projeyi klonlayın veya indirin**
   ```bash
   git clone https://github.com/kaboya19/WebTufeMobile.git
   cd WebTufeMobile
   ```

2. **Flutter bağımlılıklarını yükleyin**
   ```bash
   flutter pub get
   ```

3. **Flutter kurulumunu kontrol edin**
   ```bash
   flutter doctor
   ```
   Bu komut eksik bileşenleri (Android SDK, VS Code eklentileri vb.) gösterir.

4. **Uygulamayı çalıştırın**

   **Web tarayıcısında:**
   ```bash
   flutter run -d chrome
   ```
   veya
   ```bash
   flutter run -d web-server
   ```

   **Android emülatörde:**
   ```bash
   flutter run
   ```
   (Önce bir Android emülatör başlatmanız gerekir)

   **Belirli bir cihazda:**
   ```bash
   flutter devices  # Mevcut cihazları listeler
   flutter run -d <device-id>
   ```

#### Hızlı Başlangıç
```bash
# Bağımlılıkları yükle
flutter pub get

# Web'de çalıştır
flutter run -d chrome
```

## Ekran Görüntüleri

Ana ekran, TÜFE verilerini şu şekilde gösterir:
- Konut: En yüksek artış oranı (mavi)
- Web TÜFE: Genel endeks (kırmızı)
- Diğer kategoriler: Sıralı liste (mavi)

## Teknik Detaylar

### Kullanılan Paketler:
- `fl_chart`: Grafik çizimi için
- `csv`: CSV dosya okuma için
- `flutter/services`: Asset dosyalarını okuma için

### Dosya Yapısı:
```
lib/
  main.dart           # Ana uygulama kodu
assets/
  gruplaraylık.csv    # TÜFE verileri
```

## Veri Formatı

CSV dosyasının formatı:
```csv
,Grup,2025-02-28,2025-03-31,2025-04-30,2025-05-31,2025-06-30,2025-07-31
0,Alkollü içecekler ve tütün,0.012674,9.896720,0.0,0.0,0.000156,3.669694
1,Ev eşyası,5.940017,3.482335,0.878043,1.587086,0.454773,1.057602
...
```

Uygulama son sütundaki (en güncel ay) verileri okur ve görselleştirir.

## Lisans

MIT License 
