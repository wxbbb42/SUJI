# 2057 年九月朔：差异归因与保留边界

2026-09-19 的专项调查排除了本次 PDF 抽取错位和官方文件刚更新两种解释。**这是香港天文台自己明确预告的近午夜朔时日期分歧；目前独立高精度星历计算支持引擎使用的 9 月 29 日，但不能据此宣布 2057 年的最终民用历日已经确定，更不能把官方表改写成引擎值。**

本次只检查 2057 年原表和一个朔时，重现 9 月 28 日至 10 月 27 日的 30 天差异，没有重跑 200 年，没有修改生产算法、原始验证结果或日期补丁。

## 一手证据

1. 香港天文台[公农历对照表说明](https://www.hko.gov.hk/tc/gts/time/conversion.htm)直接指出：

   > 由於計算數十年後的月相及節氣時間可能會有數分鐘的誤差，若新月(即農曆初一)或節氣時間很接近午夜零時，「對照表」內相關農曆月份或節氣的日期可能會有一日之差別。

   同一条说明明确列举 **2057 年 9 月 28 日**的新月。英文[Remarks](https://www.hko.gov.hk/en/gts/time/conversion.htm)也有相同说明。这是官方针对这一具体日期的限定，不是本项目为解释失败而设想的原因。

2. 重新下载[2057 年 PDF](https://www.hko.gov.hk/en/gts/time/calendar/pdf/files/2057e.pdf)，SHA256 仍为 `72ffdafa83df80c8625c5f5efad3f6458e1f69928a37f5c6c64156122eb83f15`，与此前日历审计的缓存和清单一致。PDF 自带创建、修改时间均为 2004-12-09；这个元数据只能说明文件自报的制作时间，不能还原 HKO 算法版本或证明完整发布历史。

3. 独立读取[官方 TXT](https://www.hko.gov.hk/en/gts/time/calendar/text/files/T2057e.txt)，与 PDF 的 **365 个日期单元格完全一致**：9/27 是八月廿九，9/28 是九月初一，10/27 是九月三十，10/28 是十月初一。由此排除只在 PDF 中误读月份、错列或 OCR 导致这 30 天分歧的解释。

4. NASA/Fred Espenak 的[2001–2100 月相表](https://eclipse.gsfc.nasa.gov/phase/phases2001.html)列出该次朔为 **2057 Sep 28 16:00 UT**，即 UT+08 恰到午夜的那一分钟。它只印分钟，无法裁决朔在午夜前还是后；年首印出的 ΔT `00h02m` 同样是舍入值，**不能拿它当精确的 120 秒**。

原始下载保存在 ignored `native/Engine/validation/research-calendar/hko-cache/2057-investigation/`。可提交的[专项结果](../../../native/Engine/validation/research-calendar/hko-2057-investigation.json)保留来源 URL、取回时间、字节数、SHA256、相关 HTTP 元数据、失败网址、原表局部摘录和计算结果。所有文件都在本地工作区内，未引入生产依赖。

## 把星历与地球自转时间分开比较

农历朔采用日月视黄经相合。用 NASA/JPL [DE440s](https://ssd.jpl.nasa.gov/ftp/eph/planets/bsp/de440s.bsp) 星历，经 **Skyfield 1.54** 的 `almanac.moon_phases` 求地心视黄经之差过零；使用包内固定的时间表，未在线更新 UT1 数据。DE440 的[官方说明](https://ssd.jpl.nasa.gov/planets/eph_export.html)记录了星历的观测依据与覆盖范围。

这里先比较 TT（地球时）里的相合，再分别减去 ΔT=TT−UT。表中的 TT 是该时标的日历坐标，**不是 UTC 时间戳**；UT/UT1+08 是模型换算结果，也不是已知的 2057 年精确 UTC+08。未来地球自转和闰秒不能当成已知常数。

| 计算路径 | 朔的 TT，2057-09-28 | 使用的 ΔT | 对应 UT/UT1+08 |
|---|---:|---:|---|
| 生产 lunar-javascript 1.7.7，高精度朔分支 | 16:01:52.537 | 87.923 秒 | 9/29 00:00:24.614 |
| JPL DE440s + Skyfield 1.54 | 16:01:53.400 | 73.509 秒 | 9/29 00:00:39.891 |
| Astronomy Engine 2.1.19 | 16:02:29.123 | 108.867 秒 | 9/29 00:00:40.255 |

生产朔时与 DE440 路径在 **同一 TT 时标仅差 0.862 秒**。这没有显示一个足以直接解释整天偏移的生产星历错误。另一方面，Astronomy Engine 与 DE440 的 TT 相差 **35.723 秒**：此前得到的 `00:00:40` 虽然接近 Skyfield 的 UT1 结果，但里面有不同的星历误差和 ΔT，不能把两个相似的民用时数值当作秒级互证。该次亚秒级差异也不是对其他年份的普遍误差上限。

生产 `ShouXingUtil.shuoHigh` 在距午夜半小时内会转高精度计算；此次确实走了这个分支。其本次 ΔT 来自库内表后的外推。ΔT 模型与 DE440 星历是不同东西：不能把 Skyfield 的地球自转预测称为“DE440 提供的 ΔT”。

## ΔT 能否单独改变日期

固定 DE440 算出的 TT 朔时不变，只改变 ΔT，得到：

| ΔT 取法 | ΔT | 换算 UT+08 时刻 |
|---|---:|---|
| Skyfield 内置模型 | 73.509 秒 | 9/29 00:00:39.891 |
| 生产库本次值 | 87.923 秒 | 9/29 00:00:25.477 |
| Espenak–Meeus，经 Astronomy Engine | 108.867 秒 | 9/29 00:00:04.533 |
| 仅用于敏感性示例 | 120 秒 | 9/28 23:59:53.400 |

该星历下跨越午夜的阈值是 **ΔT=113.400 秒**。第三个常用模型距阈值已只差约 4.53 秒；因此分钟级朔时/时间模型差异确实足以造成一天历日差。最后一行不是 HKO 参数，也不是置信区间，只证明改变日期所需的量级。NASA 的[ΔT 模型说明](https://eclipse.gsfc.nasa.gov/SEhelp/deltatpoly2004.html)和 Skyfield 的[时间说明](https://rhodesmill.org/skyfield/time.html)也区分了稳定星历时间与难以长期预测的地球自转时间。

**尚未找到 HKO 制作该年度表时的未舍入朔时、星历版本和具体 ΔT 参数。** 所以可以确认“官方已标出的近午夜敏感边界”，但不能把 HKO 的早一天数值精确归因成“只因采用某个 ΔT”，也不能宣称已证明 HKO 算错。文件制作较早与这种敏感性相容，不构成对具体旧算法的证明。

## 对产品与验证的结论

- 保留此前 30 条差异；不能将其改成通过，也不要用 HKO 日期硬编码覆盖引擎来提高一致率。
- 当前提示“天文模型与香港天文台日期表相差一日，农历日期暂按当前天文模型，需复核”有实证依据。未来改文案时可链接官方明确说明，并给出 **9/28 官方表九月初一 / 当前模型八月三十**的具体差异。
- 若某功能需要依赖这段农历日期进行紫微或其他农历派生计算，应把两种历日依据和不确定性传递到结果，不能只在内部日志记录。此调查没有验证所有下游 UI 都已展示该提示。
- 不用这一份专项调查推断完整命理解释准确性。它只解决该次历法差异的已知类别、排除若干数据错误，并量化仍未确定的部分。

## 复算

先安装隔离研究依赖，不改变 App 或生产 package：

```sh
python3 -m venv native/Engine/validation/research-calendar/hko-cache/2057-investigation/.venv
native/Engine/validation/research-calendar/hko-cache/2057-investigation/.venv/bin/pip install skyfield==1.54
npm install --prefix /tmp/suji-calendar-research --no-audit --no-fund astronomy-engine@2.1.19
native/Engine/validation/research-calendar/hko-cache/2057-investigation/.venv/bin/python3 \
  native/Engine/validation/research-calendar/hko-2057-investigate.py \
  --fetch --output /tmp/suji-hko-2057-reproduction.json
```

脚本固定来源，只下载缺失缓存，已有结果文件会被拒绝覆盖。结果记录实际版本及脚本哈希；本次为 Skyfield 1.54、jplephem 2.24、NumPy 2.0.2、sgp4 2.25。设 `SUJI_CALENDAR_REFS` 可以指定独立 astronomy-engine 安装目录。它直接读取生产依赖的公开朔时与公农历接口，但不会修改接口或引擎文件。
