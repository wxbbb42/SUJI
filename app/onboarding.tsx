/**
 * Onboarding 引导流程
 *
 * 三页：品牌印象 → 核心价值 → 开始
 * Neo-Tactile Warmth 设计
 */

import React, { useState, useRef, useCallback } from 'react';
import {
  StyleSheet, View, Text, Pressable, Dimensions,
  ScrollView, NativeSyntheticEvent, NativeScrollEvent,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import Animated, {
  useSharedValue, useAnimatedStyle, withSpring,
} from 'react-native-reanimated';
import { useRouter } from 'expo-router';
import { Colors, Space, Radius, Type, Shadow, Motion, Size } from '@/lib/design/tokens';
import { useUserStore } from '@/lib/store/userStore';

const { width: SW } = Dimensions.get('window');

const AnimatedPressable = Animated.createAnimatedComponent(Pressable);

export default function OnboardingScreen() {
  const router = useRouter();
  const insets = useSafeAreaInsets();
  const scrollRef = useRef<ScrollView>(null);
  const [page, setPage] = useState(0);
  const { birthDate } = useUserStore();

  const handleScroll = (e: NativeSyntheticEvent<NativeScrollEvent>) => {
    setPage(Math.round(e.nativeEvent.contentOffset.x / SW));
  };

  const goNext = useCallback(() => {
    if (page < 2) {
      scrollRef.current?.scrollTo({ x: (page + 1) * SW, animated: true });
    } else {
      useUserStore.getState().setHasOnboarded();
      router.replace('/auth');
    }
  }, [page, router]);

  const skip = useCallback(() => {
    useUserStore.getState().setHasOnboarded();
    router.replace(birthDate ? '/(tabs)' : '/auth');
  }, [birthDate, router]);

  return (
    <View style={[styles.container, { paddingTop: insets.top }]}>
      {/* 跳过 */}
      <Pressable style={styles.skipBtn} onPress={skip} hitSlop={16}>
        <Text style={styles.skipText}>跳过</Text>
      </Pressable>

      {/* 页面 */}
      <ScrollView
        ref={scrollRef}
        horizontal
        pagingEnabled
        showsHorizontalScrollIndicator={false}
        onMomentumScrollEnd={handleScroll}
        scrollEventThrottle={16}
      >
        <PageBrand />
        <PageValue />
        <PageStart onStart={goNext} />
      </ScrollView>

      {/* 底部导航 */}
      <View style={[styles.footer, { paddingBottom: insets.bottom + Space.lg }]}>
        <View style={styles.dots}>
          {[0, 1, 2].map(i => (
            <View
              key={i}
              style={[
                styles.dot,
                page === i && styles.dotActive,
              ]}
            />
          ))}
        </View>

        {page < 2 && (
          <Pressable style={styles.nextBtn} onPress={goNext} hitSlop={12}>
            <Text style={styles.nextText}>继续</Text>
          </Pressable>
        )}
      </View>
    </View>
  );
}

// ── 第 1 页：品牌印象 ─────────────────────────────

function PageBrand() {
  return (
    <View style={styles.page}>
      <View style={styles.brandCenter}>
        <Text style={styles.brandBigChar}>岁</Text>
        <Text style={styles.brandName}>岁吉</Text>
        <Text style={styles.brandSub}>顺时而行 · 从容而生</Text>
      </View>
    </View>
  );
}

// ── 第 2 页：核心价值 ─────────────────────────────

function PageValue() {
  const values = [
    { color: Colors.vermilion, text: '千年智慧，现代语言' },
    { color: Colors.celadon,   text: '不预测未来，照亮当下' },
    { color: Colors.amber,     text: '每一天的节奏，为你而设' },
  ];

  return (
    <View style={styles.page}>
      <View style={styles.valueCenter}>
        {/* 装饰圆 */}
        <View style={styles.decorCircle}>
          <Text style={styles.decorText}>干支</Text>
        </View>

        <Text style={styles.valueTitle}>读懂你的时间</Text>

        <View style={styles.valueList}>
          {values.map((v, i) => (
            <View key={i} style={styles.valueRow}>
              <View style={[styles.valueDot, { backgroundColor: v.color }]} />
              <Text style={styles.valueText}>{v.text}</Text>
            </View>
          ))}
        </View>
      </View>
    </View>
  );
}

// ── 第 3 页：开始 ─────────────────────────────────

function PageStart({ onStart }: { onStart: () => void }) {
  const scale = useSharedValue(1);

  const animStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
  }));

  const handlePressIn = () => {
    scale.value = withSpring(0.95, Motion.quick);
  };
  const handlePressOut = () => {
    scale.value = withSpring(1, Motion.quick);
  };

  return (
    <View style={styles.page}>
      <View style={styles.startCenter}>
        <Text style={styles.startTitle}>准备好了吗？</Text>
        <Text style={styles.startSub}>输入你的生辰{'\n'}开启专属命盘</Text>

        <AnimatedPressable
          style={[styles.startBtn, Shadow.md, animStyle]}
          onPress={onStart}
          onPressIn={handlePressIn}
          onPressOut={handlePressOut}
        >
          <Text style={styles.startBtnText}>开始</Text>
        </AnimatedPressable>
      </View>
    </View>
  );
}

// ── Styles ────────────────────────────────────────

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.bg,
  },

  // 跳过
  skipBtn: {
    position: 'absolute',
    top: 60,
    right: Space.lg,
    zIndex: 10,
    padding: Space.sm,
  },
  skipText: {
    ...Type.bodySmall,
    color: Colors.inkTertiary,
  },

  // 页面
  page: {
    width: SW,
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: Space['3xl'],
  },

  // 品牌页
  brandCenter: {
    alignItems: 'center',
  },
  brandBigChar: {
    fontFamily: 'Georgia',
    fontSize: 120,
    color: Colors.ink,
    fontWeight: '300',
    marginBottom: Space.sm,
  },
  brandName: {
    fontFamily: 'Georgia',
    fontSize: 24,
    color: Colors.ink,
    fontWeight: '400',
    letterSpacing: 12,
    marginBottom: Space.md,
  },
  brandSub: {
    ...Type.caption,
    color: Colors.inkTertiary,
    letterSpacing: 4,
  },

  // 价值页
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
  decorText: {
    fontFamily: 'Georgia',
    fontSize: 18,
    color: Colors.vermilion,
    fontWeight: '400',
  },
  valueTitle: {
    ...Type.title,
    color: Colors.ink,
    marginBottom: Space['2xl'],
  },
  valueList: {
    gap: Space.lg,
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
  },
  valueText: {
    ...Type.body,
    color: Colors.inkSecondary,
  },

  // 开始页
  startCenter: {
    alignItems: 'center',
  },
  startTitle: {
    ...Type.title,
    color: Colors.ink,
    marginBottom: Space.lg,
  },
  startSub: {
    ...Type.body,
    color: Colors.inkTertiary,
    textAlign: 'center',
    lineHeight: 26,
    marginBottom: Space['3xl'],
  },
  startBtn: {
    backgroundColor: Colors.vermilion,
    borderRadius: Radius.full,
    paddingVertical: Space.base,
    paddingHorizontal: Space['4xl'],
    height: Size.buttonLg,
    justifyContent: 'center',
    alignItems: 'center',
  },
  startBtnText: {
    ...Type.body,
    color: '#FFFFFF',
    fontWeight: '600',
    letterSpacing: 4,
  },

  // 底部
  footer: {
    alignItems: 'center',
    gap: Space.xl,
    paddingTop: Space.lg,
  },
  dots: {
    flexDirection: 'row',
    gap: Space.sm,
    alignItems: 'center',
  },
  dot: {
    width: 6,
    height: 6,
    borderRadius: 3,
    backgroundColor: Colors.border,
  },
  dotActive: {
    width: 24,
    backgroundColor: Colors.vermilion,
    borderRadius: 3,
  },
  nextBtn: {
    paddingVertical: Space.md,
    paddingHorizontal: Space['2xl'],
  },
  nextText: {
    ...Type.body,
    color: Colors.vermilion,
    fontWeight: '500',
  },
});
