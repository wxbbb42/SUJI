import {HexagramEngine} from '../HexagramEngine';
import {GUA_64} from '../data/gua64';
import {getCalendarPillars} from '../../calendar/precision';
jest.mock('../../calendar/precision',()=>({getCalendarPillars:jest.fn()}));
const clock = getCalendarPillars as jest.Mock;
const engine=new HexagramEngine();
const run=(extra:any={})=>engine.cast({question:'合成规则坐标',questionType:'parents',castTime:new Date('2026-09-20T04:00:00Z'),lineValues:[7,7,7,7,7,7],...extra}) as any;
beforeEach(()=>clock.mockReturnValue({month:'壬辰',day:'甲子',hour:'庚午'}));

test('multiple visible parents remain distinct; no first candidate is chosen or scored',()=>{
 const r=run(); expect(r.yongShen.selectedCandidateId).toBeNull();expect(r.yongShen.yaoIndex).toBeUndefined();
 expect(r.yongShen.candidates.map((c:any)=>c.id)).toEqual(['original-3','original-6']);
 expect(r.yongShen.candidates.map((c:any)=>c.objectPath)).toEqual(['/lines/2','/lines/5']);
 expect(r.yongShen.missingContext).toEqual(expect.arrayContaining(['subject','event','time-horizon']));
 expect(r.yongShen.excluded.map((c:any)=>c.objectPath)).toEqual(['/lines/0','/lines/1','/lines/3','/lines/4']);
});
test('health distinguishes self, parent, child and sibling instead of defaulting to self',()=>{
 expect(run({questionType:'health'}).yongShen.candidates).toEqual([]);
 for(const [subject,type] of [['parent','父母'],['child','子孙'],['sibling','兄弟']]){
  const r=run({questionType:'health',questionContext:{subject,event:'问此人的状况',timeHorizon:'near'}});
  expect(r.yongShen.type).toBe(type);expect(r.yongShen.candidates.every((c:any)=>r.lines[c.position-1].liuQin===type)).toBe(true);
 }
 const self=run({questionType:'health',questionContext:{subject:'self'}});
 expect(self.yongShen.candidates.map((c:any)=>c.id)).toEqual(['original-6']);
});
test('gender cannot supply partner identity or replace missing subject; proxy finance is unresolved',()=>{
 expect(run({questionType:'marriage',gender:'男'}).yongShen.candidates).toEqual([]);
 expect(run({questionType:'marriage',gender:'女',questionContext:{subject:'wife'}}).yongShen.type).toBe('妻财');
 const proxy=run({questionType:'wealth',questionContext:{subject:'parent',event:'母亲的投资'}});
 expect(proxy.yongShen.selectionStatus).toBe('requires-clarification');expect(proxy.yongShen.candidates).toEqual([]);
 expect(proxy.yongShen.missingContext).toContain('proxy-perspective');
});
test('hidden and calendar alternatives have identities; a changed match stays a dependent reference',()=>{
 clock.mockReturnValue({month:'甲寅',day:'甲寅',hour:'庚午'});
 const r=run({questionType:'wealth',lineValues:[8,7,7,7,7,7]});
 expect(r.yongShen.candidates.map((c:any)=>c.id)).toEqual(['month','day','hidden-2']);
 expect(r.yongShen.candidates[2].objectPath).toBe('/lines/1/hidden');
 expect(r.yongShen.candidates[2].contextPath).toBe('/lines/1/hidden/context');
 const change=run({questionType:'kids',lineValues:[8,6,7,7,7,7]});
 expect(change.yongShen.related.map((c:any)=>c.id)).toContain('changed-2');
 expect(change.yongShen.candidates.map((c:any)=>c.id)).not.toContain('changed-2');
 expect(change.yingQi.branchesByCandidate.every((b:any)=>!b.rules.some((t:any)=>t.id==='static-value-clash'))).toBe(true);
});
test('all64 gua retain every original role candidate, with same-role exclusions absent',()=>{
 for(const gua of GUA_64)for(const [questionType,type] of [['career','官鬼'],['wealth','妻财'],['parents','父母'],['kids','子孙']]){
  const r=run({questionType,lineValues:gua.yao.map(v=>v==='阳'?7:8)});
  expect(r.yongShen.candidates.filter((c:any)=>c.layer==='original').map((c:any)=>c.position)).toEqual(r.lines.filter((l:any)=>l.liuQin===type).map((l:any)=>l.position));
  expect(r.yongShen.selectedCandidateId).toBeNull();
 }
});
test('static/moving branch triggers are conditional, and month-break / void coexist',()=>{
 clock.mockReturnValue({month:'庚午',day:'甲寅',hour:'庚午'});
 const stat=run({questionType:'kids'}),moving=run({questionType:'kids',lineValues:[9,7,7,7,7,7]});
 const s=stat.yingQi.branchesByCandidate[0],m=moving.yingQi.branchesByCandidate[0];
 expect(s.candidateId).toBe('original-1');
 expect(s.rules).toEqual(expect.arrayContaining([
  expect.objectContaining({id:'static-value-clash',branches:['子','午']}),
  expect.objectContaining({id:'month-break-fill-combine',branches:['子','丑']}),
  expect.objectContaining({id:'void-fill-clash',branches:['子','午']})]));
 expect(m.rules).toEqual(expect.arrayContaining([expect.objectContaining({id:'moving-value-combine',branches:['子','丑']})]));
 expect(m.rules.some((r:any)=>r.id==='static-value-clash')).toBe(false);
 expect(m.unresolved).not.toEqual(expect.arrayContaining(['dark-movement-or-binding']));
 expect(m.unresolved).not.toContain('dark-movement');
 expect(stat.yingQi.outcomeEstablished).toBe(false);expect(stat.yingQi.unresolved).toContain('selected-object');
 expect(stat.yingQi.date).toBeUndefined();
});
test('combination waits for either side to clash; changed branch is tied to the same original',()=>{
 clock.mockReturnValue({month:'癸丑',day:'甲子',hour:'庚午'});
 const r=run({questionType:'kids',lineValues:[9,7,7,7,7,7]});
 const rules=r.yingQi.branchesByCandidate[0].rules;
 expect(rules).toEqual(expect.arrayContaining([
  expect.objectContaining({id:'month-combination-open',branches:['午','未'],factPaths:['/lines/0/context/month/combination','/castGanZhi/month']}),
  expect.objectContaining({id:'changed-combination-open',branches:['午','未'],factPaths:['/lines/0/ganZhi','/lines/0/changed/ganZhi']})]));
});

test('branch trigger directions agree with a literal twelve-branch table across64 gua',()=>{
 const table:Record<string,string[]>={子:['午','丑'],丑:['未','子'],寅:['申','亥'],卯:['酉','戌'],辰:['戌','酉'],巳:['亥','申'],午:['子','未'],未:['丑','午'],申:['寅','巳'],酉:['卯','辰'],戌:['辰','卯'],亥:['巳','寅']};
 for(const gua of GUA_64)for(const moving of [false,true]){
  const r=run({lineValues:gua.yao.map(v=>v==='阳'?(moving?9:7):(moving?6:8))});
  for(const candidate of r.yongShen.candidates.filter((c:any)=>c.layer==='original')){
   const branch=r.lines[candidate.position-1].ganZhi[1];
   expect(r.yingQi.branchesByCandidate.find((b:any)=>b.candidateId===candidate.id).rules[0].branches).toEqual([branch,table[branch][moving?1:0]]);
  }
 }
});

test('read source transcription hashes and selected quotes are reproducible',()=>{
 const {createHash}=require('node:crypto');const archive=require('../../../validation/research-divination/question-judgment-sources.json');
 const {QUESTION_RULE_SOURCE}=require('../questionJudgment');
 for(const source of archive.sources.slice(0,2))expect(createHash('sha256').update(source.excerpt).digest('hex')).toBe(source.sha256);
 const passages=archive.sources.map((s:any)=>s.excerpt??s.passages.map((p:any)=>p.excerpt).join('\n')).join('\n');
 for(const ref of QUESTION_RULE_SOURCE.references){expect(archive.sources.some((s:any)=>s.sha256===ref.sha256)).toBe(true);if(ref.quote)expect(passages).toContain(ref.quote);}
 expect(passages).toContain('後逢午未日應之');expect(passages).toContain('遠事定之以年月，近事應之於日時');
});
