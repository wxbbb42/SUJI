import type { EventType } from '../types';

export interface QuestionTemplate {
  id: string;
  triggerEvents: EventType[];
  /** 不同 eventType 在该模板下的"用户应回答 yes/no/irrelevant" */
  variants: Partial<Record<EventType, 'yes' | 'no' | 'irrelevant'>>;
  /** 模板原文，含 {year} {age} */
  rawQuestion: string;
}
