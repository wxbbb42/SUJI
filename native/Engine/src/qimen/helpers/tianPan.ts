/** 转盘奇门；中五固定寄坤二，星干外圈相对顺序不因阴遁翻转。
 * 《烟波钓叟歌》“值符常遣加时干”；qfdk/qimen、qimen-go 固定坤二
 * 模式交叉核对。派别与复现证据见 docs/mingli/validation/divination-research.md。
 */
import type { TianGan, JiuxingName, YinYangDun } from '../types';
import { JIUXING_DI_PAN_FIXED } from '../data/jiuxing';
export const PALACE_CLOCKWISE_8 = [1,8,3,4,9,2,7,6];
export const jiPalace = (palace:number):number => palace===5 ? 2 : palace;

export function computeXunShou(hourGan:TianGan,hourZhi:string):TianGan {
  const stems=[...'甲乙丙丁戊己庚辛壬癸'],branches=[...'子丑寅卯辰巳午未申酉戌亥'];
  const index=Array.from({length:60},(_,i)=>stems[i%10]+branches[i%12]).indexOf(hourGan+hourZhi);
  if(index<0) throw new Error('invalid hour pillar');
  return (['戊','己','庚','辛','壬','癸'] as TianGan[])[Math.floor(index/10)];
}

export function rotateTianPan(diPan:Map<number,TianGan>,xunShou:TianGan,hourGan:TianGan,_dun:YinYangDun):{
  tianPan:Map<number,TianGan>; tianJiuxing:Map<number,JiuxingName>; zhiFuPalaceId:number; zhiFuStar:JiuxingName;
  zhiFuSourcePalaceId:number; tianQinPalaceId:number; hostedTianPanGan:TianGan;
} {
  const find=(g:TianGan):number=>{
    const p=[...diPan].find(([,v])=>v===g)?.[0];
    if(!p) throw new Error(`stem ${g} not found in earth plate`);
    return p;
  };
  const source=find(xunShou),from=jiPalace(source);
  // 甲隐于当前旬首仪下；不能把“地盘没有甲”当作中五宫。
  const to=jiPalace(find(hourGan==='甲'?xunShou:hourGan));
  const offset=(PALACE_CLOCKWISE_8.indexOf(to)-PALACE_CLOCKWISE_8.indexOf(from)+8)%8;
  const tianPan=new Map<number,TianGan>(),tianJiuxing=new Map<number,JiuxingName>();
  PALACE_CLOCKWISE_8.forEach((p,i)=>{
    const dest=PALACE_CLOCKWISE_8[(i+offset)%8];
    tianPan.set(dest,diPan.get(p)!);tianJiuxing.set(dest,JIUXING_DI_PAN_FIXED[p]);
  });
  // 保留中宫原干作底盘查阅；实际随禽芮携带的寄干另有结构化字段。
  const middle=diPan.get(5)!;
  tianPan.set(5,middle);tianJiuxing.set(5,'天禽');
  const tianQinPalaceId=PALACE_CLOCKWISE_8[(PALACE_CLOCKWISE_8.indexOf(2)+offset)%8];
  return {tianPan,tianJiuxing,zhiFuPalaceId:to,zhiFuStar:JIUXING_DI_PAN_FIXED[source],zhiFuSourcePalaceId:source,tianQinPalaceId,hostedTianPanGan:middle};
}
