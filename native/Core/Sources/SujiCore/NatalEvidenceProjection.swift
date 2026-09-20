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
        let supported: Set<String> = ["get_domain", "get_ziwei_palace"]
        guard supported.contains(name),
              let value = try? JSONDecoder().decode(JSONValue.self, from: Data(output.utf8)),
              case var .object(root) = value, root["error"] == nil, root["reusedFacts"] == nil else { return output }
        let calls = Dictionary(delivered.flatMap { $0.toolCalls ?? [] }.map { ($0.id,$0.name) }, uniquingKeysWith: { first,_ in first })
        let sources: [(String,JSONValue)] = delivered.compactMap { message in
            guard message.role == .tool, let id = message.toolCallID, let tool = calls[id], supported.contains(tool),
                  let raw = message.content, let decoded = try? JSONDecoder().decode(JSONValue.self,from:Data(raw.utf8)),
                  case let .object(object) = decoded, object["error"] == nil else { return nil }
            return (id,decoded)
        }
        let keys = ["pillars", "dayMaster", "tenGodRelationships", "pattern", "patternAnalysis", "strengthReference", "structureReference", "interpretationPolicy", "tiaoHou", "branchRelations", "stemRelations"]
        let palaceDetails: Set<String> = ["starDetails", "relatedPalaces", "natalTransformations"]
        let paths = (name == "get_domain" ? keys.map { ("bazi",$0) } + [("ziwei","ruleSources"), ("ziwei","method")] : ["ruleSources", "method", "starDetails", "relatedPalaces", "natalTransformations"].map { ("",$0) }) + [
            ("provenance","baziPolicy"), ("provenance","ziweiPolicy"), ("provenance","calendarPolicy"),
        ]
        var references: [JSONValue] = []
        for (parent, key) in paths {
            let path = parent.isEmpty ? "/\(key)" : "/\(parent)/\(key)"
            let group: [String:JSONValue]
            if parent.isEmpty { group = root }
            else if case let .object(object) = root[parent] { group = object }
            else { continue }
            guard let current = group[key] else { continue }
            let sourcePaths = parent.isEmpty ? [path,"/ziwei/\(key)"] : parent == "ziwei" ? [path,"/\(key)"] : [path]
            guard let source = sources.lazy.compactMap({ item -> (String,String)? in
                var candidates = sourcePaths
                // A detailed query may name a palace already delivered as a
                // trine/opposite. Reference that concrete named record only.
                if parent.isEmpty && ["starDetails", "natalTransformations"].contains(key) {
                    for base in ["", "/ziwei"] {
                        if case let .array(related) = ReadingVerificationEvidence.pointer(base+"/relatedPalaces",in:item.1) {
                            candidates += related.indices.map { base+"/relatedPalaces/\($0)/\(key)" }
                        }
                    }
                }
                guard let sourcePath = candidates.first(where: { candidate in
                    if parent.isEmpty && palaceDetails.contains(key) {
                        let identityPath = String(candidate.prefix(upTo:candidate.lastIndex(of:"/")!))+"/palace"
                        guard let ownPalace = root["palace"], ownPalace != .null,
                              ReadingVerificationEvidence.pointer(identityPath,in:item.1) == ownPalace else { return false }
                    }
                    return ReadingVerificationEvidence.pointer(candidate,in:item.1) == current
                }) else { return nil }
                return (item.0,sourcePath)
            }).first else { continue }
            let reference: JSONValue = .object(["path":.string(path),"toolCallID":.string(source.0),"pointer":.string(source.1)])
            // A small scalar can cost less than its reference; leave it inline.
            guard ReadingVerificationEvidence.encoded(current).utf8.count > ReadingVerificationEvidence.encoded(reference).utf8.count + 32 else { continue }
            if parent.isEmpty { root.removeValue(forKey:key) }
            else { var reduced = group; reduced.removeValue(forKey:key); root[parent] = .object(reduced) }
            references.append(reference)
        }
        guard !references.isEmpty else { return output }
        root["reusedFacts"] = .array(references)
        root["reusedFactsFormat"] = .string("Each missing path has the exact value at the earlier delivered toolCallID and pointer. Use that original tool result as evidence; these are references, not new calculations.")
        let compact = ReadingVerificationEvidence.encoded(JSONValue.object(root))
        return compact.utf8.count < output.utf8.count ? compact : output
    }
}
