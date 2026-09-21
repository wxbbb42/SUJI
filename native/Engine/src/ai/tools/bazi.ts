/**
 * 八字侧工具实现
 *
 * 4 个工具：get_bazi_star, list_shensha, get_timing, get_today_context
 */
import type { ToolDefinition, ToolHandler } from './types';
import { annualCycle, annualReference, activeSolarYear } from './annual';
import { DayunEngine } from '@engine/bazi/DayunEngine';
import { beijingDateParts, beijingDateString, getCalendarPillars, currentSolarTermAt, getSolarTerms } from '../../calendar/precision';
import type { MingPan } from '@engine/bazi/types';

export const baziTools: ToolDefinition[] = [
  {
    type: 'function',
    function: {
      name: 'get_bazi_star',
      description: '获取某六亲星位的状态。用于"婚姻/子女/父母"等关系类问题。',
      parameters: {
        type: 'object',
        additionalProperties: false,
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
        additionalProperties: false,
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
        additionalProperties: false,
        properties: {
          scope: {
            type: 'string',
            enum: ['current_dayun', 'all_dayun', 'liunian', 'liuyue'],
          },
          yearRange: {
            type: 'array',
            description: '当 scope=liunian 时使用的年份区间 [开始年, 结束年]，1901–2100，最多跨20年',
            items: { type: 'integer', minimum: 1901, maximum: 2100 },
            minItems: 2, maxItems: 2,
          },
          year: {
            type: 'integer', minimum: 1901, maximum: 2100,
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
      description: '获取提问时刻北京时间的干支、节气、日干十神关系，用于"今日运势"类问题。',
      parameters: { type: 'object', additionalProperties: false, properties: {} },
    },
  },
];

const PILLAR_LABELS: Record<string,string> = {year:'年', month:'月', day:'日', hour:'时'};

export const baziHandlers: Record<string, ToolHandler> = {
  get_bazi_star: ({ person }, { mingPan }) => {
    if (!mingPan) return {error:'no_bazi_chart'};
    const male = mingPan.gender === '男';
    const mapping: Record<string,string[]> = {
      配偶: male ? ['正财','偏财'] : ['正官','七杀'],
      子女: male ? ['正官','七杀'] : ['食神','伤官'],
      父母: ['偏财','正印'], 兄弟: ['比肩','劫财'],
    };
    const targetShiShen = mapping[person as string];
    if (!targetShiShen) return { person, error: 'unknown person' };
    const positions: string[] = [];
    const hiddenPositions: string[] = [];
    for (const [pillar,val] of Object.entries((mingPan as MingPan).siZhu)) {
      // The day stem defines the observer; it is not a sibling star in the chart.
      if (pillar !== 'day' && targetShiShen.includes(val.shiShen))
        positions.push(`${PILLAR_LABELS[pillar]}柱 ${val.ganZhi.gan}${val.ganZhi.zhi}（${val.shiShen}）`);
      for (const hidden of val.cangGan ?? []) if (targetShiShen.includes(hidden.shiShen))
        hiddenPositions.push(`${PILLAR_LABELS[pillar]}支${val.ganZhi.zhi}藏${hidden.gan}（${hidden.shiShen}）`);
    }
    return {
      person, relevantShiShen: targetShiShen, positionsInChart: positions, hiddenPositions,
      correspondencePolicy: '传统六亲对应：男财女官论配偶、男官杀女子食伤论子女、偏财父正印母；流派有异，不代表现实家庭角色或性别认同。',
      summary: positions.length ? `${person}对应十神透于${positions.join('、')}`
        : hiddenPositions.length ? `${person}对应十神未透干，藏于${hiddenPositions.join('、')}`
        : '四柱天干及藏干未检出本口径对应星；不据此推断现实亲缘有无。',
    };
  },
  list_shensha: ({kind}, {mingPan}) => {
    if (!mingPan) return {error:'no_bazi_chart'};
    const all = (mingPan.shenSha ?? []) as Array<any>;
    const k = (kind ?? 'all') as string;
    const categories: Record<string,string[]> = {桃花:['桃花','红鸾','天喜'],权贵:['天乙贵人','天德贵人','月德贵人','将星','禄神'],文昌:['文昌'],驿马:['驿马']};
    const list = k === 'all' ? all : all.filter(s => s.type === k || (categories[k] ?? [k]).some(name => s.name?.includes(name)));
    return {kind:k,list:list.map(s=>({name:s.name,type:s.type,position:s.position})), note:'神煞为辅助传统符号，不能独立断吉凶或健康。'};
  },
  get_timing: ({scope,yearRange,year}, {mingPan,now}) => {
    if (!mingPan) return {error:'no_bazi_chart'};
    const engine = new DayunEngine(mingPan as MingPan);
    const currentYear = beijingDateParts(now).year;
    const reference = {referenceDate:now.toISOString(),qiYun:mingPan.qiYun,calendar:'立春换年、精确交节换月；节气月序号不等于公历月份'};
    if (scope === 'current_dayun') {
      const {status,daYun}=engine.getDaYunStatusAt(now);
      return {scope,...reference,status,data:daYun};
    }
    if (scope === 'all_dayun') return {scope,...reference,data:mingPan.daYunList};
    if (scope === 'liunian') {
      const [start,end] = (yearRange as number[]|undefined) ?? [Math.max(1901,activeSolarYear(now)),Math.min(2100,activeSolarYear(now)+5)];
      const data=[];
      for(let y=start;y<=end;y++) {
        const at = annualReference(y,now);
        const ln=engine.getCurrentLiuNian(y,at);
        data.push({...ln,ganZhi:`${ln.ganZhi.gan}${ln.ganZhi.zhi}`,referenceDate:at.toISOString(),annualCycle:annualCycle(y,now),daYunStatus:engine.getDaYunStatusAt(at).status});
      }
      return {scope,...reference,data,note:'当前生效的立春年度以提问时刻选大运；其他年度以年中作参考。公历元旦至立春前仍属上一流年，交运前后须分别核对。'};
    }
    if (scope === 'liuyue') {
      const y=(year as number|undefined) ?? currentYear;
      return {scope,...reference,year:y,data:engine.getLiuYue(y).map(ly=>({...ly,ganZhi:`${ly.ganZhi.gan}${ly.ganZhi.zhi}`}))};
    }
    return {scope,error:'unknown scope'};
  },
  get_today_context: (_args,{mingPan,now}) => {
    const pillars=getCalendarPillars(now);
    const day = mingPan ? new DayunEngine(mingPan as MingPan).getLiuRi(now) : null;
    const terms = [...getSolarTerms(beijingDateParts(now).year-1),...getSolarTerms(beijingDateParts(now).year),...getSolarTerms(beijingDateParts(now).year+1)];
    const next = terms.find(t=>t.instant>now)!;
    const previous = terms.filter(t=>t.instant<=now).pop()!;
    return {
      solarTermInterval:{name:previous.name,startDate:previous.instant.toISOString(),nextName:next.name,endDate:next.instant.toISOString()},
      date:beijingDateString(now),referenceDate:now.toISOString(),timezone:'UTC+08:00',
      todayGanZhi:pillars.day,yearGanZhi:pillars.year,monthGanZhi:pillars.month,
      solarTerm:currentSolarTermAt(now),dayBoundary:'子初23:00换日',
      dayInteraction: day ? `今日天干${day.ganZhi.gan}相对日主${mingPan!.riZhu.gan}为${day.shiShen}` : null,
      note:'十神关系属于历法与传统分类；不直接表示一天的吉凶。',
    };
  },
};
