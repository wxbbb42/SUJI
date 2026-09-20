const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const folder='native/Engine/validation/reasoning/b5a-independent-review/';
const source=JSON.parse(fs.readFileSync('native/Engine/validation/research-divination/triad-fanfu-source-review.json','utf8'));
const c=vm.createContext({});vm.runInContext(fs.readFileSync('native/Resources/mingli.js','utf8'),c);
// Traditional bottom-up trigram bits, branch start and step. Derive vectors by modular stepping, not Engine tables/helpers.
const names=['坤','震','坎','兑','艮','离','巽','乾'];
const branches=[...'子丑寅卯辰巳午未申酉戌亥'];const start=[7,0,2,5,4,3,1,0],step=[-2,2,2,-2,2,-2,-2,2];
const stems=[[...'乙庚戊丁丙己辛甲'],[...'癸庚戊丁丙己辛壬']];
const directions=new Set(['乾巽','巽乾','坎离','离坎','震兑','兑震','艮坤','坤艮']);
const clash=(a,b)=>(branches.indexOf(a)+6)%12===branches.indexOf(b);
function oracle(v){const from=[],to=[],original=[],resulting=[];
 for(let h=0;h<2;h++){
  const n=v.slice(h*3,h*3+3).reduce((s,x,i)=>s+(x%2)*2**i,0),m=v.slice(h*3,h*3+3).reduce((s,x,i)=>s+([6,7].includes(x)?1:0)*2**i,0);
  from.push(names[n]);to.push(names[m]);
  for(let j=0;j<3;j++){original.push(stems[h][n]+branches[(start[n]+step[n]*j+h*6+24)%12]);resulting.push(stems[h][m]+branches[(start[m]+step[m]*j+h*6+24)%12])}
 }
 const moving=v.flatMap((x,i)=>[6,9].includes(x)?[i]:[]);
 return{original,resulting,fanfu:{sourceId:'liuyao-fanfu-selected-v1',assessmentStatus:'structural-only',efficacyEstablished:false,
  lines:moving.map(i=>({originalPath:'/lines/'+i,changedPath:'/lines/'+i+'/changed',sameStem:original[i][0]===resulting[i][0],sameBranch:original[i][1]===resulting[i][1],branchClash:clash(original[i][1],resulting[i][1])})),
  trigrams:[0,1].map(h=>{const a=original.slice(h*3,h*3+3),b=resulting.slice(h*3,h*3+3);return{side:h?'upper':'lower',from:from[h],to:to[h],movingPositions:moving.filter(i=>Math.floor(i/3)===h).map(i=>i+1),branchRelation:from[h]===to[h]?'unchanged':a.every((x,j)=>x[1]===b[j][1])?'repeated':a.every((x,j)=>clash(x[1],b[j][1]))?'opposed':'neither',directionalOpposition:directions.has(from[h]+to[h])}}),
  unresolved:['selected-object','target-strength','actor-effectiveness','event-outcome']}};
}
async function run(values){c.draws=values.flatMap(v=>Array(v-6).fill(.75).concat(Array(9-v).fill(0)));vm.runInContext('var n=0;Math.random=()=>draws[n++];',c);const args={question:'独立核对结构，不验证结果',questionType:'general',subject:'self',event:'结构核对',timeHorizon:'near'},date='2026-09-20T04:00:00Z';const envelope=await c.SujiNative.dispatch({command:'tool',name:'cast_liuyao',arguments:args,now:date});assert.ok(envelope.result);return{date,rows:[{name:'cast_liuyao',arguments:args,output:JSON.parse(JSON.stringify(envelope.result))}]}}
(async()=>{
let movingLines=0,unchanged=0,repeated=0,opposed=0,directional=0;const directionPairs={},relations={};
for(let n=0;n<4096;n++){const v=Array.from({length:6},(_,i)=>6+Math.floor(n/4**i)%4),f=await run(v),r=f.rows[0].output,o=oracle(v);assert.deepEqual(r.fanfu,o.fanfu);assert.deepEqual(r.guaRelations.original.ganZhi,o.original);assert.deepEqual(r.guaRelations.resulting.ganZhi,o.resulting);
 for(let i=0;i<6;i++){assert.equal(r.lines[i].ganZhi,o.original[i]);if([6,9].includes(v[i]))assert.equal(r.lines[i].changed.ganZhi,o.resulting[i]);else assert.equal(r.lines[i].changed,undefined)}
 movingLines+=o.fanfu.lines.length;
 for(const t of o.fanfu.trigrams){unchanged+=t.branchRelation==='unchanged';repeated+=t.branchRelation==='repeated';opposed+=t.branchRelation==='opposed';directional+=t.directionalOpposition;if(t.directionalOpposition)directionPairs[t.from+t.to]=(directionPairs[t.from+t.to]??0)+1;relations[t.branchRelation]=(relations[t.branchRelation]??0)+1}
}
const z25=source.sources.find(s=>s.id==='zsgy-25');assert.equal(crypto.createHash('sha256').update(z25.text).digest('hex'),z25.sha256);
const examples=[...z25.text.matchAll(/<pre>\n([\s\S]*?)<\/pre>/g)].map((m,i)=>({id:['比之井','临之中孚','姤之恒'][i],text:m[1]}));
for(const id of ['root-xun-sheng','root-guan-sheng']){const p=source.sources[0].passages.find(p=>p.id===id);assert.equal(crypto.createHash('sha256').update(p.text).digest('hex'),p.sha256);examples.push({id,text:p.text})}
const sourceCases=[],sourceFixtures=[];
for(const e of examples){const rows=e.text.split('\n').filter(s=>/[子丑寅卯辰巳午未申酉戌亥][金木水火土][⚊⚋○ㄨ]/u.test(s)).slice(0,6).reverse().map(s=>[...s.matchAll(/([子丑寅卯辰巳午未申酉戌亥])[金木水火土]([⚊⚋○ㄨ])/gu)]);assert.equal(rows.length,6);const values=rows.map(r=>({'⚊':7,'⚋':8,'○':9,'ㄨ':6})[r[0][2]]);const f=await run(values),r=f.rows[0].output;assert.deepEqual(r.lines.map(l=>l.ganZhi[1]),rows.map(x=>x[0][1]));assert.deepEqual(r.guaRelations.resulting.ganZhi.map(s=>s[1]),rows.map(x=>x[1][1]));assert.deepEqual(r.fanfu,oracle(values).fanfu);sourceCases.push({id:e.id,values,original:r.benGua.name,resulting:r.bianGua.name,fanfu:r.fanfu});sourceFixtures.push({...f,label:e.id})}
for(const values of [[7,7,7,7,7,7],[9,7,7,6,7,7],[7,8,7,8,7,8]])sourceFixtures.push(await run(values));
const distinctions={biJingMovingPositions:sourceCases[0].fanfu.trigrams[0].movingPositions,biJingStaticProjectionChanges:sourceFixtures[0].rows[0].output.guaRelations.original.ganZhi[0]!==sourceFixtures[0].rows[0].output.guaRelations.resulting.ganZhi[0],gouHengSameBranchDifferentStem:sourceCases[2].fanfu.lines.every(l=>l.sameBranch&&!l.sameStem)};
assert.deepEqual({movingLines,unchanged,repeated,opposed,directional},{movingLines:12288,unchanged:1024,repeated:256,opposed:256,directional:1024});
fs.writeFileSync(folder+'source-fixtures.json',JSON.stringify(sourceFixtures));
const report={cases:4096,method:'Independent modular Najia branch start/step reconstruction plus literal stems/trigram bits, branch delta6 clashes, named directional set; no production helper imports. Actual bundled Engine.',movingLines,unchanged,repeated,opposed,directional,directionPairs,relations,sourceCharts:sourceCases.length,sourceCases,distinctions,sourceDisagreements:source.sourceDisagreements.filter(d=>['fanfu-opening','root-trigram-ambiguity','static-fuyin'].includes(d.id)),limitations:['Source diagram checks use a modern fixed timestamp because fanfu is calendar-independent; no historical calendar reconstruction or outcome validation.','Electronic texts are not print-collated.','Static full projections are not actual changed objects.']};fs.writeFileSync(folder+'engine-source-report.json',JSON.stringify(report,null,2));console.log(JSON.stringify({...report,sourceCases:undefined,sourceDisagreements:undefined},null,2));
})().catch(e=>{console.error(e);process.exitCode=1});
