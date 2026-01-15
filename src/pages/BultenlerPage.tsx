import React, {useEffect, useMemo, useState} from 'react';
import {View, Text, StyleSheet, TouchableOpacity, Platform, Alert, Linking} from 'react-native';
import {MaterialIcons as Icon} from '@expo/vector-icons';
import {Asset} from 'expo-asset';
import * as Sharing from 'expo-sharing';
import WebPicker from '../components/WebPicker';

type BulletinItem = {
  key: string; // YYYY-MM
  label: string; // e.g. "Kasım 2025"
  asset: number; // require(...)
  uri?: string;
};

// Sabit bülten listesi (assets/bültenler içeriği)
const BULLETINS: BulletinItem[] = [
  {key: '2025-12', label: 'Aralık 2025', asset: require('../../assets/bültenler/Aralık 2025.pdf')},
  {key: '2025-11', label: 'Kasım 2025', asset: require('../../assets/bültenler/Kasım 2025.pdf')},
  {key: '2025-10', label: 'Ekim 2025', asset: require('../../assets/bültenler/Ekim 2025.pdf')},
  {key: '2025-09', label: 'Eylül 2025', asset: require('../../assets/bültenler/Eylül 2025.pdf')},
  {key: '2025-08', label: 'Ağustos 2025', asset: require('../../assets/bültenler/Ağustos 2025.pdf')},
  {key: '2025-07', label: 'Temmuz 2025', asset: require('../../assets/bültenler/Temmuz 2025.pdf')},
  {key: '2025-06', label: 'Haziran 2025', asset: require('../../assets/bültenler/Haziran 2025.pdf')},
].sort((a, b) => b.key.localeCompare(a.key));

const BultenlerPage = () => {
  const [selectedKey, setSelectedKey] = useState(BULLETINS[0]?.key || '');
  const [items, setItems] = useState<BulletinItem[]>(BULLETINS);
  const [isLoading, setIsLoading] = useState(false);

  const selectedItem = useMemo(
    () => items.find((i) => i.key === selectedKey) || items[0],
    [items, selectedKey]
  );

  useEffect(() => {
    const loadAssets = async () => {
      try {
        setIsLoading(true);
        const resolved = await Promise.all(
          BULLETINS.map(async (b) => {
            try {
              if (Platform.OS === 'web') {
                // Web'de require ile yüklenen asset'ler doğrudan URL döndürür
                const uri = b.asset as unknown as string;
                return {...b, uri};
              } else {
                // Native için Asset API kullan
                // Bundle içindeki asset'ler için downloadAsync() gerekmez, direkt uri kullanılabilir
                const asset = Asset.fromModule(b.asset);
                
                // downloadAsync() Türkçe karakterli dosya adlarında sorun çıkarabiliyor
                // Bundle içindeki asset'ler için asset.uri zaten mevcut ve kullanılabilir
                try {
                  // Önce downloadAsync dene (localUri için)
                  await asset.downloadAsync();
                  // Başarılı olursa localUri'yi kullan
                  return {...b, uri: asset.localUri || asset.uri};
                } catch (downloadError) {
                  // downloadAsync hatası durumunda direkt asset.uri'yi kullan
                  // Bundle içindeki asset'ler için bu çalışır
                  return {...b, uri: asset.uri};
                }
              }
            } catch (e) {
              console.log(`Asset yükleme hatası ${b.key}:`, e);
              return {...b, uri: undefined};
            }
          })
        );
        setItems(resolved);
      } catch (e) {
        console.log('Bültenleri yüklerken hata:', e);
      } finally {
        setIsLoading(false);
      }
    };
    loadAssets();
  }, []);

  const openBulletin = async () => {
    if (!selectedItem) return;
    
    try {
      // URI yoksa asset'i tekrar resolve et
      let uri = selectedItem.uri;
      if (!uri) {
        if (Platform.OS === 'web') {
          uri = selectedItem.asset as unknown as string;
        } else {
          try {
            const asset = Asset.fromModule(selectedItem.asset);
            // downloadAsync() denemesi, hata durumunda asset.uri kullan
            try {
              await asset.downloadAsync();
              uri = asset.localUri || asset.uri;
            } catch (downloadError) {
              // downloadAsync hatası durumunda direkt asset.uri kullan
              uri = asset.uri;
            }
          } catch (assetError) {
            console.log('Asset resolve hatası:', assetError);
          }
        }
        
        if (!uri) {
          Alert.alert('Hata', 'Bülten dosyası bulunamadı.');
          return;
        }
      }

      // Web'de direkt aç
      if (Platform.OS === 'web') {
        if (typeof (global as any).window !== 'undefined' && (global as any).window.open) {
          (global as any).window.open(uri, '_blank');
        } else {
          await Linking.openURL(uri);
        }
        return;
      }

      // Mobilde PDF açmak için
      try {
        // Asset'ten gelen URI genellikle file:// ile başlar
        // Android'de direkt Linking.openURL çalışabilir
        const canOpen = await Linking.canOpenURL(uri);
        if (canOpen) {
          await Linking.openURL(uri);
        } else {
          // Fallback: Sharing ile paylaş (kullanıcı PDF viewer seçebilir)
          const isAvailable = await Sharing.isAvailableAsync();
          if (isAvailable) {
            await Sharing.shareAsync(uri, {
              mimeType: 'application/pdf',
              dialogTitle: selectedItem.label,
            });
          } else {
            Alert.alert('Hata', 'PDF açılamadı. Lütfen tekrar deneyin.');
          }
        }
      } catch (linkError) {
        // Linking hatası durumunda Sharing dene
        try {
          const isAvailable = await Sharing.isAvailableAsync();
          if (isAvailable) {
            await Sharing.shareAsync(uri, {
              mimeType: 'application/pdf',
              dialogTitle: selectedItem.label,
            });
          } else {
            throw linkError;
          }
        } catch (shareError) {
          throw linkError;
        }
      }
    } catch (e) {
      const errorMessage = e instanceof Error ? e.message : String(e);
      console.log('PDF açma hatası:', errorMessage);
      
      const message =
        Platform.OS === 'web'
          ? 'Tarayıcıda açılır pencere engellenmiş olabilir. Adresi manuel açmayı deneyin.'
          : `Dosya açılamadı: ${errorMessage}. Lütfen tekrar deneyin.`;
      Alert.alert('Açılamadı', message);
    }
  };

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Bültenler</Text>
      <Text style={styles.subtitle}>
        Ay-Yıl seçerek ilgili PDF bülteni görüntüleyebilirsiniz.
      </Text>

      <View style={styles.pickerContainer}>
        <Icon name="calendar-month" size={20} color="#2196F3" />
        <Text style={styles.pickerLabel}>Bülten Tarihi</Text>
        <View style={styles.pickerWrapper}>
          <WebPicker
            selectedValue={selectedKey}
            onValueChange={(value) => setSelectedKey(value)}
            style={styles.picker}>
            {items.map((item) => (
              <WebPicker.Item key={item.key} label={item.label} value={item.key} />
            ))}
          </WebPicker>
        </View>
      </View>

      <View style={styles.card}>
        <View style={styles.cardHeader}>
          <Icon name="picture-as-pdf" size={24} color="#e53935" />
          <Text style={styles.cardTitle}>{selectedItem?.label || 'Bülten'}</Text>
        </View>
        <Text style={styles.cardDesc}>PDF dosyasını açmak için aşağıdaki butona tıklayın.</Text>
        <TouchableOpacity
          style={[styles.button, isLoading && styles.buttonDisabled]}
          onPress={openBulletin}
          disabled={isLoading}>
          <Text style={styles.buttonText}>{isLoading ? 'Yükleniyor...' : 'Bülteni Aç'}</Text>
        </TouchableOpacity>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    padding: 16,
    backgroundColor: '#fff',
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#1E88E5',
    marginBottom: 6,
  },
  subtitle: {
    fontSize: 14,
    color: '#616161',
    marginBottom: 16,
  },
  pickerContainer: {
    backgroundColor: '#F5F5F5',
    borderRadius: 12,
    padding: 12,
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 16,
  },
  pickerLabel: {
    marginLeft: 8,
    fontWeight: '600',
    color: '#424242',
  },
  pickerWrapper: {
    flex: 1,
    marginLeft: 12,
  },
  picker: {
    height: 48,
  },
  card: {
    backgroundColor: '#fff',
    borderRadius: 12,
    padding: 16,
    borderWidth: 1,
    borderColor: '#E0E0E0',
  },
  cardHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 8,
    gap: 8,
  },
  cardTitle: {
    fontSize: 18,
    fontWeight: '700',
    color: '#212121',
  },
  cardDesc: {
    fontSize: 14,
    color: '#616161',
    marginBottom: 12,
  },
  button: {
    backgroundColor: '#1E88E5',
    paddingVertical: 12,
    borderRadius: 10,
    alignItems: 'center',
  },
  buttonDisabled: {
    opacity: 0.7,
  },
  buttonText: {
    color: '#fff',
    fontWeight: '700',
    fontSize: 16,
  },
});

export default BultenlerPage;


