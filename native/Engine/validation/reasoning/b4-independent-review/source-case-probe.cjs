const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const esbuild=require('../../../node_modules/esbuild');
const folder='native/Engine/validation/reasoning/b4-independent-review/';
const archive=JSON.parse(fs.readFileSync('native/Engine/validation/research-divination/lifecycle-source-review.json','utf8'));
const ch30=archive.sources.find(s=>s.id==='zsgy-root').passages.find(p=>p.heading==='隨鬼入墓章第三十').text;
const examples=[['申月戊辰日占夫病癸亥命','壬申','戊辰'],['戌月甲寅日會試能連捷否','甲戌','甲寅'],['申月己丑日占病壬申命得雷風恆','壬申','己丑'],['未月戊辰日占已定重罪可蒙赦免否','癸未','戊辰'],['申月己未日占賊來否得大畜之泰卦','壬申','己未']];
const table={木:['未','申'],火:['戌','亥'],土:['辰','巳'],金:['丑','寅'],水:['辰','巳']};
(async()=>{
const bundled=await esbuild.build({entryPoints:['native/Engine/src/divination/HexagramEngine.ts'],bundle:true,platform:'node',format:'cjs',write:false,tsconfig:'native/Engine/tsconfig.json',plugins:[{name:'independent-source-pillars',setup(build){build.onResolve({filter:/calendar\/precision$/},()=>({path:'fixed-source-pillars',namespace:'source'}));build.onLoad({filter:/.*/,namespace:'source'},()=>({contents:'export const getCalendarPillars=()=>globalThis.__sourcePillars;',loader:'js'}))}}]});
const ctx=vm.createContext({module:{exports:{}},console});vm.runInContext(bundled.outputFiles[0].text,ctx);const engine=new ctx.module.exports.HexagramEngine();
const results=[];
for(const [anchor,month,day] of examples){
 const offset=ch30.indexOf(anchor);assert.ok(offset>=0);const rawRows=ch30.slice(offset).split(/\n/).filter(x=>/[子丑寅卯辰巳午未申酉戌亥][金木水火土][⚊⚋○ㄨ]/u.test(x)).slice(0,6).reverse();
 const sourceRows=rawRows.map(r=>[...r.matchAll(/([子丑寅卯辰巳午未申酉戌亥])([金木水火土])([⚊⚋○ㄨ])/gu)]);
 const values=sourceRows.map(r=>({'⚊':7,'⚋':8,'○':9,'ㄨ':6})[r[0][3]]);
 ctx.__sourcePillars={month,day,hour:'庚午'};const r=JSON.parse(JSON.stringify(engine.cast({question:'独立核对正文盘面，不验证占断结果',questionType:'general',castTime:new Date('2026-09-20T04:00:00Z'),lineValues:values})));
 assert.deepEqual(r.lines.map(l=>l.ganZhi[1]),sourceRows.map(s=>s[0][1]));
 assert.deepEqual(r.guaRelations.resulting.ganZhi.map(x=>x[1]),sourceRows.map(s=>(s[1]??s[0])[1]));
 assert.deepEqual(r.lines.map(l=>l.wuXing),sourceRows.map(s=>s[0][2]));
 const originalRows=r.tombExtinction.objects.filter(o=>/^\/lines\/\d$/.test(o.objectPath));
 const lookup=(e,b)=>table[e][0]===b?'墓':table[e][1]===b?'绝':'neither';
 for(let i=0;i<6;i++){
  const e=sourceRows[i][0][2],expected={month:lookup(e,month[1]),day:lookup(e,day[1]),movingTombPositions:sourceRows.flatMap((s,j)=>j!==i&&[6,9].includes(values[j])&&s[0][1]===table[e][0]?[j+1]:[])};
  for(const [k,v] of Object.entries(expected))assert.deepEqual(originalRows[i][k],v);
  if([6,9].includes(values[i]))assert.equal(originalRows[i].ownChange,lookup(e,sourceRows[i][1][1]));else assert.equal(originalRows[i].ownChange,undefined);
 }
 assert.equal(r.tombExtinction.efficacyEstablished,false);
 results.push({anchor,sourceMonthBranch:month[1],sourceDay:day,values,original:r.benGua.name,resulting:r.bianGua.name,originalRows,sourceOriginalBranches:sourceRows.map(s=>s[0][1]),sourceResultingBranches:sourceRows.map(s=>(s[1]??s[0])[1])});
}
assert.equal(results[1].originalRows[3].month,'墓');assert.equal(results[1].originalRows[3].ownChange,'墓');assert.deepEqual(results[1].originalRows[3].movingTombPositions,[6]);
assert.equal(results[2].originalRows[2].day,'墓');assert.deepEqual(results[2].originalRows[2].movingTombPositions,[]);
assert.equal(results[3].originalRows[2].ownChange,'墓');assert.deepEqual(results[3].originalRows[2].movingTombPositions,[1]);
fs.writeFileSync(folder+'source-case-report.json',JSON.stringify({passed:results.length,scope:'Parse five chapter30 chart glyphs/branches from the reviewed archive. Fixed source month/day coordinates only; synthetic month stems/hour and modern timestamp are scaffolding, not historical Gregorian reconstruction. Assert entire original/resulting branch arrays, original elements, every original month/day/tomb actor relation, all actual own-change references. No source narrative outcome validation.',sourceRawHash:archive.sources.find(s=>s.id==='zsgy-root').sha256,cases:results},null,2));console.log('Passed five independently parsed source chart cases');
})().catch(e=>{console.error(e);process.exitCode=1});
