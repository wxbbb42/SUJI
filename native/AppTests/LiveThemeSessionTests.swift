import XCTest
import SwiftData
import SujiCore
@testable import Suji

/// Operator opt-in. Uses a disposable account, real engine, real deployed model,
/// production ChatSession and its closed verifier. No synthetic success replies.
@MainActor final class LiveThemeSessionTests: XCTestCase {
    struct Turn: Decodable { let question: String; let kind: String }
    struct Case: Decodable { let id: String; let profile: String; let question: String; let turns: [Turn] }
    struct Matrix: Decodable { let syntheticOnly: Bool; let profiles: [String: BirthProfile]; let cases: [Case] }
    struct Configuration: Decodable {
        let email: String; let password: String; let reportPath: String; let matrixPath: String
        let caseIDs: [String]; let requestBudget: Int
    }
    func testAuthenticatedThemeJourney() async throws {
        guard let path = ProcessInfo.processInfo.environment["SUJI_LIVE_READING_CONFIG"] else { throw XCTSkip("Explicit disposable-account launcher required") }
        let config = try JSONDecoder().decode(Configuration.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
        let matrix = try JSONDecoder().decode(Matrix.self, from: Data(contentsOf: URL(fileURLWithPath: config.matrixPath)))
        XCTAssertTrue(matrix.syntheticOnly); XCTAssertLessThanOrEqual(config.requestBudget, 24)
        let saved = try KeychainStore.read("supabase-session"); try KeychainStore.write(nil, name: "supabase-session")
        defer { try? KeychainStore.write(saved, name: "supabase-session") }
        let container = try ModelContainer(for: SavedState.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let script = try XCTUnwrap(Bundle.main.url(forResource: "mingli", withExtension: "js"))
        let store = try AppStore(context: container.mainContext, scriptURL: script, userID: nil)
        await store.accountSession.signIn(email: config.email, password: config.password)
        XCTAssertTrue(store.isSignedIn); try XCTUnwrap(store.accountSession.user)
        var results: [[String: Any]] = []
        LiveHTTPObserver.reset(maxRequests: config.requestBudget)
        for item in matrix.cases where config.caseIDs.contains(item.id) {
            let birth = try XCTUnwrap(matrix.profiles[item.profile])
            store.state.conversations = []
            try await store.updateBirth(birth)
            var theme = try await store.currentBaziTheme()
            var binding = try store.makeThemeBinding(theme)
            let session = ChatSession(makeClient: { store in
                let backend = try XCTUnwrap(AccountSession.configuration(in: .main))
                let user = try XCTUnwrap(store.accountSession.user?.id)
                let token = try await store.accountSession.aiAccessToken(for: user)
                let transport = URLSessionConfiguration.ephemeral; transport.protocolClasses = [LiveHTTPObserver.self]
                return ChatClient(configuration: try ManagedAI.configuration(supabase: backend), credential: token, session: URLSession(configuration: transport))
            })
            for (index, turn) in ([Turn(question: item.question, kind: item.id == "T07" ? "offline" : "initial")] + item.turns).enumerated() {
                let start = LiveHTTPObserver.exchanges.count
                let actualPreviousFollowUp = store.state.conversations.last?.themeReply?.followUp
                let question = turn.kind == "answer-followup" && actualPreviousFollowUp == .constraints ? "时间不能调整" : turn.question
                if turn.kind == "answer-followup" {
                    XCTAssertTrue([BaziThemeAnswer.FollowUp.goalOrMethod, .constraints].contains(actualPreviousFollowUp ?? .none), "The real model must first have asked the question; do not invent it")
                }
                let oldReceipts = store.state.conversations.last(where: { $0.role == "user" })?.toolReceipts
                let oldCreated = store.natalDossier?.createdAt
                if turn.kind == "stale-birth" {
                    var changed = birth; changed.hour = 6
                    try await store.updateBirth(changed)
                }
                if turn.kind == "refresh-theme" { theme = try await store.currentBaziTheme(); binding = try store.makeThemeBinding(theme) }
                if turn.kind == "offline" { LiveHTTPObserver.interruptNextRequest() }
                session.send(question, mode: "命理", store: store, appendUser: turn.kind != "retry", themeBinding: binding, inheritTheme: false)
                let deadline = Date().addingTimeInterval(240)
                while session.working && Date() < deadline {
                    if session.castConfirmation.pending != nil { session.stop() }
                    try await Task.sleep(for: .milliseconds(100))
                }
                let timeout = session.working
                if timeout { session.stop(); try await Task.sleep(for: .milliseconds(200)) }
                let source = try XCTUnwrap(store.state.conversations.last { $0.role == "user" })
                let reply = store.state.conversations.last { $0.role == "assistant" && $0.date >= source.date }
                let receipts = source.toolReceipts ?? []
                let route = BaziThemeRouting.resolve(question, hasTheme: true, previousFollowUp: actualPreviousFollowUp)
                let expectedFailure = ["offline", "stale-birth"].contains(turn.kind)
                var projectionValid = false
                if let receipt = receipts.first, let context = source.toolContext {
                    projectionValid = (try? BaziLifeThemeCompiler.validateProjection(theme: theme, receipt: receipt, context: context)) != nil
                }
                let protocolValid = reply?.themeReply?.protocolVersion == BaziThemeAnswer.protocolVersion
                    && reply?.themeReply?.sourceUserID == source.id && reply?.themeBinding == binding
                    && reply?.themeReply?.evidenceIDs == theme.evidence.map(\.id)
                    && reply?.text == reply?.themeAction.map { BaziThemeAnswer.render(theme: theme, action: $0, followUp: reply?.themeReply?.followUp ?? .none) }
                    && reply?.themeAction.map { BaziThemeAnswer.allowedActions(question, previousFollowUp: actualPreviousFollowUp).contains($0) } == true
                let replay = try AppStore(context: container.mainContext, scriptURL: script, userID: store.accountSession.user?.id)
                let replayOK = replay.state.conversations.last?.text == store.state.conversations.last?.text
                    && replay.state.conversations.last?.themeReply == store.state.conversations.last?.themeReply
                let trace = Array(LiveHTTPObserver.exchanges.dropFirst(start))
                let answer = reply?.text ?? ""
                let result: [String: Any] = ["id": item.id, "turn": index, "kind": turn.kind, "profile": item.profile,
                    "question": question, "previousFollowUp": actualPreviousFollowUp?.rawValue ?? "none", "route": String(describing: route), "branch": theme.branch.rawValue,
                    "answer": answer, "failure": session.failure as Any? ?? NSNull(), "timedOut": timeout,
                    "expectedFailure": expectedFailure, "calculationOK": projectionValid, "closedProtocolOK": protocolValid,
                    "archiveReplayOK": replayOK, "dossierReused": oldCreated == store.natalDossier?.createdAt,
                    "retryReceiptsUnchanged": turn.kind == "retry" ? receipts == oldReceipts : true,
                    "receipts": try JSONSerialization.jsonObject(with: JSONEncoder().encode(receipts)),
                    "themeReply": try JSONSerialization.jsonObject(with: JSONEncoder().encode(reply?.themeReply), options: [.fragmentsAllowed]),
                    "exchanges": trace]
                results.append(result)
                let all = LiveHTTPObserver.exchanges
                let report: [String: Any] = ["scope": "Real deployed Supabase/DeepSeek + production native closed verifier; synthetic profiles. T07 first-turn interruption is intentionally injected before network; retry is real. Content quality requires separate review.", "requestBudget": config.requestBudget,
                    "modelRequests": all.filter { $0["startedAt"] != nil }.count, "attemptedModelRequests": all.filter { $0["endpoint"] != nil }.count, "transportInterruptions": all.filter { $0["injectedTransportInterruption"] as? Bool == true }.count,
                    "protocolVersion": BaziThemeAnswer.protocolVersion, "contentVersion": BaziLifeThemeCompiler.contentVersion, "results": results]
                try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]).write(to: URL(fileURLWithPath: config.reportPath), options: .atomic)
                print("LIVE_THEME \(item.id) turn=\(index) tools=\(receipts.map(\.name)) projection=\(projectionValid) protocol=\(protocolValid) failure=\(session.failure ?? "none")")
                XCTAssertFalse(timeout); XCTAssertTrue(replayOK)
                if expectedFailure { XCTAssertNotNil(session.failure); XCTAssertTrue(answer.isEmpty) }
                else {
                    XCTAssertNil(session.failure, item.id); XCTAssertFalse(answer.isEmpty, item.id)
                    if route == .theme { XCTAssertTrue(projectionValid); XCTAssertTrue(protocolValid) }
                    if case .clarify = route { XCTAssertTrue(trace.isEmpty); XCTAssertTrue(receipts.isEmpty); XCTAssertNil(reply?.themeBinding) }
                }
            }
        }
    }
}
