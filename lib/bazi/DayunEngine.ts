/**
 * 岁吉 · 大运流年推算引擎
 *
 * 理论来源：
 * - 《渊海子平》—— 大运排布、流年推算
 * - 《三命通会》—— 冲合刑害干支关系体系
 * - 《滴天髓》—— 运程综合判断、用神喜忌
 * - 《黄帝内经》—— 五行对应脏腑（健康分析）
 */

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
    const birthYear = this.mingPan.birthDateTime.getFullYear();
    const list: LiuNian[] = [];
    for (let i = 0; i < 10; i++) {
      const year = birthYear + daYun.startAge + i;
      list.push(this.getCurrentLiuNian(year));
    }
    return list;
  }

  /**
   * 获取指定虚岁所处的大运步
   *
   * @param currentAge 当前虚岁（周岁 + 1）
   * @returns 对应的 DaYun；未起运时返回第一步，超出排盘范围返回最后一步
   */
  getCurrentDaYun(currentAge: number): DaYun {
    const { daYunList, daYunStartAge } = this.mingPan;

    if (currentAge < daYunStartAge) {
      // 尚未起运，返回第一步大运作为参考
      return daYunList[0];
    }

    for (const dy of daYunList) {
      if (currentAge >= dy.startAge && currentAge <= dy.endAge) {
        return dy;
      }
    }

    return daYunList[daYunList.length - 1];
  }

  /**
   * 获取指定公历年份的流年信息
   *
   * @param year 公历年份（如 2026）
   * @returns 包含干支、十神及与命盘互动关系的 LiuNian
   */
  getCurrentLiuNian(year: number): LiuNian {
    const ganZhi  = this.yearToGanZhi(year);
    const riGan   = this.mingPan.riZhu.gan;
    const shiShen = DayunEngine.computeShiShen(riGan, ganZhi.gan);
    // 先构造无互动的占位对象，再分析互动
    const base: LiuNian = { year, ganZhi, shiShen, interactions: [] };
    const interactions = this.analyzeInteractions(base);

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
  analyzeInteractions(liuNian: LiuNian): string[] {
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
    const birthYear = this.mingPan.birthDateTime.getFullYear();
    const age = liuNian.year - birthYear;
    const daYun = this.getCurrentDaYun(age);
    const allTargets = [
      ...pillars,
      { label: '大运', gan: daYun.ganZhi.gan, zhi: daYun.ganZhi.zhi },
    ];

    for (const { label, gan, zhi } of allTargets) {
      // ── 天干五合 ────────────────────────────────
      for (const [a, b, huaWx] of DayunEngine.GAN_HE) {
        if ((lyGan === a && gan === b) || (lyGan === b && gan === a)) {
          results.push(
            `流年${lyGan}与${label}${gan}天干相合（化${huaWx}），利于合作与成事`,
          );
        }
      }

      // ── 天干相冲 ────────────────────────────────
      for (const [a, b] of DayunEngine.GAN_CHONG) {
        if ((lyGan === a && gan === b) || (lyGan === b && gan === a)) {
          results.push(
            `流年${lyGan}与${label}${gan}天干相冲，易有突变与意志摩擦`,
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
            `流年${lyZhi}合${label}${zhi}（六合化${huaWx}），有利缘分与合作机遇`,
          );
        }
      }

      // ── 地支六害 ────────────────────────────────
      for (const [a, b] of DayunEngine.ZHI_LIU_HAI) {
        if ((lyZhi === a && zhi === b) || (lyZhi === b && zhi === a)) {
          results.push(
            `流年${lyZhi}害${label}${zhi}（六害），注意人际摩擦与暗中阻碍`,
          );
        }
      }

      // ── 地支相刑（含自刑）───────────────────────
      for (const [a, b] of DayunEngine.ZHI_XING) {
        if (a === b) {
          // 自刑：流年地支 = 命盘地支，且为自刑地支
          if (lyZhi === a && zhi === b) {
            results.push(`流年${lyZhi}自刑${label}，内耗较重，宜内省调整`);
          }
        } else if ((lyZhi === a && zhi === b) || (lyZhi === b && zhi === a)) {
          results.push(
            `流年${lyZhi}刑${label}${zhi}（相刑），需防官非、健康或关系紧张`,
          );
        }
      }
    }

    // ── 流年五行与用神 / 喜神 / 忌神关系 ─────────────
    const lyWx = DayunEngine.GAN_WUXING[lyGan];
    const { yongShen, xiShen, jiShen } = this.mingPan.wuXingStrength;

    if (lyWx === yongShen) {
      results.push(
        `流年天干${lyGan}属${lyWx}，逢用神之年，整体运势较顺，利于突破与发展`,
      );
    } else if (lyWx === xiShen) {
      results.push(
        `流年天干${lyGan}属${lyWx}，逢喜神之年，平顺中有助力，可稳步把握机会`,
      );
    } else if (lyWx === jiShen) {
      results.push(
        `流年天干${lyGan}属${lyWx}，逢忌神之年，宜谨慎行事，避免冒进与重大变动`,
      );
    }

    return results;
  }

  /**
   * 综合大运 + 流年全年预测
   *
   * 评分规则（《滴天髓》用神喜忌论）：
   *   - 流年/大运天干五行 = 用神 → +2
   *   - 流年/大运天干五行 = 喜神 → +1
   *   - 流年/大运天干五行 = 忌神 → -2
   *   总分 ≥ 2 为顺，≤ -2 为逆，其余为平
   *
   * @param year 公历年份
   */
  getYearForecast(year: number): {
    year: number;
    daYun: DaYun;
    liuNian: LiuNian;
    overallTrend: '顺' | '平' | '逆';
    careerOutlook: string;
    wealthOutlook: string;
    relationshipOutlook: string;
    healthOutlook: string;
    keyAdvice: string;
    luckyMonths: number[];
  } {
    const birthYear = this.mingPan.birthDateTime.getFullYear();
    const age = year - birthYear;
    const daYun   = this.getCurrentDaYun(age);
    const liuNian = this.getCurrentLiuNian(year);

    const { yongShen, xiShen, jiShen } = this.mingPan.wuXingStrength;
    const lyWx = DayunEngine.GAN_WUXING[liuNian.ganZhi.gan];
    const dyWx = DayunEngine.GAN_WUXING[daYun.ganZhi.gan];

    const scoreWx = (wx: WuXing): number =>
      wx === yongShen ? 2 : wx === xiShen ? 1 : wx === jiShen ? -2 : 0;

    const totalScore    = scoreWx(lyWx) + scoreWx(dyWx);
    const overallTrend: '顺' | '平' | '逆' =
      totalScore >= 2 ? '顺' : totalScore <= -2 ? '逆' : '平';

    const riWx   = DayunEngine.GAN_WUXING[this.mingPan.riZhu.gan];
    const caiFx  = DayunEngine.KE[riWx];      // 我克者 = 财星
    const guanFx = DayunEngine.getKeMe(riWx); // 克我者 = 官星

    return {
      year,
      daYun,
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
      case '日柱': return '日支受冲，婚姻家庭易有动荡，注意情感关系稳定性';
      case '月柱': return '月支受冲，职场与财运有波动，防事业变动';
      case '年柱': return '年支受冲，与长辈或故土有变故，祖业易动摇';
      case '时柱': return '时支受冲，子女或晚辈有变动，晚运需注意';
      case '大运': return '大运地支受冲，该步大运整体动荡感增强，需稳住心态';
      default:     return '相关宫位易有变动与波折';
    }
  }

  private careerOutlook(
    lyWx: WuXing,
    dyWx: WuXing,
    guanFx: WuXing,
    yongShen: WuXing,
    trend: '顺' | '平' | '逆',
  ): string {
    if (lyWx === guanFx || dyWx === guanFx) {
      return trend === '逆'
        ? '官星虽现，但逢忌运，职场竞争激烈，防小人与权力摩擦'
        : '官星入运，事业有晋升或重要转机，适合积极拓展影响力';
    }
    if (lyWx === yongShen || dyWx === yongShen) {
      return '用神得力，事业推进顺畅，适合开展新项目或寻求突破';
    }
    return trend === '顺'
      ? '整体稳健，可稳步推进既有计划，不宜大幅变动'
      : '事业平淡，宜守不宜攻，做好基础积累为主';
  }

  private wealthOutlook(
    lyWx: WuXing,
    dyWx: WuXing,
    caiFx: WuXing,
    trend: '顺' | '平' | '逆',
  ): string {
    if (lyWx === caiFx || dyWx === caiFx) {
      return trend === '逆'
        ? '财星入运但大势不顺，有收入机会亦有损耗，量力而行'
        : '财星旺相，是增加收入和资产积累的有利时机，可适度投资';
    }
    return trend === '顺'
      ? '财运平稳向好，正职收入有望增长'
      : '财运普通，避免高风险投资，保守理财为宜';
  }

  private relationshipOutlook(liuNian: LiuNian, daYun: DaYun): string {
    const gender = this.mingPan.gender;
    // 男命：财星（正财/偏财）为配偶星；女命：官星（正官/七杀）为配偶星
    const peiouStar: ShiShen[] = gender === '男'
      ? ['正财', '偏财']
      : ['正官', '七杀'];

    if (peiouStar.includes(liuNian.shiShen) || peiouStar.includes(daYun.shiShen)) {
      return '桃花运旺，有缘分机会，单身者易遇良缘，已婚者感情可进一步深化';
    }
    const hasDayChong = liuNian.interactions.some(
      s => s.includes('冲') && s.includes('日柱'),
    );
    if (hasDayChong) {
      return '日支被冲，感情婚姻易出现摩擦或变动，需多沟通包容';
    }
    return '感情平稳，维系好现有关系，不宜强求大变化';
  }

  private healthOutlook(liuNian: LiuNian, trend: '顺' | '平' | '逆'): string {
    const zhiWx = DayunEngine.ZHI_WUXING[liuNian.ganZhi.zhi];
    // 五行对应脏腑（《黄帝内经》五脏五行）
    const wxOrgan: Record<WuXing, string> = {
      木: '肝胆', 火: '心脑', 土: '脾胃', 金: '肺气管', 水: '肾泌尿',
    };
    const organ = wxOrgan[zhiWx];
    return trend === '逆'
      ? `整体精力偏低，${organ}系统需多加注意，建议定期体检，规律作息`
      : `健康状况良好，留意${organ}相关保养，保持适度运动`;
  }

  private keyAdvice(
    trend: '顺' | '平' | '逆',
    lyWx: WuXing,
    yongShen: WuXing,
  ): string {
    const extra = lyWx === yongShen ? '用神得助，' : '';
    switch (trend) {
      case '顺':
        return `运势顺畅，${extra}把握机遇大胆推进重要决策，是发展的黄金时期`;
      case '平':
        return `运势平稳，稳中求进，夯实基础积累资源，为下一个运程做好准备`;
      case '逆':
        return `运势偏弱，以守为主，减少冒进，注重健康与人际关系，化解阻力而非强行突破`;
    }
  }

  /**
   * 推算吉利月份
   *
   * 地支月支对应关系（节气月，简化为阳历月）：
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

      months.push({ month: m, ganZhi, shiShen, zhiShiShen });
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
   * 基准日：1900-01-01 为甲子日（六十甲子序号 0）
   *
   * @param date 公历日期
   */
  getLiuRi(date: Date): LiuRi {
    const riGan = this.mingPan.riZhu.gan;

    // 基准：1900-01-01 = 甲子日
    const base = new Date(1900, 0, 1);
    const diffDays = Math.floor((date.getTime() - base.getTime()) / 86400000);
    const cycle60 = ((diffDays % 60) + 60) % 60;

    const ganZhi = DayunEngine.indexToGanZhi(cycle60);
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
    const daysInMonth = new Date(year, month, 0).getDate();
    for (let d = 1; d <= daysInMonth; d++) {
      days.push(this.getLiuRi(new Date(year, month - 1, d)));
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
