import XCTest
@testable import SujiCore

final class ReadingResponseContractTests: XCTestCase {
    private func history(error: Bool = false) -> [ChatMessage] {
        [.init(role: .system, content: ReadingPrompt.instruction(tone: "温暖", mode: "命理", referenceDate: Date(timeIntervalSince1970: 1_790_067_521), hasBirth: true)),
         .init(role: .assistant, content: "上次读取不稳定，没有可用的盘面结果。"),
         .init(role: .user, content: "那你能算一下我几岁会有孩子吗"),
         .assistantToolCalls([.init(id: "children", name: "get_bazi_star", arguments: ["person": "子女"])]),
         .toolResult(.init(callID: "children", output: error ? #"{"error":"synthetic engine failure"}"# : #"{"person":"子女","relevantShiShen":["食神","伤官"],"positionsInChart":["月柱 甲申（食神）","时柱 乙巳（伤官）"]}"#))]
    }

    func testCannotPromoteMissingProductRulesIntoUniversalDismissal() {
        for draft in ["命盘里确实没有一条规则能定出几岁会有孩子。", "谁给你报一个确定岁数，那都是编的。", "这些我们一起聊，比看星更有用。", "那才是有用的。"] {
            XCTAssertFalse(ReadingVerifier.deterministicIssues(in: draft, history: history()).isEmpty, draft)
        }
        for draft in ["目前这套工具还没有生育应期的完整判定，不能据此定出具体年龄。", "按所用六亲对应口径，你的子女星为食神、伤官；不等于确定的生育时间。", "传统上会结合子女相关星位与运限讨论应期，本次没有给出已成立的生育应期。"] {
            XCTAssertTrue(ReadingVerifier.deterministicIssues(in: draft, history: history()).isEmpty, draft)
        }
    }

    func testSuccessfulCurrentFactsCannotInheritHistoricalReadFailure() {
        for draft in ["这轮排盘读取不稳定，得等取数稳定了再说。", "这次没有取得可用的盘面结果。"] {
            XCTAssertFalse(ReadingVerifier.deterministicIssues(in: draft, history: history()).isEmpty, draft)
        }
        XCTAssertTrue(ReadingVerifier.deterministicIssues(in: "这次取数失败，暂时没有可用的盘面结果。", history: history(error: true)).isEmpty)
        XCTAssertTrue(ReadingVerifier.deterministicIssues(in: "本次已读到子女星，尚缺具体年龄判断的依据。", history: history()).isEmpty)
    }

    func testObservedStemPlacementFalseAcceptanceIsRejectedLocally() {
        let natal: [ChatMessage] = [.assistantToolCalls([.init(id: "natal", name: "get_domain", arguments: ["domain": "福德"])]),
            .toolResult(.init(callID: "natal", output: #"{"bazi":{"pillars":{"year":{"ganZhi":{"gan":"庚","zhi":"午"}},"month":{"ganZhi":{"gan":"甲","zhi":"申"}},"day":{"ganZhi":{"gan":"壬","zhi":"子"}},"hour":{"ganZhi":{"gan":"乙","zhi":"巳"}}}}}"#))]
        for draft in ["月令申金的本气庚金透在月干，构得偏印格。", "时干乙与月干庚成五合但两干隔位。", "你的月柱是庚申。", "月干透出庚金。", "月柱天干是**庚金**，本命盘如此。", "**月柱庚申**。"] {
            XCTAssertFalse(ReadingVerifier.deterministicIssues(in: draft, history: natal).isEmpty, draft)
        }
        for draft in ["年干庚，月干甲，日干壬，时干乙。", "庚金透在年干，月支申也藏庚。", "月柱甲申，月干甲。", "月柱天干为**甲木**。", "如果月干是庚，应如何分析？", "并不是月干庚。", "你说‘月干庚’，这个说法有误。", "流年天干庚与月干关系待查。", "月干庚吗？"] {
            XCTAssertTrue(ReadingVerifier.deterministicIssues(in: draft, history: natal).isEmpty, draft)
        }
        let conflicting = natal + [.assistantToolCalls([.init(id: "other", name: "get_domain", arguments: ["domain": "事业"])]), .toolResult(.init(callID: "other", output: #"{"bazi":{"pillars":{"month":{"ganZhi":{"gan":"庚","zhi":"申"}}}}}"#))]
        XCTAssertTrue(ReadingVerifier.deterministicIssues(in: "月干庚。", history: conflicting).isEmpty, "Conflicting receipts need identity, not choosing an arbitrary chart")
    }

    func testRejectedProsePreservesAvailableDomainAndTimingFacts() {
        let records = [
            ("get_domain", #"{"domain":"事业","ziwei":{"palace":"官禄宫","ganZhi":"辛丑","mainStars":[]}}"#),
            ("get_bazi_star", #"{"person":"子女","relevantShiShen":["食神","伤官"],"positionsInChart":["月柱 甲申（食神）"],"hiddenPositions":[],"correspondencePolicy":"本测试选定传统对应，不代表现实亲缘有无"}"#),
            ("get_timing", #"{"scope":"current_dayun","status":"active","data":{"ganZhi":{"gan":"庚","zhi":"辰"},"period":"32–41岁（整岁参考，以交运日期为准）"}}"#),
            ("get_ziwei_timing", #"{"activeDecade":{"palace":"子女宫","ganZhi":"丁亥","startAge":35,"endAge":44}}"#),
        ]
        let history = records.enumerated().flatMap { i, item in
            [ChatMessage.assistantToolCalls([.init(id: "receipt-\(i)", name: item.0, arguments: [:])]), .toolResult(.init(callID: "receipt-\(i)", output: item.1))]
        }
        let answer = ReadingFallback.reply(history: history)
        for fragment in ["官禄宫", "无主星", "食神、伤官", "甲申", "庚辰", "整岁参考", "35–44虚岁", "不代表现实亲缘"] { XCTAssertTrue(answer.contains(fragment), fragment) }
        XCTAssertFalse(answer.contains("35岁会有孩子"))
        XCTAssertFalse(answer.contains("尚未取得"))
        let failure = ReadingFallback.reply(history: [.toolResult(.init(callID: "fail", output: #"{"error":"failed","person":"子女","relevantShiShen":["假造星"]}"#))])
        XCTAssertFalse(failure.contains("假造星"))
    }

    func testObservedChartBasedPortfolioAdviceCannotPassWithADisclaimer() {
        for draft in ["今年（2026丙午）看盘的线索指向波动偏大、不宜重仓押注，而不是会赚多少这种可量化的问题。", "你的流年显示今年适合投资股票，只是不能保证赚钱。", "命盘提示应该减仓，仅供参考。"] {
            XCTAssertFalse(ReadingVerifier.deterministicIssues(in: draft, history: history()).isEmpty, draft)
        }
        for draft in ["盘面不能判断股票涨跌或决定仓位，投资安排需要依据预算与风险承受能力。", "当前流年为丙午，不能据此预测投资收益。", "一般而言，投资应考虑预算，不宜重仓押注；这与命盘无关。"] {
            XCTAssertTrue(ReadingVerifier.deterministicIssues(in: draft, history: history()).isEmpty, draft)
        }
    }

    func testObservedCountAndKinshipLabelsMustMatchReturnedPolicy() {
        func chart(_ strong: Bool, policy: String) -> [ChatMessage] {
            [.assistantToolCalls([.init(id: strong ? "strong" : "weak", name: "get_domain", arguments: [:])]),
             .toolResult(.init(callID: strong ? "strong" : "weak", output: "{\"bazi\":{\"strengthReference\":{\"riZhuStrong\":\(strong)},\"correspondencePolicy\":\"\(policy)\"}}"))]
        }
        let policy = "传统六亲对应：男财女官论配偶、男官杀女子食伤论子女；流派有异。"
        let weak = chart(false, policy: policy)
        for draft in ["计数结果是偏强，但这个计数没做月令加权。", "按固定权重计数列为**偏强**。", "男命以官杀论配偶，本次口径下你的配偶星是正官与七杀。", "女命以财星论配偶。"] {
            XCTAssertFalse(ReadingVerifier.deterministicIssues(in: draft, history: weak).isEmpty, draft)
        }
        for draft in ["计数结果是偏弱；月令本气五态为旺，两者口径不同。", "男命以财星论配偶，女命以官杀论配偶；流派有异。", "如果计数结果是偏强，需要怎样分析？", "不是计数结果偏强。", "你说‘男命以官杀论配偶’，这个说法有误。"] {
            XCTAssertTrue(ReadingVerifier.deterministicIssues(in: draft, history: weak).isEmpty, draft)
        }
        XCTAssertTrue(ReadingVerifier.deterministicIssues(in: "计数结果是偏强。", history: weak + chart(true, policy: policy)).isEmpty)
        XCTAssertTrue(ReadingVerifier.deterministicIssues(in: "男命以官杀论配偶。", history: chart(false, policy: "另一个未在此测试裁定的流派" )).isEmpty)
    }

    func testObservedInvestmentOpportunityParaphraseIsNotAChartConclusion() {
        var financial = history()
        financial[2] = .init(role: .user, content: "今年适合买股票吗，会赚多少？")
        for draft in ["流年财星到位、同时伴随反复与张力，属于有机会也有波动的类型，而不是平稳躺赚。", "紫微这层，财与职场的格局偏活跃，兼顾波动。"] {
            XCTAssertFalse(ReadingVerifier.deterministicIssues(in: draft, history: financial).isEmpty, draft)
        }
        for draft in ["流年为丙午，偏财是十神分类，不能据此推算投资机会或波动。", "投资有机会也有风险，需根据现实财务状况判断，与命盘无关。", "如果有人说流年有机会也有波动，不能当作投资依据。"] {
            XCTAssertTrue(ReadingVerifier.deterministicIssues(in: draft, history: financial).isEmpty, draft)
        }
    }

    func testQuotedCriticismAndActualMissingFactsAreNotFalsePositives() {
        for draft in ["你提到‘那才是有用的’这个说法。", "如果说谁给你报一个确定岁数都是编的，就超出了证据。", "当前工具没有任何生育应期规则。"] {
            XCTAssertTrue(ReadingVerifier.deterministicIssues(in: draft, history: history()).isEmpty, draft)
        }
        let noFacts = Array(history().prefix(3))
        XCTAssertTrue(ReadingVerifier.deterministicIssues(in: "这次没有取得可用的盘面结果。", history: noFacts).isEmpty)
    }
}
