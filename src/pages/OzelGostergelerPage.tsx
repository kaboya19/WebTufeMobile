import React, {useState, useEffect} from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  ActivityIndicator,
  Dimensions,
} from 'react-native';
import WebPicker from '../components/WebPicker';
import {MaterialIcons as Icon} from '@expo/vector-icons';
import LineChartWithHover from '../components/LineChartWithHover';
import {OzelGostergelerService} from '../services/OzelGostergelerService';
import {TuikService} from '../services/TuikService';
import {OzelGostergeData} from '../models/OzelGostergeData';

const initialScreenWidth = Dimensions.get('window').width;

const OzelGostergelerPage = () => {
  const [isLoadingIndicators, setIsLoadingIndicators] = useState(true);
  const [isLoadingData, setIsLoadingData] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const [availableIndicators, setAvailableIndicators] = useState<string[]>([]);
  const [selectedIndicator, setSelectedIndicator] = useState<string | null>(null);
  const [indicatorData, setIndicatorData] = useState<OzelGostergeData | null>(null);

  const [endeksChartData, setEndeksChartData] = useState<any>(null);
  const [monthlyChartData, setMonthlyChartData] = useState<any>(null);
  const [contentWidth, setContentWidth] = useState<number>(initialScreenWidth);
  const [yearlyChange, setYearlyChange] = useState<number>(0);
  const INDEX_BASELINE = 100;

  // Tarihi yıl-ay formatına çevir (DD.MM.YYYY veya YYYY-MM-DD -> YYYY-MM)
  const formatDateToYearMonth = (dateStr: string): string => {
    if (!dateStr) return '';
    
    // YYYY-MM-DD formatı için
    if (dateStr.includes('-')) {
      const parts = dateStr.split('-');
      if (parts.length >= 2) {
        return `${parts[0]}-${parts[1]}`; // YYYY-MM
      }
    }
    
    // DD.MM.YYYY formatı için
    if (dateStr.includes('.')) {
      const parts = dateStr.split('.');
      if (parts.length === 3) {
        const day = parts[0];
        const month = parts[1];
        const year = parts[2];
        return `${year}-${month}`;
      }
    }
    
    return dateStr;
  };

  useEffect(() => {
    loadIndicators();
  }, []);

  useEffect(() => {
    if (selectedIndicator) {
      loadIndicatorData();
    }
  }, [selectedIndicator]);

  const loadIndicators = async () => {
    try {
      const indicators = await OzelGostergelerService.getIndicatorNames();
      setAvailableIndicators(indicators);
      setIsLoadingIndicators(false);
      if (indicators.length > 0) {
        setSelectedIndicator(indicators[0]);
      }
    } catch (e) {
      setIsLoadingIndicators(false);
      setErrorMessage(e instanceof Error ? e.message : String(e));
    }
  };

  const loadIndicatorData = async () => {
    if (!selectedIndicator) return;

    setIsLoadingData(true);
    setErrorMessage(null);

    try {
      const data = await OzelGostergelerService.loadOzelGostergeData(selectedIndicator);
      setIndicatorData(data);
      
      // Yıllık değişimi CSV'den oku
      try {
        const yearlyChangeValue = await OzelGostergelerService.getYearlyChange(selectedIndicator);
        setYearlyChange(yearlyChangeValue);
      } catch (e) {
        console.log('Yıllık değişim okuma hatası:', e);
        // Fallback: eski mantık
        setYearlyChange(data.getYearToDateChange());
      }
      
      updateCharts(data);
      setIsLoadingData(false);
    } catch (e) {
      setIsLoadingData(false);
      setErrorMessage(e instanceof Error ? e.message : String(e));
    }
  };

  const updateCharts = async (data: OzelGostergeData) => {
    await updateEndeksChartData(data);
    await updateMonthlyChartData(data);
  };

  const updateEndeksChartData = async (data: OzelGostergeData) => {
    try {
      const tuikData = await TuikService.loadTuikOzelGostergeEndeksData(data.gostergeName);
      const result: {[key: string]: Array<{x: number; y: number}>} = {};
      let tuikSeries: Array<number | null> | null = null;

      if (data.dailyValues.length > 0) {
        result['Web TÜFE'] = data.dailyValues.map((value, index) => ({
          x: index,
          y: value,
        }));
      }

      if (tuikData.data[`TÜİK ${data.gostergeName}`]) {
        const tuikValues = tuikData.data[`TÜİK ${data.gostergeName}`] as number[];
        const tuikDates = tuikData.dates as string[];

        const tuikSpots: Array<{x: number; y: number}> = [];

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
              for (let webIndex = data.dates.length - 1; webIndex >= 0; webIndex--) {
                const webDate = data.dates[webIndex];
                const webDateParts = webDate.split('-');
                if (webDateParts.length === 3) {
                  const webMonth = webDateParts[1];
                  const webYear = webDateParts[0];

                  if (webMonth === tuikMonth && webYear === tuikYear) {
                    lastDayIndex = webIndex;
                    break;
                  }
                }
              }

              if (lastDayIndex !== -1) {
                tuikSpots.push({x: lastDayIndex, y: tuikValue});
              }
            }
          } catch (e) {
            console.log('Tarih eşleştirme hatası:', e);
          }
        }

        tuikSpots.sort((a, b) => a.x - b.x);

        // Build a step-like series but DO NOT extend beyond the last TÜİK observation.
        // Missing tail should be null so the last observation looks "empty" when TÜİK isn't available.
        tuikSeries = new Array(data.dates.length).fill(null);
        for (let i = 0; i < tuikSpots.length; i++) {
          const currentSpot = tuikSpots[i];
          const nextSpot = i < tuikSpots.length - 1 ? tuikSpots[i + 1] : null;
          const startX = currentSpot.x;
          const endX = nextSpot ? nextSpot.x - 1 : currentSpot.x;

          for (let x = startX; x <= endX && x < tuikSeries.length; x++) {
            tuikSeries[x] = currentSpot.y;
          }
        }

        const hasAnyTuik = tuikSeries.some((v) => v !== null && Number.isFinite(v));
        if (hasAnyTuik) {
          // marker for legend/dataset inclusion
          result['TÜİK TÜFE'] = tuikSpots.map((s) => ({x: s.x, y: s.y}));
        } else {
          tuikSeries = null;
        }
      }

      if (Object.keys(result).length > 0) {
        // Tarihleri YYYY-MM formatına çevir
        const formattedDates = data.dates.map(formatDateToYearMonth);

        setEndeksChartData({
          labels: formattedDates.map((_, i) => (i % Math.ceil(formattedDates.length / 5) === 0 ? formattedDates[i] : '')),
          datasets: [
            {
              // Show as "deviation from 100" so Y-axis can start at 100 in labels.
              data: (result['Web TÜFE']?.map((d) => d.y - INDEX_BASELINE) || []),
              color: () => `rgba(25, 118, 210, 1)`,
              strokeWidth: 3,
            },
            ...(tuikSeries
              ? [
                  {
                    data: tuikSeries.map((v) => (v === null ? null : v - INDEX_BASELINE)),
                    color: () => `rgba(211, 47, 47, 1)`,
                    strokeWidth: 3,
                  },
                ]
              : []),
          ],
          legend: Object.keys(result),
        });
      }
    } catch (e) {
      console.log('Endeks grafik veri yükleme hatası:', e);
    }
  };

  const updateMonthlyChartData = async (data: OzelGostergeData) => {
    try {
      const tuikData = await TuikService.loadTuikOzelGostergeData(data.gostergeName);
      const tuikDates = tuikData.dates as string[];
      const tuikKey = Object.keys(tuikData.data)[0] || '';
      const tuikValues = tuikKey ? (tuikData.data[tuikKey] as number[]) : [];

      const webTufeMap: {[key: string]: number} = {};
      const webTufeDateList: Array<{yearMonth: string; originalDate: string}> = [];

      for (let i = 0; i < data.monthlyDates.length && i < data.monthlyChanges.length; i++) {
        const originalDate = data.monthlyDates[i];
        const yearMonth = parseDateToYearMonth(originalDate);
        if (yearMonth) {
          webTufeMap[yearMonth] = data.monthlyChanges[i];
          webTufeDateList.push({yearMonth, originalDate});
        }
      }

      webTufeDateList.sort((a, b) => a.yearMonth.localeCompare(b.yearMonth));

      const tuikMap: {[key: string]: number} = {};
      for (let i = 0; i < tuikDates.length && i < tuikValues.length; i++) {
        const yearMonth = parseDateToYearMonth(tuikDates[i]);
        if (yearMonth) {
          tuikMap[yearMonth] = tuikValues[i];
        }
      }

      const allDates = webTufeDateList.map((e) => e.originalDate);
      const webValues: number[] = [];
      const tuikValuesArray: number[] = [];

      webTufeDateList.forEach((entry) => {
        webValues.push(webTufeMap[entry.yearMonth] ?? 0.0);
        tuikValuesArray.push(tuikMap[entry.yearMonth] ?? NaN);
      });

      // Tarihleri YYYY-MM formatına çevir
      const formattedMonthlyDates = allDates.map(formatDateToYearMonth);

      setMonthlyChartData({
        labels: formattedMonthlyDates.map((_, i) => (i % Math.ceil(formattedMonthlyDates.length / 5) === 0 ? formattedMonthlyDates[i] : '')),
        datasets: [
          {
            data: webValues,
            color: () => `rgba(25, 118, 210, 1)`,
            strokeWidth: 3,
          },
          ...(tuikValuesArray.some((v) => !isNaN(v))
            ? [
                {
                  // TÜİK olmayan noktalarda 0 basma; çizgiyi kesmek için null bırak.
                  data: tuikValuesArray.map((v) => (isNaN(v) ? null : v)),
                  color: () => `rgba(211, 47, 47, 1)`,
                  strokeWidth: 3,
                },
              ]
            : []),
        ],
        legend: tuikValuesArray.some((v) => !isNaN(v)) ? ['Web TÜFE', 'TÜİK'] : ['Web TÜFE'],
      });
    } catch (e) {
      console.log('Aylık grafik veri yükleme hatası:', e);
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
    <ScrollView style={styles.container}>
      <View
        style={styles.content}
        onLayout={(e) => {
          const w = e?.nativeEvent?.layout?.width;
          if (typeof w === 'number' && w > 0 && Math.abs(w - contentWidth) > 1) {
            setContentWidth(w);
          }
        }}>
        <View style={styles.topSection}>
        <Text style={styles.sectionTitle}>Özel Kapsamlı Göstergeler</Text>
        <View style={styles.pickerContainer}>
          {isLoadingIndicators ? (
            <ActivityIndicator size="small" color="#7B1FA2" />
          ) : (
            <WebPicker
              selectedValue={selectedIndicator || ''}
              onValueChange={(itemValue) => {
                setSelectedIndicator(itemValue);
                setIndicatorData(null);
              }}
              style={styles.picker}>
              {availableIndicators.map((indicator) => (
                <WebPicker.Item key={indicator} label={indicator} value={indicator} />
              ))}
            </WebPicker>
          )}
        </View>

        {indicatorData && (
          <>
            <View style={styles.statsContainer}>
              <View style={styles.statCard}>
                <View style={styles.statHeader}>
                  <Icon name="trending-up" size={20} color="#FF9800" />
                  <Text style={styles.statTitle}>Yıllık Değişim</Text>
                </View>
                <Text style={[styles.statValue, {color: '#FF9800'}]}>
                  {yearlyChange.toFixed(2)}%
                </Text>
              </View>
              <View style={styles.statCard}>
                <View style={styles.statHeader}>
                  <Icon name="calendar-month" size={20} color="#4CAF50" />
                  <Text style={styles.statTitle}>Aylık Değişim</Text>
                </View>
                <Text style={[styles.statValue, {color: '#4CAF50'}]}>
                  {indicatorData.getLatestMonthlyChange().toFixed(2)}%
                </Text>
              </View>
            </View>
            <Text style={styles.dateText}>01.01.2025-{getCurrentDate()}</Text>
          </>
        )}
      </View>

      {errorMessage && (
        <View style={styles.errorContainer}>
          <Icon name="error-outline" size={20} color="#f44336" />
          <Text style={styles.errorText}>{errorMessage}</Text>
        </View>
      )}

      {isLoadingData ? (
        <View style={styles.centerContainer}>
          <ActivityIndicator size="large" color="#7B1FA2" />
        </View>
      ) : indicatorData ? (
        <>
          {endeksChartData && (
            <View style={styles.chartSection}>
              <Text style={styles.chartTitle}>Endeks Değerleri</Text>
              {endeksChartData.legend && endeksChartData.legend.length > 1 && (
                <View style={styles.legend}>
                  <View style={styles.legendItem}>
                    <View style={[styles.legendLine, {backgroundColor: '#2196F3'}]} />
                    <Text style={styles.legendText}>Web TÜFE</Text>
                  </View>
                  <View style={styles.legendItem}>
                    <View style={[styles.legendLine, {backgroundColor: '#f44336'}]} />
                    <Text style={styles.legendText}>TÜİK</Text>
                  </View>
                </View>
              )}
              <LineChartWithHover
                data={endeksChartData}
                width={Math.max(320, contentWidth - 32)}
                height={220}
                chartConfig={chartConfig}
                withDots={false}
                bezier={false}
                horizontalLabelRotation={45}
                style={styles.chart}
                dates={(indicatorData?.dates || []).map(formatDateToYearMonth)}
                labels={endeksChartData?.labels}
                selectedEndeks={selectedIndicator}
                valueOffset={INDEX_BASELINE}
                formatYLabel={(y) => {
                  const n = parseFloat(y);
                  if (!Number.isFinite(n)) return y;
                  return (n + INDEX_BASELINE).toFixed(2);
                }}
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
                    <Text style={styles.legendText}>TÜİK</Text>
                  </View>
                </View>
              )}
              <LineChartWithHover
                data={monthlyChartData}
                width={Math.max(320, contentWidth - 32)}
                height={220}
                chartConfig={{
                  ...chartConfig,
                  color: () => `rgba(25, 118, 210, 1)`,
                }}
                withDots={false}
                bezier={false}
                horizontalLabelRotation={45}
                style={styles.chart}
                dates={(indicatorData?.monthlyDates || []).map(formatDateToYearMonth)}
                labels={monthlyChartData?.labels}
                selectedEndeks={selectedIndicator}
              />
            </View>
          )}
        </>
      ) : (
        <View style={styles.centerContainer}>
          <Text style={styles.emptyText}>Lütfen bir gösterge seçiniz</Text>
        </View>
      )}
      </View>
    </ScrollView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#fff',
  },
  content: {
    padding: 16,
  },
  topSection: {
    padding: 16,
    backgroundColor: '#F3E5F5',
    borderRadius: 12,
    marginBottom: 24,
  },
  sectionTitle: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#7B1FA2',
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
  centerContainer: {
    padding: 40,
    alignItems: 'center',
    justifyContent: 'center',
  },
  errorContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 12,
    backgroundColor: '#ffebee',
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#ffcdd2',
    marginBottom: 16,
  },
  errorText: {
    marginLeft: 8,
    color: '#f44336',
    flex: 1,
  },
  chartSection: {
    marginBottom: 24,
  },
  chartTitle: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#7B1FA2',
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
  emptyText: {
    fontSize: 16,
    color: '#757575',
    textAlign: 'center',
  },
});

export default OzelGostergelerPage;
