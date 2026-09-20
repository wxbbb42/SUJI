/**
 * 奇门遁甲起局引擎
 *
 * - 默认北京时间标准时；显式传入占测经度时才作真太阳时校正
 * - 精确物理时刻节气与日时干支计算
 * - 阴/阳遁 + 上中下元定局
 * - 起 9 宫地盘（自然数序流转）+ 真旋天盘 + 排八门 / 九星 / 八神
 *
 * 关键修复（2026-04-26，原 ADR-7 关停项）：
 *   C1：真旋天盘 — 见 helpers/tianPan.ts
 *   C2：三奇六仪按自然数序流转（非后天八卦顺时针）— 见 helpers/diPan.ts
 *
 * 拆补法：五日符头定元，值使门按旬内时数沿九宫飞数。
 * 用神仅为分类初选；不从不充分规则生成固定应期。
 */
import { toTrueSolarTime } from '@engine/bazi/TrueSolarTime';
import type {
  QimenChart, Palace, SetupOptions, YinYangDun, JuNumber,
  TianGan, BamenName, BashenName, JiuxingName, GeJu,
  QuestionType, YongShenAnalysis, QimenMethodMeta,
} from './types';
import { PALACES_BASE } from './data/palaces';
import { rotateBamen } from './helpers/bamen';
import { computeYuanFromDay } from './helpers/yuan';
import { JIUXING_DI_PAN_FIXED } from './data/jiuxing';
import { BASHEN_ORDER } from './data/bashen';
import { findJieqiJu } from './data/jieqi-ju';
import { YONGSHEN_RULES } from './data/yongshen-rules';
import { detectGeJu } from './data/geju';
import { buildDiPan } from './helpers/diPan';
import { rotateTianPan, computeXunShou, PALACE_CLOCKWISE_8 } from './helpers/tianPan';
import { computeTimePillars } from './helpers/timeGanZhi';
import { currentSolarTerm } from './helpers/solarTerms';
import { getCalendarPillars } from '@engine/calendar/precision';
import { qimenFacts } from './facts';
import { qimenQuestionObjects, unresolvedQimenTiming, QIMEN_QUESTION_SOURCE } from './questionObjects';

const QIMEN_METHOD: QimenMethodMeta = {
  level: 'standard',
  algorithm: 'zhuanpan-qimen-chai-bu-v1',
  centerPolicy: 'fixed-kun-2; tian-qin-follows-tian-rui',
  solarTermClock: 'physical-instant',
  caveats: [
    '采用拆补法和中五固定寄坤二，不混用置闰法或阴阳分寄法',
    '尚未定用；干宫关系非综合旺衰，应期规则未完备',
    '格局识别只覆盖当前数据表可判定的常用格局',
  ],
};

const GAN_WUXING: Record<TianGan, '金' | '木' | '水' | '火' | '土'> = {
  甲: '木', 乙: '木',
  丙: '火', 丁: '火',
  戊: '土', 己: '土',
  庚: '金', 辛: '金',
  壬: '水', 癸: '水',
};

const SHENG: Record<'金' | '木' | '水' | '火' | '土', '金' | '木' | '水' | '火' | '土'> = {
  木: '火', 火: '土', 土: '金', 金: '水', 水: '木',
};

const KE: Record<'金' | '木' | '水' | '火' | '土', '金' | '木' | '水' | '火' | '土'> = {
  木: '土', 土: '水', 水: '火', 火: '金', 金: '木',
};

export class QimenEngine {
  setup(opts: SetupOptions): QimenChart {
    const setupTime = opts.setupTime ?? new Date();
    const longitude = opts.longitude;

    if (!Number.isFinite(setupTime.getTime())) throw new Error('invalid setupTime');
    if (longitude !== undefined && (!Number.isFinite(longitude) || longitude < -180 || longitude > 180)) throw new Error('invalid longitude');

    // 1. 缺少本次占测地点时按明确的北京时间标准时口径起局，不猜地点。
    const calculationTime = longitude === undefined ? setupTime : toTrueSolarTime(setupTime, longitude);
    const method: QimenMethodMeta = {
      ...QIMEN_METHOD,
      clockPolicy: longitude === undefined ? 'beijing-standard' : 'apparent-solar',
      timezone: 'UTC+08:00',
      dayBoundary: longitude === undefined ? 'zi-hour on Beijing-standard clock' : 'zi-hour on apparent-solar clock',
      ...(longitude === undefined ? {} : { longitude }),
      caveats: [
        ...QIMEN_METHOD.caveats,
        longitude === undefined
          ? '未指定本次占测经度，按北京时间标准时（UTC+08:00）起局，不作真太阳时修正'
          : `按显式指定的本次占测经度${longitude}°修正日时钟面；节气仍按真实物理时刻`,
      ],
    };

    // 2. 节气
    const jieqi = currentSolarTerm(setupTime);

    // 3. 阴阳遁 + 局数 + 元
    const jieqiJu = findJieqiJu(jieqi);
    if (!jieqiJu) {
      throw new Error(`unknown jieqi: ${jieqi}`);
    }
    const yinYangDun: YinYangDun = jieqiJu.dun;
    const pillars = computeTimePillars(calculationTime);
    const {yuan,fuTou} = computeYuanFromDay(pillars.dayGan+pillars.dayZhi);
    const juNumber: JuNumber = yuan === '上' ? jieqiJu.upper :
                                yuan === '中' ? jieqiJu.middle :
                                jieqiJu.lower;

    // 4. 起 9 宫地盘干（自然数序流转）
    const diPan = buildDiPan(yinYangDun, juNumber);

    // 5. 计算时干 / 旬首
    const timeGan = pillars.hourGan;
    const xunShou = computeXunShou(pillars.hourGan, pillars.hourZhi);

    // 6. 旋天盘
    const rotation = rotateTianPan(diPan, xunShou, timeGan, yinYangDun);
    const { tianPan, tianJiuxing, zhiFuPalaceId } = rotation;
    const doors = rotateBamen(diPan,xunShou,timeGan,yinYangDun);

    // 7. 排八门 / 九星 / 八神
    const palaces = this.buildPalaces(diPan, tianPan, tianJiuxing, zhiFuPalaceId, yinYangDun, doors.bamen).map(p => ({
      ...p,
      ...(p.id===2 && method.centerPolicy?.startsWith('fixed-kun-2') ? {hostedDiPanGan:diPan.get(5)!} : {}),
      ...(p.id===rotation.tianQinPalaceId ? {hostsTianQin:true,hostedTianPanGan:rotation.hostedTianPanGan} : {}),
    }));

    // 8. 用神 + 应期
    const questionContext = { ...opts.questionContext };
    const selection = qimenQuestionObjects(opts.questionType, questionContext, palaces, {day:pillars.dayGan+pillars.dayZhi,hour:pillars.hourGan+pillars.hourZhi});
    // Legacy summary fields remain readable, but never select one of the new candidates.
    const yongShen = { ...this.selectYongShen(opts.questionType, palaces, timeGan, pillars.dayGan, xunShou, computeXunShou(pillars.dayGan,pillars.dayZhi)), ...selection };
    const yingQi = unresolvedQimenTiming(selection);

    // 9. 格局识别
    const partialChart: QimenChart = {
      question: opts.question,
      questionType: opts.questionType,
      questionContext,
      setupTime: setupTime.toISOString(),
      calculationTime: calculationTime.toISOString(),
      ...(longitude === undefined ? {} : { trueSolarTime: calculationTime.toISOString() }),
      jieqi,
      yinYangDun,
      juNumber,
      yuan,
      palaces,
      yongShen,
      geJu: [] as GeJu[],
      yingQi,
      method,
      fuTou, dayGanZhi:pillars.dayGan+pillars.dayZhi, hourGanZhi:pillars.hourGan+pillars.hourZhi,
      zhiFuStar:rotation.zhiFuStar,zhiFuPalaceId,zhiFuSourcePalaceId:rotation.zhiFuSourcePalaceId,
      zhiShiMen:doors.zhiShiMen,zhiShiPalaceId:doors.zhiShiPalaceId,zhiShiRawPalaceId:doors.zhiShiRawPalaceId,zhiShiSourcePalaceId:doors.zhiShiSourcePalaceId,
      tianQinPalaceId:rotation.tianQinPalaceId,
    };
    const geJu = detectGeJu(partialChart);
    // Month changes at the physical solar-term instant, even on an apparent-solar hour clock.
    const monthGanZhi = getCalendarPillars(setupTime).month;
    const facts=qimenFacts(pillars.hourGan+pillars.hourZhi,monthGanZhi,palaces);
    return { ...partialChart, geJu, monthGanZhi, ...facts, ruleSources:[...facts.ruleSources,QIMEN_QUESTION_SOURCE] };
  }

  /** Rebind references to the saved nine palaces, preserving both original pillar identities. */
  reassessQuestion(original: QimenChart, opts: Pick<SetupOptions, 'question' | 'questionType' | 'questionContext'>): QimenChart {
    const questionContext = opts.questionContext ?? {};
    const day = original.dayGanZhi!, hour = original.hourGanZhi!;
    const selection = qimenQuestionObjects(opts.questionType,questionContext,original.palaces,{day,hour});
    const dayGan = day[0] as TianGan, hourGan = hour[0] as TianGan;
    const yongShen = {...this.selectYongShen(opts.questionType,original.palaces,hourGan,dayGan,
      computeXunShou(hourGan,hour[1]),computeXunShou(dayGan,day[1])),...selection};
    return {...original,question:opts.question,questionType:opts.questionType,questionContext,yongShen,yingQi:unresolvedQimenTiming(selection)};
  }

  /** 按问题类别列出初始参考点，不能据单一同宫关系断吉凶。 */
  private selectYongShen(
    qt: QuestionType,
    palaces: Palace[],
    timeGan: TianGan,
    dayGan: TianGan,
    hourXunShou: TianGan,
    dayXunShou: TianGan,
  ): YongShenAnalysis {
    const rule = YONGSHEN_RULES[qt];
    const targetGan = rule.primaryGan==='day' ? dayGan : timeGan;
    const role = rule.primaryGan==='day' ? '日干参考' : '时干参考';
    const locateStem = (gan:TianGan,xun:TianGan) => {
      const visible = gan==='甲' ? xun : gan;
      return palaces.find(p=>p.id!==5&&(p.tianPanGan===visible||p.hostedTianPanGan===visible));
    };
    const palace=locateStem(targetGan,rule.primaryGan==='day'?dayXunShou:hourXunShou);
    const references: NonNullable<YongShenAnalysis['references']> = [];
    const dayPalace=locateStem(dayGan,dayXunShou),hourPalace=locateStem(timeGan,hourXunShou);
    if(dayPalace) references.push({label:`日干${dayGan}参考`,palaceId:dayPalace.id});
    if(hourPalace) references.push({label:`时干${timeGan}参考`,palaceId:hourPalace.id});
    for(const p of palaces){
      if(rule.secondaryMen&&p.bamen===rule.secondaryMen)references.push({label:rule.secondaryMen,palaceId:p.id});
      if(rule.secondaryShen&&p.bashen===rule.secondaryShen)references.push({label:rule.secondaryShen,palaceId:p.id});
      if(rule.secondaryStar&&p.jiuxing===rule.secondaryStar)references.push({label:rule.secondaryStar,palaceId:p.id});
    }

    if (!palace) {
      throw new Error(`reference stem ${targetGan} missing from outer and hosted plates`);
    }

    // Keep only the legacy single-palace relation; the complete object set is in candidates.
    const state = this.computeYongShenState(targetGan as TianGan, palace);
    const interactions = [`宫位五行判${state}（单处参考，非综合旺衰）`];

    return {
      type: targetGan,
      palaceId: palace.id,
      state,
      summary: `${role}${targetGan}在${palace.name}；未定用`,
      interactions,
      references,
      selectionStatus: 'initial-reference',
    };
  }

  private computeYongShenState(gan: TianGan, palace: Palace): YongShenAnalysis['state'] {
    const ganWx = GAN_WUXING[gan];
    const palaceWx = palace.wuXing;
    if (palaceWx === ganWx) return '旺';
    if (SHENG[palaceWx] === ganWx) return '相';
    if (SHENG[ganWx] === palaceWx) return '休';
    if (KE[ganWx] === palaceWx) return '囚';
    return '死';
  }

  /** 排八门 / 九星 / 八神 */
  private buildPalaces(
    diPan: Map<number, TianGan>,
    tianPan: Map<number, TianGan>,
    tianJiuxing: Map<number, JiuxingName>,
    zhiFuPalaceId: number,
    dun: YinYangDun,
    bamenMap: Map<number,BamenName>,
  ): Palace[] {
    // 直符宫已由 rotateTianPan 算出（= 时干所在地盘宫）。
    // 若直符宫落中 5（时干未上卦边缘场景），降级到坎宫。
    let zhiFuOuter = PALACE_CLOCKWISE_8.includes(zhiFuPalaceId) ? zhiFuPalaceId : 1;

    // 八神：值符神在直符宫，按 BASHEN_ORDER 顺/逆布
    const shenSequence = dun === '阳' ? [...PALACE_CLOCKWISE_8] : [...PALACE_CLOCKWISE_8].reverse();
    const zhiFuIdxInShen = shenSequence.indexOf(zhiFuOuter);
    const bashenMap = new Map<number, BashenName>();
    for (let i = 0; i < 8; i++) {
      const pid = shenSequence[(zhiFuIdxInShen + i) % 8];
      bashenMap.set(pid, BASHEN_ORDER[i]);
    }

    return PALACES_BASE.map(base => ({
      ...base,
      diPanGan: diPan.get(base.id) ?? null,
      tianPanGan: tianPan.get(base.id) ?? null,
      bamen: base.id === 5 ? null : (bamenMap.get(base.id) ?? null),
      // 天盘九星（旋后）；中 5 固定为天禽
      jiuxing: tianJiuxing.get(base.id) ?? JIUXING_DI_PAN_FIXED[base.id],
      bashen: base.id === 5 ? null : (bashenMap.get(base.id) ?? null),
    }));
  }
}
