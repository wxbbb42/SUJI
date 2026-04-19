/**
 * AI 对话核心模块
 *
 * 支持 OpenAI / DeepSeek / Anthropic / 自定义 (OpenAI 兼容 或 Responses API)
 * baseUrl 以 /responses 结尾时走 Responses API（GPT-5 系列、Azure AI Foundry）
 * baseUrl 含 azure.com 时用 api-key 认证头（非 Bearer）
 * 流式输出
 */

import { SYSTEM_PROMPT, TONE_PROMPTS, type ToneStyle, type ChatMessage } from './index';
import type { UserState } from '../store/userStore';

/** API 配置 */
interface ChatConfig {
  provider: 'openai' | 'deepseek' | 'anthropic' | 'custom';
  apiKey: string;
  model: string;
  baseUrl?: string;
}

/** 从 UserState 提取 ChatConfig */
export function getChatConfig(state: UserState): ChatConfig | null {
  if (!state.apiProvider || !state.apiKey) return null;

  const defaults: Record<string, { model: string; baseUrl: string }> = {
    openai:    { model: 'gpt-4o',            baseUrl: 'https://api.openai.com/v1' },
    deepseek:  { model: 'deepseek-chat',     baseUrl: 'https://api.deepseek.com/v1' },
    anthropic: { model: 'claude-sonnet-4-20250514', baseUrl: 'https://api.anthropic.com' },
    custom:    { model: 'gpt-4o',            baseUrl: '' },
  };

  const d = defaults[state.apiProvider];
  return {
    provider: state.apiProvider,
    apiKey: state.apiKey,
    model: state.apiModel || d.model,
    baseUrl: state.apiBaseUrl || d.baseUrl,
  };
}

/** 构建系统 prompt，注入命盘摘要 */
function buildSystemPrompt(mingPanJson: string | null, tone: ToneStyle = 'warm'): string {
  let prompt = SYSTEM_PROMPT + '\n\n' + TONE_PROMPTS[tone];

  if (mingPanJson) {
    try {
      const pan = JSON.parse(mingPanJson);
      const summary = [
        `用户命盘摘要：`,
        `日主：${pan.riZhu?.gan}${pan.riZhu?.zhi}（${pan.riZhu?.yinYang}${pan.riZhu?.wuXing}）`,
        `四柱：${pan.siZhu?.year?.ganZhi?.gan}${pan.siZhu?.year?.ganZhi?.zhi} ${pan.siZhu?.month?.ganZhi?.gan}${pan.siZhu?.month?.ganZhi?.zhi} ${pan.siZhu?.day?.ganZhi?.gan}${pan.siZhu?.day?.ganZhi?.zhi} ${pan.siZhu?.hour?.ganZhi?.gan}${pan.siZhu?.hour?.ganZhi?.zhi}`,
        `格局：${pan.geJu?.name}（${pan.geJu?.category}·${pan.geJu?.strength}）`,
        `用神：${pan.wuXingStrength?.yongShen}，喜神：${pan.wuXingStrength?.xiShen}，忌神：${pan.wuXingStrength?.jiShen}`,
        pan.riZhu?.description ? `日主特质：${pan.riZhu.description}` : '',
        pan.geJu?.modernMeaning ? `格局含义：${pan.geJu.modernMeaning}` : '',
      ].filter(Boolean).join('\n');
      prompt += '\n\n' + summary;
      prompt += '\n\n请根据以上命盘信息，用现代心理学语言回应用户。不要直接展示命盘数据，而是自然地融入对话。';
    } catch {
      // 解析失败忽略
    }
  }

  return prompt;
}

/** URL 形如 .../v1/responses 时走 Responses API */
function isResponsesAPI(config: ChatConfig): boolean {
  return /\/responses\/?$/.test(config.baseUrl || '');
}

/** Azure AI Foundry 用 api-key 头，OpenAI/兼容方用 Bearer */
function buildAuthHeaders(config: ChatConfig): Record<string, string> {
  const isAzure = /\.azure\.com\//i.test(config.baseUrl || '');
  return isAzure
    ? { 'api-key': config.apiKey }
    : { 'Authorization': `Bearer ${config.apiKey}` };
}

/**
 * 流式对话（OpenAI 兼容 API）
 * 适用于 openai / deepseek / custom
 */
async function* streamOpenAI(
  messages: ChatMessage[],
  systemPrompt: string,
  config: ChatConfig,
): AsyncGenerator<string> {
  const url = `${config.baseUrl}/chat/completions`;

  const body = {
    model: config.model,
    stream: true,
    messages: [
      { role: 'system', content: systemPrompt },
      ...messages.map(m => ({ role: m.role, content: m.content })),
    ],
  };

  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...buildAuthHeaders(config),
    },
    body: JSON.stringify(body),
  });

  if (!response.ok) {
    const err = await response.text();
    throw new Error(`API 请求失败 (${response.status}): ${err}`);
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
    buffer = lines.pop() || '';

    for (const line of lines) {
      const trimmed = line.trim();
      if (!trimmed || trimmed === 'data: [DONE]') continue;
      if (!trimmed.startsWith('data: ')) continue;

      try {
        const json = JSON.parse(trimmed.slice(6));
        const delta = json.choices?.[0]?.delta?.content;
        if (delta) yield delta;
      } catch {
        // 解析失败跳过
      }
    }
  }
}

/**
 * 流式对话（Responses API：GPT-5 系列、Azure AI Foundry）
 * baseUrl 就是完整 URL（到 /responses），不拼接路径
 */
async function* streamResponsesAPI(
  messages: ChatMessage[],
  systemPrompt: string,
  config: ChatConfig,
): AsyncGenerator<string> {
  const url = config.baseUrl || '';

  const body = {
    model: config.model,
    stream: true,
    input: toResponsesInput(messages, systemPrompt),
  };

  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...buildAuthHeaders(config),
    },
    body: JSON.stringify(body),
  });

  if (!response.ok) {
    const err = await response.text();
    throw new Error(`API 请求失败 (${response.status}): ${err}`);
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
    buffer = lines.pop() || '';

    for (const line of lines) {
      const trimmed = line.trim();
      if (!trimmed || !trimmed.startsWith('data: ')) continue;
      const data = trimmed.slice(6);
      if (data === '[DONE]') continue;

      try {
        const json = JSON.parse(data);
        if (json.type === 'response.output_text.delta' && typeof json.delta === 'string') {
          yield json.delta;
        }
      } catch {
        // 解析失败跳过
      }
    }
  }
}

/** Responses API 输入格式：每项需 type='message'，content 为分片数组 */
function toResponsesInput(messages: ChatMessage[], systemPrompt: string) {
  return [
    {
      type: 'message' as const,
      role: 'system' as const,
      content: [{ type: 'input_text' as const, text: systemPrompt }],
    },
    ...messages.map(m => ({
      type: 'message' as const,
      role: m.role,
      content: [{
        type: (m.role === 'assistant' ? 'output_text' : 'input_text') as const,
        text: m.content,
      }],
    })),
  ];
}

/**
 * 流式对话（Anthropic API）
 */
async function* streamAnthropic(
  messages: ChatMessage[],
  systemPrompt: string,
  config: ChatConfig,
): AsyncGenerator<string> {
  const url = `${config.baseUrl}/v1/messages`;

  const body = {
    model: config.model,
    max_tokens: 2048,
    stream: true,
    system: systemPrompt,
    messages: messages.map(m => ({ role: m.role, content: m.content })),
  };

  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': config.apiKey,
      'anthropic-version': '2023-06-01',
    },
    body: JSON.stringify(body),
  });

  if (!response.ok) {
    const err = await response.text();
    throw new Error(`API 请求失败 (${response.status}): ${err}`);
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
    buffer = lines.pop() || '';

    for (const line of lines) {
      const trimmed = line.trim();
      if (!trimmed.startsWith('data: ')) continue;

      try {
        const json = JSON.parse(trimmed.slice(6));
        if (json.type === 'content_block_delta' && json.delta?.text) {
          yield json.delta.text;
        }
      } catch {
        // 解析失败跳过
      }
    }
  }
}

/**
 * 非流式 fallback（React Native 某些环境不支持 ReadableStream）
 */
async function fetchNonStream(
  messages: ChatMessage[],
  systemPrompt: string,
  config: ChatConfig,
): Promise<string> {
  if (config.provider === 'anthropic') {
    const url = `${config.baseUrl}/v1/messages`;
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': config.apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: config.model,
        max_tokens: 2048,
        system: systemPrompt,
        messages: messages.map(m => ({ role: m.role, content: m.content })),
      }),
    });
    if (!response.ok) throw new Error(`API 错误 (${response.status})`);
    const data = await response.json();
    return data.content?.[0]?.text ?? '';
  }

  // Responses API（含 Azure AI Foundry / GPT-5 系列）
  if (isResponsesAPI(config)) {
    const response = await fetch(config.baseUrl || '', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...buildAuthHeaders(config),
      },
      body: JSON.stringify({
        model: config.model,
        input: toResponsesInput(messages, systemPrompt),
      }),
    });
    if (!response.ok) throw new Error(`API 错误 (${response.status}): ${await response.text()}`);
    const data = await response.json();
    // Responses API: data.output[].content[].text（type=output_text）
    const chunks: string[] = [];
    for (const item of data.output ?? []) {
      for (const c of item.content ?? []) {
        if (c.type === 'output_text' && typeof c.text === 'string') chunks.push(c.text);
      }
    }
    return chunks.join('') || data.output_text || '';
  }

  // OpenAI 兼容
  const url = `${config.baseUrl}/chat/completions`;
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...buildAuthHeaders(config),
    },
    body: JSON.stringify({
      model: config.model,
      messages: [
        { role: 'system', content: systemPrompt },
        ...messages.map(m => ({ role: m.role, content: m.content })),
      ],
    }),
  });
  if (!response.ok) throw new Error(`API 错误 (${response.status})`);
  const data = await response.json();
  return data.choices?.[0]?.message?.content ?? '';
}

/**
 * 主入口：发送对话并获取 AI 回复
 *
 * 优先尝试流式，fallback 到非流式
 */
export async function sendChat(
  messages: ChatMessage[],
  config: ChatConfig,
  mingPanJson: string | null,
  onChunk?: (chunk: string) => void,
): Promise<string> {
  const systemPrompt = buildSystemPrompt(mingPanJson);

  // 先尝试流式
  try {
    const stream = config.provider === 'anthropic'
      ? streamAnthropic(messages, systemPrompt, config)
      : isResponsesAPI(config)
        ? streamResponsesAPI(messages, systemPrompt, config)
        : streamOpenAI(messages, systemPrompt, config);

    let fullText = '';
    for await (const chunk of stream) {
      fullText += chunk;
      onChunk?.(fullText);
    }
    return fullText;
  } catch (streamErr) {
    // 流式失败 fallback 到非流式
    console.warn('流式请求失败，降级为非流式:', streamErr);
    const text = await fetchNonStream(messages, systemPrompt, config);
    onChunk?.(text);
    return text;
  }
}
