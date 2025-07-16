# Web TÜFE Mobile

Bu proje, webtufe.com sitesinin mobil versiyonudur. Turkish Consumer Price Index (TÜFE) verilerini görselleştiren Flutter uygulamasıdır.

## Özellikler

- 📊 Aylık TÜFE değişim oranlarını yatay çubuk grafiği ile gösterir
- 📱 Mobil cihazlar için optimize edilmiş arayüz
- 📈 CSV dosyalarından veri okuma
- 🎨 Web sitesine benzer tasarım

## Projeyi Çalıştırma
https://kaboya19.github.io/WebTufeMobile/
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
