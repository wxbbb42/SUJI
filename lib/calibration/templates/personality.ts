import type { QuestionTemplate } from './types';

/**
 * 兜底模板：当 bifurcation 没有可用年份事件时（极少见），
 * 退化到"性格倾向"问题。这两个模板的 trigger 是 'none'，
 * 由 Session 在事件用尽后强行注入，跟具体年份解耦。
 */
export const PERSONALITY_TEMPLATES: QuestionTemplate[] = [
  {
    id: 'persona_introversion',
    triggerEvents: ['none'],
    variants: { 'none': 'irrelevant' },
    rawQuestion: '你比较倾向独处+深思，还是喜欢热闹+表达？',
  },
  {
    id: 'persona_health_weak',
    triggerEvents: ['none'],
    variants: { 'none': 'irrelevant' },
    rawQuestion: '从小到大，你身体最容易出问题的是哪一块？比如脾胃、呼吸、肾水、肝气。',
  },
];
