# Kurulum ve Yapılandırma

## CSV Dosyalarını Okuma

React Native'de CSV dosyalarını okumak için birkaç seçenek vardır:

### Seçenek 1: react-native-fs Kullanımı (Önerilen)

1. Paketi yükleyin:
```bash
npm install react-native-fs
# veya
yarn add react-native-fs
```

2. Android için `android/app/src/main/assets/` klasörüne CSV dosyalarını kopyalayın

3. iOS için Xcode'da CSV dosyalarını projeye ekleyin

4. `GitHubCSVService.ts` dosyasını güncelleyin:
```typescript
import RNFS from 'react-native-fs';

private static async loadAssetFile(fileName: string): Promise<string> {
  try {
    const filePath = Platform.OS === 'android' 
      ? `${RNFS.MainBundlePath}/assets/${fileName}`
      : `${RNFS.MainBundlePath}/${fileName}`;
    
    return await RNFS.readFile(filePath, 'utf8');
  } catch (e) {
    throw new Error(`Dosya okunamadı: ${fileName} - ${e}`);
  }
}
```

### Seçenek 2: Remote URL'den Okuma

CSV dosyalarını bir GitHub repository'sinden veya CDN'den okuyabilirsiniz:

```typescript
private static async loadAssetFile(fileName: string): Promise<string> {
  const baseUrl = 'https://raw.githubusercontent.com/kaboya19/WebTufeMobile/main/assets/';
  const response = await fetch(`${baseUrl}${fileName}`);
  
  if (!response.ok) {
    throw new Error(`HTTP error! status: ${response.status}`);
  }
  
  return await response.text();
}
```

### Seçenek 3: require() Kullanımı (Statik Dosyalar)

Eğer CSV dosyaları statikse ve compile-time'da biliniyorsa:

```typescript
private static async loadAssetFile(fileName: string): Promise<string> {
  // Dosya yolu compile-time'da bilinmeli
  const csvData = require(`../assets/${fileName}`);
  return csvData;
}
```

## Android Konfigürasyonu

1. CSV dosyalarını `android/app/src/main/assets/` klasörüne kopyalayın

2. `android/app/build.gradle` dosyasında assets klasörünün doğru yapılandırıldığından emin olun

## iOS Konfigürasyonu

1. Xcode'da projeyi açın
2. CSV dosyalarını projeye sürükleyip bırakın
3. "Copy items if needed" seçeneğini işaretleyin
4. "Add to targets" bölümünde uygulama hedefini seçin

## Notlar

- CSV dosyaları büyükse, lazy loading veya chunking kullanmayı düşünün
- Cache mekanizması zaten implement edilmiştir, bu performansı artırır
- Production build'lerde CSV dosyalarının bundle boyutunu kontrol edin

