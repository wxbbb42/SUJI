# Independent calendar and public-record audit

Research date: 2026-09-20. These files contain public historical birth facts and calculation checks, not biography-based prediction scoring. The detailed assessment is in `docs/mingli/validation/professional-audit-2026-09-20.md`.

- `public-birth-cases.json`: four public figures, permanent source URLs, recorded offsets, source ratings and conflicting/rounded times. Source notes were read; original certificates/newspapers were not independently inspected.
- `verify-public-timezones.py`: Python `zoneinfo` independently checks historical local-time → UTC normalization. The saved run uses IANA 2026c. The app does not yet offer this IANA historical-zone input workflow.
- `calendar-audit.mjs`: independent apparent solar longitude and RA/GAST from **Astronomy Engine 2.1.19**, Gregorian JDN day cycle (`JDN + 49`, consistent with 1949-10-01 甲子), five-rat hour stems and five-tiger month stems. The production engine is separately bundled into a scratch directory. The reference library is not an app dependency.
- `calendar-audit-results.json`: 62 public-record comparisons and 2,400 Jie crossings / 4,800 ±120-second four-pillar comparisons for 1901–2100. CI rechecks the 62 saved independent public expectations in `publicBirthAudit.test.ts`; the entire astronomical sweep is a separate research command.

Reproduce from the repository root (Node dependencies for `native/Engine` must already be installed):

```sh
npm install --prefix /tmp/suji-professional-reference --ignore-scripts --no-package-lock astronomy-engine@2.1.19
python3 native/Engine/validation/professional/verify-public-timezones.py /tmp/public-timezone-results.json
node native/Engine/validation/professional/calendar-audit.mjs /tmp/calendar-audit-results.json
npm test --prefix native/Engine -- --runTestsByPath src/calendar/__tests__/publicBirthAudit.test.ts
```

`SUJI_ASTRONOMY_REFERENCE` may point to another installation of that exact version. Use a working Python installation if the system shim requires Xcode license acceptance; the audit does not require accepting legal terms.

Policies: year/month switch at the physical solar term; day/hour use either the fixed UTC+8 clock or the explicitly selected apparent-solar projection, with a 23:00 day boundary. The two policies can produce different valid outputs under their stated conventions. Treating a foreign local clock as UTC+8 is a different, incorrect input normalization.

Limits: the independent ephemeris is approximate, not an official second almanac. Maximum term disagreement in this run is **62.355 seconds**, so zero differences at ±120 seconds does not prove second-level identity at crossings. The known 2057 lunar-date discrepancy is not solved by this solar-term sweep. Public `qiYun` fields are recorded production observations only and are **not independently verified by this script**. ±30-minute samples are sensitivity probes, not estimates of the historical records' actual error distribution. No birth time was rectified against later life events; no person data was sent to a model.
