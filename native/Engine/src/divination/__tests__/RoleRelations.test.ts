import {HexagramEngine} from '../HexagramEngine';
import {getCalendarPillars} from '../../calendar/precision';
import {GUA_64} from '../data/gua64';
const oracle=require('../../../validation/research-divination/liuyao-role-independent-oracle.json');
jest.mock('../../calendar/precision',()=>({getCalendarPillars:jest.fn()}));
const clock=getCalendarPillars as jest.Mock;
const engine=new HexagramEngine();
const run=(values:number[],questionType='parents',subject='parent')=>engine.cast({question:'合成规则坐标，非古例公历日期',questionType:questionType as any,questionContext:{subject:subject as any,event:'核对结构',timeHorizon:'near'},castTime:new Date('2026-09-20T04:00:00Z'),lineValues:values as any}) as any;
beforeEach(()=>clock.mockReturnValue({month:'壬辰',day:'戊申',hour:'庚午'}));

for(const f of oracle.fixtures) test(f.id+' retains literal role positions, candidates and original actors',()=>{
 clock.mockReturnValue({month:'甲'+f.sourceCalendar.monthBranch,day:f.sourceCalendar.dayGanZhi,hour:'庚午'});
 const r=run(f.values,f.questionType,f.subject),roles=r.roleRelations;
 expect(r.benGua.name).toBe(f.original);expect(r.bianGua.name).toBe(f.resulting);
 expect(r.lines.map((l:any)=>l.ganZhi[1])).toEqual(f.originalBranches);
 expect(roles).toBeDefined();
 const g=roles.groups.find((g:any)=>g.candidateRefs.some((c:any)=>c.id===f.target.id));
 expect(g.targetElement).toBe(f.target.element);
 expect(g.candidateRefs).toContainEqual({id:f.target.id,objectPath:f.target.path,contextPath:f.target.path+'/context'});
 expect(g.yuanPositions).toEqual(f.roles.元神);expect(g.jiPositions).toEqual(f.roles.忌神);expect(g.chouPositions).toEqual(f.roles.仇神);
 expect(g.elements).toEqual({yuan:oracle.targetRoleTable[f.target.element].元神,ji:oracle.targetRoleTable[f.target.element].忌神,chou:oracle.targetRoleTable[f.target.element].仇神});
 expect(roles.inspectedOriginalPaths).toEqual(['/lines/0','/lines/1','/lines/2','/lines/3','/lines/4','/lines/5']);
 expect(roles.unresolved).toEqual(expect.arrayContaining(['tomb-or-extinction','event-outcome']));
 expect(roles.outcomeEstablished).toBe(false);expect(r.yongShen.selectedCandidateId).toBeNull();
 expect(g.jiYuanMovingPairs).toEqual(f.id==='ch10-daguo-ding'?[{jiPosition:6,yuanPosition:5}]:[]);
 expect(g.chouJiMovingPairs).toEqual([]);
 if(f.id==='ch10-daguo-ding') {
  expect(r.lines[3].context.month.clash).toBe(true);expect(r.lines[3].context.day.elementRelation).toBe('克爻');
  expect(g.chouPositions).not.toContain(6); // 巳 exists only as 6's own changed object.
 }
 if(f.id==='ch9-qian-xiaoxu') {
  expect(g.candidateRefs.map((c:any)=>c.id)).toEqual(['original-3','original-6']);
  expect(r.yongShen.related.map((c:any)=>c.id)).toContain('changed-4');
  expect(roles.unresolved).toContain('binding');
 }
});

test('all five role tables retain static roles, missing yuan actors and explicit no-target states',()=>{
 const elements=new Set<string>();let absentYuanWithChou=0;
 for(const gua of GUA_64)for(const [qt,subject] of [['parents','parent'],['kids','child'],['wealth','self'],['career','self'],['health','self']]) {
  const r=run(gua.yao.map(v=>v==='阳'?7:8),qt,subject);
  expect(r.roleRelations).toBeDefined();
  for(const g of r.roleRelations.groups) {
   elements.add(g.targetElement);const table=oracle.targetRoleTable[g.targetElement];
   for(const [field,role] of [['yuanPositions','元神'],['jiPositions','忌神'],['chouPositions','仇神']])expect(g[field]).toEqual(r.lines.filter((l:any)=>l.wuXing===table[role]).map((l:any)=>l.position));
   expect(g.jiYuanMovingPairs).toEqual([]);expect(g.chouJiMovingPairs).toEqual([]);
   if(!g.yuanPositions.length&&g.chouPositions.length)absentYuanWithChou++;
  }
 }
 expect([...elements].sort()).toEqual(['木','火','土','金','水'].sort());expect(absentYuanWithChou).toBeGreaterThan(0);
 expect(run([7,7,7,7,7,7],'general','unknown').roleRelations.groups).toEqual([]);
});

test('calendar candidates stay explicit and are not assigned original-line movement',()=>{
 clock.mockReturnValue({month:'甲寅',day:'甲寅',hour:'庚午'});
 const r=run([8,7,7,7,7,7],'wealth','self');
 expect(r.roleRelations).toBeDefined();
 expect(r.roleRelations.unsupportedCandidates).toEqual([
  {id:'month',objectPath:'/castGanZhi/month',reason:'calendar-target-outside-line-role-scope'},
  {id:'day',objectPath:'/castGanZhi/day',reason:'calendar-target-outside-line-role-scope'},
 ]);
 expect(r.roleRelations.groups.flatMap((g:any)=>g.candidateRefs.map((c:any)=>c.id))).toEqual(['hidden-2']);
});

test('all actual co-moving pairs are retained without creating absent actors or a rescue verdict',()=>{
 const whole=run([9,9,9,9,9,9]);
 expect(whole.roleRelations.unresolved).not.toContain('dark-movement');
 const q=whole.roleRelations.groups[0];
 expect(q.jiYuanMovingPairs).toEqual([{jiPosition:2,yuanPosition:4}]);
 expect(q.chouJiMovingPairs).toEqual([{chouPosition:1,jiPosition:2}]);
 const d=run([6,9,9,9,9,6],'health','self').roleRelations.groups[0];
 expect(d.jiYuanMovingPairs).toEqual([{jiPosition:1,yuanPosition:3},{jiPosition:1,yuanPosition:5},{jiPosition:6,yuanPosition:3},{jiPosition:6,yuanPosition:5}]);
 expect(d.chouPositions).toEqual([]);expect(d.chouJiMovingPairs).toEqual([]);
});

test('versioned source hashes and original quotations match read raw chapters',()=>{
 const {createHash}=require('node:crypto'),{ROLE_RELATION_SOURCE}=require('../roleRelations');
 const archive=require('../../../validation/research-divination/liuyao-role-sources.json');
 for(const [i,s] of archive.sources.entries()) {
  expect(createHash('sha256').update(s.text).digest('hex')).toBe(s.sha256);
  expect(ROLE_RELATION_SOURCE.references[i].sha256).toBe(s.sha256);
  expect(s.text.split('<onlyinclude>')[1].split('</onlyinclude>')[0]).toContain(ROLE_RELATION_SOURCE.references[i].quote);
 }
});
