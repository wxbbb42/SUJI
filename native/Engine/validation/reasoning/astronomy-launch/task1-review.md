# Independent Task 1 review

2026-09-20. Reviewed `task1-review.diff` (801 lines), current surrounding TS/Swift validation code, Task1 report and plan/global constraints, source archives, and the actual-wire probe/decoder scripts. No implementation changes or full-suite reruns.

## Finding

**[P2] Capacity probe still depends on a prior machine-local temporary directory.**

Path: `native/Engine/validation/reasoning/b5b-launch-acceptance/final-native-capacity-probe.swift:67`.

Trigger: compile/run the archived probe in a fresh checkout with its documented/default data directory or another explicit directory, without `/tmp/suji-b5b-probe` already present. The final report write uses the hardcoded `/tmp/suji-b5b-probe/final-native-capacity-report.json`, ignoring the `folder` resolved on line7. It throws at the end when the directory is absent; if that old temporary directory exists, it silently writes the report outside the requested run directory. This contradicts the claimed reproducible, directory-parameterized acceptance artifact and makes a fresh reviewer depend on prior local state. Write this report using the same `folder` as the captured bodies and expected facts.

A related handoff prerequisite remains: `regenerate-fixtures.cjs` reads `seed-fixtures.json`, but the acceptance directory currently does not contain the seed inputs or final run output. This is recognized as pending final archival in the controller's report, not counted as a separate defect. Final delivery needs the seed matrix (or its deterministic generator), final decoder summary, and reproducible execution instructions.

## Spec verdict

**Production structural change conforms to the selected B5b spec.** The TS layer emits only four declared route types, requires both actual endpoints for inner/outer changes, preserves each duplicate branch object's identity, excludes hidden/static changed projections, and does not merge separately scoped pools. `complete` and `centerPresent` are separate structural fields; the top-level efficacy marker stays false and unresolved conditions remain explicit. Static visible triples and non世 calendar anchors are disclosed structural conventions, not falsely attributed efficacy rules.

Swift reconstructs route pools independently from already authenticated original/changed objects, requires tomb and fanfu validation before triads, and exact-compares the entire expected layer. The upstream fanfu validator binds Najia branches to saved six line values, so a self-consistent rewritten triad cannot substitute a forged branch. Existing prerequisite tests cover the joint-forgery and missing-source cases; source-version/URL/hash and complete layer equality reject the listed corruption cases. Legacy absence is symmetric with source absence and does not turn the new layer into a partial accepted record.

**Source grounding is appropriately bounded.** Actually read the `/19` embedded complete source and relevant literal/root/易林 passages. The explicit initial/third and fourth/sixth moving routes are present; conflicting moving-count and center-present two-member wording are preserved, not repaired into a universal rule. Independently recomputed both directly archived source hashes plus six literal excerpt hashes/Unicode offsets successfully. Calendar-moving extension and all-static observations are clearly disclosed. The product copy does not adopt the source's medical/event anecdotes as verified outcomes.

## Quality / capacity verdict

**No production correctness or losslessness defect found in the reviewed triad and groupRows changes.** One validation-script P2 above should be fixed before final acceptance.

`groupRows` stores an exact per-layout sorted key list and all original values. It operates after existing receipt-ID/fact-layout handling and preserves either the shared-ID or original-ID representation. The local fact identities and full receipts remain unchanged. Added reconstruction tests and the independent JS wire decoder restore the new layout, including each original receipt ID and pointer/value. The batching decision measures the final encoded index when it crosses the cheap size threshold rather than treating raw group size as wire size.

Changing the raw receipt guard from45KB to64KiB and the tool soft headroom guard from29000 to31000 is explicit and justified separately from provider budgets. It is not itself proof of transport safety; actual enforcement remains unchanged at32000UTF16 per message,60000 tool bytes,120000 totalUTF16 including arguments,262144 request bytes. The archived decoder invokes the real backend `providerRequest` and asserts raw request bytes plus exact chart/fact reconstruction. The provided48-case run summary is consistent with that path (max111245 total,30872 message,167891 bytes), but I did not independently rerun that entire matrix and final prompt/source integration changes require the controller's fresh rerun.

Validation approval is therefore **conditional on fixing line67 and completing the already-planned final synchronized matrix/archive**. No broader claim of complete 六爻 efficacy or overall core acceptance is made.
