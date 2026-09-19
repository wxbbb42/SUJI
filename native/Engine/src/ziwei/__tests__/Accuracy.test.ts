import {readFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {astro} from 'iztro';
import {ZiweiEngine} from '../ZiweiEngine';
const engine=new ZiweiEngine();
const fixtures=JSON.parse(readFileSync(resolve(__dirname,'../../../validation/research-divination/independent-results.json'),'utf8')).ziwei.ordinaryMonthFixtures as {date:string;h:number;expected:Record<string,string[]>}[];

describe('independent ZiWeiDouShu 2020 table-based oracle (not iztro)',()=>{
  for(const f of fixtures)it(`${f.date}, double-hour ${f.h}, 14 major stars`,()=>{
    const [year,month,day]=f.date.split('-').map(Number);
    const p=engine.compute({year,month,day,hour:f.h*2,gender:'男'});
    expect(Object.fromEntries(p.palaces.map(p=>[p.position,p.mainStars.map(s=>s.name).sort()]))).toEqual(f.expected);
  });
});

describe('date, conventions, and normalized four transformations',()=>{
  it('late Zi forwards the lunar day; birth instant remains the original civil instant',()=>{
    const p=engine.compute({year:1990,month:8,day:15,hour:23,gender:'男'});
    expect(p.palaces.find(p=>p.mainStars.some(s=>s.name==='紫微'))?.position).toBe('酉');
    expect(p.birthDateTime.toISOString()).toBe('1990-08-15T15:00:00.000Z');
    const next=engine.compute({year:1990,month:8,day:16,hour:0,gender:'男'});
    expect(p.palaces).toEqual(next.palaces);
  });
  it('lunar leap birth identity is Gregorian, with invalid leap months rejected',()=>{
    const p=engine.compute({year:2023,month:2,day:1,hour:10,gender:'女',isLunar:true,isLeapMonth:true});
    expect(p.birthDateTime.toISOString()).toBe('2023-03-22T02:00:00.000Z');
    expect(()=>engine.compute({year:2024,month:2,day:1,hour:10,gender:'女',isLunar:true,isLeapMonth:true})).toThrow();
  });
  it('all 144 ordinary-month ming/shen positions follow Quanshu volume 2 counting rule',()=>{
    const branches=[...'子丑寅卯辰巳午未申酉戌亥'];
    for(let month=1;month<=12;month++)for(let hour=0;hour<12;hour++){
      const p=engine.compute({year:2024,month,day:10,hour:hour*2,gender:'男',isLunar:true});
      expect(p.mingGongPosition).toBe(branches[(2+month-1-hour+12)%12]);
      expect(p.shenGongPosition).toBe(branches[(2+month-1+hour)%12]);
    }
  });
  it('all ten stem tables agree with Quanshu 四化口诀; output always has 化 prefix',()=>{
    const expected=[
      ['廉贞','破军','武曲','太阳'],['天机','天梁','紫微','太阴'],['天同','天机','文昌','廉贞'],
      ['太阴','天同','天机','巨门'],['贪狼','太阴','右弼','天机'],['武曲','贪狼','天梁','文曲'],
      ['太阳','武曲','太阴','天同'],['巨门','太阳','文曲','文昌'],['天梁','紫微','左辅','武曲'],['破军','巨门','太阴','贪狼'],
    ];
    for(let i=0;i<10;i++){
      const p=engine.compute({year:1984+i,month:8,day:15,hour:12,gender:'男'});
      const stars=p.palaces.flatMap(p=>[...p.mainStars,...p.minorStars]);
      expect(['化禄','化权','化科','化忌'].map(label=>stars.find(s=>s.sihua?.includes(label as '化禄'))?.name)).toEqual(expected[i]);
    }
  });
  it('engine policy cannot be silently changed by another iztro consumer',()=>{
    astro.config({dayDivide:'current',yearDivide:'exact',mutagens:{甲:['紫微','紫微','紫微','紫微']}});
    const p=engine.compute({year:1984,month:8,day:15,hour:23,gender:'男'});
    expect(p.palaces.flatMap(p=>[...p.mainStars,...p.minorStars]).find(s=>s.sihua?.includes('化禄'))?.name).toBe('廉贞');
    expect(p.method?.dayBoundary).toBe('zi-hour');
  });
});
