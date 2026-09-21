const fs=require('fs'),vm=require('vm'),assert=require('assert');
const c=vm.createContext({console});vm.runInContext(fs.readFileSync('native/Resources/mingli.js','utf8'),c);
const names=['坤','震','坎','兑','艮','离','巽','乾'];
const gz={坤:['乙未','乙巳','乙卯','癸丑','癸亥','癸酉'],震:['庚子','庚寅','庚辰','庚午','庚申','庚戌'],坎:['戊寅','戊辰','戊午','戊申','戊戌','戊子'],兑:['丁巳','丁卯','丁丑','丁亥','丁酉','丁未'],艮:['丙辰','丙午','丙申','丙戌','丙子','丙寅'],离:['己卯','己丑','己亥','己酉','己未','己巳'],巽:['辛丑','辛亥','辛酉','辛未','辛巳','辛卯'],乾:['甲子','甲寅','甲辰','壬午','壬申','壬戌']};
const combines={子:'丑',丑:'子',寅:'亥',亥:'寅',卯:'戌',戌:'卯',辰:'酉',酉:'辰',巳:'申',申:'巳',午:'未',未:'午'};
const clashes={子:'午',午:'子',丑:'未',未:'丑',寅:'申',申:'寅',卯:'酉',酉:'卯',辰:'戌',戌:'辰',巳:'亥',亥:'巳'};
const ptr=(r,p)=>p.split('/').slice(1).reduce((x,k)=>x[k],r);
const rel=(a,b)=>combines[a]===b?'六合':clashes[a]===b?'六冲':'neither';
const kind=arr=>arr.every(v=>v==='六合')?'六合':arr.every(v=>v==='六冲')?'六冲':'ordinary';
(async()=>{let count=0,moving=0,staticN=0,max=0,maxcase=null,maxResult,sets={'六合':new Set(),'六冲':new Set()}; const transitions={};
for(let n=0;n<4096;n++) {
 const vals=Array.from({length:6},(_,i)=>6+(n>>(2*i)&3));
 c.draws=vals.flatMap(v=>Array(v-6).fill(.75).concat(Array(9-v).fill(0)));vm.runInContext('var idx=0;Math.random=()=>draws[idx++];',c);
 const {result:r}=await c.SujiNative.dispatch({command:'tool',name:'cast_liuyao',arguments:{question:'独立审查',questionType:'general'},now:'2026-09-19T04:00:00Z'});
 assert.deepEqual(Array.from(r.lineValues),vals);
 const original=vals.map(v=>v%2),resulting=vals.map(v=>v===6||v===7?1:0);
 for (const [side,bits] of [['original',original],['resulting',resulting]]) {
  const lower=names[bits[0]+2*bits[1]+4*bits[2]],upper=names[bits[3]+2*bits[4]+4*bits[5]],expected=gz[lower].slice(0,3).concat(gz[upper].slice(3));
  const f=r.guaRelations[side],g=ptr(r,f.guaPath);
  assert.equal(g.lower,lower);assert.equal(g.upper,upper);assert.deepEqual(Array.from(f.ganZhi),expected);
  const expectedRelations=[0,1,2].map(i=>rel(expected[i][1],expected[i+3][1]));assert.equal(f.kind,kind(expectedRelations));
  if(side==='original'&&sets[f.kind])sets[f.kind].add(g.name);
  for(let i=0;i<3;i++){const p=f.pairs[i];assert.deepEqual(Array.from(p.positions),[i+1,i+4]);assert.equal(p.relation,expectedRelations[i]);assert.deepEqual(Array.from(p.positions).map(position=>f.ganZhi[position-1][1]),[expected[i][1],expected[i+3][1]]);}
 }
 const changed=vals.flatMap((v,i)=>v===6||v===9?[i+1]:[]);assert.deepEqual(Array.from(r.changingYao),changed);
 assert.equal(r.guaRelations.transition.hasChange,changed.length>0);
 for(let i=0;i<6;i++){const l=r.lines[i],movingHere=changed.includes(i+1);assert.equal(l.isChanging,movingHere);assert.equal(!!l.changed,movingHere);assert.equal(!!l.rules.returning,movingHere);if(!movingHere)continue;moving++;
  const b=l.rules.returning;assert.strictEqual(ptr(r,b.from),l.changed);assert.strictEqual(ptr(r,b.to),l);assert.equal(b.branchRelation,l.ganZhi[1]===l.changed.ganZhi[1]?'同支':rel(l.ganZhi[1],l.changed.ganZhi[1]));assert(Array.isArray(ptr(r,b.conditionsFrom)));assert(r.ruleSources.some(x=>x.id===b.sourceId));assert(r.ruleSources.some(x=>x.id===b.branchSourceId));
 }
 const trans=r.guaRelations.transition;transitions[trans.kind]=(transitions[trans.kind]||0)+1;
 const expectedTransition=changed.length===0?'static':trans.fromKind!=='ordinary'&&trans.toKind!=='ordinary'?trans.fromKind+'变'+trans.toKind:'other-change';assert.equal(trans.kind,expectedTransition);
 if(changed.length===0){staticN++;assert.equal(trans.kind,'static')};for(const p of trans.factPaths)assert.notEqual(ptr(r,p),undefined);
 assert.equal(r.guaRelations.outcomeEstablished,false);
 const size=JSON.stringify(r).length;if(size>max){max=size;maxcase=vals;maxResult=r;}count++;
}
fs.writeFileSync('/tmp/suji-b2-max-cast.json',JSON.stringify(maxResult));
console.log(JSON.stringify({count,moving,staticN,classifications:Object.fromEntries(Object.entries(sets).map(([k,v])=>[k,[...v].sort()])),transitions,maxUTF16:max,maxcase},null,2));
})().catch(e=>{console.error(e);process.exit(1)});
