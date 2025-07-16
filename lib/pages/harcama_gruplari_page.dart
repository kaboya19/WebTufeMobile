import 'package:flutter/material.dart';
import '../models/harcama_grubu_data.dart';
import '../services/harcama_gruplari_service.dart';
import '../widgets/harcama_gruplari_chart.dart';
import '../widgets/harcama_grubu_endeks_chart.dart';
import '../widgets/harcama_grubu_aylik_chart.dart';

class HarcamaGruplariPage extends StatefulWidget {
  const HarcamaGruplariPage({super.key});

  @override
  State<HarcamaGruplariPage> createState() => _HarcamaGruplariPageState();
}

class _HarcamaGruplariPageState extends State<HarcamaGruplariPage> {
  List<AnaGrupData> anaGruplar = [];
  List<String> availableDates = [];
  List<HarcamaGrubuData> harcamaGrubuData = [];
  List<String> harcamaGruplari = [];

  String? selectedAnaGrup;
  String? selectedDate;
  String? selectedHarcamaGrubu;

  // Yeni veriler için
  List<HarcamaGrubuEndeksData> endeksData = [];
  List<HarcamaGrubuAylikData> aylikData = [];
  HarcamaGrubuIstatistik? istatistik;

  bool isLoadingAnaGruplar = true;
  bool isLoadingDates = true;
  bool isLoadingData = false;
  bool isLoadingHarcamaGruplari = false;
  bool isLoadingDetayData = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadInitialData();
  }

  Future<void> loadInitialData() async {
    try {
      final anaGruplarResult = await HarcamaGruplariService.loadAnaGruplar();
      final datesResult = await HarcamaGruplariService.getAvailableDates();

      setState(() {
        anaGruplar = anaGruplarResult;
        availableDates = datesResult;
        isLoadingAnaGruplar = false;
        isLoadingDates = false;
        errorMessage = null;

        // İlk ana grubu ve son tarihi varsayılan olarak seç
        if (anaGruplar.isNotEmpty) {
          selectedAnaGrup = anaGruplar.first.name;
        }
        if (availableDates.isNotEmpty) {
          selectedDate = availableDates.last;
        }
      });

      // İlk veriyi yükle
      if (selectedAnaGrup != null && selectedDate != null) {
        await loadHarcamaGrubuData();
        await loadHarcamaGruplariList();
      }
    } catch (e) {
      setState(() {
        isLoadingAnaGruplar = false;
        isLoadingDates = false;
        errorMessage = e.toString();
      });
    }
  }

  Future<void> loadHarcamaGrubuData() async {
    if (selectedAnaGrup == null || selectedDate == null) return;

    setState(() {
      isLoadingData = true;
      errorMessage = null;
    });

    try {
      // Önce harcama gruplarını al
      final harcamaGruplariList =
          await HarcamaGruplariService.loadHarcamaGruplari(selectedAnaGrup!);

      // Sonra değişim oranlarını al
      final data =
          await HarcamaGruplariService.loadHarcamaGrubuDegiisimOranlari(
              harcamaGruplariList, selectedDate!);

      setState(() {
        harcamaGrubuData = data;
        isLoadingData = false;
      });
    } catch (e) {
      setState(() {
        isLoadingData = false;
        errorMessage = e.toString();
      });
    }
  }

  Future<void> loadHarcamaGruplariList() async {
    if (selectedAnaGrup == null) return;

    setState(() {
      isLoadingHarcamaGruplari = true;
    });

    try {
      final gruplar =
          await HarcamaGruplariService.loadHarcamaGruplari(selectedAnaGrup!);
      setState(() {
        harcamaGruplari = gruplar;
        isLoadingHarcamaGruplari = false;
        selectedHarcamaGrubu = null; // Reset selection
        // Detay verilerini temizle
        endeksData = [];
        aylikData = [];
        istatistik = null;
      });
    } catch (e) {
      setState(() {
        isLoadingHarcamaGruplari = false;
        errorMessage = e.toString();
      });
    }
  }

  Future<void> loadHarcamaGrubuDetayData() async {
    if (selectedHarcamaGrubu == null) return;

    setState(() {
      isLoadingDetayData = true;
      errorMessage = null;
    });

    try {
      // Endeks, aylık ve istatistik verilerini paralel olarak yükle
      final futures = await Future.wait([
        HarcamaGruplariService.loadHarcamaGrubuEndeksData(
            selectedHarcamaGrubu!),
        HarcamaGruplariService.loadHarcamaGrubuAylikData(selectedHarcamaGrubu!),
        HarcamaGruplariService.calculateHarcamaGrubuStatistics(
            selectedHarcamaGrubu!),
      ]);

      setState(() {
        endeksData = futures[0] as List<HarcamaGrubuEndeksData>;
        aylikData = futures[1] as List<HarcamaGrubuAylikData>;
        istatistik = futures[2] as HarcamaGrubuIstatistik;
        isLoadingDetayData = false;
      });
    } catch (e) {
      setState(() {
        isLoadingDetayData = false;
        errorMessage = e.toString();
      });
    }
  }

  Widget _buildIstatistikCard() {
    if (istatistik == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              selectedHarcamaGrubu ?? '',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Yılbaşından Bu Yana',
                    '${istatistik!.yillikDegisim.toStringAsFixed(2)}%',
                    istatistik!.yillikDegisim >= 0 ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Son Aylık Değişim',
                    '${istatistik!.aylikDegisim.toStringAsFixed(2)}%',
                    istatistik!.aylikDegisim >= 0 ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
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
          'Harcama Grupları',
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
            // Ana Grup Seçimi
            const Text(
              'Ana Grup Seçiniz:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
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
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
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
                        onChanged: (String? newValue) async {
                          setState(() {
                            selectedAnaGrup = newValue;
                            selectedHarcamaGrubu = null;
                            // Detay verilerini temizle
                            endeksData = [];
                            aylikData = [];
                            istatistik = null;
                          });
                          await loadHarcamaGrubuData();
                          await loadHarcamaGruplariList();
                        },
                      ),
                    ),
            ),

            const SizedBox(height: 24),

            // Tarih Seçimi (sadece bar chart için)
            if (selectedHarcamaGrubu == null) ...[
              const Text(
                'Tarih Seçiniz:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
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
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator()),
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
                            loadHarcamaGrubuData();
                          },
                        ),
                      ),
              ),
              const SizedBox(height: 24),
            ],

            // Harcama Grubu Seçimi
            if (harcamaGruplari.isNotEmpty) ...[
              const Text(
                'Harcama Grubu Seçiniz (isteğe bağlı):',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
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
                child: isLoadingHarcamaGruplari
                    ? const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedHarcamaGrubu,
                          hint: const Text(
                              'Harcama grubu seçiniz (detaylı analiz için)'),
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text(
                                  'Seçim yapılmadı (tüm grupların karşılaştırması)'),
                            ),
                            ...harcamaGruplari.map((grup) {
                              return DropdownMenuItem<String>(
                                value: grup,
                                child: Text(grup),
                              );
                            }).toList(),
                          ],
                          onChanged: (String? newValue) async {
                            setState(() {
                              selectedHarcamaGrubu = newValue;
                            });
                            if (newValue != null) {
                              await loadHarcamaGrubuDetayData();
                            } else {
                              setState(() {
                                endeksData = [];
                                aylikData = [];
                                istatistik = null;
                              });
                            }
                          },
                        ),
                      ),
              ),
              const SizedBox(height: 24),
            ],

            // Sonuçlar
            Expanded(
              child: selectedHarcamaGrubu == null
                  ? _buildBarChartView()
                  : _buildDetailedView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChartView() {
    return isLoadingData
        ? const Center(child: CircularProgressIndicator())
        : errorMessage != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Hata: $errorMessage',
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: loadHarcamaGrubuData,
                      child: const Text('Tekrar Dene'),
                    ),
                  ],
                ),
              )
            : harcamaGrubuData.isEmpty
                ? const Center(
                    child: Text(
                      'Seçilen kriterlere uygun veri bulunamadı',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    child: HarcamaGruplariChart(data: harcamaGrubuData),
                  );
  }

  Widget _buildDetailedView() {
    return isLoadingDetayData
        ? const Center(child: CircularProgressIndicator())
        : errorMessage != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Hata: $errorMessage',
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: loadHarcamaGrubuDetayData,
                      child: const Text('Tekrar Dene'),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  children: [
                    _buildIstatistikCard(),
                    if (endeksData.isNotEmpty)
                      HarcamaGrubuEndeksChart(
                        data: endeksData,
                        selectedGrup: selectedHarcamaGrubu!,
                      ),
                    if (aylikData.isNotEmpty)
                      HarcamaGrubuAylikChart(
                        data: aylikData,
                        selectedGrup: selectedHarcamaGrubu!,
                      ),
                  ],
                ),
              );
  }
}
