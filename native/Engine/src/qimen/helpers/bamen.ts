import type { BamenName, YinYangDun, TianGan } from '../types';
import { PALACE_CLOCKWISE_8, jiPalace } from './tianPan';

export const FIXED_DOORS: Readonly<Record<number,BamenName>> = {1:'休门',8:'生门',3:'伤门',4:'杜门',9:'景门',2:'死门',7:'惊门',6:'开门'};

/** 值使由旬首原宫的门取得；按旬内时数沿九宫阳顺阴逆计数。
 * 最终八门在外圈整体旋转，相邻顺序不随阴阳遁翻转。
 * 中五固定寄坤二；原始宫数保留到计时结束，不从寄宫提前起算。
 * 来源与派别选择见 docs/mingli/validation/divination-research.md。
 */
export function rotateBamen(diPan: Map<number,TianGan>, xunShou:TianGan, hourGan:TianGan, dun:YinYangDun): {
  bamen:Map<number,BamenName>; zhiShiMen:BamenName; zhiShiSourcePalaceId:number; zhiShiPalaceId:number; zhiShiRawPalaceId:number;
} {
  const source=[...diPan].find(([,g])=>g===xunShou)?.[0];
  if(!source) throw new Error('xunshou not found in earth plate');
  const step=[...'甲乙丙丁戊己庚辛壬癸'].indexOf(hourGan);
  if(step<0) throw new Error('invalid hour stem');
  const raw=((source-1+(dun==='阳'?step:-step))%9+9)%9+1;
  const from=jiPalace(source),to=jiPalace(raw);
  const zhiShiMen=FIXED_DOORS[from];
  const offset=(PALACE_CLOCKWISE_8.indexOf(to)-PALACE_CLOCKWISE_8.indexOf(from)+8)%8;
  const bamen=new Map<number,BamenName>();
  PALACE_CLOCKWISE_8.forEach((p,i)=>bamen.set(PALACE_CLOCKWISE_8[(i+offset)%8],FIXED_DOORS[p]));
  return {bamen,zhiShiMen,zhiShiSourcePalaceId:source,zhiShiPalaceId:to,zhiShiRawPalaceId:raw};
}
