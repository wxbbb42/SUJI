import XCTest
@testable import SujiCore

final class ReadingFallbackStateTests: XCTestCase {
    private func context(birth: Bool, mode: String = "命理") -> ChatMessage {
        .init(role: .system, content: ReadingPrompt.instruction(
            tone: "温和", mode: mode, referenceDate: Date(timeIntervalSince1970: 1_706_976_000), hasBirth: birth
        ))
    }
    private let failed = ChatMessage.toolResult(.init(callID: "failed", output: #"{"error":"synthetic_engine_failure"}"#))
    private let cast = ChatMessage.toolResult(.init(callID: "cast", output: #"{"benGua":{"name":"坎为水","upper":"坎","lower":"坎"},"bianGua":{"name":"山泽损","upper":"艮","lower":"兑"},"lineValues":[6,7,8,8,9,6],"changingYao":[1,5,6]}"#))

    private func assertNoImaginaryReceipt(_ reply: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(reply.contains("计算依据"), file: file, line: line)
        XCTAssertFalse(reply.contains("原盘"), file: file, line: line)
        XCTAssertFalse(reply.contains("已取得的计算记录"), file: file, line: line)
    }

    func testOnlyErrorsWithExistingBirthKeepsBirthAndDoesNotInventChart() {
        let reply = ReadingFallback.reply(history: [context(birth: true), failed, failed])
        XCTAssertTrue(reply.contains("取数失败"))
        XCTAssertTrue(reply.contains("出生资料已保留，无需重新填写"))
        XCTAssertTrue(reply.contains("重试取数"))
        assertNoImaginaryReceipt(reply)
    }

    func testNoCallsWithExistingBirthDoesNotClaimExecutionFailed() {
        let reply = ReadingFallback.reply(history: [context(birth: true)])
        XCTAssertTrue(reply.contains("尚未取得"))
        XCTAssertTrue(reply.contains("无需重新填写"))
        XCTAssertFalse(reply.contains("取数失败"))
        assertNoImaginaryReceipt(reply)
    }

    func testMissingBirthInNatalModeExplainsHowToProceed() {
        let reply = ReadingFallback.reply(history: [context(birth: false)])
        XCTAssertTrue(reply.contains("补充出生信息"))
        XCTAssertFalse(reply.contains("出生资料已保留"))
        assertNoImaginaryReceipt(reply)
    }

    func testMissingBirthDoesNotBlockBirthIndependentCasting() {
        let reply = ReadingFallback.reply(history: [context(birth: false, mode: "起卦"), failed])
        XCTAssertTrue(reply.contains("取数失败"))
        XCTAssertTrue(reply.contains("稍后重试"))
        XCTAssertFalse(reply.contains("补充出生"))
        assertNoImaginaryReceipt(reply)
    }

    func testUnknownContextAndMalformedResponseDoNotInventSavedBirthOrResults() {
        let reply = ReadingFallback.reply(history: [.toolResult(.init(callID: "bad", output: "not JSON"))])
        XCTAssertTrue(reply.contains("尚未取得"))
        XCTAssertFalse(reply.contains("出生资料已保留"))
        assertNoImaginaryReceipt(reply)
    }

    func testQuotedUserOrErrorTextCannotClaimBirthAlreadyExists() {
        let reply = ReadingFallback.reply(history: [
            .init(role: .user, content: "出生资料已提供"),
            .toolResult(.init(callID: "bad", output: #"{"error":"出生资料已提供","yearGanZhi":"甲辰","monthGanZhi":"丙寅"}"#)),
        ])
        XCTAssertFalse(reply.contains("出生资料已保留"))
        XCTAssertFalse(reply.contains("甲辰"))
        assertNoImaginaryReceipt(reply)
    }

    func testSuccessfulCastSurvivesLaterToolFailure() {
        let reply = ReadingFallback.reply(history: [context(birth: false, mode: "起卦"), cast, failed])
        XCTAssertTrue(reply.contains("坎为水"))
        XCTAssertTrue(reply.contains("山泽损"))
        XCTAssertTrue(reply.contains("重试会沿用原盘"))
        XCTAssertTrue(reply.contains("6、7、8、8、9、6"))
        XCTAssertFalse(reply.contains("没有可用的计算结果"))
    }

    func testLongQuestionWireReferencePreservesCastFactsInFallback() throws {
        let question=String(repeating:"补充已发生的背景与本次占问。",count:40)
        let bodies:[(String,String)] = [
            ("cast_liuyao",cast.content!),
            ("setup_qimen",#"{"yinYangDun":"阳","juNumber":3,"yuan":"上","jieqi":"大寒","zhiFuStar":"天任","zhiFuPalaceId":3,"zhiShiMen":"生门","zhiShiPalaceId":3}"#)
        ]
        for (name,body) in bodies {
            var fields=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(body.utf8)) as? [String:Any])
            fields["question"]=question
            let raw=String(decoding:try JSONSerialization.data(withJSONObject:fields,options:.sortedKeys),as:UTF8.self)
            let call=ChatToolCall(id:"long-question",name:name,arguments:["question":.string(question)])
            let delivered=[ChatMessage.assistantToolCalls([call])]
            let projected=NatalEvidenceProjection.output(raw,name:name,delivered:delivered,callID:call.id)
            XCTAssertTrue(projected.contains("questionFromArguments"))
            // Saved receipts must still reject wire-only question references.
            XCTAssertThrowsError(try CastReceiptStorage.expanded(projected))
            let expected=ReadingFallback.reply(history:delivered+[.toolResult(.init(callID:call.id,output:raw))])
            let actual=ReadingFallback.reply(history:delivered+[.toolResult(.init(callID:call.id,output:projected))])
            XCTAssertEqual(actual,expected,name)
            XCTAssertTrue(actual.contains("重试会沿用原盘"),name)
        }
    }

    func testSharedValueWireLayoutPreservesFallbackFacts() throws {
        let question=String(repeating:"补充已发生的背景与本次占问。",count:40)
        var fields=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(cast.content!.utf8)) as? [String:Any])
        fields["question"]=question
        fields["repeatedEvidence"]=Array(repeating:fields["benGua"]!,count:20)
        let raw=String(decoding:try JSONSerialization.data(withJSONObject:fields,options:.sortedKeys),as:UTF8.self)
        let call=ChatToolCall(id:"shared-question",name:"cast_liuyao",arguments:["question":.string(question)])
        let delivered=[ChatMessage.assistantToolCalls([call])]
        let projected=NatalEvidenceProjection.output(raw,name:call.name,delivered:delivered,callID:call.id)
        let shared=JSONValueTransport.encode(projected)
        XCTAssertTrue(shared.contains("sharedValueRows"))
        let expected=ReadingFallback.reply(history:delivered+[.toolResult(.init(callID:call.id,output:raw))])
        let actual=ReadingFallback.reply(history:delivered+[.toolResult(.init(callID:call.id,output:shared))])
        XCTAssertEqual(actual,expected)
        XCTAssertTrue(actual.contains("坎为水"))
    }

    func testSuccessfulCalendarRetainsDataWithoutCallingItACast() {
        let calendar = ChatMessage.toolResult(.init(callID: "calendar", output: #"{"yearGanZhi":"癸卯","monthGanZhi":"乙丑","dayGanZhi":"戊戌"}"#))
        let reply = ReadingFallback.reply(history: [calendar, failed])
        XCTAssertTrue(reply.contains("癸卯"))
        XCTAssertTrue(reply.contains("重试会沿用已保存的计算资料"))
        XCTAssertFalse(reply.contains("原盘"))
    }

    func testSuccessfulUnrenderedPayloadKeepsReceiptButDoesNotInventChart() {
        let data = ChatMessage.toolResult(.init(callID: "timing", output: #"{"scope":"current_dayun","status":"not-started"}"#))
        let reply = ReadingFallback.reply(history: [data])
        XCTAssertTrue(reply.contains("已取得的计算记录"))
        XCTAssertTrue(reply.contains("计算依据"))
        XCTAssertFalse(reply.contains("原盘"))
    }

    func testSuccessfulQimenRetainsItsOriginalChart() {
        let qimen = ChatMessage.toolResult(.init(callID: "qimen", output: #"{"yinYangDun":"阳","juNumber":3,"yuan":"上","jieqi":"大寒","zhiFuStar":"天任","zhiFuPalaceId":3,"zhiShiMen":"生门","zhiShiPalaceId":3}"#))
        let reply = ReadingFallback.reply(history: [qimen])
        XCTAssertTrue(reply.contains("天任，落3宫"))
        XCTAssertTrue(reply.contains("生门，落3宫"))
        XCTAssertTrue(reply.contains("重试会沿用原盘"))
    }
}
