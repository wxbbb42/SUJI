import { HexagramEngine } from '../HexagramEngine';
import { getCalendarPillars } from '../../calendar/precision';
import type { QuestionContext } from '../questionJudgment';
import type { QuestionType } from '../types';

jest.mock('../../calendar/precision',()=>({getCalendarPillars:jest.fn()}));
const clock=getCalendarPillars as jest.Mock,engine=new HexagramEngine();
const cast=(values:number[],month:string,day:string,type:QuestionType='health',context:QuestionContext={subject:'self',event:'原文规则核对',timeHorizon:'near'})=>{
  clock.mockReturnValue({month,day,hour:'庚午'});
  return engine.cast({question:'原文规则核对',questionType:type,questionContext:context,castTime:new Date('2026-09-21T04:00:00Z'),lineValues:values as (6|7|8|9)[]}) as any;
};

test('uninjured monthly target establishes the source-profile favorable direction, never empirical certainty',()=>{
  const r=cast([7,7,7,7,7,7],'甲戌','甲申');
  expect(r.lines[5].ganZhi).toBe('壬戌');
  expect(r.eventAssessment).toMatchObject({outcome:'favorable-under-selected-rule',ruleOutcomeEstablished:true,outcomeEstablished:false,eventObjectPaths:['/lines/5']});
});

test('大过之鼎 no-root target defeats both moving rescue edges and yields adverse profile',()=>{
  const r=cast([8,7,7,7,9,6],'乙巳','乙未');
  expect([r.benGua.name,r.bianGua.name]).toEqual(['泽风大过','火风鼎']);
  expect(r.eventAssessment).toMatchObject({outcome:'adverse-under-selected-rule',ruleOutcomeEstablished:true,outcomeEstablished:false});
  expect(r.eventAssessment?.candidates[0].transmissions).toEqual(expect.arrayContaining([expect.objectContaining({jiPath:'/lines/5',yuanPath:'/lines/4',status:'target-cannot-receive'})]));
});

test('two appearances retain both event candidates and do not silently select an empty timing object',()=>{
  const r=cast([7,7,7,8,7,7],'癸未','庚子','wealth',{subject:'self',event:'求财'});
  expect(r.eventAssessment).toMatchObject({outcome:'unresolved',ruleOutcomeEstablished:false,eventObjectPaths:['/lines/2','/lines/3'],timingObjectStatus:'not-selected'});
  expect(r.efficacy.selection.selectedCandidateId).toBeNull();
});

test('a question with missing role cannot gain a verdict through candidate agreement',()=>{
  const r=cast([7,7,7,7,7,7],'甲戌','甲申','health',{event:'健康'});
  expect(r.eventAssessment).toMatchObject({outcome:'unresolved',ruleOutcomeEstablished:false});
});

test('effective 子忌→卯元→巳用 redirects the incoming attack, with balanced calendar supported by the moving yuan',()=>{
  const r=cast([7,9,8,8,7,6],'甲子','丙寅');
  expect([r.benGua.name,r.bianGua.name]).toEqual(['水泽节','风雷益']);
  expect(r.eventAssessment).toMatchObject({outcome:'favorable-under-selected-rule',ruleOutcomeEstablished:true});
  expect(r.eventAssessment?.candidates[0].transmissions).toEqual([expect.objectContaining({jiPath:'/lines/5',yuanPath:'/lines/1',status:'redirected-through-yuan'})]);
  expect(r.eventAssessment?.candidates[0].blockers).toEqual([]);
});

test('changing only the calendar makes the same yuan month-broken and cannot retain the favorable transmission',()=>{
  const r=cast([7,9,8,8,7,6],'甲酉','丙寅');
  expect(r.eventAssessment?.ruleOutcomeEstablished).toBe(false);
  expect(r.eventAssessment?.candidates[0].transmissions[0].status).toBe('conditional');
  expect(r.eventAssessment?.candidates[0].transmissions[0].blockers.length).toBeGreaterThan(0);
});

test('added 申金 moving attack on the yuan blocks the complete rescue chain',()=>{
  const r=cast([7,9,8,6,7,6],'甲子','丙寅');
  expect(r.eventAssessment?.ruleOutcomeEstablished).toBe(false);
  expect(r.eventAssessment?.candidates[0].transmissions[0].status).toBe('conditional');
});

test('uninjured monthly target in the current void is awaiting a condition, never permanently adverse or already obtained',()=>{
  const r=cast([7,7,7,7,8,7],'甲寅','庚戌','wealth',{subject:'self',event:'求财'});
  expect(r.eventAssessment).toMatchObject({outcome:'awaiting-condition',ruleOutcomeEstablished:false,outcomeEstablished:false});
});

test('month-break alone never satisfies the no-root adverse condition',()=>{
  const r=cast([8,7,7,7,9,6],'乙巳','甲申');
  expect(r.eventAssessment?.outcome).not.toBe('adverse-under-selected-rule');
  expect(r.eventAssessment?.ruleOutcomeEstablished).toBe(false);
});

test('monthly effective moving 忌 with no calendar support or moving rescue gives adverse direction',()=>{
  const r=cast([7,9,7,7,7,7],'甲寅','丙寅');
  expect(r.eventAssessment).toMatchObject({outcome:'adverse-under-selected-rule',ruleOutcomeEstablished:true});
});

test('two identical rootless objects can share a source direction while selection and timing remain open',()=>{
  const r=cast([8,7,7,7,9,6],'乙巳','乙未','parents',{subject:'parent',event:'父母'});
  expect(r.yongShen.candidates.map((x:any)=>x.objectPath)).toEqual(['/lines/1','/lines/3']);
  expect(r.eventAssessment).toMatchObject({outcome:'adverse-under-selected-rule',selectionStatus:'candidate-invariant-direction',timingObjectStatus:'not-selected'});
  expect(r.efficacy.selection.selectedCandidateId).toBeNull();
});

test('incoming ji also needs usable force; a supported yuan does not repair a broken incoming actor',()=>{
  const r=cast([7,9,8,8,7,6],'甲午','丙寅'); // 子忌月破；卯元仍日扶
  expect(r.eventAssessment?.candidates[0].transmissions[0].status).toBe('conditional');
  expect(r.eventAssessment?.ruleOutcomeEstablished).toBe(false);
});

test('no-root removal of only the day control condition cannot inherit target-cannot-receive',()=>{
  const r=cast([8,7,7,7,9,6],'乙巳','甲申');
  expect(r.eventAssessment?.candidates[0].transmissions[0].status).not.toBe('target-cannot-receive');
});

test('event evidence dictionary keeps every source rule and original pointer locally available',()=>{
  const r=cast([7,9,8,8,7,6],'甲子','丙寅'),a=r.eventAssessment;
  expect(a.evidenceLayout).toBe('indexed-event-evidence-v1');
  expect(a.evidence.length).toBeGreaterThan(0);
  for(const [rule,paths] of a.evidence) {
    expect(typeof a.ruleIDs[rule]).toBe('string');
    for(const index of paths)expect(a.factPaths[index].split('/').slice(1).reduce((o:any,k:string)=>o[k],r)).not.toBeUndefined();
  }
  expect(JSON.parse(JSON.stringify(a))).toEqual(a);
});

test('even an unresolved moving rescue prevents the no-rescue monthly-ji adverse rule',()=>{
  const r=cast([7,9,7,9,7,7],'甲寅','丙寅'); // add 午火元 to the prior monthly 忌 fixture
  expect(r.eventAssessment?.outcome).not.toBe('adverse-under-selected-rule');
  expect(r.eventAssessment?.ruleOutcomeEstablished).toBe(false);
});

test('matching contested candidates do not masquerade as an invariant established direction',()=>{
  const r=cast([7,7,7,7,7,7],'甲申','丙寅','parents',{subject:'parent',event:'父母'});
  expect(r.eventAssessment?.candidates.map((x:any)=>x.outcome)).toEqual(['contested','contested']);
  expect(r.eventAssessment).toMatchObject({outcome:'contested',selectionStatus:'multiple-object-ambiguity',ruleOutcomeEstablished:false});
});
