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
}
