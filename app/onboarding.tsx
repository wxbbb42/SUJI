/**
 * Onboarding 欢迎流程
 *
 * 三页引导 → 登录/注册 → 生辰输入 → 命盘生成
 *
 * 设计理念：
 * - 每页只有一个大字 + 一句话，极简
 * - 水墨风过渡，不用花哨动画
 * - 最后一页自然引导到登录
 */

import React, { useState, useRef } from 'react';
import {
  StyleSheet, View, Text, Pressable, Dimensions,
  ScrollView, NativeSyntheticEvent, NativeScrollEvent,
  Platform,
} from 'react-native';
import { useRouter } from 'expo-router';
import { Colors, Space, Type } from '@/lib/design/tokens';
import { useUserStore } from '@/lib/store/userStore';

const { width: SCREEN_W, height: SCREEN_H } = Dimensions.get('window');

interface OnboardPage {
  bigChar: string;       // 大字视觉锚点
  title: string;         // 标题
  body: string;          // 正文
  footnote?: string;     // 底部小字
}

const PAGES: OnboardPage[] = [
  {
    bigChar: '岁',
    title: '时间有纹理',
    body: '每一年、每一天、每一个时辰\n都有属于你的能量节奏',
    footnote: '— 岁吉 —',
  },
  {
    bigChar: '知',
    title: '认识自己',
    body: '千年命理智慧\n用现代语言重新讲述\n不预测未来，只照亮当下',
  },
  {
    bigChar: '行',
    title: '顺势而为',
    body: '知道何时进、何时退\n每一天都活得更从容',
  },
];

export default function OnboardingScreen() {
  const router = useRouter();
  const scrollRef = useRef<ScrollView>(null);
  const [currentPage, setCurrentPage] = useState(0);
  const { birthDate } = useUserStore();

  const handleScroll = (e: NativeSyntheticEvent<NativeScrollEvent>) => {
    const page = Math.round(e.nativeEvent.contentOffset.x / SCREEN_W);
    setCurrentPage(page);
  };

  const goNext = () => {
    if (currentPage < PAGES.length - 1) {
      scrollRef.current?.scrollTo({ x: (currentPage + 1) * SCREEN_W, animated: true });
    } else {
      // 最后一页 → 标记完成 + 进入登录
      useUserStore.getState().setHasOnboarded();
      router.replace('/auth');
    }
  };

  const skip = () => {
    useUserStore.getState().setHasOnboarded();
    if (birthDate) {
      router.replace('/(tabs)');
    } else {
      router.replace('/auth');
    }
  };

  return (
    <View style={styles.container}>
      {/* 跳过按钮 */}
      <Pressable style={styles.skipBtn} onPress={skip}>
        <Text style={styles.skipText}>跳过</Text>
      </Pressable>

      {/* 引导页 */}
      <ScrollView
        ref={scrollRef}
        horizontal
        pagingEnabled
        showsHorizontalScrollIndicator={false}
        onMomentumScrollEnd={handleScroll}
        style={styles.pager}
      >
        {PAGES.map((page, i) => (
          <View key={i} style={styles.page}>
            {/* 大字 */}
            <Text style={styles.bigChar}>{page.bigChar}</Text>

            {/* 内容 */}
            <View style={styles.content}>
              <Text style={styles.title}>{page.title}</Text>
              <Text style={styles.body}>{page.body}</Text>
              {page.footnote && (
                <Text style={styles.footnote}>{page.footnote}</Text>
              )}
            </View>
          </View>
        ))}
      </ScrollView>

      {/* 底部：进度指示 + 按钮 */}
      <View style={styles.footer}>
        {/* 点状进度 */}
        <View style={styles.dots}>
          {PAGES.map((_, i) => (
            <View
              key={i}
              style={[styles.dot, currentPage === i && styles.dotActive]}
            />
          ))}
        </View>

        {/* 下一步按钮 */}
        <Pressable style={styles.nextBtn} onPress={goNext}>
          <Text style={styles.nextText}>
            {currentPage === PAGES.length - 1 ? '开始' : '继续'}
          </Text>
        </Pressable>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.bg,
  },

  // 跳过
  skipBtn: {
    position: 'absolute',
    top: Platform.OS === 'ios' ? 60 : 40,
    right: Space.lg,
    zIndex: 10,
    paddingVertical: Space.sm,
    paddingHorizontal: Space.md,
  },
  skipText: {
    ...Type.caption,
    color: Colors.inkHint,
    letterSpacing: 2,
  },

  // 分页器
  pager: {
    flex: 1,
  },
  page: {
    width: SCREEN_W,
    height: SCREEN_H,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: Space.xl,
  },

  // 大字 — 视觉锚点
  bigChar: {
    fontSize: 160,
    color: Colors.ink,
    fontWeight: '100',
    opacity: 0.08,
    position: 'absolute',
    top: SCREEN_H * 0.15,
  },

  // 内容
  content: {
    alignItems: 'center',
    paddingHorizontal: Space.lg,
  },
  title: {
    fontSize: 28,
    color: Colors.ink,
    fontWeight: '300',
    letterSpacing: 6,
    marginBottom: Space.lg,
    textAlign: 'center',
  },
  body: {
    ...Type.body,
    color: Colors.inkSecondary,
    textAlign: 'center',
    lineHeight: 28,
    letterSpacing: 1,
  },
  footnote: {
    ...Type.caption,
    color: Colors.inkHint,
    marginTop: Space.xl,
    letterSpacing: 6,
  },

  // 底部
  footer: {
    paddingBottom: Platform.OS === 'ios' ? 50 : 32,
    paddingHorizontal: Space.xl,
    alignItems: 'center',
    gap: Space.xl,
  },

  // 进度点
  dots: {
    flexDirection: 'row',
    gap: Space.md,
  },
  dot: {
    width: 6,
    height: 6,
    borderRadius: 3,
    backgroundColor: Colors.inkHint + '40',
  },
  dotActive: {
    backgroundColor: Colors.ink,
    width: 24,
  },

  // 按钮
  nextBtn: {
    paddingVertical: Space.md + 2,
    paddingHorizontal: Space['2xl'],
    borderWidth: 1,
    borderColor: Colors.ink,
    borderRadius: 2,
  },
  nextText: {
    ...Type.body,
    color: Colors.ink,
    fontWeight: '400',
    letterSpacing: 8,
  },
});
