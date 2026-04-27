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

export { BaziEngine } from './BaziEngine';
export { DayunEngine } from './DayunEngine';
export { toTrueSolarTime, getTrueSolarTimeInfo, CITY_LONGITUDES } from './TrueSolarTime';
export { getSiLingSegments, getCurrentSiLing, getDefaultSiLing } from './SiLing';
export type { SiLingSegment } from './SiLing';
export { MarriageEngine } from '../marriage/MarriageEngine';
export { InsightEngine } from './InsightEngine';
export type * from './types';
