import Foundation

/// Explains returned candidate relations bound to their columns; no strength verdict.
enum BaziPatternConditionTrace {
    static func make(root: JSONValue) -> (text: String, paths: [String])? {
        let base = "/bazi/patternAnalysis/conditionalEvidence"
        func value(_ path: String) -> JSONValue? { ReadingVerificationEvidence.pointer(path,in:root) }
        func string(_ path: String) -> String? { if case let .string(v) = value(path) { return v }; return nil }
        guard string(base + "/assessmentStatus") == "conditions-only", value(base + "/outcomeEstablished") == .bool(false),
              string(base + "/sources/0/id") == "ziping-helper-constraints-v1",
              string(base + "/sources/0/document") == "docs/mingli/source-texts/bazi/ziping-zhenquan/00-abstract-chapters.md",
              string(base + "/sources/0/sha256") == "5b930c11310899b50703696870d9024ba4e00fca6ad177e57d6fa5e3f8a4964f",
              string(base + "/sources/1/id") == "ziping-position-season-v1",
              string(base + "/sources/1/sha256") == "8ea626e3744bb7129351b57dd3c4d6b6be595484345d8ea8101df50611993596",
              case let .array(contexts) = value(base + "/stems"), contexts.count == 4,
              case let .array(candidates) = value(base + "/rescueCandidates") else { return nil }
        let columns = ["year","month","day","hour"],labels = ["年干","月干","日干","时干"]
        let stems = columns.compactMap { string("/bazi/pillars/" + $0 + "/ganZhi/gan") }
        guard stems.count == 4,stems.allSatisfy({ element($0) != nil }) else { return nil }
        var constraints: [[(actor:Int,relation:String)]] = []
        for i in 0..<4 {
            let p = base + "/stems/\(i)"
            guard value(p + "/position") == .integer(Int64(i)),string(p + "/gan") == stems[i],
                  string(p + "/combinationAdjudication") == "unresolved",
                  case let .array(rawConstraints) = value(p + "/constraints") else { return nil }
            var checked: [(actor:Int,relation:String)] = []
            for constraint in rawConstraints {
                guard case let .object(c) = constraint,case let .integer(rawActor) = c["actorPosition"],let actor = Int(exactly:rawActor),(0..<4).contains(actor),actor != i,
                      c["actorGan"] == .string(stems[actor]),case let .string(relation) = c["relation"],
                      ["克","合"].contains(relation),matches(relation,from:stems[actor],to:stems[i]),
                      c["adjacent"] == .bool(abs(actor-i) == 1),
                      c["interveningPositions"] == .array(((min(actor,i)+1)..<max(actor,i)).map { .integer(Int64($0)) }) else { return nil }
                checked.append((actor,relation))
            }
            constraints.append(checked)
        }
        var examples: [String] = [],paths = [base + "/assessmentStatus",base + "/outcomeEstablished",base + "/sources"]
        for (i,candidate) in candidates.enumerated() {
            guard case let .object(c) = candidate,case let .integer(rawTrigger) = c["triggerPosition"],case let .integer(rawRemedy) = c["remedyPosition"],
                  let trigger = Int(exactly:rawTrigger),let remedy = Int(exactly:rawRemedy),
                  (0..<4).contains(trigger),(0..<4).contains(remedy),trigger != remedy,trigger != 2,remedy != 2,
                  c["triggerContext"] == .string("/stems/\(trigger)"),c["remedyContext"] == .string("/stems/\(remedy)"),
                  c["effectiveness"] == .string("unresolved"),case let .string(relation) = c["relation"],
                  ["克","合","生"].contains(relation),
                  c["adjacent"] == .bool(abs(trigger-remedy) == 1),
                  c["interveningPositions"] == .array(((min(trigger,remedy)+1)..<max(trigger,remedy)).map { .integer(Int64($0)) }) else { return nil }
            let from = relation == "生" ? trigger : remedy, to = relation == "生" ? remedy : trigger
            guard c["fromPosition"] == .integer(Int64(from)),c["toPosition"] == .integer(Int64(to)),matches(relation,from:stems[from],to:stems[to]) else { return nil }
            // Validate all candidates; show at most two explicitly as examples.
            if examples.count < 2 {
                var example = labels[from] + stems[from] + relation + labels[to] + stems[to]
                if abs(from-to) > 1 { example += "（隔位）" }
                let other = constraints[remedy].filter { $0.actor != trigger }
                if !other.isEmpty { example += "，救应候选\(labels[remedy])\(stems[remedy])同时见" + other.map { labels[$0.actor] + stems[$0.actor] + $0.relation + stems[remedy] }.joined(separator:"、") }
                examples.append(example)
                paths += [base + "/rescueCandidates/\(i)",base + "/stems/\(remedy)/constraints",
                          "/bazi/pillars/\(columns[from])/ganZhi/gan","/bazi/pillars/\(columns[to])/ganZhi/gan"]
            }
        }
        if candidates.isEmpty { paths.append(base + "/rescueCandidates") }
        let text = examples.isEmpty ? "本次条件记录未列透干救应候选，不据此断言全局无救。"
            : "救应条件举例：" + examples.joined(separator:"；") + "。这些关系的效力未定，仍需连同根气、月令及其他配合审查，不能见合便说已经合去。"
        return (text,paths)
    }

    private static func element(_ stem:String) -> BaziFrameworkReading.Element? {
        ["甲":.wood,"乙":.wood,"丙":.fire,"丁":.fire,"戊":.earth,"己":.earth,"庚":.metal,"辛":.metal,"壬":.water,"癸":.water][stem]
    }
    private static func matches(_ relation:String,from:String,to:String) -> Bool {
        guard let a = element(from),let b = element(to) else { return false }
        if relation == "生" { return a.generates == b }
        if relation == "克" { return a.controls == b }
        return ["甲己","己甲","乙庚","庚乙","丙辛","辛丙","丁壬","壬丁","戊癸","癸戊"].contains(from+to)
    }
}
