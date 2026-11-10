# Nykle.win primordial — deney defteri

Kural: aynı anda tek değişiklik denenir, ölçüyle karar verilir. Kötüleşen geri alınır, iyileşen kalıcı olur.
Lua bunu kendisi yapar ("Experiments"); bu dosya sonuçların kaydıdır.

## Hile karşılaştırması: GameSense'e dönüş (10 Kasım)

Bütün loglar, olay bazında tekilleştirilmiş (48 GameSense / Neverlose logu + 10 Primordial logu):

| Hile | Round sunucusu K/D | DM K/D | Sana gelen kafa oranı |
|---|---|---|---|
| GameSense | 1.02 (775 / 763) | 0.67 (442 / 656) | round %34, DM %55 |
| Neverlose | 0.89–0.97 (4 log, az örnek) | | ~%35 |
| Primordial | 0.42 (41 / 97) | 0.48 (126 / 262) | round %45, DM %59 |

Aynı rakiplere karşı (furkan, Sativa, got blessed, DUVARCI): GameSense 70 / 83 = **0.84**, Primordial 17 / 46 = **0.37**.
Primordial'ı ilk küçük loglardaki "atış başına kafa" oranına bakarak seçmiştim; K/D ile bakınca açık ara en kötüsü.
Karar: GameSense. Deney motoru GameSense lua'sına V1.0.81'de taşındı (bkz. kök README, "GameSense edition", V1.0.81);
bu dosyadaki Primordial sonuçları (gizli açı zararlı, iniş teleportu zararlı, gövde testi zararlı) GameSense'te
varsayım olarak değil aday olarak ölçülüyor.

Son Primordial logu (V1.0.30, 16 dk, güçlü lobi): 2 kill / 22 ölüm, 7 atış; `hidden_old` ara sonucu şimdiki ayar 9/15
kafa (%60), eski gizli açı 10/14 (%71), karar yok.

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

## V1.0.30 analizi: 7 log, 509 düşman mermisi (isabet + ıska)

Defensive ve "gizli açı" (defensive sırasında pitch yukarı / rastgele yaw / spin):

| Mermi anında durum | Mermi | Iska | Gövde | Kafa |
|---|---|---|---|---|
| Defensive açık, gizli açı yok | 73 | %30 | %39 | %30 |
| Defensive açık + gizli açı | 26 | %11 | %46 | %42 |
| Gizli açıdan sonraki 16 tick | 86 | %8 | %34 | %57 |
| Defensive yok | 324 | %20 | %30 | %48 |

Havada: gizli açıdan sonraki 1-8 tick'te kafa %70-88. Karar: gizli açılar bütün satırlarda kapatıldı.

AA hedefi (AA'nın döndüğü düşman) ile vuran düşman:

| Vuran | Mermi | Iska | Gövde | Kafa |
|---|---|---|---|---|
| AA hedefi | 281 | %21 | %38 | %39 |
| AA hedefi değil, lua "görüyor" diyordu | 74 | %24 | %29 | %46 |
| AA hedefi değil, lua "görmedi" diyordu | 154 | %13 | %25 | %61 |

Sebep: hedef dışındaki düşmanlar sırayla, 16-24 tick'te bir taranıyordu. Karar: 900 birim içindeki en yakın 5
düşman 2 tick'te bir taranır; görenler arasında AA hedefi hattı yeni açan, sonra en yakın olan.

Diğer gözlemler (karar verilmedi): duvardan gelen isabetlerde kafa %72, açıkta %48; rakip bizi ilk gördüğü 0.15 sn
içinde ya da "görmedi" derken sıkıyor (mermilerin %70'i); kendi atışımızdan sonraki 1 sn içinde mermilerin %32'si.

## Süren ve sıradaki deneyler (lua sırayla dener)

1. `hidden_old` — doğrulama: eski gizli açılar aday kolunda. Ölçü: yenen mermilerde kafa oranı. Beklenti: reddedilir.
2. `aa_nearest` — kimse görmüyorken AA nişangaha en yakın yerine mesafece en yakın düşmana döner. Ölçü: kafa oranı.
3. `def_dense` — yerde de 8 tick'te bir defensive (şimdi 12). Ölçü: kafa oranı; öldürme düşerse reddedilir.
4. `ret_notp` — geri çekilmede DT ışınlanması yok. Ölçü: öldürmeyen atıştan sonra 2 sn sağ kalma.
5. `scout_hc90` — scout hit chance en az 90. Ölçü: scout atış isabet oranı.
6. `crouch_stand` — eğikken Standing ayarı. Ölçü: eğikken kafa oranı.
7. `sp_off` — resolver safe point'siz. Ölçü: scout atış isabet oranı.

Reddedilen: `crouch_safe` (eğik AA sabit yaw + desync 30): aday kafa 22/28 (%79), şimdiki 21/32 (%66).

Karar kuralı: iki kolda da en az örnek varken aday 2 standart hata öndeyse kazanır, 1 standart hata gerideyse hemen
reddedilir; 3 kat örnekte 1 standart hata öndeyse kazanır, değilse şimdiki kalır. Aday yaşam başına öldürmede 2
standart hata gerideyse her durumda reddedilir.
