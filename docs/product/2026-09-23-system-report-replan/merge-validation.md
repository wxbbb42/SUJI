# 收尾合并验证记录

2026-09-23。[当前交接入口](../HANDOFF.md)。只验证和保存已有成果，不继续实施R2、不调用付费模型、不部署。此文件的本地结果不代替GitHub PR/main CI；远端结果以对应提交的Actions为准。

## 版本与范围

- 基线远端main：`8164f25d12ffc246b9cead96cae64d6760098983`；检查点：`776b34f8bd515d53fd7567ebf278e29070750534`。
- 基线与收尾分支未分叉，checkpoint在main之上1个提交；保留merge commit历史，不squash、不改写checkpoint。
- 本轮新增内容限于交接/状态说明、必要CI覆盖、测试点击/滚动定位修正，以及重复系统底栏和大字号长草稿占满阅读区的最小修复；不扩展实验功能。CI将hosted范围从若干类扩为全部`SujiTests`，加`BaziThemeHandoffUITests`与`NatalReadingReportUITests`，保留已有UI用例。
- 公开仓库。显式选择源码、合成fixtures、脚本、脱敏诊断、方案与评审；不纳入真实出生资料、原始在线响应、私有配置、截图、构建目录或xcresult。脱敏索引内的原始文件路径只描述本地保留位置。

## 本次本地回归

| 检查 | 结果 |
| --- | --- |
| `git diff --check` | 通过；提交前对暂存内容再次执行 |
| SwiftUI-only仓库检查 | 通过 |
| 配置隔离Python测试 | 4项通过，不改本机生产公开配置 |
| Supabase离线回归 | 15项通过，含PostgreSQL配额/RLS/并发/日期边界；不调用DeepSeek |
| Core全量，America/Los_Angeles | 516项，1skip，0失败，193.4秒 |
| hosted App测试 | 61项，2在线专用skip，0失败 |
| 引擎typecheck / Jest | typecheck通过；77组、1016项通过 |
| 引擎对照 | 7项检查通过；25份fixture一致（天文角度容差1e-9度，其余精确） |
| 引擎bundle与notice重建 | 重建成功，tracked资源无差异 |
| 工程生成与脚本语法 | 工程重新生成字节未变；3个JS/1个Python/1个Shell诊断脚本语法通过 |
| 相关原生UI首轮 | 25项，21通过、4失败；失败证据保留，见下方定位 |
| 中间复验 | 10项，7通过、3失败；来源折叠已过，进一步暴露聊天内容区和表单反向滚动的测试定位问题 |
| 重复底栏定向RED | 1项真实UI失败，断言系统底栏不应和自定义导航同时存在 |
| 第三轮hosted与UI | hosted 61项、2skip、0失败；UI 12项中10通过、2失败，继续定位在大字号长草稿返回与应期unit定位 |
| 最后定向验证 | 3项通过、0失败，234.2秒；大字号完整往返、普通草稿往返、应期完整确认/补充 |

本次本地日志在忽略目录`native/artifacts/remote-main-handoff-2026-09-23/`，**不是远端附件**。上表为随仓库提交的结果摘要；在线CI重新运行对应版本，原生xcresult与截图由既有`native-test-results` artifact发布，可从PR或main对应Actions run下载。该artifact属于CI合成fixture运行，不含用户资料。

## 可重跑（无模型费用）

```sh
python3 native/scripts/check-native-only.py
python3 -m unittest discover -s native/scripts/tests -v
TZ=America/Los_Angeles swift test --package-path native/Core
npm ci --prefix supabase
npm test --prefix supabase
# 引擎与资源一致性：同CI
npm ci --prefix native/Engine
npm run typecheck --prefix native/Engine
npm test --prefix native/Engine
npm run build --prefix native/Engine
git diff --exit-code -- native/Resources/mingli.js native/Resources/ThirdPartyNotices.txt
node --test native/scripts/check-engine-fixtures.test.mjs
node native/scripts/check-engine-fixtures.mjs
```

原生使用可用iPhone模拟器UDID，保留模拟器签名；不要共享同一DerivedData并发构建。不要设置`SUJI_LIVE_READING_CONFIG`，两项在线专用测试会明确skip。公开配置按`native/README.md`准备，CI使用离线占位配置。

```sh
xcodebuild -project native/Suji.xcodeproj -scheme Suji \
  -destination 'platform=iOS Simulator,id=<available-UDID>' \
  -derivedDataPath native/DerivedDataHandoff \
  -parallel-testing-enabled NO -collect-test-diagnostics never \
  -only-testing:SujiTests \
  -only-testing:SujiUITests/BaziThemeHandoffUITests \
  -only-testing:SujiUITests/NatalReadingReportUITests \
  -only-testing:SujiUITests/SujiUITests \
  -only-testing:SujiUITests/CastQuestionUITests \
  -only-testing:SujiUITests/NatalAstronomyUITests test
```

本地本轮复用`native/DerivedDataTheme`串行构建，仅结果包采用新路径。以上命令不能验证真实问答内容质量；原32题18失败及主题真实失败维持原判。真机、人工VoiceOver、R2新方案实施/内容/UI/真实问答验收均未进行。


## 首轮UI失败定位与最小处理

首轮`native.log/native.xcresult`记录25个UI用例中的4个失败，未删除或重判：

1. `BaziThemeHandoffUITests/testLargeDarkThemeCanBeReadAndQuestionChosenExplicitly`在收起**来源**时失败，例子本身已成功收起。实际查看截图`theme-05b-large-dark-source-boundary`：来源控制已在顶部导航栏后方，但AX仍返回hittable。测试helper改为先让按钮完整进入导航栏以下再点击，保留展开/收起状态断言。
2. `CastQuestionUITests`的specialSelection、supplement、timing三例失败。失败AX树显示键盘始于y=553、候选栏y=508，取用/应期开关位于y=669/722；实际查看timing录屏末帧也确认表单被键盘挡住。旧app-wide手势起点落在键盘，未滚动表单；直接按hittable点击会误触键盘。helper改为在导航栏和键盘候选栏之间的可见表单区域滚动，控件完整露出后继续原有点击和功能断言。

这两项是测试驱动的可见性定位修正，不是修改业务开关、不绕过起盘确认、不更换模拟器数据、不降低大字号或禁用键盘。首轮报告其余3项、天文1项、主流程11项均通过；复验只重跑受影响主题5项与占问5项。CI随后仍运行完整配置。


中间复验`ui-recheck.log/.xcresult`保留：来源折叠已正常，流程继续到大字号问道，手势却落在输入区，未滚动上方内容；实际查看`theme-06-large-dark-handoff`确认该状态。最终测试helper按`chat.composer`实际上边界限定内容手势，只对主题内容按钮要求完整露出，不把顶部关闭按钮误当滚动内容。占问回到取用/应期选择器的反向滚动也统一使用同一可见区域helper，避免剩余app-wide滑动误触键盘；不删功能断言。

同张截图还发现真正的界面缺陷：默认系统Tab Bar与自定义底栏同时显示。新增`app.tabBars.firstMatch.exists == false`断言后，`tabbar-red.log/.xcresult`记录1项失败（29.7秒），证明不是单纯截图猜测。最小产品修正是在各Tab内容上明确隐藏系统Tab Bar；保留既有自定义底栏、页面顺序和数据行为。最终回归保留此断言，并加跑日签揭页及深色大字号主流程。该修正属于合并前的导航回归修复，不是实施R2。


第三轮`final-ui.log/.xcresult`保留。重复底栏回归、普通草稿往返、取用/补充、日签和深色主流程通过；两处失败未重判：

- 大字号选择建议问题后出现`Invalid frame dimension`，返回按钮无法到达；长草稿使用最多5行使底部输入区域占满内容空间。最后只在accessibility字号将可见输入行数改为1–2，仍保留完整文本并让字段内部滚动；普通字号不变。该轮主题录屏不能被ffmpeg读取（缺moov），不伪称已读到其末帧；保留原始结果包，并在最后定向运行增加填入草稿后的显式PNG截图。
- 应期单位控件在Form底部返回后已位于上方且被虚拟化，未知frame时默认向下查找走错方向。实际查看最后录屏确认停在确认区底部；对这一有明确页面顺序的反向查找指定`towardTop`，功能断言保留。

最后定向覆盖大字号完整阅读→问道选择长草稿→返回、正常字号既有草稿往返、应期对象/单位/截止日期及补充再确认。结果和截图必须读回后才能写通过；不把中途失败隐去。


## 收尾本地结论

截至最后定向运行，首轮4个UI失败均已有后续通过证据；最终不是一次25项全绿的本地运行，不能合并不同轮次伪造单轮统计。Core、引擎、后端和hosted结果见表；本轮后续业务变化仅为Tab Bar可见性与accessibility输入行数。GitHub CI将在最终提交上重新执行完整既有配置及新增用例。

已实际查看最后的`theme-06b-large-dark-filled-draft`、`theme-07-large-dark-return`PNG：只有自定义底栏，长草稿内部滚动，回到册页；不代表人工VoiceOver或完整设计验收。普通草稿往返仍出现一次SwiftUI瞬态`Invalid frame dimension`警告，测试最终通过，未定位其所有触发原因，作为后续布局观察项保留，不宣称日志无警告。

磁盘紧张时仅清理了本轮从xcresult导出的重复视频/序列化快照，以及已结束Core构建的可再生编译缓存；保留全部原始xcresult、失败日志、线上原始证据、PNG和源码。新旧真实问答失败判定不变。没有部署、安装、正式发布或新增模型请求。
