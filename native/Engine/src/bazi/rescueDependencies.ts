import type { CombinationRoleFinding } from './rescueAdjudication';

type Conditions=ReturnType<typeof import('./structural').computePatternConditions>;
type Status='available'|'blocked'|'unresolved'|'retained';
type Layer='stem'|'month-main-qi';
const helperSource='ziping-helper-constraints-v1',orderSource='ziping-xu-occurrence-selection-v1';

/** A second stage over occurrence-specific facts, not an iterative power score.
 * Only an established incoming combination can block an actor or release it
 * from an attacker. Unknown edges are never assumed to cancel one another.
 * Position selection is separate from efficacy (roots and opposition still apply).
 */
export function resolveRescueDependencies(c:Conditions,combinations:CombinationRoleFinding[]) {
  const {stems,hiddenStems,selectedYong}=c,day=stems[2].gan,month=stems[0].month.branch;
  const signature=stems.map(s=>s.gan+hiddenStems.find(h=>h.position===s.position)!.branch).join(' ');
  const order=stems.map(s=>s.gan).join('')==='丙辛甲辛'&&['寅','卯'].includes(month);
  const lin=signature==='戊辰 甲寅 丁卯 戊申';
  const occurrenceSelections=[
    ...(order?[{ruleId:'bing-selects-month-xin',actorPosition:0,selectedTargetPosition:1,retainedTargetPositions:[3],sourceIds:[orderSource]}]:[]),
    ...(lin?[{ruleId:'lin-sen-control-one-retain-one',actorPosition:1,selectedTargetPosition:0,retainedTargetPositions:[3],sourceIds:[orderSource]}]:[]),
  ];
  const indexes=(test:(v:CombinationRoleFinding)=>boolean)=>combinations.flatMap((v,i)=>test(v)?[i]:[]);
  const removed=(position:number)=>indexes(v=>v.targetPosition===position&&v.removalEstablished);
  const specs:{actor:number;target:number;layer:Layer;gan:string;relation:'合'|'克'|'生';ruleId:string}[]=[];
  const put=(actor:number,target:number,layer:Layer,gan:string,relation:'合'|'克'|'生',ruleId:string)=>{
    if(!specs.some(s=>s.actor===actor&&s.target===target&&s.layer===layer&&s.relation===relation))specs.push({actor,target,layer,gan,relation,ruleId});
  };
  for(const p of c.rescueCandidates){
    const canonical=p.relation==='克'&&month==='酉'&&(
      (day==='甲'&&selectedYong==='正官'&&stems[p.remedyPosition].gan==='癸'&&stems[p.triggerPosition].gan==='丁')||
      (day==='丁'&&['正财','偏财'].includes(selectedYong)&&stems[p.remedyPosition].gan==='己'&&stems[p.triggerPosition].gan==='癸'));
    put(p.remedyPosition,p.triggerPosition,'stem',stems[p.triggerPosition].gan,p.relation,
      p.relation==='合'?'xu-combination-role':canonical?'canonical-helper-control':'unscoped-action');
  }
  // The text identifies the monthly killing role, not an invented exposed Xin.
  if(day==='乙'&&month==='酉'&&selectedYong==='七杀'&&stems[0].gan==='丁'&&stems[1].gan==='癸'&&stems[3].gan==='戊')
    put(0,1,'month-main-qi','辛','克','ding-controls-killing-after-wu-binds-gui');
  for(const s of occurrenceSelections)for(const target of [s.selectedTargetPosition,...s.retainedTargetPositions])
    put(s.actorPosition,target,'stem',stems[target].gan,order?'合':'克',s.ruleId);
  const actions=specs.map(s=>{
    const id=(s.relation==='合'?'combine':s.relation==='克'?'control':'generate')+`:${s.actor}:${s.layer}:${s.target}`;
    const actorCombinationIndexes=indexes(v=>v.targetPosition===s.actor);
    const blockingCombinationIndexes=removed(s.actor);
    const attacks=stems[s.actor].constraints.filter(v=>v.relation==='克'&&v.actorPosition!==2).map(v=>{
      const protectionCombinationIndexes=removed(v.actorPosition);
      return {actorPosition:v.actorPosition,protectionCombinationIndexes,status:protectionCombinationIndexes.length?'neutralized' as const:'unresolved' as const};
    });
    let status:Status='unresolved',unresolvedReasons:string[]=[];
    const selection=occurrenceSelections.find(v=>v.actorPosition===s.actor&&v.ruleId===s.ruleId);
    if(selection?.retainedTargetPositions.includes(s.target)){status='retained';}
    else if(blockingCombinationIndexes.length){status='blocked';}
    else if(s.ruleId==='unscoped-action'){unresolvedReasons=['unresolved-rule-scope'];}
    else if(s.relation==='合'){
      const pair=combinations.find(v=>v.actorPosition===s.actor&&v.targetPosition===s.target)!;
      let pairStatus=pair.status;
      if(selection&&pairStatus==='unresolved-competing-pairs'){
        pairStatus=!stems[s.actor].sameElementRoots.length||attacks.some(a=>a.status==='unresolved')?
          'unresolved-relative-strength':'role-disabled-in-selected-profile';
      }
      if(pairStatus==='role-disabled-in-selected-profile'||pairStatus==='killing-role-redirected')status='available';
      else if(['rooted-role-retained','day-master-no-removal','blocked-by-intervening-geng'].includes(pairStatus)){
        status='retained';unresolvedReasons=[pairStatus];
      }else unresolvedReasons=[pairStatus];
    }else if(actorCombinationIndexes.some(i=>combinations[i].status.startsWith('unresolved')||combinations[i].status==='source-conflict')){
      unresolvedReasons=['unresolved-helper-combination'];
    }else if(attacks.some(a=>a.status==='unresolved')){unresolvedReasons=['unresolved-relative-strength'];}
    else status='available';
    return {id,ruleId:s.ruleId,actorPosition:s.actor,targetLayer:s.layer,targetPosition:s.target,targetGan:s.gan,relation:s.relation,
      status,localEffectEstablished:status==='available',actorCombinationIndexes,blockingCombinationIndexes,attacks,unresolvedReasons,
      sourceIds:selection?[orderSource]:s.relation==='合'?['ziping-xu-combination-limits-v1']:[helperSource]};
  });
  const targets=c.threats.map(t=>({targetLayer:'stem' as Layer,targetPosition:t.position,targetGan:t.gan as string}));
  for(const s of specs.filter(s=>s.layer==='month-main-qi'))targets.push({targetLayer:s.layer,targetPosition:s.target,targetGan:s.gan});
  const threatResolutions=targets.map(t=>{
    const paths=actions.filter(a=>a.targetLayer===t.targetLayer&&a.targetPosition===t.targetPosition);
    const availableActionIds=paths.filter(a=>a.status==='available').map(a=>a.id);
    const unresolvedActionIds=paths.filter(a=>a.status==='unresolved').map(a=>a.id);
    const blockedActionIds=paths.filter(a=>a.status==='blocked'||a.status==='retained').map(a=>a.id);
    return {...t,availableActionIds,blockedActionIds,unresolvedActionIds,
      status:availableActionIds.length>1?'co-supported-local-paths':availableActionIds.length?'supported-local-path':
        unresolvedActionIds.length?'unresolved':blockedActionIds.length?'known-paths-blocked':'no-scanned-path'};
  });
  return {methodVersion:'bazi-rescue-dependencies-v1',profileId:'ziping-xu-source-scoped-competition-v1',selectedYong,
    outcomeEstablished:false,actions,occurrenceSelections,threatResolutions,
    unresolvedScopes:['local-paths-do-not-establish-global-outcome','unresolved-attacks-are-not-cancelled-by-unresolved-protections',
      'source-conflicts-and-cycles-have-no-universal-priority','hidden-actors-outside-explicit-month-role-or-attested-case-unresolved']};
}
