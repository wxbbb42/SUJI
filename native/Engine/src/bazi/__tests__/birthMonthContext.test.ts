import { BaziEngine } from '../BaziEngine';
const engine = new BaziEngine();
const season = (iso:string,longitude?:number):any => engine.calculate(new Date(iso),'男',longitude).geJuV2?.specialPatternEvidence?.season;

describe('production commander is bound to the original civil birth instant', () => {
  it('uses the preceding Jie across the civil new year', () => {
    expect(season('2024-01-01T04:00:00.000Z').birthMonthContext).toMatchObject({
      monthBranch:'子',civilBirthTime:'2024-01-01T04:00:00.000Z',
      jie:{name:'大雪',instant:'2023-12-07T09:32:55.000Z'},
      nextJie:{name:'小寒',instant:'2024-01-05T20:49:22.000Z'},
    });
  });
  it('changes the term and resets elapsed at the exact Jie millisecond', () => {
    const before=season('2024-02-04T08:27:06.999Z').birthMonthContext;
    const exact=season('2024-02-04T08:27:07.000Z').birthMonthContext;
    const after=season('2024-02-04T08:27:07.001Z').birthMonthContext;
    expect(before).toMatchObject({monthBranch:'丑',jie:{name:'小寒'}});
    expect(exact).toMatchObject({monthBranch:'寅',elapsedMillis:0,daysAfterJie:0,jie:{name:'立春'}});
    expect(after).toMatchObject({monthBranch:'寅',elapsedMillis:1});
    expect(after.daysAfterJie).toBe(1/86400000);
  });
  it('does not restart at the intervening Zhongqi', () => {
    const before=season('2024-04-19T13:59:46.999Z').birthMonthContext;
    const exact=season('2024-04-19T13:59:47.000Z').birthMonthContext;
    expect(before).toMatchObject({monthBranch:'辰',jie:{name:'清明',instant:'2024-04-04T07:02:17.000Z'}});
    expect(exact.jie).toEqual(before.jie);
    expect(exact.elapsedMillis-before.elapsedMillis).toBe(1);
    expect(exact.daysAfterJie).toBeGreaterThan(15);
  });
  it('keeps elapsed identical when longitude crosses Lichun in apparent solar time', () => {
    const birth='2024-02-04T08:30:00.000Z';
    const plain=season(birth).birthMonthContext;
    const corrected=season(birth,87.6).birthMonthContext;
    expect(corrected).toEqual(plain);
    expect(corrected).toMatchObject({monthBranch:'寅',elapsedMillis:173000,solarTimeApplied:false});
  });
  it('makes the earth commander available in the real production result', () => {
    expect(season('2024-04-16T07:02:16.999Z')).toMatchObject({commander:{gan:'癸'}});
    expect(season('2024-04-16T07:02:17.000Z')).toMatchObject({commander:{gan:'戊',element:'土'},birthMonthContext:{daysAfterJie:12}});
  });
  it.each(['1901-01-01T00:00:00+08:00','2100-12-31T23:59:59+08:00'])('resolves a valid civil endpoint: %s', iso => {
    const context=season(iso).birthMonthContext;
    expect(context).toBeDefined();
    expect(new Date(context.jie.instant).getTime()).toBeLessThanOrEqual(new Date(iso).getTime());
    expect(new Date(context.nextJie.instant).getTime()).toBeGreaterThan(new Date(iso).getTime());
  });
});

describe('context provenance and chart binding', () => {
  const { getBirthMonthContext } = require('../birthMonthContext') as typeof import('../birthMonthContext');
  const { adjudicateZhuanWang } = require('../zhuanWang') as typeof import('../zhuanWang');
  const { computeGeJuV2 } = require('../structural') as typeof import('../structural');
  it('recognizes a calendar-derived four-store earth chart in production', () => {
    const result=engine.calculate(new Date('1980-01-26T07:00:00+08:00'),'男');
    expect(Object.values(result.siZhu).map(p=>p.ganZhi.gan+p.ganZhi.zhi)).toEqual(['己未','丁丑','戊戌','丙辰']);
    expect(result.geJuV2).toMatchObject({category:'zhuanwang',name:'稼穑格',specialPatternEvidence:{status:'established',season:{commander:{gan:'己',element:'土'},birthMonthContext:{monthBranch:'丑'}}}});
  });
  it('rejects a source-valid context belonging to a different month pillar', () => {
    const context=getBirthMonthContext(new Date('2024-04-16T07:02:17Z'),'辰');
    expect(()=>computeGeJuV2('戊',['戊','己','戊','庚'],['辰','戌','丑','未'],undefined,context)).toThrow(/Month pillar/);
    expect(()=>getBirthMonthContext(new Date('2024-04-16T07:02:17Z'),'戌')).toThrow(/Month pillar/);
  });
  it.each(['daysAfterJie','elapsedMillis','provider','calendarPolicyVersion','solarTimeApplied','jie','nextJie'])('rejects altered source context field %s', field => {
    const context=getBirthMonthContext(new Date('2024-04-16T07:02:17Z'),'辰');
    const changed={...context,[field]:field==='daysAfterJie'?13:field==='elapsedMillis'?0:field==='solarTimeApplied'?true:'tampered'};
    expect(()=>adjudicateZhuanWang(['戊','己','戊','庚'],['戌','辰','丑','未'],{birthMonthContext:changed as any})).toThrow(RangeError);
  });
  it('does not accept an overriding bare elapsed number beside a source context', () => {
    const context=getBirthMonthContext(new Date('2024-04-16T07:02:17Z'),'辰');
    expect(()=>adjudicateZhuanWang(['戊','己','戊','庚'],['戌','辰','丑','未'],{birthMonthContext:context,daysAfterJie:11})).toThrow(/disagree/);
  });
});
