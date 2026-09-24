# B1–B5 本地报告增量：内容与证据基础独立审查

2026-09-24。审查基线 `8e04c22`。本次只读源码、既有合成测试与归档原文，核对了下列来源文件的 SHA-256；没有运行引擎、测试、构建或 AI，没有验证新 UI。本文是实施前的内容基础评审，不能代替实施后的样稿验收。

## 结论

可以立即做有价值的**八字导读增量**：B1 把月令与实际同五行根、印支持连起来；B2/B3 把本盘的两个以上关系连成可读链；B4 对已有窄规则真正改变主句，解释局部路径为何可用、受阻或未定；B5 明确比较本盘不同口径为何给出不同结果。

其中最有判别力的现成内容是 B4 的**逐柱对象、根与合的依赖链**，其次是严格专旺子集。它们确实随命盘条件改变结论，不只是把位置换进词条。但它们解释的是所选传统规则中的结构作用，尚不能宣称已完成性格、事业、关系的个体综合阅读，也不能宣称达到测测式完整基础报告。B1/B2/B3 的基本分布、月令矩阵和 B5 的计数比较仍须按结构导读计数。

`NatalReadingCatalog.swift:59` 现有八字条目是日干定义、逐透干/藏干位置、五组关系分布和通用自我观察。`NatalReadingReport.swift:45` 摘要仍是四柱复述。把这些条目改为五章、加图或增加术语定义，不会自动达到 proposal-final.md 的“组合意义、反例、逐盘价值”门槛。

## 可立即呈现的最小 B1–B5 范围

所有路径以下列原始本命载荷 `/mingPan` 为根，不能为了复用问答代码伪造 `get_domain` 回执。

| 模块 | 已有可用事实与规则 | 本轮值得写的差异 | 必须保留的边界与反例 |
|---|---|---|---|
| B1 日主与月令 | `riZhu`、`siZhu.month`；`riZhuStructure.evidence.monthBranch/monthMainQi/monthRelation/sameElementRoots/resourceSupport`；`structural.ts:369` | 月支本气怎样对待日主；本盘其他支中是否仍有同五行藏干与印支持。把“失令但有根”与“本盘未见同五行根”分开，使用户知道月令不是全盘结论 | 月令本气表是工程矩阵，未作月内司令细分；同五行根与印支持必须分列。`rootStrength.label == 无根` 不能改写成“没有根”：该档含总量小于 0.3 的非零余气，且旧总量混入印支持。不能用日干意象推人格 |
| B2 五行怎样相连 | `siZhu` 真实五行位置；`shiShenRelations` 的有向克边；B4 依赖链引用的相关元素 | 以一条实际链解释“水克火”与“土克水”同时出现时，为什么不能只取第一条；标清参与柱位、层次和状态。优先复用 B4 的已审核链，避免另外创造一个五行结论 | `shiShenRelations.outcomeEstablished` 恒为 false，克向不等于克制已生效；生克底图是通用帮助。未见某元素不是缺少现实能力；默认不显示权重百分比 |
| B3 十神在盘中怎样配合 | 年/月/时干与四支藏干两层；`shiShenRelations` 只扫描非日干透干；`structural.ts:757` | 选 1–2 条本盘确实出现的组合关系，先讲谁与谁联系，再连到 B4 的条件。例如“食神与七杀在透干层有克向”，若 B4 有来源裁定再讲具体有效/阻断；没有裁定就如实停在克向 | `食神制七杀`、`印制伤官` 等引擎名称本身不是组合成立的证书。藏干不能冒充透干。同透不等于伤官佩印、食神制杀成立。来源《论伤官》仍要求伤官旺、身稍弱等；目前没有完整力量求解 |
| B4 格局条件 | `geJuV2` 的月令选择、`conditionalEvidence`、`rescueEvidence.dependencyResolution`、`specialPatternEvidence` | 候选为何出现；某局部路径有效/受阻/未定的原因；已核对限制要改变标题与摘要。此模块可贡献首屏最有价值的条件化摘要 | 只读 `name/chengBai/jibie` 不合格。`available` 只指选定条文的局部路径；没有扫描到救应不等于无救。专旺“未命中所选子集”不等于所有流派均否定该格 |
| B5 强弱与取用为什么不同 | `wuXingStrength` 固定计数、`riZhuStructure` 月令/根印矩阵、`geJuV2.yongShen` 结构角色、`tiaoHou` 文献候选 | 同一盘并列“固定计数得出什么、月令/根印矩阵为何不同、格局用神负责什么”。结果相同也说明不构成互证。调候只在来源完整时列该日干/月支的文献候选 | 固定计数包含日干 1 次，总量 8，月令未加权；根印矩阵权重是 1/0.5/0.2，不是 0.6/0.2/0.2。两法都不能升级为完整旺衰。调候 `automatedSelection=false`，不能选成个人喜用，更不能生幸运色/职业建议 |

B1 的强项是纠正“只看月份就认定身强弱”；B2/B3 的强项是让同一张盘中的关系能一起阅读。它们比词典更有上下文，但仍是**本盘结构解释**，不要把这个名称偷换为“已确认的人格特点”。缺少合格 B4 命中时，首屏应给具体结构与当前缺口，不用现代练习补空。

## B4 的来源、条件和能改变结论的反例

### 1. 有根的对象不能因为五合就从盘中删除

- 来源：`docs/mingli/source-texts/bazi/ziping-zhenquan/01-foundations.md:80`，“如地支通根，则虽合而不失其用，喜忌依然存在”；`00-abstract-chapters.md:182`，“若丁火通根，则合之不去”。当前文件为原文与徐注混排的电子转录，未校印本。
- 已算：`geJuV2.rescueEvidence.combinations[]` 的确切 actor/target 柱位、`status`、`removalEstablished`；Swift `BaziAdjudicationTrace.swift:97` 重建所有五合配对并逐条检查。
- 条件：所选徐注口径中的五合目标确有同五行藏干根；不是只有“相同天干”才算根。目标有根时先返回 `rooted-role-retained`。日主自合另为 `day-master-no-removal`，不能把它与非日柱对象混算。
- 对照：`壬丁甲辛 / 申酉寅丑` 中寅藏丙，丁有同五行根；改为 `申酉子丑` 才移除火根。前者不能写“壬把丁合去”。这些是规则坐标，不冒充真实生日。
- 友好表达：“这两个干虽然相合，丁在地支仍有同类根，不能把它原来的作用直接划掉。读这组配合时，仍要把丁保留下来。”
- 不足：这能否定“自动删除”，不能证明丁已胜过壬、所有原作用完全不变、或此盘已成格。

### 2. 救应者自身受制，会改变整条局部路径

- 来源：`00-abstract-chapters.md:220`，“甲用酉官，透丁逢癸印，制伤以护官矣，而又逢戊，癸合戊而不制丁”；同段“丁用酉财，透癸逢己……又透甲，己合甲而不制癸”。来源 ID `ziping-helper-constraints-v1`，实现 `rescueDependencies.ts:28`。
- 可用窄范围 A：甲日、酉月、选定正官，癸制丁。可用窄范围 B：丁日、酉月、选定正财/偏财，己制癸。只有返回的 canonical action 在依赖重建后 `available` 才能说局部路径可用。
- 状态不能只看一条克边：先看施事者是否被已成立的合牵制；存在未解的来合或来克就保持未定；未定的保护不能自动抵消未定的攻击。所有对象按柱位识别，同名干不能共享结论。
- 对照：`丁癸甲戊 / 未酉寅戌` 的癸无水根，被有根戊合，癸制丁路径受阻；改时支辰后癸有根，不得仍称已合去，但戊癸的实际制约仍需判定。`癸己丁甲 / 子酉卯亥` 的己受甲合，路径受阻；将末干甲换辛，移除这项阻断，在该窄规则中局部路径可用。
- 友好表达：“这里不能只看到‘己能制癸’就停下。还要看己是否仍能起作用；本盘的己自身受合牵制，因此这条制癸路径不能照常成立。”
- 不足：默认相神/病点表并不穷尽全局。局部可用不推出全格成功、职业/财富结果，也不直接套用到所有丁日财格或所有食神七杀同透。

### 3. 明确来源允许的保护链，需要保留藏干/月令层次

- 来源：`00-abstract-chapters.md:220`，“乙用酉煞，年丁月癸，时上逢戊，则合去癸印以使丁得制煞者，全赖戊之相”。
- 精确谓词：乙日、酉月、选定七杀、年丁/月癸/时戊；通过对戊癸根与限制的复核，再判断丁对**月令本气辛**的局部作用。`rescueDependencies.ts:35` 明确 targetLayer 为 `month-main-qi`。
- 对照：`丁癸乙戊 / 巳酉卯戌` 有保护链；改末支辰使癸有根，解除癸制丁的证明消失，状态改未定。不能把藏辛改写成“月干辛”或“辛透出”。
- 友好表达：“按这条规则，先看时干戊能否牵制月干癸，再判断年干丁能否继续制约月令里的辛。中间一步改变，后面的读法也会改变。”
- 不足：当前只覆盖明确源例范围；不能推广为“所有隔位合都有效”。`甲己` 中隔庚另有明确阻断，其他遥合配置仍可能未决。

### 4. 同名的两处不能合并成一份作用

- 来源：`01-foundations.md:118`，“甲生寅卯，月时两透辛官，以年丙合月辛，是为合一留一”；`rescueDependencies.ts:16` 保留 occurrence selection。
- 条件：干顺序 `丙辛甲辛`，寅/卯月；先选择月辛，保留时辛。选择对象不代表月辛一定失去作用，根与制约仍需核对。
- 对照：`丙辛甲辛 / 寅卯子午` 与 `丙辛甲辛 / 酉卯子午`。后一例辛有酉根，必须保留作用。换月支或交换干位后，不继续继承原文的位置特权。
- 友好表达：“月干和时干虽然同为辛，所选条文先讨论丙与月辛的配合，时辛仍需单独保留。不能把一处受合写成两处都消失。”

### 5. 专旺：有可复核的成立子集，也有真实反证

- 来源：`ditianshui-chanwei/tongshen-10-xingxiang-bage.md:94` 任注“或方或局全……必要得时当令”；`ziping-zhenquan/01-foundations.md:70` 起司令表；`43-zage.md` 保留方局不全的徐注异说。
- 已算：`specialPatternEvidence`；方法 `zhuanwang-adjudication-v1`、profile `ditianshui-ren-full-formation-v1`。需完整方/局（土须四库）、所选时令、没有显见克神及未裁定的外围藏干克神。季末月必须绑定真实出生月节上下文及徐注司令，不把月名当整月得令。
- 对照：木方完整仍需看透金；改变一个干为庚即可改变主句。土四库齐全而节后日数缺失应为 `needs-month-commander`；所选表土司令前后也要改变状态。参与方局的藏干不能逐项冒充透出破神；原文庚申乙酉庚戌庚辰例中戌藏丁未否定从革。
- 友好表达：“本盘的方局、时令和所选克神条件都已核对，因此满足这套专旺规则的限定条件。这个名称只说明当前结构，尚不代表整格高低或人生结果。”
- 不足：`not-established-in-selected-profile` 是本子集未成立，不是“没有格局”；从格/化气仍为工程候选，不跟着专旺子集一起升级。

## 原生日合成对照：可以直接给父任务离线复算

以下日期来自现成真实 dispatch 测试，不是人工拼柱。**本审查仅读测试，未重新运行，实施时仍须用当前 bundle 的 natal 命令重算**。均为男、经度 120、`Asia/Shanghai`、17:30；不能拿规则坐标代替这些生日样稿。

| 合成出生日期 | 既有测试断言的四柱 | `canonical-helper-control` 状态 | 本盘应改变的正文 |
|---|---|---|---|
| 1984-09-10 | 甲子、癸酉、丁未、己酉 | `unresolved` | “己在未中有根，不能仅因甲己相合就认定己已失去作用；甲对己的制约仍未解决，因此目前不能确定己制癸这条路径有效。” |
| 1984-09-20 | 甲子、癸酉、丁巳、己酉 | `available` | “这组配合先要看制约者是否仍能起作用：年干甲受己合牵制后，时干己制月干癸的局部路径可用。” |
| 1984-09-30 | 甲子、癸酉、丁卯、己酉 | `blocked` | “己自身受合牵制，因此不能沿用己制癸这条路径。这里改变的是一条局部配合，不是对整个人作吉凶评价。” |

每段都须就近保留“所选徐注规则的局部配合，不等于全局成败”。其区别不是单纯换日支字样，而是支持方/制约方的根不同，导致依赖链结论不同。

精确入口：`native/Engine/src/bazi/__tests__/rescueDependenciesDispatch.test.ts:3`；Swift 消费验证 `native/Core/Tests/SujiCoreTests/BaziRescueDependencyTests.swift:62`。另可补 1986-03-11 与 1986-03-31、13:30、男、经度120，前者月辛局部受合可用，后者月辛有根保留（同 TS 文件第27行）。专旺实际生日既有例为 1980-01-26 07:30、男、经度120：`BaziAdjudicationTraceTests.swift:8`，需重算后再声称当次成功。

样稿仍需另加“不命中主要组合的合法盘”、同日主异月份、固定计数与结构矩阵不一致、调候文献未审核/缺失等盘，不能只拿上面三份命中样本说明全部用户均有同等内容。

## 现有 Swift 能怎样安全复用

### 可复用的是纯数据核验器，不是问道的回执来源

1. `BaziStrengthTrace.make(pillars:strength:structure:)`（`BaziStrengthTrace.swift:49`）可以直接接 `mingPan.siZhu / wuXingStrength / riZhuStructure`。它核对计数贡献、总量、同五行根与印支持、工程矩阵。它输出的是工程口径核对文本，不能当成古籍旺衰裁定。
2. `BaziPatternConditionTrace.make(root:)`（第5行）核对返回克/合/生边和柱位；只说明候选关系与限制，**不是候选有效性的证明**。它显示最多两个例子，不要把示例当成全盘穷举。
3. `BaziAdjudicationTrace.make(root:)`（第15行）核对专旺和救应的来源、根、柱位、月节/司令。它内部调用 `BaziRescueDependencies.make`，后者从四柱独立重建 dependency stage，并与返回 actions/statuses 比对。
4. 本地 adapter 可以构造无来源声明的只读值投影：`bazi.birthDateTime ← mingPan.birthDateTime`、`pillars ← siZhu`、`dayMaster ← riZhu`、`patternAnalysis ← geJuV2`。这只是为了复用旧函数的字段路径。不得建立 `ToolReceipt`、callID、toolContext，或声称已执行 `get_domain`。
5. 所有返回 pointer 必须经过有限、显式、前缀完整匹配的映射回**原始** `/mingPan/...`；从原 dossier 取值、建证据和 snapshot projection。不要把投影对象的 hash 当成账号授权。`NatalReadingCompiler.natal` 的 owner/birth/revision/current-dossier 检查仍是外层必要条件。

不存在名为 `BaziStructureTrace` 的独立安全解析器；`BaziNatalAssertions.swift` 是对自由正文/真实工具历史的断言检查，不是本地报告编译器。当前 `NatalReadingInput.Bazi` 只解码出生、日主、四柱、历法，尚未解码/检查上述扩展字段。

### 最小 B4 合同与来源闸门

建议最小输出单元至少有 `moduleID`、稳定 rule/claim ID、`kind`（取格候选/局部成立/局部阻断/未决/所选子集成立）、一句结果、解释原因、相邻限制、原载荷 evidence pointers、来源 ID/path/hash/locator、方法/profile 版本。摘要从已通过的单元选择，不另写一份无证据概要。

- 基础闸门：四柱与日主已验证；顶层 `assessmentStatus=heuristic-candidate`，name/category/yongShen/yongShenGan/yongShenShiShen 保持可识别且相容；普通格的 `conditionalEvidence.selectedYong` 必须等于顶层取用十神。不要只核对两个字段互相相等，就声称重新验证了完整取格算法。
- 取格文字：只在 `selectionBasis` 与对应月支藏干序位、实际透出柱一致时说本/中/余气透出；`sanhe/sanhui` 的代表干是 `representativeGan` 生成的代理，不能说实际透干。`jianlu-yueliu` 是所有兜底月本气的 basis 名，不是所有盘都“建禄”。日干在引擎取格 stemSet 内，B3 分布却排除日干本人；必须分别解释，不能暗改任一政策。
- 条件闸门：存在 `conditionalEvidence` 就要求 `BaziPatternConditionTrace` 成功；存在 `specialPatternEvidence/rescueEvidence` 就要求 `BaziAdjudicationTrace` 成功。返回 nil 是该模块拒绝，不得删掉坏字段再以低配文本放行；空文本则是已验证但没有可选的局部解释，不能伪造 positive claim。
- 来源闸门：保留代码已有固定 source ID、文件、hash、method/profile 检查；新字句如果用到代码尚未验证的 `unmetConditions`、来克、根或 source quote，须增加对应验证，不能因为 parser 返回非 nil 就信任整个 JSON。固定电子本 hash 只证明本版本引用一致，不证明预测有效或完成校勘。
- 依赖闸门：B4 的 causal summary 要绑定所选 action 及其 `actorCombinationIndexes/blockingCombinationIndexes/attacks.protectionCombinationIndexes`，不能只保存 `status=available`；状态为未定时要保留其具体原因。`BaziRescueDependencies.swift:137` 的 `bindAction` 是现成参考。
- 失败隔离：B4 扩展字段坏或未覆盖时，B1 的已验证日干/月令基本事实仍可读；但是同一个未通过 B4 单元不能进入 B2/B3 摘要。现在 `NatalReadingCompiler.natal` 对八字与紫微统一 throw，扩展时不要把一个可选模块解析失败变成全册消失。
- snapshot：当前报告 hash 收集的是 entries 的 evidence paths。新摘要若使用额外字段，必须将其对应的已验证模块证据也加入投影，否则内容变化但 ID 不变；变更内容和适配版本。

## 直接搬用 BaziFrameworkReading 的风险

| 风险 | 具体位置 | 建议 |
|---|---|---|
| 伪造工具执行来源 | `BaziFrameworkReading.swift:107` 只接受当前 orchestration 的 `get_domain` receipts；`FieldEvidence` 有 `toolCallID` | 只复用纯核验函数及编辑内容，不为本地报告创建 receipt |
| 特定问题/领域污染普通报告 | `plan:92` 固定 `domain=事业`；`applies:98` 只识别扶抑与格局比较 | 普通报告不调用 plan/applies/compose；也不引入 AI 选择 |
| 一个无关缺字段使全模块失败 | `catalog:150` 同时要求固定计数、格局及政策；它是完整比较答复的入口 | 本地按 B1–B5 分模块校验，不能用整个 catalog 判全册可读性 |
| “简述”不是理想的报告摘要 | `pattern-brief` 仍把完整 adjudication brief 拼入；`BaziAdjudicationTrace:134` 只拿前两个枚举顺序的配对 finding | 建立固定编辑优先序：本盘支持/阻断/未决及原因优先；原 brief 可用于详情参考，不能只截字数 |
| negative 特殊格信息可能无正文 | `BaziAdjudicationTrace:83` 对未命中子集不追加解释 | 新编译器要从已验证的原因生成收窄文字；不能从空文本推出“无格” |
| candidate 名称比结论更响亮 | `geJuV2.chengBai/jibie` 仍是工程兼容字段，旧路径会把未被明确 refute 的救应当候选覆盖 | 普通层不显示“上格/成格/破格”标签，不据此排序或评分 |
| 词义与因果混淆 | `relations` claim 只有日主元素；`tiaohou` claim 只按日干/月支匹配文献 | 前者归读图帮助，后者归文献候选；不计为完整个体解释 |

特别注意：`BaziAdjudicationTrace` 验证的是它写出的范围，不会重新执行 `selectYongShen`；`BaziPatternConditionTrace` 也不验证全部根、helper candidates 与所有候选集合的完备性。它们不能作为“JSON 整体可信”的印章。

## 仍缺少的内容支持

- 日干人物型、人格式形容词：`BaziEngine.RI_ZHU_DESC` 不可用作已审核个人结论。现有基础来源本身警告不要执着大林/微苗类比。
- 伤官佩印、食神制杀、伤官生财的全盘成立条件：目前有相关词义与局部克向，缺完整旺衰、寒暖、纯杂及效力求解；《论伤官》不能只截“印能制伤”而丢掉原条件。
- 全局救应竞争、循环、各家异文的通用优先级；通用藏干施事、支合解冲、成化；从格/化气的完整来源裁定。
- 调候 registry 已核对转录的格子仍 `automatedSelection=false`。例如甲寅“初春余寒”与甲卯“阳刃驾杀须财资”的上下文不同，不能把候选表加工成日干/月支固定喜用表。
- 通用人格/职业/伴侣/健康结论与现代行动建议，没有因为传统关系已算出就自动取得证据。通用自我观察可以选读，但不得撑起“个体阅读合格”计数。

## 本审查接受的本轮交付声明

可以说：“我的册页增加了按日主、五行、十神、格局条件、取用口径组织的本地阅读；部分已审核规则能解释这张盘的配合为何不同。”

不可以说：“已经生成完整个人命理报告”“B1–B5 已全部完成个体综合解读”“格局或用神已经确定”。最终应以当前 bundle 生成的完整合成样稿逐盘判级；如果三份对照以外的合法盘只有词义与位置，就仍明确交付为八字导读增量。

### 本次复核的来源版本

| 文件（`docs/mingli/source-texts/bazi/` 下） | 本次实读 SHA-256 |
|---|---|
| `ziping-zhenquan/00-abstract-chapters.md` | `5b930c11310899b50703696870d9024ba4e00fca6ad177e57d6fa5e3f8a4964f` |
| `ziping-zhenquan/01-foundations.md` | `8ea626e3744bb7129351b57dd3c4d6b6be595484345d8ea8101df50611993596` |
| `ziping-zhenquan/35-yinshou.md` | `d87e8f7df9f15175b26a75e9acee2a1b6e50b2df1b4ef1b5f189c38d8aa7a63c` |
| `ditianshui-chanwei/tongshen-10-xingxiang-bage.md` | `141085eeb8f5faba79a29dd1a08c8130fbdea9d2d6b81cea234c188dc6fe8183` |
| `ziping-zhenquan/43-zage.md` | `a7998453fbfd09d9e1e32e5b4b36b56ae79e81a408348a64d5ae1995dd961e56` |
| `qiongtong-baojian/jiamu.md` | `84393a67854fc642ef5fdad1b810ccb843ec5fc794fe6afb9857c33132071651` |

这些哈希与当前固定来源记录相符；本审查不将电子转录校验等同于印本校勘或个人预测效力验证。
