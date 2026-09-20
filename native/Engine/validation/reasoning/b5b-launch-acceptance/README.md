# B5b complete native transport acceptance

48/48 paired Liuyao/Qimen cases pass the actual Core orchestrator, receipt persistence/replay, no-cast retry, reference rendering, ChatClient serialization and backend `providerRequest`. No external model is contacted. All 96 full charts and every original fact ID/key/pointer/value restore exactly via the independent JavaScript decoder. The native probe also requires exact tomb, fanfu and triad render evidence pointers.

The final matrix includes maximum accepted questions, 200-byte call IDs and escaped quotes, backslashes, emoji and control-character events. Observed maxima: **111,399 total UTF-16** including tool arguments, **30,872 per message**, **168,290 request bytes**. Actual provider limits remain 120,000 / 32,000 / 262,144; the total tool-byte budget remains 60,000. These are sampled maxima, not proof over all combinations.

Before the fix, 42/48 real serialized requests exceeded the 120,000 total limit; maximum127,398. `initial-*` summaries and the `initial/` archive retain that failure. Repeated reviewer group keys now use reversible group-column layouts, and batches are chosen against actual encoded size. No facts were dropped. The persisted raw-receipt guard is now64KiB; it is not a wire budget. The separate soft tool guard31,000 preserves1,000 units below the provider limit.

`bulk-evidence.tar.xz` contains `data/seed-fixtures.json`, regenerated final fixtures, actual requests, full expected facts and reports; `initial/` contains original captures. `bulk-evidence-manifest.json` identifies every member and the complete archive. The archive was read back and every member's size/hash checked. `source-hashes.json` records accepted runtime sources. Initial captures are historical red evidence, not results produced by current fixed code.

Reproduce from the repository root, with Node and macOS Swift installed:

```sh
mkdir -p /tmp/suji-b5b-replay
tar -xf native/Engine/validation/reasoning/b5b-launch-acceptance/bulk-evidence.tar.xz -C /tmp/suji-b5b-replay
node native/Engine/validation/reasoning/b5b-launch-acceptance/regenerate-fixtures.cjs /tmp/suji-b5b-replay/data
swiftc -parse-as-library native/Core/Sources/SujiCore/*.swift native/Engine/validation/reasoning/b5b-launch-acceptance/final-native-capacity-probe.swift -o /tmp/suji-b5b-native
/tmp/suji-b5b-native /tmp/suji-b5b-replay/data
node native/Engine/validation/reasoning/b5b-launch-acceptance/final-wire-decoder.mjs /tmp/suji-b5b-replay/data
```

The explicit output directory is honored by every script. A former hardcoded report path was caught in independent review and fixed before this final run, which used `/tmp/suji-b5b-final` rather than the original prototype directory. Rebuilding a changed engine or prompt can change sizes and hashes; compare against the recorded sources before treating changed output as a regression.
