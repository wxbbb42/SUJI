/**
 * 问道页面
 * 
 * AI 对话界面
 * 设计：克制的气泡、大面积留白、方形输入框
 */

import { StyleSheet, View, Text, TextInput, ScrollView, Pressable } from 'react-native';
import { useState } from 'react';
import { Colors, Space, Type } from '@/lib/design/tokens';

export default function InsightScreen() {
  const [message, setMessage] = useState('');

  return (
    <View style={styles.container}>
      <ScrollView
        style={styles.chatArea}
        contentContainerStyle={styles.chatContent}
      >
        {/* AI 欢迎 */}
        <View style={styles.aiBubble}>
          <Text style={styles.aiLabel}>岁吉</Text>
          <Text style={styles.aiText}>
            今日巳火当令，适合内观与梳理。
          </Text>
          <Text style={styles.aiText}>
            有什么想聊的？可以跟我说说你现在的心情，或者问问关于你自己的事。
          </Text>
        </View>
      </ScrollView>

      {/* 输入区 */}
      <View style={styles.inputArea}>
        <TextInput
          style={styles.input}
          placeholder="说说你的心情…"
          placeholderTextColor={Colors.inkHint}
          value={message}
          onChangeText={setMessage}
          multiline
        />
        <Pressable
          style={[styles.sendBtn, !message.trim() && styles.sendBtnDisabled]}
          disabled={!message.trim()}
        >
          <Text style={[styles.sendText, !message.trim() && styles.sendTextDisabled]}>
            发送
          </Text>
        </Pressable>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.bg,
  },
  chatArea: {
    flex: 1,
  },
  chatContent: {
    padding: Space.lg,
    paddingTop: Space.xl,
    paddingBottom: Space['2xl'],
  },

  // AI 气泡 — 无边框无阴影，靠背景色区分
  aiBubble: {
    backgroundColor: Colors.surface,
    borderRadius: 4,
    padding: Space.lg,
    maxWidth: '88%',
  },
  aiLabel: {
    ...Type.label,
    color: Colors.brand,
    fontWeight: '600',
    marginBottom: Space.sm,
    textTransform: 'uppercase',
  },
  aiText: {
    ...Type.body,
    color: Colors.ink,
    marginBottom: Space.sm,
  },

  // 输入区 — 方形，克制
  inputArea: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    padding: Space.base,
    paddingBottom: Space.xl,
    backgroundColor: Colors.surface,
  },
  input: {
    flex: 1,
    backgroundColor: Colors.bg,
    borderRadius: 2,
    paddingHorizontal: Space.base,
    paddingVertical: Space.md,
    ...Type.body,
    color: Colors.ink,
    maxHeight: 100,
  },
  sendBtn: {
    marginLeft: Space.md,
    paddingHorizontal: Space.base,
    paddingVertical: Space.md,
  },
  sendBtnDisabled: {
    opacity: 0.3,
  },
  sendText: {
    ...Type.body,
    color: Colors.brand,
    fontWeight: '600',
  },
  sendTextDisabled: {
    color: Colors.inkHint,
  },
});
