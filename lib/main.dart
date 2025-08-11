import 'package:flutter/material.dart';
import 'models/tufe_data.dart';
import 'services/csv_service.dart';
import 'services/github_csv_service.dart';
import 'widgets/tufe_chart.dart';
import 'pages/tufe_page.dart';
import 'pages/ana_gruplar_page.dart';
import 'pages/harcama_gruplari_page.dart';
import 'pages/maddeler_page.dart';
import 'pages/ozel_gostergeler_page.dart';

void main() {
  runApp(const MyApp());
}

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
      home: const MainPage(),
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

  @override
  void initState() {
    super.initState();
    loadCSVData();
  }

  Future<void> loadCSVData() async {
    try {
      final data = await CSVService.loadTufeData();
      final month = await CSVService.getMonthFromCSV();
      setState(() {
        tufeDataList = data;
        currentMonth = month;
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veriler yenilendi'),
          duration: Duration(seconds: 2),
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
