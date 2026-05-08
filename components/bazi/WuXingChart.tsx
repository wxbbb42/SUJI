/**
 * 五行结构图 — 竖条式
 *
 * Phase 3 重写：移除 balance 数字，改为原始计数（天干出现次数 + 地支本气出现次数）。
 * 高度 = 该五行在八字中出现的干支总数，最大为 8（4干+4支）。
 * 用神/喜神以品牌色标记；无数字显示。
 */

import type { SiZhu, WuXing } from '@/lib/bazi/types';
import { Colors, Space, Type } from '@/lib/design/tokens';
import { StyleSheet, Text, View } from 'react-native';

interface WuXingChartProps {
  siZhu: SiZhu;
  yongShen?: WuXing;
  xiShen?: WuXing;
}

const ELEMENTS: { wx: WuXing; color: string }[] = [
  { wx: '金', color: Colors.wuxing.金 },
  { wx: '木', color: Colors.wuxing.木 },
  { wx: '水', color: Colors.wuxing.水 },
  { wx: '火', color: Colors.wuxing.火 },
  { wx: '土', color: Colors.wuxing.土 },
];

function countWuXing(siZhu: SiZhu): Record<WuXing, number> {
  const counts: Record<WuXing, number> = { 金: 0, 木: 0, 水: 0, 火: 0, 土: 0 };
  for (const pillar of [siZhu.year, siZhu.month, siZhu.day, siZhu.hour]) {
    counts[pillar.ganZhi.ganWuXing]++;
    counts[pillar.ganZhi.zhiWuXing]++;
  }
  return counts;
}

export function WuXingChart({ siZhu, yongShen, xiShen }: WuXingChartProps) {
  const counts = countWuXing(siZhu);
  const max = Math.max(...Object.values(counts), 1);

  return (
    <View style={styles.container}>
      <View style={styles.barsRow}>
        {ELEMENTS.map(({ wx, color }) => {
          const count = counts[wx];
          const pct = (count / max) * 100;
          const isYong = yongShen === wx;
          const isXi = xiShen === wx;

          return (
            <View key={wx} style={styles.barCol}>
              {/* 计数（整数，无系数） */}
              <Text style={styles.barValue}>{count}</Text>

              {/* 条 */}
              <View style={styles.barTrack}>
                <View
                  style={[
                    styles.barFill,
                    { height: `${Math.max(pct, 4)}%`, backgroundColor: color },
                  ]}
                />
              </View>

              {/* 五行字 */}
              <Text style={[
                styles.barLabel,
                { color },
                (isYong || isXi) && styles.barLabelHighlight,
              ]}>
                {wx}
              </Text>

              {/* 用神/喜神标记 */}
              {isYong && <Text style={styles.marker}>用</Text>}
              {isXi && <Text style={styles.marker}>喜</Text>}
            </View>
          );
        })}
      </View>
    </View>
  );
}

const BAR_HEIGHT = 100;

const styles = StyleSheet.create({
  container: {
    paddingVertical: Space.base,
  },
  barsRow: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    alignItems: 'flex-end',
  },
  barCol: {
    alignItems: 'center',
    gap: Space.xs,
  },
  barValue: {
    ...Type.label,
    color: Colors.inkTertiary,
  },
  barTrack: {
    width: 20,
    height: BAR_HEIGHT,
    backgroundColor: Colors.bg,
    borderRadius: 2,
    justifyContent: 'flex-end',
    overflow: 'hidden',
  },
  barFill: {
    width: '100%',
    borderRadius: 2,
    opacity: 0.7,
  },
  barLabel: {
    fontSize: 16,
    fontWeight: '400',
    letterSpacing: 1,
  },
  barLabelHighlight: {
    fontWeight: '700',
  },
  marker: {
    ...Type.label,
    color: Colors.brand,
    fontWeight: '500',
  },
});
