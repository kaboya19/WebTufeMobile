import 'package:flutter/services.dart';
import 'package:csv/csv.dart';
import '../models/ozel_gosterge_data.dart';
import 'github_csv_service.dart';

class OzelGostergelerService {
  // Mevcut gösterge isimlerini al
  static Future<List<String>> getAvailableIndicators() async {
    try {
      final String csvData =
          await GitHubCSVService.loadCSVFromGitHub('ozel_gostergeler.csv');
      print('ozel_gostergeler.csv veri uzunluğu: ${csvData.length}');

      // Manuel olarak satırlara böl
      List<String> lines = csvData.split(RegExp(r'\r?\n'));
      print('ozel_gostergeler.csv toplam satır sayısı: ${lines.length}');

      if (lines.isEmpty) {
        throw Exception('ozel_gostergeler.csv dosyası boş');
      }

      // İlk satır header - gösterge isimleri 2. sütundan başlar
      String headerLine = lines[0];
      List<List<dynamic>> parsedHeader =
          const CsvToListConverter().convert(headerLine);
      List<dynamic> headerRow = parsedHeader.isNotEmpty ? parsedHeader[0] : [];

      List<String> indicators = [];
      // 2. sütundan başlayarak gösterge isimlerini al (index 1'den başlar)
      for (int i = 1; i < headerRow.length; i++) {
        String indicator = headerRow[i].toString().trim();
        if (indicator.isNotEmpty) {
          indicators.add(indicator);
        }
      }

      print('Bulunan göstergeler: $indicators');
      return indicators;
    } catch (e) {
      print('Göstergeler yükleme hatası: $e');
      throw Exception('Göstergeler yükleme hatası: $e');
    }
  }

  // Seçilen göstergenin günlük verilerini yükle
  static Future<OzelGostergeData> loadIndicatorData(
      String selectedIndicator) async {
    try {
      // Günlük veriler
      final dailyData = await _loadDailyData(selectedIndicator);

      // Aylık değişim verileri
      final monthlyData = await _loadMonthlyData(selectedIndicator);

      return OzelGostergeData(
        gostergeName: selectedIndicator,
        dailyValues: dailyData['values'],
        dates: dailyData['dates'],
        monthlyChanges: monthlyData['values'],
        monthlyDates: monthlyData['dates'],
      );
    } catch (e) {
      print('Gösterge verisi yükleme hatası: $e');
      throw Exception('Gösterge verisi yükleme hatası: $e');
    }
  }

  // Günlük verileri ozel_gostergeler.csv'den oku
  static Future<Map<String, dynamic>> _loadDailyData(
      String selectedIndicator) async {
    final String csvData =
        await GitHubCSVService.loadCSVFromGitHub('ozel_gostergeler.csv');

    // Manuel olarak satırlara böl
    List<String> lines = csvData.split(RegExp(r'\r?\n'));
    print('ozel_gostergeler.csv günlük veri satır sayısı: ${lines.length}');

    if (lines.isEmpty) {
      throw Exception('ozel_gostergeler.csv dosyası boş');
    }

    // Header satırından gösterge sütununu bul
    String headerLine = lines[0];
    List<List<dynamic>> parsedHeader =
        const CsvToListConverter().convert(headerLine);
    List<dynamic> headerRow = parsedHeader.isNotEmpty ? parsedHeader[0] : [];

    int indicatorColumnIndex = -1;
    for (int i = 0; i < headerRow.length; i++) {
      if (headerRow[i].toString().trim() == selectedIndicator) {
        indicatorColumnIndex = i;
        break;
      }
    }

    if (indicatorColumnIndex == -1) {
      throw Exception('Seçilen gösterge bulunamadı: $selectedIndicator');
    }

    print('Gösterge sütun indeksi: $indicatorColumnIndex');

    List<double> values = [];
    List<String> dates = [];

    // Veri satırlarını işle (1. sütun tarih, diğerleri veriler)
    for (int i = 1; i < lines.length; i++) {
      String line = lines[i].trim();
      if (line.isNotEmpty) {
        List<List<dynamic>> parsedLine =
            const CsvToListConverter().convert(line);
        if (parsedLine.isNotEmpty) {
          List<dynamic> row = parsedLine[0];

          if (row.length > indicatorColumnIndex) {
            // İlk sütun tarih
            String date = row[0].toString().trim();

            // Gösterge verisi
            String valueStr = row[indicatorColumnIndex].toString().trim();
            double value = double.tryParse(valueStr) ?? 0.0;

            if (date.isNotEmpty && value != 0.0) {
              dates.add(date);
              values.add(value);
            }
          }
        }
      }
    }

    print('Günlük veri sayısı: ${values.length}');
    return {
      'values': values,
      'dates': dates,
    };
  }

  // Aylık değişim verilerini ozelgostergeleraylik.csv'den oku
  static Future<Map<String, dynamic>> _loadMonthlyData(
      String selectedIndicator) async {
    final String csvData =
        await GitHubCSVService.loadCSVFromGitHub('ozelgostergeleraylik.csv');

    // Manuel olarak satırlara böl
    List<String> lines = csvData.split(RegExp(r'\r?\n'));
    print('ozelgostergeleraylik.csv satır sayısı: ${lines.length}');

    if (lines.isEmpty) {
      throw Exception('ozelgostergeleraylik.csv dosyası boş');
    }

    // Header satırından tarih sütunlarını al (3. sütundan başlar, index 2'den)
    String headerLine = lines[0];
    List<List<dynamic>> parsedHeader =
        const CsvToListConverter().convert(headerLine);
    List<dynamic> headerRow = parsedHeader.isNotEmpty ? parsedHeader[0] : [];

    List<String> monthlyDates = [];
    for (int i = 2; i < headerRow.length; i++) {
      String date = headerRow[i].toString().trim();
      if (date.isNotEmpty && date.contains('-')) {
        monthlyDates.add(date);
      }
    }

    // Seçilen göstergenin satırını bul (2. sütunda gösterge isimleri var)
    List<double> monthlyValues = [];

    for (int i = 1; i < lines.length; i++) {
      String line = lines[i].trim();
      if (line.isNotEmpty) {
        List<List<dynamic>> parsedLine =
            const CsvToListConverter().convert(line);
        if (parsedLine.isNotEmpty) {
          List<dynamic> row = parsedLine[0];

          if (row.length >= 2) {
            String rowIndicator = row[1].toString().trim();

            if (rowIndicator == selectedIndicator) {
              // Bu satırdan aylık değerleri al (3. sütundan başlayarak)
              for (int j = 2;
                  j < row.length && j < monthlyDates.length + 2;
                  j++) {
                double value = double.tryParse(row[j].toString()) ?? 0.0;
                monthlyValues.add(value);
              }
              break;
            }
          }
        }
      }
    }

    print('Aylık veri sayısı: ${monthlyValues.length}');
    return {
      'values': monthlyValues,
      'dates': monthlyDates,
    };
  }
}
