/**
 * 时辰详情半屏 Modal
 */
import React from 'react';
import { Modal, View, Text, Pressable, StyleSheet, ScrollView } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Colors, Space, Radius, Type, Shadow } from '@/lib/design/tokens';
import type { ShichenEntry, ShichenVibe, MingPanSummary } from '@/lib/calendar/shichen';

type Props = {
  visible: boolean;
  entry: ShichenEntry | null;
  vibe: ShichenVibe | null;
  mingPan: MingPanSummary | null;
  onClose: () => void;
};

export function ShichenDetailSheet({ visible, entry, vibe, mingPan, onClose }: Props) {
  const insets = useSafeAreaInsets();
  if (!entry || !vibe) return null;

  return (
    <Modal
      visible={visible}
      animationType="slide"
      transparent
      onRequestClose={onClose}
    >
      <Pressable style={styles.backdrop} onPress={onClose} />
      <View style={[styles.sheet, { paddingBottom: insets.bottom + Space.lg }, Shadow.md]}>
        <View style={styles.handle} />
        <ScrollView contentContainerStyle={styles.content}>
          <Text style={styles.title}>{entry.zhi}时 · {entry.hours}</Text>
          <Text style={styles.image}>{entry.image}</Text>
          <Text style={styles.poem}>{entry.poem}</Text>

          <View style={styles.section}>
            <Text style={styles.body}>{detailDescription(entry, vibe)}</Text>
          </View>

          {mingPan && (
            <View style={styles.section}>
              <Text style={styles.sectionLabel}>对你来说</Text>
              <Text style={styles.body}>{personalizedBlurb(entry, mingPan)}</Text>
            </View>
          )}

          <Pressable style={styles.closeBtn} onPress={onClose}>
            <Text style={styles.closeText}>关闭</Text>
          </Pressable>
        </ScrollView>
      </View>
    </Modal>
  );
}

function detailDescription(entry: ShichenEntry, vibe: ShichenVibe): string {
  const levelPhrase =
    vibe.level === '旺' ? '气机充盈' :
    vibe.level === '弱' ? '气机稍滞' :
    '气机平和';
  return `${entry.zhi}时属${entry.generalWuXing}，此时${entry.poem}，${levelPhrase}。此刻宜${vibe.suitable}。`;
}

function personalizedBlurb(entry: ShichenEntry, mp: MingPanSummary): string {
  const wx = entry.generalWuXing;
  if (wx === mp.yongShen) return `此时的 ${wx} 正合你的用神，是你一天中能量最顺的时段。`;
  if (wx === mp.xiShen) return `此时的 ${wx} 与你的喜神相通，适合推进与人交流的事。`;
  if (wx === mp.jiShen) return `此时的 ${wx} 与你的忌神相冲，不必强求进取，收一收更合适。`;
  return `此时的 ${wx} 对你既非助益也非阻碍，平稳行事即可。`;
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
    maxHeight: '70%',
  },
  handle: {
    alignSelf: 'center',
    width: 36, height: 4,
    borderRadius: 2,
    backgroundColor: Colors.border,
    marginTop: Space.sm,
  },
  content: {
    padding: Space.xl,
    gap: Space.md,
  },
  title: {
    ...Type.title, color: Colors.ink,
  },
  image: {
    fontSize: 24, color: Colors.ink, fontWeight: '500',
  },
  poem: {
    ...Type.body, color: Colors.inkSecondary, fontStyle: 'italic',
  },
  section: {
    gap: Space.xs,
    marginTop: Space.sm,
  },
  sectionLabel: {
    ...Type.label, color: Colors.vermilion, letterSpacing: 2,
  },
  body: {
    ...Type.body, color: Colors.ink, lineHeight: 26,
  },
  closeBtn: {
    marginTop: Space.xl,
    alignSelf: 'center',
    paddingVertical: Space.md,
    paddingHorizontal: Space['2xl'],
    borderRadius: Radius.lg,
    backgroundColor: Colors.bgSecondary,
  },
  closeText: {
    ...Type.body, color: Colors.ink,
  },
});
