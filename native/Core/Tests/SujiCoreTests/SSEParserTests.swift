import XCTest
@testable import SujiCore

final class SSEParserTests: XCTestCase {
    func testSplitEventEmitsOnlyWhenComplete() throws {
        var parser = SSEParser()

        XCTAssertEqual(try parser.feed(Data("data: {\"value\":".utf8)), [])
        XCTAssertEqual(
            try parser.feed(Data("1}\n\n".utf8)),
            [SSEEvent(data: "{\"value\":1}")]
        )
    }

    func testParsesCRLFAndMultipleEvents() throws {
        var parser = SSEParser()
        let input = "id: first\r\nevent: update\r\ndata: one\r\n\r\ndata: two\r\n\r\n"

        XCTAssertEqual(
            try parser.feed(Data(input.utf8)),
            [
                SSEEvent(event: "update", id: "first", data: "one"),
                SSEEvent(data: "two"),
            ]
        )
    }

    func testJoinsMultipleDataLinesAndReadsRetry() throws {
        var parser = SSEParser()

        XCTAssertEqual(
            try parser.feed(Data("retry: 1500\ndata: first\ndata: second\n\n".utf8)),
            [SSEEvent(data: "first\nsecond", retry: 1_500)]
        )
    }

    func testSplitUnicodeScalarIsDecodedAfterAllBytesArrive() throws {
        var parser = SSEParser()
        let bytes = Array("data: 春风\n\n".utf8)
        let split = bytes.firstIndex(of: 0xE9)! + 2

        XCTAssertEqual(try parser.feed(Data(bytes[..<split])), [])
        XCTAssertEqual(
            try parser.feed(Data(bytes[split...])),
            [SSEEvent(data: "春风")]
        )
    }

    func testFinishDispatchesFinalUnterminatedEvent() throws {
        var parser = SSEParser()

        XCTAssertEqual(try parser.feed(Data("event: response.completed\ndata: {}".utf8)), [])
        XCTAssertEqual(
            try parser.finish(),
            [SSEEvent(event: "response.completed", data: "{}")]
        )
        XCTAssertEqual(try parser.finish(), [])
    }

    func testRecognizesDoneAndErrorTerminalEventsWithoutDiscardingThem() throws {
        var parser = SSEParser()
        let input = "data: [DONE]\n\nevent: error\ndata: {\"message\":\"bad\"}\n\n"

        XCTAssertEqual(
            try parser.feed(Data(input.utf8)),
            [
                SSEEvent(data: "[DONE]"),
                SSEEvent(event: "error", data: "{\"message\":\"bad\"}"),
            ]
        )
    }

    func testCommentsAndUnknownFieldsDoNotCreateEvents() throws {
        var parser = SSEParser()

        XCTAssertEqual(
            try parser.feed(Data(": heartbeat\nunknown: value\n\n".utf8)),
            []
        )
    }

    func testInvalidUTF8ThrowsRatherThanDroppingPayload() throws {
        var parser = SSEParser()

        XCTAssertThrowsError(try parser.feed(Data([0x64, 0x61, 0x74, 0x61, 0x3A, 0x20, 0xFF, 0x0A, 0x0A]))) {
            XCTAssertEqual($0 as? SSEParserError, .invalidUTF8)
        }
    }
}
