import Foundation
import SujiCore

struct SolarTermAmbiencePreset: Identifiable, Sendable {
    let id: String
    let note: String
    let volumes: [AmbienceLayer: Float]

    var name: String { id }

    func volume(for layer: AmbienceLayer) -> Float {
        volumes[layer, default: 0]
    }

    static let all: [Self] = [
        preset("小寒", "风紧，炉火稍暖", 0.10, 0.12, 0.40, 0.38),
        preset("大寒", "深冬静守", 0.08, 0.10, 0.42, 0.40),
        preset("立春", "水声初动", 0.22, 0.32, 0.28, 0.18),
        preset("雨水", "细雨润物", 0.42, 0.30, 0.18, 0.10),
        preset("惊蛰", "雨落，微风醒来", 0.35, 0.24, 0.24, 0.17),
        preset("春分", "四声平衡", 0.28, 0.30, 0.24, 0.18),
        preset("清明", "水清风轻", 0.34, 0.36, 0.20, 0.10),
        preset("谷雨", "雨丰，溪声相和", 0.44, 0.32, 0.15, 0.09),
        preset("立夏", "流水渐长", 0.24, 0.39, 0.23, 0.14),
        preset("小满", "水满而不溢", 0.27, 0.41, 0.21, 0.11),
        preset("芒种", "雨水相催", 0.31, 0.40, 0.18, 0.11),
        preset("夏至", "长日听水", 0.22, 0.43, 0.28, 0.07),
        preset("小暑", "风水消暑", 0.29, 0.38, 0.27, 0.06),
        preset("大暑", "雨水稍盛", 0.34, 0.37, 0.24, 0.05),
        preset("立秋", "风声渐清", 0.23, 0.31, 0.34, 0.12),
        preset("处暑", "暑退，水风相间", 0.20, 0.34, 0.31, 0.15),
        preset("白露", "露凝，炉火初起", 0.19, 0.33, 0.30, 0.18),
        preset("秋分", "清风与暖意相平", 0.18, 0.29, 0.30, 0.23),
        preset("寒露", "风凉，火声渐近", 0.16, 0.25, 0.34, 0.25),
        preset("霜降", "风深，炉火安定", 0.12, 0.20, 0.36, 0.32),
        preset("立冬", "收水入静", 0.10, 0.16, 0.36, 0.38),
        preset("小雪", "风雪未深", 0.13, 0.15, 0.35, 0.37),
        preset("大雪", "雪意与炉火", 0.10, 0.13, 0.37, 0.40),
        preset("冬至", "长夜守暖", 0.08, 0.12, 0.38, 0.42)
    ]

    static func current(at date: Date = Date()) -> Self {
        let term = SolarTermCalculator.currentTerm(at: date)
        return all.first { $0.id == term } ?? all[18]
    }

    static func named(_ id: String) -> Self? {
        all.first { $0.id == id }
    }

    private static func preset(
        _ name: String,
        _ note: String,
        _ rain: Float,
        _ stream: Float,
        _ wind: Float,
        _ fire: Float
    ) -> Self {
        Self(
            id: name,
            note: note,
            volumes: [.rain: rain, .stream: stream, .wind: wind, .fire: fire]
        )
    }
}

enum StandaloneAmbienceTimer: Int, CaseIterable, Identifiable {
    case off = 0
    case fifteen = 15
    case thirty = 30
    case sixty = 60

    var id: Int { rawValue }
    var title: String { self == .off ? "不计时" : "\(rawValue) 分钟" }
    var seconds: TimeInterval? { self == .off ? nil : TimeInterval(rawValue * 60) }
}
