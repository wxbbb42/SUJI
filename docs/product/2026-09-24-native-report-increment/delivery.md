# 原生底栏与八字易读报告增量

2026-09-24。工作分支 `codex/native-tabs-readable-report`，起点 `8e04c22`。本轮按用户“原生 Liquid Glass + 继续优化我的册页易读解读”推进；没有部署、发布、安装真机或发起付费问答矩阵。

## 用户能得到什么

### 原生导航

旧实现虽然用 `TabView` 保留页面身份，却在子页面和根节点主动隐藏系统 TabBar，另画 `NotebookTabBar` 胶囊，并手动监听键盘显隐。因此没有采用系统 Liquid Glass，也有两套安全区域处理。

现在由系统 TabBar 管理主页、静心、问道三个入口、选中态、键盘与安全区域。iOS 26 及以上采用系统玻璃呈现，较旧系统采用其原生外观；没有模拟玻璃贴图。保留现有账号/出生代际、页面选择和 Profile 路由。

随后用户确认“主页＋静心在左、问道独立在右”的方案：iOS 27 使用官方 [`TabRole.prominent`](https://developer.apple.com/documentation/swiftui/tabrole/prominent)，右侧由系统显示为独立图标；iOS 26及更早版本仍是完整原生TabBar，顺序改为主页、静心、问道。保持原有selection值：主页0、静心2、问道1，避免把保存的问道状态误映射到静心。没有借用 `.search` 角色，也没有增加自绘导航。此次增量只修改应用导航与对应UI验收，不改报告规则/模型或账号数据。

修改：[SujiApp.swift](../../../native/App/SujiApp.swift)、[NotebookNavigation.swift](../../../native/App/Design/NotebookNavigation.swift)。

左右分组代码的后续验收（19:32完成）：实际SUJI应用在iOS 26.5模拟器上的原生导航/顺序/草稿用例1项通过；iOS 27.0模拟器上3项通过，覆盖原生分组间距、Tab切换草稿、册页/专业档案返回及早期专题问道交接返回。两次命令退出码均为0，证据在本机忽略目录 `native/artifacts/native-tabs-split-2026-09-24/ios26.log`、`ios27.log` 与同名xcresult。已查看两代系统截图，iOS 27主页/静心左分组和右侧问道由系统呈现，输入区未被底栏遮挡。当时尚未提交/推送或安装手机；后续合并准备与最终回归见文末。本次没有重跑线上问答矩阵。

### 易读报告

保留 `我的 → 我的册页 → 命理体系 → 专业档案`。八字默认从逐柱词条改为一组可顺读模块；紫微、中国二十八宿、七政四余仍保留原有范围，本轮未扩充其断语。早期“表达与规则”专题移到末尾折叠，旧会话的返回入口继续展开它，不把生活主题作为报告一级结构。

| 模块 | 本轮实际内容 | 边界 |
| --- | --- | --- |
| 日主与月令 | 说明此盘的参照点、月支本气及相对十神，提供简明关系行 | 结构导读，不从日干直接判人格；不混入月内司令 |
| 五行关系 | 由日主推导生入/生出关系，列出盘中实际位置；未见的位置单独说明 | 关系图不是力量图；不从缺项推“补某元素” |
| 十神分布 | 区分天干、支藏、共同出现和仅支藏关系，解释为何部分透干规则不能套用 | 不是十神人格分数、职业或收入测量 |
| 格局配合 | 月令候选的选取原因；通过来源、柱位、根气和依赖链复核后，给局部可用/被牵制/未决的不同解释 | 仅所选普通格与局部规则；不推全局成败。三合三会代理及特殊格候选暂不在本页解释子集 |
| 强弱与取用 | 可复算的固定权重参考，与格局取用分开解释；相同元素也不算互证 | 未综合月令、根气和调候，不能称完整传统旺衰或幸运元素 |

每块默认显示结果、简明关系和重要限制；长解释、来源、原始字段逐层展开。专业原盘是独立入口。这里的图解是有文字等价的关系示意，尚不是竞品完整交互图谱。

**当前可称“结构与局部配合增量”，不能称已经达到测测的完整个体报告深度。** B1/B2/B3/B5仍主要是结构/方法解释；B4的部分组合才有条件驱动的个体差异。不能用五个标题或更好排版掩盖这个差距。

## 为什么基础报告可以不依赖 AI

输入出生资料后，本地引擎生成本命事实；固定版本的规则核对适用条件；经审核的文字按命中的条件组合。AI不负责发明基础结论。这样报告可重复、可离线阅读，解释差异能追溯到盘面差异。截图无法证明测测内部是否采用AI，本方案也不依赖这一猜测。

本轮实现位于 [BaziReadableModules.swift](../../../native/Core/Sources/SujiCore/BaziReadableModules.swift)。它消费已通过账号/资料/算法版本核对的原档案，使用纯值投影复用本地验证器；没有创建 `ToolReceipt`、callID或工具执行历史。证据仍指回 `/mingPan/...`。报告版本更新为 `natal-module-reading-2026-09-24-v2`，不修改引擎算法版本、聊天协议或在线核验策略。

未知取格方式、取用与实盘不一致、来源哈希错误或救应状态被篡改时，只降级相应模块。可选强弱结构缺失时不再使八字/紫微整册消失。资料和账号隔离沿用原有合同。基础事实本身不可信时仍由原档案验证拒绝，不允许绕过。

## 内容来源与合成差异

- [子平真诠评注：用神、相神](../../mingli/source-texts/bazi/ziping-zhenquan/00-abstract-chapters.md)，SHA256 `5b930c11310899b50703696870d9024ba4e00fca6ad177e57d6fa5e3f8a4964f`。
- [子平真诠评注：基础与合而不合](../../mingli/source-texts/bazi/ziping-zhenquan/01-foundations.md)，SHA256 `8ea626e3744bb7129351b57dd3c4d6b6be595484345d8ea8101df50611993596`。
- [structural.ts](../../../native/Engine/src/bazi/structural.ts)的 `selectYongShen/geJuName` 是本页所采用的选择顺序；这是具体算法口径，不声称所有流派统一如此。
- [BaziPatternConditionTrace](../../../native/Core/Sources/SujiCore/BaziPatternConditionTrace.swift)、[BaziAdjudicationTrace](../../../native/Core/Sources/SujiCore/BaziAdjudicationTrace.swift)、[BaziRescueDependencies](../../../native/Core/Sources/SujiCore/BaziRescueDependencies.swift)核对具体来源、条件和局部依赖。电子转录含原文与评注，尚未与纸本逐字校勘。

[六份合成样稿](synthetic-samples.md)全部由本地真实 JS 引擎生成，不来自真实用户或截图。前三份具有相同取格候选，但局部作用分别未决、可用、被阻断；第六份解释“月支本气为食神，为什么格局候选取中气透出的偏财”。它们用于检查差异的原因，不代表人口覆盖或预测有效率。

重跑样稿（无账号、无模型费用）：

```sh
sh native/scripts/generate-readable-module-samples.sh
```

## 独立评审与采纳

- 内容：`/root/readable_report_content_review`，见[基础评审](review-content-foundation.md)及[实现评审](review-content-implementation.md)。
- 技术：`/root/native_report_technical_review`，见[技术评审](review-technical.md)。

| 发现 | 处理 |
| --- | --- |
| 候选名和取用仅互相一致，没有绑定月令选取 | 采纳：复算所支持的透干优先链、回退条件及精确禄刃命名；未知/缺失basis拒绝，三合三会代理明确暂不解释 |
| 可选 `riZhuStructure` 缺失导致整册throw | 采纳：该方法模块降级，其余八字与紫微保持可读；增加单字段负例 |
| “完整条件”暗示覆盖全部；空结尾 | 采纳：只称“已核对的部分条件”，无内容不显示该段 |
| 摘要与详情重复 | 采纳：摘要给结果，详情给选取原因及已验证的根/合条件；不重复拼接整段概要 |
| 删重复时连具体根/合原因一起删掉 | 采纳复评：保留一次验证器提供的部分条件，避免只剩状态标签 |
| 整份报告仍缺完整个体解释 | 保留限制，不强行写人格结论；下一步应扩组合规则和经反例审核的解释，不优先扩页面 |

## 验证与剩余工作

已执行的结果（截至 2026-09-24 19:15，iPhone 17 Pro / iOS 26.5 模拟器）：

| 检查 | 实际结果 |
| --- | --- |
| 系统TabBar失败→修复 | 新测试先因原生TabBar不存在失败，恢复系统栏后同题通过 |
| 报告审查反例失败→修复 | 3个定向测试先报15处断言/错误（含缺字段整册throw）；修复后同组通过 |
| Core整体回归 | 521项中520通过、1跳过、0失败；跳过项为需要既有48组容量矩阵文件的探针，本轮未提供该文件 |
| 最终正文与旧主题兼容 | 最后一次文字调整后，14项报告＋19项主题相关Core测试，共33项全部通过；六份样稿同步重新生成 |
| 原生存储、账号/出生代际、旧会话 | `NatalReadingStoreTests` 2项、`NatalIdentityRevisionTests` 5项、`BaziThemeSessionTests` 6项，13项全部通过 |
| 最终交互定向复测 | `report-interaction-final.log` / `.xcresult`：3项全部通过，退出码0；深色细读/示例/来源与问道、草稿交接返回、B4/B5连续展开收起后进入专业档案；耗时197.247秒 |
| 差异卫生检查 | `git diff --check` 通过；该阶段尚未提交、未推送，后续合并准备见文末 |

整体Core回归在最后补回“部分条件”文字前构建；该最后变更由33项定向回归覆盖。两次Xcode启动问题也保留：早期移除键盘变量后有一处遗留引用，已修复；后续首次回归命令误用了目录名 `SujiAppTests`，实际target为 `SujiTests`，修正命令后运行，没有删除或跳过目标测试。

可重跑命令：

```sh
swift test --package-path native/Core
swift test --package-path native/Core --filter 'NatalReadingReportTests|BaziLifeThemeTests|BaziThemeConversationTests|BaziThemeAnswerTests'
xcodebuild -project native/Suji.xcodeproj -scheme Suji \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath native/DerivedDataTheme -parallel-testing-enabled NO \
  -only-testing:SujiTests/NatalReadingStoreTests \
  -only-testing:SujiTests/NatalIdentityRevisionTests \
  -only-testing:SujiTests/BaziThemeSessionTests \
  -only-testing:SujiUITests/NatalReadingReportUITests \
  -only-testing:SujiUITests/BaziThemeHandoffUITests test
```

首轮完整原生回归中，13项hosted通过，UI为7通过/2失败（`report-regression-2.log`）；两处失败都在旧 `nav.chat` 标识查找。已将公共导航测试辅助和直接调用改为通过原生 `TabBar` 角色/标题查找，保留所有原断言；两条失败流程复测通过。新增的报告展开检查首次失败于未滚动便断言懒加载的格局模块存在，已修正滚动定位与导航栏遮挡判断。

期间磁盘一度仅剩127MB。清理了4个旧DerivedData目录内可重建的编译中间件/模块/索引缓存，未删源码、Build/Products安装包、原始证据或本轮活跃构建目录。测试结果中仍有 `Invalid frame dimension (negative or non-finite)` 运行警告，本轮未定位来源，不把功能断言通过等同没有运行警告。

已实际查看模拟器浅色/深色册页、问道草稿与原生TabBar截图：专业入口与范围说明可见，原生底栏没有压住输入框。

展开专项另发现真实运行问题：依次展开B4/B5后，App主线程持续占用CPU，采样位于SwiftUI `LazySubviewPlacements` / `AttributeGraph`，屏幕停在B5展开前。本机保存了采样及截图，手动中断该卡住的测试（不记通过）。报告章节数量有限，改用普通 `VStack` 预先确定尺寸，保留章节ID、阅读位置及目录跳转；同题已于 `report-layout-fixed.log` 通过。这与先前导航标识/懒加载定位的测试辅助问题分开记账。

随后关联回归 `report-layout-regression.log` 为2通过/2失败：四体系来源与专业档案返回草稿通过；旧专题在折叠容器展开后，屏幕可见但AX区域不能命中。保留失败日志和截图，旧专题容器已改为显式展开按钮与条件挂载，保留44pt点击范围、展开状态、旧会话锚点。最终复测同时增加B4/B5收起后返回专业档案的断言，检查页面确实继续响应。`report-interaction-final.log` 中三项分别为85.606秒、65.076秒、46.565秒，全部通过；未删除原命中、草稿保持与导航断言。

本轮分阶段共运行12个不同的UI用例，每条最后一次记录均通过；**这不是最终源码上的12项统一全量运行**。最后修改的旧专题展开层由最终3项定向复测覆盖；四体系/来源与专业档案返回由前一组覆盖，原生底栏与草稿、登录门禁、出生代际和切换模式由此前分组覆盖。不把重复重跑累计成更多独立场景，也不把中断与失败记录抹去。

实际导出并查看最终附件：`theme-02-handoff-draft` 中原生底栏与草稿无重叠；`theme-07-dark-return`、`theme-03-returned-report` 中细读内容和返回状态保留；`report-15-methods-scope` 中方法说明与限制可见。`theme-04-dark-reading` 抓到了展开文字过渡的重影，后续稳定返回附件没有该重影；本轮不据此声称所有动画帧均已验收。读屏人工测试未执行。

本机原始日志、xcresult和截图保留在忽略目录 `native/artifacts/native-report-2026-09-24/`，不是远端公开附件。样稿与评审是仓库内可复核文字。本地构建成功不等同已装到用户手机。

历史真实问答结论维持：**原32题为2通过、2澄清、10缺项、18失败**。前一轮主题真实实验中的内容不足和任务失败也没有被本轮本地测试改判。没有重跑线上DeepSeek，本轮不宣称修复所有AI误拒或漏取数。

不在本轮验收范围：完整四体系个体解读、动态大运流年模块、新的模块级AI上下文协议、真机安装、人工VoiceOver、大字号专项，以及竞品预测准确率比较。原始竞品截图缓存本轮已缺失，Figma图片资源受到浏览器拦截；参考结构依据既有已保存的映射，本轮不声称重新逐张验图。

下一步应以八字一个完整可解释组合为单位建立“来源→条件→冲突/未决→易读正文→反例→审核”的内容包，再逐步扩充，保持体系内模块结构。继续问需另行将模块ID、事实/规则ID、主体、资料代际和版本接入现有生产核验，不能只把整篇报告塞入prompt。

## 合并准备与最终本地复核

用户随后授权提交、推送并合并远端 main。交付文档随此次提交进入 PR；最终提交、合并状态与 CI 结果以对应 PR 和 Actions 记录为准。此授权不包含部署、发布或手机安装。

为兼容现有 macOS 15 CI 的较旧 Xcode，`.prominent` 同时使用 `#if compiler(>=6.4)` 和 iOS 27 运行时判断；旧工具链构建普通原生底栏。新版 SDK 的左右分组断言使用相同编译条件，没有移除普通底栏顺序、草稿和安全区域断言。

最终源码于本次合并准备期间重新验证：

- `TZ=America/Los_Angeles swift test --package-path native/Core`：521 项，520 通过、1 条容量矩阵探针按原条件跳过、0 失败；退出码 0，271.919 秒。
- iOS 27 `testSystemTabBarOwnsNavigationAndKeepsDraft`：1 项通过、0 失败，退出码 0，41.430 秒。覆盖编译条件后的实际分组、切换与草稿保留。
- 本机证据位于忽略目录 `native/artifacts/native-report-merge-2026-09-24/`，不视为远端可访问附件。CI 的完整原生与引擎回归需由 PR 检查另行确认。
- 最终独立只读审查 `/root/native_tabs_merge_review` 未发现新增 P0/P1/P2 阻断项；审查涵盖原生 Tab 值与账号 scope、模块来源/候选/局部规则核验、旧专题返回、公开交付资料。审查没有替代旧 SDK CI 或真机验收。

本次提交不包含原始在线响应、真实用户出生资料、密钥、截图或构建产物。前述内容深度不足、历史真实问答失败、运行时尺寸警告及人工验收边界均保留。

### CI 暴露的既有限流测试边界

首个推送的 engine 作业在 `supabase/tests/quota.test.mjs` 失败：20 次请求预期恰好允许 12 次，实际 13 次，日志结束于 UTC 12:19:00。生产函数按 `date_trunc('minute', now())` 重置窗口，而测试把每次调用作为独立事务，未保证它们位于同一分钟；跨分钟允许额外请求符合该固定窗口语义。同一提交的 PR 作业随后通过该检查，保留两次结果，不把首个失败抹去。

跟进仅调整测试：把这组 burst 放入同一 PGlite 事务，利用 PostgreSQL 事务内固定的 `now()` 验证单窗口配额；后续分钟/日期重置、账号隔离、RLS 和全局额度断言保留。PGlite 本来串行执行查询，该测试不代表真实多连接并发压测。未修改生产 SQL、限额或 Supabase 部署。本地完整 Supabase 测试 15 项全部通过、0 失败，退出码 0；日志在本机忽略目录 `native/artifacts/native-report-merge-2026-09-24/supabase-quota-fixed.log`。新的远端检查需在跟进提交上重新完成。
