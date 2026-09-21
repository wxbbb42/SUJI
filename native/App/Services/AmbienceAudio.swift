import AVFoundation
import Combine
import Foundation

enum AmbienceLayer: String, CaseIterable, Identifiable, Sendable {
    case rain
    case stream
    case wind
    case fire

    var id: Self { self }

    var title: String {
        switch self {
        case .rain: "细雨"
        case .stream: "溪流"
        case .wind: "松风"
        case .fire: "炉火"
        }
    }

    var symbol: String {
        switch self {
        case .rain: "cloud.rain"
        case .stream: "water.waves"
        case .wind: "wind"
        case .fire: "flame"
        }
    }
}

/// Procedural, original ambience built from noise, oscillators and envelopes.
/// No field recordings or downloaded audio assets are used.
@MainActor
final class AmbienceAudio: ObservableObject {
    static let shared = AmbienceAudio()

    @Published private(set) var isPlaying = false
    @Published private(set) var isInterrupted = false
    @Published private(set) var lastError: String?
    @Published private(set) var sleepTimerRemaining: TimeInterval?
    @Published private(set) var masterVolume: Float = 0.72

    private let engine = AVAudioEngine()
    private var layerMixers: [AmbienceLayer: AVAudioMixerNode] = [:]
    private var sources: [AmbienceLayer: AVAudioSourceNode] = [:]
    @Published private var layerVolumes: [AmbienceLayer: Float] = [
        .rain: 0.38,
        .stream: 0.22,
        .wind: 0.18,
        .fire: 0
    ]
    private var configured = false
    private var fadeTask: Task<Void, Never>?
    private var sleepTimerTask: Task<Void, Never>?
    private var sleepTimerDeadline: TimeInterval?
    private var notificationTokens: [NSObjectProtocol] = []
    private var wasPlayingBeforeInterruption = false

    init() {
        observeAudioSession()
    }

    func volume(for layer: AmbienceLayer) -> Float {
        layerVolumes[layer, default: 0]
    }

    func setVolume(_ volume: Float, for layer: AmbienceLayer) {
        let value = min(1, max(0, volume))
        layerVolumes[layer] = value
        layerMixers[layer]?.outputVolume = value
    }

    func toggle(_ layer: AmbienceLayer) {
        setVolume(volume(for: layer) > 0.001 ? 0 : defaultVolume(for: layer), for: layer)
    }

    func setVolumes(_ volumes: [AmbienceLayer: Float]) {
        for layer in AmbienceLayer.allCases {
            setVolume(volumes[layer, default: 0], for: layer)
        }
    }

    func setMasterVolume(_ volume: Float) {
        masterVolume = min(1, max(0, volume))
        if isPlaying { engine.mainMixerNode.outputVolume = masterVolume }
    }

    func start(fadeDuration: TimeInterval = 1.2) {
        do {
            try configureIfNeeded()
            try activateSession()
            fadeTask?.cancel()
            engine.mainMixerNode.outputVolume = 0
            if !engine.isRunning { try engine.start() }
            isPlaying = true
            isInterrupted = false
            lastError = nil
            fade(to: masterVolume, duration: fadeDuration)
            resumeSleepTimerIfNeeded()
        } catch {
            // Session activation may have succeeded before the engine failed to
            // start. Release it so other audio is not left disrupted.
            tearDownPlayback()
            lastError = "声音暂时无法播放：\(error.localizedDescription)"
        }
    }

    func pause(fadeDuration: TimeInterval = 0.35) {
        guard isPlaying else { return }
        preserveSleepTimerRemaining()
        isPlaying = false
        fade(to: 0, duration: fadeDuration) { [weak self] in
            guard let self else { return }
            self.engine.pause()
            self.engine.mainMixerNode.outputVolume = self.masterVolume
        }
    }

    func resume(fadeDuration: TimeInterval = 0.7) {
        guard !isPlaying else { return }
        start(fadeDuration: fadeDuration)
    }

    func stop(fadeDuration: TimeInterval = 0.8) {
        cancelSleepTimer()
        fadeTask?.cancel()
        isPlaying = false
        isInterrupted = false
        wasPlayingBeforeInterruption = false

        guard engine.isRunning, fadeDuration > 0 else {
            tearDownPlayback()
            return
        }
        fade(to: 0, duration: fadeDuration) { [weak self] in
            self?.tearDownPlayback()
        }
    }

    /// Stops playback after the requested duration. Pauses and system
    /// interruptions preserve the remaining time instead of restarting it.
    func setSleepTimer(seconds: TimeInterval) {
        cancelSleepTimer()
        guard seconds > 0 else { return }
        sleepTimerRemaining = seconds
        if isPlaying { resumeSleepTimerIfNeeded() }
    }

    func cancelSleepTimer() {
        sleepTimerTask?.cancel()
        sleepTimerTask = nil
        sleepTimerDeadline = nil
        sleepTimerRemaining = nil
    }

    func shutdown() {
        fadeTask?.cancel()
        cancelSleepTimer()
        tearDownPlayback()
    }

    deinit {
        for token in notificationTokens {
            NotificationCenter.default.removeObserver(token)
        }
    }

    private func defaultVolume(for layer: AmbienceLayer) -> Float {
        switch layer {
        case .rain: 0.38
        case .stream: 0.28
        case .wind: 0.20
        case .fire: 0.25
        }
    }

    private func configureIfNeeded() throws {
        guard !configured else { return }
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!

        for layer in AmbienceLayer.allCases {
            let synthesizer = AmbienceSynthesizer(layer: layer, sampleRate: format.sampleRate)
            let source = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList in
                let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
                for frame in 0 ..< Int(frameCount) {
                    let sample = synthesizer.nextSample()
                    for buffer in buffers {
                        guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                        data[frame] = sample
                    }
                }
                return noErr
            }
            let mixer = AVAudioMixerNode()
            mixer.outputVolume = layerVolumes[layer, default: 0]
            engine.attach(source)
            engine.attach(mixer)
            engine.connect(source, to: mixer, format: format)
            engine.connect(mixer, to: engine.mainMixerNode, format: format)
            sources[layer] = source
            layerMixers[layer] = mixer
        }

        engine.prepare()
        configured = true
    }

    private func activateSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try session.setActive(true)
    }

    /// Final teardown is intentionally independent of `engine.isRunning`.
    /// A paused or interrupted engine still owns its graph and active session.
    private func tearDownPlayback() {
        engine.stop()
        engine.reset()
        engine.mainMixerNode.outputVolume = masterVolume
        isPlaying = false
        isInterrupted = false
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
    }

    private func fade(to target: Float, duration: TimeInterval, completion: (() -> Void)? = nil) {
        fadeTask?.cancel()
        let initial = engine.mainMixerNode.outputVolume
        guard duration > 0 else {
            engine.mainMixerNode.outputVolume = target
            completion?()
            return
        }

        fadeTask = Task { @MainActor [weak self] in
            let frameCount = max(1, Int(duration * 30))
            for frame in 1 ... frameCount {
                guard let self, !Task.isCancelled else { return }
                let progress = Float(frame) / Float(frameCount)
                let eased = 1 - pow(1 - progress, 3)
                self.engine.mainMixerNode.outputVolume = initial + (target - initial) * eased
                try? await Task.sleep(for: .milliseconds(33))
            }
            guard !Task.isCancelled else { return }
            completion?()
        }
    }

    private func preserveSleepTimerRemaining() {
        if let deadline = sleepTimerDeadline {
            sleepTimerRemaining = max(0, deadline - ProcessInfo.processInfo.systemUptime)
        }
        sleepTimerTask?.cancel()
        sleepTimerTask = nil
        sleepTimerDeadline = nil
    }

    private func resumeSleepTimerIfNeeded() {
        guard let remaining = sleepTimerRemaining, remaining > 0 else { return }
        sleepTimerDeadline = ProcessInfo.processInfo.systemUptime + remaining
        sleepTimerTask?.cancel()
        sleepTimerTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(remaining))
            guard let self, !Task.isCancelled else { return }
            self.sleepTimerRemaining = nil
            self.sleepTimerDeadline = nil
            self.stop()
        }
    }

    private func observeAudioSession() {
        let center = NotificationCenter.default
        notificationTokens.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in self?.handleInterruption(notification) }
        })
        notificationTokens.append(center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in self?.handleRouteChange(notification) }
        })
    }

    private func handleInterruption(_ notification: Notification) {
        guard
            let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: rawType)
        else { return }

        switch type {
        case .began:
            wasPlayingBeforeInterruption = isPlaying
            isInterrupted = true
            preserveSleepTimerRemaining()
            fadeTask?.cancel()
            engine.pause()
            isPlaying = false
        case .ended:
            let rawOptions = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: rawOptions)
            isInterrupted = false
            if wasPlayingBeforeInterruption, options.contains(.shouldResume) {
                resume()
            }
            wasPlayingBeforeInterruption = false
        @unknown default:
            break
        }
    }

    private func handleRouteChange(_ notification: Notification) {
        guard
            let rawReason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
            AVAudioSession.RouteChangeReason(rawValue: rawReason) == .oldDeviceUnavailable
        else { return }
        // Match media-app convention: unplugging headphones pauses and requires
        // an intentional user resume, preventing private ambience from leaking.
        pause(fadeDuration: 0)
    }
}

/// Mutable DSP state is confined to AVAudioEngine's render thread after the
/// corresponding source node starts rendering.
private final class AmbienceSynthesizer: @unchecked Sendable {
    private let layer: AmbienceLayer
    private let sampleRate: Double
    private var randomState: UInt64
    private var lowPass: Float = 0
    private var phase: Double = 0
    private var secondPhase: Double = 0
    private var transient: Float = 0

    init(layer: AmbienceLayer, sampleRate: Double) {
        self.layer = layer
        self.sampleRate = sampleRate
        self.randomState = UInt64(layer.rawValue.utf8.reduce(5_381) { ($0 << 5) &+ $0 &+ UInt64($1) })
    }

    func nextSample() -> Float {
        let noise = randomSigned()
        switch layer {
        case .rain:
            lowPass += 0.16 * (noise - lowPass)
            if randomUnit() > 0.9993 { transient = 0.45 + randomUnit() * 0.35 }
            transient *= 0.986
            return (noise - lowPass) * 0.075 + transient * noise
        case .wind:
            lowPass += 0.0012 * (noise - lowPass)
            phase = wrap(phase + 0.09 / sampleRate)
            let gust = Float(0.48 + 0.34 * sin(phase * .pi * 2))
            return lowPass * gust * 0.62
        case .stream:
            lowPass += 0.045 * (noise - lowPass)
            phase = wrap(phase + 520 / sampleRate)
            secondPhase = wrap(secondPhase + 773 / sampleRate)
            let shimmer = Float(sin(phase * .pi * 2) + 0.45 * sin(secondPhase * .pi * 2))
            return lowPass * 0.19 + shimmer * noise * 0.025
        case .fire:
            lowPass += 0.008 * (noise - lowPass)
            if randomUnit() > 0.99965 { transient = 0.75 }
            transient *= 0.972
            return lowPass * 0.28 + transient * noise * 0.55
        }
    }

    private func randomUnit() -> Float {
        randomState ^= randomState << 13
        randomState ^= randomState >> 7
        randomState ^= randomState << 17
        return Float(randomState & 0x00FF_FFFF) / Float(0x0100_0000)
    }

    private func randomSigned() -> Float {
        randomUnit() * 2 - 1
    }

    private func wrap(_ value: Double) -> Double {
        value >= 1 ? value - floor(value) : value
    }
}
