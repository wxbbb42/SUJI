import { dispatch } from '../../../bridge';

const birth={year:1975,month:3,day:14,hour:0,minute:0,gender:'男',longitude:116.4,timeZoneID:'Asia/Shanghai'};
const natal=(b:any=birth)=>dispatch({command:'natal-astronomy',birth:b});

test('four residuals expose selected mean orbital definitions and the independent purple epoch',async()=>{
  const n=await natal();
  expect(n.fourResiduals).toMatchObject({moduleID:'four-residuals',methodVersion:'mean-lunar-moira-purple-v1',
    nodeConvention:'rahu-ascending-ketu-descending',positions:[
      {body:'Rahu',definition:'mean-ascending-node'}, {body:'Ketu',definition:'mean-descending-node'},
      {body:'Apogee',definition:'mean-lunar-apogee'}, {body:'PurpleQi',definition:'uniform-symbolic-point',longitudeDegrees:230.5},
    ]});
  expect(n.fourResiduals.positions[1].longitudeDegrees).toBeCloseTo((n.fourResiduals.positions[0].longitudeDegrees+180)%360,10);
  expect(n.unsupported).not.toContain('four-residuals');
});

test.each([[5,0,'卯',0],[6,59,'卯',0],[7,0,'辰',30],[11,0,'午',90],[17,0,'酉',180],[23,0,'子',270]])(
  'life degree uses the selected fixed-clock branch at %s:%s',async(hour,minute,branch,offset)=>{
  const n=await natal({...birth,hour,minute});
  expect(n.lifeDegree).toMatchObject({moduleID:'life-degree',methodVersion:'mao-hour-tropical-solar-degree-v1',birthHourBranch:branch,
    clockPolicy:'fixed-utc-plus-8-hour-branch-v1',mansionPolicy:'modern-equatorial-reference-not-historical-degree'});
  const sun=n.sevenBodies.positions[0].longitudeDegrees;
  expect(n.lifeDegree.longitudeDegrees).toBeCloseTo((sun+offset)%360,10);
  expect(n.lifeDegree.houses).toHaveLength(12);
  expect(n.lifeDegree.mansion.body).toBe('LifeDegree');
  expect(n.lifeDegree.mansion.entryDegrees).toBeGreaterThanOrEqual(0);
  expect(n.lifeDegree.mansion.entryDegrees).toBeLessThan(n.lifeDegree.mansion.widthDegrees);
});

test('new point projections read fixed snapshots and reject changed methods or unrelated model birth inputs',async()=>{
  const n=await natal();
  for(const body of ['Rahu','Ketu','Apogee','PurpleQi','LifeDegree']) {
    const r=await dispatch({command:'tool',name:'get_natal_astronomy',birth,astronomy:n,arguments:{body}});
    expect(body==='LifeDegree'?r.result.lifeDegree:r.result.fourResiduals.positions.find((p:any)=>p.body===body)).toBeTruthy();
    expect(r.result.time).toEqual(n.time);
  }
  for(const mutation of [
    {...n,fourResiduals:{...n.fourResiduals,nodeConvention:'rahu-descending'}},
    {...n,lifeDegree:{...n.lifeDegree,birthHourBranch:'卯'}},
    {...n,lifeDegree:{...n.lifeDegree,longitudeDegrees:0}},
  ]) await expect(dispatch({command:'tool',name:'get_natal_astronomy',birth,astronomy:mutation,arguments:{}})).rejects.toThrow(/失效/);
});

test('derived cache accepts only last-bit angle differences across runtimes, never identity or dates',async()=>{
  const n=await natal(),call=(astronomy:any)=>dispatch({command:'tool',name:'get_natal_astronomy',birth,astronomy,arguments:{}});
  const drift=JSON.parse(JSON.stringify(n));drift.lifeDegree.palaceDegree+=1e-12;drift.lifeDegree.rightAscensionDegrees+=1e-12;
  drift.fourResiduals.positions[2].longitudeDegrees+=1e-12;
  await expect(call(drift)).resolves.toBeTruthy();
  for(const mutate of [(x:any)=>x.lifeDegree.palaceDegree+=1e-7,(x:any)=>x.lifeDegree.mansion.index+=1e-12,
    (x:any)=>x.lifeDegree.hoursUntilBranchChange+=1e-12,(x:any)=>x.fourResiduals.purpleParameters.periodDays+=1e-9]) {
    const bad=JSON.parse(JSON.stringify(n));mutate(bad);await expect(call(bad)).rejects.toThrow(/失效/);
  }
});
