import { getCalendarPillars } from '@engine/calendar/precision';
import type { TianGan } from '../types';

export interface TimePillars { dayGan:TianGan; dayZhi:string; hourGan:TianGan; hourZhi:string }

/** Beijing civil fields; caller may pass a solar-time clock projection for day/hour. */
export function computeTimePillars(time:Date):TimePillars {
  const p=getCalendarPillars(time);
  return {dayGan:p.day[0] as TianGan,dayZhi:p.day[1],hourGan:p.hour[0] as TianGan,hourZhi:p.hour[1]};
}
