import type { Candidate } from '../types';

const periods = [
  { startAge: 15, endAge: 24, ganZhi: { gan: '庚', zhi: '辰' }, shiShen: '偏印', startDate: '2020-12-31T16:00:00Z', endDate: '2030-12-31T16:00:00Z' },
  { startAge: 25, endAge: 34, ganZhi: { gan: '辛', zhi: '巳' }, shiShen: '正印' },
];
jest.mock('@engine/bazi/DayunEngine', () => ({
  DayunEngine: jest.fn().mockImplementation(() => ({
    getDaYunList: () => periods,
    getCurrentLiuNian: (year: number) => year === 2025
      ? { ganZhi: { gan: '乙', zhi: '巳' }, shiShen: '伤官' }
      : year === 2026
        ? { ganZhi: { gan: '丙', zhi: '午' }, shiShen: '偏财' }
        : { ganZhi: { gan: '甲', zhi: '辰' }, shiShen: '食神' },
  })),
}));
import { extractEventsForCandidate } from '../extractEvents';

const candidate = { birthDate: new Date('1995-08-15T20:00:00+08:00'), mingPan: {} } as Candidate;

describe('Bazi calibration facts', () => {
  it('uses the exact Beijing transition year rather than birth year plus rounded age', () => {
    const events = extractEventsForCandidate(candidate, 2026);
    expect(events[2021]).toBe('八字大运转入庚辰（天干庚为偏印；2021-01-01 00:00交运，至2031-01-01 00:00前，北京时间）');
    expect(events[2010]).not.toContain('大运转入');
    expect(events[2020]).not.toContain('大运转入');
  });

  it('does not infer a decade transition when exact dates are missing', () => {
    expect(Object.values(extractEventsForCandidate(candidate, 2026)).filter(e => e.includes('大运转入'))).toHaveLength(1);
  });

  it('keeps annual Ten Gods literal instead of asserting composite patterns or life events', () => {
    const events = extractEventsForCandidate(candidate, 2026);
    expect(events[2025]).toBe('八字流年乙巳（天干乙为伤官；立春换年）');
    expect(events[2026]).toBe('八字流年丙午（天干丙为偏财；立春换年）');
    expect(Object.values(events).join()).not.toMatch(/伤官见官|七杀临身|正财动|子女星动/);
  });

  it('does not emit a future transition or future annual label', () => {
    const events = extractEventsForCandidate(candidate, 2020);
    expect(events[2021]).toBeUndefined();
    expect(Object.keys(events).every(year => Number(year) <= 2020)).toBe(true);
  });
});
