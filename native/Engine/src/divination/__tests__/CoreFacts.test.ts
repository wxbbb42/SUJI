import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { HexagramEngine } from '../HexagramEngine';
import type { CastOptions } from '../types';

// Traditional coordinates isolate line rules from the independently audited calendar.
let mockDay = '甲子', mockMonth = '庚申';
jest.mock('@engine/calendar/precision', () => ({
  getCalendarPillars: () => ({ year:'甲子', month:mockMonth, day:mockDay, hour:'甲子' }),
}));
const cast = (lineValues: CastOptions['lineValues']): any => new HexagramEngine().cast({
  question:'规则复核', lineValues, castTime:new Date('2026-09-19T04:00:00Z'),
});
beforeEach(() => { mockDay='甲子'; mockMonth='庚申'; });

test('original and transformed lines have different void status in 甲子日遯之姤', () => {
  const r=cast([8,6,7,7,7,7]);
  expect(r.lines[1]).toMatchObject({ganZhi:'丙午',context:{isVoid:false},changed:{ganZhi:'辛亥',context:{isVoid:true}}});
});

test('changed 丑 is month-broken in 未月, original 子 is not', () => {
  mockMonth='己未';
  const r=cast([9,7,7,7,7,7]);
  expect(r.lines[0]).toMatchObject({context:{month:{clash:false}},changed:{ganZhi:'辛丑',context:{month:{clash:true}}}});
});

test('hidden 寅 under flying 亥 has its own month and day clash', () => {
  mockDay='甲申';
  expect(cast([8,7,7,7,7,7]).lines[1]).toMatchObject({
    ganZhi:'辛亥',context:{month:{clash:false},day:{clash:false}},
    hidden:{ganZhi:'甲寅',context:{month:{clash:true,elementRelation:'克爻'},day:{clash:true,elementRelation:'克爻'}}},
  });
});

test('a month combination and a controlling month are separate facts, not a verdict', () => {
  mockMonth='乙丑';
  const r=cast([8,7,8,8,7,8]);
  expect(r.lines[5].context).toMatchObject({
    monthState:'死',month:{ganZhi:'乙丑',combination:true,elementRelation:'克爻'},day:{sameBranch:true,elementRelation:'同类'},
  });
  expect(r.lineContextPolicy).toMatchObject({assessmentStatus:'calendar-relations-only',sourceIds:['liuyao-calendar-relations-v1']});
});

test('the classical 申月戊午日 example retains day presence and month-generation of the changed line', () => {
  mockDay='戊午';
  const r=cast([8,6,7,7,7,7]);
  expect(r.lines[1]).toMatchObject({
    context:{day:{sameBranch:true},monthState:'囚'},
    changed:{context:{month:{elementRelation:'生爻'},day:{elementRelation:'爻克'}}},
  });
  expect(r.ruleSources).toEqual(expect.arrayContaining([expect.objectContaining({id:'liuyao-calendar-relations-v1',editionStatus:'electronic-transcription-not-print-collated'})]));
});

test('all original/changed/hidden contexts agree with independent pair and five-element tables', () => {
  const oracles: {binary:string}[]=JSON.parse(readFileSync(resolve(__dirname,'../../../validation/research-divination/independent-results.json'),'utf8')).najia;
  const branches=[...'子丑寅卯辰巳午未申酉戌亥'];
  const stems=[...'甲乙丙丁戊己庚辛壬癸'];
  const wx:Record<string,string>={子:'水',丑:'土',寅:'木',卯:'木',辰:'土',巳:'火',午:'火',未:'土',申:'金',酉:'金',戌:'土',亥:'水'};
  // Rows calendar element, columns target 木火土金水; independently hand-tabulated.
  const relations:Record<string,string[]>={
    木:['同类','生爻','克爻','爻克','爻生'],火:['爻生','同类','生爻','克爻','爻克'],
    土:['爻克','爻生','同类','生爻','克爻'],金:['克爻','爻克','爻生','同类','生爻'],水:['生爻','克爻','爻克','爻生','同类'],
  };
  const clashes=['子午','丑未','寅申','卯酉','辰戌','巳亥'], combines=['子丑','寅亥','卯戌','辰酉','巳申','午未'];
  const pair=(a:string,b:string,table:string[])=>a!==b&&table.some(p=>p.includes(a)&&p.includes(b));
  const failures:string[]=[];
  for(let m=0;m<12;m++) for(let d=0;d<12;d++) {
    mockMonth=stems[m%10]+branches[m]; mockDay=stems[d%10]+branches[d];
    for(const oracle of oracles) {
      const r=cast([...oracle.binary].map(b=>b==='1'?9:6));
      for(const line of r.lines) for(const obj of [line,line.changed,line.hidden].filter(Boolean)) {
        for(const [scope,b] of [['month',branches[m]],['day',branches[d]]]) {
          const c=obj.context?.[scope],target=obj.ganZhi[1];
          if(!c||c.clash!==pair(target,b,clashes)||c.combination!==pair(target,b,combines)||c.sameBranch!==(target===b)
            ||c.elementRelation!==relations[wx[b]][[...'木火土金水'].indexOf(wx[target])]) failures.push(`${mockMonth}/${mockDay}/${oracle.binary}/${obj.ganZhi}/${scope}`);
        }
      }
    }
  }
  expect(failures.slice(0,10)).toEqual([]);
  expect(failures).toHaveLength(0);
});

test('all six xun apply independently to original/changed/hidden objects', () => {
  const branches=[...'子丑寅卯辰巳午未申酉戌亥'],stems=[...'甲乙丙丁戊己庚辛壬癸'];
  const voids=['戌亥','申酉','午未','辰巳','寅卯','子丑'];
  for(let day=0;day<60;day++) {
    mockDay=stems[day%10]+branches[day%12];
    const r=cast([8,6,7,7,7,7]);
    for(const line of r.lines) for(const obj of [line,line.changed,line.hidden].filter(Boolean))
      expect(obj.context?.isVoid).toBe(voids[Math.floor(day/10)].includes(obj.ganZhi[1]));
  }
});
