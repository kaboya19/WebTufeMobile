# Google Play Store'da Yayınlama Rehberi

## 🎯 Genel Bakış
Bu rehber, Web TÜFE Mobile uygulamasını Google Play Store'da yayınlamak için gereken tüm adımları içerir.

## 📦 Hazırlık Aşaması

### 1. Google Play Console Hesabı
- [Google Play Console](https://play.google.com/console) hesabınız yoksa oluşturun
- **$25 tek seferlik kayıt ücreti** ödemesi gereklidir
- Geliştirici hesabınızı onaylatın (1-2 gün sürebilir)

### 2. Uygulama Kaydı Oluşturma
1. Play Console'da "Tüm uygulamalar" > "Uygulama oluştur"
2. Uygulama detaylarını doldurun:
   - **Uygulama adı**: Web TÜFE Mobile
   - **Varsayılan dil**: Türkçe
   - **Uygulama veya oyun**: Uygulama
   - **Ücretsiz veya ücretli**: Ücretsiz

## 📋 Gerekli Bilgiler ve Materyaller

### A. Store Listing (Mağaza Kaydı)
Aşağıdaki bilgileri hazırlayın:

#### 1. Uygulama Açıklaması
**Kısa açıklama** (80 karakter max):
```
TÜİK TÜFE verilerini takip edin. Tüketici fiyat endeksleri, aylık değişimler ve detaylı istatistikler.
```

**Uzun açıklama** (4000 karakter max):
```
Web TÜFE Mobile, Türkiye İstatistik Kurumu (TÜİK) tarafından yayınlanan Tüketici Fiyat Endeksi (TÜFE) verilerini kolayca takip etmenizi sağlayan bir mobil uygulamadır.

📊 ÖZELLIKLER:
• Güncel TÜFE verileri
• Aylık ve yıllık değişim oranları
• Harcama grupları analizi
• Alt madde bazında detaylı veriler
• Özel göstergeler
• Grafiksel gösterimler
• Geçmiş veri karşılaştırmaları

📈 VERİ KAYNAĞI:
Tüm veriler TÜİK'in resmi kaynaklarından alınmaktadır.

💡 KULLANIM ALANLARI:
• Ekonomik araştırmalar
• Bütçe planlaması
• Yatırım kararları
• Akademik çalışmalar
• Genel bilgilendirme

Bu uygulama, TÜİK ile resmi bir bağlantısı olmayan bağımsız bir projedir.
```

#### 2. Ekran Görüntüleri
Play Store için gerekli ekran görüntüleri:
- **Telefon ekran görüntüleri**: Minimum 2, maksimum 8 adet
  - Boyut: 16:9 veya 9:16 oran
  - Minimum: 320px
  - Maksimum: 3840px
  - Format: PNG veya JPEG (24-bit RGB, alpha yok)

**Öneri**: Uygulamanın ana sayfalarından ekran görüntüleri alın:
- Ana sayfa / TÜFE verileri
- Harcama grupları sayfası
- Grafik görünümleri
- Detaylı veri tabloları

#### 3. Uygulama İkonu
- ✅ Mevcut (ic_launcher.png)
- Boyut: 512x512px
- Format: 32-bit PNG (alpha kanallı)

#### 4. Öne Çıkan Grafik (Feature Graphic)
- Boyut: 1024x500px
- Format: PNG veya JPEG
- **Önemli**: Play Store'da uygulamanızın başında görünür

### B. İçerik Derecelendirmesi
1. Play Console'da "İçerik derecelendirmesi" bölümüne gidin
2. Anketi doldurun:
   - Şiddet var mı? **Hayır**
   - Cinsellik var mı? **Hayır**
   - Küfür var mı? **Hayır**
   - Kullanıcı etkileşimi var mı? **Hayır**
   - Kişisel bilgi paylaşımı var mı? **Hayır**

### C. Hedef Kitle ve İçerik
- **Hedef yaş grubu**: 18 yaş ve üzeri
- **Kategori**: İşletme / Finans
- **İletişim bilgileri**: Email adresi (zorunlu)

### D. Gizlilik Politikası
Uygulamanız kullanıcı verisi toplamıyorsa basit bir gizlilik politikası oluşturun:

```
Bu uygulama herhangi bir kişisel veri toplamaz, saklamaz veya paylaşmaz.
Uygulama sadece TÜİK'in açık kaynaklarından alınan istatistiksel verileri gösterir.
İnternet bağlantısı sadece güncel verileri çekmek için kullanılır.
```

Bu metni bir web sayfasında yayınlayın ve URL'sini Play Console'a ekleyin.

## 🚀 Yayınlama Adımları

### ADIM 1: AAB Dosyasını Yükleme
1. Play Console'da uygulamanızı seçin
2. Sol menüden "Üretim" veya "Test" > "Sürümler" seçin
3. "Yeni sürüm oluştur" tıklayın
4. `app-release.aab` dosyasını yükleyin
5. Sürüm notları ekleyin:
```
İlk sürüm:
• TÜİK TÜFE verilerini görüntüleme
• Harcama grupları analizi
• Grafiksel gösterimler
• Aylık ve yıllık değişim takibi
```

### ADIM 2: Store Listing Tamamlama
1. "Store varlıkları" > "Ana store kaydı" bölümüne gidin
2. Tüm gerekli alanları doldurun:
   - Uygulama adı
   - Kısa açıklama
   - Uzun açıklama
   - Ekran görüntüleri (en az 2 adet)
   - Uygulama ikonu
   - Öne çıkan grafik

### ADIM 3: İçerik Derecelendirmesi
1. "İçerik derecelendirmesi" bölümüne gidin
2. Anketi tamamlayın
3. Derecelendirme sertifikalarını alın

### ADIM 4: Fiyatlandırma ve Dağıtım
1. "Fiyatlandırma ve dağıtım" bölümüne gidin
2. Ayarları yapın:
   - **Fiyat**: Ücretsiz
   - **Ülkeler**: Tüm ülkeler veya seçili ülkeler (Türkiye dahil)
   - **Cihaz kategorileri**: Telefonlar ve tabletler

### ADIM 5: Test Aşaması (İsteğe Bağlı ama Önerilen)
1. "İç test" veya "Kapalı test" oluşturun
2. Test kullanıcıları ekleyin
3. Uygulamayı test edin
4. Sorunları düzeltin

### ADIM 6: İnceleme ve Yayınlama
1. Tüm bölümlerin tamamlandığından emin olun (yeşil onay işaretleri)
2. "İncelemeyi gönder" veya "Yayınla" butonuna tıklayın
3. Google'ın inceleme sürecini bekleyin (genellikle 1-3 gün)

## ⚠️ Önemli Notlar

### Google Play İnceleme Süreci
- İlk yayın: 1-7 gün arası sürebilir
- Güncellemeler: Genellikle daha hızlıdır (1-3 gün)
- Red nedenleri: Politika ihlalleri, içerik sorunları, teknik hatalar

### Yaygın Red Nedenleri
1. **Gizlilik politikası eksik**: Mutlaka bir gizlilik politikası URL'i ekleyin
2. **Ekran görüntüleri yetersiz**: En az 2 adet kaliteli ekran görüntüsü
3. **İçerik derecelendirmesi eksik**: Anketi tamamlayın
4. **Metadata sorunları**: Açıklamalar net ve anlaşılır olmalı

### Güvenlik İpuçları
- Keystore dosyasını asla paylaşmayın veya GitHub'a yüklemeyin
- Şifreleri güvenli bir yerde saklayın (password manager)
- key.properties dosyası .gitignore'a eklendi (✅)

## 📱 Yayından Sonra

### Güncellemeler
Yeni sürüm yayınlamak için:
```bash
# pubspec.yaml'da versiyon numarasını artırın
version: 1.0.21+21

# Yeni AAB oluşturun
flutter clean
flutter build appbundle --release

# Play Console'da yeni sürüm yükleyin
```

### Kullanıcı Geri Bildirimleri
- Play Console'dan kullanıcı yorumlarını takip edin
- Crash raporlarını inceleyin
- Analytics verilerini değerlendirin

### İstatistikler
Play Console'da şunları görebilirsiniz:
- Uygulama yüklemeleri
- Aktif kullanıcılar
- Derecelendirmeler ve yorumlar
- Crash oranları
- Kullanıcı tutma oranı

## 🆘 Yardım ve Destek

### Yararlı Linkler
- [Google Play Console](https://play.google.com/console)
- [Play Console Yardım Merkezi](https://support.google.com/googleplay/android-developer)
- [Flutter Release Dokümantasyonu](https://flutter.dev/docs/deployment/android)

### Sorun Yaşarsanız
1. Build hataları için: BUILD_RELEASE.md dosyasını kontrol edin
2. Play Console sorunları için: Google Play Desteği ile iletişime geçin
3. Flutter sorunları için: [Flutter GitHub Issues](https://github.com/flutter/flutter/issues)

---

**Başarılar! 🚀**

