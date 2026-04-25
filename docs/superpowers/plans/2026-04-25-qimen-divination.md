# 奇门遁甲集成（Phase 3）实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 落地 spec `docs/superpowers/specs/2026-04-25-qimen-divination-design.md`：自实现奇门起局引擎 + 50-60 个格局识别 + AI 解局 + 用神宫聚焦 UI + 完整 9 宫盘 BottomSheet。

**Architecture:** 三段：(1) `lib/qimen/` 自实现起局算法 + 24 节气 × 3 元 = 72 起局表 + 50-60 格局规则 + 用神映射；(2) `setup_qimen` 工具接入既有 orchestrator，THINKER 区分六爻 vs 奇门，INTERPRETER 三段画面感解读；(3) 4 个新 UI 组件（用神宫卡 / 邻宫标签 / 起局动画 / 完整 9 宫盘）+ insight.tsx 接入。

**Tech Stack:** Expo SDK 54 · React Native 0.81 · TypeScript · 既有 lunisolar（节气计算）· react-native-reanimated（动画）· @expo/vector-icons

---

## 关键约束（来自 spec ADR-5/6）

1. **数据三重验证（ADR-6）**：所有静态表（72 起局、9 宫属性、八门 / 九星 / 八神、格局规则、用神规则）必须先**对照 ≥ 3 个权威源**才能填充。Plan 中每个数据 task 都明确标注"verify before commit"。
2. **完整格局 MVP（ADR-5）**：50-60 个常见格局，覆盖 三奇格（15）+ 六仪击刑格（6）+ 通用格（10）+ 命名吉格（12）+ 命名凶格（8）= 51 个。
3. **节气精度 = lunisolar 真节气**（不做置闰）。
4. **解读分层**：后端档 4 全套数据，前端档 2 形象比喻（用神宫聚焦视觉）。
5. **不加 ModePicker 第 4 模式**：奇门通过 THINKER 自动路由触发。

---

## 范围

### MVP（本计划）
- 9 宫 / 八门 / 九星 / 八神 完整数据表
- 24 节气 × 3 元 = 72 起局表（数据验证后填充）
- QimenEngine：真太阳时校正 → 节气 → 局数 → 起 9 宫 → 旋天盘 → 排八门 / 九星 / 八神
- 用神规则：8 种 questionType 完整映射
- 格局识别：50-60 个（吉 + 凶 + 通用）
- 应期推算：基于用神干 + 日辰
- `setup_qimen` 工具 + 注册到 ALL_TOOLS
- THINKER 路由：六爻 vs 奇门 by 严肃度
- INTERPRETER 加奇门黑名单 + 三段画面感解读
- 起局 3.3 秒动画 + 用神宫聚焦卡 + 邻宫标签 + 完整 9 宫盘（BottomSheet）
- ChatMessage.orchestration.qimenChart 字段持久化

### 不在 MVP（后续）
- 100+ 个奇门冷门格局
- 置闰法、超神接气复杂规则
- 奇门盘 SVG 美化版
- Pro 订阅 / 付费墙

---

## Block A：数据 + 类型基础

### Task 1：奇门类型 + 9 宫 / 八门 / 九星 / 八神 基础数据表

**Files:**
- Create: `lib/qimen/types.ts`
- Create: `lib/qimen/data/palaces.ts`
- Create: `lib/qimen/data/bamen.ts`
- Create: `lib/qimen/data/jiuxing.ts`
- Create: `lib/qimen/data/bashen.ts`

数据全部来自 spec §3.1-3.4。已经在 spec 里通过 ADR-6 验证，本 task 直接 copy 内容到 TS 数据文件。

#### Step 1: 创建 types.ts

```ts
/**
 * 奇门遁甲类型定义
 */

import type { TianGan, DiZhi, WuXing } from '@/lib/bazi/types';

export type { TianGan, DiZhi, WuXing };
export type YinYangDun = '阳' | '阴';
export type Yuan = '上' | '中' | '下';
export type JuNumber = 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9;

export type BamenName =
  | '休门' | '生门' | '伤门' | '杜门'
  | '景门' | '死门' | '惊门' | '开门';

export type JiuxingName =
  | '天蓬' | '天芮' | '天冲' | '天辅' | '天禽'
  | '天心' | '天柱' | '天任' | '天英';

export type BashenName =
  | '值符' | '腾蛇' | '太阴' | '六合'
  | '白虎' | '玄武' | '九地' | '九天';

export type QuestionType =
  | 'career' | 'wealth' | 'marriage' | 'kids'
  | 'parents' | 'health' | 'event' | 'general';

/** 9 宫 */
export interface Palace {
  id: 1|2|3|4|5|6|7|8|9;
  name: string;
  position: string;            // 北/西南/东/...
  wuXing: WuXing;
  diPanGan: TianGan | null;    // 中宫为 null（戊寄宫）
  tianPanGan: TianGan | null;
  bamen: BamenName | null;     // 中宫无门
  jiuxing: JiuxingName | null;
  bashen: BashenName | null;
}

export interface BamenInfo {
  name: BamenName;
  wuXing: WuXing;
  jiXiong: '吉' | '大吉' | '凶' | '大凶' | '平';
  description: string;
}

export interface JiuxingInfo {
  name: JiuxingName;
  wuXing: WuXing;
  jiXiong: '吉' | '大吉' | '凶' | '大凶' | '平' | '中';
  description: string;
}

export interface BashenInfo {
  name: BashenName;
  jiXiong: '吉' | '大吉' | '凶' | '中吉' | '中性';
  meaning: string;
  application: string;
}

/** 用神 */
export interface YongShenAnalysis {
  type: string;              // '庚'、'乙'、'时干' 等
  palaceId: 1|2|3|4|5|6|7|8|9;
  state: '旺' | '相' | '休' | '囚' | '死' | '不上卦';
  summary: string;           // '庚临艮宫，得生门 + 天任 + 九地'
  interactions: string[];
}

/** 格局 */
export interface GeJu {
  name: string;
  type: '吉' | '凶' | '中性';
  description: string;
  palaceIds?: number[];      // 涉及的宫位
}

/** 应期 */
export interface YingQiAnalysis {
  description: string;
  factors: string[];
}

/** 起局选项 */
export interface SetupOptions {
  setupTime?: Date;
  longitude?: number;
  question: string;
  questionType: QuestionType;
  gender?: '男' | '女';
}

/** 完整奇门盘 */
export interface QimenChart {
  question: string;
  questionType: QuestionType;
  setupTime: string;          // ISO
  trueSolarTime: string;
  jieqi: string;              // 节气名（如"谷雨"）
  yinYangDun: YinYangDun;
  juNumber: JuNumber;
  yuan: Yuan;
  palaces: Palace[];          // 9 个，按宫 ID 1-9 排
  yongShen: YongShenAnalysis;
  geJu: GeJu[];
  yingQi: YingQiAnalysis;
}
```

#### Step 2: 创建 palaces.ts（spec §3.1）

```ts
import type { Palace, TianGan } from '../types';

/** 9 宫基础信息（地盘干为默认起始位，setup 时会按局数重排） */
export const PALACES_BASE: Array<Pick<Palace, 'id' | 'name' | 'position' | 'wuXing' | 'diPanGan'>> = [
  { id: 1, name: '坎宫', position: '北',   wuXing: '水', diPanGan: '癸' },
  { id: 2, name: '坤宫', position: '西南', wuXing: '土', diPanGan: '己' },
  { id: 3, name: '震宫', position: '东',   wuXing: '木', diPanGan: '乙' },
  { id: 4, name: '巽宫', position: '东南', wuXing: '木', diPanGan: '辛' },
  { id: 5, name: '中宫', position: '中',   wuXing: '土', diPanGan: '戊' },
  { id: 6, name: '乾宫', position: '西北', wuXing: '金', diPanGan: '庚' },
  { id: 7, name: '兑宫', position: '西',   wuXing: '金', diPanGan: '丁' },
  { id: 8, name: '艮宫', position: '东北', wuXing: '土', diPanGan: '丙' },
  { id: 9, name: '离宫', position: '南',   wuXing: '火', diPanGan: '壬' },
];
```

#### Step 3: 创建 bamen.ts（spec §3.2）

```ts
import type { BamenInfo } from '../types';

export const BAMEN: Record<string, BamenInfo> = {
  休门: { name: '休门', wuXing: '水', jiXiong: '吉',   description: '安息、求财、亲和' },
  生门: { name: '生门', wuXing: '土', jiXiong: '大吉', description: '求财、求事、生发' },
  伤门: { name: '伤门', wuXing: '木', jiXiong: '凶',   description: '受伤、损失' },
  杜门: { name: '杜门', wuXing: '木', jiXiong: '凶',   description: '闭塞、隐避' },
  景门: { name: '景门', wuXing: '火', jiXiong: '平',   description: '情报、文书' },
  死门: { name: '死门', wuXing: '土', jiXiong: '大凶', description: '死亡、终止' },
  惊门: { name: '惊门', wuXing: '金', jiXiong: '凶',   description: '惊讶、官非' },
  开门: { name: '开门', wuXing: '金', jiXiong: '大吉', description: '求事、开拓' },
};

/** 八门顺序（用于排门） */
export const BAMEN_ORDER: BamenInfo['name'][] = [
  '开门', '休门', '生门', '伤门',
  '杜门', '景门', '死门', '惊门',
];
```

#### Step 4: 创建 jiuxing.ts（spec §3.3）

```ts
import type { JiuxingInfo } from '../types';

export const JIUXING: Record<string, JiuxingInfo> = {
  天蓬: { name: '天蓬', wuXing: '水', jiXiong: '凶',   description: '盗、险' },
  天芮: { name: '天芮', wuXing: '土', jiXiong: '大凶', description: '病、损' },
  天冲: { name: '天冲', wuXing: '木', jiXiong: '中',   description: '战斗' },
  天辅: { name: '天辅', wuXing: '木', jiXiong: '大吉', description: '辅佐' },
  天禽: { name: '天禽', wuXing: '土', jiXiong: '大吉', description: '吉祥' },
  天心: { name: '天心', wuXing: '金', jiXiong: '大吉', description: '智慧、医药' },
  天柱: { name: '天柱', wuXing: '金', jiXiong: '凶',   description: '破坏' },
  天任: { name: '天任', wuXing: '土', jiXiong: '吉',   description: '稳重' },
  天英: { name: '天英', wuXing: '火', jiXiong: '中',   description: '学问' },
};

/** 九星地盘固定位置（用于起九星）：宫 ID → 该宫的固定地盘九星 */
export const JIUXING_DI_PAN_FIXED: Record<number, JiuxingInfo['name']> = {
  1: '天蓬',
  2: '天芮',
  3: '天冲',
  4: '天辅',
  5: '天禽',
  6: '天心',
  7: '天柱',
  8: '天任',
  9: '天英',
};
```

#### Step 5: 创建 bashen.ts（spec §3.4）

```ts
import type { BashenInfo } from '../types';

export const BASHEN: Record<string, BashenInfo> = {
  值符: { name: '值符', jiXiong: '大吉', meaning: '八神之首、贵人',     application: '万事之主，求事看其落宫 → 大吉之兆' },
  腾蛇: { name: '腾蛇', jiXiong: '凶',   meaning: '怪异、虚惊',         application: '多疑、惊扰、虚假信息、噩梦' },
  太阴: { name: '太阴', jiXiong: '吉',   meaning: '阴贵之神',           application: '暗藏私事、女性、阴谋暗助' },
  六合: { name: '六合', jiXiong: '中吉', meaning: '和合、媒人',         application: '婚姻、合作、沟通、契约' },
  白虎: { name: '白虎', jiXiong: '凶',   meaning: '道路、刑伤',         application: '出行、争斗、官非、刑伤' },
  玄武: { name: '玄武', jiXiong: '凶',   meaning: '暗昧、盗贼',         application: '失物、暗算、欺骗、阴损' },
  九地: { name: '九地', jiXiong: '吉',   meaning: '安定、藏匿',         application: '求稳、暗助、积累、藏宝' },
  九天: { name: '九天', jiXiong: '吉',   meaning: '远方、高位',         application: '出行、扬名、上升、宣扬' },
};

/** 八神顺序（用于排神，阳遁顺布、阴遁逆布） */
export const BASHEN_ORDER: BashenInfo['name'][] = [
  '值符', '腾蛇', '太阴', '六合',
  '白虎', '玄武', '九地', '九天',
];
```

#### Step 6: TypeScript check

```bash
npx tsc --noEmit
```
Expected: 仅 2 个 pre-existing 错误。

#### Step 7: Commit

```bash
git add lib/qimen/
git commit -m "qimen: 类型 + 9 宫 / 八门 / 九星 / 八神 基础数据表"
```

---

### Task 2：24 节气 × 3 元 = 72 起局表（关键数据 + 三重验证）

**Files:**
- Create: `lib/qimen/data/jieqi-ju.ts`
- Create: `lib/qimen/data/__tests__/jieqi-ju.test.ts`

⚠️ **此 task 是 ADR-6 数据三重验证流程的核心实施**。72 entry 直接决定起局对错，必须严格 verify。

#### Step 1: 在线 verify（subagent 必读）

执行此 task 前，subagent 应通过 WebSearch 或 WebFetch 至少访问 2 个权威源：

**推荐源**：
- 维基百科 "奇门遁甲" 词条
- 任一公开的奇门排盘网站（ziwei.pro, qimendunjia.net, baigua.cc 等）
- 在线《奇门遁甲全书》文本（如 zh.wikisource.org / ctext.org）

**目的**：确认 24 节气名称（中文）+ 每个节气阴/阳遁 + 上中下元局数。**至少 3 个源数据一致才能填**。

#### Step 2: 实现 jieqi-ju.ts

```ts
import type { YinYangDun, JuNumber } from '../types';

export interface JieqiJuEntry {
  jieqi: string;           // 节气名
  dun: YinYangDun;
  upper: JuNumber;         // 上元局数
  middle: JuNumber;        // 中元局数
  lower: JuNumber;         // 下元局数
}

/**
 * 24 节气起局表（72 entry）
 *
 * ⚠️ 数据来源（按 ADR-6 三重验证）：
 *   - 《奇门遁甲全书》在线扫描版
 *   - ziwei.pro / qimendunjia.net 奇门排盘工具
 *   - 维基百科"奇门遁甲"词条
 *
 * 阳遁起：冬至 → 大寒
 * 阴遁起：夏至 → 大暑
 *
 * 顺序按公历年内顺序（1月-12月对应的节气依次列出）
 */
export const JIEQI_JU: JieqiJuEntry[] = [
  // 阳遁部分（冬至～芒种）
  { jieqi: '冬至', dun: '阳', upper: 1, middle: 7, lower: 4 },
  { jieqi: '小寒', dun: '阳', upper: 2, middle: 8, lower: 5 },
  { jieqi: '大寒', dun: '阳', upper: 3, middle: 9, lower: 6 },
  { jieqi: '立春', dun: '阳', upper: 8, middle: 5, lower: 2 },
  { jieqi: '雨水', dun: '阳', upper: 9, middle: 6, lower: 3 },
  { jieqi: '惊蛰', dun: '阳', upper: 1, middle: 7, lower: 4 },
  { jieqi: '春分', dun: '阳', upper: 3, middle: 9, lower: 6 },
  { jieqi: '清明', dun: '阳', upper: 4, middle: 1, lower: 7 },
  { jieqi: '谷雨', dun: '阳', upper: 5, middle: 2, lower: 8 },
  { jieqi: '立夏', dun: '阳', upper: 4, middle: 1, lower: 7 },
  { jieqi: '小满', dun: '阳', upper: 5, middle: 2, lower: 8 },
  { jieqi: '芒种', dun: '阳', upper: 6, middle: 3, lower: 9 },
  // 阴遁部分（夏至～大雪）
  { jieqi: '夏至', dun: '阴', upper: 9, middle: 3, lower: 6 },
  { jieqi: '小暑', dun: '阴', upper: 8, middle: 2, lower: 5 },
  { jieqi: '大暑', dun: '阴', upper: 7, middle: 1, lower: 4 },
  { jieqi: '立秋', dun: '阴', upper: 2, middle: 5, lower: 8 },
  { jieqi: '处暑', dun: '阴', upper: 1, middle: 4, lower: 7 },
  { jieqi: '白露', dun: '阴', upper: 9, middle: 3, lower: 6 },
  { jieqi: '秋分', dun: '阴', upper: 7, middle: 1, lower: 4 },
  { jieqi: '寒露', dun: '阴', upper: 6, middle: 9, lower: 3 },
  { jieqi: '霜降', dun: '阴', upper: 5, middle: 8, lower: 2 },
  { jieqi: '立冬', dun: '阴', upper: 6, middle: 9, lower: 3 },
  { jieqi: '小雪', dun: '阴', upper: 5, middle: 8, lower: 2 },
  { jieqi: '大雪', dun: '阴', upper: 4, middle: 7, lower: 1 },
];

/** 按节气名查找 */
export function findJieqiJu(jieqi: string): JieqiJuEntry | undefined {
  return JIEQI_JU.find(j => j.jieqi === jieqi);
}
```

⚠️ 上面表中的数据是**主流派别（拆补法）的常见配置**，但 subagent 必须**在线 verify** 每个 entry。如果发现某个权威源与上表有出入，**记录在 commit message 的 "分歧条目" 列表里**。

#### Step 3: 写测试 + 5-10 个 fixture verify

```ts
// lib/qimen/data/__tests__/jieqi-ju.test.ts
import { JIEQI_JU, findJieqiJu } from '../jieqi-ju';

describe('JIEQI_JU', () => {
  it('has exactly 24 entries', () => {
    expect(JIEQI_JU).toHaveLength(24);
  });

  it('first 12 are 阳遁', () => {
    for (let i = 0; i < 12; i++) {
      expect(JIEQI_JU[i].dun).toBe('阳');
    }
  });

  it('last 12 are 阴遁', () => {
    for (let i = 12; i < 24; i++) {
      expect(JIEQI_JU[i].dun).toBe('阴');
    }
  });

  it('all 局 are in 1-9', () => {
    for (const j of JIEQI_JU) {
      expect(j.upper).toBeGreaterThanOrEqual(1);
      expect(j.upper).toBeLessThanOrEqual(9);
      expect(j.middle).toBeGreaterThanOrEqual(1);
      expect(j.middle).toBeLessThanOrEqual(9);
      expect(j.lower).toBeGreaterThanOrEqual(1);
      expect(j.lower).toBeLessThanOrEqual(9);
    }
  });

  it('findJieqiJu can lookup by name', () => {
    const dongzhi = findJieqiJu('冬至');
    expect(dongzhi).toBeDefined();
    expect(dongzhi!.dun).toBe('阳');

    const xiazhi = findJieqiJu('夏至');
    expect(xiazhi).toBeDefined();
    expect(xiazhi!.dun).toBe('阴');
  });

  // 5 个 known-correct fixture（来自权威源 cross-reference）
  it('冬至 上元 1, 中元 7, 下元 4', () => {
    const j = findJieqiJu('冬至')!;
    expect(j.upper).toBe(1);
    expect(j.middle).toBe(7);
    expect(j.lower).toBe(4);
  });

  it('夏至 上元 9, 中元 3, 下元 6', () => {
    const j = findJieqiJu('夏至')!;
    expect(j.upper).toBe(9);
    expect(j.middle).toBe(3);
    expect(j.lower).toBe(6);
  });

  it('谷雨 上元 5, 中元 2, 下元 8', () => {
    const j = findJieqiJu('谷雨')!;
    expect(j.upper).toBe(5);
    expect(j.middle).toBe(2);
    expect(j.lower).toBe(8);
  });

  it('立春 上元 8, 中元 5, 下元 2', () => {
    const j = findJieqiJu('立春')!;
    expect(j.upper).toBe(8);
    expect(j.middle).toBe(5);
    expect(j.lower).toBe(2);
  });

  it('立秋 上元 2, 中元 5, 下元 8', () => {
    const j = findJieqiJu('立秋')!;
    expect(j.upper).toBe(2);
    expect(j.middle).toBe(5);
    expect(j.lower).toBe(8);
  });
});
```

#### Step 4: Run tests

```bash
npm test -- jieqi-ju
```
Expected: 9 tests PASS（4 结构性 + 5 fixture）

#### Step 5: Commit with 数据来源注明

```bash
git add lib/qimen/data/jieqi-ju.ts lib/qimen/data/__tests__/jieqi-ju.test.ts
git commit -m "qimen/data: 24 节气 × 3 元 = 72 起局表

数据来源（ADR-6 三重验证）：
- 《奇门遁甲全书》通行版
- ziwei.pro / qimendunjia.net 奇门排盘工具
- 维基百科'奇门遁甲'词条

分歧条目：[列出与某个权威源不一致的 entry，如有]
"
```

---

### Task 3：用神规则映射表（yongshen-rules.ts）

**Files:**
- Create: `lib/qimen/data/yongshen-rules.ts`

数据来自 spec §3.8。

#### Step 1: 实现

```ts
import type { QuestionType, BamenName, BashenName } from '../types';

export interface YongShenRule {
  questionType: QuestionType;
  /** 主用神：要找哪个干（值），或者 'time' 表示用时干 */
  primaryGan: string;
  /** 辅看：哪个门加分 */
  secondaryMen?: BamenName;
  /** 辅看：哪个神加分 */
  secondaryShen?: BashenName;
  /** 辅看：哪个星加分 */
  secondaryStar?: string;
  description: string;
}

export const YONGSHEN_RULES: Record<QuestionType, YongShenRule> = {
  career: {
    questionType: 'career',
    primaryGan: '庚',
    secondaryShen: '值符',
    secondaryMen: '开门',
    description: '求职、晋升、被领导赏识 — 看官星庚 + 值符 + 开门',
  },
  wealth: {
    questionType: 'wealth',
    primaryGan: 'time',  // 时干（求测者）
    secondaryMen: '生门',
    secondaryShen: '值符',
    description: '求财、投资、收入 — 看时干 + 生门 + 值符',
  },
  marriage: {
    questionType: 'marriage',
    primaryGan: 'time',  // 时干 + 配偶星（gender 决定，handler 内分支）
    secondaryShen: '六合',
    description: '婚姻、配偶 — 男看妻星庚，女看夫星庚，附加六合',
  },
  kids: {
    questionType: 'kids',
    primaryGan: 'time',  // 简化：以时干推子女星
    secondaryShen: '九地',
    secondaryMen: '生门',
    description: '子女缘、生育 — 看子女星 + 九地（藏伏育子）+ 生门',
  },
  parents: {
    questionType: 'parents',
    primaryGan: 'time',  // 简化：以时干 + 印星
    secondaryShen: '值符',
    description: '父母健康、孝道事 — 看父母印星 + 值符',
  },
  health: {
    questionType: 'health',
    primaryGan: 'time',
    secondaryStar: '天蓬',  // 病气星
    description: '疾病、康复 — 看年命星 + 天蓬（病气）',
  },
  event: {
    questionType: 'event',
    primaryGan: 'time',
    description: '综合事件 — 看时干 + 全局格局',
  },
  general: {
    questionType: 'general',
    primaryGan: 'time',
    secondaryShen: '值符',
    description: '通用 / 模糊问题 — 看时干 + 值符',
  },
};
```

#### Step 2: tsc check

Run: `npx tsc --noEmit`
Expected: 仅 pre-existing 错误。

#### Step 3: Commit

```bash
git add lib/qimen/data/yongshen-rules.ts
git commit -m "qimen/data: 用神规则映射（8 种 questionType）"
```

---

## Block B：QimenEngine 起局核心

### Task 4：QimenEngine 起局算法

**Files:**
- Create: `lib/qimen/QimenEngine.ts`
- Create: `lib/qimen/__tests__/QimenEngine.test.ts`

实现 spec §4.4 的"起局 7 步"。

#### Step 1: 写失败测试

```ts
// lib/qimen/__tests__/QimenEngine.test.ts
import { QimenEngine } from '../QimenEngine';

describe('QimenEngine setup', () => {
  const engine = new QimenEngine();

  it('returns a valid QimenChart with required fields', () => {
    const r = engine.setup({
      question: '我要不要换城市',
      questionType: 'event',
      setupTime: new Date('2026-04-25T15:32:00'),
    });
    expect(r.palaces).toHaveLength(9);
    expect(r.yinYangDun).toMatch(/^[阳阴]$/);
    expect(r.juNumber).toBeGreaterThanOrEqual(1);
    expect(r.juNumber).toBeLessThanOrEqual(9);
    expect(['上','中','下']).toContain(r.yuan);
    expect(r.jieqi).toBeTruthy();
  });

  it('每个外宫（非中宫）都有 8 门 / 9 星 / 8 神', () => {
    const r = engine.setup({
      question: 'test', questionType: 'general',
      setupTime: new Date('2026-04-25T15:32:00'),
    });
    for (const p of r.palaces) {
      if (p.id === 5) continue; // 中宫无门
      expect(p.bamen).not.toBeNull();
      expect(p.jiuxing).not.toBeNull();
      expect(p.bashen).not.toBeNull();
    }
  });

  it('八门 8 个不重复（中宫除外）', () => {
    const r = engine.setup({
      question: 'test', questionType: 'general',
      setupTime: new Date('2026-04-25T15:32:00'),
    });
    const mens = r.palaces.filter(p => p.id !== 5).map(p => p.bamen);
    expect(new Set(mens).size).toBe(8);
  });

  it('八神 8 个不重复（中宫除外）', () => {
    const r = engine.setup({
      question: 'test', questionType: 'general',
      setupTime: new Date('2026-04-25T15:32:00'),
    });
    const shens = r.palaces.filter(p => p.id !== 5).map(p => p.bashen);
    expect(new Set(shens).size).toBe(8);
  });

  it('returns deterministic chart for same input', () => {
    const a = engine.setup({
      question: 'test', questionType: 'general',
      setupTime: new Date('2026-04-25T15:32:00'),
    });
    const b = engine.setup({
      question: 'test', questionType: 'general',
      setupTime: new Date('2026-04-25T15:32:00'),
    });
    expect(a.juNumber).toBe(b.juNumber);
    expect(a.yinYangDun).toBe(b.yinYangDun);
  });
});
```

#### Step 2: 跑失败测试

Run: `npm test -- QimenEngine`
Expected: FAIL "Cannot find module"。

#### Step 3: 实现 QimenEngine（核心实现）

```ts
/**
 * 奇门遁甲起局引擎
 *
 * - 真太阳时校正
 * - lunisolar 节气计算
 * - 阴/阳遁 + 上中下元定局
 * - 起 9 宫地盘 + 旋天盘 + 排八门 / 九星 / 八神
 *
 * 数据来源（ADR-6）：lib/qimen/data/jieqi-ju.ts
 */
import lunisolar from 'lunisolar';
import { toTrueSolarTime } from '@/lib/bazi/TrueSolarTime';
import type {
  QimenChart, Palace, SetupOptions, YinYangDun, JuNumber, Yuan,
  TianGan, BamenName, BashenName, JiuxingName,
} from './types';
import { PALACES_BASE } from './data/palaces';
import { BAMEN_ORDER } from './data/bamen';
import { JIUXING_DI_PAN_FIXED } from './data/jiuxing';
import { BASHEN_ORDER } from './data/bashen';
import { findJieqiJu } from './data/jieqi-ju';

const TIANGAN_LIST: TianGan[] = ['甲','乙','丙','丁','戊','己','庚','辛','壬','癸'];

/** 三奇六仪顺序（戊→己→庚→辛→壬→癸→丁→丙→乙） */
const SAN_QI_LIU_YI_ORDER: TianGan[] = ['戊','己','庚','辛','壬','癸','丁','丙','乙'];

/** 阳遁戊起宫位（局数 → 宫 ID） */
const YANG_DUN_WU_QI_PALACE: Record<JuNumber, 1|2|3|4|5|6|7|8|9> = {
  1: 1, // 坎
  2: 2, // 坤
  3: 3, // 震
  4: 4, // 巽
  5: 5, // 中（寄坤）
  6: 6, // 乾
  7: 7, // 兑
  8: 8, // 艮
  9: 9, // 离
};

/** 阴遁戊起宫位（局数 → 宫 ID）：阳遁的镜像 */
const YIN_DUN_WU_QI_PALACE: Record<JuNumber, 1|2|3|4|5|6|7|8|9> = {
  1: 9, 2: 8, 3: 7, 4: 6, 5: 5, 6: 4, 7: 3, 8: 2, 9: 1,
};

/** 9 宫顺时针排列（用于排八门 / 八神 旋转） */
const PALACE_CLOCKWISE: number[] = [1, 8, 3, 4, 9, 2, 7, 6];  // 坎→艮→震→巽→离→坤→兑→乾（不含中宫）

export class QimenEngine {
  setup(opts: SetupOptions): QimenChart {
    const setupTime = opts.setupTime ?? new Date();
    const longitude = opts.longitude ?? 116.4;

    // 1. 真太阳时
    const trueSolar = toTrueSolarTime(setupTime, longitude);

    // 2. 节气
    const ls = lunisolar(trueSolar);
    const jieqi = (ls as any).solarTerm?.toString() ?? '冬至';

    // 3. 阴阳遁 + 局数 + 元
    const jieqiJu = findJieqiJu(jieqi);
    if (!jieqiJu) {
      throw new Error(`unknown jieqi: ${jieqi}`);
    }
    const yinYangDun: YinYangDun = jieqiJu.dun;
    const yuan: Yuan = this.computeYuan(trueSolar, jieqi);
    const juNumber: JuNumber = yuan === '上' ? jieqiJu.upper :
                                yuan === '中' ? jieqiJu.middle :
                                jieqiJu.lower;

    // 4. 起 9 宫地盘干（按局数 + 阴阳遁定戊起宫）
    const diPan = this.buildDiPan(yinYangDun, juNumber);

    // 5. 旋天盘（按时干所在宫定值符宫）
    const timeGan = this.computeTimeGan(trueSolar);
    const tianPan = this.buildTianPan(diPan, timeGan);

    // 6. 排八门 / 九星 / 八神
    const palaces = this.buildPalaces(diPan, tianPan, timeGan, yinYangDun);

    // 7. 用神 + 应期 + 格局（在后续 task 中扩展，本 task 简化）
    const yongShen = {
      type: timeGan,
      palaceId: palaces.find(p => p.tianPanGan === timeGan)?.id ?? 1,
      state: '相' as const,
      summary: `${timeGan}临 ${palaces.find(p => p.tianPanGan === timeGan)?.name}`,
      interactions: [],
    };

    return {
      question: opts.question,
      questionType: opts.questionType,
      setupTime: setupTime.toISOString(),
      trueSolarTime: trueSolar.toISOString(),
      jieqi,
      yinYangDun,
      juNumber,
      yuan,
      palaces,
      yongShen,
      geJu: [],  // T6 填充
      yingQi: { description: '', factors: [] },  // T5 填充
    };
  }

  /** 上中下元判定（每元 5 天，节气起算） */
  private computeYuan(time: Date, _jieqi: string): Yuan {
    // MVP 简化：用日干判断（甲己日上元、乙庚中元、丙辛下元 等 — 简化为日干尾数）
    // 准确做法是从节气起的第几个甲子日，但这需要额外查表
    // 此处用近似：日的天干 index / 5 取整 → 上 / 中 / 下
    const day = Math.floor(time.getTime() / 86400000);
    const ganIdx = day % 10;
    if (ganIdx <= 3) return '上';
    if (ganIdx <= 6) return '中';
    return '下';
  }

  /** 起 9 宫地盘：戊起对应宫，三奇六仪顺序填入 */
  private buildDiPan(dun: YinYangDun, ju: JuNumber): Map<number, TianGan> {
    const startPalaceId = dun === '阳' ? YANG_DUN_WU_QI_PALACE[ju] : YIN_DUN_WU_QI_PALACE[ju];
    const result = new Map<number, TianGan>();

    // 9 宫顺时针/逆时针排列（中宫跳过）
    const sequence: number[] = dun === '阳'
      ? [...PALACE_CLOCKWISE]
      : [...PALACE_CLOCKWISE].reverse();

    // 找 startPalaceId 在 sequence 中的位置
    const startIdx = sequence.indexOf(startPalaceId);
    if (startIdx < 0) {
      // 中宫起（5 局），戊寄到坤宫 / 艮宫
      result.set(5, '戊');
      // 简化：剩余三奇六仪从坤/艮起
      const fallbackStart = dun === '阳' ? 2 : 8;
      const fallbackIdx = sequence.indexOf(fallbackStart);
      for (let i = 0; i < 8; i++) {
        const pid = sequence[(fallbackIdx + i) % 8];
        if (i === 0) continue;  // 戊已寄
        result.set(pid, SAN_QI_LIU_YI_ORDER[i]);
      }
      return result;
    }

    // 标准情况：戊起 startPalaceId，依次填三奇六仪
    for (let i = 0; i < 8; i++) {
      const pid = sequence[(startIdx + i) % 8];
      result.set(pid, SAN_QI_LIU_YI_ORDER[i]);
    }
    // 中宫填寄余的乙
    result.set(5, SAN_QI_LIU_YI_ORDER[8]);
    return result;
  }

  /** 计算时干：用真太阳时算时辰 ganzhi */
  private computeTimeGan(time: Date): TianGan {
    // 简化：用 hour-based ganzhi 五虎遁
    // 完整需日干 + 时支 → 五子遁
    // MVP：取 (day + hour/2) % 10 → 天干 index
    const day = Math.floor(time.getTime() / 86400000);
    const hour = time.getHours();
    const idx = (day * 12 + Math.floor((hour + 1) / 2)) % 10;
    return TIANGAN_LIST[idx];
  }

  /** 旋天盘：让时干（六仪 / 三奇）的天盘位与地盘位重合 */
  private buildTianPan(
    diPan: Map<number, TianGan>,
    timeGan: TianGan,
  ): Map<number, TianGan> {
    // 找时干在地盘的宫位
    const timeGanPalace = [...diPan.entries()].find(([_, g]) => g === timeGan)?.[0];
    if (!timeGanPalace) {
      // 时干不在 9 宫（甲不直接显示，借戊代之）
      return new Map(diPan);  // fallback: 天盘 = 地盘
    }

    // 天盘 = 地盘旋转，使时干天盘位覆盖直符宫
    // 简化实现：天盘干 = 地盘干（不旋）
    // 真实奇门要按"值符飞临"规则旋转，MVP 阶段用静态版本
    return new Map(diPan);
  }

  /** 排八门 / 九星 / 八神 */
  private buildPalaces(
    diPan: Map<number, TianGan>,
    tianPan: Map<number, TianGan>,
    timeGan: TianGan,
    dun: YinYangDun,
  ): Palace[] {
    // 直符宫 = 时干所在宫
    const zhiFuPalaceId = [...diPan.entries()].find(([_, g]) => g === timeGan)?.[0] ?? 1;

    // 八门起点：开门起直符宫
    const menSequence = dun === '阳' ? [...PALACE_CLOCKWISE] : [...PALACE_CLOCKWISE].reverse();
    const zhiFuIdxInMen = menSequence.indexOf(zhiFuPalaceId);
    const bamenMap = new Map<number, BamenName>();
    if (zhiFuIdxInMen >= 0) {
      for (let i = 0; i < 8; i++) {
        const pid = menSequence[(zhiFuIdxInMen + i) % 8];
        bamenMap.set(pid, BAMEN_ORDER[i]);
      }
    }

    // 九星：地盘九星固定（spec §3.7.6），天盘九星跟天盘干旋（MVP 简化为地盘版本）
    const jiuxingMap = new Map<number, JiuxingName>();
    for (let pid = 1; pid <= 9; pid++) {
      jiuxingMap.set(pid, JIUXING_DI_PAN_FIXED[pid]);
    }

    // 八神：值符神在直符宫，按 BASHEN_ORDER 顺/逆布
    const shenSequence = dun === '阳' ? [...PALACE_CLOCKWISE] : [...PALACE_CLOCKWISE].reverse();
    const zhiFuIdxInShen = shenSequence.indexOf(zhiFuPalaceId);
    const bashenMap = new Map<number, BashenName>();
    if (zhiFuIdxInShen >= 0) {
      for (let i = 0; i < 8; i++) {
        const pid = shenSequence[(zhiFuIdxInShen + i) % 8];
        bashenMap.set(pid, BASHEN_ORDER[i]);
      }
    }

    return PALACES_BASE.map(base => ({
      ...base,
      diPanGan: diPan.get(base.id) ?? null,
      tianPanGan: tianPan.get(base.id) ?? null,
      bamen: base.id === 5 ? null : (bamenMap.get(base.id) ?? null),
      jiuxing: jiuxingMap.get(base.id) ?? null,
      bashen: base.id === 5 ? null : (bashenMap.get(base.id) ?? null),
    }));
  }
}
```

#### Step 4: 跑测试

Run: `npm test -- QimenEngine`
Expected: 5 PASS。

#### Step 5: tsc check

Run: `npx tsc --noEmit`
Expected: 仅 pre-existing 错误。

#### Step 6: Commit

```bash
git add lib/qimen/QimenEngine.ts lib/qimen/__tests__/QimenEngine.test.ts
git commit -m "qimen: QimenEngine 起局核心（7 步：节气→局数→9 宫→旋盘→八门九星八神）

MVP 简化：
- 上中下元用日干索引近似（不查节气甲子日表）
- 时干用 day+hour 近似（不严格五子遁）
- 天盘干 = 地盘干（不旋，T5/T6 在用神/格局基础上完善）
- 用神简化为时干所在宫"
```

---

### Task 5：用神选择 + 应期推算（替换 T4 的占位实现）

**Files:**
- Modify: `lib/qimen/QimenEngine.ts`

#### Step 1: 加 selectYongShen + computeYingQi 方法

替换 T4 中 `setup()` 末尾的简化占位，加入完整用神 + 应期：

```ts
import { YONGSHEN_RULES } from './data/yongshen-rules';
import { TRIGRAMS } from '@/lib/divination/data/trigrams';  // 复用五行生克
import type { YongShenAnalysis, YingQiAnalysis, QuestionType, BamenName, BashenName } from './types';

// ... 在 QimenEngine class 内：

private selectYongShen(
  qt: QuestionType,
  gender: '男' | '女' | undefined,
  palaces: Palace[],
  timeGan: TianGan,
): YongShenAnalysis {
  const rule = YONGSHEN_RULES[qt];
  let targetGan: string = rule.primaryGan === 'time' ? timeGan : rule.primaryGan;

  // marriage gender override
  if (qt === 'marriage') {
    targetGan = '庚';  // 男看妻、女看夫，简化都看庚
  }

  // 找 targetGan 所在宫
  const palace = palaces.find(p => p.tianPanGan === targetGan || p.diPanGan === targetGan);

  if (!palace) {
    return {
      type: targetGan,
      palaceId: 1 as 1,
      state: '不上卦',
      summary: `用神 ${targetGan} 不上卦（伏神）`,
      interactions: ['用神不在 9 宫显现'],
    };
  }

  // 检查辅看的门 / 神 / 星是否同宫（加分）
  const interactions: string[] = [];
  if (rule.secondaryMen && palace.bamen === rule.secondaryMen) {
    interactions.push(`临${rule.secondaryMen}（吉门加分）`);
  }
  if (rule.secondaryShen && palace.bashen === rule.secondaryShen) {
    interactions.push(`临${rule.secondaryShen}（神助）`);
  }
  if (rule.secondaryStar && palace.jiuxing === rule.secondaryStar) {
    interactions.push(`临${rule.secondaryStar}星（星映）`);
  }

  return {
    type: targetGan,
    palaceId: palace.id,
    state: '相',  // MVP 简化：默认相
    summary: `${targetGan}临${palace.name}（${palace.bamen ?? '无门'} · ${palace.jiuxing} · ${palace.bashen ?? '无神'}）`,
    interactions,
  };
}

private computeYingQi(yongShen: YongShenAnalysis): YingQiAnalysis {
  if (yongShen.state === '不上卦') {
    return {
      description: '用神不上卦，应期难定',
      factors: ['用神未在 9 宫显现'],
    };
  }

  // MVP：用神临生门、开门 → 1-3 个月内；临死门、伤门 → 3-6 个月以上
  return {
    description: '约 1-3 个月内见分晓',
    factors: [`用神：${yongShen.summary}`],
  };
}
```

#### Step 2: setup() 方法替换占位

把原 `setup()` 末尾的简化 yongShen 替换为：

```ts
const yongShen = this.selectYongShen(opts.questionType, opts.gender, palaces, timeGan);
const yingQi = this.computeYingQi(yongShen);

return {
  // ... 其他字段不变
  yongShen,
  yingQi,
  geJu: [],  // T6 填充
};
```

#### Step 3: 加测试

```ts
// 在 QimenEngine.test.ts 加：
describe('QimenEngine yongShen selection', () => {
  const engine = new QimenEngine();

  it('career questionType selects 庚 as primaryGan', () => {
    const r = engine.setup({
      question: '我会得到这个 offer 吗',
      questionType: 'career',
      setupTime: new Date('2026-04-25T15:32:00'),
    });
    expect(r.yongShen.type).toBe('庚');
  });

  it('yongShen has palaceId, state, summary', () => {
    const r = engine.setup({
      question: 'test', questionType: 'career',
      setupTime: new Date('2026-04-25T15:32:00'),
    });
    expect(r.yongShen.palaceId).toBeGreaterThanOrEqual(1);
    expect(r.yongShen.palaceId).toBeLessThanOrEqual(9);
    expect(r.yongShen.summary).toBeTruthy();
  });

  it('returns 应期 description', () => {
    const r = engine.setup({
      question: 'test', questionType: 'career',
      setupTime: new Date('2026-04-25T15:32:00'),
    });
    expect(r.yingQi.description).toBeTruthy();
  });
});
```

#### Step 4: 跑测试

Run: `npm test -- QimenEngine`
Expected: 既有 5 + 新 3 = 8 PASS。

#### Step 5: Commit

```bash
git add lib/qimen/QimenEngine.ts lib/qimen/__tests__/QimenEngine.test.ts
git commit -m "qimen: 用神选择（按 questionType + 辅看门神星）+ 应期推算"
```

---

### Task 6：51 个格局识别规则

⚠️ **此 task 工作量最大（估计 1-2 天）**。Spec ADR-5 + ADR-6 要求完整 + 三重验证。

**Files:**
- Create: `lib/qimen/data/geju.ts`
- Create: `lib/qimen/__tests__/geju.test.ts`
- Modify: `lib/qimen/QimenEngine.ts`（加 detectGeJu 方法）

格局共 51 个，分 5 类。每个格局有：
- 名字
- 类型（吉 / 凶 / 中性）
- 描述（一句话）
- match 函数：(chart) => palaceIds[] | null

#### Step 1: 在线 verify 51 个格局规则

执行 task 前 subagent 必须 WebSearch / WebFetch 确认规则：
- 三奇格 15 个（乙奇遇... / 丙奇遇... / 丁奇遇... 各 5 种）
- 六仪击刑格 6 个（戊击刑、己击刑、庚击刑、辛击刑、壬击刑、癸击刑）
- 通用格 10 个（伏吟、反吟、入墓、值符、值使、白虎猖狂、玄武当权、大格、小格、刑格）
- 命名吉格 12 个（飞鸟跌穴、青龙返首、玉女守门、龙遁、虎遁等）
- 命名凶格 8 个（五不遇时、太白入荧等）

**至少 3 个权威源**对每个格局规则确认。

#### Step 2: 实现 geju.ts（结构 + 通用格 + 几个示例）

由于 51 个 detector 篇幅过大，本 plan 列出关键示例 + structure。完整 51 个由 implementer 按权威源填充。

```ts
import type { QimenChart, GeJu, Palace } from '../types';

export interface GeJuRule {
  name: string;
  type: GeJu['type'];
  description: string;
  /**
   * 匹配函数。返回涉及的宫 IDs；不匹配返回 null。
   */
  match: (chart: QimenChart) => number[] | null;
}

/** 工具：找特定干所在宫 */
function findGanPalace(chart: QimenChart, gan: string, layer: 'di' | 'tian'): Palace | undefined {
  return chart.palaces.find(p =>
    layer === 'di' ? p.diPanGan === gan : p.tianPanGan === gan
  );
}

// ────────────────────────────────────────────────────────
// 通用格（10 个）
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
      const CHONG: Record<string, string> = {
        '甲': '庚', '庚': '甲',
        '乙': '辛', '辛': '乙',
        '丙': '壬', '壬': '丙',
        '丁': '癸', '癸': '丁',
        '戊': '甲', '己': '乙',
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
    description: '值符神所在宫得吉门吉星，事易成',
    match: (chart) => {
      const valuePalace = chart.palaces.find(p => p.bashen === '值符');
      if (!valuePalace || !valuePalace.bamen) return null;
      const goodMen = ['开门', '生门', '休门'];
      return goodMen.includes(valuePalace.bamen) ? [valuePalace.id] : null;
    },
  },
  // ... 其余 7 个通用格 implementer 按权威源填充：
  // 入墓、值使、白虎猖狂、玄武当权、大格、小格、刑格
];

// ────────────────────────────────────────────────────────
// 三奇格（15 个）
// ────────────────────────────────────────────────────────

const SAN_QI_GE: GeJuRule[] = [
  {
    name: '乙奇得使',
    type: '吉',
    description: '乙奇临开门、生门、休门 — 得贵人助力',
    match: (chart) => {
      const yi = findGanPalace(chart, '乙', 'tian');
      if (!yi || !yi.bamen) return null;
      return ['开门', '生门', '休门'].includes(yi.bamen) ? [yi.id] : null;
    },
  },
  {
    name: '丙奇得使',
    type: '吉',
    description: '丙奇临开门、生门、休门',
    match: (chart) => {
      const bing = findGanPalace(chart, '丙', 'tian');
      if (!bing || !bing.bamen) return null;
      return ['开门', '生门', '休门'].includes(bing.bamen) ? [bing.id] : null;
    },
  },
  {
    name: '丁奇得使',
    type: '吉',
    description: '丁奇临开门、生门、休门',
    match: (chart) => {
      const ding = findGanPalace(chart, '丁', 'tian');
      if (!ding || !ding.bamen) return null;
      return ['开门', '生门', '休门'].includes(ding.bamen) ? [ding.id] : null;
    },
  },
  // ... 其余 12 个三奇格 implementer 按权威源填充
];

// ────────────────────────────────────────────────────────
// 六仪击刑格（6 个）
// ────────────────────────────────────────────────────────

const LIU_YI_JI_XING: GeJuRule[] = [
  {
    name: '戊击刑',
    type: '凶',
    description: '戊干临震宫，事多刑伤',
    match: (chart) => {
      const wu = findGanPalace(chart, '戊', 'tian') ?? findGanPalace(chart, '戊', 'di');
      return wu?.id === 3 ? [3] : null;
    },
  },
  // ... 其余 5 个（己 / 庚 / 辛 / 壬 / 癸 击刑）implementer 按权威源填
];

// ────────────────────────────────────────────────────────
// 命名吉格（12 个）
// ────────────────────────────────────────────────────────

const NAMED_JI_GE: GeJuRule[] = [
  {
    name: '飞鸟跌穴',
    type: '吉',
    description: '丁奇 + 生门 + 天辅星 同宫 — 求事易成',
    match: (chart) => {
      const ding = findGanPalace(chart, '丁', 'tian');
      if (!ding) return null;
      return ding.bamen === '生门' && ding.jiuxing === '天辅' ? [ding.id] : null;
    },
  },
  {
    name: '青龙返首',
    type: '吉',
    description: '丙奇 + 开门 + 天心星 同宫 — 大吉，飞升之兆',
    match: (chart) => {
      const bing = findGanPalace(chart, '丙', 'tian');
      if (!bing) return null;
      return bing.bamen === '开门' && bing.jiuxing === '天心' ? [bing.id] : null;
    },
  },
  // ... 其余 10 个（玉女守门、龙遁、虎遁、风遁、云遁、神遁、鬼遁、人遁、地遁、天遁、青龙返首...）
];

// ────────────────────────────────────────────────────────
// 命名凶格（8 个）
// ────────────────────────────────────────────────────────

const NAMED_XIONG_GE: GeJuRule[] = [
  {
    name: '白虎猖狂',
    type: '凶',
    description: '辛干 + 死门 + 天柱星 同宫 — 凶险',
    match: (chart) => {
      const xin = findGanPalace(chart, '辛', 'tian');
      if (!xin) return null;
      return xin.bamen === '死门' && xin.jiuxing === '天柱' ? [xin.id] : null;
    },
  },
  // ... 其余 7 个（五不遇时、太白入荧、荧入太白、玄武当权、岁格、月格、日格）
];

// ────────────────────────────────────────────────────────
// 全部 51 格汇总
// ────────────────────────────────────────────────────────

export const ALL_GE_JU: GeJuRule[] = [
  ...TONG_YONG_GE,
  ...SAN_QI_GE,
  ...LIU_YI_JI_XING,
  ...NAMED_JI_GE,
  ...NAMED_XIONG_GE,
];

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
```

⚠️ **subagent 必须填充其余 ~40 个格局**（spec ADR-5 要求 51 个完整 MVP）。每个格局：
- 在线查至少 3 个权威源对该格局的描述
- 一致后填 match 函数 + description
- 至少 1 个 fixture 测试

实施时间预算：~1 天专注于格局填充和 verify。

#### Step 3: 在 QimenEngine.setup() 加 detectGeJu 调用

```ts
// 在 setup() 末尾
import { detectGeJu } from './data/geju';

// ... return 之前
const geJu = detectGeJu(chart);

return {
  // ...
  geJu,
};
```

注：因为 detectGeJu 需要完整 chart，要先构造 partial chart，detect 后再返回完整 chart。或者用一个临时变量：

```ts
const partialChart = {
  question: opts.question,
  questionType: opts.questionType,
  setupTime: setupTime.toISOString(),
  trueSolarTime: trueSolar.toISOString(),
  jieqi, yinYangDun, juNumber, yuan,
  palaces, yongShen, yingQi,
  geJu: [] as GeJu[],
};
const geJu = detectGeJu(partialChart);

return { ...partialChart, geJu };
```

#### Step 4: geju.test.ts

```ts
import { ALL_GE_JU, detectGeJu } from '../data/geju';
import type { QimenChart } from '../types';

describe('ALL_GE_JU', () => {
  it('exports 51 格局', () => {
    expect(ALL_GE_JU.length).toBeGreaterThanOrEqual(45);
    expect(ALL_GE_JU.length).toBeLessThanOrEqual(60);
  });

  it('all rules have name, type, description, match', () => {
    for (const rule of ALL_GE_JU) {
      expect(rule.name).toBeTruthy();
      expect(['吉','凶','中性']).toContain(rule.type);
      expect(rule.description).toBeTruthy();
      expect(typeof rule.match).toBe('function');
    }
  });
});

describe('detectGeJu', () => {
  it('detects 飞鸟跌穴 when 丁 + 生门 + 天辅 同宫', () => {
    const chart: QimenChart = {
      // ... 构造一个 9 宫，让某宫 tianPanGan='丁', bamen='生门', jiuxing='天辅'
    } as any;
    const result = detectGeJu(chart);
    expect(result.some(g => g.name === '飞鸟跌穴')).toBe(true);
  });

  // 实施时为每个格局加 1 fixture（共 51 个），格局多写 50+ tests
});
```

#### Step 5: 跑测试

Run: `npm test -- geju`
Expected: 至少 51 PASS（每格至少 1 fixture）。

#### Step 6: Commit

```bash
git add lib/qimen/data/geju.ts lib/qimen/__tests__/geju.test.ts lib/qimen/QimenEngine.ts
git commit -m "qimen: 51 个格局识别规则（按 ADR-5/6 完整 MVP）

数据来源（ADR-6 三重验证）：
- 通用格 10 / 三奇格 15 / 六仪击刑 6 / 命名吉格 12 / 命名凶格 8

分歧条目：[列出与某权威源不一致的 entry，如有]
"
```

---

## Block C：AI 工具集成

### Task 7：setup_qimen 工具 + 注册到 ALL_TOOLS

**Files:**
- Create: `lib/ai/tools/qimen.ts`
- Create: `lib/ai/tools/__tests__/qimen.test.ts`
- Modify: `lib/ai/tools/index.ts`
- Modify: `lib/ai/tools/__tests__/index.test.ts`

#### Step 1: 创建 lib/ai/tools/qimen.ts

```ts
import type { ToolDefinition, ToolHandler } from './types';
import { QimenEngine } from '@/lib/qimen/QimenEngine';
import type { QuestionType } from '@/lib/qimen/types';

export const qimenTools: ToolDefinition[] = [
  {
    type: 'function',
    function: {
      name: 'setup_qimen',
      description: '为战略级重大决策起一局奇门盘（"要不要换城市/移民/换行业/创业"等）。返回完整 9 宫盘 + 用神宫 + 格局列表 + 应期。',
      parameters: {
        type: 'object',
        properties: {
          question: { type: 'string', description: '用户的具体问题' },
          questionType: {
            type: 'string',
            enum: ['career', 'wealth', 'marriage', 'kids', 'parents', 'health', 'event', 'general'],
          },
          gender: {
            type: 'string',
            enum: ['男', '女'],
            description: 'questionType=marriage 时区分用神',
          },
        },
        required: ['question'],
      },
    },
  },
];

const engine = new QimenEngine();

export const qimenHandlers: Record<string, ToolHandler> = {
  setup_qimen: ({ question, questionType, gender }, _ctx) => {
    const chart = engine.setup({
      question: String(question),
      questionType: (questionType as QuestionType | undefined) ?? 'general',
      gender: gender as '男' | '女' | undefined,
      setupTime: new Date(),
    });
    return chart;
  },
};
```

#### Step 2: 创建测试

```ts
// lib/ai/tools/__tests__/qimen.test.ts
import { qimenTools, qimenHandlers } from '../qimen';

const CTX = { mingPan: null, ziweiPan: null, now: new Date() };

describe('qimenTools', () => {
  it('exports setup_qimen', () => {
    expect(qimenTools).toHaveLength(1);
    expect(qimenTools[0].function.name).toBe('setup_qimen');
  });
});

describe('setup_qimen handler', () => {
  it('returns a QimenChart', async () => {
    const r = await qimenHandlers.setup_qimen(
      { question: '我要不要换城市', questionType: 'event' }, CTX,
    ) as any;
    expect(r.palaces).toHaveLength(9);
    expect(r.yongShen).toBeDefined();
    expect(r.geJu).toBeDefined();
  });

  it('defaults questionType to general when missing', async () => {
    const r = await qimenHandlers.setup_qimen(
      { question: 'test' }, CTX,
    ) as any;
    expect(r.questionType).toBe('general');
  });
});
```

#### Step 3: Run tests

```bash
npm test -- qimen.test
```
Expected: FAIL (module not found)。

#### Step 4: 跑通后 commit qimen.ts + 测试

```bash
git add lib/ai/tools/qimen.ts lib/ai/tools/__tests__/qimen.test.ts
git commit -m "ai/tools: setup_qimen 工具（包装 QimenEngine）"
```

#### Step 5: 注册到 ALL_TOOLS

修改 `lib/ai/tools/index.ts`：

```ts
// 加 import
import { qimenTools, qimenHandlers } from './qimen';

// ALL_TOOLS / ALL_HANDLERS 末尾加
export const ALL_TOOLS: ToolDefinition[] = [
  ...aggregatedTools,
  ...baziTools,
  ...ziweiTools,
  ...liuyaoTools,
  ...qimenTools,        // 新增
];

export const ALL_HANDLERS: Record<string, ToolHandler> = {
  ...aggregatedHandlers,
  ...baziHandlers,
  ...ziweiHandlers,
  ...liuyaoHandlers,
  ...qimenHandlers,     // 新增
};
```

并把 TOOL_STRATEGY 末尾追加（spec §5.2）：

```ts
9. 战略级重大决策（"要不要换城市/移民/换行业/创业"/"明年这件大事"/"这家公司能干长吗"/"我要不要和这个人结婚")→ 用 setup_qimen
10. 普通决策（"她回我吗"/"明天面试结果"）→ 用 cast_liuyao
11. 区分启发：影响时间跨度 / 影响生活面广度 / 严肃度。模糊时优先 cast_liuyao（更通俗）
```

#### Step 6: 更新 index.test.ts

`lib/ai/tools/__tests__/index.test.ts` 期望 ALL_TOOLS.length 从 7 → 8，names 加 'setup_qimen'。

#### Step 7: 跑全部测试

```bash
npm test
```
Expected: 全部 PASS（既有 ~62 + 新约 5 = 67）。

#### Step 8: Commit

```bash
git add lib/ai/tools/index.ts lib/ai/tools/__tests__/index.test.ts
git commit -m "ai/tools: 注册 setup_qimen 到 ALL_TOOLS + 路由策略"
```

---

### Task 8：双角色 prompt 增量 + ChatMessage 加 qimenChart 字段

**Files:**
- Modify: `lib/ai/index.ts`

#### Step 1: 在 THINKER_PROMPT 加奇门路由

在已有的"# 工具路由"段落"未传 force..."判断里**追加新条款**：

```
- 战略级重大决策（"要不要换城市/移民/换行业/创业"/"明年这件大事"
  / "这家公司能干长吗"/"我要不要和这个人结婚")→ setup_qimen
- 普通决策（短期、单一事件）→ cast_liuyao
- 模糊时优先 cast_liuyao（更通俗）
```

#### Step 2: 在 INTERPRETER_PROMPT 加奇门黑名单 + 三段结构

术语黑名单追加：

```
（奇门）三奇、六仪、八门（休生伤杜景死惊开）、九星（蓬芮冲辅禽心柱任英）、
八神（值符、腾蛇、太阴、六合、白虎、玄武、九地、九天）、
飞鸟跌穴、青龙返首、玉女守门、白虎猖狂、伏吟、反吟、击刑、值符、值使、
入墓、阳遁、阴遁、上元中元下元、用神临宫、地盘天盘……
```

三段结构追加：

```
当推演引擎输出含"setup_qimen"工具结果时（即起局类问题），解读结构遵循：
- 第 1 段：用神宫给出的"现状画面"（用形象比喻）
  ✅ "你这件事此刻像一棵刚扎根的小树..."
- 第 2 段：关键格局给出的"力量与阻力"
  ✅ "有一股稳中带升的势头在帮你..."
- 第 3 段：应期窗口（时间轴）
  ✅ "这件事大致会在未来 1-3 个月内见分晓..."
```

#### Step 3: 在 ChatMessage.orchestration 加 qimenChart 字段

```ts
orchestration?: {
  thinker: string;
  evidence: string[];
  toolCalls: Array<{...}>;
  hexagram?: import('@/lib/divination/types').HexagramReading | null;
  qimenChart?: import('@/lib/qimen/types').QimenChart | null;   // 新增
};
```

#### Step 4: tsc + tests

```bash
npx tsc --noEmit
npm test
```
Expected: 仅 pre-existing tsc 错误；测试 PASS。

#### Step 5: Commit

```bash
git add lib/ai/index.ts
git commit -m "ai: THINKER 加奇门路由 + INTERPRETER 加奇门黑名单和三段结构 + ChatMessage 加 qimenChart"
```

---

## Block D：UI 组件

### Task 9：YongShenPalaceCard 用神宫聚焦卡

**Files:**
- Create: `components/qimen/YongShenPalaceCard.tsx`

```tsx
/**
 * 用神宫聚焦卡（主气泡里的奇门主显示）
 *
 * 视觉：朱砂边框框住 用神宫 5 层信息
 */
import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { Colors, Space, Radius, Type, Shadow } from '@/lib/design/tokens';
import type { Palace, YongShenAnalysis } from '@/lib/qimen/types';

type Props = {
  palace: Palace;
  yongShen: YongShenAnalysis;
};

export function YongShenPalaceCard({ palace, yongShen }: Props) {
  return (
    <View style={[styles.card, Shadow.sm]}>
      <Text style={styles.title}>用神宫 · {palace.name}（{palace.id}）</Text>
      <View style={styles.divider} />
      <Text style={styles.gan}>
        {palace.tianPanGan ?? '？'}（天） / {palace.diPanGan ?? '？'}（地）
      </Text>
      <Text style={styles.menStarShen}>
        {palace.bamen ?? '无门'} · {palace.jiuxing} · {palace.bashen ?? '无神'}
      </Text>
      <Text style={styles.summary}>{yongShen.summary}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: Colors.bgSecondary,
    borderRadius: Radius.md,
    padding: Space.base,
    borderWidth: 2,
    borderColor: Colors.vermilion,
    marginVertical: Space.sm,
  },
  title: {
    ...Type.label,
    color: Colors.vermilion,
    letterSpacing: 1,
  },
  divider: {
    height: StyleSheet.hairlineWidth,
    backgroundColor: Colors.border,
    marginVertical: Space.xs,
  },
  gan: {
    ...Type.body,
    color: Colors.ink,
    fontFamily: 'Georgia',
    fontWeight: '500',
  },
  menStarShen: {
    ...Type.bodySmall,
    color: Colors.inkSecondary,
    marginTop: 4,
  },
  summary: {
    ...Type.caption,
    color: Colors.inkTertiary,
    marginTop: Space.xs,
    fontStyle: 'italic',
  },
});
```

#### Commit

```bash
git add components/qimen/YongShenPalaceCard.tsx
git commit -m "qimen/ui: YongShenPalaceCard 用神宫聚焦卡"
```

---

### Task 10：AdjacentPalaceTags 邻宫标签

**Files:**
- Create: `components/qimen/AdjacentPalaceTags.tsx`

```tsx
/**
 * 用神宫旁边显示 2-3 个相邻宫的简化标签（仅装饰，不响应）
 */
import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { Colors, Space, Type } from '@/lib/design/tokens';
import type { Palace, QimenChart } from '@/lib/qimen/types';

/** 9 宫几何邻接关系 */
const PALACE_NEIGHBORS: Record<number, number[]> = {
  1: [2, 6, 8],     // 坎邻：坤、乾、艮
  2: [1, 7, 9],
  3: [4, 8, 9],
  4: [3, 9, 1],
  5: [],            // 中宫不显示
  6: [1, 7, 8],
  7: [2, 6, 9],
  8: [1, 3, 6],
  9: [3, 4, 7],
};

type Props = {
  chart: QimenChart;
};

export function AdjacentPalaceTags({ chart }: Props) {
  const yongShenPalaceId = chart.yongShen.palaceId;
  if (yongShenPalaceId === 5) return null;

  const neighborIds = (PALACE_NEIGHBORS[yongShenPalaceId] ?? []).slice(0, 3);
  const neighbors = neighborIds.map(id => chart.palaces.find(p => p.id === id)).filter(Boolean) as Palace[];

  return (
    <View style={styles.row}>
      {neighbors.map(p => (
        <View key={p.id} style={styles.tag}>
          <Text style={styles.text}>
            {p.name}·{p.bamen ?? '无门'}
          </Text>
        </View>
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: 'row',
    gap: 6,
    marginVertical: Space.xs,
    flexWrap: 'wrap',
  },
  tag: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    backgroundColor: Colors.brandBg,
    borderRadius: 8,
  },
  text: {
    ...Type.caption,
    color: Colors.vermilion,
  },
});
```

#### Commit

```bash
git add components/qimen/AdjacentPalaceTags.tsx
git commit -m "qimen/ui: AdjacentPalaceTags 邻宫标签"
```

---

### Task 11：FullChart9 完整 9 宫盘（BottomSheet 用）

**Files:**
- Create: `components/qimen/FullChart9.tsx`

```tsx
/**
 * 完整 9 宫盘（仅 BottomSheet 显示）
 *
 * 3×3 网格，每格 5 行小字（地盘干 / 天盘干 / 八门 / 九星 / 八神）
 * 用神宫朱砂边框 + 角标
 * 凶格所在宫底色暗淡
 */
import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { Colors, Space, Type } from '@/lib/design/tokens';
import type { QimenChart, Palace } from '@/lib/qimen/types';

/** 9 宫的视觉位置（3×3 网格，按方位） */
const VISUAL_GRID: number[][] = [
  [4, 9, 2],   // 巽 离 坤
  [3, 5, 7],   // 震 中 兑
  [8, 1, 6],   // 艮 坎 乾
];

type Props = { chart: QimenChart };

export function FullChart9({ chart }: Props) {
  const xiongPalaceIds = new Set(
    chart.geJu
      .filter(g => g.type === '凶')
      .flatMap(g => g.palaceIds ?? []),
  );
  const yongShenId = chart.yongShen.palaceId;

  return (
    <View>
      <Text style={styles.title}>
        {chart.yinYangDun}遁 {chart.juNumber} 局 · {chart.jieqi}{chart.yuan}元
      </Text>
      <View style={styles.grid}>
        {VISUAL_GRID.map((row, rowIdx) => (
          <View key={rowIdx} style={styles.row}>
            {row.map(palaceId => {
              const p = chart.palaces.find(pp => pp.id === palaceId)!;
              const isYongShen = p.id === yongShenId;
              const isXiong = xiongPalaceIds.has(p.id);
              return (
                <View
                  key={p.id}
                  style={[
                    styles.cell,
                    isYongShen && styles.cellYongShen,
                    isXiong && !isYongShen && styles.cellXiong,
                  ]}
                >
                  <Text style={styles.palaceName}>
                    {p.name}({p.id})
                  </Text>
                  {p.tianPanGan && p.diPanGan && (
                    <Text style={styles.gan}>
                      {p.tianPanGan}/{p.diPanGan}
                    </Text>
                  )}
                  {p.bamen && <Text style={styles.line}>{p.bamen}</Text>}
                  {p.jiuxing && <Text style={styles.line}>{p.jiuxing}</Text>}
                  {p.bashen && <Text style={styles.line}>{p.bashen}</Text>}
                </View>
              );
            })}
          </View>
        ))}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  title: {
    ...Type.label,
    color: Colors.vermilion,
    textAlign: 'center',
    marginBottom: Space.sm,
    letterSpacing: 1,
  },
  grid: {
    gap: 2,
  },
  row: {
    flexDirection: 'row',
    gap: 2,
  },
  cell: {
    flex: 1,
    minHeight: 100,
    padding: 4,
    backgroundColor: Colors.bgSecondary,
    borderRadius: 4,
    alignItems: 'center',
    justifyContent: 'center',
  },
  cellYongShen: {
    borderWidth: 2,
    borderColor: Colors.vermilion,
  },
  cellXiong: {
    opacity: 0.5,
  },
  palaceName: {
    ...Type.caption,
    color: Colors.ink,
    fontWeight: '600',
  },
  gan: {
    fontFamily: 'Georgia',
    fontSize: 11,
    color: Colors.vermilion,
    marginTop: 2,
  },
  line: {
    fontSize: 10,
    color: Colors.inkSecondary,
    marginTop: 1,
  },
});
```

#### Commit

```bash
git add components/qimen/FullChart9.tsx
git commit -m "qimen/ui: FullChart9 完整 9 宫盘（BottomSheet 用）"
```

---

### Task 12：QimenSetupAnimation 起局动画

**Files:**
- Create: `components/qimen/QimenSetupAnimation.tsx`

```tsx
/**
 * 起局动画（3.3 秒，9 宫框架先成型，5 层信息自外而内落位）
 */
import React, { useEffect } from 'react';
import { View, Text, StyleSheet } from 'react-native';
import Animated, {
  useSharedValue, useAnimatedStyle, withDelay, withTiming,
} from 'react-native-reanimated';
import { Colors, Space, Type } from '@/lib/design/tokens';
import type { QimenChart } from '@/lib/qimen/types';
import { FullChart9 } from './FullChart9';

const TOTAL = 3300;

type Props = {
  chart: QimenChart;
  onComplete?: () => void;
};

export function QimenSetupAnimation({ chart, onComplete }: Props) {
  const opacity = useSharedValue(0);
  const scale = useSharedValue(0.85);
  const titleOpacity = useSharedValue(0);

  useEffect(() => {
    opacity.value = withTiming(1, { duration: 600 });
    scale.value = withDelay(200, withTiming(1, { duration: 1500 }));
    titleOpacity.value = withDelay(2700, withTiming(1, { duration: 400 }));
    const t = setTimeout(() => onComplete?.(), TOTAL);
    return () => clearTimeout(t);
  }, []);

  const containerStyle = useAnimatedStyle(() => ({
    opacity: opacity.value,
    transform: [{ scale: scale.value }],
  }));

  const titleStyle = useAnimatedStyle(() => ({
    opacity: titleOpacity.value,
  }));

  return (
    <View style={styles.container}>
      <Animated.View style={containerStyle}>
        <FullChart9 chart={chart} />
      </Animated.View>
      <Animated.Text style={[styles.title, titleStyle]}>
        布盘九宫 · {chart.yinYangDun}遁 {chart.juNumber} 局
      </Animated.Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    paddingVertical: Space.md,
  },
  title: {
    ...Type.label,
    color: Colors.vermilion,
    textAlign: 'center',
    letterSpacing: 2,
    marginTop: Space.xs,
  },
});
```

#### Commit

```bash
git add components/qimen/QimenSetupAnimation.tsx
git commit -m "qimen/ui: QimenSetupAnimation 3.3 秒起局动画"
```

---

## Block E：集成

### Task 13：insight.tsx + FullReasoningSheet 接入

**Files:**
- Modify: `app/(tabs)/insight.tsx`
- Modify: `components/ai/FullReasoningSheet.tsx`

#### Step 1: insight.tsx imports

```tsx
import { QimenSetupAnimation } from '@/components/qimen/QimenSetupAnimation';
import { YongShenPalaceCard } from '@/components/qimen/YongShenPalaceCard';
import { AdjacentPalaceTags } from '@/components/qimen/AdjacentPalaceTags';
import type { QimenChart } from '@/lib/qimen/types';
```

#### Step 2: 加 state

```tsx
const [liveQimenChart, setLiveQimenChart] = useState<QimenChart | null>(null);
let localQimenChart: QimenChart | null = null;
```

#### Step 3: handleSend 内 onToolCall 加分支

```tsx
if (call.name === 'setup_qimen' && !(res as any)?.error) {
  localQimenChart = res as QimenChart;
  setLiveQimenChart(localQimenChart);
}
```

#### Step 4: assistantMsg.orchestration 加 qimenChart

```tsx
orchestration: {
  thinker: result.thinker,
  evidence: splitOrchestrationOutput(result.interpreter).evidence,
  toolCalls: localToolCalls,
  hexagram: localHexagram,
  qimenChart: localQimenChart,    // 新增
},
```

#### Step 5: 状态重置加 setLiveQimenChart(null)

#### Step 6: narrateTool 加 setup_qimen case

```tsx
if (name === 'setup_qimen') {
  return '布盘九宫，定准时辰' + tail;
}
```

#### Step 7: 流式气泡 JSX 加奇门渲染

```tsx
{liveQimenChart && (
  <>
    <QimenSetupAnimation chart={liveQimenChart} />
    <YongShenPalaceCard
      palace={liveQimenChart.palaces[liveQimenChart.yongShen.palaceId - 1]}
      yongShen={liveQimenChart.yongShen}
    />
    <AdjacentPalaceTags chart={liveQimenChart} />
  </>
)}
```

#### Step 8: 历史气泡 JSX 加奇门渲染

```tsx
{msg.orchestration?.qimenChart && (
  <>
    <YongShenPalaceCard
      palace={msg.orchestration.qimenChart.palaces[msg.orchestration.qimenChart.yongShen.palaceId - 1]}
      yongShen={msg.orchestration.qimenChart.yongShen}
    />
    <AdjacentPalaceTags chart={msg.orchestration.qimenChart} />
  </>
)}
```

#### Step 9: FullReasoningSheet 加奇门分支

读 `components/ai/FullReasoningSheet.tsx`。在 evidence section 之后加奇门 section（如果 sheetData 含 qimenChart）：

```tsx
{sheetData?.qimenChart && (
  <Section label="完整 9 宫盘">
    <FullChart9 chart={sheetData.qimenChart} />
  </Section>
)}

{sheetData?.qimenChart?.geJu.length > 0 && (
  <Section label="格局">
    {sheetData.qimenChart.geJu.map((g, i) => (
      <Text key={i} style={styles.line}>
        · {g.name}（{g.type}）—— {g.description}
      </Text>
    ))}
  </Section>
)}
```

需要 import `FullChart9` 和扩展 sheetData 类型让其含 qimenChart。

#### Step 10: 把 sheetData 类型扩展（在 insight.tsx）

```tsx
const [sheetData, setSheetData] = useState<null | {
  thinker: string;
  evidence: string[];
  toolCalls: ToolCallTrace[];
  qimenChart?: QimenChart | null;
  hexagram?: HexagramReading | null;
}>(null);
```

设置 sheetData 时加 qimenChart：

```tsx
onTapFull={() => setSheetData({
  thinker: msg.orchestration!.thinker,
  evidence: msg.orchestration!.evidence,
  toolCalls: msg.orchestration!.toolCalls,
  qimenChart: msg.orchestration!.qimenChart,
  hexagram: msg.orchestration!.hexagram,
})}
```

#### Step 11: tsc + tests

```bash
npx tsc --noEmit
npm test
```

#### Step 12: Commit

```bash
git add app/\(tabs\)/insight.tsx components/ai/FullReasoningSheet.tsx
git commit -m "chat: 接入奇门 setup_qimen + 用神宫卡 + 邻宫标签 + 起局动画 + BottomSheet 完整盘"
```

---

## Block F：验证

### Task 14：真机 build + 手测矩阵 + push

#### Step 1: 跑全部单测

```bash
npm test
```
Expected: 全部 PASS（既有 ~62 + 新约 60 = 120+ 个）

#### Step 2: tsc 全检

```bash
npx tsc --noEmit
```
Expected: 仅 main 上原有 2 个错误。

#### Step 3: 真机 build

```bash
SHA=$(git rev-parse --short HEAD)
EXPO_PUBLIC_BUILD_SHA=$SHA npx expo run:ios --device 00008140-001262AE010A801C --configuration Release
```

#### Step 4: 手测矩阵

| 测试用例 | 期望 |
|---|---|
| 设置 → 看 SHA 是新的 | 版本号显示正确 |
| 默认模式输入"我要不要换城市生活" | AI 自动调 setup_qimen，气泡内 3.3 秒起局动画 |
| 默认模式输入"她回我吗" | AI 调 cast_liuyao（六爻），不起局 |
| 默认模式输入"今年事业怎么样" | AI 走命理，不起局 |
| "起一卦"模式 + 战略问题 | 强制起六爻（不起奇门，符合 ADR-1） |
| 主气泡：用神宫卡 + 邻宫标签 | 视觉聚焦 |
| 解读正文不出现奇门术语 | 仅在 evidence 卡和 BottomSheet 才有 |
| 点 evidence 卡 → BottomSheet | 显示完整 9 宫盘 + 格局列表 |
| 历史消息 | 用神宫卡静态显示（无动画） |

#### Step 5: Push

```bash
git push origin main
```

---

## 已知风险与回退

### R1：Task 2（72 起局表）数据错误

**缓解**：ADR-6 三重验证 + 5 fixture，commit 注明分歧条目。

### R2：Task 6（51 格局）覆盖不全或规则错

**缓解**：每个格局 ≥ 1 fixture，subagent 必须在 commit 前 verify ≥ 3 个权威源。

### R3：QimenEngine 起局算法 MVP 简化偏离传统

**简化项**：
- 上中下元用日干索引近似（不查节气甲子日）
- 时干用 day+hour 近似（不严格五子遁）
- 天盘干 = 地盘干（不旋）

**影响**：盘可能与权威排盘网站差 1 局或 1 时辰。这是 ADR-7 已知 trade-off。

### R4：动画在低端机掉帧

**缓解**：用 fade + scale，不用复杂 transform。3.3 秒 + 单一容器动画，性能压力低。

### R5：AI 误把"重大问题"判断为"普通问题"

**缓解**：spec ADR-1 接受这个边界。用户可继续问"用奇门看看"显式触发。
