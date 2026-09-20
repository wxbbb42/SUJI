import SwiftUI
import SujiCore

struct NatalAstronomyView: View {
    @Environment(AppStore.self) private var store
    private let names = ["Sun":"太阳", "Moon":"月亮", "Mercury":"水星", "Venus":"金星", "Mars":"火星", "Jupiter":"木星", "Saturn":"土星"]
    private var document: Document? {
        guard store.hasNatalAstronomyDossier, let dossier = store.natalAstronomyDossier else { return nil }
        return try? Document(data: dossier.payload)
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("出生时的天空").font(SujiTheme.serif(30))
                Text("太阳、月亮与五颗行星的地心位置，以及现代星名距星参照下的月亮宿位。角度均为现代 360° 制。").font(.subheadline).foregroundStyle(SujiTheme.secondary).lineSpacing(5)
                if let document {
                    Text(document["time"]["wallClock"].text.replacingOccurrences(of: "T", with: " ") + " · 北京时间 UTC+8").font(.footnote).foregroundStyle(SujiTheme.secondary)
                    ForEach(document["sevenBodies"]["positions"].array, id: \.json) { position in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(names[position["body"].text] ?? position["body"].text).font(SujiTheme.serif(23))
                            Text("黄经 \(angle(position["longitudeDegrees"])) · 黄纬 \(angle(position["latitudeDegrees"]))")
                            Text("赤经 \(angle(position["rightAscensionDegrees"])) · 赤纬 \(angle(position["declinationDegrees"]))").foregroundStyle(SujiTheme.secondary)
                        }.font(.subheadline).frame(maxWidth: .infinity, alignment: .leading).padding(20).background(SujiTheme.surface, in: RoundedRectangle(cornerRadius: 18)).accessibilityElement(children: .combine)
                    }
                    if let moon = document["mansions"]["positions"].array.first(where: { $0["body"].text == "Moon" }) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("月亮 · \(moon["mansion"].text)宿").font(SujiTheme.serif(26))
                            Text("现代星名距星参照").font(.caption).foregroundStyle(SujiTheme.secondary)
                            Text("入宿 \(angle(moon["entryDegrees"])) · 宿宽 \(angle(moon["widthDegrees"]))")
                            Text("距最近宿界 \(angle(moon["distanceToBoundaryDegrees"]))")
                            Text("出生时间精度未知，宿界归属保留不确定性；小数位数不代表实际准确度。").foregroundStyle(SujiTheme.secondary)
                        }.font(.subheadline).lineSpacing(5).accessibilityIdentifier("astronomy.moonMansion")
                    } else { Text("当前星宿参照尚不可用。") }
                    DisclosureGroup("计算口径与来源") {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("以填写的北京时间固定 UTC+8 换算，不作经度、真太阳时或历史夏令时修正。UTC 近似 UT1；采用 Espenak / Meeus ΔT 换算 TT。坐标为日期真黄道、真赤道。")
                            Text("Astronomy Engine 2.1.19。太阳和行星计入光行时与光行差；月亮采用 GeoMoon，不另加这两项修正。")
                            Text("距星取现代二十八宿首星约定，Hipparcos 星表及 SIMBAD 核对。奎采用 η And、斗采用 φ Sgr；不代表所有历史距星体系。恒星变换含自行、岁差及简化章动，不含周年光行差、视差、光偏折和径向速度。")
                            Text("宿界以赤经分段，左闭右开。天体星历与星表误差尚无可承诺的统一上界。")
                            Text("未实现四余、宫位、命度或传统角度制，不能当作完整七政四余命盘。")
                            Text("来源标识：" + (document["sevenBodies"]["sourceIDs"].strings + document["mansions"]["sourceIDs"].strings).joined(separator: "；"))
                        }.font(.footnote).foregroundStyle(SujiTheme.secondary).lineSpacing(5).padding(.top, 12)
                    }
                } else if store.buildingNatalAstronomyDossier { ProgressView("正在计算出生星历…") }
                else {
                    Text(store.astronomyError.map { "星历暂未载入：" + $0 } ?? "请先填写出生资料。")
                    if store.state.birth != nil { Button("重新读取星历") { Task { await store.prepareNatalAstronomy() } } }
                }
            }.padding(24)
        }.background(SujiTheme.paper).foregroundStyle(SujiTheme.ink).navigationTitle("出生星历").navigationBarTitleDisplayMode(.inline)
            .task(id: profileRequestIdentity(store)) { await store.prepareNatalAstronomy() }
    }
    private func angle(_ value: Document) -> String { String(format: "%.3f°", value.number) }
}
