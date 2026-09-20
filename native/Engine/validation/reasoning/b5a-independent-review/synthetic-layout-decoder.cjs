const fs=require('node:fs'),assert=require('node:assert/strict');
const folder='native/Engine/validation/reasoning/b5a-independent-review/';
const {original,packed}=JSON.parse(fs.readFileSync(folder+'layout-synthetic-values.json','utf8'));
const meta=packed.liuyaoObjectRows;let count=0;
function inverse(value){if(Array.isArray(value))return value.map(inverse);if(value===null||typeof value!=='object')return value;if(Object.hasOwn(value,'$row')){const [index,...values]=value.$row;assert.equal(meta.layouts[index].length,values.length);count++;return Object.fromEntries(meta.layouts[index].map((key,i)=>[key,inverse(values[i])]))}return Object.fromEntries(Object.entries(value).filter(([key])=>key!=='liuyaoObjectRows').map(([k,v])=>[k,inverse(v)]));}
const restored=inverse(packed);assert.deepEqual(restored,original);
for(const item of restored.items){assert.equal(Object.getPrototypeOf(item),Object.prototype);assert.ok(Object.hasOwn(item,'__proto__'));assert.equal(item.__proto__,'prototype-key-is-data');assert.equal(item.constructor,'constructor-is-data')}
assert.deepEqual(restored.items[0].alphaLongFieldName,null);assert.deepEqual(restored.items[9].alphaLongFieldName,[]);assert.deepEqual(restored.items[10].alphaLongFieldName,{});assert.notDeepEqual(restored.items[9].alphaLongFieldName,restored.items[10].alphaLongFieldName);
const report={pass:true,rows:count,variants:restored.items.length,prototypeKeysPreservedAsData:true,emptyArrayObjectNullDistinct:true,scope:'Standalone inverse via recursive Object.fromEntries; exact deep equality of synthetic original and packed JSON, no production inverse imports.'};fs.writeFileSync(folder+'synthetic-layout-decoder-report.json',JSON.stringify(report,null,2));console.log(report);
