import Foundation

/// Transport-only sharing of identical natal facts within one orchestration run.
/// Receipts stay complete. Every reference points to a delivered, concrete value;
/// references never point to another reference or an older conversation context.
enum NatalEvidenceProjection {
    static func wasDelivered(_ receipt: ToolReceipt, in history: [ChatMessage]) -> Bool {
        for (index,message) in history.enumerated() where message.role == .tool && message.toolCallID == receipt.callID {
            if message.content == receipt.output { return true }
            // Authenticate projected delivery against the full receipt and the
            // concrete earlier fields, rather than trusting only a call ID.
            if message.content == output(receipt.output,name:receipt.name,delivered:Array(history.prefix(index))) { return true }
        }
        return false
    }

    static func output(_ output: String, name: String, delivered: [ChatMessage]) -> String {
        guard name == "get_domain",
              let value = try? JSONDecoder().decode(JSONValue.self, from: Data(output.utf8)),
              case var .object(root) = value, root["error"] == nil, root["reusedFacts"] == nil else { return output }
        let calls = Dictionary(delivered.flatMap { $0.toolCalls ?? [] }.map { ($0.id,$0.name) }, uniquingKeysWith: { first,_ in first })
        let sources: [(String,JSONValue)] = delivered.compactMap { message in
            guard message.role == .tool, let id = message.toolCallID, calls[id] == name,
                  let raw = message.content, let decoded = try? JSONDecoder().decode(JSONValue.self,from:Data(raw.utf8)),
                  case let .object(object) = decoded, object["error"] == nil else { return nil }
            return (id,decoded)
        }
        let keys = ["pillars", "dayMaster", "tenGodRelationships", "pattern", "patternAnalysis", "strengthReference", "structureReference", "interpretationPolicy", "tiaoHou", "branchRelations", "stemRelations"]
        let paths = keys.map { ("bazi",$0) } + [
            ("ziwei","ruleSources"), ("ziwei","method"),
            ("provenance","baziPolicy"), ("provenance","ziweiPolicy"),
        ]
        var references: [JSONValue] = []
        for (parent, key) in paths {
            let path = "/\(parent)/\(key)"
            guard case var .object(group) = root[parent], let current = group[key],
                  let (id,_) = sources.first(where: { ReadingVerificationEvidence.pointer(path,in:$0.1) == current }) else { continue }
            let reference: JSONValue = .object(["path":.string(path),"toolCallID":.string(id),"pointer":.string(path)])
            // A small scalar can cost less than its reference; leave it inline.
            guard ReadingVerificationEvidence.encoded(current).utf8.count > ReadingVerificationEvidence.encoded(reference).utf8.count + 32 else { continue }
            group.removeValue(forKey:key)
            root[parent] = .object(group)
            references.append(reference)
        }
        guard !references.isEmpty else { return output }
        root["reusedFacts"] = .array(references)
        root["reusedFactsFormat"] = .string("Each missing path has the exact value at the earlier delivered toolCallID and pointer. Use that original tool result as evidence; these are references, not new calculations.")
        let compact = ReadingVerificationEvidence.encoded(JSONValue.object(root))
        return compact.utf8.count < output.utf8.count ? compact : output
    }
}
