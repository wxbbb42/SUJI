// components/calibration/ThinkingDots.tsx
import React, { useEffect } from 'react';
import { View, StyleSheet } from 'react-native';
import Animated, { useSharedValue, useAnimatedStyle, withRepeat, withSequence, withTiming } from 'react-native-reanimated';
import { Colors, Space } from '@/lib/design/tokens';

const Dot = ({ delay }: { delay: number }) => {
  const opacity = useSharedValue(0.2);
  useEffect(() => {
    opacity.value = withRepeat(
      withSequence(
        withTiming(1, { duration: 400 }),
        withTiming(0.2, { duration: 400 }),
      ),
      -1,
      false,
    );
  }, [opacity]);
  const style = useAnimatedStyle(() => ({ opacity: opacity.value }));
  return <Animated.View style={[styles.dot, style, { marginLeft: delay > 0 ? 4 : 0 }]} />;
};

export function ThinkingDots() {
  return (
    <View style={styles.row}>
      <Dot delay={0} />
      <Dot delay={1} />
      <Dot delay={2} />
    </View>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: 'row', alignItems: 'center', paddingVertical: Space.xs },
  dot: { width: 6, height: 6, borderRadius: 3, backgroundColor: Colors.inkSecondary },
});
