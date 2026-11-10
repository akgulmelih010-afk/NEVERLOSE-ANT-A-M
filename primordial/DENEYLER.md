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

## Sıradaki deneyler (lua sırayla dener)

1. `crouch_safe` — eğikken sabit yaw, jitter yok, desync 30. Ölçü: eğikken yenen mermilerde kafa oranı.
2. `scout_hc90` — scout hit chance en az 90. Ölçü: scout atış isabet oranı.
3. `crouch_stand` — eğikken Standing ayarı (jitter 51, desync 60). Ölçü: eğikken kafa oranı.
4. `sp_off` — resolver safe point'siz. Ölçü: scout atış isabet oranı.

Her deney için sonuç satırı (`deney bitti: ...`) buraya işlenir.
