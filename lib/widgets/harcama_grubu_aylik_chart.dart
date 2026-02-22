import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/harcama_grubu_data.dart';

class HarcamaGrubuAylikChart extends StatelessWidget {
  final List<HarcamaGrubuAylikData> data;
  final String selectedGrup;

  const HarcamaGrubuAylikChart({
    super.key,
    required this.data,
    required this.selectedGrup,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(
        child: Text(
          'Grafik verisi bulunamadı',
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    List<String> allDates = data.map((item) => item.tarih).toList();
    List<double> webTufeValues = data.map((item) => item.degisimOrani).toList();

    List<double> allValues = webTufeValues;
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

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$selectedGrup - Aylık Değişim (%)',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),

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
                        color:
                            value == 0 ? Colors.black54 : Colors.grey.shade300,
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
                        interval:
                            (allDates.length / 6).clamp(1, double.infinity),
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
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(
                      color: Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  minX: 0,
                  maxX: allDates.length.toDouble() - 1,
                  minY: adjustedMinY,
                  maxY: adjustedMaxY,
                  lineBarsData: [
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
                  ],
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipItems: (List<LineBarSpot> touchedSpots) {
                        return touchedSpots.map((LineBarSpot touchedSpot) {
                          final index = touchedSpot.x.toInt();
                          if (index >= 0 && index < allDates.length) {
                            String date = allDates[index];
                            double value = touchedSpot.y;

                            return LineTooltipItem(
                              '$date\nWeb TÜFE\n${value.toStringAsFixed(2)}%',
                              const TextStyle(
                                color: Colors.blue,
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
      ),
    );
  }
}
