/** Strict inverse of Core's final repeated-value dictionary. */
const key='sharedValueRows',marker='$v';
const format='Expand each {"$v":i} from values[i], recursively. Dictionary values may reference only earlier entries. Then remove sharedValueRows and expand object, condition and date layouts; original JSON pointers apply after expansion.';
const object=(v:any):v is Record<string,any>=>!!v&&typeof v==='object'&&!Array.isArray(v);
const reserved=(v:any):boolean=>Array.isArray(v)?v.some(reserved):object(v)?(key in v||marker in v||Object.values(v).some(reserved)):false;
const canonical=(v:any):string=>JSON.stringify(Array.isArray(v)?v.map(x=>JSON.parse(canonical(x))):object(v)?Object.fromEntries(Object.keys(v).sort().map(k=>[k,JSON.parse(canonical(v[k]))])):v);
export function expandJSONValueReceipt(input:any):any {
  const fail=():never=>{throw new Error('原盘共享值字典不完整或索引无效');};
  if(!object(input)||!(key in input)){if(reserved(input))fail();return input;}
  const m=input[key];
  if(marker in input||!object(m)||JSON.stringify(Object.keys(m).sort())!==JSON.stringify(['format','values','version'])||m.version!==1||m.format!==format||!Array.isArray(m.values)||!m.values.length||m.values.length>4096)fail();
  const values:any[]=[],costs:number[]=[],used=new Set<number>(),unique=new Set<string>();
  const unpack=(v:any,limit:number):[any,number]=>{
    if(object(v)&&marker in v){const i=v[marker];if(Object.keys(v).length!==1||!Number.isSafeInteger(i)||i<0||i>=limit)fail();used.add(i);return[values[i],costs[i]];}
    if(object(v)&&key in v)fail();
    if(Array.isArray(v)||object(v)){
      let cost=2;const entries=Array.isArray(v)?v.map((x,i)=>[String(i),x]):Object.entries(v);
      const result=entries.map(([k,x])=>{const[value,n]=unpack(x,limit);cost+=n+String(k).length*6+4;if(cost>2_000_000)fail();return[k,value];});
      return[Array.isArray(v)?result.map(x=>x[1]):Object.fromEntries(result),cost];
    }
    const n=JSON.stringify(v).length*6;if(n>2_000_000)fail();return[v,n];
  };
  for(const entry of m.values){const[value,cost]=unpack(entry,values.length),id=canonical(value);if(unique.has(id))fail();unique.add(id);values.push(value);costs.push(cost);}
  const[result]=unpack(Object.fromEntries(Object.entries(input).filter(([k])=>k!==key)),values.length);
  if(used.size!==values.length)fail();return result;
}
