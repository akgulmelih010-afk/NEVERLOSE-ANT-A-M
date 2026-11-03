# Nykle.win lua V1.1: devir notu

Bu notu okuyan, işi kaldığı yerden devralabilsin diye yazıldı. Ayrıntılı kullanıcı dokümanı ve her özelliğin "neden"i `README.md`'de. Bu not, kodun haritası, özelliklerin tam listesi, test düzeni ve açık işler.

## Durum

| | |
|---|---|
| Dosya | `Nykle.win.lua`: tek dosya, Neverlose (CS:GO) Lua API'si |
| Sürüm | V1.1 (eski adı ANT-A-M v2–v5.6; V1.1 = GameSense V1.0.22–1.0.33'ün Neverlose'a taşınması) |
| Dal | `claude/loving-fermi-99v29v` (PR #2, taban `claude/csgo-hvh-anti-aim-kkh1vh`) |
| Oyun içi test | **Yapılmadı.** Bütün doğrulama `tests/` altındaki sahte (mock) API ile. V1.0 davranışı kullanıcının attığı Neverlose konsol loglarıyla, V1.1 değişiklikleri GameSense sürümünün on oyun loguyla ayarlandı; V1.1 için henüz Neverlose logu yok. |
| Testler | `tests/run_tests.sh`: 7 mod + strict, 999 kontrol, hepsi geçiyor (ana bölümde 195 local). `tests/mutate.py` 703 mutasyon V1.0'da yakalanıyordu; V1.1'den sonra yeniden çalıştırılmadı (~1 saat), değişen kod için desenler `SKIP` verebilir, güncellenmeli. |
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

## Açık işler ve bekleyen kararlar

- **Peek AA:** loglarda peek'te en iyi faz bile kafa mermilerinin yarısını yiyordu (16/33). Faz öğrenmesi yeni düzeltildi. Kararı Stats → `AA FAZ` / `PEEK` verisine göre ver.
- **Fake duck:** kullanıcı FD'yi bilerek kullanıyor (bunny hop + ani peek). FD'deki kafa ölümleri kendi atışından hemen sonra geliyordu. Önce Stats → `KD` ile ölç.
- **R8'de temiz atış:** horoz çekerken (`m_flNextPrimaryAttack`) hiç açılmayabilir. Loglarda `sen r8 temiz` görünüyor mu bakılmalı.
- **Kullanıcıdan istenecek veriler:** `atis:`, `atis ozeti`, `vuruldun:`, `resolver:` satırları; Stats panelinin `KD`, `AA FAZ`, `LAG / TEMIZ` satırları.
- **Bilinen sınır:** Neverlose'un kendi resolver'ının içi Lua'ya açık değil. Panel bizim gördüklerimizden bir tahmin.

## Kapsam dışı

- Anti-cheat ya da sunucu korumalarını (örneğin sunucunun kapattığı roll ve cezası) atlatmaya yönelik hiçbir şey yok ve eklenmeyecek.
- Oyuncu yokken kendi kendine oynayan otomasyon (tuşsuz, AFK peek) yok. AI peek tuşla çalışır.
- GameSense sürümü ayrı dosyada: `Nykle.win.gamesense.lua` (V1.0.33; oyunda `Nykle_win_gamesense.lua` adıyla). Duman testi `tests/run_gs_smoke.sh` (`tests/gs_smoke.lua`: sahte GameSense API'si, 71 kontrol). Piyasa lualarıyla karşılaştırma `LUA_KARSILASTIRMA.md`. Log analizi `LOG_ANALIZI_GS_1.0.16-21.md`; `README.md` → "GameSense edition".
