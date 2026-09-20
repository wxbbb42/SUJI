# Astronomy native delivery acceptance

Two cases (`all`, `Moon`) run the actual bundled engine through macOS JavaScriptCore, create and validate a full native astronomy payload, then inject that snapshot into the bounded tool. The real Core orchestrator, receipt replay, ChatClient body encoder and backend `providerRequest` preserve every delivered body/mansion field and evidence fact. The Moon subset retains Moon identity at position0. No provider request leaves the machine.

Both cases pass. Observed maximum total22,418 UTF-16 including arguments, maximum message6,888 and body41,576 bytes. These do not establish bounds for arbitrary combined tools or prose accuracy. The native probe asserts complete roundtrip and receipt reuse, and removing the tool-call definition yields zero facts. Because astronomy is delivered inline, its body itself remains complete without cross-result references; this is distinct from the Liuyao projected-question authentication case.

The archive includes generated JSC fixtures, captured requests, complete expected facts and both reports. Every archive member was read back and verified against `bulk-evidence-manifest.json`; runtime inputs are recorded in `source-hashes.json`. The independent decoder expands reviewer schemas and compares full keys, original pointers, receipt IDs and values.

Reproduce from the repository root:

```sh
swiftc -parse-as-library native/Core/Sources/SujiCore/*.swift native/Engine/validation/reasoning/astronomy-launch/native-probe.swift -o /tmp/suji-astronomy-native
/tmp/suji-astronomy-native /tmp/suji-astronomy-replay
node native/Engine/validation/reasoning/astronomy-launch/wire-check.mjs /tmp/suji-astronomy-replay
```

Independent ephemeris and catalogue/ERFA accuracy evidence lives separately under `validation/research-qizheng/`; runtime agreement and faithful delivery do not independently prove astronomy accuracy or traditional predictive claims.
