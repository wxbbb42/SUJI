# 八字来源纠正与专旺裁定 Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking. Independent source work follows superpowers:dispatching-parallel-agents.

**Goal:** 纠正司令表来源与申月错误，以所选原典条件替代专旺检测中错误的食伤/印门槛，并接通原始出生节令、有限救应裁定及原生本地解释。

**Architecture:** 司令分段明确表示原文并称的干；专旺独立模块输出方法、条件和有范围的判定，旧工程评分不能变成传统裁定。主任务统一接原生证据与生成资源。

**Tech Stack:** TypeScript/Jest、Swift Core/JavaScriptCore。

**Spec:** `docs/superpowers/specs/2026-09-21-mingli-adjudication-design.md`

## Global Constraints

- 原盘与来源绑定，不新增任意权重。
- 原文食伤可泄秀，不能统一判作破格；藏干克神不能脱离方局整体一票否决。
- 严格选法未命中不能表述为所有流派均否定。
- 不引入生肖；不把此批算作四系统全部完成。

### Task 1: 司令表来源与边界

**Files:** `native/Engine/src/bazi/SiLing.ts`、新增对应 Jest 测试、`native/Engine/validation/research-bazi/adjudication-2026-09-21/`。

- [x] 归档徐注完整十二月表和三命异表；逐项比较默认表，记录申月与并称干差异。
- [x] 先测申月第 9、10、12、13 天及边界的原文预期；戊己并称不能被表达为唯一己。加入负数、非有限天数反例。
- [x] 明确从月节起算的半开区间；保留长于三十天的最后段延续政策，来源不支持时不声称精确司令。
- [x] 修来源与实现，检索全部调用点，验证生产强弱是否实际使用此函数并准确报告；本批新增的实际输入用于专旺季节条件，不把旧工程强弱评级升格为传统裁定。

### Task 2: 专旺的来源条件

**Files:** `native/Engine/src/bazi/structural.ts`、新专旺规则模块与 Jest 测试、来源报告。调用点复核确认 `InsightEngine.ts` 消费现成命盘，无需重复计算专旺。

- [x] 写入独立字面向量：甲寅/丁卯/甲辰/丙寅的食伤泄秀、无透印正例；时干改庚的克神反例；原典从革庚申/乙酉/庚戌/庚辰及润下壬子/辛亥/癸丑/壬子保留方局参与支的藏干。
- [x] 运行测试确认旧实现错误；检验其余火土支路的来源，不以类推替代稼穑专条。
- [x] 实现 methodVersion、各条件与判定；未支持的传统分支明确说明，不能返回全流派否定。
- [x] 接入现有格局结果，保留传统条件判定与工程评级的区别。
- [x] 核验新增返回字段的真实 `get_domain` 传输、Swift来源／原盘绑定及局部解释；八字、历法、dispatch、natal组合17套300项通过，Swift Bazi／TypedClaim共41项通过。
- [x] 父任务统一重建最终资源并完成全量 Engine/Core/App 集成验收；此项不由上述局部通过代替。

### Task 3: 有限救应与全局边界

- [x] 对《论相神紧要》逐例构建保护、阻断和依赖链，确定能裁定的规则与全局竞争条件，并以 `rescueEvidence` 单列接口。
- [x] 实现逐柱有向五合的通根保用、日主不去、甲己庚隔、相神保护／阻断和明确原例的隔位链；完整藏干命例仅作精确见证。
- [x] 先取得16项失败的可运行RED，再通过扩展后的19项救应测试；旧工程候选保留来源限制，已证受阻的路径不能继续覆盖旧成败评级。
- [x] 未实现的完整取相、多路径力量竞争、克合反馈、藏干泛化、支合成化、从格及化气规则保留在总设计范围；不得用本批局部裁定声明整体八字裁定完成。

### Task 4: 原盘出生节令与原生证据

- [x] 新增 `birthMonthContext.ts`，以原始出生物理时刻绑定十二节左闭右开区间；禁止用真太阳时偏移月节经过量。
- [x] 唯一生产 `computeGeJuV2` 调用传入出生节令上下文，真实1980稼穑及1993两处有根癸的dispatch回归通过。
- [x] `BaziAdjudicationTrace` 及全文／简述解释核对固定来源、四柱、节令司令与有限五合；篡改来源、出生、根或柱位时拒绝该解释。
- [x] 保持共享证据48字段／6000字节边界；144个实际月／时组合通过容量回归，最大持久化字段3539字节。

### Task 5: 来源登记与交付

- [x] 八字、六爻效力、奇门应期的运行时来源ID、电子本SHA与限定论断登记到 `sources.json`／`claims.json`；保留四余／命度条目。
- [x] 出生节令与奇门有界日期搜索分别登记为产品约定；奇门现代教材为D级，不能标为已核古典原本。
- [x] 运行 `node scripts/ingest-mingli-kb.mjs`，生成77个来源／84条论断；11个当前运行时来源导出与登记字段完全匹配、8条八字文本SHA核对通过，`git diff --check`通过。本子任务实现冻结，最终全量集成由父任务统一完成。
