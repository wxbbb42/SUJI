import { beijingDateString, fromBeijingParts, getCalendarPillars, currentSolarTermAt, getSolarTerms, toSolar, sexagenaryIndex, lunarCalendarWarnings } from '../precision';
import { BaziEngine } from '../../bazi/BaziEngine';
import { DayunEngine } from '../../bazi/DayunEngine';
import { equationOfTime, getTrueSolarTimeInfo } from '../../bazi/TrueSolarTime';

const engine = new BaziEngine();
const instant = (s: string) => new Date(`${s}+08:00`);
const names = (date: Date, gender: '男'|'女'='男', longitude?: number) => {
  const p = engine.calculate(date,gender,longitude);
  return ['year','month','day','hour'].map(k => {const g=p.siZhu[k as keyof typeof p.siZhu].ganZhi;return g.gan+g.zhi;});
};

describe('independent calendrical regressions', () => {
  it('uses Li-chun instant, not the whole date; Astronomy Engine agrees within one minute', () => {
    // lunar-js 16:27:07 CST; independent Astronomy Engine 16:26:49 CST (see research artifact).
    expect(names(instant('2024-02-04T12:00:00')).slice(0,2)).toEqual(['癸卯','乙丑']);
    expect(names(instant('2024-02-04T18:00:00')).slice(0,2)).toEqual(['甲辰','丙寅']);
    const spring=getSolarTerms(2024).find(t=>t.name==='立春')!.instant;
    expect(currentSolarTermAt(new Date(+spring-1000))).toBe('大寒');
    expect(currentSolarTermAt(spring)).toBe('立春');
  });
  it('keeps original instant for year/month even when solar correction crosses Li-chun', () => {
    const birth=instant('2024-02-04T16:30:00');
    const solar=getTrueSolarTimeInfo(birth,87.6).trueSolarTime;
    expect(solar.getTime()).toBeLessThan(instant('2024-02-04T16:27:07').getTime());
    expect(names(birth,'男',87.6).slice(0,2)).toEqual(['甲辰','丙寅']);
    expect(names(birth,'男',87.6)[3]).toBe(getCalendarPillars(birth,{solarTime:solar}).hour);
  });
  it('fixes both forward and reverse qi-yun, keeping exact offsets and start dates', () => {
    const birth=instant('1990-08-15T10:00:00');
    const female=engine.calculate(birth,'女'),male=engine.calculate(birth,'男');
    expect(female.qiYun).toMatchObject({years:2,months:5,days:6,hours:6,startDate:'1993-01-21T08:00:00.000Z',termName:'立秋'});
    expect(male.qiYun).toMatchObject({years:7,months:11,days:8,hours:2,startDate:'1998-07-23T04:00:00.000Z',termName:'白露'});
    expect(female.daYunStartAge).not.toBe(34);
    expect(male.daYunStartAge).not.toBe(1);
  });
  it('fixes the independently observed 1995 January screen case and does not invent a pre-start da-yun', () => {
    const p=engine.calculate(instant('1995-01-01T12:00:00'),'女',121.5);
    expect(p.qiYun).toMatchObject({years:8,months:3,days:8,hours:4,startDate:'2003-04-09T08:00:00.000Z'});
    const dy=new DayunEngine(p);
    expect(dy.getDaYunStatusAt(instant('1996-01-01T12:00:00'))).toEqual({status:'before-start',daYun:null});
    const start=new Date(p.daYunList[0].startDate!);
    expect(dy.getCurrentDaYunAt(new Date(+start-1))).toBeNull();
    expect(dy.getCurrentDaYunAt(start)).toBe(p.daYunList[0]);
    expect(dy.getCurrentDaYunAt(new Date(p.daYunList[0].endDate!))).toBe(p.daYunList[1]);
  });
  it('matches an independent Julian-day sexagenary formula for 804 civil noon dates', () => {
    // JDN+49 modulo 60: calendrical arithmetic, independent of either lunar library.
    const dy=new DayunEngine(engine.calculate(instant('1990-08-15T10:00:00'),'男'));
    for(let year=1901;year<=2099;year+=3) for(let month=1;month<=12;month++) {
      const d=fromBeijingParts(year,month,15,12);
      const jdn=Math.floor(Date.UTC(year,month-1,15)/86400000+2440587.5+0.5);
      const expected=(jdn+49)%60;
      const actual=dy.getLiuRi(d).ganZhi;
      expect(sexagenaryIndex(actual.gan+actual.zhi)).toBe(expected);
    }
  });
  it('declares Zi-hour rollover independently from civil lunar date', () => {
    const before=instant('2024-02-09T22:59:59'),after=instant('2024-02-09T23:00:00');
    expect(getCalendarPillars(before).day).toBe('癸卯');
    expect(getCalendarPillars(after).day).toBe('甲辰');
    expect(getCalendarPillars(after,{dayBoundary:'midnight'}).day).toBe('癸卯');
    expect(toSolar(after).getLunar().getDay()).toBe(30);
    expect(toSolar(instant('2024-02-10T00:00:00')).getLunar().getDay()).toBe(1);
  });
  it('uses fixed Beijing date labels for UTC instants regardless of host timezone', () => {
    expect(beijingDateString(new Date('2026-09-18T16:30:00Z'))).toBe('2026-09-19');
    expect(names(new Date('2026-09-19T04:00:00Z'))).toEqual(['丙午','丁酉','丙申','甲午']);
  });
  it('provides twelve exact jie intervals and does not call 寅月 Gregorian January', () => {
    const dy=new DayunEngine(engine.calculate(instant('1990-08-15T10:00:00'),'男'));
    const months=dy.getLiuYue(2024);
    expect(months).toHaveLength(12);
    expect(months[0]).toMatchObject({month:1,solarTerm:'立春',startDate:'2024-02-04T08:27:07.000Z'});
    expect(months[11].solarTerm).toBe('小寒');
    for(let i=0;i<11;i++) expect(months[i].endDate).toBe(months[i+1].startDate);
    expect(getSolarTerms(2024)[23].instant.toISOString()).toBe('2024-12-21T09:20:35.000Z');
  });
  it('rejects unsupported dates and invalid longitude instead of fabricated fallback data', () => {
    expect(()=>engine.calculate(instant('1900-12-31T12:00:00'),'男')).toThrow(/1901/);
    expect(()=>engine.calculate(new Date(NaN),'男')).toThrow();
    expect(()=>getTrueSolarTimeInfo(instant('2024-01-01T12:00:00'),181)).toThrow(/经度/);
    expect(()=>getTrueSolarTimeInfo(instant('2024-01-01T12:00:00'),NaN)).toThrow(/经度/);
  });
  it('distinguishes traditional rule families and preserves known near-midnight lunar uncertainty', () => {
    const p=engine.calculate(instant('1995-01-01T12:00:00'),'女');
    expect(p.interpretationPolicy?.strengthYongShen).toContain('工程启发式');
    expect(p.interpretationPolicy?.structureYongShen).toContain('月令');
    expect(p.calculationPolicy?.solarTimeScope).toBe('day-and-hour-only');
    expect(lunarCalendarWarnings(instant('2057-10-15T12:00:00'))).toHaveLength(1);
    expect(equationOfTime(instant('2025-02-11T12:00:00'))).toBeLessThan(-14);
    expect(equationOfTime(instant('2025-11-03T12:00:00'))).toBeGreaterThan(16);
  });
  it('allows bounded internal solar-time projection across supported civil endpoints', () => {
    const cases = [
      { date: '1901-01-01T00:10:00', longitude: 87.62, projectedYear: 1900 },
      { date: '1901-01-01T00:10:00', longitude: -180, projectedYear: 1900 },
      { date: '2100-12-31T23:50:00', longitude: 180, projectedYear: 2101 },
    ];
    for (const item of cases) {
      const civil = instant(item.date);
      const projected = getTrueSolarTimeInfo(civil, item.longitude).trueSolarTime;
      expect(beijingDateString(projected).startsWith(String(item.projectedYear))).toBe(true);
      const result = engine.calculate(civil, '女', item.longitude);
      expect([result.siZhu.year, result.siZhu.month].map(z => z.ganZhi.gan + z.ganZhi.zhi)).toEqual(names(civil, '女').slice(0, 2));
      // Independent JDN formula applied to the projected civil date, with 23:00 rollover.
      const wall = new Date(projected.getTime() + 8 * 3600000);
      const jdn = Math.floor(Date.UTC(wall.getUTCFullYear(), wall.getUTCMonth(), wall.getUTCDate()) / 86400000 + 2440588);
      const expectedDay = (jdn + 49 + (wall.getUTCHours() >= 23 ? 1 : 0)) % 60;
      expect(sexagenaryIndex(result.siZhu.day.ganZhi.gan + result.siZhu.day.ganZhi.zhi)).toBe(expectedDay);
    }
  });
  it('keeps out-of-range user civil dates rejected even when a correction could move them inside', () => {
    expect(() => engine.calculate(instant('1900-12-31T23:50:00'), '男', 180)).toThrow(/1901/);
    expect(() => engine.calculate(instant('2101-01-01T00:10:00'), '女', -180)).toThrow(/2100/);
    expect(() => toSolar(instant('1900-12-31T23:50:00'))).toThrow(/1901/);
    expect(() => toSolar(instant('2101-01-01T00:10:00'))).toThrow(/2100/);
    expect(() => getCalendarPillars(instant('1901-01-01T12:00:00'), { solarTime: instant('1900-12-25T12:00:00') })).toThrow(/24小时/);
  });
});
