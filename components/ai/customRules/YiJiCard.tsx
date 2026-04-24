/**
 * 宜 / 忌 双栏卡
 */
import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { Colors, Space, Radius, Type, Shadow } from '@/lib/design/tokens';

type Props = { yi: string[]; ji: string[] };

export function YiJiCard({ yi, ji }: Props) {
  return (
    <View style={[styles.card, Shadow.sm]}>
      <Column label="宜" items={yi} tone="good" />
      <View style={styles.divider} />
      <Column label="忌" items={ji} tone="bad" />
    </View>
  );
}

function Column({
  label, items, tone,
}: { label: string; items: string[]; tone: 'good' | 'bad' }) {
  const color = tone === 'good' ? Colors.celadon : Colors.vermilion;
  return (
    <View style={styles.col}>
      <Text style={[styles.label, { color }]}>{label}</Text>
      {items.map((it, i) => (
        <Text key={i} style={styles.item}>{it}</Text>
      ))}
    </View>
  );
}

/** 把 "静心、写字" / "静心，写字" 分词成 ["静心", "写字"] */
export function splitYiji(raw: string): string[] {
  return raw
    .split(/[、,，]/)
    .map(s => s.trim())
    .filter(Boolean);
}

const styles = StyleSheet.create({
  card: {
    flexDirection: 'row',
    backgroundColor: Colors.surface,
    borderRadius: Radius.lg,
    marginVertical: Space.md,
    overflow: 'hidden',
  },
  col: {
    flex: 1,
    padding: Space.base,
    gap: Space.xs,
    alignItems: 'center',
  },
  divider: {
    width: StyleSheet.hairlineWidth,
    backgroundColor: Colors.border,
  },
  label: {
    ...Type.label,
    fontWeight: '600',
    letterSpacing: 2,
    marginBottom: Space.xs,
  },
  item: {
    ...Type.body,
    color: Colors.ink,
  },
});
