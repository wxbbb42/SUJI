import type { SiHua, ZiweiPan } from './types';

// Selected iztro 2.5.8 default, in 禄 / 权 / 科 / 忌 order. The Ren variant
// is explicitly preserved; do not read mutable process-global iztro config.
export const TRANSFORM_STARS:Record<string,readonly string[]> = {
  甲:['廉贞','破军','武曲','太阳'],乙:['天机','天梁','紫微','太阴'],
  丙:['天同','天机','文昌','廉贞'],丁:['太阴','天同','天机','巨门'],
  戊:['贪狼','太阴','右弼','天机'],己:['武曲','贪狼','天梁','文曲'],
  庚:['太阳','武曲','太阴','天同'],辛:['巨门','太阳','文曲','文昌'],
  壬:['天梁','紫微','左辅','武曲'],癸:['破军','巨门','太阴','贪狼'],
};
export const TRANSFORMATIONS:SiHua[] = ['化禄','化权','化科','化忌'];


/** Resolve each temporal label to a resident natal star; never relocate stars. */
export function temporalTransformations(pan:ZiweiPan,stem:string,scope:'annual-year-stem'|'decadal-palace-stem'|'monthly-month-stem',sourceId:string) {
  const stars = TRANSFORM_STARS[stem];
  if (!stars) throw new Error('紫微四化来源干无效');
  return stars.map((star,i)=>{
    const targets = pan.palaces.filter(p=>[...(p.mainStars??[]),...(p.minorStars??[])].some(s=>s.name===star));
    if (targets.length!==1) throw new Error(`紫微档案四化星落宫不唯一：${star}`);
    const palace = targets[0];
    return {scope,sourceStem:stem,star,transformation:TRANSFORMATIONS[i],targetPalace:palace.name,targetPosition:palace.position,sourceId};
  });
}
