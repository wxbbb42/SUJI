import { BaziEngine } from '../BaziEngine';
import { computeRiZhuStructure, computeStrengthRelation } from '../structural';
import type { DiZhi, RootStrengthLabel, StrengthRelation, WuXing } from '../types';

describe('reproducible weighted-count strength evidence', () => {
  const engine = new BaziEngine();

  it('explains all thirteen actual contributions and counts the day master exactly once', () => {
    const p = engine.calculate(new Date('1990-08-15T10:00:00+08:00'), '女');
    expect(Object.values(p.siZhu).map(z => z.ganZhi.gan + z.ganZhi.zhi)).toEqual(['庚午', '甲申', '壬子', '乙巳']);
    const e = p.wuXingStrength.evidence!;
    expect(e.contributions.map(x => [x.pillar, x.source, x.gan, x.weight, x.relation])).toEqual([
      ['year', 'stem', '庚', 1, 'resource'], ['month', 'stem', '甲', 1, 'output'],
      ['day', 'stem', '壬', 1, 'peer'], ['hour', 'stem', '乙', 1, 'output'],
      ['year', 'hidden-stem', '丁', 0.7, 'wealth'], ['year', 'hidden-stem', '己', 0.3, 'officer'],
      ['month', 'hidden-stem', '庚', 0.6, 'resource'], ['month', 'hidden-stem', '壬', 0.2, 'peer'],
      ['month', 'hidden-stem', '戊', 0.2, 'officer'], ['day', 'hidden-stem', '癸', 1, 'peer'],
      ['hour', 'hidden-stem', '丙', 0.6, 'wealth'], ['hour', 'hidden-stem', '戊', 0.2, 'officer'],
      ['hour', 'hidden-stem', '庚', 0.2, 'resource'],
    ]);
    expect(e.elementTotals).toEqual({ 金: 1.8, 木: 2, 水: 2.2, 火: 1.3, 土: 0.7 });
    expect(e.relationTotals).toEqual({ peer: 2.2, resource: 1.8, output: 2, wealth: 1.3, officer: 0.7 });
    expect(e).toMatchObject({ supportTotal: 4, drainTotal: 4, total: 8, dayMasterContribution: 1, supportExcludingDayMaster: 3, monthWeightApplied: false });
    expect(e.contributions.filter(x => x.isDayMaster)).toEqual([
      { pillar: 'day', source: 'stem', gan: '壬', zhi: '子', element: '水', weight: 1, relation: 'peer', isDayMaster: true },
    ]);
    expect(p.wuXingStrength).toMatchObject({ riZhuStrong: true, yongShen: '土', xiShen: '火', jiShen: '水' });
  });

  it.each([
    ['10', { 金: 1.2, 木: 2, 水: 0, 火: 1.3, 土: 3.5 }, 4.8, 3.2, true, ['木', '水', '土']],
    ['12', { 金: 2, 木: 2, 水: 0, 火: 1.4, 土: 2.6 }, 4, 4, true, ['木', '水', '土']],
    ['14', { 金: 2, 木: 2.2, 水: 0, 火: 0.9, 土: 2.9 }, 3.8, 4.2, false, ['火', '土', '木']],
  ] as const)('uses the declared >= threshold and matching Fuyi choice at %s:00', (hour, totals, support, drain, strong, choice) => {
    // 12:00 is the former float failure: 2.6 + 1.4 was accumulated as
    // 3.9999999999999996, incorrectly selecting false at an exact 4:4 tie.
    const p = engine.calculate(new Date(`1990-03-15T${hour}:00:00+08:00`), '男');
    const s = p.wuXingStrength;
    expect(s.riZhuStrong).toBe(strong);
    expect(s.evidence?.elementTotals).toEqual(totals);
    expect(s.evidence).toMatchObject({ supportTotal: support, drainTotal: drain, total: 8, threshold: 'supportTotal >= drainTotal' });
    expect([s.yongShen, s.xiShen, s.jiShen]).toEqual(choice);
  });

  it('conserves all contribution groups across stems, hidden stems, elements and directions', () => {
    const dates = ['1990-03-15T12:00:00+08:00', '1990-08-15T10:00:00+08:00', '1995-05-01T12:00:00+08:00', '2024-02-04T16:30:00+08:00',
      ...Array.from({ length: 12 }, (_, i) => `2000-${String(i + 1).padStart(2, '0')}-15T12:00:00+08:00`)];
    const seenBranches = new Set<DiZhi>();
    for (const date of dates) {
      const p = engine.calculate(new Date(date), '女');
      const e = p.wuXingStrength.evidence!;
      const units = (n: number) => Math.round(n * 10);
      for (const x of e.contributions) {
        expect(Number.isInteger(x.weight * 10)).toBe(true);
        seenBranches.add(x.zhi);
      }
      expect(e.contributions.reduce((sum, x) => sum + units(x.weight), 0)).toBe(80);
      expect(Object.values(e.elementTotals).reduce((sum, x) => sum + units(x), 0)).toBe(80);
      expect(Object.values(e.relationTotals).reduce((sum, x) => sum + units(x), 0)).toBe(80);
      expect(units(e.supportTotal) + units(e.drainTotal)).toBe(80);
      for (const pillar of ['year', 'month', 'day', 'hour'] as const) {
        const items = e.contributions.filter(x => x.pillar === pillar);
        expect(items.filter(x => x.source === 'stem')).toHaveLength(1);
        expect(items.filter(x => x.source === 'hidden-stem').map(x => [x.gan, x.element, x.weight])).toEqual(p.siZhu[pillar].cangGan.map(x => [x.gan, x.wuXing, x.weight]));
        expect(items.reduce((sum, x) => sum + units(x.weight), 0)).toBe(20);
        expect(items.every(x => x.zhi === p.siZhu[pillar].ganZhi.zhi)).toBe(true);
      }
      for (const [element, total] of Object.entries(e.elementTotals)) expect(
        e.contributions.filter(x => x.element === element).reduce((sum, x) => sum + units(x.weight), 0),
      ).toBe(units(total));
      for (const [relation, total] of Object.entries(e.relationTotals)) expect(
        e.contributions.filter(x => x.relation === relation).reduce((sum, x) => sum + units(x.weight), 0),
      ).toBe(units(total));
    }
    expect(seenBranches.size).toBe(12);
  });

  it('keeps accumulation independent of property order and preserves all ties', () => {
    const p = engine.calculate(new Date('1990-03-15T12:00:00+08:00'), '男');
    // The production method can receive reordered SiZhu properties; this must
    // not alter accumulation or arbitrarily replace the single day-master row.
    const siZhu = { hour: p.siZhu.hour, day: p.siZhu.day, month: p.siZhu.month, year: p.siZhu.year };
    const actual = (engine as unknown as { computeWuXingStrength: (s: typeof siZhu, g: '己', z: '卯') => typeof p.wuXingStrength }).computeWuXingStrength(siZhu, '己', '卯');
    expect(actual).toEqual(p.wuXingStrength);
    expect(actual.evidence?.strongestElements).toEqual(['土']);
    expect(actual.evidence?.weakestElements).toEqual(['水']);
    // Hand-counted algebra fixture (not a claimed birth date): four 己卯
    // pillars give 土4/木4 and 金水火0, so both max and min are tied.
    const equal = { year: p.siZhu.day, month: p.siZhu.day, day: p.siZhu.day, hour: p.siZhu.day };
    const tied = (engine as unknown as { computeWuXingStrength: (s: typeof equal, g: '己', z: '卯') => typeof p.wuXingStrength }).computeWuXingStrength(equal, '己', '卯');
    expect(tied).toMatchObject({ strongest: '木', weakest: '金', riZhuStrong: true });
    expect(tied.evidence).toMatchObject({ strongestElements: ['木', '土'], weakestElements: ['金', '水', '火'], supportTotal: 4, drainTotal: 4 });
  });
});

describe('direction and root-band evidence', () => {
  it.each<[WuXing, WuXing[]]>([
    ['木', ['木', '水', '火', '土', '金']], ['火', ['火', '木', '土', '金', '水']],
    ['土', ['土', '火', '金', '水', '木']], ['金', ['金', '土', '水', '木', '火']],
    ['水', ['水', '金', '木', '火', '土']],
  ])('distinguishes 生我/我生 and 克我/我克 for %s', (day, targets) => {
    const want: StrengthRelation[] = ['peer', 'resource', 'output', 'wealth', 'officer'];
    expect(targets.map(x => computeStrengthRelation(day, x))).toEqual(want);
  });

  it.each<[DiZhi[], number, RootStrengthLabel]>([
    [['巳', '巳', '巳', '巳'], 0, '无根'], [['巳', '巳', '巳', '未'], 0.2, '无根'],
    [['巳', '巳', '未', '未'], 0.4, '微根'], [['巳', '未', '未', '未'], 0.6, '微根'],
    [['丑', '巳', '巳', '未'], 0.7, '弱根'], [['子', '巳', '未', '未'], 1.4, '弱根'],
    [['子', '丑', '巳', '巳'], 1.5, '中根'], [['子', '子', '未', '未'], 2.4, '中根'],
    [['子', '子', '丑', '巳'], 2.5, '强根'],
  ])('makes the reported half-open root band agree with %j', (branches, total, label) => {
    const r = computeRiZhuStructure('甲', ['庚', '丙', '甲', '己'], branches as [DiZhi, DiZhi, DiZhi, DiZhi]);
    expect(r.rootStrength.totalRoot).toBeCloseTo(total, 10);
    expect(r.rootStrength.label).toBe(label);
    const bands = r.evidence!.rootLabelBands.filter(x => total >= x.lowerInclusive && (x.upperExclusive === null || total < x.upperExclusive));
    expect(bands.map(x => x.label)).toEqual([label]);
    expect(r.evidence!.sameElementRoots.reduce((sum, x) => sum + x.weight, 0)).toBeCloseTo(r.rootStrength.bijieRoot, 10);
    expect(r.evidence!.resourceSupport.reduce((sum, x) => sum + x.weight, 0)).toBeCloseTo(r.rootStrength.yinRoot, 10);
  });
});
