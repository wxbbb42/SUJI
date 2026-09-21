# 四余、遇卯命度与十二宫

本次提供明确方法的固定本命计算，随账户档案保存。没有加入生肖或宿曜关系，也未把星位直接解释为事件结果。

## 来源与方法

- `tushu567-mao-life-degree-rev1942530`：《古今图书集成·艺术典567卷》所收《张果星宗》电子转录，维基文库版本1942530。原文“以生時加太陽宮，順數遇卯，即是命宮”“以太陽之度對著命宮之度，即是命度”。太阳子宫、酉时得午命宫；十二宫逆地支。此处取得的正文补足此前《张果星宗》文本的缺页，但仍未完成古度表复原。
- `suji-mao-modern-coordinate-policy-v1`：明确的现代适配。固定UTC+8时支，以热带黄道30°等宫及太阳宫内度安命。命点纬度0，转日期真赤经，参考既有现代28颗距星。不能称地平升点、当地日出法或古命度。原文与产品坐标政策分别署名。
- 罗北计南，取平升降交点；IERS2003/Simon1994参数由ERFA v2.0.1核对。TT代TDB符合ERFA说明。
- 月孛采用平均月球轨道远地点。`F-l+180°`是轨道内角，必须以5.1453964°倾角投影，不能直接把它加到交点经度上作为黄经；J2000两者相差约0.115°。倾角值由Swiss2.10.03引用AA1996 D2核对，未声称阅读了纸本年历。
- 紫炁采用Moira固定提交7474e5f的现代参数：1975-03-13 16:00 UTC、230.5°、10227.1792日均速。该提交 `moira_s.prop` 第1149行明确写有“on March 13, 1975 at 16:00 GMT”，由此核定历元时区。它是约定推算点，无实体天体的独立星历对照。没有复制Moira/Swiss实现代码到产品。

源正文、版本、SHA256、ERFA许可及复现脚本在 `native/Engine/validation/research-qizheng/completion-2026-09-21/`。ERFA声明由构建脚本纳入应用ThirdPartyNotices。

Moira属性证据另存原始响应 `moira_s.prop`（UTF-16BE，含BOM；SHA256 `9e484843e3d2d433851fa6fb8a0c5ff3062f0114476493ecbacb5931f5518a93`）与可读转码 `moira_s.prop.utf8.txt`（UTF-8，保留BOM与原换行；SHA256 `483b69d733bf5599ba2a7e9f999e0af1521d860d9218d9666ee04edfe03ab0f0`）。`modern-parameters.json` 分别记录原始URL、文件名、编码、两份哈希与转码过程。此前未说明对象的 `sha256` 实为转码文本哈希，现已改为明确的 `rawSHA256` / `textSHA256`；这些归档仅用于研究证据，不进入产品资源。

## 独立验证

在相同TT输入下，以独立Python ERFA2.0.1.5与Swiss2.10.03核对1901–2100每季15日12点北京时间，共800时刻。比较阈值预先设为1角秒，未放宽；所有样本通过。

| 对象/坐标 | 对Swiss最大差异 |
| --- | ---: |
| 平交点黄经 | 0.210523角秒 |
| 月孛黄经 | 0.223632角秒 |
| 月孛黄纬 | 0.004087角秒 |

这证明抽样中的所选平轨道公式一致性，不是全时刻物理误差上界，也不验证预测效力。七曜原有未来ΔT差异记录仍保留。

命宫测试从原文地支计数独立核对144种太阳宫/时支组合，并验证原文例子、十二宫顺序、0/360°、05/07/23时边界、无效输入。固定档案问答读取不再调用七曜和距星星历；只做低成本派生关系与版本完整性校验。

## 原生与工具契约

`natal-astronomy`必含`fourResiduals`与`lifeDegree`，引擎版本改变使旧缓存重建；单七曜查询保持其既有投影，工具新增四余和命度单项读取。Swift严格校验时间、源标识、方法、升降交点、太阳基准、时支、宫序、宫主/度主和入宿关系。所有浮点容差只用于明确角度字段，不用于时间、身份、索引或参数周期。

界面分别展示七曜真黄道、四余平轨道、遇卯命度与十二宫；AI显式字段索引保留方法和来源。生日精度未知、古度、七政吉凶及流限未提供，不将现代参考宿当作唯一历史体系。

## 复跑

```sh
node native/Engine/validation/research-qizheng/completion-2026-09-21/sample-residuals.mjs
# 单独研究虚拟环境安装 pyswisseph==2.10.3.2 pyerfa==2.0.1.5
python native/Engine/validation/research-qizheng/completion-2026-09-21/compare-residuals.py
npm test --prefix native/Engine -- --runTestsByPath src/astronomy/__tests__/Residuals.test.ts src/astronomy/__tests__/LifeDegree.test.ts src/astronomy/__tests__/ResidualsLifeIntegration.test.ts
```
