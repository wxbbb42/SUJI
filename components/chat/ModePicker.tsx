/**
 * 模式选择 BottomSheet
 *
 * 3 种模式：随心问（默认） / 起一卦 / 看命盘
 * 选中态用左侧朱砂细竖线表示（无 emoji）
 */
import React from 'react';
import { Modal, View, Text, Pressable, StyleSheet } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Colors, Space, Radius, Type, Shadow } from '@/lib/design/tokens';

export type ChatMode = 'auto' | 'liuyao' | 'mingli';

type Props = {
  visible: boolean;
  current: ChatMode;
  onSelect: (mode: ChatMode) => void;
  onClose: () => void;
};

const MODES: Array<{ key: ChatMode; title: string; subtitle: string }> = [
  { key: 'auto',   title: '随心问', subtitle: 'AI 自动判断该用什么方式回答' },
  { key: 'liuyao', title: '起一卦', subtitle: '带具体问题让我替你卜一卦' },
  { key: 'mingli', title: '看命盘', subtitle: '根据你的八字 / 紫微解读' },
];

export function ModePicker({ visible, current, onSelect, onClose }: Props) {
  const insets = useSafeAreaInsets();

  return (
    <Modal visible={visible} transparent animationType="slide" onRequestClose={onClose}>
      <Pressable style={styles.backdrop} onPress={onClose} />
      <View style={[styles.sheet, { paddingBottom: insets.bottom + Space.lg }, Shadow.md]}>
        <View style={styles.handle} />
        <Text style={styles.title}>切换模式</Text>

        {MODES.map(m => {
          const selected = m.key === current;
          return (
            <Pressable
              key={m.key}
              style={styles.row}
              onPress={() => { onSelect(m.key); onClose(); }}
            >
              <View style={[styles.indicator, selected && styles.indicatorActive]} />
              <View style={styles.rowText}>
                <Text style={[styles.rowTitle, selected && styles.rowTitleActive]}>
                  {m.title}
                </Text>
                <Text style={styles.rowSubtitle}>{m.subtitle}</Text>
              </View>
            </Pressable>
          );
        })}
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  backdrop: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(0,0,0,0.25)',
  },
  sheet: {
    position: 'absolute',
    bottom: 0, left: 0, right: 0,
    backgroundColor: Colors.surface,
    borderTopLeftRadius: Radius.xl,
    borderTopRightRadius: Radius.xl,
    paddingTop: Space.sm,
  },
  handle: {
    alignSelf: 'center',
    width: 36, height: 4,
    borderRadius: 2,
    backgroundColor: Colors.border,
    marginBottom: Space.md,
  },
  title: {
    ...Type.label,
    color: Colors.inkTertiary,
    letterSpacing: 2,
    paddingHorizontal: Space.xl,
    marginBottom: Space.md,
  },
  row: {
    flexDirection: 'row',
    paddingVertical: Space.md,
    paddingHorizontal: Space.xl,
    alignItems: 'center',
    gap: Space.md,
  },
  indicator: {
    width: 2,
    alignSelf: 'stretch',
    backgroundColor: 'transparent',
  },
  indicatorActive: {
    backgroundColor: Colors.vermilion,
  },
  rowText: {
    flex: 1,
    gap: 2,
  },
  rowTitle: {
    ...Type.body,
    color: Colors.ink,
    fontWeight: '500',
  },
  rowTitleActive: {
    color: Colors.vermilion,
    fontWeight: '600',
  },
  rowSubtitle: {
    ...Type.caption,
    color: Colors.inkSecondary,
  },
});
