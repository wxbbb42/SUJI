import { PATTERN_CONDITION_SOURCES } from './patternSources';

export const RESCUE_SOURCES = [
  ...PATTERN_CONDITION_SOURCES,
  {id:'ziping-xu-combination-limits-v1',document:'docs/mingli/source-texts/bazi/ziping-zhenquan/01-foundations.md',
    sha256:'8ea626e3744bb7129351b57dd3c4d6b6be595484345d8ea8101df50611993596',
    locator:'四、论十干配合性情；五、论十干合而不合',
    quote:'如地支通根，则虽合而不失其用，喜忌依然存在',
    additionalQuotes:['甲己中间，以庚间隔之，则甲岂能越克我之庚而合己','日元之干相合，除合而化，变更性质之外，皆不以合论','相合则煞不攻身，非谓去之也','地支所藏之干，本静以待用，透出干头，则显其用矣'],
    editionStatus:'electronic-transcription-not-print-collated'},
  {id:'ziping-xu-hidden-action-cases-v1',document:'docs/mingli/source-texts/bazi/ziping-zhenquan/35-yinshou.md',
    sha256:'d87e8f7df9f15175b26a75e9acee2a1b6e50b2df1b4ef1b5f189c38d8aa7a63c',
    locator:'三十五、论印绶，朱尚书与庚戌戊子甲戌乙亥两例',
    quote:'辰未中皆藏乙木财星，暗损印绶，病重而得药',
    additionalQuotes:['戌中更藏丁火食神，非子印所能夺','盖印未曾合去也'],
    editionStatus:'electronic-transcription-not-print-collated'},
];
