// 复用 buildCandidates / extractEvents / bifurcation 测试里的 mock 模式：
// BaziEngine 在 jest 下因 lunisolar fetalGod 插件 CJS 加载失败，需要 stub；
// DayunEngine 用 hour 偏移制造三个候选盘的事件差异，从而保证 detectBifurcations
// 能产出至少一个分歧年份，driver 的状态机才有题目可问。
import type { ShiShen } from '@/lib/bazi/types';

jest.mock('@/lib/bazi/BaziEngine', () => ({
  BaziEngine: jest.fn().mockImplementation(() => ({
    calculate: (birthDate: Date, gender: '男' | '女') => ({
      birthDate,
      gender,
      __stub: true,
    }),
  })),
}));

const SHISHEN_CYCLE: ShiShen[] = [
  '比肩', '劫财', '食神', '伤官', '偏财',
  '正财', '七杀', '正官', '偏印', '正印',
];

const DAYUN_BY_HOUR: Record<number, Array<{ startAge: number; endAge: number; shiShen: ShiShen }>> = {
  18: [
    { startAge: 3, endAge: 12, shiShen: '正印' },
    { startAge: 13, endAge: 22, shiShen: '七杀' },
    { startAge: 23, endAge: 32, shiShen: '正财' },
    { startAge: 33, endAge: 42, shiShen: '伤官' },
  ],
  20: [
    { startAge: 5, endAge: 14, shiShen: '比肩' },
    { startAge: 15, endAge: 24, shiShen: '伤官' },
    { startAge: 25, endAge: 34, shiShen: '正官' },
    { startAge: 35, endAge: 44, shiShen: '食神' },
  ],
  22: [
    { startAge: 7, endAge: 16, shiShen: '偏印' },
    { startAge: 17, endAge: 26, shiShen: '偏财' },
    { startAge: 27, endAge: 36, shiShen: '劫财' },
    { startAge: 37, endAge: 46, shiShen: '七杀' },
  ],
};

const HOUR_OFFSET: Record<number, number> = { 18: 0, 20: 3, 22: 7 };

jest.mock('@/lib/bazi/DayunEngine', () => ({
  DayunEngine: jest.fn().mockImplementation((mingPan: { birthDate: Date }) => {
    const hour = mingPan.birthDate.getHours();
    const dayuns = DAYUN_BY_HOUR[hour] ?? DAYUN_BY_HOUR[20];
    const offset = HOUR_OFFSET[hour] ?? 0;
    return {
      getDaYunList: () => dayuns,
      getCurrentLiuNian: (year: number) => ({
        year,
        shiShen: SHISHEN_CYCLE[(((year + offset) % 10) + 10) % 10],
      }),
    };
  }),
}));

import { CalibrationSession } from '../CalibrationSession';

const mockAI = {
  runRound: jest.fn(),
};

beforeEach(() => mockAI.runRound.mockReset());

describe('CalibrationSession', () => {
  it('starts with 3 candidates and emits first question', async () => {
    mockAI.runRound.mockResolvedValueOnce({ question: '你 19 岁那年（2014）是否…？' });
    const session = new CalibrationSession({ runRound: mockAI.runRound });
    const { firstQuestion, state } = await session.start({
      birthDate: new Date('1995-08-15T20:00:00+08:00'),
      gender: '男',
      longitude: 116.4,
    });
    expect(state.candidates).toHaveLength(3);
    expect(state.bifurcations.length).toBeGreaterThan(0);
    expect(firstQuestion).toContain('你');
  });

  it('locks when scores diverge by 2', async () => {
    mockAI.runRound
      .mockResolvedValueOnce({ question: 'Q1' })
      .mockResolvedValueOnce({ lastClassification: 'yes', question: 'Q2' })
      .mockResolvedValueOnce({ lastClassification: 'yes', question: 'Q3' });

    const session = new CalibrationSession({ runRound: mockAI.runRound });
    await session.start({ birthDate: new Date('1995-08-15T20:00:00+08:00'), gender: '男', longitude: 116.4 });

    const r1 = await session.submitAnswerWithForcedDelta('在 19 岁那年我转学了', { before: 1, origin: 0, after: -1 });
    expect(r1.nextStep.type).toBe('next_question');
    const r2 = await session.submitAnswerWithForcedDelta('又有一次类似经历', { before: 1, origin: -1, after: 0 });
    // before=2, origin=-1, after=-1 → 差距 ≥ 2
    expect(r2.nextStep.type).toBe('locked');
    if (r2.nextStep.type === 'locked') {
      expect(r2.nextStep.correctedDate).toBeInstanceOf(Date);
    }
  });

  it('throws a friendly error when methods are called before start()', async () => {
    const session = new CalibrationSession({ runRound: mockAI.runRound });
    await expect(session.submitAnswer('x')).rejects.toThrow(/call start\(\) first/);
    await expect(
      session.submitAnswerWithForcedDelta('x', { before: 0, origin: 0, after: 0 }),
    ).rejects.toThrow(/call start\(\) first/);
    expect(() => session.getState()).toThrow(/call start\(\) first/);
  });

  it('gives up after 2 consecutive uncertain', async () => {
    mockAI.runRound
      .mockResolvedValueOnce({ question: 'Q1' })
      .mockResolvedValueOnce({ lastClassification: 'uncertain', question: 'Q2' })
      .mockResolvedValueOnce({ lastClassification: 'uncertain', question: 'Q3' });

    const session = new CalibrationSession({ runRound: mockAI.runRound });
    await session.start({ birthDate: new Date('1995-08-15T20:00:00+08:00'), gender: '男', longitude: 116.4 });
    await session.submitAnswer('我不记得了');
    const r2 = await session.submitAnswer('也不记得');
    expect(r2.nextStep.type).toBe('gave_up');
  });
});
