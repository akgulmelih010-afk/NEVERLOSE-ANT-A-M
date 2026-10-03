# ANT-A-M — Neverlose HvH anti-aim lua

Neverlose (CS:GO) için yazılmış, durum (state) bazlı anti-aim lua'sı. Sadece HvH sunucuları için.

## Kurulum

1. `antiaim.lua` dosyasını Neverlose'un script klasörüne at. Menüde **Scripts** sekmesinden klasörü açabilirsin, genelde `Counter-Strike Global Offensive/nl/scripts` olur.
2. Oyunda Neverlose menüsü → **Scripts** → `antiaim` → **Load**.
3. Sol tarafta **ANT-A-M** sekmesi çıkar. Ayarları orada yaparsın, config'inle birlikte kaydedilir.

> Konsolda `[ANT-A-M] menude bulunamadi: ...` yazısı çıkarsa Neverlose sürümünde o menü öğesinin adı farklı demektir. Script çökmez, sadece o ayarı atlar. Yazıyı bana at, düzeltirim.

## Menü

### Main
| Ayar | Ne işe yarar |
|---|---|
| Enable | Lua'yı açar/kapatır. Kapatınca Neverlose'un kendi AA ayarların geri gelir. |
| Pitch | Genelde `Down`. `Fake Down/Up` sadece untrusted'a izin veren sunucularda. |
| Yaw base | `At Target` en yakın düşmana göre döner. HvH'de bunu kullan. |
| Manual yaw | Sol / Sağ / İleri. Tuşa bağla (öğeye sağ tık → bind). Duvara yaslanınca kafayı duvarın arkasına saklar. Jitter'ı kapatır. |
| Freestanding | Kafayı otomatik olarak duvar tarafına saklar. Bind'li kullan. |
| Static inverter | Body yaw `Static` olan durumlarda desync tarafını çevirir. Bind'le. |
| Static body freestanding | Static body yaw'da tarafı Neverlose'un seçmesi (Peek Fake / Peek Real). |
| Anti-bruteforce | Düşman mermisi kafanın 40 birim yakınından geçince (ya da vurunca) tarafı ve limitleri değiştirir. 3 faz arasında döner. Süre dolunca ya da round başında sıfırlanır. |
| Safe head | Havada eğilip bıçak/zeus tutarken jitter'ı kapatıp kafayı sabit tutar. |

### Builder
`State` listesinden durumu seç: **Global, Standing, Moving, Slow walk, Crouching, Crouch move, Air, Air crouch**.
Global dışındaki bir durumda `Override global` açmazsan o durum Global ayarlarını kullanır.

| Ayar | Ne işe yarar |
|---|---|
| Yaw add left / right | Desync sola bakarken ve sağa bakarken eklenen yaw. İkisi farklı olunca yaw, body yaw ile **senkron** jitter yapar (L/R jitter). |
| Yaw modifier / offset | Neverlose'un kendi modifier'ları (Center, Offset, Random, Spin, 3-Way, 5-Way). L/R ile birlikte de kullanılabilir. |
| Body yaw | `Jitter`: taraf lua tarafından her paket döngüsünde çevrilir. `Static`: Static inverter'a göre sabit. `Off`: desync yok. |
| Jitter delay | Kaç paket döngüsünde bir taraf değişsin. 1 = en hızlı. 2-3 bazı resolver'ları şaşırtır. |
| Left / Right limit | Desync miktarı (0-60). |
| Avoid overlap | Gerçek ve sahte açının üst üste binmesini engeller. |

### Visuals
Nişangahın altında state, DT / HS / FS ve anti-brute fazını, yanlarda da manuel okları gösterir. Renk ayarlanabilir.

## Vuruluyorsan ne yapmalı

Hiçbir anti-aim seni vurulmaz yapmaz. İyi resolver'lar ve baim yine vurur. Ama şunlar çok fark eder:

- **Önce Global'i ayarla.** Sonra en çok hangi durumda vurulduğuna bak, sadece o durumun `Override global`'ini açıp onu değiştir. Genelde en zayıf durumlar `Air` ve `Moving`.
- **Kafadan vuruluyorsan** yaw left/right değerlerini değiştir (mesela -20/35 yerine -35/20 veya -10/45), `Jitter delay`'i 2-3 yap, ya da modifier'ı `3-Way` / `Center` dene.
- **Aynı yerden üst üste vuruluyorsan** anti-bruteforce açık kalsın. Reset süresini 4-8 saniye arasında tut.
- **Duvar dibinde bekliyorsan** freestanding ya da manuel yaw kullan. Bunlar jitter'dan daha güvenli.
- **DT + Hide Shots** kullan. DT yokken fakelag'ı yüksek tut (14).
- Geniş peek atma. Resolver'ın açını yakalaması için sana zaman tanımış olursun.

## Notlar

- Neverlose'un **CS:GO** Lua API'sine göre yazıldı. CS2 Neverlose'un API'si farklı, orada çalışmaz.
- Oyunda test edemedim. Neverlose API'sini taklit eden sahte bir ortamda bütün durumlar, jitter, manuel, freestanding, anti-brute ve menü görünürlüğü test edildi.
- Sadece HvH sunucularında kullan. Resmi maçlarda (MM) rage anti-aim çok kısa sürede ban yedirir.
