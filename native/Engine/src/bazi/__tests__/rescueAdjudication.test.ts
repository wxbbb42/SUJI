import { computeGeJuV2, computePatternConditions } from '../structural';
import { adjudicateRescue } from '../rescueAdjudication';
import type { DiZhi, ShiShen, TianGan } from '../types';
import { RESCUE_SOURCES } from '../rescueSources';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { resolve } from 'node:path';

// Independent rule coordinates, not claims of historical civil birth times.
const read = (stems:TianGan[], branches:DiZhi[], yong:ShiShen='正官') =>
  adjudicateRescue(computePatternConditions(stems[2],stems as any,branches as any,yong));
const pair = (r:ReturnType<typeof read>,actor:number,target:number) =>
  r.combinations.find((v:any)=>v.actorPosition===actor&&v.targetPosition===target)!;

test('rooted Ding retains its role, including a same-element Bing root in Yin',()=>{
  const stems:TianGan[]=['壬','丁','甲','辛'];
  expect(pair(read(stems,['申','酉','寅','丑']),0,1)).toMatchObject({status:'rooted-role-retained',removalEstablished:false});
  expect(pair(read(stems,['申','酉','子','丑']),0,1)).toMatchObject({status:'role-disabled-in-selected-profile',removalEstablished:true});
});

test('day-master self combination never removes the other actor',()=>{
  const r=read(['辛','庚','乙','戊'],['酉','申','卯','辰']);
  expect(pair(r,2,1)).toMatchObject({status:'day-master-no-removal',removalEstablished:false});
});

test('Jia cannot cross controlling Geng to combine Ji; no generic all-remote veto',()=>{
  const r=read(['甲','庚','壬','己'],['寅','申','子','未']);
  expect(pair(r,0,3)).toMatchObject({status:'blocked-by-intervening-geng',blockingPositions:[1]});
  const other=read(['乙','甲','丁','庚'],['酉','申','巳','戌']);
  expect(pair(other,0,3).status).not.toBe('blocked-by-intervening-geng');
  expect(pair(other,0,3).removalEstablished).toBe(false);
});

test('year-month combination is not converted to contention by matching day master',()=>{
  const r=read(['甲','己','甲','壬'],['卯','子','卯','子'],'正财');
  expect(pair(r,0,1)).toMatchObject({status:'role-disabled-in-selected-profile',competingPositions:[]});
  expect(pair(r,2,1).status).toBe('day-master-no-removal');
});

test('non-day competing copies remain unresolved and preserve every occurrence',()=>{
  const r=read(['癸','戊','庚','癸'],['酉','午','酉','未']);
  expect(pair(r,1,0)).toMatchObject({status:'unresolved-competing-pairs',competingPositions:[3]});
  expect(pair(r,1,3)).toMatchObject({targetPosition:3,removalEstablished:false});
});

test('Yi/Geng redirected killing role is distinguished from removal',()=>{
  const r=read(['乙','庚','甲','壬'],['寅','卯','子','午'],'七杀');
  expect(pair(r,0,1)).toMatchObject({status:'killing-role-redirected',removalEstablished:false});
});

test('documented rooted Bing/Xin counterexample remains an explicit source conflict',()=>{
  const r=read(['丙','辛','戊','甲'],['午','卯','寅','寅'],'正官');
  expect(pair(r,1,0)).toMatchObject({status:'source-conflict',removalEstablished:false});
});

test('unopposed canonical Gui restraint is available locally without a global outcome',()=>{
  const r=read(['癸','丁','甲','辛'],['子','酉','寅','丑']);
  expect(r.rescuePaths).toContainEqual(expect.objectContaining({triggerPosition:1,remedyPosition:0,relation:'克',status:'available-in-selected-profile'}));
  expect(r).toMatchObject({globalResolution:'unresolved',outcomeEstablished:false});
});

test('rootless helper bound by rooted Wu cannot continue to rescue Ding',()=>{
  const r=read(['丁','癸','甲','戊'],['未','酉','寅','戌']);
  expect(r.rescuePaths).toContainEqual(expect.objectContaining({triggerPosition:0,remedyPosition:1,relation:'克',status:'blocked-helper-combined',blockingPositions:[3]}));
  expect(computeGeJuV2('甲',['丁','癸','甲','戊'],['未','酉','寅','戌']).chengBai).toBe('po');
});

test('rooted Gui blocks an automatic removal claim but still needs Wu/Gui relative efficacy',()=>{
  const r=read(['丁','癸','甲','戊'],['未','酉','寅','辰']);
  expect(pair(r,3,1).status).toBe('rooted-role-retained');
  expect(r.rescuePaths).toContainEqual(expect.objectContaining({triggerPosition:0,remedyPosition:1,status:'unresolved-relative-strength'}));
});

test('canonical Ding wealth helper Ji loses restraint when rootless and bound by Jia',()=>{
  const a=read(['癸','己','丁','甲'],['子','酉','卯','亥'],'偏财');
  expect(a.rescuePaths).toContainEqual(expect.objectContaining({triggerPosition:0,remedyPosition:1,relation:'克',status:'blocked-helper-combined',blockingPositions:[3]}));
  const b=read(['癸','己','丁','辛'],['子','酉','卯','亥'],'偏财');
  expect(b.rescuePaths).toContainEqual(expect.objectContaining({triggerPosition:0,remedyPosition:1,relation:'克',status:'available-in-selected-profile'}));
});

test('canonical remote Wu protects Ding from rootless Gui; rooted Gui prevents that conclusion',()=>{
  const stems:TianGan[]=['丁','癸','乙','戊'];
  const a=read(stems,['巳','酉','卯','戌'],'七杀');
  expect(a.helperProtections).toContainEqual(expect.objectContaining({helperPosition:0,attackerPosition:1,remedyPosition:3,relation:'合',status:'available-in-selected-profile'}));
  const b=read(stems,['巳','酉','卯','辰'],'七杀');
  expect(b.helperProtections).toContainEqual(expect.objectContaining({helperPosition:0,attackerPosition:1,remedyPosition:3,status:'rooted-role-retained'}));
  const c=read(['丁','癸','乙','己'],['巳','酉','卯','戌'],'七杀');
  expect(c.helperProtections.some((v:any)=>v.relation==='合')).toBe(false);
});

test('rooted peer does not become a fully rescued wealth threat solely through combining',()=>{
  const stems:[TianGan,TianGan,TianGan,TianGan]=['乙','庚','甲','戊'];
  expect(computeGeJuV2('甲',stems,['子','辰','申','子']).chengBai).toBe('po');
  expect(computeGeJuV2('甲',stems,['子','丑','申','子']).chengBai).toBe('jiuying');
});

test('source-attested hidden wealth can act, while a changed chart is not generalized from it',()=>{
  const a=read(['丙','戊','辛','壬'],['戌','戌','未','辰'],'正印');
  expect(a.hiddenRoles.filter((v:any)=>v.status==='source-attested-case')).toEqual([
    expect.objectContaining({position:2,gan:'乙',role:'hidden-wealth-restrains-resource'}),
    expect.objectContaining({position:3,gan:'乙',role:'hidden-wealth-restrains-resource'}),
  ]);
  const b=read(['丙','戊','辛','壬'],['戌','戌','未','丑'],'正印');
  expect(b.hiddenRoles.some((v:any)=>v.status==='source-attested-case')).toBe(false);
});

test('hidden Ding in the documented resource case is not blindly robbed by Zi resource',()=>{
  const r=read(['庚','戊','甲','乙'],['戌','子','戌','亥'],'正印');
  expect(r.hiddenRoles.filter((v:any)=>v.status==='source-attested-case')).toEqual([
    expect.objectContaining({position:0,gan:'丁',role:'hidden-food-not-robbed-by-zi-resource'}),
    expect.objectContaining({position:2,gan:'丁',role:'hidden-food-not-robbed-by-zi-resource'}),
  ]);
});

test('Mao and Yin branch helpers retain their own You/Shen clash blockers',()=>{
  for(const [helper,blocker] of [['卯','酉'],['寅','申']] as const){
    const r=read(['丙','辛','癸','甲'],[helper,'亥','未',blocker],'劫财');
    expect(r.branchHelpers).toContainEqual(expect.objectContaining({position:0,branch:helper,status:'helper-clashed',blockingPositions:[3]}));
  }
});

test('regular production output exposes the same scoped adjudication without changing assessment scope',()=>{
  const g=computeGeJuV2('甲',['癸','丁','甲','辛'],['子','酉','寅','丑']);
  expect(g).toMatchObject({assessmentStatus:'heuristic-candidate',rescueEvidence:{methodVersion:'bazi-rescue-adjudication-v1',outcomeEstablished:false}});
});

test('all rescue quotations match the exact archived electronic witnesses',()=>{
  for(const source of RESCUE_SOURCES){
    const data=readFileSync(resolve(__dirname,'../../../../../',source.document));
    expect(createHash('sha256').update(data).digest('hex')).toBe(source.sha256);
    for(const quote of [source.quote,...source.additionalQuotes])expect(data.toString('utf8')).toContain(quote);
  }
});

test('a threat with no candidate path is retained in coverage',()=>{
  const r=read(['丁','辛','甲','丙'],['未','酉','寅','午']);
  expect(r.threatCoverage).toContainEqual({position:0,gan:'丁',status:'no-scanned-path'});
});
