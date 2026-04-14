/**
 * 岁吉 · 八字推算引擎
 *
 * 理论来源：
 * - 《渊海子平》（宋·徐子平）—— 四柱分析基本框架、十神体系、格局判定
 * - 《三命通会》（明·万民英）—— 神煞体系、纳音系统
 * - 《滴天髓》（宋·京图 / 明·刘伯温注）—— 日主强弱判断、用神取法
 * - 《穷通宝鉴》（清·余春台）—— 调候用神、季节性分析
 */

import lunisolar from 'lunisolar';
import { char8ex } from '@lunisolar/plugin-char8ex';
import { theGods } from '@lunisolar/plugin-thegods';
import { takeSound } from '@lunisolar/plugin-takesound';
import { fetalGod } from '@lunisolar/plugin-fetalgod';

import { toTrueSolarTime, getTrueSolarTimeInfo } from './TrueSolarTime';
import type {
  TianGan, DiZhi, WuXing, YinYang, ShiShen, ShiErChangSheng,
  GanZhi, SiZhu, ZhuDetail, CangGanItem,
  WuXingBalance, WuXingStrength,
  BranchRelation, StemRelation,
  GeJu, ShenSha, DaYun, DaYunDirection,
  MingPan,
} from './types';

// ─────────────────────────────────────────────
// 插件只注册一次（模块级别）
// ─────────────────────────────────────────────
let _pluginsRegistered = false;
function ensurePlugins() {
  if (_pluginsRegistered) return;
  lunisolar.extend(char8ex);
  lunisolar.extend(theGods);
  lunisolar.extend(takeSound);
  lunisolar.extend(fetalGod);
  _pluginsRegistered = true;
}

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
    const kongEnd   = (11 - xunIndex * 2 + 12) % 12;
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

  /**
   * 五行权重系数（用于五行力量计算）
   * 天干：1.0；地支本气：0.6；藏干按权重系数折算
   */
  private static readonly WX_WEIGHT = {
    GAN: 1.0,       // 天干本身
    ZHI_BASE: 0.6,  // 地支本气（通过藏干表）
  };

  /**
   * 调候用神表（《穷通宝鉴》·余春台）
   * 十天干在十二月令中的调候用神、喜神、忌神
   *
   * yong: 主要用神（第一位最重要）
   * xi:   喜神（辅助）
   * ji:   忌神（不利之干）
   */
  private static readonly TIAO_HOU_YONG_SHEN: Record<
    TianGan,
    Record<DiZhi, { yong: TianGan[]; xi: TianGan[]; ji: TianGan[]; desc: string }>
  > = {
    甲: {
      寅: { yong: ['丙', '癸'], xi: ['丙', '癸'], ji: ['庚', '辛'], desc: '初春寒木，丙火暖身，癸水润根' },
      卯: { yong: ['丙', '庚'], xi: ['丙', '庚'], ji: ['壬', '癸'], desc: '仲春木旺，丙火调候，庚金修剪' },
      辰: { yong: ['庚', '丙'], xi: ['庚', '丙'], ji: ['壬'],       desc: '土旺木弱，庚金劈甲引丁，丙火暖之' },
      巳: { yong: ['癸', '丁'], xi: ['癸'],       ji: ['丙'],       desc: '初夏炎热，癸水润根存根，忌丙火太旺' },
      午: { yong: ['癸', '庚'], xi: ['癸', '庚'], ji: ['丙', '丁'], desc: '仲夏炎燥，癸水滋润为急，庚金辅之' },
      未: { yong: ['癸', '丙'], xi: ['癸'],       ji: ['庚'],       desc: '未月燥土，癸水润土中木根' },
      申: { yong: ['丁', '丙'], xi: ['丁', '丙'], ji: ['壬'],       desc: '金旺克木，丁火制金，丙火暖身' },
      酉: { yong: ['丁', '丙'], xi: ['丁', '丙'], ji: ['壬', '癸'], desc: '秋金最旺，丁火制金为急，丙火辅之' },
      戌: { yong: ['庚', '丁'], xi: ['庚', '甲'], ji: ['壬'],       desc: '土旺木困，庚金劈甲引丁火' },
      亥: { yong: ['庚', '丙'], xi: ['庚', '丙'], ji: ['壬'],       desc: '亥月寒水，庚金劈甲，丙火暖身驱寒' },
      子: { yong: ['丙', '庚'], xi: ['丙', '庚'], ji: ['壬', '癸'], desc: '子月严寒，丙火暖木驱寒为急，庚金辅' },
      丑: { yong: ['丙', '庚'], xi: ['丙', '庚'], ji: ['癸'],       desc: '丑月冻土，丙火解冻，庚金修剪辅助' },
    },
    乙: {
      寅: { yong: ['丙', '癸'], xi: ['丙'],       ji: ['庚', '辛'], desc: '初春乙木，丙火调候，癸水滋养' },
      卯: { yong: ['丙', '癸'], xi: ['丙', '癸'], ji: ['庚', '辛'], desc: '卯月乙木最旺，丙火暖之，癸水润根' },
      辰: { yong: ['癸', '丙'], xi: ['癸', '丙'], ji: ['戊'],       desc: '辰月土盛，癸水润木，丙火暖身' },
      巳: { yong: ['癸', '丙'], xi: ['癸'],       ji: ['庚'],       desc: '巳月初夏，癸水解渴，丙火适量' },
      午: { yong: ['癸', '丙'], xi: ['癸'],       ji: ['丙'],       desc: '午月炎热，癸水为急，丙火忌过旺' },
      未: { yong: ['癸', '丙'], xi: ['癸'],       ji: ['己'],       desc: '未月燥土，癸水润土，丙火暖身' },
      申: { yong: ['丙', '癸'], xi: ['丙', '癸'], ji: ['庚'],       desc: '申月金旺，丙火制金，癸水滋根' },
      酉: { yong: ['丙', '癸'], xi: ['丙', '癸'], ji: ['辛'],       desc: '酉月金旺克木，丙癸并用' },
      戌: { yong: ['癸', '丙'], xi: ['癸', '甲'], ji: ['戊'],       desc: '戌月燥土，癸水润之，甲木为助' },
      亥: { yong: ['丙', '戊'], xi: ['丙'],       ji: ['壬'],       desc: '亥月寒水泛滥，丙火暖身，戊土制水' },
      子: { yong: ['丙', '戊'], xi: ['丙', '戊'], ji: ['癸', '壬'], desc: '子月严寒，丙火暖木，戊土培根' },
      丑: { yong: ['丙', '戊'], xi: ['丙'],       ji: ['癸'],       desc: '丑月严寒，丙火为急，戊土培根' },
    },
    丙: {
      寅: { yong: ['壬', '庚'], xi: ['壬'],       ji: ['己'],       desc: '春火渐旺，壬水既济调候' },
      卯: { yong: ['壬', '庚'], xi: ['壬'],       ji: ['己', '癸'], desc: '卯月木旺生火，壬水制火调候，庚金辅' },
      辰: { yong: ['壬', '甲'], xi: ['壬', '甲'], ji: ['戊'],       desc: '辰月土旺晦火，壬水调候，甲木引火' },
      巳: { yong: ['壬', '庚'], xi: ['壬'],       ji: ['己'],       desc: '巳月火旺，壬水为急既济' },
      午: { yong: ['壬', '庚'], xi: ['壬', '庚'], ji: ['己', '戊'], desc: '午月火极旺，壬水既济最急' },
      未: { yong: ['壬', '庚'], xi: ['壬'],       ji: ['己'],       desc: '未月火土旺，壬水调候，庚金引' },
      申: { yong: ['壬', '甲'], xi: ['壬', '甲'], ji: ['戊'],       desc: '申月金水旺，壬水调候，甲木生火' },
      酉: { yong: ['壬', '甲'], xi: ['壬', '甲'], ji: ['癸'],       desc: '酉月金旺，壬水调候，甲木助火' },
      戌: { yong: ['甲', '壬'], xi: ['甲', '壬'], ji: ['戊'],       desc: '戌月土旺晦火，甲木疏土，壬水调候' },
      亥: { yong: ['甲', '戊'], xi: ['甲'],       ji: ['壬'],       desc: '亥月水旺克火，甲木生火，戊土制水' },
      子: { yong: ['甲', '戊'], xi: ['甲'],       ji: ['癸'],       desc: '子月严寒，甲木引火，戊土制水' },
      丑: { yong: ['甲', '壬'], xi: ['甲', '戊'], ji: ['癸', '壬'], desc: '丑月寒冬，甲木生火为先，壬水调候' },
    },
    丁: {
      寅: { yong: ['甲', '庚'], xi: ['甲'],       ji: ['壬'],       desc: '寅月丁火，甲木引火，庚金锻炼' },
      卯: { yong: ['甲', '庚'], xi: ['甲'],       ji: ['壬', '癸'], desc: '卯月木旺，甲木引火，庚金为用' },
      辰: { yong: ['甲', '庚'], xi: ['甲', '庚'], ji: ['壬'],       desc: '辰月土旺，甲木疏土引火，庚金辅' },
      巳: { yong: ['甲', '庚'], xi: ['庚', '甲'], ji: ['壬'],       desc: '巳月火旺，庚金泄秀，甲木辅助' },
      午: { yong: ['壬', '庚'], xi: ['壬'],       ji: ['甲'],       desc: '午月火极旺，壬水调候，庚金泄秀' },
      未: { yong: ['甲', '壬'], xi: ['甲', '壬'], ji: ['庚'],       desc: '未月土旺，甲木疏土，壬水调候' },
      申: { yong: ['甲', '庚'], xi: ['甲'],       ji: ['壬'],       desc: '申月秋凉，甲木生火，庚金锻炼' },
      酉: { yong: ['甲', '庚'], xi: ['甲'],       ji: ['壬', '癸'], desc: '酉月金旺，甲木生火制金' },
      戌: { yong: ['甲', '壬'], xi: ['甲'],       ji: ['戊'],       desc: '戌月土旺，甲木疏土，壬水辅助' },
      亥: { yong: ['甲', '庚'], xi: ['甲'],       ji: ['壬'],       desc: '亥月寒水，甲木生火驱寒，庚金辅' },
      子: { yong: ['甲', '庚'], xi: ['甲'],       ji: ['壬', '癸'], desc: '子月严寒，甲木生火为急' },
      丑: { yong: ['甲', '庚'], xi: ['甲'],       ji: ['壬'],       desc: '丑月冻土，甲木生火，庚金疏木' },
    },
    戊: {
      寅: { yong: ['丙', '甲'], xi: ['丙'],       ji: ['壬'],       desc: '春土气寒，丙火暖土，甲木疏松' },
      卯: { yong: ['丙', '甲'], xi: ['丙'],       ji: ['壬', '癸'], desc: '卯月木旺克土，丙火暖助，甲木有情' },
      辰: { yong: ['甲', '丙'], xi: ['甲', '丙'], ji: ['庚'],       desc: '辰月土旺，甲木疏松，丙火暖照' },
      巳: { yong: ['壬', '甲'], xi: ['壬', '甲'], ji: ['庚', '丙'], desc: '巳月火生土旺，壬水调候，甲木疏土' },
      午: { yong: ['壬', '甲'], xi: ['壬'],       ji: ['丙', '丁'], desc: '午月火土燥热，壬水调候最急' },
      未: { yong: ['壬', '癸'], xi: ['壬', '甲'], ji: ['丙', '丁'], desc: '未月燥土，壬癸水润之' },
      申: { yong: ['丙', '癸'], xi: ['丙', '癸'], ji: ['壬'],       desc: '申月金旺土弱，丙火暖照，癸水润之' },
      酉: { yong: ['丙', '癸'], xi: ['丙', '癸'], ji: ['壬'],       desc: '酉月金旺，丙火暖土，癸水调候' },
      戌: { yong: ['甲', '丙'], xi: ['甲', '丙'], ji: ['庚'],       desc: '戌月土旺，甲木疏土，丙火暖照' },
      亥: { yong: ['丙', '甲'], xi: ['丙', '甲'], ji: ['壬'],       desc: '亥月水旺，丙火暖身，甲木疏土' },
      子: { yong: ['丙', '甲'], xi: ['丙'],       ji: ['壬', '癸'], desc: '子月严寒，丙火暖土为急' },
      丑: { yong: ['丙', '甲'], xi: ['丙'],       ji: ['癸', '壬'], desc: '丑月冻土，丙火解冻，甲木辅助' },
    },
    己: {
      寅: { yong: ['丙', '癸'], xi: ['丙'],       ji: ['甲'],       desc: '春土气薄，丙火暖助，癸水润之' },
      卯: { yong: ['丙', '癸'], xi: ['丙'],       ji: ['甲', '乙'], desc: '卯月木旺克土，丙火补助，癸水润根' },
      辰: { yong: ['丙', '癸'], xi: ['丙', '癸'], ji: ['庚'],       desc: '辰月己土旺，丙火暖照，癸水润泽' },
      巳: { yong: ['癸', '丙'], xi: ['癸'],       ji: ['庚'],       desc: '巳月火旺燥土，癸水调候为急' },
      午: { yong: ['癸', '丙'], xi: ['癸'],       ji: ['丙', '丁'], desc: '午月火极燥，癸水调候最急' },
      未: { yong: ['癸', '丙'], xi: ['癸'],       ji: ['甲'],       desc: '未月燥土，癸水润之为先' },
      申: { yong: ['丙', '癸'], xi: ['丙', '癸'], ji: ['庚', '壬'], desc: '申月金水旺，丙火暖土，癸水适度' },
      酉: { yong: ['丙', '癸'], xi: ['丙', '癸'], ji: ['辛'],       desc: '酉月金旺，丙火暖照，癸水调候' },
      戌: { yong: ['甲', '癸'], xi: ['甲', '癸'], ji: ['庚'],       desc: '戌月土旺，甲木疏松，癸水润泽' },
      亥: { yong: ['丙', '甲'], xi: ['丙'],       ji: ['壬', '癸'], desc: '亥月寒湿，丙火暖土，甲木疏之' },
      子: { yong: ['丙', '甲'], xi: ['丙'],       ji: ['壬', '癸'], desc: '子月严寒，丙火暖土为急，甲木辅之' },
      丑: { yong: ['丙', '甲'], xi: ['丙'],       ji: ['癸'],       desc: '丑月寒土，丙火解冻，甲木疏松' },
    },
    庚: {
      寅: { yong: ['戊', '丁'], xi: ['戊', '丁'], ji: ['壬'],       desc: '寅月木旺，戊土护金，丁火炼金' },
      卯: { yong: ['丁', '甲'], xi: ['丁'],       ji: ['壬', '癸'], desc: '卯月木旺，丁火锻炼庚金，甲木引丁' },
      辰: { yong: ['甲', '丁'], xi: ['甲', '丁'], ji: ['壬'],       desc: '辰月土旺埋金，甲木疏土，丁火炼金' },
      巳: { yong: ['壬', '戊'], xi: ['壬', '戊'], ji: ['丁'],       desc: '巳月火旺克金，壬水调候，戊土护金' },
      午: { yong: ['壬', '己'], xi: ['壬'],       ji: ['丁', '丙'], desc: '午月火极旺，壬水最急调候救金' },
      未: { yong: ['丁', '甲'], xi: ['甲', '壬'], ji: ['己'],       desc: '未月土旺，丁火炼金，甲木疏土' },
      申: { yong: ['丁', '甲'], xi: ['丁', '甲'], ji: ['壬'],       desc: '申月庚金最旺，丁火炼金为急' },
      酉: { yong: ['丁', '甲'], xi: ['丁', '甲'], ji: ['壬'],       desc: '酉月金旺，丁火炼金，甲木引丁' },
      戌: { yong: ['甲', '壬'], xi: ['甲', '壬'], ji: ['戊'],       desc: '戌月土旺，甲木疏土，壬水调候' },
      亥: { yong: ['丁', '甲'], xi: ['丁', '甲'], ji: ['壬', '癸'], desc: '亥月水旺，丁火炼金，甲木生火' },
      子: { yong: ['丁', '丙'], xi: ['丁'],       ji: ['壬', '癸'], desc: '子月严寒，丁丙火暖金炼金' },
      丑: { yong: ['丙', '丁'], xi: ['丙', '丁'], ji: ['壬', '癸'], desc: '丑月严寒，丙丁火暖身炼金' },
    },
    辛: {
      寅: { yong: ['己', '壬'], xi: ['己', '壬'], ji: ['丙'],       desc: '寅月木旺，己土生金，壬水洗净' },
      卯: { yong: ['壬', '甲'], xi: ['壬'],       ji: ['丙', '丁'], desc: '卯月木旺，壬水洗金，辛从壬水' },
      辰: { yong: ['壬', '庚'], xi: ['壬'],       ji: ['戊'],       desc: '辰月土旺，壬水为用，庚金辅助' },
      巳: { yong: ['壬', '庚'], xi: ['壬'],       ji: ['丙', '戊'], desc: '巳月火旺，壬水调候救金' },
      午: { yong: ['壬', '癸'], xi: ['壬', '癸'], ji: ['丙', '丁'], desc: '午月火极，壬癸水调候最急' },
      未: { yong: ['壬', '庚'], xi: ['壬'],       ji: ['丙', '己'], desc: '未月燥热，壬水调候，庚金辅助' },
      申: { yong: ['壬', '甲'], xi: ['壬'],       ji: ['戊', '己'], desc: '申月金旺，壬水洗净，甲木引水' },
      酉: { yong: ['壬', '甲'], xi: ['壬'],       ji: ['戊', '己'], desc: '酉月辛金最旺，壬水洗净为急' },
      戌: { yong: ['壬', '甲'], xi: ['壬', '甲'], ji: ['戊'],       desc: '戌月土燥，壬水调候，甲木疏土' },
      亥: { yong: ['壬', '丙'], xi: ['壬'],       ji: ['癸'],       desc: '亥月水旺洗金，丙火暖身' },
      子: { yong: ['丙', '壬'], xi: ['丙', '壬'], ji: ['癸'],       desc: '子月严寒，丙火暖金，壬水滋养' },
      丑: { yong: ['丙', '壬'], xi: ['丙'],       ji: ['癸', '己'], desc: '丑月严寒，丙火暖身，壬水洗净' },
    },
    壬: {
      寅: { yong: ['庚', '戊'], xi: ['庚'],       ji: ['丙', '丁'], desc: '寅月初春，庚金发水之源，戊土制水' },
      卯: { yong: ['戊', '庚'], xi: ['戊', '庚'], ji: ['甲', '乙'], desc: '卯月木旺泄水，戊土制水，庚金生水' },
      辰: { yong: ['甲', '庚'], xi: ['甲', '庚'], ji: ['戊'],       desc: '辰月土旺克水，甲木疏土，庚金生水' },
      巳: { yong: ['庚', '壬'], xi: ['庚'],       ji: ['戊', '己'], desc: '巳月火旺，庚金生水，壬水自助' },
      午: { yong: ['庚', '癸'], xi: ['庚'],       ji: ['戊', '己'], desc: '午月火旺克水，庚金生水为急，癸辅' },
      未: { yong: ['辛', '庚'], xi: ['辛', '庚'], ji: ['戊', '己'], desc: '未月土旺，辛庚金生水，防土克水' },
      申: { yong: ['戊', '丁'], xi: ['戊'],       ji: ['庚'],       desc: '申月金水旺，戊土制水，丁火调候' },
      酉: { yong: ['甲', '丙'], xi: ['甲', '丙'], ji: ['辛'],       desc: '酉月金旺生水，甲木疏通，丙火调候' },
      戌: { yong: ['甲', '丙'], xi: ['甲', '丙'], ji: ['戊'],       desc: '戌月土克水，甲木疏土，丙火调候' },
      亥: { yong: ['戊', '丙'], xi: ['戊'],       ji: ['庚'],       desc: '亥月水旺，戊土制水，丙火调候' },
      子: { yong: ['戊', '丙'], xi: ['戊', '丙'], ji: ['庚', '癸'], desc: '子月水极旺，戊土制水，丙火调候' },
      丑: { yong: ['丙', '甲'], xi: ['丙', '甲'], ji: ['庚', '癸'], desc: '丑月严寒，丙火调候，甲木引丙' },
    },
    癸: {
      寅: { yong: ['辛', '庚'], xi: ['辛'],       ji: ['甲', '丙'], desc: '寅月初春，辛金生水，庚金辅助' },
      卯: { yong: ['辛', '庚'], xi: ['辛'],       ji: ['甲', '乙'], desc: '卯月木旺泄水，辛庚金生水' },
      辰: { yong: ['丙', '辛'], xi: ['丙', '辛'], ji: ['戊'],       desc: '辰月土旺，丙火调候，辛金生水' },
      巳: { yong: ['辛', '庚'], xi: ['辛', '庚'], ji: ['戊', '丙'], desc: '巳月火旺克水，辛庚金生水为急' },
      午: { yong: ['庚', '辛'], xi: ['庚', '辛'], ji: ['丙', '丁'], desc: '午月火极克水，庚辛金生水最急' },
      未: { yong: ['庚', '辛'], xi: ['庚', '辛'], ji: ['戊', '己'], desc: '未月土旺，庚辛金生水' },
      申: { yong: ['丙', '丁'], xi: ['丙', '丁'], ji: ['庚'],       desc: '申月金旺生水，丙丁火调候' },
      酉: { yong: ['辛', '丙'], xi: ['辛'],       ji: ['庚'],       desc: '酉月金旺，丙火调候，辛金自旺' },
      戌: { yong: ['辛', '甲'], xi: ['辛', '甲'], ji: ['戊'],       desc: '戌月土旺，辛金生水，甲木疏土' },
      亥: { yong: ['庚', '丙'], xi: ['庚'],       ji: ['壬'],       desc: '亥月水旺，庚金生水，丙火调候' },
      子: { yong: ['丙', '辛'], xi: ['丙', '辛'], ji: ['庚', '壬'], desc: '子月水极旺，丙火调候，辛金适量' },
      丑: { yong: ['丙', '辛'], xi: ['丙', '辛'], ji: ['壬', '庚'], desc: '丑月严寒，丙火调候暖身，辛金生水' },
    },
  };

  // ═══════════════════════════════════════════
  // § 构造函数
  // ═══════════════════════════════════════════

  constructor() {
    ensurePlugins();
  }

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

    const sexValue = gender === '男' ? 1 : 0;
    const lsr = lunisolar(effectiveDate);
    const c8ex = lsr.char8ex(sexValue);

    // ── 1. 获取四柱原始数据 ──────────────────
    const yearPillar  = c8ex.year;
    const monthPillar = c8ex.month;
    const dayPillar   = c8ex.day;
    const hourPillar  = c8ex.hour;

    const riGan = dayPillar.stem.name as TianGan;

    // ── 2. 构建 GanZhi（含纳音）──────────────
    const yearGanZhi  = this.buildGanZhi(yearPillar.stem.name, yearPillar.branch.name, yearPillar);
    const monthGanZhi = this.buildGanZhi(monthPillar.stem.name, monthPillar.branch.name, monthPillar);
    const dayGanZhi   = this.buildGanZhi(dayPillar.stem.name, dayPillar.branch.name, dayPillar);
    const hourGanZhi  = this.buildGanZhi(hourPillar.stem.name, hourPillar.branch.name, hourPillar);

    // ── 3. 构建藏干 ──────────────────────────
    const yearCang  = this.buildCangGan(yearPillar.branch.name as DiZhi, riGan);
    const monthCang = this.buildCangGan(monthPillar.branch.name as DiZhi, riGan);
    const dayCang   = this.buildCangGan(dayPillar.branch.name as DiZhi, riGan);
    const hourCang  = this.buildCangGan(hourPillar.branch.name as DiZhi, riGan);

    // ── 4. 十神（天干相对日主）───────────────
    const yearSS  = BaziEngine.computeShiShen(riGan, yearPillar.stem.name as TianGan);
    const monthSS = BaziEngine.computeShiShen(riGan, monthPillar.stem.name as TianGan);
    const daySS: ShiShen = '比肩'; // 日主自身
    const hourSS  = BaziEngine.computeShiShen(riGan, hourPillar.stem.name as TianGan);

    // ── 5. 十二长生 ───────────────────────────
    const yearCS  = BaziEngine.computeChangSheng(riGan, yearPillar.branch.name as DiZhi);
    const monthCS = BaziEngine.computeChangSheng(riGan, monthPillar.branch.name as DiZhi);
    const dayCS   = BaziEngine.computeChangSheng(riGan, dayPillar.branch.name as DiZhi);
    const hourCS  = BaziEngine.computeChangSheng(riGan, hourPillar.branch.name as DiZhi);

    // ── 6. 组装四柱 ───────────────────────────
    const siZhu: SiZhu = {
      year:  { ganZhi: yearGanZhi,  shiShen: yearSS,  cangGan: yearCang,  changSheng: yearCS },
      month: { ganZhi: monthGanZhi, shiShen: monthSS, cangGan: monthCang, changSheng: monthCS },
      day:   { ganZhi: dayGanZhi,   shiShen: daySS,   cangGan: dayCang,   changSheng: dayCS },
      hour:  { ganZhi: hourGanZhi,  shiShen: hourSS,  cangGan: hourCang,  changSheng: hourCS },
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
    const stemRelations   = this.computeStemRelations(stems, monthPillar.branch.name as DiZhi, wuXingStrength);

    // ── 9. 格局 ───────────────────────────────
    const geJu = this.determineGeJu(siZhu, wuXingStrength, riGan);

    // ── 10. 神煞（自建推算 + theGods 插件补充）───
    const ownShenSha    = this.computeShenShaOwn(siZhu, riGan);
    const pluginShenSha = this.extractShenSha(lsr);
    const ownNames      = new Set(ownShenSha.map(s => s.name));
    const shenSha       = [...ownShenSha, ...pluginShenSha.filter(s => !ownNames.has(s.name))];

    // ── 10b. 空亡 ─────────────────────────────
    const kongWang = BaziEngine.computeKongWang(dayGanZhi);

    // ── 11. 大运 ──────────────────────────────
    const { direction, startAge, daYunList } = this.computeDaYun(birthDate, gender, riGan, lsr, c8ex);

    // ── 12. 农历信息 ──────────────────────────
    const lunar    = lsr.lunar;
    const lunarDate = `${lunar.getYearName()}年${lunar.getMonthName()}月${lunar.getDayName()}`;
    const solarTerm = lsr.solarTerm?.name;

    // ── 13. 胎元 & 命宫 ───────────────────────
    const embryoSB  = c8ex.embryo();
    const ownSignSB = c8ex.ownSign();
    const taiYuan   = this.sbToGanZhi(embryoSB);
    const mingGong  = this.sbToGanZhi(ownSignSB);

    return {
      birthDateTime: birthDate,
      gender,
      siZhu,
      riZhu: {
        gan:         riGan,
        wuXing:      BaziEngine.GAN_WUXING[riGan],
        yinYang:     BaziEngine.GAN_YINYANG[riGan],
        description: BaziEngine.RI_ZHU_DESC[riGan],
      },
      wuXingStrength,
      branchRelations,
      stemRelations,
      geJu,
      kongWang,
      trueSolarTimeDesc,
      shenSha,
      daYunDirection:  direction,
      daYunStartAge:   startAge,
      daYunList,
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
   * 从 lunisolar Pillar 对象构建 GanZhi 结构
   * 纳音通过 takeSound 插件的 pillar.takeSound 获取
   */
  private buildGanZhi(
    ganName: string,
    zhiName: string,
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    pillar: any,
  ): GanZhi {
    const gan  = ganName as TianGan;
    const zhi  = zhiName as DiZhi;
    const naYin = (pillar.takeSound as string | undefined) ?? '';
    const naYinWx = this.naYinToWuXing(naYin);
    return {
      gan,
      zhi,
      ganWuXing:   BaziEngine.GAN_WUXING[gan],
      zhiWuXing:   BaziEngine.ZHI_WUXING[zhi],
      ganYinYang:  BaziEngine.GAN_YINYANG[gan],
      zhiYinYang:  BaziEngine.ZHI_YINYANG[zhi],
      naYin,
      naYinWuXing: naYinWx,
    };
  }

  /**
   * 将 lunisolar SB 对象转换为 GanZhi（用于胎元/命宫）
   */
  private sbToGanZhi(sb: lunisolar.SB): GanZhi {
    const gan = sb.stem.name as TianGan;
    const zhi = sb.branch.name as DiZhi;
    const naYin = (sb as unknown as { takeSound?: string }).takeSound ?? '';
    return {
      gan,
      zhi,
      ganWuXing:   BaziEngine.GAN_WUXING[gan],
      zhiWuXing:   BaziEngine.ZHI_WUXING[zhi],
      ganYinYang:  BaziEngine.GAN_YINYANG[gan],
      zhiYinYang:  BaziEngine.ZHI_YINYANG[zhi],
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
      wuXing:  BaziEngine.GAN_WUXING[gan],
      shiShen: BaziEngine.computeShiShen(riGan, gan),
      weight,
    }));
  }

  /**
   * 五行力量计算（《滴天髓》五行力量论 + 《穷通宝鉴》调候用神）
   *
   * 力量来源：
   *   1. 四天干，每根权重 WX_WEIGHT.GAN
   *   2. 四地支藏干，按藏干表权重 × ZHI_BASE × 旺相休囚死系数
   *   3. 天干通根加成（每个通根 +0.3）
   *   4. 六合/三合合化加成（+0.5）
   *
   * 月令旺相休囚死（《三命通会》）：
   *   旺×2.0, 相×1.5, 休×1.0, 囚×0.7, 死×0.5
   */
  private computeWuXingStrength(
    siZhu: SiZhu,
    riGan: TianGan,
    monthZhi: DiZhi,
  ): WuXingStrength {
    const balance: WuXingBalance = { jin: 0, mu: 0, shui: 0, huo: 0, tu: 0 };

    const addWx = (wx: WuXing, amt: number) => {
      balance[BaziEngine.wxToKey(wx)] += amt;
    };

    // ── 月令本气五行 ──────────────────────────
    const monthMainWx = BaziEngine.GAN_WUXING[BaziEngine.CANG_GAN[monthZhi][0].gan];

    // ── 旺相休囚死系数 ────────────────────────
    const wangXiangFactor = (wx: WuXing): number => {
      if (wx === monthMainWx) return 2.0;                          // 旺
      if (BaziEngine.SHENG[monthMainWx] === wx) return 1.5;       // 相：月令生wx
      if (BaziEngine.SHENG[wx] === monthMainWx) return 1.0;       // 休：wx生月令
      if (BaziEngine.KE[wx] === monthMainWx) return 0.7;          // 囚：wx克月令
      if (BaziEngine.KE[monthMainWx] === wx) return 0.5;          // 死：月令克wx
      return 1.0;
    };

    // ── 1. 四天干 ─────────────────────────────
    for (const zhu of [siZhu.year, siZhu.month, siZhu.day, siZhu.hour]) {
      addWx(zhu.ganZhi.ganWuXing, BaziEngine.WX_WEIGHT.GAN);
    }

    // ── 2. 四地支藏干（旺相休囚死加权）────────
    for (const zhu of Object.values(siZhu) as ZhuDetail[]) {
      for (const cg of zhu.cangGan) {
        const base = BaziEngine.WX_WEIGHT.ZHI_BASE * cg.weight;
        addWx(cg.wuXing, base * wangXiangFactor(cg.wuXing));
      }
    }

    // ── 3. 天干通根（每通根 +0.3）───────────────
    const branches = [siZhu.year, siZhu.month, siZhu.day, siZhu.hour].map(
      z => z.ganZhi.zhi,
    );
    for (const zhu of [siZhu.year, siZhu.month, siZhu.day, siZhu.hour]) {
      const stemWx = zhu.ganZhi.ganWuXing;
      for (const zhi of branches) {
        for (const cg of BaziEngine.CANG_GAN[zhi]) {
          if (BaziEngine.GAN_WUXING[cg.gan] === stemWx) {
            addWx(stemWx, 0.3);
          }
        }
      }
    }

    // ── 4. 六合/三合合化加成 (+0.5) ─────────────
    for (const [a, b, result] of BaziEngine.ZHI_LIU_HE) {
      if (branches.includes(a) && branches.includes(b)) {
        addWx(result, 0.5);
      }
    }
    for (const [x, y, z, result] of BaziEngine.ZHI_SAN_HE) {
      if ([x, y, z].every(b => branches.includes(b))) {
        addWx(result, 0.5);
      }
    }

    // ── 日主强弱判断（《滴天髓》）───────────────
    const riWx = BaziEngine.GAN_WUXING[riGan];
    const riKey = BaziEngine.wxToKey(riWx);
    const riForce = balance[riKey];

    const helpWx = [riWx, BaziEngine.reverseSheng(riWx)];
    const helpForce = helpWx.reduce((s, wx) => s + balance[BaziEngine.wxToKey(wx)], 0);

    const weakenWx: WuXing[] = [
      BaziEngine.SHENG[riWx],
      BaziEngine.KE[riWx],
      BaziEngine.getKeMe(riWx),
    ];
    const weakenForce = weakenWx.reduce((s, wx) => s + balance[BaziEngine.wxToKey(wx)], 0);

    const riZhuStrong = (riForce + helpForce) >= weakenForce;

    // ── 用神取法：优先调候表，fallback 身强/身弱 ──
    let yongShen: WuXing;
    let xiShen: WuXing;
    let jiShen: WuXing;

    const tiaoHou = BaziEngine.TIAO_HOU_YONG_SHEN[riGan]?.[monthZhi];
    if (tiaoHou && tiaoHou.yong.length > 0) {
      // 调候用神（《穷通宝鉴》）
      yongShen = BaziEngine.GAN_WUXING[tiaoHou.yong[0]];
      xiShen   = tiaoHou.yong[1]
        ? BaziEngine.GAN_WUXING[tiaoHou.yong[1]]
        : (tiaoHou.xi[0] ? BaziEngine.GAN_WUXING[tiaoHou.xi[0]] : BaziEngine.reverseSheng(riWx));
      jiShen   = tiaoHou.ji[0]
        ? BaziEngine.GAN_WUXING[tiaoHou.ji[0]]
        : BaziEngine.getKeMe(riWx);
    } else if (riZhuStrong) {
      // 身强：用克泄之神
      yongShen = BaziEngine.getKeMe(riWx);
      xiShen   = BaziEngine.KE[riWx];
      jiShen   = riWx;
    } else {
      // 身弱：用生扶之神
      yongShen = BaziEngine.reverseSheng(riWx);
      xiShen   = riWx;
      jiShen   = BaziEngine.getKeMe(riWx);
    }

    // ── 最强/最弱五行 ─────────────────────────
    const entries = Object.entries(balance) as [keyof WuXingBalance, number][];
    const strongest = BaziEngine.keyToWx(
      entries.reduce((a, b) => (b[1] > a[1] ? b : a))[0],
    );
    const weakest = BaziEngine.keyToWx(
      entries.reduce((a, b) => (b[1] < a[1] ? b : a))[0],
    );

    return { balance, strongest, weakest, riZhuStrong, yongShen, xiShen, jiShen };
  }

  /** 五行→余额对象键 */
  private static wxToKey(wx: WuXing): keyof WuXingBalance {
    const map: Record<WuXing, keyof WuXingBalance> = {
      金: 'jin', 木: 'mu', 水: 'shui', 火: 'huo', 土: 'tu',
    };
    return map[wx];
  }

  /** 余额对象键→五行 */
  private static keyToWx(k: keyof WuXingBalance): WuXing {
    const map: Record<keyof WuXingBalance, WuXing> = {
      jin: '金', mu: '木', shui: '水', huo: '火', tu: '土',
    };
    return map[k];
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
      if (positions.length) relations.push({ type: '六合', branches: [a, b], result, positions });
    }

    // 三合（三支）
    for (const [x, y, z, result] of BaziEngine.ZHI_SAN_HE) {
      const present = [x, y, z].filter(b => branches.includes(b));
      if (present.length >= 2) {
        const positions = present.map(b => labels[branches.indexOf(b)]);
        relations.push({ type: '三合', branches: present, result, positions });
      }
    }

    // 三会（三支）
    for (const [x, y, z, result] of BaziEngine.ZHI_SAN_HUI) {
      const present = [x, y, z].filter(b => branches.includes(b));
      if (present.length >= 2) {
        const positions = present.map(b => labels[branches.indexOf(b)]);
        relations.push({ type: '三会', branches: present, result, positions });
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
  private computeStemRelations(stems: TianGan[], monthZhi: DiZhi, wxStrength: WuXingStrength): StemRelation[] {
    const relations: StemRelation[] = [];
    const labels = ['年干', '月干', '日干', '时干'];

    // 天干五合（含合化条件判断）
    for (const [a, b, huaWx] of BaziEngine.GAN_HE) {
      const positions: string[] = [];
      stems.forEach((s, i) => {
        stems.forEach((s2, j) => {
          if (j > i && ((s === a && s2 === b) || (s === b && s2 === a))) {
            positions.push(`${labels[i]}-${labels[j]}`);
          }
        });
      });
      if (positions.length) {
        // 判断是否真化（《渊海子平》合化论）
        // 条件：1. 化神得令（月支本气为化神五行）
        //        2. 化神在四柱中力量占比较高（>25%）
        //        3. 无充克破坏
        const monthMainWx = BaziEngine.GAN_WUXING[BaziEngine.CANG_GAN[monthZhi][0].gan];
        const huaKey = BaziEngine.wxToKey(huaWx);
        const total = Object.values(wxStrength.balance).reduce((s, v) => s + v, 0);
        const huaRatio = total > 0 ? wxStrength.balance[huaKey] / total : 0;
        
        const deLing = monthMainWx === huaWx; // 化神得令
        const liQiang = huaRatio > 0.25;      // 化神力强
        const heHua = deLing && liQiang;
        
        let heHuaDesc: string;
        if (heHua) {
          heHuaDesc = `${a}${b}合化${huaWx}成功：化神${huaWx}得令且力量充沛`;
        } else if (deLing && !liQiang) {
          heHuaDesc = `${a}${b}合而不化：化神得令但力量不足`;
        } else if (!deLing && liQiang) {
          heHuaDesc = `${a}${b}合而不化：化神力强但未得令`;
        } else {
          heHuaDesc = `${a}${b}合而不化：化神既未得令且力量不足`;
        }

        relations.push({ type: '天干五合', stems: [a, b], result: huaWx, positions, heHua, heHuaDesc });
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
  // § 格局判定（《渊海子平》·格局论）
  // ─────────────────────────────────────────

  /**
   * 格局判定
   *
   * 正格取法：月支藏干主气的十神为格局名
   * 特殊格：从格（五行极端偏枯）、化气格（天干五合化气）
   * 来源：《渊海子平》·格局论、《三命通会》
   */
  private determineGeJu(
    siZhu: SiZhu,
    wxStrength: WuXingStrength,
    riGan: TianGan,
  ): GeJu {
    // 1. 检查从格（身极弱，五行严重偏枯）
    const riKey = BaziEngine.wxToKey(BaziEngine.GAN_WUXING[riGan]);
    const riForce = wxStrength.balance[riKey];
    const total = Object.values(wxStrength.balance).reduce((a, b) => a + b, 0);
    if (riForce / total < 0.12) {
      const strongestWx = wxStrength.strongest;
      const cong = this.getCongGe(strongestWx, siZhu, riGan);
      if (cong) return cong;
    }

    // 2. 检查专旺格（日主五行占比>40%，身旺之极）
    if (riForce / total > 0.40) {
      const zhuan = this.getZhuanWangGe(riGan);
      if (zhuan) return zhuan;
    }

    // 3. 检查化气格（日干与年干、月干或时干五合，且化神得令）
    const huaQi = this.checkHuaQiGe(siZhu, wxStrength);
    if (huaQi) return huaQi;

    // 4. 正格：月支藏干主气的十神
    const monthMainGan = siZhu.month.cangGan[0];
    const ss = monthMainGan.shiShen;

    // 建禄格/月刃格：月支主气为比肩或劫财时特殊命名（《渊海子平》·禄刃格）
    let geJuName: string;
    if (ss === '比肩') {
      geJuName = '建禄格';
    } else if (ss === '劫财') {
      geJuName = '月刃格';
    } else {
      geJuName = `${ss}格`;
    }

    // 格局强度：月支主气五行与用神/忌神比较（《滴天髓》格局清浊论）
    const monthMainWx = BaziEngine.GAN_WUXING[monthMainGan.gan];
    let strength: '上' | '中' | '下';
    if (monthMainWx === wxStrength.yongShen) {
      strength = '上';
    } else if (monthMainWx === wxStrength.jiShen) {
      strength = '下';
    } else {
      strength = '中';
    }

    const desc         = this.getGeJuDesc(ss, wxStrength.riZhuStrong);
    const modernMeaning = this.getModernMeaning(ss);

    return {
      name:    geJuName,
      category: '正格',
      strength,
      description: desc,
      modernMeaning,
    };
  }

  private getCongGe(strongestWx: WuXing, siZhu: SiZhu, riGan: TianGan): GeJu | null {
    const riWx = BaziEngine.GAN_WUXING[riGan];
    // 从财格：财星独旺
    if (BaziEngine.KE[riWx] === strongestWx) {
      return { name: '从财格', category: '特殊格', strength: '上', description: '日主极弱，财星独旺，顺其势从之，善于积累财富', modernMeaning: '高度适应环境，善于把握资源机会' };
    }
    // 从官格
    if (BaziEngine.getKeMe(riWx) === strongestWx) {
      return { name: '从官格', category: '特殊格', strength: '上', description: '日主极弱，官星独旺，有强大组织归属感', modernMeaning: '适合在体制或大型组织中发挥才华' };
    }
    // 从儿格（食伤旺）
    if (BaziEngine.SHENG[riWx] === strongestWx) {
      return { name: '从儿格', category: '特殊格', strength: '上', description: '日主极弱，食伤独旺，才华横溢，创造力极强', modernMeaning: '天才型人格，适合创意与艺术领域' };
    }
    return null;
  }

  /**
   * 专旺格：日主五行极旺（>40%），五气从一
   * 五格：曲直（木）、炎上（火）、稼穑（土）、从革（金）、润下（水）
   * 来源：《渊海子平》·专旺格论
   */
  private getZhuanWangGe(riGan: TianGan): GeJu | null {
    const riWx = BaziEngine.GAN_WUXING[riGan];
    const map: Partial<Record<WuXing, { name: string; desc: string; modern: string }>> = {
      木: { name: '曲直格', desc: '日主木气极旺，曲直格成，性格正直，仁慈宽厚，富有生命力', modern: '你有极强的成长力与创造力，善于开辟新领域' },
      火: { name: '炎上格', desc: '日主火气极旺，炎上格成，热情奔放，礼貌文明，光明磊落', modern: '你充满热情与感召力，天生的领袖与表达者' },
      土: { name: '稼穑格', desc: '日主土气极旺，稼穑格成，厚德载物，务实包容，信用卓著', modern: '你稳重可靠，是团队中的基石与守护者' },
      金: { name: '从革格', desc: '日主金气极旺，从革格成，刚毅果断，义气凛然，改革创新', modern: '你具有极强的执行力和改革精神，敢于突破常规' },
      水: { name: '润下格', desc: '日主水气极旺，润下格成，智慧渊深，随机应变，善于谋略', modern: '你智慧超群，善于在变局中把握先机' },
    };
    const info = map[riWx];
    if (!info) return null;
    return { name: info.name, category: '特殊格', strength: '上', description: info.desc, modernMeaning: info.modern };
  }

  private checkHuaQiGe(siZhu: SiZhu, wxStrength: WuXingStrength): GeJu | null {
    // 日干与年干、月干或时干五合化气（化神在月令得势）
    for (const [a, b, huaWx] of BaziEngine.GAN_HE) {
      const dayGan   = siZhu.day.ganZhi.gan;
      const yearGan  = siZhu.year.ganZhi.gan;
      const monthGan = siZhu.month.ganZhi.gan;
      const hourGan  = siZhu.hour.ganZhi.gan;
      if (
        (dayGan === a && (yearGan === b || monthGan === b || hourGan === b)) ||
        (dayGan === b && (yearGan === a || monthGan === a || hourGan === a))
      ) {
        const huaKey = BaziEngine.wxToKey(huaWx);
        const total = Object.values(wxStrength.balance).reduce((s, v) => s + v, 0);
        if (wxStrength.balance[huaKey] / total > 0.35) {
          return {
            name: `化${huaWx}格`,
            category: '特殊格',
            strength: '上',
            description: `日干化${huaWx}，化神得势，变化能力极强`,
            modernMeaning: `极强的适应与转化能力，善于在变化中创造价值`,
          };
        }
      }
    }
    return null;
  }

  /** 正格描述（简版，来源：《渊海子平》格局用神） */
  private getGeJuDesc(ss: ShiShen, strong: boolean): string {
    const base: Record<ShiShen, string> = {
      正官: '月令正官，规则意识强，行事有序，适合体制内发展',
      七杀: '月令七杀，抗压能力强，行动力迅猛，适合挑战性工作',
      正财: '月令正财，踏实务实，善于理财，重视物质基础',
      偏财: '月令偏财，社交广泛，善于把握机遇，商业嗅觉灵敏',
      正印: '月令正印，学习能力强，为人仁厚，有贵人扶持',
      偏印: '月令偏印，思维独特，专业技能强，有研究精神',
      食神: '月令食神，创造力强，生活品质高，才华自然流露',
      伤官: '月令伤官，才华横溢，个性鲜明，追求突破与创新',
      比肩: '月令比肩，独立自主，竞争意识强，适合个人创业',
      劫财: '月令劫财，魄力十足，胆识过人，善于拼搏',
    };
    const suffix = strong ? '，日主身强，格局清纯。' : '，日主身弱，需用神扶助。';
    return (base[ss] ?? `月令${ss}格`) + suffix;
  }

  private getModernMeaning(ss: ShiShen): string {
    const map: Record<ShiShen, string> = {
      正官: '你有很强的秩序感和责任心，在体制内如鱼得水',
      七杀: '你天生适合在压力中成长，越挑战越有动力',
      正财: '你对资源管理有天赋，脚踏实地是你的优势',
      偏财: '你对机会的嗅觉很灵敏，社交能力强',
      正印: '你有很强的学习能力和思考深度，有贵人相助',
      偏印: '你有独特的专业视角，研究型思维是你的核心竞争力',
      食神: '你能把想法变成实际收获，生活充满创造力',
      伤官: '你内心有一种打破常规的冲动，才华需要出口',
      比肩: '你是那种知道自己要什么的人，独立而坚定',
      劫财: '你做决定很果断，行动力是你最大的资产',
    };
    return map[ss] ?? `${ss}格赋予你独特的人生视角`;
  }

  // ─────────────────────────────────────────
  // § 神煞提取（利用 theGods 插件）
  // ─────────────────────────────────────────

  /**
   * 从 lunisolar theGods 插件提取神煞
   * 来源：《三命通会》神煞论
   *
   * @param lsr lunisolar 实例
   */
  private extractShenSha(lsr: lunisolar.Lunisolar): ShenSha[] {
    const result: ShenSha[] = [];

    try {
      const gods = lsr.theGods;

      // 取本日所有神煞（年月日时综合）
      const allGods = gods.getGods('YMDH');
      for (const god of allGods) {
        const ll = god.luckLevel; // 正数为吉，负数为凶，0为中性
        result.push({
          name: god.name,
          type: ll > 0 ? '吉' : ll < 0 ? '凶' : '中性',
          position: god.cate ?? '综合',
          description: this.getShenShaDesc(god.name),
          modernMeaning: this.getShenShaModern(god.name),
        });
      }
    } catch {
      // theGods 插件在某些日期可能无数据，静默处理
    }

    return result;
  }

  /** 神煞白话描述（来源：《三命通会》·神煞论） */
  private getShenShaDesc(name: string): string {
    const desc: Record<string, string> = {
      天乙贵人: '四柱中最吉之神，逢凶化吉，得贵人相助',
      文昌贵人: '学业有成，文才出众，适合文职与学术',
      福星贵人: '福气深厚，逢事多吉',
      桃花: '魅力四射，人缘出众，感情丰富',
      红鸾: '婚姻感情之星，主喜事',
      天喜: '喜庆之星，多逢欢乐',
      驿马: '主变动迁移，适合行旅与流动',
      华盖: '主孤独与精神追求，有宗教艺术天赋',
      羊刃: '主果断魄力，双刃剑，需谨慎',
      空亡: '主某方面暂时缺失，需耐心等待',
      劫煞: '主破败，需防小人',
      灾煞: '主意外，需注意安全',
    };
    return desc[name] ?? `${name}：命理中的神煞标记`;
  }

  private getShenShaModern(name: string): string {
    const map: Record<string, string> = {
      天乙贵人: '你容易获得他人的帮助，贵人运强',
      文昌贵人: '你有很强的学习和表达能力',
      桃花: '你天生有吸引人的气质',
      驿马: '你适合在变化中寻找机会',
      华盖: '你有很强的精神追求，可能有孤独感',
      羊刃: '你做决定很果断，但需注意冲动',
      空亡: '这个领域暂时需要更多耐心',
    };
    return map[name] ?? `${name}对你的人生有特殊影响`;
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

    const yearGan  = siZhu.year.ganZhi.gan;
    const monthGan = siZhu.month.ganZhi.gan;
    const dayGan   = siZhu.day.ganZhi.gan;
    const hourGan  = siZhu.hour.ganZhi.gan;

    const yearZhi  = siZhu.year.ganZhi.zhi;
    const monthZhi = siZhu.month.ganZhi.zhi;
    const dayZhi   = siZhu.day.ganZhi.zhi;
    const hourZhi  = siZhu.hour.ganZhi.zhi;

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
        '主破财损耗、意外损失，需防财务风险、资产流失与合伙纠纷',
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
        '主破财损耗、小人暗害，防合伙纠纷与资金损失',
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
        '主意外灾害，宜注意出行安全与身体健康，防突发事故',
        '提高安全意识，在高风险情境下保持多一份谨慎');
    }

    return result;
  }

  // ─────────────────────────────────────────
  // § 大运计算（《渊海子平》·大运论）
  // ─────────────────────────────────────────

  /**
   * 大运排列计算
   *
   * 规则（《渊海子平》大运论）：
   * - 阳年生男、阴年生女：顺行大运
   * - 阳年生女、阴年生男：逆行大运
   * - 大运起步：从出生日到最近节气，每3天折合1岁
   * - 此处通过 lunisolar 的 char8ex 结合月柱推导大运干支
   *
   * @param birthDate 出生日期
   * @param gender 性别
   * @param riGan 日主天干
   * @param lsr lunisolar 实例
   * @param c8ex char8ex 实例
   */
  private computeDaYun(
    birthDate: Date,
    gender: '男' | '女',
    riGan: TianGan,
    lsr: lunisolar.Lunisolar,
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    c8ex: any,
  ): { direction: DaYunDirection; startAge: number; daYunList: DaYun[] } {
    // 年干阴阳
    const yearGan = c8ex.year.stem.name as TianGan;
    const yearYy  = BaziEngine.GAN_YINYANG[yearGan];

    // 顺逆行判断
    const isForward =
      (yearYy === '阳' && gender === '男') ||
      (yearYy === '阴' && gender === '女');
    const direction: DaYunDirection = isForward ? '顺行' : '逆行';

    // 大运起步年龄（简化算法：取最近节气距出生日的天数 / 3）
    const startAge = this.computeDaYunStartAge(birthDate, isForward);

    // 大运干支：从月柱起，顺/逆数10大运
    const monthSBValue = c8ex.month.value as number; // 0–59
    const daYunList: DaYun[] = [];

    for (let i = 1; i <= 10; i++) {
      const offset = isForward ? i : -i;
      const sbVal  = ((monthSBValue + offset) % 60 + 60) % 60;
      const sb     = new lunisolar.SB(sbVal);
      const ganZhi = this.sbToGanZhi(sb);
      const shiShen = BaziEngine.computeShiShen(riGan, sb.stem.name as TianGan);
      const zhiMainGan = BaziEngine.CANG_GAN[sb.branch.name as DiZhi][0].gan;
      const zhiShiShen = BaziEngine.computeShiShen(riGan, zhiMainGan);

      const ageStart = startAge + (i - 1) * 10;
      const ageEnd   = ageStart + 9;
      daYunList.push({
        startAge: ageStart,
        endAge:   ageEnd,
        ganZhi,
        shiShen,
        zhiShiShen,
        period: `${ageStart}–${ageEnd}岁`,
      });
    }

    return { direction, startAge, daYunList };
  }

  /**
   * 计算大运起步年龄（《渊海子平》·大运起步法）
   * 顺行：找出生日之后的最近节（非气）
   * 逆行：找出生日之前的最近节（非气）
   * 每3天折合1岁，不足3天按1岁计
   */
  private computeDaYunStartAge(birthDate: Date, isForward: boolean): number {
    try {
      const [, termDate] = lunisolar.SolarTerm.findNode(birthDate, {
        nodeFlag: 0, // 取节
        returnValue: false,
      });
      const msPerDay = 86400000;
      let diffDays: number;
      if (isForward) {
        diffDays = Math.ceil((termDate.getTime() - birthDate.getTime()) / msPerDay);
      } else {
        // 逆行：往回找上一个节
        const prevDate = new Date(birthDate.getTime() - 90 * msPerDay);
        const [, prevTerm] = lunisolar.SolarTerm.findNode(prevDate, {
          nodeFlag: 0,
          returnValue: false,
        });
        diffDays = Math.ceil((birthDate.getTime() - prevTerm.getTime()) / msPerDay);
      }
      return Math.max(1, Math.round(diffDays / 3));
    } catch {
      return 3; // 默认3岁起运
    }
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
