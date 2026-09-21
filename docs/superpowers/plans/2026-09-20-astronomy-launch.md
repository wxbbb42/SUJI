# Astronomy launch and Liuyao acceptance implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox syntax for tracking.

**Goal:** Accept the pending 六爻三合 changes and deliver grounded natal seven-body / Chinese mansion modules before broader product experience work.

**Architecture:** Preserve the existing 八字/紫微 dossier and fixed UTC+8 interpretation. Share deterministic geocentric astronomy in an account-owned sidecar; expose independently sourced equatorial mansion membership and bounded AI results. Four余 and 命度 remain unavailable until their definitions are actually resolved.

**Tech Stack:** TypeScript, Astronomy Engine 2.1.19 (MIT), Swift Core, SwiftUI, JavaScriptCore, SwiftData.

**Spec:** `docs/mingli/astronomy-natal-cache-design.md`, `docs/mingli/qizheng-and-28-mansions.md`, and the user's 2026-09-20 launch instruction.

## Global Constraints

- SwiftUI is the only client. Preserve authentication and account isolation.
- Birth range 1901–2100; original wall clock remains fixed UTC+8. Do not apply apparent solar time to astronomy.
- No invented latitude, 四余 epoch, 命度 rule, traditional angle conversion, or complete-system readiness.
- Preserve full 六爻 receipts and reconstructible original JSON pointers. Transport limits stay 32000 UTF16/message, 60000 tool bytes, 120000 total UTF16 including arguments, 262144 body bytes.
- Chinese 二十八宿 only; no 宿曜 relationship or 生肖 module.
- Full-circle ordered star boundaries validated before modulus. Membership is left-closed/right-open, in modern equatorial degrees, with explicit uncertainty.
- Cached payloads bind account, complete birth profile, engine revision, module versions and digest; imports and model arguments cannot supply trusted cache.
- Research Swiss Ephemeris remains outside product dependencies. Retain source/license attribution and reproducible independent comparison evidence.
- Commit and push to `codex/mingli-validation`, then verify the exact remote SHA and CI. User has already authorized these operations.

### Task 1: Accept 六爻三合 and delivery capacity

**Files:** Pending `native/Engine/src/divination/triads.ts`, Engine triad/capacity tests, Swift triad trace/evidence transport and tests, `docs/mingli/validation/liuyao-triad-2026-09-20.md`, reproducible validation artifacts.

**Interfaces:** Existing `triads` structural-only receipt; no efficacy or event outcome. Native exact reconstruction and original pointer index remain stable.

- [x] Reproduce QuestionCapacity failure and actual Swift→backend transport matrix using `/tmp/suji-b5b-probe`.
- [x] Diagnose the size regression; reduce reversible transport overhead without dropping facts. Replace an obsolete raw-only guard only with an explicit documented raw envelope and enforced real-wire acceptance, never silently relax provider limits.
- [x] Run independent 4096-pattern source/structure comparison, malformed receipt checks, full Engine/Core suites, and actual backend decoder roundtrip.
- [x] Obtain scoped independent code/source review, address findings and commit accepted changes.

### Task 2: Ground the complete mansion identity set

**Files:** `native/Engine/validation/research-qizheng/` source records and a new production-ready 28-star data JSON under `native/Engine/src/astronomy/` only after evidence supports it.

**Interfaces:** 28 ordered entries `{name, designation, hip, raDegrees, decDegrees, pmRaMasYear, pmDecMasYear, epochYear, sourceIDs}`; policy identifies the explicit modern first-star reference set separately from historical sets.

- [x] Read archived source leads, obtain all 28 identities with direct source attribution, independently cross-check catalog identities and epoch/unit semantics.
- [x] Archive reproducible catalogue query and exact returned data; explain any disagreements rather than selecting silently.
- [x] Check one-circle order at 1901, J2000 and 2100 and the old/revised 觜参 counterexample.
- [x] Record approved policy or a precise unresolved constraint; never produce fabricated constants to meet a launch date.

### Task 3: Implement seven-body astronomy and mansion computation

**Files:** New focused `native/Engine/src/astronomy/` functions/tests, package manifests, license generator, `native/Engine/bridge.ts`, tool definitions/validation/evidence as needed, build fixtures.

**Interfaces:** `natal-astronomy` command returns versioned birth-bound payload; `get_natal_astronomy` tool returns bounded natal result from native-owned cache. Shared positions contain longitude/latitude/RA/declination, frame and time policies. Mansion module consumes Task 2 data and shared true-equator-of-date RA.

- [x] Add failing fixed-vector tests from independent Swiss reference, invalid date/range tests and unchanged physical-instant tests.
- [x] Pin Astronomy Engine 2.1.19 and implement geocentric seven-body coordinates matching the verified research calls. Record UTC≈UT1, Espenak/Meeus ΔT, TT, date frame, and Moon correction difference explicitly.
- [x] Add mansion transformation with documented proper motion / precession / nutation policy, left-closed/right-open boundaries, order rejection and unknown birth-time precision. Validate transformed stars independently before readiness.
- [x] Add bridge cache reuse, bounded tool results, registered source claims and method labels; tests reject caller-supplied snapshots in tool args.
- [x] Run focused then full Engine tests and regenerate JSC fixtures/notices after integration stabilizes.

### Task 4: Integrate native dossier and minimum product access

**Files:** New Swift astronomy contract/dossier/tests; `AppStore.swift`, `ProfileView.swift`, focused `NatalAstronomyView.swift`; native store tests and CI selection.

**Interfaces:** `ensureNatalAstronomyDossier()` merges concurrent work, persists `natal-astronomy:<account>`, and injects only validated cache. Existing natal dossier remains independent and usable if astronomy fails.

- [x] Add rejection tests for corrupt, wrong-account, wrong-birth, wrong-engine, wrong-policy and malformed coordinate payloads.
- [x] Add store lifecycle tests for cached reuse, restart, concurrency, account switch, birth changes, deletion and imports.
- [x] Provide a profile entry with seven-body positions, birth Moon mansion, entry angle, boundary distance, provenance and precise supported-scope copy; no fabricated吉凶 or complete七政四余 label.
- [x] Verify real JSC parity and actual AI transport with the new tool, and iOS simulator build/tests.

### Task 5: Acceptance and remote delivery

**Files:** Validation report, scope/cache docs, source registry, generated resources.

- [x] Independent whole-change review checks calculation, provenance, cache boundaries and exposure.
- [x] Run repository-required Engine, Core, backend and native checks once final code is stable.
- [x] Update scope documents to distinguish implemented capabilities, measured accuracy, structural rules and unresolved traditional interpretation.
- [ ] Commit/push and inspect exact remote SHA and all CI jobs. Report delivery location without claiming App Store distribution.
