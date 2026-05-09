import { currentSolarTerm } from '../solarTerms';

describe('currentSolarTerm', () => {
  it('uses the solar-term transition time, not just the calendar date', () => {
    expect(currentSolarTerm(new Date('2026-04-05T02:00:00+08:00'))).toBe('春分');
    expect(currentSolarTerm(new Date('2026-04-05T03:00:00+08:00'))).toBe('清明');
  });

  it('handles year-end winter terms', () => {
    expect(currentSolarTerm(new Date('2026-12-22T12:00:00+08:00'))).toBe('冬至');
  });
});

