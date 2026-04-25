import { splitOrchestrationOutput } from '../preprocessOrchestration';

describe('splitOrchestrationOutput', () => {
  it('splits standard format', () => {
    const input = `[interpretation]
传统八字里，子女缘分看时柱与食神位。

[evidence]
子女星 · 食神
时柱 · 丙寅
当前大运 · 己亥`;
    const r = splitOrchestrationOutput(input);
    expect(r.interpretation).toContain('传统八字');
    expect(r.evidence).toEqual([
      '子女星 · 食神',
      '时柱 · 丙寅',
      '当前大运 · 己亥',
    ]);
  });

  it('returns interpretation only when [evidence] missing', () => {
    const input = `[interpretation]\n纯解读没有依据`;
    const r = splitOrchestrationOutput(input);
    expect(r.interpretation).toContain('纯解读');
    expect(r.evidence).toEqual([]);
  });

  it('falls back when no [interpretation] tag (whole text as interpretation)', () => {
    const input = '没有任何标签的内容';
    const r = splitOrchestrationOutput(input);
    expect(r.interpretation).toBe(input);
    expect(r.evidence).toEqual([]);
  });

  it('handles partial mid-stream input gracefully', () => {
    const input = `[interpretation]\n传统八字里，子女缘分`;
    const r = splitOrchestrationOutput(input);
    expect(r.interpretation).toBe('传统八字里，子女缘分');
    expect(r.evidence).toEqual([]);
  });

  it('trims empty lines from evidence', () => {
    const input = `[interpretation]\n解读\n\n[evidence]\n  \n子女星 · 食神\n  \n时柱 · 丙寅`;
    const r = splitOrchestrationOutput(input);
    expect(r.evidence).toEqual(['子女星 · 食神', '时柱 · 丙寅']);
  });
});
