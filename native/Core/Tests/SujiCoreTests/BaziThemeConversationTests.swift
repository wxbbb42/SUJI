import XCTest
@testable import SujiCore

final class BaziThemeConversationTests: XCTestCase {
    func testVerifiedFollowupShortAnswersAreScopedAndDoNotReplaceSafetyRouting() {
        XCTAssertEqual(BaziThemeRouting.resolve("方法", hasTheme: true, previousFollowUp: .goalOrMethod), .theme)
        XCTAssertEqual(BaziThemeAnswer.allowedActions("方法", previousFollowUp: .goalOrMethod), [.methodStep])
        XCTAssertEqual(BaziThemeAnswer.allowedActions("目标", previousFollowUp: .goalOrMethod), [.goalStep])
        XCTAssertEqual(BaziThemeRouting.resolve("时间不能调整", hasTheme: true, previousFollowUp: .constraints), .theme)
        XCTAssertEqual(BaziThemeAnswer.allowedActions("时间不能调整", previousFollowUp: .constraints), [.constraintStep])
        guard case .clarify = BaziThemeRouting.resolve("方法", hasTheme: true) else { return XCTFail("No preceding question must not infer context") }
        guard case .clarify = BaziThemeRouting.resolve("明年能投资吗", hasTheme: true, previousFollowUp: .constraints) else { return XCTFail() }
        XCTAssertEqual(BaziThemeRouting.resolve("请用六爻算方法", hasTheme: true, previousFollowUp: .goalOrMethod), .standard)
    }
    func testSelfInSocialContextIsNotAnotherPersonsChart() {
        for question in ["我和同事讨论规则时很难开口，练习怎么用", "昨天同事让我改方案，我没有表达不同意见，练习怎么用", "我和朋友讨论规则时总说不清，我想练习", "如果我不认同要求呢"] {
            XCTAssertEqual(BaziThemeRouting.resolve(question, hasTheme: true), .theme)
        }
        XCTAssertEqual(BaziThemeAnswer.allowedActions("如果我不认同要求呢"), [.practice])
        XCTAssertEqual(BaziThemeAnswer.allowedActions("这句话哪里不符合规则"), [.explain])
        XCTAssertEqual(BaziThemeAnswer.allowedActions("举个具体例子"), [.example])
    }
    func testExplanationCannotBeReplacedByUnrelatedPractice() {
        XCTAssertEqual(BaziThemeAnswer.allowedActions("这页为什么这么说"), [.explain])
        XCTAssertEqual(BaziThemeAnswer.allowedActions("印在哪里，有什么依据"), [.explain])
    }
    func testExplicitCalculationRequestCannotBeConsumedByExperienceShortcut() {
        for q in ["我想用六爻起卦，看看该怎么表达不同意见", "请用六爻看我和同事的不同意见", "我想用奇门观察这次不同意见"] {
            XCTAssertEqual(BaziThemeRouting.resolve(q, hasTheme: true), .standard)
        }
        guard case .clarify = BaziThemeRouting.resolve("我想观察今年投资股票能否成功", hasTheme: true) else { return XCTFail() }
        guard case .clarify = BaziThemeRouting.resolve("我姐姐也想练习表达规则", hasTheme: true) else { return XCTFail() }
    }
    func testCurrentSubjectAndTimeOverrideTheme() {
        for question in ["那我姐姐表达呢", "我对象呢", "朋友也这样吗"] {
            guard case .clarify = BaziThemeRouting.resolve(question, hasTheme: true) else { return XCTFail(question) }
        }
        for question in ["明年也这样吗", "今天适合提出不同意见吗", "我几岁能有孩子", "那这件事能成吗", "这样合适吗"] {
            guard case .clarify = BaziThemeRouting.resolve(question, hasTheme: true) else { return XCTFail(question) }
        }
        XCTAssertEqual(BaziThemeRouting.resolve("今年事业流年怎么看", hasTheme: true), .standard)
        XCTAssertEqual(BaziThemeRouting.resolve("用六爻看看这次面试", hasTheme: true), .standard)
    }
    func testStaticFollowupsAndDisagreementStayBounded() {
        for question in ["这页的表达与规则是什么意思", "举个例子", "举个具体例子", "我从不主动表达不同意见，这不符合我", "练习怎么用"] {
            XCTAssertEqual(BaziThemeRouting.resolve(question, hasTheme: true), .theme, question)
        }
        XCTAssertEqual(BaziThemeRouting.resolve("规则是什么意思", hasTheme: false), .standard)
        XCTAssertEqual(BaziThemeRouting.resolve("换个话题", hasTheme: true), .standard)
    }
}
