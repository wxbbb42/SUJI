/**
 * 日历首页
 * 
 * 手撕日历 + 每日一语 + 时辰
 * 设计：大面积留白，格言做主视觉
 */

import { StyleSheet, View, Text, ScrollView } from 'react-native';
import { TearCalendar } from '@/components/calendar';
import { useState, useCallback, useEffect, useMemo } from 'react';
import { Colors, Space, Type } from '@/lib/design/tokens';
import lunisolar from 'lunisolar';

const SHICHEN = ['子','丑','寅','卯','辰','巳','午','未','申','酉','戌','亥'] as const;
const SHICHEN_TIME = [
  '23-01','01-03','03-05','05-07','07-09','09-11',
  '11-13','13-15','15-17','17-19','19-21','21-23',
] as const;

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
  const [tornToday, setTornToday] = useState(false);
  const [info, setInfo] = useState({
    lunarDate: '', solarDate: '', ganZhi: '', wisdom: '',
  });

  useEffect(() => {
    const now = new Date();
    const ls = lunisolar(now);
    const lunar = ls.lunar;
    const weekDays = ['日','一','二','三','四','五','六'];

    const dayOfYear = Math.floor(
      (now.getTime() - new Date(now.getFullYear(), 0, 0).getTime()) / 86400000
    );

    setInfo({
      lunarDate: `${ls.format('cY')}年 ${lunar.getMonthName()}${lunar.getDayName()}`,
      solarDate: `${now.getFullYear()}.${now.getMonth()+1}.${now.getDate()} 周${weekDays[now.getDay()]}`,
      ganZhi: ls.format('cD'),
      wisdom: WISDOMS[dayOfYear % WISDOMS.length],
    });
  }, []);

  const handleTearComplete = useCallback(() => setTornToday(true), []);

  // 简单吉时标记（后续接 InsightEngine）
  const goodHours = useMemo(() => new Set([2, 5, 7, 10]), []);

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.scroll}>
      <TearCalendar
        lunarDate={info.lunarDate}
        solarDate={info.solarDate}
        ganZhi={info.ganZhi}
        fortune="宜 · 静心养神"
        fortuneSub="忌 · 急躁冒进"
        wisdom={info.wisdom}
        onTearComplete={handleTearComplete}
      />

      {/* 今日一语 */}
      <View style={styles.wisdomSection}>
        <Text style={styles.wisdomText}>{info.wisdom}</Text>
        <Text style={styles.wisdomGanZhi}>{info.ganZhi}日</Text>
      </View>

      {/* 时辰 */}
      <View style={styles.hoursSection}>
        <Text style={styles.sectionLabel}>十二时辰</Text>
        <View style={styles.hoursGrid}>
          {SHICHEN.map((zhi, i) => (
            <View key={zhi} style={styles.hourCell}>
              <Text style={[
                styles.hourZhi,
                goodHours.has(i) && styles.hourZhiGood,
              ]}>
                {zhi}
              </Text>
              <Text style={styles.hourTime}>{SHICHEN_TIME[i]}</Text>
            </View>
          ))}
        </View>
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.bg,
  },
  scroll: {
    paddingBottom: Space['3xl'],
  },

  // 今日一语
  wisdomSection: {
    paddingHorizontal: Space.xl,
    paddingTop: Space['2xl'],
    paddingBottom: Space.xl,
    alignItems: 'center',
  },
  wisdomText: {
    ...Type.title,
    color: Colors.ink,
    textAlign: 'center',
    fontWeight: '300',
  },
  wisdomGanZhi: {
    ...Type.caption,
    color: Colors.inkTertiary,
    marginTop: Space.md,
  },

  // 时辰
  hoursSection: {
    paddingHorizontal: Space.lg,
    paddingTop: Space.lg,
  },
  sectionLabel: {
    ...Type.label,
    color: Colors.inkTertiary,
    textTransform: 'uppercase',
    marginBottom: Space.base,
  },
  hoursGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: Space.xs,
  },
  hourCell: {
    width: '15.5%',
    alignItems: 'center',
    paddingVertical: Space.sm,
  },
  hourZhi: {
    ...Type.body,
    color: Colors.inkSecondary,
    fontWeight: '400',
  },
  hourZhiGood: {
    color: Colors.brand,
    fontWeight: '600',
  },
  hourTime: {
    ...Type.label,
    color: Colors.inkHint,
    marginTop: Space.xs,
  },
});
