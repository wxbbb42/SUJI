/** Real engine smoke for separated calculation facts. Differences between charts
 * are not empirical evidence for a correct birth time or grounds for auto-lock. */
import { buildCandidates } from '../buildCandidates';
import { extractEventsForCandidate } from '../extractEvents';
import { extractZiweiEventsForCandidate } from '../extractZiweiEvents';
import type { Candidate } from '../types';

function hasNonNoneSignal(cands: Candidate[], currentYear: number): boolean {
  for (const c of cands) {
    const systems = [extractEventsForCandidate(c, currentYear), extractZiweiEventsForCandidate(c, currentYear)];
    if (systems.some(events => Object.values(events).some(event => event !== 'none'))) return true;
  }
  return false;
}

function hasInterCandidateDivergence(cands: Candidate[], currentYear: number): boolean {
  const tables = cands.map(c => ({
    bazi: extractEventsForCandidate(c, currentYear),
    ziwei: extractZiweiEventsForCandidate(c, currentYear),
  }));
  for (const system of ['bazi', 'ziwei'] as const) {
    const years = new Set(tables.flatMap(table => Object.keys(table[system])));
    for (const year of years) {
      if (new Set(tables.map(table => table[system][Number(year)] ?? 'none')).size > 1) return true;
    }
  }
  return false;
}

describe('Candidate signals real-engines integration', () => {
  it('produces non-empty signal table for adult user (real engines)', () => {
    // 1995 年生（2026 年时 31 岁），戌时（19:30）出生
    const cands = buildCandidates(new Date('1995-08-15T19:30:00+08:00'), '男', 116.4);
    expect(hasNonNoneSignal(cands, 2026)).toBe(true);
    expect(hasInterCandidateDivergence(cands, 2026)).toBe(true);
  });

  it('produces divergent signals for female adult born 1990 (real engines)', () => {
    const cands = buildCandidates(new Date('1990-03-12T14:00:00+08:00'), '女', 121.5);
    expect(hasInterCandidateDivergence(cands, 2026)).toBe(true);
  });

  it('produces divergent signals for male adult born 2000 (real engines)', () => {
    const cands = buildCandidates(new Date('2000-11-23T09:00:00+08:00'), '男', 116.4);
    expect(hasInterCandidateDivergence(cands, 2026)).toBe(true);
  });
});
