/**
 * 有时 · 命理知识引擎
 * 
 * 设计哲学（Polanyi Tacit Knowledge）：
 * - 用户永远不需要知道"十神"、"纳音"这些术语
 * - 他们只需要说"我最近工作压力大"，系统自动关联到命盘中的官杀关系
 * - 所有专业推算在后台完成，前端只呈现"人话"
 * 
 * 架构：
 * ┌─────────────────────────────────┐
 * │  用户层：自然语言 / 情绪 / 提问    │
 * ├─────────────────────────────────┤
 * │  翻译层：命理术语 → 现代心理学语言  │
 * ├─────────────────────────────────┤
 * │  推算层：八字 / 大运 / 流年 / 神煞  │
 * ├─────────────────────────────────┤
 * │  数据层：lunisolar + 知识库        │
 * └─────────────────────────────────┘
 */

export { MarriageEngine } from '../marriage/MarriageEngine';
export { BaziEngine } from './BaziEngine';
export { DayunEngine } from './DayunEngine';
export { InsightEngine } from './InsightEngine';
export { getCurrentSiLing, getDefaultSiLing, getSiLingSegments } from './SiLing';
export type { SiLingSegment } from './SiLing';
export { CITY_LONGITUDES, getTrueSolarTimeInfo, toTrueSolarTime } from './TrueSolarTime';

// 结构化命理原语（通根、得令、清浊、寒暖燥湿、五档强弱、格局判定）
export {
    aggregate as aggregateSchoolVotes,
    decidePhase,
    DEFAULT_SCHOOL_WEIGHTS,
    OPEN_PHASE_THRESHOLDS
} from './multiSchoolVote';
export { defaultPhaseRegistry, PhaseRegistry } from './phaseRegistry';
export {
    computeDeLing,
    computeGeJuV2,
    computeHanNuanZaoShi,
    computeQingZhuo,
    computeRiZhuStrength,
    computeRiZhuStructure,
    computeRootStrength,
    computeYueLingState,
    computeZuoGen,
    computeZuoRen,
    detectCongGe,
    detectHuaQi,
    detectZhuanWang,
    ROOT_TIER_WEIGHT,
    selectYongShen,
} from './structural';

export type * from './types';
