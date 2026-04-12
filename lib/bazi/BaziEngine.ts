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
// fetalgod 使用 CommonJS export = 形式
// eslint-disable-next-line @typescript-eslint/no-require-imports
const fetalGod = require('@lunisolar/plugin-fetalgod') as lunisolar.PluginFunc;

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
   * @param birthDate 出生日期时间（公历）
   * @param gender 性别
   * @returns 完整命盘 MingPan
   */
  calculate(birthDate: Date, gender: '男' | '女'): MingPan {
    const sexValue = gender === '男' ? 1 : 0;
    const lsr = lunisolar(birthDate);
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
    const stemRelations   = this.computeStemRelations(stems);

    // ── 9. 格局 ───────────────────────────────
    const geJu = this.determineGeJu(siZhu, wuXingStrength, riGan);

    // ── 10. 神煞（利用 theGods 插件）────────────
    const shenSha = this.extractShenSha(lsr);

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
  private computeStemRelations(stems: TianGan[]): StemRelation[] {
    const relations: StemRelation[] = [];
    const labels = ['年干', '月干', '日干', '时干'];

    // 天干五合
    for (const [a, b, result] of BaziEngine.GAN_HE) {
      const positions: string[] = [];
      stems.forEach((s, i) => {
        stems.forEach((s2, j) => {
          if (j > i && ((s === a && s2 === b) || (s === b && s2 === a))) {
            positions.push(`${labels[i]}-${labels[j]}`);
          }
        });
      });
      if (positions.length) {
        relations.push({ type: '天干五合', stems: [a, b], result, positions });
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
