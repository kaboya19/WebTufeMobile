import React, {useEffect, useMemo, useRef, useState} from 'react';
import {Dimensions, Platform, StyleSheet, Text, View, useWindowDimensions} from 'react-native';
import {LineChart} from 'react-native-chart-kit';

interface LineChartWithHoverProps {
  data: any;
  width?: number;
  height?: number;
  chartConfig: any;
  withDots?: boolean;
  bezier?: boolean;
  style?: any;
  dates?: string[];
  labels?: string[];
  selectedEndeks?: string;
  formatYLabel?: (yLabel: string) => string;
  valueOffset?: number;
}

function dedupeSorted(nums: number[], epsilon = 0.5): number[] {
  const out: number[] = [];
  for (const n of nums) {
    if (out.length === 0 || Math.abs(out[out.length - 1] - n) > epsilon) out.push(n);
  }
  return out;
}

function nearestIndex(sorted: number[], x: number): number {
  if (sorted.length === 0) return 0;
  if (x <= sorted[0]) return 0;
  if (x >= sorted[sorted.length - 1]) return sorted.length - 1;

  let lo = 0;
  let hi = sorted.length - 1;
  while (hi - lo > 1) {
    const mid = Math.floor((lo + hi) / 2);
    if (sorted[mid] === x) return mid;
    if (sorted[mid] < x) lo = mid;
    else hi = mid;
  }
  return Math.abs(sorted[lo] - x) <= Math.abs(sorted[hi] - x) ? lo : hi;
}

function arraysAlmostEqual(a: number[], b: number[], epsilon = 0.001): boolean {
  if (a === b) return true;
  if (a.length !== b.length) return false;
  for (let i = 0; i < a.length; i++) {
    if (Math.abs(a[i] - b[i]) > epsilon) return false;
  }
  return true;
}

const LineChartWithHover: React.FC<LineChartWithHoverProps> = ({
  data,
  width,
  height = 220,
  chartConfig,
  withDots = false,
  bezier = false,
  style,
  dates,
  labels,
  selectedEndeks,
  formatYLabel,
  valueOffset,
}) => {
  const {width: windowWidth} = useWindowDimensions();
  const resolvedWidth = typeof width === 'number' ? width : Math.max(0, windowWidth - 32);
  const chartRef = useRef<View>(null);
  const pointXsRef = useRef<number[]>([]);
  const pointYsRef = useRef<number[]>([]);

  const [hoveredIndex, setHoveredIndex] = useState<number | null>(null);
  const [hoverPosition, setHoverPosition] = useState<{x: number; y: number} | null>(null);
  const [hoverLineX, setHoverLineX] = useState<number | null>(null);
  const [pointXs, setPointXs] = useState<number[]>([]);

  const dataLength: number = useMemo(() => {
    const len = data?.datasets?.[0]?.data?.length;
    return typeof len === 'number' ? len : 0;
  }, [data]);

  const effectiveWithDots = Platform.OS === 'web' ? true : withDots;

  // Web'de hover için dot'ları DOM'da tutuyoruz (görünmez), cx koordinatlarını okuyup doğru index bulacağız.
  const effectiveChartConfig = useMemo(() => {
    if (Platform.OS !== 'web') return chartConfig;
    return {
      ...chartConfig,
      propsForDots: {
        ...(chartConfig?.propsForDots ?? {}),
        r: '4',
        strokeWidth: '0',
        fill: 'transparent',
        fillOpacity: 0,
        strokeOpacity: 0,
        opacity: 0,
      },
    };
  }, [chartConfig]);

  const syncPointXsFromSvg = () => {
    const el = chartRef.current as any;
    const wrapper = el?._nativeNode || el;
    if (!wrapper) return;
    const svg: SVGSVGElement | null = wrapper.querySelector?.('svg') ?? null;
    if (!svg) return;

    // NOT: Legend'daki renkli noktalar da <circle> olarak render ediliyor.
    // Hover için sadece "görünmez dot" circle'larını alıyoruz (opacity / fillOpacity / strokeOpacity = 0).
    const circles = Array.from(svg.querySelectorAll('circle')) as SVGCircleElement[];

    const isInvisibleDot = (c: SVGCircleElement) => {
      const attrOpacity = c.getAttribute('opacity');
      const attrFillOpacity = c.getAttribute('fill-opacity');
      const attrStrokeOpacity = c.getAttribute('stroke-opacity');

      const styleOpacity = (c as any).style?.opacity;
      const styleFillOpacity = (c as any).style?.fillOpacity;
      const styleStrokeOpacity = (c as any).style?.strokeOpacity;

      const opacity = Number.isFinite(parseFloat(attrOpacity ?? ''))
        ? parseFloat(attrOpacity!)
        : Number.isFinite(parseFloat(styleOpacity ?? ''))
          ? parseFloat(styleOpacity)
          : 1;

      const fillOpacity = Number.isFinite(parseFloat(attrFillOpacity ?? ''))
        ? parseFloat(attrFillOpacity!)
        : Number.isFinite(parseFloat(styleFillOpacity ?? ''))
          ? parseFloat(styleFillOpacity)
          : 1;

      const strokeOpacity = Number.isFinite(parseFloat(attrStrokeOpacity ?? ''))
        ? parseFloat(attrStrokeOpacity!)
        : Number.isFinite(parseFloat(styleStrokeOpacity ?? ''))
          ? parseFloat(styleStrokeOpacity)
          : 1;

      const fill = (c.getAttribute('fill') ?? '').toLowerCase();

      return (
        opacity === 0 ||
        fillOpacity === 0 ||
        strokeOpacity === 0 ||
        fill === 'transparent'
      );
    };

    const points = circles
      .filter(isInvisibleDot)
      .map((c) => ({
        cx: parseFloat(c.getAttribute('cx') || 'NaN'),
        cy: parseFloat(c.getAttribute('cy') || 'NaN'),
      }))
      .filter((p) => Number.isFinite(p.cx) && Number.isFinite(p.cy))
      .sort((a, b) => a.cx - b.cx);

    // cx aynı olan (farklı seri) noktaları gruplayıp ortalama cy alıyoruz
    const uniqX: number[] = [];
    const uniqY: number[] = [];
    const epsilon = 0.5;

    for (const p of points) {
      if (uniqX.length === 0 || Math.abs(uniqX[uniqX.length - 1] - p.cx) > epsilon) {
        uniqX.push(p.cx);
        uniqY.push(p.cy);
      } else {
        // aynı x grubunda ortalama cy
        const lastIdx = uniqY.length - 1;
        uniqY[lastIdx] = (uniqY[lastIdx] + p.cy) / 2;
      }
    }

    const uniq = dedupeSorted(uniqX);

    // Nokta sayısı ile data uzunluğu uyuşmuyorsa (özellikle 2 seri veya eksik seri), yine de uniq'i kullan.
    // Hover hesaplamasında uniq uzunluğunu referans alacağız.
    if (uniq.length > 0 && !arraysAlmostEqual(pointXsRef.current, uniq, 0.01)) {
      pointXsRef.current = uniq;
      // Y dizisi de aynı uzunlukta ise sakla, değilse temizle (fallback mouse y)
      pointYsRef.current = uniqY.length === uniqX.length ? uniqY : [];
      setPointXs(uniq);
    }
  };

  useEffect(() => {
    if (Platform.OS !== 'web') return;

    setPointXs([]);
    setHoveredIndex(null);
    setHoverPosition(null);
    setHoverLineX(null);

    const el = chartRef.current as any;
    const wrapper = el?._nativeNode || el;
    if (!wrapper) return;

    let raf = 0;
    let observer: MutationObserver | null = null;
    let scheduled = false;

    const svg: SVGSVGElement | null = wrapper.querySelector?.('svg') ?? null;
    if (svg) {
      // ilk render sonrası yakala
      raf = requestAnimationFrame(() => syncPointXsFromSvg());

      observer = new MutationObserver(() => {
        // Chart-kit animasyonlarında attributes sürekli değişebiliyor; raf ile throttle et.
        if (scheduled) return;
        scheduled = true;
        requestAnimationFrame(() => {
          scheduled = false;
          syncPointXsFromSvg();

          // Noktalar yakalandıysa observer'ı kapat (donmayı engeller)
          const xsNow = pointXsRef.current;
          if (xsNow.length > 0 && (dataLength === 0 || xsNow.length >= dataLength)) {
            observer?.disconnect();
            observer = null;
          }
        });
      });
      // attributes: false -> sürekli tetiklenmeyi engeller (özellikle web animasyonlarında)
      observer.observe(svg, {subtree: true, childList: true, attributes: false});

      const onMove = (e: MouseEvent) => {
        const svgRect = svg.getBoundingClientRect();
        const svgX = e.clientX - svgRect.left;
        if (svgX < 0 || svgX > svgRect.width) {
          setHoveredIndex(null);
          setHoverPosition(null);
          setHoverLineX(null);
          return;
        }

        // `pointXs` state closure'u stale olabileceği için ref kullanıyoruz.
        if (pointXsRef.current.length === 0) syncPointXsFromSvg();
        const xs = pointXsRef.current;
        if (xs.length === 0) return;

        const idx = nearestIndex(xs, svgX);
        const wrapperRect = wrapper.getBoundingClientRect();
        const svgLeftInWrapper = svgRect.left - wrapperRect.left;
        const lineX = svgLeftInWrapper + xs[idx];

        setHoveredIndex(idx);
        // Tooltip'u mouse Y'a değil, gerçek veri noktasının Y'ına yakınla (cy)
        const ys = pointYsRef.current;
        const pointClientY =
          ys.length === xs.length && idx >= 0 && idx < ys.length
            ? svgRect.top + ys[idx]
            : e.clientY;
        setHoverPosition({x: e.clientX, y: pointClientY});
        setHoverLineX(lineX);
      };

      const onLeave = () => {
        setHoveredIndex(null);
        setHoverPosition(null);
        setHoverLineX(null);
      };

      svg.addEventListener('mousemove', onMove);
      svg.addEventListener('mouseleave', onLeave);

      return () => {
        if (raf) cancelAnimationFrame(raf);
        if (observer) observer.disconnect();
        svg.removeEventListener('mousemove', onMove);
        svg.removeEventListener('mouseleave', onLeave);
      };
    }

    // SVG henüz yoksa, bir sonraki frame'de tekrar dene
    raf = requestAnimationFrame(() => syncPointXsFromSvg());
    return () => {
      if (raf) cancelAnimationFrame(raf);
      if (observer) observer.disconnect();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [dataLength, resolvedWidth, height, bezier, selectedEndeks]);

  const getTooltipContent = () => {
    if (hoveredIndex === null || !data.datasets || data.datasets.length === 0) return null;

    const values: Array<{label: string; value: number; color: string}> = [];
    
    data.datasets.forEach((dataset: any, idx: number) => {
      // Dataset'in uzunluğunu kontrol et - eğer hoveredIndex dataset uzunluğundan küçükse veya eşitse veriyi göster
      const datasetLength = dataset.data ? dataset.data.length : 0;
      if (dataset.data && hoveredIndex < datasetLength && dataset.data[hoveredIndex] !== undefined && dataset.data[hoveredIndex] !== null) {
        const value = dataset.data[hoveredIndex];
        // NaN veya Infinity kontrolü
        if (!isNaN(value) && isFinite(value)) {
          // Legend varsa onu kullan, yoksa selectedEndeks kullan, o da yoksa "Seri X"
          let label = data.legend && data.legend[idx] ? data.legend[idx] : selectedEndeks || `Seri ${idx + 1}`;
          const color = dataset.color ? dataset.color() : chartConfig.color();
          const displayValue =
            typeof valueOffset === 'number' && Number.isFinite(valueOffset)
              ? value + valueOffset
              : value;
          values.push({label, value: displayValue, color});
        }
      }
    });

    // En az bir geçerli değer varsa tooltip'i göster
    if (values.length === 0) return null;

    let dateLabel = `Nokta ${hoveredIndex + 1}`;

    const pointCount = pointXs.length > 0 ? pointXs.length : dataLength;
    const datesOk = dates && dates.length === pointCount;
    const labelsOk = labels && labels.length === pointCount;

    if (datesOk && dates && hoveredIndex >= 0 && hoveredIndex < dates.length) {
      dateLabel = dates[hoveredIndex];
    } else if (labelsOk && labels && hoveredIndex >= 0 && hoveredIndex < labels.length && labels[hoveredIndex]) {
      dateLabel = labels[hoveredIndex];
    }

    return (
      <View style={styles.tooltip}>
        <Text style={styles.tooltipDate}>{dateLabel}</Text>
        {values.map((item, idx) => (
          <View key={idx} style={styles.tooltipRow}>
            <View style={[styles.tooltipColor, {backgroundColor: item.color}]} />
            <Text style={styles.tooltipLabel}>{item.label}:</Text>
            <Text style={styles.tooltipValue}>{item.value.toFixed(2)}</Text>
          </View>
        ))}
      </View>
    );
  };

  return (
    <View style={styles.container}>
      <View 
        ref={chartRef} 
        style={[styles.chartWrapper, {width: resolvedWidth, height}]}
      >
        <LineChart
          data={data}
          width={resolvedWidth}
          height={height}
          chartConfig={effectiveChartConfig}
          withDots={effectiveWithDots}
          bezier={bezier}
          {...(formatYLabel ? {formatYLabel} : {})}
          style={style}
        />
      </View>
      {Platform.OS === 'web' && hoveredIndex !== null && hoverPosition && hoverLineX !== null && (() => {
        // Tooltip genişliğini tahmin et (yaklaşık 180px)
        const tooltipWidth = 180;
        const screenWidth = Dimensions.get('window').width;
        const screenHeight = Dimensions.get('window').height;
        const tooltipRight = hoverPosition.x + 15 + tooltipWidth;
        
        // Eğer tooltip ekranın dışına taşıyorsa, sol tarafa kaydır
        let tooltipLeft = hoverPosition.x + 15;
        if (tooltipRight > screenWidth - 10) {
          // Tooltip'i mouse'un soluna yerleştir
          tooltipLeft = hoverPosition.x - tooltipWidth - 15;
          // Eğer sol tarafa da taşıyorsa, ekranın ortasına yerleştir
          if (tooltipLeft < 10) {
            tooltipLeft = (screenWidth - tooltipWidth) / 2;
          }
        }

        // Tooltip yüksekliğini yaklaşık hesapla (başlık + satırlar)
        const approxRows = Math.max(1, data?.datasets?.length ?? 1);
        const tooltipHeight = Math.min(220, 44 + approxRows * 18);

        // Varsayılan: noktanın biraz üstü; üstte taşarsa aşağı al.
        let tooltipTop = hoverPosition.y - tooltipHeight - 12;
        if (tooltipTop < 10) tooltipTop = hoverPosition.y + 12;
        // Ekranın dışına taşmasın
        tooltipTop = Math.max(10, Math.min(screenHeight - tooltipHeight - 10, tooltipTop));
        
        return (
          <>
            <View
              style={[styles.hoverLine, {left: hoverLineX}]}
              pointerEvents="none"
            />
            <View
              style={[
                styles.tooltipContainer,
                {
                  left: tooltipLeft,
                  top: tooltipTop,
                },
              ]}
              pointerEvents="none">
              {getTooltipContent()}
            </View>
          </>
        );
      })()}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    position: 'relative',
  },
  chartWrapper: {
    position: 'relative',
    ...(Platform.OS === 'web' && {cursor: 'crosshair'}),
  },
  hoverLine: {
    position: 'absolute',
    top: 0,
    bottom: 0,
    width: 2,
    backgroundColor: 'rgba(0, 0, 0, 0.3)',
    zIndex: 100,
    pointerEvents: 'none',
    ...(Platform.OS === 'web' && {cursor: 'crosshair'}),
  },
  tooltipContainer: {
    position: 'fixed',
    zIndex: 1000,
    pointerEvents: 'none',
  },
  tooltip: {
    backgroundColor: 'rgba(0, 0, 0, 0.85)',
    borderRadius: 8,
    padding: 12,
    minWidth: 150,
    ...(Platform.OS === 'web' && {
      boxShadow: '0 4px 12px rgba(0, 0, 0, 0.3)',
    }),
  },
  tooltipDate: {
    color: '#fff',
    fontSize: 12,
    fontWeight: 'bold',
    marginBottom: 8,
  },
  tooltipRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 4,
  },
  tooltipColor: {
    width: 12,
    height: 3,
    marginRight: 8,
  },
  tooltipLabel: {
    color: '#fff',
    fontSize: 11,
    marginRight: 8,
  },
  tooltipValue: {
    color: '#fff',
    fontSize: 11,
    fontWeight: 'bold',
  },
});

export default LineChartWithHover;

