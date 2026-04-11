import { StyleSheet, View, Text, Pressable } from 'react-native';
import { useState } from 'react';
import FontAwesome from '@expo/vector-icons/FontAwesome';

const SOUNDSCAPES = [
  { id: 'rain', name: '谷雨听雨', icon: 'tint', season: '春' },
  { id: 'thunder', name: '惊蛰听雷', icon: 'bolt', season: '春' },
  { id: 'wind', name: '秋风落叶', icon: 'envira', season: '秋' },
  { id: 'fire', name: '冬至炉火', icon: 'fire', season: '冬' },
  { id: 'cicada', name: '小暑蝉鸣', icon: 'sun-o', season: '夏' },
  { id: 'stream', name: '山间溪流', icon: 'leaf', season: '四季' },
];

export default function AmbianceScreen() {
  const [playing, setPlaying] = useState<string | null>(null);

  return (
    <View style={styles.container}>
      <Text style={styles.sectionTitle}>节气音景</Text>
      <Text style={styles.sectionSub}>闭上眼，感受此刻</Text>

      <View style={styles.grid}>
        {SOUNDSCAPES.map((sound) => (
          <Pressable
            key={sound.id}
            style={[
              styles.soundCard,
              playing === sound.id && styles.soundCardActive,
            ]}
            onPress={() => setPlaying(playing === sound.id ? null : sound.id)}
          >
            <FontAwesome
              name={sound.icon as any}
              size={28}
              color={playing === sound.id ? '#FFFDF8' : '#8B7355'}
            />
            <Text style={[
              styles.soundName,
              playing === sound.id && styles.soundNameActive,
            ]}>
              {sound.name}
            </Text>
            <Text style={[
              styles.soundSeason,
              playing === sound.id && styles.soundSeasonActive,
            ]}>
              {sound.season}
            </Text>
          </Pressable>
        ))}
      </View>

      <View style={styles.breathSection}>
        <Text style={styles.sectionTitle}>呼吸引导</Text>
        <Pressable style={styles.breathButton}>
          <View style={styles.breathCircle}>
            <Text style={styles.breathText}>开始</Text>
          </View>
          <Text style={styles.breathDuration}>5 分钟 · 五行呼吸</Text>
        </Pressable>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F5F0E8',
    padding: 20,
  },
  sectionTitle: {
    fontSize: 20,
    color: '#2C1810',
    fontWeight: '600',
    letterSpacing: 4,
    marginTop: 20,
  },
  sectionSub: {
    fontSize: 13,
    color: '#B8A898',
    marginTop: 6,
    marginBottom: 20,
    letterSpacing: 2,
  },
  grid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 12,
  },
  soundCard: {
    width: '47%',
    backgroundColor: '#FFFDF8',
    borderRadius: 12,
    padding: 20,
    alignItems: 'center',
    gap: 8,
    borderWidth: 0.5,
    borderColor: '#E5DDD0',
  },
  soundCardActive: {
    backgroundColor: '#8B4513',
    borderColor: '#8B4513',
  },
  soundName: {
    fontSize: 14,
    color: '#2C1810',
    fontWeight: '500',
    letterSpacing: 2,
  },
  soundNameActive: {
    color: '#FFFDF8',
  },
  soundSeason: {
    fontSize: 11,
    color: '#B8A898',
  },
  soundSeasonActive: {
    color: '#D4A574',
  },
  breathSection: {
    marginTop: 30,
    alignItems: 'center',
  },
  breathButton: {
    alignItems: 'center',
    marginTop: 20,
  },
  breathCircle: {
    width: 100,
    height: 100,
    borderRadius: 50,
    backgroundColor: '#FFFDF8',
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 2,
    borderColor: '#8B4513',
  },
  breathText: {
    fontSize: 16,
    color: '#8B4513',
    fontWeight: '500',
    letterSpacing: 2,
  },
  breathDuration: {
    fontSize: 13,
    color: '#8B7355',
    marginTop: 12,
    letterSpacing: 1,
  },
});
