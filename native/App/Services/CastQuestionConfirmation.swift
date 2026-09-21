import Foundation
import Observation
import SujiCore

/// A single cancellable handoff from planning to an explicit user action.
@MainActor @Observable final class CastQuestionConfirmation {
    struct Request: Identifiable {
        let id: UUID
        let originalQuestion: String
        let referenceDate: Date
        let drafts: [CastQuestionDraft]
        let reusesOriginal: Bool
    }
    private(set) var pending: Request?
    private(set) var validationFailure: String?
    @ObservationIgnored private var continuation: CheckedContinuation<[ConfirmedCastQuestion], Error>?
    @ObservationIgnored private var accept: (([CastQuestionDraft]) throws -> [ConfirmedCastQuestion])?

    func request(calls: [ChatToolCall], originalQuestion: String, userID: UUID, context: ToolContext, reusesOriginal: Bool = false, referenceOnly: Bool = false,
                 checkScope: @escaping @MainActor () throws -> Void) async throws -> [ConfirmedCastQuestion] {
        try Task.checkCancellation()
        try checkScope()
        guard pending == nil else { throw EngineError.execution("已有占问资料等待确认") }
        let drafts = try calls.map { call in
            var draft = try CastQuestionDraft(call: call); draft.referenceOnly = referenceOnly; return draft
        }
        let id = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                // Cancellation may precede installation of the continuation.
                guard !Task.isCancelled else { continuation.resume(throwing: CancellationError()); return }
                self.continuation = continuation
                self.accept = { edited in
                    try checkScope()
                    guard edited.map(\.proposedCall) == drafts.map(\.proposedCall) else {
                        throw EngineError.execution("确认资料与原问题不一致")
                    }
                    return try edited.map { try ConfirmedCastQuestion(draft: $0, userID: userID, context: context) }
                }
                validationFailure = nil
                pending = Request(id: id, originalQuestion: originalQuestion, referenceDate: context.referenceDate, drafts: drafts, reusesOriginal: reusesOriginal)
            }
        } onCancel: {
            Task { @MainActor in self.cancel(id: id) }
        }
    }

    func confirm(id: UUID, drafts: [CastQuestionDraft]) {
        guard pending?.id == id, let accept else { return }
        do { finish(.success(try accept(drafts))) }
        catch is CancellationError { finish(.failure(CancellationError())) }
        catch { validationFailure = error.localizedDescription }
    }

    func cancel(id: UUID? = nil) {
        guard let pending, id == nil || id == pending.id else { return }
        finish(.failure(CancellationError()))
    }

    private func finish(_ result: Result<[ConfirmedCastQuestion], Error>) {
        let continuation = continuation
        self.continuation = nil
        accept = nil
        pending = nil
        validationFailure = nil
        continuation?.resume(with: result)
    }
}
