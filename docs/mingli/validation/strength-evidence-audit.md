# 八字强弱证据与十进制边界审计

审计日期：2026-09-19 至 2026-09-20。基线代码：`7de86a8`。范围为 `BaziEngine.computeWuXingStrength`、`structural.ts` 的月令/根气/五档矩阵及 `get_domain` 工具回执；不重复历法逐日审计，不重写历史结果。

本轮完成可复算的贡献明细与结构证据，并修复一项确证的浮点翻档错误。**没有建立完整传统旺衰算法，也没有验证命理对现实事件的预测能力。** 月令、根气、透干、制化及调候的完整判断仍未实现；把既有数值改成文字标签不会消除这些缺口。

## 两套输出实际在算什么

| 项目 | `wuXingStrength` 固定权重计数 | `riZhuStructure` 月令/根气矩阵 |
|---|---|---|
| 输入 | 四天干、四支所有藏干 | 日干、月支本气、四支藏干、日坐刃/支持 |
| 日干本人 | 计入同类一次，权重1 | 用作关系观察基准；不作为额外根气加分 |
| 其余透干 | 各计1 | **不参与五档强弱**；虽传入聚合函数，会用于其他字段，如清浊 |
| 地支处理 | 每支藏干权重合计1；四支合计4 | 本/中/余分别1/0.5/0.2，每支总数不固定为1 |
| 月令 | 不加权、不以月令改变计数 | 仅按月支本气五行关系查旺相休囚死；未解司令与月内用事 |
| 帮扶 | 同我 `peer` + 生我 `resource` | 同五行藏干 `bijieRoot` + 生我藏干 `yinRoot` 合计 |
| 另一侧 | 我生 `output` 为泄、我克 `wealth` 为耗、克我 `officer` 为制约 | 未把食伤财官逐项作对抗力量计入五档矩阵 |
| 阈值 | 帮扶 ≥ 克泄耗，平手归兼容偏强；原权重总和8 | 根气总量0.3/0.7/1.5/2.5分档，再结合月令与日坐作五档 |
| 用途 | 保留扶抑启发式 `yongShen/xiShen/jiShen` | 保留结构五档，供现有格局逻辑使用 |

两套数字没有同一分母，不能把 `supportTotal=4` 与 `totalRoot=2.7` 直接比较，也不能把同向标签称为独立验证。计数中的“同类”包括日主本人；`supportExcludingDayMaster` 只展示其余帮扶，不偷偷变更兼容算法的判定。

得令与失令也要说明本实现口径：旺、相都使 `deLing=true`；囚、死使 `shiLing=true`；休既非得令也非失令。得令至少带来月支本气1分，因此正常聚合输入的“得令且微根/无根”分支实际上不可达；保留原矩阵不等于认可它覆盖完整传统规则。

## 实读资料与能支持的结论

1. [《子平真诠评注》基础章](../source-texts/bazi/ziping-zhenquan/01-foundations.md)，重点第200–204行“论十干得时不旺失时不弱”。本地文件自述来自 `783164565-子平真诠评注-徐乐吾.pdf`，民国二十五年初版本电子化、`pdftotext -layout` 提取，沈文和徐注交错，尚未与印刷本逐字核校。实读短句包括“旺衰强弱四字……须分别看”“大致得时为旺，失时为衰；党众为强，助寡为弱”，以及“不以为通根……甚至求刑冲开之”的反驳。支持区分时令、党众、透干与地支根气；不支持固定8分、0.6/0.2/0.2或本项目五档矩阵为古籍精确算法。
2. [《滴天髓阐微》衰旺章](../source-texts/bazi/ditianshui-chanwei/tongshen-17-shuaiwang-zhonghe.md)，第20–34行。文件来自 Wikisource EPUB 提取，未注明印刷底本，存在明显错字、重复片段。实读“得时俱为旺论，失令便作衰看……亦死法也”“年日时中，亦有损益之权”。只能支持不凭月令一项定全局；本轮未把其中历史人物吉凶叙事转换为现实断语或准确率样本。
3. [同书精神/月令章](../source-texts/bazi/ditianshui-chanwei/tongshen-14-jingshen-shiling.md)，第61行列寅月立春后不同日数用事。与仓库其他司令表存在待审口径问题；本轮只据此明确“月支本气查表未完成司令判断”，不从一段未校转录引入新日数表。
4. [《渊海子平》基础章](../source-texts/bazi/yuanhai-ziping/01-foundations.md)，第70行以甲乙为例区分金官杀、土财、水印、火食伤、木同类；第140行提醒“须随格局喜忌推之，不可执一”。用于方向核对，不为工程权重和确定命运断语背书。
5. 外部实际读取 [`bazi-life-curves/scripts/_bazi_core.py`](https://github.com/XiaoChu-1208/bazi-life-curves/blob/ad8fdeceac3d74b9682ce1df362e7a497dc91d2c/scripts/_bazi_core.py#L192-L283)，固定提交 `ad8fdeceac3d74b9682ce1df362e7a497dc91d2c`。第192–209行解释区分“同五行藏干贡献”和“生我五行藏干贡献”的动机，并自述根档阈值“经12 case校准”；第210、238–281行给出1/0.5/0.2及合计分档。实际读取该提交的 [MIT LICENSE](https://github.com/XiaoChu-1208/bazi-life-curves/blob/ad8fdeceac3d74b9682ce1df362e7a497dc91d2c/LICENSE)，署名 `2026 XiaoChu-1208 and bazi-life-curves contributors`。这是既有参数的工程出处，12例自述不等于独立实证验证，也不能把刚创建、少量使用的项目称为经过成熟预测验证的库。首次误取根目录 `_bazi_core.py` 返回404，之后核到真实 `scripts/` 路径；未把失败请求列为已读正文。
6. 已读 [工程阈值敏感性报告](structural-threshold-sensitivity.md)、[历法/八字研究报告](calendar-bazi-research.md)，以及既有《子平真诠》《渊海子平》阅读笔记。[早期体用笔记](../reading-notes/dichuixui-tiyong.md) 明确是抓取失败后的 stub；其中 paraphrase **不作为原文证据**。

古代正文与现代点校、转录的权利状态不可混称。此轮没有取得上述电子转录的完整复用许可链，未新增整本转录、未复制未明许可的新库代码；仅列短引文、定位及局限。开源参数来源有MIT许可，不意味着古籍转录因此也获得MIT许可。

实读本地关键文件 SHA256（固定本次取读内容，不暗示版本已校勘）：

```text
8ea626e3744bb7129351b57dd3c4d6b6be595484345d8ea8101df50611993596  ziping-zhenquan/01-foundations.md
3b5dc065528e90a9f5173f2a564a4e77170b39aa59450a979da24aa4778594de  ditianshui-chanwei/tongshen-17-shuaiwang-zhonghe.md
c1d2a85f37c65f7804e5c01aff08dcf34cb0deb15df32cf7ad86cb8c8fd7ab81  ditianshui-chanwei/tongshen-14-jingshen-shiling.md
11c85d2a5230eb63e62ebd4bac462012254d54b32ccfe53242a1dc3456b1b5c7  yuanhai-ziping/01-foundations.md
```

## 确证错误：4∶4被浮点运算翻成偏弱

实际出生输入：**1990-03-15 12:00，北京标准时间UTC+08:00，男，不启用真太阳时**。四柱为`庚午 己卯 己卯 庚午`，日主己土。性别不参与强弱计数。

手算：四干庚己己庚使金2、土2；两个午各藏丁0.7/己0.3，两个卯各藏乙1。最终金2、木2、水0、火1.4、土2.6。土同类2.6 + 火印1.4 = **4**，金食伤2 + 木官杀2 + 水财0 = **4**。原代码的土累计为 `2 + 0.3 + 0.3 = 2.5999999999999996`，加火1.4后为 `3.9999999999999996`；旧 `>=4` 返回false。

| 字段 | `7de86a8` 原函数实际结果 | 修后 |
|---|---|---|
| `riZhuStrong` | false | true |
| `yongShen` | 火 | 木 |
| `xiShen` | 土 | 水 |
| `jiShen` | 木 | 土 |
| `strongest` / `weakest` | 土 / 水 | 土 / 水 |

修复方式是把**既有十分位权重**累计成整数单位，最后除10输出。没有修改权重、`>=`门槛或金木水火土并列次序。扶抑选择与证据共享同一次整数合计，避免解释为4∶4而布尔仍为false。五行极值也用整数比较，因此过去由浮点误差拆散的真正并列，会恢复声明的并列次序；这也是有意的算术修正，不宣称所有历史极值字段逐一未变。

相邻时辰作为两侧反例：同日10:00四柱`庚午 己卯 己卯 己巳`，土3.5+火1.3=4.8，对侧3.2，取木/水/土；14:00为`庚午 己卯 己卯 辛未`，土2.9+火0.9=3.8，对侧4.2，取火/土/木。三例均按同一阈值解释。

错误先用独立十分位手算与旧函数对照发现，再以实际日期确认。一次96个正午输入的小范围核对（1990–2025每隔5年、每月15日）中观察到上例；**不把这个有限检查当成所有日期的差异枚举**。没有重新生成既有1152例敏感性历史结果或运行旧200年调查。

## 新证据合同与完整例

直接命盘路径为 `/wuXingStrength/evidence`、`/riZhuStructure/evidence`。`get_domain` 将其分别透传为 `/bazi/strengthReference/evidence`、`/bazi/structureReference/evidence`；后者是本轮补齐的新投影。`ai/tools/bazi.ts` 的六亲/神煞工具不承担此聚合投影，接线位于 `ai/tools/index.ts`。

计数 `version=weighted-count-v1`：

- `contributions[]` 列每柱、`stem/hidden-stem`、干/支/五行、权重、日主视角关系、是否日干本人。顺序为四天干，再按年/月/日/时列藏干。
- `elementTotals`、`relationTotals`、`supportTotal`、`drainTotal`、`total` 使用同一份贡献累计。
- `dayMasterContribution` 与 `supportExcludingDayMaster` 说明日干计入问题；后者不参与旧字段决策。
- `threshold`、`monthWeightApplied=false`、完整 `strongestElements/weakestElements` 和 `tieBreakOrder` 使门槛、未使用的月令及并列选择可检查。

结构 `version=month-root-matrix-v1`：

- `monthBranch/monthMainQi/monthMainElement/monthRelation/monthMethod` 说明月支本气查表，而非已解月内司令。
- `sameElementRoots` 与 `resourceSupport` 分开列同五行藏干和生我藏干，另给有无与日坐布尔。这里只使用狭义、可直接检查的藏干身份，**没有声称传统所有流派都把“通根”限定为同五行藏干**。
- `rootWeights/rootLabelBands` 公布参数与左闭右开区间；`strengthRule` 与 `strength` 共用同一矩阵决策。
- `exposedStemsUsedForStrength=false`、`sourceRefs/limitations` 公开尚未纳入的条件。

实际出生例：**1990-08-15 10:00，女，北京标准时间，不启用真太阳时**，四柱`庚午 甲申 壬子 乙巳`。计数共有13项：4天干+午2藏干+申3藏干+子1藏干+巳3藏干。

| 壬水视角 | 计数构成 | 小计 |
|---|---|---:|
| 同我（水） | 日干壬1、申藏壬0.2、子藏癸1 | 2.2 |
| 生我（金） | 年干庚1、申藏庚0.6、巳藏庚0.2 | 1.8 |
| 我生（木，泄） | 月干甲1、时干乙1 | 2 |
| 我克（火，耗） | 午藏丁0.7、巳藏丙0.6 | 1.3 |
| 克我（土，制约） | 午藏己0.3、申藏戊0.2、巳藏戊0.2 | 0.7 |

帮扶4、克泄耗4、总数8、日干本人1、扣除本人后的帮扶3。兼容计数按平手门槛归偏强，扶抑用/喜/忌为土/火/水。结构矩阵则把申中壬0.5与子中癸1列为同类根1.5，把申中庚1与巳中庚0.2列为印支持1.2，总2.7；申主气庚金生壬水，五态为相，兼容得令=true，日坐子有根/刃，命中 `de-ling-strong-root-with-seat-support`，返回 `taiwang`。这里“太旺”仍只是旧工程矩阵输出，不是由计数4∶4推导出的古籍定论。

两个必须保留的反例（人工算法输入，不冒充实际出生日期）：

- 甲日四子：同五行藏干根为空、四个癸印支持合计4，旧标签仍“强根”。解释层应说“印支持4，同类藏干根未检出”，不能转述“木根很强”。
- 甲日四支巳酉巳未：未藏乙余气0.2实际存在，但总量小于0.3，旧档名仍“无根”。解释层不能把分档字符串当作实际零根；实际零根反例为巳酉巳午。

## 验证与剩余工作

永久测试位于 [strengthEvidence.test.ts](../../../native/Engine/src/bazi/__tests__/strengthEvidence.test.ts)、[structural.test.ts](../../../native/Engine/src/bazi/__tests__/structural.test.ts) 和 [工具回执测试](../../../native/Engine/src/ai/tools/__tests__/index.test.ts)。覆盖13项明确贡献、各柱/五行/关系守恒、日主只计一次、4∶4及两侧实际取用、五类日主全部生克方向、极值并列和属性顺序、实际零根与0.2小根、印支持独立列示、0.2/0.4、0.6/0.7、1.4/1.5、2.4/2.5边界、结构忽略透干这一限制、JSON回执透传。结构3项和工具投影1项先观察到缺失证据失败，再修到通过；浮点反例已与基线原函数独立对照。

本轮实跑 `npm run typecheck --prefix native/Engine`，以及上述测试连同已有调候与干支反例共5套83项，通过；扩展到 `npm test --prefix native/Engine`，31套499项全部通过。守恒测试另覆盖12个节气月，检查全部地支的权重仍为十分位、每柱总计2。生产bundle、Swift消费、界面验证由集成任务处理，不能由本报告的TS通过代称完成。

待续：印刷底本与分层藏干口径校勘；月内司令与土月处理；得时/得地/党众与有效制化的独立规则及反例；融合时不得抹去两套工程口径冲突；不能用这些工程分数推断现实寿夭、健康、财务或关系事件。
