import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:csv/csv.dart';
import '../services/endeksler_service.dart';
import '../services/maddeler_service.dart';
import '../services/csv_service.dart';
import '../services/gruplar_service.dart';
import '../services/github_csv_service.dart';
import '../services/tuik_service.dart';

class TufePage extends StatefulWidget {
  const TufePage({Key? key}) : super(key: key);

  @override
  State<TufePage> createState() => _TufePageState();
}

class _TufePageState extends State<TufePage> {
  Map<String, List<double>> endekslerData = {};
  Map<String, double> maddelerData = {};
  Map<String, List<double>> monthlyChartData = {};
  List<String> monthNames = [];
  String selectedEndeks = '';
  List<String> availableEndeks = [];
  bool isLoading = true;
  List<String> dates = [];

  // Web TÜFE-specific data
  List<double> tufeValues = [];
  List<String> tufeDates = [];
  double tufeMonthlyChange = 0.0;

  @override
  void initState() {
    super.initState();
    // Cache'i temizle ve fresh data yükle
    GitHubCSVService.clearCache();
    loadData().then((_) {
      // Load Web TÜFE data by default since it's the first option
      if (selectedEndeks == 'Web TÜFE') {
        loadTufeData();
      }
    });
  }

  Future<void> loadData() async {
    try {
      final endeksData = await EndekslerService.loadEndekslerData();
      final endeksList = await EndekslerService.getEndeksList();

      // Aylık verileri yükle
      final monthlyData = await GruplarService.loadGruplarAylikData();

      // Maddeler için aylık değişim verilerini yükle
      final maddelerMonthlyData = await _loadMaddelerMonthlyData();

      setState(() {
        endekslerData = endeksData['data'];
        dates = endeksData['dates'];
        monthlyChartData = monthlyData['data'];
        monthNames = monthlyData['dates'];
        maddelerData = maddelerMonthlyData;
        availableEndeks = endeksList;
        if (availableEndeks.isNotEmpty) {
          selectedEndeks = availableEndeks.first; // This will be 'Web TÜFE'
        }
        isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<Map<String, double>> _loadMaddelerMonthlyData() async {
    try {
      final String csvData = await GitHubCSVService.loadCSVFromGitHub(
          'maddeleraylik.csv',
          useCache: false);
      List<String> lines = csvData.split(RegExp(r'\r?\n'));

      if (lines.isEmpty) return {};

      Map<String, double> monthlyData = {};

      // Header satırından son tarih sütununu bul
      List<List<dynamic>> parsedHeader =
          const CsvToListConverter().convert(lines[0]);
      List<dynamic> headerRow = parsedHeader.isNotEmpty ? parsedHeader[0] : [];
      int lastDateIndex = headerRow.length - 1;

      // Her endeks için son aylık değişim değerini al
      for (int i = 1; i < lines.length; i++) {
        if (lines[i].trim().isEmpty) continue;

        List<List<dynamic>> parsedLine =
            const CsvToListConverter().convert(lines[i]);
        if (parsedLine.isNotEmpty) {
          List<dynamic> row = parsedLine[0];
          if (row.length >= 2) {
            String endeksName = row[1].toString().trim();
            if (endeksName.isNotEmpty && row.length > lastDateIndex) {
              double lastValue =
                  double.tryParse(row[lastDateIndex].toString()) ?? 0.0;
              monthlyData[endeksName] = lastValue;
            }
          }
        }
      }

      return monthlyData;
    } catch (e) {
      print('Maddeler aylık veri yükleme hatası: $e');
      return {};
    }
  }

  Future<void> loadTufeData() async {
    try {
      final tufeData = await EndekslerService.loadTufeData();
      final monthlyChange = await CSVService.getTufeMonthlyChange();

      setState(() {
        tufeValues = tufeData['data']['Web TÜFE'];
        tufeDates = tufeData['dates'];
        tufeMonthlyChange = monthlyChange;
      });
    } catch (e) {
      print('Error loading Web TÜFE data: $e');
    }
  }

  double getYearToDateChange() {
    if (selectedEndeks.isEmpty) return 0.0;

    if (selectedEndeks == 'Web TÜFE') {
      if (tufeValues.isEmpty) return 0.0;
      // Year to date change = last value - 100
      return tufeValues.last - 100.0;
    }

    if (!endekslerData.containsKey(selectedEndeks)) {
      return 0.0;
    }

    final values = endekslerData[selectedEndeks]!;
    if (values.isEmpty) return 0.0;

    // Year to date change = last value - 100
    return values.last - 100.0;
  }

  double getMonthlyChange() {
    if (selectedEndeks.isEmpty) return 0.0;

    if (selectedEndeks == 'Web TÜFE') {
      return tufeMonthlyChange;
    }

    // Diğer endeksler için maddelerData'dan al
    if (maddelerData.containsKey(selectedEndeks)) {
      return maddelerData[selectedEndeks]!;
    }

    return 0.0;
  }

  String getCurrentDate() {
    final now = DateTime.now();
    final day = now.day.toString().padLeft(2, '0');
    final month = now.month.toString().padLeft(2, '0');
    final year = now.year.toString();
    return '$day.$month.$year';
  }

  List<FlSpot> getMainChartData() {
    if (selectedEndeks.isEmpty) return [];

    if (selectedEndeks == 'Web TÜFE') {
      if (tufeValues.isEmpty) return [];
      return tufeValues.asMap().entries.map((entry) {
        return FlSpot(entry.key.toDouble(), entry.value);
      }).toList();
    }

    if (!endekslerData.containsKey(selectedEndeks)) {
      return [];
    }

    final values = endekslerData[selectedEndeks]!;
    return values.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value);
    }).toList();
  }

  // Web TÜFE seçiliyken karşılaştırmalı endeks verisi
  Future<Map<String, List<FlSpot>>> getComparedEndeksChartData() async {
    if (selectedEndeks != 'Web TÜFE') return {};

    try {
      // TÜİK endeks verilerini al
      final tuikData = await TuikService.loadTuikEndeksData();

      Map<String, List<FlSpot>> result = {};

      // Web TÜFE verisi (günlük)
      if (tufeValues.isNotEmpty) {
        result['Web TÜFE'] = tufeValues.asMap().entries.map((entry) {
          return FlSpot(entry.key.toDouble(), entry.value);
        }).toList();
      }

      // TÜİK TÜFE verisi (aylık) - tarihleri eşleştir ve step plot için hazırla
      if (tuikData['data']['TÜİK TÜFE'] != null) {
        final tuikValues = tuikData['data']['TÜİK TÜFE'] as List<double>;
        final tuikDates = tuikData['dates'] as List<String>;

        List<FlSpot> tuikSpots = [];

        // TÜİK verilerini Web TÜFE tarihlerinin ayın son günlerine eşleştir
        for (int tuikIndex = 0; tuikIndex < tuikDates.length; tuikIndex++) {
          String tuikDate = tuikDates[tuikIndex]; // Format: dd.mm.yyyy
          double tuikValue = tuikValues[tuikIndex];

          if (tuikValue.isNaN) continue;

          try {
            List<String> tuikDateParts = tuikDate.split('.');
            if (tuikDateParts.length == 3) {
              String tuikMonth = tuikDateParts[1]; // mm
              String tuikYear = tuikDateParts[2]; // yyyy

              // Web TÜFE tarihlerinde bu ayın son gününü bul
              int lastDayIndex = -1;
              for (int webIndex = tufeDates.length - 1;
                  webIndex >= 0;
                  webIndex--) {
                String webDate = tufeDates[webIndex]; // Format: dd.mm.yyyy
                List<String> webDateParts = webDate.split('.');
                if (webDateParts.length == 3) {
                  String webMonth = webDateParts[1]; // mm
                  String webYear = webDateParts[2]; // yyyy

                  if (webMonth == tuikMonth && webYear == tuikYear) {
                    lastDayIndex = webIndex;
                    break; // Bu ayın son gününü bulduk
                  }
                }
              }

              // Eğer o ayın son günü bulunduysa TÜİK verisini ekle
              if (lastDayIndex != -1) {
                tuikSpots.add(FlSpot(lastDayIndex.toDouble(), tuikValue));
              }
            }
          } catch (e) {
            print('Tarih eşleştirme hatası: $e');
          }
        }

        // TÜİK spots'ları x değerine göre sırala
        tuikSpots.sort((a, b) => a.x.compareTo(b.x));

        // Step plot için ara değerler ekle
        List<FlSpot> stepSpots = [];
        for (int i = 0; i < tuikSpots.length; i++) {
          FlSpot currentSpot = tuikSpots[i];
          stepSpots.add(currentSpot);

          // Sonraki spot varsa ara değerler ekle
          if (i < tuikSpots.length - 1) {
            FlSpot nextSpot = tuikSpots[i + 1];
            double currentX = currentSpot.x;
            double nextX = nextSpot.x;
            double currentY = currentSpot.y;

            // Ara noktalarda aynı Y değerini kullan (step effect)
            for (double x = currentX + 1; x < nextX; x++) {
              stepSpots.add(FlSpot(x, currentY));
            }
          } else {
            // Son spot'tan sonraki değerler için son değeri kullan
            double lastX = currentSpot.x;
            double lastY = currentSpot.y;
            for (double x = lastX + 1; x < tufeDates.length; x++) {
              stepSpots.add(FlSpot(x, lastY));
            }
          }
        }

        result['TÜİK TÜFE'] = stepSpots;
      }

      return result;
    } catch (e) {
      print('Karşılaştırmalı endeks veri yükleme hatası: $e');
      return {};
    }
  }

  // State'e tarih listelerini ekleyeceğiz
  List<String> comparisonDates = [];

  Future<Map<String, List<FlSpot>>> getComparedMonthlyChangeChartData() async {
    if (selectedEndeks.isEmpty) return {};

    try {
      if (selectedEndeks == 'Web TÜFE') {
        // Web TÜFE verilerini al
        final monthlyData = await GruplarService.loadGruplarAylikData();
        // TÜİK TÜFE verilerini al
        final tuikData = await TuikService.loadTuikAylikData();

        Map<String, List<FlSpot>> result = {};

        final tuikDates = tuikData['dates'] as List<String>;
        final webTufeDates = monthlyData['dates'] as List<String>;

        // Web TÜFE tarihlerini parse et ve sırala
        List<MapEntry<String, int>> webTufeDateList = []; // "YYYY-MM" -> index
        for (int i = 0; i < webTufeDates.length; i++) {
          String dateStr = webTufeDates[i];
          String? yearMonth = _parseDateToYearMonth(dateStr);
          if (yearMonth != null) {
            webTufeDateList.add(MapEntry(yearMonth, i));
          }
        }
        // Tarihe göre sırala
        webTufeDateList.sort((a, b) => a.key.compareTo(b.key));

        // TÜİK tarihlerini parse et ve map'e çevir
        Map<String, int> tuikDateMap = {}; // "YYYY-MM" -> index
        for (int i = 0; i < tuikDates.length; i++) {
          String dateStr = tuikDates[i];
          String? yearMonth = _parseDateToYearMonth(dateStr);
          if (yearMonth != null) {
            tuikDateMap[yearMonth] = i;
          }
        }

        // comparisonDates'i Web TÜFE tarihlerine göre güncelle
        comparisonDates = webTufeDateList.map((e) => e.key).toList();

        // Web TÜFE verisi - tüm tarihler için
        if (monthlyData['data']['Web TÜFE'] != null) {
          final values = monthlyData['data']['Web TÜFE'] as List<double>;
          List<FlSpot> webTufeSpots = [];
          for (int i = 0; i < webTufeDateList.length; i++) {
            int webIndex = webTufeDateList[i].value;
            if (webIndex < values.length) {
              webTufeSpots.add(FlSpot(i.toDouble(), values[webIndex]));
            }
          }
          result['Web TÜFE'] = webTufeSpots;
        }

        // TÜİK TÜFE verisi - Web TÜFE tarihlerine göre eşleştir (sadece mevcut verileri ekle)
        if (tuikData['data']['TÜİK TÜFE'] != null) {
          final values = tuikData['data']['TÜİK TÜFE'] as List<double>;
          List<FlSpot> tuikSpots = [];
          for (int i = 0; i < webTufeDateList.length; i++) {
            String yearMonth = webTufeDateList[i].key;
            int? tuikIndex = tuikDateMap[yearMonth];
            if (tuikIndex != null && tuikIndex < values.length) {
              // TÜİK verisi varsa ekle (NaN değil, gerçek veri)
              double value = values[tuikIndex];
              if (!value.isNaN) {
                tuikSpots.add(FlSpot(i.toDouble(), value));
              }
            }
            // TÜİK verisi yoksa hiçbir şey ekleme (çizgi kesilir)
          }
          result['TÜİK TÜFE'] = tuikSpots;
        }

        return result;
      }

      return {};
    } catch (e) {
      print('Karşılaştırmalı aylık veri yükleme hatası: $e');
      return {};
    }
  }

  /// Tarih string'ini "YYYY-MM" formatına çevirir
  String? _parseDateToYearMonth(String dateStr) {
    try {
      // Format: "dd.mm.yyyy"
      if (dateStr.contains('.')) {
        List<String> parts = dateStr.split('.');
        if (parts.length == 3) {
          String day = parts[0];
          String month = parts[1];
          String year = parts[2];
          return '$year-${month.padLeft(2, '0')}';
        }
      }
      // Format: "Oca 2025" veya "Ocak 2025"
      else if (dateStr.contains(' ')) {
        List<String> parts = dateStr.split(' ');
        if (parts.length == 2) {
          String monthStr = parts[0];
          String year = parts[1];
          
          Map<String, String> monthMap = {
            'Oca': '01', 'Ocak': '01',
            'Şub': '02', 'Şubat': '02',
            'Mar': '03', 'Mart': '03',
            'Nis': '04', 'Nisan': '04',
            'May': '05', 'Mayıs': '05',
            'Haz': '06', 'Haziran': '06',
            'Tem': '07', 'Temmuz': '07',
            'Ağu': '08', 'Ağustos': '08',
            'Eyl': '09', 'Eylül': '09',
            'Eki': '10', 'Ekim': '10',
            'Kas': '11', 'Kasım': '11',
            'Ara': '12', 'Aralık': '12',
          };
          
          String? month = monthMap[monthStr];
          if (month != null) {
            return '$year-$month';
          }
        }
      }
      // Format: "2025-01-31" veya "2025-01"
      else if (dateStr.contains('-')) {
        List<String> parts = dateStr.split('-');
        if (parts.length >= 2) {
          String year = parts[0];
          String month = parts[1];
          return '$year-${month.padLeft(2, '0')}';
        }
      }
    } catch (e) {
      print('Tarih parse hatası: $dateStr - $e');
    }
    return null;
  }

  // Tek grafik için tarih listesi
  List<String> singleChartDates = [];

  Future<List<FlSpot>> getMonthlyChangeChartData() async {
    if (selectedEndeks.isEmpty) return [];

    try {
      if (selectedEndeks == 'Web TÜFE') {
        // Web TÜFE için gruplaraylik.csv'den veri al
        final monthlyData = await GruplarService.loadGruplarAylikData();
        singleChartDates = monthlyData['dates'] as List<String>;
        if (monthlyData['data']['Web TÜFE'] != null) {
          final values = monthlyData['data']['Web TÜFE'] as List<double>;
          return values.asMap().entries.map((entry) {
            return FlSpot(entry.key.toDouble(), entry.value);
          }).toList();
        }
        return [];
      } else {
        // Diğer endeksler için maddeleraylik.csv'den veri al
        final String csvData = await GitHubCSVService.loadCSVFromGitHub(
            'maddeleraylik.csv',
            useCache: false);
        List<String> lines = csvData.split(RegExp(r'\r?\n'));

        if (lines.isEmpty) return [];

        // Header satırından tarih sütunlarını al
        List<List<dynamic>> parsedHeader =
            const CsvToListConverter().convert(lines[0]);
        List<dynamic> headerRow =
            parsedHeader.isNotEmpty ? parsedHeader[0] : [];
        List<String> dates = [];
        for (int i = 2; i < headerRow.length; i++) {
          dates.add(headerRow[i].toString().trim());
        }
        singleChartDates = dates;

        // Seçili endeks için veri satırını bul
        for (int i = 1; i < lines.length; i++) {
          if (lines[i].trim().isEmpty) continue;

          List<List<dynamic>> parsedLine =
              const CsvToListConverter().convert(lines[i]);
          if (parsedLine.isNotEmpty) {
            List<dynamic> row = parsedLine[0];
            if (row.length >= 2) {
              String endeksName = row[1].toString().trim();
              if (endeksName == selectedEndeks) {
                List<double> values = [];
                for (int j = 2; j < row.length && j < dates.length + 2; j++) {
                  values.add(double.tryParse(row[j].toString()) ?? 0.0);
                }
                return values.asMap().entries.map((entry) {
                  return FlSpot(entry.key.toDouble(), entry.value);
                }).toList();
              }
            }
          }
        }
        return [];
      }
    } catch (e) {
      print('Aylık veri yükleme hatası: $e');
      return [];
    }
  }

  Widget buildTopSection() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Web TÜFE Endeksleri',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButton<String>(
              value: selectedEndeks.isEmpty ? null : selectedEndeks,
              hint: const Text('Endeks Seçiniz'),
              isExpanded: true,
              underline: const SizedBox(),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              items: availableEndeks.map((String endeks) {
                return DropdownMenuItem<String>(
                  value: endeks,
                  child: Text(endeks),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    selectedEndeks = newValue;
                  });
                  if (newValue == 'Web TÜFE') {
                    loadTufeData();
                  }
                }
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Yıl Başından Bu Yana',
                  '${getYearToDateChange().toStringAsFixed(2)}%',
                  Colors.orange.shade600,
                  Icons.trending_up,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Aylık Değişim',
                  '${getMonthlyChange().toStringAsFixed(2)}%',
                  Colors.green.shade600,
                  Icons.calendar_month,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '01.01.2025-${getCurrentDate()}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildMainChart() {
    if (selectedEndeks == 'Web TÜFE') {
      return buildComparedEndeksChart();
    } else {
      return buildSingleEndeksChart();
    }
  }

  Widget buildComparedEndeksChart() {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      child: FutureBuilder<Map<String, List<FlSpot>>>(
        future: getComparedEndeksChartData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Endeks veri yükleme hatası'));
          }

          final chartData = snapshot.data ?? {};
          if (chartData.isEmpty) {
            return const Center(child: Text('Endeks veri bulunamadı'));
          }

          List<LineChartBarData> lineBarsData = [];

          // Web TÜFE çizgisi (mavi)
          if (chartData.containsKey('Web TÜFE')) {
            lineBarsData.add(
              LineChartBarData(
                spots: chartData['Web TÜFE']!,
                isCurved: false,
                color: Colors.blue,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: Colors.blue.withOpacity(0.1),
                ),
              ),
            );
          }

          // TÜİK TÜFE çizgisi (kırmızı) - Step plot
          if (chartData.containsKey('TÜİK TÜFE')) {
            lineBarsData.add(
              LineChartBarData(
                spots: chartData['TÜİK TÜFE']!,
                isCurved: false,
                isStepLineChart: true, // Step plot için
                color: Colors.red,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: Colors.red.withOpacity(0.1),
                ),
              ),
            );
          }

          // Y-axis için dinamik aralık hesaplama
          double interval = _calculateMultiEndeksInterval(chartData);
          // Y ekseni sınırlarını hesapla
          Map<String, double> yAxisBounds =
              _calculateMultiEndeksYAxisBounds(chartData, interval);

          return Column(
            children: [
              // Legend
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 16,
                      height: 3,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    const Text('Web TÜFE', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 20),
                    Container(
                      width: 16,
                      height: 3,
                      color: Colors.red,
                    ),
                    const SizedBox(width: 8),
                    const Text('TÜİK TÜFE', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              Expanded(
                child: LineChart(
                  LineChartData(
                    minY: yAxisBounds['minY'],
                    maxY: yAxisBounds['maxY'],
                    gridData: FlGridData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 60,
                          interval: interval,
                          getTitlesWidget: (value, meta) {
                            // Interval'e göre format belirle
                            if (interval >= 25.0) {
                              return Text(
                                value.toInt().toString(),
                                style: const TextStyle(fontSize: 10),
                              );
                            } else if (interval >= 10.0) {
                              return Text(
                                value.toInt().toString(),
                                style: const TextStyle(fontSize: 10),
                              );
                            } else if (interval >= 5.0) {
                              return Text(
                                value.toInt().toString(),
                                style: const TextStyle(fontSize: 10),
                              );
                            } else {
                              return Text(
                                value.toStringAsFixed(1),
                                style: const TextStyle(fontSize: 10),
                              );
                            }
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles:
                          AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles:
                          AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    lineBarsData: lineBarsData,
                    lineTouchData: LineTouchData(
                      enabled: true,
                      touchTooltipData: LineTouchTooltipData(
                        fitInsideHorizontally: true,
                        fitInsideVertically: true,
                        getTooltipItems: (List<LineBarSpot> touchedSpots) {
                          return touchedSpots.map((LineBarSpot touchedSpot) {
                            final barIndex = touchedSpot.barIndex;
                            final label =
                                barIndex == 0 ? 'Web TÜFE' : 'TÜİK TÜFE';
                            final index = touchedSpot.x.toInt();

                            // Tarih bilgisini al
                            String dateInfo = '';
                            if (index >= 0 && index < tufeDates.length) {
                              dateInfo = '${tufeDates[index]}\n';
                            }

                            return LineTooltipItem(
                              '$dateInfo$label\n${touchedSpot.y.toStringAsFixed(2)}',
                              TextStyle(
                                color: barIndex == 0 ? Colors.blue : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          }).toList();
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget buildSingleEndeksChart() {
    final spots = getMainChartData();
    if (spots.isEmpty) {
      return const Center(child: Text('Veri bulunamadı'));
    }

    // Dinamik interval hesapla
    double interval = _calculateEndeksInterval(spots);
    // Y ekseni sınırlarını hesapla
    Map<String, double> yAxisBounds =
        _calculateEndeksYAxisBounds(spots, interval);

    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      child: LineChart(
        LineChartData(
          minY: yAxisBounds['minY'],
          maxY: yAxisBounds['maxY'],
          gridData: FlGridData(show: false), // Grid çizgilerini kaldır
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 60,
                interval: interval,
                getTitlesWidget: (value, meta) {
                  // Interval'e göre format belirle
                  if (interval >= 25.0) {
                    return Text(
                      value.toInt().toString(),
                      style: const TextStyle(fontSize: 10),
                    );
                  } else if (interval >= 10.0) {
                    return Text(
                      value.toInt().toString(),
                      style: const TextStyle(fontSize: 10),
                    );
                  } else if (interval >= 5.0) {
                    return Text(
                      value.toInt().toString(),
                      style: const TextStyle(fontSize: 10),
                    );
                  } else {
                    return Text(
                      value.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 10),
                    );
                  }
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: Colors.grey.shade300),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              color: Colors.blue,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.blue.withOpacity(0.1),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItems: (List<LineBarSpot> touchedSpots) {
                return touchedSpots.map((LineBarSpot touchedSpot) {
                  final index = touchedSpot.x.toInt();
                  final currentDates =
                      selectedEndeks == 'Web TÜFE' ? tufeDates : dates;
                  if (index >= 0 && index < currentDates.length) {
                    return LineTooltipItem(
                      '${currentDates[index]}\n${touchedSpot.y.toStringAsFixed(2)}',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  }
                  return null;
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget buildMonthlyChangeChart() {
    if (selectedEndeks == 'Web TÜFE') {
      return buildComparedMonthlyChangeChart();
    } else {
      return buildSingleMonthlyChangeChart();
    }
  }

  /// Aylık değişim grafikleri için dinamik interval hesaplar
  double _calculateMonthlyChangeInterval(List<FlSpot> spots) {
    if (spots.isEmpty) return 1.0;

    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (var spot in spots) {
      if (spot.y < minY) minY = spot.y;
      if (spot.y > maxY) maxY = spot.y;
    }

    double range = maxY - minY;
    
    // Aylık değişim oranları genellikle -10 ile +20 arasında olur
    // Ancak bazen daha geniş aralıklar olabilir
    if (range <= 5) {
      return 0.5; // Çok küçük aralık için 0.5'lik adımlar
    } else if (range <= 10) {
      return 1.0; // Küçük aralık için 1'lik adımlar
    } else if (range <= 20) {
      return 2.0; // Orta aralık için 2'lik adımlar
    } else if (range <= 40) {
      return 5.0; // Geniş aralık için 5'lik adımlar
    } else if (range <= 80) {
      return 10.0; // Çok geniş aralık için 10'luk adımlar
    } else {
      return 20.0; // Aşırı geniş aralık için 20'lik adımlar
    }
  }

  /// Endeks grafikleri için dinamik interval hesaplar
  double _calculateEndeksInterval(List<FlSpot> spots) {
    if (spots.isEmpty) return 5.0;

    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (var spot in spots) {
      if (spot.y < minY) minY = spot.y;
      if (spot.y > maxY) maxY = spot.y;
    }

    double range = maxY - minY;
    
    // Endeks değerleri genellikle 100 civarında başlar ve zamanla artar
    // Örneğin 100-150 arası olabilir, bu yüzden daha büyük interval'ler kullanılmalı
    if (range <= 10) {
      return 2.0; // Çok küçük aralık için 2'lik adımlar
    } else if (range <= 25) {
      return 5.0; // Küçük aralık için 5'lik adımlar
    } else if (range <= 50) {
      return 10.0; // Orta aralık için 10'luk adımlar
    } else if (range <= 100) {
      return 15.0; // Geniş aralık için 15'lik adımlar
    } else if (range <= 200) {
      return 25.0; // Çok geniş aralık için 25'lik adımlar
    } else if (range <= 400) {
      return 50.0; // Aşırı geniş aralık için 50'lik adımlar
    } else {
      return 100.0; // Çok aşırı geniş aralık için 100'lük adımlar
    }
  }

  /// Birden fazla endeks serisi için dinamik interval hesaplar
  double _calculateMultiEndeksInterval(Map<String, List<FlSpot>> chartData) {
    if (chartData.isEmpty) return 5.0;

    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (var series in chartData.values) {
      for (var spot in series) {
        if (spot.y < minY) minY = spot.y;
        if (spot.y > maxY) maxY = spot.y;
      }
    }

    double range = maxY - minY;
    
    if (range <= 10) {
      return 2.0;
    } else if (range <= 25) {
      return 5.0;
    } else if (range <= 50) {
      return 10.0;
    } else if (range <= 100) {
      return 15.0;
    } else if (range <= 200) {
      return 25.0;
    } else if (range <= 400) {
      return 50.0;
    } else {
      return 100.0;
    }
  }

  /// Birden fazla seri için dinamik interval hesaplar
  double _calculateMultiSeriesInterval(Map<String, List<FlSpot>> chartData) {
    if (chartData.isEmpty) return 1.0;

    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (var series in chartData.values) {
      for (var spot in series) {
        if (spot.y < minY) minY = spot.y;
        if (spot.y > maxY) maxY = spot.y;
      }
    }

    double range = maxY - minY;
    
    if (range <= 5) {
      return 0.5;
    } else if (range <= 10) {
      return 1.0;
    } else if (range <= 20) {
      return 2.0;
    } else if (range <= 40) {
      return 5.0;
    } else if (range <= 80) {
      return 10.0;
    } else {
      return 20.0;
    }
  }

  /// Y ekseni için min ve max değerleri interval'e göre ayarlar (çakışmayı önlemek için)
  Map<String, double> _calculateYAxisBounds(List<FlSpot> spots, double interval) {
    if (spots.isEmpty) {
      return {'minY': 0.0, 'maxY': 100.0};
    }

    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (var spot in spots) {
      if (spot.y < minY) minY = spot.y;
      if (spot.y > maxY) maxY = spot.y;
    }

    // Interval'e göre min ve max değerleri yuvarla ve padding ekle
    // Min değeri aşağıya yuvarla
    double adjustedMinY = (minY / interval).floor() * interval;
    // Max değeri yukarıya yuvarla ve bir interval daha ekle (padding)
    double adjustedMaxY = (maxY / interval).ceil() * interval + interval;

    return {'minY': adjustedMinY, 'maxY': adjustedMaxY};
  }

  /// Birden fazla seri için Y ekseni min ve max değerlerini hesaplar
  Map<String, double> _calculateMultiSeriesYAxisBounds(
      Map<String, List<FlSpot>> chartData, double interval) {
    if (chartData.isEmpty) {
      return {'minY': 0.0, 'maxY': 100.0};
    }

    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (var series in chartData.values) {
      for (var spot in series) {
        if (spot.y < minY) minY = spot.y;
        if (spot.y > maxY) maxY = spot.y;
      }
    }

    // Interval'e göre min ve max değerleri yuvarla ve padding ekle
    double adjustedMinY = (minY / interval).floor() * interval;
    double adjustedMaxY = (maxY / interval).ceil() * interval + interval;

    return {'minY': adjustedMinY, 'maxY': adjustedMaxY};
  }

  /// Endeks grafikleri için Y ekseni min ve max değerlerini hesaplar
  Map<String, double> _calculateEndeksYAxisBounds(
      List<FlSpot> spots, double interval) {
    if (spots.isEmpty) {
      return {'minY': 0.0, 'maxY': 100.0};
    }

    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (var spot in spots) {
      if (spot.y < minY) minY = spot.y;
      if (spot.y > maxY) maxY = spot.y;
    }

    // Interval'e göre min ve max değerleri yuvarla ve padding ekle
    double adjustedMinY = (minY / interval).floor() * interval;
    double adjustedMaxY = (maxY / interval).ceil() * interval + interval;

    return {'minY': adjustedMinY, 'maxY': adjustedMaxY};
  }

  /// Birden fazla endeks serisi için Y ekseni min ve max değerlerini hesaplar
  Map<String, double> _calculateMultiEndeksYAxisBounds(
      Map<String, List<FlSpot>> chartData, double interval) {
    if (chartData.isEmpty) {
      return {'minY': 0.0, 'maxY': 100.0};
    }

    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (var series in chartData.values) {
      for (var spot in series) {
        if (spot.y < minY) minY = spot.y;
        if (spot.y > maxY) maxY = spot.y;
      }
    }

    // Interval'e göre min ve max değerleri yuvarla ve padding ekle
    double adjustedMinY = (minY / interval).floor() * interval;
    double adjustedMaxY = (maxY / interval).ceil() * interval + interval;

    return {'minY': adjustedMinY, 'maxY': adjustedMaxY};
  }

  Widget buildComparedMonthlyChangeChart() {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      child: FutureBuilder<Map<String, List<FlSpot>>>(
        future: getComparedMonthlyChangeChartData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Aylık veri yükleme hatası'));
          }

          final chartData = snapshot.data ?? {};
          if (chartData.isEmpty) {
            return const Center(child: Text('Aylık veri bulunamadı'));
          }

          List<LineChartBarData> lineBarsData = [];

          // Web TÜFE çizgisi (mavi)
          if (chartData.containsKey('Web TÜFE')) {
            lineBarsData.add(
              LineChartBarData(
                spots: chartData['Web TÜFE']!,
                isCurved: false,
                color: Colors.blue,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: Colors.blue.withOpacity(0.1),
                ),
              ),
            );
          }

          // TÜİK TÜFE çizgisi (kırmızı)
          if (chartData.containsKey('TÜİK TÜFE')) {
            lineBarsData.add(
              LineChartBarData(
                spots: chartData['TÜİK TÜFE']!,
                isCurved: false,
                color: Colors.red,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: Colors.red.withOpacity(0.1),
                ),
              ),
            );
          }

          // Dinamik interval hesapla
          double interval = _calculateMultiSeriesInterval(chartData);
          // Y ekseni sınırlarını hesapla
          Map<String, double> yAxisBounds =
              _calculateMultiSeriesYAxisBounds(chartData, interval);

          return Column(
            children: [
              // Legend
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 16,
                      height: 3,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    const Text('Web TÜFE', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 20),
                    Container(
                      width: 16,
                      height: 3,
                      color: Colors.red,
                    ),
                    const SizedBox(width: 8),
                    const Text('TÜİK TÜFE', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              Expanded(
                child: LineChart(
                  LineChartData(
                    minY: yAxisBounds['minY'],
                    maxY: yAxisBounds['maxY'],
                    gridData: FlGridData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 60,
                          interval: interval,
                          getTitlesWidget: (value, meta) {
                            // Interval'e göre format belirle
                            if (interval >= 10.0) {
                              return Text(
                                value.toInt().toString(),
                                style: const TextStyle(fontSize: 10),
                              );
                            } else if (interval >= 2.0) {
                              return Text(
                                value.toStringAsFixed(0),
                                style: const TextStyle(fontSize: 10),
                              );
                            } else {
                              return Text(
                                value.toStringAsFixed(1),
                                style: const TextStyle(fontSize: 10),
                              );
                            }
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles:
                          AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles:
                          AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    lineBarsData: lineBarsData,
                    lineTouchData: LineTouchData(
                      enabled: true,
                      touchTooltipData: LineTouchTooltipData(
                        fitInsideHorizontally: true,
                        fitInsideVertically: true,
                        getTooltipItems: (List<LineBarSpot> touchedSpots) {
                          return touchedSpots.map((LineBarSpot touchedSpot) {
                            final barIndex = touchedSpot.barIndex;
                            final label =
                                barIndex == 0 ? 'Web TÜFE' : 'TÜİK TÜFE';
                            final index = touchedSpot.x.toInt();

                            // TÜİK verisi yoksa tooltip gösterme
                            if (barIndex == 1 && touchedSpot.y.isNaN) {
                              return null;
                            }

                            // Tarih bilgisini al
                            String dateInfo = '';
                            if (index >= 0 && index < comparisonDates.length) {
                              String dateStr = comparisonDates[index];
                              // "YYYY-MM" formatını daha okunabilir formata çevir
                              try {
                                List<String> parts = dateStr.split('-');
                                if (parts.length == 2) {
                                  int month = int.parse(parts[1]);
                                  String year = parts[0];
                                  const months = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
                                    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
                                  dateInfo = '${months[month - 1]} $year\n';
                                } else {
                                  dateInfo = '$dateStr\n';
                                }
                              } catch (e) {
                                dateInfo = '$dateStr\n';
                              }
                            }

                            return LineTooltipItem(
                              '$dateInfo$label\n${touchedSpot.y.toStringAsFixed(2)}%',
                              TextStyle(
                                color: barIndex == 0 ? Colors.blue : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          }).where((item) => item != null).cast<LineTooltipItem>().toList();
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget buildSingleMonthlyChangeChart() {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      child: FutureBuilder<List<FlSpot>>(
        future: getMonthlyChangeChartData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Aylık veri yükleme hatası'));
          }

          final spots = snapshot.data ?? [];
          if (spots.isEmpty) {
            return const Center(child: Text('Aylık veri bulunamadı'));
          }

          // Dinamik interval hesapla
          double interval = _calculateMonthlyChangeInterval(spots);
          // Y ekseni sınırlarını hesapla
          Map<String, double> yAxisBounds =
              _calculateYAxisBounds(spots, interval);

          return LineChart(
            LineChartData(
              minY: yAxisBounds['minY'],
              maxY: yAxisBounds['maxY'],
              gridData: FlGridData(show: false), // Grid çizgilerini kaldır
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 60,
                    interval: interval,
                    getTitlesWidget: (value, meta) {
                      // Interval'e göre format belirle
                      if (interval >= 10.0) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 10),
                        );
                      } else if (interval >= 2.0) {
                        return Text(
                          value.toStringAsFixed(0),
                          style: const TextStyle(fontSize: 10),
                        );
                      } else {
                        return Text(
                          value.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 10),
                        );
                      }
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: Colors.grey.shade300),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: false,
                  color: Colors.green,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Colors.green.withOpacity(0.1),
                  ),
                ),
              ],
              lineTouchData: LineTouchData(
                enabled: true,
                touchTooltipData: LineTouchTooltipData(
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItems: (List<LineBarSpot> touchedSpots) {
                    return touchedSpots.map((LineBarSpot touchedSpot) {
                      final index = touchedSpot.x.toInt();
                      if (index >= 0 && index < singleChartDates.length) {
                        return LineTooltipItem(
                          '${singleChartDates[index]}\n${touchedSpot.y.toStringAsFixed(2)}%',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }
                      return null;
                    }).toList();
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildTopSection(),
          const SizedBox(height: 24),
          Text(
            _getChartTitle(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade800,
            ),
          ),
          const SizedBox(height: 16),
          buildMainChart(),
          const SizedBox(height: 24),
          Text(
            'Aylık Değişim Oranları',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade800,
            ),
          ),
          const SizedBox(height: 16),
          buildMonthlyChangeChart(),
        ],
      ),
    );
  }

  String _getChartTitle() {
    if (selectedEndeks.isEmpty) {
      return 'Endeks Değerleri';
    }

    if (selectedEndeks == 'Web TÜFE') {
      return 'Web Tüketici Fiyat Endeksi';
    }

    return '$selectedEndeks Endeksi';
  }
}
