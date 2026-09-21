import { dispatch } from '../../../bridge';
import { HexagramEngine } from '../HexagramEngine';
import { QimenEngine } from '../../qimen/QimenEngine';
import * as calendar from '../../calendar/precision';

const now = '2024-02-04T04:00:00Z';
const initial = {question:'核对我自己的健康参考',questionType:'health',subject:'self',event:'身体情况',timeHorizon:'near'};
const revised = {question:'补充：实际问父亲的情况',questionType:'health',subject:'parent',event:'父亲的情况',timeHorizon:'far'};
const copy = <T>(value:T):T => JSON.parse(JSON.stringify(value));

async function original(name:string) {
 const random=jest.spyOn(Math,'random').mockReturnValue(0.4);
 try {return (await dispatch({command:'tool',name,id:'original-A',arguments:initial,now})).result;} finally {random.mockRestore();}
}
function immutable(value:any,name:string) {
 const result=copy(value);
 for(const key of ['question','questionType','questionContext','yongShen','yingQi','questionRevision',...(name==='cast_liuyao'?['roleRelations','efficacy']:[])])delete result[key];
 return result;
}

describe('existing-chart question reassessment',()=>{
 test.each(['cast_liuyao','setup_qimen'])('%s retains every original fact without recasting or reading current time',async name=>{
  const source=await original(name),before=copy(source);
  const cast=jest.spyOn(HexagramEngine.prototype,'cast').mockImplementation(()=>{throw new Error('recast forbidden');});
  const setup=jest.spyOn(QimenEngine.prototype,'setup').mockImplementation(()=>{throw new Error('setup forbidden');});
  const random=jest.spyOn(Math,'random').mockImplementation(()=>{throw new Error('random forbidden');});
  const OriginalDate=global.Date;
  global.Date=new Proxy(OriginalDate,{
   construct(target,args){if(!args.length)throw new Error('current Date forbidden');return Reflect.construct(target,args);},
   apply(){throw new Error('current Date call forbidden');},
  });
  const date=jest.spyOn(Date,'now').mockImplementation(()=>{throw new Error('current time forbidden');});
  const pillars=jest.spyOn(calendar,'getCalendarPillars').mockImplementation(()=>{throw new Error('calendar recomputation forbidden');});
  try {
   const envelope=await dispatch({command:'reassess-question',name,sourceCallID:'original-A',original:source,arguments:revised});
   const result=envelope.result;
   expect(source).toEqual(before);
   expect(immutable(result,name)).toEqual(immutable(before,name));
   expect(result.questionContext).toEqual({subject:'parent',event:'父亲的情况',timeHorizon:'far'});
   expect(result.yongShen.selectedCandidateId).toBeNull();
   expect(result.yongShen.selectionEstablished).toBe(false);
   expect(result.questionRevision).toEqual({algorithm:'suji-cast-question-revision-1',sourceToolName:name,sourceCallID:'original-A'});
   expect(cast).not.toHaveBeenCalled();expect(setup).not.toHaveBeenCalled();expect(random).not.toHaveBeenCalled();expect(date).not.toHaveBeenCalled();expect(pillars).not.toHaveBeenCalled();
   if(name==='cast_liuyao') {
    // 坤纳未巳卯丑亥酉，坤土以火为父母；仅二爻巳火。
    expect(result.yongShen.type).toBe('父母');
    expect(result.yongShen.candidates.map((x:any)=>x.id)).toEqual(['original-2']);
    expect(result.yingQi.timeScale).toBe('year-month-reference');
    expect(result.roleRelations).not.toEqual(source.roleRelations);
   } else {
    expect(result.yongShen.missingContext).toContain('proxy-perspective');
    expect(result.yongShen.candidates.filter((x:any)=>x.role!=='category-reference')).toEqual(source.yongShen.candidates.filter((x:any)=>x.role!=='category-reference'));
    expect(result.yingQi.dates).toEqual([]);
   }
  }finally{jest.restoreAllMocks();global.Date=OriginalDate;}
 });
 test('category changes rebuild Qimen reference candidates, including legacy fields, without altering plates',async()=>{
  const source=await original('setup_qimen');
  const result=(await dispatch({command:'reassess-question',name:'setup_qimen',sourceCallID:'original-A',original:source,arguments:{question:'问事业安排',questionType:'career',subject:'self',event:'工作安排',timeHorizon:'unspecified'}})).result;
  expect(result.palaces).toEqual(source.palaces);
  expect(result.yongShen.candidates.some((x:any)=>x.symbol==='开门')).toBe(true);
  expect(result.yongShen.references.some((x:any)=>x.label==='开门')).toBe(true);
  expect(result.yongShen.missingContext).toContain('time-horizon');
 });
 test.each(['cast_liuyao','setup_qimen'])('%s rejects corrupt, old, derived and mismatched source records',async name=>{
  const source=await original(name);
  for(const change of [
   (s:any)=>{s.provenance.engineRevision='old';},
   (s:any)=>{s.provenance.referenceDate='2025-01-01T00:00:00Z';},
   (s:any)=>{s.provenance.calendarPolicy.provider='forged';},
   (s:any)=>{s.questionRevision={algorithm:'already-derived'};},
   (s:any)=>{delete s.provenance;},
   (s:any)=>{delete s.ruleSources;},
   (s:any)=>{if(name==='cast_liuyao')s.lines.pop();else s.palaces.pop();},
  ]) {const bad=copy(source);change(bad);await expect(dispatch({command:'reassess-question',name,sourceCallID:'original-A',original:bad,arguments:revised})).rejects.toThrow();}
  for(const badName of ['get_domain',name==='cast_liuyao'?'setup_qimen':'cast_liuyao'])await expect(dispatch({command:'reassess-question',name:badName,sourceCallID:'original-A',original:source,arguments:revised})).rejects.toThrow();
  await expect(dispatch({command:'reassess-question',name,sourceCallID:'',original:source,arguments:revised})).rejects.toThrow();
  await expect(dispatch({command:'reassess-question',name,sourceCallID:'original-A',original:source,arguments:{...revised,subject:'invented'}})).rejects.toThrow();
 });
});
