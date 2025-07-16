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
  bool isLoadingTuik = true;

  @override
  void initState() {
    super.initState();
    _loadTuikData();
  }

  @override
  void didUpdateWidget(OzelGostergelerChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.gostergeName != widget.data.gostergeName) {
      _loadTuikData();
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

    final spots = widget.data.dailyValues.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value);
    }).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Endeks Değerleri (Günlük)',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade800,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 300,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 60,
                      interval: 10, // 10'ar 10'ar göster
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
                    color: Colors.blue,
                    barWidth: 2,
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
                    getTooltipItems: (List<LineBarSpot> touchedSpots) {
                      return touchedSpots.map((LineBarSpot touchedSpot) {
                        final index = touchedSpot.x.toInt();
                        if (index >= 0 && index < widget.data.dates.length) {
                          return LineTooltipItem(
                            '${widget.data.dates[index]}\n${touchedSpot.y.toStringAsFixed(2)}',
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

    // Web TÜFE verilerini al
    Map<String, double> webTufeMap = {};
    for (int i = 0;
        i < widget.data.monthlyDates.length &&
            i < widget.data.monthlyChanges.length;
        i++) {
      webTufeMap[widget.data.monthlyDates[i]] = widget.data.monthlyChanges[i];
    }

    // TÜİK verilerini al
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
          tuikMap[tuikDates[i]] = tuikDataValues[i];
        }
      }
    }

    // Ortak tarih listesi oluştur (daha uzun olanı kullan)
    Set<String> allDatesSet = {...webTufeMap.keys, ...tuikMap.keys};
    allDates = allDatesSet.toList()..sort();

    // Her tarih için değerleri hazırla
    for (String date in allDates) {
      webTufeValues.add(webTufeMap[date] ?? 0.0);
      tuikValues.add(tuikMap[date] ?? double.nan); // Eksik veri için NaN kullan
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
    if (yRange <= 10) {
      yInterval = 2.0;
    } else if (yRange <= 30) {
      yInterval = 5.0;
    } else if (yRange <= 60) {
      yInterval = 10.0;
    } else if (yRange <= 100) {
      yInterval = 15.0;
    } else {
      yInterval = 20.0;
    }

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
                        // Büyük interval'larda tam sayı, küçüklerde ondalık göster
                        String displayValue = yInterval >= 5.0
                            ? value.toInt().toString()
                            : value.toStringAsFixed(1);
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
                minY: minY,
                maxY: maxY,
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
                    getTooltipItems: (List<LineBarSpot> touchedSpots) {
                      return touchedSpots.map((LineBarSpot touchedSpot) {
                        final index = touchedSpot.x.toInt();
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
}
