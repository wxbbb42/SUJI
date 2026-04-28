import type { MingPan } from '@/lib/bazi/types';
import type { ZiweiPan } from '@/lib/ziwei/types';
import type { IFunctionalAstrolabe } from 'iztro/lib/astro/FunctionalAstrolabe';

export type CandidateId = 'before' | 'origin' | 'after';

export type EventType =
  | '大运转七杀' | '大运转正官' | '大运转伤官'
  | '大运转食神' | '大运转比肩' | '大运转劫财'
  | '大运转正印' | '大运转偏印' | '大运转正财' | '大运转偏财'
  | '流年七杀临身' | '流年伤官见官' | '流年正财动' | '流年子女星动'
  | '紫微大限转七杀' | '紫微大限转正官' | '紫微大限转伤官'
  | '紫微大限转食神' | '紫微大限转比肩' | '紫微大限转劫财'
  | '紫微大限转正印' | '紫微大限转偏印' | '紫微大限转正财' | '紫微大限转偏财'
  | 'none';

export interface Candidate {
  id: CandidateId;
  birthDate: Date;
  mingPan: MingPan;
  ziweiPan: ZiweiPan;
  /** iztro 原生 astrolabe，用于读取 palace.decadal（紫微大限信号源） */
  astrolabe: IFunctionalAstrolabe;
}

export interface YearEvent {
  candidateId: CandidateId;
  eventType: EventType;
}

export interface BifurcatedYear {
  year: number;
  ageAt: { before: number; origin: number; after: number };
  events: Record<CandidateId, EventType>;
  diversity: number;
}

export interface AskedQuestion {
  templateId: string;
  year: number;
  ageThen: number;
  questionText: string;
  userAnswer: string;
  classified: 'yes' | 'no' | 'uncertain';
  delta: Record<CandidateId, number>;
}

export interface CalibrationSessionState {
  candidates: [Candidate, Candidate, Candidate];
  scores: Record<CandidateId, number>;
  history: AskedQuestion[];
  bifurcations: BifurcatedYear[];
  consumedKeys: Set<string>;
  round: number;
  consecutiveUncertain: number;
  status: 'asking' | 'locked' | 'gave_up';
  lockedCandidate?: CandidateId;
}
