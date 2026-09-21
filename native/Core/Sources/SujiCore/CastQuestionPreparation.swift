import Foundation

/// Proposed inputs are editable, never evidence of user confirmation by themselves.
public struct CastQuestionDraft: Identifiable, Sendable, Equatable {
    public let proposedCall: ChatToolCall
    public var id: String { proposedCall.id }
    public var methodName: String { proposedCall.name == "cast_liuyao" ? "六爻" : "奇门" }
    public var question: String
    public var questionType: String
    public var subject: String
    public var event: String
    public var timeHorizon: String
    public var referenceOnly = false
    public var timingEnabled = false
    public var timingFocus = ""
    public var timingUnit = ""
    public var timingEndDate = ""
    public var timingIncludeCurrent = false

    public static let subjects = ["unknown", "self", "parent", "child", "sibling", "wife", "husband", "other"]
    public static let questionTypes = ["general", "career", "wealth", "marriage", "kids", "parents", "health", "event"]
    public static let timeHorizons = ["unspecified", "near", "far"]

    public init(call: ChatToolCall, restoringConfirmedTiming: Bool = false) throws {
        guard ["cast_liuyao", "setup_qimen"].contains(call.name), case let .object(args) = call.arguments else {
            throw CastQuestionValidationError(reason: "无法确认这次起盘资料")
        }
        func string(_ key: String, fallback: String) -> String {
            if case let .string(value) = args[key] { return value }; return fallback
        }
        proposedCall = call
        question = string("question", fallback: "")
        questionType = string("questionType", fallback: "general")
        subject = string("subject", fallback: "unknown")
        event = string("event", fallback: "")
        timeHorizon = string("timeHorizon", fallback: "unspecified")
        if call.name == "setup_qimen", case let .object(timing) = args["timingRequest"] {
            // Proposed fields may be displayed, but the user must enable timing.
            // Only persisted confirmations restore the enabled state for validation.
            timingEnabled = restoringConfirmedTiming
            if case let .string(v)=timing["focus"] { timingFocus=v }
            if case let .string(v)=timing["timeUnit"] { timingUnit=v }
            if case let .object(window)=timing["window"] {
                if case let .bool(v)=window["includeCurrent"] { timingIncludeCurrent=v }
                if case let .string(v)=window["end"],let d=Self.isoDate(v) { timingEndDate=Self.dayFormatter.string(from:d) }
            }
        }
    }

    public var validationMessage: String? {
        do { _ = try validatedCall(); return nil } catch { return error.localizedDescription }
    }

    public func validatedCall() throws -> ChatToolCall {
        let question = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let event = event.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...1600).contains(question.unicodeScalars.count) else { throw CastQuestionValidationError(reason: "请填写 1–1600 字的具体问题") }
        guard event.unicodeScalars.count <= 200 else { throw CastQuestionValidationError(reason: "请将事项缩短到 200 字以内") }
        guard referenceOnly || !event.isEmpty else { throw CastQuestionValidationError(reason: "请补充具体事项，或选择仅核对盘面") }
        guard Self.subjects.contains(subject), Self.questionTypes.contains(questionType), Self.timeHorizons.contains(timeHorizon) else {
            throw CastQuestionValidationError(reason: "请重新选择对象、类别和时间范围")
        }
        var args: [String: JSONValue] = ["question": .string(question), "questionType": .string(questionType), "subject": .string(subject), "timeHorizon": .string(timeHorizon)]
        if !event.isEmpty { args["event"] = .string(event) }
        if proposedCall.name == "setup_qimen", timingEnabled, !referenceOnly {
            guard ["employment","profit","relationship","self"].contains(timingFocus),
                  ["year","month","day","hour"].contains(timingUnit) else {
                throw CastQuestionValidationError(reason:"请明确选择应期对象和年、月、日或时辰单位")
            }
            guard timingFocus != "self" || subject == "self" else { throw CastQuestionValidationError(reason:"以本人为应期对象时，请将所问对象明确为我自己") }
            let f=Self.dayFormatter
            guard timingEndDate.range(of:#"^\d{4}-\d{2}-\d{2}$"#,options:.regularExpression) != nil,
                  let day=f.date(from:timingEndDate),f.string(from:day)==timingEndDate,
                  let year=Int(timingEndDate.prefix(4)),(1901...2100).contains(year) else {
                throw CastQuestionValidationError(reason:"请按 YYYY-MM-DD 填写1901–2100年的有效截止日期")
            }
            // End of the explicitly selected Beijing date, at millisecond precision.
            let end=day.addingTimeInterval(86400-0.001),iso=ISO8601DateFormatter()
            iso.formatOptions=[.withInternetDateTime,.withFractionalSeconds]
            args["timingRequest"]=["focus":.string(timingFocus),"event":.string(event),"timeUnit":.string(timingUnit),
                "window":["end":.string(iso.string(from:end)),"includeCurrent":.bool(timingIncludeCurrent)]]
        }
        // The legacy gender field must never supply a missing subject.
        return ChatToolCall(id: proposedCall.id, name: proposedCall.name, arguments: .object(args))
    }

    private static var dayFormatter: DateFormatter {
        let f=DateFormatter();f.locale=Locale(identifier:"en_US_POSIX");f.calendar=Calendar(identifier:.gregorian)
        f.timeZone=TimeZone(secondsFromGMT:8*3600);f.dateFormat="yyyy-MM-dd";f.isLenient=false;return f
    }
    fileprivate static func isoDate(_ value:String)->Date? {
        let f=ISO8601DateFormatter();f.formatOptions=[.withInternetDateTime,.withFractionalSeconds]
        return f.date(from:value) ?? ISO8601DateFormatter().date(from:value)
    }
}

/// Stored on the source user entry before the engine is invoked. The original
/// question time in context is deliberately independent of confirmedAt.
public struct ConfirmedCastQuestion: Codable, Sendable, Equatable {
    public let userID: UUID
    public let context: ToolContext
    public let confirmedAt: Date
    public let proposedCall: ChatToolCall
    public let call: ChatToolCall
    public let referenceOnly: Bool

    public init(draft: CastQuestionDraft, userID: UUID, context: ToolContext, confirmedAt: Date = Date()) throws {
        self.call = try draft.validatedCall()
        self.proposedCall = draft.proposedCall
        self.userID = userID
        self.context = context
        self.confirmedAt = confirmedAt
        self.referenceOnly = draft.referenceOnly
        try validate(userID: userID, context: context)
    }

    /// User intent, not calculation evidence. Replay keeps corrected inputs and
    /// the explicit reference-only scope visible even if the planner calls no tool.
    public var intentMessage: ChatMessage {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let arguments = (try? encoder.encode(call.arguments)).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
        let method = call.name == "cast_liuyao" ? "六爻" : "奇门"
        let scope = referenceOnly ? "仅核对盘面，不判断事情成败或日期" : "围绕确认的事项核对依据；未知条件仍待澄清"
        return ChatMessage(role: .user, content: "用户已核对\(method)占问资料，以下修订优先于原问题中的对应资料。范围：\(scope)。这不是新的计算结果，也不表示已经定用。已确认资料：\n\(arguments)")
    }

    public func validate(userID: UUID, context: ToolContext) throws {
        guard self.userID == userID, self.context == context, context.isValid,
              confirmedAt.timeIntervalSince1970.isFinite,
              proposedCall.id == call.id, proposedCall.name == call.name else { throw ToolOrchestratorError.staleContext }
        var draft = try CastQuestionDraft(call: call, restoringConfirmedTiming: true)
        draft.referenceOnly = referenceOnly
        guard try draft.validatedCall() == call else { throw CastQuestionValidationError(reason: "已确认的占问资料不完整，请发起新提问") }
        if case let .string(end)=ReadingVerificationEvidence.pointer("/timingRequest/window/end",in:call.arguments) {
            guard let date=CastQuestionDraft.isoDate(end),date>context.referenceDate else {
                throw CastQuestionValidationError(reason:"应期截止日期必须晚于这次原起盘时刻")
            }
        }
    }
}

private struct CastQuestionValidationError: LocalizedError {
    let reason: String
    var errorDescription: String? { reason }
}
