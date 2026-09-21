import {readFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {expandCastReceipt} from '../receiptLayout';
const folder=resolve(__dirname,'../../../validation/research-divination/efficacy-2026-09-21');
const vectors=JSON.parse(readFileSync(resolve(folder,'receipt-layout-vectors.json'),'utf8'));
const originals=JSON.parse(readFileSync(resolve(folder,'swift-fixtures.json'),'utf8'));
test('actual Swift storage vectors expand to every original field with no mutation',()=>{
 for(const vector of vectors){
  const packed=JSON.parse(vector.packed),saved=JSON.stringify(packed),original=originals.find((x:any)=>x.name===vector.name).reading;
  expect(expandCastReceipt(packed)).toEqual(original);expect(JSON.stringify(packed)).toBe(saved);
  expect(expandCastReceipt(original)).toEqual(original);
 }
});
test('malformed dictionaries, partial rows, missing columns and borrowed questions fail closed',()=>{
 for(let mutation=0;mutation<12;mutation++){
  const packed=JSON.parse(vectors[0].packed);
  const visit=(v:any):any=>{if(!v||typeof v!=='object')return; if('$row' in v)return v;for(const x of Object.values(v)){const found=visit(x);if(found)return found;}};
  const row=visit(packed);
  switch(mutation){
   case 0:delete packed.liuyaoObjectRows;break;
   case 1:packed.liuyaoObjectRows.version=2;break;
   case 2:packed.liuyaoObjectRows.layouts[0].push('extra');break;
   case 3:row.$row[0]=-1;break;
   case 4:row.$row[0]=0.5;break;
   case 5:row.extra=true;break;
   case 6:packed.ruleConditionRows.ids.push('unused');break;
   case 7:packed.ruleConditionRows.paths.push('/unused');break;
   case 8:packed.ruleConditionRows.states.reverse();break;
   case 9:delete packed.ruleConditionRows;break;
   case 10:packed.questionFromArguments={toolCallID:'other'};break;
   default:packed.liuyaoObjectRows.format='untrusted-layout';
  }
  expect(()=>expandCastReceipt(packed)).toThrow();
 }
});
