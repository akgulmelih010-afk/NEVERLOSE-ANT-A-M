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

## V1.0.23: anti-aim (ikinci log, aynı veri + 1 oturum)

İkinci log (9 612 satır) aynı dosyanın devamı: 990 yeni satır, bir V1.0.21 oturumu (aurorahvh, 105 mermi: dururken %56, Peek %50, freestanding %62 kafa) ve V1.0.22'nin sadece yüklenmesi. AA için sana gelen 1 100 merminin kırılımı:

| Kırılım | Kafa / mermi |
|---|---|
| Düşman seni gördükten < 0.1 sn sonra | 137 / 329 = **%42** |
| 0.1–1 sn | 123 / 346 = %36 |
| ≥ 1 sn | 23 / 137 = **%17** |
| `gormedi` | 87 / 240 = %36 |
| Dururken < 0.1 sn | 31 / 58 = %53 |
| Freestanding < 0.1 sn | 14 / 26 = %54 |
| Faz 0 / 1 / 2 / 3 / 4 / 5 (hepsi) | %35 / %43 / %33 / %32 / %34 / %37 |
| Desync `sag 58` / `sol 58` / `sol 60` / `sag 60` | %40 / %37 / %29 / %31 |
| Saldıran `AA hedefi` / `AA hedefi degil` | %33 / **%45** |
| Saldıran defensive'de (`DEF geri`) / değil | **%59** / %33 |
| `DT dolu, DEF yok (zorla)` (zorlandı, pencere yok) | 61 / 114 = %54 |
| Scout mermisi | 346 / 598 = %58 |

Okuma: AA bir kez görüldükten sonra iş görüyor (%17); ölümler ilk 0.1 sn'de ve defensive'li, ön nişanlı scout'lardan. Faz ve taraf değişimi fark yaratmıyor (resolver yazı-tura atıyor, desync 58 iken doğru tahmin = kafa).

Uygulananlar: (1) ilk görüşte / peek'te defensive silah hazırken de (temiz atış hariç), (2) düşük desync fazları 6–7 (öğrenme seçer), (3) kötü bilinen faz atlanır.

## V1.0.23'ün ilk logu → V1.0.24

Üçüncü log: V1.0.23 ile 12 dk DM (dm_twentysixer_office_aurorahvh, 14:30–14:43), çoğu tek rakibe karşı (мопсик: 37 ölüm+öldürme). 20 öldürme / 34 ölüm; sana 70 mermi, 31 kafa (%44); senin 42 atış, 24 isabet.

- **Bütün oturum Hide shots'taydı:** sniper öğrenmesi "HS 17/32, DT 19/28 → Hide shots" demişti. HS'de zorlanan defensive, teleport ve peek koruması yok; V1.0.23'ün "ilk görüşte defensive" değişikliği hiç devreye girmedi. 1 100 mermilik toplamda HS %45 / DT %36 kafa. → Varsayılan `Same as state` (DT), Auto eşikleri yükseltildi.
- **`gormedi (iz: kapali)` 22/23:** vurulma anında saldıranın gözünden kafana iz kapalı; 13'ünde kaydı sahte (`DEF geri`). → Sahte kayıttaki düşman için ileri bakış kaydın gerisi kadar uzatıldı.
- Faz 6/7: 24 + 18 mermi, %42 / %44 — faz 3 (%41) ile aynı; öğrenme peek için faz 3'ü seçti. Tek rakip, erken.
- Gerçek kayıt bekleme: 285 "gerçek kayıt geldi", 233 "sınır doldu" (düşman 14 tick'ten uzun defensive'de). Sahte kayda 12 atış %50, gerçeğe 29 atış %62.
- `sarj bekle` ile vurulma: 0 (V1.0.22 değişikliği).

## V1.0.24'ün ilk logu → V1.0.25

Dördüncü log: V1.0.24 ile 14 dk DM (dm_hvh_fysnow_bc_aurorahvh, 14:49–15:03), DT açık (`sniper Same as state`). 29 öldürme / 49 ölüm; sana 103 mermi, 75 isabet, **48 kafa (%64)**; senin 65 atış, 39 isabet (%60).

| Kırılım | Kafa / mermi |
|---|---|
| Freestanding / Peek / Standing / Air | 19/37 · 17/33 · 4/17 · 5/8 |
| Saldıran `gormedi` | 21/36 = %58; `iz: kapali` 32, `duvardan` 3, `su an goruyor` 1; 16'sında `DEF geri` |
| `gormedi` saldıran mesafesi | 245–1991 birim, 11'i 1600+ |
| Defensive penceresi açık / kapalı | 9/23 = %39 · 39/80 = %49 |
| `DT dolu, DEF yok, atis yok` / `DEF yok (zorla)` | 11 · 8 kafa |
| Faz 1 / 2 / 3 / 5 / 6 / 7 | %31 / %29 / %54 / %55 / **%65** / %48 (öğrenme: yerde faz 2; faz 6 artık "kötü bilinen") |
| Teleport | 15, 2'si 1.5 sn içinde vurulma (eskiden %29) |
| `sikmadi` → ölüm (2 sn) | 9, 8'inde gövde 70+ vardı (`Body 70+` kapalı) |
| Sahte / gerçek kayda atış | 16/23 · 23/42 (küçük örnek) |

Okuma: ölümlerin çoğu ekranda hiç görünmeyen, defensive'li, uzak scout'lardan; o sırada defensive kapalı (`On peek` görünmeyen düşmana zorlamıyor). → Smart artık 1800 birim içinde düşman varken de zorlar; dururken / eğilirken / freestanding'de varsayılan Smart.

## V1.0.25'in ilk logu (aynı harita, 10 dk, 15:11–15:21)

| | V1.0.24 (14 dk) | V1.0.25 (10 dk) |
|---|---|---|
| Öldürme / ölüm | 29 / 49 | **41 / 46** |
| Sana gelen mermi / isabet / kafa | 103 / 75 / 48 (%64 kafa) | 82 / 68 / 34 (**%50**) |
| `gormedi` kafa | 21 | **5** |
| Senin atış / isabet | 65 / 39 (%60) | 79 / 54 (**%68**) |
| Sahte / gerçek kayda atış | 16/23 · 23/42 | 11/19 · 39/56 |
| Teleport | 15, 2 vurulma | 3, 2 vurulma → haritada kapandı |

Kalan kafa mermileri: 20/34 Peek'te; 17'sinde `DT %N` (şarj doluyor) ya da `DT dolu, DEF yok` ve 12'si **kendi atışından 0.4 sn içinde**: DT'yle ateş ettin, şarj boşaldı, karşılık geldi. Bu DT'nin kendi bedeli; peek'ten sonra geri çekilmek (AI peek bunu yapıyor) tek çözüm. `sikmadi` → ölüm 12, 11'inde gövde 70+ vardı.

→ **V1.0.26:** DT çifti öldürüyorsa (gövde × 2 ≥ can, DT dolu) gövde serbest: Min. damage 100 şartı "sadece öldürecek atış" demek, çift öldürüyor. Temiz atışın atış sonrası tutması 14 → 6 tick (defensive şarjla birlikte dönsün). Yapılmayan: `AA hedefi degil` (%45, 152 mermi: freestanding 27, Peek 26 kafa) için hedef önceliği — hangi düşmanın görmesi gerektiğini log söylemiyor; `zorlanan 138 418 tick / zorlanıp görülen 90 810` (%66): `(zorla)` ama pencere yok = DT şarj boşluğu, script'ten düzeltilemez.

## V1.0.27–1.0.29 logu (altıncı log: office DM 8 dk, fysnow 5 dk, de_mirage 22 dk / 8 round)

| | V1.0.27 (office) | V1.0.28 (fysnow) | V1.0.29 (mirage) |
|---|---|---|---|
| Öldürme / ölüm | 5 / 16 | 5 / 6 | 13 / 25 |
| Sana gelen isabet / kafa | 28 / 10 | 8 / 5 | 38 / 14 (%37) |
| Senin atış / isabet | 15 / 9 | 11 / 8 | 30 / 19 (%63), 5 correction |
| `gormedi` kafa | — | — | 4 (13 `iz: kapali`) |
| Teleport | — | — | 3 ok / 4 vurulma |

Mirage okuması:
- **DT çifti çalışıyor:** 5 satır (`MD 86` / `MD 72` geçici), hedef kafa/mide 22/6, mideye giden 5/6 tuttu.
- **Kendi resolver hiç uygulanmadı:** 30 atışın hepsi `res gs`, panelde `kollar: GS 6/7`. Sebep: LBY kolu sadece duran düşmana seçiliyordu (`speed < 5`), atışların 28'i hareketli hedefe gitti. → **V1.0.30:** LBY kolu yerdeki her düşmanda; taraf bilgisi gidince kol bırakılır; eşikte histerezis.
- Faz 8 (asimetrik) 44 merminin 30'unu yedi, %30 kafa: diğer fazlarla aynı bant, öğrenme elemiyor; veri az, izlenecek.
- `sen havadasın` 4/9 `sikmadi`: havada hit chance 40 çalışıyor (eskiden 75/254).
- Çalışma hatası yok; Peek 10/20, Air 2/11 kafa.

## V1.0.30 logu (yedinci log: de_mirage 26 dk, 16:50–17:16)

| | V1.0.29 (mirage 22 dk) | V1.0.30 (mirage 26 dk) |
|---|---|---|
| Öldürme / ölüm | 13 / 25 | **22 / 17** |
| Sana gelen isabet / kafa | 38 / 14 (%37) | 33 / 10 (**%30**) |
| Senin atış / isabet | 30 / 19 (%63), 5 correction | 30 / 27 (**%90**), 2 correction |
| `gormedi` kafa | 4 | 11 (13 `iz: kapali`) |
| DT çifti | 5 | 7 |

- **Kendi resolver yine uygulanmadı, bu kez başka sebepten:** 8 kol seçimi (`bizim lby+ ... (deneme)`) ve 8'i aynı saniye `taraf bilgisi degisti (lby -> open): lby+ kolu birakildi`. LBY farkı anlık: düşman yürürken LBY göz yaw'ına eşitleniyor, fark bir an 0'a düşüyor (vurulma-detay'da `lby+0` / `lby-106` yan yana). V1.0.30'un "bilgi gidince bırak" kuralı fazla hevesliydi. → **V1.0.31:** 1 sn kesintisiz kayıp şartı; anlık kayıpta seçilen taraf korunur.
- Seçimlerin hepsi `(deneme)`: GS kolu 23/24 ile çok yüksek skorlu, LBY kolu sadece %15 denemeyle seçiliyor. Bu doğru: GS bu sunucuda %90 tutuyor, kendi kol ancak veri biriktirince öne geçer.
- Gerçek kayıt bekleme: 46 kez kayıt geldi, 76 kez 14 tick sınırı doldu (XOXO 41 kez / round defensive'de). Sahte kayda giden 4 atışın 2'si tuttu.
- Ölümlerin 17'si Peek'te (33 isabetin 17'si); kafa 10/33, faz 0 ve 8'de 3+3.

## V1.0.31 logu (sekizinci log: de_mirage 30 dk, 17:23–17:53)

| | V1.0.30 | V1.0.31 |
|---|---|---|
| Öldürme / ölüm | 22 / 17 | 24 / 25 |
| Sana gelen isabet / kafa | 33 / 10 (%30) | 39 / 15 (%38) |
| Senin atış / isabet | 30 / 27 (%90), 2 correction | 43 / 29 (%67), **12 correction** |
| `sikmadi` | 10 | 8 |

- **Kendi resolver üçüncü kez uygulanmadı**, bu kez sebep durum anahtarı: 12 kol seçimi (`bizim lby+ / wall+ ... (deneme)`), hepsi "Standing"de; atışlar 1 sn sonra düşman "Slow walk" / "Moving"deyken gitti (klaus 17:25:49 → 17:25:50, ﷽﷽ 17:25:50 → 17:25:51). Hipotez kaydı (düşman, durum) başına; yeni durumun kaydı boş → `res gs`. Bırakmalar artık 1–31 sn sonra (grace çalışıyor). → **V1.0.32:** karar düşman başına, her durumun hipotezine taşınır.
- Seçimlerin 11'i `(deneme)`: GS kolu 42/49 (%86) ile skor 0.84, lby+ ön bilgisi 0.62. Sadece ε ile seçiliyor. → UCB1 primi (0.25): denenmemiş kol ilk 4–8 atışta öne geçer.
- `lby L 102°`, `111°`, `122°`, `R 178°`: desync'in üstünde farklar, LBY kırıcı / bayat LBY. → 150° üstü taraf sayılmaz.
- Correction ıskası 2 → 12 (%28): Black Beatles 4, ﷽﷽ 3, furkan 2. Çoğu `BA Off` ile (bu oturumda body aim kapalı, kafa 32/43). Kendi kol tam bu düşmanlarda devreye girmeliydi; Black Beatles'ta skorla (`GS 1/4`) seçildi ama durum anahtarına takıldı.
- Çalışma hatası yok; gerçek kayıt bekleme ve DT çifti öncekiyle aynı.

## V1.0.32 logu (dokuzuncu log: de_mirage 2 dk, 18:00–18:02)

Yargı için çok kısa: 7 atış / 7 isabet, 5 öldürme / 2 ölüm, hata yok. Kendi resolver bir kez kol seçti (`kaan Standing | bizim wall+ (duvar L)`), aynı saniye kaan'ın AA deseni static → x-way'e döndü (hipotezler sıfırlandı; x-way çok yönlü desen, kol uygulanmaz) ve kaan 27 sn siper olmayan yerde yürüdü → kol bırakıldı (doğru). kaan'a tek atış x-way + sahte kayıtta gitti, `res gs`. V1.0.32'nin durum taşıması bu oturumda sınanmadı; uzun oturum gerekli.

### Devamı: aynı oturumun tamamı (de_mirage 20 dk, 18:00–18:20)

| | V1.0.31 | V1.0.32 |
|---|---|---|
| Öldürme / ölüm | 24 / 25 | 18 / 21 |
| Sana gelen isabet / kafa | 39 / 15 (%38) | 38 / 12 (%32) |
| Senin atış / isabet | 43 / 29 (%67), 12 correction | 36 / 26 (%72), 5 correction |
| Kol kararı / kolla giden atış | 12 / 0 | 3 / 0 |

- Durum taşıması çalışıyor ama **karar verecek bilgi yok**: 36 atışın 28'inde atış-detay'daki LBY farkı 0 (`lby+0`), 35° üstü sadece 8'inde (70, 146, 47, 168 …). Duvar kararı 20 dakikada 1. Jitter / x-way düşman 21 atış (kol yok), "AA deseni kararsız" 23 satır (e 14).
- İki karar düşman dormant'ken 26–28 sn asılı kaldı (güncelleme gelmedi), bırakıldı; biri (kaan 18:13:39) 1 sn sonra bırakıldı. Hiçbiri atışa denk gelmedi.
- GameSense Lua'da başka taraf kaynağı yok: animasyon katmanları / pose parametreleri okunamıyor, GS'nin çözdüğü açı dışarı verilmiyor. Kalan tek yol: **açıyı kendimiz zorlayıp sonucu düşman başına öğrenmek**. → **V1.0.33:** statik desync'li düşmanda taraf bilgisi gerektirmeyen `abs+` / `abs-` kolları (+58 / −58), UCB ile denenir, düşman başına kalıcı öğrenilir. Statik desync'te gerçek kafa sahte yaw'ın hep aynı tarafında; 36 atışın 15'i statik düşmana gitti.
- `sikmadi` 12: 5'i kaan / furkan'da "hasar 85–86 < MD 100" (DT çifti için can 100 > 2 × 86 değil, kural doğru).

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
