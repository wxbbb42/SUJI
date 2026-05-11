# PRD：奇门遁甲起局准确性 Hardening（上中下元 + 值使门/八门转盘）

**日期**：2026-05-11  
**项目**：有时 / SUJI  
**模块**：`lib/qimen/` 奇门遁甲起局引擎  
**优先级**：P0/P1  
**目标读者**：负责实现的 coding agent / reviewer  
**性质**：算法准确性 hardening，不是 UI 重设计，不是新增玩法

---

## 1. 背景

当前 SUJI 的奇门遁甲模块已经具备稳定 MVP：

- 可根据时间起局。
- 支持真太阳时校正。
- 可识别节气、阴阳遁、局数。
- 已有地盘、天盘、九星、八神、用神、格局、evidence/UI 集成。
- 现有相关测试可通过，属于“工程上稳定的 MVP”。

但对照传统转盘奇门排盘流程后，目前仍有两个关键薄弱点，会影响“完整盘”的专业可信度：

1. **上中下元判定仍是 MVP 近似**  
   当前 `QimenEngine.computeYuan()` 使用日序 / 干索引近似粗分上中下元，没有严格按“节气交接 + 甲子日起上元”的三元逻辑。

2. **八门排法仍是 MVP 简化**  
   当前 `buildPalaces()` 里八门是“直符宫起开门，阳顺阴逆”，没有完整实现“值使门”的确定与旋转。

这两个点会导致：

- 同一时间起出的局数可能和传统排盘工具不同。
- 八门位置可能与标准转盘奇门盘不一致。
- AI 解读基于错误门位时，会放大算法误差。
- 产品如果继续展示“完整盘”，专业用户会很快发现不严谨。

本 PRD 的目标是把这两个薄弱点从 MVP 近似提升到可验证、可测试、可解释的 Standard 版本。

---

## 2. 目标

### 2.1 产品目标

让有时的奇门起局从“稳定可演示 MVP”升级为“可作为严肃功能继续迭代的基础盘”。

具体表现：

- 用户在节气交接附近起局时，节气、元、局数不因日期粗判而错。
- 八门排布遵循“值使门”逻辑，而不是固定从直符宫起开门。
- Evidence / debug / metadata 能说明本次起局使用的方法层级。
- 后续 AI 解读可以更放心引用八门、值使、用神宫信息。

### 2.2 工程目标

- 把 `computeYuan()` 从近似函数替换为可测试的严格算法。
- 把八门排法拆成独立 helper，补齐值使门计算。
- 保留现有 API 兼容性，避免大范围 UI 改动。
- 增加 fixture 测试，防止后续 agent 把规则改回近似实现。
- 更新 spec / method caveat，明确哪些已升级、哪些仍是 MVP。

---

## 3. 非目标

本次不要做以下事情：

- 不重写整个 `QimenEngine`。
- 不改 UI 视觉风格。
- 不扩大到 100+ 格局识别。
- 不做置闰法 / 超神接气 / 拆补置闰多派别切换。
- 不把奇门包装成绝对权威预测。
- 不引入不可维护的第三方奇门黑盒库。
- 不在没有 source note 的情况下凭 agent 记忆硬写规则。

本次只聚焦两个核心 hardening：

- 严格三元定局。
- 严格值使门与八门转盘。

---

## 4. 当前实现问题定位

### 4.1 问题 A：上中下元判定近似

当前文件：`lib/qimen/QimenEngine.ts`

当前逻辑：

```ts
private computeYuan(time: Date): Yuan {
  const day = Math.floor(time.getTime() / 86400000);
  const ganIdx = ((day % 10) + 10) % 10;
  if (ganIdx <= 3) return '上';
  if (ganIdx <= 6) return '中';
  return '下';
}
```

问题：

- 与节气交接时刻没有绑定。
- 与“甲己日起上元、乙庚日中元、丙辛日下元”等三元判法没有明确对应。
- 对交节日前后、节气内第几元的判定可能错。
- 代码注释已承认是 MVP 简化。

### 4.2 问题 B：八门排法简化

当前文件：`lib/qimen/QimenEngine.ts`

当前逻辑：

```ts
// 八门起点：开门起直符宫，阳遁顺时针、阴遁逆时针
const menSequence = dun === '阳' ? [...PALACE_CLOCKWISE_8] : [...PALACE_CLOCKWISE_8].reverse();
const zhiFuIdxInMen = menSequence.indexOf(zhiFuOuter);
const bamenMap = new Map<number, BamenName>();
for (let i = 0; i < 8; i++) {
  const pid = menSequence[(zhiFuIdxInMen + i) % 8];
  bamenMap.set(pid, BAMEN_ORDER[i]);
}
```

问题：

- 把“直符宫”和“开门起点”绑定，属于简化。
- 没有计算“值使门”。
- 没有把值使门落到时辰对应宫位后再整体排八门。
- 传统排盘中八门是一个独立层，不能完全等同九星 / 直符逻辑。

---

## 5. 用户故事

### Story 1：作为普通用户，我希望起出的盘不要在关键节点出错

当我在节气交接当天或附近提问时，系统应该按真实交节时刻判断节气与三元，而不是按日期粗略切换。

验收：

- 交节前一小时和交节后一小时可起出不同节气/局数。
- 测试覆盖至少 4 个节气边界。

### Story 2：作为懂奇门的用户，我希望八门排布符合传统转盘逻辑

当我打开完整 9 宫盘时，八门位置应遵循值使门转动规则，而不是明显的 MVP 简化。

验收：

- 至少 5 个 fixture 与可复核来源一致。
- 完整盘中可展示或调试输出 `zhiShiMen` / `zhiShiPalaceId`。

### Story 3：作为 AI 解读用户，我希望解释基于可靠 evidence

当 AI 引用“开门/生门/伤门”等信息时，这些门位应来自新的八门算法，并且 evidence 能说明算法版本。

验收：

- `setup_qimen` 工具返回的 chart metadata 包含算法等级和 caveats。
- 旧 caveat “八门为 MVP 简化”被移除或改为更准确的剩余边界说明。

---

## 6. 功能需求

### 6.1 FR-1：严格计算节气交接时刻

当前 `currentSolarTerm(date)` 已经按太阳黄经判断当前节气，这是正确方向。但三元计算需要知道“当前节气的精确开始时刻”。

需要新增 helper：

- 文件建议：`lib/qimen/helpers/solarTerms.ts`
- 新增导出：
  - `currentSolarTerm(date: Date): string`（保留）
  - `findSolarTermStart(date: Date): { jieqi: string; startTime: Date; longitude: number }`
  - 可选：`findNextSolarTerm(date: Date): { jieqi: string; startTime: Date; longitude: number }`

实现要求：

- 基于太阳黄经 15° 分段。
- 使用二分搜索找当前节气起始边界。
- 搜索窗口可设为 date 往前 20 天，足够覆盖任意节气间隔。
- 精度目标：误差小于 10 分钟；理想小于 1 分钟。
- 不依赖在线 API。

验收：

- 对 2024/2025 年若干节气边界写测试。
- 至少覆盖：立春、清明、夏至、冬至。
- 当前节气名称仍与现有测试一致。

### 6.2 FR-2：严格计算上中下元

新增 helper：

- 文件建议：`lib/qimen/helpers/yuan.ts`
- 导出：
  - `computeYuanByJieqiStart(time: Date, jieqiStart: Date): Yuan`
  - 或 `computeYuan(time: Date, context: { jieqi: string; jieqiStart: Date }): Yuan`

推荐实现原则：

- 拆补法语境下，以节气交接时刻作为当前节气段起点。
- 从节气起点开始按日柱推进三元。
- 三元不是简单“前 5 天 / 中 5 天 / 后 5 天”的公历日切片；要明确采用一个可复核传统规则。
- 本项目建议先采用“日干定元”主流简化标准：
  - 甲、己日：上元
  - 乙、庚日：中元
  - 丙、辛日：下元
  - 丁、壬日：上元
  - 戊、癸日：中元
- 如果 source review 发现本规则与当前转盘奇门资料不一致，以三源交叉验证结果为准，并在 code comment 中记录来源。

重要：agent 实现前必须先补一份 source note，不允许直接凭记忆写。

新增文档：

- `docs/mingli/reading-notes/qimen-yuan-and-zhishi.md`

文档至少记录：

- 三元定局规则。
- 节气交接处理。
- 日干/甲子与上中下元的对应。
- 若来源有分歧，记录分歧和本项目取舍。

验收：

- 删除或废弃 `QimenEngine.computeYuan()` 的 MVP 近似。
- `QIMEN_METHOD.caveats` 不再写“上中下元使用日序近似”。
- 新增测试覆盖：
  - 同一节气内不同日干映射到不同元。
  - 节气交接前后元/局数可能变化。
  - 固定 fixture 的 juNumber 稳定。

### 6.3 FR-3：补齐值使门计算

新增 helper：

- 文件建议：`lib/qimen/helpers/bamen.ts`
- 导出：
  - `computeZhiShiMen(params): BamenName`
  - `computeZhiShiPalace(params): number`
  - `rotateBamen(params): Map<number, BamenName>`

需要明确的数据：

- 八门地盘固定位置。
- 旬首对应值使门的确定方式。
- 值使门随时辰转动后的落宫。
- 阳遁 / 阴遁下八门排布方向。
- 中宫寄宫规则。

建议类型：

```ts
export interface BamenRotationResult {
  bamen: Map<number, BamenName>;
  zhiShiMen: BamenName;
  zhiShiPalaceId: number;
  zhiShiSourcePalaceId: number;
}
```

传统概念要求：

- “值符”是九星层的主星。
- “值使”是八门层的主门。
- 值使门不是永远等于开门。
- 八门应以值使门落宫为锚点进行整体转动。

验收：

- `buildPalaces()` 不再内联八门排法。
- 八门排法全部通过 `rotateBamen()` 生成。
- `QimenChart` metadata 中可包含：
  - `zhiFuStar`
  - `zhiFuPalaceId`
  - `zhiShiMen`
  - `zhiShiPalaceId`
- 至少 5 个已知盘 fixture 验证八门位置。

### 6.4 FR-4：扩展 QimenChart method metadata

当前已有：

```ts
const QIMEN_METHOD: QimenMethodMeta = {
  level: 'mvp',
  caveats: [...],
};
```

需要升级：

- `level` 可从 `'mvp'` 调整为 `'standard'`，或保留但补充 per-field accuracy。
- 推荐改成更细：

```ts
method: {
  level: 'standard',
  algorithm: 'zhuanpan-qimen-chai-bu',
  accuracy: {
    solarTerm: 'true-solar-longitude',
    yuan: 'jieqi-start-day-gan',
    tianPan: 'rotating-star-with-xunshou',
    bamen: 'zhishi-men-rotation',
    yongShen: 'mvp-rule-table',
    yingQi: 'mvp-heuristic',
  },
  caveats: [
    '用神选择与应期仍为产品 MVP 简化规则',
    '格局识别只覆盖当前数据表可判定的常用格局',
    '暂不支持置闰法 / 超神接气等派别切换',
  ],
}
```

验收：

- 旧 caveat 不能继续说已修复项仍是 MVP。
- Evidence / debug 可读到 method 信息。

### 6.5 FR-5：测试与 fixture

必须新增测试：

- `lib/qimen/helpers/__tests__/yuan.test.ts`
- `lib/qimen/helpers/__tests__/bamen.test.ts`
- 更新 `lib/qimen/__tests__/QimenEngine.fixture.test.ts`

最低测试要求：

- 三元测试不少于 8 个。
- 八门转盘测试不少于 5 个完整 fixture。
- 节气边界测试不少于 4 个。
- 完整 `QimenEngine.setup()` 端到端测试不少于 3 个。

命令验收：

```bash
npm test -- --runInBand lib/qimen
npm test -- --runInBand
npx tsc --noEmit
git diff --check
```

全部通过后才算完成。

---

## 7. 技术方案建议

### 7.1 文件结构

建议新增或修改：

```text
lib/qimen/
  QimenEngine.ts
  types.ts
  helpers/
    solarTerms.ts
    yuan.ts
    bamen.ts
    tianPan.ts
    timeGanZhi.ts
    __tests__/
      solarTerms.test.ts
      yuan.test.ts
      bamen.test.ts
  __tests__/
    QimenEngine.fixture.test.ts
    QimenEngine.test.ts

docs/mingli/reading-notes/
  qimen-yuan-and-zhishi.md

docs/superpowers/specs/
  2026-04-25-qimen-divination-design.md
```

### 7.2 推荐实现步骤

#### Step 1：先写 source note

输出：`docs/mingli/reading-notes/qimen-yuan-and-zhishi.md`

内容必须回答：

- 上中下元如何定？
- 当前节气交接时刻怎么处理？
- 值使门怎么确定？
- 值使门如何随时辰落宫？
- 八门如何顺/逆排？
- 哪些规则有派别分歧？本项目选哪一个？为什么？

#### Step 2：实现 solar term boundary helper

在 `solarTerms.ts` 中补：

- `solarLongitude` 如需测试可导出为 internal。
- `findSolarTermStart()` 用二分查边界。
- 测试节气边界。

#### Step 3：实现 yuan helper

在 `yuan.ts` 中补：

- 从 `timeGanZhi.ts` 或 lunisolar 获取日干。
- 按 source note 规则返回上/中/下元。
- 不要再使用 epoch day mod 10。

#### Step 4：实现 bamen helper

在 `bamen.ts` 中补：

- 固定八门地盘。
- 根据旬首/时辰计算值使门。
- 根据值使门落宫整体转盘。
- 中宫寄宫逻辑复用或抽到公共 helper。

#### Step 5：接入 QimenEngine

修改 `QimenEngine.setup()`：

- `currentSolarTerm(trueSolar)` 改为返回当前节气和起始时刻。
- `computeYuan(trueSolar)` 改为 `computeYuanByJieqiStart(trueSolar, jieqiStart)`。
- `rotateTianPan()` 的返回值保留并进入 chart metadata。
- `buildPalaces()` 接受 bamenMap，而不是自己计算八门。

建议签名：

```ts
private buildPalaces(
  diPan: Map<number, TianGan>,
  tianPan: Map<number, TianGan>,
  tianJiuxing: Map<number, JiuxingName>,
  bamenMap: Map<number, BamenName>,
  bashenMap: Map<number, BashenName>,
): Palace[]
```

#### Step 6：更新 method metadata 与 spec

- 修改 `QIMEN_METHOD`。
- 更新原 spec 中旧的 “MVP 简化”描述。
- 保留派别边界说明。

#### Step 7：测试与回归

- 先跑 qimen scoped tests。
- 再跑全量 test。
- 最后 tsc。

---

## 8. 验收标准

### 8.1 功能验收

完成后必须满足：

- 当前节气按真实太阳黄经判断。
- 当前节气起始时刻可计算。
- 上中下元不再使用 epoch day / mod 近似。
- 八门不再固定“直符宫起开门”。
- chart 内可追踪值符和值使信息。
- method metadata 准确反映算法层级。

### 8.2 测试验收

必须全部通过：

```bash
npm test -- --runInBand lib/qimen
npm test -- --runInBand
npx tsc --noEmit
git diff --check
```

### 8.3 代码质量验收

- 不引入新的 `any`。
- 不引入网络依赖。
- 不在 production code 中 hardcode 临时 fixture。
- 关键算法必须有注释说明来源与派别取舍。
- helper 函数必须可单测。
- `QimenEngine.ts` 不应继续膨胀过多；排门逻辑必须拆出去。

### 8.4 产品验收

- Evidence / UI 不崩。
- 旧的奇门聊天流程仍能正常返回。
- 用神宫卡仍能读取 `bamen`、`jiuxing`、`bashen`。
- 完整 9 宫盘仍能展示。
- AI 不应宣称“绝对准确”，保留辅助决策语气。

---

## 9. 风险与处理

### 风险 1：不同资料对值使门排法有分歧

处理：

- 先记录 source note。
- 选择一种主流转盘奇门规则作为默认。
- method metadata 写明 `algorithm: zhuanpan-qimen-chai-bu`。
- 暂不做多派别切换。

### 风险 2：节气边界计算与外部排盘工具相差几分钟

处理：

- 接受小于 10 分钟误差。
- 测试不要卡到秒级。
- 如果需要更高精度，后续再引入天文算法库，但本次不做。

### 风险 3：修正八门后旧 fixture 大量变化

处理：

- 这是预期变化。
- 旧 fixture 如果 pin 的是 MVP 行为，要更新为新规则。
- commit message 中明确说明 breaking reason：`qimen: replace MVP bamen rotation with zhishi-men rotation`。

### 风险 4：AI 解读 prompt 继续过度引用奇门

处理：

- 保留 prompt 里的“辅助象意，不作确定性断言”。
- Evidence 展示算法 caveat。
- 本 PRD 不要求重写 prompt，但如发现旧 prompt 夸大，需要顺手修。

---

## 10. 建议任务拆分

### Task A：资料核对与 source note

产出：

- `docs/mingli/reading-notes/qimen-yuan-and-zhishi.md`

验收：

- 至少 3 个来源。
- 记录规则与取舍。

### Task B：节气边界 helper

产出：

- `findSolarTermStart()`
- 测试覆盖立春、清明、夏至、冬至。

### Task C：三元 helper

产出：

- `helpers/yuan.ts`
- 单测。
- `QimenEngine` 接入。

### Task D：值使门 / 八门 helper

产出：

- `helpers/bamen.ts`
- 单测。
- `QimenEngine` 接入。

### Task E：chart metadata 与 method 更新

产出：

- `types.ts` 扩展。
- `QIMEN_METHOD` 更新。
- evidence/debug 不破。

### Task F：fixture 与回归测试

产出：

- 更新 qimen fixture。
- 全量测试通过。

---

## 11. 推荐 agent 执行提示词

可以直接把下面这段交给实现 agent：

```text
你要在 SUJI 仓库实现奇门遁甲起局准确性 hardening。请严格按 docs/superpowers/prds/2026-05-11-qimen-accuracy-hardening-prd.md 执行。

重点只做两个薄弱点：
1. 上中下元从 MVP 近似升级为基于节气交接 + 传统三元规则的可测试实现。
2. 八门排法从“直符宫起开门”升级为“值使门计算 + 八门转盘”。

要求：
- 先写 source note：docs/mingli/reading-notes/qimen-yuan-and-zhishi.md，至少记录 3 个来源和本项目取舍。
- 不要重写整个 QimenEngine。
- 不要改 UI 视觉。
- 不要引入在线 API 或不可维护第三方奇门库。
- 新增 helper：solarTerms boundary、yuan、bamen。
- 新增/更新测试：yuan、bamen、solar term boundary、QimenEngine fixture。
- 更新 QIMEN_METHOD，移除已修复的 MVP caveat，保留用神/应期/派别限制。

完成前必须跑：
npm test -- --runInBand lib/qimen
npm test -- --runInBand
npx tsc --noEmit
git diff --check

如果资料出现派别分歧，不要硬猜；在 source note 中记录分歧，选择一个主流转盘奇门规则并说明原因。
```

---

## 12. Definition of Done

本 PRD 完成的定义：

- PR 中包含 source note、算法实现、测试、spec/method 更新。
- `computeYuan()` 不再是日序 mod 近似。
- 八门由 `rotateBamen()` / 值使门 helper 生成。
- `QimenChart` 可追踪值符和值使。
- qimen scoped tests、全量 tests、tsc、diff check 全通过。
- reviewer 能通过文档理解规则来源，不需要问“这段算法从哪来的”。

---

## 13. 后续可选优化

本次完成后，下一轮可以考虑：

- 多派别配置：拆补法 / 置闰法。
- 更高精度天文节气算法。
- 与 2-3 个外部排盘网站做批量 fixture 对照。
- 用神规则进一步 source-grounded。
- 应期从固定“1-3 个月”升级为基于宫位、门、干支、空亡的规则。
- 完整盘 UI 增加“算法说明 / 为什么这样排”的学习层。
