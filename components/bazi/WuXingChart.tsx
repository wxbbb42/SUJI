/**
 * WuXingChart — 五行力量柱状图
 * 展示金木水火土的力量分布，标注用神 / 喜神
 */
import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import type { WuXingBalance, WuXing } from '@/lib/bazi';

// ── 五行颜色 ────────────────────────────────────────────────────────
const WUXING_COLOR: Record<WuXing, string> = {
  金: '#C4A35A',
  木: '#4CAF50',
  水: '#2196F3',
  火: '#E53935',
  土: '#8B6914',
};

// ── 五行顺序 ────────────────────────────────────────────────────────
const WUXING_ORDER: { key: WuXing; balanceField: keyof { jin: number; mu: number; shui: number; huo: number; tu: number } }[] = [
  { key: '金', balanceField: 'jin' },
  { key: '木', balanceField: 'mu' },
  { key: '水', balanceField: 'shui' },
  { key: '火', balanceField: 'huo' },
  { key: '土', balanceField: 'tu' },
];

const MAX_BAR_HEIGHT = 100;

interface WuXingChartProps {
  balance: WuXingBalance;
  yongShen: WuXing;
  xiShen: WuXing;
  jiShen?: WuXing;
}

export default function WuXingChart({ balance, yongShen, xiShen, jiShen }: WuXingChartProps) {

  // 归一化：以最大值为参照
  const values = WUXING_ORDER.map(e => balance[e.balanceField]);
  const maxVal = Math.max(...values, 1);

  const tagFor = (wx: WuXing): string | null => {
    if (wx === yongShen) return '用';
    if (wx === xiShen)   return '喜';
    if (wx === jiShen)   return '忌';
    return null;
  };

  return (
    <View style={styles.container}>
      <Text style={styles.title}>五行分布</Text>

      {/* 柱状图 */}
      <View style={styles.chartArea}>
        {WUXING_ORDER.map(({ key, balanceField }) => {
          const val = balance[balanceField];
          const barH = Math.max(6, Math.round((val / maxVal) * MAX_BAR_HEIGHT));
          const color = WUXING_COLOR[key];
          const tag   = tagFor(key);

          return (
            <View key={key} style={styles.barCol}>
              {/* 标签（用/喜/忌） */}
              <View style={[styles.tagBadge, tag ? { backgroundColor: color } : styles.tagEmpty]}>
                {tag ? <Text style={styles.tagText}>{tag}</Text> : null}
              </View>

              {/* 数值 */}
              <Text style={[styles.barValue, { color }]}>{val.toFixed(0)}</Text>

              {/* 柱体 */}
              <View style={styles.barTrack}>
                <View style={[styles.bar, { height: barH, backgroundColor: color }]} />
              </View>

              {/* 五行标签 */}
              <Text style={[styles.barLabel, { color }]}>{key}</Text>
            </View>
          );
        })}
      </View>

      {/* 图例 */}
      <View style={styles.legend}>
        <LegendItem color={WUXING_COLOR[yongShen]} label={`用神·${yongShen}`} />
        <LegendItem color={WUXING_COLOR[xiShen]}   label={`喜神·${xiShen}`}   />
        {jiShen && (
          <LegendItem color="#B8A898" label={`忌神·${jiShen}`} />
        )}
      </View>
    </View>
  );
}

function LegendItem({ color, label }: { color: string; label: string }) {
  return (
    <View style={styles.legendItem}>
      <View style={[styles.legendDot, { backgroundColor: color }]} />
      <Text style={styles.legendText}>{label}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    backgroundColor: '#FFFDF8',
    borderRadius: 16,
    padding: 20,
    borderWidth: 0.5,
    borderColor: '#E5DDD0',
  },
  title: {
    fontSize: 15,
    color: '#2C1810',
    fontWeight: '600',
    letterSpacing: 3,
    marginBottom: 20,
  },
  chartArea: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    alignItems: 'flex-end',
    height: MAX_BAR_HEIGHT + 80,
  },
  barCol: {
    alignItems: 'center',
    width: 48,
  },
  tagBadge: {
    width: 22,
    height: 22,
    borderRadius: 11,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 4,
  },
  tagEmpty: {
    backgroundColor: 'transparent',
  },
  tagText: {
    fontSize: 11,
    color: '#FFFDF8',
    fontWeight: '700',
  },
  barValue: {
    fontSize: 11,
    fontWeight: '600',
    marginBottom: 4,
  },
  barTrack: {
    width: 28,
    height: MAX_BAR_HEIGHT,
    justifyContent: 'flex-end',
    backgroundColor: '#F5F0E8',
    borderRadius: 6,
    overflow: 'hidden',
  },
  bar: {
    width: '100%',
    borderRadius: 6,
  },
  barLabel: {
    marginTop: 8,
    fontSize: 15,
    fontWeight: '600',
    letterSpacing: 1,
  },
  legend: {
    flexDirection: 'row',
    justifyContent: 'center',
    gap: 20,
    marginTop: 16,
    paddingTop: 16,
    borderTopWidth: 0.5,
    borderTopColor: '#E5DDD0',
  },
  legendItem: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  legendDot: {
    width: 10,
    height: 10,
    borderRadius: 5,
  },
  legendText: {
    fontSize: 12,
    color: '#8B7355',
    letterSpacing: 1,
  },
});
