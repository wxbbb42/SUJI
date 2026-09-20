import {HexagramEngine} from '../HexagramEngine';
import type {CastOptions,QuestionType} from '../types';
const engine=new HexagramEngine();
test('exhaustive question metadata and conditional timing capacity probe',()=>{
 const top:any[]=[];
 for(let code=0;code<4096;code++)for(const qt of ['parents','kids','wealth','career'] as QuestionType[]){
  const values=Array.from({length:6},(_,i)=>6+((code>>(i*2))&3)) as CastOptions['lineValues'];
  const reading=engine.cast({question:'容量测试',questionType:qt,questionContext:{subject:qt==='parents'?'parent':qt==='kids'?'child':'self',event:'容量测试',timeHorizon:'near'},lineValues:values,castTime:new Date('2026-09-19T04:00:00Z')});
  const size=Buffer.byteLength(JSON.stringify(reading));
  if(top.length<5||size>top[top.length-1].size){top.push({size,values,qt,name:reading.benGua.name});top.sort((a,b)=>b.size-a.size);top.splice(5);}
 }
 if(process.env.SUJI_QUESTION_CAPACITY_OUTPUT)require('node:fs').writeFileSync(process.env.SUJI_QUESTION_CAPACITY_OUTPUT,JSON.stringify(top,null,2));expect(top[0].size).toBeLessThan(45_000);
});
