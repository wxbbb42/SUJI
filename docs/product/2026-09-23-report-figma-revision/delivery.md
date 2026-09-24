# Figma 补充方案与第一阶段实现交付

2026-09-23。以下区分实际实现、运行证据和仍未完成的目标；本机日志和原始失败记录保留。

## 结论及完成范围

采用用户要求的 Profile → 我的册页 → 专业档案结构。默认首页仍是有时纸日历，底部按可逆默认提供「今日 / 静心」及独立「问道」。已实施的是**可离线重建的基础读盘**：普通阅读页先解释，再按需看依据和专业字段。

这仍不是参考图全部生活主题的完成版。八字/紫微目前有真实位置、传统词义和条件化结构说明；性格、事业、财务风险、关系的综合内容库尚未闭合。星宿沿用中国二十八宿现代距星参照；七政覆盖排盘和安命，不补造宿曜关系、恩用财难、余奴或成功分数。实际内容差异及来源边界见 [内容验收](content-audit.md)。

## 方案与独立评审

- [冻结初稿 D2](proposal-draft.md)、[修订终稿 F2](proposal-final.md)、[内容合同](content-contract.md)。F2 覆盖前一轮 F1 的四底栏和仅文档阶段，沿用其事实/规则/解释分层。
- `/root/report_ai_critique`：完成 D2 技术评审 7 项、实施技术复核；写入 `review-technical.md` 和 `review-implementation-technical.md`。
- `/root/report_design_critique`：完成 D2 设计评审 9 项，实际查看线框及 18 参考屏；写入 `review-design.md`。
- `/root/report_implementation_design`：完成实际模拟器截图与实现评审 6 项；写入 `review-implementation-design.md`。没有将实现作者伪装为独立评审。
- `/root/natal_report_core` 与 `/root/natal_report_ui`：分别完成 Core、SwiftUI 实现；主代理核对代码、运行整合测试并修订。两位不算独立验收者。
- [逐项决定](review-decisions.md) 保留采纳、部分采纳、未完成原因。初稿及评审原文不覆盖；“采纳”不等于所有目标已完成。

第二轮修正了普通依据层直接显示 JSON/快照的设计、重复大标题、用户正文的程序术语，以及最大辅助字号底栏图标膨胀/标签断字。也修复了模拟器实际发现的整行入口留白不可点击问题。

## 实际代码

| 层 | 主要文件（仓库相对路径） | 改变 |
|---|---|---|
| 主导航 | `native/App/SujiApp.swift`、`native/App/Design/NotebookNavigation.swift` | 保留原 0/1/2 TabView 身份；Profile 独立容器，深层关闭回发起页面；键盘让位与收起动作 |
| 日常入口 | `Features/Today/TodayView.swift`、`Features/Chat/ChatView.swift`（位于 `native/App/`） | 右上我的；历史回顾移到日签区；旧去填写不再指向已删除的 tab 3；会话菜单保留 |
| 个人与阅读 | `native/App/Features/Profile/ProfileView.swift`、`NatalReadingReportView.swift` | 册页优先，出生资料、校时、日记、关系、设置可达；四体系范围标签、细读与依据、单一专业入口 |
| 确定编译 | `native/Core/Sources/SujiCore/NatalReadingReport.swift`、`NatalReadingCatalog.swift`、`NatalReadingAstronomy.swift` | 从当前可信快照生成稳定条目；必需字段、内部出生资料、十神/藏干、宫星/四化/方法校验；内置来源 |
| 回归 | `NatalReadingReportTests.swift`、`NatalReadingStoreTests.swift`、`NatalReadingReportUITests.swift` | Core、真实本地引擎/SwiftData 生命周期、原生多层往返与显示；旧 UI 路由同步迁移 |

报告不读旧 `personality` 当事实，不伪造工具回执，不调用 DeepSeek。ID 绑定 owner、完整出生资料、脚本版本、事实投影及内容/适配版本；UI 在异步加载后再次核对 scope revision 与资料身份。版本哈希是身份/损坏检查，不是外部快照真实性认证。

本轮没有新增 SwiftData 表或生产 migration。报告按当前档案重编，不新增历史报告原文仓库；既有聊天归档不被替换。

## 已实际运行的验证

日志与 `.xcresult` 在本机忽略目录 `native/artifacts/report-figma-2026-09-23/`，没有公开上传截图。

| 验证 | 实际结果 | 证据 |
|---|---|---|
| 修改前 Core 基线 | 488 项，1 跳过，0 失败 | `core-baseline.log` |
| 新编译器专项 | 最终 8 项，0 失败；真实本地 JS 合成盘 | `core-green.log`；最终整体内也重复覆盖 |
| 最终 Core 整体 | 496 项，1 跳过，0 失败；191.5 秒 | `core-final-2.log` |
| 原生数据/会话集成 | 36 项，0 失败 | `native-final-2.log` 中 `SujiTests.xctest` |
| 原生 UI 整轮 | 23 项，19 通过、4 失败；新报告 3 项当轮通过 | `native-final-2.log/xcresult` |
| UI 定向复测 | 9 项，8 通过、1 失败；此前 4 个失败已通过，大字号册页点击出现不稳定 | `native-final-3.log/xcresult`，原因和处理见下 |
| 册页最终复测 | 3 项，0 失败，145.4 秒；含修正的真实点击路径与新专业返回断言 | `native-final-4.log/xcresult`，xcodebuild 退出 0 |
| 按用例汇总最新结果 | 23 个相关 UI 用例、36 个原生集成用例的最新结果均通过；不是声称首次整轮全绿 | `ui-run-ledger.json` 保留每轮逐题状态 |
| 工程与旧工作保护 | 原工程对象无删除、无意外属性修改；原 scheme 相同 | `project-preservation.json`；`baseline.json` |
| 静态颜色对比 | 4 套纸色主题，ink/secondary/sage 对 paper/surface 为 4.53–14.52:1 | `contrast.json`，按 sRGB 相对亮度公式；不是系统材质或整屏像素审计 |

新增测试先在旧实现失败，保留 `core-red.log`、`ui-red.log`。还保留内层历法不一致、未知主星组合、JSON 布尔误等于数字出生字段的 RED/GREEN 记录。UI 第一轮暴露整行空白区不可点击，修复后四体系/专业往返和聊天草稿保留两项复测通过；大字号测试针对真实 Form 的懒加载行为增加滚动，未删除最终可见性或资料建档断言。

`native-final-2` 的四个失败分别为：大字号出生表单确认项尚未实例化就被旧 helper 跳过、归档展开组按整个内容框坐标点击而未命中标题、设置使用旧 label、账户子页未返回就查找 Profile。分别修正真实滚动与导航、按可见标题点击；未删除归档折叠后正文消失等断言。`native-final-3` 对应四项全部通过，并复核常规归档、日记/历史/分享、四体系来源及专业关闭回草稿。

`native-final-3` 新出现的大字号册页失败保留在结果中：录像第 36 秒仍停在个人页，册页入口上半部位于导航栏后，AX 树在失败时仍是“我的”，不是报告加载失败。测试仅查卡片 `isHittable` 就点击其遮挡的中心，随后错误地在个人页寻找并向下滚动 `report.summary`。已改为先把实际“我的册页”标题滚动至导航栏下方再点击，并立即断言进入册页；没有改变 App 数据或放宽结果断言。`native-final-4` 三个报告用例全部通过，包含新增的专业返回后紫微仍选中断言。

日志含聊天键盘出现时 `Invalid frame dimension (negative or non-finite)` 警告。当前受测输入、关闭、返回和草稿断言通过，没有据此观察到数据丢失；本轮未定位该系统布局警告的具体调用栈，不把它隐去或宣称已消除。另一次 `native-final-1` 因误写测试 target 而退出 70，未执行测试，不计作测试失败样本。

原生集成 36 项覆盖：新报告从已保存档案和归档导入的出生资料重建；改出生时刻后报告 ID/内容改变；跨账号不复用；A→B→A 恢复各自记录；既有慢请求/账号/归档安全；今日、六爻补充和起卦确认的现有会话回归。这些是本地集成与受控会话测试，**不是重新跑生产模型矩阵**。

可重跑最小本地验收：

```sh
bash native/scripts/test-natal-reading.sh <已启动的iOS模拟器UDID>
```

脚本仅选择新 Core / Store / UI 专项，不执行 LiveReadingSessionTests，不访问付费模型矩阵。整体回归命令及逐次结果保存在上述日志；脚本本身通过 `bash -n`。

## 未完成与限制

1. **内容价值尚未达到截图全部细解读。** 独立评审对首轮实现的主观评分：品牌 7/10、阅读层级 6/10、参考细解读价值 4/10。样稿条数和代码测试不应提高“内容完整度”评分。需要逐主题规则与文本审核，不能靠删边界、拼古文或泛人格句补齐。
2. **两项技术 P2 留存。** 本命内层声明版本尚未与桥接 metadata 的预期声明版本单独比较（外层 bundle digest 已匹配）；故障隔离仍为本命与天文两份 dossier，尚未拆到四模块。当前不接受外部报告/sidecar 导入，未来开放前需完善协议。
3. **不兼容档案的恢复。** 已修正错误说明，不再要求用户随意改出生资料；分类的一键重建机制未做。未知方法继续安全拒绝，不通过重试放宽验证。
4. **专业落点。** 八字/紫微带入原页体系；星宿/七政带入专业目录的体系说明和优先入口，但旧出生星历详情仍从顶部阅读，未做到定位某个天体/宿条目。
5. **尚未验证的体验。** 本轮未执行人工 VoiceOver 全流程、真实读者理解测试、真机安装、付费在线问答或生产登录后完整 UI 重建流程。UI 用明确合成的内存册页；生产未登录 gate 另测，不能冒称全部用户状态均覆盖。
6. **旧问道结果不变。** 32 题矩阵仍是 2 通过、2 澄清、10 缺项、18 失败。本地报告避免基础阅读依赖模型回信，不代表修好了全部自由问道、动态取数和证据核验。

## 工作区与后续决定

沿用 `codex/fix-mingli-today-activities`，起点和当前 HEAD 均为 `8164f25d12ffc246b9cead96cae64d6760098983`。对本轮开始保存的 1473 个路径做 SHA-256 比较，0 消失、0 非预期变化；只有 4 个原 App 导航文件、工程文件及 4 个迁移的旧 UI 测试文件变化（新文件另计），记录在 `baseline-final.json`。原有问答修复、矩阵和 ChatSession 等 dirty 原样保留。未提交、push、合并、部署或修改收费资源；没有新的 PR/CI 链接。

实际界面预览为本机 `native/artifacts/report-figma-2026-09-23/report-preview.png`（四张 `native-final-3` 模拟器截图拼接，未经生图）。`final-3-attachments/report-07-source.png` 与 `report-07b-raw-fields.png` 已人工查看，普通层无 locator/pointer，二级仍可见原字段；`final-4-attachments/` 的 `report-05b-returned-ziwei.png`、`report-12-large-bazi.png`、`report-11-large-shell.png` 也已实际查看，返回选择、大字正文、底栏名称与深色截图可核对。原截图、录像和 xcresult 保留，截图均为合成测试资料。

收尾检查：`git diff --check`、`bash -n native/scripts/test-natal-reading.sh` 通过；本目录 31 个本地 Markdown 链接均可解析。工程 preservation 结果未变化；未改动原 scheme。

底部页面按「今日 / 静心 + 问道」是可逆默认，Figma 没有文字标签，未声称用户已确认。下一段建议先补八字一个、紫微一个完整生活主题的来源—条件—反例—样稿—独立审核链，再扩展；宿曜方法是否另加与七政角色流派仍需明确后才做。既有中国二十八宿选择保持不变。
