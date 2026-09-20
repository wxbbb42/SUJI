import { HexagramEngine } from './HexagramEngine';
import { QimenEngine } from '../qimen/QimenEngine';
import { CALENDAR_POLICY } from '../calendar/precision';
import type { QuestionType } from './types';
import type { QuestionContext } from './questionJudgment';

// Native-only input: Core first resolves the actual persisted receipt and checks
// its complete source-bound report. This boundary also rejects incomplete/old
// shapes; a caller cannot use a derived chart as a fresh original.
export function reassessQuestion(input:any, engineRevision:string) {
  const name = input.name, s = input.original;
  const fail = () => { throw new Error('原盘记录不完整或已失效，请保留原记录并发起新的占问'); };
  if (!['cast_liuyao','setup_qimen'].includes(name) || typeof input.sourceCallID !== 'string' ||
      !/^[^\s\x00-\x1f\x7f]{1,200}$/.test(input.sourceCallID) || !s || typeof s !== 'object' ||
      'questionRevision' in s || s.provenance?.engineRevision !== engineRevision ||
      !s.provenance?.calendarPolicy || Object.keys(s.provenance.calendarPolicy).length !== Object.keys(CALENDAR_POLICY).length ||
      !Object.entries(CALENDAR_POLICY).every(([k,v])=>JSON.stringify(s.provenance.calendarPolicy[k])===JSON.stringify(v)) ||
      !Array.isArray(s.ruleSources) || !s.ruleSources.length || !s.questionContext ||
      !s.yongShen || !s.yingQi || typeof s.question !== 'string') fail();
  const originalTime = name === 'cast_liuyao' ? s.castTime : s.setupTime;
  if (typeof originalTime !== 'string' || !Number.isFinite(Date.parse(originalTime)) ||
      Date.parse(originalTime) !== Date.parse(s.provenance.referenceDate)) fail();
  const gz = (v:unknown) => typeof v === 'string' && /^[甲乙丙丁戊己庚辛壬癸][子丑寅卯辰巳午未申酉戌亥]$/.test(v);
  if (name === 'cast_liuyao') {
    if (s.method?.algorithm !== 'jingfang-najia-v1' || !Array.isArray(s.lines) || s.lines.length !== 6 ||
        !Array.isArray(s.lineValues) || s.lineValues.length !== 6 || !s.benGua || !s.bianGua ||
        !['乾','兑','离','震','巽','坎','艮','坤'].includes(s.benGua.palace) || !s.guaRelations || !s.roleRelations ||
        !s.liuQin || !Array.isArray(s.xunKong) || !Array.isArray(s.changingYao) || !s.lineContextPolicy ||
        !['day','month','hour'].every(k => gz(s.castGanZhi?.[k])) ||
        !s.lines.every((l:any,i:number) => l?.position === i+1 && [6,7,8,9].includes(l.value) &&
          l.value === s.lineValues[i] && gz(l.ganZhi) && l.context?.month && l.context?.day && l.rules)) fail();
  } else {
    if (s.method?.algorithm !== 'zhuanpan-qimen-chai-bu-v1' || !Array.isArray(s.palaces) || s.palaces.length !== 9 ||
        new Set(s.palaces.map((p:any)=>p?.id)).size !== 9 ||
        !s.palaces.every((p:any)=>Number.isInteger(p?.id) && p.id>=1 && p.id<=9 && p.diPanGan && p.wuXing) ||
        !['dayGanZhi','hourGanZhi','monthGanZhi','fuTou'].every(k=>gz(s[k])) ||
        !Number.isFinite(Date.parse(s.calculationTime)) || !Array.isArray(s.geJu)) fail();
  }
  const source = JSON.parse(JSON.stringify(s));
  const a = input.arguments;
  const opts = {question:a.question,questionType:(a.questionType ?? 'general') as QuestionType,
    questionContext:Object.fromEntries(['subject','event','timeHorizon'].filter(k=>a[k]!==undefined).map(k=>[k,a[k]])) as QuestionContext};
  const revised = name === 'cast_liuyao' ? new HexagramEngine().reassessQuestion(source,opts) : new QimenEngine().reassessQuestion(source,opts);
  return {...revised,questionRevision:{algorithm:'suji-cast-question-revision-1',sourceToolName:name,sourceCallID:input.sourceCallID}};
}
