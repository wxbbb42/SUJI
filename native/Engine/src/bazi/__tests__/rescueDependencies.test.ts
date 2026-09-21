import { computePatternConditions } from '../structural';
import { adjudicateRescue } from '../rescueAdjudication';
import type { DiZhi, ShiShen, TianGan } from '../types';

const read=(stems:string,branches:string,yong:ShiShen='正官')=>(adjudicateRescue(computePatternConditions(
  [...stems][2] as TianGan,[...stems] as [TianGan,TianGan,TianGan,TianGan],
  [...branches] as [DiZhi,DiZhi,DiZhi,DiZhi],yong)) as any).dependencyResolution;
const action=(r:any,id:string)=>r.actions.find((a:any)=>a.id===id);

test('protective combination propagates to Ding controlling the monthly killing role',()=>{
  const r=read('丁癸乙戊','巳酉卯戌','七杀');
  expect(r).toMatchObject({methodVersion:'bazi-rescue-dependencies-v1',outcomeEstablished:false});
  expect(action(r,'control:0:month-main-qi:1')).toMatchObject({status:'available',localEffectEstablished:true,
    targetGan:'辛',attacks:[{actorPosition:1,status:'neutralized',protectionCombinationIndexes:[0]}]});
  expect(r.threatResolutions).toContainEqual(expect.objectContaining({targetLayer:'month-main-qi',targetPosition:1,status:'supported-local-path'}));
});

test('rooted attacker blocks the release and is not erased by its proposed protection',()=>{
  const r=read('丁癸乙戊','巳酉卯辰','七杀');
  expect(action(r,'control:0:month-main-qi:1')).toMatchObject({status:'unresolved',localEffectEstablished:false,
    attacks:[{actorPosition:1,status:'unresolved',protectionCombinationIndexes:[]}]});
  expect(r.threatResolutions.find((t:any)=>t.targetLayer==='month-main-qi').status).toBe('unresolved');
});

test('a bound Gui cannot rescue Ding and the dependency names the exact blocking occurrence',()=>{
  const r=read('丁癸甲戊','未酉寅戌');
  expect(action(r,'control:1:stem:0')).toMatchObject({status:'blocked',localEffectEstablished:false,blockingCombinationIndexes:[0]});
  expect(r.threatResolutions).toContainEqual(expect.objectContaining({targetPosition:0,status:'known-paths-blocked'}));
});

test('removing the combining rival restores the canonical Ji control path',()=>{
  expect(action(read('癸己丁甲','子酉卯亥','偏财'),'control:1:stem:0').status).toBe('blocked');
  expect(action(read('癸己丁辛','子酉卯亥','偏财'),'control:1:stem:0').status).toBe('available');
});

test('all supported paths to one threat coexist without a fabricated winner',()=>{
  const r=read('壬丁甲癸','申酉子亥');
  expect(r.threatResolutions).toContainEqual(expect.objectContaining({targetPosition:1,status:'co-supported-local-paths',
    availableActionIds:['combine:0:stem:1','control:3:stem:1']}));
});

test('source position selects monthly Xin while preserving the hourly namesake',()=>{
  const r=read('丙辛甲辛','寅卯子午','比肩');
  expect(r.occurrenceSelections).toEqual([expect.objectContaining({actorPosition:0,selectedTargetPosition:1,retainedTargetPositions:[3]})]);
  expect(action(r,'combine:0:stem:1')).toMatchObject({status:'available',localEffectEstablished:true});
  expect(action(r,'combine:0:stem:3')).toMatchObject({status:'retained',localEffectEstablished:false});
});

test('source occurrence choice does not override a target root or confer global success',()=>{
  const r=read('丙辛甲辛','酉卯子午','比肩');
  expect(r.occurrenceSelections).toHaveLength(1);
  expect(action(r,'combine:0:stem:1')).toMatchObject({status:'retained',localEffectEstablished:false,unresolvedReasons:['rooted-role-retained']});
  expect(r.outcomeEstablished).toBe(false);
});

test('changing the selected source configuration removes the occurrence privilege',()=>{
  expect(read('丙辛甲辛','寅酉子午').occurrenceSelections).toHaveLength(0);
  expect(read('辛丙甲辛','寅卯子午','比肩').occurrenceSelections).toHaveLength(0);
});

test('the explicit Lin case controls only the year occurrence; near-match remains unscoped',()=>{
  const exact=read('戊甲丁戊','辰寅卯申','正印');
  expect(action(exact,'control:1:stem:0')).toMatchObject({ruleId:'lin-sen-control-one-retain-one',status:'available'});
  expect(action(exact,'control:1:stem:3')).toMatchObject({status:'retained'});
  expect(read('戊甲丁戊','辰寅卯酉','正印').occurrenceSelections).toHaveLength(0);
});

test('textual disagreement, day self-combination and unscoped attacks remain explicit',()=>{
  const r=read('丙辛戊甲','午卯寅寅');
  expect(action(r,'combine:0:stem:1')).toMatchObject({status:'unresolved',unresolvedReasons:['source-conflict']});
  expect(r.unresolvedScopes).toContain('source-conflicts-and-cycles-have-no-universal-priority');
  expect(read('丁癸乙戊','巳酉卯戌','正财').actions.some((a:any)=>a.targetLayer==='month-main-qi')).toBe(false);
  const attacked=read('癸丁甲己','子酉寅丑');
  expect(action(attacked,'control:0:stem:1')).toMatchObject({status:'unresolved',attacks:[{actorPosition:3,status:'unresolved',protectionCombinationIndexes:[]}]});
});

test('reciprocal unresolved combinations cannot bootstrap a helper into availability',()=>{
  const r=read('癸戊甲丁','酉酉卯酉');
  expect(action(r,'control:0:stem:3')).toMatchObject({status:'unresolved',localEffectEstablished:false,
    blockingCombinationIndexes:[],unresolvedReasons:['unresolved-helper-combination']});
  expect(r.threatResolutions).toContainEqual(expect.objectContaining({targetPosition:3,status:'unresolved',availableActionIds:[]}));
});
