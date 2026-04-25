/**
 * AI 编排核心：单轮 LLM 调用 + 流式调用 helpers
 *
 * 支持 OpenAI-compatible 协议 和 Responses API（Azure AI Foundry / GPT-5 系列）。
 * Anthropic tool-use 适配后续 task 处理。
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

/** URL 以 /responses 结尾时走 Responses API */
function isResponsesAPI(config: ChatProviderConfig): boolean {
  return /\/responses\/?$/.test(config.baseUrl || '');
}

// ── Responses API 格式转换 ──────────────────────────────────────────────────

/** OpenAI-shape ToolDefinition[] → Responses API flat tools format */
function toResponsesTools(tools: ToolDefinition[]): any[] {
  return tools.map(t => ({
    type: 'function',
    name: t.function.name,
    description: t.function.description,
    parameters: t.function.parameters,
  }));
}

/** OpenAI-shape LLMMessage[] → Responses API input items */
function toResponsesInput(messages: LLMMessage[]): any[] {
  const out: any[] = [];
  for (const m of messages) {
    if (m.role === 'system' || m.role === 'user') {
      out.push({
        type: 'message',
        role: m.role,
        content: [{ type: 'input_text', text: m.content ?? '' }],
      });
    } else if (m.role === 'assistant') {
      // 两种情况：纯文本 OR 含 tool_calls
      if (m.tool_calls && m.tool_calls.length > 0) {
        // 每个 tool_call 单独是一个 input item
        for (const tc of m.tool_calls) {
          out.push({
            type: 'function_call',
            call_id: tc.id,
            name: tc.function.name,
            arguments: tc.function.arguments,
          });
        }
      }
      if (m.content) {
        out.push({
          type: 'message',
          role: 'assistant',
          content: [{ type: 'output_text', text: m.content }],
        });
      }
    } else if (m.role === 'tool') {
      out.push({
        type: 'function_call_output',
        call_id: m.tool_call_id ?? '',
        output: m.content ?? '',
      });
    }
  }
  return out;
}

// ── OpenAI-compatible 实现（file-local）──────────────────────────────────────

async function callChatCompletionsWithTools(
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

async function callChatCompletionsStreaming(
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

// ── Responses API 实现（file-local）─────────────────────────────────────────

async function callResponsesAPIWithTools(
  messages: LLMMessage[],
  config: ChatProviderConfig,
  tools: ToolDefinition[],
  signal?: AbortSignal,
): Promise<LLMResult> {
  const url = config.baseUrl; // 直接用，已包含完整路径（以 /responses 结尾）
  const body = {
    model: config.model,
    input: toResponsesInput(messages),
    tools: toResponsesTools(tools),
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
  const outputItems = data.output ?? [];

  // 检查 function_call 项
  const functionCalls = outputItems.filter((it: any) => it.type === 'function_call');
  if (functionCalls.length > 0) {
    return {
      kind: 'tools',
      calls: functionCalls.map((fc: any) => ({
        id: fc.call_id,
        name: fc.name,
        arguments: safeJSON(fc.arguments),
      })),
    };
  }

  // 提取文本
  let text = '';
  for (const item of outputItems) {
    if (item.type === 'message') {
      for (const c of item.content ?? []) {
        if (c.type === 'output_text' && typeof c.text === 'string') text += c.text;
      }
    }
  }
  return { kind: 'text', text };
}

async function callResponsesAPIStreaming(
  messages: LLMMessage[],
  config: ChatProviderConfig,
  onChunk: (partial: string) => void,
  signal?: AbortSignal,
): Promise<string> {
  const url = config.baseUrl;
  const body = {
    model: config.model,
    input: toResponsesInput(messages),
    stream: true,
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
      if (!t || !t.startsWith('data: ')) continue;
      const dataStr = t.slice(6);
      if (dataStr === '[DONE]') continue;
      try {
        const j = JSON.parse(dataStr);
        // Responses API streaming 用 'response.output_text.delta'
        if (j.type === 'response.output_text.delta' && typeof j.delta === 'string') {
          full += j.delta;
          onChunk(full);
        }
      } catch {}
    }
  }

  return full;
}

// ── 公开入口：按 baseUrl 路由 ────────────────────────────────────────────────

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
  if (isResponsesAPI(config)) {
    return callResponsesAPIWithTools(messages, config, tools, signal);
  }
  return callChatCompletionsWithTools(messages, config, tools, signal);
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
  if (isResponsesAPI(config)) {
    return callResponsesAPIStreaming(messages, config, onChunk, signal);
  }
  return callChatCompletionsStreaming(messages, config, onChunk, signal);
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
  /** 用户强制模式：'liuyao' 强制起卦，'mingli' 强制走命理；不传则 AI 自动判断 */
  forceMode?: 'liuyao' | 'mingli';
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
    {
      role: 'user',
      content: opts.forceMode
        ? `[user_force_mode=${opts.forceMode}]\n${opts.question}`
        : opts.question,
    },
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
