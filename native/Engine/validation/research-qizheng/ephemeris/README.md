# Seven-body ephemeris feasibility probe

Research only, 2026-09-20. None of these scripts is imported by the app, bundled in
`mingli.js`, or exposed to the model. This is not a 七政四余排盘 implementation.

## Reproduce

Use a separate directory for dependencies; the app's package manifest stays unchanged.
macOS, Node 20+, Python 3 and Swift/JavaScriptCore are required. For example, from
this directory (choose a fresh scratch path):

```sh
mkdir -p /tmp/suji-ephemeris-reproduction
npm install --prefix /tmp/suji-ephemeris-reproduction/js astronomy-engine@2.1.19
python3 -m venv /tmp/suji-ephemeris-reproduction/python
/tmp/suji-ephemeris-reproduction/python/bin/pip install pyswisseph==2.10.3.2
node sample.cjs /tmp/suji-ephemeris-reproduction/js/node_modules/astronomy-engine /tmp/suji-ephemeris-reproduction/output
TZ=America/Los_Angeles swift sample-jsc.swift /tmp/suji-ephemeris-reproduction/js/node_modules/astronomy-engine /tmp/suji-ephemeris-reproduction/output
/tmp/suji-ephemeris-reproduction/python/bin/python compare.py /tmp/suji-ephemeris-reproduction/output
```

`compare.py` validates sample identities, native runtime parity and offset-formatted
same-instant checks. Its successful exit means the **report was generated**; inspect
both comparison statuses. It deliberately preserves the 13 default-time failures.

## Observed result

The preselected feasibility screen was 60 arcseconds per coordinate. The sample is
800 quarterly dates in 1901–2100, seven bodies each: Sun, Moon, Mercury, Venus, Mars,
Jupiter and Saturn. Longitude, latitude, right ascension and declination are compared.

| Comparison | Rows exceeding screen | Largest difference |
| --- | ---: | ---: |
| Same nominal UT, each library's default ΔT | 13 / 5,600 | 74.0525 arcsec |
| Same TT, isolating the ΔT model difference | 0 / 5,600 | 21.4853 arcsec |
| Node vs macOS JavaScriptCore | 0 / 5,600 at 1e-9 degree parity tolerance | 5.685e-14 degrees |

The default-time failures are Moon samples from 2093 onwards. At the largest
ΔT difference, 2100-10-15, Astronomy Engine uses 204.5048 seconds and Swiss uses
93.5469 seconds. Aligning TT explains the threshold failures; it **does not prove**
which future ΔT estimate is right. All seven bodies also agree exactly for the same
instant expressed with Z, +08:00 and -07:00 offsets in JavaScriptCore, while the host
process uses America/Los_Angeles.

Frames: candidate uses `GeoVector(body,date,true)`, then `Ecliptic` and
`Rotation_EQJ_EQD`. Do not substitute `EclipticLongitude`: that API is heliocentric.
Despite general `GeoVector` documentation, its Moon branch calls `GeoMoon`
directly, without separate light-time/aberration correction. Swiss uses geocentric
apparent tropical true ecliptic/equator of date and **explicit Moshier**, checked
against returned flags. Differences include approximation and correction choices;
this is not a statement that both implementations use identical physics.

Astronomy Engine approximates UTC as UT1 and applies Espenak/Meeus ΔT. Historical
pre-UTC labels here are proleptic civil labels, not a reconstruction of historical
UTC. The product must choose and version its time policy before accepting boundary
decisions. No inference about 四余、距星、宿界、命度、十二宫 or predictions is tested.
Quarterly sampling is not an all-instant precision guarantee or a boundary sweep.

## Dependency assessment and evidence

- Candidate: [Astronomy Engine](https://github.com/cosinekitty/astronomy), 2.1.19,
  MIT notice verified in the distributed browser source. Browser minified build:
  116,424 bytes, gzip 46,756 bytes, SHA256
  `f41139a87941ea017ab902b954c9389fa27ea72083d7fab4971756d7769d14e6`.
  This is package size, not a measured final app-size increment.
- Independent reference: pyswisseph 2.10.3.2 / Swiss Ephemeris 2.10.03. Package
  metadata declares AGPLv3. Used only in the isolated research interpreter; no
  reference source, binary or dependency is added to the product.
- `results/comparison.json` holds both outcomes and all per-body maxima/failures.
  Compressed candidate, reference and native rows are retained with byte hashes in
  `results/manifest.json`. Runtime timestamps may vary on reproduction.
- These results support further evaluation of the local candidate. They do not
  accept a production astronomy policy or a traditional interpretation system.
