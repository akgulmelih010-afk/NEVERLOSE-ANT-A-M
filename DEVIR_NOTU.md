# Nykle.win lua V1.1: devir notu

Bu notu okuyan, işi kaldığı yerden devralabilsin diye yazıldı. Ayrıntılı kullanıcı dokümanı ve her özelliğin "neden"i `README.md`'de. Bu not, kodun haritası, özelliklerin tam listesi, test düzeni ve açık işler.

## Durum

| | |
|---|---|
| Dosya | `Nykle.win.lua`: tek dosya, Neverlose (CS:GO) Lua API'si |
| Sürüm | V1.1 (eski adı ANT-A-M v2–v5.6; V1.1 = GameSense V1.0.22–1.0.33'ün Neverlose'a taşınması) |
| Dal | `claude/loving-fermi-99v29v` (PR #2, taban `claude/csgo-hvh-anti-aim-kkh1vh`) |
| Oyun içi test | **Yapılmadı.** Bütün doğrulama `tests/` altındaki sahte (mock) API ile. V1.0 davranışı kullanıcının attığı Neverlose konsol loglarıyla, V1.1 değişiklikleri GameSense sürümünün on oyun loguyla ayarlandı; V1.1 için henüz Neverlose logu yok. |
| Testler | `tests/run_tests.sh`: 7 mod + strict, 1064 kontrol, hepsi geçiyor (ana bölümde 196 local). `tests/mutate.py`: 754 mutasyonun hepsi yakalanıyor (~1 saat; `python3 mutate.py harness.lua "ad1" "ad2"` ile alt küme çalıştırılabilir). |
| Kalıcı hafıza | Neverlose `db` anahtarı `ant_a_m_memory` (eski adla; v5.x verisi aynen okunur) |

## Özelliklerin tam listesi

### Genel
- **Kurar kurmaz çalışır.** **Always use recommended settings** açıkken her ayar 64 tick'te bir ve config yüklenince varsayılanına döndürülür. Değişen ayar sayısı konsola yazılır.
- **Kapatınca hepsini geri verir.** Ezilen her Neverlose ayarı `overridden` tablosunda tutulur; Enable kapanınca ya da script kaldırılınca geri verilir. Neverlose'un reddettiği değer bir kez yazılır, 5 sn sonra tekrar denenir.
- **Güvenli API erişimi:** bulunamayan menü yolu ya da `rage.*` metodu çökertmez, o özellik atlanır. Her olay `protect()` ile sarılı: hata bir kez yazılır, script çalışmaya devam eder.
- **Kalıcı hafıza (Steam ID ile):** düşman başına öğrenilen anti-brute fazı, resolver sonuçları, faz istatistikleri ve sniper HS/DT verisi. Harita ve oyun değişince de kalır. **Forget learned enemies** düğmesi siler.

### Anti-aim
- **13 durumlu builder:** Global, Standing, Moving, Slow walk, Crouching, Crouch move, Peek, Air, Air crouch, Fake duck + Manual, Freestanding, Safe head. Her durumda yaw sol/sağ ya da X-Way, modifier, body yaw (Jitter / Random / Static / Off), limitler, randomize ve jitter gecikmesi var. Varsayılanlar `DEFAULTS` tablosunda.
- **Durum tespiti** (`detect_movement`): histerezisli hız ve egilme eşikleri. Peek iki şekilde girer: Peek Assist tuşu basılı ve hareket ediyorsan (ya da AI peek yürüyorsa), veya auto peek açıkken hareket edip görüş alanına girersen. Fake duck kendi durumudur.
- **AA hedefi** (`face_target`): Neverlose'un tehdidi varsa At Target. Öncelik sırası: düello (az önce ateş ettiğin ve seni gören), son 1 sn'de kafana ateş eden, yandan gören, en yakın düşman. `brute_target` ile aynı sıra.
- **Anti-bruteforce:** 5 faz. Taraf çevirme, ±15° kaydırma, rastgele desync tarafı, body freestanding (Peek Fake). Faz düşman başına tutulur; kafandan vuran düşmana bir sonraki faz kalıcı öğrenilir. Hesap, AA'nın **gösterdiği** fazdan yapılır.
- **Kendi kendine öğrenen faz seçimi:** hareket grubu başına (yerde / hareket / peek / hava) her fazda kafana gelen mermi ve isabet sayılır. Oran `(isabet + 2.4) / (mermi + 8)`; denenmemiş faz 0.3 sayılır, değişim için 0.1 fark gerekir. Sayılar 40'ı geçince yarılanır.
- **Safe head** (bıçak / zeus ile havada eğilirken), **freestanding** (tuş ya da durduğun yerde otomatik), **manuel yaw**, **avoid backstab**, **legit AA on use** (bomba / rehine yanında karışmaz), **spin when idle**.
- **Fake duck:** kendi AA'sı var (her pakette rastgele taraf). Bıçaklı düşman yaklaşınca FD bırakılır. Havada ve koşarken FD artık bırakılmıyor (Fake duck only when standing still varsayılan kapalı).

### Exploit'ler
- **Auto exploit:** her durumun DT / HS seçimi Builder'dan gelir. Bıçak / bomba ile son silahın seçimi korunur.
- **Sniper exploit (Auto learn):** kafana gelen mermilere göre HS ya da DT seçilir (en az 4 mermi görmeden değişmez).
- **Defensive modları:** On peek, Smart (biri seni görürken DT defensive'i zorlanır), Always on, Tick based. Durum başına hidden pitch / yaw. Dururken, eğilip dururken ve Peek'te hidden açı yok.
- **Hide shots Break LC:** "On peek" emülasyonu. Hareket ederken, görülürken ya da AI peek sırasında açılır.
- **Defensive vs enemy peeks:** sana peek atan düşmana karşı defensive, görünmeden önce (hızından tahmin). Göründükten sonra sadece silahın ateş edemezken.
- **Air lag** (havada her tick defensive) ve **havada teleport** (zıplama başına 1, inişe 0.35 sn'den az kaldıysa yok).
- **Safe recharge:** görülürken DT şarjı bekletilir (en fazla 1.2 sn).
- **Clean shot (temiz atış):** silah ateş edebiliyor ve hedefin kafası (kenarları dahil), göğsü ya da midesi Min. Damage'ı geçiyorsa Break LC, zorlanan defensive, hidden açılar ve teleport durur. Atıştan sonra hemen geri gelir. FD'de yok.
- **Bozuk atış koruması:** kendi lag'in (DEF / LC / TP) sırasında 10 sn içinde iki `unregistered shot`, `damage rejection` ya da `prediction error` gelirse o lag 10 sn durur.

### Resolver ve ragebot
- **Adaptive resolver:** Neverlose'un resolver'ı değiştirilmez; sonuçlara bakılır. Düşman başına ve hareket durumu başına son 4 sonuçtaki `correction` sayısı seviyedir: 1 = safe points Prefer, 2 = Force.
- **Jitter ön bilgisi:** veri yokken jitter'lı düşmana Prefer.
- **Force takılma koruması:** karşılıklı görüşte 0.5 sn atış gelmezse Prefer'e iner.
- **Force sınırları:** sniper'da ve sadece kafa açıkken en fazla Prefer.
- **Sahte kayda giden ıska öğrenilmez:** düşman o an defensive kaydındaysa ya da LC kırıyorsa. Jitter sadece gerçek kayıtlardan ölçülür.
- **Smart body aim:** tek gövde mermisi öldürüyorsa Force (gerçek mermi iziyle, duvar dahil). DT ile iki mermi öldürüyorsa Prefer. Sniper'da gövde öldürmüyorsa Default.
- **Head unless body kills (snipers):** biri seni görebiliyorken Min. Damage 101 (can + 1), yani sadece öldürecek atış.
- **Snipers: lethal body on fake records:** hedefin kaydı sahteyken ve gövde öldürüyorsa kafa yerine gövde (en fazla 12 tick). Gövde öldürmüyorsa kafaya ateş edilir.

### AI peek (Peek Assist tuşu basılıyken, hareket tuşuna basmadan)
- Tehdide dik, sola ve sağa 18 / 32 / 46 / 60 birim taranır. Yukarıdaki düşmana geri-çapraz noktalar da denenir.
- Yürünebilirlik kontrol edilir (hull ya da iki çizgi, altında zemin).
- Gereken hasar Min. Damage, sniper'da can + 1. Gövde noktası sadece öldürüyorsa sayılır; kafanın kenarları da sayılır.
- Nokta iki taramayla teyit edilir. Noktada 0.5 sn beklenir (R8 0.75); düşman sahte kayıttaysa bir kez 0.2 sn daha.
- Atıştan sonra ve atışsız bitince script geri yürür. Aynı düşmana 2 boş peekten sonra tuşa yeniden basana kadar peek yok.
- DT / HS şarj olurken ve silah hazır değilken peek yok.

### Görüş sistemi ve düşman takibi
- `update_exposure`: tehdit (yoksa en yakın düşman) kafana mermi geçirebiliyor mu. Kafanın iki kenarına da bakılır, 0.2 sn ileri tahmin yapılır, diğer düşmanlar sırayla kontrol edilir. FD'de kafa ayakta yüksekliğinde sayılır.
- `enemy_watch`: düşman başına simülasyon zamanı, konum ve bakış yönü takip edilir. Buradan defensive (sahte kayıt), LC kırma, jitter ortalaması ve fake duck çıkarılır.

### Loglar (Home → Console)
- `atis:` her aimbot atışı: hedef, sonuç, SP / BA / MD, backtrack, hc, kendi lag'in (`temiz`, `LC`, `DEF`, `FD`, `TP`), düşmanın AA'sı.
- `vuruldun:` / `iska:` sana gelen mermiler: durum, faz, exploit, saldıranın bilgisi.
- `resolver:` seviye değişimleri.
- `round ozeti` (sana gelen mermiler) ve `atis ozeti` (senin atışların, ıska sebepleri).
- Teleport, fake duck, AI peek ve sniper exploit satırları.

### Görsel
- Nişangah göstergesi: durum, DT / HS / FS / DEF / VIS, `BRUTE n`, `RES n`, `BAIM`, `HEAD`, `DEF BODY`, `CLEAN SHOT`, `ANTI-PEEK`, `AI PEEK`.
- Manuel oklar.
- **Resolver paneli:** canlı çözüm yüzdesi ve HIT tahmini; sürüklenebilir, boyutlanabilir.
- **Stats paneli:**
  - durum başına isabet / kafa / ıska / DT / DEF,
  - AIM ve `LAG / TEMIZ`,
  - `KD` (durum başına öldürme / ölüm),
  - `AA FAZ` ve `SNIPER`,
  - `AI PEEK`.

### V1.1: GameSense sürümünden taşınanlar (loglarla kanıtlanmış; ayrıntı README → "V1.1'de ne değişti")
- **Smart defensive** 1800 birim içinde düşman varken de zorlar (`menu.smart_near`); duran durumların varsayılanı Smart. Harness'ta eski bölümler bu anahtarı kapatır (düşman 500 birimde), kendi bölümü test eder.
- **Safe recharge** 0.5 sn, Peek'te / yürürken yok (`recharge.exposed_anyway`).
- **Anti-peek** silah hazırken de (`anti_window(now)`, sadece "On peek" modunda; Smart zaten görülünce zorlar).
- **Anti-brute fazları 6–8** (`BRUTE_PHASES`, `update_flip` asimetri) ve **kötü faz atlama** (`brute.known_bad / skip_bad`, Stats'ta `x`).
- **Sniper öğrenici** DT'den başlar, 24 / 16 / 0.15 eşikleri; varsayılan `Same as state`.
- **Kayıt gecikmeli ileri bakış** (`exposure.record_lag`, `enemy_eye_ahead`).
- **DT çifti** (`resolver.pair`, `DT_PAIR`, `menu.dt_pair`): Min. Damage gövde − 1; senin 100 üstü MD'n korunur.
- **Gerçek kayıt bekleme** (`resolver.wait`, `resolver.wait_hold`, `menu.wait_real`): global (Neverlose'da düşman başına whitelist yok), Min. Damage 130 ile. Harness'ta eski bölümler kapatır.
- **Havada hit chance** (`resolver.air_hitchance`, `refs.hit_chance` = Ragebot → Selection → Hit Chance; yol yoksa atlanır).
- **Teleport sonucu** (`teleport.record / hurt`, `map_off`): haritada son 3'ün 2'si vurulduysa kapalı.
- **Sol el** (`lefthand`, render'da): `cvar.cl_righthand:int()` → `:get_int/set_int` → `utils.console_exec`; hiçbiri yoksa bir kez konsola yazar.
- **Log kaydı** (`nlog`, `local print` sarmalayıcı): hafıza + `files.write("nykle_log.txt")`; Home → Console düğmeleri.
- **"Sıkmadı" teşhisi** (`clean_shot.damages / diagnose`): 0.44 sn'de bir, sebepler tek satırda.
- `attacker_info`: `gormedi (iz: su an goruyor / kapali)`.
- **Taşınamayan:** GameSense'in kendi resolver'ı (Force body yaw kolları) — Neverlose API'sinde düşman başına açı yok.
- **Doğrulanamayan API varsayımları** (hepsi pcall ile güvenli): `cvar.*:int()`, `utils.console_exec`, `files.write`, `Ragebot > Selection > Hit Chance` menü yolu, Min. Damage 130'un kabul edilmesi.

## Kodun haritası

Her şey tek dosyada, yukarıdan aşağı:

1. **Güvenli API** (`find`, `rage_method`, `protect`, `override`, `effective`): satır ~55–270.
2. **Menü** (sekmeler, `menu.*`, `builder[state]`, öneri sistemi `apply_recommended`): ~280–838.
3. **Durum tespiti ve görüş** (`trace_bullet`, `exposure`, `update_exposure`, `seen_by_enemy`, `duel_target`, `detect_movement`, `weapon_ready`): ~839–1500.
4. **Anti-aim yardımcıları ve anti-brute verisi** (`BRUTE_PHASES`, `brute`, `brute_default`, `sniper`, `brute_target`): ~1503–1798.
5. **Adaptive resolver** (`resolver`, `enemy_watch`, `resolver_level`, `stall_level`, `resolver.cap`, `apply_resolver`, `apply_body_aim`): ~1800–2650.
6. **Exploit ve defensive** (`apply_exploit`, `clean_shot`, `apply_defensive`, tickbase, recharge, FD guard, `face_target`, `teleport`): ~2650–3272.
7. **AI peek** (`ai_peek`, `scan`, `step`): ~3275–3880.
8. **createmove** (her tick'in sırası, aşağıda): ~3883–4070.
9. **Olaylar** (bullet_impact, player_hurt, weapon_fire, aim_fire, aim_ack, round / level / death, kalıcı hafıza): ~4073–4893.
10. **Göstergeler, paneller, render, shutdown**: ~4895–sonu.

**createmove sırası:** öneri kontrolü → canlı mı → tickbase → FD guard → düşman takibi → görüş → durum → silah → bekleyen ıskalar → anti-brute fazı → resolver → body aim (MD, hitbox) → AI peek → ladder / legit / spin dalları → AA durumu → exploit → flip → açılar → temiz atış → defensive → teleport → recharge → istatistik.

**Sınır:** ana bölümde en fazla 200 local olabilir (şu an 195). Yeni durum yeni local yerine mevcut tablolara alan olarak eklenmeli (`current`, `resolver`, `exposure`, `aim_stats`...). Aynı sınır `tests/harness.lua` için de geçerli: V1.1 bölümü local yerine `v` çalışma tablosunu kullanır.

## Testler

- `tests/harness.lua`: Neverlose API'sinin sahte hali (ui, entity, rage, utils, db, render, events) ve 939 kontrol. Redis'in Lua 5.1 `EVAL` ortamında çalışır.
- `tests/run_tests.sh`: Redis'i 6399 portunda başlatır ve 7 modu çalıştırır:
  - `none`: tam test,
  - `norage`, `notrace`, `badvalues`, `nohull`, `nobinds`: API eksik ya da bozukken çökmeme,
  - `v46`: eski kayıt formatı,
  - artı strict (tanımsız global okuma / yazma hata verir) ve local sayacı.
- `tests/run_tests.sh mutate`: `tests/mutate.py` ile 703 mutasyon; her biri kodu bilerek bozar ve testlerin yakalaması beklenir. Yaklaşık 1 saat sürer.
- Kural: her davranış değişikliğinde test ekle, yeni testin eski kodda kırıldığını kontrol et, değişen kod için mutasyon ekle. Eski desenler kodla eşleşmiyorsa (`SKIP`) güncelle.

## Odak (kullanıcı isteği)

Şu an **sadece GameSense** (`Nykle.win.gamesense.lua`). Neverlose'a kullanıcı "Neverlose'a geç" diyene kadar dokunulmaz, fikir listelerinde de Neverlose önerilmez.

## Kullanıcıya rapor biçimi (istek)

Her log sonrası rapor kısa ve şu biçimde olmalı (ayrıntı dosyalara, sohbete değil):

```
güncelleme
----------
AA GELİŞTİ: kafa oranı %77 -> %35, %15 daha iyileşmesi bekleniyor
RESOLVER AYNI: kafa atışında correction %48, gövde %84; %10 daha iyileşmesi bekleniyor
PEEK ÖLÜMLERİ: bolt cover yeni, etkisi bir sonraki logda
```

Satır = alan, durum (GELİŞTİ / AYNI / KÖTÜLEŞTİ), ölçülen rakam, beklenti. Rakamlar logdan; beklenti "bekleniyor" diye işaretli.

## V1.1.5: kafa önceliği + taze kayıt (istek: "hs'ye yoğunlaş", "çok missliyoruz")

- `menu.head_first` (açık): DT çiftinde Force yerine Prefer (`apply_body_aim`, sniper dalı), aim-target Force kuralı çiftte uygulanmaz (`resolver.pair == nil or not head_first`), `resolver.wait` duelloda `duel_max = 6` tick (kapalıyken 0). Log son eki ` (duello, kafa onceligi)`; log türleri `cap_duel` / `real_duel` ayrı sayılır.
- `menu.fresh_only` (açık) + `resolver.fresh` / `resolver.fresh_hold(lp, target, sniper)`: `clean_shot.damages` ile hedefin şu anki kaydına kafa/gövde izi (2 tick'te bir); iz 0 ama son 24 tick içinde > 0 idiyse Min. Damage 130 (`current.fresh_wait`). Hiç vurulabilir olmamış hedef / `trace_bullet` yoksa bekleme yok. `clean_shot` artık `local resolver`'dan önce ileri bildirimli (`local clean_shot`, local sayısı değişmedi).
- Veri (üçüncü Neverlose logu, 77 çözümlenen atış): `bt` ≥ 8 → 17/25 ıska (kafa 13/16, gövde 4/9, Moving kafa 7/9); `bt` < 8 → 6/52 (kafa 3/16, gövde 3/37). Jitter'lı düşmanda bt<8: 4/43 ıska. Uzun backtrack'ler ilk atışta, takip atışları `bt 0t` ile tutuyor (71:35 → 71:40, 76:02 → 76:04). Alternatifler elendi: "ıska hafızası" (bir correction ıskasından sonra 8 sn gövde) sadece 7 kafa atışını / 3 ıskayı etkilerdi; hareketli/havadaki düşmanda gövde kuralı HS'yi yarıya indirirdi.
- Sonraki logda ölçülecek: `atis:` satırlarında `bt 9t`+ atış sayısı (hedef: ~0), `taze kayit beklendi` satırları ve ardından 1 sn içinde `atis:` geliyor mu (bekleme atışı öldürüyor mu), kafa isabet oranı (eski %50 → beklenen %70+), `(duello, kafa onceligi)` satırlarından sonra isabet. Neverlose Fake Latency / Backtrack menü yolu bilinmiyor; `bt` 13+ (200 ms üstü) atışlar sürerse düşmanın fake latency'si olabilir, o zaman pencereyi 32'ye çıkarmak aday.

## V1.1.6: beşinci Neverlose logu (18 dk, V1.1.5 ile) — DT çifti yok, bolt cover kapalı

- Sonuç: 54 atış, isabet %76 (3. log %69, 4. log %56); kafa 13/21 (%62; önce %50); correction 8 (%15; önce %28); 25 öldürme / 19 ölüm; eğik peek 15 öldürme (8 HS) / 6 ölüm. Taze kayıt 17 kez bekledi (en uzun 24 tick), `(duello, kafa onceligi)` 24 satır.
- **DT ikinci mermiyi atmıyor** (scout): 3. ve 5. logda 130 atışta 1 çift (138:54); atış aralıkları hep 1.0–1.3 sn (sürgü). `DT dolu` görünüyor, atıştan sonra `DT %0`: şarj tek mermiyle gidiyor. Neden bilinmiyor (Neverlose'da DT + scout davranışı ya da defensive/`force_teleport` etkileşimi; menü yolu bilinmediği için script'ten düzeltilemiyor). Sonuç: "çift" = gövde −91 → düşman 9 canla 1.25 sn sürgü → 19 ölümün 11'i atıştan sonraki sürgüde (hit de olsa, miss de olsa).
- → `DT_PAIR.lag_ticks = 8`, `DT_PAIR.duel_*`; `apply_body_aim` sniper dalında `pair_ok` / `duel`: Headshot priority açıkken duelloda (`current.state == "Peek"` ya da hedefin `exposure.sight` kaydı `SIGHT.recent` içinde) çift yok, Min. Damage 101; hedefin kaydı `exposure.record_age(target) >= 8` tick ise (gecikmeli: kafa 5/7 ıska) çift serbest. Hedefi görmeyen ama başka düşmanın gördüğü durumda (sniper şeması açık) çift serbest. Log: `X: duello, DT cifti yerine kafa (...)`, hedef başına 5 sn'de bir.
- → **Bolt cover varsayılan kapalı** (`menu.bolt_cover` false): fake duck'ta 14 mermi geldi (3 kafa), 7 ölüm `Fake duck`; `FD, DT %0 (bind), DEF yok` satırları: fake duck DT'yi boşaltıyor, defensive yok, düşmanın resolver'ı fake duck'ı çözüyor. 4. log (kapalı) sürgüde 3/10 ölüm, 5. log (açık) 11/19.
- Uzun backtrack (`bt` 13–26t) artık düşman gecikmesi (DUVARCI 138:13'ten sonra hep uzun); taze kayıt beklemesi onu engelleyemez, `record_age` ile kafa yerine çift seçiliyor.
- Harness notu: aimbot hedefi `brute_target()` = seni gören düşman; "hedef seni görmüyor" testi için hedefe `aim_fire` verip `resolver.aim_target` tutulur (1.5 sn). `globals.curtime` ayarlanınca `weapon_ready` de `lp.next_attack`'e bakar (nil → hazır).
- **V1.1.7 (kullanıcı cevabı: "iki mermi atmıyor, deagle olursa atar ancak"):** sniper'larda çift yok. `head_instead = pair_ok and head_first and record_age < lag_ticks` → çift sadece gecikmeli kayıtta; görüş / Peek şartı (V1.1.6 `duel`) kaldırıldı. Log: `X: DT cifti yerine kafa (... scout'ta ikinci mermi surguden sonra)`. Harness: hedef seni görüyor (trace 30), `globals.curtime = sim + 10/64` ile gecikmeli, `nil` ile taze; `enemy.m_flSimulationTime` blok sonuna kadar 70 kalmalı (nil olunca enemy_watch kaydı silinir, yaş 0).
- Sonraki logda ölçülecek: sürgüde ölüm sayısı (hedef: 11/19 → <5), `DT cifti yerine kafa` satırlarından sonra `atis:` kafa isabeti, gecikmeli düşmanda (`bt` 13+) gövde atışı geliyor mu, toplam öldürme/ölüm, HS oranı (hedef %62 → %70+).

## V1.1.8: hata taraması (istek: "bi hata tara, geliştirme fikri düşün")

Yöntem: 4 avcı (çökme / mantık / API varsayımı / son üç sürüm) + her bulguya 2 bağımsız doğrulayıcı (refute + oyunda etkisi var mı). 22 aday, 5 gerçek:
1. **MD 130 kilit değil** (`resolver.wait.md`): Neverlose'da 100 üstü = can + fark; `clean_shot.need` zaten böyle modelliyordu. Düzeltme: bekleme açıkken `override("hitboxes", resolver.hold_boxes)` (boş liste; `fake_body` ezmesiyle aynı yerde birleştirildi, öncelik beklemede). 5. logda `sahte kayitta sadece govde (hitbox)` satırları hitbox ezmesinin oyunda çalıştığını gösteriyor (kafa 302 varken atış yok), boş liste de aynı yoldan gider; Neverlose boş listeyi reddederse `hitboxes = table ayarlanamadi` satırı çıkar, o zaman aday: `Aimbot>Ragebot>Main>Enabled` ezmesi.
2. **`fresh_hold` `sniper` (= görülme) şartına bağlıydı** → `bolt_gun` (silah) şartı; erken dönüşte `f.ticks = 0`.
3. **Gecikmeli çiftte Prefer** → `if not head_first or laggy then body_stall`.
4. **Teleport sonucu 0.02 sn'de vurulma** → `teleport.result_min = 0.12`.
5. **`player_id` xuid tipi**: sayı → `%.0f`, cdata → `tostring():gsub("U?LL$","")`. 17 haneli steam id double'da tam değil ama tutarlı yuvarlanır (test 16 haneli kullanır).
Reddedilen adaylar (kayıt için): `protect()` ilk hatadan sonra susar (bilinçli), `record_age` kendi ping'i de içerir (eşik bunu kapsıyor; `bt` ile aynı birim değil, kalibrasyon sonraki logda), duello 6 tick hep doluyor (bilinçli yazı-tura), `BAIM` göstergesi Prefer çiftinde, bolt cover eski config'de açık kalabilir (**kullanıcıya söylendi: menüde kapalı olduğunu kontrol etsin**), `sahte kayıtta sadece gövde` ezmesinin uygulanmadığı iddiası (log aksini gösteriyor).
Fikir ajanları kullanım sınırına takıldı; fikir listesi sohbette verildi (aşağıdaki açık işlere de eklendi).

## Açık işler ve bekleyen kararlar

- **Eğik peek ölümleri (kullanıcı isteği, V1.1.2):** "eğilerek peek atınca çok ölüyorum, ona da bir ayar çek". Karar sonraki Neverlose loglarıyla verilecek. Üçüncü logda (29 dk) `Peek (egik)` hiç çıkmadı; Peek ölümlerinin 10/13'ü kendi ıskasından sonra `DT %0` iken geldi → V1.1.3 DT çiftinde Body Aim Force (kafa %48 correction, gövde %16). Dördüncü logda (11 dk) eğik peek verisi geldi: 5 ölüm / 5 öldürme; ölümlerin 3'ü kendi ıskasından sonra `DT %0` iken (sürgü), biri teleport sonrası `DT %0`, biri `DEF acik`. → **V1.1.4 Bolt cover** (`cover_wanted` / `update_fd_guard`, `fd.why = "cover"`): sniper atışından sonra silah hazır olana kadar görülüyorsa fake duck zorlanır; varsayılan eğik peek, ayakta peek seçenekle (`menu.bolt_cover_stand`). **5. logda ölçüldü: işe yaramadı** (fake duck'a 14 mermi, 7 ölüm) → V1.1.6'da varsayılan kapalı; asıl kaynak DT çiftinin ikinci mermisinin gelmemesi (bkz. V1.1.6 bölümü). Düşmezse aday: kapalı tutup eğik peek'te ilk atışı DT çifti / gövdeye zorlamak (kafa %50 correction). Hazırlık yapıldı: Peek'te eğilmişken loglar ve KD paneli `Peek (egik)` etiketiyle ayrı sayar (`state_label()`; `vuruldun` / `iska` / `oldurdun` / `oldun` satırları, round özeti, Stats → `KD`). Bakılacaklar: eğik peek'teki ölümlerde faz, `DT %` / `DEF`, saldıranın `gordu` süresi, kafa mı gövde mi. Aday ayarlar: eğik peek'e ayrı AA durumu (Builder'da "Crouch peek": kendi yaw / desync / exploit), eğilirken Peek'te defensive zorlama / fake duck önerisi, ya da eğik peek'te Smart yerine Always on. Hangisi olacağı loga göre.

- **Peek AA:** loglarda peek'te en iyi faz bile kafa mermilerinin yarısını yiyordu (16/33). Faz öğrenmesi yeni düzeltildi. Kararı Stats → `AA FAZ` / `PEEK` verisine göre ver.
- **Fake duck:** kullanıcı FD'yi bilerek kullanıyor (bunny hop + ani peek). FD'deki kafa ölümleri kendi atışından hemen sonra geliyordu. Önce Stats → `KD` ile ölç.
- **R8'de temiz atış:** horoz çekerken (`m_flNextPrimaryAttack`) hiç açılmayabilir. Loglarda `sen r8 temiz` görünüyor mu bakılmalı.
- **Kullanıcıdan istenecek veriler:** `atis:`, `atis ozeti`, `vuruldun:`, `resolver:` satırları; Stats panelinin `KD`, `AA FAZ`, `LAG / TEMIZ` satırları.
- **Bilinen sınır:** Neverlose'un kendi resolver'ının içi Lua'ya açık değil. Panel bizim gördüklerimizden bir tahmin.

## Kapsam dışı

- Anti-cheat ya da sunucu korumalarını (örneğin sunucunun kapattığı roll ve cezası) atlatmaya yönelik hiçbir şey yok ve eklenmeyecek.
- Oyuncu yokken kendi kendine oynayan otomasyon (tuşsuz, AFK peek) yok. AI peek tuşla çalışır.
- GameSense sürümü ayrı dosyada: `Nykle.win.gamesense.lua` (V1.0.35; oyunda `Nykle_win_gamesense.lua` adıyla). Duman testi `tests/run_gs_smoke.sh` (`tests/gs_smoke.lua`: sahte GameSense API'si, 231 kontrol). V1.0.59: `res_panel.c` (tick başına hedef / live / entry / isim önbelleği), `res_panel.measure` (en fazla 256 kayıtlı ölçü ezberi); `menu.fps_ragdolls` → `hold("cl_disable_ragdolls", 1)`. `menu.dt_pair` varsayılan kapalı, `own.aa.pair_migrate` (`nykle_win_gs_dtpair59`) ilk post_config_load'da bir kez kapatır; sniper.record ve yükleme satırı Auto (learn) dışında `etkisiz` yazar. V1.0.58: `menu.crouch_cap` varsayılan açık; `own.aa.cc_migrate` (`nykle_win_gs_cc58`) ilk post_config_load'da bir kez açar (tt_migrate'den önce). Kanıt: V1.0.57 logunda maxdsy ≤30 kafa 5/15, 46–58 1/12. Sonraki logda: eğik yürüyüşte `yavas` etiketli vurulmalarda kafa payı, LBY uyumu round başına. V1.0.57: roll ve V1.0.53 hareket seçenekleri `grp.protect_raw`'da (önerilen ayarlar onları geri kapatıyordu); apply()'da `current.roll_was` geçişinde roll_value 45; `current.roll_flip` player_hurt'te kafa + roll ≠ 0 iken ters. V1.0.56: clean_shot.update başında tick geri gidince (yeni harita) pencereler sıfırlanır; quiet cvar'ları `enabled and nlog.quiet`; mock'ta `W.tick_shift` (tickcount + tickbase). V1.0.55: `nykle_win_gs_logver` (log sürümü, `nlog.ok_v/ver`); grp.info izlenmiyor; `resolver.can_fire` (apply_resolver başında) stall / body_stall / low sayaçlarını kapılar; aim_fire `resolver.low[target].visible = 0`; `own.dealt_n` + shot `dealt_n` (açıklanan isabet artışı damage rejection sayılmaz); clean_shot `trace_until/trace_index/fire_until`, etiket `bayrak+iz`; hava kuralı `tickcount() <= clean_shot.flag_until`; afkauto45 taşıması post_config_load'da. V1.0.54: `K.enemy_cache` (enemy_list tick başına; net_update_end / level_init / round_start / player_death / player_spawn'da silinir); `own.dead_cleanup` (tick_prepare ölü dalı + yeni player_death listener'ı, detaylı log ölüm satırından sonra); D.scan her tick, `D.nxt` ile düşman başına 4 tick; `v.lethal`; D.fire_info `vurulabilir/ates-hakki/o-gordu`; D.setting çoklu seçim + yedek kutu; log_clear işaret satırı. V1.0.53: `own.aa` (update / text / move): Valve yaw modifier tahmini `max_dsy`, `wtr`; gönderilen kayıt mesafesi `lc` (chokedcommands düşünce); `contact_at`; `lby_n/lby_same` (round özetinde sıfırlanır); hareket seçenekleri `menu.crouch_cap/crouch_speed/walk_cap/contact_stop/fs_contact/no_jump_seen` hepsi kapalı, tick_aa sonunda `own.aa.move`. Karar: birkaç oturum `maxdsy` ve hız logu birikince eğik / yürüyüş sınırının kafa oranını düşürüp düşürmediği ıskalar dahil ölçülecek. V1.0.52: `brute.next` aralık dışı / 0'dan tüm aralık; player_hurt'te eşleşen (MISS_WINDOW) gövde isabeti `record_phase(..., false)` (`enemy.shot_counted`, bullet_impact'te sıfır); `brute.phase_v = 2`, eski hafıza yüklemede `0.55 × cap/shots`, cap = bad_shots-1; iska satırı `miss.applied`; `pose_side` `< 0`; `current.air_keep` tick_prepare'de sıfır ve sadece `forced`; D.no_shot MD ≤ 100 canla sınırlı. V1.0.51: apply_defensive'te havada (`menu.air_lag`, SSG08/AWP) `clean_shot.by == "bayrak"` iken clean yok sayılır (`current.air_keep`); apply_body_aim `sniper_kind` (head_relaxed'sız) decide / fake-body / DT çifti / current.lethal için, `sniper_rule` sadece HP+1 için; `current.hidden(_tick)` → exploit_status `gizli Nt`; pending_misses `move` ve vuruldun sonu `v.. duck..`; shot `relaxed`. Eğik yürüyüş peek kafa %48 (yalnız vurulmalardan; ıskalarda hız artık loglanıyor) — kanıt yeterliyse yavaşlatma girdinin kendisine (|move| ≤ hedef/0.34) uygulanmalı. V1.0.50: low-HP Force `on(menu.resolver)` + `yaw == nil and resolver.body_open(enemy)`; `resolver.streak.list` level_init / forget_enemies'te sıfır; `charge.flat_clears`; D.no_shot can+K eşiği ve sürgü; shot `hyp_side` / `hyp_kind`; vurulma-detay `iz duvardan` / `iz acik` (trace_line saldırgan gözü → vurulan hitbox). Sonraki logda: `iz duvardan` kafa payı duruma / body moduna göre (≥30 duvar vurulması), `res seri` atış isabeti, `BY ... (duvar X)`. V1.0.49: `resolver.streak` (list[player_id] = { n, side, last, sign, bad, held }, need 3, side_need 2 (statik + |bak| 45–135, yalnız hâlâ yan dururken), window 300 sn; `streak.yaw(key, pattern, enemy)` çoklu desende nil, `streak.result` çoklu desen atışlarını yok sayar) — apply_resolver'da hypothesis.update nil dönerse `resolver.streak.yaw(key)`; aim_fire `shot.streak_yaw` + res_arm "seri"; aim_result'ta `resolver.streak.result` (işaret sadece seri açısıyla atılmış, kafaya nişanlı, hc ≥ hyp_chance ıskada değişir). Brute wall-mirror hatası (v47d #228 "-58 duvar R" duyurdu, #230 +58 atıldı) ayrıca düzeltilecek. V1.0.48: trash talk varsayılan kapalı (`nykle_win_gs_tt48`, `afk.tt_migrate` ilk post_config_load'da bir kez kapatır); `charge.update(lp, quiet)` — `recharge.discharged(now)` (atış/aim 1.5 sn, tp/dtac 1 sn, silah çekme) yokken 24 tick tutulan shift 32 tick ±1 düzse `charge.flat_full` tavanı düşürür; taban değişince, sebep penceresinde ve round_start'ta silinir (yapışkan). aim_result resolver logu cap'li seviyeyi yazar. Sonraki logda bakılacak: `yarim sarj` payı (%41'den düşmeli), eskiden bayat roundlarda `zorlanip gorulen` ve yenen mermi, sebepsiz `DT dolu`dan sonra sebepsiz düşüş var mı. V1.0.47: `charge.update` tavanı 24 tick halkasının (`charge.ring`) en küçüğünden öğrenir (round_start'ta ve DT kapanınca sıfır), `charge.full` 'sen ozeti'nde; `menu.air_hc` varsayılan 0 (`nykle_win_gs_airhc47` ile kayıtlı 40 bir kez 0, `resolver.air_migrate` post_config_load'da); `apply_body_aim`'de `sniper_rule` R8'i (`class ~= "Revolver"`) dışarıda bırakır (SNIPERS'ta kalıyor: exploit seçimi, resolver.cap, AI peek HP+1 değişmedi); `resolver.wait_apply` `w.why` / bitiş etiketleri, `aim_fire` `shot.wait_why`; `menu.roll` (varsayılan kapalı: kullanıcının sunucusunda roll yasak) / `menu.roll_value` → apply()'da `override("roll")` (yerde, hız < 100, merdivende 0; seçenek kapalıyken nil), `current.roll` `D.aim_text`'te; `D.where` düşmanda ağdan gelirse eye roll (normalde gelmez; istemci hitbox'ları roll'suz, `bas yan` denendi ve geri alındı: roll'u ölçemez). R8 `WEAPONS.Revolver[4] = false` (decide'ın scout dalları da dışarıda), `resolver.cap` ve AI peek `required_damage` R8'i HP+1 kuralından çıkarır. air_hc taşıma bayrağı ilk `post_config_load`'da yazılır. apply_resolver: SSG08 / AWP ile `prefer_safe` seviye 0'da da (rakip "extended yaw"; SP Prefer kafa %76 / Default %63; smoke'taki kontrol seviye 0'ı ayırt etmiyor, sadece açık olduğuna bakıyor). Sonraki logda bakılacak: `sarj tavani`, `bekleme yok:` sebepleri, duran hedefe kafa correction ıskaları (rakip extended). Açık soru kullanıcıda: roll'lu rakibe tam canda gövde atışı ancak MD 100'ün altına inmekle mümkün (scout gövde 73–92), kural gereği sorulmadan düşürülmez. V1.0.46: `menu.low_hp_safe` (apply_resolver'da can ≤ 30 → level 2, `resolver.low` ile 0.5 sn takılma koruması). V1.0.45 ilk oturumu: düello %45, kafa %15, ıska %47 (V1.0.44: %35 / %30 / %32). V1.0.45: V1.0.33'e göre gerileme analizi (düello %51 → %35, isabet %74 → %56) → smart_force açık, DT çifti geri, teleport / held-death / brute tabanı V1.0.33 gibi, air duck / auto AFK / crouch recharge kapalı (auto AFK `nykle_win_gs_afkauto45` ile bir kez kapatılır), şarj tavanı 30 sn / en az 6 / round başında sıfır; yeni: `menu.def_cooldown` (defensive bitişinden 1 sn sonra zorlama yok), `brute.next` + `menu.brute_random`. Smoke: eski bölümler için `random_ref` / `cooldown_ref` kapalı, `rec_ref` (önerilen ayarlar) testlerin arasında açılıp varsayılanları geri getirdiği için birkaç yerde yeniden kapatılıyor. V1.0.44: `menu.air_duck` (tick_aa'da teleport.update'ten sonra `cmd.in_duck = 1`), `teleport.hurt(now, hitgroup)` sadece kafa, `teleport.judge` en az `keep` sonuç. Havada defensive bilinçli kapalı (veri). V1.0.43: `menu.smart_force` (varsayılan kapalı = A/B'nin B kolu; `use_force`), `menu.def_ab` varsayılan kapalı; şarj tavanı `charge.hist` (saniye başına max shift, son 5 sn) → `charge.peak`. Smoke'ta eski Smart bölümleri için `force_ref` açık ve `rec_ref` erken kapatılıyor. V1.0.42: defensive A/B (`menu.def_ab`, `charge.round_no` round_start'ta artar; çift = B: window/guard/peeking sıfır). Analiz: `vuruldun`/`iska` satırlarını `test A`/`test B`'ye göre ayır; kafa / mermi ve ıska / mermi karşılaştır (kol başına ≥30 mermi). V1.0.41: şarj pozu varsayılan kapalı (poz açıkken DT dolu değilken 9/16 kafa, kapalıyken 9/28); log dosyası yeni sürümde sıfırlanır (`nlog.old`, VERSION satırından hemen sonra). Sıradaki aday: defensive'in görülürken sürekli açılıp kapanması (bir hayatta 141 bitiş) → her bitiş bir şarj; görülürken defensive'i tek uzun pencere tutmak ya da hiç açmamak A/B. V1.0.40: tarama düzeltmeleri — `grp.peek_raw` (AFK izlenmeyen grupta), otomatik AFK girdileri (`afk.cam_*`, menü / ısınma / donma), `recharge.cause` / `recharge.frozen` (pose ve öğrenme gerçek şarj sebebine bakar), `nykle_win_gs_cvars` veritabanı anahtarı, panel `post_config_load`, log kaydı canlıyken 300 sn. V1.0.39: resolver paneli varsayılanı %160, 560 / 380 (`res_panel.migrated` ile eski varsayılandan bir kez taşıma); `D.aim_text` (aa yon / dsy / body), `D.track`'te `partial`, `partial_seen`, `pose`, `def_ends`. V1.0.38: sessiz logda `developer 0` + `con_notifytime` için `hold_blind` (okunamazsa konsol komutu, kapatınca 8). V1.0.37: otomatik AFK (`afk.auto/armed/idle_since`, update_ai_peek'te; ölünce ve round_start'ta yeniden kurulur; donma süresinde sayılmaz), Clean shot yine açık (V1.0.36'da kapalıyken defensive bitişlerinde DT yeniden şarj → yarım şarj mermileri 16/28). V1.0.36: şarj pozu (`recharge.pose`, `tick_aa`'da `current.pose` → body Static + body_fs On), Clean shot varsayılan kapalı, yarım şarj mermileri `frozen` ile faz öğrenmesine girmez (`bullet_impact` → `entry.shot_frozen`, `pending_misses.frozen`, `player_hurt`), log alanları (`silah`, `gercek`, body modu, `sh`, `dtac`, `defbitti`). Sonraki logda bakılacak: `DT %10-90` satırlarında kafa oranı (%50 → %20 hedef), `sarj pozu` satırları, DT dolu + DEF açık ıska oranı, atışsız yarım şarjda `dtac` / `defbitti`. V1.0.35: AFK modu (`afk` tablosu `peek_key_held` öncesinde; `afk_strafe` ai_peek bloğunda `step`'ten sonra; DT `apply_exploit`'te, defensive `apply_defensive`'te `forced`'a `afk.on`), aspect ratio + FPS boost + `con_notifytime` (cvar `hold` saklar / geri yazar), eğikken Safe recharge (`exposure.ducked`, `menu.crouch_recharge`), görülmezken sniper Prefer (MD 90+), loglar `nlog.raw` → `client.color_log`. **Ana fonksiyon 200 local sınırında:** V1.0.35'te `EDITION` satır içine alındı, gerçek Peek tuşu `afk.key()` (tablo alanı); yeni local yerine var olan tabloya alan ekle. AFK'da `peek_key_held()` true, durum / bekleme / log `afk.key()`'e bakar. V1.0.34: hata taraması (sniper DT çifti kaldırıldı, `held_death` MD 90+ iken sayılmaz, teleport `result_min = 0.12`, kol isabeti sadece kafa, kol ıskası brute başlatmaz; ayrıntı README). Smoke testte teleport tetiklenmiyor (havada ışınlanma taklidi yok). Fikir listesi sohbette verildi: AI peek'in sniper'da öldüren açıyı kabul etmesi, serbest durumda Prefer body, Peek'te atıştan sonra geri çekilme, düşman başına 'beni vuran' hafızası. Piyasa lualarıyla karşılaştırma `LUA_KARSILASTIRMA.md`. Log analizi `LOG_ANALIZI_GS_1.0.16-21.md`; `README.md` → "GameSense edition".
