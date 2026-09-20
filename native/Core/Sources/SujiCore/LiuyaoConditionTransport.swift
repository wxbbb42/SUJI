import Foundation

/// A lossless wire layout for repeated condition keys/IDs, never a saved-chart
/// schema. Original JSON pointers are interpreted after expanding this layout.
enum LiuyaoConditionTransport {
    private static let key = "ruleConditionRows"
    private static let columns: JSONValue = ["idIndex", "stateIndex", "factPathIndices"]
    private static let states: [JSONValue] = ["matched", "not-matched", "unresolved"]
    private static let description = "At /lines/*/rules/*/conditions expand each row by columns to {id:ids[idIndex],state:states[stateIndex],factPaths:factPathIndices.map(i=>paths[i])}. All indices are zero-based; follow original evidence pointers after expansion. Other fields are unchanged."
    private enum Invalid: Error { case record }

    static func encode(_ raw: String) -> String {
        guard let value=try? JSONDecoder().decode(JSONValue.self,from:Data(raw.utf8)),
              case var .object(root)=value,root[key] == nil else { return raw }
        var ids:[String]=[],factPaths:[JSONValue]=[]
        guard let converted=try? transform(root) { row in
            guard case let .object(condition)=row,Set(condition.keys) == Set(["id","state","factPaths"]),
                  case let .string(id)=condition["id"],!id.isEmpty,
                  let state=condition["state"],let paths=condition["factPaths"],valid(state,paths) else { throw Invalid.record }
            let index:Int
            if let found=ids.firstIndex(of:id) { index=found }
            else { index=ids.count;ids.append(id) }
            guard case let .array(items)=paths else { throw Invalid.record }
            let pathIndices=items.map { path -> JSONValue in
                if let i=factPaths.firstIndex(of:path) { return .integer(Int64(i)) }
                factPaths.append(path);return .integer(Int64(factPaths.count-1))
            }
            return .array([.integer(Int64(index)),.integer(Int64(states.firstIndex(of:state)!)),.array(pathIndices)])
        },!ids.isEmpty else { return raw }
        root=converted
        root[key] = ["version":1,"columns":columns,"ids":.array(ids.map(JSONValue.string)),"states":.array(states),"paths":.array(factPaths),"format":.string(description)]
        let packed=ReadingVerificationEvidence.encoded(JSONValue.object(root))
        return packed.utf16.count < raw.utf16.count && packed.utf8.count < raw.utf8.count ? packed : raw
    }

    /// Reject the whole projected record on malformed metadata or rows, so a
    /// damaged condition cannot silently disappear from the verification index.
    static func expand(_ value: JSONValue) -> JSONValue? {
        guard case var .object(root)=value else { return value }
        guard let metadata=root[key] else {
            // Packed rows without their dictionary are not legacy objects.
            if case let .array(lines)=root["lines"] {
                for line in lines {
                    guard case let .object(rules)=ReadingVerificationEvidence.pointer("/rules",in:line) else { continue }
                    for rule in rules.values {
                        if case let .array(conditions)=ReadingVerificationEvidence.pointer("/conditions",in:rule),
                           conditions.contains(where:{ if case .array=$0 { return true };return false }) { return nil }
                    }
                }
            }
            return value
        }
        guard case let .object(format)=metadata,Set(format.keys) == Set(["version","columns","ids","states","paths","format"]),
              format["version"] == .integer(1),format["columns"] == columns,format["states"] == .array(states),format["format"] == .string(description),
              case let .array(values)=format["ids"],!values.isEmpty,
              case let .array(paths)=format["paths"],valid(states[0],.array(paths)) else { return nil }
        let pathNames=paths.compactMap { if case let .string(p)=$0 { return p };return nil }
        guard Set(pathNames).count == paths.count else { return nil }
        let ids=values.compactMap { v -> String? in if case let .string(id)=v,!id.isEmpty { return id };return nil }
        guard ids.count == values.count,Set(ids).count == ids.count else { return nil }
        var used=Set<Int>(),usedPaths=Set<Int>()
        guard let converted=try? transform(root) { row in
            guard case let .array(fields)=row,fields.count == 3,
                  case let .integer(rawIndex)=fields[0],rawIndex >= 0,rawIndex < ids.count,
                  case let .integer(stateIndex)=fields[1],stateIndex >= 0,stateIndex < states.count,
                  case let .array(pathIndices)=fields[2] else { throw Invalid.record }
            let restoredPaths=try pathIndices.map { item -> JSONValue in
                guard case let .integer(i)=item,i >= 0,i < paths.count else { throw Invalid.record }
                usedPaths.insert(Int(i));return paths[Int(i)]
            }
            let index=Int(rawIndex);used.insert(index)
            return .object(["id":.string(ids[index]),"state":states[Int(stateIndex)],"factPaths":.array(restoredPaths)])
        },used.count == ids.count,usedPaths.count == paths.count else { return nil }
        root=converted;root.removeValue(forKey:key)
        return .object(root)
    }

    private static func valid(_ state: JSONValue,_ paths: JSONValue) -> Bool {
        guard states.contains(state),
              case let .array(items)=paths else { return false }
        return items.allSatisfy { if case let .string(path)=$0 { return path.hasPrefix("/") };return false }
    }

    private static func transform(_ root:[String:JSONValue],row:(JSONValue)throws->JSONValue) throws -> [String:JSONValue] {
        guard case var .array(lines)=root["lines"],lines.count == 6 else { throw Invalid.record }
        var root=root
        for index in lines.indices {
            guard case var .object(line)=lines[index],case var .object(rules)=line["rules"] else { throw Invalid.record }
            // Sort keys so output and dictionary identities are stable on retry.
            for key in rules.keys.sorted() {
                guard case var .object(rule)=rules[key] else { throw Invalid.record }
                if let conditions=rule["conditions"] {
                    guard case let .array(items)=conditions else { throw Invalid.record }
                    rule["conditions"] = .array(try items.map(row));rules[key] = .object(rule)
                }
            }
            line["rules"] = .object(rules);lines[index] = .object(line)
        }
        root["lines"] = .array(lines);return root
    }
}
