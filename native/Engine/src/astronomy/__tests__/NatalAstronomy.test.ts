import { dispatch } from '../../../bridge';
import { readFileSync } from 'fs';
import { gunzipSync } from 'zlib';
import { join } from 'path';

const birth={year:2000,month:1,day:15,hour:12,minute:0,gender:'男',longitude:116.4,timeZoneID:'Asia/Shanghai'};
const natal=(b:any=birth)=>dispatch({command:'natal-astronomy',birth:b});
const bodies=['Sun','Moon','Mercury','Venus','Mars','Jupiter','Saturn'];
const coordinateMap={longitudeDegrees:'longitude',latitudeDegrees:'latitude',rightAscensionDegrees:'rightAscensionDegrees',declinationDegrees:'declination'};
const angleError=(a:number,b:number)=>Math.abs(((a-b+540)%360)-180)*3600;

test('natal command returns seven physical objects in a birth-bound fixed-time frame',async()=>{
  const r=await natal();
  expect(r).toMatchObject({schemaVersion:1,engineRevision:'development-unbundled',birthKey:JSON.stringify([2000,1,15,12,0,'男',116.4,'Asia/Shanghai']),
    time:{wallClock:'2000-01-15T12:00',instantUTC:'2000-01-15T04:00:00.000Z',interpretation:'fixed-utc-plus-8-v1',utPolicy:'utc-as-ut1-v1',deltaTModel:'espenak-meeus-v1'},
    sevenBodies:{moduleID:'geocentric-seven-bodies',methodVersion:'astronomy-engine-2.1.19-geocentric-v1'},
    unsupported:['four-residuals','houses','life-degree','traditional-angle-units']});
  expect(r.sevenBodies.positions.map((p:any)=>p.body)).toEqual(bodies);
  expect((r.time.julianDayTT-r.time.julianDayUT)*86400).toBeCloseTo(r.time.deltaTSeconds,3);
  for(const p of r.sevenBodies.positions) {
    expect(p.longitudeDegrees).toBeGreaterThanOrEqual(0);expect(p.longitudeDegrees).toBeLessThan(360);
    expect(p.rightAscensionDegrees).toBeGreaterThanOrEqual(0);expect(p.rightAscensionDegrees).toBeLessThan(360);
    expect(Math.abs(p.latitudeDegrees)).toBeLessThanOrEqual(90);expect(Math.abs(p.declinationDegrees)).toBeLessThanOrEqual(90);
    expect(p.correctionPolicy).toBe(p.body==='Moon'?'geomoon-no-separate-light-time-aberration':'light-time-aberration');
  }
});

test('China year edges are checked in original clock and do not reject UTC1900 lower edge',async()=>{
  expect((await natal({...birth,year:1901,month:1,day:1,hour:0,minute:0})).time.instantUTC).toBe('1900-12-31T16:00:00.000Z');
  expect((await natal({...birth,year:2100,month:12,day:31,hour:23,minute:59})).time.instantUTC).toBe('2100-12-31T15:59:00.000Z');
  for(const invalid of [{year:1900},{year:2101},{year:2100,month:2,day:29},{year:2000,month:2,day:30},{month:0},{hour:24},{minute:-1},{day:1.5},{timeZoneID:'America/New_York'}])
    await expect(natal({...birth,...invalid})).rejects.toThrow(/出生|北京时间|1901/);
  expect((await natal({...birth,year:2000,month:2,day:29})).time.instantUTC).toBe('2000-02-29T04:00:00.000Z');
});

test('longitude and historical DST do not shift physical instant or seven-body coordinates',async()=>{
  const a=await natal({...birth,year:1990,month:7,day:15,longitude:75});
  const b=await natal({...birth,year:1990,month:7,day:15,longitude:135});
  expect(a.time.instantUTC).toBe('1990-07-15T04:00:00.000Z');expect(a.time).toEqual(b.time);
  expect(a.sevenBodies.positions).toEqual(b.sevenBodies.positions);expect(a.birthKey).not.toBe(b.birthKey);
});

test('production seven-body vectors preserve independent Swiss sample comparison including 13 time-model failures',async()=>{
  const rows=JSON.parse(gunzipSync(readFileSync(join(__dirname,'../../../validation/research-qizheng/ephemeris/results/reference.json.gz'))).toString());
  let last='',r:any,defaultFailures=0,maxShared=0,maxDefault=0;
  for(const row of rows) {
    if(row.instant!==last) {
      const d=new Date(row.instant);r=await natal({...birth,year:d.getUTCFullYear(),month:d.getUTCMonth()+1,day:d.getUTCDate(),hour:12});last=row.instant;
    }
    const p=r.sevenBodies.positions.find((p:any)=>p.body===row.body);
    const shared=Object.entries(coordinateMap).map(([out,reference])=>angleError(p[out],row.sharedTT.coordinates[reference]));
    const normal=Object.entries(coordinateMap).map(([out,reference])=>angleError(p[out],row.defaultUT.coordinates[reference]));
    expect(Math.max(...shared)).toBeLessThan(60);maxShared=Math.max(maxShared,...shared);maxDefault=Math.max(maxDefault,...normal);
    if(Math.max(...normal)>60) {defaultFailures++;expect(row.body).toBe('Moon');expect(Number(row.instant.slice(0,4))).toBeGreaterThanOrEqual(2093);}
  }
  expect(rows).toHaveLength(5600);expect(defaultFailures).toBe(13);
  expect(maxShared).toBeCloseTo(21.48523865,4);expect(maxDefault).toBeCloseTo(74.05249389,4);
},30000);

test('tool uses native-owned astronomy snapshot and rejects model-supplied cache or alternate birth/time',async()=>{
  const snapshot=await natal();
  const call={command:'tool',name:'get_natal_astronomy',birth,astronomy:snapshot,arguments:{body:'Moon'},now:'2026-09-20T04:00:00Z'};
  const r=await dispatch(call);
  expect(r.result.sevenBodies.positions).toHaveLength(1);expect(r.result.sevenBodies.positions[0].body).toBe('Moon');
  expect(r.result.time).toEqual(snapshot.time);expect(r.evidence.length).toBeGreaterThan(0);
  for(const args of [{astronomy:snapshot},{snapshot},{birth},{instant:'2001-01-01T00:00:00Z'},{body:'Pluto'}])
    await expect(dispatch({...call,arguments:args})).rejects.toThrow();
  for(const damaged of [{...snapshot,engineRevision:'old'},{...snapshot,birthKey:'wrong'},{...snapshot,time:{...snapshot.time,instantUTC:'2001-01-01T00:00:00.000Z'}},
    {...snapshot,sevenBodies:{...snapshot.sevenBodies,positions:[]}},
    {...snapshot,sevenBodies:{...snapshot.sevenBodies,positions:snapshot.sevenBodies.positions.map((p:any,i:number)=>i? p:{...p,longitudeDegrees:NaN})}}])
    await expect(dispatch({...call,astronomy:damaged})).rejects.toThrow(/失效|天文/);
  const saved=JSON.stringify(snapshot);await dispatch({...call,now:'2030-01-01T04:00:00Z'});expect(JSON.stringify(snapshot)).toBe(saved);
  const all=await dispatch({...call,arguments:{body:'all'}});expect(all.result.sevenBodies.positions).toHaveLength(7);
  expect(Buffer.byteLength(JSON.stringify(all))).toBeLessThan(20000);
});

test('valid cache performs no ephemeris recomputation and unrelated natal charts are not required',async()=>{
  const snapshot=await natal(),saved=JSON.stringify(snapshot);
  const spy=jest.spyOn(require('astronomy-engine'),'GeoVector');
  try {
    const output=await dispatch({command:'tool',name:'get_natal_astronomy',birth,astronomy:snapshot,arguments:{},now:'2026-09-20T04:00:00Z',natal:{invalid:'unrelated'}});
    expect(output.result.sevenBodies.positions).toEqual(snapshot.sevenBodies.positions);
    expect(spy).not.toHaveBeenCalled();expect(JSON.stringify(snapshot)).toBe(saved);
    for(const damaged of [
      {...snapshot,sevenBodies:{...snapshot.sevenBodies,dependencyVersions:{...snapshot.sevenBodies.dependencyVersions,timePolicy:'changed'}}},
      {...snapshot,sevenBodies:{...snapshot.sevenBodies,sourceIDs:['made-up']}},
      {...snapshot,time:{...snapshot.time,wallClock:'2000-01-15T13:00'}},
      {...snapshot,sevenBodies:{...snapshot.sevenBodies,positions:[...snapshot.sevenBodies.positions].reverse()}},
    ])await expect(dispatch({command:'tool',name:'get_natal_astronomy',birth,astronomy:damaged,arguments:{}})).rejects.toThrow(/失效/);
    expect(spy).not.toHaveBeenCalled();
  } finally {spy.mockRestore();}
});

test('native sorted-key JSON roundtrip preserves cache validity without relying on object key insertion order',async()=>{
  const sort=(value:any):any=>Array.isArray(value)?value.map(sort):value&&typeof value==='object'
    ?Object.fromEntries(Object.keys(value).sort().map(key=>[key,sort(value[key])])):value;
  const snapshot=sort(await natal());
  const spy=jest.spyOn(require('astronomy-engine'),'GeoVector');
  try {
    const r=await dispatch({command:'tool',name:'get_natal_astronomy',birth,astronomy:snapshot,arguments:{body:'Sun'}});
    expect(r.result.sevenBodies.positions[0]).toEqual(snapshot.sevenBodies.positions[0]);expect(spy).not.toHaveBeenCalled();
  } finally {spy.mockRestore();}
});

test('production contemporary first-star policy emits28 nonuniform boundaries and seven uncertain memberships',async()=>{
  const r=await natal();
  expect(r.mansions).not.toBeNull();
  expect(r.mansions).toMatchObject({moduleID:'chinese-28-mansions',methodVersion:'contemporary-first-star28-equatorial-v1',
    uncertainty:{birthTimePrecision:'unknown',ephemerisErrorBoundDegrees:null,catalogErrorBoundDegrees:null}});
  expect(r.mansions.boundaries).toHaveLength(28);expect(r.mansions.positions.map((p:any)=>p.body)).toEqual(bodies);
  expect(r.mansions.boundaries.reduce((s:number,b:any)=>s+b.widthDegrees,0)).toBeCloseTo(360,10);
  expect(new Set(r.mansions.boundaries.map((b:any)=>b.widthDegrees)).size).toBeGreaterThan(20);
  for(const p of r.mansions.positions){expect(p.boundaryStatus).toBe('uncertain-time-precision');expect(p.entryDegrees).toBeGreaterThanOrEqual(0);expect(p.entryDegrees).toBeLessThan(p.widthDegrees);}
  const call={command:'tool',name:'get_natal_astronomy',birth,astronomy:r,arguments:{body:'Moon'}};
  for(const altered of [{...r,mansions:null},{...r,mansions:{...r.mansions,methodVersion:'historical-universal'}},
    {...r,mansions:{...r.mansions,boundaries:[...r.mansions.boundaries].reverse()}},
    {...r,mansions:{...r.mansions,positions:r.mansions.positions.map((p:any)=>({...p,index:0}))}}])
      await expect(dispatch({...call,astronomy:altered})).rejects.toThrow(/失效/);
});
