import type { AIRunner } from './CalibrationSession';

export const CALIBRATION_SYSTEM_PROMPT = `你是命理师，正在用过去事件帮用户校准出生时辰。

每轮我会给你一个事件模板和年份。你的任务：

1. 如果有上一轮的用户答案，先把它归类：
   - "yes"：用户明确说发生过
   - "no"：用户明确说没有发生
   - "uncertain"：用户说不记得 / 不知道 / 含糊 / 模棱两可
2. 把新模板改写成 1-2 句自然问句。不要解释命盘原理，不要说"根据您的命盘"，直接问事件，温和但不啰嗦。

返回严格的 JSON 格式：
{"lastClassification": "yes" | "no" | "uncertain" | null, "question": "<你的问句>"}

首轮（没有用户答案）的 lastClassification 必须为 null。`;

interface AIOutput {
  lastClassification?: 'yes' | 'no' | 'uncertain';
  question: string;
}

export function parseAIResponse(raw: string, fallbackTemplate: string): AIOutput {
  try {
    const obj = JSON.parse(raw);
    const cls = obj.lastClassification;
    const question = typeof obj.question === 'string' && obj.question.length > 0
      ? obj.question
      : fallbackTemplate;
    if (cls === null || cls === undefined) {
      return { lastClassification: undefined, question };
    }
    if (cls === 'yes' || cls === 'no' || cls === 'uncertain') {
      return { lastClassification: cls, question };
    }
    // 未知枚举 → uncertain
    return { lastClassification: 'uncertain', question };
  } catch {
    return { lastClassification: 'uncertain', question: fallbackTemplate };
  }
}

interface ProviderConfig {
  provider: 'openai' | 'deepseek' | 'anthropic' | 'custom';
  baseUrl: string;
  apiKey: string;
  model: string;
}

function defaultBaseUrl(p: 'openai' | 'deepseek' | 'anthropic' | 'custom'): string {
  switch (p) {
    case 'openai': return 'https://api.openai.com/v1';
    case 'deepseek': return 'https://api.deepseek.com/v1';
    case 'anthropic': return 'https://api.anthropic.com/v1';
    case 'custom': return '';
  }
}

function readProviderConfig(): ProviderConfig | null {
  // 懒加载 userStore：模块加载需要 RN 的 AsyncStorage，jest 单测不进入 runRound 即不触发
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const { useUserStore } = require('@/lib/store/userStore') as typeof import('@/lib/store/userStore');
  const u = useUserStore.getState();
  if (!u.apiProvider || !u.apiKey || !u.apiModel) return null;
  const baseUrl = u.apiBaseUrl ?? defaultBaseUrl(u.apiProvider);
  return {
    provider: u.apiProvider,
    baseUrl,
    apiKey: u.apiKey,
    model: u.apiModel,
  };
}

async function callOnce(cfg: ProviderConfig, userMsg: string): Promise<string> {
  // 懒加载 expo/fetch：模块加载需要 RN 运行时，jest 单测里只要不进入 callOnce 就不会触发
  const { fetch: expoFetch } = await import('expo/fetch');
  const url = `${cfg.baseUrl.replace(/\/$/, '')}/chat/completions`;
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${cfg.apiKey}`,
  };
  const body = {
    model: cfg.model,
    messages: [
      { role: 'system', content: CALIBRATION_SYSTEM_PROMPT },
      { role: 'user', content: userMsg },
    ],
    response_format: { type: 'json_object' },
    stream: false,
    temperature: 0.3,
  };
  const res = await expoFetch(url, { method: 'POST', headers, body: JSON.stringify(body) });
  if (!res.ok) throw new Error(`AI HTTP ${res.status}`);
  const data = await res.json();
  return data.choices?.[0]?.message?.content ?? '';
}

export const calibrationAI: AIRunner = {
  async runRound({ templateRaw, lastUserAnswer }) {
    const cfg = readProviderConfig();
    if (!cfg) {
      return { question: templateRaw };
    }
    const userMsg = lastUserAnswer
      ? `上一轮用户答案：${lastUserAnswer}\n\n本轮模板：${templateRaw}`
      : `本轮模板（首轮，无用户答案）：${templateRaw}`;
    let lastErr: unknown;
    for (let attempt = 0; attempt < 2; attempt++) {
      try {
        const raw = await callOnce(cfg, userMsg);
        return parseAIResponse(raw, templateRaw);
      } catch (e) {
        lastErr = e;
      }
    }
    console.warn('[CalibrationAI] all retries failed:', lastErr);
    return { lastClassification: 'uncertain', question: templateRaw };
  },
};
