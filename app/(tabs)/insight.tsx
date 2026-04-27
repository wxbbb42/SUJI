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
import { Ionicons } from '@expo/vector-icons';
import { Colors, Space, Radius, Type, Shadow, Motion, Size } from '@/lib/design/tokens';
import { useUserStore } from '@/lib/store/userStore';
import { useChatStore } from '@/lib/store/chatStore';
import { getChatConfig, sendOrchestrated, sendChat } from '@/lib/ai/chat';
import type { ChatMessage } from '@/lib/ai';
import { StreamCursor } from '@/components/ai/StreamCursor';
import { RichContent } from '@/components/ai/RichContent';
import { CoTCard, type ToolCallTrace } from '@/components/ai/CoTCard';
import { EvidenceCard } from '@/components/ai/EvidenceCard';
import { FullReasoningSheet } from '@/components/ai/FullReasoningSheet';
import { splitOrchestrationOutput } from '@/components/ai/customRules/preprocessOrchestration';
import { ModePicker, type ChatMode } from '@/components/chat/ModePicker';
import { ModeChip } from '@/components/chat/ModeChip';
import { HexagramAnimation } from '@/components/divination/HexagramAnimation';
import { HexagramDisplay } from '@/components/divination/HexagramDisplay';
import type { HexagramReading } from '@/lib/divination/types';
import { QimenSetupAnimation } from '@/components/qimen/QimenSetupAnimation';
import { YongShenPalaceCard } from '@/components/qimen/YongShenPalaceCard';
import { AdjacentPalaceTags } from '@/components/qimen/AdjacentPalaceTags';
import type { QimenChart } from '@/lib/qimen/types';

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

  const [chatMode, setChatMode] = useState<ChatMode>('auto');
  const [modePickerVisible, setModePickerVisible] = useState(false);

  // 当次发送的实时卦象（流式中的 cast 完成后填）
  const [liveHexagram, setLiveHexagram] = useState<HexagramReading | null>(null);
  // 当次发送的实时奇门盘（setup_qimen 完成后填）
  const [liveQimenChart, setLiveQimenChart] = useState<QimenChart | null>(null);

  // 当次发送的"实时"流式状态
  const [liveToolCalls, setLiveToolCalls] = useState<ToolCallTrace[]>([]);
  const [liveThinker, setLiveThinker] = useState('');

  // 详情 BottomSheet 状态
  const [sheetData, setSheetData] = useState<null | {
    thinker: string;
    evidence: string[];
    toolCalls: ToolCallTrace[];
    hexagram?: HexagramReading | null;
    qimenChart?: QimenChart | null;
  }>(null);

  const config = getChatConfig(store);

  // 发送
  const handleSend = useCallback(async () => {
    const text = message.trim();
    if (!text || !config || loading) return;

    const userMsg: ChatMessage = { role: 'user', content: text, timestamp: Date.now() };
    addMessage(userMsg);
    setMessage('');
    setLoading(true);
    setStreamingText('');
    setLiveToolCalls([]);
    setLiveThinker('');
    setLiveHexagram(null);
    setLiveQimenChart(null);
    const abortController = new AbortController();
    abortRef.current = abortController;

    // 本地累计 tool calls（避免 React state 在 closure 里 stale）
    const localToolCalls: ToolCallTrace[] = [];

    const forceMode = chatMode === 'liuyao' ? 'liuyao'
                    : chatMode === 'mingli' ? 'mingli'
                    : undefined;
    let localHexagram: HexagramReading | null = null;
    let localQimenChart: QimenChart | null = null;

    try {
      // 没命盘 OR Anthropic provider → fallback 到旧 sendChat（无工具，无双段）
      // Responses API（Azure Foundry / GPT-5）已在编排器内支持，不再排除
      const useOrchestration =
        config.provider !== 'anthropic'
        && (store.mingPanCache !== null || forceMode === 'liuyao');

      if (useOrchestration) {
        const result = await sendOrchestrated({
          question: text,
          config,
          mingPanJson: store.mingPanCache,
          ziweiPanJson: store.ziweiPanCache,
          forceMode: forceMode,
          onToolCall: (call, res) => {
            const trace: ToolCallTrace = {
              name: call.name,
              argSummary: summarizeArgs(call.arguments),
              resultSummary: summarizeResult(res),
              narration: narrateTool(call.name, call.arguments, res),
            };
            localToolCalls.push(trace);
            setLiveToolCalls(prev => [...prev, trace]);

            // 卜卦工具：捕获卦象
            if (call.name === 'cast_liuyao' && !(res as any)?.error) {
              localHexagram = res as HexagramReading;
              setLiveHexagram(localHexagram);
            }

            // 起奇门盘工具：捕获奇门盘
            if (call.name === 'setup_qimen' && !(res as any)?.error) {
              localQimenChart = res as QimenChart;
              setLiveQimenChart(localQimenChart);
            }
          },
          onThinkerComplete: (t) => setLiveThinker(t),
          onChunk: (partial) => {
            setStreamingText(partial);
            setTimeout(() => scrollRef.current?.scrollToEnd({ animated: true }), 50);
          },
          signal: abortController.signal,
        });

        const assistantMsg: ChatMessage = {
          role: 'assistant',
          content: result.interpreter,
          timestamp: Date.now(),
          orchestration: {
            thinker: result.thinker,
            evidence: mergeEvidence(result.evidence, splitOrchestrationOutput(result.interpreter).evidence),
            toolCalls: localToolCalls,
            hexagram: localHexagram,
            qimenChart: localQimenChart,
          },
        };
        addMessage(assistantMsg);
      } else {
        // Fallback：旧 sendChat 路径（流式但无工具、无双段输出）
        const fullText = await sendChat(
          [...messages, userMsg],
          config,
          store.mingPanCache,
          (partial) => {
            setStreamingText(partial);
            setTimeout(() => scrollRef.current?.scrollToEnd({ animated: true }), 50);
          },
          abortController.signal,
        );
        const assistantMsg: ChatMessage = {
          role: 'assistant',
          content: fullText,
          timestamp: Date.now(),
        };
        addMessage(assistantMsg);
      }

      setStreamingText('');
      setLiveToolCalls([]);
      setLiveThinker('');
      setLiveHexagram(null);
      setLiveQimenChart(null);
      setChatMode('auto');
    } catch (err: any) {
      // 用户主动停止 → 已到达的 streamingText / 推演保留为空消息或丢弃，不显示错误
      if (!abortController.signal.aborted) {
        const errorMsg: ChatMessage = {
          role: 'assistant',
          content: `请求失败：${err.message || '未知错误'}`,
          timestamp: Date.now(),
        };
        addMessage(errorMsg);
      }
      setStreamingText('');
      setLiveToolCalls([]);
      setLiveThinker('');
      setLiveHexagram(null);
      setLiveQimenChart(null);
      setChatMode('auto');
    } finally {
      setLoading(false);
      abortRef.current = null;
    }
  }, [message, config, loading, store.mingPanCache, store.ziweiPanCache, addMessage, chatMode]);

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
              <View key={i} style={[styles.userBubble, Shadow.sm]}>
                <Text style={styles.userText}>{msg.content}</Text>
              </View>
            </View>
          ) : (
            <View key={i} style={[styles.aiBubble, Shadow.sm]}>
              <Text style={styles.aiName}>岁吉</Text>

              {msg.orchestration && (
                <CoTCard
                  toolCalls={msg.orchestration.toolCalls}
                  thinkerText={msg.orchestration.thinker}
                  isStreaming={false}
                />
              )}

              {msg.orchestration?.hexagram && (
                <HexagramDisplay
                  benGua={msg.orchestration.hexagram.benGua}
                  bianGua={msg.orchestration.hexagram.bianGua}
                  changingYao={msg.orchestration.hexagram.changingYao}
                />
              )}

              {msg.orchestration?.qimenChart && (
                <>
                  <YongShenPalaceCard
                    palace={msg.orchestration.qimenChart.palaces[msg.orchestration.qimenChart.yongShen.palaceId - 1]}
                    yongShen={msg.orchestration.qimenChart.yongShen}
                  />
                  <AdjacentPalaceTags chart={msg.orchestration.qimenChart} />
                </>
              )}

              <RichContent content={
                msg.orchestration
                  ? splitOrchestrationOutput(msg.content).interpretation
                  : msg.content
              } />

              {msg.orchestration && msg.orchestration.evidence.length > 0 && (
                <EvidenceCard
                  evidence={msg.orchestration.evidence}
                  onTapFull={() => setSheetData({
                    thinker: msg.orchestration!.thinker,
                    evidence: msg.orchestration!.evidence,
                    toolCalls: msg.orchestration!.toolCalls,
                    hexagram: msg.orchestration!.hexagram,
                    qimenChart: msg.orchestration!.qimenChart,
                  })}
                />
              )}
            </View>
          )
        ))}

        {/* 流式 */}
        {(streamingText || liveToolCalls.length > 0) ? (
          <View style={[styles.aiBubble, Shadow.sm]}>
            <Text style={styles.aiName}>岁吉</Text>

            <CoTCard
              toolCalls={liveToolCalls}
              thinkerText={liveThinker}
              isStreaming={true}
            />

            {liveHexagram && (
              <HexagramAnimation
                benGua={liveHexagram.benGua}
                bianGua={liveHexagram.bianGua}
                changingYao={liveHexagram.changingYao}
              />
            )}

            {liveQimenChart && (
              <>
                <QimenSetupAnimation chart={liveQimenChart} />
                <YongShenPalaceCard
                  palace={liveQimenChart.palaces[liveQimenChart.yongShen.palaceId - 1]}
                  yongShen={liveQimenChart.yongShen}
                />
                <AdjacentPalaceTags chart={liveQimenChart} />
              </>
            )}

            {streamingText && (
              <>
                <RichContent content={
                  splitOrchestrationOutput(streamingText).interpretation
                } />
                <StreamCursor />
              </>
            )}

            {streamingText && (() => {
              const evid = splitOrchestrationOutput(streamingText).evidence;
              return evid.length > 0 ? (
                <EvidenceCard
                  evidence={evid}
                  onTapFull={() => setSheetData({
                    thinker: liveThinker,
                    evidence: evid,
                    toolCalls: liveToolCalls,
                    hexagram: liveHexagram,
                    qimenChart: liveQimenChart,
                  })}
                />
              ) : null;
            })()}
          </View>
        ) : null}

        {loading && !streamingText && liveToolCalls.length === 0 && (
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
            placeholder="说说你的心情或想问的事…"
            placeholderTextColor={Colors.inkHint}
            value={message}
            onChangeText={setMessage}
            multiline
            editable={!loading}
            blurOnSubmit={false}
          />
          <View style={styles.inputBottomRow}>
            <Pressable
              style={styles.modeIconBtn}
              onPress={() => setModePickerVisible(true)}
              hitSlop={4}
            >
              <Ionicons
                name="options-outline"
                size={20}
                color={Colors.inkSecondary}
              />
            </Pressable>
            <ModeChip mode={chatMode} onClear={() => setChatMode('auto')} />
            <View style={{ flex: 1 }} />
            <SendOrStopButton
              disabled={!message.trim()}
              streaming={loading}
              onSend={handleSend}
              onStop={handleStop}
            />
          </View>
        </View>
      </View>

      <FullReasoningSheet
        visible={sheetData !== null}
        evidence={sheetData?.evidence ?? []}
        thinkerText={sheetData?.thinker ?? ''}
        toolCalls={sheetData?.toolCalls ?? []}
        qimenChart={sheetData?.qimenChart ?? null}
        onClose={() => setSheetData(null)}
      />

      <ModePicker
        visible={modePickerVisible}
        current={chatMode}
        onSelect={(m) => setChatMode(m)}
        onClose={() => setModePickerVisible(false)}
      />
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

function mergeEvidence(primary: string[], fallback: string[]): string[] {
  const out: string[] = [];
  for (const item of [...primary, ...fallback]) {
    const text = item.trim();
    if (text && !out.includes(text)) out.push(text);
    if (out.length >= 6) break;
  }
  return out;
}

function summarizeArgs(args: Record<string, unknown>): string {
  return Object.entries(args).map(([k, v]) => `${k}=${v}`).join(', ');
}

function summarizeResult(r: any): string {
  if (!r) return '';
  if (typeof r === 'string') return r.length > 30 ? r.slice(0, 30) + '…' : r;
  if (r.summary) return r.summary;
  if (r.error) return `error:${r.error}`;
  return JSON.stringify(r).slice(0, 30) + '…';
}

/**
 * 把工具调用翻译成 CoT 卡里那种"我正在做什么"的诙谐古风叙事
 * —— 这是 AI 性格外露的地方，故意留点戏感
 */
function narrateTool(
  name: string,
  args: Record<string, unknown>,
  result: any,
): string {
  const ok = !result?.error;
  const tail = ok ? ' · 心里有数了' : ` · ${describeError(result?.error)}`;

  if (name === 'get_domain') {
    const d = String(args.domain ?? '');
    const map: Record<string, string> = {
      子女: '翻一翻你与孩儿的缘分簿',
      婚姻: '看看你姻缘里的风云',
      事业: '数一数你前路上的功名',
      财富: '摸一摸你的财库虚实',
      健康: '听一听你身上气脉的动静',
      父母: '寻一寻你父母星的位次',
      兄弟: '望一望你兄弟星的远近',
      迁移: '看看你的驿马起没起',
      田宅: '数一数你田宅里几间屋',
      福德: '照一照你福德宫的灯火',
    };
    return (map[d] ?? `看看「${d}」这一面`) + tail;
  }

  if (name === 'get_timing') {
    const s = String(args.scope ?? '');
    const map: Record<string, string> = {
      current_dayun: '看看你眼下走的这一程大运',
      all_dayun: '把你这一辈子的运程铺开看一遍',
      liunian: '翻一翻这几年的流年簿',
      liuyue: '数一数这一年里月相的起伏',
    };
    return (map[s] ?? '看看时间这条线') + tail;
  }

  if (name === 'get_bazi_star') {
    const p = String(args.person ?? '');
    const map: Record<string, string> = {
      配偶: '找一找你的配偶星藏在哪一柱',
      子女: '探一探你的子女星在不在',
      父母: '摸一摸你父母星的根脉',
      兄弟: '看一看你兄弟星的远近',
    };
    return (map[p] ?? `找找「${p}」星的位置`) + tail;
  }

  if (name === 'get_ziwei_palace') {
    const p = String(args.palace ?? '');
    return `凝视紫微${p}` + tail;
  }

  if (name === 'list_shensha') {
    const k = String(args.kind ?? 'all');
    const map: Record<string, string> = {
      桃花: '数一数你命里的桃花',
      权贵: '看看你命里有几位贵人',
      文昌: '摸一摸你的文昌星',
      驿马: '看你的驿马动了没',
      吉: '翻翻命里的吉星',
      凶: '看看命里有哪些煞',
      中性: '数数中性的神煞',
      all: '翻一翻你命里的神煞总图',
    };
    return (map[k] ?? '看看神煞里有什么') + tail;
  }

  if (name === 'get_today_context') {
    return '翻一翻今日的黄历' + tail;
  }

  if (name === 'cast_liuyao') {
    return '三币六掷，为你起一卦' + tail;
  }

  if (name === 'setup_qimen') {
    return '布盘九宫，定准时辰' + tail;
  }

  return name + tail;
}

function describeError(err: string | undefined): string {
  if (!err) return '没要到';
  if (err.includes('palace_not_found')) return '此宫位没找到';
  if (err.includes('no_ziwei_chart')) return '紫微盘还没排好';
  if (err.includes('liunian_compute_failed')) return '流年算盘卡住了';
  if (err.includes('unknown_domain')) return '此领域不识';
  return '此处暂未取到';
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
    flexDirection: 'column',
    alignItems: 'stretch',
    backgroundColor: Colors.surface,
    borderRadius: Radius.xl,
    paddingHorizontal: Space.base,
    paddingVertical: Space.sm,
  },
  input: {
    ...Type.body,
    color: Colors.ink,
    maxHeight: 100,
    paddingVertical: Space.sm,
  },
  inputBottomRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Space.sm,
    marginTop: Space.xs,
  },
  modeIconBtn: {
    width: 32,
    height: 32,
    alignItems: 'center',
    justifyContent: 'center',
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
