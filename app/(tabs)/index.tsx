import { StyleSheet, View, Text } from 'react-native';

export default function CalendarScreen() {
  return (
    <View style={styles.container}>
      <View style={styles.dateContainer}>
        <Text style={styles.lunarDate}>乙巳年 三月十四</Text>
        <Text style={styles.solarDate}>2026年4月11日 星期六</Text>
      </View>

      <View style={styles.calendarPage}>
        <Text style={styles.ganZhi}>辛巳日</Text>
        <Text style={styles.fortune}>宜 · 静心养神</Text>
        <Text style={styles.fortuneSub}>忌 · 急躁冒进</Text>
      </View>

      <View style={styles.wisdomContainer}>
        <Text style={styles.wisdom}>
          "水流不争先，争的是滔滔不绝"
        </Text>
      </View>

      <Text style={styles.hint}>↑ 向上拖动撕开日历</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#F5F0E8',
    padding: 20,
  },
  dateContainer: {
    alignItems: 'center',
    marginBottom: 40,
  },
  lunarDate: {
    fontSize: 16,
    color: '#8B7355',
    fontWeight: '300',
    letterSpacing: 4,
  },
  solarDate: {
    fontSize: 13,
    color: '#B8A898',
    marginTop: 6,
    letterSpacing: 2,
  },
  calendarPage: {
    width: 280,
    height: 360,
    backgroundColor: '#FFFDF8',
    borderRadius: 4,
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.08,
    shadowRadius: 12,
    elevation: 5,
    borderWidth: 0.5,
    borderColor: '#E5DDD0',
  },
  ganZhi: {
    fontSize: 36,
    color: '#2C1810',
    fontWeight: '600',
    letterSpacing: 8,
    marginBottom: 30,
  },
  fortune: {
    fontSize: 18,
    color: '#6B8E23',
    fontWeight: '400',
    letterSpacing: 4,
    marginBottom: 10,
  },
  fortuneSub: {
    fontSize: 18,
    color: '#CD853F',
    fontWeight: '400',
    letterSpacing: 4,
  },
  wisdomContainer: {
    marginTop: 40,
    paddingHorizontal: 30,
  },
  wisdom: {
    fontSize: 15,
    color: '#8B7355',
    fontWeight: '300',
    fontStyle: 'italic',
    textAlign: 'center',
    lineHeight: 24,
    letterSpacing: 1,
  },
  hint: {
    position: 'absolute',
    bottom: 40,
    fontSize: 12,
    color: '#C8B8A8',
    letterSpacing: 2,
  },
});
