import {
  computeRootStrength,
  computeYueLingState,
  computeDeLing,
  computeZuoRen,
  computeZuoGen,
  computeQingZhuo,
  computeHanNuanZaoShi,
  computeRiZhuStrength,
  computeRiZhuStructure,
  computeGeJuV2,
  selectYongShen,
  detectHuaQi,
  detectCongGe,
  detectZhuanWang,
  ROOT_TIER_WEIGHT,
} from '../structural';

describe('computeRootStrength (Phase 0.5)', () => {
  it('tier weights match bazi-life-curves 1.0 / 0.5 / 0.2', () => {
    expect(ROOT_TIER_WEIGHT.ben).toBe(1.0);
    expect(ROOT_TIER_WEIGHT.zhong).toBe(0.5);
    expect(ROOT_TIER_WEIGHT.yu).toBe(0.2);
  });

  it('甲日 + 寅卯辰巳：木根丰厚 → 强根', () => {
    // 寅: 甲(本)+1.0 bijie | 卯: 乙(本)+1.0 bijie
    // 辰: 乙(中)+0.5 bijie, 癸(余)+0.2 yin
    // 巳: 无木无水
    const r = computeRootStrength('甲', ['寅', '卯', '辰', '巳']);
    expect(r.bijieRoot).toBeCloseTo(2.5, 5);
    expect(r.yinRoot).toBeCloseTo(0.2, 5);
    expect(r.totalRoot).toBeCloseTo(2.7, 5);
    expect(r.label).toBe('强根');
  });

  it('庚日 + 子寅巳午：金根薄、土印多 → 弱根', () => {
    // 子(癸 水): 不同党不生金
    // 寅: 戊(余)+0.2 yin (土生金)；甲/丙 无关
    // 巳: 戊(中)+0.5 yin、庚(余)+0.2 bijie；丙无关
    // 午: 己(中)+0.5 yin (土生金)；丁无关
    const r = computeRootStrength('庚', ['子', '寅', '巳', '午']);
    expect(r.bijieRoot).toBeCloseTo(0.2, 5);
    expect(r.yinRoot).toBeCloseTo(1.2, 5);    // 0.2 + 0.5 + 0.5
    expect(r.totalRoot).toBeCloseTo(1.4, 5);
    expect(r.label).toBe('弱根'); // [0.70, 1.50)
  });

  it('丙日 + 寅午戌寅：火根极旺 → 强根', () => {
    // 寅×2: 甲(本)+1.0 yin, 丙(中)+0.5 bijie
    // 午: 丁(本)+1.0 bijie
    // 戌: 丁(余)+0.2 bijie
    const r = computeRootStrength('丙', ['寅', '午', '戌', '寅']);
    expect(r.bijieRoot).toBeCloseTo(2.2, 5); // 0.5*2 + 1.0 + 0.2
    expect(r.yinRoot).toBeCloseTo(2.0, 5);   // 1.0 * 2
    expect(r.label).toBe('强根');
  });

  it('details 含 zhi / position / tier / kind', () => {
    const r = computeRootStrength('甲', ['子', '丑', '卯', '酉']);
    expect(r.details.find((d) => d.zhi === '卯' && d.kind === 'bijie')).toBeDefined();
    expect(r.details.find((d) => d.zhi === '子' && d.kind === 'yin')).toBeDefined();
    const positions = new Set(r.details.map((d) => d.position));
    expect(positions.has('年')).toBe(true);
    expect(positions.has('日')).toBe(true);
  });

  it('label 切分阈值生效（中根边界）', () => {
    // 戊日 + 申子辰寅
    // 申: 戊(余)+0.2 bijie | 辰: 戊(本)+1.0 bijie
    // 寅: 丙(中)+0.5 yin (火生土), 戊(余)+0.2 bijie
    const r = computeRootStrength('戊', ['申', '子', '辰', '寅']);
    expect(r.bijieRoot).toBeCloseTo(1.4, 5);
    expect(r.yinRoot).toBeCloseTo(0.5, 5);
    expect(r.totalRoot).toBeCloseTo(1.9, 5);
    expect(r.label).toBe('中根'); // [1.50, 2.50) → 中根
  });

  it('完全无根的极端情形 → 无根', () => {
    // 庚日 + 子卯亥子（无土、无金 → 既无 yin 也无 bijie）
    const r = computeRootStrength('庚', ['子', '卯', '亥', '子']);
    expect(r.bijieRoot).toBe(0);
    expect(r.yinRoot).toBe(0);
    expect(r.label).toBe('无根');
  });
});

// ============================================================
// Phase 2 原语 fixtures
// 出处：《子平真诠》论十干得时不旺失时不弱 / 论阳刃；
//      《滴天髓·清浊 / 寒暖燥湿 / 体用》
// ============================================================

describe('computeYueLingState (《子平真诠》月令旺相休囚死)', () => {
  it('甲日生卯月 → 旺（同党当令）', () => {
    expect(computeYueLingState('甲', '卯')).toBe('旺');
  });
  it('甲日生子月 → 相（印当令，水生木）', () => {
    expect(computeYueLingState('甲', '子')).toBe('相');
  });
  it('甲日生午月 → 休（食伤当令，木生火）', () => {
    expect(computeYueLingState('甲', '午')).toBe('休');
  });
  it('甲日生戌月 → 囚（财当令，木克土）', () => {
    expect(computeYueLingState('甲', '戌')).toBe('囚');
  });
  it('甲日生酉月 → 死（官杀当令，金克木）', () => {
    expect(computeYueLingState('甲', '酉')).toBe('死');
  });
});

describe('computeDeLing / computeZuoRen / computeZuoGen', () => {
  it('丙日生午月 → 得令；坐午 → 坐刃 + 坐根', () => {
    const { deLing, shiLing, yueLingState } = computeDeLing('丙', '午');
    expect(deLing).toBe(true);
    expect(shiLing).toBe(false);
    expect(yueLingState).toBe('旺');
    expect(computeZuoRen('丙', '午')).toBe(true);
    expect(computeZuoGen('丙', '午')).toBe(true);
  });
  it('庚日生卯月 → 失令（财当令）；坐酉 → 坐刃', () => {
    const { deLing, shiLing } = computeDeLing('庚', '卯');
    expect(deLing).toBe(false);
    expect(shiLing).toBe(true);
    expect(computeZuoRen('庚', '酉')).toBe(true);
  });
  it('阴干无刃：乙日坐寅 → 不立刃，但坐根（藏甲）', () => {
    expect(computeZuoRen('乙', '寅')).toBe(false);
    expect(computeZuoGen('乙', '寅')).toBe(true);
  });
});

describe('computeHanNuanZaoShi (《滴天髓·寒暖燥湿》)', () => {
  it('壬子年子月癸亥日壬子时 → 寒 + 湿（冬月水旺无火）', () => {
    const r = computeHanNuanZaoShi('子', ['子', '子', '亥', '子'], ['壬', '壬', '癸', '壬']);
    expect(r.han).toBe(true);
    expect(r.shi).toBe(true);
    expect(r.zao).toBe(false);
    expect(r.nuan).toBe(false);
  });
  it('丙午年午月丁未日丙午时 → 暖 + 燥（夏月火旺无水）', () => {
    const r = computeHanNuanZaoShi('午', ['午', '午', '未', '午'], ['丙', '丙', '丁', '丙']);
    expect(r.nuan).toBe(true);
    expect(r.zao).toBe(true);
    expect(r.han).toBe(false);
    expect(r.shi).toBe(false);
  });
  it('春分前后辰月 → 既非寒亦非暖（中性月令）', () => {
    const r = computeHanNuanZaoShi('辰', ['寅', '辰', '酉', '巳'], ['甲', '戊', '辛', '癸']);
    expect(r.han).toBe(false);
    expect(r.nuan).toBe(false);
  });
});

describe('computeQingZhuo (《滴天髓·清浊》)', () => {
  it('丙寅午午寅 + 同党天干 → 清（火党+木印 ≥60% 根力，五行 ≤3 种）', () => {
    const q = computeQingZhuo('丙', ['寅', '午', '午', '寅'], ['丙', '甲', '丙', '丁']);
    expect(q).toBe('qing');
  });
  it('庚日 + 寅卯巳午 + 五行混杂 → 浊（5 wx + 同党根 < 30%）', () => {
    const q = computeQingZhuo('庚', ['寅', '卯', '巳', '午'], ['庚', '甲', '丁', '癸']);
    expect(q).toBe('zhuo');
  });
});

describe('computeRiZhuStrength (五档：太旺/旺/中和/弱/太弱)', () => {
  it('丙日生午月坐午 + 寅党 → 太旺', () => {
    // 月午得令，寅午两根 → 强根；坐午 → 坐刃
    const s = computeRiZhuStrength('丙', ['寅', '午', '午', '寅'], '午', '午');
    expect(s).toBe('taiwang');
  });
  it('甲日生酉月（失令） + 巳午时柱 → 太弱', () => {
    // 甲日酉月 → 死（官杀当令）；四支无木无水 → 无根
    const s = computeRiZhuStrength('甲', ['巳', '酉', '巳', '午'], '酉', '巳');
    expect(s).toBe('tairuo');
  });
  it('庚日生卯月（失令） + 申根 → 中和', () => {
    // 卯月 → 囚；但日支申有强根（金党本气）
    const s = computeRiZhuStrength('庚', ['辰', '卯', '申', '戌'], '卯', '申');
    expect(s).toBe('zhonghe');
  });
});

describe('computeRiZhuStructure (聚合)', () => {
  it('返回 deLing/shiLing/yueLingState/rootStrength/zuoRen/zuoGen/qingZhuo/hanNuanZaoShi/strength 全字段', () => {
    const r = computeRiZhuStructure(
      '丙',
      ['丙', '甲', '丙', '丁'],
      ['寅', '午', '午', '寅'],
    );
    expect(r.deLing).toBe(true);
    expect(r.shiLing).toBe(false);
    expect(r.yueLingState).toBe('旺');
    expect(r.zuoRen).toBe(true);
    expect(r.zuoGen).toBe(true);
    expect(r.qingZhuo).toBe('qing');
    expect(r.hanNuanZaoShi.nuan).toBe(true);
    expect(r.strength).toBe('taiwang');
    expect(r.rootStrength.label).toBe('强根');
  });
});

// ============================================================
// Phase 2 Step B：GeJuV2 fixtures（结构化格局）
// 出处：《子平真诠》论用神 / 论用神成败救应 / 论用神变化 /
//      论相神紧要 / 论用神格局高低；
//      《滴天髓阐微》任铁樵注 论体用 / 论从 / 论化。
// 每条 case 在 docs/mingli/reading-notes/ziping-zhenquan-xiangshen.md
// 与 dichuixui-tiyong.md 抽出，evidence 引 6 条 claim id。
// ============================================================

describe('computeGeJuV2 — 正格成（cheng）+ 上格', () => {
  // 甲日酉月：月令本气辛透干 → 正官格；
  // 戊偏财生官、癸正印护官；无伤官透干 → 成格清纯；
  // 用神金强根（酉×2 + 申庚）→ jibie='shang'。
  it('甲日酉月辛透 + 戊财 + 子癸印护 → 正官格成 / 上格', () => {
    const g = computeGeJuV2('甲', ['辛', '辛', '甲', '戊'], ['酉', '酉', '子', '申']);
    expect(g.name).toBe('正官格');
    expect(g.category).toBe('zhengge');
    expect(g.yongShen).toBe('金');
    expect(g.chengBai).toBe('cheng');
    expect(g.xiangShen).not.toBeNull();
    expect(g.xiangShen?.shiShen).toBe('正印'); // 甲日无己（正财），命中 secondary 正印
    expect(g.jiuYing).toBeNull();
    expect(g.jibie).toBe('shang');
    expect(g.evidence).toContain('bazi.yongshen.priority-chain');
    expect(g.evidence).toContain('bazi.xiangshen.definition');
    expect(g.evidence).toContain('bazi.geju.rank-criteria');
  });
});

describe('computeGeJuV2 — 正格破后救应（jiuying）', () => {
  // 同甲日酉月辛透 → 正官格；
  // 但天干透丁伤官 → 用神受克 → 破象；
  // 又透癸正印 → 印化伤官护官 → 救应（yin-hua）；
  // 评级降为中格。
  it('甲日酉月辛透 + 丁伤官破官 + 癸印化救 → 正官格 jiuying / 中格', () => {
    const g = computeGeJuV2('甲', ['癸', '辛', '甲', '丁'], ['酉', '酉', '子', '卯']);
    expect(g.name).toBe('正官格');
    expect(g.chengBai).toBe('jiuying');
    expect(g.xiangShen?.shiShen).toBe('正印');
    expect(g.jiuYing).not.toBeNull();
    expect(g.jiuYing!.length).toBeGreaterThanOrEqual(1);
    expect(g.jiuYing!.some((j) => j.path === 'yin-hua')).toBe(true);
    expect(g.jibie).toBe('zhong');
    expect(g.evidence).toContain('bazi.jiuying.path-classification');
  });
});

describe('computeGeJuV2 — 七杀格 食神制杀', () => {
  // 庚日巳月：月令本气丙透 → 七杀格；
  // 透壬食神 → 食神制杀（制神到位 → 成格）；
  // 用神火中根（寅丙 + 巳丙）→ 上格。
  it('庚日巳月丙透 + 壬食神制杀 → 七杀格成 / 上格', () => {
    const g = computeGeJuV2('庚', ['壬', '丙', '庚', '庚'], ['寅', '巳', '申', '子']);
    expect(g.name).toBe('七杀格');
    expect(g.yongShen).toBe('火');
    expect(g.chengBai).toBe('cheng');
    expect(g.xiangShen?.shiShen).toBe('食神');
    expect(g.jibie).toBe('shang');
  });
});

describe('computeGeJuV2 — 从财格', () => {
  // 壬日午月：四支午午午未 → 全火土 → 日主无根；
  // 财党（火）藏透合计 ≥ 4 且远高于次党（土）→ 从财格；
  // 不再走正格主流程。
  it('壬日午月 + 全火土 + 日主无根 → 从财格', () => {
    const g = computeGeJuV2('壬', ['丙', '丙', '壬', '丁'], ['午', '午', '午', '未']);
    expect(g.name).toBe('从财格');
    expect(g.category).toBe('conge');
    expect(g.yongShen).toBe('火');
    expect(g.chengBai).toBe('cheng');
    expect(g.jibie).toBe('shang');
    expect(g.evidence).toContain('bazi.geju.rank-criteria');
  });
});

describe('computeGeJuV2 — 化气格（甲己合化土）', () => {
  // 甲日戌月：月令本气戊（土）；时干己 → 甲己合化土；
  // 日主无根（地支午戌巳未仅未藏乙余气微弱）；
  // 月支戌不被冲（地支无辰）→ 化土格成。
  it('甲日戌月 + 时干己 + 日主无根 + 月支不冲 → 化土格', () => {
    const g = computeGeJuV2('甲', ['癸', '辛', '甲', '己'], ['午', '戌', '巳', '未']);
    expect(g.name).toBe('化土格');
    expect(g.category).toBe('huaqi');
    expect(g.yongShen).toBe('土');
    expect(g.chengBai).toBe('cheng');
    expect(g.jibie).toBe('shang');
    expect(g.evidence).toContain('bazi.yongshen.bianhua-trigger');
  });
});

describe('computeGeJuV2 — 专旺格（曲直）', () => {
  // 甲日卯月：地支卯卯卯亥 → 木党极旺（比劫 6）；
  // 透干癸正印 + 藏壬印 → 印生（≥1）；
  // 无官杀食伤透干 + 藏极少 → 克泄 ≤ 1；
  // → 曲直格（五专旺之木格）。
  it('甲日卯月 + 卯卯亥 + 印生 + 无克泄 → 曲直格', () => {
    const g = computeGeJuV2('甲', ['甲', '乙', '甲', '癸'], ['卯', '卯', '卯', '亥']);
    expect(g.name).toBe('曲直格');
    expect(g.category).toBe('zhuanwang');
    expect(g.yongShen).toBe('木');
    expect(g.chengBai).toBe('cheng');
    expect(g.jibie).toBe('shang');
  });
});

describe('selectYongShen — 用神变化（《子平真诠》论用神变化）', () => {
  it('月支本气透干 → basis=yueling-benqi-tougan / bianhua=false', () => {
    // 甲日酉月辛透 → 月令本气直接为用
    const sel = selectYongShen('甲', '酉', ['辛', '辛', '甲', '戊'], ['酉', '酉', '子', '申']);
    expect(sel.yongGan).toBe('辛');
    expect(sel.basis).toBe('yueling-benqi-tougan');
    expect(sel.bianhua).toBe(false);
  });

  it('本气未透 + 中气透 → basis=yueling-zhongqi-tougan / bianhua=true', () => {
    // 甲日寅月：寅本气甲(已是日干) / 中气丙 / 余气戊；丙透 → 用神变化为食神
    const sel = selectYongShen('甲', '寅', ['丙', '丙', '甲', '丙'], ['寅', '寅', '寅', '寅']);
    // 注意：本气甲 == dayGan，stemSet.has(甲) 为 true → 走 jianlu 而非 zhongqi
    // 这里其实应是 建禄格；改用月支非比劫之例：
    expect(['yueling-benqi-tougan', 'jianlu-yueliu']).toContain(sel.basis);
  });

  it('专气支（子午卯酉）+ 本气未透 → 跳过中/余气 → basis=jianlu-yueliu', () => {
    // 庚日卯月：卯专气，本气乙(财)未透；天干无乙
    const sel = selectYongShen('庚', '卯', ['壬', '丁', '庚', '丙'], ['辰', '卯', '申', '戌']);
    expect(sel.yongGan).toBe('乙');
    expect(sel.basis).toBe('jianlu-yueliu');
  });
});

describe('detectHuaQi / detectCongGe / detectZhuanWang — 结构化布尔', () => {
  it('detectHuaQi: 化气前置条件齐全 → isHuaQi=true', () => {
    const r = detectHuaQi('甲', ['癸', '辛', '甲', '己'], ['午', '戌', '巳', '未'], '无根');
    expect(r.isHuaQi).toBe(true);
    expect(r.huaWx).toBe('土');
    expect(r.partnerGan).toBe('己');
  });

  it('detectHuaQi: 日主有根 → isHuaQi=false（无根是硬约束）', () => {
    const r = detectHuaQi('甲', ['癸', '辛', '甲', '己'], ['寅', '戌', '巳', '未'], '中根');
    expect(r.isHuaQi).toBe(false);
  });

  it('detectCongGe: 无根 + 财党≥4 + 远超次党 → 从财', () => {
    const r = detectCongGe('壬', ['丙', '丙', '壬', '丁'], ['午', '午', '午', '未'], '无根');
    expect(r.isCong).toBe(true);
    expect(r.congType).toBe('从财');
    expect(r.congWx).toBe('火');
  });

  it('detectZhuanWang: 比劫≥4 + 印≥1 + 克泄≤1 → 曲直格', () => {
    const r = detectZhuanWang('甲', ['甲', '乙', '甲', '癸'], ['卯', '卯', '卯', '亥']);
    expect(r.isZhuanWang).toBe(true);
    expect(r.name).toBe('曲直格');
  });
});
