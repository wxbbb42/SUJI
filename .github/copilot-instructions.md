# SUJI contributor instructions

SUJI's only maintained client is the native SwiftUI iPhone app. Read `README.md`, `native/README.md` and `native/VERIFICATION.md` for current behavior and tested limitations. The former Expo client was retired; `docs/archive/expo` and older design plans are historical context.

- Put native screens and services in `native/App`, shared Swift logic in `native/Core`, and widget code in `native/Widget`.
- Keep deterministic algorithms in `native/Engine/src`. Its standalone Node package builds the bundled JavaScriptCore resource; it is not another client build. Do not reintroduce Expo, React Native, Metro, Zustand or JavaScript UI dependencies.
- AI requires a Supabase account session and uses the managed `suji-chat` Edge Function with DeepSeek Flash. Provider credentials belong only in server secrets. No user-editable endpoint, model or API-key fields.
- Preserve account-scoped SwiftData notebooks, Keychain credentials, explicit profile sync and archive migration. Do not upload conversations, journals or provider keys to profiles.
- Respect the existing native visual direction, Dynamic Type, Reduce Motion and standard Apple navigation. See `native/design-qa.md` and `.impeccable.md`.
- Preserve algorithm provenance and approximation metadata. Do not invent calculation rules or present migration parity as predictive accuracy.

Run checks appropriate to the change:

```sh
TZ=America/Los_Angeles swift test --package-path native/Core
xcodebuild -project native/Suji.xcodeproj -scheme Suji -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
npm ci --prefix native/Engine
npm run typecheck --prefix native/Engine
npm test --prefix native/Engine
npm run build --prefix native/Engine
npm ci --prefix supabase
npm test --prefix supabase
```

Regenerate the Xcode project after adding Swift files with `python3 native/scripts/generate-project.py`. Commit updated engine resources after changing algorithms or dependencies, and verify Swift parity. Keep simulator signing enabled for Keychain and App Group; never share DerivedData across concurrent builds.

Never commit `.env` files, private provider/service credentials, generated `PublicConfig.plist`, dependency folders or build artifacts. Public configuration is prepared by `native/scripts/configure-public.py`; backend operations are documented in `supabase/README.md`.
