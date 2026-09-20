import { computeGeJuV2, computePatternConditions } from '../structural';
import type { DiZhi,TianGan } from '../types';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { resolve } from 'node:path';
import { PATTERN_CONDITION_SOURCES } from '../patternSources';

// Independent literal coordinates, not claimed historical birth charts.
const read=(stems:TianGan[],branches:DiZhi[],yong:any='正官'):any=>computePatternConditions(stems[2],stems as any,branches as any,yong);

test('month 癸 may restrain year 丁 yet be constrained by remote hour 戊',()=>{
  const r=read(['丁','癸','甲','戊'],['未','酉','寅','辰']);
  expect(r.stems[1]).toMatchObject({position:1,gan:'癸',month:{branch:'酉',state:'相'}});
  expect(r.stems[1].constraints).toEqual(expect.arrayContaining([
    expect.objectContaining({actorPosition:3,relation:'克',adjacent:false,interveningPositions:[2]}),
    expect.objectContaining({actorPosition:3,relation:'合',adjacent:false,interveningPositions:[2]}),
  ]));
  expect(r.rescueCandidates).toEqual(expect.arrayContaining([expect.objectContaining({triggerPosition:0,remedyPosition:1,relation:'克',effectiveness:'unresolved',remedyContext:'/stems/1'})]));
  expect(r.outcomeEstablished).toBe(false);
});

test('resource control of 食神 is explicit even for 正印, without automatically judging damage',()=>{
  const r=read(['壬','丁','乙','辛'],['子','酉','未','亥'],'七杀');
  const helper=r.helperCandidates.find((v:any)=>v.position===1&&v.layer==='stem');
  expect(helper).toMatchObject({gan:'丁',shiShen:'食神',context:'/stems/1'});
  expect(r.stems[1].constraints).toEqual(expect.arrayContaining([
    expect.objectContaining({actorPosition:0,actorGan:'壬',relation:'克'}),expect.objectContaining({actorPosition:0,actorGan:'壬',relation:'合'}),
  ]));
});

test('roots distinguish exact stem, same element and generating support without a score',()=>{
  const a=read(['壬','丁','甲','辛'],['申','酉','寅','丑']);
  const b=read(['壬','丁','甲','辛'],['午','酉','寅','丑']);
  expect(a.stems[0].sameElementRoots).toContainEqual(expect.objectContaining({position:0,branch:'申',gan:'壬',tier:'zhong',sameStem:true}));
  expect(a.stems[0].generatingSupport).toContainEqual(expect.objectContaining({position:0,gan:'庚',tier:'ben'}));
  expect(b.stems[1].sameElementRoots).toContainEqual(expect.objectContaining({position:0,branch:'午',gan:'丁',tier:'ben',sameStem:true}));
  expect(b.stems[0].sameElementRoots).toContainEqual(expect.objectContaining({position:3,gan:'癸',sameStem:false}));
  expect(a.stems[0].score).toBeUndefined();
});

test('explicit remote helper protection: 年丁月癸日乙时戊, no adjacency-only universal rule',()=>{
  const r=read(['丁','癸','乙','戊'],['巳','酉','卯','辰'],'七杀');
  expect(r.helperProtectionCandidates).toContainEqual(expect.objectContaining({helperPosition:0,attackerPosition:1,remedyPosition:3,relation:'合',adjacent:false,effectiveness:'unresolved'}));
  // Swap 时戊 for 己: 己克癸 is a relation, but 戊癸五合 must disappear.
  const negative=read(['丁','癸','乙','己'],['巳','酉','卯','辰'],'七杀');
  expect(negative.helperProtectionCandidates.some((v:any)=>v.remedyPosition===3&&v.relation==='合')).toBe(false);
});

test('month clash remains alongside precise 六合 candidates and their own clashes',()=>{
  const r=read(['甲','丁','庚','己'],['申','午','子','丑']);
  expect(r.monthClashes).toContainEqual(expect.objectContaining({monthPosition:1,otherPosition:2,branches:['午','子'],reliefEstablished:false,
    combinationCandidates:expect.arrayContaining([expect.objectContaining({position:3,branch:'丑',combinesWithPosition:2})])}));
  const negative=read(['甲','丁','庚','己'],['申','午','子','酉']);
  expect(negative.monthClashes[0].combinationCandidates).toEqual([]);
});

test('multiple adjacent pairings are geometry, not a universal contest verdict',()=>{
  const r=read(['甲','己','甲','壬'],['寅','子','寅','子'],'正财');
  expect(r.stems[1].constraints.filter((v:any)=>v.relation==='合').map((v:any)=>v.actorPosition)).toEqual([0,2]);
  expect(r.stems[1].combinationAdjudication).toBe('unresolved');
  expect(r.stems[1].contestEstablished).toBeUndefined();
});

test('production regular pattern returns independently scoped conditional evidence and exact source records',()=>{
  const g=computeGeJuV2('甲',['丁','癸','甲','戊'],['未','酉','寅','辰']);
  expect(g.conditionalEvidence).toMatchObject({assessmentStatus:'conditions-only',outcomeEstablished:false});
  expect(g.conditionalEvidence?.sources[0]).toMatchObject({sha256:'5b930c11310899b50703696870d9024ba4e00fca6ad177e57d6fa5e3f8a4964f'});
});

test('cited hashes and excerpts match the archived text, including remote and order exceptions',()=>{
  for(const source of PATTERN_CONDITION_SOURCES) {
    const data=readFileSync(resolve(__dirname,'../../../../../',source.document));
    expect(createHash('sha256').update(data).digest('hex')).toBe(source.sha256);
    for(const quote of [source.quote,...source.additionalQuotes]) expect({quote,found:data.toString('utf8').includes(quote)}).toEqual({quote,found:true});
  }
});

test('same-named roots and helpers stay tied to their own columns; all context pointers resolve',()=>{
  const r=read(['丁','癸','甲','癸'],['子','酉','寅','子']);
  expect(r.helperCandidates.filter((v:any)=>v.layer==='stem'&&v.gan==='癸').map((v:any)=>v.position)).toEqual([1,3]);
  for(const c of [...r.rescueCandidates,...r.helperProtectionCandidates,...r.helperCandidates]) {
    for(const [key,path] of Object.entries(c)) if(key.endsWith('Context')||key==='context') {
      const value=String(path).split('/').slice(1).reduce((v:any,k:string)=>v?.[k],r);
      expect(value?.gan).toBeDefined();
    }
  }
});
