import { StyleSheet, View, Text, Pressable, ScrollView } from 'react-native';
import FontAwesome from '@expo/vector-icons/FontAwesome';

export default function ProfileScreen() {
  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      {/* 用户卡片 */}
      <View style={styles.userCard}>
        <View style={styles.avatar}>
          <FontAwesome name="user" size={32} color="#8B4513" />
        </View>
        <Text style={styles.userName}>尚未登录</Text>
        <Text style={styles.userSub}>登录后解锁完整命盘</Text>
      </View>

      {/* 命盘概览（占位） */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>命盘概览</Text>
        <View style={styles.baziCard}>
          <View style={styles.baziPlaceholder}>
            <FontAwesome name="lock" size={24} color="#B8A898" />
            <Text style={styles.baziPlaceholderText}>输入生辰后解锁</Text>
          </View>
        </View>
      </View>

      {/* 五行分布（占位） */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>五行分布</Text>
        <View style={styles.wuxingRow}>
          {['金', '木', '水', '火', '土'].map((element, i) => (
            <View key={element} style={styles.wuxingItem}>
              <View style={[styles.wuxingBar, { height: [40, 60, 30, 50, 45][i] }]} />
              <Text style={styles.wuxingLabel}>{element}</Text>
            </View>
          ))}
        </View>
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
  section: {
    marginTop: 24,
  },
  sectionTitle: {
    fontSize: 16,
    color: '#2C1810',
    fontWeight: '600',
    letterSpacing: 3,
    marginBottom: 12,
  },
  baziCard: {
    backgroundColor: '#FFFDF8',
    borderRadius: 12,
    padding: 30,
    alignItems: 'center',
    borderWidth: 0.5,
    borderColor: '#E5DDD0',
  },
  baziPlaceholder: {
    alignItems: 'center',
    gap: 8,
  },
  baziPlaceholderText: {
    fontSize: 14,
    color: '#B8A898',
  },
  wuxingRow: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    alignItems: 'flex-end',
    height: 100,
    backgroundColor: '#FFFDF8',
    borderRadius: 12,
    padding: 16,
    borderWidth: 0.5,
    borderColor: '#E5DDD0',
  },
  wuxingItem: {
    alignItems: 'center',
    gap: 6,
  },
  wuxingBar: {
    width: 28,
    backgroundColor: '#D4A574',
    borderRadius: 4,
  },
  wuxingLabel: {
    fontSize: 13,
    color: '#8B7355',
    fontWeight: '500',
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
