# 《滴天髓阐微》体用 / 清浊 / 寒暖燥湿 / 刚柔 / 顺逆 五论摘读（2026-05-07）

> 范围：本应摘读《滴天髓阐微》（任铁樵注）核心五论，用于 BaziEngine Phase 2 算法重写——把现有数字阈值（旺相休囚死 2.0/1.5/1.0/0.7/0.5、藏干 0.6 等）换成《滴天髓》结构化判断（体用、清浊、寒暖燥湿四象、刚柔、顺逆）。

---

## ⚠ Source 抓取受限说明（首先必读）

### 本次抓取尝试

| URL | 结果 |
|---|---|
| `https://www.zhonghuadiancang.com/xuanxueshushu/3023/` | WebFetch tool 被 harness 拒绝（permission denied） |
| `https://ctext.org/wiki.pl?if=gb&res=82087` | 同上，permission denied |
| `https://so.gushiwen.cn/`、`https://m.taixingsuanming.com/` | 未尝试（鉴于前两个已被拒，假设同样无权限） |
| `hf_doc_search` | 不适用——HF 文档库不收录中文古籍 |

### 因此本文件的状态

- **本文件是 stub**，不含任何从印刷版或可信网络版抽取的逐字引文。
- 所有"短摘录"段落均**改写为通俗化的内容描述**，不是原文引文，且**不可作为 claim 的 evidence 字段使用**。
- **算法可用规则**与**工程落点**两节，基于本人已有的对《滴天髓》通行解读的常识性了解（任铁樵注通行版的章节结构与核心命题），用于 Phase 2 算法的**初步设计草案**，不作为已校勘的史料。
- **任何进入 fixture 校验或 claim evidence 的内容，都必须经印刷版（推荐：中华书局点校本、孙正治校注《滴天髓阐微》、或袁树珊《命理探原》引《滴天髓》节）逐条核校后才能升格为 `status: "verified"`。**
- 本次产出 claim 草案的 `status` 一律标 `drafted_pending_source_extraction`（**不是** `drafted_from_reading`，因没有真正的 reading），等待下一次有 WebFetch 权限或拿到印刷版后再升格。

### 给后续 session 的请求

> 请 maintainer 在下次开此任务时，**先开 WebFetch 权限**（至少允许 `zhonghuadiancang.com`、`ctext.org`、`gushiwen.cn` 三域），或直接把印刷版相关章节的扫描 / 文本贴进 prompt。当前权限下无法负责任地完成"摘读"。

---

## 一、体用论

### 内容描述（非引文，待源核）

- 《滴天髓》"体用"一节的核心命题：**体与用是一对相对概念**，不是固定指日主或月令。
- 一般通行解读（任注流派）：
  - **日主当令、印比成势** → 日主为"体"，财官食伤为"用"。
  - **日主失令、被克泄过重** → 不可强扶，反以**当令旺神**为"体"，日主反求"用"于该旺神（顺势 / 化气 / 从格的根源）。
  - 体用相**配合得宜**为美；体用乖违（如体强用弱、体用相战、用神被伤）为病。
- 与《子平真诠》"用神 = 月令本气透干"的**机械取法不同**——《滴天髓》的体用是**动态的、相对的**，须看全局气势。

### 算法可用规则（设计草案，待源核后定稿）

| 类型 | 规则 |
|---|---|
| 体的候选 | (a) 日主（默认）；(b) 月令当令神（若日主严重失势） |
| 用的候选 | 与"体"互补的五行/十神：扶/抑/通关/调候 |
| 体用配合得宜 | `体强 ∧ 用神有力 ∧ 用神不被伤` |
| 体用乖违（病） | `体过强用过弱` ∨ `体弱用强反夺体` ∨ `用神被合冲克破` |
| 体用易位（化/从触发） | 日主无根 ∧ 当令神成势 ∧ 与日主非克战关系 → 转以当令神为体 |

### 工程落点

- 当前 `BaziEngine.determineGeJu`（line 1086）走的是"月支主气十神"机械路径，对应《子平真诠》取法，**不含体用动态判断**。
- 建议新增 `determineTiYong(siZhu, wuXingStrength, riGan): {ti, yong, harmony: 'he'|'wei'|'yi-wei'}`，作为 `determineGeJu` 之前的**前置判断**：
  - `harmony === 'yi-wei'`（体用易位）→ 转交 `getCongGe` / `checkHuaQiGe`
  - `harmony === 'he'`（配合得宜）→ 走正格 `chengBai` 流程
  - `harmony === 'wei'`（乖违）→ 标记为破格，走救应路径检测
- 引入新枚举字段：`tiYongHarmony: 'he' | 'wei' | 'yi-wei'`；`tiCandidate`、`yongCandidate` 各自带十神/五行标识。

---

## 二、清浊论

### 内容描述（非引文，待源核）

- "清"通常指：用神有情、五行流通、忌神被去净、相神到位、格局纯一。
- "浊"通常指：用神被伤无救、五行壅塞、忌神得势、官煞混杂、格局驳杂。
- "半清半浊"：有清有浊，浊处若得救应可转清；清处若被冲破亦转浊。
- 通行解读对"清"的几个具体可识别状态：
  - 一神到底（whole chart 围绕一个主气流通）
  - 病药相济（有病有药，药到病除）
  - 清纯不杂（不见相战十神：如官杀混、印枭混、食伤混）

### 算法可用规则（设计草案）

| 类型 | 规则 |
|---|---|
| 清（chun） | `用神 intact ∧ 忌神 absent_or_controlled ∧ 五行流通` |
| 浊（zhuo） | `用神 broken ∧ 忌神 dominant` ∨ `官煞混杂` ∨ `印枭混杂` ∨ `食伤混杂` |
| 半清半浊 | `清条件部分满足 ∧ 浊条件部分满足` |
| 五行流通 | 五行循环相生链长度 ≥ 4（金→水→木→火→土→金 的子链）|
| 病药相济 | 存在 `bingShen`（病神）∧ 存在 `yaoShen`（药神）∧ 药能制病 |

### 工程落点

- 当前 `BaziEngine` 没有清浊判断字段。建议在 `MingPan` 增加 `qingZhuo: { level: 'qing'|'zhuo'|'banqing'; reasons: string[] }`。
- 与 `determineGeJu` 输出的 `chengBai`、`xiangShen` 字段强耦合：
  - `chengBai === 'cheng' ∧ 流通到位 → qing`
  - `chengBai === 'po' ∧ 无救应 → zhuo`
  - `chengBai === 'jiuying' → banqing`
- 新增辅助函数 `computeWuXingFlow(siZhu): { chainLength: number; cycleClosed: boolean }`，用于流通判断。

---

## 三、寒暖燥湿论

### 内容描述（非引文，待源核）

- 《滴天髓》"寒暖"与"燥湿"通常分两节，但常被合并讨论为"四象调候"。
- **寒**：冬令（亥子丑）金水当令、火气衰微 → 需丙丁火暖局。
- **暖**：夏令（巳午未）木火当令、金水衰微 → 需壬癸水润局。
- **燥**：火土多而无水（春末夏季 + 戊己未戌当令）→ 需水气濡润。
- **湿**：水木多而无火（冬季 + 子辰丑当令、壬癸成势）→ 需火气暖发。
- 寒暖偏向**温度维度**（季节 + 火/水比），燥湿偏向**水分维度**（土性 + 水/火配合）。
- 与《穷通宝鉴》调候表的关系：穷通是"日干 × 月令"的查表结果；滴天髓的寒暖燥湿是其**底层抽象**——为什么这个调候用神有效。

### 算法可用规则（设计草案）

| 类型 | 规则 |
|---|---|
| 寒局 | `monthZhi ∈ {亥,子,丑} ∧ wuXing.火 < threshold` |
| 暖局 | `monthZhi ∈ {巳,午,未} ∧ wuXing.水 < threshold` |
| 燥局 | `wuXing.火 + wuXing.土 ≥ 4 ∧ wuXing.水 ≤ 1` |
| 湿局 | `wuXing.水 + wuXing.木 ≥ 4 ∧ wuXing.火 ≤ 1` |
| 寒暖适中 | 不满足寒/暖 |
| 燥湿适中 | 不满足燥/湿 |
| 调候用神 | 寒→火/木；暖→水/金；燥→水；湿→火 |
| ⚠ threshold | 待源核：是按数字（≤1 个柱）还是按"无根/有根"判断 |

### 工程落点

- 当前 `BaziEngine.TIAO_HOU_YONG_SHEN`（line 382）是日干 × 月令查表，**只给结果，不给推导**。
- 建议新增 `computeHanNuanZaoShi(siZhu, monthZhi): { hanNuan: 'han'|'nuan'|'shi-zhong'; zaoShi: 'zao'|'shi'|'shi-zhong'; demanded: WuXing[] }`，作为调候表的**底层校验**：
  - 如果查表结果 ≠ 推导结果 → log warning，走印刷版核校流程。
  - 这能在 Phase 2 帮助识别现有 `TIAO_HOU_YONG_SHEN` 表中**不符合滴天髓底层逻辑**的条目。
- 引入新字段：`mingPan.tiaoHou.hanNuanZaoShi: { ... }`，与现有 `mingPan.tiaoHou` 并列。

---

## 四、刚柔论

### 内容描述（非引文，待源核）

- 《滴天髓》"刚柔"一节的核心：**日主与全局的刚柔配合**，刚柔相济为美，纯刚纯柔多病。
- 通行解读：
  - **刚**：阳干（甲丙戊庚壬）+ 当令 + 印比多 + 通根透干 → 性刚。
  - **柔**：阴干（乙丁己辛癸）+ 失令 + 财官食伤多 + 无根 → 性柔。
  - **以柔济刚**：刚极者宜见食伤泄秀（柔中之刚为美）。
  - **以刚济柔**：柔极者宜见印比帮身（柔中之刚为贵）。
  - **过刚不折反折**：刚而无泄无制，遇大运冲克即败。
  - **过柔随波**：柔而无依无救，反成从势之局（接顺逆论）。

### 算法可用规则（设计草案）

| 类型 | 规则 |
|---|---|
| 刚（gang） | `阳干(riGan) ∧ 月令通根 ∧ wuXing.印+比 ≥ 4` |
| 柔（rou） | `阴干(riGan) ∧ 月令不通根 ∧ wuXing.财+官+食伤 ≥ 4` |
| 中和（zhonghe） | 不满足刚/柔极端 |
| 刚柔相济 | `刚 ∧ 有食伤泄` ∨ `柔 ∧ 有印比帮` |
| 过刚（病） | `刚 ∧ ¬有食伤 ∧ ¬有官杀` |
| 过柔（触发从格） | `柔 ∧ 无印比 ∧ 财官杀成势` → 转 `getCongGe` |

### 工程落点

- 当前 `computeWuXingStrength`（line 773）只输出五行能量值，**没有刚柔标签**。建议新增 `computeGangRou(siZhu, riGan, wuXingStrength): { type: 'gang'|'rou'|'zhonghe'; balanced: boolean }`。
- 与 `getCongGe`（line 1148）联动：当 `gangRou.type === 'rou' ∧ ¬balanced` 且无印比时，触发从格判定。当前从格判定基于"五行能量阈值"，刚柔判断更接近原书逻辑（阴阳干、当令、有无救济）。
- 新字段：`mingPan.gangRou: { type, balanced, reasoning }`。

---

## 五、顺逆论

### 内容描述（非引文，待源核）

- 《滴天髓》"顺逆"的核心：**有些命局不可逆，只能顺其气势**——这是从格、化气格、专旺格的根源理论。
- 通行解读：
  - **顺局**：日主无根，财官杀或食伤成势 → **顺势从之**（从财、从官杀、从儿、从势）；或一行得令独透，余气助之 → 专旺。
  - **逆局**：日主有根，五行偏枯但日主可立 → **扶抑反生**（扶弱抑强、通关、调候）。
  - 顺逆判断的关键：**日主有无根气**。无根则顺；有根则逆。
  - 与"刚柔"的衔接：**过柔无依 → 顺势**；**过刚无泄 → 逆而扶其食伤**。

### 算法可用规则（设计草案）

| 类型 | 规则 |
|---|---|
| 顺局触发 | `日主完全无根（地支无本气、无中气、无余气）∧ 某五行成势（比例 ≥ 0.6）` |
| 逆局（默认正格） | `日主有根 ∧ 五行可分主从 → 扶抑/通关/调候` |
| 顺局类型 | 从财 / 从官 / 从杀 / 从儿（食伤）/ 从势（多神并旺）/ 专旺 / 化气 |
| 顺局忌神 | 印比（破从势之根） |
| 逆局忌神 | 与正格 `chengBai.poGe` 一致 |
| ⚠ 边界 | "假从"——日主有微根但无力，仍按从论但忌神运不过——待源核 |

### 工程落点

- 当前 `getCongGe`（line 1148）和 `checkHuaQiGe`（line 1184）是分开判定的；**顺逆论应作为它们的统一前置判断**。
- 建议重构：
  ```
  determineShunNi(siZhu, riGan, wuXingStrength) → 'shun' | 'ni' | 'jia-shun'(假从)
    ↓
    'shun' → 进 getCongGe / checkZhuanWang / checkHuaQiGe（细分）
    'ni'   → 进 determineGeJu（正格 chengBai 流程）
    'jia-shun' → 进正格但标记为不稳，运到忌神时大败
  ```
- 新字段：`mingPan.shunNi: { type, rootStrength, dominantWuXing, isStable }`。
- ⚠ 这是与现有 `getCongGe` 数字阈值最直接冲突的一节——重构需要 fixture 套件回归测试以避免回归。

---

## 综合：五论之间的依赖关系

```
顺逆论（最顶层判断：扶抑 vs 顺势）
  ↓
体用论（确定体与用，定 ti/yong 候选）
  ↓
刚柔论（日主刚柔，影响扶抑方向）
  ↓
寒暖燥湿论（调候叠加，可改写用神）
  ↓
清浊论（最终评级，决定格局高低 jibie）
  ↓
（与《子平真诠》格局成败救应衔接，已在 2026-05-07 deepread 文件覆盖）
```

这与现有 `BaziEngine.calculate`（line 602+）的线性流程**完全不同**——现有流程是"算五行 → 取格 → 套用神"单向；五论体系要求**多次回路**（顺逆判断后可能跳出正格流程；调候判断后可能改写用神）。

---

## 后续待办

1. **首要**：拿到印刷版或开 WebFetch 权限后，**逐章核校短摘录**——目前所有"内容描述"都是 paraphrase，不是 evidence。
2. 推荐底本（按可靠度排序）：
   - A：中华书局《滴天髓阐微》点校本（袁树珊辑）
   - B：孙正治《滴天髓阐微校注》
   - C：台湾武陵出版社任铁樵原注影印本
   - D：ctext.org 全文（如有）
3. 核校优先级：寒暖燥湿（直接影响调候表）> 顺逆（影响从格判定）> 体用（影响整体取格架构）> 刚柔 > 清浊（评级用，可后置）。
4. 完成 verified 升格后，配套写 fixture：每论至少 3 条 case（典型成立 / 典型不成立 / 边界 case），落到 `lib/__tests__/bazi-tiyong.test.ts` 等文件。

---

## Claim 草案（待 maintainer 审阅后追加到 claims.json）

> ⚠ 全部 claim 的 `status` 标 `drafted_pending_source_extraction`，evidence 字段留空——因本次未抓到原文。等印刷版核校后补 evidence 与升格。

```json
[
  {
    "id": "bazi.tiyong.lun",
    "topic": "bazi/structural/tiyong",
    "type": "domain_rule",
    "status": "drafted_pending_source_extraction",
    "summary": "《滴天髓》体用论：体与用是相对概念。日主当令时日主为体、财官食伤为用；日主失令成势时当令神为体、日主求用于该神（化气/从格根源）。体用配合得宜则成格，体用乖违为病。",
    "evidence": [],
    "sources": ["bazi-ditianshui-chanwei"],
    "notes": "Stub claim：本次 WebFetch 被拒，无法抓取原文。所有内容基于通行解读 paraphrase，待印刷版（推荐中华书局点校本或孙正治校注）逐条核校后升格。",
    "repoRef": "docs/mingli/reading-notes/dichuixui-tiyong.md#一体用论",
    "createdAt": "2026-05-07"
  },
  {
    "id": "bazi.qingzhuo.lun",
    "topic": "bazi/structural/qingzhuo",
    "type": "domain_rule",
    "status": "drafted_pending_source_extraction",
    "summary": "《滴天髓》清浊论：清者用神有情、五行流通、忌神去净、相神到位；浊者用神被伤、五行壅塞、官煞/印枭/食伤混杂；半清半浊指有清有浊可互转。清浊决定格局高低 jibie。",
    "evidence": [],
    "sources": ["bazi-ditianshui-chanwei"],
    "notes": "Stub claim：同上。'流通'的工程实现（链长度 ≥ 4）待源核——原书未必给数字定义。",
    "repoRef": "docs/mingli/reading-notes/dichuixui-tiyong.md#二清浊论",
    "createdAt": "2026-05-07"
  },
  {
    "id": "bazi.hannuan-zaoshi.lun",
    "topic": "bazi/structural/hannuan-zaoshi",
    "type": "domain_rule",
    "status": "drafted_pending_source_extraction",
    "summary": "《滴天髓》寒暖燥湿四象：寒（冬令金水多）需火、暖（夏令木火多）需水、燥（火土多无水）需水、湿（水木多无火）需火。是《穷通宝鉴》调候表的底层逻辑——可用于反向校验现有 TIAO_HOU_YONG_SHEN 表的合理性。",
    "evidence": [],
    "sources": ["bazi-ditianshui-chanwei"],
    "notes": "Stub claim：threshold（'多'的定义）待源核。建议作为 Phase 2 调候模块的核心 claim，与 bazi.tiaohou.qiongtongbaojian 系列 claim 互证。",
    "repoRef": "docs/mingli/reading-notes/dichuixui-tiyong.md#三寒暖燥湿论",
    "createdAt": "2026-05-07"
  },
  {
    "id": "bazi.gangrou.lun",
    "topic": "bazi/structural/gangrou",
    "type": "domain_rule",
    "status": "drafted_pending_source_extraction",
    "summary": "《滴天髓》刚柔论：阳干当令印比多为刚、阴干失令财官食伤多为柔；刚柔相济为美（刚见食伤泄、柔见印比帮）；过刚易折，过柔易随（接顺逆论的从格触发）。",
    "evidence": [],
    "sources": ["bazi-ditianshui-chanwei"],
    "notes": "Stub claim：'4 个'阈值是设计草案数字，原书未必有定数。待印刷版核校。",
    "repoRef": "docs/mingli/reading-notes/dichuixui-tiyong.md#四刚柔论",
    "createdAt": "2026-05-07"
  },
  {
    "id": "bazi.shunni.lun",
    "topic": "bazi/structural/shunni",
    "type": "domain_rule",
    "status": "drafted_pending_source_extraction",
    "summary": "《滴天髓》顺逆论：日主有根则逆（扶抑/通关/调候，正格路径）；日主无根遇某五行成势则顺（从财/从官杀/从儿/从势/专旺/化气）。是从格与正格的统一前置判断。'假从'（微根但无力）属边界态，按从论但运到忌神大败。",
    "evidence": [],
    "sources": ["bazi-ditianshui-chanwei"],
    "notes": "Stub claim：'完全无根'与'微根'的工程定义（地支本气/中气/余气分级）待与现有 BaziEngine.getCongGe 实现对齐 + 印刷版核校。这是与现有数字阈值冲突最直接的一节。",
    "repoRef": "docs/mingli/reading-notes/dichuixui-tiyong.md#五顺逆论",
    "createdAt": "2026-05-07"
  }
]
```
