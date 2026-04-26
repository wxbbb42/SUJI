/**
 * 完整 9 宫盘（仅 BottomSheet 显示）
 *
 * 3×3 网格，每格 5 行小字（地盘干 / 天盘干 / 八门 / 九星 / 八神）
 * 用神宫朱砂边框 + 角标
 * 凶格所在宫底色暗淡
 */
import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { Colors, Space, Type } from '@/lib/design/tokens';
import type { QimenChart } from '@/lib/qimen/types';

/** 9 宫的视觉位置（3×3 网格，按方位） */
const VISUAL_GRID: number[][] = [
  [4, 9, 2],   // 巽 离 坤
  [3, 5, 7],   // 震 中 兑
  [8, 1, 6],   // 艮 坎 乾
];

type Props = { chart: QimenChart };

export function FullChart9({ chart }: Props) {
  const xiongPalaceIds = new Set(
    chart.geJu
      .filter(g => g.type === '凶')
      .flatMap(g => g.palaceIds ?? []),
  );
  const yongShenId = chart.yongShen.palaceId;

  return (
    <View>
      <Text style={styles.title}>
        {chart.yinYangDun}遁 {chart.juNumber} 局 · {chart.jieqi}{chart.yuan}元
      </Text>
      <View style={styles.grid}>
        {VISUAL_GRID.map((row, rowIdx) => (
          <View key={rowIdx} style={styles.row}>
            {row.map(palaceId => {
              const p = chart.palaces.find(pp => pp.id === palaceId)!;
              const isYongShen = p.id === yongShenId;
              const isXiong = xiongPalaceIds.has(p.id);
              return (
                <View
                  key={p.id}
                  style={[
                    styles.cell,
                    isYongShen && styles.cellYongShen,
                    isXiong && !isYongShen && styles.cellXiong,
                  ]}
                >
                  <Text style={styles.palaceName}>
                    {p.name}({p.id})
                  </Text>
                  {p.tianPanGan && p.diPanGan && (
                    <Text style={styles.gan}>
                      {p.tianPanGan}/{p.diPanGan}
                    </Text>
                  )}
                  {p.bamen && <Text style={styles.line}>{p.bamen}</Text>}
                  {p.jiuxing && <Text style={styles.line}>{p.jiuxing}</Text>}
                  {p.bashen && <Text style={styles.line}>{p.bashen}</Text>}
                </View>
              );
            })}
          </View>
        ))}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  title: {
    ...Type.label,
    color: Colors.vermilion,
    textAlign: 'center',
    marginBottom: Space.sm,
    letterSpacing: 1,
  },
  grid: {
    gap: 2,
  },
  row: {
    flexDirection: 'row',
    gap: 2,
  },
  cell: {
    flex: 1,
    minHeight: 100,
    padding: 4,
    backgroundColor: Colors.bgSecondary,
    borderRadius: 4,
    alignItems: 'center',
    justifyContent: 'center',
  },
  cellYongShen: {
    borderWidth: 2,
    borderColor: Colors.vermilion,
  },
  cellXiong: {
    opacity: 0.5,
  },
  palaceName: {
    ...Type.caption,
    color: Colors.ink,
    fontWeight: '600',
  },
  gan: {
    fontFamily: 'Georgia',
    fontSize: 11,
    color: Colors.vermilion,
    marginTop: 2,
  },
  line: {
    fontSize: 10,
    color: Colors.inkSecondary,
    marginTop: 1,
  },
});
