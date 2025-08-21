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
    // Tüm değerlerden maksimum mutlak değeri bul
    final maxAbsValue = data.map((e) => e.changeRate.abs())
        .reduce((a, b) => a > b ? a : b);
    
    // Bar genişliği flex oranı olarak hesapla
    final barFlexRatio = maxAbsValue > 0 ? (tufeData.changeRate.abs() / maxAbsValue) : 0.0;
    
    // Pozitif/negatif durumuna göre renk
    Color barColor;
    if (tufeData.changeRate > 0) {
      barColor = tufeData.isWebTufe ? Colors.red : Colors.blue;
    } else if (tufeData.changeRate < 0) {
      barColor = tufeData.isWebTufe ? Colors.red.shade300 : Colors.blue.shade300;
    } else {
      barColor = Colors.grey.shade400;
    }
    
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
          // Grafik alanı (orta)
          Expanded(
            flex: 5,
            child: Container(
              height: 30,
              child: Row(
                children: [
                  // Sol taraf - negatif barlar için alan (flex: 2)
                  Expanded(
                    flex: 2,
                    child: Container(
                      height: 30,
                      alignment: Alignment.centerRight,
                      child: tufeData.changeRate < 0 
                          ? FractionallySizedBox(
                              widthFactor: barFlexRatio,
                              child: Container(
                                height: 25,
                                decoration: BoxDecoration(
                                  color: barColor,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(2),
                                    bottomLeft: Radius.circular(2),
                                  ),
                                ),
                              ),
                            )
                          : Container(),
                    ),
                  ),
                  // Sıfır çizgisi (referans noktası)
                  Container(
                    width: 2,
                    height: 30,
                    color: Colors.grey.shade400,
                  ),
                  // Sağ taraf - pozitif barlar için alan (flex: 2)
                  Expanded(
                    flex: 2,
                    child: Container(
                      height: 30,
                      alignment: Alignment.centerLeft,
                      child: tufeData.changeRate > 0 
                          ? FractionallySizedBox(
                              widthFactor: barFlexRatio,
                              child: Container(
                                height: 25,
                                decoration: BoxDecoration(
                                  color: barColor,
                                  borderRadius: const BorderRadius.only(
                                    topRight: Radius.circular(2),
                                    bottomRight: Radius.circular(2),
                                  ),
                                ),
                              ),
                            )
                          : Container(),
                    ),
                  ),
                  // Text alanı - tüm textler aynı konumda başlayacak
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 60,
                    child: Text(
                      tufeData.formattedChangeRate,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.left,
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
