import { HexagramEngine } from '../HexagramEngine';
import { efficacyDecisionView } from '../efficacy';
import { getCalendarPillars } from '../../calendar/precision';
import type { QuestionContext } from '../questionJudgment';
import type { QuestionType } from '../types';

// Classical coordinates are not Gregorian dates. Only calendar lookup is replaced;
// najia, object identities, relations, cast and question reassessment remain real.
jest.mock('../../calendar/precision', () => ({ getCalendarPillars: jest.fn() }));
const clock = getCalendarPillars as jest.Mock;
const engine = new HexagramEngine();
const run = (values:number[],month:string,day:string,type:QuestionType='health',context:QuestionContext={subject:'self',event:'原文规则核对',timeHorizon:'near'}) => {
  clock.mockReturnValue({month,day,hour:'庚午'});
  const result=engine.cast({question:'原文规则核对',questionType:type,questionContext:context,
    castTime:new Date('2026-09-21T04:00:00Z'),lineValues:values as (6|7|8|9)[]});
  return {...result,efficacy:efficacyDecisionView(result.efficacy)} as any;
};
const object = (r:any,p:string) => r.efficacy?.objects.find((x:any)=>x.objectPath===p);
const triad = (r:any,scope:string,element:string) => {
  const i=r.triads.groups.findIndex((x:any)=>x.scope===scope&&x.element===element);
  return r.efficacy?.triads.find((x:any)=>x.groupPath===`/triads/groups/${i}`);
};

test('explicit self selects the actual shi object, while missing relationship retains context gap',()=>{
  const r=run([7,7,7,7,7,7],'甲寅','庚戌');
  expect(r.efficacy?.selection).toMatchObject({status:'selected',selectedCandidateId:'original-6'});
  const unknown=run([7,7,7,7,7,7],'甲寅','庚戌','wealth',{event:'求财'});
  expect(unknown.efficacy?.selection).toMatchObject({status:'requires-context',selectedCandidateId:null});
});

test('unique original remains selected even when void; two appearances never use arbitrary order or void priority',()=>{
  const r=run([7,7,7,7,8,7],'甲寅','庚戌','wealth',{subject:'self',event:'求财'}); // 大有
  expect(r.efficacy?.selection).toMatchObject({status:'selected',selectedCandidateId:'original-2'});
  expect(object(r,'/lines/1')?.availability.status).toBe('awaiting-void-fill');
  const two=run([7,7,7,8,7,7],'癸未','庚子','wealth',{subject:'self',event:'求财'}); // 小畜
  expect(two.efficacy?.selection).toMatchObject({status:'multiple-candidates',selectedCandidateId:null,candidateIds:['original-3','original-4']});
});

test('巳月乙未大过之鼎: rootless target blocks rescue despite actual yuan/ji movers',()=>{
  const r=run([8,7,7,7,9,6],'乙巳','乙未');
  expect([r.benGua.name,r.bianGua.name]).toEqual(['泽风大过','火风鼎']);
  expect(object(r,'/lines/3')?.calendarStrength.status).toBe('rootless-condition');
  expect(object(r,'/lines/3')?.vitality.status).toBe('rootless');
  expect(r.efficacy?.selectedEffect.status).toBe('blocked');
});

test('申月己丑恒: strong uninjured metal tomb is nonbinding but remains a delayed opening reference',()=>{
  const r=run([8,7,7,7,8,8],'壬申','己丑');
  expect(object(r,'/lines/2')?.vitality.status).toBe('supported-unopposed');
  expect(object(r,'/lines/2')?.tombs).toEqual(expect.arrayContaining([expect.objectContaining({scope:'day',status:'nonbinding-strength'})]));
  expect(r.efficacy?.selectedEffect.status).toBe('awaiting-condition');
});

test('未月戊辰蛊之损: source month-break opens both actual moving and own-change 丑 tombs',()=>{
  const r=run([6,7,9,8,8,7],'癸未','戊辰');
  expect(object(r,'/lines/2')?.tombs).toEqual(expect.arrayContaining([
    expect.objectContaining({scope:'moving',sourcePath:'/lines/0',status:'opened'}),
    expect.objectContaining({scope:'own-change',sourcePath:'/lines/2/changed',status:'opened'}),
  ]));
});

test('calendar support cannot override an actual moving attacker or a return-control transformation',()=>{
  const r=run([7,7,7,9,7,7],'壬申','己丑'); // moving 午 attacks 申 metal
  expect(object(r,'/lines/4')?.calendarStrength.status).toBe('supported');
  expect(object(r,'/lines/4')?.vitality.status).toBe('contested');
  expect(object(r,'/lines/4')?.tombs.find((t:any)=>t.scope==='day')?.status).toBe('conditional');
  const back=run([8,6,7,7,7,7],'壬申','戊午'); // 遯→姤 午化亥
  expect(object(back,'/lines/1')?.vitality.status).toBe('contested');
  expect(object(back,'/lines/1')?.vitality.blockers.some((index:number)=>back.efficacy.evidence[index][0]==='return-control')).toBe(true);
});

test('month support with day control remains balanced, never labelled unconditionally strong',()=>{
  const r=run([7,7,7,7,7,7],'甲寅','庚申');
  expect(object(r,'/lines/1')?.calendarStrength.status).toBe('balanced');
  expect(object(r,'/lines/1')?.vitality.status).toBe('contested');
});

test('旺土遇巳论生不论绝; a real attacker prevents automatic override',()=>{
  const r=run([7,7,7,7,7,7],'戊辰','乙巳');
  expect(object(r,'/lines/2')?.extinctions.find((x:any)=>x.scope==='day')?.status).toBe('overridden-by-generation');
  const attacked=run([7,9,7,7,7,7],'戊辰','乙巳');
  expect(object(attacked,'/lines/2')?.extinctions.find((x:any)=>x.scope==='day')?.status).toBe('conditional');
});

test('unrescued weak fire in water season has effective day extinction, not just structural lookup',()=>{
  const r=run([7,7,7,7,7,7],'癸亥','乙亥');
  expect(object(r,'/lines/3')?.vitality.status).toBe('opposed-unrescued');
  expect(object(r,'/lines/3')?.extinctions.find((x:any)=>x.scope==='day')?.status).toBe('effective');
});

test('static triad coincidence does not form a moving combination; one actual mover remains source-limited',()=>{
  const r=run([7,7,7,7,7,7],'戊辰','戊子');
  expect(triad(r,'visible-originals','火')?.formation.status).toBe('not-formed');
});

test('two moving and one static keeps the contradictory source reading explicitly',()=>{
  const r=run([7,7,7,9,7,9],'乙巳','丁酉'); // 乾→需 寅 static 午戌 move
  expect(triad(r,'visible-originals','火')?.formation.status).toBe('competing-text');
});

test('离之坤: endpoint scopes form, but actual changed 丑 void blocks the outer group now',()=>{
  const r=run([9,8,9,9,8,9],'乙卯','丁巳');
  expect(triad(r,'inner-change','木')?.formation.status).toBe('formed');
  expect(triad(r,'outer-change','金')?.formation.status).toBe('formed');
  expect(triad(r,'outer-change','金')?.efficacy.status).toBe('awaiting-void-break');
  expect(triad(r,'outer-change','金')?.efficacy.conditions.some((index:number)=>r.efficacy.evidence[index][1].some((pathIndex:number)=>r.efficacy.factPaths[pathIndex]==='/lines/3/changed/context/isVoid'))).toBe(true);
});

test('小过之艮 calendar shi route is selected; non-shi generalization cannot assert formation',()=>{
  const r=run([8,8,7,9,8,6],'甲戌','甲寅');
  expect(triad(r,'calendar-moving-anchor','火')?.formation.status).toBe('formed');
  const other=run([7,7,7,9,7,7],'甲戌','甲寅');
  expect(triad(other,'calendar-moving-anchor','火')?.formation.status).toBe('requires-scope-evidence');
});

test('question reassessment recomputes selection and efficacy without changing saved facts or casting',()=>{
  const r=run([7,7,7,7,7,7],'癸亥','乙亥');const saved=JSON.stringify(r);
  const revised=engine.reassessQuestion(r,{question:'父母',questionType:'parents',questionContext:{subject:'parent',event:'父母'}}) as any;
  revised.efficacy=efficacyDecisionView(revised.efficacy);
  expect(revised.efficacy?.selection.status).toBe('multiple-candidates');
  expect(revised.efficacy?.selectedEffect.status).toBe('requires-selection');
  expect(revised.lines).toBe(r.lines);expect(revised.triads).toBe(r.triads);
  expect(JSON.stringify(r)).toBe(saved);
});

test('every reported evidence path resolves an existing original fact; no changed cross-position attacker exists',()=>{
  const r=run([6,6,9,9,9,6],'癸未','戊辰');
  expect(r.efficacy).toBeDefined();
  const visit=(value:any):void=>{
    if(!value||typeof value!=='object')return;
    for(const [k,v] of Object.entries(value)){
      if(k==='factPaths')for(const raw of v as (string|number)[]){
        const path=typeof raw==='number'?r.efficacy.factPaths[raw]:raw;
        const found=path.split('/').slice(1).reduce((o:any,x:string)=>o?.[x],r);
        expect({path,valid:found!==undefined}).toEqual({path,valid:true});
      } else visit(v);
    }
  };visit(r.efficacy);
  for(const [,indices] of r.efficacy.evidence)for(const index of indices){
    const path=r.efficacy.factPaths[index];
    expect(path.split('/').slice(1).reduce((o:any,k:string)=>o?.[k],r)).not.toBeUndefined();
  }
  expect(r.efficacy.outcomeEstablished).toBe(false);
});

test('巳 extinction reference cannot supply its own prerequisite that earth was already supported',()=>{
  const r=run([7,7,7,7,7,7],'癸亥','乙巳'); // 土 at 辰: winter rest; the only support is the contested 巳 itself.
  expect(object(r,'/lines/2')?.extinctions.find((x:any)=>x.scope==='day')?.status).toBe('conditional');
});

test('a complete three-moving original group is distinct from two-moving text competition',()=>{
  const r=run([7,9,7,9,7,9],'癸亥','己酉');
  expect(triad(r,'visible-originals','火')?.formation.status).toBe('formed');
});

test('no month/day candidate ever gets replaced by a hidden candidate in the same absent-visible case',()=>{
  const r=run([8,7,7,7,7,7],'甲寅','甲寅','wealth',{subject:'self',event:'求财'}); // 姤 missing wealth, 寅 month/day and 寅 hidden.
  expect(r.efficacy?.selection.status).toBe('multiple-candidates');
  expect(r.efficacy?.selection.selectedCandidateId).toBeNull();
  expect(r.efficacy?.selection.eligibleCandidateIds).toEqual(['month','day']);
});

// Repeated conditions must retain their own original-object paths after interning.
test('shared evidence layout is self-contained and every decision reference resolves',()=>{
  const r=run([9,8,9,9,8,9],'乙卯','丁巳');
  expect(r.efficacy?.evidenceLayout).toBe('indexed-object-decision-evidence-tuples-v2');
  expect(r.efficacy.factPaths.every((path:string)=>path.startsWith('/'))).toBe(true);
  expect(r.efficacy.evidence.length).toBeGreaterThan(0);
  let refs=0;
  const visit=(v:any):void=>{
    if(!v||typeof v!=='object')return;
    for(const [k,x] of Object.entries(v)){
      if(k==='conditions'||k==='blockers')for(const index of x as number[]){
        expect(Number.isInteger(index)).toBe(true);expect(r.efficacy.evidence[index]).toEqual([expect.any(String),expect.any(Array)]);refs++;
      } else if(k!=='evidence')visit(x);
    }
  };visit(r.efficacy);
  expect(refs).toBeGreaterThan(r.efficacy.evidence.length);
  const persisted=JSON.parse(JSON.stringify(r.efficacy));
  expect(persisted).toEqual(r.efficacy);
});

test('an actual changed tomb that is void remains conditional instead of immediately binding its weak original',()=>{
  const r=run([9,8,6,8,8,8],'乙巳','乙未'); // 复→谦: 子水化辰墓；甲午旬辰巳空
  expect([r.benGua.name,r.bianGua.name]).toEqual(['地雷复','地山谦']);
  expect(r.lines[0].changed.ganZhi[1]).toBe('辰');
  expect(r.lines[0].changed.context.isVoid).toBe(true);
  expect(object(r,'/lines/0')?.tombs.find((x:any)=>x.scope==='own-change')?.status).toBe('conditional');
});

test('raw receipt row layout declares every zero-based dictionary and preserves empty decisions',()=>{
  clock.mockReturnValue({month:'乙卯',day:'丁巳',hour:'庚午'});
  const r=engine.cast({question:'原文规则核对',questionType:'health',questionContext:{subject:'self',event:'核对'},
    castTime:new Date('2026-09-21T04:00:00Z'),lineValues:[9,8,9,9,8,9]}),packed=r.efficacy;
  expect(packed.indexBase).toBe(0);
  expect(packed.objectColumns).toEqual(['objectPath','calendarStrength','vitality','activity','availability','tombs','extinctions']);
  expect(packed.decisionColumns).toEqual(['statusIndex','conditions','blockers']);
  expect(packed.evidenceColumns).toEqual(['ruleIndex','factPathIndices']);
  expect(packed.factPathColumns).toEqual(['rootIndex','suffixIndex']);
  for(const [state,conditions,blockers] of packed.decisions){
    expect(typeof packed.states[state]).toBe('string');
    for(const i of [...conditions,...blockers])expect(packed.evidence[i]).toHaveLength(2);
  }
  for(const [rule,paths] of packed.evidence){
    expect(typeof packed.ruleIDs[rule]).toBe('string');
    for(const i of paths){const [root,suffix]=packed.factPaths[i];expect(packed.pathRoots[root]+packed.pathSuffixes[suffix]).toMatch(/^\//);}
  }
  const view=efficacyDecisionView(packed);
  expect(view.objects.find(x=>x.objectPath==='/lines/0')?.availability).toEqual({status:'present',conditions:[],blockers:[]});
  expect(JSON.parse(JSON.stringify(packed))).toEqual(packed);
});
