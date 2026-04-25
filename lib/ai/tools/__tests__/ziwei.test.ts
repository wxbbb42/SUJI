import { ziweiTools, ziweiHandlers } from '../ziwei';

const FIXTURE_ZIWEI_PAN = {
  palaces: [
    {
      name: '命宫', position: '寅', ganZhi: '甲寅',
      mainStars: [{ name: '紫微', brightness: '庙', type: 'major' }],
      minorStars: [], isShenGong: false,
    },
    {
      name: '夫妻宫', position: '子', ganZhi: '甲子',
      mainStars: [{ name: '武曲', brightness: '旺', type: 'major', sihua: ['化忌'] }],
      minorStars: [], isShenGong: false,
    },
    {
      name: '子女宫', position: '亥', ganZhi: '癸亥',
      mainStars: [
        { name: '紫微', brightness: '庙', type: 'major' },
        { name: '天府', brightness: '旺', type: 'major' },
      ],
      minorStars: [], isShenGong: false,
    },
  ],
};

const CTX = { mingPan: null, ziweiPan: FIXTURE_ZIWEI_PAN, now: new Date() };

describe('ziweiTools', () => {
  it('exports 1 tool', () => {
    expect(ziweiTools).toHaveLength(1);
    expect(ziweiTools[0].function.name).toBe('get_ziwei_palace');
  });
});

describe('get_ziwei_palace handler', () => {
  it('returns 命宫 palace data', async () => {
    const r = await ziweiHandlers.get_ziwei_palace({ palace: '命宫' }, CTX) as any;
    expect(r.palace).toBe('命宫');
    expect(r.mainStars).toContain('紫微');
  });

  it('returns 夫妻宫 with sihua when withFlying=true', async () => {
    const r = await ziweiHandlers.get_ziwei_palace(
      { palace: '夫妻宫', withFlying: true }, CTX
    ) as any;
    expect(r.sihua).toBeDefined();
    expect(r.sihua).toContain('武曲化忌');
  });

  it('returns "not found" for unknown palace', async () => {
    const r = await ziweiHandlers.get_ziwei_palace({ palace: '财帛宫' }, CTX) as any;
    expect(r.error).toBeDefined();
  });

  it('returns no_chart message when ziweiPan is null', async () => {
    const r = await ziweiHandlers.get_ziwei_palace(
      { palace: '命宫' },
      { mingPan: null, ziweiPan: null, now: new Date() },
    ) as any;
    expect(r.error).toBeDefined();
  });
});
