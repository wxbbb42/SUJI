# Grounding Audit Checklist

> 给某个引擎/库做 grounding audit 时按这套清单走。目的：把"代码用的每条规则、表、数字"逐条点出 grounding 状态，并决定可否继续使用。
>
> 适用范围：`lib/bazi/`、`lib/ziwei/`、`lib/qimen/`、`lib/divination/`、`lib/marriage/` 等所有命理算法目录，以及它们的工程库依赖。

---

## 输入

- [ ] 目标文件（引擎或库源码）
- [ ] 现有 [`claims.json`](../claims.json)
- [ ] 现有 [`sources.json`](../sources.json)
- [ ] 已有 [`reading-notes/`](../reading-notes/) 与 [`audit/`](.) 报告
- [ ] 目标领域的 P0 古籍 source list（见 [`READING_PLAN.md`](../READING_PLAN.md)）

## 步骤

### 1. 决策切分

把目标文件切成独立的"算法决策"。每一项是：
- 一个 `readonly TABLE`（查表数据）
- 一个 `compute*` 函数（计算逻辑）
- 一个 `if / else` 分支（路径分流）
- **一个具体数字常量**（阈值、权重、加成系数）

**关键**：数字常量必须单独算一项决策，不能藏在函数里被忽略。

### 2. 现有 claim 映射

每条决策回查 [`claims.json`](../claims.json)，看是否已有对应 claim id。

### 3. 古籍引用核

代码注释引了古籍的，校原文是否一致；引了但 claims.json 没登记的标 `text_cited_no_claim`。

### 4. 上游搜索（**对每个具体数字 / 阈值 / 表必做**）

> 加入时间：2026-04-30。起因：在 BaziEngine grounding audit 中将 `2.0/1.5/0.7/0.5` 旺相休囚死系数标为"工程一拍"，但实际可溯到何建忠派民间算法。"找不到 = 我们瞎拍"是错误默认。

主动 grep 以下源头，判断该数字/表是否来自可识别的派别或开源库：

| 检索路径 | 用途 |
|---|---|
| `git log --all -- <file>` + `git blame` | 找原作者意图、commit message、可能的 attribution |
| `package.json` + 依赖库源码 / 文档 | 确认是否上游 lib 提供该数字（许多 npm/pip 包不暴露评分但内部有） |
| GitHub code search | 用 `数字组合 + 中文术语`（如 `"旺相休囚死" "2.0" "1.5"`）跨仓查同款 |
| Google + 知乎 + CSDN + 豆瓣 | 同样组合；中文圈算法常在博客而非论文里 |
| 现代 D-tier 命理家关键词 | 何建忠（《八字心理推命学》）、邵伟华、李顺祥、宋英成、陈品宏、潘子端、台湾派、香港派、盲派… |
| 命理论坛 / 软件项目 | 大六壬 / 八字 / 紫微的工程社区有自己的"民间法"传统 |

**判定与标签**：
- 能溯到 A-tier 古籍（古籍直接给出该数字）→ `text_cited_with_claim`
- 能溯到 D-tier 现代派别（如何建忠）→ `modern_practitioner_scheme`，**必须在 [`sources.json`](../sources.json) 加 D-tier 条目并在 claim/code 注释引用**
- 能溯到工程库内部 → `c_tier_dependency`
- 实在溯不到 → `engineering_threshold_no_documented_source`

**反默认**：如果只查了 1–2 个源头就放弃，标错的概率很高。给单个数字花 5–10 分钟跨源核查是合理的成本。

### 5. 政策违反扫描

描述层 / 文案层 / 字符串字面量是否违反已确立 policy：
- `product.no-absolute-fortune-claims`（绝对预测、恐吓、医学/法律/财务确定性）
- `bazi.branch-relations.not-absolute-omens`
- `bazi.ziping-zhenquan.stars-do-not-decide-geju`
- 其他 `*.policy` claims

### 6. 状态分桶

每条决策落到下列状态之一：

| 状态 | 含义 |
|---|---|
| `foundational` | 公认基础，不需要 claim（如天干顺序、五行生克） |
| `text_cited_with_claim` | 代码 + claim + 古籍引文齐全 |
| `text_cited_with_fixture` | **金标准**：三对齐 + 单测验证 |
| `text_cited_no_claim` | 代码注释引古籍但 claims.json 没登记 |
| `modern_practitioner_scheme` | 数字属可识别近现代命理派别（D-tier），有 attribution |
| `engineering_threshold_no_documented_source` | 数字纯工程判断，溯源失败 |
| `mvp_simplified` | 算法显著简化于古籍 |
| `c_tier_dependency` | 工程库提供，无 A-tier 验证 |
| `product_policy_violation_risk` | 描述层违反已确立产品政策 |

### 7. 报告产出

输出到 `docs/mingli/audit/YYYY-MM-DD-<scope>-grounding.md`。固定结构：
- TL;DR + 总览数字（决策数 / 各状态数 / 真正 grounded 比例 + fixture 覆盖率）
- 方法（链回到本 CHECKLIST.md）
- 详细决策表（行号 + 状态 + claim id + 备注）
- 分桶分析（重点风险类目）
- 推荐动作 ROI 排序
- 自我披露（没改什么、没读什么、没核实到的边界）

### 8. 决策动作

根据状态分桶决定下一步动作：

| 状态 | 动作 |
|---|---|
| `text_cited_no_claim` | 升 claim，不读新书 |
| `modern_practitioner_scheme` | 在 sources.json 加 D-tier 条目；在 claim 注明派别；评估"是否权威足够留用" |
| `engineering_threshold_no_documented_source` | **默认动作：移除或隔离**。除非用户明确批准保留并标注为产品估算 |
| `mvp_simplified` | 标 claim、写 caveat、规划经典化路径 |
| `c_tier_dependency` | 加 fixture / 加 A-tier 兜底 |
| `product_policy_violation_risk` | 立即修文案 |

---

## 不要做的事

- **不要**在 audit 中改算法、改 claim、改代码（除非另行授权）
- **不要**把"找不到来源"默认为"是工程拍的"——必须先做步骤 4
- **不要**把表登记当 claim 通胀（每条 claim 必须能对应到具体代码动作）
- **不要**跳过具体数字常量——它们往往是产品输出的真实守门员

---

## 修订记录

- 2026-04-30：v1 创建。来源是 BaziEngine grounding audit（[`2026-04-30-bazi-engine-grounding.md`](2026-04-30-bazi-engine-grounding.md)）后用户指出 audit 没主动追溯数字上游。新增"步骤 4 上游搜索"和 `modern_practitioner_scheme` 状态。
