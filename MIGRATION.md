# Flutter'dan React Native'e Geçiş Notları

Bu proje, Flutter ile yazılmış Web TÜFE Mobile uygulamasının React Native versiyonudur.

## Yapılan Değişiklikler

### 1. Proje Yapısı
- Flutter'ın `lib/` klasör yapısı yerine React Native'in standart `src/` yapısı kullanıldı
- TypeScript desteği eklendi
- Modüler yapı korundu

### 2. Modeller
- Dart sınıfları TypeScript interface ve class'lara dönüştürüldü
- `TufeData`, `HarcamaGrubuData`, `MaddeData`, `OzelGostergeData` modelleri oluşturuldu

### 3. Servisler
- `CSVService`: CSV okuma ve parsing işlemleri (PapaParse kullanılıyor)
- `GitHubCSVService`: Cache yönetimi ve asset dosyası okuma (AsyncStorage kullanılıyor)

### 4. Navigasyon
- Flutter'ın `BottomNavigationBar` yerine React Navigation'ın `BottomTabNavigator` kullanıldı
- 6 sekme: Ana Sayfa, TÜFE, Ana Gruplar, Harcama Grupları, Maddeler, Özel Göstergeler

### 5. UI Bileşenleri
- Flutter widget'ları React Native bileşenlerine dönüştürüldü
- `TufeChart`: Yatay bar chart bileşeni
- Grafikler için `react-native-chart-kit` kullanılıyor

### 6. State Yönetimi
- Flutter'ın `setState` yerine React hooks (`useState`, `useEffect`) kullanılıyor

## Önemli Notlar

### CSV Dosyalarını Okuma
React Native'de asset dosyalarını okumak için birkaç seçenek var. Detaylar için `SETUP.md` dosyasına bakın.

### Eksik Implementasyonlar
Bazı sayfalar placeholder olarak oluşturuldu. Gerçek implementasyon için:
- Servislerin tam implementasyonu gerekli
- Grafik bileşenlerinin detaylandırılması gerekli
- CSV dosyalarının asset olarak eklenmesi gerekli

### Paket Bağımlılıkları
- `react-native-chart-kit`: Grafik çizimi için
- `papaparse`: CSV parsing için
- `@react-native-async-storage/async-storage`: Cache yönetimi için
- `react-native-vector-icons`: İkonlar için
- `@react-navigation/native`: Navigasyon için

## Sonraki Adımlar

1. CSV dosyalarını assets klasörüne ekleyin
2. `GitHubCSVService.loadAssetFile()` metodunu implement edin
3. Eksik servisleri tamamlayın (EndekslerService, GruplarService, vb.)
4. Grafik bileşenlerini detaylandırın
5. Test edin ve hataları düzeltin

## Flutter vs React Native Karşılaştırması

| Özellik | Flutter | React Native |
|---------|---------|--------------|
| Dil | Dart | TypeScript/JavaScript |
| UI Framework | Widget tree | Component tree |
| State Management | setState/Provider | useState/useEffect |
| Navigation | Navigator | React Navigation |
| Charts | fl_chart | react-native-chart-kit |
| Storage | SharedPreferences | AsyncStorage |
| CSV Parsing | csv package | PapaParse |

