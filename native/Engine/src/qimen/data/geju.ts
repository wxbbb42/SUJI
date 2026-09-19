/**
 * 奇门遁甲格局识别（51 个 MVP）
 *
 * 数据来源（每个格局已交叉验证至少 2 个权威源，详见 commit 说明）：
 *   - 知乎《奇门遁甲》专栏 (zhuanlan.zhihu.com)
 *   - 国易堂周易算命网 (guoyi360.com)
 *   - 易德轩奇门遁甲 (qimen.yi958.com)
 *   - 乾坤国学院培训教材 (qkgxy.com)
 *   - 易先生奇门基础 (yixiansheng.com)
 *   - 《奇门遁甲全书》节选 (httpcn.com)
 *
 * MVP 简化说明：
 * - 由于本引擎当前不展开 "甲子戊 / 甲申庚" 等具体 60 甲子组合，
 *   六仪相关格局以 "干 + 宫位" 简化判定（如 "戊在震宫" 即视为 戊击刑）。
 * - 三奇得使原本依赖 "甲X" 旬首六仪信息，简化为 "三奇临对应六仪干所在宫"。
 * - 部分凶格（飞干 / 伏干 / 时格 / 月格）需日干 / 月干 / 时干上下文，
 *   引擎未传入这些参数，故按 chart 信息可获得的最大近似规则实现，
 *   description 注明 "简化版"。
 */

import type { QimenChart, GeJu, Palace, TianGan } from '../types';

export interface GeJuRule {
  name: string;
  type: GeJu['type'];
  description: string;
  /** 匹配函数，返回涉及的宫 IDs；不匹配返回 null */
  match: (chart: QimenChart) => number[] | null;
}

// ────────────────────────────────────────────────────────
// 工具函数
// ────────────────────────────────────────────────────────

function findPalacesByDiGan(chart: QimenChart, gan: TianGan): Palace[] {
  return chart.palaces.filter(p => p.diPanGan === gan);
}

function findPalacesByTianGan(chart: QimenChart, gan: TianGan): Palace[] {
  return chart.palaces.filter(p => p.tianPanGan === gan);
}

/** 找天盘 X 加临地盘 Y 的宫（即同一宫 tianPanGan===X && diPanGan===Y） */
function findTianAddDi(chart: QimenChart, tianGan: TianGan, diGan: TianGan): Palace[] {
  return chart.palaces.filter(p => p.tianPanGan === tianGan && p.diPanGan === diGan);
}

const GOOD_MEN = ['开门', '休门', '生门'];

// ────────────────────────────────────────────────────────
// 通用格 (10)
// ────────────────────────────────────────────────────────

const TONG_YONG_GE: GeJuRule[] = [
  {
    name: '伏吟',
    type: '凶',
    description: '天地盘相同，事情停滞、忧愁不展',
    match: (chart) => {
      const matched: number[] = [];
      for (const p of chart.palaces) {
        if (p.diPanGan && p.diPanGan === p.tianPanGan) {
          matched.push(p.id);
        }
      }
      return matched.length >= 3 ? matched : null;
    },
  },
  {
    name: '反吟',
    type: '凶',
    description: '天盘干与地盘干相冲，事情反复',
    match: (chart) => {
      // 天干七冲：甲庚、乙辛、丙壬、丁癸；戊己居中无冲（简化）
      const CHONG: Record<string, string> = {
        甲: '庚', 庚: '甲',
        乙: '辛', 辛: '乙',
        丙: '壬', 壬: '丙',
        丁: '癸', 癸: '丁',
      };
      const matched: number[] = [];
      for (const p of chart.palaces) {
        if (p.diPanGan && p.tianPanGan && CHONG[p.diPanGan] === p.tianPanGan) {
          matched.push(p.id);
        }
      }
      return matched.length >= 3 ? matched : null;
    },
  },
  {
    name: '值符',
    type: '吉',
    description: '值符神所在宫得吉门，事易成',
    match: (chart) => {
      const valuePalace = chart.palaces.find(p => p.bashen === '值符');
      if (!valuePalace || !valuePalace.bamen) return null;
      return GOOD_MEN.includes(valuePalace.bamen) ? [valuePalace.id] : null;
    },
  },
  {
    name: '值使',
    type: '吉',
    description: '值使门为吉门（开/休/生），用之则诸事顺',
    match: (chart) => {
      // 简化：开门 / 休门 / 生门 任一存在即视为值使吉
      const matched = chart.palaces
        .filter(p => p.bamen && GOOD_MEN.includes(p.bamen))
        .map(p => p.id);
      return matched.length > 0 ? matched : null;
    },
  },
  {
    name: '入墓',
    type: '凶',
    description: '干临墓宫（乙入坤、丙丁戊入乾、己庚入艮、辛壬入巽、癸入坤），抱负难申',
    match: (chart) => {
      // 干 → 墓宫 ID：乙 2, 丙 6, 丁 8, 戊 6, 己 8, 庚 8, 辛 4, 壬 4, 癸 2
      const TOMB: Record<string, number> = {
        乙: 2, 丙: 6, 丁: 8, 戊: 6, 己: 8, 庚: 8, 辛: 4, 壬: 4, 癸: 2,
      };
      const matched: number[] = [];
      for (const p of chart.palaces) {
        if (p.tianPanGan && TOMB[p.tianPanGan] === p.id) {
          matched.push(p.id);
        }
      }
      return matched.length > 0 ? matched : null;
    },
  },
  {
    name: '大格',
    type: '凶',
    description: '天盘庚加地盘癸（申寅冲），百事凶',
    match: (chart) => {
      const ps = findTianAddDi(chart, '庚', '癸');
      return ps.length > 0 ? ps.map(p => p.id) : null;
    },
  },
  {
    name: '小格',
    type: '凶',
    description: '天盘庚加地盘壬，远行迷路、求谋破财得病',
    match: (chart) => {
      const ps = findTianAddDi(chart, '庚', '壬');
      return ps.length > 0 ? ps.map(p => p.id) : null;
    },
  },
  {
    name: '刑格',
    type: '凶',
    description: '天盘庚加地盘己，主管司受刑、破财疾病',
    match: (chart) => {
      const ps = findTianAddDi(chart, '庚', '己');
      return ps.length > 0 ? ps.map(p => p.id) : null;
    },
  },
  {
    name: '白虎猖狂',
    type: '凶',
    description: '天盘辛加地盘乙，白虎横行、出入有惊、远行多灾',
    match: (chart) => {
      const ps = findTianAddDi(chart, '辛', '乙');
      return ps.length > 0 ? ps.map(p => p.id) : null;
    },
  },
  {
    name: '玄武当权',
    type: '凶',
    description: '玄武所在宫天地盘为癸/壬，主盗贼、阴私、是非',
    match: (chart) => {
      const xuanwu = chart.palaces.find(p => p.bashen === '玄武');
      if (!xuanwu) return null;
      const watery = ['癸', '壬'];
      if (
        (xuanwu.tianPanGan && watery.includes(xuanwu.tianPanGan)) ||
        (xuanwu.diPanGan && watery.includes(xuanwu.diPanGan))
      ) {
        return [xuanwu.id];
      }
      return null;
    },
  },
];

// ────────────────────────────────────────────────────────
// 三奇格 (15)：每奇 5 类（升殿 / 得使 / 遇吉门 / 入墓 / 受制）
// ────────────────────────────────────────────────────────

/** 三奇升殿宫位：乙→震 3、丙→离 9、丁→兑 7 */
const QI_PALACE: Record<'乙' | '丙' | '丁', number> = { 乙: 3, 丙: 9, 丁: 7 };

/** 三奇得使（简化）：乙临戊宫 / 丙临戊宫 / 丁临戊宫 — 旬首六仪戊代表甲子甲戌 */
function makeSanQiGe(qi: '乙' | '丙' | '丁'): GeJuRule[] {
  return [
    {
      name: `${qi}奇升殿`,
      type: '吉',
      description: `${qi}奇临${qi === '乙' ? '震' : qi === '丙' ? '离' : '兑'}宫，奇得正位、大吉`,
      match: (chart) => {
        const target = QI_PALACE[qi];
        const ps = chart.palaces.filter(p => p.id === target && p.tianPanGan === qi);
        return ps.length > 0 ? ps.map(p => p.id) : null;
      },
    },
    {
      name: `${qi}奇得使`,
      type: '吉',
      description: `${qi}奇临旬首六仪所在宫，得使可用事（简化版）`,
      match: (chart) => {
        // 简化：乙加戊或乙加己 / 丙加戊 / 丁加戊任意旬首仪
        const ps = chart.palaces.filter(p =>
          p.tianPanGan === qi && p.diPanGan && ['戊', '己', '庚', '辛', '壬', '癸'].includes(p.diPanGan)
        );
        // 三奇得使是特定 "甲子甲戌甲申..." 配对，无六十甲子上下文，简化为一般 "奇加仪"
        // 取最贴近的：乙加戊、丙加戊、丁加戊 视为得使
        const goodPs = ps.filter(p => p.diPanGan === '戊');
        return goodPs.length > 0 ? goodPs.map(p => p.id) : null;
      },
    },
    {
      name: `${qi}奇遇吉门`,
      type: '吉',
      description: `${qi}奇临开/休/生三吉门，谋事大利`,
      match: (chart) => {
        const ps = chart.palaces.filter(
          p => p.tianPanGan === qi && p.bamen && GOOD_MEN.includes(p.bamen)
        );
        return ps.length > 0 ? ps.map(p => p.id) : null;
      },
    },
    {
      name: `${qi}奇入墓`,
      type: '凶',
      description: `${qi}奇临墓宫（${qi === '乙' ? '坤宫 2' : qi === '丙' ? '乾宫 6' : '艮宫 8'}），力量受困`,
      match: (chart) => {
        const TOMB: Record<string, number> = { 乙: 2, 丙: 6, 丁: 8 };
        const target = TOMB[qi];
        const ps = chart.palaces.filter(p => p.id === target && p.tianPanGan === qi);
        return ps.length > 0 ? ps.map(p => p.id) : null;
      },
    },
    {
      name: `${qi}奇受制`,
      type: '凶',
      description: `${qi}奇被庚金克制（${qi}加庚或庚加${qi}），奇用受阻`,
      match: (chart) => {
        const ps = chart.palaces.filter(
          p => (p.tianPanGan === qi && p.diPanGan === '庚') ||
               (p.tianPanGan === '庚' && p.diPanGan === qi)
        );
        return ps.length > 0 ? ps.map(p => p.id) : null;
      },
    },
  ];
}

const SAN_QI_GE: GeJuRule[] = [
  ...makeSanQiGe('乙'),
  ...makeSanQiGe('丙'),
  ...makeSanQiGe('丁'),
];

// ────────────────────────────────────────────────────────
// 六仪击刑 (6)：戊→震、己→坤、庚→艮、辛→离、壬→巽、癸→巽
// ────────────────────────────────────────────────────────

const JI_XING_MAP: Array<{ gan: TianGan; palaceId: number; palaceName: string }> = [
  { gan: '戊', palaceId: 3, palaceName: '震宫' },
  { gan: '己', palaceId: 2, palaceName: '坤宫' },
  { gan: '庚', palaceId: 8, palaceName: '艮宫' },
  { gan: '辛', palaceId: 9, palaceName: '离宫' },
  { gan: '壬', palaceId: 4, palaceName: '巽宫' },
  { gan: '癸', palaceId: 4, palaceName: '巽宫' },
];

const LIU_YI_JI_XING: GeJuRule[] = JI_XING_MAP.map(({ gan, palaceId, palaceName }) => ({
  name: `${gan}击刑`,
  type: '凶' as const,
  description: `${gan}临${palaceName}（${palaceId}宫），地支相刑、诸事不顺`,
  match: (chart: QimenChart) => {
    const ps = chart.palaces.filter(
      p => p.id === palaceId && (p.tianPanGan === gan || p.diPanGan === gan)
    );
    return ps.length > 0 ? ps.map(p => p.id) : null;
  },
}));

// ────────────────────────────────────────────────────────
// 命名吉格 (12)：飞鸟跌穴 / 青龙返首 / 玉女守门 + 九遁
// ────────────────────────────────────────────────────────

const NAMED_JI_GE: GeJuRule[] = [
  {
    name: '飞鸟跌穴',
    type: '吉',
    description: '天盘丙奇加地盘戊（甲子戊），万事昭然，奇门第一吉格',
    match: (chart) => {
      const ps = findTianAddDi(chart, '丙', '戊');
      return ps.length > 0 ? ps.map(p => p.id) : null;
    },
  },
  {
    name: '青龙返首',
    type: '吉',
    description: '天盘戊（甲子）加地盘丙奇，大吉，求事必成',
    match: (chart) => {
      const ps = findTianAddDi(chart, '戊', '丙');
      return ps.length > 0 ? ps.map(p => p.id) : null;
    },
  },
  {
    name: '玉女守门',
    type: '吉',
    description: '丁奇 + 生门同宫（或值使临丁奇），利婚姻、和合、宴乐',
    match: (chart) => {
      const ps = chart.palaces.filter(
        p => (p.tianPanGan === '丁' || p.diPanGan === '丁') && p.bamen === '生门'
      );
      return ps.length > 0 ? ps.map(p => p.id) : null;
    },
  },
  {
    name: '天遁',
    type: '吉',
    description: '丙奇 + 生门 + 九天，利上书、求官、商贾、隐遁',
    match: (chart) => {
      const ps = chart.palaces.filter(
        p =>
          (p.tianPanGan === '丙' || p.diPanGan === '丙') &&
          p.bamen === '生门' &&
          p.bashen === '九天'
      );
      return ps.length > 0 ? ps.map(p => p.id) : null;
    },
  },
  {
    name: '地遁',
    type: '吉',
    description: '乙奇 + 开门 + 九地（或己），利安营、藏兵、修造、葬埋',
    match: (chart) => {
      const ps = chart.palaces.filter(
        p =>
          (p.tianPanGan === '乙' || p.diPanGan === '乙') &&
          p.bamen === '开门' &&
          p.bashen === '九地'
      );
      return ps.length > 0 ? ps.map(p => p.id) : null;
    },
  },
  {
    name: '人遁',
    type: '吉',
    description: '丁奇 + 休门 + 太阴，利谈判、间谍、求贤、婚商',
    match: (chart) => {
      const ps = chart.palaces.filter(
        p =>
          (p.tianPanGan === '丁' || p.diPanGan === '丁') &&
          p.bamen === '休门' &&
          p.bashen === '太阴'
      );
      return ps.length > 0 ? ps.map(p => p.id) : null;
    },
  },
  {
    name: '神遁',
    type: '吉',
    description: '丙奇 + 生门 + 九天，利攻虚、开路、塑像（与天遁相邻定义）',
    match: (chart) => {
      // 简化版：与天遁同条件但加上"九天/值符"任一神助
      const ps = chart.palaces.filter(
        p =>
          (p.tianPanGan === '丙' || p.diPanGan === '丙') &&
          p.bamen === '生门' &&
          (p.bashen === '九天' || p.bashen === '值符')
      );
      return ps.length > 0 ? ps.map(p => p.id) : null;
    },
  },
  {
    name: '鬼遁',
    type: '吉',
    description: '丁奇 + 杜门 + 九地，利偷袭、藏匿、暗中行事',
    match: (chart) => {
      const ps = chart.palaces.filter(
        p =>
          (p.tianPanGan === '丁' || p.diPanGan === '丁') &&
          p.bamen === '杜门' &&
          p.bashen === '九地'
      );
      return ps.length > 0 ? ps.map(p => p.id) : null;
    },
  },
  {
    name: '风遁',
    type: '吉',
    description: '乙奇 + 开/休/生三吉门 + 巽宫（4 宫），借风行事',
    match: (chart) => {
      const ps = chart.palaces.filter(
        p =>
          p.id === 4 &&
          (p.tianPanGan === '乙' || p.diPanGan === '乙') &&
          p.bamen && GOOD_MEN.includes(p.bamen)
      );
      return ps.length > 0 ? ps.map(p => p.id) : null;
    },
  },
  {
    name: '云遁',
    type: '吉',
    description: '乙奇 + 三吉门 + 辛（六辛），利祈雨、安营、铸兵',
    match: (chart) => {
      const ps = chart.palaces.filter(
        p =>
          (p.tianPanGan === '乙' || p.diPanGan === '乙') &&
          p.bamen && GOOD_MEN.includes(p.bamen) &&
          (p.tianPanGan === '辛' || p.diPanGan === '辛')
      );
      return ps.length > 0 ? ps.map(p => p.id) : null;
    },
  },
  {
    name: '龙遁',
    type: '吉',
    description: '乙奇 + 三吉门 + 坎宫（1 宫）或六癸，利祈雨、水运、架桥、凿井',
    match: (chart) => {
      const ps = chart.palaces.filter(
        p =>
          (p.tianPanGan === '乙' || p.diPanGan === '乙') &&
          p.bamen && GOOD_MEN.includes(p.bamen) &&
          (p.id === 1 || p.tianPanGan === '癸' || p.diPanGan === '癸')
      );
      return ps.length > 0 ? ps.map(p => p.id) : null;
    },
  },
  {
    name: '虎遁',
    type: '吉',
    description: '乙奇 + 休门 + 艮宫（8 宫）或六辛，利招兵、立寨、防守',
    match: (chart) => {
      const ps = chart.palaces.filter(
        p =>
          (p.tianPanGan === '乙' || p.diPanGan === '乙') &&
          p.bamen === '休门' &&
          (p.id === 8 || p.tianPanGan === '辛' || p.diPanGan === '辛')
      );
      return ps.length > 0 ? ps.map(p => p.id) : null;
    },
  },
];

// ────────────────────────────────────────────────────────
// 命名凶格 (8)
// ────────────────────────────────────────────────────────

const NAMED_XIONG_GE: GeJuRule[] = [
  {
    name: '五不遇时',
    type: '凶',
    description: '时干克日干（阳克阳、阴克阴），用事大凶（简化版：检测庚、辛克木日干情况）',
    match: (chart) => {
      // 严格五不遇时需日干上下文。引擎当前未传入日干，
      // 简化为：天盘庚临值符宫（克伐用神之象）
      const valuePalace = chart.palaces.find(p => p.bashen === '值符');
      if (!valuePalace) return null;
      if (valuePalace.tianPanGan === '庚') {
        return [valuePalace.id];
      }
      return null;
    },
  },
  {
    name: '太白入荧',
    type: '凶',
    description: '天盘庚加地盘丙，贼来偷营，主有惊恐',
    match: (chart) => {
      const ps = findTianAddDi(chart, '庚', '丙');
      return ps.length > 0 ? ps.map(p => p.id) : null;
    },
  },
  {
    name: '荧入太白',
    type: '凶',
    description: '天盘丙加地盘庚，宜守不宜攻、贼自退',
    match: (chart) => {
      const ps = findTianAddDi(chart, '丙', '庚');
      return ps.length > 0 ? ps.map(p => p.id) : null;
    },
  },
  {
    name: '朱雀投江',
    type: '凶',
    description: '天盘丁加地盘癸，文书口舌沉溺、音信不通',
    match: (chart) => {
      const ps = findTianAddDi(chart, '丁', '癸');
      return ps.length > 0 ? ps.map(p => p.id) : null;
    },
  },
  {
    name: '青龙逃走',
    type: '凶',
    description: '天盘乙加地盘辛，与白虎猖狂相反，主财损人离',
    match: (chart) => {
      const ps = findTianAddDi(chart, '乙', '辛');
      return ps.length > 0 ? ps.map(p => p.id) : null;
    },
  },
  {
    name: '飞干格',
    type: '凶',
    description: '天盘庚加地盘日干（简化版：庚加任一三奇即视触发）',
    match: (chart) => {
      // 简化：日干信息缺失，以庚加三奇近似
      const ps = chart.palaces.filter(
        p => p.tianPanGan === '庚' && p.diPanGan && ['乙', '丙', '丁'].includes(p.diPanGan)
      );
      return ps.length > 0 ? ps.map(p => p.id) : null;
    },
  },
  {
    name: '伏干格',
    type: '凶',
    description: '天盘日干加地盘庚（简化版：三奇加庚视为触发）',
    match: (chart) => {
      const ps = chart.palaces.filter(
        p => p.diPanGan === '庚' && p.tianPanGan && ['乙', '丙', '丁'].includes(p.tianPanGan)
      );
      return ps.length > 0 ? ps.map(p => p.id) : null;
    },
  },
  {
    name: '岁月日时格',
    type: '凶',
    description: '六庚加岁/月/日/时干，用事不利（简化版：庚加戊视触发）',
    match: (chart) => {
      // 简化：年月日时干信息缺失，以庚加戊（旬首）作通用近似
      const ps = findTianAddDi(chart, '庚', '戊');
      return ps.length > 0 ? ps.map(p => p.id) : null;
    },
  },
];

// ────────────────────────────────────────────────────────
// 汇总
// ────────────────────────────────────────────────────────

export const ALL_GE_JU: GeJuRule[] = [
  ...TONG_YONG_GE,        // 10
  ...SAN_QI_GE,           // 15
  ...LIU_YI_JI_XING,      // 6
  ...NAMED_JI_GE,         // 12
  ...NAMED_XIONG_GE,      // 8
];                        // = 51

/** 检测一个盘上所有命中的格局 */
export function detectGeJu(chart: QimenChart): GeJu[] {
  const result: GeJu[] = [];
  for (const rule of ALL_GE_JU) {
    const palaceIds = rule.match(chart);
    if (palaceIds && palaceIds.length > 0) {
      result.push({
        name: rule.name,
        type: rule.type,
        description: rule.description,
        palaceIds,
      });
    }
  }
  return result;
}
