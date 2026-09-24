# A 阶段实施独立技术复核

日期：2026-09-23。对象为本轮实际源码、`proposal-final.md`、`content-contract.md`、本评审者此前的 `review-technical.md`。只读检查 Core 报告编译器、内容库、天文适配、App 报告与专业入口、Profile/导航、AppStore 与相关测试源码；未读取其他本轮独立评审。

**结论：未发现阻止受约束 A 阶段交付的新增 P0/P1；有两项 P2 健壮性问题和一项 P3 错误引导问题。** 该结论只适用于“当前资料的本地基础读盘”，不表示完整生活主题、历史版本、报告与 AI 交接已经完成。编译、Core、Store、UI 测试由主代理执行，本评审没有运行测试、模型或业务请求，不能替代其运行结果。

工作树仍在由主代理修改。复核末次读取已经看到 `NatalReadingInput.BirthKey` 使用严格 `Decodable` 和定长字段匹配；此前 `NSArray` 把 JSON 布尔与数字按数值相等处理的风险不再列为未修复发现。对应新增反例测试是否通过须以实际执行记录为准。

## IMPL-01 · P2：本命内层引擎声明版本缺少预期值比较

**位置：** `native/Core/Sources/SujiCore/NatalReadingReport.swift` 的 `NatalReadingCompiler.natal`、`NatalReadingInput.validate`，特别是当前第 190 行；`NatalDossier.swift:27`。参照天文侧 `NatalAstronomyDossier.swift:25` 和 `AppStore.ensureNatalAstronomyDossier`。

**事实：** 本命入口严格比较外层 owner、完整出生资料和脚本 bundle revision；内层 `/engineRevision` 只验证为 64 位十六进制。它进入了报告快照哈希，因此“被记录”，但没有与当前引擎 `metadata.engineRevision` 比较。天文侧有独立 `enginePayloadRevision` 和真实 metadata 校验，本命侧没有同等闭环。

**可复现反例设计（本评审未执行）：** 取真实引擎的合成 natal JSON，只把 `/engineRevision` 改成另一串合法 64 位 hex。以当前 owner、birth、bundle revision 重新构造 `NatalDossier`，再调用 `NatalReadingCompiler.natal`。其余字段仍合法，当前源码会允许编译，只改变 snapshotID。现有“outer revision 为 different 应抛错”的测试不能覆盖此反例。

**影响与级别：** 这违背“两个 engine 版本语义分别核对”的完整契约，会允许声明了别的算法版本的快照进入报告。当前 App 的侧车来自本机引擎、按 bundle digest 分区，普通档案导入也不携带此侧车；仅改持久化 payload 而不匹配 digest 会被拒绝。因此没有证据将它定性为当前跨账号泄漏或可远程注入的 P0/P1，也不应声称哈希是认证。

**建议：** 从同一桥接实例的 metadata 获取预期 payload revision，与 bundle revision 分开传给本命 dossier/compiler；严格比较内层声明值，并增加“格式合法但版本不一致”的反例。可以复用现有 metadata 缓存，不必让报告调用网络或伪造工具回执。

**A 阻塞：否。** 当前可信本地生成路径可用；若未来允许导入、交换或恢复独立报告快照，应先补上此项及相应信任边界。

## IMPL-02 · P2：故障隔离目前只到两份档案，未到四个阅读体系

**位置：** `NatalReadingReport.swift:35` 的整包 DTO 验证和两份报告构建；`NatalReadingAstronomy.swift:4`；`NatalAstronomyDossier.swift:57` 的整体验证；`NatalReadingReportView.swift:278`、`:296` 的两组结果/失败状态。

**事实：** 天文懒加载与本命已正确分开，天文延迟不会挡住八字/紫微。但八字和紫微在一次 `natal()` 中全部成功或全部失败；月亮参照宿也必须等四余、安命等天文模块全部通过验证，才会返回。`content-contract.md` 所述“拒绝该模块，其他通过的模块仍可用”尚未完全实现。

**可复现反例设计（未执行）：**

- 保留合法八字，仅将紫微某主星的亮度改为未支持值。应拒绝紫微解释；当前 `validate` 抛错，八字也无法显示。
- 保留合法七曜、宿界和时间，将 `/lifeDegree/methodVersion` 改为未来版本。月宿三条内容没有使用 `lifeDegree`，但 `NatalAstronomyPayload.validated` 仍整包抛错，月宿与七政同时失败。现有测试验证了整包拒绝，并未证明月宿可独立保留。

**影响与级别：** 属于可用性收缩，不会把不支持的数据默认为正常事实。当前固定引擎正常产物不触发此分支，故不足以阻塞本轮 A；但不能把“两份侧车隔离”报告成“四体系缺项均独立降级”已经完成。

**建议：** 逐步把验证分为共同身份与各体系依赖闭包，例如月宿依赖 time、sevenBodies、mansions，七政再增加 residuals/lifeDegree；返回各体系的 ready/unavailable 结果。共同身份错误仍整体拒绝。八字/紫微也可在共同出生身份通过后分别验证。无需为了隔离一个未知解释而放宽真实字段或方法验证。

**A 阻塞：否。** 本轮交付说明应写清当前故障边界；后续分模块恢复需要有独立反例。

## IMPL-03 · P3：字段/方法不兼容统一引导检查出生资料，恢复指向不够准确

**位置：** `NatalReadingReportView.swift:314` 的 `failure` 及 `reportState`；`AppStore.swift:236` 的本命缓存返回路径。

**反例：** 合法出生资料对应的缓存缺少新解释器要求的字段，或方法版本暂不支持。编译器统一抛 `EngineContract.Failure.invalid`，页面显示“请检查出生资料”，保留出生编辑入口且禁用重试。保存同一出生资料又可能从 `ensureNatalDossier` 取回同一个浅层契约仍接受的缓存，用户并未获得能解决字段兼容问题的动作。

**建议：** 区分输入身份不符、缓存格式损坏与不支持的方法。前者才提示核对资料；可重建缓存提供一次明确重建；当前版本不支持则说明需要应用更新。保持不展示旧结果的现状，不能以普通重试把未知方法变成受支持。

**A 阻塞：否。** 当前失败是安全关闭，问题在恢复说明；无需为此改变用户出生值。

## 已落实的关键边界

- **身份和当前性：** `NotebookReportIdentity` 含 scopeKey、scopeRevision、完整编码 birth、engine、content/adapter。渲染先比较结果身份，两个加载函数在 await 后比较身份并检查取消。Profile 报告还有完整资料 `.id`；账号变化关闭根 sheet。未找到新报告在身份不符时继续显示旧结果的直接路径。这里只作静态结论，A→B→A 晚到、导航栈中的旧专业详情仍应由运行验收确认。
- **字段与未知值：** 必需字段使用专门 DTO；十神按日干复核、藏干表与权重核对，宫位集合、身宫、主星集合、生年四化及方法均有约束。缺主星数组不会被解成空宫。未收录主星走明确“未收录、不判单星/同宫组合”的分支；未收录辅杂曜仅保留字段、不新增象义。这和把未知 enum 落入普通默认解释不同。
- **原始证据：** 每项 evidence 指向原 dossier payload，保留值，快照投影与完整 birth、owner、bundle revision 一起生成 ID；包含内容/适配版本。未见构造假的 toolCallID/receipt，也没有调用旧人格字段写解释。该 ID 用于稳定性与身份区分，不是外部数据认证或历史回放仓库。
- **离线与隐私：** 新报告编译器及内容库不调用模型或网络。来源链接由用户点击打开，URL 没有附带出生字段。读取报告本身没有把它传给 ChatSession/ReflectionSession；既有账户云同步和独立聊天仍是既有路径，不属于新报告已经解决的证据协议。
- **导航：** 保留稳定的三子视图 `TabView`，资料作为外层 sheet，关闭动作独立于内部导航栈；缺资料按钮使用显式出生编辑 action。搜索未发现把 Profile 继续导航到 `selectedTab = 3` 的残留；Calm 的 `tag(3)` 是计时选项。未把 ChatView 改成切换时反复销毁的 `switch` 容器。

测试源码中有真实本地引擎的合成样稿、污染旧 personality、来源 pointer 解析、档案恢复、资料/账号变更及 UI 路径检查，但本评审只确认这些测试存在。特别是 UI 的 `--notebook-fixtures` 明确绕过生产登录/出生/建档 gate，不能仅凭该路径宣称生产“编辑出生导致重新建档期间仍保留所有视图状态”已经测过；F2 本轮保留既有 gate，应按实际覆盖范围报告。

## 内容完成度，与缺陷分开

实现与 F2 的缩小范围基本一致：Profile 和阅读首屏写“基础读盘”；八字、紫微总边界明确“尚不是完整性格或生活主题解读”；七政明确角色/格局与生活主题尚未审定。没有以“报告”名称偷偷开启职业、财富、婚姻、健康或成功率结论。

八字确实按实际透干/支藏、同干出现、只透/只藏/双层/未见改变结构说明，不能简单归为仅替换称呼的词典。紫微根据真实空宫、单星、同宫、身宫和四化改变内容，并将传统角色与实际落宫分开。14 条 Swift 摘录与 `ziwei-symbol-sources.json` 一致；本次也在已取得的 `ziwei-source.txt` 中核对到对应原句。摘录能支持词义归属，不证明现代人格/生活结论，当前释义没有跨过这条边界。天文使用现代距星与坐标口径，未将其冒称宿曜、历史宿度或完整恩用财难判断。

仍未完成的内容能力是：全面星曜/宫位组合条件、八字和紫微生活主题解释、宿曜、七政角色/格局，以及 F1 的历史报告版本库和 AI 自动交接。它们属于已写明的后续范围，不是本次新增 P0/P1，也不能由“条目足够多”或 UI 测试通过折算为已交付。若最终对用户宣称完成截图式完整性格/事业/关系报告，交付结论就会超出本评审允许的 A 范围。

本复核只新增本文件，未修改代码、运行测试或模型，未提交或部署。
