# AI 编排架构 + 中式占卜系统集成 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 落地 spec `docs/superpowers/specs/2026-04-25-ai-orchestration-and-divination-systems-design.md` 的 Phase 1：把 chat 重构为 tool-use 编排架构，引入紫微斗数（iztro），实现 6 个工具 + 双角色 prompt + CoT/Evidence/BottomSheet 三个新 UI 组件。

**Architecture:** Multi-turn tool loop（OpenAI-compatible function calling）。Call 1 thinker 调工具做硬推演，Call 2 interpreter 转化为双段输出 `[interpretation] + [evidence]`。客户端预处理拆分两段，分别走 RichContent 渲染和 EvidenceCard 折叠卡。

**Tech Stack:** Expo SDK 54 · React Native 0.81 · TypeScript · iztro@^2.5.8 · expo/fetch · react-native-markdown-display

---

## Block A：数据层（紫微集成）

### Task 1：安装 iztro + 烟雾测试

**Files:**
- Modify: `package.json`

- [ ] **Step 1: 安装 iztro**

```bash
cd /Users/xiaqobenwang/Documents/SUJI
npm install iztro
```

Expected: 安装成功，`package.json` 新增 `"iztro": "^2.5.8"`（或更新版本，按当前 latest）。

- [ ] **Step 2: 写一个 smoke test 验证 iztro 可以 import 并能排盘**

创建 `lib/ziwei/__tests__/iztro-smoke.test.ts`：

```ts
import { astro } from 'iztro';

describe('iztro smoke', () => {
  it('排出一张紫微星盘（已知生辰）', () => {
    // 1990-08-16 14:30 男 北京（以阳历）
    const astrolabe = astro.bySolar('1990-8-16', 2, '男', true, 'zh-CN');

    expect(astrolabe).toBeDefined();
    expect(astrolabe.palaces).toHaveLength(12);
    // 命宫存在
    const mingGong = astrolabe.palaces.find(p => p.name === '命宫');
    expect(mingGong).toBeDefined();
  });
});
```

注：`astro.bySolar(date, hourIndex, gender, fixLeap, lang)`，hourIndex 是 0-11（子=0, 丑=1...），需在后续 ZiweiEngine 中转换。`true` 是 fixLeap = 是否处理闰月。

- [ ] **Step 3: 跑测试**

Run: `npm test -- iztro-smoke`
Expected: 1 PASS。如果 import 报错（commonjs/esm 互操作问题），在 `jest.config.js` 的 `transformIgnorePatterns` 白名单里加 `iztro`。如果 PASS，本步完成。

- [ ] **Step 4: Commit**

```bash
git add package.json package-lock.json lib/ziwei/__tests__/iztro-smoke.test.ts
git commit -m "ziwei: 引入 iztro 库 + 烟雾测试"
```

---

### Task 2：ZiweiEngine 包装层

**Files:**
- Create: `lib/ziwei/types.ts`
- Create: `lib/ziwei/ZiweiEngine.ts`
- Create: `lib/ziwei/__tests__/ZiweiEngine.test.ts`

- [ ] **Step 1: 写失败测试**

```ts
// lib/ziwei/__tests__/ZiweiEngine.test.ts
import { ZiweiEngine } from '../ZiweiEngine';

describe('ZiweiEngine', () => {
  const engine = new ZiweiEngine();

  it('returns 12 palaces for a known birth', () => {
    const pan = engine.compute({
      year: 1990, month: 8, day: 16, hour: 14, minute: 30,
      gender: '男',
      isLunar: false,
    });
    expect(pan.palaces).toHaveLength(12);
  });

  it('identifies the 命宫 with main stars', () => {
    const pan = engine.compute({
      year: 1990, month: 8, day: 16, hour: 14, minute: 30,
      gender: '男',
      isLunar: false,
    });
    const mingGong = pan.palaces.find(p => p.name === '命宫');
    expect(mingGong).toBeDefined();
    expect(mingGong!.mainStars.length).toBeGreaterThanOrEqual(0); // 可能为空但属性存在
  });

  it('returns same pan for same input (deterministic)', () => {
    const input = {
      year: 1990, month: 8, day: 16, hour: 14, minute: 30,
      gender: '男' as const,
      isLunar: false,
    };
    const a = engine.compute(input);
    const b = engine.compute(input);
    expect(a.mingGongPosition).toBe(b.mingGongPosition);
  });
});
```

- [ ] **Step 2: 跑测试**

Run: `npm test -- ZiweiEngine`
Expected: FAIL with "Cannot find module '../ZiweiEngine'"。

- [ ] **Step 3: 实现 types**

创建 `lib/ziwei/types.ts`：

```ts
/**
 * 紫微斗数类型定义（在 iztro 之上的精简层）
 */

export type PalaceName =
  | '命宫' | '兄弟宫' | '夫妻宫' | '子女宫'
  | '财帛宫' | '疾厄宫' | '迁移宫' | '仆役宫'
  | '官禄宫' | '田宅宫' | '福德宫' | '父母宫';

export type StarBrightness = '庙' | '旺' | '得' | '利' | '平' | '闲' | '陷';
export type SiHua = '化禄' | '化权' | '化科' | '化忌';

export interface Star {
  name: string;
  brightness?: StarBrightness;
  type: 'major' | 'soft' | 'tough' | 'lucky' | 'unlucky' | 'flower' | 'helper' | 'other';
  sihua?: SiHua[];
}

export interface Palace {
  name: PalaceName;
  position: string;          // 地支位（子/丑/寅...）
  ganZhi: string;            // 宫位干支
  mainStars: Star[];
  minorStars: Star[];
  isShenGong: boolean;       // 是否为身宫所在
}

export interface ZiweiPan {
  birthDateTime: Date;
  gender: '男' | '女';
  palaces: Palace[];
  mingGongPosition: string;  // 命宫地支位
  shenGongPosition: string;  // 身宫地支位
  fiveElementsClass: string; // 五行局（水二局/木三局/...）
}

export interface ZiweiBirthInput {
  year: number;
  month: number;
  day: number;
  hour: number;       // 0-23
  minute?: number;    // 0-59
  gender: '男' | '女';
  isLunar?: boolean;  // 默认 false 阳历
}
```

- [ ] **Step 4: 实现 ZiweiEngine**

创建 `lib/ziwei/ZiweiEngine.ts`：

```ts
/**
 * 紫微斗数排盘引擎
 *
 * 包装 iztro 库，提供精简、稳定的接口供 AI 工具层使用
 */
import { astro } from 'iztro';
import type {
  ZiweiPan, ZiweiBirthInput, Palace, Star, PalaceName,
} from './types';

export class ZiweiEngine {
  /**
   * 排出一张紫微命盘
   */
  compute(input: ZiweiBirthInput): ZiweiPan {
    const dateStr = `${input.year}-${input.month}-${input.day}`;
    // iztro 的 hour 参数是 0-11 (子时=0)，从 24 小时换算
    const hourIndex = this.hourToIndex(input.hour);

    const astrolabe = input.isLunar
      ? astro.byLunar(dateStr, hourIndex, input.gender, false, true, 'zh-CN')
      : astro.bySolar(dateStr, hourIndex, input.gender, true, 'zh-CN');

    const palaces: Palace[] = astrolabe.palaces.map((p: any) => ({
      name: p.name as PalaceName,
      position: p.earthlyBranch,
      ganZhi: `${p.heavenlyStem}${p.earthlyBranch}`,
      mainStars: p.majorStars.map((s: any) => this.normalizeStar(s, 'major')),
      minorStars: [
        ...p.minorStars.map((s: any) => this.normalizeStar(s, 'other')),
        ...p.adjectiveStars.map((s: any) => this.normalizeStar(s, 'helper')),
      ],
      isShenGong: p.isBodyPalace ?? false,
    }));

    return {
      birthDateTime: new Date(input.year, input.month - 1, input.day, input.hour, input.minute ?? 0),
      gender: input.gender,
      palaces,
      mingGongPosition: this.findMingGongPosition(palaces),
      shenGongPosition: palaces.find(p => p.isShenGong)?.position ?? '',
      fiveElementsClass: astrolabe.fiveElementsClass ?? '',
    };
  }

  /** 24 小时制转 iztro 的 0-11 时辰索引 */
  private hourToIndex(hour: number): number {
    // 子时跨日：23-00:59 = 0
    if (hour === 23 || hour === 0) return 0;
    return Math.floor((hour + 1) / 2);
  }

  private normalizeStar(s: any, defaultType: Star['type']): Star {
    return {
      name: s.name,
      brightness: s.brightness as Star['brightness'],
      type: defaultType,
      sihua: s.mutagen ? [s.mutagen as Star['sihua'][number]] : undefined,
    };
  }

  private findMingGongPosition(palaces: Palace[]): string {
    return palaces.find(p => p.name === '命宫')?.position ?? '';
  }
}
```

注：`iztro` 的 API 中 minute 不影响排盘（紫微以时辰为最小单位），所以 minute 仅用于 `birthDateTime` 字段保留。`hourToIndex` 和我们之前在 shichen 里的 `currentShichenIndex` 算法一致（已抽出过类似逻辑，但因 shichen 模块已删，这里独立实现一份足够小不重复）。

- [ ] **Step 5: 跑测试**

Run: `npm test -- ZiweiEngine`
Expected: 3 PASS。

如果 iztro 的字段名实际与代码不符（比如 `majorStars` 实际叫 `majorStar`），调整 `compute` 内部的字段访问。

- [ ] **Step 6: TypeScript check**

Run: `npx tsc --noEmit`
Expected: 无新 TS 错误。如果 iztro 没有自带类型，则在 `tsconfig.json` 没问题的前提下用 `(astrolabe as any)` 的访问规避（已在代码中用 `: any`）。

- [ ] **Step 7: Commit**

```bash
git add lib/ziwei/
git commit -m "ziwei: ZiweiEngine 包装层 + 类型定义"
```

---

### Task 3：userStore 加 ziweiPanCache + Profile 联动

**Files:**
- Modify: `lib/store/userStore.ts`
- Modify: `app/(tabs)/profile.tsx`

- [ ] **Step 1: userStore 加字段**

修改 `lib/store/userStore.ts`：

1. 在 `interface UserState` 加：

```ts
ziweiPanCache: string | null;     // JSON.stringify(ZiweiPan)
```

2. 在 actions 加：

```ts
setZiweiPanCache: (json: string) => void;
```

3. 在 store 初始 state 加：

```ts
ziweiPanCache: null,
```

4. 在 actions 实现加：

```ts
setZiweiPanCache: (json: string) =>
  set({ ziweiPanCache: json }),
```

具体位置参考已存在的 `mingPanCache` / `setMingPanCache` 同位置，照葫芦画瓢。

- [ ] **Step 2: profile.tsx 联动生成紫微盘**

读 `app/(tabs)/profile.tsx`，找到 `baziEngine.compute(...)` 后调用 `setMingPanCache(JSON.stringify(...))` 的地方。在它后面加紫微生成。

加 import：
```ts
import { ZiweiEngine } from '@/lib/ziwei/ZiweiEngine';
```

加生成（在 useUserStore 调用后）：
```ts
const ziweiEngine = useMemo(() => new ZiweiEngine(), []);
```

在生成八字命盘成功的同一段逻辑里（找到调用 `setMingPanCache` 那一行），后面紧接着加：

```ts
const ziweiPan = ziweiEngine.compute({
  year: birthDate.getFullYear(),
  month: birthDate.getMonth() + 1,
  day: birthDate.getDate(),
  hour: birthDate.getHours(),
  minute: birthDate.getMinutes(),
  gender: gender as '男' | '女',
  isLunar: false,
});
useUserStore.getState().setZiweiPanCache(JSON.stringify(ziweiPan));
```

(`gender` 与 `birthDate` 已存在 profile 组件作用域内，按当前文件 actuals 引用即可。如果 setter 没法这么调用，改用 destructure 出 `setZiweiPanCache` 的 hook 调用。)

- [ ] **Step 3: TypeScript check**

Run: `npx tsc --noEmit`
Expected: 无新错误。

- [ ] **Step 4: 跑全部测试**

Run: `npm test`
Expected: 全部 PASS（应是 21 + 3 + 1 = 25 个）。

- [ ] **Step 5: Commit**

```bash
git add lib/store/userStore.ts "app/(tabs)/profile.tsx"
git commit -m "ziwei: profile 流程同步生成紫微盘并缓存到 userStore"
```

---

## Block B：工具框架

### Task 4：工具协议类型

**Files:**
- Create: `lib/ai/tools/types.ts`

- [ ] **Step 1: 创建类型定义**

```ts
/**
 * AI tool-use 协议类型（OpenAI-compatible function calling）
 */

/** 工具定义（发给 LLM 的 schema） */
export interface ToolDefinition {
  type: 'function';
  function: {
    name: string;
    description: string;
    parameters: {
      type: 'object';
      properties: Record<string, ParameterSchema>;
      required?: string[];
    };
  };
}

export interface ParameterSchema {
  type: 'string' | 'number' | 'boolean' | 'array' | 'object';
  description?: string;
  enum?: string[];
  items?: ParameterSchema;
}

/** LLM 返回的工具调用请求 */
export interface ToolCall {
  id: string;
  name: string;
  arguments: Record<string, unknown>;
}

/** 工具执行结果（送回 LLM） */
export interface ToolResult {
  tool_call_id: string;
  content: string;     // JSON.stringify 的执行结果（< 200 tokens 预算）
}

/** 工具执行函数签名 */
export type ToolHandler = (
  args: Record<string, unknown>,
  context: ToolContext,
) => Promise<unknown> | unknown;

/** 工具执行上下文（命盘等） */
export interface ToolContext {
  mingPan: any;        // BaziEngine 输出（来自 mingPanCache）
  ziweiPan: any;       // ZiweiEngine 输出（来自 ziweiPanCache）
  now: Date;
}
```

- [ ] **Step 2: TypeScript check**

Run: `npx tsc --noEmit`
Expected: 无新错误。

- [ ] **Step 3: Commit**

```bash
git add lib/ai/tools/types.ts
git commit -m "ai/tools: 协议类型定义"
```

---

### Task 5：八字侧工具实现（4 个工具）

**Files:**
- Create: `lib/ai/tools/bazi.ts`
- Create: `lib/ai/tools/__tests__/bazi.test.ts`

实现：`get_bazi_star`、`list_shensha`、`get_timing`、`get_today_context`。

- [ ] **Step 1: 写失败测试**

```ts
// lib/ai/tools/__tests__/bazi.test.ts
import { baziTools, baziHandlers } from '../bazi';

const FIXTURE_MING_PAN = {
  // 简化的 fixture，含 BaziEngine 输出的最小子集
  riZhu: { gan: '庚', wuXing: '金', yinYang: '阳', description: '...' },
  siZhu: {
    year: { ganZhi: { gan: '庚', zhi: '午' }, shiShen: '比肩' },
    month: { ganZhi: { gan: '甲', zhi: '申' }, shiShen: '偏财' },
    day: { ganZhi: { gan: '庚', zhi: '辰' }, shiShen: '日主' },
    hour: { ganZhi: { gan: '丙', zhi: '子' }, shiShen: '七杀' },
  },
  wuXingStrength: { yongShen: '水', xiShen: '木', jiShen: '土' },
  geJu: { name: '伤官生财', category: '正格', strength: '中', description: '', modernMeaning: '' },
  daYunList: [
    { startAge: 3, endAge: 12, ganZhi: { gan: '癸', zhi: '未' }, shiShen: '伤官', period: '3-12岁' },
    { startAge: 13, endAge: 22, ganZhi: { gan: '壬', zhi: '午' }, shiShen: '食神', period: '13-22岁' },
  ],
  shenSha: [
    { name: '红鸾', type: '吉', position: '日支辰', description: '', modernMeaning: '' },
    { name: '驿马', type: '中性', position: '年支午', description: '', modernMeaning: '' },
  ],
  branchRelations: [
    { type: '六合', branches: ['辰', '酉'], positions: ['日支-月支'] },
  ],
};

const CTX = { mingPan: FIXTURE_MING_PAN, ziweiPan: null, now: new Date(2026, 3, 25) };

describe('baziTools', () => {
  it('exports 4 tools', () => {
    expect(baziTools.length).toBe(4);
    expect(baziTools.map(t => t.function.name).sort()).toEqual(
      ['get_bazi_star', 'get_timing', 'get_today_context', 'list_shensha']
    );
  });
});

describe('get_bazi_star handler', () => {
  it('returns 子女 (food star) info', async () => {
    const r = await baziHandlers.get_bazi_star({ person: '子女' }, CTX) as any;
    expect(r.person).toBe('子女');
    expect(typeof r.summary).toBe('string');
  });
});

describe('list_shensha handler', () => {
  it('returns all shensha when no kind', async () => {
    const r = await baziHandlers.list_shensha({}, CTX) as any;
    expect(r.list.length).toBe(2);
  });

  it('filters by kind=吉', async () => {
    const r = await baziHandlers.list_shensha({ kind: '吉' }, CTX) as any;
    expect(r.list.every((s: any) => s.type === '吉')).toBe(true);
  });
});

describe('get_timing handler', () => {
  it('returns current_dayun', async () => {
    const r = await baziHandlers.get_timing({ scope: 'current_dayun' }, CTX) as any;
    expect(r.scope).toBe('current_dayun');
    expect(r.data).toBeDefined();
  });

  it('returns all_dayun list', async () => {
    const r = await baziHandlers.get_timing({ scope: 'all_dayun' }, CTX) as any;
    expect(r.scope).toBe('all_dayun');
    expect(r.data.length).toBe(2);
  });
});

describe('get_today_context handler', () => {
  it('returns today ganzhi', async () => {
    const r = await baziHandlers.get_today_context({}, CTX) as any;
    expect(r.todayGanZhi).toBeDefined();
    expect(typeof r.todayGanZhi).toBe('string');
  });
});
```

- [ ] **Step 2: 跑测试**

Run: `npm test -- bazi`
Expected: FAIL with "Cannot find module '../bazi'"。

- [ ] **Step 3: 实现 bazi 工具**

创建 `lib/ai/tools/bazi.ts`：

```ts
/**
 * 八字侧工具实现
 *
 * 4 个工具：get_bazi_star, list_shensha, get_timing, get_today_context
 */
import type { ToolDefinition, ToolHandler } from './types';

export const baziTools: ToolDefinition[] = [
  {
    type: 'function',
    function: {
      name: 'get_bazi_star',
      description: '获取某六亲星位的状态。用于"婚姻/子女/父母"等关系类问题。',
      parameters: {
        type: 'object',
        properties: {
          person: {
            type: 'string',
            description: '六亲对象',
            enum: ['配偶', '子女', '父母', '兄弟'],
          },
        },
        required: ['person'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'list_shensha',
      description: '查命盘中的神煞。可按吉/凶/中性筛选，或按名称类别（桃花/权贵/文昌/驿马）筛选。',
      parameters: {
        type: 'object',
        properties: {
          kind: {
            type: 'string',
            description: '筛选类别',
            enum: ['吉', '凶', '中性', '桃花', '权贵', '文昌', '驿马', 'all'],
          },
        },
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_timing',
      description: '获取大运/流年/流月信息，用于"何时"类问题。',
      parameters: {
        type: 'object',
        properties: {
          scope: {
            type: 'string',
            enum: ['current_dayun', 'all_dayun', 'liunian', 'liuyue'],
          },
          yearRange: {
            type: 'array',
            description: '当 scope=liunian 时使用的年份区间 [开始年, 结束年]',
            items: { type: 'number' },
          },
          year: {
            type: 'number',
            description: '当 scope=liuyue 时使用的目标年份',
          },
        },
        required: ['scope'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_today_context',
      description: '获取今日干支和与命盘的交互（神煞当令、流月引动），用于"今日运势"类问题。',
      parameters: { type: 'object', properties: {} },
    },
  },
];

const PERSON_TO_SHISHEN: Record<string, string[]> = {
  配偶: ['正官', '七杀', '正财', '偏财'],
  子女: ['食神', '伤官'],
  父母: ['正印', '偏印'],
  兄弟: ['比肩', '劫财'],
};

export const baziHandlers: Record<string, ToolHandler> = {
  get_bazi_star: ({ person }, { mingPan }) => {
    const targetShiShen = PERSON_TO_SHISHEN[person as string];
    if (!targetShiShen) return { person, error: 'unknown person' };

    // 在四柱中找到所有命中的十神位
    const positions: string[] = [];
    if (mingPan?.siZhu) {
      for (const [pillar, val] of Object.entries(mingPan.siZhu) as [string, any][]) {
        if (val?.shiShen && targetShiShen.includes(val.shiShen)) {
          positions.push(`${pillar}柱 ${val.ganZhi?.gan ?? ''}${val.ganZhi?.zhi ?? ''}（${val.shiShen}）`);
        }
      }
    }

    return {
      person,
      relevantShiShen: targetShiShen,
      positionsInChart: positions,
      summary: positions.length > 0
        ? `${person}星出现在 ${positions.join('、')}`
        : `${person}星不显（暗藏地支或不见）`,
    };
  },

  list_shensha: ({ kind }, { mingPan }) => {
    const all = (mingPan?.shenSha ?? []) as Array<any>;
    const k = (kind ?? 'all') as string;
    const list = k === 'all'
      ? all
      : all.filter(s => s.type === k || s.name?.includes(k));
    return {
      kind: k,
      list: list.map(s => ({ name: s.name, type: s.type, position: s.position })),
    };
  },

  get_timing: ({ scope, yearRange, year }, { mingPan, now }) => {
    const dayunList = (mingPan?.daYunList ?? []) as Array<any>;
    const currentAge = now.getFullYear() - new Date(mingPan?.birthDateTime ?? Date.now()).getFullYear();

    if (scope === 'current_dayun') {
      const cur = dayunList.find(d => currentAge >= d.startAge && currentAge <= d.endAge);
      return { scope, data: cur ?? null };
    }

    if (scope === 'all_dayun') {
      return {
        scope,
        data: dayunList.map(d => ({
          period: d.period,
          ganZhi: `${d.ganZhi?.gan}${d.ganZhi?.zhi}`,
          shiShen: d.shiShen,
        })),
      };
    }

    if (scope === 'liunian') {
      const [start, end] = (yearRange as number[] | undefined) ?? [now.getFullYear(), now.getFullYear() + 5];
      // 流年是简单的干支轮转：1984甲子，每年 +1 干支
      const data = [];
      for (let y = start; y <= end; y++) {
        data.push({ year: y, ganZhi: yearToGanZhi(y) });
      }
      return { scope, data };
    }

    if (scope === 'liuyue') {
      const y = (year as number | undefined) ?? now.getFullYear();
      const data = [];
      for (let m = 1; m <= 12; m++) {
        data.push({ month: m, ganZhi: monthToGanZhi(y, m) });
      }
      return { scope, year: y, data };
    }

    return { scope, error: 'unknown scope' };
  },

  get_today_context: (_args, { mingPan, now }) => {
    const todayGZ = dateToGanZhi(now);
    return {
      date: now.toISOString().slice(0, 10),
      todayGanZhi: todayGZ,
      // 与日主关系（简要）
      dayInteraction: mingPan?.riZhu?.gan
        ? describeInteraction(mingPan.riZhu.gan, todayGZ)
        : null,
    };
  },
};

// ────────────────────────────────────────────────────────
// 简化的天干地支推算（fallback 公式）
// 真实生产应该用 lunisolar 库；这里足够给 AI 上下文用
// ────────────────────────────────────────────────────────

const TIANGAN = ['甲','乙','丙','丁','戊','己','庚','辛','壬','癸'];
const DIZHI = ['子','丑','寅','卯','辰','巳','午','未','申','酉','戌','亥'];

function yearToGanZhi(year: number): string {
  // 1984 是甲子年
  const offset = (year - 1984) % 60;
  const adj = offset < 0 ? offset + 60 : offset;
  return TIANGAN[adj % 10] + DIZHI[adj % 12];
}

function monthToGanZhi(year: number, month: number): string {
  // 简化：以年干推月干起例（甲己之年丙作首）
  const yearGan = TIANGAN.indexOf(yearToGanZhi(year)[0]);
  const monthGanStart = (yearGan % 5) * 2 + 2; // 甲己=丙(2), 乙庚=戊(4), 丙辛=庚(6), 丁壬=壬(8), 戊癸=甲(0)
  const gan = TIANGAN[(monthGanStart + month - 1) % 10];
  const zhi = DIZHI[(month + 1) % 12]; // 正月寅
  return gan + zhi;
}

function dateToGanZhi(d: Date): string {
  // 1900-01-01 是甲戌日（约定，便于计算）
  const epoch = new Date(1900, 0, 1).getTime();
  const days = Math.floor((d.getTime() - epoch) / 86400000);
  // 1900-01-01 == 甲戌（offset = 10）
  const offset = (10 + days) % 60;
  const adj = offset < 0 ? offset + 60 : offset;
  return TIANGAN[adj % 10] + DIZHI[adj % 12];
}

function describeInteraction(riZhuGan: string, todayGZ: string): string {
  const todayGan = todayGZ[0];
  if (todayGan === riZhuGan) return '今日同我，比肩之日';
  return `今日 ${todayGan}，与日主 ${riZhuGan} 有微妙交互`;
}
```

- [ ] **Step 4: 跑测试**

Run: `npm test -- bazi`
Expected: 8 PASS（4 个 describe，每个 1-2 个 it）。

- [ ] **Step 5: TypeScript check**

Run: `npx tsc --noEmit`
Expected: 无新错误。

- [ ] **Step 6: Commit**

```bash
git add lib/ai/tools/bazi.ts lib/ai/tools/__tests__/bazi.test.ts
git commit -m "ai/tools: 八字侧 4 个工具（star/shensha/timing/today_context）"
```

---

### Task 6：紫微侧工具实现（get_ziwei_palace）

**Files:**
- Create: `lib/ai/tools/ziwei.ts`
- Create: `lib/ai/tools/__tests__/ziwei.test.ts`

- [ ] **Step 1: 写失败测试**

```ts
// lib/ai/tools/__tests__/ziwei.test.ts
import { ziweiTools, ziweiHandlers } from '../ziwei';

const FIXTURE_ZIWEI_PAN = {
  palaces: [
    {
      name: '命宫', position: '寅', ganZhi: '甲寅',
      mainStars: [{ name: '紫微', brightness: '庙', type: 'major' }],
      minorStars: [], isShenGong: false,
    },
    {
      name: '夫妻宫', position: '子', ganZhi: '甲子',
      mainStars: [{ name: '武曲', brightness: '旺', type: 'major', sihua: ['化忌'] }],
      minorStars: [], isShenGong: false,
    },
    {
      name: '子女宫', position: '亥', ganZhi: '癸亥',
      mainStars: [
        { name: '紫微', brightness: '庙', type: 'major' },
        { name: '天府', brightness: '旺', type: 'major' },
      ],
      minorStars: [], isShenGong: false,
    },
  ],
};

const CTX = { mingPan: null, ziweiPan: FIXTURE_ZIWEI_PAN, now: new Date() };

describe('ziweiTools', () => {
  it('exports 1 tool', () => {
    expect(ziweiTools).toHaveLength(1);
    expect(ziweiTools[0].function.name).toBe('get_ziwei_palace');
  });
});

describe('get_ziwei_palace handler', () => {
  it('returns 命宫 palace data', async () => {
    const r = await ziweiHandlers.get_ziwei_palace({ palace: '命宫' }, CTX) as any;
    expect(r.palace).toBe('命宫');
    expect(r.mainStars).toContain('紫微');
  });

  it('returns 夫妻宫 with sihua when withFlying=true', async () => {
    const r = await ziweiHandlers.get_ziwei_palace(
      { palace: '夫妻宫', withFlying: true }, CTX
    ) as any;
    expect(r.sihua).toBeDefined();
    expect(r.sihua).toContain('武曲化忌');
  });

  it('returns "not found" for unknown palace', async () => {
    const r = await ziweiHandlers.get_ziwei_palace({ palace: '财帛宫' }, CTX) as any;
    expect(r.error).toBeDefined();
  });

  it('returns no_chart message when ziweiPan is null', async () => {
    const r = await ziweiHandlers.get_ziwei_palace(
      { palace: '命宫' },
      { mingPan: null, ziweiPan: null, now: new Date() },
    ) as any;
    expect(r.error).toBeDefined();
  });
});
```

- [ ] **Step 2: 跑测试**

Run: `npm test -- ziwei`
Expected: FAIL with "Cannot find module '../ziwei'"。

- [ ] **Step 3: 实现 ziwei 工具**

创建 `lib/ai/tools/ziwei.ts`：

```ts
/**
 * 紫微侧工具实现
 */
import type { ToolDefinition, ToolHandler } from './types';

export const ziweiTools: ToolDefinition[] = [
  {
    type: 'function',
    function: {
      name: 'get_ziwei_palace',
      description: '查紫微 12 宫某宫的主星、辅星、四化。常用宫名：命宫、夫妻宫、子女宫、财帛宫、官禄宫、田宅宫、福德宫、迁移宫、疾厄宫、父母宫、兄弟宫、仆役宫。',
      parameters: {
        type: 'object',
        properties: {
          palace: {
            type: 'string',
            description: '宫位名称',
            enum: [
              '命宫','兄弟宫','夫妻宫','子女宫',
              '财帛宫','疾厄宫','迁移宫','仆役宫',
              '官禄宫','田宅宫','福德宫','父母宫',
            ],
          },
          withFlying: {
            type: 'boolean',
            description: '是否返回四化飞入飞出信息',
          },
        },
        required: ['palace'],
      },
    },
  },
];

export const ziweiHandlers: Record<string, ToolHandler> = {
  get_ziwei_palace: ({ palace, withFlying }, { ziweiPan }) => {
    if (!ziweiPan) {
      return { palace, error: 'no_ziwei_chart' };
    }
    const target = (ziweiPan.palaces ?? []).find((p: any) => p.name === palace);
    if (!target) {
      return { palace, error: 'palace_not_found' };
    }

    const mainStars: string[] = (target.mainStars ?? []).map((s: any) =>
      `${s.name}${s.brightness ? `(${s.brightness})` : ''}`
    );
    const minorStars: string[] = (target.minorStars ?? []).map((s: any) => s.name);

    const result: any = {
      palace,
      position: target.position,
      ganZhi: target.ganZhi,
      mainStars,
      minorStars,
      isShenGong: target.isShenGong,
    };

    if (withFlying) {
      const sihua: string[] = [];
      for (const s of [...(target.mainStars ?? []), ...(target.minorStars ?? [])]) {
        if (s.sihua && s.sihua.length > 0) {
          for (const h of s.sihua) sihua.push(`${s.name}${h}`);
        }
      }
      result.sihua = sihua;
    }

    return result;
  },
};
```

- [ ] **Step 4: 跑测试**

Run: `npm test -- ziwei`
Expected: 5 PASS。

- [ ] **Step 5: Commit**

```bash
git add lib/ai/tools/ziwei.ts lib/ai/tools/__tests__/ziwei.test.ts
git commit -m "ai/tools: 紫微 get_ziwei_palace 工具"
```

---

### Task 7：聚合工具 get_domain + 工具汇总

**Files:**
- Create: `lib/ai/tools/index.ts`
- Create: `lib/ai/tools/__tests__/index.test.ts`

- [ ] **Step 1: 写失败测试**

```ts
// lib/ai/tools/__tests__/index.test.ts
import { ALL_TOOLS, ALL_HANDLERS, TOOL_STRATEGY } from '../index';

const FIX_MP = {
  riZhu: { gan: '庚', wuXing: '金', yinYang: '阳', description: '' },
  siZhu: {
    year: { ganZhi: { gan: '庚', zhi: '午' }, shiShen: '比肩' },
    month: { ganZhi: { gan: '甲', zhi: '申' }, shiShen: '偏财' },
    day: { ganZhi: { gan: '庚', zhi: '辰' }, shiShen: '日主' },
    hour: { ganZhi: { gan: '丙', zhi: '子' }, shiShen: '七杀' },
  },
  wuXingStrength: { yongShen: '水', xiShen: '木', jiShen: '土' },
  geJu: { name: '伤官生财', category: '正格', strength: '中' },
  daYunList: [],
  shenSha: [{ name: '红鸾', type: '吉', position: '日支' }],
};

const FIX_ZW = {
  palaces: [
    { name: '子女宫', position: '亥', ganZhi: '癸亥',
      mainStars: [{ name: '紫微', brightness: '庙' }], minorStars: [], isShenGong: false },
    { name: '夫妻宫', position: '子', ganZhi: '甲子',
      mainStars: [{ name: '武曲', sihua: ['化忌'] }], minorStars: [], isShenGong: false },
  ],
};

const CTX = { mingPan: FIX_MP, ziweiPan: FIX_ZW, now: new Date(2026, 3, 25) };

describe('ALL_TOOLS', () => {
  it('exposes 6 tools total', () => {
    expect(ALL_TOOLS).toHaveLength(6);
    const names = ALL_TOOLS.map(t => t.function.name).sort();
    expect(names).toEqual([
      'get_bazi_star', 'get_domain', 'get_timing',
      'get_today_context', 'get_ziwei_palace', 'list_shensha',
    ]);
  });
});

describe('TOOL_STRATEGY', () => {
  it('is a non-empty string', () => {
    expect(typeof TOOL_STRATEGY).toBe('string');
    expect(TOOL_STRATEGY.length).toBeGreaterThan(50);
  });
});

describe('get_domain handler', () => {
  it('returns 子女 domain bundle', async () => {
    const r = await ALL_HANDLERS.get_domain({ domain: '子女' }, CTX) as any;
    expect(r.domain).toBe('子女');
    expect(r.bazi).toBeDefined();
    expect(r.ziwei).toBeDefined();
    expect(r.shensha).toBeDefined();
  });

  it('returns 婚姻 domain with 夫妻宫 sihua', async () => {
    const r = await ALL_HANDLERS.get_domain({ domain: '婚姻' }, CTX) as any;
    expect(r.ziwei.palace).toBe('夫妻宫');
    expect(r.ziwei.sihua).toContain('武曲化忌');
  });

  it('returns error for unknown domain', async () => {
    const r = await ALL_HANDLERS.get_domain({ domain: '不存在' }, CTX) as any;
    expect(r.error).toBeDefined();
  });
});
```

- [ ] **Step 2: 跑测试**

Run: `npm test -- tools/__tests__/index`
Expected: FAIL with "Cannot find module '../index'"。

- [ ] **Step 3: 实现 index.ts**

```ts
/**
 * 工具汇总：聚合 get_domain（实现细节用其他 handlers），导出全集
 */
import type { ToolDefinition, ToolHandler } from './types';
import { baziTools, baziHandlers } from './bazi';
import { ziweiTools, ziweiHandlers } from './ziwei';

const DOMAIN_TO_PALACE: Record<string, string> = {
  子女: '子女宫',
  婚姻: '夫妻宫',
  事业: '官禄宫',
  财富: '财帛宫',
  健康: '疾厄宫',
  父母: '父母宫',
  兄弟: '兄弟宫',
  迁移: '迁移宫',
  田宅: '田宅宫',
  福德: '福德宫',
};

const DOMAIN_TO_PERSON: Record<string, string | null> = {
  子女: '子女',
  婚姻: '配偶',
  父母: '父母',
  兄弟: '兄弟',
  事业: null,
  财富: null,
  健康: null,
  迁移: null,
  田宅: null,
  福德: null,
};

const DOMAIN_TO_SHENSHA_KIND: Record<string, string> = {
  婚姻: '桃花',
  事业: '权贵',
  健康: '凶',
};

const aggregatedTools: ToolDefinition[] = [
  {
    type: 'function',
    function: {
      name: 'get_domain',
      description: '一次获取某领域的命盘相关数据：八字星位 + 紫微对应宫位 + 相关神煞。最常用工具。',
      parameters: {
        type: 'object',
        properties: {
          domain: {
            type: 'string',
            enum: ['子女', '婚姻', '事业', '财富', '健康', '父母', '兄弟', '迁移', '田宅', '福德'],
          },
        },
        required: ['domain'],
      },
    },
  },
];

const aggregatedHandlers: Record<string, ToolHandler> = {
  get_domain: async ({ domain }, ctx) => {
    const palace = DOMAIN_TO_PALACE[domain as string];
    if (!palace) return { domain, error: 'unknown_domain' };

    const person = DOMAIN_TO_PERSON[domain as string];
    const shenshaKind = DOMAIN_TO_SHENSHA_KIND[domain as string] ?? 'all';

    const baziPart = person
      ? await baziHandlers.get_bazi_star({ person }, ctx)
      : { domain, note: '此领域不直接对应六亲星位' };
    const ziweiPart = await ziweiHandlers.get_ziwei_palace(
      { palace, withFlying: true }, ctx,
    );
    const shenshaPart = await baziHandlers.list_shensha(
      { kind: shenshaKind }, ctx,
    );

    return {
      domain,
      bazi: baziPart,
      ziwei: ziweiPart,
      shensha: shenshaPart,
    };
  },
};

export const ALL_TOOLS: ToolDefinition[] = [
  ...aggregatedTools,
  ...baziTools,
  ...ziweiTools,
];

export const ALL_HANDLERS: Record<string, ToolHandler> = {
  ...aggregatedHandlers,
  ...baziHandlers,
  ...ziweiHandlers,
};

/** 工具使用策略文本，注入 thinker prompt */
export const TOOL_STRATEGY = `工具使用策略：
1. 用户问题涉及具体领域（婚姻/子女/事业/财富/健康/父母/兄弟/迁移/田宅/福德）→ 优先用 get_domain
2. 用户问题涉及"何时" → 加 get_timing
3. 跨领域复杂问题 → 用 get_bazi_star / get_ziwei_palace 精查
4. "今日运势"类问题 → get_today_context
5. 一次推演中工具调用 ≤ 4 次（避免无意义遍历）`;
```

- [ ] **Step 4: 跑测试**

Run: `npm test -- tools/__tests__/index`
Expected: 5 PASS。

跑全部测试确认没破坏：

Run: `npm test`
Expected: 全部 PASS。

- [ ] **Step 5: Commit**

```bash
git add lib/ai/tools/index.ts lib/ai/tools/__tests__/index.test.ts
git commit -m "ai/tools: get_domain 聚合工具 + 工具汇总 + 策略文本"
```

---

## Block C：AI 编排

### Task 8：双角色 Prompt 重写

**Files:**
- Modify: `lib/ai/index.ts`

- [ ] **Step 1: 替换 SYSTEM_PROMPT 为双角色**

读取 `lib/ai/index.ts` 当前内容（约 32 行），整体替换为：

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

# 输出格式
直接输出推演过程，编号列出步骤：
1. ...
2. ...
3. ...
最后一段给"综合判断"：1-2 句话给结论。`;

/** 解读师角色 prompt（Call 2，无工具，纯文本） */
export const INTERPRETER_PROMPT = `你是岁吉的解读师。
你看不到原始命盘数据，只看推演引擎的输出。
你的任务：把硬推演转化成有文化底蕴 + 现代视角的解读，让用户读懂。

# 输出格式（严格遵守）

[interpretation]
（解读正文，3-5 段，每段 30-80 字。
 用"传统八字 / 紫微" + "现代视角"双重框架。
 可以引用古籍意象，但不要堆砌。
 给具体结论但留批判距离："被视为..."、"传统看..."。）

[evidence]
（4-6 行，每行 ≤ 12 字。
 直接来自推演引擎的关键数据点。
 格式：xxx · yyy）

# 风格
- 不用"你应该"、"必须"等命令式
- 不下"100% 会发生"的绝对断言
- 用"窗口期"、"倾向"、"被视为"等带余地的表达
- 长度控制：interpretation 不超 250 字`;

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
}
```

- [ ] **Step 2: 验证 chat.ts 仍编译**

`chat.ts` 当前 `import` 了 `SYSTEM_PROMPT`，仍存在（兜底用），所以应不破坏。

Run: `npx tsc --noEmit`
Expected: 无新错误。

- [ ] **Step 3: 跑全部测试**

Run: `npm test`
Expected: 全部 PASS。

- [ ] **Step 4: Commit**

```bash
git add lib/ai/index.ts
git commit -m "ai: 双角色 prompt — THINKER（推演）+ INTERPRETER（解读）"
```

---

### Task 9：Orchestrator — 单轮 LLM 调用 helper

**Files:**
- Create: `lib/ai/tools/orchestrator.ts`
- Create: `lib/ai/tools/__tests__/orchestrator.test.ts`

这一步只实现 **callLLMWithTools**（单轮，OpenAI-compatible），下一步 Task 10 用它构建 multi-turn 循环。

- [ ] **Step 1: 写失败测试（用 mock fetch）**

```ts
// lib/ai/tools/__tests__/orchestrator.test.ts
import { callLLMWithTools, callLLMStreaming } from '../orchestrator';
import type { ToolDefinition } from '../types';

// mock global fetch
const originalFetch = global.fetch;

afterEach(() => {
  global.fetch = originalFetch;
});

const FAKE_TOOLS: ToolDefinition[] = [
  {
    type: 'function',
    function: { name: 'echo', description: 'echo', parameters: { type: 'object', properties: {} } },
  },
];

describe('callLLMWithTools', () => {
  it('returns text when LLM responds with content', async () => {
    global.fetch = jest.fn(async () => ({
      ok: true,
      json: async () => ({
        choices: [{ message: { role: 'assistant', content: 'hello world' } }],
      }),
    })) as any;

    const r = await callLLMWithTools(
      [{ role: 'user', content: 'hi' }],
      { provider: 'openai', apiKey: 'k', model: 'gpt-4o', baseUrl: 'https://x' },
      FAKE_TOOLS,
    );
    expect(r.kind).toBe('text');
    if (r.kind === 'text') expect(r.text).toBe('hello world');
  });

  it('returns toolCalls when LLM responds with function calls', async () => {
    global.fetch = jest.fn(async () => ({
      ok: true,
      json: async () => ({
        choices: [{
          message: {
            role: 'assistant',
            content: null,
            tool_calls: [{
              id: 'call_1',
              type: 'function',
              function: { name: 'echo', arguments: '{"x":1}' },
            }],
          },
        }],
      }),
    })) as any;

    const r = await callLLMWithTools(
      [{ role: 'user', content: 'hi' }],
      { provider: 'openai', apiKey: 'k', model: 'gpt-4o', baseUrl: 'https://x' },
      FAKE_TOOLS,
    );
    expect(r.kind).toBe('tools');
    if (r.kind === 'tools') {
      expect(r.calls).toHaveLength(1);
      expect(r.calls[0].name).toBe('echo');
      expect(r.calls[0].arguments).toEqual({ x: 1 });
    }
  });
});
```

- [ ] **Step 2: 跑测试**

Run: `npm test -- orchestrator`
Expected: FAIL with "Cannot find module '../orchestrator'"。

- [ ] **Step 3: 实现 orchestrator helpers**

创建 `lib/ai/tools/orchestrator.ts`：

```ts
/**
 * AI 编排核心：单轮 LLM 调用 + 流式调用 helpers
 *
 * 当前只实现 OpenAI-compatible 协议（覆盖 OpenAI / DeepSeek / 多数自定义）。
 * Anthropic / Responses API 的 tool-use 适配后续 task 处理（如果需要）。
 */
import { fetch as expoFetch } from 'expo/fetch';
import type { ToolDefinition, ToolCall } from './types';

export interface ChatProviderConfig {
  provider: 'openai' | 'deepseek' | 'anthropic' | 'custom';
  apiKey: string;
  model: string;
  baseUrl: string;
}

export interface LLMMessage {
  role: 'system' | 'user' | 'assistant' | 'tool';
  content: string | null;
  tool_call_id?: string;
  tool_calls?: Array<{
    id: string;
    type: 'function';
    function: { name: string; arguments: string };
  }>;
}

export type LLMResult =
  | { kind: 'text'; text: string }
  | { kind: 'tools'; calls: ToolCall[] };

function buildAuthHeaders(config: ChatProviderConfig): Record<string, string> {
  const isAzure = /\.azure\.com\//i.test(config.baseUrl || '');
  return isAzure
    ? { 'api-key': config.apiKey }
    : { Authorization: `Bearer ${config.apiKey}` };
}

/**
 * 单轮非流式调用：LLM 要么返回纯文本，要么返回 tool_calls
 *
 * 用于 thinker 阶段（multi-turn loop 的每一回合）
 */
export async function callLLMWithTools(
  messages: LLMMessage[],
  config: ChatProviderConfig,
  tools: ToolDefinition[],
  signal?: AbortSignal,
): Promise<LLMResult> {
  const url = `${config.baseUrl.replace(/\/$/, '')}/chat/completions`;
  const body = {
    model: config.model,
    messages,
    tools,
    tool_choice: 'auto',
    stream: false,
  };

  const response = await expoFetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...buildAuthHeaders(config),
    },
    body: JSON.stringify(body),
    signal,
  });

  if (!response.ok) {
    throw new Error(`LLM error ${response.status}: ${await response.text()}`);
  }

  const data = await response.json();
  const msg = data.choices?.[0]?.message;
  if (!msg) throw new Error('LLM returned no message');

  if (msg.tool_calls && msg.tool_calls.length > 0) {
    const calls: ToolCall[] = msg.tool_calls.map((c: any) => ({
      id: c.id,
      name: c.function.name,
      arguments: safeJSON(c.function.arguments),
    }));
    return { kind: 'tools', calls };
  }

  return { kind: 'text', text: msg.content ?? '' };
}

/**
 * 单轮流式调用（无工具），用于 interpreter 阶段
 */
export async function callLLMStreaming(
  messages: LLMMessage[],
  config: ChatProviderConfig,
  onChunk: (partial: string) => void,
  signal?: AbortSignal,
): Promise<string> {
  const url = `${config.baseUrl.replace(/\/$/, '')}/chat/completions`;
  const body = { model: config.model, messages, stream: true };

  const response = await expoFetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...buildAuthHeaders(config),
    },
    body: JSON.stringify(body),
    signal,
  });

  if (!response.ok) {
    throw new Error(`LLM error ${response.status}: ${await response.text()}`);
  }

  const reader = response.body?.getReader();
  if (!reader) throw new Error('no body reader');

  const decoder = new TextDecoder();
  let full = '';
  let buffer = '';

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    buffer += decoder.decode(value, { stream: true });
    const lines = buffer.split('\n');
    buffer = lines.pop() ?? '';
    for (const line of lines) {
      const t = line.trim();
      if (!t || t === 'data: [DONE]' || !t.startsWith('data: ')) continue;
      try {
        const j = JSON.parse(t.slice(6));
        const delta = j.choices?.[0]?.delta?.content;
        if (delta) {
          full += delta;
          onChunk(full);
        }
      } catch {}
    }
  }

  return full;
}

function safeJSON(s: string): Record<string, unknown> {
  try { return JSON.parse(s); } catch { return {}; }
}
```

- [ ] **Step 4: 跑测试**

Run: `npm test -- orchestrator`
Expected: 2 PASS。

- [ ] **Step 5: TypeScript check**

Run: `npx tsc --noEmit`
Expected: 无新错误。

- [ ] **Step 6: Commit**

```bash
git add lib/ai/tools/orchestrator.ts lib/ai/tools/__tests__/orchestrator.test.ts
git commit -m "ai/orchestrator: 单轮调用 helpers（带工具/流式）"
```

---

### Task 10：runOrchestration — Multi-turn loop + Call 2

**Files:**
- Modify: `lib/ai/tools/orchestrator.ts`
- Create: `lib/ai/tools/__tests__/run.test.ts`

- [ ] **Step 1: 写失败测试**

```ts
// lib/ai/tools/__tests__/run.test.ts
import { runOrchestration } from '../orchestrator';

const originalFetch = global.fetch;
afterEach(() => { global.fetch = originalFetch; });

const FIXED_CONFIG = {
  provider: 'openai' as const, apiKey: 'k', model: 'gpt-4o', baseUrl: 'https://x',
};

describe('runOrchestration', () => {
  it('handles a single-round flow (no tool calls)', async () => {
    let callCount = 0;
    global.fetch = jest.fn(async (_url, init: any) => {
      callCount++;
      const body = JSON.parse(init.body);
      // Call 1 (with tools): immediately return text
      if (body.tools) {
        return {
          ok: true,
          json: async () => ({ choices: [{ message: { content: '推演：1. ...\n2. ...\n综合：xxx' } }] }),
        };
      }
      // Call 2 (streaming): single chunk + DONE
      return {
        ok: true,
        body: makeSSEBody(['{"choices":[{"delta":{"content":"[interpretation]\\nhello"}}]}']),
      };
    }) as any;

    const onChunk = jest.fn();
    const onToolCall = jest.fn();
    const result = await runOrchestration({
      question: '我什么时候有孩子',
      identity: '日主：庚金',
      mingPan: {}, ziweiPan: {},
      config: FIXED_CONFIG,
      onChunk,
      onToolCall,
    });

    expect(callCount).toBe(2);
    expect(result.thinker).toContain('推演');
    expect(result.interpreter).toContain('[interpretation]');
    expect(onToolCall).not.toHaveBeenCalled();
    expect(onChunk).toHaveBeenCalled();
  });
});

function makeSSEBody(events: string[]): any {
  const enc = new TextEncoder();
  const lines = events.map(e => `data: ${e}\n\n`).concat(['data: [DONE]\n\n']);
  let i = 0;
  return {
    getReader: () => ({
      read: async () => {
        if (i >= lines.length) return { done: true, value: undefined };
        return { done: false, value: enc.encode(lines[i++]) };
      },
    }),
  };
}
```

- [ ] **Step 2: 跑测试**

Run: `npm test -- run.test`
Expected: FAIL with "runOrchestration not exported"。

- [ ] **Step 3: 实现 runOrchestration**

在 `lib/ai/tools/orchestrator.ts` 末尾添加：

```ts
import { ALL_TOOLS, ALL_HANDLERS, TOOL_STRATEGY } from './index';
import { THINKER_PROMPT, INTERPRETER_PROMPT } from '../index';
import type { ToolCall } from './types';

const MAX_TOOL_ROUNDS = 5;

export interface OrchestrationOptions {
  question: string;
  identity: string;        // 内联到 thinker 系统消息
  mingPan: any;
  ziweiPan: any;
  config: ChatProviderConfig;
  onToolCall?: (call: ToolCall, result: unknown) => void;
  onThinkerComplete?: (text: string) => void;
  onChunk?: (partialInterpretation: string) => void;
  signal?: AbortSignal;
}

export interface OrchestrationResult {
  thinker: string;
  interpreter: string;
  toolCalls: Array<{ call: ToolCall; result: unknown }>;
}

export async function runOrchestration(opts: OrchestrationOptions): Promise<OrchestrationResult> {
  const ctx = { mingPan: opts.mingPan, ziweiPan: opts.ziweiPan, now: new Date() };
  const toolCalls: Array<{ call: ToolCall; result: unknown }> = [];

  // ── Phase A：Call 1 thinker（multi-turn）
  const thinkerSystem = `${THINKER_PROMPT}

# 命主信息
${opts.identity}

# ${TOOL_STRATEGY}`;

  const messages: LLMMessage[] = [
    { role: 'system', content: thinkerSystem },
    { role: 'user', content: opts.question },
  ];

  let thinkerOutput = '';
  for (let round = 0; round < MAX_TOOL_ROUNDS; round++) {
    const resp = await callLLMWithTools(messages, opts.config, ALL_TOOLS, opts.signal);
    if (resp.kind === 'text') {
      thinkerOutput = resp.text;
      break;
    }
    // tools branch
    messages.push({
      role: 'assistant',
      content: null,
      tool_calls: resp.calls.map(c => ({
        id: c.id,
        type: 'function',
        function: { name: c.name, arguments: JSON.stringify(c.arguments) },
      })),
    });
    for (const call of resp.calls) {
      const handler = ALL_HANDLERS[call.name];
      let result: unknown;
      try {
        result = handler
          ? await handler(call.arguments, ctx)
          : { error: `unknown_tool:${call.name}` };
      } catch (e: any) {
        result = { error: String(e?.message ?? e) };
      }
      toolCalls.push({ call, result });
      opts.onToolCall?.(call, result);
      messages.push({
        role: 'tool',
        tool_call_id: call.id,
        content: JSON.stringify(result),
      });
    }
  }

  if (!thinkerOutput) {
    thinkerOutput = '推演引擎未给出最终结论（达到工具调用上限）。';
  }
  opts.onThinkerComplete?.(thinkerOutput);

  // ── Phase B：Call 2 interpreter（streaming）
  const interpMessages: LLMMessage[] = [
    { role: 'system', content: INTERPRETER_PROMPT },
    {
      role: 'user',
      content: `用户问题：${opts.question}\n\n推演引擎输出：\n${thinkerOutput}`,
    },
  ];

  const interpreterText = await callLLMStreaming(
    interpMessages, opts.config,
    (partial) => opts.onChunk?.(partial),
    opts.signal,
  );

  return {
    thinker: thinkerOutput,
    interpreter: interpreterText,
    toolCalls,
  };
}
```

注意：上面 `LLMMessage` / `ChatProviderConfig` 已在文件前部定义；`ToolCall` 从 `./types` import。 `ALL_TOOLS / ALL_HANDLERS / TOOL_STRATEGY` 来自 `./index`，会形成循环 import 但 TS 允许（运行时不会有问题，因为都是 const）。

- [ ] **Step 4: 跑测试**

Run: `npm test -- run.test`
Expected: 1 PASS。

跑全部测试确认没破坏：
Run: `npm test`
Expected: 全部 PASS。

- [ ] **Step 5: Commit**

```bash
git add lib/ai/tools/orchestrator.ts lib/ai/tools/__tests__/run.test.ts
git commit -m "ai/orchestrator: runOrchestration multi-turn loop + Call 2"
```

---

### Task 11：chat.ts 重构 — sendOrchestrated 入口

**Files:**
- Modify: `lib/ai/chat.ts`

把现有 `sendChat` 保留作"无命盘 fallback"，新增 `sendOrchestrated` 作为有命盘时的主入口。

- [ ] **Step 1: 添加新入口**

在 `lib/ai/chat.ts` 末尾添加：

```ts
import { runOrchestration, type OrchestrationOptions, type OrchestrationResult } from './tools/orchestrator';
import type { ToolCall } from './tools/types';

/** 构建 thinker prompt 的命主身份段（150 tokens 以内） */
function buildIdentityCard(mingPan: any, ziweiPan: any): string {
  if (!mingPan) return '（未配置生辰，无法做命理推演）';
  const ri = mingPan.riZhu;
  const wuxing = mingPan.wuXingStrength;
  const geju = mingPan.geJu;
  const lines = [
    `日主：${ri?.gan ?? ''}（${ri?.yinYang ?? ''}${ri?.wuXing ?? ''}）· ${geju?.name ?? ''}格`,
    `用神：${wuxing?.yongShen ?? ''} · 喜神：${wuxing?.xiShen ?? ''} · 忌神：${wuxing?.jiShen ?? ''}`,
  ];
  if (ziweiPan?.palaces) {
    const ming = ziweiPan.palaces.find((p: any) => p.name === '命宫');
    if (ming) {
      const stars = (ming.mainStars ?? []).map((s: any) => s.name).join('、');
      lines.push(`紫微命宫主星：${stars || '（空宫）'}`);
    }
  }
  return lines.join('\n');
}

export interface SendOrchestratedOptions {
  question: string;
  config: ChatConfig;
  mingPanJson: string | null;
  ziweiPanJson: string | null;
  onToolCall?: (call: ToolCall, result: unknown) => void;
  onThinkerComplete?: (text: string) => void;
  onChunk?: (partial: string) => void;
  signal?: AbortSignal;
}

/**
 * 主入口：调用 runOrchestration，自动构建身份卡片和上下文
 */
export async function sendOrchestrated(opts: SendOrchestratedOptions): Promise<OrchestrationResult> {
  const mingPan = opts.mingPanJson ? safeParse(opts.mingPanJson) : null;
  const ziweiPan = opts.ziweiPanJson ? safeParse(opts.ziweiPanJson) : null;

  return runOrchestration({
    question: opts.question,
    identity: buildIdentityCard(mingPan, ziweiPan),
    mingPan, ziweiPan,
    config: {
      provider: opts.config.provider,
      apiKey: opts.config.apiKey,
      model: opts.config.model,
      baseUrl: opts.config.baseUrl ?? '',
    },
    onToolCall: opts.onToolCall,
    onThinkerComplete: opts.onThinkerComplete,
    onChunk: opts.onChunk,
    signal: opts.signal,
  });
}

function safeParse(s: string): any { try { return JSON.parse(s); } catch { return null; } }
```

- [ ] **Step 2: TypeScript check**

Run: `npx tsc --noEmit`
Expected: 无新错误。如果有循环依赖警告（chat.ts → orchestrator.ts → chat.ts），不阻塞——TypeScript 允许 const-only 循环引用。

- [ ] **Step 3: 跑全部测试**

Run: `npm test`
Expected: 全部 PASS。

- [ ] **Step 4: Commit**

```bash
git add lib/ai/chat.ts
git commit -m "ai/chat: sendOrchestrated 入口（有命盘时使用编排，旧 sendChat 兜底）"
```

---

## Block D：输出解析

### Task 12：preprocessOrchestration

**Files:**
- Create: `components/ai/customRules/preprocessOrchestration.ts`
- Create: `components/ai/customRules/__tests__/preprocessOrchestration.test.ts`

- [ ] **Step 1: 写失败测试**

```ts
// components/ai/customRules/__tests__/preprocessOrchestration.test.ts
import { splitOrchestrationOutput } from '../preprocessOrchestration';

describe('splitOrchestrationOutput', () => {
  it('splits standard format', () => {
    const input = `[interpretation]
传统八字里，子女缘分看时柱与食神位。

[evidence]
子女星 · 食神
时柱 · 丙寅
当前大运 · 己亥`;
    const r = splitOrchestrationOutput(input);
    expect(r.interpretation).toContain('传统八字');
    expect(r.evidence).toEqual([
      '子女星 · 食神',
      '时柱 · 丙寅',
      '当前大运 · 己亥',
    ]);
  });

  it('returns interpretation only when [evidence] missing', () => {
    const input = `[interpretation]\n纯解读没有依据`;
    const r = splitOrchestrationOutput(input);
    expect(r.interpretation).toContain('纯解读');
    expect(r.evidence).toEqual([]);
  });

  it('falls back when no [interpretation] tag (whole text as interpretation)', () => {
    const input = '没有任何标签的内容';
    const r = splitOrchestrationOutput(input);
    expect(r.interpretation).toBe(input);
    expect(r.evidence).toEqual([]);
  });

  it('handles partial mid-stream input gracefully', () => {
    const input = `[interpretation]\n传统八字里，子女缘分`;
    const r = splitOrchestrationOutput(input);
    expect(r.interpretation).toBe('传统八字里，子女缘分');
    expect(r.evidence).toEqual([]);
  });

  it('trims empty lines from evidence', () => {
    const input = `[interpretation]\n解读\n\n[evidence]\n  \n子女星 · 食神\n  \n时柱 · 丙寅`;
    const r = splitOrchestrationOutput(input);
    expect(r.evidence).toEqual(['子女星 · 食神', '时柱 · 丙寅']);
  });
});
```

- [ ] **Step 2: 跑测试**

Run: `npm test -- preprocessOrchestration`
Expected: FAIL with "Cannot find module '../preprocessOrchestration'"。

- [ ] **Step 3: 实现**

```ts
// components/ai/customRules/preprocessOrchestration.ts
/**
 * 把 LLM 的 [interpretation] + [evidence] 双段输出拆开
 *
 * 容错：
 * - 缺少 [evidence] → evidence 返回空数组
 * - 完全无标签 → 整段作为 interpretation
 * - 流式中间态（只有 [interpretation] 半截）→ interpretation 取已到部分
 */

export interface OrchestrationParts {
  interpretation: string;
  evidence: string[];
}

const TAG_INTERP = '[interpretation]';
const TAG_EVID = '[evidence]';

export function splitOrchestrationOutput(input: string): OrchestrationParts {
  const interpIdx = input.indexOf(TAG_INTERP);
  const evidIdx = input.indexOf(TAG_EVID);

  if (interpIdx < 0) {
    return { interpretation: input.trim(), evidence: [] };
  }

  const after = input.slice(interpIdx + TAG_INTERP.length);
  if (evidIdx < 0 || evidIdx < interpIdx) {
    return { interpretation: after.trim(), evidence: [] };
  }

  const interpretation = input.slice(interpIdx + TAG_INTERP.length, evidIdx).trim();
  const evidenceRaw = input.slice(evidIdx + TAG_EVID.length).trim();
  const evidence = evidenceRaw
    .split('\n')
    .map(line => line.trim())
    .filter(Boolean);

  return { interpretation, evidence };
}
```

- [ ] **Step 4: 跑测试**

Run: `npm test -- preprocessOrchestration`
Expected: 5 PASS。

- [ ] **Step 5: Commit**

```bash
git add components/ai/customRules/preprocessOrchestration.ts components/ai/customRules/__tests__/preprocessOrchestration.test.ts
git commit -m "ai: preprocessOrchestration 拆 [interpretation]/[evidence]"
```

---

## Block E：UI 组件

### Task 13：EvidenceCard 组件

**Files:**
- Create: `components/ai/EvidenceCard.tsx`

- [ ] **Step 1: 创建**

```tsx
/**
 * 推演依据卡片（4 行预览 + "查看完整推演" → BottomSheet）
 */
import React from 'react';
import { View, Text, Pressable, StyleSheet } from 'react-native';
import { Colors, Space, Radius, Type, Shadow } from '@/lib/design/tokens';

const PREVIEW_LINES = 4;

type Props = {
  evidence: string[];
  onTapFull: () => void;
};

export function EvidenceCard({ evidence, onTapFull }: Props) {
  if (evidence.length === 0) return null;
  const visible = evidence.slice(0, PREVIEW_LINES);
  const hasMore = evidence.length > PREVIEW_LINES;

  return (
    <Pressable onPress={onTapFull} style={[styles.card, Shadow.sm]}>
      <View style={styles.headerRow}>
        <Text style={styles.headerIcon}>🔍</Text>
        <Text style={styles.headerLabel}>推演依据</Text>
      </View>
      {visible.map((line, i) => (
        <Text key={i} style={styles.line} numberOfLines={1}>{line}</Text>
      ))}
      <View style={styles.footer}>
        <Text style={styles.footerText}>
          {hasMore ? '⌄ 查看完整推演' : '⌄ 展开完整推演'}
        </Text>
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: Colors.brandBg,
    borderRadius: Radius.md,
    padding: Space.base,
    marginVertical: Space.sm,
    gap: 4,
  },
  headerRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    marginBottom: Space.xs,
  },
  headerIcon: { fontSize: 14 },
  headerLabel: {
    ...Type.label,
    color: Colors.vermilion,
    fontWeight: '600',
    letterSpacing: 1,
  },
  line: {
    ...Type.bodySmall,
    color: Colors.ink,
    lineHeight: 22,
  },
  footer: {
    marginTop: Space.xs,
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: Colors.border,
    paddingTop: Space.xs,
    alignItems: 'center',
  },
  footerText: {
    ...Type.caption,
    color: Colors.vermilion,
  },
});
```

- [ ] **Step 2: TypeScript check**

Run: `npx tsc --noEmit`
Expected: 无新错误。

- [ ] **Step 3: Commit**

```bash
git add components/ai/EvidenceCard.tsx
git commit -m "ai/ui: EvidenceCard 推演依据折叠卡（4 行预览）"
```

---

### Task 14：CoTCard 组件

**Files:**
- Create: `components/ai/CoTCard.tsx`

- [ ] **Step 1: 创建**

```tsx
/**
 * 推演过程卡片（streaming 时自动展开 + 列出工具调用，结束后默认折叠）
 */
import React, { useState } from 'react';
import { View, Text, Pressable, StyleSheet } from 'react-native';
import { Colors, Space, Radius, Type, Shadow } from '@/lib/design/tokens';

export interface ToolCallTrace {
  name: string;
  argSummary: string;     // 简短的参数摘要，如 'domain=子女'
  resultSummary?: string; // 简短的结果摘要
}

type Props = {
  toolCalls: ToolCallTrace[];
  thinkerText?: string;     // Call 1 完成后的文本（可选）
  isStreaming: boolean;
};

export function CoTCard({ toolCalls, thinkerText, isStreaming }: Props) {
  const [expanded, setExpanded] = useState(isStreaming);

  // streaming 时强制展开；结束后保留用户最后状态（默认收起）
  const open = isStreaming || expanded;

  if (toolCalls.length === 0 && !thinkerText) return null;

  return (
    <Pressable
      onPress={() => !isStreaming && setExpanded(v => !v)}
      style={[styles.card, Shadow.sm]}
    >
      <View style={styles.headerRow}>
        <Text style={styles.headerIcon}>🧠</Text>
        <Text style={styles.headerLabel}>
          {isStreaming ? '推演中…' : `${toolCalls.length} 步推演`}
        </Text>
        {!isStreaming && (
          <Text style={styles.toggle}>{open ? '⌃' : '⌄'}</Text>
        )}
      </View>

      {open && (
        <View style={styles.body}>
          {toolCalls.map((c, i) => (
            <Text key={i} style={styles.line}>
              📌 {c.name}({c.argSummary}){c.resultSummary ? ` → ${c.resultSummary}` : ''}
            </Text>
          ))}
          {thinkerText && (
            <Text style={styles.summary} numberOfLines={3}>
              {extractConclusion(thinkerText)}
            </Text>
          )}
        </View>
      )}
    </Pressable>
  );
}

function extractConclusion(text: string): string {
  // 提取"综合"或最后一段
  const m = text.match(/综合[：:](.+)$/m);
  if (m) return `综合：${m[1].trim()}`;
  const lines = text.split('\n').filter(Boolean);
  return lines[lines.length - 1] ?? text;
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: Colors.surface,
    borderRadius: Radius.md,
    padding: Space.base,
    marginVertical: Space.xs,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: Colors.border,
  },
  headerRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  headerIcon: { fontSize: 14 },
  headerLabel: {
    ...Type.caption,
    color: Colors.inkSecondary,
    fontWeight: '500',
    letterSpacing: 1,
    flex: 1,
  },
  toggle: { color: Colors.inkTertiary, fontSize: 14 },
  body: {
    marginTop: Space.sm,
    gap: 4,
  },
  line: {
    ...Type.caption,
    color: Colors.inkSecondary,
    lineHeight: 20,
  },
  summary: {
    ...Type.bodySmall,
    color: Colors.ink,
    fontStyle: 'italic',
    marginTop: Space.xs,
  },
});
```

- [ ] **Step 2: TypeScript check**

Run: `npx tsc --noEmit`
Expected: 无新错误。

- [ ] **Step 3: Commit**

```bash
git add components/ai/CoTCard.tsx
git commit -m "ai/ui: CoTCard 推演过程卡（流式自动展开，结束默认折叠）"
```

---

### Task 15：FullReasoningSheet 组件

**Files:**
- Create: `components/ai/FullReasoningSheet.tsx`

- [ ] **Step 1: 创建**

```tsx
/**
 * 完整推演 BottomSheet
 *
 * 内容：evidence 完整展开 + Call 1 推演原文 + tool 调用日志
 */
import React from 'react';
import { Modal, View, Text, Pressable, ScrollView, StyleSheet } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Colors, Space, Radius, Type, Shadow } from '@/lib/design/tokens';
import type { ToolCallTrace } from './CoTCard';

type Props = {
  visible: boolean;
  evidence: string[];
  thinkerText: string;
  toolCalls: ToolCallTrace[];
  onClose: () => void;
};

export function FullReasoningSheet({
  visible, evidence, thinkerText, toolCalls, onClose,
}: Props) {
  const insets = useSafeAreaInsets();

  return (
    <Modal
      visible={visible}
      transparent
      animationType="slide"
      onRequestClose={onClose}
    >
      <Pressable style={styles.backdrop} onPress={onClose} />
      <View
        style={[
          styles.sheet,
          { paddingBottom: insets.bottom + Space.lg },
          Shadow.md,
        ]}
      >
        <View style={styles.handle} />
        <ScrollView contentContainerStyle={styles.content}>
          <Text style={styles.title}>完整推演</Text>

          {evidence.length > 0 && (
            <Section label="你的命盘要点">
              {evidence.map((line, i) => (
                <Text key={i} style={styles.line}>{line}</Text>
              ))}
            </Section>
          )}

          {thinkerText && (
            <Section label="推演过程">
              <Text style={styles.thinker}>{thinkerText}</Text>
            </Section>
          )}

          {toolCalls.length > 0 && (
            <Section label="使用的数据">
              {toolCalls.map((c, i) => (
                <Text key={i} style={styles.line}>
                  📌 {c.name}({c.argSummary}){c.resultSummary ? ` → ${c.resultSummary}` : ''}
                </Text>
              ))}
            </Section>
          )}

          <Pressable style={styles.closeBtn} onPress={onClose}>
            <Text style={styles.closeText}>关闭</Text>
          </Pressable>
        </ScrollView>
      </View>
    </Modal>
  );
}

function Section({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <View style={styles.section}>
      <Text style={styles.sectionLabel}>{label}</Text>
      <View style={styles.divider} />
      <View style={styles.sectionBody}>{children}</View>
    </View>
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
    maxHeight: '85%',
  },
  handle: {
    alignSelf: 'center',
    width: 36, height: 4,
    borderRadius: 2,
    backgroundColor: Colors.border,
    marginTop: Space.sm,
  },
  content: { padding: Space.xl, gap: Space.md },
  title: { ...Type.title, color: Colors.ink },
  section: { gap: Space.xs, marginTop: Space.md },
  sectionLabel: {
    ...Type.label, color: Colors.vermilion, letterSpacing: 2,
  },
  divider: {
    height: StyleSheet.hairlineWidth,
    backgroundColor: Colors.border,
    marginVertical: Space.xs,
  },
  sectionBody: { gap: Space.xs },
  line: { ...Type.bodySmall, color: Colors.ink, lineHeight: 22 },
  thinker: { ...Type.body, color: Colors.ink, lineHeight: 26 },
  closeBtn: {
    marginTop: Space.xl,
    alignSelf: 'center',
    paddingVertical: Space.md,
    paddingHorizontal: Space['2xl'],
    borderRadius: Radius.lg,
    backgroundColor: Colors.bgSecondary,
  },
  closeText: { ...Type.body, color: Colors.ink },
});
```

- [ ] **Step 2: TypeScript check**

Run: `npx tsc --noEmit`
Expected: 无新错误。

- [ ] **Step 3: Commit**

```bash
git add components/ai/FullReasoningSheet.tsx
git commit -m "ai/ui: FullReasoningSheet 完整推演 BottomSheet"
```

---

### Task 16：insight.tsx 接入新编排管线

**Files:**
- Modify: `app/(tabs)/insight.tsx`

这一步把上面所有部件串起来。

- [ ] **Step 1: 修改 imports**

替换/补充 imports：

```tsx
// 删除：
// import { sendChat } from '@/lib/ai/chat';

// 新增：
import { sendOrchestrated } from '@/lib/ai/chat';
import { CoTCard, type ToolCallTrace } from '@/components/ai/CoTCard';
import { EvidenceCard } from '@/components/ai/EvidenceCard';
import { FullReasoningSheet } from '@/components/ai/FullReasoningSheet';
import { splitOrchestrationOutput } from '@/components/ai/customRules/preprocessOrchestration';
```

`getChatConfig` 的 import 保持不变。

- [ ] **Step 2: 调整 message 类型，存编排副产品**

聊天消息此前结构：`{ role, content, timestamp }`。需要在 assistant 消息上挂可选的编排数据。修改 `lib/ai/index.ts` 里的 `ChatMessage`：

打开 `lib/ai/index.ts`，把：

```ts
export interface ChatMessage {
  role: 'user' | 'assistant';
  content: string;
  timestamp: number;
}
```

改为：

```ts
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
    }>;
  };
}
```

- [ ] **Step 3: 重写 handleSend**

把 `insight.tsx` 内的 `handleSend` 整体替换为：

```tsx
// 当次发送的"实时"流式状态
const [liveToolCalls, setLiveToolCalls] = useState<ToolCallTrace[]>([]);
const [liveThinker, setLiveThinker] = useState('');

// 详情 BottomSheet 状态
const [sheetData, setSheetData] = useState<null | {
  thinker: string;
  evidence: string[];
  toolCalls: ToolCallTrace[];
}>(null);

const handleSend = useCallback(async () => {
  const text = message.trim();
  if (!text || !config || loading) return;

  const userMsg: ChatMessage = { role: 'user', content: text, timestamp: Date.now() };
  addMessage(userMsg);
  setMessage('');
  setLoading(true);
  setStreamingText('');
  setLiveToolCalls([]);
  setLiveThinker('');
  const abortController = new AbortController();
  abortRef.current = abortController;

  // 本地累计 tool calls（避免 React state 在 closure 里 stale）
  const localToolCalls: ToolCallTrace[] = [];

  try {
    const result = await sendOrchestrated({
      question: text,
      config,
      mingPanJson: store.mingPanCache,
      ziweiPanJson: store.ziweiPanCache,
      onToolCall: (call, res) => {
        const trace: ToolCallTrace = {
          name: call.name,
          argSummary: summarizeArgs(call.arguments),
          resultSummary: summarizeResult(res),
        };
        localToolCalls.push(trace);
        setLiveToolCalls(prev => [...prev, trace]);
      },
      onThinkerComplete: (t) => setLiveThinker(t),
      onChunk: (partial) => {
        setStreamingText(partial);
        setTimeout(() => scrollRef.current?.scrollToEnd({ animated: true }), 50);
      },
      signal: abortController.signal,
    });

    const assistantMsg: ChatMessage = {
      role: 'assistant',
      content: result.interpreter,
      timestamp: Date.now(),
      orchestration: {
        thinker: result.thinker,
        evidence: splitOrchestrationOutput(result.interpreter).evidence,
        toolCalls: localToolCalls,
      },
    };
    addMessage(assistantMsg);
    setStreamingText('');
    setLiveToolCalls([]);
    setLiveThinker('');
  } catch (err: any) {
    const errorMsg: ChatMessage = {
      role: 'assistant',
      content: `请求失败：${err.message || '未知错误'}`,
      timestamp: Date.now(),
    };
    addMessage(errorMsg);
    setStreamingText('');
    setLiveToolCalls([]);
    setLiveThinker('');
  } finally {
    setLoading(false);
    abortRef.current = null;
  }
}, [message, config, loading, store.mingPanCache, store.ziweiPanCache, addMessage]);

function summarizeArgs(args: Record<string, unknown>): string {
  return Object.entries(args).map(([k, v]) => `${k}=${v}`).join(', ');
}

function summarizeResult(r: any): string {
  if (!r) return '';
  if (typeof r === 'string') return r.length > 30 ? r.slice(0, 30) + '…' : r;
  if (r.summary) return r.summary;
  if (r.error) return `error:${r.error}`;
  return JSON.stringify(r).slice(0, 30) + '…';
}
```

注意：函数 `summarizeArgs` 和 `summarizeResult` 必须在文件作用域（不在 InsightScreen 内），或者放在 InsightScreen 内（用 `useCallback` 包装也行）；为简洁，放文件顶级。

- [ ] **Step 4: 改 JSX 中的 AI 气泡渲染**

普通 AI 气泡（`messages.map` 里）：

```tsx
) : (
  <View key={i} style={[styles.aiBubble, Shadow.sm]}>
    <Text style={styles.aiName}>岁吉</Text>

    {msg.orchestration && (
      <CoTCard
        toolCalls={msg.orchestration.toolCalls}
        thinkerText={msg.orchestration.thinker}
        isStreaming={false}
      />
    )}

    <RichContent content={
      msg.orchestration
        ? splitOrchestrationOutput(msg.content).interpretation
        : msg.content
    } />

    {msg.orchestration && msg.orchestration.evidence.length > 0 && (
      <EvidenceCard
        evidence={msg.orchestration.evidence}
        onTapFull={() => setSheetData({
          thinker: msg.orchestration!.thinker,
          evidence: msg.orchestration!.evidence,
          toolCalls: msg.orchestration!.toolCalls,
        })}
      />
    )}
  </View>
)
```

流式气泡：

```tsx
{(streamingText || liveToolCalls.length > 0) ? (
  <View style={[styles.aiBubble, Shadow.sm]}>
    <Text style={styles.aiName}>岁吉</Text>

    <CoTCard
      toolCalls={liveToolCalls}
      thinkerText={liveThinker}
      isStreaming={true}
    />

    {streamingText && (
      <>
        <RichContent content={
          splitOrchestrationOutput(streamingText).interpretation
        } />
        <StreamCursor />
      </>
    )}

    {streamingText && (() => {
      const evid = splitOrchestrationOutput(streamingText).evidence;
      return evid.length > 0 ? (
        <EvidenceCard
          evidence={evid}
          onTapFull={() => setSheetData({
            thinker: liveThinker,
            evidence: evid,
            toolCalls: liveToolCalls,
          })}
        />
      ) : null;
    })()}
  </View>
) : null}
```

末尾加 BottomSheet：

```tsx
<FullReasoningSheet
  visible={sheetData !== null}
  evidence={sheetData?.evidence ?? []}
  thinkerText={sheetData?.thinker ?? ''}
  toolCalls={sheetData?.toolCalls ?? []}
  onClose={() => setSheetData(null)}
/>
```

- [ ] **Step 5: TypeScript check**

Run: `npx tsc --noEmit`
Expected: 无新错误。

- [ ] **Step 6: 跑全部测试**

Run: `npm test`
Expected: 全部 PASS。

- [ ] **Step 7: Commit**

```bash
git add "app/(tabs)/insight.tsx" lib/ai/index.ts
git commit -m "chat: 接入编排管线 + CoTCard + EvidenceCard + FullReasoningSheet"
```

---

## Block F：验证

### Task 17：跨模块手测 + 真机验证

- [ ] **Step 1: 跑全部单测**

```bash
cd /Users/xiaqobenwang/Documents/SUJI
npm test
```

Expected: 全部 PASS（约 40+ 测试，根据各 task 累积）。

- [ ] **Step 2: tsc 全检**

```bash
npx tsc --noEmit
```

Expected: 仅有 main 上原有的 2 个错误（`lib/ai/chat.ts:???` const-assertion + `lib/bazi/BaziEngine.ts:15` 缺 export），无新错误。

- [ ] **Step 3: 真机 build**

```bash
npx expo run:ios --device 00008140-001262AE010A801C --configuration Release
```

可能要 5-10 分钟（首次添加 iztro，xcodebuild 需要重新链接）。

- [ ] **Step 4: 手测矩阵**

进 App，登录后到"问道"页，确保已配过生辰（首次会触发 ZiweiEngine 生成，看一下没报错）。

| 测试问题 | 期望调用 | 期望解读 |
|---|---|---|
| "我什么时候会有孩子" | `get_domain('子女')` + `get_timing('liunian')` | 双段输出，evidence 含子女星 + 流年 |
| "今年事业怎么样" | `get_domain('事业')` + `get_today_context()` | 双段输出，evidence 含官禄宫 |
| "我跟我老公合不合" | `get_domain('婚姻')` + `list_shensha('桃花')` | 双段输出，evidence 含夫妻宫 + 桃花 |
| "今天怎么样" | `get_today_context()` | 双段输出 |
| "我这辈子整体" | `get_timing('all_dayun')` 或不调工具 | 解读基于内联身份 |

每条逐一观察：
- ✅ CoT 卡出现并显示 tool 调用
- ✅ Evidence 卡 4 行预览
- ✅ 点 Evidence 卡或 CoT 卡能弹出 BottomSheet
- ✅ BottomSheet 显示完整推演 + 工具调用列表
- ✅ 关掉 App 重开 → 历史消息仍在（chatStore 持久化）
- ✅ 流式中点 ⏹ 中断 → 已到达内容保留

- [ ] **Step 5: 如果有 bug，记录在 plan 末尾的"已知问题"，按需修复**

- [ ] **Step 6: 推到 remote**

```bash
git push
```

---

## 已知风险与回退方案

### R1：Tool-use 在 Anthropic / Responses API 上未实现

本 plan 只实现 OpenAI-compatible 协议（覆盖 OpenAI / DeepSeek / 多数自定义 baseUrl）。如果用户用 Anthropic 或 Azure AI Foundry：

- 现状：调 `callLLMWithTools` 时会失败（Anthropic 协议是 `tools` 但字段名 `input_schema`，Responses API 是 `tool` 顶层独立字段）
- 回退：捕获错误，提示"该 provider 暂未支持工具调用，请切换至 OpenAI/DeepSeek"
- 后续 task：Phase 1B 加适配层（不在本 plan 范围）

### R2：iztro 在 RN 0.81 + New Architecture 下未知

如果 ZiweiEngine 在真机上有日历计算偏差或 import 问题：
- 短期：把 ziweiPanCache 标记为 null，UI 降级为"暂未生成紫微盘"
- 长期：调试 iztro 兼容性 / 切到 fortel-ziweidoushu

### R3：AI 不严格按 [interpretation]/[evidence] 输出

`splitOrchestrationOutput` 已兜底：缺 [evidence] → 整段当 interpretation；无任何 tag → 全文当 interpretation。

不报错、不丢内容。如发生率高再加 retry / format-fix。

### R4：Multi-turn 工具循环达上限

`MAX_TOOL_ROUNDS = 5`，超出则跳出循环并合成 `推演引擎未给出最终结论（达到工具调用上限）`。Call 2 会基于这个降级文本写 interpretation。用户体感：能拿到答但 evidence 卡可能空。

### R5：循环 import（chat.ts ↔ orchestrator.ts ↔ tools/index.ts）

按当前实现可能存在三角依赖，TypeScript 允许 const-only 循环引用，运行时也无问题。如 Node bundler 报错则把 `THINKER_PROMPT` 等常量 inline 到 orchestrator.ts。
