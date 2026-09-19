import Foundation
import XCTest
@testable import SujiCore

final class BridgeLifecycleTests: XCTestCase {
    func testInitializationRejectsBundleWithoutRunExport() throws {
        let script = try makeScript("var SomethingElse = {};")

        XCTAssertThrowsError(try MingliBridge(scriptURL: script)) { error in
            XCTAssertEqual(
                error as? EngineError,
                .invalidBundle("本地引擎没有导出 SujiNative.run。")
            )
        }
    }

    func testCancellationResumesPromptlyAndLateResolveCannotCompleteNextRequest() async throws {
        let script = try makeScript(
            """
            var delayedResolve;
            var SujiNative = {
              run: function(json, resolve, reject) {
                var command = JSON.parse(json).command;
                if (command === "hold") {
                  delayedResolve = resolve;
                  return;
                }
                if (command === "release") {
                  delayedResolve(JSON.stringify({ value: "late" }));
                  resolve(JSON.stringify({ value: "next" }));
                  return;
                }
                reject("unexpected command");
              }
            };
            """
        )
        let bridge = try MingliBridge(scriptURL: script, requestTimeout: 2)
        let held = Task {
            try await bridge.request(#"{"command":"hold"}"#)
        }

        try await Task.sleep(for: .milliseconds(50))
        let cancellationStart = ContinuousClock.now
        held.cancel()
        do {
            _ = try await held.value
            XCTFail("A cancelled bridge request must throw")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
        XCTAssertLessThan(cancellationStart.duration(to: .now), .milliseconds(500))

        let next = try await bridge.request(#"{"command":"release"}"#)
        XCTAssertEqual(String(decoding: next, as: UTF8.self), #"{"value":"next"}"#)
    }

    func testRequestsRemainSerializedUntilPromiseCallbackCompletes() async throws {
        let script = try makeScript(
            """
            var active = false;
            var SujiNative = {
              run: function(json, resolve, reject) {
                if (active) {
                  reject("overlapping request");
                  return;
                }
                active = true;
                Promise.resolve()
                  .then(function() { return Promise.resolve(); })
                  .then(function() {
                    active = false;
                    resolve(json);
                  });
              }
            };
            """
        )
        let bridge = try MingliBridge(scriptURL: script, requestTimeout: 2)

        async let first = bridge.request(#"{"request":1}"#)
        async let second = bridge.request(#"{"request":2}"#)
        let outputs = try await [first, second].map { String(decoding: $0, as: UTF8.self) }

        XCTAssertEqual(Set(outputs), [#"{"request":1}"#, #"{"request":2}"#])
    }

    func testTimedOutPromiseReleasesFollowingRequest() async throws {
        let script = try makeScript(
            """
            var SujiNative = {
              run: function(json, resolve, reject) {
                var command = JSON.parse(json).command;
                if (command === "hang") return;
                resolve(JSON.stringify({ value: "recovered" }));
              }
            };
            """
        )
        let bridge = try MingliBridge(scriptURL: script, requestTimeout: 0.05)
        let hung = Task { try await bridge.request(#"{"command":"hang"}"#) }
        let queued = Task { try await bridge.request(#"{"command":"next"}"#) }

        do {
            _ = try await hung.value
            XCTFail("A hung bridge request must time out")
        } catch {
            guard case .timedOut = error as? EngineError else {
                return XCTFail("Expected EngineError.timedOut, got \(error)")
            }
        }

        let recovered = try await queued.value
        XCTAssertEqual(String(decoding: recovered, as: UTF8.self), #"{"value":"recovered"}"#)
    }

    private func makeScript(_ source: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("suji-bridge-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("bridge.js")
        try Data(source.utf8).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return url
    }
}
