import SwiftUI
import SujiCore

/// Presentation only. The core validates and explains the recorded calculation.
/// There is deliberately no score chart or inference from the displayed numbers.
struct BaziStrengthTraceView: View {
    let trace: BaziStrengthTrace
    var showsSummary = true
    var showsFootnote = true
    var identifier = "strength.trace"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showsSummary {
                Text(trace.summary)
                    .font(.body).lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                    .accessibilityIdentifier(identifier + ".summary")
            }
            if showsFootnote {
                Text(trace.footnote)
                    .font(.footnote).foregroundStyle(SujiTheme.secondary).lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(identifier + ".qualification")
            }
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(trace.groups) { group in
                        VStack(alignment: .leading, spacing: 14) {
                            Text(group.title)
                                .font(.headline).foregroundStyle(SujiTheme.ink)
                                .accessibilityAddTraits(.isHeader)
                                .accessibilityIdentifier(identifier + ".group." + group.id)
                            ForEach(group.rows) { row in
                                traceRow(row)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 8)
            } label: {
                Text("查看强弱判断依据")
                    .font(.subheadline.weight(.medium))
                    .frame(minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                    .accessibilityIdentifier(identifier + ".toggle")
            }
            .tint(SujiTheme.sage)
        }
        .foregroundStyle(SujiTheme.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private func traceRow(_ row: BaziStrengthTrace.Row) -> some View {
        if Double(row.detail) != nil {
            // Compact values retain their units/meaning from the core's group heading.
            LabeledContent(row.title, value: row.detail)
                .font(.subheadline)
                .foregroundStyle(SujiTheme.ink)
                .accessibilityIdentifier(identifier + ".row." + row.id)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text(row.title).font(.subheadline.weight(.medium))
                Text(row.detail)
                    .font(.subheadline).lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                    .accessibilityIdentifier(identifier + ".row." + row.id)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Adapt the app's JSON container; all schema checks stay in SujiCore.
func baziStrengthTrace(pillars: Document, strength: Document, structure: Document) -> BaziStrengthTrace? {
    let decoder = JSONDecoder()
    guard let pillarsValue = try? decoder.decode(JSONValue.self, from: Data(pillars.json.utf8)),
          let strengthValue = try? decoder.decode(JSONValue.self, from: Data(strength.json.utf8)) else { return nil }
    let structureValue = try? decoder.decode(JSONValue.self, from: Data(structure.json.utf8))
    return BaziStrengthTrace.make(pillars: pillarsValue, strength: strengthValue, structure: structureValue)
}
