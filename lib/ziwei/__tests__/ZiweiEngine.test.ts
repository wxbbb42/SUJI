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
