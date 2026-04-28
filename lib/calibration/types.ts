import type { MingPan } from '@/lib/bazi/types';
import type { ZiweiPan } from '@/lib/ziwei/types';
import type { IFunctionalAstrolabe } from 'iztro/lib/astro/FunctionalAstrolabe';

export type CandidateId = 'before' | 'origin' | 'after';

export type EventType =
  | '大运转七杀' | '大运转正官' | '大运转伤官' | '大运转食神'
  | '大运转比肩' | '大运转劫财' | '大运转正印' | '大运转偏印'
  | '大运转正财' | '大运转偏财'
  | '紫微大限转七杀' | '紫微大限转正官' | '紫微大限转伤官' | '紫微大限转食神'
  | '紫微大限转比肩' | '紫微大限转劫财' | '紫微大限转正印' | '紫微大限转偏印'
  | '紫微大限转正财' | '紫微大限转偏财'
  | '流年七杀临身' | '流年伤官见官' | '流年正财动' | '流年子女星动'
  | 'none';

export interface Candidate {
  id: CandidateId;
  birthDate: Date;
  mingPan: MingPan;
  ziweiPan: ZiweiPan;
  /** iztro 原生 astrolabe，用于读取 palace.decadal（紫微大限信号源） */
  astrolabe: IFunctionalAstrolabe;
}

/**
 * 一轮 LLM 决策给到 session 的产物。
 * - next_question：继续问
 * - locked：AI 选了某候选，写入 birthDate；summary 是给用户看的总结语
 * - gave_up：信号不足 / 用户连答不记得，不动 birthDate
 */
export type NextStep =
  | { type: 'next_question'; question: string }
  | { type: 'locked'; correctedDate: Date; candidateId: CandidateId; summary: string }
  | { type: 'gave_up'; reason: string };
