# Play Store İçin Release Build Oluşturma

## Ön Hazırlık
1. ✅ Keystore dosyası oluşturuldu (upload-keystore.jks)
2. ✅ key.properties dosyası yapılandırıldı
3. ✅ build.gradle.kts güncellendi

## Release Build Komutları

### AAB (Android App Bundle) Oluşturma (ÖNERİLEN)
Play Store için AAB formatı tercih edilir:

```bash
flutter clean
flutter build appbundle --release
```

Build başarılı olursa, AAB dosyası şu konumda olacak:
`build/app/outputs/bundle/release/app-release.aab`

### APK Oluşturma (Alternatif)
Eğer APK istiyorsanız:

```bash
flutter clean
flutter build apk --release
```

APK dosyası şu konumda olacak:
`build/app/outputs/flutter-apk/app-release.apk`

## Build Sonrası Kontroller

1. **Dosya Boyutu Kontrolü**: AAB dosyası oluştu mu?
2. **İmza Kontrolü**: Dosya düzgün imzalandı mı?
3. **Test**: APK'yı gerçek cihazda test edin

## Olası Hatalar ve Çözümleri

### Hata: "key.properties not found"
**Çözüm**: android/key.properties dosyasının olduğundan ve doğru yapılandırıldığından emin olun

### Hata: "Keystore file not found"
**Çözüm**: upload-keystore.jks dosyasının android klasöründe olduğundan emin olun

### Hata: "Wrong password"
**Çözüm**: key.properties dosyasındaki şifreleri kontrol edin

## Sonraki Adımlar

1. AAB dosyasını Google Play Console'a yükleyin
2. Store listing bilgilerini doldurun
3. Ekran görüntüleri ve açıklamalar ekleyin
4. İçerik derecelendirmesi yapın
5. Test grubu oluşturun (İsteğe bağlı)
6. Yayınlayın!

