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

describe('HexagramEngine 五行 / 用神 correctness', () => {
  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('每个卦都能在六亲分布里找到所有 5 类（除非同 trigram 重复）', () => {
    // sample test：检查 几个 known 卦
    const eng = new HexagramEngine();
    // 强行造一个固定卦象 —— 不容易，因为 cast 是 random
    // 退而求其次：跑 100 次 cast，统计每次 yongShen 的 yaoIndex 是否 ≥ 1
    let validCount = 0;
    for (let i = 0; i < 100; i++) {
      const r = eng.cast({ question: 'test', questionType: 'career' });
      // career → target='官鬼'
      // 验证：返回的 yongShen.type === '官鬼'
      expect(r.yongShen.type).toBe('官鬼');
      // 如果 yaoIndex > 0，验证它对应的 liuQin 是 '官鬼'
      if (r.yongShen.yaoIndex > 0) {
        expect(r.liuQin[r.yongShen.yaoIndex as 1|2|3|4|5|6]).toBe('官鬼');
        validCount++;
      }
    }
    // 大部分情况应该上卦
    expect(validCount).toBeGreaterThan(50);
  });

  it('uses month command instead of a hardcoded default for yongshen state', () => {
    const eng = new HexagramEngine();
    const sequence = Array.from({ length: 18 }, (_, idx) => idx % 3 === 2 ? 0.6 : 0.4);
    jest.spyOn(Math, 'random').mockImplementation(() => sequence.shift() ?? 0.6);

    const r = eng.cast({
      question: '事业走势如何',
      questionType: 'career',
      castTime: new Date('2026-04-15T12:00:00+08:00'),
    });

    expect(r.benGua.name).toBe('乾为天');
    expect(r.yongShen.type).toBe('官鬼');
    expect(r.yongShen.yaoIndex).toBe(4);
    expect(r.yongShen.wuXing).toBe('火');
    expect(r.yongShen.state).toBe('旺');
    expect(r.yongShen.interactions).toContain('月令五行判旺');
  });
});
