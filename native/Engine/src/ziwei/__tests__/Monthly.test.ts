import { ZiweiEngine } from '../ZiweiEngine';
import { ziweiHandlers } from '../../ai/tools/ziwei';
import { dispatch } from '../../../bridge';

const engine = new ZiweiEngine();
const birth = {year:2023,month:1,day:22,hour:0,minute:0,gender:'男' as const,longitude:120};
const at = (value:string) => new Date(value+'+08:00');
const query = async (pan=engine.compute(birth),now=at('2025-01-29T12:00:00'),withMonthly=true) =>
  await ziweiHandlers.get_ziwei_timing({withMonthly},{ziweiPan:pan,mingPan:null,now}) as any;

// Lunar month starts checked against HKO's 2025/2026 calendar. The palace,
// stem and transformation expectations are literal hand counts, not iztro output.
const months = [
  ['2025-01-29',1,'巳','田宅宫','戊寅'],['2025-02-28',2,'午','官禄宫','己卯'],
  ['2025-03-29',3,'未','仆役宫','庚辰'],['2025-04-28',4,'申','迁移宫','辛巳'],
  ['2025-05-27',5,'酉','疾厄宫','壬午'],['2025-06-25',6,'戌','财帛宫','癸未'],
  ['2025-08-23',7,'亥','子女宫','甲申'],['2025-09-22',8,'子','夫妻宫','乙酉'],
  ['2025-10-21',9,'丑','兄弟宫','丙戌'],['2025-11-20',10,'寅','命宫','丁亥'],
  ['2025-12-20',11,'卯','父母宫','戊子'],['2026-01-19',12,'辰','福德宫','己丑'],
] as const;

describe('selected lunar-month Ziwei projection: independent counts and scope', () => {
  test.each(months)('%s projects month%s onto natal %s/%s with month stem %s', async (date,month,position,natalPalace,ganZhi) => {
    const value = (await query(undefined,at(date+'T12:00:00'))).monthly;
    expect(value).toMatchObject({status:'available',scope:'lunar-month',assessmentStatus:'structural-only',
      calendar:{lunarYear:2025,month,day:1,isLeapMonth:false,effectiveMonth:month},
      douJun:{position:'巳',natalPalace:'田宅宫'},mingGong:{position,natalPalace},ganZhi});
    expect(value.palaces).toHaveLength(12);
    expect(value.palaces[0]).toEqual({palace:'命宫',position,natalPalace});
  });

  test('month stem transformations remain separate from annual, natal and monthly palace stems', async () => {
    const pan = engine.compute(birth),before = JSON.stringify(pan);
    const output = await query(pan), month = output.monthly;
    expect(month).toBeDefined();
    // 正月命宫落本命田宅丁巳，但月干是乙年五虎遁戊寅，不用丁干四化。
    expect(month.transformations).toEqual([
      {scope:'monthly-month-stem',sourceStem:'戊',star:'贪狼',transformation:'化禄',targetPalace:'田宅宫',targetPosition:'巳',sourceId:'ziwei-monthly-selected-v1'},
      {scope:'monthly-month-stem',sourceStem:'戊',star:'太阴',transformation:'化权',targetPalace:'福德宫',targetPosition:'辰',sourceId:'ziwei-monthly-selected-v1'},
      {scope:'monthly-month-stem',sourceStem:'戊',star:'右弼',transformation:'化科',targetPalace:'财帛宫',targetPosition:'戌',sourceId:'ziwei-monthly-selected-v1'},
      {scope:'monthly-month-stem',sourceStem:'戊',star:'天机',transformation:'化忌',targetPalace:'夫妻宫',targetPosition:'子',sourceId:'ziwei-monthly-selected-v1'},
    ]);
    expect(month.palaces.map((p:any)=>[p.palace,p.position])).toEqual([
      ['命宫','巳'],['兄弟宫','辰'],['夫妻宫','卯'],['子女宫','寅'],['财帛宫','丑'],['疾厄宫','子'],
      ['迁移宫','亥'],['仆役宫','戌'],['官禄宫','酉'],['田宅宫','申'],['福德宫','未'],['父母宫','午'],
    ]);
    expect(output.annual.transformations).toContainEqual(expect.objectContaining({star:'太阴',transformation:'化忌',scope:'annual-year-stem'}));
    expect(pan.palaces.flatMap(p=>p.mainStars).find(s=>s.name==='太阴')?.sihua).toEqual(['化科']);
    expect(JSON.stringify(pan)).toBe(before);
    pan.palaces.reverse();
    expect((await query(pan)).monthly).toEqual(month);
  });

  test('birth leap15/16 and full late-zi rollover change the fixed basis exactly once', async () => {
    const values = [
      [5,12,2,'午','戌'],[6,12,3,'午','酉'],[5,23,3,'子','卯'],
    ] as const;
    for (const [day,hour,effectiveMonth,hourBranch,position] of values) {
      const b = {...birth,month:4,day,hour};
      const pan = engine.compute(b);
      expect((pan as any).monthlyBasis).toMatchObject({lunarMonth:2,isLeapMonth:true,effectiveMonth,hourBranch});
      expect((await query(pan)).monthly?.douJun.position).toBe(position);
    }
  });

  test('query leap15/16 advances palace and month stem at23, not at a solar term', async () => {
    for (const [time,day,effectiveMonth,position,ganZhi] of [
      ['2025-08-08T22:59:59',15,6,'戌','癸未'],['2025-08-08T23:00:00',16,7,'亥','甲申'],
      ['2025-08-09T12:00:00',16,7,'亥','甲申'],
    ] as const) {
      expect((await query(undefined,at(time))).monthly).toMatchObject({calendar:{month:6,day,isLeapMonth:true,effectiveMonth},mingGong:{position},ganZhi});
    }
    expect((await query(undefined,at('2025-08-23T12:00:00'))).monthly).toMatchObject({calendar:{month:7,day:1,isLeapMonth:false,effectiveMonth:7},mingGong:{position:'亥'},ganZhi:'甲申'});
    // Lunar New Year precedes LiChun in2025; LiChun in February does not change the flow month.
    for (const time of ['2025-01-28T23:00:00','2025-02-04T12:00:00']) {
      expect((await query(undefined,at(time))).monthly).toMatchObject({calendar:{lunarYear:2025,month:1},ganZhi:'戊寅',mingGong:{position:'巳'}});
    }
    expect((await query(undefined,at('2025-01-28T22:59:59'))).monthly).toMatchObject({calendar:{lunarYear:2024,month:12},ganZhi:'丁丑',mingGong:{position:'卯'}});
  });

  test('prebirth and missing fixed basis are explicit, normal annual query stays compact', async () => {
    const pan = engine.compute(birth);
    expect((await query(pan,at('2023-01-21T23:30:00'))).monthly).toMatchObject({status:'before-birth',appliesToBirth:false,transformations:[]});
    expect((await query({...pan,monthlyBasis:undefined} as any)).monthly).toEqual({status:'unavailable',reason:'natal-monthly-basis-missing'});
    expect((await query(pan,undefined,false)).monthly).toBeUndefined();
  });

  test('persisted birth basis survives replay, lunar input parity and rejects missing cache without natal recalculation', async () => {
    const natal = JSON.parse(JSON.stringify(await dispatch({command:'natal',birth})));
    expect(natal.ziweiPan.monthlyBasis).toMatchObject({lunarMonth:1,lunarDay:1,isLeapMonth:false,effectiveMonth:1,hourBranch:'子'});
    const lunar = engine.compute({year:2023,month:1,day:1,hour:0,gender:'男',isLunar:true});
    expect((lunar as any).monthlyBasis).toEqual(natal.ziweiPan.monthlyBasis);
    const before = JSON.stringify(natal),spy = jest.spyOn(ZiweiEngine.prototype,'compute');
    try {
      const result = await dispatch({command:'tool',name:'get_ziwei_timing',birth,natal,now:'2025-01-29T04:00:00Z',arguments:{withMonthly:true}});
      expect(result.result.monthly.ganZhi).toBe('戊寅');
      expect(spy).not.toHaveBeenCalled();
      expect(JSON.stringify(natal)).toBe(before);
      await expect(dispatch({command:'profile',birth,natal:{...natal,ziweiPan:{...natal.ziweiPan,monthlyBasis:undefined}}})).rejects.toThrow(/档案/);
    } finally {spy.mockRestore();}
  });
});
