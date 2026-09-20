/**
 * 六爻起卦工具实现
 *
 * 1 个工具：cast_liuyao（包装 HexagramEngine.cast）
 */
import type { ToolDefinition, ToolHandler } from './types';
import { HexagramEngine } from '@engine/divination/HexagramEngine';
import type { QuestionContext } from '@engine/divination/questionJudgment';
import type { QuestionType } from '@engine/divination/types';

export const liuyaoTools: ToolDefinition[] = [
  {
    type: 'function',
    function: {
      name: 'cast_liuyao',
      description: '为单一具体事件起六爻卦。返回本变卦、动爻、纳甲、世应、六神和用神候选。本爻/变爻/伏神的context各自独立；rules提供回头生克、所选七组进退、飞伏与静爻日冲候选。conditions含matched/not-matched/unresolved及原始factPaths；conditionsFrom引用本盘同位共享条件。结构匹配不等于效力，暗动/日破候选和月建标签不等于综合旺衰；不能自动判伏出、吉凶或具体应期。questionContext记录明确所问对象/事件/远近；yongShen的candidates/related/excluded保留身份与理由，selectedCandidateId=null，不自动定用。yingQi只有条件触发支和未决前提，不是日期预测。请先澄清对象后起卦，同一问题补充资料不得重起卦。ruleSources提供版本及出处。',
      parameters: {
        type: 'object',
        additionalProperties: false,
        properties: {
          question: {
            type: 'string', minLength: 1, maxLength: 1600,
            description: '用户的具体问题（保留作为上下文，不影响起卦数学）',
          },
          questionType: {
            type: 'string',
            enum: ['career', 'wealth', 'marriage', 'kids', 'parents', 'health', 'event', 'general'],
            description: '问题类型，用于选用神。不确定时填 general',
          },
          subject: { type:'string', enum:['self','parent','child','sibling','wife','husband','other','unknown'], description:'所问人相对求问者的明确身份。只据用户明确资料；不能从gender推断；不明确填unknown或省略' },
          event: { type:'string', minLength:1, maxLength:200, description:'用户明确所问的单一事件，勿补造背景。未明确则省略并澄清' },
          timeHorizon: { type:'string', enum:['near','far','unspecified'], description:'用户明确近事/远事；未知用unspecified，不猜年月日时的单位' },
          gender: {
            type: 'string',
            enum: ['男', '女'],
            description: '兼容旧参数，不据性别推断伴侣身份；用明确的subject表示所问对象',
          },
        },
        required: ['question'],
      },
    },
  },
];

const engine = new HexagramEngine();

export const liuyaoHandlers: Record<string, ToolHandler> = {
  cast_liuyao: ({ question, questionType, gender, subject, event, timeHorizon }, ctx) => {
    const reading = engine.cast({
      question: String(question),
      questionType: (questionType as QuestionType | undefined) ?? 'general',
      gender: gender as '男' | '女' | undefined,
      castTime: ctx.now,
      questionContext: { subject:subject as QuestionContext['subject'], event:event as string|undefined, timeHorizon:timeHorizon as QuestionContext['timeHorizon'] },
    });
    return reading;
  },
};
