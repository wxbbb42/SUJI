# 设计文档：AI 编排架构 + 中式占卜系统集成

**日期**：2026-04-25
**作者**：通过 superpowers:brainstorming 与 Claude 协作产出
**范围**：重构 AI 对话编排架构；引入紫微斗数；规划六爻、奇门遁甲的渐进式集成
**性质**：架构设计 + 多 phase 路线图

---

## 1. 背景

### 1.1 用户感受到的问题

现状下的 AI 解读存在两个核心问题：

1. **过于 general** —— 用户问"我什么时候会生孩子"，回答可以套在任何人身上，没有命盘个性化的痕迹
2. **过于冗长 + 泛泛而谈** —— 缺乏专业推演的硬证据，听起来像普通情绪陪伴 app

### 1.2 根因分析

代码探索后发现两层根因：

**根因 A：Prompt 显式禁止预测**
`lib/ai/index.ts` 当前的 SYSTEM_PROMPT 写明：
- "永远不说'算命'、'预测未来'，而是'自我觉察'、'能量趋势'"
- "**禁止：做出具体预测**（'你下个月会升职'）"

这一约束源自 `2026-04-24-suji-product-architecture-design.md` 的 §2.5（App Store 分类合规考虑）。AI 答得泛泛**是 prompt 的设计意图**，不是实现 bug。

**根因 B：命盘硬数据 90% 没用上**
`lib/bazi/types.ts` 已有：四柱、十神、藏干带权重、十二长生、大运、流年、神煞、地支冲合刑害、天干合化、胎元、命宫、空亡。

但 `chat.ts` 的 `buildSystemPrompt` 只塞了 6 行：日主、四柱、格局、用喜忌、日主特质、格局含义。**回答"什么时候有孩子"传统命理需要的子女星 / 时柱 / 大运 / 流年 / 神煞，一个都没传给 AI**。

### 1.3 战略选择

经过讨论，产品方向确认从原 §2.5 的"绝对不预测"调整为：

> **后台用真材实料的命理推演（专业层），前台用"传统视角 + 现代解读"的双框架表达（合规层）**。

这正是本设计的核心命题。

---

## 2. 中国命理 / 占卜 系统全景

调研结论：可代码化、有现成库支持、对岁吉有意义的系统按"问什么"可分三类：

### 2.1 命理类（natal-based）— 看人 + 时间线

| 系统 | 核心 | 擅长 | 库 | 决定 |
|---|---|---|---|---|
| **八字（四柱）** ✓ | 4 柱 8 字 + 大运/流年 | 时间节奏、整体轮廓 | `lunisolar` 已用 | **保留并深度使用** |
| **紫微斗数** | 12 宫 + 14 主星 + 四化 | 领域横切（事业/婚姻/子女...） | `iztro@2.5.8`（成熟） | **Phase 1 集成** |
| 七政四余 | 真实行星位置 | 西式数据感 | 无完善 JS 库 | 不做 |
| 铁板神数 | 神秘数推 | 师父口传，无算法 | 无 | 不可代码化 |

### 2.2 卜卦类（question-based）— 看事 + 此刻

| 系统 | 核心 | 擅长 | 库 | 决定 |
|---|---|---|---|---|
| **六爻** | 易经卜卦，三币六掷 | 日常决策（"应不应该"） | 简单可自实现 / `iching-js` | **Phase 2** |
| 梅花易数 | 数字/时间起卦 | 即时灵感 | 可基于六爻 | 不单独做 |
| **奇门遁甲** | 9 宫 × 3 盘 + 八门八神九星 | 重大战略决策 | 极少 | **Phase 3 自实现** |

### 2.3 日常 / 仪式类

| 系统 | 描述 | 决定 |
|---|---|---|
| 黄历宜忌 | 干支 + 神煞匹配 | Phase 4，作为 AI 工具 `query_huangli` |
| 抽签 | 随机数 → 诗签 | Phase 4，内容层 |

### 2.4 系统互补关系

| 维度 | 系统 | 解释 |
|---|---|---|
| **时** | 八字 | "什么时候" |
| **域** | 紫微 | "哪一方面怎么样" |
| **事** | 六爻 / 奇门 | "应不应该 / 会不会" |

三足鼎立架构，跨 Phase 1-3 落地完成后能 cover 命理类提问 95% 的形式。

---

## 3. 多 Phase 路线图

| Phase | 范围 | 实施周期估计 |
|---|---|---|
| **Phase 1（本 spec）** | AI 编排重构（tool-use） + 全量八字接入 + 紫微集成 | 4-6 工作日 |
| **Phase 2** | 六爻起卦工具 + AI 解卦 prompt | 2-3 工作日 |
| **Phase 3** | 奇门遁甲简化版 + AI 解局 | 4-5 工作日 |
| **Phase 4** | 紫微 12 宫可视化、抽签内容、黄历宜忌工具、其他文化层 | 滚动迭代 |

商业化（Pro 订阅、付费墙）暂不分层；先把功能跑通，后期再分层。

---

## 4. Phase 1 架构决策

下面 5 个决策决定了 Phase 1 的具体形态。每个都有备选方案与"为什么是这个"的理由，**留给以后回看时知道当时的判断依据**。

### ADR-1：用 Tool Use（function calling）替代 Prompt 全塞

**问题**：怎么让 AI 拿到命盘相关数据？

**候选**：
- A. 全量 chart context 塞入 system prompt（每次 ~1400 tokens），AI 自挑相关字段
- B. 分段 + 注意力 hint 塞入 prompt，AI 自挑
- C. **LLM Tool Use**：定义工具签名（~200 tokens），AI 主动按需调用

**选 C**，理由：
- **真正的响应式编排**：AI 主动决策"我需要哪些数据"，过程透明、可审计
- **prompt 体积小**：只放工具定义，~250 tokens vs 1400 tokens
- **架构可扩展性极强**：Phase 2/3 加六爻 / 奇门只需加 tool def + TS 实现，**不动 AI 编排核心**
- **跨模型支持**：OpenAI / Claude / DeepSeek / GPT-5 系列都原生支持 function calling

**代价**：
- `chat.ts` 要从 single-shot 改为 multi-turn tool loop
- 三家 provider 的 tool API 略有差异，需要适配层
- 需要错误处理（AI 偶尔会乱调或重复调用工具）

### ADR-2：八字 + 紫微 在 Phase 1 同时上

**问题**：紫微立刻做还是放下一轮？

**候选**：
- A. Phase 1 只做八字深度，紫微下一轮
- B. **Phase 1 八字 + 紫微同时上**

**选 B**，理由：
- **紫微 12 宫天然映射到"领域路由"**：`get_domain('子女')` 直接返回紫微子女宫，路由设计与紫微结构契合
- 一次 onboard 用同一组生辰出两套排盘，**用户感知到的是"哇专业"**，不是分两次挤牙膏
- iztro 库成熟（v2.5.8，MIT，2.1MB unpacked），TS 友好，无技术风险
- 不立刻做紫微 12 宫的可视化 UI（留给 Phase 4），**今轮只让 AI 用紫微数据**，YAGNI 收敛

### ADR-3：解除 SYSTEM_PROMPT 的"不预测"约束

**问题**：原 prompt 禁止具体预测；新需求要求专业推演 + 具体结论。

**决议**：**重写 SYSTEM_PROMPT**，拆为 thinker（推演）+ interpreter（解读）两个角色：
- thinker 直接做硬推演，不做合规修饰
- interpreter 用"传统看 / 被视为 / 窗口期"等带余地的表达，避免绝对断言

**合规护城河**移到**输出语言**（"传统八字里...被视为...仅供参考"），而不是禁止内容本身。

参考 `2026-04-24-suji-product-architecture-design.md` §2.5 的 App Store 分类要求：仍可保持 Lifestyle / Health & Fitness 分类，因为输出始终包含**双框架解读 + 文化语境 + 不下绝对断言**。

### ADR-4：用 iztro 而非自实现紫微

**候选**：
- A. **用 `iztro@2.5.8`**（MIT、TS、活跃维护）
- B. 自实现紫微排盘算法

**选 A**，理由：
- 紫微算法复杂（14 主星 + 多辅星 + 四化 + 12 宫安星 + 流年大限）
- iztro 是社区主流选择，已经过大量用户验证
- 我们的差异化在 **AI 编排 + 解读**，不在排盘算法本身
- 自实现增加 5-7 工作日且无独占价值

### ADR-5：聚合工具 + 精细工具分层（不全部细化）

**问题**：Tool 粒度多细才合适？

**候选**：
- A. 细粒度（10+ 个工具，每个一个原子操作）
- B. **分层（聚合 + 精细 + 上下文）**
- C. 全聚合（2-3 个超级工具）

**选 B**，理由：
- 90% 常见问题（婚姻/子女/事业...）通过聚合工具 `get_domain(domain)` 一次拿全
- 10% 跨域 / 复杂问题用精细工具补充
- 工具数量 6 个，AI 容易理解、不会困惑

详见 §6 工具清单。

---

## 5. 数据层设计

### 5.1 八字层（已有，深度使用）

`lib/bazi/BaziEngine.ts` + `lib/bazi/types.ts` 已实现：
- 四柱（含每柱：十神、藏干带权重、十二长生）
- 五行平衡 + 用神/喜神/忌神
- 大运（DayunEngine）
- 神煞（红鸾、天喜、桃花、文昌、驿马 等）
- 地支冲合刑害、天干合化
- 格局识别
- 胎元 / 命宫 / 空亡

**改动**：无（引擎本身不动），新增 `lib/ai/tools/bazi.ts` 作为工具适配器层。

### 5.2 紫微层（新增）

新建 `lib/ziwei/ZiweiEngine.ts`：
- 输入：和八字一样的生辰（年月日时 + 性别 + 经纬度）
- 包装 `iztro` 库
- 输出 12 宫数据：
  - 每宫：宫名、主星、辅星、四化、亮度（庙旺得利平闲陷）
  - 命宫、身宫位置
  - 当前流年命宫
- 缓存：与 `mingPanCache` 同机制存到 `useUserStore`，独立字段 `ziweiPanCache`

### 5.3 命主身份卡片（内联 system prompt）

约 80-150 tokens，永远内联：
```
日主：{riZhu}（{yinYang}{wuXing}）· {geJu}格
用神：{yongShen} · 喜神：{xiShen} · 忌神：{jiShen}
紫微命宫主星：{ziweiMingGongStars}
```
不做成 tool —— 每次推演都需要的稳定信息没必要走 round-trip。

---

## 6. 工具清单

### Phase 1 工具（6 个）

#### 聚合层

**`get_domain(domain)`** ⭐ 最常用

获取某领域的"全套相关数据"。

| domain | 返回 |
|---|---|
| `'子女'` | 八字子女星(食神/七杀)+时柱状态 + 紫微子女宫 + 红鸾天喜神煞 |
| `'婚姻'` | 八字配偶星(财/官)+日支 + 紫微夫妻宫含化 + 桃花神煞 |
| `'事业'` | 八字财官十神 + 紫微官禄宫 + 紫微田宅宫 |
| `'财富'` | 八字偏正财 + 紫微财帛宫 + 偏财神煞 |
| `'健康'` | 八字日主衰旺 + 紫微疾厄宫 + 凶煞 |
| `'父母'` | 八字偏正印 + 紫微父母宫 |
| `'兄弟'` | 八字比劫 + 紫微兄弟宫 |
| `'迁移'` | 八字驿马 + 紫微迁移宫 |
| `'田宅'` | 八字财库 + 紫微田宅宫 |
| `'福德'` | 紫微福德宫 + 神煞总览 |

**`get_timing(scope, yearRange?)`**

| scope | 内容 |
|---|---|
| `'current_dayun'` | 当前大运 + 与命盘交互 |
| `'all_dayun'` | 全部大运（10 个） |
| `'liunian'` + yearRange | 指定区间的流年扫描 |
| `'liuyue'` + year | 某年的流月 |

#### 精细层（跨域 / 复杂问题）

**`get_bazi_star(person)`**
- person: `'配偶' | '子女' | '父母' | '兄弟'`
- 返回：单星位的状态、力量、引动情况

**`get_ziwei_palace(palace, withFlying?)`**
- palace: 12 宫名
- withFlying: 是否返回四化飞入飞出
- 返回：单宫详细数据

**`list_shensha(kind?)`**
- kind: `'桃花' | '权贵' | '文昌' | '驿马' | 'all'`
- 返回：命盘中匹配的神煞列表

#### 上下文层

**`get_today_context()`**
- 返回：今日干支 + 与命盘交互（神煞当令、流月引动）
- 专为"今日运势"类问题

### 工具策略（写入 system prompt）

```
工具使用策略：
1. 用户问题涉及具体领域（婚姻/子女/事业等）→ 优先用 get_domain
2. 用户问题涉及"何时" → 加 get_timing
3. 跨领域复杂问题 → 用 get_bazi_star / get_ziwei_palace 精查
4. "今日运势"类问题 → get_today_context
5. 一次推演中工具调用 ≤ 4 次（避免无意义遍历）
```

### Phase 2/3 增量（设计预留接口，不在本 spec 实施）

| Phase | 工具 |
|---|---|
| Phase 2 | `liuyao_cast(question)`, `liuyao_interpret(hexagram)` |
| Phase 3 | `qimen_chart()`, `qimen_query(target)` |
| Phase 4 | `query_huangli(date)`, `get_qianshi(随机)` |

---

## 7. 双角色 Prompt 设计

### Call 1 · Thinker Prompt

```
你是岁吉的命理推演引擎。
你不做文化解读，不做情绪安抚，只做硬推演。

# 命主信息（已内联）
日主：{riZhu}（{yinYang}{wuXing}）· {geJu}格
用神：{yongShen} · 喜神：{xiShen} · 忌神：{jiShen}
紫微命宫：{ziweiMingGong}

# 你可调用的工具
{tools}

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
最后一段给"综合判断"：1-2 句话给结论。
```

### Call 2 · Interpreter Prompt

```
你是岁吉的解读师。
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
- 长度控制：interpretation 不超 250 字
```

### 客户端解析

```
原文 → preprocessOrchestrationOutput → 拆出两段
  ↓
[interpretation] 段 → 走原有 RichContent 渲染
                     （markdown + 宜忌卡 + 古文卡 + 关键词徽章）
[evidence] 段       → 渲染成 "🔍 推演依据" 折叠卡
                     （4 行预览 + 查看完整）
```

未识别到 `[evidence]` → 整段当作 markdown 渲染（兜底，不报错）。

---

## 8. UI 改造

### 8.1 Chat Bubble 新结构

```
┌─ AI 气泡 ─────────────────────────────┐
│ 岁吉                                  │
│                                      │
│ ┌─ 🧠 推演过程（折叠）────────┐       │
│ │ • 调用 get_domain("子女")  │ 默认收起│
│ │ • 调用 get_timing(...)    │ 点击展开│
│ │ • 综合：缘分窗口 2027-28    │       │
│ │ ▶ 4 步推演 · 展开            │       │
│ └─────────────────────────┘       │
│                                      │
│ 解读正文（[interpretation]）           │
│ 走 markdown 渲染，宜忌/古文/徽章保留    │
│                                      │
│ ┌─ 🔍 推演依据（[evidence]）─┐        │
│ │ 子女星 · 食神（乙木）        │ 4 行预览│
│ │ 时柱 · 丙寅                │        │
│ │ 当前大运 · 己亥             │        │
│ │ 引动流年 · 2027丁未/戊申     │        │
│ │ ⌄ 查看完整推演              │ 点 →   │
│ └─────────────────────────┘        │
└────────────────────────────────────┘
```

### 8.2 CoT 卡（推演过程）

- **位置**：解读正文上方
- **默认状态**：折叠，只露 1 行总结（"4 步推演 · 展开"）
- **流式期间**：自动展开 + 显示 "推演中... ▍"，每个 tool call 增加一条
- **流式结束**：自动收起（用户主动点开才展开）
- **点击行为**：inline 展开 / 收起（**不开 BottomSheet** —— 内容轻）

### 8.3 Evidence 卡（推演依据）

- **位置**：解读正文下方
- **默认状态**：露 4 行预览 + "查看完整推演" 行动条
- **点击行为**：**打开 BottomSheet**（参考 ShichenDetailSheet 那种风格，但内容不同）

### 8.4 BottomSheet（完整推演）

```
┌─ 完整推演 ──────────────────────┐
│  你的命盘要点                    │
│  ─────                         │
│  [evidence 4-6 行展开]           │
│                                │
│  推演过程                        │
│  ─────                         │
│  [Call 1 完整推演输出]            │
│  1. ...                        │
│  2. ...                        │
│  ...                           │
│                                │
│  使用的数据                      │
│  ─────                         │
│  [tool calls 列表 + 返回值摘要]    │
│                                │
│  [关闭]                         │
└──────────────────────────────┘
```

### 8.5 流式编排时序

```
T0：用户发消息
T1：CoT 卡出现，状态 "推演中..."
T2-T4：每次 tool call 完成，CoT 卡里加一行
T5：Call 1 推演完成，CoT 卡显示 "推演完成"
T6：解读正文开始流式（[interpretation] 段）
T7：[evidence] 段到达，evidence 卡渐显
T8：流式结束，光标消失
```

---

## 9. 文件结构变化

### 新增

```
lib/
  ai/
    tools/
      index.ts                      # 工具汇总导出 + 工具策略文本
      bazi.ts                       # 6 个工具中的八字部分实现
      ziwei.ts                      # 6 个工具中的紫微部分实现
      types.ts                      # ToolDefinition / ToolCall / ToolResult 类型
      orchestrator.ts               # multi-turn tool loop 控制器
  ziwei/
    ZiweiEngine.ts                  # iztro 包装层
    types.ts                        # 紫微类型定义
components/
  ai/
    CoTCard.tsx                     # 推演过程折叠卡
    EvidenceCard.tsx                # 推演依据折叠卡
    FullReasoningSheet.tsx          # 完整推演 BottomSheet
    customRules/
      preprocessOrchestration.ts    # [interpretation] / [evidence] 拆分
```

### 修改

```
lib/
  ai/
    index.ts                        # SYSTEM_PROMPT 完全重写为 thinker + interpreter
    chat.ts                         # 重构为 multi-turn tool loop
                                    # 增加 callThinker / callInterpreter 函数
                                    # buildSystemPrompt 删除（被工具系统取代）
  store/
    userStore.ts                    # 增加 ziweiPanCache 字段
components/
  ai/
    RichContent.tsx                 # 接入 preprocessOrchestration（接 [interpretation] 流）
app/
  (tabs)/
    insight.tsx                     # 替换聊天气泡布局，加入 CoT 卡 + Evidence 卡
    profile.tsx                     # 配置生辰后同步生成紫微盘（如已有 profile 流程）
package.json                        # +iztro@^2.5.8
```

### 删除

```
lib/ai/chat.ts 里的 buildSystemPrompt 函数
```

---

## 10. 测试策略

### 单元测试（jest，已有 jest-expo 环境）

| 模块 | 测试目标 |
|---|---|
| `preprocessOrchestration.ts` | 7-8 个 case：标准格式、缺 evidence、多个 [evidence]、空 [interpretation]、半流式状态 |
| `ZiweiEngine.ts` | 5 个 case：固定生辰输入 → 已知 12 宫主星位 |
| `lib/ai/tools/bazi.ts` 各工具 | 每个工具 3-4 个固定 fixture 测试 |
| `lib/ai/tools/ziwei.ts` | 同上 |
| `lib/ai/tools/orchestrator.ts` | mock 工具响应 → 验证 multi-turn loop 终止条件、错误处理 |

### 集成 / 设备测试（手测）

跨工具 + 跨流式的测试矩阵：

| 测试问题 | 期望调用 | 期望解读 |
|---|---|---|
| "什么时候有孩子" | get_domain('子女') + get_timing('liunian') | 解读双段，evidence 含子女星 + 流年 |
| "今年事业" | get_domain('事业') + get_today_context() | 解读双段，evidence 含官禄宫 + 流年 |
| "我跟我老公合不合" | get_domain('婚姻') + list_shensha('桃花') | 解读双段，evidence 含夫妻宫 + 桃花 |
| "今天怎样" | get_today_context() | 解读单段，evidence 含今日干支交互 |
| "我这辈子整体" | get_timing('all_dayun') 或不调工具 | 解读基于身份卡片的整体画像 |

### 流式 UX 测试

- CoT 卡的 tool call 增量显示是否流畅
- Evidence 卡的渐显时机是否自然
- 中断 / 错误情形：tool call 失败、AI 不按 [evidence] 格式输出、网络中断恢复

---

## 11. 已知风险与开放问题

### R1：Tool-use API 跨 provider 差异
OpenAI / Anthropic / DeepSeek / Responses API 的 function calling 协议**结构相似但字段名不同**。需要在 `chat.ts` 内做归一化适配。

**缓解**：先在 OpenAI 兼容协议上跑通（DeepSeek 可复用），Anthropic 和 Responses API 单独适配层。

### R2：AI 不按 [evidence] 格式输出
LLM 在长上下文 / 复杂问题下偶尔不严格遵守输出格式。

**缓解**：preprocessor 兜底——识别失败就当普通 markdown 渲染，**不报错、不丢内容**。在用户实际触发率高时再加 retry / format fix 层。

### R3：iztro 与 RN 0.81 + New Architecture 兼容
iztro 的依赖（dayjs、lunar-typescript）都是纯 JS，理论上兼容。但社区里偶有报告日历计算在 Hermes 上略有偏差。

**缓解**：在 `ZiweiEngine.ts` 的单测里包括"和已知排盘网站对比"的 fixture 测试，发现差异立刻暴露。

### R4：Multi-turn tool loop 的延迟
即使每个 tool call 是本地（不发网络），LLM 端的多轮往返本身就增加延迟。"快"不是用户最关心的（用户已说），但极限情况下（比如 4 次 tool call + 长答）总响应可能 30-60 秒。

**缓解**：CoT 卡的存在让等待"有戏看"，用户感知不到无聊；UI 加 "正在推演 · X/4" 进度提示。

### R5：紫微数据让 prompt 变大
即使是工具策略，单次调用 `get_domain` 返回的数据可能 200-400 tokens。多次调用累积可能上千。

**缓解**：返回值仅含**结构化关键字段**，不含描述性长文本（描述性文字让 AI 在解读层自己写）。每个工具返回值预算 ≤ 200 tokens。

---

## 12. 与既往 spec 的关系

### 调整 `2026-04-24-suji-product-architecture-design.md` §2.5

原文："**不出现'算命''预测''大师''犯太岁''破财'等词**"

调整为："不使用绝对断言式预测语言（'你 X 月一定升职'）；可以使用带文化框架的传统语言（'传统八字看...被视为...仅供参考'）。'犯太岁''破财'仍不使用——这些是民间俗称而非命理学术语。"

App Store 分类仍保持 Lifestyle / Health & Fitness。

### 与 `2026-04-24-shichen-timeline-and-chat-richness-design.md` 的关系

- Module 2（流式）和 Module 3（富文本）已实现，本 spec **复用其渲染管道**：
  - `[interpretation]` 段直接走 `RichContent`（含宜忌卡 / 古文卡 / 命盘徽章）
  - 流式光标 / 停止键 / AbortController 不变
- Module 1（时辰能量轴）已撤销，与本 spec 无关
- 本 spec 引入的 CoT 卡、Evidence 卡、FullReasoningSheet 是**新组件**，不替换既有

---

## 13. 不在本 spec 范围

明确**本 spec 不解决**的事项：
- 紫微 12 宫的可视化 UI（盘面图、宫位卡片等）→ Phase 4
- 六爻起卦交互（摇币动画 / 用户输入数字）→ Phase 2
- 奇门盘面渲染 → Phase 3
- Pro 订阅 / 付费墙
- AI 长期记忆（对话历史已持久化，"记得用户偏好"是另一议题）
- 多人合盘 / 关系合婚（用户问"我和我对象"时，本 spec 仅基于自己命盘解读对象关系，不输入对方生辰）
