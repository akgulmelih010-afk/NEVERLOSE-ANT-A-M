# Nykle.win lua V1.0.3 — GameSense edition

`Nykle.win.lua` (Neverlose V1.0) sürümünün bütün özelliklerinin **GameSense (CS:GO)** Lua API'sine taşınmış hali: `Nykle_win_gamesense.lua`. Sadece HvH sunucuları için.

Neverlose sürümünün mantığı (durumlar, varsayılan açılar, exploit seçimi, Smart defensive, anti-brute fazları ve öğrenmesi, AI peek, resolver seviyeleri, temiz atış, loglar, istatistikler, panel) **aynen** korundu; açıklamaları ve "neden"leri için ana [README.md](README.md)'ye bak. Bu dosya GameSense'e özel olanları, farkları ve devir teslim notlarını anlatır.

**Kurar kurmaz çalışır.** Bütün ayarlar en iyi bilinen değerleriyle gelir (Neverlose V1.0'ın loglarla doğrulanmış varsayılanları); **Always use recommended settings** açık kaldıkça AA, exploit, builder ve resolver ayarları bu değerlerde tutulur, değiştirsen de geri döner. Clan tag ve trash talk da varsayılan açık.

## Kurulum

1. `Nykle_win_gamesense.lua` dosyasını GameSense'in lua klasörüne at (CS:GO klasörü, `csgo.exe`'nin yanı; diğer lua'ların durduğu yer). **Dosya adını değiştirme**: adda fazladan nokta olursa (eski `Nykle.win.gamesense.lua` gibi) GameSense lua'yı açamayabilir.
2. GameSense'in script listesinden `Nykle_win_gamesense` → **Load script**.
3. Konsolda `[Nykle.win] V1.0.3 (GameSense edition) yuklendi` satırı çıkar (önceden öğrenilmiş düşman varsa sonunda `(hafiza: 12 oyuncu)`).
4. Menü, NYKLE Yaw'daki gibi **AA sekmesi → Anti-aimbot angles** kutusunda: en üstte **Enable Nykle.win** ve **Nykle.win tab** (Home, Anti-Aim, Exploits, Builder, Ragebot, Visuals, Misc), altında seçilen sekmenin ayarları. Lua açıkken GameSense'in kendi AA ayarları (Pitch, Yaw, Body yaw, Freestanding ...) bu kutuda **gizlenir** (lua onları kendisi yazıyor); Enable kapatınca ya da unload edince geri görünür. Fake lag ve Other kutuları (Slow motion, On shot anti-aim tuşları) olduğu gibi kalır.
5. Tuşları bağla (Anti-Aim sekmesi): **Manual left / right / forward**, **Freestanding**, **Static inverter**. AI peek için GameSense'in kendi **Quick peek assist** tuşu (RAGE → Other) kullanılır.

- Hiçbir kütüphane (`gamesense/...`), FFI ya da internet gerekmez; "Allow unsafe scripts" açmana gerek yok.
- **Başka AA / resolver lua'larını kapat** (NYKLE AntiAim, NYKLE Yaw, NYKLE Resolver 2.5, angelwings, luasense, hysteria, metaset dahil): hepsi aynı GameSense ayarlarına ve oyuncu listesine yazar, hangisinin işe yaradığı anlaşılmaz.
- GameSense'in kendi resolver'ı (**Anti-aim correction**) açık kalmalı: bu lua onu değiştirmez, üstünde katman olarak çalışır.
- Kapatınca (Enable kapalı, script unload) ve **config kaydederken** GameSense ayarlarının hepsi senin değerlerine geri döner; config'ine lua'nın geçici değerleri kaydedilmez.

> Konsolda `[Nykle.win] menude bulunamadi: ...` ya da `oyuncu listesinde bulunamadi: ...` çıkarsa GameSense sürümünde o ayarın adı farklıdır; script çökmez, o özelliği atlar. `... ayarlanamadi: ...` = GameSense değeri kabul etmedi, 5 sn sonra tekrar dener. `... hata verdi: ...` = beklenmedik bir API değeri; script durmaz, satırı bana at.

### Lua açılmıyorsa

1. Dosya adı tam olarak `Nykle_win_gamesense.lua` olmalı (`.lua` uzantısı görünür olsun, Windows "bilinen uzantıları gizle" açıksa `Nykle_win_gamesense.lua.txt` gibi kalabilir). Eski `Nykle.win.gamesense.lua`'yı sil.
2. Konsolu aç (`~`) ve Load'a bas:
   - `[Nykle.win] YUKLENEMEDI (bu hatayi gonder): ...` → lua yüklenirken hata verdi; satırın tamamı (dosya:satır numarası ve altındaki `stack traceback`) hatanın yerini gösterir, onu gönder.
   - `[Nykle.win] ... olayi kaydedilemedi` / `menu ogesi olusturulamadi` / `menude bulunamadi` → lua açıldı ama GameSense sürümünde o olay / menü öğesi farklı; satırı gönder, o özellik kapalı çalışır.
   - Hiçbir `[Nykle.win]` satırı yoksa GameSense dosyayı hiç çalıştırmadı (dosya adı / klasör); GameSense'in kendi kırmızı hata satırını gönder.
3. Başka bir lua aynı anda yüklüyse onu kapatıp tekrar dene.

## Neverlose sürümünden farklar

GameSense'in API'si Neverlose'unkinden farklı; bazı şeyler başka yoldan yapılıyor:

| Konu | Neverlose | GameSense edition |
|---|---|---|
| AA ayarları | `ui.find(...):override()` (geçici, config'e yazılmaz) | `ui.set` ile GameSense'in AA ayarları her tick yazılır; senin değerlerin kaydedilir ve kapatınca / config kaydederken geri yazılır. Sen menüden değiştirirsen yeni değer senin değerin sayılır. |
| Desync miktarı (Left / Right limit) | Ayrı limit ayarı | GameSense'te ayrı limit yok: Body yaw `Static` + değer (≈ 2 × desync, luasense'in formülü). 58 ve üstü 180 yazılır (tam desync). Safe head 30 → 60, fake duck rastgele 48-58 → 96-116. |
| Desync tarafı | `rage.antiaim:inverter()` | Body yaw `Static` değerinin işareti; jitter'ı lua her gönderilen pakette çevirir (metaset / luasense yöntemi). Taraf eşleşmesi luasense'inki: negatif değer ↔ sağ yaw. |
| Body freestanding | `Peek Fake` / `Peek Real` | GameSense'in tek modu: **Freestanding body yaw**. Builder'da `Body freestanding: Off / On`. Anti-brute faz 5 bunu kullanır. |
| Yaw modifier | Center, Offset, Random, Spin, 3-Way, 5-Way | Center / Offset / Random / **Skitter** GameSense'in kendi `Yaw jitter`'ı; Spin, 3-Way, 5-Way lua tarafından her gönderilen pakette yaw'a eklenir. |
| Avoid overlap | Var | GameSense'te yok, builder'dan kaldırıldı (varsayılanı zaten kapalıydı). |
| Avoid backstab | Neverlose'un kendi ayarı | GameSense'in AA'sında yok: bıçaklı düşman 250 birimden yakın ve göz göze ise yüzün ona döner (NYKLE Yaw'daki yöntem). |
| Hidden (defensive) pitch / yaw | `override_hidden_pitch / yaw` | API yok: defensive penceresi tickbase'den anlaşılır, o tick'lerde pitch `Custom` / yaw ofseti yazılır (topluluk lua'larının yöntemi). Bir tick gecikebilir. |
| Defensive modları | Lag Options `On Peek` / `Always On`, HS `Break LC` | `cmd.force_defensive`. "On peek" = GameSense'in kendi davranışı + Smart / anti-peek / AI peek zorlamaları; "Always on" her tick; HS'nin Break LC'si de `force_defensive`. |
| DT şarjı | `rage.exploit:get()` | API yok: tickbase ile tick sayısı farkından tahmin (şarjlıyken tickbase ~14 tick geride kalır). Beklenen şarj = `sv_maxusrcmdprocessticks - DT fake lag limit - 1`. |
| Safe recharge | `rage.exploit:allow_charge(false)` | API yok: biri kafanı görürken atıştan / fake duck'tan sonra en fazla 1.2 sn **DT geçici kapatılır** (şarj başlamaz, yerinde donmazsın); görüş kesilince DT açılır ve dolar. Sadece DT'de (HS şarjı ölçülemiyor). Log'da `sarj bekle`, `DT %0`. |
| Havada teleport | `rage.exploit:force_teleport()` | `cmd.discharge_pending = true` (hysteria'nın yöntemi). Sadece DT ile (HS'de şarj ölçülemiyor); zıplama başına 1, inişe 0.35 sn'den az kaldıysa yok — kurallar aynı. Şarj harcanmazsa konsola bir kez yazar. |
| Fake duck bırakma | `override(false)` | GameSense'te fake duck sadece tuş: tuş geçici olarak boşaltılır (`On hotkey`, tuş yok), neden bitince senin tuşun ve modun geri yazılır. |
| AI peek sırasında Peek Assist | `override(false)` | Quick peek assist'in **kutusu** geçici kapatılır; tuşun okunmaya devam eder (basılı / toggle). |
| Safe point / Body aim | Tek global ayar (hedefin seviyesine göre) | **Düşman başına** oyuncu listesinden: `Override safe point: On` (Force) ve `Override prefer body aim: On / Force / Off`. Seviye 1 (Prefer) silahın `Prefer safe point` ayarı (Neverlose'daki gibi hedefe göre). |
| Sniper Min. damage (HP + 1) | `Min. Damage` override | GameSense'te rage ayarları silah grubuna göre ayrı (**Weapon type**): sadece elindeki silahın grubu menüde seçiliyken yazılır; silah değişince eski grubun değeri seçici kısa süre o gruba çevrilip geri yazılır (angelwings'in yöntemi). Senin **Minimum damage override** tuşun basılıysa dokunulmaz. |
| Sahte kayıtta gövde (sniper) | Hitbox listesi Chest + Stomach | O hedefe oyuncu listesinde `Override prefer body aim: Force` (12 tick, sonra 0.5 sn serbest) — kural aynı. |
| Resolver ıskası | `aim_ack` → `correction` | `aim_miss` → `?`. Sunucudaki isabet sayısı (`m_totalHitsOnServer`) atıştan sonra değiştiyse `damage rejection` (angelwings'in yöntemi), yoksa `correction`. |
| Kalıcı hafıza | Neverlose `db` (`ant_a_m_memory`) | GameSense `database` (`nykle_win_gs_memory`); biçim aynı, Neverlose hafızası taşınmaz. |
| Resolver paneli | Verdana, serbest boyut, tık menüye geçmez | GameSense fontları sabit: **Size** üç kademede font seçer (<85, 85-139, 140+). GameSense'te tıklamayı menüden saklayan olay yok: paneli menünün üstüne taşıma. |
| Menü | Neverlose sekmeleri, ikonlar, tooltip'ler | AA sekmesi → Anti-aimbot angles (NYKLE Yaw, luasense, angelwings gibi; Neverlose'daki iki sütun tek kutuda alt alta), `Nykle.win tab` seçicisi; ikon / tooltip API'si yok (açıklamalar bu dosyada ve README.md'de). Bütün öğe adlarında görünmez bir ek var (başka lua'larla çakışmasın). |

## GameSense'e özel: resolver katmanı

Açıları yine GameSense'in kendi resolver'ı çözer. Bu katman her aimbot atışının sonucuna bakar (`aim_fire` / `aim_hit` / `aim_miss`). Seviye **düşman başına ve düşmanın hareket durumu başına** (`Standing` / `Slow walk` / `Moving` / `Crouch` / `Air` / `Fakeduck`) son 4 sonuçtaki resolver ıskası sayısıdır (Neverlose V1.0 kuralları: sahte kayda / LC kırana giden ıska öğrenilmez, jitter sadece gerçek kayıtlardan ölçülür, kafaya nişan alınıp gövdeye gelen isabet sayılmaz, jitter ön bilgisi, Force takılma koruması):

| Seviye | Ne zaman | Ne yapılır |
|---|---|---|
| 0 | Resolver ıskası yok | Senin ayarların |
| 1 | 1 ıska ya da jitter ön bilgisi | Silahın **Prefer safe point** ayarı açılır (hedef bu düşmanken) |
| 2 | 2+ ıska, en az biri **bu haritada** | Oyuncu listesinde **sadece o düşmana** `Override safe point: On` (Force). DT'li silahta o düşmana gövde tercihi (Smart body aim). Sniper sadece öldürecek atış yaparken ya da düşmanın sadece kafası görünürken `Prefer`'de kalır |
| 3 | Force'ta da 3+ ıska, ya da Force atışı engelliyor (0.5 sn görülüp ateş yok) | **Body yaw hipotezleri** (NYKLE Resolver 2.5'ten): o düşmana oyuncu listesinde `Force body yaw` sırayla **+58 / -58 / 0 / +29 / -29** (Hypothesis yaw limit). Jitter'lı düşmana denenmez (Force safe point'te kalır). Kafaya giden uygun bir atış (backtrack yok, teleport / extrapolation / interpolation / öncelikli kayıt yok, isabet şansı ≥ %70, açı ateş anında oyuncu listesinde gerçekten yazılı) **kafadan isabet** alırsa açı tutulur; **resolver ıskası** alırsa sıradaki açı denenir; hepsi denenince GameSense'in resolver'ına dönülür ve 4 sn beklenir. Açı seçiliyken safe point `Prefer` (Force seçilen açıyı gereksiz kılar). 30 sn veri gelmezse açı bırakılır. |

- Senin kendi oyuncu listesi ayarların hiç düşürülmez: o düşmana kendin `Force body yaw` ya da bir override verdiysen dokunulmaz; `Correction active` kapalıysa hipotez uygulanmaz.
- Slot başka bir oyuncuya geçerse (aynı index) eski değerimiz yeni oyuncuya kalmaz; listeden çıkan / ölen / dormant olan düşmandaki ezmeler hemen geri verilir; harita değişince de geri verilir.
- Göstergede `RES 1 JIT`, `RES 2 AIR`, hipotezde `RES 3 BY 58`; atış satırında `| BY 58°`; resolver panelinde `BY 58°`.
- Hipotezler oturumluk (oyun kapanınca unutulur); seviyeler ve anti-brute fazları Steam ID ile kalıcı hafızada.

### V1.0.3 resolver düzeltmeleri

- **Teleport / extrapolation kayıtları:** GameSense'in kaydın yerini tahmin ettiği atışlardaki (`aim_fire`'da `teleported` / `extrapolated`) `?` ıskası artık resolver ıskası sayılmaz; atış satırında `| resolver'a sayilmadi: teleport` yazar. Önceden LC kıran düşmana kaçan mermiler seviyeyi boşuna Force'a çıkarıyordu.
- **Uygulanmayan hipotez öğrenmez:** Atış ancak ateş anında oyuncu listesinde `Force body yaw` açık ve değeri adayın açısıysa o adaya yazılır (`Correction active` kapalıyken ya da kendi Force body yaw'ın varken atılan atışlar sayılmaz). NYKLE Resolver 2.5'teki kontrol.
- **Force için bu haritada ıska:** Hafızadan (ya da önceki haritadan) gelen ıskalar en fazla `Prefer`'e çıkarır; o durumda bu haritada bir resolver ıskası olunca Force açılır. Haftalar önceki iki ıska ilk peek'te Force safe point'le atışı geciktirmez.
- **AA deseni yönle ölçülür:** Yaw değişimleri işaretli tutulur. 25°+ değişimler sırayla sağa-sola gidiyorsa `jitter` (gecikmeli jitter dahil), hep aynı yöne gidiyorsa `spin`, büyük değişim yoksa `statik`. Desen iki güncelleme üst üste aynı çıkınca değişir. Önceden ortalama büyüklüğe bakılıyordu: spin atan ya da hızlı dönen düşman da jitter sayılıp ilk atıştan `Prefer` alıyordu. Atış satırında `AA jitter 80` / `AA spin` / `AA statik`.
- **Jitter'a hipotez yok, desen değişince sıfırla:** Force body yaw sabit bir açı yazar, her pakette taraf değiştiren jitter'a karşı yarı yarıya tutar; jitter'lı düşman Force safe point'te kalır. Düşmanın deseni değişince (statik → jitter gibi) o durumdaki hipotez sonuçları silinir: `resolver: isim Standing AA deseni degisti (static -> jitter): hipotezler sifirlandi`.
- **Slow walk ayrı durum:** Yürüme hızının altı (silahın en yüksek hızının %52'si, okunamazsa 120 birim/sn) `Slow walk`; desync orada tam, koşarken azalıyor, ayrı öğrenilir.
- Değişmeyen: kafaya nişan alınıp gövdeye gelen isabet sayılmaz, ama gövdeye nişan alınıp gelen isabet (safe point dahil) resolver başarısı sayılır (Neverlose V1.0'daki gibi). Bu kuralı değiştirmek loglarla karar verilecek bir şey.
- Safe point / body aim kararları her görünen düşman için ayrı verilir (Neverlose'da hedefin kararı herkese uygulanıyordu).

## Referans lua'lardan alınanlar

`GameSense_Lua_Secimi_2026-10-05` içindeki 7 lua incelendi:

| Lua | Alınan | Alınmayan / neden |
|---|---|---|
| **NYKLE Resolver 2.5** | Oyuncu listesi `Force body yaw` hipotezleri (aday açılar, uygun atış kuralları, sahiplik ve geri yükleme, slot değişince eski ayarı taşımama) — seviye 3 olarak | Her düşmanda 2 ıskadan sonra açı değiştirme: Neverlose'un kanıtlanmış seviye 1-2 kuralları korundu, hipotez sadece onlar yetmeyince |
| **NYKLE AntiAim 1.1.1** | "Sadece bizim yazdığımız değer hâlâ duruyorsa geri yaz, kullanıcı değiştirdiyse dokunma" geri yükleme kuralı (ezme sistemi) | AA profilleri (Neverlose sürümünün log'larla doğrulanmış varsayılanları kullanıldı) |
| **NYKLE Yaw 1.2.1** | GameSense menü yolları, manuel tuşlar (`On hotkey` + basışta aç/kapa), avoid backstab yöntemi, `cmd.force_defensive`, **trash talk** (İngilizce) | Klan tag, animation breaker, aspect ratio, ikinci zoom FOV, 3D hitmarker, konsol filtresi, NewsAPI yaması (AA / resolver dışı; istenirse eklenir) |
| **angelwings** | `damage rejection` ayrımı (`m_totalHitsOnServer`), silah grubu seçicisini çevirerek silah grubuna bağlı ayarları geri yükleme, silah grubu adları (`SSG 08`, `AWP`, `R8 Revolver`...) | Deneysel resolver (rastgele, negatif olabilen açı), aerobic exploit |
| **luasense** | Body yaw değeri ≈ 2 × desync ve sağ / sol yaw eşleşmesi | "luasense" jitter tipleri, sabit değerle unload |
| **hysteria** | Havada teleport için `cmd.discharge_pending` | Resolver (build bayraklarına bağlı, backend / keygen çağrıları) |
| **metaset** | Lua yönetimli `Static ±` body yaw jitter'ı (gönderilen pakette taraf çevirme) | Animasyon katmanından resolver (FFI / native layout, iki `net_update_end`'de çalışıyor, doğrulanamıyor) |

## Menü

Yeri: **AA → Anti-aimbot angles**. Sekme `Nykle.win tab` ile seçilir. Varsayılanlar Neverlose V1.0 ile aynı (en iyi bilinen değerler, ayarlamana gerek yok); ayrıntılı açıklamalar README.md'deki aynı adlı ayarlarda. Builder'da durum seçilince altında o durumun açıları, onun altında **<durum> exploit** başlığıyla exploit ayarları görünür.

### Home
| Ayar | Varsayılan | Not |
|---|---|---|
| Enable Nykle.win | Açık | Kapatınca bütün GameSense ayarların ve oyuncu listesi geri verilir. |
| Always use recommended settings | Açık | AA, exploit, builder ve resolver ayarlarını önerilen değerlerde tutar (yüklemede, config yüklenince, oyunda saniyede bir). Bind'lere, loglara, görsellere ve Misc'e dokunmaz. |
| Forget learned enemies (Memory) | — | Fazlar, resolver seviyeleri, sniper verisi ve hipotezler silinir (hafıza dahil). |
| Reset stats (Memory) | — | İstatistikleri sıfırlar. |
| Resolver / Shot / Hit log (Console) | Açık | Neverlose sürümündeki loglar. |
| Anti-brute log (Console) | Kapalı | |

### Anti-Aim
| Ayar | Varsayılan | Not |
|---|---|---|
| Pitch | Down | `Down`, `Minimal`, `Off` (GameSense'te fake pitch yok). |
| Yaw base | At Target | Ateş ettiğin / seni gören / sana ateş eden düşmana döner (Neverlose V1.0 kuralları). |
| Manual left / right / forward | Tuş | Basınca o yön, aynı tuşa tekrar basınca kapanır. Tuşlar `On hotkey` modunda tutulur. |
| Static inverter | Tuş | Body yaw `Static` olan durumlarda tarafı çevirir (toggle / hold modunu sen seç). |
| Avoid backstab | Açık | Bıçaklı düşman 250 birimden yakın ve görünürse ona döner. |
| Legit AA on use | Açık | E'de AA devam eder (bomba / rehine yanında karışmaz). |
| Spin when idle | Açık | Warmup kapalı, canlı düşman yokken; pitch Off, hız 6. |
| Freestanding | Tuş | + `FS: disable in air` (açık), `crouching / slow walking / moving` (kapalı), `auto when standing still` (açık). |
| Safe head | Açık | Bıçak / zeus ile havada eğilirken; `any air crouch` ve `high ground` kapalı. |
| Anti-bruteforce | Açık | 5 faz, kendi kendine öğrenme, düşman başına hafıza; `reset after` 6 sn. |
| Release fake duck near knife | Açık | |
| Fake duck only when standing still | Kapalı | |

### Exploits
| Ayar | Varsayılan | Not |
|---|---|---|
| Auto exploit | Açık | Durumun DT / HS seçimini uygular (DT tuşu `Always on` yapılır, kapatınca geri). |
| Snipers (SSG08/AWP/R8) | Auto (learn) | |
| Safe recharge | Açık | GameSense'te DT geçici kapatılarak (yukarıya bak). |
| Hidden spin speed | 10 | |
| Auto peek | Açık | |
| AI peek (hold Quick peek assist) | Açık | Quick peek assist tuşunu basılı tut, hareket tuşlarına basma. Duvar kontrolü GameSense'te hull izi olmadığı için diz ve göz hizasında, gövdenin iki yanında çizgilerle. |
| Defensive during AI peek | Açık | |
| Defensive vs enemy peeks | Açık | |
| Teleport in air when seen | Açık | Sadece DT ile. |
| Air lag (defensive every tick) | Açık | |
| Clean shot (no lag while shooting) | Açık | |
| Snipers use DT in the air | Kapalı | |

### Builder
Neverlose sürümüyle aynı 13 durum ve aynı varsayılanlar (`State` listesi solda, durumun exploit'i sağda). Farklar: `Avoid overlap` yok; `Body freestanding` `Off / On`; `Yaw modifier` listesinde `Skitter` var.

### Ragebot
| Ayar | Varsayılan | Not |
|---|---|---|
| Adaptive resolver | Açık | Yukarıdaki seviye tablosu. |
| Body yaw hypotheses (Force body yaw) | Açık | Seviye 3. Kapatırsan Neverlose sürümünün davranışı (en fazla Force safe point). |
| Hypothesis yaw limit | 58 | Aday açılar ±limit, 0, ±limit/2. |
| Hypothesis min hit chance | %70 | Bundan düşük isabet şanslı atışlar hipotezi değiştirmez. |
| Smart body aim | Açık | Düşman başına (oyuncu listesi). Senin **Force body aim** tuşun basılıyken dokunulmaz. |
| Head unless body kills (snipers) | Açık | Min. damage HP + 1 (GameSense'te 101), elindeki silahın grubunda. |
| Snipers: lethal body on fake records | Açık | |

### Visuals
Crosshair indicators (+ renk), Manual arrows (+ renk), Stats panel (kapalı), Resolver panel (açık; Size 100, Position X 12, Y 330 — menü açıkken sürükle / sağ alttan büyüt). Göstergeler GameSense'in küçük piksel fontuyla (`-`).

### Misc: Clan tag
NYKLE Yaw'daki animasyonlu clan tag: **Clan tag: Nykle.win (animated)**, varsayılan **açık**. Önce `Nykle.win` 1.2 sn görünür, sonra harf harf yazılır (`N`, `Ny`, `Nyk` ... `Nykle.win`, her kare 0.45 sn) ve döner. NYKLE Yaw gibi paket gönderilen tick'te (`run_command`, chokedcommands 0) ve iki tick'te bir `paint`'te güncellenir.

- Açıkken GameSense'in kendi **Clan tag spammer**'ı (MISC → Miscellaneous) kapatılır; clan tag'i kapatınca, Enable kapatınca, config kaydederken ve unload'da senin değerine geri döner.
- Kapatınca eski etiket geri yazılır: `gamesense/steamworks` kütüphanesi yüklüyse (NYKLE Yaw'ın kullandığı) Steam grubunun etiketi okunur, yoksa etiket boşaltılır. Kütüphane şart değil.
- Önerilen ayarlara girmez: kapatırsan kapalı kalır.

### Misc: Trash talk
NYKLE Yaw'daki öldürme / ölme cümlelerinin **birebir İngilizce** çevirisi (küfürler dahil; 38 öldürme, 44 ölme seti). Varsayılan **açık**, önerilen ayarlara girmez (kapatırsan kapalı kalır).

| Ayar | Varsayılan | Not |
|---|---|---|
| Trash talk | Açık | Ana anahtar. |
| On kill | Açık | Bir düşmanı öldürünce (takım arkadaşı sayılmaz). |
| Kills: headshots only | Kapalı | Sadece kafadan öldürünce. |
| On death | Açık | Bir oyuncu seni öldürünce (düşme / intihar sayılmaz). |
| Chance | %100 | Her olayda yazma olasılığı. |
| Chat | All chat | `All chat` (`say`) ya da `Team chat` (`say_team`). |
| Message delay | 2.3 sn | Satırlar arası bekleme, cümle uzunluğuna göre (NYKLE Yaw: öldürünce uzunluk / 24, ölünce / 20 × bu değer). |

Bir cümle seti bitmeden yenisi başlamaz (chat dolmasın). Satırlardan konsol komutunu bozabilecek `;` ve `"` çıkarılır.

## Loglar

Neverlose sürümündeki bütün loglar aynı biçimde (atış satırı, vuruldun / ıska, round özeti, atış özeti, AI peek, anti-brute, sniper exploit, teleport, fake duck). GameSense farkları:
- Atış satırında `SP` = o anki safe point (`Force` = oyuncu listesi ya da Force safe point tuşu, `Prefer` = silahın Prefer safe point'i), `BA` = o düşmanın oyuncu listesi body aim'i (`Prefer` / `Force` / `Off` / `Default`), hipotez varsa sonda `| BY 58°`.
- Iska nedenleri GameSense'in: `correction` (GameSense `?`), `damage rejection`, `spread`, `prediction error`, `unregistered shot`, `death`.
- `vuruldun` satırında `DT %0, ... sarj bekle` = Safe recharge DT'yi o an tutuyordu.
- Hipotez: `resolver: isim Standing 3 resolver iskasi -> body yaw 58° denenecek`, `... body yaw 58° iskaladi -> body yaw -58° denenecek`, `... GameSense resolver'ina donuldu (hepsi denendi)`.

## Testler

`tests/gamesense/` altında GameSense API'sini taklit eden sahte bir ortam (`mock_gs.lua`) ve senaryolar (`run_tests.lua`) var:

```
luajit tests/gamesense/run_tests.lua Nykle_win_gamesense.lua
```

Test edilenler: yükleme; resolver V1.0.3 (teleport / extrapolation ıskasının sayılmaması, jitter'lı düşmanda hipotez olmaması ve Force safe point, yeni haritada eski ıskalarla Force açılmaması ve bu haritadaki ıskayla açılması, statik düşmanda hipotez başlaması, Correction kapalıyken adayın öğrenmemesi, desen değişince hipotezlerin sıfırlanması, spin'in jitter sayılmaması, Slow walk / Moving ayrımı); menünün AA → Anti-aimbot angles kutusunda olması ve GameSense AA ayarlarının lua açıkken gizlenip kapalıyken / kapanışta geri görünmesi; clan tag animasyonu (sıra ve süreler), GameSense spammer'ının kapatılıp geri verilmesi, kapatınca etiketin geri yazılması; trash talk ve clan tag'in varsayılan açık olması; durumlar (durma, yürüme, hava, eğilme, slow walk, fake duck, manuel, legit AA, merdiven, spin); AA'nın GameSense ayarlarına yazılması; auto exploit; DT şarj tahmini; görülürken Smart defensive zorlaması; temiz atışta zorlama olmaması; havada teleport (`discharge_pending`); aimbot olayları (`?` → correction, damage rejection, spread, isabet); seviye 1-2-3 (oyuncu listesi Force safe point ve body yaw hipotezleri); anti-brute (kafanın yanından geçen mermi, vurulma); sniper Min. damage'ın sadece kendi silah grubuna yazılıp silah değişince geri verilmesi; bıçaklı düşman yakınken fake duck bırakma ve geri verme; AI peek sırasında Quick peek kutusunun geri verilmesi; round / ölüm / harita olayları; resolver panelinin sürüklenmesi; stats paneli; trash talk (kapalıyken yazmama, öldürünce / ölünce, takım chati, sadece headshot, takım arkadaşında yazmama, tehlikeli karakter temizliği); 1500 tick rastgele durum / olay / menü değişikliği (fuzz); **config kaydederken ve kapanışta bütün GameSense ayarlarının (her silah grubu dahil) ve oyuncu listesinin geri verilmesi**; hafızanın yazılması; hiçbir olay fonksiyonunun hata vermemesi. Derleme LuaJIT 2.1 ile (GameSense'in Lua'sı); tanımsız global kullanımı yok.

**Oyunda test edilmedi.** Sahte ortam GameSense'in davranışını tahmin eder; aşağıdakiler gerçek oyunda doğrulanmalı.

## Bilinen sınırlar ve kontrol edilecekler

- **Desync miktarı ölçeği:** Body yaw değeri ≈ 2 × desync varsayımı luasense'ten. Tam desync (58+) her durumda 180 yazıldığı için doğru; sadece düşük limitlerde (safe head 30, fake duck 48-58) gerçek miktar farklı olabilir.
- **DT şarj tahmini** tickbase'den; ping çok oynarsa göstergede DT kısa süre turuncu / beyaz yanlış görünebilir. `DT` göstergesi ve `vuruldun` satırındaki `DT %` buna göre.
- **Oyuncu listesi alan adları** (`Override safe point`, `Override prefer body aim`, `Force body yaw`, `Correction active`): GameSense sürümünde farklıysa konsola bir kez `oyuncu listesinde bulunamadi` yazar ve o özellik (safe point Force / smart body aim / hipotez) kapanır, gerisi çalışır.
- **Weapon type seçici:** Menüde başka bir silah grubunu incelerken o tick sniper Min. damage'ı yazılmaz (yanlış gruba yazmamak için). GameSense sürümünde seçici yoksa ayar tek gruba yazılır.
- **Safe recharge** DT'yi kısa süre kapattığı için o sırada GameSense'in normal fake lag'i devrede olabilir.
- **Teleport** GameSense sürümünde `discharge_pending` çalışmıyorsa konsola bir kez `teleport: sarj harcanmadi` yazar.
- Neverlose ile GameSense arasında hafıza taşınmaz (ayrı anahtar).
