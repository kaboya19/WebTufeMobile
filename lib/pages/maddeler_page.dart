import 'package:flutter/material.dart';
import '../models/madde_data.dart';
import '../models/harcama_grubu_data.dart';
import '../services/maddeler_service.dart';
import '../widgets/maddeler_chart.dart';

class MaddelerPage extends StatefulWidget {
  const MaddelerPage({super.key});

  @override
  State<MaddelerPage> createState() => _MaddelerPageState();
}

class _MaddelerPageState extends State<MaddelerPage> {
  List<AnaGrupData> anaGruplar = [];
  List<String> availableDates = [];
  List<MaddeData> maddeData = [];

  String? selectedAnaGrup;
  String? selectedDate;

  bool isLoadingAnaGruplar = true;
  bool isLoadingDates = true;
  bool isLoadingData = false;

  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadInitialData();
  }

  Future<void> loadInitialData() async {
    await Future.wait([
      loadAnaGruplar(),
      loadAvailableDates(),
    ]);
  }

  Future<void> loadAnaGruplar() async {
    try {
      final gruplar = await MaddelerService.loadAnaGruplar();
      setState(() {
        anaGruplar = gruplar;
        isLoadingAnaGruplar = false;
        errorMessage = null;
      });
    } catch (e) {
      setState(() {
        isLoadingAnaGruplar = false;
        errorMessage = e.toString();
      });
    }
  }

  Future<void> loadAvailableDates() async {
    try {
      final dates = await MaddelerService.getAvailableDates();
      setState(() {
        availableDates = dates;
        isLoadingDates = false;
        if (dates.isNotEmpty) {
          selectedDate = dates.first; // En yeni tarihi seç
        }
        errorMessage = null;
      });
    } catch (e) {
      setState(() {
        isLoadingDates = false;
        errorMessage = e.toString();
      });
    }
  }

  Future<void> loadMaddeData() async {
    if (selectedAnaGrup == null || selectedDate == null) return;

    setState(() {
      isLoadingData = true;
      errorMessage = null;
    });

    try {
      // Önce maddeleri yükle
      final maddeler = await MaddelerService.loadMaddeler(selectedAnaGrup!);

      if (maddeler.isEmpty) {
        setState(() {
          maddeData = [];
          isLoadingData = false;
          errorMessage = 'Seçilen ana gruba ait madde bulunamadı';
        });
        return;
      }

      // Sonra değişim oranlarını yükle
      final data = await MaddelerService.loadMaddeDegiisimOranlari(
          maddeler, selectedDate!);

      setState(() {
        maddeData = data;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Maddeler',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ana Grup Dropdown
            const Text(
              'Ana Grup Seçiniz:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: isLoadingAnaGruplar
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Ana gruplar yükleniyor...'),
                    )
                  : DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedAnaGrup,
                        hint: const Text('Ana grup seçiniz'),
                        isExpanded: true,
                        items: anaGruplar.map((anaGrup) {
                          return DropdownMenuItem<String>(
                            value: anaGrup.name,
                            child: Text(anaGrup.name),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            selectedAnaGrup = newValue;
                            maddeData = []; // Önceki verileri temizle
                          });
                          if (newValue != null) {
                            loadMaddeData();
                          }
                        },
                      ),
                    ),
            ),
            const SizedBox(height: 16),

            // Tarih Dropdown
            const Text(
              'Tarih Seçiniz:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: isLoadingDates
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Tarihler yükleniyor...'),
                    )
                  : DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedDate,
                        hint: const Text('Tarih seçiniz'),
                        isExpanded: true,
                        items: availableDates.map((date) {
                          return DropdownMenuItem<String>(
                            value: date,
                            child: Text(date),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            selectedDate = newValue;
                          });
                          if (newValue != null && selectedAnaGrup != null) {
                            loadMaddeData();
                          }
                        },
                      ),
                    ),
            ),
            const SizedBox(height: 24),

            // Hata Mesajı
            if (errorMessage != null)
              Container(
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
            Expanded(
              child: isLoadingData
                  ? const Center(child: CircularProgressIndicator())
                  : maddeData.isEmpty
                      ? const Center(
                          child: Text(
                            'Ana grup ve tarih seçerek maddeleri görüntüleyebilirsiniz',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : SingleChildScrollView(
                          child: MaddelerChart(data: maddeData),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
