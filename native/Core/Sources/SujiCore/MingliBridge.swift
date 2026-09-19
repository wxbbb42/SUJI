import Foundation
import JavaScriptCore

public final class MingliBridge: @unchecked Sendable {
    private typealias Continuation = CheckedContinuation<Data, Error>

    private final class CancellationState: @unchecked Sendable {
        private let lock = NSLock()
        private var cancelled = false

        var isCancelled: Bool {
            lock.lock()
            defer { lock.unlock() }
            return cancelled
        }

        func cancel() {
            lock.lock()
            cancelled = true
            lock.unlock()
        }
    }

    private final class PendingRequest: @unchecked Sendable {
        let id: UUID
        let json: String
        let cancellation: CancellationState
        let continuation: Continuation
        var timeoutWorkItem: DispatchWorkItem?

        init(
            id: UUID,
            json: String,
            cancellation: CancellationState,
            continuation: Continuation
        ) {
            self.id = id
            self.json = json
            self.cancellation = cancellation
            self.continuation = continuation
        }
    }

    private let queue = DispatchQueue(label: "app.suji.mingli", qos: .userInitiated)
    private let requestTimeout: TimeInterval
    private var context: JSContext!
    private var waiting: [PendingRequest] = []
    private var active: PendingRequest?

    public init(scriptURL: URL, requestTimeout: TimeInterval = 30) throws {
        guard requestTimeout.isFinite, requestTimeout > 0 else {
            throw EngineError.invalidBundle("引擎请求超时时间必须大于零。")
        }
        self.requestTimeout = requestTimeout

        let script = try String(contentsOf: scriptURL, encoding: .utf8)
        var failure: String?
        var hasRunFunction = false
        queue.sync {
            context = JSContext()
            context.exceptionHandler = { _, exception in
                failure = exception?.toString() ?? "引擎脚本加载失败"
            }
            context.evaluateScript(script)
            if failure == nil {
                hasRunFunction = context
                    .evaluateScript("typeof SujiNative === 'object' && typeof SujiNative.run === 'function'")?
                    .toBool() == true
            }
            context.exceptionHandler = nil
        }
        if let failure { throw EngineError.execution(failure) }
        guard hasRunFunction else {
            throw EngineError.invalidBundle("本地引擎没有导出 SujiNative.run。")
        }
    }

    public func request(_ json: String) async throws -> Data {
        let id = UUID()
        let cancellation = CancellationState()

        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                let request = PendingRequest(
                    id: id,
                    json: json,
                    cancellation: cancellation,
                    continuation: continuation
                )
                queue.async { [self] in enqueue(request) }
            }
        } onCancel: {
            cancellation.cancel()
            self.queue.async { [weak self] in self?.cancelRequest(id: id) }
        }
    }

    private func enqueue(_ request: PendingRequest) {
        dispatchPrecondition(condition: .onQueue(queue))
        guard !request.cancellation.isCancelled else {
            request.continuation.resume(throwing: CancellationError())
            return
        }
        waiting.append(request)
        startNextIfNeeded()
    }

    private func startNextIfNeeded() {
        dispatchPrecondition(condition: .onQueue(queue))
        guard active == nil else { return }

        while !waiting.isEmpty {
            let request = waiting.removeFirst()
            if request.cancellation.isCancelled {
                request.continuation.resume(throwing: CancellationError())
                continue
            }

            active = request
            installTimeout(for: request)
            invoke(request)
            return
        }
    }

    private func invoke(_ request: PendingRequest) {
        dispatchPrecondition(condition: .onQueue(queue))
        let requestID = request.id
        let resolve: @convention(block) (String) -> Void = { [weak self] value in
            self?.queue.async { [weak self] in
                self?.finishActive(id: requestID, with: .success(Data(value.utf8)))
            }
        }
        let reject: @convention(block) (String) -> Void = { [weak self] message in
            self?.queue.async { [weak self] in
                self?.finishActive(id: requestID, with: .failure(EngineError.execution(message)))
            }
        }
        context.exceptionHandler = { [weak self] _, exception in
            let message = exception?.toString() ?? "引擎异常"
            self?.queue.async { [weak self] in
                self?.finishActive(id: requestID, with: .failure(EngineError.execution(message)))
            }
        }
        context.objectForKeyedSubscript("SujiNative")
            .invokeMethod("run", withArguments: [request.json, resolve, reject])
    }

    private func installTimeout(for request: PendingRequest) {
        dispatchPrecondition(condition: .onQueue(queue))
        let requestID = request.id
        let timeout = requestTimeout
        let workItem = DispatchWorkItem { [weak self] in
            self?.finishActive(id: requestID, with: .failure(EngineError.timedOut(timeout)))
        }
        request.timeoutWorkItem = workItem
        queue.asyncAfter(deadline: .now() + timeout, execute: workItem)
    }

    private func cancelRequest(id: UUID) {
        dispatchPrecondition(condition: .onQueue(queue))
        if active?.id == id {
            finishActive(id: id, with: .failure(CancellationError()))
            return
        }
        guard let index = waiting.firstIndex(where: { $0.id == id }) else { return }
        let request = waiting.remove(at: index)
        request.continuation.resume(throwing: CancellationError())
    }

    private func finishActive(id: UUID, with result: Result<Data, Error>) {
        dispatchPrecondition(condition: .onQueue(queue))
        guard let request = active, request.id == id else { return }
        request.timeoutWorkItem?.cancel()
        request.timeoutWorkItem = nil
        context.exceptionHandler = nil
        active = nil
        if request.cancellation.isCancelled {
            request.continuation.resume(throwing: CancellationError())
        } else {
            request.continuation.resume(with: result)
        }
        startNextIfNeeded()
    }
}

public enum EngineError: LocalizedError, Equatable {
    case execution(String)
    case invalidBundle(String)
    case timedOut(TimeInterval)

    public var errorDescription: String? {
        switch self {
        case let .execution(message), let .invalidBundle(message):
            return message
        case let .timedOut(seconds):
            return "本地引擎在 \(seconds.formatted()) 秒内没有完成。"
        }
    }
}
