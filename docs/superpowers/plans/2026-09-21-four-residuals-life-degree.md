# 四余与遇卯安命 Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 在固定本命档案中提供明确方法的四余、遇卯命宫/命度及十二宫。

**Architecture:** 四余采用现代平轨道方法：罗北计南，IERS/Simon 平交点，平均月球轨道远地点为月孛，Moira 原参数均速紫炁。遇卯法采用《图书集成·艺术典567卷》保留的《张果星宗》条文，明确以现代热带黄道十二等宫及固定 UTC+8 时支计算，现代距星参照仅用于命度参考宿位，不复原古宿度表。与七曜分别记录方法和参考系。

**Tech Stack:** TypeScript、Astronomy Engine 2.1.19、Swift Core；独立 Python ERFA/Swiss 只用于研究，不随产品分发。

**Spec:** `docs/superpowers/specs/2026-09-21-mingli-adjudication-design.md`

## Global Constraints

- 四余为推算点，不能全部称实体天体；紫炁周期10227.1792日、历元1975-03-13T16:00:00Z、黄经230.5°，这是所选现代参数。
- 平交点及月孛使用TT、日期平黄道；紫炁按UT匀速参数。七曜保持现有日期真黄道修正，不混写为同一视位置。
- 命度不等同月亮所在宿；现代360°、热带十二宫与现代距星方法必须显式说明，不声称古度或古历复原。
- 固定UTC+8出生钟面与星历物理时刻不变；此遇卯法不需纬度，不冒充地平升点或当地日出法。
- 所有新结果绑定出生、方法、源版本与引擎版本；普通问答读取缓存，不重新调用星历。

### Task 1: 四余研究复算与实现

**Files:** `src/astronomy/residuals.ts`、`src/astronomy/__tests__/Residuals.test.ts`、`validation/research-qizheng/completion-2026-09-21/`。

- [x] 记录ERFA faom03/faf03/fal03数学定义及许可、Moira旧版参数和现代南北对应选择；归档真实来源URL/哈希。
- [x] 写RED：J2000平升交点125.04455501°、降交点相差180°；紫炁历元230.5°，半周期50.5°、整周期回归；无效日期拒绝。
- [x] 平远地点由 argument=F-l+180°，倾角5.1453964°的平均轨道投影得黄经黄纬；以独立Swiss无章动输出验证，而非误把未投影经度直接作黄经。
- [x] 1901–2100季度样本，先定1角秒比较阈值；记录最大误差和所有超阈值，不把抽样阈值当全时间物理保证。

### Task 2: 遇卯命宫与命度

**Files:** `src/astronomy/lifeDegree.ts`、`src/astronomy/__tests__/LifeDegree.test.ts`。

- [x] RED：太阳子宫、酉时→午命宫；卯时命宫同太阳宫；十二宫逆地支布置，寅命→丑财→子兄→亥田，原文向量独立列出。
- [x] 现代热带黄道宫对应戌酉申未午巳辰卯寅丑子亥；命宫保留太阳宫内度，时支每差一支黄经移30°；05:00/07:00/23:00边界、跨0°与359°反例。
- [x] 命度黄道点取纬度0，转换日期真赤经后参照现有距星宿界；同时保存其现代黄道宫度与宿内现代赤经度，不混为同一种角度。
- [x] 返回十二宫及宫主、命度参照宿及度主；不扩展未验收的吉凶和流限。

### Task 3: 原生档案与证据

**Files:** `src/astronomy/natal.ts`、`src/ai/tools/astronomy.ts`、Swift `NatalAstronomyDossier`/证据索引/展示页，以及对应测试。

- [x] 新模块纳入固定档案与严格验证，旧缓存随引擎版本自动重建。
- [x] 工具all返回各模块，单七曜查询保留现有行为；新增四余和命度投影，禁止模型注入方法或出生资料。
- [x] 原生验证方法/源/身份/角度关系；篡改源、点名、南北、宫序、太阳基准或时支均拒收。
- [x] 索引保留完整方法和依据；UI使用明确方法名。最终统一容量、JSC浮点口径、缓存生命周期与真实原生构建验收。
