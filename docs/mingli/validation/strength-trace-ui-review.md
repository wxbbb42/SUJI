# 强弱依据的原生呈现复核

本轮沿用 `.impeccable.md` 的暖纸、橄榄墨色、宋体标题与系统正文，改动范围是已有强弱解释的可读性。数据解释由 `SujiCore.BaziStrengthTrace` 提供，界面不重新推断强弱。

## 截图依据与问题

基线来自 `native/Documentation/typed-reading-presentation` 的实际模拟器截图与配套 accessibility tree：

- `10-light-strength.png`、`20-dark-strength.png`：资格和结论已有层次，但扶抑依据、规则范围和局限集中在长正文里，难逐项核对。
- `10-light-evidence.png`：计算依据先列日期、领域和紫微行；用户为核对强弱进入此页时，不能立即看到强弱的计算过程。
- `30-xxxl-strength.png`：动态字号得到尊重，但长段落需要多次滚动，论据与结论相距更远。应改进分组和渐进披露，不能靠缩小辅助字号解决。
- 命盘手稿原有“较显／较弱”字段直接展示工程计数排序，名称容易与完整传统旺衰混淆。

## 实现取舍

- 聊天中的扶抑 section、计算依据和命盘手稿共用 `BaziStrengthTraceView`。明细默认折叠，正文和资格不会随折叠隐藏。
- 计算依据页优先放本次扶抑摘要；原有提问时刻、资料范围、传统文献和完整记录仍可阅读。
- “工程计数明细”“分组与边界”“月令与根气”来自经过核心校验的展示 API。长说明采用上下排，纯数值用原生 `LabeledContent`，无大数字、比例条或吉凶配色。
- 命盘手稿将“较显／较弱”改为“计数较多／计数较少”，就近说明计数不能直接当作传统强弱。
- 继承系统 Dynamic Type。展开按钮最小高度 44 pt；组标题有 header trait，长正文保留换行和文本选择。

## 验证范围

专用 Debug 界面只在 `--ui-testing` 与 `--reading-presentation-fixtures` 同时存在时启用；使用临时册页、合成出生资料和真正的本地引擎，不登录、不调用 AI。样本固定为 1990-08-15 10:00 女、经度 120，目的是观察帮扶 4 与克泄耗 4 的相等边界及日干本人一次计入。

界面测试检查浅色、深色、AX XXXL、聊天与 Profile 复用、展开收起、资格常驻、点击高度和横向边界。截图和测试结果只证明该合成样本的呈现行为，不证明传统规则预测有效，也不替代人工 VoiceOver 手势和读音测试。

首轮 `/tmp/suji-strength-trace-ui.xcresult` 的 5 项测试未通过：明细实际展开，但将 accessibility identifier 放在 `DisclosureGroup` 容器上会传递到所有子 Text，覆盖组/行自身的 identifier。失败时的 AX 树已确认内容及 4 ≥ 4 边界都存在。修正将标识放在原生展开标签上，并让测试点击标签的真实区域，避免展开后父容器的大 frame 干扰点击。首轮源文件摘要保留在 `initial-source-inputs.json`，不计为通过。

## 最终呈现与验证结果（2026-09-20）

简短扶抑回答曾在短正文后重复追加完整长注。新增真实合成界面测试先复现这一问题（`/tmp/suji-strength-trace-brief-red.xcresult`，1 项失败），再将聊天 trace 的长注关闭；完整与简短正文均已有对应限定，计算依据页和命盘页仍显示完整长注。最终截图显示短正文、启发式资格和展开入口同时可读，展开收起不会移除限定。

环境为 Xcode 26.6（17F113）、iPhone 17 Pro 模拟器、iOS 26.5（23F77），签名保持开启。按修改范围分批回归，不能把前面的失败批次称为整套通过：

| 批次 / xcresult | 实际结果 | 范围与后续 |
| --- | --- | --- |
| `/tmp/suji-strength-trace-final.xcresult` | 24 项：22 通过、2 失败 | hosted 13 通过；旧阅读 5/6 通过；强弱 UI 4/5 通过。失败为旧阅读 XXXL 的日期定位与 Profile XXXL 滚过懒加载网格后查找计数字段。 |
| `/tmp/suji-strength-trace-verified.xcresult` | 18 项：17 通过、1 失败 | 最终 Core 与最终生产 UI：hosted 13、brief、浅色、普通 Profile、Profile XXXL 通过。旧阅读 XXXL 仍失败于日期子元素定位。 |
| `/tmp/suji-strength-trace-accessibility.xcresult` | **3 项通过，0 失败** | 修正后的旧阅读 XXXL 全流程、简短扶抑界面、XXXL 长组标题与日期元数据；命令退出 0、`TEST SUCCEEDED`。 |

Profile 测试现在按阅读顺序滚动验证“计数较多／计数较少”，再查看下方摘要。旧日期问题经过实际失败录屏和 AX 树确认：原生 `LabeledContent` 同时给出子标签“提问时刻”和合并标签“提问时刻, 2026年9月19日 12:00:00 北京时间”；子标签不独立命中。测试定位完整日期标签，并核对日期，未通过增大滚动次数或缩小文字规避问题。

展开控件的实际 AX 高度也验证过：只给 label 设置 frame 时，List 内曾回报 18 pt；补充 `contentShape(Rectangle())` 后浅色 smoke 和后续回归通过 ≥44 pt 断言。最初将 identifier 放在 DisclosureGroup 导致子 identifier 被覆盖的问题，以及上述诊断失败，都保留在测试历史中。

## 实际截图复核

共归档 **25 张 PNG 和 25 份 AX 树**，每张均有 test、原 attachment、时间戳与 SHA-256，见 [capture-manifest.json](../../../native/Documentation/strength-trace-presentation/capture-manifest.json)。已实际打开核对浅色明细／边界、深色、XXXL、命盘、依据入口和 brief；没有把工程数字做成评分或比例图。

- [浅色分组与相等边界](../../../native/Documentation/strength-trace-presentation/10-light-chat-boundary.png)：同我／生我与克泄耗分项使用普通字号，日干本人一次、4 ≥ 4、月令未额外加权均相邻可读。
- [依据入口](../../../native/Documentation/strength-trace-presentation/10-light-evidence-entry.png)：摘要和完整限定先于日期元数据，展开入口清晰。
- [深色明细](../../../native/Documentation/strength-trace-presentation/20-dark-chat-first-group.png)：暖暗底色、正文与次级限定保持层级。
- [XXXL 计数字段](../../../native/Documentation/strength-trace-presentation/50-xxxl-profile-count-labels.png)：字段名不再暗示完整旺衰，系统字号得到保留。
- [最终简短回答](../../../native/Documentation/strength-trace-presentation/60-brief-chat-collapsed.png)：完整短正文与启发式资格同时可见，没有重复长注，展开入口保留。
- [XXXL 长组标题置顶](../../../native/Documentation/strength-trace-presentation/70-xxxl-structure-heading.png)：补拍并断言标题完整位于导航／合成提示与 composer 之间。后面的长正文仍需继续滚动。
- [XXXL 日期行](../../../native/Documentation/strength-trace-presentation/71-xxxl-evidence-metadata.png)：完整日期与北京时间可见，配套 AX 树保留合并标签。

较早的 `last-group` 捕获只保证组标题起点进入视口，不能据此宣称整组在一屏内可读；最终 `70-xxxl-structure-heading` 补足长标题的完整可见证据。长正文按正常滚动分段阅读，不压缩生产字号，也不宣称单张截图覆盖整组。

## 源文件和构建身份

- `source-inputs.json` 对应 baseline，聚合 SHA-256 为 `9f88410c0c5c37a530d116fabeb38902352195ef99e5a2893e432a5210e56749`。
- `final-source-inputs.json` 对应 verified；之后仅 UI 测试定位和截图调整，没有修改生产 App/Core。
- `accessibility-source-inputs.json` 对应最后一批，聚合 SHA-256 为 `0e4038b53febdff44fcd4b8bdc0292f6cb18566aaca858afd4ed1b6571b522e2`；结束后逐文件复核无变化。
- verified 与最后一批的 `Suji.debug.dylib` 均为 `fee1ed51148e96912501bc264a6be97d59e0b89afbcd7c31237886e6dcaa3a1a`，`Suji` 为 `81b0c59fa32ce540b1cbbd4f62698277d93368052b97799f589b62c474060c47`。

深色与聊天 XXXL 的 `20-`／`30-` 图来自 baseline，其后 Core 拒绝语义与 brief 重复长注发生修改；这些图通过各自源清单和 xcresult 标识，**不标成最终二进制的截图**。baseline 二进制未在重建前留存，因此没有补造其 binary hash。最终清单同时保存三批机器可读测试摘要。

范围限制：没有调用线上模型，没有做真机或 iOS 18 runtime 验证，没有人工 VoiceOver 发音、转子和手势验收，也没有验证命理预测有效性。AX 自动测试证明当前样本的结构、命中、限定保留与滚动可达性。`git diff --check` 通过。
