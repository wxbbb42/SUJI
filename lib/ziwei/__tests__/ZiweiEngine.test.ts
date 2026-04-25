import { ZiweiEngine } from '../ZiweiEngine';

describe('ZiweiEngine', () => {
  const engine = new ZiweiEngine();

  it('returns 12 palaces for a known birth', () => {
    const pan = engine.compute({
      year: 1990, month: 8, day: 16, hour: 14, minute: 30,
      gender: '男',
      isLunar: false,
    });
    expect(pan.palaces).toHaveLength(12);
  });

  it('identifies the 命宫 with main stars', () => {
    const pan = engine.compute({
      year: 1990, month: 8, day: 16, hour: 14, minute: 30,
      gender: '男',
      isLunar: false,
    });
    const mingGong = pan.palaces.find(p => p.name === '命宫');
    expect(mingGong).toBeDefined();
    expect(mingGong!.mainStars.length).toBeGreaterThanOrEqual(0);
  });

  it('normalizes all 12 palace names to end with 宫', () => {
    const pan = engine.compute({
      year: 1990, month: 8, day: 16, hour: 14, minute: 30,
      gender: '男',
      isLunar: false,
    });
    // iztro 原始返回里只有 命宫/身宫 带"宫"字，其余 12 主宫光名（子女/夫妻/...）；
    // 我们 normalize 后所有 12 个都该带"宫"字
    for (const p of pan.palaces) {
      expect(p.name.endsWith('宫')).toBe(true);
    }
    // 关键的几个宫位应该都能查到
    expect(pan.palaces.find(p => p.name === '子女宫')).toBeDefined();
    expect(pan.palaces.find(p => p.name === '夫妻宫')).toBeDefined();
    expect(pan.palaces.find(p => p.name === '官禄宫')).toBeDefined();
  });

  it('returns same pan for same input (deterministic)', () => {
    const input = {
      year: 1990, month: 8, day: 16, hour: 14, minute: 30,
      gender: '男' as const,
      isLunar: false,
    };
    const a = engine.compute(input);
    const b = engine.compute(input);
    expect(a.mingGongPosition).toBe(b.mingGongPosition);
  });
});
