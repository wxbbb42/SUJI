import { extractZiweiEventsForCandidate } from '../extractZiweiEvents';
import { buildCandidates } from '../buildCandidates';

describe('Ziwei decade facts without Bazi interpretation', () => {
  it('uses actual palace, stem/branch and natal stars at nominal-age boundaries', () => {
    const origin = buildCandidates(new Date('1995-08-15T19:30:00+08:00'), '男', 116.4)[1];
    const events = extractZiweiEventsForCandidate(origin, 2026);
    // Frozen directly from iztro's palace table: 土五局, ages5/15/25, not age+birthYear.
    expect(events).toEqual({
      1999: '紫微大限转入本命命宫（丙戌；本命主星：无主星；虚岁5–14，农历1999年起）',
      2009: '紫微大限转入本命兄弟宫（乙酉；本命主星：廉贞、破军；虚岁15–24，农历2009年起）',
      2019: '紫微大限转入本命夫妻宫（甲申；本命主星：无主星；虚岁25–34，农历2019年起）',
    });
    expect(events[2010]).toBeUndefined();
  });

  it('uses the prior lunar birth year for a January birth before Chinese New Year', () => {
    const origin = buildCandidates(new Date('1990-01-08T14:00:00+08:00'), '女', 121.5)[1];
    expect(origin.astrolabe.rawDates.lunarDate.lunarYear).toBe(1989);
    const events = extractZiweiEventsForCandidate(origin, 2003);
    expect(events).toEqual({
      1993: '紫微大限转入本命命宫（庚午；本命主星：巨门；虚岁5–14，农历1993年起）',
      2003: '紫微大限转入本命父母宫（辛未；本命主星：天相；虚岁15–24，农历2003年起）',
    });
    const before = origin.astrolabe.horoscope('2003-01-31');
    const after = origin.astrolabe.horoscope('2003-02-01');
    expect(before.age.nominalAge).toBe(14);
    expect(after.age.nominalAge).toBe(15);
    expect(origin.astrolabe.palaces[before.decadal.index].name).toBe('命宫');
    expect(origin.astrolabe.palaces[after.decadal.index].name).toBe('父母');
  });

  it('is independent of the Bazi day stem and does not translate palace stems into Ten Gods', () => {
    const origin = buildCandidates(new Date('1995-08-15T19:30:00+08:00'), '男', 116.4)[1];
    const expected = extractZiweiEventsForCandidate(origin, 2026);
    const changed = { ...origin, mingPan: { ...origin.mingPan, riZhu: { ...origin.mingPan.riZhu, gan: '甲' as const } } };
    expect(extractZiweiEventsForCandidate(changed, 2026)).toEqual(expected);
    expect(Object.values(expected).join()).not.toMatch(/大限转(?:七杀|正官|伤官|食神|比肩|劫财|正印|偏印|正财|偏财)/);
  });

  it('does not emit transitions after the requested year', () => {
    const origin = buildCandidates(new Date('1995-08-15T19:30:00+08:00'), '男', 116.4)[1];
    expect(extractZiweiEventsForCandidate(origin, 1998)).toEqual({});
    expect(Object.keys(extractZiweiEventsForCandidate(origin, 2008))).toEqual(['1999']);
  });
});
