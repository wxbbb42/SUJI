/**
 * 古文引用：升级版 blockquote，带可选落款
 */
import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { Colors, Space, Radius, Type, Shadow } from '@/lib/design/tokens';

/** 识别尾行形如 "—— xxx" 或 "——xxx" 的落款 */
export function parseAttribution(raw: string): { body: string; attribution: string | null } {
  const lines = raw.trim().split('\n');
  const last = lines[lines.length - 1]?.trim() ?? '';
  const m = last.match(/^——\s*(.+)$/);
  if (m) {
    return {
      body: lines.slice(0, -1).join('\n').trim(),
      attribution: m[1].trim(),
    };
  }
  return { body: raw.trim(), attribution: null };
}

type Props = { rawText: string };

export function ClassicalQuote({ rawText }: Props) {
  const { body, attribution } = parseAttribution(rawText);
  return (
    <View style={[styles.card, Shadow.sm]}>
      <Text style={styles.body}>{body}</Text>
      {attribution && (
        <>
          <View style={styles.divider} />
          <Text style={styles.attribution}>—— {attribution}</Text>
        </>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: Colors.brandBg,
    borderRadius: Radius.md,
    padding: Space.lg,
    marginVertical: Space.md,
  },
  body: {
    fontFamily: 'Georgia',
    fontSize: 16,
    lineHeight: 28,
    color: Colors.ink,
  },
  divider: {
    alignSelf: 'flex-end',
    width: 40,
    height: StyleSheet.hairlineWidth,
    backgroundColor: Colors.vermilion,
    opacity: 0.5,
    marginTop: Space.sm,
    marginBottom: 4,
  },
  attribution: {
    ...Type.caption,
    color: Colors.inkTertiary,
    textAlign: 'right',
  },
});
