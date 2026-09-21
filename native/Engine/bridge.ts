import { createNatalAstronomy, validateNatalAstronomy } from './src/astronomy/natal';
import { reassessQuestion } from './src/divination/reassessQuestion';
import { BaziEngine } from './src/bazi/BaziEngine';
import { ZiweiEngine } from './src/ziwei/ZiweiEngine';
import { validMonthlyBasis } from './src/ziwei/monthly';
import { InsightEngine } from './src/bazi/InsightEngine';
import { DayunEngine } from './src/bazi/DayunEngine';
import { MarriageEngine } from './src/marriage/MarriageEngine';
import { getTodayInfo } from './src/calendar';
import { currentSolarTerm } from './src/qimen/helpers/solarTerms';
import { buildCandidates } from './src/calibration/buildCandidates';
import { extractEventsForCandidate } from './src/calibration/extractEvents';
import { extractZiweiEventsForCandidate } from './src/calibration/extractZiweiEvents';
import { ALL_HANDLERS, ALL_TOOLS } from './src/ai/tools';
import { buildEvidenceFromToolCalls } from './src/ai/tools/evidence';
import { CALENDAR_POLICY, assertCalendarRange, beijingDateParts, fromBeijingParts } from './src/calendar/precision';
import { annualCycle, annualReference } from './src/ai/tools/annual';
import { validateToolArguments } from './src/ai/tools/validation';

declare const __ENGINE_REVISION__: string;
const ENGINE_REVISION = typeof __ENGINE_REVISION__ === 'undefined' ? 'development-unbundled' : __ENGINE_REVISION__;

type Birth = { year: number; month: number; day: number; hour: number; minute: number; gender: '男' | '女'; longitude: number; timeZoneID?: string };
function dateOf(b: Birth): Date {
  if (!b || typeof b !== 'object') throw new Error('出生资料无效');
  if (b.timeZoneID && b.timeZoneID !== 'Asia/Shanghai') throw new Error('目前排盘使用北京时间，请先换算为北京时间。');
  if (!Number.isFinite(b.longitude) || b.longitude < -180 || b.longitude > 180) throw new Error('出生地经度无效');
  if (![b.year,b.month,b.day,b.hour,b.minute].every(Number.isInteger)) throw new Error('出生日期须为整数');
  const d = fromBeijingParts(b.year,b.month,b.day,b.hour,b.minute);
  assertCalendarRange(d);
  const p = beijingDateParts(d);
  if (p.year !== b.year || p.month !== b.month || p.day !== b.day || p.hour !== b.hour || p.minute !== b.minute || !['男','女'].includes(b.gender)) throw new Error('出生日期无效');
  return d;
}
const bazi = new BaziEngine();
const ziwei = new ZiweiEngine();
function charts(b: Birth) {
  const date = dateOf(b);
  return { mingPan: bazi.calculate(date, b.gender, b.longitude), ziweiPan: ziwei.compute(b) };
}
function birthKey(b: Birth): string {
  dateOf(b);
  return JSON.stringify([b.year,b.month,b.day,b.hour,b.minute,b.gender,b.longitude,b.timeZoneID ?? 'Asia/Shanghai']);
}

// Only native-owned, integrity-checked local records are supplied here. Model
// tool arguments and imported notebooks cannot supply a natal snapshot.
function natalCharts(input: any): ReturnType<typeof charts> {
  if (input.natal === undefined) return charts(input.birth);
  const n = input.natal;
  const key = birthKey(input.birth);
  const date = dateOf(input.birth);
  if (!n || n.schemaVersion !== 1 || n.engineRevision !== ENGINE_REVISION || n.birthKey !== key ||
      n.calendarPolicy?.version !== CALENDAR_POLICY.version ||
      n.mingPan?.calculationPolicy?.version !== CALENDAR_POLICY.version ||
      !n.mingPan?.qiYun || !n.mingPan?.daYunList?.length ||
      !['year','month','day','hour'].every(p => n.mingPan?.siZhu?.[p]?.ganZhi?.gan && n.mingPan?.siZhu?.[p]?.ganZhi?.zhi) ||
      !Array.isArray(n.ziweiPan?.palaces) || n.ziweiPan.palaces.length !== 12 || !n.personality ||
      !validMonthlyBasis(n.ziweiPan?.monthlyBasis) ||
      !n.ziweiPan?.natalYear || n.ziweiPan?.decadalSchedule?.periods?.length !== 12 ||
      n.ziweiPan?.palaceFlights?.algorithm !== 'suji-ziwei-palace-flights-1' || n.ziweiPan?.palaceFlights?.edges?.length !== 48 ||
      new Date(n.mingPan.birthDateTime).getTime() !== date.getTime() ||
      new Date(n.ziweiPan.birthDateTime).getTime() !== date.getTime() ||
      n.mingPan.gender !== input.birth.gender || n.ziweiPan.gender !== input.birth.gender) {
    throw new Error('本命档案已失效，请重新建立档案');
  }
  // Rehydrate Date fields after persistent JSON storage. Copy so handlers do
  // not mutate the saved snapshot across questions or reference instants.
  const copy = JSON.parse(JSON.stringify(n));
  return {
    mingPan: {...copy.mingPan,birthDateTime:new Date(copy.mingPan.birthDateTime)},
    ziweiPan: {...copy.ziweiPan,birthDateTime:new Date(copy.ziweiPan.birthDateTime)},
  };
}

export async function dispatch(input: any): Promise<any> {
  if (!input || typeof input !== 'object' || Array.isArray(input)) throw new Error('无效引擎请求');
  // No current-time read, calendar or original cast is needed for an explicit supplement.
  if (input.command === 'reassess-question') {
    const definition = ALL_TOOLS.find(tool => tool.function.name === input.name);
    if (!definition || !['cast_liuyao','setup_qimen'].includes(input.name)) throw new Error('无效的原盘方法');
    validateToolArguments(definition,input.arguments);
    const result = reassessQuestion(input,ENGINE_REVISION);
    return {result,evidence:buildEvidenceFromToolCalls([{call:{id:input.sourceCallID,name:input.name,arguments:input.arguments},result}])};
  }
  if (input.now !== undefined && (typeof input.now !== 'string' || !/T.*(?:Z|[+-]\d{2}:\d{2})$/.test(input.now))) throw new Error('参考时刻须包含时区');
  const now = input.now ? new Date(input.now) : new Date();
  if (!Number.isFinite(now.getTime())) throw new Error('参考时刻无效');
  const currentYear = beijingDateParts(now).year;
  const yearOf = (value: unknown): number => {
    if (typeof value !== 'number' || !Number.isInteger(value) || value < 1901 || value > 2100) throw new Error('年份须为1901–2100');
    return value;
  };
  const referenceFor = (year:number) => annualReference(year,now);
  switch(input.command) {
    case 'metadata': return {engineRevision:ENGINE_REVISION, calendarPolicy:CALENDAR_POLICY};
    case 'calendar': {
      if (input.day !== undefined && (typeof input.day !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(input.day))) throw new Error('日历日期无效');
      const d = input.day ? new Date(`${input.day}T12:00:00+08:00`) : now;
      assertCalendarRange(d);
      if (input.day && d.toISOString().slice(0,10) !== input.day) throw new Error('日历日期无效');
      return { ...getTodayInfo(d), solarTerm: currentSolarTerm(d) };
    }
    case 'natal-astronomy': return createNatalAstronomy(birthKey(input.birth),dateOf(input.birth),ENGINE_REVISION);
    case 'natal': {
      const { mingPan, ziweiPan } = charts(input.birth);
      return { schemaVersion:1, engineRevision:ENGINE_REVISION, birthKey:birthKey(input.birth), calendarPolicy:CALENDAR_POLICY,
        mingPan, ziweiPan, personality:new InsightEngine(mingPan).getPersonalityInsight() };
    }
    case 'profile': {
      const { mingPan, ziweiPan } = natalCharts(input);
      const insight = new InsightEngine(mingPan);
      const timing = new DayunEngine(mingPan);
      const year = yearOf(input.year ?? currentYear);
      return { mingPan, ziweiPan, personality: input.natal?.personality ?? insight.getPersonalityInsight(), daily: insight.getDailyInsight(now), timing: insight.getTimingInsight(year,referenceFor(year)), forecast: {...timing.getYearForecast(year,referenceFor(year)), annualCycle:annualCycle(year,now), requestReferenceDate:now.toISOString()} };
    }
    case 'forecast': {
      const { mingPan } = natalCharts(input);
      const year = yearOf(input.year);
      return { timing: new InsightEngine(mingPan).getTimingInsight(year,referenceFor(year)), forecast: {...new DayunEngine(mingPan).getYearForecast(year,referenceFor(year)), annualCycle:annualCycle(year,now), requestReferenceDate:now.toISOString()} };
    }
    case 'tools': return ALL_TOOLS;
    case 'tool': {
      const handler = ALL_HANDLERS[input.name];
      if (!handler) throw new Error(`未知工具：${input.name}`);
      const definition = ALL_TOOLS.find(tool => tool.function.name === input.name)!;
      validateToolArguments(definition, input.arguments ?? {});
      if(input.name==='get_natal_astronomy') {
        const key=birthKey(input.birth),instant=dateOf(input.birth);
        const astronomy=input.astronomy===undefined?createNatalAstronomy(key,instant,ENGINE_REVISION):validateNatalAstronomy(input.astronomy,key,instant,ENGINE_REVISION);
        const result=await handler(input.arguments??{},{mingPan:null,ziweiPan:null,now,astronomy});
        return {result,evidence:buildEvidenceFromToolCalls([{call:{id:input.id??'native',name:input.name,arguments:input.arguments??{}},result}])};
      }
      const isCast = ['cast_liuyao', 'setup_qimen'].includes(input.name);
      const ctx = input.birth && !isCast ? natalCharts(input) : { mingPan: null, ziweiPan: null };
      if (!input.birth && !['cast_liuyao', 'setup_qimen'].includes(input.name)) throw new Error('请先在「我的」填写出生资料');
      assertCalendarRange(now);
      const raw = await handler(input.arguments ?? {}, {...ctx, now});
      const result = { ...(raw as object), provenance: {
        engineRevision:ENGINE_REVISION, referenceDate:now.toISOString(), calendarPolicy:CALENDAR_POLICY,
        interpretation:'干支、星曜与盘面为规则计算；强弱评分、用神取舍及文字为指定流派或产品启发式，不是事件概率。',
        baziPolicy:ctx.mingPan?.interpretationPolicy, ziweiPolicy:ctx.ziweiPan?.method,
      }};
      return { result, evidence: buildEvidenceFromToolCalls([{call:{ id: input.id ?? 'native', name: input.name, arguments: input.arguments ?? {} }, result}]) };
    }
    case 'relationship': {
      const a = natalCharts(input).mingPan;
      const b = charts(input.partner).mingPan;
      const { dayGanCompatibility, dayZhiCompatibility } = new MarriageEngine(a,b).getMatchResult();
      return { dayGanCompatibility, dayZhiCompatibility, first: a.riZhu, second: b.riZhu, firstDayPillar:a.siZhu.day.ganZhi, secondDayPillar:b.siZhu.day.ganZhi, note: '传统干支关系仅提供文化视角，不能衡量两个人相处的质量。' };
    }
    case 'candidates': {
      const b = input.birth as Birth;
      return buildCandidates(dateOf(b), b.gender, b.longitude).map(c => ({
        id: c.id, birthDate: c.birthDate.toISOString(), hour: c.birthDate.getHours(),
        dayPillar: c.mingPan.siZhu.day.ganZhi, hourPillar: c.mingPan.siZhu.hour.ganZhi,
        mingGong: c.ziweiPan.mingGongPosition,
        eventsBySystem: {
          bazi: extractEventsForCandidate(c, currentYear),
          ziwei: extractZiweiEventsForCandidate(c, currentYear),
        },
      }));
    }
    default: throw new Error('不支持的引擎请求');
  }
}
export function run(json: string, resolve: (json:string)=>void, reject: (error:string)=>void) {
  Promise.resolve().then(() => dispatch(JSON.parse(json))).then(value => resolve(JSON.stringify(value))).catch(error => reject(String(error?.message ?? error)));
}
