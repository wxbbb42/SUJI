import type { QuestionType, BamenName, BashenName } from '../types';

export interface YongShenRule {
  questionType: QuestionType;
  /** 主用神：要找哪个干（值），或者 'time' 表示用时干 */
  primaryGan: string;
  /** 辅看：哪个门加分 */
  secondaryMen?: BamenName;
  /** 辅看：哪个神加分 */
  secondaryShen?: BashenName;
  /** 辅看：哪个星加分 */
  secondaryStar?: string;
  description: string;
}

export const YONGSHEN_RULES: Record<QuestionType, YongShenRule> = {
  career: {
    questionType: 'career',
    primaryGan: '庚',
    secondaryShen: '值符',
    secondaryMen: '开门',
    description: '求职、晋升、被领导赏识 — 看官星庚 + 值符 + 开门',
  },
  wealth: {
    questionType: 'wealth',
    primaryGan: 'time',  // 时干（求测者）
    secondaryMen: '生门',
    secondaryShen: '值符',
    description: '求财、投资、收入 — 看时干 + 生门 + 值符',
  },
  marriage: {
    questionType: 'marriage',
    primaryGan: 'time',  // 时干 + 配偶星（gender 决定，handler 内分支）
    secondaryShen: '六合',
    description: '婚姻、配偶 — 男看妻星庚，女看夫星庚，附加六合',
  },
  kids: {
    questionType: 'kids',
    primaryGan: 'time',  // 简化：以时干推子女星
    secondaryShen: '九地',
    secondaryMen: '生门',
    description: '子女缘、生育 — 看子女星 + 九地（藏伏育子）+ 生门',
  },
  parents: {
    questionType: 'parents',
    primaryGan: 'time',  // 简化：以时干 + 印星
    secondaryShen: '值符',
    description: '父母健康、孝道事 — 看父母印星 + 值符',
  },
  health: {
    questionType: 'health',
    primaryGan: 'time',
    secondaryStar: '天蓬',  // 病气星
    description: '疾病、康复 — 看年命星 + 天蓬（病气）',
  },
  event: {
    questionType: 'event',
    primaryGan: 'time',
    description: '综合事件 — 看时干 + 全局格局',
  },
  general: {
    questionType: 'general',
    primaryGan: 'time',
    secondaryShen: '值符',
    description: '通用 / 模糊问题 — 看时干 + 值符',
  },
};
