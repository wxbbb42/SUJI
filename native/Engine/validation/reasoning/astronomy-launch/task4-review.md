# Independent Task 4 review

2026-09-20. Reviewed Task4 plan/cache specification, `AppStore.swift`, native-owned tool injection, `NatalAstronomyView.swift`, profile entry, store/UI tests, project registration and CI selection. Inspected the three actual screenshots under this directory's `screenshots/`. No implementation edits or full-suite reruns by this reviewer.

## Finding and fix review

**[P2, fixed in current production code; focused regression execution pending] Revalidate queued warm-metadata cache hits before publishing.**

The initial `ensureNatalAstronomyDossier()` operation skipped cancellation/scope/birth checks when `astronomyPayloadRevision` was already cached. A queued operation could therefore start after account switching had cancelled it and cleared memory, read the previous owner's still-persisted sidecar, and republish that old payload into the store. The UI `hasNatalAstronomyDossier` check and tool request's post-await check prevented treating it as valid, but the stale task still violated the sidecar's account lifecycle contract and returned the obsolete dossier to a direct caller. Cold-metadata and fresh-computation paths already had the necessary checks, so existing cold-start cancellation coverage did not catch it.

Reported immediately to the controller. Current source now checks cancellation plus captured scope/birth at operation entry and again before publishing a disk-cache hit. Re-read both changes: they close the identified window without adding an intervening suspension. A new `testWarmMetadataQueuedDiskHitCannotReviveReplacedBirth` exercises warm metadata, a retained disk sidecar and a changed birth before queued execution; the controller should retain actual regression results. Its Task.yield scheduling also warrants confirming that it fails against the old implementation rather than assuming the intended interleaving occurred.

## Lifecycle and trust assessment

Aside from the corrected window, the store captures owner/scope/birth, merges same-scope/birth work, validates stored envelopes against the immutable engine resource and embedded policy revision, and checks cancellation/scope/birth before writing newly calculated results. A failed rebuild does not replace the persisted previous sidecar. Changed birth profiles invalidate memory and complete profile equality prevents reuse even when only city metadata changes. Account switching clears in-memory state; metadata revision can remain because the engine instance/resource is fixed and that value is not account-specific.

Imports and local deletion remove the account's sidecar in the same save transaction and invalidate pending work only after persistence succeeds. Import/export AppState carries no trusted astronomy envelope. The tool path unconditionally strips caller-supplied top-level astronomy, requires the complete current native birth, injects only an admitted native dossier, and checks scope/birth again after both awaited operations. Strict Engine model-argument validation supplies the second boundary. No caller snapshot or cross-account payload was found able to bypass these checks.

Astronomy errors remain separate from existing natal/profile errors; the ordinary natal request succeeds before optional astronomy preparation, which records its own failure. The added failure test uses a real JSC bundle wrapper to fail only the astronomy command and checks that the existing natal/profile remains usable. The profile entry depends on birth availability, so users can retry astronomy even when other profile rendering is unavailable.

## Product and visual assessment

The result page clearly separates ecliptic and equatorial coordinates, identifies the birth clock as fixed UTC+8 and angles as modern degrees, labels the Moon's mansion with the selected modern first-star policy, and shows entry angle, width and nearest-boundary distance. The uncertainty warning appears beside the mansion result. The expanded method explains time/frame/correction conventions, catalogue differences and unsupported 四余/宫位/命度/traditional degrees; it expressly denies complete 七政四余 readiness. No personality or event outcome is fabricated from the coordinates.

The inspected seven-body, mansion and expanded-method screenshots are readable at the captured iPhone size. The Moon's mansion and uncertainty are visible together, and method/source text wraps without truncating the captured content. This is a bounded screenshot review, not an assertion that all Dynamic Type/device/localization combinations were tested.

## Acceptance conditions

No additional production blocker found after the fix. Read tests cover sidecar persistence/restart, concurrent access, birth-only metadata change, account switching, corruption rebuild, caller cache discard, incompatible birth rejection, import/delete invalidation, stale work and failure independence. The initial existing CI selection did not include `NatalAstronomyStoreTests` or `NatalAstronomyUITests`; the controller was notified and the implementation agent is still extending tests/CI. Final acceptance requires both classes selected in CI and the new regression plus refreshed native/UI run results. The synchronized JSC/backend transport acceptance remains the controller's Task5 evidence rather than a claim of this review.
