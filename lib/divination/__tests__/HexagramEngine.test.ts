import { HexagramEngine } from '../HexagramEngine';

describe('HexagramEngine cast', () => {
  it('returns a valid HexagramReading with required fields', () => {
    const eng = new HexagramEngine();
    const r = eng.cast({ question: '我会得到这个 offer 吗', questionType: 'career' });
    expect(r.benGua).toBeDefined();
    expect(r.benGua.yao).toHaveLength(6);
    expect(r.bianGua).toBeDefined();
    expect(r.bianGua.yao).toHaveLength(6);
    expect(Array.isArray(r.changingYao)).toBe(true);
    expect(r.liuQin).toBeDefined();
    expect(Object.keys(r.liuQin)).toHaveLength(6);
  });

  it('bianGua === benGua when no changing yao', () => {
    const eng = new HexagramEngine();
    for (let i = 0; i < 100; i++) {
      const r = eng.cast({ question: 'test', questionType: 'general' });
      if (r.changingYao.length === 0) {
        expect(r.bianGua.code).toBe(r.benGua.code);
        return;
      }
    }
    // 概率 (3/4)^6 ≈ 18%，100 次必出
  });

  it('changing yaos flip yin↔yang in bianGua', () => {
    const eng = new HexagramEngine();
    for (let i = 0; i < 100; i++) {
      const r = eng.cast({ question: 'test', questionType: 'general' });
      if (r.changingYao.length > 0) {
        for (const idx of r.changingYao) {
          expect(r.bianGua.yao[idx - 1]).not.toBe(r.benGua.yao[idx - 1]);
        }
        return;
      }
    }
  });

  it('uses fixed castTime when provided', () => {
    const eng = new HexagramEngine();
    const fixed = new Date('2026-04-25T12:00:00');
    const r = eng.cast({ question: 'test', questionType: 'general', castTime: fixed });
    expect(r.castTime).toBe(fixed.toISOString());
  });
});
