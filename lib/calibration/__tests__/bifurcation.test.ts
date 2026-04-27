// 见 extractEvents.test.ts —— 这里复用同样的 mock 策略，让三个 candidate
// 各自有差异化的 daYunList / 流年序列，以制造 bifurcation 年份。
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

// 三个 candidate 的 daYunList 各异，每段的 startAge / shiShen 都不同，
// 用以确保某些年份三人事件不一致。
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

// 让三个 candidate 的流年也有些差异：根据 hour 偏移 cycle 索引
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

import { detectBifurcations } from '../bifurcation';
import { buildCandidates } from '../buildCandidates';

describe('detectBifurcations', () => {
  it('returns years sorted by diversity desc then recency desc', () => {
    const cands = buildCandidates(new Date('1995-08-15T20:00:00+08:00'), '男', 116.4);
    const bifs = detectBifurcations(cands, 2026);
    expect(bifs.length).toBeGreaterThan(0);
    for (let i = 1; i < bifs.length; i++) {
      expect(bifs[i - 1].diversity).toBeGreaterThanOrEqual(bifs[i].diversity);
    }
    for (let i = 1; i < bifs.length; i++) {
      if (bifs[i - 1].diversity === bifs[i].diversity) {
        expect(bifs[i - 1].year).toBeGreaterThanOrEqual(bifs[i].year);
      }
    }
  });

  it('only returns years where at least 2 candidates differ', () => {
    const cands = buildCandidates(new Date('1995-08-15T20:00:00+08:00'), '男', 116.4);
    const bifs = detectBifurcations(cands, 2026);
    for (const b of bifs) {
      expect(b.diversity).toBeGreaterThanOrEqual(2);
      const vals = [b.events.before, b.events.origin, b.events.after];
      const uniq = new Set(vals).size;
      expect(uniq).toBeGreaterThanOrEqual(2);
    }
  });

  it('ageAt computes year - birthYear per candidate', () => {
    const cands = buildCandidates(new Date('1995-08-15T20:00:00+08:00'), '男', 116.4);
    const bifs = detectBifurcations(cands, 2026);
    expect(bifs.length).toBeGreaterThan(0);
    for (const b of bifs) {
      expect(b.ageAt.before).toBe(b.year - cands[0].birthDate.getFullYear());
      expect(b.ageAt.origin).toBe(b.year - cands[1].birthDate.getFullYear());
      expect(b.ageAt.after).toBe(b.year - cands[2].birthDate.getFullYear());
    }
  });

  it('skips years where all three are none', () => {
    const cands = buildCandidates(new Date('1995-08-15T20:00:00+08:00'), '男', 116.4);
    const bifs = detectBifurcations(cands, 2026);
    for (const b of bifs) {
      const allNone = b.events.before === 'none'
        && b.events.origin === 'none'
        && b.events.after === 'none';
      expect(allNone).toBe(false);
    }
  });
});
