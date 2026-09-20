import { HexagramEngine } from '../HexagramEngine';
import type { CastOptions } from '../types';

let mockDay='丙辰',mockMonth='甲午';
jest.mock('@engine/calendar/precision',()=>({getCalendarPillars:()=>({year:'甲子',month:mockMonth,day:mockDay,hour:'甲子'})}));
const cast=(lineValues:CastOptions['lineValues']):any=>new HexagramEngine().cast({question:'结构复算，不验证古例现实结果',lineValues,castTime:new Date('2026-09-20T04:00:00Z')});
beforeEach(()=>{mockDay='丙辰';mockMonth='甲午';});
const combined=['天地否','地天泰','雷地豫','地雷复','泽水困','水泽节','火山旅','山火贲'].sort();
const clashed=['乾为天','坤为地','震为雷','巽为风','坎为水','离为火','艮为山','兑为泽','天雷无妄','雷天大壮'].sort();
const resolve=(root:any,path:string)=>path.split('/').slice(1).reduce((v,k)=>v?.[k],root);

test('all64: eight六合 and ten六冲, stationary does not erase pairs or invent a transition',()=>{
  const matches:Record<string,string[]>={'六合':[],'六冲':[]};
  for(let n=0;n<64;n++) {
    const r=cast(Array.from({length:6},(_,i)=>n&(1<<i)?7:8) as CastOptions['lineValues']);
    expect(r.guaRelations).toBeDefined();
    const f=r.guaRelations;
    if(matches[f.original.kind]) matches[f.original.kind].push(r.benGua.name);
    expect(f.resulting).toMatchObject({kind:f.original.kind,ganZhi:f.original.ganZhi});
    expect(f.transition).toMatchObject({hasChange:false,kind:'static'});
    expect(f.outcomeEstablished).toBe(false);
    expect(f.original.pairs.map((p:any)=>p.positions)).toEqual([[1,4],[2,5],[3,6]]);
    expect(r.lines.every((l:any)=>!l.changed&&!l.rules.returning)).toBe(true);
  }
  expect(matches['六合'].sort()).toEqual(combined);
  expect(matches['六冲'].sort()).toEqual(clashed);
});

test.each([
  [[7,7,7,9,9,9],'乾为天','地天泰','六冲变六合'],
  [[6,8,7,9,8,7],'火山旅','山火贲','六合变六合'],
  [[9,8,7,7,8,7],'离为火','火山旅','六冲变六合'],
  [[6,7,8,9,7,8],'泽水困','水泽节','六合变六合'],
  [[6,6,6,7,7,7],'天地否','乾为天','六合变六冲'],
  [[9,8,9,9,8,9],'离为火','坤为地','六冲变六冲'],
  [[8,9,9,7,8,8],'雷风恒','雷地豫','other-change'],
])('classical chart transition %j keeps original/resulting identities',(values,original,resulting,kind)=>{
  const r=cast(values as CastOptions['lineValues']);
  expect(r.benGua.name).toBe(original);expect(r.bianGua.name).toBe(resulting);
  expect(r.guaRelations).toMatchObject({assessmentStatus:'structural-only',outcomeEstablished:false,transition:{hasChange:true,kind}});
});

test('离→旅: full resulting 纳甲 is not six independently moving changed lines',()=>{
  const r=cast([9,8,7,7,8,7]);
  expect(r.guaRelations).toBeDefined();
  expect(r.guaRelations.original.ganZhi).toEqual(['己卯','己丑','己亥','己酉','己未','己巳']);
  expect(r.guaRelations.resulting.ganZhi).toEqual(['丙辰','丙午','丙申','己酉','己未','己巳']);
  expect(r.guaRelations.resulting.pairs).toEqual([
    {positions:[1,4],relation:'六合'},
    {positions:[2,5],relation:'六合'},
    {positions:[3,6],relation:'六合'},
  ]);
  expect(r.changingYao).toEqual([1]);
  expect(r.lines[0].changed.ganZhi).toBe('丙辰');
  expect(r.lines[1].changed).toBeUndefined();expect(r.lines[2].changed).toBeUndefined();
});

test('恒→豫: 酉→卯 is returning branch clash but not returning control; static丑→未 is decoration only',()=>{
  const r=cast([8,9,9,7,8,8]);
  expect(r.lines[2].rules.returning).toMatchObject({branchRelation:'六冲',from:'/lines/2/changed',to:'/lines/2',assessmentStatus:'structural-relation',branchSourceId:'liuyao-calendar-relations-v1'});
  expect(r.lines[2].rules.returning.relation).toBe('本爻克变');
  expect(r.lines[2].context.day.combination).toBe(true);
  expect(r.lines[0].rules.returning).toBeUndefined();
});

test('姤→乾: original丑 and changed子 combine without overwriting five-element control direction',()=>{
  const r=cast([6,7,7,7,7,7]);
  expect(r.lines[0].rules.returning).toMatchObject({branchRelation:'六合'});
  // 丑土克子水, not same-element 比和 (a branch合 must not overwrite五行 direction).
  expect(r.lines[0].rules.returning.relation).toBe('本爻克变');
});

test('酉月乙未日坤: six-clash does not erase useful子孙酉 monthly presence and day generation',()=>{
  mockMonth='乙酉';mockDay='乙未';
  const r=cast([8,8,8,8,8,8]);
  expect(r.guaRelations).toMatchObject({original:{kind:'六冲'},outcomeEstablished:false});
  expect(r.lines[5]).toMatchObject({ganZhi:'癸酉',liuQin:'子孙',context:{month:{sameBranch:true},day:{elementRelation:'生爻'}}});
  expect(r.guaRelations.verdict).toBeUndefined();
});

test('all4096 casts: pair coordinates resolve, moving branches use independent pair tables, sources exist',()=>{
  const combinations=new Set(['子丑','丑子','寅亥','亥寅','卯戌','戌卯','辰酉','酉辰','巳申','申巳','午未','未午']);
  const clashes=new Set(['子午','午子','丑未','未丑','寅申','申寅','卯酉','酉卯','辰戌','戌辰','巳亥','亥巳']);
  let moving=0;
  for(let n=0;n<4096;n++) {
    const r=cast(Array.from({length:6},(_,i)=>6+Math.floor(n/(4**i))%4) as CastOptions['lineValues']);
    expect(r.guaRelations).toBeDefined();
    for(const side of ['original','resulting']) {
      const f=r.guaRelations[side];
      expect(f.kind).toBe(combined.includes(resolve(r,f.guaPath).name)?'六合':clashed.includes(resolve(r,f.guaPath).name)?'六冲':'ordinary');
      for(const p of f.pairs) {
        const branches=p.positions.map((position:number)=>f.ganZhi[position-1][1]);
        const pair=branches.join('');expect(p.relation).toBe(combinations.has(pair)?'六合':clashes.has(pair)?'六冲':'neither');
      }
    }
    for(const l of r.lines) {
      if(!l.isChanging) {expect(l.rules.returning).toBeUndefined();continue;}
      moving++;
      const rule=l.rules.returning,pair=l.ganZhi[1]+l.changed.ganZhi[1];
      expect(rule.branchRelation).toBe(combinations.has(pair)?'六合':clashes.has(pair)?'六冲':l.ganZhi[1]===l.changed.ganZhi[1]?'同支':'neither');
      expect(r.ruleSources.some((s:any)=>s.id===rule.branchSourceId)).toBe(true);
      expect(resolve(r,rule.from)).toBe(l.changed);expect(resolve(r,rule.to)).toBe(l);
      expect(r.ruleSources.some((s:any)=>s.id===rule.sourceId)).toBe(true);
    }
    expect(r.ruleSources.some((s:any)=>s.id===r.guaRelations.sourceId)).toBe(true);
    for(const path of r.guaRelations.transition.factPaths) expect(resolve(r,path)).toBeDefined();
  }
  expect(moving).toBe(12288);
});
