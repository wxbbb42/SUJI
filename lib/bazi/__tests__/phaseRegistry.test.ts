import { PhaseRegistry } from '../phaseRegistry';
import type { PhaseMeta } from '../types';

const baseMeta = (overrides: Partial<PhaseMeta> = {}): PhaseMeta => ({
  id: 'test_phase',
  nameCn: '测试格',
  school: 'ziping',
  dimension: 'power',
  source: '《子平真诠》论用神',
  ...overrides,
});

describe('PhaseRegistry (Phase 0.5)', () => {
  it('register valid meta succeeds', () => {
    const reg = new PhaseRegistry();
    reg.register(baseMeta());
    expect(reg.has('test_phase')).toBe(true);
    expect(reg.size()).toBe(1);
    expect(reg.get('test_phase')?.nameCn).toBe('测试格');
  });

  it('throws when source is empty', () => {
    const reg = new PhaseRegistry();
    expect(() => reg.register(baseMeta({ source: '' }))).toThrow(/缺古籍出处/);
    expect(() => reg.register(baseMeta({ source: '   ' }))).toThrow(/缺古籍出处/);
  });

  it('throws when source marked as 自创/原创', () => {
    const reg = new PhaseRegistry();
    expect(() => reg.register(baseMeta({ id: 'a', source: '自创规则' }))).toThrow(/不可标记为自创/);
    expect(() => reg.register(baseMeta({ id: 'b', source: '产品原创' }))).toThrow(/不可标记为自创/);
  });

  it('throws on duplicate id', () => {
    const reg = new PhaseRegistry();
    reg.register(baseMeta());
    expect(() => reg.register(baseMeta())).toThrow(/id 冲突/);
  });

  it('list returns all registered phases', () => {
    const reg = new PhaseRegistry();
    reg.register(baseMeta({ id: 'a' }));
    reg.register(baseMeta({ id: 'b', source: '《滴天髓》体用' }));
    expect(reg.list().map((m) => m.id).sort()).toEqual(['a', 'b']);
  });
});
