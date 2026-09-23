# 有时：易读本命报告方案的现状与证据

日期：2026-09-23。本文为方案研究记录，不是新一轮运行验收，也不是发布证明。

## 1. 工作边界

- 工作区 `/Users/xiaqobenwang/Documents/SUJI`；沿用 `codex/fix-mingli-today-activities`；读取时 HEAD 为 `8164f25d12ffc246b9cead96cae64d6760098983`。
- 现有真实问答修复、测试及矩阵文件均有未提交内容。本任务只新增本目录文档；不改业务代码、不提交、不部署、不跑付费问答。
- 以下“现有”包括当前未提交实现，不代表手机安装包或生产版本已包含它们。“拟议”是待授权实施的产品/技术设计。
- 本地源码及规范是现状证据；竞品截图只证明可见呈现，不证明其算法、内部模型或预测有效性。

## 2. 当前产品与技术能力

路径均相对仓库根。符号名作为定位锚，避免未提交工作导致行号漂移。

| 现状 | 证据路径 / 定位 | 对方案的约束 |
|---|---|---|
| 原生 SwiftUI，今日/问道/静心/我的四个页签 | `native/App/SujiApp.swift`，`RootView.mainTabs`；`docs/README.md` | 不重新引入旧 Expo，不增加第五个“命盘”主导航 |
| 首次需登录、恢复账号、确认出生资料、完成本命档案准备才能进入主界面 | `native/App/SujiApp.swift`，RootView 条件分支 | 现有建档失败会影响全局进入；解除这种全局阻塞属于新设计，不是现成功能 |
| 我的包含“你的底色”、命盘手稿、人生的节奏、校时、关系和心情册页 | `native/App/Features/Profile/ProfileView.swift`，`PersonalitySection`；`ObservationViews.swift` | “我的”可变成易读报告入口，但必须保留个人管理与其他功能可发现性 |
| 本命四柱/紫微有真实计算与专业显示 | `ProfileView.swift`，`ChartDetailView`；`BaziStrengthTraceView.swift`；`native/Engine/bridge.ts`，`natal` | 不必再造计算引擎；展示存在不等于所有象义和事件判断都有依据 |
| 出生输入以北京时间 UTC+8、公历及经度为当前口径；太阳时校正并非应用于所有体系和柱位 | `ProfileView.swift`，`BirthEditor`；`native/Engine/bridge.ts` | 不假装已支持未知时辰和全球自动时区换算；修改资料必须说明受影响口径 |
| 已有本命缓存，按账号、完整 BirthProfile、engineRevision、schema、digest 检查 | `native/Core/Sources/SujiCore/NatalDossier.swift`，`matches`；`native/App/Services/AppStore.swift`，`ensureNatalDossier` | 用户担心“每次问都重排本命”不是当前主要根因；需把缓存里的事实、规则和文案进一步分层 |
| 天文模块独立本命缓存；profile 投影同时带动态时间信息 | `NatalAstronomyDossier.swift`；`AppStore.request`、`calculateProfile`；`bridge.ts`，`profile` | 七政四余/星宿不要混入八字同一结论；profile 不能整体视为永久本命事实 |
| natal payload 含 InsightEngine 的 personality | `native/Engine/bridge.ts`；`native/Engine/src/bazi/InsightEngine.ts` | 旧文字把十神、格局映射为现代性格/职业，源码注明“产品编辑启发式，不是心理测量”；不得直接升级为核验过的事实 |
| SwiftData 保存账号分区的 SavedState；本命为可重建本地缓存 | `AppStore.swift`，`SavedState`、`scopeRevision`、`prepareAccount` | 方案优先本地实体/Blob 演进，不凭空假设云端报告服务 |
| 出生资料可云同步；聊天、日记本地；账号切换会取消/隔离异步工作 | `AppStore.updateBirth`、`syncBirthProfile`、`prepareAccount` | 新报告也须隔离，跨设备初期只能重建基础报告，不能承诺恢复所有聊天和个性化文字 |
| 问道有倾诉、命理、起卦；默认倾诉 | `native/App/Features/Chat/ChatView.swift` | 从报告进入需显式携带命理语境，并让用户看见自己正在问哪个主题 |
| 真实链路：规划/工具/解释/核验/回退；重试保持参考时刻和回执 | `native/App/Services/ChatSession.swift`，`send`；`ToolOrchestrator.swift`；`ReadingVerifier.swift` | 保留工具与核验保护；不可用报告长文代替工具证据 |
| 通用历史回执只按当前用户回合的完整 ToolContext 注入；专门八字追问已有重绑定检查 | `ReadingContext.swift`；`ReadingDocument.swift`，`BaziReadingRequest.trustedPrevious` | 稳定本命追问复用需要专门依赖验证与绑定，不是删除 referenceDate 校验 |
| 已有来源约束的 Claim/Catalog/ReadingDocument 路径 | `BaziFrameworkReading.swift`、`ReadingDocument.swift`；`ReadingDocumentView.swift` | 可借鉴“程序固定断言、模型选择/排序”的模式，但现有文档只覆盖八字部分主题，不能当作通用报告框架已经完成 |
| 另有 ReflectionSession 旁路，将调用方context放入system资料，streamText后直接显示/保存，不走ReadingVerifier | `native/App/Services/ReflectionSession.swift`，`run`；`SujiApp.swift`的今日reflection；`ObservationViews.swift`的关系/校时入口 | 初稿主要描述ChatSession；终稿须覆盖这些命理资料入口，不能把改好一个聊天通道称为全产品已隔离旧象义 |
| 外部导入保留历史文字、去掉工具上下文/证据可信元数据 | `ArchiveCodec.swift` | hash 只检损坏、不证明来源；新报告导入不得恢复旧证据权限 |
| Supabase Auth → suji-chat → 固定 DeepSeek Flash；函数不持久化问题/回答 | `supabase/README.md`，既有 Edge 配置 | 本方案不增加托管平台或后台生成服务；模型仍需联网及账号 |
| 每次输出上限 2048 token、请求体 256 KiB、文本 120000 字符、上游 90 秒；配额 12次/分、120次/账号UTC日、项目5000次/日 | `supabase/README.md` | 一次问题可能消耗多次请求；失败也计数；这些是现有上限，不是体验目标或金钱预算 |

## 3. 真实问答矩阵的含义

来源：`docs/mingli/validation/reading-matrix-2026-09-22.md` 与同名目录下 `per-question.json`。这是上一轮执行证据，本轮没有重跑。

- 32 个独立问题，95 轮记录，435 次真实模型请求，3 组明确标记的合成档案。
- 最终人工语义分类：**2 通过、2 澄清、10 缺项/条件不足、18 失败**。
- 原生展示 23、拒绝 9；已展示中另有 9 个仍未通过人工语义判断。不能以“UI 有文字”或“核验通过”冒充答对。
- 173 条工具回执未见顶层引擎 error；95 轮本地档案复用/归档读回一致。不能外推为所有计算和导入场景都可靠。
- 最终题目证据混合 v19–v22；未在同一最终版本上全量重跑32题。样本不是稳定成功率，更不是预测准确率。

| 失败/边界 | 矩阵题号 | 方案必须回答的问题 |
|---|---|---|
| 追问未取工具，拿历史文字解释，最后报未取得计算结果 | 02 的早期追问；主问题后来仍失败 | 静态证据怎样进入新回合？怎样区别“没有证据”和“有证据但解释失败”？ |
| 有盘但追加性格/事业/关系推断缺少规则支持 | 04、07、12、19 | 普通报告的内容依据从哪里来？怎样避免把“有星位”误当“有解释规则”？ |
| 错误月干曾被模型核验放行 | 01、09 | ID 引用不能证明文字没有改写事实；强类型值如何由程序渲染？ |
| 财务建议越界、六亲口径改写后仍逃过窄校验 | 10、13 | 检查关键词不足；哪些输出要收敛到审定句，哪些只能作为现实处境讨论？ |
| 虚岁遗漏、UTC 与北京时间/今天明天混用 | 13、15、20、25 | 日期与年龄如何使用强类型值和明确口径，而非让模型自由换算？ |
| 缺对方资料未有效澄清 | 14 | 多主体证据隔离和澄清如何由程序约束？ |
| 生育事件年龄未实现；医学边界回答也可能被误拒 | 16、18 | 有用事实与未覆盖判断如何部分交付？边界回答是否必须计算？ |
| 有当日历法但无具体活动宜忌规则 | 23–26 | 不应把拆卡/面试/出去玩自动变成吉凶概率或偷偷起卦 |
| 模糊问题可正常澄清，不能虚构取数失败 | 27、28 | “澄清成功”需要独立合约，不强制工具和预测 |
| 六爻候选竞争、奇门取用不足 | 29–32 | 保留事件输入和盘面，但不可把有盘当成成败结论 |

**判断：**已有缓存解决了一部分计算成本问题；稳定报告有望减少重复生成及证据漏接，但无法凭产品包装补出未审定的象义规则，也无法自动解决自由语言假接受。方案必须同时处理内容覆盖与证据编排。

## 4. 设计规范与现有品牌

- 活跃技术文档：`docs/README.md`、`native/README.md`、`docs/superpowers/specs/2026-09-18-swiftui-rebuild-design.md`。
- 视觉来源：`native/App/Design/SujiTheme.swift`、`native/design-qa.md`、`native/Documentation/overview.png`。overview 已实际查看，但为旧截图，**不是本轮真机/模拟器验收**。
- 纸色、墨色、鼠尾草绿与少量朱红；NotoSerifSC 标题、系统正文；支持 Dynamic Type。沿用纸页和日历，工具/导航可用现有材质，报告正文保持不透明可读纸面。
- `docs/superpowers/specs/2026-04-24-suji-product-architecture-design.md` 为早期历史背景，不是将旧 Expo 重新引入的依据。
- `docs/mingli/validation/product-architecture-critique.md`、`typed-reading-product-review.md` 提供既有概念和来源展示限制，不能替代本轮独立评审。

## 5. 九张参考图的实际观察

全部通过本地图像工具查看；未上传。只记录界面机制，不抄录截图中任何身份、生日、时辰或个人命盘。以下文件名对应用户提供的本地文件，前五张按用户说明属于爱占星，后四张可见测测标记。

| 文件名 | 可见观察 | 借鉴 / 反对 |
|---|---|---|
| `img_b7ef967b4d1a.png` | 本命、大运、流年、流月并列的专业柱表 | 借鉴时间分层；不让普通用户首屏承担所有层次 |
| `img_02e33b4f8afd.png` | 运/年/月多层时间表与节气标注 | 借鉴选择后深入；必须保留当前选择和北京时间说明 |
| `img_fea0227d9013.png` | 合冲关系用柱位连线表达 | 局部选择高亮比全量交叉线更易懂；须提供文本等价 |
| `img_0fa836d6fe85.png` | 日柱性格、格局参考、五行参考分块 | 分块有价值；长段人格判词及跨口径混合不可直接沿用 |
| `img_f735e55dd874.png` | 十二宫框架、中央资料、多种星煞 | 仅凭外形无法认定为紫微；不以更多术语证明专业性 |
| `img_a04b41861072.png` | 专业流盘与层层时序选择 | 专业层可探索；不是默认报告的视觉模板 |
| `img_c4a6cac4ce96.png` | 可读人物类型、格局/强弱说明、五行生克图、AI入口 | 借鉴可读性、图解与追问邻接；拒绝固定人格标签与未知依据的幸运配置 |
| `img_df714f916e3e.png` | 运期柱图点击深入、十神占比、AI细读 | 借鉴时间定位；拒绝无可解释算法的运势高低分；比例必须说明计数口径 |
| `img_67787734de83.png` | 神煞稀有度、分类评分、人格称号 | 不采用稀有率/人格分/成功率作为价值证明 |

图中“印化杀”与“杀邀食制”的表达差异无法在未知资料及流派口径下判断孰对孰错。以上不构成对竞品计算质量的判断。借鉴的是阅读层级，不是品牌视觉、文案或分数。

## 6. 证据边界

本目录方案中的数据实体、报告编译器、EvidenceBroker、字段级失效、主题覆盖状态、轻量图解、报告→问道上下文均是**拟议新增或改造**。目前只确认了可复用的代码基础，尚未证明新架构性能、可访问性、理解度和问答通过率。所有预算数字如出现均须标为目标/上限，不能写成实测。
