import 'package:flutter/services.dart';
import 'package:csv/csv.dart';
import 'github_csv_service.dart';

class GruplarService {
  static Future<Map<String, dynamic>> loadGruplarData() async {
    try {
      final String csvData = await GitHubCSVService.loadCSVFromGitHub(
          'gruplar.csv',
          useCache: false);
      print('CSV veri uzunluğu: ${csvData.length}');

      // Manuel olarak satırlara böl - farklı satır sonu karakterlerini handle et
      List<String> lines = csvData.split(RegExp(r'\r?\n'));
      print('Toplam satır sayısı: ${lines.length}');

      if (lines.isEmpty) return {'data': {}, 'dates': [], 'grupNames': []};

      // Her satırı ayrı ayrı CSV olarak parse et
      List<List<dynamic>> rows = [];
      for (String line in lines) {
        if (line.trim().isNotEmpty) {
          List<List<dynamic>> parsedLine =
              const CsvToListConverter().convert(line);
          if (parsedLine.isNotEmpty) {
            rows.add(parsedLine[0]);
          }
        }
      }

      print('Parse edilen satır sayısı: ${rows.length}');
      if (rows.isNotEmpty) {
        print('İlk satır: ${rows[0]}');
      }

      if (rows.isEmpty) return {'data': {}, 'dates': [], 'grupNames': []};

      final Map<String, List<double>> gruplarData = {};
      final List<String> dates = [];
      final List<String> grupNames = [];

      // Başlık satırından günlük tarihleri al ve dd.MM.yyyy formatına çevir
      for (int i = 1; i < rows[0].length; i++) {
        String tarihStr = rows[0][i].toString();
        try {
          // 2025-01-01 formatından dd.MM.yyyy formatına çevir
          final dateParts = tarihStr.split('-');
          if (dateParts.length == 3) {
            final formattedDate =
                '${dateParts[2]}.${dateParts[1]}.${dateParts[0]}';
            dates.add(formattedDate);
          } else {
            dates.add(tarihStr);
          }
        } catch (e) {
          dates.add(tarihStr);
        }
      }

      // Her ana grup için endeks verilerini doğrudan oku
      for (int i = 1; i < rows.length; i++) {
        if (rows[i].length >= 2) {
          String grupAdi = rows[i][0].toString().trim();
          if (grupAdi.isNotEmpty) {
            grupNames.add(grupAdi);
            gruplarData[grupAdi] = [];

            // Günlük endeks değerlerini doğrudan al
            for (int j = 1; j < rows[i].length && j <= dates.length; j++) {
              try {
                double indexValue = double.parse(rows[i][j].toString());
                gruplarData[grupAdi]!.add(indexValue);
              } catch (e) {
                // Geçersiz değer için önceki değeri kullan
                if (gruplarData[grupAdi]!.isNotEmpty) {
                  gruplarData[grupAdi]!.add(gruplarData[grupAdi]!.last);
                } else {
                  gruplarData[grupAdi]!.add(100.0); // Varsayılan değer
                }
              }
            }
          }
        }
      }

      print('Yüklenen grup adları: $grupNames');

      return {
        'data': gruplarData,
        'dates': dates,
        'grupNames': grupNames,
      };
    } catch (e) {
      print('Grup verileri yüklenirken hata: $e');
      return {'data': {}, 'dates': [], 'grupNames': []};
    }
  }

  static Future<Map<String, dynamic>> loadGruplarAylikData() async {
    try {
      final String csvData = await GitHubCSVService.loadCSVFromGitHub(
          'gruplaraylik.csv',
          useCache: false);

      // Manuel olarak satırlara böl - farklı satır sonu karakterlerini handle et
      List<String> lines = csvData.split(RegExp(r'\r?\n'));

      if (lines.isEmpty) return {'data': {}, 'dates': [], 'grupNames': []};

      // Her satırı ayrı ayrı CSV olarak parse et
      List<List<dynamic>> rows = [];
      for (String line in lines) {
        if (line.trim().isNotEmpty) {
          List<List<dynamic>> parsedLine =
              const CsvToListConverter().convert(line);
          if (parsedLine.isNotEmpty) {
            rows.add(parsedLine[0]);
          }
        }
      }

      if (rows.isEmpty) return {'data': {}, 'dates': [], 'grupNames': []};

      final Map<String, List<double>> gruplarData = {};
      final List<String> dates = [];
      final List<String> grupNames = [];

      // Başlık satırından aylık tarihleri al ve formatla
      for (int i = 2; i < rows[0].length; i++) {
        String tarihStr = rows[0][i].toString();
        try {
          final dateParts = tarihStr.split('-');
          if (dateParts.length == 3) {
            // Ay isimlerini Türkçe'ye çevir
            final monthNames = {
              '01': 'Oca',
              '02': 'Şub',
              '03': 'Mar',
              '04': 'Nis',
              '05': 'May',
              '06': 'Haz',
              '07': 'Tem',
              '08': 'Ağu',
              '09': 'Eyl',
              '10': 'Eki',
              '11': 'Kas',
              '12': 'Ara'
            };

            String monthName = monthNames[dateParts[1]] ?? dateParts[1];
            dates.add('$monthName ${dateParts[0]}');
          } else {
            dates.add(tarihStr);
          }
        } catch (e) {
          dates.add(tarihStr);
        }
      }

      // Her ana grup için aylık değişim oranlarını doğrudan oku (Web TÜFE dahil)
      for (int i = 1; i < rows.length; i++) {
        if (rows[i].length >= 3) {
          String grupAdi = rows[i][1].toString().trim();
          if (grupAdi.isNotEmpty) {
            grupNames.add(grupAdi);
            gruplarData[grupAdi] = [];

            // Aylık değişim oranlarını doğrudan al
            for (int j = 2; j < rows[i].length && j <= dates.length + 1; j++) {
              try {
                double changeRate = double.parse(rows[i][j].toString());
                gruplarData[grupAdi]!.add(changeRate);
              } catch (e) {
                // Geçersiz değer için 0 kullan
                gruplarData[grupAdi]!.add(0.0);
              }
            }
          }
        }
      }

      return {
        'data': gruplarData,
        'dates': dates.cast<String>(),
        'grupNames': grupNames.cast<String>(),
      };
    } catch (e) {
      print('Aylık grup verileri yüklenirken hata: $e');
      return {'data': {}, 'dates': <String>[], 'grupNames': <String>[]};
    }
  }

  static Future<List<String>> getGrupNames() async {
    try {
      final String csvData = await GitHubCSVService.loadCSVFromGitHub(
          'gruplar.csv',
          useCache: false);
      print('CSV veri uzunluğu: ${csvData.length}');

      // Manuel olarak satırlara böl - farklı satır sonu karakterlerini handle et
      List<String> lines = csvData.split(RegExp(r'\r?\n'));
      print('Toplam satır sayısı: ${lines.length}');

      if (lines.isEmpty) return [];

      // Her satırı ayrı ayrı CSV olarak parse et
      List<List<dynamic>> rows = [];
      for (String line in lines) {
        if (line.trim().isNotEmpty) {
          List<List<dynamic>> parsedLine =
              const CsvToListConverter().convert(line);
          if (parsedLine.isNotEmpty) {
            rows.add(parsedLine[0]);
          }
        }
      }

      print('Parse edilen satır sayısı: ${rows.length}');
      if (rows.isNotEmpty) {
        print('İlk satır: ${rows[0]}');
        if (rows.length > 1) {
          print('İkinci satır: ${rows[1]}');
        }
      }

      List<String> grupNames = [];
      for (int i = 1; i < rows.length; i++) {
        print('Satır $i: ${rows[i]}');
        if (rows[i].length >= 1) {
          String grupAdi = rows[i][0].toString().trim();
          print('Grup adı: "$grupAdi"');
          if (grupAdi.isNotEmpty) {
            grupNames.add(grupAdi);
          }
        }
      }
      print('Yüklenen grup adları: $grupNames');
      return grupNames;
    } catch (e) {
      print('Grup adları yüklenirken hata: $e');
      return [];
    }
  }

  static Future<List<double>> getGrupIndexData(String grupAdi) async {
    try {
      final data = await loadGruplarData();
      final gruplarData = data['data'] as Map<String, List<double>>;
      final result = gruplarData[grupAdi] ?? [];
      print('$grupAdi için endeks verisi: ${result.length} adet değer');
      return result;
    } catch (e) {
      print('Grup endeks verisi yüklenirken hata: $e');
      return [];
    }
  }

  static Future<List<double>> getGrupMonthlyChangeData(String grupAdi) async {
    try {
      final data = await loadGruplarAylikData();
      final gruplarData = data['data'] as Map<String, List<double>>;
      return gruplarData[grupAdi] ?? [];
    } catch (e) {
      print('Grup aylık değişim verisi yüklenirken hata: $e');
      return [];
    }
  }

  static Future<List<String>> getIndexDates() async {
    try {
      final data = await loadGruplarData();
      return data['dates'] as List<String>;
    } catch (e) {
      print('Endeks tarihleri yüklenirken hata: $e');
      return [];
    }
  }

  static Future<List<String>> getMonthlyDates() async {
    try {
      final data = await loadGruplarAylikData();
      return data['dates'] as List<String>;
    } catch (e) {
      print('Aylık tarihler yüklenirken hata: $e');
      return [];
    }
  }
}
