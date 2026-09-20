import { Solar } from 'lunar-javascript';
import { assertCalendarRange, beijingDateParts, beijingDateString, lunarCalendarWarnings } from '../calendar/precision';
import type { RuleSource } from '../rules/provenance';
import type { DecadalSchedule, ZiweiPan } from './types';

import { temporalTransformations } from './transformations';
import { ziweiMonthly, ZIWEI_MONTHLY_SOURCE } from './monthly';

const BRANCHES = '子丑寅卯辰巳午未申酉戌亥';
const STEMS = '甲乙丙丁戊己庚辛壬癸';

export const ZIWEI_TIMING_SOURCE:RuleSource = {
  id:'ziwei-timing-selected-v1',version:'1',title:'紫微大限与流年：所选现代约定',
  editionStatus:'pinned-engineering-reference',
  scope:'命宫起首限、局数起虚岁、十年一宫；农历换年；大限宫干及流年干四化；太岁所在本命宫',
  references:[
    {url:'https://unpkg.com/iztro@2.5.8/lib/astro/palace.js',locator:'getHoroscope',sha256:'e8473fcb49ab2da101633b6ab4db1faa09b538735cf6bb74c781bfaa59e06ac6'},
    {url:'https://unpkg.com/iztro@2.5.8/lib/astro/FunctionalAstrolabe.js',locator:'_getHoroscopeBySolarDate: nominalAge, decadal, yearly',sha256:'843f55ba39e20107bb00e83f26116ceb3281d88f092081e1d4bb1a9e0e5ab5fc'},
    {url:'https://unpkg.com/iztro@2.5.8/lib/data/heavenlyStems.js',locator:'mutagen',sha256:'4eb6ee5e3a09db4ede931053de526ab258d0d76908922a1f980d7f996f226191'},
  ],
  limitations:[
    '选择阳男阴女顺、阴男阳女逆，命宫以五行局数起首限；全书所读大限段支持顺逆，不能证明本产品完整起限约定',
    '虚岁及流年以农历正月换年，按产品完整子初23点换日；不取八字立春或节气起运',
    '太岁仅标明所在本命宫；四化标记本命星曜的时间层，不迁移星曜、不覆盖生年四化',
    '壬干采用左辅化科；所读全书电子本为天府化科；不同流派可另取表',
    '未含小限、流月、流日、流曜排布或十二宫飞入飞出；结构关系不自动判吉凶与事件应期',
  ],
};

/** Fixed birth-only schedule, serialized in the natal dossier. */
export function decadalSchedule(pan:ZiweiPan):DecadalSchedule {
  const year = pan.natalYear;
  const startAge = ({水二局:2,木三局:3,金四局:4,土五局:5,火六局:6} as Record<string,number>)[pan.fiveElementsClass];
  const index = BRANCHES.indexOf(pan.mingGongPosition);
  if (!year || !startAge || index < 0 || !STEMS.includes(year.stem)) throw new Error('紫微档案缺少起限资料');
  const forward = (STEMS.indexOf(year.stem)%2===0) === (pan.gender==='男');
  return {
    direction:forward?'forward':'reverse',startAge,ageConvention:'lunar-nominal',sourceId:ZIWEI_TIMING_SOURCE.id,
    periods:Array.from({length:12},(_,i)=>{
      const position = BRANCHES[(index+(forward?i:-i)+12)%12];
      const palace = pan.palaces.find(p=>p.position===position);
      if (!palace) throw new Error('紫微档案缺少大限宫位');
      const age = startAge+10*i, startLunarYear = year.lunarYear+age-1;
      return {index:i+1,startAge:age,endAge:age+9,startLunarYear,endLunarYear:startLunarYear+9,palace:palace.name,position,ganZhi:palace.ganZhi};
    }),
  };
}

/** Temporal overlay only: no natal engine call and no edits to the cached pan. */
export function ziweiTiming(pan:ZiweiPan,reference:Date,withMonthly=false) {
  assertCalendarRange(reference);
  const schedule = pan.decadalSchedule, birth = new Date(pan.birthDateTime).getTime();
  if (!pan.natalYear || !schedule || schedule.periods.length!==12 || !Number.isFinite(birth)) throw new Error('紫微档案缺少有效大限资料，请重新建档');
  const civil = beijingDateParts(reference), solar = Solar.fromYmd(civil.year,civil.month,civil.day);
  const effective = civil.hour===23 ? solar.next(1) : solar;
  const lunarYear = effective.getLunar().getYear();
  const stem = STEMS[(lunarYear-4)%10], branch = BRANCHES[(lunarYear-4)%12];
  const nominalAge = lunarYear-pan.natalYear.lunarYear+1;
  const beforeBirth = reference.getTime()<birth;
  const activeDecade = beforeBirth ? null : schedule.periods.find(p=>p.startAge<=nominalAge&&nominalAge<=p.endAge) ?? null;
  const status = beforeBirth ? 'before-birth' : activeDecade ? 'active' : nominalAge<schedule.startAge ? 'before-first-decade' : 'out-of-range';
  const taiSui = pan.palaces.find(p=>p.position===branch);
  if (!taiSui) throw new Error('紫微档案缺少太岁所在宫位');
  return {
    referenceDate:reference.toISOString(),civilDate:beijingDateString(reference),calculationDate:effective.toYmd(),
    nominalAge,status,natalYear:{...pan.natalYear},direction:schedule.direction,startAge:schedule.startAge,
    activeDecade:activeDecade?{...activeDecade}:null,
    decadalTransformations:activeDecade?temporalTransformations(pan,activeDecade.ganZhi[0],'decadal-palace-stem',ZIWEI_TIMING_SOURCE.id):[],
    annual:{lunarYear,ganZhi:stem+branch,stem,branch,appliesToBirth:!beforeBirth,
      taiSui:{position:branch,natalPalace:taiSui.name},
      transformations:beforeBirth?[]:temporalTransformations(pan,stem,'annual-year-stem',ZIWEI_TIMING_SOURCE.id)},
    ...(withMonthly ? {monthly:ziweiMonthly(pan,effective,beforeBirth)} : {}),
    method:{algorithm:'suji-ziwei-timing-1',civilTimeZone:'UTC+08:00',dayBoundary:'zi-hour',yearBoundary:'lunar-new-year',ageConvention:'lunar-nominal'},
    calendarWarnings:lunarCalendarWarnings(reference),ruleSources:[ZIWEI_TIMING_SOURCE,...(withMonthly ? [ZIWEI_MONTHLY_SOURCE] : [])],
  };
}
