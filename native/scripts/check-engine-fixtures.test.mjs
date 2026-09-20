import test from 'node:test';
import assert from 'node:assert/strict';
import { compareFixtures } from './check-engine-fixtures.mjs';

const astronomy = () => [{ request: { command:'natal-astronomy', birth:{year:1901} }, result:{
  time:{julianDayUT:2451545}, sevenBodies:{positions:[{body:'Venus',latitudeDegrees:-0.9745985545799962}]},
  mansions:{methodVersion:'contemporary-first-star28-equatorial-v1',positions:[{body:'Venus',mansion:'参',entryDegrees:1,index:20}]},
} }];

test('accepts the actual Linux/macOS last-bit difference without changing fixtures', () => {
  const saved=astronomy(), built=structuredClone(saved);
  built[0].result.sevenBodies.positions[0].latitudeDegrees=-0.9745985545800006;
  const before=JSON.stringify(built);
  assert.deepEqual(compareFixtures(built,saved),[]);
  assert.equal(JSON.stringify(built),before);
});
test('rejects a material astronomy angle change', () => {
  const saved=astronomy(),built=structuredClone(saved);
  built[0].result.mansions.positions[0].entryDegrees+=1e-8;
  assert.ok(compareFixtures(built,saved).length);
});
test('rejects changed membership, time, birth and missing fields', () => {
  for (const mutate of [
    f=>{f.result.mansions.positions[0].mansion='觜'},
    f=>{f.result.time.julianDayUT+=1e-6},
    f=>{f.request.birth.year++},
    f=>{delete f.result.sevenBodies.positions[0].body},
    f=>{f.result.sevenBodies.positions.push({body:'Moon',latitudeDegrees:1})},
  ]) { const saved=astronomy(),built=structuredClone(saved);mutate(built[0]);assert.ok(compareFixtures(built,saved).length); }
});
test('never tolerates numerical drift in other tools or arbitrary Degrees fields', () => {
  for(const command of ['profile','tool']) {
    const saved=[{request:{command,name:'get_domain'},result:{latitudeDegrees:1}}],built=structuredClone(saved);
    built[0].result.latitudeDegrees+=1e-12;assert.ok(compareFixtures(built,saved).length);
  }
  const saved=astronomy(),built=structuredClone(saved);
  saved[0].result.unrelatedDegrees=1;built[0].result.unrelatedDegrees=1+1e-12;
  assert.ok(compareFixtures(built,saved).length);
});
test('cached astronomy tool angles use the same bound; policy and identity remain exact', () => {
  const saved=astronomy();saved[0].request={command:'tool',name:'get_natal_astronomy',arguments:{body:'Moon'},astronomy:structuredClone(saved[0].result)};
  saved[0].result={result:saved[0].result,evidence:['Moon coordinates']};
  const built=structuredClone(saved);built[0].request.astronomy.sevenBodies.positions[0].latitudeDegrees+=1e-12;
  built[0].result.result.sevenBodies.positions[0].latitudeDegrees+=1e-12;
  assert.deepEqual(compareFixtures(built,saved),[]);
  built[0].request.arguments.body='all';assert.ok(compareFixtures(built,saved).length);
  built[0].request.arguments.body='Moon';built[0].result.evidence=['changed'];assert.ok(compareFixtures(built,saved).length);
});
test('fixture count, nonfinite values, null and type changes are errors', () => {
  const saved=astronomy();assert.ok(compareFixtures([],saved).length);
  for(const value of [null,'1',Infinity,NaN]) {const built=structuredClone(saved);built[0].result.sevenBodies.positions[0].latitudeDegrees=value;assert.ok(compareFixtures(built,saved).length);}
});
