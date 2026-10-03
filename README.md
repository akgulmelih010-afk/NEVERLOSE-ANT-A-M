# ANT-A-M v2 — Neverlose HvH anti-aim lua

Neverlose (CS:GO) için durum (state) bazlı anti-aim ve exploit lua'sı. Sadece HvH sunucuları için.

**Kurar kurmaz çalışır.** Bütün ayarlar hazır gelir; exploitler ve defensive her durumda kendiliğinden doğru moda geçer. İstersen sonradan ince ayar yaparsın.

## Kurulum

1. `antiaim.lua` dosyasını Neverlose'un script klasörüne at. Menüde **Scripts** sekmesinden klasörü açabilirsin, genelde `Counter-Strike Global Offensive/nl/scripts` olur.
2. Oyunda Neverlose menüsü → **Scripts** → `antiaim` → **Load**.
3. Konsolda `[ANT-A-M] v2.9 yuklendi` gibi bir satır çıkar; güncelledikten sonra numaranın değiştiğini buradan kontrol et.
4. Solda **ANT-A-M** sekmesi çıkar. İçinde **Anti-Aim** ve **Visuals** sekmeleri var. Ayarlar Neverlose config'inle birlikte kaydedilir.
5. Şu üç şeyi tuşa bağla (öğeye sağ tık → bind): **Manual yaw** (sol/sağ), **Freestanding**, **Static inverter**.

> Konsolda `[ANT-A-M] menude bulunamadi: ...` ya da `[ANT-A-M] ... ayarlanamadi: ...` yazısı çıkarsa Neverlose sürümünde o menü öğesinin ya da seçeneğin adı farklı demektir, ya da ayar o an kilitliydi. Script çökmez: reddedilen değeri 5 saniye sonra tekrar dener, bu arada o ayarı senin kendi değerine bırakır, gerisi çalışmaya devam eder. Yazıyı bana at, düzeltirim.

## Duruma göre exploit (varsayılanlar)

Script her tick'te hangi durumda olduğunu bulur ve o durumun AA'sını ve exploit ayarını uygular. **Auto exploit** açıkken (varsayılan) DT'yi kendisi açar, senin bind'ine gerek kalmaz.

| Durum | Ne zaman | Exploit | Defensive | Hidden pitch / yaw |
|---|---|---|---|---|
| Standing | Yerde duruyorsun | DT | On peek | Up / Sideways |
| Moving | Yürüyorsun / koşuyorsun | DT | On peek | Up / Sideways |
| Slow walk | Slow walk tuşu basılı | DT | On peek | Up / Sideways |
| Crouching | Eğilmiş duruyorsun | DT | On peek | Up / Sideways |
| Crouch move | Eğilerek yürüyorsun | DT | On peek | Switch / Sideways |
| Peek | Peek Assist (quick peek) tuşu basılı ya da hareket ederken düşmanın görüş alanına giriyorsun | DT | On peek | Up / Sideways |
| Air | Havadasın | DT | On peek | Up / Spin |
| Air crouch | Havada eğiliyorsun | DT | On peek | Up / Random |
| Fake duck | Fake duck tuşu basılı (peek'ten de önce gelir) | — (fake duck'ta DT/HS çalışmaz) | — | — |
| Manual | Manuel yaw açık | DT | On peek | — |
| Freestanding | Freestanding kafanı bir duvarın arkasına saklayabildi | DT | On peek | — |
| Safe head | Bıçak/zeus ile havada eğiliyorsun ya da düşmandan yüksektesin ve kafanı görebiliyor | DT | On peek | — |

- **On peek**: Neverlose peek attığını kendisi algılar ve tam o an defensive'e geçer. Yani yerde peek atınca exploit kendiliğinden devreye girer. Hide shots'ın Neverlose'da böyle bir seçeneği yok; HS kullanırken (ör. scout'ta) Peek durumundayken ya da düşman kafanı görüyor / birazdan görecekken (havadan peek dahil) "Break LC" açılır ve yarım saniye açık kalır. Böylece HS'de de peek anında defensive olur.
- **Fake duck**: Fake duck'ta exploit çalışmaz ve paketler ~14 tick boğulur; jitter ~0.2 sn'de bir dönüp tahmin edilebilir olur. Bu yüzden ayrı bir durum: varsayılanı static body yaw + "Peek Fake" body freestanding (sahte kafa peek yönüne, gerçek kafa siperin arkasına). Oyun loglarında fake duck peek'te, özellikle fake duck'la ateş ettikten hemen sonra kafadan vurulma görüldü; fake duck'ta Hide shots da çalışmadığı için ateş anındaki açın açıkta kalır. Log satırında `FD` yazar.
- **Auto peek** (varsayılan açık): Script düşmanın kafana mermi geçirebilip geçiremediğini her 2 tick'te hesaplar (şimdi ve 0.2 saniye sonraki konumun için). Hareket ederken görüş alanına giriyorsan, peek assist tuşuna basmasan da Peek durumuna geçer. Görüş kesilince 8 tick daha Peek'te kalır. Durursan açı tutuyorsun demektir, normal duruma döner.
- **Always on**: Defensive sürekli açık (Lag Options = Always On, HS'de Break LC). **Hiçbir durumda varsayılan değil:** oyun loglarında zıpladıktan, eğilip yürümeye ya da peek'e geçtikten ~0.4 sn sonra (defensive modu "Always on"a dönünce) DT %0'a düşüyor ve vurulma tam o sırada geliyordu. Varsayılanda bütün durumlar "On peek" kullandığı için durumlar arasında mod hiç değişmiyor. İstersen builder'dan bir durum için açabilirsin.
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
| Always use recommended settings | Açık | Neverlose lua ayarlarını config'e kaydeder; eski bir sürümle kaydedilmiş config eski varsayılanları geri getirir. Bu açıkken script her yüklendiğinde ve her config yüklendiğinde bütün AA, exploit ve builder ayarları o sürümün önerilen değerlerine döner, yani güncellemelerdeki yeni varsayılanlar hemen uygulanır. Bind'lenen ayarlara (Manual yaw, Freestanding, Static inverter), builder'daki durum seçiciye ve Visuals'a dokunmaz. Kendi ayarlarını kullanmak istersen kapat. |
| Pitch | Down | `Fake Down/Up` sadece untrusted'a izin veren sunucularda. |
| Yaw base | At Target | En yakın düşmana göre döner. |
| Manual yaw | Off | Sol / Sağ / İleri. Tuşa bağla. |
| Freestanding | Kapalı | Kafayı duvar tarafına saklar. Tuşa bağla. Kafan yine de açıkta kalıyorsa (freestanding saklayamadıysa) normal jitter'a döner. Dişli simgesinden: havada kapalı (varsayılan), eğilirken / slow walk'ta / yürürken kapat seçenekleri. |
| Static inverter | Kapalı | Body yaw `Static` olan durumlarda desync tarafını çevirir. |
| Safe head | Açık | Bıçak/zeus ile havada eğilirken kafayı sabitler. Düşmandan 35+ birim yüksekteyken de sabitler, ama sadece düşman kafanı gerçekten görebiliyorsa (duvar arkasındaysan gerek yok). |
| Anti-bruteforce | Açık | Düşman mermisi kafanın 40 birim yakınından geçince ya da vurunca 3 faz arasında döner. Static body yaw'da tarafı çevirir; jitter'da desync'i yaw sırasının tersine kaydırır, böylece resolver'ın öğrendiği desen bozulur. 2. ve 3. fazda kafa ayrıca ±15° kayar; desync hiçbir fazda düşük desync'e inmez (resolver'lar ıskadan sonra bunu dener). Faz **her düşman için ayrı** tutulur (her resolver ayrı öğrenir) ve AA'nın baktığı düşmanınki uygulanır. Aynı düşmanın DT çift atışı tek atış sayılır. Iskalarla ilerleyen faz 6 saniye sonra, round başında ya da ölünce biter. **Hafıza:** Bir düşman kafanı hangi fazda vurduysa, ona karşı bir sonraki fazdan başlanır ve bu round'lar arası kalır (Neverlose resolver'ı da oyuncuları round'lar boyunca hatırlar). Gövde/bacak isabetleri hafızayı değiştirmez. Harita değişince sıfırlanır. |
| Avoid backstab | Açık | Bıçaklı düşman arkana gelince döner. |
| Legit AA on use | Açık | E'ye basılı tutarken AA çalışmaya devam eder. Kapı açma ve silah alma bozulmaz. CT olarak bomba ya da rehine yanındaysan karışmaz. |
| Spin when idle | Açık | Hiç canlı düşman kalmayınca spin yapar. Warmup'ta spin isteğe bağlı (varsayılan kapalı, çünkü HvH sunucularında warmup'ta da savaşılıyor). |

### Exploits
| Ayar | Varsayılan | Ne işe yarar |
|---|---|---|
| Auto exploit | Açık | Her durumun exploit seçimini (DT / HS / Binds) uygular. Kapatırsan DT/HS'yi kendi bind'lerin yönetir. |
| Auto peek | Açık | Hareket ederken düşmanın görüş alanına girince Peek durumuna geçer (yukarıya bak). |
| Snipers (SSG08/AWP/R8) | Hide shots | Elinde scout, AWP ya da R8 varken DT yerine Hide shots kullanılır (durumun exploit'i `Binds` değilse). Bıçak, zeus, bomba ve C4'e geçince exploit değişmez, son tuttuğun silahınki korunur (scout → bıçak → scout geçişinde DT/HS kapanıp açılıp DT'yi boşaltmasın diye). Bolt-action tüfek ve R8 DT ile çift atış yapamaz; DT her atıştan sonra boşalıp uzun süre şarj olur ve o sırada ne defensive ne koruma vardır. Hide shots ateş ettiğin anki açını gizler, defensive "Break LC" ile devam eder. Oyun loglarında scout'la ateş ettikten 0.05-0.35 sn sonra, DT %0'dayken kafadan vurulma tekrar tekrar görüldü. `Same as state` ile kapatılır. |
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
| Body yaw | `Jitter`: taraf lua tarafından paket döngüsüne göre çevrilir. `Static`: Static inverter'a göre. `Off`: desync yok. Dişliden: Avoid overlap, body freestanding, delay ve limit randomize. |
| Jitter delay | Kaç paket döngüsünde bir taraf değişsin. Sadece DT/HS aktifken uygulanır. |
| Left / Right limit | Desync miktarı (0-60). |
| Exploit / Defensive / Hidden | Yukarıdaki tabloya bak. |

### Visuals
Nişangahın altında: desync çubuğu, aktif durum, DT / HS / FS / DEF ve anti-brute fazı. Yanlarda manuel oklar ve desync tarafı. Renkler ayarlanabilir; dürbünle bakarken indikatör kenara kayar.

- **DT**: beyaz = şarjlı, turuncu = şarj oluyor, soluk = kapalı.
- **DEF**: renkli = defensive penceresi şu an gerçekten açık, beyaz = bu durumda defensive sürekli açık, soluk = sadece peek'te. Pencere tickbase'den iki yolla tespit edilir: tickbase gördüğümüz en yüksek değerin gerisine düştüyse ya da DT doluyken iki paket arasında geri gittiyse veya 1'den fazla ileri sıçradıysa.
- **VIS**: renkli = düşman kafanı şu an görüyor, beyaz = birazdan görecek, soluk = görmüyor.

| Ayar | Varsayılan | Ne işe yarar |
|---|---|---|
| Hit log (console) | Açık | Seni vurunca konsola yazar. Örnek: `vuruldun: head -293 ssg08 \| Peek \| faz 1 \| sag 58 \| DT %40, DEF yok, atis 0.12s, mod 0.05s \| sen r8 \| isim` → bölge, hasar, düşmanın silahı, durum, mermi atıldığı andaki anti-brute fazı, desync tarafı ve miktarı, DT durumu (`dolu` / şarj yüzdesi / `yok`; yanında `(bind)` yazıyorsa o exploit'i script değil senin kendi bind'in belirliyor), defensive penceresi o an açık mıydı, kendi son atışından bu yana geçen süre (5 sn'den eskiyse `atis yok`) ve script defensive modunu az önce değiştirdiyse ne kadar önce (`mod`, sadece son 2 sn), senin o an tuttuğun silah. Kafanın yanından geçen ıskaları da aynı bilgilerle yazar. Molotof, yangın ve el bombası hasarı yazılmaz ve istatistiğe girmez. |
| Stats panel | Kapalı | Ekranın solunda her durum için `isabet / kafa / ıska / DT / DEF`. Sen ateş etmezken (atıştan sonraki 1 sn hariç): **DT** = DT'nin yüzde kaç dolu olduğu (düşükse o durumun ayarları DT'yi boşaltıyor), **DEF** = exploit hazırken defensive penceresinin yüzde kaç açık olduğu ("Always on" bir durumda düşükse defensive gerçekten çalışmıyor). Ölünce de görünür. |
| Reset stats | — | İstatistikleri sıfırlar. |

## Vuruluyorsan ne yapmalı

Hiçbir anti-aim seni vurulmaz yapmaz. İyi resolver'lar ve baim yine vurur. Ama şunlar çok fark eder:

- Önce varsayılanlarla oyna. **Stats panel**'i aç ya da konsoldaki `vuruldun:` satırlarına bak: hangi durumda kafadan vurulduğun orada yazıyor. Sadece o durumu değiştir. Paneli ya da birkaç satırı bana atarsan birlikte ayarlarız.
- **Kafadan vuruluyorsan** o durumun yaw left/right değerlerini değiştir (ör. -23/51 yerine -35/40), `Jitter delay`'i 2-3 yap ya da biraz `Yaw randomize` ekle.
- **Havada vuruluyorsan** Air durumunda hidden yaw'ı `Random` ya da `Sideways` dene.
- **Duvar dibinde bekliyorsan** freestanding ya da manuel yaw kullan.
- Geniş peek atma; quick peek (Peek Assist) kullanınca Peek durumu ve defensive kendiliğinden devreye girer.

## Notlar

- Neverlose'un **CS:GO** Lua API'sine göre yazıldı. CS2 Neverlose'un API'si farklı, orada çalışmaz.
- Oyunda test edemedim. Neverlose API'sini taklit eden sahte bir ortamda bütün durumlar, exploit seçimleri, defensive modları, hidden açılar, görüş tespiti, auto peek, X-Way, düşman başına anti-brute, vuruldum/ıska kaydı, istatistik paneli, legit AA, spin, merdiven, indikatör renkleri ve menü görünürlüğü test edildi. Eksik menü öğesi, eksik API (`rage`, `utils.trace_bullet`) ya da Neverlose'un kabul etmediği bir değer olduğunda da çökmediği test edildi.
- Script'e yeni menü öğeleri eklendikçe config'indeki bazı lua ayarları varsayılana dönebilir. Kendi değerlerini ayarladıysan güncellemeden sonra bir göz at.
- Sadece HvH sunucularında kullan. Resmi maçlarda (MM) rage anti-aim çok kısa sürede ban yedirir.
