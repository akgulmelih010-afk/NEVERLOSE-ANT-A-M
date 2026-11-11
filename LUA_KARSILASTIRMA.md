# Piyasadaki GameSense lualarıyla karşılaştırma (V1.0.27)

İncelenen: `XYESOSENSE.lua` (s0daa deposu, 1 354 satır) ve yOndery GS paketi (UPD-6): `!enderphobia.lua` (2 485 satır), `! Wraith Recode.lua` (2 571), `!!!!abyss.lua` (3 219, Rinnegan türevi), `Multi-Tools_by_bassota.lua` (1 558), `jumpscout.lua`, `hit_effect.lua`, `neverlose hotkeys.lua` (MoonSec ile korunmuş, okunamıyor), `Helper V3` (bomba / hareket yardımcısı, AA dışı), `ModelChanger` (görsel). Ayar dışa aktarımları: enderphobia (JSON), wraith (base64), abyss (base64 JSON); `cfg by yOnderyV3` GameSense ikili config, çözülemiyor.

Önceki sürümlerde zaten alınmış olanlar: jumpscout (V1.0.18), enderphobia'nın silah değiştirirken defensive'i ve XYESOSENSE/luasense'in bıçak yakınken defensive'i (V1.0.18), wraith / Etterance / Multi-Tools'un ESP bayrağı bit 11 "vurulabilir" (V1.0.21), NYKLE Resolver'ın Force body yaw hipotezleri.

## Özellik tablosu

| Alan | XYESOSENSE | enderphobia | Wraith | abyss | Multi-Tools | **Nykle.win GS** |
|---|---|---|---|---|---|---|
| Durum başına AA builder | 10 durum, takım başına | 10 durum (3'ü ayarlarda açık) | 16 durum, öncelik listesi | 11 durum + Safe head + Dormant | — | 13 durum, X-Way, modifier, limit/yaw/delay randomize |
| Taraf çevirme | "luasense": gönderilen pakette, rastgele 3–6 komut | gönderilen pakette, `yaw_delay` | "slow": 3 gönderilen paket | gönderilen pakette; **Switch: sol N / sağ M, her K'da yer değişir** | — | gönderilen pakette, delay + delay randomize; **faz 8 asimetrik (V1.0.27)** |
| Anti-bruteforce | düşman başına taraf log'u (bullet_impact) | saat tabanlı toggle, fiilen çalışmıyor | yok | yok | — | 9 faz, hareket grubu başına öğrenme, düşman başına hafıza, kötü faz atlama |
| Defensive tetiği | `komut % 3 ≠ 1`, weaponselect, quick_stop | Always / Tick (32'de 26) / silah çekme | durum başına her tick | durum başına her tick; "Flick": 7'de 1 | — | Smart (görüldü **veya yakında düşman**), peek, silah çekme, bıçak, air lag; **temiz atışta kalkar** |
| Hidden açılar | pitch up / spin / random / sideways; "fixer" eski yaw'a dönüş | yaw+pitch static/random/spin/jitter + gürültü | forward/spin/jitter/opposite (yaw tipi yazma hatası) | sideways/45/spin/random/opposite/progressive; `duration` | — | durum başına pitch/yaw (Down/Up/Switch/Random, Sideways/Spin/Random/Forward/Custom) |
| Defensive tespiti | predict_command tickbase | tickbase + yerel sim time geri gitmesi | predict_command tickbase | predict_command tickbase + LC kırma | tickbase + ping | predict_command tickbase + paket sıçraması + net_update |
| Teleport / şarj | — | — | "extended teleport": belirli tickbase derinliğinde DT bırak | — | havada aimbot kapatıp DT şarj ettirme | havada 1 teleport, sonuç ölçümü, haritada kapatma; şarj havada zaten doluyor (73/73) |
| Freestanding | tehditten iki yana trace | GS native + tuş | GS native + tuş | GS native + disablers | — | GS native, otomatik (dururken), FS kapatıcılar |
| Resolver | — | — | pitch > 60'ta sabit ±60 / 0 body yaw; "on shot only" whitelist | — | — | düşman başına safe point / body aim seviyesi, sahte kayıt bekleme, hipotezler, jitter ölçümü |
| Ragebot yardımcıları | — | — | — | **durum / silah başına hit chance** (havada, dürbünsüz) | DT şarj tahmini | sniper öldürücü kural, DT çifti, gövde 70+, bıçak MD, **havada hit chance (V1.0.27)** |
| Düşman takibi | threat | threat | eye yaw kaydı (4), on-shot tespiti | threat yüksekliği | — | sim time (sahte kayıt), LC, jitter deseni, fake duck, görüş izi, ileri bakış |
| Log / ölçüm | bildirim | — | — | — | — | atış / vurulma / düello / sikmadi / round özeti, Stats paneli, faz hafızası |
| Görsel / kozmetik | watermark, oklar, legs spammer, animasyon | logo, clan tag, trash talk, viewmodel | animasyon, trash talk, fps cvar | kill-helper çizgisi, LC göstergesi | buybot, hitmarker, trash talk | gösterge, oklar, resolver paneli, clan tag, trash talk |

## Taşınanlar (V1.0.27)

1. **abyss "Switch" body jitter** → anti-brute faz 8 (asimetrik taraf süresi). Öğrenme ölçer; işe yaramazsa kendi kendine elenir.
2. **abyss durum başına hit chance** → `In-air hit chance (snipers)`. Loglarda 254 `sikmadi`'nin 75'i "sen havadasın" (hepsi hc 55); havadan giden atışlar %67–89 tuttu.

## Bakılıp alınmayanlar

- **enderphobia**: hidden açılar, silah çekme tetiği, gönderilen pakette çevirme → hepsi bizde. Anti-brute'u saat tabanlı ve kırık; exploit / resolver yok. Ayarları (Global yaw ≈ −14°, body her 3 pakette) düşük desync fazlarımızı destekleyen bir veri noktası, mekanizma değil.
- **Wraith**: "extended teleport" (DT'yi −1…−4 tickbase derinliğinde bırakmak) tek yeni fikir; spekülatif, oyun içi deney ister. Yükseklik / uzak mesafe durumları: bizde Safe head: high ground var (loglarda zararlı çıktığı için kapalı). Resolver'ı bizimkinden ilkel; "AA stealer" çözülmüş yaw'dan örnek aldığı için gürültü kopyalıyor.
- **abyss**: `duration` (hidden açıyı pencerenin son N tick'ine sınırlama) ve "Flick" (7'de 1 defensive) → Smart/temiz atış mantığımızdan zayıf. Kill-helper çizgisi görsel.
- **Multi-Tools**: "havada aimbot'u kapatıp DT şarj ettirme" → bizde şarj havada zaten doluyor (73 teleportun 73'ünde), gerek yok.
- **XYESOSENSE**: "AA fixer" (defensive bitince eski yaw) → bizde hidden yaw sadece pencere içinde, builder yaw'ı zaten geri geliyor. Bullet_impact ile taraf log'u → anti-brute fazlarımızın alt kümesi. `fix hideshot` (HS'de fake lag limiti 1) → HS artık varsayılan değil.
- **hit_effect** (FFI ile tesla efekti), **ModelChanger**, **Helper V3**: AA / rage dışı.

## Web araştırması

Açık kaynaklarda (GitHub `s0daa/CSGO-HVH-LUAS`, `picocode1/LUA`, gamesense.pub `antiaim_funcs` konusu 29665, lura.blue reklamı) bu paketlerin ötesinde teknik bir şey yok; karşılaştırma yazıları reklam ya da kapalı forum.
