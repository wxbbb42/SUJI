"""Independent ERFA IAU2006/2000A reference-star transform, research only.
Requires pyerfa2.0.1.5/numpy2.0.2. Same Cartesian proper motion convention as
product, independent precession/nutation; ERFA adds frame bias while AE treats
ICRS as J2000 mean. Differences must be measured rather than called zero.
"""
import json, math
from pathlib import Path
import numpy as np
import erfa
root=Path(__file__).resolve().parent
catalog=json.loads((root/'mansion-catalog-candidate.json').read_text())
rows=[]
for epoch,ttJD in [('1901-01-01T00:00:00 TT',2415385.5),('J2000 TT',2451545.0),('2100-01-01T00:00:00 TT',2488069.5)]:
 year=2000+(ttJD-2451545)/365.25
 matrix=erfa.pnm06a(2451545.0,ttJD-2451545.0)
 stars=[]
 for s in catalog['stars']:
  ra,dec=map(math.radians,[s['raDegrees'],s['decDegrees']]); cr,sr,cd,sd=math.cos(ra),math.sin(ra),math.cos(dec),math.sin(dec)
  position=np.array([cd*cr,cd*sr,sd]); alpha=np.array([-sr,cr,0]); delta=np.array([-sd*cr,-sd*sr,cd])
  velocity=(s['pmRaMasYear']*alpha+s['pmDecMasYear']*delta)*math.pi/(180*3600000)
  vector=position+velocity*(year-s['epochYear']); vector/=np.linalg.norm(vector)
  eqd=matrix@vector; a,d=erfa.c2s(eqd)
  stars.append(dict(name=s['name'],hip=s['hip'],raDegrees=math.degrees(a)%360,decDegrees=math.degrees(d)))
 # Validate raw cyclic traversal by exactly one negative jump, then unwrap only that crossing.
 ras=[s['raDegrees'] for s in stars]; gaps=[ras[(i+1)%28]-ras[i] for i in range(28)]
 assert sum(g<0 for g in gaps)==1
 gaps=[g+360 if g<0 else g for g in gaps]
 assert all(g>0 for g in gaps) and abs(sum(gaps)-360)<1e-10
 rows.append(dict(epoch=epoch,ttJulianDate=ttJD,stars=stars,minimumWidthDegrees=min(gaps),maximumWidthDegrees=max(gaps),widthSumDegrees=sum(gaps)))
result=dict(status='independent-transform-reference-research-candidate-only',erfaVersion=erfa.__version__,method='Cartesian tangent proper motion without distance/radial velocity; ERFA pnm06a includes IAU2006 precession, IAU2000A nutation, frame bias; no aberration/parallax/deflection',rows=rows)
(root/'erfa-transform-reference.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps([dict(epoch=r['epoch'],minimumWidthDegrees=r['minimumWidthDegrees'],widthSumDegrees=r['widthSumDegrees']) for r in rows]))
