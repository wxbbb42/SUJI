/**
 * Onboarding — Neo-Tactile Warmth 引导流程
 *
 * 三页：品牌印象 → 核心价值 → 开始
 * 动画：Reanimated ScrollHandler 驱动进度点插值 + 按钮 scale
 */

import React from 'react';
import {
  StyleSheet, View, Text, Pressable, Dimensions, Platform,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import Animated, {
  SharedValue,
  useSharedValue,
  useAnimatedStyle,
  useAnimatedScrollHandler,
  withSpring,
  interpolate,
  interpolateColor,
  Extrapolation,
} from 'react-native-reanimated';
import { useRouter } from 'expo-router';
import { Colors, Space, Radius, Type, Shadow, Motion, Size } from '@/lib/design/tokens';
import { useUserStore } from '@/lib/store/userStore';

const { width: SW, height: SH } = Dimensions.get('window');

const serifFamily = Platform.select({
  ios: 'Georgia',
  android: 'serif',
  default: 'Georgia',
});

// ─── Animated progress dot ────────────────────────────────────────────────────

function ProgressDot({ index, scrollX }: { index: number; scrollX: SharedValue<number> }) {
  const dotStyle = useAnimatedStyle(() => {
    const range = [(index - 1) * SW, index * SW, (index + 1) * SW];
    return {
      width: interpolate(scrollX.value, range, [6, 24, 6], Extrapolation.CLAMP),
      backgroundColor: interpolateColor(
        scrollX.value,
        range,
        [Colors.border, Colors.vermilion, Colors.border],
      ) as string,
    };
  });
  return <Animated.View style={[styles.dot, dotStyle]} />;
}

// ─── Page 1: 品牌印象 ─────────────────────────────────────────────────────────

function PageBrand() {
  return (
    <View style={styles.page}>
      <View style={styles.brandCenter}>
        <Text style={styles.brandBigChar}>岁</Text>
        <Text style={styles.brandName}>有时</Text>
        <Text style={styles.brandSub}>顺时而行 · 从容而生</Text>
      </View>
    </View>
  );
}

// ─── Page 2: 核心价值 ─────────────────────────────────────────────────────────

const VALUE_ITEMS = [
  { accent: Colors.vermilion, text: '千年智慧，现代语言' },
  { accent: Colors.celadon,   text: '不预测未来，照亮当下' },
  { accent: Colors.amber,     text: '每一天的节奏，为你而设' },
] as const;

function PageValue() {
  return (
    <View style={styles.page}>
      <View style={styles.valueCenter}>
        <View style={[styles.decorCircle, Shadow.sm]}>
          <Text style={styles.decorGlyph}>子</Text>
        </View>
        <Text style={styles.valueTitle}>读懂你的时间</Text>
        <View style={styles.valueList}>
          {VALUE_ITEMS.map(({ accent, text }) => (
            <View key={text} style={styles.valueRow}>
              <View style={[styles.valueDot, { backgroundColor: accent }]} />
              <Text style={styles.valueText}>{text}</Text>
            </View>
          ))}
        </View>
      </View>
    </View>
  );
}

// ─── Page 3: 开始 ─────────────────────────────────────────────────────────────

function PageStart({ onStart }: { onStart: () => void }) {
  const scale = useSharedValue(1);
  const animStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
  }));

  return (
    <View style={styles.page}>
      <View style={styles.startCenter}>
        <Text style={styles.startTitle}>准备好了吗？</Text>
        <Text style={styles.startSub}>输入你的生辰，开启专属命盘</Text>
        <Animated.View style={[styles.startBtnWrap, Shadow.md, animStyle]}>
          <Pressable
            style={styles.startBtn}
            onPress={onStart}
            onPressIn={() => { scale.value = withSpring(0.96, Motion.quick); }}
            onPressOut={() => { scale.value = withSpring(1, Motion.quick); }}
          >
            <Text style={styles.startBtnText}>开始</Text>
          </Pressable>
        </Animated.View>
      </View>
    </View>
  );
}

// ─── Screen ───────────────────────────────────────────────────────────────────

export default function OnboardingScreen() {
  const router = useRouter();
  const { birthDate } = useUserStore();
  const scrollX = useSharedValue(0);

  const scrollHandler = useAnimatedScrollHandler((event) => {
    scrollX.value = event.contentOffset.x;
  });

  const handleStart = () => {
    useUserStore.getState().setHasOnboarded();
    router.replace('/auth');
  };

  const skip = () => {
    useUserStore.getState().setHasOnboarded();
    router.replace(birthDate ? '/(tabs)' : '/auth');
  };

  return (
    <SafeAreaView style={styles.container} edges={['top', 'bottom']}>
      {/* 跳过 */}
      <Pressable style={styles.skipBtn} onPress={skip} hitSlop={16}>
        <Text style={styles.skipText}>跳过</Text>
      </Pressable>

      {/* 三页 */}
      <Animated.ScrollView
        horizontal
        pagingEnabled
        showsHorizontalScrollIndicator={false}
        onScroll={scrollHandler}
        scrollEventThrottle={16}
        style={styles.pager}
      >
        <PageBrand />
        <PageValue />
        <PageStart onStart={handleStart} />
      </Animated.ScrollView>

      {/* 进度点 */}
      <View style={styles.footer}>
        <View style={styles.dots}>
          {[0, 1, 2].map((i) => (
            <ProgressDot key={i} index={i} scrollX={scrollX} />
          ))}
        </View>
      </View>
    </SafeAreaView>
  );
}

// ─── Styles ───────────────────────────────────────────────────────────────────

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.bg,
  },

  // 跳过
  skipBtn: {
    position: 'absolute',
    top: Space.md,
    right: Space.lg,
    zIndex: 10,
    padding: Space.sm,
  },
  skipText: {
    ...Type.caption,
    color: Colors.inkTertiary,
  },

  // Pager
  pager: {
    flex: 1,
  },
  page: {
    width: SW,
    height: SH,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: Space['2xl'],
  },

  // ── 品牌页 ──
  brandCenter: {
    alignItems: 'center',
    gap: Space.lg,
  },
  brandBigChar: {
    fontFamily: serifFamily,
    fontSize: 120,
    lineHeight: 132,
    color: Colors.ink,
    fontWeight: '400',
  },
  brandName: {
    fontFamily: serifFamily,
    fontSize: 28,
    lineHeight: 36,
    color: Colors.ink,
    fontWeight: '400',
    letterSpacing: 12,
  },
  brandSub: {
    ...Type.caption,
    color: Colors.inkTertiary,
    letterSpacing: 4,
  },

  // ── 价值页 ──
  valueCenter: {
    alignItems: 'center',
    width: '100%',
  },
  decorCircle: {
    width: 80,
    height: 80,
    borderRadius: 40,
    backgroundColor: Colors.brandBg,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: Space['2xl'],
  },
  decorGlyph: {
    fontFamily: serifFamily,
    fontSize: 32,
    color: Colors.vermilion,
    fontWeight: '400',
  },
  valueTitle: {
    ...Type.title,
    color: Colors.ink,
    marginBottom: Space['2xl'],
  },
  valueList: {
    gap: Space.xl,
    width: '100%',
    paddingHorizontal: Space.lg,
  },
  valueRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Space.md,
  },
  valueDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    flexShrink: 0,
  },
  valueText: {
    ...Type.bodySmall,
    color: Colors.inkSecondary,
    lineHeight: 26,
  },

  // ── 开始页 ──
  startCenter: {
    alignItems: 'center',
    gap: Space['2xl'],
    width: '100%',
  },
  startTitle: {
    fontFamily: serifFamily,
    fontSize: 32,
    lineHeight: 44,
    color: Colors.ink,
    fontWeight: '400',
    letterSpacing: 1,
    textAlign: 'center',
  },
  startSub: {
    ...Type.body,
    color: Colors.inkSecondary,
    textAlign: 'center',
  },
  startBtnWrap: {
    width: SW - Space['2xl'] * 2,
    borderRadius: Radius.full,
  },
  startBtn: {
    height: Size.buttonLg,
    borderRadius: Radius.full,
    backgroundColor: Colors.vermilion,
    alignItems: 'center',
    justifyContent: 'center',
  },
  startBtnText: {
    color: Colors.surface,
    fontFamily: serifFamily,
    fontSize: 17,
    fontWeight: '400',
    letterSpacing: 6,
  },

  // ── Footer ──
  footer: {
    paddingVertical: Space.xl,
    alignItems: 'center',
  },
  dots: {
    flexDirection: 'row',
    gap: Space.md,
    alignItems: 'center',
  },
  dot: {
    height: 6,
    borderRadius: Radius.full,
  },
});
