import SwiftUI
import UIKit
import SujiCore

/// Only presentation: qualifications and complete bodies come from the local document.
/// A section cannot be collapsed independently of the qualifications attached to it.
struct ReadingDocumentView: View {
    let document: ReadingDocument
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            ForEach(document.sections) { section in
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(section.title)
                            .font(SujiTheme.serif(23, relativeTo: .title3))
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("reading.title." + section.id)
                        Text(qualificationLabel(section.qualification))
                            .font(.footnote.weight(.medium)).foregroundStyle(SujiTheme.secondary)
                            .accessibilityIdentifier("reading.qualification." + section.id)
                    }
                    Text(section.body)
                        .font(.body).lineSpacing(6).textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("reading.body." + section.id)
                    if ["strength", "strength-brief"].contains(section.id),
                       let trace = BaziStrengthTrace.from(evidence: section.evidence) {
                        BaziStrengthTraceView(trace: trace, showsSummary: false,
                                              showsFootnote: false,
                                              identifier: "reading.strength.trace")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("reading.section." + section.id)
            }
            Button {
                UIPasteboard.general.string = document.plainText
                copied = true
            } label: {
                Label(copied ? "已复制完整回信" : "复制完整回信", systemImage: copied ? "checkmark" : "doc.on.doc")
                    .font(.footnote).frame(minHeight: 44)
            }
            .accessibilityIdentifier("reading.copy")
        }
    }

    private func qualificationLabel(_ qualification: BaziFrameworkReading.Claim.Qualification) -> String {
        switch qualification {
        case .calculated: "本地计算"
        case .heuristic: "启发式参考 · 尚未验证预测效力"
        case .candidate: "结构候选 · 尚不能认定成格"
        case .conditionalSource: "文献候选 · 适用条件待核对"
        case .definition: "概念说明"
        }
    }
}
