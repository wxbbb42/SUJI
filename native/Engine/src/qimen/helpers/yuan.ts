import type { Yuan } from '../types';

/** 拆补法：回推最近的甲/己符头，五日一元，按符头地支定元。
 * 《烟波钓叟歌》“五日都来接一元”；实现交叉核对 qfdk/qimen 与
 * deminzhang/qimen-go。详见 docs/mingli/validation/divination-research.md。
 * 甲子/己卯/甲午/己酉上；甲寅/己巳/甲申/己亥中；余四符头下。
 * 交节只切换节气局表，不将每个节气首日重新设为上元。
 */
export function computeYuanFromDay(dayGanZhi: string): { yuan: Yuan; fuTou: string } {
  const stems=[...'甲乙丙丁戊己庚辛壬癸'],branches=[...'子丑寅卯辰巳午未申酉戌亥'];
  const index=Array.from({length:60},(_,i)=>stems[i%10]+branches[i%12]).indexOf(dayGanZhi);
  if(index<0) throw new Error('invalid day pillar');
  const head=index-index%5,fuTou=stems[head%10]+branches[head%12];
  return {fuTou,yuan:'子午卯酉'.includes(fuTou[1])?'上':'寅申巳亥'.includes(fuTou[1])?'中':'下'};
}
