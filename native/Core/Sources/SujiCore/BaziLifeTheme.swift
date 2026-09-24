import Foundation
import CryptoKit

/// A bundled, conditional reading, not a personality assessment or an authenticated archive.
/// The app must reconstruct the report under its current account/birth/engine identity before reuse.
public struct BaziLifeTheme: Codable, Equatable, Sendable, Identifiable {
    public enum Branch: String, Codable, Sendable { case bothExposed, mixedLayers, hiddenPair, missingPair }
    public struct Evidence: Codable, Equatable, Sendable, Identifiable {
        public let id, dossierPointer, toolPointer, value: String
    }
    public struct Source: Codable, Equatable, Sendable, Identifiable {
        public let id, path, sha256, locator, quote, scope: String
    }
    public var id: String { "\(snapshotID):\(themeID):\(contentVersion)" }
    public let themeID, contentVersion, ruleVersion, snapshotID: String
    public let branch: Branch
    public let hasExposedResource: Bool
    public let title, summary, explanation, boundary, observation, exercise, example, followUpPrompt: String
    public let evidence: [Evidence]
    public let sourceIDs: [String]
}

public enum BaziLifeThemeCompiler {
    public static let themeID = "bazi.expression-and-rules"
    public static let title = "表达与规则：遇到要求怎样提不同意见"
    public static let contentVersion = "bazi-life-theme-copy-2026-09-23-v2"
    public static let ruleVersion = "bazi-life-theme-conditions-2026-09-23-v1"
    private static let foundations = "docs/mingli/source-texts/bazi/ziping-zhenquan/01-foundations.md"
    private static let shangguan = "docs/mingli/source-texts/bazi/ziping-zhenquan/38-shanguan.md"
    private static let foundationsHash = "8ea626e3744bb7129351b57dd3c4d6b6be595484345d8ea8101df50611993596"
    private static let shangguanHash = "93f35811d1cc1b31a10ac297778d98185e134138699c811986a06a4d4e4bd093"
    public static let sources: [BaziLifeTheme.Source] = [
        .init(id: "ziping-theme-composition-v1", path: foundations, sha256: foundationsHash, locator: "《子平真诠评注》电子转录·论阴阳生克", quote: "五行宜忌，全在配合，四时之宜忌，又各不同。", scope: "支持先看配合与季节条件；不支持从出现次数推强弱、吉凶或人格。电子转录未校印本，原文与徐注不作统一归属。"),
        .init(id: "ziping-theme-stem-hidden-v1", path: foundations, sha256: foundationsHash, locator: "《子平真诠评注》电子转录·论十干合而不合", quote: "地支所藏之干，本静以待用，透出干头，则显其用矣。", scope: "区分透干与藏干；不把透藏等同外向/内向，也不认定藏而不透没有作用。"),
        .init(id: "ziping-theme-shangguan-scope-v1", path: shangguan, sha256: shangguanHash, locator: "《子平真诠评注》电子转录·论伤官", quote: "在查其气候，量其强弱，审其喜忌，观其纯杂，微之又微，不可执也。", scope: "限定伤官的解释须结合全盘；当前未裁定整体强弱、纯杂与喜忌，不引申为才华或反叛人格。"),
        .init(id: "ziping-theme-seal-conditions-v1", path: shangguan, sha256: shangguanHash, locator: "《子平真诠评注》电子转录·论伤官", quote: "有伤官佩印者，印能制伤，所以为贵，反要伤官旺，身稍弱，始为秀气。", scope: "说明见印与伤官不足以认定佩印成立；本主题只读实际克向，不裁定作用胜负、救应或现实能力。")
    ]

    /// Accepts only the current local compiler format. This validates structure, not account authority.
    /// Do not call this with report-like data assembled from model prose or an imported document.
    public static func compile(report: NatalReadingReport) throws -> BaziLifeTheme {
        guard report.system == .bazi, report.contentVersion == NatalReadingCompiler.contentVersion,
              report.adapterVersion == NatalReadingCompiler.adapterVersion,
              validDigest(report.snapshotID) else { throw EngineContract.Failure.invalid }
        var values: [String: String] = [:]
        for field in report.entries.flatMap(\.evidence) {
            if let previous = values[field.pointer], previous != field.value { throw EngineContract.Failure.invalid }
            values[field.pointer] = field.value
        }
        let paths = NatalReadingCatalog.pillarKeys.map { "/mingPan/siZhu/\($0)" }
            + ["/mingPan/riZhu/gan", "/mingPan/riZhu/wuXing", "/mingPan/riZhu/yinYang"]
        let evidence: [BaziLifeTheme.Evidence] = try paths.map { pointer in
            guard let value = values[pointer], value.utf8.count <= 8_000 else { throw EngineContract.Failure.invalid }
            let tool = pointer.replacingOccurrences(of: "/mingPan/siZhu", with: "/bazi/pillars")
                .replacingOccurrences(of: "/mingPan/riZhu", with: "/bazi/dayMaster")
            return .init(id: digest(report.snapshotID + "\n" + pointer + "\n" + value), dossierPointer: pointer, toolPointer: tool, value: value)
        }
        return try make(snapshotID: report.snapshotID, evidence: evidence)
    }

    /// Codable permits storage, not trust. Rebuilding against the current trusted report is mandatory.
    public static func validate(_ theme: BaziLifeTheme, against report: NatalReadingReport) throws {
        guard theme == (try compile(report: report)) else { throw EngineContract.Failure.invalid }
    }

    /// Checks a real get_domain projection after the app has validated the theme against a fresh report.
    /// This never synthesizes a receipt or promotes a stored hash into execution provenance.
    public static func validateProjection(theme: BaziLifeTheme, receipt: ToolReceipt, context: ToolContext) throws {
        guard context.isValid, context.mode == "命理", receipt.context == context,
              receipt.name == "get_domain", receipt.arguments == ["domain": "事业"],
              !receipt.callID.isEmpty, receipt.callID.utf8.count <= 200,
              receipt.output.utf8.count <= 200_000,
              theme == (try make(snapshotID: theme.snapshotID, evidence: theme.evidence)),
              let root = try JSONSerialization.jsonObject(with: Data(receipt.output.utf8)) as? [String: Any],
              root["error"] == nil, root["domain"] as? String == "事业",
              let bazi = root["bazi"] as? [String: Any], bazi["error"] == nil else { throw EngineContract.Failure.invalid }
        let projection = try NatalReadingEvidence(Data(receipt.output.utf8))
        for field in theme.evidence {
            let actual = try projection.value(field.toolPointer)
            if field.dossierPointer.hasPrefix("/mingPan/siZhu/") {
                let expected = try JSONSerialization.jsonObject(with: Data(field.value.utf8))
                guard try canonical(actual) == canonical(expected) else { throw EngineContract.Failure.invalid }
            } else {
                guard let value = actual as? String, value == field.value else { throw EngineContract.Failure.invalid }
            }
        }
    }

    private struct Occurrence {
        let stem, element, relation, label, pointer: String
        let exposed: Bool
    }
    private static func make(snapshotID: String, evidence: [BaziLifeTheme.Evidence]) throws -> BaziLifeTheme {
        guard validDigest(snapshotID), evidence.count == 7,
              Set(evidence.map(\.dossierPointer)).count == 7 else { throw EngineContract.Failure.invalid }
        let fields = Dictionary(uniqueKeysWithValues: evidence.map { ($0.dossierPointer, $0) })
        for field in evidence {
            let tool = field.dossierPointer.replacingOccurrences(of: "/mingPan/siZhu", with: "/bazi/pillars").replacingOccurrences(of: "/mingPan/riZhu", with: "/bazi/dayMaster")
            guard field.id == digest(snapshotID + "\n" + field.dossierPointer + "\n" + field.value), field.toolPointer == tool,
                  field.value.utf8.count <= 8_000 else { throw EngineContract.Failure.invalid }
        }
        guard let day = fields["/mingPan/riZhu/gan"]?.value, let d = NatalReadingInput.stems.firstIndex(of: day),
              fields["/mingPan/riZhu/wuXing"]?.value == NatalReadingInput.elements[d/2],
              fields["/mingPan/riZhu/yinYang"]?.value == (d%2 == 0 ? "阳" : "阴") else { throw EngineContract.Failure.invalid }
        var occurrences: [Occurrence] = []
        for (index, key) in NatalReadingCatalog.pillarKeys.enumerated() {
            let base = "/mingPan/siZhu/\(key)", label = NatalReadingCatalog.pillarLabels[index]
            guard let raw = fields[base]?.value else { throw EngineContract.Failure.invalid }
            let p = try JSONDecoder().decode(NatalReadingInput.Pillar.self, from: Data(raw.utf8))
            guard let stem = NatalReadingInput.stems.firstIndex(of: p.ganZhi.gan),
                  let branch = NatalReadingInput.branches.firstIndex(of: p.ganZhi.zhi), stem%2 == branch%2,
                  p.ganZhi.ganWuXing == NatalReadingInput.elements[stem/2],
                  p.ganZhi.ganYinYang == (stem%2 == 0 ? "阳" : "阴"),
                  p.shiShen == (try NatalReadingInput.relation(day: day, target: p.ganZhi.gan)),
                  let hidden = NatalReadingInput.hidden[p.ganZhi.zhi], p.cangGan.count == hidden.count,
                  index != 2 || p.ganZhi.gan == day else { throw EngineContract.Failure.invalid }
            if index != 2 { occurrences.append(.init(stem: p.ganZhi.gan, element: p.ganZhi.ganWuXing, relation: p.shiShen, label: "\(label)干\(p.ganZhi.gan)", pointer: base + "/shiShen", exposed: true)) }
            for (j, h) in p.cangGan.enumerated() {
                guard let hIndex = NatalReadingInput.stems.firstIndex(of: h.gan), h.gan == hidden[j].0,
                      h.weight == hidden[j].1, h.wuXing == NatalReadingInput.elements[hIndex/2],
                      h.shiShen == (try NatalReadingInput.relation(day: day, target: h.gan)) else { throw EngineContract.Failure.invalid }
                occurrences.append(.init(stem: h.gan, element: h.wuXing, relation: h.shiShen, label: "\(label)支\(p.ganZhi.zhi)藏\(h.gan)", pointer: base + "/cangGan/\(j)/shiShen", exposed: false))
            }
        }
        let output = occurrences.filter { $0.relation == "伤官" }, authority = occurrences.filter { $0.relation == "正官" }
        let exposedOutput = output.filter(\.exposed), exposedAuthority = authority.filter(\.exposed)
        let resources = occurrences.filter { ["正印", "偏印"].contains($0.relation) && $0.exposed }
        let branch: BaziLifeTheme.Branch = output.isEmpty || authority.isEmpty ? .missingPair
            : !exposedOutput.isEmpty && !exposedAuthority.isEmpty ? .bothExposed
            : !exposedOutput.isEmpty || !exposedAuthority.isEmpty ? .mixedLayers : .hiddenPair
        func positions(_ items: [Occurrence]) -> String { items.map(\.label).joined(separator: "、") }
        let summary: String, explanation: String, observation: String
        switch branch {
        case .bothExposed:
            summary = "\(positions(exposedOutput))为伤官，\(positions(exposedAuthority))为正官，二者都在天干层。可以从这组并见结构，观察你如何处理意见与要求。"
            explanation = "这页把‘表达与规则’作为现代观察比喻，不把十神当人格标签。相对日干\(day)，伤官和正官是两种不同生克角色；此盘两者同透，按五行方向确有伤官克正官的关系。但‘有克向’与‘官被伤坏’之间，还隔着月令取用、强弱、位置及其他关系，当前主题没有完成这些裁定。因而值得展开的是：不要只拿其中一个名称解释整张盘，也不要先认定你一定与要求冲突。"
            observation = "回想最近一次你接受要求、另一次你提出异议的具体事情。各写出对方要达成的目标、你掌握的事实，以及你是否有不同方案。两次差异是否来自这些现实条件？如果‘意见与要求的拉扯’不符合你的经历，就跳过这个观察；这不会改变已保存的出生资料。"
        case .mixedLayers:
            let visible = !exposedOutput.isEmpty ? "伤官在\(positions(exposedOutput))透出，正官只见于\(positions(authority))" : "正官在\(positions(exposedAuthority))透出，伤官只见于\(positions(output))"
            summary = visible + "。两者分属透干与藏干层，不能写成伤官与正官同透。"
            explanation = "这组资料提供的重点是‘先分层，再谈组合’。\(visible)。传统文本区分支藏与透干，因此不能把它们当成两干同透；即使同透，也仍须结合其他条件解释作用。透的一方不是你在外的样子，藏的一方也不是你心里真实的想法。\n\n下方区分‘明确要求’与‘自己推测’的练习，是任何人都可选用的沟通方法，与透干、藏干没有对应关系。是否需要这个练习，只看你正在遇到的问题，不由这份盘面的层次决定。"
            observation = "选一件最近觉得受要求限制的事，分别记下对方说过的原话和你自己的推测，再找一件可以顺畅商量的反例。若没有这类困扰，写‘不符合我的经历’即可；不能因为一方藏在地支就推断你只是尚未察觉。"
        case .hiddenPair:
            summary = "伤官见于\(positions(output))，正官见于\(positions(authority))；这两种关系都没有在年、月、时干透出。"
            explanation = "本盘的伤官与正官都来自支藏层，不能据此写成两者在天干直接相争。藏干关系仍应记录，但它们如何参与全盘作用，需要额外条件，当前主题不作胜负判断。这个分支也不代表你的表达欲被隐藏，或你看似随和而内心冲突。如果仍想讨论‘如何提出不同意见’，我们应从一件你实际遇到的事开始；盘面只提供本页为什么不采用同透解读的依据。"
            observation = "先判断这个话题是否与你近期处境有关：有没有一项你愿意接受、另一项希望重新商量的要求？如果不符合，就不必强做比较。有具体情境时，再分别记录目标、事实与可协商之处，不把尚未说出的意见归因于藏干。"
        case .missingPair:
            let absent = output.isEmpty && authority.isEmpty ? "伤官与正官" : output.isEmpty ? "伤官" : "正官"
            summary = "在年、月、时干及四支藏干的核对范围内，未见\(absent)；当前不具备本主题要解释的两方组合。"
            explanation = "这份盘面不支持‘伤官与正官共同作用’这一主题读法，因此不为你生成表达与规则冲突的命理结论。未见某个十神只是所选字段的分布，不能反推你缺少表达能力、没有原则，或不会受到要求困扰。若你确实遇到难以开口的事情，仍可以用下面的通用练习整理处境；它的价值来自真实问题，而非这一组合已经在盘中成立。"
            observation = "如果你正有想商量的要求，可以写下一件具体事，再试试下面的通用练习。如果这不符合你的经历，就跳过；这不会改变已保存的出生资料。"
        }
        var fullExplanation = explanation
        var selectedSources = Array(sources.prefix(3).map(\.id))
        if !resources.isEmpty && !output.isEmpty {
            selectedSources.append(sources[3].id)
            if !exposedOutput.isEmpty {
                fullExplanation += "\n\n本盘还见\(resources.map { "\($0.label)（\($0.relation)）" }.joined(separator: "、"))。印与伤官之间有另一条五行克向，提示不能把前面的关系当作唯一读法；但不能裁定印已经制住伤官或救应已经成功。原典谈伤官佩印还附有伤官旺、身稍弱等条件，本主题没有完成这些条件审定，更不能据此说你善于自我约束。"
            } else {
                fullExplanation += "\n\n\(resources.map { "\($0.label)（\($0.relation)）" }.joined(separator: "、"))虽然透出，伤官仍在支藏层；不能把它们改写成两干直接作用，更不能裁定佩印成立。原典的伤官旺、身稍弱等条件在本主题尚未审定。"
            }
        }
        let boundary = "这是传统结构提供的观察角度，不能据此认定你的性格。‘表达与规则’和下方练习是现代编辑内容，以你的经历为准；本主题不裁定格局、救应胜负、职业选择或具体事件结果。"
        let exercise = "现代编辑练习（可选）：选一个低风险、可以商量的要求，用三句话准备开口：‘我理解共同目标是……’‘我观察到的具体事实是……’‘可否尝试……，再按……确认效果？’把自己的推测与事实分开；如果对方有不能调整的约束，先问清原因。这个练习不保证沟通成功，也不是古籍对你下的行动指令。"
        let example = """
        现代编辑示例（完全虚构，不是你的经历）
        团队希望小林把一份方案缩成两页，好让参与者快速讨论。小林担心技术细节会丢失，想保留六页。先把这件事拆开：事实是对方提出了‘两页’；‘对方不重视我的工作’是小林的推测，还没有得到确认。双方是否必须删掉所有细节，也尚未问清。

        一种具体开口是：‘我理解是希望大家能快速抓住方案重点。我担心两处关键假设不写清，会让结论难以判断。能否正文保留两页，把推导放进附录，并请大家先看结论与假设？’接下来需要听对方的实际约束：如果所有材料总共只能两页，再一起选择必须保留的内容；如果只是会议正文要短，附录可能可行。这两种结果都要实际确认，不能由命盘预测。

        这个例子也说明组合为什么不等于人格：面对不同任务，小林可能一次接受要求，另一次提出修改。同一份本命结构不会告诉我们每次任务的全部约束，也没有测量小林当时掌握的信息，因此不能把其中一种反应定为人格，更不能用‘伤官’证明小林反叛、用‘正官’证明小林服从。有用的观察是‘这一回我知道什么、还需确认什么’，而不是为任何反应寻找一个十神标签。
        """
        let followUp = branch == .missingPair ? "这页为什么没有采用表达与规则的组合解读？" : "这页为什么把表达与规则放在一起看，哪些条件还不能确定？"
        return BaziLifeTheme(themeID: themeID, contentVersion: contentVersion, ruleVersion: ruleVersion, snapshotID: snapshotID,
                             branch: branch, hasExposedResource: !resources.isEmpty, title: title, summary: summary, explanation: fullExplanation,
                             boundary: boundary, observation: observation, exercise: exercise, example: example, followUpPrompt: followUp,
                             evidence: evidence, sourceIDs: selectedSources)
    }
    private static func canonical(_ value: Any) throws -> Data {
        try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .fragmentsAllowed, .withoutEscapingSlashes])
    }
    private static func validDigest(_ text: String) -> Bool { text.count == 64 && text.allSatisfy { $0.isHexDigit && !$0.isUppercase } }
    private static func digest(_ text: String) -> String { SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined() }
}
