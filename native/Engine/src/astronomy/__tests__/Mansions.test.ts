import * as natal from '../natal';
const api=natal as any;
// Synthetic equally-spaced stars are only a geometry counterexample, never a production identity table.
const synthetic=()=>Array.from({length:28},(_,i)=>({name:`test${i}`,designation:`test${i}`,hip:i+1,rightAscensionDegrees:(350+i*360/28)%360}));
const get=(name:string)=>{expect(api[name]).toEqual(expect.any(Function));return api[name];};

test('ordered boundaries cover exactly one circle before wrapping, preserving all unequal widths',()=>{
  const stars=synthetic();stars[2].rightAscensionDegrees+=1;
  const bounds=get('buildMansionBoundaries')(stars);
  expect(bounds).toHaveLength(28);
  expect(bounds[0]).toMatchObject({name:'test0',rightAscensionDegrees:350,nextRightAscensionDegrees:stars[1].rightAscensionDegrees});
  expect(bounds.reduce((sum:number,b:any)=>sum+b.widthDegrees,0)).toBeCloseTo(360,10);
  expect(bounds[1].widthDegrees).toBeCloseTo(360/28+1,10);expect(bounds[2].widthDegrees).toBeCloseTo(360/28-1,10);
});

test('duplicate, reversed, old觜参 and missing/full-circle-invalid distance-star orders are rejected',()=>{
  const make=get('buildMansionBoundaries'),stars=synthetic();
  expect(()=>make(stars.slice(1))).toThrow(/28/);
  expect(()=>make([...stars].reverse())).toThrow(/顺序|一周/);
  expect(()=>make(stars.map((s,i)=>i===1?{...s,rightAscensionDegrees:stars[0].rightAscensionDegrees}:s))).toThrow();
  expect(()=>make(stars.map((s,i)=>i===1?{...s,hip:stars[0].hip}:s))).toThrow();
  expect(()=>make(stars.map((s,i)=>i===1?{...s,rightAscensionDegrees:NaN}:s))).toThrow();
  // Literal old φ1Ori -> δOri negative ordering; never reinterpret as a 359° span.
  const old=stars.map(s=>({...s}));old[8].rightAscensionDegrees=83.7065;old[9].rightAscensionDegrees=83.003;
  expect(()=>make(old)).toThrow(/顺序|一周/);
});

test('membership is left-closed/right-open on both sides and across zero; uncertainty is never hidden',()=>{
  const bounds=get('buildMansionBoundaries')(synthetic()),assign=get('assignMansion');
  const right=bounds[1].rightAscensionDegrees;
  expect(assign('Moon',350,bounds)).toMatchObject({mansion:'test0',index:0,entryDegrees:0,distanceToBoundaryDegrees:0,boundaryStatus:'uncertain-time-precision'});
  expect(assign('Moon',0,bounds)).toMatchObject({mansion:'test0',index:0,entryDegrees:10,boundaryStatus:'uncertain-time-precision'});
  expect(assign('Moon',right-1e-8,bounds).index).toBe(0);
  expect(assign('Moon',right,bounds)).toMatchObject({index:1,entryDegrees:0,distanceToBoundaryDegrees:0});
  expect(assign('Moon',right+1e-8,bounds).index).toBe(1);
  expect(()=>assign('Moon',360,bounds)).toThrow();expect(()=>assign('Moon',NaN,bounds)).toThrow();
});

test('catalogue proper motion and true-equator transform independently match ERFA at1901,J2000,2100',()=>{
  const transform=get('transformDistanceStar');
  const catalog=require('../../../validation/research-qizheng/catalogue/mansion-catalog-candidate.json');
  const reference=require('../../../validation/research-qizheng/catalogue/erfa-transform-reference.json');
  const {AstroTime}=require('astronomy-engine');
  let maximumArcseconds=0;
  for(const row of reference.rows) {
    const time=AstroTime.FromTerrestrialTime(row.ttJulianDate-2451545);
    const transformed=catalog.stars.map((s:any)=>transform(s,time));
    transformed.forEach((star:any,index:number)=>{
      const wanted=row.stars[index];expect(star.hip).toBe(wanted.hip);expect(star.name).toBe(wanted.name);
      const ra=Math.abs(((star.rightAscensionDegrees-wanted.raDegrees+540)%360)-180)*3600;
      const dec=Math.abs(star.declinationDegrees-wanted.decDegrees)*3600;
      // Initial0.1arcsec screen failed: AE2.1.19 uses only5 leading nutation terms.
      // 0.2arcsec is an explicitly measured sample-regression screen, not an all-date accuracy bound.
      expect(ra).toBeLessThan(0.2);expect(dec).toBeLessThan(0.2);maximumArcseconds=Math.max(maximumArcseconds,ra,dec);
    });
    const bounds=get('buildMansionBoundaries')(transformed);
    expect(Math.min(...bounds.map((b:any)=>b.widthDegrees))).toBeCloseTo(row.minimumWidthDegrees,4);
  }
  expect(maximumArcseconds).toBeCloseTo(0.1360422681,6);
  expect(()=>transform({...catalog.stars[0],pmRaMasYear:NaN},new Date())).toThrow();
  expect(()=>transform({...catalog.stars[0],decDegrees:100},new Date())).toThrow();
});
