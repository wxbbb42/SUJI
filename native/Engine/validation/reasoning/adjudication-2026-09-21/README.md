# Adjudication integration evidence — 2026-09-21

This directory checks delivery of the source-scoped rules shipped in this change. It does not establish predictive validity or complete every traditional branch. See `docs/mingli/validation/adjudication-integration-2026-09-21.md` for the implementation and remaining boundaries.

## Independent checks

- `verify-sources.mjs` checks the shipped source hashes and quoted substrings against archived electronic texts. It does not claim print-edition collation.
- `divination-capacity-fixtures.cjs` recomputes the existing 48 paired capacity inputs and five maximum-window Qimen inputs from the actual bundled engine. It injects coin draws only in its isolated test VM. These generated charts are capacity inputs, not independent rule oracles.
- `divination-native-capacity-probe.swift` exercises actual orchestration, receipt persistence, replay, retry, native reference rendering and the real `ChatClient` HTTP encoder. It uses 200-character call IDs, escaped event text, an 8,000-character user question, the full production prompt and a long draft.
- `astronomy-native-probe.swift` exercises 11 natal astronomy / Bazi single and combined requests through the actual JavaScriptCore bridge and native delivery path.
- `final-wire-decoder.mjs` independently restores the complete tool objects and every fact identity `(toolCallID, factKey, pointer, value)`, then checks them against the full originals. It invokes the real backend `providerRequest` validator and HTTP body limit. Source directories include their complete original texts and are bound by call ID, tool name and SHA256.

The large fact index shares path tokens using parent-before-child prefix nodes and exact numeric sequences; values remain in the complete tool results. Missing pointers are errors, not null values. Both the native test inverse and the separate JavaScript inverse check complete identities. No facts, source quotes, empty arrays or false values are removed to fit the request.

## Reproduce

Run from the repository root after installing `native/Engine` dependencies. Xcode's Swift compiler and JavaScriptCore are required for the native probes.

```sh
node native/Engine/validation/reasoning/adjudication-2026-09-21/verify-sources.mjs
mkdir -p /tmp/suji-adjudication-reproduce
tar -xzf native/Engine/validation/reasoning/adjudication-2026-09-21/final-capacity-evidence.tar.gz -C /tmp/suji-adjudication-reproduce
node native/Engine/validation/reasoning/adjudication-2026-09-21/final-wire-decoder.mjs /tmp/suji-adjudication-reproduce/divination
node native/Engine/validation/reasoning/adjudication-2026-09-21/final-wire-decoder.mjs /tmp/suji-adjudication-reproduce/astronomy

# Recompute the charts and recapture native requests with current code.
node native/Engine/validation/reasoning/adjudication-2026-09-21/divination-capacity-fixtures.cjs /tmp/suji-adjudication-reproduce/divination
swiftc -parse-as-library native/Core/Sources/SujiCore/*.swift native/Engine/validation/reasoning/adjudication-2026-09-21/divination-native-capacity-probe.swift -o /tmp/suji-divination-probe
TZ=America/Los_Angeles /tmp/suji-divination-probe /tmp/suji-adjudication-reproduce/divination
node native/Engine/validation/reasoning/adjudication-2026-09-21/final-wire-decoder.mjs /tmp/suji-adjudication-reproduce/divination
swiftc -parse-as-library native/Core/Sources/SujiCore/*.swift native/Engine/validation/reasoning/adjudication-2026-09-21/astronomy-native-probe.swift -o /tmp/suji-astronomy-probe
TZ=America/Los_Angeles /tmp/suji-astronomy-probe /tmp/suji-adjudication-reproduce/astronomy
node native/Engine/validation/reasoning/adjudication-2026-09-21/final-wire-decoder.mjs /tmp/suji-adjudication-reproduce/astronomy
SUJI_LIUYAO_CAPACITY_MATRIX=/tmp/suji-adjudication-reproduce/divination/fixtures.json TZ=America/Los_Angeles swift test --package-path native/Core
```

`final-capacity-evidence.tar.gz` contains only the final fixtures, actual HTTP requests, expected full facts and reports for the 53 + 11 cases. `final-capacity-manifest.json` records SHA256 for the archive, each archived member and relevant production/probe files. The requests use synthetic fixtures and local placeholder credentials; the probe captures requests without calling DeepSeek. Generated intermediate request copies and stale failed captures are excluded.
