import { beijingDateParts } from '@engine/calendar/precision';
import type { Candidate, EventType } from './types';

/**
 * Return rule-calculated Ziwei decade transitions, not predicted life events.
 * The configured iztro ageDivide=normal uses nominal age at lunar New Year:
 * target lunar year = birth lunar year + nominal age - 1.
 * No Bazi day stem or Ten Gods enters this Ziwei-only projection.
 */
export function extractZiweiEventsForCandidate(
  candidate: Candidate,
  currentYear: number,
): Record<number, EventType> {
  const birthYear = beijingDateParts(candidate.birthDate).year;
  const lunarBirthYear = candidate.astrolabe.rawDates.lunarDate.lunarYear;
  if (!Number.isInteger(lunarBirthYear)) throw new Error('紫微出生农历年份缺失');
  const events: Record<number, EventType> = {};
  const palaces = candidate.astrolabe.palaces.slice().sort((a, b) => a.decadal.range[0] - b.decadal.range[0]);

  for (const palace of palaces) {
    const [startAge, endAge] = palace.decadal.range;
    if (!Number.isInteger(startAge) || !Number.isInteger(endAge) || startAge < 1 || endAge < startAge) {
      throw new Error('紫微大限年龄区间无效');
    }
    const transitionYear = lunarBirthYear + startAge - 1;
    if (transitionYear > currentYear) break;
    if (transitionYear < birthYear || startAge === 1) continue;
    const name = palace.name.endsWith('宫') ? palace.name : `${palace.name}宫`;
    const stars = palace.majorStars.map(star => star.name).join('、') || '无主星';
    events[transitionYear] = `紫微大限转入本命${name}（${palace.heavenlyStem}${palace.earthlyBranch}；本命主星：${stars}；虚岁${startAge}–${endAge}，农历${transitionYear}年起）`;
  }
  return events;
}
