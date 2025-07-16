import 'package:flutter/material.dart';
import '../models/ozel_gosterge_data.dart';
import '../services/ozel_gostergeler_service.dart';
import '../widgets/ozel_gostergeler_chart.dart';

class OzelGostergelerPage extends StatefulWidget {
  const OzelGostergelerPage({super.key});

  @override
  State<OzelGostergelerPage> createState() => _OzelGostergelerPageState();
}

class _OzelGostergelerPageState extends State<OzelGostergelerPage> {
  List<String> availableIndicators = [];
  String? selectedIndicator;
  OzelGostergeData? indicatorData;

  bool isLoadingIndicators = true;
  bool isLoadingData = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadIndicators();
  }

  Future<void> loadIndicators() async {
    try {
      final indicators = await OzelGostergelerService.getAvailableIndicators();
      setState(() {
        availableIndicators = indicators;
        isLoadingIndicators = false;
        errorMessage = null;
      });
    } catch (e) {
      setState(() {
        isLoadingIndicators = false;
        errorMessage = e.toString();
      });
    }
  }

  Future<void> loadIndicatorData() async {
    if (selectedIndicator == null) return;

    setState(() {
      isLoadingData = true;
      errorMessage = null;
    });

    try {
      final data =
          await OzelGostergelerService.loadIndicatorData(selectedIndicator!);
      setState(() {
        indicatorData = data;
        isLoadingData = false;
        errorMessage = null;
      });
    } catch (e) {
      setState(() {
        isLoadingData = false;
        errorMessage = e.toString();
      });
    }
  }

  String getCurrentDate() {
    final now = DateTime.now();
    final day = now.day.toString().padLeft(2, '0');
    final month = now.month.toString().padLeft(2, '0');
    final year = now.year.toString();
    return '$day.$month.$year';
  }

  Widget buildTopSection() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade50, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Özel Kapsamlı Göstergeler',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.purple.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: isLoadingIndicators
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Göstergeler yükleniyor...'),
                  )
                : DropdownButton<String>(
                    value: selectedIndicator,
                    hint: const Text('Gösterge Seçiniz'),
                    isExpanded: true,
                    underline: const SizedBox(),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    items: availableIndicators.map((String indicator) {
                      return DropdownMenuItem<String>(
                        value: indicator,
                        child: Text(
                          indicator,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          selectedIndicator = newValue;
                          indicatorData = null; // Önceki verileri temizle
                        });
                        loadIndicatorData();
                      }
                    },
                  ),
          ),

          // Veriler yüklendiyse istatistikleri göster
          if (indicatorData != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Yıl Başından Bu Yana',
                    '${indicatorData!.getYearToDateChange().toStringAsFixed(2)}%',
                    Colors.orange.shade600,
                    Icons.trending_up,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Aylık Değişim',
                    '${indicatorData!.getLatestMonthlyChange().toStringAsFixed(2)}%',
                    Colors.green.shade600,
                    Icons.calendar_month,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '01.01.2025-${getCurrentDate()}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ],
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Özel Kapsamlı Göstergeler',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildTopSection(),
            const SizedBox(height: 24),

            // Hata Mesajı
            if (errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        errorMessage!,
                        style: TextStyle(color: Colors.red.shade600),
                      ),
                    ),
                  ],
                ),
              ),

            // Chart Area
            if (isLoadingData)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (indicatorData != null)
              OzelGostergelerChart(data: indicatorData!)
            else if (selectedIndicator == null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Lütfen bir gösterge seçiniz',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
