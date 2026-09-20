import type { RuleSource } from '../rules/provenance';
import type { Palace, ZiweiPan } from './types';

export const ZIWEI_RULE_SOURCES: RuleSource[] = [
  {
    id:'ziwei-palace-context-v1', version:'1', title:'紫微宫位三方四正与对宫参照',
    editionStatus:'pinned-engineering-reference', scope:'本宫及地支位移4、8、6的关联宫；参照不改变星曜实际落宫',
    references:[{url:'https://unpkg.com/iztro@2.5.8/lib/astro/analyzer.js',locator:'getSurroundedPalaces',sha256:'ce88ebcac850ff6810678b783b0ffba12e762b6dc0f42653be57ad30e043e865'}],
    limitations:['空宫保留为空，列对宫主星供参照；不移入本宫，不自动判借星强度或吉凶','三方位移相对于目标宫，不把每个目标的关联宫一律叫本命财帛或官禄'],
  },
  {
    id:'ziwei-sihua-selected-v1', version:'1', title:'生年四化：iztro 2.5.8默认表及全书异文',
    editionStatus:'electronic-transcription-not-print-collated', scope:'生年干四化，明确来源干、实际星曜与落宫；不等同宫干飞化或流年四化',
    references:[
      {url:'https://unpkg.com/iztro@2.5.8/lib/data/heavenlyStems.js',locator:'mutagen',sha256:'4eb6ee5e3a09db4ede931053de526ab258d0d76908922a1f980d7f996f226191'},
      {url:'https://zh.wikisource.org/wiki/紫微斗數全書/卷二',locator:'安禄权科忌四星变化诀',sha256:'1e255c6ae99e6f89ae124ab342554ef1347fc8e68fb8908cba7290d1a38cbb72',quote:'壬梁紫府武宿是，癸破巨阴贪狼停。'},
    ],
    limitations:['本产品默认壬年左辅化科；所读电子本为壬年天府化科，保留异文而不声称十干全同','闰月原文取次月，本产品采用前15日当月、后15日次月；晚子按完整次日月年处理','电子转录未做纸本校勘；结构正确不等于现实预测有效'],
  },
];

export function palaceFacts(palace: Palace, pan: ZiweiPan) {
  const main = palace.mainStars ?? [], minor = palace.minorStars ?? [];
  return {
    palace:palace.name, position:palace.position, ganZhi:palace.ganZhi,
    mainStars:main.map(s => s.name), mainStarsDetailed:main.map(s => `${s.name}${s.brightness ? `(${s.brightness})` : ''}`),
    minorStars:minor.map(s => s.name), isShenGong:palace.isShenGong,
    emptyMainPalace:main.length === 0,
    starDetails:[...main.map(s => ({...s,group:'main'})),...minor.map(s => ({...s,group:'minor'}))],
    natalTransformations:pan.natalYear ? [...main,...minor].flatMap(s => (s.sihua ?? []).map(transformation => ({
      scope:'natal-year-stem', sourceStem:pan.natalYear!.stem, star:s.name, transformation,
      targetPalace:palace.name, targetPosition:palace.position, sourceId:'ziwei-sihua-selected-v1',
    }))) : [],
  };
}

export function palaceContext(target: Palace, pan: ZiweiPan) {
  const branches = [...'子丑寅卯辰巳午未申酉戌亥'];
  const index = branches.indexOf(target.position);
  const relatedPalaces = index < 0 ? [] : ([['trine-4',4],['trine-8',8],['opposite',6]] as const).flatMap(([relation,offset]) => {
    const palace = pan.palaces.find(p => p.position === branches[(index + offset) % 12]);
    return palace ? [{relation,...palaceFacts(palace,pan)}] : [];
  });
  const opposite = relatedPalaces.find(p => p.relation === 'opposite');
  const emptyPalaceReference = (target.mainStars ?? []).length > 0 ? { status:'not-needed' }
    : opposite ? { status:'opposite-reference', sourcePalace:opposite.palace, sourcePosition:opposite.position, mainStars:opposite.mainStars }
    : { status:'unavailable' };
  return { relatedPalaces, emptyPalaceReference, natalYear:pan.natalYear, ruleSources:ZIWEI_RULE_SOURCES };
}
