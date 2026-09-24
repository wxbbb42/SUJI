# 原生底栏与本地报告增量：独立技术审查

2026-09-24。基线 `8e04c22`，审查 `codex/native-tabs-readable-report` 的未提交修改及新增 `BaziReadableModules.swift`，对照 `docs/product/2026-09-23-system-report-replan/proposal-final.md`。本次只读源码、现有测试与当前六份合成样稿；未运行构建、测试、模拟器或 AI。以下复现来自确定的代码路径，尚需实施者串行运行负例确认。此稿记录首次审查，修复后的结论另行追加。

## 已检查的有效边界

- 新投影只构造字段别名，没有伪造 `ToolReceipt`、call ID 或模型执行记录；证据仍取自原始 `/mingPan`。外层 owner、完整出生资料、bundle/payload revision 核对仍在。
- 局部救应状态复用 `BaziAdjudicationTrace` 和 `BaziRescueDependencies`，后者重建作用及依赖关系，不能只改一条 `available` 就通过。格局未通过时，B5 不继续引用该格局用神。
- 原逐柱/日主条目的七个路径仍保留，满足 `BaziLifeThemeCompiler.compile` 的旧输入合同。旧专题移入次级折叠组，并保留明确返回入口；不是新模块 AI 路由。
- `TabView` 已恢复系统 tab bar，自绘 `NotebookTabBar` 和手动键盘切换移除。tab selection、ChatView 状态，以及只随 `scopeRevision` 重建底栏的边界保留；出生代际变化未新增重建 ChatView 的路径。
- 新普通报告未把当日/流年输出混入本命说明，未改写原问道失败记录。

## 需要修复

### P2 / Important：缺少可选结构字段会连带清空八字与紫微报告

- 位置：`native/Core/Sources/SujiCore/BaziReadableModules.swift:162`、`:186`；传播位置 `native/Core/Sources/SujiCore/NatalReadingReport.swift:46`、`:60`。相关既有解析器 `BaziStrengthTrace.swift:117`。
- 复现：取当前任一合法 `natal` 合成载荷，只删除 `/mingPan/riZhuStructure`，保留 `wuXingStrength` 和基础四柱，调用现有 `compile` helper。
- 原因：`BaziStrengthTrace.make` 在 structure 不存在或没有 `/evidence` 时跳过该可选分支，仍返回已校验的固定计数。新 `methodsEntry` 因此通过 guard；随后却无条件执行 `evidence.at(..., "/mingPan/riZhuStructure", ...)`。缺路径直接 throw，上层 `natal` 把整个编译改为 `invalid`，导致合法的 B1–B4 和紫微也不能阅读。
- 建议：将固定计数和结构矩阵作为各自可校验、各自可追溯的输入；只绑定实际通过检查且存在的证据。结构缺失/非法时，保留计数说明并明确该口径缺失，或仅降级 B5，不能让可选字段的证据读取异常逃出模块。
- 必须验证：删除 `riZhuStructure`、删除其 `evidence`、替换为非法类型；明确各输入应得到什么 B5 状态，并断言 B1/B2/B3 与紫微仍和基线一致。

### P2 / Important：格局 gate 未核对取格方式和月令专属名称

- 位置：`native/Core/Sources/SujiCore/BaziReadableModules.swift:103`–`:116`。所复用的 `BaziPatternConditionTrace.make`、`BaziAdjudicationTrace.make`、`BaziRescueDependencies.make` 均没有验证顶层 `selectionBasis`。
- 复现 A：取合成样稿 2（1984-09-20 17:30，男，经度 120）的合法载荷，只将 `/mingPan/geJuV2/selectionBasis` 改为 `future-selector` 或删除。当前路径仍能输出“偏财格候选：有一条局部配合可用”，并让 B5 继续比较格局用神金；未知/缺失取格依据未令模块降级。
- 复现 B：对一个有效的比肩或劫财候选，只将 `name` 换成同一 `namesByRelation` 数组里的另一名称。gate 只认十神类别，因此 `比肩结构（格局待辨）` 可替换为 `建禄格`，或 `劫财透干（格局待辨）` 可替换为 `月刃格`，而不会核对禄/刃对应月支；既有 TypeScript `stemAccuracy.test.ts:78` 起有这些名称不能互换的反例。
- 影响：两份条件校验器验证的是局部关系，不能为顶层候选取格算法盖章。当前源码注释和失败文案宣称“取用、来源与条件链同时一致”，但一项取格依据缺失仍可进入主摘要及跨口径比较。
- 建议：建立小型可复核取用适配器，检查支持的 `selectionBasis`、月藏序位/实透条件及适用的优先链；三合/三会按其代表干合同核对；禄/刃名称按日干和月支核对。至少先拒绝未知或缺失 basis，不得把 parser 返回非 nil 等同于完整候选已验证。失败应限定于 B4，B5 使用现有未通过分支。
- 必须验证：未知/缺失 basis；合法 basis 与当前盘不符；比肩/劫财名称互换。断言主摘要撤回旧候选及 B5 比较，而基本模块保留。

### P3 / Minor：无选中局部路径时，完整格局解释重复或以空提示结束

- 位置：`native/Core/Sources/SujiCore/BaziReadableModules.swift:149`–`:155`。
- 复现：当前 `synthetic-samples.md` 的样稿 5 已把 `adjudicated.text` 完整输出两次；样稿 4 结尾为“完整条件与其他未决关系：”却没有后文。
- 原因：没有 `localDescriptions` 时 `localText` 已包含 `adjudicated.text`，`explanation` 又无条件追加相同内容；空字符串也照常输出前缀。
- 建议：按是否有独立局部说明决定是否追加完整核对段；空文本不渲染标题。该处直接影响“易读”目标，修复无需增加 AI 或复杂测试。

## 本次不据此判定的行为

- 完整四体系个体综合报告、专旺/调候新内容与新模块问道衔接：本次父任务明确按本地报告和外壳增量审查，不能把这些未实现项算作已完成，也不以扩大范围代替当前修复。
- 既有原问道矩阵和专题 T01/T05 失败：本次没有改 AI 路由/模型策略，不要求新的 live AI 矩阵，也不将旧失败重分类为通过。
- 最大字号专项：用户当前已明确延后，不作为本次合并门槛。
- iOS 26 Liquid Glass 实际渲染、键盘与输入框真实布局、旧专题折叠返回的滚动时机：源码路径已看，但必须由实施者的模拟器证据确认；此只读审查没有运行 UI。
- 报告页关闭后重新打开是否持久保存上次体系：现有 `@State` 生命周期已如此，并非本次改动引入；没有据此阻断该增量。

## 结论

**首次审查：With fixes。** 两项 P2 修复并通过针对性的本地负例后，才可把失败隔离和格局闸门视为通过。原生 tab 的代码方向符合要求，但实际 Liquid Glass、草稿保持和专题返回仍以本轮 UI 验证结果为准。本结论不表示完整个人报告或旧问道质量已通过。

## 修复后复核

同日收到实施者通知后，重新读取最终 `BaziReadableModules.swift`、新增测试、`NatalReadingReportView.swift` 和 `SujiApp.swift` 全部差异，并以 `structural.ts` 的真实取用表/顺序对照；仍未另跑构建或测试。`git diff --check` 无输出。

- **P2 可选字段使整册失败：源码修复。** `methodsEntry` 现在在 `riZhuStructure` 缺失/null 时直接返回 B5 降级条目，不再执行该缺失路径的证据收集。新增 `testAbsentOptionalStrengthStructureDoesNotEraseOtherReports` 断言两个体系仍在、紫微全文不变，以及 B1–B4 不变。
- **P2 取格/名称闸门：源码修复。** 新 `selectionReason` 从已验证的四柱重建月支本/中/余气实透顺序，保留专气支政策；核对 `selectionBasis` 与所选干，按实际日干/月支计算比肩及劫财的专属名称。未透时先排除月支参与的齐全三合/三会，再允许本气回退。三合/三会代理与特殊格暂明确降级，不偷偷当作实透。新增测试覆盖未知、缺失、盘面不符 basis、中气壬的实际时干解释、建禄/月刃名称替换。
- **P3 重复/空提示：源码修复。** 详情改为核对后的选取原因及独立局部说明，不再无条件重复 `adjudicated.text` 或输出空的“完整条件”前缀。
- **最终 UI 差异：未发现新增技术阻断。** 系统 tab bar 由 `TabView` 持有，账号/出生代际和草稿的原边界未被改写；五个模块进入主阅读区、旧条目/早期专题进入折叠区，`focusTheme` 返回时显式展开专题。真实系统材质、输入框安全区与滚动定位仍需实施者本轮 UI 结果确认。

**最终源码审查结论：已关闭本次 2 个 P2 和 1 个 P3，没有新增源码阻断项。** 实施者通知相关测试正在运行；本审查未读取最终测试结果，因此不声称运行验证已通过。合并判断须结合主任务的最终测试/UI 证据，且交付范围仍为本地八字导读增量。

## 后续真实 UI 卡死与布局修复复核

本轮实际 UI 验证新增发现：连续展开 B4 与 B5 时，应用主线程卡住，实施者观测 CPU 约 99%，不得把此前“源码未发现阻断”表述成运行验证通过。此运行缺陷按 **P1** 记录，须以相同操作序列恢复响应的复测结果关闭。

本审查读取了 `native/artifacts/native-report-2026-09-24/report-layout-loop.sample.txt` 并查看同目录 `report-layout-loop.png`。采样中主线程落在 `AG::Subgraph::update`、`LazySubviewPlacements.updateValue`、`placeSubviews`、`makeIDPlacementContextIfNeeded` 与 view-ID translation 路径；截图停留在已展开 B4、准备展开 B5 的阅读区。它们支持调查本地布局/滚动目标重算，不构成新的模型或网络问题；单份采样不单独证明 SwiftUI 内部循环的全部原因。

### 对当前修复的评估

- `NatalReadingReportView.swift:89` 将外层 `LazyVStack` 改为 `VStack` 是范围合适的修复。此页条目有明确上限：八字为 5 个主模块和最多 21 个旧条目，紫微 14 条，出生星宿 3 条，七政四余 12 条；它不是无限列表。解释、来源及原始字段的显式展开状态仍保留，首次打开不会因此直接渲染所有专业字段。
- 该变化去掉外层滚动内容高度的懒估算，保留既有 `.id`、`.scrollTargetLayout()`、`.scrollPosition` 及 `ScrollViewReader`。源码未见新增状态反馈循环，没有删掉定位功能来规避卡死，也没有改变编译证据、账号或出生资料的身份边界。
- 一次性测量的成本会高于懒布局，尤其把旧条目与多级证据全部展开时。但当前有界文本规模不足以据此要求分页、后台布局或新的全量性能工程；若普通字号实际复测仍卡顿，再以具体采样继续处理。
- 测试辅助按系统 `tabBars.firstMatch.buttons[title]` 定位原生控件，符合这次原生 tab 迁移。模块点击先滚动至导航栏下方可点击位置，没有移除正文展开、原始字段隐藏或草稿保持断言，也没有注入替代产品路径。

### 本次需要保留的复验边界

1. 同一合成报告上连续展开 B4/B5，等待真实“已展开”状态与截图完成，再收起 B5 或继续滚动，确认主线程仍响应。
2. 使用已有的专业页返回和旧专题返回用例确认现存 ID 目标仍可到达；切换体系后不出现空白/错误体系。无需另开 live AI 矩阵。
3. 实施者保留失败采样与成功复测的分开记录；不能把中断卡死的那次测试归入通过。

**本次追加审查结论：同意当前有界页面的 `VStack` 修复，未发现需要另改生产源码的新阻断项；P1 的运行关闭仍以主任务正在执行的定向 UI 复测为准。** 本审查未启动模拟器、构建或测试。

## 同题复测通过与旧专题展开层复核

已只读核对 `native/artifacts/native-report-2026-09-24/report-layout-fixed.log`：`testModuleReadingShowsConditionsBeforeProfessionalFields` 在 33.185 秒内通过，1 test / 0 failures；日志包含 B4、B5 点击后的 idle 等待、真实展开状态查询及两张截图附件。**前述 P1 在这条明确复现操作上已关闭**，不外推为全部交互通过。

随后读取 `report-layout-regression.log` 并查看 `report-legacy-current.png`：专题正文确实可见，测试报告 `theme.boundary` 位于屏内却 `isHittable == false`，旧交接用例失败。这份失败应保留为新的 UI/AX 命中异常，不能改成通过；仅凭静态文字的 XCTest 命中结果，尚不能独立确定实际手点按钮或 VoiceOver 的全部影响。

当前 `NatalReadingReportView.swift:124` 起把专题外层 `DisclosureGroup` 改为显式 `Button` 和 `if legacyThemeExpanded`，此次小差异风险可接受：

- 展开按钮仍有 44pt 最小高度、覆盖整行的命中形状、原 `report.legacyTheme` 标识及“已展开/已收起”辅助值；`report.theme` 锚点与 `focusTheme` 的主动展开逻辑未变。
- 原 `BaziLifeThemeCard` 原样挂载，条件收起没有改动主题绑定或问道发送边界。生产环境的细读/来源/例子展开状态来自外层 `NotebookThemeNavigation`，不会因卡片暂时卸载而清空；草稿仍由 `ChatView` 持有。卡片本地临时错误/焦点的重置不影响持久资料或已发送回答。
- 没有删除命中断言、用坐标强点绕过不可达控件，或以测试专用内容替代产品。应以原有真实 `theme.continue` 点击、草稿保持和返回流程的重跑结果关闭这次 AX 异常。
- 非阻断小建议：装饰 chevron 可加 `.accessibilityHidden(true)`，避免与按钮文字及展开值重复朗读。

**小差异源码结论：无新增阻断，可继续当前定向复测。** 旧专题这次运行失败尚未在本审查读取到成功复测结果；本段不声明它已修复通过，亦未另启构建或测试。

## 最终定向运行证据复核

只读核对 `native/artifacts/native-report-2026-09-24/report-interaction-final.log` 的三个测试起止、交互步骤及最终汇总。对应结果包为 `report-interaction-final.xcresult`；本次读取日志，没有另启测试或构建。日志在 2026-09-24 19:15:34 汇总 **3 tests / 0 failures，197.247 秒，TEST SUCCEEDED**。

| 完成的定向用例 | 用时 | 本次可确认的范围 |
|---|---:|---|
| `testDarkThemeCanBeReadAndQuestionChosenExplicitly` | 85.606 秒 | 深色专题细读、展开例子与来源、真实进入问道、明确选择问题后返回册页 |
| `testThemeHandoffPreservesDraftAndReturnsToReport` | 65.076 秒 | 专题正文可达、真实交接按钮可点击、保留原有未发送草稿、返回专题及取消上下文 |
| `testModuleReadingShowsConditionsBeforeProfessionalFields` | 46.565 秒 | B4→B5 展开、B5/B4 收起及继续滚动进入专业页，主线程保持响应，普通层不显示原始格局字段 |

重新核对必要源码差异：旧专题按钮的装饰 chevron 已对辅助功能隐藏；展开值、44pt 命中区、条件挂载与原返回锚点保留。模块测试新增“收起两模块后进入专业档案”的断言，没有删掉原有正文/字段边界断言。`git diff --check` 无输出。

**已复现的旧专题 AX 命中异常，在原草稿交接与深色专题操作这两条路径上关闭；B4/B5 布局卡死在展开、收起和后续专业页导航这条路径上关闭。** 失败的 `report-layout-regression.log` 与最初卡死采样仍是失败证据，不改写为通过。

截图由主任务另行查看，位于 `interaction-final-screens`：主任务报告 `theme-04` 捕获文字转场重影，随后 `theme-07` 稳定返回无重影，并已查看草稿保持和 B5 画面。本审查不重复把主任务的视觉核对称为自己已查看，也不使用过渡帧作为稳定版式通过证据；保留该现象，不扩展为新的动画整改范围。

**最终范围结论：本次发现的源码问题与已复现的两类 UI 交互异常均在上述明确范围内关闭，无新增技术阻断。** 该结论只覆盖本地报告/原生外壳增量和这些定向交互，不表示全部产品、全部可访问性、完整个人报告或 live AI/旧问道矩阵通过。
