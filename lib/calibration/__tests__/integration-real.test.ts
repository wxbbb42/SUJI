/**
 * end-to-end 设计验证：成年用户 + ±1 时辰 → buildSignalTable 必须产出 non-empty 信号。
 *
 * 用真实 BaziEngine + ZiweiEngine + iztro，不 mock 任何引擎。
 * 这条测试如果回到全 'none'，说明紫微大限/八字大运信号都没接入，
 * LLM 拿不到差异性信号 → 任何 lock 都不可信。
 *
 * 历史背景：八字大运由「年柱+月柱+性别」决定，不依赖时辰，
 * 三盘的八字事件序列完全相同。紫微大限由命宫位置决定，
 * 时辰平移 1 → 命宫平移 1 宫 → 大限干支序列变化 → 同年份不同盘转出不同十神。
 */
import { buildCandidates } from '../buildCandidates';
import { extractEventsForCandidate } from '../extractEvents';
import { extractZiweiEventsForCandidate } from '../extractZiweiEvents';
import type { Candidate, EventType } from '../types';

function hasNonNoneSignal(cands: Candidate[], currentYear: number): boolean {
  for (const c of cands) {
    const merged: Record<number, EventType> = {
      ...extractEventsForCandidate(c, currentYear),
      ...extractZiweiEventsForCandidate(c, currentYear),
    };
    if (Object.values(merged).some(e => e !== 'none')) return true;
  }
  return false;
}

function hasInterCandidateDivergence(cands: Candidate[], currentYear: number): boolean {
  // 至少有一年三盘事件类型不全一样——这是 LLM 用来判别的最小条件。
  const tables = cands.map(c => ({
    ...extractEventsForCandidate(c, currentYear),
    ...extractZiweiEventsForCandidate(c, currentYear),
  }));
  const allYears = new Set<number>();
  for (const t of tables) for (const y of Object.keys(t)) allYears.add(Number(y));
  for (const y of allYears) {
    const set = new Set(tables.map(t => t[y] ?? 'none'));
    if (set.size > 1) return true;
  }
  return false;
}

describe('CalibrationSession real-engines integration', () => {
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
