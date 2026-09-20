"""Research report generator, not a production acceptance test.

Usage: python compare.py output-directory
Requires isolated pyswisseph==2.10.3.2; no external Swiss ephemeris files.
Reports both default-UT and controlled-shared-TT results without hiding failures.
"""
import datetime
import hashlib
import importlib.metadata
import json
from pathlib import Path
import sys

import swisseph as S

root = Path(sys.argv[1])
assert importlib.metadata.version("pyswisseph") == "2.10.3.2"
rows = json.loads((root / "candidate.json").read_text())
jsc = json.loads((root / "jsc.json").read_text())
bodies = ["Sun", "Moon", "Mercury", "Venus", "Mars", "Jupiter", "Saturn"]
fields = ["longitude", "latitude", "rightAscensionDegrees", "declination"]
expected = {(f"{y}-{m:02d}-15T04:00:00Z", b) for y in range(1901, 2101)
            for m in [1, 4, 7, 10] for b in bodies}
assert len(rows) == len(jsc["rows"]) == len(expected) == 5600
assert {(r["instant"], r["body"]) for r in rows} == expected
assert {(r["instant"], r["body"]) for r in jsc["rows"]} == expected
assert {c["body"] for c in jsc["equalInstantChecks"]} == set(bodies)
assert all(c["equal"] for c in jsc["equalInstantChecks"])
native = {(r["instant"], r["body"]): r for r in jsc["rows"]}
flags = S.FLG_MOSEPH | S.FLG_SPEED
comparisons = {mode: {"maxima": {}, "failures": []} for mode in ["defaultUT", "sharedTT"]}
references = []
runtime_max = 0
delta_max = {"differenceSeconds": -1}

for row in rows:
    key = (row["instant"], row["body"])
    runtime_max = max(runtime_max, *(abs(row[f] - native[key][f]) for f in fields))
    date = datetime.datetime.fromisoformat(row["instant"].replace("Z", "+00:00"))
    jd = S.julday(date.year, date.month, date.day,
                 date.hour + date.minute / 60 + date.second / 3600, S.GREG_CAL)
    assert abs(jd - row["julianDayUT"]) < 1e-8
    dt = S.deltat_ex(jd, S.FLG_MOSEPH) * 86400
    difference = abs(row["deltaTSeconds"] - dt)
    if difference > delta_max["differenceSeconds"]:
        delta_max = {"differenceSeconds": difference, "instant": row["instant"],
                     "candidateSeconds": row["deltaTSeconds"], "referenceSeconds": dt}
    ref = {"instant": row["instant"], "body": row["body"], "referenceDeltaTSeconds": dt}
    for mode in comparisons:
        calc = S.calc_ut if mode == "defaultUT" else S.calc
        time = jd if mode == "defaultUT" else row["julianDayTT"]
        ecl, actual = calc(time, getattr(S, row["body"].upper()), flags)
        eq, actual_eq = calc(time, getattr(S, row["body"].upper()), flags | S.FLG_EQUATORIAL)
        assert actual & S.FLG_MOSEPH and actual_eq & S.FLG_MOSEPH
        want = dict(zip(fields, [ecl[0], ecl[1], eq[0], eq[1]]))
        errors = {f: (abs((row[f] - v + 180) % 360 - 180) if f in
                     ["longitude", "rightAscensionDegrees"] else abs(row[f] - v)) * 3600
                  for f, v in want.items()}
        ref[mode] = {"coordinates": want, "errorsArcseconds": errors}
        result = comparisons[mode]
        for f, error in errors.items():
            metric = row["body"] + "." + f
            if error > result["maxima"].get(metric, {}).get("arcseconds", -1):
                result["maxima"][metric] = {"arcseconds": error, "instant": row["instant"]}
        if any(error > 60 for error in errors.values()):
            result["failures"].append({"instant": row["instant"], "body": row["body"],
                                       "errorsArcseconds": errors})
    references.append(ref)

assert runtime_max < 1e-9, "Native runtime differs from Node beyond parity tolerance"
for result in comparisons.values():
    result["failureCount"] = len(result["failures"])
    result["status"] = "within-spike-threshold" if not result["failures"] else "exceeds-spike-threshold"
    result["maximumArcseconds"] = max(m["arcseconds"] for m in result["maxima"].values())

report = {
    "status": "research-feasible-with-time-policy-unresolved-not-production-acceptance",
    "candidate": "Astronomy Engine 2.1.19",
    "reference": f"pyswisseph {importlib.metadata.version('pyswisseph')} / Swiss Ephemeris {S.version}; explicit Moshier",
    "samples": len(rows), "range": "1901–2100, Jan/Apr/Jul/Oct 15 04:00 nominal UTC",
    "thresholdArcseconds": 60,
    "thresholdMeaning": "Preselected feasibility screen per coordinate; not an all-date error bound",
    "candidateMethod": "GeoVector(body,date,true), Ecliptic(vector), Rotation_EQJ_EQD(date); GeoVector Moon delegates to GeoMoon without separate light-time/aberration correction",
    "referenceMethod": "Geocentric apparent tropical true ecliptic/equator of date; Moshier with speed; independent default DeltaT then identical candidate TT",
    "sharedTTMeaning": "Isolates time-model differences; does NOT validate candidate TT against physical UTC",
    "timeLimitations": "Astronomy Engine approximates UTC as UT1 and uses Espenak/Meeus DeltaT; pre-UTC dates are proleptic clock labels, future DeltaT is predictive",
    "maximumDeltaTModelDifference": delta_max,
    "comparisons": comparisons,
    "nativeRuntime": {"samples": len(rows), "maximumDifferenceDegrees": runtime_max,
                      "sameInstantChecks": jsc["equalInstantChecks"],
                      "meaning": "Runtime compatibility, not independent astronomy validation"},
    "exclusions": ["traditional four residuals", "28 mansion boundaries", "houses and life degree",
                   "topocentric positions", "all-instant accuracy", "interpretation or prediction validity"],
    "inputSHA256": {name: hashlib.sha256((root / name).read_bytes()).hexdigest()
                    for name in ["candidate.json", "jsc.json"]},
}
(root / "comparison.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
(root / "reference.json").write_text(json.dumps(references, separators=(",", ":")))
print(json.dumps({"samples": len(rows), "defaultUT": comparisons["defaultUT"]["failureCount"],
                  "sharedTT": comparisons["sharedTT"]["failureCount"],
                  "runtimeMaximumDegrees": runtime_max}, indent=2))
