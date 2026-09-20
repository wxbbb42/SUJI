/**
 * 奇门遁甲类型定义
 */

import type { TianGan, DiZhi, WuXing } from '@engine/bazi/types';
import type { RuleSource } from '../rules/provenance';
import type { QuestionContext } from '../divination/questionJudgment';
import type { qimenQuestionObjects, unresolvedQimenTiming } from './questionObjects';

export type { TianGan, DiZhi, WuXing };
export type YinYangDun = '阳' | '阴';
export type Yuan = '上' | '中' | '下';
export type JuNumber = 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9;

export type BamenName =
  | '休门' | '生门' | '伤门' | '杜门'
  | '景门' | '死门' | '惊门' | '开门';

export type JiuxingName =
  | '天蓬' | '天芮' | '天冲' | '天辅' | '天禽'
  | '天心' | '天柱' | '天任' | '天英';

export type BashenName =
  | '值符' | '腾蛇' | '太阴' | '六合'
  | '白虎' | '玄武' | '九地' | '九天';

export type QuestionType =
  | 'career' | 'wealth' | 'marriage' | 'kids'
  | 'parents' | 'health' | 'event' | 'general';

/** 9 宫 */
export interface Palace {
  id: 1|2|3|4|5|6|7|8|9;
  name: string;
  position: string;            // 北/西南/东/...
  wuXing: WuXing;
  diPanGan: TianGan | null;    // 中宫保留本宫仪，实际寄干另列
  tianPanGan: TianGan | null;
  bamen: BamenName | null;     // 中宫无门
  jiuxing: JiuxingName | null;
  bashen: BashenName | null;
  hostedDiPanGan?: TianGan;   // 固定寄坤的中宫地盘干，与随天禽转动的天盘寄干分开
  hostedTianPanGan?: TianGan;
  hostsTianQin?: boolean;
  doorRelation?: DoorRelation;
  starSeason?: StarSeason;
  hostedStarSeason?: StarSeason;
}

export interface HourVoid {
  scope: 'hour'; ganZhi: string; xun: string; branches: string[]; sourceId: string;
  palaces: {palaceId:number; branches:string[]; palaceBranches:string[]; coverage:'full'|'partial'}[];
}
export interface HourHorse {
  scope: 'hour'; ganZhi: string; branch: string; palaceId: number; sourceId: string;
}
export interface DoorRelation {
  door: BamenName; doorElement: WuXing; palaceElement: WuXing;
  relation: '比和'|'门克宫'|'宫克门'|'门生宫'|'宫生门';
  isPressure: boolean; sourceId: string; assessmentStatus: 'structural-fact-only';
}
export interface StarSeason {
  scope: 'solar-term-month'; star: JiuxingName; element: WuXing;
  monthGanZhi: string; monthBranch: string; monthElement: WuXing;
  state: '旺'|'相'|'休'|'囚'|'废'; sourceId: string; assessmentStatus: 'season-relation-only';
}

export interface BamenInfo {
  name: BamenName;
  wuXing: WuXing;
  jiXiong: '吉' | '大吉' | '凶' | '大凶' | '平';
  description: string;
}

export interface JiuxingInfo {
  name: JiuxingName;
  wuXing: WuXing;
  jiXiong: '吉' | '大吉' | '凶' | '大凶' | '平' | '中';
  description: string;
}

export interface BashenInfo {
  name: BashenName;
  jiXiong: '吉' | '大吉' | '凶' | '中吉' | '中性';
  meaning: string;
  application: string;
}

/** 用神 */
export interface YongShenAnalysis extends Partial<Omit<ReturnType<typeof qimenQuestionObjects>, 'selectionStatus'>> {
  type: string;              // '庚'、'乙'、'时干' 等
  palaceId: 1|2|3|4|5|6|7|8|9;
  state: '旺' | '相' | '休' | '囚' | '死' | '不上卦';
  summary: string;           // '庚临艮宫，得生门 + 天任 + 九地'
  interactions: string[];
  references?: {label:string;palaceId:number}[];
  selectionStatus?: 'initial-reference' | 'candidates-only' | 'requires-clarification';
}

/** 格局 */
export interface GeJu {
  name: string;
  type: '吉' | '凶' | '中性';
  description: string;
  palaceIds?: number[];      // 涉及的宫位
  assessmentStatus?: 'traditional-condition-only' | 'structural-fact-only';
  source?: { title: string; url: string; quote: string; editionStatus: string };
}

/** 应期 */
export interface YingQiAnalysis extends Partial<ReturnType<typeof unresolvedQimenTiming>> {
  description: string;
  factors: string[];
}

/** 当前奇门实现的算法可信度说明，供 AI 与 UI 避免过度断言 */
export interface QimenMethodMeta {
  level: 'mvp' | 'standard' | 'verified';
  algorithm?: string;
  centerPolicy?: string;
  dayBoundary?: string;
  solarTermClock?: string;
  /** Optional when reading legacy charts; new engine output always supplies these. */
  clockPolicy?: 'beijing-standard' | 'apparent-solar';
  timezone?: 'UTC+08:00';
  longitude?: number;
  caveats: string[];
}

/** 起局选项 */
export interface SetupOptions {
  setupTime?: Date;
  /** Explicit current divination longitude selects apparent solar time; omitted uses Beijing standard time. */
  longitude?: number;
  question: string;
  questionType: QuestionType;
  gender?: '男' | '女';
  questionContext?: QuestionContext;
}

/** 完整奇门盘 */
export interface QimenChart {
  question: string;
  questionType: QuestionType;
  setupTime: string;          // ISO
  questionContext?: QuestionContext;
  calculationTime: string;    // ISO projection read as UTC+08:00 fields for day/hour; not a new physical instant
  trueSolarTime?: string;     // Only supplied for explicitly selected apparent solar time
  jieqi: string;              // 节气名（如"谷雨"）
  yinYangDun: YinYangDun;
  juNumber: JuNumber;
  yuan: Yuan;
  palaces: Palace[];          // 9 个，按宫 ID 1-9 排
  yongShen: YongShenAnalysis;
  geJu: GeJu[];
  yingQi: YingQiAnalysis;
  method: QimenMethodMeta;
  fuTou?: string;
  zhiFuStar?: JiuxingName;
  zhiFuPalaceId?: number;
  zhiFuSourcePalaceId?: number;
  zhiShiMen?: BamenName;
  zhiShiPalaceId?: number;
  zhiShiRawPalaceId?: number;
  zhiShiSourcePalaceId?: number;
  tianQinPalaceId?: number;
  dayGanZhi?: string;
  hourGanZhi?: string;
  monthGanZhi?: string;
  hourVoid?: HourVoid;
  horse?: HourHorse;
  ruleSources?: RuleSource[];
}
