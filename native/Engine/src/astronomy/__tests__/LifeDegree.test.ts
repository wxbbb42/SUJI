import {maoLifeGeometry} from '../lifeDegree';

test('source example Sun Zi and You hour gives Wu, preserving modern intra-sign degree',()=>{
  expect(maoLifeGeometry(306,17,0)).toMatchObject({sunPalaceBranch:'子',birthHourBranch:'酉',palaceBranch:'午',palaceDegree:6,longitudeDegrees:126,palaceRuler:'Sun'});
  expect(maoLifeGeometry(246,5,0).houses.slice(0,4).map(x=>[x.name,x.branch])).toEqual([['命宫','寅'],['财帛','丑'],['兄弟','子'],['田宅','亥']]);
});
test('independent branch counting agrees for all 144 solar-palace/hour pairs',()=>{
  const branches=[...'子丑寅卯辰巳午未申酉戌亥'],zodiac=[...'戌酉申未午巳辰卯寅丑子亥'];
  for(let sun=0;sun<12;sun++)for(let hour=0;hour<12;hour++) {
    // Classical branch algorithm: put birth hour on Sun palace, advance both until Mao.
    let palace=branches.indexOf(zodiac[sun]),clock=hour;
    while(clock!==3){palace=(palace+1)%12;clock=(clock+1)%12;}
    const r=maoLifeGeometry(sun*30+7.25,hour*2,0);
    expect(r.palaceBranch).toBe(branches[palace]);
    expect(r.palaceDegree).toBe(7.25);
    expect(new Set(r.houses.map(x=>x.branch)).size).toBe(12);
    expect(r.houses.map(x=>x.branch)).toEqual(Array.from({length:12},(_,i)=>branches[(palace-i+12)%12]));
  }
});
test.each([[0,23,0,270],[359.9,7,0,29.9],[0,4,59,330],[0,5,0,0],[0,6,59,0],[0,7,0,30],[0,22,59,240],[0,23,0,270]])(
  'wrap and clock boundaries %s %s:%s', (sun,hour,minute,expected)=>expect(maoLifeGeometry(sun,hour,minute).longitudeDegrees).toBeCloseTo(expected,9));
test('invalid angles and clock parts are rejected',()=>{
  for(const x of [-1,360,NaN,Infinity])expect(()=>maoLifeGeometry(x,5,0)).toThrow();
  for(const [h,m] of [[24,0],[-1,0],[5.1,0],[5,60],[5,-1],[5,NaN]])expect(()=>maoLifeGeometry(0,h,m)).toThrow();
});
