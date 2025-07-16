import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:csv/csv.dart';
import 'github_csv_service.dart';

class EndekslerService {
  static Future<Map<String, dynamic>> loadEndekslerData() async {
    final String data =
        await GitHubCSVService.loadCSVFromGitHub('endeksler.csv');

    // Manuel olarak satırlara böl ve parse et
    List<String> lines = data.split(RegExp(r'\r?\n'));
    List<List<dynamic>> csvData = [];

    for (String line in lines) {
      String trimmedLine = line.trim();
      if (trimmedLine.isNotEmpty) {
        try {
          List<List<dynamic>> parsedLine =
              const CsvToListConverter().convert(trimmedLine);
          if (parsedLine.isNotEmpty) {
            csvData.add(parsedLine[0]);
          }
        } catch (e) {
          // Parse hatalarını sessizce atla
        }
      }
    }

    final Map<String, List<double>> endeksData = {};
    final List<String> dates = [];
    List<String> endeksNames = [];

    if (csvData.isNotEmpty) {
      // First row contains endeks names (columns)
      final List<dynamic> headers = csvData[0];

      // Extract endeks names from headers (skip first empty column)
      for (int i = 1; i < headers.length; i++) {
        final String endeksName = headers[i].toString().trim();
        if (endeksName.isNotEmpty) {
          endeksNames.add(endeksName);
          endeksData[endeksName] = [];
        }
      }

      // Process data rows (each row is a date)
      for (int i = 1; i < csvData.length; i++) {
        final List<dynamic> row = csvData[i];
        if (row.isNotEmpty) {
          // First column is the date
          final String dateStr = row[0].toString().trim();
          if (dateStr.isNotEmpty) {
            // Convert date format from 2025-01-01 to 01.01.2025
            try {
              final dateParts = dateStr.split('-');
              if (dateParts.length == 3) {
                final formattedDate =
                    '${dateParts[2]}.${dateParts[1]}.${dateParts[0]}';
                dates.add(formattedDate);
              } else {
                dates.add(dateStr);
              }
            } catch (e) {
              dates.add(dateStr);
            }

            // Parse values for each endeks (skip first column which is the date)
            for (int j = 1; j < row.length && j <= endeksNames.length; j++) {
              final String endeksName = endeksNames[j - 1];
              try {
                final double value = double.parse(row[j].toString().trim());
                endeksData[endeksName]?.add(value);
              } catch (e) {
                endeksData[endeksName]
                    ?.add(100.0); // Default value for parsing errors
              }
            }
          }
        }
      }
    }

    return {
      'data': endeksData,
      'dates': dates,
    };
  }

  static Future<List<String>> getEndeksList() async {
    final data = await loadEndekslerData();
    final Map<String, List<double>> endeksData = data['data'];
    final List<String> endeksList = endeksData.keys.toList()..sort();

    // Add Web TÜFE as the first option
    endeksList.insert(0, 'Web TÜFE');

    return endeksList;
  }

  static Future<Map<String, dynamic>> loadTufeData() async {
    final String data = await GitHubCSVService.loadCSVFromGitHub('tufe.csv');

    // Manuel olarak satırlara böl ve parse et
    List<String> lines = data.split(RegExp(r'\r?\n'));
    List<List<dynamic>> csvData = [];

    for (String line in lines) {
      String trimmedLine = line.trim();
      if (trimmedLine.isNotEmpty) {
        try {
          List<List<dynamic>> parsedLine =
              const CsvToListConverter().convert(trimmedLine);
          if (parsedLine.isNotEmpty) {
            csvData.add(parsedLine[0]);
          }
        } catch (e) {
          // Parse hatalarını sessizce atla
        }
      }
    }

    final List<double> tufeValues = [];
    final List<String> dates = [];

    if (csvData.isNotEmpty) {
      // Process data rows (skip header)
      for (int i = 1; i < csvData.length; i++) {
        final List<dynamic> row = csvData[i];
        if (row.length >= 2) {
          // First column is date
          final String dateStr = row[0].toString().trim();
          if (dateStr.isNotEmpty) {
            // Convert date format from 2025-01-01 to 01.01.2025
            try {
              final dateParts = dateStr.split('-');
              if (dateParts.length == 3) {
                final formattedDate =
                    '${dateParts[2]}.${dateParts[1]}.${dateParts[0]}';
                dates.add(formattedDate);
              } else {
                dates.add(dateStr);
              }
            } catch (e) {
              dates.add(dateStr);
            }

            // Second column is TÜFE value
            try {
              final double value = double.parse(row[1].toString().trim());
              tufeValues.add(value);
            } catch (e) {
              tufeValues.add(100.0);
            }
          }
        }
      }
    }

    return {
      'data': {'Web TÜFE': tufeValues},
      'dates': dates,
    };
  }

  static Future<Map<String, dynamic>> getEndeksData(String endeksName) async {
    final data = await loadEndekslerData();
    final Map<String, List<double>> endeksData = data['data'];
    final List<String> dates = data['dates'];

    if (!endeksData.containsKey(endeksName)) {
      throw Exception('Endeks bulunamadı: $endeksName');
    }

    final values = endeksData[endeksName]!;

    // Calculate year-to-date change (last value - 100)
    final double yearChange = values.isNotEmpty ? values.last - 100.0 : 0.0;

    return {
      'values': values,
      'dates': dates,
      'yearChange': yearChange,
      'lastDate': dates.isNotEmpty ? dates.last : '',
    };
  }

  static Future<double> getMonthlyChange(String endeksName) async {
    // This method is deprecated - use MaddelerService instead
    return 0.0;
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
}
