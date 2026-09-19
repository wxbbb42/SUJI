/**
 * 旋天盘 — 转盘奇门核心规则
 *
 * 数据源（2026-04-26 核对）：
 *   A. 新浪 k.sina.cn《奇门盘中九星盘的排法》— "值符是指旬首所落宫位的固定盘九星"
 *      https://k.sina.cn/article_6936019392_19d6b41c000100ronp.html
 *   B. 简书 jianshu.com/p/f37f3ebf3a34 《奇门遁甲排盘方法》—
 *      "将值符落在时干所在之宫位。其余的星按顺时针方向旋转排列。"
 *   C. 太白童子博客 blog.sina.com.cn/.../blog_af85ff5f0102yij0.html —
 *      "把其他八星及其原宫位上的三奇六仪带过去顺时针落宫"
 *   D. 易先生《奇门预测如何起局》yixiansheng.com/article/1630.html —
 *      "值符随时干转动，将其它八星按九星顺序顺时针排列"
 *
 * 多源共识：
 *   1. 值符星 = 旬首仪 在地盘所落宫的"原始九星"
 *   2. 直符宫 = 时干在地盘所落宫
 *   3. 旋转：值符星从其原宫（= 旬首在地盘的宫）旋至直符宫，
 *      其余 8 颗九星按"原始顺时针相对位置"跟随旋转，
 *      天盘干与天盘九星绑定，一起旋转。
 *   4. 中 5 宫不参与外圈旋转（其内容寄于坤 2 / 艮 8 由展示层处理）。
 *
 * 旋转方向约定：
 *   不论阴/阳遁，九星本身按"九星序" (蓬-任-冲-辅-英-芮-柱-心) 顺时针排列；
 *   通过对九星序在 8 外宫的相对位置整体平移实现。
 */

import type { TianGan, JiuxingName, YinYangDun } from '../types';
import { JIUXING_DI_PAN_FIXED } from '../data/jiuxing';

/** 后天八卦顺时针 8 外宫序：坎1 → 艮8 → 震3 → 巽4 → 离9 → 坤2 → 兑7 → 乾6 */
export const PALACE_CLOCKWISE_8: number[] = [1, 8, 3, 4, 9, 2, 7, 6];

/**
 * 寄宫规则：中宫 5 不参与外圈，需"寄"到一个具体的外宫
 *  - 阳遁：中宫寄坤 2
 *  - 阴遁：中宫寄艮 8
 * 来源：spec §3.7.2 表 + 命理智库 exzh.net/96.html《中五宫寄宫规则》
 */
function jiPalace(palaceId: number, dun: YinYangDun): number {
  if (palaceId !== 5) return palaceId;
  return dun === '阳' ? 2 : 8;
}

/**
 * 60 甲子六旬 → 旬首仪
 *
 * 甲子旬（甲子 ~ 癸酉）→ 旬首戊
 * 甲戌旬（甲戌 ~ 癸未）→ 旬首己
 * 甲申旬（甲申 ~ 癸巳）→ 旬首庚
 * 甲午旬（甲午 ~ 癸卯）→ 旬首辛
 * 甲辰旬（甲辰 ~ 癸丑）→ 旬首壬
 * 甲寅旬（甲寅 ~ 癸亥）→ 旬首癸
 *
 * @param hourGan 时柱天干
 * @param hourZhi 时柱地支
 */
export function computeXunShou(hourGan: TianGan, hourZhi: string): TianGan {
  const TIANGAN = ['甲','乙','丙','丁','戊','己','庚','辛','壬','癸'];
  const DIZHI = ['子','丑','寅','卯','辰','巳','午','未','申','酉','戌','亥'];
  const ganIdx = TIANGAN.indexOf(hourGan);
  const zhiIdx = DIZHI.indexOf(hourZhi);
  if (ganIdx < 0 || zhiIdx < 0) return '戊'; // fallback：默认甲子旬

  // 由 (gan, zhi) 反推 60 甲子序号 sb
  // sb ≡ ganIdx (mod 10)，sb ≡ zhiIdx (mod 12)，sb ∈ [0, 60)
  const k = (((ganIdx - zhiIdx) / 2) % 6 + 6) % 6;
  const sb = ganIdx + 10 * k;             // 0..59
  const xunIndex = Math.floor(sb / 10);   // 0=甲子 … 5=甲寅
  // 旬首仪映射：旬 0/1/2/3/4/5 → 戊/己/庚/辛/壬/癸
  const XUN_SHOU: TianGan[] = ['戊', '己', '庚', '辛', '壬', '癸'];
  return XUN_SHOU[xunIndex];
}

/**
 * 旋天盘
 *
 * @param diPan       地盘干（宫 ID → 干）
 * @param xunShou     当前时辰旬首仪
 * @param hourGan     当前时辰时干（决定直符宫）
 * @returns
 *   - tianPan：天盘干（宫 ID → 干）
 *   - tianJiuxing：天盘九星（宫 ID → 星）
 *   - zhiFuPalaceId：直符宫（时干所在地盘宫）
 *   - zhiFuStar：值符星（旬首在地盘所落宫的原始九星）
 */
export function rotateTianPan(
  diPan: Map<number, TianGan>,
  xunShou: TianGan,
  hourGan: TianGan,
  dun: YinYangDun,
): {
  tianPan: Map<number, TianGan>;
  tianJiuxing: Map<number, JiuxingName>;
  zhiFuPalaceId: number;
  zhiFuStar: JiuxingName;
} {
  // 1. 找旬首仪在地盘的宫 = 值符星原宫（中宫寄宫处理）
  const xunShouPalaceRaw = findGanPalace(diPan, xunShou);
  const xunShouPalace = jiPalace(xunShouPalaceRaw, dun);
  // 2. 找时干在地盘的宫 = 直符宫（中宫寄宫处理）
  const hourGanPalaceRaw = findGanPalace(diPan, hourGan);
  const hourGanPalace = jiPalace(hourGanPalaceRaw, dun);
  // 3. 值符星 = 旬首原宫（含中 5 寄宫前的原始位）的固定地盘九星
  //    中 5 的固定九星 = 天禽，但实际旋转中 天禽 跟随 寄宫 的星走
  //    我们用"寄宫后"的星（坤 2 = 天芮 或 艮 8 = 天任）作为值符星，
  //    与多数转盘奇门排盘工具行为一致
  const zhiFuStar = JIUXING_DI_PAN_FIXED[xunShouPalace];

  const fromIdx = PALACE_CLOCKWISE_8.indexOf(xunShouPalace);
  const toIdx = PALACE_CLOCKWISE_8.indexOf(hourGanPalace);
  const offset = ((toIdx - fromIdx) % 8 + 8) % 8;

  const tianPan = new Map<number, TianGan>();
  const tianJiuxing = new Map<number, JiuxingName>();

  // 8 外宫平移：原宫 i 的天盘干（= 地盘干）和九星，落到第 (i+offset) 宫
  for (let i = 0; i < 8; i++) {
    const fromPid = PALACE_CLOCKWISE_8[i];
    const toPid = PALACE_CLOCKWISE_8[(i + offset) % 8];
    const ganAtFrom = diPan.get(fromPid);
    if (ganAtFrom) tianPan.set(toPid, ganAtFrom);
    tianJiuxing.set(toPid, JIUXING_DI_PAN_FIXED[fromPid]);
  }

  // 中 5 宫天盘 = 地盘（中宫不参与外圈旋转）
  const middle = diPan.get(5);
  if (middle) tianPan.set(5, middle);
  tianJiuxing.set(5, JIUXING_DI_PAN_FIXED[5]); // 天禽

  return {
    tianPan,
    tianJiuxing,
    zhiFuPalaceId: hourGanPalace,
    zhiFuStar,
  };
}

function findGanPalace(diPan: Map<number, TianGan>, gan: TianGan): number {
  for (const [pid, g] of diPan) {
    if (g === gan) return pid;
  }
  return 5; // fallback：未上卦时退化到中宫
}
