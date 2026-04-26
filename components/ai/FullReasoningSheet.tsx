/**
 * 完整推演 BottomSheet
 *
 * 内容：evidence 完整展开 + Call 1 推演原文 + tool 调用日志
 */
import React from 'react';
import { Modal, View, Text, Pressable, ScrollView, StyleSheet } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Colors, Space, Radius, Type, Shadow } from '@/lib/design/tokens';
import type { ToolCallTrace } from './CoTCard';
import { FullChart9 } from '@/components/qimen/FullChart9';
import type { QimenChart } from '@/lib/qimen/types';

type Props = {
  visible: boolean;
  evidence: string[];
  thinkerText: string;
  toolCalls: ToolCallTrace[];
  qimenChart?: QimenChart | null;
  onClose: () => void;
};

export function FullReasoningSheet({
  visible, evidence, thinkerText, toolCalls, qimenChart, onClose,
}: Props) {
  const insets = useSafeAreaInsets();

  return (
    <Modal
      visible={visible}
      transparent
      animationType="slide"
      onRequestClose={onClose}
    >
      <Pressable style={styles.backdrop} onPress={onClose} />
      <View
        style={[
          styles.sheet,
          { paddingBottom: insets.bottom + Space.lg },
          Shadow.md,
        ]}
      >
        <View style={styles.handle} />
        <ScrollView contentContainerStyle={styles.content}>
          <Text style={styles.title}>完整推演</Text>

          {evidence.length > 0 && (
            <Section label="你的命盘要点">
              {evidence.map((line, i) => (
                <Text key={i} style={styles.line}>{line}</Text>
              ))}
            </Section>
          )}

          {qimenChart && (
            <Section label="完整 9 宫盘">
              <FullChart9 chart={qimenChart} />
            </Section>
          )}

          {qimenChart && qimenChart.geJu.length > 0 && (
            <Section label="格局">
              {qimenChart.geJu.map((g, i) => (
                <Text key={i} style={styles.line}>
                  · {g.name}（{g.type}）—— {g.description}
                </Text>
              ))}
            </Section>
          )}

          {thinkerText && (
            <Section label="推演过程">
              <Text style={styles.thinker}>{thinkerText}</Text>
            </Section>
          )}

          {toolCalls.length > 0 && (
            <Section label="使用的数据">
              {toolCalls.map((c, i) => (
                <Text key={i} style={styles.line}>
                  {c.name}({c.argSummary}){c.resultSummary ? ` → ${c.resultSummary}` : ''}
                </Text>
              ))}
            </Section>
          )}

          <Pressable style={styles.closeBtn} onPress={onClose}>
            <Text style={styles.closeText}>关闭</Text>
          </Pressable>
        </ScrollView>
      </View>
    </Modal>
  );
}

function Section({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <View style={styles.section}>
      <Text style={styles.sectionLabel}>{label}</Text>
      <View style={styles.divider} />
      <View style={styles.sectionBody}>{children}</View>
    </View>
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
    maxHeight: '85%',
  },
  handle: {
    alignSelf: 'center',
    width: 36, height: 4,
    borderRadius: 2,
    backgroundColor: Colors.border,
    marginTop: Space.sm,
  },
  content: { padding: Space.xl, gap: Space.md },
  title: { ...Type.title, color: Colors.ink },
  section: { gap: Space.xs, marginTop: Space.md },
  sectionLabel: {
    ...Type.label, color: Colors.vermilion, letterSpacing: 2,
  },
  divider: {
    height: StyleSheet.hairlineWidth,
    backgroundColor: Colors.border,
    marginVertical: Space.xs,
  },
  sectionBody: { gap: Space.xs },
  line: { ...Type.bodySmall, color: Colors.ink, lineHeight: 22 },
  thinker: { ...Type.body, color: Colors.ink, lineHeight: 26 },
  closeBtn: {
    marginTop: Space.xl,
    alignSelf: 'center',
    paddingVertical: Space.md,
    paddingHorizontal: Space['2xl'],
    borderRadius: Radius.lg,
    backgroundColor: Colors.bgSecondary,
  },
  closeText: { ...Type.body, color: Colors.ink },
});
