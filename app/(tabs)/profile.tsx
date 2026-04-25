/**
 * 「我的」页面
 *
 * 不堆叠：分区卡片 + 点击展开/跳转
 * Neo-Tactile Warmth 设计
 */

import React, { useState, useCallback, useMemo, useEffect } from 'react';
import {
  StyleSheet, View, Text, Pressable, ScrollView, Alert,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import Animated, {
  useSharedValue, useAnimatedStyle, withSpring, withTiming,
} from 'react-native-reanimated';
import { useRouter } from 'expo-router';
import { Colors, Space, Radius, Type, Shadow, Motion, Size } from '@/lib/design/tokens';
import { BirthInput, MingPanCard, WuXingChart, PersonalityCard } from '@/components/bazi';
import { BaziEngine } from '@/lib/bazi/BaziEngine';
import { ZiweiEngine } from '@/lib/ziwei/ZiweiEngine';
import { InsightEngine } from '@/lib/bazi/InsightEngine';
import { toTrueSolarTime } from '@/lib/bazi/TrueSolarTime';
import { useUserStore } from '@/lib/store/userStore';
import type { MingPan, PersonalityInsight } from '@/lib/bazi/types';

const AnimatedPressable = Animated.createAnimatedComponent(Pressable);

export default function ProfileScreen() {
  const router = useRouter();
  const insets = useSafeAreaInsets();
  const {
    birthDate, gender, birthCity, birthLongitude, mingPanCache,
    setBirthDate, setGender, setBirthCity, setMingPanCache, setZiweiPanCache,
  } = useUserStore();

  const [mingPan, setMingPan] = useState<MingPan | null>(null);
  const [personality, setPersonality] = useState<PersonalityInsight | null>(null);
  const [showInput, setShowInput] = useState(false);
  const [expandedSection, setExpandedSection] = useState<string | null>(null);

  const baziEngine = useMemo(() => new BaziEngine(), []);
  const ziweiEngine = useMemo(() => new ZiweiEngine(), []);

  // 从缓存恢复
  useEffect(() => {
    if (mingPanCache && !mingPan) {
      try {
        const cached = JSON.parse(mingPanCache) as MingPan;
        setMingPan(cached);
        setPersonality(new InsightEngine(cached).getPersonalityInsight());
      } catch {}
    }
  }, []);

  // 迁移：有八字没紫微 → 自动补一份紫微盘
  useEffect(() => {
    const { ziweiPanCache } = useUserStore.getState();
    if (mingPanCache && !ziweiPanCache && birthDate && gender) {
      try {
        const d = new Date(birthDate);
        const ziweiPan = ziweiEngine.compute({
          year: d.getFullYear(),
          month: d.getMonth() + 1,
          day: d.getDate(),
          hour: d.getHours(),
          minute: d.getMinutes(),
          gender: gender as '男' | '女',
          isLunar: false,
        });
        setZiweiPanCache(JSON.stringify(ziweiPan));
      } catch {}
    }
  }, [mingPanCache, birthDate, gender, ziweiEngine, setZiweiPanCache]);

  const handleSubmit = useCallback(
    (date: Date, g: '男' | '女', longitude?: number) => {
      try {
        const corrected = toTrueSolarTime(date, longitude ?? 116.4);
        const result = baziEngine.calculate(corrected, g);
        setMingPan(result);
        setPersonality(new InsightEngine(result).getPersonalityInsight());
        setShowInput(false);
        setBirthDate(date);
        setGender(g);
        setMingPanCache(JSON.stringify(result));
        const ziweiPan = ziweiEngine.compute({
          year: date.getFullYear(),
          month: date.getMonth() + 1,
          day: date.getDate(),
          hour: date.getHours(),
          minute: date.getMinutes(),
          gender: g as '男' | '女',
          isLunar: false,
        });
        setZiweiPanCache(JSON.stringify(ziweiPan));
      } catch {
        Alert.alert('排盘失败', '请检查日期和时间');
      }
    },
    [baziEngine, ziweiEngine, setBirthDate, setGender, setMingPanCache, setZiweiPanCache],
  );

  const handleReset = useCallback(() => {
    Alert.alert('重新排盘', '将清除当前命盘数据', [
      { text: '取消', style: 'cancel' },
      {
        text: '确定', style: 'destructive',
        onPress: () => {
          setMingPan(null);
          setPersonality(null);
          setShowInput(true);
        },
      },
    ]);
  }, []);

  const toggleSection = (key: string) => {
    setExpandedSection(expandedSection === key ? null : key);
  };

  // ── 输入生辰 ──
  if (showInput) {
    return (
      <ScrollView
        style={[styles.container, { paddingTop: insets.top }]}
        contentContainerStyle={styles.scroll}
        showsVerticalScrollIndicator={false}
      >
        <BirthInput
          onSubmit={handleSubmit}
          initialDate={birthDate ? new Date(birthDate) : undefined}
          initialGender={gender ?? undefined}
          initialCity={birthCity ?? undefined}
        />
      </ScrollView>
    );
  }

  // ── 未输入 ──
  if (!mingPan) {
    return (
      <View style={[styles.container, { paddingTop: insets.top }]}>
        <View style={styles.emptyCenter}>
          <View style={styles.emptyCircle}>
            <Text style={styles.emptyCircleText}>我</Text>
          </View>
          <Text style={styles.emptyTitle}>遇见你自己</Text>
          <Text style={styles.emptySub}>输入生辰，开启专属命盘</Text>
          <TactileButton
            label="输入生辰"
            onPress={() => setShowInput(true)}
            color={Colors.vermilion}
          />
        </View>

        <View style={[styles.menuArea, { paddingBottom: insets.bottom + Size.tabBarHeight }]}>
          <MenuCard title="设置" onPress={() => router.push('/settings')} />
        </View>
      </View>
    );
  }

  // ── 已有命盘 ──
  return (
    <ScrollView
      style={[styles.container, { paddingTop: insets.top }]}
      contentContainerStyle={[styles.scroll, { paddingBottom: insets.bottom + Size.tabBarHeight }]}
      showsVerticalScrollIndicator={false}
    >
      {/* 日主 Hero */}
      <View style={styles.heroArea}>
        <Text style={styles.heroGan}>{mingPan.riZhu.gan}</Text>
        <Text style={styles.heroMeta}>
          {mingPan.riZhu.yinYang}{mingPan.riZhu.wuXing} · {mingPan.lunarDate}
        </Text>
        <Text style={styles.heroDesc}>{mingPan.riZhu.description}</Text>

        <Pressable onPress={handleReset} hitSlop={12}>
          <Text style={styles.resetText}>重新排盘</Text>
        </Pressable>
      </View>

      {/* 四柱卡片 */}
      <SectionCard
        title="四柱命盘"
        expanded={expandedSection === 'sizhu'}
        onToggle={() => toggleSection('sizhu')}
      >
        <MingPanCard mingPan={mingPan} />
      </SectionCard>

      {/* 五行分布 */}
      <SectionCard
        title="五行分布"
        expanded={expandedSection === 'wuxing'}
        onToggle={() => toggleSection('wuxing')}
      >
        <WuXingChart
          balance={mingPan.wuXingStrength.balance}
          yongShen={mingPan.wuXingStrength.yongShen}
          xiShen={mingPan.wuXingStrength.xiShen}
        />
      </SectionCard>

      {/* 格局 */}
      <View style={[styles.card, Shadow.sm]}>
        <Text style={styles.cardLabel}>格局</Text>
        <Text style={styles.geJuName}>{mingPan.geJu.name}</Text>
        <Text style={styles.geJuMeta}>
          {mingPan.geJu.category} · {mingPan.geJu.strength}等
        </Text>
        <Text style={styles.geJuDesc}>{mingPan.geJu.modernMeaning}</Text>
      </View>

      {/* 人格洞察 */}
      {personality && (
        <SectionCard
          title="人格洞察"
          expanded={expandedSection === 'personality'}
          onToggle={() => toggleSection('personality')}
        >
          <PersonalityCard insight={personality} />
        </SectionCard>
      )}

      {/* 功能入口 */}
      <View style={styles.menuArea}>
        <MenuCard title="流年运势" subtitle="大运 · 流年 · 流月" onPress={() => router.push('/fortune')} />
        <MenuCard title="设置" subtitle="AI 模型 · 个人信息" onPress={() => router.push('/settings')} />
      </View>
    </ScrollView>
  );
}

// ── 可展开的区块卡片 ──────────────────────────────

function SectionCard({
  title, expanded, onToggle, children,
}: {
  title: string; expanded: boolean; onToggle: () => void; children: React.ReactNode;
}) {
  return (
    <View style={[styles.card, Shadow.sm]}>
      <Pressable style={styles.cardHeader} onPress={onToggle} hitSlop={8}>
        <Text style={styles.cardLabel}>{title}</Text>
        <Text style={styles.cardChevron}>{expanded ? '−' : '+'}</Text>
      </Pressable>
      {expanded && <View style={styles.cardContent}>{children}</View>}
    </View>
  );
}

// ── 菜单卡片 ─────────────────────────────────────

function MenuCard({
  title, subtitle, onPress,
}: {
  title: string; subtitle?: string; onPress: () => void;
}) {
  const scale = useSharedValue(1);
  const animStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
  }));

  return (
    <AnimatedPressable
      style={[styles.menuCard, Shadow.sm, animStyle]}
      onPress={onPress}
      onPressIn={() => { scale.value = withSpring(0.97, Motion.quick); }}
      onPressOut={() => { scale.value = withSpring(1, Motion.quick); }}
    >
      <View style={styles.menuCardInner}>
        <Text style={styles.menuTitle}>{title}</Text>
        {subtitle && <Text style={styles.menuSub}>{subtitle}</Text>}
      </View>
      <Text style={styles.menuChevron}>›</Text>
    </AnimatedPressable>
  );
}

// ── 触感按钮 ─────────────────────────────────────

function TactileButton({
  label, onPress, color,
}: {
  label: string; onPress: () => void; color: string;
}) {
  const scale = useSharedValue(1);
  const animStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
  }));

  return (
    <AnimatedPressable
      style={[styles.tactileBtn, { backgroundColor: color }, Shadow.md, animStyle]}
      onPress={onPress}
      onPressIn={() => { scale.value = withSpring(0.95, Motion.quick); }}
      onPressOut={() => { scale.value = withSpring(1, Motion.quick); }}
    >
      <Text style={styles.tactileBtnText}>{label}</Text>
    </AnimatedPressable>
  );
}

// ── Styles ────────────────────────────────────────

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.bg },
  scroll: { paddingHorizontal: Space.lg, paddingBottom: Space['3xl'] },

  // 空状态
  emptyCenter: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    gap: Space.md,
  },
  emptyCircle: {
    width: 80,
    height: 80,
    borderRadius: 40,
    backgroundColor: Colors.brandBg,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: Space.md,
  },
  emptyCircleText: {
    fontFamily: 'Georgia',
    fontSize: 32,
    color: Colors.vermilion,
  },
  emptyTitle: {
    ...Type.title,
    color: Colors.ink,
  },
  emptySub: {
    ...Type.body,
    color: Colors.inkTertiary,
    marginBottom: Space.xl,
  },

  // Hero
  heroArea: {
    alignItems: 'center',
    paddingTop: Space.xl,
    paddingBottom: Space['2xl'],
  },
  heroGan: {
    fontFamily: 'Georgia',
    fontSize: 72,
    color: Colors.ink,
    fontWeight: '300',
    lineHeight: 80,
  },
  heroMeta: {
    ...Type.caption,
    color: Colors.inkTertiary,
    marginTop: Space.sm,
    letterSpacing: 2,
  },
  heroDesc: {
    ...Type.body,
    color: Colors.inkSecondary,
    textAlign: 'center',
    marginTop: Space.base,
    paddingHorizontal: Space.xl,
    lineHeight: 24,
  },
  resetText: {
    ...Type.caption,
    color: Colors.inkHint,
    marginTop: Space.lg,
  },

  // 卡片
  card: {
    backgroundColor: Colors.surface,
    borderRadius: Radius.lg,
    padding: Space.lg,
    marginBottom: Space.md,
  },
  cardHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  cardLabel: {
    ...Type.label,
    color: Colors.inkTertiary,
    letterSpacing: 2,
  },
  cardChevron: {
    fontSize: 20,
    color: Colors.inkHint,
    fontWeight: '300',
  },
  cardContent: {
    marginTop: Space.base,
  },

  // 格局
  geJuName: {
    ...Type.subtitle,
    color: Colors.ink,
    marginTop: Space.md,
  },
  geJuMeta: {
    ...Type.caption,
    color: Colors.inkTertiary,
    marginTop: Space.xs,
  },
  geJuDesc: {
    ...Type.body,
    color: Colors.inkSecondary,
    marginTop: Space.sm,
    lineHeight: 24,
  },

  // 菜单区
  menuArea: {
    marginTop: Space.lg,
    gap: Space.md,
    paddingHorizontal: Space.lg,
  },
  menuCard: {
    backgroundColor: Colors.surface,
    borderRadius: Radius.lg,
    padding: Space.lg,
    flexDirection: 'row',
    alignItems: 'center',
  },
  menuCardInner: {
    flex: 1,
    gap: Space.xs,
  },
  menuTitle: {
    ...Type.body,
    color: Colors.ink,
    fontWeight: '500',
  },
  menuSub: {
    ...Type.caption,
    color: Colors.inkHint,
  },
  menuChevron: {
    fontSize: 22,
    color: Colors.inkHint,
    fontWeight: '300',
  },

  // 触感按钮
  tactileBtn: {
    borderRadius: Radius.full,
    paddingVertical: Space.md,
    paddingHorizontal: Space['3xl'],
    height: Size.buttonLg,
    justifyContent: 'center',
    alignItems: 'center',
  },
  tactileBtnText: {
    ...Type.body,
    color: '#FFFFFF',
    fontWeight: '600',
    letterSpacing: 2,
  },
});
