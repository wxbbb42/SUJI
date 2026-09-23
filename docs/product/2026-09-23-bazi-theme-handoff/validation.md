# 册页主题 → 问道验收

> 历史记录：下方“最终验证”及“真实结果待填写”是实验中途状态。之后已封存8场景/19轮真实结果，失败保留；见 [收尾交接入口](../HANDOFF.md)及[暂停快照](../2026-09-23-system-report-replan/pause-status.md)。本页不代表主题或纠偏方案验收通过。

日期：2026-09-23。分支 `codex/fix-mingli-today-activities`。所有资料为明确标记合成资料；没有读取或删除真实用户 notebook。检查点提交先于本阶段业务改动：`776b34f8bd515d53fd7567ebf278e29070750534`。

## 验收合同

本地完整结构解读与现代编辑练习不依赖AI成功。模型只能选择审核动作/追问；程序验证真实本命投影、身份与闭合协议后渲染。此链路不是自由个体命理综合，不能用模型四字段协议通过率冒充内容价值，更不能当作预测准确率。

主题问题、连续追问、修改资料、动态问题、模糊/他人/事件、故障与重试分别验收。旧标准问道仍使用原生产核验器，未关闭保护。新主题不经ReflectionSession自由流式路径；该旧路径只加强了出生代际失效，并未整体重做证据核验。

## 定向失败与修复留痕

全部原始日志位于忽略目录 `native/artifacts/bazi-theme-2026-09-23/`，没有删掉失败证据。

| 问题 | 失败证据 | 修改与后验 |
| --- | --- | --- |
| 错内层算法版本仍被接受 | `/tmp/suji-theme-identity-red.log`，1失败 | 严格inner payload版本；`/tmp/suji-theme-identity-green.log` 9/9 |
| 身份代际/外部natal注入 | `/tmp/suji-theme-identity-hosted-red.log`、`/tmp/suji-theme-injection-red.log` | 独立birthRevision，跨await核对，调用方natal/astronomy剥除；`/tmp/suji-theme-identity-hosted-green.log` 19/19 |
| 实际get_domain投影没带birth | `session-red-2.log`，1测试3失败，0模型调用 | 真实引擎投影补当前birth；`session-green-2.log` 10/10 |
| 术数优先级/动作与问题错配 | `critique-routing-red.log`，4测试3断言失败 | 明确术数优先、动作限制、现实练习不误读为他人命盘 |
| 模型主动追问后短答丢失 | `short-followup-red.log`，新增合同编译失败 | 经核验的相邻历史承接窄短答；篡改正文、receipt、sourceID、binding、context均不得授权 |
| “举个具体例子”漏路由 | `concrete-example-red.log`，6测试1失败；`native-ui-final-3.log` 新hosted例3断言失败 | 例子窄匹配修正；`concrete-example-green.log` 10/10；第四轮hosted 61项、2skip、0失败 |
| 大字唯一CTA难找、示例正文AX定位、专业来源后越过CTA | 首轮`native-ui.log`，第二/三轮`native-ui-final-2/3.log` | 主CTA常显限定后；细读CTA在专业来源前；明确展开语义；实际检查原文/限定后收起，不增加盲扫次数 |
| 底栏遮住输入/发送，自动isHittable未发现 | round2四张独立截图、独立D4/P2 | 根TabView与底栏分区；新增完整输入/48pt发送目标位于底栏上方的几何断言 |
| 首轮旧慢出生更新用例出错 | `native-ui.log` 的解码错误保留 | 过时调用改为明确期望CancellationError，其他错误仍失败；第二/三/四轮该例均通过。单次初始解码错误没有独立定位为生产根因，不把改测试预期说成已修解码器 |

首次UI结果包诊断收集停滞，完成测试后仅终止本任务xcodebuild；原不完整包保留，不用它作截图证据。另一次命令错用目标`SujiAppTests`在运行前退出70，改为真实scheme目标`SujiTests`，没有把它计入测试通过数。后续加`-collect-test-diagnostics never`，使用新的结果目录。

## 最终验证结果

最新Core全量 **515项，1项跳过，0失败**（`core-final-3.log`，192秒）；最新hosted **61项，2项在线专用skip，0失败**（`native-ui-final-4.log`）；后端回归 **15/15**（`backend-regression.log`）。UI与真实批次仍待完成。每个计数取对应最终日志，不相加重复运行制造总数。

## 真实链路预算与逐例证据

预先限定8个合成场景、总计最多24次实际模型请求，闭合协议最多一次修复；网络错误无自动重试。测试矩阵为 `native/Tests/Fixtures/live-theme-matrix.json`。T07第一次中断是**人为注入的传输失败**，随后请求才是真实Supabase→DeepSeek；不能描述为自然线上故障。临时测试账号通过现有管理授权创建，结束只清理该账号及其配额行，不创建资源，不部署后端。

真实结果、脱敏逐轮索引及独立内容复核待批次完成后填写。原始模型响应不提交。取数成功、协议成功、内容合格、澄清、预期拒绝、失败分别记录。

## 可重跑入口

```sh
# 全Core与只读后端回归；无需模型调用
TZ=America/Los_Angeles swift test --package-path native/Core
npm test --prefix supabase
# 五份真实本地引擎合成样稿
bash native/scripts/generate-bazi-theme-samples.sh
# 使用可用模拟器ID；同一DerivedData不并发
xcodebuild -project native/Suji.xcodeproj -scheme Suji \
  -destination 'platform=iOS Simulator,id=6D4DD0DD-948E-4CB4-AFD6-D382D0B143AF' \
  -derivedDataPath native/DerivedDataTheme -collect-test-diagnostics never \
  -parallel-testing-enabled NO -only-testing:SujiTests \
  -only-testing:SujiUITests/BaziThemeHandoffUITests test
# 构建供显式在线测试使用的xctestrun（单独、串行）
xcodebuild -project native/Suji.xcodeproj -scheme Suji \
  -destination 'platform=iOS Simulator,id=6D4DD0DD-948E-4CB4-AFD6-D382D0B143AF' \
  -derivedDataPath native/DerivedDataTheme build-for-testing
# 将实际生成的xctestrun路径代入；输出必须为新目录，避免覆盖证据
node supabase/scripts/smoke-native-reading.mjs --create-test-user \
  --suite LiveThemeSessionTests --request-budget 24 \
  --matrix native/Tests/Fixtures/live-theme-matrix.json \
  --cases T01,T02,T03,T04,T05,T06,T07,T08 \
  --xctestrun '<实际生成的.xctestrun>' \
  --device 6D4DD0DD-948E-4CB4-AFD6-D382D0B143AF \
  --output native/artifacts/bazi-theme-new-run
# 仅生成脱敏证据摘要；内容不能自动判绿
python3 native/scripts/summarize-theme-live.py \
  native/artifacts/bazi-theme-new-run/report.json \
  --output native/artifacts/bazi-theme-new-run/sanitized.json
```

## 未覆盖

真机未安装、未测试；人工VoiceOver焦点/朗读顺序未验证。未重跑旧32题付费矩阵，其18失败维持原判。未验证任意口语/长期自由对话、所有账号云端冲突、跨设备报告版本完整历史文字重演。五份合成盘覆盖本主题的四分支和见印附加条件，不代表出生人口覆盖率。来源为仓库电子转录，未逐字校印本。内容评审通用帮助5/10，尚未满足完整、丰富生活命理报告的最终产品目标。
