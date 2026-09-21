/**
 * 奇门遁甲起局工具实现
 *
 * 1 个工具：setup_qimen（包装 QimenEngine.setup）
 * 用于战略级重大决策（"要不要换城市/移民/换行业/创业"等）。
 */
import type { ToolDefinition, ToolHandler } from './types';
import { QimenEngine } from '@engine/qimen/QimenEngine';
import type { QuestionType } from '@engine/qimen/types';
import type { QuestionContext } from '@engine/divination/questionJudgment';
import type { QimenTimingRequest } from '@engine/qimen/timing';

const timingRequestSchema={
  type:'object' as const,additionalProperties:false,required:['focus','event'],
  description:'仅在用户已明确应期对象及单一事件时传入。日期需要用户明确的时间单位和结束时刻；near/far不能代替单位，不能自行补造期限。',
  properties:{
    focus:{type:'string',enum:['employment','profit','relationship','self','explicit'],description:'employment为民事工作/单位；profit为经营利润，不代指所有财务；relationship为关系整体；self须明确问本人；explicit按候选与occurrence路径取一处'},
    event:{type:'string',minLength:1,maxLength:200,description:'用户明确的单一事项；条件日期不代表事项成功或失败'},
    object:{type:'object',additionalProperties:false,required:['candidateId','objectPath'],properties:{
      candidateId:{type:'string',minLength:1,maxLength:100},objectPath:{type:'string',minLength:1,maxLength:200},
    }},
    timeUnit:{type:'string',enum:['year','month','day','hour'],description:'用户明确的年/月/日/时辰；省略时只返回条件，不列日期'},
    window:{type:'object',additionalProperties:false,required:['end'],properties:{
      end:{type:'string',minLength:20,maxLength:35,description:'1901–2100范围内含秒和明确时区的ISO结束时刻；须晚于原起局时刻'},
      includeCurrent:{type:'boolean',description:'是否包含原起局所在的当前区间，默认false'},
      maxCandidates:{type:'integer',minimum:1,maximum:256,description:'默认32；达到返回上限时明确标记截断'},
    }},
  },
};

export const qimenTools: ToolDefinition[] = [
  {
    type: 'function',
    function: {
      name: 'setup_qimen',
      description: '为战略级重大决策起奇门盘。按本次提问物理时刻的北京时间标准时（UTC+08:00）起局，子初23:00换日；不借用出生地。返回拆补转盘9宫、值符值使、格局、时旬空覆盖、时马、门克宫及九星月令。questionContext保留明确对象/事件/远近；yongShen.candidates列日干、时干与类别参考，尚未定用，selectedCandidateId=null。每个occurrence有精确objectPath与地盘/天盘/寄干/中宫身份；甲保留原干和各自旬仪载体，中宫记录不是有效天盘。旧summary/state仅为单处干宫关系，不能代替候选或综合旺衰。取用映射是product-policy，非古籍已定断法。yingQi保留未决参考；仅用户明确应期对象、事件时传timingRequest，由timing返回同一对象的空先马、马先墓刑冲的条件，明确单位及有界窗口后列日期。所有日期仅为条件候选，outcomeEstablished=false；缺少适用规则时不列日期，不能移植六爻应期、按宫数或远近编造期限。同一问题后补资料沿用原始盘与参数，不重起。ruleSources提供电子来源及边界。',
      parameters: {
        type: 'object',
        additionalProperties: false,
        properties: {
          question: { type: 'string', minLength: 1, maxLength: 1600, description: '用户的具体问题' },
          questionType: {
            type: 'string',
            enum: ['career', 'wealth', 'marriage', 'kids', 'parents', 'health', 'event', 'general'],
          },
          subject: { type:'string', enum:['self','parent','child','sibling','wife','husband','other','unknown'], description:'用户明确的所问人身份；相对求问者，不从性别推断。不明确则省略或unknown' },
          event: { type:'string', minLength:1, maxLength:200, description:'用户明确的单一事件，不补造背景' },
          timeHorizon: { type:'string', enum:['near','far','unspecified'], description:'用户明确近事/远事；不据此自动选年月日时单位' },
          timingRequest:timingRequestSchema,
          gender: {
            type: 'string',
            enum: ['男', '女'],
            description: '兼容旧参数，不据性别推断伴侣身份或取用',
          },
        },
        required: ['question'],
      },
    },
  },
];

const engine = new QimenEngine();

export const qimenHandlers: Record<string, ToolHandler> = {
  setup_qimen: ({ question, questionType, gender, subject, event, timeHorizon, timingRequest }, ctx) => {
    const chart = engine.setup({
      question: String(question),
      questionType: (questionType as QuestionType | undefined) ?? 'general',
      gender: gender as '男' | '女' | undefined,
      setupTime: ctx.now,
      questionContext: { subject:subject as QuestionContext['subject'],event:event as string|undefined,timeHorizon:timeHorizon as QuestionContext['timeHorizon'] },
      timingRequest:timingRequest as QimenTimingRequest|undefined,
    });
    return chart;
  },
};
