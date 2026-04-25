import type { LiuQin, TrigramName, WuXing } from '../types';
import { TRIGRAMS } from './trigrams';
import type { GuaInfo } from '../types';

function relationToMe(myWuXing: WuXing, targetWuXing: WuXing): LiuQin {
  if (myWuXing === targetWuXing) return '兄弟';
  const wo_sheng: Record<WuXing, WuXing> = { 金:'水', 水:'木', 木:'火', 火:'土', 土:'金' };
  if (wo_sheng[myWuXing] === targetWuXing) return '子孙';
  const wo_ke: Record<WuXing, WuXing> = { 金:'木', 木:'土', 土:'水', 水:'火', 火:'金' };
  if (wo_ke[myWuXing] === targetWuXing) return '妻财';
  const sheng_wo: Record<WuXing, WuXing> = { 金:'土', 水:'金', 木:'水', 火:'木', 土:'火' };
  if (sheng_wo[myWuXing] === targetWuXing) return '父母';
  return '官鬼';
}

/**
 * 内卦（下卦）的下 3 爻五行（初/二/三）
 *
 * 来源：六爻纳甲传统规则
 *  - 乾内：子寅辰 → 水木土
 *  - 坤内：未巳卯 → 土火木
 *  - 震内：子寅辰 → 水木土
 *  - 巽内：丑亥酉 → 土水金
 *  - 坎内：寅辰午 → 木土火
 *  - 离内：卯丑亥 → 木土水
 *  - 艮内：辰午申 → 土火金
 *  - 兑内：巳卯丑 → 火木土
 */
const INNER_TRIGRAM_YAO_WUXING: Record<TrigramName, [WuXing, WuXing, WuXing]> = {
  乾: ['水','木','土'],
  坤: ['土','火','木'],
  震: ['水','木','土'],
  巽: ['土','水','金'],
  坎: ['木','土','火'],
  离: ['木','土','水'],
  艮: ['土','火','金'],
  兑: ['火','木','土'],
};

/**
 * 外卦（上卦）的上 3 爻五行（四/五/上）
 *
 *  - 乾外：午申戌 → 火金土
 *  - 坤外：丑亥酉 → 土水金
 *  - 震外：午申戌 → 火金土
 *  - 巽外：未巳卯 → 土火木
 *  - 坎外：申戌子 → 金土水
 *  - 离外：酉未巳 → 金土火
 *  - 艮外：戌子寅 → 土水木
 *  - 兑外：亥酉未 → 水金土
 */
const OUTER_TRIGRAM_YAO_WUXING: Record<TrigramName, [WuXing, WuXing, WuXing]> = {
  乾: ['火','金','土'],
  坤: ['土','水','金'],
  震: ['火','金','土'],
  巽: ['土','火','木'],
  坎: ['金','土','水'],
  离: ['金','土','火'],
  艮: ['土','水','木'],
  兑: ['水','金','土'],
};

/** 给一个 卦，返回 6 爻五行（初爻→上爻） */
export function yaoWuXingForGua(gua: Pick<GuaInfo, 'lower' | 'upper'>): WuXing[] {
  return [
    ...INNER_TRIGRAM_YAO_WUXING[gua.lower],
    ...OUTER_TRIGRAM_YAO_WUXING[gua.upper],
  ];
}

/** 给一个卦，返回 6 爻六亲分配（1=初爻 ... 6=上爻） */
export function liuQinForGua(gua: Pick<GuaInfo, 'palace' | 'lower' | 'upper'>):
  Record<1|2|3|4|5|6, LiuQin>
{
  const palaceWuXing = TRIGRAMS[gua.palace].wuXing;
  const yaoWuXing = yaoWuXingForGua(gua);
  const result: Partial<Record<1|2|3|4|5|6, LiuQin>> = {};
  for (let i = 0; i < 6; i++) {
    result[(i + 1) as 1|2|3|4|5|6] = relationToMe(palaceWuXing, yaoWuXing[i]);
  }
  return result as Record<1|2|3|4|5|6, LiuQin>;
}
