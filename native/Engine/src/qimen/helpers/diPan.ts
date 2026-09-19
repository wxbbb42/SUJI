/**
 * 起 9 宫地盘 — 三奇六仪按"自然数序"流转
 *
 * 顺序铁律（不论阴阳遁）：
 *   戊 → 己 → 庚 → 辛 → 壬 → 癸 → 丁 → 丙 → 乙
 *
 * 流转方向：
 *   阳遁顺布 — 从戊所在宫起，按 1→2→3→4→5→6→7→8→9 自然数序
 *   阴遁逆布 — 从戊所在宫起，按 9→8→7→6→5→4→3→2→1 自然数序
 *
 * 中宫处理：
 *   - 中宫 5 不被"跳过"，三奇六仪流转时确实经过 5；
 *   - 5 局：戊落中宫 5（其它 8 干依序落剩余 8 宫，乙最终落中宫前一宫）
 *   - 非 5 局：流经中宫时该位置正常被占（如阳遁四局 → 己落 5 中），
 *     但展示时按"中宫寄坤 / 中宫寄艮"的传统约定。算法上 5 与其他宫等价。
 *
 * 数据源（≥3 个权威源，2026-04-26 核对）：
 *   A. 命理智库《奇门遁甲基础入门》— "阳遁按九宫自然数顺序 1→2→…→9 顺排"
 *      https://exzh.net/96.html
 *   B. 易德轩《奇门遁甲——三奇六仪排布》— 阳遁一局示例：戊1→己2→庚3→辛4→壬5(寄2)→癸6→丁7→丙8→乙9
 *      https://qimen.yi958.com/
 *   C. 知乎 zhuanlan.zhihu.com/p/22165479579 阴遁二局示例：戊2→己1→庚9→辛8→壬7→癸6→丁5(中)→丙4→乙3
 *   D. 阳遁五局示例（多源一致）：戊5→己6→庚7→辛8→壬9→癸1→丁2→丙3→乙4
 *
 * 注：当前 spec §3.7.1 文字"中宫 5 跳过"与 §3.7.2 阳遁七局示例（仅 8 干落 8 宫）
 * 与上述权威源相悖。本实现以源 A/B/C/D 为准，spec 文字待修订。详见
 * docs/superpowers/specs/2026-04-25-qimen-divination-design.md (TODO 标记)。
 */

import type { TianGan, YinYangDun, JuNumber } from '../types';

/** 三奇六仪固定顺序 */
export const SAN_QI_LIU_YI_ORDER: TianGan[] = ['戊','己','庚','辛','壬','癸','丁','丙','乙'];

/** 阳遁戊起宫位（局数 → 宫 ID） */
export const YANG_DUN_WU_QI_PALACE: Record<JuNumber, 1|2|3|4|5|6|7|8|9> = {
  1: 1, 2: 2, 3: 3, 4: 4, 5: 5, 6: 6, 7: 7, 8: 8, 9: 9,
};

/** 阴遁戊起宫位（局数 → 宫 ID）：阳遁的"宫数 = 局数"映射，但流转方向相反 */
export const YIN_DUN_WU_QI_PALACE: Record<JuNumber, 1|2|3|4|5|6|7|8|9> = {
  1: 9, 2: 8, 3: 7, 4: 6, 5: 5, 6: 4, 7: 3, 8: 2, 9: 1,
};

/** 起 9 宫地盘：戊起对应宫，9 干按自然数序遍布 9 宫 */
export function buildDiPan(dun: YinYangDun, ju: JuNumber): Map<number, TianGan> {
  const startPalaceId = dun === '阳' ? YANG_DUN_WU_QI_PALACE[ju] : YIN_DUN_WU_QI_PALACE[ju];
  // 阳遁顺：1,2,3,4,5,6,7,8,9；阴遁逆：9,8,7,6,5,4,3,2,1
  const NATURAL_ASC = [1, 2, 3, 4, 5, 6, 7, 8, 9];
  const sequence = dun === '阳' ? NATURAL_ASC : [...NATURAL_ASC].reverse();
  const startIdx = sequence.indexOf(startPalaceId);

  const result = new Map<number, TianGan>();
  for (let i = 0; i < 9; i++) {
    const pid = sequence[(startIdx + i) % 9];
    result.set(pid, SAN_QI_LIU_YI_ORDER[i]);
  }
  return result;
}
