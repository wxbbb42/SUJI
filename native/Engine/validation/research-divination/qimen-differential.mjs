import {build} from '../../node_modules/esbuild/lib/main.js';
import {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';
import {writeFileSync} from 'node:fs';
const require=createRequire(import.meta.url),root=fileURLToPath(new URL('../../',import.meta.url));
await build({stdin:{contents:"export {buildDiPan} from './src/qimen/helpers/diPan'; export {rotateTianPan} from './src/qimen/helpers/tianPan'; export {rotateBamen} from './src/qimen/helpers/bamen';",resolveDir:root,loader:'ts'},bundle:true,platform:'node',format:'cjs',outfile:'/tmp/suji-qimen-post.cjs'});
const own=require('/tmp/suji-qimen-post.cjs');
const {getDiPan}=require('/tmp/suji-research-qimen/lib/dipan.js');
const {distributeBaMen}=require('/tmp/suji-research-qimen/lib/bamen.js');
const {distributeJiuXing}=require('/tmp/suji-research-qimen/lib/jiuxing.js');
const diffs=[],fixtures=[];let earth=0,star=0,door=0,centerExcluded=0;
const stems=[...'甲乙丙丁戊己庚辛壬癸'],branches=[...'子丑寅卯辰巳午未申酉戌亥'];
const sorted=o=>JSON.stringify(Object.entries(o).sort(([a],[b])=>Number(a)-Number(b)));
for(const dun of ['阳','阴'])for(let ju=1;ju<=9;ju++){
 const mode=dun==='阳'?'yang':'yin',dp=getDiPan(mode,ju);earth++;
 if(sorted(dp)!==sorted(Object.fromEntries(own.buildDiPan(dun,ju))))diffs.push({kind:'earth',dun,ju});
 for(let x=0;x<6;x++)for(let t=0;t<10;t++){
  const xun=[...'戊己庚辛壬癸'][x],hour=stems[t]+branches[(x*10+t)%12],source=Object.keys(dp).find(k=>dp[k]===xun);
  const r=own.rotateTianPan(new Map(Object.entries(dp).map(([k,v])=>[+k,v])),xun,stems[t],dun);
  const o=distributeJiuXing(dp,xun,stems[t]);star++;
  // Upstream represents hosted Tian Qin as compound 禽芮, SUJI preserves a flag.
  const os=Object.fromEntries(Object.entries(o.jiuXing).filter(([k])=>k!=='5').map(([k,v])=>[k,v==='禽芮'?'天芮':v]));
  const rs=Object.fromEntries([...r.tianJiuxing].filter(([k])=>k!==5));
  if(sorted(os)!==sorted(rs))diffs.push({kind:'stars',dun,ju,hour,xun});
  if(source==='5'){centerExcluded++;continue;}
  const ours=own.rotateBamen(new Map(Object.entries(dp).map(([k,v])=>[+k,v])),xun,stems[t],dun);
  const theirs=distributeBaMen(source,hour,mode);door++;
  const expected=Object.fromEntries(Object.entries(theirs.baMen).filter(([k])=>k!=='5'));
  if(sorted(Object.fromEntries(ours.bamen))!==sorted(expected))diffs.push({kind:'doors',dun,ju,hour,xun});
  if((dun==='阳'&&ju===1&&x===0&&[0,1,4].includes(t))||(dun==='阴'&&ju===2&&x===0&&[0,4].includes(t))) fixtures.push({dun,ju,xun,hour,source:Number(source),expected,zhiShiMen:theirs.zhiShiMen,zhiShiPalaceId:Number(theirs.zhiShiGong),zhiShiRawPalaceId:Number(theirs.zhiShiGongRaw)});
 }
}
const result={oracle:'qfdk/qimen a32544aa24bd9c7d8e3d24aa456085d5533edafb MIT (package.json says ISC; no code copied)',checks:{earth,star,door,centerExcluded,mismatches:diffs.length},limitations:'Upstream bamen expects a non-central source; 120 central-source cases excluded and covered by separately derived raw-palace regression. qfdk calendar and its 2026-06-05 fixture are not used as an oracle.',diffs,fixtures};
writeFileSync(new URL('qimen-results.json',import.meta.url),JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify(result.checks));
