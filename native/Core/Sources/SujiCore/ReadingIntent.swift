import Foundation

public enum ReadingIntent {
    public static func definitions(from data: Data, mode: String, question: String, hasBirth: Bool) throws -> [ChatToolDefinition] {
        struct Definition: Decodable {
            struct Function: Decodable { let name: String; let description: String; let parameters: JSONValue }
            let function: Function
        }
        return try JSONDecoder().decode([Definition].self, from: data).compactMap { item in
            let f = item.function
            guard ToolOrchestrator.allowedToolNames.contains(f.name) else { return nil }
            let allowed: Bool
            if mode == "起卦" { allowed = f.name == "cast_liuyao" }
            else if f.name == "setup_qimen" { allowed = allowsQimen(question) }
            else { allowed = hasBirth && f.name != "cast_liuyao" }
            return allowed ? ChatToolDefinition(name: f.name, description: f.description, parameters: f.parameters) : nil
        }
    }

    /// Conservative capability gate; merely discussing or rejecting a method does not authorize a chart.
    public static func allowsQimen(_ question: String) -> Bool {
        let text = question.filter { !$0.isWhitespace }
        let negated = #"(不要|不用|不想|禁止|不做|不许|无需|勿|拒绝|避免|不需要|别).{0,16}(奇门|起卦|起盘|排盘|起局)"#
        guard text.range(of: negated, options: .regularExpression) == nil else { return false }
        let requested = #"(使用|用|按|通过|以)奇门|奇门.{0,8}(起局|排盘|起盘|分析|推演|算一下|看一下)"#
        return text.range(of: requested, options: .regularExpression) != nil
    }
}
