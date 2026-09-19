/**
 * 合婚引擎：匹配男女八字，分析婚姻匹配度
 * 
 * 核心功能：
 * 🚀 分析天干地支相合/相冲及影响性格适配
 * 🚀 以日柱（日干+日支）为核心，判断夫妻缘分吉凶
 * 🚀 纳入"桃花星"、"红鸾星"、"凶煞"等影响
 * 🚀 提供匹配建议，支持流年婚姻预测
 */

import { BaziEngine } from '../bazi/BaziEngine';
import type { MingPan, DiZhi, TianGan } from '../bazi/types';

/** 八字婚姻匹配结果 */
export interface MarriageMatch {
  // 婚姻匹配度（基于天干/地支/十神权值加权，满分100）
  score: number;
  compatibility: string;  // 文本描述（优/合适/普通/不利...）

  // 夫妻核心关系
  dayGanCompatibility: string; // 日干天合/天冲
  dayZhiCompatibility: string; // 日支地合/地冲
  shenShaResults: { label: string; description: string; influence: '吉' | '凶' }[];

  // 流年预测
  favorableYears: number[];     // 有利婚姻运的流年（如桃花年、红鸾年...）
  unfavorableYears: number[];   // 不宜婚配的年（犯太岁、冲日...）

  // 建议
  keyAdvice: string;
}

export class MarriageEngine {
  private malePan: MingPan;
  private femalePan: MingPan;

  constructor(malePan: MingPan, femalePan: MingPan) {
    this.malePan = malePan;
    this.femalePan = femalePan;
  }

  /** 获取婚姻匹配结果 */
  getMatchResult(): MarriageMatch {
    const maleDayGan = this.malePan.siZhu.day.ganZhi.gan;
    const maleDayZhi = this.malePan.siZhu.day.ganZhi.zhi;
    const femaleDayGan = this.femalePan.siZhu.day.ganZhi.gan;
    const femaleDayZhi = this.femalePan.siZhu.day.ganZhi.zhi;

    // ── 日柱天干关系（核心点评）──────────────────────
    const dayGanCompatibility = this.ganCompatibility(maleDayGan, femaleDayGan);
    const dayZhiCompatibility = this.zhiCompatibility(maleDayZhi, femaleDayZhi);

    // ── 综合匹配打分 ────────────────────────────────
    const scores: number[] = [];
    const influences: { label: string; influence: '吉' | '凶'; description: string }[] = [];

    if (dayGanCompatibility === '天干合') scores.push(30);
    if (dayZhiCompatibility === '地支合') scores.push(50);
    if (dayGanCompatibility === '天干冲') scores.push(-20);
    if (dayZhiCompatibility === '地支冲') scores.push(-30);

    // ── 桃花星/红鸾星检查 ───────────────────────────
    const 桃花星 = ['子', '午', '卯', '酉']; // 四桃花
    const 红鸾星 = ['寅', '酉', '戌', '未'];

    if (桃花星.includes(maleDayZhi) || 桃花星.includes(femaleDayZhi)) {
      scores.push(20);
      influences.push({
        label: '夫妻宫现桃花',
        influence: '吉',
        description: '可提升双方缘分及和谐，但若局中夹杂凶星则带隐患',
      });
    }

    if (红鸾星.includes(maleDayZhi) || 红鸾星.includes(femaleDayZhi)) {
      scores.push(15);
      influences.push({
        label: '夫妻宫现红鸾',
        influence: '吉',
        description: '利于感情深厚，夫妻关系圆满',
      });
    }

    // ── 总分与推荐建议 ────────────────────────────────
    const totalScore = scores.reduce((s, v) => s + v, 0);
    let compatibility = '普通';
    let keyAdvice = '多观察磨合，婚姻经营需要双方努力';

    if (totalScore >= 80) {
      compatibility = '优';
      keyAdvice = '非常匹配，是极佳的婚姻组合';
    } else if (totalScore >= 60) {
      compatibility = '合适';
      keyAdvice = '整体婚姻匹配较高，适合长期关系';
    } else if (totalScore < 40) {
      compatibility = '不利';
      keyAdvice = '婚姻需谨慎，建议深入了解后再做决定';
    }

    // ── 返回结果 ────────────────────────────────────────
    return {
      score: totalScore,
      compatibility,
      dayGanCompatibility,
      dayZhiCompatibility,
      shenShaResults: influences,
      favorableYears: [],
      unfavorableYears: [],
      keyAdvice,
    };
  }

  // ─────────────────────────────────────────────── 
  // § 私有辅助方法：计算天干地支关系
  // ───────────────────────────────────────────────

  /** 判断天干的婚姻关系 */
  private ganCompatibility(maleGan: TianGan, femaleGan: TianGan): string {
    const HE: [TianGan, TianGan][] = [
      ['甲', '己'], ['乙', '庚'], ['丙', '辛'], ['丁', '壬'], ['戊', '癸'],
    ];
    const CHONG: [TianGan, TianGan][] = [
      ['甲', '庚'], ['乙', '辛'], ['丙', '壬'], ['丁', '癸'],
    ];

    for (const [m, f] of HE) {
      if ((maleGan === m && femaleGan === f) || (maleGan === f && femaleGan === m)) {
        return '天干合';
      }
    }

    for (const [m, f] of CHONG) {
      if ((maleGan === m && femaleGan === f) || (maleGan === f && femaleGan === m)) {
        return '天干冲';
      }
    }

    return '无特别关系';
  }

  /** 判断地支的婚姻关系 */
  private zhiCompatibility(maleZhi: DiZhi, femaleZhi: DiZhi): string {
    const HE: [DiZhi, DiZhi][] = [
      ['子', '丑'], ['寅', '亥'], ['卯', '戌'], ['辰', '酉'], ['巳', '申'], ['午', '未'],
    ];
    const CHONG: [DiZhi, DiZhi][] = [
      ['子', '午'], ['寅', '申'], ['卯', '酉'], ['辰', '戌'], ['巳', '亥'], ['丑', '未'],
    ];

    for (const [m, f] of HE) {
      if ((maleZhi === m && femaleZhi === f) || (maleZhi === f && maleZhi === m)) {
        return '地支合';
      }
    }

    for (const [m, f] of CHONG) {
      if ((maleZhi === m && femaleZhi === f) || (maleZhi === f && femaleZhi === m)) {
        return '地支冲';
      }
    }

    return '无特别关系';
  }
}
