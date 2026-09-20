import { qimenTools, qimenHandlers } from '../qimen';

const CTX = { mingPan: null, ziweiPan: null, now: new Date('2026-04-27T10:00:00+08:00') };

describe('qimenTools', () => {
  it('exports setup_qimen', () => {
    expect(qimenTools).toHaveLength(1);
    expect(qimenTools[0].function.name).toBe('setup_qimen');
  });
});

describe('setup_qimen handler', () => {
  it('forwards explicit question context without using gender as a substitute', async () => {
    const r = await qimenHandlers.setup_qimen({question:'代问父亲签约',questionType:'event',subject:'parent',event:'签约',timeHorizon:'near',gender:'女'},CTX) as any;
    expect(r.questionContext).toEqual({subject:'parent',event:'签约',timeHorizon:'near'});
    expect(r.yongShen.missingContext).toEqual(['proxy-perspective']);
  });
  it('returns a QimenChart', async () => {
    const r = await qimenHandlers.setup_qimen(
      { question: '我要不要换城市', questionType: 'event' }, CTX,
    ) as any;
    expect(r.palaces).toHaveLength(9);
    expect(r.yongShen).toBeDefined();
    expect(r.geJu).toBeDefined();
    expect(r.method).toEqual(expect.objectContaining({ level: 'standard' }));
    expect(r.method.caveats.length).toBeGreaterThan(0);
  });

  it('defaults questionType to general when missing', async () => {
    const r = await qimenHandlers.setup_qimen(
      { question: 'test' }, CTX,
    ) as any;
    expect(r.questionType).toBe('general');
  });
});
