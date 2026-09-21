# Qimen conditional timing implementation plan

> **For agentic workers:** Execute inline with the already assigned Qimen worker; do not spawn another worker.

**Goal:** Apply the source's explicit object-bound precedence and enumerate bounded calendar windows on the original plate.

**Architecture:** `analyzeQimenTiming(chart, request)` projects one selected occurrence from the existing chart, computes independently evidenced conditions, and filters calendar intervals. Setup and question reassessment may opt in; absent a request the established receipt shape remains unchanged.

**Tech Stack:** TypeScript, Jest, existing calendar precision and apparent-solar modules.

**Spec:** `docs/superpowers/specs/2026-09-21-mingli-adjudication-design.md`

## Constraints

- Original plate is immutable; no new casting call inside timing.
- Chart method must be `zhuanpan-qimen-chai-bu-v1` with fixed Kun hosting.
- Explicit focus and event are required; question category alone is insufficient.
- `near` / `far` does not specify a unit. No calendar dates without an explicit unit and end.
- Dates are conditional intervals, never an established successful outcome.
- Exact solar-term physical instants bound years/months; day/hour use the chart's clock and 23:00 day boundary.
- Every conclusion carries object and evidence paths. No cross-palace condition pooling.
- Only Qimen files and this worker's research files change; no bridge, Swift or shared registry edits.

## Task 1: source and interface

- [x] Read and archive actual chapter 2, 3 and 6 bodies with SHA256. Read event-specific employment, profit and relationship passages.
- [x] Define request `{focus,event,object?,timeUnit?,window?}` and result with selection, triggers, opposing, conflicts, unresolved and search policy. Parent accepted the interface.
- [x] Write the source decision, exact quotations, excluded transcriptions and adoption limits in the dated validation report.

## Task 2: object conditions and precedence

Files: create `native/Engine/src/qimen/timing.ts` and `native/Engine/src/qimen/__tests__/Timing.test.ts`.

- [x] RED: literal reordered palace tests select the exact occurrence; reject center/earth substitution, ambiguous identity, proxy self and incompatible method.
- [x] RED: independent chapter-6 vectors: empty Kun on Zi chooses Chou/Yin clash first; on Si chooses Wei/Shen fill first; nonempty horse Shen chooses Yin/Shen; opening door in Gen uses Chou/Wei; Xin in Li uses Wei. Void suppresses horse/tomb; horse suppresses tomb; same-tier conflicting conditions remain alternatives.
- [x] GREEN: implement focus selection and derive conditions from that same occurrence. Use whole-palace void convention with disclosed partial coverage, exact horse branch, chapter-2 stem tomb table, six-Jia carrier clashes/combinations/punishments. No unconditional palace-branch fallback. Ambiguous combination-clash target remains unresolved.
- [x] Verify targeted tests before proceeding.

## Task 3: bounded calendars

- [x] RED: 2004-05 chapter vector day windows, current inclusion, 23:00 rollover, exact Jie/Lichun, explicit apparent-solar inverse, caps/truncation, invalid/range inputs and original immutability.
- [x] GREEN: enumerate intervals with limits of 512 hour/day periods, 120 months or 24 years; cap returned candidates at caller's 1–256 limit (default 32), preserving combined reasons and search completion.
- [x] Add opt-in `timingRequest` to setup/reassessment and optional `timing` result; invalidate previous timing on changed context unless a new request exists.
- [x] Run targeted and all Qimen tests in a non-Beijing host timezone; typecheck. Parent performs full integration and generated-resource verification.

## Delivery

- [x] Report files, exact test commands/results, remaining source and integration limits to parent. No commits from worker.

## Additional authorized integration

- [x] Added bounded timingRequest schema and handler transmission to actual setup_qimen, and original-chart reassessment transmission.
- [x] Added QimenTimingEvidence.swift with fixed source-reference signature, same-occurrence/rule validation, bounded date checks and conditional local text.
- [x] Added opt-in native confirmation fields; referenceOnly removes timing. Calendar cutoff is explicit Beijing date end.
- [x] Verified archived confirmation -> real JSC, original supplement -> confirmation -> JSC -> CastSupplement.render.
- [x] Parent final bundle/resource/SwiftUI app build and full integration verification.

Latest checks are recorded in the dated source report. No worker commits.
