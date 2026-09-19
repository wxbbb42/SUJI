import {HexagramEngine} from '../HexagramEngine';
import {GUA_64} from '../data/gua64';
import type {CastOptions} from '../types';
const engine=new HexagramEngine();
const castTime=new Date('2026-04-15T12:00:00+08:00');

describe('HexagramEngine cast',()=>{
  it('returns the complete reading shape',()=>{
    const r=engine.cast({question:'我会得到这个 offer 吗',questionType:'career',castTime,lineValues:[7,7,7,7,7,7]});
    expect(r.benGua.yao).toHaveLength(6);expect(r.bianGua.yao).toHaveLength(6);
    expect(Object.keys(r.liuQin)).toHaveLength(6);expect(r.lines).toHaveLength(6);
  });
  it('unchanging coin values retain the primary gua',()=>{
    const r=engine.cast({question:'test',castTime,lineValues:[7,8,7,8,7,8]});
    expect(r.changingYao).toEqual([]);expect(r.bianGua).toEqual(r.benGua);
  });
  it('only old yin and old yang change',()=>{
    const r=engine.cast({question:'test',castTime,lineValues:[6,7,8,9,7,8]});
    expect(r.changingYao).toEqual([1,4]);expect(r.bianGua.yao).toEqual(['阳','阳','阴','阴','阳','阴']);
  });
  it('preserves fixed cast time',()=>{
    expect(engine.cast({question:'test',castTime}).castTime).toBe(castTime.toISOString());
  });
  it('career selects only matching candidates across all 64 gua',()=>{
    for(const gua of GUA_64){
      const lineValues=gua.yao.map(v=>v==='阳'?7:8) as CastOptions['lineValues'];
      const r=engine.cast({question:'test',questionType:'career',castTime,lineValues});
      expect(r.yongShen.type).toBe('官鬼');
      for(const index of r.yongShen.candidateYaoIndices??[])expect(r.liuQin[index as 1|2|3|4|5|6]).toBe('官鬼');
    }
  });
  it('辰月 fire is resting in the month-element relation, not April-as-巳 fire 旺',()=>{
    const r=engine.cast({question:'事业走势如何',questionType:'career',castTime,lineValues:[7,7,7,7,7,7]});
    expect(r.benGua.name).toBe('乾为天');expect(r.yongShen.type).toBe('官鬼');expect(r.yongShen.yaoIndex).toBe(4);
    expect(r.yongShen.wuXing).toBe('火');expect(r.yongShen.state).toBe('休');
    expect(r.yongShen.interactions).toContain('月建壬辰五行关系：休（非综合旺衰）');
  });
});
