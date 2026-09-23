import SwiftUI
import SujiCore

private extension NatalReportSystem {
    var notebookName: String {
        switch self { case .bazi: "八字"; case .ziwei: "紫微"; case .mansions: "出生星宿"; case .qizheng: "七政四余" }
    }
    var notebookCoverage: String {
        switch self {
        case .bazi: "位置与关系"
        case .ziwei: "宫位与星曜"
        case .mansions: "月亮所处参照宿"
        case .qizheng: "排盘与安命说明"
        }
    }
    var usesAstronomy: Bool { self == .mansions || self == .qizheng }
}

/// Input identity includes the complete birth record, even display-only fields.
/// The store's scope revision also prevents an A → B → A account race.
private struct NotebookReportIdentity: Equatable, Hashable {
    let scope: String
    let revision: UUID
    let birthRevision: UUID
    let birth: String
    let engine: String
    let content: String
    let adapter: String
    @MainActor init(_ store: AppStore) {
        scope = store.scopeKey; revision = store.scopeRevision
        birthRevision = store.birthRevision
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        birth = (try? encoder.encode(store.state.birth)).map { String(decoding: $0, as: UTF8.self) } ?? "null"
        engine = store.engineRevision
        content = NatalReadingCompiler.contentVersion
        adapter = NatalReadingCompiler.adapterVersion
    }
}
private struct NotebookReportResult {
    let identity: NotebookReportIdentity
    let reports: [NatalReadingReport]
}
private struct NotebookReportFailure {
    let identity: NotebookReportIdentity
    let message: String
    let canRetry: Bool
}
private struct NotebookReportTask: Equatable {
    let identity: NotebookReportIdentity
    let attempt: Int
    var enabled = true
}

struct NatalReadingReportView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.editNotebookBirth) private var editBirth
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var system: NatalReportSystem = .bazi
    @State private var natal: NotebookReportResult?
    @State private var astronomy: NotebookReportResult?
    @State private var natalFailure: NotebookReportFailure?
    @State private var astronomyFailure: NotebookReportFailure?
    @State private var natalAttempt = 0
    @State private var astronomyAttempt = 0
    @State private var expandedEntries: Set<String> = []
    @State private var expandedSources: Set<String> = []
    @State private var readingPositions: [NatalReportSystem: String] = [:]
    @State private var visiblePosition: String?
    @AccessibilityFocusState private var sourceFocus: String?
    var focusTheme = false
    private var identity: NotebookReportIdentity { NotebookReportIdentity(store) }
    private var currentReport: NatalReadingReport? {
        let result = system.usesAstronomy ? astronomy : natal
        guard result?.identity == identity else { return nil }
        return result?.reports.first { $0.system == system && $0.contentVersion == NatalReadingCompiler.contentVersion }
    }
    private var currentFailure: NotebookReportFailure? {
        let failure = system.usesAstronomy ? astronomyFailure : natalFailure
        return failure?.identity == identity ? failure : nil
    }
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    introduction.id("report.top")
                    systemPicker
                    if let report = currentReport, report.system == .bazi,
                       let theme = try? BaziLifeThemeCompiler.compile(report: report) {
                        BaziLifeThemeCard(theme: theme).id("report.theme")
                    }
                    NavigationLink { ProfessionalArchiveView(system: system) } label: {
                        HStack(spacing: 12) {
                            Text("专业档案").font(.subheadline.weight(.medium))
                            Text("核对原盘").font(.subheadline).foregroundStyle(SujiTheme.secondary)
                            Spacer(minLength: 8)
                            Image(systemName: "arrow.up.right").font(.subheadline)
                        }.frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityIdentifier("report.professional")
                    if let report = currentReport {
                        reportSummary(report)
                        HStack(alignment: .firstTextBaseline) {
                            Text("从这里读起").font(SujiTheme.serif(23, relativeTo: .title2))
                                .accessibilityAddTraits(.isHeader)
                            Spacer(minLength: 8)
                            Menu {
                                ForEach(report.entries) { entry in
                                    Button(entry.title) { proxy.scrollTo(entry.id, anchor: .top) }
                                }
                            } label: { Label("位置目录", systemImage: "list.bullet").font(.subheadline).frame(minHeight: 44) }
                        }
                        ForEach(Array(report.entries.enumerated()), id: \.element.id) { index, entry in
                            if index == 2 {
                                Text("沿着位置继续读").font(SujiTheme.serif(23, relativeTo: .title2))
                                    .accessibilityAddTraits(.isHeader).padding(.top, 12)
                            }
                            readingEntry(entry, report: report).id(entry.id)
                        }
                        Text("基础读盘无需等待 AI 回信，可随时回来看。")
                            .font(.footnote).foregroundStyle(SujiTheme.secondary).lineSpacing(5)
                    } else {
                        reportState
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 40)
                .frame(maxWidth: 680).frame(maxWidth: .infinity)
            }
            .scrollPosition(id: $visiblePosition, anchor: .top)
            .onChange(of: system) { old, new in
                if let visiblePosition { readingPositions[old] = visiblePosition }
                proxy.scrollTo(readingPositions[new] ?? "report.top", anchor: .top)
            }
            .onChange(of: currentReport?.snapshotID) { _, snapshot in
                if focusTheme && snapshot != nil && system == .bazi {
                    proxy.scrollTo("report.theme", anchor: .top)
                }
            }
        }
        .background(SujiTheme.paper).foregroundStyle(SujiTheme.ink)
        .navigationTitle("我的册页").navigationBarTitleDisplayMode(.inline)
        .task(id: NotebookReportTask(identity: identity, attempt: natalAttempt)) { await loadNatal() }
        .task(id: NotebookReportTask(identity: identity, attempt: astronomyAttempt, enabled: system.usesAstronomy)) {
            if system.usesAstronomy { await loadAstronomy() }
        }
    }

    private var introduction: some View {
        Text("基于当前出生资料 · 基础读盘")
            .font(.subheadline).foregroundStyle(SujiTheme.secondary)
    }
    private var systemPicker: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: typeSize.isAccessibilitySize ? 1 : 2), alignment: .leading, spacing: 8) {
            ForEach(NatalReportSystem.allCases, id: \.self) { item in
                Button { system = item } label: {
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(item.notebookName).font(.subheadline.weight(.medium))
                            Text(item.notebookCoverage).font(.caption).foregroundStyle(SujiTheme.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        if system == item { Image(systemName: "checkmark").font(.caption.weight(.semibold)).padding(.top, 2) }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(system == item ? SujiTheme.surface : Color.clear, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(system == item ? SujiTheme.sage : SujiTheme.line, lineWidth: 1))
                    .contentShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.notebookName + "，" + item.notebookCoverage)
                .accessibilityAddTraits(system == item ? [.isSelected] : [])
                .accessibilityIdentifier("report.system." + item.rawValue)
            }
        }
    }
    private func reportSummary(_ report: NatalReadingReport) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(report.title).font(SujiTheme.serif(26, relativeTo: .title2)).accessibilityAddTraits(.isHeader)
            Text(report.summary).font(.body).lineSpacing(7).accessibilityIdentifier("report.summary")
            Text(report.boundary).font(.subheadline).foregroundStyle(SujiTheme.secondary).lineSpacing(6)
                .accessibilityIdentifier("report.boundary")
            Divider().overlay(SujiTheme.line).padding(.top, 4)
        }.textSelection(.enabled)
    }
    private func readingEntry(_ entry: NatalReadingReport.Entry, report: NatalReadingReport) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                if !expandedEntries.insert(entry.id).inserted { expandedEntries.remove(entry.id) }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(entry.title).font(.headline.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    Image(systemName: expandedEntries.contains(entry.id) ? "minus" : "plus").font(.subheadline)
                }.frame(minHeight: 44, alignment: .leading).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(entry.title + "，细读")
            .accessibilityValue(expandedEntries.contains(entry.id) ? "已展开" : "已收起")
            .accessibilityIdentifier("report.entry." + entry.id)
            Text(entry.summary).font(.body).lineSpacing(6)
            // Meaning-changing conditions remain visible when the long reading is collapsed.
            Text(entry.boundary).font(.subheadline).foregroundStyle(SujiTheme.secondary).lineSpacing(5)
            if expandedEntries.contains(entry.id) {
                Text(entry.explanation).font(.body).lineSpacing(7).textSelection(.enabled)
                if let reflection = entry.reflection {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("留给自己的问题 · 编辑提问").font(.footnote.weight(.medium)).foregroundStyle(SujiTheme.sage)
                        Text(reflection).font(.body).lineSpacing(6)
                    }.padding(.vertical, 8)
                }
                Button {
                    if !expandedSources.insert(entry.id).inserted {
                        expandedSources.remove(entry.id)
                        sourceFocus = "trigger:" + entry.id
                    }
                } label: {
                    Label(expandedSources.contains(entry.id) ? "收起依据" : "为什么这样说", systemImage: "text.book.closed")
                        .font(.subheadline).frame(minHeight: 44)
                }
                .accessibilityLabel(entry.title + "，为什么这样说")
                .accessibilityValue(expandedSources.contains(entry.id) ? "已展开" : "已收起")
                .accessibilityIdentifier("report.sources." + entry.id)
                .accessibilityFocused($sourceFocus, equals: "trigger:" + entry.id)
                if expandedSources.contains(entry.id) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("本盘依据").font(.headline).accessibilityAddTraits(.isHeader)
                            .accessibilityFocused($sourceFocus, equals: "source:" + entry.id)
                            .onAppear { sourceFocus = "source:" + entry.id }
                        Text(entry.summary).font(.subheadline).lineSpacing(5)
                        ForEach(entry.sources, id: \.id) { source in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(source.title).font(.subheadline.weight(.medium))
                                Text(source.note).font(.footnote).foregroundStyle(SujiTheme.secondary).lineSpacing(5)
                                if let value = source.url, let url = URL(string: value), ["https", "http"].contains(url.scheme ?? "") {
                                    Link("查看来源", destination: url).font(.footnote).frame(minHeight: 44)
                                }
                            }
                        }
                        DisclosureGroup("计算字段与版本") {
                            VStack(alignment: .leading, spacing: 16) {
                                ForEach(entry.sources, id: \.id) { source in
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(source.title).font(.subheadline.weight(.medium))
                                        Text(source.locator).font(.footnote)
                                        Text(source.id).font(.caption).foregroundStyle(SujiTheme.secondary)
                                    }
                                }
                                ForEach(Array(entry.evidence.enumerated()), id: \.offset) { _, evidence in
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(evidence.value).font(.subheadline)
                                        Text(evidence.pointer).font(.caption).foregroundStyle(SujiTheme.secondary)
                                            .textSelection(.enabled)
                                    }
                                }
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("本命快照 " + report.snapshotID)
                                    Text("内容版本 " + report.contentVersion)
                                    Text("字段适配版本 " + report.adapterVersion)
                                }.font(.caption).foregroundStyle(SujiTheme.secondary)
                                    .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                            }.padding(.top, 12)
                        }.font(.subheadline).accessibilityIdentifier("report.fields." + entry.id)
                    }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                        .background(SujiTheme.surface, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            Divider().overlay(SujiTheme.line).padding(.top, 10)
        }
    }
    @ViewBuilder private var reportState: some View {
        if store.state.birth == nil {
            VStack(alignment: .leading, spacing: 16) {
                Text("从出生资料开始").font(SujiTheme.serif(25, relativeTo: .title2))
                Text("填写日期、时刻与地点后，可建立本命档案，阅读对应的位置说明。")
                    .font(.body).foregroundStyle(SujiTheme.secondary).lineSpacing(6)
                Button("填写出生资料", action: editBirth).frame(minHeight: 44)
            }
        } else if let failure = currentFailure {
            VStack(alignment: .leading, spacing: 16) {
                Text(system.usesAstronomy ? "星历说明暂未载入" : "基础读盘暂未载入").font(.headline)
                Text(failure.message).font(.body).foregroundStyle(SujiTheme.secondary).lineSpacing(6)
                if failure.canRetry {
                    Button(system.usesAstronomy ? "重新读取星历" : "重新建立读盘") {
                        if system.usesAstronomy { astronomyAttempt += 1 } else { natalAttempt += 1 }
                    }.frame(minHeight: 44)
                }
                Button("查看出生资料", action: editBirth).frame(minHeight: 44)
            }
        } else {
            ProgressView(system.usesAstronomy ? "正在整理出生星历说明…" : "正在整理本命位置说明…")
                .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 28)
        }
    }
    @MainActor private func loadNatal() async {
        let request = identity
        guard natal?.identity != request, let birth = store.state.birth else { return }
        natal = nil; natalFailure = nil
        do {
            let dossier = try await store.ensureNatalDossier()
            try Task.checkCancellation()
            guard request == identity else { return }
            let reports = try NatalReadingCompiler.natal(dossier: dossier, ownerID: request.scope, birth: birth, engineRevision: request.engine, enginePayloadRevision: store.natalPayloadRevision ?? "")
            try Task.checkCancellation()
            guard request == identity else { return }
            natal = NotebookReportResult(identity: request, reports: reports)
        } catch is CancellationError { }
        catch {
            guard !Task.isCancelled, request == identity else { return }
            natalFailure = failure(error, identity: request)
        }
    }
    @MainActor private func loadAstronomy() async {
        let request = identity
        guard astronomy?.identity != request, let birth = store.state.birth else { return }
        astronomy = nil; astronomyFailure = nil
        do {
            let dossier = try await store.ensureNatalAstronomyDossier()
            try Task.checkCancellation()
            guard request == identity, store.hasNatalAstronomyDossier else { return }
            let reports = try NatalReadingCompiler.astronomy(dossier: dossier, ownerID: request.scope, birth: birth, engineRevision: request.engine, enginePayloadRevision: dossier.enginePayloadRevision)
            try Task.checkCancellation()
            guard request == identity else { return }
            astronomy = NotebookReportResult(identity: request, reports: reports)
        } catch is CancellationError { }
        catch {
            guard !Task.isCancelled, request == identity else { return }
            astronomyFailure = failure(error, identity: request)
        }
    }
    private func failure(_ error: Error, identity: NotebookReportIdentity) -> NotebookReportFailure {
        if error is EngineContract.Failure {
            return NotebookReportFailure(identity: identity, message: "当前档案的字段或计算方法与本版读盘不兼容，暂时无法显示。出生资料仍已保留，无需为此修改；需要兼容的应用版本或重新建立档案。", canRetry: false)
        }
        return NotebookReportFailure(identity: identity, message: error.localizedDescription, canRetry: true)
    }
}

/// One professional destination carries the selected reading system into the
/// existing chart and ephemeris pages. Time-dependent reading remains separate.
struct ProfessionalArchiveView: View {
    @Environment(AppStore.self) private var store
    @State private var system: NatalReportSystem
    init(system: NatalReportSystem) { _system = State(initialValue: system) }
    private var natalDocument: Document? {
        guard store.hasNatalDossier, let dossier = store.natalDossier else { return nil }
        return try? Document(data: dossier.payload)
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("核对原盘").font(SujiTheme.serif(30, relativeTo: .largeTitle)).accessibilityAddTraits(.isHeader)
                Text("当前阅读：" + system.notebookName + " · " + system.notebookCoverage)
                    .font(.body).foregroundStyle(SujiTheme.secondary).fixedSize(horizontal: false, vertical: true)
                Picker("核对体系", selection: $system) {
                    ForEach(NatalReportSystem.allCases, id: \.self) { Text($0.notebookName).tag($0) }
                }.pickerStyle(.menu)
                if system.usesAstronomy {
                    astronomyLink
                    chartsLink
                } else {
                    chartsLink
                    astronomyLink
                }
                Divider().overlay(SujiTheme.line)
                NavigationLink { FortuneDetailView() } label: {
                    archiveRow("人生的节奏", detail: "另看大运与所选流年，属于随时间变化的资料")
                }.accessibilityIdentifier("professional.fortune")
                Text("原盘用于核对计算事实与方法。传统规则含有简化项，不替代现实中的判断。")
                    .font(.footnote).foregroundStyle(SujiTheme.secondary).lineSpacing(6)
            }.padding(24).frame(maxWidth: 680).frame(maxWidth: .infinity)
        }
        .background(SujiTheme.paper).foregroundStyle(SujiTheme.ink)
        .navigationTitle("专业档案").navigationBarTitleDisplayMode(.inline)
    }
    private var astronomyLink: some View {
        NavigationLink { NatalAstronomyView() } label: {
            archiveRow("出生星历", detail: system == .mansions ? "月亮参照宿、宿界与原始角度" : "七曜、四余、命宫与命度")
        }.accessibilityIdentifier("professional.astronomy")
    }
    @ViewBuilder private var chartsLink: some View {
        if let profile = natalDocument {
            NavigationLink { ChartDetailView(profile: profile, initialSelection: system == .ziwei ? 1 : 0) } label: {
                archiveRow("命盘手稿", detail: system == .ziwei ? "紫微十二宫、星曜与生年四化" : "四柱、透藏与计算口径")
            }.accessibilityIdentifier("professional.charts")
        } else {
            Text("本命档案尚未建立，请返回册页检查出生资料。")
                .font(.body).foregroundStyle(SujiTheme.secondary)
        }
    }
    private func archiveRow(_ title: String, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text(title).font(SujiTheme.serif(24, relativeTo: .title2))
                Text(detail).font(.subheadline).foregroundStyle(SujiTheme.secondary).lineSpacing(5)
            }.fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Image(systemName: "chevron.right").font(.subheadline)
        }.foregroundStyle(SujiTheme.ink).frame(maxWidth: .infinity, minHeight: 44).padding(.vertical, 12)
            .contentShape(Rectangle())
    }
}
