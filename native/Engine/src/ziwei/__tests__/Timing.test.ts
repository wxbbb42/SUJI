import { ZiweiEngine } from '../ZiweiEngine';
import { ziweiTiming } from '../timing';
import { ziweiHandlers } from '../../ai/tools/ziwei';

const engine = new ZiweiEngine();
const birth2023 = {year:2023,month:1,day:22,hour:0,gender:'男' as const};
const chart = () => engine.compute(birth2023);
const at = (date:string) => new Date(`${date}+08:00`);

describe('selected modern Ziwei decadal and annual policy: independent literal expectations', () => {
  test.each([
    [2024,2,10,'男','forward',6,2029,'丙寅','父母宫','卯','丁卯'],
    [2024,2,10,'女','reverse',6,2029,'丙寅','兄弟宫','丑','丁丑'],
    [2023,1,22,'男','reverse',2,2024,'甲寅','兄弟宫','丑','乙丑'],
    [2023,1,22,'女','forward',2,2024,'甲寅','父母宫','卯','乙卯'],
  ] as const)('%s-%s-%s %s stores the correct direction, ages, years and actual palace stem', (year,month,day,gender,direction,startAge,startYear,ganZhi,nextPalace,nextPosition,nextGanZhi) => {
    const pan = engine.compute({year,month,day,hour:0,gender});
    expect(pan.decadalSchedule).toMatchObject({direction,startAge,ageConvention:'lunar-nominal',sourceId:'ziwei-timing-selected-v1'});
    expect(pan.decadalSchedule!.periods).toHaveLength(12);
    expect(pan.decadalSchedule!.periods.slice(0,2)).toEqual([
      {index:1,startAge,endAge:startAge+9,startLunarYear:startYear,endLunarYear:startYear+9,palace:'命宫',position:'寅',ganZhi},
      {index:2,startAge:startAge+10,endAge:startAge+19,startLunarYear:startYear+10,endLunarYear:startYear+19,palace:nextPalace,position:nextPosition,ganZhi:nextGanZhi},
    ]);
  });

  test('uses lunar New Year instead of LiChun, including the complete late-zi rollover', () => {
    const pan = chart();
    for (const time of ['2024-02-05T12:00:00','2024-02-09T22:59:59']) {
      expect(ziweiTiming(pan,at(time))).toMatchObject({nominalAge:1,status:'before-first-decade',annual:{lunarYear:2023,ganZhi:'癸卯',taiSui:{position:'卯',natalPalace:'父母宫'}},activeDecade:null,decadalTransformations:[]});
    }
    for (const time of ['2024-02-09T23:00:00','2024-02-10T00:00:00']) {
      expect(ziweiTiming(pan,at(time))).toMatchObject({nominalAge:2,status:'active',calculationDate:'2024-02-10',annual:{lunarYear:2024,ganZhi:'甲辰',taiSui:{position:'辰',natalPalace:'福德宫'}},activeDecade:{startAge:2,endAge:11,palace:'命宫',ganZhi:'甲寅'}});
    }
    expect(ziweiTiming(pan,at('2034-02-18T22:59:59'))).toMatchObject({activeDecade:{index:1},nominalAge:11});
    expect(ziweiTiming(pan,at('2034-02-18T23:00:00'))).toMatchObject({activeDecade:{index:2,palace:'兄弟宫',ganZhi:'乙丑'},nominalAge:12});
  });

  test('annual and decadal transformations coexist with unchanged natal labels', () => {
    const pan = chart();
    const original = JSON.stringify(pan);
    const result = ziweiTiming(pan,at('2025-01-29T12:00:00'));
    const taiyin = pan.palaces.flatMap(p=>p.mainStars).find(s=>s.name==='太阴');
    expect(taiyin?.sihua).toEqual(['化科']);
    expect(result.annual.transformations).toContainEqual({scope:'annual-year-stem',sourceStem:'乙',star:'太阴',transformation:'化忌',targetPalace:'福德宫',targetPosition:'辰',sourceId:'ziwei-timing-selected-v1'});
    expect(result.decadalTransformations).toContainEqual(expect.objectContaining({scope:'decadal-palace-stem',sourceStem:'甲',star:'太阳',transformation:'化忌'}));
    expect(ziweiTiming(pan,at('2028-02-01T12:00:00')).annual.transformations).toContainEqual(expect.objectContaining({sourceStem:'戊',star:'右弼',transformation:'化科'}));
    expect(JSON.stringify(pan)).toBe(original);
  });

  test('rejects prebirth applicability and does not invent a childhood or thirteenth decade', () => {
    const pan = chart();
    expect(ziweiTiming(pan,at('2023-01-21T23:30:00'))).toMatchObject({status:'before-birth',nominalAge:1,activeDecade:null,decadalTransformations:[]});
    const ancient = engine.compute({year:1901,month:2,day:19,hour:0,gender:'男'});
    expect(ziweiTiming(ancient,at('2100-02-09T12:00:00'))).toMatchObject({status:'out-of-range',activeDecade:null});
    expect(()=>ziweiTiming({...pan,decadalSchedule:undefined},at('2025-01-29T12:00:00'))).toThrow(/档案/);
  });

  // 全书卷二安昌曲/辅弼：子时昌戌曲辰，正月左辅辰右弼戌；命寅逆列十二宫。
  test.each([
    ['2026-06-01','丙','文昌','化科','财帛宫','戌'],
    ['2028-06-01','戊','右弼','化科','财帛宫','戌'],
    ['2029-06-01','己','文曲','化忌','福德宫','辰'],
    ['2032-06-01','壬','左辅','化科','福德宫','辰'],
  ])('%s resolves minor-star transformation to its actual natal palace', (date,sourceStem,star,transformation,targetPalace,targetPosition) => {
    expect(ziweiTiming(chart(),at(date+'T12:00:00')).annual.transformations).toContainEqual({scope:'annual-year-stem',sourceStem,star,transformation,targetPalace,targetPosition,sourceId:'ziwei-timing-selected-v1'});
  });

  test('tool declares explicit-date noon and rejects impossible or non-calendar dates', async () => {
    const ctx = {mingPan:null,ziweiPan:chart(),now:at('2024-02-09T23:00:00')};
    expect(await ziweiHandlers.get_ziwei_timing({},ctx)).toMatchObject({referenceMode:'question-instant',calculationDate:'2024-02-10'});
    expect(await ziweiHandlers.get_ziwei_timing({date:'2024-02-09'},ctx)).toMatchObject({referenceMode:'explicit-date-noon',referenceDate:'2024-02-09T04:00:00.000Z',calculationDate:'2024-02-09',annual:{ganZhi:'癸卯'}});
    for (const date of ['2024-02-30','2024-2-09','2024-02-09T23:00:00','1900-12-31']) {
      expect(()=>ziweiHandlers.get_ziwei_timing({date},ctx)).toThrow();
    }
  });
});
