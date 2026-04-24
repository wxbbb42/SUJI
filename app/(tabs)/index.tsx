/**
 * 日历首页
 *
 * 日期卡片 + 每日格言 + 运势 + 十二时辰
 * Neo-Tactile Warmth 设计
 */

import React, { useState, useEffect, useMemo } from 'react';
import {
  StyleSheet, View, Text, ScrollView,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Colors, Space, Radius, Type, Shadow, Size } from '@/lib/design/tokens';
import { useUserStore } from '@/lib/store/userStore';
import { InsightEngine } from '@/lib/bazi/InsightEngine';
import type { MingPan, DailyInsight } from '@/lib/bazi/types';
import lunisolar from 'lunisolar';
import { ShichenTimeline } from '@/components/calendar/ShichenTimeline';

const WISDOMS = [
  '水流不争先\n争的是滔滔不绝',
  '大道至简\n衍化至繁',
  '知止而后有定\n定而后能静',
  '上善若水\n水善利万物而不争',
  '千里之行\n始于足下',
  '静以修身\n俭以养德',
  '不积跬步\n无以至千里',
  '心若冰清\n天塌不惊',
  '知者不惑\n仁者不忧\n勇者不惧',
  '万物并作\n吾以观复',
  '致虚极\n守静笃',
  '天行健\n君子以自强不息',
];

export default function CalendarScreen() {
  const insets = useSafeAreaInsets();
  const { mingPanCache } = useUserStore();

  const [info, setInfo] = useState({
    lunarDate: '', solarDate: '', ganZhi: '', wisdom: '',
    dayNum: 0, weekDay: '',
  });
  const [dailyInsight, setDailyInsight] = useState<DailyInsight | null>(null);

  const mingPan = useMemo<MingPan | null>(() => {
    if (!mingPanCache) return null;
    try {
      const p = JSON.parse(mingPanCache);
      if (p.birthDateTime) p.birthDateTime = new Date(p.birthDateTime);
      return p;
    } catch { return null; }
  }, [mingPanCache]);

  useEffect(() => {
    const now = new Date();
    const ls = lunisolar(now);
    const lunar = ls.lunar;
    const weekDays = ['日','一','二','三','四','五','六'];
    const dayOfYear = Math.floor(
      (now.getTime() - new Date(now.getFullYear(), 0, 0).getTime()) / 86400000
    );

    setInfo({
      lunarDate: `${lunar.getMonthName()}${lunar.getDayName()}`,
      solarDate: `${now.getFullYear()}年${now.getMonth()+1}月`,
      ganZhi: ls.format('cD'),
      wisdom: WISDOMS[dayOfYear % WISDOMS.length],
      dayNum: now.getDate(),
      weekDay: `周${weekDays[now.getDay()]}`,
    });

    if (mingPan) {
      try {
        const engine = new InsightEngine(mingPan);
        setDailyInsight(engine.getDailyInsight(now));
      } catch {}
    }
  }, [mingPan]);


  return (
    <ScrollView
      style={[styles.container, { paddingTop: insets.top }]}
      contentContainerStyle={styles.scroll}
      showsVerticalScrollIndicator={false}
    >
      {/* ── 日期卡片 ── */}
      <View style={[styles.dateCard, Shadow.md]}>
        <View style={styles.dateCardInner}>
          <Text style={styles.dateSolar}>{info.solarDate}</Text>
          <Text style={styles.dateDay}>{info.dayNum}</Text>
          <View style={styles.dateRow}>
            <Text style={styles.dateWeek}>{info.weekDay}</Text>
            <View style={styles.dateDot} />
            <Text style={styles.dateLunar}>{info.lunarDate}</Text>
            <View style={styles.dateDot} />
            <Text style={styles.dateGanZhi}>{info.ganZhi}</Text>
          </View>
        </View>
      </View>

      {/* ── 今日格言 ── */}
      <View style={styles.wisdomArea}>
        <Text style={styles.wisdomText}>{info.wisdom}</Text>
      </View>

      {/* ── 每日运势卡片 ── */}
      {dailyInsight && (
        <View style={[styles.insightCard, Shadow.sm]}>
          <View style={styles.insightHeader}>
            <Text style={styles.insightLabel}>今日运势</Text>
            <View style={[
              styles.energyBadge,
              dailyInsight.overallEnergy === '高' && styles.energyHigh,
              dailyInsight.overallEnergy === '低' && styles.energyLow,
            ]}>
              <Text style={[
                styles.energyText,
                dailyInsight.overallEnergy === '高' && styles.energyTextHigh,
                dailyInsight.overallEnergy === '低' && styles.energyTextLow,
              ]}>
                {dailyInsight.overallEnergy === '高' ? '▲' : dailyInsight.overallEnergy === '低' ? '▼' : '●'} {dailyInsight.overallEnergy}
              </Text>
            </View>
          </View>

          <Text style={styles.insightFocus}>宜 · {dailyInsight.focusArea}</Text>
          <Text style={styles.insightAdvice}>{dailyInsight.advice}</Text>

          {dailyInsight.affirmation && (
            <View style={styles.affirmationArea}>
              <Text style={styles.affirmationText}>「{dailyInsight.affirmation}」</Text>
            </View>
          )}
        </View>
      )}

      <ShichenTimeline />
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.bg,
  },
  scroll: {
    paddingHorizontal: Space.lg,
    paddingBottom: Size.tabBarHeight + Space.xl,
  },

  // ── 日期卡片 ──
  dateCard: {
    backgroundColor: Colors.surface,
    borderRadius: Radius.xl,
    marginTop: Space.lg,
    overflow: 'hidden',
  },
  dateCardInner: {
    padding: Space.xl,
    alignItems: 'center',
  },
  dateSolar: {
    ...Type.caption,
    color: Colors.inkTertiary,
    letterSpacing: 2,
  },
  dateDay: {
    fontFamily: 'Georgia',
    fontSize: 80,
    fontWeight: '300',
    color: Colors.ink,
    lineHeight: 88,
    marginVertical: Space.sm,
  },
  dateRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Space.sm,
  },
  dateWeek: {
    ...Type.bodySmall,
    color: Colors.inkSecondary,
  },
  dateDot: {
    width: 3,
    height: 3,
    borderRadius: 1.5,
    backgroundColor: Colors.inkHint,
  },
  dateLunar: {
    ...Type.bodySmall,
    color: Colors.inkSecondary,
  },
  dateGanZhi: {
    ...Type.bodySmall,
    color: Colors.vermilion,
    fontWeight: '500',
  },

  // ── 格言 ──
  wisdomArea: {
    paddingVertical: Space['2xl'],
    paddingHorizontal: Space.lg,
    alignItems: 'center',
  },
  wisdomText: {
    fontFamily: 'Georgia',
    fontSize: 20,
    lineHeight: 32,
    color: Colors.ink,
    textAlign: 'center',
    fontWeight: '400',
  },

  // ── 运势卡片 ──
  insightCard: {
    backgroundColor: Colors.surface,
    borderRadius: Radius.lg,
    padding: Space.lg,
    gap: Space.md,
  },
  insightHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  insightLabel: {
    ...Type.label,
    color: Colors.inkTertiary,
    letterSpacing: 2,
  },
  energyBadge: {
    backgroundColor: Colors.bgSecondary,
    paddingHorizontal: Space.md,
    paddingVertical: Space.xs,
    borderRadius: Radius.full,
  },
  energyHigh: {
    backgroundColor: '#E8F5E8',
  },
  energyLow: {
    backgroundColor: '#FFF0ED',
  },
  energyText: {
    ...Type.label,
    color: Colors.inkTertiary,
    fontWeight: '600',
  },
  energyTextHigh: {
    color: Colors.celadon,
  },
  energyTextLow: {
    color: Colors.vermilion,
  },
  insightFocus: {
    ...Type.body,
    color: Colors.celadon,
    fontWeight: '500',
  },
  insightAdvice: {
    ...Type.body,
    color: Colors.inkSecondary,
    lineHeight: 24,
  },
  affirmationArea: {
    backgroundColor: Colors.brandBg,
    borderRadius: Radius.md,
    padding: Space.base,
    marginTop: Space.xs,
  },
  affirmationText: {
    ...Type.bodySmall,
    color: Colors.vermilion,
    fontStyle: 'italic',
    lineHeight: 22,
    textAlign: 'center',
  },

});
