import { HexagramEngine } from '../HexagramEngine';
import { getCalendarPillars } from '../../calendar/precision';
import type { CastOptions } from '../types';

const oracle=require('../../../validation/research-divination/triad-fanfu-source-review.json');
// Source examples give traditional coordinates; the fixed timestamp does not reconstruct an ancient date.
jest.mock('../../calendar/precision',()=>({getCalendarPillars:jest.fn()}));
const clock=getCalendarPillars as jest.Mock;
const engine=new HexagramEngine();
const run=(lineValues:number[])=>engine.cast({question:'仅核对反伏结构，不验证古例结果',questionType:'health',
  questionContext:{subject:'self',event:'结构核对',timeHorizon:'near'},
  castTime:new Date('2026-09-20T04:00:00Z'),lineValues:lineValues as CastOptions['lineValues']}) as any;
beforeEach(()=>clock.mockReturnValue({month:'乙卯',day:'壬申',hour:'丙午'}));

test('比→井 separates moving-line clashes from the three-position inner projection',()=>{
  const reading=run([8,6,6,8,7,8]);
  expect(reading.fanfu).toBeDefined();
  expect([reading.benGua.name,reading.bianGua.name]).toEqual(['水地比','水风井']);
  expect(reading.fanfu).toEqual({sourceId:'liuyao-fanfu-selected-v1',assessmentStatus:'structural-only',efficacyEstablished:false,
    lines:[
      {originalPath:'/lines/1',changedPath:'/lines/1/changed',sameStem:false,sameBranch:false,branchClash:true},
      {originalPath:'/lines/2',changedPath:'/lines/2/changed',sameStem:false,sameBranch:false,branchClash:true},
    ],trigrams:[
      {side:'lower',from:'坤',to:'巽',movingPositions:[2,3],branchRelation:'opposed',directionalOpposition:false},
      {side:'upper',from:'坎',to:'坎',movingPositions:[],branchRelation:'unchanged',directionalOpposition:false},
    ],unresolved:['selected-object','target-strength','actor-effectiveness','event-outcome']});
  expect(reading.lines[0].changed).toBeUndefined();
  expect(reading.guaRelations.original.ganZhi[0]).toBe('乙未');
  expect(reading.guaRelations.resulting.ganZhi[0]).toBe('辛丑');
  expect(reading.lines[2].context.month.sameBranch).toBe(true);
  expect(reading.lines[2].rules.returning.relation).toBe('回头克');
});

test('姤→恒 same branches remain distinct from changed stems and an unchanged lower trigram',()=>{
  clock.mockReturnValue({month:'壬申',day:'癸巳',hour:'戊午'});
  const reading=run([8,7,7,7,9,9]);
  expect(reading.fanfu).toBeDefined();
  expect(reading.fanfu.lines).toEqual([
    {originalPath:'/lines/4',changedPath:'/lines/4/changed',sameStem:false,sameBranch:true,branchClash:false},
    {originalPath:'/lines/5',changedPath:'/lines/5/changed',sameStem:false,sameBranch:true,branchClash:false},
  ]);
  expect(reading.lines.slice(4).map((l:any)=>[l.ganZhi,l.changed.ganZhi])).toEqual([['壬申','庚申'],['壬戌','庚戌']]);
  expect(reading.fanfu.trigrams).toEqual([
    {side:'lower',from:'巽',to:'巽',movingPositions:[],branchRelation:'unchanged',directionalOpposition:false},
    {side:'upper',from:'乾',to:'震',movingPositions:[5,6],branchRelation:'repeated',directionalOpposition:false},
  ]);
  expect(reading.lines[3].changed).toBeUndefined();
});

test('小畜→姤 directional opposition survives while actual moving lines combine instead of clash',()=>{
  const reading=run([9,7,7,6,7,7]);
  expect(reading.fanfu).toBeDefined();
  expect(reading.fanfu.lines).toEqual([
    {originalPath:'/lines/0',changedPath:'/lines/0/changed',sameStem:false,sameBranch:false,branchClash:false},
    {originalPath:'/lines/3',changedPath:'/lines/3/changed',sameStem:false,sameBranch:false,branchClash:false},
  ]);
  expect(reading.fanfu.trigrams).toEqual([
    {side:'lower',from:'乾',to:'巽',movingPositions:[1],branchRelation:'neither',directionalOpposition:true},
    {side:'upper',from:'巽',to:'乾',movingPositions:[4],branchRelation:'neither',directionalOpposition:true},
  ]);
  expect(reading.lines[0].rules.returning.branchRelation).toBe('六合');
  expect(reading.lines[3].rules.returning.branchRelation).toBe('六合');
});

test('static pure gua and a static internal opposing pair do not become dynamic fanfu',()=>{
  for(const [values,lower,upper] of [
    [[7,7,7,7,7,7],'乾','乾'],[[7,8,7,8,7,8],'离','坎'],
  ] as const) {
    const reading=run([...values]);
    expect(reading.fanfu).toBeDefined();
    expect(reading.fanfu.lines).toEqual([]);
    expect(reading.fanfu.trigrams).toEqual([
      {side:'lower',from:lower,to:lower,movingPositions:[],branchRelation:'unchanged',directionalOpposition:false},
      {side:'upper',from:upper,to:upper,movingPositions:[],branchRelation:'unchanged',directionalOpposition:false},
    ]);
  }
});

// Literal source vectors were written before this implementation, with their original coordinates and limitations.
for(const f of [...oracle.classicalVectors,...oracle.structuralCounterexamples].filter((f:any)=>f.expected.lineClashPositions)) {
  test(f.id+' retains separately scoped positive and negative findings',()=>{
    if(f.monthBranch) {
      const evenBranch='子寅辰午申戌'.includes(f.monthBranch);
      clock.mockReturnValue({month:(evenBranch?'甲':'乙')+f.monthBranch,day:f.dayGanZhi,hour:'丙午'});
    }
    const reading=run(f.values);
    expect(reading.fanfu).toBeDefined();
    expect([reading.benGua.name,reading.bianGua.name]).toEqual([f.original,f.resulting]);
    expect(reading.lines.map((l:any)=>l.ganZhi[1])).toEqual(f.originalBranches);
    expect(reading.guaRelations.resulting.ganZhi.map((s:string)=>s[1])).toEqual(f.resultingProjectionBranches);
    expect(reading.fanfu.lines.map((l:any)=>Number(l.originalPath.split('/')[2])+1)).toEqual(f.movingPositions);
    expect(reading.fanfu.lines.filter((l:any)=>l.branchClash).map((l:any)=>Number(l.originalPath.split('/')[2])+1)).toEqual(f.expected.lineClashPositions);
    expect(reading.fanfu.lines.filter((l:any)=>l.sameBranch).map((l:any)=>Number(l.originalPath.split('/')[2])+1)).toEqual(f.expected.lineSamePositions);
    const scopes=(field:string,value:any)=>reading.fanfu.trigrams.filter((t:any)=>t[field]===value).map((t:any)=>t.side==='lower'?'inner':'outer');
    expect(scopes('branchRelation','opposed')).toEqual(f.expected.changedTrigramClashScopes);
    expect(scopes('branchRelation','repeated')).toEqual(f.expected.changedTrigramSameScopes);
    expect(scopes('directionalOpposition',true)).toEqual(f.expected.directionalTrigramOppositionScopes);
    expect(reading.fanfu.efficacyEstablished).toBe(false);
  });
}

test('all4096 casts obey independent full najia, same-position and changed-trigram pattern oracles',()=>{
  // Independent literal table; no production gua/najia/pair helper is imported into the oracle.
  const glyphs:Record<string,string>={'111':'乾','110':'兑','101':'离','100':'震','011':'巽','010':'坎','001':'艮','000':'坤'};
  const inner:Record<string,string[]>={乾:['甲子','甲寅','甲辰'],兑:['丁巳','丁卯','丁丑'],离:['己卯','己丑','己亥'],震:['庚子','庚寅','庚辰'],
    巽:['辛丑','辛亥','辛酉'],坎:['戊寅','戊辰','戊午'],艮:['丙辰','丙午','丙申'],坤:['乙未','乙巳','乙卯']};
  const outer:Record<string,string[]>={乾:['壬午','壬申','壬戌'],兑:['丁亥','丁酉','丁未'],离:['己酉','己未','己巳'],震:['庚午','庚申','庚戌'],
    巽:['辛未','辛巳','辛卯'],坎:['戊申','戊戌','戊子'],艮:['丙戌','丙子','丙寅'],坤:['癸丑','癸亥','癸酉']};
  const clashes=new Set(['子午','午子','丑未','未丑','寅申','申寅','卯酉','酉卯','辰戌','戌辰','巳亥','亥巳']);
  const repeated=new Set(['乾震','震乾']),opposed=new Set(['坤巽','巽坤']);
  const directional=new Set(['乾巽','巽乾','坎离','离坎','震兑','兑震','艮坤','坤艮']);
  let lineCount=0,repeatedCount=0,opposedCount=0,directionalCount=0,unchangedCount=0;
  for(let n=0;n<4096;n++) {
    const values=Array.from({length:6},(_,i)=>6+Math.floor(n/4**i)%4);
    const originalBits=values.map(v=>v%2).join(''),changedBits=values.map(v=>v===6||v===7?1:0).join('');
    const from=[glyphs[originalBits.slice(0,3)],glyphs[originalBits.slice(3)]],to=[glyphs[changedBits.slice(0,3)],glyphs[changedBits.slice(3)]];
    const originals=[...inner[from[0]],...outer[from[1]]],changed=[...inner[to[0]],...outer[to[1]]];
    const moving=values.flatMap((v,i)=>v===6||v===9?[i+1]:[]);
    const reading=run(values);
    expect(reading.fanfu).toBeDefined();
    const wantLines=moving.map(p=>({originalPath:`/lines/${p-1}`,changedPath:`/lines/${p-1}/changed`,
      sameStem:originals[p-1][0]===changed[p-1][0],sameBranch:originals[p-1][1]===changed[p-1][1],branchClash:clashes.has(originals[p-1][1]+changed[p-1][1])}));
    expect(reading.fanfu.lines).toEqual(wantLines);
    lineCount+=wantLines.length;
    const wantTrigrams=['lower','upper'].map((side,i)=>({side,from:from[i],to:to[i],movingPositions:moving.filter(p=>i===0?p<=3:p>=4),
      branchRelation:from[i]===to[i]?'unchanged':repeated.has(from[i]+to[i])?'repeated':opposed.has(from[i]+to[i])?'opposed':'neither',
      directionalOpposition:directional.has(from[i]+to[i])}));
    expect(reading.fanfu.trigrams).toEqual(wantTrigrams);
    for(const t of wantTrigrams) {
      repeatedCount+=Number(t.branchRelation==='repeated');opposedCount+=Number(t.branchRelation==='opposed');
      unchangedCount+=Number(t.branchRelation==='unchanged');directionalCount+=Number(t.directionalOpposition);
    }
    for(const l of reading.fanfu.lines) {
      const index=Number(l.originalPath.split('/')[2]);
      expect(reading.lines[index].ganZhi).toBe(originals[index]);
      expect(reading.lines[index].changed.ganZhi).toBe(changed[index]);
    }
  }
  expect({lineCount,repeatedCount,opposedCount,directionalCount,unchangedCount})
    .toEqual({lineCount:12288,repeatedCount:256,opposedCount:256,directionalCount:1024,unchangedCount:1024});
});

test('question supplementation keeps source-bound fanfu and all original objects byte-for-value',()=>{
  const original=run([8,6,6,8,9,9]),saved=JSON.stringify(original);
  expect(original.fanfu).toBeDefined();
  const revised=engine.reassessQuestion(original,{question:'改问父母',questionType:'parents',questionContext:{subject:'parent',event:'结构核对',timeHorizon:'far'}}) as any;
  expect(revised.fanfu).toBe(original.fanfu);
  expect(JSON.stringify(revised.fanfu)).toBe(JSON.stringify(original.fanfu));
  expect(revised.lines).toBe(original.lines);
  expect(JSON.stringify(original)).toBe(saved);
  const source=original.ruleSources.find((s:any)=>s.id===original.fanfu.sourceId);
  expect(source).toMatchObject({version:'1',editionStatus:'electronic-transcription-not-print-collated'});
  expect(source.references.map((r:any)=>[r.url,r.sha256])).toEqual([
    ['https://zh.wikisource.org/wiki/增刪卜易/25','10c6f672b4b68ea46217d8f053a8668034a757d5899447fda3f0934b82537fa2'],
    ['https://zh.wikisource.org/wiki/增刪卜易','897f963b938ec4582bc892465301b831a6439216f317841f44b888117704ca07'],
    ['https://zh.wikisource.org/wiki/易林補遺/1','abf77e78f3fbf77e33c2520e2a3525898894e5f5b0863fb5fa2c44619daab967'],
  ]);
});
