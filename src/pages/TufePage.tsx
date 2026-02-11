import React, {useState, useEffect} from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  ActivityIndicator,
  useWindowDimensions,
} from 'react-native';
import {MaterialIcons as Icon} from '@expo/vector-icons';
import WebPicker from '../components/WebPicker';
import LineChartWithHover from '../components/LineChartWithHover';
import {EndekslerService} from '../services/EndekslerService';
import {GruplarService} from '../services/GruplarService';
import {TuikService} from '../services/TuikService';
import {MaddelerService} from '../services/MaddelerService';

const TufePage = () => {
  const {width: windowWidth} = useWindowDimensions();
  const [isLoading, setIsLoading] = useState(true);
  const [selectedEndeks, setSelectedEndeks] = useState('');
  const [availableEndeks, setAvailableEndeks] = useState<string[]>([]);
  const [yearToDateChange, setYearToDateChange] = useState(0);
  const [monthlyChange, setMonthlyChange] = useState(0);
  const [mainChartData, setMainChartData] = useState<any>(null);
  const [endekslerData, setEndekslerData] = useState<{[key: string]: number[]}>({});
  const [dates, setDates] = useState<string[]>([]);
  const [tufeValues, setTufeValues] = useState<number[]>([]);
  const [tufeDates, setTufeDates] = useState<string[]>([]);
  const [monthlyChartData, setMonthlyChartData] = useState<any>(null);
  const [monthlyDates, setMonthlyDates] = useState<string[]>([]);

  useEffect(() => {
    loadData();
  }, []);

  useEffect(() => {
    if (!selectedEndeks) return;

    // Endeks değiştiğinde önce grafikleri temizle
    setMainChartData(null);

    // Kısa bir delay ile güncelle (state güncellemesinin tamamlanması için)
    const timeoutId = setTimeout(() => {
      if (!selectedEndeks) return;

      if (selectedEndeks === 'Web TÜFE') {
        // Web TÜFE için veriler yüklenmiş mi kontrol et
        if (tufeValues.length === 0 || tufeDates.length === 0) {
          // Veriler yüklenmemişse yükle
          loadTufeData();
        } else {
          // Veriler zaten yüklenmişse direkt grafiği güncelle
          updateChartData();
        }
      } else {
        // Diğer endeksler için veriler yüklenmiş mi kontrol et
        if (dates.length > 0 && endekslerData[selectedEndeks]) {
          updateChartData();
        }
      }
    }, 100);

    return () => {
      clearTimeout(timeoutId);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selectedEndeks]);

  // Web TÜFE verileri yüklendiğinde grafiği güncelle
  useEffect(() => {
    if (selectedEndeks === 'Web TÜFE' && tufeValues.length > 0 && tufeDates.length > 0) {
      updateChartData();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selectedEndeks, tufeValues.length, tufeDates.length]);

  // endekslerData yüklendiğinde diğer endeksler için grafiği güncelle
  useEffect(() => {
    if (selectedEndeks && selectedEndeks !== 'Web TÜFE' && dates.length > 0 && endekslerData[selectedEndeks]) {
      updateChartData();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selectedEndeks, dates.length, Object.keys(endekslerData).length]);

  const loadData = async () => {
    try {
      const endeksData = await EndekslerService.loadEndekslerData();
      const endeksList = await EndekslerService.getEndeksList();

      setEndekslerData(endeksData.data);
      setDates(endeksData.dates);
      setAvailableEndeks(endeksList);
      if (endeksList.length > 0) {
        const firstEndeks = endeksList[0];
        // İlk endeks Web TÜFE ise önce veriyi yükle, sonra endeksi set et
        if (firstEndeks === 'Web TÜFE') {
          await loadTufeData();
          setSelectedEndeks(firstEndeks);
          // useEffect otomatik olarak updateChartData() çağıracak
        } else {
          setSelectedEndeks(firstEndeks);
          // Veriler yüklendi, grafiği güncelle
          setTimeout(() => {
            updateChartData();
          }, 0);
        }
      }
      setIsLoading(false);
    } catch (e) {
      console.log('Error loading data:', e);
      setIsLoading(false);
    }
  };

  const loadTufeData = async () => {
    try {
      const tufeData = await EndekslerService.loadTufeData();

      setTufeValues(tufeData.data['Web TÜFE'] || []);
      setTufeDates(tufeData.dates);
      // updateChartData() artık useEffect'te çağrılıyor, burada çağırma
    } catch (e) {
      console.log('Error loading Web TÜFE data:', e);
    }
  };

  const getYearToDateChange = async (): Promise<number> => {
    if (!selectedEndeks) return 0.0;

    try {
      if (selectedEndeks === 'Web TÜFE') {
        // Web TÜFE için EndekslerService'den oku
        const yearlyChange = await EndekslerService.getYearlyChange(selectedEndeks);
        return yearlyChange;
      } else {
        // Web TÜFE dışındaki maddeler için maddeleryıllık.csv'den oku
        const yearlyChange = await MaddelerService.getMaddeYearlyChange(selectedEndeks);
        return yearlyChange;
      }
    } catch (e) {
      console.log('Yıllık değişim okuma hatası:', e);
      // Fallback: eski mantık
      if (selectedEndeks === 'Web TÜFE') {
        if (tufeValues.length === 0) return 0.0;
        return tufeValues[tufeValues.length - 1] - 100.0;
      }

      if (!endekslerData[selectedEndeks]) {
        return 0.0;
      }

      const values = endekslerData[selectedEndeks];
      if (values.length === 0) return 0.0;

      return values[values.length - 1] - 100.0;
    }
  };

  const updateChartData = async () => {
    if (!selectedEndeks) return;

    const currentEndeks = selectedEndeks;

    try {
      if (currentEndeks === 'Web TÜFE') {
        // Web TÜFE verileri yüklenmiş mi kontrol et
        if (tufeValues.length === 0 || tufeDates.length === 0) {
          return;
        }

        const comparedData = await getComparedEndeksChartData();
        if (selectedEndeks !== currentEndeks) return;

        const webTufeData = comparedData['Web TÜFE'] || [];
        const tuikData = comparedData['TÜİK TÜFE'] || [];

        if (webTufeData.length > 0 && tufeDates.length > 0) {
          const hasTuikData = tuikData.some(
            d => d.y !== null && d.y !== undefined,
          );
          const tuikSeries = tufeDates.map((_, idx) => {
            const point = tuikData.find(d => d.x === idx);
            return point ? point.y : null;
          });

          const formattedDates = tufeDates.map(formatDateToYearMonth);

          setMainChartData({
            labels: formattedDates.map((_, i) =>
              i % Math.ceil(formattedDates.length / 5) === 0
                ? formattedDates[i]
                : '',
            ),
            datasets: [
              {
                data: webTufeData.map(d => d.y),
                color: () => `rgba(25, 118, 210, 1)`,
                strokeWidth: 3,
              },
              {
                data: tuikSeries,
                color: () => `rgba(211, 47, 47, 1)`,
                strokeWidth: 3,
              },
            ],
            legend: ['Web TÜFE', hasTuikData ? 'TÜİK TÜFE' : 'TÜİK TÜFE (boş)'],
          });
        } else {
          setMainChartData(null);
        }
      } else {
        // Diğer endeksler için tekli grafik
        if (selectedEndeks !== currentEndeks) return;
        if (dates.length === 0 || !endekslerData[currentEndeks]) return;

        const values = endekslerData[currentEndeks] || [];
        if (values.length > 0 && dates.length > 0) {
          const endeksFormattedDates = dates.map(formatDateToYearMonth);

          setMainChartData({
            labels: endeksFormattedDates.map((_, i) =>
              i % Math.ceil(endeksFormattedDates.length / 5) === 0
                ? endeksFormattedDates[i]
                : '',
            ),
            datasets: [
              {
                data: values,
                color: () => `rgba(25, 118, 210, 1)`,
                strokeWidth: 3,
              },
            ],
          });
        } else {
          setMainChartData(null);
        }
      }

      // İstatistikleri güncelle
      const yearlyChange = await getYearToDateChange();
      setYearToDateChange(yearlyChange);

      try {
        const monthlyArray = await GruplarService.getGrupMonthlyChangeData(
          selectedEndeks,
        );
        const lastMonthly =
          monthlyArray.length > 0
            ? monthlyArray[monthlyArray.length - 1]
            : 0.0;
        setMonthlyChange(lastMonthly);
      } catch (e) {
        console.log('Aylık değişim okuma hatası:', e);
        setMonthlyChange(0.0);
      }

      // Aylık değişim grafiği verilerini yükle
      await updateMonthlyChartData();
    } catch (e) {
      console.log('Error updating chart data:', e);
    }
  };

  const updateMonthlyChartData = async () => {
    if (!selectedEndeks) return;

    try {
      if (selectedEndeks === 'Web TÜFE') {
        // Web TÜFE için gruplaraylıkv2.csv'den Web TÜFE ve tuikaylik.csv'den TÜFE oku
        const webTufeMonthly = await GruplarService.getGrupMonthlyChangeData('Web TÜFE');
        const webTufeMonthlyDates = await GruplarService.getMonthlyDates();
        const tuikMonthly = await TuikService.loadTuikMonthlyChangeData();

        if (webTufeMonthly.length > 0 && webTufeMonthlyDates.length > 0) {
          const formattedDates = webTufeMonthlyDates.map(formatDateToYearMonth);
          
          // TÜİK verilerini Web TÜFE tarihlerine göre eşleştir
          const tuikValues: (number | null)[] = webTufeMonthlyDates.map(() => null);
          
          if (tuikMonthly.dates.length > 0 && tuikMonthly.data['TÜİK TÜFE']) {
            const tuikDates = tuikMonthly.dates;
            const tuikData = tuikMonthly.data['TÜİK TÜFE'];
            
            for (let i = 0; i < webTufeMonthlyDates.length; i++) {
              const webDate = formatDateToYearMonth(webTufeMonthlyDates[i]);
              const tuikIndex = tuikDates.findIndex(d => formatDateToYearMonth(d) === webDate);
              if (tuikIndex !== -1 && tuikIndex < tuikData.length) {
                tuikValues[i] = tuikData[tuikIndex];
              }
            }
          }

          const hasTuikData = tuikValues.some(v => v !== null && v !== undefined);

          setMonthlyDates(webTufeMonthlyDates);
          setMonthlyChartData({
            labels: formattedDates.map((_, i) =>
              i % Math.ceil(formattedDates.length / 5) === 0
                ? formattedDates[i]
                : '',
            ),
            datasets: [
              {
                data: webTufeMonthly.map(v => v),
                color: () => `rgba(25, 118, 210, 1)`,
                strokeWidth: 3,
              },
              ...(hasTuikData ? [{
                // Null değerleri null olarak bırak ki grafik boş bıraksın
                data: tuikValues,
                color: () => `rgba(211, 47, 47, 1)`,
                strokeWidth: 3,
              }] : []),
            ],
            legend: hasTuikData ? ['Web TÜFE', 'TÜİK TÜFE'] : ['Web TÜFE'],
          });
        } else {
          setMonthlyChartData(null);
        }
      } else {
        // Diğer maddeler için maddeleraylık.csv'den oku
        const maddeMonthly = await MaddelerService.getMaddeMonthlyChangeData(selectedEndeks);
        
        if (maddeMonthly.values.length > 0 && maddeMonthly.dates.length > 0) {
          const formattedDates = maddeMonthly.dates.map(formatDateToYearMonth);
          
          setMonthlyDates(maddeMonthly.dates);
          setMonthlyChartData({
            labels: formattedDates.map((_, i) =>
              i % Math.ceil(formattedDates.length / 5) === 0
                ? formattedDates[i]
                : '',
            ),
            datasets: [
              {
                data: maddeMonthly.values,
                color: () => `rgba(25, 118, 210, 1)`,
                strokeWidth: 3,
              },
            ],
          });
        } else {
          setMonthlyChartData(null);
        }
      }
    } catch (e) {
      console.log('Aylık değişim grafiği veri yükleme hatası:', e);
      setMonthlyChartData(null);
    }
  };

  const getComparedEndeksChartData = async (): Promise<{[key: string]: Array<{x: number; y: number | null}>}> => {
    if (selectedEndeks !== 'Web TÜFE') return {};

    try {
      const tuikData = await TuikService.loadTuikEndeksData();
      const result: {[key: string]: Array<{x: number; y: number | null}>} = {};

      if (tufeValues.length > 0) {
        result['Web TÜFE'] = tufeValues.map((value, index) => ({
          x: index,
          y: value,
        }));
      }

      if (tuikData.data['TÜİK TÜFE']) {
        const tuikValues = tuikData.data['TÜİK TÜFE'] as number[];
        const tuikDates = tuikData.dates as string[];

        const tuikSeries: Array<{x: number; y: number | null}> = tufeDates.map(
          (_, idx) => ({x: idx, y: null})
        );

        for (let tuikIndex = 0; tuikIndex < tuikDates.length; tuikIndex++) {
          const tuikDate = tuikDates[tuikIndex];
          const tuikValue = tuikValues[tuikIndex];

          if (isNaN(tuikValue)) continue;

          try {
            const tuikDateParts = tuikDate.split('.');
            if (tuikDateParts.length === 3) {
              const tuikMonth = tuikDateParts[1];
              const tuikYear = tuikDateParts[2];

              let lastDayIndex = -1;
              for (let webIndex = tufeDates.length - 1; webIndex >= 0; webIndex--) {
                const webDate = tufeDates[webIndex];
                const webDateParts = webDate.split('.');
                if (webDateParts.length === 3) {
                  const webMonth = webDateParts[1];
                  const webYear = webDateParts[2];

                  if (webMonth === tuikMonth && webYear === tuikYear) {
                    lastDayIndex = webIndex;
                    break;
                  }
                }
              }

              if (lastDayIndex !== -1) {
                tuikSeries[lastDayIndex] = {x: lastDayIndex, y: tuikValue};
              }
            }
          } catch (e) {
            console.log('Tarih eşleştirme hatası:', e);
          }
        }

        // Nokta -> bir sonraki noktanın öncesine kadar uzat; son noktadan sonrası son değerle devam etsin
        const tuikSpots = tuikSeries.filter((s) => s.y !== null && s.y !== undefined);
        tuikSpots.sort((a, b) => a.x - b.x);
        for (let i = 0; i < tuikSpots.length; i++) {
          const currentSpot = tuikSpots[i];
          const nextSpot = i < tuikSpots.length - 1 ? tuikSpots[i + 1] : null;
          const endX = nextSpot ? nextSpot.x - 1 : tuikSeries.length - 1;
          for (let x = currentSpot.x; x <= endX && x < tuikSeries.length; x++) {
            tuikSeries[x].y = currentSpot.y;
          }
        }

        result['TÜİK TÜFE'] = tuikSeries;
      }

      return result;
    } catch (e) {
      console.log('Karşılaştırmalı endeks veri yükleme hatası:', e);
      return {};
    }
  };

  const parseDateToYearMonth = (dateStr: string): string | null => {
    try {
      if (dateStr.includes('.')) {
        const parts = dateStr.split('.');
        if (parts.length === 3) {
          return `${parts[2]}-${parts[1].padStart(2, '0')}`;
        }
      } else if (dateStr.includes(' ')) {
        const parts = dateStr.split(' ');
        if (parts.length === 2) {
          const monthStr = parts[0];
          const year = parts[1];
          const monthMap: {[key: string]: string} = {
            'Oca': '01', 'Ocak': '01',
            'Şub': '02', 'Şubat': '02',
            'Mar': '03', 'Mart': '03',
            'Nis': '04', 'Nisan': '04',
            'May': '05', 'Mayıs': '05',
            'Haz': '06', 'Haziran': '06',
            'Tem': '07', 'Temmuz': '07',
            'Ağu': '08', 'Ağustos': '08',
            'Eyl': '09', 'Eylül': '09',
            'Eki': '10', 'Ekim': '10',
            'Kas': '11', 'Kasım': '11',
            'Ara': '12', 'Aralık': '12',
          };
          const month = monthMap[monthStr];
          if (month) {
            return `${year}-${month}`;
          }
        }
      } else if (dateStr.includes('-')) {
        const parts = dateStr.split('-');
        if (parts.length >= 2) {
          return `${parts[0]}-${parts[1].padStart(2, '0')}`;
        }
      }
    } catch (e) {
      console.log('Tarih parse hatası:', dateStr, e);
    }
    return null;
  };

  const getCurrentDate = () => {
    const now = new Date();
    const day = now.getDate().toString().padStart(2, '0');
    const month = (now.getMonth() + 1).toString().padStart(2, '0');
    const year = now.getFullYear().toString();
    return `${day}.${month}.${year}`;
  };

  // Tarihi yıl-ay formatına çevir (DD.MM.YYYY -> YYYY-MM veya "Oca 2025" -> "2025-01")
  const formatDateToYearMonth = (dateStr: string): string => {
    if (!dateStr) return '';
    
    // "Oca 2025" formatı
    if (dateStr.includes(' ')) {
      const parts = dateStr.split(' ');
      if (parts.length === 2) {
        const monthStr = parts[0];
        const year = parts[1];
        const monthMap: {[key: string]: string} = {
          'Oca': '01', 'Ocak': '01',
          'Şub': '02', 'Şubat': '02',
          'Mar': '03', 'Mart': '03',
          'Nis': '04', 'Nisan': '04',
          'May': '05', 'Mayıs': '05',
          'Haz': '06', 'Haziran': '06',
          'Tem': '07', 'Temmuz': '07',
          'Ağu': '08', 'Ağustos': '08',
          'Eyl': '09', 'Eylül': '09',
          'Eki': '10', 'Ekim': '10',
          'Kas': '11', 'Kasım': '11',
          'Ara': '12', 'Aralık': '12',
        };
        const month = monthMap[monthStr];
        if (month) {
          return `${year}-${month}`;
        }
      }
    }
    
    // DD.MM.YYYY formatı
    const parts = dateStr.split('.');
    if (parts.length === 3) {
      const day = parts[0];
      const month = parts[1];
      const year = parts[2];
      return `${year}-${month}`;
    }
    
    // YYYY-MM-DD formatı
    if (dateStr.includes('-')) {
      const parts = dateStr.split('-');
      if (parts.length >= 2) {
        return `${parts[0]}-${parts[1].padStart(2, '0')}`;
      }
    }
    
    return dateStr;
  };

  if (isLoading) {
    return (
      <View style={styles.centerContainer}>
        <ActivityIndicator size="large" color="#2196F3" />
      </View>
    );
  }

  const chartConfig = {
    backgroundColor: '#ffffff',
    backgroundGradientFrom: '#ffffff',
    backgroundGradientTo: '#ffffff',
    decimalPlaces: 2,
    color: () => `rgba(25, 118, 210, 1)`,
    labelColor: (opacity = 1) => `rgba(0, 0, 0, ${opacity})`,
    style: {
      borderRadius: 16,
    },
    propsForDots: {
      r: '0',
      strokeWidth: '0',
    },
    propsForBackgroundLines: {
      strokeWidth: 0,
    },
  };

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <View style={styles.topSection}>
        <Text style={styles.sectionTitle}>Web TÜFE Endeksleri</Text>
        <View style={styles.pickerContainer}>
          <WebPicker
            selectedValue={selectedEndeks}
            onValueChange={(itemValue) => {
              setSelectedEndeks(itemValue);
            }}
            style={styles.picker}>
            {availableEndeks.map((endeks) => (
              <WebPicker.Item key={endeks} label={endeks} value={endeks} />
            ))}
          </WebPicker>
        </View>
        <View style={styles.statsContainer}>
          <View style={styles.statCard}>
            <View style={styles.statHeader}>
              <Icon name="trending-up" size={20} color="#FF9800" />
              <Text style={styles.statTitle}>Yıllık Değişim</Text>
            </View>
            <Text style={[styles.statValue, {color: '#FF9800'}]}>
              {yearToDateChange.toFixed(2)}%
            </Text>
          </View>
          <View style={styles.statCard}>
            <View style={styles.statHeader}>
              <Icon name="calendar-month" size={20} color="#4CAF50" />
              <Text style={styles.statTitle}>Aylık Değişim</Text>
            </View>
            <Text style={[styles.statValue, {color: '#4CAF50'}]}>
              {monthlyChange.toFixed(2)}%
            </Text>
          </View>
        </View>
        <Text style={styles.dateText}>01.01.2025-{getCurrentDate()}</Text>
      </View>

      {mainChartData && (
        <View style={styles.chartSection}>
          <Text style={styles.chartTitle}>
            {selectedEndeks === 'Web TÜFE'
              ? 'Web Tüketici Fiyat Endeksi'
              : `${selectedEndeks} Endeksi`}
          </Text>
          {mainChartData.legend && mainChartData.legend.length > 1 && (
            <View style={styles.legend}>
              <View style={styles.legendItem}>
                <View style={[styles.legendLine, {backgroundColor: '#2196F3'}]} />
                <Text style={styles.legendText}>Web TÜFE</Text>
              </View>
              <View style={styles.legendItem}>
                <View style={[styles.legendLine, {backgroundColor: '#f44336'}]} />
                <Text style={styles.legendText}>TÜİK TÜFE</Text>
              </View>
            </View>
          )}
          <LineChartWithHover
            data={mainChartData}
            width={Math.max(0, windowWidth - 32)}
            height={220}
            chartConfig={chartConfig}
            withDots={false}
            bezier
            style={styles.chart}
            dates={(selectedEndeks === 'Web TÜFE' ? tufeDates : dates).map(
              formatDateToYearMonth,
            )}
            labels={mainChartData?.labels}
            selectedEndeks={selectedEndeks}
          />
        </View>
      )}

      {monthlyChartData && (
        <View style={styles.chartSection}>
          <Text style={styles.chartTitle}>Aylık Değişim Oranları (%)</Text>
          {monthlyChartData.legend && monthlyChartData.legend.length > 1 && (
            <View style={styles.legend}>
              <View style={styles.legendItem}>
                <View style={[styles.legendLine, {backgroundColor: '#2196F3'}]} />
                <Text style={styles.legendText}>Web TÜFE</Text>
              </View>
              <View style={styles.legendItem}>
                <View style={[styles.legendLine, {backgroundColor: '#f44336'}]} />
                <Text style={styles.legendText}>TÜİK TÜFE</Text>
              </View>
            </View>
          )}
          <LineChartWithHover
            data={monthlyChartData}
            width={Math.max(0, windowWidth - 32)}
            height={220}
            chartConfig={{
              ...chartConfig,
              color: () => `rgba(25, 118, 210, 1)`,
            }}
            withDots={false}
            bezier={false}
            style={styles.chart}
            dates={monthlyDates.map(formatDateToYearMonth)}
            labels={monthlyChartData?.labels}
            selectedEndeks={selectedEndeks}
          />
        </View>
      )}
    </ScrollView>
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
  },
  content: {
    padding: 16,
  },
  topSection: {
    padding: 16,
    backgroundColor: '#E3F2FD',
    borderRadius: 12,
    marginBottom: 24,
  },
  sectionTitle: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#1565C0',
    marginBottom: 8,
  },
  pickerContainer: {
    backgroundColor: '#fff',
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#BDBDBD',
    marginBottom: 16,
  },
  picker: {
    height: 50,
  },
  statsContainer: {
    flexDirection: 'row',
    gap: 16,
    marginBottom: 8,
  },
  statCard: {
    flex: 1,
    padding: 16,
    backgroundColor: '#fff',
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#E0E0E0',
  },
  statHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 8,
  },
  statTitle: {
    fontSize: 12,
    fontWeight: '600',
    color: '#424242',
    marginLeft: 8,
    flex: 1,
  },
  statValue: {
    fontSize: 18,
    fontWeight: 'bold',
  },
  dateText: {
    fontSize: 14,
    color: '#757575',
    fontStyle: 'italic',
  },
  chartSection: {
    marginBottom: 24,
  },
  chartTitle: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#1565C0',
    marginBottom: 16,
  },
  legend: {
    flexDirection: 'row',
    justifyContent: 'center',
    marginBottom: 16,
    gap: 20,
  },
  legendItem: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  legendLine: {
    width: 16,
    height: 3,
    marginRight: 8,
  },
  legendText: {
    fontSize: 12,
    color: '#212121',
  },
  chart: {
    marginVertical: 8,
    borderRadius: 16,
  },
});

export default TufePage;
