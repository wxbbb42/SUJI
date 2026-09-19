import { DayunEngine } from '@engine/bazi/DayunEngine';
import { beijingDateParts } from '@engine/calendar/precision';
import type { Candidate, EventType } from './types';

function timeLabel(date: Date): string {
  const p = beijingDateParts(date);
  const pad = (value: number) => String(value).padStart(2, '0');
  return `${p.year}-${pad(p.month)}-${pad(p.day)} ${pad(p.hour)}:${pad(p.minute)}`;
}

/**
 * Year-indexed Bazi calculation facts for comparison, not life-event predictions.
 * Decade transitions use the exact startDate; integer startAge is only a display
 * label and must not be converted back into a supposedly exact transition year.
 * A lone annual Ten God does not establish a composite pattern or real event.
 */
export function extractEventsForCandidate(
  candidate: Candidate,
  currentYear: number,
): Record<number, EventType> {
  const engine = new DayunEngine(candidate.mingPan);
  const birthYear = beijingDateParts(candidate.birthDate).year;
  const events: Record<number, EventType> = {};

  for (let year = birthYear + 1; year <= currentYear; year++) {
    const annual = engine.getCurrentLiuNian(year);
    events[year] = `八字流年${annual.ganZhi.gan}${annual.ganZhi.zhi}（天干${annual.ganZhi.gan}为${annual.shiShen}；立春换年）`;
  }
  for (const period of engine.getDaYunList()) {
    if (!period.startDate || !period.endDate) continue; // Missing exact dates are not guessed from age.
    const start = new Date(period.startDate), end = new Date(period.endDate);
    if (!Number.isFinite(start.getTime()) || !Number.isFinite(end.getTime()) || start >= end) {
      throw new Error('八字大运日期区间无效');
    }
    const year = beijingDateParts(start).year;
    if (start <= candidate.birthDate || year > currentYear) continue;
    events[year] = `八字大运转入${period.ganZhi.gan}${period.ganZhi.zhi}（天干${period.ganZhi.gan}为${period.shiShen}；${timeLabel(start)}交运，至${timeLabel(end)}前，北京时间）`;
  }
  return events;
}
