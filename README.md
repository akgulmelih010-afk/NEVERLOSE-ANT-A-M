# Nykle.win lua V1.1 — Neverlose HvH anti-aim, exploit ve resolver lua'sı

Neverlose (CS:GO) için durum (state) bazlı anti-aim, exploit ve resolver lua'sı. Sadece HvH sunucuları için. Eski adı **ANT-A-M** (v2 – v5.6); V1.0, v5.6'nın üzerine kuruldu. GameSense sürümü ayrı dosyada (aşağıda "GameSense edition").

**Kurar kurmaz çalışır.** Bütün ayarlar hazır gelir; exploitler ve defensive her durumda kendiliğinden doğru moda geçer. **Always use recommended settings** açık kaldıkça her sürümde en iyi bilinen ayarlar korunur, ayarlara dokunman gerekmez.

## V1.1'de ne değişti (GameSense sürümünden taşınanlar)

GameSense sürümü on oyun loguyla V1.0.22'den V1.0.33'e geliştirildi, V1.0.34'te hata taramasıyla düzeltildi, V1.0.35'te AFK modu, aspect ratio ve eğilme koruması geldi, V1.0.36'da AA şarj anına göre ayarlandı, V1.0.37'de otomatik AFK geldi (bkz. "GameSense edition" ve `LOG_ANALIZI_GS_1.0.16-21.md`). Orada loglarla kanıtlanan ve Neverlose API'siyle yapılabilen her şey buraya taşındı. Varsayılanlar GameSense'teki en iyi ayarlar; hepsi menüden kapatılabilir.

| Değişiklik | Nerede | Logdaki kanıt (GameSense) |
|---|---|---|
| **Smart defensive yakında düşman varken de zorlar:** 1800 birim içinde (dormant olmayan) bir düşman varken görülmeyi beklemez. Dururken / eğilip beklerken / Manual / Freestanding varsayılanı artık **Smart** (Safe head On peek kaldı) | Exploits → Defensive → **Smart: force near enemies** (açık); Builder'daki Defensive seçimleri | Kafa mermilerinin 36/48'inde saldıran `gormedi`: defensive'li uzak scout ekranda görünmeden ateş ediyor. V1.0.25'te K/D 29/49 → 41/46, `gormedi` kafa 21 → 5 |
| **Safe recharge** Peek'te ve yürürken (> 100 birim/sn) beklemez; üst sınır 1.2 → **0.5 sn** | Exploits → Safe recharge | `sarj bekle` ile 179 mermi / 70 kafa yendi, 57'si Peek'te, çoğu atıştan sonraki 0.3 sn içinde: beklerken DT kapalı ve defensive yok |
| **Defensive vs enemy peeks** silahın hazırken de zorlanır (temiz atış varsa yine kalkar) | Exploits → Defensive (On peek durumlarında) | Kafa mermilerinin %42'si düşman seni gördükten < 0.1 sn sonra geldi (1 sn+ görenlerde %17) |
| **Anti-brute fazları 6, 7, 8:** desync 32°; 41° + taraf çevirme + 10°; asimetrik taraf süresi (bir taraf 2 paket uzun, uzun taraf her 4 çevirmede değişir). **Kötü bilinen faz** (≥ 12 mermi, ≥ %55 kafa) düşman başına ilerlemede atlanır; Stats → `AA FAZ`'da `x` | Anti-brute (kendi kendine öğrenir) | 0–5 fazlarının hepsi %32–43 kafa yedi: taraf / ±15° değiştirmek resolver'ın ±58 tahminini bozmuyor; havada faz 1 16/25 = %64 |
| **Snipers varsayılanı `Same as state` (DT).** `Auto (learn)` önce DT, 24 mermi görmeden değişmez, öteki ≥ 16 mermi, geçiş farkı 0.15; kullanılan exploit %45+ kafa yiyorsa denenmemiş öteki denenir | Exploits → Snipers (SSG08/AWP/R8) | HS açıkken kafa %45 (208 mermi), DT'de %36 (898); 4 mermilik eski öğrenme bütün oturumu HS'ye çeviriyor ve HS ile zorlanan defensive / teleport / peek koruması çalışmıyordu |
| **Sahte kayıtta ileri bakış uzar:** düşmanın kaydı gördüğümüzün gerisindeyse (defensive) görüş tahmini o kadar (≤ 0.25 sn) daha ileriden yapılır | Otomatik (görüş sistemi) | `gormedi` kafa mermilerinin 22/23'ünde vurulma anında iz kapalıydı, 13'ünde kaydı sahteydi: defensive'li düşman gördüğümüz yerden değil ilerisinden ateş ediyor |
| **DT çifti (sniper):** DT dolu ve gövde × 2 ≥ can (gövde ≥ 60) ise Min. Damage geçici gövde − 1 (ilk mermi gövdeye, ikincisi DT ile). Senin Min. Damage'in 100 üstüyse (can + fark) dokunulmaz. Log: `X: DT cifti olduruyor (govde 86 x 2 >= can 100), Min. Damage gecici 85` | Ragebot → Resolver → **Snipers: DT pair kills (body x 2 >= HP)** (açık) | En büyük ölüm kaynağı gövde 70–87 vurulabilirken kafa beklemekti (12 ölümün 11'i); Min. damage 100 şartı "sadece öldürecek atış" demek, DT çifti öldürüyor |
| **Kafa önceliği (V1.1.5 / V1.1.6):** kafa açıkken kafaya: DT çifti öldürüyorsa Body Aim Prefer kalır (Force değil), az önce ateş ettiğin hedefte de çift gövdeyi zorlamaz (tek gövde mermisi öldürüyorsa Force), duelloda sahte kayda kafa atmadan önce 6 tick gerçek kayıt beklenir. **V1.1.7:** DT çifti yalnızca hedefin kaydı 8+ tick gecikmeliyken (kafa tutmaz); kayıt tazeyse Min. Damage 101 kalır (kafa) | Ragebot → Resolver → **Headshot priority** (açık; kapalı = V1.1.3: çift her zaman, öldürüyorsa gövde Force, duelloda bekleme yok) | İstek: daha fazla HS. Scout'ta DT ikinci mermiyi atmıyor (kullanıcı doğruladı; loglarda 130 atışta 1), çiftin gövdesi düşmanı 9 canla bırakıp sürgüde öldürtüyordu (11/19 ölüm); kafa taze kayıtta %79 tutuyor, gecikmeli kayıtta %29 |
| **Taze kayıt (V1.1.5):** sniper'da hedefin şu anki kaydına mermi geçmiyorsa ama 24 tick içinde geçiyorduysa (geri çekildi / köşe arkasına geçti) ateş bekletilir (V1.1.8: hitbox listesi boşaltılır, Min. Damage 130 yedek; görülme şartı yok); kayıt yine vurulabilir olunca ya da eski kayıtlar backtrack penceresinden çıkınca serbest. Log: `resolver: X su anki kaydi vurulamiyordu: 9 tick taze kayit beklendi, kayit taze, ates serbest` | Ragebot → Resolver → **Snipers: fresh record only** (açık) | 8+ tick backtrack'li atışların %68'i ıska (kafa %81), 8 tick altındakilerin %12'si (kafa %19): uzun backtrack hep düşman görünüp çekildiğinde ilk atışta |
| **Gerçek kayıt bekleme:** hedefin kaydı sahteyken (defensive) ve kimse seni görmüyorken en fazla 14 tick ateş bekletilir (V1.1.8: hitbox listesi boşaltılır, Min. Damage 130 yedek), gerçek kayıt geldikten 3 tick sonra serbest, sonra 32 tick serbest. Duelloda (Peek, az önce ateş ettiğin hedef, seni gören düşman) Headshot priority açıkken en fazla 6 tick beklenir, kapalıyken hiç. Log: `resolver: X sahte kayitta (defensive): 8 tick gercek kayit beklendi, gercek kayit geldi` | Ragebot → Resolver → **Wait for real record (unseen)** (açık) | Sahte kayda giden atış %57 tuttu, gerçek kayda giden %75; defensive bittikten 0–2 tick sonra giden %58 |
| **Havada sniper hit chance:** havada scout / AWP / R8 ile Hit Chance geçici bu değer (V1.0.47'den beri varsayılan 0 = kapalı, senin hc'n; senin değerin daha düşükse dokunulmaz) | Exploits → Defensive → **In-air hit chance (snipers)** | 254 `sikmadi`'nin 75'i "sen havadasın" (hepsi hc 55); havadan giden hc ≥ 55 atışlar %67–89 tuttu, hc < 55 olanlar 12'de 3 gövde, 0 kafa |
| **Teleport sonucu ölçülür:** ışınlandıktan 1.5 sn içinde mermi yediysen "vuruldu"; bir haritada son 3 teleportun 2'si vurulduysa o haritada teleport kapanır (harita değişince açılır). Log: `teleport sonucu: ...`, `teleport: bu haritada son 3 teleportun 2'si vuruldu -> ... kapali` | Otomatik | Bazı haritalarda 3 teleportun 2'si vuruldu: ışınlanma kaydı geçersizleştirmiyor, sadece şarjı harcıyordu |
| **Kalıcı sol el:** lua yüklenir yüklenmez `cl_righthand 0`, açık kaldıkça öyle kalır; kapatınca / script kaldırılınca eski değer | Home → **Left hand (cl_righthand 0, permanent)** (açık) | İstek |
| **Log kaydı:** konsola yazılan her satır saatiyle hafızada; Home → Console → **Dump logs to console** hepsini yeniden yazar, **Save logs to file now** `nykle_log.txt`'ye yazar (Neverlose'un `files` API'si varsa; round başında, harita değişince, 5 dk'da bir ve kapanışta kendiliğinden). `vuruldun:` satırında `gormedi (iz: su an goruyor / kapali)` | Home → Console | GameSense'teki bütün analizler bu dosyadan yapıldı |
| **"Sıkmadı" teşhisi:** hedefe mermi geçiyor ama 0.44 sn ateş yoksa sebep tek satırda: `dbg sikmadi: X 0.44s vurulabilir (kafa 0, govde 74 hasar, can 100), ates yok \| hasar 74 < MD 101 \| MD 101 \| sen ssg08` (sebepler: Min. Damage, gerçek kayıt bekleniyor, silah hazır değil, sahte kayıtta sadece gövde, havada hit chance, aimbot başka hedefe) | Shot log açıkken | GameSense'teki 254 `sikmadi` satırı DT çifti ve havada hit chance kararlarının kaynağıydı |

**Taşınamayanlar:** GameSense'teki *kendi resolver* (Force body yaw kolları: `lby± / wall± / abs±`, UCB ile düşman başına öğrenme) Neverlose'a taşınamaz: Neverlose Lua API'si düşman başına açı zorlamaya izin vermiyor (sadece safe point / body aim). Clan tag ve trash talk da GameSense'e özel kaldı. Neverlose API'si hakkında doğrulanamayan iki nokta güvenli yazıldı: `cvar.cl_righthand:int()` yoksa `utils.console_exec` denenir (o da yoksa konsola bir kez yazılır); `files.write` yoksa dosya yazılmaz, logları **Dump logs to console** ile al.

**V1.1.1** (ilk Neverlose logu, 4.5 dk; `LOG_ANALIZI_GS_1.0.16-21.md` sonunda): dosya kaydı çalıştı; gerçek kayıt bekleme logu düşman başına 15 sn'de bir (205 satırın 95'i o idi); `sikmadi` satırında SP / BA / hitbox durumu da (iki "sebep bilinmiyor"); zaman damgası oyun saati dakika:saniye (`os.date` yok).

**V1.1.2** (ikinci Neverlose logu, 13 dk): kafa oranı %77 → %19 (faz öğrenmesi oturdu), teleport haritada kapandı (4 vurulma). `sikmadi` penceresi 0.63 sn, 20 hasar altı ve sadece "silah hazır değil" satırları yazılmaz; `oldurdun: X | durum | sen silah [| headshot]` ve `oldun: ...` satırları (K/D log analizi için). **Eğik peek** (istek: "eğilerek peek atınca çok ölüyorum") loglarda ve Stats → `KD`'de `Peek (egik)` olarak ayrı sayılır; ayarı sonraki loglara göre gelecek (bkz. `DEVIR_NOTU.md` → Açık işler).

**V1.1.3** (üçüncü Neverlose logu, 29 dk, 78 atış): kafaya giden atışların 15/31'i correction ıskası, gövdeye gidenlerin 7/45'i; Peek'teki 13 kafa mermisinin 10'u kendi ıskandan sonra `DT %0` iken geldi. DT çifti öldürüyorsa artık Body Aim **Force** (ilk mermi gövdeye, ikincisi DT ile; gövde görünmüyorsa 0.5 sn sonra Prefer). Eğik peek (`Peek (egik)`) bu logda hiç yok; ölümlerin 15'i ayakta Peek.

**V1.1.4** (dördüncü Neverlose logu, 11 dk; ilk eğik peek verisi): eğik peek'te 5 ölüm / 5 öldürme; ölümlerin 3'ü kendi ıskandan 0.24–0.74 sn sonra `DT %0` iken, biri teleport sonrası `DT %0` ile, biri `DEF acik` iken. Eğik yürürken kaçamadığın için → **Bolt cover** (Exploits → Defensive, açık): scout / AWP / R8 ile ateş ettikten sonra sürgü çekilirken (silah hazır olana kadar) biri seni görüyorsa **fake duck zorlanır** (kafa aşağıda, kayıt her pakette değişir), silah hazır olunca bırakılır; bıçaklı düşman yakınsa / havada yok. Ayakta peek için ayrı seçenek (**Bolt cover also in standing peek**, kapalı: fake duck geri çekilmeyi yavaşlatır). Log: `surgu korumasi: fake duck (Peek (egik), atistan 0.12 sn sonra, silah hazir degil)`.

**V1.1.5** (istek: "daha fazla HS atmak istiyorum" + "çok missliyoruz"; üçüncü Neverlose logu yeniden incelendi): iki değişiklik.
- **Headshot priority** (Ragebot → Resolver, açık): kafa açıkken kafaya. DT çifti öldürüyorsa gövde zorlanmaz (V1.1.3'ün Force'u yerine Prefer; kapatınca eski davranış), az önce ateş ettiğin hedefte de DT çifti gövdeyi zorlamaz (tek gövde mermisi öldürüyorsa yine Force), duelloda / görülürken sahte kayda kafa atmadan önce en fazla **6 tick** gerçek kayıt beklenir (eskiden hiç; sahte kayda atış %57, gerçek kayda %75 tutuyordu). Log: `... 6 tick gercek kayit beklendi, sinir doldu, ates serbest (duello, kafa onceligi)`.
- **Snipers: fresh record only** (Ragebot → Resolver, açık): logda ıskanın asıl kaynağı **backtrack** çıktı: 8+ tick geriye atılan 25 atışın 17'si ıska (kafa 13/16, gövde 4/9), 8 tick altındakilerin 52'de 6'sı (kafa 3/16, **%81 isabet**). Uzun backtrack hep ilk atışta: düşman görünüp geri çekilince / köşe arkasına geçince aimbot eski kayda ateş ediyor ve resolver o kayıtta yanılıyor. Şimdi hedefin **şu anki** kaydına mermi geçmiyorsa (az önce geçiyorduysa) ateş bekletilir (Min. Damage 130, en fazla 24 tick = backtrack penceresi); kayıt yine vurulabilir olunca hemen serbest. Hiç görünmemiş hedefte bekleme yok. Log: `resolver: X su anki kaydi vurulamiyordu: 9 tick taze kayit beklendi, kayit taze, ates serbest` / `eski kayitlar gecti (backtrack yok)`. Beklenti: `bt 9t`+ atışlar kaybolur, isabet %70 → %80+, HS oranı yükselir; sonraki logda `atis:` satırlarındaki `bt` ile ölçülecek.

**V1.1.6** (beşinci Neverlose logu, 18 dk, 54 atış, V1.1.5 ile): isabet %76 (önceki %69 / %56), kafa 13/21 (%62, önceki %50), correction ıskası %15 (önceki %28), 25 öldürme / 19 ölüm (önceki 8 / 10), eğik peek 15 öldürme / 6 ölüm (önceki 5 / 5). Üç bulgu, üç değişiklik:
- **DT çifti gerçekte yok:** scout'ta DT ikinci mermiyi atmıyor (iki logda 130 atışta 1 çift; atışlar hep 1.0–1.3 sn arayla, yani sürgüden sonra). "Çift" gövde −91 ile düşman 9 canla kalıyor ve sen 1.25 sn sürgü bekliyorsun: 19 ölümün 11'i atıştan sonraki sürgüde. Şimdi Headshot priority açıkken **duelloda** (Peek'tesin ya da hedefin kendisi seni görüyor) çift yok, kafa (öldürürse sürgü yok); hedef seni görmüyorsa (başka düşman görüyor olsa da) çift serbest. Hedefin kaydı 8+ tick gecikmeliyse kafa tutmuyor (bu logda 5/7, önceki 13/16 ıska; gövde 0/6) → yine çift. Log: `X: duello, DT cifti yerine kafa (govde 73 x 2 >= can 100 ama ikinci mermi surguden sonra)`.
- **Bolt cover kapatıldı** (seçenek duruyor): fake duck'la kapanan sürgüye 14 mermi geldi (3'ü kafaya), 7 ölüm `Fake duck` durumunda; fake duck'ta DT boşalıyor ve defensive yok. Kapalıyken (4. log) sürgüde 3/10 ölüm, açıkken 11/19.
- **Taze kayıt** bekledi (17 bekleme, en uzunu 24 tick), ama 8+ tick backtrack'li atış hâlâ 13/54: uzun `bt` artık bizim seçimimiz değil, **düşmanın gecikmesi** (DUVARCI 138:13'ten sonra hep `bt 13–26t`). Kayıt gecikmesi ölçülüyor (`exposure.record_age`, sunucu zamanı − düşmanın en yeni kaydı) ve yukarıdaki çift kuralına giriyor.

**V1.1.7** (kullanıcı doğruladı: Neverlose'da DT ikinci mermiyi sadece deagle'da atar, scout / AWP / R8'de atmaz): sniper'larda "DT çifti" diye bir şey yok. Headshot priority açıkken çift kuralı yalnızca hedefin kaydı 8+ tick gecikmeliyken çalışır (kafa tutmaz, gövde 0/6 ıska); kayıt tazeyse hedef seni görsün görmesin kafa (Min. Damage 101). V1.1.6'nın "hedef görmüyorsa çift" ayrımı kaldırıldı. Kapalıyken eski davranış (gövde ilk, ikinci atış sürgüden sonra). Log: `X: DT cifti yerine kafa (govde 73 x 2 >= can 100 ama scout'ta ikinci mermi surguden sonra)`.

**V1.1.8** (hata taraması: 4 avcı + her bulguya 2 bağımsız doğrulayıcı; 22 adaydan 5'i gerçek çıktı):
- **Beklemeler ateşi kesmiyordu.** Gerçek kayıt / taze kayıt beklemesi Min. Damage 130 ile yapılıyordu; Neverlose'da 100 üstü = can + fark, yani 130 = can + 30. Scout kafası 150–290 vurduğu için kafa atışı serbest kalıyordu (5. logda `MD 130` ile 3 atış, ikisi sahte kayda, biri ıska). Şimdi bekleme sırasında **hitbox listesi boşaltılır** (hedef yok = atış yok; MD 130 yedek). `sikmadi` satırında `(hitbox yok)` ibaresi.
- **Taze kayıt beklemesi görülmeye bağlıydı:** düşman köşe arkasına geçince seni görmesi de bitiyor, bekleme tam o anda düşüyordu. Şart artık sadece silah (scout / AWP / R8 + Head unless body kills). Silah değişince yarım bekleme sessizce biter (eski sayaç loga karışmaz).
- **Gecikmeli kayıtta çift Prefer'de kalıyordu:** Neverlose Prefer'de yine kafaya gidiyordu (5. log 142:45 `BA Prefer | MD 73 | bt 26t` ıska). Gecikmeli kayıtta artık Body Aim **Force** (0.5 sn görünür gövde yoksa Prefer).
- **Teleport sonucu:** ışınlandıktan 0.12 sn içinde gelen mermi ışınlanmadan önce atılmıştı, artık örnek sayılmaz (5. logda `0.02 sn sonra vuruldun` harita kapatma sayımına girmişti).
- **Kalıcı hafıza:** `get_xuid` sayı ya da 64 bit cdata (`...ULL`) dönerse `s:` anahtarı üretilmiyordu; iki logda da `yuklendi` satırında hafıza yoktu. Hepsi aynı metne çevrilir. Sonraki logda `yuklendi (hafiza: N oyuncu)` görünmeli.
- Elenen adaylar (doğrulayıcılar reddetti, DEVIR_NOTU'nda): `record_age`'in kendi ping'ini de ölçmesi (eşik 8 tick bunu kapsıyor), duello 6 tick beklemesinin çoğunlukla dolması (bilinçli), `sikmadi`'nin taze kayıt beklemesini yazmaması (eklendi), `ayarlanamadi` ağının hata fırlatmaya dayanması.

Test: `tests/run_tests.sh` 7 mod + strict, **1064 kontrol** (V1.1 için 48 yeni kontrol; yeni kontrollerin eski mantıkta kırıldığı doğrulandı). `tests/run_tests.sh mutate`: **754 mutasyonun hepsi yakalanıyor** (V1.1 için 27 yeni mutasyon, V1.1.5 için 12, V1.1.6–7 için 7, V1.1.8 için 8, 30 eskisi yeni koda göre güncellendi). Oyun içi test: ilk log V1.1.1'e girdi.

## V1.0'da ne değişti

**Resolver: en kararlı sürüme dönüş + mantıklı iyileştirmeler.** Sürümler tek tek karşılaştırıldı. v5.2'den sonra resolver'a eklenen üç şey her sürümde atışı biraz daha kısıtlıyordu ve "resolver gittikçe kötüleşti" hissinin kaynağı bunlardı:

| Kaldırılan (sürüm) | Neden |
|---|---|
| Wait out enemy defensive (v5.5) | Düşman defensive'deyken aimbot'un hitbox listesi boşaltılıp ~0.2 sn ateş bekletiliyordu. HvH'de çoğu kişi defensive'i sürekli açık tutuyor: her temasta ilk atış gecikiyordu, önce ateş eden kazanır. Ayrıca beklerken diğer düşmanlara da ateş edilmiyordu. |
| Uzaktaki düşmana veri olmadan `Prefer`, tek ıskada `Force` (v5.6) | `Force` safe point'te güvenli nokta bulunamayınca aimbot hiç ateş etmiyordu; uzakta en çok bu oluyordu. Uzak ıskaların çoğu resolver değil spread/hit chance. |
| Fake duck yapan düşmana veri olmadan `Prefer` (v5.5) | Tahmindi, veriye dayanmıyordu. Fake duck ayrı durum olarak kalıyor ve kendi verisiyle öğreniyor; DT'li silahta gövde tercihi de duruyor. |
| Kendi fake duck'ında zorla `Prefer` (v5.4) | Seviye artık sadece düşmana göre; fake duck'ta da resolver'ın kendi seviyesi. |

Taban **v5.2'nin resolver kuralları** (düşman ve hareket durumu başına 1 ıska `Prefer`, 2 ıska `Force`, jitter ön bilgisi, Force takılma koruması) + **v5.3'ün sniper düzeltmesi** (Min. Damage can + 1, hedeften bağımsız). Üstüne iki iyileştirme, ikisi de "bizim numaralarımıza kanmama" için:

- **Sahte kayda giden ıska öğrenilmez:** aimbot düşmanın defensive kaydına (gördüğümüz en yeni kayıttan eski; açılar hidden, lag compensation bozuk) ateş edip `correction` ile ıskalarsa bu resolver'ın taraf hatası değildir, safe point de düzeltmez. v5.5 loglarında bu ıskalar `Force`'ta bile sürdü ve seviyeyi boşuna yükseltip sonraki gerçek kayıtlarda kafa atışını kesiyordu. Artık sayılmaz (Stats panel'de `OTHER`), atış satırında `def (sahte kayit)` yazar. Defensive'den hemen sonraki gerçek kayıttaki ıska (`def`) normal sayılır.
- **Jitter sadece gerçek kayıtlardan ölçülür:** defensive kaydındaki açı düşmanın hidden yaw'ıdır (spin / random). Eskiden bu açılar da ortalamaya girip statik AA'lı düşmanı "jitter" gösteriyor ve gereksiz `Prefer` açıyordu.

**Anti-aim:** AA'nın yaw/desync varsayılanları v4.2'den beri hiç değişmedi (topluluk preset'lerinden, loglarla doğrulanmış). Sonraki sürümlerin AA eklemeleri kaldı: hidden yaw `Random` (Sideways tarafı ele veriyordu), fake duck'ta rastgele yaw/desync, anti-brute faz 5, AI peek iyileştirmeleri, defensive peek. Sorun çıkardığı görülen bir AA özelliği yoktu; resolver'a bağlı olanlar yukarıda kaldırıldı.

**İlk V1.0 loglarından iki düzeltme:**

- **Fake duck'ta faz 5 yok:** round özetinde fake duck'ta kafadan vuruldun ve o an anti-brute **faz 5** uygulanıyordu (`kafa fazlari 5:1 | FD 1`). Faz 5 desync'i `Static` + `Peek Fake` yapıyor ve fake duck'ın her pakette rastgele tarafını eziyordu: eski "fake duck'ta hep aynı taraf → kafadan vuruldun" sorununun aynısı. Faz 5 artık kendi AA'sı olan durumlarda (Fake duck, Safe head, Manual) uygulanmaz.
- **Teleport sonrası atış:** loglarda havada 3 teleport'tan hemen sonraki scout atışı `iska unregistered shot` oldu. Teleport'tan sonraki 0.3 sn içindeki atışlar atış satırında `TP` ile işaretlenir (`sen ssg08 TP`); böyle iki atış 10 sn içinde sunucuda geçmezse teleport 10 sn durur (DEF ve LC için olan korumanın aynısı).

**Zıplama / teleport / iniş (sonraki V1.0 logları):** iki ölüm de bu döngüdeydi ve ikisinde de exploit şarjsızdı: havada ikinci teleport'tan 0.21 sn sonra `DT %80, DEF yok`; inişten sonra peek'te `HS %14 LC`. Teleport artık **zıplama başına 1 kez** ve inişe en az 0.35 sn varsa (şarj inmeden dolsun); **Snipers use DT in the air** varsayılan **kapalı** (inişteki DT → HS geçişi şarjı sıfırlıyordu, scout havada da HS + Break LC).

**Duvardan öldürücü gövde hesabı:** "tek gövde mermisi öldürüyor → Body Aim Force" kararı artık gerçek mermi iziyle (duvar dahil) veriliyor; duvar arkasındaki düşmana öldürmeyen zorlanmış gövde atışı yok.

**Mantık taraması (V1.0):**
- **Açıktayken düşman peek'ine tepki:** seni gören düşman yeni göründüyse ya da görürken hızla hareket ediyorsa (jiggle / geniş peek) ve silahın o an ateş edemiyorsa (sürgü, şarjör) defensive zorlanır; silahın hazırsa sıra senin atışında. Göstergede `ANTI-PEEK`. Görünmeden önceki tahmin aynen kalır.
- **Peek tuşu + safe head:** tuşa basıp dururken artık Peek durumu yok (duruşun AA'sı, otomatik freestanding'i ve safe head'i kalır); dururken, eğilip dururken ve Peek'te defensive'de sahte açı yok (kafayı siperden çıkarıyordu).
- **AA ateş ettiğin düşmana döner:** aimbot'un son 1 sn içinde ateş ettiği düşman hayattaysa ve seni görüyorsa AA ona döner ve anti-brute'ta onun fazı uygulanır (loglarda 0x41'e göğüs vuruldu, AA başkasına dönüktü, 0.35 sn sonra 0x41 kafadan vurdu: `AA hedefi degil`).
- **Sniper'da vurduğun düşmana öldürücü gövde:** scout / AWP / R8 ile az önce ateş ettiğin (1.5 sn) düşmanı gövde öldürüyorsa Body Aim `Force` (eskiden hep `Prefer`: loglarda göğüs -73 sonrası 27 candaki düşmana Neverlose kafaya gidip ıskaladı, sürgü çekerken öldün).
- **Sahte kayda kafa atışı yok (sniper):** hedefin kaydı defensive'de (sahte) iken scout / AWP / R8 sadece göğüs + mideye ateş eder (öldürüyorsa); kafa atışı gerçek kayda gider. En fazla 12 tick bekler, sonra 0.5 sn serbest (sürekli defensive kullanana da kafa atışı gider). Loglarda sahte / havadaki kayda kafaya nişan alınan atışlar gövdeye geldi (göğüs -45, -53, mide -92), düşman hayatta kaldı. Göstergede `DEF BODY`.
- **Resolver paneli gerçeğe yaklaştı:** başlangıç %80 (eskiden %60), indirimler yumuşak (jitter 120°'de ×0.8, havada ×0.9, sahte kayıtta ×0.5). V1.0 loglarında resolver'a bağlı ~12 isabete 1 `correction` ıskası vardı ama panel %50-60 gösteriyordu.
- **Sadece kafa görünüyorsa Force yok:** hedefin gövdesine mermi izi geçmiyorsa (yukarıda eğilmiş, sadece kafası görünen düşman) resolver en fazla `Prefer`; `Force` kafada güvenli nokta bırakmadığı için hiç ateş edilmiyordu.
- **Sniper'da Force yok:** scout / AWP / R8 sadece öldürecek atış yaparken resolver en fazla `Prefer`: tam canlı düşmanda öldürecek tek nokta kafa ve `Force` kafada güvenli nokta bırakmıyordu (atış hiç gelmiyor, her temasta 0.5 sn kayıp).
- **AI peek:** silah ateş edemezken (sürgü, şarjör) ve Hide shots şarj olurken peek yok; yukarıdaki düşmana geri-çapraz noktalar da denenir.

**Temiz atış ("resolver %80-90 ama ıskalıyor, hit düşük"):** ıskaların resolver dışı kısmının kaynağı kendi lag'imizdi. V1.0 loglarında atışların hepsi `LC` (Hide shots Break LC) ya da `FD` iken gitti; lag sırasında tickbase kaydığı için sunucu silahın hazır olduğunu başka tick'te görüyor: mermi geçmiyor (`unregistered shot`) ya da bir tick sonra başka göz noktasından gidiyor (`prediction error`, kafaya nişan → göğüs / mide isabeti).

- **Clean shot (no lag while shooting)** (varsayılan açık, Exploits → Defensive): silahın ateş edebiliyorken ve hedefin kafasına, göğsüne ya da midesine gözünden Min. Damage'ı geçen mermi gidiyorsa (aimbot şimdi ateş eder) Break LC, zorlanan DT defensive'i, hidden açılar ve havada teleport durur. Mermi gidince (sürgü, şarjör) hepsi hemen geri gelir: savunmasız olduğun an zaten silahın ateş edemediği an. Göstergede `CLEAN SHOT`, atış satırında `sen ssg08 temiz`.
- Hedef değişince eski hedefin bekleme süresi taşınmaz; bıçak / bomba ile ve hitbox okunamazsa hiç açılmaz (eski davranış).
- **Lag'li atışta `prediction error` da sayılır:** kendi lag'in (DEF / LC / TP) sırasında 10 sn içinde iki bozuk atış (`unregistered shot`, `damage rejection` ya da artık `prediction error`) o lag'i 10 sn durdurur. Log: `... sirasinda 2 atis bozuk gitti`.
- **Stats paneli:** `LAG x / y   TEMIZ x / y` = kendi lag'in açıkken ve temiz giden atışların isabet / atış sayısı. Temiz atışın işe yarayıp yaramadığı buradan görünür.
- **AI peek gövde kuralı:** taramada gövde noktası sadece öldürüyorsa sayılır (DT'li silahta iki mermiyle). Auto / deagle'da Min. Damage düşükken script öldürmeyen bir gövde açısına yürüyordu ("AI peek body atabiliyor"); artık kafanın açık olduğu ya da gövdenin öldürdüğü noktaya gider. Scout / AWP / R8'de zaten sadece öldürecek atış aranıyordu.
- **AI peek'te defensive bekleme:** noktada beklerken düşmanın kaydı sahteyse (defensive) bekleme bir kez 0.2 sn uzar (0.5 → 0.7 sn). Aimbot sahte kayda kafa atmaz; eskiden süre dolup atışsız geri dönülüyordu.
- **Durum başına KD (Stats paneli):** `KD   OLDURDUN / OLDUN` bölümü: hangi durumdayken (Peek, Fake duck, Air…) kaç kill aldın ve kaç kez öldün. Sadece düşmanın öldürdüğü ölümler ve düşman killeri sayılır. FD'nin ve Peek'in gerçekten işe yarayıp yaramadığı buradan görünür.
- **Round sonu atış özeti (konsol):** `atis ozeti: 6 mermi, 4 isabet | temiz 4/5, lag 0/1 | iska: correction 1, prediction error 1`. Iska sebepleri en çok olandan başlar; `correction` = resolver, `spread` = isabet şansı, `prediction error` / `unregistered shot` = tahmin ya da kendi lag'in. "Missliyor" dediğinde bu satırı atman yeterli. Shot log açıkken yazılır.
- **"Önüme eğiliyor, kafasını görüyorum, sıkmıyor" düzeltildi:**
  - Sahte kayıt kuralı (sniper'da kafa yerine gövde) artık **sadece gövde öldürüyorsa** devreye girer. Tam canlı düşmanda gövde öldürmediği için kural hiç atış getirmiyordu; defensive kullanan (eğilip duran) düşmana tekrar tekrar sıkılmıyordu. Seçeneğin yeni adı **Snipers: lethal body on fake records**.
  - Temiz atış ve AI peek düşmanın kafasının sadece ortasına değil **iki kenarına da** iz atar: kafasının bir kısmı görünen düşman da "vurulabilir" sayılır (lag kapanır, AI peek o açıyı bulur).
- **Mantık taraması (2):**
  - Neverlose'un tehdidi yokken AA en yakın düşmana dönüyordu ama anti-brute fazı son ateş edenden geliyordu: artık faz da AA'nın baktığı düşmanınki. Tehdit yokken yandan gören düşmana da dönülür (tehdit varken olduğu gibi).
  - Kafandan vuran düşmanın öğrenilen fazı, onun kendi fazından değil **AA'nın o an gösterdiği fazdan** hesaplanır. AA başka düşmana dönükken (düello / yandan gören) eski hesap "bir sonraki faz" olarak tam vurulan fazı seçebiliyordu. `vuruldun` satırındaki `faz` ve round özetindeki `kafa fazlari` da artık gösterilen faz.
  - Sahte kayıt kuralında (sniper sadece gövde) temiz atış kafayı saymaz: kafa açık diye atış gelmeyecekken lag boşuna kapanıyordu.
- **AA kendi kendine öğrenmesi düzeldi:** denenmemiş anti-brute fazları artık %30 sayılıyor (eskiden %50). Peek'te en iyi faz bile kafana gelen mermilerin yarısını (16/33) yiyordu ve diğer fazlar hiç denenmiyordu; şimdi %40'ın üstünde vurulan faz bırakılır, sırayla diğerleri denenir.
- **Fake duck artık her yerde senin:** **Fake duck only when standing still** varsayılan kapalı. Bunny hop + FD ile ani peek (düşmanın önüne ışınlanıp hemen kafa) bu ayar yüzünden havada ve koşarken bozuluyordu. FD sırasında temiz atış yok (FD kendisi lag; atış satırında `FD`).
- **Paneldeki HIT düzeldi:** eskiden Neverlose'un hit chance'i (loglarda %82-100, ama 51 atışta 0 spread ıskası) ile düşmanın ham ıska oranı çarpılıyordu; 2 atışta 1 tahmin hatası HIT'i yarıya indiriyordu. Artık gerçek spread ve resolver dışı ıska oranları kullanılır, düşmanın az atışı tüm düşmanların oranına doğru çekilir (ön bilgi: spread %2, diğer %8). Veri yokken HIT ≈ çözüm × 0.9.

**Menü baştan düzenlendi:** 6 sekme (Home, Anti-Aim, Exploits, Builder, Ragebot, Visuals), ikonlar ve fareyle üzerine gelince Türkçe açıklamalar. Bütün konsol logları tek yerde (Home → Console) ve artık tercih: önerilen ayarlar onları açıp kapatmaz. Builder'da durumun AA'sı solda, exploit'i sağda.

**Öğrenilenler kaybolmaz:** hafıza aynı `db` anahtarında; v5.x'te öğrenilen fazlar ve resolver seviyeleri V1.0'a aynen geçer.

## Kurulum

1. `Nykle.win.lua` dosyasını Neverlose'un script klasörüne at (eski `antiaim.lua`'yı sil, ikisi birlikte çalışmasın). Menüde **Scripts** sekmesinden klasörü açabilirsin, genelde `Counter-Strike Global Offensive/nl/scripts` olur.
2. Oyunda Neverlose menüsü → **Scripts** → `Nykle.win` → **Load**.
3. Konsolda `[Nykle.win] V1.0 yuklendi` gibi bir satır çıkar (daha önce öğrenilmiş düşmanlar varsa sonunda `(hafiza: 12 oyuncu)` yazar); güncelledikten sonra numaranın değiştiğini buradan kontrol et.
4. Solda **Nykle.win** sekmesi çıkar. İçinde **Home**, **Anti-Aim**, **Exploits**, **Builder**, **Ragebot** ve **Visuals** sekmeleri var. Ayarlar Neverlose config'inle birlikte kaydedilir.
5. Şu üç şeyi tuşa bağla (öğeye sağ tık → bind): **Manual yaw** (sol/sağ), **Freestanding**, **Static inverter** (hepsi Anti-Aim sekmesinde).

> Konsolda `[Nykle.win] 12 ayar onerilen degerine donduruldu (orn. Fake duck Left limit 60, onerilen 58)` gibi bir satır çıkarsa Neverlose config'inden eski değerler yüklemişti ve script onları önerilen değerlere geri aldı (aşağıda **Always use recommended settings**). `Always use recommended settings kapali: ...` yazıyorsa o ayar kapalı ve ayarların önerilenden farklı; açmak için Home sekmesine bak.
>
> Konsolda `[Nykle.win] createmove hata verdi: ...` gibi bir satır çıkarsa bir olay fonksiyonu beklenmedik bir değerle karşılaştı demektir. Script durmaz; hata her olay için bir kez yazılır. O satırı bana at.
>
> Konsolda `[Nykle.win] menude bulunamadi: ...` ya da `[Nykle.win] ... ayarlanamadi: ...` yazısı çıkarsa Neverlose sürümünde o menü öğesinin ya da seçeneğin adı farklı demektir, ya da ayar o an kilitliydi. Script çökmez: reddedilen değeri 5 saniye sonra tekrar dener, bu arada o ayarı senin kendi değerine bırakır, gerisi çalışmaya devam eder. Yazıyı bana at, düzeltirim.

## Duruma göre exploit (varsayılanlar)

Script her tick'te hangi durumda olduğunu bulur ve o durumun AA'sını ve exploit ayarını uygular. **Auto exploit** açıkken (varsayılan) DT'yi kendisi açar, senin bind'ine gerek kalmaz.

| Durum | Ne zaman | Exploit | Defensive | Hidden pitch / yaw |
|---|---|---|---|---|
| Standing | Yerde duruyorsun (Peek Assist tuşu basılı olsa da) | DT | On peek | — (V1.0: dururken sahte açı yok) |
| Moving | Yürüyorsun / koşuyorsun | DT | Smart | Up / Random |
| Slow walk | Slow walk tuşu basılı | DT | Smart | Up / Random |
| Crouching | Eğilmiş duruyorsun | DT | On peek | — (V1.0) |
| Crouch move | Eğilerek yürüyorsun | DT | Smart | Up / Random |
| Peek | Peek Assist (quick peek) tuşu basılıyken **hareket ediyorsun** ya da AI peek yürüyor / noktada bekliyor (V1.0: tuşa basıp dururken artık Peek değil, duruşun AA'sı, freestanding'i ve safe head'i kalır), ya da hareket ederken düşmanın görüş alanına giriyorsun | DT | Smart | — (V1.0: bilerek kendini gösterirken sahte açı yok) |
| Air | Havadasın | DT | Smart | Up / Spin |
| Air crouch | Havada eğiliyorsun | DT | Smart | Up / Random |
| Fake duck | Fake duck tuşu basılı (peek'ten de önce gelir). Bıçak / zeus tutan düşman yakındaysa fake duck bırakılır (Anti-Aim → **Release fake duck near knife**). AA: rastgele taraf, ±20° rastgele yaw ve 48-58 rastgele desync her pakette; görüş kontrolü kafayı ayakta yüksekliğinde de dener (fake duck'ta kafa eğilip kalkar, düşman onu yukarıda da görür) | — (fake duck'ta DT/HS çalışmaz) | — | — |
| Manual | Manuel yaw açık | DT | On peek | — |
| Freestanding | Freestanding kafanı bir duvarın arkasına saklayabildi | DT | On peek | — |
| Safe head | Bıçak/zeus ile havada eğiliyorsun ya da düşmandan yüksektesin ve kafanı görebiliyor | DT | On peek | — |

Scout, AWP ve R8'de exploit tablodaki DT yerine Hide shots'tır (aşağıda **Snipers**).

- **Smart** (hareket ederken ve havada varsayılan): "On peek"in aynısı, üstüne script düşmanın kafana mermi geçirebildiğini (ya da 0.2 sn içinde geçirebileceğini) gördüğü anda DT doluysa defensive'i kendisi zorlar (`force_defensive`). Görüş sürdükçe zorlamaya devam eder, görüş kesilince 8 tick daha zorlar. Eskiden aynı görüş 1 saniyeden uzun sürünce bırakıyordu; loglarda Peek'te 1.47 sn görüldükten sonra `DT dolu, DEF yok` iken kafadan vuruldun. Neverlose'un modu hep "On Peek" kalır, yani durumlar arasında mod değişip DT boşalmaz. Neden: oyun loglarında `Air | DT dolu, DEF yok` ve `Peek | DT dolu, DEF yok` isabetleri vardı; Neverlose'un peek tespiti o anları kaçırmıştı. Dururken ve eğilip beklerken "On peek" kalır: açı tutan sensin, orada ilk atışın hızı daha önemli. Hide shots'ta Smart, On peek ile aynı çalışır (Break LC).
- **On peek**: Neverlose peek attığını kendisi algılar ve tam o an defensive'e geçer. Yani yerde peek atınca exploit kendiliğinden devreye girer. Hide shots'ın Neverlose'da böyle bir seçeneği yok; HS kullanırken (ör. scout'ta) **hareket ettiğin sürece** (yürürken, slow walk'ta, eğilerek yürürken, Peek'te, havada) ya da düşman kafanı görüyor / birazdan görecekken / az önce kafana ateş ettiyse "Break LC" açılır ve yarım saniye açık kalır. Görüş beklenmez: loglarda HS ile `DEF yok` iken kafadan vuruldun ve saldıranı script'in izleri görmemişti (`gormedi`). **Anti-backtrack:** Break LC açıkken sunucudaki eski kayıtların geçersizleşir, düşmanın aimbot'u senin 100-400 ms önceki konumuna (backtrack) ateş edemez. Yerinde dururken LC kırılamaz (yer değiştirmeden kayıtlar zaten aynı yerde), orada işe yaramaz. Fake latency'li düşmanlara karşı da yardımcı olur ama hepsini durdurmaz; anti-defensive kullanan bir rage'e karşı da tam koruma değildir.
- **Fake duck**: Fake duck'ta exploit çalışmaz ve paketler ~14 tick boğulur; jitter ~0.2 sn'de bir dönüp tahmin edilebilir olur. Bu yüzden ayrı bir durum: varsayılanı **Random** body yaw: desync tarafı her pakette rastgele seçilir, tahmin edilecek bir sıra yoktur. Eskiden static + "Peek Fake" body freestanding'di; tarafı Neverlose seçtiği için anti-brute tarafı değiştiremiyordu (loglarda `faz 1` ve `faz 2`'de hep `sol 58` ile kafadan vuruldun). Oyun loglarında fake duck peek'te, özellikle fake duck'la ateş ettikten hemen sonra kafadan vurulma görüldü; fake duck'ta Hide shots da çalışmadığı için ateş anındaki açın açıkta kalır. Log satırında `FD` yazar. v4.1 öncesi loglarda fake duck'ta hep `sol 60` görünüyordu; varsayılan 58 ve body freestanding'le taraf değişmeli. Yani fake duck, Fake duck durumu eklenmeden önce kaydedilmiş bir config'in (o sıradaki Manual'in: static, sol, 60, freestanding yok) değerleriyle çalışıyordu: tek taraflı, tahmin edilebilir bir AA. Artık önerilen ayarlar oyun sırasında da korunuyor (Home → **Always use recommended settings**).
- **Auto peek** (varsayılan açık): Script düşmanın kafana mermi geçirebilip geçiremediğini her 2 tick'te hesaplar (şimdi ve 0.2 saniye sonraki konumun için). Kafanın merkezi siperin arkasındaysa iki yan kenarına da (3.5 birim) bakılır: düşmanın aimbot'u kafanın kenarına da ateş eder, loglarda `gormedi` iken kafadan vurulmalar vardı. **Düşmanın hareketi de tahmin edilir:** düşmanın gözü hızıyla 0.2 sn ileri alınır; sana doğru peek atıyorsa kafanı görmeden önce "birazdan görecek" sayılır. Smart defensive, Hide shots'ın Break LC'si, Safe recharge ve AA'nın dönüşü düşman görünmeden devreye girer. Neden: v4.8 loglarında ölümlerin çoğunda düşman seni 0.00-0.03 sn'de vurdu; defensive ancak o göründüğünde açılıyordu. Tahmin edilen görüş log'da `gordu` sayılmaz. Havadayken kafanın yüksekliği de tahmin edilir (zıplama hızı ve yerçekimi), yani kutu üstünden zıplayınca kafa siperin üstüne çıkmadan önce görüş "birazdan" olarak algılanır; zıplama tuşuna basıldığı tick'te bile. Neverlose'un tehdidi yoksa en yakın düşman tehdit sayılır. Ayrıca her güncellemede tehdit dışındaki düşmanlardan ikisi sırayla kontrol edilir; yandan bakan bir düşman da auto peek'i, Smart defensive'i, Hide shots'ın Break LC'sini ve Safe recharge'ı tetikler. Bir düşmanın görüşü 12 tick geçerli sayılır; ölen, dormant olan ya da listeden çıkan düşmanın görüşü hemen silinir. Hareket ederken görüş alanına giriyorsan, peek assist tuşuna basmasan da Peek durumuna geçer. Görüş kesilince 8 tick daha Peek'te kalır. Durursan açı tutuyorsun demektir, normal duruma döner.
- **Always on**: Defensive sürekli açık (Lag Options = Always On, HS'de Break LC). **Hiçbir durumda varsayılan değil:** oyun loglarında zıpladıktan, eğilip yürümeye ya da peek'e geçtikten ~0.4 sn sonra (defensive modu "Always on"a dönünce) DT %0'a düşüyor ve vurulma tam o sırada geliyordu. Varsayılanda bütün durumlar "On peek" ya da "Smart" kullanıyor; ikisinde de Neverlose'un modu "On Peek" kaldığı için durumlar arasında mod hiç değişmiyor. İstersen builder'dan bir durum için açabilirsin.
- **Tick based**: Her N komutta bir defensive zorlanır (`force_defensive`).
- **Off**: Defensive zorlanmaz. Kendi Neverlose ayarın "Always On" olsa bile Neverlose'un en sakin modu olan "On Peek"e çekilir.
- **Hidden pitch / yaw**: Defensive tick'lerinde sunucuya giden sahte açılar. **v5.6:** yerdeki durumlarda hidden yaw `Random` (eskiden `Sideways`), eğilerek yürürken hidden pitch `Up` (eskiden `Switch`): `Sideways` desync tarafına göre ±90, `Switch` da tarafa göre aşağı/yukarı veriyordu; defensive tick'lerinde açıları okuyan bir resolver kafanın hangi tarafta olduğunu oradan görebiliyordu. **V1.0:** dururken, eğilip dururken ve Peek'te hidden açı **yok**: yerinde dururken LC kırmanın konumsal faydası yok (kayıtların zaten aynı yerde), defensive tick'lerinde sahte pitch / yaw sadece kafayı siperin / freestanding'in arkasından çıkarıyordu ("peek tuşuna basınca kafa direkt defans açıyor, kafamı vuruyorlar"); peek'te pitch Up kafayı yükseltiyordu. Defensive'in kendisi (LC kırma) kalır. Yürürken ve havada hidden açılar (havada spin) kalır.
- Elinde bomba (grenade) varken, fake duck yaparken ve merdivende defensive kapanır.
- E'ye basınca (legit AA) ve spin sırasında DT kapatılmaz; kapatıp açmak her seferinde yeniden şarj demek.
- Durumlara farklı exploit seçersen (ör. yerde DT, havada HS) her geçişte DT yeniden şarj olur. Hepsini DT'de bırakmak en güvenlisi.

Her durumun bu ayarları **Builder** sekmesinde, durumu seçince sağdaki **State exploit** sütununda görünür (Global ve Fake duck'ın exploit ayarı yok; sütun nedenini yazar).

## Menü

### Home
Üstte script adı, sürüm ve Neverlose kullanıcı adın. Enable kapalıyken de görünür.

| Ayar | Varsayılan | Ne işe yarar |
|---|---|---|
| Enable | Açık | Lua'yı açar/kapatır. Kapatınca Neverlose'un kendi ayarların geri gelir. |
| Always use recommended settings | Açık | Neverlose lua ayarlarını config'e kaydeder; eski bir sürümle kaydedilmiş config eski değerleri geri getirir. Bu açıkken bütün AA, exploit, builder ve resolver ayarları o sürümün önerilen değerlerinde **tutulur**: script yüklenince, config yüklenince ve oyun sırasında saniyede bir kontrol edilir, farklı olan geri alınır ve konsola kaç ayarın düzeltildiği bir örnekle yazılır (en fazla 30 sn'de bir). Neden: sadece yükleme anında dönmek yetmiyordu, Neverlose config değerlerini script'ten sonra da uygulayabiliyor (loglarda Fake duck eski değerlerle çalışıyordu). Bind'lenen ayarlara (Manual yaw, Freestanding, Static inverter), builder'daki durum seçiciye, konsol loglarına ve Visuals'a dokunmaz. Kendi ayarlarını kullanmak istersen kapat; kapalıyken hiçbir ayar değiştirilmez, yüklemede kaç ayarın önerilenden farklı olduğu bir kez yazılır. |
| Forget learned enemies (Memory) | — | Steam ID ile hatırlanan bütün anti-brute fazlarını, resolver seviyelerini ve sniper verisini siler (kayıtlı hafıza dahil). |
| Reset stats (Memory) | — | İstatistikleri sıfırlar. |
| Resolver log (Console) | Açık | Resolver seviyesi değişince konsola yazar. Örnek: `resolver: isim Air iska (correction) \| seviye 1 -> safe points Prefer`. |
| Shot log (Console) | Açık | Her aimbot atışı tek satır (aşağıda **Ragebot**) ve AI peek logları. |
| Hit log (Console) | Açık | Vuruldun / ıska satırları, round özeti, teleport ve fake duck notları (aşağıda **Visuals**). |
| Anti-brute log (Console) | Kapalı | Anti-brute fazı değişince: `anti-brute: isim faz 3`. |

Konsol logları tercih: **Always use recommended settings** onları değiştirmez.

### Anti-Aim
**Main** (solda: pitch, yaw base, manual, inverter, avoid backstab, legit AA, spin) ve **Protection** (sağda: freestanding, safe head, anti-bruteforce, fake duck korumaları) grupları.

| Ayar | Varsayılan | Ne işe yarar |
|---|---|---|
| Pitch | Down | `Fake Down/Up` sadece untrusted'a izin veren sunucularda. |
| Yaw base | At Target | Düşmana göre döner (sırtın ona döner; jitter ve desync ona göre). **V1.0:** aimbot'un son 1 sn içinde ateş ettiği düşman hayattaysa ve seni görüyorsa önce ona döner (vuramadığın düşman geri ateş eder). Az önce (1 sn içinde) kafanın yanından mermi geçiren ya da seni kafadan vuran düşman varsa ona göre döner (tehdit seni görüyorsa tehdide). Neverlose'un tehdidi yoksa script en yakın düşmanı seçer; tehdit seni görmüyor ama yandan başka biri görüyorsa ona göre döner. Neden: loglarda `AA hedefi degil, gormedi` ile aynı düşmandan arka arkaya kafadan vuruldun; ateş eden düşman AA'nın baktığı düşman değildi. Neden: oyun loglarında `tehdit yok` iken havada kafadan vuruldun; AA hiçbir düşmana göre dönmüyordu. Desync kafayı yana kaydırır, bu ancak bakan düşmana göre doğru yöndeyse kafayı saklar. Freestanding'de ve `Local View` seçersen dokunulmaz. |
| Manual yaw | Off | Sol / Sağ / İleri. Tuşa bağla. |
| Freestanding | Kapalı | Kafayı duvar tarafına saklar. Tuşa bağla. Kafan yine de açıkta kalıyorsa (freestanding saklayamadıysa) normal jitter'a döner. Dişli simgesinden: havada kapalı (varsayılan), eğilirken / slow walk'ta / yürürken kapat seçenekleri. **Auto when standing still** (varsayılan açık): tuşa basmasan da yerinde dururken ve eğilip dururken freestanding açılır (açı tutarken kafa duvar tarafına saklanır); hareket edince normal jitter'a döner. |
| Static inverter | Kapalı | Body yaw `Static` olan durumlarda desync tarafını çevirir. |
| Safe head | Açık | Bıçak/zeus ile havada eğilirken kafayı sabitler (yaw 0, desync 30). Dişliden **High ground** (varsayılan **kapalı**): düşmandan 35+ birim yüksekteyken ve düşman kafanı gerçekten görürken de sabitler. v4.9'da kapatıldı: v4.8 loglarında alttaki düşman kafanı görürken Safe head'deyken 5 kafa mermisinin 4'ü isabet etti (`gordu 0.00-0.03s`); düşük desync tam görüldüğün anda kafayı ortaya getiriyordu. Kapalıyken hareket durumunun AA'sı (ve Smart defensive) kalır. Desync tarafı her pakette rastgele (`Random`): eskiden hep aynı taraftı (loglarda Safe head'de `sol 30` ile kafadan vuruldun). |
| Anti-bruteforce | Açık | Düşman mermisi kafanın 40 birim yakınından geçince ya da vurunca 5 faz arasında döner. Faz 1: Static body yaw'da tarafı çevirir; jitter'da desync'i yaw sırasının tersine kaydırır, böylece resolver'ın öğrendiği desen bozulur. 2. ve 3. fazda kafa ayrıca ±15° kayar. Faz 4: desync tarafı her flip'te rastgele, yaw'dan bağımsız (yaw sırayla dönmeye devam eder ama kafanın hangi tarafta olduğunu ele vermez). **Faz 5 (v5.6):** desync sabit, tarafı Neverlose'un body freestanding'i (`Peek Fake`) seçer: gerçek kafa duvar tarafında kalır, düşmana önce sahte taraf görünür; yaw jitter'ı desync'ten bağımsız devam eder. Kendi AA'sı olan durumlarda (Fake duck, Safe head, Manual) uygulanmaz (V1.0: fake duck'ın rastgele tarafını eziyordu). Hangi fazın sana karşı en az vurulduğunu sistem senin maçlarında ölçer (aşağıda), faz 5 de bu yarışa girer. Desync hiçbir fazda düşük desync'e inmez (resolver'lar ıskadan sonra bunu dener). **Kendi kendine öğrenen AA:** Her fazda kafana gelen mermiler (kafadan isabet ya da kafanın yanından ıska) sayılır; seni kafadan hiç vurmamış düşmanlar **en az vurulan fazla** başlar. Oran (isabet + 2.4) / (mermi + 8) (V1.0; denenmemiş faz 0.3 sayılır); yeni bir faz ancak şimdikinden 0.1'den fazla iyiyse seçilir (tek bir isabet seçimi değiştirmez, aynı fazda arka arkaya iki kafa isabeti değiştirir). **V1.0 düzeltmesi:** eskiden oran (isabet + 2) / (mermi + 4) idi, denenmemiş faz 0.5 sayılıyordu: kafa isabeti %50'ye yakın bir faz hiç bırakılmıyordu. Loglarda `AA (peek): en az vurulan faz 1 (16/33 kafa isabeti)`: peek'te kafana gelen mermilerin yarısı isabet etti ve diğer fazlar hiç denenmedi. Artık %40'ın üstünde vurulan fazın yerine denenmemiş olan denenir (yarısında vurulan faz 5-6 mermide bırakılır); hafızadaki peek verin de buna göre yeniden değerlendirilir. Sayım **hareket grubuna göre ayrı** yapılır: yerde (Standing, Crouching, Fake duck…), hareket (Moving, Slow walk, Crouch move), peek (Peek) ve havada (Air, Air crouch); yerde en iyi olan faz havada en iyi olmayabilir. Peek v4.7'de ayrıldı: v4.6 loglarında kafa isabetlerinin hepsi Peek'teydi; v4.6 kaydında peek'in verisi yürümeninkinden başlar. Safe head, Manual ve Fake duck'taki mermiler sayılmaz: onların kendi AA'sı var (v4.8 loglarında Safe head'deki kafa isabetleri "yerde" grubuna yazılıp normal duruşun fazını değiştirmişti). Mermi geldiği anki grup ve faz kaydedilir. Seçim değişince konsola `AA (hava): en az vurulan faz 2 (1/9 kafa isabeti) -> verisi olmayan dusmanlara faz 2` yazar. v4.5'in tek listesi yüklenince her gruba kopyalanır. Sayılar 40'ı geçince yarılanır (son oyunlar ağır basar) ve kalıcı hafızaya yazılır; gövde, bıçak ve zeus isabetleri sayılmaz. Faz **her düşman için ayrı** tutulur (her resolver ayrı öğrenir) ve sana ateş edenin ya da kafanı görenin fazı uygulanır: az önce (1 sn) kafana ateş eden düşman varsa onunki, AA'nın baktığı tehdit seni görmüyor ama yandan başka biri görüyorsa onunki, kimse görmüyorsa tehdidinki. Aynı düşmanın DT çift atışı tek atış sayılır. Iskalarla ilerleyen faz 6 saniye sonra, round başında ya da ölünce biter. **Hafıza:** Bir düşman kafanı hangi fazda vurduysa, ona karşı bir sonraki fazdan başlanır ve bu round'lar arası kalır (Neverlose resolver'ı da oyuncuları round'lar boyunca hatırlar). Gövde/bacak isabetleri hafızayı değiştirmez. Hafıza Steam ID ile tutulur, harita değişince ve oyunu kapatıp açınca da kalır (aktif faz sıfırlanır); Home → Memory'deki **Forget learned enemies** düğmesi siler. |
| Avoid backstab | Açık | Bıçaklı düşman arkana gelince döner. |
| Fake duck only when standing still | **Kapalı** (V1.0) | Açıkken havadayken ve hareket ederken (40 birim/sn üstünde 0.15 sn) fake duck bırakılır; durunca (10 altı) ve inince yine senin. Kısa kıpırdamalar bırakmaz. v5.0'da v4.9-v5.1 loglarındaki `Fake duck \| FD, DT %0 (bind)` ölümleri yüzünden eklenmişti. **V1.0'da varsayılan kapalı:** fake duck'ı bilerek kullanıyorsun: bunny hop yapıp FD ile düşmanın önüne "ışınlanıyor" (FD paketleri boğar, düşman seni bir anda karşısında görür) ve hemen kafa atıyorsun; FD'siz peek'te karşıdaki de seni vurabiliyor. Bu ayar tam o peek'i bozuyordu (havada ve koşarken FD'yi bırakıyordu). Kapalıyken FD tuşun her yerde çalışır; bıçak koruması (Release fake duck near knife) ayrı ve açık kalır. Konsola `fake duck birakildi: hareket ediyorsun` yazar (açıksa, 10 sn'de en fazla bir kez). |
| Release fake duck near knife | Açık | Bıçak ya da zeus tutan canlı bir düşman 260 birimden yakınsa fake duck'ı kapatır (bind'in basılı olsa da); 360 birimden uzaklaşınca ya da silah değiştirince bind'in yine geçerli olur. Fake duck'ta eğik ve yavaşsın, DT/HS çalışmaz. Oyun loglarında fake duck'tayken bıçakla üç kez arka arkaya vurulup ölündü. Konsola `fake duck birakildi: isim bicak/zeus ile 180 birim yakinda` yazar. |
| Legit AA on use | Açık | E'ye basılı tutarken AA çalışmaya devam eder. Kapı açma ve silah alma bozulmaz. CT olarak bomba ya da rehine yanındaysan karışmaz. |
| Spin when idle | Açık | Hiç canlı düşman kalmayınca spin yapar. Warmup'ta spin isteğe bağlı (varsayılan kapalı, çünkü HvH sunucularında warmup'ta da savaşılıyor). |

### Exploits
**Exploits** (auto exploit, snipers, safe recharge, hidden spin), **Peek** (auto peek, AI peek, defensive during AI peek) ve **Defensive** (düşman peek'ine karşı, air lag, teleport, sniper DT havada) grupları.

| Ayar | Varsayılan | Ne işe yarar |
|---|---|---|
| Auto exploit | Açık | Her durumun exploit seçimini (DT / HS / Binds) uygular. Kapatırsan DT/HS'yi kendi bind'lerin yönetir. |
| Auto peek | Açık | Hareket ederken düşmanın görüş alanına girince Peek durumuna geçer (yukarıya bak). |
| Defensive vs enemy peeks | Açık | Dururken ve eğilip beklerken ("On peek" durumları) **sana peek atan düşmana tepki**: DT defensive'i zorlanır ve 0.25 sn daha sürer, mermisi geldiğinde LC kırık ve açıların gizli olur (Hide shots'ta Break LC açılır). Üç an: (1) düşman görünmeden önce, sana doğru hareket ediyorsa (hızından 0.2 sn ileri tahmin); (2) **V1.0:** kafanı görmeye başladığı ilk 0.25 sn (yeni göründü) ve (3) kafanı görürken hızla hareket ettiği sürece (120 birim/sn üstü: jiggle / geniş peek), **ama sadece silahın ateş edemiyorken** (scout / AWP sürgü çekerken, şarjör değişirken): silahın hazırsa sıra senin atışında, defensive zorlanmaz ("üzerime gelen hareketli kişileri vurmakta zorlanıyor": görünür düşmana karşı hep zorlandığında atışların sunucuda geçmeyebiliyordu). Durup açı tutan ya da yavaş yürüyen düşmana karşı bırakılır. Eskiden tepki düşman göründüğü an bitiyordu: "ben açıktayken karşıdakinin peeklediğini anlasın". Göstergede `ANTI-PEEK`. Tehdit dışındaki düşmanlar da sırayla kontrol edilir. Hareket ederken bunu zaten Smart yapar. |
| Air lag (defensive every tick) | Açık | Havadayken DT doluysa defensive **her tick** zorlanır (görülmeyi beklemeden): havada sürekli lag (LC kırık) ve defensive tick'lerinde hidden açılar (Air: pitch Up / yaw Spin, Air crouch: Up / Random). Neverlose'un modu "On Peek" kalır, durumlar arasında mod değişip DT boşalmaz. Neden: "havada lag olmuyor"; Smart havada sadece biri seni görünce zorluyordu. Yerde değişen bir şey yok. |
| Clean shot (no lag while shooting) | Açık | (V1.0) Silahın ateş edebiliyorken (lead 0.15 sn) ve aimbot'un hedefinin kafasına, göğsüne ya da midesine gözünden **Min. Damage'ı geçen** mermi gidiyorsa (aimbot şimdi ateş eder) kendi lag'in durur: Hide shots Break LC, zorlanan DT defensive'i (Smart, Air lag, AI peek, Tick based; Always on o an On Peek), hidden açılar ve havada teleport. Mermi gidince (sürgü, şarjör) hepsi hemen geri gelir. İz 2 tick'te bir atılır, açılınca 6 tick açık kalır (titremesin); hedef değişince sıfırlanır. Bıçak / zeus / bomba ile, dormant hedefte ve hitbox okunamazsa açılmaz. Neden: lag sırasında tickbase kaydığı için mermi sunucuda geçmiyor ya da bir tick sonra başka göz noktasından gidiyor (V1.0 loglarında bütün atışlar `LC` / `FD` iken: `prediction error`, `unregistered shot`, kafaya nişan → göğüs / mide). Göstergede `CLEAN SHOT`, atış satırında `sen ssg08 temiz`. |
| Snipers use DT in the air | **Kapalı** (V1.0) | Açıkken scout / AWP / R8 havadayken DT kullanır, inince yine Hide shots (havada air lag ve teleport onlarda da çalışır). **V1.0'da varsayılan kapalı:** inişteki DT → HS geçişi şarjı sıfırdan başlatıyor; loglarda zıpladıktan sonra peek'te `HS %14 LC` iken (teleport'tan 0.38 sn sonra) kafadan vuruldun. Kapalıyken scout havada da Hide shots'ta kalır ve hareket ettiği için Break LC açıktır (havada LC kırılır, iniş şarjlı). Açmak istersen **Always use recommended settings**'i kapatman gerekir. |
| Defensive during AI peek | Açık | (AI peek açıkken görünür.) AI peek yürürken ve beklerken DT defensive'i zorlanır: düşman seni ilk gördüğünde elindeki kayıt eski ve açıların gizli olur (defensive peek). Atıştan sonra geri dönerken zorlanmaz. Hide shots'ta (scout) Break LC zaten açık; zorlama DT ister. |
| Teleport in air when seen | Açık | Havadayken bir düşman kafanı görünce (ya da birazdan görecekken) exploit doluysa Neverlose'un teleport'u tetiklenir (`rage.exploit:force_teleport`): biriken tick'ler bir anda oynanır, zıplama yönünde ileri sıçrarsın ve düşmanın elindeki kayıt geçersizleşir. **Zıplama başına 1 kez (V1.0):** teleport şarjı harcar ve şarj dolana kadar (~0.26 sn; loglarda 0.21 sn sonra `DT %80`) havada ne defensive ne air lag vardır. v5.4-v5.6'da zıplama başına 5 teleport vardı; loglarda ikinci teleport'tan 0.21 sn sonra `DT %80, DEF yok` iken kafadan vuruldun. Artık tek teleport'tan sonra şarj dolar ve air lag (her tick defensive) devam eder. **İnişe 0.35 sn'den az kaldıysa teleport yok:** şarj inene kadar dolmaz, yere DT'siz inip şarj olurken yerinde donardın. Yatay hız en az 150. Fake duck'ta yok (orada exploit çalışmaz). Hide shots'ta (scout, **Snipers use DT in the air** kapalıyken) **bir kez denenir:** şarj harcanmadıysa Neverlose HS ile teleport yapmıyor demektir; konsola `teleport: Hide shots ile calismiyor` yazar ve o haritada HS ile bir daha denenmez. DT'li silahlarda (rifle, auto, deagle) her zaman çalışır. Konsola `teleport: havada goruldun, DT ile isinlanildi (1. kez)` yazar, vuruldun satırında `tp 0.12s`, atış satırında teleport'tan sonraki 0.3 sn içinde `TP`; inince `teleport: bu ziplamada 1 kez (sarj havada tekrar dolmadi)` gibi bir özet. Teleport sonrası iki atış 10 sn içinde sunucuda geçmezse teleport 10 sn durur. **Not:** teleport seni daha uzağa götürmez; sunucu aradaki konumlarını atlar, düşman seni bir anda ileri sıçramış görür. |
| AI peek (hold Peek Assist) | Açık | **Peek Assist tuşunu basılı tutup hareket tuşlarına basmazsan** script yanları tarar: düşmana dik, sola ve sağa 18 / 32 / 46 / 60 birim. Bir noktaya yürünebiliyorsa (yolda duvar yok, altında zemin var, uçurumdan düşmezsin) ve oradan düşmanın kafasına ya da göğsüne ateş etsen aimbot'un minimum hasarı geçiyorsa (scout / AWP / R8'de canı, yani öldürecek atış), **en yakın** böyle noktaya kendisi yürür. Açı yolda açılırsa orada durur. **v5.4:** v5.3 loglarında 4 peek'in 3'ü 3-8 birim yürünüp `aci kapandi` ile bitti: nokta tek bir taramada görünmüş, hemen sonrakinde kaybolmuştu (düşmanın jitter'ı / hareketi). Artık (1) nokta 2 tick sonra **ikinci taramada da** aynı düşmana aynı tarafta bulunmazsa yürünmez; (2) yürürken tek kötü tarama geri döndürmez, **3 tarama üst üste** olmazsa dönülür; (3) beklerken açı kayarsa (düşman yürüdü) **aynı tarafta biraz ileri gidilir** (başlangıçtan en fazla 74 birim); (4) kafa ve göğsün yanında **mide** de denenir (canı azsa scout'la mide de öldürür). **v5.5:** (5) **başka bir düşmanın da kafanı göreceği noktaya gidilmez** (v5.3 loglarında peek sırasında hedef olmayan bir düşman kafadan vurdu); (6) **düşman defensive'deyken / LC kırarken açı kaybı sayılmaz**: kaydı sahte (v5.4 loglarında defensive kullanan düşmanlara peek'ler `hasar 0/101` ile bitti), kayıt gerçeğe dönünce yeniden bakılır. Yürürken önce asıl hedef noktanın hâlâ öldürecek atış verip vermediğine bakılır; tehdit değişse de aynı düşmana peek sürer; nokta sadece diğer tarafta açık kalırsa yön değiştirmez, geri döner. AI peek yürürken ve beklerken AA peek attığın düşmana döner (kendini bilerek ona gösteriyorsun) ve DT'liyken defensive o seni görmeden başlar (**Defensive during AI peek**). Scout / AWP / R8'de peek her zaman sadece öldürecek atış için atılır (orada düşman seni görecek). **AI peek yürürken Neverlose'un Peek Assist'i geçici olarak kapatılır** (v4.9'da nokta bulunuyordu ama karakter yürümüyordu: tuş basılı ve hareket tuşu yokken Peek Assist seni başlangıçta tutup hareketi eziyordu); tuşun durumu `ui.get_binds()`'tan okunur. Aimbot ateş edince script seni başlangıç noktana kendisi geri yürütür; ateş edilmezse 0.5 sn (R8'de horoz ve isabet için 0.75 sn) bekleyip başlangıç noktana döner. **Aynı düşmana iki peek atışsız biterse** o düşmana Peek Assist tuşuna yeniden basana kadar peek atmaz (v4.7 loglarında aynı düşmana 7 kez boş peek atıldı, her seferinde kendini gösterdin); başka bir düşmanın sayısı ayrı tutulur. Her boş peek'te konsola `ai peek: atis olmadi (17/18 birim gidildi) -> geri` yazar: gidilen mesafe 0'a yakınsa hareketini başka bir şey (ör. Peek Assist'in geri çekmesi) eziyor demektir, bu satırı bana at. Hareket tuşuna bastığın an kontrol sende. DT şarj olurken, Hide shots şarj olurken (V1.0), **silah ateş edemezken** (V1.0: scout / AWP sürgü çekerken, şarjör değişirken; eskiden atıştan 0.8 sn sonra peek başlıyordu ama scout'un sürgüsü 1.25 sn, ateş edemeden görünüyordun), atıştan sonraki 0.8 sn, havada, bıçak/bomba elindeyken, fake duck'ta ve dormant düşmana karşı çalışmaz. **Yukarıdaki düşman (V1.0):** düşman en az 32 birim yukarıdaysa (kutu, balkon) yana adım çoğu zaman açmaz, kenar kafasını kapatır; o zaman **geri-çapraz** noktalar da denenir (log'da `sol-geri 18 birim`). Göstergede `AI PEEK`. Her peek konsola yazılır (aşağıda **AI peek logları**).  Boştayken (peek yokken) Peek Assist tamamen senin. |
| Snipers (SSG08/AWP/R8) | Auto (learn) | Elinde scout, AWP ya da R8 varken exploit seçimi. **Auto (learn)** (varsayılan, v5.6): önce Hide shots; senin maçlarında hangisi kafana daha az mermi yediriyorsa o. v4.7-v5.5'te Hide shots sabitti: v4.6'da öğrenme iki HS isabetinden sonra DT'ye geçmiş ve scout'la ateş ettikten hemen sonra `DT %0` iken vuruluyordun; ama v5.3-v5.5 loglarında HS ile de peek'te ve atıştan 0.06-0.14 sn sonra kafadan vurulmalar sürdü. Artık en az 4 mermi görmeden değişmiyor, karar senin verinle. **Hide shots**: hep HS. **Auto (learn)** nasıl: kafana gelen mermiler (kafadan isabet ya da kafanın yanından ıska) HS ve DT için ayrı sayılır; seçili exploit en az 4 mermi görmeden değişmez, diğerinin oranı (isabet + 2) / (mermi + 4) 0.1 daha iyiyse ona geçer. Seçim değişince konsola `sniper exploit: Hide shots 4/4, Double tap 0/0 kafa isabeti -> Double tap` gibi yazar ve kalıcı hafızaya kaydedilir. Sayılar her seçenekte tutulur (Stats panel'de **SNIPER** satırı). Bıçak, zeus, bomba ve C4'e geçince exploit değişmez, son tuttuğun silahınki korunur (scout → bıçak → scout geçişinde DT/HS kapanıp açılıp DT'yi boşaltmasın diye). Bolt-action tüfek ve R8 DT ile çift atış yapamaz; DT her atıştan sonra boşalıp uzun süre şarj olur ve o sırada ne defensive ne koruma vardır. Hide shots ateş ettiğin anki açını gizler, defensive "Break LC" ile devam eder. Oyun loglarında scout'la ateş ettikten 0.05-0.35 sn sonra, DT %0'dayken kafadan vurulma tekrar tekrar görüldü. `Same as state` ile kapatılır. |
| Safe recharge | Açık | Exploit yeniden şarj olurken oyuncu sunucuda ~14 tick yerinde donar. Şarj iki durumda sıfırdan başlar: ateş ettikten sonra ve fake duck'ı bıraktığında (fake duck'ta exploit çalışmaz; fake duck peek'ten kalkınca hâlâ görüş alanındasın). Düşman kafanı görüyorken (ya da birazdan görecekken) script şarjı bekletir (`rage.exploit:allow_charge`); siperin arkasına geçince dolar. Hep görülüyorsan 1.2 sn sonra yine de şarj olur, exploit'siz kalmazsın. Neden: oyun loglarında peek'te ateş ettikten 0.05-0.36 sn sonra, `DT %0` iken kafadan vurulma tekrar tekrar görüldü. DT'de her zaman çalışır. Hide shots'ta sadece Neverlose'un şarj değerinin HS'de de dolup boşaldığı görüldükten sonra çalışır (değer sadece DT'ye aitse HS'ye hiç karışmaz); o zaman log'da `HS %40` gibi şarj yüzdesi de yazar. Fake duck basılıyken karışmaz. Log satırında `sarj bekle` yazar. Bu Neverlose sürümünde `allow_charge` yoksa sessizce devre dışı kalır. |
| Hidden spin speed | 10 | Hidden yaw `Spin` hızı. |

**Sunucuda geçmeyen atış koruması:** Kendi lag'ın sırasında atılan iki mermi 10 sn içinde bozuk giderse (`iska unregistered shot`, `iska damage rejection` ya da V1.0'dan beri `iska prediction error`), o lag 10 sn durur: script'in zorladığı DT defensive'i (Smart, Air lag, Defensive vs enemy peeks, AI peek), Hide shots'ın Break LC'si ya da (V1.0) havada teleport (teleport'tan sonraki 0.3 sn içindeki atışlar; konsola `teleport 10 sn durduruldu: teleport sonrasi sirasinda 2 atis bozuk gitti`). Konsola `defensive 10 sn durduruldu: zorlanan defensive sirasinda 2 atis bozuk gitti (son: damage rejection)` / `Break LC 10 sn durduruldu: ...` yazar. Atış satırında silahın yanında o anki lag yazar (`sen ssg08 TP`, `sen ssg08 LC`, `sen ak47 DEF`, `sen ssg08 FD`; lag yoksa ve temiz atış açıksa `sen ssg08 temiz`): ıskalar hangi lag'da geliyor, oradan görülür. Fake duck senin tuşun, durdurulmaz. Lag'ın kendi atışlarını bozmasına karşı.

**AI peek logları** (Home → Console → Shot log açıkken):
- Başlarken: `ai peek: sol 32 birim -> isim (hasar 150)`
- Aimbot peek'te ateş ederse sonucu: `ai peek sonucu: isabet head -150 -> isim (30 birim)` ya da `ai peek sonucu: iska (correction) -> isim (24 birim)`
- Ateş edilmezse nedeni ve ne kadar gidildiği: `ai peek: atis olmadi, sure doldu (12/32 birim gidildi) -> geri`. `aci kapandi, hasar 0/101` = açı tamamen kapandı (düşman yer değiştirdi), `hasar 95/101` = sınırdaydı; `aci sadece diger tarafta`, `aci 74 birimden uzakta`, `hedef yok`; sonunda `, dusman defensive kullandi` varsa peek sırasında düşman defensive'e girmişti. Gidilen 0'a yakınsa hareketini başka bir şey eziyor demektir.
- Elinden alınırsa: `ai peek: iptal, hareket tusu` / `iptal, Peek Assist birakildi` / `iptal, kosul degisti`
- Peek sırasında vurulursan: `ai peek: peek sirasinda vuruldun (head -100, isim)`
- Tuşu basılı tuttuğun halde 1 sn'de hiç peek olmazsa nedeni (her basışta bir kez): `ai peek: peek yok, isim icin 60 birime kadar oldurecek atis yok` / `isim icin nokta var ama isim2 de kafani gorurdu` / `DT sarj oluyor` / `HS sarj oluyor` / `silah hazir degil (surgu / sarjor)` / `hedef yok` / `isim buradan vurulabiliyor, aimbot ates etmeli`
- Stats panel'de **AI PEEK** satırı: peek / atış / isabet / boş / vuruldun.

### Builder
Solda **Angles**: `State` listesi ve o durumun AA'sı; sağda **State exploit**: o durumun exploit / defensive / hidden ayarları. `State` listesinden durumu seç. Her durum kendi ayarlarıyla gelir. Hareket durumlarında `Override` kapatılırsa o durum **Global**'in AA ayarlarını kullanır (exploit ayarı yine kendisinden gelir). Varsayılan olarak bütün `Override`'lar açık olduğundan Global'i değiştirmek bir şey yapmaz; tek bir ayarla oynamak istersen durumların `Override`'ını kapat.

| Ayar | Ne işe yarar |
|---|---|
| Yaw mode | `L&R` (varsayılan) ya da `X-Way`. |
| Yaw left / right | `L&R`'de desync sola ve sağa bakarken eklenen yaw. İkisi farklı olunca yaw, body yaw ile **senkron** jitter yapar. |
| Ways / Way 1-5 | `X-Way`'de yaw her flip'te sıradaki açıya geçer (3-5 açı, varsayılan -30 / 0 / 30 / -15 / 15). Desync her flip'te taraf değiştirdiği için açı-taraf eşleşmesi sürekli kayar. |
| Yaw randomize | Her flip'te yaw'a ± bu kadar rastgele açı ekler. **Fake duck'ta varsayılan 20** (dişlideki **Limit randomize** de 10: desync 48-58 arası): fake duck'ta paket ~14 tick boğulu, düşman her pakette tek kayıt görür; her pakette rastgele yaw, desync miktarı ve taraf. v5.3-v5.4 loglarında fake duck'ta kafadan vurulmalar sürdü; sabit yaw'da tek bilinmeyen desync tarafıydı. |
| Yaw modifier / offset | Neverlose'un kendi modifier'ları (Center, Offset, Random, Spin, 3-Way, 5-Way). Dişliden randomize. |
| Body yaw | `Jitter`: taraf lua tarafından paket döngüsüne göre sırayla çevrilir. `Random`: taraf her paket döngüsünde (Jitter delay kadar) rastgele seçilir; Fake duck ve Safe head'de varsayılan. `Static`: Static inverter'a göre. `Off`: desync yok. Dişliden: Avoid overlap, body freestanding, delay ve limit randomize. Jitter'lı durumlarda **Delay randomize varsayılanı 1**: taraf her dönüşte 1 ya da 2 paket tutulur. Tam sırayla dönen jitter'ı resolver'lar yakalar (örnek resolver son 4 açı değişiminin 3'ü yön değiştiriyorsa "jitter" deyip tarafı eşliyordu); rastgele bekleme bu sırayı bozar. |
| Jitter delay | Kaç paket döngüsünde bir taraf değişsin. Sadece DT/HS aktifken uygulanır. |
| Left / Right limit | Desync miktarı (0-60). |
| Exploit / Defensive / Hidden | Yukarıdaki tabloya bak. |

### Ragebot
| Ayar | Varsayılan | Ne işe yarar |
|---|---|---|
| Adaptive resolver | Açık | Düşman başına çalışan resolver katmanı (aşağıya bak). |
| Head unless body kills (snipers) | Açık | Scout / AWP / R8'de Neverlose'un Min. Damage'ı **101** (Neverlose'da 100 üstü "can + fazlası", yani can + 1) ve Body Aim **Prefer** yapılır; aimbot'un az önce (1.5 sn) ateş ettiği düşmanı gövde öldürüyorsa **Force** (V1.0: o düşmanla zaten çatışıyorsun, ikinci atış garanti gövdeye). İkisi de **hedeften bağımsız**: aimbot hangi düşmana ateş ederse etsin sadece öldürecek atış yapar (tam canlıya kafa, canı azsa gövde). Neden: eskiden tahmin edilen tek hedefe göre ayarlanıyordu ve aimbot başka düşmana ateş edince loglarda tam canlı düşmana `BA Force \| MD 31` ile 40'lık gövde atışı yapıldı. **Sadece bir düşman kafanı görebiliyorken** (ya da birazdan görecekken) geçerli: seni geri vuramayacaksa uzaktan ince bir boşluktan görünen kol / gövdeye atış bedava hasardır, o zaman kendi Min. Damage'ın kullanılır ("uzakta ince yerlerden sıkamıyor"). Senin Min. Damage'ın zaten 101 ya da üstüyse dokunulmaz; baim tuşun (Body Aim'e bağlı Force bind'i) basılıyken ezme bırakılır. Göstergede `HEAD` (tahmin edilen hedefin gövdesi öldürüyorsa `BAIM`), atış satırında `MD 101`. |
| Snipers: lethal body on fake records | Açık | (V1.0) Scout / AWP / R8 sadece öldürecek atış yaparken hedefin kaydı defensive'de (sahte: gördüğümüz en yeni kayıttan eski, açılar hidden) **ve gövde öldürüyorsa** hitbox'lar göğüs + mide: kafa yerine öldürecek gövde, kafa atışı gerçek kayda gider. En fazla 12 tick, sonra 0.5 sn serbest. **Gövde öldürmüyorsa (tam canlı düşman) dokunulmaz, kafaya ateş edilir:** eskiden bu durumda gövde listesi hiç atış getirmiyordu; loglarda `sahte kayitta ... sniper sadece govdeye` satırları ve "önüme eğiliyor, kafasını net görüyorum, sıkmıyor". Konsola en fazla 5 sn'de bir `resolver: isim sahte kayitta (defensive): sniper oldurecek govdeye, kafa gercek kayda`, göstergede `DEF BODY`. |
| Smart body aim | Açık | Aimbot'un hedefine göre Neverlose'un Body Aim'ini seçer (göstergede `BAIM` = gövde tercih ediliyor). **1.** Tek gövde mermisi öldürüyorsa `Force` (resolver'a bağlı olmayan kesin öldürme). Loglarda düşman 31 candayken `Prefer` ile Neverlose yine kafaya nişan alıp resolver yüzünden ıskaladı. Sadece kafa görünüyorsa `Force` hiç ateş ettirmez: düşman seni görürken yarım saniye o hedefe ateş edilmediyse `Prefer`'e inilir, bir sonraki atışta yeniden `Force` denenir. **2.** DT doluyken iki gövde mermisi öldürüyorsa `Prefer` (oto: zırhlıya göğüs ~65 × 2; deagle ~48 × 2 = 90 canın altında). **3.** Scout / AWP / R8'de gövde öldürmüyorsa senin `Prefer`'in kaldırılıp `Default` yapılır ki aimbot kafayı geçmesin (bu silahlarda DT ile ikinci mermi yok). **4.** Resolver o düşmanda, o hareket durumunda iki kez yanıldıysa (seviye 2) `Prefer`: gövde hitbox'ları desync'le kafa kadar kaymaz. **5.** Hedef o an defensive kaydındaysa (spin kafayı gövdenin etrafında döndürür, gövde yerinde kalır) ya da fake duck yapıyorsa (kafa yüksekliği kayıttan kayda değişir) `Prefer`. Scout / AWP / R8'de değil: öldürmeyen gövde vuruşunun karşılığında kafadan yersin. Hasar önce **gerçek mermi iziyle** ölçülür (gözünden düşmanın göğsüne: duvar, mesafe, zırh dahil; V1.0: loglarda canı 45 düşmana deagle'la `BA Force` ile duvardan 26-27'lik göğüs vuruşları geldi, tablo yakında ~58 diyordu ve zorlanan gövde kafa atışını kaybettirdi); iz atılamazsa CS:GO silah değerlerinden (scout, AWP, R8, SCAR-20, G3SG1, Deagle) zırh ve mesafeyle düşüş dahil hesaplanır; göğüs ölçü alınır, çünkü aimbot gövdeye ateş edince mideye değil göğse gelebilir. Senin kendi `Force`un (baim tuşu) hiç değiştirilmez. Neden: oyun loglarında scout'la tam canlı düşmanlara 87-93 gövde vuruşları vardı; düşman hayatta kalıp kafadan vuruyordu. |
| Shot log (Home → Console) | Açık | Her aimbot atışını tek satır yazar: `atis: isim \| Air \| HP 100 \| hedef head 98 \| iska correction \| SP Force \| BA Default \| MD 100 \| bt 2t \| hc 81% \| sen ssg08 \| AA jit 62, def` → düşman, ateş anındaki durumu ve canı, aimbot'un hedeflediği bölge ve beklediği hasar, sonuç (isabet bölge/hasar ya da ıska nedeni), ateş anındaki Safe Points, Body Aim ve Min. Damage (`MD 100`), backtrack (tick), isabet şansı, senin silahın (yanında o anki kendi lag'ın: `TP` = havada teleport'tan sonraki 0.3 sn, `DEF` = script'in zorladığı DT defensive'i, `LC` = Hide shots Break LC, `FD` = fake duck) ve düşmanın ateş anındaki AA'sı (`AA jit 62` = gerçek güncellemeler arası ortalama 62° yaw değişimi, `AA statik`, yeterli veri yoksa `AA ?`; `def (sahte kayit)` = ateş edilen kayıt defensive kaydıydı, ıska resolver'a sayılmaz; `def` = son 16 tick'te defensive kullandı; `LC` = lag compensation kırıyordu). Resolver'ı ayarlamak için bu satırları bana at. |

**Nasıl çalışır:** Açıları yine Neverlose'un kendi resolver'ı çözer. Bu katman her aimbot atışının sonucuna bakar (Neverlose'un `aim_ack` olayı). `correction` = mermi isabet edecekti ama resolver düşmanın açısında yanıldı. Seviye **düşman başına ve düşmanın hareket durumu başına** (`Standing` / `Moving` / `Crouch` / `Air` / `Fakeduck`) tutulur: AA lua'ları her durumda farklı ayar kullanır, havada çözülemeyen biri yerde çözülebilir. Atışın hangi durumda yapıldığı ateş anında kaydedilir; sonuç geldiğinde düşman inmiş ya da eğilmiş olsa bile ıska doğru duruma yazılır. O durumda son 4 atıştaki `correction` ıskası sayısı seviyedir:

| Seviye | Ne zaman | Safe Points |
|---|---|---|
| 0 | Resolver ıskası yok | Senin kendi ayarın |
| 1 | 1 resolver ıskası, ya da o durumda hiç sonuç yokken düşmanın AA'sı jitter'li | `Prefer`: güvenli nokta varsa ona ateş eder |
| 2 | 2+ resolver ıskası | `Force`: sadece desync hangi taraftaysa da isabet eden noktalara ateş eder. DT'li silahlarda Body Aim de `Prefer` olur (**Smart body aim**). Scout / AWP / R8 sadece öldürecek atış yaparken ve hedefin gövdesi görünmüyorken (sadece kafa; V1.0) `Prefer`'de kalır: kafada güvenli nokta yok, `Force` atışı tamamen keserdi |

- İsabetler son 4 atışa girip eski ıskaları dışarı ittikçe seviye kendiliğinden düşer. Spread, tahmin hatası, backtrack gibi resolver dışı ıskalar sayılmaz.
- **Düşman takibi:** Script her düşmanın sunucudan gelen simülasyon zamanını, konumunu ve bakış yönünü her tick izler. Simülasyon zamanı gördüğümüz en yüksek değerin gerisine düştüyse düşman **defensive** kullanıyordur ve o kayıt sahtedir (açılar hidden, lag compensation bozuk); iki güncelleme arasında 64 birimden fazla yer değiştirdiyse **LC kırıyordur** (eski kayıtlara backtrack geçersiz). Atış anında düşman LC kırıyorduysa ya da ateş edilen kayıt defensive kaydıysa (V1.0) gelen `correction` ıskası resolver'ın hatası sayılmaz, seviye yükselmez (safe point bunu düzeltmez, sadece kafa atışını azaltırdı); Stats panel'de `OTHER`'a sayılır. Sadece o an sahte olan kayıt sayılmaz: son 16 tick'te defensive kullanmış ama şu an gerçek kayıttaki düşmana ıska normal sayılır (loglarda neredeyse her atışta `def` vardı; hepsi sayılmasaydı resolver hiç öğrenmezdi). Jitter ortalaması sadece gerçek kayıtlardan hesaplanır (defensive kaydındaki hidden yaw sayılmaz).
- **Jitter ön bilgisi (daha hızlı):** Düşmanın son güncellemeler arasındaki ortalama yaw değişimi 35° ve üstüyse (jitter ya da spin AA) ve o durumda hiç sonuç yoksa, ilk atıştan `Prefer` kullanılır; ıska beklenmez. Neverlose'un resolver'ı en çok jitter'da yanılır. Karar 60 saniye hatırlanır: loglarda aynı düşmanın ortalaması 21 ile 48 arasında gidip geliyordu ve ön bilgi açılıp kapanıyordu. O durumda ilk sonuç gelince gerçek veri geçerli olur (kafaya isabet ederse `Default`'a döner). Konsola her düşman için bir kez (harita başına) `resolver: isim jitter 62° -> safe points Prefer (veri yok, on bilgi)` yazar, göstergede `RES 1 JIT`.
- **Fake duck yapan düşman (v5.5):** yerde, eğilme miktarı yarım ve paketleri boğulu (en az 6 tick) iki güncelleme üst üste görülen düşman ayrı durumdur (`Fakeduck`; atış satırında `Fakeduck`, göstergede `FD`). Eğilme miktarı sürekli değiştiği için eskiden `Crouch` ile `Standing` arasında gidip gelip iki durumun verisini de bozuyordu. O durum kendi verisiyle öğrenir (V1.0'da veri olmadan `Prefer` yok); DT'li silahta gövde tercih edilir ("fake duck'taki adamları vuramıyorum").
- **Bizim numaralarımıza karşı:** rastgele desync tarafı ve anti-brute (ıskadan sonra taraf değiştirme) → seviye 1-2 safe point (her iki tarafta da isabet eden noktalar); jitter → ilk atıştan `Prefer` (jitter sadece gerçek kayıtlardan ölçülür); defensive / gizli açılar / spin → sahte kayda giden ıska öğrenilmez, DT'li silahta gövde; LC kırma / havada teleport → o ıskalar öğrenilmez; fake duck → ayrı durum (kendi verisi) + gövde. Atış bekletilmez.
- **Kafaya nişan alınıp başka yere gelen isabet resolver'a isabet sayılmaz** (loglarda `hedef head 110 | isabet chest -28`): mermi resolver'ın kafa sandığı yerden geçip gövdeye girdi, yani kafanın yeri tutmamış olabilir. Böyle isabetler seviyeyi düşürmez. Boyna nişan alıp kafaya gelen ya da gövdeye nişan alıp kola gelen isabetler normal sayılır.
- Düşmanın o anki durumunda hiç sonuç yoksa diğer durumlardaki son sonuçlar ön bilgi olur, ama en fazla `Prefer`.
- **Force takılırsa:** `Force`'ta düşmanın güvenli noktası yoksa aimbot hiç ateş etmez (ve sonuç gelmediği için seviye de düşmez). Düşman seni görürken yarım saniye boyunca ona hiç ateş edilmediyse `Prefer`'e inilir ve konsola `safe point bulunamadi` yazılır; o durumun bir sonraki atış sonucu seviyeyi yeniden belirler.
- Seviye **sadece o düşmana ve onun o anki durumuna karşı** uygulanır: aimbot az önce (1.5 sn içinde) kime ateş ettiyse onunki; yoksa kafanı gören düşmanınki (aynı görüş hattından sen de onu vurursun; AA'nın baktığı tehdit seni görmüyor ama yandan biri görüyorsa o); kimse görmüyorsa tehdidinki. Göstergede seviye ve neden yazar: `RES 2 AIR` = düşman havadayken iki kez yanıldı (`STAND` / `MOVE` / `DUCK` / `AIR` / `FD`), `RES 1 JIT` = jitter ön bilgisi.
- Senin kendi Safe Points ayarın hiç düşürülmez (zaten `Force` ise dokunulmaz). Body Aim'e sadece **Smart body aim** dokunur; kendi body aim tuşun (`Force`) aynen çalışır.
- Seviye **Steam ID ile** tutulur: round'lar arası ve harita değişince de kalır (HvH sunucularında oyuncular harita değişince kalır, slot numaraları değişir). Steam ID'si olmayan botlar isimle tutulur. En fazla 64 oyuncu hatırlanır; dolunca en uzun süredir görülmeyen unutulur. **Forget learned enemies** düğmesi hepsini siler.
- **Kalıcı hafıza:** HvH sunucularında aynı oyuncularla tekrar tekrar karşılaşırsın. Steam ID'si olan oyuncuların resolver sonuçları ve anti-brute fazı Neverlose'un `db` deposuna yazılır; oyunu kapatıp açınca da hatırlanır. Botlar ve Steam ID'siz oyuncular yazılmaz. Yazma ağır bir işlem olduğu için round başında en fazla dakikada bir, harita değişirken ve script kapanırken yazılır; okuma sadece script yüklenirken bir kez yapılır. Bozuk ya da eski biçimli kayıtlar atlanır.
- **Neden düşmanın açısını Lua'dan ezmiyor:** Neverlose'un açık Lua API'si sadece gövde dönüş parametresini (`m_flPoseParameter[11]`) yazabiliyor; modelin ayak yönü Neverlose'un kendi çözümünden geliyor ve ikisi tutmayınca hitbox'lar yeni bir yanlış açıya kayar. Ayak yönünü yazmak için FFI ile oyun belleğinde sabit ofsetlere yazmak gerekiyor: bu sadece tek bir `client.dll` sürümünde geçerli ve Neverlose'un atış kayıtlarına etkisi Lua'dan doğrulanamıyor (bunu yapan örnek resolver'ın kendi başlığında da "UNVERIFIED" yazıyor). Bu yüzden açıyı Neverlose'a bırakıp, onun yanıldığı düşmanda ve durumda güvenli noktaya geçmek daha sağlam.
- **Başka bir resolver script'iyle birlikte çalıştırma** (ör. kenar çubuğundaki `RESOLVER`). İki script aynı ayarlara ya da animasyonlara karışırsa hangisinin işe yaradığı anlaşılmaz.

### Visuals
Nişangahın altında: desync çubuğu, aktif durum, DT / HS / FS / DEF / VIS, anti-brute fazı (`BRUTE n`), resolver seviyesi ve nedeni (`RES 2 AIR`, `RES 1 JIT`) ve gövde vuruşu öldürüyorsa `BAIM`, scout / AWP / R8'de sadece kafa (öldürecek atış) aranıyorsa `HEAD`, AI peek bir noktaya yürüyorsa `AI PEEK`, hedefin kaydı sahte ve sniper sadece gövdeye ateş ediyorsa `DEF BODY`, silahın ateş edebiliyor ve hedef vurulabilir olduğu için kendi lag'in durduysa `CLEAN SHOT`, açıktayken bir düşman sana peek atıyor ve defensive ona karşı zorlanıyorsa `ANTI-PEEK`. Yanlarda manuel oklar ve desync tarafı. Renkler ayarlanabilir; dürbünle bakarken indikatör kenara kayar.

- **DT** / **HS**: beyaz = şarjlı, turuncu = şarj oluyor (ya da Safe recharge bekletiyor), soluk = kapalı. HS'de turuncu sadece şarj değeri HS'yi takip ediyorsa görünür.
- **DEF**: renkli = defensive penceresi şu an gerçekten açık, beyaz = script defensive'i şu an zorluyor (Smart, HS'de Break LC) ya da bu durumda sürekli açık, soluk = Neverlose'un peek tespitine bırakıldı. Pencere tickbase'den iki yolla tespit edilir: tickbase gördüğümüz en yüksek değerin gerisine düştüyse ya da DT doluyken iki paket arasında geri gittiyse veya 1'den fazla ileri sıçradıysa.
- **VIS**: renkli = tehdit ya da başka bir düşman kafanı şu an görüyor, beyaz = tehdit birazdan görecek, soluk = görmüyor.

| Ayar | Varsayılan | Ne işe yarar |
|---|---|---|
| Hit log (Home → Console) | Açık | Seni vurunca konsola yazar. Örnek: `vuruldun: head -293 ssg08 \| Peek \| faz 1 \| sag 58 \| DT %40, DEF yok, atis 0.12s, mod 0.05s \| sen r8 \| isim` → bölge, hasar, düşmanın silahı, durum, mermi atıldığı andaki anti-brute fazı, desync tarafı ve miktarı, DT durumu (`dolu` / şarj yüzdesi / `yok`, HS'de şarj biliniyorsa `HS %40`, script'in Break LC'si açıksa `HS LC`; yanında `(bind)` yazıyorsa o exploit'i script değil senin kendi bind'in belirliyor), defensive penceresi o an açık mıydı (`(zorla)` = Smart o an defensive istiyordu; `DEF yok (zorla)` görürsen zorlama işe yaramamış demektir, bana at), Safe recharge şarjı bekletiyor muydu (`sarj bekle`), kendi son atışından bu yana geçen süre (5 sn'den eskiyse `atis yok`), havada teleport'tan bu yana geçen süre (`tp 0.12s`, son 2 sn) ve script defensive modunu az önce değiştirdiyse ne kadar önce (`mod`, sadece son 2 sn), senin o an tuttuğun silah, en sonda parantez içinde saldıran: hareket durumu, AA'nın o an döndüğü düşman mı (`AA hedefi` / `AA hedefi degil` / `AA hedefi yok`) ve script'in izlerine göre kafanı ne kadar süredir görüyordu (`gordu 0.31s`; `gormedi` = izler görmedi: duvarın arkasından ya da diğer düşmanlar sırayla kontrol edilirken sıra ona gelmeden vurdu). Kafanın yanından geçen ıskaları da aynı bilgilerle yazar. Molotof, yangın ve el bombası hasarı yazılmaz ve istatistiğe girmez; bıçak ve zeus hasarı yazılır ama istatistiğe ve anti-brute'a girmez. |
| Round özeti | Hit log açıkken | Her round başında önceki round'da sana gelen mermilerin tek satır özeti: `round ozeti: 4 mermi, 3 kafa \| Peek 2/2, Standing 1/2 \| kafa fazlari 1:2 4:1 \| HS 3, DT 1 \| gormedi 2` → mermi ve kafa sayısı, durum başına kafa/mermi, kafa isabetlerinin geldiği anti-brute fazları, o an açık exploit, script'in izlerinin görmediği saldırılar. AA'yı tahminle değil bu satırlarla ayarlamak için: birkaç round'un özetini bana at. |
| Stats panel | Kapalı | Ekranın solunda her durum için `isabet / kafa / ıska / DT / DEF`. Sen ateş etmezken (atıştan sonraki 1 sn ve Safe recharge'ın bilerek beklettiği süre hariç): **DT** = DT'nin yüzde kaç dolu olduğu (düşükse o durumun ayarları DT'yi boşaltıyor), **DEF** = exploit hazırken defensive penceresinin yüzde kaç açık olduğu ("Smart" ya da "Always on" bir durumda düşükse defensive gerçekten çalışmıyor). Altında **AIM** satırı: senin aimbot atışların, isabetler ve ıskaların nedeni (`CORR` = resolver, `SPREAD` = isabet şansı, `OTHER` = tahmin hatası, backtrack, kayıtsız atış vb.). `CORR` yüksekse resolver, `SPREAD` yüksekse hit chance sorunu vardır. Altında (V1.0) `LAG x / y   TEMIZ x / y`: kendi lag'in (DEF / LC / FD / TP) açıkken ve lag'siz giden atışların isabet / atış sayısı (ölüm ıskaları sayılmaz). En altta **AA FAZ** bölümü: her hareket grubu için (`YERDE`, `HAREKET`, `PEEK`, `HAVA`) her anti-brute fazında kafana gelen mermilerden kaçı kafadan isabet etti (`0* 2/9   1 0/3 ...`; `*` = o grupta verisi olmayan düşmanlara uygulanan, en az vurulan faz). **SNIPER** satırı: scout/AWP/R8'de Hide shots ve DT ile kafana gelen mermiler (`*` = şu an seçili). AI peek kullanıldıysa **AI PEEK** satırı: peek / atış / isabet / atışsız biten / peek sırasında vurulma. Ölünce de görünür. |
| Resolver panel | Açık | (Visuals sekmesinin sağ sütunu.) **Sadece yazı** (kutu, çubuk, arka plan yok; gölgeli Verdana): o anki hedefin (aimbot'un hedefi, yoksa tehdit) **canlı çözüm yüzdesi** büyük ve renkli (kırmızı → sarı → yeşil), yanında adı; altında küçük `COZUM   HIT 67%   2/3` = **canlı isabet şansı** ve resolver'a bağlı isabet / atış. Sayı her tick hesaplanır ve yumuşakça kayar: başlangıç o düşmana geçmiş resolver sonuçları (isabet / isabet + `correction`; veri yoksa %80 ön bilgi, V1.0: loglardaki gerçek orana göre), üstüne düşmanın o anki durumu: kaydı sahte / defensive'de ×0.5, LC kırıyor ×0.6, jitter arttıkça düşer (120°'de ×0.8), havada ya da fake duck ×0.9, uzakta (1500+ / 2500+ birim) ×0.92 / ×0.85, safe point `Prefer` / `Force` biraz artırır. HIT = canlı çözüm × spread'le ıskalamama × resolver dışı ıskaların (sunucu reddi, tahmin hatası, sahte kayıt) olmama oranı (V1.0: oranlar gerçek sonuçlardan; düşmanın az atışı tüm düşmanların oranına doğru çekilir, ön bilgi spread %2, diğer %8; veri yokken HIT ≈ çözüm × 0.9). Eskiden Neverlose'un hit chance'i ve düşmanın ham oranı çarpılıyordu: 2 atışta 1 tahmin hatası HIT'i yarıya indiriyordu. **Not:** Neverlose'un kendi resolver'ının içi Lua'ya açık değil; bu, gördüklerimizden canlı bir tahmin. Hedef yoksa `--   hedef yok`. Çözüm sayıları Steam ID ile kayıtlı hafızaya yazılır; spread / diğer oranları oturumluk. **Menü açıkken yazının etrafında ince bir çerçeve çıkar: fareyle tutup sürükleyerek taşınır, sağ alt köşedeki üçgen tutamaç sürüklenerek büyütülür / küçültülür** (%70-200, font da büyür). Yeri ve boyutu config'e kaydedilir; dişlideki **Size**, **Position X / Y** (ekranın binde biri) ile de ayarlanır. Sürüklerken tıklama menüye ya da oyuna geçmez. |

## Vuruluyorsan ne yapmalı

Hiçbir anti-aim seni vurulmaz yapmaz. İyi resolver'lar ve baim yine vurur. Ama şunlar çok fark eder:

- Önce varsayılanlarla oyna. **Stats panel**'i aç ya da konsoldaki `vuruldun:` satırlarına bak: hangi durumda kafadan vurulduğun orada yazıyor. Sadece o durumu değiştir. Paneli ya da birkaç satırı bana atarsan birlikte ayarlarız.
- **Kafadan vuruluyorsan** o durumun yaw left/right değerlerini değiştir (ör. -23/51 yerine -35/40), `Jitter delay`'i 2-3 yap ya da biraz `Yaw randomize` ekle.
- **Havada vuruluyorsan** Air durumunda hidden yaw'ı `Random` ya da `Sideways` dene.
- **Duvar dibinde bekliyorsan** freestanding ya da manuel yaw kullan.
- **Fake duck'ı bilerek kullan (ayrı tuş, hold).** Fake duck basılıyken Neverlose DT ve HS'yi kapatır; scout'ta Hide shots ve bütün defensive'ler de gider (log'da `FD, DT %0 (bind)`). Bunny hop + FD ile ani peek gibi bilerek kullanıyorsan (V1.0'dan beri script FD'yi havada / koşarken bırakmıyor) sorun değil; ama eğilme tuşuna (CTRL) bağlıysa her eğilişte DT'siz kalırsın. Ayrı bir tuşa (ör. mouse yan tuşu) ve "hold" moduna al.
- Geniş peek atma; quick peek (Peek Assist) kullanınca Peek durumu ve defensive kendiliğinden devreye girer.
- **Backtrack'ten vuruluyorsan:** Hareket ederken scout'ta (HS) Break LC artık sürekli açık. DT'li silahlarda Smart defensive görüldüğün anda açılır. Yerinde dururken backtrack zaten kafanın aynı yerine düşer; orada korunma AA ve freestanding'dir. Fake latency'li ve anti-defensive'li bir rage'i hiçbir lua tamamen durduramaz.
- **Daha iyi vurmak için:** Sihirli bir exploit yok. İşe yarayanlar: **AI peek** (Peek Assist tuşunu basılı tut, hareket tuşlarına basma: script öldürecek atışın olduğu en yakın noktaya yürür), Neverlose'un **Fake latency**'si (Misc; loglarda `bt 27t` gibi uzun backtrack'ler zaten var, yani açık), quick peek + defensive (önce sen görürsün, ateş edip geri çekilirsin), scout'ta sadece öldürecek atış (**Head unless body kills**) ve resolver'ın öğrenmesi (aynı düşmanlarla oynadıkça hafıza dolar).
- **Fake duck'tan ateş etme** seni gören bir düşmana: fake duck'ta HS/DT çalışmaz, ateş anındaki açın açıkta kalır (loglarda FD atışından 0.06-0.21 sn sonra kafadan vurulma).

## GameSense edition (`Nykle.win.gamesense.lua`)

Aynı özelliklerin GameSense (CS:GO) Lua API'sine taşınmış hali; oyunda `Nykle_win_gamesense.lua` adıyla yüklenir (GameSense script adındaki fazladan noktaları sevmez). Farklar ve kurulum dosyanın başındaki yorumda. Oyun logları (`nykle_log.txt`, Home → Console → Copy all logs) bu sürümün geliştirme verisi; V1.0.16–1.0.21 loglarının analizi `LOG_ANALIZI_GS_1.0.16-21.md`'de.

**V1.0.22'de ne değişti** (10 961 satırlık logdan):

| Değişiklik | Neden |
|---|---|
| **Safe recharge** Peek'te ve yürürken (> 100 birim/sn) beklemez; bekleme üst sınırı 1.2 → 0.5 sn | Beklerken DT kapalı ve defensive yok: `sarj bekle` ile 179 mermi / 70 kafa yendi, 57'si Peek'te, çoğu atıştan sonraki 0.3 sn içinde. |
| **Wait for real record** varsayılan **açık**; ilk gerçek kayıttan sonra 3 tick daha beklenir | Sahte kayda giden 178 atış %57 tuttu (correction %25), gerçek kayda giden %75 (%9); defensive bittikten 0–2 tick sonra giden atış da %58. Kurallar aynı: düelloda / görülürken beklenmez, en fazla 14 tick, sonra 32 tick serbest. |
| Yeni seçenek **Body 70+ while an enemy sees you** (Ragebot → Resolver, varsayılan **kapalı**) | 94 ölümün 2 sn öncesinde `sikmadi` vardı, 71'inde gövdeye 70+ vurulabilirdi; 369 kafa ölümünün 183'ünde hiç ateş edilmemişti. Min. damage 100 kalsın isteği için kapalı; açarsan biri kafanı görürken ve kafa öldüremezken gövde 70+ için Min. damage geçici 70. |
| `vuruldun:` satırında `gormedi` yanına iz sonucu: `(iz: su an goruyor / duvardan goruyor / kapali)` | 85 kafa mermisi "gormedi" idi (50'si duvardan); görüş takibinin neyi kaçırdığı artık logdan okunur. |
| `dbg sikmadi` yeni sebepler: `aimbot tehdidi baska`, `gercek kayit bekleniyor (whitelist)`, `safe point Force` | 22 `sebep bilinmiyor`. |

**V1.0.23: anti-aim** (aynı log, sana gelen 1 100 mermi):

| Değişiklik | Neden |
|---|---|
| **Defensive vs enemy peeks** silahın hazırken de: seni yeni gören / sana peek atan düşmana karşı dururken, eğilirken ve freestanding'de de DT defensive zorlanır (temiz atış varsa yine kalkar) | Kafa mermilerinin %42'si düşman seni gördükten < 0.1 sn sonra geldi (1 sn+ görenlerde %17); dururken %53, freestanding'de %54. Eskiden sadece silah ateş edemezken zorlanıyordu. |
| İki yeni anti-brute fazı: **6** desync 32°, **7** desync 41° + taraf çevirme | 0–5 fazlarının hepsi aynı kafa oranını yedi (%32–43): desync hep 58–60 olunca resolver'ın ±58 tahmini yazı-tura. Düşük desync'te iki tahmin de kafayı bulmaz. Hangisinin işe yaradığını grup başına öğrenme seçer; Stats → AA FAZ'da yeni sütunlar. |
| **Kötü bilinen faz atlanır:** bir grupta ≥ 12 mermi ve ≥ %55 kafa yiyen faz, düşman başına ilerlemede ve öğrenilen başlangıçta atlanır (panelde `x`) | Havada faz 1: 16/25 = %64 kafa (faz 0: %35); düşman başına ilerleme yine de ona dönüyordu. |

**V1.0.24** (V1.0.23'ün ilk logu: 12 dk DM, 70 mermi):

| Değişiklik | Neden |
|---|---|
| **Snipers** varsayılanı `Same as state` (= DT); `Auto (learn)` seçilirse eşikler yüksek (öteki ≥ 16, kendisi ≥ 24 mermi, fark 0.15) | Öğrenme 60 mermilik sayımıyla oturumu Hide shots'a çevirdi; 1 100 mermilik logda HS'de kafa %45, DT'de %36 (havada %76 / %52) ve HS ile zorlanan defensive, teleport, peek koruması çalışmıyor. |
| Düşmanın kaydı sahteyken (defensive) görüş sisteminin ileri bakışı kaydın gerisi kadar uzar (0.2 + ≤ 0.25 sn) | `gormedi` kafa mermilerinin 22/23'ünde vurulma anında onun gözünden iz kapalıydı, 13'ünde kaydı sahteydi: defensive'li düşman gördüğümüz yerden değil ilerisinden ateş ediyor. |

**V1.0.25** (V1.0.24'ün ilk logu: 14 dk DM, 75 isabet / 48 kafa):

| Değişiklik | Neden |
|---|---|
| **Smart** defensive 1800 birim içinde bir düşman varken de zorlanır (görünmesi beklenmez); Standing / Crouching / Freestanding / Manual varsayılanı `On peek` → `Smart` (hidden açı yine yok) | Kafa mermilerinin 36'sında saldıran `gormedi`, 32'sinde vurulma anında bile iz kapalı, 16'sında kaydı sahte: defensive'li düşman ekranda görünmeden ateş ediyor (245–1991 birimden, yarısı 1600+). Defensive açıkken kafa %38, kapalıyken %53–69. |

**V1.0.26** (V1.0.25'in logu: 10 dk, 68 isabet / 34 kafa, 41 / 46):

| Değişiklik | Neden |
|---|---|
| **DT pair counts as lethal** (Ragebot → Resolver, açık): scout DT iki mermi atar; DT doluyken gövde × 2 ≥ can (ve tek mermi ≥ 60) ise atış "öldürücü" sayılır, Min. damage geçici olarak gövde hasarının 1 altına iner. DT boşken kural eskisi gibi (can + 1). | Beş logda da en büyük ölüm kaynağı: gövdeye 70–87 vurabilirken kafa beklemek (son oturumda 12 ölümün 11'i). "Min. damage 100 = sadece öldürecek atış" şartı korunur: çift öldürüyor. |
| Temiz atışın atış sonrası tutması 14 → 6 tick | Kafa mermilerinin 12'si kendi DT atışından 0.4 sn içinde; 14 tick, DT şarjının geri gelişi kadar sürüp defensive'i geciktiriyordu. DT'nin ikinci mermisi 1–2 tick sonra gider. |

**V1.0.27** (piyasadaki lualarla karşılaştırma, `LUA_KARSILASTIRMA.md`):

| Değişiklik | Nereden / neden |
|---|---|
| Anti-brute **faz 8**: taraflar eşit sürmez (bir taraf 2 paket uzun, uzun taraf her 4 çevirmede değişir); öğrenme seçer | abyss lua'sının "Switch" body jitter'ı; "her N tick'te bir çeviriyor" diye brute eden resolver periyodu tutturamaz |
| **In-air hit chance (snipers)** (Exploits → Defensive, varsayılan 40; V1.0.47'den beri 0 = kapalı): havada sniper tutarken Minimum hit chance geçici bu değer | abyss'in durum başına hit chance'i; 254 `sikmadi`'nin 75'i "sen havadasın" (hepsi hc 55), havadan giden atışlar %67–89 tuttu |

**V1.0.29 — kendi resolver** (Ragebot → Resolver → **Own resolver (LBY / cover side, measured vs GS)**, açık):

GameSense Lua'da açıyı doğrudan belirleyen tek araç oyuncu listesindeki Force body yaw. Eskiden hipotezler ancak Force'ta 3+ ıskadan sonra sırayla deneniyordu; şimdi taraf bilgisi olan düşmanda **ilk atıştan** itibaren ölçülen bir "kol" seçilir:

| Kol | Ne yapar |
|---|---|
| `gs` | GameSense'in resolver'ı (açı yazılmaz) — taban, her zaman aday |
| `lby+` / `lby-` | Duran düşmanda göz yaw ile LBY farkı ≥ 35°: gerçek ayak yaw'ı LBY tarafında. `+` teorik yön, `-` tersi (GameSense'in işaret kuralı belgesiz; iki kol da ölçülür, kazanan kalır) |
| `wall+` / `wall-` | Duvarlı düşman: tek tarafı kapalıysa freestanding gerçek kafayı oraya saklar |

Ölçüm: her uygun atış (kafaya nişan, backtrack / teleport / extrapolation yok, hit chance ≥ eşik) kolun hesabına yazılır: isabet = isabet, resolver ıskası (`correction`; sahte kayıt / LC hariç) = ıska. Skor `(isabet + önbilgi × k) / (atış + k)`: genel sayım (k = 8, kalıcı hafıza) ve düşman başına sayım (k = 4, genel orana çekilir). En iyi kol seçilir; **Own resolver exploration** (%15) oranında en az denenmiş kol denenir (30 atışı geçen kol artık denenmez). Kol kaybederse kendiliğinden `gs`'ye döner. Jitter'lı / kararsız desende ve havada kol yok (Force safe point). Karar düşman başına bir kez verilir, atış sonucu gelene (ya da 10 sn) kadar tutulur.

Logda: `atis: ... | res lby+` (kol), `resolver: X Standing | bizim lby+ (lby L 50°) body yaw 58° | kollar: GS 12/20 LBY+ 5/7 ...`; Stats panelinde `RESOLVER` satırı; hafızada kol sayımları.

**V1.0.28:** Misc → Movement → **Left hand (cl_righthand 0, permanent)** (açık): lua yüklenir yüklenmez silah sol ele geçer ve açık kaldıkça öyle kalır (oyun / config geri çevirse de); kapatınca ya da script kaldırılınca eski değer geri gelir.

**V1.0.30** (V1.0.29 logu, de_mirage 22 dk):

| Değişiklik | Neden |
|---|---|
| LBY kolu (`lby+` / `lby-`) **hareket eden düşmanda da** seçilir (eskiden sadece duran düşmanda) | V1.0.29 oturumunda 30 atışın 28'i hareketli hedefe gitti; kol sadece durana seçildiği için hiçbir atışta uygulanmadı (hepsi `res gs`, panelde `kollar: GS 6/7`). LBY sunucunun gerçek göz yaw'ına güncellenir, gördüğümüz göz yaw'ı sahtedir; fark hareketliyken de desync'in kendisidir |
| Taraf bilgisi kaybolur ya da türü değişirse (lby → open / duvar) seçili kol **bırakılır**, GS resolver'ına dönülür, yeni türe göre kol yeniden seçilir (logda `taraf bilgisi degisti (lby -> open): lby+ kolu birakildi`) | Kol seçildiği taraf bilgisine bağlı; bilgi gidince Force body yaw dayanaksız kalıyordu (isabetten sonra aday 30 sn tutuluyordu) |
| LBY eşiğinde histerezis: kol seçiliyken 25°, yoksa 35° | Fark eşik etrafında titreyince kol düşüp yeniden seçilmesin |

**V1.0.31** (V1.0.30 logu, de_mirage 26 dk):

| Değişiklik | Neden |
|---|---|
| Kol, taraf bilgisi **1 sn kesintisiz** yoksa bırakılır (anlık kayıp sayılmaz); logda `taraf bilgisi 1.2 sn'dir yok (lby -> open): lby+ kolu birakildi` | LBY farkı anlık ölçülür: düşman yürürken LBY her güncellemede göz yaw'ına eşitlenir, fark bir an 0 olup geri gelir. V1.0.30 oturumunda 8 kol seçiminin 8'i aynı saniye bırakıldı, 30 atışın hepsi yine `res gs` |
| Bilgi anlık yokken seçildiği taraf (L/R) korunur | Taraf `open` dönünce açı aynalanmıyor, sağ taraf kolu sol açıya kayıyordu |

**V1.0.32** (V1.0.31 logu, de_mirage 30 dk):

| Değişiklik | Neden |
|---|---|
| Kendi resolver'ın kararı **düşman başına** tutulur, durum başına değil: düşman Standing → Slow walk → Moving geçse de aynı kol o durumun hipotezine yazılır (havada yazılmaz) | V1.0.31 oturumunda 12 kol seçiminin hepsi "Standing"de verildi, atışlar 1 sn sonra "Slow walk" / "Moving"de gitti; o durumun hipotezi boş olduğundan 43 atışın hepsi yine `res gs` |
| Kol seçiminde **UCB1 kesif primi**: skor + 0.25 · √(ln(toplam atış + 1) / (kolun atışı + 1)) | GS %85 tutarken hiç denenmemiş kol salt ön bilgiyle (0.62) asla öne geçemiyordu; prim denenmemiş kolu ilk 4–8 atışta öne alır, tutmuyorsa kendiliğinden söner |
| İsabet eden kol düşmanda kalır; resolver ıskasında bırakılır ve yeniden seçilir. Bilgi kaybında karar da sıfırlanır (bilgi dönünce beklemeden yeni karar) | Her atıştan sonra karar sıfırlanınca bilgi o an yoksa kol kayboluyordu |
| LBY farkı **150° üstü** taraf bilgisi sayılmaz | 178°, 122°, 111° gibi "farklar": desync en çok ~58°, bu LBY kırıcı / bayat LBY; işaret anlamsız |

**V1.0.33** (V1.0.32 logu, de_mirage 20 dk):

| Değişiklik | Neden |
|---|---|
| Yeni kollar **`abs+` / `abs-`**: taraf bilgisi (LBY / duvar) yokken **statik desync'li** düşmanda doğrudan body yaw +58 / −58; hangi taraf olduğu düşman başına öğrenilir (kalıcı), ön bilgi 0.50 / 0.50 | 36 atışın 28'inde LBY farkı 0, 20 dakikada sadece 3 kol kararı: LBY ve duvar bilgisi nadir. Statik desync'te gerçek kafa sahte yaw'ın hep aynı tarafında; 36 atışın 15'i statik düşmana. Jitter / x-way'de yok (her pakette taraf değişir) |
| Own resolver kapatılınca bekleyen karar silinir | Kapalıyken eski karar Force body yaw'ı tutuyordu |
| Log: `bizim abs+ (statik desync, taraf bilgisi yok) body yaw 58°`, atışta `res abs+` | |

**V1.0.34** (hata taraması: 4 avcı, bulgu başına 1 doğrulayıcı; 22 adaydan 9 doğrulandı, birleşince 6 hata):

| Değişiklik | Neden |
|---|---|
| **Sniper'da DT çifti kaldırıldı** (scout / AWP / R8: kafa, Min. damage HP + 1). Menüdeki seçenek etkisiz ve gizli | DT ikinci scout mermisini atmıyor: loglarda ~500 scout atışında ardışık iki atış arası hep 1.0–1.3 sn (sürgü). "Çift" gövde −90 ile düşmanı 8–15 canla bırakıyor, DT / defensive boşalıyor, dönüş atışında ölüyordun (v30 17:13:35, v32 18:00:44, v33b 18:30:12). Neverlose V1.1.7 ile aynı karar |
| Sahte kayıtta "sadece gövde" kuralı DT çiftini öldürücü saymaz | Çift yüzünden öldürmeyen gövdeye Force veriliyordu, öldüren kafa kapanıyordu (v33b 18:29:09) |
| **Kafa beklerken ölüm öğrenmesi** senin Min. damage'in 90+ iken sayılmaz | Gevşeme gövdeyi zaten açtırmıyor, sadece sniper kuralını haritanın geri kalanında kapatıyordu; v33b'de "0.00 sn vurulabilir" iki ölümle 20 dk kapalı kaldı |
| Teleport sonucu: ışınlandıktan ilk **0.12 sn** içinde gelen mermi sayılmaz | Işınlanmadan önce atılmıştı (v31 17:24:21 `tp 0.13s`); 3'te 2 kuralı havada teleportu haritaya kapatıyordu. Neverlose V1.1.8 ile aynı |
| Kendi resolver kolu: kafaya nişan alınıp göğse giden isabet kolun başarısı sayılmaz | v33b 18:33:58 `hedef head 288 \| isabet chest -72 \| res gs` GS koluna isabet yazılıyordu; resolver penceresi bunu zaten saymıyordu |
| Kendi kolumuz ıskalarsa brute döngüsü başlamaz, kol yeniden seçilir (karşı kol dahil) | Tek ıskada brute başlıyor ("body yaw −58 denenecek"), 30 sn boyunca kol kararı engelleniyordu; Force + 3 ıska kapısı atlanıyordu |

Elenenler (doğrulayıcı reddetti): `sikmadi` teşhisinin MD 100+ hesabı, duelloda sahte kayıt beklemesi yok (bilinçli), sniper'da öldürücü gövdenin Prefer'de kalması.

**V1.0.35** (istekler: AFK modu, 4:3, eğilirken daha zor vurulma, loglar ekranda değil; tarama fikri 2):

| Değişiklik | Menü | Neden |
|---|---|---|
| **AFK modu:** açınca durduğun yer çapa olur, AI peek Peek Assist tuşu olmadan oradan çalışır; AI peek boştayken **3 sn'de bir** düşmana dik 24 birim sağa / sola adım (duvar / uçurum varsa o yan atlanır); DT her silahta açık, DT doluyken defensive her tick zorlanır (temiz atış hariç), otomatik ateş ve otomatik dürbün açık. Tuşa basınca adım durur, bıraktığın yer yeni çapa olur; doğunca / ışınlanınca çapa yenilenir. 2 boş peek kilidi AFK'da 10 sn sonra kalkar. Log: `afk modu acik ...` | Exploits → Peek → **AFK mode** (kapalı) | İstek. Not: AFK'da da hareket ettiğin için durum Peek sayılır (Peek AA'sı ve exploit'i) |
| **Aspect ratio** (`r_aspectratio`): 4:3 / 5:4 / 16:10 / Off | Misc → Movement → **Aspect ratio** (4:3) | İstek. `r_aspectratio` görüntüyü 4:3'e çeker ama **FPS'i tek başına artırmaz** (çözünürlük değişmez) |
| **FPS boost:** gölgeler (`r_shadows`, `cl_csm_*`), 3D sky, post-process, kırılan parça, namlu ışığı, dinamik ışık kapalı | Misc → Movement → **FPS boost** (açık) | FPS artışı bundan gelir. Kapatınca / script kaldırılınca senin eski değerlerin geri yazılır |
| **Eğilirken Safe recharge:** eğik Peek'te ve eğik yürürken de görülüyorsan atıştan sonra DT şarjı bekletilir (en fazla 0.5 sn) | Exploits → **Also while crouched** (açık) | v30–v33b'de eğikken 84 vurulma: DT yarım şarjdayken (%10–90, şarj olurken sunucuda donuyorsun) gelen mermilerin **%55'i kafa** (11/20), DT dolu / 0'dayken %17 (10/59). Defensive eğikken kafayı korumuyor (%26 / %29), o yüzden "defensive zorla" değil. Ayakta Peek'te V1.0.22 kuralı kalır |
| Kimse seni görmezken scout'ta **Body Aim Prefer** (senin Min. damage'in 90+ iken; daha düşükse eski Default) | — | Görülmezken kafa isabeti %55, görülürken %84; tek ayar farkı Body Aim. MD 100'de tam canlı düşmana gövde atışı zaten yapılmaz |
| **Loglar ekranda değil:** satırlar `client.color_log` ile sadece konsola, CS:GO'nun sol üst bildirimi (`con_notifytime`) kapalı; `nykle_log.txt` dakikada bir yazılır (5 dk'ydı) | Home → Console → **Logs only in console + file** (açık) | İstek. Dosya CS:GO klasöründe |

Gözden geçirmeden sonra düzeltilenler (aynı sürüm): AFK'da Peek tuşu her yerde "basılı" sayılıyordu, bu sahte kayıt beklemesini kapatıyor ve her yan adımı Peek yapıyordu; artık sadece AI peek için sayılır. Ölünce AFK çapası ve otomatik ateş bırakılır. Havada eğikken şarj bekletilmez (havada teleport için şarj lazım). AFK adımı basamak yüksekliği (18 birim) dışına inmez, kenardan düşmez. Okunamayan cvar'a dokunulmaz (yanlış "eski değer" geri yazılmasın), yazım geri okunarak doğrulanır. Prefer kuralı Min. damage override tuşunu da sayar.

Fikir 1 (AI peek'in DT çiftiyle öldüren açıyı kabul etmesi) yapılmadı: V1.0.34'te sniper DT çifti kaldırıldı; AI peek tek gövde mermisiyle öldüren açıyı zaten kabul ediyor. Loglardaki retlerin hepsi "60 birime kadar öldürecek atış yok" (tam canlı, kafa görünmüyor).

**V1.0.36** (istek: "hem ıskayı hem kafayı korumayı artır"; v30–v33b'de sana gelen 193 mermi ölçüldü):

| Değişiklik | Menü | Neden |
|---|---|---|
| **Şarj pozu:** atıştan sonraki 1.5 sn'de (ya da ışınlandıktan sonraki 1 sn'de) DT dolana kadar body yaw statik + GameSense freestanding body yaw (kafa siperin arkasında) | Exploits → **Recharge pose** (açık) | DT yarım şarjdayken (şarj olurken sunucuda donuyorsun) gelen mermilerin **%50'si kafa** (24/48), dolu / boşken %17. Statik + freestanding en az kafa yenen poz (Freestanding'de 2/25) |
| **Clean shot varsayılan kapalı:** nişan alabildiğin anda da defensive açık kalır | Exploits → Defensive → Clean shot (kapalı) | Defensive sırasında attığın 15 atışın 2'si ıska (%13), temiz atışta 137'nin 36'sı (%26): GameSense'te lag'de ateş isabeti düşürmüyor. DT doluyken defensive açıkken düşman mermilerinin **%45'i ıska** (kafa %16), kapalıyken %20 ıska (kafa %20) |
| **Faz öğrenmesi temizliği:** DT yarım şarjdayken yenen kafa düşmanın faz tabanını ve faz istatistiğini değiştirmez (sıra yine ilerler) | — | Bu mermiler kafa kayıtlarının yarısıydı ve fazları yanlış "kötü" gösteriyordu; onlar çıkınca Peek fazlarının hepsi %18–22 kafa |
| **Log:** ıska satırında düşmanın silahı (`silah ssg08`), AA alanında modelde oluşan gerçek desync ve body modu (`sol 58 (gercek 41, jit)`), yarım şarjda `sh 5/14`, `dtac` (DT ne zaman açıldı), `defbitti` (defensive ne zaman bitti), poz açıkken `sarj pozu` | — | Atış olmadan gelen 30 yarım şarj mermisinin kaynağı logda yoktu; sonraki log bunu gösterecek |

Verinin yapma dedikleri: desync 58 → 60 (fark durumdan geliyor, GameSense'e ikisi de 180 gidiyor), daha fazla faz / rastgele taraf (aynı faz + taraf 28 denemede 0 kez tekrar kafa yedi), düşmana özel AA (kafalar 16 kişiye dağılmış).

**V1.0.37** (V1.0.36 oturumu, de_mirage 23 dk; istek: "AFK olduğumu anlasın, kendiliğinden açılsın"):

| Değişiklik | Menü | Neden |
|---|---|---|
| **Otomatik AFK:** doğduktan ya da round başladıktan sonra (donma süresi bitince) **8 sn** hareket / zıplama / eğilme tuşuna basmazsan AFK modu kendiliğinden açılır; bir tuşa basınca kapanır ve o doğuşta bir daha açılmaz. Log: `otomatik afk: dogduktan sonra 8 sn tusa basmadin` / `otomatik afk kapandi: tusa bastin` | Exploits → Peek → **Auto AFK** (açık) | İstek |
| **Clean shot yine varsayılan açık** (V1.0.36'da kapatılmıştı) | Exploits → Defensive → Clean shot | V1.0.36 oturumunda defensive daha çok açılıp kapandıkça DT her bitişte yeniden şarj oldu: `DT %0, defbitti 0.00s` satırları. Sana gelen mermilerin 16/28'i yarım / boş şarjda (önceki oturumlarda 48/193), kafa oranı %26 → %36. Örnek küçük ama yön net; "lag'de atış isabeti düşmüyor" bulgusu doğru kaldı, sorun defensive bitişindeki şarj |

V1.0.36 oturumu (28 düşman mermisi, küçük örnek): şarj pozu 6 mermide 3 kafa (henüz etkisi görülmedi, kalıyor); atışsız yarım şarjın kaynağı bulundu: defensive bitişi (`defbitti` 0.00–0.6 sn, 18 yarım / boş şarj satırının 10'unda). Ayarlanan 58° desync jitter'da modelde 12–34° görünüyor (`gercek`), statik / freestanding'de 56–57°. Kalıcı hafıza bu oturumda yüklenmedi; V1.0.33 de dün 20:45'te hafızasız yüklenmiş, yani GameSense veritabanı silinmiş (sürümle ilgisi yok), oynadıkça yeniden dolar.

**V1.0.38:** loglar hâlâ ekranın sol üstünde görünüyordu. O alan CS:GO'nun konsol bildirimi; `developer 1` iken konsola düşen her satırı çiziyor. V1.0.35'teki `con_notifytime 0` hiç yazılmıyordu: geliştirici cvar'ı olduğu için Lua okuyamıyor, "okunamayan cvar'a dokunma" kuralı da yazımı atlıyordu. Şimdi "Logs only in console + file" açıkken `developer 0` yapılıyor, `con_notifytime` da okunamazsa konsol komutuyla 0'a çekiliyor. Kapatınca ikisi de eski değerine döner (`con_notifytime` okunamadıysa 8).

**V1.0.39:** resolver paneli varsayılan **%160** boyutta, ekranın ortasının biraz sağ üstünde (binde 560 / 380); config'inde eski varsayılan (12 / 330 / %100) kayıtlıysa bir kez yeni yere taşınır, elle sürüklediğin yer korunur. Ayrıntılı log: `vurulma-detay` ve `olum-detay` satırlarında saldırana göre AA (`aa yon +12 dsy -41 body jit`: gönderdiğin yaw ile saldırana yön arası, modeldeki işaretli desync, body modu); `sen ozeti`nde `yarim sarj N tick (goruluyorken M), sarj pozu K, defensive bitisi D` (hayat boyunca DT'nin yarım şarjda, sunucuda donuk geçtiği süre).

**V1.0.40** (V1.0.35–1.0.39 kodunda hata taraması; 15 aday, 13 gerçek):

| Düzeltme | Neden |
|---|---|
| **AFK seçenekleri "Always use recommended settings"in dışında** | Önerilen ayarlar açıkken (varsayılan) elle açılan AFK 1 sn içinde kendiliğinden kapanıyordu |
| **Otomatik AFK girdileri:** ateş, dürbün, E, R, silah seçimi ve **fare** de girdi sayılır; menü açıkken ve ısınmada sayaç ilerlemez; donma süresinde tuşa basmak sadece sayacı sıfırlar (AFK'yı o doğuş için bozmaz). Log: `otomatik afk kapandi: fare / ates / tus ...` | Eskiden sadece WASD / zıplama / eğilme sayılıyordu: menüde ya da sadece fareyle nişan alırken 8 sn'de AFK açılıp seni yürütebiliyordu; donmada A/D'ye dokunmak AFK'yı o round tamamen kapatıyordu |
| Ölünce AFK kapanır (`afk modu kapali: oldun`) | Ölüyken ve harita değişirken AFK "açık" kalıp kapanış satırı bir sonraki doğuşta yazılıyordu |
| **Şarj pozu ve faz öğrenmesi gerçek şarj sebebine bakar:** son 1.5 sn'de atış / aimbot atışı, 1 sn'de teleport, **defensive bitişi** ya da DT'nin açılması. Satırda sebep yazılır: `sarj pozu (def)` | V1.0.36 logunda defensive bitişindeki yarım şarj kafaları pozsuz geçti; şarj tahmini sebepsizken de %70–90'da durabiliyor (`DT %90 ... defbitti 3.41s`), bu mermiler yanlışlıkla öğrenmeden çıkarılıyordu. Poz açıkken (faz yerine poz uygulanmışken) gelen mermi de faza yazılmaz |
| Satırda `aim 0.05s` (aimbot atışı istemcide hemen) | `sarj pozu, atis yok` çelişkisi: weapon_fire sunucudan geç geliyor |
| **cvar orijinalleri veritabanında** (`nykle_win_gs_cvars`) | Oyun çökerse 4:3 / gölgesiz `config.cfg`'ye yazılı kalıyordu ve sonraki yüklemede eski değer kayboluyordu |
| Panel taşıması config yüklenince de yapılır | Sonradan yüklenen config paneli eski küçük yere geri koyuyordu |
| `defensive bitisi` sayacı her round 1 fazla sayıyordu; ölüyken eski defensive durumu doğuşta "bitti" sayılıyordu | Sayaç düzeltildi |
| Log dosyası canlıyken 5 dk'da bir, ölüyken / donmada dakikada bir yazılır | 1 MB'lık dosyayı round içinde her dakika yazmak takılma yapıyordu |

**V1.0.41** (V1.0.37–1.0.39 oturumları, de_mirage ~22 dk, 41 düşman mermisi):

| Değişiklik | Neden |
|---|---|
| **Şarj pozu varsayılan kapalı** (Exploits → Recharge pose) | V1.0.36–1.0.39'da DT dolu değilken poz açıkken **16 merminin 9'u kafa (%56)**, poz yokken (jitter) 28'in 9'u (%32). Donukken statik desync + freestanding tahmin edilebilir oluyor |
| **Log dosyası her yeni sürümde sıfırdan:** `nykle_log.txt`'de bu sürümün yükleme satırı yoksa eski oturumlar atılır | İstek (karışık olmasın) |

Oturum notları: Clean shot açık olsa da yarım / boş şarjda gelen mermi payı yüksek kaldı (28/41); demek ki asıl sebep Clean shot değil, defensive'in sürekli açılıp kapanması (bir hayatta 141 defensive bitişi). Kafa oranı %34. Senin kafa atışın 8/19 (correction 6). Otomatik AFK doğru çalıştı (8 sn'de açıldı, tuşla kapandı). `aa yon` örnekleri: vurulduğunda yüzün saldırana çoğunlukla ±120–180° (arkası dönük), birkaçında ±90° (yan).

**V1.0.42 — defensive A/B testi** (Exploits → Defensive → **Defensive A/B test**, açık): tek roundlarda (A) defensive normal; çift roundlarda (B) görülme / yakın düşman / peek için defensive zorlanmaz (silah değişimi, bıçaklı yakın ve AFK aynı kalır). Round başında `defensive testi: bu round A / B` ve her `vuruldun` / `iska` satırında `test A` / `test B`. Neden: defensive her bittiğinde DT yeniden şarj oluyor (bir hayatta 141 bitiş) ve yarım şarjda gelen mermiler kafa yediriyor; defensive'in kendi kafa koruması ise ölçülemedi (%23–43 açık, %29–35 kapalı, küçük örnekler). Birkaç oturumluk logla hangi kolun daha az kafa yedirdiği ölçülüp kalıcı karar verilecek; o zamana kadar maçların yarısı B kolunda geçer.

**V1.0.43** (V1.0.42 oturumu, de_mirage 40 dk, 43 round, 40 düşman mermisi):

| Değişiklik | Neden |
|---|---|
| **Görülünce / yakın düşmanda / peek'te / havada zorlanan defensive varsayılan kapalı** (Exploits → Defensive → **Force defensive when seen / near (Smart)**; A/B testi de kapalı, istenirse açılır) | A/B: A (zorlanan) 18 mermi **7 kafa (%39)**, %17 ıska, 10 ölüm; B (zorlanmaz) 22 mermi **6 kafa (%27)**, %32 ıska, 7 ölüm. Peek'te B 11 mermide 1 kafa, 6 ıska. V1.0.36'da da daha çok defensive → daha çok kafa. Silah değişimi, bıçaklı yakın ve AFK zorlaması kalır |
| **Şarj tavanı gözlemden:** son 5 sn'deki en yüksek shift (en az 4) dolu sayılır | Bu sunucuda (ping ~30) DT doluyken bile `DT %60` görünüyordu: hayat boyu 7500 tick "yarım şarj"; AI peek "DT şarj oluyor" diye bekliyor, Safe recharge ve öğrenme filtresi yanlış çalışıyordu |

Oturum notları: kafa oranı %32 (13/40); senin göğüs / mide ıskalarının hepsi R8 (Min. damage 11, BA Force, hc %39–84 — senin R8 ayarların). Log sıfırlaması çalıştı (dosya V1.0.42 ile başlıyor), hafıza 25 oyuncu.

**V1.0.44** (V1.0.43 oturumu, 2 dk: 9 düşman mermisinin 6'sı sen havadayken; tüm GameSense loglarında havada **%49 kafa**, yerde %26):

| Değişiklik | Menü | Neden |
|---|---|---|
| **Havada görülünce eğil** | Exploits → Defensive → **Air duck when seen** (açık) | Havada eğikken %33 kafa (6/18), düz havada %58 (18/31); eğik + teleport 1/9 |
| **Teleport sadece kafa vuruşuyla "başarısız" sayılır**, haritada kapanması için en az 3 sonuç | Teleport in air when seen | Havada teleporttan sonra %33 kafa, teleportsuz %58. "Kapat" kuralı 6 kez tetiklendi, çoğu göğüs / mide vuruşuyla (bu oturumda 2 sonuçta kapandı) |
| Havada defensive (Air lag) kapalı kalır (V1.0.43'ten beri, Smart zorlamasıyla birlikte) | — | Havada defensive açıkken %58 kafa, kapalıyken %46: korumuyor |

**V1.0.45 — V1.0.33'e göre geri dönüş + iki yenilik.** Sürüm sürüm aynı ölçüler (düello kazanma = öldürme / (öldürme + ölüm)):

| Sürümler | Düello kazanma | Aimbot isabeti | DT dolu değilken gelen mermi |
|---|---|---|---|
| V1.0.30–1.0.33 | **%51** (91/178) | **%74** (117/158) | %49 |
| V1.0.36–1.0.43 | %35 (35/101) | %56 (53/95) | %64 |

Fark istatistiksel olarak gerçek (p = 0.009 ve 0.004); bir kısmı ortamdan (ping 110, tek rakip, R8 + MD 11), ama V1.0.33 sonrası dört varsayılan değişiklik çürüyen ya da karışık veriye dayanıyordu:

| Değişiklik | V1.0.45 | Neden |
|---|---|---|
| Görülünce / yakında zorlanan defensive (V1.0.43'te kapatılmıştı) | **Yine açık** | V1.0.42 A/B geçersizdi: A kolunda defensive 19 satırın sadece 1'inde zorlanmıştı |
| Sniper DT çifti (V1.0.34'te kaldırılmıştı) | **Geri** | V1.0.30–33'te 9 çift gövde atışının 7'si öldürme; ikinci scout atışı ~1 sn sonra 8–27 canlı düşmana. Kaldırırken verilen örnek ölüm değil öldürmeydi |
| Teleport: her vuruş sayılır, 3'te 2'de kapanır (V1.0.44'te sadece kafa) | **V1.0.33 gibi** | Teleport sonrası iniş = boş DT; V1.0.44'ün %33 / %58 verisi ölmüş oyuncu satırlarını da sayıyordu |
| Kafa beklerken ölüm öğrenmesi (V1.0.34'te MD 90+ iken kapanmıştı) | **V1.0.33 gibi** | V1.0.30–33'te her oturumda 2–3 kez çalıştı, en iyi K/D o oturumlarda |
| Anti-brute tabanı her kafada taşınır (V1.0.36'da yarım şarjda taşınmıyordu) | **V1.0.33 gibi** (faz istatistiği yine temiz) | Atıştan hemen sonra seni öldüren düşman tabanı hiç taşımıyordu |
| Havada eğilme, otomatik AFK, eğikken şarj bekletme | **Varsayılan kapalı** (seçenekler duruyor) | Havada eğik 17/32 vs düz 55/85 kafa (p = 0.29, fark yok); otomatik AFK V1.0.42'de 43 roundda 19 kez açılıp DT / defensive zorladı; eğik şarj 20 mermilik veri. Otomatik AFK eski config'lerde bir kez kapatılır |
| Şarj tavanı | 30 sn penceresi, en az 6, her roundda sıfır | 5 sn / 4 yoğun anlarda yarım şarjı "dolu" okuyordu |

Yenilikler:
- **Re-arm cooldown** (Exploits → Defensive, açık): görülmeye devam ederken defensive bittiyse 1 sn yeniden zorlanmaz, DT dolar (ilk görüş, düşman peek'i, hava, AI peek, silah değişimi, bıçak ve AFK hariç). V1.0.30–33'te atış yokken DT yarım şarjda gelen mermilerin 13/28'i kafa (%46), DT doluyken 13/68 (%19); V1.0.36–42'de defensive bitişinden sonraki 1 sn'de 14/34.
- **Random anti-brute order** (Anti-Aim → Protection, açık): kafa yiyince sıradaki faz sabit +1 değil, rastgele (kötü bilinen fazlar yine atlanır). Rakip "anti brute Claude'a bağlı, randomize" diyordu; sabit sıra öğrenen bir resolver'a tahmin edilebilir.
Kalanlar: sahte kayıt / teleport 0.12 sn / kol muhasebesi düzeltmeleri, Clean shot açık, şarj pozu kapalı, görülmezken sniper Prefer, loglar, AFK (elle), 4:3 / FPS boost.

**V1.0.46** (V1.0.45'in ilk oturumu, 12 dk, scout + MD 100):

| | V1.0.44 | V1.0.45 |
|---|---|---|
| Düello kazanma | %35 (16/46) | **%45** (9/20) |
| Sana gelen mermide kafa | %30 (19/63) | **%15** (5/34) |
| Düşman ıskası | %32 | **%47** |
| Senin scout isabetin | %73 (24/33) | %59 (16/27; 8 correction) |
| DT çifti | — | 5 karar: 3 öldürme, 1 ölüm |

Örnek küçük (20 düello) ama yön V1.0.33'e doğru. Yeni: **Finish low HP with safe point** (Ragebot → Resolver, açık): canı 30 ve altındaki düşmana Force safe point; her isabet öldürür, resolver tahminine gerek yok. Bu oturumda 8 canlı düşmana 3 takip atışı "correction" ile ıskaladı (tüm loglarda 40 atışta 6). Safe point bulunamazsa 0.5 sn sonra bırakılır.

**V1.0.47** (V1.0.46 oturumu, 19 dk, de_mirage, scout + MD 100; rakipler northgard, iha, Serpent1337, azure — rakipler roll / "extended" kullanıyor):

| | V1.0.45 | V1.0.46 |
|---|---|---|
| Düello kazanma | %45 (9/20) | %36 (10/28) |
| Sana gelen mermide kafa | %15 (5/34) | %36 (13/36); 5 ölüm duvardan kafa |
| Senin scout isabetin | %59 (16/27) | %42 (11/26; 8 correction, 5 spread) |
| Düşük can safe point | — | 2 atış: 1 öldürme, 1 sahte kayıtta ıska |

| Değişiklik | Neden |
|---|---|
| **DT şarj tavanı** artık 24 tick (~0.4 sn) **tutulan** shift'ten öğreniliyor | 10 roundun 5'i baştan sona "DT %70 sh 7/14" okundu; o roundlarda zorlanan defensive 0 tick, havada teleport ve DT çifti de kapalıydı. Kısa defensive düşüşleri ve kırpma tick'i tavanı 10'a şişirip düz 7'yi "yarım" okutuyordu. Bir hayatta ilk atıştan sonra aynı şarj "dolu" görünüyordu (ölçüm hatası). "sen ozeti"ne `sarj tavani` ve `taban farki` eklendi. |
| **In-air hit chance** varsayılan 40 → **0** (havada da senin hc'n; kayıtlı config'teki 40 bir kez 0 yapılır) | Bu ayarın açtığı hc < 55 havada scout atışları V1.0.30–46'da 12: 3 gövde isabeti, 0 kafa, 0 öldürme; bu oturumda 4/4 spread. hc ≥ 55 havada 3/5 isabet. Bedeli: havada hc 55'in altında yine sıkmaz. |
| **R8 sniper kuralından çıktı** (SSG08 / AWP kalır) | R8 82 gövde hasarıyla 0.45 sn bekledi, deagle'a öldün; R8 ölümleri scout kuralını "öğrenildi" diye gevşetiyordu. R8'de senin kendi Min. damage'ın geçer. |
| **Extended desync (roll)** (Anti-Aim → Protection, **kapalı**; Roll 45°) | İstek ("extended var mı"). Kullanıcının sunucusunda roll yasak ("extended değil"), bu yüzden varsayılan kapalı; roll'a izin veren sunucuda elle açılır. GameSense'in Roll ayarı lua açıkken gizliydi ve hiç yazılmıyordu. Yerde ve yavaşken (hız < 100) desync tarafına göre ±roll; koşarken, havada, merdivende 0. **Valve sunucularında kapat.** Vurulma satırlarında `roll ±45` yazar. |
| **Scout / AWP ile safe point en az Prefer** (resolver seviyesi 0'da da) | Rakipler "extended yaw" kullanıyor; bilinmeyen desync'e karşı safe point. Tüm loglarda kafa atışı SP Prefer 110/144 (%76), SP Default 12/19 (%63). Prefer atışı engellemez, safe nokta varsa onu seçer. Aynı düşmana correction ıskasından sonra aynı roundda kafa atışları 8/9 tuttu (mevcut tırmanma çalışıyor). Senin Prefer safe point ayarın açıksa dokunulmaz. |
| Loglar: sahte kayıt beklemesi neden bitti (`serbest birakildi (seni goruyor / duello / cooldown)`, `sinir doldu, kayit hala sahte`), atış satırında `bekleme yok: <sebep>` | Bu oturumda 47 bekleme 14 tick sınırıyla, 25'i "gercek kayit geldi" diye bitti; ama görüldüğü / peek attığın için bırakılanlar da "gercek kayit geldi" yazıyordu ve sahte kayda giden atışların sebebi bilinmiyordu. Rakibin roll'u ağdan gelmiyor ve istemcideki hitbox'lar roll'suz kurulur; roll'lu rakip ancak ıskalardan (duran hedefe kafa correction) anlaşılır. |

**V1.0.48** (V1.0.47 oturumu, ~30 dk, de_mirage, scout + MD 100; rakipler dominik, azure, northgard, Serpent1337):

| | V1.0.46 | V1.0.47 |
|---|---|---|
| Kill / ölüm | 10 / 18 (%36) | 21 / 29 (%42) |
| Sana gelen isabette kafa | %36 (13/36) | **%29** (17/58) |
| Senin scout isabetin | %42 (11/26) | %49 (30/61); 24 correction (dominik 25 atış), 3 spread |
| Havada hc < 55 spread | 4 | **0** |
| Yarım şarj okunan canlı süre | — | %41 (58 293 tickin 24 147'si) |

| Değişiklik | Neden |
|---|---|
| **DT şarjı: sebepsiz düz kalan shift dolu sayılır** (atış / aimbot atışı 1.5 sn, teleport / DT açılışı 1 sn, silah çekme yokken 24 tick tutulan shift 32 tick ±1 düz → tavan o değer) | V1.0.42–47'de roundun ilk atışından önce sebepsiz okumalar 63 dolu / 133 yarım (sh 4–9, 10–20 sn düz); ilk atıştan sonra 54 dolu / 9 yarım. Şarjsız fark (taban) sadece şarj harcanınca düzeliyor, doğuşta kayınca dolu DT "%60" okunuyordu ve forced defensive, havada teleport, DT çifti, AI peek kapalı kalıyordu. Sadece tavanı düşürür; sebep penceresinde, taban düzelince ve her round silinir. |
| Resolver logu uygulanan safe point'i yazar (`seviye 2 -> safe points Prefer (sniper kafa kurali: Prefer uygulanir)`) | Scout / AWP'de "Head unless body kills" açıkken Force safe point hiç uygulanmıyor (resolver.cap), log "Force" yazıyordu. Davranış değişmedi: ıskadan sonraki atış GS ile 21/37, brute 1/4, kendi kol 0/1; Force verisi yok. |

Ayrıca: **Trash talk varsayılan kapalı** (istek); kayıtlı config'te açık kaldıysa ilk config yüklemesinde bir kez kapatılır, sonra elle açarsan dokunulmaz.

İncelenip değiştirilmeyen: ıskaları düşman başına (durum yerine) saymak (15 atışı erkene alırdı, bunların 10'u zaten isabetti), yan dönük düşmana kural (sadece v47'de iki oyuncuda görülüyor).

**V1.0.49** (dominik incelemesi, V1.0.47 oturumu + V1.0.48 ilk oturumu):

| | Ölçüm |
|---|---|
| dominik'e atış | 25 atış: kafaya 16'da 1 isabet (14 correction), gövdeye 9'da 6 |
| Iskalardan sonra ne oldu | 14 resolver ıskası 5 duruma dağıldı (duran 5, yavaş 3, hava 3, koşu 2, eğik 1); brute aynı durumda 3 ıska istiyor, iki kez açıldı. 10 kafa ıskası GameSense'in kendi resolver'ıyla |
| Zorlanan body yaw ile kafa (tüm loglar, 7 rakip) | -58: 8/11, +58: 1/6 |
| V1.0.48 ilk oturumu | yarım şarj %41 → %11 (şarj düzeltmesi tuttu); 5 kill / 10 ölüm; 18 atışın hepsi GS ile, 6 correction |

| Değişiklik | Neden |
|---|---|
| **Resolver serisi** (düşman başına, durumdan ve AA deseninden bağımsız): aynı düşmana 3 resolver ıskası (her biri bir öncekinden ≤ 300 sn) → GameSense'e kalacak atışlarda Force body yaw **-58**; -58 iki kez üst üste kafayı ıskalarsa +58, +58 bir kez ıskalarsa -58. GameSense kafadan vurursa seri biter; zorlanan açıyla kafa isabeti seriyi açık tutar. Kendi kol / brute önce gelir. Correction kapalıysa ya da senin Force body yaw'ın varsa yazılmaz. Logda `res seri` ve `seri: ...` satırları **Tüm loglar taraması** (705 scout atışı) ile iki ince ayar: statik AA'lı düşman yan dururken (\|bak\| 45–135) seri **2 ıskada** açılır (yalnızca hâlâ yan dururken uygulanır; statik yan duruşta GS kafa correction %29, arkası dönükken %15); düşman jitter / x-way / random'dayken seri ne sayar ne uygulanır (`seri: desen ... -> GS`), çünkü orada GS %73 tutuyor ve zorlanan açı hiç denenmemiş. | dominik'e kafa 1/16; ıskalar durumlara dağıldığı için brute ve kendi kollar devreye girmedi. Sürekli ıskaladığın rakipler (tüm loglar): dominik %65, aimlarp %44 (Neverlose), azure %50, ping-170 oyuncu %35, PhytoCannaBinoide %32 resolver ıskası; ortak noktaları yan duruş (%41'e karşı %11), yüksek ping (medyan 107 / 47) ve statik AA'da yan duruş. Replay: dominik'in 14 correction ıskasının 9'u seri açısıyla atılırdı; diğer rakiplerde 3 ıska, 0 kafa isabeti etkilenir. Beklenen kazanç küçük örnekten: dominik'e ~2–3 kafa. Rakibin roll / extended'ı yüzünden hiç işe yaramayabilir; bir sonraki logda `res seri` atışları ölçülecek. |

**V1.0.50** (geliştirme turu: brute ayna, ölümler, sıkılmayan atışlar, V1.0.47–1.0.49 hata taraması; V1.0.48 oturumunun tamamı)

V1.0.48 oturumu (~20 dk): 12 kill / 19 ölüm, sana gelen 32 isabette 9 kafa, 34 atışta 16 isabet (11 correction, 5 spread), atışların **hepsi GS ile** (seri kuralı V1.0.49'da). Yarım şarj ~%11 kaldı.

| Değişiklik | Neden |
|---|---|
| Düşük can safe point: sadece Adaptive resolver açıkken; açı seçiliyse (hipotez / seri) ya da sadece kafa açıksa Force yazılmaz | Force safe point seçilen açıyı gereksiz kılıyor, sadece kafa açıkken atışı kilitleyebilir (resolver.cap ile aynı gerekçe). Logda görülmüş bir olay yok, önleyici. |
| Resolver serisi yeni haritada ve "Forget learned enemies"ta sıfırlanır | Tutarlılık. |
| Şarj: tutulan shift öğrenilen "dolu" değerin üstüne çıkarsa o değer silinir | Yarım şarjın %100 okunmasını önleyen değişmez (önleyici). |
| Loglar: `sikmadi` satırında MD 100+ için gerçek eşik (`hasar 74 < can+1 = 55 (hp54)`), sürgü (`silah hazir degil (surgu, son atis 0.40s once)`), R8'de "dürbün kapalı" yok; atış satırında `BY -58° (duvar L)`; her vurulmada `iz duvardan` / `iz acik` | Sıkılmayan atış incelemesi: hiçbir kapı atış kaçırmamış, ama sebepler yanlış etiketliydi. Duvardan kafa ölümleri en büyük ölüm türü; payda (açıktan vurulma) yoktu. Brute ayna: 4 karışık örnek; davranış değiştirilmedi, taraf loglanıyor. |

Doğrulamada elenenler: brute açısını seçimde dondurmak (tek kafa örneği tersini gösteriyor), teleport kapatma eşiğini 2/5 yapmak, düello gecikme logu.

**V1.0.51** (AA / defensive incelemesi ve "ı"; V1.0.48 uzun oturum + V1.0.50 ilk oturum)

V1.0.48 (v50 logu, ~40 dk): 22 kill / 33 ölüm, sana gelen 53 isabette 18 kafa (%34); vurulduğun anların 40'ında DEF kapalı. V1.0.50 ilk oturum (10 dk): 3 / 11, 16 isabette 6 kafa, 7'si duvardan (`iz duvardan`), kafaların 5/6'sı açıktan. 241 düşman mermisi (V1.0.45–48): kafa payı her mermide %22.

| Ölçüm (her düşman mermisinde kafa) | |
|---|---|
| Yerde DEF açık / kapalı | 13/63 (%21) / 26/136 (%19): fark yok |
| Havada DEF açık / kapalı | **2/14 (%14) / 14/38 (%37)** |
| Havada DT dolu ama DEF yok | 8 vurulmanın 7'si "temiz (bayrak)": GameSense'in "vurulabilir" bayrağı defensive'i kesmiş |
| Eğik yürürken peek (~78 u/s) | 11/23 vurulmada kafa (%48); eğik ≤55 u/s 2/20; desync ~29°'ye iniyor |
| İlk o gördü (<0,3 sn) | 44/170 (%26), sonra 9/71 (%13) |

| Değişiklik | Neden |
|---|---|
| **Havada scout / AWP ile GameSense'in "vurulabilir" bayrağı hava defensive'ini kesmez** (iz ya da gerçek atış yine keser); logda `DEF ... (hava, bayrak)` | Havada aimbot ancak hit chance tutarsa sıkıyor; bayrak yüzünden defensive her seferinde düşüyordu. Havada DEF açıkken kafa %14, kapalıyken %37. |
| **"Öğrenildi" gevşemesinden sonra DT çifti ve sahte kayıtta gövde kuralı açık kalır** (sadece HP+1 kalkar) | Gevşeme haritanın başında geliyor ve sonuna kadar DT çiftini kapatıyordu: v50'de gevşemeden sonra 14 tam canlı atışın hepsi kafaya (6 isabet). "ı"'ya 8 atış, 6 kafa ıskası; ikisinde DT dolu, gövde 74 × 2 ≥ 100. DT çifti gövde atışları tüm loglarda 13/17 isabet. |
| Loglar: `iska` / `vuruldun` sonunda `v<hız> duck<eğilme>`; `DEF acik gizli Nt` (gizli açı gerçekten gönderildi); atışta `kafa kurali gevsek`; "kararsız" satırı artık yanlış "Force safe point" yazmıyor | Eğik yürüyüş bulgusu ıskalarla doğrulanabilsin; defensive'in gerçekten açı değiştirip değiştirmediği görülsün. |

Doğrulamada elenenler: eğik peek'te hızı 50'ye kesmek (yazılan haliyle CS:GO'da hiç yavaşlatmıyor, mekanizma da tam kanıtlanmadı; **elle: açıya eğik yürüyerek girme, ya ayakta peek at ya da durup eğil**), havada teleportu kapatmak (iki doğrulayıcı ayrıştı; asıl sebep bayrak), peek'te gizli pitch Up, yerde defensive'i uzatmak (yerde fark yok).

**V1.0.52** (AA araştırması + faz tasarımı + çalışma / mantık hatası taraması; 258 düşman mermisi, V1.0.45–50)

| Değişiklik | Neden |
|---|---|
| **Faz öğrenmesi gövde isabetini de sayar** (kafa yakınına gelen mermi gövdeye gelirse "kafa değil" mermi; bir mermi bir kez); eski hafıza yeni ölçüye çevrilip "kötü" eşiğinin altında tutulur | Eskiden gövde isabeti hiç sayılmıyordu: ölçü kafa / (kafa + ıska) ≈ %44–50, gerçek mermi başına %22–28. Ortalama fazlar (yerde faz 1: mermi başına %30) rastgele "kötü" işaretlenip atlanıyordu. |
| **Rastgele faz sırası artık son fazı (8, asym) da seçiyor** | Faz 0'dan ilk adımda faz 8 hiç seçilemiyordu (258 mermide 17). |
| `iska` satırı uygulanan fazı yazıyor (atanın kendi fazı farklıysa `(dusmanin N)`) | Hit ve ıska satırları farklı kaynaktan faz yazıyordu. |
| Body freestanding'de taraf (`sol/sag`) ve göstergedeki taraf düzeltildi | `pose_side` ters işaretliydi: fs modunda V1.0.36–51 logları ve gösterge tersti (önceki fs taraf analizleri ters okunmalı). |
| `(hava, bayrak)` etiketi sadece defensive gerçekten zorlandığı tick'te; `sikmadi` MD ≤ 100'de de canı hesaba katar (`hasar X < can Y (MD 100)`) | Etiket bomba / merdiven / DT kapalı tick'lerinde takılı kalıyordu; düşük canlı düşmana "MD yetmedi" yanlış suçlaması. |

Araştırmanın sonucu (dürüst): **yerde faz seçimi kafa oranını değiştirmiyor** (fazlar arası ki-kare p≈0,86; aileler %19–30). Daha fazla faz eklemek veriyle desteklenmedi; önce öğrenme düzeltildi. AA'da gerçek sızıntılar: hareket ederken desync'in çökmesi (eğik yürüyüş ~29°, ≤30° desync'te kafa %27 / üstünde %17) ve hava (V1.0.51'de bayrak düzeltildi). GameSense'in kullanmadığımız AA ayarları (Yaw 180 Z, Opposite body yaw, edge yaw, fake lag, bacak / animasyon kırıcı, fake peek) bu sızıntılara etki etmiyor. Elenenler: 16 fazlık tablo (nötr), eğik peek'te hız sınırı (mekanizma ıskalarla doğrulanmadı; V1.0.51'den beri ıska satırlarında hız var, sonraki loglarla yeniden bakılacak), havada iz sinyalini bayrağın önüne koymak (V1.0.51 düzeltmesini geri alırdı).

**V1.0.53** (internet araştırması: Valve animstate kodu, açık GameSense lua'ları, sızmış resolver'lar)

Desync hız ve eğilmeyle küçülüyor (Valve formülü: tam hız eğik yürüme ~29°, koşudan yavaşlarken ~34°, dururken 58°); logda ≤30° desync'te kafa %27, üstünde %17. Yeni seçenekler (Anti-Aim → Protection) **hepsi varsayılan kapalı**; önce loglarla ölçülecek:

| Seçenek | Ne yapar |
|---|---|
| **Desync keeper: slow crouch-walk when seen** (+ hız, varsayılan 38 u/s) | Biri seni görürken eğik yürüyüş hızını sınırlar (desync ~29° yerine ~41°). Geri çekilirken, atıştan sonraki 0,6 sn, AI peek / AFK / quick peek tuşunda, merdivende, fake duck'ta çalışmaz. |
| **Desync keeper: slow walk when seen (≤115 u/s)** | Görülürken ayakta hızı 115'e sınırlar (koşuda ~29° yerine ~47°). Walk tuşuna basılıyken dokunmaz. |
| **Stop before contact when decelerating** | Birazdan görüleceksin (henüz görmüyor), koşudan yavaşlıyorsan (dar desync) ve tehdide doğru gidiyorsan 0,3 sn hızın tersine girdi verir (sürtünmeden hızlı durur); tam durunca 58° geri gelir. Quick peek tuşu / AI peek'te çalışmaz. |
| **Invert freestanding side at first contact** | Tehdidin kafanı ilk gördüğü anın (0,5 sn görülmeden sonra yeni temas) ilk 0,4 sn'sinde body freestanding'in seçtiği tarafın tersi; taraf pencere başında kilitlenir. |
| **Block jump while seen (not jump-scout)** | Görülürken zıplamayı engeller; scout / AWP ateşe hazırsa (jump scout) engellemez. |

Yeni loglar (bağımsız incelemeden sonra: silahın hızı, sabit 135,2 geçiş eşiği, 2D LC mesafesi; geri çekilme / karşı strafe girdinin yönüyle ayırt ediliyor): `iska` / `vuruldun` sonunda `maxdsy N wtr N%` (o anki tahmini en büyük desync ve koşu→yürüyüş geçişi), havadayken `lc N` (gönderilen iki kayıt arası mesafe, 64'ten büyükse `kirik`), etiketler `yavas` / `dur` / `fs ters` / `zipla yok`; round özetinde `lby taraf N/M` (kendi LBY'nin desync tarafıyla uyumu; ~%50 = sızıntı yok).

**V1.0.54** (atış tarafı analizi + taranmamış kısımlarda hata taraması + performans; 415 scout atışı, V1.0.30–50)

Atış analizi: isabet %66, kafa %36. Resolver dışında isabeti belirleyen tek şey hit chance (55–64'te %51, 65+'ta %70; spread ıskalarının 19/31'i bu bantta) ama düşük hc kendi hızımızla değil mesafeyle ilişkili; "hareketliyken hc 65" önerisi doğrulamada elendi. Kendi defensive'imiz atışı bozmuyor (zorla DEF'te 14/15 isabet). Backtrack her atışta 0: bu GameSense'in kendi değeri, script'ten değil. "Ben önce gördüm ama öldüm" ölümlerinin 36/40'ında tek atış atılıp ıskalanmış.

| Değişiklik | Neden |
|---|---|
| `dbg atis-detay`: o görünürlükteki ilk atışta `vurulabilir Xs` (vurulabilir olduğundan beri), `ates-hakki Xs` (öldürecek hasar göründüğünden beri), `o-gordu Xs` | "aim" alanı atış anında hep 0.00s'ti; yavaş mı sıkıyoruz yoksa ıskalıyor muyuz ayırt edilemiyordu. |
| `dbg ayarlar`: GameSense'in accuracy boost, delay shot, quick stop (+ seçenekleri), ping spike | Backtrack / doğruluk ayarları loglarda görünsün. Ping spike scout için önerilmez (V1.0.66'dan beri script kapatıyor). |
| "Clear saved logs" sürüm işaretini yeniden yazar | Silinen logdan sonra bir sonraki yüklemede (GS lua'yı birkaç kez yükler) tüm dosya siliniyordu. |
| Ölünce temizlik `player_death`'te de çalışır | GameSense ölüyken setup_command çağırmıyor: AFK / fake duck / plist temizliği ve "afk modu kapali: oldun" hiç çalışmıyordu; doğuş tick'i "defensive bitti" sayıyordu. |
| Alt seçenekleri olan 6 anahtar (roll, head-only, crouch keeper, safe recharge, own resolver, backstab) değişince menü hemen güncellenir | Alt ayarlar ancak sekme değişince görünüyor / gizleniyordu. |
| Performans: düşman listesi tick başına bir kez; detaylı log taraması tick'lere yayılır | Tick başına 7–10 düşman listesi kuruluyordu; log taraması 4 tick'te bir tüm düşmanlara 15 iz atıyordu (1% low'ları bozar). Kararlar değişmez. |

**V1.0.55** (dosyanın tamamı altı parçada hata avı; her bulgu ayrı doğrulandı, 8 gerçek hata)

| Düzeltme | Etkisi |
|---|---|
| DT çiftinin ikinci mermisi resolver ıskasıysa ve ilk mermi isabet ettiyse artık "damage rejection" değil **correction** sayılır | Bu ıskalar resolver'a hiç ulaşmıyordu: seri, hipotez, Force tırmanması o düşmana karşı ilerlemiyordu. |
| Force safe point / gövde Force / düşük can sayaçları sadece **ateş edebiliyorken** sayar (şarjör, bıçak, bomba, silah değişimi sayılmaz) | Şarjör değiştirirken 0,5 sn görülünce Force "takıldı" diye bırakılıyordu. |
| Düşük can Force'u ateş edildikçe sayacı sıfırlar | Ateş ederken 0,5 sn sonra kendini kapatıyordu. |
| Log dosyasının sürümü veritabanında da tutulur | Çok uzun bir oturumda yükleme satırı dosyadan düşünce bir sonraki yüklemede en uzun oturum siliniyordu. |
| Auto AFK taşıması bir kez çalışır | Oturum boyunca her config yüklemesinde Auto AFK'yi kapatıyordu. |
| "Önerilen ayarlar kapalı" raporu kendi anahtarını fark saymıyor | Rapor hep bir fazla sayıyor ve örnek olarak kendini gösteriyordu. |
| Temiz atış etiketi kaynağı doğru yazar: `bayrak`, `iz`, `bayrak+iz`, `atis` | "atis" hiç görünmüyordu, iz ve bayrak karışıyordu. Hava defensive kuralı değişmedi (bayrak açıkken sürer); `bayrak+iz` ile ikisinin birlikte ne sıklıkla olduğu ölçülecek. |

**V1.0.56** (ikinci hata avı, konu bazında: oyuncu / round geçişleri, ayar kapatma ve kaldırma, zaman birimleri, sayılar; 2 gerçek hata)

| Düzeltme | Etkisi |
|---|---|
| Harita / sunucu değişince temiz atış pencereleri (bayrak / iz / atış) temizlenir | tickcount baştan başladığı için eski haritanın "bayrak" penceresi yeni haritada dakikalarca temiz atış sayılıp defensive'i kesebiliyordu. (Test ortamı bu yolu taklit edemiyor; kod incelemesiyle doğrulandı.) |
| "Enable Nykle.win" kapalıyken `developer` / `con_notifytime` geri verilir | Script kapalıyken de ekrandaki bildirimler gizli kalıyordu. |

İki tur hata avından sonra (14 bulgu, 10'u düzeltildi) kod tarafındaki hatalar büyük ölçüde temizlendi; bundan sonraki gerçek ilerleme oyun loglarıyla ölçüm.

**V1.0.57** (istek: "roll'u açınca en iyi ayarlarında açılsın")

| Değişiklik | Neden |
|---|---|
| **Extended desync (roll) açılınca en iyi ayarla gelir:** Roll 45° (en büyük yatma), taraf desync tarafında; roll'luyken kafa yenince roll tarafı ters çevrilir (`roll: kafa yendi -> roll tarafi ters`). Yerde ve yavaşken (< 100 u/s) çalışır; koşarken, havada, merdivende 0. | Roll resolver'ları yatma tarafını tahmin eder; kafa yenince taraf değişmeli. |
| **Hata:** "Always use recommended settings" açıkken (varsayılan) roll ve V1.0.53'ün desync koruyucu seçenekleri ~1 sn içinde geri kapatılıyordu; artık izlenmeyen grupta | Bu seçenekler hiç açılamıyordu. |

Not: kullanıcının sunucusunda roll yasak; sadece izin veren sunucuda aç.

**V1.0.58** (V1.0.57 logu, de_mirage, 15 dk: 7 kill / 11 ölüm; sana gelen 24 isabetin 7'si kafa, 9'u duvardan; senin 15 atışın 14'ü isabet, 6'sı kafa)

| Değişiklik | Neden |
|---|---|
| **"Desync keeper: slow crouch-walk when seen" varsayılan AÇIK** (eski config'te kapalı kaydedildiyse ilk config yüklemesinde bir kez açılır, `nykle_win_gs_cc58`; sonra elle kapatırsan dokunulmaz). Görülürken eğik yürüyüş hızı ~38 u/s ile sınırlanır, desync ~29°'ye düşmez. | V1.0.53'ten beri her vurulmada `maxdsy` loglanıyor. V1.0.57 logunda mermi başına kafa: maxdsy ≤ 30 iken **5/15**, 31–45 iken 1/6, 46–58 iken **1/12**. Eski loglarla birlikte (258 mermi) ≤30° %27, üstü %17. Kafa yiyen düşük-desync durumlarının çoğu eğik yürüyüş / eğik zıplama. |

Logda görülen diğer şeyler (değişiklik yok, ölçülecek):
- 2 kafa "Air crouch" + "DEF acik (zorla) gizli 1t (hava, bayrak)": havada eğilirken desync de ~29°'ye iniyor; görülen açıya eğilerek zıplamak kafa veriyor.
- LBY uyumu round başına çok taraflı (0/7, 0/5, 1/9, 4/4, 3/5): rakip bazı roundlarda tarafı LBY'den okuyor olabilir. Bir sonraki logda `lby` sütunu ile kafa payı birlikte bakılacak.
- `res seri` ve roll bu oturumda hiç çalışmadı (roll kapalı, sunucuda yasak).

**V1.0.59** (V1.0.58 logu, de_mirage / de_dust2: 9 kill / 22 ölüm; sana gelen 31 isabetin 16'sı kafa; senin 26 atışın 18'i isabet, 9'u kafa)

| Değişiklik | Neden |
|---|---|
| **"DT pair counts as lethal" varsayılan KAPALI** (kayıtlı config'te açıksa ilk yüklemede bir kez kapatılır, `nykle_win_gs_dtpair59`; elle açarsan dokunulmaz) | Bu kural Min. damage 100'ünü 72–86'ya indiriyordu (logdaki "MD 73/84/86"). Scout / AWP'de GameSense DT ikinci mermiyi hemen atmıyor (sürgü ~1 sn; aynı saniyede ikinci atış 90'da 1). v58'de 8 çift gövde atışı: 0 kill, 8 ölüm (5'i kafa, düşman 0.13–0.37 sn sonra vurdu). V1.0.45'ten beri 27 çift atış: ilk atışta 0 kill, 2 sn içinde 23 ölüm. Kafa kuralı gevşemesi tek başına zararsız (MD 100 ile ilk atışta kill 46/95). |
| Sniper exploit öğrenme satırı "Same as state" iken `(ayar: ..., etkisiz)` yazar | Log "-> Hide shots" diyordu ama ayar Same as state olduğu için hiçbir şey değişmiyordu. |
| **FPS:** resolver paneli (varsayılan açık) hedefi, çözüm oranını ve ismi tick başına bir kez okur; metin ölçüleri ezberlenir | Panel her karede tüm resolver zincirini ve 4 metin ölçümünü yeniden yapıyordu (kare başı ~38 API çağrısı, 1.8 KB çöp). Sahte API'de paint 85 → ~50 çağrı / kare; çöp toplayıcı kaynaklı mikro takılma azalır. |
| **FPS:** "» Disable ragdolls (bodies vanish)" (FPS boost altında, varsayılan KAPALI) | `cl_disable_ragdolls 1`: ölenler yere yığılmadan kaybolur, çoklu öldürme / round sonu fizik yükü gider. Kapatınca / unload'da senin değerin geri yazılır. |

İlk V1.0.59 oturumu: 20 kill / 13 ölüm (V1.0.58: 28 / 49), senin 29 atışın 21'i isabet, 19'u kafa, 20'si ilk atışta kill; sana gelen kafa %46 → %27.

FPS araştırmasında elenenler (34 ajan, şüpheci kontrolü): `r_drawparticles` / `r_drawdecals` / `r_drawbeams` 0 (duman, molotof ve mermi izi bilgisini siler), `mat_queue_mode`, `fps_max`, `cl_detail_max_sway` (etkisiz ya da zararlı); diğer tick içi önbellek önerileri ölçülebilir kazanç getirmediği için yapılmadı. Asıl FPS kazancı zaten açık olan FPS boost listesinden geliyor.

**V1.0.70** (istek: "bomba, sis, molotof alsın")

| Değişiklik | Not |
|---|---|
| **Otomatik bomba alımı** ("Auto buy grenades (HE + smoke + molotov)", Misc > Movement, **varsayılan açık**): round başında (DM'de doğuşta) `buy hegrenade; buy smokegrenade; buy molotov; buy incgrenade` | CT'de molotof yerine yangın bombası alınır. Para yetmezse ya da sunucu alımı kapatmışsa oyun reddeder, zararı yok. 3 sn içinde tekrar etmez. |

**V1.0.69** (V1.0.68'in ayrı incelemesi: 14 ajan, 6 gerçek bulgu)

| Düzeltme | Neden |
|---|---|
| Zeus tutan hedefe sonraki kurallar (gövde 70+, extended gövde) öldürmeyen MD yazamaz | Canı MD'den az değilken zeus kuralı devre dışı kalıp extended gövde kuralı MD'yi ~85'e indirebiliyordu. |
| Zeus "sadece öldürücü" log satırı kural gerçekten devreye girince yazılır | Önceden bastırılabiliyordu. |
| Şarj bekletme engeli: bıçak / zeus kat farkı (≤128) ve 3B mesafe; oto sniper sana son 32 tick'te ateş ettiyse de "görüyor" | Üst / alt kattaki bıçaklı beklemeyi kapatıyordu; sana sıkan oto sayılmıyordu. |
| Tehdit kontrolü sadece gerçek bekleme adayında; logda yanlış "sarj bekleme yok" yok | Her tick çalışıyordu. |
| Zemin kafa ıskası sayacı gerçekten ardışık (gövde isabeti de sıfırlar, round başında sıfır); extended işareti en fazla 180 sn | Sayaç araya giren isabetlerle sıfırlanmıyordu, işaret kendini canlı tutabiliyordu. |

**V1.0.68** (bütün logların kişi bazlı analizi: 43 bin tekrarsız satır, 524 oyuncu, 52 ajan; ayrıntı `OYUNCU_ANALIZI.md`)

| Değişiklik | Neden |
|---|---|
| **Zeus'a karşı sadece öldürücü atış** (zeus tutana MD = canı; can ≥ MD ise normal kafa kuralı). Bıçakta MD 30 kalır. | Zeus tutana MD 30: öldürmeyen 21 isabetten sonra 17 ölüm, 2 kill (11 oyuncu). Bıçakta kural işe yarıyor (14 kill / 15 ölüm). |
| **Extended gövde kuralı her koldan:** statik desenli, yerdeki rakibe kafaya nişanlı, hc ≥ 70 üç correction ıskası üst üste (hangi kol atarsa atsın) → o rakibe gövde. Kafa isabeti sayacı sıfırlar. | V1.0.67'nin merdiveni sadece "seri" atışlarında ilerliyordu; John Pork'a 12 atışın 3'ü seriydi, kural hiç tetiklenmedi. dominik / kent.apk / John Pork: yerde kafaya 0 isabet. Simülasyonda yerde kafa isabeti kaybı 0. |
| Duran (hız < 5, yerde) hedefin sahte kaydındaki correction ıskaları öğrenmeye sayılır | Duran hedefin sahte kaydında correction %25, genel %27 ile aynı; istisna yüzünden seri / extended hiç ilerleyemiyordu (103 istisna). |
| **Şarj bekletme yok:** yakında bıçak (260u) / zeus (420u) ya da elinde SCAR-20 / G3SG1 olan biri seni görüyorsa. Logda `sarj bekleme yok: zeus yakin / bicak yakin / oto goruyor` | Bekleme sırasında (DT kapalı, defensive yok) bıçak / zeus ölümleri; oto sniper isabetlerinin beklemedeyken 8/15'i kafa, diğer zamanlarda 19/128. |

**V1.0.67** (V1.0.66 logu: John Pork'a 12 atışta 1 isabet, 11 correction; kullanıcı: "yapabileceğimiz bir şey olmalı")

| Değişiklik | Neden |
|---|---|
| **Extended / roll desync'e gövde** ("Body vs extended/roll (all head angles missed)", Anti-Aim B, **varsayılan açık**): seri merdiveni bir rakipte bütün açıları (−58, +58, 0, −29, +29) kafada ıskalarsa o rakibe gövde zorlanır ve Min. damage gövde hasarının 1 altına iner (yalnız o rakip, seri penceresi boyunca; zorlanan açıyla ya da GS ile kafa vurulursa kalkar). Log: `<isim>: extended / roll suphesi (butun acilar kafada iskaladi): govde N, Min. damage gecici N-1` | John Pork ve kent.apk: statik, yan duruyor, LBY 0; GS, kendi kollar, seri ±58, 0, ±29 hepsi kafada ıskaladı. Extended / roll desync kafayı ve üst gövdeyi kaydırıyor, istemci hitbox'ları roll'suz; karın bölgesi en az kayan yer. Kafası hiçbir açıdan vurulamayan rakip için MD 100 kuralının tek istisnası. |

**V1.0.66** (üçüncü hata taraması + internetten exploit araştırması: 25 ajan; kullanıcı kuralı: ayar yapmıyor, iyi olan varsayılan açık, yasak sadece roll)

| Değişiklik | Neden |
|---|---|
| **Exploit: ping spike kapalı** ("Disable ping spike", Misc > Movement, **varsayılan açık**) | GameSense sürümündeki tüm atışlarda backtrack 0t: genişletilmiş backtrack penceresi hiç kullanılmadı. Spike açıkken skor tablosu pingi ~90 (kapalıyken 5–10), isabet aynı (%63.6 / %62), tahmin (prediction error) ıskası **%6.9 / %1**. Seçenek kapanınca / unload'da senin ayarın geri gelir. |
| **Exploit: scout / AWP'de Quick stop "Early"** ("Quick stop: Early for scout / AWP", Exploits, **varsayılan açık**) | Early, hitbox görünmeden önce frenlemeye başlar. Peek'te öldürücü hasarın görülmesinden atışa medyan 0.09 sn (~6 tick fren); "önce gördüm ama öldüm" 40 ölümün 36'sı tek mermi. Senin diğer quick stop seçimlerin korunur, "Duck" eklenmez (kafayı indirir), R8 hariç. |
| Kayıtlı config için tek seferlik taşıma (`nykle_win_gs_x66`): iki seçenek kapalı kaydedildiyse ilk yüklemede açılır | Kullanıcı ayar yapmıyor. |
| **Hata:** bıçak / zeus yakınken Min. damage 30, duvar / kat arkasındaki bıçaklıda ve **başka hedefe** de uygulanıyordu | Artık görüş çizgisi, ≤128 birim kat farkı ve hedefin kendisi olması gerekiyor (MD 100 gereksiz düşmesin). |
| **Hata:** merdivende, Legit (E) ve Spin'de yenen vuruşlar anti-brute faz istatistiğine giriyordu | O durumlarda faz uygulanmıyor; artık öğrenilmiyor. |
| **Hata (log):** ölüm satırı "sarj bekle"yi hiç yazmıyordu (558 ölüm satırında 0) | Bekleme durumu ölüm satırından önce siliniyordu. |
| **Hata (log):** `dbg ayarlar` quick stop seçeneklerini hep "?", ping spike'ı tuşu ve ms'si olmadan yazıyordu | Artık `quick stop true tus false [Early+Slow motion]`, `ping spike false tus true 100ms`. |
| "Disable ragdolls" FPS boost açılıp kapanınca görünür / gizlenir; dosya başı yorumları güncel | Küçük. |

Araştırmada elenenler: defensive AA flick, lag peek, havada LC kırma vb. script'te zaten var (defensive zorlama, havada teleport, air lag); "Duck" quick stop (kafayı indirir); ping spike'ı otomatik geri açma kuralı (backtrack ölçüsü spike'ın faydasını göstermez). Roll kapalı kalıyor.

**V1.0.65** (V1.0.64'ün ayrı incelemesi: 12 ajan, 5 gerçek bulgu; şarj düzeltmesinin "boş DT'yi dolu sanma" riski çürütüldü)

| Düzeltme | Neden |
|---|---|
| DM round yedeği sadece round_start hiç gelmeyen haritada | Normal haritada doğuş round_start'tan önce geliyor; 60 sn'den uzun roundlardan sonra round işleri iki kez çalışıyordu (A/B testi B'de takılırdı). |
| Jitter / kararsız desende hipotez adayı yine her tick bırakılır | V1.0.64'ün 1.5 sn bekleme kapısı bu temizliği de bekletiyordu: jitter'a geçen rakibe 1.5 sn eski Force body yaw kalıyordu. |
| Hafızadaki "son görülme" anti-brute zaman damgasıyla çakışmıyor (`mem_last`) | Round başında sıfırlanıp 0 yazılıyordu. |
| 64 kişilik sınır brute + resolver kayıtlarının birleşimine, en yeniden uygulanır | Brute tablosu önce doldurup yeni görülen resolver kayıtlarını atıyordu. |
| Atışsız bırakılan kol kararı en fazla 10 deneme sayılır ve sadece rakip seni gördüyse | Duvar arkasındaki rakip için her 10 sn bir deneme sayılıp keşfi oturum boyu kapatabiliyordu. |

**V1.0.64** (ikinci özellik denetimi: 14 ajan; sayı taraması, hiç görünmeyen log satırları, iç sistemler; her bulguya şüpheci)

| Düzeltme | Neden |
|---|---|
| **AA deseni değişimi durum oturmadan sayılmaz** (düşman yeni duruma geçince 1.5 sn) | Desen penceresi düşman başına, karşılaştırma durum başına: önceki durumun deseni (ör. Slow walk'taki jitter) Standing'in "desen değişimi" sayılıyordu. "deseni degisti / kararsiz" olaylarının yaklaşık yarısı buydu; her biri o durumda kendi resolver'ı ve hipotezleri **20 sn kapatıyordu**. Testte eski kod "kararsiz" yazıyor, yenisi yazmıyor. |
| **DT şarj tahmini düşükte takılırsa 2 sn sonra düzelir** (`sen ozeti`'nde "taban duzeltildi N kez") | v63b round 7: tüm round "DT %0 sh 0/14", **zorlanan defensive 0 tick**, yarım şarj 1700 tick. Taban DT doluyken kayınca onu düzeltecek boşaltmalar (zorlanan defensive, havada teleport) dolu şarj istediği için hiç olmuyordu. |
| **DM'de round işleri doğuşta** (son round başlangıcından 60 sn geçtiyse): round özeti, hafıza kaydı, şarj / brute sıfırlama, detaylı log özetleri | DM haritasında round_start hiç gelmiyor: v63b'de 8 dakika boyunca hiçbiri çalışmadı. Harita değişince de son roundun özeti artık yazılıyor. |
| Atış gitmeyen kendi kol kararı 10 sn sonra bırakılır (o kola deneme sayılır) | abs kolları hiç bırakılmıyordu ("taraf bilgisi 248 sn'dir yok"). |
| Hafıza (64 oyuncu) son görülme oturumuna göre: yüklemede en yeniler, oturumda en eski hatırlanan önce atılır | Hafıza dolu ve kimin atılacağı tablo sırasına kalmıştı. |
| Ölen oyuncu detay satırında "havada" yazılmaz | Ölümcül her vurulmada yanlış "havada vz+0" yazılıyordu. |

Denetimde temiz çıkanlar: loglardaki tüm sayılar (nan / inf yalnız eski V1.0.60 UCB primi), trig / sqrt / modulo kullanımları, fake duck koruması (v42'de tetiklenmiş), manuel ok tuşları, freestanding tuşu, istatistik sıfırlama, keşif oranı (V1.0.61'den beri çalışıyor). `math.random` tohumsuz ama etkisiz bulundu (oyun içi çekim sayısı oturumları ayırıyor).

**V1.0.63** (V1.0.62'nin ayrı incelemesi: 10 ajan, 3 gerçek bulgu)

| Değişiklik | Neden |
|---|---|
| Peek'teki kısa sahte kayıt beklemesi **sadece hedef havadayken** (yerde eskisi gibi beklenmez) | Yeniden sayım (31 atış): sahte kayda peek'te giden atışların fazla correction'ı tamamen havadaki hedefte (8 atışta 6, %75; gerçek kayıtta havadaki hedef %25). Yerde correction %22, normalle aynı; kalan ıskalar spread / ölüm, beklemek onları düzeltmez, sadece düelloyu geciktirir. |
| Log etiketleri ayrıldı: `bekleme: peek: N tick beklendi` (bekleme oldu), `duello, seni goruyor`, `duello / peek` (yerde, beklenmedi) | V1.0.62'de bekleyen atış da "bekleme yok" yazıyordu; sonraki logda ölçülemezdi. |
| Config yüklemesi roll'u "açıldı" saymaz | V1.0.62 sadece script yüklemesini düzeltmişti. |

**V1.0.62** (kullanıcı: northgard "predictlemiyorsun" dedi; 109 özelliğin denetimi: 23 ajan, her "çalışmıyor" iddiasına şüpheci)

| Değişiklik | Neden |
|---|---|
| **Peek atarken sahte kayıt beklemesi:** sen peek atarken düşman seni **görmüyorsa** sahte (defensive) kayıtta en fazla **4 tick** gerçek kayıt beklenir (sonra ateş serbest, 32 tick cooldown). Seni görüyorsa eskisi gibi beklenmez. | Tüm loglarda sahte kayda "bekleme yok: duello / peek" ile giden 24 scout atışı %37 isabet / %37 correction; normal kayıt %61 / %23, bekleyerek sahte kayda giden %63. "Predict" şikâyeti bu: peek'te defensive'in sahte kaydına sıkılıyordu. |
| "bekleme yok" sebebi aynı sahte kayıt penceresinde ilk gerçek sebebi korur (sonraki cooldown tick'leri "cooldown" diye ezmez) | Atış satırı yanlış sebep yazıyordu. |
| **Hata (denetim):** kendi resolver'ın LBY kolları hiç ölçülemiyordu: `lby-` kararı 23/23 kez atış gitmeden 1 sn içinde bırakıldı, 0 atışlı kol keşifte ve UCB'de hep yeniden seçildi (kilitlenme). Artık atışsız bırakılan karar o kola "deneme" sayılır (oturum içi); prim azalır, sıra diğer kollara / GS'ye geçer. | Denetim + şüpheci doğruladı. |
| **Hata (denetim):** roll açıkken her yüklemede kayıtlı özel Roll değerin 45'e eziliyordu; artık sadece senin kapalı → açık geçişinde | Roll sunucuda yasak, pratikte etkisiz ama hata. |

Denetimde çalışmadığı doğrulanan ama **bilerek değiştirilmeyenler** (varsayılanları zaten kapalı ya da veriyle kapatılmış; "Always use recommended settings" açıkken elle açılamıyorlar): `Defensive vs enemy peeks` (sadece "On peek" durumlarında çalışıyor, varsayılan durumların hepsi Smart; yerde defensive'in kafa payına etkisi ölçülmedi, açmak DT şarjını harcar), `Body 70+ while an enemy sees you` (MD 100'ü düşürür), `Air duck when seen`, `Snipers use DT in the air`, `Fake duck still`. Denetimde "çalışıyor" çıkanlar: resolver, hipotezler, seri, safe point, düşük can, kafa kuralı, sahte kayıt gövdesi, gerçek kayıt bekleme, unutma / istatistik sıfırlama butonları, FPS / aspect, AFK, AI peek, loglar.

**V1.0.61** (V1.0.60 logu: kısa oturum, 1 kill / 9 ölüm, 11 atışın hepsi `res gs`; seri ve kendi kollar hiç devreye girmedi)

| Değişiklik | Neden |
|---|---|
| **Hata (büyük):** kendi resolver kollarının UCB keşif primi oyunda `nan` çıkıyordu (`gs 0.728+nan abs+ 0.563+nan`); artık logaritma `math.log`'a dayanmadan hesaplanıyor (`hypothesis.own.ln`, hata < 1e-11) ve sayı değilse prim 0 | nan skor hiçbir kolu GS'nin önüne geçiremediği için lby+ / lby− / duvar / abs kolları **sadece %15 keşifle** seçiliyordu: tüm loglardaki 183 "bizim" kararının hepsinin "(deneme)" olmasının asıl sebebi bu. V1.0.60'taki random şüphesi yanlıştı: `dbg random` iki çekimin de 0.01–0.97 arası dağıldığını gösterdi. Testte `math.log` nan döndürecek şekilde ayarlanınca eski kodda 17 kontrol kırılıyor. |

**V1.0.60** (resolver; V1.0.59 logları: 52 kill / 42 ölüm, 106 atışta 44 kafa, 23 correction ıskası; kullanıcı: "kent fake yaw kullanıyor")

| Değişiklik | Neden |
|---|---|
| **Seri merdiveni:** düşman başına seride −58 ve +58 ikisi de tam açıyla kafada ıskalarsa body yaw **0**, o da ıskalarsa **−29**, sonra **+29**, sonra yine tam açı. 0 / yarım açıyla kafa vurulursa o basamak korunur. Log: `seri: -58 ve +58 ikisi de iskaladi (fake yaw / kucuk desync) -> body yaw 0` | kent.apk (statik, yan duruyor, `lby+0`): 15 atışta 9 correction; GS, abs+, abs−, seri −58 ve +58 hepsi ıskaladı. İki taraf da tutmuyorsa sorun taraf değil, açının büyüklüğü (fake yaw / küçük desync). Resolver'da 0 ve ±29 adayları vardı ama seri sadece ±58 arasında gidip geliyordu. |
| **Hata:** kendi resolver kol seçiminde keşif çekimi `random()` yerine `random(0, 999999) / 1e6` | Tüm loglardaki 183 "bizim" kararının hepsi "(deneme)" idi: kol hep en az denenen koldu, öğrenilen skorlar hiç kullanılmıyordu. Yüklemede `dbg random:` satırı iki çekimi ölçer. |
| Kol kararları skorlarıyla yazılır (`| r 0.412/0.15 tercih | gs 0.668+0.081 abs+ ...`); GS'nin tercih edildiği kararlar da (`GS resolver'i (tercih)`) | Önceden GS seçimi sessizdi; kolların gerçekten GS'den iyi olup olmadığı ölçülemiyordu. |
| **Hata (log):** öldüren isabet düello satırında sayılır | `player_death`, `aim_hit`'ten önce geldiği için v58'de 9/9 "oldurdun" düellosu "0 isabet" yazıyordu. |

Ayrı inceleme (13 ajan) 5 gerçek hata buldu, hepsi düzeltildi: tam açıyla kafa vurunca eski ıskalar silinir (yoksa tek ıska 0°'a düşürüyordu), tam açıyla kafa merdiveni sıfırlar, süresi dolan seri eski basamağıyla geri gelmez, hipotezin 0° kafa isabeti seriyi bitirmez, aynı GS kararı tekrar yazılmaz, bomba / bıçak öldürmesi düelloda isabet sayılmaz. Testte rastgele sayı tekrarlanabilir.

Resolver araştırmasında elenenler (83 ajan, her öneriye 2 şüpheci): düşman başına "kanıtlanmış kol" kilidi (sonraki atışlar 4/4 isabet, veri desteklemiyor), keşif oranını düşürmek (kollar ile GS arasında anlamlı fark yok: statik düşmanda %62 / %72, ~1.1 SE), jitter tarafı zorlama (örnek yetersiz; önce log).

Test: `tests/run_gs_smoke.sh` (GameSense API'sinin sahte hali, Redis Lua 5.1): yükleme, 200 tick, olaylar ve V1.0.22–1.0.70 kuralları (260 kontrol; V1.0.60'ın 7 yeni kontrolünün eski kodda kırıldığı doğrulandı; V1.0.58'in taşıma kontrolünün eski kodda kırıldığı doğrulandı; V1.0.47'nin yeni kontrollerinin eski kodda kırıldığı doğrulandı; V1.0.34'ün 8 yeni kontrolünün eski kodda kırıldığı doğrulandı, teleport alt sınırı test ortamında tetiklenmiyor). Hafızada GS kolu 40/45 ile tohumlanır: lby+ seçimi ancak UCB primiyle geçer.

## Notlar

- Neverlose'un **CS:GO** Lua API'sine göre yazıldı. CS2 Neverlose'un API'si farklı, orada çalışmaz.
- Oyunda test edemedim. Neverlose API'sini taklit eden sahte bir ortamda bütün durumlar, exploit seçimleri, defensive modları (Smart dahil), Safe recharge, zıplama tahmini, hidden açılar, görüş tespiti, auto peek, X-Way, düşman başına anti-brute, resolver, body aim, düşman peek tahmini, peek'e karşı defensive, havada teleport, scout'ta sadece öldürecek atış (min damage), sniper exploit öğrenmesi, hareket grubu başına faz öğrenmesi, AI peek (duvar, uçurum, hasar, yön, zaman aşımı, geri dönüş, teyit, takip, başka düşmanın görmesi), sahte (defensive) kayda giden ıskanın öğrenilmemesi, jitter'ın sadece gerçek kayıtlardan ölçülmesi, düşman fake duck tanıma, sunucuda geçmeyen atış koruması, resolver paneli (yüzdeler, sürükleme, boyut), anti-backtrack, otomatik freestanding, ateş edene dönme, fake duck koruması, önerilen ayarların korunması, vuruldum/ıska/atış kaydı, istatistik paneli, legit AA, spin, merdiven, indikatör renkleri, menü sekmeleri / grupları ve görünürlüğü test edildi. Eksik menü öğesi, eksik API (`rage`, `utils.trace_bullet`) ya da Neverlose'un kabul etmediği bir değer olduğunda da çökmediği test edildi.
- V1.0'da menü yeniden adlandırıldığı için config'indeki lua ayarları (özellikle Visuals: renkler, panel yeri) varsayılana dönebilir; AA / exploit / resolver ayarları zaten önerilen değerlerde tutulur. Kendi değerlerini ayarladıysan güncellemeden sonra bir göz at.
- Sadece HvH sunucularında kullan. Resmi maçlarda (MM) rage anti-aim çok kısa sürede ban yedirir.
