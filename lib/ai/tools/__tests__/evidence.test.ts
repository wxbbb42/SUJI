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
});
