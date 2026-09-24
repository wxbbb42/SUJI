# 个人册页与确定报告 Implementation Plan

> For agentic workers: 使用 subagent-driven-development 分离Core报告和原生界面；主agent整合、验证与评审。用户要求保留现有分支/dirty，故不建丢失未提交工作的worktree，不commit/push。

**Goal:** 简化导航，提供不依赖AI且有字段/来源/边界的细粒度个人读盘。
**Architecture:** 纯Swift Core compiler消费当前可信本命快照；SwiftUI呈现，JS引擎保持原样。完整生活主题与闭合AI问答不是本次可以冒称完成的内容。
**Tech Stack:** SwiftUI、SujiCore、现有SwiftData/AppStore、JavaScriptCore。
**Spec:** `proposal-final.md`（独立评审后修订）、`content-contract.md`；D2冻结不覆盖。

## 全局约束

- 分支 codex/fix-mingli-today-activities；起点HEAD 8164f25d12ffc246b9cead96cae64d6760098983。
- 禁止业务外改动、付费模型矩阵、生产部署、提交/合并/发布。原有ChatSession等dirty不动。
- 不用personality/历史聊天作证据，不伪造ToolReceipt。未知字段/方法不能默认正常值。
- 失败测试先行，真实本地JS合成资料；截图资料不进入fixture。
- 第一版明确“盘面导读”，四体系覆盖不同；生活主题未审定不显示成已实现。

## Task 1 · 确定报告Core

Create `native/Core/Sources/SujiCore/NatalReadingReport.swift`（结构/入口/验证）及按需要拆出的 `NatalReadingCatalog.swift`（文案/来源）、`NatalReadingAstronomy.swift`（星历说明）。Test `native/Core/Tests/SujiCoreTests/NatalReadingReportTests.swift`。

接口约定：
```swift
public enum NatalReportSystem: String, CaseIterable, Sendable { case bazi, ziwei, mansions, qizheng }
public struct NatalReadingReport: Identifiable, Sendable, Equatable {
  public let id: String
  public let system: NatalReportSystem
  public let title, summary, boundary, contentVersion: String
  public let entries: [Entry]
  // Entry: id,title,summary,explanation,boundary,reflection:String?; evidence:[Evidence]; sources:[Source]
  // Evidence: pointer,value:String。Source: id,title,locator,note:String; url:String?
}
public enum NatalReadingCompiler {
  public static func natal(dossier: NatalDossier, ownerID: String, birth: BirthProfile, engineRevision: String) throws -> [NatalReadingReport]
  public static func astronomy(dossier: NatalAstronomyDossier, ownerID: String, birth: BirthProfile, engineRevision: String, enginePayloadRevision: String) throws -> [NatalReadingReport]
}
```
若实现需要调整接口先通知主agent，不边写边让UI猜。API验证dossier.matches和专用字段schema后编译。ID对snapshot+contentVersion+system稳定；局部entryID对事实位置固定；id不授予导入可信性。

- [x] RED：先写编译器测试并运行，确认缺新API失败。用MingliBridge执行command:natal真实计算2份合成出生资料；同输入输出相同，不含当前日期。
- [x] GREEN：八字逐柱透藏、五类关系分组与结构说明；日干不计为额外比肩；未知十神/干支/空藏干报invalid；词义不升级生活断言。
- [x] GREEN：紫微12宫条目、主星象义、真实生年四化；多星并列、空宫不借星落宫、未知星保留事实并声明未解读或局部不支持；不得把传统角色误作实际落宫。
- [x] GREEN：月宿、七曜/四余性质、宫主与度主链条；方法/缺值严格检查。
- [x] 反例/边界：换owner、生辰、engine拒绝；输入损坏/未来method/缺字段拒绝；不生成恩用财难仇、宿曜配对、健康/财富结论；不同合成资料可追踪不同字段。
- [x] 运行Core专项与整体，记录结果，不编造内容专业通过。

## Task 2 · 原生导航与报告呈现

Modify `native/App/SujiApp.swift`, `Features/Profile/ProfileView.swift`, `Features/Today/TodayView.swift`, `Features/Chat/ChatView.swift` 的纯导航位置，按需要新增 `Design/NotebookNavigation.swift` 和 `Features/Profile/NatalReadingReportView.swift`。现有dirty ChatSession不改。Project由root在代码完成后更新。

- [x] RED：新增 `native/UITests/NatalReadingReportUITests.swift`，迁移已有受影响UI测试的我的tab路径；先运行新流程测试验证当前缺入口失败（root协调一次Xcode生成）。
- [x] Root保留3个tab数字身份，隐藏默认bar并用底部两胶囊（含文字/selected trait）控制；使用真实TabView保留聊天草稿/静心状态，不用switch每次重建页面。
- [x] Profile右上进入独立导航容器；关闭回原页面；ChatView旧selectedTab=3改为打开Profile。通知仍选今日且关闭Profile。
- [x] Profile是个人导航列表；我的册页打开基础报告，不先显示出生时间/大表格；出生资料独立编辑；已有日记、设置、关系、校时可达。
- [x] Report模块四项可换行。摘要/重要限定常显；条目细读/依据折叠；单一专业档案进入既有四柱紫微、出生星历、运限。
- [x] report的显示identity绑定scope+完整birth+engine，旧task结果不能落入新scope；尚未建档/重建失败/星历加载各自清楚，不能缺值作0°。
- [x] 不添加虚假的“带依据AI续问”入口；旧独立问道可达，AI交接协议单列未来依赖。
- [x] 44pt触控、Dynamic Type、纸墨token、深色、VoiceOver标签/顺序；键盘时底部导航不遮composer。

## Task 3 · 主agent整合与验收

- [x] 审查Core与UI边界、源引用，修复评审P0/P1具体bug；记录生活解释缺口不冒称验收。
- [x] 用`python3 native/scripts/generate-project.py`前后比较原pbxproj dirty，确保已有源文件/配置未丢；如出现不相关覆盖只定点追加文件。
- [x] `swift test --package-path native/Core`，Xcode原生build和相关hosted/UI测试；不变JS业务不重复全引擎付费/网络测试。
- [x] 模拟器light/dark/最大字号/四模块/专业入口截图已取得并实际查看；资料修改的身份和重建由Store集成测试覆盖。
- [x] 最终定向UI复测收尾与截图复核（见delivery）；final-3保留1次大字号点击失败，修正真实标题点击后final-4三项全过。
- [ ] 人工VoiceOver、真实用户理解测试与生产登录后的资料重建UI流程未完成，不以合成fixture覆盖替代。
- [x] 请求独立实现复核并记录采纳；最终baseline核对在delivery中单列。
- [x] `delivery.md`补录最终UI复测/截图/本轮baseline结果，README连到所有方案/评审；不commit/push。


勾选表示该实施步骤已执行，不表示四体系生活主题或人工可访问性验收已完成。UI最终结果以delivery为准，保留每轮失败及修正记录；计划不能代替实际测试日志。
