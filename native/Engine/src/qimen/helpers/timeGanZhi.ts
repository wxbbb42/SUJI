/**
 * 通过 lunisolar 计算精确日柱 / 时柱干支
 *
 * 此前 QimenEngine 的 computeTimeGan 用 day+hour 数学近似，
 * 不符合五子遁规则。此处接入 lunisolar.char8ex 给出精确值。
 *
 * 输出：日干、日支、时干、时支
 */

import lunisolar from 'lunisolar';
import { char8ex } from '@lunisolar/plugin-char8ex';
import type { TianGan } from '../types';

let extended = false;
function ensureExtension() {
  if (extended) return;
  lunisolar.extend(char8ex);
  extended = true;
}

export interface TimePillars {
  dayGan: TianGan;
  dayZhi: string;
  hourGan: TianGan;
  hourZhi: string;
}

export function computeTimePillars(time: Date): TimePillars {
  ensureExtension();
  const lsr = lunisolar(time);
  const c8ex = (lsr as any).char8ex(1);
  const day = c8ex.day;
  const hour = c8ex.hour;
  return {
    dayGan: day.stem.name as TianGan,
    dayZhi: day.branch.name as string,
    hourGan: hour.stem.name as TianGan,
    hourZhi: hour.branch.name as string,
  };
}
