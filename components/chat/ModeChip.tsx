/**
 * 当前模式 chip（输入框底部显示）
 *
 * 当 mode === 'auto'（默认随心问）时返回 null，不渲染
 * 否则朱砂背景 + 白字 + ✕ 可清除
 */
import React from 'react';
import { View, Text, Pressable, StyleSheet } from 'react-native';
import { Colors, Type } from '@/lib/design/tokens';
import type { ChatMode } from './ModePicker';

const MODE_LABEL: Record<ChatMode, string> = {
  auto: '',
  liuyao: '起一卦',
  mingli: '看命盘',
};

type Props = {
  mode: ChatMode;
  onClear: () => void;
};

export function ModeChip({ mode, onClear }: Props) {
  if (mode === 'auto') return null;
  const label = MODE_LABEL[mode];

  return (
    <View style={styles.chip}>
      <Text style={styles.label}>{label}</Text>
      <Pressable onPress={onClear} hitSlop={8}>
        <Text style={styles.x}>✕</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  chip: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 12,
    backgroundColor: Colors.vermilion,
  },
  label: {
    ...Type.caption,
    color: '#FFFFFF',
    fontWeight: '500',
  },
  x: {
    color: '#FFFFFF',
    fontSize: 14,
    lineHeight: 16,
  },
});
