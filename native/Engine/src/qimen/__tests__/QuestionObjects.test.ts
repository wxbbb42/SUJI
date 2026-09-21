import { QimenEngine } from '../QimenEngine';
import { qimenQuestionObjects } from '../questionObjects';
import type { Palace } from '../types';

const engine = new QimenEngine();
const base = { question:'核对盘面', questionType:'wealth' as const, setupTime:new Date('2024-02-04T04:00:00Z') };

describe('Qimen object identities and unresolved adjudication', () => {
  it('exposes fixed Kun earth hosting separately from the rotating Tianqin sky stem', () => {
    const chart = engine.setup(base) as any;
    // Hand chart A: center 庚 stays recorded in 5, earth hosting stays in 2,
    // while 天禽 carries sky 庚 to 7. These are three different objects.
    expect(chart.palaces.filter((p:any)=>p.hostedDiPanGan).map((p:any)=>[p.id,p.hostedDiPanGan])).toEqual([[2,'庚']]);
    expect(chart.palaces.filter((p:any)=>p.hostedTianPanGan).map((p:any)=>[p.id,p.hostedTianPanGan])).toEqual([[7,'庚']]);
    expect(chart.palaces.find((p:any)=>p.id===2)).toMatchObject({diPanGan:'乙',tianPanGan:'丁',hostedDiPanGan:'庚'});
    const references=qimenQuestionObjects('event',{},chart.palaces,{day:'庚子',hour:'甲申'});
    for (const candidate of references.candidates) {
      expect(candidate.occurrences.map(o=>[o.palaceId,o.plate])).toEqual([[2,'hosted-earth'],[5,'earth'],[5,'center-record'],[7,'hosted-sky']]);
      expect(candidate.occurrences[0].isEffectiveSky).toBe(false);
    }
  });
  it('keeps day and hour separate even when both are 戊 in the same palace', () => {
    const chart = engine.setup(base) as any;
    expect(chart.yongShen).toMatchObject({selectionEstablished:false,selectedCandidateId:null,missingContext:['subject','event','time-horizon']});
    const [day,hour] = chart.yongShen.candidates;
    expect([day.id,hour.id]).toEqual(['day-stem','hour-stem']);
    expect([day.calendarPath,hour.calendarPath]).toEqual(['/dayGanZhi','/hourGanZhi']);
    expect([day.symbol,hour.symbol]).toEqual(['戊','戊']);
    // Independently hand-worked chart A: earth 戊 in 3, sky 戊 in 4.
    expect(day.occurrences.map((x:any)=>[x.palaceId,x.plate,x.objectPath])).toEqual([
      [3,'earth','/palaces/2/diPanGan'],[4,'sky','/palaces/3/tianPanGan'],
    ]);
    expect(hour.occurrences).toEqual(day.occurrences);
    expect(chart.ruleSources.map((s:any)=>s.id)).toContain(chart.yongShen.sourceId);
    expect(chart.ruleSources.find((s:any)=>s.id===chart.yongShen.sourceId).editionStatus).toBe('product-policy');
  });

  it('retains proxy/conflicting context without assigning the day stem to the person asked about', () => {
    const context={subject:'parent',event:'代问父亲采购是否完成',timeHorizon:'near'};
    const chart=engine.setup({...base,questionType:'kids',questionContext:context} as any) as any;
    expect(chart.questionContext).toEqual(context);
    expect(chart.yongShen.missingContext).toEqual(['proxy-perspective','category-subject-conflict']);
    expect(chart.yongShen.selectionEstablished).toBe(false);
    expect(chart.yongShen.candidates[0].role).toBe('day-reference');
    expect(chart.yingQi).toMatchObject({outcomeEstablished:false,timeScale:'unresolved',triggers:[],dates:[]});
    expect(chart.yingQi.unresolved).toEqual(expect.arrayContaining(['selected-object','event-outcome','qimen-timing-convention','time-unit']));
  });

  it('does not infer a spouse from gender or treat a complete context as final selection', () => {
    const args={...base,questionType:'marriage',questionContext:{subject:'self',event:'与伴侣沟通',timeHorizon:'far'}};
    const male=engine.setup({...args,gender:'男'} as any) as any;
    const female=engine.setup({...args,gender:'女'} as any) as any;
    expect(male.yongShen).toEqual(female.yongShen);
    expect(male.yongShen.selectionStatus).toBe('candidates-only');
    expect(male.yongShen.selectedCandidateId).toBeNull();
    expect(male.yongShen.candidates.map((c:any)=>c.id)).toEqual(['day-stem','hour-stem','category-deity-六合']);
    expect(male.yingQi.timeScale).toBe('unresolved');
  });

  it('marks 甲 by its own day/hour carrier and does not count center as effective sky', () => {
    const chart=engine.setup({...base,setupTime:new Date('2026-09-19T04:00:00Z')}) as any;
    // Hand chart B: 甲午 hour hides under 辛 in 6, not 壬 hosted in 2.
    expect(chart.yongShen.candidates[1]).toMatchObject({symbol:'甲',carrierStem:'辛',carrierMethod:'own-pillar-xun',calendarPath:'/hourGanZhi'});
    expect(chart.yongShen.candidates[1].occurrences.map((x:any)=>[x.palaceId,x.plate])).toEqual([[6,'earth'],[6,'sky']]);
    expect(chart.yongShen.candidates[1].occurrences[1].elementRelation).toMatchObject({stemElement:'木',palaceElement:'金',relation:'宫克干',assessmentStatus:'stem-palace-only'});
  });

  it('projects reordered literal plates, separates two 甲 carriers, and preserves hosted identity', () => {
    // Literal selector fixture: 甲子→戊, 甲申→庚. It is not a newly calculated chart.
    const palaces = [
      {id:8,wuXing:'土',diPanGan:'乙',tianPanGan:'戊',hostedTianPanGan:'庚'},
      {id:5,wuXing:'土',diPanGan:'庚',tianPanGan:'庚'},
      {id:2,wuXing:'土',diPanGan:'戊',tianPanGan:'乙',hostedDiPanGan:'庚'},
    ] as Palace[];
    const snapshot=JSON.stringify(palaces);
    const result=qimenQuestionObjects('event',{},palaces,{day:'甲子',hour:'甲申'});
    expect(result.candidates.map(c=>[c.id,c.symbol,c.carrierStem])).toEqual([['day-stem','甲','戊'],['hour-stem','甲','庚']]);
    const hour=result.candidates[1];
    expect(hour.occurrences.map(o=>[o.palaceId,o.plate,o.objectPath,o.isEffectiveSky])).toEqual([
      [8,'hosted-sky','/palaces/0/hostedTianPanGan',true],
      [5,'earth','/palaces/1/diPanGan',false],
      [5,'center-record','/palaces/1/tianPanGan',false],
      [2,'hosted-earth','/palaces/2/hostedDiPanGan',false],
    ]);
    expect(hour.occurrences[0].elementRelation).toMatchObject({stemElement:'木',palaceElement:'土',relation:'干克宫'});
    expect(hour.occurrences[2].elementRelation).toBeUndefined();
    for(const candidate of result.candidates)for(const occurrence of candidate.occurrences){
      const [,index,field]=occurrence.objectPath.slice(1).split('/');
      expect((palaces[Number(index)] as any)[field]).toBe(candidate.carrierStem);
    }
    const reversed=qimenQuestionObjects('event',{},[...palaces].reverse(),{day:'甲子',hour:'甲申'});
    expect(reversed.candidates[1].occurrences.find(o=>o.plate==='hosted-sky')?.objectPath).toBe('/palaces/2/hostedTianPanGan');
    expect(JSON.stringify(palaces)).toBe(snapshot);
  });

  it('does not replace a missing sky occurrence with center or earth', () => {
    const palaces=[{id:5,wuXing:'土',diPanGan:'壬',tianPanGan:'壬'}] as Palace[];
    const result=qimenQuestionObjects('health',{subject:'self',event:'核对盘面',timeHorizon:'near'},palaces,{day:'壬子',hour:'壬寅'});
    expect(result.missingContext).toEqual(['day-sky-reference','hour-sky-reference']);
    expect(result.candidates[0].occurrences.every(o=>!o.isEffectiveSky)).toBe(true);
    expect(result.selectedCandidateId).toBeNull();
  });
});
