/**
 * 五行力量图 — 竖条式
 * 
 * 设计：不用传统柱状图，用竖条+文字
 * 用神/喜神以品牌色下划线标记
 */

import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { Colors, Space, Type } from '@/lib/design/tokens';
import type { WuXingBalance, WuXing } from '@/lib/bazi/types';

interface WuXingChartProps {
  balance: WuXingBalance;
  yongShen?: WuXing;
  xiShen?: WuXing;
}

const ELEMENTS: { key: keyof WuXingBalance; label: string; color: string }[] = [
  { key: 'jin',  label: '金', color: Colors.wuxing.jin },
  { key: 'mu',   label: '木', color: Colors.wuxing.mu },
  { key: 'shui', label: '水', color: Colors.wuxing.shui },
  { key: 'huo',  label: '火', color: Colors.wuxing.huo },
  { key: 'tu',   label: '土', color: Colors.wuxing.tu },
];

export function WuXingChart({ balance, yongShen, xiShen }: WuXingChartProps) {
  const values = ELEMENTS.map(e => balance[e.key]);
  const max = Math.max(...values, 1);

  return (
    <View style={styles.container}>
      <View style={styles.barsRow}>
        {ELEMENTS.map((el) => {
          const val = balance[el.key];
          const pct = (val / max) * 100;
          const isYong = yongShen === el.label;
          const isXi = xiShen === el.label;

          return (
            <View key={el.key} style={styles.barCol}>
              {/* 数值 */}
              <Text style={styles.barValue}>{val.toFixed(1)}</Text>

              {/* 条 */}
              <View style={styles.barTrack}>
                <View
                  style={[
                    styles.barFill,
                    { height: `${Math.max(pct, 4)}%`, backgroundColor: el.color },
                  ]}
                />
              </View>

              {/* 五行字 */}
              <Text style={[
                styles.barLabel,
                { color: el.color },
                (isYong || isXi) && styles.barLabelHighlight,
              ]}>
                {el.label}
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
