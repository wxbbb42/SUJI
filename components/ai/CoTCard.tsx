/**
 * 推演过程卡片（streaming 时自动展开 + 列出工具调用，结束后默认折叠）
 */
import React, { useState } from 'react';
import { View, Text, Pressable, StyleSheet } from 'react-native';
import { Colors, Space, Radius, Type, Shadow } from '@/lib/design/tokens';

export interface ToolCallTrace {
  name: string;
  argSummary: string;     // 简短的参数摘要，如 'domain=子女'
  resultSummary?: string; // 简短的结果摘要
  narration?: string;     // CoT 卡里渲染的友好叙事（古风幽默）
}

type Props = {
  toolCalls: ToolCallTrace[];
  thinkerText?: string;     // Call 1 完成后的文本（可选）
  isStreaming: boolean;
};

export function CoTCard({ toolCalls, thinkerText, isStreaming }: Props) {
  const [expanded, setExpanded] = useState(isStreaming);

  // streaming 时强制展开；结束后保留用户最后状态（默认收起）
  const open = isStreaming || expanded;

  if (toolCalls.length === 0 && !thinkerText) return null;

  return (
    <Pressable
      onPress={() => !isStreaming && setExpanded(v => !v)}
      style={[styles.card, Shadow.sm]}
    >
      <View style={styles.headerRow}>
        <Text style={styles.headerLabel}>
          {isStreaming ? '推演中…' : `${toolCalls.length} 步推演`}
        </Text>
        {!isStreaming && (
          <Text style={styles.toggle}>{open ? '⌃' : '⌄'}</Text>
        )}
      </View>

      {open && (
        <View style={styles.body}>
          {toolCalls.map((c, i) => (
            <Text key={i} style={styles.line}>
              {c.narration ?? `${c.name}(${c.argSummary})${c.resultSummary ? ` → ${c.resultSummary}` : ''}`}
            </Text>
          ))}
          {thinkerText && (
            <Text style={styles.summary} numberOfLines={3}>
              {extractConclusion(thinkerText)}
            </Text>
          )}
        </View>
      )}
    </Pressable>
  );
}

function extractConclusion(text: string): string {
  // 提取"综合"或最后一段
  const m = text.match(/综合[：:](.+)$/m);
  if (m) return `综合：${m[1].trim()}`;
  const lines = text.split('\n').filter(Boolean);
  return lines[lines.length - 1] ?? text;
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: Colors.surface,
    borderRadius: Radius.md,
    padding: Space.base,
    marginVertical: Space.xs,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: Colors.border,
  },
  headerRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  headerLabel: {
    ...Type.caption,
    color: Colors.inkSecondary,
    fontWeight: '500',
    letterSpacing: 1,
    flex: 1,
  },
  toggle: { color: Colors.inkTertiary, fontSize: 14 },
  body: {
    marginTop: Space.sm,
    gap: 4,
  },
  line: {
    ...Type.caption,
    color: Colors.inkSecondary,
    lineHeight: 20,
  },
  summary: {
    ...Type.bodySmall,
    color: Colors.ink,
    fontStyle: 'italic',
    marginTop: Space.xs,
  },
});
