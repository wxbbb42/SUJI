# D5 targeted independent implementation review

Scope: uncommitted D5 changes over base `83e2bd9`; read-only production review. Review artifacts are under `/tmp/suji-d5-review`. No production edits by reviewer.

## Algorithm and cache behavior

Passed the pre-existing independent literal oracle against a separately bundled current bridge: 30/30 focused cases, recorded in `structural-results.json`. These cover twelve ordinary lunar-2025 months, both query leap15/16 sets, both birth leap15/16 午 cases, six explicit 23:00 references, late-zi birth equivalence at leap15/16 and lunar new year, month stem versus destination palace stem, the four target star branches, and unchanged cached natal JSON. The new production `Monthly.test.ts` also passed 17/17, including a compute spy that rejects natal recomputation during cached replay.

The implementation uses the already advanced calendar date from `timing.ts`, stores birth month/hour once, computes month stems with lunar-year Five Tiger, resolves transformations to resident natal stars, and keeps monthly palace names in a separate overlay. No algorithm finding remains from these examples.

## Initial blocking findings reported to owner

The frozen initial source and probe are retained in `core-snapshot` / `assertion-probe.swift`; RED outputs are `assertion-results.json`.

1. Monthly transformation binding accepted a known entry-level source ID without checking same-receipt monthly status, appliesToBirth, parent source ID, selected method, source registry, or source-stem consistency. Removing registry data or damaging parent scope still authorized both deterministic correction and reviewer feedback. The owner is adding source/structure checks and permanent regression cases.
2. Explicit month qualifiers were discarded by clause splitting: a January 戊/太阴权 receipt could authorize changing `农历六月，流月太阴化科` to 化权, even though sixth-month 癸/太阴科 is a distinct valid month. Whole-draft qualification (including prior sentence/year context) is required for the narrow current-month repair path.
3. Comparing only records grouped by scope+star did not reject mixed-month histories when the current month's transformations omitted a star present in the old month. January 太阴权 plus fifth-month 天梁禄 could still authorize correcting a plain 太阴 claim from January. The owner is adding single-month calendar/stem identity checks.

These are repair-authorization issues, not errors in the deterministic Ziwei monthly arithmetic. Final post-fix confirmation is pending owner notification; the review does not expand natural-language support beyond the agreed literal scope.

## Initial capacity/reference follow-up

On the 1989-08-15 07:30 male fixture with two domains, two palace-flight tools and a monthly timing query, the first nested-palace optimization produced:

- 5/5 live and replay receipts, no error results, replay exactly matching live delivery.
- 40 concrete references, including 10 nested related-palace references; zero value mismatches or palace-identity mismatches; no chained reference accepted.
- Every deleted-source check invalidated projected receipt authentication.
- Equality of unique fact-key/value sets before and after sharing.
- Actual `ChatClient` serialization captured locally, then accepted by real backend `providerRequest`: 113208 UTF16 including tool arguments; 160690 body bytes, or 161714 including 1024 reserved bytes.

Evidence: `combined-results.json`, `actual-wire-report.json`, `actual-chatclient-wire.json`. This is one bounded fixture, not a matrix capacity claim. Owner later found a separate 1986 未-hour capacity excess and is revising source-reference/limitation sharing; final targeted recheck is pending.
