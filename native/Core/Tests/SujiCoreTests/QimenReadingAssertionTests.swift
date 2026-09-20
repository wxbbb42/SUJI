import XCTest
@testable import SujiCore

final class QimenReadingAssertionTests: XCTestCase {
    private let chart = #"{"method":{"centerPolicy":"fixed-kun-2; tian-qin-follows-tian-rui"},"palaces":[{"id":4,"diPanGan":"己","tianPanGan":"戊"},{"id":3,"diPanGan":"戊","tianPanGan":"癸"},{"id":2,"diPanGan":"乙","tianPanGan":"丁","hostedDiPanGan":"庚"},{"id":7,"diPanGan":"壬","tianPanGan":"乙","hostedTianPanGan":"庚"},{"id":5,"diPanGan":"庚","tianPanGan":"庚"}]}"#
    private func tool(_ id: String, _ raw: String) -> [ChatMessage] {
        [.assistantToolCalls([.init(id:id,name:"setup_qimen",arguments:[:])]),.toolResult(.init(callID:id,output:raw))]
    }
    private var history: [ChatMessage] { tool("q",chart) }

    func testArchivedWrongEarthPalaceIsRepairedEvenIfReviewerWouldAccept() async throws {
        let file = URL(fileURLWithPath:#filePath).deletingLastPathComponent().appendingPathComponent("../../../Engine/validation/reasoning/core-e2a-final-results.json")
        let report = try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:file)) as? [String:Any])
        let record = try XCTUnwrap((report["cases"] as? [[String:Any]])?.first)
        let draft = try XCTUnwrap(record["draft"] as? String)
        let messages = try JSONDecoder().decode([ChatMessage].self,from:JSONSerialization.data(withJSONObject:try XCTUnwrap(record["writerHistory"])))
        let issues = ReadingVerifier.deterministicIssues(in:draft,history:messages)
        XCTAssertEqual(issues.count,1)
        XCTAssertTrue(issues.first?.contains("qimen.palace4.diPanGan") == true)
        XCTAssertTrue(issues.first?.contains("己") == true)
        let repaired = "地盘戊在震宫，天盘戊在巽宫"
        let answer = try await ReadingVerifier.verify(draft:draft,history:messages,question:"核对盘层") { request in
            if request.last?.content?.hasPrefix(ReadingVerifier.revision) == true {
                XCTAssertTrue(request.last?.content?.contains("qimen.palace4.diPanGan") == true)
                return .text(repaired)
            }
            return .text(#"{"protocolVersion":"suji-verification-2","accepted":true,"reviewedSentences":[1],"issues":[]}"#)
        }
        XCTAssertEqual(answer,repaired)
    }

    func testDirectAndReverseClaimsBindTheirOwnPlateAndPalace() throws {
        let facts = ReadingVerificationEvidence.facts(history)
        for (sentence,key,value) in [
            ("地盘戊在巽宫","qimen.palace4.diPanGan","己"),
            ("巽四宫的地盘为戊","qimen.palace4.diPanGan","己"),
            ("天盘戊也在震宫","qimen.palace3.tianPanGan","癸"),
            ("坤二宫地盘寄干为壬","qimen.palace2.hostedDiPanGan","庚"),
            ("地盘寄干壬在坤二宫","qimen.palace2.hostedDiPanGan","庚"),
            ("兑七宫天禽寄干为壬","qimen.palace7.hostedTianPanGan","庚"),
            ("天禽寄干壬在兑宫","qimen.palace7.hostedTianPanGan","庚")
        ] {
            let issues = ReadingVerifier.deterministicIssues(in:sentence,history:history)
            XCTAssertEqual(issues.count,1,sentence)
            XCTAssertTrue(issues.first?.contains(key) == true,sentence)
            XCTAssertTrue(issues.first?.contains(value) == true,sentence)
            let fact = try XCTUnwrap(facts.first { $0.factKey == key })
            XCTAssertTrue(ReadingVerificationAssertions.binds(sentence.contains("壬") ? "壬" : "戊",to:fact,in:sentence,facts:facts),sentence)
        }
        for safe in ["地盘戊在震宫，天盘戊也在巽宫", "地盘寄干庚在坤宫，天禽寄干庚在兑宫", "坤二宫地盘为庚", "天盘庚在兑宫", "天盘庚在中宫", "兑七宫天禽寄干为庚"] {
            XCTAssertTrue(ReadingVerifier.deterministicIssues(in:safe,history:history).isEmpty,safe)
        }
        let primary = try XCTUnwrap(facts.first { $0.factKey == "qimen.palace2.diPanGan" })
        XCTAssertFalse(ReadingVerificationAssertions.binds("庚",to:primary,in:"坤二宫地盘为庚",facts:facts),"Known hosted stem cannot be mislabeled as a wrong primary")
        XCTAssertFalse(ReadingVerificationAssertions.binds("壬",to:primary,in:"坤二宫地盘寄干为壬",facts:facts))
    }

    func testContextAndConflictingReceiptsCannotAuthorizePlateRepair() throws {
        let wrong = "地盘戊在巽宫"
        let facts = ReadingVerificationEvidence.facts(history)
        let field = try XCTUnwrap(facts.first { $0.factKey == "qimen.palace4.diPanGan" })
        for sentence in ["如果" + wrong, "有人说：" + wrong, "上次：" + wrong, "旧盘" + wrong, wrong + "？", "不是" + wrong, wrong + "是不成立的", "六爻" + wrong, "书中记载：" + wrong, "例如：" + wrong, "2023年：" + wrong, wrong + "或震宫", "巽宫的地盘不是戊", "巽宫的地盘为戊是否正确", "并未证明：" + wrong, "待核对：" + wrong, wrong + "，这一判断缺乏依据", "下面只是示例：" + wrong, "我们考虑一种可能性：" + wrong] {
            XCTAssertTrue(ReadingVerifier.deterministicIssues(in:sentence,history:history).isEmpty,sentence)
            XCTAssertFalse(ReadingVerificationAssertions.binds("戊",to:field,in:sentence,facts:facts),sentence)
        }
        for extra in [chart.replacingOccurrences(of:"\"diPanGan\":\"己\"",with:"\"diPanGan\":\"壬\""), #"{"palaces":[{"id":3,"diPanGan":"戊"}]}"#] {
            let conflict = history + tool("other",extra)
            XCTAssertTrue(ReadingVerifier.deterministicIssues(in:wrong,history:conflict).isEmpty)
            XCTAssertFalse(ReadingVerificationAssertions.binds("戊",to:field,in:wrong,facts:ReadingVerificationEvidence.facts(conflict)))
        }
        let repeated = history + tool("same",chart)
        XCTAssertEqual(ReadingVerifier.deterministicIssues(in:wrong,history:repeated).count,1)
    }

    func testLegacyHostingDoesNotBecomeFalsePrimaryMismatch() {
        let legacy = chart.replacingOccurrences(of:",\"hostedDiPanGan\":\"庚\"",with:"")
        XCTAssertTrue(ReadingVerifier.deterministicIssues(in:"地盘庚在坤宫",history:tool("old",legacy)).isEmpty)
        let sparse = #"{"palaces":[{"id":2,"diPanGan":"乙"}]}"#
        XCTAssertTrue(ReadingVerifier.deterministicIssues(in:"地盘庚在坤宫",history:tool("sparse",sparse)).isEmpty)
    }

    func testReviewerFeedbackKeepsQuestionPunctuationAndExplicitHostedIdentity() throws {
        func feedback(_ sentence: String, draft: String? = nil, key: String, pointer: String, actual: String, claimed: String) throws -> ReadingVerifier.Feedback {
            let json: [String:Any] = ["protocolVersion":ReadingVerifier.protocolVersion,"accepted":false,"reviewedSentences":[1],"issues":[["kind":"field_mismatch","candidateQuote":sentence,"candidateValueQuote":claimed,"factKey":key,"toolCallID":"q","pointer":pointer,"actualValue":actual,"claimedValue":claimed,"predicate":"equals"]]]
            return ReadingVerifier.feedback(String(decoding:try JSONSerialization.data(withJSONObject:json),as:UTF8.self),draft:draft ?? sentence,history:history)
        }
        for sentence in ["地盘戊在巽宫", "巽四宫的地盘为戊"] {
            guard case .revise = try feedback(sentence,key:"qimen.palace4.diPanGan",pointer:"/palaces/0/diPanGan",actual:"己",claimed:"戊") else { return XCTFail(sentence) }
            guard case .invalid = try feedback(sentence,draft:sentence + "？",key:"qimen.palace4.diPanGan",pointer:"/palaces/0/diPanGan",actual:"己",claimed:"戊") else { return XCTFail("Question cannot authorize correction") }
        }
        guard case .revise = try feedback("兑七宫天禽寄干为壬",key:"qimen.palace7.hostedTianPanGan",pointer:"/palaces/3/hostedTianPanGan",actual:"庚",claimed:"壬") else { return XCTFail("Sky-host mismatch") }
        guard case .revise = try feedback("坤二宫地盘寄干为壬",key:"qimen.palace2.hostedDiPanGan",pointer:"/palaces/2/hostedDiPanGan",actual:"庚",claimed:"壬") else { return XCTFail("Earth-host mismatch") }
        guard case .invalid = try feedback("坤二宫地盘为庚",key:"qimen.palace2.diPanGan",pointer:"/palaces/2/diPanGan",actual:"乙",claimed:"庚") else { return XCTFail("Hosting is supported") }
        guard case .invalid = try feedback("兑七宫寄干为壬",key:"qimen.palace7.hostedTianPanGan",pointer:"/palaces/3/hostedTianPanGan",actual:"庚",claimed:"壬") else { return XCTFail("Unqualified hosting is ambiguous") }
    }
}
