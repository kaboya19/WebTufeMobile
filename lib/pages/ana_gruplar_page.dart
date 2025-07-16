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
            _getChartTitle(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: grupIndexData.isEmpty || getMainChartData().isEmpty
                ? const Center(
                    child: Text(
                      'Veri yükleniyor...',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: true,
                        horizontalInterval: 10,
                        verticalInterval: 10,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Colors.grey.withOpacity(0.3),
                            strokeWidth: 1,
                          );
                        },
                        getDrawingVerticalLine: (value) {
                          return FlLine(
                            color: Colors.grey.withOpacity(0.3),
                            strokeWidth: 1,
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            interval: 5, // 5'er 5'er göster
                            getTitlesWidget: (value, meta) {
                              return SideTitleWidget(
                                axisSide: meta.axisSide,
                                child: Text(
                                  value.toInt().toString(),
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border.all(color: Colors.grey.withOpacity(0.3)),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: getMainChartData(),
                          isCurved: false,
                          color: Colors.blue.shade600,
                          barWidth: 2,
                          isStrokeCapRound: true,
                          dotData: FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: Colors.blue.shade600.withOpacity(0.1),
                          ),
                        ),
                      ],
                      lineTouchData: LineTouchData(
                        enabled: true,
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (List<LineBarSpot> touchedSpots) {
                            return touchedSpots.map((LineBarSpot touchedSpot) {
                              final index = touchedSpot.x.toInt();
                              if (index >= 0 && index < indexDates.length) {
                                return LineTooltipItem(
                                  '${indexDates[index]}\n${touchedSpot.y.toStringAsFixed(2)}',
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
