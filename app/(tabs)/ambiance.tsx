/**
 * 静心页面
 * 
 * 节气音景 + 呼吸引导
 * 设计：极简，靠间距和字号说话
 */

import { StyleSheet, View, Text, Pressable } from 'react-native';
import { useState } from 'react';
import { Colors, Space, Type } from '@/lib/design/tokens';

const SOUNDSCAPES = [
  { id: 'rain',    name: '谷雨听雨', season: '春' },
  { id: 'thunder', name: '惊蛰听雷', season: '春' },
  { id: 'wind',    name: '秋风落叶', season: '秋' },
  { id: 'fire',    name: '冬至炉火', season: '冬' },
  { id: 'cicada',  name: '小暑蝉鸣', season: '夏' },
  { id: 'stream',  name: '山间溪流', season: '四季' },
];

export default function AmbianceScreen() {
  const [playing, setPlaying] = useState<string | null>(null);

  return (
    <View style={styles.container}>
      {/* 节气音景 */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>节气音景</Text>
        <Text style={styles.sectionSub}>闭上眼，感受此刻</Text>

        <View style={styles.soundList}>
          {SOUNDSCAPES.map((sound) => {
            const active = playing === sound.id;
            return (
              <Pressable
                key={sound.id}
                style={styles.soundItem}
                onPress={() => setPlaying(active ? null : sound.id)}
              >
                <Text style={[styles.soundName, active && styles.soundNameActive]}>
                  {sound.name}
                </Text>
                <Text style={[styles.soundSeason, active && styles.soundSeasonActive]}>
                  {sound.season}
                </Text>
              </Pressable>
            );
          })}
        </View>
      </View>

      {/* 呼吸引导 */}
      <View style={styles.breathSection}>
        <Text style={styles.sectionTitle}>呼吸引导</Text>

        <Pressable style={styles.breathCenter}>
          <Text style={styles.breathChar}>息</Text>
        </Pressable>

        <Text style={styles.breathHint}>五分钟 · 五行呼吸</Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.bg,
    paddingHorizontal: Space.lg,
  },

  section: {
    paddingTop: Space.xl,
  },
  sectionTitle: {
    ...Type.subtitle,
    color: Colors.ink,
    fontWeight: '400',
  },
  sectionSub: {
    ...Type.caption,
    color: Colors.inkTertiary,
    marginTop: Space.xs,
    marginBottom: Space.lg,
  },

  // 音景列表 — 纯文字，不用卡片
  soundList: {
    gap: Space.xs,
  },
  soundItem: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: Space.base,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: Colors.inkHint + '40',
  },
  soundName: {
    ...Type.body,
    color: Colors.inkSecondary,
  },
  soundNameActive: {
    color: Colors.brand,
    fontWeight: '600',
  },
  soundSeason: {
    ...Type.label,
    color: Colors.inkHint,
  },
  soundSeasonActive: {
    color: Colors.brandMuted,
  },

  // 呼吸引导 — 一个字
  breathSection: {
    alignItems: 'center',
    paddingTop: Space['3xl'],
  },
  breathCenter: {
    width: 120,
    height: 120,
    borderRadius: 60,
    borderWidth: 1,
    borderColor: Colors.inkHint + '60',
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: Space.xl,
  },
  breathChar: {
    fontSize: 32,
    color: Colors.brand,
    fontWeight: '300',
    letterSpacing: 0,
  },
  breathHint: {
    ...Type.caption,
    color: Colors.inkTertiary,
    marginTop: Space.base,
  },
});
