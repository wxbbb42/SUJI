/**
 * AI 编排核心：单轮 LLM 调用 + 流式调用 helpers
 *
 * 当前只实现 OpenAI-compatible 协议（覆盖 OpenAI / DeepSeek / 多数自定义）。
 * Anthropic / Responses API 的 tool-use 适配后续 task 处理（如果需要）。
 */
import { fetch as expoFetch } from 'expo/fetch';
import type { ToolDefinition, ToolCall } from './types';

export interface ChatProviderConfig {
  provider: 'openai' | 'deepseek' | 'anthropic' | 'custom';
  apiKey: string;
  model: string;
  baseUrl: string;
}

export interface LLMMessage {
  role: 'system' | 'user' | 'assistant' | 'tool';
  content: string | null;
  tool_call_id?: string;
  tool_calls?: Array<{
    id: string;
    type: 'function';
    function: { name: string; arguments: string };
  }>;
}

export type LLMResult =
  | { kind: 'text'; text: string }
  | { kind: 'tools'; calls: ToolCall[] };

function buildAuthHeaders(config: ChatProviderConfig): Record<string, string> {
  const isAzure = /\.azure\.com\//i.test(config.baseUrl || '');
  return isAzure
    ? { 'api-key': config.apiKey }
    : { Authorization: `Bearer ${config.apiKey}` };
}

/**
 * 单轮非流式调用：LLM 要么返回纯文本，要么返回 tool_calls
 *
 * 用于 thinker 阶段（multi-turn loop 的每一回合）
 */
export async function callLLMWithTools(
  messages: LLMMessage[],
  config: ChatProviderConfig,
  tools: ToolDefinition[],
  signal?: AbortSignal,
): Promise<LLMResult> {
  const url = `${config.baseUrl.replace(/\/$/, '')}/chat/completions`;
  const body = {
    model: config.model,
    messages,
    tools,
    tool_choice: 'auto',
    stream: false,
  };

  const response = await expoFetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...buildAuthHeaders(config),
    },
    body: JSON.stringify(body),
    signal,
  });

  if (!response.ok) {
    throw new Error(`LLM error ${response.status}: ${await response.text()}`);
  }

  const data = await response.json();
  const msg = data.choices?.[0]?.message;
  if (!msg) throw new Error('LLM returned no message');

  if (msg.tool_calls && msg.tool_calls.length > 0) {
    const calls: ToolCall[] = msg.tool_calls.map((c: any) => ({
      id: c.id,
      name: c.function.name,
      arguments: safeJSON(c.function.arguments),
    }));
    return { kind: 'tools', calls };
  }

  return { kind: 'text', text: msg.content ?? '' };
}

/**
 * 单轮流式调用（无工具），用于 interpreter 阶段
 */
export async function callLLMStreaming(
  messages: LLMMessage[],
  config: ChatProviderConfig,
  onChunk: (partial: string) => void,
  signal?: AbortSignal,
): Promise<string> {
  const url = `${config.baseUrl.replace(/\/$/, '')}/chat/completions`;
  const body = { model: config.model, messages, stream: true };

  const response = await expoFetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...buildAuthHeaders(config),
    },
    body: JSON.stringify(body),
    signal,
  });

  if (!response.ok) {
    throw new Error(`LLM error ${response.status}: ${await response.text()}`);
  }

  const reader = response.body?.getReader();
  if (!reader) throw new Error('no body reader');

  const decoder = new TextDecoder();
  let full = '';
  let buffer = '';

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    buffer += decoder.decode(value, { stream: true });
    const lines = buffer.split('\n');
    buffer = lines.pop() ?? '';
    for (const line of lines) {
      const t = line.trim();
      if (!t || t === 'data: [DONE]' || !t.startsWith('data: ')) continue;
      try {
        const j = JSON.parse(t.slice(6));
        const delta = j.choices?.[0]?.delta?.content;
        if (delta) {
          full += delta;
          onChunk(full);
        }
      } catch {}
    }
  }

  return full;
}

function safeJSON(s: string): Record<string, unknown> {
  try { return JSON.parse(s); } catch { return {}; }
}
