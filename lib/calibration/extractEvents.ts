import { DayunEngine } from '@/lib/bazi/DayunEngine';
import type { ShiShen } from '@/lib/bazi/types';
import type { Candidate, EventType } from './types';

/**
 * 大运十神 → 大运转事件 类型映射
 *
 * 用神 / 忌神都映射为同一个粗粒度事件类型，由 candidate scoring 模块决定权重。
 * 这里只做"机械翻译"：daYun.shiShen → 对应的 EventType。
 */
const SHISHEN_TO_DAYUN_EVENT: Partial<Record<ShiShen, EventType>> = {
  '七杀': '大运转七杀',
  '正官': '大运转正官',
  '伤官': '大运转伤官',
  '食神': '大运转食神',
  '比肩': '大运转比肩',
  '劫财': '大运转劫财',
  '正印': '大运转正印',
  '偏印': '大运转偏印',
  '正财': '大运转正财',
  '偏财': '大运转偏财',
};

/**
 * 提取某个 candidate 在 [birthYear+1, currentYear] 区间内的关键事件向量
 *
 * 优先级：大运转入年 > 流年关键事件
 * - 大运转入年：startAge + birthYear 落在区间内，返回 '大运转XX'
 * - 其余年份：根据流年十神选取 '流年七杀临身' / '流年伤官见官' / '流年正财动'
 *   其它情况记 'none'，保证返回值覆盖完整年份序列以便 bifurcation 对齐。
 *
 * @param candidate 候选命盘
 * @param currentYear 当前公历年份（含）
 * @returns Record<year, EventType>
 */
export function extractEventsForCandidate(
  candidate: Candidate,
  currentYear: number,
): Record<number, EventType> {
  const dayunEngine = new DayunEngine(candidate.mingPan);
  const dayunList = dayunEngine.getDaYunList();
  const birthYear = candidate.birthDate.getFullYear();
  const events: Record<number, EventType> = {};

  // ── 大运转入年优先 ──────────────────────────────
  for (const dy of dayunList) {
    const transitionYear = birthYear + dy.startAge;
    if (transitionYear > currentYear) break;
    // startAge=0 (出生即转大运) 退化为 birthYear，不视为"事件"
    if (transitionYear <= birthYear) continue;
    const eventType = SHISHEN_TO_DAYUN_EVENT[dy.shiShen];
    if (eventType) events[transitionYear] = eventType;
  }

  // ── 流年关键事件（仅填充未被大运转占据的年份）─────
  for (let year = birthYear + 1; year <= currentYear; year++) {
    if (events[year]) continue;
    const ln = dayunEngine.getCurrentLiuNian(year);
    if (ln.shiShen === '七杀') {
      events[year] = '流年七杀临身';
    } else if (ln.shiShen === '伤官') {
      events[year] = '流年伤官见官';
    } else if (ln.shiShen === '正财' || ln.shiShen === '偏财') {
      events[year] = '流年正财动';
    } else {
      events[year] = 'none';
    }
  }

  return events;
}
