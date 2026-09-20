import type { Solar } from 'lunar-javascript';
import type { RuleSource } from '../rules/provenance';
import type { PalaceName, ZiweiMonthlyBasis, ZiweiPan } from './types';
import { temporalTransformations } from './transformations';

const BRANCHES = '子丑寅卯辰巳午未申酉戌亥';
const STEMS = '甲乙丙丁戊己庚辛壬癸';
const PALACES:PalaceName[] = ['命宫','兄弟宫','夫妻宫','子女宫','财帛宫','疾厄宫','迁移宫','仆役宫','官禄宫','田宅宫','福德宫','父母宫'];
const cycle = (index:number,mod=12) => ((index%mod)+mod)%mod;

export const ZIWEI_MONTHLY_SOURCE:RuleSource = {
  id:'ziwei-monthly-selected-v1',version:'1',title:'紫微流月：所选农历斗君与月干约定',
  editionStatus:'pinned-engineering-reference',
  scope:'太岁起正月逆至生月、起子顺至生时得斗君，顺布流月；农历年五虎遁月干四化，出生及查询闰月均以15日分界',
  references:[
    {url:'https://unpkg.com/iztro@2.5.8/lib/astro/FunctionalAstrolabe.js',locator:'_getHoroscopeBySolarDate: monthlyIndex / dateLeapAddition / monthly',sha256:'843f55ba39e20107bb00e83f26116ceb3281d88f092081e1d4bb1a9e0e5ab5fc'},
    {url:'https://unpkg.com/lunar-lite@0.2.8/lib/ganzhi.js',locator:'calculateMonthlyGanZhi: normal / FIVE_TIGER / fixLeap',sha256:'5b7ec19b55f1d703bce40694a7dfb172ddbf3358cef2682f7c048c65b01cba2d'},
    {url:'https://unpkg.com/iztro@2.5.8/lib/data/heavenlyStems.js',locator:'mutagen',sha256:'4eb6ee5e3a09db4ede931053de526ab258d0d76908922a1f980d7f996f226191'},
    {url:'https://zh.wikisource.org/wiki/紫微斗數全書/卷二',locator:'安斗君诀；安命身例（闰月异文）',sha256:'1e255c6ae99e6f89ae124ab342554ef1347fc8e68fb8908cba7290d1a38cbb72'},
  ],
  limitations:[
    '选择iztro2.5.8 normal约定；全书电子本支持斗君计数，但闰月另有整月作次月异文，不声称各派一致',
    '使用完整子初23点换日及农历正月换年；闰月前15日当月、16日起次月，实际次月仍按其月数，不顺延全年',
    '月干来自农历年五虎遁，不是八字节月，也不是流月所在本命宫的宫干；壬干仍取左辅化科',
    '流月宫名是覆盖层；四化指向实际本命星宫，不移动本命星、不覆盖生年、大限、流年或宫干关系',
    '只给结构，不推定效力、吉凶或精确应期；未含流日、流时、流曜排布或完整飞星断法',
  ],
};

export function validMonthlyBasis(value:unknown):value is ZiweiMonthlyBasis {
  if (!value || typeof value!=='object') return false;
  const b = value as ZiweiMonthlyBasis;
  return b.algorithm==='suji-ziwei-monthly-basis-1' && Number.isInteger(b.lunarMonth) && b.lunarMonth>=1 && b.lunarMonth<=12
    && Number.isInteger(b.lunarDay) && b.lunarDay>=1 && b.lunarDay<=30 && typeof b.isLeapMonth==='boolean'
    && b.effectiveMonth===b.lunarMonth+(b.isLeapMonth && b.lunarDay>15 ? 1 : 0)
    && typeof b.hourBranch==='string' && b.hourBranch.length===1 && BRANCHES.includes(b.hourBranch);
}

/** Query-only overlay. The caller already applied the selected23h day boundary. */
export function ziweiMonthly(pan:ZiweiPan,effective:ReturnType<typeof Solar.fromYmd>,beforeBirth:boolean) {
  const basis = pan.monthlyBasis;
  if (!validMonthlyBasis(basis)) return {status:'unavailable',reason:'natal-monthly-basis-missing'};
  const sourceId = ZIWEI_MONTHLY_SOURCE.id;
  if (beforeBirth) return {status:'before-birth',scope:'lunar-month',appliesToBirth:false,sourceId,transformations:[]};
  const lunar = effective.getLunar(), lunarYear = lunar.getYear();
  const month = Math.abs(lunar.getMonth()),day = lunar.getDay(),isLeapMonth = lunar.getMonth()<0;
  const effectiveMonth = month+(isLeapMonth && day>15 ? 1 : 0);
  const yearIndex = cycle(lunarYear-4,10), taiSui = cycle(lunarYear-4);
  const douJun = cycle(taiSui-(basis.effectiveMonth-1)+BRANCHES.indexOf(basis.hourBranch));
  const ming = cycle(douJun+effectiveMonth-1);
  // 甲己丙、乙庚戊、丙辛庚、丁壬壬、戊癸甲；寅月起顺排。
  const firstStem = [2,4,6,8,0][yearIndex%5];
  const stem = STEMS[cycle(firstStem+effectiveMonth-1,10)],branch = BRANCHES[cycle(effectiveMonth+1)];
  const at = (index:number) => {
    const position = BRANCHES[cycle(index)],matches = pan.palaces.filter(p=>p.position===position);
    if (matches.length!==1) throw new Error('紫微档案缺少唯一流月对应宫位');
    return {position,natalPalace:matches[0].name};
  };
  return {
    status:'available',scope:'lunar-month',assessmentStatus:'structural-only',appliesToBirth:true,sourceId,
    calendar:{lunarYear,month,day,isLeapMonth,effectiveMonth},birthBasis:{...basis},
    douJun:at(douJun),mingGong:at(ming),ganZhi:stem+branch,stem,branch,
    palaces:PALACES.map((palace,i)=>({palace,...at(ming-i)})),
    transformations:temporalTransformations(pan,stem,'monthly-month-stem',sourceId),
    method:{algorithm:'suji-ziwei-monthly-1',monthBoundary:'lunar-month',leapMonth:'split-at-day-15',stemMethod:'lunar-year-five-tiger',palaceMethod:'dou-jun'},
  };
}
