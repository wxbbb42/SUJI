/**
 * 紫微侧工具实现
 */
import type { ToolDefinition, ToolHandler } from './types';

export const ziweiTools: ToolDefinition[] = [
  {
    type: 'function',
    function: {
      name: 'get_ziwei_palace',
      description: '查紫微 12 宫某宫的主星、辅星、四化。常用宫名：命宫、夫妻宫、子女宫、财帛宫、官禄宫、田宅宫、福德宫、迁移宫、疾厄宫、父母宫、兄弟宫、仆役宫。',
      parameters: {
        type: 'object',
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
          withFlying: {
            type: 'boolean',
            description: '是否返回四化飞入飞出信息',
          },
        },
        required: ['palace'],
      },
    },
  },
];

export const ziweiHandlers: Record<string, ToolHandler> = {
  get_ziwei_palace: ({ palace, withFlying }, { ziweiPan }) => {
    if (!ziweiPan) {
      return { palace, error: 'no_ziwei_chart' };
    }
    const target = (ziweiPan.palaces ?? []).find((p: any) => p.name === palace);
    if (!target) {
      return { palace, error: 'palace_not_found' };
    }

    const mainStars: string[] = (target.mainStars ?? []).map((s: any) => s.name);
    const mainStarsDetailed: string[] = (target.mainStars ?? []).map((s: any) =>
      `${s.name}${s.brightness ? `(${s.brightness})` : ''}`
    );
    const minorStars: string[] = (target.minorStars ?? []).map((s: any) => s.name);

    const result: any = {
      palace,
      position: target.position,
      ganZhi: target.ganZhi,
      mainStars,
      mainStarsDetailed,
      minorStars,
      isShenGong: target.isShenGong,
    };

    if (withFlying) {
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
