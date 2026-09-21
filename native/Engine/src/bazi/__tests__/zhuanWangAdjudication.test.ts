import { computeGeJuV2, detectZhuanWang } from '../structural';
import type { DiZhi, TianGan } from '../types';
const read = (stems:string, branches:string) => detectZhuanWang(stems[2] as TianGan, [...stems] as [TianGan,TianGan,TianGan,TianGan], [...branches] as [DiZhi,DiZhi,DiZhi,DiZhi]);

describe('source-grounded exclusive-pattern recognition', () => {
  it.each([
    ['甲丁甲丙','寅卯辰寅','曲直格'],
    ['庚乙庚庚','申酉戌辰','从革格'],
    ['壬辛癸壬','子亥丑子','润下格'],
    ['丙甲丙乙','寅午戌未','炎上格'],
    ['丙戊丙丁','巳午未午','炎上格'],
    ['庚壬庚辛','申酉戌申','从革格'],
    ['壬甲癸辛','亥子丑亥','润下格'],
  ])('recognizes %s/%s without treating output or participating hidden controllers as universal breakers', (stems, branches, name) => {
    expect(read(stems,branches)).toMatchObject({isZhuanWang:true,name});
  });
  it('records a visible controller as failure of this profile, without an all-school rejection', () => {
    const r = read('甲丁甲庚','寅卯辰寅');
    expect(r.adjudication).toMatchObject({status:'not-established-in-selected-profile',exposedControllers:[{position:3,gan:'庚'}]});
  });
  it('requires season as well as complete branch tokens', () => {
    const r = read('甲丁甲丙','寅午辰卯');
    expect(r.adjudication).toMatchObject({status:'not-established-in-selected-profile',season:{status:'out-of-season'}});
  });
  it('records the unassessed Xu incomplete-formation alternative', () => {
    const r = read('癸乙甲乙','卯卯寅亥');
    expect(r.adjudication).toMatchObject({status:'not-established-in-selected-profile',alternativeProfile:{id:'ziping-xu-pure-peer-resource',status:'candidate'}});
    expect(r.isZhuanWang).toBe(true);
  });
  it('does not fabricate earth command from a 四库 month name', () => {
    expect((read('戊己戊庚','辰戌丑未')).adjudication).toMatchObject({status:'needs-month-commander',season:{status:'needs-month-commander'}});
  });
  it('attaches an independent scope to the existing chart result', () => {
    const r = computeGeJuV2('甲',['甲','丁','甲','丙'],['寅','卯','辰','寅']);
    expect(r.specialPatternEvidence).toMatchObject({status:'established',outcomeEstablished:false,profileId:'ditianshui-ren-full-formation-v1'});
    expect(r.assessmentStatus).toBe('heuristic-candidate');
  });
});

describe('earth and transition-month boundaries under the selected commander table', () => {
  const { adjudicateZhuanWang } = require('../zhuanWang') as typeof import('../zhuanWang');
  const assess = (stems:string,branches:string,daysAfterJie?:number) => adjudicateZhuanWang([...stems] as [TianGan,TianGan,TianGan,TianGan],[...branches] as [DiZhi,DiZhi,DiZhi,DiZhi],{daysAfterJie});
  it.each(['辰戌丑未','戌辰丑未','辰丑戌未','辰未丑戌'])('requires actual earth command for all four seasonal months: %s', branches => {
    expect(assess('戊己戊庚',branches)).toMatchObject({status:'needs-month-commander'});
    expect(assess('戊己戊庚',branches,11.99999)).toMatchObject({status:'not-established-in-selected-profile',season:{status:'out-of-season'}});
    expect(assess('戊己戊庚',branches,12)).toMatchObject({status:'established',name:'稼穑格',season:{commander:{element:'土'}}});
  });
  it('does not erase four-store hidden wood or require a fire resource', () => {
    const r = assess('戊己戊庚','辰戌丑未',15);
    expect(r.status).toBe('established');
    expect(r.hiddenControllerContext).toEqual([
      {position:0,branch:'辰',gan:'乙',inFormation:true,exposed:false,handling:'retained-within-formation'},
      {position:3,branch:'未',gan:'乙',inFormation:true,exposed:false,handling:'retained-within-formation'},
    ]);
    expect(r.outputStems).toEqual([{position:3,gan:'庚'}]);
  });
  it('rejects visible wood from the unmixed earth subset even after day 12', () => {
    expect(assess('戊己戊甲','辰戌丑未',15)).toMatchObject({status:'not-established-in-selected-profile',exposedControllers:[{position:3,gan:'甲'}]});
  });
  it.each([
    ['甲丁甲丙','寅辰卯寅',8.99999,9],
    ['丙戊丙丁','巳未午午',8.99999,9],
    ['庚壬庚辛','申戌酉申',8.99999,9],
    ['壬甲癸辛','亥丑子亥',8.99999,9],
  ])('does not grant the whole transition month to %s', (stems,branches,before,after) => {
    expect(assess(stems,branches)).toMatchObject({status:'needs-month-commander'});
    expect(assess(stems,branches,before)).toMatchObject({status:'established'});
    expect(assess(stems,branches,after)).toMatchObject({status:'not-established-in-selected-profile',season:{status:'out-of-season'}});
  });
  it('retains an external controller even when all formation tokens are present', () => {
    expect(assess('甲丁甲丙','申卯辰寅')).toMatchObject({status:'not-established-in-selected-profile',externalControllerBranches:[{position:0,branch:'申',element:'金'}]});
  });
  it('does not convert an unadjudicated hidden controller outside the formation into successful removal', () => {
    expect(assess('甲丁甲丙','寅卯辰戌')).toMatchObject({status:'not-established-in-selected-profile',unmetConditions:['external-hidden-controller-unadjudicated']});
  });
  it.each([-1,NaN,Infinity])('does not suppress invalid explicit elapsed input %s', days => {
    expect(()=>assess('甲丁甲丙','寅卯辰寅',days)).toThrow(RangeError);
  });
  it('does not call an incomplete selected profile an absence of any ordinary chart pattern', () => {
    const r = computeGeJuV2('甲',['甲','丁','甲','丙'],['卯','卯','卯','亥']);
    expect(r.category).toBe('zhengge');
    expect(r.specialPatternEvidence?.status).toBe('not-established-in-selected-profile');
    expect(r.name).toBeTruthy();
  });
});

it('binds the adjudication citations to exact archived files and passages', () => {
  const r = read('甲丁甲丙','寅卯辰寅');
  const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto');
  for (const source of r.adjudication.sources) {
    const bytes = fs.readFileSync(path.resolve(__dirname,'../../../../..',source.document));
    expect(crypto.createHash('sha256').update(bytes).digest('hex')).toBe(source.sha256);
    for (const quote of [source.quote,...source.additionalQuotes]) expect(bytes.toString()).toContain(quote);
  }
});
