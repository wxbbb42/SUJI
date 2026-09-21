import type { RuleSource } from '../rules/provenance';
const weatherURL='https://www.aqioo.com/qmdjxdyyjs/167806.html',weatherSHA='4bc953e3ba511c0461a8d709c2bb9b32fc576d2ec447401fa6678c1a2872779b';
const dwellingURL='https://www.aqioo.com/qmdjxdyyjs/167799.html',dwellingSHA='46a78f7549a6c48255d20909904990bb4844eecafc04a978361d7fbcdf0108fc';
export const QIMEN_WEATHER_SELECTION_SOURCE:RuleSource={
 id:'qimen-xdyy-weather-selection-v1',version:'1',title:'奇门遁甲现代应用技术：天气专门对象',editionStatus:'electronic-transcription-not-print-collated',
 scope:'明确占雨、雪、风、河水的原盘参考对象；不裁定实际天气',
 references:[
  {url:weatherURL,sha256:weatherSHA,locator:'第04章 天气情况；占雨；文字稿第16行',quote:'测是否下雨以天柱星代表雨师，天蓬星代表水神'},
  {url:weatherURL,sha256:weatherSHA,locator:'第04章 天气情况；占雪；文字稿第17行',quote:'占雪、专看天心、天柱二星。'},
  {url:weatherURL,sha256:weatherSHA,locator:'第04章 天气情况；占风；文字稿第19行',quote:'占风、专看天辅星落何宫'},
  {url:weatherURL,sha256:weatherSHA,locator:'第04章 天气情况；河水；文字稿第20行',quote:'占河水消长，专看天蓬、休门为用神。'},
 ],limitations:['仅核对原文指定对象及原盘位置；不推断降水、风力、洪水或适宜出行日期','并列对象共同保留，不按首项、落宫或旺衰替换','只读原盘，不重起局；转录实例有日期勘误，未用其应验叙述证明预测有效'],
};
export const QIMEN_DWELLING_SELECTION_SOURCE:RuleSource={
 id:'qimen-xdyy-dwelling-selection-v1',version:'1',title:'奇门遁甲现代应用技术：住宅专门对象',editionStatus:'electronic-transcription-not-print-collated',
 scope:'明确住宅及设施角色的原盘参考对象；不判现实房屋位置、宅运或安全',
 references:[
  {url:dwellingURL,sha256:dwellingSHA,locator:'第10章；住宅自身条件；文字稿第96–97行',quote:'时干、生门所落宫位是否得令。'},
  {url:dwellingURL,sha256:dwellingSHA,locator:'第10章；住宅大门；文字稿第98行',quote:'值使门代表住宅的大门及在使用住宅期间的各种影响。'},
  {url:dwellingURL,sha256:dwellingSHA,locator:'第10章；厨房设施；文字稿第99行',quote:'丙奇代表灶具、燃火，壬水为饮用自来水，辛为锅碗瓢盆'},
  {url:dwellingURL,sha256:dwellingSHA,locator:'第10章；院落、天井；文字稿第101行',quote:'九天、天芮星代表院落，己代表天井'},
  {url:dwellingURL,sha256:dwellingSHA,locator:'第10章；住宅房间；文字稿第102行',quote:'六合为客厅所在之宫，大多为客厅的位置。'},
 ],limitations:['原文角色对应不是实际房间方位或房屋吉凶的证据','干的盘层未由该取用句唯一限定，地盘、寄地盘、天盘及寄天盘分列，不选首项','住宅大门只取本盘值使门；日干和年命及大环境总裁定、移宫法、阴宅未实现','只读原盘；不由此推断健康、灾害、财运或购房决策'],
};
export const QIMEN_SELECTION_SOURCE_IDS=[QIMEN_WEATHER_SELECTION_SOURCE.id,QIMEN_DWELLING_SELECTION_SOURCE.id];
export function qimenSelectionSource(focus:string):RuleSource{return focus.startsWith('weather-')?QIMEN_WEATHER_SELECTION_SOURCE:QIMEN_DWELLING_SELECTION_SOURCE;}
