# Nykle.win lua V1.0.20 — GameSense edition

`Nykle.win.lua` (Neverlose V1.0) sürümünün bütün özelliklerinin **GameSense (CS:GO)** Lua API'sine taşınmış hali: `Nykle_win_gamesense.lua`. Sadece HvH sunucuları için.

Neverlose sürümünün mantığı (durumlar, varsayılan açılar, exploit seçimi, Smart defensive, anti-brute fazları ve öğrenmesi, AI peek, resolver seviyeleri, temiz atış, loglar, istatistikler, panel) **aynen** korundu; açıklamaları ve "neden"leri için ana [README.md](README.md)'ye bak. Bu dosya GameSense'e özel olanları, farkları ve devir teslim notlarını anlatır.

**Kurar kurmaz çalışır.** Bütün ayarlar en iyi bilinen değerleriyle gelir (Neverlose V1.0'ın loglarla doğrulanmış varsayılanları); **Always use recommended settings** açık kaldıkça AA, exploit, builder ve resolver ayarları bu değerlerde tutulur, değiştirsen de geri döner. Clan tag ve trash talk da varsayılan açık.

## Kurulum

1. `Nykle_win_gamesense.lua` dosyasını GameSense'in lua klasörüne at (CS:GO klasörü, `csgo.exe`'nin yanı; diğer lua'ların durduğu yer). **Dosya adını değiştirme**: adda fazladan nokta olursa (eski `Nykle.win.gamesense.lua` gibi) GameSense lua'yı açamayabilir.
2. GameSense'in script listesinden `Nykle_win_gamesense` → **Load script**.
3. Konsolda `[Nykle.win] V1.0.20 (GameSense edition) yuklendi` satırı çıkar (önceden öğrenilmiş düşman varsa sonunda `(hafiza: 12 oyuncu)`).
4. Menü, NYKLE Yaw'daki gibi **AA sekmesi → Anti-aimbot angles** kutusunda: en üstte **Enable Nykle.win** ve **Nykle.win tab** (Home, Anti-Aim, Exploits, Builder, Ragebot, Visuals, Misc), altında seçilen sekmenin ayarları. Lua açıkken GameSense'in kendi AA ayarları (Pitch, Yaw, Body yaw, Freestanding ...) bu kutuda **gizlenir** (lua onları kendisi yazıyor); Enable kapatınca ya da unload edince geri görünür. Fake lag ve Other kutuları (Slow motion, On shot anti-aim tuşları) olduğu gibi kalır.
5. Tuşları bağla (Anti-Aim sekmesi): **Manual left / right / forward**, **Freestanding**, **Static inverter**. AI peek için GameSense'in kendi **Quick peek assist** tuşu (RAGE → Other) kullanılır.

- Hiçbir kütüphane (`gamesense/...`) ya da internet gerekmez; "Allow unsafe scripts" açmana gerek yok. Sadece **Copy all logs** panoya kopyalamak için FFI kullanır; FFI yoksa loglar konsola yazılır (dosyada da durur).
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
| Havada teleport | `rage.exploit:force_teleport()` | `cmd.discharge_pending = true` (hysteria'nın yöntemi). Sadece DT ile (HS'de şarj ölçülemiyor); zıplama başına 1, inişe 0.35 sn'den az kaldıysa yok — kurallar aynı. Şarj harcanmazsa konsola bir kez yazar. V1.0.13: bir haritada son 3 teleportun 2'sinden sonraki 1.5 sn içinde vurulduysan o harita boyunca kapanır. |
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

### V1.0.20: V1.0.17 (sıfırlama sonrası), V1.0.18 ve V1.0.19 logundan (16:21–17:10)

Hepsi de_mirage. V1.0.17 hafıza sıfırlandıktan sonra (16:21–16:44): 38 kill / 22 ölüm. V1.0.18 (16:44–16:55): 3 / 10. V1.0.18'in 10 ölümünün 6'sı T spawn'da duvardan; lua kaynaklı bir şey görünmüyor. V1.0.19 (16:55–17:10): 14 / 17.

Değişen (sadece loglar; oyundaki davranış aynı):

- **Denenmemiş faza geçiş artık "0/0 kafa isabeti" yazmıyor.** 16:24:44'te `AA (peek): en az vurulan faz 1 (0/0 kafa isabeti)` yazıldı. Faz 1 en az vurulan değildi, hiç denenmemişti. Geçişin sebebi faz 0'ın kafa yemesiydi (V1.0 kuralı: ~%40'ın üstünde kafa yiyen fazın yerine denenmemiş faz denenir). Yeni satır: `AA (peek): faz 0 cok kafa yiyor (2/2 kafa isabeti) -> verisi olmayan dusmanlara denenmemis faz 1`. Verisi olan bir faza geçince satır eskisi gibi: `en az vurulan faz N (x/y kafa isabeti)`.
- **Harita başında round başlığı bir kez yazılıyor.** 16:46:03'te ve 13:58:08'de round_start arka arkaya iki kez geldi, `dbg ===== round 1 | de_mirage | sen ? =====` de iki kez yazıldı. Artık arada başka satır yoksa aynı başlık tekrar yazılmıyor. Kazananı olmayan round sonu (`? kazandi`, 5 kez, hepsi harita başında) artık `round sonu: kazanan yok (oyun basi / yeniden baslatma)`.

Logda görülen, kodda değişmeyenler:

- **V1.0.19'un gevşeyen kafa kuralı çalışıyor.**
  - 16:55:43'teki satır: `ogrenildi: AF1 ... (senin Min. damage'in 100: seni gorurken gecici 70)`. 16:56:34'ten sonra kural herkese uygulandı.
  - Düşman seni görürken atışlar MD 70 ile gitti.
  - Gövdeye öldürmeyen 5 isabet oldu (87, 86, 75, 89, 90): 3'ünde ikinci mermiyle kill aldın, 1'ini takım arkadaşın bitirdi, 1'inde öldün.
- **HS ret kuralı hiç tetiklenmedi** (`reddediyor` satırı yok).
- **Silah değişirken defensive sayacı** `sen ozeti`nde görünüyor (`silah degisirken 83`, `86`).
- **Sniper hep DT'deydi.**
  - "Forget learned enemies" 10 kez basıldı. Bu düğme sniper istatistiğini de siliyor, bu yüzden HS 0/0 kaldı. DT'de kafa oranı %40'ın altında olduğu için keşif de olmadı.
  - DT'deyken düşmanın scout mermilerinin %28'i kafana geldi (95 mermide 27). Önceki oturumda HS'de bu oran %38'di. DT'de kalmak doğru.
  - `6/34 → 8/29` gibi düşen sayılar, 40 mermiyi geçince yapılan yarılamadan.
- **Havada teleport mirage'da iki kez kendini kapattı** (`son 3 isinlanmanin 2'sinde hemen vuruldun`). V1.0.13 kuralı.
- **Safe recharge değişmedi.**
  - V1.0.19'daki 17 ölümün 9'unda vurulma satırı `DT %0, sarj bekle, atis 0.05–1.15s` diyor. Yani scout'la ateş ettin, DT boşaldı, düşman seni görüyordu ve şarj bekletildi. Bekletilmeseydi şarj seni ~14 tick yerinde dondururdu.
  - V1.0.10 – V1.0.19 loglarında düşman mermilerinin sana isabet oranı:

    | Durum | İsabet |
    |---|---|
    | Şarj beklerken | %62 (78 mermi) |
    | DT doluyken | %70 (159 mermi) |
    | Beklemeden şarj olurken | %73 (63 mermi) |

    Iska olarak sadece kafanın yanından geçen mermiler sayılıyor, bu yüzden üç oran da aynı ölçüde yüksek çıkıyor.
  - Bekletmenin zararı görünmüyor. Bu ölümlerin sebebi ateş ettikten sonra açıkta kalmak.
- **Bıçak / zeus yakınken uygulanan MD 30 kuralı değişmedi.**
  - furkan iki kez havadan zeus'la öldürdü (16:56:11, 17:05:37). İkisinde de scout'un tek mermisi gövdeye gitti ve öldürmedi (93 ve 43 hasar).
  - Ama V1.0.10 – V1.0.19 loglarında bu durumda gövdeye giden ve öldürmeyen 7 isabetin 4'ünden sonra düşmanı yine sen öldürdün.
  - Aynı durumda öldürecek kafa atışı olarak nişan alınan 7 merminin hepsi ıskaladı (correction / damage rejection). Kafa kuralına dönmek daha iyi olmazdı.

### V1.0.19: V1.0.17 logundan (13:27–16:20, ~3 saat)

de_dust2, cs_office, de_mirage. 362 atış (184 isabet, 106 correction, 34 damage rejection, 25 spread), düşmandan 340 mermi (147 kafa).

Değişen:

- **"Sunucu Hide shots'u reddediyor" kuralı artık gürültüyle tetiklenmiyor.** V1.0.8'in kuralı (aynı exploit'le 60 sn'de 2 damage rejection → sniper'da 5 dk öteki exploit) 4 kez tetiklendi (14:23:14, 15:28:36, 15:58:17, 16:16:52) ve scout'u toplam 20 dk DT'de bıraktı. Ama ret oranı HS'ye özgü değil: HS'de 311 atışta 28 (%9), DT'de 35 atışta 5 (%14). Tetiklerin 3'ü aynı düşmana 1-3 sn arayla iki retti (x_x, PEX PEEK, furkan); bu o düşmanın kaydı / pingi (V1.0.17'de Haise, bu logda Elmacı: 43 atışta 9 ret). Bu 20 dakikada DT'deki 28 sniper mermisinin 18'i kafaya geldi (%64); HS'de 308'de 118 (%38). Yeni kural: lag yokken o exploit'le atılan **son 4 atışın 3'ü** 120 sn içinde reddedildiyse ve **en az 2 farklı düşmana** ise. Bu kural V1.0.10 – V1.0.17 loglarının hiçbirinde tetiklenmiyor (eski kural V1.0.10 – V1.0.16'da da 3 kez tetiklenmişti); sunucu HS'yi gerçekten reddediyorsa 3 atışta yakalar. Log: `sunucu Hide shots ile atilan atislari reddediyor (son 4 atisin 3'i, 2 dusmanda, son: damage rejection) -> sniper'da 5 dk Double tap`.
- **"Kafa beklerken öldün → gövde de atılacak" öğrenmesi artık senin Min. damage'ınla da çalışıyor.** SSG 08 Min. damage'ın 100. Bu yüzden 13 `ogrenildi ... kafa beklerken` satırının hiçbiri bir şey değiştirmedi (`ama senin Min. damage'in 100: govde yine atilmaz`). En sık `sikmadi` sebebi de buydu: 93 kez `hasar N < MD 100`, 56'sı 70-89 hasar. Artık kural gevşeyince (o düşman ya da haritada 2 ölümden sonra herkes) **seni görürken** Min. damage geçici **70** (zırhlı göğüs ~75). Görmezken senin 100'ün, yeni haritada yine kafa kuralı (101). Minimum damage override tuşun basılıyken dokunulmaz; Min. damage'ın 70 ya da altındaysa değişmez. Log: `ogrenildi: ... -> bu haritada ona karsi govde de atilacak (senin Min. damage'in 100: seni gorurken gecici 70)`.
- **Copy all logs başarısız olunca sebebi yazıyor** (`FFI yok: GameSense'te Allow unsafe scripts kapali`, `VGUI_System010 arayuzu bulunamadi`, `hata: ...`). Bu logda 17 kez `panoya kopyalanamadi` var (V1.0.10 – V1.0.16'da hep kopyalanıyordu). 16:20:52'de 2 sn'de 13 kez basıldı, her basışta 4300 satır yeniden konsola yazıldı. Artık loglar 10 sn içinde ikinci kez konsola yazılmıyor (`loglar 2 sn once konsola yazildi (yukari kaydir)`).

Logda görülen, kodda değişmeyenler:

- **Yüklemede sniper durumu doğru seçildi:** `sniper exploit (hafiza): Hide shots 13/38, Double tap 6/8 kafa isabeti -> Hide shots`. DT 8 mermisini gördü (V1.0.17 kuralı), sonra oranlar karşılaştırılıp HS seçildi. Bu oturumun sayıları da HS'yi doğruluyor (%38'e karşı %64 kafa).
- **Havada teleport 12 kez, hiçbirinden sonra 1.5 sn içinde vurulma yok.** 14:27:22'de bir kez `sarj harcanmadi`.
- **Bıçak / zeus Min. damage kuralı 16 kez çalıştı.** Yaklaşma başına bir satır.
- **Elmacı'ya karşı ret çok:** 43 atışta 9 `damage rejection` (Haise gibi; onun tarafında).
- `sebep bilinmiyor` 6 kez; çoğu R8'le (dürbün yok) atış anında.

### V1.0.18: yOndery paketi ve XYESOSENSE'ten alınanlar

Gönderdiğin `x.rar` (yOndery-gs pack UPD-6: enderphobia, abyss, wraith, Etterance, Multi-Tools, jumpscout, hit_effect, neverlose hotkeys, grenade helper) ve `XYESOSENSE.lua` incelendi. Elimizde zaten olmayan ve işe yarayan üç şey alındı; hepsi varsayılan açık:

- **Defensive while switching weapons** (Exploits; enderphobia'nın "Weapon switch" tetiği, luasense / XYESOSENSE'in `weaponselect` defensive'i): silah çekilirken zaten ateş edemiyorsun, o sürede DT defensive'i zorlanır. Silah seçildiği tick (`cmd.weaponselect`) ve `m_flNextAttack` ileride olduğu sürece; silah 0.15 sn içinde hazır olacaksa bırakılır (temiz atış). Canlı düşman yokken yok. Sadece "On peek" modunda ve DT açıkken (diğer zorlamalar gibi).
- **Tahminli Avoid backstab + `» Defensive while knife is close`** (Anti-Aim; wraith 16 tick, XYESOSENSE 9 tick tahmini): bıçaklı düşmanın ve senin hızından 6 ve 12 tick (0.1 / 0.19 sn) sonraki yerleriniz de denenir. Koşarak gelen bıçaklı 250 birime girmeden yakalanır ve yüzün ona döner. Duran bıçaklıya eskisi gibi 250 birimde tepki. Bıçaklı yakınken DT defensive'i de zorlanır (bıçak da lag compensation'lı: LC kırılınca eski kaydına vurur). Log yaklaşma başına bir kez: `backstab: isim bicakli, 290 birimde (0.19 sn sonra 243) -> yuz ona, defensive`.
- **Jump scout (no air strafe on standing jump)** (Misc → Movement; jumpscout.lua): scout'la yerinde (yatay hız < 10) zıplarken GameSense'in **Air strafe**'i kapatılır; havada fareyle nişan alırken auto strafe yana kaydırıp isabeti bozmaz. İnince, koşarak zıplarken, başka silahta ve lua kapatılınca senin ayarın geri gelir. Air strafe'i sen kapattıysan dokunulmaz. Önerilen ayarlara girmez.
- `dbg sen ozeti` zorlanan defensive'in ne kadarının bunlardan geldiğini yazar: `defensive zorlanan 120 tick (silah degisirken 37, bicakli yakinken 8)`. `dbg ayarlar` satırında `air strafe true, jump scout true`.

İncelenip alınmayanlar:

| Lua | Neden |
|---|---|
| **enderphobia** | AA builder'ı ve safe head bizimkiyle aynı işi yapıyor (bizimkiler loglarla ayarlandı). Silah değiştirme tetiği alındı. |
| **abyss** | Yükseklik avantajında safe head bizde var (`Safe head: high ground`, kapalı). Defensive süre sınırı bizde var (Smart defensive, sürekli defensive'de 14 tick). Defensive flick (defensive penceresinde yaw sıçraması) bizdeki hidden yaw ile aynı iş. |
| **wraith** | "Extended teleport" isabet riskini tahmin ediyor; bizim havada teleport kendi sonucundan öğreniyor (V1.0.13). Rakibin ateş anını yakalama bizde düşman peek'ine karşı defensive olarak var. `?` ıskası ayrımı bizde var (`correction` / `damage rejection`). Tahminli backstab alındı. |
| **Etterance** | AA builder'ı, animasyon (bacak, moonwalk, lean), fast ladder, watermark, config; yeni bir AA / defensive tekniği yok. |
| **Multi-Tools** | Görsel / ses / auto-buy. "Unsafe charge in air" havada DT şarjını zorluyor; bizdeki Safe recharge'ın tersi (görülürken şarj seni dondurur), alınmadı. |
| **XYESOSENSE** | AA ve defensive tetikleri bizdekilerle aynı yapıda; `weaponselect` defensive'i ve bıçaklı yakınken defensive alındı. |
| hit_effect, neverlose hotkeys, grenade helper | AA / resolver dışı (efekt, tuş listesi, bomba yardımcısı). neverlose hotkeys tek satırlık şifreli kod. |

### V1.0.17: sniper exploit hafızadan yine Hide shots ile başlıyordu

V1.0.15'in kalanı (12:02–12:19, de_mirage) ve V1.0.16'nın ilk oturumundan (12:19–12:24, de_mirage → de_dust2).

Değişen:

- **Kullanılan exploit kendi 8 mermisini görmeden bırakılmıyor.** V1.0.16 yüklenince scout yine Hide shots ile başladı (12:19:34 `HS, DEF yok`, `DT acik 0`). Sebep: V1.0.15'le 12:00:45'ten 12:19'a kadar 17 dk daha Hide shots'ta oynandı, hafızaya HS'de 27 mermide 10 kafa yazıldı; DT 4 mermide 4 kafada kaldı. İki tarafın da 4+ mermisi olduğu için yüklemede oran karşılaştırması HS'yi seçti, DT seçilmediği için 4 mermisi de hiç artmadı. V1.0.16'nın "DT ile başlatır" dediğim durumu sadece HS'de 1-2 mermi varken doğruydu. Artık yüklemede önce DT seçilir; kullanılan exploit kendi en az 8 mermisini görene kadar değişmez, sonra karşılaştırılır. Hafızandaki sayılarla DT 4 mermi daha alır; o 4 mermide de kafa yerse (DT 8/8'e karşı HS 10/27) Hide shots'a geçer, bu sefer DT'nin yeterli verisiyle.
- **Yüklemede sniper durumu yazılıyor:** `sniper exploit (hafiza): Hide shots 10/27, Double tap 4/4 kafa isabeti -> Double tap`. Scout hangi exploit'le başladığı artık logdan görülüyor.
- **Jitter / x-way / random arası geçiş `AA deseni kararsiz` sayılmıyor.** Haise için 9 dk'da 5 kez yazıldı (12:03:58, 12:04:20, 12:07:42, 12:12:13, 12:12:48): desen jitter 50 ile x-way 85 arasında okunuyordu. Üçü de aynı aile (hipotez yok, Force safe point), aralarındaki geçişin hiçbir etkisi yoktu. Statik ↔ jitter gibi gerçek değişimler yine sayılıyor.
- **`sikmadi` satırında LC kıran kayıt yazılıyor.** 12:09:46'da sh için `sebep bilinmiyor` yazdı; düşman havada 3681 hızla ışınlanıyordu (`LC`). Artık `onun kaydi LC kiriyor (isinlaniyor)`.

Logda görülen, kodda değişmeyenler:

- **Haise'ye karşı `damage rejection` çok** (ping 140-160): 22 atışta 7; öteki düşmanlarda ~1. Haise tarafında (ping / kayıt), lua'dan düzeltilemiyor.
- **Bıçak kuralı çalıştı:** 12:09:44 `MD 30` → kafa -37; 12:10:14 yeni bir yaklaşmaydı, aynı yaklaşmada tekrar yazmadı.
- **`2 bos peek` kilidi çıkmadı**: V1.0.15'in AI peek düzeltmesi tutuyor görünüyor.
- **12:22:31 `unknown` isimli düşman**: harita değişiminden hemen önce, isim okunamamış. Etkisi yok.
- Ölümlerin çoğu fake duck'ta ya da HS açıkken; fake duck mermileri sniper istatistiğine sayılmıyor.

### V1.0.16: sniper exploit denenmemiş Hide shots'a erken geçiyordu

V1.0.15'in ilk logundan (11:56–12:02, de_mirage, Haise deagle / scout). Kararsız desen ve `2 bos peek` bu kısa oturumda hiç çıkmadı (Vice Luaaa yoktu, az peek oldu). Bıçak kuralı tetiklenmedi.

Değişen:

- **Sniper exploit (Auto learn) 4 mermide hiç denenmemiş Hide shots'a geçmiyor.** 12:00:45'te `sniper exploit: Hide shots 0/0, Double tap 4/4 kafa isabeti -> Hide shots` oldu. Oturumun kalanında DT kapalı kaldı: `DT acik 25 | defensive zorlanan 0` (12:01:46), sonra `DT acik 0`; 12:02:19'da `HS LC` iken kafa -139. Sebep: hiç denenmemiş exploit'in oranı ön bilgiden 0.5 sayılıyordu (2/4). DT 4 mermide 4 kafa yiyince oranı 6/8 = 0.75 oldu, 0.5'ten 0.1'den fazla kötü göründü ve karşılaştırma tek başına Hide shots'a geçirdi. Keşif kuralı (8+ mermi, %40+ kafa) atlanmış oluyordu. Geri dönmek için de Hide shots'ta en az 10 mermi, hepsi kafa, gerekiyordu. Artık kendi en az 4 mermisi olmayan exploit'e sadece keşifle geçiliyor: kullanılan exploit'te 8+ mermi ve %40+ kafa. Hafızandaki bu oturumun sayılarıyla (DT 4/4, HS'de 1-2 mermi) V1.0.15 sonraki oyunda scout'u yine Hide shots ile başlatırdı, V1.0.16 DT ile başlatır.

Logda görülen, kodda değişmeyenler:

- **DT'de yenen kafaların çoğu DT boşken.** 11:57:42 teleporttan 0.15 sn sonra (teleport şarjı harcıyor, `DT %0`); 11:58:20 kendi atışından 0.04 sn sonra (`sarj bekle`); 11:59:04 havada fake duck tuşu basılıyken. Bunlar DT'nin şarj süresinin bedeli, sniper istatistiğinde DT'ye sayılıyor (doğru: HS'de bu boşluk yok, ama defensive / teleport / air lag da yok).
- **`DT dolu, DEF acik (zorla)` iken kafa** (11:57:01, 12:00:45): düellolar 0.08 ve 0.16 sn sürdü. 11:57:01'de sen 0.06 sn önce gördün ama vurulabilir atış yoktu (`0.00s vurulabilir`); 12:00:45'te Haise 0.09 sn önce gördü. Zorlanan defensive bu kadar hızlı sıkan sniper'ı durdurmuyor.
- **Bu oturumda scout atışlarının 3'ü `damage rejection`** (8 atışta; bütün loglarda ~250 scout atışında 11). Aynı exploit'le 60 sn'de 2 red kuralı tetiklenmedi: 12:00:37 DT ile, 12:01:36 fake duck'ta (exploit yok).
- **11:59:04 `Air crouch | FD, DT %0`**: havada fake duck tuşu basılı. DT V1.0.14'ten beri havada açık kalıyor ama dolu değildi; şarjın neden boş olduğu logdan anlaşılmıyor (yerde fake duck'ta DT kapalı, zıplayınca sıfırdan doluyor olabilir).

### V1.0.15: sniper exploit ölçümü, AI peek boş peek, kararsız desen

V1.0.14 logundan (00:57–02:08). Bıçak kuralı, havada fake duck düzeltmesi, sniper sonrası fake duck bırakma ve haritalık teleport kapatma oyunda çalıştı:

- 01:08:49 `Air crouch | DT %0`: havada fake duck tuşu artık DT'yi kapatmıyor.
- Sniper mermisiyle bırakılan fake duck'ta ikinci mermi atlatıldı ve kill alındı (01:04:54–56).
- Teleport bir haritada son 3'ün 2'sinde vurulunca kendini kapattı.

Değişenler:

- **Sniper exploit (Auto learn) artık gövde isabetlerini de sayıyor.** 01:36:48'de `sniper exploit: Hide shots 19/37, Double tap 23/35 kafa isabeti -> Hide shots` oldu. Oturumun kalanında (~32 dk) scout'ta `DT acik 0`, `defensive zorlanan 0`. Ölçüm sadece kafa isabeti ve ıskayı sayıyordu, gövde isabeti hiç girmiyordu. Logdan sayım (elinde scout / R8, fake duck hariç): **DT'de 16 kafa, 17 gövde, 9 ıska (kafa oranı %38); HS'de 21 kafa, 0 gövde, 15 ıska (%58).** GameSense'te HS ile defensive yok; HS'deyken düşmanın her isabeti kafaya gitti. Artık düşmanın sana attığı her mermi sayılıyor (ıska, gövde, kafa), oran = kafa / hepsi. Hafızadaki eski (gövdesiz) sayılar alınmıyor; sniper yeniden DT ile başlıyor ve sıfırdan öğreniyor.
- **AI peek: ateş edilen peek boş sayılmıyor.** Aimbot'un atışı (`aim_fire`) istemcide hemen geliyor, oyunun `weapon_fire` olayı ise sunucudan geç geliyordu. Lua ikincisini bekliyordu; arada peek `atis olmadi` deyip boş sayılıyordu. Sonuç: isabetli peek'ten sonra bile `2 bos peek` kilidi. 01:20:07'de kafa -157 kill'den hemen sonra, 01:20:34'te `ai peek sonucu` satırından sonra oldu. Artık `aim_fire` görüldüğü an peek "atış yaptı" sayılıyor. Boş sayaç dönüş bitince ve atış olmadıysa artıyor.
- **Bıçak kuralı 30'da kaldı.** V1.0.15'in ilk halinde 60'a çekmiştim, geri aldım (hataydı). İki örnek: 01:12:16'da bacak -37, ardından gövde -93 (can 63 → öldü); 01:18:23'te mide -51, ardından -93 kill. Düşük ilk atış ikinci gövde atışını öldürücü yapıyor (30 + 75 = 100+); 60 ise ilk atışı geciktirirdi. Log artık yaklaşma başına bir kez (01:51:02–27 arası 5 sn'de bir yazıyordu).
- **Kararsız AA deseni.** Vice Luaaa'nın deseni static / jitter / xway / spin arasında saniyede bir değişti. Her değişimde `hipotezler sifirlandi`, hemen ardından `3 resolver iskasi -> body yaw 58° denenecek` (01:32:29–46 ve 01:42'ye kadar). Artık desen 20 sn'de 3 kez değişirse 20 sn hipotez yok (Force safe point kalır) ve tek satır yazılır: `AA deseni kararsiz (20 sn'de 3 degisim): hipotez yok, Force safe point`. Yeni desen 1.5 sn oturmadan hipotez başlamaz.
- **Ölünce etiket.** Fake duck tuşu basılıyken öldüğünde vurulma satırı `Fake duck | DT yok, DEF acik` gösterebiliyordu: ölü oyuncu "yerde" sayılmadığı için fake duck yok sanılıyordu. Artık ölüyken tuş durumu esas alınıyor (`FD, DT yok, DEF yok`). Sadece log / gösterge, oynanışa etkisi yok.

Logda görülen, kodda değişmeyenler:

- **Scout'ta senin Min. damage'in 100.** Logda çok sayıda `sikmadi: hasar 85-93 < MD 100` var. Bu değer lua'dan gelmiyor, SSG 08 grubundaki kendi ayarın. 100 scout'u pratikte sadece kafaya sıktırıyor (zırhlı gövde 75-95), resolver'ın `ogrenildi ... govde yine atilmaz` satırı da bu yüzden. Gövde de istiyorsan SSG 08 Min. damage'ı 80-90 yap. Lua'nın 101 kuralı yine sadece öldüren atışı bekler, senin değerin daha düşükse seninki geçerli.
- **R8'de defensive yok** (bu logda da 783 zorlanan tick'te predict 19, 990'da 9). GameSense revolver'da defensive yapmıyor.
- **Defensive 10 sn durduruldu** (01:33:39): zorlanan defensive sırasında 2 atış `damage rejection` ile gitti, lua defensive'i 10 sn bıraktı. Tasarlandığı gibi.
- **Duvar arkasından vuran sniper'a karşı fake duck bırak / geri al döngüsünde DT dolmuyor.** Her bırakma 1.25-3 sn sürüyor, vuran seni görmeyince fake duck geri geliyor. Bilerek değiştirilmedi: daha uzun bırakmak, basılı tuttuğun fake duck'ı lua'nın senin yerine kapatması olurdu. Böyle bir sniper varken DT istiyorsan tuşu kendin bırak.

### V1.0.14: havada fake duck, sniper sonrası şarj, yakındaki bıçak

V1.0.12 – 1.0.13 logundan:

- **Havada fake duck tuşu artık DT'yi kapatmıyor.** Logda zıplayıp havada fake duck'a basılınca `Air crouch | FD, DT yok` görünüyordu (örneğin V1.0.13'te r8'le havadayken ölüm; V1.0.12'de bir teleporttan 0.1 sn sonra). GameSense'in fake duck'ı sadece yerde çalışır; havada tuşa basmak bir şey kazandırmıyor ama lua DT'yi kapatıyordu. Artık fake duck **yerdeyken** sayılıyor: havada DT / air lag / defensive / hidden açılar / teleport çalışmaya devam eder, yere inince fake duck her zamanki gibi (DT kapalı). Zıplayıp fake duck'la inme alışkanlığın bozulmaz.
- **Sniper'dan yiyip fake duck bırakılınca şarj beklenmiyor.** Logda fake duck bırakıldıktan 1 sn sonra ikinci sniper mermisi geldiğinde DT hâlâ %10'du: Safe recharge, görülürken şarjı bekletiyordu. Artık bu durumda (3 sn) DT hemen dolar; sniper'ın ikinci mermisi en erken 1.25 sn sonra geldiği için şarj ve defensive o mermiden önce hazır olur. Fake duck'ı kendin bıraktığında Safe recharge eskisi gibi.
- **Bıçak / zeus tutan düşman yakınken Min. damage geçici olarak en fazla 30** (Anti-Aim → Protection → *Lower Min. damage vs close knife/zeus*, varsayılan açık). Logda zıplayarak bıçakla gelen düşman 37-78 birimdeyken 1 sn boyunca vurulabilir göründü ama ateş edilmedi (`hasar 87 < MD 100`), üç bıçakla ölüm. Artık bıçaklı / zeus'lu düşman 320 birimden yakınken scout'un 101 kuralı ve senin daha yüksek Min. damage'in geçici olarak 30'a iner. Uzaklaşınca geri gelir. Minimum damage override tuşun basılıysa onun değeri kalır. Log: `isim bicak/zeus ile yakinda: Min. damage gecici 30 (oldurmese de vur)`.

Logda görülen, kodda değişmeyenler:

- **R8 ile defensive açılmıyor.** R8'li roundlarda zorlanan 477 tick'te predict 0 (V1.0.11'de 672'de net_update 8). Diğer silahlarda ~%70. GameSense revolver'da defensive yapmıyor; R8'deyken `DEF yok (zorla)` normal.
- **V1.0.13'te `MD 5`.** Atış satırlarında Min. damage 5 görünüyor. Lua bunu yazmıyor: GameSense'in **Minimum damage override** tuşu açıkken lua onun değerine dokunmaz. Override değeri 5 olunca scout 5-20 hasarlık (duvar arkası, kol) atışlar yapıyor; her atış 1.25 sn sürgü ve DT şarjı demek. Gövde için 60-80 yeterli (zırhlı gövdeye scout ~75-95 vurur).

### V1.0.13: teleport sonucunu öğrenen havada teleport

V1.0.12 logu: defensive gerçekten açılıyor. Zorlanan 704 tick'in 507'sinde (~%72) predict_command defensive'i gördü, logda `DEF acik (zorla)` var. V1.0.11'de de `net_update` sayısı zorlananla neredeyse aynıydı: **defensive o zaman da sunucuda açılıyordu**, sadece lua göremediği için hidden açılar yazılmıyordu.

Logdaki zayıf nokta havada teleport. Teleportların yaklaşık yarısından sonraki 1.5 sn içinde vuruldun (önceki logda 24 teleportun ~10'u), çoğunda DT %0 iken. Teleport şarjı harcıyor, inince ne DT ne de defensive kalıyor.

- Her teleportun **sonucu** tutuluyor: sonraki 1.5 sn içinde düşman mermisi yedin mi. Konsolda `teleport sonucu: 1.5 sn icinde vuruldun (son 3: 2 vurulma)` / `vurulmadin` görünür.
- Bir haritada **son 3 teleportun 2'si** vurulmayla bittiyse, o harita boyunca havada teleport kapanır: `teleport: son 3 isinlanmanin 2'sinde hemen vuruldun, bu harita boyunca havada teleport kapali (sarj air lag / DT icin kalir)`. Şarj havada air lag (defensive) için, inince DT için kalır.
- Yeni haritada (level_init) teleport yeniden açılır ve sayım sıfırdan başlar. Menüdeki `Teleport in air when seen` ayarı aynen kalır; tamamen kapatmak istersen oradan kapat.
- `dbg sen ozeti` satırının sonuna, kapandıysa `(teleport bu harita kapali)` eklenir.

### V1.0.12: defensive algılama düzeltmesi (hidden AA artık uygulanıyor)

Soru: "Deff açık mı? Jitter var ama kafam farklı yerlere gitmiyor."

- **Sebep:** Lua defensive penceresini `setup_command`'da tickbase'e bakarak arıyordu. Gerçek GameSense'te bu ölçüm defensive'i hiç görmedi: V1.0.10 – 1.0.11 loglarında `DEF acik` hiç yok, tek istisna fake duck'ta yanlış bir satır. Hidden pitch / yaw (defensive sırasında kafanın gittiği yer) yalnızca defensive görülünce yazıldığı için **hiç uygulanmadı**. Zorlama (`cmd.force_defensive`) gönderiliyordu (`DEF yok (zorla)`), ama lua onu göremiyordu.
- **Düzeltme:** Referans lua'ların (luasense, hysteria) GameSense yöntemi kullanılıyor. `run_command`'daki komut `predict_command`'da tahmin edilince tickbase, görülen en yüksek değerin 3-14 tick gerisindeyse defensive açık sayılıyor. Eski komutların yeniden tahmini sayılmıyor. Fake duck'ta defensive yok sayılıyor (DT / HS kapalı).
- **Sonuç:** Defensive zorlanıp gerçekten açılınca:
  - logda `DEF acik (zorla)` görünür;
  - yürürken / slow walk'ta / eğilip yürürken / havada hidden açılar yazılır (varsayılan: pitch Up, yaw Random; havada yaw Spin).
  - Dururken, eğilip dururken, Peek'te, manuel yaw'da ve freestanding'de hidden açı **varsayılan kapalı** (Neverlose V1.0 tasarımı: kafayı siperin / freestanding'in arkasından çıkarıyordu). Oralarda kafa yine yerinde kalır, bu normal.
- **`dbg sen ozeti`** artık: `defensive zorlanan X tick, gorulen: setup / predict / net_update, zorlanip gorulen Y`. **Y > 0 ise GameSense defensive'i gerçekten açıyor.** Y hep 0 kalırsa sunucu / GameSense sürümü defensive'e izin vermiyor demektir.

### V1.0.11: ilk detaylı logdan (de_mirage, ~30 round)

Logdan çıkanlar:
- **Atışların:** 54 atışın 40'ı isabet (%74). 14 ıskanın 6'sı düşmanın **sahte kaydına** (defensive). Sahte kayda giden atışların yine de ~%70'i isabet, yani beklemek kazandırmıyor (V1.0.8'deki karar doğru). Kalanlar: 4 gerçek resolver ıskası, 2 damage rejection, 1 spread, 1 prediction error.
- **Ölümler:** 22 ölümün **10'unda fake duck açıktı**. Fake duck'ta DT / defensive yok, hareket yavaş. 3'ünde ilk scout mermisini fake duck'ta yedin, 1-2 sn fake duck'ta kaldın ve ikinci mermiyle öldün. Diğer ölümlerin çoğu aynı anda görülen peek düelloları (rakip 0.03-0.1 sn önce görüyor) ve duvar arkasından vuruşlar (`duvardan (1)`).
- **`DEF acik` logda hiç yok:** zorlanan defensive her satırda `DEF yok (zorla)`. Ya GameSense defensive'i lua'nın ölçtüğü yerde (setup_command tickbase'i) göstermiyor ya da hiç devreye girmiyor. Bunu ayırmak için yeni teşhis satırı eklendi (aşağıda).
- **Scout Min. damage'in 100:** `ayarlar` satırında `MD 100 (SSG 08)`. Aimbot zaten sadece öldürecek yere sıkıyor. "Kafa beklerken öldün → gövde de atılacak" öğrenmesi bu yüzden etkisiz; log artık bunu söylüyor.

Değişenler:
- **Sniper'dan yiyince fake duck bırakılır** (Anti-Aim → Protection → *Release fake duck when hit by sniper*, varsayılan açık). Fake duck'tayken scout / AWP mermisi gelirse fake duck en az 1.25 sn bırakılır; vuran seni görmeye devam ederse en fazla 3 sn. Bu sürede hız, DT ve defensive geri gelir; sniper'ın ikinci mermisi en erken 1.25 sn sonra. Log: `fake duck birakildi: isim sniper ile vurdu ...`. Tüfek / deagle mermisinde bırakılmaz (hızlı ateşte ayağa kalkmak daha kötü).
- **Mermi başka oyuncuya giderse resolver'a sayılmaz:** Logda nişan alınan oyuncu ıskalanmış, mermi arkadakine isabet etmiş (`atis: WWW...` ama detay satırı `KaslıZenci`). Artık `resolver'a sayilmadi: mermi baska oyuncuya gitti (nisan: isim)` yazılıyor; ikisinin de seviyesi ve hipotezi değişmiyor.
- **Detaylı log düzeltmeleri:**
  - Defensive süresine düşmanın dormant kaldığı süre de ekleniyordu (`en uzun 840t` gibi). Artık bölüm son görüldüğü tick'te kapanıyor.
  - 1-4 hasarlık (çok duvar arkası) görüşler "vurulabilir" sayılmıyor.
  - Molotof / el bombası hasarı detay satırı yazmıyor.
  - Fake duck'ta görüş ayakta göz yüksekliğinden ölçülüyor.
- **Yeni `dbg sen ozeti`** (round sonunda): kaç tick defensive zorlandı ve kaçında defensive görüldü, üç ayrı ölçümle (setup_command / run_command / net_update tickbase). Ayrıca kaç teleport oldu ve kaçından sonraki 1.5 sn'de vuruldun. Logda iki ölüm teleporttan ~0.25 sn sonra, DT %0 iken; bu satırla teleport'un işe yarayıp yaramadığı görülecek.

### V1.0.10: detaylı log (oyun loglarından geliştirmek için)

Bu sürümü bir süre oynayıp logları toplu göndermek için. Davranış (AA, exploit, resolver) V1.0.9 ile aynı; sadece daha çok şey loglanıyor ve loglar tek seferde alınabiliyor.

**Logları almak (Home → Console):**
- **Copy all logs:** bütün loglar (önceki oturumlar dahil) panoya; Ctrl+V ile yapıştır. Pano kullanılamazsa (GameSense'te FFI kapalı) loglar konsola basılır.
- **Print all logs to console:** bu oturumun bütün satırları saatleriyle konsola.
- **Dosya:** loglar ayrıca CS:GO klasöründe (`csgo.exe`'nin yanı) **`nykle_log.txt`**'ye yazılır: round başında, harita değişince, en geç 5 dakikada bir ve kapanışta. Önceki oturumların logları dosyada kalır (en fazla ~2 MB eski + bu oturumun 12000 satırı). Dosyayı olduğu gibi gönderebilirsin.
- **Clear saved logs:** hafızadaki ve dosyadaki logları siler (yeni bir test turuna temiz başlamak için).
- Her satırın başında saat (`21:34:05`) var.

**Detailed log (for analysis)** (varsayılan açık) şu `dbg` satırlarını ekler:
- **Konum biçimi:** `@BombsiteA(-512,1024,64) 812u h+64 v134 havada vz+120 duck50 bak+178 lby-35 p89 hp100 ssg08 ping45`. Haritadaki bölge adı ve koordinat, mesafe (birim; 1 m ≈ 52), `h` = yükseklik farkı (+ = düşman üstte), `v` = yatay hız, `bak` = düşmanın yaw'ının sana göre açısı (0 = sana bakıyor, ±180 = arkası dönük; AA'sı hakkında bilgi), `lby` = LBY ile yaw farkı, `p` = pitch, can, silah, ping.
- **Kayıt biçimi:** `DEF geri 6t` = şu an sahte (defensive) kayıtta, 6 tick geride; `def 12t once bitti`; `bogma 3` = paket boğma; `LC`, `FD`; `AA jitter/45`; `seviye 2` = resolver seviyesi.
- `dbg atis-detay:` her atış sonucunun altında: hedefin konumu ve kaydı, oyuncu listesi (`SP` / `BA` / `BY` / `WHITELIST`), aimbot bayrakları (`bt 4t`, `hc 72%`, `teleported`, `extrapolated`, `interpolated`, `high_priority`, `nisan z+62` = ayağının kaç birim üstüne nişan alındı), senin konumun / durumun / exploit'in, sonuç.
- `dbg sikmadi:` düşmanın kafasına ya da gövdesine mermi geçerken 0.4 sn ateş yoksa (görüş başına bir kez): tahmini kafa / gövde hasarı, olası sebepler (`sniper kurali: sadece oldurecek atis`, `hasar 34 < MD 101`, `kafa kapali`, `onun kaydi sahte (DEF)`, `sen havadasin`, `sen hareketlisin v210`, `fake duck`, `silah hazir degil`, `aimbot baska hedefe ates`, `rage kapali`), MD / hit chance, silah durumu (dürbün dahil), onun konumu ve kaydı, sen.
- `dbg duello:` bir düşmanla karşılaşma bitince tek satır: süre, **ilk gören** (`o 0.20s once` / `sen ...` / `sadece o gordu`), onun defensive'i (`def 6 kez 41t (%48)`), en yüksek hızı, havada mı, onun ve senin atış / isabet sayıları, sonuç (`oldun` / `oldurdun` / `ayrildi` / `round bitti`).
- `dbg vurulma-detay:` vurulunca: saldıranın konumu ve kaydı, **son iki atışı arası** (`0.06s (DT)`), senin onu görüp görmediğin ve kaç kez sıktığın, senin durumun.
- `dbg olum-detay:` / `dbg kill-detay:` ölüm / öldürme: silah, `headshot`, `duvardan (1)`, `noscope`, `smoke icinden`, `kor`, konumlar.
- `dbg def ozeti:` round sonunda düşman başına defensive sayısı, toplam / ortalama / en uzun süre, kaçı hareket ederken.
- Başlıklar: `dbg ===== round 7 | de_mirage | sen CT | ping 45ms =====`, `dbg round sonu`, harita değişince `dbg ===== harita ... =====` ve `dbg ayarlar:` (tick, rage hit chance / min damage, DT / HS, fake lag, lua'nın önemli ayarları).

Ayrıca düzeltme: `aim_result`'ta hedef, `baska oyuncuya isabet` karşılaştırmasından **sonra** tanımlanıyordu (V1.0.8 – 1.0.9); karşılaştırma boş değere yapıldığı için hedefin kendi hasarı da "başka oyuncu" sayılabiliyordu. Artık önce okunuyor.

### V1.0.9: defensive + shift ile gelenlere karşı

Oyun logu (V1.0.8, ~10 round): senin atışların 16'da 14 isabet; ıskalayan ikisi de düşmanın **sahte kaydına** gitmiş (`def (sahte kayit)`). Asıl sorun savunmadaydı: scout'ta exploit **Hide shots**'tı (`HS LC`) ve ölümlerin neredeyse hepsinde `DEF yok`. GameSense'te Hide shots ile defensive zorlanamıyor (DT şarjı yok): scout'tayken peek'e karşı defensive, havada air lag ve teleport hiç çalışmıyordu. Düşman defensive + shift ile gelince ilk mermi onun.

- **Scout / AWP / R8 önce Double tap:** "Snipers: Auto (learn)" artık DT ile başlar: peek'e karşı defensive (Defensive vs enemy peeks / Smart), havada air lag ve teleport scout'ta da çalışır. Öğrenme sürer (kafadan vurulma oranı Hide shots'tan 0.1 kötüyse geçer); ayrıca **keşif**: kullanılan exploit'te 8+ mermide kafa oranı %40+ ve öteki hiç denenmemişse öteki denenir (`... -> Hide shots (deneme: oteki hic denenmedi)`). Eskiden denenmemiş exploit'in 0.5'lik ön bilgisi yüzünden pratikte hep Hide shots'ta kalıyordu.
- **Ayna defensive:** Hedef sahte kayıttayken (defensive) temiz atış yok: senin defensive'in de açık kalır, onun mermisi de senin sahte kaydına gider. Gerçek kaydı gelince temiz atış döner (lag kesilir, aimbot gerçek kayda sıkar). Önceden lua "temiz atış" deyip kendi defensive'ini kapatıyordu, aimbot da boşa giden sahte kayda sıkıyordu.
- Logda 5 ölüm **fake duck** sırasında (scout'la shift'le gelen düşmana karşı). Fake duck'ta DT / HS / defensive yok (V1.0.6); scout'çulara karşı fake duck pahalı. İstersen **Fake duck only when standing still**'i aç.

### V1.0.8: oyun loglarından — scout sıkmıyor, damage rejection, zeus

- **Sahte kayıt beklemesi varsayılan kapalı:** Sürekli defensive açan düşmanlara karşı "sıkamıyor" şikâyeti sürdü; faydası oyunda kanıtlanmadı. Artık aimbot defensive'deki düşmana da normal sıkar. İstersen Ragebot'tan açarsın (açıkken de düelloda / peek'te beklemez).
- **Scout'ta "sadece kafa" kuralı öğreniyor:** `atis olmadi, aci kapandi, hasar 72/101` ve ardından ateş etmeden ölüm. Düşman seni görürken scout HP + 1 ile sadece öldürecek yere sıkıyor, gövde açıkken kafayı bekliyordu. Bir düşman seni bu kuralla ateş etmeden beklerken öldürürse bu haritada **ona karşı** kural gevşer (aimbot senin Min. damage'inle gövdeye de sıkar); haritada 2 böyle ölümde **herkese karşı** gevşer. Log: `ogrenildi: isim seni sen kafa beklerken (sniper, ates etmeden) oldurdu -> bu haritada ona karsi govde de atilacak`. Yeni haritada sıfırlanır.
- **Damage rejection ayrımı:** Sunucudaki isabet sayacın artıp hasar gelmediyse önceden hep `damage rejection` yazılıyordu. Artık o sırada senden başka bir oyuncu hasar aldıysa `baska oyuncuya isabet`, almadıysa gerçekten `damage rejection` (sunucu reddetti).
- **Sunucunun reddettiği exploit öğreniliyor:** İki logda da `damage rejection` Hide shots açıkken geldi (`HS LC`). Lua'nın kendi lag'i yokken aynı exploit'le (HS / DT) 60 sn'de 2 damage rejection / unregistered shot olursa sniper'da (Auto) o exploit 5 dk bırakılır, öteki kullanılır: `sunucu Hide shots ile atilan atislari reddediyor (60 sn'de 2 kez ...) -> sniper'da 5 dk Double tap`. Tek olay kanıt sayılmaz.
- **Zeus'a karşı fake duck daha erken bırakılır:** Log: `fake duck birakildi: ... zeus ile 178 birim yakinda` → hemen zeus. Zeus tutan düşmanda 420 birimde bırakılır (bıçakta 260), 520'den uzaklaşınca geri verilir.

### V1.0.7: sahte kayıt beklemesi düelloda yok, AA'ya dokunmuyor

Oyun logu: Serpent1337 / BANANA-GOD / aimlarp neredeyse sürekli defensive açıyordu (`12-13 tick gercek kayit beklendi` her birkaç saniyede). Bekleme 14 tick sınırına hiç takılmadığı için ara vermiyordu: aimbot bu düşmanlara neredeyse hiç ateş etmedi (logda tek `atis:` yok, AI peek iki kez öldürecek noktaya gidip `atis olmadi` ile döndü). Ayrıca beklerken freestanding kapatılıyordu (GameSense'in freestanding'i whitelist'teki oyuncuyu atlar diye önlem): sürekli defensive'de freestanding de sürekli kapalı kaldı, `vuruldun: head -92 | Standing` (Freestanding olmalıydı). Düzeltmeler:

- **AA'ya ve freestanding'e hiç dokunulmaz** (beklerken AA yönü ve freestanding değişmez).
- **Düelloda beklenmez:** düşman kafanı görüyorsa ya da sen peek atıyorsan (Peek durumu, Quick peek / AI peek tuşu basılı) ateş serbest, kayıt seçimi GameSense'in. Bekleme sadece açıyı sen tutarken, düşman seni görmezken: o zaman birkaç tick beklemek bedava.
- **Her beklemeden sonra 32 tick ateş serbest** (gerçek kayıt gelse de sınır dolsa da): sürekli defensive açan düşmana da düzenli sıkılır.

### V1.0.6: fake duck'ta DT / HS kapalı

Oyun logu: `atis: ... iska spread | ... hc 98% | sen ssg08 FD` ve hemen ardından `vuruldun: ... FD, DT %10 (bind)`. Fake duck sırasında DT senin bind'inden açık kalıyor ve şarj olmaya çalışıyordu (auto exploit fake duck'ta exploit'i bind'lere bırakıyordu). DT ile fake duck birlikte çalışmaz: DT açıkken GameSense fake lag'i "Double tap fake lag limit"e çeker, fake duck'ın 14 tick choke'u bozulur; atış sunucuyla farklı eğilme / isabet hesabıyla gider (%98 isabet şansında `spread`), kafa da açıkta kalır. Artık auto exploit açıkken fake duck boyunca **DT ve HS kapalı**; bırakınca durumun exploit'i döner (görülürken Safe recharge DT'yi en fazla 1.2 sn bekletir). Log satırında fake duck'ta `FD, DT yok` görünür.

### V1.0.5: kişiyi tanıyan ve doğrulayan resolver

Resolver artık her düşmanı (Steam ID ile, en fazla 64 kişi, oyunlar arası) tanır ve oynadıkça biriktirir; ama hafızadakini **körü körüne uygulamaz**: canlı gözlem her zaman önce gelir, hafıza her seferinde doğrulanır ya da düzeltilir.

- **Kişi profili:** Düşman göründükçe saniyede bir örnek: AA deseni (jitter / statik / spin / x-way / random), son 1 sn'de defensive, fake duck. 240 örnekte sayılar yarıya iner (eski alışkanlık silinir). Alışkanlık: 10+ örnek ve desen örneklerinin %60'ı aynı.
- **Tanıma:** Hafızadaki düşman ilk görüldüğünde (haritada bir kez) `resolver: isim tanindi (hafiza): genelde statik (dogrulanacak), defensive %40, Standing static duvarli aci 58°`.
- **Doğrulama:** Hafızadaki desen sadece canlı desen henüz ölçülmemişken kullanılır (örn. bilinen jitter'cıya ilk atıştan Prefer: `(veri yok, hafizadan, dogrulanacak)`). Canlı desen ölçülür ölçülmez karşılaştırılır: `hafiza dogrulandi: genelde static, simdi static` ya da `hafiza tutmadi: genelde jitter, simdi static (canli desen kullaniliyor, aliskanlik duzeltildi)` (tutmayınca eski desen sayıları yarıya iner, alışkanlık canlı davranışa çabuk uyar).
- **Kalıcı açılar:** Body yaw açı denemelerinin sonucu (kafa / ıska) kişi + durum + AA deseni + taraf türü başına hafızaya yazılır. O kişiyle tekrar karşılaşınca, Force'a çıktığında (bu haritada bir ıska şart) daha önce **en az 2 kez kafadan vuran** açı varsa 3 ıska beklenmeden hemen o açıyla başlanır: `hafizada kafadan vuran aci (3 kafa), dogrulanacak`. İlk uygun atış sınar: `hafizadaki aci (body yaw 58°) dogrulandi: kafa isabeti` ya da `tutmadi, siradaki denenecek` (skoru hafızada düşer).
- **Taraf bilgisi (daha fazla bilgi):** Açılar tarafa göre öğrenilir ve **aynalanır**:
  - *Duvar (anti-freestand):* gözünden düşmanın kafasının iki yanına iz; tek taraf kapalıysa freestanding AA gerçek kafayı o tarafa saklar. Siperin bir tarafında kafadan vuran açı, düşman öbür tarafa geçince aynalanmış haliyle (+58 ↔ −58) kullanılır. Log: `(duvar L)`.
  - *LBY:* açık alanda duran düşmanda göz yaw'ı ile sunucudan gelen LBY (alt gövde yaw'ı) arasındaki fark 35°+ ise taraf odur (statik desync / LBY breaker / Opposite). Log: `(lby L)`.
- **Bilinen fake duck'çı** tek güncellemede `Fakeduck` sayılır (diğerleri iki güncelleme üst üste); yine canlı kanıt (yarım eğilme + 6+ tick choke) şart.
- **Yeni AA desenleri:** `x-way` (3-way / 5-way: son 8 açıda 3-5 ayrı açı kümesi), `random` (skitter / random jitter), yavaş spin. Jitter, x-way ve random çok taraflıdır: sabit body yaw onların ancak bir kısmını tutar, onlara açı denemesi yapılmaz, Force safe point kullanılır.
- **LC kıran düşmana gövde:** GameSense yerini tahmin ederken DT'li silahta gövde tercih edilir (sahte kayıt ve fake duck'taki gibi).

#### AA türleri ve exploit'ler: lua ne yapıyor

Açıyı her zaman GameSense'in kendi resolver'ı çözer; lua onun üstünde düşman başına safe point / body aim / body yaw / ateş zamanlamasını yönetir.

| AA / exploit | Nasıl anlaşılır | Lua ne yapar |
|---|---|---|
| Statik desync | desen `static` | 2 ıskada (biri bu haritada) Force safe point; Force'ta da 3 ıska ya da hafızada tutan açı varsa body yaw açı denemeleri (+58 / −58 / 0 / ±29), kişi + durum + taraf başına kalıcı |
| Jitter (center / offset), gecikmeli jitter | desen `jitter` (25°+ değişimler sırayla sağa-sola) | İlk atıştan Prefer, 2 ıskada Force safe point; açı denemesi yok |
| Random / skitter jitter | desen `random` | Jitter gibi |
| 3-way / 5-way | desen `x-way` | Jitter gibi |
| Spin (hızlı / yavaş) | desen `spin` | Seviyeler + açı denemeleri (spin tek taraflı desync olabilir) |
| Freestanding desync | duvar tarafı (iz) | Açı denemeleri duvar tarafına göre öğrenilir, öbür tarafa aynalanır |
| LBY breaker / Opposite | LBY farkı (dururken) | Açı denemeleri LBY tarafına göre öğrenilir |
| Az desync (low delta) / desync yok (legit AA) | — | ±29° ve 0° adayları; tutan açı öğrenilir |
| Fake duck | yarım eğilme + 6+ tick choke | Ayrı durum (`Fakeduck`) olarak öğrenilir, DT'li silahta gövde, sniper sadece öldürecekse gövde, bilinen FD'ci hızlı yakalanır |
| Defensive / DT defensive, defensive AA (gizli açılar) | sahte kayıt: simülasyon zamanı geri gider | Açıyı sen tutarken **Wait for real record** (en fazla 14 tick, sonra 32 tick serbest; düelloda ve peek'te yok), ıska resolver'a sayılmaz, DT'li silahta gövde, sniper'da öldürecekse gövde |
| Break LC / teleport | 64+ birim sıçrama, GameSense `teleported` | Iska resolver'a sayılmaz, DT'li silahta gövde |
| Yüksek fake lag (eski kayıt) | GameSense `extrapolated` | Iska resolver'a sayılmaz |
| Hide shots / on-shot kaydı | GameSense `high_priority` | Açı denemesi o atıştan öğrenmez |
| Ani peek | iz (her tick) | Temiz atış: kendi defensive'in atıştan önce kesilir; ateşten sonra 14 tick lag yok |
| Roll AA, fake walk | — | Tespit edilemiyor (roll açısı ağdan gelmiyor); GameSense'e kalır |

### V1.0.4: karşıda defensive / DT / ani peek yapan olunca

- **Sahte kayıtta bekleme (Wait for real record):** Düşman defensive açınca simülasyon zamanı geri gider; sunucu o zamanı düşmanın **eski** konumuyla eşleştirir, o kayda giden mermi (DT'nin iki mermisi dahil) boşa gider. Lua bunu zaten görüyordu (atış satırında `def (sahte kayit)`), ama aimbot yine ateş ediyordu. Artık kayıt sahteyken o düşman oyuncu listesinde kısa süre **Add to whitelist** yapılır: aimbot gerçek kayıt gelene kadar ona ateş etmez, DT şarjı gerçek kayda kalır. Bir pencerede en fazla 14 tick (GameSense'in defensive kayması kadar), sonra 16 tick beklenmez: sürekli defensive açan düşmana da ateş edilir. Kendi whitelist'ine dokunulmaz; kapatınca / unload'da / harita değişince geri verilir. Göstergede `WAIT REAL`; konsolda `resolver: isim sahte kayitta (defensive): 9 tick gercek kayit beklendi, gercek kayit geldi` (ya da `sinir doldu, ates serbest`). GameSense sürümünde alan adı farklıysa konsola bir kez `oyuncu listesinde bulunamadi: Add to whitelist` yazar ve bu özellik kapanır.
- ~~Beklerken AA: AA beklenen düşmana döner, freestanding yok.~~ V1.0.7'de kaldırıldı (sürekli defensive açan düşmanda freestanding sürekli kapalı kalıyordu).
- **Temiz atış ani peek'te:** Biri seni görürken (ya da birazdan görecekken) iz her tick atılır (önceden 2 tick'te bir). Kafa / göğüs / mide / üst göğüs / kalça / uyluklara bakılır (önceden kafa / göğüs / mide; aimbot'un vurabildiği bacak / kalça atışında defensive zorlanıyordu). Hareket ediyorsan 0.1 sn sonraki gözden de bakılır: kendi defensive'in atıştan önce kesilir, atış anına denk gelmez.
- **Ateşten sonra 14 tick temiz:** Aimbot ateş edince (`aim_fire`) o hedefe 14 tick kendi lag'in (zorlanan defensive, Break LC, teleport) yok: DT'nin ikinci mermisi ve hemen arkasındaki atış lag'e denk gelmez.
- Fake duck yapan düşmana karşı: ayrı durum (`Fakeduck`) olarak öğrenilir, DT'li silahta gövde tercih edilir, sniper sadece öldürecekse gövdeye (değişmedi). Fake duck'ta kaçan mermilerin nedenini görmek için atış satırındaki `Fakeduck` ve `iska` nedenlerine bak.

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
| Detailed log (for analysis) (Console) | Açık | V1.0.10: konum, kayıt, düello, "sıkmadı" sebebi (`dbg` satırları, bkz. V1.0.10). |
| Copy all logs / Print all logs to console / Clear saved logs (Console) | — | Bütün loglar panoya / konsola; dosya `nykle_log.txt` (CS:GO klasörü). |

### Anti-Aim
| Ayar | Varsayılan | Not |
|---|---|---|
| Pitch | Down | `Down`, `Minimal`, `Off` (GameSense'te fake pitch yok). |
| Yaw base | At Target | Ateş ettiğin / seni gören / sana ateş eden düşmana döner (Neverlose V1.0 kuralları). |
| Manual left / right / forward | Tuş | Basınca o yön, aynı tuşa tekrar basınca kapanır. Tuşlar `On hotkey` modunda tutulur. |
| Static inverter | Tuş | Body yaw `Static` olan durumlarda tarafı çevirir (toggle / hold modunu sen seç). |
| Avoid backstab | Açık | Bıçaklı düşman 250 birimden yakın ve görünürse ona döner. V1.0.18: 0.1 / 0.19 sn sonraki yerler de denenir (koşarak gelen bıçaklı erken yakalanır). |
| » Defensive while knife is close | Açık | V1.0.18: bıçaklıya dönülürken DT defensive'i de zorlanır. |
| Legit AA on use | Açık | E'de AA devam eder (bomba / rehine yanında karışmaz). |
| Spin when idle | Açık | Warmup kapalı, canlı düşman yokken; pitch Off, hız 6. |
| Freestanding | Tuş | + `FS: disable in air` (açık), `crouching / slow walking / moving` (kapalı), `auto when standing still` (açık). |
| Safe head | Açık | Bıçak / zeus ile havada eğilirken; `any air crouch` ve `high ground` kapalı. |
| Anti-bruteforce | Açık | 5 faz, kendi kendine öğrenme, düşman başına hafıza; `reset after` 6 sn. |
| Release fake duck near knife | Açık | |
| Release fake duck when hit by sniper | Açık | V1.0.11: fake duck'ta scout / AWP mermisi yiyince en az 1.25, vuran seni gördükçe en fazla 3 sn fake duck bırakılır (DT / defensive / hız geri gelir). V1.0.14: bu sürede Safe recharge beklemez, DT hemen dolar. |
| Lower Min. damage vs close knife/zeus | Açık | V1.0.14: bıçak / zeus tutan düşman 320 birimden yakınken Min. damage geçici olarak en fazla 30'a düşürülür (log yaklaşma başına bir kez). Override tuşun basılıysa dokunulmaz. |
| Fake duck only when standing still | Kapalı | |

### Exploits
| Ayar | Varsayılan | Not |
|---|---|---|
| Auto exploit | Açık | Durumun DT / HS seçimini uygular (DT tuşu `Always on` yapılır, kapatınca geri). |
| Snipers (SSG08/AWP/R8) | Auto (learn) | V1.0.9'dan beri önce **Double tap** (GameSense'te Hide shots ile defensive zorlanamıyor), sonra kafadan vurulma oranına göre öğrenir (V1.0.15'ten beri ıska, gövde ve kafa, düşmanın her mermisi sayılır). Denenmemiş exploit'e sadece keşifle geçer: kullanılan exploit'te 8+ mermi ve %40+ kafa (V1.0.16'dan beri ön bilgiyle karşılaştırıp 4 mermide geçmez). V1.0.17'den beri yüklemede önce DT seçilir ve kullanılan exploit kendi 8 mermisini görmeden değişmez. Sunucu bir exploit'i reddediyorsa (V1.0.19: son 4 atışın 3'ü, en az 2 düşmanda) sniper'da 5 dk öteki kullanılır. |
| Safe recharge | Açık | GameSense'te DT geçici kapatılarak (yukarıya bak). |
| Hidden spin speed | 10 | |
| Auto peek | Açık | |
| AI peek (hold Quick peek assist) | Açık | Quick peek assist tuşunu basılı tut, hareket tuşlarına basma. Duvar kontrolü GameSense'te hull izi olmadığı için diz ve göz hizasında, gövdenin iki yanında çizgilerle. |
| Defensive during AI peek | Açık | |
| Defensive vs enemy peeks | Açık | |
| Teleport in air when seen | Açık | Sadece DT ile. Son 3 teleportun 2'si hemen vurulmayla bittiyse o harita boyunca kendiliğinden kapanır (V1.0.13). |
| Air lag (defensive every tick) | Açık | |
| Clean shot (no lag while shooting) | Açık | |
| Defensive while switching weapons | Açık | V1.0.18: silah çekilirken (ateş edemiyorken) DT defensive'i zorlanır; silah hazır olmadan 0.15 sn önce bırakılır. Canlı düşman yokken yok. |
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
| Head unless body kills (snipers) | Açık | Min. damage HP + 1 (GameSense'te 101), elindeki silahın grubunda. Kafa beklerken öldürülünce o düşmana (haritada 2 ölümde herkese) karşı gevşer. V1.0.19: Min. damage'ın 70'ten yüksekse gevşeyince seni görürken geçici 70. |
| Snipers: lethal body on fake records | Açık | |
| Wait for real record (enemy defensive) | **Kapalı** (V1.0.8) | Açıyı sen tutarken (düşman seni görmüyor, sen peek atmıyorsun) düşmanın kaydı sahteyse aimbot gerçek kayıt gelene kadar o düşmana ateş etmez (en fazla 14 tick, her beklemeden sonra 32 tick serbest). Düelloda beklenmez. Aşağıda V1.0.4 ve V1.0.7. |

### Visuals
Crosshair indicators (+ renk), Manual arrows (+ renk), Stats panel (kapalı), Resolver panel (açık; Size 100, Position X 12, Y 330 — menü açıkken sürükle / sağ alttan büyüt). Göstergeler GameSense'in küçük piksel fontuyla (`-`).

### Misc: Clan tag
NYKLE Yaw'daki animasyonlu clan tag: **Clan tag: Nykle.win (animated)**, varsayılan **açık**. Önce `Nykle.win` 1.2 sn görünür, sonra harf harf yazılır (`N`, `Ny`, `Nyk` ... `Nykle.win`, her kare 0.45 sn) ve döner. NYKLE Yaw gibi paket gönderilen tick'te (`run_command`, chokedcommands 0) ve iki tick'te bir `paint`'te güncellenir.

- Açıkken GameSense'in kendi **Clan tag spammer**'ı (MISC → Miscellaneous) kapatılır; clan tag'i kapatınca, Enable kapatınca, config kaydederken ve unload'da senin değerine geri döner.
- Kapatınca eski etiket geri yazılır: `gamesense/steamworks` kütüphanesi yüklüyse (NYKLE Yaw'ın kullandığı) Steam grubunun etiketi okunur, yoksa etiket boşaltılır. Kütüphane şart değil.
- Önerilen ayarlara girmez: kapatırsan kapalı kalır.

### Misc: Movement
**Jump scout (no air strafe on standing jump)**, varsayılan açık (V1.0.18, jumpscout.lua): scout'la yerinde zıplarken GameSense'in Air strafe'i kapalı, inince geri. Önerilen ayarlara girmez.

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
- V1.0.10: bütün satırlar saatiyle hafızada ve `nykle_log.txt`'de; `dbg` satırları için bkz. V1.0.10.

## Testler

`tests/gamesense/` altında GameSense API'sini taklit eden sahte bir ortam (`mock_gs.lua`) ve senaryolar (`run_tests.lua`) var:

```
luajit tests/gamesense/run_tests.lua Nykle_win_gamesense.lua
luajit tests/gamesense/run_memory_tests.lua Nykle_win_gamesense.lua
luajit tests/gamesense/run_sniper_tests.lua Nykle_win_gamesense.lua
luajit tests/gamesense/run_feature_tests.lua Nykle_win_gamesense.lua
```

Test edilenler: yükleme; V1.0.20 (`run_feature_tests.lua`: yerde faz 0 iki kafa yiyince denenmemiş faz 1'e geçişin `faz 0 cok kafa yiyor (2/2 kafa isabeti) -> ... denenmemis faz 1` diye yazılması, `0/0 kafa isabeti` yazılmaması, tek kafada faz değişmemesi; `run_tests.lua`: arka arkaya iki round_start'ta başlığın bir kez yazılması, kazanansız round sonunun `kazanan yok` demesi); V1.0.19 (`run_tests.lua`: aynı düşmana iki retle ve araya isabet giren retlerle exploit'in değişmemesi, son 4 atışın 3'ü 2 düşmanda reddedilince Hide shots'ın bırakılması; Min. damage 100 iken kafa kuralı gevşeyince seni görürken 70 yazılması, öğrenme logunun bunu yazması ve yeni haritada 101'e dönmesi; pano yokken sebebin yazılması ve 10 sn içinde logların ikinci kez konsola yazılmaması); V1.0.18 (`run_feature_tests.lua`: silah çekilirken ve `weaponselect` tick'inde defensive'in zorlanması, silah hazır olmadan bırakılması, ayar kapalıyken ve düşman yokken zorlanmaması, `sen ozeti` sayacı; duran bıçaklıya 290 birimde tepki olmaması, 250 hızla koşan bıçaklının 290 birimde tahminle yakalanıp yüzün ona dönmesi ve defensive, logun bir kez yazılması, alt ayar kapalıyken sadece dönülmesi, uzaklaşınca bırakılması; scout'la yerinde zıplarken Air strafe'in kapanması, havada kapalı kalıp inince geri gelmesi, koşarak / tüfekle zıplarken dokunulmaması, senin kapattığın Air strafe'in açılmaması, havadayken lua kapatılınca geri verilmesi); V1.0.17 (`run_sniper_tests.lua`: hafızada HS 10/27, DT 4/4 iken yüklemede `sniper exploit (hafiza)` satırı ve scout'un DT ile başlaması, DT 7 mermideyken geçilmemesi, 8. mermide karşılaştırılıp Hide shots'a geçilmesi; `run_tests.lua`: jitter ↔ x-way geçişinin `AA deseni kararsiz` sayılmaması, ışınlanan düşmanda `sikmadi` satırının `onun kaydi LC kiriyor` demesi); V1.0.16 (scout'ta DT'de 4 kafa yiyince hiç denenmemiş Hide shots'a geçilmemesi ve DT'nin açık kalması, 8 mermide %40+ kafada keşifle Hide shots'a geçilmesi); V1.0.15 (AI peek'te aimbot ateş edince — `weapon_fire` peek bittikten sonra gelse de — peek'in boş sayılmaması ve `2 bos peek` kilidi olmaması, gerçekten boş iki peek'te kilidin yine gelmesi; sniper istatistiğinde gövde isabetinin sayılması ve hafızaya `v = 2` ile yazılması, eski (gövdesiz) hafıza verisinin alınmayıp scout'un DT ile başlaması; desen oturmadan (1.5 sn) hipotez başlamaması, 20 sn'de 3. değişimde `AA deseni kararsiz` ve kararsızken hipotez / tekrar log olmaması; bıçaklı düşman yakınken scout Min. damage'ının 30 olması ve yakında kalınca logun tekrarlanmaması; fake duck tuşu basılıyken ölünce vurulma satırının `FD` ve `DEF yok` demesi); V1.0.14 (havada fake duck tuşunda DT'nin açık kalması ve yere inince kapanması, sniper mermisiyle bırakılan fake duck'ta DT'nin beklemeden açılması ve tuşu kendin bırakınca görülürken Safe recharge'ın beklemesi, bıçaklı düşman yakınken scout Min. damage'ının düşmesi, logu, uzaklaşınca 101'e ve silah değişince senin değerine dönmesi); V1.0.13 (vurulan / vurulmayan teleport sonucunun yazılması, 1 vurulmada açık kalması, 2 vurulmada o harita boyunca kapanması ve kapandıktan sonra teleport olmaması, yeni haritada yeniden açılması); V1.0.12 (setup_command'daki tickbase normalken predict_command'da 8 tick geride tickbase ile `DEF acik` ve havada air lag zorlarken hidden pitch Up yazılması, defensive yokken hidden açı olmaması, fake duck'ta `DEF acik` olmaması; sahte ortam artık GameSense sırasıyla setup_command → run_command → predict_command gönderiyor); V1.0.11 (fake duck'ta sniper mermisiyle fake duck'ın bırakılması ve tüfek mermisinde bırakılmaması, vuran görürken erken geri gelmemesi ve görmeyince geri verilmesi, başka oyuncuya giden mermide ayrım ve resolver'a yazılmaması, dormant sürenin defensive sayılmaması, ateş hasarında detay satırı olmaması, `sen ozeti`); V1.0.10 (görüp sıkmadı satırı, atış detayında konum / aimbot bayrakları / sonuç, vurulmada son iki atış arası (DT) ve görüş, kill detayı, düello özeti (ateş / isabet / hasar / sonuç), round başlığı, log dosyasında eski oturumun korunması ve saat, Print all logs, pano yokken Copy all logs'un konsola yazması, Detailed log kapalıyken `dbg` satırı olmaması, Clear saved logs); V1.0.9 (scout'ta Auto (learn)'ün DT ile başlaması, DT'de kafa yiyince Hide shots'a geçiş, hafızadaki istatistikle keşif, hedef sahte kayıttayken kendi defensive'in zorlanması); V1.0.8 (bekleme varsayılan kapalı ve kapalıyken whitelist yok, başka oyuncuya giden isabetin damage rejection sanılmaması, HS ile 2 reddin öğrenilip sniper'ın HS'den çıkması ve tek reddin yetmemesi, kafa beklerken ölümün öğrenilip o düşmana karşı Min. damage'ın gevşemesi ve yeni haritada geri gelmesi, zeus'ta 400 birimde fake duck bırakma); V1.0.7 (beklerken freestanding'in değişmemesi, düşman kafanı görürken ve Quick peek tuşu basılıyken beklememe, sürekli defensive'de 14 tick bekleyip 32 tick serbest); V1.0.6 (fake duck boyunca DT / HS kapalı — senin DT bind'in açık olsa da —, bırakınca DT'nin dönmesi); V1.0.5 (`run_memory_tests.lua`: hafızadaki iki düşmanın tanınması, doğru alışkanlığın doğrulanması, yanlışın düzeltilip hafızada yarıya inmesi, canlı desen yokken hafızadaki jitter alışkanlığının kullanılması, hafızadaki açıyla hemen başlama, duvar L / R aynalama, hafızadaki açının doğrulanması ve tutmaması, LBY tarafı, kapanışta açı sonuçlarının yazılması; `run_tests.lua`: x-way / random / yavaş spin desenleri, profil ve açıların hafızaya yazılması); V1.0.4 (sahte kayıtta whitelist ile bekleme, gerçek kayıt gelince bırakma, sürekli defensive'de 14 tick sınırı ve 16 tick serbest, kendi whitelist'ine dokunmama, beklerken AA'nın beklenen düşmana dönmesi, aimbot ateş edince 14 tick zorlanan defensive olmaması, kapanışta whitelist'in geri verilmesi); resolver V1.0.3 (teleport / extrapolation ıskasının sayılmaması, jitter'lı düşmanda hipotez olmaması ve Force safe point, yeni haritada eski ıskalarla Force açılmaması ve bu haritadaki ıskayla açılması, statik düşmanda hipotez başlaması, Correction kapalıyken adayın öğrenmemesi, desen değişince hipotezlerin sıfırlanması, spin'in jitter sayılmaması, Slow walk / Moving ayrımı); menünün AA → Anti-aimbot angles kutusunda olması ve GameSense AA ayarlarının lua açıkken gizlenip kapalıyken / kapanışta geri görünmesi; clan tag animasyonu (sıra ve süreler), GameSense spammer'ının kapatılıp geri verilmesi, kapatınca etiketin geri yazılması; trash talk ve clan tag'in varsayılan açık olması; durumlar (durma, yürüme, hava, eğilme, slow walk, fake duck, manuel, legit AA, merdiven, spin); AA'nın GameSense ayarlarına yazılması; auto exploit; DT şarj tahmini; görülürken Smart defensive zorlaması; temiz atışta zorlama olmaması; havada teleport (`discharge_pending`); aimbot olayları (`?` → correction, damage rejection, spread, isabet); seviye 1-2-3 (oyuncu listesi Force safe point ve body yaw hipotezleri); anti-brute (kafanın yanından geçen mermi, vurulma); sniper Min. damage'ın sadece kendi silah grubuna yazılıp silah değişince geri verilmesi; bıçaklı düşman yakınken fake duck bırakma ve geri verme; AI peek sırasında Quick peek kutusunun geri verilmesi; round / ölüm / harita olayları; resolver panelinin sürüklenmesi; stats paneli; trash talk (kapalıyken yazmama, öldürünce / ölünce, takım chati, sadece headshot, takım arkadaşında yazmama, tehlikeli karakter temizliği); 1500 tick rastgele durum / olay / menü değişikliği (fuzz); **config kaydederken ve kapanışta bütün GameSense ayarlarının (her silah grubu dahil) ve oyuncu listesinin geri verilmesi**; hafızanın yazılması; hiçbir olay fonksiyonunun hata vermemesi. Derleme LuaJIT 2.1 ile (GameSense'in Lua'sı); tanımsız global kullanımı yok.

**Oyunda test edilmedi.** Sahte ortam GameSense'in davranışını tahmin eder; aşağıdakiler gerçek oyunda doğrulanmalı.

## Bilinen sınırlar ve kontrol edilecekler

- **Desync miktarı ölçeği:** Body yaw değeri ≈ 2 × desync varsayımı luasense'ten. Tam desync (58+) her durumda 180 yazıldığı için doğru; sadece düşük limitlerde (safe head 30, fake duck 48-58) gerçek miktar farklı olabilir.
- **DT şarj tahmini** tickbase'den; ping çok oynarsa göstergede DT kısa süre turuncu / beyaz yanlış görünebilir. `DT` göstergesi ve `vuruldun` satırındaki `DT %` buna göre.
- **Oyuncu listesi alan adları** (`Override safe point`, `Override prefer body aim`, `Force body yaw`, `Correction active`): GameSense sürümünde farklıysa konsola bir kez `oyuncu listesinde bulunamadi` yazar ve o özellik (safe point Force / smart body aim / hipotez) kapanır, gerisi çalışır.
- **Weapon type seçici:** Menüde başka bir silah grubunu incelerken o tick sniper Min. damage'ı yazılmaz (yanlış gruba yazmamak için). GameSense sürümünde seçici yoksa ayar tek gruba yazılır.
- **Safe recharge** DT'yi kısa süre kapattığı için o sırada GameSense'in normal fake lag'i devrede olabilir.
- **Teleport** GameSense sürümünde `discharge_pending` çalışmıyorsa konsola bir kez `teleport: sarj harcanmadi` yazar.
- Neverlose ile GameSense arasında hafıza taşınmaz (ayrı anahtar).
- **Log dosyası / pano (V1.0.10):** `nykle_log.txt` GameSense'in `writefile`'ıyla yazılır; GameSense sürümünde yoksa dosya oluşmaz, **Copy all logs** / **Print all logs to console** yine çalışır. Pano, CS:GO'nun `VGUI_System010` arayüzüyle (GameSense'in clipboard kütüphanesiyle aynı yol). `dbg` satırları konsolu kalabalıklaştırırsa **Detailed log**'u kapatabilirsin (normal loglar kalır).
