import { dispatch } from '../../../../bridge';
import { BaziEngine } from '../../../bazi/BaziEngine';
import { ZiweiEngine } from '../../../ziwei/ZiweiEngine';

const birth = {year:1990,month:8,day:15,hour:10,minute:0,gender:'女',longitude:120,timeZoneID:'Asia/Shanghai'};
const now = '2024-02-04T04:00:00Z';
const json = (value: unknown) => JSON.parse(JSON.stringify(value));

describe('durable natal calculations', () => {
  afterEach(() => jest.restoreAllMocks());

  test('round-trips natal data without calculating it again for profile, tools and forecast', async () => {
    const natal = json(await dispatch({command:'natal',birth}));
    const requests = [
      {command:'profile',birth,now},
      {command:'forecast',birth,now,year:2025},
      {command:'tool',name:'get_domain',birth,now,arguments:{domain:'事业'}},
      {command:'tool',name:'get_timing',birth,now,arguments:{scope:'current_dayun'}},
      {command:'tool',name:'get_ziwei_palace',birth,now,arguments:{palace:'命宫'}},
      {command:'tool',name:'get_ziwei_timing',birth,now,arguments:{date:'2025-01-29'}},
    ];
    const expected = await Promise.all(requests.map(dispatch));
    const bazi = jest.spyOn(BaziEngine.prototype,'calculate');
    const ziwei = jest.spyOn(ZiweiEngine.prototype,'compute');
    for (let i=0;i<requests.length;i++) {
      expect(json(await dispatch({...requests[i],natal}))).toEqual(json(expected[i]));
    }
    expect(bazi).not.toHaveBeenCalled();
    expect(ziwei).not.toHaveBeenCalled();
  });

  test('uses new reference dates while keeping the original natal snapshot unchanged', async () => {
    const natal = json(await dispatch({command:'natal',birth}));
    expect(natal.daily).toBeUndefined();
    expect(natal.forecast).toBeUndefined();
    expect(natal.ziweiPan.decadalSchedule.periods).toHaveLength(12);
    expect(natal.ziweiPan.annual).toBeUndefined();
    const saved = JSON.stringify(natal);
    const request = {command:'tool',name:'get_today_context',birth,natal,arguments:{}};
    expect((await dispatch({...request,now})).result.yearGanZhi).toBe('癸卯');
    expect((await dispatch({...request,now:'2024-02-04T09:00:00Z'})).result.yearGanZhi).toBe('甲辰');
    expect(JSON.stringify(natal)).toBe(saved);
    const ziweiRequest = {...request,name:'get_ziwei_timing'};
    expect((await dispatch({...ziweiRequest,now:'2024-02-09T14:59:59Z'})).result.annual.ganZhi).toBe('癸卯');
    expect((await dispatch({...ziweiRequest,now:'2024-02-09T15:00:00Z'})).result.annual.ganZhi).toBe('甲辰');
    expect(JSON.stringify(natal)).toBe(saved);
  });

  test('rejects stale, mismatched and incomplete snapshots instead of silently using them', async () => {
    const natal = json(await dispatch({command:'natal',birth}));
    for (const damaged of [
      {...natal,engineRevision:'old'}, {...natal,birthKey:'other'},
      {...natal,schemaVersion:99}, {...natal,mingPan:{}},
      {...natal,ziweiPan:{...natal.ziweiPan,palaces:[]}},
      {...natal,ziweiPan:{...natal.ziweiPan,decadalSchedule:undefined}},
      {...natal,calendarPolicy:{version:'old'}},
    ]) await expect(dispatch({command:'profile',birth,natal:damaged,now})).rejects.toThrow();
    await expect(dispatch({command:'profile',birth:{...birth,minute:1},natal,now})).rejects.toThrow();
  });

  test('question-only casts do not calculate a natal chart even if birth is supplied', async () => {
    const bazi = jest.spyOn(BaziEngine.prototype,'calculate');
    const ziwei = jest.spyOn(ZiweiEngine.prototype,'compute');
    const result = await dispatch({command:'tool',name:'setup_qimen',arguments:{question:'工作',questionType:'career'},birth,now});
    expect(result.result.provenance.referenceDate).toBe('2024-02-04T04:00:00.000Z');
    expect(bazi).not.toHaveBeenCalled();
    expect(ziwei).not.toHaveBeenCalled();
  });
});
