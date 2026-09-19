import Foundation
import SwiftUI
import WidgetKit

private let appGroupIdentifier = "group.app.suji.native"
private let snapshotFileName = "widget-snapshot.json"

private struct SujiWidgetSnapshot: Codable {
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

private enum SujiWidgetState {
    case current(SujiWidgetSnapshot)
    case stale
    case empty
}

private struct SujiWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: SujiWidgetSnapshot?

    var state: SujiWidgetState {
        guard let snapshot else { return .empty }
        guard snapshot.schemaVersion == 1,
              snapshot.day == localDayKey(for: date) else { return .stale }
        return .current(snapshot)
    }
}

private struct SujiWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> SujiWidgetEntry {
        SujiWidgetEntry(date: Date(), snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (SujiWidgetEntry) -> Void) {
        completion(SujiWidgetEntry(
            date: Date(),
            snapshot: context.isPreview ? .preview : loadSnapshot()
        ))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SujiWidgetEntry>) -> Void) {
        let now = Date()
        let snapshot = loadSnapshot()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let startOfToday = calendar.startOfDay(for: now)
        let nextMidnight = calendar.date(byAdding: .day, value: 1, to: startOfToday)
            ?? now.addingTimeInterval(24 * 60 * 60)

        // The midnight entry re-evaluates the day key with the same payload. If
        // the app has not published the new day yet, the widget becomes safely
        // stale instead of presenting yesterday's quote as today's.
        let entries = [
            SujiWidgetEntry(date: now, snapshot: snapshot),
            SujiWidgetEntry(date: nextMidnight, snapshot: snapshot)
        ]
        completion(Timeline(entries: entries, policy: .after(nextMidnight.addingTimeInterval(60))))
    }

    private func loadSnapshot() -> SujiWidgetSnapshot? {
        guard let directory = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else { return nil }
        do {
            let data = try Data(contentsOf: directory.appendingPathComponent(snapshotFileName))
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(SujiWidgetSnapshot.self, from: data)
        } catch {
            return nil
        }
    }
}

private struct SujiWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme
    let entry: SujiWidgetEntry

    var body: some View {
        Group {
            switch entry.state {
            case .current(let snapshot): current(snapshot)
            case .stale: fallback(title: "新的一日", detail: "打开有时，取一张今天的日签。")
            case .empty: fallback(title: "万物有时", detail: "打开有时，留下今天的一点空白。")
            }
        }
        .padding(16)
        .foregroundStyle(ink)
        .containerBackground(for: .widget) { paper }
        .widgetURL(URL(string: "suji-native://today"))
    }

    @ViewBuilder
    private func current(_ snapshot: SujiWidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 7 : 9) {
            HStack(alignment: .firstTextBaseline) {
                Text(displayDate(snapshot.date))
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(vermilion)
                Spacer(minLength: 6)
                if let solarTerm = snapshot.solarTerm, !solarTerm.isEmpty {
                    Text(solarTerm)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            if !snapshot.lunar.isEmpty {
                Text(snapshot.lunar)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if snapshot.isRevealed {
                Text(snapshot.quote.replacingOccurrences(of: "\n", with: " "))
                    .font(.system(family == .systemSmall ? .title3 : .title2, design: .serif, weight: .regular))
                    .lineLimit(family == .systemSmall ? 3 : 2)
                    .minimumScaleFactor(0.82)
                if family == .systemMedium {
                    Text(snapshot.action)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } else {
                Text("今日一签，静候揭晓")
                    .font(.system(.title3, design: .serif))
                Text("轻触打开")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func fallback(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "calendar")
                .font(.title3)
                .foregroundStyle(vermilion)
            Spacer(minLength: 0)
            Text(title)
                .font(.system(.title3, design: .serif))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(family == .systemSmall ? 3 : 2)
        }
    }

    private func displayDate(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day())
    }

    private var paper: Color {
        colorScheme == .dark
            ? Color(red: 0.094, green: 0.110, blue: 0.098)
            : Color(red: 0.961, green: 0.949, blue: 0.914)
    }

    private var ink: Color {
        colorScheme == .dark
            ? Color(red: 0.929, green: 0.925, blue: 0.886)
            : Color(red: 0.161, green: 0.176, blue: 0.153)
    }

    private var vermilion: Color {
        colorScheme == .dark
            ? Color(red: 0.859, green: 0.580, blue: 0.482)
            : Color(red: 0.643, green: 0.278, blue: 0.208)
    }
}

struct SujiTodayWidget: Widget {
    let kind = "SujiTodayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SujiWidgetProvider()) { entry in
            SujiWidgetView(entry: entry)
        }
        .configurationDisplayName("今日一签")
        .description("在桌面留一张安静的日签。")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

@main
struct SujiWidgetBundle: WidgetBundle {
    var body: some Widget {
        SujiTodayWidget()
    }
}

private func localDayKey(for date: Date) -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .current
    let components = calendar.dateComponents([.year, .month, .day], from: date)
    return String(
        format: "%04d-%02d-%02d",
        components.year ?? 0,
        components.month ?? 0,
        components.day ?? 0
    )
}

private extension SujiWidgetSnapshot {
    static var preview: Self {
        Self(
            schemaVersion: 1,
            day: localDayKey(for: Date()),
            date: Date(),
            generatedAt: Date(),
            lunar: "八月初九",
            solarTerm: "秋分",
            quote: "万物有时，\n你也一样。",
            action: "今天把一件事做得从容一点。",
            isRevealed: true
        )
    }
}
