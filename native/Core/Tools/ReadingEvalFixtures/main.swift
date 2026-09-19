import Foundation
import SujiCore

// Synthetic, opt-in evaluation fixture. No app data or credentials are read.
if CommandLine.arguments.contains("--guard") {
    let input = try JSONSerialization.jsonObject(with: FileHandle.standardInput.readDataToEndOfFile()) as! [String: String]
    let output: [String: Any] = ["issues": ReadingVerifier.deterministicIssues(in: input["draft"] ?? ""), "allowsQimen": ReadingIntent.allowsQimen(input["question"] ?? "")]
    FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject: output, options: [.sortedKeys]))
    exit(0)
}
let now = ISO8601DateFormatter().date(from: "2024-02-04T04:00:00Z")!
let fixture: [String: String] = [
    "version": ReadingPrompt.version,
    "mingli": ReadingPrompt.instruction(tone: "温暖", mode: "命理", referenceDate: now, hasBirth: true),
    "noBirth": ReadingPrompt.instruction(tone: "温暖", mode: "命理", referenceDate: now, hasBirth: false),
    "cast": ReadingPrompt.instruction(tone: "温暖", mode: "起卦", referenceDate: now, hasBirth: false),
    "planner": ReadingPrompt.planner,
    "writer": ReadingPrompt.writer,
    "verifier": ReadingVerifier.instruction,
    "revision": ReadingVerifier.revision,
]
let output = try JSONSerialization.data(withJSONObject: fixture, options: [.sortedKeys, .prettyPrinted])
FileHandle.standardOutput.write(output)
