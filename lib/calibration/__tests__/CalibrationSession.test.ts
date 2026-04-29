// LLM-driven CalibrationSession 单测：
// BaziEngine 在 jest 下因 lunisolar fetalGod 插件 CJS 加载失败，需要 stub；
// DayunEngine 给三个候选盘提供差异化的大运十神，从而保证 buildSignalTable
// 能产出非 'none' 信号，session 才不会抛 LOW_SIGNAL。
import type { ShiShen } from '@/lib/bazi/types';

jest.mock('@/lib/bazi/BaziEngine', () => ({
  BaziEngine: jest.fn().mockImplementation(() => ({
    calculate: (birthDate: Date, gender: '男' | '女') => ({
      birthDate,
      gender,
      // riZhu.gan 占位：紫微大限 extractor 用日主天干算十神。mock 模式下任意值即可。
      riZhu: { gan: '甲' },
      __stub: true,
    }),
  })),
}));

const DAYUN_BY_HOUR: Record<number, Array<{ startAge: number; endAge: number; shiShen: ShiShen }>> = {
  18: [
    { startAge: 3, endAge: 12, shiShen: '正印' },
    { startAge: 13, endAge: 22, shiShen: '七杀' },
    { startAge: 23, endAge: 32, shiShen: '正财' },
  ],
  20: [
    { startAge: 5, endAge: 14, shiShen: '比肩' },
    { startAge: 15, endAge: 24, shiShen: '伤官' },
    { startAge: 25, endAge: 34, shiShen: '正官' },
  ],
  22: [
    { startAge: 7, endAge: 16, shiShen: '偏印' },
    { startAge: 17, endAge: 26, shiShen: '偏财' },
    { startAge: 27, endAge: 36, shiShen: '劫财' },
  ],
};

jest.mock('@/lib/bazi/DayunEngine', () => {
  const ctor: any = jest.fn().mockImplementation((mingPan: { birthDate: Date }) => {
    const hour = mingPan.birthDate.getHours();
    const dayuns = DAYUN_BY_HOUR[hour] ?? DAYUN_BY_HOUR[20];
    return {
      getDaYunList: () => dayuns,
      getCurrentLiuNian: (year: number) => ({ year, shiShen: 'none' }),
    };
  });
  ctor.computeShiShen = jest.fn().mockReturnValue('比肩');
  return { DayunEngine: ctor };
});

import { CalibrationSession, type AIRunner } from '../CalibrationSession';

function makeAI(behaviors: Array<Parameters<AIRunner['runRound']>[0] extends infer _ ? Awaited<ReturnType<AIRunner['runRound']>> : never>): {
  runner: AIRunner;
  spy: jest.Mock;
} {
  const spy = jest.fn();
  for (const b of behaviors) spy.mockResolvedValueOnce(b);
  return { runner: { runRound: spy }, spy };
}

const COMMON_OPTS = {
  birthDate: new Date('1995-08-15T20:00:00+08:00'),
  gender: '男' as const,
  longitude: 116.4,
};

describe('CalibrationSession (LLM-driven)', () => {
  it('start() emits AI-provided first question and records history', async () => {
    const { runner, spy } = makeAI([
      { decision: 'asking', text: '你 19 岁那年是不是经历过压力性的转折？' },
    ]);
    const session = new CalibrationSession(runner);
    const { firstQuestion } = await session.start(COMMON_OPTS);
    expect(firstQuestion).toContain('19 岁');
    expect(spy).toHaveBeenCalledTimes(1);
    const arg = spy.mock.calls[0][0];
    expect(arg.round).toBe(1);
    expect(arg.history).toEqual([]);
    expect(arg.signalTable.candidatesMeta).toHaveLength(3);
    expect(arg.userAge).toBeGreaterThan(0);
  });

  it('happy path: AI eventually locks → returns correctedDate from chosen candidate', async () => {
    const { runner } = makeAI([
      { decision: 'asking', text: 'Q1' },
      { decision: 'asking', text: 'Q2' },
      { decision: 'asking', text: 'Q3' },
      { decision: 'locked', text: '看起来你出生在酉时。', lockedCandidate: 'before' },
    ]);
    const session = new CalibrationSession(runner);
    await session.start(COMMON_OPTS);
    const r1 = await session.submitAnswer('那年我转学了');
    expect(r1.nextStep.type).toBe('next_question');
    const r2 = await session.submitAnswer('又一次类似的事');
    expect(r2.nextStep.type).toBe('next_question');
    const r3 = await session.submitAnswer('对，那段时间压力很大');
    expect(r3.nextStep.type).toBe('locked');
    if (r3.nextStep.type === 'locked') {
      expect(r3.nextStep.candidateId).toBe('before');
      expect(r3.nextStep.correctedDate).toBeInstanceOf(Date);
      expect(r3.nextStep.correctedDate.getHours()).toBe(18); // before = 戌-1 = 酉(18)
      expect(r3.nextStep.summary).toContain('酉时');
    }
  });

  it('gave_up path: AI returns gave_up after answers are inconclusive', async () => {
    const { runner } = makeAI([
      { decision: 'asking', text: 'Q1' },
      { decision: 'asking', text: 'Q2' },
      { decision: 'gave_up', text: '三盘信号混合，无法确认。' },
    ]);
    const session = new CalibrationSession(runner);
    await session.start(COMMON_OPTS);
    await session.submitAnswer('不太记得了');
    const r2 = await session.submitAnswer('也不确定');
    expect(r2.nextStep.type).toBe('gave_up');
    if (r2.nextStep.type === 'gave_up') {
      expect(r2.nextStep.reason).toContain('三盘');
    }
  });

  it('throws when submitAnswer is called before start()', async () => {
    const session = new CalibrationSession({ runRound: jest.fn() });
    await expect(session.submitAnswer('x')).rejects.toThrow(/call start\(\) first/);
  });

  it('throws if AI declares locked without candidateId', async () => {
    const { runner } = makeAI([
      { decision: 'asking', text: 'Q1' },
      // 故意不给 lockedCandidate
      { decision: 'locked', text: '锁了' },
    ]);
    const session = new CalibrationSession(runner);
    await session.start(COMMON_OPTS);
    await expect(session.submitAnswer('回答')).rejects.toThrow(/candidateId/);
  });

  it('throws if AI tries to lock/give_up on the very first round', async () => {
    const { runner } = makeAI([
      { decision: 'gave_up', text: '不该这样' },
    ]);
    const session = new CalibrationSession(runner);
    await expect(session.start(COMMON_OPTS)).rejects.toThrow(/首轮/);
  });

  it('throws TOO_YOUNG when minor user has no detectable signals', async () => {
    // 直接 spy 两个 extractor 让信号表全 'none'，绕开 BaziEngine/iztro 的复杂依赖。
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const ev = require('../extractEvents');
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const zv = require('../extractZiweiEvents');
    const evSpy = jest.spyOn(ev, 'extractEventsForCandidate').mockReturnValue({});
    const zvSpy = jest.spyOn(zv, 'extractZiweiEventsForCandidate').mockReturnValue({});
    try {
      const recentBirth = new Date();
      recentBirth.setFullYear(recentBirth.getFullYear() - 10);
      recentBirth.setHours(12, 0, 0, 0);
      const session = new CalibrationSession({ runRound: jest.fn() });
      await expect(
        session.start({ birthDate: recentBirth, gender: '男', longitude: 116.4 }),
      ).rejects.toThrow('TOO_YOUNG');
    } finally {
      evSpy.mockRestore();
      zvSpy.mockRestore();
    }
  });

  it('throws LOW_SIGNAL when adult user has no detectable signals', async () => {
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const ev = require('../extractEvents');
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const zv = require('../extractZiweiEvents');
    const evSpy = jest.spyOn(ev, 'extractEventsForCandidate').mockReturnValue({});
    const zvSpy = jest.spyOn(zv, 'extractZiweiEventsForCandidate').mockReturnValue({});
    try {
      const session = new CalibrationSession({ runRound: jest.fn() });
      await expect(session.start(COMMON_OPTS)).rejects.toThrow('LOW_SIGNAL');
    } finally {
      evSpy.mockRestore();
      zvSpy.mockRestore();
    }
  });
});
