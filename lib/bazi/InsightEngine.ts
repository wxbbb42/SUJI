/**
 * 岁吉 · 洞察翻译层
 *
 * 设计哲学（Polanyi Tacit Knowledge）：
 *   将全部命理术语在此层翻译为现代心理学语言，
 *   上层调用者只接触"人话"，不感知任何八字术语。
 *
 * 映射来源：REFERENCES.ts §四「传统术语 → 现代语言」映射表
 * 理论背书：Big Five 人格理论 / Erikson-Levinson 生命周期理论 / 中医五脏五行
 */

import type {
  TianGan, DiZhi, WuXing, ShiShen,
  GanZhi, MingPan,
  PersonalityInsight, TimingInsight, DailyInsight,
} from './types';
import { DayunEngine } from './DayunEngine';

// ─────────────────────────────────────────────────────────────────
// 每日甲子基准（1900-01-31 = 甲子日，序号 0）
// 来源：《三命通会》纳音五行表 + 历法推算
// ─────────────────────────────────────────────────────────────────
const DAY_BASE = new Date(1900, 0, 31).getTime();

/**
 * 洞察翻译层
 *
 * 接收已排好的 MingPan，输出三类面向用户的洞察：
 *   - PersonalityInsight  人格洞察（静态，基于命盘本身）
 *   - TimingInsight       时运洞察（动态，基于大运流年）
 *   - DailyInsight        每日洞察（基于日柱干支）
 *
 * @example
 * ```ts
 * const engine = new InsightEngine(mingPan);
 * const personality = engine.getPersonalityInsight();
 * const timing      = engine.getTimingInsight(2026);
 * const daily       = engine.getDailyInsight(new Date());
 * ```
 */
export class InsightEngine {
  private readonly mingPan: MingPan;
  private readonly dayunEngine: DayunEngine;

  // ═══════════════════════════════════════════
  // § 传统术语 → 现代语言映射表（REFERENCES.ts §四）
  // ═══════════════════════════════════════════

  /**
   * 十神 → 人格维度（Big Five 映射）
   * 来源：REFERENCES.ts 3.2 心理学视角
   */
  private static readonly SHISHEN_PROFILE: Record<ShiShen, {
    trait: string;
    strength: string;
    challenge: string;
    career: string;
    relationStyle: string;
  }> = {
    比肩: {
      trait:        '独立自主，竞争意识强，你是那种知道自己要什么的人',
      strength:     '自我驱动力强，不依赖他人也能推进事情',
      challenge:    '合作时容易显得强势，需给他人更多空间',
      career:       '创业者、独立顾问、体育竞技、个人品牌',
      relationStyle:'倾向平等伙伴关系，珍视独立空间',
    },
    劫财: {
      trait:        '果断魄力，胆识过人，做决定很果断',
      strength:     '行动力是你最大的资产，魄力十足',
      challenge:    '财务决策需要更谨慎，避免冲动',
      career:       '销售、投资、竞争性行业、危机管理',
      relationStyle:'关系中竞争意识较强，需给彼此留呼吸空间',
    },
    食神: {
      trait:        '你有很强的创造力和表达天赋，能把想法变成实际收获',
      strength:     '才华自然流露，生活品质感强',
      challenge:    '过于享受当下，有时缺乏紧迫感',
      career:       '艺术创作、美食、设计、教育、内容创作',
      relationStyle:'在关系中滋养他人，通过付出和创造获得满足',
    },
    伤官: {
      trait:        '才华横溢，你内心有一种打破常规的冲动',
      strength:     '独特视角与创新能力，不受框架束缚',
      challenge:    '与权威的摩擦，才华的出口需要选对场合',
      career:       '创意产业、研发、表演艺术、独立媒体',
      relationStyle:'对关系标准高，不接受将就，真诚才能真正打动你',
    },
    偏财: {
      trait:        '你对机会的嗅觉很灵敏，社交能力强',
      strength:     '善于把握意外机遇，人脉广博',
      challenge:    '容易分散注意力，需要培养专注力',
      career:       '商业、公关、投资、贸易、自由职业',
      relationStyle:'关系广博，善于营造轻松氛围，有多方情感体验',
    },
    正财: {
      trait:        '踏实务实，对资源管理有天赋',
      strength:     '脚踏实地，长期规划见成效',
      challenge:    '风险承受度偏低，可能错失高回报机会',
      career:       '财务、会计、稳健型商业、行政管理',
      relationStyle:'稳定忠诚，将伴侣视为重要的安全感来源',
    },
    七杀: {
      trait:        '你天生适合在压力中成长，越挑战越有动力',
      strength:     '抗压能力极强，能在逆境中爆发潜能',
      challenge:    '压力过大时容易焦虑或做出冲动决策',
      career:       '军警、外科医生、竞技运动、挑战性管理岗',
      relationStyle:'关系中张力大，激情与冲突并存，磁场强烈',
    },
    正官: {
      trait:        '你有很强的秩序感和责任心，在体制内如鱼得水',
      strength:     '值得信赖，长期主义是你的核心优势',
      challenge:    '有时过于拘谨，创新突破感到阻力',
      career:       '政府、大型企业、法律、行政、教育机构',
      relationStyle:'对关系负责任，重视承诺，适合稳定的长期伴侣',
    },
    偏印: {
      trait:        '你有独特的专业视角，研究型思维是你的核心竞争力',
      strength:     '深度专业能力，独立研究型思考',
      challenge:    '有时过于内敛，不擅长自我营销',
      career:       '科研、技术专家、哲学、心理咨询、玄学专业',
      relationStyle:'在关系中保持一定距离感，重视精神层面的契合',
    },
    正印: {
      trait:        '你有很强的学习能力和思考深度，身边有支持你的力量',
      strength:     '强大的学习吸收能力，贵人运旺',
      challenge:    '决策时可能过于依赖他人意见，需信任自己',
      career:       '学术、教育、咨询、医疗、公益',
      relationStyle:'依赖感较强，重视被关怀，倾向长辈或导师式情感连接',
    },
  };

  /** 日主天干 → 沟通风格（《滴天髓》日元论） */
  private static readonly RI_GAN_COMM: Record<TianGan, string> = {
    甲: '直接有力，善于传递愿景，天然具有领导感',
    乙: '温和灵活，善于倾听与协作，让人如沐春风',
    丙: '热情外向，擅长激励他人，能量感染力强',
    丁: '细腻专注，表达深思熟虑，话不多但有分量',
    戊: '沉稳可靠，言出必行，让人感到踏实',
    己: '温婉细心，注重细节，沟通时体贴周全',
    庚: '直接有力，言辞简洁，敢于直说',
    辛: '精准优雅，追求表达的完美，重视言辞质量',
    壬: '智慧包容，善于从全局思考，能包容不同意见',
    癸: '敏锐直觉强，情感共鸣力高，容易让人敞开心扉',
  };

  /** 日主天干 → 情绪模式 */
  private static readonly RI_GAN_EMOTION: Record<TianGan, string> = {
    甲: '情绪稳定但执着，挫折时容易固守己见，需要提醒自己保持弹性',
    乙: '情绪灵活，善于调节，但对外界评价较敏感',
    丙: '情绪外显，热烈奔放，低谷时需要通过社交和陪伴充电',
    丁: '情感深沉内敛，执着专注，内心世界比表面丰富得多',
    戊: '情绪稳定厚重，不轻易表露，倾向以行动而非语言处理情绪',
    己: '情感细腻，容易受环境氛围影响，对安全感的需求较高',
    庚: '情绪直接，爱憎分明，压力下容易产生冲动，需要出口',
    辛: '情感敏感，自尊心强，需要被认可，批评要注意方式',
    壬: '情绪流动，包容性强，偶尔显得难以捉摸，其实在深层整合',
    癸: '情感极为丰富，直觉敏锐，容易感同身受他人情绪，需要设立边界',
  };

  /** 大运十神 → 人生阶段描述（Levinson 生命周期 × 大运论） */
  private static readonly DAYUN_PHASE: Record<ShiShen, string> = {
    比肩: '自我建立期：独立意识增强，适合强化个人品牌，单打独斗比团队协作更顺',
    劫财: '行动爆发期：竞争意识和魄力达到峰值，能量充沛，财务方面需要谨慎把控',
    食神: '才华绽放期：创造力和表达欲旺盛，是发展创意事业的黄金阶段',
    伤官: '突破革新期：打破常规的冲动强烈，容易与既有体制摩擦，创造力爆发',
    偏财: '拓展机遇期：社交机会涌现，商业嗅觉敏锐，适合扩大人脉和把握意外机遇',
    正财: '积累沉淀期：稳步夯实基础，适合长期规划和资产建设，慢即是快',
    七杀: '磨砺蜕变期：挑战密集，压力催生成长，是人生中极具转化意义的阶段',
    正官: '社会认可期：职场规范化和外部认可度提升，适合在体制内寻求上升',
    偏印: '专业深化期：适合深耕专业技能、独立研究，或精神层面的探索',
    正印: '贵人庇护期：贵人运旺，学习进修有成效，内心平稳，适合沉淀与蓄力',
  };

  /** 五行 → 幸运颜色 */
  private static readonly WX_COLORS: Record<WuXing, string[]> = {
    木: ['绿色', '青色', '蓝绿色'],
    火: ['红色', '橙色', '紫色'],
    土: ['黄色', '棕色', '米色'],
    金: ['白色', '金色', '银色'],
    水: ['黑色', '深蓝色', '灰色'],
  };

  /** 五行 → 幸运方位 */
  private static readonly WX_DIRECTIONS: Record<WuXing, string[]> = {
    木: ['东方', '东南方'],
    火: ['南方'],
    土: ['中央', '西南方', '东北方'],
    金: ['西方', '西北方'],
    水: ['北方'],
  };

  /**
   * 五行 → 幸运数字（河图洛书）
   * 水→1,6；火→2,7；木→3,8；金→4,9；土→5,10
   */
  private static readonly WX_NUMBERS: Record<WuXing, number[]> = {
    水: [1, 6],
    火: [2, 7],
    木: [3, 8],
    金: [4, 9],
    土: [5, 10],
  };

  /** 五行 → 脏腑（《黄帝内经》五脏五行）*/
  private static readonly WX_ORGAN: Record<WuXing, string> = {
    木: '肝胆', 火: '心脑', 土: '脾胃', 金: '肺气管', 水: '肾泌尿',
  };

  /** 神煞白话描述（来源：REFERENCES.ts §四 + 三命通会神煞论） */
  private static readonly SHENSHA_MODERN: Record<string, string> = {
    天乙贵人: '你容易获得他人的帮助，贵人运强',
    文昌贵人: '你有很强的学习和表达能力',
    桃花:     '你天生有吸引人的气质',
    驿马:     '你适合在变化中寻找机会',
    华盖:     '你有很强的精神追求，可能带有孤独感',
    羊刃:     '你做决定很果断，但需注意冲动',
    空亡:     '这个领域暂时需要更多耐心',
    天喜:     '多逢喜庆机遇，生命里常有惊喜',
    红鸾:     '感情姻缘上有吉兆',
    福星贵人: '整体福气深厚，逢事多有贵人',
  };

  // ═══════════════════════════════════════════
  // § 构造函数
  // ═══════════════════════════════════════════

  constructor(mingPan: MingPan) {
    this.mingPan     = mingPan;
    this.dayunEngine = new DayunEngine(mingPan);
  }

  // ═══════════════════════════════════════════
  // § 人格洞察
  // ═══════════════════════════════════════════

  /**
   * 基于命盘生成人格洞察
   *
   * 整合维度：日主（日干）、格局（月令十神）、
   * 五行强弱、神煞（吉神）、身强/弱
   */
  getPersonalityInsight(): PersonalityInsight {
    const { riZhu, wuXingStrength, geJu, shenSha, siZhu } = this.mingPan;

    // ── 核心性格特质 ──────────────────────────
    const monthSS   = siZhu.month.cangGan[0].shiShen;
    const ssProfile = InsightEngine.SHISHEN_PROFILE[monthSS];

    const coreTraits: string[] = [
      riZhu.description,
      ssProfile.trait,
    ];
    if (wuXingStrength.riZhuStrong) {
      coreTraits.push('你是那种知道自己要什么的人，自我意识清晰而坚定');
    } else {
      coreTraits.push('你擅长在环境中找到自己的位置，适应力是你的隐形优势');
    }

    // ── 优势 ─────────────────────────────────
    const strengths: string[] = [ssProfile.strength, geJu.modernMeaning];
    for (const sha of shenSha.filter(s => s.type === '吉').slice(0, 2)) {
      const modern = InsightEngine.SHENSHA_MODERN[sha.name] ?? sha.modernMeaning;
      if (modern) strengths.push(modern);
    }

    // ── 挑战 ─────────────────────────────────
    const challenges: string[] = [ssProfile.challenge];
    if (!wuXingStrength.riZhuStrong) {
      const jiOrgan = InsightEngine.WX_ORGAN[wuXingStrength.jiShen];
      challenges.push(
        `${wuXingStrength.jiShen}五行过旺时容易带来压力，注意${jiOrgan}系统的调养`,
      );
    }
    // 凶神煞提示（最多 1 条，避免过于负面）
    const firstBad = shenSha.find(s => s.type === '凶');
    if (firstBad) challenges.push(firstBad.modernMeaning);

    // ── 沟通风格 & 情绪模式 ───────────────────
    const communicationStyle = InsightEngine.RI_GAN_COMM[riZhu.gan];
    const emotionalPattern   = InsightEngine.RI_GAN_EMOTION[riZhu.gan];

    // ── 职业倾向 ─────────────────────────────
    const careerAptitude = [
      ssProfile.career,
      `${geJu.name}：${geJu.modernMeaning}`,
    ];

    // ── 关系模式 ─────────────────────────────
    const relationshipStyle = ssProfile.relationStyle;

    return {
      coreTraits,
      strengths,
      challenges,
      communicationStyle,
      emotionalPattern,
      careerAptitude,
      relationshipStyle,
    };
  }

  // ═══════════════════════════════════════════
  // § 时运洞察
  // ═══════════════════════════════════════════

  /**
   * 基于大运流年生成时运洞察
   * @param year 公历年份
   */
  getTimingInsight(year: number): TimingInsight {
    const birthYear  = this.mingPan.birthDateTime.getFullYear();
    const currentAge = year - birthYear;
    const daYun      = this.dayunEngine.getCurrentDaYun(currentAge);
    const liuNian    = this.dayunEngine.getCurrentLiuNian(year);
    const { yongShen, xiShen, jiShen } = this.mingPan.wuXingStrength;

    // ── 当前人生阶段 ─────────────────────────
    const phaseDesc  = InsightEngine.DAYUN_PHASE[daYun.shiShen];
    const currentPhase = `${daYun.period}·${daYun.ganZhi.gan}${daYun.ganZhi.zhi}大运：${phaseDesc}`;

    // ── 当前能量状态（流年十神） ───────────────
    const lnProfile    = InsightEngine.SHISHEN_PROFILE[liuNian.shiShen];
    const currentEnergy = `${year}${liuNian.ganZhi.gan}${liuNian.ganZhi.zhi}年：${lnProfile.trait}`;

    // ── 机遇方向 ─────────────────────────────
    const opportunities: string[] = [
      `喜神为${xiShen}，关注${InsightEngine.WX_DIRECTIONS[xiShen].join('、')}方向的机遇`,
      lnProfile.strength,
    ];
    const heInteraction = liuNian.interactions.find(s => s.includes('合'));
    if (heInteraction) opportunities.push(heInteraction);

    // ── 注意事项 ─────────────────────────────
    const watchouts: string[] = [
      `忌神为${jiShen}（${InsightEngine.WX_ORGAN[jiShen]}方向需关注），避免相关领域过度消耗`,
      lnProfile.challenge,
    ];
    const chongInteraction = liuNian.interactions.find(
      s => s.includes('冲') || s.includes('刑'),
    );
    if (chongInteraction) watchouts.push(chongInteraction);

    // ── 建议 ─────────────────────────────────
    const advice =
      `用神为${yongShen}，多接触${InsightEngine.WX_COLORS[yongShen].join('、')}，` +
      `向${InsightEngine.WX_DIRECTIONS[yongShen].join('、')}发展，有助于激活能量';`;

    // ── 幸运元素 ─────────────────────────────
    const luckyElements = {
      colors:     InsightEngine.WX_COLORS[xiShen],
      directions: InsightEngine.WX_DIRECTIONS[xiShen],
      numbers:    InsightEngine.WX_NUMBERS[xiShen],
    };

    return {
      currentPhase,
      currentEnergy,
      opportunities,
      watchouts,
      advice,
      luckyElements,
    };
  }

  // ═══════════════════════════════════════════
  // § 每日洞察
  // ═══════════════════════════════════════════

  /**
   * 基于公历日期生成每日运势
   *
   * 日柱干支推算：
   *   基准 1900-01-31 = 甲子日（序号 0）
   *   diffDays = floor((date - base) / 86400000)
   *   idx = diffDays % 60
   *
   * @param date 目标日期
   */
  getDailyInsight(date: Date): DailyInsight {
    // ── 计算日柱 ─────────────────────────────
    const diffDays = Math.floor((date.getTime() - DAY_BASE) / 86400000);
    const idx      = ((diffDays % 60) + 60) % 60;
    const dayGanZhi = DayunEngine.indexToGanZhi(idx);

    const riGan      = this.mingPan.riZhu.gan;
    const dayShiShen = DayunEngine.computeShiShen(riGan, dayGanZhi.gan);

    // ── 整体能量 ─────────────────────────────
    // 日柱五行与用神/喜神/忌神对照
    const { yongShen, xiShen, jiShen } = this.mingPan.wuXingStrength;
    const dayWx = dayGanZhi.ganWuXing;
    let overallEnergy: '高' | '中' | '低' = '中';
    if (dayWx === yongShen || dayWx === xiShen) overallEnergy = '高';
    if (dayWx === jiShen)                       overallEnergy = '低';

    // ── 今日关注领域 ─────────────────────────
    const focusMap: Record<ShiShen, string> = {
      比肩: '个人项目与独立决策',
      劫财: '行动执行与任务推进',
      食神: '创意输出与生活享受',
      伤官: '才华表达与创新突破',
      偏财: '社交机遇与商业拓展',
      正财: '财务规划与踏实工作',
      七杀: '压力处理与问题解决',
      正官: '职责履行与规范事务',
      偏印: '学习研究与独立思考',
      正印: '休养充电与寻求支持',
    };

    // ── 今日建议 ─────────────────────────────
    const adviceMap: Record<ShiShen, string> = {
      比肩: '发挥主动性，推进自己的计划，今天适合独当一面',
      劫财: '利用今天的行动力完成积压任务，动起来效率高',
      食神: '留出创意时间，享受过程，好状态会自然来',
      伤官: '让才华有个出口，选好表达的场合更重要',
      偏财: '主动拓展人脉，商机往往藏在随意的交流里',
      正财: '专注手头工作，稳扎稳打是今天的关键词',
      七杀: '遇到压力先冷静 3 秒，再行动，质量胜于速度',
      正官: '按规矩来今天收益最大，做好该做的事',
      偏印: '深度学习或独处思考，保持专注',
      正印: '可以寻求帮助、充电补能，也适合学习',
    };

    // ── 今日宜避免 ───────────────────────────
    const avoidMap: Record<ShiShen, string> = {
      比肩: '避免意气用事和不必要的竞争',
      劫财: '避免冲动消费或激进决策',
      食神: '避免过度享乐，耽误重要事项',
      伤官: '避免在职场与权威正面冲突',
      偏财: '避免贪多，专注几个核心机会',
      正财: '避免高风险投资和赌博式决策',
      七杀: '避免焦虑驱动的仓促行动',
      正官: '避免过于刻板，留有弹性',
      偏印: '避免孤立，适当与他人交流想法',
      正印: '避免过度依赖，相信自己的判断',
    };

    // ── 今日肯定语 ───────────────────────────
    const affirmationMap: Record<ShiShen, string> = {
      比肩: '我清楚自己的方向，今天我主动创造机会',
      劫财: '我的行动力是我最强的武器，今天我全力以赴',
      食神: '我的创意自然流淌，今天我享受这个过程',
      伤官: '我的才华值得被看见，今天我找到合适的舞台',
      偏财: '机会在流动中降临，我保持开放与好奇',
      正财: '踏实前行，每一步都在为未来积累',
      七杀: '压力让我更强大，我有能力化解眼前的挑战',
      正官: '我用负责任的行动赢得信任与尊重',
      偏印: '深度思考是我的力量，今天我潜入内心',
      正印: '我值得被支持，也有能力接受帮助',
    };

    // ── 吉时（以日支为基准：同气相求或六合时辰）──
    const luckyHours = InsightEngine.getDayZhiLuckyHours(dayGanZhi.zhi);

    const y = date.getFullYear();
    const m = String(date.getMonth() + 1).padStart(2, '0');
    const d = String(date.getDate()).padStart(2, '0');

    return {
      date:          `${y}-${m}-${d}`,
      ganZhi:        `${dayGanZhi.gan}${dayGanZhi.zhi}日（${dayGanZhi.naYin}）`,
      overallEnergy,
      focusArea:     focusMap[dayShiShen]      ?? '综合事务',
      advice:        adviceMap[dayShiShen]     ?? '顺其自然，保持平常心',
      avoidance:     avoidMap[dayShiShen]      ?? '避免拖延和消极情绪',
      luckyHours,
      affirmation:   affirmationMap[dayShiShen] ?? '我接纳今天，顺势而为',
    };
  }

  // ═══════════════════════════════════════════
  // § 内部工具
  // ═══════════════════════════════════════════

  /**
   * 推算日支对应的吉时
   *
   * 规则：日支五合时辰（主气相合） + 同五行时辰为辅
   * 地支六合：子丑 / 寅亥 / 卯戌 / 辰酉 / 巳申 / 午未
   */
  private static getDayZhiLuckyHours(dayZhi: DiZhi): string[] {
    const liuHe: Record<DiZhi, DiZhi> = {
      子: '丑', 丑: '子', 寅: '亥', 亥: '寅',
      卯: '戌', 戌: '卯', 辰: '酉', 酉: '辰',
      巳: '申', 申: '巳', 午: '未', 未: '午',
    };
    const zhiHour: Record<DiZhi, string> = {
      子: '子时(23–1时)',  丑: '丑时(1–3时)',
      寅: '寅时(3–5时)',  卯: '卯时(5–7时)',
      辰: '辰时(7–9时)',  巳: '巳时(9–11时)',
      午: '午时(11–13时)', 未: '未时(13–15时)',
      申: '申时(15–17时)', 酉: '酉时(17–19时)',
      戌: '戌时(19–21时)', 亥: '亥时(21–23时)',
    };
    const result = [zhiHour[dayZhi]];
    const heZhi  = liuHe[dayZhi];
    if (heZhi && zhiHour[heZhi]) result.push(zhiHour[heZhi]);
    return result;
  }
}
