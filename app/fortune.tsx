/**
 * 流年运势页面
 *
 * 大运 → 流年 → 流月 三级展开
 * Neo-Tactile Warmth 设计
 */

import React, { useState, useMemo } from 'react';
import {
  StyleSheet, View, Text, Pressable, ScrollView,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import Animated, {
  useSharedValue, useAnimatedStyle, withSpring,
} from 'react-native-reanimated';
import { useRouter } from 'expo-router';
import { Colors, Space, Radius, Type, Shadow, Motion, Size } from '@/lib/design/tokens';
import { useUserStore } from '@/lib/store/userStore';
import { DayunEngine } from '@/lib/bazi/DayunEngine';
import { InsightEngine } from '@/lib/bazi/InsightEngine';
import type { MingPan, DaYun, LiuNian } from '@/lib/bazi/types';

const AnimatedPressable = Animated.createAnimatedComponent(Pressable);

export default function FortunePage() {
  const router = useRouter();
  const insets = useSafeAreaInsets();
  const { mingPanCache } = useUserStore();

  const mingPan = useMemo<MingPan | null>(() => {
    if (!mingPanCache) return null;
    try {
      const p = JSON.parse(mingPanCache);
      if (p.birthDateTime) p.birthDateTime = new Date(p.birthDateTime);
      return p;
    } catch { return null; }
  }, [mingPanCache]);

  if (!mingPan) {
    return (
      <View style={[styles.container, { paddingTop: insets.top }]}>
        <View style={styles.emptyCenter}>
          <Text style={styles.emptyTitle}>流年运势</Text>
          <Text style={styles.emptySub}>请先在「我的」页面输入生辰</Text>
          <Pressable style={[styles.backBtnEmpty, Shadow.sm]} onPress={() => router.back()}>
            <Text style={styles.backBtnText}>返回</Text>
          </Pressable>
        </View>
      </View>
    );
  }

  return <FortuneContent mingPan={mingPan} onBack={() => router.back()} insets={insets} />;
}

function FortuneContent({ mingPan, onBack, insets }: { mingPan: MingPan; onBack: () => void; insets: any }) {
  const dayunEngine = useMemo(() => new DayunEngine(mingPan), [mingPan]);
  const currentYear = new Date().getFullYear();
  const birthYear = mingPan.birthDateTime.getFullYear();
  const currentAge = currentYear - birthYear;

  const [expandedDaYun, setExpandedDaYun] = useState<number | null>(() => {
    const dy = dayunEngine.getCurrentDaYun(currentAge);
    return dy.startAge;
  });
  const [expandedYear, setExpandedYear] = useState<number | null>(currentYear);

  const daYunList = dayunEngine.getDaYunList();
  const forecast = dayunEngine.getYearForecast(currentYear);

  const trendColor = forecast.overallTrend === '顺' ? Colors.celadon
    : forecast.overallTrend === '逆' ? Colors.vermilion : Colors.inkTertiary;

  return (
    <ScrollView
      style={[styles.container, { paddingTop: insets.top }]}
      contentContainerStyle={[styles.scroll, { paddingBottom: insets.bottom + Space['3xl'] }]}
      showsVerticalScrollIndicator={false}
    >
      <Pressable onPress={onBack} style={styles.navBtn} hitSlop={12}>
        <Text style={styles.navText}>← 返回</Text>
      </Pressable>

      <Text style={styles.heading}>流年运势</Text>
      <Text style={styles.sub}>
        {mingPan.riZhu.gan}日主 · {currentYear}年 · 虚岁{currentAge + 1}
      </Text>

      {/* 当年运势卡片 */}
      <View style={[styles.yearCard, Shadow.md]}>
        <View style={styles.yearCardHeader}>
          <Text style={styles.yearCardYear}>{currentYear}</Text>
          <View style={[styles.trendBadge, { backgroundColor: trendColor + '20' }]}>
            <Text style={[styles.trendText, { color: trendColor }]}>
              {forecast.overallTrend === '顺' ? '↑' : forecast.overallTrend === '逆' ? '↓' : '→'} {forecast.overallTrend}
            </Text>
          </View>
        </View>
        <Text style={styles.yearCardGanZhi}>
          {forecast.liuNian.ganZhi.gan}{forecast.liuNian.ganZhi.zhi}年 · {forecast.liuNian.shiShen}
        </Text>

        <View style={styles.forecastGrid}>
          <ForecastItem label="事业" text={forecast.careerOutlook} emoji="💼" />
          <ForecastItem label="财运" text={forecast.wealthOutlook} emoji="💰" />
          <ForecastItem label="感情" text={forecast.relationshipOutlook} emoji="❤️" />
          <ForecastItem label="健康" text={forecast.healthOutlook} emoji="🌿" />
        </View>

        <View style={styles.adviceArea}>
          <Text style={styles.adviceText}>{forecast.keyAdvice}</Text>
        </View>

        {forecast.luckyMonths.length > 0 && (
          <View style={styles.luckyRow}>
            <Text style={styles.luckyLabel}>吉月</Text>
            <View style={styles.luckyChips}>
              {forecast.luckyMonths.map(m => (
                <View key={m} style={styles.luckyChip}>
                  <Text style={styles.luckyChipText}>{m}月</Text>
                </View>
              ))}
            </View>
          </View>
        )}
      </View>

      {/* 大运列表 */}
      <Text style={styles.sectionTitle}>大运</Text>
      {daYunList.map((dy) => {
        const isCurrent = currentAge >= dy.startAge && currentAge <= dy.endAge;
        const isExpanded = expandedDaYun === dy.startAge;

        return (
          <View key={dy.startAge}>
            <Pressable
              style={[styles.daYunCard, isCurrent && styles.daYunCardCurrent, Shadow.sm]}
              onPress={() => setExpandedDaYun(isExpanded ? null : dy.startAge)}
            >
              <Text style={[styles.daYunGan, isCurrent && styles.daYunGanCurrent]}>
                {dy.ganZhi.gan}{dy.ganZhi.zhi}
              </Text>
              <View style={styles.daYunInfo}>
                <Text style={styles.daYunAge}>{dy.startAge}–{dy.endAge}岁</Text>
                <Text style={styles.daYunSS}>{dy.shiShen}</Text>
              </View>
              <Text style={styles.daYunYears}>
                {birthYear + dy.startAge}–{birthYear + dy.endAge}
              </Text>
              <Text style={styles.chevron}>{isExpanded ? '−' : '+'}</Text>
            </Pressable>

            {isExpanded && (
              <View style={styles.liuNianArea}>
                {Array.from({ length: 10 }, (_, i) => {
                  const year = birthYear + dy.startAge + i;
                  const ln = dayunEngine.getCurrentLiuNian(year);
                  const isCurrentYear = year === currentYear;
                  const isYearExpanded = expandedYear === year;

                  return (
                    <View key={year}>
                      <Pressable
                        style={[
                          styles.liuNianRow,
                          isCurrentYear && styles.liuNianRowCurrent,
                        ]}
                        onPress={() => setExpandedYear(isYearExpanded ? null : year)}
                      >
                        <Text style={[styles.lnGan, isCurrentYear && styles.lnGanCurrent]}>
                          {ln.ganZhi.gan}{ln.ganZhi.zhi}
                        </Text>
                        <Text style={styles.lnYear}>{year}</Text>
                        <Text style={styles.lnSS}>{ln.shiShen}</Text>
                      </Pressable>

                      {isYearExpanded && ln.interactions.length > 0 && (
                        <View style={styles.interactionArea}>
                          {ln.interactions.map((txt, j) => (
                            <Text key={j} style={styles.interactionText}>· {txt}</Text>
                          ))}
                        </View>
                      )}
                    </View>
                  );
                })}
              </View>
            )}
          </View>
        );
      })}
    </ScrollView>
  );
}

function ForecastItem({ label, text, emoji }: { label: string; text: string; emoji: string }) {
  return (
    <View style={styles.forecastItem}>
      <View style={styles.forecastItemHeader}>
        <Text style={styles.forecastEmoji}>{emoji}</Text>
        <Text style={styles.forecastLabel}>{label}</Text>
      </View>
      <Text style={styles.forecastText}>{text}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.bg },
  scroll: { paddingHorizontal: Space.lg },

  navBtn: { paddingVertical: Space.md },
  navText: { ...Type.body, color: Colors.vermilion },

  heading: {
    fontFamily: 'Georgia',
    fontSize: 32,
    color: Colors.ink,
    fontWeight: '400',
  },
  sub: {
    ...Type.caption,
    color: Colors.inkTertiary,
    marginTop: Space.xs,
    marginBottom: Space.xl,
    letterSpacing: 1,
  },

  // 空状态
  emptyCenter: { flex: 1, justifyContent: 'center', alignItems: 'center', gap: Space.md },
  emptyTitle: { ...Type.title, color: Colors.ink },
  emptySub: { ...Type.body, color: Colors.inkTertiary },
  backBtnEmpty: { backgroundColor: Colors.surface, borderRadius: Radius.lg, paddingVertical: Space.md, paddingHorizontal: Space['2xl'], marginTop: Space.lg },
  backBtnText: { ...Type.body, color: Colors.vermilion, fontWeight: '500' },

  // 当年运势
  yearCard: {
    backgroundColor: Colors.surface,
    borderRadius: Radius.xl,
    padding: Space.xl,
    marginBottom: Space.xl,
  },
  yearCardHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  yearCardYear: {
    fontFamily: 'Georgia',
    fontSize: 36,
    color: Colors.ink,
    fontWeight: '300',
  },
  trendBadge: {
    paddingHorizontal: Space.md,
    paddingVertical: Space.xs,
    borderRadius: Radius.full,
  },
  trendText: {
    ...Type.label,
    fontWeight: '600',
  },
  yearCardGanZhi: {
    ...Type.caption,
    color: Colors.inkTertiary,
    marginTop: Space.xs,
    marginBottom: Space.xl,
  },
  forecastGrid: { gap: Space.lg },
  forecastItem: { gap: Space.xs },
  forecastItemHeader: { flexDirection: 'row', alignItems: 'center', gap: Space.sm },
  forecastEmoji: { fontSize: 16 },
  forecastLabel: { ...Type.label, color: Colors.inkTertiary, letterSpacing: 1 },
  forecastText: { ...Type.body, color: Colors.inkSecondary, lineHeight: 24, paddingLeft: Space.xl + Space.sm },
  adviceArea: {
    backgroundColor: Colors.brandBg,
    borderRadius: Radius.md,
    padding: Space.base,
    marginTop: Space.xl,
  },
  adviceText: { ...Type.body, color: Colors.vermilion, lineHeight: 24 },
  luckyRow: { flexDirection: 'row', alignItems: 'center', gap: Space.md, marginTop: Space.lg },
  luckyLabel: { ...Type.label, color: Colors.inkTertiary },
  luckyChips: { flexDirection: 'row', gap: Space.sm, flexWrap: 'wrap' },
  luckyChip: { backgroundColor: Colors.celadon + '20', paddingHorizontal: Space.md, paddingVertical: Space.xs, borderRadius: Radius.full },
  luckyChipText: { ...Type.label, color: Colors.celadon, fontWeight: '600' },

  // 大运
  sectionTitle: { ...Type.label, color: Colors.inkTertiary, letterSpacing: 2, marginBottom: Space.md },
  daYunCard: {
    backgroundColor: Colors.surface,
    borderRadius: Radius.lg,
    padding: Space.base,
    flexDirection: 'row',
    alignItems: 'center',
    gap: Space.md,
    marginBottom: Space.sm,
  },
  daYunCardCurrent: { borderWidth: 1, borderColor: Colors.vermilion + '30' },
  daYunGan: { fontFamily: 'Georgia', fontSize: 20, color: Colors.inkSecondary, width: 48 },
  daYunGanCurrent: { color: Colors.vermilion, fontWeight: '500' },
  daYunInfo: { flex: 1, gap: 2 },
  daYunAge: { ...Type.bodySmall, color: Colors.ink },
  daYunSS: { ...Type.caption, color: Colors.inkHint },
  daYunYears: { ...Type.caption, color: Colors.inkHint },
  chevron: { fontSize: 18, color: Colors.inkHint, width: 20, textAlign: 'center' },

  // 流年
  liuNianArea: {
    backgroundColor: Colors.bgSecondary,
    borderRadius: Radius.md,
    marginBottom: Space.md,
    marginLeft: Space.xl,
    overflow: 'hidden',
  },
  liuNianRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: Space.md,
    paddingHorizontal: Space.base,
    gap: Space.md,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: Colors.borderLight,
  },
  liuNianRowCurrent: { backgroundColor: Colors.brandBg },
  lnGan: { fontFamily: 'Georgia', fontSize: 16, color: Colors.inkSecondary, width: 40 },
  lnGanCurrent: { color: Colors.vermilion, fontWeight: '500' },
  lnYear: { ...Type.bodySmall, color: Colors.inkTertiary, flex: 1 },
  lnSS: { ...Type.caption, color: Colors.inkHint },

  interactionArea: { padding: Space.base, paddingTop: 0, gap: 4 },
  interactionText: { ...Type.caption, color: Colors.inkSecondary, lineHeight: 20 },
});
