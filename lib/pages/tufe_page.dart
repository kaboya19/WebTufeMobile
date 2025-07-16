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

        // TÜİK tarihlerini al (daha uzun olma ihtimali yüksek)
        final tuikDates = tuikData['dates'] as List<String>;
        final webTufeDates = monthlyData['dates'] as List<String>;

        // Daha uzun olan tarih listesini kullan
        comparisonDates =
            tuikDates.length >= webTufeDates.length ? tuikDates : webTufeDates;

        // Web TÜFE verisi
        if (monthlyData['data']['Web TÜFE'] != null) {
          final values = monthlyData['data']['Web TÜFE'] as List<double>;
          result['Web TÜFE'] = values.asMap().entries.map((entry) {
            return FlSpot(entry.key.toDouble(), entry.value);
          }).toList();
        }

        // TÜİK TÜFE verisi
        if (tuikData['data']['TÜİK TÜFE'] != null) {
          final values = tuikData['data']['TÜİK TÜFE'] as List<double>;
          result['TÜİK TÜFE'] = values.asMap().entries.map((entry) {
            return FlSpot(entry.key.toDouble(), entry.value);
          }).toList();
        }

        return result;
      }

      return {};
    } catch (e) {
      print('Karşılaştırmalı aylık veri yükleme hatası: $e');
      return {};
    }
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
          double minY = double.infinity;
          double maxY = double.negativeInfinity;

          for (var series in chartData.values) {
            for (var spot in series) {
              if (spot.y < minY) minY = spot.y;
              if (spot.y > maxY) maxY = spot.y;
            }
          }

          double range = maxY - minY;
          double interval = 5.0;
          if (range <= 20) {
            interval = 2.0;
          } else if (range <= 50) {
            interval = 5.0;
          } else if (range <= 100) {
            interval = 10.0;
          } else if (range <= 200) {
            interval = 15.0;
          } else {
            interval = 20.0;
          }

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
                    gridData: FlGridData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 60,
                          interval: interval,
                          getTitlesWidget: (value, meta) {
                            if (interval >= 10.0) {
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

    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false), // Grid çizgilerini kaldır
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 60,
                interval: 5, // 5'er 5'er göster
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 10),
                  );
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
                    gridData: FlGridData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 60,
                          interval: 1.0,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              value.toStringAsFixed(1),
                              style: const TextStyle(fontSize: 10),
                            );
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
                            if (index >= 0 && index < comparisonDates.length) {
                              dateInfo = '${comparisonDates[index]}\n';
                            }

                            return LineTooltipItem(
                              '$dateInfo$label\n${touchedSpot.y.toStringAsFixed(2)}%',
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

          return LineChart(
            LineChartData(
              gridData: FlGridData(show: false), // Grid çizgilerini kaldır
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 60,
                    interval: 1.0,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 10),
                      );
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
