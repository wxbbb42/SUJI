import { HexagramEngine } from '../HexagramEngine';
import { getCalendarPillars } from '../../calendar/precision';

// Calendar input is isolated because classical cases specify pillars, not Gregorian dates.
// Actual casting, najia, hidden objects, line contexts and question reassessment remain real.
jest.mock('../../calendar/precision', () => ({ getCalendarPillars: jest.fn() }));
const clock = getCalendarPillars as jest.Mock;
const engine = new HexagramEngine();
const run = (values: number[]) => engine.cast({ question:'核对原文结构，不验证结果', questionType:'health',
  questionContext:{subject:'self',event:'结构核对',timeHorizon:'near'},
  castTime:new Date('2026-09-20T04:00:00Z'), lineValues:values as (6|7|8|9)[] }) as any;
const row = (reading:any, path:string) => reading.tombExtinction.objects.find((o:any) => o.objectPath === path);
beforeEach(() => clock.mockReturnValue({month:'壬申',day:'己卯',hour:'庚午'}));

// Independently literal 5 x 12 table. Column order: 子丑寅卯辰巳午未申酉戌亥.
// A wrong element/branch lookup, reversal or borrowed Bazi stem cycle must fail these.
const TABLE:Record<string,string[]> = {
  木:['neither','neither','neither','neither','neither','neither','neither','墓','绝','neither','neither','neither'],
  火:['neither','neither','neither','neither','neither','neither','neither','neither','neither','neither','墓','绝'],
  土:['neither','neither','neither','neither','墓','绝','neither','neither','neither','neither','neither','neither'],
  金:['neither','墓','绝','neither','neither','neither','neither','neither','neither','neither','neither','neither'],
  水:['neither','neither','neither','neither','墓','绝','neither','neither','neither','neither','neither','neither'],
};
for (const [column,branch] of [...'子丑寅卯辰巳午未申酉戌亥'].entries()) {
  test(`literal five-element table at ${branch} binds original and actual changed calendars independently`, () => {
    // Valid sexagenary parity; synthetic coordinates deliberately make no Gregorian inference.
    const ganZhi=(column%2===0?'甲':'乙')+branch;
    clock.mockReturnValue({month:ganZhi,day:ganZhi,hour:column%2===0?'庚午':'壬午'});
    const reading = run([9,9,9,9,9,9]);
    expect(reading.tombExtinction).toBeDefined();
    expect(reading.lines.map((l:any) => l.wuXing)).toEqual(['水','木','土','火','金','土']);
    expect(reading.lines.map((l:any) => l.changed.wuXing)).toEqual(['土','火','木','土','水','金']);
    const original = ['水','木','土','火','金','土'], changed = ['土','火','木','土','水','金'];
    for (let i=0;i<6;i++) {
      expect(row(reading,`/lines/${i}`)).toMatchObject({month:TABLE[original[i]][column],day:TABLE[original[i]][column]});
      expect(row(reading,`/lines/${i}/changed`)).toEqual({objectPath:`/lines/${i}/changed`,month:TABLE[changed[i]][column],day:TABLE[changed[i]][column],
        movingTombPositions:[],movingExtinctionPositions:[],supportingMovingPositions:[]});
    }
  });
}

test('static casts create only real objects and keep every empty actor array', () => {
  const reading = run([7,7,7,7,7,7]);
  expect(reading.tombExtinction).toBeDefined();
  expect(reading.tombExtinction.objects.map((o:any) => o.objectPath)).toEqual(['/lines/0','/lines/1','/lines/2','/lines/3','/lines/4','/lines/5']);
  for (const object of reading.tombExtinction.objects) expect(object).toEqual({objectPath:object.objectPath,
    month:object.objectPath==='/lines/1'?'绝':'neither',day:'neither',
    movingTombPositions:[],movingExtinctionPositions:[],supportingMovingPositions:[]});
});

test('own-change tomb/extinction stay directed at the moving original, never the changed target', () => {
  clock.mockReturnValue({month:'壬申',day:'乙巳',hour:'庚午'});
  const reading = run([6,7,9,8,7,7]);
  expect(reading.tombExtinction).toBeDefined();
  expect([reading.benGua.name,reading.bianGua.name]).toEqual(['巽为风','风泽中孚']);
  expect(row(reading,'/lines/0')).toEqual({objectPath:'/lines/0',month:'neither',day:'绝',ownChange:'绝',
    movingTombPositions:[],movingExtinctionPositions:[],supportingMovingPositions:[]});
  expect(row(reading,'/lines/2')).toEqual({objectPath:'/lines/2',month:'neither',day:'neither',ownChange:'墓',
    movingTombPositions:[1],movingExtinctionPositions:[],supportingMovingPositions:[1]});
  expect(row(reading,'/lines/2/changed')).toEqual({objectPath:'/lines/2/changed',month:'neither',day:'绝',
    movingTombPositions:[],movingExtinctionPositions:[],supportingMovingPositions:[]});
  expect(row(reading,'/lines/0/changed').day).toBe('neither');
  expect(row(reading,'/lines/2/changed')).not.toHaveProperty('ownChange');
  expect(row(reading,'/lines/2/changed')).not.toHaveProperty('flying');
});

test('hidden water binds its own flying tomb and calendar support, without importing a moving tomb actor', () => {
  const reading = run([8,8,7,7,7,7]);
  expect(reading.tombExtinction).toBeDefined();
  expect(reading.benGua.name).toBe('天山遯');
  expect(reading.lines[0].ganZhi).toBe('丙辰');
  expect(reading.lines[0].hidden.ganZhi).toBe('甲子');
  expect(reading.tombExtinction.objects.map((o:any) => o.objectPath)).toEqual([
    '/lines/0','/lines/0/hidden','/lines/1','/lines/1/hidden','/lines/2','/lines/3','/lines/4','/lines/5']);
  expect(row(reading,'/lines/0/hidden')).toEqual({objectPath:'/lines/0/hidden',month:'neither',day:'neither',flying:'墓',
    movingTombPositions:[],movingExtinctionPositions:[],supportingMovingPositions:[]});
  expect(reading.lines[0].hidden.context.month.elementRelation).toBe('生爻');
  expect(row(reading,'/lines/0')).not.toHaveProperty('flying');
  expect(row(reading,'/lines/1/hidden').month).toBe('绝');
});

test('hidden support excludes its own moving flying object but keeps other original actors', () => {
  const reading = run([8,9,7,7,9,7]); // 姤: 2飞亥水生伏寅木, 5动申金; flying support remains separately scoped.
  expect(reading.tombExtinction).toBeDefined();
  expect(reading.benGua.name).toBe('天风姤');
  expect(reading.lines[1].hidden.ganZhi).toBe('甲寅');
  expect(row(reading,'/lines/1/hidden')).toEqual({objectPath:'/lines/1/hidden',month:'绝',day:'neither',flying:'neither',
    movingTombPositions:[],movingExtinctionPositions:[],supportingMovingPositions:[]});
  expect(row(reading,'/lines/1').supportingMovingPositions).toEqual([5]);
  expect(row(reading,'/lines/1').movingExtinctionPositions).toEqual([]);
  const supported=run([8,8,9,7,9,7]); // 遯伏子水 receives both independently moving 申金 originals.
  expect(row(supported,'/lines/0/hidden').supportingMovingPositions).toEqual([3,5]);
  expect(row(supported,'/lines/0/hidden').movingTombPositions).toEqual([]);
  expect(row(supported,'/lines/0/hidden').movingExtinctionPositions).toEqual([]);
});

test('moving support distinguishes generation and same-element from control, draining and self support', () => {
  const reading=run([9,9,9,9,9,9]); // 乾 bottom-up 水木土火金土: independent five-element calculation.
  expect(reading.tombExtinction).toBeDefined();
  expect(reading.lines.map((l:any)=>l.wuXing)).toEqual(['水','木','土','火','金','土']);
  expect(['/lines/0','/lines/1','/lines/2','/lines/3','/lines/4','/lines/5'].map(path=>row(reading,path).supportingMovingPositions))
    .toEqual([[5],[1],[4,6],[2],[3,6],[3,4]]);
});

test('ch30 戌月甲寅 literal 小过→艮 preserves month, moving and own-change tombs without efficacy', () => {
  clock.mockReturnValue({month:'甲戌',day:'甲寅',hour:'庚午'});
  const reading = run([8,8,7,9,8,6]);
  expect(reading.tombExtinction).toBeDefined();
  expect([reading.benGua.name,reading.bianGua.name]).toEqual(['雷山小过','艮为山']);
  expect(reading.lines.map((l:any) => l.ganZhi[1])).toEqual(['辰','午','申','午','申','戌']);
  expect(reading.changingYao).toEqual([4,6]);
  expect(reading.lines[3].changed.ganZhi[1]).toBe('戌');
  expect(reading.lines[5].changed.ganZhi[1]).toBe('寅');
  expect(row(reading,'/lines/3')).toEqual({objectPath:'/lines/3',month:'墓',day:'neither',ownChange:'墓',
    movingTombPositions:[6],movingExtinctionPositions:[],supportingMovingPositions:[]});
  expect(reading.lines[3].context.day.elementRelation).toBe('生爻');
  expect(reading.tombExtinction.efficacyEstablished).toBe(false);
});

test('ch30 未月戊辰 literal 蛊→损 retains a broken tomb source and support rather than declaring release', () => {
  clock.mockReturnValue({month:'癸未',day:'戊辰',hour:'庚午'});
  const reading = run([6,7,9,8,8,7]);
  expect(reading.tombExtinction).toBeDefined();
  expect([reading.benGua.name,reading.bianGua.name]).toEqual(['山风蛊','山泽损']);
  expect(reading.lines.map((l:any) => l.ganZhi[1])).toEqual(['丑','亥','酉','戌','子','寅']);
  expect(reading.changingYao).toEqual([1,3]);
  expect(row(reading,'/lines/2')).toEqual({objectPath:'/lines/2',month:'neither',day:'neither',ownChange:'墓',
    movingTombPositions:[1],movingExtinctionPositions:[],supportingMovingPositions:[1]});
  expect(reading.lines[0].context.month.clash).toBe(true);
  expect(reading.lines[2].context.month.elementRelation).toBe('生爻');
  expect(reading.lines[2].context.day.elementRelation).toBe('生爻');
  expect(reading.tombExtinction.efficacyEstablished).toBe(false);
});

test('support and adverse calendar context coexist at the same tomb without automatic rescue', () => {
  clock.mockReturnValue({month:'乙巳',day:'丙午',hour:'庚午'});
  const reading = run([6,7,9,8,8,7]);
  expect(reading.tombExtinction).toBeDefined();
  expect(row(reading,'/lines/2')).toMatchObject({ownChange:'墓',movingTombPositions:[1],supportingMovingPositions:[1]});
  expect(reading.lines[2].context.month.elementRelation).toBe('克爻');
  expect(reading.lines[2].context.day.elementRelation).toBe('克爻');
  expect(reading.tombExtinction).toMatchObject({assessmentStatus:'conditional-structure',efficacyEstablished:false,
    sourceId:'liuyao-tomb-extinction-v1',unresolved:['selected-object','target-strength','actor-effectiveness','event-outcome']});
});

test('a static 丑 does not become a moving tomb and original extinction actors are never their own targets', () => {
  clock.mockReturnValue({month:'壬申',day:'己丑',hour:'庚午'});
  const reading = run([8,7,7,7,8,8]);
  expect(reading.tombExtinction).toBeDefined();
  expect(reading.benGua.name).toBe('雷风恒');
  expect(row(reading,'/lines/2')).toMatchObject({day:'墓',movingTombPositions:[]});
  const moving = run([7,9,7,7,9,7]); // 乾: 寅 at2 is metal絶; 申 at5 is wood絶.
  expect(row(moving,'/lines/1')).toMatchObject({movingExtinctionPositions:[5],supportingMovingPositions:[]});
  expect(row(moving,'/lines/4')).toMatchObject({movingExtinctionPositions:[2],supportingMovingPositions:[]});
  for (const object of moving.tombExtinction.objects) {
    const position=Number(object.objectPath.split('/')[2])+1;
    expect(object.movingTombPositions).not.toContain(position);
    expect(object.movingExtinctionPositions).not.toContain(position);
    expect(object.supportingMovingPositions).not.toContain(position);
  }
});

test('every structural pointer resolves its exact object and reassessment preserves the original layer', () => {
  const original=run([6,6,9,9,9,6]), saved=JSON.stringify(original);
  expect(original.tombExtinction).toBeDefined();
  const paths:string[]=[];
  original.lines.forEach((line:any,i:number) => {
    paths.push(`/lines/${i}`);
    if(line.changed)paths.push(`/lines/${i}/changed`);
    if(line.hidden)paths.push(`/lines/${i}/hidden`);
  });
  expect(original.tombExtinction.objects.map((o:any)=>o.objectPath)).toEqual(paths);
  for(const object of original.tombExtinction.objects) {
    const target=object.objectPath.split('/').slice(1).reduce((value:any,key:string)=>value[key],original);
    expect(target.ganZhi).toMatch(/^.{2}$/u);
  }
  const revised=engine.reassessQuestion(original,{question:'改问父母的情况',questionType:'parents',questionContext:{subject:'parent',event:'结构核对',timeHorizon:'far'}}) as any;
  expect(revised.tombExtinction).toEqual(original.tombExtinction);
  expect(revised.tombExtinction).toBe(original.tombExtinction);
  expect(JSON.stringify(original)).toBe(saved);
  const source=original.ruleSources.find((s:any)=>s.id===original.tombExtinction.sourceId);
  expect(source).toMatchObject({version:'1',editionStatus:'electronic-transcription-not-print-collated'});
  expect(source.references).toEqual(expect.arrayContaining([
    expect.objectContaining({url:'https://zh.wikisource.org/wiki/增刪卜易/26又1',sha256:'630f38b037ae720e90e55faff10a1c044f7edf9e3a85ce7dc645b8693ada2008'}),
    expect.objectContaining({url:'https://zh.wikisource.org/wiki/易林補遺/1',sha256:'abf77e78f3fbf77e33c2520e2a3525898894e5f5b0863fb5fa2c44619daab967'}),
  ]));
});
