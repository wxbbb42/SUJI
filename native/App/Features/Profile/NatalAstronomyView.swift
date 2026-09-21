import SwiftUI
import SujiCore

struct NatalAstronomyView: View {
    @Environment(AppStore.self) private var store
    private let names = ["Sun":"太阳", "Moon":"月亮", "Mercury":"水星", "Venus":"金星", "Mars":"火星", "Jupiter":"木星", "Saturn":"土星", "Rahu":"罗喉", "Ketu":"计都", "Apogee":"月孛", "PurpleQi":"紫炁"]
    private var document: Document? {
        guard store.hasNatalAstronomyDossier, let dossier = store.natalAstronomyDossier else { return nil }
        return try? Document(data: dossier.payload)
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("出生时的天空").font(SujiTheme.serif(30))
                Text("七曜、四余与二十八宿参照，以及按遇卯法排布的命宫、命度和十二宫。它们随出生资料存入档案，角度采用现代 360° 制。").font(.subheadline).foregroundStyle(SujiTheme.secondary).lineSpacing(5)
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
                    VStack(alignment: .leading, spacing: 14) {
                        Text("四余 · 平轨道法").font(SujiTheme.serif(26))
                        Text("罗喉取北交点、计都取南交点，月孛取平均远地点；紫炁按约定周期推算。").font(.subheadline).foregroundStyle(SujiTheme.secondary)
                        ForEach(document["fourResiduals"]["positions"].array, id: \.json) { point in
                            Text("\(names[point["body"].text] ?? point["body"].text) · 黄经 \(angle(point["longitudeDegrees"])) · 黄纬 \(angle(point["latitudeDegrees"]))").font(.subheadline)
                        }
                    }.accessibilityIdentifier("astronomy.fourResiduals")
                    VStack(alignment: .leading, spacing: 14) {
                        let life = document["lifeDegree"]
                        Text("\(life["palaceBranch"].text)宫 · 遇卯命度").font(SujiTheme.serif(26))
                        Text("宫内 \(angle(life["palaceDegree"])) · 宫主 \(names[life["palaceRuler"].text] ?? life["palaceRuler"].text)")
                        Text("\(life["mansion"]["mansion"].text)宿 · 参考入宿 \(angle(life["mansion"]["entryDegrees"])) · 度主 \(names[life["degreeRuler"].text] ?? life["degreeRuler"].text)")
                        Text("以出生时支加太阳宫，顺数至卯安命。此处采用现代黄道宫与距星参照；出生时刻或流派不同，命度可能不同。").foregroundStyle(SujiTheme.secondary)
                        DisclosureGroup("十二宫排布") {
                            ForEach(life["houses"].array, id: \.json) { house in
                                Text("\(house["name"].text) · \(house["branch"].text) · \(names[house["ruler"].text] ?? house["ruler"].text)")
                                    .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 4)
                            }
                        }
                    }.font(.subheadline).lineSpacing(5).accessibilityIdentifier("astronomy.lifeDegree")
                    DisclosureGroup("计算口径与来源") {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("以填写的北京时间固定 UTC+8 换算，不作经度、真太阳时或历史夏令时修正。UTC 近似 UT1；采用 Espenak / Meeus ΔT 换算 TT。七曜坐标为日期真黄道、真赤道。")
                            Text("Astronomy Engine 2.1.19。太阳和行星计入光行时与光行差；月亮采用 GeoMoon，不另加这两项修正。")
                            Text("距星取现代二十八宿首星约定，Hipparcos 星表及 SIMBAD 核对。奎采用 η And、斗采用 φ Sgr；不代表所有历史距星体系。恒星变换含自行、岁差及简化章动，不含周年光行差、视差、光偏折和径向速度。")
                            Text("宿界以赤经分段，左闭右开。天体星历与星表误差尚无可承诺的统一上界。")
                            Text("四余采用平交点、平均月球轨道及 Moira 紫炁参数，平黄道位置不与七曜视位置混用。遇卯安命据《古今图书集成》所收《张果星宗》条文，映射至现代热带黄道十二等宫，不等同地平升点或古代命度表。宫内黄经与入宿赤经是不同角度。")
                            Text("当前提供所选方法的排盘依据；传统角度制、七政吉凶裁定与流限尚未提供。")
                            Text("来源标识：" + (["sevenBodies", "mansions", "fourResiduals", "lifeDegree"].flatMap { document[$0]["sourceIDs"].strings }).joined(separator: "；"))
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
