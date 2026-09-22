import SwiftUI

struct TodayView: View {
    let date: Date
    let lunarDate: String
    let ganZhi: String
    let solarTerm: String
    let quote: String
    let action: String
    let isRevealed: Bool
    let onReveal: () -> Void
    let onJournal: () -> Void
    let onHistory: () -> Void
    let onShare: () -> Void
    let onReflect: () -> Void

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var reduceMotion: Bool { SujiTheme.reduceMotion(systemReduceMotion) }
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @GestureState private var isDragging = false
    @State private var curlProgress: CGFloat = 0
    @State private var isCompleting = false
    @State private var didRequestReveal = false
    @State private var passedThreshold = false
    @State private var completionID = UUID()
    @State private var naturalPaperHeight: CGFloat = 0
    @State private var dragIntent: Bool?
    @State private var maximumDragDistance: CGFloat = 0
    @AccessibilityFocusState private var isQuoteFocused: Bool

    init(
        date: Date,
        lunarDate: String,
        ganZhi: String,
        solarTerm: String,
        quote: String,
        action: String,
        isRevealed: Bool,
        onReveal: @escaping () -> Void,
        onJournal: @escaping () -> Void,
        onHistory: @escaping () -> Void,
        onShare: @escaping () -> Void,
        onReflect: @escaping () -> Void
    ) {
        self.date = date
        self.lunarDate = lunarDate
        self.ganZhi = ganZhi
        self.solarTerm = solarTerm
        self.quote = quote
        self.action = action
        self.isRevealed = isRevealed
        self.onReveal = onReveal
        self.onJournal = onJournal
        self.onHistory = onHistory
        self.onShare = onShare
        self.onReflect = onReflect
    }

    private var revealed: Bool { isRevealed || didRequestReveal }
    private var showsCover: Bool { !revealed || isCompleting }
    private var dateKey: Date { Calendar.current.startOfDay(for: date) }
    private var revealThreshold: CGFloat { PaperPeelInteraction.revealProgress }
    private var visualProgress: CGFloat {
#if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--ui-testing"), let index = args.firstIndex(of: "--ritual-progress"),
           args.indices.contains(index + 1), let value = Double(args[index + 1]) {
            return min(1, max(0, value))
        }
#endif
        return curlProgress
    }
    private var instruction: String {
        if reduceMotion { return "一页日签，一点心意。" }
        if passedThreshold { return "松开，收下今日。" }
        return isDragging && dragIntent == true ? "向左上，轻轻揭起。" : "从页角，轻揭今天。"
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        introduction
                            .padding(.top, typeSize.isAccessibilitySize ? 12 : 20)
                            .padding(.bottom, typeSize.isAccessibilitySize ? 16 : 24)

                        ritualPaper(height: paperHeight(in: geometry.size))

                        ritualAction
                            .padding(.top, 25)

                        Text("本地编辑 · 每日一签")
                            .font(.caption2)
                            .tracking(1)
                            .foregroundStyle(SujiTheme.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 16)
                            .padding(.bottom, 28)
                        if revealed {
                            Button(action: onReflect) { Label("聊聊今天", systemImage: "bubble.left") }
                                .font(.footnote).foregroundStyle(SujiTheme.secondary)
                                .frame(maxWidth: .infinity).padding(.bottom, 24)
                        }
                    }
                    .frame(maxWidth: 520)
                    .padding(.horizontal, 26)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geometry.size.height, alignment: .top)
                }
                .scrollIndicators(.hidden)
                .scrollDisabled(isDragging && dragIntent == true)
            }
            .background { SujiPaperBackground().ignoresSafeArea() }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("有时")
                        .font(SujiTheme.serif(23, relativeTo: .title3))
                        .tracking(3)
                        .fixedSize(horizontal: true, vertical: false)
                        .foregroundStyle(SujiTheme.ink)
                        .accessibilityAddTraits(.isHeader)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onHistory) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 18, weight: .regular))
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("近七天回顾")
                    .accessibilityIdentifier("ritual.history")
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .tint(SujiTheme.ink)
            .sensoryFeedback(.selection, trigger: passedThreshold) { _, value in value }
            .sensoryFeedback(.success, trigger: didRequestReveal) { _, value in value }
            .onChange(of: isDragging) { _, dragging in
                // GestureState also resets for an interrupted/cancelled drag.
                if !dragging {
                    dragIntent = nil
                    maximumDragDistance = 0
                    if !isCompleting && !revealed { returnPaper() }
                }
            }
            .onChange(of: dateKey) { _, _ in resetRitual() }
            .onChange(of: isRevealed) { _, value in
                if !value { resetRitual() }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { settleInterruptedInteraction() }
            }
            .onDisappear { settleInterruptedInteraction() }
        }
    }

    private var introduction: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                greeting
                Spacer(minLength: 8)
                seasonalLabel
            }
            VStack(alignment: .leading, spacing: 12) {
                greeting
                seasonalLabel
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var greeting: some View {
        Text(revealed ? "把片刻，留给自己。" : "新的一天，慢慢来。")
            .font(typeSize.isAccessibilitySize ? SujiTheme.serif(17, relativeTo: .body) : SujiTheme.serif(25, relativeTo: .title2))
            .foregroundStyle(SujiTheme.ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private var seasonalLabel: some View {
        if !solarTerm.isEmpty {
            Text(solarTerm)
                .font(SujiTheme.serif(15, relativeTo: .subheadline))
                .foregroundStyle(SujiTheme.seasonalAccent(solarTerm))
                .accessibilityIdentifier("ritual.season")
                .fixedSize()
        }
    }

    private func paperHeight(in size: CGSize) -> CGFloat {
        let preferred = min(520, max(404, size.height - 248))
        return max(preferred, naturalPaperHeight)
    }

    private func ritualPaper(height: CGFloat) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomTrailing) {
                // The backing leaves live outside the cover's mask: a thin,
                // visible fore-edge, rather than a floating rounded card.
                paperShape.fill(SujiTheme.line)
                    .padding(.horizontal, 4).offset(y: 6)
                paperShape.fill(SujiTheme.surface)
                    .padding(.horizontal, 2).offset(y: 3)
                    .shadow(color: .black.opacity(0.045), radius: 1, y: 1)

                revealedLeaf(measuring: false)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .background { SujiPaperBackground(color: SujiTheme.surface) }
                    .clipShape(paperShape)
                    .accessibilityHidden(!revealed || isCompleting)

                if showsCover {
                    PaperCurlSurface(progress: reduceMotion ? 0 : visualProgress) {
                        calendarCover
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipShape(paperShape)
                    }
                    .accessibilityHidden(true)

                    if !isCompleting {
                        cornerHandle(in: proxy.size)
                    }
                }
            }
            .background {
                paperShape.fill(SujiTheme.surface)
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.22 : 0.065), radius: 10, x: 0, y: 7)
            }
            .overlay(alignment: .top) {
                // A restrained contact shadow anchors the bound edge.
                UnevenRoundedRectangle(topLeadingRadius: 9, topTrailingRadius: 9)
                    .fill(LinearGradient(colors: [SujiTheme.line.opacity(0.72), SujiTheme.surface.opacity(0)], startPoint: .top, endPoint: .bottom))
                    .frame(height: 9)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .overlay(alignment: .top) {
                // Measure real text at its current Dynamic Type size. The scroll
                // view can grow the leaf instead of clipping large-font content.
                ZStack(alignment: .top) {
                    measureNaturalHeight(calendarCover)
                    measureNaturalHeight(revealedLeaf(measuring: true))
                }
                .hidden()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .onPreferenceChange(PaperContentHeightKey.self) { height in
                if abs(naturalPaperHeight - height) > 0.5 { naturalPaperHeight = height }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("ritual.paper")
            .accessibilityActions {
                if !revealed { Button("揭开今日", action: reveal) }
            }
            .accessibilityLabel(revealed ? "今日日签" : "今日日签，\(accessibleDate)，\(lunarDate)，\(ganZhi)，\(solarTerm)")
        }
        .frame(height: height)
    }

    private var paperShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: 9, bottomLeadingRadius: 2,
                               bottomTrailingRadius: 2, topTrailingRadius: 9)
    }

    private func measureNaturalHeight<Content: View>(_ content: Content) -> some View {
        content
            .fixedSize(horizontal: false, vertical: true)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(key: PaperContentHeightKey.self, value: proxy.size.height)
                }
            }
    }

    private var calendarCover: some View {
        VStack(alignment: .leading, spacing: 0) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    monthLabel.fixedSize()
                    Spacer(minLength: 8)
                    weekdayLabel.fixedSize()
                }
                VStack(alignment: .leading, spacing: 8) {
                    monthLabel
                    weekdayLabel
                }
            }

            Spacer(minLength: 12)

            HStack(alignment: .center, spacing: 8) {
                Text(String(Calendar.current.component(.day, from: date)))
                    .font(.system(size: typeSize.isAccessibilitySize ? 144 : 126, weight: .regular, design: .serif))
                    .tracking(-4)
                    .monospacedDigit()
                    .minimumScaleFactor(0.65)
                    .lineLimit(1)
                    .padding(.leading, -6)
                    .accessibilityHidden(true)
                Spacer(minLength: 0)
                if !typeSize.isAccessibilitySize {
                    SujiBotanical().frame(width: 94, height: 146)
                }
            }

            HStack(alignment: .center, spacing: 14) {
                Text(lunarDate)
                    .font(SujiTheme.serif(22, relativeTo: .title3))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                if !typeSize.isAccessibilitySize { SujiSeal(text: "今日") }
            }
            .padding(.top, 5)

            Rectangle()
                .fill(SujiTheme.line)
                .frame(height: 0.75)
                .padding(.top, 25)
                .padding(.bottom, 16)

            Text(ganZhi)
                .font(.footnote)
                .tracking(1.5)
                .foregroundStyle(SujiTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 28)

            HStack(alignment: .bottom) {
                Text(instruction)
                    .font(SujiTheme.serif(15, relativeTo: .subheadline))
                    .foregroundStyle(SujiTheme.ink.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 40)
            }
        }
        .padding(.horizontal, 29)
        .padding(.top, 29)
        .padding(.bottom, 29)
        .foregroundStyle(SujiTheme.ink)
        .background { SujiPaperBackground(color: SujiTheme.surface) }
    }

    private var monthLabel: some View {
        Text(date.formatted(.dateTime.year().month(.wide).locale(Locale(identifier: "zh_CN"))))
            .font(.subheadline.weight(.medium))
            .tracking(1)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var weekdayLabel: some View {
        Text(date.formatted(.dateTime.weekday(.wide).locale(Locale(identifier: "zh_CN"))))
            .font(.subheadline)
            .foregroundStyle(SujiTheme.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func revealedLeaf(measuring: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("今日一言")
                    .font(.caption.weight(.medium))
                    .tracking(2)
                Spacer(minLength: 12)
                Text(date.formatted(.dateTime.month(.twoDigits).day(.twoDigits)))
                    .font(.caption)
                    .monospacedDigit()
            }
            .foregroundStyle(SujiTheme.secondary)

            Spacer(minLength: 28)

            if measuring {
                quoteText
            } else {
                quoteText
                    .accessibilityFocused($isQuoteFocused)
                    .task(id: revealed && !isCompleting) {
                        guard revealed && !isCompleting else { return }
                        await Task.yield()
                        guard !Task.isCancelled && revealed && !isCompleting else { return }
                        isQuoteFocused = true
                    }
            }

            Spacer(minLength: 30)

            VStack(alignment: .leading, spacing: 12) {
                Text("今日小事")
                    .font(.caption.weight(.medium))
                    .tracking(2)
                    .foregroundStyle(SujiTheme.seasonalAccent(solarTerm))
                Text(action)
                    .font(.subheadline)
                    .lineSpacing(5)
                    .foregroundStyle(SujiTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, 30)

            HStack {
                Rectangle()
                    .fill(SujiTheme.line)
                    .frame(height: 0.75)
                    .padding(.trailing, 18)
                SujiSeal(text: "已阅")
                    .accessibilityLabel("今日已阅")
            }
        }
        .padding(29)
    }

    private var quoteText: some View {
        Text(quote)
            .font(SujiTheme.serif(typeSize.isAccessibilitySize ? 25 : 30, relativeTo: .title2))
            .lineSpacing(10)
            .foregroundStyle(SujiTheme.ink)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("ritual.revealed")
    }

    @ViewBuilder private var ritualAction: some View {
        if revealed {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { journalButton; shareButton }
                VStack(spacing: 12) { journalButton; shareButton }
            }
            .frame(maxWidth: .infinity)
            .opacity(isCompleting ? 0 : 1)
            .allowsHitTesting(!isCompleting)
            .accessibilityHidden(isCompleting)
        } else {
            Button(action: reveal) {
                HStack(spacing: 10) {
                    Text("揭开今日")
                    Image(systemName: "arrow.up.left")
                        .font(.caption.weight(.medium))
                }
                .frame(minWidth: 122)
            }
            .buttonStyle(SujiQuietButtonStyle())
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("ritual.reveal")
            .accessibilityHint("揭开日签，阅读今日一句与一件小事")
        }
    }

    private var journalButton: some View {
        Button(action: onJournal) {
            Label("记下此刻", systemImage: "square.and.pencil")
                .frame(minWidth: 106)
        }
        .buttonStyle(SujiQuietButtonStyle())
        .accessibilityIdentifier("ritual.journal")
    }

    private var shareButton: some View {
        Button(action: onShare) {
            Label("分享日签", systemImage: "square.and.arrow.up")
                .frame(minWidth: 106)
        }
        .buttonStyle(SujiQuietButtonStyle())
        .accessibilityIdentifier("ritual.share")
    }

    private func cornerHandle(in size: CGSize) -> some View {
        Color.clear
            .frame(width: 80, height: 80)
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .updating($isDragging) { _, dragging, _ in dragging = true }
                    .onChanged { value in
                        guard !revealed && !isCompleting else { return }
                        maximumDragDistance = max(maximumDragDistance, hypot(value.translation.width, value.translation.height))
                        guard !reduceMotion && maximumDragDistance >= 8 else { return }
                        if dragIntent == nil {
                            dragIntent = PaperPeelInteraction.isPeelIntent(value.translation)
                        }
                        guard dragIntent == true else { return }
                        curlProgress = PaperPeelInteraction.progress(for: value.translation, width: size.width)
                        passedThreshold = curlProgress >= revealThreshold
                    }
                    .onEnded { value in
                        let completes = PaperPeelInteraction.shouldReveal(
                            at: value.translation, maximumDistance: maximumDragDistance,
                            acquiredPeel: dragIntent == true, width: size.width, reduceMotion: reduceMotion)
                        dragIntent = nil
                        maximumDragDistance = 0
                        if completes { reveal() } else { returnPaper() }
                    }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("揭开今日")
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("ritual.corner")
            .accessibilityAction { reveal() }
    }

    private func reveal() {
        guard !revealed && !isCompleting else { return }
        let token = UUID()
        completionID = token
        didRequestReveal = true
        passedThreshold = false

        // Persist as soon as a valid gesture/button completes. The local paper keeps
        // animating over the persisted content, so leaving the screen cannot lose it.
        if reduceMotion {
            curlProgress = 1
            onReveal()
            return
        }
        isCompleting = true
        onReveal()
        withAnimation(.timingCurve(0.18, 0.72, 0.22, 1, duration: 0.58), completionCriteria: .logicallyComplete) {
            curlProgress = 1
        } completion: {
            guard completionID == token else { return }
            withAnimation(.easeOut(duration: 0.16)) { isCompleting = false }
        }
    }

    private func returnPaper() {
        passedThreshold = false
        withAnimation(reduceMotion ? nil : .timingCurve(0.2, 0.7, 0.25, 1, duration: 0.32)) {
            curlProgress = 0
        }
    }

    private func resetRitual() {
        completionID = UUID()
        curlProgress = 0
        isCompleting = false
        didRequestReveal = false
        isQuoteFocused = false
        dragIntent = nil
        maximumDragDistance = 0
        passedThreshold = false
    }

    private func settleInterruptedInteraction() {
        completionID = UUID()
        isCompleting = false
        curlProgress = revealed ? 1 : 0
        dragIntent = nil
        maximumDragDistance = 0
        passedThreshold = false
    }

    private var accessibleDate: String {
        date.formatted(.dateTime.year().month(.wide).day().weekday(.wide).locale(Locale(identifier: "zh_CN")))
    }
}

private struct PaperContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
