import hashlib,json
from pathlib import Path
p=Path(__file__).resolve().parent
sha=lambda b:hashlib.sha256(b).hexdigest()
counts={}
for manifest in ['independent-sources.json','chart-sources.json']:
    rows=json.loads((p/manifest).read_text())
    failures=0
    for r in rows:
        if 'error' in r:
            assert 'file' not in r,r
            failures+=1
            continue
        b=(p/r['file']).read_bytes()
        assert len(b)==r['bytes'] and sha(b)==r['sha256'],r['file']
        if 'textSha256' in r:
            assert sha((p/(r['file'].removesuffix('.html')+'.txt')).read_bytes())==r['textSha256'],r['file']
    counts[manifest]={'archived':len(rows)-failures,'failedFetches':failures}
rows=json.loads((p/'selected-passages.json').read_text())
for r in rows:
    t=(p/r['file']).read_text()
    assert t[r['startUnicodeCodepoint']:r['endUnicodeCodepoint']]==r['text'],r['file']
    assert sha(r['text'].encode())==r['sha256'],r['file']
counts['selected-passages.json']=len(rows)
print(json.dumps({'verified':counts,'check':'saved bytes, SHA256, extracted text bytes and exact Unicode offsets'},ensure_ascii=False))
