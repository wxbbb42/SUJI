# Core Mingli Completion Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to execute and verify each batch; the user has already authorized the roadmap and implementation.

**Goal:** Close the recorded core-rule gaps in Bazi, Ziwei, Liuyao and Qimen before assessing Qizheng Siyu or an independent lunar-mansion module.

**Architecture:** Keep deterministic chart facts, conditional rule findings and question-dependent adjudication separate. Each new rule carries a versioned source and scope; native interpretation evidence must resolve to the exact returned object. Fixed natal charts remain account-scoped cached dossiers, while casts and temporal layers remain question-specific.

**Tech Stack:** TypeScript/Jest engine, Swift Core/XCTest, SwiftUI/JavaScriptCore, existing Supabase/DeepSeek.

**Spec:** `docs/mingli/validation/professional-audit-2026-09-20.md` and the user's approved core-first roadmap.

## Global constraints

- Preserve login, required birth data, natal caching, account isolation and stable cast receipts.
- No new systems or zodiac module during core acceptance. No invented ancient Gregorian dates or biography fitting.
- A structural match is not a prediction or adjudicated strength; source uncertainty remains explicit.
- Independent expected tables/hand calculations, counterexamples and evidence-binding tests are required; runtime parity is additional integration evidence only.
- Commit/push to `codex/mingli-validation`, verify the exact remote commit in CI. Local syntax parsing is not an iOS build.

## Acceptance ledger / dependency order

- [ ] A. Liuyao original/changed/hidden objects each carry their own month/day/void/clash/combination facts; Qimen hour void, scoped horse, directional door pressure and star/month relationship; native fact index binds these precisely.
- [ ] B. Liuyao returning generation/control, flying/hidden, advance/retreat, conditional dark movement/day break with explicit satisfied/conflicting/unresolved conditions and classical counterexamples.
- [ ] C. Bazi rescue damage, support/root/season context and branch rescue conditions; do not replace unresolved global competition with a score.
- [ ] D. Fresh Ziwei review and closure of demonstrated gaps: school policy boundaries, palace/star/transform relationships and natal versus dynamic layers; independent boundary and structural examples.
- [ ] E. Question-object selection and conditional timing: candidate identities, selection/exclusion evidence, missing relationship/event/time scope, conflicts retained; no first-candidate-as-verdict behavior.
- [ ] F. Interpretation acceptance: fact references, rule provenance, incorrect-object/overclaim counterexamples, targeted end-to-end readings. Persist actual failures and residual limitations.
- [ ] G. Full Engine/Core/native checks, regenerated bundle, commit/push and exact-head CI verification.
- [ ] H. After A–G acceptance, separate feasibility reports for Qizheng Siyu and independent lunar mansions: school, calculations, sources, shared infrastructure, use cases and cost; no premature implementation.

## Batch A — explicit divination facts

**Files:** `native/Engine/src/divination/{types.ts,HexagramEngine.ts,lineContext.ts}`, `native/Engine/src/qimen/{types.ts,QimenEngine.ts,facts.ts}`, their `__tests__/CoreFacts.test.ts`, `native/Core/Sources/SujiCore/ReadingVerificationEvidence.swift`, `native/Core/Tests/SujiCoreTests/DivinationEvidenceTests.swift`, tool descriptions, grounding claims and generated bundle.

**Interfaces:** `lineContext(ganZhi, element, month, day, voidBranches)` returns `LineContext`; every original/changed/hidden object owns one. `qimenFacts(hourGanZhi, monthGanZhi, palaces)` returns scoped hour void, hour horse and per-palace door/star facts. Source definitions are returned once per chart and referenced by stable IDs. No function changes birth records or recomputes natal charts.

- [x] Write failing engine tests with the four Liuyao coordinate examples recorded in the professional audit: original nonvoid/changed void; changed month break; hidden month/day clash; original month combination. Verify that adding fields fails with missing-value assertions.
- [x] Add the minimum fact implementation and retain legacy original-line boolean fields from the same computed context. Test all original/changed/hidden objects against independently written pair tables and month/day five-element tables.
- [x] Write failing Qimen tests using hand charts A–D from the audit: hour void branches/palaces, hour horse, D door-pressure palaces `[1,2,3,6]`; include palace-controls-door as a negative example, half/full emptiness and no center duplication.
- [x] Implement scoped facts. Obtain the solar-term month from the physical instant, not the apparent-clock projection. Check nine-star/month states against a fixed independent five-by-five table; include 天芮土 in 酉月=旺, not ordinary month-strength 休.
- [x] Add native fact-index tests for changed/hidden pointers, false booleans, sparse optional legacy payloads, nonsequential palace arrays, source/version fields, cast month/day and method metadata. Add only allowlisted scalar/array facts; never index arbitrary model-generated prose as facts.
- [ ] Run targeted Jest, full Engine typecheck/test/build, Swift parse; push for Core/App/macOS CI. Update evidence report with observed counts and provenance before marking A accepted.

## Later batches

Each of B–F gets a detailed test-first implementation section after its source/code review. The ledger deliberately remains unchecked until the behavior and its counterexamples exist; recording a limitation is not closing it. Report batch progress without marking the overall goal complete.

## Progress evidence

2026-09-20 Batch A implemented; full local checks: 609 Engine tests, 226 Swift Core tests including 13 Node/JSC parity fixtures, 14 backend tests, typecheck/build/native-only check pass. Independent code review found and then cleared aggregate verifier capacity and nested metadata shape defects; fixes had observed RED/GREEN tests. Source registry: 50 sources / 56 claims. Remote exact-commit CI remains pending before A acceptance. See `docs/mingli/validation/core-facts-acceptance-2026-09-20.md`. No completion claim for B–H.
