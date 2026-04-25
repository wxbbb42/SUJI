import type { LiuQin, TrigramName, WuXing } from '../types';
import { TRIGRAMS } from './trigrams';

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

/** MVP 简化纳甲：每宫的 6 爻五行（初爻→上爻） */
export const PALACE_YAO_WUXING: Record<TrigramName, WuXing[]> = {
  乾: ['水','木','土','土','金','金'],
  兑: ['火','火','土','金','金','金'],
  离: ['木','木','水','金','土','土'],
  震: ['水','木','土','金','水','土'],
  巽: ['木','木','火','金','水','水'],
  坎: ['火','土','土','金','水','水'],
  艮: ['火','水','土','土','土','土'],
  坤: ['火','土','土','土','水','水'],
};

export function liuQinForGua(gua: { palace: TrigramName }): Record<1|2|3|4|5|6, LiuQin> {
  const palaceWuXing = TRIGRAMS[gua.palace].wuXing;
  const yaoWuXing = PALACE_YAO_WUXING[gua.palace];
  const result: Partial<Record<1|2|3|4|5|6, LiuQin>> = {};
  for (let i = 0; i < 6; i++) {
    result[(i + 1) as 1|2|3|4|5|6] = relationToMe(palaceWuXing, yaoWuXing[i]);
  }
  return result as Record<1|2|3|4|5|6, LiuQin>;
}
