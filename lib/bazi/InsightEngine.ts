/**
 * 岁吉 · 洞察翻译层
 *
 * 将 BaziEngine / DayunEngine 产出的命理术语
 * 转化为用户可感知的现代心理学语言。
 *
 * 理论映射依据：REFERENCES.ts §3.2 心理学视角
 *   十神 ↔ Big Five 人格维度
 *   大运流年 ↔ Erikson/Levinson 生命周期理论
 */

import type {
  MingPan,
  PersonalityInsight,
  TimingInsight,
  DailyInsight,
  ShiShen,
  WuXing,
  TianGan,
  DiZhi,
} from './types';
import { DayunEngine } from './DayunEngine';

// ── 十神 → 现代语言特质映射（REFERENCES.ts §3.2 Big Five 映射）──────
const SHISHEN_TRAITS: Record<
  ShiShen,
  { traits: string[]; strengths: string[]; challenges: string[] }
> = {
  比肩: {
    traits: ['独立自主', '自我意识强', '有主见'],
    strengths: ['能坚持自己的方向', '有强烈的个人风格'],
    challenges: ['有时固执，不易妥协', '独自扛事的习惯让人难以靠近'],
  },
  劫财: {
    traits: ['竞争意识强', '行动力足', '有魄力'],
    strengths: ['在竞争中能脱颖而出', '执行力强，说做就做'],
    challenges: ['容易与人产生争执', '冲动行事容易后悔'],
  },
  食神: {
    traits: ['创造力丰富', '善于表达', '享受生活'],
    strengths: ['有艺术天赋', '能把内心感受转化为有价值的东西'],
    challenges: ['有时过于随性，缺乏紧迫感', '容易沉浸舒适区'],
  },
  伤官: {
    traits: ['思想前卫', '表达能力强', '不拘一格'],
    strengths: ['创新突破能力强', '才华横溢且独树一帜'],
    challenges: ['内心有打破常规的冲动，在体制内易感压抑', '情绪化表达有时会引起误会'],
  },
  偏财: {
    traits: ['社交能力强', '对机会敏感', '灵活变通'],
    strengths: ['善于把握时机，人脉资源丰富', '在流动变化中如鱼得水'],
    challenges: ['情感上有时不够专一', '精力分散，难以深耕一件事'],
  },
  正财: {
    traits: ['务实稳健', '规划性强', '踏实勤奋'],
    strengths: ['资源管理能力强，财务规划有序', '言出必行，值得信赖'],
    challenges: ['有时过于保守，错过弹性机会', '对不确定性容忍度低'],
  },
  七杀: {
    traits: ['抗压能力强', '果断', '适合挑战'],
    strengths: ['天生在压力中成长', '有感召力，能带领团队冲破困境'],
    challenges: ['高压状态下容易焦虑', '与权威关系容易紧张'],
  },
  正官: {
    traits: ['秩序感强', '有责任心', '规则意识强'],
    strengths: ['可靠守信，在体制内发展好', '有很强的道德感和使命感'],
    challenges: ['对不确定性的容忍度偏低', '变化快时容易感到不适'],
  },
  偏印: {
    traits: ['思维独特', '内省深度强', '有精神追求'],
    strengths: ['学习能力强，思维深邃', '对知识和灵性有天然的热情'],
    challenges: ['有时孤僻，难以融入主流节奏', '过度内省时容易陷入自我怀疑'],
  },
  正印: {
    traits: ['学习能力强', '善于思考', '内心丰富'],
    strengths: ['有强大的支持系统，智慧型人格', '善于积累和传递知识'],
    challenges: ['行动力偶尔不足，思考多于行动', '依赖外部认可'],
  },
};

// ── 格局名 → 现代语言解读（REFERENCES.ts §4 映射表）───────────────
const GEJU_MODERN: Partial<Record<string, string>> = {
  正官格: '你有很强的秩序感和责任心，适合在有规则有目标的环境中发光',
  七杀格: '你天生适合在压力中成长，越是挑战越能激发你的潜能',
  食神格: '你有丰富的创造力和表达天赋，能把内心感受转化为实际价值',
  伤官格: '你内心有一种打破常规的冲动，适合在创新领域施展才华',
  偏财格: '你对机会的嗅觉很灵敏，善于在流动变化中抓住资源',
  正财格: '你踏实稳健，有强大的资源管理能力，财富往往通过持续努力积累',
  偏印格: '你有深刻的思维和精神追求，适合在知识、艺术领域深耕',
  正印格: '你有很强的学习能力和思考深度，身边往往有支持你的力量',
  食神生财: '你能把想法变成实际收获，创意和才华都能为你带来回报',
  比肩格: '你知道自己要什么，有强烈的自我意识和独立精神',
  从强格: '你个性鲜明，专注于自我成长，最适合独当一面的领域',
  从财格: '你擅长顺势而为，在资源丰富的环境中如鱼得水',
  从官杀格: '你有很强的适应能力，能在权威环境中找到自己的定位',
  从儿格: '你的创造力和表达欲极为旺盛，艺术与创作是你的天赋领域',
};

// ── 格局 → 职业倾向 ────────────────────────────────────────────────
const GEJU_CAREER: Partial<Record<string, string[]>> = {
  正官格: ['管理与领导', '公共事业', '法律与合规'],
  七杀格: ['创业与挑战性工作', '军事与安全', '高压决策领域'],
  食神格: ['艺术与创作', '美食与生活方式', '教育与传播'],
  伤官格: ['创新与研发', '艺术表演', '咨询与顾问'],
  偏财格: ['商业与贸易', '销售与市场', '金融投资'],
  正财格: ['财务与会计', '稳健型创业', '实体产业'],
  偏印格: ['研究与学术', '心理与咨询', '灵性与哲学'],
  正印格: ['教育与学术', '文化与出版', '医疗与关爱'],
  食神生财: ['创意变现', '内容创业', '设计与商业结合'],
};

// ── 五行 → 职业倾向补充 ────────────────────────────────────────────
const WUXING_CAREER: Record<WuXing, string[]> = {
  木: ['规划与战略', '环保与自然领域'],
  火: ['媒体与传播', '品牌与营销'],
  土: ['房地产与建筑', '农业与食品'],
  金: ['科技与工程', '金融与制造'],
  水: ['互联网与数据', '哲学与心理'],
};

// ── 五行 → 有利颜色 / 方位 / 数字 ────────────────────────────────
const WUXING_LUCKY: Record<WuXing, { colors: string[]; directions: string[]; numbers: number[] }> = {
  木: { colors: ['绿色', '青色', '翠绿'], directions: ['东方', '东南'], numbers: [3, 8] },
  火: { colors: ['红色', '橙色', '紫色'], directions: ['南方'],           numbers: [2, 7] },
  土: { colors: ['黄色', '米色', '棕色'], directions: ['中央', '西南'],   numbers: [5, 0] },
  金: { colors: ['白色', '金色', '银色'], directions: ['西方', '西北'],   numbers: [4, 9] },
  水: { colors: ['黑色', '深蓝', '灰色'], directions: ['北方'],           numbers: [1, 6] },
};

// ── 用神五行 → 吉时地支 ──────────────────────────────────────────
const WUXING_ZHI: Record<WuXing, DiZhi[]> = {
  木: ['寅', '卯'],
  火: ['巳', '午'],
  土: ['辰', '未', '戌', '丑'],
  金: ['申', '酉'],
  水: ['子', '亥'],
};

// ── 地支 → 时间段 ─────────────────────────────────────────────────
const ZHI_HOUR: Record<DiZhi, string> = {
  子: '23:00–01:00', 丑: '01:00–03:00', 寅: '03:00–05:00', 卯: '05:00–07:00',
  辰: '07:00–09:00', 巳: '09:00–11:00', 午: '11:00–13:00', 未: '13:00–15:00',
  申: '15:00–17:00', 酉: '17:00–19:00', 戌: '19:00–21:00', 亥: '21:00–23:00',
};

// ── 日柱干支推算常量 ─────────────────────────────────────────────────
// 参考点：2000-01-01 本地时间 = 甲戌日，60 甲子循环索引 10
// 甲(idx=0)·戌(idx=10) → 10%10=0 ✓  10%12=10 ✓
const TIAN_GAN: TianGan[] = ['甲', '乙', '丙', '丁', '戊', '己', '庚', '辛', '壬', '癸'];
const DI_ZHI: DiZhi[]     = ['子', '丑', '寅', '卯', '辰', '巳', '午', '未', '申', '酉', '戌', '亥'];
const GAN_WUXING: Record<TianGan, WuXing> = {
  甲: '木', 乙: '木', 丙: '火', 丁: '火', 戊: '土',
  己: '土', 庚: '金', 辛: '金', 壬: '水', 癸: '水',
};
const ZHI_WUXING: Record<DiZhi, WuXing> = {
  子: '水', 丑: '土', 寅: '木', 卯: '木', 辰: '土', 巳: '火',
  午: '火', 未: '土', 申: '金', 酉: '金', 戌: '土', 亥: '水',
};

const DAY_REF_LOCAL = new Date(2000, 0, 1).getTime(); // 本地时间 2000-01-01
const DAY_REF_CYCLE = 10;                             // 甲戌日

/** 将日期转为日柱干支信息 */
function dateToDayGanZhi(date: Date): {
  ganZhiStr: string;
  ganWx: WuXing;
  zhiWx: WuXing;
  zhi: DiZhi;
} {
  // 取当天正午，规避夏令时边界问题
  const noon  = new Date(date.getFullYear(), date.getMonth(), date.getDate(), 12).getTime();
  const days  = Math.round((noon - DAY_REF_LOCAL) / 86400000);
  const cycle = ((days + DAY_REF_CYCLE) % 60 + 60) % 60;
  const gan   = TIAN_GAN[cycle % 10];
  const zhi   = DI_ZHI[cycle % 12];
  return { ganZhiStr: `${gan}${zhi}`, ganWx: GAN_WUXING[gan], zhiWx: ZHI_WUXING[zhi], zhi };
}

/** 当日能量等级（基于用神喜忌评分） */
function dailyEnergyLevel(
  ganWx: WuXing,
  zhiWx: WuXing,
  yongShen: WuXing,
  xiShen: WuXing,
  jiShen: WuXing,
): '高' | '中' | '低' {
  let score = 0;
  if (ganWx === yongShen || zhiWx === yongShen) score += 2;
  if (ganWx === xiShen   || zhiWx === xiShen)   score += 1;
  if (ganWx === jiShen   || zhiWx === jiShen)   score -= 2;
  return score >= 2 ? '高' : score <= -2 ? '低' : '中';
}

// ════════════════════════════════════════════════════════════════════
// InsightEngine
// ════════════════════════════════════════════════════════════════════

export class InsightEngine {
  private readonly mingPan: MingPan;
  private readonly dayunEngine: DayunEngine;

  constructor(mingPan: MingPan) {
    this.mingPan     = mingPan;
    this.dayunEngine = new DayunEngine(mingPan);
  }

  // ──────────────────────────────────────────────────────────────────
  // 人格洞察
  // ──────────────────────────────────────────────────────────────────

  getPersonalityInsight(): PersonalityInsight {
    const { geJu, riZhu, wuXingStrength, siZhu, shenSha } = this.mingPan;
    const monthShiShen = siZhu.month.shiShen;
    const monthInfo    = SHISHEN_TRAITS[monthShiShen];

    // — 核心特质 ——————————————————————————————————————————————————
    const coreTraits: string[] = [];

    coreTraits.push(
      wuXingStrength.riZhuStrong
        ? '你是那种知道自己要什么的人，有强烈的自我驱动力'
        : '你擅长在环境中找到自己的位置，适应力和感知力是你的天赋',
    );

    const geJuDesc = GEJU_MODERN[geJu.name] ?? geJu.modernMeaning;
    if (geJuDesc) coreTraits.push(geJuDesc);

    coreTraits.push(...monthInfo.traits.slice(0, 2).map(t => `天生具有${t}的特质`));

    // — 优势 ————————————————————————————————————————————————————————
    const strengths: string[] = [...monthInfo.strengths];

    for (const ss of shenSha) {
      if (ss.type === '吉' && ss.modernMeaning) strengths.push(ss.modernMeaning);
    }
    strengths.push(this.wuXingPersonalStrength(wuXingStrength.yongShen));

    // — 挑战 ————————————————————————————————————————————————————————
    const challenges: string[] = [...monthInfo.challenges];

    const geJuChallenge = this.geJuChallenge(geJu.name);
    if (geJuChallenge) challenges.push(geJuChallenge);
    challenges.push(this.wuXingPersonalChallenge(wuXingStrength.jiShen));

    // — 其他维度 ————————————————————————————————————————————————————
    const communicationStyle = this.communicationStyle(siZhu.day.shiShen, riZhu.wuXing);
    const emotionalPattern   = this.emotionalPattern(riZhu.wuXing, wuXingStrength.riZhuStrong);
    const careerAptitude     = this.careerAptitude(geJu.name, riZhu.wuXing);
    const relationshipStyle  = this.relationshipStyle(siZhu, this.mingPan.gender, wuXingStrength.riZhuStrong);

    return {
      coreTraits:        dedup(coreTraits).slice(0, 5),
      strengths:         dedup(strengths).slice(0, 5),
      challenges:        dedup(challenges).slice(0, 4),
      communicationStyle,
      emotionalPattern,
      careerAptitude:    careerAptitude.slice(0, 5),
      relationshipStyle,
    };
  }

  // ──────────────────────────────────────────────────────────────────
  // 时运洞察
  // ──────────────────────────────────────────────────────────────────

  getTimingInsight(year: number): TimingInsight {
    const birthYear = this.mingPan.birthDateTime.getFullYear();
    const age       = year - birthYear;
    const forecast  = this.dayunEngine.getYearForecast(year);
    const { liuNian, overallTrend } = forecast;

    const currentPhase  = this.currentPhaseDesc(age, overallTrend);
    const currentEnergy = this.currentEnergyDesc(overallTrend);

    // 机遇方向
    const opportunities: string[] = [
      this.translateCareer(forecast.careerOutlook),
      this.translateWealth(forecast.wealthOutlook),
    ];
    if (forecast.relationshipOutlook.includes('缘分') || forecast.relationshipOutlook.includes('深化')) {
      opportunities.push('感情与人际关系上有新的连接机会');
    }
    if (overallTrend === '逆' && opportunities.length < 2) {
      opportunities.push('专注自我积累与能力提升，为下一个顺势期做准备');
    }

    // 注意事项
    const watchouts: string[] = [];
    if (overallTrend === '逆') {
      watchouts.push('这段时间外部阻力较多，重大决策宜缓行');
      watchouts.push(this.translateHealth(forecast.healthOutlook));
    } else if (overallTrend === '平') {
      watchouts.push('保持稳健，不要被短暂的机会冲昏头脑');
      watchouts.push('重大变动前多做调研，不急于下结论');
    } else {
      watchouts.push('顺势期容易忽视风险，保持清醒的判断力');
    }
    if (liuNian.interactions.some(i => i.includes('忌神'))) {
      watchouts.push('今年某些方面需要额外耐心，顺势而为好过强行突破');
    }

    const advice    = this.translateAdvice(forecast.keyAdvice);
    const luckyWx   = this.mingPan.wuXingStrength.yongShen;
    const luckyElements = {
      colors:     WUXING_LUCKY[luckyWx].colors,
      directions: WUXING_LUCKY[luckyWx].directions,
      numbers:    WUXING_LUCKY[luckyWx].numbers,
    };

    return {
      currentPhase,
      currentEnergy,
      opportunities: dedup(opportunities).slice(0, 3),
      watchouts:     dedup(watchouts).slice(0, 3),
      advice,
      luckyElements,
    };
  }

  // ──────────────────────────────────────────────────────────────────
  // 每日洞察
  // ──────────────────────────────────────────────────────────────────

  getDailyInsight(date: Date): DailyInsight {
    const { yongShen, xiShen, jiShen } = this.mingPan.wuXingStrength;
    const { ganZhiStr, ganWx, zhiWx, zhi } = dateToDayGanZhi(date);

    const overallEnergy = dailyEnergyLevel(ganWx, zhiWx, yongShen, xiShen, jiShen);
    const focusArea     = this.dailyFocusArea(ganWx, overallEnergy);
    const advice        = this.dailyAdvice(overallEnergy, ganWx, yongShen);
    const avoidance     = this.dailyAvoidance(overallEnergy, zhiWx, jiShen);

    // 吉时：用神 + 喜神对应时辰
    const luckyZhi: DiZhi[] = [...WUXING_ZHI[yongShen], ...WUXING_ZHI[xiShen]];
    const luckyHours = dedup(luckyZhi).map(z => ZHI_HOUR[z]).slice(0, 3);

    const affirmation = this.dailyAffirmation(overallEnergy, this.mingPan.riZhu.wuXing);
    const dateStr     = date.toLocaleDateString('zh-CN', {
      year: 'numeric', month: 'long', day: 'numeric',
    });

    return {
      date: dateStr,
      ganZhi: ganZhiStr,
      overallEnergy,
      focusArea,
      advice,
      avoidance,
      luckyHours,
      affirmation,
    };
  }

  // ════════════════════════════════════════════════════════════════════
  // § 私有辅助 — 人格
  // ════════════════════════════════════════════════════════════════════

  private wuXingPersonalStrength(wx: WuXing): string {
    const map: Record<WuXing, string> = {
      木: '你有很强的成长驱动力，能在逆境中保持韧性',
      火: '你的热情和感染力是天然的领导资本',
      土: '你的稳定感和包容心让人有安全感',
      金: '你做事果断精准，执行力是你的核心竞争力',
      水: '你的直觉和洞察力让你总能看透本质',
    };
    return map[wx];
  }

  private wuXingPersonalChallenge(wx: WuXing): string {
    const map: Record<WuXing, string> = {
      木: '有时会因为急于成长而忽略脚下的稳定',
      火: '情绪波动时容易能量过激，需要学会收放',
      土: '过于依赖稳定感，可能错过需要灵活变通的机会',
      金: '完美主义倾向有时会成为前进的阻力',
      水: '思维过度活跃时容易焦虑，需要给自己一个锚点',
    };
    return map[wx];
  }

  private communicationStyle(dayShiShen: ShiShen, riWx: WuXing): string {
    const base: Record<WuXing, string> = {
      木: '你表达直接，思路清晰，善于用逻辑说服人',
      火: '你充满热情，沟通富有感染力，容易带动他人情绪',
      土: '你说话稳重踏实，让人感到可靠与安心',
      金: '你逻辑清晰，言简意赅，讲究原则与效率',
      水: '你善于倾听，能察言观色，沟通时灵活变通',
    };
    let style = base[riWx];
    if (dayShiShen === '食神' || dayShiShen === '伤官') {
      style += '，同时你的语言有很强的创意感，能把复杂的事情讲得生动有趣';
    } else if (dayShiShen === '正官' || dayShiShen === '七杀') {
      style += '，在重要场合你善于清晰表达立场，令人信服';
    }
    return style;
  }

  private emotionalPattern(riWx: WuXing, strong: boolean): string {
    const patterns: Record<WuXing, [string, string]> = {
      木: [
        '你情感充沛，目标感强，内心有一股向上的力量，但有时难以彻底放松',
        '你情感细腻，容易被外界触动，需要稳定的情感环境来滋养自己',
      ],
      火: [
        '你情绪来得快去得也快，热情时如火，但期待落空时落差感会比较强',
        '你内心渴望与外在稳定之间常有张力，学会表达感受比压抑更健康',
      ],
      土: [
        '你情绪稳定，不易被打动，但偶尔会因过于压制感受而感到沉重',
        '你重视安全感，在稳定的关系中才能充分放松和展示自己',
      ],
      金: [
        '你对自己的情绪管理很严格，理性压过感性，有时会显得距离感较强',
        '你内心敏感但外表坚硬，允许自己偶尔脆弱会让关系更深入',
      ],
      水: [
        '你情感流动性强，思维活跃，容易同时承载多种情绪，需要适时清空内心',
        '你善于感受他人情绪，有时边界不够清晰，需要保护自己的能量',
      ],
    };
    return patterns[riWx][strong ? 0 : 1];
  }

  private careerAptitude(geJuName: string, riWx: WuXing): string[] {
    const geJuList = GEJU_CAREER[geJuName] ?? [];
    const wxList   = WUXING_CAREER[riWx];
    return dedup([...geJuList, ...wxList]);
  }

  private relationshipStyle(
    siZhu: MingPan['siZhu'],
    gender: '男' | '女',
    strong: boolean,
  ): string {
    const dayZhiShenList = siZhu.day.cangGan.map(c => c.shiShen);
    const hasExpressive  = (['食神', '伤官'] as ShiShen[]).some(s => dayZhiShenList.includes(s));

    if (strong) {
      return hasExpressive
        ? '你在感情中有很强的吸引力，但也有自己的原则——你愿意付出，但不会失去自我'
        : '你在关系中有主导倾向，需要另一半给你足够的空间，同时也欣赏你的强度';
    }
    return gender === '男'
      ? '你在感情中细腻体贴，善于照顾对方感受，记得在付出的同时也照顾好自己的需求'
      : '你在感情中善于感知和配合，会为关系做很多调整，同时也值得被同等珍视';
  }

  private geJuChallenge(geJuName: string): string {
    const map: Partial<Record<string, string>> = {
      七杀格:   '高压状态下容易焦虑，需要学会适时放松和充电',
      伤官格:   '对规则的抗拒有时会带来不必要的摩擦，需要找到创新与合作的平衡点',
      劫财格:   '竞争心过强时容易忽视合作的价值',
      正官格:   '对不确定性的容忍度偏低，环境变化快时可能感到不适',
      偏印格:   '思维过于内省时容易陷入自我怀疑，多与外界连接有助于落地',
      官杀混杂: '你可能同时面对多个方向的期待，学会设立优先级很重要',
    };
    return map[geJuName] ?? '';
  }

  // ════════════════════════════════════════════════════════════════════
  // § 私有辅助 — 时运
  // ════════════════════════════════════════════════════════════════════

  private currentPhaseDesc(age: number, trend: '顺' | '平' | '逆'): string {
    let stage: string;
    if      (age < 25) stage = '人生探索与自我发现的阶段';
    else if (age < 35) stage = '建立基础与积累资源的阶段';
    else if (age < 45) stage = '深耕专业与扩展影响力的阶段';
    else if (age < 55) stage = '收获与传承的人生中期';
    else if (age < 65) stage = '整合过往、享受成果的阶段';
    else               stage = '智慧沉淀与轻盈生活的阶段';

    const trendDesc = {
      顺: '整体能量顺畅，是主动出击的好时机',
      平: '运势平稳，稳中求进是最佳策略',
      逆: '外部阻力较多，宜修炼内功、等待时机',
    }[trend];

    return `你目前处于${stage}，${trendDesc}。`;
  }

  private currentEnergyDesc(trend: '顺' | '平' | '逆'): string {
    if (trend === '顺') return '你现在的状态像是风帆满张，整体能量充沛，外部环境对你的行动有支撑作用';
    if (trend === '逆') return '现在的能量场更适合内部整合，不必强行突破，把精力放在巩固和修复上';
    return '目前能量处于平稳状态，日常推进问题不大，重大突破需要更多蓄力';
  }

  private translateCareer(outlook: string): string {
    if (outlook.includes('晋升') || outlook.includes('突破')) return '职业发展有新的晋升或突破机会，值得积极争取';
    if (outlook.includes('顺畅') || outlook.includes('顺'))  return '工作推进顺畅，适合开展新项目或拓展合作';
    if (outlook.includes('激烈') || outlook.includes('逆'))  return '职场竞争较激烈，专注本职、减少内耗是上策';
    return '事业稳步推进，维护好现有的合作关系';
  }

  private translateWealth(outlook: string): string {
    if (outlook.includes('积累') || outlook.includes('增长')) return '收入有增长空间，可考虑稳健的资产配置';
    if (outlook.includes('投资') || outlook.includes('机会')) return '财务方面有良好机遇，可适度把握';
    if (outlook.includes('损耗') || outlook.includes('逆'))  return '财务保持保守，避免高风险操作';
    return '财运平稳，量入为出，做好长期规划';
  }

  private translateHealth(outlook: string): string {
    const match = outlook.match(/注意([^，。，、]+)/);
    if (match) return `身体方面注意${match[1]}，保持规律作息和适度运动`;
    return '注意身体状态，规律的作息和运动是最好的投资';
  }

  private translateAdvice(keyAdvice: string): string {
    if (keyAdvice.includes('把握机遇') || keyAdvice.includes('大胆推进')) {
      return '这是一个值得主动出击的阶段，心中有的目标可以大胆推进，别让犹豫错过窗口';
    }
    if (keyAdvice.includes('稳中求进') || keyAdvice.includes('夯实基础')) {
      return '不必急于求成，把基础打好，机会会自然到来——持续比速度更重要';
    }
    if (keyAdvice.includes('以守为主') || keyAdvice.includes('减少冒进')) {
      return '学会在安静中积蓄力量，减少不必要的消耗，等待更好的时机再发力';
    }
    return keyAdvice;
  }

  // ════════════════════════════════════════════════════════════════════
  // § 私有辅助 — 每日
  // ════════════════════════════════════════════════════════════════════

  private dailyFocusArea(ganWx: WuXing, energy: '高' | '中' | '低'): string {
    if (energy === '低') return '休息与自我照顾';
    const focus: Record<WuXing, string> = {
      木: '成长、学习与规划',
      火: '创意、表达与人际连接',
      土: '落地执行与整理',
      金: '决策、精准行动与收尾',
      水: '直觉感知、思考与沟通',
    };
    return focus[ganWx];
  }

  private dailyAdvice(energy: '高' | '中' | '低', ganWx: WuXing, yongShen: WuXing): string {
    if (energy === '高') return '今天能量充沛，适合推进重要事项、做关键决定或启动新计划';
    if (energy === '低') return '今天能量偏低，建议以恢复为主，做轻松的事，减少消耗性社交';
    if (ganWx === yongShen) return '今天有隐性助力，稳步推进日常事务，专注当下每一个小目标';
    return '今天适合平稳推进，不必强求突破，保持节奏比速度更重要';
  }

  private dailyAvoidance(energy: '高' | '中' | '低', zhiWx: WuXing, jiShen: WuXing): string {
    if (energy === '低')   return '避免过度消耗自己，减少高强度决策和冲突性对话';
    if (zhiWx === jiShen) return '注意今天外部环境有些阻力，避免强行推进已经卡住的事情';
    if (energy === '高')   return '避免因状态太好而冲动行事，决策前依然保持冷静判断';
    return '避免今天做无把握的冒险，已有计划比新想法更值得优先执行';
  }

  private dailyAffirmation(energy: '高' | '中' | '低', riWx: WuXing): string {
    const affirmations: Record<WuXing, Record<'高' | '中' | '低', string>> = {
      木: {
        高: '我充满生机，每一步都在向光的方向成长。',
        中: '我踏实地走着，每一天都是有意义的积累。',
        低: '休息是为了更好地出发，我允许自己慢下来。',
      },
      火: {
        高: '我的热情是最真实的礼物，今天我全情投入。',
        中: '我的光芒不依赖外部条件，内心有一团稳定的火。',
        低: '即使安静，我依然是温暖的存在。',
      },
      土: {
        高: '我稳稳承载着一切，这份力量让我值得信赖。',
        中: '我的价值不在于快，而在于持续和可靠。',
        低: '大地需要雨水滋养，我今天选择接受照顾。',
      },
      金: {
        高: '我清晰、果断，今天我做出的每个选择都是最好的版本。',
        中: '精准比完美更重要，我专注于最关键的那件事。',
        低: '磨砺需要时间，我的锋芒在沉淀中更显光华。',
      },
      水: {
        高: '我的流动与智慧带我到达需要去的地方。',
        中: '我信任自己的直觉，它总是指向对的方向。',
        低: '深水需要静止才能清澈，我给自己这份宁静。',
      },
    };
    return affirmations[riWx][energy];
  }
}

// ── 工具函数 ─────────────────────────────────────────────────────────

function dedup<T>(arr: T[]): T[] {
  return [...new Set(arr)];
}
