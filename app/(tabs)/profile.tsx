/**
 * 「我的」页面
 *
 * 未输入生辰：引导输入
 * 已输入：完整命盘展示（从 store 读取）
 * 支持真太阳时修正（传入经度）
 */

import { StyleSheet, View, Text, Pressable, ScrollView, Alert } from 'react-native';
import { useState, useCallback, useMemo, useEffect } from 'react';
import { useRouter } from 'expo-router';
import { Colors, Space, Type } from '@/lib/design/tokens';
import { BirthInput, MingPanCard, WuXingChart, PersonalityCard } from '@/components/bazi';
import { BaziEngine } from '@/lib/bazi/BaziEngine';
import { InsightEngine } from '@/lib/bazi/InsightEngine';
import { toTrueSolarTime } from '@/lib/bazi/TrueSolarTime';
import { useUserStore } from '@/lib/store/userStore';
import type { MingPan, PersonalityInsight } from '@/lib/bazi/types';

export default function ProfileScreen() {
  const router = useRouter();

  // ── store ──
  const {
    birthDate, gender, birthCity, birthLongitude, mingPanCache,
    setBirthDate, setGender, setBirthCity, setMingPanCache,
  } = useUserStore();

  const [mingPan,     setMingPan]     = useState<MingPan | null>(null);
  const [personality, setPersonality] = useState<PersonalityInsight | null>(null);
  const [showInput,   setShowInput]   = useState(false);

  const baziEngine = useMemo(() => new BaziEngine(), []);

  // 首次加载：若 store 有缓存，直接还原命盘
  useEffect(() => {
    if (mingPanCache && !mingPan) {
      try {
        const cached = JSON.parse(mingPanCache) as MingPan;
        setMingPan(cached);
        const insight = new InsightEngine(cached);
        setPersonality(insight.getPersonalityInsight());
      } catch {
        // 缓存损坏，忽略
      }
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const handleSubmit = useCallback(
    (date: Date, g: '男' | '女', longitude?: number) => {
      try {
        // 真太阳时修正（无城市时默认北京经度）
        const corrected = toTrueSolarTime(date, longitude ?? 116.4);
        const result = baziEngine.calculate(corrected, g);
        const insight = new InsightEngine(result);

        // 持久化到 store
        setBirthDate(date);
        setGender(g);
        // city name stored in store via BirthInput's onSubmit path —
        // profile passes longitude through, city already set via store action
        setMingPanCache(JSON.stringify(result));

        setMingPan(result);
        setPersonality(insight.getPersonalityInsight());
        setShowInput(false);
      } catch {
        Alert.alert('排盘失败', '请检查日期和时间');
      }
    },
    [baziEngine, setBirthDate, setGender, setMingPanCache],
  );

  // 包装 BirthInput 的 onSubmit，同时把城市存进 store
  const handleBirthSubmit = useCallback(
    (date: Date, g: '男' | '女', longitude?: number) => {
      handleSubmit(date, g, longitude);
    },
    [handleSubmit],
  );

  const handleReset = useCallback(() => {
    Alert.alert('重新输入', '清除当前命盘？', [
      { text: '取消', style: 'cancel' },
      {
        text: '确定',
        onPress: () => {
          setMingPan(null);
          setPersonality(null);
          setShowInput(true);
        },
      },
    ]);
  }, []);

  // 初始值（有 store 数据时预填）
  const initialDate = birthDate ? new Date(birthDate) : undefined;
  const initialGender = gender ?? undefined;
  const initialCity = birthCity ?? undefined;

  // ── 输入生辰 ──
  if (showInput) {
    return (
      <ScrollView style={styles.container} contentContainerStyle={styles.scroll}>
        <BirthInput
          onSubmit={handleBirthSubmit}
          initialDate={initialDate}
          initialGender={initialGender}
          initialCity={initialCity}
        />
      </ScrollView>
    );
  }

  // ── 未输入 ──
  if (!mingPan) {
    return (
      <View style={styles.container}>
        <View style={styles.emptyCenter}>
          <Text style={styles.emptyTitle}>遇见你自己</Text>
          <Text style={styles.emptySub}>输入生辰，开启专属命盘</Text>
          <Pressable style={styles.emptyBtn} onPress={() => setShowInput(true)}>
            <Text style={styles.emptyBtnText}>输入生辰</Text>
          </Pressable>
        </View>

        {/* 菜单 */}
        <View style={styles.menuSection}>
          <MenuItem title="情绪日记" />
          <MenuItem title="关系洞察" />
          <MenuItem title="流年运势" />
          <MenuItem title="设置" onPress={() => router.push('/settings')} />
        </View>
      </View>
    );
  }

  // ── 已有命盘 ──
  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.scroll}>
      {/* 日主 — 视觉锚点 */}
      <View style={styles.heroSection}>
        <Text style={styles.heroGan}>{mingPan.riZhu.gan}</Text>
        <Text style={styles.heroMeta}>
          {mingPan.riZhu.yinYang}{mingPan.riZhu.wuXing} · {mingPan.lunarDate}
        </Text>
        <Text style={styles.heroDesc}>{mingPan.riZhu.description}</Text>
      </View>

      {/* 四柱 */}
      <SectionTitle text="四柱" right={
        <Pressable onPress={handleReset}>
          <Text style={styles.resetText}>重新输入</Text>
        </Pressable>
      } />
      <MingPanCard mingPan={mingPan} />

      {/* 五行 */}
      <SectionTitle text="五行分布" />
      <WuXingChart
        balance={mingPan.wuXingStrength.balance}
        yongShen={mingPan.wuXingStrength.yongShen}
        xiShen={mingPan.wuXingStrength.xiShen}
      />

      {/* 格局 */}
      <SectionTitle text="格局" />
      <View style={styles.geJuBlock}>
        <Text style={styles.geJuName}>{mingPan.geJu.name}</Text>
        <Text style={styles.geJuMeta}>
          {mingPan.geJu.category} · {mingPan.geJu.strength}等
        </Text>
        <Text style={styles.geJuDesc}>{mingPan.geJu.modernMeaning}</Text>
      </View>

      {/* 人格 */}
      {personality && (
        <>
          <SectionTitle text="人格洞察" />
          <PersonalityCard insight={personality} />
        </>
      )}

      {/* 菜单 */}
      <View style={styles.menuSection}>
        <MenuItem title="情绪日记" />
        <MenuItem title="关系洞察" />
        <MenuItem title="流年运势" />
        <MenuItem title="设置" onPress={() => router.push('/settings')} />
      </View>
    </ScrollView>
  );
}

// ── 通用组件 ──

function SectionTitle({ text, right }: { text: string; right?: React.ReactNode }) {
  return (
    <View style={styles.sectionTitleRow}>
      <Text style={styles.sectionTitle}>{text}</Text>
      {right}
    </View>
  );
}

function MenuItem({ title, onPress }: { title: string; onPress?: () => void }) {
  return (
    <Pressable style={styles.menuItem} onPress={onPress}>
      <Text style={styles.menuText}>{title}</Text>
    </Pressable>
  );
}

// ── Styles ──

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.bg,
  },
  scroll: {
    paddingHorizontal: Space.lg,
    paddingBottom: Space['3xl'],
  },

  // 空状态
  emptyCenter: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingBottom: Space['3xl'],
  },
  emptyTitle: {
    ...Type.title,
    color: Colors.ink,
    fontWeight: '300',
  },
  emptySub: {
    ...Type.caption,
    color: Colors.inkTertiary,
    marginTop: Space.sm,
  },
  emptyBtn: {
    marginTop: Space.xl,
    paddingVertical: Space.md,
    paddingHorizontal: Space.xl,
    borderWidth: 1,
    borderColor: Colors.brand,
    borderRadius: 2,
  },
  emptyBtnText: {
    ...Type.body,
    color: Colors.brand,
    fontWeight: '500',
  },

  // 日主 hero
  heroSection: {
    alignItems: 'center',
    paddingTop: Space.xl,
    paddingBottom: Space['2xl'],
  },
  heroGan: {
    fontSize: 72,
    color: Colors.ink,
    fontWeight: '200',
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
  },

  // 分区标题
  sectionTitleRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingTop: Space.xl,
    paddingBottom: Space.md,
  },
  sectionTitle: {
    ...Type.label,
    color: Colors.inkTertiary,
    textTransform: 'uppercase',
  },
  resetText: {
    ...Type.caption,
    color: Colors.brand,
  },

  // 格局
  geJuBlock: {
    paddingBottom: Space.base,
  },
  geJuName: {
    ...Type.subtitle,
    color: Colors.ink,
    fontWeight: '400',
  },
  geJuMeta: {
    ...Type.label,
    color: Colors.inkTertiary,
    marginTop: Space.xs,
  },
  geJuDesc: {
    ...Type.body,
    color: Colors.inkSecondary,
    marginTop: Space.sm,
  },

  // 菜单 — 纯文字
  menuSection: {
    paddingTop: Space['2xl'],
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: Colors.inkHint + '30',
    marginTop: Space.xl,
  },
  menuItem: {
    paddingVertical: Space.base,
  },
  menuText: {
    ...Type.body,
    color: Colors.inkSecondary,
  },
});
