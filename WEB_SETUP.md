# Web'de Çalıştırma Rehberi

## Kurulum

1. **Bağımlılıkları yükleyin:**
   ```bash
   npm install
   ```

2. **Web'de çalıştırın:**
   ```bash
   npm run web
   ```
   
   veya
   
   ```bash
   npx expo start --web
   ```

## Web için Özel Notlar

### React Native Vector Icons
Web'de `react-native-vector-icons` çalışmayabilir. Alternatif olarak:
- `@expo/vector-icons` kullanabilirsiniz
- Veya web için Material Icons'u doğrudan kullanabilirsiniz

### AsyncStorage
Web'de `@react-native-async-storage/async-storage` localStorage kullanır, bu normaldir.

### Platform Kontrolü
Web'de bazı native modüller çalışmayabilir. Platform kontrolü için:
```typescript
import { Platform } from 'react-native';

if (Platform.OS === 'web') {
  // Web-specific code
}
```

## Sorun Giderme

### Port Zaten Kullanılıyor
```bash
npx expo start --web --port 8080
```

### Build Hatası
```bash
npx expo export:web
```

## Production Build

Web için production build:
```bash
npx expo export:web
```

Build dosyaları `web-build/` klasöründe oluşur.

