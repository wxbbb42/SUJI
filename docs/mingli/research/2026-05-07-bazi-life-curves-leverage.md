# bazi-life-curves leverage report (2026-05-07)

> Source: https://github.com/XiaoChu-1208/bazi-life-curves @ ad8fdeceac3d74b9682ce1df362e7a497dc91d2c
> License: MIT (verified)
> Repo size: ~25.5k Python LoC in `scripts/` + ~5k 行文档
> Read by: Claude (Explore agent), 2026-05-07
> Purpose: identify what SUJI's BaziEngine Path C rewrite can borrow vs. design from scratch

## TL;DR

**3 个值得直接借鉴的设计**
1. **多流派加权投票 + open_phase 逃逸阀**（`_school_registry.py` + `multi_school_vote.py`）— 4 派加权投票（25/40/30/0）+ 派别冲突检测 + 后验 < 0.55 时承认"不知道"。直接对标 SUJI"谁打败谁"的决策层缺口。
2. **Phase 注册表模式 + 古籍出处强制**（`_phase_registry.py`）— 每个相位带 `id/source/requires/reversal_overrides`，注册时强制非空 `source`。给 SUJI 的 `GeJuV2` 提供稳定身份管理。
3. **通根度分档**（`_bazi_core.compute_dayuan_root_strength`）— 本气 1.0 / 中气 0.5 / 余气 0.2，输出 5 档 label（无根→强根）。替代当前 `2.0/1.5/0.7/0.5` 数字黑盒。

**完全跳过**：LLM 流式管道、HTML 渲染、MCP server、5 维 28 题问卷、virtue_motifs。

**Test fixtures 可直接抄**：`官印相生`、`伤官生财`、`yangren_chong_cai`，加 `phase_decision_determinism` 黄金测集。

---

## 1. 架构总览

bazi-life-curves 的总体设计遵循 "**precision over recall, 多解共存, 不允许独断**" 范式（SKILL.md §"v9 范式转换"）。

**核心三层**：

1. **识别层（Identification）** — `_bazi_core.py` + `rare_phase_detector.py`
   - P1–P6 共 6 组 detector 穷尽所有可能的相位候选（14 个 core + ~60 个 rare）
   - 每个 detector 给出 confidence（0.0–1.0）与古籍出处
   - 输出候选池 + 先验分布

2. **消歧层（Disambiguation）** — `adaptive_elicit.py` + 宿主 AskQuestion UI
   - 5 维度 28 题结构化问卷（民族志/家庭、关系、流年、中医体征、自我体感）
   - 每题 phase-discriminative（≥2 相位间≥0.20 概率差）+ 反方向选项
   - 硬体征权重 2× 软自述权重

3. **决策层（Decision）** — `phase_posterior.py` + `multi_school_vote.py`
   - 贝叶斯后验：P(phase | answers) ∝ prior × ∏ likelihood^{weight}
   - 4 流派加权投票（子平 1.0 / 滴天髓 1.0 / 穷通宝鉴 0.9 / 盲派 0.9）
   - top1 < 0.55 OR gap < 0.10 → `open_phase`（诚实承认"不知道"）

**对 SUJI 的启发**：
- 多派融合 → 不让任何一派独大
- 格局优先于用神的链路结构
- 燥湿作为独立维度（不依赖身强弱）— SUJI 当前没有这层
- 通根度精细化 — 比当前数字阈值更可理解
- Confirmed facts 跨 session 记忆 — SUJI 当前没有

---

## 2. 可借鉴（按 ROI 排序）

### 2.1 多流派加权投票框架 + open_phase 逃逸阀

**What it is**：
`_school_registry.py` 定义 6 个流派（子平真诠、滴天髓、穷通宝鉴、盲派 4 个权重 > 0；紫微、铁板权重 0 占位），每个流派提供 `judge(bazi) -> List[candidate]`。`multi_school_vote.py` 的 `vote()` 对所有候选做**加权平均**后验，触发多条规则决定是否落 `open_phase`。

**Why it fits SUJI**：
当前 `GeJuV2` 的核心痛点是"谁打败谁"——弃命从财 vs 调候反向 vs 格局派判定无机制仲裁。bazi-life-curves 的解法：
- 不靠单一派别"人工规则"
- 而是让派别在**后验层竞争**
- 没有派别赢得多数支持 → 坦白说不知道（ethical choice）

**How to port**（TypeScript 伪代码）：
```ts
const SCHOOLS = {
  ziping:   { weight: 0.25, judge: detectorGeju },
  tiaohou:  { weight: 0.40, judge: detectorClimate },
  geju:     { weight: 0.30, judge: detectorChengbai },
  mangpai:  { weight: 0,    voteType: "events_only" },  // 不进融合，仅事件
};

function decidePhase(bazi: Bazi): PhaseDecision {
  const votes = aggregateVotes(SCHOOLS, bazi);
  const [top1, top2] = votes.slice(0, 2);
  if (top1.posterior < 0.55 || top1.posterior - top2.posterior < 0.10) {
    return { phase: "open_phase", candidates: votes.slice(0, 3), reason: "uncertain" };
  }
  return { phase: top1.id, confidence: top1.posterior };
}
```

**File:line refs**：
- `_school_registry.py:157–194` — 6 流派注册表
- `multi_school_vote.py` — voting 逻辑
- `phase_posterior.py:80–120` — 决策阈值
- `references/phase_decision_protocol.md §5` — 决策阈值学理

**Complexity**: Medium. Python 30–50 行；TypeScript 100–150 行（含类型）。

---

### 2.2 三档通根度精细化（本气/中气/余气 → 5 档 label）

**What it is**：
`compute_dayuan_root_strength()` 把日主的根按藏干阶级细分：
- 本气 1.0（如 子 的癸）
- 中气 0.5（如 丑 的癸）
- 余气 0.2（如 戌 的丁）

输出 5 档 label（无根/微根/弱根/中根/强根），阈值 < 0.30 / < 0.70 / < 1.50 / < 2.50 / >= 2.50。

**Why it fits SUJI**：
当前 SUJI 用 `2.0/1.5/0.7/0.5` 数字黑盒。bazi-life-curves 的做法：
- 明确"本气 vs 中气 vs 余气"权重原因（古籍根据：藏干主气论）
- 5 档 label 比数字更易**转化为逻辑判断**（`if label == "无根": phase = "cong_cai"`）
- 直接支持 `RiZhuStructure.tongGen` + `chengBai` 子状态枚举

**How to port**（TypeScript 伪代码）：
```ts
type RootTier = "无根" | "微根" | "弱根" | "中根" | "强根";

function computeRootStrength(dayGan: TianGan, branches: DiZhi[]): RootStrength {
  const TIER_WEIGHT = [1.0, 0.5, 0.2]; // 本/中/余
  let bijie = 0, yin = 0;
  const details = [];
  for (const branch of branches) {
    ZHI_HIDDEN_GAN[branch].forEach((hg, tier) => {
      const w = TIER_WEIGHT[tier];
      if (isSameElement(dayGan, hg)) { bijie += w; details.push({...}); }
      else if (isShengElement(hg, dayGan)) { yin += w; details.push({...}); }
    });
  }
  const total = bijie + yin;
  const label: RootTier =
    total < 0.30 ? "无根" :
    total < 0.70 ? "微根" :
    total < 1.50 ? "弱根" :
    total < 2.50 ? "中根" : "强根";
  return { bijieRoot: bijie, yinRoot: yin, totalRoot: total, label, details };
}
```

**File:line refs**：
- `_bazi_core.py:192–284` — `compute_dayuan_root_strength()` 完整实现
- `_bazi_core.py:210` — `ROOT_TIER_WEIGHT` 定义
- `references/methodology.md §通根度` — 学理说明

**Complexity**: Low. 核心 30 行 Python；TypeScript 50–70 行。

> ⚠️ **注意**：阈值 0.30 / 0.70 / 1.50 / 2.50 仍是工程经验值，不是古籍数。SUJI 借用时应在 claim 标 `engineering_threshold_borrowed_from_open_source` + 引 bazi-life-curves attribution。**比当前的 9 个数字门槛好的地方**是：(a) 输出语义化 label，(b) 权重 1.0/0.5/0.2 有古籍主气论支持，(c) 只剩 4 个阈值在 label 切分上。

---

### 2.3 Phase 注册表模式 + 反向规则 DSL

**What it is**：
`_phase_registry.py` 定义 `PhaseMeta` dataclass，每个相位记录：
- `id` — 稳定标识（如 `yangren_chong_cai`），冻结不可改
- `name_cn` — 展示名
- `school` — 流派
- `dimension` — 维度（power / zuogong / cong / climate / huaqi / special）
- `source` — **古籍出处（强制必填，违反报错）**
- `requires` — 成立条件
- `zuogong_trigger_branches` — 做功应期支
- `reversal_overrides` — 盲派事件反向规则

**Why it fits SUJI**：
SUJI 正在设计 `GeJuV2 { yongShen, xiangShen, chengBai, jiuYing, jibie }`。当前问题：
- 没有统一 phase 身份管理（id 易漂移、古籍出处易丢失）
- `confirmed_facts` 跨版本兼容需要稳定 id
- 盲派反向规则需要结构化管理，不能散落业务逻辑

**How to port**（TypeScript 伪代码）：
```ts
interface PhaseMeta {
  id: string;                           // 冻结，不可改
  nameCn: string;
  school: SchoolName;
  dimension: "power" | "zuogong" | "climate" | "huaqi" | "special";
  source: string;                       // 强制非空
  requires?: Record<string, string>;    // {"strength.label": ">= 中和"}
  zuogongTriggerBranches?: DiZhi[];
  reversalOverrides?: Record<string, "positive"|"neutral"|"negative">;
}

class PhaseRegistry {
  register(meta: PhaseMeta) {
    if (this.map.has(meta.id)) throw new Error(`id 冲突: ${meta.id}`);
    if (!meta.source || meta.source.includes("自创")) {
      throw new Error(`${meta.id} 缺古籍出处或自创规则`);
    }
    this.map.set(meta.id, meta);
  }
}
```

**File:line refs**：
- `_phase_registry.py:26–73` — `PhaseMeta` dataclass
- `_phase_registry.py:94–104` — register + 出处强制检查
- `_phase_registry.py:107–176` — v8 baseline 14 个 core phase
- `_phase_registry.py:180–249` — v9 新增的做功 phase（含 `reversal_overrides` 例子）

**Complexity**: Low-Medium. TypeScript 100–150 行（dataclass + registry 类）。最耗时的是**枚举所有已有格局**并按 schema 整理。

---

### 2.4 Mangpai 反向规则 DSL（YAML 化 + 结构反向）

**What it is**：
`references/mangpai_reversal_rules.yaml` 定义盲派 11 条事件反向规则：

```yaml
shang_guan_jian_guan:  # 伤官见官
  base_polarity: negative
  reversal_conditions:
    - condition: "身强用官"
      override: negative
    - condition: "身弱印护"
      override: positive  # 反正
  source: "《滴天髓》伤官章 + 盲派象法"
```

**Why it fits SUJI**：
《穷通宝鉴》与现代盲派都强调"相同事件，不同结构下完全反向"：比劫在身强损财，身弱反帮身。显式化好处：
1. 防止"硬编码在业务逻辑导致遗漏"
2. LLM 解读层可查询"这个事件在这盘是否反向"
3. 为合盘场景提供"夫妻一方比劫是另一方帮手"推论

**File:line refs**：
- `references/mangpai_reversal_rules.yaml` — 规则集
- `_mangpai_reversal.py` — YAML 评估器
- `scripts/mangpai_events.py:206–214` — 应用示例

**Complexity**: Low. YAML schema + TypeScript 评估器 50–100 行。

---

### 2.5 化气格 + 神煞自动识别

**What it is**：
- `_bazi_core.detect_huaqi_pattern()` 检测五合化气（甲己合土等），满足"月令为化神 + 化神有根 + 日干无根"自动改 phase 为 `huaqi_to_<化神>`
- `_bazi_core.detect_shensha()` 识别天乙贵人、文昌、驿马等 8 类神煞，影响终生 baseline ±0.3~0.4，流年 ±0.5~1.0

**Why it fits SUJI**：
SUJI 当前都有，但化气格判定用 `> 35%` 阈值（不可解释），神煞描述违反 `product.no-absolute-fortune-claims`。借用 bazi-life-curves 的检测器可：
- 把化气阈值换成结构化条件检查（化神有根 + 日干无根）
- 把神煞从"凶吉断语"改为"baseline 调味"的弱影响（不操格局成败之权，符合《子平真诠》"星辰无关格局"）

**File:line refs**：
- `_bazi_core.py:~500+` — 完整实现
- `scripts/score_curves.py:~185–192` — apply_geju_override 应用

**Complexity**: Low. 两个检测器合计 100–150 行 TypeScript。

---

### 2.6 confirmed_facts 跨会话记忆

**What it is**：
每次用户校验后，算法把 R0/R1/R2 答案 + 用户自由事实 + 结构化纠错 写进 `confirmed_facts.json`。下次跑同一八字时：
1. 跳过已确认正确的 trait
2. 应用之前的结构化纠错（"这条判断被证伪过，下次跳过"）
3. 保留历史反馈供 LLM 查阅

**Why it fits SUJI**：
SUJI 当前每次跑都从零开始。加这层后：
- 用户跑同一八字两次不重复答校验题
- 之前算法判断被用户证伪了（"我不是这个相位"），下次不踩雷
- 给 LLM 解读层提供"这盘已确认事实"作上下文

**File:line refs**：
- `scripts/save_confirmed_facts.py`
- `scripts/solve_bazi.py` 顶部加载逻辑
- `SKILL.md §0`

**Complexity**: Medium. Schema 设计 + I/O，TypeScript 100–200 行。**SUJI 当前 MingPan 是内存对象，要做这个需要先决定持久化位置（Supabase / AsyncStorage / 本地 JSON）**。

---

## 3. Test fixtures 可移植清单

| 命例 | 八字 | 格局 | 测的是什么 | 来源 | TS 难度 |
|---|---|---|---|---|---|
| guan_yin_xiang_sheng | examples/guan_yin_xiang_sheng.bazi.json | 官印相生格 | 子平真诠月令格识别、三派融合、R1/R2 校验 | examples/ | 低 |
| shang_guan_sheng_cai | examples/shang_guan_sheng_cai.bazi.json | 伤官生财格 | 盲派象法识别、反向规则、做功应期 | examples/_v75_e2e/ | 低 |
| yangren_chong_cai | tests/test_yangren_chong_cai.py（丙子 丙申 壬午 乙巳） | 阳刃冲财做功格 | v9.1 做功维度、L1–L7 全链路、反转事件 ≥10 | tests/ | 中 |
| multi_school_vote | tests/test_multi_school_vote.py | 多派分歧 | 4 派加权投票、open_phase 落地、conflict alert | tests/ | 中 |
| phase_decision_determinism | tests/test_phase_decision_determinism.py | 10 个金标准 + 性别对称 | bit-for-bit 确定性、posterior 稳定性 | tests/ | 低（黄金测）|

**移植优先级**：
1. **guan_yin_xiang_sheng** — 最简单，v9 认证通过的"好盘"
2. **shang_guan_sheng_cai** — 测盲派象法
3. **yangren_chong_cai** — 复杂但能测出"做功维度"价值
4. **phase_decision_determinism** — 黄金测集

---

## 4. Skip（不要花时间）

- ❌ **LLM 流式输出管道**（`adaptive_elicit.py` + `streaming_pipeline.py` + `append_analysis_node.py`）— SUJI 有自己的 LLM 集成；v9 的"流式物理审计"对 TypeScript 工程无意义
- ❌ **virtue_motifs（德性暗线）** — 超出 BaziEngine 职责，SUJI 如果要做应放在上层应用层
- ❌ **HTML/Chart 渲染**（Recharts + Jinja2 + render_artifact.py）— SUJI 有 React Native 前端
- ❌ **MCP server 包装**（`scripts/mcp_server.py`）— Claude Desktop 集成层，与 SUJI 无关
- ❌ **性别/取向现代化复杂度**（v7 `--orientation` + relationship_mode）— 如果 SUJI 要支持，应在 API 层
- ❌ **5 维 28 题校验问卷**（R0/R1/R2/R3 全套 handshake）— 太复杂，SUJI 可 keep simple，3–5 题够用

---

## 5. License & provenance notes

- **License**: MIT（确认）
  - Copyright (c) 2026 XiaoChu-1208 and contributors
  - Full text in `/tmp/suji-research/bazi-life-curves/LICENSE`
- **Author**: XiaoChu-1208（GitHub @XiaoChu-1208）
- **Commit sha**: `ad8fdeceac3d74b9682ce1df362e7a497dc91d2c`（2026-04-28）
- **Repo**: https://github.com/XiaoChu-1208/bazi-life-curves

**借鉴合规**：MIT 是最宽松开源协议，只要保留版权声明就合规。所有借鉴的代码 snippet 必须在 SUJI 代码注释里引出处（file:line）+ 标 `adapted from bazi-life-curves (MIT) by XiaoChu-1208`。

---

## 6. 与 SUJI 自有 reading 的结合点

### A. 三派权重 25/40/30 vs SUJI 的《子平真诠》优先级

**bazi-life-curves**：扶抑 25% + 调候 40% + 格局 30%（calibration/dataset.yaml 5 人 15 事件回测调出）

**SUJI 的读书笔记**（`docs/mingli/reading-notes/2026-05-07-ziping-zhenquan-geju-deepread.md`）：《子平真诠》强调"先观月令以定格局，次看用神以分清浊"——暗示"格局派权重应最高"，与 bazi-life-curves 的 30% 不一致。

**两条路**：
1. 保持 bazi-life-curves 权重（有回测支持）+ 贡献 SUJI 数据扩样本
2. 按《子平真诠》重标定（格局 > 调候 > 扶抑）+ 用户反馈验证

**推荐路线 1**（借已验证权重快速迭代），后用 SUJI 用户数据 A/B 对比。

### B. chengBai/jiuYing vs phase 注册表

**bazi-life-curves**：不区分"成败救应"细致子状态；所有判定落到 14 个 core phase。

**SUJI 设想**：`chengBai` 子类型 + `jiuYing` 应事方向。

**建议两者都要，层次分明**：
1. BaziEngine 的 phase decision 用 bazi-life-curves 14+rare 模式（保多派投票可扩展）
2. `GeJuV2` 的 `chengBai/jiuYing` 是**上层语义化标签**，由 phase → {chengBai, jiuYing} 映射表派生

即：`phase_id="yangren_chong_cai"` → 映射表查 `{chengBai: "成", jiuYing: "主财"}` → LLM 解读使用。

### C. open_phase vs SUJI 的"诚实设计"

**bazi-life-curves**：top1 < 0.55 OR gap < 0.10 → 不独断，列出备解 + 让用户补事件。

**强烈建议 SUJI 在 v1 BaziEngine rewrite 加入 open_phase**：不必全套 R1/R2/R3，但至少要有"后验不确定时主动承认"的逻辑。这与产品政策 `product.no-absolute-fortune-claims` + 《子平真诠》"相从"观念吻合。

---

## 7. 推荐下一步动作（按 ROI）

### 立即（1 周）

1. **复用多流派投票框架** ⭐⭐⭐⭐⭐ — 抄 `_school_registry.py` + `multi_school_vote.py` 骨架到 TypeScript（100–150 行）。直接替代 9 个数字阈值黑盒。**3–5 天**
2. **实现通根度精细化** ⭐⭐⭐⭐ — `computeRootStrength()` TypeScript 版（本/中/余 权重 + 5 档 label）。支持"弃命从财 vs 杀印相生"判定。**2–3 天**
3. **Phase 注册表建立** ⭐⭐⭐⭐ — `PhaseMeta` + `PhaseRegistry` + 手动注册 14 core + 已知 rare phase。为 confirmed_facts 兼容性、反向规则统一管理奠基。**3–5 天**

### 中期（2–3 周）

4. **Mangpai 反向规则 DSL** ⭐⭐⭐ — `mangpai_reversals.yaml` schema + 评估函数。**1 周**
5. **化气格 + 神煞重做** ⭐⭐⭐ — 替换当前 35% 阈值与神煞凶吉断语。**5 天**
6. **confirmed_facts 持久化** ⭐⭐ — 跨会话记忆 + 结构化纠错。**1 周**（**前置决策**：持久化位置 Supabase vs AsyncStorage vs 本地 JSON）

### 长期（1 个月+）

7. **集成 open_phase + 自适应提问** ⭐⭐ — 后验 < 0.55 时生成备选 + 针对性提问。**2–3 周**
8. **历史回测数据集建设** ⭐⭐ — 收集 10+ SUJI 用户真实八字 + 大事件验证。**持续**

---

## 结论

bazi-life-curves 是**现存唯一做到"古籍引文 + 多派融合 + 结构保护机制 + 可验证"的开源八字工具**。其核心价值：

1. **科学仲裁机制**（多派投票 + Bayesian 后验）→ 不再单派独大
2. **古籍出处强制**（每条规则要引文献）→ 学理诚实
3. **结构化细节处理**（通根分档、燥湿独立、反向 DSL）→ 比"数字黑盒"可理解

对 SUJI 的最大启发：**精心设计的枚举 + 注册表 + 投票机制** 比 "hardcoded threshold 越来越多" 更有生命力。SUJI 完全可以站在 bazi-life-curves 肩膀上，融合《子平真诠》"成败救应"视角，打造**既尊重古籍、又符合现代工程规范**的 BaziEngine v2。

---

## 附：本报告调整 Path C 计划的建议

如果采纳本报告，原 `purring-stirring-sunbeam.md` Path C 计划需调整：

- **Phase 1.3** 类型设计：在 `RiZhuStructure` 之外增加 `PhaseMeta` 类型；`GeJuV2.chengBai/jiuYing` 改为从 `phase_id` 映射派生而非独立判定
- **Phase 2** 算法重写：把"删除 9 个工程数字"改为"用 bazi-life-curves 的通根分档（4 个阈值）+ 多派投票替换"。最终阈值数从 9 → 4，且每个有明确 attribution
- **Phase 2 fixtures**：原计划 6 条，扩到 6 + 5（移植上述 5 条 bazi-life-curves fixture）= 11 条
- **新增 Phase 0.5**（介于现 Phase 1 之前）：先实现 PhaseRegistry 与多派投票骨架，再做 reading（reading 校验骨架是否对，更高效）
