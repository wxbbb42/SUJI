"""Independent IANA normalization of public records; no person data is transmitted."""
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from zoneinfo import ZoneInfo, TZPATH

here = Path(__file__).resolve().parent
cases = json.loads((here / "public-birth-cases.json").read_text())["cases"]
rows = []
for case in cases:
    local = datetime.fromisoformat(case["localDateTime"]).replace(tzinfo=ZoneInfo(case["ianaZone"]))
    actual = local.astimezone(timezone.utc)
    expected = datetime.fromisoformat(case["instant"].replace("Z", "+00:00"))
    row = {"id": case["id"], "zone": case["ianaZone"], "offsetHours": local.utcoffset().total_seconds() / 3600,
           "normalizedInstant": actual.isoformat(), "matchesRecordedOffsetAndInstant": actual == expected and local.utcoffset().total_seconds() / 3600 == case["utcOffsetHours"]}
    rows.append(row)
versions = {}
for root in TZPATH:
    for name in ("+VERSION", "tzdata.zi"):
        p = Path(root) / name
        if p.is_file():
            versions[str(p)] = p.read_text().splitlines()[0]
result = {"method": "Python zoneinfo/IANA; independent of Date parsing and production fixed UTC+8", "zoneVersions": versions, "cases": rows}
out = Path(sys.argv[1]) if len(sys.argv) > 1 else here / "public-timezone-results.json"
out.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
assert all(row["matchesRecordedOffsetAndInstant"] for row in rows), rows
print(f"IANA historical offsets and UTC instants: {len(rows)}/{len(rows)} match")
