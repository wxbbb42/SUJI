import { currentSolarTermAt, getSolarTerms } from '@engine/calendar/precision';

/** Astronomical term is evaluated at the physical instant, never a solar-clock offset. */
export const currentSolarTerm = currentSolarTermAt;

export function findSolarTermStart(date:Date): {jieqi:string;startTime:Date} {
  const year=date.getUTCFullYear();
  const terms=[...getSolarTerms(year-1),...getSolarTerms(year),...getSolarTerms(year+1)]
    .filter(t=>t.instant.getTime()<=date.getTime()).sort((a,b)=>b.instant.getTime()-a.instant.getTime());
  if(!terms.length) throw new Error('solar term boundary unavailable');
  return {jieqi:terms[0].name,startTime:terms[0].instant};
}
