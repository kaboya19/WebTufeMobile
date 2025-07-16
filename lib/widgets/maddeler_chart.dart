import 'package:flutter/material.dart';
import '../models/madde_data.dart';

class MaddelerChart extends StatelessWidget {
  final List<MaddeData> data;

  const MaddelerChart({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(
        child: Text(
          'Veri bulunamadı',
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    // En büyük ve en küçük değerleri bul
    double maxValue =
        data.map((e) => e.changeRate.abs()).reduce((a, b) => a > b ? a : b);
    if (maxValue == 0) maxValue = 1; // Sıfıra bölmeyi önle

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Maddeler Değişim Oranları (%)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          ...data
              .map((item) => _buildBarItem(item, maxValue, context))
              .toList(),
        ],
      ),
    );
  }

  Widget _buildBarItem(MaddeData item, double maxValue, BuildContext context) {
    // Bar genişliğini hesapla (ekranın %30'u maksimum - her iki yön için)
    double barWidthRatio = (item.changeRate.abs() / maxValue) * 0.3;
    double screenWidth =
        MediaQuery.of(context).size.width - 32; // padding dahil

    // Renk seçimi
    Color barColor;
    if (item.changeRate > 0) {
      barColor = Colors.green.shade400;
    } else if (item.changeRate < 0) {
      barColor = Colors.red.shade400;
    } else {
      barColor = Colors.grey.shade400;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          // Madde adı - ortalanmış
          Text(
            item.maddeName,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          // Bar container - orta noktalı
          SizedBox(
            height: 24,
            width: screenWidth,
            child: Stack(
              children: [
                // Orta çizgi
                Positioned(
                  left: screenWidth / 2 - 1,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 2,
                    color: Colors.grey.shade300,
                  ),
                ),
                // Bar
                if (item.changeRate != 0)
                  Positioned(
                    left: item.changeRate >= 0
                        ? screenWidth / 2 // Pozitif: orta noktadan başla
                        : screenWidth / 2 -
                            (screenWidth *
                                barWidthRatio), // Negatif: orta noktadan sola
                    top: 2,
                    child: Container(
                      height: 20,
                      width: screenWidth * barWidthRatio,
                      decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                // Değer etiketi
                Positioned(
                  left: item.changeRate >= 0
                      ? screenWidth / 2 +
                          (screenWidth * barWidthRatio) +
                          4 // Pozitif: barın sağında
                      : screenWidth / 2 -
                          (screenWidth * barWidthRatio) -
                          40, // Negatif: barın solunda
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Text(
                      '${item.changeRate.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: barColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
