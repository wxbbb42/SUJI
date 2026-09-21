import {build} from 'esbuild';
import {writeFileSync} from 'node:fs';
import {dirname,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
const dir=dirname(fileURLToPath(import.meta.url)),engine=resolve(dir,'../../..');
const compiled=await build({stdin:{contents:"export { HexagramEngine } from './src/divination/HexagramEngine';",resolveDir:engine,loader:'ts'},bundle:true,platform:'node',format:'cjs',write:false,plugins:[{name:'literal-calendar',setup(b){b.onResolve({filter:/calendar\/precision$/},()=>({path:'calendar',namespace:'literal'}));b.onLoad({filter:/.*/,namespace:'literal'},()=>({contents:'export const getCalendarPillars=()=>globalThis.__eventCalendar;',loader:'js'}));}}]});
const module={exports:{}};new Function('module','exports',compiled.outputFiles[0].text)(module,module.exports);const e=new module.exports.HexagramEngine();
const vectors=[
 ['monthly',[7,7,7,7,7,7],'甲戌','甲申','health','self'],
 ['rootless',[8,7,7,7,9,6],'乙巳','乙未','health','self'],
 ['chain',[7,9,8,8,7,6],'甲子','丙寅','health','self'],
 ['yuan-broken',[7,9,8,8,7,6],'甲酉','丙寅','health','self'],
 ['yuan-attacked',[7,9,8,6,7,6],'甲子','丙寅','health','self'],
 ['ji-broken',[7,9,8,8,7,6],'甲午','丙寅','health','self'],
 ['void-monthly',[7,7,7,7,8,7],'甲寅','庚戌','wealth','self'],
 ['month-break-only',[8,7,7,7,9,6],'乙巳','甲申','health','self'],
 ['monthly-ji',[7,9,7,7,7,7],'甲寅','丙寅','health','self'],
 ['multiple',[7,7,7,8,7,7],'癸未','庚子','wealth','self'],
 ['unanimous',[8,7,7,7,9,6],'乙巳','乙未','parents','parent'],
 ['potential-rescue',[7,9,7,9,7,7],'甲寅','丙寅','health','self'],
 ['multiple-unresolved',[7,7,7,7,7,7],'甲申','丙寅','parents','parent'],
 ['missing-context',[7,7,7,7,7,7],'甲戌','甲申','health','unknown'],
];
const fixtures=vectors.map(([name,lineValues,month,day,questionType,subject])=>{
 globalThis.__eventCalendar={month,day,hour:'庚午'};
 const reading=e.cast({question:'原文规则核对',questionType,questionContext:{subject,event:'原文规则核对',timeHorizon:'near'},lineValues,castTime:new Date('2026-09-21T04:00:00Z')});
 return {name,reading:{...reading,provenance:{engineRevision:'liuyao-event-fixture-v1'}}};
});
writeFileSync(resolve(dir,'swift-fixtures.json'),JSON.stringify(fixtures));
console.log(fixtures.map(f=>({name:f.name,bytes:Buffer.byteLength(JSON.stringify(f.reading)),outcome:f.reading.eventAssessment.outcome})));
