/**
 * 六爻起卦工具实现
 *
 * 1 个工具：cast_liuyao（包装 HexagramEngine.cast）
 */
import type { ToolDefinition, ToolHandler } from './types';
import { HexagramEngine } from '@engine/divination/HexagramEngine';
import type { QuestionType } from '@engine/divination/types';

export const liuyaoTools: ToolDefinition[] = [
  {
    type: 'function',
    function: {
      name: 'cast_liuyao',
      description: '为单一具体事件起一卦（六爻易经卜卦）。用于"该不该 X / 会不会 Y / X 这件事的结果"等决策类问题。返回本变卦、动爻、纳甲、世应、六神和用神候选；本爻、变爻、伏神各自的context包含旬空及月日临值、生克、冲合，不可混用对象。monthState只是月建五行关系，尚非综合旺衰。ruleSources提供规则版本及出处；证据不足时应期保持未定。',
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
          gender: {
            type: 'string',
            enum: ['男', '女'],
            description: '性别，仅在 questionType=marriage 时需要（女问看官鬼，男问看妻财）',
          },
        },
        required: ['question'],
      },
    },
  },
];

const engine = new HexagramEngine();

export const liuyaoHandlers: Record<string, ToolHandler> = {
  cast_liuyao: ({ question, questionType, gender }, ctx) => {
    const reading = engine.cast({
      question: String(question),
      questionType: (questionType as QuestionType | undefined) ?? 'general',
      gender: gender as '男' | '女' | undefined,
      castTime: ctx.now,
    });
    return reading;
  },
};
