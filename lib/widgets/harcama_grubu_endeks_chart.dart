import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/harcama_grubu_data.dart';
import '../services/tuik_service.dart';

class HarcamaGrubuEndeksChart extends StatefulWidget {
  final List<HarcamaGrubuEndeksData> data;
  final String selectedGrup;

  const HarcamaGrubuEndeksChart({
    super.key,
    required this.data,
    required this.selectedGrup,
  });

  @override
  State<HarcamaGrubuEndeksChart> createState() =>
      _HarcamaGrubuEndeksChartState();
}

class _HarcamaGrubuEndeksChartState extends State<HarcamaGrubuEndeksChart> {
  // Karşılaştırmalı endeks verisi
  Future<Map<String, List<FlSpot>>>
      getComparedHarcamaGrubuIndexChartData() async {
    try {
      print(
          'Harcama grubu karşılaştırmalı chart data yükleniyor: ${widget.selectedGrup}');
      print('Web TÜFE harcama grubu veri sayısı: ${widget.data.length}');
      if (widget.data.isNotEmpty) {
        print('İlk Web TÜFE tarihi: ${widget.data.first.tarih}');
        print('Son Web TÜFE tarihi: ${widget.data.last.tarih}');
      }

      // TÜİK harcama grubu endeks verilerini al
      final tuikData =
          await TuikService.loadTuikHarcamaGrubuEndeksData(widget.selectedGrup);

      print('TÜİK verisi geldi: ${tuikData.toString()}');

      Map<String, List<FlSpot>> result = {};

      // Web TÜFE harcama grubu verisi (günlük)
      if (widget.data.isNotEmpty) {
        result['Web TÜFE'] = widget.data.asMap().entries.map((entry) {
          return FlSpot(entry.key.toDouble(), entry.value.endeks);
        }).toList();
      }

      // TÜİK harcama grubu verisi (aylık) - tarihleri eşleştir ve step plot için hazırla
      if (tuikData['data']['TÜİK ${widget.selectedGrup}'] != null) {
        final tuikValues =
            tuikData['data']['TÜİK ${widget.selectedGrup}'] as List<double>;
        final tuikDates = tuikData['dates'] as List<String>;

        List<FlSpot> tuikSpots = [];

        // TÜİK verilerini Web TÜFE tarihlerinin ayın son günlerine eşleştir
        print(
            'TÜİK tarih eşleştirmesi başlıyor. TÜİK veri sayısı: ${tuikDates.length}');
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
                  'TÜİK tarih eşleştiriliyor: $tuikDate (${tuikMonth}.${tuikYear}) = $tuikValue');

              // Web TÜFE tarihlerinde bu ayın son gününü bul
              int lastDayIndex = -1;
              for (int webIndex = widget.data.length - 1;
                  webIndex >= 0;
                  webIndex--) {
                String webDate =
                    widget.data[webIndex].tarih; // Format: yyyy-mm-dd
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
                print('TÜİK spot eklendi: ($lastDayIndex, $tuikValue)');
              } else {
                print(
                    'Bu ay için Web TÜFE verisi bulunamadı: ${tuikMonth}.${tuikYear}');
              }
            }
          } catch (e) {
            print('Harcama grubu endeks tarih eşleştirme hatası: $e');
          }
        }

        // TÜİK spots'ları x değerine göre sırala
        tuikSpots.sort((a, b) => a.x.compareTo(b.x));

        print('Toplam TÜİK spot sayısı: ${tuikSpots.length}');
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
            for (double x = lastX + 1; x < widget.data.length; x++) {
              stepSpots.add(FlSpot(x, lastY));
            }
          }
        }

        result['TÜİK TÜFE'] = stepSpots;
        print('Step plot spots sayısı: ${stepSpots.length}');
      }

      print('Final result: ${result.keys.toList()}');
      return result;
    } catch (e) {
      print('Karşılaştırmalı harcama grubu endeks veri yükleme hatası: $e');
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return const Center(
        child: Text(
          'Grafik verisi bulunamadı',
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.selectedGrup} - Endeks Değerleri (Karşılaştırmalı)',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 350,
              child: FutureBuilder<Map<String, List<FlSpot>>>(
                future: getComparedHarcamaGrubuIndexChartData(),
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

                  // Web TÜFE harcama grubu çizgisi (mavi)
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

                  // TÜİK TÜFE harcama grubu çizgisi (kırmızı) - Step plot
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
                            Text('Web TÜFE ${widget.selectedGrup}',
                                style: const TextStyle(fontSize: 12)),
                            const SizedBox(width: 20),
                            Container(
                              width: 16,
                              height: 3,
                              color: Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Text('TÜİK ${widget.selectedGrup}',
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
                                        ? 'Web TÜFE ${widget.selectedGrup}'
                                        : 'TÜİK ${widget.selectedGrup}';
                                    final index = touchedSpot.x.toInt();

                                    // Tarih bilgisini al
                                    String dateInfo = '';
                                    if (index >= 0 &&
                                        index < widget.data.length) {
                                      dateInfo =
                                          '${widget.data[index].tarih}\n';
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
      ),
    );
  }
}
