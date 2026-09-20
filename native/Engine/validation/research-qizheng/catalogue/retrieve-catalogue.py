"""Reproduce candidate catalogue queries; does not resolve historical mansion identities.
Run python3 retrieve-catalogue.py. Overwrites two raw source files in this directory.
"""
import subprocess
from pathlib import Path
root = Path(__file__).resolve().parent
hip = [65474,69427,72622,78265,80112,82514,88635,92041,100345,102618,106278,109074,113963,1067,4463,8903,12719,17499,20889,26207,26727,30343,41822,42313,46390,48356,53740,59803]
ids = ['* alf Vir','* kap Vir','* alf02 Lib','* pi Sco','* sig Sco','* mu01 Sco','* gam02 Sgr','* phi Sgr','* bet01 Cap','* eps Aqr','* bet Aqr','* alf Aqr','* alf Peg','* gam Peg','* eta And','* bet Ari','35 Ari','17 Tau','* eps Tau','* lam Ori','* zet Ori','* mu Gem','* tet Cnc','* del Hya','* alf Hya','* ups01 Hya','* alf Crt','* gam Crv']
query = "SELECT i.id,b.main_id,b.ra,b.dec,h.id as hip FROM ident AS i JOIN basic AS b ON i.oidref=b.oid JOIN ident AS h ON h.oidref=b.oid WHERE i.id IN (" + ','.join("'"+v+"'" for v in ids) + ") AND h.id LIKE 'HIP %'"
requests = [
 ('https://vizier.cds.unistra.fr/viz-bin/asu-tsv', {'-source':'I/239/hip_main','HIP':','.join(map(str,hip)), '-out':'HIP,RAICRS,DEICRS,pmRA,pmDE'}, 'hipparcos-28.tsv'),
 ('http://simbad.cds.unistra.fr/simbad/sim-tap/sync', {'request':'doQuery','lang':'adql','format':'json','query':query}, 'simbad-28.json')]
if __name__ == '__main__':
 for url,params,filename in requests:
  cmd=['curl','-4','-f','-L','--connect-timeout','8','--max-time','45','-sG',url]
  for k,v in params.items(): cmd += ['--data-urlencode', k+'='+v]
  subprocess.run(cmd+['-o',str(root/filename)],check=True)
