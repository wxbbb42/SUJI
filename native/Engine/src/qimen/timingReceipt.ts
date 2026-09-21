/** Lossless inverse of the native conditional-date wire/storage dictionary. */
const key='qimenTimingDateRows';
const columns=['unit','ganZhi','branch','startsAt','endsAt','eligibleStart','eligibleEnd','triggerIds','firstWindow'];
const format='If timestamps is an object, expand each offset to canonical ISO UTC milliseconds at base + offset * stepMilliseconds. At /timing/dates map each row to columns. Columns 3–6 are zero-based indices into timestamps; column 7 is an index into triggerSets. Other columns are literal values. Preserve every row and array order; remove qimenTimingDateRows and use original evidence pointers after expansion.';
const object=(x:unknown):x is Record<string,any>=>!!x&&typeof x==='object'&&!Array.isArray(x);
const same=(a:unknown,b:unknown)=>JSON.stringify(a)===JSON.stringify(b);
const nonempty=(x:unknown):x is string=>typeof x==='string'&&x.length>0;
const failure=()=>{throw new Error('奇门条件日期存档无效');};
function expandTimes(value:any):any[] {
  if(Array.isArray(value))return value;
  if(!object(value)||!same(Object.keys(value).sort(),['base','stepMilliseconds','offsets'].sort())||typeof value.base!=='string'||value.base.length!==24||
     !Number.isFinite(Date.parse(value.base))||new Date(value.base).toISOString()!==value.base||!Number.isSafeInteger(value.stepMilliseconds)||value.stepMilliseconds<=0||
     !Array.isArray(value.offsets)||!value.offsets.length||value.offsets.length>1024) return failure();
  const base=Date.parse(value.base);
  return value.offsets.map((offset:any)=>{
    const delta=offset*value.stepMilliseconds,millis=base+delta;
    if(!Number.isSafeInteger(offset)||offset<0||!Number.isSafeInteger(delta)||!Number.isSafeInteger(millis)||millis < -62135596800000||millis>253402300799999)return failure();
    const text=new Date(millis).toISOString();if(text.length!==24)return failure();return text;
  });
}
export function expandQimenTimingReceipt(root:any):any {
  if(!object(root))return root;
  if(!Object.prototype.hasOwnProperty.call(root,key)) {
    if(Array.isArray(root.timing?.dates)&&root.timing.dates.some(Array.isArray))failure();
    return root;
  }
  const m=root[key];
  if(!object(m))return failure();
  const timestamps=expandTimes(m.timestamps);
  if(!object(m)||!same(Object.keys(m).sort(),['version','columns','timestamps','triggerSets','format'].sort())||m.version!==1||!same(m.columns,columns)||m.format!==format||
     !timestamps.length||timestamps.length>1024||!timestamps.every(nonempty)||new Set(timestamps).size!==timestamps.length||
     !Array.isArray(m.triggerSets)||!m.triggerSets.length||m.triggerSets.length>256||!m.triggerSets.every((s:unknown)=>Array.isArray(s)&&s.length>0&&s.every(nonempty))||
     new Set(m.triggerSets.map((s:unknown)=>JSON.stringify(s))).size!==m.triggerSets.length||!object(root.timing)||!Array.isArray(root.timing.dates)||root.timing.dates.length<2||root.timing.dates.length>256)failure();
  const usedTimes=new Set<number>(),usedSets=new Set<number>();
  const dates=root.timing.dates.map((row:unknown)=>{
    if(!Array.isArray(row)||row.length!==columns.length)failure();
    const fields=(row as any[]).slice();
    for(let i=3;i<=7;i++) {
      const table=i===7?m.triggerSets:timestamps,index=fields[i];
      if(!Number.isInteger(index)||index<0||index>=table.length)failure();
      fields[i]=table[index];(i===7?usedSets:usedTimes).add(index);
    }
    if(!['year','month','day','hour'].includes(fields[0])||typeof fields[1]!=='string'||[...fields[1]].length!==2||typeof fields[2]!=='string'||[...fields[2]].length!==1||typeof fields[8]!=='boolean')failure();
    return Object.fromEntries(columns.map((c,i)=>[c,fields[i]]));
  });
  if(usedTimes.size!==timestamps.length||usedSets.size!==m.triggerSets.length)failure();
  const result:Record<string,any>={...root,timing:{...root.timing,dates}};delete result[key];return result;
}
