import SwiftUI
import SujiCore

/// The complete report is local. Opening 问道 only stages a question context;
/// neither reading this card nor choosing its action starts a model request.
struct BaziLifeThemeCard: View {
    @Environment(AppStore.self) private var store
    @Environment(\.notebookThemeNavigation) private var navigation
    @Environment(\.openNotebookTheme) private var openTheme
    @State private var localExpanded = false
    @State private var localSources = false
    @State private var localExample = false
    @State private var failure: String?
    @AccessibilityFocusState private var focusedSource: Bool
    let theme: BaziLifeTheme
    private var expanded: Bool { navigation?.readingExpanded ?? localExpanded }
    private var showingSources: Bool { navigation?.sourcesExpanded ?? localSources }
    private var showingExample: Bool { navigation?.exampleExpanded ?? localExample }
    private var sources: [BaziLifeTheme.Source] {
        BaziLifeThemeCompiler.sources.filter { theme.sourceIDs.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("八字 · 生活里的观察").font(.caption.weight(.medium)).foregroundStyle(SujiTheme.sage)
            Text(theme.title).font(SujiTheme.serif(27, relativeTo: .title2))
                .accessibilityAddTraits(.isHeader).accessibilityIdentifier("theme.title")
            Text(theme.summary).font(.body).lineSpacing(7).accessibilityIdentifier("theme.summary")
            // This qualifier changes the meaning of the reading and must not
            // disappear when details or evidence are collapsed.
            Text(theme.boundary).font(.subheadline).foregroundStyle(SujiTheme.secondary)
                .lineSpacing(6).accessibilityIdentifier("theme.boundary")
            continueButton(identifier: "theme.continue")
            Text("先去问道整理问题，由你决定发送。阅读这一页无需等待 AI。")
                .font(.footnote).foregroundStyle(SujiTheme.secondary).lineSpacing(5)
            Button {
                if let navigation { navigation.readingExpanded.toggle() }
                else { localExpanded.toggle() }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(expanded ? "收起细读" : "读懂这一页").font(.subheadline.weight(.medium))
                    Spacer(minLength: 8)
                    Image(systemName: expanded ? "minus" : "plus").font(.subheadline).accessibilityHidden(true)
                }.frame(minHeight: 44).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityValue(expanded ? "已展开" : "已收起")
                .accessibilityIdentifier("theme.expand")
            if expanded {
                Text(theme.explanation).font(.body).lineSpacing(8).textSelection(.enabled)
                section("先和自己的经历对照", text: theme.observation)
                section("试一小步 · 现代编辑练习", text: theme.exercise)
                Button {
                    if let navigation { navigation.exampleExpanded.toggle() }
                    else { localExample.toggle() }
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(showingExample ? "收起生活里的小例子" : "看一个生活里的小例子")
                            .font(.subheadline.weight(.medium))
                        Spacer(minLength: 8)
                        Image(systemName: showingExample ? "minus" : "plus")
                            .font(.subheadline).accessibilityHidden(true)
                    }.frame(minHeight: 44).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("theme.example")
                    .accessibilityValue(showingExample ? "已展开" : "已收起")
                if showingExample {
                    Text(theme.example).font(.body).lineSpacing(7).textSelection(.enabled)
                        .padding(.top, 12).accessibilityIdentifier("theme.example.text")
                }
                // Reading provenance is optional; continuing the conversation
                // must not require traversing the entire professional appendix.
                continueButton(identifier: "theme.continue.footer")
                Button {
                    if let navigation { navigation.sourcesExpanded.toggle() }
                    else { localSources.toggle() }
                } label: {
                    Label(showingSources ? "收起这页的依据" : "为什么这样说", systemImage: "text.book.closed")
                        .font(.subheadline).frame(minHeight: 44)
                }.accessibilityIdentifier("theme.sources")
                    .accessibilityValue(showingSources ? "已展开" : "已收起")
                if showingSources { sourceReading }
            }
            if let failure {
                Text(failure).font(.subheadline).foregroundStyle(SujiTheme.secondary)
                    .accessibilityIdentifier("theme.failure")
            }
            Divider().overlay(SujiTheme.line).padding(.vertical, 8)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }
    private func continueButton(identifier: String) -> some View {
        Button {
            do {
                let binding = try store.makeThemeBinding(theme)
                failure = nil
                openTheme(binding, theme.title, theme.followUpPrompt)
            } catch {
                failure = "这页的资料已变化，暂不能用于对话。请返回后重新打开册页；当前阅读和草稿仍会保留。"
            }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("带着这页继续问").font(.body.weight(.medium))
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.right").font(.subheadline).accessibilityHidden(true)
            }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityIdentifier(identifier)
            .accessibilityHint("前往问道，保留已有草稿，由你决定发送。AI 回信需要联网并登录。")
    }
    private func section(_ title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline.weight(.medium)).accessibilityAddTraits(.isHeader)
            Text(text).font(.body).lineSpacing(7).textSelection(.enabled)
        }.padding(.vertical, 8)
    }
    private var sourceReading: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("传统依据与适用边界").font(.headline).accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("theme.sources.heading")
                .accessibilityFocused($focusedSource).onAppear { focusedSource = true }
            ForEach(sources) { source in
                VStack(alignment: .leading, spacing: 8) {
                    Text(source.locator).font(.subheadline.weight(.medium))
                    Text("「" + source.quote + "」").font(.body).lineSpacing(6)
                        .accessibilityIdentifier("theme.source.quote." + source.id)
                    Text(source.scope).font(.subheadline).foregroundStyle(SujiTheme.secondary).lineSpacing(6)
                        .accessibilityIdentifier("theme.source.scope." + source.id)
                }
            }
            DisclosureGroup("核对计算字段与版本") {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(theme.evidence) { evidence in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(evidence.dossierPointer).font(.caption.weight(.medium))
                            Text(evidence.value).font(.caption).textSelection(.enabled)
                        }
                    }
                    Text("内容版本：" + theme.contentVersion)
                    Text("规则版本：" + theme.ruleVersion)
                    Text("本命快照：" + theme.snapshotID)
                    ForEach(sources) { source in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(source.path)
                            Text("来源校验：" + source.sha256)
                        }
                    }
                }.font(.caption).foregroundStyle(SujiTheme.secondary).padding(.top, 12)
                    .textSelection(.enabled)
            }.font(.subheadline).accessibilityIdentifier("theme.fields")
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(SujiTheme.surface, in: RoundedRectangle(cornerRadius: 16))
    }
}
