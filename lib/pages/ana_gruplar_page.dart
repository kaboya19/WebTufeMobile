import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/gruplar_service.dart';
import '../services/tuik_service.dart';

class AnaGruplarPage extends StatefulWidget {
  const AnaGruplarPage({Key? key}) : super(key: key);

  @override
  State<AnaGruplarPage> createState() => _AnaGruplarPageState();
}

class _AnaGruplarPageState extends State<AnaGruplarPage> {
  List<double> grupIndexData = [];
  List<double> grupMonthlyChangeData = [];
  List<String> indexDates = [];
  List<String> monthlyDates = [];
  String selectedGrup = '';
  List<String> availableGruplar = [];
  bool isLoading = true;

  // Karşılaştırmalı veriler için
  List<String> comparisonDates = [];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    try {
      final gruplarList = await GruplarService.getGrupNames();

      setState(() {
        availableGruplar = gruplarList;
        if (availableGruplar.isNotEmpty) {
          selectedGrup = availableGruplar.first;
        }
        isLoading = false;
      });

      // İlk grubu seç ve verisini yükle
      if (availableGruplar.isNotEmpty) {
        await loadGrupData(selectedGrup);
      }
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> loadGrupData(String grupName) async {
    try {
      final indexData = await GruplarService.getGrupIndexData(grupName);
      final monthlyData =
          await GruplarService.getGrupMonthlyChangeData(grupName);
      final dates = await GruplarService.getIndexDates();
      final monthlyDatesList = await GruplarService.getMonthlyDates();

      setState(() {
        grupIndexData = indexData;
        grupMonthlyChangeData = monthlyData;
        indexDates = dates;
        monthlyDates = monthlyDatesList;
      });
    } catch (e) {
      print('Error loading grup data: $e');
    }
  }

  double getYearToDateChange() {
    if (grupIndexData.isEmpty) return 0.0;

    // Year to date change = last value - 100
    return grupIndexData.last - 100.0;
  }

  double getMonthlyChange() {
    if (grupMonthlyChangeData.isEmpty) return 0.0;

    // Son ayın değişim oranı
    return grupMonthlyChangeData.last;
  }

  List<FlSpot> getMainChartData() {
    if (grupIndexData.isEmpty) return [];

    return grupIndexData.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value);
    }).toList();
  }

  // Karşılaştırmalı endeks verisi
  Future<Map<String, List<FlSpot>>> getComparedIndexChartData() async {
    if (selectedGrup.isEmpty) return {};

    try {
      // Web TÜFE ana grup endeks verilerini al
      final webIndexData = await GruplarService.getGrupIndexData(selectedGrup);
      final webDates = await GruplarService.getIndexDates();

      // TÜİK ana grup endeks verilerini al
      final tuikData =
          await TuikService.loadTuikAnaGrupEndeksData(selectedGrup);

      Map<String, List<FlSpot>> result = {};

      // Web TÜFE ana grup verisi (günlük)
      if (webIndexData.isNotEmpty) {
        result['Web TÜFE'] = webIndexData.asMap().entries.map((entry) {
          return FlSpot(entry.key.toDouble(), entry.value);
        }).toList();
      }

      // TÜİK ana grup verisi (aylık) - tarihleri eşleştir ve step plot için hazırla
      if (tuikData['data']['TÜİK $selectedGrup'] != null) {
        final tuikValues =
            tuikData['data']['TÜİK $selectedGrup'] as List<double>;
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
              for (int webIndex = webDates.length - 1;
                  webIndex >= 0;
                  webIndex--) {
                String webDate = webDates[webIndex]; // Format: dd.mm.yyyy
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
            print('Ana grup endeks tarih eşleştirme hatası: $e');
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
            for (double x = lastX + 1; x < webDates.length; x++) {
              stepSpots.add(FlSpot(x, lastY));
            }
          }
        }

        result['TÜİK TÜFE'] = stepSpots;
      }

      return result;
    } catch (e) {
      print('Karşılaştırmalı ana grup endeks veri yükleme hatası: $e');
      return {};
    }
  }

  List<FlSpot> getMonthlyChangeChartData() {
    if (grupMonthlyChangeData.isEmpty) return [];

    return grupMonthlyChangeData.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value);
    }).toList();
  }

  // Karşılaştırmalı aylık değişim verisini al
  Future<Map<String, List<FlSpot>>> getComparedMonthlyChangeChartData() async {
    if (selectedGrup.isEmpty) return {};

    try {
      // Ana grup aylık verisini al
      final monthlyData = await GruplarService.loadGruplarAylikData();
      // TÜİK ana grup verisini al
      final tuikData = await TuikService.loadTuikAnaGrupData(selectedGrup);

      Map<String, List<FlSpot>> result = {};

      // Tarih listelerini al
      final webTufeDates = monthlyData['dates'] as List<String>;
      final tuikDates = tuikData['dates'] as List<String>;

      // Daha uzun olan tarih listesini kullan
      comparisonDates =
          tuikDates.length >= webTufeDates.length ? tuikDates : webTufeDates;

      // Web TÜFE ana grup verisi
      if (monthlyData['data'][selectedGrup] != null) {
        final values = monthlyData['data'][selectedGrup] as List<double>;
        result[selectedGrup] = values.asMap().entries.map((entry) {
          return FlSpot(entry.key.toDouble(), entry.value);
        }).toList();
      }

      // TÜİK ana grup verisi
      if (tuikData['data']['TÜİK $selectedGrup'] != null) {
        final values = tuikData['data']['TÜİK $selectedGrup'] as List<double>;
        result['TÜİK $selectedGrup'] = values.asMap().entries.map((entry) {
          return FlSpot(entry.key.toDouble(), entry.value);
        }).toList();
      }

      return result;
    } catch (e) {
      print('Karşılaştırmalı ana grup aylık veri yükleme hatası: $e');
      return {};
    }
  }

  Widget buildTopSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade600,
            Colors.blue.shade800,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Ana Gruplar',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedGrup.isEmpty ? null : selectedGrup,
                isExpanded: true,
                hint: Text('Grup Seçiniz'),
                items: availableGruplar.map((String grup) {
                  return DropdownMenuItem<String>(
                    value: grup,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(grup),
                    ),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      selectedGrup = newValue;
                    });
                    loadGrupData(newValue);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
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
      ),
    );
  }

  Widget buildStatsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildStatCard(
            'Yıl Başından İtibaren',
            '${getYearToDateChange().toStringAsFixed(2)}%',
            getYearToDateChange() >= 0 ? Colors.green : Colors.red,
          ),
          _buildStatCard(
            'Aylık Değişim',
            '${getMonthlyChange().toStringAsFixed(2)}%',
            getMonthlyChange() >= 0 ? Colors.green : Colors.red,
          ),
        ],
      ),
    );
  }

  Widget buildIndexChart() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_getChartTitle()} - Karşılaştırmalı',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 300,
            child: FutureBuilder<Map<String, List<FlSpot>>>(
              future: getComparedIndexChartData(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return const Center(
                      child: Text('Endeks veri yükleme hatası'));
                }

                final chartData = snapshot.data ?? {};
                if (chartData.isEmpty) {
                  return const Center(child: Text('Endeks veri bulunamadı'));
                }

                List<LineChartBarData> lineBarsData = [];

                // Web TÜFE ana grup çizgisi (mavi)
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

                // TÜİK TÜFE ana grup çizgisi (kırmızı) - Step plot
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
                          Text('Web TÜFE $selectedGrup',
                              style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 20),
                          Container(
                            width: 16,
                            height: 3,
                            color: Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Text('TÜİK $selectedGrup',
                              style: const TextStyle(fontSize: 12)),
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
                            rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
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
                              getTooltipItems:
                                  (List<LineBarSpot> touchedSpots) {
                                return touchedSpots
                                    .map((LineBarSpot touchedSpot) {
                                  final barIndex = touchedSpot.barIndex;
                                  final label = barIndex == 0
                                      ? 'Web TÜFE $selectedGrup'
                                      : 'TÜİK $selectedGrup';
                                  final index = touchedSpot.x.toInt();

                                  // Tarih bilgisini al
                                  String dateInfo = '';
                                  if (index >= 0 && index < indexDates.length) {
                                    dateInfo = '${indexDates[index]}\n';
                                  }

                                  return LineTooltipItem(
                                    '$dateInfo$label\n${touchedSpot.y.toStringAsFixed(2)}',
                                    TextStyle(
                                      color: barIndex == 0
                                          ? Colors.blue
                                          : Colors.red,
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
          ),
        ],
      ),
    );
  }

  Widget buildMonthlyChart() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Aylık Değişim (%) - Karşılaştırmalı',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 300,
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

                // Web TÜFE ana grup çizgisi (mavi)
                if (chartData.containsKey(selectedGrup)) {
                  lineBarsData.add(
                    LineChartBarData(
                      spots: chartData[selectedGrup]!,
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

                // TÜİK ana grup çizgisi (kırmızı)
                if (chartData.containsKey('TÜİK $selectedGrup')) {
                  lineBarsData.add(
                    LineChartBarData(
                      spots: chartData['TÜİK $selectedGrup']!,
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
                          Text('Web TÜFE $selectedGrup',
                              style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 20),
                          Container(
                            width: 16,
                            height: 3,
                            color: Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Text('TÜİK $selectedGrup',
                              style: const TextStyle(fontSize: 12)),
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
                            rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
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
                              getTooltipItems:
                                  (List<LineBarSpot> touchedSpots) {
                                return touchedSpots
                                    .map((LineBarSpot touchedSpot) {
                                  final barIndex = touchedSpot.barIndex;
                                  final label = barIndex == 0
                                      ? 'Web TÜFE $selectedGrup'
                                      : 'TÜİK $selectedGrup';
                                  final index = touchedSpot.x.toInt();

                                  // Tarih bilgisini al
                                  String dateInfo = '';
                                  if (index >= 0 &&
                                      index < comparisonDates.length) {
                                    dateInfo = '${comparisonDates[index]}\n';
                                  }

                                  return LineTooltipItem(
                                    '$dateInfo$label\n${touchedSpot.y.toStringAsFixed(2)}%',
                                    TextStyle(
                                      color: barIndex == 0
                                          ? Colors.blue
                                          : Colors.red,
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
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SingleChildScrollView(
        child: Column(
          children: [
            buildTopSection(),
            buildStatsSection(),
            buildIndexChart(),
            buildMonthlyChart(),
          ],
        ),
      ),
    );
  }

  String _getChartTitle() {
    if (selectedGrup.isEmpty) {
      return 'Endeks Değerleri';
    }

    return '$selectedGrup Endeksi';
  }
}
