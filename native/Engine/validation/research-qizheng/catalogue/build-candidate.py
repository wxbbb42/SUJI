"""Generate research-only candidate from exact archived Hipparcos rows.
Unknown historical identity evidence cannot be supplied by a successful numerical check.
"""
import json,hashlib,math
from pathlib import Path
from importlib.machinery import SourceFileLoader
root=Path(__file__).resolve().parent
spec=SourceFileLoader('retrieve',str(root/'retrieve-catalogue.py')).load_module()
names=list('角亢氐房心尾箕斗牛女虚危室壁奎娄胃昴毕觜参井鬼柳星张翼轸')
rows={}
for line in (root/'hipparcos-28.tsv').read_text().splitlines():
 f=line.split()
 if len(f)==5 and f[0].isdigit(): rows[int(f[0])]=list(map(float,f[1:]))
assert len(rows)==28
stars=[]
for name,hip,designation in zip(names,spec.hip,spec.ids):
 ra,dec,pmra,pmdec=rows[hip]
 stars.append(dict(name=name,designation=designation,hip=hip,raDegrees=ra,decDegrees=dec,pmRaMasYear=pmra,pmDecMasYear=pmdec,epochYear=1991.25,sourceIDs=['hipparcos-28-esa1997','simbad-28-20260920']))
candidate=dict(id='modern-revised-chinese-distance-stars-candidate',version='2026-09-20.research.1',status='research-only-identity-source-incomplete',epochPolicy='ICRS coordinates at Julian epoch J1991.25; pmRaMasYear is mu_alpha*cos(delta), mas/Julian year',stars=stars)
(root/'mansion-catalog-candidate.json').write_text(json.dumps(candidate,ensure_ascii=False,indent=2)+'\n')
# Independent catalogue check: propagate Hip coordinates 8.75 yr to SIMBAD metadata epoch.
sim={int(x[4].split()[1]):x for x in json.loads((root/'simbad-28.json').read_text())['data']}
checks=[]
for s in stars:
 row=sim[s['hip']]; c=math.cos(math.radians(s['decDegrees']))
 ra=s['raDegrees']+8.75*s['pmRaMasYear']/3600000/c
 dec=s['decDegrees']+8.75*s['pmDecMasYear']/3600000
 separation=math.hypot((ra-row[2])*c,dec-row[3])*3600
 checks.append(dict(name=s['name'],hip=s['hip'],simbadMainID=row[1],propagatedHipVsSimbadArcseconds=separation))
assert max(x['propagatedHipVsSimbadArcseconds'] for x in checks)<1
result=dict(status='28-catalog-identities-crosschecked-not-historical-policy-accepted',sourceHashes={x:hashlib.sha256((root/x).read_bytes()).hexdigest() for x in ['hipparcos-28.tsv','simbad-28.json']},checks=checks,maxSeparationArcseconds=max(x['propagatedHipVsSimbadArcseconds'] for x in checks))
(root/'catalogue-crosscheck.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'count':len(stars),'maxCrosscheckArcseconds':result['maxSeparationArcseconds']},ensure_ascii=False))
