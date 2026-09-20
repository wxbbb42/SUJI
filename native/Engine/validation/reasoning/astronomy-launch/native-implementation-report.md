# Task 4 — native astronomy dossier, lifecycle and UI

Native sidecar is separate from the existing natal dossier and archive. `NatalAstronomyDossier` binds owner, complete BirthProfile (including city), actual bundled script SHA256, embedded source revision, schema and payload digest. Typed contract validation checks fixed UTC+8 identity, UTC instant, independent ΔT and UT/TT consistency, exact body order/method/source policies, coordinate ranges, full 28-star identity/one-circle geometry, seven recomputed memberships and explicit uncertainty. It does not claim to independently recalculate ephemerides in Swift.

`AppStore` merges concurrent work, reuses only current valid disk caches, rebuilds corrupt caches, cancels and guards stale work, resets on full birth/account changes, removes sidecars on import/deletion, and prepares astronomy independently of the existing natal profile. Tool injection strips caller-supplied top-level astronomy, requires exact current birth, and inserts only the native-owned validated sidecar; it does not compute unrelated natal results for this tool. No production test-injection API was added.

Profile entry is available whenever birth exists, independently of old profile success. `NatalAstronomyView` only displays the currently matching dossier and loads by profile/account task identity. It shows seven geocentric positions, modern Moon mansion, entry/width/nearest boundary distance, unknown birth precision, source/method policies and explicit unsupported scope. It uses the title 出生星历 and label 现代星名距星参照, never complete 七政四余. No invented latitude, houses, 四余 or traditional units.

## Observed verification

- Core RED: prior EngineContract accepted malformed astronomy; native payload/dossier validation then passes 3 focused tests.
- App RED: first tool calls persisted zero sidecars and caller-forged top-level cache caused engine error. Implementation passes the regression with exactly one record and safe native replacement.
- `TZ=America/Los_Angeles swift test --package-path native/Core --filter 'NatalAstronomyDossierTests|EngineTests.testJavaScriptCoreMatchesNode'`:4 tests PASS. Runtime transcendental roundoff ~1e-14° initially failed exact parity; only astronomy fields ending in Degrees allow1e-9°, all earlier fixtures remain exact.
- Five App lifecycle tests PASS: concurrent trusted injection, restart/account/full-birth/archive/delete lifecycle, corruption + incompatible tool birth, stale in-flight notebook replacement, deliberate natal-astronomy command failure preserving old natal/profile. The first fault injection attempted to replace an export getter and did not trigger a fault; corrected fixture replaces only the command branch in a temporary script, asserts the marker exists, and now observes the intended error. No production dependency changed.
- Reviewer found warm metadata/disk-hit queued-work race. Added operation-entry and cache-publication cancellation/scope/birth guards and a dedicated regression. Final RED/GREEN result recorded below.
- Simulator UI `NatalAstronomyUITests.testBirthAstronomyAndModernMansionAreReadable` PASS on iPhone17Pro iOS26.4. Three screenshot attachments exported to `screenshots/{seven-bodies,modern-mansion,method-limits}.png`; visually inspected for readable layout, uncertainty, convention and scope. `/tmp/suji-astronomy-task4.xcresult` contains attachments and UI result (its earlier overall run also contains the superseded fault-injection test failure).
- Regenerated Xcode project; simulator build passed with actual signing/Keychain entitlement. Parent owns final full Core/App suites, transport acceptance, commit and push.

## Files

`native/Core/Sources/SujiCore/NatalAstronomyDossier.swift`, astronomy branch of `EngineContract.swift`, `native/Core/Tests/SujiCoreTests/NatalAstronomyDossierTests.swift`, narrow astronomy parity change in `EngineTests.swift`; `native/App/Services/AppStore.swift`; `native/App/Features/Profile/{ProfileView,NatalAstronomyView}.swift`; `native/AppTests/NatalAstronomyStoreTests.swift`; `native/UITests/NatalAstronomyUITests.swift`; regenerated project. Task3 contract/report/sample refreshed to the approved production modern28 module. No commit or push by this agent.

## Final reviewer regression evidence

Temporarily removed only the new operation-entry/cache-publication guards, retaining the same warm-metadata queued disk-hit regression. `/tmp/suji-astronomy-race-red.log` observed2 real failures: stale operation returned success and republished the old birth dossier after current birth changed. Restored both guards, then reran the entire `NatalAstronomyStoreTests` selection:6 tests,0 failures, `TEST SUCCEEDED` at2026-09-20 22:57:00+08 (`/tmp/suji-astronomy-race-green.log`). Production/App/test files now stable. `git diff --check` for modified tracked App/fixture-comparator files exit0. No full-suite success inferred from focused runs.
