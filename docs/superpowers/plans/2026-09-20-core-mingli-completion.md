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
- [x] C. Bazi rescue damage, support/root/season context and branch rescue conditions; do not replace unresolved global competition with a score.
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
- [x] D3: interpretation evidence for transformation scope, empty-palace overclaims and dynamic layers, with actual end-to-end cases. Palace-stem flying and flow-month remain separate scope decisions requiring grounded rules.

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
- [x] Source-grounded native indexing and framework reading, real transport/replay, independent recheck, full checks and exact-head CI.

B accepted: exact5134662ffd9c7a658ab5c3aff09b0cfb8ba47a26 pushed; run35493371399 succeeded in engine,swift-core,native-app.

C local verification: 654 Engine /240 Swift Core tests pass,18 fixtures, typecheck/build/native-only/diff pass. Independent source review cleared. Native review caught an empty-list evidence omission; actual-chart RED/GREEN now preserves the empty rescue list in both catalog and persisted reading. Exact-head CI pending; global competition and final efficacy remain separate unresolved scope.

## Batch E1 — Liuyao object candidates and conditional timing

- [x] Explicit question subject/event/time-horizon metadata. Preserve missing/contradictory context; gender alone never determines relationship roles. No arbitrary first candidate or fixed score.
- [x] Original/hidden/month/day candidates retain identity and selection reasons; changed-line matches remain dependent references, not freely substituted primary objects. Retain all same-role lines and exclusion reasons.
- [x] Source-bound conditional static/moving, month-break, void and combination timing triggers. Return branch conditions only, shared unresolved prerequisites and each candidate's opposing facts. No Gregorian prediction or auto-recast; hidden/calendar objects do not inherit original-line motion.
- [x] Independent literal tables, all64 gua candidate membership, ambiguity/代占/hidden/changed counterexamples; native allowlist, transport/replay/capacity and review.

E2 remains Qimen question objects and conditional timing. D3/F and other grounded core-scope decisions remain open after E1.

C accepted: 9c0f578acfd80259ba18de9c907a0e795dc90303 matches remote; run35493977209 passed engine, swift-core and native-app. This accepts the documented conditional scope, not comprehensive global efficacy adjudication.

E1 local validation: 666 Engine /241 Swift tests. Independent reviewer cleared object/trigger rules and UI/capacity fixes. Real DeepSeek replay failed interpretation and safely fell back; archived in core-e1-results/review.json. This does NOT accept F. Final dynamic adjudication and cross-turn clarification are still open. Exact-head CI pending.

## Batch F1 — prioritize observed live calendar hallucination

- [x] Bind Liuyao month/day/hour and Qimen day/hour/month to their own explicit cast context; wrong system, negation and ambiguous multi-tool values must not authorize corrections.
- [x] Local deterministic correction for narrowly bound calendrical mismatches, including the actual E1 pre-LiChun failure; source/tool values only, no separate calendar recomputation.
- [x] Counterexample tests, real provider replay and full validation (live interpretation still failed; preserved as evidence). Fine-grained line relations and Ziwei D3 remain next.

E1 accepted within its documented calculation scope: `6fd9d92163fb82b82577d18e61e8fce183d28516` matches remote. [Run35494700577](https://github.com/wxbbb42/SUJI/actions/runs/35494700577) passed engine, swift-core and native-app. Live prose remains unaccepted.

F1 local scope accepted: 250 Swift Core tests, nine targeted tests, independent39 assertions; final real replay still fact-fallback. See [F1](../../mingli/validation/divination-calendar-reading-2026-09-20.md). No broad interpretation acceptance. Exact-head CI pending.

## Batch D3 — scoped Ziwei interpretation assertions

- [x] Bind each transformation to its explicit natal/annual/decadal scope, named star, actual target palace and source identity. Named star brightness is a different field; never borrow another star or palace.
- [x] Detect only explicit current-scope literal mismatches. Mixed correct layers coexist. Negations/questions/reported/hypothetical/old values and conflicting tool outputs do not authorize a rewrite.
- [x] Empty main-star palace does not erase actual minor stars; demonstrate with returned arrays. Preserve opposite-palace reference rather than move stars into the empty palace.
- [x] Test independent literal contradictions, real native natal+timing outputs and model replay; retain failures. Review, full validation, push and exact-head CI before accepting D3.

F1 remote accepted in its narrow scope: exact `4da3a3b85ebac190aa9db29f28f1dcf4aa287600` matches remote; run35495103778 passed engine, swift-core and native-app.

D3 local:258 Core tests including8 scoped regressions. Third live run was falsely accepted with wrong source-stem comparison and a lunar-year denial; raw report retained and both errors reproduced in permanent verifier regression. Final delivery replay agrees with three actual receipts,4 real provider requests. See `docs/mingli/validation/ziwei-reading-scope-2026-09-20.md`. Independent final rereview cleared; exact-head CI pending; broad D/E/F acceptance remains open.

## Batch E2 — Qimen question objects and conditional timing (next)

Read the actual Dunjia Yanyi and Daoisms finance pages; neither qualifies as a complete, version-selected modern object/timing rulebook. Do not cite a search-engine AI summary as a classical quotation. See `docs/mingli/validation/qimen-selection-source-review-2026-09-20.md`.

- [x] E2a: explicit subject/event/horizon, all candidate identities including hosted stems and甲旬仪, missing context and per-object fact pointers. Distinguish product initial-reference convention from classical rule provenance; no first candidate as adjudication.
- [ ] E2b: select a readable, explicit timing convention; encode supported/opposing/unresolved conditions and object/source identity. Do not transplant Liuyao timing or infer a date from a palace number. No precise deadline without an adjudicated event and time unit.
- [ ] Independent fixed vectors and ambiguity/代占/hosted-counterexamples; native allowlist, actual transport/replay/capacity, semantic review and remote checks.

D3 remote accepted within the documented bounded assertion scope: exact `10ab339a21ecef69211b3a8c53189362c75f1a72`, run35495982293 passed engine, swift-core and native-app. This does not complete broader D/E/F/G or authorize extensions.

E2a local:676 Engine /263 Core tests; identity/source/empty/null transport, multi-receipt lossless index and capacity checks pass. Added explicit fixed-Kun earth hosting, distinct from rotating Tianqin sky hosting; independent2,922-chart /12,962-pointer probe preserves all legacy geju. Actual DeepSeek reports include zero-receipt false acceptance, omitted sky-host stem, then wrong earth palace (戊 said4, actual3). Reports remain immutable; E2a structure is ready for remote checks, F is not accepted. Next F3 must bind direct/reverse plate assertions and new explicit hosted labels, reproducing the real false acceptance. See `docs/mingli/validation/qimen-question-objects-2026-09-20.md`.

E2a accepted in that structural scope: exact `49aed08b04b3c054aa6908b0800c5b23ed719ec8`, run35497388190 all3 jobs green.

## Batch F3 — bound Qimen plate assertions

- [x] Archived real false acceptance reproduces wrong earth palace. Direct/reverse stem assertions use each receipt's field; hosted-earth and hosted-sky labels separate.
- [x] Correct hosting, sparse legacy, reordered palaces, conflicting receipts, questions and full-sentence framing counterexamples; local guard before model review. No calendar or chart recalculation.
- [x] Independent final review, full checks, push and exact-head CI.

`core-f3-results.json` still fails broader interpretation: correct plate positions but an incorrect day/hour identity summary and user-picked palace advice. No further prompt reroll to claim accuracy. Next F4: compile critical Qimen fact/reference sections locally from original receipts, preserving identity, qualification, source and absence; reuse the proven claim approach where suitable. Before changing delivery, specify tests for actual failures, conflicting/sparse/cross-context receipts, source identity and cached original casts. E2b and F2 Liuyao source/object errors remain open.

F3 remote accepted in its bounded assertion scope: exact `e8a1a523f9fdabff5e28f87b5c57fc21733150c9`, run35497659888 passed engine, swift-core and native-app. Broader live interpretation remains unaccepted.

## Batch F4 — source-bound Qimen reference delivery

Decision: compile complete reference sections locally for a Qimen-only tool request, following the existing Bazi evidence-bound path. A fixed short report is preferable to asking a model to select/rewrite these mandatory facts. The planner still extracts the explicitly supplied question context; calculations and persisted original receipts remain unchanged. Mixed-system questions stay outside this batch and cannot be silently reduced to Qimen.

- [x] RED/GREEN against actual chart A and甲-carrier chart B: retain day/hour IDs independently, every plate occurrence, center record versus effective sky, both hosted stems, category-reference absence, product-source scope, missing question context and unresolved timing. No user-selected palace as an adjudication.
- [x] Every section carries exact receipt ID, JSON pointers and values. Validate occurrence pointers against the matching palace/symbol and expected plate; reject conflicting, stale, sparse or unsupported-version receipts rather than fabricate prose. Reordered arrays preserve identity; retries use the original receipt.
- [x] Integrate the same compiler in shipping ChatSession and the real Swift evaluation harness. An unavailable source-bound report yields an explicit incomplete-data response, not free-prose invention. Preserve cancellation, account/birth context checks and persisted receipts. No UI redesign or new natal calculation.
- [x] Test the actual orchestration/retry path, compile more than one question category, independently review, run full Core/native checks, and archive a real provider planning+tool+local-render pass. Explicitly report that this replaces model prose for this scope; it does not prove model factual accuracy or complete event adjudication.
- [x] Commit/push and verify exact-head CI. Broader D/E/F/G remain open until their own requirements pass.

F4 local: 11 new tests,279 total Core; independent73 renderer/18 actual intent-gate cases pass. Final real provider trial:6 calls,2 valid local reference reports (including甲午 at .789 subsecond) and honest zero-receipt failure response. One planner omitted explicitly supplied event; preserve this as context-extraction work still open. See `docs/mingli/validation/qimen-reference-delivery-2026-09-20.md`. Accepted remotely at d35fc865283a3a7c4ed3fcbadc02e6d16e5d28a1, run35498534151: engine, swift-core, native-app all success. E2b source review continued with Yuanlingjing and a modern repost; incompatible chart conventions and contradictory passages are recorded, not adopted or counted as rule completion.

## Batch B2 — whole-hexagram combinations/clashes and moving branch returns

Read ch19/20 from the immutable `core-rule-sources.json` archive. Adopt the explicit branch-pair structure, not its unconditional outcome passages. Ch19 both qualifies ordinary combinations by useful-object condition and makes a six-clash-to-combination exception; keep that textual distinction visible and do not manufacture a universal adjudication rule.

- [x] RED/GREEN: independently enumerate the eight 六合 and ten 六冲 hexagrams among all64; validate inner/outer corresponding1–4,2–5,3–6 pairs, including static casts.
- [x] Original and resulting complete 纳甲 arrays are separate chart projections. Only actual moving positions get `lines.changed`; static casts never claim a transition. Verify乾→泰、旅→贲、离→旅、困→节、否→乾、离→坤.
- [x] Add moving same-position branch combination/clash independently of five-element returning control. Source20恒→豫酉→卯 clashes but does not return-control; source20酉月乙未坤 retains monthly presence and day generation despite six-clash structure.
- [x] Bind source, scope and pair pointers through native evidence; legacy sparse data, actual transport, multi-receipt capacity and Node/JSC parity. Do not claim effective合化/冲散 or final outcomes.
- [x] Independent review, full local checks, push and exact-head CI. 三合、反伏、墓绝、元忌仇 and broader F remain separate open work.

B2 local: 689 Engine /283 Core tests and18 Node/JSC fixtures pass. Independent4,096-cast structure,9 original diagrams,128-chart context preservation and9,728-case capacity probes pass; two independent capacity regressions fixed with permanent RED/GREEN tests. Combined sample maximum59,758/60,000 bytes is not a global guarantee. Review cleared; exact-head push/CI pending.

## Batch F2 — Liuyao object-bound reference delivery

The archived F1 final provider draft invents 丑戌合, confuses selection/timing provenance and discusses暗动 for an all-moving cast. Extend the receipt-based delivery used by F4 to exclusive Liuyao requests. Render chart/calendar, separate original/changed/hidden facts, actual moving-return and day-clash conditions, all object candidates and their conditional timing branches from allowlisted values. Each section carries exact original receipt pointers/values and the applicable source. This fixes presentation grounding; it does not accept comprehensive event adjudication.

- [x] RED/GREEN with actual F1 all-moving values and source-bound branches, moving versus static day-clash, original/changed/hidden identity, full changed projection versus actual moving positions.
- [x] Reject missing/unsupported sources, wrong object pointers, conflicting/stale/cross-context receipts. Empty candidates and calendar/hidden candidates keep their own identity; no substituted primary changed object or invented event signal.
- [x] Shipping ChatSession and live evaluator use the same exclusive-request gate and compiler. Mixed-system requests remain mixed. Cached retries preserve original receipts and do not recast.
- [x] Independent review, full Core/native verification and one real provider planner/tool/local-render trial; retain model extraction failures.
- [x] Commit/push, verify exact head.

B2 remote accepted at `a93f07ffc66fc24a36efff4c3b94c89f472fc272`, remote hash matched, run35499556906 passed engine/swift-core/native-app. F2 and broader core completion remain open.

F2 local:294 Core tests and18 parity fixtures pass. Independent5,376 receipts /2,446,086 evidence fields have zero mismatches. Final eight mutation and eight intent probes pass; nine-receipt retry defect reproduced and fixed in both Liuyao and Qimen. Four real provider calls yield one source-bound report and one honest no-receipt failure; synthetic authentication/quota, not deployed E2E. Exact-head CI pending.

## Batch D4 — fixed natal palace-stem transformation graph

Selected convention: pinned iztro2.5.8 FunctionalPalace.fliesTo/selfMutaged/mutagedPlaces plus the already-selected ten-stem table. This defines source palace stem → actual natal star palace, including self loops. It is not a universal classical school, a complete 自化 taxonomy or an event judgment. Flow-month remains separate.

- [x] RED/GREEN independent2023正月初一子时 chart/star placements and all48 directed edges; minor stars, Ren左辅 variant, self loop and empty source宫 counterexamples.
- [x] Compute once in natal dossier; serialize graph with source/target identities, selected scope and source. Cached query must not recompute charts or mutate natal labels. Invalid/missing snapshot requires rebuild.
- [x] Explicit `withPalaceFlights` option on existing palace tool projects incoming/outgoing edges for only the requested宫. Legacy `withFlying` keeps its existing生年四化 alias meaning. Domain summaries do not automatically expand48 edges.
- [x] Native allowlist includes directed identities and original pointers, including empty incoming sets and false self flags; verify transport/replay, capacity and runtime parity. Source archive/claims distinguish natal-palace, natal-year, decade and annual layers.
- [x] Independent source and final code review, full local verification.
- [x] Commit/push and exact-head CI. Broader D/E/F remain open.

F2 remote accepted at `278b8ea3d7dbeff41bd21afd21a6132f2e53710f`, matching remote; run35500445792 passed engine,swift-core,native-app. D4 remains pending final review and remote checks.

D4 local:694 Engine /299 Core tests pass,19 parity fixtures. Independent48 literal edges pass;96-chart compatibility probe passes4,608 edges. Two capacity regressions observed RED/GREEN; final12 large queries preserve all distinct facts and314 exact references with full prompts/draft. Provider planning used the new option but writing ended503, no live interpretation acceptance. See ziwei-palace-flights-2026-09-20.md.

## Batch D5 — lunar-month projection from fixed birth basis

Source review confirms the selected iztro2.5.8/lunar-lite0.2.8 normal convention: 太岁起正月逆至生月、起子顺至生时得斗君，顺行每月一宫；birth and query leap days1–15 retain the month, days16+ use the next month. Monthly stems use lunar-year 五虎遁, not Bazi solar-term months or the natal stem of the monthly palace. The Quanshu electronic text supports the counting mnemonic, but its birth leap rule differs; retain this distinction. This is a structural overlay, not full event adjudication.

- [x] Independent literal RED/GREEN for twelve month palaces, month stems and four transformations; birth/query leap15/16, late-zi rollover, lunar New Year versus LiChun, prebirth and sparse-cache counterexamples.
- [x] Store birth lunar month/day/leap/hour basis in the account-scoped natal dossier. Optional `withMonthly` on `get_ziwei_timing` projects only the question month, keeping natal, decade, annual, palace-stem and monthly identities separate. No natal recomputation or star relocation.
- [x] Native original-path fact index and exact-scope interpretation counterexamples; actual tool transport/replay/capacity and Node/JSC parity.
- [x] Archive versioned sources, independent literal oracle and limitations; full local checks.
- [x] Final independent review (24 monthly counterexamples,4,120 exact index records,129 exact references).
- [x] Commit/push and exact-head CI.

Broader D/E/F/G remain open; no extension implementation.

D4 remote accepted at `83e2bd958ab150c2938d1e80992a35baa9dbad35`, matching remote; run35501350775 passed engine,swift-core,native-app. The failed live writing trial remains a limitation, not semantic acceptance.

D5 local: 711 Engine /309 Core tests pass,20 runtime fixtures. Independent HKO25 dates,26 upstream compatibility cases,30 production structural cases pass; raw upstream23h timestamps differ and are not adopted. Final12 large five-tool requests pass actual backend offline validation,113885 UTF16 max including arguments,542 exact concrete references, no fact-value loss or source-removal authentication. Shared field layouts restore each original receipt/key/pointer/value. Live4calls/2receipts returned matching month transformations but falsely accepted “农历月序号从6月进到7月” where only the calculation month changes; immutable report retained. This accepts neither broad text accuracy nor core completion. See ziwei-monthly-2026-09-20.md.

D5 remote accepted within the documented structural scope: exact `966c9f5550dc1fb5c2e58fc7c26d941d6bcd1b71`, run35502405039 passed engine, swift-core and native-app. F5 remains open.

## Batch F5 — actual lunar month versus selected calculation month

The D5 provider answer correctly lists both leap-six dates but later describes the selected effective-month transition as a real lunar month change. Preserve original calendars, selected school convention and separate date scopes. Use this actual false acceptance as a permanent regression before choosing a bounded receipt-based month description or another precisely scoped repair. Do not treat model accepted status as semantic evidence; do not broaden auto-rewrite across ambiguous date contexts.

Decision: add a bounded, source/date/argument-bound contradiction guard to the existing verifier. Only an explicit two-date 紫微流月 comparison with complete mutually consistent original calendars can authorize the known actual-month/effective-month transition correction. Preserve negation, report framing, hypothetical and ambiguous dates. Validate concrete source sharing against globally unique original receipts and source identity. This does not replace the complete answer or extend the old current-month transformation rewriting to ambiguous date contexts.

- [x] Permanent RED/GREEN on the immutable actual D5 false acceptance and unchanged-draft rejection before model acceptance.
- [x] Same-date/source/method/argument validation; false-positive and missing/conflicting/date/quote/transport-reference counterexamples, including independent review findings.
- [x] Actual JSC cached natal → monthly tools → compact transport → persisted replay → retry; original calendars unchanged and no retry recomputation.
- [x] Real archived-draft provider replay (2 requests, original2 receipts), independently check the corrected calendars,斗君,命宫 and8 transformations; preserve raw result and limitations.
- [x] Final local Core/native checks and independent review artifact archive.
- [x] Commit/push and exact-head CI. Broad monthly prose and full core acceptance remain open.

See `docs/mingli/validation/ziwei-month-calendar-2026-09-20.md`. No claim that a finite assertion grammar fully verifies natural-language interpretation.

## Batch B3 — candidate-relative 元神 / 忌神 / 仇神

Read actual 增删卜易 ch9/ch10 raw subpages, not the root transclusion markers or later editor annotation. Ch9 defines 生用为元、克用为忌、克元生忌为仇. Ch10 大过→鼎 explicitly retains 月破日克 despite 元忌同动; a co-moving chain is not a successful rescue. Three-combination and reverse/repeated chanting efficacy remain separate because the read transcription has conflicting passages.

- [x] Write RED/GREEN against independent five-element role table and ch9乾→小畜, ch10大过→鼎/兑→解, hidden姤 and static反例. Keep all target candidates; never substitute a convenient changed branch.
- [x] Map only actual original actors relative to each original/hidden candidate; group identical target elements losslessly with explicit candidate identities. Record original moving-pair chains separately from static role identity. Calendar targets remain explicitly unsupported in this layer; no changed/hidden/calendar actor freely attacking another original.
- [x] Retain every original object's month/day/void/return/binding context and unresolved target/actor effectiveness. No new outcome, date or net strength score.
- [x] Source archive and native original-pointer index, strict receipt-bound reference description including wrong-object/source/candidate and unavailable-layer counterexamples. Check actual combined transport/replay and backend capacity before acceptance.
- [x] Independent rereview and complete local validation.
- [x] Commit/push and exact-head CI. Other B/E/F gaps remain open.

B3 local:720 Engine /313 Core tests,20 runtime fixtures,source index51/65 pass. Independent40,960 engine cases and1,280 actual native reports,617,780 exact references and26 rejected corruptions pass.9,728 lossless capacity combinations;12 real native/replay/backend requests max107,617 UTF16 including arguments,52,603 tool bytes;actual ChatClient body158,059 bytes. Only duplicate long question text references same-call arguments; original receipts and every chart field remain complete. No final efficacy/吉凶/日期 or broader core acceptance. See liuyao-candidate-roles-2026-09-20.md.

B3 remote accepted within this structural scope: `b20b03ce41585042c69cbe1ea5924d5f19e7b3c0` matches origin; [run35503491952](https://github.com/wxbbb42/SUJI/actions/runs/35503491952) passed engine, swift-core and native-app. F5 is the next priority; core G/H are not accepted.

F5 local:325 Core tests (including12 new permanent regressions),39 independent probes and SwiftUI simulator build pass. Actual archived-draft replay:2 real provider calls, original2 receipts, no planner or recomputation; dates,斗君,命宫 and8 transformations independently match. Source and code hashes recorded in `native/Engine/validation/reasoning/f5-independent-review/`; original D5 false acceptance remains unchanged. Exact-head CI passed at `6f7446679b1ae75ba9716d3cbc772bf421dc635b` (run35504442304). Broader prose/context extraction, B/E efficacy and G/H remain open. Additional 易林補遺反伏吟 transcription is preserved as research only in `fanfu-additional-source-review.json`, not adopted as an engine rule.

F5 remote acceptance: `6f7446679b1ae75ba9716d3cbc772bf421dc635b` matched origin and CI run35504442304; engine, swift-core and native-app all success. Recorded real-provider responses were also replayed against the final refusal-guard source: the revision/review message arrays and final answer matched, without another provider request.

## Batch F6a — confirm first-cast question context

Retain the actual F4 missing-event planner call (office lease). Before a new 六爻/奇门 cast, show the original question beside editable proposed question, category, subject, event and near/far/unspecified scope. No gender inference or silent extraction fallback. Event mode requires a nonblank event; explicit reference-only mode permits absence. Unknown subject and unspecified horizon remain visible unresolved inputs, never final object selection or timing. This is input integrity, not core interpretation acceptance.

- Validate the entire planner batch before asking; collect all unique new cast preparations before executing any tool. Validate identity, schema and semantics again after preparation. Same-tool aliases share one confirmation.
- Persist confirmed call arguments, purpose, source question identity, context and timestamp before calculation; preserve the original question timestamp as cast time. Retry after a failed execution reuses confirmed arguments. Completed original receipts take priority and never trigger confirmation/recast. Backward archives without confirmations still decode.
- Native confirmation suspends execution. Cancel, stop, account/birth change and stale callbacks must not resume an old operation or execute an unconfirmed cast. Persistence failure prevents calculation.
- Test the archived omission, edited context reaching the actual engine, batch/alias/retry/cancellation/scope counterexamples, persistence and native UI. Independent review; full relevant local checks; commit/push and exact-head CI.
- Cross-turn question supplementation/re-adjudication without recast remains F6b; this batch does not claim it. E2b timing, broader efficacy and core G/H also remain open.

F6a local accepted within this input-integrity scope: 12 new Core regressions /337 total,720 Engine tests and unchanged rebuilt resources,15 backend tests,25 native unit tests (6 new),2 new UI tests and inspected screenshots pass. The native session test uses actual SwiftData/JSC with synthetic HTTP planner replies shaped like the archived F4 omission. Independent review resolved a maximum-original-question truncation bug and passed six max-size verifier cases plus100 cancellation/confirmation races. The initial UI selector used the wrong automation type; querying its existing accessibility identifier passes across the observed SwiftUI type mismatch. Evidence: `docs/mingli/validation/cast-question-confirmation-2026-09-20.md`, `core-f6a-local-results.json`, and `f6-independent-review/`. Commit/push and exact-head CI are pending; F6b/E2b, broader efficacy and G/H remain open.

F6a remote accepted: local HEAD/origin/GitHub ref all `c27cb423cbb2d99ea7638b18fe7c4a67c1ab8ecd`; run35505732574 passed engine, swift-core and native-app. Working tree was clean. Original rule/efficacy/core G/H gaps remain open.

## Batch F6b — explicit supplements on an immutable original chart

Architectural decision: select an existing cast explicitly in chat; do not guess follow-up lineage from prose. A supplement is a new user record, with the immutable original `ToolReceipt` and source user identity retained in optional `CastSupplement` metadata. It can start from an accepted prior supplement, but always re-evaluates the original chart. The confirmation call keeps the original method for its input schema; the result is named `reassess_liuyao` or `reassess_qimen`, so it cannot masquerade as a new cast. Original question time remains the computation reference; supplement entry/confirmation times describe the later edit.

1. Engine: a native-only `reassess-question` command validates original method, original provenance/current engine revision and complete chart inputs; rejects an already derived original. It calls pure question reassessment methods, never `cast`, `setup`, randomness, current time or calendar recomputation. Return full original facts unchanged, replacing only question, questionType, questionContext, yongShen, yingQi, and Liuyao roleRelations. Add explicit questionRevision source method/call ID metadata. No new traditional rule or final object/outcome/date is introduced.
2. Core: `CastSupplement` resolves the actual source entry/receipt in this account, not a model-supplied snapshot; compares the saved original to the source, rejects mismatched/forward/ambiguous identities, stale context and incomplete source. Validation of a derived receipt requires confirmed arguments, exact questionRevision identity and complete equality of every immutable original output field. Source-bound Liuyao/Qimen renderers are reused only after this validation; report text explicitly identifies an original-chart supplement.
3. Native: a focused supplement path in ChatSession creates/persists a linked user entry, opens the existing editable confirmation with supplement wording, persists accepted inputs, invokes the native-only command and saves the derived receipt before rendering. Retry after failed execution reuses saved confirmation; completed derived receipt retry performs zero engine calculations and never calls AI/cast/setup. Stop/account/birth changes use the existing cancellation/scope gates. Expose actions per cast/method on user entries; following a supplement uses its accepted inputs as editable defaults and retains the original source. The original source record is never overwritten.
4. Display/persistence: optional Codable entry metadata keeps old archives readable. Derived receipts show both the original time and supplement status in evidence; full original and revised records remain inspectable. Normal new-question flow stays explicit; no unsupported natural-language lineage inference is claimed.
5. Tests: fixed 六爻 self-health→parent-health target changes (including hidden/role/conditional timing contexts) while original six lines/values/calendar remain exact; fixed 奇门 category/proxy/horizon changes preserve all nine palaces/甲 hosted references/times. Counterexamples cover wrong original/version/source/user/scope, tampered immutable fields/provenance, wrong accepted arguments, forward/duplicate links, incomplete source, repeated supplement, retry, cancellation and account isolation. Native UI selects a real fixture chart, confirms an edit, observes revised evidence and an unchanged original. Independent review, full checks, regenerated engine bundle, commit/push and exact-head CI.

This closes the explicit supplement path, not general automatic follow-up understanding, final selection/efficacy, or E2b timing. G/H require the remaining core work.

F6b local: explicit source-chart selection, editable supplement confirmation, immutable root linkage, question-dependent reassessment and distinct derived receipts implemented. Core validates all immutable facts and independently binds accepted category/subject/horizon to candidates, missing conditions and legacy Qimen references. Independent review found and fixed stale-candidate grafts, unchecked original provenance on cached retries and the confirm-to-account-switch persistence race. Local725 Engine /342 Core outside Beijing /15 backend /29 unique native unit /3 UI pass; actual failure restoration and positively verified no-calculation retry trap pass. Independent768 valid combinations +18 hidden/month/day cases pass;6 corruptions reject and copied-account race saves nothing. Evidence: `docs/mingli/validation/cast-question-supplement-2026-09-20.md`, `core-f6b-local-results.json`, `f6b-independent-review/`. Commit/push and exact-head CI pending. E2b, broader Liuyao/Bazi efficacy and Ziwei prose grounding, core G/H remain open.

F6b remote accepted: `9a3e01c28e7d3b94c5be90fdf12a0be858701c07` matched origin; run35507252857 passed engine, swift-core and native-app. B/E efficacy and core G/H remain open.

## Batch B4 — object-bound tomb/extinction references and conditions

Source decision: selected five-element table is wood 未/申, fire 戌/亥, earth and water 辰/巳, metal 丑/寅 (tomb/extinction). Read actual 增删 /26又1, /26又3, root chapters28/30; fire extinction is corroborated explicitly by 易林补遗/1 because the selected 增删 transcription omits the fire table row. Only this compatible table item is taken from 易林; its stronger earth-Si efficacy statement is not adopted. 土随水 is an explicit selected convention, not Bazi yin/yang stem cycles. Scope remains conditional until selected-object strength and competing actors are adjudicated.

- Engine adds `tombExtinction` with sourceId `liuyao-tomb-extinction-v1`, assessmentStatus `conditional-structure`, efficacyEstablished false, and one ordered object row per actual original/changed/hidden (original, changed if present, hidden if present per position). Row fields: objectPath; month/day = 墓/绝/neither; ownChange only for actual moving originals; flying only for hidden; movingTombPositions and movingExtinctionPositions for original targets only, excluding self; supportingMovingPositions (same element or generates target) for original/hidden, excluding own original/flying. Changed targets retain independent calendar references only, never cross-position actors. Moving extinction is declared table-based structural projection, not a quoted complete efficacy rule.
- All arrays remain present even empty; no static changed projection, free hidden actor or branch from another object. Top-level unresolved stays selected-object, target-strength, actor-effectiveness, event-outcome. Native independently validates exact row membership, table, directional actors and negative lists before displaying. Source-specific empty/broken/clashed tomb references remain separate from target context; target support is evidence, never an automatic true/false tomb verdict. No date/outcome inferred; no arbitrary score.
- Native report shows the selected convention and exception conditions: earth+Si retains fire-generates-earth alongside extinction reference; metal+Chou retains earth-generates-metal and opposing tomb conditions; broken/clashed tomb, target support and source context cannot be silently collapsed into a universal release. Each statement carries original receipt pointers and a reviewed source. Old archives without this optional layer remain readable; a present layer requires its exact source and consistent full structure.
- Independent literal table and original ch30 vectors, weak/strong-support counterexamples, hidden/changed/source identity/cached supplementation tests; native evidence allowlist, actual tool transport/replay and capacity. Full Engine/Core/backend/native checks, independent source/code review, generated bundle, commit/push and exact-head CI.

This closes the missing object-bound references and relevant observable conditions; comprehensive efficacy, 三合/反伏, E2b and G/H remain open. No expansion implementation.

B4 local accepted in this scoped sense: 747 Engine /354 Core outside Beijing /15 backend,28 native unit and3 UI tests pass; resource rebuild unchanged,52 source/66 claim index valid. Independent review resolved long call-ID capacity, escaped-event expansion and missing transport-layout evidence loss. Final45 actual Core/ChatClient requests (200-byte IDs) pass backend validation,90 complete chart roundtrips and4,400 condition rows match original outputs; max113,354 UTF16 including arguments,30,221 per message,53,763 tool bytes,167,609 body bytes.27 malformed layouts reject completely,2 valid alterations fail receipt authentication,8 corrupted charts/sources reject native rendering. Five independently read classical vectors and73,728 cross-month structural cases pass. See liuyao-tomb-extinction-2026-09-20.md and b4-independent-review; no new real-provider interpretation call. Commit/push and exact-head CI pending. B5 source comparison is research only; E2b and G/H remain open.

B4 remote accepted: `56ee94ee9227484ae536ce10076285d0fb995f2b` matched origin; run35509259390 passed engine, swift-core and native-app. B5a/B5b, E2b and core G/H remain open.

## Batch B5a — explicitly scoped moving-line and trigram fanfu references

Source comparison is recorded in `triad-fanfu-source-review.json`. Select three separate observations: actual original moving line versus its own changed line (same branch/clash, same stem retained independently); three-branch Najia projection of an actually changed lower/upper trigram (all repeated/all opposed/neither); separately named 易林 directional opposition pairs乾巽、坎离、震兑、艮坤. Do not merge these into one unqualified反吟/伏吟 flag. Static trigrams are unchanged, even when their projection repeats; source alternatives乾→坤、坤→震 remain explicit disagreements. No prediction or efficacy. Triads remain B5b, not inferred from these patterns.

- Engine adds question-independent `fanfu` with sourceId `liuyao-fanfu-selected-v1`, assessmentStatus `structural-only`, efficacyEstablished false. `lines` includes every actual moving original in position order, with originalPath/changedPath and sameStem/sameBranch/branchClash booleans, including negatives. `trigrams` includes lower then upper, with side, from, to, movingPositions, branchRelation (`unchanged`, `repeated`, `opposed`, `neither`) and directionalOpposition boolean. The original/resulting branches are already preserved at guaRelations/original/ganZhi and resulting/ganZhi; avoid copying them as free actors. Unresolved = selected-object, target-strength, actor-effectiveness, event-outcome.
- Source binds actual增删25 and root118 plus explicit易林1 convention; preserve edition limits and nonselected terminology. Actual line scope does not require same stem and cannot admit static changed decoration. Trigram branch-vector scope uses all three projected positions but labels the actual moving subset separately. Purely unchanged/static卦 is not the selected dynamic伏吟.
- Independent literal source vectors/counters and all4096 original/change patterns; actual line members, own-change identities and negative booleans; reassessment preserves layer byte-for-value. Native independently rebuilds the whole layer and renders precise original receipt references; missing source, wrong object, wrong table, false efficacy, mismatched calendar/source or static label corruption reject.
- Verify evidence allowlist, full native report, supplement/replay, old archives without layer, and combined capacity including200-byte IDs/max escaped events. Keep full receipts and no raised limits. Independent final review, all relevant checks/resources, commit/push and exact-head CI before acceptance. No extension implementation or overall-core completion claim.

B5a transport decision: preserved single-message/source limits after the legal escaped-event regression and independent upper request case failed (32,888 single cast /123,187 whole request including arguments). Add an exact self-contained repeated-object-key layout after the existing condition dictionary; expand object rows first, then conditions, before original-pointer indexing. No chart facts/values omitted, full saved receipts unchanged; old condition-only delivery remains authenticated by exact regeneration. Reject damaged/missing/unused layouts, preserve primitive/array/object identity and special key names. Independent worst controls case now has116,784 total with arguments and26,719 sampled max cast; final independent wire review pending. A too-small special-key test initially chose the correct no-compression fallback; enlarging its fixture forces actual packing, with complete equality and no prototype semantics verified. B5a broad acceptance remains pending until final Core/native and review results.

B5a local accepted within this structural scope:764 Engine /364 Core outside Beijing /15 backend /28 native unit +3 UI pass; deterministic resources,53-source/67-claim index and native-only check pass. Independent4096 patterns and5 source diagrams agree.48 actual Core/ChatClient requests pass real backend providerRequest;96 full charts,6,851 object rows,4,694 condition rows and336 index messages restore exactly. Max116,997 UTF16 including arguments,26,719 per message,52,008 tool bytes and172,003 body bytes;30 native/source cases and46 layout/value boundary cases pass. No unresolved scoped review findings. Evidence in liuyao-fanfu-2026-09-20.md, core-b5a-local-results.json and b5a-independent-review. No new provider interpretation/prediction validation. Commit/push/exact-head CI pending; B5b, E2b, broader efficacy and G/H remain open.
