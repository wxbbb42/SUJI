import type { QuestionTemplate } from './types';

/**
 * 八字大运 与 紫微大限 共用同一组问句模板。
 *
 * 理由：八字大运十神 与 紫微大限十神 在"语义层"含义相同（都表达"这十年主导力的属性"），
 * 因此问句可以复用，只需把对应的 '紫微大限转 XX' 也注册到 triggerEvents / variants。
 *
 * Bifurcation 合并器（lib/calibration/bifurcation.ts）让紫微优先，
 * 所以 ±1 时辰候选盘里出现的转入事件多数是 '紫微大限转 XX'，由此匹配到这里。
 */
export const DAYUN_TEMPLATES: QuestionTemplate[] = [
  {
    id: 'qisha_role_shift',
    triggerEvents: [
      '大运转七杀', '大运转正官', '大运转比肩',
      '紫微大限转七杀', '紫微大限转正官', '紫微大限转比肩',
    ],
    variants: {
      '大运转七杀': 'yes',     '紫微大限转七杀': 'yes',
      '大运转正官': 'no',      '紫微大限转正官': 'no',
      '大运转比肩': 'no',      '紫微大限转比肩': 'no',
    },
    rawQuestion: '你 {age} 岁那年（{year}）有没有从某种压抑的环境里挣脱出来，比如换工作、跟权威翻脸、独自承担一件大事？',
  },
  {
    id: 'zhengguan_into_position',
    triggerEvents: [
      '大运转正官', '大运转伤官', '大运转食神',
      '紫微大限转正官', '紫微大限转伤官', '紫微大限转食神',
    ],
    variants: {
      '大运转正官': 'yes',     '紫微大限转正官': 'yes',
      '大运转伤官': 'no',      '紫微大限转伤官': 'no',
      '大运转食神': 'no',      '紫微大限转食神': 'no',
    },
    rawQuestion: '你 {age} 岁那年（{year}）有没有进入一个更需要克制自己、配合规则的位置？比如新岗位、新团队、新家庭责任。',
  },
  {
    id: 'shangguan_conflict',
    triggerEvents: [
      '大运转伤官', '大运转正官', '大运转正印',
      '紫微大限转伤官', '紫微大限转正官', '紫微大限转正印',
    ],
    variants: {
      '大运转伤官': 'yes',     '紫微大限转伤官': 'yes',
      '大运转正官': 'no',      '紫微大限转正官': 'no',
      '大运转正印': 'no',      '紫微大限转正印': 'no',
    },
    rawQuestion: '你 {age} 岁那年（{year}）有没有跟领导/师长/规则发生明显摩擦，或者主动选择走非常规的路？',
  },
  {
    id: 'shishen_express',
    triggerEvents: [
      '大运转食神', '大运转七杀', '大运转劫财',
      '紫微大限转食神', '紫微大限转七杀', '紫微大限转劫财',
    ],
    variants: {
      '大运转食神': 'yes',     '紫微大限转食神': 'yes',
      '大运转七杀': 'no',      '紫微大限转七杀': 'no',
      '大运转劫财': 'no',      '紫微大限转劫财': 'no',
    },
    rawQuestion: '你 {age} 岁那年（{year}）有没有在创作、表达、生活情趣上明显放开来过，开始追求"自己想做的事"？',
  },
  {
    id: 'jiecai_partnership',
    triggerEvents: [
      '大运转劫财', '大运转比肩', '大运转正印',
      '紫微大限转劫财', '紫微大限转比肩', '紫微大限转正印',
    ],
    variants: {
      '大运转劫财': 'yes',     '紫微大限转劫财': 'yes',
      '大运转比肩': 'yes',     '紫微大限转比肩': 'yes',
      '大运转正印': 'no',      '紫微大限转正印': 'no',
    },
    rawQuestion: '你 {age} 岁那年（{year}）有没有跟朋友/同事/合伙人深度共事过，或者在合作里被对方分走了机会/资源？',
  },
  {
    id: 'yinxing_dependence',
    triggerEvents: [
      '大运转正印', '大运转偏印', '大运转伤官',
      '紫微大限转正印', '紫微大限转偏印', '紫微大限转伤官',
    ],
    variants: {
      '大运转正印': 'yes',     '紫微大限转正印': 'yes',
      '大运转偏印': 'yes',     '紫微大限转偏印': 'yes',
      '大运转伤官': 'no',      '紫微大限转伤官': 'no',
    },
    rawQuestion: '你 {age} 岁那年（{year}）有没有依赖过某个长辈/前辈/学习体系，或者重新回到学习、修养、慢生活的状态？',
  },
];
