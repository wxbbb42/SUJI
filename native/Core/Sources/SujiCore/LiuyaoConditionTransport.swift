import Foundation

/// Lossless self-contained layouts for repeated fields and condition IDs.
/// Used by wire transport and receipt storage; original pointers follow expansion.
enum LiuyaoConditionTransport {
    private static let key = "ruleConditionRows"
    private static let layoutKey = "liuyaoObjectRows"
    private static let rowKey = "$row"
    private static let layoutDescription = "Recursively replace each {\"$row\":[i,...values]} with Object.fromEntries(layouts[i].map((key,j)=>[key,values[j]])). Expand nested rows first; arrays retain order. Exclude root keys liuyaoObjectRows, ruleConditionRows, questionFromArguments; then expand ruleConditionRows. Use original JSON pointers after expansion."
    private static let columns: JSONValue = ["idIndex", "stateIndex", "factPathIndices"]
    private static let states: [JSONValue] = ["matched", "not-matched", "unresolved"]
    private static let description = "At /lines/*/rules/*/conditions expand each row by columns to {id:ids[idIndex],state:states[stateIndex],factPaths:factPathIndices.map(i=>paths[i])}. All indices are zero-based; follow original evidence pointers after expansion. Other fields are unchanged."
    private enum Invalid: Error { case record }

    /// Share repeated object field names, including calendar contexts and source
    /// records. Every value stays in this message; no chart fact is omitted.
    /// The condition dictionary and same-call question reference remain plain.
    static func encodeLayouts(_ raw: String) -> String {
        guard let value=try? JSONDecoder().decode(JSONValue.self,from:Data(raw.utf8)),
              case var .object(root)=value,!hasReservedLayoutKey(value) else { return raw }
        var counts:[[String]:Int]=[:],order:[[String]]=[]
        func collect(_ value:JSONValue) {
            switch value {
            case let .array(items): items.forEach(collect)
            case let .object(object):
                let keys=object.keys.sorted()
                if counts[keys] == nil { order.append(keys) }
                counts[keys,default:0] += 1
                keys.forEach { collect(object[$0]!) }
            default: break
            }
        }
        let payloadKeys=root.keys.filter { ![key,"questionFromArguments"].contains($0) }.sorted()
        payloadKeys.forEach { collect(root[$0]!) }
        // Conservative field-name savings estimate; the final full encoding
        // must also shrink in both backend accounting units.
        let layouts=order.filter { keys in
            let count=counts[keys]!,bytes=ReadingVerificationEvidence.encoded(keys).utf8.count
            return !keys.isEmpty && keys.allSatisfy({ !$0.isEmpty }) && count >= 2 && (count-1)*bytes > count*17+10
        }
        guard !layouts.isEmpty else { return raw }
        func pack(_ value:JSONValue) -> JSONValue {
            switch value {
            case let .array(items): return .array(items.map(pack))
            case let .object(object):
                let keys=object.keys.sorted()
                if let index=layouts.firstIndex(of:keys) {
                    return .object([rowKey:.array([.integer(Int64(index))]+keys.map { pack(object[$0]!) })])
                }
                return .object(object.mapValues(pack))
            default: return value
            }
        }
        payloadKeys.forEach { root[$0]=pack(root[$0]!) }
        root[layoutKey] = ["version":1,"layouts":.array(layouts.map { .array($0.map(JSONValue.string)) }),"format":.string(layoutDescription)]
        let packed=ReadingVerificationEvidence.encoded(JSONValue.object(root))
        return packed.utf16.count < raw.utf16.count && packed.utf8.count < raw.utf8.count ? packed : raw
    }

    private static func hasReservedLayoutKey(_ value:JSONValue) -> Bool {
        switch value {
        case let .array(items): return items.contains(where:hasReservedLayoutKey)
        case let .object(object):
            return object[rowKey] != nil || object[layoutKey] != nil || object.values.contains(where:hasReservedLayoutKey)
        default: return false
        }
    }

    private static func expandLayouts(_ value:JSONValue) -> JSONValue? {
        guard case var .object(root)=value else {
            if hasReservedLayoutKey(value) { return nil };return value
        }
        guard let metadata=root[layoutKey] else {
            if hasReservedLayoutKey(value) { return nil };return value
        }
        guard root[rowKey] == nil,case let .object(format)=metadata,
              Set(format.keys) == Set(["version","layouts","format"]),format["version"] == .integer(1),
              format["format"] == .string(layoutDescription),case let .array(rawLayouts)=format["layouts"],!rawLayouts.isEmpty else { return nil }
        var layouts:[[String]]=[]
        for layout in rawLayouts {
            guard case let .array(fields)=layout,!fields.isEmpty else { return nil }
            let keys=fields.compactMap { if case let .string(key)=$0,!key.isEmpty { return key };return nil }
            guard keys.count == fields.count,Set(keys).count == keys.count,keys == keys.sorted(),
                  !keys.contains(rowKey),!keys.contains(layoutKey),!layouts.contains(keys) else { return nil }
            layouts.append(keys)
        }
        var used=Array(repeating:0,count:layouts.count)
        func expand(_ value:JSONValue) throws -> JSONValue {
            switch value {
            case let .array(items): return .array(try items.map(expand))
            case let .object(object):
                guard object[layoutKey] == nil else { throw Invalid.record }
                if let marker=object[rowKey] {
                    guard object.count == 1,case let .array(row)=marker,
                          case let .integer(i)=row.first,i >= 0,i < layouts.count else { throw Invalid.record }
                    let index=Int(i),keys=layouts[index]
                    guard row.count == keys.count+1 else { throw Invalid.record }
                    used[index] += 1
                    return .object(Dictionary(uniqueKeysWithValues:try zip(keys,row.dropFirst()).map { ($0,try expand($1)) }))
                }
                // A declared layout cannot be partly packed: damaged rows must
                // not masquerade as unrelated legacy objects.
                guard !layouts.contains(object.keys.sorted()) else { throw Invalid.record }
                return .object(try object.mapValues(expand))
            default: return value
            }
        }
        do {
            for field in root.keys.sorted() where field != layoutKey {
                if [key,"questionFromArguments"].contains(field) {
                    guard !hasReservedLayoutKey(root[field]!) else { return nil }
                } else { root[field]=try expand(root[field]!) }
            }
        } catch { return nil }
        guard used.allSatisfy({ $0 >= 2 }) else { return nil }
        root.removeValue(forKey:layoutKey)
        return .object(root)
    }

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
        guard let value=expandLayouts(value) else { return nil }
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

/// Complete saved-chart representation. It reuses the self-contained wire
/// dictionaries without same-call question references; legacy raw JSON remains valid.
public enum CastReceiptStorage {
    private enum Invalid: Error { case record }
    public static func encode(_ raw:String) throws -> String {
        guard let value=try? JSONDecoder().decode(JSONValue.self,from:Data(raw.utf8)),case let .object(root)=value else { return raw }
        guard root["questionFromArguments"] == nil,root["ruleSourcesFromDirectory"] == nil,let shared=JSONValueTransport.expand(value),let layouts=LiuyaoConditionTransport.expand(shared),let expanded=QimenTimingTransport.expand(layouts) else { throw Invalid.record }
        // Do not rewrite a saved representation on retry.
        if root["sharedValueRows"] != nil || root["liuyaoObjectRows"] != nil || root["ruleConditionRows"] != nil || root["qimenTimingDateRows"] != nil { return raw }
        let packed=JSONValueTransport.encode(LiuyaoConditionTransport.encodeLayouts(LiuyaoConditionTransport.encode(QimenTimingTransport.encode(raw))))
        guard let decoded=try? JSONDecoder().decode(JSONValue.self,from:Data(packed.utf8)),let decodedShared=JSONValueTransport.expand(decoded),let decodedLayouts=LiuyaoConditionTransport.expand(decodedShared),QimenTimingTransport.expand(decodedLayouts)==expanded else { throw Invalid.record }
        return packed
    }
    public static func expanded(_ raw:String) throws -> JSONValue {
        let value=try JSONDecoder().decode(JSONValue.self,from:Data(raw.utf8))
        guard case let .object(root)=value,root["questionFromArguments"] == nil,root["ruleSourcesFromDirectory"] == nil,let shared=JSONValueTransport.expand(value),let layouts=LiuyaoConditionTransport.expand(shared),let expanded=QimenTimingTransport.expand(layouts) else { throw Invalid.record }
        return expanded
    }
    public static func expandedData(_ raw:String) throws -> Data { try JSONEncoder().encode(expanded(raw)) }
}

/// Compatibility name for the first consumer of the shared lossless storage.
public typealias LiuyaoReceiptStorage = CastReceiptStorage
