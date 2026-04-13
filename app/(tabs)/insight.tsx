/**
 * 问道页面
 *
 * AI 对话界面 — 流式输出、命盘注入、BYOM
 */

import React, {
  useState, useRef, useCallback, useEffect,
} from 'react';
import {
  StyleSheet, View, Text, TextInput, ScrollView, Pressable,
  KeyboardAvoidingView, Platform, ActivityIndicator,
} from 'react-native';
import { useRouter } from 'expo-router';
import { Colors, Space, Type } from '@/lib/design/tokens';
import { useUserStore } from '@/lib/store/userStore';
import { streamChat, type Message, type ChatConfig } from '@/lib/ai/chat';

// ── 欢迎语 ──────────────────────────────────────────────────────────────
const WELCOME = '有什么想聊的？可以跟我说说你现在的心情，或者问问关于你自己的事。';

export default function InsightScreen() {
  const router = useRouter();

  const { apiProvider, apiKey, apiModel, apiBaseUrl, mingPanCache } = useUserStore();

  const [messages,  setMessages]  = useState<Message[]>([]);
  const [input,     setInput]     = useState('');
  const [streaming, setStreaming] = useState(false);

  const scrollRef = useRef<ScrollView>(null);

  // 滚到底部
  useEffect(() => {
    setTimeout(() => scrollRef.current?.scrollToEnd({ animated: true }), 80);
  }, [messages]);

  const hasApiConfig = !!(apiProvider && apiKey);

  // 命盘摘要：从 cache 提取关键字段
  const mingPanSummary = (() => {
    if (!mingPanCache) return undefined;
    try {
      const p = JSON.parse(mingPanCache);
      const siZhu = p.siZhu as Array<{ gan: string; zhi: string }>;
      const cols = siZhu
        ?.map((z: { gan: string; zhi: string }) => `${z.gan}${z.zhi}`)
        .join(' ');
      return [
        cols && `四柱：${cols}`,
        p.riZhu && `日主：${p.riZhu.gan}（${p.riZhu.yinYang}${p.riZhu.wuXing}）`,
        p.geJu?.name && `格局：${p.geJu.name}`,
        p.wuXingStrength?.yongShen && `用神：${p.wuXingStrength.yongShen}`,
      ]
        .filter(Boolean)
        .join('，');
    } catch {
      return undefined;
    }
  })();

  const getConfig = useCallback((): ChatConfig | null => {
    if (!apiProvider || !apiKey) return null;
    return {
      provider: apiProvider,
      apiKey,
      model: apiModel ?? '',
      baseUrl: apiBaseUrl ?? undefined,
      mingPanSummary,
    };
  }, [apiProvider, apiKey, apiModel, apiBaseUrl, mingPanSummary]);

  const handleSend = useCallback(async () => {
    const text = input.trim();
    if (!text || streaming) return;

    const config = getConfig();
    if (!config) return;

    const newHistory: Message[] = [
      ...messages,
      { role: 'user', content: text },
    ];

    setMessages(newHistory);
    setInput('');
    setStreaming(true);

    // 先插入一条空的 assistant 消息，后续填充
    setMessages(prev => [...prev, { role: 'assistant', content: '' }]);

    try {
      let accumulated = '';
      for await (const token of streamChat(newHistory, config)) {
        accumulated += token;
        const final = accumulated;
        setMessages(prev => {
          const updated = [...prev];
          updated[updated.length - 1] = { role: 'assistant', content: final };
          return updated;
        });
      }
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : '未知错误';
      setMessages(prev => {
        const updated = [...prev];
        updated[updated.length - 1] = {
          role: 'assistant',
          content: `⚠️ 出错了：${msg}`,
        };
        return updated;
      });
    } finally {
      setStreaming(false);
    }
  }, [input, streaming, messages, getConfig]);

  // ── 无 API 配置时的引导 ──
  if (!hasApiConfig) {
    return (
      <View style={styles.container}>
        <View style={styles.guideCenter}>
          <Text style={styles.guideTitle}>问道</Text>
          <Text style={styles.guideSub}>配置 AI 密钥，开启深度对话</Text>
          <Text style={styles.guideBody}>
            岁吉支持 OpenAI、DeepSeek、Anthropic 及自定义接口。
            {'\n'}带上你的密钥，AI 将基于你的命盘与你深度交谈。
          </Text>
          <Pressable style={styles.guideBtn} onPress={() => router.push('/settings')}>
            <Text style={styles.guideBtnText}>前往配置</Text>
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
        showsVerticalScrollIndicator={false}
      >
        {/* 欢迎气泡 */}
        <View style={styles.aiBubble}>
          <Text style={styles.aiLabel}>岁吉</Text>
          <Text style={styles.aiText}>{WELCOME}</Text>
        </View>

        {/* 消息列表 */}
        {messages.map((m, i) =>
          m.role === 'user' ? (
            <View key={i} style={styles.userBubble}>
              <Text style={styles.userText}>{m.content}</Text>
            </View>
          ) : (
            <View key={i} style={styles.aiBubble}>
              <Text style={styles.aiLabel}>岁吉</Text>
              <Text style={styles.aiText}>
                {m.content}
                {streaming && i === messages.length - 1 ? (
                  <Text style={styles.cursor}>▌</Text>
                ) : null}
              </Text>
            </View>
          ),
        )}

        {/* 流式加载指示 */}
        {streaming && messages[messages.length - 1]?.content === '' && (
          <View style={styles.aiBubble}>
            <Text style={styles.aiLabel}>岁吉</Text>
            <ActivityIndicator
              size="small"
              color={Colors.brand}
              style={{ alignSelf: 'flex-start', marginTop: Space.xs }}
            />
          </View>
        )}
      </ScrollView>

      {/* 输入区 */}
      <View style={styles.inputArea}>
        <TextInput
          style={styles.input}
          placeholder="说说你的心情…"
          placeholderTextColor={Colors.inkHint}
          value={input}
          onChangeText={setInput}
          multiline
          editable={!streaming}
          onSubmitEditing={handleSend}
        />
        <Pressable
          style={[styles.sendBtn, (!input.trim() || streaming) && styles.sendBtnDisabled]}
          disabled={!input.trim() || streaming}
          onPress={handleSend}
        >
          <Text style={[styles.sendText, (!input.trim() || streaming) && styles.sendTextDisabled]}>
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

  // 引导页
  guideCenter: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: Space['2xl'],
  },
  guideTitle: {
    ...Type.title,
    color: Colors.ink,
    fontWeight: '200',
    letterSpacing: 8,
    marginBottom: Space.sm,
  },
  guideSub: {
    ...Type.caption,
    color: Colors.inkTertiary,
    marginBottom: Space.xl,
  },
  guideBody: {
    ...Type.body,
    color: Colors.inkSecondary,
    textAlign: 'center',
    marginBottom: Space['2xl'],
    lineHeight: 24,
  },
  guideBtn: {
    paddingVertical: Space.md,
    paddingHorizontal: Space.xl,
    borderWidth: 1,
    borderColor: Colors.brand,
    borderRadius: 2,
  },
  guideBtnText: {
    ...Type.body,
    color: Colors.brand,
    fontWeight: '500',
  },

  // 聊天区
  chatArea: {
    flex: 1,
  },
  chatContent: {
    padding: Space.lg,
    paddingTop: Space.xl,
    paddingBottom: Space['2xl'],
    gap: Space.base,
  },

  // AI 气泡
  aiBubble: {
    backgroundColor: Colors.surface,
    borderRadius: 4,
    padding: Space.lg,
    maxWidth: '88%',
    alignSelf: 'flex-start',
  },
  aiLabel: {
    ...Type.label,
    color: Colors.brand,
    fontWeight: '600',
    marginBottom: Space.sm,
    letterSpacing: 1,
  },
  aiText: {
    ...Type.body,
    color: Colors.ink,
  },
  cursor: {
    color: Colors.brand,
    opacity: 0.8,
  },

  // 用户气泡
  userBubble: {
    backgroundColor: Colors.bg,
    borderRadius: 4,
    padding: Space.lg,
    maxWidth: '88%',
    alignSelf: 'flex-end',
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: Colors.inkHint + '60',
  },
  userText: {
    ...Type.body,
    color: Colors.ink,
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
