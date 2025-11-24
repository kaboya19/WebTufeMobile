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

      final webTufeDates = monthlyData['dates'] as List<String>;
      final tuikDates = tuikData['dates'] as List<String>;

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

      // Web TÜFE ana grup verisi - tüm tarihler için
      if (monthlyData['data'][selectedGrup] != null) {
        final values = monthlyData['data'][selectedGrup] as List<double>;
        List<FlSpot> webTufeSpots = [];
        for (int i = 0; i < webTufeDateList.length; i++) {
          int webIndex = webTufeDateList[i].value;
          if (webIndex < values.length) {
            webTufeSpots.add(FlSpot(i.toDouble(), values[webIndex]));
          }
        }
        result[selectedGrup] = webTufeSpots;
      }

      // TÜİK ana grup verisi - Web TÜFE tarihlerine göre eşleştir (sadece mevcut verileri ekle)
      if (tuikData['data']['TÜİK $selectedGrup'] != null) {
        final values = tuikData['data']['TÜİK $selectedGrup'] as List<double>;
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
        result['TÜİK $selectedGrup'] = tuikSpots;
      }

      return result;
    } catch (e) {
      print('Karşılaştırmalı ana grup aylık veri yükleme hatası: $e');
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

                                  // TÜİK verisi yoksa tooltip gösterme
                                  if (barIndex == 1 && touchedSpot.y.isNaN) {
                                    return null;
                                  }

                                  // Tarih bilgisini al
                                  String dateInfo = '';
                                  if (index >= 0 &&
                                      index < comparisonDates.length) {
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
                                      color: barIndex == 0
                                          ? Colors.blue
                                          : Colors.red,
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

    double adjustedMinY = (minY / interval).floor() * interval;
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

    double adjustedMinY = (minY / interval).floor() * interval;
    double adjustedMaxY = (maxY / interval).ceil() * interval + interval;

    return {'minY': adjustedMinY, 'maxY': adjustedMaxY};
  }
}
