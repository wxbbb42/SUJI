import type { SiHua } from './types';

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

