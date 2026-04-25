/**
 * 八字侧工具实现
 *
 * 4 个工具：get_bazi_star, list_shensha, get_timing, get_today_context
 */
import type { ToolDefinition, ToolHandler } from './types';
import { DayunEngine } from '@/lib/bazi/DayunEngine';
import type { MingPan } from '@/lib/bazi/types';

export const baziTools: ToolDefinition[] = [
  {
    type: 'function',
    function: {
      name: 'get_bazi_star',
      description: '获取某六亲星位的状态。用于"婚姻/子女/父母"等关系类问题。',
      parameters: {
        type: 'object',
        properties: {
          person: {
            type: 'string',
            description: '六亲对象',
            enum: ['配偶', '子女', '父母', '兄弟'],
          },
        },
        required: ['person'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'list_shensha',
      description: '查命盘中的神煞。可按吉/凶/中性筛选，或按名称类别（桃花/权贵/文昌/驿马）筛选。',
      parameters: {
        type: 'object',
        properties: {
          kind: {
            type: 'string',
            description: '筛选类别',
            enum: ['吉', '凶', '中性', '桃花', '权贵', '文昌', '驿马', 'all'],
          },
        },
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_timing',
      description: '获取大运/流年/流月信息，用于"何时"类问题。',
      parameters: {
        type: 'object',
        properties: {
          scope: {
            type: 'string',
            enum: ['current_dayun', 'all_dayun', 'liunian', 'liuyue'],
          },
          yearRange: {
            type: 'array',
            description: '当 scope=liunian 时使用的年份区间 [开始年, 结束年]',
            items: { type: 'number' },
          },
          year: {
            type: 'number',
            description: '当 scope=liuyue 时使用的目标年份',
          },
        },
        required: ['scope'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_today_context',
      description: '获取今日干支和与命盘的交互（神煞当令、流月引动），用于"今日运势"类问题。',
      parameters: { type: 'object', properties: {} },
    },
  },
];

const PERSON_TO_SHISHEN: Record<string, string[]> = {
  配偶: ['正官', '七杀', '正财', '偏财'],
  子女: ['食神', '伤官'],
  父母: ['正印', '偏印'],
  兄弟: ['比肩', '劫财'],
};

export const baziHandlers: Record<string, ToolHandler> = {
  get_bazi_star: ({ person }, { mingPan }) => {
    const targetShiShen = PERSON_TO_SHISHEN[person as string];
    if (!targetShiShen) return { person, error: 'unknown person' };

    // 在四柱中找到所有命中的十神位
    const positions: string[] = [];
    if (mingPan?.siZhu) {
      for (const [pillar, val] of Object.entries(mingPan.siZhu) as [string, any][]) {
        if (val?.shiShen && targetShiShen.includes(val.shiShen)) {
          positions.push(`${pillar}柱 ${val.ganZhi?.gan ?? ''}${val.ganZhi?.zhi ?? ''}（${val.shiShen}）`);
        }
      }
    }

    return {
      person,
      relevantShiShen: targetShiShen,
      positionsInChart: positions,
      summary: positions.length > 0
        ? `${person}星出现在 ${positions.join('、')}`
        : `${person}星不显（暗藏地支或不见）`,
    };
  },

  list_shensha: ({ kind }, { mingPan }) => {
    const all = (mingPan?.shenSha ?? []) as Array<any>;
    const k = (kind ?? 'all') as string;
    const list = k === 'all'
      ? all
      : all.filter(s => s.type === k || s.name?.includes(k));
    return {
      kind: k,
      list: list.map(s => ({ name: s.name, type: s.type, position: s.position })),
    };
  },

  get_timing: ({ scope, yearRange, year }, { mingPan, now }) => {
    const dayunList = (mingPan?.daYunList ?? []) as Array<any>;
    const currentAge = now.getFullYear() - new Date(mingPan?.birthDateTime ?? Date.now()).getFullYear();

    if (scope === 'current_dayun') {
      const cur = dayunList.find(d => currentAge >= d.startAge && currentAge <= d.endAge);
      return { scope, data: cur ?? null };
    }

    if (scope === 'all_dayun') {
      return {
        scope,
        data: dayunList.map(d => ({
          period: d.period,
          ganZhi: `${d.ganZhi?.gan}${d.ganZhi?.zhi}`,
          shiShen: d.shiShen,
        })),
      };
    }

    if (scope === 'liunian') {
      const [start, end] = (yearRange as number[] | undefined)
        ?? [now.getFullYear(), now.getFullYear() + 5];
      // 用 DayunEngine 算流年（含十神 + 与命盘的冲合刑害互动），而非简化干支轮转
      try {
        const engine = new DayunEngine(mingPan as MingPan);
        const data = [];
        for (let y = start; y <= end; y++) {
          const ln = engine.getCurrentLiuNian(y);
          data.push({
            year: ln.year,
            ganZhi: `${ln.ganZhi.gan}${ln.ganZhi.zhi}`,
            shiShen: ln.shiShen,
            interactions: ln.interactions,
          });
        }
        return { scope, data };
      } catch (e: any) {
        return { scope, error: `liunian_compute_failed: ${e?.message ?? e}` };
      }
    }

    if (scope === 'liuyue') {
      const y = (year as number | undefined) ?? now.getFullYear();
      // 用 DayunEngine 算流月
      try {
        const engine = new DayunEngine(mingPan as MingPan);
        const liuyueList = engine.getLiuYue(y);
        const data = liuyueList.map(ly => ({
          month: ly.month,
          ganZhi: `${ly.ganZhi.gan}${ly.ganZhi.zhi}`,
          shiShen: ly.shiShen,
          zhiShiShen: ly.zhiShiShen,
        }));
        return { scope, year: y, data };
      } catch (e: any) {
        return { scope, year: y, error: `liuyue_compute_failed: ${e?.message ?? e}` };
      }
    }

    return { scope, error: 'unknown scope' };
  },

  get_today_context: (_args, { mingPan, now }) => {
    const todayGZ = dateToGanZhi(now);
    return {
      date: now.toISOString().slice(0, 10),
      todayGanZhi: todayGZ,
      // 与日主关系（简要）
      dayInteraction: mingPan?.riZhu?.gan
        ? describeInteraction(mingPan.riZhu.gan, todayGZ)
        : null,
    };
  },
};

// ────────────────────────────────────────────────────────
// 简化的天干地支推算（fallback 公式）
// ────────────────────────────────────────────────────────

const TIANGAN = ['甲', '乙', '丙', '丁', '戊', '己', '庚', '辛', '壬', '癸'];
const DIZHI = ['子', '丑', '寅', '卯', '辰', '巳', '午', '未', '申', '酉', '戌', '亥'];

function yearToGanZhi(year: number): string {
  // 1984 是甲子年
  const offset = (year - 1984) % 60;
  const adj = offset < 0 ? offset + 60 : offset;
  return TIANGAN[adj % 10] + DIZHI[adj % 12];
}

function monthToGanZhi(year: number, month: number): string {
  // 简化：以年干推月干起例（甲己之年丙作首）
  const yearGan = TIANGAN.indexOf(yearToGanZhi(year)[0]);
  const monthGanStart = (yearGan % 5) * 2 + 2; // 甲己=丙(2), 乙庚=戊(4), 丙辛=庚(6), 丁壬=壬(8), 戊癸=甲(0)
  const gan = TIANGAN[(monthGanStart + month - 1) % 10];
  const zhi = DIZHI[(month + 1) % 12]; // 正月寅
  return gan + zhi;
}

function dateToGanZhi(d: Date): string {
  // 1900-01-01 是甲戌日（约定，便于计算）
  const epoch = new Date(1900, 0, 1).getTime();
  const days = Math.floor((d.getTime() - epoch) / 86400000);
  const offset = (10 + days) % 60;
  const adj = offset < 0 ? offset + 60 : offset;
  return TIANGAN[adj % 10] + DIZHI[adj % 12];
}

function describeInteraction(riZhuGan: string, todayGZ: string): string {
  const todayGan = todayGZ[0];
  if (todayGan === riZhuGan) return '今日同我，比肩之日';
  return `今日 ${todayGan}，与日主 ${riZhuGan} 有微妙交互`;
}
