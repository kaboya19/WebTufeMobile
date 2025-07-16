import 'package:flutter/services.dart';
import 'package:csv/csv.dart';

class TuikService {
  static Future<Map<String, dynamic>> loadTuikAylikData() async {
    try {
      final csvData = await rootBundle.loadString('assets/tuikaylik.csv');
      List<String> lines = csvData.split(RegExp(r'\r?\n'));

      if (lines.isEmpty) return {'dates': [], 'data': {}};

      // Header satırından tarih sütunlarını al
      List<List<dynamic>> parsedHeader =
          const CsvToListConverter().convert(lines[0]);
      List<dynamic> headerRow = parsedHeader.isNotEmpty ? parsedHeader[0] : [];

      // "Genel" sütununun indeksini bul
      int genelColumnIndex = -1;
      for (int i = 0; i < headerRow.length; i++) {
        if (headerRow[i].toString().trim() == 'Genel') {
          genelColumnIndex = i;
          break;
        }
      }

      if (genelColumnIndex == -1) {
        print('Genel sütunu bulunamadı');
        return {'dates': [], 'data': {}};
      }

      List<String> dates = [];
      List<double> genelValues = [];

      // Tarih ve değer satırlarını oku
      for (int i = 1; i < lines.length; i++) {
        if (lines[i].trim().isEmpty) continue;

        List<List<dynamic>> parsedLine =
            const CsvToListConverter().convert(lines[i]);
        if (parsedLine.isNotEmpty) {
          List<dynamic> row = parsedLine[0];
          if (row.length > genelColumnIndex) {
            // İlk sütun tarih
            String date = row[0].toString().trim();
            // Genel sütunundaki değer
            double value =
                double.tryParse(row[genelColumnIndex].toString()) ?? 0.0;

            dates.add(date);
            genelValues.add(value);
          }
        }
      }

      return {
        'dates': dates,
        'data': {
          'TÜİK TÜFE': genelValues,
        }
      };
    } catch (e) {
      print('TÜİK aylık veri yükleme hatası: $e');
      return {'dates': [], 'data': {}};
    }
  }

  // Ana grup için TÜİK verisi
  static Future<Map<String, dynamic>> loadTuikAnaGrupData(
      String anaGrupAdi) async {
    try {
      final csvData = await rootBundle.loadString('assets/tuikaylik.csv');
      List<String> lines = csvData.split(RegExp(r'\r?\n'));

      if (lines.isEmpty) return {'dates': [], 'data': {}};

      // Header satırından sütunları al
      List<List<dynamic>> parsedHeader =
          const CsvToListConverter().convert(lines[0]);
      List<dynamic> headerRow = parsedHeader.isNotEmpty ? parsedHeader[0] : [];

      // Ana grup ismi mapping'i - web sistemindeki isimlerden TÜİK CSV'sindeki isimlere
      Map<String, String> grupMapping = {
        'Gıda ve alkolsüz içecekler': 'Gıda ve alkolsüz içecekler',
        'Alkollü içecekler ve tütün': 'Alkollü içecekler ve tütün',
        'Giyim ve ayakkabı': 'Giyim ve ayakkabı',
        'Konut, su, elektrik, gaz ve diğer yakıtlar': 'Konut',
        'Mobilya, ev aletleri ve ev bakım hizmetleri': 'Ev eşyası',
        'Sağlık': 'Sağlık',
        'Ulaştırma': 'Ulaştırma',
        'Haberleşme': 'Haberleşme',
        'Eğlence ve kültür': 'Eğlence ve kültür',
        'Eğitim': 'Eğitim',
        'Lokanta ve oteller': 'Lokanta ve oteller',
        'Çeşitli mal ve hizmetler': 'Çeşitli mal ve hizmetler',
      };

      // Mapping'den TÜİK sütun adını al
      String tuikColumnName = grupMapping[anaGrupAdi] ?? anaGrupAdi;

      // TÜİK sütununun indeksini bul
      int tuikColumnIndex = -1;
      for (int i = 0; i < headerRow.length; i++) {
        if (headerRow[i].toString().trim() == tuikColumnName) {
          tuikColumnIndex = i;
          break;
        }
      }

      if (tuikColumnIndex == -1) {
        print('TÜİK sütunu bulunamadı: $tuikColumnName');
        return {'dates': [], 'data': {}};
      }

      List<String> dates = [];
      List<double> tuikValues = [];

      // Tarih ve değer satırlarını oku
      for (int i = 1; i < lines.length; i++) {
        if (lines[i].trim().isEmpty) continue;

        List<List<dynamic>> parsedLine =
            const CsvToListConverter().convert(lines[i]);
        if (parsedLine.isNotEmpty) {
          List<dynamic> row = parsedLine[0];
          if (row.length > tuikColumnIndex) {
            // İlk sütun tarih
            String date = row[0].toString().trim();
            // TÜİK sütunundaki değer
            double value =
                double.tryParse(row[tuikColumnIndex].toString()) ?? 0.0;

            dates.add(date);
            tuikValues.add(value);
          }
        }
      }

      return {
        'dates': dates,
        'data': {
          'TÜİK $anaGrupAdi': tuikValues,
        }
      };
    } catch (e) {
      print('TÜİK ana grup veri yükleme hatası: $e');
      return {'dates': [], 'data': {}};
    }
  }

  // Harcama grubu için TÜİK verisi
  static Future<Map<String, dynamic>> loadTuikHarcamaGrubuData(
      String harcamaGrubuAdi) async {
    try {
      final csvData = await rootBundle.loadString('assets/tuikaylik.csv');
      List<String> lines = csvData.split(RegExp(r'\r?\n'));

      if (lines.isEmpty) return {'dates': [], 'data': {}};

      // Header satırından sütunları al
      List<List<dynamic>> parsedHeader =
          const CsvToListConverter().convert(lines[0]);
      List<dynamic> headerRow = parsedHeader.isNotEmpty ? parsedHeader[0] : [];

      // Harcama grubu ismi mapping'i - web sistemindeki isimlerden TÜİK CSV'sindeki isimlere
      Map<String, String> harcamaGrupMapping = {
        // Gıda grupları
        'Pirinç': 'Pirinç',
        'Un ve diğer tahıllar': 'Un ve diğer tahıllar',
        'Ekmek': 'Ekmek',
        'Diğer fırıncılık ürünleri (bisküvi, kek, kraker, yufka, baklava vb.)':
            'Diğer fırıncılık ürünleri (bisküvi, kek, kraker, yufka, baklava vb.)',
        'Makarna çeşitleri': 'Makarna çeşitleri',
        'Kahvaltılık tahıl ürünleri': 'Kahvaltılık tahıl ürünleri',
        'Dana eti': 'Dana eti',
        'Kuzu eti': 'Kuzu eti',
        'Tavuk eti': 'Tavuk eti',
        'Diğer etler ve yenilebilir sakatatlar':
            'Diğer etler ve yenilebilir sakatatlar',
        'Şarküteri ürünleri (sucuk, sosis, salam vb.)':
            'Şarküteri ürünleri (sucuk, sosis, salam vb.)',
        'Taze balık': 'Taze balık',
        'Konserve edilmiş veya işlenmiş balık':
            'Konserve edilmiş veya işlenmiş balık',
        'Süt': 'Süt',
        'Diğer süt ürünleri (yoğurt, hazır sütlü tatlı vb.)':
            'Diğer süt ürünleri (yoğurt, hazır sütlü tatlı vb.)',
        'Peynir': 'Peynir',
        'Yumurta': 'Yumurta',
        'Tereyağı': 'Tereyağı',
        'Margarin': 'Margarin',
        'Sıvı yağlar (zeytinyağı, ayçiçek yağı)':
            'Sıvı yağlar (zeytinyağı, ayçiçek yağı)',
        'Taze meyveler': 'Taze meyveler',
        'Kuru meyve ve sert kabuklu yemişler':
            'Kuru meyve ve sert kabuklu yemişler',
        'Taze sebzeler (patates hariç)': 'Taze sebzeler (patates hariç)',
        'Patates': 'Patates',
        'Kuru baklagiller': 'Kuru baklagiller',
        'Konserve edilmiş veya işlenmiş sebze içerikli ürünler (salça, turşu, zeytin vb. dahil)':
            'Konserve edilmiş veya işlenmiş sebze içerikli ürünler (salça, turşu, zeytin vb. dahil)',
        'Şeker': 'Şeker',
        'Reçel, marmelat, bal vb. ürünler': 'Reçel, marmelat, bal vb. ürünler',
        'Çikolata ve şekerlemeler': 'Çikolata ve şekerlemeler',
        'Dondurma': 'Dondurma',
        'Başka yerde sınıflandırılamayan diğer gıda ürünleri (tuz, sirke, ketçap, mayonez vb.)':
            'Başka yerde sınıflandırılamayan diğer gıda ürünleri (tuz, sirke, ketçap, mayonez vb.)',
        'Kahve': 'Kahve',
        'Çay ve bitki çayları': 'Çay ve bitki çayları',
        'Toz kakao': 'Toz kakao',
        'Su ve maden suyu': 'Su ve maden suyu',
        'Alkolsüz içecekler (meşrubat, ayran vb.)':
            'Alkolsüz içecekler (meşrubat, ayran vb.)',
        'Meyve ve sebze suları': 'Meyve ve sebze suları',
        'Alkollü içecekler (rakı, viski, votka vb.)':
            'Alkollü içecekler (rakı, viski, votka vb.)',
        'Şarap': 'Şarap',
        'Bira': 'Bira',
        'Sigaralar': 'Sigaralar',
        // Giyim ve ayakkabı grupları
        'Erkek giyim': 'Erkek giyim',
        'Kadın giyim': 'Kadın giyim',
        'Çocuk giyim': 'Çocuk giyim',
        'Bebek giyim': 'Bebek giyim',
        'Diğer giyim eşyaları ve aksesuarları (kravat, kemer, eşarp vb.)':
            'Diğer giyim eşyaları ve aksesuarları (kravat, kemer, eşarp vb.)',
        'Giyim eşyalarının temizlenmesi ve tadilatı':
            'Giyim eşyalarının temizlenmesi ve tadilatı',
        'Erkek ayakkabısı': 'Erkek ayakkabısı',
        'Kadın ayakkabısı': 'Kadın ayakkabısı',
        // Diğer gruplar gerektiğinde eklenebilir
      };

      // Mapping'den TÜİK sütun adını al
      String tuikColumnName =
          harcamaGrupMapping[harcamaGrubuAdi] ?? harcamaGrubuAdi;

      // TÜİK sütununun indeksini bul
      int tuikColumnIndex = -1;
      for (int i = 0; i < headerRow.length; i++) {
        if (headerRow[i].toString().trim() == tuikColumnName) {
          tuikColumnIndex = i;
          break;
        }
      }

      if (tuikColumnIndex == -1) {
        print('TÜİK sütunu bulunamadı: $tuikColumnName');
        return {'dates': [], 'data': {}};
      }

      List<String> dates = [];
      List<double> tuikValues = [];

      // Tarih ve değer satırlarını oku
      for (int i = 1; i < lines.length; i++) {
        if (lines[i].trim().isEmpty) continue;

        List<List<dynamic>> parsedLine =
            const CsvToListConverter().convert(lines[i]);
        if (parsedLine.isNotEmpty) {
          List<dynamic> row = parsedLine[0];
          if (row.length > tuikColumnIndex) {
            // İlk sütun tarih
            String date = row[0].toString().trim();
            // TÜİK sütunundaki değer
            double value =
                double.tryParse(row[tuikColumnIndex].toString()) ?? 0.0;

            dates.add(date);
            tuikValues.add(value);
          }
        }
      }

      return {
        'dates': dates,
        'data': {
          'TÜİK $harcamaGrubuAdi': tuikValues,
        }
      };
    } catch (e) {
      print('TÜİK harcama grubu veri yükleme hatası: $e');
      return {'dates': [], 'data': {}};
    }
  }

  // Özel gösterge için TÜİK verisi
  static Future<Map<String, dynamic>> loadTuikOzelGostergeData(
      String ozelGostergeAdi) async {
    try {
      final csvData =
          await rootBundle.loadString('assets/tuikozelgostergeler.csv');
      List<String> lines = csvData.split(RegExp(r'\r?\n'));

      if (lines.isEmpty) return {'dates': [], 'data': {}};

      // Header satırından sütunları al
      List<List<dynamic>> parsedHeader =
          const CsvToListConverter().convert(lines[0]);
      List<dynamic> headerRow = parsedHeader.isNotEmpty ? parsedHeader[0] : [];

      // Özel gösterge ismi mapping'i - web sistemindeki isimlerden TÜİK CSV'sindeki isimlere
      Map<String, String> ozelGostergeMapping = {
        'Mevsimlik Ürünler Hariç TÜFE': 'Mevsimlik Ürünler Hariç TÜFE',
        'TÜFE B': 'TÜFE B',
        'TÜFE C': 'TÜFE C',
        'TÜFE D': 'TÜFE D',
        'TÜFE E': 'TÜFE E',
        'TÜFE F': 'TÜFE F',
        'Mallar': 'Mallar',
        'Enerji': 'Enerji',
        'Gıda ve alkolsüz içecekler': 'Gıda ve alkolsüz içecekler',
        'Taze meyve ve sebze': 'Taze meyve ve sebze',
        'İşlenmemiş gıda': 'İşlenmemiş gıda',
        'Diğer işlenmemiş gıda': 'Diğer işlenmemiş gıda',
        'İşlenmiş Gıda': 'İşlenmiş Gıda',
        'Ekmek ve tahıllar': 'Ekmek ve tahıllar',
        'Diğer işlenmiş gıda': 'Diğer işlenmiş gıda',
        'Enerji ve gıda dışı mallar': 'Enerji ve gıda dışı mallar',
        'Temel mallar': 'Temel mallar',
        'Giyim ve ayakkabı': 'Giyim ve ayakkabı',
        'Dayanıklı Mallar (altın hariç)': 'Dayanıklı Mallar (altın hariç)',
        'Diğer Temel Mallar': 'Diğer Temel Mallar',
        'Alkollü içecekler, tütün ve altın':
            'Alkollü içecekler, tütün ve altın',
        'Hizmet': 'Hizmet',
        'Kira': 'Kira',
        'Lokanta ve oteller': 'Lokanta ve oteller',
        'Ulaştırma hizmetleri': 'Ulaştırma hizmetleri',
        'Haberleşme hizmetleri': 'Haberleşme hizmetleri',
        'Diğer hizmetler': 'Diğer hizmetler',
        'TÜFE': 'TÜFE',
      };

      // Mapping'den TÜİK sütun adını al
      String tuikColumnName =
          ozelGostergeMapping[ozelGostergeAdi] ?? ozelGostergeAdi;

      // TÜİK sütununun indeksini bul
      int tuikColumnIndex = -1;
      for (int i = 0; i < headerRow.length; i++) {
        if (headerRow[i].toString().trim() == tuikColumnName) {
          tuikColumnIndex = i;
          break;
        }
      }

      if (tuikColumnIndex == -1) {
        print('TÜİK özel gösterge sütunu bulunamadı: $tuikColumnName');
        return {'dates': [], 'data': {}};
      }

      List<String> dates = [];
      List<double> tuikValues = [];

      // Tarih ve değer satırlarını oku
      for (int i = 1; i < lines.length; i++) {
        if (lines[i].trim().isEmpty) continue;

        List<List<dynamic>> parsedLine =
            const CsvToListConverter().convert(lines[i]);
        if (parsedLine.isNotEmpty) {
          List<dynamic> row = parsedLine[0];
          if (row.length > tuikColumnIndex) {
            // İlk sütun tarih
            String date = row[0].toString().trim();
            // TÜİK sütunundaki değer
            double value =
                double.tryParse(row[tuikColumnIndex].toString()) ?? 0.0;

            dates.add(date);
            tuikValues.add(value);
          }
        }
      }

      return {
        'dates': dates,
        'data': {
          'TÜİK $ozelGostergeAdi': tuikValues,
        }
      };
    } catch (e) {
      print('TÜİK özel gösterge veri yükleme hatası: $e');
      return {'dates': [], 'data': {}};
    }
  }
}
