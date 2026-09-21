import type { QimenChart, TianGan } from './types';
import type { RuleSource } from '../rules/provenance';
import { qimenQuestionObjects } from './questionObjects';
import { assertCalendarRange, beijingDateParts, getCalendarPillars, getSolarTerms } from '../calendar/precision';
import { toTrueSolarTime } from '../bazi/TrueSolarTime';

export type QimenTimingUnit='year'|'month'|'day'|'hour';
export interface QimenTimingRequest {
  /** Explicit event focus, never inferred from the broad question category. */
  focus:'employment'|'profit'|'relationship'|'self'|'explicit';
  event:string;
  object?:{candidateId:string;objectPath:string};
  timeUnit?:QimenTimingUnit;
  window?:{end:string;includeCurrent?:boolean;maxCandidates?:number};
}
export interface QimenTimingTrigger {
  ruleId:string;branches:string[];priority:number;objectPath:string;factPaths:string[];sourceId:string;
}
export interface QimenTimingDate {
  unit:QimenTimingUnit;ganZhi:string;branch:string;startsAt:string;endsAt:string;
  eligibleStart:string;eligibleEnd:string;triggerIds:string[];firstWindow:boolean;
}
export interface QimenTimingAnalysis {
  methodVersion:string;sourceIDs:string[];event:string;focus:QimenTimingRequest['focus'];
  assessmentStatus:'conditional-calendar-candidates'|'conditional-triggers-only'|'unresolved';outcomeEstablished:false;
  selection:{established:boolean;candidateId?:string;objectPath?:string;palaceId?:number;symbol?:string;carrierStem?:TianGan;reason:string};
  triggers:QimenTimingTrigger[];
  supported:{condition:string;factPaths:string[];coverage?:'full'|'partial'}[];
  opposing:{ruleId:string;reason:string;factPaths:string[]}[];
  conflicts:{ruleIds:string[];reason:string}[];unresolved:string[];dates:QimenTimingDate[];
  searchPolicy:{timezone:'UTC+08:00';dayBoundary:'23:00';yearBoundary:'exact-lichun';monthBoundary:'exact-jie';
    clockPolicy:string;solarInversePolicy:string;includeCurrent:boolean;maxCandidates:number;maxPeriods:number;
    requestedEnd?:string;searchedUntil?:string;truncated:boolean;searchComplete:boolean;reason:string};
}

const BASE='https://www.aqioo.com/qmdjxdyyjs/';
export const QIMEN_TIMING_SOURCE:RuleSource={
  id:'qimen-xdyy-timing-v1',version:'1',title:'奇门遁甲现代应用技术：对象条件优先应期',
  editionStatus:'electronic-transcription-not-print-collated',
  scope:'同一选定对象：宫空先于马，马先于墓刑冲合；显式时间单位及有界条件候选',
  references:[
    {url:BASE+'167816.html',locator:'第03章 第二节中五寄宫',sha256:'06c5d8f574ccdfcb8e9df3b8452d8c65829a225e056a3cac81d618d437ea500b',quote:'需要说明的是奇门遁甲的中五宫在一般的情况下均寄在坤二宫，也就是说中五宫中的九星天禽星和所在的三奇六仪在运转时随坤二宫的天芮星及其三奇六仪运转'},
    {url:BASE+'167810.html',locator:'第06章 第一步及第三步1至6',sha256:'dab3897adc647067952b8813d4979ebe3db27ed37282a0ebc47753e9b0543ad5',quote:'如果用神宫逢空亡，无论用神是否临马星、刑冲、生旺、墓绝、庚格、值使门均用冲空、填空为应期。'},
    {url:BASE+'167810.html',locator:'第06章 第三步3：开门入墓直接例证',sha256:'dab3897adc647067952b8813d4979ebe3db27ed37282a0ebc47753e9b0543ad5',quote:'如开门为用神，落在艮八宫入墓，戊子日预测，到丑年、月、日、时则为应期或冲丑的未年、月、日、时为应期。'},
    {url:BASE+'167817.html',locator:'第02章 十干长生墓支、十二地支合冲及宫位',sha256:'6caea61e307f4ced210a012c77d391f23fb01ad8172eae71c93db4ce708e8697'},
    {url:BASE+'167813.html',locator:'第04章 13、六仪击刑六个落宫；与第06章甲午辛例互校',sha256:'3dd0817ce52fb78ed8ee587a1ea8b5d731ec58fb9dbc91e8a23aca405cf5fa31'},
    {url:BASE+'167802.html',locator:'第08章 工作就业；开门为工作，日干为求测者',sha256:'cd2fc6c0238e425c2955d5d85ec0cb8ebecf01337ace2eb69a4f46d6ba1e4d01'},
    {url:BASE+'167807.html',locator:'经营求财：生门为利润利息；不等于一切财务事件',sha256:'e66dc4605a2ea265dc52824df511ae60aae21209d9910c96cb88aa2e70c60c40'},
    {url:BASE+'167808.html',locator:'恋爱婚姻：六合为婚姻用神；不据性别代取伴侣',sha256:'39f14beac1bde7677c8a55e87e9113508dcc5f6bc3ee7f4ed659ba847e58a574'},
  ],
  limitations:['网页电子转录未经纸本校勘，不归作已核作者原版','年月日时必须明确；远近和宫数均不自动转换成期限','宫空采用全宫触发支，仍公开具体空支及partial/full；不是本宫每一支均为旬空','墓刑冲合同层未规定唯一顺序，保留竞争分支；不混入转载刑墓优先法','无空马墓刑冲合时，事件生旺衰墓分支仍未裁决；补充宫支参考不自动生成日期','不推断事件成功、失败或健康预后；日期仅为所选对象的条件候选','历法边界、搜索上限、包含当前区间与排序属于显式产品约定'],
};

const BRANCHES=[...'子丑寅卯辰巳午未申酉戌亥'];
const PALACE_BRANCHES:Record<number,string[]>={1:['子'],2:['未','申'],3:['卯'],4:['辰','巳'],6:['戌','亥'],7:['酉'],8:['丑','寅'],9:['午']};
const TOMB:Record<TianGan,string>={甲:'未',乙:'戌',丙:'戌',丁:'丑',戊:'戌',己:'丑',庚:'丑',辛:'辰',壬:'辰',癸:'未'};
const INSTRUMENT:Partial<Record<TianGan,string>>={戊:'子',己:'戌',庚:'申',辛:'午',壬:'辰',癸:'寅'};
const PUNISH:Partial<Record<TianGan,number>>={戊:3,己:2,庚:8,辛:9,壬:4,癸:4};
const clash=(b:string)=>BRANCHES[(BRANCHES.indexOf(b)+6)%12];
const combine=(b:string)=>BRANCHES[(13-BRANCHES.indexOf(b))%12];
const MAX_PERIODS:Record<QimenTimingUnit,number>={year:24,month:120,day:512,hour:512};
const ISO=/^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d{1,3})?(Z|[+-](?:(?:0\d|1[0-3]):[0-5]\d|14:00))$/;
function instant(value:string):Date {
  const m=typeof value==='string'?ISO.exec(value):null;
  if(!m)throw new RangeError('时间必须含秒与明确时区');
  const [year,month,day,hour,minute,second]=m.slice(1,7).map(Number);
  const days=new Date(Date.UTC(year,month,0)).getUTCDate();
  if(month<1||month>12||day<1||day>days||hour>23||minute>59||second>59)throw new RangeError('无效公历日期');
  const date=new Date(value);assertCalendarRange(date);return date;
}

/** Reuses immutable original plate only. No QimenEngine.setup, no event-outcome claim. */
export function analyzeQimenTiming(chart:QimenChart, request:QimenTimingRequest):QimenTimingAnalysis {
  const start=instant(chart.setupTime),unit=request.timeUnit;
  if(!['employment','profit','relationship','self','explicit'].includes(request.focus))throw new RangeError('无效应期对象类型');
  if(unit!==undefined&&!['year','month','day','hour'].includes(unit))throw new RangeError('无效应期时间单位');
  const end=request.window?instant(request.window.end):undefined;
  const max=request.window?.maxCandidates??32;
  if(!Number.isInteger(max)||max<1||max>256)throw new RangeError('候选上限须为1至256');
  if(end&&end.getTime()<=start.getTime())throw new RangeError('应期窗口结束须晚于起局时刻');
  if(request.window?.includeCurrent!==undefined&&typeof request.window.includeCurrent!=='boolean')throw new RangeError('includeCurrent须为布尔值');
  const result:QimenTimingAnalysis={methodVersion:QIMEN_TIMING_SOURCE.id,sourceIDs:[QIMEN_TIMING_SOURCE.id,'qimen-hour-void-horse-v1'],focus:request.focus,event:request.event,
    assessmentStatus:'unresolved',outcomeEstablished:false,selection:{established:false,reason:'object-not-selected'},
    triggers:[],supported:[],opposing:[],conflicts:[],unresolved:[],dates:[],
    searchPolicy:{timezone:'UTC+08:00',dayBoundary:'23:00',yearBoundary:'exact-lichun',monthBoundary:'exact-jie',clockPolicy:chart.method.clockPolicy??'unspecified',solarInversePolicy:chart.method.clockPolicy==='apparent-solar'?'earliest-physical-millisecond-with-projected-clock-at-boundary':'none',includeCurrent:request.window?.includeCurrent??false,maxCandidates:max,maxPeriods:unit?MAX_PERIODS[unit]:0,truncated:false,searchComplete:false,reason:'not-enumerated',...(end?{requestedEnd:end.toISOString()}:{})}};
  const unresolved=result.unresolved;
  if(chart.method.algorithm!=='zhuanpan-qimen-chai-bu-v1'||chart.method.centerPolicy!=='fixed-kun-2; tian-qin-follows-tian-rui')unresolved.push('incompatible-chart-method');
  if(!request.event?.trim())unresolved.push('single-event');
  if(!unit)unresolved.push('time-unit');
  if(!end)unresolved.push('calendar-window');
  // A complete question category never substitutes for an explicit event focus.
  const found:{candidateId:string;objectPath:string;palaceId:number;symbol:string;carrierStem?:TianGan}[]=[];
  if(request.focus==='self'||request.focus==='explicit'){
    if(request.focus==='self'&&chart.questionContext?.subject!=='self')unresolved.push('self-subject-required');
    if(!chart.dayGanZhi||!chart.hourGanZhi)unresolved.push('original-pillars');
    else {
      const candidates=qimenQuestionObjects(chart.questionType,chart.questionContext??{},chart.palaces,{day:chart.dayGanZhi,hour:chart.hourGanZhi}).candidates;
      for(const c of candidates)for(const o of c.occurrences){
        const allowed=o.palaceId!==5&&(o.isEffectiveSky||o.plate==='door'||o.plate==='star'||o.plate==='deity');
        if(allowed&&(request.focus==='self'?c.id==='day-stem':request.object?.candidateId===c.id&&request.object.objectPath===o.objectPath))found.push({candidateId:c.id,objectPath:o.objectPath,palaceId:o.palaceId,symbol:c.symbol,carrierStem:c.carrierStem});
      }
    }
  }else{
    const symbol=request.focus==='employment'?'开门':request.focus==='profit'?'生门':'六合';
    const field=request.focus==='relationship'?'bashen':'bamen';
    chart.palaces.forEach((p,i)=>{if(p.id!==5&&p[field]===symbol)found.push({candidateId:`category-${field==='bashen'?'deity':'door'}-${symbol}`,objectPath:`/palaces/${i}/${field}`,palaceId:p.id,symbol});});
  }
  if(found.length!==1)unresolved.push(found.length>1?'ambiguous-object':'selected-object');
  if(unresolved.some(x=>!['time-unit','calendar-window'].includes(x)))return result;
  const selected=found[0],palaceBranches=PALACE_BRANCHES[selected.palaceId];
  if(!palaceBranches){unresolved.push('outer-palace');return result;}
  result.selection={...selected,established:true,reason:request.focus==='explicit'?'explicit-candidate-occurrence':`explicit-${request.focus}-focus`};
  const all:QimenTimingTrigger[]=[];
  const add=(ruleId:string,branches:string[],priority:number,factPaths:string[])=>all.push({ruleId,branches:[...new Set(branches)],priority,objectPath:selected.objectPath,factPaths,sourceId:QIMEN_TIMING_SOURCE.id});
  const emptyIndex=chart.hourVoid?.palaces.findIndex(p=>p.palaceId===selected.palaceId)??-1;
  if(!chart.hourVoid){unresolved.push('original-hour-void');return result;}
  if(emptyIndex<0&&!chart.horse){unresolved.push('original-hour-horse');return result;}
  if(emptyIndex>=0){
    const path=`/hourVoid/palaces/${emptyIndex}`;
    result.supported.push({condition:'palace-void',factPaths:[path],coverage:chart.hourVoid!.palaces[emptyIndex].coverage});
    add('void-fill',palaceBranches,1,[path,selected.objectPath]);
    add('void-clash',palaceBranches.map(clash),1,[path,selected.objectPath]);
  }
  if(chart.horse?.palaceId===selected.palaceId){
    result.supported.push({condition:'hour-horse',factPaths:['/horse',selected.objectPath]});
    add('horse-value',[chart.horse.branch],2,['/horse/branch',selected.objectPath]);
    add('horse-clash',[clash(chart.horse.branch)],2,['/horse/branch',selected.objectPath]);
  }
  // Stem tomb uses the original identity, not the stem carrying a hidden 甲.
  const tomb=TOMB[selected.symbol as TianGan]??(selected.symbol==='开门'?'丑':undefined);
  if(tomb&&palaceBranches.includes(tomb)){
    result.supported.push({condition:'object-tomb',factPaths:[selected.objectPath]});
    add('tomb-value',[tomb],3,[selected.objectPath]);add('tomb-clash',[clash(tomb)],3,[selected.objectPath]);
  }
  const carrier=selected.carrierStem,hidden=carrier&&INSTRUMENT[carrier];
  if(carrier&&hidden){
    if(PUNISH[carrier]===selected.palaceId)add('punishment-combine',[combine(hidden)],3,[selected.objectPath]);
    else if(palaceBranches.includes(clash(hidden)))add('instrument-clash-combine',[combine(hidden)],3,[selected.objectPath]);
    else if(palaceBranches.includes(combine(hidden))){
      result.supported.push({condition:'instrument-palace-combination',factPaths:[selected.objectPath]});
      // "临合就以冲" does not identify which member is the timing target.
      // Preserve that open branch instead of silently selecting either/both.
      if(!all.some(t=>t.priority<3))unresolved.push('instrument-combination-clash-target');
    }
  }
  // Chapter 6's supplemental palace-branch reference is not an unconditional
  // replacement for step 4's event-specific strength and outcome prerequisites.
  unresolved.push('event-outcome-not-adjudicated');
  if(!all.length){
    if(!unresolved.includes('instrument-combination-clash-target'))unresolved.push('event-specific-strength-timing');
    return result;
  }
  const first=Math.min(...all.map(t=>t.priority));
  result.triggers=all.filter(t=>t.priority===first);
  result.opposing=all.filter(t=>t.priority>first).map(t=>({ruleId:t.ruleId,reason:first===1?'suppressed-by-void':'suppressed-by-horse',factPaths:t.factPaths}));
  if(first===3&&result.triggers.some(t=>t.ruleId.startsWith('tomb'))&&result.triggers.some(t=>!t.ruleId.startsWith('tomb')))
    result.conflicts.push({ruleIds:result.triggers.map(t=>t.ruleId),reason:'source-does-not-order-tomb-versus-punishment-clash-combination'});
  // Every trigger remains conditional on the named event; palace symbols alone do not prove an outcome.
  result.assessmentStatus='conditional-triggers-only';
  if(!unit||!end)return result;
  if(!['beijing-standard','apparent-solar'].includes(chart.method.clockPolicy??'')){unresolved.push('chart-clock-policy');return result;}
  if(chart.method.clockPolicy==='apparent-solar'&&(chart.method.longitude===undefined||!Number.isFinite(chart.method.longitude)||Math.abs(chart.method.longitude)>180)){unresolved.push('chart-longitude');return result;}
  enumerate(chart,start,end,unit,result);
  result.assessmentStatus='conditional-calendar-candidates';
  return result;
}

function enumerate(chart:QimenChart,start:Date,end:Date,unit:QimenTimingUnit,result:QimenTimingAnalysis):void {
  const policy=result.searchPolicy,solar=chart.method.clockPolicy==='apparent-solar';
  const clock=(millis:number)=>solar?toTrueSolarTime(new Date(millis),chart.method.longitude!).getTime():millis;
  // Monotonic inverse of this version's apparent-solar clock, with integer millisecond boundary semantics.
  const physical=(target:number)=>{
    if(!solar)return target;
    let low=target-86400000,high=target+86400000;
    while(high-low>1){const mid=Math.floor((low+high)/2);if(clock(mid)>=target)high=mid;else low=mid;}
    return high;
  };
  const from=start.getTime(),until=end.getTime();
  let cursor:number,next:number;
  const step=unit==='hour'?7200000:86400000;
  const interval=(at:number):[number,number]=>{
    if(unit==='day'||unit==='hour'){
      const floor=Math.floor((clock(at)-15*3600000)/step)*step+15*3600000;
      return [physical(floor),physical(floor+step)];
    }
    const year=beijingDateParts(new Date(at)).year;
    const terms=[year-1,year,year+1].filter(y=>y>=1900&&y<=2101).flatMap(y=>getSolarTerms(y).filter((t,i)=>unit==='year'?t.name==='立春':i%2===0).map(t=>t.instant.getTime())).sort((a,b)=>a-b);
    const i=terms.findIndex(t=>t>at);
    if(i<1)throw new RangeError('历法区间超出已验证范围');
    return [terms[i-1],terms[i]];
  };
  [cursor,next]=interval(from);
  if(!policy.includeCurrent)[cursor,next]=interval(next);
  let count=0,lastFirstEnd:number|undefined,firstClosed=false;
  while(cursor<until&&count<policy.maxPeriods){
    const eligible=Math.max(cursor,from),eligibleEnd=Math.min(next,until);
    const instantDate=new Date(eligible);
    const pillars=getCalendarPillars(instantDate,solar?{solarTime:new Date(clock(eligible))}:{});
    const ganZhi=pillars[unit],branch=ganZhi[1];
    const triggerIds=result.triggers.filter(t=>t.branches.includes(branch)).map(t=>t.ruleId);
    if(triggerIds.length){
      if(result.dates.length===policy.maxCandidates){policy.truncated=true;policy.reason='candidate-limit';policy.searchedUntil=new Date(cursor).toISOString();return;}
      if(lastFirstEnd!==undefined&&cursor!==lastFirstEnd)firstClosed=true;
      const firstWindow=!firstClosed;
      if(firstWindow)lastFirstEnd=next;
      result.dates.push({unit,ganZhi,branch,startsAt:new Date(cursor).toISOString(),endsAt:new Date(next).toISOString(),eligibleStart:new Date(eligible).toISOString(),eligibleEnd:new Date(eligibleEnd).toISOString(),triggerIds,firstWindow});
    }
    count++;policy.searchedUntil=new Date(Math.min(next,until)).toISOString();
    if(next>=until){cursor=until;break;}
    [cursor,next]=interval(next);
  }
  policy.truncated=cursor<until;
  policy.searchComplete=!policy.truncated;
  if(policy.searchComplete)policy.searchedUntil=end.toISOString();
  policy.reason=policy.truncated?'period-limit':'window-complete';
}
