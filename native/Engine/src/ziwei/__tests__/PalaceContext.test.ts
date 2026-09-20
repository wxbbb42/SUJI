import { ZiweiEngine } from '../ZiweiEngine';
import { ziweiHandlers } from '../../ai/tools/ziwei';

const engine = new ZiweiEngine();
const natal = () => engine.compute({ year:1995, month:8, day:15, hour:19, minute:30, gender:'女' });
const context = (ziweiPan = natal()) => ({ ziweiPan, mingPan:null, now:new Date('2026-09-20T04:00:00Z') });

describe('palace context retains physical placement and natal transformation scope', () => {
  it('returns the two trines and opposite of empty 戌命, with stars still in 辰迁移', async () => {
    const result = await ziweiHandlers.get_ziwei_palace({ palace:'命宫', withSihua:true }, context()) as any;
    expect(result.mainStars).toEqual([]);
    expect(result.emptyMainPalace).toBe(true);
    expect(result.relatedPalaces.map((p: any) => [p.relation,p.palace,p.position])).toEqual([
      ['trine-4','官禄宫','寅'], ['trine-8','财帛宫','午'], ['opposite','迁移宫','辰'],
    ]);
    const opposite = result.relatedPalaces[2];
    expect(opposite.mainStars).toEqual(['天机','天梁']);
    expect(opposite.natalTransformations).toEqual([
      { scope:'natal-year-stem', sourceStem:'乙', star:'天机', transformation:'化禄', targetPalace:'迁移宫', targetPosition:'辰', sourceId:'ziwei-sihua-selected-v1' },
      { scope:'natal-year-stem', sourceStem:'乙', star:'天梁', transformation:'化权', targetPalace:'迁移宫', targetPosition:'辰', sourceId:'ziwei-sihua-selected-v1' },
    ]);
    expect(result.natalTransformations).toEqual([]);
    expect(result.emptyPalaceReference).toEqual({ status:'opposite-reference', sourcePalace:'迁移宫', sourcePosition:'辰', mainStars:['天机','天梁'] });
    expect(result.ruleSources.map((s: any) => s.id)).toContain('ziwei-palace-context-v1');
  });

  it('finds relations by earthly branch identity, independent of array order', async () => {
    const pan = natal();
    const result = await ziweiHandlers.get_ziwei_palace({ palace:'命宫' }, context({ ...pan, palaces:pan.palaces.slice().reverse() })) as any;
    expect(result.relatedPalaces.map((p: any) => p.position)).toEqual(['寅','午','辰']);
  });

  it('retains resident stars and uses no borrowed reference for a nonempty palace', async () => {
    const result = await ziweiHandlers.get_ziwei_palace({ palace:'迁移宫' }, context()) as any;
    expect(result.mainStars).toEqual(['天机','天梁']);
    expect(result.emptyPalaceReference).toEqual({ status:'not-needed' });
    expect(result.starDetails.filter((s: any) => s.group==='main').map((s: any) => [s.name,s.sihua])).toEqual([['天机',['化禄']],['天梁',['化权']]]);
    expect(result.sihua).toBeUndefined(); // Legacy flag affects legacy strings only.
    expect(result.natalTransformations[0].scope).toBe('natal-year-stem');
  });

  it('does not invent an opposite or source stem in sparse legacy charts', async () => {
    const result = await ziweiHandlers.get_ziwei_palace({ palace:'命宫' }, { mingPan:null, now:new Date(), ziweiPan:{palaces:[{name:'命宫',position:'戌',mainStars:[],minorStars:[],isShenGong:false}]} }) as any;
    expect(result.relatedPalaces).toEqual([]);
    expect(result.emptyPalaceReference).toEqual({ status:'unavailable' });
    expect(result.natalTransformations).toEqual([]);
    expect(result.natalYear).toBeUndefined();
  });

  it('preserves sparse legacy charts whose star arrays are absent', async () => {
    const result = await ziweiHandlers.get_ziwei_palace({palace:'命宫'}, {mingPan:null,now:new Date(),ziweiPan:{palaces:[{name:'命宫',position:'戌'}]}}) as any;
    expect(result.mainStars).toEqual([]);
    expect(result.emptyMainPalace).toBe(true);
    expect(result.emptyPalaceReference).toEqual({status:'unavailable'});
  });

  it('identifies the natal year from effective lunar year rather than LiChun or civil year', () => {
    const before = engine.compute({year:2024,month:2,day:9,hour:22,gender:'男'});
    const after = engine.compute({year:2024,month:2,day:9,hour:23,gender:'男'});
    expect((before as any).natalYear).toEqual({ lunarYear:2023, ganZhi:'癸卯', stem:'癸', branch:'卯' });
    expect((after as any).natalYear).toEqual({ lunarYear:2024, ganZhi:'甲辰', stem:'甲', branch:'辰' });
  });

  it('marks the selected Ren table explicitly instead of claiming all editions agree', async () => {
    const pan = engine.compute({ year:1992, month:8, day:15, hour:12, gender:'男' });
    const result = await ziweiHandlers.get_ziwei_palace({ palace:'命宫' }, context(pan)) as any;
    expect(pan.palaces.flatMap(p => [...p.mainStars,...p.minorStars]).find(s => s.sihua?.includes('化科'))?.name).toBe('左辅');
    expect(result.ruleSources.find((s: any) => s.id==='ziwei-sihua-selected-v1').limitations.join('')).toContain('壬年天府化科');
  });
});
