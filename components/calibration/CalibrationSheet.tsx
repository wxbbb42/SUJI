// components/calibration/CalibrationSheet.tsx
import React, { useEffect, useRef, useState, useCallback } from 'react';
import {
  Modal, View, Text, Pressable, ScrollView, TextInput, StyleSheet, KeyboardAvoidingView, Platform,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Colors, Space, Radius, Type, Shadow } from '@/lib/design/tokens';
import { useUserStore } from '@/lib/store/userStore';
import { CalibrationSession, type NextStep } from '@/lib/calibration/CalibrationSession';
import { calibrationAI } from '@/lib/calibration/CalibrationAI';
import { ThinkingDots } from './ThinkingDots';

interface ChatLine {
  role: 'ai' | 'user';
  text: string;
}

const SHICHEN_LABEL: Record<number, { name: string; range: string }> = {
  0:  { name: '子时', range: '23:00–01:00' },  2:  { name: '丑时', range: '01:00–03:00' },
  4:  { name: '寅时', range: '03:00–05:00' },  6:  { name: '卯时', range: '05:00–07:00' },
  8:  { name: '辰时', range: '07:00–09:00' },  10: { name: '巳时', range: '09:00–11:00' },
  12: { name: '午时', range: '11:00–13:00' },  14: { name: '未时', range: '13:00–15:00' },
  16: { name: '申时', range: '15:00–17:00' },  18: { name: '酉时', range: '17:00–19:00' },
  20: { name: '戌时', range: '19:00–21:00' },  22: { name: '亥时', range: '21:00–23:00' },
};

interface Props {
  visible: boolean;
  onClose: () => void;
}

export function CalibrationSheet({ visible, onClose }: Props) {
  const insets = useSafeAreaInsets();
  const u = useUserStore();
  const setBirthDate = useUserStore(s => s.setBirthDate);
  const scrollRef = useRef<ScrollView>(null);
  const sessionRef = useRef<CalibrationSession | null>(null);

  const [lines, setLines] = useState<ChatLine[]>([]);
  const [input, setInput] = useState('');
  const [thinking, setThinking] = useState(false);
  const [done, setDone] = useState(false);

  const append = useCallback((line: ChatLine) => {
    setLines(prev => [...prev, line]);
    setTimeout(() => scrollRef.current?.scrollToEnd({ animated: true }), 50);
  }, []);

  useEffect(() => {
    if (!visible) return;
    if (!u.birthDate || !u.gender) {
      append({ role: 'ai', text: '需要先在"我的"里填写生辰和性别。' });
      setDone(true);
      return;
    }
    setLines([]);
    setDone(false);
    setInput('');
    const longitude = u.birthLongitude ?? 116.4; // 北京兜底；真太阳时差异 ≤±15 分钟，对 ±1 时辰校准影响可忽略
    const start = async () => {
      setThinking(true);
      const session = new CalibrationSession(calibrationAI);
      sessionRef.current = session;
      try {
        const { firstQuestion } = await session.start({
          birthDate: new Date(u.birthDate!),
          gender: u.gender!,
          longitude,
        });
        append({ role: 'ai', text: '我会问你 3-5 个过去发生过的事件，帮你校准出生时辰。' });
        append({ role: 'ai', text: firstQuestion });
      } catch (e) {
        if (e instanceof Error && e.message === 'TOO_YOUNG') {
          append({ role: 'ai', text: '你目前还不够大，过去事件回推暂时无法校准。再过几年可以再来。' });
        } else if (e instanceof Error && e.message === 'LOW_SIGNAL') {
          append({ role: 'ai', text: '校准引擎正在升级紫微大限信号，当前版本还无法精确鉴别你的时辰。下个版本会修复。' });
        } else if (e instanceof Error && e.message === 'NIGHT_ZISHI_UNSUPPORTED') {
          append({ role: 'ai', text: '23 点前后出生的时辰校准暂未支持，可以先按你填的时辰用，未来版本会加。' });
        } else {
          append({ role: 'ai', text: '启动校准时出错。可以稍后再试。' });
        }
        setDone(true);
      } finally {
        setThinking(false);
      }
    };
    start();
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [visible]);

  const handleResult = (step: NextStep) => {
    if (step.type === 'next_question') {
      append({ role: 'ai', text: step.question });
    } else if (step.type === 'locked') {
      const hour = step.correctedDate.getHours();
      const label = SHICHEN_LABEL[hour] ?? { name: '?时', range: '' };
      setBirthDate(step.correctedDate);
      // AI 给的总结语优先（更自然），后面追一行系统级反馈说"命盘已更新"
      append({ role: 'ai', text: step.summary });
      append({ role: 'ai', text: `已校准为${label.name}（${label.range}），命盘已更新。` });
      setDone(true);
    } else {
      append({ role: 'ai', text: step.reason || '信息不够，无法确定时辰。可换个时间再试。' });
      setDone(true);
    }
  };

  const send = async () => {
    const text = input.trim();
    if (!text || thinking || done) return;
    if (text.length > 200) {
      append({ role: 'ai', text: '请简短一点，控制在 200 字以内。' });
      return;
    }
    if (!sessionRef.current) return;
    append({ role: 'user', text });
    setInput('');
    setThinking(true);
    try {
      const r = await sessionRef.current.submitAnswer(text);
      handleResult(r.nextStep);
    } catch (e) {
      append({ role: 'ai', text: '网络异常，请稍后重试。' });
    } finally {
      setThinking(false);
    }
  };

  return (
    <Modal visible={visible} animationType="slide" transparent onRequestClose={onClose}>
      <Pressable style={styles.backdrop} onPress={onClose} />
      <View style={[styles.sheet, { paddingBottom: insets.bottom }]}>
        <View style={styles.handle} />
        <View style={styles.header}>
          <Text style={styles.title}>校准时辰</Text>
          <Pressable onPress={onClose} hitSlop={12}><Text style={styles.close}>✕</Text></Pressable>
        </View>
        <KeyboardAvoidingView style={styles.body} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
          <ScrollView ref={scrollRef} contentContainerStyle={styles.messages}>
            {lines.map((l, i) => (
              <View key={i} style={[styles.bubbleRow, l.role === 'user' ? styles.userRow : styles.aiRow]}>
                <View style={[styles.bubble, l.role === 'user' ? styles.userBubble : styles.aiBubble]}>
                  <Text style={l.role === 'user' ? styles.userText : styles.aiText}>{l.text}</Text>
                </View>
              </View>
            ))}
            {thinking && (
              <View style={[styles.bubbleRow, styles.aiRow]}>
                <View style={[styles.bubble, styles.aiBubble]}>
                  <ThinkingDots />
                </View>
              </View>
            )}
          </ScrollView>
          <View style={styles.inputRow}>
            <TextInput
              style={[styles.input, done && styles.inputDisabled]}
              placeholder={done ? '校准已结束' : '输入你的回答…'}
              placeholderTextColor={Colors.inkTertiary}
              value={input}
              onChangeText={setInput}
              editable={!done}
              maxLength={250}
              onSubmitEditing={send}
              returnKeyType="send"
            />
            <Pressable
              onPress={send}
              disabled={done || thinking || !input.trim()}
              style={[styles.sendBtn, (done || thinking || !input.trim()) && styles.sendBtnDisabled]}
            >
              <Text style={styles.sendText}>发送</Text>
            </Pressable>
          </View>
        </KeyboardAvoidingView>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  backdrop: { ...StyleSheet.absoluteFillObject, backgroundColor: 'rgba(0,0,0,0.4)' },
  sheet: {
    position: 'absolute', left: 0, right: 0, bottom: 0,
    height: '85%',
    backgroundColor: Colors.surface,
    borderTopLeftRadius: Radius.lg, borderTopRightRadius: Radius.lg,
    ...Shadow.md,
  },
  handle: {
    width: 36, height: 4, alignSelf: 'center',
    marginTop: Space.sm, marginBottom: Space.sm,
    backgroundColor: Colors.border, borderRadius: 2,
  },
  header: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
    paddingHorizontal: Space.base, paddingBottom: Space.sm,
    borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: Colors.border,
  },
  title: { ...Type.subtitle, color: Colors.ink },
  close: { ...Type.subtitle, color: Colors.inkSecondary },
  body: { flex: 1 },
  messages: { padding: Space.base, gap: Space.sm },
  bubbleRow: { flexDirection: 'row' },
  aiRow: { justifyContent: 'flex-start' },
  userRow: { justifyContent: 'flex-end' },
  bubble: { maxWidth: '80%', padding: Space.sm, borderRadius: Radius.md },
  aiBubble: { backgroundColor: Colors.bgSecondary, borderTopLeftRadius: Radius.sm },
  userBubble: { backgroundColor: Colors.brand, borderTopRightRadius: Radius.sm },
  aiText: { ...Type.body, color: Colors.ink },
  userText: { ...Type.body, color: Colors.surface },
  inputRow: {
    flexDirection: 'row', alignItems: 'center', gap: Space.sm,
    paddingHorizontal: Space.base, paddingVertical: Space.sm,
    borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: Colors.border,
  },
  input: {
    flex: 1, paddingHorizontal: Space.sm, paddingVertical: Space.xs,
    borderRadius: Radius.sm, backgroundColor: Colors.bgSecondary,
    ...Type.body, color: Colors.ink,
  },
  inputDisabled: { opacity: 0.5 },
  sendBtn: {
    paddingHorizontal: Space.base, paddingVertical: Space.xs,
    borderRadius: Radius.sm, backgroundColor: Colors.brand,
  },
  sendBtnDisabled: { opacity: 0.4 },
  sendText: { ...Type.body, color: Colors.surface, fontWeight: '600' },
});
