import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/ozel_gosterge_data.dart';
import '../services/tuik_service.dart';

class OzelGostergelerChart extends StatefulWidget {
  final OzelGostergeData data;

  const OzelGostergelerChart({
    super.key,
    required this.data,
  });

  @override
  State<OzelGostergelerChart> createState() => _OzelGostergelerChartState();
}

class _OzelGostergelerChartState extends State<OzelGostergelerChart> {
  Map<String, dynamic> tuikData = {'dates': [], 'data': {}};
  Map<String, dynamic> tuikEndeksData = {'dates': [], 'data': {}};
  bool isLoadingTuik = true;
  bool isLoadingTuikEndeks = true;

  @override
  void initState() {
    super.initState();
    _loadTuikData();
    _loadTuikEndeksData();
  }

  @override
  void didUpdateWidget(OzelGostergelerChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.gostergeName != widget.data.gostergeName) {
      _loadTuikData();
      _loadTuikEndeksData();
    }
  }

  Future<void> _loadTuikData() async {
    setState(() {
      isLoadingTuik = true;
    });

    try {
      final result =
          await TuikService.loadTuikOzelGostergeData(widget.data.gostergeName);
      setState(() {
        tuikData = result;
        isLoadingTuik = false;
      });
    } catch (e) {
      print('TÜİK özel gösterge veri yükleme hatası: $e');
      setState(() {
        tuikData = {'dates': [], 'data': {}};
        isLoadingTuik = false;
      });
    }
  }

  Future<void> _loadTuikEndeksData() async {
    setState(() {
      isLoadingTuikEndeks = true;
    });

    try {
      final result = await TuikService.loadTuikOzelGostergeEndeksData(
          widget.data.gostergeName);
      setState(() {
        tuikEndeksData = result;
        isLoadingTuikEndeks = false;
      });
    } catch (e) {
      print('TÜİK özel gösterge endeks veri yükleme hatası: $e');
      setState(() {
        tuikEndeksData = {'dates': [], 'data': {}};
        isLoadingTuikEndeks = false;
      });
    }
  }

  // Karşılaştırmalı endeks verisi
  Future<Map<String, List<FlSpot>>>
      getComparedOzelGostergeEndeksChartData() async {
    try {
      print(
          'Özel gösterge karşılaştırmalı endeks chart data yükleniyor: ${widget.data.gostergeName}');
      print(
          'Web TÜFE özel gösterge veri sayısı: ${widget.data.dailyValues.length}');
      if (widget.data.dates.isNotEmpty) {
        print('İlk Web TÜFE tarihi: ${widget.data.dates.first}');
        print('Son Web TÜFE tarihi: ${widget.data.dates.last}');
      }

      Map<String, List<FlSpot>> result = {};

      // Web TÜFE özel gösterge verisi (günlük)
      if (widget.data.dailyValues.isNotEmpty) {
        result['Web TÜFE'] =
            widget.data.dailyValues.asMap().entries.map((entry) {
          return FlSpot(entry.key.toDouble(), entry.value);
        }).toList();
      }

      // TÜİK özel gösterge verisi (aylık) - tarihleri eşleştir ve step plot için hazırla
      if (tuikEndeksData['data']['TÜİK ${widget.data.gostergeName}'] != null) {
        final tuikValues = tuikEndeksData['data']
            ['TÜİK ${widget.data.gostergeName}'] as List<double>;
        final tuikDates = tuikEndeksData['dates'] as List<String>;

        List<FlSpot> tuikSpots = [];

        // TÜİK verilerini Web TÜFE tarihlerinin ayın son günlerine eşleştir
        print(
            'TÜİK özel gösterge tarih eşleştirmesi başlıyor. TÜİK veri sayısı: ${tuikDates.length}');
        for (int tuikIndex = 0; tuikIndex < tuikDates.length; tuikIndex++) {
          String tuikDate = tuikDates[tuikIndex]; // Format: dd.mm.yyyy
          double tuikValue = tuikValues[tuikIndex];

          if (tuikValue.isNaN) {
            print('TÜİK değeri NaN, atlanıyor: $tuikDate');
            continue;
          }

          try {
            List<String> tuikDateParts = tuikDate.split('.');
            if (tuikDateParts.length == 3) {
              String tuikMonth = tuikDateParts[1]; // mm
              String tuikYear = tuikDateParts[2]; // yyyy

              print(
                  'TÜİK özel gösterge tarih eşleştiriliyor: $tuikDate (${tuikMonth}.${tuikYear}) = $tuikValue');

              // Web TÜFE tarihlerinde bu ayın son gününü bul
              int lastDayIndex = -1;
              for (int webIndex = widget.data.dates.length - 1;
                  webIndex >= 0;
                  webIndex--) {
                String webDate =
                    widget.data.dates[webIndex]; // Format: yyyy-mm-dd
                List<String> webDateParts = webDate.split('-');
                if (webDateParts.length == 3) {
                  String webMonth = webDateParts[1]; // mm
                  String webYear = webDateParts[0]; // yyyy

                  if (webMonth == tuikMonth && webYear == tuikYear) {
                    lastDayIndex = webIndex;
                    print(
                        'Eşleşme bulundu! Web tarih: $webDate, indeks: $lastDayIndex');
                    break; // Bu ayın son gününü bulduk
                  }
                }
              }

              // Eğer o ayın son günü bulunduysa TÜİK verisini ekle
              if (lastDayIndex != -1) {
                tuikSpots.add(FlSpot(lastDayIndex.toDouble(), tuikValue));
                print(
                    'TÜİK özel gösterge spot eklendi: ($lastDayIndex, $tuikValue)');
              } else {
                print(
                    'Bu ay için Web TÜFE verisi bulunamadı: ${tuikMonth}.${tuikYear}');
              }
            }
          } catch (e) {
            print('Özel gösterge endeks tarih eşleştirme hatası: $e');
          }
        }

        // TÜİK spots'ları x değerine göre sırala
        tuikSpots.sort((a, b) => a.x.compareTo(b.x));

        print('Toplam TÜİK özel gösterge spot sayısı: ${tuikSpots.length}');
        if (tuikSpots.isNotEmpty) {
          print('İlk TÜİK spot: (${tuikSpots.first.x}, ${tuikSpots.first.y})');
          print('Son TÜİK spot: (${tuikSpots.last.x}, ${tuikSpots.last.y})');
        }

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
            for (double x = lastX + 1; x < widget.data.dates.length; x++) {
              stepSpots.add(FlSpot(x, lastY));
            }
          }
        }

        result['TÜİK TÜFE'] = stepSpots;
        print('Step plot spots sayısı: ${stepSpots.length}');
      }

      print('Final özel gösterge endeks result: ${result.keys.toList()}');
      return result;
    } catch (e) {
      print('Karşılaştırmalı özel gösterge endeks veri yükleme hatası: $e');
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Günlük Endeks Grafiği
        buildDailyChart(),
        const SizedBox(height: 32),
        // Aylık Değişim Grafiği (TÜİK karşılaştırmalı)
        buildMonthlyChart(),
      ],
    );
  }

  Widget buildDailyChart() {
    if (widget.data.dailyValues.isEmpty) {
      return const Center(child: Text('Günlük veri bulunamadı'));
    }

    if (isLoadingTuikEndeks) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Endeks Değerleri (Karşılaştırmalı)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
            const SizedBox(height: 100),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('TÜİK endeks verileri yükleniyor...'),
          ],
        ),
      );
    }

    return FutureBuilder<Map<String, List<FlSpot>>>(
      future: getComparedOzelGostergeEndeksChartData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: const Column(
              children: [
                SizedBox(height: 100),
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Karşılaştırmalı endeks verileri hazırlanıyor...'),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return const Center(child: Text('Endeks veri yükleme hatası'));
        }

        final chartData = snapshot.data ?? {};
        if (chartData.isEmpty) {
          return const Center(child: Text('Endeks veri bulunamadı'));
        }

        List<LineChartBarData> lineBarsData = [];

        // Web TÜFE özel gösterge çizgisi (mavi)
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

        // TÜİK özel gösterge çizgisi (kırmızı) - Step plot
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
        if (range <= 10) {
          interval = 2.0;
        } else if (range <= 25) {
          interval = 5.0;
        } else if (range <= 50) {
          interval = 10.0;
        } else if (range <= 100) {
          interval = 15.0;
        } else if (range <= 200) {
          interval = 25.0;
        } else if (range <= 400) {
          interval = 50.0;
        } else {
          interval = 100.0;
        }

        // Y ekseni sınırlarını interval'e göre ayarla
        double adjustedMinY = (minY / interval).floor() * interval;
        double adjustedMaxY = (maxY / interval).ceil() * interval + interval;

        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Endeks Değerleri (Karşılaştırmalı)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
              const SizedBox(height: 12),

              // Legend
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 16,
                    height: 3,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  Text('Web TÜFE ${widget.data.gostergeName}',
                      style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 20),
                  Container(
                    width: 16,
                    height: 3,
                    color: Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Text('TÜİK ${widget.data.gostergeName}',
                      style: const TextStyle(fontSize: 12)),
                ],
              ),
              const SizedBox(height: 16),

              SizedBox(
                height: 350,
                child: LineChart(
                  LineChartData(
                    minY: adjustedMinY,
                    maxY: adjustedMaxY,
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
                            final label = barIndex == 0
                                ? 'Web TÜFE ${widget.data.gostergeName}'
                                : 'TÜİK ${widget.data.gostergeName}';
                            final index = touchedSpot.x.toInt();

                            // Tarih bilgisini al
                            String dateInfo = '';
                            if (index >= 0 &&
                                index < widget.data.dates.length) {
                              dateInfo = '${widget.data.dates[index]}\n';
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
          ),
        );
      },
    );
  }

  Widget buildMonthlyChart() {
    if (widget.data.monthlyChanges.isEmpty) {
      return const Center(child: Text('Aylık değişim verisi bulunamadı'));
    }

    if (isLoadingTuik) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Aylık Değişim Oranları (%)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade800,
              ),
            ),
            const SizedBox(height: 100),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('TÜİK verileri yükleniyor...'),
          ],
        ),
      );
    }

    // Tüm verileri birleştir (Web TÜFE + TÜİK)
    List<String> allDates = [];
    List<double> webTufeValues = [];
    List<double> tuikValues = [];

    // Web TÜFE verilerini al ve tarihleri parse et
    Map<String, double> webTufeMap = {};
    List<MapEntry<String, String>> webTufeDateList = []; // "YYYY-MM" -> original date
    for (int i = 0;
        i < widget.data.monthlyDates.length &&
            i < widget.data.monthlyChanges.length;
        i++) {
      String originalDate = widget.data.monthlyDates[i];
      String? yearMonth = _parseDateToYearMonth(originalDate);
      if (yearMonth != null) {
        webTufeMap[yearMonth] = widget.data.monthlyChanges[i];
        webTufeDateList.add(MapEntry(yearMonth, originalDate));
      }
    }
    // Tarihe göre sırala
    webTufeDateList.sort((a, b) => a.key.compareTo(b.key));

    // TÜİK verilerini al ve parse et
    Map<String, double> tuikMap = {};
    if (tuikData['dates'] != null && tuikData['data'] != null) {
      List<String> tuikDates = List<String>.from(tuikData['dates']);
      String tuikKey =
          tuikData['data'].keys.isNotEmpty ? tuikData['data'].keys.first : '';
      if (tuikKey.isNotEmpty) {
        List<double> tuikDataValues =
            List<double>.from(tuikData['data'][tuikKey]);
        for (int i = 0;
            i < tuikDates.length && i < tuikDataValues.length;
            i++) {
          String? yearMonth = _parseDateToYearMonth(tuikDates[i]);
          if (yearMonth != null) {
            tuikMap[yearMonth] = tuikDataValues[i];
          }
        }
      }
    }

    // Web TÜFE tarihlerini kullan (tüm tarihler)
    allDates = webTufeDateList.map((e) => e.value).toList();

    // Her tarih için değerleri hazırla
    for (var entry in webTufeDateList) {
      String yearMonth = entry.key;
      webTufeValues.add(webTufeMap[yearMonth] ?? 0.0);
      // TÜİK verisi varsa ekle, yoksa NaN kullan (gösterilmeyecek)
      double? tuikValue = tuikMap[yearMonth];
      tuikValues.add(tuikValue ?? double.nan);
    }

    if (allDates.isEmpty) {
      return const Center(
        child: Text(
          'Karşılaştırma için uygun veri bulunamadı',
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    // Y ekseni için min/max değerleri hesapla (NaN değerleri hariç)
    List<double> allValues = [
      ...webTufeValues,
      ...tuikValues.where((v) => !v.isNaN)
    ];
    if (allValues.isEmpty) {
      allValues = webTufeValues; // Sadece Web TÜFE verileri kullan
    }
    double minY = allValues.reduce((a, b) => a < b ? a : b);
    double maxY = allValues.reduce((a, b) => a > b ? a : b);

    double margin = (maxY - minY) * 0.1;
    minY = (minY - margin);
    maxY = (maxY + margin);

    // Sıfır çizgisini dahil et
    if (minY > 0) minY = -margin;
    if (maxY < 0) maxY = margin;

    // Y ekseni interval'ını dinamik olarak hesapla
    double yRange = maxY - minY;
    double yInterval;
    if (yRange <= 5) {
      yInterval = 0.5;
    } else if (yRange <= 10) {
      yInterval = 1.0;
    } else if (yRange <= 20) {
      yInterval = 2.0;
    } else if (yRange <= 40) {
      yInterval = 5.0;
    } else if (yRange <= 80) {
      yInterval = 10.0;
    } else {
      yInterval = 20.0;
    }

    // Y ekseni sınırlarını interval'e göre ayarla
    double adjustedMinY = (minY / yInterval).floor() * yInterval;
    double adjustedMaxY = (maxY / yInterval).ceil() * yInterval + yInterval;

    bool hasTuikData = tuikMap.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Aylık Değişim Oranları (%) ${hasTuikData ? "Karşılaştırması" : ""}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade800,
            ),
          ),
          const SizedBox(height: 12),

          // Legend
          if (hasTuikData) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem(
                    'Web TÜFE ${widget.data.gostergeName}', Colors.blue),
                const SizedBox(width: 20),
                _buildLegendItem(
                    'TÜİK ${widget.data.gostergeName}', Colors.red),
              ],
            ),
            const SizedBox(height: 16),
          ],

          SizedBox(
            height: 300,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: yInterval,
                  verticalInterval: 1,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: value == 0 ? Colors.black54 : Colors.grey.shade300,
                      strokeWidth: value == 0 ? 1.5 : 0.5,
                    );
                  },
                  getDrawingVerticalLine: (value) {
                    return const FlLine(
                      color: Colors.grey,
                      strokeWidth: 0.5,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 60,
                      interval: yInterval,
                      getTitlesWidget: (value, meta) {
                        // Interval'e göre format belirle
                        String displayValue;
                        if (yInterval >= 10.0) {
                          displayValue = value.toInt().toString();
                        } else if (yInterval >= 2.0) {
                          displayValue = value.toStringAsFixed(0);
                        } else {
                          displayValue = value.toStringAsFixed(1);
                        }
                        return Text(
                          displayValue,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: (allDates.length / 6).clamp(1, double.infinity),
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index >= 0 && index < allDates.length) {
                          String tarih = allDates[index];
                          List<String> parts = tarih.split('-');
                          if (parts.length >= 2) {
                            String ay = parts[1].padLeft(2, '0');
                            String yil = parts[0].substring(2);
                            return Transform.rotate(
                              angle: -0.5,
                              child: Text(
                                '$ay/$yil',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 10,
                                ),
                              ),
                            );
                          }
                        }
                        return const Text('');
                      },
                    ),
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
                minX: 0,
                maxX: allDates.length.toDouble() - 1,
                minY: adjustedMinY,
                maxY: adjustedMaxY,
                lineBarsData: [
                  // Web TÜFE çizgisi (Mavi)
                  LineChartBarData(
                    spots: webTufeValues.asMap().entries.map((entry) {
                      return FlSpot(entry.key.toDouble(), entry.value);
                    }).toList(),
                    isCurved: false,
                    color: Colors.blue,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 3,
                          color: Colors.blue,
                          strokeWidth: 1,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                  ),

                  // TÜİK çizgisi (Kırmızı) - sadece veri varsa
                  if (hasTuikData)
                    LineChartBarData(
                      spots: tuikValues
                          .asMap()
                          .entries
                          .where((entry) =>
                              !entry.value.isNaN) // NaN değerleri filtrele
                          .map((entry) {
                        return FlSpot(entry.key.toDouble(), entry.value);
                      }).toList(),
                      isCurved: false,
                      color: Colors.red,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 3,
                            color: Colors.red,
                            strokeWidth: 1,
                            strokeColor: Colors.white,
                          );
                        },
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
                        
                        // TÜİK verisi yoksa tooltip gösterme
                        if (touchedSpot.barIndex == 1 && touchedSpot.y.isNaN) {
                          return null;
                        }
                        
                        if (index >= 0 && index < allDates.length) {
                          String date = allDates[index];
                          String source =
                              touchedSpot.barIndex == 0 ? 'Web TÜFE' : 'TÜİK';
                          double value = touchedSpot.y;

                          return LineTooltipItem(
                            '$date\n$source\n${value.toStringAsFixed(2)}%',
                            TextStyle(
                              color: touchedSpot.barIndex == 0
                                  ? Colors.blue
                                  : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }
                        return null;
                      }).where((item) => item != null).cast<LineTooltipItem>().toList();
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

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black87,
          ),
        ),
      ],
    );
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
}
