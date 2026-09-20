/** 京房八宫纳甲。规则与校勘边界见 docs/mingli/validation/divination-research.md。 */
import type { CastOptions, HexagramReading, HexagramLine, Yao, WuXing } from './types';
import { findGuaByYao, GUA_64 } from './data/gua64';
import { ganZhiForGua, liuQinForGua, yaoWuXingForGua, relationToMe } from './data/liuqin';
import { TRIGRAMS } from './data/trigrams';
import { getCalendarPillars } from '@engine/calendar/precision';
import { lineContext, LINE_CONTEXT_SOURCE } from './lineContext';
import { lineRules, CONDITIONAL_RULE_SOURCES } from './conditionalRules';
import {selectQuestionObjects,conditionalTiming,QUESTION_RULE_SOURCE} from './questionJudgment';
import { guaRelations } from './guaRelations';

const BRANCHES = [...'子丑寅卯辰巳午未申酉戌亥'];
const STEMS = [...'甲乙丙丁戊己庚辛壬癸'];
const SIX_SPIRITS = ['青龙', '朱雀', '勾陈', '腾蛇', '白虎', '玄武'];
export class HexagramEngine {
  cast(opts: CastOptions): HexagramReading {
    const castTime = opts.castTime ?? new Date();
    if (!Number.isFinite(castTime.getTime())) throw new Error('invalid castTime');
    const lineValues = opts.lineValues ? [...opts.lineValues] : Array.from({ length: 6 }, () => this.castSingleYao());
    if (lineValues.length !== 6 || lineValues.some(v => ![6,7,8,9].includes(v))) throw new Error('lineValues must contain six integers from 6 to 9, bottom to top');
    const benYao: Yao[] = lineValues.map(v => v % 2 ? '阳' : '阴');
    const bianYao: Yao[] = lineValues.map(v => v === 6 || v === 7 ? '阳' : '阴');
    const changingYao = lineValues.flatMap((v, i) => v === 6 || v === 9 ? [i+1] : []);
    const benGua = findGuaByYao(benYao);
    const bianGua = changingYao.length ? findGuaByYao(bianYao) : benGua;
    const liuQin = liuQinForGua(benGua);
    const pillars = getCalendarPillars(castTime);
    const castGanZhi = { day: pillars.day, month: pillars.month, hour: pillars.hour };
    const palaceSequence = GUA_64.filter(g => g.palace === benGua.palace);
    const stage = palaceSequence.findIndex(g => g.name === benGua.name);
    // 本宫、初世、二世、三世、四世、五世、游魂、归魂；应爻隔三位。
    const shiYao = [6,1,2,3,4,5,4,3][stage];
    const yingYao = (shiYao + 2) % 6 + 1;
    const dayStem = STEMS.indexOf(pillars.day[0]);
    const dayBranch = BRANCHES.indexOf(pillars.day[1]);
    const xunStartBranch = (dayBranch - dayStem + 12) % 12;
    const xunKong = [BRANCHES[(xunStartBranch+10)%12], BRANCHES[(xunStartBranch+11)%12]];
    const spiritStart = [0,0,1,1,2,3,4,4,5,5][dayStem];
    const gzs = ganZhiForGua(benGua), wxs = yaoWuXingForGua(benGua);
    const changedGzs = ganZhiForGua(bianGua), changedWxs = yaoWuXingForGua(bianGua);
    const pure = palaceSequence[0], pureGzs = ganZhiForGua(pure), pureWxs = yaoWuXingForGua(pure), pureQin = liuQinForGua(pure);
    const palaceElement = TRIGRAMS[benGua.palace].wuXing;
    const presentQin = new Set(Object.values(liuQin));
    // Same policy applies to every context; keep object-specific values in place.
    const contextFacts = (ganZhi:string,element:WuXing) => {
      const {assessmentStatus:_status,sourceIds:_sources,...facts} = lineContext(ganZhi,element,pillars.month,pillars.day,xunKong);
      return facts;
    };
    const lines: HexagramLine[] = lineValues.map((value, i) => {
      const position = i+1;
      const context = contextFacts(gzs[i],wxs[i]);
      const qin = liuQin[position as 1|2|3|4|5|6], hiddenQin = pureQin[position as 1|2|3|4|5|6];
      return {
        position, value, ganZhi:gzs[i], wuXing:wxs[i], liuQin:qin,
        liuShen:SIX_SPIRITS[(spiritStart+i)%6], isShi:position===shiYao, isYing:position===yingYao,
        isChanging:changingYao.includes(position), context, isVoid:context.isVoid,
        monthClash:context.month.clash,
        dayClash:context.day.clash,
        dayCombination:context.day.combination,
        // 变爻六亲仍以本卦宫五行为我，不改用变卦宫。
        ...(changingYao.includes(position) ? {changed:{ganZhi:changedGzs[i],wuXing:changedWxs[i],liuQin:relationToMe(palaceElement,changedWxs[i]),context:contextFacts(changedGzs[i],changedWxs[i])}} : {}),
        ...(!presentQin.has(hiddenQin) ? {hidden:{ganZhi:pureGzs[i],wuXing:pureWxs[i],liuQin:hiddenQin,context:contextFacts(pureGzs[i],pureWxs[i])}} : {}),
      };
    });
    for (const line of lines) line.rules = lineRules(line,lines);
    const yongShen = selectQuestionObjects(opts.questionType ?? 'general',opts.questionContext??{},lines,palaceElement,pillars);
    return {
      question:opts.question, questionType:opts.questionType ?? 'general', castTime:castTime.toISOString(), castGanZhi,
      benGua,bianGua,changingYao,liuQin,yongShen,lineValues,shiYao,yingYao,xunKong,lines,
      guaRelations:guaRelations(benGua,bianGua,changingYao),
      lineContextPolicy:{assessmentStatus:'calendar-relations-only',sourceIds:[LINE_CONTEXT_SOURCE.id]},
      questionContext:opts.questionContext??{},ruleSources:[LINE_CONTEXT_SOURCE,...CONDITIONAL_RULE_SOURCES,QUESTION_RULE_SOURCE],
      yingQi:conditionalTiming(yongShen,lines,opts.questionContext??{}),
      method:{algorithm:'jingfang-najia-v1',calendar:'Beijing civil time; exact solar-term month',dayBoundary:'zi-hour',caveats:[
        '旺相休囚死仅表示月建五行关系，不等于综合旺衰或事件结果',
        '用神按提问类别初选；多个候选爻全部保留，需结合具体所问再判断',
        '旬空、月破、日冲和伏神是排盘事实，不自动判定吉凶或应期',
      ]},
    };
  }

  private castSingleYao(): 6|7|8|9 {
    return (Array.from({length:3}, () => Math.random() < 0.5 ? 2 : 3).reduce<number>((a,b)=>a+b,0)) as 6|7|8|9;
  }

}
