import { CalibrationSession } from '../CalibrationSession';

// 沿用其它 calibration 测试同款 mock 模式（看 buildCandidates.test.ts、bifurcation.test.ts）
// 让 BaziEngine + DayunEngine 返回 deterministic fixture，使 detectBifurcations 可控

jest.mock('@/lib/bazi/BaziEngine', () => {
  return {
    BaziEngine: jest.fn().mockImplementation(() => ({
      calculate: (date: Date, gender: '男'|'女', _lon?: number) => ({
        birthDateTime: date,
        gender,
        // 最小占位，DayunEngine 会读这些字段（占位即可，DayunEngine 也被 mock）
        siZhu: {} as any,
        riZhu: {} as any,
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
  };
});

const HOUR_OFFSET: Record<number, number> = { 18: -2, 20: 0, 22: 2 };
const DAYUN_BY_HOUR: Record<number, Array<{ startAge: number; endAge: number; shiShen: string }>> = {
  18: [
    { startAge: 3, endAge: 12, shiShen: '比肩' },
    { startAge: 13, endAge: 22, shiShen: '七杀' },   // 2008
    { startAge: 23, endAge: 32, shiShen: '正官' },
  ],
  20: [
    { startAge: 3, endAge: 12, shiShen: '比肩' },
    { startAge: 13, endAge: 22, shiShen: '正官' },   // 2008
    { startAge: 23, endAge: 32, shiShen: '伤官' },
  ],
  22: [
    { startAge: 3, endAge: 12, shiShen: '比肩' },
    { startAge: 13, endAge: 22, shiShen: '比肩' },   // 2008（与 origin 不同 → 三盘 diversity ≥ 2）
    { startAge: 23, endAge: 32, shiShen: '正印' },
  ],
};

jest.mock('@/lib/bazi/DayunEngine', () => {
  return {
    DayunEngine: jest.fn().mockImplementation((mingPan: any) => {
      const hour = mingPan.birthDateTime.getHours();
      return {
        getDaYunList: () => DAYUN_BY_HOUR[hour] ?? [],
        getCurrentLiuNian: (year: number) => ({
          year,
          ganZhi: { gan: '甲', zhi: '子' },
          shiShen: 'none',  // 流年路径不参与本测试
          interactions: [],
        }),
      };
    }),
  };
});

describe('CalibrationSession integration with deterministic engines', () => {
  it('runs to locked status with forced deltas pointing to before', async () => {
    const ai = { runRound: jest.fn().mockResolvedValue({ question: 'mock-q' }) };
    const session = new CalibrationSession(ai);
    await session.start({
      birthDate: new Date('1995-08-15T20:00:00+08:00'),
      gender: '男',
      longitude: 116.4,
    });
    const r1 = await session.submitAnswerWithForcedDelta('a', { before: 1, origin: 0, after: 0 });
    expect(r1.nextStep.type).toBe('next_question');
    const r2 = await session.submitAnswerWithForcedDelta('b', { before: 1, origin: 0, after: 0 });
    expect(r2.nextStep.type).toBe('locked');
    if (r2.nextStep.type === 'locked') {
      expect(r2.nextStep.candidateId).toBe('before');
    }
  });

  it('reaches gave_up after 2 consecutive uncertain (zero deltas)', async () => {
    const ai = { runRound: jest.fn().mockResolvedValue({ question: 'q' }) };
    const session = new CalibrationSession(ai);
    await session.start({
      birthDate: new Date('1995-08-15T20:00:00+08:00'),
      gender: '男',
      longitude: 116.4,
    });
    await session.submitAnswerWithForcedDelta('a0', { before: 0, origin: 0, after: 0 });
    const last = await session.submitAnswerWithForcedDelta('a1', { before: 0, origin: 0, after: 0 });
    expect(last.nextStep.type).toBe('gave_up');
  });
});
