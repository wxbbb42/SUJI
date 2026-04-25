# 设计文档：奇门遁甲集成（Phase 3）

**日期**：2026-04-25
**作者**：通过 superpowers:brainstorming 与 Claude 协作产出
**范围**：在 Phase 1 编排架构 + Phase 2 六爻基础上加奇门遁甲起局工具 + AI 解局 + 用神宫聚焦 UI
**性质**：功能扩展（最复杂的占卜系统）+ 数据精准度高优先

---

## 1. 背景

Phase 2 上线后，"事"维度有了六爻覆盖日常决策（"她回我吗" / "明天面试结果"）。但用户面对**战略级重大决策**时（"我要不要换城市生活" / "明年要不要创业" / "全家移民"），六爻能给的答案颗粒度仍嫌不足 —— 缺少"全局态势 + 关键时机 + 多维力量"的视角。

奇门遁甲在传统中被称为"帝王之学"，专治此类问题。9 宫 × 5 层（地盘干 / 天盘干 / 八门 / 九星 / 八神）= 45 个信息点 + 用神宫定位 + 格局识别 + 应期推算，是中国占卜系统中最深的"事"维度工具。

### 1.1 与既往 spec 的关系

`2026-04-25-ai-orchestration-and-divination-systems-design.md` §3 路线图：

| Phase | 范围 | 状态 |
|---|---|---|
| Phase 1 | 编排重构 + 八字深度 + 紫微 | ✅ 已上线 |
| Phase 2 | 六爻起卦 + AI 解卦 | ✅ 已上线 |
| **Phase 3（本 spec）** | **奇门遁甲简化版 + AI 解局** | 本 spec |
| Phase 4 | 紫微 12 宫可视化、抽签、黄历 | 后续 |

Phase 1 ADR-1（用 Tool Use）的工具系统在 Phase 2 验证良好，本 spec 完全复用：加新工具 `setup_qimen`，不动 orchestrator 核心。

### 1.2 工时调整

Phase 1 spec 估 Phase 3 为 4-5 工作日。本 spec 因数据精准要求 + 完整格局 MVP，**调整为 7-9 工作日**。

---

## 2. 设计决策（ADR）

### ADR-1：奇门和六爻通过 AI 自动路由区分（不加 ModePicker 模式）

**问题**：奇门和六爻都是"卜决策"类工具，怎么让用户用？

**候选**：
- A. AI 自动判断（不加新模式）
- B. ModePicker 加第 4 模式"起一局"
- C. 混合：默认 A，可强制 B

**选 A**。理由：
- 用户已经接受了 Phase 2 的"起一卦 = 六爻"心智，"卦" vs "局"是奇门 vs 六爻的传统区分
- 加新模式增加学习成本（"什么时候用一卦、什么时候用一局"用户分不清）
- AI 路由有清晰的启发式：影响时间跨度 + 生活面广度 + 严肃度
- 误判时用户可通过 `user_force_mode=liuyao` 强制走六爻（已有）

**意味着**："起一卦"模式 = 仅六爻（不会触发奇门）；奇门只在"随心问"模式下、AI 自动判断为战略级问题时触发。

### ADR-2：UI 主气泡只显示用神宫，完整 9 宫盘在 BottomSheet

**问题**：奇门 9 宫盘信息密度极高（3×3 网格 × 5 层），普通用户看到立刻劝退。

**候选**：
- A. 完整 9 宫盘画在主气泡里
- B. 用神宫聚焦卡 + 相邻宫标签
- C. 极简文字（不画盘）

**选 B**。理由：
- 用户能"一眼看懂"用神宫的含义（5 行信息聚焦在一个卡里）
- 保留"专业感"（有盘 + 有图，不是纯文字）
- 完整 9 宫盘留在 BottomSheet 给爱好者
- 与 Phase 2 "evidence 卡精华 / BottomSheet 完整" 的分层一致

### ADR-3：后端档 4 全套数据 + 前端档 2 形象比喻

延续 Phase 1/2 的分层：
- `setup_qimen` 工具返回完整 9 宫盘（45 数据点）+ 用神宫 + 格局列表 + 应期
- INTERPRETER 用"画面感 + 心情共鸣"语言写解读（禁奇门术语）
- evidence 卡和 BottomSheet 显示档 3-4 的专业字段

### ADR-4：自实现奇门算法（不依赖第三方库）

**问题**：从 npm / web 看奇门库可用性。

**候选**：
- A. 用 npm `qimen-dunjia` / `qimendunjia` 之类
- B. 自实现

**选 B**。理由：
- npm 上的奇门库都不是一线维护，准度堪忧
- 奇门算法虽然复杂但**完全确定性**：节气查表 → 局数查表 → 9 宫起式（固定规则） → 格局检测（规则集合）
- Phase 2 自实现六爻经验顺利，预演了"自实现 + 数据驱动"模式
- 有 `lunisolar` 库（已在依赖里）解决节气计算这个最难的部分

### ADR-5：完整格局 MVP（50-60 个，不分阶段）

**问题**：经典格局有 100+ 个，是不是先做 20-30 个高频，剩下 Phase 3.5 补？

**用户决定**：MVP 一次做完整。

**范围**：50-60 个常见格局，覆盖：
- 三奇格（乙奇 / 丙奇 / 丁奇 各对应特定门、星、神组合，约 15 个）
- 六仪击刑格（戊击刑 / 己击刑 / 庚击刑 / 辛击刑 / 壬击刑 / 癸击刑 共 6 个）
- 通用格（伏吟、反吟、入墓、值符、值使、白虎猖狂、玄武当权 等约 10 个）
- 命名吉格（飞鸟跌穴、青龙返首、玉女守门 等约 12 个）
- 命名凶格（白虎猖狂、太白入荧、五不遇时 等约 8 个）

**不做的**：100+ 个里冷门组合（如某些古书独家格局）。

### ADR-6：数据精准度三重验证

**用户决定**：所有静态数据必须**实施前**通过 3 个权威源交叉验证。

**实施约束**：
- 24 节气 × 3 元 = 72 起局表（最关键）
- 9 宫位置 + 五行 + 默认地盘干
- 八门 / 九星 / 八神 各自的属性
- 50-60 个格局的识别规则
- 用神规则映射（questionType → 用神干 / 星 / 神）

**验证方法**：
1. **来源 ≥ 3 个**：《奇门遁甲全书》扫描版 + ziwei.pro / qimendunjia.net / 类似奇门排盘网站 + 至少 1 本现代奇门入门书
2. **fixture 验证**：每张数据表用 3-5 个已知盘比对，确认本地实现产出与权威源完全一致
3. **格局规则**：每个格局至少 1 个 fixture 测试

如果三个来源对某个数据点意见不一致 → 标记为"分歧条目"，commit message 注明，留待后续考据。

### ADR-7：起局精度 = Standard（真节气 + 拆补法）

- ✅ 用 `lunisolar` 算真节气（不是公历近似）
- ✅ 真太阳时校正（复用 `lib/bazi/TrueSolarTime.ts`）
- ✅ 拆补法（主流派，节气切换直接换局）
- ❌ 不做置闰法（小众派别，多 200 行代码收益小，节气切换边界 1 天内可能误判）
- ❌ 不做超神接气复杂规则

---

## 3. 中国奇门遁甲基础（实施依据）

为了让实施者（含 AI subagent）不必从零学奇门，本节固定关键概念。

### 3.1 9 宫位置

| 宫 ID | 宫名 | 方位 | 五行 | 默认地盘干 |
|---|---|---|---|---|
| 1 | 坎宫 | 北 | 水 | 癸 |
| 2 | 坤宫 | 西南 | 土 | 己 |
| 3 | 震宫 | 东 | 木 | 乙 |
| 4 | 巽宫 | 东南 | 木 | 辛 |
| 5 | 中宫 | 中 | 土 | 戊（寄） |
| 6 | 乾宫 | 西北 | 金 | 庚 |
| 7 | 兑宫 | 西 | 金 | 丁 |
| 8 | 艮宫 | 东北 | 土 | 丙 |
| 9 | 离宫 | 南 | 火 | 壬 |

### 3.2 八门（顺时针排列）

| 门 | 五行 | 吉凶 | 一句话性质 |
|---|---|---|---|
| 休门 | 水 | 吉 | 安息、求财、亲和 |
| 生门 | 土 | 大吉 | 求财、求事、生发 |
| 伤门 | 木 | 凶 | 受伤、损失 |
| 杜门 | 木 | 凶 | 闭塞、隐避 |
| 景门 | 火 | 平 | 情报、文书 |
| 死门 | 土 | 大凶 | 死亡、终止 |
| 惊门 | 金 | 凶 | 惊讶、官非 |
| 开门 | 金 | 大吉 | 求事、开拓 |

### 3.3 九星

| 星 | 五行 | 吉凶 | 性质 |
|---|---|---|---|
| 天蓬 | 水 | 凶 | 盗、险 |
| 天芮 | 土 | 大凶 | 病、损 |
| 天冲 | 木 | 中 | 战斗 |
| 天辅 | 木 | 大吉 | 辅佐 |
| 天禽 | 土 | 大吉 | 吉祥 |
| 天心 | 金 | 大吉 | 智慧、医药 |
| 天柱 | 金 | 凶 | 破坏 |
| 天任 | 土 | 吉 | 稳重 |
| 天英 | 火 | 中 | 学问 |

### 3.4 八神

| 神 | 吉凶 | 含义 | 求测应用 |
|---|---|---|---|
| 值符 | 大吉 | 八神之首、贵人 | 万事之主，求事看其落宫 → 大吉之兆 |
| 腾蛇 | 凶 | 怪异、虚惊 | 多疑、惊扰、虚假信息、噩梦 |
| 太阴 | 吉 | 阴贵之神 | 暗藏私事、女性、阴谋暗助 |
| 六合 | 中吉 | 和合、媒人 | 婚姻、合作、沟通、契约 |
| 白虎 | 凶 | 道路、刑伤 | 出行、争斗、官非、刑伤 |
| 玄武 | 凶 | 暗昧、盗贼 | 失物、暗算、欺骗、阴损 |
| 九地 | 吉 | 安定、藏匿 | 求稳、暗助、积累、藏宝 |
| 九天 | 吉 | 远方、高位 | 出行、扬名、上升、宣扬 |

**起神规则**：
- 起点：值符神放在**直符宫**（即时干所在宫）
- 阳遁：顺布（值符 → 腾蛇 → 太阴 → 六合 → 白虎 → 玄武 → 九地 → 九天，按宫位顺时针）
- 阴遁：逆布（同序但按宫位逆时针）
- 中宫不放神（八神共 8 个，对应 8 个外宫）

### 3.5 三奇六仪

- **三奇**：乙、丙、丁
- **六仪**：戊、己、庚、辛、壬、癸

地盘干分布：戊放第 1 局 / 第 2 局... 视局数定起点。

### 3.6 阴阳遁

- **阳遁**：冬至～夏至前。局数顺转（1→2→3...→9→1）
- **阴遁**：夏至～冬至前。局数逆转（9→8→7...→1→9）

每节气 15 天分上元（前 5 天）、中元（中 5 天）、下元（后 5 天）。每元定一个局数。

24 节气 × 3 元 = 72 个局数 entries（这是最重要的查找表）。

### 3.7 起局核心规则

实施 §4.4 的"起局 7 步"必需的具体规则：

#### 3.7.1 三奇六仪分布到 9 宫

戊己庚辛壬癸（六仪）+ 丁丙乙（三奇）按以下顺序放：

```
戊 → 己 → 庚 → 辛 → 壬 → 癸 → 丁 → 丙 → 乙
```

- **阳遁**：顺布。从戊所在宫起，按 1→2→3→4→5→6→7→8→9 宫顺序填入（中宫 5 跳过，戊寄到坤宫 2 或不放）
- **阴遁**：逆布。同序但按 9→8→7→6→5→4→3→2→1 宫顺序

#### 3.7.2 戊起在哪一宫（按局数）

阳遁起戊宫位映射（这是 9 宫盘的"原点"）：

| 局数 | 阳遁戊位 | 阴遁戊位 |
|---|---|---|
| 1 局 | 坎宫（1） | 离宫（9） |
| 2 局 | 坤宫（2） | 艮宫（8） |
| 3 局 | 震宫（3） | 兑宫（7） |
| 4 局 | 巽宫（4） | 乾宫（6） |
| 5 局 | 中宫（5）寄坤 | 中宫寄艮 |
| 6 局 | 乾宫（6） | 巽宫（4） |
| 7 局 | 兑宫（7） | 震宫（3） |
| 8 局 | 艮宫（8） | 坤宫（2） |
| 9 局 | 离宫（9） | 坎宫（1） |

举例：阳遁 7 局 → 戊在兑宫（7） → 阳遁顺布 → 己 在艮 8、庚 在离 9、辛 在坎 1、壬 在坤 2（中宫跳过）、癸 在震 3、丁 在巽 4、丙 在乾 6（中宫已跳）、乙 寄到... 具体看《奇门遁甲全书》对应章节。

#### 3.7.3 时干所在宫 = 直符宫

由起好的地盘干表查找当前**时辰天干**所在的宫位。该宫即"直符宫"，是 9 宫盘的"指针中心"。

#### 3.7.4 旋天盘

整个天盘绕中宫旋转，使时干（六仪+三奇之一）的天盘位与地盘位重合在同一宫。具体做法：

- 找到时干在地盘的宫位 = 直符宫
- 把天盘的"值符星"旋至直符宫
- 其余天盘干跟着旋转（保持相对位置不变）

#### 3.7.5 排八门

- 起点：八门按"开休生伤杜景死惊"顺序排
- 直符宫的门 = 八门之首"开门"或当前节气对应的本门（视具体派别，本 spec 用"直符宫起开门"简化）
- 阳遁：顺时针排
- 阴遁：逆时针排
- 中宫无门（中宫 5 不参与八门循环）

#### 3.7.6 排九星

- 九星跟着天盘旋转（与天盘干一一对应固定）
- **天禽星**寄附于天蓬星位置（中宫 5 寄宫规则）
- 起点固定：天蓬在坎、天芮在坤、天冲在震、天辅在巽、天禽在中、天心在乾、天柱在兑、天任在艮、天英在离 —— 这是**地盘九星**的固定位置；天盘九星跟天盘干旋转

#### 3.7.7 排八神

- 起点：值符神放直符宫
- 阳遁顺布、阴遁逆布（详见 §3.4）

### 3.8 用神规则（按 questionType）

| questionType | 主用神（看哪个干） | 辅看（门 / 星 / 神） | 备注 |
|---|---|---|---|
| career | 庚（官星） | 值符（贵人）+ 开门（机会门） | 求职、晋升、被领导赏识 |
| wealth | 时干（求测者）+ 庚（财源） | 生门（求财门）+ 值符（贵人） | 求财、投资、收入 |
| marriage 男 | 时干（自己）+ 庚（妻） | 六合（媒）+ 太阴（女性）+ 生门（情感升温） | 找对象、看妻 |
| marriage 女 | 时干（自己）+ 庚（夫） | 六合 + 值符（贵人）+ 开门（缘分到来） | 找对象、看夫 |
| kids | 子星（具体看局，常用 时干 / 庚 / 天蓬阴位） | 九地（藏伏育子）+ 生门 | 子女缘、生育 |
| parents | 父母印星（视局而定，常用 戊 / 己） | 值符（贵人）+ 太阴（暗助） | 父母健康、孝道事 |
| health | 年命星（年柱地支对应宫位的星） | 天蓬（病气星）+ 天芮（病气）+ 死门（重病）+ 玄武（暗损） | 疾病、康复 |
| event | 时干（求测者） | 看全局格局吉凶倾向 | 综合事件 |
| general | 时干 + 值符 | 看格局总倾向 | 通用 / 模糊问题 |

实施时 `lib/qimen/data/yongshen-rules.ts` 按此表填充。每条规则形式：

```ts
{
  questionType: 'career',
  primaryGan: '庚',
  secondaryShen: '值符',
  secondaryMen: '开门',
  // 用法：找到主用神干所在宫 = 用神宫
  //      检查辅看的门/神是否同宫 → 加分
}
```

### 3.9 关于起局表（jieqi-ju.ts）数据精度提示

72 起局 entry（24 节气 × 3 元）不在本 spec 列出（数据量大、需独立验证）。

实施时严格按 **ADR-6 三重验证流程**填充 `lib/qimen/data/jieqi-ju.ts`：
- 来源 ≥ 3 个权威源（《奇门遁甲全书》扫描版 + ziwei.pro + qimendunjia.net + 现代奇门入门书）
- fixture 测试用 5-10 个已知日期对照排盘网站输出
- 三个来源不一致 → 标记"分歧条目"，commit 注明，留考据

---

## 4. 数据层设计

### 4.1 文件结构

```
lib/qimen/
  types.ts                    # QimenChart, Palace, BamenInfo, JiuxingInfo, BashenInfo,
                              # GeJu, YongShenAnalysis, YingQiAnalysis, SetupOptions
  QimenEngine.ts              # 起局核心 + 用神 + 格局 + 应期
  data/
    palaces.ts                # 9 宫基础信息表
    bamen.ts                  # 八门属性表
    jiuxing.ts                # 九星属性表
    bashen.ts                 # 八神属性 + 起神规则
    jieqi-ju.ts               # 24 节气 × 3 元 = 72 局数表（最关键）
    geju.ts                   # 50-60 格局识别规则
    yongshen-rules.ts         # questionType → 用神查找规则
  __tests__/
    QimenEngine.test.ts       # 起局准度测试（5-10 fixture）
    geju.test.ts              # 格局检测测试
```

### 4.2 关键类型

```ts
export interface QimenChart {
  question: string;
  questionType: QuestionType;
  setupTime: string;            // ISO
  trueSolarTime: string;
  jieqi: JieqiName;
  yinYangDun: '阳' | '阴';
  juNumber: 1|2|3|4|5|6|7|8|9;
  yuan: '上' | '中' | '下';

  palaces: Palace[];            // 9 个，按宫 ID 1-9 排
  yongShen: YongShenAnalysis;
  geJu: GeJu[];                  // 命中的格局列表
  yingQi: YingQiAnalysis;
}

export interface Palace {
  id: 1|2|3|4|5|6|7|8|9;
  name: string;                 // 坎宫、坤宫...
  position: string;             // 北、西南...
  wuXing: WuXing;
  diPanGan: TianGan | null;     // 中宫为 null
  tianPanGan: TianGan | null;
  bamen: BamenName | null;      // 中宫无门
  jiuxing: JiuxingName | null;
  bashen: BashenName | null;
}

export interface YongShenAnalysis {
  type: string;                 // '庚'、'乙' 等用神干
  palaceId: 1|2|3|4|5|6|7|8|9;
  state: '旺' | '相' | '休' | '囚' | '死' | '不上卦';
  summary: string;              // 一句话描述：'庚临艮宫，得生门 + 天任 + 九地'
  interactions: string[];
}

export interface GeJu {
  name: string;                 // '飞鸟跌穴'
  type: '吉' | '凶' | '中性';
  description: string;          // '丁奇逢生门，求事易成'
  palaceIds?: number[];         // 涉及的宫位
}

export interface YingQiAnalysis {
  description: string;
  factors: string[];
}
```

### 4.3 QimenEngine 类签名

```ts
export class QimenEngine {
  setup(opts: SetupOptions): QimenChart;
}

export interface SetupOptions {
  setupTime?: Date;             // 默认 now
  longitude?: number;           // 真太阳时校正用，默认 116.4 (北京)
  question: string;
  questionType: QuestionType;
  gender?: '男' | '女';
}
```

### 4.4 起局 7 步

```
[1] 真太阳时校正（复用 lib/bazi/TrueSolarTime.ts）
[2] lunisolar 算节气
[3] 阴阳遁判定（冬至～夏至前=阳；夏至～冬至前=阴）
[4] 上中下元定局数（查 jieqi-ju.ts 表）
[5] 起 9 宫地盘干（按局数定戊位起点，三奇六仪顺/逆排）
[6] 旋天盘 + 排八门 + 排九星 + 排八神
[7] 用神选择 + 格局检测 + 应期推算
```

---

## 5. AI 工具集成

### 5.1 新工具 `setup_qimen`

```ts
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
          description: 'questionType=marriage 时区分用神（女问看官，男问看财）',
        },
      },
      required: ['question'],
    },
  },
}
```

### 5.2 工具策略追加（TOOL_STRATEGY）

```
9. 战略级重大决策（"要不要换城市/移民/换行业/创业"/"明年这件大事"
   /"这家公司能干长吗"/"我要不要和这个人结婚")→ 用 setup_qimen
10. 普通决策（"她回我吗"/"明天面试结果"）→ 用 cast_liuyao
11. 区分启发：影响时间跨度 / 影响生活面广度 / 严肃度
    模糊时优先 cast_liuyao（更通俗）
```

---

## 6. AI Prompt 工程

### 6.1 THINKER_PROMPT 路由块更新

参见 §5.2 的 TOOL_STRATEGY 追加。THINKER prompt 的"# 工具路由"段落复用既有 + 加 §5.2 的 9-11 条。

### 6.2 INTERPRETER_PROMPT 黑名单 + 三段结构

**追加奇门术语黑名单**：

```
（奇门）三奇、六仪、八门（休生伤杜景死惊开）、九星（蓬芮冲辅禽心柱任英）、
八神（值符、腾蛇、太阴、六合、白虎、玄武、九地、九天）、
飞鸟跌穴、青龙返首、玉女守门、白虎猖狂、伏吟、反吟、击刑、值符、值使、
入墓、阳遁、阴遁、上元中元下元、用神临宫、地盘天盘……
```

**追加奇门解读三段结构**（仅起局类问题适用）：

```
当推演引擎输出含"setup_qimen"工具结果时（即起局类问题），解读结构遵循：
- 第 1 段：用神宫给出的"现状画面"（用形象比喻）
  ✅ "你这件事此刻像一棵刚扎根的小树，下面有结实的土，上面是清晨的光"
  ❌ "你的用神庚临艮宫，得生门天任九地"
- 第 2 段：关键格局给出的"力量与阻力"
  ✅ "有一股 '稳中带升' 的势头在帮你，但中央位置有点滞涩"
  ❌ "飞鸟跌穴吉格 + 中宫伏吟凶格"
- 第 3 段：应期窗口（时间轴）
  ✅ "这件事大致会在未来 1-3 个月内见分晓"
  ❌ "应在乙日或乙月（春分前后）"
```

### 6.3 narrateTool 增量

```ts
if (name === 'setup_qimen') {
  return '布盘九宫，定准时辰' + tail;
}
```

无 emoji，与 Phase 2 风格一致。

---

## 7. UI 设计

### 7.1 起局动画（QimenSetupAnimation）

3.3 秒入场动画，纯 reanimated 实现。

```
T=0.0s：3×3 灰虚线框架淡入
T=0.5s：中宫朱砂点定（"局心"）
T=0.7-2.3s：8 宫各 0.2s，5 层信息（地盘干 / 天盘干 / 八门 / 九星 / 八神）依次填入
T=2.5s：用神宫朱砂边框高亮 + 微缩放
T=3.0s：局名浮现 "阳遁 7 局 · 谷雨中元"
T=3.3s：动画完成，9 宫盘缩小淡出，用神宫聚焦卡作为主显示
```

### 7.2 主气泡布局

```
[起局动画 3 秒，仅在流式中显示]
       ↓
[用神宫聚焦卡 90×120pt]
   宫名 + 位序
   天盘干 / 地盘干
   八门 · 九星 · 八神
       ↓
[相邻宫标签横排，3 个]
   [离宫·开门] [巽宫·杜门] [中宫·寄宫]
       ↓
[CoT 卡 折叠]
       ↓
[interpretation 解读正文]
       ↓
[Evidence 卡 4-6 行]
   局：阳遁 7 局 · 谷雨中元
   用神：庚 · 临艮宫 · 旺
   格局：飞鸟跌穴（吉）
   应期：约 1-3 月
   ⌄ 查看完整推演 / 9 宫盘
```

### 7.3 BottomSheet 完整 9 宫盘（FullChart9）

3×3 网格，每格 5 行小字（地盘干 + 天盘干 + 八门 + 九星 + 八神）+ 用神宫朱砂边框 + 凶格宫底色暗淡。

下方分两节：
- **格局列表**：每个命中格局一行（名 + 吉凶 + 一句话描述）
- **推演过程**：Call 1 thinker 文本

### 7.4 ModePicker（不改）

复用现有 3 模式（随心问 / 起一卦 / 看命盘）。奇门通过 THINKER 路由自动选用，不加新模式（ADR-1）。

---

## 8. 数据流

```
user input + chatMode (来自 ModePicker)
  ↓
sendOrchestrated(question, forceMode?)
  ↓
THINKER：判断"战略级重大决策"→ 调 setup_qimen
  ↓
QimenEngine.setup() → 完整 QimenChart
  ↓
THINKER 看用神宫 + 格局列表 + 应期，做硬推演
  ↓
INTERPRETER：[interpretation] 三段画面感语言 + [evidence] 4-6 行术语
  ↓
客户端：
  - 起局动画（仅流式）
  - 用神宫聚焦卡 + 相邻宫标签
  - 解读正文 (RichContent)
  - Evidence 卡（4-6 行）
  - BottomSheet：完整 9 宫盘 + 格局列表 + Call 1 thinker
```

---

## 9. 文件结构总览

### 新增

```
lib/qimen/
  types.ts                    # QimenChart / Palace / GeJu / YongShenAnalysis / 等
  QimenEngine.ts              # 起局 7 步 + 用神 + 格局 + 应期
  data/
    palaces.ts                # 9 宫基础信息
    bamen.ts                  # 八门 8 个 entry
    jiuxing.ts                # 九星 9 个 entry
    bashen.ts                 # 八神 8 个 entry + 起神规则
    jieqi-ju.ts               # 24 节气 × 3 元 = 72 局数表
    geju.ts                   # 50-60 格局识别规则
    yongshen-rules.ts         # questionType → 用神查找规则
  __tests__/
    QimenEngine.test.ts       # 起局准度（5-10 fixture）
    geju.test.ts              # 格局检测（每个格局 ≥ 1 fixture）

lib/ai/tools/
  qimen.ts                    # setup_qimen 工具（包装 QimenEngine）
  __tests__/qimen.test.ts

components/qimen/
  QimenSetupAnimation.tsx     # 起局 3.3 秒动画
  YongShenPalaceCard.tsx      # 用神宫聚焦卡
  AdjacentPalaceTags.tsx      # 相邻宫标签
  FullChart9.tsx              # 完整 9 宫盘（仅 BottomSheet）
```

### 修改

```
lib/ai/index.ts               # ChatMessage.orchestration 加 qimenChart? 字段
                              # THINKER 加路由 9-11 条
                              # INTERPRETER 加奇门黑名单 + 三段结构
lib/ai/tools/index.ts         # ALL_TOOLS / ALL_HANDLERS 加 setup_qimen
                              # TOOL_STRATEGY 加 9-11 条
app/(tabs)/insight.tsx        # liveQimenChart state + 流式动画 + 历史回显
                              # narrateTool 加 setup_qimen case
components/ai/FullReasoningSheet.tsx  # 新增 FullChart9 渲染分支 + 格局列表
```

---

## 10. 测试策略

### 10.1 单元测试

| 模块 | 测试目标 |
|---|---|
| `QimenEngine.setup()` | 5-10 fixture：固定生辰 + 时辰 → 已知阴阳遁 + 局数 + 用神宫位 |
| `geju.ts` 检测函数 | 每个格局 ≥ 1 fixture（命中 + 不命中 case） |
| `yongshen-rules.ts` | 每个 questionType + gender 组合 1 case |
| `setup_qimen` 工具 | 工具签名 + handler shape + 错误参数兜底 |

总测试数预计 60-80 个新测试（格局多）。

### 10.2 数据准度三重验证

每张数据表（jieqi-ju, palaces, bamen, jiuxing, bashen, geju, yongshen-rules）：

1. 来源 ≥ 3 个权威源（《奇门遁甲全书》扫描版 + ziwei.pro + qimendunjia.net + 现代奇门入门书）
2. 数据填充后用 5 个已知排盘网站结果做 fixture 比对
3. 每个格局规则用 3 个示例 case 验证

### 10.3 集成 / 设备测试

| 用户操作 | 期望 |
|---|---|
| 输入"我要不要换城市生活"（默认） | AI 自动调 setup_qimen，气泡内 3.3 秒起局动画 |
| 输入"她回我吗" | AI 调 cast_liuyao（六爻），不起局 |
| 输入"今年事业怎么样" | AI 走命理，不起局 |
| 主气泡只显示用神宫卡 + 3 邻宫标签 | 视觉聚焦，不画完整 9 宫盘 |
| 点 evidence 卡 → BottomSheet | 显示完整 9 宫盘 + 格局列表 |
| 历史消息回显 | 用神宫卡静态显示（无动画） |
| 解读正文不出现奇门术语 | "用神临艮"等术语只在 evidence 卡 |

---

## 11. 已知风险与回退

### R1：72 局数表数据错误
**风险**：起局表是奇门核心，错一个 entry 整个盘错。
**缓解**：ADR-6 三重验证 + 5-10 个 fixture 测试，每个 fixture 都用对照网站确认。如发现单条错误，单条修复。

### R2：格局检测规则覆盖不全
**风险**：50-60 格局看似全，但古籍记载 100+ 个，可能遗漏冷门重要格局。
**缓解**：
- 50-60 是"一线奇门软件标准覆盖"，不是 MVP 折扣
- 用户实测时如果发现重大遗漏（"这局明明应该有 X 格"），单条添加即可
- 不在 R1 critical 级别

### R3：节气切换边界 1 天误判
**风险**：拆补法不做置闰，节气精确切换时刻附近的盘可能差 1 天。
**缓解**：lunisolar 库给出真节气精确到分钟级；边界误差最多 1 天，对长期决策（奇门主场景）可接受。

### R4：起局动画在低端机掉帧
**风险**：3.3 秒 + 5 层 × 8 宫 = 40 个动画元素同时跑。
**缓解**：用 fade + scale（无复杂 transform），分层 stagger（每宫 0.2s 间隔），iPhone 16 Plus 实测 60fps 即可。

### R5：AI 误把"重大问题"判断为"普通问题"
**风险**：用户问"我要不要换工作" → AI 调 cast_liuyao 而不是 setup_qimen。
**缓解**：
- THINKER prompt 给 4-5 条 ✅/❌ 例子
- 用户可强制 `user_force_mode=liuyao`（已有）
- 缺少 `user_force_mode=qimen` 但 ADR-1 已选择不加 ModePicker —— 接受这个边界

---

## 12. 与既往 spec 的关系

### 与 `2026-04-25-ai-orchestration-and-divination-systems-design.md`

完全延续 Phase 1 架构：tool-use orchestrator、双角色 prompt、preprocessOrchestration、CoT/Evidence/BottomSheet 三组件、流式光标。

### 与 `2026-04-25-liuyao-divination-design.md`（Phase 2）

ADR-6（去 emoji）继续遵循。INTERPRETER 三段结构与 Phase 2 六爻类似（区别：奇门用"用神宫现状 + 格局力量 + 应期窗口"；六爻用"主卦现状 + 变卦走向 + 动爻关键节点"）。新工具 `setup_qimen` 注册到既有 ALL_TOOLS / TOOL_STRATEGY，不动 orchestrator 核心。

`questionType` 类型（career / wealth / marriage / kids / parents / health / event / general）与 Phase 2 复用，AI 工具签名一致，前端不用改 ModePicker。

### Phase 4 接口预留

- ChatMessage.orchestration 已支持多种"事件类"载荷（`hexagram` Phase 2 + `qimenChart` Phase 3），Phase 4 加抽签 / 黄历可加 `qiansi?` / `huangli?`
- `narrateTool` 函数体已是按 `name` 分支的查找表，加新工具加新 case 即可
- BottomSheet 已支持"按类型分支渲染"，Phase 4 加新类型加新分支

---

## 13. 不在本 spec 范围

明确**本 spec 不解决**的事项：

- 奇门历史回顾页面（"我以往起过什么局"）—— Phase 4
- 奇门盘的 SVG 美化版（书法笔触感、纸纹）—— 极简版本足够
- 真节气精确到秒（边界 case 修复）—— ADR-7 选择不做
- 100+ 个奇门冷门格局 —— ADR-5 范围内 50-60 个已是 MVP 完整集
- AI 主动反问"这是个重大决策吗"—— 增加交互摩擦
- Pro 订阅 / 付费墙
- 多人合局 / 替他人起局 —— 同 Phase 2 决议
- 实物摇晃触发起局 —— 同 Phase 2 决议
- 紫微 12 宫可视化 —— Phase 4
