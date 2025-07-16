import 'package:flutter/services.dart';
import 'package:csv/csv.dart';
import '../models/harcama_grubu_data.dart';
import 'github_csv_service.dart';

class HarcamaGruplariService {
  // Ana grupları gruplar.csv'den okuyacağız
  static Future<List<AnaGrupData>> loadAnaGruplar() async {
    try {
      final String csvData =
          await GitHubCSVService.loadCSVFromGitHub('gruplar.csv');
      print('CSV veri uzunluğu: ${csvData.length}');

      // Manuel olarak satırlara böl - farklı satır sonu karakterlerini handle et
      List<String> lines = csvData.split(RegExp(r'\r?\n'));
      print('Toplam satır sayısı: ${lines.length}');

      if (lines.isEmpty) {
        throw Exception('gruplar.csv dosyası boş');
      }

      List<AnaGrupData> anaGruplar = [];

      // İlk satır header, ikinci satırdan itibaren ana grup isimleri (ilk sütunda)
      for (int i = 1; i < lines.length; i++) {
        String line = lines[i].trim();
        if (line.isNotEmpty) {
          // Her satırı ayrı ayrı CSV olarak parse et
          List<List<dynamic>> parsedLine =
              const CsvToListConverter().convert(line);
          if (parsedLine.isNotEmpty && parsedLine[0].isNotEmpty) {
            String anaGrupAdi = parsedLine[0][0].toString().trim();
            if (anaGrupAdi.isNotEmpty) {
              anaGruplar.add(AnaGrupData(name: anaGrupAdi));
            }
          }
        }
      }

      print('Yüklenen ana gruplar: ${anaGruplar.map((e) => e.name).toList()}');
      return anaGruplar;
    } catch (e) {
      throw Exception('Ana gruplar yükleme hatası: $e');
    }
  }

  // Seçilen ana gruba ait harcama gruplarını ürünler.csv'den okuyacağız
  static Future<List<String>> loadHarcamaGruplari(
      String selectedAnaGrup) async {
    try {
      final String csvData =
          await GitHubCSVService.loadCSVFromGitHub('urunler.csv');
      print('urunler.csv veri uzunluğu: ${csvData.length}');

      // Manuel olarak satırlara böl (line ending sorunları için)
      List<String> lines = csvData.split(RegExp(r'\r?\n'));
      print('urunler.csv toplam satır sayısı: ${lines.length}');

      List<List<dynamic>> rows = [];
      for (String line in lines) {
        if (line.trim().isNotEmpty) {
          List<dynamic> row = const CsvToListConverter().convert(line).first;
          rows.add(row);
        }
      }
      print('İşlenen satır sayısı: ${rows.length}');

      if (rows.isEmpty) {
        throw Exception('urunler.csv dosyası boş');
      }

      Set<String> harcamaGruplari = {};
      String selectedGroupNorm = selectedAnaGrup.trim().toLowerCase();
      print('Aranan ana grup (normalize): $selectedGroupNorm');

      // İlk satır header, ondan sonraki satırları işle
      int matchCount = 0;
      for (int i = 1; i < rows.length; i++) {
        if (rows[i].length >= 6) {
          String anaGrup =
              rows[i][5].toString().trim().toLowerCase(); // Ana Grup sütunu
          String grup = rows[i][2].toString().trim(); // Grup sütunu

          // İlk birkaç eşleşme için debug
          if (anaGrup == selectedGroupNorm && matchCount < 5) {
            print(
                'Eşleşen satır ${i}: Ana Grup="${rows[i][5]}", Grup="${rows[i][2]}"');
            matchCount++;
          }

          if (anaGrup == selectedGroupNorm && grup.isNotEmpty) {
            harcamaGruplari.add(grup);
          }
        }
      }

      print('Bulunan harcama grupları sayısı: ${harcamaGruplari.length}');
      print('Harcama grupları listesi: ${harcamaGruplari.toList()}');

      return harcamaGruplari.toList();
    } catch (e) {
      print('Harcama grupları yükleme hatası: $e');
      throw Exception('Harcama grupları yükleme hatası: $e');
    }
  }

  // Harcama gruplarının değişim oranlarını harcama_gruplarıaylık.csv'den okuyacağız
  static Future<List<HarcamaGrubuData>> loadHarcamaGrubuDegiisimOranlari(
      List<String> harcamaGruplari, String selectedDate) async {
    try {
      final String csvData =
          await GitHubCSVService.loadCSVFromGitHub('harcama_gruplarıaylık.csv');

      // Manuel olarak satırlara böl
      List<String> lines = csvData.split(RegExp(r'\r?\n'));

      if (lines.isEmpty) {
        throw Exception('harcama_gruplarıaylık.csv dosyası boş');
      }

      // Header satırını parse et
      List<List<dynamic>> parsedHeader =
          const CsvToListConverter().convert(lines[0]);
      List<dynamic> headerRow = parsedHeader.isNotEmpty ? parsedHeader[0] : [];
      if (headerRow.isEmpty) {
        throw Exception('Header satırı parse edilemedi');
      }

      // Header satırından tarih sütununu bul
      List<dynamic> headers = headerRow;
      int dateColumnIndex = -1;

      for (int i = 0; i < headers.length; i++) {
        if (headers[i].toString().trim() == selectedDate) {
          dateColumnIndex = i;
          break;
        }
      }

      if (dateColumnIndex == -1) {
        throw Exception('Seçilen tarih bulunamadı: $selectedDate');
      }

      List<HarcamaGrubuData> result = [];

      // Harcama gruplarını normalize et
      Set<String> normalizedHarcamaGruplari =
          harcamaGruplari.map((grup) => grup.trim().toLowerCase()).toSet();

      // CSV'den verileri oku (header hariç)
      for (int i = 1; i < lines.length; i++) {
        String line = lines[i].trim();
        if (line.isNotEmpty) {
          List<List<dynamic>> parsedLine =
              const CsvToListConverter().convert(line);
          if (parsedLine.isNotEmpty && parsedLine[0].length > dateColumnIndex) {
            List<dynamic> row = parsedLine[0];
            String grupAdi = row[1].toString().trim();
            String normalizedGrupAdi = grupAdi.toLowerCase();

            if (normalizedHarcamaGruplari.contains(normalizedGrupAdi)) {
              double changeRate =
                  double.tryParse(row[dateColumnIndex].toString()) ?? 0.0;
              result.add(HarcamaGrubuData(
                groupName: grupAdi,
                changeRate: changeRate,
              ));
            }
          }
        }
      }

      // Değişim oranına göre sırala (büyükten küçüğe)
      result.sort((a, b) => b.changeRate.compareTo(a.changeRate));

      return result;
    } catch (e) {
      throw Exception('Harcama grubu değişim oranları yükleme hatası: $e');
    }
  }

  // Mevcut tarihleri al
  static Future<List<String>> getAvailableDates() async {
    try {
      final String csvData =
          await GitHubCSVService.loadCSVFromGitHub('harcama_gruplarıaylık.csv');

      // Manuel olarak satırlara böl
      List<String> lines = csvData.split(RegExp(r'\r?\n'));

      if (lines.isEmpty) {
        throw Exception('harcama_gruplarıaylık.csv dosyası boş');
      }

      // İlk satırı parse et (header)
      List<List<dynamic>> parsedHeader =
          const CsvToListConverter().convert(lines[0]);
      if (parsedHeader.isEmpty) {
        throw Exception('Header satırı parse edilemedi');
      }

      List<String> dates = [];
      List<dynamic> headers = parsedHeader[0];

      // İlk 2 sütun (index ve grup adı) hariç diğerleri tarih
      for (int i = 2; i < headers.length; i++) {
        String date = headers[i].toString().trim();
        if (date.isNotEmpty) {
          dates.add(date);
        }
      }

      return dates;
    } catch (e) {
      throw Exception('Tarihler yükleme hatası: $e');
    }
  }

  // Harcama grubu endeks verilerini harcama_grupları.csv'den oku
  static Future<List<HarcamaGrubuEndeksData>> loadHarcamaGrubuEndeksData(
      String selectedGrup) async {
    try {
      final String csvData =
          await GitHubCSVService.loadCSVFromGitHub('harcama_grupları.csv');

      // Manuel olarak satırlara böl
      List<String> lines = csvData.split(RegExp(r'\r?\n'));

      if (lines.isEmpty) {
        throw Exception('harcama_grupları.csv dosyası boş');
      }

      // Header satırını parse et - ürün/harcama grubu adları sütun başlıkları
      List<List<dynamic>> parsedHeader =
          const CsvToListConverter().convert(lines[0]);
      List<dynamic> headerRow = parsedHeader.isNotEmpty ? parsedHeader[0] : [];
      if (headerRow.isEmpty) {
        throw Exception('Header satırı parse edilemedi');
      }

      // Seçilen harcama grubunun sütun indeksini bul
      int targetColumnIndex = -1;
      String normalizedSelectedGrup = selectedGrup.trim().toLowerCase();

      for (int i = 1; i < headerRow.length; i++) {
        // İlk sütun tarih, 1'den başla
        String columnName = headerRow[i].toString().trim().toLowerCase();
        if (columnName == normalizedSelectedGrup) {
          targetColumnIndex = i;
          break;
        }
      }

      if (targetColumnIndex == -1) {
        throw Exception(
            'Seçilen harcama grubu sütunu bulunamadı: $selectedGrup');
      }

      print('Harcama grubu sütun indeksi: $targetColumnIndex');

      List<HarcamaGrubuEndeksData> endeksData = [];

      // Veri satırlarını işle (header hariç)
      for (int i = 1; i < lines.length; i++) {
        String line = lines[i].trim();
        if (line.isNotEmpty) {
          List<List<dynamic>> parsedLine =
              const CsvToListConverter().convert(line);
          if (parsedLine.isNotEmpty &&
              parsedLine[0].length > targetColumnIndex) {
            List<dynamic> row = parsedLine[0];
            String tarih = row[0].toString().trim(); // İlk sütun tarih
            double endeks =
                double.tryParse(row[targetColumnIndex].toString()) ?? 0.0;

            if (tarih.isNotEmpty && endeks > 0) {
              endeksData.add(HarcamaGrubuEndeksData(
                tarih: tarih,
                endeks: endeks,
              ));
            }
          }
        }
      }

      print('Endeks veri sayısı: ${endeksData.length}');
      return endeksData;
    } catch (e) {
      throw Exception('Harcama grubu endeks verisi yükleme hatası: $e');
    }
  }

  // Harcama grubu aylık değişim verilerini harcama_gruplarıaylık.csv'den oku
  static Future<List<HarcamaGrubuAylikData>> loadHarcamaGrubuAylikData(
      String selectedGrup) async {
    try {
      final String csvData =
          await GitHubCSVService.loadCSVFromGitHub('harcama_gruplarıaylık.csv');

      // Manuel olarak satırlara böl
      List<String> lines = csvData.split(RegExp(r'\r?\n'));

      if (lines.isEmpty) {
        throw Exception('harcama_gruplarıaylık.csv dosyası boş');
      }

      // Header satırını parse et
      List<List<dynamic>> parsedHeader =
          const CsvToListConverter().convert(lines[0]);
      List<dynamic> headerRow = parsedHeader.isNotEmpty ? parsedHeader[0] : [];
      if (headerRow.isEmpty) {
        throw Exception('Header satırı parse edilemedi');
      }

      // Seçilen harcama grubunun satırını bul
      int targetRowIndex = -1;
      String normalizedSelectedGrup = selectedGrup.trim().toLowerCase();

      for (int i = 1; i < lines.length; i++) {
        String line = lines[i].trim();
        if (line.isNotEmpty) {
          List<List<dynamic>> parsedLine =
              const CsvToListConverter().convert(line);
          if (parsedLine.isNotEmpty && parsedLine[0].length > 1) {
            String grupAdi = parsedLine[0][1].toString().trim().toLowerCase();
            if (grupAdi == normalizedSelectedGrup) {
              targetRowIndex = i;
              break;
            }
          }
        }
      }

      if (targetRowIndex == -1) {
        throw Exception('Seçilen harcama grubu bulunamadı: $selectedGrup');
      }

      // Hedef satırı parse et
      List<List<dynamic>> parsedTargetLine =
          const CsvToListConverter().convert(lines[targetRowIndex]);
      List<dynamic> targetRow = parsedTargetLine[0];

      List<HarcamaGrubuAylikData> aylikData = [];

      // Header'dan tarihleri al ve karşılık gelen değişim oranlarını çıkar
      for (int i = 2; i < headerRow.length && i < targetRow.length; i++) {
        String tarih = headerRow[i].toString().trim();
        double degisimOrani = double.tryParse(targetRow[i].toString()) ?? 0.0;

        if (tarih.isNotEmpty) {
          aylikData.add(HarcamaGrubuAylikData(
            tarih: tarih,
            degisimOrani: degisimOrani,
          ));
        }
      }

      return aylikData;
    } catch (e) {
      throw Exception('Harcama grubu aylık değişim verisi yükleme hatası: $e');
    }
  }

  // Harcama grubu istatistiklerini hesapla - sadece aylık veriden
  static Future<HarcamaGrubuIstatistik> calculateHarcamaGrubuStatistics(
      String selectedGrup) async {
    try {
      // Endeks ve aylık verilerini al
      final endeksData = await loadHarcamaGrubuEndeksData(selectedGrup);
      final aylikData = await loadHarcamaGrubuAylikData(selectedGrup);

      if (endeksData.isEmpty || aylikData.isEmpty) {
        throw Exception('Yeterli veri bulunamadı');
      }

      // En son aylık değişim (son tarih)
      double aylikDegisim = aylikData.last.degisimOrani;

      // Yıllık değişim hesaplama - endeks verilerinden yılbaşından bu yana
      double yillikDegisim = 0.0;

      // Endeks verilerinden yılbaşından bu yana değişimi hesapla
      if (endeksData.length >= 2) {
        double ilkEndeks = endeksData.first.endeks;
        double sonEndeks = endeksData.last.endeks;

        if (ilkEndeks > 0) {
          yillikDegisim = ((sonEndeks - ilkEndeks) / ilkEndeks) * 100;
        }
      }

      return HarcamaGrubuIstatistik(
        yillikDegisim: yillikDegisim,
        aylikDegisim: aylikDegisim,
        selectedGrup: selectedGrup,
      );
    } catch (e) {
      throw Exception('İstatistik hesaplama hatası: $e');
    }
  }
}
