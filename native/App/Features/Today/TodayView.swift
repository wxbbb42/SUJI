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
    private var revealThreshold: CGFloat { 0.27 }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        introduction
                            .padding(.top, 20)
                            .padding(.bottom, 28)

                        ritualPaper(height: paperHeight(in: geometry.size))

                        ritualAction
                            .padding(.top, 25)

                        Text("本地编辑 · 每日一签")
                            .font(.caption2)
                            .tracking(1)
                            .foregroundStyle(SujiTheme.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 20)
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
                if !dragging && !isCompleting && !revealed { returnPaper() }
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
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            VStack(alignment: .leading, spacing: 9) {
                Text("一日一签")
                    .font(.caption.weight(.medium))
                    .tracking(3)
                    .foregroundStyle(SujiTheme.secondary)
                Text(revealed ? "把片刻，留给自己。" : "新的一天，慢慢来。")
                    .font(SujiTheme.serif(25, relativeTo: .title2))
                    .foregroundStyle(SujiTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if !solarTerm.isEmpty && !typeSize.isAccessibilitySize {
                Text(solarTerm)
                    .font(SujiTheme.serif(15, relativeTo: .subheadline))
                    .foregroundStyle(SujiTheme.seasonalAccent(solarTerm))
                    .fixedSize()
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func paperHeight(in size: CGSize) -> CGFloat {
        let preferred = min(520, max(404, size.height - 248))
        return max(preferred, naturalPaperHeight)
    }

    private func ritualPaper(height: CGFloat) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomTrailing) {
                // A bound edge and one underlying leaf give depth without a card stack UI.
                Rectangle()
                    .fill(SujiTheme.line.opacity(0.42))
                    .padding(.horizontal, 4)
                    .offset(y: 5)

                revealedLeaf
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .background(SujiTheme.surface)
                    .accessibilityHidden(!revealed || isCompleting)

                if showsCover {
                    PaperCurlSurface(progress: reduceMotion ? 0 : curlProgress) {
                        calendarCover
                            .frame(width: proxy.size.width, height: proxy.size.height)
                    }
                    .accessibilityHidden(true)

                    if !reduceMotion && !isCompleting {
                        cornerHandle(in: proxy.size)
                    }
                }
            }
            .clipShape(UnevenRoundedRectangle(
                topLeadingRadius: 12,
                bottomLeadingRadius: 3,
                bottomTrailingRadius: 3,
                topTrailingRadius: 12
            ))
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(SujiTheme.ink.opacity(0.10))
                    .frame(height: 1)
            }
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.07), radius: 16, x: 0, y: 8)
            .overlay(alignment: .top) {
                // Measure real text at its current Dynamic Type size. The scroll
                // view can grow the leaf instead of clipping large-font content.
                ZStack(alignment: .top) {
                    measureNaturalHeight(calendarCover)
                    measureNaturalHeight(revealedLeaf)
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
            .accessibilityAction(named: "揭开今日") { reveal() }
            .accessibilityLabel(revealed ? "今日日签" : "今日日签，\(accessibleDate)，\(lunarDate)，\(ganZhi)")
        }
        .frame(height: height)
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
            HStack(alignment: .firstTextBaseline) {
                Text(date.formatted(.dateTime.year().month(.wide).locale(Locale(identifier: "zh_CN"))))
                    .font(.subheadline.weight(.medium))
                    .tracking(1)
                Spacer(minLength: 8)
                Text(date.formatted(.dateTime.weekday(.wide).locale(Locale(identifier: "zh_CN"))))
                    .font(.subheadline)
                    .foregroundStyle(SujiTheme.secondary)
            }

            Spacer(minLength: 12)

            HStack(alignment: .center, spacing: 8) {
                Text(String(Calendar.current.component(.day, from: date)))
                    .font(.system(size: typeSize.isAccessibilitySize ? 144 : 126, weight: .regular, design: .serif))
                    .tracking(-7)
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
                SujiSeal(text: "今日")
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
                Text(reduceMotion ? "一页日签，一点心意。" : "轻揭一页，开始今天。")
                    .font(SujiTheme.serif(15, relativeTo: .subheadline))
                    .foregroundStyle(SujiTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 34)
            }
        }
        .padding(.horizontal, 29)
        .padding(.top, 29)
        .padding(.bottom, 29)
        .foregroundStyle(SujiTheme.ink)
        .background { SujiPaperBackground(color: SujiTheme.surface) }
    }

    private var revealedLeaf: some View {
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

            Text(quote)
                .font(SujiTheme.serif(typeSize.isAccessibilitySize ? 25 : 30, relativeTo: .title2))
                .lineSpacing(10)
                .foregroundStyle(SujiTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("ritual.revealed")

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
        Image(systemName: "arrow.up.left")
            .font(.system(size: 14, weight: .light))
            .foregroundStyle(SujiTheme.secondary.opacity(curlProgress > 0.03 ? 0 : 0.7))
            .frame(width: 72, height: 72, alignment: .center)
            .background(Color.clear)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 4, coordinateSpace: .local)
                    .updating($isDragging) { _, dragging, _ in dragging = true }
                    .onChanged { value in
                        guard !revealed && !isCompleting else { return }
                        curlProgress = progress(for: value.translation, in: size)
                        passedThreshold = curlProgress >= revealThreshold
                    }
                    .onEnded { value in
                        let actual = progress(for: value.translation, in: size)
                        if actual >= revealThreshold {
                            reveal()
                        } else {
                            returnPaper()
                        }
                    }
            )
            .accessibilityHidden(true)
    }

    private func progress(for translation: CGSize, in size: CGSize) -> CGFloat {
        let distance = -translation.width * PaperCurlGeometry.normal.x - translation.height * PaperCurlGeometry.normal.y
        return min(0.88, max(0, distance / (max(size.width, size.height) * 1.4)))
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
        withAnimation(.timingCurve(0.18, 0.72, 0.22, 1, duration: 0.78), completionCriteria: .logicallyComplete) {
            curlProgress = 1
        } completion: {
            guard completionID == token else { return }
            withAnimation(.easeOut(duration: 0.18)) { isCompleting = false }
        }
    }

    private func returnPaper() {
        passedThreshold = false
        withAnimation(reduceMotion ? nil : .spring(response: 0.46, dampingFraction: 0.88)) {
            curlProgress = 0
        }
    }

    private func resetRitual() {
        completionID = UUID()
        curlProgress = 0
        isCompleting = false
        didRequestReveal = false
        passedThreshold = false
    }

    private func settleInterruptedInteraction() {
        completionID = UUID()
        isCompleting = false
        curlProgress = revealed ? 1 : 0
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

/// The page bends around a moving diagonal cylinder. Each clipped strip gets
/// its own affine projection; the entire page is never rotated as a rigid card.
private struct PaperCurlSurface<Front: View>: View, Animatable {
    nonisolated var progress: CGFloat
    @ViewBuilder var front: () -> Front

    nonisolated var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        Canvas { context, size in
            guard let symbol = context.resolveSymbol(id: "calendar-front") else { return }
            let geometry = PaperCurlGeometry(size: size, progress: progress)
            if progress < 0.0001 {
                context.draw(symbol, at: .zero, anchor: .topLeading)
                return
            }

            let flatPath = geometry.path(for: geometry.clippedPolygon(lower: -.infinity, upper: geometry.fold))
            var flatContext = context
            flatContext.clip(to: flatPath)
            flatContext.draw(symbol, at: .zero, anchor: .topLeading)

            let strips = geometry.strips(count: 48)
            var shadow = context
            shadow.addFilter(.blur(radius: 8 + geometry.radius * 0.08))
            for strip in strips {
                var projected = strip.path.applying(strip.transform)
                projected = projected.offsetBy(dx: 2, dy: 5)
                shadow.fill(projected, with: .color(.black.opacity(0.085)))
            }

            for strip in strips {
                var layer = context
                layer.concatenate(strip.transform)
                layer.clip(to: strip.path)
                if strip.isBack {
                    layer.fill(strip.path, with: .color(SujiTheme.surface))
                    layer.fill(strip.path, with: .color(SujiTheme.line.opacity(0.25)))
                } else {
                    layer.draw(symbol, at: .zero, anchor: .topLeading)
                }
                layer.fill(strip.path, with: .color(.black.opacity(strip.shade)))
                if strip.highlight > 0 {
                    layer.fill(strip.path, with: .color(.white.opacity(strip.highlight)))
                }
            }
        } symbols: {
            front().tag("calendar-front")
        }
        .allowsHitTesting(false)
    }
}

/// Pure geometry, independent of gesture state and SwiftUI rendering. A convex
/// clip keeps every strip inside the source leaf before cylinder projection.
struct PaperCurlGeometry {
    static let normal = CGPoint(x: 0.64, y: 0.7683749084919419)
    let size: CGSize
    let progress: CGFloat

    var extent: CGFloat { size.width * Self.normal.x + size.height * Self.normal.y }
    var radius: CGFloat { 21 + 24 * sin(min(1, max(0, progress)) * .pi) }
    var fold: CGFloat { extent - max(0, min(1, progress)) * (extent + 140) }

    struct Strip {
        let path: Path
        let transform: CGAffineTransform
        let isBack: Bool
        let shade: Double
        let highlight: Double
    }

    func strips(count: Int) -> [Strip] {
        let start = max(0, fold)
        guard count > 0, extent > start else { return [] }
        let step = (extent - start) / CGFloat(count)
        return (0..<count).compactMap { index in
            let lower = start + CGFloat(index) * step
            let upper = lower + step
            let polygon = clippedPolygon(lower: lower - 0.16, upper: upper + 0.16)
            guard polygon.count > 2 else { return nil }
            let middle = (lower + upper) / 2 - fold
            let angle = min(.pi, max(0, middle / radius))
            let back = angle > .pi / 2
            let shade = 0.018 + 0.22 * pow(sin(angle), 4) + (back ? 0.015 : 0)
            let highlight = 0.11 * pow(max(0, cos(angle - 0.45)), 8)
            return Strip(
                path: path(for: polygon),
                transform: transform(lower: lower, upper: upper),
                isBack: back,
                shade: shade,
                highlight: highlight
            )
        }
    }

    func clippedPolygon(lower: CGFloat, upper: CGFloat) -> [CGPoint] {
        let corners = [CGPoint.zero, CGPoint(x: size.width, y: 0),
                       CGPoint(x: size.width, y: size.height), CGPoint(x: 0, y: size.height)]
        return clip(clip(corners, boundary: upper, keepLower: true), boundary: lower, keepLower: false)
    }

    func path(for polygon: [CGPoint]) -> Path {
        Path { path in
            guard let first = polygon.first else { return }
            path.move(to: first)
            polygon.dropFirst().forEach { path.addLine(to: $0) }
            path.closeSubpath()
        }
    }

    private func position(_ distance: CGFloat) -> (plane: CGFloat, height: CGFloat) {
        let arcLength = .pi * radius
        if distance > arcLength { return (-(distance - arcLength), 2 * radius) }
        let angle = max(0, distance) / radius
        return (radius * sin(angle), radius * (1 - cos(angle)))
    }

    private func transform(lower: CGFloat, upper: CGFloat) -> CGAffineTransform {
        let first = position(lower - fold)
        let last = position(upper - fold)
        let delta = max(0.0001, upper - lower)
        let scale = (last.plane - first.plane) / delta
        let liftScale = (last.height - first.height) / delta
        let planeOffset = fold + first.plane - scale * lower
        let liftOffset = first.height - liftScale * lower
        let n = Self.normal
        // The slight vertical height projection makes the lifted edge read as
        // volume. Source text bends with the front; the reverse is blank paper.
        return CGAffineTransform(
            a: 1 + (scale - 1) * n.x * n.x,
            b: (scale - 1) * n.y * n.x - 0.18 * liftScale * n.x,
            c: (scale - 1) * n.x * n.y,
            d: 1 + (scale - 1) * n.y * n.y - 0.18 * liftScale * n.y,
            tx: n.x * planeOffset,
            ty: n.y * planeOffset - 0.18 * liftOffset
        )
    }

    private func clip(_ polygon: [CGPoint], boundary: CGFloat, keepLower: Bool) -> [CGPoint] {
        guard !polygon.isEmpty else { return [] }
        if boundary == .infinity { return keepLower ? polygon : [] }
        if boundary == -.infinity { return keepLower ? [] : polygon }
        func signedDistance(_ point: CGPoint) -> CGFloat {
            let value = point.x * Self.normal.x + point.y * Self.normal.y - boundary
            return keepLower ? value : -value
        }
        var result: [CGPoint] = []
        var previous = polygon[polygon.count - 1]
        var previousDistance = signedDistance(previous)
        for point in polygon {
            let distance = signedDistance(point)
            if (distance <= 0) != (previousDistance <= 0) {
                let fraction = previousDistance / (previousDistance - distance)
                result.append(CGPoint(
                    x: previous.x + (point.x - previous.x) * fraction,
                    y: previous.y + (point.y - previous.y) * fraction
                ))
            }
            if distance <= 0 { result.append(point) }
            previous = point
            previousDistance = distance
        }
        return result
    }
}
