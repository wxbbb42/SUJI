import { runOrchestration } from '../orchestrator';

jest.mock('expo/fetch', () => ({
  fetch: jest.fn(),
}));

import { fetch as expoFetch } from 'expo/fetch';

afterEach(() => {
  (expoFetch as jest.Mock).mockReset();
});

const FIXED_CONFIG = {
  provider: 'openai' as const, apiKey: 'k', model: 'gpt-4o', baseUrl: 'https://x',
};

describe('runOrchestration', () => {
  it('handles a single-round flow (no tool calls)', async () => {
    let callCount = 0;
    (expoFetch as jest.Mock).mockImplementation(async (_url: any, init: any) => {
      callCount++;
      const body = JSON.parse(init.body);
      if (body.tools) {
        // Call 1 (with tools): immediately return text
        return {
          ok: true,
          json: async () => ({
            choices: [{ message: { content: '推演：1. ...\n2. ...\n综合：xxx' } }],
          }),
        };
      }
      // Call 2 (streaming): single chunk + DONE
      return {
        ok: true,
        body: makeSSEBody(['{"choices":[{"delta":{"content":"[interpretation]\\nhello"}}]}']),
      };
    });

    const onChunk = jest.fn();
    const onToolCall = jest.fn();
    const result = await runOrchestration({
      question: '我什么时候有孩子',
      identity: '日主：庚金',
      mingPan: {}, ziweiPan: {},
      config: FIXED_CONFIG,
      onChunk,
      onToolCall,
    });

    expect(callCount).toBe(2);
    expect(result.thinker).toContain('推演');
    expect(result.interpreter).toContain('[interpretation]');
    expect(onToolCall).not.toHaveBeenCalled();
    expect(onChunk).toHaveBeenCalled();
  });
});

function makeSSEBody(events: string[]): any {
  const enc = new TextEncoder();
  const lines = events.map(e => `data: ${e}\n\n`).concat(['data: [DONE]\n\n']);
  let i = 0;
  return {
    getReader: () => ({
      read: async () => {
        if (i >= lines.length) return { done: true, value: undefined };
        return { done: false, value: enc.encode(lines[i++]) };
      },
    }),
  };
}
