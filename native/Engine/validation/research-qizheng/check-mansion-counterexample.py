"""Read-only research example using archived catalogue data, not a宿界算法.

Run with Python 3. Coordinates are compared within each catalogue's epoch only.
"""
import json
from pathlib import Path

root = Path(__file__).resolve().parent
simbad = json.loads((root / "sources/orion-simbad.json").read_text())
identity = {row[0]: row[1] for row in simbad["data"]}
assert identity == {"HIP 25930": "* del Ori", "HIP 26176": "* phi01 Ori",
                    "HIP 26207": "* lam Ori", "HIP 26727": "* zet Ori"}
assert "CT.epoch=J2000" in simbad["metadata"][2]["utype"]
j2000 = {int(row[0].split()[1]): row[2] for row in simbad["data"]}
hip_text = (root / "sources/orion-hipparcos.tsv").read_text()
assert "Epoch=J1991.25" in hip_text
j1991 = {}
for line in hip_text.splitlines():
    fields = line.split()
    if len(fields) == 5 and fields[0].isdigit():
        j1991[int(fields[0])] = float(fields[1])
assert j1991.keys() == j2000.keys()
results = []
for epoch, coords in [("Hipparcos ICRS J1991.25", j1991), ("SIMBAD ICRS J2000", j2000)]:
    old = coords[25930] - coords[26176]  # δ minus φ1: the old 觜→参 ordering
    revised = coords[26727] - coords[26207]  # ζ minus λ: later identifications
    assert -1 < old < 0 and 1 < revised < 2
    results.append({"coordinateEpoch": epoch, "oldPairSignedRADegrees": old,
                    "oldPairBlindModuloDegrees": old % 360,
                    "revisedPairSignedRADegrees": revised})
print(json.dumps({"status": "counterexample-reproduced", "results": results,
                  "scope": "star ordering only; no apparent-of-birth transformation or production mansion assignment"},
                 ensure_ascii=False, indent=2))
