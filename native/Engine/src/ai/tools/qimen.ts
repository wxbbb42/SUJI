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
      description: '为战略级重大决策起一局奇门盘（"要不要换城市/移民/换行业/创业"等）。返回拆补法转盘的 9 宫、值符值使、用神初选、格局与方法说明。应期证据不足时不会给出固定期限；派别差异和取用限制必须保留。',
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
