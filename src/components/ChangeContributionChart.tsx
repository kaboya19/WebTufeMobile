import React, {useMemo, useState} from 'react';
import {View, Text, StyleSheet, LayoutChangeEvent} from 'react-native';

type Item = {
  groupName: string;
  change: number;
  changeLabel: string;
  contribution: number;
  contributionLabel: string;
};

interface Props {
  items: Item[];
  showContribution?: boolean;
}

const ChangeContributionChart: React.FC<Props> = ({items, showContribution = true}) => {
  const maxChange = useMemo(
    () => Math.max(0.01, ...items.map((i) => Math.abs(i.change))),
    [items]
  );
  const maxContribution = useMemo(
    () => Math.max(0.01, ...items.map((i) => Math.abs(i.contribution))),
    [items]
  );

  if (!items.length) {
    return (
      <View style={styles.empty}>
        <Text style={styles.emptyText}>Veri bulunamadı</Text>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      {items.map((it) => (
        <Row
          key={it.groupName}
          item={it}
          maxChange={maxChange}
          maxContribution={maxContribution}
          showContribution={showContribution}
        />
      ))}
    </View>
  );
};

const Row: React.FC<{
  item: Item;
  maxChange: number;
  maxContribution: number;
  showContribution: boolean;
}> = ({
  item,
  maxChange,
  maxContribution,
  showContribution,
}) => {
  return (
    <View style={styles.row}>
      <BarWithCenter
        value={item.change}
        maxAbs={maxChange}
        positiveColor="#ef4444"
        negativeColor="#93c5fd"
        label={item.changeLabel}
        align="left-axis"
      />

      <View style={styles.centerLabel}>
        <Text style={styles.groupText} numberOfLines={2}>
          {item.groupName}
        </Text>
      </View>

      {showContribution && (
        <BarWithCenter
          value={item.contribution}
          maxAbs={maxContribution}
          positiveColor="#22c55e"
          negativeColor="#86efac"
          label={item.contributionLabel}
          align="right-axis"
        />
      )}
    </View>
  );
};

const BarWithCenter: React.FC<{
  value: number;
  maxAbs: number;
  positiveColor: string;
  negativeColor: string;
  label: string;
  align: 'left-axis' | 'right-axis';
}> = ({value, maxAbs, positiveColor, negativeColor, label, align}) => {
  const [width, setWidth] = useState(260);
  const onLayout = (e: LayoutChangeEvent) => {
    const w = e?.nativeEvent?.layout?.width;
    if (typeof w === 'number' && w > 0) setWidth(w);
  };

  const zeroX = align === 'left-axis' ? 0 : 0; // zero starts at left edge
  const usableWidth = width * 0.9; // some padding to avoid overflow
  const barWidth = maxAbs > 0 ? (Math.abs(value) / maxAbs) * usableWidth : 0;
  const barLeft = value >= 0 ? zeroX : zeroX - barWidth;
  const color = value >= 0 ? positiveColor : negativeColor;
  const labelLeft = value >= 0 ? zeroX + barWidth + 6 : zeroX - barWidth - 52;

  return (
    <View style={[styles.barArea, {paddingHorizontal: 8}]}>
      <View style={styles.barInner} onLayout={onLayout}>
        <View style={[styles.axisLine]} />
        {value !== 0 && (
          <View style={[styles.bar, {left: barLeft, width: barWidth, backgroundColor: color}]} />
        )}
        <View style={[styles.valueLabel, {left: labelLeft}]}>
          <Text style={styles.valueText}>{label}</Text>
        </View>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {width: '100%', gap: 8},
  empty: {padding: 16, alignItems: 'center', justifyContent: 'center'},
  emptyText: {color: '#6b7280', fontSize: 14},
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    paddingVertical: 4,
  },
  barArea: {
    flex: 4.5,
    height: 54,
  },
  barInner: {
    flex: 1,
    position: 'relative',
    backgroundColor: '#f8fafc',
    borderRadius: 12,
    overflow: 'hidden',
    borderWidth: 1,
    borderColor: '#e5e7eb',
  },
  axisLine: {
    position: 'absolute',
    top: 0,
    bottom: 0,
    width: 2,
    left: 0,
    backgroundColor: '#cbd5e1',
  },
  bar: {
    position: 'absolute',
    top: 12,
    height: 30,
    borderRadius: 10,
  },
  valueLabel: {
    position: 'absolute',
    top: 0,
    bottom: 0,
    justifyContent: 'center',
  },
  valueText: {
    fontSize: 12,
    fontWeight: '700',
    color: '#0f172a',
  },
  centerLabel: {
    flex: 3,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 6,
  },
  groupText: {
    fontSize: 13,
    fontWeight: '800',
    color: '#0f172a',
    textAlign: 'center',
  },
  axisLabel: {fontSize: 11, color: '#6b7280', textAlign: 'center', marginTop: 6},
});

export default ChangeContributionChart;


