import { BaziEngine } from './src/bazi/BaziEngine';
import { ZiweiEngine } from './src/ziwei/ZiweiEngine';
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

type Birth = { year: number; month: number; day: number; hour: number; minute: number; gender: '男' | '女'; longitude: number; timeZoneID?: string };
function dateOf(b: Birth): Date {
  if (b.timeZoneID && b.timeZoneID !== 'Asia/Shanghai') throw new Error('目前排盘使用北京时间，请先换算为北京时间。');
  if (!Number.isFinite(b.longitude) || b.longitude < -180 || b.longitude > 180) throw new Error('出生地经度无效');
  const d = new Date(b.year, b.month - 1, b.day, b.hour, b.minute);
  if (d.getFullYear() !== b.year || d.getMonth() + 1 !== b.month || d.getDate() !== b.day || d.getHours() !== b.hour || d.getMinutes() !== b.minute || !['男','女'].includes(b.gender)) throw new Error('出生日期无效');
  return d;
}
const bazi = new BaziEngine();
const ziwei = new ZiweiEngine();
function charts(b: Birth) {
  const date = dateOf(b);
  return { mingPan: bazi.calculate(date, b.gender, b.longitude), ziweiPan: ziwei.compute(b) };
}

export async function dispatch(input: any): Promise<any> {
  const now = input.now ? new Date(input.now) : new Date();
  switch(input.command) {
    case 'calendar': {
      const d = input.day ? new Date(`${input.day}T12:00:00+08:00`) : now;
      return { ...getTodayInfo(d), solarTerm: currentSolarTerm(d) };
    }
    case 'profile': {
      const { mingPan, ziweiPan } = charts(input.birth);
      const insight = new InsightEngine(mingPan);
      const timing = new DayunEngine(mingPan);
      return { mingPan, ziweiPan, personality: insight.getPersonalityInsight(), daily: insight.getDailyInsight(now), timing: insight.getTimingInsight(now.getFullYear()), forecast: timing.getYearForecast(input.year ?? now.getFullYear()) };
    }
    case 'forecast': {
      const mingPan = bazi.calculate(dateOf(input.birth), input.birth.gender, input.birth.longitude);
      const year = Number(input.year);
      if (!Number.isInteger(year) || year < 1900 || year > 2100) throw new Error('年份无效');
      return { timing: new InsightEngine(mingPan).getTimingInsight(year), forecast: new DayunEngine(mingPan).getYearForecast(year) };
    }
    case 'tools': return ALL_TOOLS;
    case 'tool': {
      const handler = ALL_HANDLERS[input.name];
      if (!handler) throw new Error(`未知工具：${input.name}`);
      const ctx = input.birth ? charts(input.birth) : { mingPan: null, ziweiPan: null };
      if (!input.birth && !['cast_liuyao', 'setup_qimen'].includes(input.name)) throw new Error('请先在「我的」填写出生资料');
      const result = await handler(input.arguments ?? {}, {...ctx, now});
      return { result, evidence: buildEvidenceFromToolCalls([{call:{ id: input.id ?? 'native', name: input.name, arguments: input.arguments ?? {} }, result}]) };
    }
    case 'relationship': {
      const a = charts(input.birth).mingPan;
      const b = charts(input.partner).mingPan;
      const { dayGanCompatibility, dayZhiCompatibility } = new MarriageEngine(a,b).getMatchResult();
      return { dayGanCompatibility, dayZhiCompatibility, first: a.riZhu, second: b.riZhu, note: '传统干支关系仅提供文化视角，不能衡量两个人相处的质量。' };
    }
    case 'candidates': {
      const b = input.birth as Birth;
      return buildCandidates(dateOf(b), b.gender, b.longitude).map(c => ({
        id: c.id, birthDate: c.birthDate.toISOString(), hour: c.birthDate.getHours(),
        dayPillar: c.mingPan.siZhu.day.ganZhi, hourPillar: c.mingPan.siZhu.hour.ganZhi,
        mingGong: c.ziweiPan.mingGongPosition,
        events: { ...extractEventsForCandidate(c, now.getFullYear()), ...extractZiweiEventsForCandidate(c, now.getFullYear()) },
      }));
    }
    default: throw new Error('不支持的引擎请求');
  }
}
export function run(json: string, resolve: (json:string)=>void, reject: (error:string)=>void) {
  Promise.resolve().then(() => dispatch(JSON.parse(json))).then(value => resolve(JSON.stringify(value))).catch(error => reject(String(error?.message ?? error)));
}
