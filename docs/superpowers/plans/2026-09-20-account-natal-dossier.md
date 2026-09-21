# Account and Natal Dossier Implementation Plan

**Goal:** Require an account and complete birth profile before entering the app, then reuse a durable natal chart across questions and launches.

**Architecture:** Keep natal calculations in an account-scoped local record separate from notebook backups and time-dependent readings. The engine exports and restores a versioned natal snapshot; native storage binds it to the birth inputs and bundled engine digest. Existing Supabase birth-profile storage supports restoring another device; snapshots remain local and are rebuilt once per device/version.

**Tech Stack:** SwiftUI, SwiftData, SujiCore, JavaScriptCore, TypeScript, Supabase Auth/profiles.

**Spec:** User's account → required information → fixed dossier flow in this task.

## Constraints

- Implement 八字 and 紫微 natal reuse; keep 六爻/奇门 question receipts and their fixed retry instants.
- No 生肖, 七政四余 or independent 星宿 implementation in this change.
- Preserve existing per-account notebooks; never silently assign local guest data to a new account.
- Imported notebook data cannot supply a trusted natal cache. Algorithm/birth changes rebuild it.
- Daily observations and annual forecasts always use the requested reference time.
- Keep this task on the existing `codex/mingli-validation` branch; commit/push and verify remote CI.

## Tasks

- [x] Engine snapshot round-trip: add `natal` command returning `schemaVersion`, `engineRevision`, `birthKey`, `calendarPolicy`, `mingPan`, `ziweiPan`, `personality`. Accept `natal` on profile/forecast/natal tools and first relationship chart. Validate identity and restore Date fields. Test no natal recalculation with spies on real engine methods, malformed snapshots, dynamic reference times and exact output parity.
- [x] Durable native storage: add `NatalDossier` in SujiCore with owner, validated birth, bundle digest, createdAt and checksummed JSON payload. Store under separate `SavedState` key; coalesce concurrent requests. Test restart, corruption, account/birth/version mismatch and AppStore request routing.
- [x] Account-first setup: replace guest onboarding cover with a root gate; show login, birth form, building/retry state, then tabs. Reuse account/password recovery UI. Automatically restore cloud birth only into an empty account; saved birth changes are queued for cloud upload with visible retry. Preserve user control over importing old local data.
- [x] Verification: run engine typecheck/tests/build, Core and native integration tests, generate Xcode project, inspect diff and archive boundaries, update architecture notes, commit/push. macOS CI supplies native checks when local Xcode tooling is unavailable.

## Test examples / contracts

```ts
const natal = JSON.parse(JSON.stringify(await dispatch({command:'natal',birth})));
const result = await dispatch({command:'profile',birth,natal,now:'2024-02-04T04:00:00Z'});
// BaziEngine.calculate and ZiweiEngine.compute are not called after creating natal.
// A second date changes daily/forecast reference values, not the saved natal chart.
```

```swift
let saved = try NatalDossier(ownerID: "user:a", birth: birth, engineRevision: digest, payload: data)
let restored = try JSONDecoder().decode(NatalDossier.self, from: JSONEncoder().encode(saved))
XCTAssertTrue(restored.matches(ownerID: "user:a", birth: birth, engineRevision: digest))
XCTAssertFalse(restored.matches(ownerID: "user:b", birth: birth, engineRevision: digest))
```

## Result

Implemented and verified at `a39838df3f0c75458d30a7e21e102f7db634d264`. [CI run 35489808350](https://github.com/wxbbb42/SUJI/actions/runs/35489808350) passed: 592 engine tests, 219 Swift Core tests, 18 native integration tests, 2 UI tests and 14 backend tests. The final follow-up commit contains only this record, verification notes and captured screenshots.
