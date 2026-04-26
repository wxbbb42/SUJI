/**
 * 用神宫旁边显示 2-3 个相邻宫的简化标签（仅装饰，不响应）
 */
import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { Colors, Space, Type } from '@/lib/design/tokens';
import type { Palace, QimenChart } from '@/lib/qimen/types';

/** 9 宫几何邻接关系 */
const PALACE_NEIGHBORS: Record<number, number[]> = {
  1: [2, 6, 8],
  2: [1, 7, 9],
  3: [4, 8, 9],
  4: [3, 9, 1],
  5: [],
  6: [1, 7, 8],
  7: [2, 6, 9],
  8: [1, 3, 6],
  9: [3, 4, 7],
};

type Props = {
  chart: QimenChart;
};

export function AdjacentPalaceTags({ chart }: Props) {
  const yongShenPalaceId = chart.yongShen.palaceId;
  if (yongShenPalaceId === 5) return null;

  const neighborIds = (PALACE_NEIGHBORS[yongShenPalaceId] ?? []).slice(0, 3);
  const neighbors = neighborIds.map(id => chart.palaces.find(p => p.id === id)).filter(Boolean) as Palace[];

  return (
    <View style={styles.row}>
      {neighbors.map(p => (
        <View key={p.id} style={styles.tag}>
          <Text style={styles.text}>
            {p.name}·{p.bamen ?? '无门'}
          </Text>
        </View>
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: 'row',
    gap: 6,
    marginVertical: Space.xs,
    flexWrap: 'wrap',
  },
  tag: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    backgroundColor: Colors.brandBg,
    borderRadius: 8,
  },
  text: {
    ...Type.caption,
    color: Colors.vermilion,
  },
});
