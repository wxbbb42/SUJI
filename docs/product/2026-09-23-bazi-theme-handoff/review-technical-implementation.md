# 八字主题衔接：实施独立技术评审

评审日期：2026-09-23。评审者：`/root/theme_ai_audit`。对象：`776b34f` 之后的在建工作树，主要为 `BaziLifeTheme.swift`、`BaziThemeConversation.swift`、`BaziThemeContext.swift`、`ChatSession.swift`、`ReflectionSession.swift`、`AppStore.swift`、`Domain.swift`、`ArchiveCodec.swift`，并读了当时已接入的 Root/ChatView 导航。未参与实现，未改业务代码，未执行付费请求、构建或测试，避免和主代理共享 DerivedData 并发构建。本评审读取了测试源码；运行结果须以主代理记录为准。

**第一轮结论：证据信任边界有实质改善，但尚不能验收闭环。发现三个须修复的 P1：get_domain 漏出生输入、生产建档 gate 会销毁草稿状态、明确退出主题未关闭自动主题继承。** 已逐项即时发给主代理。审阅期间源码仍在变动，以下保留发现时的依据；后续修复/复测结论应追加，不把第一轮发现删除。内容评审者已提出的 allowedActions 可能答非所问与同事词路由过拒，不重复作为本评审的新发现。

## IMPL-T01 · P1：新主题工具请求没有出生输入

位置：`native/App/Services/ChatSession.swift:answerTheme`，本轮首次读到第370行附近的 `store.request`。

它传了 command/name/id/arguments/now，却没有原管线 execute 所传的 `birth`。`AppStore.request` 只有看到请求中与当前资料相符的 birth 才注入 natal；`get_domain` 从 `ctx.mingPan` 读 pillars/dayMaster。因此“册页本地正常”与“主题投影实际有八字”是两回事。即使模型登录成功，此路径也会在 `validateProjection` 因缺字段拒绝。

修法：先 guard 当前冻结 birth，然后像原执行器一样传 `try store.birthJSON(birth)`，由 AppStore 在可信边界注入有效缓存。不直接把 binding 或 theme 转成 natal payload。

验证：用生产 `ChatSession.send` + 真实本地JS引擎，模型响应可在单元层使用受控闭合选项，确认执行发生、原始receipt有完整八字、选择协议被调用且最终回复保存。缺birth的版本应先失败。这项单元集成证明计算链，不替代之后真实Supabase→DeepSeek验收。

## IMPL-T02 · P1：独立出生generation没有解决生产页面生命周期丢草稿

位置：`native/App/SujiApp.swift:RootView.body` 第74—79行附近；`native/App/Features/Chat/ChatView.swift` 的内部 `@State input/session`；`BaziThemeHandoffUITests` 的 `--notebook-fixtures`。

新增 birthRevision 与 scopeRevision 分开，避免主动执行“账号切换时清草稿”的 observer，这是正确的。但生产 Root 仍在 `!store.hasNatalDossier` 时把整个 mainTabs 替换为 DossierSetupView。实际 A→B 修改使旧dossier不匹配，mainTabs/ChatView移除，内部State草稿和会话对象的身份不能据此保证保留。UI测试使用 notebookFixtures，总是 mainTabs，因此不能验证此生产分支；只重新保存同一出生值也不足以触发它。

修法可二选一：把草稿与ChatSession放到稳定的、账号隔离的上层容器；或对已进入产品的用户保留mainTabs身份，用受控建档状态覆盖需要新盘的入口。首次建档和账号切换仍要遵守原gate，不允许旧账号内容闪现。不要以禁用资料编辑回避这条用户要求。

验证：使用与生产等价的 Root gate，保留未发送文字，确认真实不同出生B，等待新dossier，再返回问道，文字仍在；进行中请求应停止或被generation拒绝，不写回旧结果。A→B→A也验证。fixture绕gate的返回测试仍有价值，但应单独标明。

## IMPL-T03 · P1：用户点击“不带这页继续聊”后，旧主题会自动恢复

位置：`ChatView.themeContextActions` 仅 `themeNavigation.clear()`；`ChatSession.send` 第65行附近 `themeBinding ?? previous.themeBinding`；`ChatView.sendDraft` 遇pending总是把mode强制命理。

反例：成功收到主题回答→再次打开该页/存在pending→用户点“不带这页继续聊”→问“表达是什么意思”。UI清了待发主题，Session却从上一assistant继承themeBinding，再次进入主题分支。没有“显式退出”和“未提供新主题但允许正常追问”的区别。pending若发送后永不消费，用户手动切倾诉也可能在sendDraft被改回命理。

修法：用明确的主题选择策略（例如显式binding、允许连续追问、显式不带主题）或等效状态传入send；用户退出必须覆盖自动继承。首发的pending应在合理时点消费，失败仍可从原user entry重试；恢复不需靠永远挂着导航pending。是否持续锁命理必须可见且可退出。

验证：正常连续静态追问仍带来源；取消之后的相同文字不触发主题selector；切倾诉确实走倾诉；有运行中任务时切入册页不会停止它、下次发送不会吞草稿。断网重试仍绑定原题。

## IMPL-T04 · P2：历史关联当前只保留binding/action，没有重建历史正文的完整合同

位置：`Domain.ConversationEntry` 的 themeBinding/themeAction；`ChatSession.persistReply` 与自动候选；`ChatView` 对 `entry.themeBinding != nil` 显示返回入口。

有利事实：外部归档import已同时删除themeBinding/themeAction；每次回答会从当前仓库重建theme，完整比对binding，再比对真实投影字段；旧assistant正文没有作为事实输入。因此本评审没有发现它直接把篡改历史变成当前事实的路径。

剩余边界：原生本地回放只展示旧text与来源字符串，缺少 sourceUserID/协议版本/完整结构化渲染快照的重建检查。auto主题只看上一assistant带binding，不检查它是否对应相邻user真实回执及相同action的原渲染结果；这目前主要是主题许可与历史可追溯健壮性不足，不等于事实已跨过新投影校验。重启后运行时UUID轮换会让旧binding无法新授信，安全关闭，但需要准确的重新选择说明。

建议：至少存储并核对来源user ID、当前选择协议/规则版本和动作；回放时不把结构不一致的旧text标作已通过主题回答，保持可读历史。历史返册页应明确是否当前资料已改变，不能只在accessibilityHint里说明跳转当前档案。完整多版本报告库可以延期，但交付不能说已支持历史主题内容重演。

验证：保存重启后旧文可读且新问需重新选择；导入移除权限；篡改action/text/源user或删除源回执不能获得“已验证主题”标记；返回新资料时有可见提示。以上不能只用 `binding.isWellFormed` 测试代替。

## IMPL-T05 · P2：在线能力成本有硬调用上限，仍需如实区分模型价值与协议成功

`BaziThemeAnswer.compose` 最多两次选择请求，transport失败直接抛出；`ChatClient.complete` 未见内部自动重试，因此此主题分支本身有清晰上限。`validate` 精确限制三个字段、snapshotID、action及allowedActions，最终正文程序固定渲染，模型不能输出新命理句子。这符合受约束生产核验路径，**不是原自由文稿 ReadingVerifier 的通过结果**。

但action只是有限选项，不能声称AI已经深入理解现实处境或实现开放的“带上下文继续问”。请求含最多前两条user问题，却没有完整assistant动作状态；同一个泛用答案反复出现时，JSON合格也可能对用户没有增量。allowedActions答非所问已有其他评审在修，需将真实问题的内容合格单独评分。

真实验收报告应列：是否实际计算、是否协议通过、选了哪个动作、是否回应本题、是否有新增帮助、模型请求数、失败阶段。主题最多两请求的界限不能套到 `.standard` 动态/事件路径；后者有原工具规划/自由稿/核验/修复预算，整批测试必须另有总上限，剩余不足时停，不无限重试。

## 已验证到的实现改善（静态源码结论）

- **出生代际：**birthRevision在成功保存后轮换，包括同值确认；账号切换、档案替换、云恢复也轮换。request、natal/astronomy task、profile计算、sync写后处理、ChatSession与ReflectionSession的异步检查加入generation。失败输入在改变revision前被拒；这比只比较A最终值严格。
- **内外引擎版本：**AppStore从同一bridge metadata读取payload revision；缓存匹配和新生成都比内层声明。`NatalReadingCompiler.natal` 参数必传expected payload revision，避免调用者省略。原IMPL-01 P2的核心原因已处理，测试源码包含格式合法但版本错误重建。
- **调用方快照：**AppStore.request无条件去掉natal与astronomy，然后只由可信仓库按当前资料注入；alternate-birth调用方伪natal测试存在。原T-08方向已落实。
- **完整主题绑定：**owner、scope/birth revision、出生指纹、bundle/payload、snapshot/content/theme校验齐全；主题重新编译后要求完整binding相等。generation是运行时的，有意不允许归档UUID直接恢复可信权限。
- **真实投影校验：**`validateProjection`比较实际receipt名称、参数、context、domain、无error及七项完整依据（四柱对象与日主三字段）；全量四柱canonical比对，不能只改某个十神仍通过。关键前提是IMPL-T01先使这份真实回执存在。
- **不伪造信任：**选择packet是普通数据，不冒充工具消息；model只给闭合选择，程序渲染整个正文与boundary。真正receipt只在store.request完成后创建，重试复用同user entry且context相等的receipt；没有给旧receipt重写referenceDate。
- **归档import：**新增绑定和动作明确去掉，原文本/证据仍供历史阅读；未知格式不因hash看似合法而自动获得当前账号权限。
- **Reflection旁路：**新增generation保护，但其既有自由流式命理解读仍未迁移。新主题代码没调用ReflectionSession；交付必须继续把旧旁路和32题矩阵排除在新主题可靠性结论之外。

## 后续验收仍待证据

主代理告知已有19 hosted身份/存储测试与Core主题测试通过。本评审未亲自执行，也未在本次读取到完整原生主题会话/真实请求逐例日志，不能据此宣布新链路通过。应补：

1. IMPL-T01生产会话真实引擎RED/GREEN。
2. 无binding普通问道及Reflection异步取消回归，确保新增generation不只保护主题入口。
3. 网络失败/协议拒绝→原问题与receipt保留→有限重试；资料或账号变更后的retry明确拒绝。
4. 动态、他人、事件、模糊和明确退出；当没有可用绑定时不得从旧assistant文字复原权限。
5. 生产gate等价的草稿生命周期，及普通/大字深色的实际截图；人工VoiceOver另列未验证。
6. 有预算的真实Supabase→DeepSeek→生产闭合核验逐例结果；动态标准管线若失败如实保留，不能把取数成功代替解释通过。

本评审不改变内容价值评审结论，也不将静态安全闭合当作命理预测验证。完成这些缺口后可以交付一个受限的完整主题增量，仍不能宣称旧问答问题整体解决。

## 第二轮追加复核

同日追加；独立评审者重新读取实现和主代理已落盘日志，没有启动构建或模型调用。此处状态覆盖上面第一轮结论，不删除发现历史。

### 三项P1的修复状态

- **IMPL-T01已修复并有定向运行证据。** `answerTheme`现在先guard冻结birth，实际get_domain请求传`store.birthJSON(birth)`；仍由AppStore注入可信natal。实际读取`native/artifacts/bazi-theme-2026-09-23/session-green-2.log`，主题Session5项和身份5项合计10 tests、0 failures。`testRealProjectionAndRejectedSelectorPreserveFactsForRetry`源码确认使用真实JS引擎，先让选择器两次输出无协议文字，保留真实receipt；随后重试接受受控选择，receipt与dossier.createdAt均不变。它证明本地生产Session计算及协议恢复，未假称真实DeepSeek已通过。
- **IMPL-T02源码层已修复，最终UI结果待主代理收齐。** Root只有一个`if notebookReady { mainTabs.id(scopeRevision) }`分支；进入过产品的同scope用`admittedScopeRevision`维持同一SwiftUI身份，重建显示状态条，首次登录/首次建档仍保留gate。账号不满足`notebookAccountAvailable`时不能借旧admission继续显示。新增gated fixture仅代替认证，实际出生编辑、真实引擎及`hasNatalDossier=false`间隙继续执行；测试明确断言观察到真实间隙。此结构对应修复原因，不再用旧无gate fixture作为唯一证明。
- **IMPL-T03源码层已修复。** 原生发送明确传`inheritTheme:false`，UI是否带主题完全由可见pending与当前mode决定；切离命理清pending，send不再强行改回命理。因此点“不带这页继续聊”后不能由上一答自动复活。持续pending的行为仍是显式带主题会话，用户可看见并退出；并非发送后已消费。Core/Session默认自动继承接口仍存在，但原生入口不使用该默认，独立调用者如使用须明示其权限约定。

### 新的具体路由反例 IMPL-T06 · P2

`BaziThemeRouting`为避免“我和同事的真实经历”被当作解读另一人，新增了experience提前返回分支。但这段在“六爻/奇门/起卦/起局→standard”之前，而且outcome过滤词未含这些术数。

静态可确定反例：“请用六爻看我和同事的不同意见”“我想用奇门观察这次不同意见”满足experience条件，会提前进入本命主题，忽略用户明确方法。这不造成伪盘面，却是错误路由，违背新链的事件边界。已通知主代理把明确术数检测提前到experience并补反例。当前文档追加时尚未读到该修复，需在交付前确认。其他真实经历仍允许本主题编辑练习，不应反过来恢复所有“同事”过拒。

### IMPL-T04历史记录改善，但仍保留范围限制

新增`BaziThemeReplyRecord`记录sourceUserID、context、protocolVersion、ruleVersion、action、evidenceIDs，创建时来自真实当前theme，归档import明确去掉record。这补齐了此前缺少的关联字段。

该record目前是历史来源元数据；`isWellFormed`不重建正文、不校验sourceUserID所指回执，也不被ChatView用于完整历史正文验证。因此不能写为“已实现历史报告可重演核验”。新问答依然会重建当前theme和真实投影，外部import不获授权，风险仍可作为P2边界保留。重启后的历史binding安全拒绝，需要重新从册页选择；历史返回按钮仍只在accessibilityHint解释打开当前资料，最好加可见的资料已变化提示。

### 运行证据与尚未完成项

独立读取了`session-green-2.log`的10项通过结果；没有把主代理口述的运行结果冒充本评审亲自执行。另在当时读取到的`native-ui.log`，hosted汇总为60 tests、2 skipped、1 unexpected failure：`StoreRegressionTests.testOlderSlowBirthCalculationCannotOverwriteNewerResult`出现`uncertainty.birthTimePrecision`应为Double却是string的解码错误，已立即通知主代理。它不等于已证明新generation错误，也不能忽略；需要查明并定向复测后才能声称整体回归通过。

五项UI、真实小批量Supabase→DeepSeek、最终Core整体结果尚在主代理执行范围，本追加不预告它们成功。真实预算拟为最多8场景、24请求，新增标准动态路径的实际请求也要计入总额。当前可作出的结论是：第一轮三个P1已在源码中有针对性修复，T01有定向运行证据；整体可交付结论仍以新增路由反例、回归失败处理及实际UI/在线核验结果为条件。

## 第三轮追加终审（在线验收前）

独立重新读取最新主题协议、生产Session、Root状态与测试日志。没有修改业务代码、启动构建或模型调用。

### 已闭合项与日志核对

- IMPL-T06明确方法优先级已修复：六爻/奇门/起卦/起局在experience分支前进入standard；测试包含本评审给出的两个原样反例以及另一个混合句。源码仍有一处重复的术数判断，只是可清理冗余，不影响正确性。
- 未发现新增绕过主体/资料/版本验证的主题入口：原生UI显式传入pending binding并禁用无提示继承；主题发送重建当前本命、全binding比较、真实get_domain投影比对、回复写前再次核对generation。报告正文没有成为工具事实，ReflectionSession没有被新主题调用。
- 新`followUp`不是自由模型句子。输出必须恰含四字段，followUp属于action对应的审定枚举，最终完整限定与追问均由程序渲染，replyRecord保存followUp。这没有扩大模型伪造命理事实的权限，最多两次选择调用的上限仍在。
- 独立实际读取`core-final.log`：513 tests、1 skipped、0 failures。读取`native-ui-final-2.log`的hosted段：60 tests、2 skipped、0 failures；此前`StoreRegressionTests.testOlderSlowBirthCalculationCannotOverwriteNewerResult`现在通过。测试变更保留“旧操作不能成功/新结果不能被覆盖”的断言，明确要求旧代际以CancellationError结束；不是删掉失败用例。这里是已读日志的核对，不是本评审亲自执行。

### IMPL-T07 · P1（流程完整性）：主动追问与下一轮短答没有共同上下文

这不是新证据安全漏洞，但会阻止宣称新增的主动追问已经闭环。

当前followUp可输出“你不同意的是这项要求要达到的目标，还是达成目标的方法？”用户正常回答“方法”或“目标”时，`BaziThemeRouting.resolve`只看当前文本，不接收上一通过核验的追问，结果落到“你想了解哪一部分”的泛澄清；constraints问完回答“预算不能动”也同样丢失承接。compose只带前两条user问题，没有上一assistant具体选择的followUp，无法可靠知道刚问过什么。

这个反例不能靠“举个例子→怎么理解”两轮都带关键词来代替。当前新追问是产品主动发出的，因此应至少完整支持它允许的短答，或者先不主动询问无法承接的问题。

最小修法：把可信上一主题回复的action/followUp作为有限对话状态，允许目标/方法或明确约束短答进入对应编辑观察；模型只在审定续接模板中选择，不能借机生成用户人格或新事实。**新record目前只有历史元数据，不能直接授信**：用于路由前需核对上一assistant绑定、sourceUserID与相邻user关联、context与该user一致、实际receipt投影有效、正文等于当前theme/action/followUp完整render。遇规则/内容版本变化、导入剥权、资料变更仍要求重新选择，不以关键词猜上下文。

验收应添加：合法问句→“方法”的短答；同样“方法”没有可信上一问时正常澄清；上一问绑定不符/正文改动/源回执缺失时不继承；“明年呢”“那我对象呢”仍优先退出静态主题。若本轮收窄followUp为none，需明确不声称具备AI主动澄清续接。

### 在线验收声明边界

本轮未发现需要重新设计事实投影或放弃新birthRevision的阻断问题。仍不能用这些静态结论代替真实Supabase→DeepSeek结果。最多8场景、24请求的真实验收应把新增追问短答纳入连续对话；计算成功、选择协议通过与问题被回应三个结果分别记录。历史完整正文重演、Reflection旧自由路径、旧32题矩阵、真机和人工VoiceOver继续作为未验证/未完成项，不能由513项Core通过推定。

## 第四轮追加终审：受信短答承接

重新只读检查最新`BaziThemeHistory`、路由/selector、ChatSession及新增hosted测试。**IMPL-T07在源码层已有对应修复；未发现新增阻断事实、主体或资料授权的旁路。** 运行层仍需主代理待执行的hosted/在线验证，不能将这个静态结论写为所有在线场景通过。

本轮的可信上一问不是从旧assistant普通文字推断。ChatSession先验证当前binding、重建当前theme并完整比较绑定，随后`verifiedFollowUp`要求：紧邻assistant/user角色与同binding、sourceUserID匹配、record/source context一致、当前协议与规则版本、精确evidenceIDs、action一致、合法followUp、正文等于当前主题完整render，以及唯一真实receipt通过`validateProjection`。外部import仍删除binding/action/record，因此不能凭可解码的历史记录恢复授权。

短答采取窄白名单：目标/方法及少量约束语句，只有相应已验证的上一问才能映射到methodStep/goalStep/constraintStep。新段落明确是根据用户答复给出的现代沟通练习，不把这个选择归因于命盘；方法/目标分支不会重新问同一个目标/方法问题。明确术数和高风险事项仍优先于短答。没有可信上一问的“方法”仍正常澄清，不能借此构造一份新人物画像。

独立实际读取`short-followup-red.log`：新API缺失导致编译失败，属于先写验收接口的RED，**不是旧系统运行行为已经被复现**。读取`short-followup-green.log`：9专项tests、0 failures。hosted源码新增真实Session生成上一问→“方法”成功以及正文、回执、source ID、绑定、context五种改动不继承的测试；当前读取时尚未获得它们的运行完成日志，不预告通过。

仍建议一个小型P2健壮性补充：`verifiedFollowUp`直接比较`record.context.birthFingerprint == binding.birthFingerprint`及`record.context.engineRevision == binding.payloadRevision`。当前record/context只与source和receipt互比，虽然当前theme完整投影、当前绑定授权与导入剥权已经阻止通常的旧资料复用，没有证据将这称为现有跨主体漏洞，但直接比较更准确表达合同，避免将来另一个调用者误以为自洽历史就等于当前身份。

范围限制仍明确：这不是通用短答理解器，诸如任意叙述、同义句、多个新事项可能继续澄清；完整历史版本库未实现。可交付表述是“对审定追问提供有限、带来源的续接”，而非“AI能够完整理解所有上下文”。接下来应停止扩展协议，完成已定义的集中回归及有预算真实请求，把实际失败如实保留。

## 第五轮追加：真实首批请求独立读回

本次实际读取原始`native/artifacts/bazi-theme-2026-09-23/live-2/report.json`（SHA256 `5554d2e096e8655074afae68804c06b8eeee6f3b532ee59754b02e6099b78978`）、其中T05全部8个请求/响应、同目录`xcodebuild.log`和脱敏`live-before-fix.json`。原始资料是明确合成测试；本文只保留原因摘要，不复制模型原始正文或出生资料。没有重新发起付费请求。

### 首批结果的正确读法

8场景、19个用户轮次、19次实际模型请求，另有1次网络发送前人为注入的offline中断。两个19恰好相同，不能理解为每轮都只调用一次。raw有11轮`closedProtocolOK=true`，其中T01第1轮虽然协议正确，却未满足用户明确要求追问，必须判内容失败；有5轮程序澄清，其中T01第2轮是前一步遗漏追问造成的链路失败，其余动态/他人/模糊/事件澄清符合范围。另有一次旧资料绑定拒绝、一次预期offline、一次标准动态解读失败。**不得把这些状态合并成19轮通过。** 本评审对主题完整内容价值不代替内容评审者打分。

### T01：协议成功仍可能漏做用户明确请求

真实T01第1轮要求举例并再问一个问题，模型选择example+none，本地当时允许none，因而协议通过但没有追问。下一轮用户答“方法”，程序观察到上一答的followUp确实是none，正常澄清，没有伪造曾问过的问题。这个安全关闭是正确的，但整个承接场景失败；根因是allowedFollowUps没有把用户要求的追问作为内容必需项。

主代理已新增定向RED并修改明确肯定请求时排除none，拟在剩余最多5模型请求内同题复测。当前只读到修复源码，尚未读取修后真实结果，不提前关闭T01失败。

新修法另有一个P2语义反例已通知：`举个例子，但不要问我问题`也会命中“问我…问题”子串，强制排除none。应先识别否定，再处理肯定请求，补同句正反例即可；不需为它扩大真实预算。不要通过强制每一题都追问把首批绿化。

### T05：真实取数成功，既有标准自由稿/核验协议未完成，仍为失败

输入为“今年事业流年怎么看”，route为standard；实际工具是get_domain、get_ziwei_timing、get_timing，三份回执均已取得。原生日志明确最后原因`Reading verification rejected: invalid_verdict`，不是network failure，也不是没有盘面。

按8个exchange顺序追踪：

| exchange | 实际步骤 | 独立观察 |
|---|---|---|
| 0 | 规划并请求3工具 | 路由与工具范围合理，未走静态主题selector |
| 1 | 规划结束返回文字 | 含传统象义到现实行动的扩张；该文字不是正式writer终稿，不应混作已展示回答 |
| 2 | 自由writer草稿 | 在盘面事实之外继续从食神、星曜与流年推导现实工作/对外活动取向；年龄口径也没有全部保留 |
| 3 | 第一次review | 将现实建议归为candidate-not-established，但这不满足本地该规则对格局/用神候选升级的窄predicate，核验意见不能授信 |
| 4 | 协议重核一次 | field_mismatch用了候选句子片段、错误工具对象/字段及不匹配的值关系，另两项也不是可接受完整句证据；本地拒绝该review |
| 5 | 固定protocolRecovery修稿 | 稿件缩短，但仍明示由食神/迁移宫化忌事实给现实输出和外部场景精力建议；不能认定已完全移除无依据扩张 |
| 6 | 修稿review | 给personalized-rule-required，但该句不满足本地要求“个人主体+星/宫+归因动词+人格/能力/职业”的窄组合，review再次无效 |
| 7 | 修稿review重核 | 改用action.no-chart-selected-year，但句内缺该谓词要求的具体年度及限定行动组合，仍无效，预算用尽后invalid_verdict |

因此不能简单定性为“核验器把好答案误拒”。这里同时有writer超出当前返回规则依据、核验模型与程序支持的issue语义不一致两个问题。最终fallback保留已计算四柱、官禄主星及有虚岁限定的大限事实，没有把未完成核验的草稿给用户，也没有把取数成功当作完整事业解读成功。正确下一步是对既有标准管线补可验证的解释能力与核验合同；不能放宽字段/规则检查或关闭保护来接受这份草稿。

### 是否由新主题跨上下文污染造成

本次T05没有观察到主题污染：第一请求只有系统说明和该用户问题；8个请求均没有新的主题选择协议、册页主题正文或前一次主题问题。它是独立scenario的initial turn，通过有binding入口识别动态后走standard。

这只能证明**这次失败不由主题packet注入导致**。它不是“主题回答→同一会话动态追问”的完整连续测试，不能据此宣称实际跨话题上下文污染已被全面排除。新主题路由的安全测试和真实T04动态澄清提供部分覆盖，但动态成功解读尚未交付。旧32题矩阵也未因这次单题取数而更新。

### 身份与失败恢复的实际记录

T03旧出生binding在模型前拒绝，重新选择当前主题后成功；T06他人、模糊和具体成败没有把静态主题当证据硬答。T07首轮是测试代码明确注入的offline，不是真实网络故障；其重试实际经过部署服务及模型，原receipt保持不变、dossier复用、历史仍可读。可以说“受控中断后的真实重试恢复有效”，不能说“本轮实际发生网络故障并自动修复”。

第四轮提出的context对当前binding直接比较已经在最新`verifiedFollowUp`源码补齐；那个小P2关闭。历史全文版本仓库与自由Reflection路径限制仍在。

**当前终审状态：T01修后真实复测未收齐，T05明确未通过，UI仍有键盘动画等待与磁盘空间问题在处理，不满足整体交付通过声明。** 继续使用原24请求总预算；已19次实际调用，剩余最多5次用于计划的T01复验，保留首批失败证据。任何最终通过描述都必须限定于实际跑过的闭合主题场景，不能扩张到完整流年/全问道产品。
