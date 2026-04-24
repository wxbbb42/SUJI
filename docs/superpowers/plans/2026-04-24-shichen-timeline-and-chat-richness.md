# 时辰能量轴 + 问道对话富化 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 spec `docs/superpowers/specs/2026-04-24-shichen-timeline-and-chat-richness-design.md` 中的 3 个模块落地：修 Chat 流式输出、为 AI 回复加富文本渲染（含结构化卡片）、首页 12 时辰方格换成个性化横向能量轴。

**Architecture:** 按"用户感知最强 → 较弱"的顺序执行：先修流式（Module 2），再铺 markdown 基础（Module 3 Level 1），最后做结构化卡片（Module 3 Level 2）和时辰轴（Module 1）。每个模块都能独立产出"可用的"小版本，即便中途停下也有价值。

**Tech Stack:** Expo SDK 54 · React Native 0.81 · TypeScript · react-native-markdown-display · expo/fetch · react-native-reanimated · zustand

---

## Module 2：Chat 流式修复

### Task 1：引入 jest-expo 最小测试环境

**为什么**：后续步骤要对 `preprocessYiji`、命盘关键词扫描、`computeShichenVibe` 这些纯函数做 TDD；当前项目没有 jest 配置，需要一次性铺好。

**Files:**
- Modify: `package.json`
- Create: `jest.config.js`

- [ ] **Step 1: 安装 jest-expo 及 peer deps**

```bash
cd /Users/xiaqobenwang/Documents/SUJI
npm install --save-dev jest jest-expo @types/jest @testing-library/react-native
```

Expected: 安装成功，`package.json` 的 `devDependencies` 新增这 4 个包。

- [ ] **Step 2: 创建 `jest.config.js`**

```js
/** @type {import('jest').Config} */
module.exports = {
  preset: 'jest-expo',
  testMatch: ['**/__tests__/**/*.test.(ts|tsx)'],
  transformIgnorePatterns: [
    'node_modules/(?!((jest-)?react-native|@react-native|expo(nent)?|@expo(nent)?/.*|@expo-google-fonts/.*|react-navigation|@react-navigation/.*|@unimodules/.*|unimodules|sentry-expo|native-base|react-native-svg|@ronradtke)/)'
  ],
};
```

- [ ] **Step 3: 在 `package.json` 的 scripts 里加 `test`**

```json
"scripts": {
  "start": "expo start --dev-client",
  "android": "expo run:android",
  "ios": "expo run:ios",
  "web": "expo start --web",
  "test": "jest"
}
```

- [ ] **Step 4: 写一个 smoke test 验证 jest 跑得起来**

创建 `lib/__tests__/smoke.test.ts`：

```ts
describe('jest smoke', () => {
  it('runs', () => {
    expect(1 + 1).toBe(2);
  });
});
```

- [ ] **Step 5: 运行测试**

Run: `npm test`
Expected: `PASS lib/__tests__/smoke.test.ts`，1 个测试通过。

- [ ] **Step 6: Commit**

```bash
git add package.json package-lock.json jest.config.js lib/__tests__/smoke.test.ts
git commit -m "test: 引入 jest-expo 最小测试环境"
```

---

### Task 2：把 chat.ts 的 fetch 换成 expo/fetch

**为什么**：RN 原生 fetch 对 ReadableStream 支持不稳，导致流式静默降级。`expo/fetch`（SDK 54 自带）在 Hermes + New Arch 下可靠。

**Files:**
- Modify: `lib/ai/chat.ts`

- [ ] **Step 1: 在 chat.ts 顶部加入 expo/fetch 引入**

在第 10 行 `import ... from './index'` 后面加：

```ts
import { fetch as expoFetch } from 'expo/fetch';
```

- [ ] **Step 2: 把 `streamOpenAI` 函数内的 `fetch(url, ...)` 改成 `expoFetch(url, ...)`**

当前 `lib/ai/chat.ts:100` 的 `const response = await fetch(url, {` 改成 `const response = await expoFetch(url, {`。

- [ ] **Step 3: 把 `streamResponsesAPI` 函数内的 fetch 改成 expoFetch**

当前 `lib/ai/chat.ts:161` 的 fetch 改成 expoFetch。

- [ ] **Step 4: 把 `streamAnthropic` 函数内的 fetch 改成 expoFetch**

当前 `lib/ai/chat.ts:244` 的 fetch 改成 expoFetch。

- [ ] **Step 5: 非流式 `fetchNonStream` 保持用原生 fetch**

这是硬错误兜底，不要动。

- [ ] **Step 6: TypeScript 编译检查**

Run: `npx tsc --noEmit`
Expected: 无报错，或仅有已存在的历史报错（不引入新报错）。

- [ ] **Step 7: Commit**

```bash
git add lib/ai/chat.ts
git commit -m "ai: 改用 expo/fetch 真正启用流式"
```

---

### Task 3：为 sendChat 加 AbortController 支持

**Files:**
- Modify: `lib/ai/chat.ts`

- [ ] **Step 1: 扩展 `sendChat` 签名**

修改 `lib/ai/chat.ts:369` 的 `sendChat` 函数签名为：

```ts
export async function sendChat(
  messages: ChatMessage[],
  config: ChatConfig,
  mingPanJson: string | null,
  onChunk?: (chunk: string) => void,
  signal?: AbortSignal,
): Promise<string> {
```

- [ ] **Step 2: 扩展三个 stream 生成器的签名**

给 `streamOpenAI`、`streamResponsesAPI`、`streamAnthropic` 各加一个可选 `signal?: AbortSignal` 参数，并在各自的 `expoFetch(url, { ... })` 选项里加 `signal`：

```ts
async function* streamOpenAI(
  messages: ChatMessage[],
  systemPrompt: string,
  config: ChatConfig,
  signal?: AbortSignal,
): AsyncGenerator<string> {
  // ...
  const response = await expoFetch(url, {
    method: 'POST',
    headers: { /* ... */ },
    body: JSON.stringify(body),
    signal,  // 新增
  });
  // ...
}
```

另外两个同理。

- [ ] **Step 3: `sendChat` 内部把 signal 透传给三个 stream**

修改 `lib/ai/chat.ts:378-383` 这一块：

```ts
const stream = config.provider === 'anthropic'
  ? streamAnthropic(messages, systemPrompt, config, signal)
  : isResponsesAPI(config)
    ? streamResponsesAPI(messages, systemPrompt, config, signal)
    : streamOpenAI(messages, systemPrompt, config, signal);
```

- [ ] **Step 4: 捕获 AbortError 返回已累积文本**

修改 `sendChat` 的 try/catch 逻辑为：

```ts
let fullText = '';
try {
  const stream = /* 如上 */;
  for await (const chunk of stream) {
    fullText += chunk;
    onChunk?.(fullText);
  }
  return fullText;
} catch (streamErr: any) {
  if (streamErr?.name === 'AbortError') {
    // 用户主动停止 —— 返回到目前为止累积的文本
    return fullText;
  }
  // 其他错误 fallback 到非流式
  console.warn('流式请求失败，降级为非流式:', streamErr);
  const text = await fetchNonStream(messages, systemPrompt, config);
  onChunk?.(text);
  return text;
}
```

- [ ] **Step 5: TypeScript 编译检查**

Run: `npx tsc --noEmit`
Expected: 无新报错。

- [ ] **Step 6: Commit**

```bash
git add lib/ai/chat.ts
git commit -m "ai: sendChat 支持 AbortSignal 中断"
```

---

### Task 4：StreamCursor 组件

**Files:**
- Create: `components/ai/StreamCursor.tsx`

- [ ] **Step 1: 创建 StreamCursor 组件**

```tsx
/**
 * 流式光标：末尾闪烁的 ▍
 */
import React, { useEffect } from 'react';
import { Text, StyleSheet } from 'react-native';
import Animated, {
  useSharedValue, useAnimatedStyle, withRepeat, withTiming, cancelAnimation,
} from 'react-native-reanimated';
import { Colors, Type } from '@/lib/design/tokens';

const AnimatedText = Animated.createAnimatedComponent(Text);

export function StreamCursor() {
  const opacity = useSharedValue(1);

  useEffect(() => {
    opacity.value = withRepeat(
      withTiming(0.2, { duration: 500 }),
      -1,
      true,
    );
    return () => cancelAnimation(opacity);
  }, [opacity]);

  const style = useAnimatedStyle(() => ({ opacity: opacity.value }));

  return <AnimatedText style={[styles.cursor, style]}>▍</AnimatedText>;
}

const styles = StyleSheet.create({
  cursor: {
    ...Type.body,
    color: Colors.vermilion,
    fontWeight: '300',
  },
});
```

- [ ] **Step 2: TypeScript 编译检查**

Run: `npx tsc --noEmit`
Expected: 无新报错。

- [ ] **Step 3: Commit**

```bash
git add components/ai/StreamCursor.tsx
git commit -m "ai: 新增流式光标组件"
```

---

### Task 5：SendOrStopButton + AbortController 接入 insight.tsx

**Files:**
- Modify: `app/(tabs)/insight.tsx`

- [ ] **Step 1: 改 imports，加 StreamCursor**

在 `app/(tabs)/insight.tsx` 的 import 段落加：

```tsx
import { StreamCursor } from '@/components/ai/StreamCursor';
```

- [ ] **Step 2: 在组件里声明 abortRef**

在 `export default function InsightScreen()` 内，现有 `const [loading, setLoading] = useState(false);` 之后加：

```tsx
const abortRef = useRef<AbortController | null>(null);
```

（顶部 import 确认已经 `import React, { useState, useRef, useCallback } from 'react';` —— 当前代码已经 import 了 useRef，沿用。）

- [ ] **Step 3: 改 handleSend，创建并透传 AbortController**

在 `handleSend` 内部，`setStreamingText('')` 之后添加：

```tsx
const abortController = new AbortController();
abortRef.current = abortController;
```

然后把 `sendChat` 调用改成：

```tsx
const fullText = await sendChat(
  newMessages, config, store.mingPanCache,
  (partial) => {
    setStreamingText(partial);
    setTimeout(() => scrollRef.current?.scrollToEnd({ animated: true }), 50);
  },
  abortController.signal,
);
```

- [ ] **Step 4: 新增 handleStop 回调**

在 `handleSend` 之后加：

```tsx
const handleStop = useCallback(() => {
  abortRef.current?.abort();
}, []);
```

- [ ] **Step 5: 改 SendButton → SendOrStopButton**

把现有 `function SendButton(...)` 整个替换为：

```tsx
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
```

- [ ] **Step 6: 在 styles 里添加 `stopBtn`**

在 `const styles = StyleSheet.create({...})` 里 `sendBtn` 样式之后加：

```ts
stopBtn: {
  backgroundColor: Colors.ink,
},
```

- [ ] **Step 7: JSX 里替换按钮调用**

找到当前的 `<SendButton disabled={...} onPress={handleSend} />`，替换为：

```tsx
<SendOrStopButton
  disabled={!message.trim()}
  streaming={loading}
  onSend={handleSend}
  onStop={handleStop}
/>
```

- [ ] **Step 8: 流式气泡末尾挂 StreamCursor**

找到现有：

```tsx
{streamingText ? (
  <View style={[styles.aiBubble, Shadow.sm]}>
    <Text style={styles.aiName}>岁吉</Text>
    <Text style={styles.aiText}>{streamingText}</Text>
  </View>
) : null}
```

改成：

```tsx
{streamingText ? (
  <View style={[styles.aiBubble, Shadow.sm]}>
    <Text style={styles.aiName}>岁吉</Text>
    <Text style={styles.aiText}>
      {streamingText}
      <StreamCursor />
    </Text>
  </View>
) : null}
```

- [ ] **Step 9: TypeScript 编译检查**

Run: `npx tsc --noEmit`
Expected: 无新报错。

- [ ] **Step 10: 设备手测（关键质量门）**

```bash
npx expo run:ios --device 00008140-001262AE010A801C --configuration Release
```

手机上：
- 向 AI 发一条"给我讲讲用神和喜神的区别"
- 确认：文字**逐 token 到达**（能看到一字一字或一小段一小段增加），末尾有闪烁 `▍`
- 流式中发送键变成墨色 ■，**点一下能中断**，已到达的内容保留成消息
- 流式结束后光标消失

Expected: 上面 4 点全部观察到。

- [ ] **Step 11: Commit**

```bash
git add app/\(tabs\)/insight.tsx
git commit -m "chat: 流式光标 + 停止键 + AbortController 接入"
```

---

## Module 3：富文本输出

### Task 6：安装 markdown-display + 基础 RichContent 组件

**Files:**
- Modify: `package.json`
- Create: `components/ai/RichContent.tsx`
- Create: `components/ai/richStyles.ts`

- [ ] **Step 1: 安装 react-native-markdown-display**

```bash
npm install react-native-markdown-display
```

Expected: 安装成功。注意：如果用该包在 RN 0.81 + New Architecture 下报错（最常见是依赖 `react-native-fit-image` 的 prop type 警告），则备选 `@ronradtke/react-native-markdown-display` 再试；仍不行则换 `react-native-marked`（API 不同，需要调整 `RichContent` 内部，但主入口和使用方式保持一致）。

- [ ] **Step 2: 创建 richStyles.ts —— markdown 元素 × design tokens**

```ts
/**
 * Markdown 元素样式，全部使用 design tokens
 */
import { StyleSheet } from 'react-native';
import { Colors, Space, Radius, Type, Shadow } from '@/lib/design/tokens';

export const richStyles = StyleSheet.create({
  body: {
    ...Type.body,
    color: Colors.ink,
    lineHeight: 28,
  },
  paragraph: {
    marginTop: 0,
    marginBottom: Space.md,
  },
  heading1: {
    fontFamily: 'Georgia',
    fontSize: 28,
    fontWeight: '400',
    color: Colors.ink,
    marginTop: Space.lg,
    marginBottom: Space.md,
  },
  heading2: {
    fontFamily: 'Georgia',
    fontSize: 22,
    fontWeight: '500',
    color: Colors.ink,
    marginTop: Space.md,
    marginBottom: Space.sm,
  },
  heading3: {
    fontFamily: 'Georgia',
    fontSize: 18,
    fontWeight: '500',
    color: Colors.ink,
    marginTop: Space.md,
    marginBottom: Space.xs,
  },
  strong: {
    color: Colors.vermilion,
    fontWeight: '600',
  },
  em: {
    color: Colors.inkSecondary,
    fontStyle: 'italic',
  },
  bullet_list: {
    marginVertical: Space.sm,
  },
  ordered_list: {
    marginVertical: Space.sm,
  },
  list_item: {
    flexDirection: 'row',
    marginBottom: Space.xs,
  },
  bullet_list_icon: {
    color: Colors.vermilion,
    marginRight: Space.sm,
    fontSize: 16,
    lineHeight: 28,
  },
  blockquote: {
    backgroundColor: Colors.brandBg,
    borderLeftWidth: 2,
    borderLeftColor: Colors.vermilion,
    paddingHorizontal: Space.base,
    paddingVertical: Space.md,
    marginVertical: Space.md,
    borderRadius: Radius.xs,
  },
  hr: {
    backgroundColor: Colors.vermilion,
    height: 1,
    marginVertical: Space.md,
    opacity: 0.4,
  },
  code_inline: {
    backgroundColor: Colors.bgSecondary,
    fontFamily: 'Courier',
    paddingHorizontal: 4,
    borderRadius: 3,
  },
});
```

- [ ] **Step 3: 创建 RichContent.tsx —— 最小可用版**

```tsx
/**
 * AI 文本富文本渲染入口
 * 后续 Task 会在这里接入 preprocessYiji、YiJiCard、ClassicalQuote、MingPanBadge
 */
import React from 'react';
import Markdown from 'react-native-markdown-display';
import { richStyles } from './richStyles';

type Props = { content: string };

export function RichContent({ content }: Props) {
  return <Markdown style={richStyles}>{content}</Markdown>;
}
```

- [ ] **Step 4: TypeScript 编译检查**

Run: `npx tsc --noEmit`
Expected: 无新报错。

- [ ] **Step 5: 手测：在 insight.tsx 里临时接入一下，跑一下看能不能渲染**

先不全量替换，临时在 `app/(tabs)/insight.tsx` 的开头加 `import { RichContent } from '@/components/ai/RichContent';`，在某个 AI 气泡里把 `<Text style={styles.aiText}>{msg.content}</Text>` 换成 `<RichContent content={msg.content} />`。

跑：`npx expo run:ios --device 00008140-001262AE010A801C --configuration Release`

手机让 AI 答一段带 `## 标题` `**粗体**` `- 列表项` 的回复，确认渲染正常。验证完**把临时改动改回**（Task 8 再正式替换）。

- [ ] **Step 6: Commit**

```bash
git add package.json package-lock.json components/ai/RichContent.tsx components/ai/richStyles.ts
git commit -m "ai: 引入 react-native-markdown-display + 富文本渲染入口"
```

---

### Task 7：宜/忌 配对预扫描 + YiJiCard

**Files:**
- Create: `components/ai/customRules/preprocessYiji.ts`
- Create: `components/ai/customRules/YiJiCard.tsx`
- Create: `components/ai/customRules/__tests__/preprocessYiji.test.ts`
- Modify: `components/ai/RichContent.tsx`

- [ ] **Step 1: 先写 preprocessYiji 的失败测试**

创建 `components/ai/customRules/__tests__/preprocessYiji.test.ts`：

```ts
import { preprocessYiji } from '../preprocessYiji';

describe('preprocessYiji', () => {
  it('identifies a yi/ji pair on adjacent lines', () => {
    const input = '宜：静心、写字\n忌：争执、远行';
    const expected = '::yiji\nyi: 静心、写字\nji: 争执、远行\n::';
    expect(preprocessYiji(input)).toBe(expected);
  });

  it('identifies a yi/ji pair separated by blank line', () => {
    const input = '宜：静心\n\n忌：争执';
    const expected = '::yiji\nyi: 静心\nji: 争执\n::';
    expect(preprocessYiji(input)).toBe(expected);
  });

  it('accepts bolded markers', () => {
    const input = '**宜**：静心\n**忌**：争执';
    const expected = '::yiji\nyi: 静心\nji: 争执\n::';
    expect(preprocessYiji(input)).toBe(expected);
  });

  it('accepts ASCII colon', () => {
    const input = '宜: 静心\n忌: 争执';
    const expected = '::yiji\nyi: 静心\nji: 争执\n::';
    expect(preprocessYiji(input)).toBe(expected);
  });

  it('leaves a solo 宜 untouched', () => {
    const input = '今天宜：静心，没啥别的';
    expect(preprocessYiji(input)).toBe(input);
  });

  it('leaves unpaired 宜 without 忌 untouched', () => {
    const input = '宜：静心\n\n然后呢';
    expect(preprocessYiji(input)).toBe(input);
  });

  it('preserves surrounding text', () => {
    const input = '今天的建议：\n\n宜：静心\n忌：争执\n\n好好过一天。';
    const expected = '今天的建议：\n\n::yiji\nyi: 静心\nji: 争执\n::\n\n好好过一天。';
    expect(preprocessYiji(input)).toBe(expected);
  });
});
```

- [ ] **Step 2: 跑测试确认全部失败**

Run: `npm test -- preprocessYiji`
Expected: 所有 test FAIL with "Cannot find module '../preprocessYiji'"。

- [ ] **Step 3: 实现 preprocessYiji**

创建 `components/ai/customRules/preprocessYiji.ts`：

```ts
/**
 * 扫描原文，把"宜: ... / 忌: ..."配对替换为自定义 fence token `::yiji ... ::`
 *
 * 触发条件：
 *   - 一行形如 `(**)?宜(**)?[：:] 正文`
 *   - 紧接着（允许中间有空行）一行形如 `(**)?忌(**)?[：:] 正文`
 *
 * 不匹配单独出现的 宜 或 忌，也不匹配句中嵌套的"宜"。
 */
const YI_RE = /^(?:\*\*)?宜(?:\*\*)?[:：]\s*(.+)$/;
const JI_RE = /^(?:\*\*)?忌(?:\*\*)?[:：]\s*(.+)$/;

export function preprocessYiji(input: string): string {
  const lines = input.split('\n');
  const out: string[] = [];
  let i = 0;

  while (i < lines.length) {
    const yiMatch = lines[i].match(YI_RE);
    if (yiMatch) {
      // 往后找 忌（允许跨空行）
      let j = i + 1;
      while (j < lines.length && lines[j].trim() === '') j++;
      const jiMatch = j < lines.length ? lines[j].match(JI_RE) : null;

      if (jiMatch) {
        out.push('::yiji');
        out.push(`yi: ${yiMatch[1].trim()}`);
        out.push(`ji: ${jiMatch[1].trim()}`);
        out.push('::');
        i = j + 1;
        continue;
      }
    }
    out.push(lines[i]);
    i++;
  }

  return out.join('\n');
}
```

- [ ] **Step 4: 跑测试确认全部通过**

Run: `npm test -- preprocessYiji`
Expected: 所有 7 个 test PASS。

- [ ] **Step 5: 实现 YiJiCard 组件**

创建 `components/ai/customRules/YiJiCard.tsx`：

```tsx
/**
 * 宜 / 忌 双栏卡
 */
import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { Colors, Space, Radius, Type, Shadow } from '@/lib/design/tokens';

type Props = { yi: string[]; ji: string[] };

export function YiJiCard({ yi, ji }: Props) {
  return (
    <View style={[styles.card, Shadow.sm]}>
      <Column label="宜" items={yi} tone="good" />
      <View style={styles.divider} />
      <Column label="忌" items={ji} tone="bad" />
    </View>
  );
}

function Column({
  label, items, tone,
}: { label: string; items: string[]; tone: 'good' | 'bad' }) {
  const color = tone === 'good' ? Colors.celadon : Colors.vermilion;
  return (
    <View style={styles.col}>
      <Text style={[styles.label, { color }]}>{label}</Text>
      {items.map((it, i) => (
        <Text key={i} style={styles.item}>{it}</Text>
      ))}
    </View>
  );
}

/** 把 "静心、写字" / "静心，写字" 分词成 ["静心", "写字"] */
export function splitYiji(raw: string): string[] {
  return raw
    .split(/[、,，]/)
    .map(s => s.trim())
    .filter(Boolean);
}

const styles = StyleSheet.create({
  card: {
    flexDirection: 'row',
    backgroundColor: Colors.surface,
    borderRadius: Radius.lg,
    marginVertical: Space.md,
    overflow: 'hidden',
  },
  col: {
    flex: 1,
    padding: Space.base,
    gap: Space.xs,
    alignItems: 'center',
  },
  divider: {
    width: StyleSheet.hairlineWidth,
    backgroundColor: Colors.border,
  },
  label: {
    ...Type.label,
    fontWeight: '600',
    letterSpacing: 2,
    marginBottom: Space.xs,
  },
  item: {
    ...Type.body,
    color: Colors.ink,
  },
});
```

- [ ] **Step 6: 把 YiJiCard 接入 RichContent**

修改 `components/ai/RichContent.tsx`：

```tsx
import React from 'react';
import Markdown from 'react-native-markdown-display';
import { richStyles } from './richStyles';
import { preprocessYiji } from './customRules/preprocessYiji';
import { YiJiCard, splitYiji } from './customRules/YiJiCard';

type Props = { content: string };

export function RichContent({ content }: Props) {
  const processed = preprocessYiji(content);

  return (
    <Markdown
      style={richStyles}
      rules={{
        fence: (node: any) => {
          if (node.sourceInfo === 'yiji' || node.info === 'yiji') {
            const text: string = node.content || '';
            const yi = parseYi(text);
            const ji = parseJi(text);
            return <YiJiCard key={node.key} yi={yi} ji={ji} />;
          }
          return null;
        },
      }}
    >
      {processed}
    </Markdown>
  );
}

function parseYi(body: string): string[] {
  const m = body.match(/yi:\s*(.+)/);
  return m ? splitYiji(m[1]) : [];
}

function parseJi(body: string): string[] {
  const m = body.match(/ji:\s*(.+)/);
  return m ? splitYiji(m[1]) : [];
}
```

注：markdown-display 把 `::yiji\n...\n::` 这种 fence 风格解析到什么 node 里，取决于具体版本。上面 rule 里 `fence` 是标准的；如果实测该 lib 不把 `::` 当 fence（它主要是 ```` ``` ```` 三反引号才算），则需要 **改预处理把 fence 改成三反引号 + 语言标记**：`\`\`\`yiji\nyi: ...\nji: ...\n\`\`\``。第 8 步手测里会确认，如不渲染则回这里调整预处理。

- [ ] **Step 7: TypeScript 编译检查**

Run: `npx tsc --noEmit`
Expected: 无新报错。

- [ ] **Step 8: 手测**

```bash
npx expo run:ios --device 00008140-001262AE010A801C --configuration Release
```

让 AI 回答（可在聊天窗口直接问）"给我今天的宜和忌"，确认 AI 给出类似：
```
宜：静心、写字、整理
忌：争执、远行
```

应该看到一张横向双栏卡，左青瓷绿"宜"、右朱砂红"忌"。如果没渲染（只有纯文字），按 Step 6 备注把 `::yiji/::` 改成三反引号 fence 再试。

- [ ] **Step 9: Commit**

```bash
git add components/ai/customRules/ components/ai/RichContent.tsx
git commit -m "ai: 宜/忌 双栏卡渲染"
```

---

### Task 8：古文引用组件 + 落款解析

**Files:**
- Create: `components/ai/customRules/ClassicalQuote.tsx`
- Create: `components/ai/customRules/__tests__/parseAttribution.test.ts`
- Modify: `components/ai/RichContent.tsx`

- [ ] **Step 1: 写落款解析的失败测试**

创建 `components/ai/customRules/__tests__/parseAttribution.test.ts`：

```ts
import { parseAttribution } from '../ClassicalQuote';

describe('parseAttribution', () => {
  it('extracts —— 庄子 style attribution', () => {
    expect(parseAttribution('天行健\n——庄子')).toEqual({
      body: '天行健',
      attribution: '庄子',
    });
  });

  it('extracts —— 庄子《大宗师》', () => {
    expect(parseAttribution('夫大块载我以形\n—— 庄子《大宗师》')).toEqual({
      body: '夫大块载我以形',
      attribution: '庄子《大宗师》',
    });
  });

  it('leaves body without attribution alone', () => {
    expect(parseAttribution('海纳百川')).toEqual({
      body: '海纳百川',
      attribution: null,
    });
  });

  it('does not split on 《》 alone without ——', () => {
    expect(parseAttribution('我读了《道德经》')).toEqual({
      body: '我读了《道德经》',
      attribution: null,
    });
  });
});
```

- [ ] **Step 2: 跑测试确认全部失败**

Run: `npm test -- parseAttribution`
Expected: 所有 test FAIL。

- [ ] **Step 3: 实现 ClassicalQuote 组件 + parseAttribution**

创建 `components/ai/customRules/ClassicalQuote.tsx`：

```tsx
/**
 * 古文引用：升级版 blockquote，带可选落款
 */
import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { Colors, Space, Radius, Type, Shadow } from '@/lib/design/tokens';

/** 识别尾行形如 "—— xxx" 或 "——xxx" 的落款 */
export function parseAttribution(raw: string): { body: string; attribution: string | null } {
  const lines = raw.trim().split('\n');
  const last = lines[lines.length - 1]?.trim() ?? '';
  const m = last.match(/^——\s*(.+)$/);
  if (m) {
    return {
      body: lines.slice(0, -1).join('\n').trim(),
      attribution: m[1].trim(),
    };
  }
  return { body: raw.trim(), attribution: null };
}

type Props = { children: React.ReactNode; rawText: string };

export function ClassicalQuote({ rawText }: Props) {
  const { body, attribution } = parseAttribution(rawText);
  return (
    <View style={[styles.card, Shadow.sm]}>
      <Text style={styles.body}>{body}</Text>
      {attribution && (
        <>
          <View style={styles.divider} />
          <Text style={styles.attribution}>—— {attribution}</Text>
        </>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: Colors.brandBg,
    borderRadius: Radius.md,
    padding: Space.lg,
    marginVertical: Space.md,
  },
  body: {
    fontFamily: 'Georgia',
    fontSize: 16,
    lineHeight: 28,
    color: Colors.ink,
  },
  divider: {
    alignSelf: 'flex-end',
    width: 40,
    height: StyleSheet.hairlineWidth,
    backgroundColor: Colors.vermilion,
    opacity: 0.5,
    marginTop: Space.sm,
    marginBottom: 4,
  },
  attribution: {
    ...Type.caption,
    color: Colors.inkTertiary,
    textAlign: 'right',
  },
});
```

- [ ] **Step 4: 跑测试确认全部通过**

Run: `npm test -- parseAttribution`
Expected: 所有 4 个 test PASS。

- [ ] **Step 5: 在 RichContent 里接入 blockquote rule**

修改 `components/ai/RichContent.tsx`，在 `rules` 里添加 `blockquote` 规则（内联提取原文字符串）：

```tsx
import { ClassicalQuote } from './customRules/ClassicalQuote';

// ...在 rules 对象里加：
blockquote: (node: any, children: any, parent: any, styles: any) => {
  const raw = extractText(node);
  return <ClassicalQuote key={node.key} rawText={raw}>{children}</ClassicalQuote>;
},
```

并在 RichContent 文件里加 helper：

```tsx
function extractText(node: any): string {
  if (!node) return '';
  if (typeof node.content === 'string') return node.content;
  if (Array.isArray(node.children)) {
    return node.children.map(extractText).join('');
  }
  return '';
}
```

- [ ] **Step 6: TypeScript 编译 + 单测跑一次**

```bash
npx tsc --noEmit && npm test
```

Expected: 全部通过。

- [ ] **Step 7: 手测**

跑 App，让 AI 答一段带古文引用的回复，例如："请用一句经典概括这种状态，附上出处"。验证渲染：
- blockquote 背景变浅米色
- 正文用衬线字体
- 如有 `—— xxx` 出现，右下角有落款小字

- [ ] **Step 8: Commit**

```bash
git add components/ai/customRules/ClassicalQuote.tsx components/ai/customRules/__tests__/parseAttribution.test.ts components/ai/RichContent.tsx
git commit -m "ai: 古文引用卡片 + 落款解析"
```

---

### Task 9：命盘关键词徽章

**Files:**
- Create: `components/ai/customRules/keywords.ts`
- Create: `components/ai/customRules/MingPanBadge.tsx`
- Create: `components/ai/customRules/__tests__/keywords.test.ts`
- Modify: `components/ai/RichContent.tsx`

- [ ] **Step 1: 写关键词扫描的失败测试**

创建 `components/ai/customRules/__tests__/keywords.test.ts`：

```ts
import { splitIntoKeywordSegments } from '../keywords';

describe('splitIntoKeywordSegments', () => {
  it('finds 日主 in middle of a sentence', () => {
    const segs = splitIntoKeywordSegments('你的日主是庚金');
    expect(segs).toEqual([
      { text: '你的', isKeyword: false },
      { text: '日主', isKeyword: true },
      { text: '是庚金', isKeyword: false },
    ]);
  });

  it('finds multiple keywords in one string', () => {
    const segs = splitIntoKeywordSegments('用神为水，喜神为金');
    expect(segs.filter(s => s.isKeyword).map(s => s.text)).toEqual(['用神', '喜神']);
  });

  it('does NOT match 金 as five-element inside 金色', () => {
    const segs = splitIntoKeywordSegments('夕阳金色');
    expect(segs.some(s => s.isKeyword)).toBe(false);
  });

  it('does match 金 as five-element when surrounded by punctuation', () => {
    const segs = splitIntoKeywordSegments('你属金，适合收敛');
    expect(segs.filter(s => s.isKeyword).map(s => s.text)).toContain('金');
  });

  it('returns whole string as non-keyword when no match', () => {
    const segs = splitIntoKeywordSegments('今天天气真好');
    expect(segs).toEqual([{ text: '今天天气真好', isKeyword: false }]);
  });
});
```

- [ ] **Step 2: 跑测试确认全部失败**

Run: `npm test -- keywords`
Expected: 所有 test FAIL。

- [ ] **Step 3: 实现 keywords.ts**

创建 `components/ai/customRules/keywords.ts`：

```ts
/**
 * 命盘关键词扫描，支持徽章化显示
 */

const SHI_SHEN = [
  '日主', '正官', '七杀', '正印', '偏印',
  '正财', '偏财', '食神', '伤官', '比肩', '劫财',
];

const MING_LI = ['用神', '喜神', '忌神', '格局'];

const WU_XING = ['木', '火', '土', '金', '水'];

export type Segment = { text: string; isKeyword: boolean };

/**
 * 把一段文本分成若干片段，每个片段要么是关键词，要么不是
 *
 * 规则：
 *  - 十神 / 命理 术语直接匹配（它们几乎不会误中）
 *  - 五行单字只在"前后非汉字"时匹配（避免 金色 / 水果 等假阳性）
 */
export function splitIntoKeywordSegments(text: string): Segment[] {
  const regex = buildKeywordRegex();
  const result: Segment[] = [];
  let lastIndex = 0;

  for (const match of text.matchAll(regex)) {
    const idx = match.index!;
    if (idx > lastIndex) {
      result.push({ text: text.slice(lastIndex, idx), isKeyword: false });
    }
    result.push({ text: match[0], isKeyword: true });
    lastIndex = idx + match[0].length;
  }

  if (lastIndex < text.length) {
    result.push({ text: text.slice(lastIndex), isKeyword: false });
  }

  return result.length ? result : [{ text, isKeyword: false }];
}

function buildKeywordRegex(): RegExp {
  const phrases = [...SHI_SHEN, ...MING_LI];
  const phrasePart = phrases.join('|');
  // 五行单字：前后必须非汉字（用 lookarounds）
  const wuxingPart = `(?<![\\u4e00-\\u9fff])(?:${WU_XING.join('|')})(?![\\u4e00-\\u9fff])`;
  return new RegExp(`${phrasePart}|${wuxingPart}`, 'g');
}
```

- [ ] **Step 4: 跑测试确认全部通过**

Run: `npm test -- keywords`
Expected: 所有 5 个 test PASS。

- [ ] **Step 5: 实现 MingPanBadge 组件**

创建 `components/ai/customRules/MingPanBadge.tsx`：

```tsx
/**
 * 命盘关键词行内徽章
 */
import React from 'react';
import { Text, StyleSheet } from 'react-native';
import { Colors, Type, Radius } from '@/lib/design/tokens';

type Props = { children: React.ReactNode };

export function MingPanBadge({ children }: Props) {
  return <Text style={styles.badge}>{children}</Text>;
}

const styles = StyleSheet.create({
  badge: {
    ...Type.bodySmall,
    color: Colors.vermilion,
    backgroundColor: Colors.brandBg,
    paddingHorizontal: 6,
    paddingVertical: 1,
    borderRadius: Radius.xs,
    overflow: 'hidden',
  },
});
```

注：React Native 的 inline `<Text>` 背景要靠嵌套 Text 实现，`overflow: 'hidden'` 在 inline 场景下 iOS 有效、Android 可能需要降级。

- [ ] **Step 6: 在 RichContent 里接入 text rule 用 MingPanBadge**

修改 `components/ai/RichContent.tsx`，在 rules 对象里加：

```tsx
import { splitIntoKeywordSegments } from './customRules/keywords';
import { MingPanBadge } from './customRules/MingPanBadge';

// ...
text: (node: any, children: any, parent: any, styles: any) => {
  const raw = node.content as string;
  const segments = splitIntoKeywordSegments(raw);
  return (
    <Text key={node.key} style={styles.text}>
      {segments.map((seg, i) =>
        seg.isKeyword
          ? <MingPanBadge key={i}>{seg.text}</MingPanBadge>
          : seg.text
      )}
    </Text>
  );
},
```

- [ ] **Step 7: 编译 + 单测**

```bash
npx tsc --noEmit && npm test
```

Expected: 全部通过。

- [ ] **Step 8: 手测**

跑 App，让 AI 解读八字，例如："用我的命盘给我一个忠告"。验证：
- 正文中出现 `日主 / 用神 / 喜神 / 忌神` 的地方都被小胶囊包住
- "夕阳金色"里的"金"不会被误识别

- [ ] **Step 9: Commit**

```bash
git add components/ai/customRules/keywords.ts components/ai/customRules/MingPanBadge.tsx components/ai/customRules/__tests__/keywords.test.ts components/ai/RichContent.tsx
git commit -m "ai: 命盘关键词行内徽章"
```

---

### Task 10：正式接入 RichContent 替换所有 AI 气泡

**Files:**
- Modify: `app/(tabs)/insight.tsx`

- [ ] **Step 1: 加 import**

在 `app/(tabs)/insight.tsx` 的 import 段落加：

```tsx
import { RichContent } from '@/components/ai/RichContent';
```

- [ ] **Step 2: 替换已定型消息的 AI 气泡**

找到 messages 渲染循环里的：

```tsx
) : (
  <View key={i} style={[styles.aiBubble, Shadow.sm]}>
    <Text style={styles.aiName}>岁吉</Text>
    <Text style={styles.aiText}>{msg.content}</Text>
  </View>
)
```

改成：

```tsx
) : (
  <View key={i} style={[styles.aiBubble, Shadow.sm]}>
    <Text style={styles.aiName}>岁吉</Text>
    <RichContent content={msg.content} />
  </View>
)
```

- [ ] **Step 3: 替换流式气泡**

找到 streamingText 那段：

```tsx
{streamingText ? (
  <View style={[styles.aiBubble, Shadow.sm]}>
    <Text style={styles.aiName}>岁吉</Text>
    <Text style={styles.aiText}>
      {streamingText}
      <StreamCursor />
    </Text>
  </View>
) : null}
```

改成：

```tsx
{streamingText ? (
  <View style={[styles.aiBubble, Shadow.sm]}>
    <Text style={styles.aiName}>岁吉</Text>
    <RichContent content={streamingText} />
    <StreamCursor />
  </View>
) : null}
```

注意 StreamCursor 从 RichContent 内部提出来（独立一行），因为 markdown-display 渲染的是 block-level 结构，光标放在文本末尾不再可靠；改放气泡底部。

- [ ] **Step 4: 替换欢迎消息（可选但一致）**

找到：

```tsx
<Text style={styles.aiText}>
  {store.mingPanCache
    ? '你的命盘已就绪。...'
    : '有什么想聊的？...'}
</Text>
```

改成：

```tsx
<RichContent content={
  store.mingPanCache
    ? '你的命盘已就绪。有什么想聊的？\n可以跟我说说你现在的心情。'
    : '有什么想聊的？\n输入生辰后，对话会更贴合你。'
} />
```

- [ ] **Step 5: 编译**

Run: `npx tsc --noEmit`
Expected: 无新报错。

- [ ] **Step 6: 全量手测**

```bash
npx expo run:ios --device 00008140-001262AE010A801C --configuration Release
```

- 清除对话
- 发一条测试消息："给我讲讲用神、喜神、忌神的区别，并给我今天的宜忌，最后引用一句庄子的话"
- 观察：markdown 渲染、宜/忌 卡、古文引用、关键词徽章**同时**出现，不冲突
- 再发一条，观察**流式光标**是否正常工作，markdown 是否实时渲染

- [ ] **Step 7: Commit**

```bash
git add app/\(tabs\)/insight.tsx
git commit -m "chat: AI 气泡全量接入富文本渲染"
```

---

## Module 1：时辰能量轴

### Task 11：抽 dayOfYear 到共享工具

**为什么**：时辰轴的动词选择用到 `dayOfYear(date)`，现在这个算法埋在 `lib/bazi/TrueSolarTime.ts` 里。抽到共享 `lib/utils/date.ts` 复用。

**Files:**
- Create: `lib/utils/date.ts`
- Create: `lib/utils/__tests__/date.test.ts`
- Modify: `lib/bazi/TrueSolarTime.ts`

- [ ] **Step 1: 写 dayOfYear 测试**

创建 `lib/utils/__tests__/date.test.ts`：

```ts
import { dayOfYear } from '../date';

describe('dayOfYear', () => {
  it('returns 1 for Jan 1', () => {
    expect(dayOfYear(new Date(2026, 0, 1))).toBe(1);
  });

  it('returns 32 for Feb 1', () => {
    expect(dayOfYear(new Date(2026, 1, 1))).toBe(32);
  });

  it('returns 365 for Dec 31 non-leap year', () => {
    expect(dayOfYear(new Date(2026, 11, 31))).toBe(365);
  });

  it('returns 366 for Dec 31 leap year', () => {
    expect(dayOfYear(new Date(2024, 11, 31))).toBe(366);
  });
});
```

- [ ] **Step 2: 跑测试确认失败**

Run: `npm test -- date`
Expected: FAIL with "Cannot find module"。

- [ ] **Step 3: 实现 dayOfYear**

创建 `lib/utils/date.ts`：

```ts
/**
 * Day-of-year（1–366），本地时区。
 */
export function dayOfYear(date: Date): number {
  const start = new Date(date.getFullYear(), 0, 0);
  const diff = date.getTime() - start.getTime();
  return Math.floor(diff / 86400000);
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `npm test -- date`
Expected: 全部 PASS。

- [ ] **Step 5: 让 TrueSolarTime.ts 复用**

修改 `lib/bazi/TrueSolarTime.ts`，在顶部 import：

```ts
import { dayOfYear } from '@/lib/utils/date';
```

然后把文件内原先的 dayOfYear 算法那一行替换为 `const dayOfYear = dayOfYear(date);` —— **但要改名避免冲突**：

```ts
const doy = dayOfYear(date);
const B = ((2 * Math.PI) / 365) * (doy - 81);
```

（把文件内原先定义 dayOfYear 的那一行删掉，其他引用改名。）

- [ ] **Step 6: 编译 + 单测**

```bash
npx tsc --noEmit && npm test
```

Expected: 全部通过。

- [ ] **Step 7: Commit**

```bash
git add lib/utils/ lib/bazi/TrueSolarTime.ts
git commit -m "util: 抽取 dayOfYear 到共享工具"
```

---

### Task 12：SHICHEN_MAP 静态数据 + computeShichenVibe

**Files:**
- Create: `lib/calendar/shichen.ts`
- Create: `lib/calendar/__tests__/shichen.test.ts`

- [ ] **Step 1: 先写 computeShichenVibe 的测试**

创建 `lib/calendar/__tests__/shichen.test.ts`：

```ts
import { SHICHEN_MAP, computeShichenVibe, currentShichenIndex } from '../shichen';
import type { MingPanSummary } from '../shichen';

describe('SHICHEN_MAP', () => {
  it('has exactly 12 entries', () => {
    expect(SHICHEN_MAP).toHaveLength(12);
  });

  it('starts with 子 ending with 亥', () => {
    expect(SHICHEN_MAP[0].zhi).toBe('子');
    expect(SHICHEN_MAP[11].zhi).toBe('亥');
  });
});

describe('computeShichenVibe', () => {
  const mp = (yongShen: any, xiShen: any, jiShen: any): MingPanSummary => ({
    yongShen, xiShen, jiShen,
  });

  it('returns 旺 for 用神 match with strong suitable verb', () => {
    const date = new Date(2026, 0, 1);
    // 寅时 五行是 木
    const entry = SHICHEN_MAP.find(s => s.zhi === '寅')!;
    const vibe = computeShichenVibe(entry, mp('木', '水', '金'), date);
    expect(vibe.level).toBe('旺');
    expect(['行动', '开启', '进取', '谈判']).toContain(vibe.suitable);
  });

  it('returns 弱 for 忌神 match with recessive verb', () => {
    const date = new Date(2026, 0, 1);
    const entry = SHICHEN_MAP.find(s => s.zhi === '寅')!;
    const vibe = computeShichenVibe(entry, mp('土', '火', '木'), date);
    expect(vibe.level).toBe('弱');
    expect(['静心', '休整', '独处', '观照']).toContain(vibe.suitable);
  });

  it('returns 平 with default suitable when no match', () => {
    const date = new Date(2026, 0, 1);
    const entry = SHICHEN_MAP.find(s => s.zhi === '寅')!;
    const vibe = computeShichenVibe(entry, mp('土', '水', '金'), date);
    expect(vibe.level).toBe('平');
    expect(vibe.suitable).toBe(entry.defaultSuitable);
  });

  it('returns deterministic suitable for same date', () => {
    const date = new Date(2026, 0, 1);
    const entry = SHICHEN_MAP[0];
    const a = computeShichenVibe(entry, mp('水', '木', '火'), date);
    const b = computeShichenVibe(entry, mp('水', '木', '火'), date);
    expect(a.suitable).toBe(b.suitable);
  });
});

describe('currentShichenIndex', () => {
  it('maps 03:30 to 寅 (index 2)', () => {
    const d = new Date();
    d.setHours(3, 30, 0, 0);
    expect(currentShichenIndex(d)).toBe(2);
  });

  it('maps 23:30 to 子 (index 0)', () => {
    const d = new Date();
    d.setHours(23, 30, 0, 0);
    expect(currentShichenIndex(d)).toBe(0);
  });

  it('maps 00:30 to 子 (index 0)', () => {
    const d = new Date();
    d.setHours(0, 30, 0, 0);
    expect(currentShichenIndex(d)).toBe(0);
  });
});
```

- [ ] **Step 2: 跑测试确认失败**

Run: `npm test -- shichen`
Expected: FAIL with "Cannot find module"。

- [ ] **Step 3: 实现 shichen.ts**

创建 `lib/calendar/shichen.ts`：

```ts
/**
 * 时辰能量轴核心模块
 */
import { dayOfYear } from '@/lib/utils/date';

export type DiZhi = '子' | '丑' | '寅' | '卯' | '辰' | '巳' | '午' | '未' | '申' | '酉' | '戌' | '亥';
export type WuXing = '木' | '火' | '土' | '金' | '水';
export type EnergyLevel = '旺' | '平' | '弱';

export type ShichenEntry = {
  zhi: DiZhi;
  hours: string;            // '23–01'
  image: string;            // 两字意象，如 '夜藏'
  poem: string;             // ≤8 字
  generalWuXing: WuXing;
  defaultSuitable: string;  // 无个性化时的建议，2–4 字动词短语
};

export type MingPanSummary = {
  yongShen: WuXing;
  xiShen: WuXing;
  jiShen: WuXing;
};

export type ShichenVibe = {
  level: EnergyLevel;
  suitable: string;
};

export const SHICHEN_MAP: ShichenEntry[] = [
  { zhi: '子', hours: '23–01', image: '夜藏', poem: '万物归元', generalWuXing: '水', defaultSuitable: '入眠' },
  { zhi: '丑', hours: '01–03', image: '沉静', poem: '土凝寒气', generalWuXing: '土', defaultSuitable: '深睡' },
  { zhi: '寅', hours: '03–05', image: '苏醒', poem: '万物萌动', generalWuXing: '木', defaultSuitable: '静思' },
  { zhi: '卯', hours: '05–07', image: '日出', poem: '生气勃发', generalWuXing: '木', defaultSuitable: '晨起' },
  { zhi: '辰', hours: '07–09', image: '勤奋', poem: '日精正升', generalWuXing: '土', defaultSuitable: '专注' },
  { zhi: '巳', hours: '09–11', image: '昂扬', poem: '阳气渐盛', generalWuXing: '火', defaultSuitable: '行动' },
  { zhi: '午', hours: '11–13', image: '鼎沸', poem: '阳极将衰', generalWuXing: '火', defaultSuitable: '休整' },
  { zhi: '未', hours: '13–15', image: '和缓', poem: '土厚载物', generalWuXing: '土', defaultSuitable: '沟通' },
  { zhi: '申', hours: '15–17', image: '收敛', poem: '金气渐锋', generalWuXing: '金', defaultSuitable: '决断' },
  { zhi: '酉', hours: '17–19', image: '归栖', poem: '日落金收', generalWuXing: '金', defaultSuitable: '复盘' },
  { zhi: '戌', hours: '19–21', image: '安宁', poem: '暮土藏火', generalWuXing: '土', defaultSuitable: '陪伴' },
  { zhi: '亥', hours: '21–23', image: '归藏', poem: '水润归源', generalWuXing: '水', defaultSuitable: '静读' },
];

const STRONG_VERBS   = ['行动', '开启', '进取', '谈判'];
const NEUTRAL_VERBS  = ['沟通', '书写', '学习', '整理'];
const RECESSIVE_VERBS = ['静心', '休整', '独处', '观照'];

/** 结合命盘、日子计算某时辰的能量和建议 */
export function computeShichenVibe(
  entry: ShichenEntry,
  mingPan: MingPanSummary,
  date: Date,
): ShichenVibe {
  const wx = entry.generalWuXing;
  const doy = dayOfYear(date);

  if (wx === mingPan.yongShen) {
    return { level: '旺', suitable: STRONG_VERBS[doy % STRONG_VERBS.length] };
  }
  if (wx === mingPan.xiShen) {
    return { level: '旺', suitable: NEUTRAL_VERBS[doy % NEUTRAL_VERBS.length] };
  }
  if (wx === mingPan.jiShen) {
    return { level: '弱', suitable: RECESSIVE_VERBS[doy % RECESSIVE_VERBS.length] };
  }
  return { level: '平', suitable: entry.defaultSuitable };
}

/**
 * 返回当前时刻对应的 SHICHEN_MAP 索引（0–11）
 * 子时 = 23:00–01:00，跨日，统一映射到 index 0
 */
export function currentShichenIndex(date: Date): number {
  const h = date.getHours();
  // 23:00–00:59 → 子 (0)
  if (h === 23 || h === 0) return 0;
  // 01:00–02:59 → 丑 (1), 03:00–04:59 → 寅 (2), ...
  return Math.floor((h + 1) / 2);
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `npm test -- shichen`
Expected: 全部 PASS。

- [ ] **Step 5: Commit**

```bash
git add lib/calendar/shichen.ts lib/calendar/__tests__/shichen.test.ts
git commit -m "calendar: 时辰静态表 + 个性化 vibe 计算"
```

---

### Task 13：ShichenCard 组件

**Files:**
- Create: `components/calendar/ShichenCard.tsx`

- [ ] **Step 1: 创建单卡组件**

```tsx
/**
 * 时辰单卡
 */
import React from 'react';
import { View, Text, Pressable, StyleSheet } from 'react-native';
import { Colors, Space, Radius, Type, Shadow } from '@/lib/design/tokens';
import type { ShichenEntry, ShichenVibe, EnergyLevel } from '@/lib/calendar/shichen';

type Props = {
  entry: ShichenEntry;
  vibe: ShichenVibe;
  active: boolean;          // 是否当前时辰
  onPress: () => void;
};

export function ShichenCard({ entry, vibe, active, onPress }: Props) {
  return (
    <Pressable
      onPress={onPress}
      style={[styles.card, active && styles.cardActive, Shadow.sm]}
    >
      {active && <View style={styles.marker} />}
      <Text style={[styles.zhi, active && styles.zhiActive]}>{entry.zhi}</Text>
      <Text style={styles.hours}>{entry.hours}</Text>

      <View style={styles.divider} />

      <Text style={[styles.image, active && styles.imageActive]}>{entry.image}</Text>
      <Text style={styles.poem}>{entry.poem}</Text>

      <View style={styles.divider} />

      <View style={styles.levelRow}>
        <View style={[styles.levelDot, { backgroundColor: levelColor(vibe.level) }]} />
        <Text style={styles.levelText}>{vibe.level}</Text>
      </View>

      <Text style={styles.suitable} numberOfLines={1}>宜 · {vibe.suitable}</Text>
    </Pressable>
  );
}

function levelColor(level: EnergyLevel): string {
  if (level === '旺') return Colors.celadon;
  if (level === '弱') return Colors.vermilion;
  return Colors.inkHint;
}

const styles = StyleSheet.create({
  card: {
    width: 110,
    height: 150,
    backgroundColor: Colors.surface,
    borderRadius: Radius.lg,
    padding: Space.sm,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: Space.sm,
  },
  cardActive: {
    width: 130,
    height: 170,
    backgroundColor: Colors.brandBg,
  },
  marker: {
    position: 'absolute',
    top: 4,
    alignSelf: 'center',
    width: 0, height: 0,
    borderLeftWidth: 4, borderRightWidth: 4, borderBottomWidth: 5,
    borderLeftColor: 'transparent', borderRightColor: 'transparent',
    borderBottomColor: Colors.vermilion,
  },
  zhi: {
    fontFamily: 'Georgia', fontSize: 36,
    color: Colors.ink, fontWeight: '300', lineHeight: 40,
  },
  zhiActive: { fontSize: 40 },
  hours: { ...Type.caption, color: Colors.inkTertiary, marginTop: 2 },
  divider: {
    width: '60%', height: StyleSheet.hairlineWidth,
    backgroundColor: Colors.border, marginVertical: Space.xs,
  },
  image: { fontSize: 18, color: Colors.ink, fontWeight: '500' },
  imageActive: { fontSize: 20 },
  poem: { ...Type.bodySmall, color: Colors.inkSecondary, marginTop: 2 },
  levelRow: { flexDirection: 'row', alignItems: 'center', gap: 4 },
  levelDot: { width: 6, height: 6, borderRadius: 3 },
  levelText: { ...Type.caption, color: Colors.inkTertiary },
  suitable: {
    ...Type.caption, color: Colors.vermilion, marginTop: 4, fontWeight: '500',
  },
});
```

- [ ] **Step 2: 编译**

Run: `npx tsc --noEmit`
Expected: 无新报错。

- [ ] **Step 3: Commit**

```bash
git add components/calendar/ShichenCard.tsx
git commit -m "calendar: 时辰单卡组件"
```

---

### Task 14：ShichenDetailSheet 组件

**Files:**
- Create: `components/calendar/ShichenDetailSheet.tsx`

- [ ] **Step 1: 创建详情抽屉**

```tsx
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
              <Text style={styles.body}>{personalizedBlurb(entry, vibe, mingPan)}</Text>
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

function personalizedBlurb(entry: ShichenEntry, vibe: ShichenVibe, mp: MingPanSummary): string {
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
```

- [ ] **Step 2: 编译**

Run: `npx tsc --noEmit`
Expected: 无新报错。

- [ ] **Step 3: Commit**

```bash
git add components/calendar/ShichenDetailSheet.tsx
git commit -m "calendar: 时辰详情抽屉"
```

---

### Task 15：ShichenTimeline 主组件 + 接入首页

**Files:**
- Create: `components/calendar/ShichenTimeline.tsx`
- Modify: `app/(tabs)/index.tsx`

- [ ] **Step 1: 创建 ShichenTimeline**

```tsx
/**
 * 首页时辰能量轴：横向滑动 + 自动居中当前时辰 + 点击展开详情
 * 仅在用户已配生辰（mingPanCache 存在）时渲染；否则返回 null
 */
import React, { useMemo, useState, useRef, useEffect } from 'react';
import { View, Text, FlatList, Dimensions, StyleSheet } from 'react-native';
import { Colors, Space, Type } from '@/lib/design/tokens';
import { useUserStore } from '@/lib/store/userStore';
import {
  SHICHEN_MAP, computeShichenVibe, currentShichenIndex,
  type ShichenEntry, type ShichenVibe, type MingPanSummary,
} from '@/lib/calendar/shichen';
import { ShichenCard } from './ShichenCard';
import { ShichenDetailSheet } from './ShichenDetailSheet';

const SCREEN_W = Dimensions.get('window').width;
const CARD_W_NORMAL = 110 + 8;   // 卡宽 + marginRight
const CARD_W_ACTIVE = 130 + 8;

export function ShichenTimeline() {
  const { mingPanCache } = useUserStore();
  const mp = useMemo(() => parseMingPan(mingPanCache), [mingPanCache]);
  if (!mp) return null;

  const [detailIdx, setDetailIdx] = useState<number | null>(null);
  const listRef = useRef<FlatList<ShichenEntry>>(null);
  const now = useMemo(() => new Date(), []);
  const currentIdx = currentShichenIndex(now);

  // 每张卡的 vibe
  const vibes = useMemo<ShichenVibe[]>(
    () => SHICHEN_MAP.map(e => computeShichenVibe(e, mp, now)),
    [mp, now],
  );

  // 自动居中当前卡
  useEffect(() => {
    const t = setTimeout(() => {
      // 把当前卡中心对齐屏幕中心
      const beforeWidth = currentIdx * CARD_W_NORMAL;
      const offset = beforeWidth - (SCREEN_W - CARD_W_ACTIVE) / 2;
      listRef.current?.scrollToOffset({ offset: Math.max(0, offset), animated: true });
    }, 300);
    return () => clearTimeout(t);
  }, [currentIdx]);

  const detailEntry = detailIdx != null ? SHICHEN_MAP[detailIdx] : null;
  const detailVibe  = detailIdx != null ? vibes[detailIdx] : null;

  return (
    <View style={styles.container}>
      <Text style={styles.sectionTitle}>时辰能量</Text>

      <FlatList
        ref={listRef}
        data={SHICHEN_MAP}
        keyExtractor={e => e.zhi}
        horizontal
        showsHorizontalScrollIndicator={false}
        contentContainerStyle={styles.listContent}
        renderItem={({ item, index }) => (
          <ShichenCard
            entry={item}
            vibe={vibes[index]}
            active={index === currentIdx}
            onPress={() => setDetailIdx(index)}
          />
        )}
      />

      <ShichenDetailSheet
        visible={detailIdx != null}
        entry={detailEntry}
        vibe={detailVibe}
        mingPan={mp}
        onClose={() => setDetailIdx(null)}
      />
    </View>
  );
}

function parseMingPan(json: string | null): MingPanSummary | null {
  if (!json) return null;
  try {
    const p = JSON.parse(json);
    const ys = p.wuXingStrength?.yongShen;
    const xs = p.wuXingStrength?.xiShen;
    const js = p.wuXingStrength?.jiShen;
    if (!ys || !xs || !js) return null;
    return { yongShen: ys, xiShen: xs, jiShen: js };
  } catch {
    return null;
  }
}

const styles = StyleSheet.create({
  container: {
    marginTop: Space['2xl'],
  },
  sectionTitle: {
    ...Type.label,
    color: Colors.inkTertiary,
    letterSpacing: 2,
    marginBottom: Space.base,
    marginHorizontal: Space.lg,
  },
  listContent: {
    paddingHorizontal: Space.lg,
    paddingVertical: Space.xs,
  },
});
```

- [ ] **Step 2: 替换首页现有的十二时辰代码**

修改 `app/(tabs)/index.tsx`：

1. 顶部 import 加：

```tsx
import { ShichenTimeline } from '@/components/calendar/ShichenTimeline';
```

2. 找到 `{/* ── 十二时辰 ── */}` 这一段（约 153–174 行）：

```tsx
{/* ── 十二时辰 ── */}
<View style={styles.hoursArea}>
  <Text style={styles.sectionTitle}>十二时辰</Text>
  <View style={styles.hoursGrid}>
    {SHICHEN.map((zhi, i) => {
      // ...
    })}
  </View>
</View>
```

整段替换为：

```tsx
<ShichenTimeline />
```

3. 顶部原先 `SHICHEN`、`SHICHEN_TIME`、`goodHours` 相关的 import 和变量如果不再被其他地方用到，一并删除（使用 `grep` 确认）。

4. styles 里的 `hoursArea`、`sectionTitle`（如果独占）、`hoursGrid`、`hourCell`、`hourCellGood`、`hourZhi`、`hourZhiGood`、`hourTime`、`hourTimeGood` 删除。

- [ ] **Step 3: 编译**

Run: `npx tsc --noEmit`
Expected: 无新报错。如报"unused import"的静态告警，按上一步说明的清理办法处理。

- [ ] **Step 4: 手测**

```bash
npx expo run:ios --device 00008140-001262AE010A801C --configuration Release
```

**如果当前账户没有生辰**：
- 验证首页 **不显示**时辰轴（不占位、不报错）
- 如果你想看效果，临时用一个 mock：在 `index.tsx` 里临时 hardcode mingPan，看一下，验证完删掉

**如果当前账户有生辰**：
- 首页底部出现横向时辰轴
- 打开时**自动滚到当前时辰**，当前卡更大、背景偏朱砂色、顶部有朱砂小三角
- 左右滑能看到全部 12 时辰
- 每张卡的"宜"动词**同一天保持稳定**（可以关掉 App 再开一次验证）
- 点任意卡弹出半屏抽屉，内容正确；有命盘的用户能看到"对你来说"段落
- 抽屉下拉或点关闭都能收起

- [ ] **Step 5: Commit**

```bash
git add components/calendar/ShichenTimeline.tsx app/\(tabs\)/index.tsx
git commit -m "calendar: 首页替换为个性化时辰能量轴"
```

---

## 收尾：完整回归 + Push

### Task 16：跨模块回归手测

- [ ] **Step 1: 同时触发 3 个模块的场景**

- 发一条："告诉我今天的宜忌，再引用一句古诗，最后解读下我的用神"
- 观察：
  - 流式光标跳动（Module 2 OK）
  - markdown 标题/粗体/列表渲染（Module 3 Level 1 OK）
  - 宜/忌 卡出现（Module 3 Level 2 OK）
  - blockquote 变成古文卡 + 落款（Module 3 Level 2 OK）
  - "用神" 等关键词变徽章（Module 3 Level 2 OK）
- 切到日历 tab，**时辰轴正常、滚动顺畅、点击抽屉弹出**（Module 1 OK）

- [ ] **Step 2: 单测全跑**

Run: `npm test`
Expected: 全部 PASS。

- [ ] **Step 3: TypeScript 全检**

Run: `npx tsc --noEmit`
Expected: 无新报错。

- [ ] **Step 4: 推到远端（可选）**

```bash
git push
```

---

## 开放问题 / 如果撞到坑

1. **markdown-display 与 RN 0.81 兼容性** —— Task 6 验证。如果 `react-native-markdown-display` 在 New Architecture 下有问题，备选 `@ronradtke/react-native-markdown-display`（社区 fork，活跃维护）。两者都不行则换 `react-native-marked`（基于 `marked` 解析器 + 自己的 renderer，API 不同）。接入点 `<RichContent>` 保持不变。

2. **宜/忌 fence 语法** —— markdown-display 对 `::yiji/::` 这种非标 fence 是否识别取决于版本。Task 7 Step 6 的注里写了回退方案：改预处理输出成三反引号带语言标记的 fence。

3. **行内文本 background 在 Android 的表现** —— `MingPanBadge` 的 `backgroundColor` + `overflow: hidden` 在 iOS 稳定、Android 可能需要降级到无圆角或改用 View 包裹。初期只关心 iOS，Android 问题先记账。

4. **时辰轴自动居中首次渲染闪跳** —— 如果 `scrollToOffset` 在 FlatList 初始化前触发导致看到闪动，改用 `initialScrollIndex` + `getItemLayout` 更稳，但这两者又和"当前卡宽度不一致"冲突。折中：首次用 `scrollToOffset` 延迟 300ms（Task 15 实现版），视觉可接受即不动；真闪则改为全卡统一宽度 + 只改背景色。
