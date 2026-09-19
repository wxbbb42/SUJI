import XCTest
@testable import SujiCore

final class BreathingClockTests: XCTestCase {
    func testPauseFreezesElapsedTimeAndPhase() {
        var clock = BreathingClock(duration: 180, inhaleDuration: 4, exhaleDuration: 6)

        clock.start(at: 10)
        _ = clock.update(at: 15)
        clock.pause(at: 15)

        let paused = clock.snapshot(at: 75)
        XCTAssertEqual(paused.state, .paused)
        XCTAssertEqual(paused.elapsed, 5, accuracy: 0.000_1)
        XCTAssertEqual(paused.remaining, 175, accuracy: 0.000_1)
        XCTAssertEqual(paused.phase, .exhale)
        XCTAssertEqual(paused.phaseProgress, 1.0 / 6.0, accuracy: 0.000_1)
    }

    func testResumeAdvancesFromSavedPosition() {
        var clock = BreathingClock(duration: 180, inhaleDuration: 4, exhaleDuration: 6)

        clock.start(at: 100)
        clock.pause(at: 107)
        clock.resume(at: 1_000)

        let resumed = clock.update(at: 1_003)
        XCTAssertEqual(resumed.state, .running)
        XCTAssertEqual(resumed.elapsed, 10, accuracy: 0.000_1)
        XCTAssertEqual(resumed.phase, .inhale)
        XCTAssertEqual(resumed.phaseProgress, 0, accuracy: 0.000_1)
    }

    func testDurationBoundaryFinishesExactlyOnce() {
        var clock = BreathingClock(duration: 10, inhaleDuration: 4, exhaleDuration: 6)
        clock.start(at: 20)

        let before = clock.update(at: 29.999)
        let boundary = clock.update(at: 30)
        let after = clock.update(at: 45)

        XCTAssertFalse(before.didFinish)
        XCTAssertTrue(boundary.didFinish)
        XCTAssertEqual(boundary.state, .finished)
        XCTAssertEqual(boundary.elapsed, 10, accuracy: 0.000_1)
        XCTAssertEqual(boundary.remaining, 0, accuracy: 0.000_1)
        XCTAssertFalse(after.didFinish)
        XCTAssertEqual(after.state, .finished)
    }

    func testClockUsesAbsoluteTimestampRatherThanTickCount() {
        var clock = BreathingClock(duration: 60, inhaleDuration: 4, exhaleDuration: 6)
        clock.start(at: 500)

        let afterBackgroundGap = clock.update(at: 537.5)

        XCTAssertEqual(afterBackgroundGap.elapsed, 37.5, accuracy: 0.000_1)
        XCTAssertEqual(afterBackgroundGap.remaining, 22.5, accuracy: 0.000_1)
        XCTAssertEqual(afterBackgroundGap.phase, .exhale)
        XCTAssertEqual(afterBackgroundGap.phaseProgress, 3.5 / 6.0, accuracy: 0.000_1)
    }

    func testPauseAtDurationEmitsCompletionExactlyOnce() {
        var clock = BreathingClock(duration: 10, inhaleDuration: 4, exhaleDuration: 6)
        clock.start(at: 0)

        let pauseTransition = clock.pause(at: 10)
        let laterUpdate = clock.update(at: 20)

        XCTAssertTrue(pauseTransition.didFinish)
        XCTAssertEqual(pauseTransition.state, .finished)
        XCTAssertEqual(pauseTransition.remaining, 0, accuracy: 0.000_1)
        XCTAssertFalse(laterUpdate.didFinish)
        XCTAssertEqual(laterUpdate.state, .finished)
    }
}
