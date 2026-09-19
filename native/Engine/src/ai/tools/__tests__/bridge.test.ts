import { dispatch } from '../../../../bridge';
import { BaziEngine } from '../../../bazi/BaziEngine';
import { baziHandlers } from '../bazi';

const birth = {year:1990,month:8,day:15,hour:10,minute:0,gender:'女',longitude:120,timeZoneID:'Asia/Shanghai'};
const now = '2024-02-04T04:00:00Z';

describe('native boundary and grounded tools', () => {
  test.each([
    {command:'profile',birth:{...birth,year:1900}},
    {command:'profile',birth:{...birth,day:32}},
    {command:'profile',birth:{...birth,minute:0.5}},
    {command:'profile',birth:{...birth,timeZoneID:'America/Los_Angeles'}},
    {command:'calendar',day:'2024-02-30'},
    {command:'calendar',now:'2024-02-04T12:00:00'},
    {command:'forecast',birth,year:2024.5},
  ])('rejects invalid input instead of rolling it over: %j', async request => {
    await expect(dispatch(request)).rejects.toThrow();
  });

  test('uses the exact reference instant before and after a Yun transition', async () => {
    const chart = new BaziEngine().calculate(new Date('1990-08-15T02:00:00Z'),'女',120);
    const start = Date.parse(chart.daYunList[0].startDate!);
    const request = {command:'tool',name:'get_timing',arguments:{scope:'current_dayun'},birth};
    const before = await dispatch({...request,now:new Date(start-1_000).toISOString()});
    const after = await dispatch({...request,now:new Date(start).toISOString()});
    expect(before.result.status).toBe('before-start');
    expect(before.result.data).toBeNull();
    expect(after.result.status).toBe('active');
    expect(after.result.data.startDate).toBe(chart.daYunList[0].startDate);
    expect(after.result.provenance.referenceDate).toBe(new Date(start).toISOString());
  });

  test('today respects exact Lichun and Beijing midnight independently of UTC date', async () => {
    const request = {command:'tool',name:'get_today_context',arguments:{},birth};
    const before = await dispatch({...request,now});
    expect(before.result.yearGanZhi).toBe('癸卯');
    expect(before.result.monthGanZhi).toBe('乙丑');
    const after = await dispatch({...request,now:'2024-02-04T09:00:00Z'});
    expect(after.result.yearGanZhi).toBe('甲辰');
    expect(after.result.monthGanZhi).toBe('丙寅');
    const midnight = await dispatch({...request,now:'2024-02-04T16:30:00Z'});
    expect(midnight.result.date).toBe('2024-02-05');
    expect(midnight.result.dayInteraction).not.toContain('微妙');
  });

  test('distinguishes requested annual cycle from the active year before Lichun', async () => {
    const request={command:'tool',name:'get_timing',birth,now};
    const current=await dispatch({...request,arguments:{scope:'liunian'}});
    expect(current.result.data[0].year).toBe(2023);
    expect(current.result.data[0].ganZhi).toBe('癸卯');
    expect(current.result.data[0].annualCycle.isActiveAtReference).toBe(true);
    const specified=await dispatch({...request,arguments:{scope:'liunian',yearRange:[2024,2024]}});
    expect(specified.result.data[0].ganZhi).toBe('甲辰');
    expect(specified.result.data[0].annualCycle.isActiveAtReference).toBe(false);
    expect(specified.result.data[0].referenceDate).toBe('2024-07-01T04:00:00.000Z');
  });

  test('reports hidden family stars without counting the day master as a sibling', async () => {
    const chart = new BaziEngine().calculate(new Date('1990-08-15T02:00:00Z'),'女',120);
    const ctx = {mingPan:chart,ziweiPan:null,now:new Date(now)};
    const siblings:any = await baziHandlers.get_bazi_star({person:'兄弟'},ctx);
    expect(siblings.positionsInChart.every((p:string)=>!p.startsWith('日柱'))).toBe(true);
    expect(Array.isArray(siblings.hiddenPositions)).toBe(true);
    const parents:any = await baziHandlers.get_bazi_star({person:'父母'},ctx);
    expect(parents.relevantShiShen).toEqual(['偏财','正印']);
  });

  test('career includes actual four pillars; schemas reject choosing random outcomes', async () => {
    const domain = await dispatch({command:'tool',name:'get_domain',arguments:{domain:'事业'},birth,now});
    expect(domain.result.bazi.pillars.day.ganZhi.gan).toBeTruthy();
    expect(domain.result.bazi.interpretationPolicy).toBeTruthy();
    await expect(dispatch({command:'tool',name:'cast_liuyao',arguments:{question:'工作',lineValues:[9,9,9,9,9,9]},now})).rejects.toThrow();
  });

  test('calibration keeps each system and relationship exposes both full day pillars', async () => {
    const candidates=await dispatch({command:'candidates',birth,now});
    expect(candidates.length).toBeGreaterThan(0);
    for (const candidate of candidates) {
      expect(candidate.events).toBeUndefined();
      expect(candidate.eventsBySystem.bazi).toBeDefined();
      expect(candidate.eventsBySystem.ziwei).toBeDefined();
    }
    const relation=await dispatch({command:'relationship',birth,partner:{...birth,hour:20},now});
    expect(relation.firstDayPillar.zhi).toBeTruthy();
    expect(relation.secondDayPillar.zhi).toBeTruthy();
  });
});
