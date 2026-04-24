/**
 * 问道页面 — AI 对话
 *
 * Neo-Tactile Warmth 设计
 * 气泡有圆角和微妙阴影，输入区有触感
 */

import React, { useState, useRef, useCallback } from 'react';
import {
  StyleSheet, View, Text, TextInput, ScrollView, Pressable,
  KeyboardAvoidingView, Platform, ActivityIndicator,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import Animated, {
  useSharedValue, useAnimatedStyle, withSpring,
} from 'react-native-reanimated';
import { useRouter } from 'expo-router';
import { Colors, Space, Radius, Type, Shadow, Motion, Size } from '@/lib/design/tokens';
import { useUserStore } from '@/lib/store/userStore';
import { useChatStore } from '@/lib/store/chatStore';
import { getChatConfig, sendChat } from '@/lib/ai/chat';
import type { ChatMessage } from '@/lib/ai';
import { StreamCursor } from '@/components/ai/StreamCursor';
import { RichContent } from '@/components/ai/RichContent';

const AnimatedPressable = Animated.createAnimatedComponent(Pressable);

export default function InsightScreen() {
  const router = useRouter();
  const insets = useSafeAreaInsets();
  const store = useUserStore();
  const scrollRef = useRef<ScrollView>(null);
  const { messages, addMessage, clearMessages } = useChatStore();

  const [message, setMessage] = useState('');
  const [streamingText, setStreamingText] = useState('');
  const [loading, setLoading] = useState(false);
  const abortRef = useRef<AbortController | null>(null);

  const config = getChatConfig(store);

  // 发送
  const handleSend = useCallback(async () => {
    const text = message.trim();
    if (!text || !config || loading) return;

    const userMsg: ChatMessage = { role: 'user', content: text, timestamp: Date.now() };
    const newMessages = [...messages, userMsg];
    addMessage(userMsg);
    setMessage('');
    setLoading(true);
    setStreamingText('');
    const abortController = new AbortController();
    abortRef.current = abortController;

    try {
      const fullText = await sendChat(
        newMessages, config, store.mingPanCache,
        (partial) => {
          setStreamingText(partial);
          setTimeout(() => scrollRef.current?.scrollToEnd({ animated: true }), 50);
        },
        abortController.signal,
      );
      const assistantMsg: ChatMessage = { role: 'assistant', content: fullText, timestamp: Date.now() };
      addMessage(assistantMsg);
      setStreamingText('');
    } catch (err: any) {
      const errorMsg: ChatMessage = {
        role: 'assistant',
        content: `请求失败：${err.message || '未知错误'}`,
        timestamp: Date.now(),
      };
      addMessage(errorMsg);
      setStreamingText('');
    } finally {
      setLoading(false);
      abortRef.current = null;
    }
  }, [message, messages, config, loading, store.mingPanCache, addMessage]);

  const handleStop = useCallback(() => {
    abortRef.current?.abort();
  }, []);

  // 未配置
  if (!config) {
    return (
      <View style={[styles.container, { paddingTop: insets.top }]}>
        <View style={styles.emptyCenter}>
          <View style={styles.emptyIcon}>
            <Text style={styles.emptyIconText}>问</Text>
          </View>
          <Text style={styles.emptyTitle}>问道</Text>
          <Text style={styles.emptySub}>
            配置你的 AI 模型{'\n'}开启智慧对话
          </Text>
          <Text style={styles.emptyProviders}>
            支持 OpenAI · DeepSeek · Anthropic
          </Text>
          <Pressable
            style={[styles.setupBtn, Shadow.sm]}
            onPress={() => router.push('/settings')}
          >
            <Text style={styles.setupBtnText}>前往设置</Text>
          </Pressable>
        </View>
      </View>
    );
  }

  return (
    <KeyboardAvoidingView
      style={[styles.container, { paddingTop: insets.top }]}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      keyboardVerticalOffset={insets.top + Size.headerHeight}
    >
      <ScrollView
        ref={scrollRef}
        style={styles.chatArea}
        contentContainerStyle={styles.chatContent}
        onContentSizeChange={() => scrollRef.current?.scrollToEnd({ animated: true })}
        showsVerticalScrollIndicator={false}
      >
        {/* 清除对话 */}
        {messages.length > 0 && (
          <Pressable
            style={styles.clearBtn}
            onPress={clearMessages}
          >
            <Text style={styles.clearText}>清除对话</Text>
          </Pressable>
        )}

        {/* 欢迎 */}
        {messages.length === 0 && !streamingText && (
          <View style={[styles.aiBubble, Shadow.sm]}>
            <Text style={styles.aiName}>岁吉</Text>
            <RichContent content={
              store.mingPanCache
                ? '你的命盘已就绪。有什么想聊的？\n可以跟我说说你现在的心情。'
                : '有什么想聊的？\n输入生辰后，对话会更贴合你。'
            } />
          </View>
        )}

        {/* 消息列表 */}
        {messages.map((msg, i) => (
          msg.role === 'user' ? (
            <View key={i} style={styles.userRow}>
              <View style={[styles.userBubble, Shadow.sm]}>
                <Text style={styles.userText}>{msg.content}</Text>
              </View>
            </View>
          ) : (
            <View key={i} style={[styles.aiBubble, Shadow.sm]}>
              <Text style={styles.aiName}>岁吉</Text>
              <RichContent content={msg.content} />
            </View>
          )
        ))}

        {/* 流式 */}
        {streamingText ? (
          <View style={[styles.aiBubble, Shadow.sm]}>
            <Text style={styles.aiName}>岁吉</Text>
            <RichContent content={streamingText} />
            <StreamCursor />
          </View>
        ) : null}

        {loading && !streamingText && (
          <View style={styles.loadingRow}>
            <View style={styles.loadingDots}>
              <View style={[styles.loadingDot, { opacity: 0.4 }]} />
              <View style={[styles.loadingDot, { opacity: 0.6 }]} />
              <View style={[styles.loadingDot, { opacity: 0.8 }]} />
            </View>
          </View>
        )}
      </ScrollView>

      {/* 输入区 */}
      <View style={[styles.inputArea, { paddingBottom: insets.bottom + Space.sm }]}>
        <View style={[styles.inputCard, Shadow.sm]}>
          <TextInput
            style={styles.input}
            placeholder="说说你的心情…"
            placeholderTextColor={Colors.inkHint}
            value={message}
            onChangeText={setMessage}
            multiline
            editable={!loading}
            blurOnSubmit={false}
          />
          <SendOrStopButton
            disabled={!message.trim()}
            streaming={loading}
            onSend={handleSend}
            onStop={handleStop}
          />
        </View>
      </View>
    </KeyboardAvoidingView>
  );
}

function SendOrStopButton({
  disabled, streaming, onSend, onStop,
}: {
  disabled: boolean;
  streaming: boolean;
  onSend: () => void;
  onStop: () => void;
}) {
  const scale = useSharedValue(1);
  const animStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
  }));

  const isStop = streaming;
  const onPress = isStop ? onStop : onSend;
  const isDisabled = !isStop && disabled;

  return (
    <AnimatedPressable
      style={[
        styles.sendBtn,
        isStop && styles.stopBtn,
        isDisabled && styles.sendBtnDisabled,
        animStyle,
      ]}
      disabled={isDisabled}
      onPress={onPress}
      onPressIn={() => { if (!isDisabled) scale.value = withSpring(0.9, Motion.quick); }}
      onPressOut={() => { scale.value = withSpring(1, Motion.quick); }}
    >
      <Text style={[styles.sendIcon, isDisabled && styles.sendIconDisabled]}>
        {isStop ? '■' : '↑'}
      </Text>
    </AnimatedPressable>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.bg },

  // 空状态
  emptyCenter: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: Space['3xl'],
  },
  emptyIcon: {
    width: 64,
    height: 64,
    borderRadius: 32,
    backgroundColor: Colors.brandBg,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: Space.xl,
  },
  emptyIconText: {
    fontFamily: 'Georgia',
    fontSize: 28,
    color: Colors.vermilion,
  },
  emptyTitle: {
    ...Type.title,
    color: Colors.ink,
    marginBottom: Space.md,
  },
  emptySub: {
    ...Type.body,
    color: Colors.inkSecondary,
    textAlign: 'center',
    lineHeight: 24,
  },
  emptyProviders: {
    ...Type.caption,
    color: Colors.inkHint,
    marginTop: Space.sm,
    marginBottom: Space.xl,
  },
  setupBtn: {
    backgroundColor: Colors.surface,
    borderRadius: Radius.lg,
    paddingVertical: Space.md,
    paddingHorizontal: Space['2xl'],
  },
  setupBtnText: {
    ...Type.body,
    color: Colors.vermilion,
    fontWeight: '500',
  },

  // 对话区
  chatArea: { flex: 1 },
  chatContent: {
    padding: Space.lg,
    gap: Space.md,
    paddingBottom: Space.xl,
  },

  // 清除
  clearBtn: {
    alignSelf: 'center',
    paddingVertical: Space.xs,
    paddingHorizontal: Space.md,
  },
  clearText: {
    ...Type.caption,
    color: Colors.inkHint,
  },

  // AI 气泡
  aiBubble: {
    backgroundColor: Colors.surface,
    borderRadius: Radius.lg,
    borderTopLeftRadius: Radius.xs,
    padding: Space.base,
    maxWidth: '85%',
  },
  aiName: {
    ...Type.label,
    color: Colors.vermilion,
    marginBottom: Space.xs,
  },
  aiText: {
    ...Type.body,
    color: Colors.ink,
    lineHeight: 24,
  },

  // 用户气泡
  userRow: {
    alignItems: 'flex-end',
  },
  userBubble: {
    backgroundColor: Colors.ink,
    borderRadius: Radius.lg,
    borderTopRightRadius: Radius.xs,
    padding: Space.base,
    maxWidth: '80%',
  },
  userText: {
    ...Type.body,
    color: Colors.bg,
    lineHeight: 24,
  },

  // Loading
  loadingRow: {
    paddingVertical: Space.sm,
  },
  loadingDots: {
    flexDirection: 'row',
    gap: Space.xs,
  },
  loadingDot: {
    width: 6,
    height: 6,
    borderRadius: 3,
    backgroundColor: Colors.inkHint,
  },

  // 输入区
  inputArea: {
    paddingHorizontal: Space.lg,
    paddingTop: Space.sm,
    backgroundColor: Colors.bg,
  },
  inputCard: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    backgroundColor: Colors.surface,
    borderRadius: Radius.xl,
    paddingLeft: Space.base,
    paddingRight: Space.sm,
    paddingVertical: Space.sm,
  },
  input: {
    flex: 1,
    ...Type.body,
    color: Colors.ink,
    maxHeight: 100,
    paddingVertical: Space.sm,
  },
  sendBtn: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: Colors.vermilion,
    alignItems: 'center',
    justifyContent: 'center',
  },
  stopBtn: {
    backgroundColor: Colors.ink,
  },
  sendBtnDisabled: {
    backgroundColor: Colors.bgSecondary,
  },
  sendIcon: {
    fontSize: 18,
    color: '#FFFFFF',
    fontWeight: '700',
  },
  sendIconDisabled: {
    color: Colors.inkHint,
  },
});
