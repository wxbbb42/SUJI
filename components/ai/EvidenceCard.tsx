/**
 * 推演依据卡片（4 行预览 + "查看完整推演" → BottomSheet）
 */
import React from 'react';
import { View, Text, Pressable, StyleSheet } from 'react-native';
import { Colors, Space, Radius, Type, Shadow } from '@/lib/design/tokens';

const PREVIEW_LINES = 4;

type Props = {
  evidence: string[];
  onTapFull: () => void;
};

export function EvidenceCard({ evidence, onTapFull }: Props) {
  if (evidence.length === 0) return null;
  const visible = evidence.slice(0, PREVIEW_LINES);
  const hasMore = evidence.length > PREVIEW_LINES;

  return (
    <Pressable onPress={onTapFull} style={[styles.card, Shadow.sm]}>
      <View style={styles.headerRow}>
        <Text style={styles.headerIcon}>🔍</Text>
        <Text style={styles.headerLabel}>推演依据</Text>
      </View>
      {visible.map((line, i) => (
        <Text key={i} style={styles.line} numberOfLines={1}>{line}</Text>
      ))}
      <View style={styles.footer}>
        <Text style={styles.footerText}>
          {hasMore ? '⌄ 查看完整推演' : '⌄ 展开完整推演'}
        </Text>
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: Colors.brandBg,
    borderRadius: Radius.md,
    padding: Space.base,
    marginVertical: Space.sm,
    gap: 4,
  },
  headerRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    marginBottom: Space.xs,
  },
  headerIcon: { fontSize: 14 },
  headerLabel: {
    ...Type.label,
    color: Colors.vermilion,
    fontWeight: '600',
    letterSpacing: 1,
  },
  line: {
    ...Type.bodySmall,
    color: Colors.ink,
    lineHeight: 22,
  },
  footer: {
    marginTop: Space.xs,
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: Colors.border,
    paddingTop: Space.xs,
    alignItems: 'center',
  },
  footerText: {
    ...Type.caption,
    color: Colors.vermilion,
  },
});
