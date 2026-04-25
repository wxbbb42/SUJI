import { QimenEngine } from '../QimenEngine';

describe('QimenEngine setup', () => {
  const engine = new QimenEngine();

  it('returns a valid QimenChart with required fields', () => {
    const r = engine.setup({
      question: '我要不要换城市',
      questionType: 'event',
      setupTime: new Date('2026-04-25T15:32:00'),
    });
    expect(r.palaces).toHaveLength(9);
    expect(r.yinYangDun).toMatch(/^[阳阴]$/);
    expect(r.juNumber).toBeGreaterThanOrEqual(1);
    expect(r.juNumber).toBeLessThanOrEqual(9);
    expect(['上','中','下']).toContain(r.yuan);
    expect(r.jieqi).toBeTruthy();
  });

  it('每个外宫（非中宫）都有 8 门 / 9 星 / 8 神', () => {
    const r = engine.setup({
      question: 'test', questionType: 'general',
      setupTime: new Date('2026-04-25T15:32:00'),
    });
    for (const p of r.palaces) {
      if (p.id === 5) continue; // 中宫无门
      expect(p.bamen).not.toBeNull();
      expect(p.jiuxing).not.toBeNull();
      expect(p.bashen).not.toBeNull();
    }
  });

  it('八门 8 个不重复（中宫除外）', () => {
    const r = engine.setup({
      question: 'test', questionType: 'general',
      setupTime: new Date('2026-04-25T15:32:00'),
    });
    const mens = r.palaces.filter(p => p.id !== 5).map(p => p.bamen);
    expect(new Set(mens).size).toBe(8);
  });

  it('八神 8 个不重复（中宫除外）', () => {
    const r = engine.setup({
      question: 'test', questionType: 'general',
      setupTime: new Date('2026-04-25T15:32:00'),
    });
    const shens = r.palaces.filter(p => p.id !== 5).map(p => p.bashen);
    expect(new Set(shens).size).toBe(8);
  });

  it('returns deterministic chart for same input', () => {
    const a = engine.setup({
      question: 'test', questionType: 'general',
      setupTime: new Date('2026-04-25T15:32:00'),
    });
    const b = engine.setup({
      question: 'test', questionType: 'general',
      setupTime: new Date('2026-04-25T15:32:00'),
    });
    expect(a.juNumber).toBe(b.juNumber);
    expect(a.yinYangDun).toBe(b.yinYangDun);
  });
});
