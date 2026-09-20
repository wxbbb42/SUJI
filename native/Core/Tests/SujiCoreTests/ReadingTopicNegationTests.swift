import Foundation
import XCTest
@testable import SujiCore

final class ReadingTopicNegationTests: XCTestCase {
    private func topics(_ question: String) throws -> [ReadingDocument.Focus]? {
        let context = try ToolContext(birth: nil, engineRevision: "topic-scope-test", referenceDate: Date(timeIntervalSince1970: 1_789_876_800), mode: "命理")
        let next = ConversationEntry(role: "user", text: question)
        return BaziReadingRequest.resolveRequest(question: question, mode: "命理", entries: [next], currentUserID: next.id, context: context)?.focuses
    }

    func testPoliteAndEmbeddedRefusalsDoNotBecomeRequiredTopics() throws {
        XCTAssertEqual(try topics("只讲我的扶抑和调候，请不要讲格局。"), [.strength, .climate])
        XCTAssertEqual(try topics("我不想看扶抑，只讲调候"), [.climate])
        XCTAssertEqual(try topics("我的八字不要讲格局，只看扶抑"), [.strength])
        XCTAssertEqual(try topics("我的格局暂时不用讲，只讲调候"), [.climate])
        XCTAssertEqual(try topics("我的扶抑怎么理解，格局不用讲"), [.strength])
    }

    func testRefusalCoversTheWholeTopicListUntilAnExplicitPositiveClause() throws {
        for question in [
            "不要讲我的扶抑和调候，只讲格局",
            "不看我的扶抑和调候，只讲格局",
            "我的扶抑和调候先不看，只讲格局",
            "我的八字不用比较扶抑和调候，而是讲格局",
            "我的八字不要讲扶抑和调候只讲格局"
        ] { XCTAssertEqual(try topics(question), [.pattern], question) }
        XCTAssertNil(try topics("请不要讲我的扶抑和调候"))
    }

    func testPositiveWordsContainingBieAndQualificationQuestionsRemainSupported() throws {
        XCTAssertEqual(try topics("分别讲我的扶抑和调候"), [.strength, .climate])
        XCTAssertEqual(try topics("特别说说我的格局"), [.pattern])
        XCTAssertEqual(try topics("我的偏印格是不是已成？不要那些限定。"), [.pattern])
        XCTAssertEqual(try topics("我的格局为什么只是候选，而不是已经成格？"), [.pattern])
        XCTAssertEqual(try topics("请解释我的八字为什么不成格？"), [.pattern])
        XCTAssertEqual(try topics("我的八字不成格是什么意思？"), [.pattern])
    }
}
