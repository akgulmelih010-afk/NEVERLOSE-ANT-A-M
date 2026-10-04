# ANT-A-M v4 — Neverlose HvH anti-aim, exploit ve resolver lua'sı

Neverlose (CS:GO) için durum (state) bazlı anti-aim ve exploit lua'sı. Sadece HvH sunucuları için.

**Kurar kurmaz çalışır.** Bütün ayarlar hazır gelir; exploitler ve defensive her durumda kendiliğinden doğru moda geçer. İstersen sonradan ince ayar yaparsın.

## Kurulum

1. `antiaim.lua` dosyasını Neverlose'un script klasörüne at. Menüde **Scripts** sekmesinden klasörü açabilirsin, genelde `Counter-Strike Global Offensive/nl/scripts` olur.
2. Oyunda Neverlose menüsü → **Scripts** → `antiaim` → **Load**.
3. Konsolda `[ANT-A-M] v4.1 yuklendi` gibi bir satır çıkar; güncelledikten sonra numaranın değiştiğini buradan kontrol et.
4. Solda **ANT-A-M** sekmesi çıkar. İçinde **Anti-Aim**, **Resolver** ve **Visuals** sekmeleri var. Ayarlar Neverlose config'inle birlikte kaydedilir.
5. Şu üç şeyi tuşa bağla (öğeye sağ tık → bind): **Manual yaw** (sol/sağ), **Freestanding**, **Static inverter**.

> Konsolda `[ANT-A-M] 12 ayar onerilen degerine donduruldu (orn. Fake duck Left limit 60, onerilen 58)` gibi bir satır çıkarsa Neverlose config'inden eski değerler yüklemişti ve script onları önerilen değerlere geri aldı (aşağıda **Always use recommended settings**). `Always use recommended settings kapali: ...` yazıyorsa o ayar kapalı ve ayarların önerilenden farklı; açmak için Main sekmesine bak.
>
> Konsolda `[ANT-A-M] createmove hata verdi: ...` gibi bir satır çıkarsa bir olay fonksiyonu beklenmedik bir değerle karşılaştı demektir. Script durmaz; hata her olay için bir kez yazılır. O satırı bana at.
>
> Konsolda `[ANT-A-M] menude bulunamadi: ...` ya da `[ANT-A-M] ... ayarlanamadi: ...` yazısı çıkarsa Neverlose sürümünde o menü öğesinin ya da seçeneğin adı farklı demektir, ya da ayar o an kilitliydi. Script çökmez: reddedilen değeri 5 saniye sonra tekrar dener, bu arada o ayarı senin kendi değerine bırakır, gerisi çalışmaya devam eder. Yazıyı bana at, düzeltirim.

## Duruma göre exploit (varsayılanlar)

Script her tick'te hangi durumda olduğunu bulur ve o durumun AA'sını ve exploit ayarını uygular. **Auto exploit** açıkken (varsayılan) DT'yi kendisi açar, senin bind'ine gerek kalmaz.

| Durum | Ne zaman | Exploit | Defensive | Hidden pitch / yaw |
|---|---|---|---|---|
| Standing | Yerde duruyorsun | DT | On peek | Up / Sideways |
| Moving | Yürüyorsun / koşuyorsun | DT | Smart | Up / Sideways |
| Slow walk | Slow walk tuşu basılı | DT | Smart | Up / Sideways |
| Crouching | Eğilmiş duruyorsun | DT | On peek | Up / Sideways |
| Crouch move | Eğilerek yürüyorsun | DT | Smart | Switch / Sideways |
| Peek | Peek Assist (quick peek) tuşu basılı ya da hareket ederken düşmanın görüş alanına giriyorsun | DT | Smart | Up / Sideways |
| Air | Havadasın | DT | Smart | Up / Spin |
| Air crouch | Havada eğiliyorsun | DT | Smart | Up / Random |
| Fake duck | Fake duck tuşu basılı (peek'ten de önce gelir). Bıçak / zeus tutan düşman yakındaysa fake duck bırakılır (Main → **Release fake duck near knife**) | — (fake duck'ta DT/HS çalışmaz) | — | — |
| Manual | Manuel yaw açık | DT | On peek | — |
| Freestanding | Freestanding kafanı bir duvarın arkasına saklayabildi | DT | On peek | — |
| Safe head | Bıçak/zeus ile havada eğiliyorsun ya da düşmandan yüksektesin ve kafanı görebiliyor | DT | On peek | — |

Scout, AWP ve R8'de exploit tablodaki DT yerine Hide shots'tır (aşağıda **Snipers**).

- **Smart** (hareket ederken ve havada varsayılan): "On peek"in aynısı, üstüne script düşmanın kafana mermi geçirebildiğini (ya da 0.2 sn içinde geçirebileceğini) gördüğü anda DT doluysa defensive'i kendisi zorlar (`force_defensive`). Görüş kesilince 8 tick daha zorlar; aynı görüş 1 saniyeden uzun sürerse durur (peek anı geçti), görüş kesilip yeniden başlayınca tekrar kurulur. Neverlose'un modu hep "On Peek" kalır, yani durumlar arasında mod değişip DT boşalmaz. Neden: oyun loglarında `Air | DT dolu, DEF yok` ve `Peek | DT dolu, DEF yok` isabetleri vardı; Neverlose'un peek tespiti o anları kaçırmıştı. Dururken ve eğilip beklerken "On peek" kalır: açı tutan sensin, orada ilk atışın hızı daha önemli. Hide shots'ta Smart, On peek ile aynı çalışır (Break LC).
- **On peek**: Neverlose peek attığını kendisi algılar ve tam o an defensive'e geçer. Yani yerde peek atınca exploit kendiliğinden devreye girer. Hide shots'ın Neverlose'da böyle bir seçeneği yok; HS kullanırken (ör. scout'ta) Peek durumundayken ya da düşman kafanı görüyor / birazdan görecekken (havadan peek dahil) "Break LC" açılır ve yarım saniye açık kalır. Böylece HS'de de peek anında defensive olur.
- **Fake duck**: Fake duck'ta exploit çalışmaz ve paketler ~14 tick boğulur; jitter ~0.2 sn'de bir dönüp tahmin edilebilir olur. Bu yüzden ayrı bir durum: varsayılanı static body yaw + "Peek Fake" body freestanding (sahte kafa peek yönüne, gerçek kafa siperin arkasına). Oyun loglarında fake duck peek'te, özellikle fake duck'la ateş ettikten hemen sonra kafadan vurulma görüldü; fake duck'ta Hide shots da çalışmadığı için ateş anındaki açın açıkta kalır. Log satırında `FD` yazar. v4.1 öncesi loglarda fake duck'ta hep `sol 60` görünüyordu; varsayılan 58 ve body freestanding'le taraf değişmeli. Yani fake duck, Fake duck durumu eklenmeden önce kaydedilmiş bir config'in (o sıradaki Manual'in: static, sol, 60, freestanding yok) değerleriyle çalışıyordu: tek taraflı, tahmin edilebilir bir AA. Artık önerilen ayarlar oyun sırasında da korunuyor (Main → **Always use recommended settings**).
- **Auto peek** (varsayılan açık): Script düşmanın kafana mermi geçirebilip geçiremediğini her 2 tick'te hesaplar (şimdi ve 0.2 saniye sonraki konumun için). Havadayken kafanın yüksekliği de tahmin edilir (zıplama hızı ve yerçekimi), yani kutu üstünden zıplayınca kafa siperin üstüne çıkmadan önce görüş "birazdan" olarak algılanır; zıplama tuşuna basıldığı tick'te bile. Ayrıca her güncellemede tehdit dışındaki düşmanlardan biri sırayla kontrol edilir (tek ek iz); yandan bakan bir düşman da auto peek'i, Smart defensive'i, Hide shots'ın Break LC'sini ve Safe recharge'ı tetikler. Bir düşmanın görüşü 12 tick geçerli sayılır; ölen, dormant olan ya da listeden çıkan düşmanın görüşü hemen silinir. Hareket ederken görüş alanına giriyorsan, peek assist tuşuna basmasan da Peek durumuna geçer. Görüş kesilince 8 tick daha Peek'te kalır. Durursan açı tutuyorsun demektir, normal duruma döner.
- **Always on**: Defensive sürekli açık (Lag Options = Always On, HS'de Break LC). **Hiçbir durumda varsayılan değil:** oyun loglarında zıpladıktan, eğilip yürümeye ya da peek'e geçtikten ~0.4 sn sonra (defensive modu "Always on"a dönünce) DT %0'a düşüyor ve vurulma tam o sırada geliyordu. Varsayılanda bütün durumlar "On peek" ya da "Smart" kullanıyor; ikisinde de Neverlose'un modu "On Peek" kaldığı için durumlar arasında mod hiç değişmiyor. İstersen builder'dan bir durum için açabilirsin.
- **Tick based**: Her N komutta bir defensive zorlanır (`force_defensive`).
- **Off**: Defensive zorlanmaz. Kendi Neverlose ayarın "Always On" olsa bile Neverlose'un en sakin modu olan "On Peek"e çekilir.
- **Hidden pitch / yaw**: Defensive tick'lerinde sunucuya giden sahte açılar.
- Elinde bomba (grenade) varken, fake duck yaparken ve merdivende defensive kapanır.
- E'ye basınca (legit AA) ve spin sırasında DT kapatılmaz; kapatıp açmak her seferinde yeniden şarj demek.
- Durumlara farklı exploit seçersen (ör. yerde DT, havada HS) her geçişte DT yeniden şarj olur. Hepsini DT'de bırakmak en güvenlisi.

Her durumun bu ayarları **Builder**'da, durumu seçince altta **Exploit** başlığında görünür.

## Menü

### Main
| Ayar | Varsayılan | Ne işe yarar |
|---|---|---|
| Enable | Açık | Lua'yı açar/kapatır. Kapatınca Neverlose'un kendi ayarların geri gelir. |
| Always use recommended settings | Açık | Neverlose lua ayarlarını config'e kaydeder; eski bir sürümle kaydedilmiş config eski değerleri geri getirir. Bu açıkken bütün AA, exploit, builder ve resolver ayarları o sürümün önerilen değerlerinde **tutulur**: script yüklenince, config yüklenince ve oyun sırasında saniyede bir kontrol edilir, farklı olan geri alınır ve konsola kaç ayarın düzeltildiği bir örnekle yazılır (en fazla 30 sn'de bir). Neden: sadece yükleme anında dönmek yetmiyordu, Neverlose config değerlerini script'ten sonra da uygulayabiliyor (loglarda Fake duck eski değerlerle çalışıyordu). Bind'lenen ayarlara (Manual yaw, Freestanding, Static inverter), builder'daki durum seçiciye ve Visuals'a dokunmaz. Kendi ayarlarını kullanmak istersen kapat; kapalıyken hiçbir ayar değiştirilmez, yüklemede kaç ayarın önerilenden farklı olduğu bir kez yazılır. |
| Pitch | Down | `Fake Down/Up` sadece untrusted'a izin veren sunucularda. |
| Yaw base | At Target | En yakın düşmana göre döner. |
| Manual yaw | Off | Sol / Sağ / İleri. Tuşa bağla. |
| Freestanding | Kapalı | Kafayı duvar tarafına saklar. Tuşa bağla. Kafan yine de açıkta kalıyorsa (freestanding saklayamadıysa) normal jitter'a döner. Dişli simgesinden: havada kapalı (varsayılan), eğilirken / slow walk'ta / yürürken kapat seçenekleri. |
| Static inverter | Kapalı | Body yaw `Static` olan durumlarda desync tarafını çevirir. |
| Safe head | Açık | Bıçak/zeus ile havada eğilirken kafayı sabitler. Düşmandan 35+ birim yüksekteyken de sabitler, ama sadece düşman kafanı gerçekten görebiliyorsa (duvar arkasındaysan gerek yok). |
| Anti-bruteforce | Açık | Düşman mermisi kafanın 40 birim yakınından geçince ya da vurunca 3 faz arasında döner. Static body yaw'da tarafı çevirir; jitter'da desync'i yaw sırasının tersine kaydırır, böylece resolver'ın öğrendiği desen bozulur. 2. ve 3. fazda kafa ayrıca ±15° kayar; desync hiçbir fazda düşük desync'e inmez (resolver'lar ıskadan sonra bunu dener). Faz **her düşman için ayrı** tutulur (her resolver ayrı öğrenir) ve kafanı gören düşmanınki uygulanır: AA'nın baktığı tehdit seni görmüyor ama yandan başka biri görüyorsa onunki, kimse görmüyorsa tehdidinki. Aynı düşmanın DT çift atışı tek atış sayılır. Iskalarla ilerleyen faz 6 saniye sonra, round başında ya da ölünce biter. **Hafıza:** Bir düşman kafanı hangi fazda vurduysa, ona karşı bir sonraki fazdan başlanır ve bu round'lar arası kalır (Neverlose resolver'ı da oyuncuları round'lar boyunca hatırlar). Gövde/bacak isabetleri hafızayı değiştirmez. Hafıza Steam ID ile tutulur, harita değişince de kalır (aktif faz sıfırlanır); Resolver sekmesindeki **Forget learned enemies** düğmesi siler. |
| Avoid backstab | Açık | Bıçaklı düşman arkana gelince döner. |
| Release fake duck near knife | Açık | Bıçak ya da zeus tutan canlı bir düşman 260 birimden yakınsa fake duck'ı kapatır (bind'in basılı olsa da); 360 birimden uzaklaşınca ya da silah değiştirince bind'in yine geçerli olur. Fake duck'ta eğik ve yavaşsın, DT/HS çalışmaz. Oyun loglarında fake duck'tayken bıçakla üç kez arka arkaya vurulup ölündü. Konsola `fake duck birakildi: isim bicak/zeus ile 180 birim yakinda` yazar. |
| Legit AA on use | Açık | E'ye basılı tutarken AA çalışmaya devam eder. Kapı açma ve silah alma bozulmaz. CT olarak bomba ya da rehine yanındaysan karışmaz. |
| Spin when idle | Açık | Hiç canlı düşman kalmayınca spin yapar. Warmup'ta spin isteğe bağlı (varsayılan kapalı, çünkü HvH sunucularında warmup'ta da savaşılıyor). |

### Exploits
| Ayar | Varsayılan | Ne işe yarar |
|---|---|---|
| Auto exploit | Açık | Her durumun exploit seçimini (DT / HS / Binds) uygular. Kapatırsan DT/HS'yi kendi bind'lerin yönetir. |
| Auto peek | Açık | Hareket ederken düşmanın görüş alanına girince Peek durumuna geçer (yukarıya bak). |
| Snipers (SSG08/AWP/R8) | Hide shots | Elinde scout, AWP ya da R8 varken DT yerine Hide shots kullanılır (durumun exploit'i `Binds` değilse). Bıçak, zeus, bomba ve C4'e geçince exploit değişmez, son tuttuğun silahınki korunur (scout → bıçak → scout geçişinde DT/HS kapanıp açılıp DT'yi boşaltmasın diye). Bolt-action tüfek ve R8 DT ile çift atış yapamaz; DT her atıştan sonra boşalıp uzun süre şarj olur ve o sırada ne defensive ne koruma vardır. Hide shots ateş ettiğin anki açını gizler, defensive "Break LC" ile devam eder. Oyun loglarında scout'la ateş ettikten 0.05-0.35 sn sonra, DT %0'dayken kafadan vurulma tekrar tekrar görüldü. `Same as state` ile kapatılır. |
| Safe recharge | Açık | Exploit yeniden şarj olurken oyuncu sunucuda ~14 tick yerinde donar. Şarj iki durumda sıfırdan başlar: ateş ettikten sonra ve fake duck'ı bıraktığında (fake duck'ta exploit çalışmaz; fake duck peek'ten kalkınca hâlâ görüş alanındasın). Düşman kafanı görüyorken (ya da birazdan görecekken) script şarjı bekletir (`rage.exploit:allow_charge`); siperin arkasına geçince dolar. Hep görülüyorsan 1.2 sn sonra yine de şarj olur, exploit'siz kalmazsın. Neden: oyun loglarında peek'te ateş ettikten 0.05-0.36 sn sonra, `DT %0` iken kafadan vurulma tekrar tekrar görüldü. DT'de her zaman çalışır. Hide shots'ta sadece Neverlose'un şarj değerinin HS'de de dolup boşaldığı görüldükten sonra çalışır (değer sadece DT'ye aitse HS'ye hiç karışmaz); o zaman log'da `HS %40` gibi şarj yüzdesi de yazar. Fake duck basılıyken karışmaz. Log satırında `sarj bekle` yazar. Bu Neverlose sürümünde `allow_charge` yoksa sessizce devre dışı kalır. |
| Hidden spin speed | 10 | Hidden yaw `Spin` hızı. |

### Builder
`State` listesinden durumu seç. Her durum kendi ayarlarıyla gelir. Hareket durumlarında `Override` kapatılırsa o durum **Global**'in AA ayarlarını kullanır (exploit ayarı yine kendisinden gelir). Varsayılan olarak bütün `Override`'lar açık olduğundan Global'i değiştirmek bir şey yapmaz; tek bir ayarla oynamak istersen durumların `Override`'ını kapat.

| Ayar | Ne işe yarar |
|---|---|
| Yaw mode | `L&R` (varsayılan) ya da `X-Way`. |
| Yaw left / right | `L&R`'de desync sola ve sağa bakarken eklenen yaw. İkisi farklı olunca yaw, body yaw ile **senkron** jitter yapar. |
| Ways / Way 1-5 | `X-Way`'de yaw her flip'te sıradaki açıya geçer (3-5 açı, varsayılan -30 / 0 / 30 / -15 / 15). Desync her flip'te taraf değiştirdiği için açı-taraf eşleşmesi sürekli kayar. |
| Yaw randomize | Her flip'te yaw'a ± bu kadar rastgele açı ekler. |
| Yaw modifier / offset | Neverlose'un kendi modifier'ları (Center, Offset, Random, Spin, 3-Way, 5-Way). Dişliden randomize. |
| Body yaw | `Jitter`: taraf lua tarafından paket döngüsüne göre çevrilir. `Static`: Static inverter'a göre. `Off`: desync yok. Dişliden: Avoid overlap, body freestanding, delay ve limit randomize. Jitter'lı durumlarda **Delay randomize varsayılanı 1**: taraf her dönüşte 1 ya da 2 paket tutulur. Tam sırayla dönen jitter'ı resolver'lar yakalar (örnek resolver son 4 açı değişiminin 3'ü yön değiştiriyorsa "jitter" deyip tarafı eşliyordu); rastgele bekleme bu sırayı bozar. |
| Jitter delay | Kaç paket döngüsünde bir taraf değişsin. Sadece DT/HS aktifken uygulanır. |
| Left / Right limit | Desync miktarı (0-60). |
| Exploit / Defensive / Hidden | Yukarıdaki tabloya bak. |

### Resolver
| Ayar | Varsayılan | Ne işe yarar |
|---|---|---|
| Adaptive resolver | Açık | Düşman başına çalışan resolver katmanı (aşağıya bak). |
| Console log | Açık | Resolver seviyesi değişince konsola yazar. Örnek: `resolver: isim Air iska (correction) \| seviye 1 -> safe points Prefer`. |
| Forget learned enemies | — | Steam ID ile hatırlanan bütün anti-brute fazlarını ve resolver seviyelerini siler. |
| Body aim only if lethal (snipers) | Açık | Scout, AWP ve R8'de: hedefin canı göğüs vuruşuna yetiyorsa Body Aim `Prefer` (resolver'a bağlı olmayan kesin öldürme, göstergede `BAIM`), yetmiyorsa senin `Prefer`'in kaldırılıp `Default` yapılır ki aimbot kafayı geçmesin. Hasar CS:GO silah değerlerinden hesaplanır: zırh (scout göğüs 88 → zırhlıya 75, mide 93) ve mesafeyle düşüş. Göğüs ölçü alınır, çünkü aimbot gövdeye ateş edince mideye değil göğse gelebilir. Senin kendi `Force`un (baim tuşu) hiç değiştirilmez; diğer silahlara dokunulmaz. Neden: oyun loglarında scout'la tam canlı düşmanlara 87-93 gövde vuruşları vardı; düşman hayatta kalıp kafadan vuruyordu. |
| Shot log (console) | Açık | Her aimbot atışını tek satır yazar: `atis: isim \| Air \| HP 100 \| hedef head 98 \| iska correction \| SP Force \| BA Default \| bt 2t \| hc 81% \| sen ssg08` → düşman, ateş anındaki durumu ve canı, aimbot'un hedeflediği bölge ve beklediği hasar, sonuç (isabet bölge/hasar ya da ıska nedeni), ateş anındaki Safe Points ve Body Aim, backtrack (tick), isabet şansı ve senin silahın. Resolver'ı ayarlamak için bu satırları bana at. |

**Nasıl çalışır:** Açıları yine Neverlose'un kendi resolver'ı çözer. Bu katman her aimbot atışının sonucuna bakar (Neverlose'un `aim_ack` olayı). `correction` = mermi isabet edecekti ama resolver düşmanın açısında yanıldı. Seviye **düşman başına ve düşmanın hareket durumu başına** (`Standing` / `Moving` / `Crouch` / `Air`) tutulur: AA lua'ları her durumda farklı ayar kullanır, havada çözülemeyen biri yerde çözülebilir. Atışın hangi durumda yapıldığı ateş anında kaydedilir; sonuç geldiğinde düşman inmiş ya da eğilmiş olsa bile ıska doğru duruma yazılır. O durumda son 4 atıştaki `correction` ıskası sayısı seviyedir:

| Seviye | Ne zaman | Safe Points |
|---|---|---|
| 0 | Resolver ıskası yok | Senin kendi ayarın |
| 1 | 1 resolver ıskası | `Prefer`: güvenli nokta varsa ona ateş eder |
| 2 | 2+ resolver ıskası | `Force`: sadece desync hangi taraftaysa da isabet eden noktalara ateş eder |

- İsabetler son 4 atışa girip eski ıskaları dışarı ittikçe seviye kendiliğinden düşer. Spread, tahmin hatası, backtrack gibi resolver dışı ıskalar sayılmaz.
- Düşmanın o anki durumunda hiç sonuç yoksa diğer durumlardaki son sonuçlar ön bilgi olur, ama en fazla `Prefer`.
- **Force takılırsa:** `Force`'ta düşmanın güvenli noktası yoksa aimbot hiç ateş etmez (ve sonuç gelmediği için seviye de düşmez). Düşman seni görürken 1 saniye boyunca ona hiç ateş edilmediyse `Prefer`'e inilir ve konsola `safe point bulunamadi` yazılır; o durumun bir sonraki atış sonucu seviyeyi yeniden belirler.
- Seviye **sadece o düşmana ve onun o anki durumuna karşı** uygulanır: aimbot az önce (1.5 sn içinde) kime ateş ettiyse onunki, yoksa AA'nın baktığı tehdidinki. Göstergede `RES 1` / `RES 2` yazar.
- Senin kendi Safe Points ayarın hiç düşürülmez (zaten `Force` ise dokunulmaz). Body Aim'e sadece scout / AWP / R8'de **Body aim only if lethal** dokunur; kendi body aim tuşun (`Force`) aynen çalışır.
- Seviye **Steam ID ile** tutulur: round'lar arası ve harita değişince de kalır (HvH sunucularında oyuncular harita değişince kalır, slot numaraları değişir). Steam ID'si olmayan botlar isimle tutulur. En fazla 64 oyuncu hatırlanır; dolunca en uzun süredir görülmeyen unutulur. **Forget learned enemies** düğmesi hepsini siler.
- **Neden düşmanın açısını Lua'dan ezmiyor:** Neverlose'un açık Lua API'si sadece gövde dönüş parametresini (`m_flPoseParameter[11]`) yazabiliyor; modelin ayak yönü Neverlose'un kendi çözümünden geliyor ve ikisi tutmayınca hitbox'lar yeni bir yanlış açıya kayar. Ayak yönünü yazmak için FFI ile oyun belleğinde sabit ofsetlere yazmak gerekiyor: bu sadece tek bir `client.dll` sürümünde geçerli ve Neverlose'un atış kayıtlarına etkisi Lua'dan doğrulanamıyor (bunu yapan örnek resolver'ın kendi başlığında da "UNVERIFIED" yazıyor). Bu yüzden açıyı Neverlose'a bırakıp, onun yanıldığı düşmanda ve durumda güvenli noktaya geçmek daha sağlam.
- **Başka bir resolver script'iyle birlikte çalıştırma** (ör. kenar çubuğundaki `RESOLVER`). İki script aynı ayarlara ya da animasyonlara karışırsa hangisinin işe yaradığı anlaşılmaz.

### Visuals
Nişangahın altında: desync çubuğu, aktif durum, DT / HS / FS / DEF / VIS, anti-brute fazı (`BRUTE n`), resolver seviyesi (`RES n`) ve scout / AWP / R8'de gövde vuruşu öldürüyorsa `BAIM`. Yanlarda manuel oklar ve desync tarafı. Renkler ayarlanabilir; dürbünle bakarken indikatör kenara kayar.

- **DT** / **HS**: beyaz = şarjlı, turuncu = şarj oluyor (ya da Safe recharge bekletiyor), soluk = kapalı. HS'de turuncu sadece şarj değeri HS'yi takip ediyorsa görünür.
- **DEF**: renkli = defensive penceresi şu an gerçekten açık, beyaz = script defensive'i şu an zorluyor (Smart, HS'de Break LC) ya da bu durumda sürekli açık, soluk = Neverlose'un peek tespitine bırakıldı. Pencere tickbase'den iki yolla tespit edilir: tickbase gördüğümüz en yüksek değerin gerisine düştüyse ya da DT doluyken iki paket arasında geri gittiyse veya 1'den fazla ileri sıçradıysa.
- **VIS**: renkli = tehdit ya da başka bir düşman kafanı şu an görüyor, beyaz = tehdit birazdan görecek, soluk = görmüyor.

| Ayar | Varsayılan | Ne işe yarar |
|---|---|---|
| Hit log (console) | Açık | Seni vurunca konsola yazar. Örnek: `vuruldun: head -293 ssg08 \| Peek \| faz 1 \| sag 58 \| DT %40, DEF yok, atis 0.12s, mod 0.05s \| sen r8 \| isim` → bölge, hasar, düşmanın silahı, durum, mermi atıldığı andaki anti-brute fazı, desync tarafı ve miktarı, DT durumu (`dolu` / şarj yüzdesi / `yok`, HS'de şarj biliniyorsa `HS %40`; yanında `(bind)` yazıyorsa o exploit'i script değil senin kendi bind'in belirliyor), defensive penceresi o an açık mıydı (`(zorla)` = Smart o an defensive istiyordu; `DEF yok (zorla)` görürsen zorlama işe yaramamış demektir, bana at), Safe recharge şarjı bekletiyor muydu (`sarj bekle`), kendi son atışından bu yana geçen süre (5 sn'den eskiyse `atis yok`) ve script defensive modunu az önce değiştirdiyse ne kadar önce (`mod`, sadece son 2 sn), senin o an tuttuğun silah, en sonda parantez içinde saldıran: hareket durumu, AA'nın baktığı tehdit mi (`AA hedefi` / `AA hedefi degil` / `tehdit yok`) ve script'in izlerine göre kafanı ne kadar süredir görüyordu (`gordu 0.31s`; `gormedi` = izler görmedi: duvarın arkasından ya da diğer düşmanlar sırayla kontrol edilirken sıra ona gelmeden vurdu). Kafanın yanından geçen ıskaları da aynı bilgilerle yazar. Molotof, yangın ve el bombası hasarı yazılmaz ve istatistiğe girmez; bıçak ve zeus hasarı yazılır ama istatistiğe ve anti-brute'a girmez. |
| Stats panel | Kapalı | Ekranın solunda her durum için `isabet / kafa / ıska / DT / DEF`. Sen ateş etmezken (atıştan sonraki 1 sn ve Safe recharge'ın bilerek beklettiği süre hariç): **DT** = DT'nin yüzde kaç dolu olduğu (düşükse o durumun ayarları DT'yi boşaltıyor), **DEF** = exploit hazırken defensive penceresinin yüzde kaç açık olduğu ("Smart" ya da "Always on" bir durumda düşükse defensive gerçekten çalışmıyor). Altında **AIM** satırı: senin aimbot atışların, isabetler ve ıskaların nedeni (`CORR` = resolver, `SPREAD` = isabet şansı, `OTHER` = tahmin hatası, backtrack, kayıtsız atış vb.). `CORR` yüksekse resolver, `SPREAD` yüksekse hit chance sorunu vardır. Ölünce de görünür. |
| Reset stats | — | İstatistikleri sıfırlar. |

## Vuruluyorsan ne yapmalı

Hiçbir anti-aim seni vurulmaz yapmaz. İyi resolver'lar ve baim yine vurur. Ama şunlar çok fark eder:

- Önce varsayılanlarla oyna. **Stats panel**'i aç ya da konsoldaki `vuruldun:` satırlarına bak: hangi durumda kafadan vurulduğun orada yazıyor. Sadece o durumu değiştir. Paneli ya da birkaç satırı bana atarsan birlikte ayarlarız.
- **Kafadan vuruluyorsan** o durumun yaw left/right değerlerini değiştir (ör. -23/51 yerine -35/40), `Jitter delay`'i 2-3 yap ya da biraz `Yaw randomize` ekle.
- **Havada vuruluyorsan** Air durumunda hidden yaw'ı `Random` ya da `Sideways` dene.
- **Duvar dibinde bekliyorsan** freestanding ya da manuel yaw kullan.
- **Fake duck'ı eğilme tuşuna (CTRL) bağlama.** Fake duck basılıyken Neverlose DT ve HS'yi kapatır; scout'ta Hide shots ve bütün defensive'ler de gider. Log'da `FD, DT %0 (bind)` görüyorsan o an fake duck basılıydı. Loglarda `Air crouch | ... FD` satırları var: havada fake duck'ın hiçbir faydası yok, yani fake duck büyük ihtimalle eğilme tuşuna bağlı ya da açık kalan bir toggle. Fake duck'ı sadece bilerek fake duck peek atacağın ayrı bir tuşa (ör. mouse yan tuşu) ve "hold" moduna al.
- Geniş peek atma; quick peek (Peek Assist) kullanınca Peek durumu ve defensive kendiliğinden devreye girer.

## Notlar

- Neverlose'un **CS:GO** Lua API'sine göre yazıldı. CS2 Neverlose'un API'si farklı, orada çalışmaz.
- Oyunda test edemedim. Neverlose API'sini taklit eden sahte bir ortamda bütün durumlar, exploit seçimleri, defensive modları (Smart dahil), Safe recharge, zıplama tahmini, hidden açılar, görüş tespiti, auto peek, X-Way, düşman başına anti-brute, resolver, body aim, fake duck koruması, önerilen ayarların korunması, vuruldum/ıska/atış kaydı, istatistik paneli, legit AA, spin, merdiven, indikatör renkleri ve menü görünürlüğü test edildi. Eksik menü öğesi, eksik API (`rage`, `utils.trace_bullet`) ya da Neverlose'un kabul etmediği bir değer olduğunda da çökmediği test edildi.
- Script'e yeni menü öğeleri eklendikçe config'indeki bazı lua ayarları varsayılana dönebilir. Kendi değerlerini ayarladıysan güncellemeden sonra bir göz at.
- Sadece HvH sunucularında kullan. Resmi maçlarda (MM) rage anti-aim çok kısa sürede ban yedirir.
