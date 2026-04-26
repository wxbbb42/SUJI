/**
 * 起局动画（3.3 秒，9 宫框架先成型，5 层信息自外而内落位）
 *
 * 用 fade + scale 入场，复用 FullChart9 显示数据
 */
import React, { useEffect } from 'react';
import { View, StyleSheet } from 'react-native';
import Animated, {
  useSharedValue, useAnimatedStyle, withDelay, withTiming,
} from 'react-native-reanimated';
import { Colors, Space, Type } from '@/lib/design/tokens';
import type { QimenChart } from '@/lib/qimen/types';
import { FullChart9 } from './FullChart9';

const TOTAL = 3300;

type Props = {
  chart: QimenChart;
  onComplete?: () => void;
};

export function QimenSetupAnimation({ chart, onComplete }: Props) {
  const opacity = useSharedValue(0);
  const scale = useSharedValue(0.85);
  const titleOpacity = useSharedValue(0);

  useEffect(() => {
    opacity.value = withTiming(1, { duration: 600 });
    scale.value = withDelay(200, withTiming(1, { duration: 1500 }));
    titleOpacity.value = withDelay(2700, withTiming(1, { duration: 400 }));
    const t = setTimeout(() => onComplete?.(), TOTAL);
    return () => clearTimeout(t);
  }, []);

  const containerStyle = useAnimatedStyle(() => ({
    opacity: opacity.value,
    transform: [{ scale: scale.value }],
  }));

  const titleStyle = useAnimatedStyle(() => ({
    opacity: titleOpacity.value,
  }));

  return (
    <View style={styles.container}>
      <Animated.View style={containerStyle}>
        <FullChart9 chart={chart} />
      </Animated.View>
      <Animated.Text style={[styles.title, titleStyle]}>
        布盘九宫 · {chart.yinYangDun}遁 {chart.juNumber} 局
      </Animated.Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    paddingVertical: Space.md,
  },
  title: {
    ...Type.label,
    color: Colors.vermilion,
    textAlign: 'center',
    letterSpacing: 2,
    marginTop: Space.xs,
  },
});
