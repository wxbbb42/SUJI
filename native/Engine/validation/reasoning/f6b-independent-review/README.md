# F6b independent review

Reviewed the explicit original-chart supplement path on `codex/mingli-validation` against base `c27cb423cbb2d99ea7638b18fe7c4a67c1ab8ecd`. The three reproduced findings below are resolved in the reviewed source. No outstanding important finding remains within this bounded review. This does not establish interpretation efficacy, final object selection, event outcomes, or event timing.

## Findings and fixes verified

1. **P2 — stale question-dependent fields passed derived validation.** A real self-health/near chart was supplemented with confirmed parent-health/far inputs. Replacing the reassessment's `yongShen` and `yingQi` (also Liuyao `roleRelations`) with the old fields still passed `CastSupplement.render` for both methods. Liuyao showed the supplemented parent question alongside the old self/世爻 reference; Qimen omitted the required proxy clarification. The new `CastQuestionBinding` independently checks question/category/subject/horizon against candidate mappings, missing context, and Qimen legacy references. Both stale-field grafts now fail.
2. **P2 — cached derived receipts bypassed full source provenance validation.** Setting `provenance.referenceDate` to 2025 while source cast/setup time and context remained 2024 passed Core source selection. A cached derived result with matching corrupt provenance also passed rendering. A fresh engine calculation already rejected this, so retry differed from first execution. Core now requires original provenance time to equal original cast/setup time and the complete versioned calendar policy. Both methods reject the corrupt source before derived reuse.
3. **P2 — scope could change between confirmation and persistence.** Running the actual `ChatSession` and confirmation gate with a minimal persistence stub, confirmation followed immediately by a scope change to an imported notebook copy wrote the old action into the new scope. Before: old account confirmations 0, new account confirmations 1, new scope saved true. After the immediate `checkScope` preceding confirmation persistence: both counts 0, new scope saved false. The store stub preserves UUID/context copies to exercise the case ordinary distinct UUIDs conceal.

`before-core-results.json` and `before-session-results.json` capture the accepting state; `after-core-results.json` and `after-session-results.json` capture rejection after fixes. The two `before-*.swift.txt` files retain the exact relevant production snapshots used for the initial reproduction. They are review data, not compiled project sources.

## Independent validation

- **768 valid combinations pass**: two methods × eight question categories × eight subjects × three horizons × ordinary/reference-only inputs. Each result was produced by the actual bundled engine and accepted by Core with real source linkage and confirmation. The reference-only cases omit event text.
- **18 targeted absent-visible cases pass**: hidden candidate (地雷复, parent), month candidate (地山谦, wife), day candidate (雷地豫, parent), each across all three horizons and ordinary/reference-only inputs. The generator searches fixed six-line patterns and dated engine fixtures; it does not invent calendar facts.
- The bundled `reassess-question` command passes both methods with `Date()`, zero-argument `new Date()`, `Date.now`, and `Math.random` forbidden. No Date construction occurred. This repairs the confidence gap in the original Date.now-only test; the permanent Jest test now traps construction and the calendar function too.
- Final focused `QuestionReassessment.test.ts`: 5 tests pass, including cast/setup/random/current-time/calendar traps.
- After the final localized-error-only change, rebuilt Core and reran the six negative checks, account scope check, and 18 targeted valid cases. The 768-case sweep preceded only this error-message change; binding logic is identical.
- All compiled Core source snapshots and the actual native session/gate snapshots match the final workspace hashes in `source-hashes.json`.

## Reproduce

Run from the repository root on this Mac. The probes intentionally use an isolated fixed scratch path. They require the repository's native bundled engine and Swift toolchain; no credentials or provider requests are used.

```sh
mkdir -p /tmp/suji-f6b-independent-review
cp native/Engine/validation/reasoning/f6b-independent-review/*.swift /tmp/suji-f6b-independent-review/
cp native/Engine/validation/reasoning/f6b-independent-review/*.cjs /tmp/suji-f6b-independent-review/
cp -R native/Core/Sources/SujiCore /tmp/suji-f6b-independent-review/
cp native/App/Services/ChatSession.swift /tmp/suji-f6b-independent-review/
cp native/App/Services/CastQuestionConfirmation.swift /tmp/suji-f6b-independent-review/
swiftc -parse-as-library -emit-library -emit-module -module-name SujiCore -emit-module-path /tmp/suji-f6b-independent-review/SujiCore.swiftmodule /tmp/suji-f6b-independent-review/SujiCore/*.swift -o /tmp/suji-f6b-independent-review/libSujiCore.dylib
node /tmp/suji-f6b-independent-review/engine-probe.cjs
node /tmp/suji-f6b-independent-review/target-fixtures.cjs
swiftc -parse-as-library -I /tmp/suji-f6b-independent-review -L /tmp/suji-f6b-independent-review -lSujiCore -Xlinker -rpath -Xlinker /tmp/suji-f6b-independent-review /tmp/suji-f6b-independent-review/core-probe.swift -o /tmp/suji-f6b-independent-review/core-probe
/tmp/suji-f6b-independent-review/core-probe
swiftc -parse-as-library -I /tmp/suji-f6b-independent-review -L /tmp/suji-f6b-independent-review -lSujiCore -Xlinker -rpath -Xlinker /tmp/suji-f6b-independent-review /tmp/suji-f6b-independent-review/session-stub.swift /tmp/suji-f6b-independent-review/ChatSession.swift /tmp/suji-f6b-independent-review/CastQuestionConfirmation.swift -o /tmp/suji-f6b-independent-review/session-probe
/tmp/suji-f6b-independent-review/session-probe
swiftc -parse-as-library -I /tmp/suji-f6b-independent-review -L /tmp/suji-f6b-independent-review -lSujiCore -Xlinker -rpath -Xlinker /tmp/suji-f6b-independent-review /tmp/suji-f6b-independent-review/sweep.swift -o /tmp/suji-f6b-independent-review/sweep
/tmp/suji-f6b-independent-review/sweep
swiftc -parse-as-library -I /tmp/suji-f6b-independent-review -L /tmp/suji-f6b-independent-review -lSujiCore -Xlinker -rpath -Xlinker /tmp/suji-f6b-independent-review /tmp/suji-f6b-independent-review/target-probe.swift -o /tmp/suji-f6b-independent-review/target-probe
/tmp/suji-f6b-independent-review/target-probe
```

For the original failing state, replace only the scratch `SujiCore/CastSupplement.swift` and `ChatSession.swift` with the archived `before-*.swift.txt` snapshots before compiling. Regenerate fixture JSON after rebuilding the engine because engine revision is source-bound.

## Limits

The account race probe uses real session/gate code and the real engine, but its AppStore/persistence layer is a deliberately small stub. Native SwiftData persistence, zero-calculation retry, cancellation integration, screenshots, and UI assertions belong to the parent task's separate tests and are not claimed here. In particular the parent's first retry wrapper assigned a getter-only export and was ineffective; its corrected whole-object trap is outside this independent probe. No live provider or account request was made. Only the bounded reassessment path and listed source files were reviewed; full domain efficacy and broader G/H acceptance remain open.
