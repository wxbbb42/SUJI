import { liuyaoTools, liuyaoHandlers } from '../liuyao';

const CTX = { mingPan: null, ziweiPan: null, now: new Date(2026, 3, 25) };

describe('liuyaoTools', () => {
  it('exports cast_liuyao', () => {
    expect(liuyaoTools).toHaveLength(1);
    expect(liuyaoTools[0].function.name).toBe('cast_liuyao');
  });
});

describe('cast_liuyao handler', () => {
  it('returns a HexagramReading', async () => {
    const r = await liuyaoHandlers.cast_liuyao(
      { question: '我应该接 X offer 吗', questionType: 'career' }, CTX,
    ) as any;
    expect(r.benGua).toBeDefined();
    expect(r.bianGua).toBeDefined();
    expect(r.benGua.yao).toHaveLength(6);
    expect(r.yongShen).toBeDefined();
    expect(r.yongShen.type).toBe('官鬼'); // career → 官鬼
  });

  it('defaults questionType to general when missing', async () => {
    const r = await liuyaoHandlers.cast_liuyao(
      { question: 'test' }, CTX,
    ) as any;
    expect(r.questionType).toBe('general');
  });
});
