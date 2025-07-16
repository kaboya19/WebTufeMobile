import 'package:flutter/material.dart';
import '../models/tufe_data.dart';

class TufeChart extends StatelessWidget {
  final List<TufeData> data;

  const TufeChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(
        child: Text('Veri bulunamadı'),
      );
    }

    return Column(
      children: data.map((tufeData) => _buildBar(tufeData, context)).toList(),
    );
  }

  Widget _buildBar(TufeData tufeData, BuildContext context) {
    final maxValue = data.first.changeRate;
    final barWidth =
        maxValue > 0 ? (tufeData.changeRate / maxValue) * 0.8 : 0.0;

    // Bar genişliği hesaplama (piksel cinsinden)
    final barWidthPx =
        (MediaQuery.of(context).size.width * 0.5 * barWidth).toDouble();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2.0),
      height: 40,
      child: Row(
        children: [
          // Grup adı (sol taraf)
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.only(right: 8.0),
              child: Text(
                tufeData.displayName,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ),
          // Grafik alanı (orta) - Bar ve text yan yana
          Expanded(
            flex: 5,
            child: Container(
              height: 30,
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  // Bar (çubuk)
                  Container(
                    width: barWidthPx,
                    height: 25,
                    decoration: BoxDecoration(
                      color: tufeData.isWebTufe ? Colors.red : Colors.blue,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(2),
                        bottomRight: Radius.circular(2),
                      ),
                    ),
                  ),
                  // Yüzde değeri - barın hemen yanında
                  const SizedBox(width: 5),
                  Text(
                    tufeData.formattedChangeRate,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
