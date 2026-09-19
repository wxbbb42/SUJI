import Foundation
import SujiCore
import WidgetKit

enum WidgetSnapshotService {
    static let appGroupIdentifier = "group.app.suji.native"
    static let fileName = "widget-snapshot.json"
    static let widgetKind = "SujiTodayWidget"

    /// The deliberately narrow signature prevents profile, birth, account, or
    /// credential data from entering the shared App Group container.
    static func publish(
        day: DayKey,
        date: Date,
        lunar: String,
        solarTerm: String?,
        quote: String,
        action: String,
        isRevealed: Bool
    ) throws {
        guard DayKey(date: date).rawValue == day.rawValue else {
            throw SnapshotError.dayMismatch
        }
        guard let directory = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            throw SnapshotError.appGroupUnavailable
        }
        let snapshot = WidgetSnapshot(
            schemaVersion: 1,
            day: day.rawValue,
            date: date,
            generatedAt: Date(),
            lunar: lunar,
            solarTerm: solarTerm,
            quote: quote,
            action: action,
            isRevealed: isRevealed
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(snapshot).write(
            to: directory.appendingPathComponent(fileName, isDirectory: false),
            options: [.atomic]
        )
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
    }
}

private struct WidgetSnapshot: Codable {
    let schemaVersion: Int
    let day: String
    let date: Date
    let generatedAt: Date
    let lunar: String
    let solarTerm: String?
    let quote: String
    let action: String
    let isRevealed: Bool
}

private enum SnapshotError: LocalizedError {
    case appGroupUnavailable
    case dayMismatch

    var errorDescription: String? {
        switch self {
        case .appGroupUnavailable: "小组件共享空间暂不可用。"
        case .dayMismatch: "小组件日签日期不一致，未写入共享空间。"
        }
    }
}
