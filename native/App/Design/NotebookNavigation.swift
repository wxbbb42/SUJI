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
