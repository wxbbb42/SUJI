# F5 independent review, final verdict

**Cleared for the bounded F5 assertion repair. No remaining blocker in the reviewed scope.** The implementation now declines the date/framing/reference counterexamples below and still recognizes the immutable actual D5 failure. This is not broad Ziwei/core semantic or completion acceptance.

Final independent validation:

- All 39 independent probes pass with zero mismatches (`probe.swift`, `results-final.json`). The original results are retained separately in `results-initial.json`.
- Independent full Core suite: 325 tests passed, 0 failures (`full-core-final.log`). This includes the 12 F5 tests and actual cached natal → timing → compact source → persisted history → retry path.
- Manually checked the actual provider replay and independently matched the dated source facts (`live-replay-review.json`). Archive SHA-256, original draft, writer history and both receipts are unchanged. Exactly two exchanges are recorded: revision then verifier. The revised answer correctly distinguishes actual leap-six day 15/16 from effective month 6/7. Both 田宅宫（巳）斗君, 财帛宫（戌）→子女宫（亥）命宫, 癸未→甲申, and all eight dated monthly transformations match original source receipts.
- Live preservation limit: the revision omits the unrequested common-background paragraph about natal year, active decade and annual background. It preserves separate-layer/no-overwrite wording, but this replay is not evidence of universal prose preservation or accuracy.
- Exact reviewed file hashes are in `final-hashes.json`. Assertion source SHA-256: `ceefc5907be0dd8fb1cf2c39f70de2f36eebfa55f0d291c9f74f6c0818361600`.

## Initial review and resolved findings

Workspace: `/Users/xiaqobenwang/Documents/SUJI`, base `b20b03ce41585042c69cbe1ea5924d5f19e7b3c0`. Reviewed uncommitted F5 assertion, hook, regression tests, and lightly reviewed the added immutable archived-verification replay harness. No product files edited.

## Validation

- Independently ran `swift test --package-path native/Core --scratch-path /tmp/suji-f5-independent-review/build --filter ZiweiMonthlyCalendarAssertionTests`: initial 9 tests passed. Log: `tests.log`.
- Independently compiled all current Core sources plus `probe.swift`; 37 probes, results in `results.json`. 13 mismatches correspond to three blocker categories below.
- Original archived actual writer history yields exactly one repair. Corrected actual-calendar sentence yields no repair. The original bibliography sharing works, source hash/version/index mutation, sparse fields and parsed third-date guards fail closed.
- The opt-in archive replay retains original draft/history and archive hash and calls shipping `ReadingVerifier`; no extra blocker found in its diff. Actual provider replay is owned by the parent, not executed here.

## Resolved blockers

### P2 — Reject date forms that cannot safely inherit the Gregorian header pair

`dates` only parses Chinese 日 and ISO Gregorian-shaped forms, and the global scope guard checks only the resulting set. It silently skips other explicit date labels, and it treats explicit numeric lunar dates as Gregorian. All the following produce one issue with the actual archived history but should produce none:

1. `比较农历2025年8月8日与8月9日的紫微流月。\n\n农历月序号从6月进到7月`
2. `比较2025年8月8日与8月9日的紫微流月。\n\n8月10号：农历月序号从6月进到7月`
3. Same header followed by `8/10：…` or `2025/08/10：…`.

This incorrectly uses August 8/9 Gregorian receipts to authorize correction about a different or unsupported date context. A conservative ambiguity guard suffices; no expansion of accepted date grammar is requested.

### P2 — Preserve report and quote framing reached by the controlled matcher

With the valid header and archived history, `他说：农历月序号从6月进到7月` yields a repair, because the report filter recognizes `有人说` but not ordinary `他说`. `‘结论：农历月序号从6月进到7月；待续’` also yields a repair because curly single quotation is not excluded and the semicolon satisfies the controlled transition terminator. Both are attributed/quoted content, not an affirmative claim by this answer. These are narrow additions to refusal framing, not comprehensive NLU requirements.

### P2 — Require original call/receipt order, global uniqueness, and donor call binding

The current date receipts search all calls and outputs without requiring the call to precede its output. Swapping the archived assistant call message and first tool result still authorizes correction.

For a concrete bibliography donor, `references` only inspects the prefix before the target output. It accepts a donor named `get_domain` even with invalid `domain=bazi`, a donor named `get_ziwei_timing` with empty arguments, an original output before its call, and duplicate donor call/output IDs appended after target outputs. Reproduction is implemented as independent-source cases in `probe.swift`. This violates the requested original receipt bindings and no-duplicate-ID requirement. Verify complete donor args/receipt and global call/output uniqueness plus call-before-output-before-consumer ordering. The parent correctly identified that the initial synthetic positive `get_domain(domain=ziwei)` donor is not a valid production call; the positive fixture is now the full actual first timing receipt under a fresh call ID with its original valid arguments. Limiting accepted donors to complete explicit-date timing receipts is appropriate; no requirement to support other tools is implied.

### Resolution

The final implementation rejects unsupported numeric date scopes and explicit full numeric lunar dates, retains the real archived positive that mentions a numeric lunar year with literal Chinese month/day, and rejects ordinary reported speech plus curly single quotes. Both target and bibliography donor calls/outputs have global uniqueness and original call-before-output ordering. Shared bibliography donors must be a complete explicit-date `get_ziwei_timing` receipt with inline concrete references, the same source/version/index, and an output preceding the consumer. Chains, other tool donors, sparse arguments, malformed/null inline reference values, duplicate IDs and mixed inline/link values fail closed.

## Scope

No expansion of controlled positive grammar and no broad Ziwei/core language acceptance. The original actual failure, source binding, scope refusal and runtime compaction/replay paths are green in this bounded review.
