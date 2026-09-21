"""Independent research: pip install pyswisseph==2.10.3.2 pyerfa==2.0.1.5.
Shared TT isolates the lunar element formula from Delta-T models. Swiss uses
its own mean-element implementation. ERFA checks the cited argument convention.
Predeclared acceptance: 1 arcsecond against Swiss for all sampled coordinates.
No Swiss code is distributed in the application.
"""
import json, math, hashlib
from pathlib import Path
import erfa
import swisseph as swe
root=Path(__file__).resolve().parent
candidate=json.loads((root/'residual-candidate.json').read_text())
assert erfa.__version__=='2.0.1.5' and str(swe.__version__)=='20230604', (erfa.__version__,swe.__version__)
reference=[]
maximum={}
failures=[]
def error(a,b): return abs((a-b+180)%360-180)*3600
for row in candidate:
    jd=row['julianDayTT']; t=(jd-2451545)/36525
    omega=erfa.faom03(t); arg=erfa.faf03(t)-erfa.fal03(t)+math.pi; inc=math.radians(5.1453964)
    erfa_values={'ascendingNodeDegrees':math.degrees(omega)%360,
        'descendingNodeDegrees':(math.degrees(omega)+180)%360,
        'apogeeLongitudeDegrees':math.degrees(omega+math.atan2(math.cos(inc)*math.sin(arg),math.cos(arg)))%360,
        'apogeeLatitudeDegrees':math.degrees(math.asin(math.sin(inc)*math.sin(arg)))}
    node,flags=swe.calc(jd,swe.MEAN_NODE,swe.FLG_MOSEPH|swe.FLG_NONUT)
    apogee,apogee_flags=swe.calc(jd,swe.MEAN_APOG,swe.FLG_MOSEPH|swe.FLG_NONUT)
    swiss={'ascendingNodeDegrees':node[0],'descendingNodeDegrees':(node[0]+180)%360,
        'apogeeLongitudeDegrees':apogee[0],'apogeeLatitudeDegrees':apogee[1]}
    reference.append({k:row[k] for k in ['instant','julianDayTT']}|{'swiss':swiss,'erfa':erfa_values,'swissFlags':[flags,apogee_flags]})
    for engine,values in [('swiss',swiss),('erfa',erfa_values)]:
        for key,value in values.items():
            e=error(row[key],value); label=engine+'.'+key
            if e>maximum.get(label,{}).get('arcseconds',-1):maximum[label]={'arcseconds':e,'instant':row['instant']}
            if e>1:failures.append({'instant':row['instant'],'coordinate':label,'arcseconds':e})
(root/'residual-reference.json').write_text(json.dumps(reference,indent=2)+'\n')
report={'samples':len(reference),'range':'1901–2100, Jan/Apr/Jul/Oct 15 04:00 UTC',
    'thresholdArcseconds':1,'timePolicy':'same production TT supplied to independent formulas',
    'pyswisseph':'2.10.3.2','swissLibrary':swe.version,'pyerfa':erfa.__version__,
    'maximumErrors':maximum,'failures':failures,
    'limitations':['Quarterly samples are not a continuous error bound.','Mean elements are not true/osculating node or apogee.','Purple Qi is a symbolic uniform convention and has no physical Swiss reference.']}
for file in ['sample-residuals.mjs','compare-residuals.py','residual-candidate.json','residual-reference.json']:
    report.setdefault('sha256',{})[file]=hashlib.sha256((root/file).read_bytes()).hexdigest()
(root/'residual-comparison.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
assert len(reference)==800 and not failures
