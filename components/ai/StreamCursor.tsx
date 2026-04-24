/**
 * 流式光标：末尾闪烁的 ▍
 */
import React, { useEffect } from 'react';
import { Text, StyleSheet } from 'react-native';
import Animated, {
  useSharedValue, useAnimatedStyle, withRepeat, withTiming, cancelAnimation,
} from 'react-native-reanimated';
import { Colors, Type } from '@/lib/design/tokens';

const AnimatedText = Animated.createAnimatedComponent(Text);

export function StreamCursor() {
  const opacity = useSharedValue(1);

  useEffect(() => {
    opacity.value = withRepeat(
      withTiming(0.2, { duration: 500 }),
      -1,
      true,
    );
    return () => cancelAnimation(opacity);
  }, [opacity]);

  const style = useAnimatedStyle(() => ({ opacity: opacity.value }));

  return <AnimatedText style={[styles.cursor, style]}>▍</AnimatedText>;
}

const styles = StyleSheet.create({
  cursor: {
    ...Type.body,
    color: Colors.vermilion,
    fontWeight: '300',
  },
});
