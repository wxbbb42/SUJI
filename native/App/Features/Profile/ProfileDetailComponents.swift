import SwiftUI
import SujiCore

@MainActor
func profileRequestIdentity(_ store: AppStore) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let encoded = (try? encoder.encode(store.state.birth)) ?? Data()
    return store.scopeRevision.uuidString + ":" + store.engineRevision + ":" + String(decoding: encoded, as: UTF8.self)
}

struct ZiweiPalaceCard: View {
    let palace: Document
    private var isBody: Bool { palace["isShenGong"].value as? Bool == true }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(palace["name"].text).font(.headline)
                Spacer(minLength: 4)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(SujiTheme.secondary)
            }
            Text(palace["ganZhi"].text + (isBody ? " · 身宫" : "")).font(.caption).foregroundStyle(SujiTheme.secondary)
            if palace["mainStars"].array.isEmpty {
                Text("无主星").font(SujiTheme.serif(20)).foregroundStyle(SujiTheme.secondary)
            } else {
                ForEach(Array(palace["mainStars"].array.enumerated()), id: \.offset) { _, star in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(star["name"].text).font(SujiTheme.serif(20))
                        if !starDescription(star).isEmpty { Text(starDescription(star)).font(.caption).foregroundStyle(SujiTheme.sage) }
                    }
                }
            }
            Text("\(palace["minorStars"].array.count) 颗辅杂星 · 查看详情").font(.caption).foregroundStyle(SujiTheme.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(18)
            .background(SujiTheme.surface, in: RoundedRectangle(cornerRadius: 18))
            .foregroundStyle(SujiTheme.ink).accessibilityElement(children: .combine)
    }
}

struct ZiweiPalaceDetailView: View {
    let palace: Document
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(palace["ganZhi"].text).font(SujiTheme.serif(30))
                if palace["isShenGong"].value as? Bool == true {
                    Text("身宫所在").font(.headline).foregroundStyle(SujiTheme.sage)
                }
                Text("本命主星").font(.headline)
                if palace["mainStars"].array.isEmpty {
                    Text("本宫无主星").font(SujiTheme.serif(24))
                    Text("无主星是盘面信息，不是缺失数据。需要结合相关宫位整体阅读，不能单独作吉凶判断。").font(.subheadline).foregroundStyle(SujiTheme.secondary).lineSpacing(6)
                } else { starRows(palace["mainStars"].array) }
                Divider()
                Text("完整辅星与杂曜").font(.headline)
                if palace["minorStars"].array.isEmpty {
                    Text("本宫没有返回辅杂星。").font(.subheadline).foregroundStyle(SujiTheme.secondary)
                } else { starRows(palace["minorStars"].array) }
                Text("庙、旺、得、利、平、陷等是传统星曜亮度标记；四化是本命盘的禄、权、科、忌，不等同于流年四化，也不代表事件一定发生。").font(.footnote).foregroundStyle(SujiTheme.secondary).lineSpacing(6)
            }.padding(24)
        }.background(SujiTheme.paper).foregroundStyle(SujiTheme.ink)
            .navigationTitle(palace["name"].text).navigationBarTitleDisplayMode(.inline)
    }
    private func starRows(_ stars: [Document]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(stars.enumerated()), id: \.offset) { _, star in
                VStack(alignment: .leading, spacing: 7) {
                    Text(star["name"].text).font(SujiTheme.serif(23))
                    if !starDescription(star).isEmpty {
                        Text(starDescription(star)).font(.subheadline).foregroundStyle(SujiTheme.sage)
                    }
                }.accessibilityElement(children: .combine)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

private func starDescription(_ star: Document) -> String {
    var parts: [String] = []
    if !star["brightness"].text.isEmpty { parts.append("亮度：" + star["brightness"].text) }
    if !star["sihua"].strings.isEmpty { parts.append("本命四化：" + star["sihua"].strings.joined(separator: "、")) }
    return parts.joined(separator: " · ")
}

struct TiaoHouSourceView: View {
    let document: Document
    private var checked: Bool { document["reviewStatus"].text == "transcription-checked" }
    var body: some View {
        if !document["ruleId"].text.isEmpty {
            DisclosureGroup("调候文献候选（条件待核）") {
                VStack(alignment: .leading, spacing: 14) {
                    if checked, !document["candidateStems"].strings.isEmpty {
                        Text(document["candidateStems"].strings.joined(separator: "、"))
                            .font(SujiTheme.serif(26)).foregroundStyle(SujiTheme.ink)
                        Text("这些是原文涉及的候选，需结合完整四柱与适用条件阅读；尚未自动选定调候用神。")
                            .font(.subheadline)
                    } else {
                        Text("本条原文仍待核对，暂不列候选。").font(.subheadline)
                    }
                    if !document["excerpt"].text.isEmpty {
                        Text("「" + document["excerpt"].text + "」")
                            .font(SujiTheme.serif(18)).lineSpacing(6)
                    }
                    ForEach(Array(document["conditions"].strings.enumerated()), id: \.offset) { _, condition in
                        Text(condition).font(.footnote).lineSpacing(5)
                    }
                    Text("来源：《穷通宝鉴》" + sourceChapter + "。现据在线转录本整理，尚未逐字核对印刷底本。")
                        .font(.caption).foregroundStyle(SujiTheme.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.top, 14)
            }.font(.subheadline).foregroundStyle(SujiTheme.ink)
        }
    }
    private var sourceChapter: String {
        let chapters = ["甲": "甲木篇", "乙": "乙木篇", "丙": "丙火篇", "丁": "丁火篇", "戊": "戊土篇", "己": "己土篇", "庚": "庚金篇", "辛": "辛金篇", "壬": "壬水篇", "癸": "癸水篇"]
        return chapters[document["dayStem"].text] ?? ""
    }
}

struct ChartCalculationNote: View {
    let profile: Document
    private var policy: Document { profile["mingPan"]["calculationPolicy"] }
    var body: some View {
        DisclosureGroup("排盘口径与时间") {
            VStack(alignment: .leading, spacing: 14) {
                Text("出生记录采用公历、民用北京时间。八字与紫微保留各自的时刻口径。").font(.subheadline)
                if !profile["mingPan"]["trueSolarTimeDesc"].text.isEmpty {
                    Text("八字 · " + profile["mingPan"]["trueSolarTimeDesc"].text).font(.subheadline)
                }
                if let civil = profileBeijingDate(policy["civilBirthTime"].text) { Text("民用输入：" + civil).font(.subheadline) }
                if let solar = profileBeijingDate(policy["effectiveSolarTime"].text) { Text("日时柱采用的太阳时：" + solar).font(.subheadline) }
                if policy["yearBoundary"].text == "exact-lichun", policy["monthBoundary"].text == "exact-jie" {
                    Text("年柱以精确立春换年，月柱以精确的节换月，均以民用时间比较；太阳时校正只作用于日柱和时柱。").font(.subheadline)
                }
                if policy["dayBoundary"].text == "zi-hour-23:00" { Text("八字以 23:00 子初换日；农历日期仍以民用午夜换日。").font(.subheadline) }
                Text("紫微 · 使用输入的民用北京时间，不套用八字的真太阳时校正。").font(.subheadline)
                if profile["ziweiPan"]["method"]["yearBoundary"].text == "lunar-new-year" {
                    Text("紫微以农历正月初一换年；23:00 起按次日安星；闰月初一至十五按本月，十六日起按下月。").font(.subheadline)
                }
                ForEach(profile["ziweiPan"]["method"]["caveats"].strings, id: \.self) { Text($0).font(.footnote).foregroundStyle(SujiTheme.secondary) }
                ForEach(policy["warnings"].strings, id: \.self) { Text($0).font(.footnote).foregroundStyle(SujiTheme.secondary) }
                if !policy["provider"].text.isEmpty { Text("历法实现：" + policy["provider"].text + " · " + policy["version"].text).font(.caption).foregroundStyle(SujiTheme.secondary) }
                Text("结果中的格局、取用和应期含不同传统解释与简化规则；对同一出生资料，不同排盘口径可能产生不同结论。").font(.footnote).foregroundStyle(SujiTheme.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(.top, 14)
        }.font(.subheadline)
    }
}

func profileBeijingDate(_ iso: String, includesTime: Bool = true) -> String? {
    let formatter = ISO8601DateFormatter()
    var date = formatter.date(from: iso)
    if date == nil { formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; date = formatter.date(from: iso) }
    guard let date else { return nil }
    let display = DateFormatter()
    display.locale = Locale(identifier: "zh_CN")
    display.timeZone = TimeZone(secondsFromGMT: 8 * 3600)
    display.dateFormat = includesTime ? "yyyy年M月d日 HH:mm" : "yyyy年M月d日"
    return display.string(from: date)
}
