import { createRequire } from 'node:module';
import { readFileSync, writeFileSync, unlinkSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import { createHash } from 'node:crypto';
const here = dirname(fileURLToPath(import.meta.url));
const engine = resolve(here, '../../..');
const root = resolve(engine, '../..');
const require = createRequire(resolve(engine, 'package.json'));
const { buildSync } = require('esbuild');
const outfile = resolve(here, 'baseline.cjs');
buildSync({stdin:{contents:"export * from './src/bazi/structural'; export * from './src/bazi/SiLing';",resolveDir:engine,loader:'ts'},outfile,bundle:true,platform:'node',format:'cjs',logLevel:'silent'});
const api=require(outfile);
const sources=JSON.parse(readFileSync(resolve(here,'sources.json'),'utf8'));
for (const s of sources) {
 const bytes=readFileSync(resolve(root,s.document));
 if(createHash('sha256').update(bytes).digest('hex')!==s.sha256) throw Error(`Source hash changed ${s.id}`);
 for (const q of s.quotes) if(!bytes.toString().includes(q.text)) throw Error(`Quote not found ${s.id}`);
}
unlinkSync(outfile);
const vectors=JSON.parse(readFileSync(resolve(here,'vectors.json'),'utf8'));
const special= vectors.specialPatternVectors.map(v=>({...v,observed:api.detectZhuanWang(v.stems[2],v.stems,v.branches)}));
const rescue=vectors.rescueVectors.map(v=>{
 const facts=api.computePatternConditions(v.stems[2],v.stems,v.branches,v.yong);
 return {...v,observed:api.computeGeJuV2(v.stems[2],v.stems,v.branches),facts};
});
const siLing=Object.fromEntries([..."寅卯辰巳午未申酉戌亥子丑"].map(z=>[z,api.getSiLingSegments(z)]));
writeFileSync(resolve(here,'current-observations.json'),JSON.stringify({revision:'working-tree-after-adjudication',sourceAssertions:sources.length,special,siLing,rescue},null,2)+'\n');
console.log(JSON.stringify({sourceAssertions:sources.length,special:special.map(v=>({id:v.id,expect:v.expect,observed:{isZhuanWang:v.observed.isZhuanWang,name:v.observed.name,adjudication:v.observed.adjudication ? Object.fromEntries(['methodVersion','profileId','status','unmetConditions','alternativeProfile'].map(k=>[k,v.observed.adjudication[k]])) : undefined}})),siLingShen:siLing.申},null,2));
