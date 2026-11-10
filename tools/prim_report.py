#!/usr/bin/env python3
"""Nykle.win log raporu (primordial + GameSense bicimleri).

Kullanim: python3 -I tools/prim_report.py LOG [--from-line N] [--prev ESKI_LOG]
Tek dosyadan kisa bir ozet cikarir: skor, atislar, yenen mermiler (durum / DT / DEF / faz / duvar),
ilk mermi tablosu, duellolar, exploit satirlari, deney satirlari. --prev ile onceki logla karsilastirir.
"""
import re
import sys
from collections import Counter, defaultdict

TS = re.compile(r'^(\d\d:\d\d(?::\d\d)?(?:\.\d)?) \[Nykle\.win\] (.*)$')
HG = ('head', 'neck', 'chest', 'stomach', 'left arm', 'right arm', 'left leg', 'right leg', 'generic', 'gear')


def secs(t):
    p = [float(x) for x in t.split(':')]
    return p[0] * 3600 + p[1] * 60 + p[2] if len(p) == 3 else p[0] * 60 + p[1]


def norm(n):
    return n.replace('\u200b', '').strip()


def pct(a, b):
    return '%3.0f%%' % (100.0 * a / b) if b else '  - '


def hitgroup(text):
    for h in HG:
        if text.startswith(h):
            return h
    return text.split()[0] if text.split() else '?'


def parse(path, from_line=1):
    r = {'versions': [], 'lines': 0, 'unknown': Counter(), 'errors': [], 'shots': [], 'hurt': [], 'emiss': [],
         'kills': [], 'deaths': [], 'duels': [], 'sikmadi': Counter(), 'tp': Counter(), 'tp_no': Counter(),
         'def_shift': Counter(), 'def_refill': [], 'def_unspent': 0, 'waits': Counter(), 'peek': Counter(),
         'levels': 0, 'last': {}, 'wall': Counter(), 'wall_head': Counter(), 'first_t': None, 'last_t': None,
         'maps': Counter(), 'events': [], 'vis': 0, 'vis_def': 0, 'esc': Counter(), 'fake': Counter()}
    known = ('dbg ', 'resolver:', 'teleport', 'ai peek', 'def:', 'aa:', 'atis ozeti', 'round', 'harita', 'faz',
             'log ', 'teshis', 'afk', 'otomatik afk', 'script', 'UYARI', 'hafiza', 'anti-brute', 'brute', 'dusman ozeti',
             'detayli log', 'inis tahmini', 'duvar avi', 'ideal tick', 'safe', 'air lc', 'backstab', 'sarj', 'DT ',
             'duvar kacisi', 'AA (', 'geri cekilme')
    with open(path, encoding='utf-8', errors='replace') as f:
        for no, raw in enumerate(f, 1):
            if no < from_line:
                continue
            m = TS.match(raw.rstrip('\n'))
            if not m:
                continue
            r['lines'] += 1
            t, b = secs(m.group(1)), m.group(2)
            r['first_t'] = t if r['first_t'] is None else r['first_t']
            r['last_t'] = t
            mv = re.match(r'V(\S+) \((\w+) edition\) yuklendi', b)
            if mv:
                r['versions'].append((m.group(1), mv.group(1), mv.group(2)))
                continue
            if 'hata verdi' in b or b.startswith('UYARI'):
                r['errors'].append(b[:140])
            parts = [p.strip() for p in b.split('|')]
            if b.startswith('atis:'):
                hit = next((p for p in parts if p.startswith('isabet')), None)
                miss = next((p for p in parts if p.startswith('iska')), None)
                aim = next((p for p in parts if p.startswith('hedef')), '')
                reason = miss.split(None, 1)[1] if miss and ' ' in miss else ('?' if miss else None)
                r['shots'].append({'t': t, 'enemy': norm(parts[0][5:]), 'state': parts[1] if len(parts) > 1 else '?',
                                   'aim': aim.split()[1] if len(aim.split()) > 1 else '?',
                                   'hit': hitgroup(hit[7:]) if hit else None, 'reason': reason})
            elif b.startswith('vuruldun:'):
                head = parts[0][9:].strip()
                att = norm(re.split(r' \(', parts[-1])[0]) if len(parts) > 5 else '?'
                last = parts[-1]
                if not re.search(r'\(', last) and len(parts) > 6:
                    cand = [p for p in parts if re.search(r'\((Standing|Moving|Slow walk|Crouch|Air|Peek|Fake)', p)]
                    if cand:
                        att, last = norm(cand[0].split(' (')[0]), cand[0]
                ex = next((p for p in parts if p.startswith('DT ') or p.startswith('HS')), '')
                dt = 'dolu' if 'DT dolu' in ex else ('%0' if 'DT %0' in ex else ('kismi' if 'DT %' in ex else
                     ('HS' if ex.startswith('HS') else '?')))
                faz = ' '.join(next((p for p in parts if p.startswith('faz')), 'faz ?').split()[:2])
                r['hurt'].append({'t': t, 'hg': hitgroup(head), 'weapon': head.split()[-1], 'state': parts[1],
                                  'dt': dt, 'def': 'DEF acik' in ex or ('DEF' in ex and 'DEF yok' not in ex),
                                  'faz': faz, 'att': att, 'seen': 'gormedi' not in last, 'fatal': False})
            elif b.startswith('iska:'):
                cand = [p for p in parts if '(' in p and ('gordu' in p or 'gormedi' in p or 'AA hedefi' in p)]
                if cand:
                    faz = ' '.join(next((p for p in parts if p.startswith('faz')), 'faz ?').split()[:2])
                    r['emiss'].append({'t': t, 'att': norm(cand[0].split(' (')[0]), 'state': parts[0][5:].strip(),
                                       'faz': faz})
            elif b.startswith('oldurdun:'):
                r['kills'].append({'t': t, 'enemy': norm(parts[0][9:]), 'hs': 'headshot' in b})
            elif b.startswith('oldun:'):
                r['deaths'].append({'t': t, 'enemy': norm(parts[0][6:])})
            elif b.startswith('dbg duello:'):
                d = {'t': t, 'enemy': norm(parts[0][11:]), 'res': parts[-1], 'first': '?'}
                for p in parts:
                    if p.startswith('ilk goren:'):
                        d['first'] = p[10:].split()[0]
                mdur = re.search(r'\| ([\d.]+)s \|', b)
                d['dur'] = float(mdur.group(1)) if mdur else None
                r['duels'].append(d)
            elif b.startswith('dbg sikmadi:'):
                for why in (parts[1].split(',') if len(parts) > 1 else ['?']):
                    r['sikmadi'][re.sub(r'\d+', 'N', why.strip())[:40]] += 1
            elif b.startswith('dbg vurulma-detay:'):
                k = 'duvardan' if 'iz duvardan' in b else ('acik' if 'iz acik' in b else None)
                mh = re.search(r'(head|neck|chest|stomach|left arm|right arm|left leg|right leg) -', b)
                if k and mh:
                    r['wall'][k] += 1
                    r['wall_head'][k] += mh.group(1) == 'head'
            elif b.startswith('teleport:') or b.startswith('teleport sonucu'):
                if 'inise yok' in b:
                    mm = re.search(r'\((.*?)\)', b)
                    r['tp_no'][re.sub(r'\d+', 'N', mm.group(1)) if mm else '?'] += 1
                elif 'kala' in b or 'isinlanildi' in b:
                    r['tp']['atildi'] += 1
                elif 'vuruldun' in b:
                    r['tp']['sonra vuruldu'] += 1
                elif 'kapali' in b:
                    r['tp']['kapandi'] += 1
            elif b.startswith('def: shift sarj harcamadi'):
                r['def_unspent'] += 1
            elif b.startswith('def: shift'):
                mm = re.search(r'\((\w+)\)', b)
                mn = re.search(r'\+(\d+) yazilmadi', b)
                r['def_shift'][mm.group(1) if mm else '?'] += 1 + (int(mn.group(1)) if mn else 0)
            elif b.startswith('def: sarj'):
                mm = re.search(r'sarj (\d+) tick', b)
                if mm:
                    r['def_refill'].append(int(mm.group(1)))
            elif b.startswith('resolver:'):
                if 'gercek kayit beklendi' in b or 'taze kayit beklendi' in b:
                    r['waits']['sinir doldu' if 'sinir doldu' in b else ('gercek kayit geldi' if 'geldi' in b else 'diger')] += 1
                elif 'seviye' in b:
                    r['levels'] += 1
            elif b.startswith('ai peek'):
                key = 'baslangic' if '->' in b and 'birim ->' in b else ('atis olmadi' if 'atis olmadi' in b else
                      ('isabet' if 'isabet' in b else ('vuruldun' if 'vurul' in b else 'diger')))
                r['peek'][key] += 1
            elif b.startswith('duvar kacisi'):
                key = ('nokta yok' if 'nokta yok' in b else 'yine vuruldu' if 'yine vuruldun' in b else
                       'temiz' if 'vurulmadin' in b else 'varildi' if 'varildi' in b else
                       'yarida' if 'yarida' in b else 'basladi')
                r['esc'][key] += 1
            elif b.startswith('dbg sen ozeti'):
                mm = re.search(r"gorulurken (\d+) tick, DEF'li (\d+)", b)
                if mm:
                    r['vis'] += int(mm.group(1))
                    r['vis_def'] += int(mm.group(2))
            elif b.startswith('dbg harita') or b.startswith('===== harita'):
                r['maps'][b[:60]] += 1
            if b.startswith('atis:') and ('| isabet' in b or '| iska' in b):
                hit = 1 if '| isabet' in b else 0
                if 'def (sahte kayit)' not in b:
                    r['fake'][('r', hit)] += 1
                else:
                    r['fake'][('w' if 'bekleme: ' in b else 'n', hit)] += 1
            for key in ('faz karsilastirma', 'resolver karsilastirma', 'harita ozeti', 'dbg teshis', 'olum nedenleri',
                        'teleport testi', 'geri cekilme testi',
                        'ai peek karsilastirma'):
                if b.startswith(key):
                    r['last'][key] = b
            if not b.startswith(('atis:', 'vuruldun:', 'iska:', 'oldurdun:', 'oldun:') + known):
                r['unknown'][b.split(':')[0][:28]] += 1
    # oldurucu mermi: olumden hemen once / ayni anda gelen son isabet
    for d in r['deaths']:
        best = None
        for h in r['hurt']:
            if abs(h['t'] - d['t']) <= 1.0 and (best is None or abs(h['t'] - d['t']) <= abs(best['t'] - d['t'])):
                best = h
        if best is not None:
            best['fatal'] = True
    return r


def table(title, rows, cols):
    print(title)
    for key, vals in rows:
        print('  %-26s %s' % (str(key)[:26], '  '.join(cols[i] % v if not isinstance(v, str) else v
                                                         for i, v in enumerate(vals))))


def head_table(title, items, keyfn):
    g = defaultdict(lambda: [0, 0])
    for h in items:
        k = keyfn(h)
        g[k][0] += 1
        g[k][1] += h['hg'] == 'head'
    rows = sorted(g.items(), key=lambda kv: -kv[1][0])[:10]
    table(title, [(k, (v[0], pct(v[1], v[0]))) for k, v in rows], ('%4d mermi', 'kafa %s'))


def headline(r):
    shots = r['shots']
    hits = [s for s in shots if s['hit']]
    heads = [s for s in hits if s['hit'] == 'head']
    hurt = r['hurt']
    dur = max(1.0, (r['last_t'] or 0) - (r['first_t'] or 0))
    return {'K': len(r['kills']), 'D': len(r['deaths']), 'atis': len(shots), 'isabet': len(hits), 'kafa': len(heads),
            'yenen': len(hurt), 'yenen_kafa': sum(h['hg'] == 'head' for h in hurt),
            'duvar': r['wall']['duvardan'], 'acik': r['wall']['acik'],
            'shift_dk': 60.0 * sum(r['def_shift'].values()) / dur, 'dk': dur / 60.0}


def report(r, prev=None):
    h = headline(r)
    print('== BASLIK ==')
    print('  satir %d, sure %.0f dk, yukleme: %s' % (r['lines'], h['dk'], ', '.join('%s V%s %s' % v for v in r['versions']) or '?'))
    if r['errors']:
        print('  HATA / UYARI %d: %s' % (len(r['errors']), ' || '.join(sorted(set(r['errors']))[:4])))
    print('== SKOR ==')
    print('  K %d  D %d  KD %.2f | atis %d  isabet %s  kafa/atis %s | yenen mermi %d  kafa %s' % (
        h['K'], h['D'], h['K'] / max(1, h['D']), h['atis'], pct(h['isabet'], h['atis']), pct(h['kafa'], h['atis']),
        h['yenen'], pct(h['yenen_kafa'], h['yenen'])))
    reasons = Counter(s['reason'] for s in r['shots'] if s['reason'])
    if reasons:
        print('  iska nedenleri: ' + ', '.join('%s %d' % kv for kv in reasons.most_common(8)))
    aimed = Counter(); aimed_head = Counter()
    for s in r['shots']:
        aimed[s['aim']] += 1
        aimed_head[s['aim']] += s['hit'] == 'head'
    if aimed:
        print('  nisan: ' + ', '.join('%s %d (kafa %s)' % (k, v, pct(aimed_head[k], v)) for k, v in aimed.most_common(4)))

    print('== DUSMAN BASINA ==')
    en = defaultdict(lambda: Counter())
    for k in r['kills']:
        en[k['enemy']]['k'] += 1
    for d in r['deaths']:
        en[d['enemy']]['d'] += 1
    for s in r['shots']:
        e = en[s['enemy']]
        e['s'] += 1
        e['h'] += bool(s['hit'])
        e['hh'] += s['hit'] == 'head'
    for x in r['hurt']:
        e = en[x['att']]
        e['b'] += 1
        e['bh'] += x['hg'] == 'head'
    for x in r['emiss']:
        en[x['att']]['bm'] += 1
    rows = sorted(en.items(), key=lambda kv: -(kv[1]['k'] + kv[1]['d'] + kv[1]['s'] + kv[1]['b']))[:12]
    for name, e in rows:
        print('  %-22s K/D %2d/%-2d | atis %2d isabet %2d kafa %2d | bana: isabet %2d (kafa %2d) iska %2d' % (
            name[:22], e['k'], e['d'], e['s'], e['h'], e['hh'], e['b'], e['bh'], e['bm']))

    hurt = r['hurt']
    if hurt:
        print('== YENEN MERMILER (%d; %d oldurucu) ==' % (len(hurt), sum(x['fatal'] for x in hurt)))
        head_table(' durum:', hurt, lambda x: x['state'])
        head_table(' DT (oldurucu mermi haric: olum sarji sifirlar):', [x for x in hurt if not x['fatal']], lambda x: x['dt'])
        head_table(' DEF:', hurt, lambda x: 'DEF acik' if x['def'] else 'DEF yok')
        head_table(' faz:', hurt, lambda x: x['faz'])
        head_table(' goren:', hurt, lambda x: 'gordu' if x['seen'] else 'gormedi')
        head_table(' silah:', hurt, lambda x: x['weapon'])
        w = r['wall']
        if w:
            print(' iz: duvardan %d (kafa %s), acik %d (kafa %s)' % (w['duvardan'], pct(r['wall_head']['duvardan'], w['duvardan']),
                                                                      w['acik'], pct(r['wall_head']['acik'], w['acik'])))
        fz = defaultdict(lambda: [0, 0, 0])
        for x in hurt:
            fz[x['faz']][0] += 1
            fz[x['faz']][1] += x['hg'] == 'head'
        for x in r['emiss']:
            fz[x['faz']][2] += 1
        print(' faz (mermi basina): ' + ' | '.join('%s: %d mermi, kafa %s, iska %s' % (
            k, v[0] + v[2], pct(v[1], v[0] + v[2]), pct(v[2], v[0] + v[2])) for k, v in sorted(fz.items())))

    # ilk mermi tablosu
    ev = sorted([(x['t'], 'hit', x['att'], x['hg']) for x in hurt] + [(x['t'], 'miss', x['att'], None) for x in r['emiss']] +
                [(x['t'], 'kill', x['enemy'], None) for x in r['kills']] + [(x['t'], 'died', x['enemy'], None) for x in r['deaths']],
                key=lambda e: e[0])
    last, enc = {}, Counter()
    for i, e in enumerate(ev):
        if e[1] not in ('hit', 'miss'):
            continue
        if e[2] in last and 0 <= e[0] - last[e[2]] <= 4:
            last[e[2]] = e[0]
            continue
        last[e[2]] = e[0]
        first = 'iska' if e[1] == 'miss' else ('kafa' if e[3] == 'head' else 'govde')
        out = '?'
        for x in ev[max(0, i - 4):i + 60]:
            if x[0] - e[0] > 6:
                break
            if x[0] < e[0] - 0.2:
                continue
            if x[1] == 'died':
                out = 'oldum'
                break
            if x[1] == 'kill' and x[2] == e[2]:
                out = 'oldurdum'
                break
        enc[(first, out)] += 1
    if enc:
        print('== ILK MERMI (rakibin bana ilk mermisi -> sonuc) ==')
        for first in ('iska', 'govde', 'kafa'):
            w, l, u = enc[(first, 'oldurdum')], enc[(first, 'oldum')], enc[(first, '?')]
            print('  %-6s %3d | oldurdum %2d  oldum %2d  belirsiz %2d | kazanma %s' % (first, w + l + u, w, l, u, pct(w, w + l)))

    if r['duels']:
        d = r['duels']
        res = Counter()
        for x in d:
            key = 'kazandim' if 'oldurdun' in x['res'] else ('kaybettim' if 'oldun' in x['res'] or 'oldu' == x['res'] else 'ayrildi')
            res[(x['first'], key)] += 1
        print('== DUELLO (%d) ==' % len(d))
        for first in sorted(set(k[0] for k in res)):
            w, l, a = res[(first, 'kazandim')], res[(first, 'kaybettim')], res[(first, 'ayrildi')]
            print('  ilk goren %-6s kazandim %2d  kaybettim %2d  ayrildi %3d | kazanma %s' % (first, w, l, a, pct(w, w + l)))
        if r['sikmadi']:
            print('  sikmadi nedenleri: ' + ', '.join('%s %d' % kv for kv in r['sikmadi'].most_common(6)))

    print('== EXPLOIT ==')
    print('  teleport: %s | inise yok: %s' % (dict(r['tp']) or '-', dict(r['tp_no'].most_common(5)) or '-'))
    rf = r['def_refill']
    print('  def shift: %s (dakikada %.1f) | dolum ort %s tick (%d olcum) | sarj harcamadi %d' % (
        dict(r['def_shift']) or '-', h['shift_dk'], ('%.1f' % (sum(rf) / len(rf))) if rf else '?', len(rf), r['def_unspent']))
    print('  kayit beklemeleri: %s | resolver seviye satiri %d (dakikada %.1f) | ai peek: %s' % (
        dict(r['waits']) or '-', r['levels'], r['levels'] / max(1.0, h['dk']), dict(r['peek']) or '-'))
    if r['fake']:
        f = r['fake']
        print('  sahte (defensive) kayda atis: beklenen %d isabet / %d | beklemeden %d isabet / %d | gercek kayit %d / %d' % (
            f[('w', 1)], f[('w', 1)] + f[('w', 0)], f[('n', 1)], f[('n', 1)] + f[('n', 0)], f[('r', 1)], f[('r', 1)] + f[('r', 0)]))
    if r['esc']:
        print('  duvar kacisi: %s' % dict(r['esc']))
    if r['vis'] > 0:
        # DEF korumasi: gorulurken gecen surenin DEF'li payi ile yenen mermilerin "DEF acik" payi. Mermi payi sure
        # payindan belirgin dusukse defensive koruyor (ayni olasilikla vurulsaydik iki pay esit olurdu).
        hits = r['hurt']
        hd = sum(1 for x in hits if x['def'])
        print("  DEF korumasi: gorulurken %d tick, DEF'li %s | yenen mermilerin DEF acik payi %s (%d/%d)" % (
            r['vis'], pct(r['vis_def'], r['vis']), pct(hd, len(hits)), hd, len(hits)))
    if r['last']:
        print('== DENEY / OZET SATIRLARI (son) ==')
        for k, v in r['last'].items():
            print('  ' + v[:400])
    if r['unknown']:
        print('== TANINMAYAN ONEKLER == ' + ', '.join('%s %d' % kv for kv in r['unknown'].most_common(6)))
    if prev is not None:
        p = headline(prev)
        print('== DEGISEN (onceki -> bu) ==')
        print('  KD %.2f -> %.2f | kafa/atis %s -> %s | isabet %s -> %s | yenen kafa %s -> %s | duvar payi %s -> %s | shift/dk %.1f -> %.1f' % (
            p['K'] / max(1, p['D']), h['K'] / max(1, h['D']), pct(p['kafa'], p['atis']), pct(h['kafa'], h['atis']),
            pct(p['isabet'], p['atis']), pct(h['isabet'], h['atis']), pct(p['yenen_kafa'], p['yenen']),
            pct(h['yenen_kafa'], h['yenen']), pct(p['duvar'], p['duvar'] + p['acik']), pct(h['duvar'], h['duvar'] + h['acik']),
            p['shift_dk'], h['shift_dk']))


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 1
    path, from_line, prev = argv[1], 1, None
    i = 2
    while i < len(argv):
        if argv[i] == '--from-line':
            from_line = int(argv[i + 1]); i += 2
        elif argv[i] == '--prev':
            prev = parse(argv[i + 1]); i += 2
        else:
            i += 1
    report(parse(path, from_line), prev)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
