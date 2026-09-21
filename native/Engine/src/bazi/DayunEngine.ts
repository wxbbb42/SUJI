/**
 * 有时 · 大运流年推算引擎
 *
 * 理论来源：
 * - 《渊海子平》—— 大运排布、流年推算
 * - 《三命通会》—— 冲合刑害干支关系体系
 * - 《滴天髓》—— 运程综合判断、用神喜忌
 * - 《黄帝内经》—— 五行对应脏腑（健康分析）
 */

import { getCalendarPillars, sexagenaryIndex, beijingDateParts, fromBeijingParts, getSolarTerms } from '../calendar/precision';
import type {
  TianGan, DiZhi, WuXing, YinYang, ShiShen,
  GanZhi, DaYun, LiuNian, LiuYue, LiuRi, MingPan,
} from './types';

// ─────────────────────────────────────────────────────────────────
// 纳音五行表（60 甲子，每相邻两柱共用一纳音；源：《三命通会》）
// 索引 0 = 甲子乙丑，1 = 丙寅丁卯，…，29 = 壬戌癸亥
// ─────────────────────────────────────────────────────────────────
const NA_YIN_60: string[] = [
  '海中金', '炉中火', '大林木', '路旁土', '剑锋金',
  '山头火', '涧下水', '城头土', '白蜡金', '杨柳木',
  '泉中水', '屋上土', '霹雳火', '松柏木', '长流水',
  '沙中金', '山下火', '平地木', '壁上土', '金箔金',
  '覆灯火', '天河水', '大驿土', '钗钏金', '桑柘木',
  '大溪水', '沙中土', '天上火', '石榴木', '大海水',
];

const NA_YIN_WX_MAP: Record<string, WuXing> = {
  海中金: '金', 炉中火: '火', 大林木: '木', 路旁土: '土', 剑锋金: '金',
  山头火: '火', 涧下水: '水', 城头土: '土', 白蜡金: '金', 杨柳木: '木',
  泉中水: '水', 屋上土: '土', 霹雳火: '火', 松柏木: '木', 长流水: '水',
  沙中金: '金', 山下火: '火', 平地木: '木', 壁上土: '土', 金箔金: '金',
  覆灯火: '火', 天河水: '水', 大驿土: '土', 钗钏金: '金', 桑柘木: '木',
  大溪水: '水', 沙中土: '土', 天上火: '火', 石榴木: '木', 大海水: '水',
};

/**
 * 大运流年推算引擎
 *
 * 依赖一个已排好的 MingPan（由 BaziEngine.calculate 生成），
 * 在其基础上推算当步大运、流年干支，以及与命盘的冲合刑害互动。
 *
 * @example
 * ```ts
 * const engine = new DayunEngine(mingPan);
 * const daYun  = engine.getCurrentDaYun(35);
 * const liuNian = engine.getCurrentLiuNian(2026);
 * const forecast = engine.getYearForecast(2026);
 * ```
 */
export class DayunEngine {
  // ════════════════════════════════════════════
  // § 静态查表数据（与 BaziEngine 共享同一理论来源）
  // ════════════════════════════════════════════

  static readonly TIAN_GAN: TianGan[] = [
    '甲', '乙', '丙', '丁', '戊', '己', '庚', '辛', '壬', '癸',
  ];

  static readonly DI_ZHI: DiZhi[] = [
    '子', '丑', '寅', '卯', '辰', '巳', '午', '未', '申', '酉', '戌', '亥',
  ];

  static readonly GAN_WUXING: Record<TianGan, WuXing> = {
    甲: '木', 乙: '木', 丙: '火', 丁: '火', 戊: '土',
    己: '土', 庚: '金', 辛: '金', 壬: '水', 癸: '水',
  };

  static readonly GAN_YINYANG: Record<TianGan, YinYang> = {
    甲: '阳', 乙: '阴', 丙: '阳', 丁: '阴', 戊: '阳',
    己: '阴', 庚: '阳', 辛: '阴', 壬: '阳', 癸: '阴',
  };

  static readonly ZHI_WUXING: Record<DiZhi, WuXing> = {
    子: '水', 丑: '土', 寅: '木', 卯: '木', 辰: '土', 巳: '火',
    午: '火', 未: '土', 申: '金', 酉: '金', 戌: '土', 亥: '水',
  };

  static readonly ZHI_YINYANG: Record<DiZhi, YinYang> = {
    子: '阳', 丑: '阴', 寅: '阳', 卯: '阴', 辰: '阳', 巳: '阴',
    午: '阳', 未: '阴', 申: '阳', 酉: '阴', 戌: '阳', 亥: '阴',
  };

  /** 五行相生（木→火→土→金→水→木） */
  private static readonly SHENG: Record<WuXing, WuXing> = {
    木: '火', 火: '土', 土: '金', 金: '水', 水: '木',
  };

  /** 五行相克（木→土→水→火→金→木） */
  private static readonly KE: Record<WuXing, WuXing> = {
    木: '土', 土: '水', 水: '火', 火: '金', 金: '木',
  };

  /** 地支六冲（《渊海子平》） */
  private static readonly ZHI_LIU_CHONG: [DiZhi, DiZhi][] = [
    ['子', '午'], ['丑', '未'], ['寅', '申'],
    ['卯', '酉'], ['辰', '戌'], ['巳', '亥'],
  ];

  /** 地支六合（《三命通会》） */
  private static readonly ZHI_LIU_HE: [DiZhi, DiZhi, WuXing][] = [
    ['子', '丑', '土'], ['寅', '亥', '木'], ['卯', '戌', '火'],
    ['辰', '酉', '金'], ['巳', '申', '水'], ['午', '未', '土'],
  ];

  /** 地支六害（《三命通会》） */
  private static readonly ZHI_LIU_HAI: [DiZhi, DiZhi][] = [
    ['子', '未'], ['丑', '午'], ['寅', '巳'],
    ['卯', '辰'], ['申', '亥'], ['酉', '戌'],
  ];

  /**
   * 地支相刑（《渊海子平》）
   * 含三刑、二刑、自刑
   */
  private static readonly ZHI_XING: [DiZhi, DiZhi][] = [
    ['寅', '巳'], ['巳', '申'], ['申', '寅'],  // 三刑无恩
    ['丑', '戌'], ['戌', '未'], ['未', '丑'],  // 三刑无礼
    ['子', '卯'], ['卯', '子'],                // 相刑
    ['辰', '辰'], ['午', '午'], ['酉', '酉'], ['亥', '亥'], // 自刑
  ];

  /** 天干五合（《渊海子平》） */
  private static readonly GAN_HE: [TianGan, TianGan, WuXing][] = [
    ['甲', '己', '土'], ['乙', '庚', '金'], ['丙', '辛', '水'],
    ['丁', '壬', '木'], ['戊', '癸', '火'],
  ];

  /** 天干相冲（间隔 6 位，戊己不冲） */
  private static readonly GAN_CHONG: [TianGan, TianGan][] = [
    ['甲', '庚'], ['乙', '辛'], ['丙', '壬'], ['丁', '癸'],
  ];

  // ════════════════════════════════════════════
  // § 实例属性 & 构造函数
  // ════════════════════════════════════════════

  private readonly mingPan: MingPan;

  constructor(mingPan: MingPan) {
    this.mingPan = mingPan;
  }

  // ════════════════════════════════════════════
  // § 公开方法
  // ════════════════════════════════════════════

  /** 返回命盘完整大运列表 */
  getDaYunList(): DaYun[] {
    return this.mingPan.daYunList;
  }

  /**
   * 获取某步大运中的 10 个流年列表
   * @param daYun 大运对象
   */
  getLiuNian(daYun: DaYun): LiuNian[] {
    const birthYear = beijingDateParts(this.mingPan.birthDateTime).year;
    const list: LiuNian[] = [];
    for (let i = 0; i < 10; i++) {
      const year = (daYun.startDate ? beijingDateParts(new Date(daYun.startDate)).year : birthYear + daYun.startAge) + i;
      list.push(this.getCurrentLiuNian(year));
    }
    return list;
  }

  /** Compatibility for whole-age displays only. Use getCurrentDaYunAt for actual transitions. */
  getCurrentDaYun(currentAge: number): DaYun | null {
    if (!Number.isFinite(currentAge) || currentAge < 0) return null;
    return this.mingPan.daYunList.find(dy => currentAge >= dy.startAge && currentAge < dy.endAge + 1) ?? null;
  }

  getDaYunStatusAt(date: Date): { status: 'before-birth' | 'before-start' | 'active' | 'out-of-range' | 'missing-exact-dates'; daYun: DaYun | null } {
    if (!Number.isFinite(date.getTime())) throw new RangeError('日期无效');
    if (date.getTime() < this.mingPan.birthDateTime.getTime()) return {status:'before-birth', daYun:null};
    const list = this.mingPan.daYunList;
    if (!list.length || list.some(dy => !dy.startDate || !dy.endDate)) return {status:'missing-exact-dates', daYun:null};
    if (date.getTime() < Date.parse(list[0].startDate!)) return {status:'before-start', daYun:null};
    const daYun = list.find(dy => date.getTime() >= Date.parse(dy.startDate!) && date.getTime() < Date.parse(dy.endDate!)) ?? null;
    return {status:daYun ? 'active' : 'out-of-range', daYun};
  }

  getCurrentDaYunAt(date: Date): DaYun | null {
    return this.getDaYunStatusAt(date).daYun;
  }

  /**
   * 获取指定公历年份的流年信息
   *
   * @param year 公历年份（如 2026）
   * @returns 包含干支、十神及与命盘互动关系的 LiuNian
   */
  getCurrentLiuNian(year: number, referenceDate: Date = fromBeijingParts(year, 7, 1, 12)): LiuNian {
    const ganZhi  = this.yearToGanZhi(year);
    const riGan   = this.mingPan.riZhu.gan;
    const shiShen = DayunEngine.computeShiShen(riGan, ganZhi.gan);
    // 先构造无互动的占位对象，再分析互动
    const base: LiuNian = { year, ganZhi, shiShen, interactions: [] };
    const interactions = this.analyzeInteractions(base, referenceDate);

    return { ...base, interactions };
  }

  /**
   * 分析流年干支与命盘四柱 + 当步大运的冲合刑害关系
   *
   * 检查范围：
   *   - 天干：五合、相冲
   *   - 地支：六冲、六合、六害、相刑（含自刑）
   *   - 流年五行与用神/喜神/忌神的关系
   *
   * @param liuNian 流年（interactions 字段可为空，本方法重新生成）
   * @returns 互动关系中文描述列表
   */
  analyzeInteractions(liuNian: LiuNian, referenceDate: Date = fromBeijingParts(liuNian.year, 7, 1, 12)): string[] {
    const results: string[] = [];
    const { siZhu } = this.mingPan;
    const lyGan = liuNian.ganZhi.gan;
    const lyZhi = liuNian.ganZhi.zhi;

    const pillars: { label: string; gan: TianGan; zhi: DiZhi }[] = [
      { label: '年柱', gan: siZhu.year.ganZhi.gan,  zhi: siZhu.year.ganZhi.zhi  },
      { label: '月柱', gan: siZhu.month.ganZhi.gan, zhi: siZhu.month.ganZhi.zhi },
      { label: '日柱', gan: siZhu.day.ganZhi.gan,   zhi: siZhu.day.ganZhi.zhi   },
      { label: '时柱', gan: siZhu.hour.ganZhi.gan,  zhi: siZhu.hour.ganZhi.zhi  },
    ];

    // 将当步大运也纳入互动分析
    const daYun = this.getCurrentDaYunAt(referenceDate);
    const allTargets = [
      ...pillars,
      ...(daYun ? [{ label: '大运', gan: daYun.ganZhi.gan, zhi: daYun.ganZhi.zhi }] : []),
    ];

    for (const { label, gan, zhi } of allTargets) {
      // ── 天干五合 ────────────────────────────────
      for (const [a, b, huaWx] of DayunEngine.GAN_HE) {
        if ((lyGan === a && gan === b) || (lyGan === b && gan === a)) {
          results.push(
            `流年${lyGan}与${label}${gan}天干相合（传统合化方向为${huaWx}，此处未判成化）`,
          );
        }
      }

      // ── 天干相冲 ────────────────────────────────
      for (const [a, b] of DayunEngine.GAN_CHONG) {
        if ((lyGan === a && gan === b) || (lyGan === b && gan === a)) {
          results.push(
            `流年${lyGan}与${label}${gan}天干相冲；传统上用于讨论张力，不代表现实事件必然发生`,
          );
        }
      }

      // ── 地支六冲 ────────────────────────────────
      for (const [a, b] of DayunEngine.ZHI_LIU_CHONG) {
        if ((lyZhi === a && zhi === b) || (lyZhi === b && zhi === a)) {
          results.push(
            `流年${lyZhi}冲${label}${zhi}（六冲），${this.chongMeaning(label)}`,
          );
        }
      }

      // ── 地支六合 ────────────────────────────────
      for (const [a, b, huaWx] of DayunEngine.ZHI_LIU_HE) {
        if ((lyZhi === a && zhi === b) || (lyZhi === b && zhi === a)) {
          results.push(
            `流年${lyZhi}合${label}${zhi}（六合，传统合化方向为${huaWx}，未判成化）`,
          );
        }
      }

      // ── 地支六害 ────────────────────────────────
      for (const [a, b] of DayunEngine.ZHI_LIU_HAI) {
        if ((lyZhi === a && zhi === b) || (lyZhi === b && zhi === a)) {
          results.push(
            `流年${lyZhi}害${label}${zhi}（六害）；这是传统关系标签，不推断他人的动机`,
          );
        }
      }

      // ── 地支相刑（含自刑）───────────────────────
      for (const [a, b] of DayunEngine.ZHI_XING) {
        if (a === b) {
          // 自刑：流年地支 = 命盘地支，且为自刑地支
          if (lyZhi === a && zhi === b) {
            results.push(`流年${lyZhi}自刑${label}；可作为自我复盘的传统意象`);
          }
        } else if ((lyZhi === a && zhi === b) || (lyZhi === b && zhi === a)) {
          results.push(
            `流年${lyZhi}刑${label}${zhi}（相刑）；单一关系不足以推断官非、健康或感情事件`,
          );
        }
      }
    }

    // ── 流年五行与用神 / 喜神 / 忌神关系 ─────────────
    const lyWx = DayunEngine.GAN_WUXING[lyGan];
    const { yongShen, xiShen, jiShen } = this.mingPan.wuXingStrength;

    if (lyWx === yongShen) {
      results.push(
        `流年天干${lyGan}属${lyWx}，与当前扶抑参考的用神一致，属于规则内的对应关系`,
      );
    } else if (lyWx === xiShen) {
      results.push(
        `流年天干${lyGan}属${lyWx}，与当前扶抑参考的喜神一致，不代表机会一定出现`,
      );
    } else if (lyWx === jiShen) {
      results.push(
        `流年天干${lyGan}属${lyWx}，与当前扶抑参考的忌神一致，不据此否定现实选择`,
      );
    }

    return [...new Set(results)];
  }

  /**
   * 综合大运 + 流年全年预测
   *
   * 工程启发式标签（借用传统喜忌术语；数值不是《滴天髓》原文，也未校准为现实预测）：
   *   - 流年/大运天干五行 = 用神 → +2
   *   - 流年/大运天干五行 = 喜神 → +1
   *   - 流年/大运天干五行 = 忌神 → -2
   *   总分 ≥ 2 为顺，≤ -2 为逆，其余为平
   *
   * @param year 公历年份
   */
  getYearForecast(year: number, referenceDate: Date = fromBeijingParts(year, 7, 1, 12)): {
    year: number;
    daYun: DaYun | null;
    daYunStatus: ReturnType<DayunEngine['getDaYunStatusAt']>['status'];
    referenceDate: string;
    luckyMonthsCalendar: 'solar-term-ordinal';
    interpretationBasis: { kind: 'engineering-heuristic'; calibratedProbability: false; description: string };
    liuNian: LiuNian;
    overallTrend: '顺' | '平' | '逆';
    careerOutlook: string;
    wealthOutlook: string;
    relationshipOutlook: string;
    healthOutlook: string;
    keyAdvice: string;
    luckyMonths: number[];
  } {
    const { daYun, status: daYunStatus } = this.getDaYunStatusAt(referenceDate);
    const liuNian = this.getCurrentLiuNian(year, referenceDate);

    const { yongShen, xiShen, jiShen } = this.mingPan.wuXingStrength;
    const lyWx = DayunEngine.GAN_WUXING[liuNian.ganZhi.gan];
    const dyWx = daYun ? DayunEngine.GAN_WUXING[daYun.ganZhi.gan] : undefined;

    const scoreWx = (wx: WuXing): number =>
      wx === yongShen ? 2 : wx === xiShen ? 1 : wx === jiShen ? -2 : 0;

    const totalScore    = scoreWx(lyWx) + (dyWx ? scoreWx(dyWx) : 0);
    const overallTrend: '顺' | '平' | '逆' =
      totalScore >= 2 ? '顺' : totalScore <= -2 ? '逆' : '平';

    const riWx   = DayunEngine.GAN_WUXING[this.mingPan.riZhu.gan];
    const caiFx  = DayunEngine.KE[riWx];      // 我克者 = 财星
    const guanFx = DayunEngine.getKeMe(riWx); // 克我者 = 官星

    return {
      year,
      daYun,
      daYunStatus,
      referenceDate: referenceDate.toISOString(),
      luckyMonthsCalendar: 'solar-term-ordinal',
      interpretationBasis: { kind: 'engineering-heuristic', calibratedProbability: false, description: '顺／平／逆和月份建议来自五行喜忌的工程规则，不是古籍数值、事件概率或财务健康预测。' },
      liuNian,
      overallTrend,
      careerOutlook:       this.careerOutlook(lyWx, dyWx, guanFx, yongShen, overallTrend),
      wealthOutlook:       this.wealthOutlook(lyWx, dyWx, caiFx, overallTrend),
      relationshipOutlook: this.relationshipOutlook(liuNian, daYun),
      healthOutlook:       this.healthOutlook(liuNian, overallTrend),
      keyAdvice:           this.keyAdvice(overallTrend, lyWx, yongShen),
      luckyMonths:         this.luckyMonths(yongShen, xiShen),
    };
  }

  // ════════════════════════════════════════════
  // § 内部辅助方法
  // ════════════════════════════════════════════

  /**
   * 六十甲子序号（0–59）→ GanZhi
   * 供外部模块（如 InsightEngine 的每日干支计算）复用
   */
  static indexToGanZhi(idx: number): GanZhi {
    const i          = ((idx % 60) + 60) % 60;
    const gan        = DayunEngine.TIAN_GAN[i % 10];
    const zhi        = DayunEngine.DI_ZHI[i % 12];
    const naYin      = NA_YIN_60[Math.floor(i / 2)];
    const naYinWuXing: WuXing = NA_YIN_WX_MAP[naYin] ?? '土';
    return {
      gan,
      zhi,
      ganWuXing:  DayunEngine.GAN_WUXING[gan],
      zhiWuXing:  DayunEngine.ZHI_WUXING[zhi],
      ganYinYang: DayunEngine.GAN_YINYANG[gan],
      zhiYinYang: DayunEngine.ZHI_YINYANG[zhi],
      naYin,
      naYinWuXing,
    };
  }

  /**
   * 公历年份 → GanZhi
   *
   * 甲子年基准：1984 年（60 甲子循环索引 = 0）
   *   ganIdx = (year - 4) % 10
   *   zhiIdx = (year - 4) % 12
   *   naYin  = NA_YIN_60[ floor(cycle60 / 2) ]
   */
  private yearToGanZhi(year: number): GanZhi {
    const base    = year - 4;
    const ganIdx  = ((base % 10) + 10) % 10;
    const zhiIdx  = ((base % 12) + 12) % 12;
    const cycle60 = ((base % 60) + 60) % 60;

    const gan          = DayunEngine.TIAN_GAN[ganIdx];
    const zhi          = DayunEngine.DI_ZHI[zhiIdx];
    const naYin        = NA_YIN_60[Math.floor(cycle60 / 2)];
    const naYinWuXing: WuXing = NA_YIN_WX_MAP[naYin] ?? '土';

    return {
      gan,
      zhi,
      ganWuXing:  DayunEngine.GAN_WUXING[gan],
      zhiWuXing:  DayunEngine.ZHI_WUXING[zhi],
      ganYinYang: DayunEngine.GAN_YINYANG[gan],
      zhiYinYang: DayunEngine.ZHI_YINYANG[zhi],
      naYin,
      naYinWuXing,
    };
  }

  /**
   * 推算天干十神（与 BaziEngine.computeShiShen 逻辑一致）
   * 来源：《渊海子平》十神论
   */
  static computeShiShen(riGan: TianGan, targetGan: TianGan): ShiShen {
    const riWx = DayunEngine.GAN_WUXING[riGan];
    const tgWx = DayunEngine.GAN_WUXING[targetGan];
    const same = DayunEngine.GAN_YINYANG[riGan] === DayunEngine.GAN_YINYANG[targetGan];

    if (riWx === tgWx)                              return same ? '比肩' : '劫财';
    if (DayunEngine.SHENG[riWx] === tgWx)           return same ? '食神' : '伤官';
    if (DayunEngine.KE[riWx] === tgWx)              return same ? '偏财' : '正财';
    if (DayunEngine.KE[tgWx] === riWx)              return same ? '七杀' : '正官';
    if (DayunEngine.SHENG[tgWx] === riWx)           return same ? '偏印' : '正印';
    return '比肩'; // 理论上不可达
  }

  /** 反向查克我五行：KE 表中值 = wx → 返回其键 */
  private static getKeMe(wx: WuXing): WuXing {
    for (const [k, v] of Object.entries(DayunEngine.KE) as [WuXing, WuXing][]) {
      if (v === wx) return k;
    }
    return wx;
  }

  /** 六冲含义（按被冲柱位分类） */
  private chongMeaning(label: string): string {
    switch (label) {
      case '日柱': return '传统解释常联系亲密关系议题，可据实际经历检查沟通与边界';
      case '月柱': return '传统解释常联系工作与成长环境，可整理近期目标和变化';
      case '年柱': return '传统解释常联系成长背景与长辈，可按实际需要安排交流';
      case '时柱': return '传统解释常联系长期计划，不据此预测子女或晚年事件';
      case '大运': return '当前规则中出现大运与流年冲的组合，可复盘已有计划是否需要调整';
      default:     return '存在传统冲的关系，具体含义需要结合语境';
    }
  }

  private careerOutlook(
    lyWx: WuXing,
    dyWx: WuXing | undefined,
    guanFx: WuXing,
    yongShen: WuXing,
    trend: '顺' | '平' | '逆',
  ): string {
    if (lyWx === guanFx || dyWx === guanFx) {
      return trend === '逆'
        ? '传统官杀意象与当前喜忌标签并存；可检查职责边界与沟通方式，不据此判断同事动机'
        : '传统官杀意象常涉及职责与规范；可用实际绩效、岗位机会和资源评估职业计划';
    }
    if (lyWx === yongShen || dyWx === yongShen) {
      return '传统用神对应被触发；可将想推进的项目拆成可验证的小步骤，进展仍以现实反馈为准';
    }
    return trend === '顺'
      ? '可回顾既有计划的进展，依据资源和现实反馈安排下一步'
      : '可梳理技能与工作目标；是否行动应由实际条件决定';
  }

  private wealthOutlook(
    lyWx: WuXing,
    dyWx: WuXing | undefined,
    caiFx: WuXing,
    trend: '顺' | '平' | '逆',
  ): string {
    if (lyWx === caiFx || dyWx === caiFx) {
      return trend === '逆'
        ? '传统财星意象与当前喜忌标签并存；可整理预算、现金流与承受范围，不能据此预测收益'
        : '传统财星意象出现；可借此复盘收入结构与支出习惯，不构成投资时机或收益判断';
    }
    return trend === '顺'
      ? '财务计划请依据实际收入、负债和目标制定，命盘不提供收益预测'
      : '可检查财务目标与预算的差距；具体资产决策应依据风险和可靠的财务信息';
  }

  private relationshipOutlook(liuNian: LiuNian, daYun: DaYun | null): string {
    const gender = this.mingPan.gender;
    // 男命：财星（正财/偏财）为配偶星；女命：官星（正官/七杀）为配偶星
    const peiouStar: ShiShen[] = gender === '男'
      ? ['正财', '偏财']
      : ['正官', '七杀'];

    if (peiouStar.includes(liuNian.shiShen) || (daYun !== null && peiouStar.includes(daYun.shiShen))) {
      return '按传统配偶星口径出现关系意象；可关注真实互动中的期待、尊重与沟通，不推断缘分必然到来';
    }
    const hasDayChong = liuNian.interactions.some(
      s => s.includes('冲') && s.includes('日柱'),
    );
    if (hasDayChong) {
      return '日支存在冲的传统关系；可用它提出沟通问题，不据此断定分离、背叛或婚姻变化';
    }
    return '关系发展仍取决于双方的现实互动，可从倾听与清楚表达期待开始';
  }

  private healthOutlook(_liuNian: LiuNian, _trend: '顺' | '平' | '逆'): string {
    return '命理中的五行意象不能用于判断健康状况或疾病风险；日常保持规律作息与适度运动，身体不适时以医疗意见为准。';
  }

  private keyAdvice(
    trend: '顺' | '平' | '逆',
    lyWx: WuXing,
    yongShen: WuXing,
  ): string {
    const extra = lyWx === yongShen ? '传统用神对应被触发，' : '';
    switch (trend) {
      case '顺':
        return `${extra}当前规则标签为“顺”；可尝试一个可验证的小行动，重要决定仍需现实依据`;
      case '平':
        return `当前规则标签为“平”；可整理目标与资源，用实际反馈调整安排`;
      case '逆':
        return `当前规则标签为“逆”；可以复盘计划的难点，但不必因此放弃有现实依据的机会`;
    }
  }

  /**
   * 推算吉利月份
   *
   * 地支月支对应关系（节气月序号，不是公历月份）：
   *   子→11月，丑→12月，寅→1月，卯→2月，…，亥→10月
   * 月支五行逢用神或喜神者为吉月。
   */
  private luckyMonths(yongShen: WuXing, xiShen: WuXing): number[] {
    const zhiToMonth: Partial<Record<DiZhi, number>> = {
      子: 11, 丑: 12, 寅: 1,  卯: 2,  辰: 3,  巳: 4,
      午: 5,  未: 6,  申: 7,  酉: 8,  戌: 9,  亥: 10,
    };
    const lucky: number[] = [];
    for (const [zhi, month] of Object.entries(zhiToMonth) as [DiZhi, number][]) {
      const wx = DayunEngine.ZHI_WUXING[zhi];
      if (wx === yongShen || wx === xiShen) {
        lucky.push(month);
      }
    }
    return lucky.sort((a, b) => a - b);
  }

  // ════════════════════════════════════════════
  // § 流月排盘
  // ════════════════════════════════════════════

  /**
   * 获取某年 12 个流月的干支
   *
   * 流月干支推算规则（《渊海子平》月上起天干法）：
   * 年干     正月天干
   * 甲己 → 丙寅月
   * 乙庚 → 戊寅月
   * 丙辛 → 庚寅月
   * 丁壬 → 壬寅月
   * 戊癸 → 甲寅月
   *
   * @param year 公历年份
   */
  getLiuYue(year: number): LiuYue[] {
    const riGan = this.mingPan.riZhu.gan;
    const yearGanZhi = this.yearToGanZhi(year);
    const yearGanIdx = DayunEngine.TIAN_GAN.indexOf(yearGanZhi.gan);

    // 年干起月干：甲己起丙(2)，乙庚起戊(4)，丙辛起庚(6)，丁壬起壬(8)，戊癸起甲(0)
    const monthGanStart = ((yearGanIdx % 5) * 2 + 2) % 10;

    // 流月地支从寅开始（正月=寅，二月=卯，...，十一月=子，十二月=丑）
    const jie = [...getSolarTerms(year), ...getSolarTerms(year + 1)].filter(t => ['立春','惊蛰','清明','立夏','芒种','小暑','立秋','白露','寒露','立冬','大雪','小寒'].includes(t.name));
    const first = jie.findIndex(t => t.name === '立春');
    const monthTerms = jie.slice(first, first + 13);
    const months: LiuYue[] = [];
    for (let m = 1; m <= 12; m++) {
      const ganIdx = (monthGanStart + m - 1) % 10;
      const zhiIdx = (m + 1) % 12; // 正月=寅(2)，二月=卯(3)...

      const gan = DayunEngine.TIAN_GAN[ganIdx];
      const zhi = DayunEngine.DI_ZHI[zhiIdx];
      const cycle60 = this.ganZhiTo60(gan, zhi);
      const naYin = NA_YIN_60[Math.floor(cycle60 / 2)];

      const ganZhi: GanZhi = {
        gan, zhi,
        ganWuXing: DayunEngine.GAN_WUXING[gan],
        zhiWuXing: DayunEngine.ZHI_WUXING[zhi],
        ganYinYang: DayunEngine.GAN_YINYANG[gan],
        zhiYinYang: DayunEngine.ZHI_YINYANG[zhi],
        naYin,
        naYinWuXing: NA_YIN_WX_MAP[naYin] ?? '土',
      };

      const shiShen = DayunEngine.computeShiShen(riGan, gan);
      const zhiMainGan = this.zhiCangGanMain(zhi);
      const zhiShiShen = DayunEngine.computeShiShen(riGan, zhiMainGan);

      months.push({ month: m, ganZhi, shiShen, zhiShiShen, startDate: monthTerms[m-1].instant.toISOString(), endDate: monthTerms[m].instant.toISOString(), solarTerm: monthTerms[m-1].name });
    }
    return months;
  }

  // ════════════════════════════════════════════
  // § 流日排盘
  // ════════════════════════════════════════════

  /**
   * 获取某一天的流日干支
   *
   * 流日干支基于六十甲子循环。
   * 统一使用历法 facade，默认北京时间子初 23:00 换日。
   *
   * @param date 公历日期
   */
  getLiuRi(date: Date): LiuRi {
    const riGan = this.mingPan.riZhu.gan;

    const ganZhi = DayunEngine.indexToGanZhi(sexagenaryIndex(getCalendarPillars(date).day));
    const shiShen = DayunEngine.computeShiShen(riGan, ganZhi.gan);

    return { date, ganZhi, shiShen };
  }

  /**
   * 获取某月每一天的流日列表
   * @param year 年
   * @param month 月（1-12）
   */
  getLiuRiList(year: number, month: number): LiuRi[] {
    const days: LiuRi[] = [];
    const daysInMonth = new Date(Date.UTC(year, month, 0)).getUTCDate();
    for (let d = 1; d <= daysInMonth; d++) {
      days.push(this.getLiuRi(fromBeijingParts(year, month, d, 12)));
    }
    return days;
  }

  // ── 辅助 ──────────────────────────────────────

  /** 天干+地支 → 六十甲子序号 (0-59) */
  private ganZhiTo60(gan: TianGan, zhi: DiZhi): number {
    const g = DayunEngine.TIAN_GAN.indexOf(gan);
    const z = DayunEngine.DI_ZHI.indexOf(zhi);
    // 找 k 使 g + 10k ≡ z (mod 12)
    for (let k = 0; k < 6; k++) {
      if ((g + 10 * k) % 12 === z) return g + 10 * k;
    }
    return 0;
  }

  /** 地支藏干主气天干 */
  private zhiCangGanMain(zhi: DiZhi): TianGan {
    const CANG_MAIN: Record<DiZhi, TianGan> = {
      子: '癸', 丑: '己', 寅: '甲', 卯: '乙',
      辰: '戊', 巳: '丙', 午: '丁', 未: '己',
      申: '庚', 酉: '辛', 戌: '戊', 亥: '壬',
    };
    return CANG_MAIN[zhi];
  }
}
