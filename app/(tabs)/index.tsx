/**
 * 日历首页
 * 
 * 手撕日历 + 每日运势卡
 * 根据用户命盘生成个性化每日洞察
 */

import { StyleSheet, View, Text, ScrollView } from 'react-native';
import { TearCalendar } from '@/components/calendar';
import { useState, useCallback, useEffect, useMemo } from 'react';
import FontAwesome from '@expo/vector-icons/FontAwesome';
import lunisolar from 'lunisolar';

export default function CalendarScreen() {
  const [tornToday, setTornToday] = useState(false);
  const [todayInfo, setTodayInfo] = useState({
    lunarDate: '',
    solarDate: '',
    ganZhi: '',
    fortune: '宜 · 静心养神',
    fortuneSub: '忌 · 急躁冒进',
    wisdom: '',
  });

  // 每日格言池
  const wisdoms = useMemo(() => [
    '水流不争先，争的是滔滔不绝',
    '大道至简，衍化至繁',
    '知止而后有定，定而后能静',
    '上善若水，水善利万物而不争',
    '千里之行，始于足下',
    '静以修身，俭以养德',
    '不积跬步，无以至千里',
    '心若冰清，天塌不惊',
    '知者不惑，仁者不忧，勇者不惧',
    '万物并作，吾以观复',
    '致虚极，守静笃',
    '天行健，君子以自强不息',
  ], []);

  useEffect(() => {
    const now = new Date();
    const ls = lunisolar(now);
    const lunar = ls.lunar;

    // 农历日期
    const lunarStr = `${ls.format('cY')}年 ${lunar.getMonthName()}${lunar.getDayName()}`;
    
    // 公历日期
    const weekDays = ['星期日', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六'];
    const solarStr = `${now.getFullYear()}年${now.getMonth() + 1}月${now.getDate()}日 ${weekDays[now.getDay()]}`;

    // 日干支
    const dayGanZhi = ls.format('cD');

    // 随机格言（按日期固定）
    const dayOfYear = Math.floor((now.getTime() - new Date(now.getFullYear(), 0, 0).getTime()) / 86400000);
    const wisdom = wisdoms[dayOfYear % wisdoms.length];

    setTodayInfo({
      lunarDate: lunarStr,
      solarDate: solarStr,
      ganZhi: dayGanZhi,
      fortune: '宜 · 静心养神',
      fortuneSub: '忌 · 急躁冒进',
      wisdom,
    });
  }, [wisdoms]);

  const handleTearComplete = useCallback(() => {
    setTornToday(true);
  }, []);

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.scrollContent}>
      <TearCalendar
        lunarDate={todayInfo.lunarDate}
        solarDate={todayInfo.solarDate}
        ganZhi={todayInfo.ganZhi}
        fortune={todayInfo.fortune}
        fortuneSub={todayInfo.fortuneSub}
        wisdom={todayInfo.wisdom}
        onTearComplete={handleTearComplete}
      />

      {/* 今日运势卡 */}
      <View style={styles.dailyCard}>
        <View style={styles.dailyHeader}>
          <FontAwesome name="sun-o" size={16} color="#C4A35A" />
          <Text style={styles.dailyTitle}>今日能量</Text>
        </View>
        
        <View style={styles.energyRow}>
          <View style={styles.energyItem}>
            <Text style={styles.energyLabel}>日干支</Text>
            <Text style={styles.energyValue}>{todayInfo.ganZhi || '...'}</Text>
          </View>
          <View style={styles.energyDivider} />
          <View style={styles.energyItem}>
            <Text style={styles.energyLabel}>宜</Text>
            <Text style={styles.energyValue}>静心·读书</Text>
          </View>
          <View style={styles.energyDivider} />
          <View style={styles.energyItem}>
            <Text style={styles.energyLabel}>忌</Text>
            <Text style={styles.energyValue}>争执·冒进</Text>
          </View>
        </View>

        <View style={styles.adviceSection}>
          <Text style={styles.adviceText}>
            {todayInfo.wisdom}
          </Text>
        </View>
      </View>

      {/* 时辰吉凶 */}
      <View style={styles.hoursCard}>
        <View style={styles.dailyHeader}>
          <FontAwesome name="clock-o" size={16} color="#8B4513" />
          <Text style={styles.dailyTitle}>时辰参考</Text>
        </View>
        <View style={styles.hoursGrid}>
          {['子', '丑', '寅', '卯', '辰', '巳', '午', '未', '申', '酉', '戌', '亥'].map((zhi, i) => {
            const times = [
              '23-01', '01-03', '03-05', '05-07', '07-09', '09-11',
              '11-13', '13-15', '15-17', '17-19', '19-21', '21-23',
            ];
            // 简单的吉凶标记（后续接 InsightEngine）
            const isGood = [2, 5, 7, 10].includes(i);
            return (
              <View key={zhi} style={[styles.hourItem, isGood && styles.hourItemGood]}>
                <Text style={[styles.hourZhi, isGood && styles.hourZhiGood]}>{zhi}</Text>
                <Text style={styles.hourTime}>{times[i]}</Text>
              </View>
            );
          })}
        </View>
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F5F0E8',
  },
  scrollContent: {
    paddingBottom: 40,
  },
  dailyCard: {
    backgroundColor: '#FFFDF8',
    borderRadius: 16,
    marginHorizontal: 20,
    marginTop: 16,
    padding: 18,
    borderWidth: 0.5,
    borderColor: '#E5DDD0',
  },
  dailyHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    marginBottom: 14,
  },
  dailyTitle: {
    fontSize: 15,
    color: '#2C1810',
    fontWeight: '600',
    letterSpacing: 2,
  },
  energyRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-around',
    marginBottom: 14,
  },
  energyItem: {
    alignItems: 'center',
    gap: 4,
  },
  energyLabel: {
    fontSize: 11,
    color: '#B8A898',
    letterSpacing: 1,
  },
  energyValue: {
    fontSize: 15,
    color: '#2C1810',
    fontWeight: '600',
  },
  energyDivider: {
    width: 1,
    height: 30,
    backgroundColor: '#E5DDD0',
  },
  adviceSection: {
    backgroundColor: '#F5F0E8',
    borderRadius: 10,
    padding: 14,
    alignItems: 'center',
  },
  adviceText: {
    fontSize: 14,
    color: '#8B7355',
    lineHeight: 22,
    textAlign: 'center',
    letterSpacing: 1,
  },
  hoursCard: {
    backgroundColor: '#FFFDF8',
    borderRadius: 16,
    marginHorizontal: 20,
    marginTop: 12,
    padding: 18,
    borderWidth: 0.5,
    borderColor: '#E5DDD0',
  },
  hoursGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
    justifyContent: 'center',
  },
  hourItem: {
    width: '15%',
    alignItems: 'center',
    paddingVertical: 8,
    borderRadius: 8,
    backgroundColor: '#F5F0E8',
  },
  hourItemGood: {
    backgroundColor: '#8B451318',
    borderWidth: 1,
    borderColor: '#8B451330',
  },
  hourZhi: {
    fontSize: 14,
    color: '#2C1810',
    fontWeight: '600',
  },
  hourZhiGood: {
    color: '#8B4513',
  },
  hourTime: {
    fontSize: 9,
    color: '#B8A898',
    marginTop: 2,
  },
});
