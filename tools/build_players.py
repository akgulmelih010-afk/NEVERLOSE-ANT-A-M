import re,sys,os,json,glob
from collections import defaultdict,Counter
src=sys.argv[1]; out=sys.argv[2]
files=sorted(glob.glob(os.path.join(src,'*.txt')))
VER=re.compile(r'\] V(1\.0\.\d+) \(GameSense edition\) yuklendi')
seen={}; order=[]
for f in files:
    txt=open(f,encoding='utf-8',errors='ignore').read().splitlines()
    if not any('(GameSense edition) yuklendi' in l for l in txt): continue
    cur=None
    for i,l in enumerate(txt):
        m=VER.search(l)
        if m: cur=m.group(1)
        if l not in seen:
            seen[l]=cur; order.append(l)
        elif seen[l] is None and cur is not None:
            seen[l]=cur
AUTOS={'scar20','g3sg1'}
ZW=re.compile('[​‌‍⁠﻿]')
def nm(s): return ZW.sub('',s).strip()
def bucket(v):
    if v is None: return '?'
    n=int(v.split('.')[2])
    for lo,hi,b in ((16,21,'A 16-21'),(22,33,'B 22-33'),(34,44,'C 34-44'),(45,50,'D 45-50'),(51,58,'E 51-58'),(59,61,'F 59-61'),(62,99,'G 62-67')):
        if lo<=n<=hi: return b
    return '?'
def new(): return {'shots':0,'hits':0,'head_hits':0,'head_aim':0,'head_aim_head':0,'miss':Counter(),'aa':Counter(),'arm':Counter(),'state':Counter(),
  'hit_me':0,'head_me':0,'auto_hit':0,'auto_death':0,'nonauto_hit':0,'nonauto_head':0,'dmg_me':0,'wall_me':0,'weap':Counter(),'kills':0,'deaths':0,'first':Counter(),'ping':[],'my_weapon':Counter(),'versions':Counter()}
P=defaultdict(new); PB=defaultdict(lambda:defaultdict(new))
lines_by=defaultdict(list)
for l in order:
    v=seen[l]; b=bucket(v)
    who=None
    m=re.search(r'\] atis: (.+?) \| ([A-Za-z][A-Za-z ]*?) \| HP',l)
    if m:
        who=nm(m.group(1))
        for p in (P[who],PB[who][b]):
            p['shots']+=1; p['versions'][v]+=1
            if '| isabet ' in l: p['hits']+=1
            if '| isabet head' in l: p['head_hits']+=1
            if '| hedef head' in l:
                p['head_aim']+=1
                if '| isabet head' in l: p['head_aim_head']+=1
            mm=re.search(r'\| iska ([a-z ]+?) \|',l)
            if mm: p['miss'][mm.group(1)]+=1
            aa=re.search(r'\| AA ([^|]*)',l); p['aa'][re.sub(r'\d+','',aa.group(1)).strip() if aa else '-']+=1
            ar=re.search(r'\| res (\S+)',l); p['arm'][ar.group(1) if ar else '-']+=1
            p['state'][m.group(2)]+=1
            sw=re.search(r'\| sen (\S+)',l); p['my_weapon'][sw.group(1) if sw else '?']+=1
    m=re.search(r'vuruldun: (\S+(?: \S+)?) -(\d+) (\S+) \|.*\| sen \S+(?: [A-Z]+)? \| (.+?) \(',l)
    if m and who is None:
        who=nm(m.group(4))
        for p in (P[who],PB[who][b]):
            p['hit_me']+=1; p['dmg_me']+=int(m.group(2)); p['weap'][m.group(3)]+=1
            if m.group(1)=='head': p['head_me']+=1
            if m.group(3) in AUTOS: p['auto_hit']+=1
            else:
                p['nonauto_hit']+=1
                if m.group(1)=='head': p['nonauto_head']+=1
    m=re.search(r'dbg vurulma-detay: (.+?) \S+(?: \S+)? -\d+ \S+ \| iz duvardan',l)
    if m:
        w=nm(m.group(1)); P[w]['wall_me']+=1; PB[w][b]['wall_me']+=1; who=who or w
    m=re.search(r'dbg kill-detay: (.+?) (?:[a-z0-9_]+)(?: headshot)?(?:, duvardan \(\d\))? \|',l)
    if m:
        w=nm(m.group(1)); P[w]['kills']+=1; PB[w][b]['kills']+=1; who=who or w
    m=re.search(r'dbg olum-detay: (.+?) ([a-z0-9_]+)(?: headshot)?(?:, duvardan \(\d\))? \|',l)
    if m:
        w=nm(m.group(1)); P[w]['deaths']+=1; PB[w][b]['deaths']+=1; who=who or w
        if m.group(2) in AUTOS: P[w]['auto_death']+=1; PB[w][b]['auto_death']+=1
    m=re.search(r'dbg duello: (.+?) @.*?ilk goren: (sadece sen gordun|sadece o gordu|ayni anda|sen|o)\b',l)
    if m:
        w=nm(m.group(1)); P[w]['first'][m.group(2)]+=1; PB[w][b]['first'][m.group(2)]+=1; who=who or w
    m=re.search(r'(?:atis-detay|vurulma-detay|duello): (.+?) (?:@|\S+(?: \S+)? -\d+ \S+ \|).*? ping(\d+)',l)
    if m:
        w=nm(m.group(1)); P[w]['ping'].append(int(m.group(2))); who=who or w
    if who is None:
        m=re.search(r'\] (?:resolver|dbg [a-z-]+): ([^|:]+?)(?: [A-Z][a-z]+(?: [a-z]+)?)? (?:\||sahte|seri|tanindi|hafiza|AA|iska|isabet|\d+ resolver|jitter|xway|static|spin|random|sadece|0\.)',l)
        if m: who=nm(m.group(1))
    if who: lines_by[who].append(f'[{v}] {l}')
def fin(p):
    q=dict(p)
    for k in ('miss','aa','arm','state','weap','first','my_weapon','versions'): q[k]=dict(p[k].most_common())
    pg=sorted(p['ping']); q['ping']=pg[len(pg)//2] if pg else None
    return q
res={k:{'all':fin(v),'by':{b:fin(x) for b,x in PB[k].items()}} for k,v in P.items()}
json.dump(res,open(os.path.join(out,'players.json'),'w'),ensure_ascii=False,indent=0)
safe=lambda s: re.sub(r'[^A-Za-z0-9_.-]','_',s)[:40] or 'x'
idx=[]
for k,v in P.items():
    n=v['shots']+v['hit_me']+v['kills']+v['deaths']
    if n>=12:
        idx.append((n,k))
idx.sort(reverse=True)
idx=[(n,k,f'{i+1:03d}_'+safe(k)+'.txt') for i,(n,k) in enumerate(idx)]
for n,k,fn in idx:
    open(os.path.join(out,'players',fn),'w').write('\n'.join(lines_by[k]))
open(os.path.join(out,'players_index.tsv'),'w').write('\n'.join(f'{n}\t{k}\t{fn}' for n,k,fn in idx))
print('unique lines',len(order),'players',len(P),'players>=12',len(idx))
