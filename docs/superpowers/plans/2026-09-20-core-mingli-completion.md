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

- [x] A. Liuyao original/changed/hidden objects each carry their own month/day/void/clash/combination facts; Qimen hour void, scoped horse, directional door pressure and star/month relationship; native fact index binds these precisely.
- [x] B. Liuyao returning generation/control, flying/hidden, advance/retreat, conditional dark movement/day break with explicit satisfied/conflicting/unresolved conditions and classical counterexamples.
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
- [x] Run targeted Jest, full Engine typecheck/test/build, Swift Core; push for Core/App/macOS CI. Update evidence report with observed counts and provenance before marking A accepted.

## Later batches

Each of B–F gets a detailed test-first implementation section after its source/code review. The ledger deliberately remains unchecked until the behavior and its counterexamples exist; recording a limitation is not closing it. Report batch progress without marking the overall goal complete.

## Progress evidence

2026-09-20 Batch A implemented; full local checks: 609 Engine tests, 226 Swift Core tests including 13 Node/JSC parity fixtures, 14 backend tests, typecheck/build/native-only check pass. Independent code review found and then cleared aggregate verifier capacity and nested metadata shape defects; fixes had observed RED/GREEN tests. Source registry: 50 sources / 56 claims. Remote exact-commit CI remains pending before A acceptance. See `docs/mingli/validation/core-facts-acceptance-2026-09-20.md`. No completion claim for B–H.

Batch A accepted after remote run [35491117669](https://github.com/wxbbb42/SUJI/actions/runs/35491117669) succeeded for exact head `0c3ae1fe418569c3f88f82f91cbd382d5d335d98`: engine, swift-core, native-app all green.

## Batch D1 — prioritize independently demonstrated Ziwei error

The fresh read-only review found a P1 late-zi calendar inconsistency. This takes priority over adding Liuyao rules. Selected policy remains full 23:00 rollover; no universal school claim.

- [x] Observe RED for independent leap-15/16, ordinary month-end and lunar-year-end expectations, original birth identity, lunar input and the last accepted civil date.
- [x] Normalize the effective solar date before iztro and use early-zi index0. Preserve original civil birth identity. The raw astrolabe uses the effective lunar year consistently.
- [x] Return target and actual trine/opposite palace facts, keeping empty resident-star arrays unchanged and borrowed-reference provenance explicit. Test reordered arrays, empty/nonempty and sparse legacy payloads.
- [x] Return each natal transformation's source stem, star, target palace and source ID. Archive the read edition and explicitly record Ren 天府/左辅 and leap-month differences. Fix the old test's overstatement of agreement.
- [x] Index star brightness, body/empty flags, scoped transformations, methods and sources in standalone and domain tools. Add named-palace binding and wrong-palace/transit/negation counterexamples.
- [x] Finish D1 independent rereview, full Core/Engine verification, push and exact-head CI.
- [x] D2: independent nominal-age/decadal vectors; separate annual projection from natal cache, explicit school provenance and boundary tests. No borrowing Bazi timing as Ziwei timing.
- [ ] D3: interpretation evidence for transformation scope, empty-palace overclaims and dynamic layers, with actual end-to-end cases. Palace-stem flying and flow-month remain separate scope decisions requiring grounded rules.

Liuyao B source reread also uncovered a research-excerpt bug: prior root-page chapter28/32 excerpts hit the table of contents. `core-rule-sources.json` records actual chapter offsets/hashes from the same full-source hash. This corrects evidence extraction, not the still-pending B implementation.

## Batch D2 — cached decades and separate temporal layers

Selected policy: modern iztro-default decade convention, first decade at 命宫 and bureau-number nominal age, ten years per palace, 阳男阴女顺 / 阴男阳女逆. Cite the pinned engineering implementation; the Quanshu excerpt supports direction only, not the complete modern convention. Annual year and nominal age turn at lunar New Year, with the same complete 23:00 rollover as natal. Do not reuse Bazi 立春 or exact 起运 dates.

- [x] RED/GREEN: independently written 2024甲男/女火六 and 2023癸男/女水二 decade vectors, 丑宫干 boundary, before birth / before first decade / exact decade transitions.
- [x] Store twelve fixed decades in the natal snapshot. Dynamic projection reads only the snapshot; no natal recomputation or mutation.
- [x] Add `get_ziwei_timing`, defaulting to the question instant; optional explicit Gregorian `date` uses Beijing noon and declares it. Return lunar-year age, active decade, 太岁所在本命宫, separately scoped annual and decade-stem transformations. Keep natal stars unchanged; do not claim 小限、流月、流曜 or palace-stem flying.
- [x] RED/GREEN: before/after lunar New Year including 23:00; LiChun counterexample; same star 生年化科 and 流年化忌; minor-star 化科; invalid dates; persisted snapshot and timezone independence.
- [x] Native allowlist, scoped scalar evidence index, real tool transport/replay and Node/JSC parity. Source archive/registry and scope descriptions updated.
- [x] Independent review, full local checks, push and exact-head CI.

D2 local acceptance: 636 Engine /235 Swift Core /15 backend tests; independent review and deployed authenticated 9-tool smoke passed. Native mixed-tool replay35,513bytes; no natal recalculation. Commit and exact-head CI pending. D3 and core B/C/E/F remain open.

D1 remote acceptance: run35492092036 succeeded (engine, swift-core, native-app) at exact f59facfddaae3887dcb71063fa9eb16357ac8995. D2 accepted: 5857c5ebe520f7fc590e0e7153c60af12bcad95e remote hash matched; run35492560471 succeeded in engine, swift-core and native-app.

## Batch B — conditional Liuyao relationship chains

Source choice: read 增删卜易 electronic chapters17/20/22 and root chapters28/29, archived in `core-rule-sources.json`. Chapter29 lists seven advance pairs; do not add 戌丑 under that source. Preserve independent object contexts from A.

- [x] Test first: 申月戊午日遯→姤, changed亥水 returns control to original午火 despite午临日; direction is changed→original, never every changed line attacking all originals.
- [x] Test all seven forward/reverse branch pairs; retain structural进退 even when changed line is empty/broken, and distinguish when it can apply from the mere match. Exclude unlisted戌丑 and stationary changed-palace decorations.
- [x] Test 姤二亥飞生寅伏 / 遯初辰飞克子伏. Return identity, direction and separate enabling/opposing conditions including day/month/moving generation, clash/control of flying, and flying emptiness/month break. Comprehensive strength and 墓绝 must not be fabricated from monthState.
- [x] Test 静旺日冲 / 静弱日冲, moving-line exclusion, 冲空, and 寅月己未日坤→师: month克丑 plus同类日扶 coexist. Return competing conditional暗动/日破 cases; do not classify by monthState alone or invent a net-strength threshold.
- [x] Bind each condition to precise original/changed/hidden fact pointers. Include sources once, keep true/false/unresolved separate, preserve incomplete adjudication rather than hide it in a score.
- [x] Native index and actual cast transport/replay; check limits before accepting richer results. Independent review, source registry, full checks and exact-head CI.

This batch closes structural and conditional rule gaps only; question-dependent final取用 and event timing remain E, interpretation claims F. Additional 三合、六合六冲、反吟伏吟、墓绝 require their own grounded decisions before final core acceptance.

B local verification: 645 Engine /237 Core /15 backend tests pass,18 Node/JSC fixtures. Exhaustive 4,096 casts validate 12,288 returning and3,584 flying-hidden directions. Lossless verifier prefixes reduce the large 大畜+奇门 case from132,867 to110,541 UTF-16 units. Actual live/replay test found mismatched60KB/40KB receipt budgets; both now share the existing60KB live limit, backend limits unchanged. See `docs/mingli/validation/liuyao-conditional-2026-09-20.md`. Independent review cleared, including repeated cached-chart message count. Push/exact-head CI remain pending.

## Batch C — rescue and support conditions

Read archived Ziping abstract chapters and foundations (hashes in returned source records). Independent review demonstrated: 月癸制年丁 can itself be combined/controlled by 时戊; 印 can constrain 食神; same rescue stem names conceal different roots; 月午日子冲 may coexist with 日子时丑合. The explicit 年丁月癸时戊 example disproves treating the current adjacency-only scan as a universal rule. Preserve the existing heuristic summary for compatibility, and add a separately scoped conditional assessment; no new net-strength score or automatic success claim.

- [x] RED/GREEN for seven independent literal vectors, including remote rescue and non-universal competing-pair interpretation.
- [x] Bind candidate/helper identities to stem or hidden-stem column. Return exact/same-element roots separately from generating support, month state, incoming control/combination and intermediary positions. Keep calendar facts distinct from outcome.
- [x] Return direct rescue and helper-protection candidates, including remote pairs as unresolved. Preserve every candidate and opponent, not first-match verdict. Associate each with its own support and constraints.
- [x] Return monthly clash pairs plus precise combination/mediation candidates and obstruction facts; do not erase the clash or call partial三合 transformed.
- [ ] Source-grounded native indexing and framework reading, real transport/replay, independent recheck, full checks and exact-head CI.

B accepted: exact5134662ffd9c7a658ab5c3aff09b0cfb8ba47a26 pushed; run35493371399 succeeded in engine,swift-core,native-app.

C local verification: 654 Engine /240 Swift Core tests pass,18 fixtures, typecheck/build/native-only/diff pass. Independent source review cleared. Native review caught an empty-list evidence omission; actual-chart RED/GREEN now preserves the empty rescue list in both catalog and persisted reading. Exact-head CI pending; global competition and final efficacy remain separate unresolved scope.
