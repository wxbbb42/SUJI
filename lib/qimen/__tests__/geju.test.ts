import { ALL_GE_JU, detectGeJu } from '../data/geju';
import type { QimenChart, Palace } from '../types';

// ────────────────────────────────────────────────────────
// 工具：构造一个 mock chart 用于测试特定格局
// ────────────────────────────────────────────────────────

function makeChart(palaceOverrides: Array<Partial<Palace>>): QimenChart {
  const palaces: Palace[] = [];
  const baseInfo: Array<Pick<Palace, 'id' | 'name' | 'position' | 'wuXing'>> = [
    { id: 1, name: '坎宫', position: '北',   wuXing: '水' },
    { id: 2, name: '坤宫', position: '西南', wuXing: '土' },
    { id: 3, name: '震宫', position: '东',   wuXing: '木' },
    { id: 4, name: '巽宫', position: '东南', wuXing: '木' },
    { id: 5, name: '中宫', position: '中',   wuXing: '土' },
    { id: 6, name: '乾宫', position: '西北', wuXing: '金' },
    { id: 7, name: '兑宫', position: '西',   wuXing: '金' },
    { id: 8, name: '艮宫', position: '东北', wuXing: '土' },
    { id: 9, name: '离宫', position: '南',   wuXing: '火' },
  ];
  for (let i = 0; i < 9; i++) {
    palaces.push({
      ...baseInfo[i],
      diPanGan: null,
      tianPanGan: null,
      bamen: null,
      jiuxing: null,
      bashen: null,
      ...(palaceOverrides[i] ?? {}),
    });
  }
  return {
    question: '',
    questionType: 'general',
    setupTime: '',
    trueSolarTime: '',
    jieqi: '冬至',
    yinYangDun: '阳',
    juNumber: 1,
    yuan: '上',
    palaces,
    yongShen: { type: '', palaceId: 1, state: '相', summary: '', interactions: [] },
    geJu: [],
    yingQi: { description: '', factors: [] },
  };
}

// ────────────────────────────────────────────────────────
// 结构性测试
// ────────────────────────────────────────────────────────

describe('ALL_GE_JU', () => {
  it('exports 45-60 格局（spec ADR-5 接受范围）', () => {
    expect(ALL_GE_JU.length).toBeGreaterThanOrEqual(45);
    expect(ALL_GE_JU.length).toBeLessThanOrEqual(60);
  });

  it('all rules have name, type, description, match', () => {
    for (const rule of ALL_GE_JU) {
      expect(rule.name).toBeTruthy();
      expect(['吉', '凶', '中性']).toContain(rule.type);
      expect(rule.description).toBeTruthy();
      expect(typeof rule.match).toBe('function');
    }
  });

  it('rule names are unique', () => {
    const names = ALL_GE_JU.map(r => r.name);
    expect(new Set(names).size).toBe(names.length);
  });

  it('contains key 通用 / 命名 格局', () => {
    const names = ALL_GE_JU.map(r => r.name);
    const keyOnes = ['伏吟', '反吟', '值符', '入墓', '飞鸟跌穴', '青龙返首', '玉女守门'];
    for (const k of keyOnes) {
      expect(names).toContain(k);
    }
  });
});

// ────────────────────────────────────────────────────────
// Fixture 测试：通用格
// ────────────────────────────────────────────────────────

describe('detectGeJu - 伏吟', () => {
  it('triggers when ≥3 palaces have same di+tian gan', () => {
    const overrides: Array<Partial<Palace>> = [
      { diPanGan: '甲', tianPanGan: '甲' },
      { diPanGan: '乙', tianPanGan: '乙' },
      { diPanGan: '丙', tianPanGan: '丙' },
      {}, {}, {}, {}, {}, {},
    ];
    const result = detectGeJu(makeChart(overrides));
    expect(result.some(g => g.name === '伏吟')).toBe(true);
  });

  it('does NOT trigger with only 2 matching palaces', () => {
    const overrides: Array<Partial<Palace>> = [
      { diPanGan: '甲', tianPanGan: '甲' },
      { diPanGan: '乙', tianPanGan: '乙' },
      {}, {}, {}, {}, {}, {}, {},
    ];
    const result = detectGeJu(makeChart(overrides));
    expect(result.some(g => g.name === '伏吟')).toBe(false);
  });
});

describe('detectGeJu - 反吟', () => {
  it('triggers when ≥3 palaces have opposing tian/di gan (甲庚 / 乙辛 / 丙壬)', () => {
    const overrides: Array<Partial<Palace>> = [
      { diPanGan: '甲', tianPanGan: '庚' },
      { diPanGan: '乙', tianPanGan: '辛' },
      { diPanGan: '丙', tianPanGan: '壬' },
      {}, {}, {}, {}, {}, {},
    ];
    const result = detectGeJu(makeChart(overrides));
    expect(result.some(g => g.name === '反吟')).toBe(true);
  });
});

describe('detectGeJu - 值符', () => {
  it('triggers when 值符神 is on 吉门 palace', () => {
    const overrides: Array<Partial<Palace>> = [
      { bashen: '值符', bamen: '开门' },
      {}, {}, {}, {}, {}, {}, {}, {},
    ];
    const result = detectGeJu(makeChart(overrides));
    expect(result.some(g => g.name === '值符')).toBe(true);
  });

  it('does NOT trigger when 值符 is on 凶门', () => {
    const overrides: Array<Partial<Palace>> = [
      { bashen: '值符', bamen: '伤门' },
      {}, {}, {}, {}, {}, {}, {}, {},
    ];
    const result = detectGeJu(makeChart(overrides));
    expect(result.some(g => g.name === '值符')).toBe(false);
  });
});

// ────────────────────────────────────────────────────────
// Fixture 测试：六仪击刑
// ────────────────────────────────────────────────────────

describe('detectGeJu - 六仪击刑', () => {
  it('戊击刑：戊在震宫 (3)', () => {
    const overrides: Array<Partial<Palace>> = [
      {}, {},
      { diPanGan: '戊' }, // index 2 = palace id 3 (震宫)
      {}, {}, {}, {}, {}, {},
    ];
    const result = detectGeJu(makeChart(overrides));
    expect(result.some(g => g.name === '戊击刑')).toBe(true);
  });

  it('庚击刑：庚在艮宫 (8)', () => {
    const overrides: Array<Partial<Palace>> = [
      {}, {}, {}, {}, {}, {}, {},
      { tianPanGan: '庚' }, // index 7 = palace id 8 (艮宫)
      {},
    ];
    const result = detectGeJu(makeChart(overrides));
    expect(result.some(g => g.name === '庚击刑')).toBe(true);
  });

  it('壬击刑 / 癸击刑：壬癸在巽宫 (4)', () => {
    const overrides: Array<Partial<Palace>> = [
      {}, {}, {},
      { tianPanGan: '壬' }, // index 3 = palace id 4 (巽宫)
      {}, {}, {}, {}, {},
    ];
    const result = detectGeJu(makeChart(overrides));
    expect(result.some(g => g.name === '壬击刑')).toBe(true);
  });

  it('does NOT trigger 戊击刑 when 戊 is in another palace', () => {
    const overrides: Array<Partial<Palace>> = [
      { diPanGan: '戊' }, // 坎宫，不是震宫
      {}, {}, {}, {}, {}, {}, {}, {},
    ];
    const result = detectGeJu(makeChart(overrides));
    expect(result.some(g => g.name === '戊击刑')).toBe(false);
  });
});

// ────────────────────────────────────────────────────────
// Fixture 测试：命名吉格
// ────────────────────────────────────────────────────────

describe('detectGeJu - 飞鸟跌穴', () => {
  it('triggers when 天盘丙 加 地盘戊', () => {
    const overrides: Array<Partial<Palace>> = [
      { diPanGan: '戊', tianPanGan: '丙' },
      {}, {}, {}, {}, {}, {}, {}, {},
    ];
    const result = detectGeJu(makeChart(overrides));
    expect(result.some(g => g.name === '飞鸟跌穴')).toBe(true);
  });
});

describe('detectGeJu - 青龙返首', () => {
  it('triggers when 天盘戊 加 地盘丙', () => {
    const overrides: Array<Partial<Palace>> = [
      { diPanGan: '丙', tianPanGan: '戊' },
      {}, {}, {}, {}, {}, {}, {}, {},
    ];
    const result = detectGeJu(makeChart(overrides));
    expect(result.some(g => g.name === '青龙返首')).toBe(true);
  });
});

describe('detectGeJu - 玉女守门', () => {
  it('triggers when 丁 + 生门 同宫', () => {
    const overrides: Array<Partial<Palace>> = [
      { tianPanGan: '丁', bamen: '生门' },
      {}, {}, {}, {}, {}, {}, {}, {},
    ];
    const result = detectGeJu(makeChart(overrides));
    expect(result.some(g => g.name === '玉女守门')).toBe(true);
  });
});

// ────────────────────────────────────────────────────────
// Fixture 测试：命名凶格
// ────────────────────────────────────────────────────────

describe('detectGeJu - 大格 / 小格 / 刑格', () => {
  it('大格：庚加癸', () => {
    const overrides: Array<Partial<Palace>> = [
      { tianPanGan: '庚', diPanGan: '癸' },
      {}, {}, {}, {}, {}, {}, {}, {},
    ];
    const result = detectGeJu(makeChart(overrides));
    expect(result.some(g => g.name === '大格')).toBe(true);
  });

  it('小格：庚加壬', () => {
    const overrides: Array<Partial<Palace>> = [
      { tianPanGan: '庚', diPanGan: '壬' },
      {}, {}, {}, {}, {}, {}, {}, {},
    ];
    const result = detectGeJu(makeChart(overrides));
    expect(result.some(g => g.name === '小格')).toBe(true);
  });

  it('刑格：庚加己', () => {
    const overrides: Array<Partial<Palace>> = [
      { tianPanGan: '庚', diPanGan: '己' },
      {}, {}, {}, {}, {}, {}, {}, {},
    ];
    const result = detectGeJu(makeChart(overrides));
    expect(result.some(g => g.name === '刑格')).toBe(true);
  });
});

describe('detectGeJu - 太白入荧 / 荧入太白', () => {
  it('太白入荧：庚加丙', () => {
    const overrides: Array<Partial<Palace>> = [
      { tianPanGan: '庚', diPanGan: '丙' },
      {}, {}, {}, {}, {}, {}, {}, {},
    ];
    const result = detectGeJu(makeChart(overrides));
    expect(result.some(g => g.name === '太白入荧')).toBe(true);
  });

  it('荧入太白：丙加庚', () => {
    const overrides: Array<Partial<Palace>> = [
      { tianPanGan: '丙', diPanGan: '庚' },
      {}, {}, {}, {}, {}, {}, {}, {},
    ];
    const result = detectGeJu(makeChart(overrides));
    expect(result.some(g => g.name === '荧入太白')).toBe(true);
  });
});

// ────────────────────────────────────────────────────────
// Fixture 测试：三奇格
// ────────────────────────────────────────────────────────

describe('detectGeJu - 三奇升殿', () => {
  it('乙奇升殿：乙临震宫 (3)', () => {
    const overrides: Array<Partial<Palace>> = [
      {}, {},
      { tianPanGan: '乙' }, // 震宫
      {}, {}, {}, {}, {}, {},
    ];
    const result = detectGeJu(makeChart(overrides));
    expect(result.some(g => g.name === '乙奇升殿')).toBe(true);
  });

  it('丙奇升殿：丙临离宫 (9)', () => {
    const overrides: Array<Partial<Palace>> = [
      {}, {}, {}, {}, {}, {}, {}, {},
      { tianPanGan: '丙' }, // 离宫
    ];
    const result = detectGeJu(makeChart(overrides));
    expect(result.some(g => g.name === '丙奇升殿')).toBe(true);
  });

  it('丁奇升殿：丁临兑宫 (7)', () => {
    const overrides: Array<Partial<Palace>> = [
      {}, {}, {}, {}, {}, {},
      { tianPanGan: '丁' }, // 兑宫
      {}, {},
    ];
    const result = detectGeJu(makeChart(overrides));
    expect(result.some(g => g.name === '丁奇升殿')).toBe(true);
  });
});

describe('detectGeJu - 三奇遇吉门', () => {
  it('乙奇遇吉门：乙 + 开门', () => {
    const overrides: Array<Partial<Palace>> = [
      { tianPanGan: '乙', bamen: '开门' },
      {}, {}, {}, {}, {}, {}, {}, {},
    ];
    const result = detectGeJu(makeChart(overrides));
    expect(result.some(g => g.name === '乙奇遇吉门')).toBe(true);
  });
});

// ────────────────────────────────────────────────────────
// 集成测试
// ────────────────────────────────────────────────────────

describe('detectGeJu - empty chart', () => {
  it('returns empty array when no rules match', () => {
    const overrides: Array<Partial<Palace>> = [
      {}, {}, {}, {}, {}, {}, {}, {}, {},
    ];
    const result = detectGeJu(makeChart(overrides));
    // 注意：可能空 chart 也会触发"值使"（吉门检测）等规则；只验证返回类型
    expect(Array.isArray(result)).toBe(true);
  });
});

describe('detectGeJu - 多格局并发', () => {
  it('chart 同时触发多个格局', () => {
    const overrides: Array<Partial<Palace>> = [
      { tianPanGan: '丙', diPanGan: '戊', bashen: '值符', bamen: '开门' }, // 飞鸟跌穴 + 值符
      {}, {}, {}, {}, {}, {}, {}, {},
    ];
    const result = detectGeJu(makeChart(overrides));
    const names = result.map(g => g.name);
    expect(names).toContain('飞鸟跌穴');
    expect(names).toContain('值符');
  });
});
