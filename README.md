# ANT-A-M v2 — Neverlose HvH anti-aim lua

Neverlose (CS:GO) için durum (state) bazlı anti-aim ve exploit lua'sı. Sadece HvH sunucuları için.

**Kurar kurmaz çalışır.** Bütün ayarlar hazır gelir; exploitler ve defensive her durumda kendiliğinden doğru moda geçer. İstersen sonradan ince ayar yaparsın.

## Kurulum

1. `antiaim.lua` dosyasını Neverlose'un script klasörüne at. Menüde **Scripts** sekmesinden klasörü açabilirsin, genelde `Counter-Strike Global Offensive/nl/scripts` olur.
2. Oyunda Neverlose menüsü → **Scripts** → `antiaim` → **Load**.
3. Solda **ANT-A-M** sekmesi çıkar. İçinde **Anti-Aim** ve **Visuals** sekmeleri var. Ayarlar Neverlose config'inle birlikte kaydedilir.
4. Şu üç şeyi tuşa bağla (öğeye sağ tık → bind): **Manual yaw** (sol/sağ), **Freestanding**, **Static inverter**.

> Konsolda `[ANT-A-M] menude bulunamadi: ...` yazısı çıkarsa Neverlose sürümünde o menü öğesinin adı farklı demektir. Script çökmez, sadece o özelliği atlar. Yazıyı bana at, düzeltirim.

## Duruma göre exploit (varsayılanlar)

Script her tick'te hangi durumda olduğunu bulur ve o durumun AA'sını ve exploit ayarını uygular. **Auto exploit** açıkken (varsayılan) DT'yi kendisi açar, senin bind'ine gerek kalmaz.

| Durum | Ne zaman | Exploit | Defensive | Hidden pitch / yaw |
|---|---|---|---|---|
| Standing | Yerde duruyorsun | DT | On peek | Up / Sideways |
| Moving | Yürüyorsun / koşuyorsun | DT | On peek | Up / Sideways |
| Slow walk | Slow walk tuşu basılı | DT | On peek | Up / Sideways |
| Crouching | Eğilmiş duruyorsun | DT | On peek | Up / Sideways |
| Crouch move | Eğilerek yürüyorsun | DT | **Always on** | Switch / Sideways |
| Peek | Peek Assist (quick peek) tuşu basılı | DT | **Always on** | Up / Sideways |
| Air | Havadasın | DT | **Always on** | Up / Spin |
| Air crouch | Havada eğiliyorsun | DT | **Always on** | Up / Random |
| Manual | Manuel yaw açık | DT | On peek | — |
| Freestanding | Freestanding bir duvar buldu | DT | On peek | — |
| Safe head | Bıçak/zeus ile havada eğiliyorsun ya da düşmandan yüksektesin | DT | Kapalı | — |

- **On peek**: Neverlose peek attığını kendisi algılar ve tam o an defensive'e geçer. Yani yerde peek atınca exploit kendiliğinden devreye girer.
- **Always on**: Defensive sürekli açık (Lag Options = Always On, HS'de Break LC). Havada ve eğilerek peek atarken vurulmamak için.
- **Tick based**: Her N komutta bir defensive zorlanır (`force_defensive`).
- **Hidden pitch / yaw**: Defensive tick'lerinde sunucuya giden sahte açılar.
- Elinde bomba (grenade) varken ve fake duck yaparken exploitlere karışılmaz.

Her durumun bu ayarları **Builder**'da, durumu seçince altta **Exploit** başlığında görünür.

## Menü

### Main
| Ayar | Varsayılan | Ne işe yarar |
|---|---|---|
| Enable | Açık | Lua'yı açar/kapatır. Kapatınca Neverlose'un kendi ayarların geri gelir. |
| Pitch | Down | `Fake Down/Up` sadece untrusted'a izin veren sunucularda. |
| Yaw base | At Target | En yakın düşmana göre döner. |
| Manual yaw | Off | Sol / Sağ / İleri. Tuşa bağla. |
| Freestanding | Kapalı | Kafayı duvar tarafına saklar. Tuşa bağla. Dişli simgesinden: havada kapalı (varsayılan), eğilirken / slow walk'ta / yürürken kapat seçenekleri. |
| Static inverter | Kapalı | Body yaw `Static` olan durumlarda desync tarafını çevirir. |
| Safe head | Açık | Bıçak/zeus ile havada eğilirken ve düşmandan 35+ birim yüksekteyken kafayı sabitler. |
| Anti-bruteforce | Açık | Düşman mermisi kafanın 40 birim yakınından geçince ya da vurunca tarafı ve limitleri değiştirir. 6 saniye sonra, round başında ya da ölünce sıfırlanır. |
| Avoid backstab | Açık | Bıçaklı düşman arkana gelince döner. |
| Legit AA on use | Açık | E'ye basılı tutarken AA çalışmaya devam eder. Kapı açma ve silah alma bozulmaz. CT olarak bomba başındaysan karışmaz. |
| Spin when idle | Açık | Warmup'ta ve hiç canlı düşman kalmayınca spin yapar. |

### Exploits
| Ayar | Varsayılan | Ne işe yarar |
|---|---|---|
| Auto exploit | Açık | Her durumun exploit seçimini (DT / HS / Binds) uygular. Kapatırsan DT/HS'yi kendi bind'lerin yönetir. |
| Hidden spin speed | 10 | Hidden yaw `Spin` hızı. |

### Builder
`State` listesinden durumu seç. Her durum kendi ayarlarıyla gelir. Hareket durumlarında `Override` kapatılırsa o durum **Global**'in AA ayarlarını kullanır (exploit ayarı yine kendisinden gelir).

| Ayar | Ne işe yarar |
|---|---|
| Yaw left / right | Desync sola ve sağa bakarken eklenen yaw. İkisi farklı olunca yaw, body yaw ile **senkron** jitter yapar. |
| Yaw randomize | Her flip'te yaw'a ± bu kadar rastgele açı ekler. |
| Yaw modifier / offset | Neverlose'un kendi modifier'ları (Center, Offset, Random, Spin, 3-Way, 5-Way). Dişliden randomize. |
| Body yaw | `Jitter`: taraf lua tarafından paket döngüsüne göre çevrilir. `Static`: Static inverter'a göre. `Off`: desync yok. Dişliden: Avoid overlap, body freestanding, delay ve limit randomize. |
| Jitter delay | Kaç paket döngüsünde bir taraf değişsin. Sadece DT/HS aktifken uygulanır. |
| Left / Right limit | Desync miktarı (0-60). |
| Exploit / Defensive / Hidden | Yukarıdaki tabloya bak. |

### Visuals
Nişangahın altında: desync çubuğu, aktif durum, DT / HS / FS / DEF ve anti-brute fazı. Yanlarda manuel oklar ve desync tarafı. Renkler ayarlanabilir; dürbünle bakarken indikatör kenara kayar.

## Vuruluyorsan ne yapmalı

Hiçbir anti-aim seni vurulmaz yapmaz. İyi resolver'lar ve baim yine vurur. Ama şunlar çok fark eder:

- Önce varsayılanlarla oyna. Hangi durumda vurulduğunu indikatördeki durum yazısından gör, sadece o durumu değiştir.
- **Kafadan vuruluyorsan** o durumun yaw left/right değerlerini değiştir (ör. -23/51 yerine -35/40), `Jitter delay`'i 2-3 yap ya da biraz `Yaw randomize` ekle.
- **Havada vuruluyorsan** Air durumunda hidden yaw'ı `Random` ya da `Sideways` dene.
- **Duvar dibinde bekliyorsan** freestanding ya da manuel yaw kullan.
- Geniş peek atma; quick peek (Peek Assist) kullanınca Peek durumu ve defensive kendiliğinden devreye girer.

## Notlar

- Neverlose'un **CS:GO** Lua API'sine göre yazıldı. CS2 Neverlose'un API'si farklı, orada çalışmaz.
- Oyunda test edemedim. Neverlose API'sini taklit eden sahte bir ortamda bütün durumlar, exploit seçimleri, defensive modları, hidden açılar, anti-brute, legit AA, spin ve menü görünürlüğü test edildi. Eksik menü öğesi ya da API olduğunda da çökmediği test edildi.
- Sadece HvH sunucularında kullan. Resmi maçlarda (MM) rage anti-aim çok kısa sürede ban yedirir.
