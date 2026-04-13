/**
 * AI 对话模块
 *
 * 支持:
 *  - OpenAI 兼容 API (openai / deepseek / custom)
 *  - Anthropic Messages API
 *
 * 返回 AsyncGenerator<string> 逐 token 流式输出
 */

import { SYSTEM_PROMPT } from './index';

export interface ChatConfig {
  provider: 'openai' | 'deepseek' | 'anthropic' | 'custom';
  apiKey: string;
  model: string;
  baseUrl?: string;           // custom provider
  mingPanSummary?: string;    // 注入命盘摘要
}

export interface Message {
  role: 'user' | 'assistant';
  content: string;
}

// ── Base URL 映射 ────────────────────────────────────────────────────────
const BASE_URLS: Record<string, string> = {
  openai:    'https://api.openai.com/v1',
  deepseek:  'https://api.deepseek.com/v1',
  anthropic: 'https://api.anthropic.com',
};

function getBaseUrl(config: ChatConfig): string {
  if (config.provider === 'custom' && config.baseUrl) {
    return config.baseUrl.replace(/\/$/, '');
  }
  return BASE_URLS[config.provider] ?? BASE_URLS.openai;
}

// ── System prompt 构造 ───────────────────────────────────────────────────
function buildSystemPrompt(mingPanSummary?: string): string {
  if (!mingPanSummary) return SYSTEM_PROMPT;
  return `${SYSTEM_PROMPT}

---
【用户命盘摘要】
${mingPanSummary}
---

在对话中，可以自然引用命盘信息，帮助用户理解自己的性格特质与人生模式。`;
}

// ── OpenAI 兼容流式请求 ──────────────────────────────────────────────────
async function* streamOpenAI(
  messages: Message[],
  config: ChatConfig,
): AsyncGenerator<string> {
  const baseUrl = getBaseUrl(config);
  const systemPrompt = buildSystemPrompt(config.mingPanSummary);

  const response = await fetch(`${baseUrl}/chat/completions`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${config.apiKey}`,
    },
    body: JSON.stringify({
      model: config.model,
      stream: true,
      messages: [
        { role: 'system', content: systemPrompt },
        ...messages,
      ],
    }),
  });

  if (!response.ok) {
    const err = await response.text();
    throw new Error(`API 错误 ${response.status}: ${err}`);
  }

  const reader = response.body?.getReader();
  if (!reader) throw new Error('无法读取响应流');

  const decoder = new TextDecoder();
  let buffer = '';

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;

    buffer += decoder.decode(value, { stream: true });
    const lines = buffer.split('\n');
    buffer = lines.pop() ?? '';

    for (const line of lines) {
      const trimmed = line.trim();
      if (!trimmed || trimmed === 'data: [DONE]') continue;
      if (!trimmed.startsWith('data: ')) continue;

      try {
        const json = JSON.parse(trimmed.slice(6));
        const delta = json.choices?.[0]?.delta?.content;
        if (delta) yield delta;
      } catch {
        // 忽略 JSON 解析错误
      }
    }
  }
}

// ── Anthropic Messages API 流式请求 ─────────────────────────────────────
async function* streamAnthropic(
  messages: Message[],
  config: ChatConfig,
): AsyncGenerator<string> {
  const systemPrompt = buildSystemPrompt(config.mingPanSummary);

  const response = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': config.apiKey,
      'anthropic-version': '2023-06-01',
    },
    body: JSON.stringify({
      model: config.model,
      max_tokens: 1024,
      stream: true,
      system: systemPrompt,
      messages,
    }),
  });

  if (!response.ok) {
    const err = await response.text();
    throw new Error(`Anthropic API 错误 ${response.status}: ${err}`);
  }

  const reader = response.body?.getReader();
  if (!reader) throw new Error('无法读取响应流');

  const decoder = new TextDecoder();
  let buffer = '';

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;

    buffer += decoder.decode(value, { stream: true });
    const lines = buffer.split('\n');
    buffer = lines.pop() ?? '';

    for (const line of lines) {
      const trimmed = line.trim();
      if (!trimmed.startsWith('data: ')) continue;

      try {
        const json = JSON.parse(trimmed.slice(6));
        // content_block_delta 事件携带 delta.text
        if (json.type === 'content_block_delta' && json.delta?.text) {
          yield json.delta.text;
        }
      } catch {
        // 忽略
      }
    }
  }
}

// ── 公开接口 ─────────────────────────────────────────────────────────────
/**
 * 流式发送消息，返回 AsyncGenerator<string>（逐 token）
 *
 * @example
 * for await (const token of streamChat(messages, config)) {
 *   setText(prev => prev + token);
 * }
 */
export async function* streamChat(
  messages: Message[],
  config: ChatConfig,
): AsyncGenerator<string> {
  if (config.provider === 'anthropic') {
    yield* streamAnthropic(messages, config);
  } else {
    yield* streamOpenAI(messages, config);
  }
}
