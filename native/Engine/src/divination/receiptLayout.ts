import {expandQimenTimingReceipt} from '../qimen/timingReceipt';
import {expandJSONValueReceipt} from './valueReceipt';

/** Strict inverse of Core's existing, self-contained object/condition layouts.
 * Expansion precedes original-chart validation and never changes a cast fact. */
const layoutDescription='Recursively replace each {"$row":[i,...values]} with Object.fromEntries(layouts[i].map((key,j)=>[key,values[j]])). Expand nested rows first; arrays retain order. Exclude root keys liuyaoObjectRows, ruleConditionRows, questionFromArguments; then expand ruleConditionRows. Use original JSON pointers after expansion.';
const conditionDescription='At /lines/*/rules/*/conditions expand each row by columns to {id:ids[idIndex],state:states[stateIndex],factPaths:factPathIndices.map(i=>paths[i])}. All indices are zero-based; follow original evidence pointers after expansion. Other fields are unchanged.';
const object=(v:any):v is Record<string,any>=>!!v&&typeof v==='object'&&!Array.isArray(v);
const equal=(a:any,b:any)=>JSON.stringify(a)===JSON.stringify(b);
const keys=(v:Record<string,any>,expected:string[])=>equal(Object.keys(v).sort(),[...expected].sort());
const fail=():never=>{throw new Error('原盘无损布局不完整或索引无效');};
const index=(v:any,length:number)=>Number.isSafeInteger(v)&&v>=0&&v<length?v:fail();
const uniqueStrings=(v:any,check:(s:string)=>boolean)=>Array.isArray(v)&&v.every(s=>typeof s==='string'&&check(s))&&new Set(v).size===v.length;
const reserved=(v:any):boolean=>Array.isArray(v)?v.some(reserved):object(v)?('$row' in v||'liuyaoObjectRows' in v||Object.values(v).some(reserved)):false;
export function expandCastReceipt(input:any):any {
  if(!object(input)||'questionFromArguments' in input||'ruleSourcesFromDirectory' in input)fail();
  let root=expandJSONValueReceipt(JSON.parse(JSON.stringify(input)));
  if('liuyaoObjectRows' in root){
    const metadata=root.liuyaoObjectRows;
    if('$row' in root||!object(metadata)||!keys(metadata,['version','layouts','format'])||metadata.version!==1||metadata.format!==layoutDescription||!Array.isArray(metadata.layouts)||!metadata.layouts.length)fail();
    const layouts=metadata.layouts as string[][];
    for(const layout of layouts)if(!uniqueStrings(layout,s=>!!s&&s!=='$row'&&s!=='liuyaoObjectRows')||!layout.length||!equal(layout,[...layout].sort()))fail();
    if(new Set(layouts.map(x=>JSON.stringify(x))).size!==layouts.length)fail();
    const used=layouts.map(()=>0);
    const expand=(v:any):any=>{
      if(Array.isArray(v))return v.map(expand);
      if(!object(v))return v;
      if('liuyaoObjectRows' in v)fail();
      if('$row' in v){
        if(Object.keys(v).length!==1||!Array.isArray(v.$row))fail();
        const i=index(v.$row[0],layouts.length),columns=layouts[i];
        if(v.$row.length!==columns.length+1)fail();used[i]++;
        return Object.fromEntries(columns.map((k,j)=>[k,expand(v.$row[j+1])]));
      }
      if(layouts.some(x=>equal(x,Object.keys(v).sort())))fail();
      return Object.fromEntries(Object.entries(v).map(([k,x])=>[k,expand(x)]));
    };
    root=Object.fromEntries(Object.entries(root).filter(([k])=>k!=='liuyaoObjectRows').map(([k,v])=>{
      if(k==='ruleConditionRows'){if(reserved(v))fail();return [k,v];}
      return [k,expand(v)];
    }));
    if(used.some(n=>n<2))fail();
  } else if(reserved(root))fail();
  root=expandQimenTimingReceipt(root);
  if(!('ruleConditionRows' in root)){
    if(Array.isArray(root.lines))for(const line of root.lines)if(object(line?.rules))for(const rule of Object.values(line.rules))
      if(object(rule)&&Array.isArray(rule.conditions)&&rule.conditions.some(Array.isArray))fail();
    return root;
  }
  const metadata=root.ruleConditionRows;
  if(!object(metadata)||!keys(metadata,['version','columns','ids','states','paths','format'])||metadata.version!==1||metadata.format!==conditionDescription||
    !equal(metadata.columns,['idIndex','stateIndex','factPathIndices'])||!equal(metadata.states,['matched','not-matched','unresolved'])||
    !uniqueStrings(metadata.ids,s=>!!s)||!metadata.ids.length||!uniqueStrings(metadata.paths,s=>s.startsWith('/'))||!Array.isArray(root.lines)||root.lines.length!==6)fail();
  const used=new Set<number>(),usedPaths=new Set<number>();
  root.lines=root.lines.map((line:any)=>{
    if(!object(line)||!object(line.rules))fail();
    return {...line,rules:Object.fromEntries(Object.entries(line.rules).map(([key,rawRule])=>{
      const rule=rawRule as any;
      if(!object(rule))fail();
      if(!('conditions' in rule))return [key,rule];
      if(!Array.isArray(rule.conditions))fail();
      return [key,{...rule,conditions:rule.conditions.map((row:any)=>{
        if(!Array.isArray(row)||row.length!==3||!Array.isArray(row[2]))fail();
        const i=index(row[0],metadata.ids.length),state=index(row[1],3);used.add(i);
        const factPaths=row[2].map((v:any)=>{const j=index(v,metadata.paths.length);usedPaths.add(j);return metadata.paths[j];});
        return {id:metadata.ids[i],state:metadata.states[state],factPaths};
      })}];
    }))};
  });
  if(used.size!==metadata.ids.length||usedPaths.size!==metadata.paths.length)fail();
  delete root.ruleConditionRows;return root;
}

export const expandLiuyaoReceipt=expandCastReceipt;
