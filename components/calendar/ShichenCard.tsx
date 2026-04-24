/**
 * 时辰单卡
 */
import React from 'react';
import { View, Text, Pressable, StyleSheet } from 'react-native';
import { Colors, Space, Radius, Type, Shadow } from '@/lib/design/tokens';
import type { ShichenEntry, ShichenVibe, EnergyLevel } from '@/lib/calendar/shichen';

type Props = {
  entry: ShichenEntry;
  vibe: ShichenVibe;
  active: boolean;
  onPress: () => void;
};

export function ShichenCard({ entry, vibe, active, onPress }: Props) {
  return (
    <Pressable
      onPress={onPress}
      style={[styles.card, active && styles.cardActive, Shadow.sm]}
    >
      {active && <View style={styles.marker} />}
      <Text style={[styles.zhi, active && styles.zhiActive]}>{entry.zhi}</Text>
      <Text style={styles.hours}>{entry.hours}</Text>

      <View style={styles.divider} />

      <Text style={[styles.image, active && styles.imageActive]}>{entry.image}</Text>
      <Text style={styles.poem}>{entry.poem}</Text>

      <View style={styles.divider} />

      <View style={styles.levelRow}>
        <View style={[styles.levelDot, { backgroundColor: levelColor(vibe.level) }]} />
        <Text style={styles.levelText}>{vibe.level}</Text>
      </View>

      <Text style={styles.suitable} numberOfLines={1}>宜 · {vibe.suitable}</Text>
    </Pressable>
  );
}

function levelColor(level: EnergyLevel): string {
  if (level === '旺') return Colors.celadon;
  if (level === '弱') return Colors.vermilion;
  return Colors.inkHint;
}

const styles = StyleSheet.create({
  card: {
    width: 110,
    height: 150,
    backgroundColor: Colors.surface,
    borderRadius: Radius.lg,
    padding: Space.sm,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: Space.sm,
  },
  cardActive: {
    width: 130,
    height: 170,
    backgroundColor: Colors.brandBg,
  },
  marker: {
    position: 'absolute',
    top: 4,
    alignSelf: 'center',
    width: 0, height: 0,
    borderLeftWidth: 4, borderRightWidth: 4, borderBottomWidth: 5,
    borderLeftColor: 'transparent', borderRightColor: 'transparent',
    borderBottomColor: Colors.vermilion,
  },
  zhi: {
    fontFamily: 'Georgia', fontSize: 36,
    color: Colors.ink, fontWeight: '300', lineHeight: 40,
  },
  zhiActive: { fontSize: 40 },
  hours: { ...Type.caption, color: Colors.inkTertiary, marginTop: 2 },
  divider: {
    width: '60%', height: StyleSheet.hairlineWidth,
    backgroundColor: Colors.border, marginVertical: Space.xs,
  },
  image: { fontSize: 18, color: Colors.ink, fontWeight: '500' },
  imageActive: { fontSize: 20 },
  poem: { ...Type.bodySmall, color: Colors.inkSecondary, marginTop: 2 },
  levelRow: { flexDirection: 'row', alignItems: 'center', gap: 4 },
  levelDot: { width: 6, height: 6, borderRadius: 3 },
  levelText: { ...Type.caption, color: Colors.inkTertiary },
  suitable: {
    ...Type.caption, color: Colors.vermilion, marginTop: 4, fontWeight: '500',
  },
});
