/**
 * 「我的」页面（重设计版）
 * 日主文字作为视觉锚点 · 无头像圆框 · 菜单纯文字链接 · 无卡片边框
 */

import { StyleSheet, View, Text, Pressable, ScrollView, Alert } from 'react-native';
import { useState, useCallback, useMemo } from 'react';

import { BirthInput, MingPanCard, WuXingChart, PersonalityCard } from '@/components/bazi';
import { BaziEngine } from '@/lib/bazi/BaziEngine';
import { InsightEngine } from '@/lib/bazi/InsightEngine';
import type { MingPan, PersonalityInsight } from '@/lib/bazi/types';

// ── 色彩系统 ───────────────────────────────────────────────────────────
const C = {
  bg:      '#F5EDE0',
  surface: '#FFFBF5',
  deep:    '#2C1810',
  mid:     '#6B5040',
  mute:    '#8B7355',
  faint:   '#B8A898',
  brand:   '#8B4513',
};

interface BirthData {
  date:   Date;
  gender: '男' | '女';
}

export default function ProfileScreen() {
  const [birthData,  setBirthData]  = useState<BirthData | null>(null);
  const [mingPan,    setMingPan]    = useState<MingPan | null>(null);
  const [personality, setPersonality] = useState<PersonalityInsight | null>(null);
  const [showInput,  setShowInput]  = useState(false);

  const baziEngine = useMemo(() => new BaziEngine(), []);

  const handleBirthSubmit = useCallback((date: Date, gender: '男' | '女') => {
    try {
      const result = baziEngine.calculate(date, gender);
      const ie     = new InsightEngine(result);
      setBirthData({ date, gender });
      setMingPan(result);
      setPersonality(ie.getPersonalityInsight());
      setShowInput(false);
    } catch (err) {
      Alert.alert('排盘失败', '请检查输入的日期和时间是否正确');
    }
  }, [baziEngine]);

  const handleReset = useCallback(() => {
    Alert.alert('重新输入', '确定要清除当前命盘数据吗？', [
      { text: '取消', style: 'cancel' },
      {
        text: '确定',
        onPress: () => {
          setBirthData(null);
          setMingPan(null);
          setPersonality(null);
          setShowInput(false);
        },
      },
    ]);
  }, []);

  // ── 未输入生辰 ────────────────────────────────────────────────────────
  if (!mingPan) {
    if (showInput) {
      return (
        <ScrollView style={styles.container} contentContainerStyle={styles.content}>
          <BirthInput onSubmit={handleBirthSubmit} />
        </ScrollView>
      );
    }

    return (
      <ScrollView style={styles.container} contentContainerStyle={styles.content}>
        {/* 引导区 */}
        <View style={styles.hero}>
          <Text style={styles.heroGlyph}>命</Text>
          <Text style={styles.heroTitle}>遇见你自己</Text>
          <Text style={styles.heroSub}>输入生辰，开启专属命盘</Text>
          <Pressable onPress={() => setShowInput(true)} style={styles.heroAction}>
            <Text style={styles.heroActionText}>输入生辰</Text>
          </Pressable>
        </View>

        {/* 菜单 */}
        <View style={styles.menuSection}>
          <MenuItem title="情绪日记" sub="记录每日心情" />
          <MenuItem title="关系洞察" sub="了解你与 TA 的相处之道" />
          <MenuItem title="流年运势" sub="年度能量走向" />
          <MenuItem title="主题"     sub="留白宣纸风" />
          <MenuItem title="设置"     sub="" />
        </View>
      </ScrollView>
    );
  }

  // ── 已输入生辰 ────────────────────────────────────────────────────────
  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      {/* 日主 — 页面视觉锚点 */}
      <View style={styles.hero}>
        <Text style={styles.dayMasterGlyph}>{mingPan.riZhu.gan}</Text>
        <Text style={styles.dayMasterTitle}>
          {mingPan.riZhu.yinYang}{mingPan.riZhu.wuXing}
        </Text>
        <Text style={styles.dayMasterDesc} numberOfLines={3}>{mingPan.riZhu.description}</Text>
        <Text style={styles.lunarDate}>{mingPan.lunarDate}</Text>
        <Pressable onPress={handleReset} style={styles.resetBtn}>
          <Text style={styles.resetText}>重新输入</Text>
        </Pressable>
      </View>

      {/* 四柱命盘 */}
      <View style={styles.section}>
        <Text style={styles.sectionLabel}>四柱命盘</Text>
        <MingPanCard mingPan={mingPan} />
      </View>

      {/* 五行分布 */}
      <View style={styles.section}>
        <Text style={styles.sectionLabel}>五行分布</Text>
        <WuXingChart
          balance={mingPan.wuXingStrength.balance}
          yongShen={mingPan.wuXingStrength.yongShen}
          xiShen={mingPan.wuXingStrength.xiShen}
        />
      </View>

      {/* 格局 */}
      <View style={styles.section}>
        <Text style={styles.sectionLabel}>格局</Text>
        <Text style={styles.geJuName}>{mingPan.geJu.name}</Text>
        <Text style={styles.geJuMeta}>{mingPan.geJu.category} · {mingPan.geJu.strength}等</Text>
        <Text style={styles.geJuDesc}>{mingPan.geJu.modernMeaning}</Text>
      </View>

      {/* 人格洞察 */}
      {personality && (
        <View style={styles.section}>
          <Text style={styles.sectionLabel}>人格洞察</Text>
          <PersonalityCard insight={personality} />
        </View>
      )}

      {/* 神煞速览 */}
      {mingPan.shenSha.length > 0 && (
        <View style={styles.section}>
          <Text style={styles.sectionLabel}>神煞速览</Text>
          <View style={styles.shenShaList}>
            {mingPan.shenSha.slice(0, 8).map((sha, i) => (
              <View key={`${sha.name}-${i}`} style={styles.shenShaRow}>
                <Text style={[
                  styles.shenShaName,
                  sha.type === '吉' ? styles.colorJi : sha.type === '凶' ? styles.colorXiong : null,
                ]}>
                  {sha.name}
                </Text>
                <Text style={styles.shenShaDesc} numberOfLines={2}>{sha.modernMeaning}</Text>
              </View>
            ))}
          </View>
        </View>
      )}

      {/* 菜单 */}
      <View style={styles.menuSection}>
        <MenuItem title="情绪日记" sub="记录每日心情" />
        <MenuItem title="关系洞察" sub="了解你与 TA 的相处之道" />
        <MenuItem title="流年运势" sub="年度能量走向" />
        <MenuItem title="主题"     sub="留白宣纸风" />
        <MenuItem title="设置"     sub="" />
      </View>
    </ScrollView>
  );
}

// ── MenuItem — 纯文字，无图标无箭头 ──────────────────────────────────
function MenuItem({ title, sub }: { title: string; sub: string }) {
  return (
    <Pressable style={styles.menuItem}>
      <Text style={styles.menuTitle}>{title}</Text>
      {sub ? <Text style={styles.menuSub}>{sub}</Text> : null}
    </Pressable>
  );
}

// ── Styles ────────────────────────────────────────────────────────────
const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: C.bg,
  },
  content: {
    paddingHorizontal: 24,
    paddingTop: 32,
    paddingBottom: 64,
  },

  // 引导 / 日主 hero 区
  hero: {
    paddingBottom: 40,
    alignItems: 'flex-start',
  },
  heroGlyph: {
    fontSize:      80,
    color:         C.deep,
    fontWeight:    '100',
    letterSpacing: 4,
    lineHeight:    88,
    marginBottom:  8,
    opacity:       0.18,
  },
  heroTitle: {
    fontSize:      24,
    color:         C.deep,
    fontWeight:    '300',
    letterSpacing: 8,
    marginBottom:  8,
  },
  heroSub: {
    fontSize:      13,
    color:         C.faint,
    letterSpacing: 2,
    marginBottom:  24,
  },
  heroAction: {
    paddingVertical: 4,
  },
  heroActionText: {
    fontSize:      15,
    color:         C.brand,
    letterSpacing: 6,
    fontWeight:    '400',
  },

  // 日主大字
  dayMasterGlyph: {
    fontSize:      80,
    fontWeight:    '600',
    color:         C.brand,
    lineHeight:    88,
    marginBottom:  4,
  },
  dayMasterTitle: {
    fontSize:      28,
    color:         C.deep,
    fontWeight:    '200',
    letterSpacing: 8,
    marginBottom:  12,
  },
  dayMasterDesc: {
    fontSize:      14,
    color:         C.mid,
    lineHeight:    24,
    marginBottom:  12,
    maxWidth:      280,
  },
  lunarDate: {
    fontSize:      12,
    color:         C.faint,
    letterSpacing: 2,
    marginBottom:  16,
  },
  resetBtn: {
    paddingVertical: 4,
  },
  resetText: {
    fontSize:      13,
    color:         C.mute,
    letterSpacing: 2,
  },

  // 章节
  section: {
    marginBottom: 40,
  },
  sectionLabel: {
    fontSize:      11,
    color:         C.faint,
    letterSpacing: 4,
    marginBottom:  16,
  },

  // 格局（内联文字，不用卡片）
  geJuName: {
    fontSize:      18,
    color:         C.deep,
    fontWeight:    '500',
    letterSpacing: 3,
    marginBottom:  4,
  },
  geJuMeta: {
    fontSize:      12,
    color:         C.faint,
    letterSpacing: 1,
    marginBottom:  8,
  },
  geJuDesc: {
    fontSize:      14,
    color:         C.mid,
    lineHeight:    24,
  },

  // 神煞
  shenShaList: {
    gap: 16,
  },
  shenShaRow: {
    gap: 3,
  },
  shenShaName: {
    fontSize:      13,
    color:         C.deep,
    fontWeight:    '500',
    letterSpacing: 1,
  },
  shenShaDesc: {
    fontSize:  12,
    color:     C.mute,
    lineHeight: 18,
  },
  colorJi: {
    color: '#7A8B14',
  },
  colorXiong: {
    color: '#B84A3A',
  },

  // 菜单 — 纯文字链接
  menuSection: {
    marginTop:    8,
    paddingTop:   24,
    borderTopWidth: 0.5,
    borderTopColor: '#DDD4C4',
  },
  menuItem: {
    paddingVertical: 16,
    borderBottomWidth: 0.5,
    borderBottomColor: '#DDD4C4',
  },
  menuTitle: {
    fontSize:      15,
    color:         C.deep,
    letterSpacing: 2,
  },
  menuSub: {
    fontSize:      12,
    color:         C.faint,
    letterSpacing: 1,
    marginTop:     3,
  },
});
