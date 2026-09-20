import SwiftUI
import SujiCore

struct ReadingEvidenceView: View {
    let receipts: [ToolReceipt]
    var body: some View {
        List {
            ForEach(receipts, id: \.callID) { receipt in
                Section(ChatSession.toolLabel(receipt.name)) {
                    let document = (try? Document(data: Data(receipt.output.utf8))) ?? Document([:])
                    if let trace = baziStrengthTrace(pillars: document["bazi"]["pillars"], strength: document["bazi"]["strengthReference"], structure: document["bazi"]["structureReference"]) {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("扶抑参考的来由").font(.headline).accessibilityAddTraits(.isHeader)
                            BaziStrengthTraceView(trace: trace, identifier: "evidence.strength.trace." + receipt.callID)
                        }.padding(.vertical, 8)
                    }
                    if let context = receipt.context {
                        LabeledContent("提问时刻", value: timeLabel(context.referenceDate))
                        Text("按当时的出生资料与排盘规则计算；旧盘保留供核对，不随资料修改而改变。")
                            .font(.footnote).foregroundStyle(SujiTheme.secondary)
                    } else {
                        Text("旧版或导入的历史盘面，来源未验证，不用于新的 AI 解读。")
                            .font(.footnote).foregroundStyle(SujiTheme.secondary)
                    }
                    ForEach(Array(receipt.evidence.enumerated()), id: \.offset) { _, line in
                        Text(line).font(.subheadline).textSelection(.enabled)
                    }
                    if receipt.name == "cast_liuyao", document["lines"].array.count == 6 { liuyao(document) }
                    if receipt.name == "setup_qimen", document["palaces"].array.count == 9 { qimen(document) }
                    let source = document["bazi"]["tiaoHou"]
                    if !source["excerpt"].text.isEmpty {
                        Text("调候文献候选").font(.subheadline.weight(.medium))
                        Text(source["excerpt"].text).textSelection(.enabled)
                        Text(source["sourceAnchor"].text).font(.caption).foregroundStyle(SujiTheme.secondary)
                        Text(source["conditions"].strings.joined(separator: "\n")).font(.footnote)
                        Text("已核对转录文字；尚未对照印刷底本，候选不等于已满足取用条件。")
                            .font(.footnote).foregroundStyle(SujiTheme.secondary)
                    }
                    DisclosureGroup("完整计算记录") {
                        Text(receipt.output).font(.caption.monospaced()).textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let context = receipt.context {
                            Text("引擎版本 · " + context.engineRevision).font(.caption2).textSelection(.enabled)
                        }
                        ShareLink("导出这条依据", item: receipt.output)
                    }
                }
            }
        }
        .navigationTitle("计算依据").navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden).background(SujiTheme.paper).foregroundStyle(SujiTheme.ink)
    }

    @ViewBuilder private func liuyao(_ data: Document) -> some View {
        Text(data["benGua"]["name"].text + " → " + data["bianGua"]["name"].text)
            .font(SujiTheme.serif(24)).accessibilityLabel("本卦" + data["benGua"]["name"].text + "，变卦" + data["bianGua"]["name"].text)
        Text("月建 \(data["castGanZhi"]["month"].text) · 日辰 \(data["castGanZhi"]["day"].text) · 时柱 \(data["castGanZhi"]["hour"].text)").font(.subheadline)
        Text("旬空 · " + data["xunKong"].strings.joined(separator: "、")).font(.subheadline)
        DisclosureGroup("六爻明细 · 上爻至初爻") {
            ForEach(Array(data["lines"].array.reversed().enumerated()), id: \.offset) { _, line in
                VStack(alignment: .leading, spacing: 7) {
                    let value = Int(line["value"].number)
                    let quality = [6: "老阴", 7: "少阳", 8: "少阴", 9: "老阳"][value] ?? "未知"
                    let flags = [line["isShi"].number == 1 ? "世" : "", line["isYing"].number == 1 ? "应" : "", line["isChanging"].number == 1 ? "动爻" : "", line["isVoid"].number == 1 ? "旬空" : ""].filter { !$0.isEmpty }.joined(separator: " · ")
                    Text("第\(Int(line["position"].number))爻 · \(quality)（\(value)） \(flags)").font(.subheadline.weight(.medium))
                    Text("\(line["liuShen"].text) · \(line["liuQin"].text) · \(line["ganZhi"].text) · \(line["wuXing"].text)").font(.subheadline)
                    if !line["changed"]["ganZhi"].text.isEmpty {
                        Text("变爻 · \(line["changed"]["ganZhi"].text) · \(line["changed"]["liuQin"].text)").font(.footnote)
                    }
                    if !line["hidden"]["ganZhi"].text.isEmpty {
                        Text("伏神 · \(line["hidden"]["ganZhi"].text) · \(line["hidden"]["liuQin"].text)").font(.footnote)
                    }
                    let relations = [line["monthClash"].number == 1 ? "月破" : "", line["dayClash"].number == 1 ? "日冲" : "", line["dayCombination"].number == 1 ? "日合" : ""].filter { !$0.isEmpty }
                    if !relations.isEmpty { Text(relations.joined(separator: " · ")).font(.footnote) }
                }.padding(.vertical, 8).accessibilityElement(children: .combine)
                    .accessibilityIdentifier("evidence.liuyao.line." + String(Int(line["position"].number)))
            }
        }
        Text(data["yingQi"]["description"].text).font(.footnote).foregroundStyle(SujiTheme.secondary)
        method(data)
    }

    @ViewBuilder private func qimen(_ data: Document) -> some View {
        Text("\(data["yinYangDun"].text)遁\(Int(data["juNumber"].number))局 · \(data["yuan"].text)元").font(SujiTheme.serif(24))
        Text("\(data["jieqi"].text) · 符头 \(data["fuTou"].text)").font(.subheadline)
        Text("值符 · \(data["zhiFuStar"].text)，落\(Int(data["zhiFuPalaceId"].number))宫").font(.subheadline)
        Text("值使 · \(data["zhiShiMen"].text)，落\(Int(data["zhiShiPalaceId"].number))宫").font(.subheadline)
        DisclosureGroup("九宫明细") {
            ForEach(Array(data["palaces"].array.enumerated()), id: \.offset) { _, palace in
                VStack(alignment: .leading, spacing: 7) {
                    Text("\(palace["name"].text) · \(Int(palace["id"].number))宫 · \(palace["position"].text)").font(.subheadline.weight(.medium))
                    Text([palace["jiuxing"].text, palace["bamen"].text, palace["bashen"].text].filter { !$0.isEmpty }.joined(separator: " · ")).font(.subheadline)
                    if Int(palace["id"].number) == 5 && palace["bamen"].text.isEmpty && palace["bashen"].text.isEmpty {
                        Text("中宫不布八门与八神；天禽寄干见对应外宫。").font(.footnote).foregroundStyle(SujiTheme.secondary)
                    }
                    Text("地盘 \(palace["diPanGan"].text) · 天盘 \(palace["tianPanGan"].text.isEmpty ? "无独立干" : palace["tianPanGan"].text)").font(.footnote)
                    if !palace["hostedTianPanGan"].text.isEmpty {
                        Text("天禽寄干 · " + palace["hostedTianPanGan"].text).font(.footnote)
                    }
                    if !palace["hostedDiPanGan"].text.isEmpty {
                        Text("地盘寄干 · " + palace["hostedDiPanGan"].text).font(.footnote)
                    }
                }.padding(.vertical, 8).accessibilityElement(children: .combine)
                    .accessibilityIdentifier("evidence.qimen.palace." + String(Int(palace["id"].number)))
            }
        }
        if !data["yongShen"]["candidates"].array.isEmpty {
            Text("取用参考 · 尚未定用").font(.subheadline)
            ForEach(Array(data["yongShen"]["candidates"].array.enumerated()), id: \.offset) { _, candidate in
                let role = ["day-reference":"日干参考", "hour-reference":"时干参考", "category-reference":"事项参考"][candidate["role"].text] ?? "参考"
                VStack(alignment: .leading, spacing: 4) {
                    Text(role + " · " + candidate["symbol"].text).font(.footnote)
                    if candidate["carrierMethod"].text == "own-pillar-xun" {
                        Text("甲隐于本柱旬仪" + candidate["carrierStem"].text + "，按此定位").font(.caption)
                    }
                    ForEach(Array(candidate["occurrences"].array.enumerated()), id: \.offset) { _, occurrence in
                        let plate = ["earth":"地盘", "hosted-earth":"地盘寄干", "sky":"天盘", "hosted-sky":"天禽寄干", "center-record":"中宫留存记录", "door":"门", "deity":"神", "star":"星"][occurrence["plate"].text] ?? "参考"
                        Text("\(plate) · \(Int(occurrence["palaceId"].number))宫").font(.caption).foregroundStyle(SujiTheme.secondary)
                    }
                }.accessibilityElement(children: .combine)
            }
        } else {
            Text("旧记录取用参考 · " + data["yongShen"]["summary"].text).font(.footnote)
        }
        Text(data["yingQi"]["description"].text).font(.footnote).foregroundStyle(SujiTheme.secondary)
        method(data)
    }

    @ViewBuilder private func method(_ data: Document) -> some View {
        ForEach(Array(data["method"]["caveats"].strings.enumerated()), id: \.offset) { _, caveat in
            Text(caveat).font(.footnote).foregroundStyle(SujiTheme.secondary)
        }
    }

    private func timeLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = TimeZone(secondsFromGMT: 8 * 3600)
        formatter.dateFormat = "yyyy年M月d日 HH:mm:ss '北京时间'"
        return formatter.string(from: date)
    }
}
