/**
 * 有时 · 八字推算引擎
 *
 * 理论来源：
 * - 《渊海子平》（传统子平文献，通行本编纂归属需按底本核对）—— 四柱分析基本框架、十神体系、格局判定
 * - 《三命通会》（明·万民英）—— 神煞体系、纳音系统
 * - 《滴天髓》（旧题京图撰、刘基注；此处采用任铁樵阐微传统）—— 日主强弱判断、用神取法
 * - 《穷通宝鉴》（清·余春台）—— 调候用神、季节性分析
 */

import { CALENDAR_POLICY, getCalendarPillars, toSolar, fromSolar, fromBeijingParts, beijingDateParts, currentSolarTermAt, naYinFor, sexagenaryIndex, lunarCalendarWarnings } from '../calendar/precision';
import type { QiYunInfo } from './types';
import { getTiaoHouReview } from './tiaohou';
import { getTrueSolarTimeInfo } from './TrueSolarTime';
import { assessStemCombination, computeGeJuV2, computeRiZhuStructure, computeShiShenRelations } from './structural';
import type {
  BranchRelation,
  CangGanItem,
  DaYun, DaYunDirection,
  DiZhi,
  GanZhi,
  GeJu,
  MingPan,
  ShenSha,
  ShiErChangSheng,
  ShiShen,
  SiZhu,
  StemRelation,
  TianGan,
  WuXing,
  WuXingStrength,
  YinYang,
  ZhuDetail,
} from './types';

// ─────────────────────────────────────────────
// 辅助类型
// ─────────────────────────────────────────────
type PillarKey = 'year' | 'month' | 'day' | 'hour';

/**
 * 八字（四柱）推算引擎
 *
 * @example
 * ```ts
 * const engine = new BaziEngine();
 * const mingPan = engine.calculate(new Date('1990-08-15T10:00:00'), '男');
 * ```
 */
export class BaziEngine {
  // ═══════════════════════════════════════════
  // § 静态查表数据（渊海子平·三命通会·滴天髓）
  // ═══════════════════════════════════════════

  /** 天干顺序 */
  private static readonly TIAN_GAN: TianGan[] = [
    '甲', '乙', '丙', '丁', '戊', '己', '庚', '辛', '壬', '癸',
  ];

  /** 地支顺序 */
  private static readonly DI_ZHI: DiZhi[] = [
    '子', '丑', '寅', '卯', '辰', '巳', '午', '未', '申', '酉', '戌', '亥',
  ];

  /**
   * 天干五行（《渊海子平》）
   * 甲乙木、丙丁火、戊己土、庚辛金、壬癸水
   */
  private static readonly GAN_WUXING: Record<TianGan, WuXing> = {
    甲: '木', 乙: '木',
    丙: '火', 丁: '火',
    戊: '土', 己: '土',
    庚: '金', 辛: '金',
    壬: '水', 癸: '水',
  };

  /**
   * 天干阴阳（奇数序为阳，偶数序为阴；甲序0为阳）
   * 甲丙戊庚壬为阳，乙丁己辛癸为阴
   */
  private static readonly GAN_YINYANG: Record<TianGan, YinYang> = {
    甲: '阳', 乙: '阴',
    丙: '阳', 丁: '阴',
    戊: '阳', 己: '阴',
    庚: '阳', 辛: '阴',
    壬: '阳', 癸: '阴',
  };

  /**
   * 地支五行（《渊海子平》）
   * 寅卯木、巳午火、申酉金、亥子水、辰戌丑未土
   */
  private static readonly ZHI_WUXING: Record<DiZhi, WuXing> = {
    子: '水', 丑: '土', 寅: '木', 卯: '木',
    辰: '土', 巳: '火', 午: '火', 未: '土',
    申: '金', 酉: '金', 戌: '土', 亥: '水',
  };

  /**
   * 地支阴阳（《渊海子平》）
   * 子寅辰午申戌为阳，丑卯巳未酉亥为阴
   */
  private static readonly ZHI_YINYANG: Record<DiZhi, YinYang> = {
    子: '阳', 丑: '阴', 寅: '阳', 卯: '阴',
    辰: '阳', 巳: '阴', 午: '阳', 未: '阴',
    申: '阳', 酉: '阴', 戌: '阳', 亥: '阴',
  };

  /**
   * 地支藏干表（《三命通会》）
   * 格式：[本气, 中气?, 余气?] + 权重
   * 权重参考：本气 0.6–0.7，中气 0.2–0.3，余气 0.1
   */
  private static readonly CANG_GAN: Record<DiZhi, { gan: TianGan; weight: number }[]> = {
    子: [{ gan: '癸', weight: 1.0 }],
    丑: [{ gan: '己', weight: 0.6 }, { gan: '癸', weight: 0.2 }, { gan: '辛', weight: 0.2 }],
    寅: [{ gan: '甲', weight: 0.6 }, { gan: '丙', weight: 0.2 }, { gan: '戊', weight: 0.2 }],
    卯: [{ gan: '乙', weight: 1.0 }],
    辰: [{ gan: '戊', weight: 0.6 }, { gan: '乙', weight: 0.2 }, { gan: '癸', weight: 0.2 }],
    巳: [{ gan: '丙', weight: 0.6 }, { gan: '戊', weight: 0.2 }, { gan: '庚', weight: 0.2 }],
    午: [{ gan: '丁', weight: 0.7 }, { gan: '己', weight: 0.3 }],
    未: [{ gan: '己', weight: 0.6 }, { gan: '丁', weight: 0.2 }, { gan: '乙', weight: 0.2 }],
    申: [{ gan: '庚', weight: 0.6 }, { gan: '壬', weight: 0.2 }, { gan: '戊', weight: 0.2 }],
    酉: [{ gan: '辛', weight: 1.0 }],
    戌: [{ gan: '戊', weight: 0.6 }, { gan: '辛', weight: 0.2 }, { gan: '丁', weight: 0.2 }],
    亥: [{ gan: '壬', weight: 0.7 }, { gan: '甲', weight: 0.3 }],
  };

  /**
   * 五行相生顺序：木→火→土→金→水→木
   * 五行相克顺序：木→土→水→火→金→木
   * 来源：《渊海子平》五行生克论
   */
  private static readonly SHENG: Record<WuXing, WuXing> = {
    木: '火', 火: '土', 土: '金', 金: '水', 水: '木',
  };
  private static readonly KE: Record<WuXing, WuXing> = {
    木: '土', 土: '水', 水: '火', 火: '金', 金: '木',
  };

  /**
   * 十神推算规则（《渊海子平》·十神论）
   * 以日干为基准，判断其与他干的生克+阴阳关系
   *
   * 规则矩阵：
   *   同我（同五行）：同阴阳→比肩，异阴阳→劫财
   *   我生（日干生对方）：同阴阳→食神，异阴阳→伤官
   *   我克（日干克对方）：同阴阳→偏财，异阴阳→正财
   *   克我（对方克日干）：同阴阳→七杀，异阴阳→正官
   *   生我（对方生日干）：同阴阳→偏印，异阴阳→正印
   */
  private static computeShiShen(riGan: TianGan, targetGan: TianGan): ShiShen {
    const riWx = BaziEngine.GAN_WUXING[riGan];
    const tgWx = BaziEngine.GAN_WUXING[targetGan];
    const riYy = BaziEngine.GAN_YINYANG[riGan];
    const tgYy = BaziEngine.GAN_YINYANG[targetGan];
    const same = riYy === tgYy;

    if (riWx === tgWx) return same ? '比肩' : '劫财';
    if (BaziEngine.SHENG[riWx] === tgWx) return same ? '食神' : '伤官';
    if (BaziEngine.KE[riWx] === tgWx) return same ? '偏财' : '正财';
    if (BaziEngine.KE[tgWx] === riWx) return same ? '七杀' : '正官';
    if (BaziEngine.SHENG[tgWx] === riWx) return same ? '偏印' : '正印';

    // 理论上不会到这里
    return '比肩';
  }

  /**
   * 十二长生表（《三命通会》·十二运论）
   * 按天干（阳干/阴干）查起始地支，顺/逆数12步
   *
   * 阳干（甲丙戊庚壬）：从长生顺数
   * 阴干（乙丁己辛癸）：从长生逆数
   *
   * 各阳干长生地支：甲→亥、丙→寅、戊→寅、庚→巳、壬→申
   * 各阴干（与同五行阳干反向）：乙→午、丁→酉、己→酉、辛→子、癸→卯
   */
  private static readonly CHANG_SHENG_ORDER: ShiErChangSheng[] = [
    '长生', '沐浴', '冠带', '临官', '帝旺',
    '衰', '病', '死', '墓', '绝', '胎', '养',
  ];

  /**
   * 阳干长生起始地支索引（0=子，顺序同 DI_ZHI 数组）
   * 甲→亥(11), 丙→寅(2), 戊→寅(2), 庚→巳(5), 壬→申(8)
   */
  private static readonly YANG_CHANG_SHENG_START: Partial<Record<TianGan, number>> = {
    甲: 11, 丙: 2, 戊: 2, 庚: 5, 壬: 8,
  };

  /**
   * 阴干长生起始地支索引（逆数）
   * 乙→午(6), 丁→酉(9), 己→酉(9), 辛→子(0), 癸→卯(3)
   */
  private static readonly YIN_CHANG_SHENG_START: Partial<Record<TianGan, number>> = {
    乙: 6, 丁: 9, 己: 9, 辛: 0, 癸: 3,
  };

  /**
   * 计算天干在某地支的十二长生状态
   * @param gan 天干
   * @param zhi 地支
   * @returns 十二长生状态
   */
  private static computeChangSheng(gan: TianGan, zhi: DiZhi): ShiErChangSheng {
    const isYang = BaziEngine.GAN_YINYANG[gan] === '阳';
    const zhiIdx = BaziEngine.DI_ZHI.indexOf(zhi);

    if (isYang) {
      const start = BaziEngine.YANG_CHANG_SHENG_START[gan];
      if (start === undefined) return '长生'; // fallback
      const step = ((zhiIdx - start) % 12 + 12) % 12;
      return BaziEngine.CHANG_SHENG_ORDER[step];
    } else {
      const start = BaziEngine.YIN_CHANG_SHENG_START[gan];
      if (start === undefined) return '长生'; // fallback
      const step = ((start - zhiIdx) % 12 + 12) % 12;
      return BaziEngine.CHANG_SHENG_ORDER[step];
    }
  }

  /**
   * 六甲空亡计算（《三命通会》·空亡论）
   *
   * 六十甲子分六旬，每旬10个干支，对应12地支剩余2支为空亡：
   *   甲子旬（甲子~癸酉）→ 空亡戌亥
   *   甲戌旬（甲戌~癸未）→ 空亡申酉
   *   甲申旬（甲申~癸巳）→ 空亡午未
   *   甲午旬（甲午~癸卯）→ 空亡辰巳
   *   甲辰旬（甲辰~癸丑）→ 空亡寅卯
   *   甲寅旬（甲寅~癸亥）→ 空亡子丑
   *
   * @param dayPillar 日柱干支
   * @returns 空亡的两个地支
   */
  static computeKongWang(dayPillar: GanZhi): DiZhi[] {
    const ganIdx = BaziEngine.TIAN_GAN.indexOf(dayPillar.gan);
    const zhiIdx = BaziEngine.DI_ZHI.indexOf(dayPillar.zhi);
    // 由天干/地支索引推算六十甲子序号
    // 解：sbVal ≡ ganIdx (mod 10), sbVal ≡ zhiIdx (mod 12)
    // k 满足 ganIdx + 10k ≡ zhiIdx (mod 12)
    const k = (((ganIdx - zhiIdx) / 2) % 6 + 6) % 6;
    const sbVal = ganIdx + 10 * k;
    const xunIndex = Math.floor(sbVal / 10); // 0=甲子旬 … 5=甲寅旬
    // 空亡地支：甲子旬空戌(10)亥(11)，每升一旬递减2
    const kongStart = (10 - xunIndex * 2 + 12) % 12;
    const kongEnd = (11 - xunIndex * 2 + 12) % 12;
    return [BaziEngine.DI_ZHI[kongStart], BaziEngine.DI_ZHI[kongEnd]];
  }

  /**
   * 天干五合表（《渊海子平》）
   * 甲己合→土，乙庚合→金，丙辛合→水，丁壬合→木，戊癸合→火
   */
  private static readonly GAN_HE: [TianGan, TianGan, WuXing][] = [
    ['甲', '己', '土'],
    ['乙', '庚', '金'],
    ['丙', '辛', '水'],
    ['丁', '壬', '木'],
    ['戊', '癸', '火'],
  ];

  /**
   * 天干相冲（间隔6位）
   * 甲庚、乙辛、丙壬、丁癸（戊己不冲）
   */
  private static readonly GAN_CHONG: [TianGan, TianGan][] = [
    ['甲', '庚'], ['乙', '辛'], ['丙', '壬'], ['丁', '癸'],
  ];

  /**
   * 地支六合（《三命通会》）
   * 子丑→土，寅亥→木，卯戌→火，辰酉→金，巳申→水，午未→土
   */
  private static readonly ZHI_LIU_HE: [DiZhi, DiZhi, WuXing][] = [
    ['子', '丑', '土'], ['寅', '亥', '木'], ['卯', '戌', '火'],
    ['辰', '酉', '金'], ['巳', '申', '水'], ['午', '未', '土'],
  ];

  /**
   * 地支三合（《渊海子平》）
   * 申子辰→水，寅午戌→火，巳酉丑→金，亥卯未→木
   */
  private static readonly ZHI_SAN_HE: [DiZhi, DiZhi, DiZhi, WuXing][] = [
    ['申', '子', '辰', '水'],
    ['寅', '午', '戌', '火'],
    ['巳', '酉', '丑', '金'],
    ['亥', '卯', '未', '木'],
  ];

  /**
   * 地支三会（方局，《三命通会》）
   * 寅卯辰→木，巳午未→火，申酉戌→金，亥子丑→水
   */
  private static readonly ZHI_SAN_HUI: [DiZhi, DiZhi, DiZhi, WuXing][] = [
    ['寅', '卯', '辰', '木'],
    ['巳', '午', '未', '火'],
    ['申', '酉', '戌', '金'],
    ['亥', '子', '丑', '水'],
  ];

  /**
   * 地支六冲（间隔6位，《渊海子平》）
   * 子午冲、丑未冲、寅申冲、卯酉冲、辰戌冲、巳亥冲
   */
  private static readonly ZHI_LIU_CHONG: [DiZhi, DiZhi][] = [
    ['子', '午'], ['丑', '未'], ['寅', '申'],
    ['卯', '酉'], ['辰', '戌'], ['巳', '亥'],
  ];

  /**
   * 地支六害（《三命通会》）
   * 子未、丑午、寅巳、卯辰、申亥、酉戌
   */
  private static readonly ZHI_LIU_HAI: [DiZhi, DiZhi][] = [
    ['子', '未'], ['丑', '午'], ['寅', '巳'],
    ['卯', '辰'], ['申', '亥'], ['酉', '戌'],
  ];

  /**
   * 地支六破（《三命通会》）
   * 子酉、午卯、巳申、寅亥、辰丑、戌未
   */
  private static readonly ZHI_LIU_PO: [DiZhi, DiZhi][] = [
    ['子', '酉'], ['午', '卯'], ['巳', '申'],
    ['寅', '亥'], ['辰', '丑'], ['戌', '未'],
  ];

  /**
   * 地支相刑（《渊海子平》）
   * 寅刑巳、巳刑申、申刑寅（三刑无恩）
   * 丑刑戌、戌刑未、未刑丑（三刑无礼）
   * 子刑卯、卯刑子（相刑无礼）
   * 辰午酉亥（自刑）
   */
  private static readonly ZHI_XING: [DiZhi, DiZhi][] = [
    ['寅', '巳'], ['巳', '申'], ['申', '寅'],
    ['丑', '戌'], ['戌', '未'], ['未', '丑'],
    ['子', '卯'], ['卯', '子'],
    ['辰', '辰'], ['午', '午'], ['酉', '酉'], ['亥', '亥'],
  ];

  /**
   * 日主性格描述（五行+阴阳，来源：《滴天髓》日元论）
   */
  private static readonly RI_ZHU_DESC: Record<TianGan, string> = {
    甲: '栋梁之木，正直进取，领导力强，理想主义',
    乙: '藤蔓之木，柔韧适应，善于合作，亲和力强',
    丙: '太阳之火，热情开朗，慷慨大方，领袖气质',
    丁: '烛火之火，细腻温和，执着专注，有艺术天赋',
    戊: '大山之土，稳重可靠，宽厚包容，务实踏实',
    己: '田园之土，温柔体贴，善于经营，注重细节',
    庚: '利剑之金，刚毅果断，行动力强，重情义',
    辛: '珠宝之金，精致优雅，自尊心强，追求完美',
    壬: '江海之水，智慧聪颖，包容万象，胸怀宽广',
    癸: '雨露之水，灵动敏锐，情感丰富，直觉力强',
  };

  // ═══════════════════════════════════════════
  // § 主计算入口
  // ═══════════════════════════════════════════

  /**
   * 排盘：计算完整八字命盘
   * @param birthDate 出生日期时间（公历，北京时间）
   * @param gender 性别
   * @param longitude 出生地经度（可选，传入则启用真太阳时校正）
   * @returns 完整命盘 MingPan
   */
  calculate(birthDate: Date, gender: '男' | '女', longitude?: number): MingPan {
    // ── 0. 真太阳时校正 ────────────────────
    let effectiveDate = birthDate;
    let trueSolarTimeDesc: string | undefined;
    if (longitude !== undefined) {
      const info = getTrueSolarTimeInfo(birthDate, longitude);
      effectiveDate = info.trueSolarTime;
      trueSolarTimeDesc = info.description;
    }

    if (gender !== '男' && gender !== '女') throw new RangeError('排运性别须为男或女');
    const pillarNames = getCalendarPillars(birthDate, { solarTime: effectiveDate });
    const c8ex = { year: this.toPillar(pillarNames.year), month: this.toPillar(pillarNames.month), day: this.toPillar(pillarNames.day), hour: this.toPillar(pillarNames.hour) };
    const lunar = toSolar(birthDate).getLunar();

    // ── 1. 获取四柱原始数据 ──────────────────
    const yearPillar = c8ex.year;
    const monthPillar = c8ex.month;
    const dayPillar = c8ex.day;
    const hourPillar = c8ex.hour;

    const riGan = dayPillar.stem.name as TianGan;

    // ── 2. 构建 GanZhi（含纳音）──────────────
    const yearGanZhi = this.buildGanZhi(yearPillar.stem.name, yearPillar.branch.name, yearPillar);
    const monthGanZhi = this.buildGanZhi(monthPillar.stem.name, monthPillar.branch.name, monthPillar);
    const dayGanZhi = this.buildGanZhi(dayPillar.stem.name, dayPillar.branch.name, dayPillar);
    const hourGanZhi = this.buildGanZhi(hourPillar.stem.name, hourPillar.branch.name, hourPillar);

    // ── 3. 构建藏干 ──────────────────────────
    const yearCang = this.buildCangGan(yearPillar.branch.name as DiZhi, riGan);
    const monthCang = this.buildCangGan(monthPillar.branch.name as DiZhi, riGan);
    const dayCang = this.buildCangGan(dayPillar.branch.name as DiZhi, riGan);
    const hourCang = this.buildCangGan(hourPillar.branch.name as DiZhi, riGan);

    // ── 4. 十神（天干相对日主）───────────────
    const yearSS = BaziEngine.computeShiShen(riGan, yearPillar.stem.name as TianGan);
    const monthSS = BaziEngine.computeShiShen(riGan, monthPillar.stem.name as TianGan);
    const daySS: ShiShen = '比肩'; // 日主自身
    const hourSS = BaziEngine.computeShiShen(riGan, hourPillar.stem.name as TianGan);

    // ── 5. 十二长生 ───────────────────────────
    const yearCS = BaziEngine.computeChangSheng(riGan, yearPillar.branch.name as DiZhi);
    const monthCS = BaziEngine.computeChangSheng(riGan, monthPillar.branch.name as DiZhi);
    const dayCS = BaziEngine.computeChangSheng(riGan, dayPillar.branch.name as DiZhi);
    const hourCS = BaziEngine.computeChangSheng(riGan, hourPillar.branch.name as DiZhi);

    // ── 6. 组装四柱 ───────────────────────────
    const siZhu: SiZhu = {
      year: { ganZhi: yearGanZhi, shiShen: yearSS, cangGan: yearCang, changSheng: yearCS },
      month: { ganZhi: monthGanZhi, shiShen: monthSS, cangGan: monthCang, changSheng: monthCS },
      day: { ganZhi: dayGanZhi, shiShen: daySS, cangGan: dayCang, changSheng: dayCS },
      hour: { ganZhi: hourGanZhi, shiShen: hourSS, cangGan: hourCang, changSheng: hourCS },
    };

    // ── 7. 五行力量 ───────────────────────────
    const wuXingStrength = this.computeWuXingStrength(siZhu, riGan, monthPillar.branch.name as DiZhi);

    // ── 8. 关系网络 ───────────────────────────
    const branches: DiZhi[] = [
      yearPillar.branch.name as DiZhi,
      monthPillar.branch.name as DiZhi,
      dayPillar.branch.name as DiZhi,
      hourPillar.branch.name as DiZhi,
    ];
    const stems: TianGan[] = [
      yearPillar.stem.name as TianGan,
      monthPillar.stem.name as TianGan,
      dayPillar.stem.name as TianGan,
      hourPillar.stem.name as TianGan,
    ];
    const branchRelations = this.computeBranchRelations(branches);
    const stemRelations = this.computeStemRelations(stems, monthPillar.branch.name as DiZhi);

    // ── 9. 格局 V2（《子平真诠》结构化判定）─────
    const riZhuStructure = computeRiZhuStructure(
      riGan,
      stems as [TianGan, TianGan, TianGan, TianGan],
      branches as [DiZhi, DiZhi, DiZhi, DiZhi],
    );
    const geJuV2 = computeGeJuV2(
      riGan,
      stems as [TianGan, TianGan, TianGan, TianGan],
      branches as [DiZhi, DiZhi, DiZhi, DiZhi],
      riZhuStructure,
    );
    // legacy geJu stub — populated from geJuV2; downstream reads geJuV2 directly
    const geJu: GeJu = {
      name:         geJuV2.name,
      category:     geJuV2.category === 'zhengge' ? '正格' : '特殊格',
      strength:     geJuV2.jibie === 'shang' ? '上' : geJuV2.jibie === 'zhong' ? '中' : '下',
      description:  geJuV2.name,
      modernMeaning: geJuV2.name,
    };

    // ── 10. 神煞（独立原局规则）───
    // Natal markers only: almanac day-selection gods are a different system.
    const shenSha = this.computeShenShaOwn(siZhu, riGan);

    // ── 10b. 空亡 ─────────────────────────────
    const kongWang = BaziEngine.computeKongWang(dayGanZhi);

    // ── 11. 大运 ──────────────────────────────
    const { direction, startAge, daYunList, qiYun } = this.computeDaYun(birthDate, gender, riGan, pillarNames.month);

    // ── 12. 农历信息 ──────────────────────────
    const lunarDate = `${lunar.getYearInChinese()}年${lunar.getMonthInChinese()}月${lunar.getDayInChinese()}`;
    const solarTerm = currentSolarTermAt(birthDate);

    // ── 13. 胎元 & 命宫 ───────────────────────
    const taiYuan = this.sbToGanZhi(this.toPillar(lunar.getEightChar().getTaiYuan()));
    // Ming-gong uses the selected month/hour branches and exact Li-chun year stem.
    const monthIndex = (BaziEngine.DI_ZHI.indexOf(pillarNames.month[1] as DiZhi) + 10) % 12 + 1;
    const hourIndex = (BaziEngine.DI_ZHI.indexOf(pillarNames.hour[1] as DiZhi) + 10) % 12 + 1;
    const sum = monthIndex + hourIndex;
    const offset = (sum >= 14 ? 26 : 14) - sum;
    const mingGan = BaziEngine.TIAN_GAN[((BaziEngine.TIAN_GAN.indexOf(pillarNames.year[0] as TianGan) + 1) * 2 + offset - 1) % 10];
    const mingZhi = BaziEngine.DI_ZHI[(offset + 1) % 12];
    const mingGong = this.sbToGanZhi(this.toPillar(mingGan + mingZhi));

    return {
      birthDateTime: birthDate,
      gender,
      siZhu,
      riZhu: {
        gan: riGan,
        wuXing: BaziEngine.GAN_WUXING[riGan],
        yinYang: BaziEngine.GAN_YINYANG[riGan],
        description: BaziEngine.RI_ZHU_DESC[riGan],
      },
      wuXingStrength,
      tiaoHou: getTiaoHouReview(riGan, monthPillar.branch.name as DiZhi),
      riZhuStructure,
      branchRelations,
      stemRelations,
      shiShenRelations: computeShiShenRelations(riGan, stems),
      geJu,
      geJuV2,
      kongWang,
      trueSolarTimeDesc,
      shenSha,
      daYunDirection: direction,
      daYunStartAge: startAge,
      daYunList,
      qiYun,
      calculationPolicy: { ...CALENDAR_POLICY, civilBirthTime: birthDate.toISOString(), effectiveSolarTime: effectiveDate.toISOString(), solarTimeApplied: longitude !== undefined, ...(longitude !== undefined ? { longitude } : {}), warnings: lunarCalendarWarnings(birthDate) },
      interpretationPolicy: { strengthYongShen: '扶抑参考（工程启发式，调候另列来源候选）', structureYongShen: '月令格局用神（子平真诠口径）', status: 'traditional-interpretation-not-empirical-prediction' },
      lunarDate,
      solarTerm,
      yearNaYin: yearGanZhi.naYin,
      taiYuan,
      mingGong,
    };
  }

  // ═══════════════════════════════════════════
  // § 内部辅助方法
  // ═══════════════════════════════════════════

  /**
   * 从内部柱适配对象构建 GanZhi 结构
   * 纳音通过 takeSound 插件的 pillar.takeSound 获取
   */
  private buildGanZhi(
    ganName: string,
    zhiName: string,
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    pillar: any,
  ): GanZhi {
    const gan = ganName as TianGan;
    const zhi = zhiName as DiZhi;
    const naYin = (pillar.takeSound as string | undefined) ?? '';
    const naYinWx = this.naYinToWuXing(naYin);
    return {
      gan,
      zhi,
      ganWuXing: BaziEngine.GAN_WUXING[gan],
      zhiWuXing: BaziEngine.ZHI_WUXING[zhi],
      ganYinYang: BaziEngine.GAN_YINYANG[gan],
      zhiYinYang: BaziEngine.ZHI_YINYANG[zhi],
      naYin,
      naYinWuXing: naYinWx,
    };
  }

  /**
   * 将内部干支适配对象转换为 GanZhi（用于胎元/命宫）
   */
  private sbToGanZhi(sb: ReturnType<BaziEngine['toPillar']>): GanZhi {
    const gan = sb.stem.name as TianGan;
    const zhi = sb.branch.name as DiZhi;
    const naYin = (sb as unknown as { takeSound?: string }).takeSound ?? '';
    return {
      gan,
      zhi,
      ganWuXing: BaziEngine.GAN_WUXING[gan],
      zhiWuXing: BaziEngine.ZHI_WUXING[zhi],
      ganYinYang: BaziEngine.GAN_YINYANG[gan],
      zhiYinYang: BaziEngine.ZHI_YINYANG[zhi],
      naYin,
      naYinWuXing: this.naYinToWuXing(naYin),
    };
  }

  /**
   * 纳音名称解析为五行
   * 常见纳音后缀：海中金/大林木/炉中火/大驿土/剑锋金/…
   * 来源：《三命通会》纳音五行表
   */
  private naYinToWuXing(naYin: string): WuXing {
    if (!naYin) return '土';
    if (naYin.endsWith('金')) return '金';
    if (naYin.endsWith('木')) return '木';
    if (naYin.endsWith('水')) return '水';
    if (naYin.endsWith('火')) return '火';
    if (naYin.endsWith('土')) return '土';
    // 特殊：大林木→木，路旁土→土 等
    const wxMap: Record<string, WuXing> = {
      '大林': '木', '松柏': '木', '平地': '木', '天上': '火',
      '壁上': '土', '路旁': '土', '城头': '土', '沙中': '金',
      '山头': '火', '涧下': '水', '大海': '水', '天河': '水',
    };
    for (const [key, wx] of Object.entries(wxMap)) {
      if (naYin.includes(key)) return wx;
    }
    return '土';
  }

  /**
   * 构建地支藏干列表，包含十神信息
   * @param zhi 地支
   * @param riGan 日主天干
   */
  private buildCangGan(zhi: DiZhi, riGan: TianGan): CangGanItem[] {
    return BaziEngine.CANG_GAN[zhi].map(({ gan, weight }) => ({
      gan,
      wuXing: BaziEngine.GAN_WUXING[gan],
      shiShen: BaziEngine.computeShiShen(riGan, gan),
      weight,
    }));
  }

  /**
   * 工程计数近似，不是古籍给定的权重或已验证强弱算法。
   * 计算五行强弱（保留 yongShen/xiShen/jiShen/riZhuStrong/strongest/weakest 语义字段）
   * balance 仅作内部变量用于 strongest/weakest 推导，不对外暴露。
   */
  private computeWuXingStrength(
    siZhu: SiZhu,
    riGan: TianGan,
    monthZhi: DiZhi,
  ): WuXingStrength {
    type BalanceKey = 'jin' | 'mu' | 'shui' | 'huo' | 'tu';
    const balance: Record<BalanceKey, number> = { jin: 0, mu: 0, shui: 0, huo: 0, tu: 0 };
    const wxToKey = (wx: WuXing): BalanceKey => ({ 金: 'jin', 木: 'mu', 水: 'shui', 火: 'huo', 土: 'tu' }[wx] as BalanceKey);
    const keyToWx = (k: BalanceKey): WuXing => ({ jin: '金', mu: '木', shui: '水', huo: '火', tu: '土' }[k] as WuXing);

    const addWx = (wx: WuXing, amt: number) => { balance[wxToKey(wx)] += amt; };

    // 四天干各计 1
    for (const zhu of [siZhu.year, siZhu.month, siZhu.day, siZhu.hour]) {
      addWx(zhu.ganZhi.ganWuXing, 1);
    }
    // 四地支藏干按藏干权重
    for (const zhu of Object.values(siZhu) as ZhuDetail[]) {
      for (const cg of zhu.cangGan) {
        addWx(cg.wuXing, cg.weight);
      }
    }

    const riWx = BaziEngine.GAN_WUXING[riGan];
    const helpForce = [riWx, BaziEngine.reverseSheng(riWx)].reduce((s, wx) => s + balance[wxToKey(wx)], 0);
    const weakenForce = [BaziEngine.SHENG[riWx], BaziEngine.KE[riWx], BaziEngine.getKeMe(riWx)]
      .reduce((s, wx) => s + balance[wxToKey(wx)], 0);
    // helpForce already contains the day-master element: never count it twice.
    const riZhuStrong = helpForce >= weakenForce;

    // Legacy display fields retain a named FUYI heuristic only. The unreviewed
    // 120-cell tiaohou table must never silently decide these values. Source-linked
    // conditional tiaohou candidates are returned separately as MingPan.tiaoHou.
    let yongShen: WuXing;
    let xiShen: WuXing;
    let jiShen: WuXing;
    if (riZhuStrong) {
      yongShen = BaziEngine.getKeMe(riWx);
      xiShen = BaziEngine.KE[riWx];
      jiShen = riWx;
    } else {
      yongShen = BaziEngine.reverseSheng(riWx);
      xiShen = riWx;
      jiShen = BaziEngine.getKeMe(riWx);
    }

    const entries = Object.entries(balance) as [BalanceKey, number][];
    const strongest = keyToWx(entries.reduce((a, b) => (b[1] > a[1] ? b : a))[0]);
    const weakest   = keyToWx(entries.reduce((a, b) => (b[1] < a[1] ? b : a))[0]);

    return { strongest, weakest, riZhuStrong, yongShen, xiShen, jiShen, suggestionBasis: 'fuyi-heuristic', suggestionStatus: 'not-empirically-validated', tiaohouApplied: false };
  }

  /** 反向相生：找生我者（如木被水生，reverseSheng(木)=水） */
  private static reverseSheng(wx: WuXing): WuXing {
    for (const [k, v] of Object.entries(BaziEngine.SHENG) as [WuXing, WuXing][]) {
      if (v === wx) return k;
    }
    return wx;
  }

  /** 找克我者（如金克木，getKeMe(木)=金） */
  private static getKeMe(wx: WuXing): WuXing {
    for (const [k, v] of Object.entries(BaziEngine.KE) as [WuXing, WuXing][]) {
      if (v === wx) return k;
    }
    return wx;
  }

  // ─────────────────────────────────────────
  // § 地支关系计算（《三命通会》干支关系论）
  // ─────────────────────────────────────────

  /**
   * 计算四柱地支之间的所有关系
   */
  private computeBranchRelations(branches: DiZhi[]): BranchRelation[] {
    const relations: BranchRelation[] = [];
    const labels = ['年支', '月支', '日支', '时支'];

    // 六合（两两）
    for (const [a, b, result] of BaziEngine.ZHI_LIU_HE) {
      const positions: string[] = [];
      branches.forEach((br, i) => {
        if (br === a || br === b) {
          branches.forEach((br2, j) => {
            if (j > i && ((br === a && br2 === b) || (br === b && br2 === a))) {
              positions.push(`${labels[i]}-${labels[j]}`);
            }
          });
        }
      });
      if (positions.length) relations.push({ type: '六合', branches: [a, b], result, positions,
        requiredBranches: [a, b], missingBranches: [], completeness: 'complete', outcomeEstablished: false });
    }

    // 三合（三支）
    for (const [x, y, z, result] of BaziEngine.ZHI_SAN_HE) {
      const present = [x, y, z].filter(b => branches.includes(b));
      if (present.length >= 2) {
        const positions = present.map(b => labels[branches.indexOf(b)]);
        const complete = present.length === 3;
        relations.push({ type: complete ? '三合' : present.includes(y) ? '半合候选' : '拱合候选',
          branches: present, result, positions, requiredBranches: [x, y, z],
          missingBranches: [x, y, z].filter(b => !present.includes(b)),
          completeness: complete ? 'complete' : 'partial', outcomeEstablished: false });
      }
    }

    // 三会（三支）
    for (const [x, y, z, result] of BaziEngine.ZHI_SAN_HUI) {
      const present = [x, y, z].filter(b => branches.includes(b));
      if (present.length >= 2) {
        const positions = present.map(b => labels[branches.indexOf(b)]);
        const complete = present.length === 3;
        relations.push({ type: complete ? '三会' : '三会候选', branches: present, result, positions,
          requiredBranches: [x, y, z], missingBranches: [x, y, z].filter(b => !present.includes(b)),
          completeness: complete ? 'complete' : 'partial', outcomeEstablished: false });
      }
    }

    // 六冲
    this.addPairRelations(branches, labels, BaziEngine.ZHI_LIU_CHONG, '六冲', relations, undefined);

    // 六害
    this.addPairRelations(branches, labels, BaziEngine.ZHI_LIU_HAI, '六害', relations, undefined);

    // 六破
    this.addPairRelations(branches, labels, BaziEngine.ZHI_LIU_PO, '六破', relations, undefined);

    // 相刑
    this.addPairRelations(branches, labels, BaziEngine.ZHI_XING, '相刑', relations, undefined);

    return relations;
  }

  private addPairRelations(
    branches: DiZhi[],
    labels: string[],
    table: [DiZhi, DiZhi][],
    type: BranchRelation['type'],
    out: BranchRelation[],
    result: WuXing | undefined,
  ) {
    for (const [a, b] of table) {
      const positions: string[] = [];
      branches.forEach((br, i) => {
        branches.forEach((br2, j) => {
          if (j > i && ((br === a && br2 === b) || (br === b && br2 === a))) {
            positions.push(`${labels[i]}-${labels[j]}`);
          }
        });
      });
      if (positions.length) {
        out.push({ type, branches: [a, b], result, positions });
      }
    }
  }

  // ─────────────────────────────────────────
  // § 天干关系计算
  // ─────────────────────────────────────────

  /**
   * 计算四柱天干之间的关系（五合、相冲）
   */
  private computeStemRelations(stems: TianGan[], monthZhi: DiZhi): StemRelation[] {
    const relations: StemRelation[] = [];
    const labels = ['年干', '月干', '日干', '时干'];

    // Five-combination identities and position-aware candidate conditions.
    for (const [a, b, huaWx] of BaziEngine.GAN_HE) {
      const positions: string[] = [];
      const combinationAssessments: ReturnType<typeof assessStemCombination>[] = [];
      stems.forEach((s, i) => {
        stems.forEach((s2, j) => {
          if (j > i && ((s === a && s2 === b) || (s === b && s2 === a))) {
            positions.push(`${labels[i]}-${labels[j]}`);
            combinationAssessments.push(assessStemCombination(stems, monthZhi, i, j));
          }
        });
      });
      if (positions.length) {
        const heHuaDesc = `${a}${b}五合，传统化神方向为${huaWx}；成化未定。` +
          [...new Set(combinationAssessments.flatMap(item => item.reasons))].join('；');
        relations.push({ type: '天干五合', stems: [a, b], result: huaWx, positions, heHuaDesc, combinationAssessments });
      }
    }

    // 天干相冲
    for (const [a, b] of BaziEngine.GAN_CHONG) {
      const positions: string[] = [];
      stems.forEach((s, i) => {
        stems.forEach((s2, j) => {
          if (j > i && ((s === a && s2 === b) || (s === b && s2 === a))) {
            positions.push(`${labels[i]}-${labels[j]}`);
          }
        });
      });
      if (positions.length) {
        relations.push({ type: '天干相冲', stems: [a, b], positions });
      }
    }

    return relations;
  }

  // ─────────────────────────────────────────
  // § 自建神煞推算（《三命通会》·神煞论）
  // 不依赖任何插件，纯查表推算
  // ─────────────────────────────────────────

  /**
   * 自建神煞推算系统（《三命通会》·《渊海子平》神煞论）
   *
   * 涵盖18种常见神煞，以日干、日支、年支、月支为基准推算。
   * 相比插件，本方法提供更丰富的白话描述与现代解读。
   */
  private computeShenShaOwn(siZhu: SiZhu, riGan: TianGan): ShenSha[] {
    const result: ShenSha[] = [];

    const yearGan = siZhu.year.ganZhi.gan;
    const monthGan = siZhu.month.ganZhi.gan;
    const dayGan = siZhu.day.ganZhi.gan;
    const hourGan = siZhu.hour.ganZhi.gan;

    const yearZhi = siZhu.year.ganZhi.zhi;
    const monthZhi = siZhu.month.ganZhi.zhi;
    const dayZhi = siZhu.day.ganZhi.zhi;
    const hourZhi = siZhu.hour.ganZhi.zhi;

    const pillarGans: [TianGan, string][] = [
      [yearGan, '年柱'], [monthGan, '月柱'], [dayGan, '日柱'], [hourGan, '时柱'],
    ];
    const pillarZhis: [DiZhi, string][] = [
      [yearZhi, '年柱'], [monthZhi, '月柱'], [dayZhi, '日柱'], [hourZhi, '时柱'],
    ];

    /** 在四柱地支中查目标支，每命中一次记录一条 */
    const checkZhis = (
      targets: DiZhi[],
      name: string,
      type: ShenSha['type'],
      description: string,
      modernMeaning: string,
    ) => {
      for (const [zhi, pos] of pillarZhis) {
        if (targets.includes(zhi)) {
          result.push({ name, type, position: pos, description, modernMeaning });
        }
      }
    };

    /** 在四柱天干中查目标干，每命中一次记录一条 */
    const checkGans = (
      targets: TianGan[],
      name: string,
      type: ShenSha['type'],
      description: string,
      modernMeaning: string,
    ) => {
      for (const [gan, pos] of pillarGans) {
        if (targets.includes(gan)) {
          result.push({ name, type, position: pos, description, modernMeaning });
        }
      }
    };

    // ─── 1. 天乙贵人（以日干查各柱地支）────────────
    // 来源：《渊海子平》·天乙贵人篇
    const TIAN_YI: Record<TianGan, DiZhi[]> = {
      甲: ['丑', '未'], 乙: ['子', '申'],
      丙: ['亥', '酉'], 丁: ['亥', '酉'],
      戊: ['丑', '未'], 己: ['子', '申'],
      庚: ['丑', '未'], 辛: ['午', '寅'],
      壬: ['卯', '巳'], 癸: ['卯', '巳'],
    };
    checkZhis(TIAN_YI[riGan], '天乙贵人', '吉',
      '四柱最吉之神，逢凶化吉，一生多得贵人援手，化险为夷，运势平稳',
      '你天生具有吸引贵人的气场，困难时刻往往有人在关键节点伸出援手');

    // ─── 2. 文昌贵人（以日干查各柱地支）────────────
    // 来源：《三命通会》·文昌贵人论
    const WEN_CHANG: Record<TianGan, DiZhi> = {
      甲: '巳', 乙: '午', 丙: '申', 丁: '酉',
      戊: '申', 己: '酉', 庚: '亥', 辛: '子', 壬: '寅', 癸: '卯',
    };
    checkZhis([WEN_CHANG[riGan]], '文昌贵人', '吉',
      '主聪明才智，文采出众，学业有成，利于考试升学与文职工作',
      '你有出色的学习和表达能力，语言文字是你的天赋领域');

    // ─── 3. 天德贵人（以月支确定，查四柱干支）──────
    // 来源：《三命通会》·天德贵人
    // 偶数月（二、五、八、十一月）天德为地支；奇数月为天干
    const TIAN_DE_GAN: Partial<Record<DiZhi, TianGan>> = {
      寅: '丁', 辰: '壬', 巳: '辛', 未: '甲',
      申: '癸', 戌: '丙', 亥: '乙', 丑: '庚',
    };
    const TIAN_DE_ZHI: Partial<Record<DiZhi, DiZhi>> = {
      卯: '申', 午: '亥', 酉: '寅', 子: '巳',
    };
    const tiande_gan = TIAN_DE_GAN[monthZhi];
    if (tiande_gan) {
      checkGans([tiande_gan], '天德贵人', '吉',
        '月令天德，一生逢凶化吉，得天地庇佑，遇难呈祥，官司不侵',
        '你有一种化解危机的天赋，困境中往往能找到转机');
    }
    const tiande_zhi = TIAN_DE_ZHI[monthZhi];
    if (tiande_zhi) {
      checkZhis([tiande_zhi], '天德贵人', '吉',
        '月令天德，一生逢凶化吉，得天地庇佑，遇难呈祥，官司不侵',
        '你有一种化解危机的天赋，困境中往往能找到转机');
    }

    // ─── 4. 月德贵人（以月支所属三合查四柱天干）────
    // 来源：《三命通会》·月德贵人
    const YUE_DE_MAP: Record<DiZhi, TianGan> = {
      寅: '丙', 午: '丙', 戌: '丙',
      申: '壬', 子: '壬', 辰: '壬',
      亥: '甲', 卯: '甲', 未: '甲',
      巳: '庚', 酉: '庚', 丑: '庚',
    };
    const yueDe = YUE_DE_MAP[monthZhi];
    if (yueDe) {
      checkGans([yueDe], '月德贵人', '吉',
        '月令月德，天赋仁德之性，心善积福，官非不侵，有贵人护持',
        '你有温润的人格魅力，善举往往能转化为自身的好运');
    }

    // ─── 5. 桃花（咸池，以日支三合组查各柱地支）────
    // 来源：《渊海子平》·桃花论
    const TAO_HUA_MAP: Record<DiZhi, DiZhi> = {
      寅: '卯', 午: '卯', 戌: '卯',
      申: '酉', 子: '酉', 辰: '酉',
      巳: '午', 酉: '午', 丑: '午',
      亥: '子', 卯: '子', 未: '子',
    };
    const taoHua = TAO_HUA_MAP[dayZhi];
    if (taoHua) {
      checkZhis([taoHua], '桃花', '中性',
        '桃花贵人，魅力十足，人缘出众，感情丰富；需防感情泛滥或桃花劫',
        '你天生有吸引人的气质，社交能力强，感情生活容易丰富多彩');
    }

    // ─── 6. 驿马（以日支三合组查各柱地支）──────────
    // 来源：《三命通会》·驿马论
    const YI_MA_MAP: Record<DiZhi, DiZhi> = {
      寅: '申', 午: '申', 戌: '申',
      申: '寅', 子: '寅', 辰: '寅',
      巳: '亥', 酉: '亥', 丑: '亥',
      亥: '巳', 卯: '巳', 未: '巳',
    };
    const yiMa = YI_MA_MAP[dayZhi];
    if (yiMa) {
      checkZhis([yiMa], '驿马', '中性',
        '主变动迁移，奔波忙碌，适合出差行旅与异地发展；逢合则受羁绊',
        '你适合在流动变化中寻找机会，外出闯荡比守株待兔更有收获');
    }

    // ─── 7. 华盖（以日支三合组查各柱地支）──────────
    // 来源：《三命通会》·华盖论
    const HUA_GAI_MAP: Record<DiZhi, DiZhi> = {
      寅: '戌', 午: '戌', 戌: '戌',
      申: '辰', 子: '辰', 辰: '辰',
      巳: '丑', 酉: '丑', 丑: '丑',
      亥: '未', 卯: '未', 未: '未',
    };
    const huaGai = HUA_GAI_MAP[dayZhi];
    if (huaGai) {
      checkZhis([huaGai], '华盖', '中性',
        '主孤独清高，有宗教信仰或艺术哲学天赋，喜独处，精神世界丰富',
        '你有强烈的精神追求，独处时往往能激发最深刻的灵感与创造力');
    }

    // ─── 8. 将星（以日支三合组查各柱地支）──────────
    // 来源：《三命通会》·将星论
    const JIANG_XING_MAP: Record<DiZhi, DiZhi> = {
      寅: '午', 午: '午', 戌: '午',
      申: '子', 子: '子', 辰: '子',
      巳: '酉', 酉: '酉', 丑: '酉',
      亥: '卯', 卯: '卯', 未: '卯',
    };
    const jiangXing = JIANG_XING_MAP[dayZhi];
    if (jiangXing) {
      checkZhis([jiangXing], '将星', '吉',
        '将帅之星，主权威与领导力，统率四方，适合担任要职或团队领袖',
        '你天生有领导气质，团队中往往自然成为核心与决策人物');
    }

    // ─── 9. 亡神（以日支三合组查各柱地支）──────────
    // 来源：《三命通会》·亡神论
    const WANG_SHEN_MAP: Record<DiZhi, DiZhi> = {
      寅: '巳', 午: '巳', 戌: '巳',
      申: '亥', 子: '亥', 辰: '亥',
      巳: '申', 酉: '申', 丑: '申',
      亥: '寅', 卯: '寅', 未: '寅',
    };
    const wangShen = WANG_SHEN_MAP[dayZhi];
    if (wangShen) {
      checkZhis([wangShen], '亡神', '凶',
        '传统神煞，归入"内耗"一类标签，常用于财务谨慎与契约核查的提醒；现代解读不作具体结论',
        '注意资产安全，避免冲动消费或高风险投资决策');
    }

    // ─── 10. 羊刃（以日干查各柱地支）────────────────
    // 来源：《渊海子平》·羊刃论
    const YANG_REN: Record<TianGan, DiZhi> = {
      甲: '卯', 乙: '寅', 丙: '午', 丁: '巳',
      戊: '午', 己: '巳', 庚: '酉', 辛: '申', 壬: '子', 癸: '亥',
    };
    checkZhis([YANG_REN[riGan]], '羊刃', '中性',
      '主果断魄力，行动力强，但锋芒毕露易引争端；善用则护身，失控则伤身',
      '你行动果断，执行力强，注意将魄力用在正确方向，避免无谓争斗');

    // ─── 11. 禄神（以日干查各柱地支）────────────────
    // 来源：《渊海子平》·禄神论
    const LU_SHEN: Record<TianGan, DiZhi> = {
      甲: '寅', 乙: '卯', 丙: '巳', 丁: '午',
      戊: '巳', 己: '午', 庚: '申', 辛: '酉', 壬: '亥', 癸: '子',
    };
    checkZhis([LU_SHEN[riGan]], '禄神', '吉',
      '禄星临命，衣食无忧，仕途顺畅，职业稳定，财运平稳有保障',
      '你有稳定的谋生能力，职场中自然能找到立足之地');

    // ─── 12. 太极贵人（以年支查各柱地支）────────────
    // 来源：《三命通会》·太极贵人
    const TAI_JI_MAP: Record<DiZhi, DiZhi[]> = {
      子: ['卯', '酉'], 午: ['卯', '酉'],
      寅: ['子', '午'], 申: ['子', '午'],
      辰: ['丑', '未'], 戌: ['丑', '未'],
      巳: ['寅', '申'], 亥: ['寅', '申'],
      丑: ['辰', '戌'], 未: ['辰', '戌'],
      卯: ['巳', '亥'], 酉: ['巳', '亥'],
    };
    const taiJiZhis = TAI_JI_MAP[yearZhi] ?? [];
    checkZhis(taiJiZhis, '太极贵人', '吉',
      '主智慧超群，思维灵活，善从宏观视角把握局势，有化腐朽为神奇之能',
      '你具有超凡的洞察力，能看穿事物本质，在复杂局面中找到最优解');

    // ─── 13. 金舆（日干之禄前两位地支）──────────────
    // 来源：《三命通会》·金舆论
    const JIN_YU: Record<TianGan, DiZhi> = {
      甲: '辰', 乙: '巳', 丙: '未', 丁: '申',
      戊: '未', 己: '申', 庚: '戌', 辛: '亥', 壬: '丑', 癸: '寅',
    };
    checkZhis([JIN_YU[riGan]], '金舆', '吉',
      '主富贵荣华，出行有车马之利，财运丰厚，生活优越，易得配偶助力',
      '你有享受优质生活的运势，伴侣往往能给你带来实质帮助');

    // ─── 14. 魁罡（特定日柱组合）────────────────────
    // 来源：《渊海子平》·魁罡格
    const KUIGANG_DAYS: [TianGan, DiZhi][] = [
      ['壬', '辰'], ['庚', '辰'], ['庚', '戌'], ['戊', '戌'],
    ];
    for (const [g, z] of KUIGANG_DAYS) {
      if (dayGan === g && dayZhi === z) {
        result.push({
          name: '魁罡',
          type: '中性',
          position: '日柱',
          description: '魁罡日主，性格刚强果断，才华横溢，性情峻烈，人生起伏较大',
          modernMeaning: '你有极强的个人意志和才华，适合在高压环境中独当一面',
        });
      }
    }

    // ─── 15. 红鸾（以年支逆数推，查各柱地支）────────
    // 来源：《三命通会》·红鸾天喜
    const HONG_LUAN_MAP: Record<DiZhi, DiZhi> = {
      子: '卯', 丑: '寅', 寅: '丑', 卯: '子',
      辰: '亥', 巳: '戌', 午: '酉', 未: '申',
      申: '未', 酉: '午', 戌: '巳', 亥: '辰',
    };
    const hongLuan = HONG_LUAN_MAP[yearZhi];
    if (hongLuan) {
      checkZhis([hongLuan], '红鸾', '吉',
        '婚姻感情之星，主感情顺遂，婚缘美满，易逢喜庆之事',
        '你的感情生活容易获得美好结果，婚姻运势较为顺遂');
    }

    // ─── 16. 天喜（红鸾对冲支，以年支查各柱地支）────
    // 来源：《三命通会》·红鸾天喜
    const TIAN_XI_MAP: Record<DiZhi, DiZhi> = {
      子: '酉', 丑: '申', 寅: '未', 卯: '午',
      辰: '巳', 巳: '辰', 午: '卯', 未: '寅',
      申: '丑', 酉: '子', 戌: '亥', 亥: '戌',
    };
    const tianXi = TIAN_XI_MAP[yearZhi];
    if (tianXi) {
      checkZhis([tianXi], '天喜', '吉',
        '喜庆之星，主逢事多喜，婚嫁、生育、升迁等喜事接踵而来',
        '你容易在生命中遇到各种值得庆祝的好事，正向能量充足');
    }

    // ─── 17. 劫煞（以日支三合组查各柱地支）──────────
    // 来源：《三命通会》·劫煞论
    const JIE_SHA_MAP: Record<DiZhi, DiZhi> = {
      寅: '亥', 午: '亥', 戌: '亥',
      申: '巳', 子: '巳', 辰: '巳',
      巳: '寅', 酉: '寅', 丑: '寅',
      亥: '申', 卯: '申', 未: '申',
    };
    const jieSha = JIE_SHA_MAP[dayZhi];
    if (jieSha) {
      checkZhis([jieSha], '劫煞', '凶',
        '传统神煞，归入"外耗"一类标签，常用于合作识人与签约细节的提醒；现代解读不作具体结论',
        '注意识别身边不可靠之人，合作时务必谨慎签约核查');
    }

    // ─── 18. 灾煞（以日支三合组查各柱地支）──────────
    // 来源：《三命通会》·灾煞论
    const ZAI_SHA_MAP: Record<DiZhi, DiZhi> = {
      寅: '子', 午: '子', 戌: '子',
      申: '午', 子: '午', 辰: '午',
      巳: '卯', 酉: '卯', 丑: '卯',
      亥: '酉', 卯: '酉', 未: '酉',
    };
    const zaiSha = ZAI_SHA_MAP[dayZhi];
    if (zaiSha) {
      checkZhis([zaiSha], '灾煞', '凶',
        '传统神煞，归入"突发/风险提醒"一类标签，常用于出行与高风险情境的关注；现代解读不作具体结论',
        '提高安全意识，在高风险情境下保持多一份谨慎');
    }

    return result;
  }

  // ─────────────────────────────────────────
  // § 大运计算（《渊海子平》·大运论）
  // ─────────────────────────────────────────

  /** Adapt the pinned MIT library's Ganzhi values; no library-specific objects escape. */
  private toPillar(ganzhi: string) {
    return { stem: { name: ganzhi[0] }, branch: { name: ganzhi[1] }, value: sexagenaryIndex(ganzhi), takeSound: naYinFor(ganzhi) };
  }

  /** 年干阴阳定顺逆；实际交节时间差按三日一年，分钟折算法（sect 2）。 */
  private computeDaYun(birthDate: Date, gender: '男' | '女', riGan: TianGan, monthGanzhi: string): {
    direction: DaYunDirection; startAge: number; daYunList: DaYun[]; qiYun: QiYunInfo;
  } {
    const lunar = toSolar(birthDate).getLunar();
    const eight = lunar.getEightChar();
    eight.setSect(1);
    const yun = eight.getYun(gender === '男' ? 1 : 0, 2);
    const isForward = yun.isForward();
    const term = isForward ? lunar.getNextJie(false) : lunar.getPrevJie(false);
    const startDate = fromSolar(yun.getStartSolar());
    const qiYun: QiYunInfo = {
      years: yun.getStartYear(), months: yun.getStartMonth(), days: yun.getStartDay(), hours: yun.getStartHour(),
      startDate: startDate.toISOString(), termDate: fromSolar(term.getSolar()).toISOString(), termName: term.getName(), sect: 2,
    };
    const startAge = qiYun.years;
    const first = beijingDateParts(startDate);
    const dateAt = (offset: number): string => {
      const year = first.year + offset;
      // Clamp Feb 29 anniversaries to Feb 28 in common years, never overflow into March.
      const lastDay = new Date(Date.UTC(year, first.month, 0)).getUTCDate();
      return fromBeijingParts(year, first.month, Math.min(first.day, lastDay), first.hour, first.minute, first.second).toISOString();
    };
    const monthIndex = sexagenaryIndex(monthGanzhi);
    const daYunList: DaYun[] = [];
    for (let i = 1; i <= 10; i++) {
      const value = (monthIndex + (isForward ? i : -i) + 60) % 60;
      const gan = BaziEngine.TIAN_GAN[value % 10];
      const zhi = BaziEngine.DI_ZHI[value % 12];
      const age = startAge + (i - 1) * 10;
      daYunList.push({ startAge: age, endAge: age + 9, startDate: dateAt((i - 1) * 10), endDate: dateAt(i * 10),
        ganZhi: this.sbToGanZhi(this.toPillar(gan + zhi)), shiShen: BaziEngine.computeShiShen(riGan, gan),
        zhiShiShen: BaziEngine.computeShiShen(riGan, BaziEngine.CANG_GAN[zhi][0].gan),
        period: `${age}–${age + 9}岁（整岁参考，以交运日期为准）` });
    }
    return { direction: isForward ? '顺行' : '逆行', startAge, daYunList, qiYun };
  }

  // ─────────────────────────────────────────
  // § 公共工具（供外部查询使用）
  // ─────────────────────────────────────────

  /**
   * 获取单个天干的五行
   */
  getGanWuXing(gan: TianGan): WuXing {
    return BaziEngine.GAN_WUXING[gan];
  }

  /**
   * 获取单个地支的藏干
   */
  getZhiCangGan(zhi: DiZhi): { gan: TianGan; weight: number }[] {
    return BaziEngine.CANG_GAN[zhi];
  }

  /**
   * 推算任意两干之间的十神关系
   */
  calcShiShen(riGan: TianGan, targetGan: TianGan): ShiShen {
    return BaziEngine.computeShiShen(riGan, targetGan);
  }
}
