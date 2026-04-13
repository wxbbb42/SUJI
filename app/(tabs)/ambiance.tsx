/**
 * 静心页面
 *
 * 节气音景 + 呼吸引导
 * Neo-Tactile Warmth 设计
 */

import React, { useState } from 'react';
import {
  StyleSheet, View, Text, Pressable, ScrollView,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import Animated, {
  useSharedValue, useAnimatedStyle, withSpring, withRepeat, withSequence, withTiming,
} from 'react-native-reanimated';
import { Colors, Space, Radius, Type, Shadow, Motion } from '@/lib/design/tokens';

const AnimatedPressable = Animated.createAnimatedComponent(Pressable);

const SOUNDSCAPES = [
  { id: 'rain',    name: '谷雨听雨',   emoji: '🌧',  season: '春' },
  { id: 'thunder', name: '惊蛰听雷',   emoji: '⚡',  season: '春' },
  { id: 'wind',    name: '秋风落叶',   emoji: '🍂',  season: '秋' },
  { id: 'fire',    name: '冬至炉火',   emoji: '🔥',  season: '冬' },
  { id: 'cicada',  name: '小暑蝉鸣',   emoji: '🦗',  season: '夏' },
  { id: 'stream',  name: '山间溪流',   emoji: '💧',  season: '四季' },
];

export default function AmbianceScreen() {
  const insets = useSafeAreaInsets();
  const [playing, setPlaying] = useState<string | null>(null);
  const [breathing, setBreathing] = useState(false);

  // 呼吸圈动画
  const breathScale = useSharedValue(1);
  const breathOpacity = useSharedValue(0.3);

  const breathAnim = useAnimatedStyle(() => ({
    transform: [{ scale: breathScale.value }],
    opacity: breathOpacity.value,
  }));

  const toggleBreathing = () => {
    if (breathing) {
      setBreathing(false);
      breathScale.value = withSpring(1, Motion.gentle);
      breathOpacity.value = withTiming(0.3, { duration: 300 });
    } else {
      setBreathing(true);
      // 4秒吸气(放大) → 4秒呼气(缩小) 循环
      breathScale.value = withRepeat(
        withSequence(
          withTiming(1.4, { duration: 4000 }),
          withTiming(1, { duration: 4000 }),
        ),
        -1, // 无限循环
      );
      breathOpacity.value = withRepeat(
        withSequence(
          withTiming(0.6, { duration: 4000 }),
          withTiming(0.3, { duration: 4000 }),
        ),
        -1,
      );
    }
  };

  return (
    <ScrollView
      style={[styles.container, { paddingTop: insets.top }]}
      contentContainerStyle={[styles.scroll, { paddingBottom: insets.bottom + 100 }]}
      showsVerticalScrollIndicator={false}
    >
      {/* 呼吸引导 */}
      <View style={styles.breathArea}>
        <Pressable onPress={toggleBreathing} style={styles.breathCenter}>
          <Animated.View style={[styles.breathCircleOuter, breathAnim]} />
          <View style={styles.breathCircleInner}>
            <Text style={styles.breathChar}>
              {breathing ? '息' : '静'}
            </Text>
          </View>
        </Pressable>
        <Text style={styles.breathHint}>
          {breathing ? '跟随节奏呼吸' : '点击开始呼吸引导'}
        </Text>
        {breathing && (
          <Text style={styles.breathCycle}>4秒吸气 · 4秒呼气</Text>
        )}
      </View>

      {/* 节气音景 */}
      <Text style={styles.sectionTitle}>节气音景</Text>
      <Text style={styles.sectionSub}>闭上眼，感受此刻</Text>

      <View style={styles.soundGrid}>
        {SOUNDSCAPES.map((sound) => {
          const active = playing === sound.id;
          return (
            <SoundCard
              key={sound.id}
              {...sound}
              active={active}
              onPress={() => setPlaying(active ? null : sound.id)}
            />
          );
        })}
      </View>
    </ScrollView>
  );
}

function SoundCard({
  name, emoji, season, active, onPress,
}: {
  name: string; emoji: string; season: string;
  active: boolean; onPress: () => void;
}) {
  const scale = useSharedValue(1);
  const animStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
  }));

  return (
    <AnimatedPressable
      style={[
        styles.soundCard,
        active && styles.soundCardActive,
        Shadow.sm,
        animStyle,
      ]}
      onPress={onPress}
      onPressIn={() => { scale.value = withSpring(0.95, Motion.quick); }}
      onPressOut={() => { scale.value = withSpring(1, Motion.quick); }}
    >
      <Text style={styles.soundEmoji}>{emoji}</Text>
      <Text style={[styles.soundName, active && styles.soundNameActive]}>{name}</Text>
      <Text style={[styles.soundSeason, active && styles.soundSeasonActive]}>{season}</Text>
    </AnimatedPressable>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.bg },
  scroll: { paddingHorizontal: Space.lg },

  // 呼吸引导
  breathArea: {
    alignItems: 'center',
    paddingVertical: Space['4xl'],
  },
  breathCenter: {
    width: 160,
    height: 160,
    alignItems: 'center',
    justifyContent: 'center',
  },
  breathCircleOuter: {
    position: 'absolute',
    width: 160,
    height: 160,
    borderRadius: 80,
    backgroundColor: Colors.brandBg,
  },
  breathCircleInner: {
    width: 80,
    height: 80,
    borderRadius: 40,
    backgroundColor: Colors.surface,
    alignItems: 'center',
    justifyContent: 'center',
    ...Shadow.md,
  },
  breathChar: {
    fontFamily: 'Georgia',
    fontSize: 28,
    color: Colors.vermilion,
    fontWeight: '400',
  },
  breathHint: {
    ...Type.body,
    color: Colors.inkTertiary,
    marginTop: Space.xl,
  },
  breathCycle: {
    ...Type.caption,
    color: Colors.inkHint,
    marginTop: Space.sm,
  },

  // 音景
  sectionTitle: {
    ...Type.subtitle,
    color: Colors.ink,
  },
  sectionSub: {
    ...Type.caption,
    color: Colors.inkHint,
    marginTop: Space.xs,
    marginBottom: Space.lg,
  },
  soundGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: Space.md,
  },
  soundCard: {
    width: '47%',
    backgroundColor: Colors.surface,
    borderRadius: Radius.lg,
    padding: Space.lg,
    alignItems: 'center',
    gap: Space.sm,
  },
  soundCardActive: {
    backgroundColor: Colors.brandBg,
  },
  soundEmoji: {
    fontSize: 28,
  },
  soundName: {
    ...Type.bodySmall,
    color: Colors.ink,
    fontWeight: '500',
  },
  soundNameActive: {
    color: Colors.vermilion,
  },
  soundSeason: {
    ...Type.label,
    color: Colors.inkHint,
  },
  soundSeasonActive: {
    color: Colors.vermilion,
  },
});
