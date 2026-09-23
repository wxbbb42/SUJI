import XCTest
@testable import SujiCore

final class BaziThemeAnswerTests: XCTestCase {
    // Selector-only fixture, not chart evidence. Real engine projections are
    // exercised in BaziLifeThemeTests and the hosted ChatSession tests.
    private var theme: BaziLifeTheme {
        .init(themeID: BaziLifeThemeCompiler.themeID, contentVersion: BaziLifeThemeCompiler.contentVersion,
              ruleVersion: BaziLifeThemeCompiler.ruleVersion, snapshotID: String(repeating: "a", count: 64),
              branch: .bothExposed, hasExposedResource: false, title: "主题", summary: "测试事实",
              explanation: "测试组合解释", boundary: "不能据此认定性格", observation: "可反驳的观察",
              exercise: "现代编辑练习", example: "明确虚构的例子，不是用户经历", followUpPrompt: "为什么", evidence: [], sourceIDs: [])
    }
    private func selection(_ action: String, snapshot: String? = nil, extra: Bool = false) throws -> String {
        var o = ["protocolVersion": BaziThemeAnswer.protocolVersion, "snapshotID": snapshot ?? theme.snapshotID, "action": action, "followUp": "none"]
        if extra { o["interpretation"] = "你天生反叛" }
        return String(decoding: try JSONSerialization.data(withJSONObject: o), as: UTF8.self)
    }
    func testSemanticTaskAndNecessaryQualifierAreIndivisible() throws {
        for bad in ["practice", "observe", "notApplicable", "invented"] {
            XCTAssertThrowsError(try BaziThemeAnswer.validate(selection: selection(bad), theme: theme, question: "为什么这样解释"))
        }
        let explanation = try BaziThemeAnswer.validate(selection: selection("explain"), theme: theme, question: "为什么这样解释")
        XCTAssertTrue(explanation.text.contains(theme.explanation)); XCTAssertTrue(explanation.text.contains(theme.boundary))
        XCTAssertThrowsError(try BaziThemeAnswer.validate(selection: selection("explain"), theme: theme, question: "举个例子"))
        XCTAssertThrowsError(try BaziThemeAnswer.validate(selection: selection("explain"), theme: theme, question: "我从不主动表达不同意见"))
        XCTAssertThrowsError(try BaziThemeAnswer.validate(selection: selection("explain", extra: true), theme: theme, question: "为什么"))
        XCTAssertThrowsError(try BaziThemeAnswer.validate(selection: selection("explain", snapshot: "another"), theme: theme, question: "为什么"))
    }
    func testShortAnswerNeedsVerifiedPrecedingQuestionAndCannotRepeatIt() throws {
        XCTAssertThrowsError(try BaziThemeAnswer.validate(selection: selection("methodStep"), theme: theme, question: "方法"))
        let answer = try BaziThemeAnswer.validate(selection: selection("methodStep"), theme: theme, question: "方法", previousFollowUp: .goalOrMethod)
        XCTAssertTrue(answer.text.contains("现代沟通练习")); XCTAssertTrue(answer.text.contains(theme.boundary))
        XCTAssertFalse(BaziThemeAnswer.allowedFollowUps(.methodStep).contains(.goalOrMethod))
        XCTAssertEqual(BaziThemeAnswer.allowedFollowUps(.constraintStep), [.none])
        XCTAssertThrowsError(try BaziThemeAnswer.validate(selection: selection("explain"), theme: theme, question: "方法", previousFollowUp: .goalOrMethod))
    }
    func testExplicitRequestForNextQuestionCannotBeSilentlySkipped() throws {
        XCTAssertThrowsError(try BaziThemeAnswer.validate(selection: selection("example"), theme: theme,
            question: "举个具体例子，并问我一个能帮助继续练习的问题"))
    }
    func testInvalidModelOutputGetsOnlyOneRepairAndNoFreeProseFallback() async throws {
        var requests = 0
        do {
            _ = try await BaziThemeAnswer.compose(theme: theme, question: "为什么", previousQuestions: []) { _ in requests += 1; return .text("你天生叛逆，所以会失败") }
            XCTFail("Unsafe prose must never render")
        } catch { XCTAssertTrue(error is BaziThemeAnswer.Failure) }
        XCTAssertEqual(requests, 2)
    }
    func testTransportFailureDoesNotSpendAnAutomaticRepair() async throws {
        var requests = 0
        do {
            _ = try await BaziThemeAnswer.compose(theme: theme, question: "为什么", previousQuestions: []) { _ in requests += 1; throw URLError(.notConnectedToInternet) }
            XCTFail("Offline is not a valid selection")
        } catch { XCTAssertTrue(error is URLError) }
        XCTAssertEqual(requests, 1)
    }
}
