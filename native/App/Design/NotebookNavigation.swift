import SwiftUI
import SujiCore

/// This is an unsent navigation intent, not a tool result. The ChatSession checks
/// the complete binding again before collecting real evidence for a reply.
@MainActor @Observable final class NotebookThemeNavigation {
    struct Intent {
        let binding: BaziThemeBinding
        let title: String
        let prompt: String
    }
    var pending: Intent?
    var expiredMessage: String?
    var readingExpanded = false
    var sourcesExpanded = false
    var exampleExpanded = false

    func stage(_ binding: BaziThemeBinding, title: String, prompt: String) {
        pending = Intent(binding: binding, title: title, prompt: prompt)
        expiredMessage = nil
    }
    func clear() { pending = nil; expiredMessage = nil }
    func invalidateBirth() {
        if pending != nil { expiredMessage = "出生资料已重新确认，这页的对话依据已过期。草稿仍在，可返回册页重新选择。" }
        pending = nil; readingExpanded = false; sourcesExpanded = false; exampleExpanded = false
    }
    func resetAccount() {
        clear(); readingExpanded = false; sourcesExpanded = false; exampleExpanded = false
    }
}

private struct NotebookThemeNavigationKey: EnvironmentKey {
    static let defaultValue: NotebookThemeNavigation? = nil
}
private struct OpenNotebookThemeKey: EnvironmentKey {
    static let defaultValue: (BaziThemeBinding, String, String) -> Void = { _, _, _ in }
}
private struct ReturnNotebookThemeKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

private struct OpenNotebookProfileKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}
private struct EditNotebookBirthKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}
extension EnvironmentValues {
    var notebookThemeNavigation: NotebookThemeNavigation? {
        get { self[NotebookThemeNavigationKey.self] }
        set { self[NotebookThemeNavigationKey.self] = newValue }
    }
    var openNotebookTheme: (BaziThemeBinding, String, String) -> Void {
        get { self[OpenNotebookThemeKey.self] }
        set { self[OpenNotebookThemeKey.self] = newValue }
    }
    var returnNotebookTheme: () -> Void {
        get { self[ReturnNotebookThemeKey.self] }
        set { self[ReturnNotebookThemeKey.self] = newValue }
    }
    var openNotebookProfile: () -> Void {
        get { self[OpenNotebookProfileKey.self] }
        set { self[OpenNotebookProfileKey.self] = newValue }
    }
    var editNotebookBirth: () -> Void {
        get { self[EditNotebookBirthKey.self] }
        set { self[EditNotebookBirthKey.self] = newValue }
    }
}

struct NotebookProfileButton: View {
    @Environment(\.openNotebookProfile) private var openProfile
    var body: some View {
        Button(action: openProfile) {
            HStack(spacing: 6) {
                Image(systemName: "person.crop.circle").font(.system(size: 21, weight: .regular))
                Text("我的").font(.subheadline)
            }
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .foregroundStyle(SujiTheme.ink)
        }
        .accessibilityLabel("我的资料与册页")
        .accessibilityIdentifier("nav.profile")
    }
}

/// Three destinations share one selection. The separate capsule is still a tab,
/// so opening 问道 never creates a new conversation or discards a draft.
struct NotebookTabBar: View {
    @Binding var selection: Int
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            HStack(spacing: 4) {
                destination("今日", symbol: "sun.horizon", tag: 0, identifier: "today")
                destination("静心", symbol: "water.waves", tag: 2, identifier: "calm")
            }
            .padding(4)
            .background(SujiTheme.surface, in: Capsule())
            .overlay(Capsule().stroke(SujiTheme.line, lineWidth: 1))
            Spacer(minLength: 12)
            destination("问道", symbol: "bubble.left.and.text.bubble.right", tag: 1, identifier: "chat")
                .padding(4)
                .background(SujiTheme.surface, in: Capsule())
                .overlay(Capsule().stroke(SujiTheme.line, lineWidth: 1))
        }
        .padding(.horizontal, typeSize.isAccessibilitySize ? 16 : 24).padding(.top, 8).padding(.bottom, 6)
        .background(SujiTheme.paper)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("nav.bar")
    }
    private func destination(_ title: String, symbol: String, tag: Int, identifier: String) -> some View {
        Button { selection = tag } label: {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 20, weight: .regular))
                    .frame(width: 24, height: 24)
                Text(title).font(.caption.weight(selection == tag ? .semibold : .regular))
                    .fixedSize(horizontal: true, vertical: false)
            }
            .frame(minWidth: typeSize.isAccessibilitySize ? 60 : 56, minHeight: 44)
            .padding(.horizontal, 4).padding(.vertical, 5)
            .foregroundStyle(selection == tag ? SujiTheme.paper : SujiTheme.ink)
            .background(selection == tag ? SujiTheme.ink : Color.clear, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(selection == tag ? "当前页面" : "")
        .accessibilityAddTraits(selection == tag ? [.isSelected] : [])
        .accessibilityIdentifier("nav." + identifier)
    }
}

/// The close action belongs to the presentation, outside its navigation path.
/// It remains available even when a legacy chart pushes another detail page.
struct NotebookProfileSheet: View {
    @Environment(AppStore.self) private var store
    @State private var editingBirth = false
    var startsAtTheme = false
    let close: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("个人资料").font(.subheadline).foregroundStyle(SujiTheme.secondary)
                Spacer()
                Button(action: close) {
                    Text("关闭").frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                }
                    .accessibilityLabel("关闭个人资料，返回原页面")
                    .accessibilityIdentifier("profile.close")
            }.padding(.horizontal, 24).background(SujiTheme.paper)
            NavigationStack {
                if startsAtTheme { NatalReadingReportView(focusTheme: true) }
                else { ProfileView() }
            }
        }
        .background(SujiTheme.paper)
        .environment(\.editNotebookBirth, { editingBirth = true })
        .sheet(isPresented: $editingBirth) {
            BirthEditor(existing: store.state.birth) { birth in try await store.updateBirth(birth) }
        }
    }
}
