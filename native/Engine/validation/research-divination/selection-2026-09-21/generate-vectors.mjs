import {build} from 'esbuild';
import vm from 'node:vm';
import {createRequire} from 'node:module';
import {writeFileSync} from 'node:fs';
const require=createRequire(import.meta.url),engine=new URL('../../../',import.meta.url).pathname;
const output=await build({stdin:{contents:"export {QimenEngine} from './src/qimen/QimenEngine';export {QIMEN_SELECTION_FOCUSES,analyzeQimenSelection} from './src/qimen/specializedSelection';",resolveDir:engine},bundle:true,write:false,format:'cjs',platform:'node'});
const sandbox={module:{exports:{}},exports:{},require,Date};vm.runInNewContext(output.outputFiles[0].text,sandbox);
const {QimenEngine,QIMEN_SELECTION_FOCUSES,analyzeQimenSelection}=sandbox.module.exports,e=new QimenEngine();
const vectors=QIMEN_SELECTION_FOCUSES.map(focus=>{
 const arguments_={question:'核对明确事项的传统取用',questionType:'event',subject:'self',event:'单一事项',timeHorizon:'near',selectionRequest:{focus}};
 const chart=e.setup({setupTime:new Date('2004-05-29T04:00:00Z'),question:arguments_.question,questionType:'event',questionContext:{subject:'self',event:arguments_.event,timeHorizon:'near'},selectionRequest:{focus}});
 return {focus,arguments:arguments_,chart:{...chart,provenance:{engineRevision:'selection-fixture-v1'}}};
});
writeFileSync(new URL('native-vectors.json',import.meta.url),JSON.stringify(vectors,null,2)+'\n');
console.log('Generated '+vectors.length+' specialized selection vectors from the engine; Swift derives its expected roles independently.');
const boundaries=[];
function boundary(name,focus,mutate,established){
 const vector=structuredClone(vectors.find(v=>v.focus===focus));
 mutate(vector.chart,vector.arguments);
 vector.chart.specializedSelection=analyzeQimenSelection(vector.chart,vector.arguments.selectionRequest);
 boundaries.push({...vector,name,established});
}
boundary('event-missing','weather-rain',(c,a)=>{c.questionContext.event='';a.event='';},false);
boundary('category-conflict','weather-rain',(c,a)=>{c.questionType='career';a.questionType='career';},false);
boundary('method-incompatible','weather-rain',c=>{c.method.algorithm='other';},false);
boundary('duty-door-palace-conflict','dwelling-entrance',c=>{c.zhiShiPalaceId=c.zhiShiPalaceId===1?2:1;},false);
boundary('duplicate-star','weather-rain',c=>{c.palaces.find(p=>p.id!==5&&p.jiuxing!=='天柱'&&p.jiuxing!=='天蓬').jiuxing='天柱';},false);
boundary('reordered-palaces','weather-rain',c=>{c.palaces.reverse();},true);
boundary('center-only-star','weather-wind',c=>{c.palaces.find(p=>p.jiuxing==='天辅').jiuxing='天心';c.palaces.find(p=>p.id===5).jiuxing='天辅';},false);
boundary('own-hour-jia','dwelling-residence',c=>{c.hourGanZhi='甲辰';},true);
boundary('invalid-hour-pillar','dwelling-residence',c=>{c.hourGanZhi='甲丑';},false);
boundary('utf16-200','weather-rain',(c,a)=>{c.questionContext.event='😀'.repeat(100);a.event=c.questionContext.event;},true);
boundary('utf16-202','weather-rain',(c,a)=>{c.questionContext.event='😀'.repeat(101);a.event=c.questionContext.event;},false);
boundary('js-trim','weather-rain',(c,a)=>{c.questionContext.event='\uFEFF单一事项\u3000';a.event=' 单一事项 ';},true);
boundary('duplicate-palace-id','weather-rain',c=>{c.palaces[0].id=c.palaces[1].id;},false);
boundary('general-category','weather-rain',(c,a)=>{c.questionType='general';delete a.questionType;},true);
writeFileSync(new URL('native-boundary-vectors.json',import.meta.url),JSON.stringify(boundaries,null,2)+'\n');
console.log('Generated '+boundaries.length+' independent-native boundary vectors.');
