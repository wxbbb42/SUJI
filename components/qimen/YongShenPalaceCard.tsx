/**
 * 用神宫聚焦卡（主气泡里的奇门主显示）
 *
 * 视觉：朱砂边框框住 用神宫 5 层信息
 */
import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { Colors, Space, Radius, Type, Shadow } from '@/lib/design/tokens';
import type { Palace, YongShenAnalysis } from '@/lib/qimen/types';

type Props = {
  palace: Palace;
  yongShen: YongShenAnalysis;
};

export function YongShenPalaceCard({ palace, yongShen }: Props) {
  return (
    <View style={[styles.card, Shadow.sm]}>
      <Text style={styles.title}>用神宫 · {palace.name}（{palace.id}）</Text>
      <View style={styles.divider} />
      <Text style={styles.gan}>
        {palace.tianPanGan ?? '？'}（天） / {palace.diPanGan ?? '？'}（地）
      </Text>
      <Text style={styles.menStarShen}>
        {palace.bamen ?? '无门'} · {palace.jiuxing} · {palace.bashen ?? '无神'}
      </Text>
      <Text style={styles.summary}>{yongShen.summary}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: Colors.bgSecondary,
    borderRadius: Radius.md,
    padding: Space.base,
    borderWidth: 2,
    borderColor: Colors.vermilion,
    marginVertical: Space.sm,
  },
  title: {
    ...Type.label,
    color: Colors.vermilion,
    letterSpacing: 1,
  },
  divider: {
    height: StyleSheet.hairlineWidth,
    backgroundColor: Colors.border,
    marginVertical: Space.xs,
  },
  gan: {
    ...Type.body,
    color: Colors.ink,
    fontFamily: 'Georgia',
    fontWeight: '500',
  },
  menStarShen: {
    ...Type.bodySmall,
    color: Colors.inkSecondary,
    marginTop: 4,
  },
  summary: {
    ...Type.caption,
    color: Colors.inkTertiary,
    marginTop: Space.xs,
    fontStyle: 'italic',
  },
});
