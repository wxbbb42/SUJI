# 六爻事件方向验收

实现范围和原文边界：`docs/mingli/validation/liuyao-event-source-review-2026-09-21.md`。

最终证据：

- `selected-passages.json` / `verify-sources.py`：12 段原始字节散列、逐字内容与 Unicode 坐标。所有当前来源引文均不跨 HTML 段落拼接。
- `generate-fixtures.mjs` / `swift-fixtures.json`：14 组真实引擎回执；日历坐标是明确传统输入，现代时间只作测试脚手架。
- `engine-final.log`：事件、既有效力、原盘补问共 42 项通过；事件独立 16 项。
- `divination-final.log`：前一轮 divination 17 套／221 项通过，随后又新增两项潜在救应和多候选状态回归，包含在上述最终 42 项中。
- `swift-final-source.log`：新事件层、既有效力及索引校验共 11 项通过。新层 4 项测试包含 14 组完整回执、存储字典与 ConversationEntry JSON 档案重放、全部证据指针和 24 个篡改变体。
- `capacity-final-source.log` / `capacity-top.json`：4,096 卦画 × 4 类问题 = 16,384 组；最终最大 63,793 字节，小于不变的 65,536 字节上限。
- `tdd-red*.log` 与相应 `tdd-green*.log`：缺新层、传递／待空、忌神施力、索引布局、多候选未决误报的 RED/GREEN。
- `swift-red.log`：旧原生拒绝新层且缺少对称防降级，2 失败；`swift-red-indexed-fixture.log`：已编译旧验证器拒绝新索引回执。`swift-green-indexed.log` 与最终日志记录修正后通过。

中途 `swift-regression.log`、`swift-red-indexed.log`、`swift-red-indexed-retry.log`、`swift-final.log` 含其他并行领域正在编辑时的编译失败，不是最终验收结果；最终通过记录为 `swift-final-source.log`。未改写失败日志。

重现（在仓库根目录；不生成 App 共享 bundle）：

```sh
python3 native/Engine/validation/research-divination/event-2026-09-21/verify-sources.py
cd native/Engine
node validation/research-divination/event-2026-09-21/generate-fixtures.mjs
npm test -- --runTestsByPath src/divination/__tests__/EventAssessment.test.ts src/divination/__tests__/Efficacy.test.ts src/divination/__tests__/QuestionReassessment.test.ts
SUJI_QUESTION_CAPACITY_OUTPUT=validation/research-divination/event-2026-09-21/capacity-top.json npm test -- --runTestsByPath src/divination/__tests__/QuestionCapacity.test.ts
cd ../..
swift test --package-path native/Core --scratch-path /tmp/suji-liuyao-global-build --filter 'LiuyaoEventAssessmentTests|LiuyaoEfficacyTests|LiuyaoEfficacyIndexTests'
```

真实共用 bundle、ChatSession、仅盘面模式、工具传输容量、App/UI 和完整档案链由主任务集成验收。此目录的本域结果不能代替那些跨层测试。
