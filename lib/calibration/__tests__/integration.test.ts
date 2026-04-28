// LLM-driven session 端到端测试（使用 deterministic engine mocks）：
// 验证从 start() 到 locked / gave_up 的完整状态流转，
// 配合 mock AI 模拟"先问 N 轮再 lock"和"中途 give_up"两条主线。

import type { ShiShen } from '@/lib/bazi/types';

jest.mock('@/lib/bazi/BaziEngine', () => ({
  BaziEngine: jest.fn().mockImplementation(() => ({
    calculate: (date: Date, gender: '男' | '女') => ({
      birthDateTime: date,
      gender,
      siZhu: {} as any,
      riZhu: { gan: '甲' } as any,
      wuXingStrength: {} as any,
      branchRelations: [],
      stemRelations: [],
      geJu: {} as any,
      shenSha: [],
      daYunDirection: '顺行' as const,
      daYunStartAge: 3,
      daYunList: [],
      lunarDate: '',
      yearNaYin: '',
      kongWang: [],
      taiYuan: {} as any,
      mingGong: {} as any,
    }),
  })),
}));

const DAYUN_BY_HOUR: Record<number, Array<{ startAge: number; endAge: number; shiShen: ShiShen }>> = {
  18: [
    { startAge: 3, endAge: 12, shiShen: '比肩' },
    { startAge: 13, endAge: 22, shiShen: '七杀' },
    { startAge: 23, endAge: 32, shiShen: '正官' },
  ],
  20: [
    { startAge: 3, endAge: 12, shiShen: '比肩' },
    { startAge: 13, endAge: 22, shiShen: '正官' },
    { startAge: 23, endAge: 32, shiShen: '伤官' },
  ],
  22: [
    { startAge: 3, endAge: 12, shiShen: '比肩' },
    { startAge: 13, endAge: 22, shiShen: '比肩' },
    { startAge: 23, endAge: 32, shiShen: '正印' },
  ],
};

jest.mock('@/lib/bazi/DayunEngine', () => {
  const ctor: any = jest.fn().mockImplementation((mingPan: any) => {
    const hour = mingPan.birthDateTime.getHours();
    return {
      getDaYunList: () => DAYUN_BY_HOUR[hour] ?? [],
      getCurrentLiuNian: (year: number) => ({ year, shiShen: 'none' }),
    };
  });
  ctor.computeShiShen = jest.fn().mockReturnValue('比肩');
  return { DayunEngine: ctor };
});

import { CalibrationSession } from '../CalibrationSession';

const COMMON_OPTS = {
  birthDate: new Date('1995-08-15T20:00:00+08:00'),
  gender: '男' as const,
  longitude: 116.4,
};

describe('CalibrationSession integration (LLM-driven)', () => {
  it('runs full ask → lock cycle: AI sees signal table and chooses a candidate', async () => {
    const ai = {
      runRound: jest.fn()
        .mockResolvedValueOnce({ decision: 'asking', text: 'Q1' })
        .mockResolvedValueOnce({ decision: 'asking', text: 'Q2' })
        .mockResolvedValueOnce({ decision: 'asking', text: 'Q3' })
        .mockResolvedValueOnce({
          decision: 'locked',
          text: '看起来你出生在亥时(21-23)。',
          lockedCandidate: 'after',
        }),
    };
    const session = new CalibrationSession(ai);
    const { firstQuestion } = await session.start(COMMON_OPTS);
    expect(firstQuestion).toBe('Q1');

    // session 把 signalTable 传给 AI——验证内容包含 3 个候选 metadata
    const firstCall = ai.runRound.mock.calls[0][0];
    expect(firstCall.signalTable.candidatesMeta.map((c: any) => c.id)).toEqual([
      'before', 'origin', 'after',
    ]);

    const r1 = await session.submitAnswer('a');
    expect(r1.nextStep.type).toBe('next_question');
    const r2 = await session.submitAnswer('b');
    expect(r2.nextStep.type).toBe('next_question');
    const r3 = await session.submitAnswer('c');
    expect(r3.nextStep.type).toBe('locked');
    if (r3.nextStep.type === 'locked') {
      expect(r3.nextStep.candidateId).toBe('after');
      // after = 戌+1 = 亥(22)
      expect(r3.nextStep.correctedDate.getHours()).toBe(22);
      expect(r3.nextStep.summary).toContain('亥时');
    }
  });

  it('runs ask → give_up cycle when AI gives up', async () => {
    const ai = {
      runRound: jest.fn()
        .mockResolvedValueOnce({ decision: 'asking', text: 'Q1' })
        .mockResolvedValueOnce({ decision: 'asking', text: 'Q2' })
        .mockResolvedValueOnce({ decision: 'gave_up', text: '信号不足。' }),
    };
    const session = new CalibrationSession(ai);
    await session.start(COMMON_OPTS);
    await session.submitAnswer('不记得');
    const last = await session.submitAnswer('也不记得');
    expect(last.nextStep.type).toBe('gave_up');
    if (last.nextStep.type === 'gave_up') {
      expect(last.nextStep.reason).toContain('信号不足');
    }
  });
});
