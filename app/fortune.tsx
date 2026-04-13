/**
 * 流年运势页面
 *
 * 大运 → 流年 → 流月 展开视图
 * 当前年份高亮，点击展开详情
 */

import {
  StyleSheet, View, Text, Pressable, ScrollView,
} from 'react-native';
import { useState, useMemo } from 'react';
import { useRouter } from 'expo-router';
import { Colors, Space, Type } from '@/lib/design/tokens';
import { useUserStore } from '@/lib/store/userStore';
import { DayunEngine } from '@/lib/bazi/DayunEngine';
import { InsightEngine } from '@/lib/bazi/InsightEngine';
import type { MingPan, DaYun, LiuNian } from '@/lib/bazi/types';

export default function FortunePage() {
  const router = useRouter();
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
      <View style={styles.container}>
        <View style={styles.emptyCenter}>
          <Text style={styles.emptyTitle}>流年运势</Text>
          <Text style={styles.emptySub}>请先在「我的」页面输入生辰</Text>
          <Pressable style={styles.backBtn} onPress={() => router.back()}>
            <Text style={styles.backBtnText}>返回</Text>
          </Pressable>
        </View>
      </View>
    );
  }

  return <FortuneContent mingPan={mingPan} onBack={() => router.back()} />;
}

function FortuneContent({ mingPan, onBack }: { mingPan: MingPan; onBack: () => void }) {
  const dayunEngine = useMemo(() => new DayunEngine(mingPan), [mingPan]);
  const insightEngine = useMemo(() => new InsightEngine(mingPan), [mingPan]);
  const currentYear = new Date().getFullYear();
  const birthYear = mingPan.birthDateTime.getFullYear();
  const currentAge = currentYear - birthYear;

  const [expandedYear, setExpandedYear] = useState<number | null>(currentYear);
  const [expandedDaYun, setExpandedDaYun] = useState<number | null>(() => {
    const dy = dayunEngine.getCurrentDaYun(currentAge);
    return dy.startAge;
  });

  const daYunList = dayunEngine.getDaYunList();

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.scroll}>
      <Pressable onPress={onBack} style={styles.nav}>
        <Text style={styles.navText}>← 返回</Text>
      </Pressable>

      <Text style={styles.heading}>流年运势</Text>
      <Text style={styles.sub}>
        {mingPan.riZhu.gan}日主 · {currentYear}年 · 虚岁{currentAge + 1}
      </Text>

      {/* 当年运势概览 */}
      <YearOverview
        insightEngine={insightEngine}
        dayunEngine={dayunEngine}
        year={currentYear}
      />

      {/* 大运列表 */}
      <Text style={styles.sectionTitle}>大运</Text>
      {daYunList.map((dy) => {
        const isCurrentDaYun = currentAge >= dy.startAge && currentAge <= dy.endAge;
        const isExpanded = expandedDaYun === dy.startAge;

        return (
          <View key={dy.startAge}>
            <Pressable
              style={[styles.daYunRow, isCurrentDaYun && styles.daYunRowCurrent]}
              onPress={() => setExpandedDaYun(isExpanded ? null : dy.startAge)}
            >
              <Text style={[styles.daYunGanZhi, isCurrentDaYun && styles.daYunGanZhiCurrent]}>
                {dy.ganZhi.gan}{dy.ganZhi.zhi}
              </Text>
              <Text style={styles.daYunMeta}>
                {dy.startAge}–{dy.endAge}岁 · {dy.shiShen}
              </Text>
              <Text style={styles.daYunYear}>
                {birthYear + dy.startAge}–{birthYear + dy.endAge}
              </Text>
            </Pressable>

            {/* 展开的流年 */}
            {isExpanded && (
              <View style={styles.liuNianGrid}>
                {Array.from({ length: 10 }, (_, i) => {
                  const year = birthYear + dy.startAge + i;
                  const ln = dayunEngine.getCurrentLiuNian(year);
                  const isCurrent = year === currentYear;
                  const isYearExpanded = expandedYear === year;

                  return (
                    <View key={year}>
                      <Pressable
                        style={[styles.liuNianCell, isCurrent && styles.liuNianCellCurrent]}
                        onPress={() => setExpandedYear(isYearExpanded ? null : year)}
                      >
                        <Text style={[styles.lnGanZhi, isCurrent && styles.lnGanZhiCurrent]}>
                          {ln.ganZhi.gan}{ln.ganZhi.zhi}
                        </Text>
                        <Text style={styles.lnYear}>{year}</Text>
                        <Text style={styles.lnShiShen}>{ln.shiShen}</Text>
                      </Pressable>

                      {/* 流年详情 */}
                      {isYearExpanded && (
                        <LiuNianDetail
                          dayunEngine={dayunEngine}
                          insightEngine={insightEngine}
                          year={year}
                          liuNian={ln}
                        />
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

/** 当年运势概览 */
function YearOverview({
  insightEngine, dayunEngine, year,
}: { insightEngine: InsightEngine; dayunEngine: DayunEngine; year: number }) {
  const forecast = dayunEngine.getYearForecast(year);
  const trendEmoji = forecast.overallTrend === '顺' ? '↑' : forecast.overallTrend === '逆' ? '↓' : '→';

  return (
    <View style={styles.overview}>
      <View style={styles.overviewHeader}>
        <Text style={styles.overviewYear}>{year}</Text>
        <Text style={styles.overviewTrend}>{trendEmoji} {forecast.overallTrend}</Text>
      </View>

      <Text style={styles.overviewGanZhi}>
        {forecast.liuNian.ganZhi.gan}{forecast.liuNian.ganZhi.zhi}年 · {forecast.liuNian.shiShen}
      </Text>

      <View style={styles.overviewGrid}>
        <OverviewItem label="事业" text={forecast.careerOutlook} />
        <OverviewItem label="财运" text={forecast.wealthOutlook} />
        <OverviewItem label="感情" text={forecast.relationshipOutlook} />
        <OverviewItem label="健康" text={forecast.healthOutlook} />
      </View>

      <Text style={styles.overviewAdvice}>{forecast.keyAdvice}</Text>

      {forecast.luckyMonths.length > 0 && (
        <Text style={styles.overviewLucky}>
          吉月：{forecast.luckyMonths.map(m => `${m}月`).join('、')}
        </Text>
      )}
    </View>
  );
}

function OverviewItem({ label, text }: { label: string; text: string }) {
  return (
    <View style={styles.overviewItem}>
      <Text style={styles.overviewItemLabel}>{label}</Text>
      <Text style={styles.overviewItemText}>{text}</Text>
    </View>
  );
}

/** 流年详情展开 */
function LiuNianDetail({
  dayunEngine, insightEngine, year, liuNian,
}: {
  dayunEngine: DayunEngine;
  insightEngine: InsightEngine;
  year: number;
  liuNian: LiuNian;
}) {
  const liuYueList = dayunEngine.getLiuYue(year);

  return (
    <View style={styles.lnDetail}>
      {/* 互动关系 */}
      {liuNian.interactions.length > 0 && (
        <View style={styles.lnInteractions}>
          {liuNian.interactions.map((text, i) => (
            <Text key={i} style={styles.lnInteractionText}>· {text}</Text>
          ))}
        </View>
      )}

      {/* 流月 */}
      <Text style={styles.lnMonthTitle}>流月</Text>
      <View style={styles.liuYueGrid}>
        {liuYueList.map((ly) => (
          <View key={ly.month} style={styles.liuYueCell}>
            <Text style={styles.lyMonth}>{ly.month}月</Text>
            <Text style={styles.lyGanZhi}>{ly.ganZhi.gan}{ly.ganZhi.zhi}</Text>
            <Text style={styles.lyShiShen}>{ly.shiShen}</Text>
          </View>
        ))}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.bg },
  scroll: { paddingHorizontal: Space.lg, paddingBottom: Space['3xl'] },

  nav: { paddingTop: Space.xl, paddingBottom: Space.md },
  navText: { ...Type.body, color: Colors.brand },

  heading: { fontSize: 32, color: Colors.ink, fontWeight: '200', letterSpacing: 8 },
  sub: { ...Type.caption, color: Colors.inkHint, marginTop: Space.xs, marginBottom: Space.xl },

  // 空状态
  emptyCenter: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  emptyTitle: { ...Type.title, color: Colors.ink, fontWeight: '300' },
  emptySub: { ...Type.caption, color: Colors.inkTertiary, marginTop: Space.sm },
  backBtn: { marginTop: Space.xl, paddingVertical: Space.md, paddingHorizontal: Space.xl, borderWidth: 1, borderColor: Colors.brand, borderRadius: 2 },
  backBtnText: { ...Type.body, color: Colors.brand },

  // 当年概览
  overview: { backgroundColor: Colors.surface, borderRadius: 4, padding: Space.lg, marginBottom: Space.xl },
  overviewHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: Space.sm },
  overviewYear: { fontSize: 28, color: Colors.ink, fontWeight: '200' },
  overviewTrend: { ...Type.body, color: Colors.brand, fontWeight: '500' },
  overviewGanZhi: { ...Type.caption, color: Colors.inkTertiary, marginBottom: Space.lg },
  overviewGrid: { gap: Space.md },
  overviewItem: { gap: Space.xs },
  overviewItemLabel: { ...Type.label, color: Colors.inkHint },
  overviewItemText: { ...Type.body, color: Colors.inkSecondary, lineHeight: 22 },
  overviewAdvice: { ...Type.body, color: Colors.ink, marginTop: Space.lg, lineHeight: 22 },
  overviewLucky: { ...Type.caption, color: Colors.brand, marginTop: Space.md },

  // 大运
  sectionTitle: { ...Type.label, color: Colors.inkTertiary, textTransform: 'uppercase', marginBottom: Space.md },
  daYunRow: { flexDirection: 'row', alignItems: 'center', paddingVertical: Space.md, gap: Space.md },
  daYunRowCurrent: { },
  daYunGanZhi: { ...Type.subtitle, color: Colors.inkSecondary, fontWeight: '300', width: 48 },
  daYunGanZhiCurrent: { color: Colors.brand, fontWeight: '500' },
  daYunMeta: { ...Type.caption, color: Colors.inkHint, flex: 1 },
  daYunYear: { ...Type.caption, color: Colors.inkHint },

  // 流年
  liuNianGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: Space.xs, paddingLeft: Space.md, marginBottom: Space.lg },
  liuNianCell: { width: '18%', alignItems: 'center', paddingVertical: Space.sm },
  liuNianCellCurrent: { backgroundColor: Colors.surface, borderRadius: 4 },
  lnGanZhi: { ...Type.body, color: Colors.inkSecondary, fontWeight: '300' },
  lnGanZhiCurrent: { color: Colors.brand, fontWeight: '500' },
  lnYear: { ...Type.label, color: Colors.inkHint, marginTop: 2 },
  lnShiShen: { ...Type.label, color: Colors.inkHint, marginTop: 1 },

  // 流年详情
  lnDetail: { paddingLeft: Space.md, paddingBottom: Space.lg },
  lnInteractions: { marginBottom: Space.md },
  lnInteractionText: { ...Type.caption, color: Colors.inkSecondary, lineHeight: 20, marginBottom: 4 },
  lnMonthTitle: { ...Type.label, color: Colors.inkHint, marginBottom: Space.sm },
  liuYueGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: Space.xs },
  liuYueCell: { width: '15%', alignItems: 'center', paddingVertical: Space.xs },
  lyMonth: { ...Type.label, color: Colors.inkHint },
  lyGanZhi: { ...Type.caption, color: Colors.inkSecondary },
  lyShiShen: { fontSize: 9, color: Colors.inkHint },
});
