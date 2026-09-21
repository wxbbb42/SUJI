import { assertCalendarRange, beijingDateParts, CALENDAR_POLICY, getSolarTerms } from '../calendar/precision';
import type { DiZhi } from './types';

const JIE_MONTH: Record<string, DiZhi> = {
  小寒:'丑',立春:'寅',惊蛰:'卯',清明:'辰',立夏:'巳',芒种:'午',
  小暑:'未',立秋:'申',白露:'酉',寒露:'戌',立冬:'亥',大雪:'子',
};

/** Civil instant and exact month-Jie interval, never apparent-solar-time shifted. */
export function getBirthMonthContext(civilBirth: Date, expectedMonth: DiZhi) {
  assertCalendarRange(civilBirth);
  const year = beijingDateParts(civilBirth).year;
  const terms = [year-1,year,year+1].flatMap(y=>getSolarTerms(y))
    .filter(t=>Object.prototype.hasOwnProperty.call(JIE_MONTH,t.name))
    .sort((a,b)=>a.instant.getTime()-b.instant.getTime());
  const birthMillis = civilBirth.getTime();
  const nextIndex = terms.findIndex(t=>t.instant.getTime()>birthMillis);
  if (nextIndex < 1) throw new RangeError('Birth instant lacks an enclosing Jie interval');
  const previous = terms[nextIndex-1], next = terms[nextIndex];
  const monthBranch = JIE_MONTH[previous.name];
  if (monthBranch !== expectedMonth) throw new RangeError('Month pillar does not match the civil birth Jie interval');
  const elapsedMillis = birthMillis-previous.instant.getTime();
  return {
    methodVersion:'birth-month-jie-context-v1' as const,
    civilBirthTime:civilBirth.toISOString(),monthBranch,
    jie:{name:previous.name,instant:previous.instant.toISOString()},
    nextJie:{name:next.name,instant:next.instant.toISOString()},
    elapsedMillis,daysAfterJie:elapsedMillis/86400000,
    calendarPolicyVersion:CALENDAR_POLICY.version,provider:CALENDAR_POLICY.provider,
    timeBasis:'civil-instant-utc' as const,solarTimeApplied:false as const,
    termPrecision:'provider-second' as const,
  };
}
export type BirthMonthContext = ReturnType<typeof getBirthMonthContext>;

/** Reject stale/tampered source-bound data instead of accepting an unbound number. */
export function validateBirthMonthContext(context: BirthMonthContext, month: DiZhi): BirthMonthContext {
  const expected = getBirthMonthContext(new Date(context.civilBirthTime),month);
  if (context.methodVersion!==expected.methodVersion || context.monthBranch!==expected.monthBranch ||
      context.civilBirthTime!==expected.civilBirthTime || context.calendarPolicyVersion!==expected.calendarPolicyVersion ||
      context.provider!==expected.provider || context.timeBasis!==expected.timeBasis || context.solarTimeApplied!==false ||
      context.termPrecision!==expected.termPrecision || context.elapsedMillis!==expected.elapsedMillis || context.daysAfterJie!==expected.daysAfterJie ||
      context.jie?.name!==expected.jie.name || context.jie?.instant!==expected.jie.instant ||
      context.nextJie?.name!==expected.nextJie.name || context.nextJie?.instant!==expected.nextJie.instant) {
    throw new RangeError('Birth month context does not match its calendar source and civil instant');
  }
  return expected;
}
