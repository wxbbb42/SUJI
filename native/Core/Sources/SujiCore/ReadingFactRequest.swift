import Foundation

/// A bounded evidence acquisition fallback when the optional model planner
/// returns prose without even attempting a calculation. Uses existing tools and
/// their normal validation/persistence; never infers chart facts from old prose.
public enum ReadingFactRequest {
    /// These inputs do not identify a calculation target. A clarification is a
    /// question, not an unavailable chart; it still passes the normal verifier.
    public static func clarification(question: String, mode: String) -> String? {
        guard mode == "命理" else { return nil }
        let q = question.filter { !$0.isWhitespace }
        let vague = #"\A(?:(?:请|麻烦)?(?:帮我)?(?:看(?:一看|看)?|算(?:一算|算)?)(?:一下|看|算)?(?:呗|吧|好吗)?|(?:我)?最近(?:有点|不太|不)?顺(?:，|,)?(?:咋回事|怎么回事|怎么办)(?:啊|呀|呢)?)[？?。！!]*\z"#
        guard q.range(of: vague, options: .regularExpression) != nil else { return nil }
        return "你想先看整体命盘、事业财运，还是感情家庭？也可以说一件最近具体遇到的事，我再按这个方向查对应依据。"
    }

    public static func missingCalls(question: String, context: ToolContext, hasBirth: Bool,
                                    history: [ChatMessage], entries: [ConversationEntry], currentUserID: UUID) -> [ChatToolCall] {
        guard hasBirth, context.isValid, context.mode == "命理", !history.contains(where: { $0.role == .tool }) else { return [] }
        let q = question.filter { !$0.isWhitespace }
        func has(_ pattern: String) -> Bool { q.range(of: pattern, options: .regularExpression) != nil }
        // Ambiguous coordination, another person's chart and refusals stay with
        // the ordinary clarification path. Do not substitute a divination method.
        guard !has("不要|不用|不想|别算|不算|无需|不必|不需要|停止|六爻|奇门|奇門|起卦|朋友|对象的|孩子的|父母的|伴侣的") else { return [] }
        if has("什么是|是什么意思|区别|定义|含义"), !has("我的|我这|本命|本盘|四柱") { return [] }
        func call(_ name: String, _ arguments: JSONValue) -> ChatToolCall {
            .init(id: "facts-" + UUID().uuidString, name: name, arguments: arguments)
        }
        if has("^(那|所以)?(目前|现在|本次|这次)?(能看出什么|还能看出什么|哪些能确定|能确定什么|继续|再解释一下|展开说说|简单说说)(，哪些还不能确定)?[？?。！!]*$") {
            guard let current = entries.firstIndex(where: { $0.id == currentUserID }), current >= 2,
                  entries[current - 1].role == "assistant", entries[current - 2].role == "user",
                  let previous = entries[current - 2].toolContext,
                  previous.birthFingerprint == context.birthFingerprint, previous.engineRevision == context.engineRevision,
                  previous.mode == context.mode else { return [] }
            let stable: Set<String> = ["get_domain", "get_bazi_star", "get_ziwei_palace", "get_natal_astronomy"]
            var seen = Set<String>()
            return (entries[current - 2].toolReceipts ?? []).compactMap { receipt -> ChatToolCall? in
                guard receipt.context == previous, stable.contains(receipt.name),
                      case let .object(value) = ToolOutputWire.decode(receipt.output, name: receipt.name, callID: receipt.callID),
                      !value.isEmpty, value["error"] == nil else { return nil }
                let key = receipt.name + String(decoding: (try? JSONEncoder().encode(receipt.arguments)) ?? Data(), as: UTF8.self)
                guard seen.insert(key).inserted else { return nil }
                return call(receipt.name, receipt.arguments)
            }.prefix(3).map { $0 }
        }
        if let palace = ["命宫", "兄弟宫", "夫妻宫", "子女宫", "财帛宫", "疾厄宫", "迁移宫", "仆役宫", "官禄宫", "田宅宫", "福德宫", "父母宫"].first(where: { q.contains($0) }) {
            return [call("get_ziwei_palace", ["palace": .string(palace), "withSihua": true])]
        }
        if has("子女|孩子|怀孕|生育|备孕") {
            return [call("get_bazi_star", ["person": "子女"]), call("get_ziwei_palace", ["palace": "子女宫", "withSihua": true])]
        }
        if has("现在|目前|当前"), has("大运|换运|交运") { return [call("get_timing", ["scope": "current_dayun"])] }
        let domains = [("事业", "事业|工作|求职|面试|升职|创业|管理|技术"), ("财富", "财运|财星|正财|偏财|股票|投资|钱"), ("婚姻", "感情|婚姻|结婚|脱单|配偶|对象"), ("父母", "父母|爸爸|妈妈")]
        let selected = domains.filter { has($0.1) }
        if !selected.isEmpty { return selected.prefix(2).map { call("get_domain", ["domain": .string($0.0)]) } }
        if has("八字|四柱|日主|月令|性格|命盘") { return [call("get_domain", ["domain": "福德"])] }
        return []
    }
}
