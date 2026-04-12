/**
 * 「我的」页面
 * 
 * 未输入生辰：显示 BirthInput
 * 已输入生辰：显示完整命盘（MingPanCard + WuXingChart + PersonalityCard）
 */

import { StyleSheet, View, Text, Pressable, ScrollView, Alert } from 'react-native';
import FontAwesome from '@expo/vector-icons/FontAwesome';
import { useState, useCallback, useMemo } from 'react';

import { BirthInput, MingPanCard, WuXingChart, PersonalityCard } from '@/components/bazi';
import { BaziEngine } from '@/lib/bazi/BaziEngine';
import { InsightEngine } from '@/lib/bazi/InsightEngine';
import type { MingPan, PersonalityInsight } from '@/lib/bazi/types';

interface BirthData {
  date: Date;
  gender: '男' | '女';
}

export default function ProfileScreen() {
  const [birthData, setBirthData] = useState<BirthData | null>(null);
  const [mingPan, setMingPan] = useState<MingPan | null>(null);
  const [personality, setPersonality] = useState<PersonalityInsight | null>(null);
  const [showInput, setShowInput] = useState(false);

  const baziEngine = useMemo(() => new BaziEngine(), []);

  const handleBirthSubmit = useCallback((date: Date, gender: '男' | '女') => {
    try {
      const result = baziEngine.calculate(date, gender);
      const insightEngine = new InsightEngine(result);
      const personalityInsight = insightEngine.getPersonalityInsight();

      setBirthData({ date, gender });
      setMingPan(result);
      setPersonality(personalityInsight);
      setShowInput(false);
    } catch (err) {
      Alert.alert('排盘失败', '请检查输入的日期和时间是否正确');
      console.error('BaziEngine error:', err);
    }
  }, [baziEngine]);

  const handleReset = useCallback(() => {
    Alert.alert(
      '重新输入',
      '确定要清除当前命盘数据吗？',
      [
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
      ]
    );
  }, []);

  // 未输入生辰 — 显示引导
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
        {/* 用户卡片 */}
        <View style={styles.userCard}>
          <View style={styles.avatar}>
            <FontAwesome name="user" size={32} color="#8B4513" />
          </View>
          <Text style={styles.userName}>遇见你自己</Text>
          <Text style={styles.userSub}>输入生辰，开启你的专属命盘</Text>
        </View>

        {/* 命盘占位 */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>命盘概览</Text>
          <Pressable style={styles.baziCard} onPress={() => setShowInput(true)}>
            <View style={styles.baziPlaceholder}>
              <FontAwesome name="plus-circle" size={32} color="#8B4513" />
              <Text style={styles.baziPlaceholderText}>点击输入生辰</Text>
              <Text style={styles.baziPlaceholderSub}>需要出生年月日和大致时辰</Text>
            </View>
          </Pressable>
        </View>

        {/* 功能入口 */}
        <View style={styles.section}>
          <MenuItem icon="calendar-check-o" title="情绪日记" subtitle="记录每日心情" />
          <MenuItem icon="heart" title="关系洞察" subtitle="了解你与 TA 的相处之道" />
          <MenuItem icon="line-chart" title="流年运势" subtitle="年度能量走向" />
          <MenuItem icon="paint-brush" title="主题" subtitle="留白宣纸风" />
          <MenuItem icon="cog" title="设置" subtitle="" />
        </View>
      </ScrollView>
    );
  }

  // 已输入生辰 — 显示完整命盘
  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      {/* 用户卡片 */}
      <View style={styles.userCard}>
        <View style={styles.avatarActive}>
          <Text style={styles.avatarEmoji}>
            {mingPan.riZhu.wuXing === '金' ? '🪙' :
             mingPan.riZhu.wuXing === '木' ? '🌿' :
             mingPan.riZhu.wuXing === '水' ? '💧' :
             mingPan.riZhu.wuXing === '火' ? '🔥' : '🏔️'}
          </Text>
        </View>
        <Text style={styles.userName}>
          {mingPan.riZhu.gan}{mingPan.riZhu.yinYang === '阳' ? '阳' : '阴'}{mingPan.riZhu.wuXing}命
        </Text>
        <Text style={styles.userSub}>{mingPan.riZhu.description}</Text>
        <Text style={styles.lunarDate}>{mingPan.lunarDate}</Text>
      </View>

      {/* 四柱命盘 */}
      <View style={styles.section}>
        <View style={styles.sectionRow}>
          <Text style={styles.sectionTitle}>四柱命盘</Text>
          <Pressable onPress={handleReset}>
            <Text style={styles.resetText}>重新输入</Text>
          </Pressable>
        </View>
        <MingPanCard mingPan={mingPan} />
      </View>

      {/* 五行分布 */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>五行分布</Text>
        <WuXingChart
          balance={mingPan.wuXingStrength.balance}
          yongShen={mingPan.wuXingStrength.yongShen}
          xiShen={mingPan.wuXingStrength.xiShen}
        />
      </View>

      {/* 格局 */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>格局</Text>
        <View style={styles.geJuCard}>
          <View style={styles.geJuHeader}>
            <Text style={styles.geJuName}>{mingPan.geJu.name}</Text>
            <View style={[styles.geJuBadge, 
              mingPan.geJu.strength === '上' ? styles.badgeGold :
              mingPan.geJu.strength === '中' ? styles.badgeSilver : styles.badgeBronze
            ]}>
              <Text style={styles.geJuBadgeText}>{mingPan.geJu.strength}格</Text>
            </View>
          </View>
          <Text style={styles.geJuDesc}>{mingPan.geJu.modernMeaning}</Text>
        </View>
      </View>

      {/* 人格洞察 */}
      {personality && (
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>人格洞察</Text>
          <PersonalityCard insight={personality} />
        </View>
      )}

      {/* 神煞速览 */}
      {mingPan.shenSha.length > 0 && (
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>神煞速览</Text>
          <View style={styles.shenShaGrid}>
            {mingPan.shenSha.slice(0, 8).map((sha, i) => (
              <View key={`${sha.name}-${i}`} style={styles.shenShaItem}>
                <Text style={[styles.shenShaType,
                  sha.type === '吉' ? styles.shenShaJi : 
                  sha.type === '凶' ? styles.shenShaXiong : styles.shenShaZhong
                ]}>
                  {sha.type === '吉' ? '★' : sha.type === '凶' ? '✕' : '○'}
                </Text>
                <Text style={styles.shenShaName}>{sha.name}</Text>
                <Text style={styles.shenShaDesc} numberOfLines={2}>
                  {sha.modernMeaning}
                </Text>
              </View>
            ))}
          </View>
        </View>
      )}

      {/* 功能入口 */}
      <View style={styles.section}>
        <MenuItem icon="calendar-check-o" title="情绪日记" subtitle="记录每日心情" />
        <MenuItem icon="heart" title="关系洞察" subtitle="了解你与 TA 的相处之道" />
        <MenuItem icon="line-chart" title="流年运势" subtitle="年度能量走向" />
        <MenuItem icon="paint-brush" title="主题" subtitle="留白宣纸风" />
        <MenuItem icon="cog" title="设置" subtitle="" />
      </View>
    </ScrollView>
  );
}

function MenuItem({ icon, title, subtitle }: { icon: string; title: string; subtitle: string }) {
  return (
    <Pressable style={styles.menuItem}>
      <FontAwesome name={icon as any} size={18} color="#8B7355" style={styles.menuIcon} />
      <View style={styles.menuText}>
        <Text style={styles.menuTitle}>{title}</Text>
        {subtitle ? <Text style={styles.menuSub}>{subtitle}</Text> : null}
      </View>
      <FontAwesome name="angle-right" size={18} color="#C8B8A8" />
    </Pressable>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F5F0E8',
  },
  content: {
    padding: 20,
    paddingBottom: 60,
  },
  userCard: {
    alignItems: 'center',
    paddingVertical: 24,
  },
  avatar: {
    width: 72,
    height: 72,
    borderRadius: 36,
    backgroundColor: '#FFFDF8',
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 2,
    borderColor: '#E5DDD0',
  },
  avatarActive: {
    width: 72,
    height: 72,
    borderRadius: 36,
    backgroundColor: '#FFFDF8',
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 2,
    borderColor: '#8B4513',
  },
  avatarEmoji: {
    fontSize: 32,
  },
  userName: {
    fontSize: 18,
    color: '#2C1810',
    fontWeight: '600',
    marginTop: 12,
    letterSpacing: 2,
  },
  userSub: {
    fontSize: 13,
    color: '#B8A898',
    marginTop: 4,
    textAlign: 'center',
    paddingHorizontal: 40,
    lineHeight: 20,
  },
  lunarDate: {
    fontSize: 12,
    color: '#8B7355',
    marginTop: 6,
    letterSpacing: 1,
  },
  section: {
    marginTop: 24,
  },
  sectionRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 12,
  },
  sectionTitle: {
    fontSize: 16,
    color: '#2C1810',
    fontWeight: '600',
    letterSpacing: 3,
    marginBottom: 12,
  },
  resetText: {
    fontSize: 13,
    color: '#8B4513',
    marginBottom: 12,
  },
  baziCard: {
    backgroundColor: '#FFFDF8',
    borderRadius: 12,
    padding: 40,
    alignItems: 'center',
    borderWidth: 0.5,
    borderColor: '#E5DDD0',
  },
  baziPlaceholder: {
    alignItems: 'center',
    gap: 8,
  },
  baziPlaceholderText: {
    fontSize: 15,
    color: '#8B4513',
    fontWeight: '500',
    marginTop: 4,
  },
  baziPlaceholderSub: {
    fontSize: 12,
    color: '#B8A898',
  },
  geJuCard: {
    backgroundColor: '#FFFDF8',
    borderRadius: 12,
    padding: 16,
    borderWidth: 0.5,
    borderColor: '#E5DDD0',
  },
  geJuHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    marginBottom: 8,
  },
  geJuName: {
    fontSize: 17,
    color: '#2C1810',
    fontWeight: '700',
    letterSpacing: 2,
  },
  geJuBadge: {
    paddingHorizontal: 8,
    paddingVertical: 2,
    borderRadius: 10,
  },
  badgeGold: {
    backgroundColor: '#C4A35A28',
  },
  badgeSilver: {
    backgroundColor: '#B8A89828',
  },
  badgeBronze: {
    backgroundColor: '#8B735528',
  },
  geJuBadgeText: {
    fontSize: 11,
    color: '#8B7355',
    fontWeight: '600',
  },
  geJuDesc: {
    fontSize: 14,
    color: '#2C1810',
    lineHeight: 22,
  },
  shenShaGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  shenShaItem: {
    width: '47%',
    backgroundColor: '#FFFDF8',
    borderRadius: 10,
    padding: 12,
    borderWidth: 0.5,
    borderColor: '#E5DDD0',
  },
  shenShaType: {
    fontSize: 14,
    fontWeight: '700',
    marginBottom: 2,
  },
  shenShaJi: {
    color: '#C4A35A',
  },
  shenShaXiong: {
    color: '#E53935',
  },
  shenShaZhong: {
    color: '#B8A898',
  },
  shenShaName: {
    fontSize: 14,
    color: '#2C1810',
    fontWeight: '600',
    marginBottom: 4,
  },
  shenShaDesc: {
    fontSize: 11,
    color: '#8B7355',
    lineHeight: 16,
  },
  menuItem: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#FFFDF8',
    borderRadius: 12,
    padding: 16,
    marginBottom: 8,
    borderWidth: 0.5,
    borderColor: '#E5DDD0',
  },
  menuIcon: {
    width: 28,
  },
  menuText: {
    flex: 1,
    marginLeft: 8,
  },
  menuTitle: {
    fontSize: 15,
    color: '#2C1810',
    fontWeight: '500',
  },
  menuSub: {
    fontSize: 12,
    color: '#B8A898',
    marginTop: 2,
  },
});
