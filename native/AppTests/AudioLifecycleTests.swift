import AVFoundation
import XCTest
@testable import Suji

@MainActor final class AudioLifecycleTests: XCTestCase {
    func testAudioEngineInterruptionResumeAndHeadphoneDisconnect() async throws {
        let audio = AmbienceAudio()
        defer { audio.shutdown() }
        audio.setMasterVolume(0)
        audio.setSleepTimer(seconds: 180)
        audio.start(fadeDuration: 0)
        XCTAssertTrue(audio.isPlaying, audio.lastError ?? "Audio engine did not start")

        NotificationCenter.default.post(name: AVAudioSession.interruptionNotification, object: nil,
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue])
        await settle { audio.isInterrupted }
        XCTAssertFalse(audio.isPlaying)
        XCTAssertNotNil(audio.sleepTimerRemaining)

        NotificationCenter.default.post(name: AVAudioSession.interruptionNotification, object: nil,
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue,
                       AVAudioSessionInterruptionOptionKey: AVAudioSession.InterruptionOptions.shouldResume.rawValue])
        await settle { audio.isPlaying }
        XCTAssertFalse(audio.isInterrupted)

        NotificationCenter.default.post(name: AVAudioSession.routeChangeNotification, object: nil,
            userInfo: [AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue])
        await settle { !audio.isPlaying }
        XCTAssertNotNil(audio.sleepTimerRemaining)
        audio.stop(fadeDuration: 0)
        XCTAssertFalse(audio.isPlaying)
        XCTAssertNil(audio.sleepTimerRemaining)
    }

    private func settle(_ condition: () -> Bool) async {
        for _ in 0..<100 {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertTrue(condition())
    }
}
