# Nykle.win primordial config notları

Dosya: `primordial/Nykle.win.cfg`. Okunabilir hali `Nykle.win.cfg.json`. Üreten: `python3 -I tools/build_prim_cfg.py`.
Kodlama orijinallerle aynı: base64 içinde sıkışık JSON, anahtarlar sıralı. KIZ4RU ve Raz bu yolla bayt bayt aynı üretiliyor; bu kontrol edildi.

## Seçilen configler

| Config | İyi olduğu yer | Bizde ne kullanıldı |
|---|---|---|
| **KIZ4RU** | AA tabanı, tuş düzeni, exploitler, misc | Ağacın tamamı buradan. MOUSE5 basılıyken autopeek ve auto direction çalışır. Manueller ok tuşlarında. Fakeduck MOUSE4'te. FL 15 + Break LC. Uncharge 11. Buybot. |
| **A RazGamesensical** | Ragebot isabeti, güvenli her şeyci | 7 silah bloğunun tamamı buradan: strict safepoint, multipoint sadece kafa/göğüs/mide, "Delay Shot Until Fully Accurate", snipelarda Min. damage 100. |
| **FRAGMENT** | DT isabeti | DT hitchance normal hitchance'ın üstünde: Auto 60, Deagle 65. Raz'da bu değerler 13/19 idi ve ikinci mermi neredeyse spreydi. |
| **kucjlota** | Duvar arkası filtresi | Auto ve Deagle'da duvar hasarı görünen hasarın altında: 30 ve 34. |
| bassota / çoğunluk | Güvenli exploit varsayılanları | Anti-Prediction On Peek açık, Shift On Knife açık, Force Prediction kapalı. |

## Nötrlenenler ve nedenleri

Bunları script her tick kendisi yazıyor. Native ayar da açık kalırsa script'le kavga eder.

- **AA:** Yaw Add 0, Jitter yok, Rotate kapalı, Pitch Down, at target. Desync sabit sol 100/100. Move ve Slow Walk override'ları kapalı. Native Anti Bruteforce ve On Shot kapalı, çünkü script'in kendi anti-brute fazları var.
- **Roll / Extended Angles / Body Lean:** tamamen kapalı. Sunucunda yasak.
- **Recharge:** Dont Use Charge ve Instant Recharge tuşsuz. Recharge'ın tek sahibi Nykle. Anti-Prediction In Air kapalı, çünkü havadaki teleport'u Nykle yapıyor.
- **Force Safepoint:** Unresolved, Jitter, In Air ve Lethal kapalı. Min. damage 100 iken "Lethal" açık kalsa her sniper atışı safepoint'e zorlanırdı. Safepoint'i Nykle'nin resolver'ı veriyor.
- **Force Hitchance tuşu (Raz'da SPACE):** tuşsuz. Havada hitchance'ı script yönetiyor.
- **Fake Ping (KIZ4RU'da 200):** kapalı. DT ve defensive zamanlamasını bozuyor.
- **Native Aimbot Logs:** kapalı. Log tek kaynaktan, `nykle_log.txt` dosyasından geliyor.
- **Resolve Antiaim:** açık. KIZ4RU bunu kapatan **resosense** adlı zararlı script'i yüklüyordu.
- **Script listesi:** sadece `Nykle.win`. IDEAL-TICK ve resosense alt ağaçları silindi. Böylece fakelag, recharge ve resolver'ın tek sahibi var.
- **Edge Jump (E):** tuşsuz. E aynı zamanda USE tuşu ve "Legit AA on use" ayarı bu tuşu kullanıyor.

## Senin değerlerin

- **Min. damage:** Scout, AWP ve R8'de 100 (HP). Yani sadece öldüren atış alınır, gövde öldürüyorsa gövde tercih edilir. Auto 42, Deagle 46, tabancalar 32, diğer silahlar 26. Bu değerleri sadece belgelenmiş kurallar düşürür: yakında bıçak/zeus varsa, DT çifti (kapalı) ve extended/kafa saklayana gövde.
- **Caps Lock (basılı tut):** native Min. damage override. Her şeye ateş etmek istediğinde kullanırsın. Basılıyken Nykle kendi Min. damage kurallarını uygulamaz. (KIZ4RU'nun G toggle'ı CS:GO'nun silah atma tuşuydu: silah atarken override fark edilmeden açık kalıyordu.)
- **DT:** her zaman açık (mode 3). Bu mod oyunda denenmedi. Kabul edilmezse DT'yi C'ye toggle olarak bağla.
- **Hideshots:** tuşsuz (KIZ4RU'nun Z'si CS:GO'nun radio1 tuşu; DT zaten her zaman açık).
- **Nade Helper:** kapalı (KIZ4RU'da her zaman açık, Autothrow MOUSE1 basılı; granat yardımcısı istenmedi).
- **Script ayarları:** script'in kendi varsayılanları. Hepsi en iyi değerlerde ve iyi özellikler açık gelir.
