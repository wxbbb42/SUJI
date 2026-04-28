import { DayunEngine } from '@/lib/bazi/DayunEngine';
import type { ShiShen, TianGan } from '@/lib/bazi/types';
import type { Candidate, EventType } from './types';

/**
 * 紫微大限十神 → 紫微大限转事件 类型映射
 *
 * iztro 给每个宫位都挂了一个 decadal { range:[startAge,endAge], heavenlyStem, earthlyBranch }，
 * 把每个 decadal 看成一段 10 年大限。我们以 decadal 起始年为转入点。
 * 转入年的"事件类型"由 decadal 天干相对日主的十神决定（与八字大运同口径）。
 */
const SHISHEN_TO_ZIWEI_DAYUN_EVENT: Partial<Record<ShiShen, EventType>> = {
  '七杀': '紫微大限转七杀',
  '正官': '紫微大限转正官',
  '伤官': '紫微大限转伤官',
  '食神': '紫微大限转食神',
  '比肩': '紫微大限转比肩',
  '劫财': '紫微大限转劫财',
  '正印': '紫微大限转正印',
  '偏印': '紫微大限转偏印',
  '正财': '紫微大限转正财',
  '偏财': '紫微大限转偏财',
};

/**
 * 提取某个 candidate 紫微大限在 [birthYear+1, currentYear] 区间内的转入事件
 *
 * 算法：
 *   1. 对 12 个宫位的 decadal 按 range[0]（起始 age）排序
 *   2. 对每个 decadal，转入年 = birthYear + range[0]
 *   3. 转入年若 ≤ currentYear，记录 EventType（decadal.heavenlyStem 相对日主的十神）
 *   4. 其余年份不填（与 extractEvents.ts 的 dayun 优先逻辑相同，由 bifurcation 合并器决定）
 *
 * 这里之所以能区分时辰：iztro 命宫位置由 birthHourIndex 决定，
 * ±1 时辰 → 命宫平移 1 宫 → 12 个 decadal 的 stem/branch 整体平移
 * → 同一 age 区间在不同候选盘上 stem 不同 → EventType 不同。
 */
export function extractZiweiEventsForCandidate(
  candidate: Candidate,
  currentYear: number,
): Record<number, EventType> {
  const birthYear = candidate.birthDate.getFullYear();
  const dayStem = candidate.mingPan.riZhu.gan as TianGan;
  const events: Record<number, EventType> = {};

  // iztro 原生 palace.decadal 列表（每宫一段 10 年大限）
  // 类型在 iztro 上是 any 的（没有完整 d.ts），用 any 拿值即可
  const palaces: any[] = (candidate.astrolabe as any).palaces ?? [];
  const decadals = palaces
    .map(p => p.decadal)
    .filter((d): d is { range: [number, number]; heavenlyStem: TianGan } =>
      d && Array.isArray(d.range) && typeof d.heavenlyStem === 'string')
    .slice()
    .sort((a, b) => a.range[0] - b.range[0]);

  for (const dec of decadals) {
    const startAge = dec.range[0];
    const transitionYear = birthYear + startAge;
    if (transitionYear > currentYear) break;
    if (transitionYear <= birthYear) continue; // 出生即起的第一段不计为"事件"
    const shishen = DayunEngine.computeShiShen(dayStem, dec.heavenlyStem);
    const eventType = SHISHEN_TO_ZIWEI_DAYUN_EVENT[shishen];
    if (eventType) events[transitionYear] = eventType;
  }

  return events;
}
