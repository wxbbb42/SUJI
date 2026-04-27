// 与 buildCandidates.test.ts 同样的限制：BaziEngine 在 jest 环境下因 lunisolar fetalGod
// 插件的 CJS 加载问题无法直接 instantiate。这里 mock 掉 BaziEngine 让 buildCandidates
// 能跑通；同时 mock DayunEngine 返回结构化的固定数据，让 extractEventsForCandidate
// 的事件聚合逻辑可被精确断言。
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

// 三个 candidate 的 daYunList 各异，便于 bifurcation 测试中也能复用此 mock。
// 这里按 birthDate 的 hour 分流：18 → before, 20 → origin, 22 → after。
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

jest.mock('@/lib/bazi/DayunEngine', () => ({
  DayunEngine: jest.fn().mockImplementation((mingPan: { birthDate: Date }) => {
    const hour = mingPan.birthDate.getHours();
    const dayuns = DAYUN_BY_HOUR[hour] ?? DAYUN_BY_HOUR[20];
    return {
      getDaYunList: () => dayuns,
      getCurrentLiuNian: (year: number) => ({
        year,
        shiShen: SHISHEN_CYCLE[((year % 10) + 10) % 10],
      }),
    };
  }),
}));

import { extractEventsForCandidate } from '../extractEvents';
import { buildCandidates } from '../buildCandidates';

describe('extractEventsForCandidate', () => {
  it('returns events for ages 1..currentAge for a 1995 birth in 2026', () => {
    const cands = buildCandidates(new Date('1995-08-15T20:00:00+08:00'), '男', 116.4);
    const events = extractEventsForCandidate(cands[1], 2026);
    expect(Object.keys(events).length).toBeGreaterThan(15);
    expect(Object.keys(events).every(y => /^\d{4}$/.test(y))).toBe(true);
  });

  it('marks 大运 boundary years with 大运转 event', () => {
    const cands = buildCandidates(new Date('1995-08-15T20:00:00+08:00'), '男', 116.4);
    const events = extractEventsForCandidate(cands[1], 2026);
    const hasDayunTransition = Object.values(events).some(e => e.startsWith('大运转'));
    expect(hasDayunTransition).toBe(true);
  });

  it('maps dayun shiShen to corresponding 大运转 event at startAge year', () => {
    // origin (hour=20) 的 daYunList[1] 是 startAge=15 → '伤官'，
    // birthYear=1995，所以 1995+15=2010 应该是 '大运转伤官'。
    const cands = buildCandidates(new Date('1995-08-15T20:00:00+08:00'), '男', 116.4);
    const events = extractEventsForCandidate(cands[1], 2026);
    expect(events[2010]).toBe('大运转伤官');
    // daYunList[2] startAge=25 → '正官'，1995+25=2020 应该是 '大运转正官'。
    expect(events[2020]).toBe('大运转正官');
  });

  it('liu nian 七杀 maps to 流年七杀临身 in non-transition years', () => {
    const cands = buildCandidates(new Date('1995-08-15T20:00:00+08:00'), '男', 116.4);
    const events = extractEventsForCandidate(cands[1], 2026);
    // 找一个非大运转入年，且 SHISHEN_CYCLE[year%10] === '七杀'
    // SHISHEN_CYCLE 索引 6 对应 '七杀'，所以 year % 10 === 6 → 1996, 2006, 2016, 2026
    // 2010, 2020 是 transition；其余应当映射到 '流年七杀临身'
    expect(events[1996]).toBe('流年七杀临身');
    expect(events[2006]).toBe('流年七杀临身');
    expect(events[2016]).toBe('流年七杀临身');
    expect(events[2026]).toBe('流年七杀临身');
  });
});
