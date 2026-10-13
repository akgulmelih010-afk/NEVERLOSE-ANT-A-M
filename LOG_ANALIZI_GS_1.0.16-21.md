# GameSense edition V1.0.16 – V1.0.21 log analizi

Kaynak: `nykle_log.txt` (10 961 satır, 33 yükleme, V1.0.16 → V1.0.21, çoğunluk V1.0.16).
Sayılar `atis:`, `vuruldun:`, `iska:`, `dbg duello`, `dbg sikmadi`, `dbg olum-detay`, `teleport sonucu` satırlarından çıkarıldı.

## V1.0.22'de uygulananlar

| Madde | Ne yapıldı |
|---|---|
| 5 (şarj bekle) | Peek'te ve yürürken bekleme yok; üst sınır 0.5 sn. |
| 7 (sahte kayıt) | `Wait for real record` varsayılan açık + ilk gerçek kayıttan sonra 3 tick. |
| 1 (gövde kuralı) | Seçenek olarak (`Body 70+ while an enemy sees you`, kapalı): Min. damage 100 isteği korunuyor. Öğrenme (`ogrenildi`) hâlâ sadece HP+1'i kaldırır. |
| 3 (gormedi) | Önce teşhis: `gormedi (iz: ...)` ile görüş takibinin kaçırdığı durum loga yazılır; delmeli görüş `trace_bullet` ile zaten var, sorunun kaynağı bir sonraki logdan okunacak. |
| 9 (sebep bilinmiyor) | `aimbot tehdidi baska`, `gercek kayit bekleniyor`, `safe point Force` sebepleri. |
| 2, 4, 6, 8 | Yapılmadı: Peek AA ve temiz atış değişiklikleri oyun içi deneme ister; önce V1.0.22 logu. |

## Genel tablo

| | |
|---|---|
| Senin atışın | 955 (isabet 632 = %66; ıska: correction 161, spread 66, death 50, damage rejection 26, prediction 12) |
| Sana gelen mermi | 1 108 (783 isabet, 325 ıska); **369 kafa** |
| Öldürme / ölüm (detay satırları) | 585 / 502 |
| Düello sonuçları | öldürdün 585, öldün 417 + 79, ayrıldı 691, başkası öldürdü 114 |
| Sürüm | 1.0.16: 368 / 306 · 1.0.21: 26 / 68 (aurorahvh DM, bir kısmı rage kapalı: karşılaştırma için güvenilmez) |

Kafa yeme oranı (kafa / sana gelen mermi), durum başına:

| Durum | Kafa / mermi | Oran |
|---|---|---|
| **Peek** | 187 / 532 | %35 |
| Air | 62 / 128 | **%48** |
| Air crouch | 17 / 40 | %42 |
| Fake duck | 12 / 31 | %39 |
| Freestanding | 37 / 162 | %23 |
| Standing | 22 / 94 | %23 |
| Crouching | 22 / 92 | %24 |

Ölümlerin **%49'u Peek'te** (248 / 502), %15'i havada (75), %11'i freestanding (54).

## Bulgular (önem sırasıyla)

### 1. Sniper "sadece öldürecek atış" kuralı ölüme yol açıyor; öğrenme işe yaramıyor

- `sikmadi` satırlarının 223'ü `hasar X < MD 100`; bunların **129'unda gövde hasarı ≥ 70** (scout gövde 85–87, düşman hp100).
- 94 ölümün 2 sn öncesinde bir `sikmadi` var; **71'inde gövdeye ≥ 70 hasar vurabilirdin**, kafa bekledin, öldün.
- 369 kafa ölümünün **183'ünde (`atis yok`) hiç ateş etmemişsin**.
- `ogrenildi: ... kafa beklerken öldürdü -> gövde de atılacak` 44 kez tetiklendi; **36'sı "(ama Min. damage'in 100: gövde yine atılmaz)" ile no-op**. 1.0.19/1.0.20'de "görürken geçici 70" vardı, **1.0.21'de yine no-op'a dönmüş** (5/5).

Öneri:
- Öğrenilen kural geri gelsin ve gerçekten uygulansın: o düşman (ya da haritadaki herkes) seni görürken Min. damage geçici olarak `min(hp, 70)`; hedef hp ≤ 87 ise zaten gövde öldürür.
- Öğrenmeyi beklemeden de: **seni görebilen düşman** + kafa atışı `N` tick (ör. 0.3 sn) içinde gelmediyse + gövde ≥ 70 → gövdeye at. İkinci atış (ya da takım) bitirir; 86 hasar yiyen çoğu geri çekiliyor. Görülmüyorken kural aynen kalsın (kafa bekle).
- Alternatif ölçüt: gövde atışı sonrası düşman hp ≤ 15 kalıyorsa (86/100) bunu "öldürecek" say.

### 2. Peek: faz öğrenmesi hiçbir şey kazandırmıyor

Peek'te 6 fazın hepsi %32–43 arasında (faz 0: 28/88, 1: 31/78, 2: 34/104, 3: 38/120, 4: 35/93, 5: 21/49). Faz değiştirmek kafa oranını değiştirmiyor → düşman seni **çözüyor** ya da fazdan bağımsız vuruyor.

- Peek kafa vuruşlarının 67'si düşman seni gördükten **< 0.1 sn** sonra (ön nişan, sen onun tuttuğu açıya giriyorsun), 34'ü < 0.3 sn.
- `sadece o gördü -> öldün` 123 düello: **111'i < 0.3 sn sürdü, 81'inde düşman defensive'deydi (> %50)**, medyan mesafe 591. Sen onu hiç "vurulabilir" görmedin (`sen onu vuramıyordun` 77). Klasik defensive peek + anlık atış.
- Peek'te her mermide `sol 58 / sag 58`: desync hep aynı miktar; faz sadece tarafı / ±15° değiştiriyor.

Öneri:
- Peek'te faz yerine **mesafeyi** değiştir: düşman seni görmeden önceki 2–3 tick'te yaw'ı 90°+ çevir (ters taraf) ve desync'i 58 sabitinden rastgele 35–58 aralığına çek; peek'e girişte jitter gecikmesini 0 yap. Ölçüt: `AA FAZ / PEEK` kafa oranı.
- "Defensive vs enemy peeks" sadece hızdan tahmin ediyor; `sadece o gördü` ölümlerinin 58'inde düşman hızı ≤ 150 (duruyor, açı tutuyor). Açı tutan düşmana peek atarken (auto peek, AI peek) ilk 0.3 sn **zorla defensive + hidden yaw** (hide shots ile), atış ancak kafa/gövde kuralı geçince.
- Auto peek durumuna girişi daha erken yap: `gordu < 0.1` ölümlerinde sen zaten "Peek"tesin ama defensive `yok`/`zorla kapalı` (bkz. 4).

### 3. Duvar arkasından ölüm ve görünmeyen saldırgan

- `olum-detay` 502 ölümün **213'ü `duvardan (1)`** (mermi bir yüzeyden geçmiş; kafa hasarları -105…-222 ile tutarlı).
- 85 kafa vuruşunda saldırgan senin takibine göre seni **görmüyordu** (`gormedi`); 77'sinde `sen onu vuramıyordun`, 50'si duvardan.
- `update_exposure` delip geçmeyi hesaba katmıyor: ince duvar arkasında "görünmüyor" sayılıyorsun → defensive yok, AA hedefi o değil, DT şarj bekletiliyor.

Öneri:
- Görüş testinde düşmanın gözünden senin kafana **delmeli** trace (`client.trace_bullet` GameSense'te hasar ve delme veriyor): kafaya ≥ (hp) hasar geçiyorsa "görülüyor" say. Bu, defensive/hide shots'u ve AA hedefini duvar arkası düşmana da açar.
- Aynı trace ile "duvar arkası kafa riski" varken Peek/Standing'de hidden pitch/yaw kapatma.

### 4. Temiz atış (clean shot) defensive'i kapatıyor ama atış gelmiyor

`DEF yok (zorla)` + `atis yok` ile 38 kafa vuruşu (Peek 17–18, Freestanding 11, Air 5, Standing 4); `DEF acik (zorla)` + `atis yok` 35. "Temiz atış" bayrağı açılınca Break LC / defensive / hidden kapanıyor, aimbot ateş etmiyor (`sebep bilinmiyor` 22, `silah hazir degil` 26, `sen havadasın` 19), sen açıkta kalıyorsun.

Öneri:
- Temiz atış sadece aimbot **gerçekten** ateşlemek üzereyken açılsın: hit chance eşiği geçmiş + silah hazır + hedef hitbox geçerli; bu şartlardan biri yoksa açılmasın.
- Açıldıktan sonra `k` tick (ör. 4) içinde `weapon_fire` gelmezse kapan, `atis yok` ile ölümde bayrak açıksa öğren (o düşmana karşı temiz atış kapalı).
- `silah hazir degil` (sürgü) sırasında temiz atış asla açılmasın; `sen havadasın` (jump scout) sırasında da.

### 5. Safe recharge (şarj bekle) seni çıplak bırakıyor

`DT %0, DEF yok, sarj bekle`: 179 isabet, **70 kafa**, 57'si Peek. Görülürken şarj bekletiliyor ama o sırada ne DT ne defensive var; 1.2 sn'ye kadar.

Öneri:
- Peek / Moving'de şarj beklemesi yok (hemen şarj et).
- Beklerken defensive (hide shots / fake lag) zorla açık; bekleme üst sınırı 0.5 sn.

### 6. Hava: en yüksek kafa oranı, teleport 1/3 vuruluyor

- Air %48, Air crouch %42 kafa. Air faz 1: **16/25 = %64**, faz 5: 9/15, faz 2: 8/14; faz 0: 16/46 = %35. Hava grubunda öğrenme faz 1'den kaçmıyor.
- Teleport sonucu: 136 teleportun **40'ında 1.5 sn içinde vuruldun** (%29; 1.0.16: 26/88, 1.0.21: 6/18). "Son 3'ün 2'sinde vuruldun" kilidi 12 kez devreye girdi.
- `sen havadasın` 19 `sikmadi` + 13 ölüm: zıplarken ateş edemiyorsun (jump scout) ve zıplarken vuruluyorsun.

Öneri:
- Hava grubunda faz 1'i başlangıçta yasakla (öğrenme oranına göre), öncelik faz 0.
- Teleport: inişe < 0.5 sn kala ya da seni gören düşman duruyorsa (hız ≤ 50) teleport yok; teleport yerine havada her tick defensive zaten var.
- Jump scout kapalıyken "havada sniper atışı yok" kuralı; açıkken hc'yi havada 55 → 30 düşürme yerine havada ateşi tamamen kapat ve iniş tick'inde temiz atış.

### 7. Resolver: sahte kayda atış 18 puan kaybettiriyor

| Düşman kaydı | Atış | İsabet | Correction |
|---|---|---|---|
| Gerçek (def yok) | 392 | 294 (%75) | 36 (%9) |
| Defensive **yeni bitti** | 386 | 241 (%62) | 82 (%21) |
| Defensive **içinde** (`DEF geri`) | 178 | 102 (%57) | 44 (%25) |

- Scout 1.25 sn'lik döngüde her ıska pahalı. `gercek kayit bekle` ayarı var ama **kapalı**.
- Düşman AA'sına göre correction: static %10, jitter %21, x-way %21, `?` %25. Seviye 2 (Force) atışları 28/53 (%53) — Force ıskayı azaltmıyor.
- `AA deseni kararsız: hipotez yok, Force safe point` 56 kez: kararsız desende Force'a geçmek veriyle çelişiyor.

Öneri:
- **Koşullu gerçek kayıt bekleme:** sniper + düşman defensive'de + **sen görülmüyorsan** (madde 3'teki delmeli görüşe göre) ≤ 0.2 sn bekle; görülüyorsan hemen at (ilk ateş eden kazanır). Defensive bittikten sonraki ilk 2 tick de "sahte" sayılsın (62 → 75'e yaklaşması beklenir).
- Kararsız desen → Force yerine Prefer; Force sadece aynı düşmana aynı durumda 2 correction sonrası (v5.2 kuralı).
- Jitter/x-way ön bilgisi Prefer'i korusun (ıska %21), static'te Default.

### 8. AI peek: 407 denemenin 165'i "60 birime kadar öldürecek atış yok"

Madde 1'deki gövde kuralı AI peek'i de kilitliyor (kafa görünmezse hiç peek yok). Peek atılanlarda sonuç iyi (çoğu `isabet head`), 31 `aci kapandi`, 9 `süre doldu`.

Öneri: görülmüyorsan (düşman seni göremiyor) kuralı koru; AI peek'te "gövde ≥ 70 + hedef tek, ikinci atış mümkün" noktalarını da say; `aci kapandi` için noktada bekleme 0.5 → 0.7 sn (R8 gibi).

### 9. Diğer

- `damage rejection` 26 (r8 5, ssg08 21): "sunucu Hide shots'u reddediyor -> 5 dk DT" 3 kez tetiklendi; çalışıyor.
- `iska death` 50: hedef mermi varmadan öldü (takım). Sayılmamalı; `atis ozeti`'nden çıkar.
- `panoya kopyalanamadi (Allow unsafe scripts kapalı)` 17 kez: mesaj her Copy'de tekrar ediyor, bir kez yaz.
- `hp100`'e karşı 369 `sikmadi`; hp ≤ 87 düşmanda gövde zaten öldürüyor, orada sorun yok.

## Önerilen uygulama sırası

1. Madde 1 (gövde kuralı + öğrenme no-op düzeltmesi) — en çok ölüm, en küçük değişiklik.
2. Madde 3 (delmeli görüş) — 4, 5 ve 7'nin de temeli.
3. Madde 4 + 5 (temiz atış ve şarj bekle: defensive'siz kalma).
4. Madde 7 (koşullu gerçek kayıt bekleme).
5. Madde 2 + 6 (Peek ve hava AA).

Her maddeyi ölçmek için gereken satırlar zaten logda var: `sikmadi` sebepleri, `vuruldun` exploit alanı, `atis-detay`'daki `DEF geri / once bitti`, `teleport sonucu`, Stats `AA FAZ / PEEK`.
