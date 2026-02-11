import React, {useRef, useState, useEffect} from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  ActivityIndicator,
  TouchableOpacity,
  Alert,
  Platform,
  TextInput,
} from 'react-native';
import {MaterialIcons as Icon} from '@expo/vector-icons';
import WebPicker from '../components/WebPicker';
import {CSVService} from '../services/CSVService';
import {GitHubCSVService} from '../services/GitHubCSVService';
import {TufeDataModel} from '../models/TufeData';
import TufeChart from '../components/TufeChart';
import {NewsletterService} from '../services/NewsletterService';

const TufeHomePage = () => {
  const [tufeDataList, setTufeDataList] = useState<TufeDataModel[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [currentMonth, setCurrentMonth] = useState('');
  const [isDataOutdated, setIsDataOutdated] = useState(false);
  const [lastDataDate, setLastDataDate] = useState<string | null>(null);
  const [displayedDataDate, setDisplayedDataDate] = useState<string | null>(
    null
  );
  const [availableDates, setAvailableDates] = useState<string[]>([]);
  const [selectedDate, setSelectedDate] = useState<string | null>(null);

  const [newsletterEmail, setNewsletterEmail] = useState('');
  const [isSubscribing, setIsSubscribing] = useState(false);
  const [newsletterMessage, setNewsletterMessage] = useState<string | null>(null);
  const [newsletterError, setNewsletterError] = useState<string | null>(null);
  const newsletterEmailRef = useRef('');

  useEffect(() => {
    initializeData();
  }, []);

  const initializeData = async () => {
    try {
      // Önce tarih listesini yükle
      const dates = await CSVService.getAvailableDates();
      let initialDate: string | null = null;
      if (dates.length > 0) {
        initialDate = dates[dates.length - 1]; // En son tarih
      }

      setAvailableDates(dates);
      setSelectedDate(initialDate);

      // Verileri yükle
      await loadCSVData();
    } catch (e) {
      setIsLoading(false);
      setErrorMessage(String(e));
    }
  };

  const loadCSVData = async (overrideDate?: string) => {
    try {
      let data: TufeDataModel[];
      let month: string;

      const effectiveDate = overrideDate || selectedDate;

      if (effectiveDate) {
        // Seçili tarih için veri yükle
        data = await CSVService.loadTufeDataForDate(effectiveDate);
        month = CSVService.getMonthFromDate(effectiveDate);
      } else {
        // Son tarih için veri yükle
        data = await CSVService.loadTufeData();
        month = await CSVService.getMonthFromCSV();
      }

      const dataFreshness = await checkDataFreshness();

      setTufeDataList(data);
      setCurrentMonth(month);
      setIsDataOutdated(dataFreshness.isOutdated);
      setLastDataDate(dataFreshness.lastDate);
      setDisplayedDataDate(dataFreshness.displayedDate);
      setIsLoading(false);
      setErrorMessage(null);
    } catch (e) {
      setIsLoading(false);
      setErrorMessage(String(e));
      setCurrentMonth(CSVService.getCurrentMonth()); // Fallback
    }
  };


  const checkDataFreshness = async (): Promise<{
    isOutdated: boolean;
    lastDate: string | null;
    displayedDate: string | null;
  }> => {
    try {
      // Günlük TÜFE verilerinden en son tarihi al (cache kullan)
      const csvData = await GitHubCSVService.loadCSVFromGitHub(
        'tufe.csv',
        true
      );

      const lines = csvData.split(/\r?\n/);
      if (lines.length < 2) {
        return {isOutdated: false, lastDate: null, displayedDate: null};
      }

      // Son satırdan tarihi al (CSV'deki en son veri tarihi)
      let lastLine = lines[lines.length - 1].trim();
      if (!lastLine && lines.length > 2) {
        lastLine = lines[lines.length - 2].trim();
      }

      if (lastLine) {
        const parts = lastLine.split(',');
        if (parts.length > 0) {
          const csvLastDateStr = parts[0].trim();

          try {
            const csvLastDate = new Date(csvLastDateStr);

            // Ekranda gösterilen veri tarihini al (aylık CSV'den - cache kullan)
            const monthlyData = await GitHubCSVService.loadCSVFromGitHub(
              'gruplaraylıkv2.csv',
              true
            );
            const monthlyLines = monthlyData.split(/\r?\n/);

            let displayedDataDate: Date | null = null;
            if (monthlyLines.length > 0) {
              // Header satırından son sütun tarihini al
              const headerParts = monthlyLines[0].split(',');
              if (headerParts.length > 0) {
                const displayedDateStr = headerParts[headerParts.length - 1].trim();
                try {
                  displayedDataDate = new Date(displayedDateStr);
                } catch (e) {
                  console.log('Ekran tarihi parse hatası:', e);
                }
              }
            }

            // Karşılaştırma: ekranda gösterilen tarih ile CSV'deki son tarih
            let isOutdated = false;
            let daysDifference = 0;

            if (displayedDataDate) {
              daysDifference =
                (csvLastDate.getTime() - displayedDataDate.getTime()) /
                (1000 * 60 * 60 * 24);
              // 1 gün bile eksikse uyarı ver
              isOutdated = daysDifference >= 1;
            }

            // Tarihleri Türkçe formata çevir
            const csvFormattedDate = `${csvLastDate
              .getDate()
              .toString()
              .padStart(2, '0')}.${(csvLastDate.getMonth() + 1)
              .toString()
              .padStart(2, '0')}.${csvLastDate.getFullYear()}`;
            let displayedFormattedDate: string | null = null;
            if (displayedDataDate) {
              displayedFormattedDate = `${displayedDataDate
                .getDate()
                .toString()
                .padStart(2, '0')}.${(displayedDataDate.getMonth() + 1)
                .toString()
                .padStart(2, '0')}.${displayedDataDate.getFullYear()}`;
            }

            return {
              isOutdated,
              lastDate: csvFormattedDate,
              displayedDate: displayedFormattedDate,
            };
          } catch (e) {
            console.log('Tarih parse hatası:', e);
          }
        }
      }

      return {isOutdated: false, lastDate: null, displayedDate: null};
    } catch (e) {
      console.log('Veri güncellik kontrolü hatası:', e);
      return {isOutdated: false, lastDate: null, displayedDate: null};
    }
  };

  const clearCache = async () => {
    await GitHubCSVService.clearCache();
    Alert.alert('Başarılı', 'Cache temizlendi');
  };

  const refreshData = async () => {
    await GitHubCSVService.clearCache();
    setIsLoading(true);
    setErrorMessage(null);
    await loadCSVData();

    // Refresh successful feedback
    let message = 'Veriler yenilendi';
    if (isDataOutdated && lastDataDate && displayedDataDate) {
      message = `Veriler yenilendi\nEkran: ${displayedDataDate} | Güncel: ${lastDataDate}`;
    } else if (isDataOutdated && lastDataDate) {
      message = `Veriler yenilendi (Son veri: ${lastDataDate})`;
    }

    Alert.alert('Başarılı', message);
  };

  const isValidEmail = (email: string) => {
    const s = (email || '').trim();
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(s);
  };

  const setEmail = (next: string) => {
    newsletterEmailRef.current = next;
    setNewsletterEmail(next);
  };

  const subscribeNewsletter = async () => {
    let email = (newsletterEmailRef.current || newsletterEmail).trim();
    setNewsletterMessage(null);
    setNewsletterError(null);

    // RN Web can occasionally miss TextInput change events; as a last-resort, read DOM value on submit.
    if (Platform.OS === 'web' && (!email || !isValidEmail(email))) {
      try {
        const doc: any = typeof document !== 'undefined' ? document : null;
        const el: any = doc?.querySelector?.('input[placeholder="E-posta adresiniz"]');
        const domValue = typeof el?.value === 'string' ? el.value.trim() : '';
        if (domValue) {
          email = domValue;
          setEmail(domValue);
        }
      } catch {
        // ignore
      }
    }

    if (!isValidEmail(email)) {
      setNewsletterError('Lütfen geçerli bir e-posta adresi girin.');
      return;
    }

    try {
      setIsSubscribing(true);
      const res =
        Platform.OS === 'web'
          ? await NewsletterService.subscribeWebViaIframe(email)
          : await NewsletterService.subscribe(email);
      if (res.ok) {
        setNewsletterMessage(res.message || 'Aboneliğiniz alındı. Teşekkürler!');
        setEmail('');
      } else {
        setNewsletterError(res.message || 'Abonelik sırasında hata oluştu.');
      }
    } catch (e) {
      setNewsletterError(e instanceof Error ? e.message : String(e));
    } finally {
      setIsSubscribing(false);
    }
  };

  if (isLoading) {
    return (
      <View style={styles.centerContainer}>
        <ActivityIndicator size="large" color="#2196F3" />
      </View>
    );
  }

  if (errorMessage) {
    return (
      <View style={styles.centerContainer}>
        <Icon name="error-outline" size={48} color="#f44336" />
        <Text style={styles.errorText}>Hata: {errorMessage}</Text>
        <TouchableOpacity
          style={styles.retryButton}
          onPress={() => {
            setIsLoading(true);
            setErrorMessage(null);
            loadCSVData();
          }}>
          <Text style={styles.retryButtonText}>Tekrar Dene</Text>
        </TouchableOpacity>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <ScrollView style={styles.scrollView} contentContainerStyle={styles.content}>
        {/* Veri güncellik uyarısı */}
        {isDataOutdated && lastDataDate && (
          <View style={styles.warningContainer}>
            <View style={styles.warningContent}>
              <Icon
                name="warning"
                size={24}
                color="#FF9800"
                style={styles.warningIcon}
              />
              <View style={styles.warningTextContainer}>
                <Text style={styles.warningTitle}>Veriler Güncel Değil</Text>
                <Text style={styles.warningText}>
                  {displayedDataDate
                    ? `Ekrandaki veri: ${displayedDataDate}\nEn güncel veri: ${lastDataDate}`
                    : `Son veri tarihi: ${lastDataDate}\nVeriler güncel değil.`}
                </Text>
              </View>
            </View>
            <TouchableOpacity
              style={styles.refreshButton}
              onPress={refreshData}
              disabled={isLoading}>
              <Icon name="refresh" size={18} color="#fff" />
              <Text style={styles.refreshButtonText}>
                Yenile Butonuna Tıklayarak Güncel Verileri Yükleyin
              </Text>
            </TouchableOpacity>
          </View>
        )}

        {/* Tarih seçici */}
        {availableDates.length > 0 && (
          <View style={styles.datePickerContainer}>
            <Icon name="calendar-today" size={20} color="#2196F3" />
            <Text style={styles.datePickerLabel}>Tarih Seç:</Text>
            <View style={styles.pickerContainer}>
              <WebPicker
                selectedValue={selectedDate}
                onValueChange={async (itemValue) => {
                  if (itemValue && itemValue !== selectedDate) {
                    setSelectedDate(itemValue);
                    setIsLoading(true);
                    await loadCSVData(itemValue);
                  }
                }}
                style={styles.picker}>
                {availableDates.map((date) => {
                  let displayText = date;
                  try {
                    const dateTime = new Date(date);
                    displayText = `${dateTime.getFullYear()}-${(dateTime.getMonth() + 1)
                      .toString()
                      .padStart(2, '0')}`;
                  } catch (e) {
                    // Tarih parse edilemezse olduğu gibi göster
                  }
                  return (
                    <WebPicker.Item key={date} label={displayText} value={date} />
                  );
                })}
              </WebPicker>
            </View>
          </View>
        )}

        <Text style={styles.title}>
          Web TÜFE {currentMonth} Ayı Ana Grup Artış Oranları
        </Text>

        <View style={styles.chartWrapper}>
          <TufeChart
            data={tufeDataList}
            showContributions={false}
          />
        </View>

        <View style={styles.newsletterCard}>
          <View style={styles.newsletterHeader}>
            <Icon name="mail-outline" size={20} color="#1E88E5" />
            <Text style={styles.newsletterTitle}>Bülten Aboneliği</Text>
          </View>
          <Text style={styles.newsletterDesc}>
            Güncel veriler ve önemli duyurular için e-posta bültenine abone olun.
          </Text>

          <View style={styles.newsletterRow}>
            <TextInput
              value={newsletterEmail}
              onChangeText={(t) => {
                setEmail(t);
                if (newsletterError) setNewsletterError(null);
                if (newsletterMessage) setNewsletterMessage(null);
              }}
              // RN Web sometimes requires onChange to reliably propagate value in controlled inputs.
              onChange={(e) => {
                const anyEvt: any = e as any;
                const nativeText = anyEvt?.nativeEvent?.text;
                if (typeof nativeText === 'string') {
                  setEmail(nativeText);
                } else if (typeof anyEvt?.target?.value === 'string') {
                  setEmail(anyEvt.target.value);
                } else if (typeof anyEvt?.currentTarget?.value === 'string') {
                  setEmail(anyEvt.currentTarget.value);
                } else {
                  // If we can't extract a value, don't clobber the current state.
                  return;
                }
                if (newsletterError) setNewsletterError(null);
                if (newsletterMessage) setNewsletterMessage(null);
              }}
              placeholder="E-posta adresiniz"
              autoCapitalize="none"
              autoCorrect={false}
              keyboardType={Platform.OS === 'web' ? 'email' : 'email-address'}
              style={styles.newsletterInput}
              editable={!isSubscribing}
              onSubmitEditing={subscribeNewsletter}
            />
            <TouchableOpacity
              style={[styles.newsletterButton, isSubscribing && styles.newsletterButtonDisabled]}
              onPress={subscribeNewsletter}
              disabled={isSubscribing}
              accessibilityRole="button"
              accessibilityLabel="Abone Ol"
              accessible
            >
              {isSubscribing ? (
                <ActivityIndicator size="small" color="#fff" />
              ) : (
                <Text style={styles.newsletterButtonText}>Abone Ol</Text>
              )}
            </TouchableOpacity>
          </View>

          {!!newsletterError && (
            <Text style={styles.newsletterErrorText}>{newsletterError}</Text>
          )}
          {!!newsletterMessage && (
            <Text style={styles.newsletterSuccessText}>{newsletterMessage}</Text>
          )}

          <Text style={styles.newsletterFinePrint}>
            E-postanız yalnızca bülten aboneliği için kullanılır.
          </Text>
        </View>
      </ScrollView>

      <TouchableOpacity
        style={[styles.fab, isLoading && styles.fabDisabled]}
        onPress={refreshData}
        disabled={isLoading}>
        {isLoading ? (
          <ActivityIndicator size="small" color="#fff" />
        ) : (
          <Icon name="refresh" size={24} color="#fff" />
        )}
      </TouchableOpacity>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#fff',
  },
  centerContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#fff',
  },
  scrollView: {
    flex: 1,
  },
  content: {
    padding: 16,
  },
  warningContainer: {
    width: '100%',
    padding: 12,
    marginBottom: 16,
    backgroundColor: '#FFF3E0',
    borderWidth: 1,
    borderColor: '#FFB74D',
    borderRadius: 8,
  },
  warningContent: {
    flexDirection: 'row',
    marginBottom: 12,
  },
  warningIcon: {
    marginRight: 12,
  },
  warningTextContainer: {
    flex: 1,
  },
  warningTitle: {
    fontWeight: 'bold',
    color: '#E65100',
    fontSize: 14,
    marginBottom: 4,
  },
  warningText: {
    color: '#F57C00',
    fontSize: 12,
  },
  refreshButton: {
    width: '100%',
    backgroundColor: '#FF9800',
    padding: 12,
    borderRadius: 8,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
  },
  refreshButtonText: {
    color: '#fff',
    marginLeft: 8,
    fontWeight: '600',
  },
  datePickerContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 16,
    padding: 12,
    backgroundColor: '#F5F5F5',
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#E0E0E0',
  },
  datePickerLabel: {
    fontWeight: '600',
    fontSize: 14,
    marginLeft: 12,
    marginRight: 12,
  },
  pickerContainer: {
    flex: 1,
  },
  picker: {
    flex: 1,
  },
  title: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#212121',
    marginBottom: 16,
    lineHeight: 22,
  },
  newsletterCard: {
    marginTop: 18,
    padding: 14,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#E3F2FD',
    backgroundColor: '#F7FBFF',
  },
  newsletterHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 6,
  },
  newsletterTitle: {
    marginLeft: 8,
    fontSize: 16,
    fontWeight: '700',
    color: '#0D47A1',
  },
  newsletterDesc: {
    color: '#455A64',
    fontSize: 12,
    marginBottom: 10,
    lineHeight: 16,
  },
  card: {
    marginTop: 18,
    padding: 14,
    backgroundColor: '#fff',
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#E0E0E0',
    gap: 10,
  },
  cardHeaderRow: {flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 12},
  cardTitle: {fontSize: 18, fontWeight: '700', color: '#212121'},
  chartWrapper: {position: 'relative', marginTop: 12, marginBottom: 8},
  floatCheckbox: {
    position: 'absolute',
    top: -16,
    right: 0,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    paddingHorizontal: 8,
    paddingVertical: 6,
    backgroundColor: '#fff',
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#E0E0E0',
  },
  checkboxRow: {flexDirection: 'row', alignItems: 'center', gap: 6},
  checkbox: {
    width: 18,
    height: 18,
    borderRadius: 4,
    borderWidth: 1,
    borderColor: '#1E88E5',
    alignItems: 'center',
    justifyContent: 'center',
  },
  checkboxChecked: {
    backgroundColor: '#1E88E5',
  },
  checkboxLabel: {fontSize: 12, color: '#424242'},
  newsletterRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  newsletterInput: {
    flex: 1,
    height: 44,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: '#BBDEFB',
    backgroundColor: '#fff',
    paddingHorizontal: 12,
    fontSize: 14,
    color: '#263238',
  },
  newsletterButton: {
    marginLeft: 10,
    height: 44,
    minWidth: 96,
    paddingHorizontal: 12,
    borderRadius: 10,
    backgroundColor: '#1E88E5',
    alignItems: 'center',
    justifyContent: 'center',
  },
  newsletterButtonDisabled: {
    backgroundColor: '#90CAF9',
  },
  newsletterButtonText: {
    color: '#fff',
    fontWeight: '700',
    fontSize: 14,
  },
  newsletterErrorText: {
    marginTop: 8,
    color: '#D32F2F',
    fontSize: 12,
  },
  newsletterSuccessText: {
    marginTop: 8,
    color: '#2E7D32',
    fontSize: 12,
  },
  newsletterFinePrint: {
    marginTop: 8,
    color: '#607D8B',
    fontSize: 11,
  },
  errorText: {
    color: '#f44336',
    textAlign: 'center',
    marginTop: 16,
    marginBottom: 16,
  },
  retryButton: {
    backgroundColor: '#2196F3',
    padding: 12,
    borderRadius: 8,
  },
  retryButtonText: {
    color: '#fff',
    fontWeight: '600',
  },
  fab: {
    position: 'absolute',
    right: 16,
    bottom: 16,
    width: 56,
    height: 56,
    borderRadius: 28,
    backgroundColor: '#2196F3',
    justifyContent: 'center',
    alignItems: 'center',
    elevation: 4,
    ...(Platform.OS === 'web'
      ? {
          boxShadow: '0px 2px 3.84px rgba(0,0,0,0.25)',
        }
      : {
          shadowColor: '#000',
          shadowOffset: {width: 0, height: 2},
          shadowOpacity: 0.25,
          shadowRadius: 3.84,
        }),
  },
  fabDisabled: {
    backgroundColor: '#9E9E9E',
  },
});

export default TufeHomePage;

