/**
 * 命理系统核心类型定义
 */

// ========================
// 基础元素
// ========================

/** 天干 */
export type TianGan = '甲' | '乙' | '丙' | '丁' | '戊' | '己' | '庚' | '辛' | '壬' | '癸';

/** 地支 */
export type DiZhi = '子' | '丑' | '寅' | '卯' | '辰' | '巳' | '午' | '未' | '申' | '酉' | '戌' | '亥';

/** 五行 */
export type WuXing = '金' | '木' | '水' | '火' | '土';

/** 阴阳 */
export type YinYang = '阴' | '阳';

/** 十神 */
export type ShiShen =
  | '比肩' | '劫财'     // 同我
  | '食神' | '伤官'     // 我生
  | '偏财' | '正财'     // 我克
  | '七杀' | '正官'     // 克我
  | '偏印' | '正印';    // 生我

/** 十二长生 */
export type ShiErChangSheng =
  | '长生' | '沐浴' | '冠带' | '临官' | '帝旺'
  | '衰' | '病' | '死' | '墓' | '绝' | '胎' | '养';

/** 六亲 */
export type LiuQin = '父' | '母' | '兄弟' | '姐妹' | '子女' | '配偶';

// ========================
// 干支与柱
// ========================

/** 干支对 */
export interface GanZhi {
  gan: TianGan;
  zhi: DiZhi;
  ganWuXing: WuXing;
  zhiWuXing: WuXing;
  ganYinYang: YinYang;
  zhiYinYang: YinYang;
  naYin: string;        // 纳音（如"山头火"）
  naYinWuXing: WuXing;  // 纳音五行
}

/** 四柱（八字） */
export interface SiZhu {
  year: ZhuDetail;
  month: ZhuDetail;
  day: ZhuDetail;
  hour: ZhuDetail;
}

/** 单柱详情 */
export interface ZhuDetail {
  ganZhi: GanZhi;
  shiShen: ShiShen;           // 该柱天干相对日主的十神
  cangGan: CangGanItem[];     // 藏干
  changSheng: ShiErChangSheng; // 十二长生
}

/** 藏干条目 */
export interface CangGanItem {
  gan: TianGan;
  wuXing: WuXing;
  shiShen: ShiShen;
  weight: number;  // 藏干力量权重 (0-1)
}

// ========================
// 五行分析
// ========================

/** 五行强弱判断 */
export interface WuXingStrength {
  strongest: WuXing;
  weakest: WuXing;
  riZhuStrong: boolean;     // 日主是否身强
  yongShen: WuXing;         // 用神五行
  xiShen: WuXing;           // 喜神五行
  jiShen: WuXing;           // 忌神五行
}

// ========================
// 地支关系
// ========================

/** 地支关系类型 */
export type BranchRelationType =
  | '六合' | '三合' | '三会'
  | '六冲' | '六害' | '六破'
  | '相刑';

/** 地支关系 */
export interface BranchRelation {
  type: BranchRelationType;
  branches: DiZhi[];
  result?: WuXing;      // 合化结果五行（如有）
  positions: string[];   // 涉及的柱位（如 "年支-月支"）
}

// ========================
// 天干关系
// ========================

export type StemRelationType = '天干五合' | '天干相冲';

export interface StemRelation {
  type: StemRelationType;
  stems: TianGan[];
  result?: WuXing;
  positions: string[];
  heHua?: boolean;      // 天干五合是否真正化成
  heHuaDesc?: string;   // 合化条件说明
}

// ========================
// 大运与流年
// ========================

/** 大运信息 */
export interface DaYun {
  startAge: number;
  endAge: number;
  ganZhi: GanZhi;
  shiShen: ShiShen;      // 大运天干十神
  zhiShiShen: ShiShen;   // 大运地支藏干主气十神
  period: string;         // "3-12岁" 格式
}

/** 流年信息 */
export interface LiuNian {
  year: number;
  ganZhi: GanZhi;
  shiShen: ShiShen;
  interactions: string[];  // 与命盘的互动关系
}

/** 流月信息 */
export interface LiuYue {
  month: number;           // 1-12
  ganZhi: GanZhi;
  shiShen: ShiShen;        // 流月天干十神
  zhiShiShen: ShiShen;     // 流月地支藏干主气十神
}

/** 流日信息 */
export interface LiuRi {
  date: Date;
  ganZhi: GanZhi;
  shiShen: ShiShen;        // 流日天干十神
}

/** 大运排列方向 */
export type DaYunDirection = '顺行' | '逆行';

// ========================
// 神煞
// ========================

/** 神煞条目 */
export interface ShenSha {
  name: string;
  type: '吉' | '凶' | '中性';
  position: string;       // 出现位置（年柱/月柱/...）
  description: string;    // 白话解释
  modernMeaning: string;  // 现代心理学映射
}

// ========================
// 格局
// ========================

/** 八字格局 */
export interface GeJu {
  name: string;              // 格局名（如"正官格"、"食神生财"）
  category: '正格' | '特殊格' | '杂格';
  strength: '上' | '中' | '下';
  description: string;
  modernMeaning: string;     // 用现代语言描述的含义
}

// ========================
// 完整命盘
// ========================

/** 完整八字命盘 */
export interface MingPan {
  // 基本信息
  birthDateTime: Date;
  gender: '男' | '女';

  // 四柱
  siZhu: SiZhu;

  // 日主信息
  riZhu: {
    gan: TianGan;
    wuXing: WuXing;
    yinYang: YinYang;
    description: string;  // 日主性格特征描述
  };

  // 五行分析
  wuXingStrength: WuXingStrength;

  // 日主结构（得令/通根/坐刃/清浊/寒暖燥湿/五档强弱）
  riZhuStructure?: RiZhuStructure;

  // 关系网络
  branchRelations: BranchRelation[];
  stemRelations: StemRelation[];

  // 格局（legacy stub，下游逐步迁移到 geJuV2）
  geJu: GeJu;

  // 格局 V2（《子平真诠》成败救应 + 相神 + 高低）
  geJuV2?: GeJuV2;

  // 神煞
  shenSha: ShenSha[];

  // 大运
  daYunDirection: DaYunDirection;
  daYunStartAge: number;
  daYunList: DaYun[];

  // 农历信息
  lunarDate: string;
  solarTerm?: string;    // 出生时的节气

  // 纳音
  yearNaYin: string;

  // 空亡
  kongWang: DiZhi[];       // 六甲空亡地支

  // 真太阳时
  trueSolarTimeDesc?: string;  // 真太阳时校正描述

  // 胎元 & 命宫
  taiYuan: GanZhi;        // 胎元
  mingGong: GanZhi;       // 命宫
}

// ========================
// 洞察层 — 面向用户的解读
// ========================

/** 人格洞察 */
export interface PersonalityInsight {
  coreTraits: string[];           // 核心性格特质
  strengths: string[];            // 优势
  challenges: string[];           // 挑战
  communicationStyle: string;     // 沟通风格
  emotionalPattern: string;       // 情绪模式
  careerAptitude: string[];       // 职业倾向
  relationshipStyle: string;      // 关系模式
}

/** 时运洞察 */
export interface TimingInsight {
  currentPhase: string;           // 当前人生阶段描述
  currentEnergy: string;          // 当前能量状态
  opportunities: string[];        // 机遇方向
  watchouts: string[];            // 注意事项
  advice: string;                 // 建议
  luckyElements: {                // 有利元素
    colors: string[];
    directions: string[];
    numbers: number[];
  };
}

/** 每日洞察 */
export interface DailyInsight {
  date: string;
  ganZhi: string;
  overallEnergy: '高' | '中' | '低';
  focusArea: string;              // 今日关注领域
  advice: string;                 // 今日建议
  avoidance: string;              // 今日宜避免
  luckyHours: string[];           // 吉时
  affirmation: string;            // 今日肯定语
}

// ========================
// 结构化格局类型
// 借鉴 bazi-life-curves (MIT, XiaoChu-1208)：
//   _phase_registry.py / _bazi_core.compute_dayuan_root_strength /
//   multi_school_vote.py
// ========================

/** 藏干层级（《三命通会》藏干主气论） */
export type RootTier = 'ben' | 'zhong' | 'yu';  // 本气 / 中气 / 余气

/** 通根档位（5 档语义化标签） */
export type RootStrengthLabel = '无根' | '微根' | '弱根' | '中根' | '强根';

/** 单条通根细节 */
export interface RootDetail {
  zhi: DiZhi;
  position: '年' | '月' | '日' | '时';
  hiddenGan: TianGan;
  tier: RootTier;
  weight: number;              // 本气 1.0 / 中气 0.5 / 余气 0.2
  kind: 'bijie' | 'yin';       // 同党根 / 印根
}

/** 通根强度评估 */
export interface RootStrength {
  bijieRoot: number;           // 同党根（含日主同五行）总和
  yinRoot: number;             // 印根（生日主）总和
  totalRoot: number;
  label: RootStrengthLabel;
  details: RootDetail[];
}

/** 月令旺相休囚死（《子平真诠》论十干得时不旺失时不弱）*/
export type YueLingState = '旺' | '相' | '休' | '囚' | '死';

/** 清浊（《滴天髓·清浊论》）*/
export type QingZhuo = 'qing' | 'banqing' | 'zhuo';

/** 寒暖燥湿（《滴天髓·寒暖燥湿》）*/
export interface HanNuanZaoShi {
  han: boolean;   // 寒（冬月 + 水金多）
  nuan: boolean;  // 暖（夏月 + 火木多）
  zao: boolean;   // 燥（火土多 + 无水润）
  shi: boolean;   // 湿（水土多 + 无火暖）
}

/** 日主五档强弱（《子平真诠》论用神 + 任注《滴天髓·体用》）*/
export type RiZhuStrengthLabel = 'taiwang' | 'wang' | 'zhonghe' | 'ruo' | 'tairuo';

/** 日主结构（得令/通根/坐刃/清浊/寒暖燥湿/五档强弱） */
export interface RiZhuStructure {
  deLing: boolean;             // 得月令（月支主气为比劫/印）
  shiLing: boolean;            // 失月令（月支主气为财/官杀）
  yueLingState: YueLingState;  // 月令五态（旺相休囚死）
  rootStrength: RootStrength;
  zuoRen: boolean;             // 坐刃（日支为日主羊刃）
  zuoGen: boolean;             // 坐根（日支藏干含同党或印）
  qingZhuo: QingZhuo;          // 清浊
  hanNuanZaoShi: HanNuanZaoShi;
  strength: RiZhuStrengthLabel;
}

/** 流派 */
export type SchoolName = 'ziping' | 'tiaohou' | 'geju' | 'mangpai';

/** 格局维度 */
export type PhaseDimension =
  | 'power'    // 扶抑
  | 'zuogong'  // 做功（盲派）
  | 'cong'     // 从格
  | 'climate'  // 调候
  | 'huaqi'    // 化气
  | 'special'; // 杂格

/** 反向规则极性 */
export type ReversalPolarity = 'positive' | 'neutral' | 'negative';

/** 格局元数据（注册表条目）*/
export interface PhaseMeta {
  /** 稳定标识，跨版本不可改 */
  id: string;
  /** 中文展示名 */
  nameCn: string;
  school: SchoolName;
  dimension: PhaseDimension;
  /** 古籍出处（PhaseRegistry 强制非空） */
  source: string;
  /** 成立条件（人类可读，未来可结构化） */
  requires?: Record<string, string>;
  /** 做功应期支 */
  zuogongTriggerBranches?: DiZhi[];
  /** 盲派事件反向规则覆盖：事件 id → 极性 */
  reversalOverrides?: Record<string, ReversalPolarity>;
}

/** 相神 */
export interface XiangShenInfo {
  wuXing: WuXing;
  shiShen: ShiShen;
  role: string;                // "财生官" / "印护官" / "食制杀" 等
}

/** 救应路径 */
export interface JiuYingInfo {
  trigger: string;             // 触发破格的条件
  remedy: string;              // 救应字
  path?: 'qu-qing' | 'shi-zhi' | 'yin-hua' | 'he-sha' | 'other';
  source: string;              // 古籍出处
}

/** 格局成败状态 */
export type ChengBaiStatus = 'cheng' | 'po' | 'jiuying';

/** 格局高低 */
export type GeJuRank = 'shang' | 'zhong' | 'xia';

/** 结构化格局（《子平真诠》成败救应 + 相神 + 高低）*/
export interface GeJuV2 {
  phaseId: string;             // 引用 PhaseRegistry
  name: string;
  category: 'zhengge' | 'conge' | 'zhuanwang' | 'huaqi';
  yongShen: WuXing;
  xiangShen: XiangShenInfo | null;
  chengBai: ChengBaiStatus;
  jiuYing: JiuYingInfo[] | null;
  jibie: GeJuRank;
  evidence: string[];          // 引 claims.json 的 claim id
}

// --- 多派投票骨架 ---

/** 单派候选 */
export interface SchoolCandidate {
  phaseId: string;
  confidence: number;          // 0–1
  source: string;              // 古籍出处
  reasoning?: string;
}

/** 单派投票输出 */
export interface SchoolVote {
  school: SchoolName;
  weight: number;
  candidates: SchoolCandidate[];
}

/** 聚合后候选 */
export interface AggregatedCandidate {
  phaseId: string;
  posterior: number;
  contributingSchools: SchoolName[];
}

/** 决策状态 */
export type PhaseDecisionStatus = 'decided' | 'open_phase';

/** 决策输出 */
export interface PhaseDecision {
  status: PhaseDecisionStatus;
  /** decided 时填充；open_phase 时为 null */
  phaseId: string | null;
  confidence: number;
  topCandidates: AggregatedCandidate[];
  reason: 'low_top1' | 'narrow_gap' | null;
}
