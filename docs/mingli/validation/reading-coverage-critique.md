# 八字自然提问的解释覆盖独立审阅

2026-09-20。基线为 `7de86a8` 的 Swift Core/App 路径，以及原有 `native-round9-results.json`。审阅者只修改本报告和 `ReadingCoverageCritiqueTests.swift`，生产代码由根代理修复。此审阅关注“用户问的内容实际有没有解释”，不重复上一轮协议绕过目录。

## 结论与验收优先级

**进入本地受保护路径不等于回答了问题。** 基线的安全限定较稳定，但固定单主题条目会漏掉混合请求、重复简化前正文，并把“怎么算出来”回答成“这是启发式”。普通问题落回自由正文路径时，仍经过原有 `ReadingVerifier`；没有在此独立审阅中调用模型，不能将路由为 nil 直接记为错误答案，也不能记为已完成解释。

| 优先级 | 可复现触发 | 基线实际结果 | 可验证验收 |
|---|---|---|---|
| P1 | 调候后“能不能简单一点” | round9 两轮正文逐字相同，均185字；四个单主题的本地复测也重复 | 保持原主题，brief 正文确实缩短；条件/候选状态保留；不是更换成扶抑/格局概览 |
| P1 | “分别讲扶抑和调候” | 裸 `别` 拒绝正则命中“分别”，导致全部回 free | “分别”不算拒绝；显式正向主题都保留 |
| P1 | “格局怎么看？也说一下调候”“扶抑、格局、调候分别怎么看” | 单值 Focus 优先链只留下 pattern / strength | 单次回复覆盖所有被请求主题；一个主题的排除只排除该主题 |
| P1 | “为什么我身强，具体是哪几项累加” | strength 只给偏强、土和通用限制，无数字 | 绑定当前 receipt 的贡献项、双方总数、判定阈值；无 trace 时说明缺少计算明细，不现场冒造 |
| P2 | “我的五行里，木克土是什么意思” | 只列以壬水为参照的四条方向，无木克土 | 针对木→土说明关系，和水相对的泄耗区别；不因此判个人用神 |
| P2 | “月令申藏哪三个干？本气为什么不是月干甲” | pattern 只说申本气庚透年，省略壬、戊及月干/本气区别 | 列本次月支的完整藏干及所问区别，不能仅靠免责声明算作答完 |
| P2 | “乙庚合了，庚是不是不能当格局用神” | pattern 的通用候选解释没有本次年/时隔位关系 | 引本次相合位置和 unresolved；不把合视为合去/成化 |

P1 是本轮优先修复范围。P2 中明确元素对由根代理一并处理；月令藏干、根气、偏印制食、半合等更深解释需要按实际证据消费情况逐项记账，不能用“现在有结构化回复”覆盖所有未答部分。

## 22 个普通问题的基线路由与内容覆盖

`P` 表示本地 claim 编译/选择/渲染；`F` 表示普通模型规划、SSE 正文、ReadingVerifier 路径。`F` 的正文没有在本审阅中生成。括号是上一条本地解释的 focus；“无”表示直接提问，不借历史文档建立意图。

| ID | 问题 | 前文 | 基线路由 | 内容审阅 |
|---|---|---|---|---|
| S01 | 为什么我身强，具体是哪几项累加？ | 无 | P strength | 返回偏强/土，无贡献项、数字或阈值 |
| S02 | 我的同类和异类分别是多少，按什么权重？ | 无 | F | 同义的计数问题未被识别；自由答复未知 |
| S03 | 日主自己这一分算不算？不算还强吗？ | strength | F | 没有接住对计数口径的自然追问 |
| S04 | 月令申对我的旺衰具体起什么作用？ | 无 | P strength | 泛称未纳入完整月令，未区分月藏干已计数与季节系数未应用 |
| S05 | 我的通根在哪几柱，壬水和癸水要分开吗？ | 无 | F | 根气事实问题仍需模型路径，未测正文 |
| S06 | 月令申藏哪三个干？本气为什么不是月干甲？ | pattern | P pattern | 只有庚本气透年，遗漏壬/戊与概念区别 |
| S07 | 结合我的八字，分别讲扶抑和调候。 | 无 | F | “分别”的别被当成拒绝 |
| S08 | 我的八字格局怎么看？也说一下调候。 | 无 | P pattern | 调候被丢弃 |
| S09 | 只讲我的扶抑和调候，不要讲格局。 | 无 | F | 格局的否定使其余正向请求一起退出 |
| S10 | 庚透年干，那月干甲食神受克会不会破格？ | pattern | F | 包含真实当盘关系，未被本地解释覆盖 |
| S11 | 乙庚合了，庚是不是不能当格局用神？ | pattern | P pattern | 泛述隔位规则，没有明确本盘乙时干/庚年干与结果未定 |
| S12 | 申子是不是已经合水，所以日主更强？ | strength | F | 未消费半合候选、缺辰、结果未成立的当盘字段 |
| S13 | 能不能简单一点 | climate | P climate | 与完整回答完全相同 |
| S14 | 调候那段能不能只用两句白话？ | climate | P climate | 没有两句白话变体，原长段重复 |
| S15 | 我的五行里，木克土是什么意思？ | 无 | P relations | 回答水的关系，没有木克土 |
| S16 | 为什么我偏强？ | 无 | F | 相同意图只在有本地前文时识别 |
| S17 | 我的八字格局和身强身弱有什么关系？ | 无 | P strength | 丢失格局及二者关系 |
| S18 | 我的扶抑、格局、调候分别怎么看？ | 无 | P strength | 丢失格局、调候 |
| S19 | 那你说的参考，具体怎么计算出来的？ | strength | F | 没有接住对上一项计算依据的追问 |
| S20 | 水生木为什么叫泄？ | relations | P relations | 至少回答所问方向，并保留定义不等于用神的边界 |
| S21 | 我最近睡不好，先聊聊作息。 | strength | F | 现实话题没有被固定命理解说占据；实际普通答复未测 |
| S22 | 那是不是偏印格已成？ | pattern | P pattern | 保留候选状态，并给本气透干线索，未升级为已成格 |

这些问题不是穷举路由证明。尤其 S06/S11：命中相关 topic、带上限定语，仍不足以完成该具体问题。

## “为什么身强”必须能解释这个 4 比 4

round9 的合成出生资料排出庚午、甲申、壬子、乙巳，壬水日主。本审阅直接读取该报告 receipt 的天干五行、藏干和权重，独立加总，没有读取模型的解释作为依据。

| 元素 | 贡献项 | 合计 |
|---|---|---|
| 水 | 日干壬1、申藏壬0.2、子藏癸1 | 2.2 |
| 金 | 年干庚1、申藏庚0.6、巳藏庚0.2 | 1.8 |
| 木 | 月干甲1、时干乙1 | 2 |
| 火 | 午藏丁0.7、巳藏丙0.6 | 1.3 |
| 土 | 午藏己0.3、申藏戊0.2、巳藏戊0.2 | 0.7 |

同类/印生合计 `2.2 + 1.8 = 4`，食伤/财/官杀合计 `2 + 1.3 + 0.7 = 4`。当前计数规则采用 `supportTotal >= drainTotal`，所以**恰好相等也进入偏强分支**。不能说生扶分数“大于”另一边，也不能把申月得令包装成此计数结论的计算原因。

此规则把日主本人的日干计1分。若只做“去掉本人这一分”的算术对照，则是3比4；这说明口径敏感性，不表示应用已经采用新规则，更不验证传统旺衰。月支藏干已包含在普通贡献项中，另加季节权重则未应用，这两件事要分别表达。根气/得令的另一套结构分档如同时展示，必须与这个四柱计数结论分开，不能互相充当独立验证。

旧 round9 的 `strengthReference` 只有结论和状态，缺 numeric trace。独立测试能从字段验证上述算术，并不授权 renderer 在无 trace 的旧 receipt 上新造绑定路径。新增引擎 runtime trace 到位后，应由当前 receipt 供给并验证它与汇总一致。

## 验证记录

新增 `native/Core/Tests/SujiCoreTests/ReadingCoverageCritiqueTests.swift`。首次新 scratch 编译因磁盘满失败，日志 `/tmp/suji-reading-coverage-before.log`，不能记为逻辑失败。磁盘恢复后，使用已有 scratch 跑基线：

```sh
swift test --package-path native/Core \
  --scratch-path /tmp/suji-continuity-independent-review \
  --filter ReadingCoverageCritiqueTests
```

2026-09-20 10:39（本机时区）基线结果：**7项测试，4项测试失败，7条失败断言**。成功编译日志 `/tmp/suji-reading-coverage-baseline.log`；22项机器可读观察 `/tmp/suji-reading-coverage-baseline-observations.json`。混合主题测试首个 unwrap 失败提前退出该方法，另外两个混合问题的实际路由由22项矩阵单独记录，不伪称三项断言均已执行。

基线源指纹：

| 文件 | SHA256 |
|---|---|
| ReadingDocument.swift | `2c03ad30c9c2a11c44c789f32cf9a4471c34ca82b9059d82fb95ba3cefcb0029` |
| BaziFrameworkReading.swift | `87b63b462702529b463ccc1a15a87b2af8cf034649d6209d13b44b6bb6bf55a5` |
| native-round9-results.json | `4e2ab8be6ca31e6633a0838b550456c893affe94729d2124e02d0fdae0a26c86` |

### 修复后复验

独立测试已迁移到 `resolveRequest → Presentation(focuses, detail) → compose`，保留旧 round9 报告作历史对照。另有混合文档 JSON 保存/恢复后再次请求 brief 的测试，不只验证一次性的路由。最终22项矩阵与实际答复改用**当前打包引擎经 JavaScriptCore 的真实 get_domain receipt**，不靠手造 trace，也不再用旧报告的缺 trace 字段冒充新引擎输出。

第一轮新接口复验（仍用旧 receipt 做多数文案测试）加此前 continuity 测试，17/17通过。将实用性测试全部切到新 runtime 后，发现 strength 从133字降到111字，只缩短约16.5%，未达到本测试对这个代表性例设的20%可见缩短准则。这与基线的“逐字重复”不同，不把它误记成没有任何简化。该轮日志 `/tmp/suji-reading-coverage-runtime-first.log`。

根代理随后压缩 strength brief，保留4比4、≥、日干本人一次和工程参考边界。**最终2026-09-20 10:48独立复验：9项coverage测试与8项既有continuity测试全部通过，17/17。** 测试报告含22个自然提问场景，不能把17项测试数和22场景数相加冒充独立问题数。

```sh
swift test --package-path native/Core \
  --scratch-path /tmp/suji-continuity-independent-review \
  --filter 'ReadingCoverageCritiqueTests|ReadingContinuityBoundaryTests'
```

| 单主题 | 标准正文字符数 | brief字符数 |
|---|---:|---:|
| 扶抑 | 133 | 81 |
| 格局 | 199 | 112 |
| 调候 | 185 | 130 |
| 五行关系 | 149 | 100 |

长度按 Swift `String.count`，包含相同的四柱介绍段。四项均缩短超过20%；这一量化检查不代表白话可读性已完整验收。mixed文档经过本地 JSON 保存恢复再简化，仍保留strength+climate，没有混入pattern。

最终日志 `/tmp/suji-reading-coverage-runtime-final.log`，SHA256 `8a22ccb504415f883e793e21b4bcfa1457d69d1c59f67d3321edd4bab1bb527b`。机器观察 `/tmp/suji-reading-coverage-observations.json`，数值解释 `/tmp/suji-reading-coverage-runtime-strength.json`。`git diff --check` 通过。

当前 matrix 的路由变化：

| 场景 | 新路由/事实消费 | 结论范围 |
|---|---|---|
| S01、S02、S16、S19 | strength；正文明确帮扶4、克泄耗4、相等按≥偏强 | 已有可核对的直接计算摘要，保留工程启发式资格 |
| S03 | strength；正文标日干本人计入，trace 行标本人1、其余帮扶3 | 提供了追问所需算术事实；未自动改用排除日干的新规则 |
| S04 | strength；展开trace可见月藏干普通计入、月令不另加权、结构规则另列 | 不能由此写成“申月得令导致这个计数偏强” |
| S05 | strength；trace列申藏壬/子藏癸与申巳藏庚，分开同五行与印 | 事实可查看；尚未针对“壬癸是否同根”的传统术语作完整讲解 |
| S07、S08、S09、S17、S18 | 各自两个/三个正向主题都有；S09没有pattern | 多主题与单项排除完成；“分别”不再当拒绝 |
| S06、S10、S12 | F | 月支完整藏干、本盘偏印制食是否破格、申子半合未接入受保护针对性解释；不评价未生成的自由正文 |
| S11 | pattern | 仍是泛候选文案，没有消费本盘乙时干/庚年干的非相邻 assessment |
| S13、S14 | climate brief | 已不重复标准正文，185→130字；仍有辰戌戊、戊癸合等术语且主体三句，因此严格“两句白话”仍是部分完成 |
| S15、S20 | relations | 新文案列完整生克方向，包含木克土；仍以完整关系表追加方式回答，尚非只围绕所问边定制 |
| S21 | F | 正确留给现实作息对话；本审阅未生成普通模型回答 |
| S22 | pattern | 候选限定仍在，没有升格为已成格 |

真实 runtime 审阅产物 `/tmp/suji-reading-coverage-runtime-strength.json` 的直接正文：

> 当前工程启发式的固定权重计数：帮扶 4，克泄耗 4。两侧相等，按当前“≥”规则列为偏强。参考用神为土。这些数字是工程权重，不是实测力量。计数包含日干本人一次，未综合月令旺衰、根气、合化与调候，不能替代完整传统强弱辨析。

其 `BaziStrengthTrace` 还包含四柱逐项权重、比劫/印/食伤/财/官杀五组、日干本人、月令未额外加权、结构规则另列等可读行。每个 claim 证据 pointer 都独立核对为当前 receipt 内的实际值。SwiftUI 源码把这些行放在“查看强弱判断依据”展开项中；本审阅只证明 Core 行内容及绑定，不把源码阅读当成设备显示通过。

本次最终验证源指纹：

| 文件 | SHA256 |
|---|---|
| ReadingDocument.swift | `21cc2e6623fc4dd4899ef8d4a1d66414668878ef3d5f51aefbd75cc530360075` |
| BaziFrameworkReading.swift | `34486c03248acae2d176ce01a9ad3eb3eee6afeb844904be48f56c21f3b002ef` |
| BaziStrengthTrace.swift | `39f6a53de465039ed7cd7c5feb071d93e1c8f61cb4d28a0eff53e2b3b232d336` |
| ReadingCoverageCritiqueTests.swift | `2106c0b45b78aef0c0406e8d5399ef7ab08ed3c1eb18660a50a0a29575e9f76d` |
| native/Resources/mingli.js | `e0db8fcb48abc2ab67aafbf7ec268cd6a3577529928ccea55f49f4bd5e1a7792` |

当前打包引擎revision：`6ac5ff6a948b2b2d20459b81d5fbfb0cba8f1807986032be3bf86ccac2ca6b09`。已再次实际执行 `native/Resources/mingli.js` 的 `SujiNative.dispatch({command: 'metadata'})` 核对，和真实 `native-round10-results.json` 一致；bundle SHA256仍为上表的 `e0db8fcb…`。

历史记录：本报告先前将中间产物revision `cc0a70c26f362b120633054db742a8a0d8a37832dc1fc931abc8a4ee76f97c6f` 留在此处；类型注释也参与引擎源码摘要，重建后应使用上述 `6ac5ff6a…`。此处仅更正版本记录，保留此前测试日志和结果，不重新解释或覆盖旧报告。以上通过结论只对应所记录的源和产物，不对之后改动自动延伸。

## 范围限制

此审阅没有运行 Xcode、模拟器、实际账号认证或新的 live 模型请求。round9 是此前真实模型选择加本地正文的原生测试报告，不是部署后 SwiftUI 端到端证明。新路由的 nil 仍只描述交给普通模型路径，未对其回答内容评分；`ReadingVerifier` 存在不等于自由正文语义完备或全部正确。
