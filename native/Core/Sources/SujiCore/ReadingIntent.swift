import Foundation

public enum ReadingIntent {
    public static func definitions(from data: Data, mode: String, question: String, hasBirth: Bool) throws -> [ChatToolDefinition] {
        struct Definition: Decodable {
            struct Function: Decodable { let name: String; let description: String; let parameters: JSONValue }
            let function: Function
        }
        let qimenRequested = allowsQimen(question)
        // A named, single-method request has the same capability set in both
        // tabs. Otherwise having a natal profile accidentally selects free-form
        // multi-system writing instead of the existing checked Qimen renderer.
        let singleQimen = qimenRequested && !["八字", "四柱", "紫微", "紫薇", "六爻", "七政", "星宿", "占星"].contains(where: question.contains)
        return try JSONDecoder().decode([Definition].self, from: data).compactMap { item in
            let f = item.function
            guard ToolOrchestrator.allowedToolNames.contains(f.name) else { return nil }
            let allowed: Bool
            if f.name == "setup_qimen" { allowed = qimenRequested }
            else if singleQimen { allowed = false }
            else if mode == "起卦" { allowed = f.name == "cast_liuyao" && (!qimenRequested || requestsMethod(question, method: "六爻", other: "奇门")) }
            else { allowed = hasBirth && f.name != "cast_liuyao" }
            return allowed ? ChatToolDefinition(name: f.name, description: f.description, parameters: f.parameters) : nil
        }
    }

    /// Conservative capability gate; merely discussing or rejecting a method does not authorize a chart.
    public static func allowsQimen(_ question: String) -> Bool {
        requestsMethod(question, method: "奇门", other: "六爻")
    }

    static func normalizedMethods(_ question: String) -> String {
        question.replacingOccurrences(of:"奇門",with:"奇门").replacingOccurrences(of:"與",with:"与").replacingOccurrences(of:"術",with:"术")
    }

    private static func requestsMethod(_ question: String, method: String, other: String) -> Bool {
        let text = normalizedMethods(question).filter { !$0.isWhitespace }
        let negated = "(不要|不用|不想|禁止|不做|不许|无需|勿|拒绝|避免|不需要|别)[^，,。；;！？\\n]{0,16}(" + method + "|起卦|起盘|排盘|起局)"
        guard text.range(of: negated, options: .regularExpression) == nil else { return false }
        let discussion = "(?:什么是|介绍|解释|讲解|学习)(?:用)?" + method + "(?:起局|排盘|起盘)?|" + method + "(?:起局|排盘|起盘)?[”’\\\"]?(?:是什么|是什么意思|的含义|怎么|如何)|" + method + "[^，,。；;！？]{0,12}(?:区别|含义)"
        guard text.range(of: discussion, options: .regularExpression) == nil else { return false }
        let requested = "(使用|用|按|通过|以)(?:" + other + "(?:和|与|及|、|以及))?" + method + "|" + method + "[^，,。；;！？]{0,8}(起局|排盘|起盘|分析|推演|算一下|看一下)"
        return text.range(of: requested, options: .regularExpression) != nil
    }
}
