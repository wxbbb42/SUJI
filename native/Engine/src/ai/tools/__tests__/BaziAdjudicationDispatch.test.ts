import { dispatch } from '../../../../bridge';

const now='2026-09-21T04:00:00Z';
const earthBirth={year:1980,month:1,day:26,hour:7,minute:30,gender:'男',longitude:120,timeZoneID:'Asia/Shanghai'};
const regularBirth={year:1993,month:6,day:8,hour:13,minute:30,gender:'男',longitude:120,timeZoneID:'Asia/Shanghai'};
const json=(value:unknown)=>JSON.parse(JSON.stringify(value));
const domain=(birth:unknown,extra={})=>dispatch({command:'tool',name:'get_domain',arguments:{domain:'事业'},birth,now,...extra});

describe('Bazi adjudication through actual get_domain dispatch',()=>{
  test('returns earth formation and the original civil Jie elapsed context',async()=>{
    const result=json(await domain(earthBirth));
    expect(result.result.bazi.birthDateTime).toBe('1980-01-25T23:30:00.000Z');
    const pattern=result.result.bazi.patternAnalysis;
    expect(pattern).toMatchObject({name:'稼穑格',category:'zhuanwang',assessmentStatus:'heuristic-candidate',specialPatternEvidence:{
      status:'established',outcomeEstablished:false,season:{commander:{gan:'己',element:'土'},birthMonthContext:{
        civilBirthTime:'1980-01-25T23:30:00.000Z',monthBranch:'丑',jie:{name:'小寒'},nextJie:{name:'立春'},
        timeBasis:'civil-instant-utc',solarTimeApplied:false}}}});
    expect(pattern.specialPatternEvidence.season.birthMonthContext.daysAfterJie).toBeGreaterThan(12);
  });

  test('returns positional rescue limits with same-element roots and preserves the unrescued duplicate',async()=>{
    const pattern=json(await domain(regularBirth)).result.bazi.patternAnalysis;
    expect(pattern.rescueEvidence).toMatchObject({methodVersion:'bazi-rescue-adjudication-v1',globalResolution:'unresolved',outcomeEstablished:false});
    expect(pattern.rescueEvidence.combinations).toContainEqual(expect.objectContaining({actorPosition:1,targetPosition:0,targetGan:'癸',status:'rooted-role-retained',removalEstablished:false}));
    expect(pattern.rescueEvidence.combinations).toContainEqual(expect.objectContaining({actorPosition:1,targetPosition:3,targetGan:'癸',status:'rooted-role-retained',removalEstablished:false}));
    expect(pattern.chengBai).toBe('po');
    expect(pattern.specialPatternEvidence.status).toBe('not-established-in-selected-profile');
  });

  test.each([earthBirth,regularBirth])('preserves adjudication through durable natal and profile paths: %j',async birth=>{
    const natal=json(await dispatch({command:'natal',birth}));
    const saved=JSON.stringify(natal);
    const result=json(await domain(birth,{natal}));
    const profile=json(await dispatch({command:'profile',birth,natal,now}));
    expect(result.result.bazi.patternAnalysis).toEqual(natal.mingPan.geJuV2);
    expect(profile.mingPan.geJuV2).toEqual(natal.mingPan.geJuV2);
    expect(JSON.stringify(natal)).toBe(saved);
  });
});
