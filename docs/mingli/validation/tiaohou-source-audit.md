# 调候120格来源审计及退役旧表

2026-09-19，针对 `BaziEngine` 原来把月令两三个字直接当确定用神的行为做重构。

**实际行为改变**：旧 `TIAO_HOU_YONG_SHEN` 120格表已从生产引擎删除；它不再决定用神、喜神、忌神。旧表仅存于研究目录的 `legacy-tiaohou-table.json`，标记退役不可用于生产。兼容 `wuXingStrength` 的三字段改为明确的扶抑工程启发式，同时修掉日主五行力量被重复累计的问题；不把这个简化计数说成古籍精确算法。调候另以 `MingPan.tiaoHou` 输出有出处的候选、上下文条件及审核状态，**没有自动选定用神**。

120个干月组合全部有记录。119个条目与本地转录逐句核对，包含部分共享季节通论；1个（乙丑）缺少可定位的十二月条文，候选为空。119不是“119个印刷定本规则已验证”，也不是119个完整条件求解器。所有条目都保留 `editionStatus=online-transcription-unverified-against-printed-edition` 和 `automatedSelection=false`。若年内前后半月、秋分前后、透藏、缺位替代、成局/从格等条件未判定，不得把候选第一个字输出为用户的既定用神。

数据实现：`native/Engine/src/bazi/tiaohou.ts`；生成/审阅清单：`native/Engine/validation/research-calendar/build-tiaohou-registry.py`。每个条目带源文路径、行锚点、源文件SHA256、精确短引文、条件说明。测试检查引文确实存在于锁定源文件，**这只证明转录引用保真，不证明古籍预测效力或印刷底本权威**。

发现的实质差异示例：甲辰原表“庚丙，忌壬”，现按引文候选“庚壬”且保留土局等条件；甲未原表癸丙，原文通论为丁庚；甲申原表丁丙，原文丁尊庚次；壬卯原文先戊后辛，癸巳庚只是无辛的替代，乙酉秋分前后不同，不能仍压成一格常量。

乙丑的源文件虽标题称“乙木12月”，正文三冬部分只明确十月与十一月，后面再次出现十一月；没有据此虚构十二月。下一步应补有版本依据的十二月原文，再做独立校勘。现有网络转录无法代替印刷定本，Wikisource本次访问403；禁止将另一网站的摘要表悄悄填回默认值。

下表新列是**文献候选集合**，不是排序后的自动取用。详尽条件与短引文在数据记录里。旧列仅为可追溯审计，不是另一套仍启用的规则。

| 日干／节气月 | 退役旧表 yong | 新文献候选 | 状态 | 出处 |
|---|---|---|---|---|
| 甲寅 | 丙、癸 | 丙、癸 | 转录已核；条件未自动求解 | [jiamu.md:38](../source-texts/bazi/qiongtong-baojian/jiamu.md) |
| 甲卯 | 丙、庚 | 庚 | 转录已核；条件未自动求解 | [jiamu.md:50](../source-texts/bazi/qiongtong-baojian/jiamu.md) |
| 甲辰 | 庚、丙 | 庚、壬 | 转录已核；条件未自动求解 | [jiamu.md:52](../source-texts/bazi/qiongtong-baojian/jiamu.md) |
| 甲巳 | 癸、丁 | 癸、丁 | 转录已核；条件未自动求解 | [jiamu.md:68](../source-texts/bazi/qiongtong-baojian/jiamu.md) |
| 甲午 | 癸、庚 | 癸、丁、庚 | 转录已核；条件未自动求解 | [jiamu.md:76](../source-texts/bazi/qiongtong-baojian/jiamu.md) |
| 甲未 | 癸、丙 | 丁、庚 | 转录已核；条件未自动求解 | [jiamu.md:76](../source-texts/bazi/qiongtong-baojian/jiamu.md) |
| 甲申 | 丁、丙 | 丁、庚 | 转录已核；条件未自动求解 | [jiamu.md:110](../source-texts/bazi/qiongtong-baojian/jiamu.md) |
| 甲酉 | 丁、丙 | 丁、丙、庚 | 转录已核；条件未自动求解 | [jiamu.md:112](../source-texts/bazi/qiongtong-baojian/jiamu.md) |
| 甲戌 | 庚、丁 | 丁、壬、癸 | 转录已核；条件未自动求解 | [jiamu.md:126](../source-texts/bazi/qiongtong-baojian/jiamu.md) |
| 甲亥 | 庚、丙 | 庚、丁、丙 | 转录已核；条件未自动求解 | [jiamu.md:148](../source-texts/bazi/qiongtong-baojian/jiamu.md) |
| 甲子 | 丙、庚 | 丁、庚、丙 | 转录已核；条件未自动求解 | [jiamu.md:156](../source-texts/bazi/qiongtong-baojian/jiamu.md) |
| 甲丑 | 丙、庚 | 庚、丁 | 转录已核；条件未自动求解 | [jiamu.md:164](../source-texts/bazi/qiongtong-baojian/jiamu.md) |
| 乙寅 | 丙、癸 | 丙、癸 | 转录已核；条件未自动求解 | [yimu.md:34](../source-texts/bazi/qiongtong-baojian/yimu.md) |
| 乙卯 | 丙、癸 | 丙、癸 | 转录已核；条件未自动求解 | [yimu.md:40](../source-texts/bazi/qiongtong-baojian/yimu.md) |
| 乙辰 | 癸、丙 | 癸、丙 | 转录已核；条件未自动求解 | [yimu.md:50](../source-texts/bazi/qiongtong-baojian/yimu.md) |
| 乙巳 | 癸、丙 | 癸、丙 | 转录已核；条件未自动求解 | [yimu.md:68](../source-texts/bazi/qiongtong-baojian/yimu.md) |
| 乙午 | 癸、丙 | 癸、丙 | 转录已核；条件未自动求解 | [yimu.md:74](../source-texts/bazi/qiongtong-baojian/yimu.md) |
| 乙未 | 癸、丙 | 丙、癸 | 转录已核；条件未自动求解 | [yimu.md:80](../source-texts/bazi/qiongtong-baojian/yimu.md) |
| 乙申 | 丙、癸 | 己、丙 | 转录已核；条件未自动求解 | [yimu.md:102](../source-texts/bazi/qiongtong-baojian/yimu.md) |
| 乙酉 | 丙、癸 | 癸、丙 | 转录已核；条件未自动求解 | [yimu.md:110](../source-texts/bazi/qiongtong-baojian/yimu.md) |
| 乙戌 | 癸、丙 | 癸、辛 | 转录已核；条件未自动求解 | [yimu.md:124](../source-texts/bazi/qiongtong-baojian/yimu.md) |
| 乙亥 | 丙、戊 | 丙、戊 | 转录已核；条件未自动求解 | [yimu.md:132](../source-texts/bazi/qiongtong-baojian/yimu.md) |
| 乙子 | 丙、戊 | 丙 | 转录已核；条件未自动求解 | [yimu.md:136](../source-texts/bazi/qiongtong-baojian/yimu.md) |
| 乙丑 | 丙、戊 | — 待补原文 | 缺失原文段 | [三冬乙木（本转录见十月与十一月，未见十二月独立段）](../source-texts/bazi/qiongtong-baojian/yimu.md) |
| 丙寅 | 壬、庚 | 壬、庚 | 转录已核；条件未自动求解 | [binghuo.md:40](../source-texts/bazi/qiongtong-baojian/binghuo.md) |
| 丙卯 | 壬、庚 | 壬 | 转录已核；条件未自动求解 | [binghuo.md:82](../source-texts/bazi/qiongtong-baojian/binghuo.md) |
| 丙辰 | 壬、甲 | 壬、甲 | 转录已核；条件未自动求解 | [binghuo.md:104](../source-texts/bazi/qiongtong-baojian/binghuo.md) |
| 丙巳 | 壬、庚 | 壬、庚 | 转录已核；条件未自动求解 | [binghuo.md:118](../source-texts/bazi/qiongtong-baojian/binghuo.md) |
| 丙午 | 壬、庚 | 壬、庚 | 转录已核；条件未自动求解 | [binghuo.md:142](../source-texts/bazi/qiongtong-baojian/binghuo.md) |
| 丙未 | 壬、庚 | 壬、庚 | 转录已核；条件未自动求解 | [binghuo.md:164](../source-texts/bazi/qiongtong-baojian/binghuo.md) |
| 丙申 | 壬、甲 | 壬 | 转录已核；条件未自动求解 | [binghuo.md:188](../source-texts/bazi/qiongtong-baojian/binghuo.md) |
| 丙酉 | 壬、甲 | 壬 | 转录已核；条件未自动求解 | [binghuo.md:202](../source-texts/bazi/qiongtong-baojian/binghuo.md) |
| 丙戌 | 甲、壬 | 甲、壬、癸 | 转录已核；条件未自动求解 | [binghuo.md:224](../source-texts/bazi/qiongtong-baojian/binghuo.md) |
| 丙亥 | 甲、戊 | 甲、戊、庚 | 转录已核；条件未自动求解 | [binghuo.md:246](../source-texts/bazi/qiongtong-baojian/binghuo.md) |
| 丙子 | 甲、戊 | 壬、戊 | 转录已核；条件未自动求解 | [binghuo.md:264](../source-texts/bazi/qiongtong-baojian/binghuo.md) |
| 丙丑 | 甲、壬 | 壬、甲 | 转录已核；条件未自动求解 | [binghuo.md:286](../source-texts/bazi/qiongtong-baojian/binghuo.md) |
| 丁寅 | 甲、庚 | 庚、甲 | 转录已核；条件未自动求解 | [dinghuo.md:34](../source-texts/bazi/qiongtong-baojian/dinghuo.md) |
| 丁卯 | 甲、庚 | 庚、甲 | 转录已核；条件未自动求解 | [dinghuo.md:56](../source-texts/bazi/qiongtong-baojian/dinghuo.md) |
| 丁辰 | 甲、庚 | 甲、庚 | 转录已核；条件未自动求解 | [dinghuo.md:76](../source-texts/bazi/qiongtong-baojian/dinghuo.md) |
| 丁巳 | 甲、庚 | 甲、庚 | 转录已核；条件未自动求解 | [dinghuo.md:86](../source-texts/bazi/qiongtong-baojian/dinghuo.md) |
| 丁午 | 壬、庚 | 壬、庚、甲 | 转录已核；条件未自动求解 | [dinghuo.md:102](../source-texts/bazi/qiongtong-baojian/dinghuo.md) |
| 丁未 | 甲、壬 | 甲、壬 | 转录已核；条件未自动求解 | [dinghuo.md:132](../source-texts/bazi/qiongtong-baojian/dinghuo.md) |
| 丁申 | 甲、庚 | 甲、庚、丙 | 转录已核；条件未自动求解 | [dinghuo.md:176](../source-texts/bazi/qiongtong-baojian/dinghuo.md) |
| 丁酉 | 甲、庚 | 甲、丙、庚、乙 | 转录已核；条件未自动求解 | [dinghuo.md:154](../source-texts/bazi/qiongtong-baojian/dinghuo.md) |
| 丁戌 | 甲、壬 | 甲、庚 | 转录已核；条件未自动求解 | [dinghuo.md:154](../source-texts/bazi/qiongtong-baojian/dinghuo.md) |
| 丁亥 | 甲、庚 | 甲、庚、癸、戊 | 转录已核；条件未自动求解 | [dinghuo.md:226](../source-texts/bazi/qiongtong-baojian/dinghuo.md) |
| 丁子 | 甲、庚 | 甲、庚、癸、戊 | 转录已核；条件未自动求解 | [dinghuo.md:226](../source-texts/bazi/qiongtong-baojian/dinghuo.md) |
| 丁丑 | 甲、庚 | 甲、庚、癸、戊 | 转录已核；条件未自动求解 | [dinghuo.md:226](../source-texts/bazi/qiongtong-baojian/dinghuo.md) |
| 戊寅 | 丙、甲 | 丙、甲、癸 | 转录已核；条件未自动求解 | [wutu.md:42](../source-texts/bazi/qiongtong-baojian/wutu.md) |
| 戊卯 | 丙、甲 | 丙、甲、癸 | 转录已核；条件未自动求解 | [wutu.md:42](../source-texts/bazi/qiongtong-baojian/wutu.md) |
| 戊辰 | 甲、丙 | 甲、丙、癸 | 转录已核；条件未自动求解 | [wutu.md:42](../source-texts/bazi/qiongtong-baojian/wutu.md) |
| 戊巳 | 壬、甲 | 甲、丙、癸 | 转录已核；条件未自动求解 | [wutu.md:80](../source-texts/bazi/qiongtong-baojian/wutu.md) |
| 戊午 | 壬、甲 | 壬、甲、丙 | 转录已核；条件未自动求解 | [wutu.md:98](../source-texts/bazi/qiongtong-baojian/wutu.md) |
| 戊未 | 壬、癸 | 癸、丙、甲 | 转录已核；条件未自动求解 | [wutu.md:108](../source-texts/bazi/qiongtong-baojian/wutu.md) |
| 戊申 | 丙、癸 | 丙、癸、甲 | 转录已核；条件未自动求解 | [wutu.md:132](../source-texts/bazi/qiongtong-baojian/wutu.md) |
| 戊酉 | 丙、癸 | 丙、癸 | 转录已核；条件未自动求解 | [wutu.md:148](../source-texts/bazi/qiongtong-baojian/wutu.md) |
| 戊戌 | 甲、丙 | 甲、癸、丙 | 转录已核；条件未自动求解 | [wutu.md:156](../source-texts/bazi/qiongtong-baojian/wutu.md) |
| 戊亥 | 丙、甲 | 甲、丙 | 转录已核；条件未自动求解 | [wutu.md:186](../source-texts/bazi/qiongtong-baojian/wutu.md) |
| 戊子 | 丙、甲 | 丙、甲 | 转录已核；条件未自动求解 | [wutu.md:204](../source-texts/bazi/qiongtong-baojian/wutu.md) |
| 戊丑 | 丙、甲 | 丙、甲 | 转录已核；条件未自动求解 | [wutu.md:204](../source-texts/bazi/qiongtong-baojian/wutu.md) |
| 己寅 | 丙、癸 | 丙、戊 | 转录已核；条件未自动求解 | [jitu.md:42](../source-texts/bazi/qiongtong-baojian/jitu.md) |
| 己卯 | 丙、癸 | 甲、癸 | 转录已核；条件未自动求解 | [jitu.md:50](../source-texts/bazi/qiongtong-baojian/jitu.md) |
| 己辰 | 丙、癸 | 丙、癸、甲 | 转录已核；条件未自动求解 | [jitu.md:70](../source-texts/bazi/qiongtong-baojian/jitu.md) |
| 己巳 | 癸、丙 | 癸、丙、辛 | 转录已核；条件未自动求解 | [jitu.md:92](../source-texts/bazi/qiongtong-baojian/jitu.md) |
| 己午 | 癸、丙 | 癸、丙、辛 | 转录已核；条件未自动求解 | [jitu.md:92](../source-texts/bazi/qiongtong-baojian/jitu.md) |
| 己未 | 癸、丙 | 癸、丙、辛 | 转录已核；条件未自动求解 | [jitu.md:92](../source-texts/bazi/qiongtong-baojian/jitu.md) |
| 己申 | 丙、癸 | 癸、丙、辛 | 转录已核；条件未自动求解 | [jitu.md:134](../source-texts/bazi/qiongtong-baojian/jitu.md) |
| 己酉 | 丙、癸 | 癸、丙、辛 | 转录已核；条件未自动求解 | [jitu.md:134](../source-texts/bazi/qiongtong-baojian/jitu.md) |
| 己戌 | 甲、癸 | 甲、癸、丙、辛 | 转录已核；条件未自动求解 | [jitu.md:134](../source-texts/bazi/qiongtong-baojian/jitu.md) |
| 己亥 | 丙、甲 | 丙、甲、戊 | 转录已核；条件未自动求解 | [jitu.md:150](../source-texts/bazi/qiongtong-baojian/jitu.md) |
| 己子 | 丙、甲 | 丙、甲、丁 | 转录已核；条件未自动求解 | [jitu.md:150](../source-texts/bazi/qiongtong-baojian/jitu.md) |
| 己丑 | 丙、甲 | 丙、甲、丁 | 转录已核；条件未自动求解 | [jitu.md:150](../source-texts/bazi/qiongtong-baojian/jitu.md) |
| 庚寅 | 戊、丁 | 丙、甲 | 转录已核；条件未自动求解 | [gengjin.md:20](../source-texts/bazi/qiongtong-baojian/gengjin.md) |
| 庚卯 | 丁、甲 | 丁、甲、庚 | 转录已核；条件未自动求解 | [gengjin.md:42](../source-texts/bazi/qiongtong-baojian/gengjin.md) |
| 庚辰 | 甲、丁 | 甲、丁 | 转录已核；条件未自动求解 | [gengjin.md:70](../source-texts/bazi/qiongtong-baojian/gengjin.md) |
| 庚巳 | 壬、戊 | 壬、戊、丙 | 转录已核；条件未自动求解 | [gengjin.md:90](../source-texts/bazi/qiongtong-baojian/gengjin.md) |
| 庚午 | 壬、己 | 壬、癸 | 转录已核；条件未自动求解 | [gengjin.md:100](../source-texts/bazi/qiongtong-baojian/gengjin.md) |
| 庚未 | 丁、甲 | 丁、甲 | 转录已核；条件未自动求解 | [gengjin.md:106](../source-texts/bazi/qiongtong-baojian/gengjin.md) |
| 庚申 | 丁、甲 | 丁、甲 | 转录已核；条件未自动求解 | [gengjin.md:128](../source-texts/bazi/qiongtong-baojian/gengjin.md) |
| 庚酉 | 丁、甲 | 丁、甲、丙 | 转录已核；条件未自动求解 | [gengjin.md:136](../source-texts/bazi/qiongtong-baojian/gengjin.md) |
| 庚戌 | 甲、壬 | 甲、壬 | 转录已核；条件未自动求解 | [gengjin.md:158](../source-texts/bazi/qiongtong-baojian/gengjin.md) |
| 庚亥 | 丁、甲 | 丁、丙、甲 | 转录已核；条件未自动求解 | [gengjin.md:180](../source-texts/bazi/qiongtong-baojian/gengjin.md) |
| 庚子 | 丁、丙 | 丁、甲、丙 | 转录已核；条件未自动求解 | [gengjin.md:194](../source-texts/bazi/qiongtong-baojian/gengjin.md) |
| 庚丑 | 丙、丁 | 丙、丁、甲 | 转录已核；条件未自动求解 | [gengjin.md:214](../source-texts/bazi/qiongtong-baojian/gengjin.md) |
| 辛寅 | 己、壬 | 己、壬 | 转录已核；条件未自动求解 | [xinjin.md:20](../source-texts/bazi/qiongtong-baojian/xinjin.md) |
| 辛卯 | 壬、甲 | 壬、甲 | 转录已核；条件未自动求解 | [xinjin.md:34](../source-texts/bazi/qiongtong-baojian/xinjin.md) |
| 辛辰 | 壬、庚 | 壬、甲 | 转录已核；条件未自动求解 | [xinjin.md:64](../source-texts/bazi/qiongtong-baojian/xinjin.md) |
| 辛巳 | 壬、庚 | 壬 | 转录已核；条件未自动求解 | [xinjin.md:74](../source-texts/bazi/qiongtong-baojian/xinjin.md) |
| 辛午 | 壬、癸 | 己、壬、癸 | 转录已核；条件未自动求解 | [xinjin.md:84](../source-texts/bazi/qiongtong-baojian/xinjin.md) |
| 辛未 | 壬、庚 | 壬、庚、甲 | 转录已核；条件未自动求解 | [xinjin.md:94](../source-texts/bazi/qiongtong-baojian/xinjin.md) |
| 辛申 | 壬、甲 | 壬、甲、戊 | 转录已核；条件未自动求解 | [xinjin.md:112](../source-texts/bazi/qiongtong-baojian/xinjin.md) |
| 辛酉 | 壬、甲 | 壬、甲 | 转录已核；条件未自动求解 | [xinjin.md:118](../source-texts/bazi/qiongtong-baojian/xinjin.md) |
| 辛戌 | 壬、甲 | 壬、甲 | 转录已核；条件未自动求解 | [xinjin.md:146](../source-texts/bazi/qiongtong-baojian/xinjin.md) |
| 辛亥 | 壬、丙 | 壬、丙 | 转录已核；条件未自动求解 | [xinjin.md:174](../source-texts/bazi/qiongtong-baojian/xinjin.md) |
| 辛子 | 丙、壬 | 壬、丙 | 转录已核；条件未自动求解 | [xinjin.md:180](../source-texts/bazi/qiongtong-baojian/xinjin.md) |
| 辛丑 | 丙、壬 | 丙、壬 | 转录已核；条件未自动求解 | [xinjin.md:188](../source-texts/bazi/qiongtong-baojian/xinjin.md) |
| 壬寅 | 庚、戊 | 庚、丙、戊 | 转录已核；条件未自动求解 | [renshui.md:34](../source-texts/bazi/qiongtong-baojian/renshui.md) |
| 壬卯 | 戊、庚 | 戊、辛、庚 | 转录已核；条件未自动求解 | [renshui.md:48](../source-texts/bazi/qiongtong-baojian/renshui.md) |
| 壬辰 | 甲、庚 | 甲、庚 | 转录已核；条件未自动求解 | [renshui.md:58](../source-texts/bazi/qiongtong-baojian/renshui.md) |
| 壬巳 | 庚、壬 | 壬、辛、庚 | 转录已核；条件未自动求解 | [renshui.md:70](../source-texts/bazi/qiongtong-baojian/renshui.md) |
| 壬午 | 庚、癸 | 癸、庚、辛 | 转录已核；条件未自动求解 | [renshui.md:92](../source-texts/bazi/qiongtong-baojian/renshui.md) |
| 壬未 | 辛、庚 | 辛、甲、癸 | 转录已核；条件未自动求解 | [renshui.md:106](../source-texts/bazi/qiongtong-baojian/renshui.md) |
| 壬申 | 戊、丁 | 戊、丁 | 转录已核；条件未自动求解 | [renshui.md:112](../source-texts/bazi/qiongtong-baojian/renshui.md) |
| 壬酉 | 甲、丙 | 甲 | 转录已核；条件未自动求解 | [renshui.md:132](../source-texts/bazi/qiongtong-baojian/renshui.md) |
| 壬戌 | 甲、丙 | 甲、丙 | 转录已核；条件未自动求解 | [renshui.md:162](../source-texts/bazi/qiongtong-baojian/renshui.md) |
| 壬亥 | 戊、丙 | 戊、庚 | 转录已核；条件未自动求解 | [renshui.md:174](../source-texts/bazi/qiongtong-baojian/renshui.md) |
| 壬子 | 戊、丙 | 戊、丙 | 转录已核；条件未自动求解 | [renshui.md:188](../source-texts/bazi/qiongtong-baojian/renshui.md) |
| 壬丑 | 丙、甲 | 丙、甲 | 转录已核；条件未自动求解 | [renshui.md:206](../source-texts/bazi/qiongtong-baojian/renshui.md) |
| 癸寅 | 辛、庚 | 辛、丙 | 转录已核；条件未自动求解 | [guishui.md:34](../source-texts/bazi/qiongtong-baojian/guishui.md) |
| 癸卯 | 辛、庚 | 庚、辛 | 转录已核；条件未自动求解 | [guishui.md:44](../source-texts/bazi/qiongtong-baojian/guishui.md) |
| 癸辰 | 丙、辛 | 丙、辛、甲 | 转录已核；条件未自动求解 | [guishui.md:60](../source-texts/bazi/qiongtong-baojian/guishui.md) |
| 癸巳 | 辛、庚 | 辛、庚 | 转录已核；条件未自动求解 | [guishui.md:84](../source-texts/bazi/qiongtong-baojian/guishui.md) |
| 癸午 | 庚、辛 | 庚、辛、壬 | 转录已核；条件未自动求解 | [guishui.md:88](../source-texts/bazi/qiongtong-baojian/guishui.md) |
| 癸未 | 庚、辛 | 庚、辛 | 转录已核；条件未自动求解 | [guishui.md:94](../source-texts/bazi/qiongtong-baojian/guishui.md) |
| 癸申 | 丙、丁 | 丁、甲 | 转录已核；条件未自动求解 | [guishui.md:106](../source-texts/bazi/qiongtong-baojian/guishui.md) |
| 癸酉 | 辛、丙 | 辛、丙 | 转录已核；条件未自动求解 | [guishui.md:122](../source-texts/bazi/qiongtong-baojian/guishui.md) |
| 癸戌 | 辛、甲 | 辛、癸、甲 | 转录已核；条件未自动求解 | [guishui.md:134](../source-texts/bazi/qiongtong-baojian/guishui.md) |
| 癸亥 | 庚、丙 | 庚、辛 | 转录已核；条件未自动求解 | [guishui.md:148](../source-texts/bazi/qiongtong-baojian/guishui.md) |
| 癸子 | 丙、辛 | 丙、辛 | 转录已核；条件未自动求解 | [guishui.md:162](../source-texts/bazi/qiongtong-baojian/guishui.md) |
| 癸丑 | 丙、辛 | 丙、壬 | 转录已核；条件未自动求解 | [guishui.md:172](../source-texts/bazi/qiongtong-baojian/guishui.md) |
