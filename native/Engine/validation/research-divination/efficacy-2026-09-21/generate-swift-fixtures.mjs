import { build } from 'esbuild';
import { writeFileSync, readFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
const dir=dirname(fileURLToPath(import.meta.url));
const engine=resolve(dir,'../../..');
const result=await build({stdin:{contents:"export { HexagramEngine } from './src/divination/HexagramEngine'; export { efficacy, EFFICACY_SOURCE } from './src/divination/efficacy';",resolveDir:engine,loader:'ts'},bundle:true,platform:'node',format:'cjs',write:false,plugins:[{name:'literal-calendar-fixture',setup(b){b.onResolve({filter:/calendar\/precision$/},()=>({path:'calendar',namespace:'literal'}));b.onLoad({filter:/.*/,namespace:'literal'},()=>({contents:'export const getCalendarPillars=()=>globalThis.__liuyaoCalendar;',loader:'js'}));}}]});
const module={exports:{}};new Function('module','exports',result.outputFiles[0].text)(module,module.exports);
const e=new module.exports.HexagramEngine();
const vectors=[
 ['rootless',[8,7,7,7,9,6],'乙巳','乙未','health'],
 ['strong-tomb',[8,7,7,7,8,8],'壬申','己丑','health'],
 ['opened-tombs',[6,7,9,8,8,7],'癸未','戊辰','health'],
 ['endpoint-triads',[9,8,9,9,8,9],'乙卯','丁巳','health'],
 ['competing-motion',[7,7,7,9,7,9],'乙巳','丁酉','health'],
 ['calendar-shi',[8,8,7,9,8,6],'甲戌','甲寅','health'],
 ['multiple',[7,7,7,8,7,7],'癸未','庚子','wealth'],
 ['source-void',[9,8,6,8,8,8],'乙巳','乙未','health'],
 ['soil-exception',[7,7,7,7,7,7],'戊辰','乙巳','health'],
 ['soil-self-support',[7,7,7,7,7,7],'癸亥','乙巳','health'],
 ['changed-attack',[8,6,7,7,7,7],'壬申','戊午','health'],
 ['all-moving',[6,6,9,9,9,6],'癸未','戊辰','health'],
 ['event',[7,7,7,7,7,7],'甲寅','庚戌','event']
];
const fixtures=vectors.map(([name,lineValues,month,day,questionType])=>{
 globalThis.__liuyaoCalendar={month,day,hour:'庚午'};
 const reading=e.cast({question:'原文规则核对',questionType,questionContext:{subject:'self',event:'原文规则核对',timeHorizon:'near'},castTime:new Date('2026-09-21T04:00:00Z'),lineValues});
 return {name,literalCalendar:true,reading:{...reading,provenance:{engineRevision:'liuyao-efficacy-fixture-v1'}}};
});
const revised=e.reassessQuestion(fixtures[0].reading,{question:'父母',questionType:'parents',questionContext:{subject:'parent',event:'父母'}});
fixtures.push({name:'reassessed',literalCalendar:true,reading:revised});
writeFileSync(resolve(dir,'swift-fixtures.json'),JSON.stringify(fixtures));
console.log(fixtures.map(x=>[x.name,Buffer.byteLength(JSON.stringify(x.reading))]));

const forged=structuredClone(fixtures[0].reading);
forged.yongShen.candidates=[{id:'original-3',layer:'original',position:3,objectPath:'/lines/2',contextPath:'/lines/2/context',reason:'querent-self-reference'}];
forged.efficacy=module.exports.efficacy(forged.lines,forged.yongShen,forged.questionContext,forged.tombExtinction,forged.triads);
writeFileSync(resolve(dir,'swift-joint-forgery.json'),JSON.stringify(forged));

const matrixPath='/tmp/suji-adjudication-capacity/data/fixtures.json';
if(existsSync(matrixPath)){
 const matrix=JSON.parse(readFileSync(matrixPath,'utf8')),sizes=[];
 for(const [index,item] of matrix.entries())for(const row of item.rows)if(row.name==='cast_liuyao'){
  const r=row.output;r.efficacy=module.exports.efficacy(r.lines,r.yongShen,r.questionContext,r.tombExtinction,r.triads);
  r.ruleSources=r.ruleSources.map(s=>s.id===module.exports.EFFICACY_SOURCE.id?module.exports.EFFICACY_SOURCE:s);
  sizes.push({index,bytes:Buffer.byteLength(JSON.stringify(r)),values:r.lineValues,type:r.questionType});
 }
 sizes.sort((a,b)=>b.bytes-a.bytes);writeFileSync(resolve(dir,'paired-matrix-capacity.json'),JSON.stringify(sizes,null,2));
 console.log('48 paired matrix largest',sizes.slice(0,3));
}
