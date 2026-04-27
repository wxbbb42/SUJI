import type { QuestionTemplate } from './types';

export const LIUNIAN_TEMPLATES: QuestionTemplate[] = [
  {
    id: 'liunian_qisha_pressure',
    triggerEvents: ['流年七杀临身', '流年伤官见官', '流年正财动'],
    variants: {
      '流年七杀临身': 'yes',
      '流年伤官见官': 'no',
      '流年正财动': 'no',
    },
    rawQuestion: '你 {age} 岁那年（{year}）有没有突然被一件外部压力压过来，比如被裁员/重大考试/严重的家庭压力？',
  },
  {
    id: 'liunian_shangguan_official',
    triggerEvents: ['流年伤官见官', '流年七杀临身', '流年正财动'],
    variants: {
      '流年伤官见官': 'yes',
      '流年七杀临身': 'no',
      '流年正财动': 'no',
    },
    rawQuestion: '你 {age} 岁那年（{year}）有没有跟体制/权威/上级发生明显冲突，或者主动违反过某种规则？',
  },
  {
    id: 'liunian_wealth_action',
    triggerEvents: ['流年正财动', '流年七杀临身', '流年伤官见官'],
    variants: {
      '流年正财动': 'yes',
      '流年七杀临身': 'no',
      '流年伤官见官': 'no',
    },
    rawQuestion: '你 {age} 岁那年（{year}）在钱财或事业资源上有过明显的进项或重大投入吗？',
  },
  {
    id: 'liunian_kids_signal',
    triggerEvents: ['流年子女星动', '流年七杀临身', '流年正财动'],
    variants: {
      '流年子女星动': 'yes',
      '流年七杀临身': 'no',
      '流年正财动': 'no',
    },
    rawQuestion: '你 {age} 岁那年（{year}）跟孩子（或弟妹、晚辈）有过特别的事吗？怀孕、出生、教养转折之类。',
  },
];
