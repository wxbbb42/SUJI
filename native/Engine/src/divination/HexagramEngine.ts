/** 京房八宫纳甲。规则与校勘边界见 docs/mingli/validation/divination-research.md。 */
import type { CastOptions, HexagramReading, HexagramLine, Yao, GuaInfo, LiuQin, YongShenAnalysis, WuXing, QuestionType } from './types';
import { findGuaByYao, GUA_64 } from './data/gua64';
import { ganZhiForGua, liuQinForGua, yaoWuXingForGua, relationToMe } from './data/liuqin';
import { TRIGRAMS } from './data/trigrams';
import { getCalendarPillars } from '@engine/calendar/precision';
import { lineContext, LINE_CONTEXT_SOURCE } from './lineContext';

const BRANCHES = [...'子丑寅卯辰巳午未申酉戌亥'];
const STEMS = [...'甲乙丙丁戊己庚辛壬癸'];
const SIX_SPIRITS = ['青龙', '朱雀', '勾陈', '腾蛇', '白虎', '玄武'];
const SHENG: Record<WuXing, WuXing> = { 木:'火', 火:'土', 土:'金', 金:'水', 水:'木' };
const KE: Record<WuXing, WuXing> = { 木:'土', 土:'水', 水:'火', 火:'金', 金:'木' };
const BRANCH_ELEMENTS: WuXing[] = ['水','土','木','木','土','火','火','土','金','金','土','水'];

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
    const lines: HexagramLine[] = lineValues.map((value, i) => {
      const position = i+1;
      const context = lineContext(gzs[i],wxs[i],pillars.month,pillars.day,xunKong);
      const qin = liuQin[position as 1|2|3|4|5|6], hiddenQin = pureQin[position as 1|2|3|4|5|6];
      return {
        position, value, ganZhi:gzs[i], wuXing:wxs[i], liuQin:qin,
        liuShen:SIX_SPIRITS[(spiritStart+i)%6], isShi:position===shiYao, isYing:position===yingYao,
        isChanging:changingYao.includes(position), context, isVoid:context.isVoid,
        monthClash:context.month.clash,
        dayClash:context.day.clash,
        dayCombination:context.day.combination,
        // 变爻六亲仍以本卦宫五行为我，不改用变卦宫。
        ...(changingYao.includes(position) ? {changed:{ganZhi:changedGzs[i],wuXing:changedWxs[i],liuQin:relationToMe(palaceElement,changedWxs[i]),context:lineContext(changedGzs[i],changedWxs[i],pillars.month,pillars.day,xunKong)}} : {}),
        ...(!presentQin.has(hiddenQin) ? {hidden:{ganZhi:pureGzs[i],wuXing:pureWxs[i],liuQin:hiddenQin,context:lineContext(pureGzs[i],pureWxs[i],pillars.month,pillars.day,xunKong)}} : {}),
      };
    });
    const yongShen = this.selectYongShen(opts.questionType ?? 'general', opts.gender, liuQin, benGua, pillars.month, shiYao, lines);
    return {
      question:opts.question, questionType:opts.questionType ?? 'general', castTime:castTime.toISOString(), castGanZhi,
      benGua,bianGua,changingYao,liuQin,yongShen,lineValues,shiYao,yingYao,xunKong,lines,
      ruleSources:[LINE_CONTEXT_SOURCE],
      yingQi:{description:'未推定应期；月日、动变与用神条件不足以给出可靠的具体日期',factors:['不使用固定周数或月份作为预测期限']},
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

  private selectYongShen(qt:QuestionType, gender:'男'|'女'|undefined, liuQin:Record<1|2|3|4|5|6,LiuQin>, gua:GuaInfo, month:string, shiYao:number, lines:HexagramLine[]):YongShenAnalysis {
    const byCategory:Partial<Record<QuestionType,LiuQin>> = {career:'官鬼',wealth:'妻财',kids:'子孙',parents:'父母'};
    const target = qt==='marriage' && gender ? (gender==='男' ? '妻财' : '官鬼') : byCategory[qt];
    const type = target ?? liuQin[shiYao as 1|2|3|4|5|6];
    const candidates = target ? lines.filter(l=>l.liuQin===target) : lines.filter(l=>l.isShi);
    const chosen = candidates[0];
    if (!chosen) {
      const hidden = lines.find(l=>l.hidden?.liuQin===type)?.hidden;
      return {type,yaoIndex:0,wuXing:hidden?.wuXing ?? TRIGRAMS[gua.palace].wuXing,state:'不上卦',candidateYaoIndices:[],interactions:[hidden ? `用神伏藏：${hidden.ganZhi}，需结合飞伏生克判断` : '未找到用神，暂不判定']};
    }
    const monthWx=BRANCH_ELEMENTS[BRANCHES.indexOf(month[1])], wx=chosen.wuXing;
    const state=monthWx===wx?'旺':SHENG[monthWx]===wx?'相':SHENG[wx]===monthWx?'休':KE[wx]===monthWx?'囚':'死';
    return {type,yaoIndex:chosen.position,wuXing:wx,state,candidateYaoIndices:candidates.map(l=>l.position),interactions:[
      target ? `按问题类别初选${target}` : '以世爻代表求问者；具体用神仍需明确所问对象',
      `月建${month}五行关系：${state}（非综合旺衰）`,
      ...(candidates.length>1 ? ['多个用神候选，当前列出初爻起首项，不代表最终取用'] : []),
      ...(chosen.isVoid?['临旬空']:[]),...(chosen.monthClash?['临月破']:[]),...(chosen.dayClash?['日冲']:[]),...(chosen.dayCombination?['日合']:[]),
    ]};
  }
}
