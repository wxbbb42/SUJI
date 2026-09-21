# Three adjudication follow-ups — 2026-09-21

Continuation from `codex/mingli-validation` at `1a55f46809d16eddf2537cb891ec25ed0d40f800`. This evidence covers actual source-scoped Liuyao event assessments, Qimen specialized selection and Bazi rescue dependencies, plus their native interpretation, persistence and delivery. It does not prove real-world predictive validity or complete the unresolved traditional branches.

See `docs/mingli/validation/adjudication-integration-2026-09-21.md` and its three linked specialist reports for rules, positive/negative/conflict cases and remaining boundaries. The previous `adjudication-2026-09-21/` archive is immutable historical evidence.

## What the checks establish

- `verify-sources.mjs` independently checks 40 shipped source references against actual archived raw-byte hashes and literal normalized quotes. These are electronic witnesses, not print-edition collation.
- `divination-capacity-fixtures.cjs` recomputes 48 paired inputs, five maximum timing windows, and all 12 explicit specialized selections combined with timing: 65 pairs / 130 full charts. Coin injection is isolated test scaffolding, not an independent chart oracle.
- `divination-native-capacity-probe.swift` checks real ToolOrchestrator delivery, receipts, JSON restoration, replay/retry, Liuyao and Qimen reference rendering, exact evidence paths, source authentication, and actual ChatClient HTTP encoding.
- `astronomy-native-probe.swift` checks 16 native natal requests, including five valid synthetic births spanning Bazi unresolved/available/blocked and selected/rooted competition outcomes.
- `final-wire-decoder.mjs` is an independent JavaScript inverse and invokes the real backend `providerRequest` and body limits. It compares every complete chart and every `(toolCallID, factKey, pointer, value)` tuple to the full expected originals. It supports historical reference-index v1 and current v2, and expands source dictionaries before verifying complete source SHA256.
- Reference-index v2 stores node pairs and four-column patterns flat without changing indices, values or path semantics. The existing value codec also shares repeated short paths and repeated source metadata. Original sources, false/null/empty values, candidate order and object identity are preserved. Missing dictionaries cannot become trusted legacy evidence.
- The stress cases use 200-character call IDs, control-character events, an 8,000-character user question, full production prompts and a long draft. Request capture uses URLProtocol and placeholder test credentials; no model call or personal record is sent.

## Reproduce archived captures

From the repository root:

```sh
node native/Engine/validation/reasoning/adjudication-followup-2026-09-21/verify-sources.mjs
mkdir -p /tmp/suji-followup-reproduce
tar -xzf native/Engine/validation/reasoning/adjudication-followup-2026-09-21/final-capacity-evidence.tar.gz -C /tmp/suji-followup-reproduce
node native/Engine/validation/reasoning/adjudication-followup-2026-09-21/final-wire-decoder.mjs /tmp/suji-followup-reproduce/divination
node native/Engine/validation/reasoning/adjudication-followup-2026-09-21/final-wire-decoder.mjs /tmp/suji-followup-reproduce/astronomy
```

`final-capacity-manifest.json` contains archive, member and production/probe SHA256 values. Intermediate duplicate encodings and failed captures are excluded from the archive. RED regression logs are separate and explicitly named.

## Recompute with current code

Install `native/Engine` dependencies and build its bundle first; use Xcode Swift/JavaScriptCore. The generator uses only the first 48 archived inputs, so reruns do not duplicate the additional cases.

```sh
npm run build --prefix native/Engine
node native/Engine/validation/reasoning/adjudication-followup-2026-09-21/divination-capacity-fixtures.cjs /tmp/suji-followup-reproduce/divination
swiftc -O -parse-as-library native/Core/Sources/SujiCore/*.swift native/Engine/validation/reasoning/adjudication-followup-2026-09-21/divination-native-capacity-probe.swift -o /tmp/suji-followup-divination
TZ=America/Los_Angeles /tmp/suji-followup-divination /tmp/suji-followup-reproduce/divination
node native/Engine/validation/reasoning/adjudication-followup-2026-09-21/final-wire-decoder.mjs /tmp/suji-followup-reproduce/divination
swiftc -O -parse-as-library native/Core/Sources/SujiCore/*.swift native/Engine/validation/reasoning/adjudication-followup-2026-09-21/astronomy-native-probe.swift -o /tmp/suji-followup-astronomy
TZ=America/Los_Angeles /tmp/suji-followup-astronomy /tmp/suji-followup-reproduce/astronomy
node native/Engine/validation/reasoning/adjudication-followup-2026-09-21/final-wire-decoder.mjs /tmp/suji-followup-reproduce/astronomy
SUJI_LIUYAO_CAPACITY_MATRIX=/tmp/suji-followup-reproduce/divination/fixtures.json TZ=America/Los_Angeles swift test --package-path native/Core
python3 native/Engine/validation/reasoning/adjudication-followup-2026-09-21/package-evidence.py /tmp/suji-followup-reproduce
```

Repack only after both native and independent decoder runs succeed; the manifest identifies capture sources, not a later report-only commit.

## Failures fixed during integration

- `selectedYong` contradiction/missing-field mutations initially passed the standalone native rescue trace. The trace now binds the conditional and adjudicated yong; actual JSC catalog/full/brief rejection and old receipts remain covered.
- Reference-only Liuyao initially displayed event direction. First native reading, saved retry and original-chart supplement now respect that confirmation while retaining and validating the full stored report.
- Newly derived reassessment tools were missing complete fact and source-directory projection. They now preserve their own actual call identity throughout replay and review.
- A short-path value-sharing test failed before the codec recognized repeated smaller paths. A 65-pair real request check then exposed a separate total-context failure (122,974 vs 120,000). The permanent maximum-window/selection regression independently restores all facts and requires 2,500 units of headroom. Source sharing plus reference-index v2 resolves it without raising any production budget.
- Historical Fanfu/Triad test fixtures had to remove both new event report and source to actually represent legacy archives. Existing rejection assertions and production validation were retained.

## Final frozen-code results

Engine 77 suites / 1,016 tests; Core 446 tests (America/Los_Angeles, matrix enabled, no skips); App/UI 45 tests; backend 15; fixture comparator 7; typecheck and SwiftUI-only guard passed. Rebuilding bundle, 25 runtime parity fixtures and notices reproduced identical bytes. Source audit: 40 references, no failures.

All 65 paired requests passed native checks and the independent real-backend decoder: 130 complete charts, 126,050 exact fact tuples, 69 authenticated source directories. Max total 116,952 UTF-16; max HTTP 179,657 bytes; max message 31,048 UTF-16; max combined tools 59,450 bytes; max stored receipt 53,907 bytes. All 16 natal requests passed with 6,966 exact tuples; max total 81,958 UTF-16, body 122,651 bytes and message 28,975 UTF-16. No production limit changed.

`selection-confirmation.png` and `selection-reference-reading.png` are inspected screenshots from the final successful simulator run; `app-summary.json` records 45 passed / zero failed / zero skipped. All dates and questions in these test captures are synthetic.
