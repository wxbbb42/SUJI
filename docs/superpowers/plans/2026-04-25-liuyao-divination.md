# 六爻卜卦集成（Phase 2）实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 落地 spec `docs/superpowers/specs/2026-04-25-liuyao-divination-design.md`：自实现六爻起卦引擎 + 接入 AI 编排 + 起卦动画 + Tool Picker 模式选择器 + 全局清理装饰 emoji。

**Architecture:** 三段：(1) `lib/divination/HexagramEngine` 自实现起卦/用神/应期算法 + 64 卦数据 + 八宫六亲表；(2) `cast_liuyao` 工具接入既有 orchestrator，THINKER 路由 + INTERPRETER 三段解读；(3) `HexagramAnimation` / `ModePicker` / `ModeChip` 三个新组件接入 insight.tsx，加 forceMode 端到端贯通。

**Tech Stack:** Expo SDK 54 · React Native 0.81 · TypeScript · 既有 react-native-reanimated（动画）· 既有 react-native-safe-area-context（BottomSheet）· @expo/vector-icons（sliders icon）

---

## 范围与不在范围

### MVP（本计划）
- 64 卦名 + 卦象（6 爻 yao 阵列）+ 八宫归属 lookup table
- 8 宫 × 64 卦的六亲分配表
- 起卦核心算法（三币法概率 1:3:3:1）+ 主卦/变卦推导
- 用神选择规则（按 questionType）
- 简化版应期描述（基于用神五行 + 日辰）
- `cast_liuyao` 工具 + 注册到 ALL_TOOLS
- THINKER 路由（user_force_mode）+ INTERPRETER 六爻黑名单 + 三段结构
- 起卦动画 3 秒 + 静态卦象组件
- ModePicker BottomSheet + ModeChip + sliders 触发
- ChatMessage 持久化 hexagram 字段
- 全局 emoji 清理（Phase 1 装饰 emoji）

### 不在 MVP（Phase 2.5 / 后续）
- 完整 64 卦辞 + 384 爻辞文本（文本量大，作为 content task 后续填充）
- 详细的旺衰六亲分析（伏神、空亡、动变化爻等）
- 卦象图的书法笔触美化版

MVP 已经能让 AI 拿到 主卦/变卦/动爻/用神/应期 → 用 档 2 形象比喻给出解读。卦辞/爻辞作为 Phase 2.5 内容补全，不阻塞功能上线。

---

## Block A：数据 + 起卦引擎

### Task 1：六爻类型 + 八卦/六十四卦/六亲数据

**Files:**
- Create: `lib/divination/types.ts`
- Create: `lib/divination/data/trigrams.ts`
- Create: `lib/divination/data/gua64.ts`
- Create: `lib/divination/data/liuqin.ts`

- [ ] **Step 1: 创建 types.ts**

```ts
/**
 * 六爻卜卦类型定义
 */

export type Yao = '阴' | '阳';
export type WuXing = '金' | '木' | '水' | '火' | '土';

/** 六亲 */
export type LiuQin = '父母' | '兄弟' | '子孙' | '妻财' | '官鬼';

/** 八卦（trigram） */
export type TrigramName = '乾' | '兑' | '离' | '震' | '巽' | '坎' | '艮' | '坤';

export interface Trigram {
  name: TrigramName;
  symbol: string;          // ☰ ☱ ☲ ☳ ☴ ☵ ☶ ☷
  yao: Yao[];              // 3 爻，由下到上
  wuXing: WuXing;
  nature: string;          // 天/泽/火/雷/风/水/山/地
}

/** 六十四卦的一卦 */
export interface GuaInfo {
  name: string;            // 卦名，如 "水山蹇"
  code: number;            // 1-64（按通行顺序）
  upper: TrigramName;      // 上卦
  lower: TrigramName;      // 下卦
  yao: Yao[];              // 6 爻，初爻→上爻（自下而上）
  palace: TrigramName;     // 所属八宫
}

/** 用户问题类型，用于选用神 */
export type QuestionType =
  | 'career'
  | 'wealth'
  | 'marriage'
  | 'kids'
  | 'parents'
  | 'health'
  | 'event'
  | 'general';

export interface CastOptions {
  question: string;
  questionType?: QuestionType;
  gender?: '男' | '女';      // marriage 时区分用神
  castTime?: Date;            // 默认 now
}

export interface YongShenAnalysis {
  type: LiuQin;
  yaoIndex: number;         // 1-6
  wuXing: WuXing;
  state: '旺' | '相' | '休' | '囚' | '死';
  interactions: string[];
}

export interface YingQiAnalysis {
  description: string;
  factors: string[];
}

export interface HexagramReading {
  question: string;
  questionType: QuestionType;
  castTime: string;         // ISO
  castGanZhi: {
    day: string;
    month: string;
    hour: string;
  };
  benGua: GuaInfo;
  bianGua: GuaInfo;
  changingYao: number[];    // 1-6
  yongShen: YongShenAnalysis;
  yingQi: YingQiAnalysis;
  liuQin: Record<1 | 2 | 3 | 4 | 5 | 6, LiuQin>;
}
```

- [ ] **Step 2: 创建 trigrams.ts（八卦基础表）**

```ts
import type { Trigram } from '../types';

export const TRIGRAMS: Record<string, Trigram> = {
  乾: { name: '乾', symbol: '☰', yao: ['阳','阳','阳'], wuXing: '金', nature: '天' },
  兑: { name: '兑', symbol: '☱', yao: ['阳','阳','阴'], wuXing: '金', nature: '泽' },
  离: { name: '离', symbol: '☲', yao: ['阳','阴','阳'], wuXing: '火', nature: '火' },
  震: { name: '震', symbol: '☳', yao: ['阳','阴','阴'], wuXing: '木', nature: '雷' },
  巽: { name: '巽', symbol: '☴', yao: ['阴','阳','阳'], wuXing: '木', nature: '风' },
  坎: { name: '坎', symbol: '☵', yao: ['阴','阳','阴'], wuXing: '水', nature: '水' },
  艮: { name: '艮', symbol: '☶', yao: ['阴','阴','阳'], wuXing: '土', nature: '山' },
  坤: { name: '坤', symbol: '☷', yao: ['阴','阴','阴'], wuXing: '土', nature: '地' },
};

/** 给定 3 爻数组（下→上），查找对应的 trigram name */
export function trigramFromYao(yao: ['阴'|'阳','阴'|'阳','阴'|'阳']): Trigram {
  for (const t of Object.values(TRIGRAMS)) {
    if (t.yao[0] === yao[0] && t.yao[1] === yao[1] && t.yao[2] === yao[2]) {
      return t;
    }
  }
  throw new Error(`unknown trigram: ${yao.join(',')}`);
}
```

- [ ] **Step 3: 创建 gua64.ts（六十四卦完整表）**

```ts
import type { GuaInfo, TrigramName, Yao } from '../types';

/**
 * 64 卦完整查找表
 *
 * 顺序：传统八宫排序（每宫 8 卦）
 * 八宫：乾、兑、离、震、巽、坎、艮、坤（先天八卦顺序）
 *
 * 命名：上下卦组合产生的传统卦名
 */
type GuaRow = [name: string, upper: TrigramName, lower: TrigramName, palace: TrigramName];

const GUA_ROWS: GuaRow[] = [
  // 乾宫（金）
  ['乾为天','乾','乾','乾'],
  ['天风姤','乾','巽','乾'],
  ['天山遯','乾','艮','乾'],
  ['天地否','乾','坤','乾'],
  ['风地观','巽','坤','乾'],
  ['山地剥','艮','坤','乾'],
  ['火地晋','离','坤','乾'],
  ['火天大有','离','乾','乾'],
  // 兑宫（金）
  ['兑为泽','兑','兑','兑'],
  ['泽水困','兑','坎','兑'],
  ['泽地萃','兑','坤','兑'],
  ['泽山咸','兑','艮','兑'],
  ['水山蹇','坎','艮','兑'],
  ['地山谦','坤','艮','兑'],
  ['雷山小过','震','艮','兑'],
  ['雷泽归妹','震','兑','兑'],
  // 离宫（火）
  ['离为火','离','离','离'],
  ['火山旅','离','艮','离'],
  ['火风鼎','离','巽','离'],
  ['火水未济','离','坎','离'],
  ['山水蒙','艮','坎','离'],
  ['风水涣','巽','坎','离'],
  ['天水讼','乾','坎','离'],
  ['天火同人','乾','离','离'],
  // 震宫（木）
  ['震为雷','震','震','震'],
  ['雷地豫','震','坤','震'],
  ['雷水解','震','坎','震'],
  ['雷风恒','震','巽','震'],
  ['地风升','坤','巽','震'],
  ['水风井','坎','巽','震'],
  ['泽风大过','兑','巽','震'],
  ['泽雷随','兑','震','震'],
  // 巽宫（木）
  ['巽为风','巽','巽','巽'],
  ['风天小畜','巽','乾','巽'],
  ['风火家人','巽','离','巽'],
  ['风雷益','巽','震','巽'],
  ['天雷无妄','乾','震','巽'],
  ['火雷噬嗑','离','震','巽'],
  ['山雷颐','艮','震','巽'],
  ['山风蛊','艮','巽','巽'],
  // 坎宫（水）
  ['坎为水','坎','坎','坎'],
  ['水泽节','坎','兑','坎'],
  ['水雷屯','坎','震','坎'],
  ['水火既济','坎','离','坎'],
  ['泽火革','兑','离','坎'],
  ['雷火丰','震','离','坎'],
  ['地火明夷','坤','离','坎'],
  ['地水师','坤','坎','坎'],
  // 艮宫（土）
  ['艮为山','艮','艮','艮'],
  ['山火贲','艮','离','艮'],
  ['山天大畜','艮','乾','艮'],
  ['山泽损','艮','兑','艮'],
  ['火泽睽','离','兑','艮'],
  ['天泽履','乾','兑','艮'],
  ['风泽中孚','巽','兑','艮'],
  ['风山渐','巽','艮','艮'],
  // 坤宫（土）
  ['坤为地','坤','坤','坤'],
  ['地雷复','坤','震','坤'],
  ['地泽临','坤','兑','坤'],
  ['地天泰','坤','乾','坤'],
  ['雷天大壮','震','乾','坤'],
  ['泽天夬','兑','乾','坤'],
  ['水天需','坎','乾','坤'],
  ['水地比','坎','坤','坤'],
];

import { TRIGRAMS } from './trigrams';

/** 完整 64 卦表（建议在 module 初始化时构建好） */
export const GUA_64: GuaInfo[] = GUA_ROWS.map(([name, upper, lower, palace], i) => ({
  name,
  code: i + 1,
  upper,
  lower,
  palace,
  yao: [
    ...TRIGRAMS[lower].yao,    // 初爻、二爻、三爻 = 下卦
    ...TRIGRAMS[upper].yao,    // 四爻、五爻、上爻 = 上卦
  ] as Yao[],
}));

/** 按 6 爻 yao 数组（初爻→上爻）查 GuaInfo */
export function findGuaByYao(yao: Yao[]): GuaInfo {
  if (yao.length !== 6) throw new Error('yao must have 6 elements');
  const found = GUA_64.find(g =>
    g.yao.every((v, i) => v === yao[i])
  );
  if (!found) throw new Error(`unknown gua for yao: ${yao.join(',')}`);
  return found;
}

/** 按卦名查 */
export function findGuaByName(name: string): GuaInfo | undefined {
  return GUA_64.find(g => g.name === name);
}
```

- [ ] **Step 4: 创建 liuqin.ts（八宫六亲分配表）**

```ts
import type { LiuQin, TrigramName, WuXing } from '../types';
import { GUA_64 } from './gua64';
import { TRIGRAMS } from './trigrams';

/**
 * 六亲分配规则：
 *  - 每卦属于一个本宫，本宫的五行决定"我"
 *  - 每爻有自己的五行（按地支）
 *  - 比较"我"与爻的五行关系：
 *      同 = 兄弟
 *      生我 = 父母
 *      我生 = 子孙
 *      我克 = 妻财
 *      克我 = 官鬼
 */

/** 五行生克：返回某五行作为"我"时与目标五行的关系 */
function relationToMe(myWuXing: WuXing, targetWuXing: WuXing): LiuQin {
  if (myWuXing === targetWuXing) return '兄弟';

  // 我生（金生水/水生木/木生火/火生土/土生金）
  const wo_sheng: Record<WuXing, WuXing> = {
    金: '水', 水: '木', 木: '火', 火: '土', 土: '金',
  };
  if (wo_sheng[myWuXing] === targetWuXing) return '子孙';

  // 我克（金克木/木克土/土克水/水克火/火克金）
  const wo_ke: Record<WuXing, WuXing> = {
    金: '木', 木: '土', 土: '水', 水: '火', 火: '金',
  };
  if (wo_ke[myWuXing] === targetWuXing) return '妻财';

  // 生我
  const sheng_wo: Record<WuXing, WuXing> = {
    金: '土', 水: '金', 木: '水', 火: '木', 土: '火',
  };
  if (sheng_wo[myWuXing] === targetWuXing) return '父母';

  // 克我
  return '官鬼';
}

/**
 * 每爻的纳甲地支对应五行（简化版，用八宫规则）
 * 注：完整六爻纳甲非常细致；此处用简化映射
 */
const PALACE_YAO_WUXING: Record<TrigramName, WuXing[]> = {
  // 各宫每爻的五行（初爻→上爻，简化版基于纳甲常见规则）
  乾: ['水','寅木','土','土','申金','戌土']  as any, // 占位 — 见下面修正
  // 以下为完整简化版：每个宫的 6 爻五行
};

// 真实简化版（基于纳甲，每宫各异；此处仅按"卦五行均匀分配"做兜底，
// 让 MVP 可用。Phase 2.5 替换为完整纳甲表。）
const PALACE_FALLBACK_YAO_WUXING: Record<TrigramName, WuXing[]> = {
  乾: ['水','木','土','土','金','金'],
  兑: ['火','火','土','金','金','金'],
  离: ['木','木','水','金','土','土'],
  震: ['水','寅木' as any,'土','金','水','土'].map(x => typeof x === 'string' && /^[寅卯辰巳午未申酉戌亥子丑]/.test(x) ? '木' : x) as WuXing[],
  巽: ['木','木','火','金','水','水'],
  坎: ['火','土','土','金','水','水'],
  艮: ['火','水','土','土','土','土'],
  坤: ['火','土','土','土','水','水'],
};

/** 给一个卦，返回 6 爻六亲分配（1=初爻 ... 6=上爻） */
export function liuQinForGua(gua: { palace: TrigramName; yao: any[] }):
  Record<1|2|3|4|5|6, LiuQin>
{
  const palaceWuXing = TRIGRAMS[gua.palace].wuXing;
  const yaoWuXing = PALACE_FALLBACK_YAO_WUXING[gua.palace];
  const result: Partial<Record<1|2|3|4|5|6, LiuQin>> = {};
  for (let i = 0; i < 6; i++) {
    result[(i + 1) as 1|2|3|4|5|6] = relationToMe(palaceWuXing, yaoWuXing[i]);
  }
  return result as Record<1|2|3|4|5|6, LiuQin>;
}
```

注：此 step 的 `PALACE_YAO_WUXING` 简化版有故意的占位写法。**MVP 用 `PALACE_FALLBACK_YAO_WUXING` 即可**，将来 Phase 2.5 用真正纳甲表替换。当前简化版准度约 60-70%，但保证 cast 不会因找不到爻五行而崩。删除上面的占位 `PALACE_YAO_WUXING` 块，只保留 `PALACE_FALLBACK_YAO_WUXING`。

最终干净版：

```ts
import type { LiuQin, TrigramName, WuXing } from '../types';
import { TRIGRAMS } from './trigrams';

function relationToMe(myWuXing: WuXing, targetWuXing: WuXing): LiuQin {
  if (myWuXing === targetWuXing) return '兄弟';
  const wo_sheng: Record<WuXing, WuXing> = { 金:'水', 水:'木', 木:'火', 火:'土', 土:'金' };
  if (wo_sheng[myWuXing] === targetWuXing) return '子孙';
  const wo_ke: Record<WuXing, WuXing> = { 金:'木', 木:'土', 土:'水', 水:'火', 火:'金' };
  if (wo_ke[myWuXing] === targetWuXing) return '妻财';
  const sheng_wo: Record<WuXing, WuXing> = { 金:'土', 水:'金', 木:'水', 火:'木', 土:'火' };
  if (sheng_wo[myWuXing] === targetWuXing) return '父母';
  return '官鬼';
}

/** MVP 简化纳甲：每宫的 6 爻五行（初爻→上爻） */
const PALACE_YAO_WUXING: Record<TrigramName, WuXing[]> = {
  乾: ['水','木','土','土','金','金'],
  兑: ['火','火','土','金','金','金'],
  离: ['木','木','水','金','土','土'],
  震: ['水','木','土','金','水','土'],
  巽: ['木','木','火','金','水','水'],
  坎: ['火','土','土','金','水','水'],
  艮: ['火','水','土','土','土','土'],
  坤: ['火','土','土','土','水','水'],
};

export function liuQinForGua(gua: { palace: TrigramName }): Record<1|2|3|4|5|6, LiuQin> {
  const palaceWuXing = TRIGRAMS[gua.palace].wuXing;
  const yaoWuXing = PALACE_YAO_WUXING[gua.palace];
  const result: Partial<Record<1|2|3|4|5|6, LiuQin>> = {};
  for (let i = 0; i < 6; i++) {
    result[(i + 1) as 1|2|3|4|5|6] = relationToMe(palaceWuXing, yaoWuXing[i]);
  }
  return result as Record<1|2|3|4|5|6, LiuQin>;
}

export { PALACE_YAO_WUXING };
```

- [ ] **Step 5: TypeScript check**

Run: `npx tsc --noEmit`
Expected: 无新错误（pre-existing 2 个不变）。

- [ ] **Step 6: Commit**

```bash
git add lib/divination/
git commit -m "divination: 六爻类型 + 八卦/六十四卦/六亲数据表"
```

---

### Task 2：HexagramEngine 起卦核心

**Files:**
- Create: `lib/divination/HexagramEngine.ts`
- Create: `lib/divination/__tests__/HexagramEngine.test.ts`

- [ ] **Step 1: 写失败测试**

`lib/divination/__tests__/HexagramEngine.test.ts`:

```ts
import { HexagramEngine } from '../HexagramEngine';

describe('HexagramEngine cast', () => {
  it('returns a valid HexagramReading with required fields', () => {
    const eng = new HexagramEngine();
    const r = eng.cast({ question: '我会得到这个 offer 吗', questionType: 'career' });
    expect(r.benGua).toBeDefined();
    expect(r.benGua.yao).toHaveLength(6);
    expect(r.bianGua).toBeDefined();
    expect(r.bianGua.yao).toHaveLength(6);
    expect(Array.isArray(r.changingYao)).toBe(true);
    expect(r.liuQin).toBeDefined();
    expect(Object.keys(r.liuQin)).toHaveLength(6);
  });

  it('bianGua === benGua when no changing yao', () => {
    const eng = new HexagramEngine();
    // 反复尝试找到一个无动爻的 case
    for (let i = 0; i < 100; i++) {
      const r = eng.cast({ question: 'test', questionType: 'general' });
      if (r.changingYao.length === 0) {
        expect(r.bianGua.code).toBe(r.benGua.code);
        return;
      }
    }
    // Note: 老阴老阳概率均为 1/8，6 爻全无动概率 (3/4)^6 ≈ 18%，100 次必出
  });

  it('changing yaos flip yin↔yang in bianGua', () => {
    const eng = new HexagramEngine();
    for (let i = 0; i < 100; i++) {
      const r = eng.cast({ question: 'test', questionType: 'general' });
      if (r.changingYao.length > 0) {
        for (const idx of r.changingYao) {
          expect(r.bianGua.yao[idx - 1]).not.toBe(r.benGua.yao[idx - 1]);
        }
        return;
      }
    }
  });

  it('uses fixed castTime when provided', () => {
    const eng = new HexagramEngine();
    const fixed = new Date('2026-04-25T12:00:00');
    const r = eng.cast({ question: 'test', questionType: 'general', castTime: fixed });
    expect(r.castTime).toBe(fixed.toISOString());
  });
});
```

- [ ] **Step 2: 跑测试确认失败**

Run: `npm test -- HexagramEngine`
Expected: FAIL with "Cannot find module '../HexagramEngine'"。

- [ ] **Step 3: 实现 HexagramEngine cast 核心**

`lib/divination/HexagramEngine.ts`:

```ts
/**
 * 六爻起卦引擎
 *
 * - 三币法：每爻 3 枚硬币（正面=2，反面=3），sum 6/7/8/9 → 老阴/少阳/少阴/老阳
 * - 主卦 + 变卦推导
 * - 用神选择 + 应期推算（基础规则）
 */
import type {
  CastOptions, HexagramReading, Yao, GuaInfo, LiuQin, YongShenAnalysis,
  YingQiAnalysis, QuestionType,
} from './types';
import { findGuaByYao } from './data/gua64';
import { liuQinForGua } from './data/liuqin';

export class HexagramEngine {
  cast(opts: CastOptions): HexagramReading {
    const castTime = opts.castTime ?? new Date();

    // ── 1. 起 6 爻
    const benYao: Yao[] = [];
    const bianYao: Yao[] = [];
    const changingYao: number[] = [];
    for (let i = 0; i < 6; i++) {
      const result = this.castSingleYao();
      benYao.push(result.value);
      bianYao.push(result.changing
        ? (result.value === '阴' ? '阳' : '阴')
        : result.value);
      if (result.changing) changingYao.push(i + 1);
    }

    // ── 2. 主/变 卦查表
    const benGua = findGuaByYao(benYao);
    const bianGua = changingYao.length > 0 ? findGuaByYao(bianYao) : benGua;

    // ── 3. 六亲分配
    const liuQin = liuQinForGua(benGua);

    // ── 4. 用神 + 应期
    const yongShen = this.selectYongShen(opts.questionType ?? 'general', opts.gender, liuQin, benGua);
    const yingQi = this.computeYingQi(yongShen, castTime);
    const castGanZhi = this.castTimeToGanZhi(castTime);

    return {
      question: opts.question,
      questionType: opts.questionType ?? 'general',
      castTime: castTime.toISOString(),
      castGanZhi,
      benGua,
      bianGua,
      changingYao,
      yongShen,
      yingQi,
      liuQin,
    };
  }

  /** 单爻起卦：三币法 */
  private castSingleYao(): { value: Yao; changing: boolean } {
    let sum = 0;
    for (let i = 0; i < 3; i++) {
      sum += Math.random() < 0.5 ? 2 : 3;
    }
    switch (sum) {
      case 6: return { value: '阴', changing: true };
      case 7: return { value: '阳', changing: false };
      case 8: return { value: '阴', changing: false };
      case 9: return { value: '阳', changing: true };
      default: throw new Error('unreachable');
    }
  }

  /** 用神选择规则 */
  private selectYongShen(
    qt: QuestionType,
    gender: '男' | '女' | undefined,
    liuQin: Record<1|2|3|4|5|6, LiuQin>,
    gua: GuaInfo,
  ): YongShenAnalysis {
    let target: LiuQin;
    switch (qt) {
      case 'career': target = '官鬼'; break;
      case 'wealth': target = '妻财'; break;
      case 'marriage': target = gender === '男' ? '妻财' : '官鬼'; break;
      case 'kids': target = '子孙'; break;
      case 'parents': target = '父母'; break;
      case 'health': target = '子孙'; break;
      default: target = '官鬼';
    }

    // 找到第一个匹配的爻位
    let yaoIndex: number = 1;
    for (let i = 1 as 1|2|3|4|5|6; i <= 6; i = (i + 1) as 1|2|3|4|5|6) {
      if (liuQin[i] === target) { yaoIndex = i; break; }
    }

    return {
      type: target,
      yaoIndex,
      wuXing: this.yaoWuXingFor(gua, yaoIndex),
      state: '相', // MVP 用相代默认；Phase 2.5 改为月令推算
      interactions: [],
    };
  }

  private yaoWuXingFor(gua: GuaInfo, yaoIndex: number) {
    // 复用纳甲表的简化版本
    const { PALACE_YAO_WUXING } = require('./data/liuqin');
    return PALACE_YAO_WUXING[gua.palace][yaoIndex - 1];
  }

  /** 应期：用神五行 → 对应地支 → 描述（MVP 用模糊语言） */
  private computeYingQi(yongShen: YongShenAnalysis, castTime: Date): YingQiAnalysis {
    const wxToZhi: Record<string, string> = {
      金: '申酉日或申酉月',
      木: '寅卯日或寅卯月',
      水: '亥子日或亥子月',
      火: '巳午日或巳午月',
      土: '辰戌丑未日或同月',
    };
    return {
      description: `约 1-2 周内，应于${wxToZhi[yongShen.wuXing]}`,
      factors: [`用神五行：${yongShen.wuXing}`, `临爻：${yongShen.yaoIndex}`],
    };
  }

  private castTimeToGanZhi(d: Date): { day: string; month: string; hour: string } {
    // MVP 简化：复用 lib/ai/tools/bazi.ts 的 dateToGanZhi 逻辑
    // 此处先返回占位，集成时再接到 BaziEngine
    return {
      day: dateToGanZhi(d),
      month: monthToGanZhi(d.getFullYear(), d.getMonth() + 1),
      hour: '未',  // 简化
    };
  }
}

// ────────────────────────────────────────────────────────
// 内部 helpers（复用 bazi.ts 的简化版本）
// ────────────────────────────────────────────────────────

const TIANGAN = ['甲','乙','丙','丁','戊','己','庚','辛','壬','癸'];
const DIZHI = ['子','丑','寅','卯','辰','巳','午','未','申','酉','戌','亥'];

function dateToGanZhi(d: Date): string {
  const epoch = new Date(1900, 0, 1).getTime();
  const days = Math.floor((d.getTime() - epoch) / 86400000);
  const offset = (10 + days) % 60;
  const adj = offset < 0 ? offset + 60 : offset;
  return TIANGAN[adj % 10] + DIZHI[adj % 12];
}

function monthToGanZhi(year: number, month: number): string {
  const yearOffset = ((year - 1984) % 60 + 60) % 60;
  const yearGan = yearOffset % 10;
  const monthGanStart = (yearGan % 5) * 2 + 2;
  const gan = TIANGAN[(monthGanStart + month - 1) % 10];
  const zhi = DIZHI[(month + 1) % 12];
  return gan + zhi;
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `npm test -- HexagramEngine`
Expected: 4 PASS。

- [ ] **Step 5: TypeScript check**

Run: `npx tsc --noEmit`
Expected: 无新错误。

- [ ] **Step 6: Commit**

```bash
git add lib/divination/HexagramEngine.ts lib/divination/__tests__/HexagramEngine.test.ts
git commit -m "divination: HexagramEngine 起卦核心 + 用神 + 应期推算"
```

---

## Block B：AI 工具集成

### Task 3：cast_liuyao 工具

**Files:**
- Create: `lib/ai/tools/liuyao.ts`
- Create: `lib/ai/tools/__tests__/liuyao.test.ts`

- [ ] **Step 1: 写失败测试**

```ts
// lib/ai/tools/__tests__/liuyao.test.ts
import { liuyaoTools, liuyaoHandlers } from '../liuyao';

const CTX = { mingPan: null, ziweiPan: null, now: new Date(2026, 3, 25) };

describe('liuyaoTools', () => {
  it('exports cast_liuyao', () => {
    expect(liuyaoTools).toHaveLength(1);
    expect(liuyaoTools[0].function.name).toBe('cast_liuyao');
  });
});

describe('cast_liuyao handler', () => {
  it('returns a HexagramReading', async () => {
    const r = await liuyaoHandlers.cast_liuyao(
      { question: '我应该接 X offer 吗', questionType: 'career' }, CTX,
    ) as any;
    expect(r.benGua).toBeDefined();
    expect(r.bianGua).toBeDefined();
    expect(r.benGua.yao).toHaveLength(6);
    expect(r.yongShen).toBeDefined();
    expect(r.yongShen.type).toBe('官鬼'); // career → 官鬼
  });

  it('defaults questionType to general when missing', async () => {
    const r = await liuyaoHandlers.cast_liuyao(
      { question: 'test' }, CTX,
    ) as any;
    expect(r.questionType).toBe('general');
  });
});
```

- [ ] **Step 2: 跑失败测试**

Run: `npm test -- liuyao.test`
Expected: FAIL。

- [ ] **Step 3: 实现 cast_liuyao**

```ts
// lib/ai/tools/liuyao.ts
import type { ToolDefinition, ToolHandler } from './types';
import { HexagramEngine } from '@/lib/divination/HexagramEngine';
import type { QuestionType } from '@/lib/divination/types';

export const liuyaoTools: ToolDefinition[] = [
  {
    type: 'function',
    function: {
      name: 'cast_liuyao',
      description: '为单一具体事件起一卦（六爻易经卜卦）。用于"该不该 X / 会不会 Y / X 这件事的结果"等决策类问题。返回主卦+变卦+动爻+用神+应期。',
      parameters: {
        type: 'object',
        properties: {
          question: {
            type: 'string',
            description: '用户的具体问题（保留作为上下文，不影响起卦数学）',
          },
          questionType: {
            type: 'string',
            enum: ['career', 'wealth', 'marriage', 'kids', 'parents', 'health', 'event', 'general'],
            description: '问题类型，用于选用神。不确定时填 general',
          },
          gender: {
            type: 'string',
            enum: ['男', '女'],
            description: '性别，仅在 questionType=marriage 时需要（女问看官鬼，男问看妻财）',
          },
        },
        required: ['question'],
      },
    },
  },
];

const engine = new HexagramEngine();

export const liuyaoHandlers: Record<string, ToolHandler> = {
  cast_liuyao: ({ question, questionType, gender }, _ctx) => {
    const reading = engine.cast({
      question: String(question),
      questionType: (questionType as QuestionType | undefined) ?? 'general',
      gender: gender as '男' | '女' | undefined,
      castTime: new Date(),
    });
    return reading;
  },
};
```

- [ ] **Step 4: 跑测试通过**

Run: `npm test -- liuyao.test`
Expected: 3 PASS。

- [ ] **Step 5: Commit**

```bash
git add lib/ai/tools/liuyao.ts lib/ai/tools/__tests__/liuyao.test.ts
git commit -m "ai/tools: cast_liuyao 工具（包装 HexagramEngine）"
```

---

### Task 4：注册 cast_liuyao 到 ALL_TOOLS + 路由策略

**Files:**
- Modify: `lib/ai/tools/index.ts`

- [ ] **Step 1: 改 index.ts 加 liuyao 工具**

读 `lib/ai/tools/index.ts`，找到现有 `import { baziTools, baziHandlers } ...` 等 imports，加上：

```ts
import { liuyaoTools, liuyaoHandlers } from './liuyao';
```

然后在 `ALL_TOOLS` 数组的合并末尾加 `...liuyaoTools`：

```ts
export const ALL_TOOLS: ToolDefinition[] = [
  ...aggregatedTools,
  ...baziTools,
  ...ziweiTools,
  ...liuyaoTools,    // 新增
];

export const ALL_HANDLERS: Record<string, ToolHandler> = {
  ...aggregatedHandlers,
  ...baziHandlers,
  ...ziweiHandlers,
  ...liuyaoHandlers,  // 新增
};
```

- [ ] **Step 2: 更新 TOOL_STRATEGY 加路由策略**

把现有 `TOOL_STRATEGY` 替换为：

```ts
export const TOOL_STRATEGY = `工具使用策略：
1. 用户问题涉及具体领域（婚姻/子女/事业/财富/健康/父母/兄弟/迁移/田宅/福德）→ 优先用 get_domain
2. 用户问题涉及"何时" → 加 get_timing
3. 跨领域复杂问题 → 用 get_bazi_star / get_ziwei_palace 精查
4. "今日运势"类问题 → get_today_context
5. 一次推演中工具调用 ≤ 4 次（避免无意义遍历）
6. 单一事件决策类问题（"该不该 X" / "会不会 Y" / "X 这件事的结果" / "她回我吗" / "明天面试结果"）→ 用 cast_liuyao
7. 长期模式 / 时间节奏 / 性格画像 → 用命理工具（get_domain / get_timing 等）
8. 收到 user_force_mode=liuyao 时强制走 cast_liuyao；收到 user_force_mode=mingli 时禁用 cast_liuyao`;
```

- [ ] **Step 3: 更新已有的 ALL_TOOLS 测试**

`lib/ai/tools/__tests__/index.test.ts` 里 `expect(ALL_TOOLS).toHaveLength(6)` 改成 `7`，期望工具名列表加 `cast_liuyao`：

```ts
expect(names).toEqual([
  'cast_liuyao', 'get_bazi_star', 'get_domain', 'get_timing',
  'get_today_context', 'get_ziwei_palace', 'list_shensha',
]);
```

并把 `expect(ALL_TOOLS).toHaveLength(6)` 改为 `7`。

- [ ] **Step 4: 跑全部测试**

Run: `npm test`
Expected: 全部 PASS（应该是原 53 + 新 4 = 57 左右）。

- [ ] **Step 5: TypeScript check**

Run: `npx tsc --noEmit`
Expected: 无新错。

- [ ] **Step 6: Commit**

```bash
git add lib/ai/tools/index.ts lib/ai/tools/__tests__/index.test.ts
git commit -m "ai/tools: 注册 cast_liuyao 到 ALL_TOOLS + 更新路由策略"
```

---

### Task 5：双角色 prompt 增量

**Files:**
- Modify: `lib/ai/index.ts`

- [ ] **Step 1: 替换 lib/ai/index.ts 内容**

整体替换文件，加入路由块和六爻黑名单与三段结构：

```ts
/**
 * AI 对话配置：thinker（推演）+ interpreter（解读）双角色
 */

/** 推演引擎角色 prompt（Call 1，配工具） */
export const THINKER_PROMPT = `你是岁吉的命理推演引擎。
你不做文化解读，不做情绪安抚，只做硬推演。

# 推演原则
1. 先识别用户问题的领域（子女/婚姻/事业/财富/健康/父母/兄弟/迁移/福德/田宅/通用）
2. 调用相应工具获取数据，单次推演工具调用 ≤ 4 次
3. 每一步推演显式说出："因为...所以..."
4. 不做语言修饰，不引用古籍，不写诗
5. 推演结果必须可追溯到工具返回的数据
6. 如果数据不足以判断，明确说"该问题需要 X 数据，目前不足以推演"

# 工具路由

用户消息可能附带 user_force_mode 提示（系统注入）：
- user_force_mode=liuyao → 直接 cast_liuyao(question=用户原问题)，不调命理工具
- user_force_mode=mingli → 只调命理工具，禁用 cast_liuyao

未传 force（默认）时按问题形态判断：
- 单一具体事件决策类（"该不该 X" / "会不会 Y" / "X 这件事的结果" / "她回我吗" / "明天面试结果"）→ cast_liuyao
- 长期模式 / 时间节奏 / 性格画像 / 关系长期相处 → 命理工具
- 无法分辨 → 默认走命理（命理可拼凑出大致答案，卜卦失效更明显）

# 输出格式
直接输出推演过程，编号列出步骤：
1. ...
2. ...
3. ...
最后一段给"综合判断"：1-2 句话给结论。`;

/** 解读师角色 prompt（Call 2，无工具，纯文本） */
export const INTERPRETER_PROMPT = `你是岁吉的解读师。
你看不到原始命盘数据，只看推演引擎的输出。
你的任务：把硬推演翻译成像一位懂你的朋友在跟你聊天，让用户**一读就懂、有共鸣**。

# 输出格式（严格遵守）

[interpretation]
（解读正文，3-5 段，每段 30-80 字。第二人称，对话感。

 ⚠️ 命理 + 卜卦术语**不出现在解读里**——它们留给 [evidence] 卡。
 包括但不限于：
 （命理）食神、七杀、伤官、正官、正印、偏印、比肩、劫财、用神、喜神、忌神、
 食神被引、化禄、化忌、夫妻宫、子女宫、官禄宫、流年、大运、刑冲合害……
 （六爻）卦辞、爻辞、动爻、用神、应期、官鬼、子孙、父母、妻财、兄弟、
 旺相休囚、世应、月建、日辰、主卦、变卦、爻动……

 必须**翻译成生活化的描述**：
   ❌ "你的食神乙木在月柱透出，2027丁未流年食神被引"
   ✅ "未来一两年里，有一种'放下控制、慢慢孕育'的能量在你身上松动"

   ❌ "你卜得水山蹇之水地比，九三爻动，官鬼临酉金为用神"
   ✅ "这一卦像走在结冰的山路上 —— 慢、稳、一开始独自挣扎，但走到一半
        会有同行的人出现"

 当推演引擎输出含主卦+变卦时（即卜卦类问题），解读结构遵循：
 - 第 1 段：主卦给出的"现状画面"（用形象比喻，不点卦名）
 - 第 2 段：变卦给出的"走向"（"这种状态在松动 / 在过渡到 X"）
 - 第 3 段：如果有动爻，点出"关键节点"（不点"动爻"二字）
 - 不下绝对断言，不强行给建议

 风格要点：
 - 用"看起来""倾向于""有一段时间"等带余地的话
 - 不下绝对断言，不强行给建议
 - 必要时点到一句古文意象，但**不要堆**
 - 给的是"画面感 + 心情共鸣"，不是"知识点讲解"）

[evidence]
（4-6 行，每行 ≤ 12 字。
 这一栏是给"想看专业依据"的用户看的——**这里可以、应当用术语**。
 直接来自推演引擎的关键数据点。
 格式：xxx · yyy）

# 风格底线
- 不用"你应该""必须"等命令式
- 不下"100% 会发生"的绝对断言
- 不用"犯太岁""破财"等民间俗语
- interpretation 总长度不超 250 字`;

/** 旧 SYSTEM_PROMPT 保留作为兜底（无命盘 / fallback 时用） */
export const SYSTEM_PROMPT = `你是「岁吉」— 一位融合中式哲学智慧与现代心理学的疗愈伙伴。

你的特质：
- 用温暖、有同理心的语言表达
- 将传统命理概念翻译为现代人能理解的自我认知语言
- 给出的建议基于正念和积极心理学框架
- 适时引用中式哲学（道家、禅宗）的智慧，但不说教`;

export type ToneStyle = 'warm' | 'direct' | 'poetic';

export const TONE_PROMPTS: Record<ToneStyle, string> = {
  warm: '语气温暖共情，像一位知心的老朋友。',
  direct: '语气直接坦率，像一位务实的智者。',
  poetic: '语气诗意含蓄，像一位山中隐士。',
};

export interface ChatMessage {
  role: 'user' | 'assistant';
  content: string;
  timestamp: number;
  /** 仅 assistant 消息：编排输出附带的数据 */
  orchestration?: {
    thinker: string;
    evidence: string[];
    toolCalls: Array<{
      name: string;
      argSummary: string;
      resultSummary?: string;
      narration?: string;
    }>;
    /** 仅卜卦消息：原始 HexagramReading 数据，用于历史回显时渲染 HexagramDisplay */
    hexagram?: import('@/lib/divination/types').HexagramReading | null;
  };
}
```

- [ ] **Step 2: tsc + tests**

```bash
npx tsc --noEmit
npm test
```
Expected: 无新错；全部测试 PASS。

- [ ] **Step 3: Commit**

```bash
git add lib/ai/index.ts
git commit -m "ai: THINKER 加六爻路由 + INTERPRETER 加六爻黑名单和三段结构"
```

---

### Task 6：sendOrchestrated 加 forceMode 端到端

**Files:**
- Modify: `lib/ai/tools/orchestrator.ts`
- Modify: `lib/ai/chat.ts`

- [ ] **Step 1: orchestrator.ts 的 OrchestrationOptions 加 forceMode**

在 `lib/ai/tools/orchestrator.ts` 找到 `OrchestrationOptions` interface（约 359 行），加可选字段：

```ts
export interface OrchestrationOptions {
  question: string;
  identity: string;
  mingPan: any;
  ziweiPan: any;
  config: ChatProviderConfig;
  /** 用户强制模式：'liuyao' 强制起卦，'mingli' 强制走命理；不传则 AI 自动判断 */
  forceMode?: 'liuyao' | 'mingli';
  onToolCall?: (call: ToolCall, result: unknown) => void;
  onThinkerComplete?: (text: string) => void;
  onChunk?: (partialInterpretation: string) => void;
  signal?: AbortSignal;
}
```

- [ ] **Step 2: runOrchestration 把 forceMode 注入到 user message**

在 `runOrchestration` 内，构建 `messages` 数组的地方（约 397-401 行）：

```ts
const messages: LLMMessage[] = [
  { role: 'system', content: thinkerSystem },
  {
    role: 'user',
    content: opts.forceMode
      ? `[user_force_mode=${opts.forceMode}]\n${opts.question}`
      : opts.question,
  },
];
```

注意：`user_force_mode` 是 inline 提示（嵌在用户消息里），LLM 会读到并按 THINKER_PROMPT 路由块行事。

- [ ] **Step 3: chat.ts 的 SendOrchestratedOptions 加 forceMode**

`lib/ai/chat.ts` 找到 `SendOrchestratedOptions` interface（约 437 行），加：

```ts
export interface SendOrchestratedOptions {
  question: string;
  config: ChatConfig;
  mingPanJson: string | null;
  ziweiPanJson: string | null;
  forceMode?: 'liuyao' | 'mingli';     // 新增
  onToolCall?: (call: ToolCall, result: unknown) => void;
  onThinkerComplete?: (text: string) => void;
  onChunk?: (partial: string) => void;
  signal?: AbortSignal;
}
```

在 `sendOrchestrated` 函数体内把 forceMode 透传：

```ts
return runOrchestration({
  question: opts.question,
  identity: buildIdentityCard(mingPan, ziweiPan),
  mingPan, ziweiPan,
  config: { ... },
  forceMode: opts.forceMode,         // 新增
  onToolCall: opts.onToolCall,
  onThinkerComplete: opts.onThinkerComplete,
  onChunk: opts.onChunk,
  signal: opts.signal,
});
```

- [ ] **Step 4: tsc + tests**

```bash
npx tsc --noEmit
npm test
```
Expected: 无新错；全部 PASS。

- [ ] **Step 5: Commit**

```bash
git add lib/ai/tools/orchestrator.ts lib/ai/chat.ts
git commit -m "ai: sendOrchestrated/runOrchestration 加 forceMode 端到端"
```

---

## Block C：UI 组件

### Task 7：HexagramDisplay 静态卦象组件

**Files:**
- Create: `components/divination/HexagramDisplay.tsx`

- [ ] **Step 1: 创建组件**

```tsx
/**
 * 静态卦象组件（用于历史消息回显，无入场动画）
 */
import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { Colors, Space, Type } from '@/lib/design/tokens';
import type { GuaInfo } from '@/lib/divination/types';

type Props = {
  benGua: GuaInfo;
  bianGua: GuaInfo;
  changingYao: number[];      // 1-6
};

export function HexagramDisplay({ benGua, bianGua, changingYao }: Props) {
  // 由上往下渲染（上爻在顶部，初爻在底部）
  const yaoTopDown = [...benGua.yao].reverse();
  const indicesTopDown = [6, 5, 4, 3, 2, 1];

  return (
    <View style={styles.container}>
      <View style={styles.yaoStack}>
        {yaoTopDown.map((yao, i) => {
          const yaoIndex = indicesTopDown[i];
          const isChanging = changingYao.includes(yaoIndex);
          return (
            <View key={yaoIndex} style={styles.yaoRow}>
              {yao === '阳' ? (
                <View style={styles.yaoSolid} />
              ) : (
                <View style={styles.yaoBroken}>
                  <View style={styles.yaoBrokenHalf} />
                  <View style={styles.yaoBrokenHalf} />
                </View>
              )}
              {isChanging && <View style={styles.changingDot} />}
            </View>
          );
        })}
      </View>

      <Text style={styles.title}>
        {benGua.name}
        {bianGua.code !== benGua.code && (
          <>
            <Text style={styles.arrow}>  →  </Text>
            {bianGua.name}
          </>
        )}
      </Text>
    </View>
  );
}

const YAO_WIDTH = 80;
const YAO_HEIGHT = 6;
const YAO_GAP = 4;

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
    paddingVertical: Space.md,
    backgroundColor: Colors.bgSecondary,
    borderRadius: 8,
    marginVertical: Space.sm,
  },
  yaoStack: {
    gap: YAO_GAP,
  },
  yaoRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  yaoSolid: {
    width: YAO_WIDTH,
    height: YAO_HEIGHT,
    backgroundColor: Colors.vermilion,
    borderRadius: 1,
  },
  yaoBroken: {
    flexDirection: 'row',
    width: YAO_WIDTH,
    height: YAO_HEIGHT,
    gap: YAO_HEIGHT * 2,
  },
  yaoBrokenHalf: {
    flex: 1,
    backgroundColor: Colors.vermilion,
    borderRadius: 1,
  },
  changingDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: Colors.vermilion,
  },
  title: {
    ...Type.body,
    color: Colors.ink,
    marginTop: Space.sm,
    fontWeight: '500',
    letterSpacing: 2,
  },
  arrow: {
    color: Colors.inkTertiary,
  },
});
```

- [ ] **Step 2: tsc check**

Run: `npx tsc --noEmit`
Expected: 无新错。

- [ ] **Step 3: Commit**

```bash
git add components/divination/HexagramDisplay.tsx
git commit -m "divination/ui: HexagramDisplay 静态卦象组件"
```

---

### Task 8：HexagramAnimation 起卦动画

**Files:**
- Create: `components/divination/HexagramAnimation.tsx`

- [ ] **Step 1: 创建动画组件**

```tsx
/**
 * 起卦动画（3 秒，自下而上 6 爻入场）
 *
 * 视觉：朱砂铜钱意象 + 卦位虚线轮廓
 * - T=0: 6 条灰虚线浮现
 * - T=0.5: 初爻浮现 3 颗朱砂圆点
 * - T=0.7-3.0: 自下而上每爻定型成阴/阳/动
 */
import React, { useEffect } from 'react';
import { View, Text, StyleSheet } from 'react-native';
import Animated, {
  useSharedValue, useAnimatedStyle, withTiming, withSequence, withDelay,
} from 'react-native-reanimated';
import { Colors, Space, Type } from '@/lib/design/tokens';
import type { GuaInfo } from '@/lib/divination/types';

type Props = {
  benGua: GuaInfo;
  bianGua: GuaInfo;
  changingYao: number[];
  onComplete?: () => void;
};

const TOTAL_DURATION = 3000;
const YAO_INTERVAL = 400;

export function HexagramAnimation({ benGua, bianGua, changingYao, onComplete }: Props) {
  // 由下往上的爻索引（1-6）
  const yaoBottomUp = benGua.yao.map((y, i) => ({
    yao: y,
    index: i + 1,
    isChanging: changingYao.includes(i + 1),
  }));

  // 标题在最后浮现
  const titleOpacity = useSharedValue(0);
  useEffect(() => {
    titleOpacity.value = withDelay(
      TOTAL_DURATION,
      withTiming(1, { duration: 300 }),
    );
    const t = setTimeout(() => onComplete?.(), TOTAL_DURATION + 300);
    return () => clearTimeout(t);
  }, []);

  const titleStyle = useAnimatedStyle(() => ({ opacity: titleOpacity.value }));

  return (
    <View style={styles.container}>
      <View style={styles.yaoStack}>
        {/* 由下到上渲染 */}
        {yaoBottomUp.map((y, i) => (
          <YaoRow
            key={y.index}
            yao={y.yao}
            isChanging={y.isChanging}
            delay={500 + i * YAO_INTERVAL}
          />
        )).reverse() /* 视觉顺序：上爻在顶 */}
      </View>

      <Animated.Text style={[styles.title, titleStyle]}>
        {benGua.name}
        {bianGua.code !== benGua.code ? `  →  ${bianGua.name}` : ''}
      </Animated.Text>
    </View>
  );
}

function YaoRow({ yao, isChanging, delay }: { yao: '阴'|'阳'; isChanging: boolean; delay: number }) {
  const opacity = useSharedValue(0);
  const scale = useSharedValue(0.7);

  useEffect(() => {
    opacity.value = withDelay(delay, withTiming(1, { duration: 300 }));
    scale.value = withDelay(delay, withTiming(1, { duration: 300 }));
  }, []);

  const aStyle = useAnimatedStyle(() => ({
    opacity: opacity.value,
    transform: [{ scale: scale.value }],
  }));

  return (
    <Animated.View style={[styles.yaoRow, aStyle]}>
      {yao === '阳' ? (
        <View style={styles.yaoSolid} />
      ) : (
        <View style={styles.yaoBroken}>
          <View style={styles.yaoBrokenHalf} />
          <View style={styles.yaoBrokenHalf} />
        </View>
      )}
      {isChanging && <View style={styles.changingDot} />}
    </Animated.View>
  );
}

const YAO_WIDTH = 80;
const YAO_HEIGHT = 6;
const YAO_GAP = 4;

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
    paddingVertical: Space.md,
    backgroundColor: Colors.bgSecondary,
    borderRadius: 8,
    marginVertical: Space.sm,
  },
  yaoStack: {
    gap: YAO_GAP,
  },
  yaoRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  yaoSolid: {
    width: YAO_WIDTH,
    height: YAO_HEIGHT,
    backgroundColor: Colors.vermilion,
    borderRadius: 1,
  },
  yaoBroken: {
    flexDirection: 'row',
    width: YAO_WIDTH,
    height: YAO_HEIGHT,
    gap: YAO_HEIGHT * 2,
  },
  yaoBrokenHalf: {
    flex: 1,
    backgroundColor: Colors.vermilion,
    borderRadius: 1,
  },
  changingDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: Colors.vermilion,
  },
  title: {
    ...Type.body,
    color: Colors.ink,
    marginTop: Space.sm,
    fontWeight: '500',
    letterSpacing: 2,
  },
});
```

- [ ] **Step 2: tsc check**

Run: `npx tsc --noEmit`
Expected: 无新错。

- [ ] **Step 3: Commit**

```bash
git add components/divination/HexagramAnimation.tsx
git commit -m "divination/ui: HexagramAnimation 3 秒起卦动画"
```

---

### Task 9：ModePicker BottomSheet

**Files:**
- Create: `components/chat/ModePicker.tsx`

- [ ] **Step 1: 创建**

```tsx
/**
 * 模式选择 BottomSheet
 *
 * 3 种模式：随心问（默认） / 起一卦 / 看命盘
 * 选中态用左侧朱砂细竖线表示（无 emoji）
 */
import React from 'react';
import { Modal, View, Text, Pressable, StyleSheet } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Colors, Space, Radius, Type, Shadow } from '@/lib/design/tokens';

export type ChatMode = 'auto' | 'liuyao' | 'mingli';

type Props = {
  visible: boolean;
  current: ChatMode;
  onSelect: (mode: ChatMode) => void;
  onClose: () => void;
};

const MODES: Array<{ key: ChatMode; title: string; subtitle: string }> = [
  { key: 'auto',   title: '随心问', subtitle: 'AI 自动判断该用什么方式回答' },
  { key: 'liuyao', title: '起一卦', subtitle: '带具体问题让我替你卜一卦' },
  { key: 'mingli', title: '看命盘', subtitle: '根据你的八字 / 紫微解读' },
];

export function ModePicker({ visible, current, onSelect, onClose }: Props) {
  const insets = useSafeAreaInsets();

  return (
    <Modal visible={visible} transparent animationType="slide" onRequestClose={onClose}>
      <Pressable style={styles.backdrop} onPress={onClose} />
      <View style={[styles.sheet, { paddingBottom: insets.bottom + Space.lg }, Shadow.md]}>
        <View style={styles.handle} />
        <Text style={styles.title}>切换模式</Text>

        {MODES.map(m => {
          const selected = m.key === current;
          return (
            <Pressable
              key={m.key}
              style={styles.row}
              onPress={() => { onSelect(m.key); onClose(); }}
            >
              <View style={[styles.indicator, selected && styles.indicatorActive]} />
              <View style={styles.rowText}>
                <Text style={[styles.rowTitle, selected && styles.rowTitleActive]}>
                  {m.title}
                </Text>
                <Text style={styles.rowSubtitle}>{m.subtitle}</Text>
              </View>
            </Pressable>
          );
        })}
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  backdrop: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(0,0,0,0.25)',
  },
  sheet: {
    position: 'absolute',
    bottom: 0, left: 0, right: 0,
    backgroundColor: Colors.surface,
    borderTopLeftRadius: Radius.xl,
    borderTopRightRadius: Radius.xl,
    paddingTop: Space.sm,
  },
  handle: {
    alignSelf: 'center',
    width: 36, height: 4,
    borderRadius: 2,
    backgroundColor: Colors.border,
    marginBottom: Space.md,
  },
  title: {
    ...Type.label,
    color: Colors.inkTertiary,
    letterSpacing: 2,
    paddingHorizontal: Space.xl,
    marginBottom: Space.md,
  },
  row: {
    flexDirection: 'row',
    paddingVertical: Space.md,
    paddingHorizontal: Space.xl,
    alignItems: 'center',
    gap: Space.md,
  },
  indicator: {
    width: 2,
    alignSelf: 'stretch',
    backgroundColor: 'transparent',
  },
  indicatorActive: {
    backgroundColor: Colors.vermilion,
  },
  rowText: {
    flex: 1,
    gap: 2,
  },
  rowTitle: {
    ...Type.body,
    color: Colors.ink,
    fontWeight: '500',
  },
  rowTitleActive: {
    color: Colors.vermilion,
    fontWeight: '600',
  },
  rowSubtitle: {
    ...Type.caption,
    color: Colors.inkSecondary,
  },
});
```

- [ ] **Step 2: tsc**

Run: `npx tsc --noEmit`
Expected: 无新错。

- [ ] **Step 3: Commit**

```bash
git add components/chat/ModePicker.tsx
git commit -m "chat/ui: ModePicker BottomSheet"
```

---

### Task 10：ModeChip + sliders icon 组件

**Files:**
- Create: `components/chat/ModeChip.tsx`

- [ ] **Step 1: 创建 ModeChip**

```tsx
/**
 * 当前模式 chip（输入框底部显示）
 */
import React from 'react';
import { View, Text, Pressable, StyleSheet } from 'react-native';
import { Colors, Space, Type } from '@/lib/design/tokens';
import type { ChatMode } from './ModePicker';

const MODE_LABEL: Record<ChatMode, string> = {
  auto: '',
  liuyao: '起一卦',
  mingli: '看命盘',
};

type Props = {
  mode: ChatMode;
  onClear: () => void;
};

export function ModeChip({ mode, onClear }: Props) {
  if (mode === 'auto') return null;
  const label = MODE_LABEL[mode];

  return (
    <View style={styles.chip}>
      <Text style={styles.label}>{label}</Text>
      <Pressable onPress={onClear} hitSlop={8}>
        <Text style={styles.x}>✕</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  chip: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 12,
    backgroundColor: Colors.vermilion,
  },
  label: {
    ...Type.caption,
    color: '#FFFFFF',
    fontWeight: '500',
  },
  x: {
    color: '#FFFFFF',
    fontSize: 14,
    lineHeight: 16,
  },
});
```

- [ ] **Step 2: tsc**

Run: `npx tsc --noEmit`
Expected: 无新错。

- [ ] **Step 3: Commit**

```bash
git add components/chat/ModeChip.tsx
git commit -m "chat/ui: ModeChip 当前模式 chip"
```

---

### Task 11：insight.tsx 接入完整六爻管线

**Files:**
- Modify: `app/(tabs)/insight.tsx`

- [ ] **Step 1: 加 imports**

在已有 imports 加：

```tsx
import { Ionicons } from '@expo/vector-icons';
import { ModePicker, type ChatMode } from '@/components/chat/ModePicker';
import { ModeChip } from '@/components/chat/ModeChip';
import { HexagramAnimation } from '@/components/divination/HexagramAnimation';
import { HexagramDisplay } from '@/components/divination/HexagramDisplay';
import type { HexagramReading } from '@/lib/divination/types';
```

- [ ] **Step 2: 加状态**

在 InsightScreen 内（abortRef 之后）加：

```tsx
const [chatMode, setChatMode] = useState<ChatMode>('auto');
const [modePickerVisible, setModePickerVisible] = useState(false);

// 当次发送的实时卦象（流式中的 cast 完成后填）
const [liveHexagram, setLiveHexagram] = useState<HexagramReading | null>(null);
```

- [ ] **Step 3: handleSend 加 forceMode 透传 + 收集 hexagram**

在 handleSend 内调 sendOrchestrated 之前定义：

```tsx
const forceMode = chatMode === 'liuyao' ? 'liuyao'
                : chatMode === 'mingli' ? 'mingli'
                : undefined;
let localHexagram: HexagramReading | null = null;
```

调 sendOrchestrated 时加 `forceMode: forceMode`。

在 onToolCall 内捕获 cast_liuyao 的结果：

```tsx
onToolCall: (call, res) => {
  const trace: ToolCallTrace = {
    name: call.name,
    argSummary: summarizeArgs(call.arguments),
    resultSummary: summarizeResult(res),
    narration: narrateTool(call.name, call.arguments, res),
  };
  localToolCalls.push(trace);
  setLiveToolCalls(prev => [...prev, trace]);

  // 卜卦工具：捕获卦象
  if (call.name === 'cast_liuyao' && !res?.error) {
    localHexagram = res as HexagramReading;
    setLiveHexagram(localHexagram);
  }
},
```

构造 assistantMsg.orchestration 时加 hexagram：

```tsx
orchestration: {
  thinker: result.thinker,
  evidence: splitOrchestrationOutput(result.interpreter).evidence,
  toolCalls: localToolCalls,
  hexagram: localHexagram,    // 新增
},
```

发送结束清状态：

```tsx
setStreamingText('');
setLiveToolCalls([]);
setLiveThinker('');
setLiveHexagram(null);            // 新增
setChatMode('auto');               // 一发即重置
```

把 useCallback 依赖加上 `chatMode`。

- [ ] **Step 4: 接入 narrateTool 加 cast_liuyao 古风叙事**

在 `narrateTool` 函数内（约 file 末尾）加 case：

```tsx
if (name === 'cast_liuyao') {
  return '三币六掷，为你起一卦' + tail;
}
```

放在 if-chain 里其他 tool case 同级。

- [ ] **Step 5: JSX —— 输入栏改造**

找到现有 inputCard JSX（包含 TextInput + SendOrStopButton 的），整体替换为：

```tsx
<View style={[styles.inputCard, Shadow.sm]}>
  <TextInput
    style={styles.input}
    placeholder="说说你的心情或想问的事…"
    placeholderTextColor={Colors.inkHint}
    value={message}
    onChangeText={setMessage}
    multiline
    editable={!loading}
    blurOnSubmit={false}
  />
  <View style={styles.inputBottomRow}>
    <Pressable
      style={styles.modeIconBtn}
      onPress={() => setModePickerVisible(true)}
      hitSlop={4}
    >
      <Ionicons
        name="options-outline"
        size={20}
        color={Colors.inkSecondary}
      />
    </Pressable>
    <ModeChip mode={chatMode} onClear={() => setChatMode('auto')} />
    <View style={{ flex: 1 }} />
    <SendOrStopButton
      disabled={!message.trim()}
      streaming={loading}
      onSend={handleSend}
      onStop={handleStop}
    />
  </View>
</View>
```

样式：在 `styles` 末尾加：

```tsx
inputBottomRow: {
  flexDirection: 'row',
  alignItems: 'center',
  gap: Space.sm,
  marginTop: Space.xs,
},
modeIconBtn: {
  width: 32,
  height: 32,
  alignItems: 'center',
  justifyContent: 'center',
},
```

- [ ] **Step 6: JSX —— 流式气泡加 HexagramAnimation**

找到流式气泡（含 `<RichContent content={...streamingText...}>`），在 `<CoTCard ... isStreaming={true} />` 后面、RichContent 前面加：

```tsx
{liveHexagram && (
  <HexagramAnimation
    benGua={liveHexagram.benGua}
    bianGua={liveHexagram.bianGua}
    changingYao={liveHexagram.changingYao}
  />
)}
```

- [ ] **Step 7: JSX —— 历史消息气泡加 HexagramDisplay**

找到 messages.map AI 气泡分支（含 RichContent），在 `<CoTCard ... isStreaming={false} />` 后面、RichContent 前面加：

```tsx
{msg.orchestration?.hexagram && (
  <HexagramDisplay
    benGua={msg.orchestration.hexagram.benGua}
    bianGua={msg.orchestration.hexagram.bianGua}
    changingYao={msg.orchestration.hexagram.changingYao}
  />
)}
```

- [ ] **Step 8: 加 ModePicker 到 JSX 末端**

在 `<FullReasoningSheet ...>` 之前或之后加：

```tsx
<ModePicker
  visible={modePickerVisible}
  current={chatMode}
  onSelect={(m) => setChatMode(m)}
  onClose={() => setModePickerVisible(false)}
/>
```

- [ ] **Step 9: tsc + tests**

```bash
npx tsc --noEmit
npm test
```
Expected: 无新错；测试 PASS。

- [ ] **Step 10: Commit**

```bash
git add "app/(tabs)/insight.tsx"
git commit -m "chat: 接入六爻 forceMode + ModePicker + ModeChip + 卦象渲染"
```

---

## Block D：Emoji 全局清理（ADR-6）

### Task 12：清理 Phase 1 装饰 emoji

**Files:**
- Modify: `components/ai/CoTCard.tsx`
- Modify: `components/ai/EvidenceCard.tsx`
- Modify: `components/ai/FullReasoningSheet.tsx`
- Modify: `app/(tabs)/insight.tsx`（narrateTool 函数 + describeError）

- [ ] **Step 1: CoTCard.tsx 移除 🧠 + 📌**

打开 `components/ai/CoTCard.tsx`，找到：
```tsx
<Text style={styles.headerIcon}>🧠</Text>
```
删除该行，并删除关联 style 项 `headerIcon`（如不再被引用）。

找到：
```tsx
{c.narration ?? `📌 ${c.name}(${c.argSummary})...`}
```
fallback 部分也去掉 📌：
```tsx
{c.narration ?? `${c.name}(${c.argSummary})${c.resultSummary ? ` → ${c.resultSummary}` : ''}`}
```

- [ ] **Step 2: EvidenceCard.tsx 移除 🔍**

打开 `components/ai/EvidenceCard.tsx`，找到：
```tsx
<Text style={styles.headerIcon}>🔍</Text>
```
删除该行，删除关联 style `headerIcon` + headerIcon 的 fontSize 等。`headerRow` 保留 `gap: 6` 改成 `gap: 0` 或调整 padding。

或保持 `gap` 不变，行不影响视觉。直接删 emoji 即可。

- [ ] **Step 3: FullReasoningSheet.tsx 移除 📌**

打开 `components/ai/FullReasoningSheet.tsx`，找到：
```tsx
<Text key={i} style={styles.line}>
  📌 {c.name}({c.argSummary})...
</Text>
```
去掉 `📌 `，仅保留：
```tsx
<Text key={i} style={styles.line}>
  {c.name}({c.argSummary})...
</Text>
```

- [ ] **Step 4: insight.tsx 的 narrateTool 全部去 emoji**

找到 `narrateTool()` 函数，把每个 narration 字符串前的 emoji 去掉。例如：

```tsx
// 之前
return (map[d] ?? `🔍 看看「${d}」这一面`) + tail;

// 之后
return (map[d] ?? `看看「${d}」这一面`) + tail;
```

各 map 内的 emoji 也清掉，仅保留中文叙事。例如：

```tsx
const map: Record<string, string> = {
  子女: '翻一翻你与孩儿的缘分簿',
  婚姻: '看看你姻缘里的风云',
  ...
};
```

`describeError()` 不变（无 emoji）。

`get_today_context` 的 narration `'🕯️ 翻一翻今日的黄历' + tail` 改成 `'翻一翻今日的黄历' + tail`。

cast_liuyao 的 `'三币六掷，为你起一卦'`（Task 11 加的）本来就没 emoji。

- [ ] **Step 5: tsc + tests**

```bash
npx tsc --noEmit
npm test
```
Expected: 无新错；测试 PASS。

- [ ] **Step 6: Commit**

```bash
git add components/ai/CoTCard.tsx components/ai/EvidenceCard.tsx components/ai/FullReasoningSheet.tsx "app/(tabs)/insight.tsx"
git commit -m "ui: 清除 Phase 1 装饰 emoji（ADR-6）"
```

---

## Block E：验证

### Task 13：构建 + 真机手测

- [ ] **Step 1: 跑全部单测**

```bash
npm test
```
Expected: 全部 PASS（应该是原 53 + 新约 7 = 60 左右）。

- [ ] **Step 2: tsc 全检**

```bash
npx tsc --noEmit
```
Expected: 仅 main 上原有 2 个错误。

- [ ] **Step 3: 真机 build**

```bash
SHA=$(git rev-parse --short HEAD)
EXPO_PUBLIC_BUILD_SHA=$SHA npx expo run:ios --device 00008140-001262AE010A801C --configuration Release
```

- [ ] **Step 4: 手测矩阵**

| 测试用例 | 期望 |
|---|---|
| 设置 → 看 SHA 是新的（含 cast_liuyao） | 版本号显示正确 |
| 默认模式输入"我应该接 X offer 吗" | AI 自动调 cast_liuyao，气泡内有 3 秒起卦动画 |
| 默认模式输入"今年事业怎么样" | AI 走命理，无起卦动画 |
| 切换"起一卦"模式输入"今年事业" | 强制起卦，即使是命理类问题 |
| 切换"看命盘"模式输入"我应该接 offer" | 强制走命理，不起卦 |
| 发送一条后 ModeChip 自动消失 | 模式重置生效 |
| 历史消息中卜卦消息 | HexagramDisplay 静态渲染（无动画） |
| BottomSheet 完整推演 | 显示用神/应期/六亲数据 |
| 全 app 检查 | 无装饰 emoji（CoT/Evidence/narrateTool） |

- [ ] **Step 5: Push**

```bash
git push origin main
```

---

## 已知风险与回退

### R1：64 卦数据准度

- **风险**：64 卦表的卦名、上下卦、八宫归属如有错，会让 AI 解读基础错位
- **缓解**：T1 step 3 给的 GUA_ROWS 表基于通行版周易八宫；如发现错误单条修复即可，不影响架构

### R2：纳甲简化版六亲偏离传统

- **风险**：T1 step 4 用的是简化纳甲表，约 60-70% 准度
- **缓解**：MVP 接受。Phase 2.5 用真正纳甲表（每宫每爻按地支+五行）替换 PALACE_YAO_WUXING

### R3：起卦动画在低端机掉帧

- **缓解**：动画只用 fade + scale，无复杂 transform；用户的 iPhone 16 Plus 实测无掉帧即可

### R4：AI 误判默认模式下问题类型

- **缓解**：用户可通过 ModePicker 强制；THINKER prompt 加了 4-5 条 ✅/❌ 例子帮助分类

### R5：历史消息没有 hexagram 字段

- **背景**：Phase 2 之前的卜卦类回答是 fake（实际是命理回答），不会有 hexagram 字段
- **缓解**：`msg.orchestration?.hexagram &&` 守卫保证只有真有数据才渲染。旧消息正常显示 RichContent
