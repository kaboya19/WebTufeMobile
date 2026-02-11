import React from 'react';
import {View, Text, StyleSheet, Dimensions} from 'react-native';
import {TufeDataModel} from '../models/TufeData';

const {width: SCREEN_WIDTH} = Dimensions.get('window');
const CHART_PADDING = 32;

interface TufeChartProps {
  data: TufeDataModel[];
  showContributions?: boolean;
}

const TufeChart: React.FC<TufeChartProps> = ({
  data,
  showContributions = false,
}) => {
  if (data.length === 0) {
    return (
      <View style={styles.centerContainer}>
        <Text style={styles.noDataText}>Veri bulunamadı</Text>
      </View>
    );
  }

  // Tüm değerlerden maksimum mutlak değeri bul
  const maxAbsChange = Math.max(...data.map((e) => Math.abs(e.changeRate)), 0.01);

  return (
    <View style={styles.container}>
      <View style={styles.headerRow}>
        <View style={styles.graphContainer}>
          <Text style={styles.headerText}>Değişim (%)</Text>
        </View>
        <View style={styles.centerLabel} />
      </View>

      {data.map((tufeData, index) => (
        <BarItem
          key={index}
          tufeData={tufeData}
          maxAbsChange={maxAbsChange}
        />
      ))}
    </View>
  );
};

interface BarItemProps {
  tufeData: TufeDataModel;
  maxAbsChange: number;
}

const BarItem: React.FC<BarItemProps> = ({
  tufeData,
  maxAbsChange,
}) => {
  const chartWidth = SCREEN_WIDTH - CHART_PADDING;
  // Bar alanını daha küçük yap - flex container genişliğinin %70'i kadar
  const barAreaWidth = (chartWidth * 1.5) / 10 * 0.7;
  const centerX = barAreaWidth / 2;

  // Bar genişliğini hesapla - alan küçüldüğü için yüzdeyi artırıyoruz
  const changeWidth =
    maxAbsChange > 0 ? (Math.abs(tufeData.changeRate) / maxAbsChange) * (barAreaWidth * 0.85) : 0;

  // Pozitif/negatif durumuna göre renk
  let barColor: string;
  if (tufeData.changeRate > 0) {
    barColor = tufeData.isWebTufe ? '#f44336' : '#2196F3';
  } else if (tufeData.changeRate < 0) {
    barColor = tufeData.isWebTufe ? '#EF9A9A' : '#90CAF9';
  } else {
    barColor = '#BDBDBD';
  }

  const barLeft = tufeData.changeRate >= 0 ? centerX : centerX - changeWidth;

  const labelGap = 3;
  const labelMinWidth = 38;
  const labelInside = changeWidth >= 42;
  const labelLeft = labelInside
    ? tufeData.changeRate >= 0
      ? barLeft + changeWidth - labelMinWidth + 2
      : barLeft + 3
    : tufeData.changeRate >= 0
      ? centerX + changeWidth + labelGap
      : Math.max(0, centerX - changeWidth - labelMinWidth - labelGap);

  return (
    <View style={styles.barContainer}>
      {/* Değişim barı */}
      <View style={styles.graphContainer}>
        <View style={styles.graphArea}>
          <View style={[styles.centerLine, {left: centerX - 1}]} />
          {tufeData.changeRate !== 0 && (
            <View
              style={[
                styles.bar,
                {
                  left: barLeft,
                  width: changeWidth,
                  backgroundColor: barColor,
                },
              ]}
            />
          )}
          <View style={[styles.valueLabel, {left: labelLeft}]}>
            <Text
              style={[
                styles.valueText,
                labelInside && tufeData.changeRate !== 0 ? styles.valueTextInBar : null,
              ]}>
              {tufeData.formattedChangeRate}
            </Text>
          </View>
        </View>
      </View>

      {/* Grup adı ortada */}
      <View style={styles.centerLabel}>
        <Text style={styles.groupText} numberOfLines={2} ellipsizeMode="tail">
          {tufeData.displayName}
        </Text>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    width: '100%',
  },
  centerContainer: {
    alignItems: 'center',
    justifyContent: 'center',
    padding: 20,
  },
  noDataText: {
    fontSize: 16,
    color: '#757575',
  },
  barContainer: {
    flexDirection: 'row',
    marginVertical: 5,
    minHeight: 58,
    alignItems: 'center',
    paddingVertical: 5,
  },
  headerRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 8,
  },
  headerText: {
    fontSize: 10,
    fontWeight: '700',
    color: '#424242',
    textAlign: 'center',
  },
  graphContainer: {
    flex: 1.5,
    minHeight: 40,
    justifyContent: 'center',
  },
  graphArea: {
    flex: 1,
    position: 'relative',
    minHeight: 36,
  },
  centerLine: {
    position: 'absolute',
    top: 0,
    bottom: 0,
    width: 2,
    backgroundColor: '#BDBDBD',
  },
  bar: {
    position: 'absolute',
    top: 10,
    height: 18,
    borderRadius: 3,
  },
  valueLabel: {
    position: 'absolute',
    top: 0,
    bottom: 0,
    justifyContent: 'center',
  },
  valueText: {
    fontSize: 9,
    fontWeight: 'bold',
    color: '#212121',
  },
  valueTextInBar: {
    color: '#ffffff',
  },
  centerLabel: {
    flex: 2,
    paddingHorizontal: 0,
    alignItems: 'flex-start',
    justifyContent: 'center',
    minHeight: 40,
    paddingLeft: 4,
  },
  groupText: {
    fontSize: 10.5,
    fontWeight: '700',
    color: '#212121',
    textAlign: 'center',
    lineHeight: 13,
  },
});

export default TufeChart;

