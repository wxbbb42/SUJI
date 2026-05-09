import { deserializeMingPanCache, deserializeZiweiPanCache, serializeMingPanCache, serializeZiweiPanCache } from '../cache';

describe('mingli cache codecs', () => {
  it('revives legacy MingPan birthDateTime and marks it migrated', () => {
    const raw = JSON.stringify({
      birthDateTime: '2026-01-01T00:00:00.000Z',
      siZhu: {},
      riZhu: {},
      wuXingStrength: {},
    });
    const out = deserializeMingPanCache(raw);
    expect(out.migrated).toBe(true);
    expect(out.value?.birthDateTime instanceof Date).toBe(true);
  });

  it('round-trips versioned ZiweiPan cache', () => {
    const pan = {
      birthDateTime: new Date('2026-01-01T00:00:00.000Z'),
      gender: '女' as const,
      palaces: Array.from({ length: 12 }, (_, i) => ({
        name: `${i}宫`,
        position: '子',
        ganZhi: '甲子',
        mainStars: [],
        minorStars: [],
        isShenGong: false,
      })),
      mingGongPosition: '子',
      shenGongPosition: '丑',
      fiveElementsClass: '水二局',
    };
    const out = deserializeZiweiPanCache(serializeZiweiPanCache(pan as any));
    expect(out.migrated).toBe(false);
    expect(out.value?.birthDateTime instanceof Date).toBe(true);
  });

  it('serializes MingPan with a schema envelope', () => {
    const raw = serializeMingPanCache({
      birthDateTime: new Date('2026-01-01T00:00:00.000Z'),
      siZhu: {},
      riZhu: {},
      wuXingStrength: {},
    } as any);
    expect(JSON.parse(raw)).toMatchObject({ kind: 'mingPan', schemaVersion: 1 });
  });
});

