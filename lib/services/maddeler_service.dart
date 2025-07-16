import 'package:flutter/services.dart';
import 'package:csv/csv.dart';
import '../models/madde_data.dart';
import '../models/harcama_grubu_data.dart'; // AnaGrupData için
import 'github_csv_service.dart';

class MaddelerService {
  // Ana grupları gruplar.csv'den okuyacağız
  static Future<List<AnaGrupData>> loadAnaGruplar() async {
    try {
      final String csvData =
          await GitHubCSVService.loadCSVFromGitHub('gruplar.csv');
      print('gruplar.csv veri uzunluğu: ${csvData.length}');

      // Manuel olarak satırlara böl (line ending sorunları için)
      List<String> lines = csvData.split(RegExp(r'\r?\n'));
      print('Toplam satır sayısı: ${lines.length}');

      List<AnaGrupData> anaGruplar = [];
      for (int i = 1; i < lines.length; i++) {
        // İlk satır header
        String line = lines[i].trim();
        if (line.isNotEmpty) {
          List<List<dynamic>> parsedLine =
              const CsvToListConverter().convert(line);
          if (parsedLine.isNotEmpty && parsedLine[0].isNotEmpty) {
            List<dynamic> row = parsedLine[0];
            String anaGrupAdi = row[0].toString().trim();
            if (anaGrupAdi.isNotEmpty) {
              anaGruplar.add(AnaGrupData(name: anaGrupAdi));
            }
          }
        }
      }

      print('Yüklenen ana gruplar: ${anaGruplar.map((e) => e.name).toList()}');
      return anaGruplar;
    } catch (e) {
      print('Ana gruplar yükleme hatası: $e');
      throw Exception('Ana gruplar yükleme hatası: $e');
    }
  }

  // Maddeleraylik.csv'den mevcut tarihleri al
  static Future<List<String>> getAvailableDates() async {
    try {
      final String csvData =
          await GitHubCSVService.loadCSVFromGitHub('maddeleraylik.csv');
      print('maddeleraylik.csv veri uzunluğu: ${csvData.length}');

      // Manuel olarak satırlara böl
      List<String> lines = csvData.split(RegExp(r'\r?\n'));
      print('maddeleraylik.csv toplam satır sayısı: ${lines.length}');

      if (lines.isEmpty) {
        throw Exception('maddeleraylik.csv dosyası boş');
      }

      // İlk satır header - tarih sütunları 2. sütundan başlar
      String headerLine = lines[0];
      List<List<dynamic>> parsedHeader =
          const CsvToListConverter().convert(headerLine);
      List<dynamic> headerRow = parsedHeader.isNotEmpty ? parsedHeader[0] : [];

      List<String> dates = [];
      // 2. sütundan başlayarak tarih sütunlarını al
      for (int i = 2; i < headerRow.length; i++) {
        String date = headerRow[i].toString().trim();
        if (date.isNotEmpty && date.contains('-')) {
          dates.add(date);
        }
      }

      print('Bulunan tarihler: $dates');
      return dates.reversed.toList(); // En yeni tarih önce
    } catch (e) {
      print('Tarihler yükleme hatası: $e');
      throw Exception('Tarihler yükleme hatası: $e');
    }
  }

  // Seçilen ana gruba ait maddeleri ürünler.csv'den okuyacağız
  static Future<List<String>> loadMaddeler(String selectedAnaGrup) async {
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

      Set<String> maddeler = {};
      String selectedGroupNorm = selectedAnaGrup.trim().toLowerCase();
      print('Aranan ana grup (normalize): $selectedGroupNorm');

      // İlk satır header, ondan sonraki satırları işle
      int matchCount = 0;
      for (int i = 1; i < rows.length; i++) {
        if (rows[i].length >= 6) {
          String anaGrup =
              rows[i][5].toString().trim().toLowerCase(); // Ana Grup sütunu
          String madde =
              rows[i][1].toString().trim().toLowerCase(); // Ürün sütunu

          // İlk birkaç eşleşme için debug
          if (anaGrup == selectedGroupNorm && matchCount < 5) {
            print(
                'Eşleşen satır ${i}: Ana Grup="${rows[i][5]}", Madde="${rows[i][1]}"');
            matchCount++;
          }

          if (anaGrup == selectedGroupNorm && madde.isNotEmpty) {
            maddeler.add(madde);
          }
        }
      }

      print('Bulunan maddeler sayısı: ${maddeler.length}');
      print('Maddeler listesi: ${maddeler.toList()}');

      return maddeler.toList();
    } catch (e) {
      print('Maddeler yükleme hatası: $e');
      throw Exception('Maddeler yükleme hatası: $e');
    }
  }

  // Maddelerin değişim oranlarını maddeleraylik.csv'den okuyacağız
  static Future<List<MaddeData>> loadMaddeDegiisimOranlari(
      List<String> maddeler, String selectedDate) async {
    try {
      final String csvData =
          await GitHubCSVService.loadCSVFromGitHub('maddeleraylik.csv');

      // Manuel olarak satırlara böl
      List<String> lines = csvData.split(RegExp(r'\r?\n'));
      print('maddeleraylik.csv satır sayısı: ${lines.length}');

      if (lines.isEmpty) {
        throw Exception('maddeleraylik.csv dosyası boş');
      }

      // Header satırından tarih sütununu bul
      String headerLine = lines[0];
      List<List<dynamic>> parsedHeader =
          const CsvToListConverter().convert(headerLine);
      List<dynamic> headerRow = parsedHeader.isNotEmpty ? parsedHeader[0] : [];

      int dateColumnIndex = -1;
      for (int i = 0; i < headerRow.length; i++) {
        if (headerRow[i].toString().trim() == selectedDate) {
          dateColumnIndex = i;
          break;
        }
      }

      if (dateColumnIndex == -1) {
        throw Exception('Seçilen tarih bulunamadı: $selectedDate');
      }

      print('Tarih sütun indeksi: $dateColumnIndex');

      List<MaddeData> maddeDataList = [];

      // Veri satırlarını işle
      for (int i = 1; i < lines.length; i++) {
        String line = lines[i].trim();
        if (line.isNotEmpty) {
          List<List<dynamic>> parsedLine =
              const CsvToListConverter().convert(line);
          if (parsedLine.isNotEmpty) {
            List<dynamic> row = parsedLine[0];

            if (row.length > dateColumnIndex) {
              String rowMaddeName = row[1].toString().trim().toLowerCase();

              // Seçilen maddeler listesinde var mı kontrol et
              if (maddeler.contains(rowMaddeName)) {
                double changeRate =
                    double.tryParse(row[dateColumnIndex].toString()) ?? 0.0;

                maddeDataList.add(MaddeData(
                  maddeName: row[1].toString().trim(), // Orijinal case'i koru
                  changeRate: changeRate,
                ));
              }
            }
          }
        }
      }

      print('Bulunan madde verileri sayısı: ${maddeDataList.length}');

      // Değişim oranına göre sırala (büyükten küçüğe)
      maddeDataList.sort((a, b) => b.changeRate.compareTo(a.changeRate));

      return maddeDataList;
    } catch (e) {
      print('Madde değişim oranları yükleme hatası: $e');
      throw Exception('Madde değişim oranları yükleme hatası: $e');
    }
  }
}
