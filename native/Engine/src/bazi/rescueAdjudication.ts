import { RESCUE_SOURCES } from './rescueSources';
import { resolveRescueDependencies } from './rescueDependencies';

type Conditions = ReturnType<typeof import('./structural').computePatternConditions>;
export type CombinationRoleStatus = 'day-master-no-removal' | 'blocked-by-intervening-geng'
  | 'rooted-role-retained' | 'source-conflict' | 'unresolved-competing-pairs'
  | 'unresolved-remote-configuration' | 'unresolved-relative-strength'
  | 'killing-role-redirected' | 'role-disabled-in-selected-profile';
type PathStatus = CombinationRoleStatus | 'available-in-selected-profile' | 'blocked-helper-combined'
  | 'unresolved-helper-combination' | 'unresolved-rule-scope';
export type RescuePathStatus=PathStatus;
export interface CombinationRoleFinding {
  actorPosition:number; targetPosition:number; actorGan:string; targetGan:string;
  status:CombinationRoleStatus; removalEstablished:boolean;
  blockingPositions:number[]; competingPositions:number[]; sourceIds:string[];
}

/** Local role dependencies under the selected Xu commentary. The input retains
 * every exposed/hidden occurrence, so a same-named stem never inherits another
 * occurrence's remedy. No root weights or general pairwise power solver.
 */
export function adjudicateRescue(conditions:Conditions) {
  const {stems,hiddenStems}=conditions;
  const day=stems[2].gan, month=stems[0].month.branch;
  const branches=[0,1,2,3].map(i=>hiddenStems.find(v=>v.position===i)!.branch);
  const signature=stems.map((s,i)=>s.gan+branches[i]).join(' ');
  const has=(gan:string)=>stems.some((s,i)=>i!==2&&s.gan===gan);
  const sourceIds=['ziping-xu-combination-limits-v1'];
  const canonicalRemote=(a:number,b:number)=>{
    const pair=[stems[a].gan,stems[b].gan];
    if(day==='丁'&&month==='酉'&&has('癸')&&pair.includes('甲')&&pair.includes('己'))return true;
    if(!pair.includes('戊')||!pair.includes('癸')||month!=='酉')return false;
    // 相神紧要 explicitly permits 月癸/时戊 across 日乙. Its 官 case
    // also names 戊合癸 interrupting 癸制丁, without an adjacency limit.
    return (day==='甲'&&has('丁')) || (day==='乙'&&stems[0].gan==='丁'&&stems[1].gan==='癸'&&stems[3].gan==='戊');
  };
  const combinations:CombinationRoleFinding[]=stems.flatMap(target=>
    target.constraints.filter(v=>v.relation==='合').map(edge=>{
      const actor=stems[edge.actorPosition];
      const blockingPositions=edge.interveningPositions.filter(i=>
        ((actor.gan==='甲'&&target.gan==='己')||(actor.gan==='己'&&target.gan==='甲'))&&stems[i].gan==='庚');
      const competingPositions=[...new Set([
        ...actor.constraints.filter(v=>v.relation==='合'&&v.actorPosition!==target.position&&v.actorPosition!==2).map(v=>v.actorPosition),
        ...target.constraints.filter(v=>v.relation==='合'&&v.actorPosition!==actor.position&&v.actorPosition!==2).map(v=>v.actorPosition),
      ])];
      const actorAttacks=actor.constraints.filter(v=>v.relation==='克'&&v.actorPosition!==2&&v.actorPosition!==target.position);
      let status:CombinationRoleStatus;
      if(actor.position===2||target.position===2)status='day-master-no-removal';
      else if(blockingPositions.length)status='blocked-by-intervening-geng';
      else if(signature==='丙午 辛卯 戊寅 甲寅'&&actor.position<2&&target.position<2)status='source-conflict';
      else if(target.sameElementRoots.length)status='rooted-role-retained';
      else if(competingPositions.length)status='unresolved-competing-pairs';
      else if(!edge.adjacent&&!canonicalRemote(actor.position,target.position))status='unresolved-remote-configuration';
      else if(!actor.sameElementRoots.length||actorAttacks.length)status='unresolved-relative-strength';
      else if(day==='甲'&&actor.gan==='乙'&&target.gan==='庚')status='killing-role-redirected';
      else status='role-disabled-in-selected-profile';
      return {actorPosition:actor.position,targetPosition:target.position,actorGan:actor.gan,targetGan:target.gan,
        status,removalEstablished:status==='role-disabled-in-selected-profile',blockingPositions,competingPositions,
        sourceIds:canonicalRemote(actor.position,target.position)?[...sourceIds,'ziping-helper-constraints-v1']:sourceIds};
    }));
  const combination=(actor:number,target:number)=>combinations.find(v=>v.actorPosition===actor&&v.targetPosition===target)!;
  const helperBlockers=(position:number)=>combinations.filter(v=>v.targetPosition===position&&v.removalEstablished);
  const helperUnresolved=(position:number)=>combinations.some(v=>v.targetPosition===position&&
    (v.status.startsWith('unresolved')||v.status==='source-conflict'));
  const canonicalControl=(actor:number,target:number)=>month==='酉'&&(
    (day==='甲'&&stems[actor].gan==='癸'&&stems[target].gan==='丁')||
    (day==='丁'&&stems[actor].gan==='己'&&stems[target].gan==='癸'));
  const rescuePaths=conditions.rescueCandidates.map(path=>{
    const blockers=helperBlockers(path.remedyPosition);
    let status:PathStatus;
    if(blockers.length)status='blocked-helper-combined';
    else if(path.relation==='合'){
      const c=combination(path.remedyPosition,path.triggerPosition);
      status=c.removalEstablished||c.status==='killing-role-redirected'?'available-in-selected-profile':c.status;
    }else if(helperUnresolved(path.remedyPosition))status='unresolved-helper-combination';
    else if(stems[path.remedyPosition].constraints.some(v=>v.relation==='克'&&v.actorPosition!==2))status='unresolved-relative-strength';
    else if(path.relation==='克'&&canonicalControl(path.remedyPosition,path.triggerPosition))status='available-in-selected-profile';
    else status='unresolved-rule-scope';
    const {effectiveness:_,...facts}=path;
    return {...facts,status,blockingPositions:blockers.map(v=>v.actorPosition),sourceIds:['ziping-helper-constraints-v1']};
  });
  const helperProtections=conditions.helperProtectionCandidates.filter(path=>path.attackerPosition!==2).map(path=>{
    const blockers=helperBlockers(path.remedyPosition);
    let status:PathStatus;
    if(blockers.length)status='blocked-helper-combined';
    else if(path.relation==='合'){
      const c=combination(path.remedyPosition,path.attackerPosition);
      status=c.removalEstablished?'available-in-selected-profile':c.status;
    }else status='unresolved-relative-strength';
    const {effectiveness:_,...facts}=path;
    return {...facts,status,blockingPositions:blockers.map(v=>v.actorPosition),sourceIds:['ziping-helper-constraints-v1']};
  });
  const hiddenRoles=hiddenStems.map(hidden=>{
    let role='root-and-branch-context';
    let status:'context-only'|'source-attested-case'='context-only';
    if(signature==='丙戌 戊戌 辛未 壬辰'&&hidden.gan==='乙'&&(hidden.position===2||hidden.position===3)){
      role='hidden-wealth-restrains-resource';status='source-attested-case';
    }
    if(signature==='庚戌 戊子 甲戌 乙亥'&&hidden.gan==='丁'&&(hidden.position===0||hidden.position===2)){
      role='hidden-food-not-robbed-by-zi-resource';status='source-attested-case';
    }
    return {...hidden,role,status,exposedPositions:stems.filter(s=>s.gan===hidden.gan).map(s=>s.position),
      sourceIds:status==='source-attested-case'?['ziping-xu-hidden-action-cases-v1']:sourceIds};
  });
  const branchHelpers=branches.flatMap((branch,position)=>{
    if(day!=='癸'||month!=='亥'||!has('丙')||(branch!=='卯'&&branch!=='寅'))return [];
    const blockingPositions=branches.flatMap((b,i)=>b===(branch==='卯'?'酉':'申')?[i]:[]);
    return [{position,branch,blockingPositions,status:blockingPositions.length?'helper-clashed' as const:'helper-present-transformation-unresolved' as const,
      sourceIds:['ziping-helper-constraints-v1']}];
  });
  const threatCoverage=conditions.threats.map(({position})=>{
    const paths=rescuePaths.filter(p=>p.triggerPosition===position);
    return {position,gan:stems[position].gan,
      status:paths.some(p=>p.status==='available-in-selected-profile')?'has-supported-local-path' as const:
        paths.some(p=>p.status.startsWith('unresolved')||p.status==='source-conflict')?'unresolved' as const:
          paths.length?'known-paths-blocked' as const:'no-scanned-path' as const};
  });
  return {methodVersion:'bazi-rescue-adjudication-v1' as const,profileId:'ziping-xu-local-role-dependencies-v1' as const,
    outcomeEstablished:false as const,globalResolution:'unresolved' as const,
    combinations,rescuePaths,helperProtections,hiddenRoles,branchHelpers,threatCoverage,sources:RESCUE_SOURCES,
    dependencyResolution:resolveRescueDependencies(conditions,combinations),
    unresolvedScopes:['全局取相与全部病点尚未穷尽；局部路径可用不等于全格成败',
      '直接克边的相对力量及多条救应竞争未由根数或分数替代',
      '除明确命例外，藏干实际施事效力与支合解冲仍需配置条件',
      '徐注有根仍有用与丙午辛卯戊寅甲寅两失其用存在解释冲突；该命例明确标出',
      '本裁定不证明任何五合成化，也不裁定从格、专旺的克神救应']};
}
export type RescueAdjudication=ReturnType<typeof adjudicateRescue>;

/** A refuted local path must not count toward the legacy rescue candidate. */
export function isRefutedRescuePath(status:PathStatus):boolean {
  return status==='rooted-role-retained'||status==='day-master-no-removal'||
    status==='blocked-by-intervening-geng'||status==='blocked-helper-combined';
}
