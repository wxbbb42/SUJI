/**
 * 静态卦象组件（用于历史消息回显，无入场动画）
 *
 * 视觉：6 横线（阴爻断、阳爻实）+ 动爻朱砂圆点 + 卦名标题（变卦时带箭头）
 * 朱砂主色，灰底，与起卦动画完成态视觉一致
 */
import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { Colors, Space, Type } from '@/lib/design/tokens';
import type { GuaInfo } from '@/lib/divination/types';

type Props = {
  benGua: GuaInfo;
  bianGua: GuaInfo;
  changingYao: number[];      // 1-6
};

export function HexagramDisplay({ benGua, bianGua, changingYao }: Props) {
  // 由上往下渲染（上爻在顶部，初爻在底部）
  const yaoTopDown = [...benGua.yao].reverse();
  const indicesTopDown = [6, 5, 4, 3, 2, 1];

  return (
    <View style={styles.container}>
      <View style={styles.yaoStack}>
        {yaoTopDown.map((yao, i) => {
          const yaoIndex = indicesTopDown[i];
          const isChanging = changingYao.includes(yaoIndex);
          return (
            <View key={yaoIndex} style={styles.yaoRow}>
              {yao === '阳' ? (
                <View style={styles.yaoSolid} />
              ) : (
                <View style={styles.yaoBroken}>
                  <View style={styles.yaoBrokenHalf} />
                  <View style={styles.yaoBrokenHalf} />
                </View>
              )}
              {isChanging && <View style={styles.changingDot} />}
            </View>
          );
        })}
      </View>

      <Text style={styles.title}>
        {benGua.name}
        {bianGua.code !== benGua.code && (
          <>
            <Text style={styles.arrow}>  →  </Text>
            {bianGua.name}
          </>
        )}
      </Text>
    </View>
  );
}

const YAO_WIDTH = 80;
const YAO_HEIGHT = 6;
const YAO_GAP = 4;

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
    paddingVertical: Space.md,
    backgroundColor: Colors.bgSecondary,
    borderRadius: 8,
    marginVertical: Space.sm,
  },
  yaoStack: {
    gap: YAO_GAP,
  },
  yaoRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  yaoSolid: {
    width: YAO_WIDTH,
    height: YAO_HEIGHT,
    backgroundColor: Colors.vermilion,
    borderRadius: 1,
  },
  yaoBroken: {
    flexDirection: 'row',
    width: YAO_WIDTH,
    height: YAO_HEIGHT,
    gap: YAO_HEIGHT * 2,
  },
  yaoBrokenHalf: {
    flex: 1,
    backgroundColor: Colors.vermilion,
    borderRadius: 1,
  },
  changingDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: Colors.vermilion,
  },
  title: {
    ...Type.body,
    color: Colors.ink,
    marginTop: Space.sm,
    fontWeight: '500',
    letterSpacing: 2,
  },
  arrow: {
    color: Colors.inkTertiary,
  },
});
