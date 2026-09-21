import Foundation
import SujiCore
@main struct Review {
 static func main() throws {
  let original = String(repeating:"字",count:8000)
  let context = try ToolContext(birth:nil,engineRevision:"review",referenceDate:Date(),mode:"起卦")
  var draft = try CastQuestionDraft(call:ChatToolCall(id:"first",name:"setup_qimen",arguments:["question":"short proposed question"]))
  draft.referenceOnly = true
  let confirmation = try ConfirmedCastQuestion(draft:draft,userID:UUID(),context:context)
  let effective = ([original, confirmation.intentMessage.content!]).joined(separator:"\n\n")
  let messages = ReadingVerifier.messages(draft:"仅核对盘面。",history:[confirmation.intentMessage],question:effective)
  let question = messages[2].content!
  print("original accepted bounds: characters=\(original.count), bytes=\(original.utf8.count)")
  print("reviewer retains scope marker: \(question.contains("仅核对盘面，不判断事情成败或日期"))")
  print("reviewer retains corrected question: \(question.contains("short proposed question"))")
 }
}
