import { SHICHEN_MAP, computeShichenVibe, currentShichenIndex } from '../shichen';
import type { MingPanSummary } from '../shichen';

describe('SHICHEN_MAP', () => {
  it('has exactly 12 entries', () => {
    expect(SHICHEN_MAP).toHaveLength(12);
  });

  it('starts with 子 ending with 亥', () => {
    expect(SHICHEN_MAP[0].zhi).toBe('子');
    expect(SHICHEN_MAP[11].zhi).toBe('亥');
  });
});

describe('computeShichenVibe', () => {
  const mp = (yongShen: any, xiShen: any, jiShen: any): MingPanSummary => ({
    yongShen, xiShen, jiShen,
  });

  it('returns 旺 for 用神 match with strong suitable verb', () => {
    const date = new Date(2026, 0, 1);
    const entry = SHICHEN_MAP.find(s => s.zhi === '寅')!;
    const vibe = computeShichenVibe(entry, mp('木', '水', '金'), date);
    expect(vibe.level).toBe('旺');
    expect(['行动', '开启', '进取', '谈判']).toContain(vibe.suitable);
  });

  it('returns 弱 for 忌神 match with recessive verb', () => {
    const date = new Date(2026, 0, 1);
    const entry = SHICHEN_MAP.find(s => s.zhi === '寅')!;
    const vibe = computeShichenVibe(entry, mp('土', '火', '木'), date);
    expect(vibe.level).toBe('弱');
    expect(['静心', '休整', '独处', '观照']).toContain(vibe.suitable);
  });

  it('returns 平 with default suitable when no match', () => {
    const date = new Date(2026, 0, 1);
    const entry = SHICHEN_MAP.find(s => s.zhi === '寅')!;
    const vibe = computeShichenVibe(entry, mp('土', '水', '金'), date);
    expect(vibe.level).toBe('平');
    expect(vibe.suitable).toBe(entry.defaultSuitable);
  });

  it('returns deterministic suitable for same date', () => {
    const date = new Date(2026, 0, 1);
    const entry = SHICHEN_MAP[0];
    const a = computeShichenVibe(entry, mp('水', '木', '火'), date);
    const b = computeShichenVibe(entry, mp('水', '木', '火'), date);
    expect(a.suitable).toBe(b.suitable);
  });
});

describe('currentShichenIndex', () => {
  it('maps 03:30 to 寅 (index 2)', () => {
    const d = new Date();
    d.setHours(3, 30, 0, 0);
    expect(currentShichenIndex(d)).toBe(2);
  });

  it('maps 23:30 to 子 (index 0)', () => {
    const d = new Date();
    d.setHours(23, 30, 0, 0);
    expect(currentShichenIndex(d)).toBe(0);
  });

  it('maps 00:30 to 子 (index 0)', () => {
    const d = new Date();
    d.setHours(0, 30, 0, 0);
    expect(currentShichenIndex(d)).toBe(0);
  });
});
