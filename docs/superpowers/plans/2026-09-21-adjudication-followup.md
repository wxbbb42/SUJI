# 三项裁定缺口续修实施记录

> Execution: source review and TDD per independent domain, followed by shared integration and whole-branch verification. Continue the existing checkout; the user explicitly authorized execution.

**Goal:** 实现六爻事件方向、奇门专门取用、八字竞争救应中有原文支持的裁定，并在原生解释、保存和回放中保留完整条件及未决边界。

**Architecture:** 延续 TypeScript 确定计算、Swift 独立核验和固定回执链路；新增裁定层不改写旧结构事实。规则来源携带版本、原文位置与散列，支持的充分条件与现实预测结果严格分开。

**Tech Stack:** TypeScript/Jest、Swift/JavaScriptCore/XCTest、SwiftUI、既有 Supabase 请求校验。

**Spec:** 用户本轮明确要求及 `docs/mingli/validation/adjudication-integration-2026-09-21.md` 的剩余三项范围。

## 共同约束

- 起点 `1a55f46809d16eddf2537cb891ec25ed0d40f800`；`codex/mingli-validation` 工作区起初干净。
- 不合并 main、不发布、不清理他人文件；独立领域只改其拥有的文件，公共接入由主任务统一处理。
- 每项先有行为失败，再实现并记录通过；正例、反例、冲突与边界均需包含。
- 不编造力量分数、无来源优先级或必然事件结果。不能仅把全局未决改名作为实现。
- 旧记录仍可核对；新记录缺来源、被篡改或缺必要条件时不得按旧格式降级通过。
- 不放宽请求容量上限、不丢弃来源/条件/候选；真实用户资料不用于测试。

## 任务 1：六爻事件方向与元忌传递

Owned: `native/Engine/src/divination/`、`Liuyao*.swift`、`Liuyao*Tests.swift` 与领域来源记录。

- [x] 核对《增删卜易》元忌衰旺、月将、两现等既有归档，绑定原文与可适用条件。
- [x] 正例：明确事体与对象、干净充分条件；反例：用神不能受生、元神自身受阻；冲突：多对象异向或残留克制；边界：缺事件/对象/条件。
- [x] 添加独立 `eventAssessment`；旧 `efficacy` 保留。枚举传递边与所有剩余制约，不凭第一候选定成败。
- [x] Swift 从原爻和来源复核，展示所选规则内方向及未决项；修改裁定/来源必须被拒绝。

## 任务 2：奇门专门取用

Owned: `native/Engine/src/qimen/`、`Qimen*.swift`、`Qimen*Tests.swift` 与领域来源记录。

- [x] 核实所选书派的专门取用原文，明确事件范围及同名星门神的对象身份。
- [x] 添加显式取用输入和结果；由用户确认的专门类别触发，不从任意自由文字猜测。
- [x] 正例、类别不符反例、中宫/寄宫与多处冲突、缺少上下文边界均覆盖。
- [x] 支持的新取用进入原生阅读与原盘补问；无依据的合冲侧或外应继续逐项说明原因。

## 任务 3：八字竞争救应

Owned: `native/Engine/src/bazi/`、`Bazi*.swift`、`Bazi*Tests.swift` 与领域来源记录。

- [x] 将已有局部路径接成可审计的依赖/竞争裁定；核对根、合、护相与明示源例。
- [x] 正例：足够条件下确定可用路径；反例：唯一相神受阻；冲突：相对力量未知或循环；边界：有根、争合、日主自合和藏透区别。
- [x] 输出每一病点的路径、可证阻断及仍依赖条件；只有完整支持时才给所选范围结论。
- [x] Swift 独立复核新结果；`natal`/`profile`/`get_domain`、解释和档案保存保持一致。

## 任务 4：公共原生与请求接入

Owned by root: `native/Engine/bridge.ts`、`src/ai/tools/`、`CastQuestionPreparation.swift`、`CastQuestionBinding.swift`、`CastSupplement.swift`、`ReadingVerificationEvidence.swift`、`ReadingContext.swift`、确认 UI 及公共测试。

- [x] 按领域最终接口更新 schema/dispatch 和确认输入；模型建议不等于用户已确认。
- [x] 补问仅允许重算新问题依赖字段，原爻、原宫、时间及来源绑定仍受保护。
- [x] 闭合证据索引包含新裁定全部条件/冲突；原生正文、摘要、复核与 fallback 不丢边界。
- [x] 实际 JSC → 保存 → JSON/Archive → 重放 → 补问 → 再渲染集成，拒绝旧问题裁定冒充新结果。
- [x] 新输入确认与结果展示的 App/UI 验证；仍用完整原始事实检验无损传输与容量。

## 任务 5：总体验收与提交

- [x] 各领域来源与反例的独立复核；处理实现与原文的冲突。
- [x] `npm run typecheck --prefix native/Engine`、引擎全部 Jest、后端全部测试、bundle/fixture 对比。
- [x] `TZ=America/Los_Angeles swift test --package-path native/Core`；加入最终容量矩阵、原生 App/UI 验收。
- [x] 更新总报告，分别记录已实现、正反例与冲突测试、未覆盖项及具体证据原因。
- [x] 在现有分支提交并推送；逐次核对精确 SHA 的 CI 并处理失败，最终通过情况在交付消息单列。不合并或发布。

## 协作检查

| 接口 | 生产者 | 消费者/所有者 | 处理 |
| --- | --- | --- | --- |
| 六爻 eventAssessment | 六爻领域 | 主任务事实索引、补问可变字段 | 旧效力层不变；新增层单独核验 |
| 奇门专门取用输入/结果 | 奇门领域 | 主任务 schema、确认 UI、补问 | 先固定接口，再统一接入 |
| 八字竞争结果 | 八字领域 | 主任务事实索引及容量 | 保持现有 rescueEvidence 兼容边界 |
| bundle 与 fixtures | 三领域源码 | 主任务生成 | 不并发生成共享文件 |

Sources and independently meaningful outcomes are reviewed before marking any task complete. Existing immutable capacity archives remain historical evidence; new captures get a separate directory.
