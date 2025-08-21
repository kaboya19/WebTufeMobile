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
    
    // Bar genişliğini hesapla (ekranın %30'u maksimum - her iki yön için)
    double barWidthRatio = maxAbsValue > 0 ? (tufeData.changeRate.abs() / maxAbsValue) * 0.3 : 0.0;
    double screenWidth = MediaQuery.of(context).size.width - 32; // padding dahil
    
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
          // Grafik alanı (orta) - harcama grupları gibi Stack kullan
          Expanded(
            flex: 5,
            child: SizedBox(
              height: 30,
              child: Stack(
                children: [
                  // Orta çizgi (sıfır referansı)
                  Positioned(
                    left: screenWidth * 0.5 / 1.6 - 1, // Grafik alanının ortası
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 2,
                      color: Colors.grey.shade400,
                    ),
                  ),
                  // Bar
                  if (tufeData.changeRate != 0)
                    Positioned(
                      left: tufeData.changeRate >= 0
                          ? screenWidth * 0.5 / 1.6 // Pozitif: orta noktadan başla
                          : screenWidth * 0.5 / 1.6 - (screenWidth * 0.5 / 1.6 * barWidthRatio), // Negatif: orta noktadan sola
                      top: 2,
                      child: Container(
                        height: 26,
                        width: screenWidth * 0.5 / 1.6 * barWidthRatio,
                        decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  // Değer etiketi
                  Positioned(
                    left: tufeData.changeRate >= 0
                        ? screenWidth * 0.5 / 1.6 + (screenWidth * 0.5 / 1.6 * barWidthRatio) + 4 // Pozitif: barın sağında
                        : screenWidth * 0.5 / 1.6 - (screenWidth * 0.5 / 1.6 * barWidthRatio) - 50, // Negatif: barın solunda
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Text(
                        tufeData.formattedChangeRate,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
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
