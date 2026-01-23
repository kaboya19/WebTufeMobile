import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/tufe_data.dart';
import 'services/csv_service.dart';
import 'services/github_csv_service.dart';
import 'widgets/tufe_chart.dart';
import 'pages/tufe_page.dart';
import 'pages/ana_gruplar_page.dart';
import 'pages/harcama_gruplari_page.dart';
import 'pages/maddeler_page.dart';
import 'pages/ozel_gostergeler_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Uygulama başlangıcında versiyon kontrolü yap ve cache'i temizle
  await _checkAndClearCacheOnVersionChange();
  
  runApp(const MyApp());
}

/// Versiyon değişikliğini kontrol eder ve gerekirse cache'i temizler
Future<void> _checkAndClearCacheOnVersionChange() async {
  try {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
    
    final prefs = await SharedPreferences.getInstance();
    final lastVersion = prefs.getString('last_app_version');
    
    // Versiyon değiştiyse veya ilk açılışsa cache'i temizle
    if (lastVersion != currentVersion) {
      print('Versiyon değişti: $lastVersion -> $currentVersion');
      print('Cache temizleniyor...');
      GitHubCSVService.clearCache();
      
      // Yeni versiyonu kaydet
      await prefs.setString('last_app_version', currentVersion);
      print('Cache temizlendi ve yeni versiyon kaydedildi: $currentVersion');
    } else {
      print('Versiyon aynı: $currentVersion, cache temizlenmedi');
    }
  } catch (e) {
    print('Versiyon kontrolü hatası: $e');
    // Hata durumunda da cache'i temizle (güvenli tarafta olmak için)
    GitHubCSVService.clearCache();
  }
}

// Bakım modu - true olduğunda sadece bakım ekranı gösterilir
const bool _maintenanceMode = false;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Web TÜFE Mobile',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Roboto',
      ),
      home: _maintenanceMode ? const MaintenancePage() : const MainPage(),
    );
  }
}

class MaintenancePage extends StatelessWidget {
  const MaintenancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.construction,
                size: 80,
                color: Colors.blue.shade700,
              ),
              const SizedBox(height: 32),
              Text(
                'Nihai veriler hazırlanıyor. Sabrınız için teşekkürler...',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade800,
                  fontFamily: 'Roboto',
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const TufeHomePage(),
    const TufePage(),
    const AnaGruplarPage(),
    const HarcamaGruplariPage(),
    const MaddelerPage(),
    const OzelGostergelerPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Ana Sayfa',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.trending_up),
            label: 'TÜFE',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Ana Gruplar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Harcama Grupları',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory),
            label: 'Maddeler',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.insights),
            label: 'Özel Göstergeler',
          ),
        ],
      ),
    );
  }
}

class TufeHomePage extends StatefulWidget {
  const TufeHomePage({super.key});

  @override
  State<TufeHomePage> createState() => _TufeHomePageState();
}

class _TufeHomePageState extends State<TufeHomePage> {
  List<TufeData> tufeDataList = [];
  bool isLoading = true;
  String? errorMessage;
  String currentMonth = '';
  bool isDataOutdated = false;
  String? lastDataDate;
  String? displayedDataDate;
  List<String> availableDates = [];
  String? selectedDate;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      // Önce tarih listesini yükle
      final dates = await CSVService.getAvailableDates();
      String? initialDate;
      if (dates.isNotEmpty) {
        initialDate = dates.last; // En son tarih
      }
      
      setState(() {
        availableDates = dates;
        selectedDate = initialDate;
      });
      
      // Verileri yükle
      await loadCSVData();
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = e.toString();
      });
    }
  }

  Future<void> loadCSVData() async {
    try {
      List<TufeData> data;
      String month;
      
      if (selectedDate != null) {
        // Seçili tarih için veri yükle
        data = await CSVService.loadTufeDataForDate(selectedDate!);
        month = CSVService.getMonthFromDate(selectedDate!);
      } else {
        // Son tarih için veri yükle
        data = await CSVService.loadTufeData();
        month = await CSVService.getMonthFromCSV();
      }
      
      final dataFreshness = await _checkDataFreshness();
      
      setState(() {
        tufeDataList = data;
        currentMonth = month;
        isDataOutdated = dataFreshness['isOutdated'];
        lastDataDate = dataFreshness['lastDate'];
        displayedDataDate = dataFreshness['displayedDate'];
        isLoading = false;
        errorMessage = null;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = e.toString();
        currentMonth = CSVService.getCurrentMonth(); // Fallback
      });
    }
  }

  Future<Map<String, dynamic>> _checkDataFreshness() async {
    try {
      // Günlük TÜFE verilerinden en son tarihi al
      final String csvData = await GitHubCSVService.loadCSVFromGitHub(
          'tufe.csv', useCache: false);
      
      List<String> lines = csvData.split(RegExp(r'\r?\n'));
      if (lines.length < 2) {
        return {'isOutdated': false, 'lastDate': null, 'displayedDate': null};
      }

      // Son satırdan tarihi al (CSV'deki en son veri tarihi)
      String lastLine = lines[lines.length - 1].trim();
      if (lastLine.isEmpty && lines.length > 2) {
        lastLine = lines[lines.length - 2].trim();
      }

      if (lastLine.isNotEmpty) {
        List<String> parts = lastLine.split(',');
        if (parts.isNotEmpty) {
          String csvLastDateStr = parts[0].trim();
          
          try {
            DateTime csvLastDate = DateTime.parse(csvLastDateStr);
            
            // Ekranda gösterilen veri tarihini al (aylık CSV'den)
            final String monthlyData = await GitHubCSVService.loadCSVFromGitHub(
                'gruplaraylik.csv', useCache: false);
            List<String> monthlyLines = monthlyData.split(RegExp(r'\r?\n'));
            
            DateTime? displayedDataDate;
            if (monthlyLines.isNotEmpty) {
              // Header satırından son sütun tarihini al
              List<String> headerParts = monthlyLines[0].split(',');
              if (headerParts.isNotEmpty) {
                String displayedDateStr = headerParts.last.trim();
                try {
                  displayedDataDate = DateTime.parse(displayedDateStr);
                } catch (e) {
                  print('Ekran tarihi parse hatası: $e');
                }
              }
            }
            
            // Karşılaştırma: ekranda gösterilen tarih ile CSV'deki son tarih
            bool isOutdated = false;
            int daysDifference = 0;
            
            if (displayedDataDate != null) {
              daysDifference = csvLastDate.difference(displayedDataDate).inDays;
              // 1 gün bile eksikse uyarı ver
              isOutdated = daysDifference >= 1;
            }
            
            // Tarihleri Türkçe formata çevir
            String csvFormattedDate = '${csvLastDate.day.toString().padLeft(2, '0')}.${csvLastDate.month.toString().padLeft(2, '0')}.${csvLastDate.year}';
            String? displayedFormattedDate;
            if (displayedDataDate != null) {
              displayedFormattedDate = '${displayedDataDate.day.toString().padLeft(2, '0')}.${displayedDataDate.month.toString().padLeft(2, '0')}.${displayedDataDate.year}';
            }
            
            return {
              'isOutdated': isOutdated,
              'lastDate': csvFormattedDate,
              'displayedDate': displayedFormattedDate,
              'daysDifference': daysDifference
            };
          } catch (e) {
            print('Tarih parse hatası: $e');
          }
        }
      }
      
      return {'isOutdated': false, 'lastDate': null, 'displayedDate': null};
    } catch (e) {
      print('Veri güncellik kontrolü hatası: $e');
      return {'isOutdated': false, 'lastDate': null, 'displayedDate': null};
    }
  }

  void _clearCache() {
    GitHubCSVService.clearCache();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cache temizlendi')),
    );
  }

  void _refreshData() async {
    GitHubCSVService.clearCache();
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    await loadCSVData();
    
    // Refresh successful feedback
    if (mounted) {
      String message = 'Veriler yenilendi';
      if (isDataOutdated && lastDataDate != null && displayedDataDate != null) {
        message = 'Veriler yenilendi\nEkran: $displayedDataDate | Güncel: $lastDataDate';
      } else if (isDataOutdated && lastDataDate != null) {
        message = 'Veriler yenilendi (Son veri: $lastDataDate)';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 4),
          backgroundColor: isDataOutdated ? Colors.orange : null,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          children: [
            const Text(
              'Web TÜFE Mobile',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            onSelected: (value) async {
              switch (value) {
                case 'cache_clear':
                  _clearCache();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'connection',
                child: Row(
                  children: [
                    Icon(Icons.wifi),
                    SizedBox(width: 8),
                    Text('Bağlantıyı Kontrol Et'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'cache_clear',
                child: Row(
                  children: [
                    Icon(Icons.clear_all),
                    SizedBox(width: 8),
                    Text('Cache Temizle'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: isLoading
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
                        onPressed: () {
                          setState(() {
                            isLoading = true;
                            errorMessage = null;
                          });
                          loadCSVData();
                        },
                        child: const Text('Tekrar Dene'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Veri güncellik uyarısı
                      if (isDataOutdated && lastDataDate != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            border: Border.all(color: Colors.orange.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber_outlined,
                                    color: Colors.orange.shade700,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Veriler Güncel Değil',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange.shade800,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          displayedDataDate != null 
                                            ? 'Ekrandaki veri: $displayedDataDate\nEn güncel veri: $lastDataDate'
                                            : 'Son veri tarihi: $lastDataDate\nVeriler güncel değil.',
                                          style: TextStyle(
                                            color: Colors.orange.shade700,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: isLoading ? null : _refreshData,
                                  icon: const Icon(Icons.refresh, size: 18),
                                  label: const Text('Yenile Butonuna Tıklayarak Güncel Verileri Yükleyin'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange.shade600,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      // Tarih seçici
                      if (availableDates.isNotEmpty) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 20, color: Colors.blue),
                                const SizedBox(width: 12),
                                const Text(
                                  'Tarih Seç:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButton<String>(
                                    value: selectedDate,
                                    isExpanded: true,
                                    underline: const SizedBox(),
                                    items: availableDates.map((String date) {
                                      String displayText = date;
                                      try {
                                        DateTime dateTime = DateTime.parse(date);
                                        displayText = '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}';
                                      } catch (e) {
                                        // Tarih parse edilemezse olduğu gibi göster
                                      }
                                      return DropdownMenuItem<String>(
                                        value: date,
                                        child: Text(displayText),
                                      );
                                    }).toList(),
                                    onChanged: (String? newDate) {
                                      if (newDate != null && newDate != selectedDate) {
                                        setState(() {
                                          selectedDate = newDate;
                                          isLoading = true;
                                        });
                                        loadCSVData();
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      Text(
                        'Web TÜFE $currentMonth Ayı Ana Grup Artış Oranları',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TufeChart(data: tufeDataList),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: isLoading ? null : _refreshData,
        backgroundColor: isLoading ? Colors.grey : Colors.blue,
        child: isLoading 
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.refresh, color: Colors.white),
        tooltip: 'Verileri Yenile',
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
