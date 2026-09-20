/**
 * 奇门遁甲起局工具实现
 *
 * 1 个工具：setup_qimen（包装 QimenEngine.setup）
 * 用于战略级重大决策（"要不要换城市/移民/换行业/创业"等）。
 */
import type { ToolDefinition, ToolHandler } from './types';
import { QimenEngine } from '@engine/qimen/QimenEngine';
import type { QuestionType } from '@engine/qimen/types';

export const qimenTools: ToolDefinition[] = [
  {
    type: 'function',
    function: {
      name: 'setup_qimen',
      description: '为战略级重大决策起一局奇门盘（"要不要换城市/移民/换行业/创业"等）。按本次提问物理时刻的北京时间标准时（UTC+08:00）起局，子初23:00换日；没有本次占测地点，不作真太阳时修正，不借用出生地。返回拆补转盘的9宫、值符值使、用神初选、格局、时旬空具体空支与支位覆盖、时马、门克宫关系及九星月令。starSeason与用神的宫干关系不同，空支覆盖不等于整宫无效；ruleSources提供采用的版本与出处。结构事实不足以断现实吉凶或固定应期。',
      parameters: {
        type: 'object',
        additionalProperties: false,
        properties: {
          question: { type: 'string', minLength: 1, maxLength: 1600, description: '用户的具体问题' },
          questionType: {
            type: 'string',
            enum: ['career', 'wealth', 'marriage', 'kids', 'parents', 'health', 'event', 'general'],
          },
          gender: {
            type: 'string',
            enum: ['男', '女'],
            description: 'questionType=marriage 时区分用神',
          },
        },
        required: ['question'],
      },
    },
  },
];

const engine = new QimenEngine();

export const qimenHandlers: Record<string, ToolHandler> = {
  setup_qimen: ({ question, questionType, gender }, ctx) => {
    const chart = engine.setup({
      question: String(question),
      questionType: (questionType as QuestionType | undefined) ?? 'general',
      gender: gender as '男' | '女' | undefined,
      setupTime: ctx.now,
    });
    return chart;
  },
};
