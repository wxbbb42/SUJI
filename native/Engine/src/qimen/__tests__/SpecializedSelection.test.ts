import { QimenEngine } from '../QimenEngine';
import { analyzeQimenSelection } from '../specializedSelection';
import type { QimenChart, SetupOptions } from '../types';
import { QIMEN_WEATHER_SELECTION_SOURCE, QIMEN_DWELLING_SELECTION_SOURCE } from '../selectionSources';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { resolve } from 'node:path';

const engine=new QimenEngine();
const options=(focus?:string)=>({setupTime:new Date('2004-05-29T04:00:00Z'),question:'核对明确事项的传统取用',questionType:'event',
  questionContext:{subject:'self',event:'单一事项',timeHorizon:'near'},...(focus?{selectionRequest:{focus}}:{})} as SetupOptions);
const plate=()=>engine.setup(options());
const read=(c:QimenChart,focus:string)=>analyzeQimenSelection(c,{focus} as any);
const symbols=(r:any)=>r.references.map((x:any)=>x.symbol);

describe('source-specific Qimen object selection',()=>{
 test.each([
  ['weather-rain',['天柱','天蓬']],['weather-snow',['天心','天柱']],['weather-wind',['天辅']],['weather-river-level',['天蓬','休门']],
 ])('%s retains every expressly named peer object without weather adjudication',(focus,expected)=>{
  const c=engine.setup(options(focus)),r=(c as any).specializedSelection;
  expect(r).toBeDefined();expect(symbols(r)).toEqual(expected);
  expect(r).toMatchObject({methodVersion:'qimen-xdyy-selection-v1',request:{focus},event:'单一事项',roleMappingEstablished:true,outcomeEstablished:false,conflicts:[]});
  expect(r.references.every((x:any)=>x.occurrences.length===1)).toBe(true);
  expect(c.ruleSources!.filter(s=>s.id==='qimen-xdyy-weather-selection-v1')).toHaveLength(1);
  expect(c.yongShen.selectionEstablished).toBe(false);expect(c.timing).toBeUndefined();
 });
 test('dwelling roles remain distinct, including direct stems on separately labelled plates',()=>{
  const c=plate();
  for(const [focus,expected] of [
   ['dwelling-residence',[c.hourGanZhi![0],'生门']],['dwelling-stove',['丙']],['dwelling-tap-water',['壬']],['dwelling-utensils',['辛']],
   ['dwelling-courtyard',['九天','天芮']],['dwelling-skywell',['己']],['dwelling-living-room',['六合']],
  ] as [string,string[]][]){const r=read(c,focus);expect(r).toBeDefined();expect(symbols(r)).toEqual(expected);expect(r.outcomeEstablished).toBe(false);}
  const stove=read(c,'dwelling-stove').references[0];
  expect(stove.resolution).toBe('multiple-plate-references');
  expect(stove.occurrences.map((x:any)=>x.plate)).toEqual(expect.arrayContaining(['earth','sky']));
  expect(stove.selectedObjectPath).toBeNull();
 });
 test('entrance selects the actual duty door and verifies its palace identity',()=>{
  const c=plate(),r=read(c,'dwelling-entrance'),ref=r.references[0];
  expect(ref.symbol).toBe(c.zhiShiMen);expect(ref.occurrences).toEqual([{palaceId:c.zhiShiPalaceId,plate:'door',objectPath:`/palaces/${c.palaces.findIndex(p=>p.id===c.zhiShiPalaceId)}/bamen`}]);
  expect(ref.factPaths).toEqual(['/zhiShiMen','/zhiShiPalaceId']);
  const bad=structuredClone(c);bad.zhiShiPalaceId=c.zhiShiPalaceId===1?2:1;
  expect(read(bad,'dwelling-entrance')).toMatchObject({roleMappingEstablished:false,conflicts:[{id:'duty-door-palace-conflict',factPaths:['/zhiShiMen','/zhiShiPalaceId']}]});
 });
 test('reordered palaces keep exact original array pointers and never select a duplicate first',()=>{
  const c=plate();c.palaces.reverse();const r=read(c,'weather-rain');
  expect(r.references[0].occurrences[0].objectPath).toBe(`/palaces/${c.palaces.findIndex(p=>p.jiuxing==='天柱')}/jiuxing`);
  const other=c.palaces.find(p=>p.id!==5&&p.jiuxing!=='天柱')!;other.jiuxing='天柱';
  const conflict=read(c,'weather-rain');expect(conflict.roleMappingEstablished).toBe(false);
  expect(conflict.references[0].occurrences).toHaveLength(2);expect(conflict.references[0].selectedObjectPath).toBeNull();
  expect(conflict.conflicts.some((x:any)=>x.id==='duplicate-role-object')).toBe(true);
 });
 test('explicit event, broad-category conflict and compatible method are independently required',()=>{
  const c=plate();c.questionContext!.event=' ';expect(read(c,'weather-rain')).toMatchObject({roleMappingEstablished:false,missingContext:['single-event']});
  c.questionContext!.event='事项';c.questionType='wealth';expect(read(c,'weather-rain').conflicts).toEqual([{id:'question-category-conflict',factPaths:['/questionType']}]);
  c.questionType='event';c.method.centerPolicy='another-school';expect(read(c,'weather-rain').missingContext).toContain('compatible-chart-method');
  expect(()=>read(c,'invented')).toThrow(/专门取用/);
 });
 test('center records and missing original symbols never become effective role objects',()=>{
  const c=plate();for(const p of c.palaces)if(p.jiuxing==='天辅')p.jiuxing='天心';c.palaces.find(p=>p.id===5)!.jiuxing='天辅';
  const r=read(c,'weather-wind');expect(r.references[0].occurrences).toEqual([]);expect(r.roleMappingEstablished).toBe(false);expect(r.missingContext).toContain('role-object:wind-star');
 });
 test('Jia hour uses its own pillar carrier and preserves original stem identity',()=>{
  const c=plate();c.hourGanZhi='甲戌';const r=read(c,'dwelling-residence').references[0];
  expect(r).toMatchObject({symbol:'甲',carrierStem:'己',carrierMethod:'own-pillar-xun',factPaths:['/hourGanZhi']});
  expect(r.occurrences.every((o:any)=>{const [,,i,f]=o.objectPath.split('/');return (c.palaces[Number(i)] as any)[f]==='己';})).toBe(true);
  c.hourGanZhi='甲丑';const invalid=read(c,'dwelling-residence');expect(invalid.missingContext).toContain('original-hour-pillar');expect(invalid.references[0].occurrences).toEqual([]);
 });
 test('each quoted selection rule matches newly archived raw bytes and full text',()=>{
  const directory=resolve(__dirname,'../../../validation/research-divination/selection-2026-09-21');
  for(const source of [QIMEN_WEATHER_SELECTION_SOURCE,QIMEN_DWELLING_SELECTION_SOURCE])for(const ref of source.references){
   const id=ref.url.match(/(\d+)\.html$/)![1];
   expect(createHash('sha256').update(readFileSync(resolve(directory,id+'.html'))).digest('hex')).toBe(ref.sha256);
   expect(readFileSync(resolve(directory,id+'.txt'),'utf8')).toContain(ref.quote);
  }
 });
 test('supplement replaces the request/source, preserves the original palaces and removes absent selection',()=>{
  const original=engine.setup(options('weather-rain')),before=JSON.stringify(original);
  const changed=engine.reassessQuestion(original,{...options('dwelling-entrance'),question:'换成住宅大门',questionContext:{event:'大门取用',subject:'self'}});
  expect((changed as any).specializedSelection.request).toEqual({focus:'dwelling-entrance'});expect((changed as any).specializedSelection.event).toBe('大门取用');
  expect(changed.palaces).toEqual(original.palaces);expect(changed.setupTime).toBe(original.setupTime);expect(JSON.stringify(original)).toBe(before);
  expect(changed.ruleSources!.filter(s=>s.id.includes('-selection-v1')).map(s=>s.id)).toEqual(['qimen-xdyy-dwelling-selection-v1']);
  const removed=engine.reassessQuestion(changed,options());expect((removed as any).specializedSelection).toBeUndefined();expect(removed.ruleSources!.some(s=>s.id.includes('-selection-v1'))).toBe(false);
 });
});
