# 出生时辰校准（Phase 4）实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在"我的"页面加一个 chat 式时辰校准入口，通过 ±1 时辰 3 候选 + bifurcation 鉴别 + AI 改写问句 + 结构化分类，给用户一个 5 轮以内的对话校准体验，结果直接覆盖 `useUserStore.birthDate`。

**Architecture:** 程序确定性引擎驱动（`lib/calibration/`：候选盘、事件提取、bifurcation、模板库、scoring、状态机），LLM 仅做"模板 → 自然问句 + 用户答案 → yes/no/uncertain"，每轮 1 次 JSON-mode 调用。UI 用 RN `Modal` 模式（参 `FullReasoningSheet`）+ 内联 chat 渲染。

**Tech Stack:** TypeScript strict, Jest, Zustand, Expo SDK 54, lunisolar, iztro，OpenAI/DeepSeek/Anthropic-compatible Chat Completions（JSON mode）。

**Spec:** `docs/superpowers/specs/2026-04-26-time-calibration-design.md`

---

## 文件结构（决定边界）

```
lib/calibration/
├── types.ts                    # 共享类型
├── buildCandidates.ts          # ±1 时辰 → 3 候选盘
├── extractEvents.ts            # MingPan → 年份-事件向量
├── bifurcation.ts              # 3 候选盘 → 排序后的鉴别年份列表
├── templates/
│   ├── types.ts                # QuestionTemplate 类型
│   ├── dayun.ts                # 大运类 6 个模板
│   ├── liunian.ts              # 流年类 4 个模板
│   ├── personality.ts          # 兜底类 2 个模板
│   └── index.ts                # 聚合 + 匹配
├── scoring.ts                  # applyAnswer + checkTermination
├── CalibrationSession.ts       # 状态机（不含 AI）
├── CalibrationAI.ts            # 单 LLM call 封装
└── __tests__/
    ├── buildCandidates.test.ts
    ├── extractEvents.test.ts
    ├── bifurcation.test.ts
    ├── templates.test.ts
    ├── scoring.test.ts
    ├── CalibrationSession.test.ts
    └── integration.test.ts

components/calibration/
├── ThinkingDots.tsx            # 思考动画（30 行）
└── CalibrationSheet.tsx        # Modal + 内联 chat

app/(tabs)/profile.tsx          # 加入口行 + visible state（修改）
```

紫微类 3 个模板暂不在本期（需要扩 ZiweiEngine 暴露大限，留 Phase 4.5）。MVP 共 12 个模板：大运 6 + 流年 4 + 兜底 2。

---

## Task 1：types + 候选盘构造

**Files:**
- Create: `lib/calibration/types.ts`
- Create: `lib/calibration/buildCandidates.ts`
- Test: `lib/calibration/__tests__/buildCandidates.test.ts`

- [ ] **Step 1.1: 写 types.ts**

```ts
// lib/calibration/types.ts
import type { MingPan } from '@/lib/bazi/types';

export type CandidateId = 'before' | 'origin' | 'after';

export type EventType =
  | '大运转七杀' | '大运转正官' | '大运转伤官'
  | '大运转食神' | '大运转比肩' | '大运转劫财'
  | '大运转正印' | '大运转偏印' | '大运转正财' | '大运转偏财'
  | '流年七杀临身' | '流年伤官见官' | '流年正财动' | '流年子女星动'
  | 'none';

export interface Candidate {
  id: CandidateId;
  birthDate: Date;
  mingPan: MingPan;
}

export interface YearEvent {
  candidateId: CandidateId;
  eventType: EventType;
}

export interface BifurcatedYear {
  year: number;
  ageAt: { before: number; origin: number; after: number };
  events: Record<CandidateId, EventType>;
  diversity: number;        // 0..3，3=三盘各自不同，2=有 1 对相同，1=不在判别（不会进入候选）
}

export interface AskedQuestion {
  templateId: string;
  year: number;
  ageThen: number;
  questionText: string;
  userAnswer: string;
  classified: 'yes' | 'no' | 'uncertain';
  delta: Record<CandidateId, number>;
}

export interface CalibrationSessionState {
  candidates: [Candidate, Candidate, Candidate];
  scores: Record<CandidateId, number>;
  history: AskedQuestion[];
  bifurcations: BifurcatedYear[];   // 起 session 时一次性算好排序
  consumedKeys: Set<string>;        // "templateId:year" 用过的不再选
  round: number;
  consecutiveUncertain: number;
  status: 'asking' | 'locked' | 'gave_up';
  lockedCandidate?: CandidateId;
}
```

- [ ] **Step 1.2: 写 buildCandidates 测试（先失败）**

```ts
// lib/calibration/__tests__/buildCandidates.test.ts
import { buildCandidates, SHICHEN_ANCHORS } from '../buildCandidates';

describe('buildCandidates', () => {
  it('returns 3 candidates with ±1 时辰 around 戌时 anchor', () => {
    // 1995-08-15 19:30 戌时 (19-21)
    const birth = new Date('1995-08-15T19:30:00+08:00');
    const result = buildCandidates(birth, '男', 116.4);
    expect(result).toHaveLength(3);
    expect(result.map(c => c.id)).toEqual(['before', 'origin', 'after']);
    // 酉时 anchor 18:00, 戌时 anchor 20:00, 亥时 anchor 22:00
    const hours = result.map(c => c.birthDate.getHours());
    expect(hours).toEqual([18, 20, 22]);
    expect(result[0].mingPan).toBeDefined();
    expect(result[1].mingPan.gender).toBe('男');
  });

  it('SHICHEN_ANCHORS covers all 12 时辰', () => {
    expect(Object.keys(SHICHEN_ANCHORS)).toHaveLength(12);
    expect(SHICHEN_ANCHORS['戌']).toBe(20);
  });
});
```

- [ ] **Step 1.3: 跑测试确认 fail**

Run: `npm test -- --testPathPattern=buildCandidates`
Expected: `Cannot find module '../buildCandidates'`

- [ ] **Step 1.4: 写 buildCandidates.ts**

```ts
// lib/calibration/buildCandidates.ts
import { BaziEngine } from '@/lib/bazi/BaziEngine';
import type { Candidate, CandidateId } from './types';

/** 12 时辰中位时刻（小时，用于稳定排盘） */
export const SHICHEN_ANCHORS: Record<string, number> = {
  '子': 0,  '丑': 2,  '寅': 4,  '卯': 6,
  '辰': 8,  '巳': 10, '午': 12, '未': 14,
  '申': 16, '酉': 18, '戌': 20, '亥': 22,
};

const ORDER = ['子','丑','寅','卯','辰','巳','午','未','申','酉','戌','亥'] as const;

function shichenOfHour(hour: number): typeof ORDER[number] {
  // 子时 23-1, 丑 1-3, ...
  if (hour === 23 || hour === 0) return '子';
  return ORDER[Math.floor((hour + 1) / 2)];
}

function adjacent(shi: typeof ORDER[number], offset: number): typeof ORDER[number] {
  const idx = ORDER.indexOf(shi);
  const next = (idx + offset + 12) % 12;
  return ORDER[next];
}

function buildAt(originDate: Date, anchorHour: number): Date {
  const d = new Date(originDate);
  d.setHours(anchorHour, 0, 0, 0);
  return d;
}

const engine = new BaziEngine();

export function buildCandidates(
  birthDate: Date,
  gender: '男' | '女',
  longitude: number,
): [Candidate, Candidate, Candidate] {
  const originShi = shichenOfHour(birthDate.getHours());
  const beforeShi = adjacent(originShi, -1);
  const afterShi = adjacent(originShi, +1);

  const make = (id: CandidateId, shi: typeof ORDER[number]): Candidate => {
    const date = buildAt(birthDate, SHICHEN_ANCHORS[shi]);
    return { id, birthDate: date, mingPan: engine.calculate(date, gender, longitude) };
  };

  return [
    make('before', beforeShi),
    make('origin', originShi),
    make('after', afterShi),
  ];
}
```

- [ ] **Step 1.5: 跑测试确认 pass**

Run: `npm test -- --testPathPattern=buildCandidates`
Expected: 2 passed

- [ ] **Step 1.6: 提交**

```bash
git add lib/calibration/types.ts lib/calibration/buildCandidates.ts lib/calibration/__tests__/buildCandidates.test.ts
git commit -m "calibration: types + ±1 时辰候选盘构造"
```

---

## Task 2：事件向量提取 + bifurcation detector

**Files:**
- Create: `lib/calibration/extractEvents.ts`
- Create: `lib/calibration/bifurcation.ts`
- Test: `lib/calibration/__tests__/extractEvents.test.ts`
- Test: `lib/calibration/__tests__/bifurcation.test.ts`

- [ ] **Step 2.1: 写 extractEvents 测试**

```ts
// lib/calibration/__tests__/extractEvents.test.ts
import { extractEventsForCandidate } from '../extractEvents';
import { buildCandidates } from '../buildCandidates';

describe('extractEventsForCandidate', () => {
  it('returns events for ages 1..currentAge for a 1995 birth in 2026', () => {
    const cands = buildCandidates(new Date('1995-08-15T20:00:00+08:00'), '男', 116.4);
    const events = extractEventsForCandidate(cands[1], 2026);
    expect(Object.keys(events).length).toBeGreaterThan(15);   // 至少 15 年
    expect(Object.keys(events).every(y => /^\d{4}$/.test(y))).toBe(true);
  });

  it('marks 大运 boundary years with 大运转 event', () => {
    const cands = buildCandidates(new Date('1995-08-15T20:00:00+08:00'), '男', 116.4);
    const events = extractEventsForCandidate(cands[1], 2026);
    const hasDayunTransition = Object.values(events).some(e => e.startsWith('大运转'));
    expect(hasDayunTransition).toBe(true);
  });
});
```

- [ ] **Step 2.2: 跑确认 fail**

Run: `npm test -- --testPathPattern=extractEvents`
Expected: `Cannot find module '../extractEvents'`

- [ ] **Step 2.3: 写 extractEvents.ts**

```ts
// lib/calibration/extractEvents.ts
import { DayunEngine } from '@/lib/bazi/DayunEngine';
import type { Candidate, EventType } from './types';
import type { ShiShen, DaYun } from '@/lib/bazi/types';

const SHISHEN_TO_DAYUN_EVENT: Partial<Record<ShiShen, EventType>> = {
  '七杀': '大运转七杀',
  '正官': '大运转正官',
  '伤官': '大运转伤官',
  '食神': '大运转食神',
  '比肩': '大运转比肩',
  '劫财': '大运转劫财',
  '正印': '大运转正印',
  '偏印': '大运转偏印',
  '正财': '大运转正财',
  '偏财': '大运转偏财',
};

/**
 * 给定候选盘，返回 birth+1 → currentYear 的 {year → eventType} 映射。
 * 大运转入年（startAge）写大运十神事件；其它年优先看流年关键事件，否则 'none'。
 */
export function extractEventsForCandidate(
  candidate: Candidate,
  currentYear: number,
): Record<number, EventType> {
  const dayunEngine = new DayunEngine(candidate.mingPan);
  const dayunList = dayunEngine.getDaYunList();
  const birthYear = candidate.birthDate.getFullYear();

  const events: Record<number, EventType> = {};

  // 大运转入年
  for (const dy of dayunList) {
    const transitionYear = birthYear + dy.startAge;
    if (transitionYear > currentYear) break;
    if (transitionYear <= birthYear) continue;
    const eventType = SHISHEN_TO_DAYUN_EVENT[dy.shiShen];
    if (eventType) events[transitionYear] = eventType;
  }

  // 流年关键事件（在没有大运转入的年份）
  for (let year = birthYear + 1; year <= currentYear; year++) {
    if (events[year]) continue;
    const ln = dayunEngine.getCurrentLiuNian(year);
    if (ln.shiShen === '七杀') events[year] = '流年七杀临身';
    else if (ln.shiShen === '伤官') {
      // 伤官见正官？需查命局是否有正官 → 简化：临伤官即标
      events[year] = '流年伤官见官';
    } else if (ln.shiShen === '正财' || ln.shiShen === '偏财') {
      events[year] = '流年正财动';
    } else {
      events[year] = 'none';
    }
  }

  return events;
}
```

- [ ] **Step 2.4: 跑确认 pass**

Run: `npm test -- --testPathPattern=extractEvents`
Expected: 2 passed

- [ ] **Step 2.5: 写 bifurcation 测试**

```ts
// lib/calibration/__tests__/bifurcation.test.ts
import { detectBifurcations } from '../bifurcation';
import { buildCandidates } from '../buildCandidates';

describe('detectBifurcations', () => {
  it('returns years sorted by diversity desc then recency desc', () => {
    const cands = buildCandidates(new Date('1995-08-15T20:00:00+08:00'), '男', 116.4);
    const bifs = detectBifurcations(cands, 2026);
    expect(bifs.length).toBeGreaterThan(0);
    // 第一个 diversity 应 ≥ 任意后续
    for (let i = 1; i < bifs.length; i++) {
      expect(bifs[i - 1].diversity).toBeGreaterThanOrEqual(bifs[i].diversity);
    }
    // 同 diversity 下，year 降序
    for (let i = 1; i < bifs.length; i++) {
      if (bifs[i - 1].diversity === bifs[i].diversity) {
        expect(bifs[i - 1].year).toBeGreaterThanOrEqual(bifs[i].year);
      }
    }
  });

  it('only returns years where at least 2 candidates differ', () => {
    const cands = buildCandidates(new Date('1995-08-15T20:00:00+08:00'), '男', 116.4);
    const bifs = detectBifurcations(cands, 2026);
    for (const b of bifs) {
      expect(b.diversity).toBeGreaterThanOrEqual(1);
    }
  });
});
```

- [ ] **Step 2.6: 跑确认 fail**

Run: `npm test -- --testPathPattern=bifurcation`
Expected: `Cannot find module '../bifurcation'`

- [ ] **Step 2.7: 写 bifurcation.ts**

```ts
// lib/calibration/bifurcation.ts
import type { Candidate, BifurcatedYear, CandidateId, EventType } from './types';
import { extractEventsForCandidate } from './extractEvents';

function diversityOf(events: Record<CandidateId, EventType>): number {
  const vals = [events.before, events.origin, events.after];
  const uniq = new Set(vals);
  // 三盘全不同 = 3, 有 1 对相同 = 2, 三盘全相同 = 1（不进候选）
  return uniq.size === 3 ? 3 : uniq.size === 2 ? 2 : 1;
}

export function detectBifurcations(
  candidates: [Candidate, Candidate, Candidate],
  currentYear: number,
): BifurcatedYear[] {
  const evb = extractEventsForCandidate(candidates[0], currentYear);
  const evo = extractEventsForCandidate(candidates[1], currentYear);
  const eva = extractEventsForCandidate(candidates[2], currentYear);

  const years = new Set([...Object.keys(evb), ...Object.keys(evo), ...Object.keys(eva)].map(Number));

  const result: BifurcatedYear[] = [];
  for (const year of years) {
    const events = {
      before: evb[year] ?? 'none',
      origin: evo[year] ?? 'none',
      after: eva[year] ?? 'none',
    } as Record<CandidateId, EventType>;
    const div = diversityOf(events);
    if (div < 2) continue;   // 三盘相同，无判别价值
    // 全 'none' 但不同的情况 div 仍 ≥ 2 但语义无差，过滤
    if (events.before === 'none' && events.origin === 'none' && events.after === 'none') continue;

    result.push({
      year,
      ageAt: {
        before: year - candidates[0].birthDate.getFullYear(),
        origin: year - candidates[1].birthDate.getFullYear(),
        after: year - candidates[2].birthDate.getFullYear(),
      },
      events,
      diversity: div,
    });
  }

  result.sort((a, b) => b.diversity - a.diversity || b.year - a.year);
  return result;
}
```

- [ ] **Step 2.8: 跑确认 pass**

Run: `npm test -- --testPathPattern=bifurcation`
Expected: 2 passed

- [ ] **Step 2.9: 提交**

```bash
git add lib/calibration/extractEvents.ts lib/calibration/bifurcation.ts lib/calibration/__tests__/extractEvents.test.ts lib/calibration/__tests__/bifurcation.test.ts
git commit -m "calibration: 事件向量提取 + bifurcation detector"
```

---

## Task 3：模板类型 + 大运类 6 个模板

**Files:**
- Create: `lib/calibration/templates/types.ts`
- Create: `lib/calibration/templates/dayun.ts`
- Test: `lib/calibration/__tests__/templates-dayun.test.ts`

- [ ] **Step 3.1: 写 templates/types.ts**

```ts
// lib/calibration/templates/types.ts
import type { EventType } from '../types';

export interface QuestionTemplate {
  id: string;
  triggerEvents: EventType[];
  /** 不同 eventType 在该模板下的"用户应回答 yes/no/irrelevant" */
  variants: Partial<Record<EventType, 'yes' | 'no' | 'irrelevant'>>;
  /** 模板原文，含 {year} {age} */
  rawQuestion: string;
}
```

- [ ] **Step 3.2: 写 dayun 测试**

```ts
// lib/calibration/__tests__/templates-dayun.test.ts
import { DAYUN_TEMPLATES } from '../templates/dayun';

describe('DAYUN_TEMPLATES', () => {
  it('has 6 templates with unique ids', () => {
    expect(DAYUN_TEMPLATES).toHaveLength(6);
    const ids = DAYUN_TEMPLATES.map(t => t.id);
    expect(new Set(ids).size).toBe(6);
  });

  it('each template has rawQuestion containing {year} and {age}', () => {
    for (const t of DAYUN_TEMPLATES) {
      expect(t.rawQuestion).toMatch(/\{year\}/);
      expect(t.rawQuestion).toMatch(/\{age\}/);
    }
  });

  it('each template has at least 2 trigger events with non-irrelevant variants', () => {
    for (const t of DAYUN_TEMPLATES) {
      const meaningful = Object.values(t.variants).filter(v => v !== 'irrelevant');
      expect(meaningful.length).toBeGreaterThanOrEqual(2);
    }
  });
});
```

- [ ] **Step 3.3: 跑确认 fail**

Run: `npm test -- --testPathPattern=templates-dayun`
Expected: `Cannot find module '../templates/dayun'`

- [ ] **Step 3.4: 写 dayun.ts（6 个模板）**

```ts
// lib/calibration/templates/dayun.ts
import type { QuestionTemplate } from './types';

export const DAYUN_TEMPLATES: QuestionTemplate[] = [
  {
    id: 'qisha_role_shift',
    triggerEvents: ['大运转七杀', '大运转正官', '大运转比肩'],
    variants: {
      '大运转七杀': 'yes',
      '大运转正官': 'no',
      '大运转比肩': 'no',
    },
    rawQuestion: '你 {age} 岁那年（{year}）有没有从某种压抑的环境里挣脱出来，比如换工作、跟权威翻脸、独自承担一件大事？',
  },
  {
    id: 'zhengguan_into_position',
    triggerEvents: ['大运转正官', '大运转伤官', '大运转食神'],
    variants: {
      '大运转正官': 'yes',
      '大运转伤官': 'no',
      '大运转食神': 'no',
    },
    rawQuestion: '你 {age} 岁那年（{year}）有没有进入一个更需要克制自己、配合规则的位置？比如新岗位、新团队、新家庭责任。',
  },
  {
    id: 'shangguan_conflict',
    triggerEvents: ['大运转伤官', '大运转正官', '大运转正印'],
    variants: {
      '大运转伤官': 'yes',
      '大运转正官': 'no',
      '大运转正印': 'no',
    },
    rawQuestion: '你 {age} 岁那年（{year}）有没有跟领导/师长/规则发生明显摩擦，或者主动选择走非常规的路？',
  },
  {
    id: 'shishen_express',
    triggerEvents: ['大运转食神', '大运转七杀', '大运转劫财'],
    variants: {
      '大运转食神': 'yes',
      '大运转七杀': 'no',
      '大运转劫财': 'no',
    },
    rawQuestion: '你 {age} 岁那年（{year}）有没有在创作、表达、生活情趣上明显放开来过，开始追求"自己想做的事"？',
  },
  {
    id: 'jiecai_partnership',
    triggerEvents: ['大运转劫财', '大运转比肩', '大运转正印'],
    variants: {
      '大运转劫财': 'yes',
      '大运转比肩': 'yes',
      '大运转正印': 'no',
    },
    rawQuestion: '你 {age} 岁那年（{year}）有没有跟朋友/同事/合伙人深度共事过，或者在合作里被对方分走了机会/资源？',
  },
  {
    id: 'yinxing_dependence',
    triggerEvents: ['大运转正印', '大运转偏印', '大运转伤官'],
    variants: {
      '大运转正印': 'yes',
      '大运转偏印': 'yes',
      '大运转伤官': 'no',
    },
    rawQuestion: '你 {age} 岁那年（{year}）有没有依赖过某个长辈/前辈/学习体系，或者重新回到学习、修养、慢生活的状态？',
  },
];
```

- [ ] **Step 3.5: 跑确认 pass**

Run: `npm test -- --testPathPattern=templates-dayun`
Expected: 3 passed

- [ ] **Step 3.6: 提交**

```bash
git add lib/calibration/templates/types.ts lib/calibration/templates/dayun.ts lib/calibration/__tests__/templates-dayun.test.ts
git commit -m "calibration: 模板类型 + 大运类 6 模板"
```

---

## Task 4：剩余模板（流年 4 + 兜底 2）+ 聚合 index

**Files:**
- Create: `lib/calibration/templates/liunian.ts`
- Create: `lib/calibration/templates/personality.ts`
- Create: `lib/calibration/templates/index.ts`
- Test: `lib/calibration/__tests__/templates-index.test.ts`

- [ ] **Step 4.1: 写 liunian.ts**

```ts
// lib/calibration/templates/liunian.ts
import type { QuestionTemplate } from './types';

export const LIUNIAN_TEMPLATES: QuestionTemplate[] = [
  {
    id: 'liunian_qisha_pressure',
    triggerEvents: ['流年七杀临身', '流年伤官见官', '流年正财动'],
    variants: {
      '流年七杀临身': 'yes',
      '流年伤官见官': 'no',
      '流年正财动': 'no',
    },
    rawQuestion: '你 {age} 岁那年（{year}）有没有突然被一件外部压力压过来，比如被裁员/重大考试/严重的家庭压力？',
  },
  {
    id: 'liunian_shangguan_official',
    triggerEvents: ['流年伤官见官', '流年七杀临身', '流年正财动'],
    variants: {
      '流年伤官见官': 'yes',
      '流年七杀临身': 'no',
      '流年正财动': 'no',
    },
    rawQuestion: '你 {age} 岁那年（{year}）有没有跟体制/权威/上级发生明显冲突，或者主动违反过某种规则？',
  },
  {
    id: 'liunian_wealth_action',
    triggerEvents: ['流年正财动', '流年七杀临身', '流年伤官见官'],
    variants: {
      '流年正财动': 'yes',
      '流年七杀临身': 'no',
      '流年伤官见官': 'no',
    },
    rawQuestion: '你 {age} 岁那年（{year}）在钱财或事业资源上有过明显的进项或重大投入吗？',
  },
  {
    id: 'liunian_kids_signal',
    triggerEvents: ['流年子女星动', '流年七杀临身', '流年正财动'],
    variants: {
      '流年子女星动': 'yes',
      '流年七杀临身': 'no',
      '流年正财动': 'no',
    },
    rawQuestion: '你 {age} 岁那年（{year}）跟孩子（或弟妹、晚辈）有过特别的事吗？怀孕、出生、教养转折之类。',
  },
];
```

- [ ] **Step 4.2: 写 personality.ts（兜底 2 个）**

```ts
// lib/calibration/templates/personality.ts
import type { QuestionTemplate } from './types';

/**
 * 兜底模板：当 bifurcation 没有可用年份事件时（极少见），
 * 退化到"性格倾向"问题。这两个模板的 trigger 是 'none'，
 * 由 Session 在事件用尽后强行注入，跟具体年份解耦。
 */
export const PERSONALITY_TEMPLATES: QuestionTemplate[] = [
  {
    id: 'persona_introversion',
    triggerEvents: ['none'],
    variants: { 'none': 'irrelevant' },
    rawQuestion: '你比较倾向独处+深思，还是喜欢热闹+表达？',
  },
  {
    id: 'persona_health_weak',
    triggerEvents: ['none'],
    variants: { 'none': 'irrelevant' },
    rawQuestion: '从小到大，你身体最容易出问题的是哪一块？比如脾胃、呼吸、肾水、肝气。',
  },
];
```

- [ ] **Step 4.3: 写 templates/index.ts**

```ts
// lib/calibration/templates/index.ts
import type { QuestionTemplate } from './types';
import type { BifurcatedYear, CandidateId, EventType } from '../types';
import { DAYUN_TEMPLATES } from './dayun';
import { LIUNIAN_TEMPLATES } from './liunian';
import { PERSONALITY_TEMPLATES } from './personality';

export const ALL_TEMPLATES: QuestionTemplate[] = [
  ...DAYUN_TEMPLATES,
  ...LIUNIAN_TEMPLATES,
  ...PERSONALITY_TEMPLATES,
];

/**
 * 给定一个分歧年份，找最合适的模板。
 * 评分 = 该模板 variants 中"非 irrelevant"且命中三个候选 eventType 的项数。
 */
export function findTemplate(bif: BifurcatedYear): QuestionTemplate | null {
  const eventVals = [bif.events.before, bif.events.origin, bif.events.after];

  let best: QuestionTemplate | null = null;
  let bestScore = 0;
  for (const tpl of [...DAYUN_TEMPLATES, ...LIUNIAN_TEMPLATES]) {
    let score = 0;
    for (const ev of eventVals) {
      const v = tpl.variants[ev];
      if (v && v !== 'irrelevant') score += 1;
    }
    if (score > bestScore) {
      bestScore = score;
      best = tpl;
    }
  }
  return bestScore >= 2 ? best : null;
}

export function fillTemplate(tpl: QuestionTemplate, year: number, age: number): string {
  return tpl.rawQuestion.replace(/\{year\}/g, String(year)).replace(/\{age\}/g, String(age));
}

/** 计算一次 classification 给三个候选造成的 delta。 */
export function deltaFromAnswer(
  tpl: QuestionTemplate,
  events: Record<CandidateId, EventType>,
  answer: 'yes' | 'no' | 'uncertain',
): Record<CandidateId, number> {
  const delta: Record<CandidateId, number> = { before: 0, origin: 0, after: 0 };
  if (answer === 'uncertain') return delta;
  for (const id of ['before', 'origin', 'after'] as CandidateId[]) {
    const expected = tpl.variants[events[id]];
    if (!expected || expected === 'irrelevant') continue;
    if (expected === answer) delta[id] += 1;
    else delta[id] -= 1;
  }
  return delta;
}
```

- [ ] **Step 4.4: 写 templates-index 测试**

```ts
// lib/calibration/__tests__/templates-index.test.ts
import { ALL_TEMPLATES, findTemplate, fillTemplate, deltaFromAnswer } from '../templates';
import type { BifurcatedYear } from '../types';

describe('templates index', () => {
  it('aggregates 12 templates with unique ids', () => {
    expect(ALL_TEMPLATES).toHaveLength(12);
    const ids = ALL_TEMPLATES.map(t => t.id);
    expect(new Set(ids).size).toBe(12);
  });

  it('findTemplate matches a 大运转七杀 vs 正官 vs 比肩 year', () => {
    const bif: BifurcatedYear = {
      year: 2014,
      ageAt: { before: 18, origin: 19, after: 20 },
      events: { before: '大运转七杀', origin: '大运转正官', after: '大运转比肩' },
      diversity: 3,
    };
    const tpl = findTemplate(bif);
    expect(tpl).not.toBeNull();
    expect(tpl!.id).toBe('qisha_role_shift');
  });

  it('returns null when fewer than 2 candidate events match the best template', () => {
    const bif: BifurcatedYear = {
      year: 2010,
      ageAt: { before: 15, origin: 15, after: 15 },
      events: { before: 'none', origin: '大运转七杀', after: 'none' },
      diversity: 2,
    };
    const tpl = findTemplate(bif);
    expect(tpl).toBeNull();
  });

  it('fillTemplate substitutes year and age', () => {
    const out = fillTemplate(ALL_TEMPLATES[0], 2014, 19);
    expect(out).toContain('2014');
    expect(out).toContain('19');
    expect(out).not.toContain('{');
  });

  it('deltaFromAnswer scores +1 for matching expected, -1 for opposite', () => {
    const tpl = ALL_TEMPLATES.find(t => t.id === 'qisha_role_shift')!;
    const events = { before: '大运转七杀', origin: '大运转正官', after: '大运转比肩' } as const;
    const d = deltaFromAnswer(tpl, events, 'yes');
    expect(d.before).toBe(1);    // 七杀 期望 yes，匹配
    expect(d.origin).toBe(-1);   // 正官 期望 no，不匹配
    expect(d.after).toBe(-1);    // 比肩 期望 no，不匹配
  });

  it('deltaFromAnswer returns zeros for uncertain', () => {
    const tpl = ALL_TEMPLATES[0];
    const events = { before: '大运转七杀', origin: '大运转正官', after: '大运转比肩' } as const;
    const d = deltaFromAnswer(tpl, events, 'uncertain');
    expect(d).toEqual({ before: 0, origin: 0, after: 0 });
  });
});
```

- [ ] **Step 4.5: 跑测试**

Run: `npm test -- --testPathPattern=templates`
Expected: 9 passed (3 dayun + 6 index)

- [ ] **Step 4.6: 提交**

```bash
git add lib/calibration/templates/ lib/calibration/__tests__/templates-index.test.ts
git commit -m "calibration: 流年/兜底模板 + index 聚合 + 匹配/打分函数"
```

---

## Task 5：Scoring + 终止条件

**Files:**
- Create: `lib/calibration/scoring.ts`
- Test: `lib/calibration/__tests__/scoring.test.ts`

- [ ] **Step 5.1: 写测试**

```ts
// lib/calibration/__tests__/scoring.test.ts
import { applyAnswer, checkTermination } from '../scoring';
import type { CalibrationSessionState } from '../types';

function makeSession(overrides: Partial<CalibrationSessionState> = {}): CalibrationSessionState {
  return {
    candidates: [{} as any, {} as any, {} as any],
    scores: { before: 0, origin: 0, after: 0 },
    history: [],
    bifurcations: [],
    consumedKeys: new Set(),
    round: 0,
    consecutiveUncertain: 0,
    status: 'asking',
    ...overrides,
  };
}

describe('applyAnswer', () => {
  it('updates scores by delta and increments round', () => {
    const s = makeSession();
    const next = applyAnswer(s, {
      templateId: 'qisha_role_shift',
      year: 2014,
      ageThen: 19,
      questionText: 'q',
      userAnswer: 'yes',
      classified: 'yes',
      delta: { before: 1, origin: -1, after: -1 },
    });
    expect(next.scores).toEqual({ before: 1, origin: -1, after: -1 });
    expect(next.round).toBe(1);
    expect(next.history).toHaveLength(1);
    expect(next.consecutiveUncertain).toBe(0);
  });

  it('increments consecutiveUncertain on uncertain', () => {
    const s = makeSession({ consecutiveUncertain: 1 });
    const next = applyAnswer(s, {
      templateId: 't',
      year: 2010,
      ageThen: 15,
      questionText: 'q',
      userAnswer: 'idk',
      classified: 'uncertain',
      delta: { before: 0, origin: 0, after: 0 },
    });
    expect(next.consecutiveUncertain).toBe(2);
  });

  it('resets consecutiveUncertain on yes', () => {
    const s = makeSession({ consecutiveUncertain: 1 });
    const next = applyAnswer(s, {
      templateId: 't', year: 2010, ageThen: 15, questionText: 'q',
      userAnswer: 'yes', classified: 'yes',
      delta: { before: 1, origin: 0, after: 0 },
    });
    expect(next.consecutiveUncertain).toBe(0);
  });
});

describe('checkTermination', () => {
  it('locks when max - second >= 2', () => {
    const s = makeSession({ scores: { before: 3, origin: 0, after: 0 }, round: 3 });
    const r = checkTermination(s);
    expect(r.status).toBe('locked');
    expect(r.lockedCandidate).toBe('before');
  });

  it('locks at round 5 with current top, ties break to origin', () => {
    const s = makeSession({ scores: { before: 1, origin: 1, after: 1 }, round: 5 });
    const r = checkTermination(s);
    expect(r.status).toBe('locked');
    expect(r.lockedCandidate).toBe('origin');
  });

  it('gives up on 2 consecutive uncertain', () => {
    const s = makeSession({ consecutiveUncertain: 2, round: 2 });
    const r = checkTermination(s);
    expect(r.status).toBe('gave_up');
  });

  it('continues asking otherwise', () => {
    const s = makeSession({ scores: { before: 1, origin: 0, after: 0 }, round: 2 });
    const r = checkTermination(s);
    expect(r.status).toBe('asking');
  });
});
```

- [ ] **Step 5.2: 跑确认 fail**

Run: `npm test -- --testPathPattern=scoring`
Expected: `Cannot find module '../scoring'`

- [ ] **Step 5.3: 写 scoring.ts**

```ts
// lib/calibration/scoring.ts
import type { CalibrationSessionState, CandidateId, AskedQuestion } from './types';

export function applyAnswer(
  session: CalibrationSessionState,
  q: AskedQuestion,
): CalibrationSessionState {
  const next: CalibrationSessionState = {
    ...session,
    scores: {
      before: session.scores.before + q.delta.before,
      origin: session.scores.origin + q.delta.origin,
      after: session.scores.after + q.delta.after,
    },
    history: [...session.history, q],
    round: session.round + 1,
    consecutiveUncertain: q.classified === 'uncertain'
      ? session.consecutiveUncertain + 1
      : 0,
    consumedKeys: new Set(session.consumedKeys).add(`${q.templateId}:${q.year}`),
  };
  return next;
}

export function checkTermination(
  session: CalibrationSessionState,
): { status: CalibrationSessionState['status']; lockedCandidate?: CandidateId } {
  // 优先 1：连续 2 轮 uncertain
  if (session.consecutiveUncertain >= 2) {
    return { status: 'gave_up' };
  }

  const sorted = (Object.entries(session.scores) as [CandidateId, number][])
    .sort((a, b) => b[1] - a[1]);
  const [top, second] = sorted;

  // 优先 2：分差 ≥ 2 → lock
  if (top[1] - second[1] >= 2) {
    return { status: 'locked', lockedCandidate: top[0] };
  }

  // 优先 3：满 5 轮强制 lock。平手时 origin 优先（保守），其次 before
  if (session.round >= 5) {
    const tieBreak: CandidateId[] = ['origin', 'before', 'after'];
    const winners = sorted.filter(([, sc]) => sc === top[1]).map(([id]) => id);
    const winner = tieBreak.find(t => winners.includes(t)) ?? top[0];
    return { status: 'locked', lockedCandidate: winner };
  }

  return { status: 'asking' };
}
```

- [ ] **Step 5.4: 跑测试**

Run: `npm test -- --testPathPattern=scoring`
Expected: 7 passed

- [ ] **Step 5.5: 提交**

```bash
git add lib/calibration/scoring.ts lib/calibration/__tests__/scoring.test.ts
git commit -m "calibration: scoring + 终止条件（locked/gave_up）"
```

---

## Task 6：CalibrationSession 状态机（mock AI）

**Files:**
- Create: `lib/calibration/CalibrationSession.ts`
- Test: `lib/calibration/__tests__/CalibrationSession.test.ts`

- [ ] **Step 6.1: 写测试**

```ts
// lib/calibration/__tests__/CalibrationSession.test.ts
import { CalibrationSession } from '../CalibrationSession';

const mockAI = {
  runRound: jest.fn(),
};

beforeEach(() => mockAI.runRound.mockReset());

describe('CalibrationSession', () => {
  it('starts with 3 candidates and emits first question', async () => {
    mockAI.runRound.mockResolvedValueOnce({ question: '你 19 岁那年（2014）是否…？' });
    const session = new CalibrationSession({ runRound: mockAI.runRound });
    const { firstQuestion, state } = await session.start({
      birthDate: new Date('1995-08-15T20:00:00+08:00'),
      gender: '男',
      longitude: 116.4,
    });
    expect(state.candidates).toHaveLength(3);
    expect(state.bifurcations.length).toBeGreaterThan(0);
    expect(firstQuestion).toContain('你');
  });

  it('locks when scores diverge by 2', async () => {
    mockAI.runRound
      .mockResolvedValueOnce({ question: 'Q1' })                          // start
      .mockResolvedValueOnce({ lastClassification: 'yes', question: 'Q2' })
      .mockResolvedValueOnce({ lastClassification: 'yes', question: 'Q3' });

    const session = new CalibrationSession({ runRound: mockAI.runRound });
    await session.start({ birthDate: new Date('1995-08-15T20:00:00+08:00'), gender: '男', longitude: 116.4 });

    // 强行注入对 'before' 偏向的 delta
    const r1 = await session.submitAnswerWithForcedDelta('在 19 岁那年我转学了', { before: 1, origin: 0, after: -1 });
    expect(r1.nextStep.type).toBe('next_question');
    const r2 = await session.submitAnswerWithForcedDelta('又有一次类似经历', { before: 1, origin: -1, after: 0 });
    // before=2, origin=-1, after=-1 → 差距 ≥ 2
    expect(r2.nextStep.type).toBe('locked');
    if (r2.nextStep.type === 'locked') {
      expect(r2.nextStep.correctedDate).toBeInstanceOf(Date);
    }
  });

  it('gives up after 2 consecutive uncertain', async () => {
    mockAI.runRound
      .mockResolvedValueOnce({ question: 'Q1' })
      .mockResolvedValueOnce({ lastClassification: 'uncertain', question: 'Q2' })
      .mockResolvedValueOnce({ lastClassification: 'uncertain', question: 'Q3' });

    const session = new CalibrationSession({ runRound: mockAI.runRound });
    await session.start({ birthDate: new Date('1995-08-15T20:00:00+08:00'), gender: '男', longitude: 116.4 });
    await session.submitAnswer('我不记得了');
    const r2 = await session.submitAnswer('也不记得');
    expect(r2.nextStep.type).toBe('gave_up');
  });
});
```

- [ ] **Step 6.2: 跑确认 fail**

Run: `npm test -- --testPathPattern=CalibrationSession`
Expected: `Cannot find module '../CalibrationSession'`

- [ ] **Step 6.3: 写 CalibrationSession.ts**

```ts
// lib/calibration/CalibrationSession.ts
import { buildCandidates } from './buildCandidates';
import { detectBifurcations } from './bifurcation';
import { findTemplate, fillTemplate, deltaFromAnswer } from './templates';
import { PERSONALITY_TEMPLATES } from './templates/personality';
import { applyAnswer, checkTermination } from './scoring';
import type {
  CalibrationSessionState, CandidateId, AskedQuestion, BifurcatedYear,
} from './types';
import type { QuestionTemplate } from './templates/types';

export interface AIRunner {
  runRound(input: {
    templateRaw: string;
    lastUserAnswer?: string;
  }): Promise<{ lastClassification?: 'yes' | 'no' | 'uncertain'; question: string }>;
}

export interface StartOptions {
  birthDate: Date;
  gender: '男' | '女';
  longitude: number;
}

export type NextStep =
  | { type: 'next_question'; question: string }
  | { type: 'locked'; correctedDate: Date; candidateId: CandidateId }
  | { type: 'gave_up'; reason: string };

export class CalibrationSession {
  private state!: CalibrationSessionState;
  private pendingTemplate: QuestionTemplate | null = null;
  private pendingBifurcation: BifurcatedYear | null = null;
  private pendingAge = 0;

  constructor(private ai: AIRunner) {}

  async start(opts: StartOptions): Promise<{ firstQuestion: string; state: CalibrationSessionState }> {
    const candidates = buildCandidates(opts.birthDate, opts.gender, opts.longitude);
    const bifurcations = detectBifurcations(candidates, new Date().getFullYear());

    this.state = {
      candidates,
      scores: { before: 0, origin: 0, after: 0 },
      history: [],
      bifurcations,
      consumedKeys: new Set(),
      round: 0,
      consecutiveUncertain: 0,
      status: 'asking',
    };

    const firstQuestion = await this.prepareNextQuestion();
    return { firstQuestion, state: this.state };
  }

  private pickNext(): { template: QuestionTemplate; bif: BifurcatedYear; age: number } | null {
    for (const bif of this.state.bifurcations) {
      const tpl = findTemplate(bif);
      if (!tpl) continue;
      const key = `${tpl.id}:${bif.year}`;
      if (this.state.consumedKeys.has(key)) continue;
      return { template: tpl, bif, age: bif.ageAt.origin };
    }
    // fallback: 性格模板（无年份），id 不重复用
    for (const tpl of PERSONALITY_TEMPLATES) {
      if (this.state.consumedKeys.has(`${tpl.id}:0`)) continue;
      return { template: tpl, bif: { year: 0, ageAt: { before: 0, origin: 0, after: 0 }, events: { before: 'none', origin: 'none', after: 'none' }, diversity: 0 }, age: 0 };
    }
    return null;
  }

  private async prepareNextQuestion(lastUserAnswer?: string): Promise<string> {
    const next = this.pickNext();
    if (!next) {
      // 模板用尽——按当前 scores 强制 lock
      const verdict = checkTermination({ ...this.state, round: 5 });
      this.state = { ...this.state, status: verdict.status, lockedCandidate: verdict.lockedCandidate };
      return ''; // 调用方应通过下一次 submitAnswer 检测
    }
    this.pendingTemplate = next.template;
    this.pendingBifurcation = next.bif;
    this.pendingAge = next.age;
    const raw = fillTemplate(next.template, next.bif.year, next.age);
    const aiOut = await this.ai.runRound({ templateRaw: raw, lastUserAnswer });
    return aiOut.question;
  }

  async submitAnswer(userText: string): Promise<{ classified: 'yes'|'no'|'uncertain'; nextStep: NextStep }> {
    if (!this.pendingTemplate || !this.pendingBifurcation) {
      throw new Error('CalibrationSession: no pending question');
    }
    const tpl = this.pendingTemplate;
    const bif = this.pendingBifurcation;

    const raw = fillTemplate(tpl, bif.year, this.pendingAge);
    const aiOut = await this.ai.runRound({ templateRaw: raw, lastUserAnswer: userText });
    const classified = aiOut.lastClassification ?? 'uncertain';

    return this.consume(classified, userText, aiOut.question);
  }

  /** 测试专用：跳过 AI 直接注入分类 + delta */
  async submitAnswerWithForcedDelta(
    userText: string,
    forcedDelta: Record<CandidateId, number>,
  ): Promise<{ classified: 'yes'|'no'|'uncertain'; nextStep: NextStep }> {
    if (!this.pendingTemplate || !this.pendingBifurcation) {
      throw new Error('CalibrationSession: no pending question');
    }
    // 推断 classification：delta 不全 0 视为 yes，否则 uncertain
    const sum = forcedDelta.before + forcedDelta.origin + forcedDelta.after;
    const classified: 'yes'|'no'|'uncertain' = sum === 0 ? 'uncertain' : 'yes';
    return this.consumeWithDelta(classified, userText, forcedDelta, '');
  }

  private async consume(classified: 'yes'|'no'|'uncertain', userText: string, nextQuestionText: string): Promise<{ classified: typeof classified; nextStep: NextStep }> {
    const tpl = this.pendingTemplate!;
    const bif = this.pendingBifurcation!;
    const delta = deltaFromAnswer(tpl, bif.events, classified);
    return this.consumeWithDelta(classified, userText, delta, nextQuestionText);
  }

  private async consumeWithDelta(
    classified: 'yes'|'no'|'uncertain',
    userText: string,
    delta: Record<CandidateId, number>,
    nextQuestionText: string,
  ): Promise<{ classified: typeof classified; nextStep: NextStep }> {
    const tpl = this.pendingTemplate!;
    const bif = this.pendingBifurcation!;
    const q: AskedQuestion = {
      templateId: tpl.id,
      year: bif.year,
      ageThen: this.pendingAge,
      questionText: fillTemplate(tpl, bif.year, this.pendingAge),
      userAnswer: userText,
      classified,
      delta,
    };
    this.state = applyAnswer(this.state, q);
    const verdict = checkTermination(this.state);
    this.state = { ...this.state, status: verdict.status, lockedCandidate: verdict.lockedCandidate };

    if (verdict.status === 'locked') {
      const winner = this.state.candidates.find(c => c.id === verdict.lockedCandidate)!;
      return { classified, nextStep: { type: 'locked', correctedDate: winner.birthDate, candidateId: winner.id } };
    }
    if (verdict.status === 'gave_up') {
      return { classified, nextStep: { type: 'gave_up', reason: '连续 2 轮无法判断' } };
    }
    // 否则继续问
    const question = nextQuestionText || (await this.prepareNextQuestion(userText));
    if (this.state.status !== 'asking') {
      // prepareNextQuestion 内部可能因为模板用尽强制 lock
      const winner = this.state.candidates.find(c => c.id === this.state.lockedCandidate);
      if (winner) return { classified, nextStep: { type: 'locked', correctedDate: winner.birthDate, candidateId: winner.id } };
      return { classified, nextStep: { type: 'gave_up', reason: '题库用尽' } };
    }
    return { classified, nextStep: { type: 'next_question', question } };
  }

  getState(): CalibrationSessionState {
    return this.state;
  }
}
```

- [ ] **Step 6.4: 跑测试**

Run: `npm test -- --testPathPattern=CalibrationSession`
Expected: 3 passed

- [ ] **Step 6.5: 提交**

```bash
git add lib/calibration/CalibrationSession.ts lib/calibration/__tests__/CalibrationSession.test.ts
git commit -m "calibration: Session 状态机（mock AI 可单测）"
```

---

## Task 7：CalibrationAI（单 LLM call，JSON mode）

**Files:**
- Create: `lib/calibration/CalibrationAI.ts`
- Test: `lib/calibration/__tests__/CalibrationAI.test.ts`

参考 `lib/ai/chat.ts` 既有的 provider 配置读取方式。

- [ ] **Step 7.1: 写测试**

```ts
// lib/calibration/__tests__/CalibrationAI.test.ts
import { parseAIResponse, CALIBRATION_SYSTEM_PROMPT } from '../CalibrationAI';

describe('parseAIResponse', () => {
  it('parses well-formed JSON', () => {
    const r = parseAIResponse('{"lastClassification":"yes","question":"你今年呢？"}', '原模板');
    expect(r.lastClassification).toBe('yes');
    expect(r.question).toBe('你今年呢？');
  });

  it('falls back to template raw when JSON invalid', () => {
    const r = parseAIResponse('not json', '原模板');
    expect(r.lastClassification).toBe('uncertain');
    expect(r.question).toBe('原模板');
  });

  it('falls back when classification is unknown enum', () => {
    const r = parseAIResponse('{"lastClassification":"maybe","question":"q"}', '原');
    expect(r.lastClassification).toBe('uncertain');
    expect(r.question).toBe('q');
  });

  it('treats null lastClassification as undefined (first round)', () => {
    const r = parseAIResponse('{"lastClassification":null,"question":"首题？"}', '首题');
    expect(r.lastClassification).toBeUndefined();
    expect(r.question).toBe('首题？');
  });
});

describe('CALIBRATION_SYSTEM_PROMPT', () => {
  it('contains required keywords', () => {
    expect(CALIBRATION_SYSTEM_PROMPT).toContain('校准');
    expect(CALIBRATION_SYSTEM_PROMPT).toContain('JSON');
    expect(CALIBRATION_SYSTEM_PROMPT).toContain('lastClassification');
    expect(CALIBRATION_SYSTEM_PROMPT).toContain('question');
  });
});
```

- [ ] **Step 7.2: 跑确认 fail**

Run: `npm test -- --testPathPattern=CalibrationAI`
Expected: `Cannot find module '../CalibrationAI'`

- [ ] **Step 7.3: 写 CalibrationAI.ts**

```ts
// lib/calibration/CalibrationAI.ts
import { fetch as expoFetch } from 'expo/fetch';
import { useUserStore } from '@/lib/store/userStore';
import type { AIRunner } from './CalibrationSession';

export const CALIBRATION_SYSTEM_PROMPT = `你是命理师，正在用过去事件帮用户校准出生时辰。

每轮我会给你一个事件模板和年份。你的任务：

1. 如果有上一轮的用户答案，先把它归类：
   - "yes"：用户明确说发生过
   - "no"：用户明确说没有发生
   - "uncertain"：用户说不记得 / 不知道 / 含糊 / 模棱两可
2. 把新模板改写成 1-2 句自然问句。不要解释命盘原理，不要说"根据您的命盘"，直接问事件，温和但不啰嗦。

返回严格的 JSON 格式：
{"lastClassification": "yes" | "no" | "uncertain" | null, "question": "<你的问句>"}

首轮（没有用户答案）的 lastClassification 必须为 null。`;

interface AIOutput {
  lastClassification?: 'yes' | 'no' | 'uncertain';
  question: string;
}

export function parseAIResponse(raw: string, fallbackTemplate: string): AIOutput {
  try {
    const obj = JSON.parse(raw);
    const cls = obj.lastClassification;
    const validCls: 'yes'|'no'|'uncertain'|undefined =
      cls === 'yes' || cls === 'no' || cls === 'uncertain' ? cls :
      cls === null || cls === undefined ? undefined :
      'uncertain';   // 未知 enum → uncertain
    const question = typeof obj.question === 'string' && obj.question.length > 0
      ? obj.question
      : fallbackTemplate;
    if (cls && cls !== 'yes' && cls !== 'no' && cls !== 'uncertain' && cls !== null) {
      // 非已知枚举 + question 仍可信 → 保留 question 但 cls 降为 uncertain
      return { lastClassification: 'uncertain', question };
    }
    return { lastClassification: validCls, question };
  } catch {
    return { lastClassification: 'uncertain', question: fallbackTemplate };
  }
}

interface ProviderConfig {
  provider: 'openai' | 'deepseek' | 'anthropic' | 'custom';
  baseUrl: string;
  apiKey: string;
  model: string;
}

function readProviderConfig(): ProviderConfig | null {
  const u = useUserStore.getState();
  if (!u.apiProvider || !u.apiKey || !u.apiModel) return null;
  const baseUrl = u.apiBaseUrl ?? defaultBaseUrl(u.apiProvider);
  return {
    provider: u.apiProvider,
    baseUrl,
    apiKey: u.apiKey,
    model: u.apiModel,
  };
}

function defaultBaseUrl(p: 'openai' | 'deepseek' | 'anthropic' | 'custom'): string {
  switch (p) {
    case 'openai': return 'https://api.openai.com/v1';
    case 'deepseek': return 'https://api.deepseek.com/v1';
    case 'anthropic': return 'https://api.anthropic.com/v1';
    case 'custom': return '';
  }
}

async function callOnce(cfg: ProviderConfig, userMsg: string): Promise<string> {
  const url = `${cfg.baseUrl.replace(/\/$/, '')}/chat/completions`;
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${cfg.apiKey}`,
  };
  const body = {
    model: cfg.model,
    messages: [
      { role: 'system', content: CALIBRATION_SYSTEM_PROMPT },
      { role: 'user', content: userMsg },
    ],
    response_format: { type: 'json_object' },
    stream: false,
    temperature: 0.3,
  };
  const res = await expoFetch(url, { method: 'POST', headers, body: JSON.stringify(body) });
  if (!res.ok) throw new Error(`AI HTTP ${res.status}`);
  const data = await res.json();
  return data.choices?.[0]?.message?.content ?? '';
}

export const calibrationAI: AIRunner = {
  async runRound({ templateRaw, lastUserAnswer }) {
    const cfg = readProviderConfig();
    if (!cfg) {
      // 未配置 provider，直接 fallback 模板原文
      return { question: templateRaw };
    }
    const userMsg = lastUserAnswer
      ? `上一轮用户答案：${lastUserAnswer}\n\n本轮模板：${templateRaw}`
      : `本轮模板（首轮，无用户答案）：${templateRaw}`;
    let lastErr: unknown;
    for (let attempt = 0; attempt < 2; attempt++) {
      try {
        const raw = await callOnce(cfg, userMsg);
        return parseAIResponse(raw, templateRaw);
      } catch (e) {
        lastErr = e;
      }
    }
    console.warn('[CalibrationAI] all retries failed:', lastErr);
    return { lastClassification: 'uncertain', question: templateRaw };
  },
};
```

- [ ] **Step 7.4: 跑测试**

Run: `npm test -- --testPathPattern=CalibrationAI`
Expected: 5 passed

- [ ] **Step 7.5: 提交**

```bash
git add lib/calibration/CalibrationAI.ts lib/calibration/__tests__/CalibrationAI.test.ts
git commit -m "calibration: AI 单次 JSON-mode 调用 + 容错 + 重试"
```

---

## Task 8：UI——ThinkingDots + CalibrationSheet

**Files:**
- Create: `components/calibration/ThinkingDots.tsx`
- Create: `components/calibration/CalibrationSheet.tsx`

视觉规范严格沿用 `components/ai/FullReasoningSheet.tsx` 的 Modal/backdrop 模式 + `lib/design/tokens` 里的 Color/Space/Radius/Type/Shadow。

- [ ] **Step 8.1: 写 ThinkingDots.tsx**

```tsx
// components/calibration/ThinkingDots.tsx
import React, { useEffect } from 'react';
import { View, StyleSheet } from 'react-native';
import Animated, { useSharedValue, useAnimatedStyle, withRepeat, withSequence, withTiming } from 'react-native-reanimated';
import { Colors, Space } from '@/lib/design/tokens';

const Dot = ({ delay }: { delay: number }) => {
  const opacity = useSharedValue(0.2);
  useEffect(() => {
    opacity.value = withRepeat(
      withSequence(
        withTiming(1, { duration: 400 }),
        withTiming(0.2, { duration: 400 }),
      ),
      -1,
      false,
    );
  }, [opacity]);
  const style = useAnimatedStyle(() => ({ opacity: opacity.value }));
  return <Animated.View style={[styles.dot, style, { marginLeft: delay > 0 ? 4 : 0 }]} />;
};

export function ThinkingDots() {
  return (
    <View style={styles.row}>
      <Dot delay={0} />
      <Dot delay={1} />
      <Dot delay={2} />
    </View>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: 'row', alignItems: 'center', paddingVertical: Space.xs },
  dot: { width: 6, height: 6, borderRadius: 3, backgroundColor: Colors.inkSecondary },
});
```

- [ ] **Step 8.2: 写 CalibrationSheet.tsx**

```tsx
// components/calibration/CalibrationSheet.tsx
import React, { useEffect, useRef, useState, useCallback } from 'react';
import {
  Modal, View, Text, Pressable, ScrollView, TextInput, StyleSheet, KeyboardAvoidingView, Platform,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Colors, Space, Radius, Type, Shadow } from '@/lib/design/tokens';
import { useUserStore } from '@/lib/store/userStore';
import { CalibrationSession, type NextStep } from '@/lib/calibration/CalibrationSession';
import { calibrationAI } from '@/lib/calibration/CalibrationAI';
import { ThinkingDots } from './ThinkingDots';

interface ChatLine {
  role: 'ai' | 'user';
  text: string;
}

const SHICHEN_LABEL: Record<number, { name: string; range: string }> = {
  0:  { name: '子时', range: '23:00–01:00' },  2:  { name: '丑时', range: '01:00–03:00' },
  4:  { name: '寅时', range: '03:00–05:00' },  6:  { name: '卯时', range: '05:00–07:00' },
  8:  { name: '辰时', range: '07:00–09:00' },  10: { name: '巳时', range: '09:00–11:00' },
  12: { name: '午时', range: '11:00–13:00' },  14: { name: '未时', range: '13:00–15:00' },
  16: { name: '申时', range: '15:00–17:00' },  18: { name: '酉时', range: '17:00–19:00' },
  20: { name: '戌时', range: '19:00–21:00' },  22: { name: '亥时', range: '21:00–23:00' },
};

interface Props {
  visible: boolean;
  onClose: () => void;
}

export function CalibrationSheet({ visible, onClose }: Props) {
  const insets = useSafeAreaInsets();
  const u = useUserStore();
  const setBirthDate = useUserStore(s => s.setBirthDate);
  const scrollRef = useRef<ScrollView>(null);
  const sessionRef = useRef<CalibrationSession | null>(null);

  const [lines, setLines] = useState<ChatLine[]>([]);
  const [input, setInput] = useState('');
  const [thinking, setThinking] = useState(false);
  const [done, setDone] = useState(false);

  const append = useCallback((line: ChatLine) => {
    setLines(prev => [...prev, line]);
    setTimeout(() => scrollRef.current?.scrollToEnd({ animated: true }), 50);
  }, []);

  // 打开时启动 session
  useEffect(() => {
    if (!visible) return;
    if (!u.birthDate || !u.gender || u.birthLongitude == null) {
      append({ role: 'ai', text: '需要先在"我的"里填写生辰、性别和出生地。' });
      setDone(true);
      return;
    }
    setLines([]);
    setDone(false);
    setInput('');
    const start = async () => {
      setThinking(true);
      const session = new CalibrationSession(calibrationAI);
      sessionRef.current = session;
      try {
        const { firstQuestion } = await session.start({
          birthDate: new Date(u.birthDate!),
          gender: u.gender!,
          longitude: u.birthLongitude!,
        });
        append({ role: 'ai', text: '我会问你 3-5 个过去发生过的事件，帮你校准出生时辰。' });
        append({ role: 'ai', text: firstQuestion });
      } catch (e) {
        append({ role: 'ai', text: '启动校准时出错。可以稍后再试。' });
        setDone(true);
      } finally {
        setThinking(false);
      }
    };
    start();
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [visible]);

  const handleResult = (step: NextStep) => {
    if (step.type === 'next_question') {
      append({ role: 'ai', text: step.question });
    } else if (step.type === 'locked') {
      const hour = step.correctedDate.getHours();
      const label = SHICHEN_LABEL[hour] ?? { name: '?时', range: '' };
      setBirthDate(step.correctedDate);
      append({ role: 'ai', text: `已校准为${label.name}（${label.range}），命盘已更新。` });
      setDone(true);
    } else {
      append({ role: 'ai', text: '信息不够，无法确定时辰。可换个时间再试。' });
      setDone(true);
    }
  };

  const send = async () => {
    const text = input.trim();
    if (!text || thinking || done) return;
    if (text.length > 200) {
      append({ role: 'ai', text: '请简短一点，控制在 200 字以内。' });
      return;
    }
    if (!sessionRef.current) return;
    append({ role: 'user', text });
    setInput('');
    setThinking(true);
    try {
      const r = await sessionRef.current.submitAnswer(text);
      handleResult(r.nextStep);
    } catch (e) {
      append({ role: 'ai', text: '网络异常，请稍后重试。' });
    } finally {
      setThinking(false);
    }
  };

  return (
    <Modal visible={visible} animationType="slide" transparent onRequestClose={onClose}>
      <Pressable style={styles.backdrop} onPress={onClose} />
      <View style={[styles.sheet, { paddingBottom: insets.bottom }]}>
        <View style={styles.handle} />
        <View style={styles.header}>
          <Text style={styles.title}>校准时辰</Text>
          <Pressable onPress={onClose} hitSlop={12}><Text style={styles.close}>✕</Text></Pressable>
        </View>
        <KeyboardAvoidingView style={styles.body} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
          <ScrollView ref={scrollRef} contentContainerStyle={styles.messages}>
            {lines.map((l, i) => (
              <View key={i} style={[styles.bubbleRow, l.role === 'user' ? styles.userRow : styles.aiRow]}>
                <View style={[styles.bubble, l.role === 'user' ? styles.userBubble : styles.aiBubble]}>
                  <Text style={l.role === 'user' ? styles.userText : styles.aiText}>{l.text}</Text>
                </View>
              </View>
            ))}
            {thinking && (
              <View style={[styles.bubbleRow, styles.aiRow]}>
                <View style={[styles.bubble, styles.aiBubble]}>
                  <ThinkingDots />
                </View>
              </View>
            )}
          </ScrollView>
          <View style={styles.inputRow}>
            <TextInput
              style={[styles.input, done && styles.inputDisabled]}
              placeholder={done ? '校准已结束' : '输入你的回答…'}
              placeholderTextColor={Colors.inkTertiary}
              value={input}
              onChangeText={setInput}
              editable={!done}
              maxLength={250}
              onSubmitEditing={send}
              returnKeyType="send"
            />
            <Pressable
              onPress={send}
              disabled={done || thinking || !input.trim()}
              style={[styles.sendBtn, (done || thinking || !input.trim()) && styles.sendBtnDisabled]}
            >
              <Text style={styles.sendText}>发送</Text>
            </Pressable>
          </View>
        </KeyboardAvoidingView>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  backdrop: { ...StyleSheet.absoluteFillObject, backgroundColor: 'rgba(0,0,0,0.4)' },
  sheet: {
    position: 'absolute', left: 0, right: 0, bottom: 0,
    height: '85%',
    backgroundColor: Colors.surface,
    borderTopLeftRadius: Radius.lg, borderTopRightRadius: Radius.lg,
    ...Shadow.md,
  },
  handle: {
    width: 36, height: 4, alignSelf: 'center',
    marginTop: Space.sm, marginBottom: Space.sm,
    backgroundColor: Colors.border, borderRadius: 2,
  },
  header: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
    paddingHorizontal: Space.base, paddingBottom: Space.sm,
    borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: Colors.border,
  },
  title: { ...Type.titleSmall, color: Colors.ink },
  close: { ...Type.titleSmall, color: Colors.inkSecondary },
  body: { flex: 1 },
  messages: { padding: Space.base, gap: Space.sm },
  bubbleRow: { flexDirection: 'row' },
  aiRow: { justifyContent: 'flex-start' },
  userRow: { justifyContent: 'flex-end' },
  bubble: { maxWidth: '80%', padding: Space.sm, borderRadius: Radius.md },
  aiBubble: { backgroundColor: Colors.surfaceMuted, borderTopLeftRadius: Radius.sm },
  userBubble: { backgroundColor: Colors.accent, borderTopRightRadius: Radius.sm },
  aiText: { ...Type.body, color: Colors.ink },
  userText: { ...Type.body, color: Colors.surface },
  inputRow: {
    flexDirection: 'row', alignItems: 'center', gap: Space.sm,
    paddingHorizontal: Space.base, paddingVertical: Space.sm,
    borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: Colors.border,
  },
  input: {
    flex: 1, paddingHorizontal: Space.sm, paddingVertical: Space.xs,
    borderRadius: Radius.sm, backgroundColor: Colors.surfaceMuted,
    ...Type.body, color: Colors.ink,
  },
  inputDisabled: { opacity: 0.5 },
  sendBtn: {
    paddingHorizontal: Space.base, paddingVertical: Space.xs,
    borderRadius: Radius.sm, backgroundColor: Colors.accent,
  },
  sendBtnDisabled: { opacity: 0.4 },
  sendText: { ...Type.body, color: Colors.surface, fontWeight: '600' },
});
```

- [ ] **Step 8.3: 跑 TypeCheck**

Run: `npx tsc --noEmit`
Expected: 0 errors

> 如果 `Colors.surfaceMuted` 或 `Colors.accent` 不存在于现有 tokens（请先 `grep -n 'export ' lib/design/tokens.ts` 核对），用最接近的现有 token 替换；不要新增 token，单独建 token 不在本期范围。

- [ ] **Step 8.4: 提交**

```bash
git add components/calibration/
git commit -m "calibration/ui: ThinkingDots + CalibrationSheet（Modal + 内联 chat）"
```

---

## Task 9：Profile 入口 + 集成

**Files:**
- Modify: `app/(tabs)/profile.tsx`

> 由于 profile.tsx 当前结构未知，本任务步骤先 Read 该文件再做最小侵入式修改：在生辰展示行下方加"校准时辰"行 + visible state。

- [ ] **Step 9.1: 读 profile.tsx 找到生辰展示位**

Run: `grep -n "birthDate\|生辰\|出生\|onboarding" app/\(tabs\)/profile.tsx | head -10`
Expected: 至少能定位到展示生辰的 Text/View

- [ ] **Step 9.2: 加入口行 + sheet visible state**

在 profile.tsx 的 imports 顶部加：
```ts
import { useState } from 'react';
import { CalibrationSheet } from '@/components/calibration/CalibrationSheet';
```

在组件内 state 段（与 useUserStore 同区）加：
```ts
const [calibrationVisible, setCalibrationVisible] = useState(false);
const canCalibrate = !!u.birthDate && !!u.gender && u.birthLongitude != null && !!u.apiKey;
```

在生辰展示行下方加一行（用文件本身的 Row/SettingsRow 组件，跟随现有风格；如无现成组件，使用相同 StyleSheet.row）：
```tsx
<Pressable
  onPress={() => canCalibrate && setCalibrationVisible(true)}
  disabled={!canCalibrate}
  style={[styles.row, !canCalibrate && styles.rowDisabled]}
>
  <Text style={styles.rowLabel}>校准时辰</Text>
  <Text style={styles.rowHint}>
    {canCalibrate ? '→' : !u.birthDate ? '先填生辰' : !u.apiKey ? '先在设置里配置 AI' : ''}
  </Text>
</Pressable>
```

在 return 的最外层 View 末尾（关闭 tag 前）挂载 sheet：
```tsx
<CalibrationSheet visible={calibrationVisible} onClose={() => setCalibrationVisible(false)} />
```

如 profile.tsx 有 `styles.rowDisabled` / `rowHint` / `rowLabel` 之外的命名，照搬现有命名，不新建。如需要新增样式，加最小集合：
```ts
rowDisabled: { opacity: 0.4 },
rowHint: { ...Type.caption, color: Colors.inkTertiary },
```

- [ ] **Step 9.3: TypeCheck + 全量测试**

Run: `npx tsc --noEmit && npm test -- --runInBand`
Expected: tsc 0 errors，测试 0 fail（现有 + 校准新增 ~25 个）

- [ ] **Step 9.4: 提交**

```bash
git add app/\(tabs\)/profile.tsx
git commit -m "calibration: profile 加入口行 + sheet 挂载"
```

---

## Task 10：集成测试 + 文档 + 手测矩阵

**Files:**
- Create: `lib/calibration/__tests__/integration.test.ts`
- Modify: `docs/PRD.md`（加 Phase 4 短描述）
- Modify: `docs/TASKS.md`（加 Phase 4 任务列表 + 标记完成）

- [ ] **Step 10.1: 写集成测试（用真实引擎 + mock AI）**

```ts
// lib/calibration/__tests__/integration.test.ts
import { CalibrationSession } from '../CalibrationSession';

describe('CalibrationSession integration with real engines', () => {
  it('runs to locked status with deterministic forced deltas', async () => {
    const ai = {
      runRound: jest.fn().mockResolvedValue({ question: 'mock-q' }),
    };
    const session = new CalibrationSession(ai);
    await session.start({
      birthDate: new Date('1995-08-15T20:00:00+08:00'),
      gender: '男',
      longitude: 116.4,
    });
    // 强行让 'before' 拿到 +2 分
    const r1 = await session.submitAnswerWithForcedDelta('a', { before: 1, origin: 0, after: 0 });
    expect(r1.nextStep.type).toBe('next_question');
    const r2 = await session.submitAnswerWithForcedDelta('b', { before: 1, origin: 0, after: 0 });
    expect(r2.nextStep.type).toBe('locked');
    if (r2.nextStep.type === 'locked') {
      expect(r2.nextStep.candidateId).toBe('before');
    }
  });

  it('reaches 5-round cap and locks origin on three-way tie', async () => {
    const ai = { runRound: jest.fn().mockResolvedValue({ question: 'q' }) };
    const session = new CalibrationSession(ai);
    await session.start({
      birthDate: new Date('1995-08-15T20:00:00+08:00'),
      gender: '男', longitude: 116.4,
    });
    let last: any;
    for (let i = 0; i < 5; i++) {
      last = await session.submitAnswerWithForcedDelta(`a${i}`, { before: 0, origin: 0, after: 0 });
    }
    expect(last.nextStep.type).toBe('gave_up');
    // 全 0 delta 的 classification 是 uncertain，连续 5 轮 → 第 2 轮就 gave_up
  });
});
```

> 注：第二个测试期望第 2 轮就 gave_up（连续 2 uncertain）。这是预期行为。

- [ ] **Step 10.2: 跑确认 pass**

Run: `npm test -- --testPathPattern=calibration`
Expected: 全部 calibration 相关测试通过（30+ 个）

- [ ] **Step 10.3: 更新 PRD.md**

在 PRD.md 的 "Phase 路线图" 段（如有）加一行：
```
| Phase 4 | 出生时辰校准（"我的"内嵌 chat 校时） | ✅ |
```

如 PRD 没有这种表格，在文档末尾加一段：
```markdown
## Phase 4 — 时辰校准（2026-04）

用户在"我的"页面打开 chat 式 BottomSheet，回答 3-5 个事件鉴别问题。
程序排出 ±1 时辰共 3 个候选盘，AI 把模板改写成自然问句、判类用户答案，
最终覆盖式更新 birthDate。规则全部确定性，AI 仅做语言层。
```

- [ ] **Step 10.4: 更新 TASKS.md**

在 Phase 4 段加：
```markdown
## Phase 4 — 出生时辰校准

- [x] T1 引擎 types + 候选盘构造
- [x] T2 事件向量提取 + bifurcation detector
- [x] T3 大运类 6 模板
- [x] T4 流年/兜底模板 + index
- [x] T5 scoring + 终止条件
- [x] T6 CalibrationSession 状态机
- [x] T7 CalibrationAI（JSON mode）
- [x] T8 ThinkingDots + CalibrationSheet
- [x] T9 profile 入口 + 挂载
- [x] T10 集成测试 + 文档 + 手测
```

- [ ] **Step 10.5: 手测矩阵**

设备：用户已配置好 Xcode signing 的真机。用 `EXPO_PUBLIC_BUILD_SHA=$(git rev-parse --short HEAD) npx expo run:ios --device <UDID> --configuration Release`。

清单：
1. 已填生辰 + 配置过 AI 的用户：profile 点"校准时辰"→ Sheet 弹出 → 完成 5 轮 → 看到"已校准为 X 时" → 关闭 → 进命盘看时辰已更新 ✓
2. 没填生辰用户：入口显示"先填生辰"，点击不响应 ✓
3. 没配 AI 用户：入口显示"先在设置里配置 AI" ✓
4. 中途关闭 → 重开 → 全新 session ✓
5. 连续答"我不记得" → gave_up，birthDate 不变 ✓
6. 飞行模式打开后发送：sheet 内显示"网络异常，请稍后重试"，可继续问 ✓
7. 输入 > 200 字：提示控制简短，不发送 ✓

把手测结果（哪几条 ✓ / ✗）作为提交说明的一部分。

- [ ] **Step 10.6: 全量验证 + 提交**

Run: `npx tsc --noEmit && npm test -- --runInBand --silent`
Expected: 0 errors / 0 fails

```bash
git add lib/calibration/__tests__/integration.test.ts docs/PRD.md docs/TASKS.md
git commit -m "calibration: 集成测试 + PRD/TASKS 更新（Phase 4 完成）"
```

---

## Self-Review

- **Spec coverage**：12 个任务覆盖 spec 的 §3 数据流、§4 引擎层（含 ADR-1 ±1 时辰、ADR-2 程序确定性）、§5 AI 层（含 ADR-3 单 LLM call）、§6 UI、§7 持久化（含 ADR-4 覆盖式）、§8 失败兜底、§9 测试。ADR-5 旁路通道由 CalibrationAI 不进 orchestrator 体现。spec §10 列出的"不在 MVP 范围"（紫微大限、校准历史、可视化等）本计划未触碰，正确。
- **Placeholder 扫描**：无 TBD/TODO；每个 step 含可执行命令或完整代码块。Task 9 步骤 9.2 包含基于代码 grep 结果的最小侵入修改而非伪代码。Step 8.3 提到的 token fallback 是显式 fallback 指令而非 placeholder。
- **类型一致性**：`CandidateId`、`EventType`、`AskedQuestion`、`CalibrationSessionState`、`NextStep` 在 types.ts 与下游所有文件签名一致；`AIRunner.runRound` 输入输出与 CalibrationAI 实现一致；`buildCandidates` 返回 `[Candidate, Candidate, Candidate]` tuple 与 Session start 接收处一致。

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-04-26-time-calibration.md`. 两种执行方式：

**1. Subagent-Driven（推荐）** — 每个 Task 派一个 subagent，spec compliance + code quality 两段 review，fast iteration
**2. Inline Execution** — 在当前 session 顺序执行，每两三个 task 后 checkpoint

哪种？
