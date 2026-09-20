/**
 * 紫微侧工具实现
 */
import type { ToolDefinition, ToolHandler } from './types';
import { palaceFacts, palaceContext } from '../../ziwei/context';

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
];

export const ziweiHandlers: Record<string, ToolHandler> = {
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
