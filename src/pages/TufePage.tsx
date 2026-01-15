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
import {CSVService} from '../services/CSVService';
import {TuikService} from '../services/TuikService';
import {GitHubCSVService} from '../services/GitHubCSVService';
import Papa from 'papaparse';

const TufePage = () => {
  const {width: windowWidth} = useWindowDimensions();
  const [isLoading, setIsLoading] = useState(true);
  const [selectedEndeks, setSelectedEndeks] = useState('');
  const [availableEndeks, setAvailableEndeks] = useState<string[]>([]);
  const [yearToDateChange, setYearToDateChange] = useState(0);
  const [monthlyChange, setMonthlyChange] = useState(0);
  const [mainChartData, setMainChartData] = useState<any>(null);
  const [monthlyChartData, setMonthlyChartData] = useState<any>(null);
  const [endekslerData, setEndekslerData] = useState<{[key: string]: number[]}>({});
  const [dates, setDates] = useState<string[]>([]);
  const [tufeValues, setTufeValues] = useState<number[]>([]);
  const [tufeDates, setTufeDates] = useState<string[]>([]);
  const [tufeMonthlyChange, setTufeMonthlyChange] = useState(0);
  const [maddelerData, setMaddelerData] = useState<{[key: string]: number}>({});
  const [monthlyChartDates, setMonthlyChartDates] = useState<string[]>([]);

  useEffect(() => {
    loadData();
  }, []);

  useEffect(() => {
    if (!selectedEndeks) return;

    // Endeks değiştiğinde önce grafikleri temizle
    setMainChartData(null);
    setMonthlyChartData(null);

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
      const monthlyData = await GruplarService.loadGruplarAylikData();
      const maddelerMonthlyData = await loadMaddelerMonthlyData();

      setEndekslerData(endeksData.data);
      setDates(endeksData.dates);
      setMaddelerData(maddelerMonthlyData);
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

  const loadMaddelerMonthlyData = async (): Promise<{[key: string]: number}> => {
    try {
      const csvData = await GitHubCSVService.loadCSVFromGitHub(
        'maddeleraylik.csv',
        false
      );
      const lines = csvData.split(/\r?\n/);

      if (lines.length === 0) return {};

      const monthlyData: {[key: string]: number} = {};

      const parsedHeader = Papa.parse(lines[0], {
        header: false,
        skipEmptyLines: true,
      });
      const headerRow =
        parsedHeader.data.length > 0 && Array.isArray(parsedHeader.data[0])
          ? (parsedHeader.data[0] as any[])
          : [];
      const lastDateIndex = headerRow.length - 1;

      for (let i = 1; i < lines.length; i++) {
        if (lines[i].trim()) {
          try {
            const parsed = Papa.parse(lines[i], {
              header: false,
              skipEmptyLines: true,
            });
            if (
              parsed.data.length > 0 &&
              Array.isArray(parsed.data[0]) &&
              parsed.data[0].length >= 2
            ) {
              const row = parsed.data[0] as any[];
              const endeksName = row[1]?.toString().trim() || '';
              if (endeksName && row.length > lastDateIndex) {
                const lastValue =
                  parseFloat(row[lastDateIndex]?.toString() || '0') || 0.0;
                monthlyData[endeksName] = lastValue;
              }
            }
          } catch (e) {
            // Skip parse errors
          }
        }
      }

      return monthlyData;
    } catch (e) {
      console.log('Maddeler aylık veri yükleme hatası:', e);
      return {};
    }
  };

  const loadTufeData = async () => {
    try {
      const tufeData = await EndekslerService.loadTufeData();
      const monthlyChange = await CSVService.getTufeMonthlyChange();

      setTufeValues(tufeData.data['Web TÜFE'] || []);
      setTufeDates(tufeData.dates);
      setTufeMonthlyChange(monthlyChange);
      // updateChartData() artık useEffect'te çağrılıyor, burada çağırma
    } catch (e) {
      console.log('Error loading Web TÜFE data:', e);
    }
  };

  const getYearToDateChange = async (): Promise<number> => {
    if (!selectedEndeks) return 0.0;

    try {
      // Yıllık CSV'den oku
      const yearlyChange = await EndekslerService.getYearlyChange(selectedEndeks);
      return yearlyChange;
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

  const getMonthlyChange = (): number => {
    if (!selectedEndeks) return 0.0;

    if (selectedEndeks === 'Web TÜFE') {
      return tufeMonthlyChange;
    }

    if (maddelerData[selectedEndeks] !== undefined) {
      return maddelerData[selectedEndeks];
    }

    return 0.0;
  };

  const updateChartData = async () => {
    if (!selectedEndeks) return;

    // Mevcut selectedEndeks'i sakla (race condition önleme)
    const currentEndeks = selectedEndeks;

    try {
      if (currentEndeks === 'Web TÜFE') {
        // Web TÜFE verileri yüklenmiş mi kontrol et
        if (tufeValues.length === 0 || tufeDates.length === 0) {
          return; // Veriler henüz yüklenmemiş, bekleyelim
        }

        // Web TÜFE için karşılaştırmalı grafik
        const comparedData = await getComparedEndeksChartData();
        
        // selectedEndeks hala Web TÜFE mi kontrol et
        if (selectedEndeks !== currentEndeks || currentEndeks !== 'Web TÜFE') {
          return; // Endeks değişmiş, işlemi iptal et
        }

        if (Object.keys(comparedData).length > 0) {
          const webTufeData = comparedData['Web TÜFE'] || [];
          const tuikData = comparedData['TÜİK TÜFE'] || [];

          // Veri kontrolü yap ve selectedEndeks hala Web TÜFE mi kontrol et
          if (webTufeData.length > 0 && tufeDates.length > 0 && selectedEndeks === currentEndeks && currentEndeks === 'Web TÜFE') {
            const hasTuikData = tuikData.some((d) => d.y !== null && d.y !== undefined);
            const tuikSeries = tufeDates.map((_, idx) => {
              const point = tuikData.find((d) => d.x === idx);
              return point ? point.y : null;
            });

            // Tarihleri YYYY-MM formatına çevir
            const formattedDates = tufeDates.map(formatDateToYearMonth);

            setMainChartData({
              labels: formattedDates.map((_, i) => (i % Math.ceil(formattedDates.length / 5) === 0 ? formattedDates[i] : '')),
              datasets: [
                {
                  data: webTufeData.map((d) => d.y),
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
          }

          // Aylık değişim grafiği (Web TÜFE seçiliyken her durumda göster)
          const monthlyCompared = await getComparedMonthlyChangeChartData();
          
          // selectedEndeks hala Web TÜFE mi kontrol et
          if (selectedEndeks !== currentEndeks || currentEndeks !== 'Web TÜFE') {
            return; // Endeks değişmiş, işlemi iptal et
          }

          const comparisonDates = await getComparisonDates();
          const formattedComparisonDates = comparisonDates.map(formatDateToYearMonth);

          let webMonthly = monthlyCompared['Web TÜFE'] || [];
          let tuikMonthly = monthlyCompared['TÜİK TÜFE'] || [];

          // Web aylık veri yoksa CSV'den fallback al
          if (!webMonthly.length) {
            try {
              const monthlyData = await GruplarService.loadGruplarAylikData();
              if (monthlyData.data['Web TÜFE']) {
                webMonthly = (monthlyData.data['Web TÜFE'] as number[]).map((v, idx) => ({x: idx, y: v}));
              }
            } catch (e) {
              // yoksay
            }
          }

          const hasTuikMonthlyData = tuikMonthly.some((d) => d.y !== null && d.y !== undefined);
          const tuikMonthlySeries = formattedComparisonDates.map((_, idx) => {
            const point = tuikMonthly.find((d) => d.x === idx);
            return point ? point.y : null;
          });

          if (webMonthly.length > 0) {
            setMonthlyChartData({
              labels: formattedComparisonDates.map((_, i) => (i % Math.ceil(formattedComparisonDates.length / 5) === 0 ? formattedComparisonDates[i] : '')),
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
              legend: ['Web TÜFE', hasTuikMonthlyData ? 'TÜİK TÜFE' : 'TÜİK TÜFE (boş)'],
            });
            setMonthlyChartDates(formattedComparisonDates);
          } else {
            setMonthlyChartData(null);
            setMonthlyChartDates([]);
          }
        }
      } else {
        // Diğer endeksler için tekli grafik
        // selectedEndeks hala aynı mı kontrol et
        if (selectedEndeks !== currentEndeks) {
          return; // Endeks değişmiş, işlemi iptal et
        }

        // Veriler yüklenmiş mi kontrol et
        if (dates.length === 0 || !endekslerData[currentEndeks]) {
          return; // Veriler henüz yüklenmemiş
        }

        const values = endekslerData[currentEndeks] || [];
        if (values.length > 0 && dates.length > 0 && selectedEndeks === currentEndeks) {
          // Tarihleri YYYY-MM formatına çevir
          const endeksFormattedDates = dates.map(formatDateToYearMonth);

          // Endeks grafiği - her zaman güncelle
          setMainChartData({
            labels: endeksFormattedDates.map((_, i) => (i % Math.ceil(endeksFormattedDates.length / 5) === 0 ? endeksFormattedDates[i] : '')),
            datasets: [
              {
                data: values,
                color: () => `rgba(25, 118, 210, 1)`,
                strokeWidth: 3,
              },
            ],
          });

          // Aylık değişim grafiği
          const monthlyResult = await getMonthlyChangeChartData();
          const monthlyData = monthlyResult.data;
          const monthlyDatesFromCSV = monthlyResult.dates;
          
          if (monthlyData.length > 0) {
            // CSV'den gelen tarihleri kullan, yoksa dates array'inden al
            const monthlyDates = monthlyDatesFromCSV.length > 0 && monthlyDatesFromCSV.length === monthlyData.length
              ? monthlyDatesFromCSV
              : (dates.length >= monthlyData.length 
                  ? dates.slice(-monthlyData.length)
                  : dates.slice(0, monthlyData.length));
            
            // Tarihleri yıl-ay formatına çevir
            const formattedMonthlyDates = monthlyDates.slice(0, monthlyData.length).map(formatDateToYearMonth);

            setMonthlyChartData({
              labels: formattedMonthlyDates.map((_, i) => (i % Math.ceil(formattedMonthlyDates.length / 5) === 0 ? formattedMonthlyDates[i] : '')),
              datasets: [
                {
                  data: monthlyData.map((d) => d.y),
                  color: () => `rgba(25, 118, 210, 1)`,
                  strokeWidth: 3,
                },
              ],
            });
            // Tarihleri state'e kaydet - veri uzunluğuyla eşleştiğinden emin ol
            setMonthlyChartDates(formattedMonthlyDates);
          } else {
            // Aylık veri yoksa grafiği temizle
            setMonthlyChartData(null);
            setMonthlyChartDates([]);
          }
        } else {
          // Veri yoksa grafikleri temizle
          setMainChartData(null);
          setMonthlyChartData(null);
        }
      }

      // İstatistikleri güncelle
      const yearlyChange = await getYearToDateChange();
      setYearToDateChange(yearlyChange);
      setMonthlyChange(getMonthlyChange());
    } catch (e) {
      console.log('Error updating chart data:', e);
    }
  };

  const getComparedEndeksChartData = async (): Promise<{[key: string]: Array<{x: number; y: number}>}> => {
    if (selectedEndeks !== 'Web TÜFE') return {};

    try {
      const tuikData = await TuikService.loadTuikEndeksData();
      const result: {[key: string]: Array<{x: number; y: number}>} = {};

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

  const getComparedMonthlyChangeChartData = async (): Promise<{[key: string]: Array<{x: number; y: number}>}> => {
    if (!selectedEndeks || selectedEndeks !== 'Web TÜFE') return {};

    try {
      const monthlyData = await GruplarService.loadGruplarAylikData();
      const tuikData = await TuikService.loadTuikAylikData();

      const tuikDates = tuikData.dates as string[];
      const webTufeDates = monthlyData.dates as string[];

      const result: {[key: string]: Array<{x: number; y: number}>} = {};

      if (monthlyData.data['Web TÜFE']) {
        const values = monthlyData.data['Web TÜFE'] as number[];
        result['Web TÜFE'] = values.map((value, index) => ({
          x: index,
          y: value,
        }));
      }

      if (tuikData.data['TÜİK TÜFE']) {
        const values = tuikData.data['TÜİK TÜFE'] as number[];
        const tuikSeries: Array<{x: number; y: number | null}> = webTufeDates.map(
          (_, idx) => ({x: idx, y: null})
        );

        for (let i = 0; i < webTufeDates.length; i++) {
          const webDateStr = webTufeDates[i];
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

  const getComparisonDates = async (): Promise<string[]> => {
    try {
      const monthlyData = await GruplarService.loadGruplarAylikData();
      return monthlyData.dates;
    } catch (e) {
      return [];
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

  const getMonthlyChangeChartData = async (): Promise<{data: Array<{x: number; y: number}>, dates: string[]}> => {
    if (!selectedEndeks || selectedEndeks === 'Web TÜFE') return {data: [], dates: []};

    try {
      const csvData = await GitHubCSVService.loadCSVFromGitHub(
        'maddeleraylik.csv',
        false
      );
      const lines = csvData.split(/\r?\n/);

      if (lines.length === 0) return {data: [], dates: []};

      const parsedHeader = Papa.parse(lines[0], {
        header: false,
        skipEmptyLines: true,
      });
      const headerRow =
        parsedHeader.data.length > 0 && Array.isArray(parsedHeader.data[0])
          ? (parsedHeader.data[0] as any[])
          : [];
      const dates: string[] = [];
      for (let i = 2; i < headerRow.length; i++) {
        dates.push(headerRow[i]?.toString().trim() || '');
      }

      for (let i = 1; i < lines.length; i++) {
        if (lines[i].trim()) {
          try {
            const parsed = Papa.parse(lines[i], {
              header: false,
              skipEmptyLines: true,
            });
            if (
              parsed.data.length > 0 &&
              Array.isArray(parsed.data[0]) &&
              parsed.data[0].length >= 2
            ) {
              const row = parsed.data[0] as any[];
              const endeksName = row[1]?.toString().trim() || '';

              if (endeksName === selectedEndeks) {
                const values: number[] = [];
                for (let j = 2; j < row.length && j < dates.length + 2; j++) {
                  values.push(parseFloat(row[j]?.toString() || '0') || 0.0);
                }
                return {
                  data: values.map((value, index) => ({
                    x: index,
                    y: value,
                  })),
                  dates: dates.slice(0, values.length),
                };
              }
            }
          } catch (e) {
            // Skip parse errors
          }
        }
      }
      return {data: [], dates: []};
    } catch (e) {
      console.log('Aylık veri yükleme hatası:', e);
      return {data: [], dates: []};
    }
  };

  const getCurrentDate = () => {
    const now = new Date();
    const day = now.getDate().toString().padStart(2, '0');
    const month = (now.getMonth() + 1).toString().padStart(2, '0');
    const year = now.getFullYear().toString();
    return `${day}.${month}.${year}`;
  };

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
            horizontalLabelRotation={45}
            style={styles.chart}
            dates={(selectedEndeks === 'Web TÜFE' ? tufeDates : dates).map(formatDateToYearMonth)}
            labels={mainChartData?.labels}
            selectedEndeks={selectedEndeks}
          />
        </View>
      )}

      {monthlyChartData && (
        <View style={[styles.chartSection, {marginHorizontal: -16}]}>
          <View style={{paddingHorizontal: 16}}>
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
          </View>
          <LineChartWithHover
            data={monthlyChartData}
            width={windowWidth}
            height={220}
            chartConfig={{
              ...chartConfig,
              color: () => `rgba(25, 118, 210, 1)`,
            }}
            withDots={false}
            bezier={false}
            horizontalLabelRotation={45}
            style={styles.chart}
            dates={monthlyChartDates.map(formatDateToYearMonth)}
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
