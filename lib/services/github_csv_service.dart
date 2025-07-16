import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class GitHubCSVService {
  // GitHub Raw API base URL - kullanıcının repo'su
  static const String _baseUrl =
      'https://raw.githubusercontent.com/kaboya19/WebTufeMobile/main';

  // CORS proxy for web (Flutter web can't directly access GitHub due to CORS)
  static const String _corsProxy = 'https://api.allorigins.win/raw?url=';

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
    'harcama_gruplari.csv': ['harcama_gruplari.csv', 'harcama_grupları.csv'],
    'urunler.csv': ['urunler.csv', 'ürünler.csv'],
    'tufe.csv': ['tufe.csv', 'tüfe.csv'],
  };

  /// Cache busting için tarih parametresi oluşturur (format: ?v=YYYYMMDDHHMM)
  static String _getCacheBustingParam() {
    final now = DateTime.now();
    return '?v=${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
  }

  /// GitHub'dan CSV dosyasını çeker
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
        print('Denenen dosya: $tryFileName');

        // Platform'a göre URL oluştur
        String url;
        if (kIsWeb) {
          // Web için jsDelivr CDN kullan (en güvenilir)
          url =
              'https://cdn.jsdelivr.net/gh/kaboya19/WebTufeMobile@main/assets/$tryFileName${_getCacheBustingParam()}';
          print('jsDelivr CDN ile CSV çekiliyor (ana method): $url');
          print('Dosya adı: [$tryFileName]');
        } else {
          // Mobil için direkt GitHub URL
          url = '$_baseUrl/assets/$tryFileName';
          print('GitHub\'dan CSV çekiliyor: $url');
        }

        final response = await http.get(
          Uri.parse(url),
          headers: {
            'Accept': 'text/csv',
            'Cache-Control': 'no-cache',
          },
        ).timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          // UTF-8 decode et
          String csvData;
          if (response.headers['content-type']?.contains('charset=utf-8') ==
              true) {
            csvData = response.body;
          } else {
            csvData = utf8.decode(response.bodyBytes);
          }

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
        } else {
          print('HTTP hatası $tryFileName için: ${response.statusCode}');
          // Bu dosya adı başarısız, bir sonrakini dene
          continue;
        }
      } on SocketException catch (e) {
        print('İnternet bağlantısı hatası $tryFileName için: $e');
        continue;
      } on http.ClientException catch (e) {
        print('HTTP istek hatası $tryFileName için: $e');
        continue;
      } catch (e) {
        print('GitHub CSV yükleme hatası $tryFileName için: $e');
        continue;
      }
    }

    // Hiçbir dosya adı çalışmazsa fallback dene
    print('Tüm dosya adları başarısız, fallback deneniyor: $fileName');
    return await _loadLocalFallback(fileName);
  }

  /// Fallback mekanizması - alternatif yöntemler dener
  static Future<String> _loadLocalFallback(String fileName) async {
    if (kIsWeb) {
      // Web için alternatif CORS proxy dene
      try {
        print('Alternatif CORS proxy deneniyor: $fileName');
        final githubUrl = '$_baseUrl/assets/$fileName';
        final altProxyUrl =
            'https://corsproxy.io/?${Uri.encodeComponent(githubUrl)}';

        final response = await http.get(
          Uri.parse(altProxyUrl),
          headers: {'Accept': 'text/csv'},
        ).timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          print('Alternatif proxy başarılı: $fileName');
          return utf8.decode(response.bodyBytes);
        }
      } catch (e) {
        print('Alternatif proxy da başarısız: $e');
      }

      // Son çare: jsDelivr CDN dene
      try {
        print('jsDelivr CDN deneniyor: $fileName');
        final cdnUrl =
            'https://cdn.jsdelivr.net/gh/kaboya19/WebTufeMobile@main/assets/$fileName${_getCacheBustingParam()}';

        final response = await http.get(
          Uri.parse(cdnUrl),
          headers: {'Accept': 'text/csv'},
        ).timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          print('jsDelivr CDN başarılı: $fileName');
          final csvData = utf8.decode(response.bodyBytes);

          // Debug: İlk birkaç satırı logla
          final lines = csvData.split('\n');
          print(
              'CSV ilk satır (fallback): ${lines.isNotEmpty ? lines[0] : 'BOŞ'}');
          print('CSV satır sayısı (fallback): ${lines.length}');
          if (lines.length > 1) {
            print('CSV ikinci satır (fallback): ${lines[1]}');
          }

          return csvData;
        }
      } catch (e) {
        print('jsDelivr CDN da başarısız: $e');
      }

      // Son çare olarak Turkish karakterli dosyaları dene
      List<String> filesToTry = _fileNameAlternatives[fileName] ?? [fileName];

      for (String tryFileName in filesToTry) {
        if (tryFileName == fileName) continue; // Zaten denedik

        try {
          print('Fallback Turkish karakterli dosya deneniyor: $tryFileName');
          final cdnUrl =
              'https://cdn.jsdelivr.net/gh/kaboya19/WebTufeMobile@main/assets/$tryFileName${_getCacheBustingParam()}';

          final response = await http.get(
            Uri.parse(cdnUrl),
            headers: {'Accept': 'text/csv'},
          ).timeout(const Duration(seconds: 30));

          if (response.statusCode == 200) {
            print('Turkish karakterli dosya başarılı: $tryFileName');
            return utf8.decode(response.bodyBytes);
          }
        } catch (e) {
          print('Turkish karakterli dosya başarısız: $tryFileName - $e');
        }
      }
    }

    // Yerel asset'i dene (son çare)
    try {
      print('Yerel asset deneniyor: $fileName');
      return await rootBundle.loadString('assets/$fileName');
    } catch (e) {
      print('Yerel asset da başarısız: $e');
      throw Exception('$fileName dosyası hiçbir yöntemle yüklenemedi');
    }
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

  /// İnternet bağlantısı kontrolü
  static Future<bool> hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }
}

/// Cache verisi için yardımcı sınıf
class _CachedData {
  final String data;
  final DateTime timestamp;

  _CachedData(this.data, this.timestamp);
}
