# F6a independent preparation review

Reviewed the uncommitted first-cast preparation changes against `6f7446679b1ae75ba9716d3cbc772bf421dc635b` on `codex/mingli-validation`. No outstanding finding remains in the bounded reviewed paths after the fix below. This is input-integrity evidence, not acceptance of interpretation outcomes or timing.

## Finding resolved

**F6-REVIEW-1, P2:** The initial `ChatSession` implementation concatenated the original question before confirmed intent. `ReadingVerifier.messages` subsequently applied the 24,000-byte question budget. An accepted original containing 8,000 Chinese characters occupied that entire budget, removing the edited question and reference-only purpose. Ordinary user history messages did not supply an alternate path into verification.

`before-fix-probe.swift` reproduces the former ordering: both the scope marker and edited question are absent from the actual verifier messages. It deliberately constructs that old ordering; it is not the current `ChatSession` path.

The fix places complete confirmations first through `ReadingPrompt.verificationQuestion` (`ReadingContext.swift:80`). `ChatSession.swift:206–208` validates the latest confirmations before using it, and line 201 gives confirmed edits and reference-only scope explicit writer precedence. The independent refreshed probe confirms complete intent survives the actual `ReadingVerifier.messages` call with a 24,000-byte original and one or two methods. Each confirmed question/event reaches its maximum allowed scalar count. BMP characters, supplementary-plane characters, and the larger JSON-escaped control-character representation all pass. The latter is a serialization-budget counterexample, not recommended user input.

## Checks performed

- Inspected complete-batch ID/schema/semantic checks, confirmation identity and order, unique-method preparation, alias reuse, saved-argument reuse, original receipt priority, and original-question timestamp propagation.
- Inspected native gate continuation ownership, stale request IDs, stop/scope checks, persistence-before-calculation ordering, in-memory rollback on confirmation-save failure, and backwards-compatible optional archive fields.
- Independently injected cancellation immediately after preparation and immediately after persistence; neither path executed a tool.
- Independently retried saved edited question/event/subject/horizon with a changed planner call ID; the confirmed arguments were retained without another prompt.
- Ran 100 gate cancellation/confirmation races; every pending request was released. The gate can race to a result, while the outer orchestrator cancellation checks prevent calculation.
- Ran six maximum-size verifier-budget cases and a no-confirmation preservation check. All passed. `git diff --check` also passed at review time.

`probe-results.json` contains the runtime results. `review-results.json` records the finding and limits. `source-hashes.json` records the compiler, probe/executable hashes, inspected file hashes, and every compiled Core source plus the native gate. All 33 compiled source files matched the workspace when recorded.

## Reproduce the independent probes

From the repository root, using the macOS Swift toolchain:

```sh
review_tmp=$(mktemp -d /tmp/suji-f6-review.XXXXXX)
cp -R native/Core/Sources/SujiCore "$review_tmp/SujiCore"
cp native/App/Services/CastQuestionConfirmation.swift "$review_tmp/CastQuestionConfirmation.swift"
swiftc -parse-as-library -emit-library -emit-module -module-name SujiCore -emit-module-path "$review_tmp/SujiCore.swiftmodule" "$review_tmp"/SujiCore/*.swift -o "$review_tmp/libSujiCore.dylib"
swiftc -parse-as-library -I "$review_tmp" -L "$review_tmp" -lSujiCore -Xlinker -rpath -Xlinker "$review_tmp" native/Engine/validation/reasoning/f6-independent-review/probes.swift "$review_tmp/CastQuestionConfirmation.swift" -o "$review_tmp/probes"
"$review_tmp/probes"
```

## Limits

This reviewer did not run SwiftUI/simulator checks, AppStore/SwiftData persistence integration tests, or new live-provider requests. The parent task is running native and UI checks separately; this report does not claim their results. Standalone probes used a fresh Apple Swift 6.4 source build, avoiding the existing Swift 6.3.3 module cache. Source inspection cannot prove generated prose always follows the supplied intent. F6b cross-turn supplementation, event adjudication, timing, and broader core G/H acceptance remain outside this review. Simultaneous workflow, debug UI, UI-test, and project-file edits were not covered.
