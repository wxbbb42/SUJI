import Foundation

/// Deterministic fact acquisition for a small set of explicit, general today questions.
/// This selects the existing tool; the engine and ordinary writer retain their contracts.
public enum TodayReadingRequest {
    public static func applies(question: String, mode: String) -> Bool {
        guard mode == "命理" else { return false }
        let question = question.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.controlCharacters))
        // Ignore invisible input noise only at the edges; never join intent across controls.
        guard question.rangeOfCharacter(from: .controlCharacters) == nil else { return false }
        let chinese = question.filter { !$0.isWhitespace }
        let english = question.lowercased().components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }.joined(separator: " ")
        // Match the entire request. Extra subjects, time scopes, negations, quotes
        // and method instructions must remain with the ordinary planner.
        let chinesePattern = #"\A(?:请问[，,]?)?(?:(?:今天|今日)(?:我)?|我(?:今天|今日))(?:适合|应该|该|可以)(?:(?:做|干)(?:点)?什么|干嘛)(?:呢|呀|啊)?[？?！!。.]*\z"#
        let advicePattern = #"\A(?:请问[，,]?)?(?:今天|今日)(?:有什么建议|(?:需要|应该|该)注意什么|有什么需要注意的)(?:吗|呢)?[？?！!。.]*\z"#
        let englishPattern = #"\A(?:please[,]? )?(?:what (?:should|can) i do today|what should i focus on today|what is today good for|what (?:is|would be) good (?:for me )?to do today|(?:any )?(?:advice|suggestions) for today|how should i spend today)(?:,? please)?\s*[?!.]*\z"#
        return chinese.range(of: chinesePattern, options: .regularExpression) != nil
            || chinese.range(of: advicePattern, options: .regularExpression) != nil
            || english.range(of: englishPattern, options: .regularExpression) != nil
    }

    /// Callers replay matching cached receipts into the writer's history, as for
    /// BaziFrameworkReading. A stable attempt ID stops after either success or failure;
    /// a later explicit retry may supply a new ID and fetch again if no usable cache exists.
    public static func plan(callID: String, history: [ChatMessage], cachedReceipts: [ToolReceipt] = [], context: ToolContext, hasBirth: Bool) -> ChatCompletionResult {
        guard hasBirth, context.isValid, context.mode == "命理",
              !history.contains(where: { ($0.toolCalls ?? []).contains(where: { $0.id == callID }) || ($0.role == .tool && $0.toolCallID == callID) }),
              !cachedReceipts.contains(where: { reusable($0, context: context) }) else { return .text("") }
        return .toolCalls([ChatToolCall(id: callID, name: "get_today_context", arguments: [:])])
    }

    private static func reusable(_ receipt: ToolReceipt, context: ToolContext) -> Bool {
        guard receipt.name == "get_today_context", receipt.context == context,
              receipt.arguments == .object([:]), !receipt.callID.isEmpty,
              let decoded = ToolOutputWire.decode(receipt.output, name: receipt.name, callID: receipt.callID),
              case let .object(fields) = decoded, fields["error"] == nil else { return false }
        // Required returned facts only: no date conversion, pillar computation or
        // birth inference. Partial/failed receipts may be fetched on a fresh retry.
        return ["yearGanZhi", "monthGanZhi", "todayGanZhi", "solarTerm"].allSatisfy { key in
            guard case let .string(value) = fields[key] else { return false }
            return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}
