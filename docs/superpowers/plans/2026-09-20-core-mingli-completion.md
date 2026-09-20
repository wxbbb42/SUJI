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
- [ ] Commit/push and exact-head CI. Broader D/E/F remain open.

F2 remote accepted at `278b8ea3d7dbeff41bd21afd21a6132f2e53710f`, matching remote; run35500445792 passed engine,swift-core,native-app. D4 remains pending final review and remote checks.

D4 local:694 Engine /299 Core tests pass,19 parity fixtures. Independent48 literal edges pass;96-chart compatibility probe passes4,608 edges. Two capacity regressions observed RED/GREEN; final12 large queries preserve all distinct facts and314 exact references with full prompts/draft. Provider planning used the new option but writing ended503, no live interpretation acceptance. See ziwei-palace-flights-2026-09-20.md.
