# Nykle.win primordial — deney defteri

Kural: aynı anda tek değişiklik denenir, ölçüyle karar verilir. Kötüleşen geri alınır, iyileşen kalıcı olur.
Lua bunu kendisi yapar ("Experiments"); bu dosya sonuçların kaydıdır.

## Taban çizgisi (V1.0.26-27, Min. damage 100 kolu)

| Ölçü | Değer | Kaynak |
|---|---|---|
| Yaşam başına öldürme | 0.80 (16 / 20 yaşam) | log 13, gövde testi kapalı kolu |
| Temiz koşulda scout isabeti | %82 (28 / 34) | log 13 |
| Yediğimiz mermilerde kafa oranı | %50 (35 / 70) | log 13 |
| Eğik durumlarda kafa oranı | ~%50 (Peek eğik, Crouch move, Crouching; 5 log) | log 8-13 |
| Fake duck + Safe head kafa oranı | %21-25 (18 mermi) | log 12-13 |
| Görülürken defensive payı / o sırada yenen mermi payı | %34 / %20 | log 13 |

## Biten deneyler

| Deney | Sonuç | Veri |
|---|---|---|
| AA fazları (5 faz) | Fark yok, sabit asym | 656 mermi, kafa %36-45 |
| İniş teleportu | Kapalı | açık 0.33 öldürme/yaşam, 16.5 sn; kapalı 0.88, 24 sn (52 yaşam) |
| Scout gövde atışı (Min. damage 50) | Reddedildi | açık 1 öldürme / 20 yaşam; kapalı 16 / 20 |
| Atıştan sonra geri çekilme | Açık (zayıf kanıt) | 12 atışta 7 ölüm; kapalıyken 8 |
| Sahte kayda ateş etmeme + temiz ateş | Kalıcı | sahte kayıtta %40, gerçekte %72; kendi defensive açıkken %58, kapalıyken %80 |

## Süren deney

| Deney | Durum (log 14, V1.0.28) |
|---|---|
| `crouch_safe` eğik AA sabit yaw + desync 30 | Kötü gidiyor: şimdiki 40 yaşam, 0.47 öldürme/yaşam, eğikken kafa 21/32 (%66); aday 40 yaşam, 0.35, kafa 22/28 (%79). V1.0.29 kuralıyla (1 standart hata geride = ret) bir sonraki oturumda reddedilir. |

Log 14 notu: güçlü lobi (yediğimiz mermilerde kafa %69, önceki log %50; scout isabeti temiz koşulda %66, önceki %82).
İki kol aynı lobide oynandığı için deney karşılaştırması geçerli; taban çizgisiyle karşılaştırma değil.

## Sıradaki deneyler (lua sırayla dener)

1. `def_hidden` — Peek / eğik / dururken defensive sırasında gizli açı (pitch yukarı, yaw rastgele). Ölçü: yenen mermilerde kafa oranı. Sebep: yenen 104 merminin 45'i Peek (eğik)'te, %73 kafa; bu satırlarda gizli açı kapalıydı.
2. `ret_notp` — geri çekilmede DT ışınlanması yok (şarj kalır, atış sonrası defensive çalışır). Ölçü: öldürmeyen atıştan sonra 2 sn sağ kalma. Sebep: 17 atışın 13'ünde 2 sn içinde ölüm.
3. `scout_hc90` — scout hit chance en az 90. Ölçü: scout atış isabet oranı.
4. `crouch_stand` — eğikken Standing ayarı (jitter 51, desync 60). Ölçü: eğikken kafa oranı.
5. `sp_off` — resolver safe point'siz. Ölçü: scout atış isabet oranı.

Karar kuralı (V1.0.29): iki kolda da en az örnek varken aday 2 standart hata öndeyse kazanır, 1 standart hata
gerideyse hemen reddedilir; 3 kat örnekte 1 standart hata öndeyse kazanır, değilse şimdiki kalır. Aday yaşam başına
öldürmede 2 standart hata gerideyse her durumda reddedilir.
