import {readFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {expandJSONValueReceipt} from '../valueReceipt';
const vector=JSON.parse(readFileSync(resolve(__dirname,'../../../validation/research-divination/efficacy-2026-09-21/value-receipt-vector.json'),'utf8'));
test('Swift shared values restore unknown fields and nested repeated objects without mutation',()=>{
 const before=JSON.stringify(vector.packed);expect(expandJSONValueReceipt(vector.packed)).toEqual(vector.original);expect(JSON.stringify(vector.packed)).toBe(before);
});
test('missing, cyclic, forward, unused, duplicate and malformed value references fail closed',()=>{
 const clone=()=>JSON.parse(JSON.stringify(vector.packed));const variants:any[]=[];
 let x=clone();delete x.sharedValueRows;variants.push(x);
 for(const wrong of [-1,99999,0.5,false,'0']){x=clone();x.invalid={$v:wrong};variants.push(x);}
 for(const wrong of [{$v:0},{$v:99999},{sharedValueRows:false}]){x=clone();x.sharedValueRows.values[0]=wrong;variants.push(x);}
 for(const extra of [vector.packed.sharedValueRows.values[0],'unused unique value']){x=clone();x.sharedValueRows.values.push(extra);variants.push(x);}
 x=clone();x.extra={$v:0,other:true};variants.push(x);
 x=clone();x.sharedValueRows.version=2;variants.push(x);
 for(const v of variants)expect(()=>expandJSONValueReceipt(v)).toThrow();
});
