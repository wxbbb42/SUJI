import { dispatch } from '../../../bridge';
const now='2026-09-21T04:00:00Z';
export const dependencyBirthCases=[
  {day:10,hour:17,status:'unresolved',pillars:['甲子','癸酉','丁未','己酉']},
  {day:20,hour:17,status:'available',pillars:['甲子','癸酉','丁巳','己酉']},
  {day:30,hour:17,status:'blocked',pillars:['甲子','癸酉','丁卯','己酉']},
  {day:17,hour:5,status:'available',pillars:['甲子','癸酉','甲寅','丁卯']},
];
test.each(dependencyBirthCases)('actual September 1984 birth $day/$hour resolves $status through natal/profile/domain',async ({day,hour,status,pillars})=>{
  const birth={year:1984,month:9,day,hour,minute:30,gender:'男',longitude:120,timeZoneID:'Asia/Shanghai'};
  const natal:any=await dispatch({command:'natal',birth});
  const saved=JSON.stringify(natal);
  const profile:any=await dispatch({command:'profile',birth,natal,now});
  const direct:any=await dispatch({command:'tool',name:'get_domain',arguments:{domain:'事业'},birth,now});
  const reused:any=await dispatch({command:'tool',name:'get_domain',arguments:{domain:'事业'},birth,natal,now});
  const b=direct.result.bazi,d=b.patternAnalysis.rescueEvidence.dependencyResolution;
  expect(Object.values(b.pillars).map((p:any)=>p.ganZhi.gan+p.ganZhi.zhi)).toEqual(pillars);
  expect(d.actions.find((a:any)=>a.ruleId==='canonical-helper-control').status).toBe(status);
  expect(d.outcomeEstablished).toBe(false);
  expect(profile.mingPan.geJuV2).toEqual(natal.mingPan.geJuV2);
  expect(reused.result.bazi.patternAnalysis).toEqual(b.patternAnalysis);
  expect(b.patternAnalysis).toEqual(natal.mingPan.geJuV2);
  expect(JSON.stringify(natal)).toBe(saved);
  if(day===20)expect(d.actions[0].attacks).toEqual([{actorPosition:0,protectionCombinationIndexes:[0],status:'neutralized'}]);
});

test.each([{day:11,status:'available'},{day:31,status:'retained'}])('actual March 1986 source order selects month occurrence with efficacy $status',async ({day,status})=>{
  const birth={year:1986,month:3,day,hour:13,minute:30,gender:'男',longitude:120};
  const natal:any=await dispatch({command:'natal',birth});
  const result:any=await dispatch({command:'tool',name:'get_domain',arguments:{domain:'事业'},birth,natal,now});
  const d=result.result.bazi.patternAnalysis.rescueEvidence.dependencyResolution;
  expect(d.occurrenceSelections).toEqual([{ruleId:'bing-selects-month-xin',actorPosition:0,selectedTargetPosition:1,retainedTargetPositions:[3],sourceIds:['ziping-xu-occurrence-selection-v1']}]);
  expect(d.actions.map((a:any)=>a.status)).toEqual([status,'retained']);
  expect(result.result.bazi.patternAnalysis).toEqual(natal.mingPan.geJuV2);
});
