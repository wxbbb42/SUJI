/**
 * 紫微侧工具实现
 */
import type { ToolDefinition, ToolHandler } from './types';
import { palaceFacts, palaceContext } from '../../ziwei/context';
import { ziweiTiming } from '../../ziwei/timing';
import { assertCalendarRange, beijingDateString } from '../../calendar/precision';

export const ziweiTools: ToolDefinition[] = [
  {
    type: 'function',
    function: {
      name: 'get_ziwei_palace',
      description: '查紫微本命某宫及三方四正的实际星曜、亮度、身宫、生年四化来源。空宫提供对宫参照，不移动星曜。不含宫干飞化或流年四化。',
      parameters: {
        type: 'object',
        additionalProperties: false,
        properties: {
          palace: {
            type: 'string',
            description: '宫位名称',
            enum: [
              '命宫', '兄弟宫', '夫妻宫', '子女宫',
              '财帛宫', '疾厄宫', '迁移宫', '仆役宫',
              '官禄宫', '田宅宫', '福德宫', '父母宫',
            ],
          },
          withSihua: {
            type: 'boolean',
            description: '是否返回本宫星曜四化标签',
          },
          withFlying: {
            type: 'boolean',
            description: '旧参数名，兼容等同 withSihua；不包含飞入/飞出宫位关系',
          },
        },
        required: ['palace'],
      },
    },
  },
  {
    type:'function',function:{name:'get_ziwei_timing',
      description:'从固定紫微档案查大限和流年：虚岁、当前大限宫干四化、流年干四化、太岁所在本命宫。农历正月换年，与八字 get_timing 分开；不含小限、流月、流曜或完整宫干飞化。',
      parameters:{type:'object',additionalProperties:false,properties:{date:{type:'string',minLength:10,maxLength:10,description:'可选公历日期 YYYY-MM-DD（1901–2100），按北京时间当日12:00查询。不传使用提问时刻，含子初23点换日。农历年前后须明确具体日期。'}}},
    },
  },
];

export const ziweiHandlers: Record<string, ToolHandler> = {
  get_ziwei_timing: ({date}, {ziweiPan,now}) => {
    if (!ziweiPan) return {error:'no_ziwei_chart'};
    let reference = now;
    if (date!==undefined) {
      if (typeof date!=='string' || !/^\d{4}-\d{2}-\d{2}$/.test(date)) throw new Error('紫微查询日期须为 YYYY-MM-DD');
      reference = new Date(`${date}T12:00:00+08:00`);
      assertCalendarRange(reference);
      if (beijingDateString(reference)!==date) throw new Error('紫微查询日期无效');
    }
    return {...ziweiTiming(ziweiPan,reference),referenceMode:date===undefined?'question-instant':'explicit-date-noon'};
  },
  get_ziwei_palace: ({ palace, withSihua, withFlying }, { ziweiPan }) => {
    if (!ziweiPan) {
      return { palace, error: 'no_ziwei_chart' };
    }
    const target = (ziweiPan.palaces ?? []).find((p: any) => p.name === palace);
    if (!target) {
      return { palace, error: 'palace_not_found' };
    }

    const result: any = {
      ...palaceFacts(target, ziweiPan),
      ...palaceContext(target, ziweiPan),
      method: ziweiPan.method,
      note: (target.mainStars ?? []).length === 0 ? "本宫无主星；须结合对宫与三方四正，不等于此领域不存在。" : undefined,
    };

    if (withSihua || withFlying) {
      const sihua: string[] = [];
      for (const s of [...(target.mainStars ?? []), ...(target.minorStars ?? [])]) {
        if (s.sihua && s.sihua.length > 0) {
          for (const h of s.sihua) sihua.push(`${s.name}${h}`);
        }
      }
      result.sihua = sihua;
    }

    return result;
  },
};
