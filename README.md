# Web TÜFE Mobile - React Native

Bu proje, webtufe.com sitesinin mobil versiyonudur. Turkish Consumer Price Index (TÜFE) verilerini görselleştiren React Native uygulamasıdır.

## Özellikler

- 📊 Aylık TÜFE değişim oranlarını yatay çubuk grafiği ile gösterir
- 📱 Mobil cihazlar için optimize edilmiş arayüz
- 📈 CSV dosyalarından veri okuma
- 🎨 Modern ve kullanıcı dostu tasarım
- 💾 Cache yönetimi ile hızlı veri yükleme

## Gereksinimler

- Node.js >= 18
- React Native CLI
- Android Studio (Android için)
- Xcode (iOS için)

## Kurulum

1. **Bağımlılıkları yükleyin**
   ```bash
   npm install
   # veya
   yarn install
   ```

2. **iOS bağımlılıklarını yükleyin (sadece macOS)**
   ```bash
   cd ios && pod install && cd ..
   ```

3. **Uygulamayı çalıştırın**

   **Android:**
   ```bash
   npm run android
   # veya
   yarn android
   ```

   **iOS:**
   ```bash
   npm run ios
   # veya
   yarn ios
   ```

## Proje Yapısı

```
src/
  ├── models/          # Veri modelleri
  ├── services/        # API ve CSV servisleri
  ├── pages/           # Sayfa bileşenleri
  ├── components/      # Yeniden kullanılabilir bileşenler
  └── App.tsx          # Ana uygulama bileşeni
```

## Kullanılan Teknolojiler

- **React Native**: Mobil uygulama framework'ü
- **TypeScript**: Tip güvenliği
- **React Navigation**: Navigasyon
- **React Native Chart Kit**: Grafik çizimi
- **AsyncStorage**: Yerel depolama
- **PapaParse**: CSV parsing

## Notlar

- CSV dosyaları assets klasöründe bulunmalıdır
- Android için `android/app/src/main/assets/` klasörüne
- iOS için proje bundle'ına eklenmelidir

## Lisans

MIT License
