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
import { CalibrationSheet } from '@/components/calibration/CalibrationSheet';
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
  const apiKey = useUserStore(s => s.apiKey);

  const [mingPan, setMingPan] = useState<MingPan | null>(null);
  const [personality, setPersonality] = useState<PersonalityInsight | null>(null);
  const [showInput, setShowInput] = useState(false);
  const [expandedSection, setExpandedSection] = useState<string | null>(null);
  const [calibrationVisible, setCalibrationVisible] = useState(false);

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

  // 迁移：有八字没紫微，或紫微宫名是旧格式（缺"宫"字） → 重新生成紫微盘
  useEffect(() => {
    const { ziweiPanCache } = useUserStore.getState();
    if (!mingPanCache || !birthDate || !gender) return;

    let needsRegen = !ziweiPanCache;
    if (ziweiPanCache && !needsRegen) {
      try {
        const cached = JSON.parse(ziweiPanCache);
        // 旧格式：iztro 直接返回的 '子女'/'夫妻' 等无"宫"字宫名
        // 新格式（normalizePalaceName 后）：所有 12 主宫都带"宫"字
        const hasOldFormat = (cached.palaces ?? []).some(
          (p: any) => p.name && !p.name.endsWith('宫'),
        );
        if (hasOldFormat) needsRegen = true;
      } catch {
        needsRegen = true;
      }
    }

    if (needsRegen) {
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
    (date: Date, g: '男' | '女', longitude?: number, city?: string) => {
      try {
        const corrected = toTrueSolarTime(date, longitude ?? 116.4);
        const result = baziEngine.calculate(corrected, g);
        setMingPan(result);
        setPersonality(new InsightEngine(result).getPersonalityInsight());
        setShowInput(false);
        setBirthDate(date);
        setGender(g);
        if (city && longitude != null) {
          setBirthCity(city, longitude);
        }
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
    [baziEngine, ziweiEngine, setBirthDate, setGender, setBirthCity, setMingPanCache, setZiweiPanCache],
  );

  const handleEdit = useCallback(() => {
    setShowInput(true);
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
    <>
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
      </View>

      {/* 出生信息 */}
      <View style={[styles.card, Shadow.sm]}>
        <View style={styles.cardHeader}>
          <Text style={styles.cardLabel}>出生信息</Text>
          <Pressable onPress={handleEdit} hitSlop={8}>
            <Text style={styles.editLink}>编辑</Text>
          </Pressable>
        </View>
        <View style={styles.cardContent}>
          <BirthInfoRow label="生日" value={formatBirthDate(birthDate)} />
          <BirthInfoRow label="性别" value={gender ?? '—'} />
          <BirthInfoRow label="出生地" value={birthCity ?? '未填（按北京估算）'} />
        </View>
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
        <MenuCard
          title="校准时辰"
          subtitle={apiKey ? '过去事件回推，3-5 轮对话' : '先在设置里配置 AI'}
          onPress={() => {
            if (!apiKey) {
              Alert.alert('需要 AI', '请先在"设置"里配置 AI 模型');
              return;
            }
            setCalibrationVisible(true);
          }}
        />
        <MenuCard title="流年运势" subtitle="大运 · 流年 · 流月" onPress={() => router.push('/fortune')} />
        <MenuCard title="设置" subtitle="AI 模型 · 个人信息" onPress={() => router.push('/settings')} />
      </View>
    </ScrollView>
    <CalibrationSheet
      visible={calibrationVisible}
      onClose={() => setCalibrationVisible(false)}
    />
    </>
  );
}

// ── 出生信息一行 ──────────────────────────────────

function BirthInfoRow({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.birthRow}>
      <Text style={styles.birthLabel}>{label}</Text>
      <Text style={styles.birthValue} numberOfLines={1}>{value}</Text>
    </View>
  );
}

function formatBirthDate(iso: string | null): string {
  if (!iso) return '—';
  const d = new Date(iso);
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  const hh = String(d.getHours()).padStart(2, '0');
  const mm = String(d.getMinutes()).padStart(2, '0');
  return `${y}-${m}-${day} ${hh}:${mm}`;
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
  editLink: {
    ...Type.bodySmall,
    color: Colors.vermilion,
    fontWeight: '500',
  },
  birthRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: Space.sm,
  },
  birthLabel: {
    ...Type.bodySmall,
    color: Colors.inkSecondary,
    width: 64,
  },
  birthValue: {
    ...Type.body,
    color: Colors.ink,
    flex: 1,
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
