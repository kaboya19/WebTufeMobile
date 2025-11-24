import 'package:flutter/services.dart';
import 'package:csv/csv.dart';
import '../models/tufe_data.dart';
import 'github_csv_service.dart';

class CSVService {
  static Future<List<TufeData>> loadTufeData() async {
    try {
      final String csvData = await GitHubCSVService.loadCSVFromGitHub(
          'gruplaraylik.csv',
          useCache: false);
      print('CSV parse ediliyor... Uzunluk: ${csvData.length}');

      // Manuel olarak satırlara böl
      List<String> lines = csvData.split(RegExp(r'\r?\n'));
      print('Manuel satır sayısı: ${lines.length}');

      // Her satırı ayrı ayrı CSV olarak parse et
      List<List<dynamic>> rows = [];
      for (int i = 0; i < lines.length; i++) {
        String line = lines[i].trim();
        if (line.isNotEmpty) {
          try {
            List<List<dynamic>> parsedLine =
                const CsvToListConverter().convert(line);
            if (parsedLine.isNotEmpty) {
              rows.add(parsedLine[0]);
              print('Satır $i parse edildi: ${parsedLine[0].length} sütun');
            }
          } catch (e) {
            print('Satır $i parse hatası: $e');
          }
        }
      }

      print('Başarıyla parse edilen satır sayısı: ${rows.length}');

      if (rows.isNotEmpty) {
        print('Header satırı: ${rows[0]}');
        if (rows.length > 1) {
          print('İlk veri satırı: ${rows[1]}');
        }
      }

      if (rows.isEmpty) {
        throw Exception('CSV dosyası boş');
      }

      List<TufeData> tufeDataList = [];

      // İlk satır header, ondan sonraki satırları işle
      for (int i = 1; i < rows.length; i++) {
        if (rows[i].length < 2) {
          print('Geçersiz satır $i: ${rows[i]}');
          continue; // Geçersiz satırları atla
        }

        String groupName = rows[i][1].toString().trim();
        print('Satır $i - Grup: "$groupName", Uzunluk: ${rows[i].length}');

        if (groupName.isEmpty) {
          print('Boş grup adı, atlaniyor');
          continue;
        }

        // Son sütundaki veriyi al (en güncel ay)
        dynamic lastValue = rows[i][rows[i].length - 1];
        double changeRate = 0.0;

        if (lastValue is num) {
          changeRate = lastValue.toDouble();
        } else if (lastValue is String) {
          try {
            changeRate = double.parse(lastValue);
          } catch (e) {
            // Parse edilemeyen değerleri 0 olarak kabul et
            changeRate = 0.0;
          }
        }

        tufeDataList.add(TufeData(
          groupName: groupName,
          changeRate: changeRate,
        ));
        print('Eklendi: $groupName = $changeRate');
      }

      print('Toplam ${tufeDataList.length} veri eklendi');

      // Verileri değişim oranına göre büyükten küçüğe sırala
      tufeDataList.sort((a, b) => b.changeRate.compareTo(a.changeRate));

      print('Sıralama sonrası ilk 3 item:');
      for (int i = 0; i < tufeDataList.length && i < 3; i++) {
        print(
            '${i + 1}. ${tufeDataList[i].groupName}: ${tufeDataList[i].changeRate}');
      }

      return tufeDataList;
    } catch (e) {
      throw Exception('CSV veri yükleme hatası: $e');
    }
  }

  static String getCurrentMonth() {
    final now = DateTime.now();
    const months = [
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık'
    ];
    return months[now.month - 1];
  }

  static Future<String> getMonthFromCSV() async {
    try {
      final String csvData = await GitHubCSVService.loadCSVFromGitHub(
          'gruplaraylik.csv',
          useCache: false);

      // Manuel olarak satırlara böl
      List<String> lines = csvData.split(RegExp(r'\r?\n'));
      List<List<dynamic>> rows = [];

      for (String line in lines) {
        String trimmedLine = line.trim();
        if (trimmedLine.isNotEmpty) {
          try {
            List<List<dynamic>> parsedLine =
                const CsvToListConverter().convert(trimmedLine);
            if (parsedLine.isNotEmpty) {
              rows.add(parsedLine[0]);
            }
          } catch (e) {
            // Parse hatalarını sessizce atla
          }
        }
      }

      if (rows.isEmpty || rows[0].length < 3) {
        // Fallback olarak sistem tarihini kullan
        return getCurrentMonth();
      }

      // Header satırından son sütundaki tarihi al
      String lastDateString = rows[0].last.toString().trim();
      
      // Tarih formatını parse et (2025-08-31 formatında)
      try {
        DateTime lastDate = DateTime.parse(lastDateString);
        const months = [
          'Ocak',
          'Şubat',
          'Mart',
          'Nisan',
          'Mayıs',
          'Haziran',
          'Temmuz',
          'Ağustos',
          'Eylül',
          'Ekim',
          'Kasım',
          'Aralık'
        ];
        return months[lastDate.month - 1];
      } catch (e) {
        // Tarih parse edilemezse sistem tarihini kullan
        return getCurrentMonth();
      }
    } catch (e) {
      // Hata durumunda sistem tarihini kullan
      return getCurrentMonth();
    }
  }

  static Future<double> getTufeMonthlyChange() async {
    try {
      final String csvData = await GitHubCSVService.loadCSVFromGitHub(
          'gruplaraylik.csv',
          useCache: false);

      // Manuel olarak satırlara böl
      List<String> lines = csvData.split(RegExp(r'\r?\n'));
      List<List<dynamic>> rows = [];

      for (String line in lines) {
        String trimmedLine = line.trim();
        if (trimmedLine.isNotEmpty) {
          try {
            List<List<dynamic>> parsedLine =
                const CsvToListConverter().convert(trimmedLine);
            if (parsedLine.isNotEmpty) {
              rows.add(parsedLine[0]);
            }
          } catch (e) {
            // Parse hatalarını sessizce atla
          }
        }
      }

      if (rows.isEmpty) {
        throw Exception('CSV dosyası boş');
      }

      // Find the "Web TÜFE" row
      for (int i = 1; i < rows.length; i++) {
        if (rows[i].length >= 2) {
          final String groupName = rows[i][1].toString().trim();
          if (groupName == 'Web TÜFE') {
            // Get the last column (latest monthly change)
            final String lastValue = rows[i].last.toString().trim();
            try {
              return double.parse(lastValue);
            } catch (e) {
              return 0.0;
            }
          }
        }
      }

      return 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  /// CSV dosyasındaki tüm tarihleri döndürür
  static Future<List<String>> getAvailableDates() async {
    try {
      final String csvData = await GitHubCSVService.loadCSVFromGitHub(
          'gruplaraylik.csv',
          useCache: false);

      List<String> lines = csvData.split(RegExp(r'\r?\n'));
      List<List<dynamic>> rows = [];

      for (String line in lines) {
        String trimmedLine = line.trim();
        if (trimmedLine.isNotEmpty) {
          try {
            List<List<dynamic>> parsedLine =
                const CsvToListConverter().convert(trimmedLine);
            if (parsedLine.isNotEmpty) {
              rows.add(parsedLine[0]);
            }
          } catch (e) {
            // Parse hatalarını sessizce atla
          }
        }
      }

      if (rows.isEmpty || rows[0].length < 3) {
        return [];
      }

      // Header satırından tarihleri al (2. sütundan itibaren)
      List<String> dates = [];
      for (int i = 2; i < rows[0].length; i++) {
        String dateStr = rows[0][i].toString().trim();
        if (dateStr.isNotEmpty) {
          dates.add(dateStr);
        }
      }

      return dates;
    } catch (e) {
      print('Tarih listesi yükleme hatası: $e');
      return [];
    }
  }

  /// Belirli bir tarih için TÜFE verilerini yükler
  static Future<List<TufeData>> loadTufeDataForDate(String selectedDate) async {
    try {
      final String csvData = await GitHubCSVService.loadCSVFromGitHub(
          'gruplaraylik.csv',
          useCache: false);

      List<String> lines = csvData.split(RegExp(r'\r?\n'));
      List<List<dynamic>> rows = [];

      for (int i = 0; i < lines.length; i++) {
        String line = lines[i].trim();
        if (line.isNotEmpty) {
          try {
            List<List<dynamic>> parsedLine =
                const CsvToListConverter().convert(line);
            if (parsedLine.isNotEmpty) {
              rows.add(parsedLine[0]);
            }
          } catch (e) {
            print('Satır $i parse hatası: $e');
          }
        }
      }

      if (rows.isEmpty) {
        throw Exception('CSV dosyası boş');
      }

      // Header satırından seçili tarihin sütun indeksini bul
      int dateColumnIndex = -1;
      for (int i = 2; i < rows[0].length; i++) {
        String dateStr = rows[0][i].toString().trim();
        if (dateStr == selectedDate) {
          dateColumnIndex = i;
          break;
        }
      }

      if (dateColumnIndex == -1) {
        throw Exception('Seçili tarih bulunamadı: $selectedDate');
      }

      List<TufeData> tufeDataList = [];

      // İlk satır header, ondan sonraki satırları işle
      for (int i = 1; i < rows.length; i++) {
        if (rows[i].length < dateColumnIndex + 1) {
          continue;
        }

        String groupName = rows[i][1].toString().trim();
        if (groupName.isEmpty) {
          continue;
        }

        // Seçili tarih sütunundaki veriyi al
        dynamic value = rows[i][dateColumnIndex];
        double changeRate = 0.0;

        if (value is num) {
          changeRate = value.toDouble();
        } else if (value is String) {
          try {
            changeRate = double.parse(value);
          } catch (e) {
            changeRate = 0.0;
          }
        }

        tufeDataList.add(TufeData(
          groupName: groupName,
          changeRate: changeRate,
        ));
      }

      // Verileri değişim oranına göre büyükten küçüğe sırala
      tufeDataList.sort((a, b) => b.changeRate.compareTo(a.changeRate));

      return tufeDataList;
    } catch (e) {
      throw Exception('CSV veri yükleme hatası: $e');
    }
  }

  /// Belirli bir tarih için ay adını döndürür
  static String getMonthFromDate(String dateString) {
    try {
      DateTime date = DateTime.parse(dateString);
      const months = [
        'Ocak',
        'Şubat',
        'Mart',
        'Nisan',
        'Mayıs',
        'Haziran',
        'Temmuz',
        'Ağustos',
        'Eylül',
        'Ekim',
        'Kasım',
        'Aralık'
      ];
      return months[date.month - 1];
    } catch (e) {
      return '';
    }
  }
}
