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

/** 五行力量分布 */
export interface WuXingBalance {
  jin: number;   // 金
  mu: number;    // 木
  shui: number;  // 水
  huo: number;   // 火
  tu: number;    // 土
}

/** 五行强弱判断 */
export interface WuXingStrength {
  balance: WuXingBalance;
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
  
  // 关系网络
  branchRelations: BranchRelation[];
  stemRelations: StemRelation[];
  
  // 格局
  geJu: GeJu;
  
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
