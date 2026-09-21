import Foundation

public struct SSEEvent: Sendable, Equatable {
    public var event: String?
    public var id: String?
    public var data: String
    public var retry: Int?

    public init(event: String? = nil, id: String? = nil, data: String, retry: Int? = nil) {
        self.event = event
        self.id = id
        self.data = data
        self.retry = retry
    }
}

public enum SSEParserError: Error, Sendable, Equatable {
    case invalidUTF8
}

/// An incremental parser for the event-stream wire format.
///
/// It buffers bytes rather than partially decoded strings, so a UTF-8 scalar may
/// be split at any byte boundary without corrupting the event payload.
public struct SSEParser: Sendable {
    private var buffer = Data()
    private var eventName: String?
    private var eventID: String?
    private var dataLines: [String] = []
    private var retryMilliseconds: Int?
    private var isFinished = false
    private var isFirstLine = true

    public init() {}

    public mutating func feed(_ chunk: Data) throws -> [SSEEvent] {
        guard !isFinished else { return [] }
        buffer.append(chunk)
        return try consumeLines(flushing: false)
    }

    public mutating func finish() throws -> [SSEEvent] {
        guard !isFinished else { return [] }
        isFinished = true
        var events = try consumeLines(flushing: true)
        if let event = dispatchEvent() {
            events.append(event)
        }
        return events
    }

    private mutating func consumeLines(flushing: Bool) throws -> [SSEEvent] {
        var events: [SSEEvent] = []

        while !buffer.isEmpty {
            let bytes = [UInt8](buffer)
            guard let newlineIndex = bytes.firstIndex(where: { $0 == 0x0A || $0 == 0x0D }) else {
                if flushing {
                    try processLine(buffer, events: &events)
                    buffer.removeAll(keepingCapacity: false)
                }
                break
            }

            // A trailing CR might be the first half of CRLF in the next chunk.
            if bytes[newlineIndex] == 0x0D, newlineIndex + 1 == bytes.count, !flushing {
                break
            }

            let line = buffer.prefix(newlineIndex)
            var delimiterLength = 1
            if bytes[newlineIndex] == 0x0D,
               newlineIndex + 1 < bytes.count,
               bytes[newlineIndex + 1] == 0x0A {
                delimiterLength = 2
            }

            buffer.removeFirst(newlineIndex + delimiterLength)
            try processLine(Data(line), events: &events)
        }

        return events
    }

    private mutating func processLine(_ bytes: Data, events: inout [SSEEvent]) throws {
        guard var line = String(data: bytes, encoding: .utf8) else {
            throw SSEParserError.invalidUTF8
        }

        if isFirstLine {
            isFirstLine = false
            if line.first == "\u{FEFF}" {
                line.removeFirst()
            }
        }

        if line.isEmpty {
            if let event = dispatchEvent() {
                events.append(event)
            }
            return
        }

        guard !line.hasPrefix(":") else { return }

        let field: Substring
        var value: Substring
        if let colon = line.firstIndex(of: ":") {
            field = line[..<colon]
            value = line[line.index(after: colon)...]
            if value.first == " " { value = value.dropFirst() }
        } else {
            field = Substring(line)
            value = ""
        }

        switch field {
        case "event":
            eventName = String(value)
        case "data":
            dataLines.append(String(value))
        case "id":
            if !value.contains("\u{0000}") { eventID = String(value) }
        case "retry":
            if value.allSatisfy(\.isNumber) { retryMilliseconds = Int(value) }
        default:
            break
        }
    }

    private mutating func dispatchEvent() -> SSEEvent? {
        defer {
            eventName = nil
            eventID = nil
            dataLines.removeAll(keepingCapacity: true)
            retryMilliseconds = nil
        }
        guard !dataLines.isEmpty else { return nil }
        return SSEEvent(
            event: eventName,
            id: eventID,
            data: dataLines.joined(separator: "\n"),
            retry: retryMilliseconds
        )
    }
}
