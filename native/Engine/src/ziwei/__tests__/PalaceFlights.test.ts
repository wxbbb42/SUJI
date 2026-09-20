import { ZiweiEngine } from '../ZiweiEngine';
import { ziweiHandlers } from '../../ai/tools/ziwei';
import { dispatch } from '../../../bridge';

const birth = {year:2023,month:1,day:22,hour:0,minute:0,gender:'男' as const,longitude:120};
const engine = new ZiweiEngine();
const pan = () => engine.compute(birth);
// Independent literal convention and hand chart: 水二局初一紫微丑/天府卯;
// 紫府两系顺逆安星，子时昌戌曲辰，正月左辰右戌。No production table imports.
const table: Record<string,string[]> = {
  甲:['廉贞','破军','武曲','太阳'],乙:['天机','天梁','紫微','太阴'],
  丙:['天同','天机','文昌','廉贞'],丁:['太阴','天同','天机','巨门'],
  戊:['贪狼','太阴','右弼','天机'],己:['武曲','贪狼','天梁','文曲'],
  庚:['太阳','武曲','太阴','天同'],辛:['巨门','太阳','文曲','文昌'],
  壬:['天梁','紫微','左辅','武曲'],癸:['破军','巨门','太阴','贪狼'],
};
const positions:Record<string,string> = {紫微:'丑',天机:'子',太阳:'戌',武曲:'酉',天同:'申',廉贞:'巳',天府:'卯',太阴:'辰',贪狼:'巳',巨门:'午',天相:'未',天梁:'申',七杀:'酉',破军:'丑',文昌:'戌',文曲:'辰',左辅:'辰',右弼:'戌'};
const palaceRows = ['命宫甲寅','父母宫乙卯','福德宫丙辰','田宅宫丁巳','官禄宫戊午','仆役宫己未','迁移宫庚申','疾厄宫辛酉','财帛宫壬戌','子女宫癸亥','夫妻宫甲子','兄弟宫乙丑'].map(s=>({palace:s.slice(0,-2),stem:s.slice(-2,-1),position:s.slice(-1)}));

describe('fixed natal palace stem flights: selected convention, not event adjudication', () => {
  test('all48 edges resolve independent literal star positions, preserving source and target direction', () => {
    const chart = pan(), graph = (chart as any).palaceFlights;
    expect(graph).toMatchObject({algorithm:'suji-ziwei-palace-flights-1',assessmentStatus:'structural-only',sourceId:'ziwei-palace-flights-selected-v1'});
    const expected = palaceRows.flatMap(source => table[source.stem].map((star,i)=>{
      const target = palaceRows.find(p=>p.position===positions[star])!;
      return {scope:'natal-palace-stem',sourcePalace:source.palace,sourcePosition:source.position,sourceStem:source.stem,star,transformation:['化禄','化权','化科','化忌'][i],targetPalace:target.palace,targetPosition:target.position,isSelf:source.position===target.position,sourceId:'ziwei-palace-flights-selected-v1'};
    }));
    expect(graph.edges).toHaveLength(48);
    expect(graph.edges).toEqual(expect.arrayContaining(expected));
    expect(graph.edges.filter((e:any)=>e.sourceStem==='壬' && e.transformation==='化科').map((e:any)=>e.star)).toEqual(['左辅']);
    expect(graph.edges.filter((e:any)=>e.isSelf)).toEqual(expect.arrayContaining([
      expect.objectContaining({sourcePalace:'迁移宫',star:'天同',transformation:'化忌',targetPalace:'迁移宫'}),
      expect.objectContaining({sourcePalace:'兄弟宫',star:'紫微',transformation:'化科',targetPalace:'兄弟宫'}),
    ]));
  });

  test('explicit query projects cached directions without relocating stars or changing natal labels', async () => {
    const chart = pan(), before = JSON.stringify(chart);
    const query = await ziweiHandlers.get_ziwei_palace({palace:'福德宫',withPalaceFlights:true},{ziweiPan:chart,mingPan:null,now:new Date()}) as any;
    expect(query.palaceFlights).toMatchObject({status:'available',scope:'natal-palace-stem',assessmentStatus:'structural-only'});
    expect(query.palaceFlights.outgoing).toHaveLength(4);
    expect(query.palaceFlights.outgoing).toContainEqual(expect.objectContaining({sourceStem:'丙',star:'文昌',targetPalace:'财帛宫',targetPosition:'戌',transformation:'化科',isSelf:false}));
    expect(query.palaceFlights.incoming).toContainEqual(expect.objectContaining({sourcePalace:'财帛宫',sourceStem:'壬',star:'左辅',transformation:'化科',targetPosition:'辰'}));
    expect(query.natalTransformations).toContainEqual(expect.objectContaining({scope:'natal-year-stem',sourceStem:'癸',star:'太阴',transformation:'化科'}));
    expect(query.ruleSources).toContainEqual(expect.objectContaining({id:'ziwei-palace-flights-selected-v1',editionStatus:'pinned-engineering-reference'}));
    chart.palaces.reverse();
    const reordered = await ziweiHandlers.get_ziwei_palace({palace:'福德宫',withPalaceFlights:true},{ziweiPan:chart,mingPan:null,now:new Date('2030-01-01')}) as any;
    expect(reordered.palaceFlights).toEqual(query.palaceFlights);
    chart.palaces.reverse();
    expect(JSON.stringify(chart)).toBe(before);
  });

  test('empty main-star source palace still emits its own stem edges without borrowing opposite stars', async () => {
    const chart = engine.compute({year:1995,month:8,day:15,hour:19,minute:30,gender:'女'});
    const result = await ziweiHandlers.get_ziwei_palace({palace:'命宫',withPalaceFlights:true},{ziweiPan:chart,mingPan:null,now:new Date()}) as any;
    expect(result.mainStars).toEqual([]);
    expect(result.palaceFlights.outgoing.map((e:any)=>[e.sourceStem,e.star])).toEqual([['丙','天同'],['丙','天机'],['丙','文昌'],['丙','廉贞']]);
    expect(result.palaceFlights.outgoing.find((e:any)=>e.star==='天机')).toMatchObject({targetPalace:'迁移宫',targetPosition:'辰',isSelf:false});
    expect(result.natalTransformations).toEqual([]);
  });

  test('legacy alias remains natal labels only, absent cache is explicit and not recomputed', async () => {
    const chart = pan();
    const ctx = {ziweiPan:chart,mingPan:null,now:new Date()};
    const legacy = await ziweiHandlers.get_ziwei_palace({palace:'福德宫',withFlying:true},ctx) as any;
    expect(legacy.sihua).toContain('太阴化科');
    expect(legacy.palaceFlights).toBeUndefined();
    const sparse = await ziweiHandlers.get_ziwei_palace({palace:'福德宫',withPalaceFlights:true},{...ctx,ziweiPan:{...chart,palaceFlights:undefined}}) as any;
    expect(sparse.palaceFlights).toEqual({status:'unavailable',reason:'natal-flight-cache-missing'});
  });

  test('persisted snapshot contains fixed graph, query does not recalculate natal chart, missing graph is rejected', async () => {
    const natal = JSON.parse(JSON.stringify(await dispatch({command:'natal',birth})));
    expect(natal.ziweiPan.palaceFlights?.edges).toHaveLength(48);
    const spy = jest.spyOn(ZiweiEngine.prototype,'compute');
    try {
      const before = JSON.stringify(natal);
      const result = await dispatch({command:'tool',name:'get_ziwei_palace',birth,natal,now:'2025-01-29T04:00:00Z',arguments:{palace:'兄弟宫',withPalaceFlights:true}});
      expect(result.result.palaceFlights.outgoing).toHaveLength(4);
      expect(spy).not.toHaveBeenCalled();
      expect(JSON.stringify(natal)).toBe(before);
      for(const damaged of [undefined,{...natal.ziweiPan.palaceFlights,edges:[]}]) {
        await expect(dispatch({command:'profile',birth,natal:{...natal,ziweiPan:{...natal.ziweiPan,palaceFlights:damaged}}})).rejects.toThrow(/档案/);
      }
    } finally { spy.mockRestore(); }
  });
});
