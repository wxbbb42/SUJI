/**
 * 紫微大限事件抽取的单测
 *
 * 紫微大限（10 年一段）的起始年份与天干由"命宫位置"决定，
 * 而命宫位置受时辰索引影响（±1 时辰 → 命宫平移 1 宫）→ 大限干支序列变化
 * → 同一公历年份在三盘上转出不同的「紫微大限转 XX」事件
 *
 * 这里使用真实 iztro + ZiweiEngine + BaziEngine.computeShiShen，
 * 不 mock，因为这一层就是要验证 iztro 的输出转换是否落到正确的 EventType。
 */
import { extractZiweiEventsForCandidate } from '../extractZiweiEvents';
import { buildCandidates } from '../buildCandidates';

describe('extractZiweiEventsForCandidate', () => {
  it('emits 紫微大限转 events at decadal boundary years for adult user', () => {
    const cands = buildCandidates(new Date('1995-08-15T19:30:00+08:00'), '男', 116.4);
    const events = extractZiweiEventsForCandidate(cands[1], 2026);

    const transitions = Object.entries(events).filter(([, ev]) => ev !== 'none');
    expect(transitions.length).toBeGreaterThan(0);
    for (const [, ev] of transitions) {
      expect(ev.startsWith('紫微大限转')).toBe(true);
    }
  });

  it('boundary year stem differs across ±1 时辰 candidates (核心 design assertion)', () => {
    const cands = buildCandidates(new Date('1995-08-15T19:30:00+08:00'), '男', 116.4);
    const evb = extractZiweiEventsForCandidate(cands[0], 2026);
    const evo = extractZiweiEventsForCandidate(cands[1], 2026);
    const eva = extractZiweiEventsForCandidate(cands[2], 2026);

    // 三盘所有年份的事件向量应至少在某些年份不全相同
    const allYears = new Set<number>([
      ...Object.keys(evb), ...Object.keys(evo), ...Object.keys(eva),
    ].map(Number));

    let differCount = 0;
    for (const y of allYears) {
      const a = evb[y] ?? 'none';
      const b = evo[y] ?? 'none';
      const c = eva[y] ?? 'none';
      const set = new Set([a, b, c]);
      if (set.size > 1) differCount += 1;
    }
    expect(differCount).toBeGreaterThan(0);
  });

  it('returns Record<year, EventType> with year keys parseable as 4-digit ints', () => {
    const cands = buildCandidates(new Date('1995-08-15T19:30:00+08:00'), '男', 116.4);
    const events = extractZiweiEventsForCandidate(cands[1], 2026);
    for (const k of Object.keys(events)) {
      expect(/^\d{4}$/.test(k)).toBe(true);
    }
  });
});
