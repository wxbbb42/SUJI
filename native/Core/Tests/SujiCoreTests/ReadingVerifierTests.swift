import XCTest
@testable import SujiCore

final class ReadingVerifierTests: XCTestCase {
    func testExplicitQimenRequestIsAvailableInDivinationModeWithoutSubstitutingLiuyao() throws {
        let data = Data(#"[{"function":{"name":"cast_liuyao","description":"liuyao","parameters":{}}},{"function":{"name":"setup_qimen","description":"qimen","parameters":{}}}]"#.utf8)
        let question = "请用奇门问我自己近期能否签下新办公室租约，这是近事。先只核对盘面。"
        let names = try ReadingIntent.definitions(from:data,mode:"起卦",question:question,hasBirth:false).map(\.name)
        XCTAssertEqual(names,["setup_qimen"])
        for plain in ["问这次租约", "不要用奇门，给我起六爻", "奇门和六爻有什么区别"] {
            XCTAssertEqual(try ReadingIntent.definitions(from:data,mode:"起卦",question:plain,hasBirth:false).map(\.name),["cast_liuyao"])
        }
        for both in ["请用奇门和六爻分别分析这次租约", "用六爻和奇门分别解释这次盘面"] {
            XCTAssertEqual(try ReadingIntent.definitions(from:data,mode:"起卦",question:both,hasBirth:false).map(\.name),["cast_liuyao","setup_qimen"])
        }
        for discussion in ["用奇门起局是什么意思？", "什么是奇门", "请介绍奇门起局的方法", "奇门和六爻有什么区别"] {
            XCTAssertFalse(ReadingIntent.allowsQimen(discussion),discussion)
        }
    }
    private let accepted = #"{"protocolVersion":"suji-verification-2","accepted":true,"reviewedSentences":[1],"issues":[]}"#
    private let rejected = #"{"protocolVersion":"suji-verification-2","accepted":false,"reviewedSentences":[1],"issues":[{"kind":"field_mismatch","candidateQuote":"年柱为甲辰","candidateValueQuote":"甲辰","factKey":"calendar.year","toolCallID":"a","pointer":"/yearGanZhi","actualValue":"癸卯","claimedValue":"甲辰","predicate":"equals"}]}"#
    private var history: [ChatMessage] {
        [ChatMessage(role: .system, content: "出生资料已提供"),
         ChatMessage(role: .assistant, content: "昨日不可信旧答案"),
         ChatMessage(role: .user, content: "今年是什么年"),
         .assistantToolCalls([.init(id: "a", name: "get_today_context", arguments: [:])]),
         .toolResult(.init(callID: "a", output: #"{"yearGanZhi":"癸卯"}"#))]
    }

    func testAcceptedDraftReturnedUnchanged() async throws {
        let result = try await ReadingVerifier.verify(draft: "仍为癸卯", history: history, question: "当前年柱") { _ in .text(self.accepted) }
        XCTAssertEqual(result, "仍为癸卯")
    }

    func testIncorrectDraftMustBeRevisedAndRechecked() async throws {
        var calls = 0
        let result = try await ReadingVerifier.verify(draft: "年柱为甲辰", history: history, question: "当前年柱") { messages in
            calls += 1
            if calls == 1 { return .text(self.rejected) }
            if calls == 2 {
                XCTAssertTrue(messages.last!.content!.contains("癸卯"))
                return .text("仍为癸卯")
            }
            XCTAssertTrue(messages.last!.content!.contains("仍为癸卯"))
            return .text(self.accepted)
        }
        XCTAssertEqual(result, "仍为癸卯")
        XCTAssertEqual(calls, 3)
    }

    func testRepeatedRejectionNeverReturnsOriginalOrRevisedDraft() async {
        var calls = 0
        do {
            _ = try await ReadingVerifier.verify(draft: "年柱为甲辰", history: history, question: "当前年柱") { _ in
                calls += 1
                return .text(calls == 2 ? "年柱为甲辰" : self.rejected)
            }
            XCTFail("Rejected draft must not be displayed")
        } catch { XCTAssertTrue(error is ReadingVerifier.Rejected) }
        XCTAssertEqual(calls, 3)
    }

    func testMalformedAndContradictoryVerdictsFailClosed() async {
        for value in ["accepted", #"{"accepted":true,"issues":["错误"]}"#, #"{"accepted":false,"issues":[]}"#, "```json\n\(accepted)\n```", #"{"accepted":true}"#] {
            do {
                _ = try await ReadingVerifier.verify(draft: "draft", history: history, question: "q") { _ in .text(value) }
                XCTFail(value)
            } catch { XCTAssertTrue(error is ReadingVerifier.Rejected) }
        }
    }

    func testOnlyCurrentToolMessagesAreEvidenceAndQuestionIsExplicit() {
        let messages = ReadingVerifier.messages(draft: "candidate", history: history, question: "最新原始问题")
        XCTAssertFalse(messages.contains { $0.content == "昨日不可信旧答案" })
        XCTAssertTrue(messages.contains { $0.content?.contains("最新原始问题") == true })
        XCTAssertEqual(messages.filter { $0.role == .tool }, history.filter { $0.role == .tool })
        XCTAssertEqual(messages.flatMap { $0.toolCalls ?? [] }.map(\.id), ["a"])
    }

    func testCancellationBetweenResponseAndAcceptanceNeverReturnsDraft() async {
        let task = Task {
            try await ReadingVerifier.verify(draft: "draft", history: history, question: "q") { _ in
                try await Task.sleep(nanoseconds: 50_000_000)
                return .text(self.accepted)
            }
        }
        task.cancel()
        do { _ = try await task.value; XCTFail("Cancelled draft") }
        catch { XCTAssertTrue(error is CancellationError) }
    }

    func testDeterministicGuardCatchesObservedFalseAcceptsWithoutRejectingCalendarFacts() {
        for draft in ["2026到2028这几年盘面相对顺一些，2028尤其值得关注", "2024这一年更适合打磨能力，主动争位置容易被卡", "如果用真太阳时，实际交节对应的钟表时间会有几分钟偏差", "我上一条回答里关于疾病的说法，我把它撤掉", "<AUTO>说明"] {
            XCTAssertFalse(ReadingVerifier.deterministicIssues(in: draft).isEmpty, draft)
        }
        XCTAssertTrue(ReadingVerifier.deterministicIssues(in: "2024年甲辰，年干甲为食神。升职取决于绩效和岗位空缺，不能由盘决定年份。").isEmpty)
    }

    func testDeterministicRejectionDoesNotTrustAFalseModelAcceptance() async {
        var calls = 0
        do {
            _ = try await ReadingVerifier.verify(draft: "2028尤其值得关注", history: history, question: "事业") { _ in
                calls += 1
                return .text("2028尤其值得关注")
            }
            XCTFail("An unchanged offending revision is rejected locally")
        } catch { XCTAssertTrue(error is ReadingVerifier.Rejected) }
        XCTAssertEqual(calls, 1)
    }

    func testFallbackPreservesActualLineOrderAndDoesNotRepeatDraftOrInterpret() {
        let tool = ChatMessage.toolResult(.init(callID: "cast", output: #"{"benGua":{"name":"坎为水","upper":"坎","lower":"坎"},"bianGua":{"name":"山泽损","upper":"艮","lower":"兑"},"lineValues":[6,7,8,8,9,6],"changingYao":[1,5,6]}"#))
        let reply = ReadingFallback.reply(history: [.init(role: .assistant, content: "这年必定升职"), tool])
        XCTAssertTrue(reply.contains("6、7、8、8、9、6"))
        XCTAssertTrue(reply.contains("动爻：1、5、6"))
        XCTAssertTrue(reply.contains("变卦上艮下兑"))
        XCTAssertFalse(reply.contains("升职"))
    }

    func testFallbackSkipsToolErrorsAndUnrecognizedPayloads() {
        let reply = ReadingFallback.reply(history: [.toolResult(.init(callID: "x", output: #"{"error":"failed","yearGanZhi":"甲辰","monthGanZhi":"丙寅"}"#))])
        XCTAssertFalse(reply.contains("甲辰"))
        XCTAssertTrue(reply.contains("暂未采用"))
    }

    func testQimenRequiresPositiveIntentAndHonorsNegation() {
        for text in ["不要用奇门", "不要起卦，谈谈奇门", "什么是奇门", "我不想用奇门分析", "奇门和六爻有什么区别"] {
            XCTAssertFalse(ReadingIntent.allowsQimen(text), text)
        }
        for text in ["请用奇门看看事业", "奇门排盘", "请按奇门推演这件事"] {
            XCTAssertTrue(ReadingIntent.allowsQimen(text), text)
        }
    }
}
