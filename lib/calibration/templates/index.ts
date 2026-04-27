import type { QuestionTemplate } from './types';
import type { BifurcatedYear, CandidateId, EventType } from '../types';
import { DAYUN_TEMPLATES } from './dayun';
import { LIUNIAN_TEMPLATES } from './liunian';
import { PERSONALITY_TEMPLATES } from './personality';

export const ALL_TEMPLATES: QuestionTemplate[] = [
  ...DAYUN_TEMPLATES,
  ...LIUNIAN_TEMPLATES,
  ...PERSONALITY_TEMPLATES,
];

/**
 * 给定一个分歧年份，找最合适的模板。
 * 评分 = 该模板 variants 中"非 irrelevant"且命中三个候选 eventType 的项数。
 * 至少 2 个命中才返回。
 */
export function findTemplate(bif: BifurcatedYear): QuestionTemplate | null {
  const eventVals = [bif.events.before, bif.events.origin, bif.events.after];

  let best: QuestionTemplate | null = null;
  let bestScore = 0;
  for (const tpl of [...DAYUN_TEMPLATES, ...LIUNIAN_TEMPLATES]) {
    let score = 0;
    for (const ev of eventVals) {
      const v = tpl.variants[ev];
      if (v && v !== 'irrelevant') score += 1;
    }
    if (score > bestScore) {
      bestScore = score;
      best = tpl;
    }
  }
  return bestScore >= 2 ? best : null;
}

export function fillTemplate(tpl: QuestionTemplate, year: number, age: number): string {
  return tpl.rawQuestion.replace(/\{year\}/g, String(year)).replace(/\{age\}/g, String(age));
}

/** 计算一次 classification 给三个候选造成的 delta。 */
export function deltaFromAnswer(
  tpl: QuestionTemplate,
  events: Record<CandidateId, EventType>,
  answer: 'yes' | 'no' | 'uncertain',
): Record<CandidateId, number> {
  const delta: Record<CandidateId, number> = { before: 0, origin: 0, after: 0 };
  if (answer === 'uncertain') return delta;
  for (const id of ['before', 'origin', 'after'] as CandidateId[]) {
    const expected = tpl.variants[events[id]];
    if (!expected || expected === 'irrelevant') continue;
    if (expected === answer) delta[id] += 1;
    else delta[id] -= 1;
  }
  return delta;
}
