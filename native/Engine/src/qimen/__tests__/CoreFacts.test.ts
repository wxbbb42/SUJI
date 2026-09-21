import { QimenEngine } from '../QimenEngine';
import { hourHorse, hourVoid, qimenFacts } from '../facts';
import type { Palace, WuXing, JiuxingName, BamenName } from '../types';

const setup=(date:string):any=>new QimenEngine().setup({setupTime:new Date(date),longitude:116.4,question:'手排复核',questionType:'general'});

test.each([
  ['2024-02-04T04:00:00Z','甲寅',['子','丑'],[1,8],'申',2,[]],
  ['2026-09-19T04:00:00Z','甲午',['辰','巳'],[4],'申',2,[]],
  ['2026-01-01T00:00:00Z','甲戌',['申','酉'],[2,7],'寅',8,[]],
  ['2026-06-21T10:00:00Z','甲午',['辰','巳'],[4],'亥',6,[1,2,3,6]],
])('independent hand chart %s: hour void, horse and door pressure', (date,xun,branches,palaces,horse,horsePalace,pressure) => {
  const r=setup(date as string);
  expect(r.hourVoid).toMatchObject({scope:'hour',ganZhi:r.hourGanZhi,xun,branches});
  expect(r.hourVoid?.palaces?.map((p:any)=>p.palaceId)).toEqual(palaces);
  expect(r.horse).toMatchObject({scope:'hour',ganZhi:r.hourGanZhi,branch:horse,palaceId:horsePalace});
  expect(r.palaces.filter((p:any)=>p.doorRelation?.isPressure).map((p:any)=>p.id)).toEqual(pressure);
});

test('void keeps actual branches and partial/full palace coverage', () => {
  expect(setup('2026-01-01T00:00:00Z').hourVoid?.palaces).toEqual([
    {palaceId:2,branches:['申'],palaceBranches:['未','申'],coverage:'partial'},
    {palaceId:7,branches:['酉'],palaceBranches:['酉'],coverage:'full'},
  ]);
  expect(setup('2026-09-19T04:00:00Z').hourVoid?.palaces).toEqual([
    {palaceId:4,branches:['辰','巳'],palaceBranches:['辰','巳'],coverage:'full'},
  ]);
});

test('palace controls door is not door pressure and center has no door facts', () => {
  const r=setup('2026-06-21T10:00:00Z');
  expect(r.palaces[5].doorRelation).toMatchObject({door:'景门',doorElement:'火',palaceElement:'金',relation:'门克宫',isPressure:true});
  expect(r.palaces[8].doorRelation).toMatchObject({door:'生门',relation:'宫生门',isPressure:false});
  expect(r.palaces[4].doorRelation).toBeUndefined();
  expect(r.ruleSources).toEqual(expect.arrayContaining([expect.objectContaining({id:'qimen-door-controls-palace-v1'})]));
});

test('star season uses the star-month table, includes hosted Tianqin once, and differs from stem-palace state', () => {
  const r=setup('2026-09-19T04:00:00Z');
  expect(r.monthGanZhi).toBe('丁酉');
  expect(r.palaces[1].starSeason).toMatchObject({star:'天芮',element:'土',monthBranch:'酉',monthElement:'金',state:'旺',scope:'solar-term-month'});
  expect(r.palaces[1].hostedStarSeason).toMatchObject({star:'天禽',state:'旺'});
  expect(r.palaces[4].starSeason).toBeUndefined();
  expect(r.yongShen.state).toBe('休');
});

test('60 hour pillars agree with the fixed six-xun and four horse tables', () => {
  const stems=[...'甲乙丙丁戊己庚辛壬癸'],branches=[...'子丑寅卯辰巳午未申酉戌亥'];
  const voids=['戌亥','申酉','午未','辰巳','寅卯','子丑'];
  const horses:Record<string,[string,number]>={申:['寅',8],子:['寅',8],辰:['寅',8],寅:['申',2],午:['申',2],戌:['申',2],巳:['亥',6],酉:['亥',6],丑:['亥',6],亥:['巳',4],卯:['巳',4],未:['巳',4]};
  for(let n=0;n<60;n++) {
    const gz=stems[n%10]+branches[n%12];
    expect(hourVoid(gz).branches).toEqual([...voids[Math.floor(n/10)]]);
    expect(hourHorse(gz)).toMatchObject({scope:'hour',branch:horses[gz[1]][0],palaceId:horses[gz[1]][1]});
  }
});

test('all 25 star/month and door/palace element pairs use separate independently tabulated relations', () => {
  const elements:WuXing[]=['木','火','土','金','水'];
  const stars:JiuxingName[]=['天辅','天英','天芮','天心','天蓬'];
  const doors:BamenName[]=['杜门','景门','死门','开门','休门'];
  const months=['甲寅','丙午','戊辰','庚申','壬子'];
  const expectedStar=[['相','旺','休','囚','废'],['废','相','旺','休','囚'],['囚','废','相','旺','休'],['休','囚','废','相','旺'],['旺','休','囚','废','相']];
  const expectedDoor=[
    ['比和','门生宫','门克宫','宫克门','宫生门'],['宫生门','比和','门生宫','门克宫','宫克门'],
    ['宫克门','宫生门','比和','门生宫','门克宫'],['门克宫','宫克门','宫生门','比和','门生宫'],['门生宫','门克宫','宫克门','宫生门','比和'],
  ];
  for(let row=0;row<5;row++) for(let col=0;col<5;col++) {
    // A controlled element matrix, not a real rotated chart.
    const p:Palace={id:1,name:'受控宫',position:'受控',wuXing:elements[col],diPanGan:null,tianPanGan:null,bamen:doors[row],jiuxing:stars[row],bashen:null};
    const r=qimenFacts('甲子',months[col],[p]).palaces[0];
    expect(r.starSeason?.state).toBe(expectedStar[row][col]);
    expect(r.doorRelation?.relation).toBe(expectedDoor[row][col]);
    expect(r.doorRelation?.isPressure).toBe(expectedDoor[row][col]==='门克宫');
  }
});

test('solar clock projection across Lichun cannot change the physical solar-term month', () => {
  const engine=new QimenEngine();
  // 16:27 Beijing is just after Lichun; 87.6° apparent clock is hours earlier.
  for(const longitude of [undefined,87.6,121.5]) {
    const chart:any=engine.setup({setupTime:new Date('2026-02-04T08:27:00Z'),longitude,question:'月令钟域',questionType:'general'});
    expect(chart.monthGanZhi).toBe('庚寅');
    expect(chart.palaces.filter((p:any)=>p.starSeason).every((p:any)=>p.starSeason.monthBranch==='寅')).toBe(true);
  }
});
