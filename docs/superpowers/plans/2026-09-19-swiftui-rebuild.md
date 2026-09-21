# SwiftUI Rebuild Implementation Plan

> **For agentic workers:** Use superpowers:subagent-driven-development for independent modules; the controller integrates and verifies the app. Track work here and in the plan ledger.

**Goal:** Rebuild the full SUJI self-care experience in native SwiftUI with refined Apple interaction and Eastern paper-and-ink character.
**Architecture:** A standalone Xcode app in native/, Swift services and persistence, and a bundled JavaScriptCore deterministic engine. SwiftUI owns every screen; no React Native or WebView at runtime.
**Tech Stack:** SwiftUI, SwiftData, JavaScriptCore, AVFoundation, URLSession, Keychain, WidgetKit, UserNotifications; iOS 18 minimum.
**Spec:** docs/superpowers/specs/2026-09-18-swiftui-rebuild-design.md

## Global Constraints

- Preserve the Expo project; use branch codex/swiftui-rebuild and native/ in this workspace.
- API keys stay in Keychain, never profiles or exported archives.
- Real playback, real calculations and real network errors; no fake successful actions.
- All UI uses SwiftUI; iOS 26 system materials with availability guards, iOS 18 fallback.
- Keep simplifications visible; algorithm parity is not proof of traditional accuracy.
- Verification reports distinguish simulator, automated tests and unverified real accounts/device haptics.

## File ownership and interfaces

- native/Core/Sources/SujiCore/: Codable domain models, deterministic daily content, breathing clock, SSE parser and engine bridge; native/Core/Tests/SujiCoreTests/ tests. Export public types usable in app and package tests.
- native/Engine/bridge.ts and build.mjs: bundle existing algorithms to native/Resources/mingli.js and generate parity fixtures. JSON commands calendar, profile, tool, relationship, candidates.
- native/App/Design/: tokens, paper components, haptics. native/App/Features/: Today, Chat, Calm, Profile, Journal, Settings, Onboarding.
- native/App/Services/: Keychain, storage, chat orchestration, reminders, profile sync, audio and archive services.
- native/Widget/: widget extension. native/UITests/: XCUITest end-to-end flows.
- native/scripts/generate-project.py: reproducible Xcode project generation; native/README.md: build and limitations.

### Task 1: Buildable native foundation and engine

- [x] Create package tests first for calendar date boundaries, persisted ritual uniqueness, countdown pause/resume and invalid birth input. Assertions include `XCTAssertEqual(DayKey(date: instant, timeZone: shanghai).rawValue, "2026-09-19")` for `2026-09-18T16:00:00Z`.
- [x] Run `swift test --package-path native/Core`, observe missing production behavior, then implement models and rules.
- [x] Create engine contract tests comparing all four pillars, twelve palaces and qimen method metadata against Node-generated fixtures; malformed commands return errors.
- [x] Bundle algorithms and run JavaScriptCore tests; use a serial executor and Codable JSON boundary, restore Dates inside bridge. Tool responses handle promises.
- [x] Generate Xcode app project and build for simulator with signing enabled (required for Keychain and App Group runtime verification). No remote dependency needed for app startup.

### Task 2: Native ritual, design and journaling

- [x] Implement theme tokens, native TabView, navigation and nonmandatory onboarding. App storage exposes `state: AppState`, `save()`, `revealToday()` and `recordMood(_:note:)`.
- [x] Implement drag-progress paper curl and reveal, seven-day history, daily insight, real share rendering and mood composer. Persist one entry per day; repeated reveal returns existing entry.
- [x] Build journal list/editor/trends; test editing retains identity and deleting removes persisted entry.
- [x] Capture simulator screenshots in light, dark, smaller device and large type. Verify Reduce Motion preserves the reveal operation.

### Task 3: Audio and breathing

- [x] Implement monotonic breathing clock tests: pause freezes elapsed time, resume advances from saved position, duration boundary finishes exactly once.
- [x] Implement AVAudioEngine layered ambience with documented original synthesized sounds, gain controls, fades, timer and interruptions. No downloaded assets without license provenance.
- [x] Build CalmView with one visual focus, duration control, visible phases, session completion and real playback state.
- [x] Verify pause/resume/stop and app lifecycle; simulator playback evidence is distinct from physical audio quality review.

### Task 4: Profile and all calculation flows

- [x] Add birth editor with explicit timezone, longitude and input validation; asynchronously compute profile and discard stale results.
- [x] Display four pillars, five elements, personality, twelve palaces and annual/decadal details with method caveats.
- [x] Implement candidate calibration with explicit acceptance and undo, and relationship insights without unsupported compatibility scores.
- [x] Test birth update invalidates both cached charts; real fixture comparisons and 23:00/00:00 boundaries.

### Task 5: AI and credentials

- [x] Write SSE parser tests for split JSON, CRLF, multiple events, terminal events, Unicode and errors. Example: feeding two halves of an event yields exactly one complete payload.
- [x] Implement URLSession Chat Completions / Responses adapters, Keychain and provider settings; preserve custom URL and Azure auth conventions.
- [x] Implement eight-tool orchestration with history, cancellation, iteration cap, evidence and parsed chart output; verify a stub HTTP server receives paired call IDs and prior turns.
- [x] Build readable chat UI with selectable text, history, retry, stop and all error states. Real requests only after user configuration.

### Task 6: Native extensions and portability

- [x] Implement versioned archives excluding credentials, legacy user/chat import, account-scoped data and deletion controls; test round trip and malformed archive rejection.
- [x] Implement Supabase Email/Google session and profiles through Swift; use external config, explicit sync and no production schema mutation.
- [x] Implement WidgetKit App Group snapshot, deep link, morning and solar-term notification scheduling and denial handling.
- [x] Add theme and accessibility settings; run end-to-end flows and visual review, document external account/device requirements.

### Task 7: Whole product verification

- [x] Run original Jest and tsc, Swift domain/engine/network tests and simulator UI tests.
- [x] Audit every spec requirement against code and actual runtime evidence, fix functional or visual regressions.
- [x] Refresh final screen set after the Figma refinement; retain ritual/breathing motion evidence, provide Xcode entry point and precise remaining verification limits.
- [x] Independent final review; no goal completion until all required product behavior is implemented and verified at the appropriate scope.

### Task 8: Figma-informed Eastern minimal refinement (2026-09-19)

Reference: Figma `Nk1dbVHGGPwvg0JwjxS5v6`, node `1:17`. The node is a five-image moodboard, not a directly implementable SUJI screen. Preserve the approved native product scope and interpret its paper, botanical and editorial direction.

- [x] Read the actual Figma screenshot and design context; establish cream paper, olive ink, botanical illustration and quieter typography.
- [x] Refine theme, daily paper, chat entry, breathing focus and profile hierarchy while preserving native navigation and controls.
- [x] Generate and inspect original botanical asset, integrate with light/dark/celadon themes.
- [x] Re-run hosted and UI tests; compare standard, small, dark and accessibility captures against the moodboard.
- [x] Publish local verification/design QA evidence and synchronize documentation and ledger.

Storage follow-up closed: 13 hosted tests passed, including exact legacy-artifact selection, unrelated-file retention and backup failure/retry; independent review reports no open P1/P2.
