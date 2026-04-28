import type { BifurcatedYear, Candidate, CandidateId, EventType } from './types';
import { extractEventsForCandidate } from './extractEvents';
import { extractZiweiEventsForCandidate } from './extractZiweiEvents';

/**
 * 计算事件三元组的"分歧度"
 *
 * - 3 → 三人事件互不相同
 * - 2 → 恰有两人不同
 * - 1 → 三人完全相同（不构成 bifurcation）
 */
function diversityOf(events: Record<CandidateId, EventType>): number {
  return new Set([events.before, events.origin, events.after]).size;
}

/**
 * 合并八字 + 紫微两个事件源到单个 candidate 的年份向量
 *
 * 设计：紫微大限是真正能区分时辰的信号（八字大运由年柱+月柱决定，与时辰无关），
 * 因此 ziwei 事件优先；若紫微在该年没有转入事件，则回退到八字大运/流年。
 */
function mergeEventsForCandidate(
  candidate: Candidate,
  currentYear: number,
): Record<number, EventType> {
  const baziEv = extractEventsForCandidate(candidate, currentYear);
  const ziweiEv = extractZiweiEventsForCandidate(candidate, currentYear);
  const merged: Record<number, EventType> = { ...baziEv };
  for (const [yearStr, ev] of Object.entries(ziweiEv)) {
    if (ev && ev !== 'none') {
      merged[Number(yearStr)] = ev;
    }
  }
  return merged;
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
 *
 * @param candidates [before, origin, after] 三选一候选盘
 * @param currentYear 当前公历年份
 * @returns BifurcatedYear[] 已排序
 */
export function detectBifurcations(
  candidates: [Candidate, Candidate, Candidate],
  currentYear: number,
): BifurcatedYear[] {
  const evb = mergeEventsForCandidate(candidates[0], currentYear);
  const evo = mergeEventsForCandidate(candidates[1], currentYear);
  const eva = mergeEventsForCandidate(candidates[2], currentYear);

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
