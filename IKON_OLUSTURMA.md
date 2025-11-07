# Özel Uygulama İkonu Oluşturma (İsteğe Bağlı)

Şu anda varsayılan Flutter ikonu kullanılıyor. Özel bir ikon için:

## Adım 1: flutter_launcher_icons Paketi Ekleyin

pubspec.yaml'a ekleyin:

```yaml
dev_dependencies:
  flutter_launcher_icons: ^0.13.1

flutter_launcher_icons:
  android: true
  ios: false
  image_path: "assets/app_icon.png"  # 512x512 veya daha büyük PNG
  adaptive_icon_background: "#FFFFFF"
  adaptive_icon_foreground: "assets/app_icon.png"
```

## Adım 2: İkon Dosyası Hazırlayın

1. 512x512 veya 1024x1024 boyutunda PNG dosyası oluşturun
2. `assets/app_icon.png` olarak kaydedin
3. Şeffaf arkaplan kullanabilirsiniz

## Adım 3: İkonları Oluşturun

```bash
flutter pub get
flutter pub run flutter_launcher_icons
```

Bu komut otomatik olarak tüm boyutlarda ikonlar oluşturur.

## Tasarım Önerileri

TÜFE/TÜİK temalı bir ikon için:
- 📊 Grafik/chart simgesi
- 📈 Yükselen trend okları
- 🇹🇷 Türkiye renkleri (kırmızı/beyaz)
- 💰 Para/ekonomi sembolleri

Online ikon oluşturma araçları:
- Canva (canva.com)
- Figma (figma.com)
- Icon Kitchen (icon.kitchen)

