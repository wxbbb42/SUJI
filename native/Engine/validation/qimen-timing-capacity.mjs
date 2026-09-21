// Representative capacity search, not an exhaustive bound over every supported instant.
// No chart or candidate is trimmed; final provider budgets are exercised by native tests.
import { build } from 'esbuild';
import vm from 'node:vm';
import { createRequire } from 'node:module';
const require=createRequire(import.meta.url),engine=new URL('../',import.meta.url).pathname;
const bundle=await build({stdin:{contents:"export { QimenEngine } from './src/qimen/QimenEngine'; export { analyzeQimenTiming,QIMEN_TIMING_SOURCE } from './src/qimen/timing';",resolveDir:engine},bundle:true,write:false,format:'cjs',platform:'node'});
const sandbox={module:{exports:{}},exports:{},require,Date};vm.runInNewContext(bundle.outputFiles[0].text,sandbox);
const {QimenEngine,analyzeQimenTiming,QIMEN_TIMING_SOURCE}=sandbox.module.exports,e=new QimenEngine(),rank=[];
const event='事'+'\u0001'.repeat(199);let clocks=0;
for(const month of [1,3,5,7,9,11])for(let day=1;day<=10;day++)for(let hour=0;hour<24;hour+=2){
  const instant=`2004-${String(month).padStart(2,'0')}-${String(day).padStart(2,'0')}T${String(hour).padStart(2,'0')}:00:00Z`;
  const chart=e.setup({setupTime:new Date(instant),question:'问'.repeat(1600),questionType:'career',questionContext:{subject:'self',event,timeHorizon:'far'}});clocks++;
  for(const focus of ['employment','profit','relationship','self']){
    const timing=analyzeQimenTiming(chart,{focus,event});
    if(new Set(timing.triggers.flatMap(t=>t.branches)).size!==4)continue;
    const value={...chart,timing,ruleSources:[...chart.ruleSources,QIMEN_TIMING_SOURCE]};
    rank.push({instant,focus,bytes:Buffer.byteLength(JSON.stringify(value)),chart});
  }
}
rank.sort((a,b)=>b.bytes-a.bytes);const candidates=[];
for(const item of rank.slice(0,12))for(const unit of ['day','hour']){
  const timing=analyzeQimenTiming(item.chart,{focus:item.focus,event,timeUnit:unit,window:{end:'2100-12-31T23:59:59+08:00',maxCandidates:256}});
  const raw=JSON.stringify({...item.chart,timing,ruleSources:[...item.chart.ruleSources,QIMEN_TIMING_SOURCE]});
  candidates.push({instant:item.instant,focus:item.focus,unit,dates:timing.dates.length,geJu:item.chart.geJu.length,rawUTF16:raw.length,rawUTF8:Buffer.byteLength(raw)});
}
candidates.sort((a,b)=>b.rawUTF8-a.rawUTF8);
console.log(JSON.stringify({clocks,focusesPerClock:4,fourBranchCases:rank.length,topCandidates:candidates.slice(0,6),limitations:['Representative 720-clock search; not a proof of the largest possible payload.','Native dispatch adds provenance; Swift tests and actual ChatClient probes measure the final stored/wire representation.']},null,2));
