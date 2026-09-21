# 原盘占问补充（F6b，2026-09-20）

## 验收范围

首次占问确认后的跨消息补充原先没有明确关联原盘的入口。本批增加“补充这次占问”：用户选择一个已保存的六爻或奇门盘，核对修改后的问题、对象、事项、类别及远近范围，另存补充记录。连续补充仍指向第一张原盘；既有原盘与历史补充不覆盖。另一个事项应发起新提问，不从普通聊天文字猜测原盘归属。

这仅完善资料、计算和解释依据之间的关联，不增加已定用神、综合效力、事件成败或具体应期。七政四余、独立星宿及生肖均未加入；核心整体验收仍未完成。

## 实现边界

- `reassess-question` 是本机专用命令，不向模型开放。它先于桥接层的当前时间读取分派，不调用起卦、起局、随机数或历法重算。
- 六爻仅更新问题上下文、候选对象、候选相对元忌仇角色和条件应期；奇门仅更新问题上下文、日时干/事项参考及尚未确定的应期条件。原爻、动爻值、变伏、六亲、九宫、格局、日月时柱及原来源信息保持逐字段一致。
- 保存派生记录为 `reassess_liuyao` / `reassess_qimen`，并记录原工具名和原调用编号。原工具名称只用于确认参数校验和通过验证后的本地展示适配，不修改存储记录或模型工具白名单。
- 原盘必须存在于当前账户的实际历史、早于补充，编号无歧义且与快照完全一致；资料或引擎版本变化时拒绝继续套用旧记录。旧档案仍可解码和查看，不承诺跨引擎版本迁移。
- 确认元数据在计算之前保存；已完成补充的重试只读取保存结果，不调用模型或计算引擎（允许读取引擎版本元数据）。取消、资料变化和账户变化均检查操作范围。

## 独立审阅发现及修复

1. 仅检查原盘不变量，仍可能把旧问题的完整候选/应期/角色集合放到新资料下。六爻“自己健康→父亲情况”反例曾显示新问题却沿用世爻本人参考；奇门漏掉代占视角。新增独立问题绑定校验，检查候选映射、遗漏条件、远近标签、奇门事项候选和兼容参考字段，并保留原坐标与角色证据检查。
2. 原盘的 `provenance.referenceDate` 被篡改时，新计算会拒绝，但缓存重试曾接受。原生层现在检查来源时间与原起盘时间一致、完整历法策略符合当前版本，并核对引擎版本/资料上下文。
3. 用户确认与挂起任务恢复之间存在账户切换窗口。若另一个账户导入了相同记录编号，原实现可能先保存旧确认再发现切换。确认返回后、保存前再次核验账户和出生资料，加入真实 SwiftData 的复制册页反例。

## 验证说明

- 引擎测试固定起盘输入，随后禁止 `cast`、`setup`、`Math.random`、`Date.now`、零参数 `new Date()`/`Date()` 与历法取柱；逐字段核对全部原盘不变量。坤卦父母候选的手工依据：纳支未巳卯丑亥酉、坤宫土以火为父母，因此本爻只取二爻巳火；测试初稿误写五爻已按表纠正，未以生产结果作为预期值来源。
- Core 使用实际 JavaScriptCore 引擎，覆盖原盘关联、连续补充、Codable 保存、逐个不可变字段删除、旧候选偷换、确认参数/编号不一致、来源缺失/重复/倒序及策略/时刻篡改。
- 原生测试使用实际 SwiftData、ChatSession 和打包引擎，禁止模型调用；恢复后的缓存重试通过会拒绝一切非 metadata 请求的引擎运行。另测取消、切换账户和确认后瞬间切换至复制册页。
- UI 测试从实际保存盘选择补充、修改事项、确认、查看包含原盘与补充记录的依据页，并导出/检查截图。首次新增 UI 测试点击开关未真正打开，仍停在禁用确认状态；改用已有可验证的事项输入路径，未绕过资料校验。原生测试初稿释放 SwiftData ModelContainer 导致测试对象失效，保留容器生命周期后通过。
- 所有资料均为合成输入；本流程无需模型，未作新在线模型或 Supabase E2E 声明。现有传统映射仍分别受六爻已读文献、奇门产品参考约定及其未决条件约束。

最终测试计数、独立复核记录与远端提交验收见同目录主计划及 `native/Engine/validation/reasoning/core-f6b-local-results.json`。

Final local results: 725 Engine /342 Core (America/Los_Angeles) /15 backend /29 unique native unit /3 UI pass. The complete native run had 28 tests; the added failure-restoration test raises the unique count to29, with all4 supplement tests rerun. The final localized error message change was followed by5 focused Core tests. Independent768 combinations +18 hidden/month/day cases pass;6 corruptions reject; the copied-account race persists no confirmation in the new scope.

Additional test correction: assigning an esbuild getter-only exported run property did not install the test interceptor. The fixture now replaces the whole namespace and positively proves a calendar request receives the exact forbidden-calculation error before testing cached retry. Failed reassessment also preserves accepted inputs and retries without another confirmation. These assertions are based on the corrected final run, not the earlier ineffective interceptor. Exact-head remote acceptance remains pending.
