import React, {useState, useEffect} from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  ActivityIndicator,
  useWindowDimensions,
} from 'react-native';
import WebPicker from '../components/WebPicker';
import {MaterialIcons as Icon} from '@expo/vector-icons';
import LineChartWithHover from '../components/LineChartWithHover';
import {GruplarService} from '../services/GruplarService';
import {TuikService} from '../services/TuikService';

const AnaGruplarPage = () => {
  const {width: windowWidth} = useWindowDimensions();
  const [isLoading, setIsLoading] = useState(true);
  const [selectedGrup, setSelectedGrup] = useState('');
  const [availableGruplar, setAvailableGruplar] = useState<string[]>([]);
  const [grupIndexData, setGrupIndexData] = useState<number[]>([]);
  const [grupMonthlyChangeData, setGrupMonthlyChangeData] = useState<number[]>([]);
  const [indexDates, setIndexDates] = useState<string[]>([]);
  const [monthlyDates, setMonthlyDates] = useState<string[]>([]);
  const [mainChartData, setMainChartData] = useState<any>(null);
  const [monthlyChartData, setMonthlyChartData] = useState<any>(null);
  const [yearToDateChange, setYearToDateChange] = useState(0);
  const [monthlyChange, setMonthlyChange] = useState(0);

  // Tarihi yıl-ay formatına çevir (DD.MM.YYYY -> YYYY-MM)
  const formatDateToYearMonth = (dateStr: string): string => {
    if (!dateStr) return '';
    const parts = dateStr.split('.');
    if (parts.length === 3) {
      const day = parts[0];
      const month = parts[1];
      const year = parts[2];
      return `${year}-${month}`;
    }
    return dateStr;
  };

  useEffect(() => {
    loadData();
  }, []);

  useEffect(() => {
    if (selectedGrup) {
      loadGrupData(selectedGrup);
    }
  }, [selectedGrup]);

  const loadData = async () => {
    try {
      const gruplarList = await GruplarService.getGrupNames();

      setAvailableGruplar(gruplarList);
      if (gruplarList.length > 0) {
        setSelectedGrup(gruplarList[0]);
      }
      setIsLoading(false);
    } catch (e) {
      console.log('Error loading data:', e);
      setIsLoading(false);
    }
  };

  const loadGrupData = async (grupName: string) => {
    try {
      const indexData = await GruplarService.getGrupIndexData(grupName);
      const monthlyData = await GruplarService.getGrupMonthlyChangeData(grupName);
      const dates = await GruplarService.getIndexDates();
      const monthlyDatesList = await GruplarService.getMonthlyDates();

      setGrupIndexData(indexData);
      setGrupMonthlyChangeData(monthlyData);
      setIndexDates(dates);
      setMonthlyDates(monthlyDatesList);

      updateChartData(indexData, monthlyData, dates, monthlyDatesList);
      
      // Yıllık değişimi CSV'den oku
      try {
        const yearlyChange = await GruplarService.getYearlyChange(grupName);
        setYearToDateChange(yearlyChange);
      } catch (e) {
        console.log('Yıllık değişim okuma hatası:', e);
        // Fallback: eski mantık
        setYearToDateChange(indexData.length > 0 ? indexData[indexData.length - 1] - 100.0 : 0);
      }
      
      setMonthlyChange(monthlyData.length > 0 ? monthlyData[monthlyData.length - 1] : 0);
    } catch (e) {
      console.log('Error loading grup data:', e);
    }
  };

  const updateChartData = async (
    indexData: number[],
    monthlyData: number[],
    dates: string[],
    monthlyDatesList: string[]
  ) => {
    try {
      // Ana endeks grafiği
      if (indexData.length > 0) {
        const comparedData = await getComparedIndexChartData(indexData, dates);
        if (Object.keys(comparedData).length > 0) {
          const webData = comparedData['Web TÜFE'] || [];
          const tuikData = comparedData['TÜİK TÜFE'] || [];
          const hasTuikData = tuikData.some((d) => d.y !== null && d.y !== undefined);
          const tuikSeries = dates.map((_, idx) => {
            const point = tuikData.find((d) => d.x === idx);
            return point ? point.y : null;
          });

          // Tarihleri YYYY-MM formatına çevir
          const formattedDates = dates.map(formatDateToYearMonth);

          setMainChartData({
            labels: formattedDates.map((_, i) => (i % Math.ceil(formattedDates.length / 5) === 0 ? formattedDates[i] : '')),
            datasets: [
              {
                data: webData.map((d) => d.y),
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
          // Tarihleri YYYY-MM formatına çevir
          const formattedDates = dates.map(formatDateToYearMonth);

          setMainChartData({
            labels: formattedDates.map((_, i) => (i % Math.ceil(formattedDates.length / 5) === 0 ? formattedDates[i] : '')),
            datasets: [
              {
                data: indexData,
                color: () => `rgba(25, 118, 210, 1)`,
                strokeWidth: 3,
              },
            ],
          });
        }
      }

      // Aylık değişim grafiği
      if (monthlyData.length > 0) {
        const comparedMonthly = await getComparedMonthlyChangeChartData(monthlyData, monthlyDatesList);
        if (Object.keys(comparedMonthly).length > 0) {
          const webMonthly = comparedMonthly['Web TÜFE'] || [];
          const tuikMonthly = comparedMonthly['TÜİK TÜFE'] || [];
          const hasTuikMonthly = tuikMonthly.some((d) => d.y !== null && d.y !== undefined);
          const tuikMonthlySeries = monthlyDatesList.map((_, idx) => {
            const point = tuikMonthly.find((d) => d.x === idx);
            return point ? point.y : null;
          });

          // Tarihleri YYYY-MM formatına çevir
          const formattedMonthlyDates = monthlyDatesList.map(formatDateToYearMonth);

          setMonthlyChartData({
            labels: formattedMonthlyDates.map((_, i) => (i % Math.ceil(formattedMonthlyDates.length / 5) === 0 ? formattedMonthlyDates[i] : '')),
            datasets: [
              {
                data: webMonthly.map((d) => d.y),
                color: () => `rgba(25, 118, 210, 1)`,
                strokeWidth: 3,
              },
              {
                data: tuikMonthlySeries,
                color: () => `rgba(211, 47, 47, 1)`,
                strokeWidth: 3,
              },
            ],
            legend: ['Web TÜFE', hasTuikMonthly ? 'TÜİK TÜFE' : 'TÜİK TÜFE (boş)'],
          });
        } else {
          // Tarihleri YYYY-MM formatına çevir
          const formattedMonthlyDates = monthlyDatesList.map(formatDateToYearMonth);

          setMonthlyChartData({
            labels: formattedMonthlyDates.map((_, i) => (i % Math.ceil(formattedMonthlyDates.length / 5) === 0 ? formattedMonthlyDates[i] : '')),
            datasets: [
              {
                data: monthlyData,
                color: () => `rgba(25, 118, 210, 1)`,
                strokeWidth: 3,
              },
            ],
          });
        }
      }
    } catch (e) {
      console.log('Error updating chart data:', e);
    }
  };

  const getComparedIndexChartData = async (
    webIndexData: number[],
    webDates: string[]
  ): Promise<{[key: string]: Array<{x: number; y: number}>}> => {
    if (!selectedGrup) return {};

    try {
      const tuikData = await TuikService.loadTuikAnaGrupEndeksData(selectedGrup);

      const result: {[key: string]: Array<{x: number; y: number}>} = {};

      if (webIndexData.length > 0) {
        result['Web TÜFE'] = webIndexData.map((value, index) => ({
          x: index,
          y: value,
        }));
      }

      if (tuikData.data[`TÜİK ${selectedGrup}`]) {
        const tuikValues = tuikData.data[`TÜİK ${selectedGrup}`] as number[];
        const tuikDates = tuikData.dates as string[];

        const tuikSeries: Array<{x: number; y: number | null}> = webDates.map(
          (_, idx) => ({x: idx, y: null})
        );

        for (let tuikIndex = 0; tuikIndex < tuikDates.length; tuikIndex++) {
          const tuikDate = tuikDates[tuikIndex];
          const tuikValue = tuikValues[tuikIndex];

          if (isNaN(tuikValue)) continue;

          try {
            const tuikYearMonth = parseDateToYearMonth(tuikDate);
            if (!tuikYearMonth) continue;

            // Web günlük tarihlerde aynı ayın son gün index'ini bul
            let lastDayIndex = -1;
            for (let webIndex = webDates.length - 1; webIndex >= 0; webIndex--) {
              const webYearMonth = parseDateToYearMonth(webDates[webIndex]);
              if (webYearMonth === tuikYearMonth) {
                lastDayIndex = webIndex;
                break;
              }
            }

            if (lastDayIndex !== -1) {
              tuikSeries[lastDayIndex] = {x: lastDayIndex, y: tuikValue};
            }
          } catch (e) {
            console.log('Tarih eşleştirme hatası:', e);
          }
        }

        // Noktaları bir sonraki noktanın öncesine kadar uzat; son nokta sonuna kadar devam etsin
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
      console.log('Karşılaştırmalı ana grup endeks veri yükleme hatası:', e);
      return {};
    }
  };

  const getComparedMonthlyChangeChartData = async (
    webMonthlyData: number[],
    webDates: string[]
  ): Promise<{[key: string]: Array<{x: number; y: number}>}> => {
    if (!selectedGrup) return {};

    try {
      const tuikData = await TuikService.loadTuikAnaGrupData(selectedGrup);

      const result: {[key: string]: Array<{x: number; y: number}>} = {};
      const tuikDates = tuikData.dates as string[];

      if (webMonthlyData.length > 0) {
        result['Web TÜFE'] = webMonthlyData.map((value, index) => ({
          x: index,
          y: value,
        }));
      }

      if (tuikData.data[`TÜİK ${selectedGrup}`]) {
        const values = tuikData.data[`TÜİK ${selectedGrup}`] as number[];
        const tuikSeries: Array<{x: number; y: number | null}> = webDates.map(
          (_, idx) => ({x: idx, y: null})
        );

        for (let i = 0; i < webDates.length; i++) {
          const webDateStr = webDates[i];
          const yearMonth = parseDateToYearMonth(webDateStr);

          if (yearMonth) {
            let tuikIndex = -1;
            for (let j = 0; j < tuikDates.length; j++) {
              const tuikYearMonth = parseDateToYearMonth(tuikDates[j]);
              if (tuikYearMonth === yearMonth) {
                tuikIndex = j;
                break;
              }
            }

            if (tuikIndex !== -1 && tuikIndex < values.length) {
              const value = values[tuikIndex];
              if (!isNaN(value)) {
                tuikSeries[i] = {x: i, y: value};
              }
            }
          }
        }

        // Nokta -> bir sonraki öncesine kadar uzat; son noktadan sonrası boş kalsın
        const tuikSpots = tuikSeries.filter((s) => s.y !== null && s.y !== undefined);
        tuikSpots.sort((a, b) => a.x - b.x);
        for (let i = 0; i < tuikSpots.length; i++) {
          const currentSpot = tuikSpots[i];
          const nextSpot = i < tuikSpots.length - 1 ? tuikSpots[i + 1] : null;
          const endX = nextSpot ? nextSpot.x - 1 : currentSpot.x;
          for (let x = currentSpot.x; x <= endX && x < tuikSeries.length; x++) {
            tuikSeries[x].y = currentSpot.y;
          }
        }

        result['TÜİK TÜFE'] = tuikSeries;
      }

      return result;
    } catch (e) {
      console.log('Karşılaştırmalı aylık veri yükleme hatası:', e);
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
        <Text style={styles.sectionTitle}>Ana Gruplar</Text>
        <View style={styles.pickerContainer}>
          <WebPicker
            selectedValue={selectedGrup}
            onValueChange={(itemValue) => setSelectedGrup(itemValue)}
            style={styles.picker}>
            {availableGruplar.map((grup) => (
              <WebPicker.Item key={grup} label={grup} value={grup} />
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
          <Text style={styles.chartTitle}>{selectedGrup} Endeksi</Text>
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
            horizontalLabelRotation={45}
            style={styles.chart}
            dates={indexDates.map(formatDateToYearMonth)}
            labels={mainChartData?.labels}
            selectedEndeks={selectedGrup}
          />
        </View>
      )}

      {monthlyChartData && (
        <View style={styles.chartSection}>
          <Text style={styles.chartTitle}>Aylık Değişim Oranları</Text>
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
            horizontalLabelRotation={45}
            style={styles.chart}
            dates={monthlyDates.map(formatDateToYearMonth)}
            labels={monthlyChartData?.labels}
            selectedEndeks={selectedGrup}
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

export default AnaGruplarPage;
