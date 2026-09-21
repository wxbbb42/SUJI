// Verify the shipped rule records against archived text bytes, not against another
// copy of their metadata. This does not establish print-edition authenticity.
import {build} from 'esbuild';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {createRequire} from 'node:module';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const here=path.dirname(fileURLToPath(import.meta.url)),root=path.resolve(here,'../../../../..');
const require=createRequire(import.meta.url),hash=s=>createHash('sha256').update(s).digest('hex');
const archived=new Map();
function scan(folder){for(const e of fs.readdirSync(folder,{withFileTypes:true})){
 const f=path.join(folder,e.name);if(e.isDirectory())scan(f);
 else if(/\.(md|txt|html|c|json)$/.test(e.name)){const bytes=fs.readFileSync(f);archived.set(hash(bytes),{file:path.relative(root,f),text:bytes.toString('utf8')});}
}}
scan(path.join(root,'docs/mingli/source-texts'));
for(const folder of ['research-divination/event-2026-09-21','research-divination/selection-2026-09-21','research-divination/efficacy-2026-09-21','research-divination/timing-2026-09-21','research-qizheng/completion-2026-09-21'])scan(path.join(root,'native/Engine/validation',folder));
const refs=[],failures=[];
for(const [file,key] of [['bazi/zhuanWangSources.ts','ZHUAN_WANG_SOURCES'],['bazi/rescueSources.ts','RESCUE_SOURCES'],['bazi/SiLing.ts','SI_LING_SOURCE'],['divination/eventAssessment.ts','EVENT_SOURCE'],['qimen/selectionSources.ts','QIMEN_WEATHER_SELECTION_SOURCE'],['qimen/selectionSources.ts','QIMEN_DWELLING_SELECTION_SOURCE'],['divination/efficacy.ts','EFFICACY_SOURCE'],['qimen/timing.ts','QIMEN_TIMING_SOURCE']]){
 const output=await build({entryPoints:[path.join(root,'native/Engine/src',file)],bundle:true,write:false,platform:'node',format:'cjs'});
 const sandbox={module:{exports:{}},exports:{},require};vm.runInNewContext(output.outputFiles[0].text,sandbox);
 const raw=sandbox.module.exports[key],sources=Array.isArray(raw)?raw:[raw];
 for(const s of sources)for(const r of s.references??[s]){
  const witness=archived.get(r.sha256),quotes=[r.quote,...(r.additionalQuotes??[])].filter(Boolean);
  const normalize=x=>x.replace(/\s+/g,'');
  const missing=witness?quotes.filter(q=>!normalize(witness.text).includes(normalize(q))):quotes;
  if(!witness||missing.length)failures.push({id:s.id,sha256:r.sha256,missingQuotes:missing});
  refs.push({id:s.id,sha256:r.sha256,archive:witness?.file,quotesChecked:quotes.length});
 }
}
const report={scope:'Exact archived bytes and normalized quoted substrings; electronic transcription, not print collation.',references:refs,failures};
fs.writeFileSync(path.join(here,'source-verification.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({references:refs.length,failures},null,2));assert.equal(failures.length,0);
