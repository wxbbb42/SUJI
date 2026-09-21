// Research only; uses production code without rebuilding the shipping bundle.
import { build } from 'esbuild';
import { createRequire } from 'node:module';
import { writeFileSync } from 'node:fs';
import vm from 'node:vm';
const require=createRequire(import.meta.url), A=require('astronomy-engine');
const code=await build({entryPoints:[new URL('../../../src/astronomy/residuals.ts',import.meta.url).pathname],bundle:true,write:false,format:'cjs',platform:'node'});
const sandbox={exports:{},module:{exports:{}},require};
vm.runInNewContext(code.outputFiles[0].text,sandbox);
const rows=[];
for(let year=1901;year<=2100;year++) for(const month of [1,4,7,10]) {
  const instant=`${year}-${String(month).padStart(2,'0')}-15T04:00:00.000Z`,time=A.MakeTime(new Date(instant));
  rows.push({instant,julianDayUT:time.ut+2451545,julianDayTT:time.tt+2451545,...sandbox.module.exports.meanLunarPoints(time.tt+2451545)});
}
writeFileSync(new URL('residual-candidate.json',import.meta.url),JSON.stringify(rows,null,2)+'\n');
console.log(`Sampled ${rows.length} production mean lunar positions.`);
