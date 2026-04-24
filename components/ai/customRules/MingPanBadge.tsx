/**
 * 命盘关键词行内徽章
 */
import React from 'react';
import { Text, StyleSheet } from 'react-native';
import { Colors, Type, Radius } from '@/lib/design/tokens';

type Props = { children: React.ReactNode };

export function MingPanBadge({ children }: Props) {
  return <Text style={styles.badge}>{children}</Text>;
}

const styles = StyleSheet.create({
  badge: {
    ...Type.bodySmall,
    color: Colors.vermilion,
    backgroundColor: Colors.brandBg,
    paddingHorizontal: 6,
    paddingVertical: 1,
    borderRadius: Radius.xs,
    overflow: 'hidden',
  },
});
