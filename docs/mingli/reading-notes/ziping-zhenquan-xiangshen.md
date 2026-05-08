# 《子平真诠评注》相神 / 成败救应 / 用神变化 / 格局高低 抽象章节摘读（2026-05-07）

> 范围：抽象层（不针对单一格局），覆盖《子平真诠》关于"如何判用神成败、如何取相神、如何评格局高低"的四章。这是 Phase 2 重写 `BaziEngine.determineGeJu` 的 **算法骨架来源**——决定 `chengBai` / `xiangShen` / `jiuYing` / `jibie` 字段填充流程，而不是某一个具体格局如何用。
>
> 与 `2026-05-07-ziping-zhenquan-geju-deepread.md`（per-格局深读）配套使用：deepread 给"什么算正官成、什么算财破"，本篇给"成/破/救应/高低"的通用判定流程。

## Source 与可靠性限制

### 本次实际使用

- **本次 session WebFetch / 网络抓取被禁用**，未能重新打开 `https://xm.yi958.com/gsqm/4272`、`https://xm.yi958.com/gsqm/4263`、`https://xm.yi958.com/gsqm/4270`、`https://www.zhonghuadiancang.com/xuanxueshushu/`、`https://ctext.org/zh` 任何一个链接。
- 文中"短摘录"全部 **复用自本仓库 `docs/mingli/reading-notes/2026-04-30-ziping-zhenquan-first-pass.md` 已提取段落**——该文件的引文在前一个 session 由 WebFetch 抓自易德轩 `https://xm.yi958.com/gsqm/4272`（《子平真诠（原文）（上）清·沈孝瞻》），已落入 git 历史。本篇没有新增任何未在 first-pass 中出现的字句。
- **没有徐乐吾评注层的引文**——first-pass 抓取的是沈孝瞻原文转载页，未含徐乐吾评注。算法可用规则表里凡来自徐乐吾评注的判定路径，本篇标 `⚠ 缺徐乐吾评注核校`。
- 商业站转载，未提供底本/校勘/影印页；进入 fixture / claims `status: text_cited_needs_fixture` 之前应补 A-tier 印刷版（中华书局点校本《子平真诠评注》，徐乐吾注，方重审校或类似）。
- 本篇 source 标注 `bazi-ziping-zhenquan` + `notes: "网络转载初校；徐乐吾评注层未取证；待印刷版 final review"`。

### 章节对应关系

| 本篇章节 | 沈孝瞻原文章名 | first-pass 中的位置 |
|---|---|---|
| 一 | 论相神紧要（卷一第十五章） | first-pass §15 |
| 二 | 论用神成败救应（卷一第九章） | first-pass §9 |
| 三 | 论用神变化（卷一第十章） | first-pass §10 |
| 四 | 论用神格局高低（卷一第十二章） | first-pass §12 |

> 注：原书"成败救应"在前、"相神"在后；本篇按工程相关性顺序重排：先把**相神**这把通用钥匙摆出来，再讲成败救应、变化、高低三层流程，方便对齐 `GeJuV2` 字段的求值顺序。

---

## 一、论相神紧要

### 短摘录（每段 ≤ 100 字符）

1. `月令既得用神，则别位亦必有相，若君之有相，辅者是也。`
2. `凡全局之格，赖此一字而成者，均谓之相也。`
3. `伤用神甚于伤身，伤相甚于伤用。`

### 算法可用规则

| 类型 | 规则 |
|---|---|
| 相神定义 | 月令用神之外，**全局赖以成格的那个干/支**即为相神；不限于固定十神表 |
| 取相神顺序 | (1) 先按格局通法取（如官用财生时财为相、杀逢食制时食为相）；(2) 通法取不到时，扫描四柱中"使该格成立的关键字"作为相神 |
| 相神位置 | 必在月令以外的"别位"——年/日/时柱的干支或月柱另一半（干或支） |
| 相神被破 → 影响 | "伤相甚于伤用"——相神被合/冲/破，格局立败，且严重于用神本身受伤 |
| 救应路径（针对相神被破） | (1) 救相之字（如官杀混杂中合去其一、原局有印护相）；(2) 大运/流年补一个等效相神；(3) 相神受伤无救 → 破格 |
| 相神 vs 用神 | 用神 = 月令所成的格局之核心；相神 = 辅佐用神成格的字。两者**不能合一**——同一个字不能同时是用神又是相神 |

### 工程落点

- `XiangShenInfo` 字段填充时机：在 `determineGeJu` 选定 `phaseId` / `yongShen` 之后立即扫描 4 柱寻相神。返回 `{ wuXing, shiShen, role: '财生官'|'印护官'|'食制杀'|'劫救印'|'印化杀'|'比劫帮身' ... }`。
- `xiangShen: null` 的语义：**不是"无相神"，而是"算法当前未能识别相神"**。文案需明确，不能直接说"此命无相"。
- 相神被破的 `JiuYingInfo` 优先级：在 `BaziEngine` 的成败判定流程中，"相神受伤"应触发与"用神受伤"相同甚至更重的破格扫描——目前代码完全没有此分支。
- 相神有可能是地支藏干（中气/余气），不只是透干——deepread 的"印重透财"/"杀重转印"都依赖此。

---

## 二、论用神成败救应

### 短摘录（每段 ≤ 100 字符）

1. `用神专寻月令，以四柱配之，必有成败。`
2. `成中有败，必是带忌；败中有成，全凭救应。`

### 算法可用规则

| 类型 | 规则 |
|---|---|
| 成格（cheng） | 月令用神得相神辅佐 + 相神不被破 + 用神本身不被合冲 |
| 破格（po） | 用神被合（贪合忘用）、被冲、被克制不当；或相神被破且无救 |
| 带忌 | "成中有败" = 表面成格但带忌神（如官格透伤、财格透比劫），需进一步看忌神是否被制 |
| 救应（jiuying） | "败中有成" = 已破之格通过特定字将其挽回，主要四类路径见下 |
| 救应类型（path 枚举） | (1) 去病（`qu-qing`/去清）：去掉病神留下用神，如官煞混杂去其一 / 重官重煞去其一；(2) 食制（`shi-zhi`）：以食伤制忌神（多用于杀格）；(3) 印化（`yin-hua`）：以印化忌神（杀化为印生身、伤官见印护官）；(4) 合杀/合凶（`he-sha`）：以合的方式去掉凶神（合煞留官、阳刃合杀） |
| 救应有效条件 | 救应之字 **(a)** 必须出现在原局（不能纯靠运补充才算原局成格）；**(b)** 自身不被冲合所伤；**(c)** 与被救之字位置相邻或可达（古法以邻位优先，但⚠ 资料冲突待印刷版核） |
| 救应失败 | 救应字本身被破 / 救应字反生忌神 / 救应路径互相矛盾（如食制路径下又透印） → 仍判 `po` |

### 工程落点

- `ChengBaiStatus` 三态判定流程（`determineGeJu` 内新增子流程）：
  1. 月令用神选定 → 扫相神
  2. 扫忌神（针对该格的禁忌字，由 PhaseRegistry 提供）
  3. 若无忌神出现 → `cheng`
  4. 若忌神出现且无救应字 → `po`
  5. 若忌神出现但救应字到位 → `jiuying`
- `JiuYingInfo.path` 枚举映射（与 `lib/bazi/types.ts:384` 对齐）：
  - `qu-qing` ← 去病/去清类（官煞混杂去一、重官重煞去一）
  - `shi-zhi` ← 食神制杀、伤官生财化比劫
  - `yin-hua` ← 印化杀、印护官、印化伤
  - `he-sha` ← 合煞留官、阳刃合杀、合去忌神
  - `other` ← 其余（待 per-格局深读补全；不应作 default）
- `JiuYingInfo[]` **可有多条**：一个破格场景可能同时存在多条救应路径（如官煞混杂既可"合煞"又可"制煞"），算法应全部记录，由解释层选最强的展示。

---

## 三、论用神变化

### 短摘录（每段 ≤ 100 字符）

1. `用神既主月令矣，然月令所藏不一，而用神遂有变化。`
2. `八字非用神不立，用神非变化不灵。`

### 算法可用规则

| 类型 | 规则 |
|---|---|
| 变化触发条件（trigger） | (1) 月令本气不透干，但月令所藏中气/余气透出；(2) 月令本气透干，但被合化或冲克失效；(3) 地支会合三合/三会/六合改变月令五行性质；(4) 月令为子午卯酉一类"专气支"则原则上不变化（除非被冲） |
| 变化后用神取法（优先级链） | **优先级 1**：月令本气透干（首选） → **优先级 2**：月令藏干透干（中气优先于余气） → **优先级 3**：月令所参与的会合三合所成五行 → **优先级 4**：实在无可取时，按建禄/月劫处理 |
| 变化的善与不善 | 原则：变化后仍有用神可立 = 善；变化导致月令五行被合化掉、用神无所附 = 不善（破格风险） |
| "变而不失本格" | 月令藏干透出的虽非本气，但所成格局与本气方向相同（如月令巳火藏戊土透出但戊土仍为日主之财） → 仍按原格论，仅相神/位置调整 |
| 不变化的硬条件 | 月令为子（专癸）、午（专丁己微）、卯（专乙）、酉（专辛）这四支时，本气专一 → 原则不变化（⚠ 午中己土透出能否变成印格，资料冲突待印刷版核） |

### 工程落点

- `determineGeJu` 取格优先级链（落入代码）：
  ```
  1. 月令本气是否透出 4 柱天干 → 取该十神为格
  2. 否则月令中气是否透出 → 取该十神为格
  3. 否则月令余气是否透出 → 取该十神为格
  4. 否则检查月支是否参与三合/三会成局 → 取所成五行对应十神
  5. 否则月令本气十神为格（建禄/月劫处理）
  ```
  当前代码 `BaziEngine.determineGeJu` 在步骤 1 就停了，2/3/4 路径完全缺失。
- `GeJuV2.basis` 字段值与上述优先级一一对应：`'yueling-benqi-tougan' | 'yueling-canggan' | 'huiju-sanhe' | 'sanhui'`（已在 deepread 类型草案中预留）。
- 何时切到"变格"：当步骤 1 失败但步骤 2/3/4 成功时，`basis` 标 `yueling-canggan` / `huiju-sanhe` / `sanhui`，并记录 `originalYongShen`（月令本气）vs `actualYongShen`（取出的）差异，便于解释层说明"本格本应为 X，因 Y 字未透/会合而变为 Z"。
- `checkHuaQiGe`（天干五合化气）目前与"用神变化"概念混在一起；按本章应区分：**化气格**是日主自身被合化（特殊格），**用神变化**是月令所成格的变化（正格内部）。两者不应共用一条逻辑。

---

## 四、论用神格局高低

### 短摘录（每段 ≤ 100 字符）

1. `八字既有用神，必有格局，有格局必有高低。`
2. `其理之大纲，亦在有情、有力无力之间而已。`

### 算法可用规则

| 类型 | 规则 |
|---|---|
| 上格（shang） | 成格（`cheng`） + 用神有力（通根透干） + 相神齐全且不被破 + 八字清纯（无混杂） |
| 中格（zhong） | (a) 成格但相神不齐 / 相神有轻微瑕疵；或 (b) 破后救应到位（`jiuying`）但救应不完美（救字本身偏弱、位置不利） |
| 下格（xia） | 破格无救（`po` 且 `jiuying` 为空或失败）；或用神/相神俱伤；或忌神当令而无制 |
| 高低判别四要素 | (1) **有情**：用神、相神、日主三者关系是否相生相护、不互克；(2) **无情**：相神反克用神、用神反伤日主、相隔太远不能相顾；(3) **有力**：用神/相神是否通根、得月令、得透干、得会合扶助；(4) **无力**：用神浮于天干无根、相神虚透、被合化夺力 |
| 清浊 | "清" = 一格独成、用相分明、忌神不犯；"浊" = 多格交错、用相不分、忌神横行 → 清者高、浊者低（⚠ 此判定细节在《滴天髓》"清浊章"更详尽，本章只给大纲） |
| 格名不决定高低 | "财官印食杀伤劫刃皆有贵贱"——同样正官格可能上可至卿相、下可至贫贱，关键看上述四要素 |

### 工程落点

- `GeJuRank` 判定流程（替换当前 `BaziEngine.ts` "月支主气 == 用神 → 上格" 的二段判）：
  ```
  if chengBai == 'cheng':
    if 用神有力 + 相神齐 + 八字清纯 → 'shang'
    else → 'zhong'
  elif chengBai == 'jiuying':
    if 救应路径完美（救字有力、位置邻接、不被反破） → 'zhong'
    else → 'xia'
  elif chengBai == 'po':
    → 'xia'
  ```
- "用神有力"的可机器化判据：用神五行通根强度 ≥ `中根`（参 `RootStrengthLabel`），且至少一柱透干；"相神有力"同理。
- "八字清纯" / "有情无情" 在本章只给大纲——**不要 Phase 2 一次落到底**。建议先实现"成格 + 用神有力 + 相神齐 + 无忌神"四布尔判 `shang`，其余降为 `zhong`，破格降 `xia`；"清浊/有情"留待 Phase 3 接入《滴天髓》深读后再细化。
- 当前 `GeJu.strength: '上'|'中'|'下'` 的逻辑（`BaziEngine.ts` 月支主气 vs `yongShen` 比较）**全部应废弃**——它把"日主用神"和"格局用神"混为一谈，与本章判定毫无对应。

---

## 五、四章交叉调用关系（求值顺序）

按本篇规则，`determineGeJu` Phase 2 的求值顺序应为：

```
Step 1  取月令用神（章三：用神变化优先级链）
        → 输出：yongShen, basis, phaseId

Step 2  扫相神（章一：相神紧要）
        → 输出：xiangShen | null

Step 3  扫忌神 & 救应（章二：成败救应）
        → 输出：chengBai, jiuYing[]

Step 4  评级（章四：格局高低）
        → 输出：jibie
```

任一步异常（如 Step 1 拿不到合法 phaseId）→ 整个 GeJuV2 标 `category: 'special'` 走杂格分支，不强行评级。

---

## 综合：本篇与 deepread 的分工

| 维度 | 本篇（抽象四章） | deepread（per-格局四章） |
|---|---|---|
| 回答的问题 | 通用流程 / 字段语义 / 优先级 | 某格的"成败破救"具体规则 |
| 喂给代码的形式 | `determineGeJu` 主流程的伪码 | PhaseRegistry 的格局元数据 + chengBai 子规则 |
| 引用范围 | 论用神变化 / 成败救应 / 相神 / 高低 | 论正官 / 论财 / 论印 / 论七杀 |
| Claim 类型 | `domain_rule`（流程性） | `domain_rule`（per-格局性） |

两篇都属于 first-pass 之上的二次细读，**仍未替代印刷版校勘**。

---

## Claim 草案（待加入 `claims.json`）

> 草案使用本任务指定的 schema（`topic` / `type` / `summary` / `evidence` / `sources` / `notes` / `repoRef` / `createdAt`）。落入 `claims.json` 时再按仓库实际 schema（`domain` / `claim` / `sourceIds` / `repoRefs` / `confidence` / `status`）转译，并合并 `bazi-ziping-zhenquan` source。

```json
[
  {
    "id": "bazi.xiangshen.definition",
    "topic": "bazi/structural/xiangshen",
    "type": "domain_rule",
    "status": "drafted_from_reading",
    "summary": "相神 = 月令用神之外、全局赖以成格的关键字；不限于固定十神表，可为任一柱的干或支。一格必有相神，相神不存在则成格存疑；相神受伤甚于用神受伤。",
    "evidence": [
      "《子平真诠》论相神紧要：'月令既得用神，则别位亦必有相，若君之有相，辅者是也。'",
      "《子平真诠》论相神紧要：'凡全局之格，赖此一字而成者，均谓之相也。'",
      "《子平真诠》论相神紧要：'伤用神甚于伤身，伤相甚于伤用。'"
    ],
    "sources": ["bazi-ziping-zhenquan"],
    "notes": "网络转载初校（reuse 自 first-pass，本 session 未能重抓）；徐乐吾评注层未取证；待印刷版 final review",
    "repoRef": "docs/mingli/reading-notes/ziping-zhenquan-xiangshen.md",
    "createdAt": "2026-05-07"
  },
  {
    "id": "bazi.xiangshen.cheng-po-rule",
    "topic": "bazi/structural/xiangshen",
    "type": "domain_rule",
    "status": "drafted_from_reading",
    "summary": "相神被合/冲/破即触发破格判定，且优先级高于'用神被破'本身；XiangShenInfo.intact = false 时 ChengBaiStatus 不可为 'cheng'。",
    "evidence": [
      "《子平真诠》论相神紧要：'伤用神甚于伤身，伤相甚于伤用。'"
    ],
    "sources": ["bazi-ziping-zhenquan"],
    "notes": "推导自相神紧要章；具体'伤'的判定（合/冲/克/害是否等价）待印刷版与徐乐吾评注核",
    "repoRef": "docs/mingli/reading-notes/ziping-zhenquan-xiangshen.md",
    "createdAt": "2026-05-07"
  },
  {
    "id": "bazi.jiuying.path-classification",
    "topic": "bazi/structural/jiuying",
    "type": "domain_rule",
    "status": "drafted_from_reading",
    "summary": "救应路径分四类：去清（qu-qing，去病留用神）/ 食制（shi-zhi，以食伤制忌神）/ 印化（yin-hua，以印化忌神）/ 合凶（he-sha，以合去凶神），其余归 other。一个破格场景可同时存在多条救应路径。",
    "evidence": [
      "《子平真诠》论用神成败救应：'用神专寻月令，以四柱配之，必有成败。'",
      "《子平真诠》论用神成败救应：'成中有败，必是带忌；败中有成，全凭救应。'"
    ],
    "sources": ["bazi-ziping-zhenquan"],
    "notes": "四类枚举与 lib/bazi/types.ts:384 JiuYingInfo.path 一致；具体每条路径的 per-格局映射来自 deepread；本章只确立分类层",
    "repoRef": "docs/mingli/reading-notes/ziping-zhenquan-xiangshen.md",
    "createdAt": "2026-05-07"
  },
  {
    "id": "bazi.yongshen.priority-chain",
    "topic": "bazi/structural/yongshen-extraction",
    "type": "domain_rule",
    "status": "drafted_from_reading",
    "summary": "取格优先级链：月令本气透干 → 月令中气透干 → 月令余气透干 → 月支参与的三合/三会成局 → 建禄/月劫处理。当前 BaziEngine.determineGeJu 仅实现第一步。",
    "evidence": [
      "《子平真诠》论用神变化：'用神既主月令矣，然月令所藏不一，而用神遂有变化。'",
      "《子平真诠》论用神变化：'八字非用神不立，用神非变化不灵。'"
    ],
    "sources": ["bazi-ziping-zhenquan"],
    "notes": "优先级序与 GeJuV2.basis 枚举（yueling-benqi-tougan / yueling-canggan / huiju-sanhe / sanhui）一一对应；中气 vs 余气优先序为常见解释，待印刷版核",
    "repoRef": "docs/mingli/reading-notes/ziping-zhenquan-xiangshen.md",
    "createdAt": "2026-05-07"
  },
  {
    "id": "bazi.yongshen.bianhua-trigger",
    "topic": "bazi/structural/yongshen-extraction",
    "type": "domain_rule",
    "status": "drafted_from_reading",
    "summary": "用神变化触发条件：(1) 月令本气不透干；(2) 月令本气透干但被合化/冲克失效；(3) 月支参与三合/三会改变五行；(4) 子午卯酉为专气支，原则上不变化（除非被冲）。",
    "evidence": [
      "《子平真诠》论用神变化：'然月令所藏不一，而用神遂有变化。'"
    ],
    "sources": ["bazi-ziping-zhenquan"],
    "notes": "子午卯酉专气例外规则常见但具体边界（如午中己土能否变印）⚠ 资料冲突待印刷版核；化气格（日主被合化）应与用神变化区分实现",
    "repoRef": "docs/mingli/reading-notes/ziping-zhenquan-xiangshen.md",
    "createdAt": "2026-05-07"
  },
  {
    "id": "bazi.geju.rank-criteria",
    "topic": "bazi/structural/geju-rank",
    "type": "domain_rule",
    "status": "drafted_from_reading",
    "summary": "GeJuRank 判定基于'有情/无情、有力/无力、清/浊、相神是否破'四要素：成格+用神有力+相神齐+八字清纯=上；成格但相神不全或救应不完美=中；破格无救=下。格名本身不决定高低。",
    "evidence": [
      "《子平真诠》论用神格局高低：'八字既有用神，必有格局，有格局必有高低。'",
      "《子平真诠》论用神格局高低：'其理之大纲，亦在有情、有力无力之间而已。'"
    ],
    "sources": ["bazi-ziping-zhenquan"],
    "notes": "Phase 2 先以'成格 + 用神通根 ≥ 中根 + 相神齐 + 无忌神'布尔判 shang；'清浊/有情无情'细节留 Phase 3 接《滴天髓》清浊章；当前 BaziEngine 月支主气 vs yongShen 二段判应废弃",
    "repoRef": "docs/mingli/reading-notes/ziping-zhenquan-xiangshen.md",
    "createdAt": "2026-05-07"
  }
]
```
