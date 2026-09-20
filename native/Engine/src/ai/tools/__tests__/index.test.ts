import { ALL_TOOLS, ALL_HANDLERS, TOOL_STRATEGY } from '../index';
import { BaziEngine } from '../../../bazi/BaziEngine';

const FIX_MP = {
  riZhu: { gan: '庚', wuXing: '金', yinYang: '阳', description: '' },
  siZhu: {
    year: { ganZhi: { gan: '庚', zhi: '午' }, shiShen: '比肩' },
    month: { ganZhi: { gan: '甲', zhi: '申' }, shiShen: '偏财' },
    day: { ganZhi: { gan: '庚', zhi: '辰' }, shiShen: '日主' },
    hour: { ganZhi: { gan: '丙', zhi: '子' }, shiShen: '七杀' },
  },
  wuXingStrength: { yongShen: '水', xiShen: '木', jiShen: '土' },
  geJu: { name: '伤官生财', category: '正格', strength: '中' },
  daYunList: [],
  shenSha: [{ name: '红鸾', type: '吉', position: '日支' }],
};

const FIX_ZW = {
  palaces: [
    { name: '子女宫', position: '亥', ganZhi: '癸亥',
      mainStars: [{ name: '紫微', brightness: '庙' }], minorStars: [], isShenGong: false },
    { name: '夫妻宫', position: '子', ganZhi: '甲子',
      mainStars: [{ name: '武曲', sihua: ['化忌'] }], minorStars: [], isShenGong: false },
  ],
};

const CTX = { mingPan: FIX_MP, ziweiPan: FIX_ZW, now: new Date(2026, 3, 25) };

describe('ALL_TOOLS', () => {
  it('exposes the ten registered tools with bounded natal astronomy', () => {
    expect(ALL_TOOLS).toHaveLength(10);
    const names = ALL_TOOLS.map(t => t.function.name).sort();
    expect(names).toEqual([
      'cast_liuyao', 'get_bazi_star', 'get_domain', 'get_natal_astronomy', 'get_timing',
      'get_today_context', 'get_ziwei_palace', 'get_ziwei_timing', 'list_shensha', 'setup_qimen',
    ]);
  });
});

describe('TOOL_STRATEGY', () => {
  it('is a non-empty string', () => {
    expect(typeof TOOL_STRATEGY).toBe('string');
    expect(TOOL_STRATEGY.length).toBeGreaterThan(50);
  });
});

describe('get_domain handler', () => {
  it('keeps reproducible counting and month/root evidence in the serialized tool receipt', async () => {
    const mingPan = new BaziEngine().calculate(new Date('1990-08-15T10:00:00+08:00'), '女');
    const result = await ALL_HANDLERS.get_domain({ domain: '事业' }, { ...CTX, mingPan });
    const r = JSON.parse(JSON.stringify(result));
    expect(r.bazi.strengthReference.evidence).toMatchObject({ supportTotal: 4, drainTotal: 4, total: 8, dayMasterContribution: 1 });
    expect(r.bazi.structureReference).toMatchObject({
      yueLingState: '相', rootStrength: { bijieRoot: 1.5, yinRoot: 1.2, totalRoot: 2.7 },
      evidence: { monthMainQi: '庚', monthRelation: 'resource', hasSameElementRoot: true, hasResourceSupport: true },
    });
    expect(r.bazi.strengthReference.evidence.contributions).toHaveLength(13);
    expect(r.bazi.structureReference.evidence.sameElementRoots).toHaveLength(2);
    expect(r.bazi.structureReference.evidence.resourceSupport).toHaveLength(2);
  });

  it('returns 子女 domain bundle', async () => {
    const r = await ALL_HANDLERS.get_domain({ domain: '子女' }, CTX) as any;
    expect(r.domain).toBe('子女');
    expect(r.bazi).toBeDefined();
    expect(r.ziwei).toBeDefined();
    expect(r.shensha).toBeDefined();
  });

  it('returns 婚姻 domain with 夫妻宫 sihua', async () => {
    const r = await ALL_HANDLERS.get_domain({ domain: '婚姻' }, CTX) as any;
    expect(r.ziwei.palace).toBe('夫妻宫');
    expect(r.ziwei.sihua).toContain('武曲化忌');
  });

  it('returns error for unknown domain', async () => {
    const r = await ALL_HANDLERS.get_domain({ domain: '不存在' }, CTX) as any;
    expect(r.error).toBeDefined();
  });
});
