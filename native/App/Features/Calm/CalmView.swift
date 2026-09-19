import SwiftUI
import SujiCore

@MainActor
struct CalmView: View {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var reduceMotion: Bool { SujiTheme.reduceMotion(systemReduceMotion) }
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var audio = AmbienceAudio.shared
    @State private var selectedMinutes = 5
    @State private var clock = BreathingClock(duration: 5 * 60)
    @State private var snapshot = BreathingClock(duration: 5 * 60).snapshot(at: 0)
    @State private var tickTask: Task<Void, Never>?
    @State private var completed = false
    @State private var selectedPresetID = SolarTermAmbiencePreset.current().id
    @State private var standaloneTimer: StandaloneAmbienceTimer = .off
    @State private var appliedInitialPreset = false

    var body: some View {
        ZStack {
            SujiPaperBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    heading
                    breathingFocus
                        .padding(.top, 36)
                    controls
                        .padding(.top, 44)
                    soundMixer
                        .padding(.top, 36)
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 40)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .foregroundStyle(SujiTheme.ink)
        .onAppear(perform: restoreView)
        .onDisappear(perform: stopRendering)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                refreshClock()
                if snapshot.state == .running { startTicking() }
            } else {
                stopRendering()
            }
        }
    }

    private var heading: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 7) {
                Text("静心")
                    .font(SujiTheme.serif(34, relativeTo: .largeTitle))
                Text("把一息，还给此刻")
                    .font(.subheadline)
                    .tracking(1)
                    .foregroundStyle(SujiTheme.secondary)
            }
            Spacer(minLength: 20)
            Label(audio.isPlaying ? "音景播放中" : "音景已静音", systemImage: audio.isPlaying ? "waveform" : "speaker.slash")
                .labelStyle(.iconOnly)
                .foregroundStyle(audio.isPlaying ? SujiTheme.sage : SujiTheme.secondary)
                .accessibilityLabel(audio.isPlaying ? "音景播放中" : "音景已静音")
        }
    }

    private var breathingFocus: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .stroke(SujiTheme.line, lineWidth: 1)
                    .frame(width: 232, height: 232)

                Circle()
                    .fill(SujiTheme.sage.opacity(completed ? 0.12 : 0.16))
                    .overlay {
                        Circle()
                            .stroke(SujiTheme.sage.opacity(0.22), lineWidth: 0.75)
                    }
                    .frame(width: 184, height: 184)
                    .scaleEffect(focusScale)

                VStack(spacing: 8) {
                    Image(systemName: completed ? "checkmark" : phaseSymbol)
                        .font(.system(size: 18, weight: .medium))
                        .accessibilityHidden(true)
                    Text(phaseTitle)
                        .font(SujiTheme.serif(24, relativeTo: .title2))
                    Text(timeString(snapshot.remaining))
                        .font(.system(.title3, design: .rounded, weight: .regular))
                        .monospacedDigit()
                        .foregroundStyle(SujiTheme.secondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(phaseTitle)，剩余 \(timeString(snapshot.remaining))")

            Text(instruction)
                .font(.callout)
                .foregroundStyle(SujiTheme.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
    }

    private var controls: some View {
        VStack(spacing: 20) {
            durationPicker
            sessionButtons
        }
    }

    private var durationPicker: some View {
        Picker("静心时长", selection: $selectedMinutes) {
            Text("3 分钟").tag(3)
            Text("5 分钟").tag(5)
            Text("10 分钟").tag(10)
        }
        .pickerStyle(.segmented)
        .disabled(snapshot.state == .running || snapshot.state == .paused)
        .onChange(of: selectedMinutes) { _, minutes in
            clock = BreathingClock(duration: TimeInterval(minutes * 60))
            snapshot = clock.snapshot(at: uptime)
            completed = false
        }
    }

    @ViewBuilder
    private var sessionButtons: some View {
        HStack(spacing: 12) {
            if snapshot.state == .idle || snapshot.state == .finished {
                Button(action: startSession) {
                    Label(completed ? "再静一次" : "开始", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryCalmButtonStyle())
            } else {
                Button {
                    if snapshot.state == .paused { resumeSession() } else { pauseSession() }
                } label: {
                    Label(
                        snapshot.state == .paused ? "继续" : "暂停",
                        systemImage: snapshot.state == .paused ? "play.fill" : "pause.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryCalmButtonStyle())

                Button(action: endSession) {
                    Label("结束", systemImage: "stop.fill")
                        .labelStyle(.iconOnly)
                        .frame(width: 46, height: 46)
                }
                .buttonStyle(.plain)
                .background(SujiTheme.ink.opacity(0.07), in: Circle())
                .accessibilityLabel("结束静心")
            }
        }
    }

    private var soundMixer: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("合成音景")
                    .font(.headline)
                Spacer()
                Text("原创程序合成")
                    .font(.caption)
                    .foregroundStyle(SujiTheme.secondary)
            }

            HStack(spacing: 12) {
                Menu {
                    ForEach(SolarTermAmbiencePreset.all) { preset in
                        Button {
                            selectedPresetID = preset.id
                            audio.setVolumes(preset.volumes)
                        } label: {
                            if preset.id == selectedPresetID {
                                Label(preset.name, systemImage: "checkmark")
                            } else {
                                Text(preset.name)
                            }
                        }
                    }
                } label: {
                    Label(selectedPresetName, systemImage: "leaf")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(SujiQuietButtonStyle())

                Button {
                    if audio.isPlaying {
                        audio.stop()
                    } else {
                        applyStandaloneTimer()
                        audio.start()
                    }
                } label: {
                    Label(
                        audio.isPlaying ? "停止音景" : "播放音景",
                        systemImage: audio.isPlaying ? "stop.fill" : "play.fill"
                    )
                    .labelStyle(.iconOnly)
                    .frame(width: 46, height: 46)
                }
                .buttonStyle(.plain)
                .background(SujiTheme.ink.opacity(0.07), in: Circle())
                .accessibilityLabel(audio.isPlaying ? "停止音景" : "播放音景")
            }

            Text(selectedPresetNote)
                .font(.caption)
                .foregroundStyle(SujiTheme.secondary)

            Picker("独立计时", selection: $standaloneTimer) {
                ForEach(StandaloneAmbienceTimer.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: standaloneTimer) { _, _ in
                guard audio.isPlaying else { return }
                applyStandaloneTimer()
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), spacing: 10)], spacing: 10) {
                ForEach(AmbienceLayer.allCases) { layer in
                    let enabled = audio.volume(for: layer) > 0.001
                    Button {
                        audio.toggle(layer)
                    } label: {
                        Label(layer.title, systemImage: layer.symbol)
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity, minHeight: 42)
                            .foregroundStyle(enabled ? SujiTheme.paper : SujiTheme.secondary)
                            .background(enabled ? SujiTheme.sage : SujiTheme.ink.opacity(0.055), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(enabled ? "已开启" : "已关闭")
                }
            }

            VStack(spacing: 12) {
                ForEach(AmbienceLayer.allCases) { layer in
                    HStack(spacing: 12) {
                        Label(layer.title, systemImage: layer.symbol)
                            .font(.caption)
                            .frame(width: 70, alignment: .leading)
                        Slider(
                            value: Binding(
                                get: { Double(audio.volume(for: layer)) },
                                set: {
                                    selectedPresetID = "自定"
                                    audio.setVolume(Float($0), for: layer)
                                }
                            ),
                            in: 0 ... 1
                        )
                        .tint(SujiTheme.sage)
                        .accessibilityLabel("\(layer.title)音量")
                        Text("\(Int((audio.volume(for: layer) * 100).rounded()))")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(SujiTheme.secondary)
                            .frame(width: 24, alignment: .trailing)
                            .accessibilityHidden(true)
                    }
                }
            }

            HStack(spacing: 12) {
                Image(systemName: "speaker.fill")
                    .foregroundStyle(SujiTheme.secondary)
                    .accessibilityHidden(true)
                Slider(
                    value: Binding(
                        get: { Double(audio.masterVolume) },
                        set: { audio.setMasterVolume(Float($0)) }
                    ),
                    in: 0 ... 1
                )
                .tint(SujiTheme.sage)
                .accessibilityLabel("总音量")
                Image(systemName: "speaker.wave.3.fill")
                    .foregroundStyle(SujiTheme.secondary)
                    .accessibilityHidden(true)
            }

            if let error = audio.lastError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .accessibilityLabel(error)
            }
        }
        .padding(.top, 24)
        .overlay(alignment: .top) {
            Rectangle().fill(SujiTheme.line).frame(height: 1)
        }
    }

    private var selectedPresetName: String {
        SolarTermAmbiencePreset.named(selectedPresetID)?.name ?? "自定"
    }

    private var selectedPresetNote: String {
        SolarTermAmbiencePreset.named(selectedPresetID)?.note ?? "四种声音已分别调整"
    }

    private var phaseTitle: String {
        if completed { return "已完成" }
        switch snapshot.state {
        case .idle: return "准备"
        case .paused: return "暂歇"
        case .finished: return "已完成"
        case .running: return snapshot.phase == .inhale ? "吸气" : "呼气"
        }
    }

    private var phaseSymbol: String {
        switch snapshot.state {
        case .idle: "circle.dotted"
        case .paused: "pause"
        case .finished: "checkmark"
        case .running: snapshot.phase == .inhale ? "arrow.down" : "arrow.up"
        }
    }

    private var instruction: String {
        switch snapshot.state {
        case .idle: "自然坐好，不必刻意控制。准备好时，轻触开始。"
        case .paused: "停在这里也可以。呼吸不会催促你。"
        case .finished: "这一小段安静已经属于你。"
        case .running: snapshot.phase == .inhale ? "缓缓吸气，让肩膀保持松弛。" : "慢慢呼气，把注意力放回身体。"
        }
    }

    private var focusScale: CGFloat {
        guard !reduceMotion, snapshot.state == .running else { return 1 }
        if snapshot.phase == .inhale {
            return 0.82 + CGFloat(snapshot.phaseProgress) * 0.18
        }
        return 1 - CGFloat(snapshot.phaseProgress) * 0.18
    }

    private var uptime: TimeInterval { ProcessInfo.processInfo.systemUptime }

    private func startSession() {
        completed = false
        clock = BreathingClock(duration: TimeInterval(selectedMinutes * 60))
        clock.start(at: uptime)
        snapshot = clock.update(at: uptime)
        audio.setSleepTimer(seconds: TimeInterval(selectedMinutes * 60))
        audio.start()
        startTicking()
    }

    private func pauseSession() {
        let latest = clock.pause(at: uptime)
        snapshot = latest
        stopRendering()
        if latest.didFinish {
            completeSession()
            return
        }
        audio.pause()
    }

    private func resumeSession() {
        clock.resume(at: uptime)
        snapshot = clock.snapshot(at: uptime)
        audio.resume()
        startTicking()
    }

    private func endSession() {
        stopRendering()
        clock.reset()
        snapshot = clock.snapshot(at: uptime)
        completed = false
        audio.stop()
    }

    private func refreshClock() {
        guard snapshot.state == .running else { return }
        let latest = clock.update(at: uptime)
        snapshot = latest
        if latest.didFinish {
            completeSession()
        }
    }

    private func startTicking() {
        stopRendering()
        guard scenePhase == .active else { return }
        let interval = reduceMotion ? 1_000_000_000 : 33_000_000
        tickTask = Task { @MainActor in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: UInt64(interval))
                } catch {
                    return
                }
                refreshClock()
            }
        }
    }

    private func stopRendering() {
        tickTask?.cancel()
        tickTask = nil
    }

    private func completeSession() {
        stopRendering()
        completed = true
        audio.stop()
    }

    private func restoreView() {
        if !appliedInitialPreset {
            let preset = SolarTermAmbiencePreset.current()
            selectedPresetID = preset.id
            audio.setVolumes(preset.volumes)
            appliedInitialPreset = true
        }
        refreshClock()
        if snapshot.state == .running { startTicking() }
    }

    private func applyStandaloneTimer() {
        if let seconds = standaloneTimer.seconds {
            audio.setSleepTimer(seconds: seconds)
        } else {
            audio.cancelSleepTimer()
        }
    }

    private func timeString(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(ceil(seconds)))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

private struct PrimaryCalmButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var reduceMotion: Bool { SujiTheme.reduceMotion(systemReduceMotion) }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(SujiTheme.paper)
            .padding(.horizontal, 22)
            .frame(minHeight: 48)
            .background(SujiTheme.ink, in: Capsule())
            .opacity(configuration.isPressed ? 0.78 : 1)
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.985 : 1))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

private struct CalmViewPreview: PreviewProvider {
    static var previews: some View {
        CalmView()
    }
}
