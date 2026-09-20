import './licenses.mjs';
import { build } from 'esbuild';
import { readFile, writeFile, mkdir, readdir } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import vm from 'node:vm';
import { createHash } from 'node:crypto';
const native = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
await mkdir(path.join(native,'Resources'), { recursive:true });
async function sourceFiles(directory) {
  const entries=await readdir(directory,{withFileTypes:true});
  const nested=await Promise.all(entries.sort((a,b)=>a.name.localeCompare(b.name)).map(async entry=>{
    const full=path.join(directory,entry.name);
    if(entry.isDirectory()) return entry.name==='__tests__'?[]:sourceFiles(full);
    return /\.(ts|json)$/.test(entry.name)?[full]:[];
  }));
  return nested.flat();
}
const inputs=[...await sourceFiles(path.join(native,'Engine/src')), ...['bridge.ts','timezone.js','package-lock.json','build.mjs'].map(p=>path.join(native,'Engine',p))].sort();
const hash=createHash('sha256');
for(const file of inputs) hash.update(path.relative(native,file)).update('\0').update(await readFile(file)).update('\0');
const revision=hash.digest('hex');
const result = await build({
  entryPoints:[path.join(native,'Engine/bridge.ts')], bundle:true, write:false,
  format:'iife', globalName:'SujiNative', target:'es2020', platform:'browser',
  tsconfig:path.join(native,'Engine/tsconfig.json'), minify:true,
  define:{__ENGINE_REVISION__:JSON.stringify(revision)},
});
const code = await readFile(path.join(native,'Engine/timezone.js'),'utf8') + '\n' + result.outputFiles[0].text;
await writeFile(path.join(native,'Resources/mingli.js'),code);
// Runtime parity fixtures only: generated output is NOT an independent correctness oracle.
process.env.TZ = 'Asia/Shanghai';
const context=vm.createContext({ console }); vm.runInContext(result.outputFiles[0].text,context);
const birth={year:1995,month:8,day:15,hour:19,minute:30,gender:'女',city:'上海',longitude:121.47,timeZoneID:'Asia/Shanghai'};
const requests = [
  {command:'natal',birth},
  {command:'calendar',day:'2026-09-19'},
  {command:'profile',birth,now:'2026-09-19T04:00:00Z'},
  {command:'tool',name:'setup_qimen',arguments:{question:'换个城市生活',questionType:'career'},now:'2026-09-19T04:00:00Z'},
  {command:'candidates',birth,now:'2026-09-19T04:00:00Z'},
  ...[0, 23].map(hour => ({command:'profile',birth:{...birth,hour,minute:30},now:'2026-09-19T04:00:00Z'})),
  {command:'profile',birth:{...birth,year:2000,month:2,day:29,hour:1,minute:10,longitude:87.62},now:'2026-09-19T04:00:00Z'},
  {command:'calendar',day:'2026-02-03'},
  {command:'calendar',day:'2026-02-05'},
  {command:'tool',name:'get_domain',birth,arguments:{domain:'事业'},now:'2026-09-19T04:00:00Z'},
  {command:'forecast',birth,year:2027,now:'2026-09-19T04:00:00Z'},
  ...[{year:2023,month:4,day:6}, {year:2024,month:2,day:9}].map(date => ({command:'natal',birth:{...birth,...date,hour:23,minute:59}})),
  {command:'tool',name:'get_ziwei_palace',birth,arguments:{palace:'命宫',withSihua:true},now:'2026-09-19T04:00:00Z'},
];
const savedNatal=JSON.parse(JSON.stringify(await context.SujiNative.dispatch({command:'natal',birth})));
requests.push({command:'profile',birth,natal:savedNatal,now:'2026-09-19T04:00:00Z'});
const fixtures=[];
for(const request of requests) fixtures.push({request,result:await context.SujiNative.dispatch(request)});
await writeFile(path.join(native,'Resources/engine-fixtures.json'),JSON.stringify(fixtures,null,2));
console.log(`Bundled ${Math.round(code.length/1024)} KB; generated ${fixtures.length} native parity fixtures.`);
