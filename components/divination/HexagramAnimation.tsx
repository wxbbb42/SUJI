/**
 * 起卦动画（3 秒，自下而上 6 爻入场）
 *
 * 视觉：朱砂铜钱意象 + 卦位虚线轮廓
 * - T=0: 6 条灰虚线浮现
 * - T=0.5: 初爻浮现 3 颗朱砂圆点
 * - T=0.7-3.0: 自下而上每爻定型成阴/阳/动
 */
import React, { useEffect } from 'react';
import { View, StyleSheet } from 'react-native';
import Animated, {
  useSharedValue, useAnimatedStyle, withTiming, withDelay,
} from 'react-native-reanimated';
import { Colors, Space, Type } from '@/lib/design/tokens';
import type { GuaInfo } from '@/lib/divination/types';

type Props = {
  benGua: GuaInfo;
  bianGua: GuaInfo;
  changingYao: number[];
  onComplete?: () => void;
};

const TOTAL_DURATION = 3000;
const YAO_INTERVAL = 400;

export function HexagramAnimation({ benGua, bianGua, changingYao, onComplete }: Props) {
  // 由下往上的爻索引（1-6）
  const yaoBottomUp = benGua.yao.map((y, i) => ({
    yao: y,
    index: i + 1,
    isChanging: changingYao.includes(i + 1),
  }));

  // 标题在最后浮现
  const titleOpacity = useSharedValue(0);
  useEffect(() => {
    titleOpacity.value = withDelay(
      TOTAL_DURATION,
      withTiming(1, { duration: 300 }),
    );
    const t = setTimeout(() => onComplete?.(), TOTAL_DURATION + 300);
    return () => clearTimeout(t);
  }, []);

  const titleStyle = useAnimatedStyle(() => ({ opacity: titleOpacity.value }));

  return (
    <View style={styles.container}>
      <View style={styles.yaoStack}>
        {/* 由下到上构建，但视觉顺序：上爻在顶 */}
        {[...yaoBottomUp].reverse().map((y, displayIdx) => {
          // displayIdx: 0=top (上爻), 5=bottom (初爻)
          // 实际入场顺序：初爻先（index=1），上爻后（index=6）
          const enterOrder = y.index - 1;     // 0..5
          return (
            <YaoRow
              key={y.index}
              yao={y.yao}
              isChanging={y.isChanging}
              delay={500 + enterOrder * YAO_INTERVAL}
            />
          );
        })}
      </View>

      <Animated.Text style={[styles.title, titleStyle]}>
        {benGua.name}
        {bianGua.code !== benGua.code ? `  →  ${bianGua.name}` : ''}
      </Animated.Text>
    </View>
  );
}

function YaoRow({ yao, isChanging, delay }: { yao: '阴'|'阳'; isChanging: boolean; delay: number }) {
  const opacity = useSharedValue(0);
  const scale = useSharedValue(0.7);

  useEffect(() => {
    opacity.value = withDelay(delay, withTiming(1, { duration: 300 }));
    scale.value = withDelay(delay, withTiming(1, { duration: 300 }));
  }, []);

  const aStyle = useAnimatedStyle(() => ({
    opacity: opacity.value,
    transform: [{ scale: scale.value }],
  }));

  return (
    <Animated.View style={[styles.yaoRow, aStyle]}>
      {yao === '阳' ? (
        <View style={styles.yaoSolid} />
      ) : (
        <View style={styles.yaoBroken}>
          <View style={styles.yaoBrokenHalf} />
          <View style={styles.yaoBrokenHalf} />
        </View>
      )}
      {isChanging && <View style={styles.changingDot} />}
    </Animated.View>
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
});
