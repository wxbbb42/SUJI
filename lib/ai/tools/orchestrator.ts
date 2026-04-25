/**
 * AI 编排核心：单轮 LLM 调用 + 流式调用 helpers
 *
 * 当前只实现 OpenAI-compatible 协议（覆盖 OpenAI / DeepSeek / 多数自定义）。
 * Anthropic / Responses API 的 tool-use 适配后续 task 处理（如果需要）。
 */
import { fetch as expoFetch } from 'expo/fetch';
import type { ToolDefinition, ToolCall } from './types';
import { ALL_TOOLS, ALL_HANDLERS, TOOL_STRATEGY } from './index';
import { THINKER_PROMPT, INTERPRETER_PROMPT } from '../index';

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

// ── runOrchestration: multi-turn thinker loop + Phase B streaming ──

const MAX_TOOL_ROUNDS = 5;

export interface OrchestrationOptions {
  question: string;
  identity: string;        // 内联到 thinker 系统消息
  mingPan: any;
  ziweiPan: any;
  config: ChatProviderConfig;
  onToolCall?: (call: ToolCall, result: unknown) => void;
  onThinkerComplete?: (text: string) => void;
  onChunk?: (partialInterpretation: string) => void;
  signal?: AbortSignal;
}

export interface OrchestrationResult {
  thinker: string;
  interpreter: string;
  toolCalls: Array<{ call: ToolCall; result: unknown }>;
}

export async function runOrchestration(opts: OrchestrationOptions): Promise<OrchestrationResult> {
  const ctx = { mingPan: opts.mingPan, ziweiPan: opts.ziweiPan, now: new Date() };
  const toolCalls: Array<{ call: ToolCall; result: unknown }> = [];

  // ── Phase A：Call 1 thinker（multi-turn）
  const thinkerSystem = `${THINKER_PROMPT}

# 命主信息
${opts.identity}

# ${TOOL_STRATEGY}`;

  const messages: LLMMessage[] = [
    { role: 'system', content: thinkerSystem },
    { role: 'user', content: opts.question },
  ];

  let thinkerOutput = '';
  for (let round = 0; round < MAX_TOOL_ROUNDS; round++) {
    const resp = await callLLMWithTools(messages, opts.config, ALL_TOOLS, opts.signal);
    if (resp.kind === 'text') {
      thinkerOutput = resp.text;
      break;
    }
    // tools branch
    messages.push({
      role: 'assistant',
      content: null,
      tool_calls: resp.calls.map(c => ({
        id: c.id,
        type: 'function',
        function: { name: c.name, arguments: JSON.stringify(c.arguments) },
      })),
    });
    for (const call of resp.calls) {
      const handler = ALL_HANDLERS[call.name];
      let result: unknown;
      try {
        result = handler
          ? await handler(call.arguments, ctx)
          : { error: `unknown_tool:${call.name}` };
      } catch (e: any) {
        result = { error: String(e?.message ?? e) };
      }
      toolCalls.push({ call, result });
      opts.onToolCall?.(call, result);
      messages.push({
        role: 'tool',
        tool_call_id: call.id,
        content: JSON.stringify(result),
      });
    }
  }

  if (!thinkerOutput) {
    thinkerOutput = '推演引擎未给出最终结论（达到工具调用上限）。';
  }
  opts.onThinkerComplete?.(thinkerOutput);

  // Phase A → B 之间检查 abort（节省一次 round trip）
  if (opts.signal?.aborted) {
    throw Object.assign(new Error('Aborted between phases'), { name: 'AbortError' });
  }

  // ── Phase B：Call 2 interpreter（streaming）
  const interpMessages: LLMMessage[] = [
    { role: 'system', content: INTERPRETER_PROMPT },
    {
      role: 'user',
      content: `用户问题：${opts.question}\n\n推演引擎输出：\n${thinkerOutput}`,
    },
  ];

  const interpreterText = await callLLMStreaming(
    interpMessages, opts.config,
    (partial) => opts.onChunk?.(partial),
    opts.signal,
  );

  return {
    thinker: thinkerOutput,
    interpreter: interpreterText,
    toolCalls,
  };
}
