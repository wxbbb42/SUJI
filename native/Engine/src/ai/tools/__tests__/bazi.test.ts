import { baziTools, baziHandlers } from '../bazi';

const FIXTURE_MING_PAN = {
  // 简化的 fixture，含 BaziEngine 输出的最小子集
  riZhu: { gan: '庚', wuXing: '金', yinYang: '阳', description: '...' },
  siZhu: {
    year: { ganZhi: { gan: '庚', zhi: '午' }, shiShen: '比肩' },
    month: { ganZhi: { gan: '甲', zhi: '申' }, shiShen: '偏财' },
    day: { ganZhi: { gan: '庚', zhi: '辰' }, shiShen: '日主' },
    hour: { ganZhi: { gan: '丙', zhi: '子' }, shiShen: '七杀' },
  },
  wuXingStrength: { yongShen: '水', xiShen: '木', jiShen: '土' },
  geJu: { name: '伤官生财', category: '正格', strength: '中', description: '', modernMeaning: '' },
  daYunList: [
    { startAge: 3, endAge: 12, ganZhi: { gan: '癸', zhi: '未' }, shiShen: '伤官', period: '3-12岁' },
    { startAge: 13, endAge: 22, ganZhi: { gan: '壬', zhi: '午' }, shiShen: '食神', period: '13-22岁' },
  ],
  shenSha: [
    { name: '红鸾', type: '吉', position: '日支辰', description: '', modernMeaning: '' },
    { name: '驿马', type: '中性', position: '年支午', description: '', modernMeaning: '' },
  ],
  branchRelations: [
    { type: '六合', branches: ['辰', '酉'], positions: ['日支-月支'] },
  ],
};

const CTX = { mingPan: FIXTURE_MING_PAN, ziweiPan: null, now: new Date(2026, 3, 25) };

describe('baziTools', () => {
  it('exports 4 tools', () => {
    expect(baziTools.length).toBe(4);
    expect(baziTools.map(t => t.function.name).sort()).toEqual(
      ['get_bazi_star', 'get_timing', 'get_today_context', 'list_shensha']
    );
  });
});

describe('get_bazi_star handler', () => {
  it('returns 子女 (food star) info', async () => {
    const r = await baziHandlers.get_bazi_star({ person: '子女' }, CTX) as any;
    expect(r.person).toBe('子女');
    expect(typeof r.summary).toBe('string');
  });
});

describe('list_shensha handler', () => {
  it('returns all shensha when no kind', async () => {
    const r = await baziHandlers.list_shensha({}, CTX) as any;
    expect(r.list.length).toBe(2);
  });

  it('filters by kind=吉', async () => {
    const r = await baziHandlers.list_shensha({ kind: '吉' }, CTX) as any;
    expect(r.list.every((s: any) => s.type === '吉')).toBe(true);
  });
});

describe('get_timing handler', () => {
  it('returns current_dayun', async () => {
    const r = await baziHandlers.get_timing({ scope: 'current_dayun' }, CTX) as any;
    expect(r.scope).toBe('current_dayun');
    expect(r.data).toBeDefined();
  });

  it('returns all_dayun list', async () => {
    const r = await baziHandlers.get_timing({ scope: 'all_dayun' }, CTX) as any;
    expect(r.scope).toBe('all_dayun');
    expect(r.data.length).toBe(2);
  });
});

describe('get_today_context handler', () => {
  it('returns today ganzhi', async () => {
    const r = await baziHandlers.get_today_context({}, CTX) as any;
    expect(r.todayGanZhi).toBeDefined();
    expect(typeof r.todayGanZhi).toBe('string');
  });
});
