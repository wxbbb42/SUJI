import {meanLunarPoints,purpleLongitude,PURPLE_PERIOD_DAYS} from '../residuals';
import {readFileSync} from 'fs';
import {join} from 'path';

test('mean node J2000 and projected apogee preserve independent reference definitions',()=>{
  const p=meanLunarPoints(2451545);
  expect(p.ascendingNodeDegrees).toBeCloseTo(125.04455501,8);
  expect(p.apogeeLongitudeDegrees).toBeCloseTo(263.468120348,6);
  expect(p.apogeeLatitudeDegrees).toBeCloseTo(3.419723161,6);
  expect(Math.abs(p.apogeeLongitudeDegrees-263.35324312)).toBeGreaterThan(.1);
  for(const v of [NaN,Infinity,-Infinity]){expect(()=>meanLunarPoints(v)).toThrow();expect(()=>purpleLongitude(v)).toThrow();}
});
test('purple parameters independently return epoch, half and whole period without sign loss',()=>{
  const epoch=2442485+1/6; // 1975-03-13 16:00 UTC, independently tabulated Julian day.
  expect(purpleLongitude(epoch)).toBeCloseTo(230.5,8);
  expect(purpleLongitude(epoch+PURPLE_PERIOD_DAYS/2)).toBeCloseTo(50.5,8);
  expect(purpleLongitude(epoch+PURPLE_PERIOD_DAYS)).toBeCloseTo(230.5,8);
  expect(purpleLongitude(epoch-PURPLE_PERIOD_DAYS)).toBeCloseTo(230.5,8);
});
test('800 independent Swiss mean-node and mean-apogee quarterly vectors meet predeclared 1 arcsecond',()=>{
  const rows=JSON.parse(readFileSync(join(__dirname,'../../../validation/research-qizheng/completion-2026-09-21/residual-reference.json'),'utf8'));
  expect(rows).toHaveLength(800);
  for(const row of rows) {
    const p=meanLunarPoints(row.julianDayTT);
    for(const key of Object.keys(p) as (keyof typeof p)[])
      expect(Math.abs(((p[key]-row.swiss[key]+540)%360)-180)*3600).toBeLessThan(1);
  }
});
