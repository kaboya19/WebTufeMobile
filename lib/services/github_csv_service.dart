import 'package:flutter/services.dart';

class GitHubCSVService {
  // Cache için timeout süresi (dakika)
  static const int _cacheTimeoutMinutes = 15;

  // Cache verilerini tutmak için static map
  static final Map<String, _CachedData> _cache = {};

  // Dosya adı alternatifleri - ASCII ve Turkish karakterli versiyonlar
  static final Map<String, List<String>> _fileNameAlternatives = {
    'ozel_gostergeler.csv': ['ozel_gostergeler.csv', 'özelgöstergeler.csv'],
    'ozelgostergeleraylik.csv': [
      'ozelgostergeleraylik.csv',
      'özelgöstergeleraylık.csv'
    ],
    'maddeleraylik.csv': ['maddeleraylik.csv', 'maddeleraylık.csv'],
    'harcama_gruplariaylik.csv': [
      'harcama_gruplariaylik.csv',
      'harcama_gruplarıaylık.csv'
    ],
    'harcama_gruplari.csv': [
      'harcama_gruplari.csv',
      'harcama_grupları.csv',
      'harcamagrupları.csv'
    ],
    'urunler.csv': ['urunler.csv', 'ürünler.csv'],
    'tufe.csv': ['tufe.csv', 'tüfe.csv'],
  };

  /// Yerel assets'ten CSV dosyasını okur
  /// [fileName] - assets klasöründeki dosya adı (örn: 'gruplaraylik.csv')
  /// [useCache] - Cache kullanılsın mı (varsayılan: true)
  static Future<String> loadCSVFromGitHub(String fileName,
      {bool useCache = true}) async {
    // Cache kontrolü
    if (useCache && _cache.containsKey(fileName)) {
      final cachedData = _cache[fileName]!;
      if (DateTime.now().difference(cachedData.timestamp).inMinutes <
          _cacheTimeoutMinutes) {
        print('Cache\'den CSV okunuyor: $fileName');
        return cachedData.data;
      } else {
        // Cache süresi dolmuş, kaldır
        _cache.remove(fileName);
      }
    }

    // Dosya adı alternatifleri ile dene
    List<String> filesToTry = _fileNameAlternatives[fileName] ?? [fileName];

    for (String tryFileName in filesToTry) {
      try {
        print('Yerel assets\'ten CSV okunuyor: $tryFileName');

        final String csvData =
            await rootBundle.loadString('assets/$tryFileName');

        print(
            'CSV başarıyla yüklendi: $tryFileName (${csvData.length} karakter)');

        // Debug: İlk birkaç satırı logla
        final lines = csvData.split('\n');
        print('CSV ilk satır: ${lines.isNotEmpty ? lines[0] : 'BOŞ'}');
        print('CSV satır sayısı: ${lines.length}');
        if (lines.length > 1) {
          print('CSV ikinci satır: ${lines[1]}');
        }

        // Cache'e kaydet
        if (useCache) {
          _cache[fileName] = _CachedData(csvData, DateTime.now());
        }

        return csvData;
      } catch (e) {
        print('Yerel asset okuma hatası $tryFileName için: $e');
        continue;
      }
    }

    // Hiçbir dosya adı çalışmazsa hata fırlat
    throw Exception('$fileName dosyası yerel assets\'te bulunamadı');
  }

  /// Cache verilerini temizle
  static void clearCache() {
    _cache.clear();
    print('CSV cache temizlendi');
  }

  /// Belirli bir dosyanın cache'ini temizle
  static void clearFileCache(String fileName) {
    _cache.remove(fileName);
    print('$fileName cache\'i temizlendi');
  }
}

/// Cache verisi için yardımcı sınıf
class _CachedData {
  final String data;
  final DateTime timestamp;

  _CachedData(this.data, this.timestamp);
}
