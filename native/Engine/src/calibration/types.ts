import type { MingPan } from '@engine/bazi/types';
import type { ZiweiPan } from '@engine/ziwei/types';
import type { IFunctionalAstrolabe } from 'iztro/lib/astro/FunctionalAstrolabe';

export type CandidateId = 'before' | 'origin' | 'after';

export type EventType =
  | `八字大运转入${string}`
  | `八字流年${string}`
  | `紫微大限转入${string}`
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
