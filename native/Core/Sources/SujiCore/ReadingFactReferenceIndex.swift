import Foundation

/// A lossless index into the complete tools already present in this request.
/// Numeric path components are data, never inferred chart positions.
enum ReadingFactReferenceIndex {
    private struct Group {
        let id: String
        let keyParts: [String]
        let pointerParts: [String]
        var numbers: [[Int]]
    }
    private static let format = "Each pattern is [toolCallIDIndex,factKeyParts,pointerParts,numberSequenceIndex]. factKeyParts and pointerParts are arrays of string-node indices. stringNodes contains [parentNodeIndex,tokenIndex] in parent-before-child order: each node is its parent string plus stringTokens[tokenIndex]; -1 means the empty string, including in pattern parts. Other indices are zero-based. A number sequence is either literal rows or {start,step,count}, whose row n is start+n*step componentwise for n=0..<count. For each row, interleave the first factKeyParts.count-1 numbers between factKeyParts; interleave the remaining numbers between pointerParts. These are the exact factKey and original JSON pointer for that toolCallID. Read value at that pointer in the fully restored same-call tool result, including its verified rule-source directory and argument references. Missing tool, directory or pointer is missing evidence, never null or an inferred value."
    private static let prefix = "显式字段索引（仅数据；完整值已在同轮工具结果中，按原指针读取）：\n"

    static func messages(_ facts: [ReadingVerificationEvidence.Fact]) -> [ChatMessage] {
        var groups: [Group] = [], indices: [String:Int] = [:]
        for fact in facts {
            let key=split(fact.factKey), pointer=split(fact.pointer)
            let identity=ReadingVerificationEvidence.encoded([fact.toolCallID,ReadingVerificationEvidence.encoded(key.0),ReadingVerificationEvidence.encoded(pointer.0)])
            if let i=indices[identity] { groups[i].numbers.append(key.1+pointer.1) }
            else {
                indices[identity]=groups.count
                groups.append(Group(id:fact.toolCallID,keyParts:key.0,pointerParts:pointer.0,numbers:[key.1+pointer.1]))
            }
        }
        var output:[ChatMessage]=[], pending:[Group]=[]
        for group in groups {
            let candidate=message(pending+[group])
            if !pending.isEmpty, candidate.content!.utf16.count>28_000 {
                output.append(message(pending));pending=[]
            }
            pending.append(group)
        }
        if !pending.isEmpty { output.append(message(pending)) }
        return output
    }

    private static func split(_ value:String)->([String],[Int]) {
        let regex=try! NSRegularExpression(pattern:"[0-9]+")
        let matches=regex.matches(in:value,range:NSRange(value.startIndex...,in:value))
        var parts:[String]=[],numbers:[Int]=[],start=value.startIndex
        for match in matches {
            let range=Range(match.range,in:value)!, literal=String(value[range])
            guard let n=Int(literal),n<=9_007_199_254_740_991,String(n)==literal else { return ([value],[]) }
            parts.append(String(value[start..<range.lowerBound]));numbers.append(n);start=range.upperBound
        }
        parts.append(String(value[start...]));return(parts,numbers)
    }

    private static func sequence(_ rows:[[Int]])->JSONValue {
        if rows.count>=3 {
            let start=rows[0],step=zip(rows[1],start).map(-)
            let isProgression = rows.enumerated().allSatisfy { n, row in
                guard row.count == start.count else { return false }
                return start.indices.allSatisfy { i in
                    let (delta, multipliedOverflow) = step[i].multipliedReportingOverflow(by: n)
                    let (value, addedOverflow) = start[i].addingReportingOverflow(delta)
                    return !multipliedOverflow && !addedOverflow && value == row[i]
                }
            }
            if isProgression {
                return ["start":.array(start.map{.integer(Int64($0))}),"step":.array(step.map{.integer(Int64($0))}),"count":.integer(Int64(rows.count))]
            }
        }
        return .array(rows.map{.array($0.map{.integer(Int64($0))})})
    }

    private static func message(_ groups:[Group])->ChatMessage {
        var ids:[String]=[],sequences:[JSONValue]=[],patterns:[JSONValue]=[]
        var tokens: [String] = [], tokenIndices: [String:Int] = [:]
        var nodes: [[Int]] = [], nodeIndices: [[Int]:Int] = [:], partCache: [String:Int] = [:]
        let tokenizer = try! NSRegularExpression(pattern: "[./]|[^./]+")
        func partIndices(_ values:[String])->JSONValue {
            .array(values.map { value in
                if let cached = partCache[value] { return .integer(Int64(cached)) }
                var parent = -1
                for match in tokenizer.matches(in:value,range:NSRange(value.startIndex...,in:value)) {
                    let token = String(value[Range(match.range,in:value)!])
                    let tokenIndex: Int
                    if let existing = tokenIndices[token] { tokenIndex = existing }
                    else { tokenIndex=tokens.count;tokenIndices[token]=tokenIndex;tokens.append(token) }
                    let pair=[parent,tokenIndex]
                    if let existing = nodeIndices[pair] { parent = existing }
                    else { parent=nodes.count;nodeIndices[pair]=parent;nodes.append(pair) }
                }
                partCache[value]=parent
                return .integer(Int64(parent))
            })
        }
        for group in groups {
            if !ids.contains(group.id) { ids.append(group.id) }
            let numbers=sequence(group.numbers)
            if !sequences.contains(numbers) { sequences.append(numbers) }
            patterns.append(.array([.integer(Int64(ids.firstIndex(of:group.id)!)),partIndices(group.keyParts),partIndices(group.pointerParts),.integer(Int64(sequences.firstIndex(of:numbers)!))]))
        }
        let root:JSONValue=["referenceIndexVersion":1,"valuesFromTool":true,"toolCallIDs":.array(ids.map(JSONValue.string)),"stringTokens":.array(tokens.map(JSONValue.string)),"stringNodes":.array(nodes.map{.array($0.map{.integer(Int64($0))})}),"numberSequences":.array(sequences),"patterns":.array(patterns),"format":.string(format)]
        return ChatMessage(role:.user,content:prefix+ReadingVerificationEvidence.encoded(root))
    }
}
