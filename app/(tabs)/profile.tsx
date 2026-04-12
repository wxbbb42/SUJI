import { StyleSheet, View, Text, Pressable, ScrollView } from 'react-native';
import FontAwesome from '@expo/vector-icons/FontAwesome';
import { useState } from 'react';
import type { MingPan } from '@/lib/bazi';
import { InsightEngine } from '@/lib/bazi';
import BirthInput from '@/components/bazi/BirthInput';
import MingPanCard from '@/components/bazi/MingPanCard';
import WuXingChart from '@/components/bazi/WuXingChart';
import { PersonalityCard } from '@/components/bazi/PersonalityCard';

export default function ProfileScreen() {
  // TODO: 后续用 AsyncStorage 持久化
  const [mingPan, setMingPan] = useState<MingPan | null>(null);

  // 已有命盘时，按需计算人格洞察
  const personalityInsight = mingPan
    ? new InsightEngine(mingPan).getPersonalityInsight()
    : null;

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      {/* 用户卡片 */}
      <View style={styles.userCard}>
        <View style={styles.avatar}>
          <FontAwesome name="user" size={32} color="#8B4513" />
        </View>
        <Text style={styles.userName}>
          {mingPan
            ? `${mingPan.riZhu.gan}日生 · ${mingPan.gender}`
            : '尚未输入生辰'}
        </Text>
        <Text style={styles.userSub}>
          {mingPan
            ? mingPan.lunarDate
            : '输入生辰后解锁完整命盘'}
        </Text>
        {mingPan && (
          <Pressable style={styles.resetBtn} onPress={() => setMingPan(null)}>
            <Text style={styles.resetText}>重新输入</Text>
          </Pressable>
        )}
      </View>

      {!mingPan ? (
        /* ── 未输入生辰：显示输入表单 ────────────────────────────── */
        <View style={styles.section}>
          <BirthInput onSubmit={setMingPan} />
        </View>
      ) : (
        /* ── 已有命盘：展示完整分析 ──────────────────────────────── */
        <>
          <View style={styles.section}>
            <MingPanCard mingPan={mingPan} />
          </View>

          <View style={styles.section}>
            <WuXingChart wuXingStrength={mingPan.wuXingStrength} />
          </View>

          {personalityInsight && (
            <View style={styles.section}>
              <PersonalityCard insight={personalityInsight} />
            </View>
          )}
        </>
      )}

      {/* 功能入口（始终显示） */}
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
    paddingBottom: 40,
  },
  userCard: {
    alignItems: 'center',
    paddingVertical: 30,
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
  },
  resetBtn: {
    marginTop: 10,
    paddingHorizontal: 16,
    paddingVertical: 6,
    borderRadius: 20,
    borderWidth: 0.5,
    borderColor: '#D4A574',
  },
  resetText: {
    fontSize: 12,
    color: '#8B4513',
    letterSpacing: 1,
  },
  section: {
    marginTop: 16,
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
