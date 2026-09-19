import { buildEvidenceFromToolCalls } from '../evidence';

function call(name: string, args: Record<string, unknown> = {}) {
  return { id: `call_${name}`, name, arguments: args };
}

describe('buildEvidenceFromToolCalls', () => {
  it('builds qimen evidence from structured chart result', () => {
    const evidence = buildEvidenceFromToolCalls([
      {
        call: call('setup_qimen'),
        result: {
          jieqi: '谷雨',
          yinYangDun: '阳',
          juNumber: 5,
          yongShen: { summary: '庚临艮宫（生门 · 天任 · 九地）' },
          geJu: [{ name: '飞鸟跌穴' }, { name: '青龙返首' }],
          yingQi: { description: '约 1-3 个月内见分晓' },
          method: { level: 'mvp' },
        },
      },
    ]);

    expect(evidence).toEqual([
      '节气 · 谷雨',
      '阳遁 · 5局',
      '用神 · 庚临艮宫（生门 · 天任 · 九地）',
      '格局 · 飞鸟跌穴',
      '格局 · 青龙返首',
      '应期 · 约 1-3 个月内见分晓',
    ]);
  });

  it('deduplicates and skips failed tool results', () => {
    const evidence = buildEvidenceFromToolCalls([
      { call: call('get_today_context'), result: { error: 'network' } },
      { call: call('get_today_context'), result: { ganZhi: '甲子', solarTerm: '立春' } },
      { call: call('get_today_context'), result: { ganZhi: '甲子' } },
    ]);

    expect(evidence).toEqual(['今日 · 甲子', '节气 · 立春']);
  });

  it('builds liuyao evidence from HexagramEngine result fields', () => {
    const evidence = buildEvidenceFromToolCalls([
      {
        call: call('cast_liuyao'),
        result: {
          benGua: { name: '水山蹇' },
          bianGua: { name: '水地比' },
          changingYao: [3],
        },
      },
    ]);

    expect(evidence).toEqual([
      '主卦 · 水山蹇',
      '变卦 · 水地比',
      '动爻 · 3',
    ]);
  });

  it('builds domain evidence from aggregated bazi, ziwei, and shensha results', () => {
    const evidence = buildEvidenceFromToolCalls([
      {
        call: call('get_domain', { domain: '婚姻' }),
        result: {
          domain: '婚姻',
          bazi: { summary: '配偶星出现在 month柱 甲申（偏财）' },
          ziwei: { palace: '夫妻宫', mainStars: ['武曲'], sihua: ['武曲化忌'] },
          shensha: { list: [{ name: '红鸾' }, { name: '天喜' }] },
        },
      },
    ]);

    expect(evidence).toEqual([
      '领域 · 婚姻',
      '宫位 · 夫妻宫',
      '主星 · 武曲',
      '四化 · 武曲化忌',
      '神煞 · 红鸾/天喜',
      '依据 · 配偶星出现在 month柱 甲申（偏财）',
    ]);
  });

  it('builds bazi star evidence from actual handler result fields', () => {
    const evidence = buildEvidenceFromToolCalls([
      {
        call: call('get_bazi_star', { person: '子女' }),
        result: {
          person: '子女',
          relevantShiShen: ['食神', '伤官'],
          positionsInChart: ['hour柱 丙子（七杀）'],
          summary: '子女星不显（暗藏地支或不见）',
        },
      },
    ]);

    expect(evidence).toEqual([
      '子女 · 食神/伤官',
      '位置 · hour柱 丙子（七杀）',
      '依据 · 子女星不显（暗藏地支或不见）',
    ]);
  });

  it('builds timing evidence from data payloads', () => {
    const evidence = buildEvidenceFromToolCalls([
      {
        call: call('get_timing', { scope: 'current_dayun' }),
        result: {
          scope: 'current_dayun',
          data: {
            period: '23-32岁',
            ganZhi: { gan: '壬', zhi: '午' },
            shiShen: '食神',
          },
        },
      },
    ]);

    expect(evidence).toEqual([
      '时间 · current_dayun',
      '干支 · 壬午',
      '十神 · 食神',
      '阶段 · 23-32岁',
    ]);
  });

  it('builds shensha and today evidence from actual handler result fields', () => {
    const evidence = buildEvidenceFromToolCalls([
      {
        call: call('list_shensha', { kind: '桃花' }),
        result: { kind: '桃花', list: [{ name: '红鸾' }, { name: '咸池' }] },
      },
      {
        call: call('get_today_context'),
        result: { todayGanZhi: '甲子', dayInteraction: '今日 甲，与日主 庚 有微妙交互' },
      },
    ]);

    expect(evidence).toEqual([
      '神煞 · 桃花',
      '星曜 · 红鸾/咸池',
      '今日 · 甲子',
      '互动 · 今日 甲，与日主 庚 有微妙交互',
    ]);
  });
});
