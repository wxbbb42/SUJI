# Final scoped review — findings closed

2026-09-20. Follow-up limited to previously reported findings and final matrix evidence. No test reruns or new review scope.

- **Task1 P2 closed:** the Swift probe writes its report under the supplied `folder`; its explicit boolean preconditions enforce reconstruction, original tomb/fanfu/triad pointers, replay and authentication. README records the final `/tmp/suji-b5b-final` run and independent-directory reproduction. Seed inputs are present in the archived evidence.
- **Task3 P3 closed:** contract, report and sample now consistently use the complete `contemporary-first-star28-equatorial-v1@1.0.0` production policy rather than the obsolete unavailable/null state.
- **Task4 P2 closed:** operation-entry and disk-hit publication checks remain present. Independently read the actual RED log: the old implementation returned the stale dossier and failed both expected assertions. The restored implementation's GREEN log records all six astronomy store tests passing. Both astronomy store and UI test classes are now explicitly selected in CI.

Final report consistency checked programmatically: all48 B5b native rows satisfy the positive checks, have no capacity error and reject source removal; all48 backend rows accept, preserve equal full/index fact counts and restore two charts each. Maxima match README:111,399 total UTF-16,30,872 per message,168,290 request bytes,57,336 native tool bytes—within unchanged120,000/32,000/262,144/60,000 limits. Astronomy all/Moon native reports preserve facts and replay; both backend cases accept and restore the complete delivered object, with157/49 facts respectively. Astronomy maxima match README:22,418 total UTF-16,6,888 per message,41,576 request bytes.

Independently recomputed both archive SHA256s and every manifest member's size/hash:294 B5b members and9 astronomy members match. This verifies evidence integrity and report agreement, not a new execution of the matrices or a global accuracy bound.

**All findings raised by this reviewer are closed.** No remaining scoped review blocker. Controller reports Engine785/Core372/backend15 and34 hosted native tests passing; final UI execution was still in progress at handoff, so this report does not predeclare that run or remote CI success. Earlier screenshots and focused UI success remain documented in Task4 evidence.
