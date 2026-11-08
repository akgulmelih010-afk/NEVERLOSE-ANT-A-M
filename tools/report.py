import json,sys
from collections import Counter
d=json.load(open(sys.argv[1]))
idx=[l.split('\t') for l in open(sys.argv[2]).read().splitlines()]
def pct(a,b): return f"{100*a//b}%" if b else "-"
out=[]
out.append('# Oyuncu analizi: tüm GameSense logları (V1.0.16 – V1.0.66)\n')
out.append('Kaynak: kullanıcının gönderdiği tüm `nykle_log.txt` dosyaları, tekrar eden satırlar tek sayıldı (43.114 tekrarsız satır, 524 oyuncu). Sayılar log satırlarından: **atış** = senin aimbot atışın (`atis:`), **isabet / kafa**, **ıska** türleri; **o→sen** = onun sana isabeti (`vuruldun:`), **duvardan** = vurulma-detay `iz duvardan`; **K / Ö** = kill-detay / olum-detay; **ilk gören** = düello satırı.\n')
# totals by bucket
B=Counter(); tot={}
for k,v in d.items():
    for b,x in v['by'].items():
        t=tot.setdefault(b,Counter())
        for f in ('shots','hits','head_hits','head_aim','head_aim_head','hit_me','head_me','wall_me','kills','deaths'):
            t[f]+=x[f]
        for m,c in x['miss'].items(): t['miss_'+m]+=c
out.append('## Sürüm grubuna göre toplam (düzeltmelerin etkisi)\n')
out.append('| Sürüm | Atış | İsabet | Kafa | Kafaya nişan → kafa | Correction | Spread | Death ıska | Sana isabet | Sana kafa | Duvardan | K / Ö |')
out.append('|---|---|---|---|---|---|---|---|---|---|---|---|')
for b in sorted(tot):
    t=tot[b]
    out.append(f"| {b} | {t['shots']} | {t['hits']} ({pct(t['hits'],t['shots'])}) | {t['head_hits']} ({pct(t['head_hits'],t['shots'])}) | {t['head_aim_head']}/{t['head_aim']} ({pct(t['head_aim_head'],t['head_aim'])}) | {t['miss_correction']} ({pct(t['miss_correction'],t['shots'])}) | {t['miss_spread']} | {t['miss_death']} | {t['hit_me']} | {t['head_me']} ({pct(t['head_me'],t['hit_me'])}) | {t['wall_me']} | {t['kills']} / {t['deaths']} |")
out.append('\n## Kişi bazında (en çok karşılaşılan 144 oyuncu)\n')
out.append('| # | Oyuncu | K / Ö | Atış | İsabet | Kafa | Correction | Spread | Diğer ıska | O→sen (kafa, duvardan) | Silahı | Ping | AA (ilk 2) | İlk gören: sen / o / aynı | Sürümler |')
out.append('|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|')
for i,(n,k,fn) in enumerate(idx):
    a=d[k]['all']; miss=a['miss']; corr=miss.get('correction',0); spr=miss.get('spread',0); oth=sum(miss.values())-corr-spr
    fs=a['first']; sen=fs.get('sen',0)+fs.get('sadece sen gordun',0); o=fs.get('o',0)+fs.get('sadece o gordu',0)
    weap='/'.join(list(a['weap'])[:2]) or '-'
    aa=', '.join(f"{x} {c}" for x,c in list(a['aa'].items())[:2]) or '-'
    vers=sorted(a['by'] if False else d[k]['by'].keys())
    name=k.replace('|','/')
    out.append(f"| {i+1} | {name} | {a['kills']} / {a['deaths']} | {a['shots']} | {a['hits']} ({pct(a['hits'],a['shots'])}) | {a['head_hits']} | {corr} ({pct(corr,a['shots'])}) | {spr} | {oth} | {a['hit_me']} ({a['head_me']}, {a['wall_me']}) | {weap} | {a['ping'] if a['ping'] is not None else '-'} | {aa} | {sen} / {o} / {fs.get('ayni anda',0)} | {', '.join(v.split(' ')[0] for v in vers)} |")
open(sys.argv[3],'w').write('\n'.join(out)+'\n')
