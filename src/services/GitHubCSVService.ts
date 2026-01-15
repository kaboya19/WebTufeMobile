import AsyncStorage from '@react-native-async-storage/async-storage';
import {Platform} from 'react-native';

const CACHE_TIMEOUT_MINUTES = 60; // 1 saat cache
const CACHE_PREFIX = 'csv_cache_';
const CACHE_TIMESTAMP_PREFIX = 'csv_timestamp_';

// Yerleşik katkı CSV fallback (remote/asset bulunamazsa)
const LOCAL_KATKI_CSV = `,Alkollü içecekler ve tütün,Ev eşyası,Eğitim,Eğlence ve kültür,Giyim ve ayakkabı,Gıda ve alkolsüz içecekler,Haberleşme,"Konut,Su,Elektrik,Gaz ve Diğer Yakıtlar",Lokanta ve oteller,Sağlık,Ulaştırma,Çeşitli mal ve hizmetler,Web TÜFE
2025-02-28,0.0,0.48,0.17,0.07,0.35,0.96,-0.04,0.82,0.31,-0.31,0.27,0.2,3.29
2025-03-31,0.38,0.29,0.18,0.03,0.52,1.44,-0.05,0.39,0.09,-0.01,0.02,0.19,3.45
2025-04-30,0.0,0.07,0.0,0.02,0.09,0.51,-0.07,0.83,0.36,0.0,0.42,0.11,2.34
2025-05-31,0.0,0.13,0.0,0.03,-0.0,-0.11,-0.0,0.59,0.4,0.0,0.3,0.05,1.39
2025-06-30,0.0,0.04,0.0,0.01,0.04,-0.06,-0.01,0.52,0.33,-0.0,0.37,0.06,1.3
2025-07-31,0.2,0.11,0.1,0.02,0.05,0.19,0.01,0.94,0.22,0.0,0.44,0.04,2.32
2025-08-31,0.26,0.11,-0.0,0.02,-0.29,0.58,0.06,0.39,0.37,-0.0,0.4,0.06,1.94
2025-09-30,0.01,0.07,0.66,0.02,0.1,0.78,0.07,0.48,0.14,0.0,0.17,0.12,2.61
2025-10-31,0.07,0.1,0.01,0.02,0.89,1.14,0.0,0.39,0.08,0.0,0.25,0.13,3.09
2025-11-30,0.14,-0.0,-0.0,-0.0,-0.08,0.41,0.04,0.34,0.05,-0.0,0.24,0.0,1.14
2025-12-31,-0.0,0.1,0.0,0.04,0.04,0.43,0.1,0.27,0.09,0.04,-0.16,0.06,1.01
`;

const fileNameAlternatives: {[key: string]: string[]} = {
  'ozel_gostergeler.csv': ['ozel_gostergeler.csv', 'özelgöstergeler.csv'],
  'ozelgostergeleraylik.csv': [
    'ozelgostergeleraylik.csv',
    'özelgöstergeleraylık.csv',
  ],
  'ozelgostergeleryıllık.csv': [
    'ozelgostergeleryıllık.csv',
    'özelgöstergeleryıllık.csv',
    'ozelgostergeleryillik.csv',
  ],
  'maddeleraylik.csv': ['maddeleraylik.csv', 'maddeleraylık.csv'],
  'maddeleryıllık.csv': [
    'maddeleryıllık.csv',
    'maddeleryıllık.csv',
    'maddeleryillik.csv',
  ],
  'harcama_gruplariaylik.csv': [
    'harcama_gruplariaylik.csv',
    'harcama_gruplarıaylık.csv',
  ],
  'harcamagruplarıyıllık.csv': [
    'harcamagruplarıyıllık.csv',
    'harcamagruplariyillik.csv',
  ],
  'harcama_gruplari.csv': [
    'harcama_gruplari.csv',
    'harcama_grupları.csv',
    'harcamagrupları.csv',
  ],
  'gruplaryıllık.csv': [
    'gruplaryıllık.csv',
    'gruplaryillik.csv',
  ],
  'urunler.csv': ['urunler.csv', 'ürünler.csv'],
  'tufe.csv': ['tufe.csv', 'tüfe.csv'],
  'tüfeyıllık.csv': [
    'tüfeyıllık.csv',
    'tufeyillik.csv',
    'tufeyillik.csv',
    'tufe_yillik.csv',
  ],
  'katkıpayları.csv': ['katkıpayları.csv', 'katkipaylari.csv', 'katki_paylari.csv'],
};

export class GitHubCSVService {
  static async loadCSVFromGitHub(
    fileName: string,
    useCache: boolean = true
  ): Promise<string> {
    // Cache kontrolü
    if (useCache) {
      const cachedData = await this.getCachedData(fileName);
      if (cachedData) {
        // Cache'den okundu (log azaltıldı)
        return cachedData;
      }
    }

    // Dosya adı alternatifleri ile dene
    const filesToTry = fileNameAlternatives[fileName] || [fileName];

    for (const tryFileName of filesToTry) {
      try {
        // React Native'de assets dosyalarını okumak için
        // require kullanarak veya fetch ile okuyabiliriz
        // Burada örnek olarak fetch kullanıyoruz, gerçek implementasyonda
        // assets klasöründen okunması gerekiyor
        
        // Not: React Native'de assets dosyalarını okumak için
        // genellikle require() kullanılır veya bundle içinde olmalıdır
        // Bu örnekte fetch ile GitHub'dan okuma simüle ediyoruz
        
        // Gerçek implementasyonda:
        // const csvData = require(`../assets/${tryFileName}`);
        // veya
        // const csvData = await fetch(`file:///android_asset/${tryFileName}`);
        
        // Şimdilik placeholder olarak boş string döndürüyoruz
        // Gerçek implementasyonda bu kısım düzeltilmeli
        const csvData = await this.loadAssetFile(tryFileName);

        console.log(`CSV yüklendi: ${tryFileName}`);

        // Cache'e kaydet
        if (useCache) {
          await this.setCachedData(fileName, csvData);
        }

        return csvData;
      } catch (e) {
        // Yerel asset okuma hatası (log azaltıldı)
        continue;
      }
    }

    throw new Error(`${fileName} dosyası yerel assets'te bulunamadı`);
  }

  private static async loadAssetFile(fileName: string): Promise<string> {
    // GitHub'dan CSV dosyalarını okuma
    // Flutter versiyonunda assets klasöründen okunuyordu,
    // React Native versiyonunda GitHub'dan fetch ile okuyoruz
    const baseUrl = 'https://raw.githubusercontent.com/kaboya19/WebTufeMobile/main/assets/';
    
    // Önce ana dosya adını dene
    const filesToTry = fileNameAlternatives[fileName] || [fileName];
    
    for (const tryFileName of filesToTry) {
      try {
        const response = await fetch(`${baseUrl}${encodeURIComponent(tryFileName)}`);
        
        if (response.ok) {
          const text = await response.text();
          console.log(`CSV GitHub'dan yüklendi: ${tryFileName}`);
          return text;
        }
      } catch (e) {
        // Bu dosya adı çalışmadı, bir sonrakini dene
        continue;
      }
    }
    
    // Katkı CSV için fallback (sadece GitHub'dan okunamazsa)
    if (fileNameAlternatives['katkıpayları.csv']?.includes(fileName)) {
      console.log(`Katkı CSV GitHub'dan okunamadı, fallback kullanılıyor`);
      return LOCAL_KATKI_CSV;
    }
    
    // Hiçbiri çalışmadıysa hata fırlat
    console.log(`GitHub'dan CSV okuma hatası ${fileName} için: Dosya bulunamadı (404)`);
    throw new Error(`CSV dosyası GitHub'da bulunamadı: ${fileName}. Lütfen dosyayı GitHub repository'nize yükleyin.`);
  }

  private static async getCachedData(fileName: string): Promise<string | null> {
    try {
      const cacheKey = `${CACHE_PREFIX}${fileName}`;
      const timestampKey = `${CACHE_TIMESTAMP_PREFIX}${fileName}`;
      
      const cachedData = await AsyncStorage.getItem(cacheKey);
      const timestampStr = await AsyncStorage.getItem(timestampKey);
      
      if (!cachedData || !timestampStr) {
        return null;
      }

      const timestamp = parseInt(timestampStr, 10);
      const now = Date.now();
      const diffMinutes = (now - timestamp) / (1000 * 60);

      if (diffMinutes < CACHE_TIMEOUT_MINUTES) {
        return cachedData;
      } else {
        // Cache süresi dolmuş, kaldır
        await AsyncStorage.multiRemove([cacheKey, timestampKey]);
        return null;
      }
    } catch (e) {
      // Cache okuma hatası (sessiz)
      return null;
    }
  }

  private static async setCachedData(
    fileName: string,
    data: string
  ): Promise<void> {
    try {
      const cacheKey = `${CACHE_PREFIX}${fileName}`;
      const timestampKey = `${CACHE_TIMESTAMP_PREFIX}${fileName}`;
      
      await AsyncStorage.multiSet([
        [cacheKey, data],
        [timestampKey, Date.now().toString()],
      ]);
    } catch (e) {
      // Cache yazma hatası (sessiz)
    }
  }

  static async clearCache(): Promise<void> {
    try {
      const keys = await AsyncStorage.getAllKeys();
      const cacheKeys = keys.filter(
        key =>
          key.startsWith(CACHE_PREFIX) || key.startsWith(CACHE_TIMESTAMP_PREFIX)
      );
      await AsyncStorage.multiRemove(cacheKeys);
      console.log('CSV cache temizlendi');
    } catch (e) {
      console.log('Cache temizleme hatası:', e);
    }
  }

  static async clearFileCache(fileName: string): Promise<void> {
    try {
      const cacheKey = `${CACHE_PREFIX}${fileName}`;
      const timestampKey = `${CACHE_TIMESTAMP_PREFIX}${fileName}`;
      await AsyncStorage.multiRemove([cacheKey, timestampKey]);
      console.log(`${fileName} cache'i temizlendi`);
    } catch (e) {
      console.log('Dosya cache temizleme hatası:', e);
    }
  }
}

