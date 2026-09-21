import { analyzeQimenTiming, type QimenTimingRequest } from '../timing';
import { QimenEngine } from '../QimenEngine';
import type { QimenChart, Palace } from '../types';
import { toTrueSolarTime } from '../../bazi/TrueSolarTime';

// Literal condition plate. Its deliberately reordered rows test identity binding;
// it is not a recast and the expected timing branches are chapter-6 examples.
function plate(changes:Partial<QimenChart>={}):QimenChart {
  return {
    setupTime:'2004-05-09T04:00:00.000Z', calculationTime:'2004-05-09T04:00:00.000Z',
    question:'本月该工作事项何时变化', questionType:'career',
    questionContext:{subject:'self',event:'工作事项',timeHorizon:'near'},
    dayGanZhi:'戊子',hourGanZhi:'甲戌',monthGanZhi:'己巳',
    method:{level:'standard',algorithm:'zhuanpan-qimen-chai-bu-v1',centerPolicy:'fixed-kun-2; tian-qin-follows-tian-rui',clockPolicy:'beijing-standard',timezone:'UTC+08:00',caveats:[]},
    palaces:[
      {id:2,name:'坤',wuXing:'土',diPanGan:'癸',tianPanGan:'戊',bamen:'开门',jiuxing:'天心',bashen:'六合'},
      {id:8,name:'艮',wuXing:'土',diPanGan:'戊',tianPanGan:'庚',bamen:'生门',jiuxing:'天任',bashen:'九地'},
      {id:9,name:'离',wuXing:'火',diPanGan:'壬',tianPanGan:'辛',bamen:'景门',jiuxing:'天英',bashen:'太阴'},
      {id:5,name:'中',wuXing:'土',diPanGan:'乙',tianPanGan:'乙',bamen:null,jiuxing:'天禽',bashen:null},
    ] as Palace[],
    hourVoid:{scope:'hour',ganZhi:'甲戌',xun:'甲戌',branches:['申','酉'],sourceId:'qimen-hour-void-horse-v1',palaces:[{palaceId:2,branches:['申'],palaceBranches:['未','申'],coverage:'partial'}]},
    horse:{scope:'hour',ganZhi:'甲戌',branch:'申',palaceId:2,sourceId:'qimen-hour-void-horse-v1'},
    ...changes,
  } as QimenChart;
}
const request:QimenTimingRequest={focus:'employment',event:'本人工作事项在本月的变化',timeUnit:'day',window:{end:'2004-05-20T00:00:00+08:00'}};
const run=(c=plate(),r:QimenTimingRequest=request)=>analyzeQimenTiming(c,r);

describe('source-selected Qimen timing on an immutable original plate',()=>{
  it('binds employment to the actual opening door and lets palace void override the same palace horse',()=>{
    const c=plate(),saved=JSON.stringify(c),r=run(c);
    expect(r.selection).toMatchObject({established:true,symbol:'开门',palaceId:2,objectPath:'/palaces/0/bamen'});
    expect(r.triggers.map(t=>[t.ruleId,t.branches])).toEqual([['void-fill',['未','申']],['void-clash',['丑','寅']]]);
    expect(r.opposing).toEqual(expect.arrayContaining([expect.objectContaining({ruleId:'horse-value',reason:'suppressed-by-void'})]));
    expect(r.supported).toEqual(expect.arrayContaining([expect.objectContaining({condition:'palace-void',factPaths:['/hourVoid/palaces/0'],coverage:'partial'})]));
    expect(r.outcomeEstablished).toBe(false);
    expect(JSON.stringify(c)).toBe(saved);
  });
  it('enumerates the chapter-6 Zi-day empty-Kun example as Chou/Yin before fill, with 23:00 boundaries',()=>{
    const r=run();
    expect(r.dates.slice(0,2).map(d=>[d.ganZhi,d.startsAt,d.endsAt,d.triggerIds])).toEqual([
      ['己丑','2004-05-09T15:00:00.000Z','2004-05-10T15:00:00.000Z',['void-clash']],
      ['庚寅','2004-05-10T15:00:00.000Z','2004-05-11T15:00:00.000Z',['void-clash']],
    ]);
    expect(r.dates.slice(0,2).every(d=>d.firstWindow)).toBe(true);
    expect(r.dates.find(d=>d.ganZhi==='乙未')?.firstWindow).toBe(false);
  });
  it('uses fill first in the chapter-6 Si-day empty-Kun example',()=>{
    const r=run(plate({setupTime:'2004-05-14T04:00:00.000Z',dayGanZhi:'癸巳'}));
    expect(r.dates.slice(0,2).map(d=>[d.ganZhi,d.triggerIds])).toEqual([['乙未',['void-fill']],['丙申',['void-fill']]]);
  });
  it('preserves the source partial-Wei Kun example as full palace triggers, without borrowing another empty palace',()=>{
    // Both literal source days 戊子/癸巳 belong to 甲申旬, whose empty branches are 午未.
    // Its example still expressly names 丑寅冲未申 and 未申填实. No missing hour is reconstructed.
    const c=plate({hourVoid:{...plate().hourVoid!,ganZhi:'甲申',xun:'甲申',branches:['午','未'],palaces:[
      {palaceId:2,branches:['未'],palaceBranches:['未','申'],coverage:'partial'},
      {palaceId:9,branches:['午'],palaceBranches:['午'],coverage:'full'},
    ]}});
    expect(run(c).triggers.map(t=>t.branches)).toEqual([['未','申'],['丑','寅']]);
    expect(c.hourVoid!.palaces[0].branches).toEqual(['未']);
    c.hourVoid!.palaces=c.hourVoid!.palaces.filter(p=>p.palaceId!==2);
    c.horse={...c.horse!,branch:'寅',palaceId:8};
    expect(run(c).triggers).toEqual([]);expect(run(c).dates).toEqual([]);
  });
  it('requires the explicit unit and bounded window despite a near horizon',()=>{
    const r=run(plate(),{focus:'employment',event:'本月工作事项'});
    expect(r.triggers).toHaveLength(2);expect(r.dates).toEqual([]);
    expect(r.unresolved).toEqual(expect.arrayContaining(['time-unit','calendar-window']));
  });
  it('uses only the selected palace horse, suppresses tomb, and never borrows another palace void',()=>{
    const c=plate({hourVoid:{...plate().hourVoid!,palaces:[]}});
    c.palaces[0].bamen='生门';c.palaces[1].bamen='开门';
    c.horse={...c.horse!,branch:'寅',palaceId:8};
    const r=run(c);
    expect(r.triggers.map(t=>[t.ruleId,t.branches])).toEqual([['horse-value',['寅']],['horse-clash',['申']]]);
    expect(r.opposing).toEqual(expect.arrayContaining([expect.objectContaining({ruleId:'tomb-value',reason:'suppressed-by-horse'})]));
    c.horse={...c.horse,branch:'申',palaceId:2};
    expect(run(c).triggers.map(t=>[t.ruleId,t.branches])).toEqual([['tomb-value',['丑']],['tomb-clash',['未']]]);
  });
  it('retains competing same-tier stem tomb and instrument punishment without making one win',()=>{
    const c=plate({dayGanZhi:'庚子',hourVoid:{...plate().hourVoid!,palaces:[]}});
    const r=run(c,{...request,focus:'self'});
    expect(r.triggers.map(t=>[t.ruleId,t.branches])).toEqual([['tomb-value',['丑']],['tomb-clash',['未']],['punishment-combine',['巳']]]);
    expect(r.conflicts).toEqual(expect.arrayContaining([expect.objectContaining({ruleIds:['tomb-value','tomb-clash','punishment-combine']})]));
  });
  it('applies the literal Xin-in-Li punishment example to the chosen original stem',()=>{
    const c=plate({dayGanZhi:'辛卯'});
    const r=run(c,{...request,focus:'self'});
    expect(r.triggers.map(t=>[t.ruleId,t.branches])).toEqual([['punishment-combine',['未']]]);
    expect(r.dates[0].ganZhi).toBe('乙未');
  });
  it('uses the original hidden Jia identity for tomb, and its carrier branch for a palace clash',()=>{
    const c=plate({dayGanZhi:'甲子',hourVoid:{...plate().hourVoid!,palaces:[]},horse:{...plate().horse!,branch:'寅',palaceId:8}});
    expect(run(c,{...request,focus:'self'})).toMatchObject({selection:{symbol:'甲',carrierStem:'戊'},triggers:[{ruleId:'tomb-value',branches:['未']},{ruleId:'tomb-clash',branches:['丑']}]});
    c.palaces[0].id=9;c.palaces[2].id=1;
    expect(run(c,{...request,focus:'self'}).triggers.map(t=>[t.ruleId,t.branches])).toEqual([['instrument-clash-combine',['丑']]]);
  });
  it('does not choose both sides of a combination when the source leaves the target unspecified',()=>{
    const c=plate({hourVoid:{...plate().hourVoid!,palaces:[]}});
    c.palaces[0].id=8;c.palaces[1].id=7;
    const r=run(c,{...request,focus:'self'});
    expect(r.selection.established).toBe(true);
    expect(r.triggers).toEqual([]);expect(r.dates).toEqual([]);
    expect(r.unresolved).toContain('instrument-combination-clash-target');
  });
  it('requires higher-priority facts without requiring an irrelevant horse beneath established void',()=>{
    const noVoid=run(plate({hourVoid:undefined}),{...request,focus:'self'});
    expect(noVoid.triggers).toEqual([]);expect(noVoid.dates).toEqual([]);
    expect(noVoid.unresolved).toContain('original-hour-void');
    const noHorse=run(plate({hourVoid:{...plate().hourVoid!,palaces:[]},horse:undefined}),{...request,focus:'self'});
    expect(noHorse.triggers).toEqual([]);expect(noHorse.dates).toEqual([]);
    expect(noHorse.unresolved).toContain('original-hour-horse');
    expect(run(plate({horse:undefined})).dates[0].ganZhi).toBe('己丑');
  });
  it('refuses wrong/ambiguous occurrences, proxy-self and incompatible chart conventions',()=>{
    expect(run(plate(),{...request,focus:'explicit',object:{candidateId:'day-stem',objectPath:'/palaces/1/diPanGan'}}).selection.established).toBe(false);
    expect(run(plate(),{...request,focus:'explicit',object:{candidateId:'day-stem',objectPath:'/palaces/3/tianPanGan'}}).selection.established).toBe(false);
    expect(run(plate({questionContext:{subject:'parent'}}),{...request,focus:'self'}).selection.established).toBe(false);
    const c=plate();c.palaces[1].bamen='开门';expect(run(c).selection.established).toBe(false);
    c.method.algorithm='other';expect(run(c).unresolved).toContain('incompatible-chart-method');
  });
  it('selects hosted sky independently and does not use its earth or center record',()=>{
    const c=plate({dayGanZhi:'乙丑'});c.palaces[0].hostedDiPanGan='乙';c.palaces[2].hostedTianPanGan='乙';
    const r=run(c,{...request,focus:'self'});
    expect(r.selection).toMatchObject({objectPath:'/palaces/2/hostedTianPanGan',palaceId:9,symbol:'乙'});
    expect(r.triggers).toEqual([]);expect(r.dates).toEqual([]);
    expect(r.assessmentStatus).toBe('unresolved');
    expect(r.unresolved).toContain('event-specific-strength-timing');
  });
  it('uses explicit current inclusion and reports result truncation',()=>{
    const c=plate({setupTime:'2004-05-10T04:00:00.000Z'});
    const include=run(c,{...request,window:{...request.window!,includeCurrent:true,maxCandidates:1}});
    expect(include.dates[0]).toMatchObject({ganZhi:'己丑',eligibleStart:'2004-05-10T04:00:00.000Z'});
    expect(include.searchPolicy).toMatchObject({truncated:true,searchComplete:false,reason:'candidate-limit'});
    expect(run(c).dates[0].ganZhi).toBe('庚寅');
  });
  it('bounds long searches and validates date/unit/limit input instead of interpreting arbitrary JS dates',()=>{
    expect(run(plate(),{...request,window:{end:'2009-01-01T00:00:00Z',maxCandidates:256}}).searchPolicy).toMatchObject({truncated:true,searchComplete:false,reason:'period-limit'});
    for(const window of [{end:'2004-05-20'}, {end:'2004-02-30T00:00:00Z'}, {end:'2004-01-01T00:00:00Z'}, {end:'2005-01-01T00:00:00Z',maxCandidates:0}]) {
      expect(()=>run(plate(),{...request,window})).toThrow();
    }
  });
  it('does not accept impossible ISO offsets, missing clock policies or an unbounded request',()=>{
    expect(()=>run(plate(),{...request,window:{end:'2005-01-01T00:00:00+14:59'}})).toThrow();
    const c=plate();delete c.method.clockPolicy;
    expect(run(c).unresolved).toContain('chart-clock-policy');expect(run(c).dates).toEqual([]);
    expect(run(plate(),{...request,window:undefined}).dates).toEqual([]);
  });
  it('finishes an empty future-only window without implying an unsearched interval',()=>{
    const r=run(plate(),{...request,window:{end:'2004-05-09T05:00:00Z'}});
    expect(r.dates).toEqual([]);
    expect(r.searchPolicy).toMatchObject({searchComplete:true,truncated:false,searchedUntil:'2004-05-09T05:00:00.000Z'});
  });
  it('keeps hour branches across civil midnight and excludes the present interval unless explicitly included',()=>{
    const c=plate({setupTime:'2004-05-09T14:59:59.000Z'});
    const r=run(c,{...request,timeUnit:'hour',window:{end:'2004-05-10T00:00:00Z'}});
    expect(r.dates.map(d=>[d.branch,d.startsAt,d.endsAt])).toEqual([
      ['丑','2004-05-09T17:00:00.000Z','2004-05-09T19:00:00.000Z'],
      ['寅','2004-05-09T19:00:00.000Z','2004-05-09T21:00:00.000Z'],
    ]);
    c.setupTime='2004-05-09T17:00:00.000Z';
    expect(run(c,{...request,timeUnit:'hour',window:{end:'2004-05-10T00:00:00Z'}}).dates[0].branch).toBe('寅');
    expect(run(c,{...request,timeUnit:'hour',window:{end:'2004-05-10T00:00:00Z',includeCurrent:true}}).dates[0].branch).toBe('丑');
  });
  it('inverts apparent-solar boundaries to physical instants while keeping month boundaries physical',()=>{
    const c=plate();c.method={...c.method,clockPolicy:'apparent-solar',longitude:120};
    const r=run(c),start=new Date(r.dates[0].startsAt);
    // At 120 E in early May, the sundial runs several minutes ahead of civil time.
    expect(start.getTime()).toBeLessThan(Date.parse('2004-05-09T15:00:00Z'));
    expect(start.getTime()).toBeGreaterThan(Date.parse('2004-05-09T14:50:00Z'));
    expect(toTrueSolarTime(start,120).toISOString()).toBe('2004-05-09T15:00:00.000Z');
    expect(toTrueSolarTime(new Date(start.getTime()-1),120).getTime()).toBeLessThan(Date.parse('2004-05-09T15:00:00Z'));
    const req:QimenTimingRequest={...request,timeUnit:'month',window:{end:'2005-01-01T00:00:00Z'}};
    expect(run(c,req).dates).toEqual(run(plate(),req).dates);
  });
  it('uses actual Jie and Lichun boundaries for months/years, with all reason IDs retained',()=>{
    const month=run(plate(),{...request,timeUnit:'month',window:{end:'2005-01-01T00:00:00Z'}});
    expect(month.dates[0].ganZhi).toBe('辛未');
    expect(month.dates[0].startsAt.slice(0,10)).toBe('2004-07-06'); // 小暑 UTC date, not lunar 6/1.
    const year=run(plate(),{...request,timeUnit:'year',window:{end:'2011-01-01T00:00:00Z'}});
    expect(year.dates[0].ganZhi).toBe('己丑');
    expect(year.dates[0].startsAt.slice(0,10)).toBe('2009-02-03'); // 2009立春 UTC.
  });
  it('matches the source 2004-05-29 noon plate and exposes timing only when requested',()=>{
    const e=new QimenEngine(),args={setupTime:new Date('2004-05-29T04:00:00Z'),question:'工作事项',questionType:'career' as const,questionContext:{subject:'self' as const,event:'工作事项',timeHorizon:'near' as const}};
    const original=e.setup(args);
    expect(original).toMatchObject({dayGanZhi:'戊申',hourGanZhi:'戊午',juNumber:8,zhiFuPalaceId:8,tianQinPalaceId:4});
    expect(original.palaces.find(p=>p.id===2)).toMatchObject({bamen:'开门',jiuxing:'天心',tianPanGan:'丙'});
    expect(original.timing).toBeUndefined();
    const timed=e.setup({...args,timingRequest:{...request,window:{end:'2004-06-10T00:00:00Z'}}});
    expect(timed.palaces).toEqual(original.palaces);
    expect(timed.timing?.dates[0].ganZhi).toBe('甲寅');
    const derived=e.reassessQuestion(timed,{question:'新问财务',questionType:'wealth',questionContext:{subject:'self',event:'新问题',timeHorizon:'far'}});
    expect(derived.timing).toBeUndefined();expect(derived.palaces).toBe(timed.palaces);
  });
});
