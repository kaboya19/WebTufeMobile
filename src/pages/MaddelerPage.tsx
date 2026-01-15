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
import {MaddelerService} from '../services/MaddelerService';
import {MaddeData} from '../models/MaddeData';

const screenWidth = Dimensions.get('window').width;

const MaddelerPage = () => {
  const [isLoadingAnaGruplar, setIsLoadingAnaGruplar] = useState(true);
  const [isLoadingDates, setIsLoadingDates] = useState(true);
  const [isLoadingData, setIsLoadingData] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const [anaGruplar, setAnaGruplar] = useState<string[]>([]);
  const [availableDates, setAvailableDates] = useState<string[]>([]);
  const [maddeData, setMaddeData] = useState<MaddeData[]>([]);

  const [selectedAnaGrup, setSelectedAnaGrup] = useState<string | null>(null);
  const [selectedDate, setSelectedDate] = useState<string | null>(null);

  useEffect(() => {
    loadInitialData();
  }, []);

  useEffect(() => {
    if (selectedAnaGrup && selectedDate) {
      loadMaddeData();
    }
  }, [selectedAnaGrup, selectedDate]);

  const loadInitialData = async () => {
    try {
      const anaGruplarResult = await MaddelerService.loadAnaGruplar();
      const datesResult = await MaddelerService.getAvailableDates();

      setAnaGruplar(anaGruplarResult);
      setAvailableDates(datesResult);
      setIsLoadingAnaGruplar(false);
      setIsLoadingDates(false);
      setErrorMessage(null);

      if (anaGruplarResult.length > 0) {
        setSelectedAnaGrup(anaGruplarResult[0]);
      }
      if (datesResult.length > 0) {
        // getAvailableDates() en yeni tarihi önce döndürüyor -> default olarak en son (en yeni) tarih seçilsin
        setSelectedDate(datesResult[0]);
      }
    } catch (e) {
      setIsLoadingAnaGruplar(false);
      setIsLoadingDates(false);
      setErrorMessage(e instanceof Error ? e.message : String(e));
    }
  };

  const loadMaddeData = async () => {
    if (!selectedAnaGrup || !selectedDate) return;

    setIsLoadingData(true);
    setErrorMessage(null);

    try {
      // 1) Seçili ana gruba ait madde isimlerini al
      const maddeler = await MaddelerService.loadMaddeler(selectedAnaGrup);
      // 2) Seçili tarihte bu maddelerin değişim oranlarını yükle
      const data = await MaddelerService.loadMaddeDegiisimOranlari(maddeler, selectedDate);
      setMaddeData(data);
      setIsLoadingData(false);
    } catch (e) {
      setIsLoadingData(false);
      setErrorMessage(e instanceof Error ? e.message : String(e));
    }
  };

  const renderBarChart = () => {
    if (maddeData.length === 0) {
      return (
        <View style={styles.emptyContainer}>
          <Text style={styles.emptyText}>
            Ana grup ve tarih seçerek maddeleri görüntüleyebilirsiniz
          </Text>
        </View>
      );
    }

    const maxValue =
      Math.max(...maddeData.map((e) => Math.abs(e.changeRate))) || 1;

    return (
      <View style={styles.barChartContainer}>
        <Text style={styles.barChartTitle}>Maddeler Değişim Oranları (%)</Text>
        {maddeData.map((item, index) => {
          const barWidthRatio = (Math.abs(item.changeRate) / maxValue) * 0.3;
          const barColor =
            item.changeRate > 0
              ? '#66BB6A'
              : item.changeRate < 0
              ? '#EF5350'
              : '#9E9E9E';

          return (
            <View key={index} style={styles.barItem}>
              <Text style={styles.barItemLabel} numberOfLines={2}>
                {item.maddeName}
              </Text>
              <View style={styles.barContainer}>
                <View style={styles.centerLine} />
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
                      left:
                        item.changeRate >= 0
                          ? `${50 + barWidthRatio * 100}%`
                          : `${50 - barWidthRatio * 100}%`,
                      width: 60,
                      transform: [
                        {translateX: item.changeRate >= 0 ? 4 : -64},
                      ],
                      textAlign: item.changeRate >= 0 ? 'left' : 'right',
                    },
                  ]}>
                  {item.changeRate.toFixed(1)}%
                </Text>
              </View>
            </View>
          );
        })}
      </View>
    );
  };

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <Text style={styles.title}>Maddeler</Text>

      <View style={styles.section}>
        <Text style={styles.label}>Ana Grup Seçiniz:</Text>
        <View style={styles.pickerContainer}>
          {isLoadingAnaGruplar ? (
            <ActivityIndicator size="small" color="#2196F3" />
          ) : (
            <WebPicker
              selectedValue={selectedAnaGrup || ''}
              onValueChange={(itemValue) => {
                setSelectedAnaGrup(itemValue);
                setMaddeData([]);
              }}
              style={styles.picker}>
              {anaGruplar.map((anaGrup) => (
                <WebPicker.Item key={anaGrup} label={anaGrup} value={anaGrup} />
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

      {errorMessage && (
        <View style={styles.errorContainer}>
          <Text style={styles.errorText}>{errorMessage}</Text>
        </View>
      )}

      {isLoadingData ? (
        <View style={styles.centerContainer}>
          <ActivityIndicator size="large" color="#2196F3" />
        </View>
      ) : (
        renderBarChart()
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
    fontWeight: 'bold',
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
    padding: 12,
    backgroundColor: '#ffebee',
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#ffcdd2',
    marginBottom: 16,
  },
  errorText: {
    color: '#f44336',
  },
  barChartContainer: {
    padding: 16,
    backgroundColor: '#FAFAFA',
    borderRadius: 12,
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
    textAlign: 'center',
  },
});

export default MaddelerPage;
