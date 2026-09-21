# Local calculation engine

The SwiftUI app runs these deterministic algorithms offline through JavaScriptCore. This directory contains calculation sources and tool definitions, not an app UI or an AI network client. Native Swift services own chat orchestration, authentication and storage.

From the repository root, with Node.js 20 or later:

```sh
npm ci --prefix native/Engine
npm run typecheck --prefix native/Engine
npm test --prefix native/Engine
npm run build --prefix native/Engine
TZ=America/Los_Angeles swift test --package-path native/Core
```

The package declares all its dependencies. It does not require a root `node_modules` directory, Expo, React Native or `native/tooling`. The lockfile pins MIT-licensed `lunar-javascript` 1.7.7 and `iztro` 2.5.8; `useDefineForClassFields` preserves the original compilation semantics. The Jest suite runs in Beijing time, matching the engine's supported civil timezone.

`build.mjs` bundles `bridge.ts` and `src/` into the checked-in `../Resources/mingli.js`, then creates `../Resources/engine-fixtures.json` using an independent Node process timezone. `timezone.js` adapts Date operations to Beijing time inside JavaScriptCore. The Swift core suite compares both implementations under a different host timezone. Commit regenerated resources whenever engine source or dependencies change.

`src/ai/tools` defines eight local calculations and their evidence. It performs no provider requests. The former Expo chat client, model settings, calibration session controller and network orchestration have been retired; the Swift equivalents live in `../App/Services` and `../Core`.

The initial retirement moved sources from `lib/` without rule changes. The subsequent accuracy audit corrected calendar boundaries, exact luck-cycle dates, Ziwei, Liuyao and Qimen rules; its independent evidence and remaining limits are in [the validation record](../../docs/mingli/validation/PLAN.md). Runtime parity does not establish algorithmic correctness or the predictive accuracy of traditional interpretations.
