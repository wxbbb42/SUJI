import Foundation

/// Transport-only sharing of identical natal facts and echoed cast questions within one orchestration run.
/// Receipts stay complete. Every reference points to a delivered, concrete value;
/// references never point to another reference or an older conversation context.
enum NatalEvidenceProjection {
    static func wasDelivered(_ receipt: ToolReceipt, in history: [ChatMessage]) -> Bool {
        for (index,message) in history.enumerated() where message.role == .tool && message.toolCallID == receipt.callID {
            if message.content == receipt.output { return true }
            // Authenticate projected delivery against the full receipt and the
            // concrete earlier fields, rather than trusting only a call ID.
            if message.content == output(receipt.output,name:receipt.name,delivered:Array(history.prefix(index)),callID:receipt.callID) { return true }
        }
        return false
    }

    static func output(_ output: String, name: String, delivered: [ChatMessage], callID: String? = nil) -> String {
        if ["cast_liuyao", "setup_qimen"].contains(name) {
            return castQuestion(output, name:name, delivered:delivered, callID:callID)
        }
        let supported: Set<String> = ["get_domain", "get_ziwei_palace", "get_ziwei_timing"]
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
        var paths = name == "get_domain" ? keys.map { "/bazi/"+$0 } : []
        if name == "get_ziwei_timing" { paths.append("/natalYear") }
        else {
            let base = name == "get_domain" ? "/ziwei" : ""
            paths += ["ruleSources", "method", "starDetails", "relatedPalaces", "natalTransformations"].map { base+"/"+$0 }
            if case let .array(related) = ReadingVerificationEvidence.pointer(base+"/relatedPalaces",in:value) {
                for index in related.indices {
                    paths += ["starDetails", "natalTransformations"].map { base+"/relatedPalaces/\(index)/"+$0 }
                }
            }
        }
        let sourceBase = name == "get_domain" ? "/ziwei/ruleSources" : "/ruleSources"
        if case let .array(rules) = ReadingVerificationEvidence.pointer(sourceBase,in:value) {
            for index in rules.indices {
                paths += ["references", "limitations"].map { sourceBase+"/\(index)/"+$0 }
            }
        }
        paths += ["baziPolicy", "ziweiPolicy", "calendarPolicy"].map { "/provenance/"+$0 }
        var references: [JSONValue] = []
        for path in paths {
            guard let current = ReadingVerificationEvidence.pointer(path,in:.object(root)),
                  let key = path.split(separator:"/").last.map(String.init) else { continue }
            let parentPath = String(path.prefix(upTo:path.lastIndex(of:"/")!))
            let sourceField = path.hasPrefix(sourceBase+"/") && ["references", "limitations"].contains(key)
            let identityPath = parentPath+"/palace"
            let ownPalace = ReadingVerificationEvidence.pointer(identityPath,in:value)
            guard let source = sources.lazy.compactMap({ item -> (String,String)? in
                var candidates = [path]
                if sourceField {
                    // Retain the source's array index so the existing fact keys
                    // remain identical as well as the source ID and version.
                    candidates += [path.hasPrefix("/ziwei/") ? String(path.dropFirst(6)) : "/ziwei"+path]
                } else if !path.hasPrefix("/bazi/") && !path.hasPrefix("/provenance/") {
                    candidates += ["/"+key, "/ziwei/"+key]
                    if ["starDetails", "natalTransformations"].contains(key) {
                        for base in ["", "/ziwei"] {
                            if case let .array(related) = ReadingVerificationEvidence.pointer(base+"/relatedPalaces",in:item.1) {
                                candidates += related.indices.map { base+"/relatedPalaces/\($0)/"+key }
                            }
                        }
                    }
                }
                guard let sourcePath = candidates.first(where: { candidate in
                    if sourceField {
                        let otherParent = String(candidate.prefix(upTo:candidate.lastIndex(of:"/")!))
                        for field in ["id", "version"] {
                            guard case let .string(identity) = ReadingVerificationEvidence.pointer(parentPath+"/"+field,in:value),
                                  ReadingVerificationEvidence.pointer(otherParent+"/"+field,in:item.1) == .string(identity) else { return false }
                        }
                    }
                    if palaceDetails.contains(key) {
                        let sourceIdentityPath = String(candidate.prefix(upTo:candidate.lastIndex(of:"/")!))+"/palace"
                        guard let ownPalace, ownPalace != .null,
                              ReadingVerificationEvidence.pointer(sourceIdentityPath,in:item.1) == ownPalace else { return false }
                    }
                    return ReadingVerificationEvidence.pointer(candidate,in:item.1) == current
                }) else { return nil }
                return (item.0,sourcePath)
            }).first else { continue }
            let reference: JSONValue = .object(["path":.string(path),"toolCallID":.string(source.0),"pointer":.string(source.1)])
            // A small scalar can cost less than its reference; leave it inline.
            guard ReadingVerificationEvidence.encoded(current).utf8.count > ReadingVerificationEvidence.encoded(reference).utf8.count + 32 else { continue }
            guard case let .object(reduced) = removing(Array(path.split(separator:"/").map(String.init))[...],from:.object(root)) else { continue }
            root = reduced
            references.append(reference)
        }
        guard !references.isEmpty else { return output }
        root["reusedFacts"] = .array(references)
        root["reusedFactsFormat"] = .string("Each missing path has the exact value at the earlier delivered toolCallID and pointer. Use that original tool result as evidence; these are references, not new calculations.")
        let compact = ReadingVerificationEvidence.encoded(JSONValue.object(root))
        return compact.utf8.count < output.utf8.count ? compact : output
    }

    /// Long questions are already present verbatim in the same call's arguments.
    /// Share only that exact string; chart facts and persisted receipts stay full.
    private static func castQuestion(_ output:String, name:String, delivered:[ChatMessage], callID:String?) -> String {
        guard let value=try? JSONDecoder().decode(JSONValue.self,from:Data(output.utf8)),
              case var .object(root)=value,root["error"] == nil,root["questionFromArguments"] == nil,
              case let .string(question)=root["question"],question.utf8.count > 600 else { return output }
        let matches=delivered.flatMap { $0.toolCalls ?? [] }.filter {
            $0.name == name && (callID == nil || $0.id == callID) &&
            ReadingVerificationEvidence.pointer("/question",in:$0.arguments) == .string(question)
        }
        guard matches.count == 1,let call=matches.first else { return output }
        root.removeValue(forKey:"question")
        root["questionFromArguments"]=["toolCallID":.string(call.id),"pointer":"/question"]
        return ReadingVerificationEvidence.encoded(JSONValue.object(root))
    }

    /// Remove only a selected field; retain array order and surrounding palace
    /// identity so a reference cannot relocate a star to an adjacent record.
    private static func removing(_ path:ArraySlice<String>,from value:JSONValue) -> JSONValue {
        guard let first = path.first else { return value }
        switch value {
        case var .object(object):
            if path.count == 1 { object.removeValue(forKey:first) }
            else if let child = object[first] { object[first] = removing(path.dropFirst(),from:child) }
            return .object(object)
        case var .array(array):
            guard let index = Int(first), array.indices.contains(index), path.count > 1 else { return value }
            array[index] = removing(path.dropFirst(),from:array[index])
            return .array(array)
        default: return value
        }
    }
}
