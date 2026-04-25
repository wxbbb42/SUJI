import { callLLMWithTools } from '../orchestrator';
import type { ToolDefinition } from '../types';

// Mock expo/fetch — the orchestrator imports `fetch` from 'expo/fetch'
jest.mock('expo/fetch', () => ({
  fetch: jest.fn(),
}));

import { fetch as expoFetch } from 'expo/fetch';

afterEach(() => {
  (expoFetch as jest.Mock).mockReset();
});

const FAKE_TOOLS: ToolDefinition[] = [
  {
    type: 'function',
    function: { name: 'echo', description: 'echo', parameters: { type: 'object', properties: {} } },
  },
];

const FAKE_CONFIG = {
  provider: 'openai' as const,
  apiKey: 'k',
  model: 'gpt-4o',
  baseUrl: 'https://x',
};

describe('callLLMWithTools', () => {
  it('returns text when LLM responds with content', async () => {
    (expoFetch as jest.Mock).mockResolvedValueOnce({
      ok: true,
      json: async () => ({
        choices: [{ message: { role: 'assistant', content: 'hello world' } }],
      }),
    });

    const r = await callLLMWithTools(
      [{ role: 'user', content: 'hi' }],
      FAKE_CONFIG,
      FAKE_TOOLS,
    );
    expect(r.kind).toBe('text');
    if (r.kind === 'text') expect(r.text).toBe('hello world');
  });

  it('returns toolCalls when LLM responds with function calls', async () => {
    (expoFetch as jest.Mock).mockResolvedValueOnce({
      ok: true,
      json: async () => ({
        choices: [{
          message: {
            role: 'assistant',
            content: null,
            tool_calls: [{
              id: 'call_1',
              type: 'function',
              function: { name: 'echo', arguments: '{"x":1}' },
            }],
          },
        }],
      }),
    });

    const r = await callLLMWithTools(
      [{ role: 'user', content: 'hi' }],
      FAKE_CONFIG,
      FAKE_TOOLS,
    );
    expect(r.kind).toBe('tools');
    if (r.kind === 'tools') {
      expect(r.calls).toHaveLength(1);
      expect(r.calls[0].name).toBe('echo');
      expect(r.calls[0].arguments).toEqual({ x: 1 });
    }
  });
});

describe('callLLMWithTools (Responses API path)', () => {
  it('routes to Responses API when baseUrl ends with /responses, returns text', async () => {
    (expoFetch as jest.Mock).mockResolvedValueOnce({
      ok: true,
      json: async () => ({
        output: [
          {
            type: 'message',
            role: 'assistant',
            content: [{ type: 'output_text', text: 'hello from responses' }],
          },
        ],
      }),
    });
    const r = await callLLMWithTools(
      [{ role: 'user', content: 'hi' }],
      { provider: 'custom', apiKey: 'k', model: 'gpt-5', baseUrl: 'https://x/responses' },
      [],
    );
    expect(r.kind).toBe('text');
    if (r.kind === 'text') expect(r.text).toBe('hello from responses');
  });

  it('routes to Responses API and returns toolCalls', async () => {
    (expoFetch as jest.Mock).mockResolvedValueOnce({
      ok: true,
      json: async () => ({
        output: [
          { type: 'function_call', call_id: 'c1', name: 'echo', arguments: '{"x":1}' },
        ],
      }),
    });
    const r = await callLLMWithTools(
      [{ role: 'user', content: 'hi' }],
      { provider: 'custom', apiKey: 'k', model: 'gpt-5', baseUrl: 'https://x/responses' },
      [{ type: 'function', function: { name: 'echo', description: '', parameters: { type: 'object', properties: {} } } }],
    );
    expect(r.kind).toBe('tools');
    if (r.kind === 'tools') {
      expect(r.calls).toHaveLength(1);
      expect(r.calls[0].name).toBe('echo');
      expect(r.calls[0].arguments).toEqual({ x: 1 });
    }
  });
});
