# 八字追问与本地证据连续性的独立审阅

2026-09-19。独立审阅了本次 `ReadingDocument`、`BaziFrameworkReading`、`ReadingContext`、`ArchiveCodec`、App `ChatSession` 和 `NativeReadingEvaluation` 的未提交变更。审阅者只新增专属测试与本报告；生产修复由根代理完成，未运行 Xcode 或占用模拟器。

## 发现、修复与复验

| 问题 | 初始可复现行为 | 当前复验 |
|---|---|---|
| 现实问题被旧八字话题截获 | “我和父母的关系怎么改善？”得到 relations；“我有两个工作机会，该选哪个？”得到 overview | 两者回到普通问答路径；候选人比较、团队强弱项的同类漏网例也已修复 |
| 忽略明确放下命理 | “不要谈命理，简单说我该怎么休息”仍得到 overview | 三个明确拒绝/转题例不继承八字文档 |
| 简化请求变换了主题 | 在调候、五行关系、扶抑、格局单项后说“简单说/一句话概括”，都变成只讲扶抑与格局的 overview | 单项保持原 focus；比较解释才使用 overview |
| 单项取数失败误用比较回复 | 调候等单项 catalog 缺失时，旧回退仍说“不能结合命盘比较” | App、原生 evaluator 均传 focus；四种单项回退不再误称比较，有无出生资料分别处理 |
| 本地计划器的重试 ID | 一个非 error 但字段残缺的已持久化 get_domain receipt，会让固定 user ID 派生的 call ID 被视为已执行，重试不再取数 | App 每次 send/retry 生成新的 attempt ID、同一轮固定；完整匹配缓存仍复用 |

最后一项必须准确区分：**真正的工具 throw/error 不会被 ToolOrchestrator 持久化为 receipt**，所以不能把普通工具报错说成该 ID 问题的触发。审阅初期对此作过错误推断，继续读代码后立即更正；永久测试分别覆盖 error 和非 error 残缺结果。

## 独立验证

新增 [ReadingContinuityBoundaryTests.swift](../../../native/Core/Tests/SujiCoreTests/ReadingContinuityBoundaryTests.swift)，共 **8 项，全部通过**：

- 五个现实转题例与三个明确拒绝例不被固定八字说明截获。
- 四种单项的两种简化请求保留主题，比较请求仍可简化。
- 新用户提问的模型历史可保留旧对话文字，但不夹带旧 tool calls/receipts 当作本次证据。
- 四种单项计算不可用时保留正确的出生资料恢复状态。
- 本地 plan 经真实 ToolOrchestrator 正常执行一次、随后停止；完整匹配缓存不再执行。
- 无出生资料不执行；throw 只尝试一次、不持久化，下一个 attempt 可成功取数。
- 非 error 残缺结果确实会持久化，新的 attempt 可再次取数；**新旧不一致结果合并后仍不能编译为可信 catalog**。

命令：

```sh
swift test --package-path native/Core \
  --scratch-path /tmp/suji-continuity-independent-review \
  --filter ReadingContinuityBoundaryTests
```

初始运行：4 项中 3 项失败、14 条失败断言。第一次修复后原测试通过；补充候选人/团队强弱项例后又实测 2 条失败；再次修复及加入本地计划边界后最终 8 项全部通过。日志分别保存在：

- `/tmp/suji-continuity-independent-review.log`
- `/tmp/suji-continuity-independent-after.log`
- `/tmp/suji-continuity-independent-expanded.log`
- `/tmp/suji-continuity-independent-final.log`
- `/tmp/suji-continuity-independent-brief-final.log`（补齐“可以简单说说吗”等整句表达后的独立 8 项复跑，全部通过）

最终日志 SHA256：`82ac809966dd70713a776abbbdad44c34209fcb6d437433bbf7db693b6df3617`。`git diff --check` 无问题。

## 证据绑定与持久化结论的范围

在所读路径中，没有发现新的证据提升漏洞：连续性要求相邻 user/assistant、匹配 sourceUserID、原始 context、相同出生资料与引擎版本、可重新编译的 receipts，以及逐段正文/qualification/evidence 完整相等。旧助手文字本身不能建立这一身份。外部导入清除 readingDocument、toolContext 和 receipt context；本地保存保留它们。App 中选择模型失败仍用本地确定正文，且送达前再次检查资料作用域与取消状态。

这不是无限自然语言路由正确性的证明，也不是所有命理解释都已被结构化保护。`nil` 只代表交回普通模型路径，不能推导“现实转题绝不会再调用任何工具”。本审阅没有执行部署认证、App 网络重试 UI 或实际设备恢复测试；不把 Core 的可复现结果扩大成这些路径的端到端通过。

已保存的残缺与新完整结果冲突时，目前有真实重试，但仍拒绝最终解释。这保留了“不静默择取冲突数据”的边界；不要把“重试确实取数”写成“所有残缺历史均能自动恢复”。

## 本次复验的源码指纹

| 文件 | SHA256 |
|---|---|
| ReadingDocument.swift | `2c03ad30c9c2a11c44c789f32cf9a4471c34ca82b9059d82fb95ba3cefcb0029` |
| BaziFrameworkReading.swift | `87b63b462702529b463ccc1a15a87b2af8cf034649d6209d13b44b6bb6bf55a5` |
| ReadingContext.swift | `eccbac9cc1018070da8dbb8b17e89c7738da978415fc1e2360df7f713b0ad85f` |
| ArchiveCodec.swift | `4c9ef706d9b3b189d5372925dc5d43e90d3c51000722595a94831ec45dca58fe` |
| App/Services/ChatSession.swift | `2605f008c67332260e50548e7325fb8d9874ba84b0b71231e3e7b38a516aaa16` |
| Tools/ReadingEvalFixtures/NativeReadingEvaluation.swift | `69ca36ab71912c1465c9f8677310d9e9b96ae4db9df61e08ad586f8608332582` |
| ReadingContinuityBoundaryTests.swift | `77c8b093e80caee1b76c55d2b334101eb8739ecb68c53b15503967133ae6ed4c` |
