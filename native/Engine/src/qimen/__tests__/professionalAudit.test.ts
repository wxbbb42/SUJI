/**
 * Independent hand-worked cases: docs/mingli/validation/qimen-professional-audit.md.
 * No production calendar / rotation helper supplies the expected values.
 */
import { QimenEngine } from '../QimenEngine';
import { qimenHandlers } from '../../ai/tools/qimen';
import type { QimenChart } from '../types';

const engine = new QimenEngine();
const question = '请核对这次奇门起局的盘面';

describe('professional Qimen audit: explicit chart clock', () => {
  const seams = [
    {
      time: '2026-09-19T15:05:00.000Z', day: '丁酉', hour: '庚子', star: '天心', starPalace: 7, doorPalace: 9,
      solarDay: '丙申', solarHour: '己亥', solarStarPalace: 8, solarDoorPalace: 1,
    },
    {
      time: '2026-12-31T15:05:00.000Z', day: '庚辰', hour: '丙子', star: '天芮', starPalace: 8, doorPalace: 4,
      solarDay: '己卯', solarHour: '乙亥', solarStarPalace: 9, solarDoorPalace: 3,
    },
  ];

  it.each(seams)('uses unshifted Beijing standard time without a divination longitude: $time', async c => {
    const chart = await qimenHandlers.setup_qimen({ question }, {
      now: new Date(c.time), ziweiPan: null,
      // A birth location is not the current divination location.
      mingPan: { birthInfo: { longitude: 87.6, year: 1990, month: 1, day: 1, hour: 12, minute: 0 } },
    }) as QimenChart;
    expect(chart).toMatchObject({
      setupTime: c.time, calculationTime: c.time,
      dayGanZhi: c.day, hourGanZhi: c.hour,
      zhiFuStar: c.star, zhiFuPalaceId: c.starPalace, zhiShiPalaceId: c.doorPalace,
      method: { clockPolicy: 'beijing-standard', timezone: 'UTC+08:00', solarTermClock: 'physical-instant' },
    });
    expect(chart.trueSolarTime).toBeUndefined();
    expect(chart.method).not.toHaveProperty('longitude');
  });

  it.each(seams)('preserves a deliberately selected 116.4-degree apparent-solar chart: $time', c => {
    const chart = engine.setup({ question, questionType: 'general', setupTime: new Date(c.time), longitude: 116.4 });
    expect(chart).toMatchObject({
      setupTime: c.time, dayGanZhi: c.solarDay, hourGanZhi: c.solarHour,
      zhiFuStar: c.star, zhiFuPalaceId: c.solarStarPalace, zhiShiPalaceId: c.solarDoorPalace,
      method: { clockPolicy: 'apparent-solar', timezone: 'UTC+08:00', longitude: 116.4, solarTermClock: 'physical-instant' },
    });
    expect(chart.trueSolarTime).not.toBe(c.time);
    expect(chart.calculationTime).toBe(chart.trueSolarTime);
  });
});

describe('professional Qimen audit: independent four-chart arithmetic', () => {
  // Arrays are literal hand-worked palace 1...9 order; 中5 is a static reference.
  const cases = [
    {
      time: '2024-02-04T04:00:00Z', day: '戊戌', hour: '戊午', term: '大寒', dun: '阳', ju: 3, yuan: '上', fu: '甲午',
      earth: '丙 乙 戊 己 庚 辛 壬 癸 丁', sky: '辛 丁 癸 戊 庚 壬 乙 丙 己',
      doors: ['开门','景门','生门','伤门',null,'惊门','死门','休门','杜门'],
      chief: ['天任',8,3,'生门',8,3,3], host: 7, hosted: '庚', tombs: [], punishments: [],
    },
    {
      time: '2026-09-19T04:00:00Z', day: '丙申', hour: '甲午', term: '白露', dun: '阴', ju: 9, yuan: '上', fu: '甲午',
      earth: '乙 丙 丁 癸 壬 辛 庚 己 戊', sky: '乙 丙 丁 癸 壬 辛 庚 己 戊',
      doors: ['休门','死门','伤门','杜门',null,'开门','惊门','生门','景门'],
      chief: ['天心',6,6,'开门',6,6,6], host: 2, hosted: '壬', tombs: [8], punishments: [['癸击刑',[4]]],
    },
    {
      time: '2026-01-01T00:00:00Z', day: '乙亥', hour: '庚辰', term: '冬至', dun: '阳', ju: 4, yuan: '下', fu: '甲戌',
      earth: '丁 丙 乙 戊 己 庚 辛 壬 癸', sky: '辛 戊 丁 壬 己 丙 癸 庚 乙',
      doors: ['休门','死门','伤门','杜门',null,'开门','惊门','生门','景门'],
      chief: ['天禽',5,6,'死门',5,2,2], host: 6, hosted: '己', tombs: [4,6,8], punishments: [['庚击刑',[8]],['壬击刑',[4]]],
    },
    {
      time: '2026-06-21T10:00:00Z', day: '丙寅', hour: '丁酉', term: '夏至', dun: '阴', ju: 9, yuan: '上', fu: '甲子',
      earth: '乙 丙 丁 癸 壬 辛 庚 己 戊', sky: '丙 丁 辛 乙 壬 戊 癸 庚 己',
      doors: ['死门','伤门','开门','休门',null,'景门','杜门','惊门','生门'],
      chief: ['天心',6,3,'开门',6,3,3], host: 1, hosted: '壬', tombs: [6,8], punishments: [['庚击刑',[8]]],
    },
  ];

  it.each(cases)('matches hand-derived plates including hosted stems and actual chief door: $time', c => {
    const chart = engine.setup({ question, questionType: 'general', setupTime: new Date(c.time), longitude: 116.4 });
    expect(chart).toMatchObject({ dayGanZhi:c.day, hourGanZhi:c.hour, jieqi:c.term, yinYangDun:c.dun, juNumber:c.ju, yuan:c.yuan, fuTou:c.fu });
    expect(chart.palaces.map(p=>p.diPanGan)).toEqual(c.earth.split(' '));
    expect(chart.palaces.map(p=>p.tianPanGan)).toEqual(c.sky.split(' '));
    expect(chart.palaces.map(p=>p.bamen)).toEqual(c.doors);
    expect([chart.zhiFuStar,chart.zhiFuSourcePalaceId,chart.zhiFuPalaceId,chart.zhiShiMen,chart.zhiShiSourcePalaceId,chart.zhiShiRawPalaceId,chart.zhiShiPalaceId]).toEqual(c.chief);
    expect(chart.tianQinPalaceId).toBe(c.host);
    expect(chart.palaces.find(p=>p.id===c.host)).toMatchObject({hostsTianQin:true,hostedTianPanGan:c.hosted});
    expect(chart.geJu.find(p=>p.name==='入墓')?.palaceIds ?? []).toEqual(c.tombs);
    expect(chart.geJu.filter(p=>p.name.endsWith('击刑')).map(p=>[p.name,p.palaceIds])).toEqual(c.punishments);
  });

  it('retains the same physical solstice across three solar clock projections and standard time', () => {
    // Astronomy Engine 2.1.19 independently places the solstice at 08:25 UTC;
    // this wider bracket allows the documented difference in ephemeris models.
    for (const longitude of [undefined,87.6,116.4,121.5]) {
      const before = engine.setup({ question, questionType:'general', setupTime:new Date('2026-06-21T08:23:00Z'), longitude });
      const after = engine.setup({ question, questionType:'general', setupTime:new Date('2026-06-21T08:27:00Z'), longitude });
      expect([before.jieqi,before.yinYangDun,before.juNumber]).toEqual(['芒种','阳',6]);
      expect([after.jieqi,after.yinYangDun,after.juNumber]).toEqual(['夏至','阴',9]);
    }
  });
});
