import { StyleSheet, View } from 'react-native';
import { TearCalendar } from '@/components/calendar';
import { useState, useCallback } from 'react';

export default function CalendarScreen() {
  const [tornToday, setTornToday] = useState(false);

  const handleTearComplete = useCallback(() => {
    setTornToday(true);
    // TODO: 触发音效（撕纸声）
    // TODO: 触觉反馈 (Haptics)
    // TODO: 记录已撕状态到本地存储
  }, []);

  return (
    <View style={styles.container}>
      <TearCalendar
        lunarDate="乙巳年 三月十四"
        solarDate="2026年4月11日 星期六"
        ganZhi="辛巳"
        fortune="宜 · 静心养神"
        fortuneSub="忌 · 急躁冒进"
        wisdom="水流不争先，争的是滔滔不绝"
        onTearComplete={handleTearComplete}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F5F0E8',
  },
});
