import { ALL_GE_JU, detectGeJu } from '../data/geju';
import type { QimenChart, Palace } from '../types';

// ────────────────────────────────────────────────────────
// 工具：构造一个 mock chart 用于测试特定格局
// ────────────────────────────────────────────────────────

function makeChart(palaceOverrides: Array<Partial<Palace>>): QimenChart {
  const palaces: Palace[] = [];
  const baseInfo: Array<Pick<Palace, 'id' | 'name' | 'position' | 'wuXing'>> = [
    { id: 1, name: '坎宫', position: '北',   wuXing: '水' },
    { id: 2, name: '坤宫', position: '西南', wuXing: '土' },
    { id: 3, name: '震宫', position: '东',   wuXing: '木' },
    { id: 4, name: '巽宫', position: '东南', wuXing: '木' },
    { id: 5, name: '中宫', position: '中',   wuXing: '土' },
    { id: 6, name: '乾宫', position: '西北', wuXing: '金' },
    { id: 7, name: '兑宫', position: '西',   wuXing: '金' },
    { id: 8, name: '艮宫', position: '东北', wuXing: '土' },
    { id: 9, name: '离宫', position: '南',   wuXing: '火' },
  ];
  for (let i = 0; i < 9; i++) {
    palaces.push({
      ...baseInfo[i],
      diPanGan: null,
      tianPanGan: null,
      bamen: null,
      jiuxing: null,
      bashen: null,
      ...(palaceOverrides[i] ?? {}),
    });
  }
  return {
    question: '',
    questionType: 'general',
    setupTime: '',
    calculationTime: '',
    trueSolarTime: '',
    jieqi: '冬至',
    yinYangDun: '阳',
    juNumber: 1,
    yuan: '上',
    palaces,
    yongShen: { type: '', palaceId: 1, state: '相', summary: '', interactions: [] },
    geJu: [],
    yingQi: { description: '', factors: [] },
    method: { level: 'mvp', caveats: [] },
  };
}

// Expected facts below come from explicit classical pairings and full plate
// fixtures, not the implementation's old count thresholds or matching tables.
import { QimenEngine } from '../QimenEngine';
import type { TianGan, BamenName, JiuxingName } from '../types';

function names(chart: QimenChart): string[] { return detectGeJu(chart).map(item => item.name); }
function one(id: number, data: Partial<Palace>, metadata: Partial<QimenChart> = {}): QimenChart {
  const overrides: Array<Partial<Palace>> = Array.from({length:9},()=>({}));
  overrides[id-1]=data;
  return {...makeChart(overrides),...metadata};
}

describe('Reviewed rule scope', () => {
  it('has unique documented rules without unsupported MVP names or event guarantees', () => {
    expect(new Set(ALL_GE_JU.map(rule=>rule.name)).size).toBe(ALL_GE_JU.length);
    for(const old of ['玄武当权','神遁','鬼遁','风遁','云遁','龙遁','虎遁','岁月日时格','玉女守门','丙奇受制']) {
      expect(ALL_GE_JU.map(rule=>rule.name)).not.toContain(old);
    }
    expect(ALL_GE_JU.map(rule=>rule.description).join()).not.toMatch(/求事必成|诸事顺|破财得病|事易成/);
    expect(detectGeJu(makeChart([]))).toEqual([]);
  });
});

describe('Full stars and doors, never a stem-count proxy', () => {
  const homeStars: Array<JiuxingName> = ['天蓬','天芮','天冲','天辅','天禽','天心','天柱','天任','天英'];
  const reversedStars: Array<JiuxingName> = ['天英','天任','天柱','天心','天禽','天辅','天冲','天芮','天蓬'];
  const homeDoors: Array<BamenName|null> = ['休门','死门','伤门','杜门',null,'开门','惊门','生门','景门'];
  const reversedDoors: Array<BamenName|null> = ['景门','生门','惊门','开门',null,'杜门','伤门','死门','休门'];
  it('distinguishes star and door repetition independently', () => {
    const chart=makeChart(homeStars.map((jiuxing,i)=>({jiuxing,bamen:reversedDoors[i]})));
    expect(names(chart)).toContain('伏吟');
    expect(names(chart)).toContain('八门反吟');
    expect(names(chart)).not.toContain('反吟');
    expect(names(chart)).not.toContain('八门伏吟');
  });
  it('recognizes opposite star palaces and doors at home', () => {
    const chart=makeChart(reversedStars.map((jiuxing,i)=>({jiuxing,bamen:homeDoors[i]})));
    expect(names(chart)).toContain('反吟');
    expect(names(chart)).toContain('八门伏吟');
    expect(names(chart)).not.toContain('伏吟');
  });
  it('rejects a partial plate and both old arbitrary three-stem conditions', () => {
    expect(names(makeChart([{diPanGan:'甲',tianPanGan:'甲'},{diPanGan:'乙',tianPanGan:'乙'},{diPanGan:'丙',tianPanGan:'丙'}]))).not.toContain('伏吟');
    expect(names(makeChart([{diPanGan:'甲',tianPanGan:'庚'},{diPanGan:'乙',tianPanGan:'辛'},{diPanGan:'丙',tianPanGan:'壬'}]))).not.toContain('反吟');
    const chart=makeChart(homeStars.map(jiuxing=>({jiuxing})));
    chart.palaces[0].jiuxing=null;
    expect(names(chart)).not.toContain('伏吟');
  });
});

describe('Six instruments and tombs use the moving sky plate', () => {
  test.each([['戊',3],['己',2],['庚',8],['辛',9],['壬',4],['癸',4]] as const)('%s punishment requires sky placement in palace %s', (gan,id)=>{
    expect(names(one(id,{tianPanGan:gan}))).toContain(`${gan}击刑`);
    expect(names(one(id,{diPanGan:gan,tianPanGan:'乙'}))).not.toContain(`${gan}击刑`);
    expect(names(one(1,{tianPanGan:gan}))).not.toContain(`${gan}击刑`);
  });
  test.each([['乙',6],['丙',6],['丁',8],['戊',6],['己',8],['庚',8],['辛',4],['壬',4],['癸',2]] as const)('%s tomb is palace %s in the selected Qimen table', (gan,id)=>{
    expect(names(one(id,{tianPanGan:gan}))).toContain('入墓');
    expect(names(one(id,{diPanGan:gan}))).not.toContain('入墓');
  });
  it('does not put Yi in Kun tomb and accounts for hosted sky stems', ()=>{
    expect(names(one(2,{tianPanGan:'乙'}))).not.toContain('乙奇入墓');
    expect(names(one(6,{tianPanGan:'乙'}))).toContain('乙奇入墓');
    expect(names(one(4,{tianPanGan:'乙',hostedTianPanGan:'壬'}))).toContain('壬击刑');
    expect(names(one(5,{tianPanGan:'庚',diPanGan:'丙'}))).not.toContain('太白入荧');
  });
  it('does not reproduce the round4 false Wu punishment', ()=>{
    const chart=new QimenEngine().setup({setupTime:new Date('2024-02-04T04:00:00Z'),question:'项目',questionType:'general'});
    expect(chart.palaces.find(p=>p.id===3)?.diPanGan).toBe('戊');
    expect(chart.palaces.find(p=>p.id===3)?.tianPanGan).toBe('癸');
    expect(names(chart)).not.toContain('戊击刑');
  });
  it('attributes the full tomb table separately from the poem about the three Qi', ()=>{
    const rules=detectGeJu(one(6,{tianPanGan:'乙'}));
    expect(rules.find(rule=>rule.name==='入墓')?.source).toEqual(expect.objectContaining({
      title:'qimen-go QMTomb（所选奇门墓库表）',
      editionStatus:'selected-implementation-table-not-classical-edition',
    }));
    expect(rules.find(rule=>rule.name==='乙奇入墓')?.source?.title).toBe('烟波钓叟歌（在线转录）');
  });
});

describe('Chief door is one actual door', ()=>{
  it('marks only the real chief palace, not every good door', ()=>{
    const chart=makeChart([{bamen:'开门'},{},{bamen:'生门'},{},{},{},{},{bamen:'休门'}]);
    chart.zhiShiMen='生门';chart.zhiShiPalaceId=3;
    expect(detectGeJu(chart).find(item=>item.name==='值使为三吉门')?.palaceIds).toEqual([3]);
    chart.zhiShiMen='伤门';chart.zhiShiPalaceId=4;chart.palaces[3].bamen='伤门';
    expect(names(chart)).not.toContain('值使为三吉门');
  });
  it('only reports real chief-door contact with earth Ding', ()=>{
    expect(names(one(1,{diPanGan:'丁',bamen:'休门'},{zhiShiMen:'休门',zhiShiPalaceId:1}))).toContain('值使临地盘丁');
    expect(names(one(1,{tianPanGan:'丁',bamen:'生门'},{zhiShiMen:'生门',zhiShiPalaceId:1}))).not.toContain('值使临地盘丁');
    expect(names(one(1,{diPanGan:'丁',bamen:'生门'},{zhiShiMen:'休门',zhiShiPalaceId:8}))).not.toContain('值使临地盘丁');
  });
});

describe('Specific Qi/instrument pairs rather than all Qi over Wu', ()=>{
  test.each([['乙','己'],['乙','辛'],['丙','戊'],['丙','庚'],['丁','壬'],['丁','癸']] as const)('%s over %s is a poem pairing', (qi,instrument)=>{
    expect(names(one(1,{tianPanGan:qi,diPanGan:instrument}))).toContain(`${qi}奇得使`);
    expect(names(one(1,{tianPanGan:instrument,diPanGan:qi}))).not.toContain(`${qi}奇得使`);
  });
  it('rejects Yi/Wu and Ding/Wu and does not say Geng metal controls fire', ()=>{
    expect(names(one(1,{tianPanGan:'乙',diPanGan:'戊'}))).not.toContain('乙奇得使');
    expect(names(one(1,{tianPanGan:'丁',diPanGan:'戊'}))).not.toContain('丁奇得使');
    const fact=detectGeJu(one(1,{tianPanGan:'丙',diPanGan:'庚'})).find(item=>item.name==='丙与庚叠盘');
    expect(fact?.assessmentStatus).toBe('structural-fact-only');
  });
  it('includes the center earth stem only under explicit fixed-Kun hosting', ()=>{
    const chart=makeChart([{}, {tianPanGan:'丙',diPanGan:'壬'}, {}, {}, {diPanGan:'戊'}]);
    expect(names(chart)).not.toContain('飞鸟跌穴');
    chart.method.centerPolicy='fixed-kun-2; tian-qin-follows-tian-rui';
    expect(detectGeJu(chart).find(item=>item.name==='飞鸟跌穴')?.palaceIds).toEqual([2]);
  });
  it('reports the old ascension positions literally without claiming an established home', ()=>{
    const fact=detectGeJu(one(3,{tianPanGan:'乙'})).find(item=>item.name==='乙奇临震三');
    expect(fact?.assessmentStatus).toBe('structural-fact-only');
    expect(fact?.source).toBeUndefined();
    expect(names(one(3,{tianPanGan:'乙'}))).not.toContain('乙奇升殿');
  });
});

describe('Three escapes preserve heaven/earth roles', ()=>{
  it('Heaven requires Bing over Ding and Life door, not Nine Heaven', ()=>{
    expect(names(one(1,{tianPanGan:'丙',diPanGan:'丁',bamen:'生门'}))).toContain('天遁');
    expect(names(one(1,{tianPanGan:'丙',diPanGan:'戊',bamen:'生门',bashen:'九天'}))).not.toContain('天遁');
    expect(names(one(1,{tianPanGan:'丁',diPanGan:'丙',bamen:'生门'}))).not.toContain('天遁');
  });
  it('Earth requires Yi over Ji and Open door, not Nine Earth', ()=>{
    expect(names(one(1,{tianPanGan:'乙',diPanGan:'己',bamen:'开门'}))).toContain('地遁');
    expect(names(one(1,{tianPanGan:'乙',diPanGan:'戊',bamen:'开门',bashen:'九地'}))).not.toContain('地遁');
  });
  it('Human requires sky Ding, Rest door and Taiyin', ()=>{
    expect(names(one(1,{tianPanGan:'丁',bamen:'休门',bashen:'太阴'}))).toContain('人遁');
    expect(names(one(1,{diPanGan:'丁',bamen:'休门',bashen:'太阴'}))).not.toContain('人遁');
  });
});

describe('Actual day/hour conditions', ()=>{
  test.each([['甲子','庚午'],['乙丑','辛巳'],['丙寅','壬辰'],['丁卯','癸卯'],['戊辰','甲寅'],['己巳','乙丑'],['庚午','丙子'],['辛未','丁酉'],['壬申','戊申'],['癸酉','己未']])('%s / %s meets same-polarity hour control', (dayGanZhi,hourGanZhi)=>{
    expect(names({...makeChart([]),dayGanZhi,hourGanZhi})).toContain('五不遇时');
  });
  it('does not substitute a sky Geng chief or opposite polarity', ()=>{
    expect(names(one(1,{tianPanGan:'庚',bashen:'值符'}))).not.toContain('五不遇时');
    expect(names({...makeChart([]),dayGanZhi:'甲子',hourGanZhi:'辛未'})).not.toContain('五不遇时');
  });
  it('names flying/hidden stems correctly and uses the actual day stem', ()=>{
    expect(names(one(1,{tianPanGan:'庚',diPanGan:'乙'},{dayGanZhi:'乙丑'}))).toContain('伏干格');
    expect(names(one(1,{tianPanGan:'庚',diPanGan:'乙'},{dayGanZhi:'乙丑'}))).not.toContain('飞干格');
    expect(names(one(1,{tianPanGan:'乙',diPanGan:'庚'},{dayGanZhi:'乙丑'}))).toContain('飞干格');
    expect(names(one(1,{tianPanGan:'庚',diPanGan:'乙'},{dayGanZhi:'壬子'}))).not.toContain('伏干格');
    expect(names(one(1,{tianPanGan:'庚',diPanGan:'辛'},{dayGanZhi:'甲午'}))).toContain('伏干格');
    expect(names(one(1,{tianPanGan:'庚',diPanGan:'辛'},{dayGanZhi:'甲子'}))).not.toContain('伏干格');
  });
  it('uses the actual hour carrier and rejects impossible sexagenary pairs', ()=>{
    expect(names(one(1,{tianPanGan:'庚',diPanGan:'辛'},{hourGanZhi:'甲午'}))).toContain('庚加时干');
    expect(names(one(1,{tianPanGan:'庚',diPanGan:'辛'},{hourGanZhi:'甲子'}))).not.toContain('庚加时干');
    const invalid=one(1,{tianPanGan:'庚',diPanGan:'戊'},{dayGanZhi:'甲丑',hourGanZhi:'甲丑'});
    expect(names(invalid)).not.toContain('伏干格');
    expect(names(invalid)).not.toContain('庚加时干');
    expect(names(invalid)).not.toContain('五不遇时');
  });
  it('keeps a global time condition without fabricating a palace', ()=>{
    const result=detectGeJu({...makeChart([]),dayGanZhi:'甲子',hourGanZhi:'庚午'}).find(rule=>rule.name==='五不遇时');
    expect(result).toBeDefined();
    expect(result?.palaceIds).toBeUndefined();
    expect(result?.assessmentStatus).toBe('traditional-condition-only');
  });
});

describe('Named directional pairs', ()=>{
  test.each([
    ['飞鸟跌穴','丙','戊'],['青龙返首','戊','丙'],['大格','庚','癸'],['上格','庚','壬'],['刑格','庚','己'],
    ['太白入荧','庚','丙'],['荧入太白','丙','庚'],['朱雀投江','丁','癸'],['青龙逃走','乙','辛'],['白虎猖狂','辛','乙'],
  ] as const)('%s preserves its top/bottom order', (name,above,below)=>{
    const match=detectGeJu(one(1,{tianPanGan:above,diPanGan:below})).find(item=>item.name===name);
    expect(match?.assessmentStatus).toBe('traditional-condition-only');
    expect(match?.source?.quote).toBeTruthy();
    expect(names(one(1,{tianPanGan:below,diPanGan:above}))).not.toContain(name);
  });
});
