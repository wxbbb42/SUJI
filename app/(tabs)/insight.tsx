/**
 * 问道页面
 *
 * AI 对话界面 — BYOM（Bring Your Own Model）
 */

import {
  StyleSheet, View, Text, TextInput, ScrollView, Pressable,
  KeyboardAvoidingView, Platform, ActivityIndicator,
} from 'react-native';
import { useState, useRef, useCallback } from 'react';
import { useRouter } from 'expo-router';
import { Colors, Space, Type } from '@/lib/design/tokens';
import { useUserStore } from '@/lib/store/userStore';
import { getChatConfig, sendChat } from '@/lib/ai/chat';
import type { ChatMessage } from '@/lib/ai';

export default function InsightScreen() {
  const router = useRouter();
  const store = useUserStore();
  const scrollRef = useRef<ScrollView>(null);

  const [message, setMessage] = useState('');
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [streamingText, setStreamingText] = useState('');
  const [loading, setLoading] = useState(false);

  const config = getChatConfig(store);
  const hasApiKey = !!config;

  const handleSend = useCallback(async () => {
    const text = message.trim();
    if (!text || !config || loading) return;

    const userMsg: ChatMessage = { role: 'user', content: text, timestamp: Date.now() };
    const newMessages = [...messages, userMsg];
    setMessages(newMessages);
    setMessage('');
    setLoading(true);
    setStreamingText('');

    try {
      const fullText = await sendChat(
        newMessages,
        config,
        store.mingPanCache,
        (partial) => {
          setStreamingText(partial);
          setTimeout(() => scrollRef.current?.scrollToEnd({ animated: true }), 50);
        },
      );

      const assistantMsg: ChatMessage = {
        role: 'assistant',
        content: fullText,
        timestamp: Date.now(),
      };
      setMessages(prev => [...prev, assistantMsg]);
      setStreamingText('');
    } catch (err: any) {
      const errorMsg: ChatMessage = {
        role: 'assistant',
        content: `抱歉，请求失败：${err.message || '未知错误'}。请检查设置中的 API 配置。`,
        timestamp: Date.now(),
      };
      setMessages(prev => [...prev, errorMsg]);
      setStreamingText('');
    } finally {
      setLoading(false);
    }
  }, [message, messages, config, loading, store.mingPanCache]);

  // ── 未配置 API ──
  if (!hasApiKey) {
    return (
      <View style={styles.container}>
        <View style={styles.emptyCenter}>
          <Text style={styles.emptyTitle}>问道</Text>
          <Text style={styles.emptySub}>
            配置你的 AI 模型，开启智慧对话
          </Text>
          <Text style={styles.emptyDetail}>
            支持 OpenAI · DeepSeek · Anthropic{'\n'}以及任何 OpenAI 兼容 API
          </Text>
          <Pressable
            style={styles.setupBtn}
            onPress={() => router.push('/settings')}
          >
            <Text style={styles.setupBtnText}>前往设置</Text>
          </Pressable>
        </View>
      </View>
    );
  }

  // ── 对话界面 ──
  return (
    <KeyboardAvoidingView
      style={styles.container}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      keyboardVerticalOffset={90}
    >
      <ScrollView
        ref={scrollRef}
        style={styles.chatArea}
        contentContainerStyle={styles.chatContent}
        onContentSizeChange={() => scrollRef.current?.scrollToEnd({ animated: true })}
      >
        {/* 欢迎消息 */}
        {messages.length === 0 && !streamingText && (
          <View style={styles.aiBubble}>
            <Text style={styles.aiLabel}>岁吉</Text>
            <Text style={styles.aiText}>
              {store.mingPanCache
                ? '你的命盘已就绪。有什么想聊的？可以跟我说说你现在的心情，或者问问关于你自己的事。'
                : '有什么想聊的？输入生辰后，我可以结合你的命盘给出更个性化的建议。'}
            </Text>
          </View>
        )}

        {/* 对话历史 */}
        {messages.map((msg, i) => (
          <View
            key={i}
            style={msg.role === 'user' ? styles.userBubble : styles.aiBubble}
          >
            {msg.role === 'assistant' && (
              <Text style={styles.aiLabel}>岁吉</Text>
            )}
            <Text style={msg.role === 'user' ? styles.userText : styles.aiText}>
              {msg.content}
            </Text>
          </View>
        ))}

        {/* 流式输出中 */}
        {streamingText ? (
          <View style={styles.aiBubble}>
            <Text style={styles.aiLabel}>岁吉</Text>
            <Text style={styles.aiText}>{streamingText}</Text>
          </View>
        ) : null}

        {/* Loading */}
        {loading && !streamingText && (
          <View style={styles.loadingRow}>
            <ActivityIndicator size="small" color={Colors.inkHint} />
            <Text style={styles.loadingText}>思考中…</Text>
          </View>
        )}
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
          editable={!loading}
          onSubmitEditing={handleSend}
          blurOnSubmit={false}
        />
        <Pressable
          style={[styles.sendBtn, (!message.trim() || loading) && styles.sendBtnDisabled]}
          disabled={!message.trim() || loading}
          onPress={handleSend}
        >
          <Text style={[
            styles.sendText,
            (!message.trim() || loading) && styles.sendTextDisabled,
          ]}>
            发送
          </Text>
        </Pressable>
      </View>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.bg,
  },

  // 空状态
  emptyCenter: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: Space.xl,
  },
  emptyTitle: {
    ...Type.title,
    color: Colors.ink,
    fontWeight: '300',
    marginBottom: Space.md,
  },
  emptySub: {
    ...Type.body,
    color: Colors.inkSecondary,
    textAlign: 'center',
    marginBottom: Space.sm,
  },
  emptyDetail: {
    ...Type.caption,
    color: Colors.inkHint,
    textAlign: 'center',
    lineHeight: 20,
    marginBottom: Space.xl,
  },
  setupBtn: {
    paddingVertical: Space.md,
    paddingHorizontal: Space.xl,
    borderWidth: 1,
    borderColor: Colors.brand,
    borderRadius: 2,
  },
  setupBtnText: {
    ...Type.body,
    color: Colors.brand,
    fontWeight: '500',
  },

  // 对话区
  chatArea: {
    flex: 1,
  },
  chatContent: {
    padding: Space.lg,
    paddingTop: Space.xl,
    paddingBottom: Space['2xl'],
    gap: Space.lg,
  },

  // AI 气泡
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
    lineHeight: 24,
  },

  // 用户气泡
  userBubble: {
    alignSelf: 'flex-end',
    maxWidth: '80%',
    padding: Space.lg,
  },
  userText: {
    ...Type.body,
    color: Colors.inkSecondary,
    textAlign: 'right',
  },

  // Loading
  loadingRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Space.sm,
    paddingVertical: Space.sm,
  },
  loadingText: {
    ...Type.caption,
    color: Colors.inkHint,
  },

  // 输入区
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
