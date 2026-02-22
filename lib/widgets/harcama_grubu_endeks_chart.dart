import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/harcama_grubu_data.dart';

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
  List<FlSpot> getChartData() {
    return widget.data.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.endeks);
    }).toList();
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
              '${widget.selectedGrup} - Endeks Değerleri',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 350,
              child: Builder(
                builder: (context) {
                  final spots = getChartData();
                  if (spots.isEmpty) {
                    return const Center(child: Text('Endeks veri bulunamadı'));
                  }

                  List<LineChartBarData> lineBarsData = [
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
                  ];

                  double minY = double.infinity;
                  double maxY = double.negativeInfinity;
                  for (var spot in spots) {
                    if (spot.y < minY) minY = spot.y;
                    if (spot.y > maxY) maxY = spot.y;
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

                  return Column(
                    children: [
                      Expanded(
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
                                    final index = touchedSpot.x.toInt();
                                    String dateInfo = '';
                                    if (index >= 0 &&
                                        index < widget.data.length) {
                                      dateInfo =
                                          '${widget.data[index].tarih}\n';
                                    }

                                    return LineTooltipItem(
                                      '${dateInfo}Web TÜFE ${widget.selectedGrup}\n${touchedSpot.y.toStringAsFixed(2)}',
                                      const TextStyle(
                                        color: Colors.blue,
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
