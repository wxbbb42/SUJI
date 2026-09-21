import { HexagramEngine } from '../HexagramEngine';
import { getCalendarPillars } from '../../calendar/precision';
import type { CastOptions } from '../types';

// Ancient sources provide month/day coordinates, not Gregorian dates. Mock only that calendar boundary.
jest.mock('../../calendar/precision',()=>({getCalendarPillars:jest.fn()}));
const clock=getCalendarPillars as jest.Mock;
const engine=new HexagramEngine();
const run=(values:number[])=>engine.cast({question:'三合成员结构核对',castTime:new Date('2026-09-20T04:00:00Z'),
  lineValues:values as CastOptions['lineValues']}) as any;
const setCalendar=(month:string,day:string)=>clock.mockReturnValue({month,day,hour:'丙午'});
beforeEach(()=>setCalendar('乙卯','丁巳'));
const group=(reading:any,scope:string,element:string,anchorPath:string|null=null)=> {
  expect(reading.triads).toBeDefined();
  return reading.triads.groups.find((g:any)=>g.scope===scope&&g.element===element&&g.anchorPath===anchorPath);
};
const members=(g:any)=>g.members.map((m:any)=>[m.branch,m.role,m.objectPaths]);
const pointer=(r:any,p:string)=>p.slice(1).split('/').reduce((v:any,k:string)=>v[k],r);
const unresolved=['motion-threshold','dark-movement','member-strength','void-break-effectiveness','tomb-effectiveness','clash-effectiveness','binding-or-transformation','selected-object','event-outcome'];

// Catches cross-half borrowing and static 2/5 changed projections.
test('literal /19 离→坤 keeps inner木 and outer金 endpoint identities separate',()=>{
  const r=run([9,8,9,9,8,9]);
  expect([r.benGua.name,r.bianGua.name]).toEqual(['离为火','坤为地']);
  expect(members(group(r,'inner-change','木'))).toEqual([
    ['亥','birth',['/lines/2']],['卯','center',['/lines/0','/lines/2/changed']],['未','tomb',['/lines/0/changed']],
  ]);
  expect(members(group(r,'outer-change','金'))).toEqual([
    ['巳','birth',['/lines/5']],['酉','center',['/lines/3','/lines/5/changed']],['丑','tomb',['/lines/3/changed']],
  ]);
  for(const g of r.triads.groups)for(const forbidden of ['/lines/1/changed','/lines/4/changed'])
    expect(g.members.flatMap((m:any)=>m.objectPaths)).not.toContain(forbidden);
});

test('literal 复→谦 retains both 辰 identities and adverse month/day and returning conditions',()=>{
  setCalendar('乙未','戊辰');
  const r=run([9,8,6,8,8,8]),g=group(r,'inner-change','水');
  expect(members(g)).toEqual([
    ['申','birth',['/lines/2/changed']],['子','center',['/lines/0']],['辰','tomb',['/lines/0/changed','/lines/2']],
  ]);
  expect(g).toMatchObject({complete:true,centerPresent:true,missingBranches:[],contextPaths:[
    '/lines/2/changed/context','/lines/0/context','/lines/0/changed/context','/lines/2/context',
  ]});
  expect(r.lines[0].context.month.elementRelation).toBe('克爻');
  expect(r.lines[0].context.day.elementRelation).toBe('克爻');
  expect(r.lines[0].rules.returning.relation).toBe('回头克');
  expect(r.lines[2].changed.context.month.elementRelation).toBe('生爻');
  expect(r.lines[2].changed.context.day.elementRelation).toBe('生爻');
});

test('literal 革→家人 binds 日月世 to moving亥 alone and preserves outer duplicate未 and conflicts',()=>{
  setCalendar('乙卯','癸未');
  const r=run([7,8,7,9,7,6]);
  expect(r.lines[3].isShi).toBe(true);
  expect(members(group(r,'calendar-moving-anchor','木','/lines/3'))).toEqual([
    ['亥','birth',['/lines/3']],['卯','center',['/castGanZhi/month']],['未','tomb',['/castGanZhi/day']],
  ]);
  const g=group(r,'outer-change','木');
  expect(members(g)).toEqual([
    ['亥','birth',['/lines/3']],['卯','center',['/lines/5/changed']],['未','tomb',['/lines/3/changed','/lines/5']],
  ]);
  expect(r.lines[3].rules.returning.relation).toBe('回头克');
  expect(r.lines[3].context.day.elementRelation).toBe('克爻');
  expect(r.lines[5].context.month.elementRelation).toBe('克爻');
  expect(r.triads.groups.some((x:any)=>x.anchorPath==='/lines/2')).toBe(false);
});

test('daily clash never promotes static anchors and one moving endpoint never opens a change route',()=>{
  setCalendar('甲寅','戊午');
  const r=run([7,8,8,6,6,7]);
  expect(group(r,'calendar-moving-anchor','火','/lines/3').complete).toBe(true);
  expect(r.lines[0].dayClash).toBe(true);
  expect(r.lines[0].isChanging).toBe(false);
  expect(r.triads.groups.some((g:any)=>g.scope.endsWith('-change')||g.anchorPath==='/lines/0')).toBe(false);
});

test('all-static complete visible sets stay structural with no calendar or changed routes',()=>{
  setCalendar('甲申','戊辰');
  const r=run([7,7,7,7,7,7]);
  expect(group(r,'visible-originals','水')).toMatchObject({complete:true,centerPresent:true,missingBranches:[]});
  expect(r.triads.groups.map((g:any)=>[g.scope,g.element])).toEqual([['visible-originals','水'],['visible-originals','火']]);
  expect(r.triads).toMatchObject({sourceId:'liuyao-triad-selected-v1',assessmentStatus:'structural-only',efficacyEstablished:false,unresolved});
});

test('missing center stays missing despite duplicate originals; missing birth or tomb stays incomplete',()=>{
  // Calendar route duplicates 申 but cannot replace center子.
  setCalendar('甲申','戊辰');
  const missingCenter=group(run([8,8,9,8,8,8]),'calendar-moving-anchor','水','/lines/2');
  expect(members(missingCenter)).toEqual([
    ['申','birth',['/lines/2','/castGanZhi/month']],['子','center',[]],['辰','tomb',['/castGanZhi/day']],
  ]);
  expect(missingCenter).toMatchObject({missingBranches:['子'],complete:false,centerPresent:false});
  setCalendar('甲子','戊辰');
  expect(group(run([9,7,7,7,7,7]),'calendar-moving-anchor','水','/lines/0')).toMatchObject({missingBranches:['申'],complete:false,centerPresent:true});
  setCalendar('甲申','甲子');
  expect(group(run([9,7,7,7,7,7]),'calendar-moving-anchor','水','/lines/0')).toMatchObject({missingBranches:['辰'],complete:false,centerPresent:true});
});

test('all4096 casts match independent literal branch and route oracle with exact condition references',()=>{
  const inner:Record<string,string>={'111':'子寅辰','110':'巳卯丑','101':'卯丑亥','100':'子寅辰','011':'丑亥酉','010':'寅辰午','001':'辰午申','000':'未巳卯'};
  const outer:Record<string,string>={'111':'午申戌','110':'亥酉未','101':'酉未巳','100':'午申戌','011':'未巳卯','010':'申戌子','001':'戌子寅','000':'丑亥酉'};
  const tables=[['申子辰','水'],['巳酉丑','金'],['寅午戌','火'],['亥卯未','木']];
  let incomplete=0,missingCenter=0,completeStatic=0,hidden=0,hiddenCannotFill=0,staticProjectionCannotFill=0,crossHalfCannotFill=0;
  for(let n=0;n<4096;n++) {
    const values=Array.from({length:6},(_,i)=>6+Math.floor(n/4**i)%4);
    const bits=values.map(v=>v%2).join(''),after=values.map(v=>Number(v===6||v===7)).join('');
    const beforeBranches=[...inner[bits.slice(0,3)],...outer[bits.slice(3)]];
    const afterBranches=[...inner[after.slice(0,3)],...outer[after.slice(3)]];
    const moving=values.map(v=>v===6||v===9),r=run(values);
    expect(r.triads).toBeDefined();
    expect(r.lines.map((l:any)=>l.ganZhi.slice(-1))).toEqual(beforeBranches);
    const actual:Record<string,string>={};
    beforeBranches.forEach((b,i)=>{actual[`/lines/${i}`]=b;if(moving[i])actual[`/lines/${i}/changed`]=afterBranches[i];});
    actual['/castGanZhi/month']='卯';actual['/castGanZhi/day']='巳';
    const routes:Array<[string,string|null,string[]]>=[['visible-originals',null,values.map((_,i)=>`/lines/${i}`)]];
    moving.forEach((m,i)=>{if(m)routes.push(['calendar-moving-anchor',`/lines/${i}`,[`/lines/${i}`,'/castGanZhi/month','/castGanZhi/day']]);});
    if(moving[0]&&moving[2])routes.push(['inner-change',null,['/lines/0','/lines/0/changed','/lines/2','/lines/2/changed']]);
    if(moving[3]&&moving[5])routes.push(['outer-change',null,['/lines/3','/lines/3/changed','/lines/5','/lines/5/changed']]);
    const expected:any[]=[];
    for(const [scope,anchorPath,pool] of routes)for(const [branches,element] of tables) {
      const present=new Set(pool.map(p=>actual[p]).filter(b=>branches.includes(b)));
      if(present.size<2||(anchorPath&&!branches.includes(actual[anchorPath])))continue;
      const ms=[...branches].map((branch,i)=>({branch,role:['birth','center','tomb'][i],objectPaths:pool.filter(p=>actual[p]===branch)}));
      const paths=ms.flatMap(m=>m.objectPaths).filter(p=>p.startsWith('/lines/'));
      const missingBranches=[...branches].filter(b=>!present.has(b));
      for(const missing of missingBranches) {
        hiddenCannotFill+=Number(r.lines.some((l:any)=>l.hidden?.ganZhi.slice(-1)===missing));
        staticProjectionCannotFill+=Number(afterBranches.some((b,i)=>!moving[i]&&b===missing));
        crossHalfCannotFill+=Number(afterBranches.some((b,i)=>moving[i]&&b===missing&&
          (scope==='inner-change'?i>=3:scope==='outer-change'?i<3:false)));
      }
      const g={scope,anchorPath,element,members:ms,missingBranches,complete:present.size===3,centerPresent:present.has(branches[1]),
        contextPaths:paths.map(p=>p+'/context'),
        tombReferencePaths:paths.map(p=>`/tombExtinction/objects/${r.tombExtinction.objects.findIndex((o:any)=>o.objectPath===p)}`),
        dayClashRulePaths:paths.filter(p=>/^\/lines\/\d$/.test(p)&&pointer(r,p).rules?.dayClash).map(p=>p+'/rules/dayClash')};
      expected.push(g);
      incomplete+=Number(!g.complete);missingCenter+=Number(!g.centerPresent);completeStatic+=Number(g.complete&&!moving.some(Boolean));
    }
    expect(r.triads).toEqual({sourceId:'liuyao-triad-selected-v1',assessmentStatus:'structural-only',efficacyEstablished:false,groups:expected,unresolved});
    for(const g of r.triads.groups)for(const key of ['contextPaths','tombReferencePaths','dayClashRulePaths'])for(const p of g[key])expect(pointer(r,p)).toBeDefined();
    hidden+=r.lines.filter((l:any)=>l.hidden).length;
  }
  expect(incomplete).toBeGreaterThan(0);expect(missingCenter).toBeGreaterThan(0);expect(completeStatic).toBeGreaterThan(0);expect(hidden).toBeGreaterThan(0);
  expect(hiddenCannotFill).toBeGreaterThan(0);expect(staticProjectionCannotFill).toBeGreaterThan(0);expect(crossHalfCannotFill).toBeGreaterThan(0);
},30000);

test('supplementation preserves triads, contexts and source provenance without mutating original',()=>{
  const r=run([9,8,9,9,8,9]),saved=JSON.stringify(r);
  expect(r.triads).toBeDefined();
  const revised=engine.reassessQuestion(r,{question:'改问父母',questionType:'parents'});
  expect((revised as any).triads).toBe(r.triads);expect(revised.lines).toBe(r.lines);expect(JSON.stringify(r)).toBe(saved);
  const source=r.ruleSources.find((s:any)=>s.id===r.triads.sourceId);
  expect(source).toMatchObject({version:'1',editionStatus:'electronic-transcription-not-print-collated'});
  expect(source.references.map((x:any)=>[x.url,x.sha256])).toEqual([
    ['https://zh.wikisource.org/wiki/增刪卜易/19','087c35339f209c6d1359c01d8a918a535eb6151729973fc09ef960c1195f3fdf'],
    ['https://zh.wikisource.org/wiki/增刪卜易','897f963b938ec4582bc892465301b831a6439216f317841f44b888117704ca07'],
    ['https://zh.wikisource.org/wiki/易林補遺/1','abf77e78f3fbf77e33c2520e2a3525898894e5f5b0863fb5fa2c44619daab967'],
  ]);
});
