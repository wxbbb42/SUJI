# Research calendar evidence

Read `docs/mingli/validation/calendar-bazi-research.md` for scope and interpretation.

`baseline-differential.json` is an immutable observation captured before the calendrical rewrite at repository HEAD `df1a7c9`; do not overwrite it to make the new implementation appear to pass. It records the old lunisolar path, not the current production dependency set.

`differential.mjs` builds source in a temporary directory and writes `current-differential.json`. Reference packages are installed separately:

```sh
npm install --prefix /tmp/suji-calendar-research --no-audit --no-fund lunar-javascript@1.7.7 astronomy-engine@2.1.19
TZ=Asia/Shanghai node native/Engine/validation/research-calendar/differential.mjs
```

Set `SUJI_CALENDAR_REFS` to an alternative absolute `node_modules` directory. Neither these packages nor their licenses are silently copied into the production bundle.

After switching production to lunar-javascript, a lunar-javascript comparison tests integration, not independent astronomical truth. Independent evidence is the preserved pre-switch comparison, JDN arithmetic in permanent tests, HKO dated tables, and Astronomy Engine solar-longitude searches (264 dates, observed maximum 41-second difference; not a universal error bound). Library metadata was fetched from GitHub API on 2026-09-19; failed URLs and unrecognized licenses are left visible.
# Structural parameter sensitivity

Run `node native/Engine/validation/research-calendar/structural-sensitivity.mjs` from the repository root. It evaluates 1152 fixed calendar inputs against isolated parameter changes in temporary bundles and writes `structural-sensitivity.json`. The report is parameter sensitivity, not empirical accuracy. No production bundle or source file is rewritten. See `docs/mingli/validation/structural-threshold-sensitivity.md` for interpretation and limitations.

## Independent HKO daily reference, 1901–2100

Run `python3 native/Engine/validation/research-calendar/hko-daily-audit.py`, then `node native/Engine/validation/research-calendar/hko-daily-compare.mjs`. Requires curl, Poppler pdftotext, Python 3 and existing Engine dependencies. The first command reads only official HKO PDFs/TXT, never a lunar library; the second compares the production facade to those independently extracted facts. Ignored `hko-cache/` stores downloads and temporary artifacts. Persisted manifest/results record all 200 source files, hashes, failures/fallbacks, coverage, and every differing day.

Current result: 73,049 civil dates; 73,000 complete lunar dates plus 49 partial dates at the initial boundary. 198 PDFs parse directly; official HKO text tables recover 2048/2051 without guessing. Only 2057-09-28 through 2057-10-27 differs (30 days). See `docs/mingli/validation/hko-daily-calendar-audit.md` for precise scope and unresolved near-midnight new-moon uncertainty.
