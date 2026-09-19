/**
 * One calendrical policy for every engine. Instants are projected into fixed UTC+08:00,
 * independently of the device timezone/DST. Solar longitude boundaries use the actual
 * instant; apparent solar time may change only the day/hour pillars.
 */
import { Solar, LunarUtil } from 'lunar-javascript';
import type { SolarDate } from 'lunar-javascript';

const BEIJING_OFFSET_MS = 8 * 60 * 60 * 1000;
export const CALENDAR_POLICY = {
  version: 'suji-calendar-2', provider: 'lunar-javascript@1.7.7',
  timezone: 'UTC+08:00', yearBoundary: 'exact-lichun', monthBoundary: 'exact-jie',
  dayBoundary: 'zi-hour-23:00', lunarDayBoundary: 'civil-midnight',
  solarTimeScope: 'day-and-hour-only', yun: 'year-polarity-gender; jie; three-days-per-year; sect-2-minute-conversion',
  supportedCivilYears: [1901, 2100],
} as const;

export function beijingDateParts(date: Date) {
  if (!Number.isFinite(date.getTime())) throw new RangeError('日期无效');
  const d = new Date(date.getTime() + BEIJING_OFFSET_MS);
  return {year:d.getUTCFullYear(),month:d.getUTCMonth()+1,day:d.getUTCDate(),hour:d.getUTCHours(),minute:d.getUTCMinutes(),second:d.getUTCSeconds()};
}
export function assertCalendarRange(date: Date): void {
  const {year}=beijingDateParts(date);
  if(year<1901||year>2100) throw new RangeError('历法验证范围为北京时间 1901–2100 年');
}
export function beijingDateString(date: Date): string {
  const p=beijingDateParts(date); return `${p.year}-${String(p.month).padStart(2,'0')}-${String(p.day).padStart(2,'0')}`;
}
export function fromBeijingParts(year:number,month:number,day:number,hour=0,minute=0,second=0): Date {
  return new Date(Date.UTC(year,month-1,day,hour,minute,second)-BEIJING_OFFSET_MS);
}
export function toSolar(date: Date): SolarDate {
  assertCalendarRange(date);
  return toSolarProjection(date);
}
/** Internal projection can cross one civil-day boundary after a valid input.
 * Keep it private so a solar-time correction cannot widen the public date range.
 */
function toSolarProjection(date: Date): SolarDate {
  const p=beijingDateParts(date);
  return Solar.fromYmdHms(p.year,p.month,p.day,p.hour,p.minute,p.second);
}
export function fromSolar(solar: SolarDate): Date {
  return fromBeijingParts(solar.getYear(),solar.getMonth(),solar.getDay(),solar.getHour(),solar.getMinute(),solar.getSecond());
}
export function getCalendarPillars(instant: Date, options: {solarTime?: Date;dayBoundary?:'zi-hour'|'midnight'}={}) {
  const civil=toSolar(instant).getLunar().getEightChar();
  const solarTime=options.solarTime??instant;
  const offset=solarTime.getTime()-instant.getTime();
  // Longitude [-180,180] relative to 120E plus equation-of-time stays <24h.
  // Valid 1901/2100 civil inputs may internally project into 1900/2101.
  if(!Number.isFinite(offset)||Math.abs(offset)>24*60*60*1000) throw new RangeError('太阳时修正不能超出原时刻24小时');
  const local=toSolarProjection(solarTime).getLunar().getEightChar();
  local.setSect(options.dayBoundary==='midnight'?2:1);
  // The hour-stem follows the selected day-stem, including late Zi in midnight policy.
  const day=local.getDay();
  const branches='子丑寅卯辰巳午未申酉戌亥';
  const stems='甲乙丙丁戊己庚辛壬癸';
  const hourBranch=branches.indexOf(local.getTime()[1]);
  const hour=stems[(stems.indexOf(day[0])%5*2+hourBranch)%10]+branches[hourBranch];
  return {year:civil.getYear(),month:civil.getMonth(),day,hour};
}
export function naYinFor(ganzhi: string): string {
  const name=LunarUtil.NAYIN[ganzhi];
  if(!name) throw new RangeError(`无效干支：${ganzhi}`);
  return name;
}
export function sexagenaryIndex(ganzhi:string):number {
  const index=LunarUtil.JIA_ZI.indexOf(ganzhi);
  if(index<0) throw new RangeError(`无效干支：${ganzhi}`);
  return index;
}
const TERM_NAMES=['小寒','大寒','立春','雨水','惊蛰','春分','清明','谷雨','立夏','小满','芒种','夏至','小暑','大暑','立秋','处暑','白露','秋分','寒露','霜降','立冬','小雪','大雪','冬至'];
const termCache=new Map<number,{name:string;millis:number}[]>();
export function getSolarTerms(year:number):{name:string;instant:Date}[] {
  if(!Number.isInteger(year)||year<1900||year>2101) throw new RangeError('节气年份超出已验证范围');
  let terms=termCache.get(year);
  if(!terms){
    const table=Solar.fromYmdHms(year,6,1,12,0,0).getLunar().getJieQiTable();
    // Upstream uses 冬至 for the PREVIOUS year's winter solstice, DONG_ZHI for this year.
    terms=TERM_NAMES.map(name=>({name,millis:fromSolar(table[name==='冬至'?'DONG_ZHI':name]).getTime()}));
    termCache.set(year,terms);
  }
  return terms.map(t=>({name:t.name,instant:new Date(t.millis)}));
}
export function currentSolarTermAt(instant:Date):string {
  assertCalendarRange(instant);
  const year=beijingDateParts(instant).year;
  const elapsed=[...getSolarTerms(year-1),...getSolarTerms(year)].filter(t=>t.instant.getTime()<=instant.getTime());
  const latest=elapsed[elapsed.length-1];
  if(!latest) throw new RangeError('无法确定当前节气');
  return latest.name;
}
export function lunarCalendarWarnings(instant:Date):string[] {
  const civil=beijingDateString(instant);
  return civil>='2057-09-28'&&civil<'2057-10-28'
    ? ['2057年九月朔接近北京时间午夜：天文模型与香港天文台日期表相差一日，农历日期暂按当前天文模型，需复核。'] : [];
}
