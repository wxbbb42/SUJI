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
  QuestionType, YongShenAnalysis, YingQiAnalysis, QimenMethodMeta,
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

const QIMEN_METHOD: QimenMethodMeta = {
  level: 'standard',
  algorithm: 'zhuanpan-qimen-chai-bu-v1',
  centerPolicy: 'fixed-kun-2; tian-qin-follows-tian-rui',
  solarTermClock: 'physical-instant',
  caveats: [
    '采用拆补法和中五固定寄坤二，不混用置闰法或阴阳分寄法',
    '用神按问题类别初选；旺衰仅为宫位五行关系，应期证据不足时不报期限',
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
    const palaces = this.buildPalaces(diPan, tianPan, tianJiuxing, zhiFuPalaceId, yinYangDun, doors.bamen).map(p => ({...p, ...(p.id===rotation.tianQinPalaceId ? {hostsTianQin:true,hostedTianPanGan:rotation.hostedTianPanGan} : {})}));

    // 8. 用神 + 应期
    const yongShen = this.selectYongShen(opts.questionType, palaces, timeGan, pillars.dayGan, xunShou, computeXunShou(pillars.dayGan,pillars.dayZhi));
    const yingQi = this.computeYingQi(yongShen);

    // 9. 格局识别
    const partialChart: QimenChart = {
      question: opts.question,
      questionType: opts.questionType,
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

    return { ...partialChart, geJu };
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
    const role = rule.primaryGan==='day' ? '求问者（日干）' : '所问之事（时干）';
    const locateStem = (gan:TianGan,xun:TianGan) => {
      const visible = gan==='甲' ? xun : gan;
      return palaces.find(p=>p.id!==5&&(p.tianPanGan===visible||p.hostedTianPanGan===visible));
    };
    const palace=locateStem(targetGan,rule.primaryGan==='day'?dayXunShou:hourXunShou);
    const references: NonNullable<YongShenAnalysis['references']> = [];
    const dayPalace=locateStem(dayGan,dayXunShou),hourPalace=locateStem(timeGan,hourXunShou);
    if(dayPalace) references.push({label:`求问者（日干${dayGan}）`,palaceId:dayPalace.id});
    if(hourPalace) references.push({label:`所问之事（时干${timeGan}）`,palaceId:hourPalace.id});
    for(const p of palaces){
      if(rule.secondaryMen&&p.bamen===rule.secondaryMen)references.push({label:rule.secondaryMen,palaceId:p.id});
      if(rule.secondaryShen&&p.bashen===rule.secondaryShen)references.push({label:rule.secondaryShen,palaceId:p.id});
      if(rule.secondaryStar&&p.jiuxing===rule.secondaryStar)references.push({label:rule.secondaryStar,palaceId:p.id});
    }

    if (!palace) {
      throw new Error(`reference stem ${targetGan} missing from outer and hosted plates`);
    }

    // 记录门 / 神 / 星是否同宫，不计算虚构的分数。
    const interactions: string[] = [rule.description,'这些位置是取象参考点，不是最终用神裁定或吉凶结论'];
    if (rule.secondaryMen && palace.bamen === rule.secondaryMen) {
      interactions.push(`临${rule.secondaryMen}（同宫参考）`);
    }
    if (rule.secondaryShen && palace.bashen === rule.secondaryShen) {
      interactions.push(`临${rule.secondaryShen}（同宫参考）`);
    }
    if (rule.secondaryStar && palace.jiuxing === rule.secondaryStar) {
      interactions.push(`临${rule.secondaryStar}星（同宫参考）`);
    }
    const state = this.computeYongShenState(targetGan as TianGan, palace);
    interactions.unshift(`宫位五行判${state}`);

    return {
      type: targetGan,
      palaceId: palace.id,
      state,
      summary: `${role}${targetGan}临${palace.name}，${state}（${palace.bamen ?? '无门'} · ${palace.jiuxing} · ${palace.bashen ?? '无神'}）`,
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

  /** 应期推算（MVP 简化） */
  private computeYingQi(yongShen: YongShenAnalysis): YingQiAnalysis {
    if (yongShen.state === '不上卦') {
      return {
        description: '用神不上卦，应期难定',
        factors: ['用神未在 9 宫显现'],
      };
    }
    return {
      description: '尚不能确定应期；需明确事件条件，并综合空亡、动静与应期规则',
      factors: [`用神：${yongShen.summary}`, '当前取用与宫位关系不足以推出具体期限'],
    };
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
