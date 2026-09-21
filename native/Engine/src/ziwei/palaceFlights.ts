import type { RuleSource } from '../rules/provenance';
import type { Palace, PalaceFlightGraph, ZiweiPan } from './types';
import { TRANSFORM_STARS, TRANSFORMATIONS } from './transformations';

export const ZIWEI_PALACE_FLIGHT_SOURCE:RuleSource = {
  id:'ziwei-palace-flights-selected-v1',version:'1',title:'本命宫干四化：所选iztro2.5.8宫际关系',
  editionStatus:'pinned-engineering-reference',
  scope:'来源本命宫的宫干按所选十干表映射四化星，指向星曜实际本命宫；同源同目标的不同星化关系均保留',
  references:[
    {url:'https://unpkg.com/iztro@2.5.8/lib/astro/FunctionalPalace.js',locator:'fliesTo / selfMutaged / mutagedPlaces',sha256:'f9be5552443820ec31f20a4848c25d65dab4d2375b0994b94efcf7447db3b4a1'},
    {url:'https://unpkg.com/iztro@2.5.8/lib/data/heavenlyStems.js',locator:'mutagen',sha256:'4eb6ee5e3a09db4ede931053de526ab258d0d76908922a1f980d7f996f226191'},
  ],
  limitations:[
    '仅本命宫干关系，不是生年干、大限宫干、流年干四化；不会移动星曜或覆盖生年标签',
    '壬干取左辅化科；所读全书电子本的生年表为天府化科；不把软件约定说成各派统一规则',
    'isSelf仅表示所选宫干四化落回同宫，不涵盖向心、离心等完整自化分类',
    '空主星宫仍有本宫宫干；对宫借星参照不改变实际目标宫',
    '只记录结构，不自动判吉凶、效力、事件、应期或化忌一定不利；流月另行计算',
  ],
};

/** Fixed birth-only graph, built once with the natal chart. */
export function natalPalaceFlights(pan:ZiweiPan):PalaceFlightGraph {
  return {
    algorithm:'suji-ziwei-palace-flights-1',assessmentStatus:'structural-only',sourceId:ZIWEI_PALACE_FLIGHT_SOURCE.id,
    edges:pan.palaces.flatMap(source=>{
      const stem = source.ganZhi[0], stars = TRANSFORM_STARS[stem];
      if (!stars) throw new Error('紫微档案缺少有效宫干');
      return stars.map((star,i)=>{
        const targets = pan.palaces.filter(p=>[...(p.mainStars??[]),...(p.minorStars??[])].some(s=>s.name===star));
        if (targets.length!==1) throw new Error(`紫微四化星落宫不唯一：${star}`);
        const target = targets[0];
        return {scope:'natal-palace-stem' as const,sourcePalace:source.name,sourcePosition:source.position,sourceStem:stem,
          star,transformation:TRANSFORMATIONS[i],targetPalace:target.name,targetPosition:target.position,
          isSelf:source.position===target.position,sourceId:ZIWEI_PALACE_FLIGHT_SOURCE.id};
      });
    }),
  };
}

/** Query projection only; no chart calculation, star relocation or mutation. */
export function palaceFlightContext(target:Palace,pan:ZiweiPan) {
  const graph = pan.palaceFlights;
  if (!graph || graph.algorithm!=='suji-ziwei-palace-flights-1' || graph.edges.length!==48) {
    return {status:'unavailable',reason:'natal-flight-cache-missing'};
  }
  return {
    status:'available',scope:'natal-palace-stem',algorithm:graph.algorithm,
    assessmentStatus:graph.assessmentStatus,sourceId:graph.sourceId,
    outgoing:graph.edges.filter(e=>e.sourcePosition===target.position).map(e=>({...e})),
    incoming:graph.edges.filter(e=>e.targetPosition===target.position).map(e=>({...e})),
  };
}
