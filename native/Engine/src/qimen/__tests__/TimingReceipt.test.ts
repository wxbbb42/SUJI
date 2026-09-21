import { expandQimenTimingReceipt } from '../timingReceipt';
const format='If timestamps is an object, expand each offset to canonical ISO UTC milliseconds at base + offset * stepMilliseconds. At /timing/dates map each row to columns. Columns 3–6 are zero-based indices into timestamps; column 7 is an index into triggerSets. Other columns are literal values. Preserve every row and array order; remove qimenTimingDateRows and use original evidence pointers after expansion.';
const first={unit:'day',ganZhi:'甲寅',branch:'寅',startsAt:'2004-06-03T15:00:00.000Z',endsAt:'2004-06-04T15:00:00.000Z',eligibleStart:'2004-06-03T16:00:00.000Z',eligibleEnd:'2004-06-04T15:00:00.000Z',triggerIds:['void-fill'],firstWindow:true};
const second={...first,ganZhi:'乙卯',branch:'卯',startsAt:'2004-06-04T15:00:00.000Z',endsAt:'2004-06-05T15:00:00.000Z',eligibleStart:'2004-06-04T15:00:00.000Z',eligibleEnd:'2004-06-05T00:00:00.000Z',triggerIds:['void-clash','other'],firstWindow:false};
const columns=['unit','ganZhi','branch','startsAt','endsAt','eligibleStart','eligibleEnd','triggerIds','firstWindow'];
function packed():any {return {question:'原始问题',unknown:{falseValue:false,empty:[],nullValue:null},timing:{outcomeEstablished:false,dates:[['day','甲寅','寅',0,1,2,1,0,true],['day','乙卯','卯',1,3,1,4,1,false]]},qimenTimingDateRows:{version:1,columns,timestamps:[first.startsAt,first.endsAt,first.eligibleStart,second.endsAt,second.eligibleEnd],triggerSets:[first.triggerIds,second.triggerIds],format}};}

test('native date layout restores literal intervals, clipping, trigger order and every other field without mutation',()=>{
 const input=packed(),saved=JSON.stringify(input),restored=expandQimenTimingReceipt(input);
 expect(restored).toEqual({question:input.question,unknown:input.unknown,timing:{outcomeEstablished:false,dates:[first,second]}});
 expect(JSON.stringify(input)).toBe(saved);expect(expandQimenTimingReceipt(restored)).toEqual(restored);
 const grid=packed();grid.qimenTimingDateRows.timestamps={base:first.startsAt,stepMilliseconds:3600000,offsets:[0,24,1,48,33]};
 expect(expandQimenTimingReceipt(grid)).toEqual(restored);
 const precision=packed();precision.qimenTimingDateRows.timestamps={base:'2004-06-03T15:00:00.001Z',stepMilliseconds:1,offsets:[0,1,2,3,4]};
 expect(expandQimenTimingReceipt(precision).timing.dates[0].eligibleStart).toBe('2004-06-03T15:00:00.003Z');
});

test('damaged or partial date dictionaries and unsafe timestamp grids fail closed',()=>{
 const mutations=[
  (r:any)=>delete r.qimenTimingDateRows,(r:any)=>r.qimenTimingDateRows.version=2,
  (r:any)=>r.qimenTimingDateRows.format='invented',(r:any)=>r.qimenTimingDateRows.extra=false,
  (r:any)=>r.qimenTimingDateRows.timestamps.push('unused'),(r:any)=>r.qimenTimingDateRows.timestamps.push(first.startsAt),
  (r:any)=>r.qimenTimingDateRows.triggerSets.push(['unused']),(r:any)=>r.qimenTimingDateRows.triggerSets.push(first.triggerIds),
  (r:any)=>r.timing.dates[0][3]=-1,(r:any)=>r.timing.dates[0][3]=.5,(r:any)=>r.timing.dates[0][3]=true,
  (r:any)=>r.timing.dates[0][7]=999,(r:any)=>r.timing.dates[0][8]='false',
  (r:any)=>r.timing.dates[0].push(null),(r:any)=>r.timing.dates[0]=first,
 ];
 for(const mutate of mutations){const root=packed();mutate(root);expect(()=>expandQimenTimingReceipt(root)).toThrow(/存档无效/);}
 for(const grid of [{base:first.startsAt,stepMilliseconds:0,offsets:[0,1,2,3,4]},
  {base:'2004-02-30T15:00:00.000Z',stepMilliseconds:1,offsets:[0,1,2,3,4]},
  {base:first.startsAt,stepMilliseconds:Number.MAX_SAFE_INTEGER,offsets:[0,2,3,4,5]},
  {base:first.startsAt,stepMilliseconds:1,offsets:[0,-1,2,3,4]},
  {base:first.startsAt,stepMilliseconds:1,offsets:[0,.5,2,3,4]}]){
   const root=packed();root.qimenTimingDateRows.timestamps=grid;expect(()=>expandQimenTimingReceipt(root)).toThrow(/存档无效/);
 }
});
