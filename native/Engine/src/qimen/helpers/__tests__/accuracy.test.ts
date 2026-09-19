import {readFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {buildDiPan} from '../diPan';
import {rotateBamen} from '../bamen';
import {rotateTianPan,computeXunShou} from '../tianPan';
import {computeYuanFromDay} from '../yuan';
import {QimenEngine} from '../../QimenEngine';
import type {YinYangDun,JuNumber,TianGan} from '../../types';
const oracle=JSON.parse(readFileSync(resolve(__dirname,'../../../../validation/research-divination/qimen-results.json'),'utf8')).fixtures as {dun:YinYangDun;ju:JuNumber;xun:TianGan;hour:string;expected:Record<string,string>;zhiShiMen:string;zhiShiPalaceId:number;zhiShiRawPalaceId:number}[];

describe('source-grounded chai-bu and zhishi regressions',()=>{
  for(const f of oracle)it(`${f.dun}${f.ju}局 ${f.hour} complete door fixture`,()=>{
    const r=rotateBamen(buildDiPan(f.dun,f.ju),f.xun,f.hour[0] as TianGan,f.dun);
    expect(Object.fromEntries(r.bamen)).toEqual(f.expected);
    expect(r.zhiShiMen).toBe(f.zhiShiMen);expect(r.zhiShiPalaceId).toBe(f.zhiShiPalaceId);expect(r.zhiShiRawPalaceId).toBe(f.zhiShiRawPalaceId);
  });
  it.each(['阳','阴'] as const)('%s五局中心符头先计时再寄宫',dun=>{
    const r=rotateBamen(buildDiPan(dun,5),'戊','乙',dun);
    expect(r.zhiShiSourcePalaceId).toBe(5);expect(r.zhiShiMen).toBe('死门');
    expect(r.zhiShiRawPalaceId).toBe(dun==='阳'?6:4);expect(r.zhiShiPalaceId).toBe(dun==='阳'?6:4);
  });
  it('all 60 days match independent qimen-go sexagenary three-yuan formula',()=>{
    const stems=[...'甲乙丙丁戊己庚辛壬癸'],branches=[...'子丑寅卯辰巳午未申酉戌亥'];
    for(let n=0;n<60;n++)expect(computeYuanFromDay(stems[n%10]+branches[n%12]).yuan).toBe(['上','中','下'][Math.floor(n%15/5)]);
    expect(computeYuanFromDay('甲戌')).toEqual({yuan:'下',fuTou:'甲戌'});
    expect(computeYuanFromDay('戊寅')).toEqual({yuan:'下',fuTou:'甲戌'});
  });
  it('all 108 Jia-hour plates are fuyin, with Qin carried by its host',()=>{
    for(const dun of ['阳','阴'] as const)for(let ju=1;ju<=9;ju++)for(const xun of [...'戊己庚辛壬癸'] as TianGan[]){
      const dp=buildDiPan(dun,ju as JuNumber),r=rotateTianPan(dp,xun,'甲',dun);
      expect(Object.fromEntries(r.tianPan)).toEqual(Object.fromEntries(dp));expect(r.tianQinPalaceId).toBe(2);
      expect(r.hostedTianPanGan).toBe(dp.get(5));
    }
  });
  it('rejects invalid sexagenary pairs, instead of silently selecting 甲子',()=>{
    expect(()=>computeXunShou('甲','丑')).toThrow();expect(()=>computeYuanFromDay('甲丑')).toThrow();
  });
  it('all Yin and Yang earth plates place 戊 at the stated ju',()=>{
    for(const dun of ['阳','阴'] as const)for(let ju=1;ju<=9;ju++)expect(buildDiPan(dun,ju as JuNumber).get(ju)).toBe('戊');
  });
  it('same physical instant has the same term at all longitudes',()=>{
    const e=new QimenEngine();
    for(const longitude of [87.6,116.4,135]){
      const r=e.setup({question:'test',questionType:'general',setupTime:new Date('2026-02-04T04:42:08+08:00'),longitude});
      expect(r.jieqi).toBe('立春');expect(r.method.algorithm).toBe('zhuanpan-qimen-chai-bu-v1');
      expect(r.yingQi.description).toContain('尚不能确定');expect(r.zhiShiMen).toBeTruthy();
    }
  });
});
