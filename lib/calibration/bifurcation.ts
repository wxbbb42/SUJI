import type { BifurcatedYear, Candidate, CandidateId, EventType } from './types';
import { extractEventsForCandidate } from './extractEvents';

/**
 * 计算事件三元组的"分歧度"
 *
 * - 3 → 三人事件互不相同
 * - 2 → 恰有两人不同
 * - 1 → 三人完全相同（不构成 bifurcation）
 */
function diversityOf(events: Record<CandidateId, EventType>): number {
  const vals = [events.before, events.origin, events.after];
  const uniq = new Set(vals);
  if (uniq.size === 3) return 3;
  if (uniq.size === 2) return 2;
  return 1;
}

/**
 * 在三个候选盘的事件向量中，找出能最大区分候选盘的"分歧年份"
 *
 * 排序规则：
 *   1. 分歧度 (diversity) 从高到低
 *   2. 年份从近到远（recency）—— 用户对近期事件记忆更可靠
 *
 * 过滤规则：
 *   - diversity < 2 的年份直接丢弃（三人一致，问也无法区分）
 *   - 三人都是 'none' 的年份丢弃（即使全 none 一致，diversity=1，但显式再 guard 一次）
 *
 * @param candidates [before, origin, after] 三选一候选盘
 * @param currentYear 当前公历年份
 * @returns BifurcatedYear[] 已排序
 */
export function detectBifurcations(
  candidates: [Candidate, Candidate, Candidate],
  currentYear: number,
): BifurcatedYear[] {
  const evb = extractEventsForCandidate(candidates[0], currentYear);
  const evo = extractEventsForCandidate(candidates[1], currentYear);
  const eva = extractEventsForCandidate(candidates[2], currentYear);

  const years = new Set<number>();
  for (const y of Object.keys(evb)) years.add(Number(y));
  for (const y of Object.keys(evo)) years.add(Number(y));
  for (const y of Object.keys(eva)) years.add(Number(y));

  const result: BifurcatedYear[] = [];
  for (const year of years) {
    const events: Record<CandidateId, EventType> = {
      before: evb[year] ?? 'none',
      origin: evo[year] ?? 'none',
      after:  eva[year] ?? 'none',
    };
    const div = diversityOf(events);
    if (div < 2) continue;
    if (events.before === 'none' && events.origin === 'none' && events.after === 'none') continue;
    result.push({
      year,
      ageAt: {
        before: year - candidates[0].birthDate.getFullYear(),
        origin: year - candidates[1].birthDate.getFullYear(),
        after:  year - candidates[2].birthDate.getFullYear(),
      },
      events,
      diversity: div,
    });
  }

  result.sort((a, b) => b.diversity - a.diversity || b.year - a.year);
  return result;
}
