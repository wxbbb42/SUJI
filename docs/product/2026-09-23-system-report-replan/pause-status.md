# 纠偏时的工作区与验证封存

> 本文为暂停时快照；后续收尾授权及最新回归见 [交接入口](../HANDOFF.md)。不以新的收尾回归改写下列线上失败。

2026-09-23。用户最新要求优先于旧主题执行任务：**暂停生活主题扩展，只修订计划与独立评审，等用户确认。** 本记录不表示当前代码已经完成验收。

- 分支：`codex/fix-mingli-today-activities`。
- HEAD/已完成检查点：`776b34f8bd515d53fd7567ebf278e29070750534`，`checkpoint: preserve reading diagnostics and local natal report`。
- 检查点之后的主题实现、会话/资料隔离、测试与评审仍在工作区，尚未提交。没有删除、reset、stash、回滚、amend、push、merge、发布或安装。
- 新源码冻结指纹保存在本机忽略目录 `native/artifacts/report-direction-correction-2026-09-23/source-freeze.json`。记录1278个非docs文件的SHA-256，用于核对本轮只改方案/评审文档；原始线上响应、截图、旧构建证据不纳入Git。
- 已启动的两个测试已安全结束，只读回结果；停止剩余线上复测，不消耗旧预算剩余5次，也未启动纠偏后实现。

## 截止暂停的真实结果

| 范围 | 结果 | 限制/证据 |
|---|---|---|
| 最新Core全量 | 516项，1skip，0失败 | `native/artifacts/bazi-theme-2026-09-23/core-final-4.log`；194.9秒。是旧主题在制品的本地回归，不是新报告验收 |
| 单变量键盘定向UI | 1项通过，38.4秒 | `keyboard-experiment-2.log/.xcresult`；出生资料重确认保草稿。没有补跑完整5项UI或旧布局相关整轮，不能称整体UI全绿 |
| 前一次hosted | 61项，2在线专用skip，0失败 | `native-ui-final-4.log`；在“明确追问不允许none”最后修复之前，不冒称最终全部实现回归 |
| 后端回归 | 15/15 | `backend-regression.log`；本轮没重新跑 |
| 真实Supabase→DeepSeek | 8场景、19轮、19模型请求；预算上限24 | `live-2/report.json`；临时账号和配额行清理读回成功；T07初次中断为人为注入，随后重试是真实请求 |
| 19轮独立内容分类 | 8受限内容合格、2解释不足、3任务失败、4合理澄清、2预期保护/中断 | 见旧主题独立内容评审，不将这五类汇总成预测准确率 |
| 原32题矩阵 | 2通过、2澄清、10缺项、18失败 | 未重跑，原判不变 |

真实逐例脱敏索引：[live-before-fix.json](../2026-09-23-bazi-theme-handoff/live-before-fix.json)。内容评审在 [review-content-implementation.md](../2026-09-23-bazi-theme-handoff/review-content-implementation.md) 的“真实19轮内容验收”部分；技术评审在 [review-technical-implementation.md](../2026-09-23-bazi-theme-handoff/review-technical-implementation.md)。索引的`contentVerdict=requires-independent-review`为导出时状态，以上独立评审才是后续人工分类；没有用自动状态覆盖失败。

## 必须保留的问题

1. T01模型忽略“请问我一个问题”，下一轮“方法”无法承接：已写正向约束修复、Core通过，但真实修后复测暂停，**不能改判通过**。
2. 技术评审发现否定反例“举个例子，但不要问我问题”会被正则当成必须追问，尚未修复。
3. T03刷新/T08缺项解释的主回复漏掉具体缺哪一项，独立内容验收为不足，未修复。
4. T05有`get_domain/get_ziwei_timing/get_timing`真实结果，仍因自由稿个体引申缺规则、核验模型与本地谓词合同问题而最终拒绝。不是没取数，也不能称保护过严就放行。该例是首轮动态题，未证明真实多轮跨话题交接。
5. 旧主题只覆盖局部结构与现代沟通练习，独立内容实用性5/10，不能成为用户要求的体系基础报告替代品。
6. `ReflectionSession`自由解释旁路未整体重做；完整UI、人工VoiceOver、真机、新方向的内容样稿与真实多轮链均未验收。

本轮新增计划和独立评审不关闭这些问题；确认新方案后才决定哪些基础能力迁移、哪些表现层撤出默认路径。旧实现保持原样，避免边讨论方向边改坏现有工作。

## 文档收尾检查

纠偏后对1278个非docs工作文件重新计算SHA-256，0变化、0删除、0新增非docs受版本管理文件；HEAD仍为上述检查点。新文档的本地链接检查0缺失，`git diff --check`及逐个新Markdown的whitespace检查无告警。结果保存在本机忽略目录`native/artifacts/report-direction-correction-2026-09-23/plan-validation.json`。这些仅证明工作保留与文档一致性，不是新功能测试。
