# Nykle.win V1.0.0 — primordial edition

primordial (CS:GO) için HvH anti-aim, exploit ve resolver lua'sı. GameSense sürümünün (`Nykle.win.gamesense.lua` V1.0.79) loglarla kanıtlanmış özelliklerinin ve Neverlose sürümünün (`Nykle.win.lua` V1.1.x) kurallarının primordial API'sine taşınmış hali. Sadece HvH sunucuları için.

**Kurar kurmaz çalışır.** Bütün iyi özellikler açık ve en iyi bilinen değerlerle gelir. **Always use recommended settings** açık kaldıkça (varsayılan açık) ayarlar saniyede bir önerilen değerlerine döner; ayarlara dokunman gerekmez.

## Kurulum

1. `Nykle.win.lua` dosyasını `<CS:GO klasörü>/primordial/scripts/` içine **bu adla** koy (ad değişirse config'teki kayıtlı ayarlar okunmaz: primordial script ayarlarını dosya adı `Nykle.win` ve grup / öğe adlarıyla saklar).
2. primordial menüsünde Scripts sekmesinden `Nykle.win`'i yükle.
3. İstersen `Nykle.win.cfg`'yi `<CS:GO klasörü>/primordial/configs/` içine koyup primordial'dan yükle. **Dikkat:** config yüklemek **bütün profilini** değiştirir (native AA ve ragebot'un yanında görseller, skinler ve bütün tuşlar da config'tekilerle değişir). `Nykle.win.cfg.json` sadece okumak içindir (düz JSON, primordial yükleyemez): configs klasörüne **koyma**. Config'teki tuşlar:
   - DT her zaman açık (tuşsuz); Hideshots tuşsuz.
   - **MOUSE5** (basılı) = autopeek + auto direction; **MOUSE4** (basılı) = fake duck; **LSHIFT** (basılı) = slow walk.
   - **Ok tuşları** sol / sağ / aşağı = manuel AA (toggle). CS:GO'da bu tuşlar varsayılan `+left` / `+right` / `+back`'tir: konsolda `unbind leftarrow; unbind rightarrow; unbind downarrow` yaz, yoksa her basışta bakışın döner / geri yürürsün.
   - **Caps Lock** (basılı tut) = native Min. damage override (her silahta: Scout 7, AWP 8, Auto 4, Deagle 6, R8 7, tabancalar 10, diğer 4). Bırakınca kapanır.
   - MOUSE3 = thirdperson (toggle), Insert = menü. Native Nade Helper kapalı.
   Config yüklemesen de script native AA taşıyıcılarını kendisi nötrde tutar.
4. Başka AA / resolver / ideal-tick / recharge script'i (metasett, IDEAL-TICK vb.) yanında yükleme: recharge, fakelag ve resolver'ın tek sahibi bu script.
5. Konsolda `[Nykle.win] V1.0.0 (primordial edition) yuklendi (hafiza: N oyuncu)` satırını görürsen hazır.

**Log dosyası:** `nykle_log.txt` ve hafıza dosyası `nykle_memory.txt`, oyunun `Counter-Strike Global Offensive/csgo/` klasörüne yazılır (yoksa oyunun kök klasörüne bak). Analiz için `nykle_log.txt`'yi gönder. Dosya yazılamazsa (ffi kapalı vb.) loglar hafızada kalır: **Console → Print all logs to console** ile konsola yazdır.

## Menü

Menü Scripts sekmesinde "Nykle.win | ..." gruplarıdır. **Home → Tab** ile sekme seçilir; her sekmede yalnız o sekmenin grupları görünür.

| Sekme | Gruplar | İçerik |
|---|---|---|
| Home | Home, Console | Enable, Always use recommended settings, log seçenekleri ve düğmeleri (kopyala / konsola yaz / dosyaya kaydet / temizle / düşmanları unut / istatistik sıfırla) |
| Anti-Aim | Anti-Aim, Protection | Pitch, yaw base, avoid backstab, legit AA (E), spin; freestanding durum ayarları, safe head, anti-bruteforce, bıçak / zeus Min. damage, eğik yürüme desync koruyucu |
| Builder | Builder, Builder exploit | 13 durumun AA'sı (`[Durum] ...` öğeleri; **State** ile durum seçilir) ve durum başına defensive / gizli açılar |
| Exploits | Exploits, Peek | Safe recharge, Smart defensive, re-arm cooldown, anti-peek, temiz atış, havada teleport, Air LC, air lag, havada hit chance; auto peek durumu, AI peek, AFK, otomatik AFK |
| Ragebot | Ragebot | Adaptif resolver, düşük can safe point, akıllı gövde, sniper kuralları, gerçek / taze kayıt bekleme, extended ve kafa saklayana gövde |
| Visuals | Visuals | Nişangah göstergeleri, manuel oklar, sol liste, resolver paneli, istatistik paneli |
| Misc | Misc | Clan tag, trash talk, jump scout, otomatik bomba, sol el, aspect ratio, FPS boost |

Tuşlar native primordial tuşlarıdır (script tuş atayamaz / değiştiremez): manuel (sol / arka / sağ), **Auto Direction** (freestanding), **Autopeek** (Peek durumu ve AI peek), **Fake duck**, **Invert desync** (Static body yaw'da taraf). Kendi **Min. damage override** tuşun açıkken (config'te Caps Lock, basılı tut) scriptin hiçbir Min. damage kuralı çalışmaz (senin kaçış tuşun). Tuş okunamazsa 10 sn'de bir yeniden aranır.

## Özellikler

Varsayılan: "açık" = kutu varsayılan işaretli. "İzlenen" = Always use recommended settings bu öğeyi önerilen değerine döndürür.

| Özellik | Ne yapar | Varsayılan | Kaynak / kanıt |
|---|---|---|---|
| Durumlar (13) | Global, Standing, Moving, Slow walk, Crouching, Crouch move, Peek, Air, Air crouch, Fake duck, Manual, Freestanding, Safe head. Önce hareket durumu (Air > Fake duck > Peek > eğik > yürüme > durma; hareket 10 / 5 birim/sn, eğilme 0.7 / 0.5 histerezisi, inişten sonra 3 tick hava), sonra Manual > Safe head > Freestanding (sadece kafa gizliyken) | — | GS `detect_movement` + `tick_aa` |
| Builder | Durum başına yaw sol / sağ veya X-Way (3-5), yaw randomize, modifier (Center / Offset / Random / Spin / 3-Way / 5-Way), body yaw (Jitter / Static / Random / Off), body freestanding, jitter gecikmesi + randomize, limit randomize, sol / sağ limit. Override kapalı hareket durumu Global'i kullanır | GS `DEFAULTS` (log doğrulamalı) | GS V1.0.x |
| AA uygulama | Her tick `ctx:set_yaw` (hedefe göre mutlak yaw), `set_desync(±limit/60)`, `set_pitch`; jitter yalnız gönderilen pakette (komut başına bir kez) çevrilir | açık | primordial API |
| Roll yasağı | Her tick `set_body_lean(0)`; native Body Lean / Moving Body Lean / Extended Angles "Enable While Moving" nötrde tutulur. Native Extended Angles tuşu açıksa `UYARI: Extended Angles acik (roll yasak) -> kapat` ve solda `ROLL!` | her zaman | kullanıcı kuralı |
| Native AA nötr | Jitter mode None, rotate kapalı, yaw add 0, side#stand Left, miktarlar 100, override stand#move / slow walk kapalı, native anti bruteforce kapalı, on shot Off. Kapatınca / script kaldırılınca senin değerlerin geri gelir | açık | BRIEF §3.2 |
| AA hedefi | Düello (son 1 sn'de ateş ettiğin ve seni gören) > son 1 sn'de kafana ateş eden > seni gören > nişangaha en yakın | — | GS `face_target` |
| Manuel | Native manuel tuşları: sol −90, arka 0, sağ +90 | — | — |
| Freestanding | Native Auto Direction tuşu; kafa açıktaysa (biri şu an görüyorsa) normal durum AA'sı. Durum başına kapatma (havada varsayılan) native "States" öğesiyle; **FS: auto when standing still**: dururken tehdidin gözünden kafanın ±20 birim yanına düz iz (`trace.line`), tek taraf kapalıysa kafa o tarafa; iki taraf da açık / kapalıysa taraf yok (eski taraf kullanılmaz) | havada kapalı, auto açık | GS |
| Safe head | Bıçak / zeus ile havada eğik (açık), her havada eğik (kapalı), yüksek zemin 35+ birim (kapalı): pitch 89, limit 30 | açık / kapalı / kapalı | GS, README |
| Anti-bruteforce | Kafanın 40 birim yakınından geçen düşman mermisi o düşmanın fazını ilerletir (0.1 sn tekrar koruması, 6 sn sonra sıfırlanır). Fazlar 1-8 (ters, ±15, ölçek, rastgele, body freestanding, 0.55, ters+0.7+10, asimetrik). Hareket grubu başına öğrenme `(kafa + 2.4) / (mermi + 8)`, kötü bilinen faz (≥ 12 mermi, ≥ %55 kafa) atlanır, kafadan vurulunca düşmanın tabanı kalıcı değişir, sıra rastgele | açık, 6 sn, rastgele | GS V1.0.23/27/36/45/52 |
| Desync işareti ölçümü | Dururken `get_real_angle` / `get_fake_angle` ile + işaretin hangi taraf olduğu ölçülür (sadece aynı tarafta kalan paketlerde); tutarsızsa `set_invert_desync` de kullanılır | otomatik | — |
| Avoid backstab | 250 birimde göz göze bıçaklıya yüzünü döner; Defensive while knife is close | açık / açık | GS |
| Legit AA (E) | E basılı ve 100 birimde bomba / rehine yokken bakış açısı, desync kalır | açık | GS |
| Spin | Düşman kalmayınca (açık) / ısınmada (kapalı) dönme | açık | GS |
| Desync keeper | Eğikken (≥ 0.9) görülürken tehdide doğru yürüme komutu "Crouch speed" (38) / 0.34'e kısılır; geri çekilme / ateşten 0.6 sn sonrası / peek'te yok | açık, 38 | GS V1.0.58 |
| Defensive | Durum başına Off / On peek / Smart / Always on / Tick based. Smart: ragebot hedef tarıyorken + görülürken / 1800 birimde düşman varken + görüş kesilince 8 tick. Sadece DT doluyken, tick başına bir tetik. Re-arm cooldown: defensive bitince görülürken 1 sn yeniden yok (ilk görüş, hava, AI peek, silah değişimi, bıçak, AFK hariç). Anti-peek: yeni gören / hızlı düşmanda 8 tick | GS `EXPLOIT_DEFAULTS` | GS V1.0.23/43/45 |
| Gizli açılar | Sadece kendi defensive tick'lerinde (simülasyon zamanı geri gidince) durum başına pitch / yaw (Up, Spin, Random ...) | yürürken / havada | GS / NL |
| Temiz atış | Silah hazır ve hedefin kafasına (merkez ±3), göğsüne ya da pelvisine yeterli hasar geçiyorsa: defensive yok, gizli açı yok, teleport / Air LC başlamaz, paket hemen gider; atıştan sonra 6 tick | açık | GS V1.0.26/37 |
| Safe recharge | Atıştan sonra görülürken 0.5 sn şarj bekletilir (`block_recharge` her tick, bırakınca bir kez `allow_recharge`); Peek, > 100 birim/sn, hava, eğik peek, 260 birimde bıçak, 420 birimde zeus, seni gören oto-sniper'da yok. Tek sahip + 3 sn bekçi | açık | GS V1.0.22/68/69 |
| İnişte teleport | **Teleport in air + Air: break LC ikisi açıkken (varsayılan), DT ile:** havada DT hiç boşaltılmaz, Air LC kilidi yok, şarj inişe saklanır. Rakip seni görürken (ya da son 24 tick'te gördüyse) inişe **1–11 tick kala** (max şarj − 3; yedek: yerde 1. tick) tek bir teleport (`force_uncharge`, şarj 0 olana kadar ≤ 4 tick); teleport tick'inde ve sonraki 2 tick zıplama bastırılır. İniş anı `sv_gravity` + 5 köşe zemin iziyle, iniş noktasının zeminiyle ikinci kez hesaplanır. 3D yer değiştirme < 64 u ise (yerinde zıplama, ~200 u/s altı) atılmaz. Uçuşta (kalkıştan yerde 2. tick'e kadar) defensive zorlanmaz | açık | GS V1.0.80 |
| Havada teleport (eski yol) | Sadece Air LC kapalıyken: havada görülürken (ya da görülmek üzereyken), inişe ≥ 0.35 sn varken atlayış başına bir kez `force_uncharge` (≤ 4 tick), inişte şarj serbest | açık | GS / NL |
| Air LC (eski yol) | Sadece Teleport in air kapalıyken: havada görülünce inişe kadar şarj yok + tam fakelag (teleport yapılmadıysa teleportla başlar) | açık | GS V1.0.78/79 |
| Merdiven | Merdiven (`m_MoveType` 9) hava sayılmaz: teleport, Air LC, air lag, tam choke ve jump scout yok | otomatik | GS `teleport.plan` |
| Teleport sonucu | Teleporttan 0.12-1.5 sn sonra vurulma ölçülür; haritada son 3'ün 2'si vurulduysa o harita boyunca havada teleport / Air LC kapalı | otomatik | GS V1.0.33/34/45 |
| Bozuk atış koruması | Kendi lag'ın (DEF / LC / TP) sırasında 10 sn'de 2 `server rejection` / `prediction error` → o lag 10 sn durur | otomatik | GS / NL |
| Air lag | Havada görülmüyorken her tick defensive; sadece durumun defensive modu Smart iken (Off / On peek'te yok), DT'li uçuşta (inişte teleport) yok | açık | GS V1.0.51/80 |
| Gerçek kayıt bekleme | Hedefin kaydı sahteyken (defensive) ve kimse seni görmüyorken ≤ 14 tick ateş bekletilir (hedef yoksayılır + gruplar kapalı), gerçek kayıt geldikten 3 tick sonra serbest, sonra 32 tick serbest; düelloda bekleme yok. Harita değişince bekleme durumları silinir | açık | GS V1.0.22/47/62 |
| Taze kayıt (sniper) | Şu anki kayda mermi geçmiyor ama son 24 tick'te geçiyorduysa bekletilir (izler sadece son 32 tick'te taranan / bekletilen / tehdit olan düşmana) | açık | NL V1.1.5/8 |
| Min. damage kuralları | Sıra: bıçak / zeus → DT çifti → extended → kafa saklayan → can'a yükselt. Bıçaklı 320 birimde göz göze: MD min(30, can); zeus: sadece öldürücü (can). Extended şüphesi (kafada 3 resolver ıskası üst üste, yan duruyorsa 2; her isabet, gövde dahil, seriyi sıfırlar; 300 sn ıskasız seri baştan): gövde, MD gövde−1 (180 sn ya da kafa isabetine kadar; süre bitince seri sıfırdan). Kafa saklayan (12+ atışta kafa payı ≤ %35): sniper gövde, her 4. atış kafaya serbest. Extended ve kafa saklayan sadece hedef yerdeyken, gövde ≥ 60 ve gövde öldürmüyorken: yoksa kafa açık kalır, MD'ye dokunulmaz (duvar arkası gövde MD'yi düşürmez). **Senin Min. damage'in bunlar dışında asla düşürülmez** | açık (DT çifti kapalı) | GS V1.0.14/66-75/79 |
| Head unless body kills | Sniper, biri seni görürken sadece öldürücü atış (MD can'a yükseltilir; config'te MD 100 = can ise etkisiz) | açık | GS |
| Akıllı gövde | Tek gövde mermisi öldürüyorsa kafa / kol / bacak kapalı | açık | GS |
| Sahte kayıtta gövde | Sniper, hedef sahte kayıtta ve gövde öldürüyorsa kafa gerçek kayda (≤ 12 tick) | açık | GS / NL |
| Adaptif resolver | Düşman ve durum başına son 4 sonuç (sadece isabet ve resolver ıskası; spread / diğer ıskalar pencereye girmez); resolver ıskası sayısı = seviye 1 (safe point kafa) / 2 (Force safe point). Hafızadan gelen eski ıskalar en fazla seviye 1: Force için bu haritada o durumda bir resolver ıskası gerekir. Scout / AWP (Head unless body kills açıkken) ≤ 1, R8 sınırsız; 0.5 sn ateş gelmezse 2 sn seviye 1; jitter desenli yeni düşman seviye 1; can ≤ 30 seviye 2. Asla `safe point false` yazmaz | açık | GS / NL |
| Havada hit chance | Sniper havada bu değer (0 = kapalı) | 0 | GS V1.0.47 |
| Auto peek durumu | Hareket ederken görüş alanına girmek = Peek (8 tick) | açık | GS |
| AI peek | Autopeek tuşu basılı, hareket tuşu yok: tehdide dik 18/32/46/60 birim noktalar taranır (kafa yeterli ya da gövde öldürücü, yürünebilir, 2 taramada doğrulanır), oraya yürür, 0.5 sn bekler (R8 0.75), atıştan sonra native autopeek döner (0.5 sn'de dönmezse script). 2 boş peek → o düşmana tuşa yeniden basana kadar yok | açık | GS / NL |
| AFK modu | Kendi çapası, AI peek tuşsuz, 3 sn'de bir 24 birim sağ / sol, her tick defensive | kapalı | GS V1.0.35 |
| Otomatik AFK | Doğduktan / donma bittikten sonra 8 sn girdi yoksa AFK; herhangi bir girdi kapatır (bu doğuşta tekrar açılmaz) | açık | GS V1.0.37/71 |
| Göstergeler | Nişangah altı (NYKLE.WIN, durum, DT/HS/FS/DEF, BRUTE, RES, BAIM, CLEAN SHOT, AIR LC, ANTI-PEEK, AI PEEK, AFK); manuel oklar; sol liste (DT yeşil / sarı / kırmızı, DT OFF, HS, FD, DEF, LC, AIR LC, MD, BAIM, SAFE, FS, PEEK, AFK, ROLL!, FD!); resolver paneli | açık | GS V1.0.76 |
| Sol el | `cl_righthand 0` (kalıcı), kapatınca eski değer | açık | GS V1.0.28 |
| Aspect ratio | 4:3 (Off = eski değer, 5:4, 16:10) | 4:3 | GS V1.0.35 |
| FPS boost | GS'deki 13 cvar (gölgeler, 3D sky, post-process, kırılan parçalar, namlu ışığı, dinamik ışık); ragdoll kapatma ayrı (kapalı) | açık / kapalı | GS V1.0.35/59 |
| Sadece konsol + dosya | `developer 0`; loglar ekrana düşmez | açık | GS V1.0.35 |
| Otomatik bomba | Round başında HE + smoke + molotov / incendiary (native buybot zaten alıyorsa almaz; DM'de doğuşta) | açık | GS V1.0.70 |
| Clan tag | "Nykle.win" harf harf | açık | GS |
| Trash talk | GS'deki İngilizce satırlar | kapalı | GS V1.0.48 |
| Jump scout | Scout ile durarak zıplayınca native autostrafer kalkıştan inişe kadar kapalı | açık | GS V1.0.18 |

**Taşınmayanlar:** roll / extended desync (yasak), düşmana body yaw zorlama (primordial'da yok; GS V1.0.77'de native resolver daha iyiydi), native tuşları değiştiren her şey (DT / HS seçimi, sniper exploit öğrenmesi, fake duck bırakma: script yalnız uyarır), granat yardımcısı (istemedin), recharge pozu ve "gövde 70+" (loglar aleyhte / Min. damage kuralı).

## Loglar

Her satır `[Nykle.win] ` ile başlar; dosyada başına saat eklenir. Satır biçimleri GS sürümüyle aynı, analiz araçları ikisinde de çalışır:

- `atis: <isim> | <durum> | HP <can> | hedef <grup> <hasar> | isabet <grup> -<hasar> / iska <sebep> / sonuc yok | SP <Head/Force/-> | BA <Force/Default> | MD <md> | bt <n>t | hc <n>% | sen <silah>[ temiz| LC| DEF| TP| FD] | <desen> dsy? <air/ground>[ | bekleme: ...][ | def (sahte kayit)]` — primordial'ın `resolver` ıskası `correction` yazılır.
- `vuruldun: ...`, `iska: ...` (sana gelen mermiler), `oldurdun: ...`, `oldun: ...`, `round ozeti: ...`, `atis ozeti: ...`.
- `resolver: ...`, `teleport: ...` (`teleport: inise N tick kala (S, hiz, 2D / 3D u, h)`, `teleport: inise yok (gorulmedi / temiz atis / sarj x/y / yavas 3D N u / tahmin yok / durduruldu)`, `teleport: inis teleportu bitti (...)`), `teleport sonucu: ...`, `air lc: ...`, `ai peek: ...`, `afk modu ...`, `otomatik afk ...`, `backstab: ...`, `aa: desync isareti ...`, `UYARI: ...`.
- Detailed log açıkken: `dbg ayarlar`, `dbg duello`, `dbg sikmadi`, `dbg olum-detay`, `dbg kill-detay`, `dbg air lc`.

Dosya: yeni sürümde (dosyada `V1.0.0 (primordial edition) yuklendi` yoksa) sıfırlanır; 2 MB'yi geçerse son 1 MB tutulur, 4 MB'yi geçmişse sıfırlanır; bir oturumda 2 MB'den fazla yazılmaz. Round başında / sonunda, harita değişince, ölünce, kapanışta ve 5 dk'da bir (ölüyken 1 dk) yazılır.

## Bilinen belirsizlikler (oyunda doğrulanacak)

primordial'ın Lua API'si belgelenmemiş; aşağıdakiler başka script'lerden çıkarıldı. Script hepsinde iki ihtimale göre de güvenli çalışır, sonucu loga yazar.

| Belirsizlik | Script ne yapar | Logda |
|---|---|---|
| SETUP_COMMAND / ANTIAIM sırası, ANTIAIM'in komut başına kaç kez çağrıldığı | Durum ve jitter komut numarasıyla bir kez hesaplanır | — |
| Script native tuş (DT / HS / fake duck) değiştiremez | Hiç yazmaz; DT kapalıysa uyarı | `UYARI: DT kapali (cfg'de DT her zaman acik olmali)` |
| Eksik menü yolunun ne döndürdüğü | pcall + tip kontrolü + ilk okuma denemesi; o özellik kapanır | `menude bulunamadi: a > b > c` |
| `block_recharge` kalıcı mı, tek `force_uncharge` şarjı boşaltır mı | Block her tick yenilenir, uncharge şarj 0 olana kadar ≤ 4 tick | `teleport: ... (N. kez, uncharge K tick)`, `sarj kilidi 3 sn'yi gecti` |
| `set_desync` işaretinin hangi taraf olduğu | Ölçülür; tutarsızsa `set_invert_desync` de | `aa: desync isareti olculdu (+ = sag)` / `(olculemedi)` |
| `set_safepoint_state(true, HEAD)` anlamı, seviye 2 ateşi engeller mi | Sniper ≤ 1, 0.5 sn ateş yoksa 2 sn seviye 1 | `resolver: X ... seviye 2 -> 1 (ates gelmedi, 2 sn)` |
| Min. damage 100 üstü = can + fark mı | Script MD'yi asla can üstüne yazmaz | — |
| Native Auto Direction "States" öğesine adla yazma | Geri okuma; olmazsa sıra numarası; o da olmazsa durum başına FS kapatma kapalı | `fs_states:Air = false ayarlanamadi` |
| `cmd.move.y` işareti (sağ / sol) | AI peek / AFK hızdan ölçer; 3 başarısız ölçümde kapanır | `ai peek: yan hareket isareti ters olculdu, duzeltildi` |
| Native autopeek dönüşü | 0.5 sn dönmezse script götürür | `ai peek: geri (native donmedi)` |
| Dosya konumu (`MOD` yolu) | csgo klasörü; yoksa oyun kökü; yazılamazsa hafıza | `log dosyasi: nykle_log.txt (MOD, csgo klasoru)` |
| `player_hurt.hitgroup`, `reason_string == "jitter"` | Yoksa `?`; jitter de correction sayılır | `vuruldun: ? -45 ...` |
| `force_anti_exploit_shift` eski sürümde yok | Sadece üye kontrol edilir (namespace tablo / userdata, üye fonksiyon / çağrılabilir olabilir); yoksa defensive özellikleri devre dışı | `(defensive yok: eski primordial)` |
| `trace.bullet` hitbox olmayan noktaya ne döndürür | Hitbox dışı noktalar için `trace.line` (kapak / FS auto); `trace.bullet` sadece hitbox'a | — |
| `cmd:remove_button(JUMP)` | İniş teleportunda zıplamayı bastırmak için (pcall) | — |
| `game_newmap` bağlanırken gelmeyebilir | Yerel oyuncu yok olup geri gelince ya da tickcount geri gidince de harita sıfırlaması | — |
| Düşman `m_angEyeAngles[1]` okunur mu | Okunmazsa desen `?`, yan duruş kısayolu kapalı | atış satırında `? dsy?` |
| cvar'lar Lua'dan yazılabilir mi | Okunamayan cvar'a hiç yazılmaz | `cvar <ad> yazilamadi` |
| Etiket içinde `%` | Öğe adlarında `%` + harf yok (`35 pct over`) | — |
| ANTIAIM'de E basılıyken primordial AA'yı kapatıyor mu | Legit AA o zaman hiç çalışmaz | — |

## Sürüm geçmişi

- **V1.0.0 (primordial edition), inceleme düzeltmeleri:** GS V1.0.80 inişte teleport (havada DT boşaltılmaz, Air LC kilidi yok, uçuşta defensive yok); merdiven hava sayılmaz; air lag sadece Smart'ta; extended / kafa saklayan gövde kuralı sadece yerde, gövde ≥ 60 ve öldürmüyorken, seri her isabette sıfırlanır; resolver Force'u hafızadan değil bu haritadaki ıskadan, spread ıskaları pencereye girmez, R8 Force alabilir; harita değişiminde tick'e bağlı durumlar (Smart tutma, bekleme cooldown'u, teleport, izleme) sıfırlanır; FS auto düz izle; hafıza 64 sınırında yeni rakibi atmaz; override tuşu hata verirse yeniden aranır; config: override Caps Lock basılı tut (G = silah atma), Hideshots tuşsuz (Z = radio), native Nade Helper kapalı.
- **V1.0.0 (primordial edition):** ilk sürüm. GS V1.0.79 varsayılanları ve log kuralları; primordial'a özgü: native AA taşıyıcıları nötr tutma (Override nesnesi, kapatınca geri), recharge'ın tek sahibi, desync işareti ve yan hareket işareti ölçümü, Air LC'nin "şarj yok + tam fakelag" ile yapılması, kalıcı hafıza ve log dosyası ffi ile.
