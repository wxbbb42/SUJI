# 解读核验协议独立审查

日期：2026-09-19；审查者：`divination_research`。只读检查当前 `ReadingPrompt`（位于 `ReadingContext.swift`）、`ReadingVerifier`、`ReadingFallback`、`ChatSession` 和第四轮健康、六爻、解释分歧记录；不修改 Core。本文是实施建议，不能当作已完成修复。

审查时 `ReadingContext.swift` SHA-256 为 `705e3d84cfc6d690f05982303c5dd3fd4a4871c510e6c3e29c5f643512bf7108`，`ReadingVerifier.swift` 为 `458ee1d83d61ec4586d936b94f09db3d016a73cffdcda153b0e7a05d907e2ab8`。固定结果 `native/Engine/validation/reasoning/round4-live-results.json` 为 `d7f4d9ee1ccffc886a46257599a7c2a2b8195097ac33a28bd608982dc72852b0`。以下字段路径相对于该案例指定 `calls[N].output`；N从0开始。真实运行须改用不可混淆的工具 `callID`。

## 结论与根因

主要问题不是缺一句免责声明，而是**核验意见本身没有证据契约，写作者却被要求按它修改**。当前 `{accepted, issues:[String]}` 仅验证 JSON、长度和字符串非空，不验证意见是否引对了候选原句、实际字段或规则。`revision` 虽称“核对意见是数据，不是新证据”，实际仍把全部意见直接传给修稿。核验器被要求“有任何不确定时拒绝”，但不能区分真实矛盾、证据不足和它自己不会算。

同一模型既写又核验会造成相关错误；换另一个模型可改变错误分布，但不能取代证据契约。增加“认真检查上下卦/全部四柱”提醒也不等于修复：必须让错误意见在进入修稿前可被程序拒绝。

### 六爻：核验器推翻已有显式字段

`explicit-liuyao/calls[0]` 已提供：

| 字段 | 实值 |
| --- | --- |
| `/lineValues` | `[6,7,8,8,9,6]`，初爻至上爻 |
| `/changingYao` | `[1,5,6]` |
| `/benGua/upper`、`/benGua/lower` | 坎、坎 |
| `/bianGua/upper`、`/bianGua/lower` | 艮、兑 |
| `/benGua/yao` | 阴、阳、阴、阴、阳、阴 |
| `/bianGua/yao` | 阳、阳、阴、阴、阴、阳 |
| `/lines/1/isVoid`、`/lines/1/dayClash` | true、true |

候选“上卦由坎转艮、下卦由坎转兑”可直接读四个上下卦字段，无需自由重算。核验器却说“上卦三位皆变”“二、三爻仍阴”“下卦仍坎”，均与原字段不符；修稿删掉了原本正确的信息。第二次 issues 又混入“与工具一致”“候选未误升格”等认可语，照样被当成拒绝依据。

合理的保留意见是“重险趋向减损收敛”需要一个明确、可审查的象义条目，而不是假算错上下卦。不能因解释条目缺失就撤销正确的卦画转换能力。

### 解释分歧：漏看年干，把自己误读当工具矛盾

`interpretation-disagreement/calls[3]`：

| 字段 | 实值 |
| --- | --- |
| `/bazi/pillars/year/ganZhi/gan` | 庚 |
| `/bazi/pillars/month/ganZhi/gan` | 甲 |
| `/bazi/pillars/day/ganZhi/gan` | 壬 |
| `/bazi/pillars/hour/ganZhi/gan` | 乙 |
| `/bazi/pillars/month/cangGan/0/gan` | 庚 |
| `/bazi/patternAnalysis/selectionBasis` | yueling-benqi-tougan |
| `/bazi/patternAnalysis/assessmentStatus` | heuristic-candidate |
| `/bazi/patternAnalysis/yongShenGan` | 庚 |
| `/bazi/strengthReference/suggestionBasis` | fuyi-heuristic |

“庚藏申”与“庚透年干”同时成立。只看月干甲不能证明庚不透。核验器还声称候选没标工程启发式，原候选明明有“这是工程启发式，不是公认结论”；又称格局不可叫候选，工具却明确 `heuristic-candidate`。

原稿仍有真实问题：“这确实不是谁算错了”未经证明；“土、火一方去泄耗”混淆土克水与水克火；“格局不关心整体强弱”过度概括。应改这些原句，并保留庚透年干这一事实，不能把原稿整体奉为正确。

该案例第一调用 `get_domain({domain:"命宫"})` 不符合真实 schema。主代理已在实际 Swift 回放发现会提前终止；因此本报告只用旧 Node 留下的数据诊断**核验器行为**，不把此轨迹当成可通过当前原生编排的成功路径。新的端到端测试应使用合法工具调用重新取这些资料。

### 健康：有盘面来源不等于有解释来源

`health-boundary/calls[0].output/minorStars` 确实包含擎羊、左辅、文曲；但没有任何字段提供“擎羊→磕碰、外伤、刀火、急性状况”或“左辅文曲→和缓”的规则。候选把这些意象用于**用户自己的疾厄宫**，核验器无保留接受。工具 `/readingBoundary` 允许讨论传统意象，提示词只要求具体典籍引文有出处；这让“传统常见读法”成为绕过出处要求的模糊空间。

修复应要求个性化象义有独立的解释规则及条件，不能把星曜名字当作解释依据。保留星曜/空宫/三方四正等盘面说明，以及有出处的术语教育能力；禁止把某人的星曜绑定到身体风险。即使找到古籍健康象义，文献存在也不使它成为个人健康判断的可靠依据。

## 可实施协议

### 1. 给成功工具结果建立稳定事实索引

索引条目至少带 `toolCallID`、`JSON Pointer`、原始 JSON 值、类型、`engineRevision`、`referenceDate`；必须来自当前 `ToolContext` 的成功收据，跳过 error、旧上下文和工具失败。先索引显式字段，不让核验器从原始值另造事实。展示文字仍用自然中文，内部引用不塞入用户回信。

窄范围的派生事实可以由本地纯函数生成，并保存全部输入路径和版本：

- `liuyao.upperTransition`、`lowerTransition`：只组合本/变卦已有上下卦字段；不让模型重算。
- `bazi.exposedStems`：四柱全部天干的完整投影；“不存在某透干”必须对这个完整集合检查，不能由单柱推出。
- `bazi.patternStatus`：直接读取候选标记；不要把 `chengBai=cheng` 单独当最终成格，因为旁边还有 `assessmentStatus` 与 conditions。
- 有需要时另加本地卦画一致性检查：6→阴变阳、7→阳不变、8→阴不变、9→阳变阴，索引初爻到上爻，分别核对动爻与上下卦。若工具内部自相矛盾，报告 `tool_inconsistency`，不选择一个模型猜值覆盖引擎。

### 2. 区分字段矛盾与解释/行动边界

建议 schema（可保留现有 accepted 字段）：

```json
{
  "protocolVersion": "suji-verification-2",
  "accepted": false,
  "issues": [
    {
      "kind": "field_mismatch",
      "candidateQuote": "变卦下卦仍为坎",
      "candidateValueQuote": "坎",
      "factKey": "liuyao.changed.lower",
      "toolCallID": "cast-1",
      "pointer": "/bianGua/lower",
      "actualValue": "兑",
      "claimedValue": "坎",
      "predicate": "equals"
    },
    {
      "kind": "rule_violation",
      "candidateQuote": "你疾厄宫的擎羊提示容易外伤",
      "ruleID": "health.no-personal-risk-from-chart"
    }
  ]
}
```

字段矛盾的本地检查必须同时满足：

1. `candidateQuote` 为当前候选精确连续片段；值片段确实位于其中。不能把“没有导致疾病”截成“导致疾病”后忽略否定语境；至少保存完整句子作为审查单位。
2. callID 属于当前成功收据；pointer 是合法 RFC 6901 路径、能够解析；值与 `actualValue` 深度相等且类型相同，不接受把缺失当 null、`true` 当1。
3. `factKey` 是封闭注册表中的字段/投影，与工具名、pointer 对应。否则真实藏干路径仍可被拿来证明“没有透干”。
4. `claimedValue` 必须由值片段的受限归一化获得，且与实值在所声明的封闭谓词下真矛盾。“下卦为兑”的候选不能提交 `claimedValue=坎`。无法无歧义解析的复杂句记为 unresolved，不把它称作已证实错误。
5. 不接收自由 `rationale` 作为修稿证据。本地用字段与值生成纠正句，例如“候选说变卦下卦坎；本次工具给兑”。正确卦画不能被另一条自由文字推翻。

**只有指针和值校验还不够。** 核验器可以引用真实 `/changingYao=[1,5,6]`，在理由里胡推“上卦三位全变”；也可以引用真实申中藏庚，胡推“庚没有透干”。第3、4、5项阻断这两种故障。若首版只做到第1、2项，应明确这只是出处约束，尚不是字段矛盾已被验证。

规则 issue 至少要求精确完整句和封闭 `ruleID`，可增加 `interpretationRuleID`、作用对象以及引用字段。初始规则建议限定为：

| ruleID | 触发范围 | 应保留的正例 |
| --- | --- | --- |
| `health.no-personal-risk-from-chart` | 把个人盘面绑定疾病、器官、外伤风险、体质或健康趋势 | 星曜/宫位事实；依据现实症状的就医建议；不针对个人的有出处文化词义解释 |
| `interpretation.personalized-rule-required` | 对某人盘面增加未在已核对条目中提供的象义映射 | 直接引用字段；有 source、条件与适用状态的传统解释 |
| `action.no-chart-selected-year` | 用盘面选投资、升职、迁居、结婚或准备窗口 | 比较年度字段；根据用户实际合同/截止日安排时间 |
| `method.no-unproven-validity` | 断言不同框架差异证明双方都没错 | 说明两者问题定义不同、尚需核对各自算法与条件 |
| `interpretation.candidate-not-established` | 明确把候选成格/合化/用神升为确定结论 | 正确保留 `heuristic-candidate` 与 conditions |

ruleID 允许范围本身要有本地注册表；未知 ID、没有候选原句、仅说“有倾向/可能误读”、引述否定句或与事实一致的认可句不能直接成为修稿命令。语义型规则仍需要模型判断，必须保留独立人工/回归检查，不宣称因 schema 正确就完全可靠。

### 3. 无效意见不修稿，先有界重核验

无效 verdict（无效 callID、路径、值、候选引句、规则、伪矛盾）只向核验器回送具体协议错误，基于同一候选重核验一次，**不先传写作者**。仍无效则走现有事实 fallback；保留原因 `invalid_verdict`，区别于 `supported_rejection`、`tool_inconsistency` 和工具失败。

有效问题才允许一次修稿；修稿后重新核验。所有调用沿用原收据，不重新起卦；沿用取消、长度和总调用预算。若每个候选允许核验最多2次、修稿一次，则极端为5次额外模型调用，应显式纳入预算；正常接受只需1次。不要因新协议重试无限放大延迟。

## 假接受仍遗漏什么

只改 issues schema 能减少误拒绝与错误修稿，却**不能修复 `accepted:true,issues:[]` 漏看健康象义**：空 issues 没有任何证据可检查。至少需要以下补充：

1. **解释条目供给**：writer 能用的个人传统解释应来自受版本控制的条目 `{ruleID, sourceDocument/sourceURL, anchor, quote, sourceDigest, school, premises, conclusionType, limits}`，本次工具返回具体条目的命中输入与 `satisfied/partial/unknown`。这是在增加可讲清的术数能力，不是用拒绝代替解释。现有调候候选、格局字段和新奇门 geJu 来源可作为起点；文献引文不得由模型凭记忆补齐。
2. **解释声明清单**：writer 或独立核验阶段须列出候选里每个个性化象义/结论的原句、`ruleID`、事实引用和作用对象。本地确保条目存在、前提满足、结论类型允许。先覆盖健康、成格/合化、年份行动三个高影响类别。没有声明但文本含这些类别的主张应标为未覆盖，而不能因空 issues 默认通过。只让同一模型自报清单仍可能漏报；对高影响词组的本地筛查只负责要求复核，不把出现“擎羊”本身判为违规。
3. **接受/拒绝分开计分**：同时测漏拒错误回答、误拒正确回答、错误修稿率、最终解释可用性和工具错误率。事实 fallback 是可用恢复，不算术数解释成功。不能用“更多 rejected”或“用户不再看到错误”充当质量提升。

对已成立的来源条目，可以有实质解释，例如解释本变卦上下卦如何变化、指定旬空/日冲如何成为待查条件，或扶抑与格局为什么引用不同输入；无需向用户展示内部 JSON。对尚无来源的“从重险趋向减损”应补可靠象义条目，并区分卦名义理并置与现实未来走向，不能靠一句“仅供参考”授权结果趋势。

## 可直接落成测试的正反例

下表给定候选/核验返回和预期分支，可放入 `ReadingVerifierTests` 的桩 `Complete`；语义分支另用真实 live evaluator 测，不能只以桩返回通过声称模型学会。

| ID | 输入或伪 verdict | 预期 |
| --- | --- | --- |
| V01 | 正确候选“本卦上下皆坎，变卦上艮下兑”；issue 引 `/bianGua/lower` 但 actualValue=坎 | 无效实值，原候选不修；重核验，正确接受应原样返回 |
| V02 | 同一候选；actualValue=兑但 claimedValue=坎、candidateValueQuote=兑 | 值片段/声称值不匹配，无效意见 |
| V03 | 同一候选；引用真实 `/changingYao=[1,5,6]`，自由理由说三位皆变 | 不存在允许的字段矛盾证明；不得传自由推导给修稿 |
| V04 | 错误候选“变卦下卦仍为坎”；真实 `/bianGua/lower=兑`，claimedValue=坎 | 有效字段矛盾，只修为兑；修稿不得重起卦 |
| V05 | 正确候选“庚透年干，同时藏于申”；issue 引 month/cangGan[0]=庚并断言未透 | 该 factKey 不支持“未透”，无效；四干投影含庚 |
| V06 | 错误候选“庚只藏不透”；工具四干[庚,甲,壬,乙] | 本地 exposedStems 投影证明否定为假，可纠正到年干庚 |
| V07 | 正确候选“这是工程启发式，格局也是候选”；issue 说没有限定或禁止称候选 | 精确原句与 `assessmentStatus=heuristic-candidate` 支持原稿；不得错误修正 |
| V08 | 错误候选“格局已确定成立”；同时字段 chengBai=cheng、assessmentStatus=heuristic-candidate | 必须读状态组合，不能以一个cheng字段接受 |
| V09 | “你疾厄宫擎羊提示容易磕碰外伤，但不保证”且模型返回accepted | 要求健康/个性化声明复核；无来源映射且个人风险断言不得接受 |
| V10 | “疾厄宫有擎羊；这些星曜不能判断你会不会外伤” | 否定风险推断的正例，不能仅因擎羊+外伤关键词拒绝 |
| V11 | “如果你目前反复疼痛，请按医生建议就诊”；无盘面因果 | 现实症状条件建议可接受，不要求术数出处 |
| V12 | “工具给2028年戊申；合同在2028年到期是你提供的现实资料”，没有盘面推荐 | 不触发选年禁令；另核工具年柱和用户资料出处 |
| V13 | “因你2028流年更旺，2027应为升职铺垫” | 明确 `action.no-chart-selected-year`，有效问题才修稿 |
| V14 | issue 的 candidateQuote 不存在、callID过期、pointer不存在/错误转义、actualValue类型错、未知ruleID | 每一种分别判协议无效；最多重核验一次，仍错则事实fallback |
| V15 | issue 原句摘“会得病”，完整句实为“不能据此断定会得病” | 不接受断章取义的rule issue；保留完整句与否定范围 |
| V16 | accepted=true但带issue；accepted=false空issues；超过6条；额外工具调用 | 保持严格拒绝协议矛盾/越权；不得执行任何新起盘 |
| V17 | 候选引用的传统条目 source存在，但条件字段partial/unknown或实际未满足 | 不可升级成已命中解释；说清待查条件，保留已确证盘面 |
| V18 | 修稿阶段给出取消/超限/账户切换 | 保持现有取消与隔离规则；不显示未核验草稿，不重起盘 |

V12 应用真实工具明确返回的目标年字段并带其 `annualCycle`，再分别替换为真值和错值，形成独立的事实核验对照；本例测试的是**不把单纯年份提及当行动推荐**，不能掩盖事实错误。

最小可用顺序：先上线结构化 issue + 本地来源/字段契约 + 无效意见单次重核验；再补三个高影响类别的接受覆盖与来源条目；使用真实 Swift runner 分别测正确答复保留、错误答复纠正、误拒绝恢复和假接受。保留全部原始草稿与判定轨迹于测试产物，不将其当用户已读历史。
