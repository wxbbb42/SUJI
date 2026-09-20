"""Verify the explicitly selected contemporary first-star reference policy.
This does not adopt Stellarium's discordant historical determinative-star table.
"""
import hashlib,json
from pathlib import Path
root=Path(__file__).resolve().parent
source=root/'stellarium/contemporary-index.json'
raw=source.read_bytes(); api=json.loads((root/'stellarium/contemporary-index-api.json').read_text())
assert hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==api['sha']=='71885f2ea74edb2b8d960b0672d89fbf3e980517'
index=json.loads(raw)
candidate=json.loads((root/'mansion-catalog-candidate.json').read_text())
english=['Horn','Neck','Root','Room','Heart','Tail','Winnowing Basket','Dipper','Ox','Girl','Emptiness','Rooftop','Encampment','Wall','Legs','Bond','Stomach','Hairy Head','Net','Turtle Beak','Three Stars','Well','Ghosts','Willow','Star','Extended Net','Wings','Chariot']
checks=[]
for star,label in zip(candidate['stars'],english):
 key='HIP '+str(star['hip']); expected=label+' I'
 assert {'english':expected} in index['common_names'][key], (star,expected)
 # Unique contemporary HIP identity for each first-star name, not inferred from line order.
 matched=[k for k,v in index['common_names'].items() if {'english':expected} in v]
 assert matched==[key],matched
 checks.append(dict(name=star['name'],hip=star['hip'],modernName=expected,pointer='/common_names/'+key+'/0/english'))
result=dict(policyID='contemporary-first-star28-equatorial-v1',label='现代星名距星参照',sourceBlob=api['sha'],checks=checks,passed=len(checks)==28,scope='Select the first numbered star of each named contemporary Chinese mansion asterism. Not a historical-school reconstruction or an endorsement of every determinative-star table.',conflicts=[{'name':'奎','selected':'η And / HIP4463 / Legs I','other':'Archived historical Wikipedia table and Stellarium Chinese description determinative table use ζ And. Contemporary first-star policy intentionally selects η; no date or universal historical revision claim.'},{'name':'斗','selected':'φ Sgr / HIP92041 / Dipper I','other':'Archived Wikipedia historic table agrees φ Sgr; Stellarium Chinese description determinative table lists μ Sgr. That separate table is not adopted.'},{'name':'觜参','selected':'λ Ori / HIP26207 and ζ Ori / HIP26727','other':'Old φ¹ Ori / δ Ori pair reverses modern RA order; revised contemporary I identities agree archived Wikipedia revision narrative.'}])
(root/'contemporary-policy-check.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(dict(passed=result['passed'],count=len(checks),sourceBlob=api['sha'])))
