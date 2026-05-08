# 2026-04-30 BaziEngine Grounding Audit

> Scope: 把 [`lib/bazi/BaziEngine.ts`](../../../lib/bazi/BaziEngine.ts)（1755 行）里**每一个真正参与运算的决策**逐条点出来，标记它的 grounding 状态。这是"先看一个 domain 的工程量"试跑，不动算法、不读新书、不改代码。
>
> 输入：BaziEngine.ts 全文 + [SiLing.ts](../../../lib/bazi/SiLing.ts) + [REFERENCES.ts](../../../lib/bazi/REFERENCES.ts) + 现有 [claims.json](../claims.json) 20 条 + 2 份 reading notes + 上一份 audit。
>
> 输出：决策清单 + 按 grounding 状态分桶 + 优先要补的工作。

---

## TL;DR

`BaziEngine.ts` 里我点出 **44 个独立算法决策**。其中：

| 状态 | 数量 | 含义 |
|---|---|---|
| `foundational` | 9 | 不需要 claim：天干地支顺序、五行生克、阴阳归类等公认到不存在分歧的基础事实 |
| `text_cited_with_claim` | 7 | 代码 + claim + 古籍引文齐全，但绝大多数缺 fixture |
| `text_cited_no_claim` | 9 | 代码注释引了古籍但 claims.json 里没有对应条目，等于"私下引用、对外没登记" |
| `engineering_threshold_ungrounded` | 9 | **关键风险**：算法用了具体数字（`0.12 / 0.40 / 0.25 / 0.35 / 0.6 / 0.3 / 2.0 / 1.5 / 0.7 / 0.5`）来做格局/用神判断，这些数字**没有任何古籍来源，是工程上拍出来的**。它们直接决定了产品输出 |
| `mvp_simplified` | 7 | 算法存在但显著简化（缺透干取舍、相神、成败救应、运程通变等），已有部分 claim 标过 |
| `c_tier_dependency` | 2 | 排盘和神煞依赖 lunisolar/iztro/theGods 插件，没做 A-tier 古籍 fixture |
| `product_policy_violation_risk` | 5 | 模板字符串/描述层（特别是神煞凶神）直接输出"主破财/主意外/主刑伤"，与现有 `product.no-absolute-fortune-claims` 相冲 |

**最大的发现不是"读得不够"，而是"算了不该算的"**：很多看似有理论依据的输出（格局上/中/下、化气格、从格、五行强弱评分、用神选择），它们的**临界数值**完全是工程一拍脑袋的常数，但用户/AI 看到的是"专业八字结论"。这是"瞎算"的真实分布。

---

## 方法

1. 自顶向下扫描 `BaziEngine.ts`，把每个 `private static readonly TABLE`、每个 `compute*` 方法、每个分支判断都列成"一项决策"。
2. 对每项决策，回到现有 [claims.json](../claims.json)（20 条）和上次 audit 找匹配。
3. 按以下五分类打标：
   - `foundational` — 不需要 claim（公认基础）
   - `text_cited_with_claim` — 代码 + claim + 古籍引文齐全
   - `text_cited_no_claim` — 注释引了古籍，但 claims.json 没登记
   - `engineering_threshold_ungrounded` — 工程拍数字
   - `mvp_simplified` — 算法显著简化于古籍
   - `c_tier_dependency` — 工程库提供，无 A-tier 验证
   - `product_policy_violation_risk` — 表达层有恐吓/绝对断语风险
4. 不读新书、不改代码、不增删 claim。

---

## 决策清单

### A. 静态查表数据

| # | 决策 | 位置 | 状态 | 现有 claim | 备注 |
|---|---|---|---|---|---|
| A01 | 天干顺序 | [BaziEngine.ts:61](../../../lib/bazi/BaziEngine.ts#L61) | `foundational` | — | 公认 |
| A02 | 地支顺序 | [BaziEngine.ts:66](../../../lib/bazi/BaziEngine.ts#L66) | `foundational` | — | 公认 |
| A03 | 天干五行映射 | [BaziEngine.ts:74](../../../lib/bazi/BaziEngine.ts#L74) | `foundational` | — | 注释引《渊海子平》，实际全派一致 |
| A04 | 天干阴阳 | [BaziEngine.ts:86](../../../lib/bazi/BaziEngine.ts#L86) | `foundational` | — | 公认 |
| A05 | 地支五行 | [BaziEngine.ts:98](../../../lib/bazi/BaziEngine.ts#L98) | `foundational` | — | 公认 |
| A06 | 地支阴阳 | [BaziEngine.ts:108](../../../lib/bazi/BaziEngine.ts#L108) | `foundational` | — | 公认 |
| A07 | 五行相生相克 | [BaziEngine.ts:139](../../../lib/bazi/BaziEngine.ts#L139) | `foundational` | — | 公认 |
| A08 | 地支藏干表（带权重） | [BaziEngine.ts:119](../../../lib/bazi/BaziEngine.ts#L119) | `text_cited_with_claim` + `engineering_threshold_ungrounded` | `bazi.hidden-stems.table` | **混合**：藏干列表《渊海子平》《三命通会》皆有；但**权重 `0.6 / 0.2 / 0.2 / 0.7 / 0.3` 是工程数字**——古籍提供的是"司令天数"（见 [SiLing.ts](../../../lib/bazi/SiLing.ts)），不是百分比权重。这两套数据被代码当作不同维度处理，但它们映射的是同一个东西。需要一个新 claim 显式标记"权重是天数的近似投影" |
| A09 | 十二长生序列 + 阳干/阴干起始地支 | [BaziEngine.ts:184](../../../lib/bazi/BaziEngine.ts#L184), [193](../../../lib/bazi/BaziEngine.ts#L193), [201](../../../lib/bazi/BaziEngine.ts#L201) | `text_cited_no_claim` | **缺** | 注释引《三命通会》卷二·十二运论。表本身经典；但 claims.json 没有 `bazi.twelve-stages.table` |
| A10 | 天干五合表（含化气五行） | [BaziEngine.ts:261](../../../lib/bazi/BaziEngine.ts#L261) | `text_cited_no_claim` | **缺** | 注释引《渊海子平》，全派一致；但 claims.json 没登记 |
| A11 | 天干相冲表 | [BaziEngine.ts:273](../../../lib/bazi/BaziEngine.ts#L273) | `foundational` | — | |
| A12 | 地支六合表（带合化五行） | [BaziEngine.ts:281](../../../lib/bazi/BaziEngine.ts#L281) | `text_cited_with_claim` | `bazi.branch-relations.not-absolute-omens` | 表 OK |
| A13 | 地支三合表 | [BaziEngine.ts:290](../../../lib/bazi/BaziEngine.ts#L290) | `text_cited_with_claim` | 同上 | |
| A14 | 地支三会（方局） | [BaziEngine.ts:301](../../../lib/bazi/BaziEngine.ts#L301) | `text_cited_with_claim` | 同上 | |
| A15 | 地支六冲 | [BaziEngine.ts:312](../../../lib/bazi/BaziEngine.ts#L312) | `text_cited_with_claim` | 同上 | |
| A16 | 地支六害 | [BaziEngine.ts:321](../../../lib/bazi/BaziEngine.ts#L321) | `text_cited_with_claim` | 同上 | |
| A17 | 地支六破 | [BaziEngine.ts:330](../../../lib/bazi/BaziEngine.ts#L330) | `text_cited_with_claim` | 同上 | |
| A18 | 地支相刑 | [BaziEngine.ts:342](../../../lib/bazi/BaziEngine.ts#L342) | `text_cited_with_claim` | 同上 | |
| A19 | 日主性格描述（10 干 × 1 句） | [BaziEngine.ts:352](../../../lib/bazi/BaziEngine.ts#L352) | `product_policy_violation_risk` (轻) | — | 注释引《滴天髓》日元论，但内容是 app 改写。"栋梁之木/正直进取"等不在《滴天髓》原文里，是工程现写的现代解读。**风险等级**：低，因都是中性正面描述 |
| A20 | 五行权重系数 `{GAN: 1.0, ZHI_BASE: 0.6}` | [BaziEngine.ts:369](../../../lib/bazi/BaziEngine.ts#L369) | `engineering_threshold_ungrounded` | — | **彻底工程拍数**。古籍论五行强弱用"得令/通根/坐刃/会合"等结构语言，不存在"天干 = 1.0、地支 = 0.6"这种数值。这两个常数是 `computeWuXingStrength` 评分的入口 |
| A21 | 调候用神表（10 干 × 12 月 = 120 entries） | [BaziEngine.ts:382](../../../lib/bazi/BaziEngine.ts#L382) | `text_cited_with_claim` (但弱) | `bazi.adjusting-climate.yongshen` | claim status 是 `implemented_needs_text_citation`。这是 BaziEngine 中**单条最大的查表数据**（每条都有用神/喜神/忌神/desc），需要逐条对《穷通宝鉴》校验。当前没有 fixture |

### B. 算法函数

| # | 决策 | 位置 | 状态 | 现有 claim | 备注 |
|---|---|---|---|---|---|
| B01 | 十神算法（生克 × 阴阳） | [BaziEngine.ts:157](../../../lib/bazi/BaziEngine.ts#L157) | `text_cited_with_claim` | `bazi.ten-gods.core` | 算法对，缺 fixture |
| B02 | 十二长生计算（阳顺阴逆） | [BaziEngine.ts:211](../../../lib/bazi/BaziEngine.ts#L211) | `text_cited_no_claim` | **缺** | 见 A09 |
| B03 | 六甲空亡计算 | [BaziEngine.ts:242](../../../lib/bazi/BaziEngine.ts#L242) | `text_cited_no_claim` | **缺** | 注释引《三命通会》卷二·空亡论。算法是数学化的旬空查表；claims.json 没登记 |
| B04 | 纳音五行解析（字串后缀匹配） | [BaziEngine.ts:728](../../../lib/bazi/BaziEngine.ts#L728) | `foundational` (近似) | — | 实际是字符串处理，依赖 takeSound 插件提供的纳音名 |
| B05 | 旺相休囚死系数 `{2.0, 1.5, 1.0, 0.7, 0.5}` | [BaziEngine.ts:788](../../../lib/bazi/BaziEngine.ts#L788) | `engineering_threshold_ungrounded` | `bazi.wuxing.seasonal-prosperity.requires-tongbian`（caveat 已存在） | **关键风险**：claim 已警告"生旺未必吉、休囚死绝未必凶"，但代码仍**用具体数值乘进强弱评分**。古籍只提供语言判断（旺/相/休/囚/死 5 档），不给数值。这五个常数 `{2.0, 1.5, 1.0, 0.7, 0.5}` 是 app 选择 |
| B06 | 通根加成 `+0.3` per match | [BaziEngine.ts:819](../../../lib/bazi/BaziEngine.ts#L819) | `engineering_threshold_ungrounded` | — | "通根"概念《滴天髓》强调，但"+0.3"是工程数字 |
| B07 | 六合三合加成 `+0.5` | [BaziEngine.ts:828](../../../lib/bazi/BaziEngine.ts#L828), [833](../../../lib/bazi/BaziEngine.ts#L833) | `engineering_threshold_ungrounded` | — | 同上 |
| B08 | 日主强弱 boolean 判断（`helpForce >= weakenForce`） | [BaziEngine.ts:852](../../../lib/bazi/BaziEngine.ts#L852) | `mvp_simplified` | `bazi.wuxing.seasonal-prosperity.requires-tongbian` (caveat) | 二元化的身强/身弱。《滴天髓》体用清浊远比这复杂（中和、太过、不及、独象、化象、从格…）。这个 boolean 直接驱动用神选择 |
| B09 | 用神选择三段式：调候 → 身强用克泄 → 身弱用生扶 | [BaziEngine.ts:854](../../../lib/bazi/BaziEngine.ts#L854) | `mvp_simplified` + `engineering_threshold_ungrounded` (优先级排序未登记) | `bazi.adjusting-climate.yongshen` (部分) | **优先级"调候表 优先于 扶抑"是产品决策，没有古籍说必须这样选**。古籍提供"调候、扶抑、通关、病药、专旺"五种取用思路，何者为主要看格局 |
| B10 | 最强/最弱五行（`reduce(b[1] > a[1])`） | [BaziEngine.ts:882](../../../lib/bazi/BaziEngine.ts#L882) | `engineering_threshold_ungrounded` | — | 直接把 balance 数值最大的认定为最强；但前提是 balance 数值本身已经是工程拼凑的 |
| B11 | 地支关系网络遍历 | [BaziEngine.ts:932](../../../lib/bazi/BaziEngine.ts#L932) | `text_cited_with_claim` | `bazi.branch-relations.not-absolute-omens` | 遍历逻辑 OK |
| B12 | 天干合化判定（化神得令 + `> 25%` + 无冲克） | [BaziEngine.ts:1014-1054](../../../lib/bazi/BaziEngine.ts#L1014-L1054) | `engineering_threshold_ungrounded` + `mvp_simplified` | — | 注释说"化神在四柱中力量占比较高（>25%）"，**25% 是工程门槛**。古籍论合化条件是定性的（化神得月令、天透地藏、不被破坏），不给百分比 |
| B13 | 格局判定主流程（4 段：从 0.12 → 专旺 0.40 → 化气 → 正格） | [BaziEngine.ts:1086](../../../lib/bazi/BaziEngine.ts#L1086) | `mvp_simplified` + `engineering_threshold_ungrounded` (×2) | `bazi.geju.mvp-simplified`, `bazi.ziping-zhenquan.month-command-yongshen`, `bazi.ziping-zhenquan.geju-chengbai-jiuying` | claims 已经标过简化，但具体数值 `0.12` 和 `0.40` 没在 claim 里出现 |
| B14 | 从格分类（从财/从官/从儿） | [BaziEngine.ts:1148](../../../lib/bazi/BaziEngine.ts#L1148) | `mvp_simplified` | `bazi.geju.mvp-simplified` | 缺：从势、从弱、假从、真从、从化等。也缺"从格成立条件"（如四柱无根） |
| B15 | 专旺格五格分类 | [BaziEngine.ts:1170](../../../lib/bazi/BaziEngine.ts#L1170) | `text_cited_no_claim` + `mvp_simplified` | **缺** | 注释引《渊海子平》专旺格论；曲直/炎上/稼穑/从革/润下五格名是经典的，但成立条件（必须四柱无克泄、有印生扶等）未实现，仅靠日主占比 > 40% 单一阈值 |
| B16 | 化气格判定（`> 35%` ratio + 日干合他干） | [BaziEngine.ts:1184](../../../lib/bazi/BaziEngine.ts#L1184) | `engineering_threshold_ungrounded` + `mvp_simplified` | `bazi.geju.mvp-simplified` | **35% 是工程门槛**；化气格成立条件远比"日干合他干 + 化神比例"复杂（月令为化神之地、化神不被冲克、天透地藏等） |
| B17 | 格局上中下评级 | [BaziEngine.ts:1126-1134](../../../lib/bazi/BaziEngine.ts#L1126-L1134) | `mvp_simplified_critical` | `bazi.ziping-zhenquan.geju-chengbai-jiuying` (但仅作为政策) | **关键失配**：代码以"月支主气五行 == yongShen / jiShen"二段决定上/中/下。《子平真诠》的"格局高低"在"有情/无情、有力/无力、相神是否破"。当前算法和古籍论高低**不在同一个语义维度上** |
| B18 | 格局描述 + modernMeaning（10 神 各 1 句） | [BaziEngine.ts:1212](../../../lib/bazi/BaziEngine.ts#L1212), [1229](../../../lib/bazi/BaziEngine.ts#L1229) | `product_policy_violation_risk` (低) | — | 描述都是 app 改写的现代语；不直接出"必凶/必富/必贵"，相对安全。但和 `bazi.ziping-zhenquan.stars-do-not-decide-geju` 的"格名不是结论"政策有张力——格名 + 一句性格描述等于把格名当结论 |
| B19 | theGods 插件提取神煞 | [BaziEngine.ts:1255](../../../lib/bazi/BaziEngine.ts#L1255) | `c_tier_dependency` | — | luckLevel > 0/< 0/== 0 直接映射"吉/凶/中性"，未做 A-tier 古籍审查。`P-001` 已经标过这个问题 |
| B20 | 自建神煞 18 个（天乙、文昌、天德、月德、桃花、驿马、华盖、将星、亡神、羊刃、禄神、太极、金舆、魁罡、红鸾、天喜、劫煞、灾煞） | [BaziEngine.ts:1323-1629](../../../lib/bazi/BaziEngine.ts#L1323-L1629) | **混合**：表 `text_cited_no_claim` + 描述 `product_policy_violation_risk` | **表缺 claim**；描述违反 `product.no-absolute-fortune-claims` 和 `bazi.ziping-zhenquan.stars-do-not-decide-geju` | 表的查法注释引《三命通会》《渊海子平》各篇，结构经典；**但描述层多次出现"主破财损耗、意外损失，需防…"（亡神 [L1505](../../../lib/bazi/BaziEngine.ts#L1505)）、"主意外灾害"（灾煞 [L1625](../../../lib/bazi/BaziEngine.ts#L1625)）、"主破败，需防小人"（劫煞 [L1610](../../../lib/bazi/BaziEngine.ts#L1610)）**——直接的恐吓式断语，违反产品政策且违反《子平真诠》"星辰无关格局" |
| B21 | 大运方向（阳男阴女顺、阴男阳女逆） | [BaziEngine.ts:1664](../../../lib/bazi/BaziEngine.ts#L1664) | `text_cited_with_claim` | `bazi.dayun.requires-tongbian` (loose) | 顺逆规则全派一致 |
| B22 | 大运起步年龄（节距 / 3） | [BaziEngine.ts:1706](../../../lib/bazi/BaziEngine.ts#L1706) | `mvp_simplified` | **缺更精细的 claim** | 古籍正法是 "3 天 = 1 年, 1 天 = 4 月, 1 时辰 = 10 天"。当前只到天精度，月/日级精度被取整丢掉。差异可达 ±1 岁 |
| B23 | 大运干支顺逆数 10 步 | [BaziEngine.ts:1676](../../../lib/bazi/BaziEngine.ts#L1676) | `text_cited_with_claim` | `bazi.dayun.requires-tongbian` | 排法 OK；解释层未实现"通变" |
| B24 | 排盘依赖 lunisolar / char8ex 插件 | [BaziEngine.ts:558](../../../lib/bazi/BaziEngine.ts#L558) | `c_tier_dependency` | **缺** | 整个四柱、节气、月柱划分由 `@lunisolar/plugin-char8ex` 提供，无独立 fixture 校验。这是排盘正确性的最底层依赖 |

---

## 分桶分析

### 桶 1 — `engineering_threshold_ungrounded`（最大风险）

把所有"代码用了具体数字、但古籍没给这些数字"的位置集中起来：

| 数值 | 位置 | 用途 |
|---|---|---|
| `0.6, 0.7, 0.2, 0.3, 1.0`（藏干权重） | [CANG_GAN](../../../lib/bazi/BaziEngine.ts#L119) | 藏干进入五行强度计算的折算 |
| `1.0`（天干 weight）+ `0.6`（地支 base） | [WX_WEIGHT](../../../lib/bazi/BaziEngine.ts#L369) | 五行强度入口系数 |
| `2.0, 1.5, 1.0, 0.7, 0.5`（旺相休囚死系数） | [B05](../../../lib/bazi/BaziEngine.ts#L788) | 月令对五行的乘子 |
| `+0.3`（通根加成） | [B06](../../../lib/bazi/BaziEngine.ts#L819) | |
| `+0.5`（六合/三合加成） | [B07](../../../lib/bazi/BaziEngine.ts#L828) | |
| `0.25`（化神比例阈值，合化判定） | [B12](../../../lib/bazi/BaziEngine.ts#L1039) | 决定是否"合化成功" |
| `0.12`（从格阈值） | [B13](../../../lib/bazi/BaziEngine.ts#L1095) | 决定是否走从格 |
| `0.40`（专旺阈值） | [B13](../../../lib/bazi/BaziEngine.ts#L1102) | 决定是否走专旺 |
| `0.35`（化气比例阈值） | [B16](../../../lib/bazi/BaziEngine.ts#L1197) | 决定是否走化气 |

这九组数字**完全是工程拍出来的**。它们是格局/用神判定的实际守门员——同一组八字，把 0.40 改成 0.45，可能从专旺格变成正格；把 0.12 改成 0.10，从格直接消失。

> 这就是用户说的"瞎算"的真实位置。不在表，在阈值。

### 桶 2 — `text_cited_no_claim`（私下引用、对外没登记）

代码注释引古籍但 [claims.json](../claims.json) 没对应条目：

- **A09** 十二长生序列与起始地支 → 缺 `bazi.twelve-stages.table`
- **A10** 天干五合（含化气方向） → 缺 `bazi.heavenly-stem-combinations.table`
- **B03** 六甲空亡 → 缺 `bazi.kong-wang.formula`
- **B15** 专旺格五格 → 缺 `bazi.zhuanwang.five-patterns`
- **B20** 18 个自建神煞表 → 缺神煞类 claim group（建议每个神煞一条 claim 或合并为 `bazi.shensha.tables`）
- **B22** 大运起步年龄正法 → 缺 `bazi.dayun.start-age.precision`（标记当前实现的精度损失）

### 桶 3 — `mvp_simplified`（已登记 + 应登记）

已被 [claims.json](../claims.json) 标过的简化：
- `bazi.geju.mvp-simplified` 涵盖 `determineGeJu` 主流程
- `bazi.ziping-zhenquan.geju-chengbai-jiuying` 提示"成败救应"未实现
- `bazi.ziping-zhenquan.yongshen-variation` 提示"用神变化"未实现
- `bazi.ziping-zhenquan.xiangshen-critical` 提示"相神"未实现

**但下面这几项简化没在 claim 里**：
- B08 日主强弱二元化（`helpForce >= weakenForce`）—— 把《滴天髓》体用清浊压成 boolean
- B09 用神选择优先级（调候 > 扶抑）—— 这是产品决策，应该有 claim 显式说"为什么这样选"
- B17 格局上/中/下 vs《子平真诠》"高低" —— 语义错位
- B22 大运起步年龄精度 —— 月/日级丢失

### 桶 4 — `product_policy_violation_risk`（描述层政策违反）

`computeShenShaOwn` 的描述字符串里有几条直接违反政策：

- 亡神 [L1505](../../../lib/bazi/BaziEngine.ts#L1505)："主破财损耗、意外损失，需防财务风险、资产流失与合伙纠纷"
- 灾煞 [L1625](../../../lib/bazi/BaziEngine.ts#L1625)："主意外灾害，宜注意出行安全与身体健康，防突发事故"
- 劫煞 [L1610](../../../lib/bazi/BaziEngine.ts#L1610)："主破败，需防小人"
- `getShenShaDesc` 里的 [劫煞](../../../lib/bazi/BaziEngine.ts#L1293)：「主破败，需防小人」、[灾煞](../../../lib/bazi/BaziEngine.ts#L1294)：「主意外，需注意安全」

这几条违反两条政策：
- `product.no-absolute-fortune-claims`（避免绝对预测、恐吓式断语、医学/法律/财务确定性）
- `bazi.ziping-zhenquan.stars-do-not-decide-geju`（神煞不能操格局成败之权 → 也不应单独触发"防小人/防意外"）

**且与 `modernMeaning` 段落的安全表达自相冲突**：例如 [灾煞 modernMeaning L1626](../../../lib/bazi/BaziEngine.ts#L1626) 是温和的"提高安全意识"，但 `description` 字段是恐吓的"主意外灾害"。如果 UI 同时渲染两者，恐吓版会先到。

### 桶 5 — `c_tier_dependency`（工程库无 A-tier 验证）

- **B19** theGods 插件吉/凶 luckLevel 直出
- **B24** 整个排盘依赖 char8ex 插件，无独立古籍排盘 fixture

`Z-001 / Z-002` 在上一份 audit 已经把 ziwei 的 iztro 依赖标了。bazi 的 lunisolar 依赖**还没有任何 fixture**——这意味着月柱、节气、子时、闰月等关键边界都没有 A-tier 兜底。

---

## 数字综合

按"是否真的 grounded"收口：

```
44 个决策
├── 18 个真正 grounded (= foundational + text_cited_with_claim)
│      = 其中 0 个有 fixture 验证
├── 9 个 text_cited 但没登记 claim
├── 9 个工程数字门槛（产品输出由它们决定）
├── 7 个 mvp_simplified（部分已 claim）
├── 5 个产品政策风险描述
└── 2 个 C-tier 库依赖无 fixture
```

把"工程数字门槛"和"无 fixture 的 text_cited"算到非真正 grounded 一侧的话，**严格意义上"算法到原文有完整通路且经过 fixture 校验"的决策为 0**。这不是 BaziEngine 写得差——它在工程上比业界很多 bazi 库都更体系化，注释和分层都很清楚——而是 grounding 的**最后一公里（fixture）**整个 domain 都还没建。

---

## 推荐的下一步（按 ROI 由高到低）

> 注：这是我作为审查者的建议，**不是已批准的工作**。请你决定要不要做、做哪几条、按什么顺序。

### R1 [最高 ROI] — 把 9 个工程阈值正式登记成 claim

每个阈值一条 claim（或合并为 1–2 条），状态 `engineering_threshold_no_classical_basis`。这件事**不需要读新书**，只需要把已知事实显式化。完成后效果：
- 这些数字第一次"被点名"
- 给未来调整/做 A/B 留下文字依据
- AI prompt 里如果要解释"为什么是从格"，可以拒绝信任阈值结论

工作量：1–2 小时。

### R2 [高 ROI] — 修 5 个产品政策违反描述

`亡神/灾煞/劫煞`（B20 部分）+ `getShenShaDesc` 中的相同条目，把 `description` 字段改成与 `modernMeaning` 一致的安全版。这是**纯产品风险**，不影响算法正确性，但用户/AI 直接读到。

工作量：30 分钟。可以和 R1 一起做。

### R3 [中高 ROI] — 把 9 条 `text_cited_no_claim` 升为 claim

不读新书，只把已经在代码注释里的引用形式化登记。完成后 [claims.json](../claims.json) 从 20 条增长到约 29 条，覆盖率显著提升。

工作量：1–2 小时。

### R4 [中 ROI] — 给 6 个最关键算法补 fixture

不补全部 44 个，只补：
- 十神 (B01)
- 藏干 (A08)
- 十二长生 (B02)
- 空亡 (B03)
- 大运方向 (B21)
- 月令人元司令 (`SiLing.ts` 已是 contested)

每个 fixture：1 个已知盘 + 古籍/独立排盘源对照 + jest test。完成后这 6 个决策从 `text_cited` 升到 `grounded_with_fixture`。

工作量：每个 1–2 小时，共约 1 个工作日。

### R5 [中长期] — 重看格局判定主流程（B13–B17）

涉及读《子平真诠》后续章节、设计 `GeJu` 类型扩展（`xiangShen / chengBai / jiuYing / basis`）、可能要改 BaziEngine 大块代码。这件事要等 R1–R4 把 ledger 和 fixture 体系建起来后再动。

工作量：1–3 周。**这是真正"消除瞎算"的核心改造**，但前面四步是地基。

### R6 [低优先 / 长期] — `lib/bazi` 之外的同类 audit

`DayunEngine.ts`（696 行）、`InsightEngine.ts`（586 行）按这套方法做 grounding audit。预估：每个文件 2–4 小时。然后是 `lib/ziwei/`、`lib/qimen/`、`lib/divination/`。

---

## 建议给 [claims.json](../claims.json) 加的 status 值

当前 status 值偏定性。建议补两个端点值，让 ledger 第一次有 "grounded vs ungrounded" 的明确二分：

- `algorithm_grounded_with_fixture` — 金标准：原文 + 代码 + fixture 三对齐
- `algorithm_threshold_engineering_choice` — 当前 `engineering_threshold_ungrounded` 的正式名

加这两个之后，BaziEngine 的 grounding ledger 一眼能看出哪一行是"真稳的"哪一行是"靠工程一拍"。

---

## 这一轮试跑教会了我们什么

1. **44 个决策、20 条 claim、0 个 fixture** —— claim 增长比 fixture 容易得多。如果只追求 claim 数量上涨，会造成"读过证书"的假象。fixture 是真正的工程门槛。

2. **最值得防的不是"读得不够"，是"算得太多"** —— 9 个工程阈值掌管了产品输出最关键的几个判断（从格/专旺/化气/合化/身强弱/用神）。这些是"瞎算"的真实位置，比"哪本书没读"更紧迫。

3. **方法本身可持续** —— 这次 audit 用了大约 1 小时（读 1755 行 + 现有材料 + 写报告）。按这个节奏，整个 `lib/bazi` 的 4 个引擎文件 1 个工作日内可以全 audit；`lib/ziwei` + `lib/qimen` + `lib/divination` 各 1 天，**合计 4 天能把整个 app 的算法层全 grounding ledger 化**。

4. **不需要先读完所有书** —— 这次 audit 没读任何新书，但已经把"BaziEngine 哪里不稳"显式化了。读书可以服务于具体已发现的缺口（fixture 校验、阈值是否能找到古籍依据），而不是开放式扫荡。

---

## 确认 / 不确认

- ✅ 我**没有**改任何代码、claims.json、reading-notes
- ✅ 我**没有**读任何新书或外部资料
- ✅ 行号引用基于 audit 写作当下的 BaziEngine.ts 状态；如果代码后续变动，需重新校对
- ⚠️ "44 个决策"是我根据"独立的 readonly table 或 compute* 函数或 if-分支"切分的，可能和你的口径不完全一致——粒度可调
- ⚠️ "engineering_threshold_ungrounded" 是审查者标签，不代表这些数字**一定错**；只代表它们**目前没有古籍依据可被引用**。有些数字（例如旺相休囚死的 5 档系数）在民间 bazi 软件中是常见做法，可能存在某些 D-tier source 但 audit 中未追溯
