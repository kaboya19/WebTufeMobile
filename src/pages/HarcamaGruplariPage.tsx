import React, {useState, useEffect} from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  ActivityIndicator,
  useWindowDimensions,
  TouchableOpacity,
} from 'react-native';
import WebPicker from '../components/WebPicker';
import {MaterialIcons as Icon} from '@expo/vector-icons';
import LineChartWithHover from '../components/LineChartWithHover';
import {HarcamaGruplariService} from '../services/HarcamaGruplariService';
import {TuikService} from '../services/TuikService';
import {
  AnaGrupData,
  HarcamaGrubuData,
  HarcamaGrubuEndeksData,
  HarcamaGrubuAylikData,
  HarcamaGrubuIstatistik,
} from '../models/HarcamaGrubuData';

const HarcamaGruplariPage = () => {
  const {width: windowWidth} = useWindowDimensions();
  const [isLoadingAnaGruplar, setIsLoadingAnaGruplar] = useState(true);
  const [isLoadingDates, setIsLoadingDates] = useState(true);
  const [isLoadingData, setIsLoadingData] = useState(false);
  const [isLoadingHarcamaGruplari, setIsLoadingHarcamaGruplari] = useState(false);
  const [isLoadingDetayData, setIsLoadingDetayData] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const [anaGruplar, setAnaGruplar] = useState<AnaGrupData[]>([]);
  const [availableDates, setAvailableDates] = useState<string[]>([]);
  const [harcamaGrubuData, setHarcamaGrubuData] = useState<HarcamaGrubuData[]>([]);
  const [harcamaGruplari, setHarcamaGruplari] = useState<string[]>([]);

  const [selectedAnaGrup, setSelectedAnaGrup] = useState<string | null>(null);
  const [selectedDate, setSelectedDate] = useState<string | null>(null);
  const [selectedHarcamaGrubu, setSelectedHarcamaGrubu] = useState<string | null>(null);

  const [endeksData, setEndeksData] = useState<HarcamaGrubuEndeksData[]>([]);
  const [aylikData, setAylikData] = useState<HarcamaGrubuAylikData[]>([]);
  const [istatistik, setIstatistik] = useState<HarcamaGrubuIstatistik | null>(null);

  const [endeksChartData, setEndeksChartData] = useState<any>(null);
  const [aylikChartData, setAylikChartData] = useState<any>(null);
  const [aylikChartDates, setAylikChartDates] = useState<string[]>([]);

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
    loadInitialData();
  }, []);

  useEffect(() => {
    if (selectedAnaGrup && selectedDate) {
      loadHarcamaGrubuData();
      loadHarcamaGruplariList();
    }
  }, [selectedAnaGrup, selectedDate]);

  useEffect(() => {
    if (selectedHarcamaGrubu) {
      loadHarcamaGrubuDetayData();
    }
  }, [selectedHarcamaGrubu]);

  const loadInitialData = async () => {
    try {
      const anaGruplarResult = await HarcamaGruplariService.loadAnaGruplar();
      const datesResult = await HarcamaGruplariService.getAvailableDates();

      setAnaGruplar(anaGruplarResult);
      setAvailableDates(datesResult);
      setIsLoadingAnaGruplar(false);
      setIsLoadingDates(false);
      setErrorMessage(null);

      if (anaGruplarResult.length > 0) {
        setSelectedAnaGrup(anaGruplarResult[0].name);
      }
      if (datesResult.length > 0) {
        setSelectedDate(datesResult[datesResult.length - 1]);
      }
    } catch (e) {
      setIsLoadingAnaGruplar(false);
      setIsLoadingDates(false);
      setErrorMessage(e instanceof Error ? e.message : String(e));
    }
  };

  const loadHarcamaGrubuData = async () => {
    if (!selectedAnaGrup || !selectedDate) return;

    setIsLoadingData(true);
    setErrorMessage(null);

    try {
      const harcamaGruplariList = await HarcamaGruplariService.loadHarcamaGruplari(
        selectedAnaGrup
      );
      const data = await HarcamaGruplariService.loadHarcamaGrubuDegiisimOranlari(
        harcamaGruplariList,
        selectedDate
      );

      setHarcamaGrubuData(data);
      setIsLoadingData(false);
    } catch (e) {
      setIsLoadingData(false);
      setErrorMessage(e instanceof Error ? e.message : String(e));
    }
  };

  const loadHarcamaGruplariList = async () => {
    if (!selectedAnaGrup) return;

    setIsLoadingHarcamaGruplari(true);

    try {
      const gruplar = await HarcamaGruplariService.loadHarcamaGruplari(selectedAnaGrup);
      setHarcamaGruplari(gruplar);
      setIsLoadingHarcamaGruplari(false);
      setSelectedHarcamaGrubu(null);
      setEndeksData([]);
      setAylikData([]);
      setIstatistik(null);
    } catch (e) {
      setIsLoadingHarcamaGruplari(false);
      setErrorMessage(e instanceof Error ? e.message : String(e));
    }
  };

  const loadHarcamaGrubuDetayData = async () => {
    if (!selectedHarcamaGrubu) return;

    const groupName = selectedHarcamaGrubu;
    setIsLoadingDetayData(true);
    setErrorMessage(null);
    setEndeksChartData(null);
    setAylikChartData(null);
    setAylikChartDates([]);

    try {
      const [endeks, aylik, stats] = await Promise.all([
        HarcamaGruplariService.loadHarcamaGrubuEndeksData(groupName),
        HarcamaGruplariService.loadHarcamaGrubuAylikData(groupName),
        HarcamaGruplariService.calculateHarcamaGrubuStatistics(groupName),
      ]);

      // Selection changed mid-flight; ignore stale response
      if (selectedHarcamaGrubu !== groupName) return;

      setEndeksData(endeks);
      setAylikData(aylik);
      setIstatistik(stats);

      await Promise.all([
        updateEndeksChartData(groupName, endeks),
        updateAylikChartData(groupName, aylik),
      ]);

      setIsLoadingDetayData(false);
    } catch (e) {
      setIsLoadingDetayData(false);
      setErrorMessage(e instanceof Error ? e.message : String(e));
    }
  };

  const updateEndeksChartData = async (
    groupName: string,
    data: HarcamaGrubuEndeksData[]
  ) => {
    if (!groupName || data.length === 0) return;

    try {
      const tuikData = await TuikService.loadTuikHarcamaGrubuEndeksData(groupName);
      const result: {[key: string]: Array<{x: number; y: number}>} = {};

      if (data.length > 0) {
        result['Web TÜFE'] = data.map((item, index) => ({
          x: index,
          y: item.endeks,
        }));
      }

      if (tuikData.data[`TÜİK ${groupName}`]) {
        const tuikValues = tuikData.data[`TÜİK ${groupName}`] as number[];
        const tuikDates = tuikData.dates as string[];

        const tuikSeries: Array<{x: number; y: number | null}> = data.map(
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
              for (let webIndex = data.length - 1; webIndex >= 0; webIndex--) {
                const webDate = data[webIndex].tarih;
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
                tuikSeries[lastDayIndex] = {x: lastDayIndex, y: tuikValue};
              }
            }
          } catch (e) {
            console.log('Tarih eşleştirme hatası:', e);
          }
        }

        // Nokta -> bir sonraki öncesine kadar uzat; son noktadan sonrası da son değerle devam etsin
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

      if (Object.keys(result).length > 0) {
        const dates = data.map((d) => d.tarih);
        const hasTuikData = result['TÜİK TÜFE']?.some((d) => d.y !== null && d.y !== undefined);
        const tuikSeries = dates.map((_, idx) => {
          const point = result['TÜİK TÜFE']?.find((d) => d.x === idx);
          return point ? point.y : null;
        });

        if (selectedHarcamaGrubu !== groupName) return;
        
        // Tarihleri YYYY-MM formatına çevir
        const formattedDates = dates.map(formatDateToYearMonth);

        setEndeksChartData({
          labels: formattedDates.map((_, i) => (i % Math.ceil(formattedDates.length / 5) === 0 ? formattedDates[i] : '')),
          datasets: [
            {
              data: result['Web TÜFE']?.map((d) => d.y) || [],
              color: () => `rgba(25, 118, 210, 1)`,
              strokeWidth: 3,
            },
            {
              data: tuikSeries,
              color: () => `rgba(211, 47, 47, 1)`,
              strokeWidth: 3,
            },
          ],
          legend: ['Web TÜFE', hasTuikData ? 'TÜİK' : 'TÜİK (boş)'],
        });
      }
    } catch (e) {
      console.log('Endeks grafik veri yükleme hatası:', e);
    }
  };

  const updateAylikChartData = async (
    groupName: string,
    data: HarcamaGrubuAylikData[]
  ) => {
    if (!groupName || data.length === 0) return;

    try {
      const tuikData = await TuikService.loadTuikHarcamaGrubuData(groupName);
      const tuikDates = tuikData.dates as string[];
      const tuikKey = Object.keys(tuikData.data)[0] || '';
      const tuikValues = tuikKey ? (tuikData.data[tuikKey] as number[]) : [];

      const webTufeMap: {[key: string]: number} = {};
      data.forEach((item) => {
        webTufeMap[item.tarih] = item.degisimOrani;
      });

      const tuikMap: {[key: string]: number} = {};
      for (let i = 0; i < tuikDates.length && i < tuikValues.length; i++) {
        tuikMap[tuikDates[i]] = tuikValues[i];
      }

      const allDates = Array.from(new Set([...Object.keys(webTufeMap), ...Object.keys(tuikMap)])).sort();

      const webValues: number[] = [];
      const tuikValuesArray: number[] = [];

      allDates.forEach((date) => {
        webValues.push(webTufeMap[date] ?? 0.0);
        tuikValuesArray.push(tuikMap[date] ?? NaN);
      });

      // TÜİK olmayan noktalarda null kalsın; son değer uzatılmasın

      if (selectedHarcamaGrubu !== groupName) return;
      setAylikChartDates(allDates);
      const tuikSeries = tuikValuesArray.map((v) => (isNaN(v) ? null : v));
      const hasTuikValues = tuikSeries.some((v) => v !== null);
      
      // Tarihleri YYYY-MM formatına çevir
      const formattedMonthlyDates = allDates.map(formatDateToYearMonth);

      setAylikChartData({
        labels: formattedMonthlyDates.map((_, i) => (i % Math.ceil(formattedMonthlyDates.length / 5) === 0 ? formattedMonthlyDates[i] : '')),
        datasets: [
          {
            data: webValues,
            color: () => `rgba(25, 118, 210, 1)`,
            strokeWidth: 3,
          },
          {
            // TÜİK olmayan noktalarda 0 basma; çizgiyi kesmek için null bırak.
            data: tuikSeries,
            color: () => `rgba(211, 47, 47, 1)`,
            strokeWidth: 3,
          },
        ],
        legend: ['Web TÜFE', hasTuikValues ? 'TÜİK' : 'TÜİK (boş)'],
      });
    } catch (e) {
      console.log('Aylık grafik veri yükleme hatası:', e);
    }
  };

  const renderBarChart = () => {
    if (harcamaGrubuData.length === 0) {
      return (
        <View style={styles.emptyContainer}>
          <Text style={styles.emptyText}>Veri bulunamadı</Text>
        </View>
      );
    }

    const maxValue = Math.max(
      ...harcamaGrubuData.map((e) => Math.abs(e.changeRate))
    ) || 1;

    return (
      <View style={styles.barChartContainer}>
        <Text style={styles.barChartTitle}>Harcama Grupları Değişim Oranları (%)</Text>
        {harcamaGrubuData.map((item, index) => {
          const barWidthRatio = (Math.abs(item.changeRate) / maxValue) * 0.3;
          const barColor = item.changeRate > 0 ? '#66BB6A' : item.changeRate < 0 ? '#EF5350' : '#9E9E9E';

          return (
            <TouchableOpacity
              key={index}
              onPress={() => setSelectedHarcamaGrubu(item.groupName)}
              style={styles.barItem}>
              <Text style={styles.barItemLabel} numberOfLines={2}>
                {item.groupName}
              </Text>
              <View style={styles.barContainer}>
                <View style={[styles.centerLine]} />
                {item.changeRate !== 0 && (
                  <View
                    style={[
                      styles.bar,
                      {
                        width: `${barWidthRatio * 100}%`,
                        backgroundColor: barColor,
                        left: item.changeRate >= 0 ? '50%' : `${50 - barWidthRatio * 100}%`,
                      },
                    ]}
                  />
                )}
                <Text
                  style={[
                    styles.barValue,
                    {
                      color: barColor,
                      // Pozitif: barın sağına
                      // Negatif: barın soluna (çakışmayı engelle)
                      width: 60,
                      left:
                        item.changeRate >= 0
                          ? `${50 + barWidthRatio * 100}%`
                          : `${50 - barWidthRatio * 100}%`,
                      transform: [
                        {translateX: item.changeRate >= 0 ? 4 : -64},
                      ],
                      textAlign: item.changeRate >= 0 ? 'left' : 'right',
                    },
                  ]}>
                  {item.changeRate.toFixed(2)}%
                </Text>
              </View>
            </TouchableOpacity>
          );
        })}
      </View>
    );
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
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <Text style={styles.title}>Harcama Grupları</Text>

      <View style={styles.section}>
        <Text style={styles.label}>Ana Grup Seçiniz:</Text>
        <View style={styles.pickerContainer}>
          {isLoadingAnaGruplar ? (
            <ActivityIndicator size="small" color="#2196F3" />
          ) : (
            <WebPicker
              selectedValue={selectedAnaGrup || ''}
              onValueChange={(itemValue) => setSelectedAnaGrup(itemValue)}
              style={styles.picker}>
              {anaGruplar.map((anaGrup) => (
                <WebPicker.Item key={anaGrup.name} label={anaGrup.name} value={anaGrup.name} />
              ))}
            </WebPicker>
          )}
        </View>
      </View>

      <View style={styles.section}>
        <Text style={styles.label}>Tarih Seçiniz:</Text>
        <View style={styles.pickerContainer}>
          {isLoadingDates ? (
            <ActivityIndicator size="small" color="#2196F3" />
          ) : (
            <WebPicker
              selectedValue={selectedDate || ''}
              onValueChange={(itemValue) => setSelectedDate(itemValue)}
              style={styles.picker}>
              {availableDates.map((date) => (
                <WebPicker.Item key={date} label={date} value={date} />
              ))}
            </WebPicker>
          )}
        </View>
      </View>

      <View style={styles.section}>
        <Text style={styles.label}>Harcama Grubu Seçiniz:</Text>
        <View style={styles.pickerContainer}>
          {isLoadingHarcamaGruplari ? (
            <ActivityIndicator size="small" color="#2196F3" />
          ) : (
            <WebPicker
              selectedValue={selectedHarcamaGrubu || ''}
              onValueChange={(itemValue) => {
                const value = itemValue?.toString() ?? '';
                setSelectedHarcamaGrubu(value ? value : null);
              }}
              style={styles.picker}>
              <WebPicker.Item label="Seçiniz" value="" />
              {harcamaGruplari.map((grup) => (
                <WebPicker.Item key={grup} label={grup} value={grup} />
              ))}
            </WebPicker>
          )}
        </View>
      </View>

      {errorMessage && (
        <View style={styles.errorContainer}>
          <Icon name="error-outline" size={20} color="#f44336" />
          <Text style={styles.errorText}>{errorMessage}</Text>
        </View>
      )}

      {/* Liste görünümü */}
      {!selectedHarcamaGrubu && (
        <>
          {isLoadingData ? (
            <View style={styles.centerContainer}>
              <ActivityIndicator size="large" color="#2196F3" />
            </View>
          ) : (
            renderBarChart()
          )}
        </>
      )}

      {/* Detay görünümü (TÜFE sayfası gibi) */}
      {selectedHarcamaGrubu && (
        <View style={styles.detailContainer}>
          <View style={styles.detailHeader}>
            <TouchableOpacity
              style={styles.backButton}
              onPress={() => setSelectedHarcamaGrubu(null)}>
              <Icon name="arrow-back" size={18} color="#1565C0" />
              <Text style={styles.backButtonText}>Liste</Text>
            </TouchableOpacity>
            <Text style={styles.detailTitle} numberOfLines={2}>
              {selectedHarcamaGrubu}
            </Text>
          </View>

          {isLoadingDetayData ? (
            <View style={styles.centerContainer}>
              <ActivityIndicator size="large" color="#2196F3" />
            </View>
          ) : (
            <>
              {istatistik && (
                <View style={styles.statsCard}>
                  <Text style={styles.statsTitle}>{selectedHarcamaGrubu}</Text>
                  <View style={styles.statsRow}>
                    <View style={styles.statCard}>
                      <Text style={styles.statLabel}>Yılbaşından Bu Yana</Text>
                      <Text
                        style={[
                          styles.statValue,
                          {
                            color:
                              istatistik.yillikDegisim >= 0 ? '#4CAF50' : '#f44336',
                          },
                        ]}>
                        {istatistik.yillikDegisim.toFixed(2)}%
                      </Text>
                    </View>
                    <View style={styles.statCard}>
                      <Text style={styles.statLabel}>Son Aylık Değişim</Text>
                      <Text
                        style={[
                          styles.statValue,
                          {
                            color:
                              istatistik.aylikDegisim >= 0 ? '#4CAF50' : '#f44336',
                          },
                        ]}>
                        {istatistik.aylikDegisim.toFixed(2)}%
                      </Text>
                    </View>
                  </View>
                </View>
              )}

              {endeksChartData && (
                <View style={styles.chartSection}>
                  <Text style={styles.chartTitle}>
                    Endeks Değerleri
                  </Text>
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
                    width={Math.max(0, windowWidth - 32)}
                    height={220}
                    chartConfig={chartConfig}
                    withDots={false}
                    bezier
                    horizontalLabelRotation={45}
                    style={styles.chart}
                    dates={endeksData.map((d) => formatDateToYearMonth(d.tarih))}
                    labels={endeksChartData?.labels}
                    selectedEndeks={selectedHarcamaGrubu}
                  />
                </View>
              )}

              {aylikChartData && (
                <View style={styles.chartSection}>
                  <Text style={styles.chartTitle}>
                    Aylık Değişim (%)
                  </Text>
                  {aylikChartData.legend && aylikChartData.legend.length > 1 && (
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
                    data={aylikChartData}
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
                    dates={aylikChartDates.map(formatDateToYearMonth)}
                    labels={aylikChartData?.labels}
                    selectedEndeks={selectedHarcamaGrubu}
                  />
                </View>
              )}

              {!endeksChartData && !aylikChartData && !errorMessage && (
                <View style={styles.emptyContainer}>
                  <Text style={styles.emptyText}>
                    Bu harcama grubu için grafik verisi bulunamadı.
                  </Text>
                </View>
              )}
            </>
          )}
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
  content: {
    padding: 16,
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#212121',
    marginBottom: 24,
  },
  section: {
    marginBottom: 16,
  },
  label: {
    fontSize: 16,
    fontWeight: '600',
    color: '#212121',
    marginBottom: 8,
  },
  pickerContainer: {
    backgroundColor: '#F5F5F5',
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#E0E0E0',
  },
  picker: {
    height: 50,
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
  barChartContainer: {
    padding: 16,
    backgroundColor: '#FAFAFA',
    borderRadius: 12,
    marginBottom: 24,
  },
  barChartTitle: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#212121',
    marginBottom: 16,
  },
  barItem: {
    marginBottom: 16,
  },
  barItemLabel: {
    fontSize: 12,
    fontWeight: '500',
    color: '#212121',
    textAlign: 'center',
    marginBottom: 8,
  },
  barContainer: {
    height: 24,
    width: '100%',
    position: 'relative',
  },
  centerLine: {
    position: 'absolute',
    left: '50%',
    top: 0,
    bottom: 0,
    width: 2,
    backgroundColor: '#E0E0E0',
  },
  bar: {
    position: 'absolute',
    height: 20,
    top: 2,
    borderRadius: 4,
  },
  barValue: {
    position: 'absolute',
    top: 0,
    bottom: 0,
    fontSize: 11,
    fontWeight: '600',
    textAlign: 'center',
    lineHeight: 24,
  },
  emptyContainer: {
    padding: 40,
    alignItems: 'center',
  },
  emptyText: {
    fontSize: 16,
    color: '#757575',
  },
  statsCard: {
    padding: 16,
    backgroundColor: '#F5F5F5',
    borderRadius: 12,
    marginBottom: 24,
  },
  statsTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#212121',
    marginBottom: 16,
  },
  statsRow: {
    flexDirection: 'row',
    gap: 16,
  },
  statCard: {
    flex: 1,
    padding: 16,
    backgroundColor: '#fff',
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#E0E0E0',
    alignItems: 'center',
  },
  statLabel: {
    fontSize: 12,
    color: '#757575',
    fontWeight: '500',
    marginBottom: 8,
  },
  statValue: {
    fontSize: 24,
    fontWeight: 'bold',
  },
  chartSection: {
    marginBottom: 24,
  },
  chartTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#212121',
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
  detailContainer: {
    marginTop: 8,
  },
  detailHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 12,
    gap: 12,
  },
  backButton: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 8,
    paddingHorizontal: 10,
    backgroundColor: 'rgba(21, 101, 192, 0.08)',
    borderRadius: 10,
  },
  backButtonText: {
    marginLeft: 6,
    fontSize: 13,
    fontWeight: '600',
    color: '#1565C0',
  },
  detailTitle: {
    flex: 1,
    fontSize: 16,
    fontWeight: '700',
    color: '#212121',
    textAlign: 'right',
  },
  chart: {
    marginVertical: 8,
    borderRadius: 16,
  },
});

export default HarcamaGruplariPage;
