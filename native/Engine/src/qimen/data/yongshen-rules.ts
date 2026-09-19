import type {QuestionType,BamenName,BashenName,JiuxingName} from '../types';

/** 取用参考点，不是充分的吉凶规则。分类只决定先展示哪些盘面事实。 */
export interface YongShenRule {
  questionType:QuestionType;
  primaryGan:'day'|'time';
  secondaryMen?:BamenName;
  secondaryShen?:BashenName;
  secondaryStar?:JiuxingName;
  description:string;
}

// 采用常见时家“日干为求问者、时干为所问之事”的取象口径。
// 开门事业、生门财、六合关系、禽芮病象/天心医药仅作象意参考。
// 不把八字“官星/印星”未经定义套进奇门，也不由用户性别推断伴侣角色。
// 来源范围和未完成的断法见 docs/mingli/validation/divination-research.md。
export const YONGSHEN_RULES:Record<QuestionType,YongShenRule> = {
  career:{questionType:'career',primaryGan:'day',secondaryMen:'开门',secondaryShen:'值符',description:'求问者日干与开门、值符作为事业参考点；不以庚固定代表官星'},
  wealth:{questionType:'wealth',primaryGan:'day',secondaryMen:'生门',description:'求问者日干与生门作为财务参考点；不能由单宫直接判断收益'},
  marriage:{questionType:'marriage',primaryGan:'day',secondaryShen:'六合',description:'求问者与六合关系参考；双方身份和关系状态需另行明确'},
  kids:{questionType:'kids',primaryGan:'day',description:'仅标出求问者；子女对象、年命与具体问题未明确，不预设子女星'},
  parents:{questionType:'parents',primaryGan:'day',description:'仅标出求问者；父母对象与年命未明确，不将日干当父母用神'},
  health:{questionType:'health',primaryGan:'day',secondaryStar:'天芮',description:'日干与天芮只是传统取象参考，不用于诊断、预后或治疗判断'},
  event:{questionType:'event',primaryGan:'time',description:'时干暂作所问之事的参考；具体对象和条件仍需明确'},
  general:{questionType:'general',primaryGan:'day',description:'日干暂作求问者参考；模糊问题尚未确定事件用神'},
};
