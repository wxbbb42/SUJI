import Foundation

public enum BreathingClockState: String, Codable, Sendable {
    case idle
    case running
    case paused
    case finished
}

public enum BreathingPhase: String, Codable, Sendable {
    case inhale
    case exhale
}

public struct BreathingClockSnapshot: Equatable, Sendable {
    public let state: BreathingClockState
    public let elapsed: TimeInterval
    public let remaining: TimeInterval
    public let phase: BreathingPhase
    public let phaseProgress: Double
    /// True only for the update that crosses the session boundary.
    public let didFinish: Bool

    public var progress: Double {
        guard elapsed + remaining > 0 else { return 1 }
        return elapsed / (elapsed + remaining)
    }
}

/// A deterministic breathing-session clock driven by monotonic timestamps.
///
/// Production code should pass `ProcessInfo.processInfo.systemUptime`; tests may
/// provide arbitrary increasing values. No frame or timer count is accumulated,
/// so foreground scheduling delays cannot make a running session drift.
public struct BreathingClock: Sendable {
    public let duration: TimeInterval
    public let inhaleDuration: TimeInterval
    public let exhaleDuration: TimeInterval

    public private(set) var state: BreathingClockState = .idle

    private var accumulatedElapsed: TimeInterval = 0
    private var runStartedAt: TimeInterval?

    public init(
        duration: TimeInterval,
        inhaleDuration: TimeInterval = 4,
        exhaleDuration: TimeInterval = 6
    ) {
        precondition(duration > 0, "A breathing session must have a positive duration")
        precondition(inhaleDuration > 0 && exhaleDuration > 0, "Breathing phases must be positive")
        self.duration = duration
        self.inhaleDuration = inhaleDuration
        self.exhaleDuration = exhaleDuration
    }

    public mutating func start(at timestamp: TimeInterval) {
        accumulatedElapsed = 0
        runStartedAt = timestamp
        state = .running
    }

    @discardableResult
    public mutating func pause(at timestamp: TimeInterval) -> BreathingClockSnapshot {
        guard state == .running else { return snapshot(at: timestamp) }

        // Route through update so a scheduler stall that crosses the duration
        // boundary still emits the one-shot completion transition.
        let latest = update(at: timestamp)
        guard !latest.didFinish else { return latest }

        accumulatedElapsed = latest.elapsed
        runStartedAt = nil
        state = .paused
        return makeSnapshot(elapsed: accumulatedElapsed, didFinish: false)
    }

    public mutating func resume(at timestamp: TimeInterval) {
        guard state == .paused else { return }
        runStartedAt = timestamp
        state = .running
    }

    public mutating func reset() {
        accumulatedElapsed = 0
        runStartedAt = nil
        state = .idle
    }

    public func snapshot(at timestamp: TimeInterval) -> BreathingClockSnapshot {
        makeSnapshot(elapsed: elapsed(at: timestamp), didFinish: false)
    }

    @discardableResult
    public mutating func update(at timestamp: TimeInterval) -> BreathingClockSnapshot {
        let currentElapsed = elapsed(at: timestamp)
        let crossedBoundary = state == .running && currentElapsed >= duration

        if crossedBoundary {
            accumulatedElapsed = duration
            runStartedAt = nil
            state = .finished
        }

        return makeSnapshot(elapsed: currentElapsed, didFinish: crossedBoundary)
    }

    private func elapsed(at timestamp: TimeInterval) -> TimeInterval {
        guard state == .running, let runStartedAt else {
            return min(duration, accumulatedElapsed)
        }
        // Defensive max keeps a malformed decreasing timestamp from rewinding.
        return min(duration, accumulatedElapsed + max(0, timestamp - runStartedAt))
    }

    private func makeSnapshot(elapsed: TimeInterval, didFinish: Bool) -> BreathingClockSnapshot {
        let clampedElapsed = min(duration, max(0, elapsed))
        let cycleDuration = inhaleDuration + exhaleDuration
        let cyclePosition = clampedElapsed.truncatingRemainder(dividingBy: cycleDuration)
        let phase: BreathingPhase
        let phaseProgress: Double

        if cyclePosition < inhaleDuration {
            phase = .inhale
            phaseProgress = cyclePosition / inhaleDuration
        } else {
            phase = .exhale
            phaseProgress = (cyclePosition - inhaleDuration) / exhaleDuration
        }

        return BreathingClockSnapshot(
            state: state,
            elapsed: clampedElapsed,
            remaining: max(0, duration - clampedElapsed),
            phase: phase,
            phaseProgress: phaseProgress,
            didFinish: didFinish
        )
    }
}
