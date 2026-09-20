import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { HexagramEngine } from '../HexagramEngine';
import { GUA_64 } from '../data/gua64';
import type { CastOptions } from '../types';
const oracle=JSON.parse(readFileSync(resolve(__dirname,'../../../validation/research-divination/independent-results.json'),'utf8')).najia as {binary:string;name:string;shi:number;ying:number;palace:string;ganzhi:string[];liuqin:string[]}[];
const engine=new HexagramEngine(),castTime=new Date('2026-09-19T10:00:00+08:00');

describe('independent bopo/najia oracle; 64 Jingfang gua',()=>{
  for(const f of oracle) it(`${f.name} palace, shi/ying, six najia and relationships`,()=>{
    const lineValues=f.binary.split('').map(v=>v==='1'?7:8) as CastOptions['lineValues'];
    const r=engine.cast({question:'oracle',castTime,lineValues});
    expect(r.benGua.palace).toBe(f.palace);expect(r.shiYao).toBe(f.shi);expect(r.yingYao).toBe(f.ying);
    expect(r.lines.map(l=>l.ganZhi)).toEqual(f.ganzhi);expect(r.lines.map(l=>l.liuQin)).toEqual(f.liuqin);
  });
});

describe('calendar, casting identity and missing evidence',()=>{
  it('exact month and actual hour, independent lunar-javascript baseline',()=>{
    const r=engine.cast({question:'test',castTime,lineValues:[7,7,7,7,7,7]});
    expect(r.castGanZhi).toEqual({day:'丙申',month:'丁酉',hour:'癸巳'});
    expect(r.xunKong).toEqual(['辰','巳']);
    expect(r.lines.map(l=>l.liuShen)).toEqual(['朱雀','勾陈','腾蛇','白虎','玄武','青龙']);
  });
  it('retains all 4096 line states and flips only 6 or 9',()=>{
    for(let mask=0;mask<4096;mask++){
      const v=Array.from({length:6},(_,i)=>6+(mask>>2*i&3)) as NonNullable<CastOptions['lineValues']>;
      const r=engine.cast({question:'replay',castTime,lineValues:v});
      expect(r.lineValues).toEqual(v);
      expect(r.changingYao).toEqual(v.flatMap((n,i)=>[6,9].includes(n)?[i+1]:[]));
      expect(r.bianGua.yao).toEqual(v.map(n=>n===6||n===7?'阳':'阴'));
    }
  });
  it('uses the original palace element for changing-line kinship',()=>{
    const r=engine.cast({question:'test',castTime,lineValues:[9,7,7,7,7,7]});
    expect(r.benGua.name).toBe('乾为天');expect(r.bianGua.name).toBe('天风姤');
    expect(r.lines[0].changed).toMatchObject({ganZhi:'辛丑',wuXing:'土',liuQin:'父母'});
  });
  it('stores hidden absent relationships under their pure-palace positions',()=>{
    const r=engine.cast({question:'test',castTime,lineValues:[8,7,7,7,7,7]});
    expect(r.benGua.name).toBe('天风姤');
    expect(r.lines[1].hidden).toMatchObject({ganZhi:'甲寅',wuXing:'木',liuQin:'妻财'});
  });
  it('correctly labels standard King Wen numbers without reordering palace families',()=>{
    expect(GUA_64.find(g=>g.name==='坤为地')?.code).toBe(2);
    expect(GUA_64.find(g=>g.name==='天风姤')?.code).toBe(44);
    expect(new Set(GUA_64.map(g=>g.code)).size).toBe(64);
  });
  it('keeps evidence uncertainty rather than fabricated weeks',()=>{
    const r=engine.cast({question:'test',castTime,lineValues:[7,7,7,7,7,7]});
    expect(r.yingQi.description).toMatch(/未推定/);expect(r.yingQi.description).not.toMatch(/1-2/);
    expect(r.yongShen.candidates).toEqual([]);expect(r.yongShen.querentReference).toBe('/lines/5');
  });
  it('rejects malformed coin input instead of recasting it',()=>{
    expect(()=>engine.cast({question:'x',castTime,lineValues:[6]})).toThrow(/six/);
  });
});
