# 设计文档：出生时辰校准（Phase 4）

**日期**：2026-04-26
**作者**：通过 superpowers:brainstorming 与 Claude 协作产出
**范围**：在"我的"页面加一个 chat 式的出生时辰校准入口
**性质**：功能扩展（旁路通道），不改动现有 AI orchestration 主链

---

## 1. 背景

### 1.1 问题

SUJI 的命理推演（八字 / 紫微 / 六爻 / 奇门）都依赖用户在 onboarding 填的 `birthDate`。但真实用户场景中：

- 大部分人不确定出生时辰是否精确（医院记录可能粗略，长辈口述常有 ±1-2 小时误差）
- 紫微盘对时辰极敏感（差一个时辰，命宫主星可能完全不同）
- 八字时柱不准 → 时上十神、子女宫、晚年运全部跑偏
- 用户感受到"AI 解读不准"时往往把锅扣在 AI 身上，但根因是输入有偏差

竞品调研发现，传统命理师面诊时也会用"过去事件回推"的方式校时——这是行业里的成熟做法，但移动端产品几乎没人做。如果做了，准度会有显著提升，且这个仪式本身就是用户体验的一部分。

### 1.2 路线图位置

| Phase | 范围 | 状态 |
|---|---|---|
| Phase 1 | 八字 + 紫微 + 编排 | ✅ |
| Phase 2 | 六爻 | ✅ |
| Phase 3 | 奇门遁甲 | ✅ |
| **Phase 4（本 spec）** | **出生时辰校准** | 进行中 |
| Phase 5 | 合婚规则库（rules-as-tool pilot） | 排期 |

校准是后续所有命理升级的"地基修补"——不修这块，其它优化收益打折。

---

## 2. 设计决策（ADR）

### ADR-1：候选时辰范围 = ±1 时辰（3 个候选）

**决策**：用户填的时辰为基准，候选只取相邻前后两个时辰（共 3 个候选盘）。

**理由**：
- 多数用户的真实场景是"大概知道但不确定准不准"，±1 时辰能覆盖
- 5 个候选要 6-8 个鉴别问题，体感拉长
- 全 12 时辰扫描适用于"完全不知道几点"，应单独做"未知时辰"分支，不混入主流程

**未来**：如果用户反馈 ±1 不够，可在 v2 加"扩展校准"按钮跳到 ±2 / 全扫描。

### ADR-2：程序确定性 + AI 叙述层（不让 AI 主导）

**决策**：bifurcation detection、scoring、状态机全部程序实现；LLM 只做"模板 → 自然问句"和"用户答案 → yes/no/uncertain"。

**理由**：
- AI 主导会编年份（hallucinate 大运边界）、给两次相同输入可能给不同结论
- 程序逻辑可单测、可审计
- 跟 SUJI 现有"工具确定 + AI 翻译"哲学一致

### ADR-3：每轮 1 次 LLM 调用（不拆 phraser/classifier）

**决策**：每轮一次 LLM 调用，同时做"判类上轮答案 + 出新问题"两件事。

**理由**：
- 拆 2 个 call 增加延迟、复杂度，没有相应收益
- 用 JSON mode 一次返回 `{lastClassification, question}`，程序拿前者更新分数、后者渲染给 UI
- JSON 单次响应 <500ms，加"思考中..."短动画即可，不需要流式 JSON 解析

### ADR-4：覆盖式更新 birthDate（不留原值）

**决策**：`locked` 时直接 overwrite `useUserStore.birthDate`（store 里实际字段名），不新增 `calibratedBirthDate` 字段。

**理由**：
- 用户后续校准都从最新 birthDate 出发，不需要"原值"概念
- 不污染 schema，不改 Supabase profiles 表（profileSync 自动跟随）
- "随时可再校准"已经是用户出口，无需在 UI 显式区分"原 / 校准后"

### ADR-5：旁路通道，不进 orchestrator

**决策**：校准是独立 chat session，不复用 THINKER / INTERPRETER prompt、不进 `lib/ai/tools/orchestrator.ts`。

**理由**：
- 校准的目标是"问 → 答 → 判 → 问"循环，不是命理推演
- 如果接入 orchestrator，主对话和校准对话的 message stream 会混淆
- 独立通道便于将来调整（例如换更便宜的 model 给 classifier 任务）

---

## 3. 整体数据流

```
用户在"我的"点 校准
       ↓
打开 BottomSheet
  → CalibrationSession.start(currentBirthDate, gender, longitude)
       ↓
程序：排出 3 个候选盘（八字 + 紫微）→ 找最分歧年份 → 选首题模板
       ↓
LLM call 1：模板 → 自然问句 (JSON: {question})
       ↓
渲染 question 到 chat
       ↓
用户输入答案
       ↓
LLM call 2：{ lastUserAnswer, nextTemplate } → JSON: {lastClassification, question}
       ↓
程序：lastClassification → 更新各候选 score
       ↓
检查终止条件：
  · 最高 - 次高 ≥ 2  → locked
  · 满 5 轮          → locked（取最高）
  · 连续 2 轮 uncertain → gave_up
       ↓
循环 LLM call N（同上结构）直到终止
       ↓
locked: useUserStore.getState().setBirthDate(correctedDate)
       → AsyncStorage + Supabase profileSync 自动同步
       → AI 最后一句 "已校准为 X 时，命盘已更新"
gave_up: AI 最后一句 "信息不够，可换个时间再试"
       不动 birthDate
```

---

## 4. 引擎层

模块路径：`lib/calibration/`

### 4.1 状态机

```ts
type CandidateId = 'before' | 'origin' | 'after';

interface Candidate {
  id: CandidateId;
  birthTime: Date;       // 实际时辰对应的时间（中位数，例如 戌时 = 20:00）
  bazi: BaziChart;
  ziwei: ZiweiChart;
}

interface AskedQuestion {
  templateId: string;
  year: number;
  ageThen: number;
  questionText: string;       // LLM 改写后的实际问句
  userAnswer: string;
  classified: 'yes' | 'no' | 'uncertain';
  delta: Record<CandidateId, number>;  // 本轮各盘分数变化
}

interface CalibrationSession {
  candidates: [Candidate, Candidate, Candidate];
  scores: Record<CandidateId, number>;
  history: AskedQuestion[];
  round: number;
  consecutiveUncertain: number;
  status: 'asking' | 'locked' | 'gave_up';
  lockedCandidate?: CandidateId;
}
```

### 4.2 Bifurcation Detector

模块：`lib/calibration/bifurcation.ts`

输入：3 个候选盘
处理：
1. 对每个候选盘，列出 `[currentAge - 30, currentAge - 1]` 区间内的事件向量
   - 大运边界年（每盘约 3-5 个）
   - 流年关键事件（七杀 / 伤官见官 / 桃花 / 官非 / 子女星动）
   - 紫微大限边界 + 关键四化年
2. 按年份聚合，每年生成 `{year, events: [{candidateId, eventType}]}`
3. 计算"差异度" = 该年里 3 个候选盘事件类型两两不同的对数（max=3, min=0）
4. 按差异度降序排序，再按"距今越近优先"排序（用户对近期记忆更准）
5. 返回排序后的候选问题列表，每项形如 `{ year, ageThen, eventByCandidate: {before: '七杀', origin: '正官', after: '伤官'} }`

### 4.3 模板库

模块：`lib/calibration/templates/`

每模板形如：
```ts
interface QuestionTemplate {
  id: string;
  triggerEvents: string[];    // 命中哪些事件类型
  variants: {                  // 不同事件类型对应的"yes 期望"
    [eventType: string]: 'yes' | 'no' | 'irrelevant';
  };
  rawQuestion: string;         // 模板文本，含 {year} {age} 占位
}
```

举例：
```ts
{
  id: 'major_role_shift',
  triggerEvents: ['大运转七杀', '大运转正官', '大运转比劫'],
  variants: {
    '大运转七杀': 'yes',   // 临七杀的盘期望用户在那年说"挣脱过被压抑环境 / 主动挑战权威"
    '大运转正官': 'yes',   // 临正官期望"进入更需要克制的位置"
    '大运转比劫': 'no',    // 比劫期望那年没明显角色变化
  },
  rawQuestion: '你 {age} 岁那年（{year}）有没有在工作或生活角色上有明显的转折？'
}
```

MVP 起步覆盖 **~15 个模板**：
- 大运类 6 个：七杀挣脱 / 正官入位 / 伤官冲突 / 食神舒展 / 比劫合作 / 印星依靠
- 流年类 4 个：桃花动情 / 官非纠纷 / 子女缘 / 伤病
- 紫微类 3 个：命迁互换 / 夫妻宫四化 / 财官冲突
- 兜底类 2 个：性格鉴别 / 健康弱点

模板库扁平存储，每个模板一个 `.ts` 文件，由 `templates/index.ts` 聚合导出。新增模板不改 detector / scoring 逻辑。

### 4.4 Scoring + 终止

每轮：
- LLM 返回 `lastClassification` ∈ {'yes', 'no', 'uncertain'}
- 程序按当前模板的 `variants` 比对：
  - 候选盘的事件类型期望值 == 用户答案 → 该盘 +1
  - 期望值 ≠ 用户答案（且不是 irrelevant） → 该盘 -1
  - irrelevant 或 uncertain → 不变
- 更新 `scores`，记录 `history`

终止条件（按优先级）：
1. **locked**：`max(scores) - secondMax(scores) ≥ 2` → lock 最高分候选
2. **locked**：`round == 5` → lock 当前最高分（如果有平手，原时辰优先）
3. **gave_up**：`consecutiveUncertain == 2` → 保留原 birthDate
4. 否则：`round += 1`，从 detector 取下一题（已问过的模板/年份不重复）

---

## 5. AI 编排层

模块：`lib/calibration/CalibrationAI.ts`

### 5.1 单 LLM Call 设计

```ts
interface CalibrationAIInput {
  templateRaw: string;         // 模板原文（已替换 {year} {age}）
  lastUserAnswer?: string;     // 首轮为 undefined
}

interface CalibrationAIOutput {
  lastClassification?: 'yes' | 'no' | 'uncertain';  // 首轮为 undefined
  question: string;            // 改写后的自然问句
}
```

### 5.2 System Prompt

```
你是命理师，正在用过去事件帮用户校准出生时辰。

每轮我会给你一个事件模板和年份。你的任务：

1. 如果有上一轮的用户答案，先把它归类：
   - yes：用户明确说发生过
   - no：用户明确说没有发生
   - uncertain：用户说不记得 / 不知道 / 含糊 / 模棱两可
2. 把新模板改写成 1-2 句自然问句。不要解释命盘原理，不要"根据您的命盘"这种话，直接问事件，温和但不啰嗦。

返回 JSON 格式：
{
  "lastClassification": "yes" | "no" | "uncertain" | null,
  "question": "<你的问句>"
}

首轮 lastClassification 为 null。
```

### 5.3 复用现有基建

- Provider config：复用 settings 里的 BYOK key 配置
- Streaming：**不流式**，用一次性 JSON mode（`response_format: {type: 'json_object'}`）
- 网络层：复用 `lib/ai/chat.ts` 的 fetch/请求构造，但走独立函数避免与 streaming chat 路径耦合

### 5.4 容错

- JSON 解析失败：fallback `{ lastClassification: 'uncertain', question: templateRaw }`（直接显示模板原文）
- 网络错（带 retry，最多 2 次）：失败后 fallback 同上，并在 chat 末尾追加一条系统消息 "网络似乎有点慢，先用原句继续"
- LLM 输出非 JSON：当 fallback 处理

---

## 6. UI

### 6.1 入口（"我的"页面）

`app/(tabs)/profile.tsx` 在生辰相关区域加一行：

```
出生信息
  生辰      1995-08-15 19:30
  校准时辰  →
```

视觉规范：
- 行高、padding、字号严格对齐 profile.tsx 现有行
- 右侧 chevron 用现有 `ChevronRight` 资源
- **不加任何 "已校准" / "未校准" 状态标签**——按 ADR-4，没有这个状态概念

无 birthDate 用户：整行 disabled + 灰色提示 "先填生辰才能校准"，点击不响应。

### 6.2 BottomSheet（CalibrationSheet）

新文件：`components/calibration/CalibrationSheet.tsx`

**视觉规范**：沿用 `components/ai/FullReasoningSheet.tsx` 的 RN `Modal` + backdrop 模式（不引第三方 BottomSheet 库）：
- 高度 ~85%
- 顶部 header：左边 "校准时辰" 标题，右边 ✕ 关闭
- 中间 ScrollView 渲染消息流
- 底部输入栏：贴底，单行 TextInput + 发送按钮

**消息样式**：项目目前**没有**提取独立的 `MessageBubble` 组件——`app/(tabs)/insight.tsx` 内联了 chat 渲染。本期**也内联**（CalibrationSheet 自带 bubble + input 样式），匹配 insight.tsx 视觉规范，不引入跨场景抽象。后续如要做"提取共享 chat 组件"由独立 refactor 任务承接。

**交互**：
- 打开时 `useEffect` 调 `CalibrationSession.start()`，渲染首题
- 用户发送 → 显示 user bubble → 显示 "思考中..." 占位 → LLM 返回 → 替换为 AI bubble + 下一题
- 思考中动画：3 个点的 fade 循环，约 800ms 周期，组件名 `CalibrationThinkingDots`，单文件 ~30 行
- `locked` / `gave_up` 后输入栏置灰 disabled

**完成态消息**：
- `locked`：「已校准为戊时（晚上 7-9 点），命盘已更新。」（中文化时辰名 + 时间区间）
- `gave_up`：「信息不够，无法确定时辰。可换个时间再试。」

### 6.3 中途关闭

用户点 ✕ 或下滑关闭 → 直接销毁 session，不留草稿。重开 = 全新 session。

---

## 7. 数据持久化

### 7.1 写入

`locked` 时一行：

```ts
useUserStore.getState().setBirthDate(correctedDate);
```

底层（已有，不动）：
- Zustand 更新 → 全局 reactive UI 立即响应
- `lib/store/userStore.ts` 已经用 `persist` + AsyncStorage middleware
- `lib/store/profileSync.ts` 自动把 birthDate 上行到 Supabase profiles 表

**不动**：
- profiles 表 schema
- onboarding 流程
- 其它任何 UI

### 7.2 读取

不需要新增 selector——所有命盘/AI 都已经从 `useUserStore.birthDate` 取，自动看到校准后的值。

---

## 8. 失败 / 边缘情况

| 场景 | 行为 |
|---|---|
| 用户没填生辰 | 入口 disabled，显示提示 |
| AI provider 未配置 | 入口 disabled + 提示 "先在设置里配置 AI" |
| Bifurcation detector 找不到差异年份（< 18 岁用户） | 启动失败，提示 "再过几年才适合校准"（暂不做校准） |
| 用户输入空字符串 | 发送按钮 disabled，不发起 LLM call |
| 用户输入超过 200 字 | 截断到 200 字，提示 "请简短回答" |
| 网络中断 mid-session | 当前轮重试 2 次，仍失败则提示 "网络异常，请稍后重试"，session 保留状态可继续 |
| 连续 2 轮 uncertain | 进入 `gave_up`，保留原 birthDate |
| 满 5 轮但平手 | lock 当前最高分；如果三盘平手，lock 原时辰（保守） |
| LLM 输出非 JSON | fallback 见 §5.4 |
| 用户在 `locked` 后立即再点校准 | 用 locked 后的 birthDate 作为新基准，开始新一轮（不带历史）|

---

## 9. 测试策略

### 9.1 单元测试（确定性引擎）

`lib/calibration/__tests__/`：
- `bifurcation.test.ts`：固定 3 个候选盘，验证差异度计算和年份排序
- `scoring.test.ts`：固定模板和答案序列，验证 score 累计和终止条件触发
- `CalibrationSession.test.ts`：mock AI 层，验证状态机走通 happy path / gave_up / max_rounds 三种结局

### 9.2 模板测试

`lib/calibration/templates/__tests__/`：
- 每个模板至少 1 个 fixture 测试：给定事件类型组合，验证 expected 期望值正确
- 模板字段完整性测试（id 唯一、rawQuestion 含 {year}{age}、variants 至少 2 个事件类型）

### 9.3 集成测试

`lib/calibration/__tests__/integration.test.ts`：
- 用真实 BaziEngine + iztro 排 3 个候选盘
- mock LLM 回复（按预定 yes/no 序列）
- 验证最终 lock 的候选符合预期

### 9.4 UI 测试（手测矩阵）

T14-style 手测清单：
1. 已填生辰用户：入口可点 → 打开 sheet → 走完 5 轮 → 看到"已校准"消息 → 关闭 → 命盘页时辰已更新
2. 未填生辰用户：入口 disabled
3. 中途关闭 → 再开 → 全新 session
4. 连续答 "我不记得" → gave_up 消息显示，birthDate 不变
5. 网络断开 → 重试提示

---

## 10. 不在 MVP 范围

- ±2 时辰 / 全 12 时辰扫描（"未知时辰"分支）
- 校准历史记录（"我上一次校准是什么时候"）
- 校准证据可视化（哪些问题贡献了最终结论）
- 多用户档案的 batch 校准（家人/伴侣盘）
- 校准过程中切换语言 / 切换 AI provider
- 校准结果"可疑度"评分给主对话用（"AI 现在用的时辰是 76% 置信度"这类元信息）

这些都是 v2 之后再考虑的方向，本期不实现。

---

## 11. 落地文件清单（预估）

| 路径 | 改动 |
|---|---|
| `lib/calibration/CalibrationSession.ts` | 新建 |
| `lib/calibration/bifurcation.ts` | 新建 |
| `lib/calibration/scoring.ts` | 新建 |
| `lib/calibration/CalibrationAI.ts` | 新建 |
| `lib/calibration/templates/index.ts` + ~15 个模板文件 | 新建 |
| `lib/calibration/types.ts` | 新建 |
| `lib/calibration/__tests__/*` | 新建 |
| `components/calibration/CalibrationSheet.tsx` | 新建（含内联 bubble/input/ThinkingDots） |
| `app/(tabs)/profile.tsx` | 加入口行 + sheet visible state |
| `lib/store/userStore.ts` | 不改（复用现成 `setBirthDate`） |
| `docs/PRD.md` | 加 Phase 4 描述 |
| `docs/TASKS.md` | 加 Phase 4 任务列表 |

预估 LOC：~1500-2000（含测试）。

---

## 12. 后续

设计审阅通过后：
1. 用 superpowers:writing-plans 写实施计划到 `docs/superpowers/plans/2026-04-26-time-calibration.md`
2. 用 superpowers:subagent-driven-development 派 subagent 落地（按用户偏好用 opus model + WebSearch）
