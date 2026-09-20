/**
 * 结构化命理原语 — 通根、得令、清浊、寒暖燥湿、五档强弱、格局判定
 *
 * 借鉴：bazi-life-curves `_bazi_core.py:192–284` `compute_dayuan_root_strength`
 *   仓库：https://github.com/XiaoChu-1208/bazi-life-curves
 *   License: MIT (Copyright (c) 2026 XiaoChu-1208)
 *   Commit: ad8fdeceac3d74b9682ce1df362e7a497dc91d2c (2026-04-28)
 *
 * 学理：藏干主气论 — 本气、中气、余气 三级权重；
 * 同党根（比劫）+ 印根（生身）共同决定日主通根强度。
 *
 * 工程注意：
 *  - tier 权重 1.0 / 0.5 / 0.2 与 5 档 label 阈值 0.30 / 0.70 / 1.50 / 2.50
 *    均为 bazi-life-curves 经验值；古籍只有定性论述。
 *  - 标 `engineering_threshold_borrowed_from_open_source`，
 *    见 docs/mingli/claims.json `bazi.tonggen.tier-weights-borrowed`
 *    与 `bazi.tonggen.label-thresholds-borrowed`。
 */

import type {
  ChengBaiStatus,
  DiZhi,
  GeJuRank,
  GeJuV2,
  HanNuanZaoShi,
  JiuYingInfo,
  QingZhuo,
  RiZhuStrengthLabel,
  RiZhuStructure,
  RootDetail,
  RootStrength,
  RootStrengthLabel,
  RootTier,
  ShiShen,
  ShiShenRelationFact,
  StemCombinationAssessment,
  StrengthRelation,
  TianGan,
  WuXing,
  XiangShenInfo,
  YueLingState,
} from './types';

/** 本/中/余 三级权重（adapted from bazi-life-curves `ROOT_TIER_WEIGHT`） */
export const ROOT_TIER_WEIGHT: Record<RootTier, number> = {
  ben: 1.0,
  zhong: 0.5,
  yu: 0.2,
};

/**
 * 地支藏干分层（按主气论排序：ben → zhong → yu）
 * 来源：《三命通会》藏干表，与 bazi-life-curves 同口径
 *
 * 注意：与 BaziEngine.CANG_GAN 的 `weight` 字段口径不同（后者是力量评分用的 0.6/0.2/0.2 体系）。
 */
const ROOT_HIDDEN_GAN: Record<DiZhi, { gan: TianGan; tier: RootTier }[]> = {
  子: [{ gan: '癸', tier: 'ben' }],
  丑: [{ gan: '己', tier: 'ben' }, { gan: '癸', tier: 'zhong' }, { gan: '辛', tier: 'yu' }],
  寅: [{ gan: '甲', tier: 'ben' }, { gan: '丙', tier: 'zhong' }, { gan: '戊', tier: 'yu' }],
  卯: [{ gan: '乙', tier: 'ben' }],
  辰: [{ gan: '戊', tier: 'ben' }, { gan: '乙', tier: 'zhong' }, { gan: '癸', tier: 'yu' }],
  巳: [{ gan: '丙', tier: 'ben' }, { gan: '戊', tier: 'zhong' }, { gan: '庚', tier: 'yu' }],
  午: [{ gan: '丁', tier: 'ben' }, { gan: '己', tier: 'zhong' }],
  未: [{ gan: '己', tier: 'ben' }, { gan: '丁', tier: 'zhong' }, { gan: '乙', tier: 'yu' }],
  申: [{ gan: '庚', tier: 'ben' }, { gan: '壬', tier: 'zhong' }, { gan: '戊', tier: 'yu' }],
  酉: [{ gan: '辛', tier: 'ben' }],
  戌: [{ gan: '戊', tier: 'ben' }, { gan: '辛', tier: 'zhong' }, { gan: '丁', tier: 'yu' }],
  亥: [{ gan: '壬', tier: 'ben' }, { gan: '甲', tier: 'zhong' }],
};

const GAN_WUXING: Record<TianGan, WuXing> = {
  甲: '木', 乙: '木',
  丙: '火', 丁: '火',
  戊: '土', 己: '土',
  庚: '金', 辛: '金',
  壬: '水', 癸: '水',
};

/** 五行相生：木→火→土→金→水→木 */
const SHENG: Record<WuXing, WuXing> = {
  木: '火', 火: '土', 土: '金', 金: '水', 水: '木',
};

function shengs(producer: WuXing, target: WuXing): boolean {
  return SHENG[producer] === target;
}

/**
 * 5 档 label 切分
 * 阈值口径：bazi-life-curves classify_root_strength
 */
function classifyRoot(total: number): RootStrengthLabel {
  if (total < 0.30) return '无根';
  if (total < 0.70) return '微根';
  if (total < 1.50) return '弱根';
  if (total < 2.50) return '中根';
  return '强根';
}

/**
 * 计算日主通根度
 * @param dayGan 日干
 * @param branches 四支顺序：[年支, 月支, 日支, 时支]
 */
export function computeRootStrength(
  dayGan: TianGan,
  branches: [DiZhi, DiZhi, DiZhi, DiZhi],
): RootStrength {
  const dayWx = GAN_WUXING[dayGan];
  const positions: ['年', '月', '日', '时'] = ['年', '月', '日', '时'];

  let bijie = 0;
  let yin = 0;
  const details: RootDetail[] = [];

  branches.forEach((zhi, idx) => {
    for (const { gan, tier } of ROOT_HIDDEN_GAN[zhi]) {
      const w = ROOT_TIER_WEIGHT[tier];
      const hgWx = GAN_WUXING[gan];
      if (hgWx === dayWx) {
        bijie += w;
        details.push({
          zhi,
          position: positions[idx],
          hiddenGan: gan,
          tier,
          weight: w,
          kind: 'bijie',
        });
      } else if (shengs(hgWx, dayWx)) {
        yin += w;
        details.push({
          zhi,
          position: positions[idx],
          hiddenGan: gan,
          tier,
          weight: w,
          kind: 'yin',
        });
      }
    }
  });

  const total = bijie + yin;
  return {
    bijieRoot: bijie,
    yinRoot: yin,
    totalRoot: total,
    label: classifyRoot(total),
    details,
  };
}

// ============================================================
// 得令 / 清浊 / 寒暖燥湿 / 日主五档强弱
// 出处：
//   - 《子平真诠评注》六、论十干得时不旺失时不弱（月令旺相休囚死）
//   - 《滴天髓阐微》通神论·清浊 / 寒暖燥湿 / 体用
// 布尔/枚举输出仍依赖经验权重与计数阈值，不等于古籍原文算法。
// ============================================================

/** 五行相克：木克土，土克水，水克火，火克金，金克木 */
const KE: Record<WuXing, WuXing> = {
  木: '土', 土: '水', 水: '火', 火: '金', 金: '木',
};

/** 相对于日主的方向；月支与计数证据共用，不据此直接定喜忌。 */
export function computeStrengthRelation(dayElement: WuXing, targetElement: WuXing): StrengthRelation {
  if (targetElement === dayElement) return 'peer';
  if (SHENG[targetElement] === dayElement) return 'resource';
  if (SHENG[dayElement] === targetElement) return 'output';
  if (KE[dayElement] === targetElement) return 'wealth';
  return 'officer';
}

/** 阳干羊刃地支（《子平真诠》论阳刃 — 阳刃为劫财之地） */
const YANG_REN: Partial<Record<TianGan, DiZhi>> = {
  甲: '卯',
  丙: '午',
  戊: '午',
  庚: '酉',
  壬: '子',
};

/**
 * 月令五态（旺相休囚死）— 看月支主气与日主的五行关系
 * 《子平真诠》论十干得时不旺失时不弱：
 *   月支 == 日主同党 → 旺
 *   月支生日主（印）   → 相
 *   月支 == 日主所生（食伤）→ 休
 *   月支 == 日主所克（财）  → 囚
 *   月支克日主（官杀）   → 死
 */
export function computeYueLingState(dayGan: TianGan, monthZhi: DiZhi): YueLingState {
  const dayWx = GAN_WUXING[dayGan];
  const benGan = ROOT_HIDDEN_GAN[monthZhi].find((h) => h.tier === 'ben')!.gan;
  const monthWx = GAN_WUXING[benGan];
  if (monthWx === dayWx) return '旺';
  if (SHENG[monthWx] === dayWx) return '相';
  if (SHENG[dayWx] === monthWx) return '休';
  if (KE[dayWx] === monthWx) return '囚';
  return '死';
}

/**
 * 得令 / 失令
 * 得令：月支主气为日主同党（旺）或印（相）
 * 失令：月支主气为财（囚）或官杀（死）
 * 中性：休（食伤）— 既非得令也非失令
 */
export function computeDeLing(
  dayGan: TianGan,
  monthZhi: DiZhi,
): { deLing: boolean; shiLing: boolean; yueLingState: YueLingState } {
  const state = computeYueLingState(dayGan, monthZhi);
  return {
    deLing: state === '旺' || state === '相',
    shiLing: state === '囚' || state === '死',
    yueLingState: state,
  };
}

/**
 * 坐刃 — 日支为阳干日主之羊刃
 * 《子平真诠》论阳刃：仅阳干立刃，阴干无刃。
 */
export function computeZuoRen(dayGan: TianGan, dayZhi: DiZhi): boolean {
  return YANG_REN[dayGan] === dayZhi;
}

/**
 * 坐根 — 日支藏干含日主同党或印
 * 与 computeRootStrength 内部判定一致，但只看日支一柱。
 */
export function computeZuoGen(dayGan: TianGan, dayZhi: DiZhi): boolean {
  const dayWx = GAN_WUXING[dayGan];
  return ROOT_HIDDEN_GAN[dayZhi].some(({ gan }) => {
    const wx = GAN_WUXING[gan];
    return wx === dayWx || shengs(wx, dayWx);
  });
}

/**
 * 清浊判定 —《滴天髓·清浊论》
 *   清：工程近似为五行种数 ≤ 3 且同党+印根 ≥ 60% 总根力
 *   浊：工程近似为五行齐全且同党+印根 < 30% 总根力
 *   半清：介于其间
 *
 * 工程注意：该近似未判定冲克或流通是否实际成立，60%/30%不是古籍阈值。
 */
export function computeQingZhuo(
  dayGan: TianGan,
  branches: [DiZhi, DiZhi, DiZhi, DiZhi],
  stems: [TianGan, TianGan, TianGan, TianGan],
): QingZhuo {
  const wxSet = new Set<WuXing>();
  stems.forEach((g) => wxSet.add(GAN_WUXING[g]));
  branches.forEach((z) => {
    ROOT_HIDDEN_GAN[z].forEach(({ gan }) => wxSet.add(GAN_WUXING[gan]));
  });
  const wxCount = wxSet.size;

  const root = computeRootStrength(dayGan, branches);
  const totalAllRoot = branches.reduce((sum, z) => {
    return (
      sum +
      ROOT_HIDDEN_GAN[z].reduce((s, { tier }) => s + ROOT_TIER_WEIGHT[tier], 0)
    );
  }, 0);
  const dayPartyShare = totalAllRoot > 0 ? root.totalRoot / totalAllRoot : 0;

  if (wxCount <= 3 && dayPartyShare >= 0.6) return 'qing';
  if (wxCount === 5 && dayPartyShare < 0.3) return 'zhuo';
  return 'banqing';
}

/**
 * 寒暖燥湿判定 —《滴天髓·寒暖燥湿》
 *   寒：冬月（亥子丑）+ 水/金 干支为多
 *   暖：夏月（巳午未）+ 火/木 干支为多
 *   燥：火土合计 ≥ 5（含藏干本气）且 水 = 0
 *   湿：水土合计 ≥ 5 且 火 = 0
 *
 * 寒/暖以月令季节为主轴；燥/湿以全局五行偏枯为主轴。
 * 同一八字可同时为"暖+燥"（如丙午丁未无水）或"寒+湿"（如壬子癸亥无火）。
 */
const WINTER: ReadonlySet<DiZhi> = new Set(['亥', '子', '丑']);
const SUMMER: ReadonlySet<DiZhi> = new Set(['巳', '午', '未']);

export function computeHanNuanZaoShi(
  monthZhi: DiZhi,
  branches: [DiZhi, DiZhi, DiZhi, DiZhi],
  stems: [TianGan, TianGan, TianGan, TianGan],
): HanNuanZaoShi {
  const counts: Record<WuXing, number> = { 金: 0, 木: 0, 水: 0, 火: 0, 土: 0 };
  stems.forEach((g) => counts[GAN_WUXING[g]]++);
  branches.forEach((z) => {
    const ben = ROOT_HIDDEN_GAN[z].find((h) => h.tier === 'ben')!.gan;
    counts[GAN_WUXING[ben]]++;
  });

  const watery = counts.水 + counts.金;
  const fiery = counts.火 + counts.木;

  const han = WINTER.has(monthZhi) && watery >= 3;
  const nuan = SUMMER.has(monthZhi) && fiery >= 3;
  const zao = counts.火 + counts.土 >= 5 && counts.水 === 0;
  const shi = counts.水 + counts.土 >= 5 && counts.火 === 0;

  return { han, nuan, zao, shi };
}

/**
 * 日主五档强弱（结构化判定）
 *
 * SUJI 兼容工程矩阵；经典只支持辨析月令与全局，不给出此精确矩阵：
 *   太旺 = 得令 + 强根 + (坐刃 || 坐根)
 *   旺   = 得令 + 中根以上
 *   中和 = 得令 + 弱根 OR 失令 + 中根以上
 *   弱   = 失令 + 弱根 OR 得令 + 微根/无根
 *   太弱 = 失令 + 微根/无根
 *
 * rootStrength.label 已依赖数值权重和阈值；这里只把分档再映射成五档。
 * 保留原矩阵，并公开命中分支；这不构成完整传统旺衰判断。
 */
const STRONG_LABELS: ReadonlySet<RootStrengthLabel> = new Set(['中根', '强根']);
const WEAK_LABELS: ReadonlySet<RootStrengthLabel> = new Set(['微根', '无根']);

export function computeRiZhuStrength(
  dayGan: TianGan,
  branches: [DiZhi, DiZhi, DiZhi, DiZhi],
  monthZhi: DiZhi,
  dayZhi: DiZhi,
): RiZhuStrengthLabel {
  const { deLing, shiLing } = computeDeLing(dayGan, monthZhi);
  const root = computeRootStrength(dayGan, branches);
  const zuoRen = computeZuoRen(dayGan, dayZhi);
  const zuoGen = computeZuoGen(dayGan, dayZhi);
  return classifyRiZhuStrength(deLing, shiLing, root.label, zuoRen, zuoGen).strength;
}

/** The result and its explanation share one decision, not two parallel matrices. */
function classifyRiZhuStrength(
  deLing: boolean, shiLing: boolean, rootLabel: RootStrengthLabel, zuoRen: boolean, zuoGen: boolean,
): { strength: RiZhuStrengthLabel; rule: string } {
  const isStrong = STRONG_LABELS.has(rootLabel);
  const isWeak = WEAK_LABELS.has(rootLabel);
  if (deLing && rootLabel === '强根' && (zuoRen || zuoGen)) return { strength: 'taiwang', rule: 'de-ling-strong-root-with-seat-support' };
  if (deLing && isStrong) return { strength: 'wang', rule: 'de-ling-medium-or-strong-root' };
  if (deLing && rootLabel === '弱根') return { strength: 'zhonghe', rule: 'de-ling-weak-root' };
  if (shiLing && isStrong) return { strength: 'zhonghe', rule: 'shi-ling-medium-or-strong-root' };
  if (shiLing && rootLabel === '弱根') return { strength: 'ruo', rule: 'shi-ling-weak-root' };
  if (deLing && isWeak) return { strength: 'ruo', rule: 'de-ling-minimal-root' };
  if (shiLing && isWeak) return { strength: 'tairuo', rule: 'shi-ling-minimal-root' };
  if (isStrong) return { strength: 'zhonghe', rule: 'neutral-month-medium-or-strong-root' };
  if (isWeak) return { strength: 'ruo', rule: 'neutral-month-minimal-root' };
  return { strength: 'zhonghe', rule: 'neutral-month-weak-root' };
}

/**
 * 聚合：完整日主结构
 * 入参与现有 BaziEngine 一致：四柱按 [年, 月, 日, 时] 排序
 */
export function computeRiZhuStructure(
  dayGan: TianGan,
  stems: [TianGan, TianGan, TianGan, TianGan],
  branches: [DiZhi, DiZhi, DiZhi, DiZhi],
): RiZhuStructure {
  const monthZhi = branches[1];
  const dayZhi = branches[2];
  const { deLing, shiLing, yueLingState } = computeDeLing(dayGan, monthZhi);
  const rootStrength = computeRootStrength(dayGan, branches);
  const sameElementRoots = rootStrength.details.filter(item => item.kind === 'bijie');
  const resourceSupport = rootStrength.details.filter(item => item.kind === 'yin');
  const zuoRen = computeZuoRen(dayGan, dayZhi);
  const zuoGen = computeZuoGen(dayGan, dayZhi);
  const assessment = classifyRiZhuStrength(deLing, shiLing, rootStrength.label, zuoRen, zuoGen);
  const monthMainQi = ROOT_HIDDEN_GAN[monthZhi].find(item => item.tier === 'ben')!.gan;
  return {
    deLing,
    shiLing,
    yueLingState,
    rootStrength,
    zuoRen,
    zuoGen,
    qingZhuo: computeQingZhuo(dayGan, branches, stems),
    hanNuanZaoShi: computeHanNuanZaoShi(monthZhi, branches, stems),
    strength: assessment.strength,
    evidence: {
      version: 'month-root-matrix-v1', basis: 'engineering-heuristic',
      monthBranch: monthZhi, monthMainQi, monthMainElement: GAN_WUXING[monthMainQi],
      monthRelation: computeStrengthRelation(GAN_WUXING[dayGan], GAN_WUXING[monthMainQi]),
      monthMethod: 'month-branch-main-qi',
      sameElementRoots, resourceSupport,
      hasSameElementRoot: sameElementRoots.length > 0, hasResourceSupport: resourceSupport.length > 0,
      daySeatSameElementRoot: sameElementRoots.some(item => item.position === '日'),
      daySeatResourceSupport: resourceSupport.some(item => item.position === '日'),
      rootWeightBasis: 'open-source-engineering-weights', rootWeights: { ...ROOT_TIER_WEIGHT },
      rootLabelBands: [
        { label: '无根', lowerInclusive: 0, upperExclusive: 0.3 },
        { label: '微根', lowerInclusive: 0.3, upperExclusive: 0.7 },
        { label: '弱根', lowerInclusive: 0.7, upperExclusive: 1.5 },
        { label: '中根', lowerInclusive: 1.5, upperExclusive: 2.5 },
        { label: '强根', lowerInclusive: 2.5, upperExclusive: null },
      ],
      strengthRule: assessment.rule, exposedStemsUsedForStrength: false,
      sourceRefs: [
        'docs/mingli/source-texts/bazi/ziping-zhenquan/01-foundations.md:200',
        'docs/mingli/source-texts/bazi/ditianshui-chanwei/tongshen-17-shuaiwang-zhonghe.md:20',
        'https://github.com/XiaoChu-1208/bazi-life-curves/blob/ad8fdeceac3d74b9682ce1df362e7a497dc91d2c/scripts/_bazi_core.py#L192-L283',
      ],
      limitations: [
        '月令五态仅按月支本气查表，未按交节后日数判司令，辰戌丑未也未区分月内用事。',
        '得令包含旺与相，失令仅指囚与死，休在此矩阵按中性处理；这是本实现约定。',
        '兼容根力标签合计同五行藏干与印支持；无根档也可能含非零余气，须以实际条目区分。',
        '本中余权重1/0.5/0.2与分档阈值是开源工程参数，未获独立实证校准。',
        '五档强弱未考虑其余透干、制化刑冲会合及调候，不能替代完整传统旺衰辨析。',
        '经典引文来自待核印刷底本的电子转录，支持定性辨析，不为工程数值与矩阵背书。',
      ],
    },
  };
}

// ============================================================
// 结构化格局判定 computeGeJuV2
// 出处：
//   - 《子平真诠》论用神变化（取格优先级链）
//   - 《子平真诠》论用神成败救应（cheng/po/jiuying 三态 + 4 救应路径）
//   - 《子平真诠》论相神紧要（per-格局 相神映射）
//   - 《子平真诠》论用神格局高低（jibie 评级）
// 算法骨架: docs/mingli/reading-notes/ziping-zhenquan-xiangshen.md
// per-格局 规则: docs/mingli/reading-notes/2026-05-07-ziping-zhenquan-geju-deepread.md
// 取格与评级包含未校准的计数/根力阈值，输出为候选，非定论。
// ============================================================

const GAN_YINYANG: Record<TianGan, '阳' | '阴'> = {
  甲: '阳', 丙: '阳', 戊: '阳', 庚: '阳', 壬: '阳',
  乙: '阴', 丁: '阴', 己: '阴', 辛: '阴', 癸: '阴',
};

/** 五合化气（《渊海子平》） */
const GAN_HE_TABLE: { gans: [TianGan, TianGan]; huaWx: WuXing }[] = [
  { gans: ['甲', '己'], huaWx: '土' },
  { gans: ['乙', '庚'], huaWx: '金' },
  { gans: ['丙', '辛'], huaWx: '水' },
  { gans: ['丁', '壬'], huaWx: '木' },
  { gans: ['戊', '癸'], huaWx: '火' },
];

/** 三合局 */
const ZHI_SAN_HE_TABLE: { branches: [DiZhi, DiZhi, DiZhi]; wx: WuXing }[] = [
  { branches: ['申', '子', '辰'], wx: '水' },
  { branches: ['寅', '午', '戌'], wx: '火' },
  { branches: ['巳', '酉', '丑'], wx: '金' },
  { branches: ['亥', '卯', '未'], wx: '木' },
];

/** 三会方局 */
const ZHI_SAN_HUI_TABLE: { branches: [DiZhi, DiZhi, DiZhi]; wx: WuXing }[] = [
  { branches: ['寅', '卯', '辰'], wx: '木' },
  { branches: ['巳', '午', '未'], wx: '火' },
  { branches: ['申', '酉', '戌'], wx: '金' },
  { branches: ['亥', '子', '丑'], wx: '水' },
];

const ZHI_LIU_CHONG_PAIRS: [DiZhi, DiZhi][] = [
  ['子', '午'], ['丑', '未'], ['寅', '申'],
  ['卯', '酉'], ['辰', '戌'], ['巳', '亥'],
];

/** 子午卯酉为专气支：原则上不涉及用神变化 */
const ZHUAN_QI_ZHI: ReadonlySet<DiZhi> = new Set(['子', '午', '卯', '酉']);

/**
 * 十神计算（日干 vs 目标干）
 *   阳见阳 / 阴见阴 = 同性 → 比肩 / 食神 / 偏财 / 七杀 / 偏印
 *   阳见阴 / 阴见阳 = 异性 → 劫财 / 伤官 / 正财 / 正官 / 正印
 */
export function computeShiShenOf(dayGan: TianGan, targetGan: TianGan): ShiShen {
  const dayWx = GAN_WUXING[dayGan];
  const tarWx = GAN_WUXING[targetGan];
  const same = GAN_YINYANG[dayGan] === GAN_YINYANG[targetGan];
  if (dayWx === tarWx) return same ? '比肩' : '劫财';
  if (SHENG[dayWx] === tarWx) return same ? '食神' : '伤官';
  if (KE[dayWx] === tarWx) return same ? '偏财' : '正财';
  if (KE[tarWx] === dayWx) return same ? '七杀' : '正官';
  return same ? '偏印' : '正印';
}

/** 取某五行代表天干（与日主异性优先 → 多产生"正"形十神，符合古籍习惯） */
function representativeGan(wx: WuXing, dayGan: TianGan): TianGan {
  const dayYY = GAN_YINYANG[dayGan];
  const yang: Record<WuXing, TianGan> = { 木: '甲', 火: '丙', 土: '戊', 金: '庚', 水: '壬' };
  const yin: Record<WuXing, TianGan> = { 木: '乙', 火: '丁', 土: '己', 金: '辛', 水: '癸' };
  return dayYY === '阳' ? yin[wx] : yang[wx];
}

/** 用神选定 — 月令取格优先级链 */
export interface YongShenSelection {
  yongGan: TianGan;
  yongWx: WuXing;
  yongShiShen: ShiShen;
  basis:
    | 'yueling-benqi-tougan'
    | 'yueling-zhongqi-tougan'
    | 'yueling-yuqi-tougan'
    | 'sanhe'
    | 'sanhui'
    | 'jianlu-yueliu';
  bianhua: boolean;
}

export function selectYongShen(
  dayGan: TianGan,
  monthZhi: DiZhi,
  stems: [TianGan, TianGan, TianGan, TianGan],
  branches: [DiZhi, DiZhi, DiZhi, DiZhi],
): YongShenSelection {
  const hidden = ROOT_HIDDEN_GAN[monthZhi];
  const stemSet = new Set(stems);
  const benGan = hidden.find((h) => h.tier === 'ben')!.gan;

  // Step 1: 月令本气透干
  if (stemSet.has(benGan)) {
    return {
      yongGan: benGan,
      yongWx: GAN_WUXING[benGan],
      yongShiShen: computeShiShenOf(dayGan, benGan),
      basis: 'yueling-benqi-tougan',
      bianhua: false,
    };
  }

  // Step 2-3: 月令中气/余气透干（专气支跳过）
  if (!ZHUAN_QI_ZHI.has(monthZhi)) {
    const zhongGan = hidden.find((h) => h.tier === 'zhong')?.gan;
    if (zhongGan && stemSet.has(zhongGan)) {
      return {
        yongGan: zhongGan,
        yongWx: GAN_WUXING[zhongGan],
        yongShiShen: computeShiShenOf(dayGan, zhongGan),
        basis: 'yueling-zhongqi-tougan',
        bianhua: true,
      };
    }
    const yuGan = hidden.find((h) => h.tier === 'yu')?.gan;
    if (yuGan && stemSet.has(yuGan)) {
      return {
        yongGan: yuGan,
        yongWx: GAN_WUXING[yuGan],
        yongShiShen: computeShiShenOf(dayGan, yuGan),
        basis: 'yueling-yuqi-tougan',
        bianhua: true,
      };
    }
  }

  // Step 4: 月支参与三合 / 三会成局
  const branchSet = new Set(branches);
  for (const { branches: triple, wx } of ZHI_SAN_HE_TABLE) {
    if (triple.includes(monthZhi) && triple.every((z) => branchSet.has(z))) {
      const proxy = representativeGan(wx, dayGan);
      return {
        yongGan: proxy,
        yongWx: wx,
        yongShiShen: computeShiShenOf(dayGan, proxy),
        basis: 'sanhe',
        bianhua: true,
      };
    }
  }
  for (const { branches: triple, wx } of ZHI_SAN_HUI_TABLE) {
    if (triple.includes(monthZhi) && triple.every((z) => branchSet.has(z))) {
      const proxy = representativeGan(wx, dayGan);
      return {
        yongGan: proxy,
        yongWx: wx,
        yongShiShen: computeShiShenOf(dayGan, proxy),
        basis: 'sanhui',
        bianhua: true,
      };
    }
  }

  // Step 5: 建禄 / 月刃格（月令本气即用神，但本气未透）
  return {
    yongGan: benGan,
    yongWx: GAN_WUXING[benGan],
    yongShiShen: computeShiShenOf(dayGan, benGan),
    basis: 'jianlu-yueliu',
    bianhua: false,
  };
}

/** 格局名（中文）— ShiShen → 格名 */
function geJuName(yong: ShiShen, dayGan: TianGan, monthZhi: DiZhi): string {
  const lu: Record<TianGan, DiZhi> = { 甲: '寅', 乙: '卯', 丙: '巳', 丁: '午', 戊: '巳', 己: '午', 庚: '申', 辛: '酉', 壬: '亥', 癸: '子' };
  if (yong === '比肩') return lu[dayGan] === monthZhi ? '建禄格' : '比肩结构（格局待辨）';
  if (yong === '劫财') {
    if (YANG_REN[dayGan] === monthZhi) return '月刃格';
    const monthGod = computeShiShenOf(dayGan, ROOT_HIDDEN_GAN[monthZhi][0].gan);
    return monthGod === '劫财' ? '月劫格' : '劫财透干（格局待辨）';
  }
  return `${yong}格`;
}

/** 格局 phaseId — ShiShen → 稳定 id（与 PhaseRegistry 命名一致） */
function geJuPhaseId(yong: ShiShen, name: string): string {
  if (yong === '比肩' && name !== '建禄格') return 'bijie-pending';
  if (yong === '劫财' && name !== '月刃格') return name === '月劫格' ? 'yuejie-ge' : 'bijie-pending';
  const map: Record<ShiShen, string> = {
    正官: 'zhengguan-ge',
    七杀: 'qisha-ge',
    正财: 'zhengcai-ge',
    偏财: 'piancai-ge',
    正印: 'zhengyin-ge',
    偏印: 'pianyin-ge',
    食神: 'shishen-ge',
    伤官: 'shangguan-ge',
    比肩: 'jianlu-ge',
    劫财: 'yueren-ge',
  };
  return map[yong];
}

/** Per-格局 相神默认映射（《子平真诠》deepread 提取） */
const XIANGSHEN_DEFAULT: Record<ShiShen, { primary: ShiShen; secondary?: ShiShen; role: string }> = {
  正官: { primary: '正财', secondary: '正印', role: '财生官 / 印护官' },
  七杀: { primary: '食神', secondary: '正印', role: '食神制杀 / 印化杀' },
  正财: { primary: '食神', secondary: '正官', role: '食神生财 / 官星护财' },
  偏财: { primary: '食神', secondary: '七杀', role: '食生财 / 杀护财' },
  正印: { primary: '正官', secondary: '七杀', role: '官生印' },
  偏印: { primary: '七杀', secondary: '正官', role: '杀生印' },
  食神: { primary: '正财', secondary: '偏财', role: '食神生财' },
  伤官: { primary: '正印', secondary: '正财', role: '伤官佩印 / 伤官生财' },
  比肩: { primary: '正官', secondary: '七杀', role: '官杀制身护财' },
  劫财: { primary: '正官', secondary: '七杀', role: '官杀制身护财' },
};

/** Per-格局 忌神默认映射 */
const JISHEN_DEFAULT: Record<ShiShen, ShiShen[]> = {
  正官: ['伤官'],
  七杀: ['正财'],
  正财: ['比肩', '劫财'],
  偏财: ['比肩', '劫财'],
  正印: ['正财', '偏财'],
  偏印: ['正财', '偏财'],
  食神: ['偏印'],
  伤官: ['正官'],
  比肩: [],
  劫财: [],
};

/** 4 柱所有透出之干（含日干自身） */
function allTransparentStems(stems: [TianGan, TianGan, TianGan, TianGan]): TianGan[] {
  return [...stems];
}

/** 4 柱所有藏干（含本/中/余） */
function allHiddenStems(branches: [DiZhi, DiZhi, DiZhi, DiZhi]): TianGan[] {
  const out: TianGan[] = [];
  for (const z of branches) {
    for (const { gan } of ROOT_HIDDEN_GAN[z]) out.push(gan);
  }
  return out;
}

/** 扫描相神：相神十神是否在四柱透干或藏干中出现 */
function scanXiangShen(
  yong: ShiShen,
  dayGan: TianGan,
  stems: [TianGan, TianGan, TianGan, TianGan],
  branches: [DiZhi, DiZhi, DiZhi, DiZhi],
): XiangShenInfo | null {
  const def = XIANGSHEN_DEFAULT[yong];
  const candidates: ShiShen[] = [def.primary, ...(def.secondary ? [def.secondary] : [])];
  const all: TianGan[] = [...allTransparentStems(stems), ...allHiddenStems(branches)];
  for (const cand of candidates) {
    const hit = all.find((g) => g !== dayGan && computeShiShenOf(dayGan, g) === cand);
    if (hit) {
      return {
        wuXing: GAN_WUXING[hit],
        shiShen: cand,
        role: def.role,
      };
    }
  }
  return null;
}

/** 扫描忌神：忌神十神是否在四柱透干中出现（透干比藏干威胁更大） */
function scanJiShenTransparent(
  yong: ShiShen,
  dayGan: TianGan,
  stems: [TianGan, TianGan, TianGan, TianGan],
): TianGan[] {
  const jiList = JISHEN_DEFAULT[yong];
  const out: TianGan[] = [];
  for (const g of stems) {
    if (g === dayGan) continue;
    const ss = computeShiShenOf(dayGan, g);
    if (jiList.includes(ss)) out.push(g);
  }
  return out;
}

/** 干 a 是否与干 b 五合 */
function isGanHe(a: TianGan, b: TianGan): boolean {
  return GAN_HE_TABLE.some(
    ({ gans }) => (gans[0] === a && gans[1] === b) || (gans[0] === b && gans[1] === a),
  );
}

/** 干 a 是否克干 b（同/异性都算） */
function ganKe(a: TianGan, b: TianGan): boolean {
  return KE[GAN_WUXING[a]] === GAN_WUXING[b];
}

/** Column geometry is checked per pair, not from a set of stem names.
 * 《子平真诠评注》论十干合而不合 discusses intervening stems, remote
 * pairs, and adjacent competing partners separately; season alone proves none.
 */
export function assessStemCombination(
  stems: readonly TianGan[], monthZhi: DiZhi, left: number, right: number,
): StemCombinationAssessment {
  const a = stems[left], b = stems[right];
  const rule = GAN_HE_TABLE.find(({ gans }) => gans.includes(a) && gans.includes(b) && a !== b);
  if (!rule) throw new RangeError('所给柱位不构成天干五合配对');
  const adjacent = Math.abs(left - right) === 1;
  const competingAdjacentPartner = stems.some((g, i) => i !== left && i !== right && (
    (Math.abs(i - left) === 1 && isGanHe(g, a)) ||
    (Math.abs(i - right) === 1 && isGanHe(g, b))
  ));
  const monthSupportsTransformation = GAN_WUXING[ROOT_HIDDEN_GAN[monthZhi][0].gan] === rule.huaWx;
  const reasons: string[] = [];
  if (!adjacent) reasons.push('隔位配对，须另审中间干及全局，不直接作合去或成化');
  if (competingAdjacentPartner) reasons.push('存在紧邻争合配对，不能自动选定一对成化');
  if (!monthSupportsTransformation) reasons.push('月令本气不属所列化神五行');
  reasons.push('五合方向不等于成化；根气、坐支及全局条件尚未完整求解');
  return {
    positions: [left, right], adjacent, competingAdjacentPartner,
    monthSupportsTransformation,
    status: adjacent && !competingAdjacentPartner && monthSupportsTransformation ? 'candidate' : 'unresolved',
    reasons, transformationEstablished: false,
  };
}

export function computeShiShenRelations(
  dayGan: TianGan, stems: readonly TianGan[],
): ShiShenRelationFact[] {
  const facts: ShiShenRelationFact[] = [];
  stems.forEach((a, sourcePosition) => stems.forEach((b, targetPosition) => {
    if (sourcePosition === 2 || targetPosition === 2 || sourcePosition === targetPosition || !ganKe(a, b)) return;
    const source = computeShiShenOf(dayGan, a), target = computeShiShenOf(dayGan, b);
    let pattern: ShiShenRelationFact['pattern'] = '五行相克';
    if (source === '偏印' && target === '食神') pattern = '偏印制食神';
    else if ((source === '偏印' || source === '正印') && target === '伤官') pattern = '印制伤官';
    else if (source === '食神' && target === '七杀') pattern = '食神制七杀';
    else if (source === '伤官' && target === '正官') pattern = '伤官克正官';
    else if ((source === '正财' || source === '偏财') && (target === '正印' || target === '偏印')) pattern = '财克印';
    facts.push({
      source: { gan: a, shiShen: source, position: sourcePosition },
      target: { gan: b, shiShen: target, position: targetPosition },
      relation: '克', adjacent: Math.abs(sourcePosition - targetPosition) === 1,
      pattern, outcomeEstablished: false,
    });
  }));
  return facts;
}

/**
 * 救应路径扫描（4 类）：
 *   qu-qing : 忌神被五合（合去）→ 去病
 *   shi-zhi : 食伤透出克忌神 → 食制
 *   yin-hua : 印透出生身（用于 伤官见官 / 七杀格 印化路径）
 *   he-sha  : 忌神被合（同 qu-qing 但 reason 偏"合凶" — 七杀格 阳刃合杀的简化）
 */
function scanJiuYing(
  yong: ShiShen,
  jiShenStems: TianGan[],
  dayGan: TianGan,
  stems: [TianGan, TianGan, TianGan, TianGan],
): JiuYingInfo[] {
  if (jiShenStems.length === 0) return [];
  const out: JiuYingInfo[] = [];
  const allStems = stems.filter((_, i) => i !== 2);
  const adjacent = (a: TianGan, b: TianGan) => stems.some((g, i) => i !== 2 && g === a &&
    stems.some((other, j) => j !== 2 && other === b && Math.abs(i - j) === 1));

  for (const ji of jiShenStems) {
    // (1) qu-qing / he-sha: 忌神被五合
    const heHit = allStems.find((g) => g !== ji && isGanHe(g, ji) && adjacent(g, ji));
    if (heHit) {
      out.push({
        trigger: `忌神 ${ji}（${computeShiShenOf(dayGan, ji)}）透出`,
        triggerGan: ji,
        remedy: `${heHit} 与 ${ji} 紧邻五合，为合忌候选；是否去留须复核`,
        path: 'qu-qing',
        source: '《子平真诠》论用神成败救应',
      });
    }

    // (2) shi-zhi: 食伤干克忌神
    const shiZhi = allStems.find((g) => {
      const ss = computeShiShenOf(dayGan, g);
      return (ss === '食神' || ss === '伤官') && ganKe(g, ji) && adjacent(g, ji);
    });
    if (shiZhi) {
      out.push({
        trigger: `忌神 ${ji}（${computeShiShenOf(dayGan, ji)}）透出`,
        triggerGan: ji,
        remedy: `${shiZhi}（${computeShiShenOf(dayGan, shiZhi)}）制忌神`,
        path: 'shi-zhi',
        source: '《子平真诠》论用神成败救应',
      });
    }

    // (3) yin-hua: 印透出（伤官见官 → 印护官；七杀逢印 → 印化杀）
    const yin = allStems.find((g) => {
      const ss = computeShiShenOf(dayGan, g);
      if (ss !== '正印' && ss !== '偏印') return false;
      // 印制伤官 and 官杀生印 are different relations. An arbitrary 印
      // cannot "化" the 财 that actually overcomes it.
      return adjacent(g, ji) && (ganKe(g, ji) || SHENG[GAN_WUXING[ji]] === GAN_WUXING[g]);
    });
    if (yin && (yong === '正官' || yong === '七杀' || yong === '伤官')) {
      out.push({
        trigger: `忌神 ${ji}（${computeShiShenOf(dayGan, ji)}）透出`,
        triggerGan: ji,
        remedy: ganKe(yin, ji)
          ? `${yin}（${computeShiShenOf(dayGan, yin)}）克${ji}（${computeShiShenOf(dayGan, ji)}），为制伤候选`
          : `${ji}（${computeShiShenOf(dayGan, ji)}）生${yin}（${computeShiShenOf(dayGan, yin)}），为印通关候选`,
        path: 'yin-hua',
        source: '《子平真诠》论用神成败救应',
      });
    }
  }

  return out;
}

/** 用神是否被合冲（结构性破象） */
function isYongShenBroken(
  yongGan: TianGan,
  dayGan: TianGan,
  stems: [TianGan, TianGan, TianGan, TianGan],
): boolean {
  // Only an unopposed adjacent combination of every exposed copy is a
  // candidate disruption. Remote pairs, the day stem itself, and 合一留一
  // must not mechanically become a broken configuration.
  const exposed = stems.map((g, i) => g === yongGan && i !== 2 ? i : -1).filter(i => i >= 0);
  return exposed.length > 0 && exposed.every(i => stems.some((g, j) =>
    j !== 2 && Math.abs(i - j) === 1 && isGanHe(g, yongGan) &&
    !stems.some((other, k) => k !== i && k !== j && Math.abs(k - j) === 1 && isGanHe(other, g)),
  ));
}

/** 月支是否被冲（影响月令取格 / 用神变化的判定） */
function isMonthBranchChonged(
  monthZhi: DiZhi,
  branches: [DiZhi, DiZhi, DiZhi, DiZhi],
): boolean {
  return branches.some(
    (z, idx) =>
      idx !== 1 &&
      ZHI_LIU_CHONG_PAIRS.some(
        ([a, b]) => (a === monthZhi && b === z) || (a === z && b === monthZhi),
      ),
  );
}

/**
 * 化气格结构化检测
 *   保守候选筛查，不能当作完整古籍成化求解器：
 *     1. 日干与紧邻天干（月/时）五合，无紧邻争合
 *     2. 化神（合化所成五行）= 月令本气
 *     3. 日主不见任何比印根或额外透干比印（不只看阈值 label）
 *     4. 月支不被冲
 */
export interface HuaQiResult {
  isHuaQi: boolean;
  huaWx: WuXing | null;
  partnerGan: TianGan | null;
}

export function detectHuaQi(
  dayGan: TianGan,
  stems: [TianGan, TianGan, TianGan, TianGan],
  branches: [DiZhi, DiZhi, DiZhi, DiZhi],
  rootLabel: RootStrengthLabel,
): HuaQiResult {
  if (rootLabel !== '无根') return { isHuaQi: false, huaWx: null, partnerGan: null };
  const dayWx = GAN_WUXING[dayGan];
  if (computeRootStrength(dayGan, branches).totalRoot > 0 || stems.some((g, i) =>
    i !== 2 && (GAN_WUXING[g] === dayWx || SHENG[GAN_WUXING[g]] === dayWx),
  )) return { isHuaQi: false, huaWx: null, partnerGan: null };
  const monthZhi = branches[1];
  if (isMonthBranchChonged(monthZhi, branches)) {
    return { isHuaQi: false, huaWx: null, partnerGan: null };
  }
  const benGan = ROOT_HIDDEN_GAN[monthZhi].find((h) => h.tier === 'ben')!.gan;
  const monthBenWx = GAN_WUXING[benGan];

  // The year column is not adjacent to the day column.
  for (const position of [1, 3]) {
    const n = stems[position];
    for (const { gans, huaWx } of GAN_HE_TABLE) {
      const matches =
        (gans[0] === dayGan && gans[1] === n) || (gans[0] === n && gans[1] === dayGan);
      if (matches && huaWx === monthBenWx && !assessStemCombination(stems, monthZhi, 2, position).competingAdjacentPartner) {
        return { isHuaQi: true, huaWx, partnerGan: n };
      }
    }
  }
  return { isHuaQi: false, huaWx: null, partnerGan: null };
}

/**
 * 从格结构化检测
 *   条件：日主无根 + 一种"敌党"势力（财 / 官杀 / 食伤）在原局占主导
 *     主导判据：藏干计数中该党 ≥ 4（不引入百分比）
 */
export interface CongGeResult {
  isCong: boolean;
  congType: '从财' | '从官' | '从儿' | null;
  congWx: WuXing | null;
}

export function detectCongGe(
  dayGan: TianGan,
  stems: [TianGan, TianGan, TianGan, TianGan],
  branches: [DiZhi, DiZhi, DiZhi, DiZhi],
  rootLabel: RootStrengthLabel,
): CongGeResult {
  if (rootLabel !== '无根') return { isCong: false, congType: null, congWx: null };
  const dayWx = GAN_WUXING[dayGan];
  // An engineering "无根" bucket includes small nonzero roots; it must not
  // erase actual supporting stems or roots when screening a following chart.
  if (computeRootStrength(dayGan, branches).totalRoot > 0 || stems.some((g, i) =>
    i !== 2 && (GAN_WUXING[g] === dayWx || SHENG[GAN_WUXING[g]] === dayWx),
  )) return { isCong: false, congType: null, congWx: null };
  const counts: Record<'财' | '官杀' | '食伤' | '比劫' | '印', number> = {
    财: 0, 官杀: 0, 食伤: 0, 比劫: 0, 印: 0,
  };
  const allGans: TianGan[] = [...stems.filter((_, i) => i !== 2), ...allHiddenStems(branches)];
  for (const g of allGans) {
    const wx = GAN_WUXING[g];
    if (wx === dayWx) counts.比劫++;
    else if (SHENG[wx] === dayWx) counts.印++;
    else if (SHENG[dayWx] === wx) counts.食伤++;
    else if (KE[dayWx] === wx) counts.财++;
    else counts.官杀++;
  }
  // 取最大党
  const entries = (Object.entries(counts) as [keyof typeof counts, number][])
    .sort((a, b) => b[1] - a[1]);
  const [topParty, topCount] = entries[0];
  // 4 柱 12 藏干 + 3 干 = 至多 15；从格要求一党≥4 且 远高于次党
  if (topCount < 4) return { isCong: false, congType: null, congWx: null };
  const secondCount = entries[1]?.[1] ?? 0;
  if (topCount - secondCount < 2) return { isCong: false, congType: null, congWx: null };
  if (topParty === '财') return { isCong: true, congType: '从财', congWx: KE[dayWx] };
  if (topParty === '官杀') {
    // 反查"克我之五行" — 不能用 KE[dayWx]（那是我克）
    const reverseKe: WuXing = (Object.keys(KE) as WuXing[]).find((w) => KE[w] === dayWx)!;
    return { isCong: true, congType: '从官', congWx: reverseKe };
  }
  if (topParty === '食伤') return { isCong: true, congType: '从儿', congWx: SHENG[dayWx] };
  return { isCong: false, congType: null, congWx: null };
}

/**
 * 专旺格结构化检测
 *   条件：日主同党（比劫）≥ 4 且印星辅之 + 无明显克泄（官杀+食伤 ≤ 1）
 */
export interface ZhuanWangResult {
  isZhuanWang: boolean;
  name: string | null;
}

export function detectZhuanWang(
  dayGan: TianGan,
  stems: [TianGan, TianGan, TianGan, TianGan],
  branches: [DiZhi, DiZhi, DiZhi, DiZhi],
): ZhuanWangResult {
  const dayWx = GAN_WUXING[dayGan];
  let bijie = 0;
  let yin = 0;
  let keXie = 0; // 官杀 + 食伤
  const allGans: TianGan[] = [...stems.filter((_, i) => i !== 2), ...allHiddenStems(branches)];
  for (const g of allGans) {
    const wx = GAN_WUXING[g];
    if (wx === dayWx) bijie++;
    else if (SHENG[wx] === dayWx) yin++;
    else if (SHENG[dayWx] === wx || KE[wx] === dayWx) keXie++;
  }
  if (bijie < 4 || yin < 1 || keXie > 1) {
    return { isZhuanWang: false, name: null };
  }
  const map: Record<WuXing, string> = {
    木: '曲直格', 火: '炎上格', 土: '稼穑格', 金: '从革格', 水: '润下格',
  };
  return { isZhuanWang: true, name: map[dayWx] };
}

/**
 * 格局高低评级
 *   shang : cheng + 用神有力 + 相神齐 + 无忌神
 *   xia   : po
 *   zhong : 其他（含 jiuying 救应 / cheng 但相神不全）
 */
function rankGeJu(
  chengBai: ChengBaiStatus,
  xiang: XiangShenInfo | null,
  yongRoot: RootStrengthLabel,
  jiCount: number,
): GeJuRank {
  if (chengBai === 'po') return 'xia';
  const yongQiang = yongRoot === '中根' || yongRoot === '强根';
  if (chengBai === 'cheng' && xiang !== null && yongQiang && jiCount === 0) return 'shang';
  return 'zhong';
}

/**
 * 计算用神五行的"通根"档位（复用 computeRootStrength 的判定，
 * 但以"用神五行"代替"日主五行"判同党）
 */
function computeYongShenRootLabel(
  yongWx: WuXing,
  branches: [DiZhi, DiZhi, DiZhi, DiZhi],
): RootStrengthLabel {
  let total = 0;
  for (const z of branches) {
    for (const { gan, tier } of ROOT_HIDDEN_GAN[z]) {
      if (GAN_WUXING[gan] === yongWx) total += ROOT_TIER_WEIGHT[tier];
    }
  }
  if (total < 0.30) return '无根';
  if (total < 0.70) return '微根';
  if (total < 1.50) return '弱根';
  if (total < 2.50) return '中根';
  return '强根';
}

/**
 * computeGeJuV2 — 结构化格局判定主入口
 *
 * 求值顺序（《子平真诠》四章交叉）：
 *   特殊格预检（化气 / 从格 / 专旺 / 全部基于 rootStrength 与计数）
 *   ↓
 *   Step 1  selectYongShen          （用神变化优先级链）
 *   Step 2  scanXiangShen            （per-格局 默认相神映射）
 *   Step 3  scanJiShen + scanJiuYing （成败救应：cheng / jiuying / po）
 *   Step 4  rankGeJu                 （高低：shang / zhong / xia）
 */
export function computeGeJuV2(
  dayGan: TianGan,
  stems: [TianGan, TianGan, TianGan, TianGan],
  branches: [DiZhi, DiZhi, DiZhi, DiZhi],
  riZhuStructure?: RiZhuStructure,
): GeJuV2 {
  const monthZhi = branches[1];
  const root = riZhuStructure?.rootStrength ?? computeRootStrength(dayGan, branches);

  // 特殊格预检 1：化气格
  const huaQi = detectHuaQi(dayGan, stems, branches, root.label);
  if (huaQi.isHuaQi && huaQi.huaWx) {
    return {
      phaseId: `huaqi-${huaQi.huaWx}-ge`,
      name: `化${huaQi.huaWx}格`,
      category: 'huaqi',
      yongShen: huaQi.huaWx,
      xiangShen: null,
      chengBai: 'cheng',
      jiuYing: null,
      jibie: 'shang',
      evidence: ['bazi.yongshen.bianhua-trigger'],
      assessmentStatus: 'heuristic-candidate',
      conditions: ['通过相邻、月令、无比印根与无透干比印的保守筛查；仍为化气候选，未证明成化'],
    };
  }

  // 特殊格预检 2：从格
  const cong = detectCongGe(dayGan, stems, branches, root.label);
  if (cong.isCong && cong.congWx && cong.congType) {
    return {
      phaseId: `${cong.congType.replace('从', 'cong-')}-ge`,
      name: `${cong.congType}格`,
      category: 'conge',
      yongShen: cong.congWx,
      xiangShen: null,
      chengBai: 'cheng',
      jiuYing: null,
      jibie: 'shang',
      evidence: ['bazi.geju.rank-criteria'],
      assessmentStatus: 'heuristic-candidate',
      conditions: ['已排除显式比印根与透干比印；党势计数阈值仍属工程规则，非从格定论'],
    };
  }

  // 特殊格预检 3：专旺
  const zw = detectZhuanWang(dayGan, stems, branches);
  if (zw.isZhuanWang && zw.name) {
    return {
      phaseId: `zhuanwang-${GAN_WUXING[dayGan]}-ge`,
      name: zw.name,
      category: 'zhuanwang',
      yongShen: GAN_WUXING[dayGan],
      xiangShen: null,
      chengBai: 'cheng',
      jiuYing: null,
      jibie: 'shang',
      evidence: ['bazi.geju.rank-criteria'],
      assessmentStatus: 'heuristic-candidate',
      conditions: ['专旺党势计数仍属工程规则，未完成月令、成局与全局条件求解'],
    };
  }

  // 正格主流程
  const sel = selectYongShen(dayGan, monthZhi, stems, branches);
  const yong = sel.yongShiShen;
  const xiang = scanXiangShen(yong, dayGan, stems, branches);
  const jiStems = scanJiShenTransparent(yong, dayGan, stems);
  const yongBroken = isYongShenBroken(sel.yongGan, dayGan, stems);
  const jiuYing = scanJiuYing(yong, jiStems, dayGan, stems);

  // 三态 chengBai
  let chengBai: ChengBaiStatus;
  if (yongBroken) {
    chengBai = 'po';
  } else if (jiStems.length === 0) {
    chengBai = 'cheng';
  } else if (jiStems.every(ji => jiuYing.some(remedy => remedy.triggerGan === ji))) {
    chengBai = 'jiuying';
  } else {
    chengBai = 'po';
  }

  const yongRootLabel = computeYongShenRootLabel(sel.yongWx, branches);
  const jibie = rankGeJu(chengBai, xiang, yongRootLabel, jiStems.length);
  const name = geJuName(yong, dayGan, monthZhi);

  // evidence: 引 reading-note 抽出的 claim ids
  const evidence: string[] = ['bazi.yongshen.priority-chain'];
  if (xiang) evidence.push('bazi.xiangshen.definition');
  if (jiuYing.length > 0) evidence.push('bazi.jiuying.path-classification');
  if (sel.bianhua) evidence.push('bazi.yongshen.bianhua-trigger');
  if (jibie !== 'zhong') evidence.push('bazi.geju.rank-criteria');

  return {
    phaseId: geJuPhaseId(yong, name),
    name,
    category: 'zhengge',
    yongShen: sel.yongWx,
    xiangShen: xiang,
    chengBai,
    jiuYing: jiuYing.length > 0 ? jiuYing : null,
    jibie,
    evidence,
    assessmentStatus: 'heuristic-candidate',
    conditions: [
      '成败与等级是当前结构规则的候选输出，不是完整古籍格局裁定',
      '隔位五合不自动合去用神；相邻合一留一不自动判全格破败',
      ...(isMonthBranchChonged(monthZhi, branches) ? ['月支逢冲，须复核根气与配置影响'] : []),
    ],
    yongShenGan: sel.yongGan,
    yongShenShiShen: yong,
    selectionBasis: sel.basis,
  };
}
