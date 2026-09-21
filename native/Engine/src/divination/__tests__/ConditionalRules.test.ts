import { HexagramEngine } from '../HexagramEngine';
import { advanceRetreat } from '../conditionalRules';
import type { CastOptions } from '../types';

let mockDay='戊午',mockMonth='庚申';
jest.mock('@engine/calendar/precision',()=>({getCalendarPillars:()=>({year:'甲子',month:mockMonth,day:mockDay,hour:'甲子'})}));
const cast=(lineValues:CastOptions['lineValues']):any=>new HexagramEngine().cast({question:'传统坐标规则复算，不推断现实结果',lineValues,castTime:new Date('2026-09-20T04:00:00Z')});
beforeEach(()=>{mockDay='戊午';mockMonth='庚申';});

test('申月戊午遯之姤: changed亥 returns control to 午 despite original day presence',()=>{
  const r=cast([8,6,7,7,7,7]);
  expect(r.lines[1].rules.returning).toMatchObject({relation:'回头克',from:'/lines/1/changed',to:'/lines/1',sourceId:'liuyao-changing-relations-v1',assessmentStatus:'structural-relation'});
  expect(r.lines[1].rules.returning.conditions).toEqual(expect.arrayContaining([
    expect.objectContaining({id:'changed-month-generation',state:'matched',factPaths:['/lines/1/changed/context/month/elementRelation']}),
    expect.objectContaining({id:'original-day-presence',state:'matched',factPaths:['/lines/1/context/day/sameBranch']}),
  ]));
  expect(r.lines[0].rules.returning).toBeUndefined();
  expect(r.lines[1].rules.returning.outcome).toBeUndefined();
});

test('all seven selected advance pairs and reverses; unlisted earth wrap is not invented',()=>{
  for(const [a,b] of [['亥','子'],['寅','卯'],['巳','午'],['申','酉'],['丑','辰'],['辰','未'],['未','戌']]) {
    expect(advanceRetreat(a,b)).toBe('进神');expect(advanceRetreat(b,a)).toBe('退神');
  }
  for(const [a,b] of [['戌','丑'],['丑','戌'],['申','申'],['亥','卯'],['子','午']]) expect(advanceRetreat(a,b)).toBe('not-listed');
});

test('恒五申化酉进 retains structural identity when changed酉 is both empty and month-broken',()=>{
  mockDay='甲戌';mockMonth='丁卯';
  const r=cast([8,7,7,7,6,8]);
  expect(r.benGua.name).toBe('雷风恒');expect(r.bianGua.name).toBe('泽风大过');
  expect(r.lines[4].rules.advanceRetreat).toMatchObject({kind:'进神',fromBranch:'申',toBranch:'酉',assessmentStatus:'structural-match',effectiveness:'conditional'});
  expect(r.lines[4].rules.advanceRetreat.conditions).toEqual(expect.arrayContaining([
    expect.objectContaining({id:'changed-void',state:'matched'}),expect.objectContaining({id:'changed-month-break',state:'matched'}),
  ]));
  expect(r.lines[2].rules.advanceRetreat).toBeUndefined();
});

test('flying and hidden direction plus simultaneously supportive and obstructing facts',()=>{
  mockDay='甲申';
  const gou=cast([8,7,7,7,7,7]);
  expect(gou.lines[1].rules.flyingHidden).toMatchObject({relation:'飞生伏',from:'/lines/1',to:'/lines/1/hidden',assessmentStatus:'conditions-only'});
  expect(gou.lines[1].rules.flyingHidden.conditions).toEqual(expect.arrayContaining([
    expect.objectContaining({id:'flying-generates-hidden',state:'matched'}),
    expect.objectContaining({id:'hidden-month-clash',state:'matched'}),expect.objectContaining({id:'hidden-day-control',state:'matched'}),
    expect.objectContaining({id:'hidden-combined-strength',state:'unresolved'}),
  ]));
  const dun=cast([8,8,7,7,7,7]);
  expect(dun.lines[0].rules.flyingHidden).toMatchObject({relation:'飞克伏',from:'/lines/0',to:'/lines/0/hidden'});
  expect(gou.lines[1].rules.flyingHidden.isReleased).toBeUndefined();
});

test('寅月己未坤之师: day support prevents month-only day-break adjudication',()=>{
  mockMonth='丙寅';mockDay='己未';
  const r=cast([8,6,8,8,8,8]);
  expect(r.benGua.name).toBe('坤为地');expect(r.bianGua.name).toBe('地水师');
  const facts=r.lines[3].rules.dayClash;
  // 己未属甲寅旬，子丑空；丑土还须保留冲空分支。
  expect(facts).toMatchObject({kind:'static-day-clash',assessmentStatus:'conditional',candidates:['暗动','日破','冲空待审']});
  expect(facts.conditions).toEqual(expect.arrayContaining([
    expect.objectContaining({id:'day-support',state:'matched'}),
    expect.objectContaining({id:'month-control',state:'matched'}),
    expect.objectContaining({id:'combined-strength',state:'unresolved'}),
  ]));
  expect(facts.movingGenerationPositions).toContain(2);
  expect(facts.verdict).toBeUndefined();
});

test('旺月静酉逢卯冲, weak static and moving counterexamples, and 冲空 remain distinct',()=>{
  mockMonth='庚申';mockDay='癸卯';
  expect(cast([8,7,7,7,6,8]).lines[2].rules.dayClash).toMatchObject({kind:'static-day-clash',candidates:['暗动']});
  mockMonth='丙午';
  expect(cast([8,7,7,7,8,8]).lines[2].rules.dayClash).toMatchObject({kind:'static-day-clash',candidates:['日破']});
  expect(cast([8,7,9,7,8,8]).lines[2].rules.dayClash).toMatchObject({kind:'moving-day-clash',candidates:[]});
  mockMonth='己巳';mockDay='戊戌';
  const r=cast([7,8,8,8,7,7]); // 益，三爻辰土旬空，戌日冲
  expect(r.lines[2].rules.dayClash).toMatchObject({voidClash:true,candidates:expect.arrayContaining(['冲空待审'])});
});

test('every condition fact pointer resolves to the actual chart, including moving actors',()=>{
  for(const values of [[8,6,7,7,7,7],[6,9,9,9,9,9],[8,6,8,8,8,8]] as CastOptions['lineValues'][]) {
    const r=cast(values);
    for(const line of r.lines) for(const rule of Object.values(line.rules) as any[]) {
      if(rule.conditionsFrom) expect(Array.isArray(rule.conditionsFrom.split('/').slice(1).reduce((v:any,k:string)=>v?.[k],r))).toBe(true);
      for(const condition of rule.conditions??[]) {
        expect(['matched','not-matched','unresolved']).toContain(condition.state);
        for(const path of condition.factPaths) expect(path.split('/').slice(1).reduce((v:any,k:string)=>v?.[k],r)).toBeDefined();
      }
    }
  }
});

test('negative moving conditions cite the inspected set, not only the target element',()=>{
  const staticGou=cast([8,7,7,7,7,7]);
  expect(staticGou.lines[1].rules.flyingHidden.conditions).toContainEqual(expect.objectContaining({id:'moving-generates-hidden',state:'not-matched',factPaths:expect.arrayContaining(['/changingYao'])}));
  const movingGou=cast([8,7,7,7,9,7]); // 五爻申金动，对寅木为克而非生
  expect(movingGou.lines[1].rules.flyingHidden.conditions).toContainEqual(expect.objectContaining({id:'moving-generates-hidden',state:'not-matched',factPaths:expect.arrayContaining(['/changingYao','/lines/4/isChanging','/lines/4/wuXing'])}));
});

test('all line-value combinations respect an independently tabulated direction matrix',()=>{
  const elements=['木','火','土','金','水'];
  const matrix=[[0,1,2,4,3],[3,0,1,2,4],[4,3,0,1,2],[2,4,3,0,1],[1,2,4,3,0]];
  const returned=['比和','回头生','回头克','本爻生变','本爻克变'];
  const hidden=['飞伏比和','飞生伏','飞克伏','伏生飞','伏克飞'];
  let returns=0,fly=0;
  for(let n=0;n<4096;n++) {
    const values=Array.from({length:6},(_,i)=>(6+Math.floor(n/(4**i))%4)) as CastOptions['lineValues'];
    const r=cast(values);
    for(const [i,l] of r.lines.entries()) {
      if(l.changed) {
        returns++;
        expect(l.rules.returning.relation).toBe(returned[matrix[elements.indexOf(l.changed.wuXing)][elements.indexOf(l.wuXing)]]);
        expect(l.rules.returning.from).toBe(`/lines/${i}/changed`);expect(l.rules.returning.to).toBe(`/lines/${i}`);
      } else expect(l.rules.returning).toBeUndefined();
      if(l.hidden) {
        fly++;
        expect(l.rules.flyingHidden.relation).toBe(hidden[matrix[elements.indexOf(l.wuXing)][elements.indexOf(l.hidden.wuXing)]]);
      }
    }
  }
  expect(returns).toBe(12288);expect(fly).toBe(3584);
});
