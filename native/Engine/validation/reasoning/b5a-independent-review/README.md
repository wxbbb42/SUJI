# B5a independent source, structure and native transport review

Reviewed uncommitted B5a against `56ee94ee9227484ae536ce10076285d0fb995f2b`. Final verdict: **pass, with the initial capacity regression fixed; no outstanding actionable finding in this scope**. The reviewer changed no production code, source registry or source archive, and made no commit.

## Source and code verdict

The three recorded observations remain separate: each actual moving original versus its own changed object; complete original/resulting three-branch trigram projections with the actual moving subset named; and explicitly selected 易林 directional pairs 乾巽、坎离、震兑、艮坤. Static projection differences never create `/lines/N/changed`. Unchanged trigrams remain `unchanged`; distinct stems can still share branches.

The code and text preserve the source disagreements: 增删25's literal 乾變坤, root118's 坤變震, and 易林's static eight-pure 伏吟 terminology are not silently folded into the selected dynamic classifier. Source scope and rendering do not establish target choice, strength, efficacy or outcome. The quoted electronic editions remain uncollated against print.

`engine-source-report.json` records:

- All **4,096** line-value patterns through the actual compiled Engine, independently compared field-for-field using modular Najia branch starts/steps, literal stems/trigram bits, branch displacement of six, and the named directional pairs. No production oracle helpers were imported.
- **12,288** actual moving-line records, **256** repeated and **256** opposed trigram projections, **1,024** unchanged trigrams, and **1,024** directional matches (eight directed pairs, 128 each).
- Five diagrams parsed directly from archived source glyphs/branches: 增删25 比→井、临→中孚、姤→恒; root 巽→升、观→升. Their original and complete resulting branch vectors agree with Engine output. 比→井 changes a static position's projected branch but only positions2/3 are actual changes; 姤→恒 retains same branches with different stems.

The source diagram runs use a fixed modern timestamp because this layer is calendar-independent. They do not reconstruct historical dates or validate transmitted outcomes.

## Native validation and exact delivery

`native-corruption-report.json`: 8 valid source/synthetic charts accepted, 20 malformed fanfu/chart variants rejected by both direct `LiuyaoFanfuTrace` reconstruction and complete rendering, and 2 source-presence/hash corruptions rejected by rendering. Includes jointly forged original and resulting trigram labels, branch projections and flags; the unchanged six saved line values expose those forgeries. All mutations verify that they changed the input.

`layout-corruption-report.json`: 46 checks cover 13 nested JSON value variants, raw value passthrough, reserved-key collisions, 28 malformed metadata/row variants, and a well-shaped value tamper rejected by delivery authentication. Malformed records yield zero verification facts. `synthetic-layout-decoder-report.json` independently restores null, empty array, empty object, booleans, integers, decimal numbers, nested values, quotes/escapes/emoji, and `__proto__`/`constructor` keys using `Object.fromEntries`; prototype keys remain data.

`final-native-capacity-report.json` and `final-wire-decoder-report.json` record **48/48** paired Liuyao/Qimen cases with 200-byte IDs and maximum-length questions/events. The matrix retains B4 selected maxima and escaped quote/backslash/emoji/control events, adding control events at the prior single-tool and paired-request maxima.

The actual Core orchestrator, saved receipt encoder, replay, no-cast retry, projection authentication, missing-source rejection and complete tomb/fanfu reference rendering all pass. Every evidence pointer has its original value and complete receipt ID. The actual `ChatClient` body is intercepted locally, then passed through the real backend `providerRequest` validator; no external provider is contacted.

Independent JavaScript restores **96 complete chart objects**, **6,851 object-layout rows**, **4,694 condition tuples** (including **862 empty path arrays**) and **336 reviewer index messages** with layouts/ID dictionaries. All reconstructed chart fields and full fact keys/pointers/IDs/values exactly match uncompressed originals; no fields are sampled or removed.

| Observed final maximum | Value | Limit |
| --- | ---: | ---: |
| Tool/message UTF-16 | 26,719 | 32,000 |
| Paired tool UTF-8 bytes | 52,008 | 60,000 |
| Complete backend UTF-16, including arguments | 116,997 | 120,000 |
| Actual ChatClient request bytes | 172,003 | 262,144 |

The highest total is control-event parents/parent, 2026-09-12T04:00:00Z, `[6,6,6,6,9,9]`, 风地观→雷天大壮, paired with career Qimen. These are observed bounded maxima, not a formal proof for all accepted input combinations.

## Preserved failure evidence

`initial-native-capacity-report.json` retains the actual pre-fix failure: 小过→中孚 at 2024-07-11 with a legal event `事` plus 199 U+0001 characters projected to **32,480** UTF-16 units, causing Liuyao capacity fallback and lost delivery/fact coverage while full saved rendering remained intact. Other ordinary requests already reached **119,207** complete backend units.

`initial-escaped-budget-report.json` documents exact substitution of that accepted event into two captured chart outputs and two argument strings. The resulting constructed pre-fix requests reached **32,888** per tool and **123,187** complete backend units. They are explicitly constructed payloads, not successful live deliveries. All three corresponding maximum contexts are regenerated through the actual Engine in the final 48-case matrix and pass with the new object layout.

`source-hashes-initial.json` and `source-hashes-final.json` identify code snapshots. Among captured sources, only `NatalEvidenceProjection.swift` and `LiuyaoConditionTransport.swift` changed between the initial and final runs. Engine/bundle and fanfu reconstruction stayed unchanged.

## Archive and reproduction

Full fixtures, initial/final requests, and expected-fact arrays are in `bulk-evidence.tar.xz`. `bulk-evidence-manifest.json` lists the archive hash and each member's byte size/SHA-256. Every member was read back and verified before loose copies were moved to temporary storage. `artifact-sha256.json` hashes retained evidence, and `source-hashes-final.json` identifies the accepted production sources.

From the repository root, using the existing Node and Swift installations:

```sh
tar -xf native/Engine/validation/reasoning/b5a-independent-review/bulk-evidence.tar.xz
node native/Engine/validation/reasoning/b5a-independent-review/engine-source-probe.cjs
node native/Engine/validation/reasoning/b5a-independent-review/regenerate-fixtures.cjs
swiftc -parse-as-library native/Core/Sources/SujiCore/*.swift native/Engine/validation/reasoning/b5a-independent-review/final-native-capacity-probe.swift -o /tmp/suji-b5a-final-native-capacity-probe
/tmp/suji-b5a-final-native-capacity-probe
node native/Engine/validation/reasoning/b5a-independent-review/final-wire-decoder.mjs
swiftc -parse-as-library native/Core/Sources/SujiCore/*.swift native/Engine/validation/reasoning/b5a-independent-review/native-corruption-probe.swift -o /tmp/suji-b5a-native-corruption-probe
/tmp/suji-b5a-native-corruption-probe
swiftc -parse-as-library native/Core/Sources/SujiCore/*.swift native/Engine/validation/reasoning/b5a-independent-review/layout-corruption-probe.swift -o /tmp/suji-b5a-layout-corruption-probe
/tmp/suji-b5a-layout-corruption-probe
node native/Engine/validation/reasoning/b5a-independent-review/synthetic-layout-decoder.cjs
```

`native-capacity-probe.swift` is the initial/red probe. Its historical numbers require the initial source snapshot; the final acceptance procedure uses `final-native-capacity-probe.swift`. Full repository suite results belong to the parent integration run and are not claimed as independent executions here.
