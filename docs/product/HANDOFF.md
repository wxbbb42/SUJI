# SUJI：远端 main 收尾交接

2026-09-23。**先读本页，再读方案；合并保存成果不代表产品验收通过。**

用户本轮授权为：提交已有相关成果、push、通过既有 PR/CI 流程合并远端 main，随后停止。下一步交给用户另一个 agent。**没有授权实施纠偏后的新方案，也没有授权部署 Supabase、发布客户端或继续付费矩阵。** 历史文档中的“不提交/不合并”是当时阶段边界，本次收尾授权仅替代该边界，未改变实验和失败的判定。

仓库：`https://github.com/wxbbb42/SUJI`。收尾分支：`codex/fix-mingli-today-activities`。保留检查点 `776b34f8bd515d53fd7567ebf278e29070750534` 及后续实验；以 PR 的 merge commit 和 Actions 读回结果判断是否已经合并，本文不把本地提交或构建成功等同远端完成或上线。

**当前合并阻塞**：[#9](https://github.com/wxbbb42/SUJI/pull/9)仍未合并。实现/测试头提交`a4944dd944721dd88a53e7d695bedddd32590d17`的[push CI](https://github.com/wxbbb42/SUJI/actions/runs/35881103577)为引擎/Core通过、原生UI 22项中21通过/1失败（hosted 61项、2skip、0失败）。大字号主题测试已通过出生资料入口，但在册页滚动寻找`theme.boundary`时失败，完整流程未获iOS 18验收；本机iOS 26.5通过不能代替。多次有限修正及全部失败见下方验证记录。收尾不绕过失败CI，远端main最后读回仍为`8164f25d12ffc246b9cead96cae64d6760098983`；接手当前成果需从PR分支开始，不能声称这些成果已在main。后续文档提交不改变该未解决代码状态。

## 接手顺序

1. [修订终稿 R2](2026-09-23-system-report-replan/proposal-final.md)：当前建议，**待用户确认、尚未实施**。结构为 `Profile → 我的册页 → 命理体系 → 体系内模块的易读个体结果/图解 → 专业档案`，不将自我观察/事业/感情改成基础报告一级栏目。
2. [参考观察](2026-09-23-system-report-replan/reference-map.md)、[产品评审](2026-09-23-system-report-replan/review-product.md)、[设计评审](2026-09-23-system-report-replan/review-design.md)、[技术/AI评审](2026-09-23-system-report-replan/review-technical.md)、[逐项采纳理由](2026-09-23-system-report-replan/review-decisions.md)。21项初评和2项复核的处理是计划修订，不是实现通过。
3. [第一阶段实现交付](2026-09-23-report-figma-revision/delivery.md)及[内容差距](2026-09-23-report-figma-revision/content-audit.md)。不要把已有导读当作达到测测颗粒度的报告。
4. [旧32题验收](../mingli/validation/reading-matrix-2026-09-22.md)、[逐题脱敏数据](../mingli/validation/reading-matrix-2026-09-22/per-question.json)，再读下方暂停实验。不要直接执行旧文档中的在线测试命令；需要新的明确范围与预算。

## 已有实现与暂停实验

| 范围 | 当前源码与实际状态 |
| --- | --- |
| SwiftUI册页基础 | [NatalReadingReportView](../../native/App/Features/Profile/NatalReadingReportView.swift)、[NatalReadingReport](../../native/Core/Sources/SujiCore/NatalReadingReport.swift)、[NatalReadingCatalog](../../native/Core/Sources/SujiCore/NatalReadingCatalog.swift)提供本地四体系阅读入口、来源/限制、独立专业档案；离线正文不依赖模型生成。属于基础导读阶段，不是新方案完整模块群。 |
| 问道诊断与取数 | [ReadingFactRequest](../../native/Core/Sources/SujiCore/ReadingFactRequest.swift)、[ChatSession](../../native/App/Services/ChatSession.swift)等保存取数、核验和逐题诊断改动。旧问题未整体修复。 |
| 可复用的隔离/存储底座 | [AppStore](../../native/App/Services/AppStore.swift)区分账号和出生代际，核对内层算法版本、剥除调用方缓存再注入当前可信档案；[ArchiveCodec](../../native/Core/Sources/SujiCore/ArchiveCodec.swift)外部导入保留历史正文、剥除主题授权字段。晚到响应、出生A→B→A与同值确认均有回归。 |
| 可复用的交接交互 | [NotebookNavigation](../../native/App/Design/NotebookNavigation.swift)、[ChatView](../../native/App/Features/Chat/ChatView.swift)、[SujiApp](../../native/App/SujiApp.swift)保留草稿、不自动发送、不打断回答，资料重建保留视图身份、账号变化隔离；输入区与底栏分区；收尾实际截图发现重复系统底栏，新增失败回归后，在各Tab内容明确隐藏系统栏；大字号输入框限制可见行数并保留内部滚动，避免长草稿挤掉阅读区。 |
| **暂停的生活主题实验** | [BaziLifeTheme](../../native/Core/Sources/SujiCore/BaziLifeTheme.swift)、[BaziThemeConversation](../../native/Core/Sources/SujiCore/BaziThemeConversation.swift)、[BaziThemeContext](../../native/App/Services/BaziThemeContext.swift)、[BaziLifeThemeCard](../../native/App/Features/Profile/BaziLifeThemeCard.swift)。主题是“表达与规则”，只做局部十神透藏解释和明确标记的现代编辑练习。**卡片仍在当前八字册页中显示，未删除、隐藏或重构；不代表用户批准的最终报告结构。**闭合模型动作选择实验不能替代完整命理解读。 |
| 尚未落地 | R2的体系模块数据合同、`LocalModuleProjection/LocalFactEvidence`、完整八字B1–B5个体模块群和新AI三入口。不能把现有主题协议改名视为完成这些工作。 |

主题内容的[来源/条件/反例](2026-09-23-bazi-theme-handoff/content-implementation.md)、[五份合成样稿](2026-09-23-bazi-theme-handoff/synthetic-samples.md)、[独立内容评审](2026-09-23-bazi-theme-handoff/review-content-implementation.md)、[技术评审](2026-09-23-bazi-theme-handoff/review-technical-implementation.md)、[设计评审](2026-09-23-bazi-theme-handoff/review-design-implementation.md)及[采纳记录](2026-09-23-bazi-theme-handoff/review-decisions.md)均随仓库提供。样稿是明确合成输入经过本地真实引擎计算，不是用户出生资料。

## 真实问答证据：失败维持原判

- **原32题：2通过 / 2澄清 / 10缺项 / 18失败。** 没有重跑，不能用新的小批或自动测试通过替换该结论。
- 主题线上实验：8个合成场景、19用户轮、19实际模型请求（原预算上限24，剩余未用并已停止）。[脱敏逐轮索引](2026-09-23-bazi-theme-handoff/live-before-fix.json)包含问题、工具、取数/协议/归档状态、请求用量和响应摘要哈希；不包含原始模型响应。导出时`contentVerdict=requires-independent-review`不等于后续内容通过。
- [独立内容分类](2026-09-23-bazi-theme-handoff/review-content-implementation.md)：8轮受限内容合格、2轮内容不足、3轮任务失败、4轮合理澄清、2轮预期保护/中断。通用内容价值主观5/10；这些均非预测准确率。
- **T01**明确要求模型追问却收到`none`，导致下一轮“方法”无上下文。正向约束已写、离线回归通过；真实修后复测暂停，仍不得改判。否定表达“举个例子，但不要问我问题”被正则误判为必须追问，仍未修。
- **T03刷新/T08**解释正文漏掉具体缺哪项，内容不足，未修。
- **T05**三个真实工具`get_domain/get_ziwei_timing/get_timing`成功，8次模型交互后仍核验拒绝：存在未经规则授权的年度行动引申，也有review协议/本地谓词及字段粒度错配。不能放开证据保护；该例也不能证明主题→动态多轮已跑通。
- **T07**第一次断网是人为注入；随后真实请求重试成功并复用回执。不能称为自然线上故障。
- [ReflectionSession](../../native/App/Services/ReflectionSession.swift)只补资料代际保护，旧自由解读旁路未整体统一核验。口语、否定表达、跨主题/跨年、多轮和所有云端冲突未全面验收。

原始响应、截图、xcresult、失败日志与私有配置在作者本地保留，**不随仓库提供**。历史文档中的`native/artifacts/...`和`/tmp/...`仅是当时本地证据位置，不能当成远端可读附件。接手不需要这些目录即可从上列脱敏结果、失败分析和可重跑测试理解状态；无法从哈希还原原始回复，也不能仅凭哈希独立重新评分。

## 收尾验证

当前收尾的逐项结果和可重跑命令见 [merge-validation.md](2026-09-23-system-report-replan/merge-validation.md)。CI在既有引擎、Core、原生三项基础上纳入全部hosted测试及册页/主题UI；在线专用测试必须显式提供临时账号配置，正常CI跳过，**未关闭生产核验**。

自动回归只证明所覆盖的计算/存储/交互合同。真机、人工VoiceOver、新方案UI及完整内容价值、主题真实修后复测、旧32题复跑均未验收。本轮不消耗新的模型预算。

## 下一位 agent 的边界

先向用户承接R2方案确认，再按确认范围推进。推荐的下一步是八字体系内B1–B5一组完整差异样稿和能力白名单，验证模块内容与规则边界，而非继续扩生活主题。中国二十八宿与宿曜关系不得混同，七政四余缺项不编解释；不同体系不拼总分。

保留全部历史失败和检查点；不要为了新方案删除旧证据、清理用户档案或绕过核验。任何后续部署/安装/付费实验须按新的任务授权执行。本轮仅保存和合并，随后停止。
