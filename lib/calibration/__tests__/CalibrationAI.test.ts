import {
  calibrationAI,
  parseAIResponse,
  CALIBRATION_SYSTEM_PROMPT,
  renderSignalTable,
  renderHistory,
  buildUserMessage,
} from '../CalibrationAI';
import type { SignalTable } from '../CalibrationSession';

jest.mock('@/lib/store/userStore', () => ({
  useUserStore: {
    getState: jest.fn(),
  },
}));

describe('parseAIResponse', () => {
  it('parses well-formed asking response', () => {
    const r = parseAIResponse('{"decision":"asking","text":"你今年呢？"}', '原文本');
    expect(r.decision).toBe('asking');
    expect(r.text).toBe('你今年呢？');
    expect(r.lockedCandidate).toBeUndefined();
  });

  it('parses well-formed locked response with candidate', () => {
    const r = parseAIResponse(
      '{"decision":"locked","text":"看起来你是酉时。","lockedCandidate":"before"}',
      'fallback',
    );
    expect(r.decision).toBe('locked');
    expect(r.lockedCandidate).toBe('before');
  });

  it('parses gave_up response', () => {
    const r = parseAIResponse('{"decision":"gave_up","text":"信号不足"}', 'fb');
    expect(r.decision).toBe('gave_up');
    expect(r.text).toBe('信号不足');
  });

  it('downgrades locked-without-candidate to asking', () => {
    const r = parseAIResponse('{"decision":"locked","text":"锁了"}', 'fb');
    expect(r.decision).toBe('asking');
  });

  it('rejects unknown candidate id', () => {
    const r = parseAIResponse(
      '{"decision":"locked","text":"锁","lockedCandidate":"middle"}',
      'fb',
    );
    expect(r.decision).toBe('asking');
  });

  it('falls back to template raw when JSON invalid', () => {
    const r = parseAIResponse('not json', '原文本');
    expect(r.decision).toBe('asking');
    expect(r.text).toBe('原文本');
  });

  it('falls back when decision is unknown enum', () => {
    const r = parseAIResponse('{"decision":"maybe","text":"q"}', '原');
    expect(r.decision).toBe('asking');
    expect(r.text).toBe('q');
  });
});

describe('CALIBRATION_SYSTEM_PROMPT', () => {
  it('contains required keywords', () => {
    expect(CALIBRATION_SYSTEM_PROMPT).toContain('校准');
    expect(CALIBRATION_SYSTEM_PROMPT).toContain('JSON');
    expect(CALIBRATION_SYSTEM_PROMPT).toContain('decision');
    expect(CALIBRATION_SYSTEM_PROMPT).toContain('lockedCandidate');
  });
});

const FAKE_TABLE: SignalTable = {
  byCandidate: {
    before: { 2014: '紫微大限转伤官', 2024: '紫微大限转食神' },
    origin: { 2014: '紫微大限转正印', 2024: '紫微大限转七杀' },
    after: { 2014: '紫微大限转食神', 2024: '紫微大限转正官', 2020: 'none' },
  },
  candidatesMeta: [
    { id: 'before', birthDate: '1995-08-15T17:00:00.000Z', birthHourLabel: '酉时(17-19)' },
    { id: 'origin', birthDate: '1995-08-15T19:00:00.000Z', birthHourLabel: '戌时(19-21)' },
    { id: 'after', birthDate: '1995-08-15T21:00:00.000Z', birthHourLabel: '亥时(21-23)' },
  ],
  currentYear: 2026,
};

describe('renderSignalTable', () => {
  it('lists each candidate with non-none events sorted by year', () => {
    const out = renderSignalTable(FAKE_TABLE);
    expect(out).toContain('candidate_before (酉时(17-19))');
    expect(out).toContain('candidate_origin (戌时(19-21))');
    expect(out).toContain('  2014: 紫微大限转伤官');
    expect(out).toContain('  2024: 紫微大限转七杀');
    // 'none' 年份过滤掉
    expect(out).not.toContain('2020: none');
  });
});

describe('renderHistory', () => {
  it('returns "first round" hint when empty', () => {
    expect(renderHistory([])).toContain('首轮');
  });

  it('formats AI / User turns', () => {
    const out = renderHistory([
      { role: 'ai', text: 'Q1' },
      { role: 'user', text: 'A1' },
    ]);
    expect(out).toContain('AI: Q1');
    expect(out).toContain('User: A1');
  });
});

describe('buildUserMessage', () => {
  it('includes signal table, age, history, round directive', () => {
    const out = buildUserMessage({
      signalTable: FAKE_TABLE,
      history: [{ role: 'ai', text: 'Q1' }],
      round: 2,
      userAge: 31,
    });
    expect(out).toContain('信号表：');
    expect(out).toContain('用户当前年龄：31');
    expect(out).toContain('AI: Q1');
    expect(out).toContain('第 2 轮');
  });
});

function mockUserStoreState(state: {
  apiProvider: 'openai' | 'deepseek' | 'anthropic' | 'custom';
  apiKey: string;
  apiModel?: string | null;
  apiBaseUrl?: string | null;
}) {
  const { useUserStore } = jest.requireMock('@/lib/store/userStore') as {
    useUserStore: { getState: jest.Mock };
  };
  useUserStore.getState.mockReturnValue(state);
}

function mockResponse(data: unknown, ok = true, status = 200): Response {
  return {
    ok,
    status,
    json: async () => data,
    text: async () => JSON.stringify(data),
  } as Response;
}

describe('calibrationAI provider calls', () => {
  beforeEach(() => {
    global.fetch = jest.fn();
  });

  it('routes Anthropic config to /v1/messages instead of /chat/completions', async () => {
    mockUserStoreState({
      apiProvider: 'anthropic',
      apiKey: 'test-key',
      apiModel: 'claude-sonnet-test',
      apiBaseUrl: 'https://stale-custom.example/v1',
    });
    (global.fetch as jest.Mock).mockResolvedValueOnce(
      mockResponse({ content: [{ type: 'text', text: '{"decision":"asking","text":"Q1"}' }] }),
    );

    const out = await calibrationAI.runRound({
      signalTable: FAKE_TABLE,
      history: [],
      round: 1,
      userAge: 31,
    });

    expect(global.fetch).toHaveBeenCalledWith(
      'https://api.anthropic.com/v1/messages',
      expect.objectContaining({ method: 'POST' }),
    );
    expect(out).toEqual({ decision: 'asking', text: 'Q1' });
  });

  it('keeps first round startable when provider request fails', async () => {
    mockUserStoreState({
      apiProvider: 'openai',
      apiKey: 'test-key',
      apiModel: 'gpt-test',
      apiBaseUrl: null,
    });
    (global.fetch as jest.Mock).mockResolvedValue(mockResponse({ error: 'boom' }, false, 500));

    const out = await calibrationAI.runRound({
      signalTable: FAKE_TABLE,
      history: [],
      round: 1,
      userAge: 31,
    });

    expect(out.decision).toBe('asking');
    expect(out.text).toContain('印象很深');
  });
});
