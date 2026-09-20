import Foundation
import SujiCore

actor Log {
 var values: [String] = []
 func add(_ value: String) { values.append(value) }
}
@main struct Review {
 @MainActor static func main() async throws {
  let questionID = UUID()
  let context = try ToolContext(birth: nil, engineRevision: "independent-review", referenceDate: Date(timeIntervalSince1970: 1789880000), mode: "起卦")
  let call = ChatToolCall(id: "original", name: "setup_qimen", arguments: ["question":"办公室租约", "questionType":"event"])
  let definition = ChatToolDefinition(name: "setup_qimen", description: "review", parameters: ["type":"object", "additionalProperties":false, "required":["question"], "properties":["question":["type":"string","minLength":1,"maxLength":1600],"questionType":["type":"string","enum":["general","event"]],"subject":["type":"string","enum":["unknown","self"]],"event":["type":"string","minLength":1,"maxLength":200],"timeHorizon":["type":"string","enum":["near","far","unspecified"]]]])
  var draft = try CastQuestionDraft(call: call)
  draft.question = "edited confirmed question"
  draft.event = "signed agreement"
  draft.subject = "self"
  draft.timeHorizon = "far"
  let confirmed = try ConfirmedCastQuestion(draft: draft, userID: questionID, context: context)
  // Cancellation wins after async preparation, even when the callback returns a valid confirmation.
  for stage in ["prepare", "persist"] {
   let log = Log()
   let orchestrator = ToolOrchestrator(maxRounds:1, complete:{_,_ in .toolCalls([call])}, execute:{_ in await log.add("execute"); return ToolExecutionResult(output:"{}")}, prepareCasts:{_ in
    await log.add("prepare")
    if stage == "prepare" { withUnsafeCurrentTask { $0?.cancel() } }
    return [confirmed]
   }, persistConfirmations:{_ in await log.add("persist"); if stage == "persist" { withUnsafeCurrentTask { $0?.cancel() } } })
   let attempt = Task { try await orchestrator.run(history:[],definitions:[definition],context:context,questionID:questionID) }
   do { _ = try await attempt.value; fatalError("cancelled orchestration returned") } catch is CancellationError {} catch { throw error }
   let values = await log.values
   precondition(values == (stage == "prepare" ? ["prepare"] : ["prepare","persist"]))
  }
  // Explicit corrections survive no-receipt retry and a different planner call ID.
  let log = Log()
  let retry = ChatToolCall(id:"retry",name:call.name,arguments:["question":"new planner wording"])
  let orchestrator = ToolOrchestrator(maxRounds:1,complete:{_,_ in .toolCalls([retry])},execute:{ effective in
   precondition(effective.arguments == confirmed.call.arguments)
   await log.add("execute")
   return ToolExecutionResult(output:"{}")
  },prepareCasts:{_ in fatalError("reconfirmation")})
  _ = try await orchestrator.run(history:[],definitions:[definition],context:context,questionID:questionID,confirmedQuestions:[confirmed])
  let executions = await log.values
  precondition(executions == ["execute"])
  // Simulate stop and stale callback before cancellation-handler hop; never save or execute.
  for _ in 0..<100 {
   let gate = CastQuestionConfirmation()
   let operation = Task { try await gate.request(calls:[call],originalQuestion:"original",userID:questionID,context:context,checkScope:{}) }
   while gate.pending == nil { await Task.yield() }
   let pending = gate.pending!
   operation.cancel()
   gate.confirm(id:pending.id,drafts:[draft])
   // The gate itself may race successfully, but the enclosing orchestrator checks Task.isCancelled above.
   _ = try? await operation.value
   await Task.yield()
   precondition(gate.pending == nil)
  }
  // The verifier must receive every full confirmation even at the largest accepted original size.
  let original = String(repeating: "字", count: 8000)
  var budgetResults: [[String: Any]] = []
  for (label, scalar) in [("bmp", "字"), ("supplementary", "𠮷"), ("json-escaped-control", "\u{0001}")] {
   for confirmationCount in [1, 2] {
    var values: [ConfirmedCastQuestion] = []
    for name in ["setup_qimen", "cast_liuyao"].prefix(confirmationCount) {
     var proposal = call; proposal.name = name
     var value = try CastQuestionDraft(call: proposal)
     value.question = String(repeating: scalar, count: 1600)
     value.event = String(repeating: scalar, count: 200)
     value.referenceOnly = true
     values.append(try ConfirmedCastQuestion(draft: value, userID: questionID, context: context))
    }
    let verificationQuestion = ReadingPrompt.verificationQuestion(original: original, confirmations: values)
    let reviewMessages = ReadingVerifier.messages(draft: "仅核对盘面。", history: [], question: verificationQuestion)
    let receivedQuestion = reviewMessages[2].content!
    let whole = reviewMessages.compactMap(\.content).joined(separator: "\n")
    precondition(values.allSatisfy { whole.contains($0.intentMessage.content!) })
    precondition(whole.contains("仅核对盘面，不判断事情成败或日期"))
    budgetResults.append(["encoding":label, "confirmationCount":confirmationCount, "originalUTF8Bytes":original.utf8.count, "receivedQuestionUTF8Bytes":receivedQuestion.utf8.count, "completeConfirmationsRetained":true])
   }
  }
  let unchanged = ReadingPrompt.verificationQuestion(original: "unchanged original", confirmations: [])
  precondition(unchanged == "unchanged original")
  let results: [String: Any] = [
   "status":"passed",
   "cancellationStages":["after-prepare", "after-persist"],
   "savedEditedInputsSurviveRetry":true,
   "gateCancellationConfirmRaces":100,
   "verifierBudgetCases":budgetResults,
   "noConfirmationOriginalUnchanged":true
  ]
  let data = try JSONSerialization.data(withJSONObject:results,options:[.prettyPrinted,.sortedKeys])
  print(String(decoding:data,as:UTF8.self))
 }
}
