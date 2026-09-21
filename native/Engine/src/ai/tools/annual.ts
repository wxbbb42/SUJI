import { beijingDateParts, fromBeijingParts, getCalendarPillars, getSolarTerms } from '../../calendar/precision';

export function activeSolarYear(at: Date): number {
  const civilYear = beijingDateParts(at).year;
  const lichun = getSolarTerms(civilYear).find(t => t.name === '立春')!.instant;
  return at < lichun ? civilYear - 1 : civilYear;
}

export function annualCycle(year: number, at: Date) {
  const start = getSolarTerms(year).find(t => t.name === '立春')!.instant;
  const end = getSolarTerms(year + 1).find(t => t.name === '立春')!.instant;
  return { labelYear: year, startDate: start.toISOString(), endDate: end.toISOString(),
    isActiveAtReference: at >= start && at < end, activeYearAtReference: activeSolarYear(at),
    activeYearGanZhi: getCalendarPillars(at).year };
}

/** Historical/future cycles use an explicit representative instant, never a date outside that cycle. */
export function annualReference(year: number, at: Date): Date {
  return activeSolarYear(at) === year ? at : fromBeijingParts(year, 7, 1, 12);
}
