--[[
    Nykle.win lua V1.0.11  |  primordial edition  |  primordial (CS:GO) icin HvH anti-aim, exploit ve resolver lua'si

    GameSense surumunun (Nykle.win.gamesense.lua V1.0.79) loglarla kanitlanan ozelliklerinin ve Neverlose
    surumunun (Nykle.win.lua V1.1.x) kurallarinin primordial API'sine tasinmis hali.
    Kurar kurmaz calisir: butun varsayilanlar en iyi bilinen degerlerle gelir ("Always use recommended
    settings" acik kaldikca bu degerler korunur). Menu: Scripts sekmesi > "Nykle.win | ..." gruplari
    (Home > Tab ile sekme secilir).

    Dosya adi "Nykle.win.lua" kalmali: primordial config'te script ayarlari dosya adiyla ("Nykle.win") ve
    grup / oge adlariyla saklanir; adlar degisirse kayitli ayarlar okunmaz.

    GameSense surumunden farklar (primordial API'sinin izin verdigi kadar, bkz. primordial/README.md):
      - AA her tick ANTIAIM callback'inin ctx:set_yaw / set_desync / set_pitch ile verilir; native AA
        ayarlari (jitter, rotate, body lean, desync tarafi, anti bruteforce, on shot, yaw add) notrde tutulur
        ve kapatinca / script kaldirilinca senin degerlerine geri doner.
      - Roll / extended angles YOK (sunucunda yasak): her tick ctx:set_body_lean(0).
      - Freestanding: native Auto Direction tusu okunur (MOUSE5); tus basiliyken kafa acikta degilse
        script yaw yazmaz, native freestanding kafayi saklar.
      - Defensive: exploits.force_anti_exploit_shift() (sadece DT dolu iken). Teleport: force_uncharge.
        Safe recharge: block_recharge / allow_recharge (tek sahip, 3 sn bekci).
      - Resolver: primordial'da dusmana aci zorlama yok; dusman basina safe point seviyesi, gercek / taze
        kayit bekleme ve Min. damage kurallari HITSCAN / TARGET_SELECTION ile hedef basina verilir.
      - Min. damage sadece belgelenmis kurallarla duser: yakinda bicak / zeus, DT cifti (kapali),
        extended / kafa saklayan dusmana govde. Senin Min. damage override tusun basiliyken hicbiri calismaz.
      - Hafiza ve log dosyasi: ffi ile CS:GO dosya sistemi (nykle_memory.txt, nykle_log.txt; csgo klasoru).
      - DT / HS / fake duck / autopeek tuslarini script degistiremez: config'te DT her zaman acik gelir.

    Surum gecmisi:
      V1.0.11 (primordial edition): duvar hatti. Dusmanin mermi izi bana hasar veriyor ama gozunden kafama duz cizgi
        kapaliysa (duvardan vurabiliyor) sol listede "WB <hasar>" (sari; canina yetiyorsa kirmizi) ve vuruldun /
        iska satirinda "duvar hatti <hasar> hasar <sure>s". Log 4: yenen 9 merminin 9'u duvardan.
      V1.0.10 (primordial edition): "Defensive: repeat while seen" (varsayilan 16 tick): dusman gorurken zorlanan
        defensive her defensive dongusunde bir yenilenir (V1.0.5-9: gorulme basina tek shift; istek: "def az
        kullaniyor"). Log 3-4: force_anti_exploit_shift sarji harcamiyor ("sarj harcamadi"), takilma her tick
        cagirmaktan geliyordu; 16 tick'te bir cagri arada. 0 = olay basina bir kez (V1.0.9 davranisi).
      V1.0.9 (primordial edition): yeni faz seti ve adil faz testi. Eski 1-7 fazlari kaldirildi (2429 mermilik GS / NL
        logunda normal AA'dan iyi degillerdi: %42-48 kafa, normal %43); kalanlar: 0 normal, 1 asym (eski en iyi, %36),
        2 rnd-asym, 3 asym+duvar, 4 atis-sonrasi (son ucu bizim; hepsi taraf suresinin duzensizligiyle oynar). "Phase
        test" (acik): her round tek faz, her fazda 40 mermi birikene kadar esit rotasyon, sonra en dusuk kafa oranli
        faz roundlarin %60'i. Sayim mermi basina (isabet + iska), hafizada kalir (T kaydi). Log: round basinda "faz
        testi: bu round <faz> ...", harita sonu / kapanista "faz karsilastirma: ...". Eski setin faz istatistikleri
        ve dusman taban fazlari hafizadan dusurulur. Nisangah gostergesi "FAZ <AD>".
      V1.0.8 (primordial edition): desync isareti olcumu duzeltildi (log 4 ham sayilar: set_desync + iken gercek-sahte
        farki -78, - iken +47). Olcum degerin isaretini istenen tarafla degil kendisiyle karsilastiriyordu; sonuc
        carpandan bagimsiz hep "ters" cikiyor ve carpan her yuklemede 5-45 sn sonra cevriliyordu (V1.0.6-7'de dogru
        varsayilan yanlisa cevrildi). Artik istenen tarafla karsilastirilir: -1 varsayilani "uyumlu" olculur ve kalir.
      V1.0.7 (primordial edition): 3. oyun logundan (V1.0.6; takilma gitti). Hafiza dosyasi artik ikili modda yazilip
        okunur ve sayi tutmasa da gecerli kayitlar yuklenir (Windows metin modu yuzunden "kayit sayisi 30 != 33" ile
        butun hafiza bos yukleniyordu; okunan metinden \r / NUL temizlenir). Tick sayaci kendi tickbase kaymamizla
        (defensive / teleport) birkac tick geri gidince butun dusmanlar "uyandi" sayilip takipleri (AA deseni,
        defensive bayragi) sifirlaniyordu: artik sadece 64 tick'ten buyuk geri gidis ya da 32 tick'lik sessizlik
        uyanma. Desync olcumune ham sayi satiri ("aa: desync olcumu ham: ...").
      V1.0.6 (primordial edition): ilk iki oyun logundan. Desync isareti varsayilani oyunda olculen yon (+ = sol; her
        yuklemede 10-45 sn ters kaliyordu). "Goruyor" tespiti: dusman gozunden kafama mermi izi 0 donse de duz cizgi
        aciksa goruyor sayilir (bize gelen mermilerin %50-81'i "gormedi" yaziliyordu; "teshis: G31" + dbg teshis
        sayaci). Yakinda (NEAR) uyanan (dormant'tan cikan) dusman ilk gorus kenari sayilir (tek defensive olayi) ve
        16 tick boyunca her tick kontrol edilir (sirasini beklemez). Sol liste 28 piksel iceriden (kenarda kesikti).
      V1.0.5 (primordial edition): zorlanan defensive artik OLAY (yeni "Defensive: one shift per event (no repeat while
        seen)", acik): Smart'ta dusman gorunmeye BASLAYINCA tek force_anti_exploit_shift, gorulme surerken tekrar yok,
        sadece "yakin" hic tetiklemez (eskiden sarj dolar dolmaz yine zorlaniyordu: duello tick'lerinin %26'si, her
        zorlamada isinlanma + takilma). Sebep basina aralik: smart 64, peek 48 (ilk gorus / tarama basi / hizli dusman),
        silah degisimi 64, bicak 32 (tekrar eder), air lag ucus basina bir, AI peek yuruyus basina bir, AFK / Always
        on 64, Tick based max(14, N); kapatinca eski her-tick davranis. Log: "def: shift (<sebep>) | sarj c/m", "def:
        sarj N tick sonra doldu" / "def: shift sarj harcamadi" ve dbg sen ozetinde "shift N, dolum ort Nt". Uyanma
        (dormant / olu / 32+ tick guncellenmeyen dusmanin ilk kaydi) artik LC sayilmaz: takip yeniden tabanlanir, 14
        tick'lik gercek kayit beklemesi baslamaz; gercek kayit sadece defensive'de beklenir (LC'de degil), bekleme 3
        tick'lik dogrulamada da 14'u asmaz, satirda (defensive) / (N kez). Vuruldun / olum satirinda "uyandi X.XXs
        once" / "uykuda", "dbg uyandi" satiri, dbg teshis'te uyanma sayaclari. Takip tick basina dusman basina bir kez
        orneklenir (SETUP_COMMAND yedegi sadece NET_UPDATE 1 tick'ten uzun susunca).
      V1.0.4 (primordial edition): Stats paneli GS duzeninde (N.stats): durum basina isabet / kafa / iska + DT dolu ve
        zorlanan DEF tick payi, AIM (atis / isabet / correction / spread / diger), LAG / TEMIZ, durum basina KD (sadece
        dusman, olay anindaki durum), AI PEEK (peek / atis / isabet / bos / vurulma), AA FAZ tablosu (* varsayilan faz,
        x kotu bilinen faz); yazi ekran yuksekligine gore (1080 = 12 px), satirlar tick basina bir kez. Resolver
        panelinde "cozum %N" ve "HIT %N" (NL V1.0 modeli: %80 x0.8 jitter >= 120 x0.9 havada x0.5 sahte kayit x
        correction payi; HIT spread / diger on bilgisi %2 / %8), tick basina bir kez hesaplanir (karede isim / hafiza
        okumasi yok). "harita ozeti:" satiri (harita degisiminde, kapanista, 20 roundda bir) panel sayilarini loga
        tasir; Reset stats oturum ve harita sayaclarini sifirlar.
      V1.0.3 (primordial edition): sarj analizi (N.charge): DT yarim sarjken exploit durumunda "sh c/m", "dtac X.XXs",
        "defbitti X.XXs", "sarj: atis|teleport|def|dtac|?" (vuruldun / iska / dbg satirlari), round basinda "dbg sen
        ozeti", inis teleportunun sonucu ("teleport sonucu: tahmin N, sapma +N tick, ilk paket ...") ve 10 iniste bir
        "inis tahmini", force_uncharge sarji 3 kez harcamazsa oturum boyunca havada teleport kapali, ucus basina tek
        teleport bekcisi, sunucu reddi bekcisi (lag'li son 4 atisin 3'u 120 sn'de 2 dusmanda ret -> DEF / LC / TP 5 dk,
        PAUSE gostergesi; atisa ve Min. damage'e dokunmaz); teshis (N.diag): SPEC §8 belirsizlikleri icin ilk goruluste
        "teshis: Gn ..." ve harita / kapanista "dbg teshis:" (callback sirasi, ANTIAIM / komut, olay filtresi, iska
        sebebi histogrami, bekleme ihlali, seviye 1 / 2 atis hizi, sarj kilidi, USE, uncharge, DT tus modu, iz / tick).
      V1.0.2 (primordial edition): dusman profili ve hafiza v2 (N.profile): AA deseni statik / jitter <aralik> /
        x-way / spin / random (sadece gercek kayit yaw'lari; atis satirinda "AA jitter 80"), dusman fake duck
        isareti (dbg kayitta FD), gorunen dusmandan saniyede bir profil ornegi (desen, defensive, fake duck; 240'ta
        yariya), aliskanlik (10+ ornek, %60), hafizadan jitter on bilgisi (canli desen yokken ilk peek'te safe point
        Head, "hafizadan, dogrulanacak") + dogrulandi / tutmadi, "tanindi (hafiza)", AA deseni degisti / kararsiz
        (durum degisiminden 1.5 sn sonra), dusman basina kariyer (K/D, atis / isabet / kafa, correction, sana
        mermi) ve harita sonunda / kapanista "dusman ozeti"; hafiza dosyasi NYKLEMEM 2 (R / K / C kayitlari, END
        + kayit sayisi, nykle_memory.bak yedegi, bozuk dosyada yedekten yukleme, v1 okunur); cvar orijinalleri
        hafizada (oyun cokerse 4:3 / FPS / sol el eski degerine doner); 64 sinirinda gelecekteki oturum degeri
        sirayi bozmaz.
      V1.0.1 (primordial edition): detayli log GS ile ayni (N.dlog): dbg atis-detay (konum / kayit / aimbot /
        vurulabilir / ates-hakki / o-gordu / sen), dbg vurulma-detay (iz duvardan / acik, son iki atisi arasi (DT)),
        olum-detay / kill-detay etiketleri (headshot, duvardan, noscope, smoke icinden, kor), dbg duello GS bicimi
        (acilistaki konum, def %, havada) + olduren isabet artik sayiliyor (player_death AIMBOT_HIT'ten once gelir),
        dbg def ozeti, round / harita basliklari (cift round_start'ta bir kez), dbg round sonu, dbg sikmadi butun
        sebepler + silah / konum / kayit / sen kuyrugu, dusman basina 4 tick'te bir sirali vurulabilirlik taramasi.
      V1.0.0 (primordial edition): ilk surum. GameSense V1.0.79 varsayilanlari (builder, exploit satirlari,
        anti-brute fazlari 0-8 ve ogrenme, Smart defensive + re-arm cooldown + anti-peek, temiz atis,
        safe recharge, havada teleport + Air LC, gercek / taze kayit bekleme, bicak / zeus Min. damage,
        extended ve kafa saklayana govde, adaptif safe point resolver'i, AI peek, AFK + otomatik AFK,
        sol el, 4:3, FPS boost, clan tag, otomatik bomba alma, gostergeler ve GS ile ayni log satirlari).
]]

local N = {
    SCRIPT = "Nykle.win", VERSION = "1.0.11", EDITION = "primordial",
    util = {}, log = {}, fs = {}, ref = {}, ui = {}, ov = {}, rc = {}, mem = {}, track = {}, exposure = {},
    state = {}, aa = {}, brute = {}, ex = {}, rage = {}, peek = {}, afk = {}, shots = {}, stats = {}, misc = {},
    draw = {}, cb = {}, tick = {}, K = {}, dlog = {}, profile = {}, charge = {}, diag = { trn = 0 },
    st = { on = false, enabled = true, tick = 0, cmdn = -1, lp = nil, alive = false, dead = true, idx = nil,
        enemies = {}, enemies_tick = -1, any_enemy_alive = true, state = "Standing", move_state = "Standing",
        label = "Standing", threat = nil, weapon = nil, wgroup = "auto", round_start_at = -1000,
        last_round_start = -1000, last_shot = -1000, spawn_at = -1000, map = nil },
}
local floor, abs, sqrt, min, max = math.floor, math.abs, math.sqrt, math.min, math.max
local random, huge = math.random, math.huge
local pcall, type, tostring, tonumber, pairs, ipairs = pcall, type, tostring, tonumber, pairs, ipairs
local fmt, concat, tremove = string.format, table.concat, table.remove

-------------------------------------------------------------------------------
-- Sabitler
-------------------------------------------------------------------------------
do
    local K = N.K
    K.STATES = { "Global", "Standing", "Moving", "Slow walk", "Crouching", "Crouch move", "Peek", "Air",
        "Air crouch", "Fake duck", "Manual", "Freestanding", "Safe head" }
    -- Override kutusu olan hareket durumlari (Global'in AA'sini paylasabilenler).
    K.OVERRIDABLE = { Standing = true, Moving = true, ["Slow walk"] = true, Crouching = true,
        ["Crouch move"] = true, Peek = true, Air = true, ["Air crouch"] = true }
    K.MOVEMENT = { Global = true, Standing = true, Moving = true, ["Slow walk"] = true, Crouching = true,
        ["Crouch move"] = true, Peek = true, Air = true, ["Air crouch"] = true }
    -- { yaw sol, yaw sag, jitter gecikmesi, sol limit, sag limit } (GS DEFAULTS, loglarla dogrulanmis)
    K.DEFAULTS = {
        Global = { -20, 40, 1, 60, 60 }, Standing = { -23, 51, 1, 60, 60 }, Moving = { -20, 50, 1, 58, 58 },
        ["Slow walk"] = { -23, 51, 2, 58, 58 }, Crouching = { -20, 30, 1, 58, 58 },
        ["Crouch move"] = { -20, 30, 1, 58, 58 }, Peek = { -20, 45, 1, 58, 58 }, Air = { -13, 34, 1, 58, 58 },
        ["Air crouch"] = { -15, 44, 1, 58, 58 }, ["Fake duck"] = { 0, 0, 1, 58, 58 },
        Manual = { 0, 0, 1, 60, 60 }, Freestanding = { 0, 0, 1, 60, 60 }, ["Safe head"] = { 0, 0, 1, 30, 30 },
    }
    -- { defensive, hidden pitch, hidden yaw } (GS EXPLOIT_DEFAULTS; "Exploit" sutunu primordial'da yok)
    K.EXPLOIT_DEFAULTS = {
        Standing = { "Smart", "Off", "Off" }, Moving = { "Smart", "Up", "Random" },
        ["Slow walk"] = { "Smart", "Up", "Random" }, Crouching = { "Smart", "Off", "Off" },
        ["Crouch move"] = { "Smart", "Up", "Random" }, Peek = { "Smart", "Off", "Off" },
        Air = { "Smart", "Up", "Spin" }, ["Air crouch"] = { "Smart", "Up", "Random" },
        Manual = { "Smart", "Off", "Off" }, Freestanding = { "Smart", "Off", "Off" },
        ["Safe head"] = { "On peek", "Off", "Off" },
    }
    K.WAY_DEFAULTS = { -30, 0, 30, -15, 15 }
    K.YAW_MODES = { "L&R", "X-Way" }
    K.MODIFIERS = { "Off", "Center", "Offset", "Random", "Spin", "3-Way", "5-Way" }
    K.BODY_YAWS = { "Jitter", "Static", "Random", "Off" }
    K.ON_OFF = { "Off", "On" }
    K.DEF_MODES = { "Off", "On peek", "Smart", "Always on", "Tick based" }
    K.HIDDEN_PITCHES = { "Off", "Down", "Up", "Zero", "Switch", "Random", "Custom" }
    K.HIDDEN_YAWS = { "Off", "Sideways", "Spin", "Random", "Forward", "Custom" }
    K.TABS = { "Home", "Anti-Aim", "Builder", "Exploits", "Ragebot", "Visuals", "Misc" }
    K.WGROUPS = { "auto", "scout", "awp", "deagle", "revolver", "pistols", "other" }
    K.HITGROUPS = { [0] = "generic", [1] = "head", [2] = "chest", [3] = "stomach", [4] = "left arm",
        [5] = "right arm", [6] = "left leg", [7] = "right leg", [8] = "neck", [10] = "gear" }
    K.GRENADES = { hegrenade = true, flashbang = true, smokegrenade = true, molotov = true, incgrenade = true,
        decoy = true, c4 = true, tagrenade = true, healthshot = true }
    K.NON_BULLET = { inferno = true, molotov = true, incgrenade = true, hegrenade = true, decoy = true,
        flashbang = true, smokegrenade = true }
    -- V1.0.9 faz seti (faz 0 = normal). Tum GS / NL loglari (2429 mermi, oto haric): eski 1-7 fazlari (taraf cevir,
    -- +-15 derece, rastgele taraf, freestand, dusuk desync) normal AA'dan (%43 kafa) iyi degil (%42-48); tek fark
    -- yaratan taraf suresinin DUZENSIZ olmasi (eski faz 8, asimetrik: %36). Bu yuzden: 1 = eski en iyi (asimetrik),
    -- 2-4 = kendi fazlarimiz, hepsi taraf zamanlamasiyla oynar:
    --   1 asym        : bir taraf 2 paket uzun, uzun taraf 4 cevirmede bir yer degistirir.
    --   2 rnd-asym    : her taraf rastgele 1-4 paket (periyot yok).
    --   3 asym+duvar  : uzun tutulan taraf kafanin duvara bakan tarafi (A.cover); duvar yoksa rnd-asym gibi.
    --   4 atis-sonrasi: asimetrik + dusman mermisi yanimdan gecince taraf hemen cevrilir, ritim yeniden karilir.
    K.BRUTE_PHASES = {
        { invert = false, scale = 1.0, shift = 0, asym = 2 },
        { invert = false, scale = 1.0, shift = 0, rnd = true },
        { invert = false, scale = 1.0, shift = 0, asym = 2, wall = true },
        { invert = false, scale = 1.0, shift = 0, asym = 2, kick = true },
    }
    K.PHASE_NAME = { [0] = "normal", "asym", "rnd-asym", "asym+duvar", "atis-sonrasi" }
    -- Hafiza dosyasindaki faz kayitlarinin seti (eski setin sayilari / dusman tabanlari yeni sete tasinmaz).
    K.PHASE_SET = 2
    K.BRUTE_GROUPS = { "still", "move", "peek", "air" }
    K.GROUP_OF = { Moving = "move", ["Slow walk"] = "move", ["Crouch move"] = "move", Peek = "peek",
        Air = "air", ["Air crouch"] = "air" }
    -- Faz uygulanmayan / ogrenilmeyen durumlar (kendi AA'si olanlar).
    K.UNLEARNED = { ["Safe head"] = true, Manual = true, ["Fake duck"] = true, Ladder = true, Legit = true,
        Spin = true }
    K.LANDING_TICKS = 3
    K.MOVE_ENTER, K.MOVE_LEAVE = 10, 5
    K.DUCK_ENTER, K.DUCK_LEAVE = 0.7, 0.5
    K.PEEK_HOLD = 8
    K.EXPOSE_EVERY = 2
    K.SIGHT_RECENT = 32
    K.SIGHT_GAP = 24
    K.NEAR = 1800
    K.LOOKAHEAD = 0.2
    K.BRUTE_RADIUS = 40
    K.BRUTE_DEBOUNCE = 0.1
    K.MISS_WINDOW = 0.15
    K.SHOT_MEMORY = 5
    K.AIM_TARGET_HOLD = 1.5
    K.FORCE_STALL = 0.5
    K.MEMORY_LIMIT = 64
    K.FPS_CVARS = { "r_3dsky", "r_shadows", "cl_csm_shadows", "cl_csm_rope_shadows", "cl_csm_sprite_shadows",
        "cl_csm_static_prop_shadows", "cl_csm_viewmodel_shadows", "cl_csm_world_shadows",
        "cl_foot_contact_shadows", "mat_postprocess_enable", "func_break_max_pieces", "muzzleflash_light",
        "r_dynamic" }
    K.ASPECTS = { 1.3333, false, 1.25, 1.6 }
end

-------------------------------------------------------------------------------
-- Yardimcilar (vektor islemleri elle: vec3_t * sayi kullanilmaz)
-------------------------------------------------------------------------------
do
    local U = N.util
    local deg, rad, cos, sin = math.deg, math.rad, math.cos, math.sin
    local atan2 = math.atan2 or math.atan

    U.finite = function(x)
        return type(x) == "number" and x == x and x > -huge and x < huge
    end

    U.R = function(x)
        if not U.finite(x) then
            return 0
        end
        return floor(x + 0.5)
    end

    U.clamp = function(x, a, b)
        if x < a then
            return a
        end
        if x > b then
            return b
        end
        return x
    end

    U.norm = function(y)
        if not U.finite(y) then
            return 0
        end
        y = (y + 180) % 360 - 180
        if y == -180 then
            y = 180
        end
        return y
    end

    U.call = function(fn, ...)
        if type(fn) ~= "function" then
            return nil
        end
        local ok, a, b, c, d = pcall(fn, ...)
        if ok then
            return a, b, c, d
        end
        return nil
    end

    U.now = function()
        local ok, t = pcall(global_vars.real_time)
        return (ok and U.finite(t)) and t or 0
    end

    U.tick = function()
        local ok, t = pcall(global_vars.tick_count)
        return (ok and U.finite(t)) and t or 0
    end

    U.cur = function()
        local ok, t = pcall(global_vars.cur_time)
        return (ok and U.finite(t)) and t or 0
    end

    U.ipt = function()
        local ok, t = pcall(global_vars.interval_per_tick)
        return (ok and U.finite(t) and t > 0) and t or (1 / 64)
    end

    U.vec = function(x, y, z)
        return vec3_t(x, y, z)
    end

    U.okvec = function(v)
        local t = type(v)
        if t ~= "table" and t ~= "userdata" then
            return false
        end
        local ok, x, y, z = pcall(function()
            return v.x, v.y, v.z
        end)
        return ok and U.finite(x) and U.finite(y) and U.finite(z)
    end

    U.copy = function(v)
        return vec3_t(v.x, v.y, v.z)
    end

    U.add = function(v, x, y, z)
        return vec3_t(v.x + x, v.y + y, v.z + z)
    end

    U.dist = function(a, b)
        local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
        return sqrt(dx * dx + dy * dy + dz * dz)
    end

    U.dist2d = function(a, b)
        local dx, dy = a.x - b.x, a.y - b.y
        return sqrt(dx * dx + dy * dy)
    end

    U.yaw_to = function(a, b)
        return deg(atan2(b.y - a.y, b.x - a.x))
    end

    U.dir = function(yaw)
        local r = rad(yaw)
        return cos(r), sin(r)
    end

    -- p'yi yaw yonunde dist kadar (ve z'de dz) kaydir.
    U.offset = function(p, yaw, dist, dz)
        local cx, sy = U.dir(yaw)
        return vec3_t(p.x + cx * dist, p.y + sy * dist, p.z + (dz or 0))
    end

    -- p noktasinin a -> b dogru parcasina en kisa uzakligi.
    U.seg_dist = function(p, a, b)
        local abx, aby, abz = b.x - a.x, b.y - a.y, b.z - a.z
        local len_sq = abx * abx + aby * aby + abz * abz
        if len_sq <= 0 then
            return U.dist(p, a)
        end
        local t = ((p.x - a.x) * abx + (p.y - a.y) * aby + (p.z - a.z) * abz) / len_sq
        t = max(0, min(1, t))
        local dx, dy, dz = a.x + abx * t - p.x, a.y + aby * t - p.y, a.z + abz * t - p.z
        return sqrt(dx * dx + dy * dy + dz * dz)
    end

    U.prop = function(ent, name, i)
        if ent == nil then
            return nil
        end
        local ok, v
        if i ~= nil then
            ok, v = pcall(ent.get_prop, ent, name, i)
        else
            ok, v = pcall(ent.get_prop, ent, name)
        end
        if ok then
            return v
        end
        return nil
    end

    U.num = function(ent, name)
        local v = U.prop(ent, name)
        if U.finite(v) then
            return v
        end
        return nil
    end

    U.eye = function(ent)
        if ent == nil then
            return nil
        end
        local ok, v = pcall(ent.get_eye_position, ent)
        if ok and U.okvec(v) then
            return v
        end
        return nil
    end

    -- name: "HEAD", "PELVIS" ya da "CHEST" (e_hitboxes'ta STOMACH yok).
    U.hitbox = function(ent, name)
        if ent == nil then
            return nil
        end
        local id = e_hitboxes[name]
        local ok, v = pcall(ent.get_hitbox_pos, ent, id)
        if ok and U.okvec(v) then
            return v
        end
        return nil
    end

    U.origin = function(ent)
        local v = U.prop(ent, "m_vecOrigin")
        if U.okvec(v) then
            return v
        end
        local e = U.eye(ent)
        if e ~= nil then
            return vec3_t(e.x, e.y, e.z - 64)
        end
        return nil
    end

    U.vel = function(ent)
        local v = U.prop(ent, "m_vecVelocity")
        if U.okvec(v) then
            return v
        end
        return { x = 0, y = 0, z = 0 }
    end

    U.speed = function(ent)
        local v = U.vel(ent)
        return sqrt(v.x * v.x + v.y * v.y)
    end

    U.alive = function(ent)
        if ent == nil then
            return false
        end
        local ok, v = pcall(ent.is_alive, ent)
        return ok and v == true
    end

    U.dormant = function(ent)
        local ok, v = pcall(ent.is_dormant, ent)
        return ok and v == true
    end

    U.is_enemy = function(ent)
        local ok, v = pcall(ent.is_enemy, ent)
        return ok and v == true
    end

    U.index = function(ent)
        if ent == nil then
            return nil
        end
        local ok, v = pcall(ent.get_index, ent)
        if ok and U.finite(v) then
            return v
        end
        return nil
    end

    U.name = function(ent)
        if ent == nil then
            return "?"
        end
        local ok, v = pcall(ent.get_name, ent)
        if ok and v ~= nil then
            return (tostring(v):gsub("[\t\r\n]", " "))
        end
        return "?"
    end

    U.flag = function(ent, flag)
        if ent == nil then
            return nil
        end
        local ok, v = pcall(ent.has_player_flag, ent, e_player_flags[flag])
        if ok and type(v) == "boolean" then
            return v
        end
        return nil
    end

    U.hp = function(ent)
        local v = U.num(ent, "m_iHealth")
        return v or 100
    end

    -- Aktif silah: { name = "ssg08", class = "CWeaponSSG08" }. Tick basina oyuncu basina onbellek.
    U.wcache = { tick = -1, list = {} }
    U.winfo = function(ent)
        if ent == nil then
            return nil
        end
        local idx = U.index(ent) or 0
        local t = U.tick()
        local c = U.wcache
        if c.tick ~= t then
            c.tick, c.list = t, {}
        end
        local cached = c.list[idx]
        if cached ~= nil then
            return cached or nil
        end
        local info = false
        local ok, w = pcall(ent.get_active_weapon, ent)
        if ok and w ~= nil then
            local okn, name = pcall(w.get_name, w)
            local okc, class = pcall(w.get_class_name, w)
            name = (okn and type(name) == "string") and name:lower() or nil
            if name == nil then
                local okd, data = pcall(w.get_weapon_data, w)
                local cn = okd and data ~= nil and U.call(function()
                    return data.console_name
                end) or nil
                if type(cn) == "string" then
                    name = cn:lower():gsub("^weapon_", "")
                end
            end
            info = { ent = w, name = name or "?", class = (okc and type(class) == "string") and class or "" }
        end
        c.list[idx] = info
        return info or nil
    end

    -- "knife", "zeus" ya da nil. GS'de get_name "bayonet" de donebiliyor; sinif CKnife.
    U.melee = function(info)
        if info == nil then
            return nil
        end
        local n, c = info.name or "", info.class or ""
        if c == "CKnife" or c == "CKnifeGG" or n == "knife" or n == "bayonet" or n:find("knife", 1, true) then
            return "knife"
        end
        if n == "taser" or c == "CWeaponTaser" then
            return "zeus"
        end
        return nil
    end

    U.is_sniper = function(name)
        return name == "ssg08" or name == "awp"
    end

    U.is_bolt = function(name)
        return name == "ssg08" or name == "awp" or name == "revolver"
    end

    U.is_gun = function(info)
        if info == nil then
            return false
        end
        if U.melee(info) == "knife" or N.K.GRENADES[info.name] then
            return false
        end
        return info.name ~= "?"
    end

    U.wlabel = function(name)
        if name == nil or name == "?" then
            return "sen ?"
        end
        if name == "revolver" then
            return "sen r8"
        end
        return "sen " .. name
    end

    -- Hasar izi: trace.bullet(from, to, skip, target).damage; gecersizse 0.
    U.tdmg = function(from, to, skip, target)
        if from == nil or to == nil then
            return 0
        end
        N.diag.trn = N.diag.trn + 1
        local ok, r
        if target ~= nil then
            ok, r = pcall(trace.bullet, from, to, skip, target)
        else
            ok, r = pcall(trace.bullet, from, to, skip)
        end
        if not ok or r == nil then
            return 0
        end
        local okv, valid, dmg = pcall(function()
            return r.valid, r.damage
        end)
        if not okv or valid == false or not U.finite(dmg) then
            return 0
        end
        return max(0, dmg)
    end

    -- Duz iz: fraction (0..1), entity (ya da nil) ve iz gercekten alindi mi (hata / eksik deger = 1, nil, false).
    U.tline = function(from, to, skip)
        if from == nil or to == nil then
            return 1, nil
        end
        N.diag.trn = N.diag.trn + 1
        local ok, r
        if skip ~= nil then
            ok, r = pcall(trace.line, from, to, skip)
        else
            ok, r = pcall(trace.line, from, to)
        end
        if not ok or r == nil then
            return 1, nil
        end
        local okv, f, e = pcall(function()
            return r.fraction, r.entity
        end)
        if not okv or not U.finite(f) then
            return 1, nil
        end
        return f, e, true
    end

    -- Sayi metni: tam sayiysa %d, degilse bir ondalik.
    U.numtext = function(v)
        if type(v) == "boolean" then
            return v and "acik" or "kapali"
        end
        if not U.finite(v) then
            return tostring(v)
        end
        if abs(v - floor(v + 0.5)) < 1e-6 then
            return fmt("%d", U.R(v))
        end
        return fmt("%.1f", v)
    end

    U.game = function(name)
        local ok, v = pcall(game_rules.get_prop, name)
        if ok and U.finite(v) then
            return v
        end
        return nil
    end

    U.in_game = function()
        local ok, v = pcall(engine.is_in_game)
        return ok and v == true
    end
end

-------------------------------------------------------------------------------
-- Korunan cagrilar: her callback / dugme pcall icinde; hata ilk 3 kez yazilir, 50 hatada kapatilir.
-------------------------------------------------------------------------------
do
    local C = N.cb
    C.handlers, C.added = {}, {}

    C.run = function(h, ...)
        if h.dead then
            return
        end
        local ok, err = pcall(h.fn, ...)
        if not ok then
            h.errors = h.errors + 1
            if h.errors <= 3 then
                N.log.line(fmt("%s hata verdi: %s", h.name, tostring(err)))
            end
            if h.errors == 50 then
                h.dead = true
                N.log.line(h.name .. " 50 hata, kapatildi")
            end
        end
    end

    -- Dugmeler ve gecikmeli cagrilar icin tek korunan fonksiyon.
    C.wrap = function(name, fn)
        local h = { name = name, fn = fn, errors = 0, dead = false }
        return function(...)
            C.run(h, ...)
        end
    end
end

-------------------------------------------------------------------------------
-- Log: halka tampon (12 000 satir), konsol (client.log), dosya (nykle_log.txt, toplu yazma)
-------------------------------------------------------------------------------
do
    local U, L = N.util, N.log
    L.lines, L.cap, L.trim = {}, 12000, 1000
    L.pending, L.file = {}, "nykle_log.txt"
    -- Oturum basina dosya siniri 2 MB; asilinca dosyaya bir not ve sadece ozet satirlari (L.PRIO) 128 KB'lik
    -- yedek payla yazilir: yuklenen logda harita / dusman ozeti, teshis ve kapanis eksik kalmasin.
    L.bytes, L.cap_bytes, L.reserve, L.capped = 0, 2 * 1024 * 1024, 128 * 1024, false
    L.PRIO = { "harita ozeti", "dusman ozeti", "dbg teshis", "teshis:", "script kaldirildi" }
    L.saved_at, L.dumped_at = -1000, -1000
    L.load_entry, L.notes = nil, {}
    -- n: bu oturumda yazilan satir sayisi (halka kirpilsa da artar; dbg round basligi tekrar denetimi).
    L.n = 0
    L.marker = "] V" .. N.VERSION .. " (" .. N.EDITION .. " edition) yuklendi"

    L.stamp = function()
        local ok, h, m, s = pcall(client.get_local_time)
        if ok and U.finite(h) and U.finite(m) and U.finite(s) then
            return fmt("%02d:%02d:%02d", U.R(h), U.R(m), U.R(s))
        end
        return fmt("%.1f", U.now())
    end

    L.console = function(line)
        if pcall(client.log, color_t(210, 210, 210), line) then
            return
        end
        pcall(print, line)
    end

    L.push = function(line)
        L.n = L.n + 1
        local entry = L.stamp() .. " " .. line
        local lines = L.lines
        lines[#lines + 1] = entry
        if #lines > L.cap + L.trim then
            local keep = {}
            for i = #lines - L.cap + 1, #lines do
                keep[#keep + 1] = lines[i]
            end
            L.lines = keep
        end
        if N.fs.ok and (not L.capped or L.prio(entry)) then
            L.pending[#L.pending + 1] = entry
        end
        return entry
    end

    -- Sinir asildiktan sonra da dosyaya giden ozet satiri mi ("SS:DD:SS [Nykle.win] <metin>").
    L.prio = function(entry)
        local at = entry:find("] ", 1, true)
        local body = at ~= nil and entry:sub(at + 2) or entry
        for _, prefix in ipairs(L.PRIO) do
            if body:sub(1, #prefix) == prefix then
                return true
            end
        end
        return false
    end

    -- Tek giris noktasi: "[Nykle.win] " oneki, halka + dosya kuyrugu + konsol.
    L.line = function(text)
        local line = "[" .. N.SCRIPT .. "] " .. tostring(text)
        local entry = L.push(line)
        L.console(line)
        return entry
    end

    -- Bir log anahtari icin en fazla "every" saniyede bir satir.
    -- count = true: sure dolmadan gelen (yazilmayan) satirlar sayilir; sonraki satira " (N kez)" eklenir (N = o satir
    -- dahil, son yazilandan beri kac kez).
    L.limits, L.skipped = {}, {}
    L.every = function(key, every, text, count)
        local now = U.now()
        local last = L.limits[key]
        if last ~= nil and now >= last and now - last < every then
            if count then
                L.skipped[key] = (L.skipped[key] or 0) + 1
            end
            return false
        end
        L.limits[key] = now
        local n = L.skipped[key]
        if count and n ~= nil and n > 0 then
            text = text .. fmt(" (%d kez)", n + 1)
        end
        L.skipped[key] = nil
        L.line(text)
        return true
    end

    L.flush = function()
        if #L.pending == 0 then
            return true
        end
        local F = N.fs
        local batch = L.pending
        L.pending = {}
        if not F.ok then
            return false
        end
        -- Sigan kisim yazilir; sinirda not dosyaya da gider, sonrasi sadece ozet satirlari (yedek pay icinde).
        local out, size = {}, 0
        local limit = L.cap_bytes + (L.capped and L.reserve or 0)
        for _, entry in ipairs(batch) do
            local n = #entry + 1
            if not L.capped and L.bytes + size + n > L.cap_bytes then
                L.capped, limit = true, L.cap_bytes + L.reserve
                local note = L.line(fmt("log dosyasi bu oturumda %d MB'yi gecti: dosyaya bundan sonra sadece ozet"
                    .. " satirlari (harita / dusman ozeti, teshis, kapanis), butun loglar hafizada", U.R(L.cap_bytes / 1048576)))
                out[#out + 1], size = note, size + #note + 1
            end
            if L.bytes + size + n <= limit and (not L.capped or L.prio(entry)) then
                out[#out + 1], size = entry, size + n
            end
        end
        if #out == 0 then
            return false
        end
        local text = concat(out, "\n") .. "\n"
        if F.put(L.file, text, "a") then
            L.bytes = L.bytes + #text
            return true
        end
        return false
    end

    -- PAINT'ten: hayattayken 300 sn'de, olu / donma / oyun disi 60 sn'de bir dosyaya.
    L.timer = function()
        local now = U.now()
        local st = N.st
        local frozen = U.game("m_bFreezePeriod") == 1
        local every = (st.alive and not frozen and U.in_game()) and 300 or 60
        if now < L.saved_at or now - L.saved_at >= every then
            L.saved_at = now
            L.flush()
        end
    end

    -- Yuklemede: yeni surum = yeni dosya; 2 MB ustu son 1 MB'ye kirpilir; 4 MB ustu sifirlanir.
    L.open = function()
        local F = N.fs
        if not F.ok then
            return
        end
        local size = F.size(L.file)
        if size == nil then
            return
        end
        if size > 4 * 1024 * 1024 then
            F.put(L.file, "", "w")
            L.notes[#L.notes + 1] = "onceki log 4 MB'yi gecmisti, sifirlandi"
            return
        end
        local text = F.read(L.file)
        if text == nil or text == "" then
            return
        end
        if not text:find(L.marker, 1, true) then
            F.put(L.file, "", "w")
            L.notes[#L.notes + 1] = "log dosyasi yeni surum icin sifirlandi"
            return
        end
        if #text > 2 * 1024 * 1024 then
            local tail = text:sub(#text - 1024 * 1024 + 1)
            tail = tail:gsub("^[^\n]*\n", "", 1)
            F.put(L.file, tail, "w")
            L.notes[#L.notes + 1] = "log dosyasi 2 MB'yi gecmisti, son 1 MB tutuldu"
        end
    end

    L.dump = function()
        local now = U.now()
        if now >= L.dumped_at and now - L.dumped_at < 10 then
            L.console(fmt("[%s] loglar %d sn once konsola yazildi (yukari kaydir); tekrar yazmak icin 10 sn bekle",
                N.SCRIPT, U.R(now - L.dumped_at)))
            return false
        end
        L.dumped_at = now
        L.console(fmt("[%s] ===== tum loglar: %d satir (bu oturum) =====", N.SCRIPT, #L.lines))
        for _, line in ipairs(L.lines) do
            L.console(line)
        end
        L.console(fmt("[%s] ===== loglarin sonu =====", N.SCRIPT))
        return true
    end

    -- Pano: VGUI_System010 sanal tablo 9 (SetClipboardText), memory.get_vfunc ile.
    L.clipboard = function(text)
        local ok, res = pcall(function()
            local f = N.fs.ffi
            if f == nil then
                return "ffi yok"
            end
            local mem = memory
            if mem == nil or mem.create_interface == nil or mem.get_vfunc == nil then
                return "memory yok"
            end
            local iface = mem.create_interface("vgui2.dll", "VGUI_System010")
            if iface == nil then
                return "VGUI_System010 bulunamadi"
            end
            local fnp = mem.get_vfunc(iface, 9)
            if fnp == nil then
                return "vfunc 9 yok"
            end
            local set_text = f.cast("void(__thiscall*)(void*, const char*, int)", fnp)
            set_text(f.cast("void***", iface), text, #text)
            return true
        end)
        if ok and res == true then
            return true
        end
        return false, tostring(res)
    end

    L.copy = function()
        L.flush()
        local ok, why = L.clipboard(concat(L.lines, "\n"))
        if ok then
            L.line(fmt("loglar panoya kopyalandi (%d satir)", #L.lines))
            return true
        end
        L.line(fmt("panoya kopyalanamadi (%s): loglar asagida konsolda", tostring(why)))
        L.dumped_at = -1000
        L.dump()
        return false
    end

    L.clear = function()
        L.lines, L.pending = {}, {}
        L.bytes, L.capped = 0, false
        if N.fs.ok then
            N.fs.put(L.file, (L.load_entry or L.stamp() .. " [" .. N.SCRIPT .. "] V" .. N.VERSION .. " ("
                .. N.EDITION .. " edition) yuklendi") .. "\n", "w")
        end
        if L.load_entry ~= nil then
            L.lines[1] = L.load_entry
        end
        L.line("kayitli loglar temizlendi")
    end
end

-------------------------------------------------------------------------------
-- Dosya sistemi: ffi + VBaseFileSystem011 (include/File System.lua deseni), yol kimligi "MOD"
-------------------------------------------------------------------------------
do
    local U, F = N.util, N.fs
    F.ok, F.why, F.fails = false, "baslatilmadi", 0
    F.MAX_READ = 4 * 1024 * 1024

    F.init = function()
        local ok, err = pcall(function()
            local f = ffi
            if f == nil then
                local okr, r = pcall(require, "ffi")
                if okr then
                    f = r
                end
            end
            if f == nil then
                error("ffi yok", 0)
            end
            F.ffi = f
            local mem = memory
            if mem == nil or mem.create_interface == nil then
                error("memory yok", 0)
            end
            local iface = mem.create_interface("filesystem_stdio.dll", "VBaseFileSystem011")
            if iface == nil then
                error("VBaseFileSystem011 bulunamadi", 0)
            end
            local cls = f.cast("void***", iface)
            local vt = cls[0]
            F.cls = cls
            F.c_read = f.cast("int (__thiscall*)(void*, void*, int, void*)", vt[0])
            F.c_write = f.cast("int (__thiscall*)(void*, void const*, int, void*)", vt[1])
            F.c_open = f.cast("void* (__thiscall*)(void*, const char*, const char*, const char*)", vt[2])
            F.c_close = f.cast("void (__thiscall*)(void*, void*)", vt[3])
            F.c_size = f.cast("unsigned int (__thiscall*)(void*, void*)", vt[7])
            F.c_exists = f.cast("bool (__thiscall*)(void*, const char*, const char*)", vt[10])
        end)
        F.ok = ok
        if not ok then
            F.why = tostring(err)
        else
            F.why = nil
        end
        return ok
    end

    F.fail = function(reason)
        F.fails = F.fails + 1
        if F.fails >= 3 and F.ok then
            F.ok, F.why = false, tostring(reason)
            N.log.line(fmt("log dosyasi yazilamadi: %s (loglar hafizada; Console > Print all logs)", F.why))
        end
    end

    -- mode "a" (ekle) ya da "w" (bastan yaz).
    F.put = function(name, text, mode)
        if not F.ok then
            return false
        end
        local ok, res = pcall(function()
            -- V1.0.7: ikili mod ("ab" / "wb"). Metin modunda Windows \n'i \r\n yapiyor, okurken boyut tutmuyor ve
            -- tampon sonunda NUL kaliyordu: hafiza dosyasi "kayit sayisi 30 != 33" diye bos yukleniyordu.
            local h = F.c_open(F.cls, name, mode == "a" and "ab" or "wb", "MOD")
            if h == nil then
                return "dosya acilamadi"
            end
            if #text > 0 then
                F.c_write(F.cls, text, #text, h)
            end
            F.c_close(F.cls, h)
            return true
        end)
        if ok and res == true then
            F.fails = 0
            return true
        end
        F.fail(ok and res or ("hata: " .. tostring(res)))
        return false
    end

    F.exists = function(name)
        if not F.ok then
            return false
        end
        local ok, v = pcall(F.c_exists, F.cls, name, "MOD")
        return ok and v == true
    end

    -- Boyut (bayt) ya da nil (dosya yok / okunamadi).
    F.size = function(name)
        if not F.exists(name) then
            return nil
        end
        local ok, n = pcall(function()
            local h = F.c_open(F.cls, name, "r", "MOD")
            if h == nil then
                return nil
            end
            local s = F.c_size(F.cls, h)
            F.c_close(F.cls, h)
            return tonumber(s)
        end)
        if ok then
            return n
        end
        return nil
    end

    -- Metin ya da nil. 4 MB ustu okunmaz.
    F.read = function(name)
        if not F.exists(name) then
            return nil
        end
        local ok, text = pcall(function()
            local h = F.c_open(F.cls, name, "rb", "MOD")
            if h == nil then
                return nil
            end
            local n = tonumber(F.c_size(F.cls, h)) or 0
            if n <= 0 or n > F.MAX_READ then
                F.c_close(F.cls, h)
                return nil
            end
            local buf = F.ffi.new("char[?]", n + 1)
            local got = tonumber(F.c_read(F.cls, buf, n, h))
            F.c_close(F.cls, h)
            -- Gercekten okunan bayt kadar (eski metin modlu dosyalarda daha az gelir); kalan NUL / \r temizlenir.
            if got == nil or got < 0 or got > n then
                got = n
            end
            return (F.ffi.string(buf, got):gsub("[%z\r]", ""))
        end)
        if ok and type(text) == "string" then
            return text
        end
        return nil
    end
end

-------------------------------------------------------------------------------
-- Native menu referanslari (yuklemede bulunur, eksikse 10 sn'de bir yeniden denenir)
-------------------------------------------------------------------------------
do
    local U, P = N.util, N.ref
    P.items, P.missing, P.noted = {}, {}, {}
    P.retry_at = 0

    -- { anahtar, tus mu ([2]), yollar (YENI once, ESKI yedek) }
    P.defs = {
        { "dt", true, { { "aimbot", "general", "exploits", "doubletap", "enable" } } },
        { "hs", true, { { "aimbot", "general", "exploits", "hideshots", "enable" } } },
        { "fakeping", true, { { "aimbot", "general", "fake ping", "enable" } } },
        { "autopeek", true, { { "aimbot", "general", "misc", "autopeek" },
            { "aimbot", "general", "misc", "autopeek", "enable" } } },
        { "fakeduck", true, { { "antiaim", "main", "general", "fakeduck" },
            { "antiaim", "main", "general", "fake duck" } } },
        { "slowwalk", true, { { "misc", "main", "movement", "slow walk" },
            { "misc", "main", "movement", "slow walk", "enable" } } },
        { "fs", true, { { "antiaim", "main", "auto direction", "enable" } } },
        { "fs_states", false, { { "antiaim", "main", "auto direction", "states" } } },
        { "inverter", true, { { "antiaim", "main", "manual", "invert desync" } } },
        { "ext_angles", true, { { "antiaim", "main", "extended angles", "enable" } } },
        { "jitter_mode", false, { { "antiaim", "main", "angles", "jitter mode" } } },
        { "rotate", false, { { "antiaim", "main", "angles", "rotate" } } },
        { "body_lean", false, { { "antiaim", "main", "angles", "body lean" } } },
        { "moving_body_lean", false, { { "antiaim", "main", "angles", "moving body lean" } } },
        { "yaw_add", false, { { "antiaim", "main", "angles", "yaw add" } } },
        { "ext_moving", false, { { "antiaim", "main", "extended angles", "enable while moving" } } },
        { "override_move", false, { { "antiaim", "main", "desync", "override stand#move" } } },
        { "override_slow", false, { { "antiaim", "main", "desync", "override stand#slow walk" } } },
        { "anti_brute_native", false, { { "antiaim", "main", "desync", "anti bruteforce" } } },
        { "on_shot", false, { { "antiaim", "main", "desync", "on shot" } } },
        { "side_stand", false, { { "antiaim", "main", "desync", "side#stand" } } },
        { "left_amount_stand", false, { { "antiaim", "main", "desync", "left amount#stand" } } },
        { "right_amount_stand", false, { { "antiaim", "main", "desync", "right amount#stand" } } },
        { "fl_amount", false, { { "antiaim", "main", "fakelag", "amount" } } },
        { "fl_blc", false, { { "antiaim", "main", "fakelag", "break lag compensation" } } },
        { "buybot", false, { { "misc", "utility", "buybot", "enable" } } },
        { "buybot_nades", false, { { "misc", "utility", "buybot", "grenades" } } },
        { "autostrafer", false, { { "misc", "main", "movement", "autostrafer" } } },
    }
    for _, w in ipairs(N.K.WGROUPS) do
        local old = (w == "deagle" or w == "revolver") and "heavy pistols" or w
        P.defs[#P.defs + 1] = { "md:" .. w, false, { { "aimbot", w, "targeting", "min. damage" },
            { "aimbot", old, "targeting", "min. damage" } } }
        P.defs[#P.defs + 1] = { "mdo:" .. w, "pair", { { "aimbot", w, "target overrides", "min. damage" },
            { "aimbot", old, "target overrides", "force min. damage" } } }
        P.defs[#P.defs + 1] = { "hc:" .. w, false, { { "aimbot", w, "targeting", "hitchance" },
            { "aimbot", old, "targeting", "hitchance" } } }
    end
    P.defs[#P.defs + 1] = { "qs:scout", false, { { "aimbot", "scout", "accuracy", "options" } } }
    P.defs[#P.defs + 1] = { "qs:awp", false, { { "aimbot", "awp", "accuracy", "options" } } }

    P.find = function(path)
        local ok, r
        if #path == 5 then
            ok, r = pcall(menu.find, path[1], path[2], path[3], path[4], path[5])
        else
            ok, r = pcall(menu.find, path[1], path[2], path[3], path[4])
        end
        if not ok then
            return nil
        end
        local t = type(r)
        if t ~= "table" and t ~= "userdata" then
            return nil
        end
        return r
    end

    P.sub = function(r, i)
        local ok, v = pcall(function()
            return r[i]
        end)
        if ok and type(v) ~= "nil" then
            return v
        end
        return nil
    end

    -- :get() ilk denemede hata veren yer tutucu yok sayilir.
    P.probe = function(obj, name)
        if obj == nil then
            return false
        end
        local ok
        if name ~= nil then
            ok = pcall(obj.get, obj, name)
        else
            ok = pcall(obj.get, obj)
        end
        return ok
    end

    P.note = function(key, path)
        if P.noted[key] then
            return
        end
        P.noted[key] = true
        N.log.line("menude bulunamadi: " .. concat(path or { key }, " > "))
    end

    P.resolve_one = function(def)
        local key, kind, paths = def[1], def[2], def[3]
        for _, path in ipairs(paths) do
            local r = P.find(path)
            if r ~= nil then
                if kind == "pair" then
                    local slider, keyobj = P.sub(r, 1), P.sub(r, 2)
                    if P.probe(slider) and P.probe(keyobj) then
                        local w = key:sub(5)
                        P.items["mdo:" .. w], P.items["mdk:" .. w] = slider, keyobj
                        P.missing[key] = nil
                        return true
                    end
                elseif kind == true then
                    local k = P.sub(r, 2)
                    if P.probe(k) then
                        P.items[key], P.missing[key] = k, nil
                        return true
                    end
                else
                    if key == "fs_states" or key == "qs:scout" or key == "qs:awp" or key == "buybot_nades" then
                        P.items[key], P.missing[key] = r, nil
                        return true
                    end
                    if P.probe(r) then
                        P.items[key], P.missing[key] = r, nil
                        return true
                    end
                end
            end
        end
        P.missing[key] = true
        P.note(key, paths[1])
        return false
    end

    P.resolve = function()
        for _, def in ipairs(P.defs) do
            local key = def[1]
            local have
            if def[2] == "pair" then
                -- Cift: slider ve tus ikisi de olmali (biri hata verip silindiyse ikisi yeniden aranir).
                have = P.items["mdo:" .. key:sub(5)] ~= nil and P.items["mdk:" .. key:sub(5)] ~= nil
            else
                have = P.items[key] ~= nil
            end
            if not have then
                P.resolve_one(def)
            end
        end
        P.retry_at = U.now() + 10
    end

    -- PAINT: eksik varsa 10 sn'de bir sessizce yeniden dene.
    P.retry = function()
        local now = U.now()
        if now < P.retry_at and now >= P.retry_at - 20 then
            return
        end
        if next(P.missing) ~= nil then
            P.resolve()
        else
            P.retry_at = now + 10
        end
    end

    P.get = function(key)
        local obj = P.items[key]
        if obj == nil then
            return nil
        end
        local ok, v = pcall(obj.get, obj)
        if not ok then
            P.items[key] = nil
            -- mdk: / mdo: P.defs'te "mdo:<grup>" cifti olarak durur; P.retry onu yeniden cozer.
            local pre = key:sub(1, 4)
            local def_key = (pre == "mdk:" or pre == "mdo:") and ("mdo:" .. key:sub(5)) or key
            P.missing[def_key] = true
            P.note(key)
            return nil
        end
        return v
    end

    P.on = function(key)
        return P.get(key) == true
    end

    P.wgroup = function()
        local ok, v = pcall(ragebot.get_active_cfg)
        if ok and U.finite(v) then
            return N.K.WGROUPS[floor(v) + 1] or "other"
        end
        return "other"
    end

    -- Etkin Min. damage: override tusu basiliyken override degeri, yoksa normal deger. (deger, override_mi)
    P.md_eff = function(w)
        w = w or N.st.wgroup
        if P.on("mdk:" .. w) then
            local v = P.get("mdo:" .. w)
            if U.finite(v) then
                return v, true
            end
        end
        local v = P.get("md:" .. w)
        if U.finite(v) then
            return v, false
        end
        return nil, false
    end

    P.need = function(hp, md)
        if md >= 100 then
            return hp + (md - 100)
        end
        return md
    end

    -- Bu hedeften native ayarin gercekten istedigi hasar (100 = can).
    P.md_need = function(hp, w)
        local md = P.md_eff(w)
        if md == nil or not U.finite(hp) then
            return nil
        end
        return P.need(hp, md)
    end

    P.charge = function()
        local c = U.call(exploits.get_charge)
        local m = U.call(exploits.get_max_charge)
        return U.finite(c) and c or 0, U.finite(m) and m or 0
    end

    P.dt_ready = function()
        if not P.on("dt") then
            return false
        end
        local c, m = P.charge()
        return m > 0 and c >= m
    end

    P.fd_on = function()
        local v = U.call(antiaim.is_fakeducking)
        return v == true or P.on("fakeduck")
    end

    P.multi = function(key, item)
        local obj = P.items[key]
        if obj == nil then
            return nil
        end
        local ok, v = pcall(obj.get, obj, item)
        if ok and type(v) == "boolean" then
            return v
        end
        return nil
    end
end

-------------------------------------------------------------------------------
-- Menu (gruplar ve oge adlari config anahtari: DONDURULMUS, bkz. SPEC §2)
-------------------------------------------------------------------------------
do
    local U, UI = N.util, N.ui
    local K = N.K
    UI.e, UI.def, UI.b, UI.bdef, UI.x, UI.xdef = {}, {}, {}, {}, {}, {}
    UI.tracked, UI.vis, UI.failed = {}, {}, 0
    UI.G = {
        home = "Nykle.win | Home", console = "Nykle.win | Console", aa = "Nykle.win | Anti-Aim",
        protect = "Nykle.win | Protection", builder = "Nykle.win | Builder",
        bexploit = "Nykle.win | Builder exploit", exploits = "Nykle.win | Exploits", peek = "Nykle.win | Peek",
        rage = "Nykle.win | Ragebot", visuals = "Nykle.win | Visuals", misc = "Nykle.win | Misc",
    }
    UI.GROUP_ORDER = {
        { "home", 1, 0 }, { "console", 2, 1 }, { "aa", 1, 2 }, { "protect", 2, 2 }, { "builder", 1, 3 },
        { "bexploit", 2, 3 }, { "exploits", 1, 4 }, { "peek", 2, 4 }, { "rage", 1, 5 }, { "visuals", 1, 6 },
        { "misc", 1, 7 },
    }

    UI.val = function(el, def)
        if el == nil then
            return def
        end
        local ok, v = pcall(el.get, el)
        if ok and v ~= nil then
            return v
        end
        return def
    end

    UI.make = function(kind, group, name, a, b, c, d, e)
        local ok, el
        if kind == "cb" then
            ok, el = pcall(menu.add_checkbox, group, name, a)
        elseif kind == "sl" then
            ok, el = pcall(menu.add_slider, group, name, a, b, c, d, e)
        elseif kind == "sel" then
            ok, el = pcall(menu.add_selection, group, name, a)
        elseif kind == "txt" then
            ok, el = pcall(menu.add_text, group, name)
        elseif kind == "btn" then
            ok, el = pcall(menu.add_button, group, name, a)
        end
        if not ok or el == nil then
            UI.failed = UI.failed + 1
            return nil
        end
        return el
    end

    UI.track = function(el, def, label, items)
        if el ~= nil then
            UI.tracked[#UI.tracked + 1] = { el = el, def = def, label = label, items = items }
        end
    end

    UI.set = function(el, v)
        if el ~= nil then
            pcall(el.set, el, v)
        end
    end

    -- Genel ogeler: anahtar, grup, ad, tur, varsayilan, (slider: min, max, adim, hassasiyet, birim; sel: liste),
    -- izlenen mi (R).
    UI.cb = function(key, g, name, def, tracked)
        local el = UI.make("cb", UI.G[g], name, def)
        UI.e[key], UI.def[key] = el, def
        if tracked then
            UI.track(el, def, name)
        end
        return el
    end

    UI.sl = function(key, g, name, lo, hi, def, tracked, suffix, step, prec)
        local el = UI.make("sl", UI.G[g], name, lo, hi, step or 1, prec or 0, suffix or "")
        UI.set(el, def)
        UI.e[key], UI.def[key] = el, def
        if tracked then
            UI.track(el, def, name)
        end
        return el
    end

    UI.sel = function(key, g, name, items, def, tracked)
        local el = UI.make("sel", UI.G[g], name, items)
        UI.set(el, def)
        UI.e[key], UI.def[key] = el, def
        if tracked then
            UI.track(el, def, name, items)
        end
        return el
    end

    UI.txt = function(key, g, text)
        UI.e[key] = UI.make("txt", UI.G[g], text)
        return UI.e[key]
    end

    UI.btn = function(key, g, name, fn)
        UI.e[key] = UI.make("btn", UI.G[g], name, N.cb.wrap("button: " .. name, fn))
        return UI.e[key]
    end

    UI.color = function(key, host, name, col)
        local el = UI.e[host]
        if el == nil then
            return nil
        end
        local ok, c = pcall(el.add_color_picker, el, name, col)
        if ok and c ~= nil then
            UI.e[key] = c
            return c
        end
        UI.failed = UI.failed + 1
        return nil
    end

    -- Kisa okuyucular.
    N.v = function(key)
        return UI.val(UI.e[key], UI.def[key])
    end
    N.on = function(key)
        return UI.val(UI.e[key], UI.def[key]) == true
    end
    -- Builder: durumun kendi satiri (Override kapaliysa Global).
    N.bv = function(state, key)
        local row = UI.b[state]
        local defs = UI.bdef[state]
        if row == nil or defs == nil then
            return nil
        end
        return UI.val(row[key], defs[key])
    end
    N.xv = function(state, key)
        local row = UI.x[state]
        local defs = UI.xdef[state]
        if row == nil or defs == nil then
            return nil
        end
        return UI.val(row[key], defs[key])
    end

    local function index_of(list, name)
        for i, v in ipairs(list) do
            if v == name then
                return i
            end
        end
        return 1
    end
    UI.index_of = index_of

    UI.build_builder = function()
        local g = UI.G.builder
        UI.e.state = UI.make("sel", g, "State", K.STATES)
        UI.set(UI.e.state, 1)
        UI.def.state = 1
        for _, s in ipairs(K.STATES) do
            local row, defs = {}, {}
            UI.b[s], UI.bdef[s] = row, defs
            local d = K.DEFAULTS[s]
            local function add(key, kind, name, def, a, b, c, items)
                local label = "[" .. s .. "] " .. name
                local el
                if kind == "cb" then
                    el = UI.make("cb", g, label, def)
                elseif kind == "sl" then
                    el = UI.make("sl", g, label, a, b, 1, 0, c or "")
                    UI.set(el, def)
                else
                    el = UI.make("sel", g, label, items)
                    UI.set(el, def)
                end
                row[key], defs[key] = el, def
                UI.track(el, def, label, items)
            end
            local movement = K.MOVEMENT[s]
            local fd = s == "Fake duck"
            if K.OVERRIDABLE[s] then
                add("override", "cb", "Override", true)
            end
            add("yaw_mode", "sel", "Yaw mode", 1, nil, nil, nil, K.YAW_MODES)
            add("yaw_left", "sl", "Yaw left", d[1], -180, 180)
            add("yaw_right", "sl", "Yaw right", d[2], -180, 180)
            add("ways", "sl", "Ways", 3, 3, 5)
            for i = 1, 5 do
                add("way" .. i, "sl", "Way " .. i, K.WAY_DEFAULTS[i], -180, 180)
            end
            add("yaw_random", "sl", "Yaw randomize", fd and 20 or 0, 0, 30)
            add("modifier", "sel", "Yaw modifier", 1, nil, nil, nil, K.MODIFIERS)
            add("mod_random", "sl", "Modifier randomize", 0, 0, 60)
            add("mod_offset", "sl", "Modifier offset", 0, -180, 180)
            local body = movement and 1 or ((s == "Manual" or s == "Freestanding") and 2 or 3)
            add("body_yaw", "sel", "Body yaw", body, nil, nil, nil, K.BODY_YAWS)
            add("body_fs", "sel", "Body freestanding", fd and 2 or 1, nil, nil, nil, K.ON_OFF)
            add("delay_random", "sl", "Delay randomize", movement and 1 or 0, 0, 5, "t")
            add("limit_random", "sl", "Limit randomize", fd and 10 or 0, 0, 30)
            add("delay", "sl", "Jitter delay", d[3], 1, 10, "t")
            add("left_limit", "sl", "Left limit", d[4], 0, 60)
            add("right_limit", "sl", "Right limit", d[5], 0, 60)
        end
        local gx = UI.G.bexploit
        for _, s in ipairs(K.STATES) do
            if s == "Global" or s == "Fake duck" then
                UI.x[s] = { text = UI.make("txt", gx,
                    "[" .. s .. "] No exploit settings (Global shares AA only, fake duck has no DT)") }
                UI.xdef[s] = {}
            else
                local row, defs = {}, {}
                UI.x[s], UI.xdef[s] = row, defs
                local d = K.EXPLOIT_DEFAULTS[s]
                local function add(key, kind, name, def, a, b, items, suffix)
                    local label = "[" .. s .. "] " .. name
                    local el
                    if kind == "sl" then
                        el = UI.make("sl", gx, label, a, b, 1, 0, suffix or "")
                    else
                        el = UI.make("sel", gx, label, items)
                    end
                    UI.set(el, def)
                    row[key], defs[key] = el, def
                    UI.track(el, def, label, items)
                end
                add("def_mode", "sel", "Defensive", index_of(K.DEF_MODES, d[1]), nil, nil, K.DEF_MODES)
                add("def_ticks", "sl", "Defensive every", 14, 2, 22, nil, "t")
                add("hidden_pitch", "sel", "Hidden pitch", index_of(K.HIDDEN_PITCHES, d[2]), nil, nil,
                    K.HIDDEN_PITCHES)
                add("hidden_pitch_value", "sl", "Pitch value", 0, -89, 89)
                add("hidden_yaw", "sel", "Hidden yaw", index_of(K.HIDDEN_YAWS, d[3]), nil, nil, K.HIDDEN_YAWS)
                add("hidden_yaw_value", "sl", "Yaw value", 90, -180, 180)
            end
        end
    end

    UI.build = function()
        local B = UI
        -- Home
        B.cb("enabled", "home", "Enable Nykle.win", true, false)
        B.sel("tab", "home", "Tab", K.TABS, 1, false)
        B.cb("recommended", "home", "Always use recommended settings", true, false)
        B.txt("info1", "home", "No need to change any setting.")
        B.txt("info2", "home", "Bind: native manual / auto direction / autopeek")
        -- Console
        B.cb("resolver_log", "console", "Resolver log", true, false)
        B.cb("shot_log", "console", "Shot log", true, false)
        B.cb("hit_log", "console", "Hit log", true, false)
        B.cb("brute_log", "console", "Anti-brute log", false, false)
        B.cb("debug_log", "console", "Detailed log (for analysis)", true, false)
        B.cb("log_quiet", "console", "Logs only in console + file (not on screen)", true, false)
        B.btn("log_copy", "console", "Copy all logs", function()
            N.log.copy()
        end)
        B.btn("log_print", "console", "Print all logs to console", function()
            N.log.dump()
        end)
        B.btn("log_save", "console", "Save logs to file now", function()
            if N.log.flush() and N.fs.ok then
                N.log.line("loglar dosyaya yazildi: " .. N.log.file)
            else
                N.log.line("loglar dosyaya yazilamadi (" .. tostring(N.fs.why or "dosya yok") .. ")")
            end
        end)
        B.btn("log_clear", "console", "Clear saved logs", function()
            N.log.clear()
        end)
        B.btn("forget", "console", "Forget learned enemies", function()
            N.mem.forget()
        end)
        B.btn("stats_reset", "console", "Reset stats", function()
            N.stats.reset()
        end)
        -- Anti-Aim
        B.sel("pitch", "aa", "Pitch", { "Down", "Zero", "Off" }, 1, true)
        B.sel("yaw_base", "aa", "Yaw base", { "At target", "Local view" }, 1, true)
        B.cb("avoid_backstab", "aa", "Avoid backstab", true, true)
        B.cb("backstab_def", "aa", "Defensive while knife is close", true, true)
        B.cb("legit_use", "aa", "Legit AA on use", true, true)
        B.cb("spin", "aa", "Spin when idle", true, true)
        B.cb("spin_warmup", "aa", "Spin in warmup", false, true)
        B.cb("spin_enemies", "aa", "Spin: no enemies alive", true, true)
        B.sel("spin_pitch", "aa", "Spin pitch", { "Off", "Down" }, 1, true)
        B.sl("spin_speed", "aa", "Spin speed", 1, 20, 6, true)
        -- Protection
        B.cb("fs_air", "protect", "FS: disable in air", true, true)
        B.cb("fs_crouch", "protect", "FS: disable while crouching", false, true)
        B.cb("fs_slow", "protect", "FS: disable while slow walking", false, true)
        B.cb("fs_moving", "protect", "FS: disable while moving", false, true)
        B.cb("fs_auto", "protect", "FS: auto when standing still", true, true)
        B.cb("safe_head", "protect", "Safe head", true, true)
        B.cb("safe_knife", "protect", "Safe head: knife/zeus in air crouch", true, true)
        B.cb("safe_air", "protect", "Safe head: any air crouch", false, true)
        B.cb("safe_high", "protect", "Safe head: high ground", false, true)
        B.cb("anti_brute", "protect", "Anti-bruteforce", true, true)
        B.sl("brute_reset", "protect", "Anti-brute reset after", 1, 15, 6, true, "s")
        B.cb("brute_random", "protect", "Random anti-brute order", true, true)
        B.cb("phase_test", "protect", "Phase test (one phase per round, fair comparison)", true, true)
        B.cb("knife_md", "protect", "Lower Min. damage vs close knife/zeus", true, true)
        B.cb("crouch_cap", "protect", "Desync keeper: slow crouch-walk when seen", true, false)
        B.sl("crouch_speed", "protect", "Crouch speed", 20, 78, 38, false, "u/s")
        -- Builder
        UI.build_builder()
        -- Exploits
        B.cb("safe_recharge", "exploits", "Safe recharge", true, true)
        B.cb("crouch_recharge", "exploits", "Also while crouched (peek / crouch move)", false, true)
        B.sl("hidden_spin", "exploits", "Hidden spin speed", 1, 30, 10, true)
        B.cb("smart_force", "exploits", "Force defensive when seen / near (Smart)", true, true)
        B.cb("def_cooldown", "exploits", "Re-arm cooldown (let DT refill after defensive)", true, true)
        B.cb("def_edge", "exploits", "Defensive: one shift per event (no repeat while seen)", true, true)
        B.sl("def_repeat", "exploits", "Defensive: repeat while seen (ticks, 0 = once)", 0, 64, 16, false, "t")
        B.cb("anti_peek", "exploits", "Defensive vs enemy peeks", true, true)
        B.cb("switch_def", "exploits", "Defensive while switching weapons", true, true)
        B.cb("clean_shot", "exploits", "Clean shot (no lag while shooting)", true, true)
        B.cb("air_teleport", "exploits", "Teleport in air when seen", true, true)
        B.cb("air_lc", "exploits", "Air: break LC (uncharge + full fake lag when seen)", true, false)
        B.cb("air_lag", "exploits", "Air lag (defensive every tick)", true, true)
        B.sl("air_hc", "exploits", "In-air hit chance (snipers, 0 = off)", 0, 100, 0, true, "%")
        -- Peek
        B.cb("auto_peek", "peek", "Auto peek state (moving into view)", true, true)
        B.cb("ai_peek", "peek", "AI peek (hold autopeek key)", true, true)
        B.cb("peek_defensive", "peek", "Defensive during AI peek", true, true)
        B.cb("afk", "peek", "AFK mode (AI peek here + strafe, full exploits)", false, false)
        B.cb("afk_auto", "peek", "Auto AFK (no input 8 s after spawn)", true, false)
        -- Ragebot
        B.cb("resolver", "rage", "Adaptive resolver", true, true)
        B.cb("low_hp_safe", "rage", "Finish low HP (<=30) with safe point", true, true)
        B.cb("smart_baim", "rage", "Smart body aim", true, true)
        B.cb("head_only", "rage", "Head unless body kills (snipers)", true, true)
        B.cb("dt_pair", "rage", "DT pair counts as lethal (body x2 >= HP)", false, true)
        B.cb("fake_body", "rage", "Snipers: lethal body on fake records", true, true)
        B.cb("wait_real", "rage", "Wait for real record (enemy defensive)", true, true)
        B.cb("fresh_only", "rage", "Snipers: fresh record only", true, true)
        B.cb("ext_body", "rage", "Body vs extended (repeated head misses)", true, false)
        B.cb("hider_body", "rage", "Body vs head hiders (head share <= 35 pct over 12+ shots)", true, false)
        -- Visuals
        B.cb("indicators", "visuals", "Crosshair indicators", true, false)
        B.color("accent", "indicators", "Indicator color", color_t(150, 190, 255, 255))
        B.cb("arrows", "visuals", "Manual arrows", true, false)
        B.color("arrow_color", "arrows", "Arrow color", color_t(150, 190, 255, 255))
        B.cb("left_ind", "visuals", "Left indicators (DT / HS / FD / DEF / MD ...)", true, false)
        B.cb("stats_panel", "visuals", "Stats panel", false, false)
        B.cb("res_panel", "visuals", "Resolver panel", true, false)
        B.sl("panel_size", "visuals", "Panel size", 70, 200, 160, false, "%")
        B.sl("panel_x", "visuals", "Panel position X", 0, 1000, 560, false)
        B.sl("panel_y", "visuals", "Panel position Y", 0, 1000, 380, false)
        -- Misc
        B.cb("clantag", "misc", "Clan tag: Nykle.win (animated)", true, false)
        B.cb("trash_talk", "misc", "Trash talk", false, false)
        B.cb("tt_kill", "misc", "On kill", true, false)
        B.cb("tt_headshot", "misc", "Kills: headshots only", false, false)
        B.cb("tt_death", "misc", "On death", true, false)
        B.sl("tt_chance", "misc", "Chance", 1, 100, 100, false, "%")
        B.sel("tt_chat", "misc", "Chat", { "All chat", "Team chat" }, 1, false)
        B.sl("tt_delay", "misc", "Message delay", 0.5, 5, 2.3, false, "s", 0.1, 1)
        B.cb("jump_scout", "misc", "Jump scout (no air strafe on standing jump)", true, false)
        B.cb("auto_buy", "misc", "Auto buy grenades (HE + smoke + molotov)", true, false)
        B.cb("left_hand", "misc", "Left hand (cl_righthand 0, permanent)", true, false)
        B.sel("aspect", "misc", "Aspect ratio", { "4:3", "Off", "5:4", "16:10" }, 1, false)
        B.cb("fps_boost", "misc", "FPS boost (shadows / 3D sky / post-process off)", true, false)
        B.cb("fps_ragdolls", "misc", "Disable ragdolls (bodies vanish)", false, false)

        for _, g in ipairs(UI.GROUP_ORDER) do
            pcall(menu.set_group_column, UI.G[g[1]], g[2])
        end
        UI.build_vis()
    end

    -- Gorunurluk kurallari: { oge, kosul }.
    UI.build_vis = function()
        local list = {}
        local function rule(key, fn)
            if UI.e[key] ~= nil then
                list[#list + 1] = { el = UI.e[key], fn = fn }
            end
        end
        rule("backstab_def", function() return N.on("avoid_backstab") end)
        for _, k in ipairs({ "spin_warmup", "spin_enemies", "spin_pitch", "spin_speed" }) do
            rule(k, function() return N.on("spin") end)
        end
        for _, k in ipairs({ "safe_knife", "safe_air", "safe_high" }) do
            rule(k, function() return N.on("safe_head") end)
        end
        rule("brute_reset", function() return N.on("anti_brute") end)
        rule("brute_random", function() return N.on("anti_brute") end)
        rule("phase_test", function() return N.on("anti_brute") end)
        rule("crouch_speed", function() return N.on("crouch_cap") end)
        rule("crouch_recharge", function() return N.on("safe_recharge") end)
        rule("def_cooldown", function() return N.on("smart_force") end)
        rule("peek_defensive", function() return N.on("ai_peek") end)
        rule("low_hp_safe", function() return N.on("resolver") end)
        rule("dt_pair", function() return N.on("head_only") end)
        for _, k in ipairs({ "panel_size", "panel_x", "panel_y" }) do
            rule(k, function() return N.on("res_panel") end)
        end
        for _, k in ipairs({ "tt_kill", "tt_death", "tt_chance", "tt_chat", "tt_delay" }) do
            rule(k, function() return N.on("trash_talk") end)
        end
        rule("tt_headshot", function() return N.on("trash_talk") and N.on("tt_kill") end)
        rule("fps_ragdolls", function() return N.on("fps_boost") end)
        -- Builder: secili durumun ogeleri; Override kapaliysa sadece Override kutusu.
        for _, s in ipairs(K.STATES) do
            local row = UI.b[s]
            for key, el in pairs(row) do
                local fn
                local function base()
                    if UI.cur_state ~= s then
                        return false
                    end
                    if key ~= "override" and row.override ~= nil and UI.val(row.override, true) ~= true then
                        return false
                    end
                    return true
                end
                if key == "yaw_left" or key == "yaw_right" then
                    fn = function() return base() and N.bv(s, "yaw_mode") == 1 end
                elseif key == "ways" then
                    fn = function() return base() and N.bv(s, "yaw_mode") == 2 end
                elseif key:sub(1, 3) == "way" then
                    local n = tonumber(key:sub(4)) or 1
                    fn = function()
                        return base() and N.bv(s, "yaw_mode") == 2 and n <= (N.bv(s, "ways") or 3)
                    end
                elseif key == "mod_random" or key == "mod_offset" then
                    fn = function() return base() and N.bv(s, "modifier") ~= 1 end
                elseif key == "body_fs" then
                    fn = function() return base() and N.bv(s, "body_yaw") == 2 end
                elseif key == "delay_random" or key == "delay" then
                    fn = function() return base() and N.bv(s, "body_yaw") == 1 end
                else
                    fn = base
                end
                list[#list + 1] = { el = el, fn = fn }
            end
            local xrow = UI.x[s]
            for key, el in pairs(xrow) do
                local fn
                if key == "def_ticks" then
                    fn = function() return UI.cur_state == s and N.xv(s, "def_mode") == 5 end
                elseif key == "hidden_pitch_value" then
                    fn = function() return UI.cur_state == s and N.xv(s, "hidden_pitch") == 7 end
                elseif key == "hidden_yaw_value" then
                    fn = function() return UI.cur_state == s and N.xv(s, "hidden_yaw") == 6 end
                else
                    fn = function() return UI.cur_state == s end
                end
                list[#list + 1] = { el = el, fn = fn }
            end
        end
        UI.vis = list
    end

    UI.signature = function()
        local s = UI.cur_state or ""
        local parts = { tostring(N.v("tab")), s }
        for _, k in ipairs({ "avoid_backstab", "spin", "safe_head", "anti_brute", "crouch_cap", "safe_recharge",
            "smart_force", "ai_peek", "resolver", "head_only", "res_panel", "trash_talk", "tt_kill", "fps_boost" }) do
            parts[#parts + 1] = tostring(N.v(k))
        end
        if UI.b[s] ~= nil then
            for _, k in ipairs({ "override", "yaw_mode", "ways", "modifier", "body_yaw" }) do
                parts[#parts + 1] = tostring(N.bv(s, k))
            end
        end
        if UI.xdef[s] ~= nil and UI.xdef[s].def_mode ~= nil then
            for _, k in ipairs({ "def_mode", "hidden_pitch", "hidden_yaw" }) do
                parts[#parts + 1] = tostring(N.xv(s, k))
            end
        end
        return concat(parts, "|")
    end

    UI.sig, UI.open_at, UI.was_open = nil, nil, false
    UI.visibility = function()
        local ok_open, open = pcall(menu.is_open)
        open = ok_open and open == true
        local now = U.now()
        if not open then
            UI.was_open = false
            return
        end
        if not UI.was_open then
            UI.was_open, UI.open_at = true, now
        end
        UI.cur_state = K.STATES[N.v("state")] or "Global"
        local sig = UI.signature()
        local late = UI.open_at ~= nil and now - UI.open_at >= 0.5
        if sig == UI.sig and not late then
            return
        end
        if late then
            UI.open_at = nil
        end
        UI.sig = sig
        local tab = N.v("tab") or 1
        for _, g in ipairs(UI.GROUP_ORDER) do
            local show = g[3] == 0 or g[3] == tab
            pcall(menu.set_group_visibility, UI.G[g[1]], show)
        end
        for _, item in ipairs(UI.vis) do
            local ok, show = pcall(item.fn)
            pcall(item.el.set_visible, item.el, ok and show == true)
        end
    end

    UI.text_of = function(t, v)
        if t.items ~= nil and U.finite(v) and t.items[floor(v)] ~= nil then
            return t.items[floor(v)]
        end
        return U.numtext(v)
    end

    UI.differs = function(v, def)
        if type(def) == "number" then
            return not U.finite(v) or abs(v - def) > 1e-4
        end
        return v ~= def
    end

    -- Saniyede bir (menu kapaliyken): izlenen ogeler varsayilanina doner.
    UI.rec_at, UI.rec_reported = -1000, false
    UI.recommend = function()
        local now = U.now()
        if now >= UI.rec_at and now - UI.rec_at < 1 then
            return
        end
        UI.rec_at = now
        local ok_open, open = pcall(menu.is_open)
        if ok_open and open == true then
            return
        end
        local on = N.on("recommended")
        if not on and UI.rec_reported then
            return
        end
        local n, example = 0, nil
        for _, t in ipairs(UI.tracked) do
            local okg, v = pcall(t.el.get, t.el)
            if okg and UI.differs(v, t.def) then
                n = n + 1
                if example == nil then
                    example = fmt("%s %s -> %s", t.label, UI.text_of(t, v), UI.text_of(t, t.def))
                end
                if on then
                    UI.set(t.el, t.def)
                end
            end
        end
        if on then
            UI.rec_reported = false
            if n > 0 then
                N.log.line(fmt("%d ayar onerilen degerine donduruldu (orn. %s)", n, example))
            end
        else
            UI.rec_reported = true
            if n > 0 then
                N.log.line(fmt("Always use recommended settings kapali: %d ayar onerilenden farkli (orn. %s)", n,
                    example))
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Override nesnesi: native menuye TEK yazma yolu (anlik kopya, geri okuma, birakinca geri yazma)
-------------------------------------------------------------------------------
do
    local U, O = N.util, N.ov
    O.items, O.warned, O.multi_off = {}, {}, false
    O.neutral_at = -1000
    -- A23: native AA tasiyicilari notrde (Lua degerleri 1 tabanli; cfg'de index - 1).
    O.NEUTRAL = {
        { "jitter_mode", 1 }, { "rotate", false }, { "yaw_add", 0 }, { "body_lean", 1 },
        { "moving_body_lean", false }, { "ext_moving", false }, { "override_move", false },
        { "override_slow", false }, { "anti_brute_native", false }, { "on_shot", 1 }, { "side_stand", 2 },
        { "left_amount_stand", 100 }, { "right_amount_stand", 100 },
    }

    local function same(a, b)
        if type(a) == "number" and type(b) == "number" then
            return abs(a - b) < 1e-4
        end
        return a == b
    end
    O.same = same

    O.set = function(key, ref, value)
        if ref == nil then
            return false
        end
        local now = U.now()
        local it = O.items[key]
        if it ~= nil and it.failed_until ~= nil and now < it.failed_until and now >= it.failed_until - 10 then
            return false
        end
        local okc, cur = pcall(ref.get, ref)
        if not okc then
            return false
        end
        if it == nil then
            it = { ref = ref, snap = cur }
            O.items[key] = it
        elseif it.written ~= nil and not same(cur, it.written) then
            -- Tutarken kullanici degistirdi: birakinca onun degeri geri gelsin.
            it.snap = cur
        end
        if same(cur, value) then
            it.written, it.failed_until = value, nil
            return true
        end
        pcall(ref.set, ref, value)
        local okb, back = pcall(ref.get, ref)
        if not okb or not same(back, value) then
            it.failed_until = now + 5
            if not O.warned[key] then
                O.warned[key] = true
                N.log.line(fmt("%s = %s ayarlanamadi", key, tostring(value)))
            end
            return false
        end
        it.written, it.failed_until = value, nil
        return true
    end

    -- Native multi'de tek oge (ada gore; geri okuma yanlissa :get_items() sirasiyla index).
    O.set_multi = function(key, ref, item, value)
        if ref == nil or O.multi_off then
            return false
        end
        local full = key .. ":" .. item
        local now = U.now()
        local it = O.items[full]
        if it ~= nil and it.failed_until ~= nil and now < it.failed_until and now >= it.failed_until - 10 then
            return false
        end
        if it == nil then
            local okn, v = pcall(ref.get, ref, item)
            local sel = item
            if not okn or type(v) ~= "boolean" then
                sel = nil
                local oki, items = pcall(ref.get_items, ref)
                if oki and type(items) == "table" then
                    for i, name in ipairs(items) do
                        if tostring(name):lower() == item:lower() then
                            sel = i
                        end
                    end
                end
                if sel ~= nil then
                    okn, v = pcall(ref.get, ref, sel)
                end
            end
            if sel == nil or not okn or type(v) ~= "boolean" then
                O.multi_off = true
                N.log.line(fmt("%s = %s ayarlanamadi (oge okunamadi; durum basina FS kapatma kapali)", full,
                    tostring(value)))
                return false
            end
            it = { ref = ref, snap = v, sel = sel, multi = true }
            O.items[full] = it
        end
        local okc, cur = pcall(ref.get, ref, it.sel)
        if okc and cur == value then
            it.written = value
            return true
        end
        pcall(ref.set, ref, it.sel, value)
        local okb, back = pcall(ref.get, ref, it.sel)
        if okb and back == value then
            it.written = value
            return true
        end
        -- Ada gore yazilamadi: :get_items() sirasiyla bir kez daha.
        if type(it.sel) == "string" then
            local oki, items = pcall(ref.get_items, ref)
            if oki and type(items) == "table" then
                for i, name in ipairs(items) do
                    if tostring(name):lower() == item:lower() then
                        it.sel = i
                    end
                end
            end
            if type(it.sel) == "number" then
                pcall(ref.set, ref, it.sel, value)
                okb, back = pcall(ref.get, ref, it.sel)
                if okb and back == value then
                    it.written = value
                    return true
                end
            end
        end
        it.failed_until = now + 5
        if not O.warned[full] then
            O.warned[full] = true
            N.log.line(fmt("%s = %s ayarlanamadi", full, tostring(value)))
        end
        return false
    end

    O.release = function(key)
        local it = O.items[key]
        if it == nil then
            return
        end
        O.items[key] = nil
        if it.written == nil then
            return
        end
        if it.multi then
            local okc, cur = pcall(it.ref.get, it.ref, it.sel)
            if okc and cur == it.written and cur ~= it.snap then
                pcall(it.ref.set, it.ref, it.sel, it.snap)
            end
            return
        end
        local okc, cur = pcall(it.ref.get, it.ref)
        if okc and same(cur, it.written) and not same(cur, it.snap) then
            pcall(it.ref.set, it.ref, it.snap)
        end
    end

    O.release_prefix = function(prefix)
        local keys = {}
        for key in pairs(O.items) do
            if key:sub(1, #prefix) == prefix then
                keys[#keys + 1] = key
            end
        end
        for _, key in ipairs(keys) do
            O.release(key)
        end
    end

    O.release_all = function()
        local keys = {}
        for key in pairs(O.items) do
            keys[#keys + 1] = key
        end
        for _, key in ipairs(keys) do
            O.release(key)
        end
    end

    O.held = function(key)
        return O.items[key] ~= nil
    end

    -- A23: Enable acikken native tasiyicilar notrde (64 tick'te bir kontrol).
    O.hold_neutral = function(force)
        local t = U.tick()
        if not force and t >= O.neutral_at and t - O.neutral_at < 64 then
            return
        end
        O.neutral_at = t
        for _, item in ipairs(O.NEUTRAL) do
            local ref = N.ref.items[item[1]]
            if ref ~= nil then
                O.set(item[1], ref, item[2])
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Sarj sahibi: block_recharge / allow_recharge tek yerden (sebep listesi + 3 sn bekci)
-------------------------------------------------------------------------------
do
    local U, RC = N.util, N.rc
    RC.reasons, RC.banned = {}, {}

    RC.block = function(reason)
        if RC.banned[reason] then
            return false
        end
        RC.reasons[reason] = RC.reasons[reason] or U.now()
        U.call(exploits.block_recharge)
        return true
    end

    RC.allow = function(reason)
        RC.banned[reason] = nil
        if RC.reasons[reason] == nil then
            return
        end
        RC.reasons[reason] = nil
        if next(RC.reasons) == nil then
            U.call(exploits.allow_recharge)
        end
    end

    -- Her SETUP_COMMAND: tutulurken block her tick yeniden (yapiskan oldugu kesin degil).
    RC.tick = function()
        if next(RC.reasons) ~= nil then
            U.call(exploits.block_recharge)
        end
    end

    RC.release_all = function()
        local had = next(RC.reasons) ~= nil
        RC.reasons, RC.banned = {}, {}
        U.call(exploits.allow_recharge)
        return had
    end

    RC.watchdog = function()
        local now = U.now()
        for reason, since in pairs(RC.reasons) do
            if now < since or now - since > 3 then
                RC.reasons[reason] = nil
                RC.banned[reason] = true
                if next(RC.reasons) == nil then
                    U.call(exploits.allow_recharge)
                end
                N.log.line(fmt("sarj kilidi 3 sn'yi gecti, birakildi (%s)", reason))
                return
            end
        end
    end

    RC.held = function(reason)
        if reason ~= nil then
            return RC.reasons[reason] ~= nil
        end
        return next(RC.reasons) ~= nil
    end
end

-------------------------------------------------------------------------------
-- Kalici hafiza (nykle_memory.txt, Steam ID ile): resolver sonuclari, anti-brute tabani, faz istatistikleri,
-- kafa saklayan sayaclari, AA profili (R), kariyer (K), cvar orijinalleri (C).
-- Dosya surum 2: "NYKLEMEM\t2\t<oturum>" basligi, kayitlar, son satir "END\t<kayit sayisi>". END'i olmayan ya da
-- sayisi tutmayan dosya bozuk sayilir ve nykle_memory.bak denenir (GS V1.0.37 / NL V1.1.8: hafiza iki kez sessizce
-- kayboldu). Yazarken once onceki gecerli metin .bak'a, sonra yeni metin ana dosyaya. Surum 1 dosyasi okunur
-- (END'siz); bilinmeyen kayit turleri atlanir (ileriye uyumlu).
-------------------------------------------------------------------------------
do
    local U, M = N.util, N.mem
    M.file, M.bak, M.players, M.count, M.session, M.dirty, M.loaded = "nykle_memory.txt", "nykle_memory.bak", {}, 0, 1,
        false, false
    M.seq, M.kc = 0, {}
    -- cvars: cvar orijinalleri (C kaydi: ilk yazimdan onceki deger; temiz birakista silinir). good: son gecerli dosya
    -- metni (bir sonraki yazimda .bak'a gider); bak_text: .bak'ta oldugu bilinen metin; from_bak: yedekten yuklendi.
    -- locked: ana dosya bu scriptten yeni bir surumle yazilmis (eski surume donulmus); hic yazilmaz (SPEC §5).
    M.cvars, M.good, M.bak_text, M.from_bak, M.cv_new, M.locked = {}, nil, nil, false, false, false

    M.key_of = function(ent, name)
        if ent == nil then
            return nil
        end
        local ok, _, sid64 = pcall(ent.get_steamids, ent)
        local key = ok and sid64 ~= nil and tostring(sid64):gsub("U?LL$", "") or nil
        if key == nil or key == "" or key == "0" or key == "nil" then
            key = "n:" .. (name or U.name(ent))
        end
        return key
    end

    -- Anahtar ve ad entity index'ine gore 1 sn onbellekte (tick basina birkac kez steamid / ad okunmasin).
    M.cached = function(ent)
        local idx = U.index(ent)
        local now = U.now()
        local c = idx ~= nil and M.kc[idx] or nil
        if c ~= nil and now >= c.at and now - c.at < 1 then
            return c.key, c.name
        end
        local name = U.name(ent)
        local key = M.key_of(ent, name)
        if idx ~= nil then
            M.kc[idx] = { key = key, name = name, at = now }
        end
        return key, name
    end

    M.entry = function(ent, key)
        local ck, name = nil, nil
        if ent ~= nil then
            ck, name = M.cached(ent)
        end
        key = key or ck
        if key == nil then
            return nil, nil
        end
        M.seq = M.seq + 1
        local p = M.players[key]
        if p == nil then
            p = { name = name or "?", last = M.session, base = nil, res = {},
                hider = { n = 0, h = 0, b = 0 }, gmiss = 0 }
            M.players[key] = p
            M.count = M.count + 1
            M.dirty = true
            if M.count > N.K.MEMORY_LIMIT then
                p.seen = M.seq
                M.trim(key)
            end
        end
        p.seen = M.seq
        if p.last ~= M.session then
            p.last = M.session
            M.dirty = true
        end
        if name ~= nil and p.name ~= name then
            p.name = name
        end
        return p, key
    end

    -- En uzun suredir gorulmeyenler atilir (64 oyuncu siniri): once oturum, esitse son erisim; yeni eklenen
    -- (keep) hic atilmaz. Dosyadaki oturum bu oturumdan buyukse (bozuk / baska kurulum) bu oturum sayilir: yoksa
    -- "gelecekteki" kayitlar bu oturumda gorulenleri surekli atardi.
    M.trim = function(keep)
        local list = {}
        for key, p in pairs(M.players) do
            if key ~= keep then
                list[#list + 1] = { key = key, last = min(p.last or 0, M.session), seen = p.seen or 0 }
            end
        end
        table.sort(list, function(a, b)
            if a.last ~= b.last then
                return a.last > b.last
            end
            return a.seen > b.seen
        end)
        local room = N.K.MEMORY_LIMIT - (keep ~= nil and M.players[keep] ~= nil and 1 or 0)
        for i = room + 1, #list do
            M.players[list[i].key] = nil
        end
        M.count = min(#list, room) + (N.K.MEMORY_LIMIT - room)
    end

    local function split(line)
        local out = {}
        for field in (line .. "\t"):gmatch("([^\t]*)\t") do
            out[#out + 1] = field
        end
        return out
    end

    -- Metni dogrular ve ayristirir: tablo ya da nil, sebep. Hicbir sey uygulanmaz (bozuk ana dosya hafizayi yarim
    -- doldurmasin, yedek denenebilsin).
    M.parse = function(text)
        if type(text) ~= "string" or text == "" then
            return nil, "bos"
        end
        local lines = {}
        for line in text:gmatch("[^\n]+") do
            lines[#lines + 1] = (line:gsub("\r$", ""))
        end
        local head = split(lines[1] or "")
        if head[1] ~= "NYKLEMEM" then
            return nil, "baslik yok"
        end
        if head[2] ~= "1" and head[2] ~= "2" then
            return nil, "surum " .. tostring(head[2]), tonumber(head[2])
        end
        local last = #lines
        if head[2] == "2" then
            local tail = split(lines[#lines])
            if tail[1] ~= "END" then
                return nil, "END yok"
            end
            -- V1.0.7: sayi tutmasa da gecerli kayitlar yuklenir (her satir kendi alan sayisiyla dogrulanir); eskiden
            -- butun hafiza atiliyordu. Not: M.partial.
            if tonumber(tail[2]) ~= #lines - 2 then
                M.partial = fmt("kayit sayisi %s != %d", tostring(tail[2]), #lines - 2)
            end
            last = #lines - 1
        end
        local d = { session = tonumber(head[3]) or 0, players = {}, count = 0, phases = {}, cvars = {}, test = {} }
        local extra = {}
        local PR = N.profile
        for i = 2, last do
            local f = split(lines[i])
            local kind = f[1]
            if kind == "P" and #f >= 8 and f[2] ~= "" then
                local res = {}
                for state, results in f[6]:gmatch("([^=;]+)=([cho]*)") do
                    -- Eski surumlerin 'o' (diger iska) harfleri pencereyi sulandirmasin.
                    res[state] = results:gsub("o", ""):sub(-4)
                end
                local n, h, b = f[7]:match("^([%d%.]+),([%d%.]+),(%d+)$")
                if d.players[f[2]] == nil then
                    d.count = d.count + 1
                end
                d.players[f[2]] = { name = f[3], last = tonumber(f[4]) or 0, base = tonumber(f[5]), res = res,
                    hider = { n = tonumber(n) or 0, h = tonumber(h) or 0, b = tonumber(b) or 0 },
                    gmiss = tonumber(f[8]) or 0 }
            elseif kind == "F2" and #f >= 5 then
                d.phases[#d.phases + 1] = { g = f[2], phase = tonumber(f[3]), shots = tonumber(f[4]) or 0,
                    hits = tonumber(f[5]) or 0 }
            elseif kind == "T" and #f >= 6 then
                d.test[#d.test + 1] = { phase = tonumber(f[2]), n = tonumber(f[3]) or 0, h = tonumber(f[4]) or 0,
                    hit = tonumber(f[5]) or 0, rounds = tonumber(f[6]) or 0 }
            elseif kind == "V" and f[2] == "phases" then
                d.phase_set = tonumber(f[3])
            elseif kind == "R" and #f >= 3 + #PR.PATTERNS + 2 then
                local r = PR.new_prof()
                r.n = tonumber(f[3]) or 0
                for j, name in ipairs(PR.PATTERNS) do
                    r[name] = tonumber(f[3 + j]) or 0
                end
                r.def = tonumber(f[4 + #PR.PATTERNS]) or 0
                r.fd = tonumber(f[5 + #PR.PATTERNS]) or 0
                extra[#extra + 1] = { key = f[2], field = "prof", v = r }
            elseif kind == "K" and #f >= 2 + #PR.CAREER then
                local c = {}
                for j, name in ipairs(PR.CAREER) do
                    c[name] = tonumber(f[2 + j]) or 0
                end
                extra[#extra + 1] = { key = f[2], field = "car", v = c }
            elseif kind == "C" and #f >= 4 and f[2] ~= "" and U.finite(tonumber(f[3])) then
                d.cvars[f[2]] = { v = tonumber(f[3]), float = f[4] == "1" }
            end
        end
        -- Eski faz setinden kalan dusman taban fazlari yeni sette anlamsiz: silinir.
        if d.phase_set ~= N.K.PHASE_SET then
            for _, p in pairs(d.players) do
                p.base = nil
            end
            d.phases, d.test = {}, {}
        end
        -- R / K kaydi oyuncusu (P) olmadan atlanir (64 sinirinda atilmis oyuncu).
        for _, x in ipairs(extra) do
            local p = d.players[x.key]
            if p ~= nil and (x.field ~= "prof" or x.v.n > 0) then
                p[x.field] = x.v
            end
        end
        return d
    end

    M.apply = function(d)
        M.players, M.count = d.players, d.count
        M.session = d.session + 1
        -- mem: dosyadan taninan oyuncu ("tanindi (hafiza)" ve hafiza dogrulamasi icin).
        for _, p in pairs(M.players) do
            p.mem = true
        end
        for _, f in ipairs(d.phases) do
            local list = N.brute.phases[f.g]
            if list ~= nil and f.phase ~= nil and list[f.phase] ~= nil then
                list[f.phase].shots = f.shots
                list[f.phase].hits = f.hits
            end
        end
        for _, t in ipairs(d.test) do
            local x = t.phase ~= nil and N.brute.test[t.phase] or nil
            if x ~= nil then
                x.n, x.h, x.hit, x.rounds = t.n, t.h, t.hit, t.rounds
            end
        end
        M.cvars = d.cvars
        if M.count > N.K.MEMORY_LIMIT then
            M.trim()
        end
        for _, g in ipairs(N.K.BRUTE_GROUPS) do
            N.brute.default[g] = N.brute.best_default(g)
        end
    end

    M.load = function()
        M.loaded = true
        if not N.fs.ok then
            return
        end
        local text = N.fs.read(M.file)
        local d, why, ver = M.parse(text)
        if ver ~= nil and ver > 2 then
            M.locked = true
            N.log.notes[#N.log.notes + 1] = fmt("hafiza dosyasi daha yeni bir surumden (%s): dokunulmuyor, bu oturumun"
                .. " hafizasi kaydedilmez", why)
        end
        if d ~= nil then
            M.good = text
            if M.partial ~= nil then
                N.log.notes[#N.log.notes + 1] = fmt("hafiza dosyasinda %s: gecerli kayitlar yuklendi", M.partial)
                M.partial = nil
            end
        else
            local btext = N.fs.read(M.bak)
            M.bak_text = btext
            local b = M.parse(btext)
            local notes = N.log.notes
            if b ~= nil then
                d, M.good, M.from_bak = b, btext, true
                notes[#notes + 1] = text == nil and fmt("hafiza dosyasi yok -> yedek kullanildi (%s)", M.bak)
                    or fmt("hafiza dosyasi bozuk (%s) -> yedek kullanildi (%s)", why, M.bak)
            elseif text ~= nil then
                notes[#notes + 1] = fmt("hafiza dosyasi bozuk (%s) -> bos hafiza (yedek %s)", why,
                    btext == nil and "yok" or "de bozuk")
            end
        end
        if d ~= nil then
            M.apply(d)
        end
    end

    local function num(v)
        if not U.finite(v) then
            return "0"
        end
        if abs(v - floor(v)) < 1e-9 then
            return fmt("%d", floor(v))
        end
        return fmt("%.2f", v)
    end

    -- cvar degeri: 4 ondalik yetmez (r_aspectratio 1.7778), sondaki sifirlar atilir.
    local function cnum(v)
        if abs(v - floor(v)) < 1e-9 then
            return fmt("%d", floor(v))
        end
        return (fmt("%.6f", v):gsub("0+$", ""):gsub("%.$", ""))
    end

    M.text = function()
        local PR = N.profile
        local out = { "NYKLEMEM\t2\t" .. fmt("%d", floor(M.session)) }
        local keys = {}
        for key in pairs(M.players) do
            keys[#keys + 1] = key
        end
        table.sort(keys)
        for _, key in ipairs(keys) do
            local p = M.players[key]
            local res = {}
            for state, results in pairs(p.res) do
                if results ~= "" then
                    res[#res + 1] = state .. "=" .. results
                end
            end
            table.sort(res)
            local hd = p.hider or { n = 0, h = 0, b = 0 }
            out[#out + 1] = concat({ "P", key, (tostring(p.name or "?"):gsub("[\t\r\n]", " ")),
                num(p.last or 0), p.base ~= nil and num(p.base) or "", concat(res, ";"),
                num(hd.n) .. "," .. num(hd.h) .. "," .. num(floor(hd.b)), num(p.gmiss or 0) }, "\t")
            local r = p.prof
            if r ~= nil and r.n > 0 then
                local f = { "R", key, num(r.n) }
                for _, name in ipairs(PR.PATTERNS) do
                    f[#f + 1] = num(r[name] or 0)
                end
                f[#f + 1] = num(r.def or 0)
                f[#f + 1] = num(r.fd or 0)
                out[#out + 1] = concat(f, "\t")
            end
            local c = p.car
            if c ~= nil then
                local f = { "K", key }
                for _, name in ipairs(PR.CAREER) do
                    f[#f + 1] = num(c[name] or 0)
                end
                out[#out + 1] = concat(f, "\t")
            end
        end
        for _, g in ipairs(N.K.BRUTE_GROUPS) do
            local list = N.brute.phases[g]
            for phase = 0, #N.K.BRUTE_PHASES do
                local s = list[phase]
                if s ~= nil and s.shots > 0 then
                    out[#out + 1] = concat({ "F2", g, fmt("%d", phase), num(s.shots), num(s.hits) }, "\t")
                end
            end
        end
        out[#out + 1] = "V\tphases\t" .. fmt("%d", N.K.PHASE_SET)
        for phase = 0, #N.K.BRUTE_PHASES do
            local t = N.brute.test[phase]
            if t.n > 0 or t.rounds > 0 then
                out[#out + 1] = concat({ "T", fmt("%d", phase), num(t.n), num(t.h), num(t.hit), num(t.rounds) }, "\t")
            end
        end
        local names = {}
        for name in pairs(M.cvars) do
            names[#names + 1] = name
        end
        table.sort(names)
        for _, name in ipairs(names) do
            local c = M.cvars[name]
            out[#out + 1] = concat({ "C", name, cnum(c.v), c.float and "1" or "0" }, "\t")
        end
        out[#out + 1] = "END\t" .. fmt("%d", #out - 1)
        return concat(out, "\n") .. "\n"
    end

    -- fresh: .bak'a da yeni metin (unut dugmesi: unutulan veri yedekten geri gelmesin).
    M.save = function(force, fresh)
        if not M.dirty and not force then
            return false
        end
        if not N.fs.ok or M.locked then
            return false
        end
        local text = M.text()
        local prev = fresh and text or M.good
        if prev ~= nil and prev ~= M.bak_text and N.fs.put(M.bak, prev, "w") then
            M.bak_text = prev
        end
        if N.fs.put(M.file, text, "w") then
            M.dirty, M.good = false, text
            return true
        end
        return false
    end

    -- cvar orijinali (C kaydi): ilk yazimdan once kaydedilir, temiz birakista silinir; oyun cokerse bir sonraki
    -- oturum senin degerini buradan alir (GS V1.0.40).
    M.cvar_keep = function(name, value, float)
        M.cvars[name] = { v = value, float = float == true }
        M.dirty, M.cv_new = true, true
    end

    M.cvar_drop = function(name)
        if M.cvars[name] ~= nil then
            M.cvars[name] = nil
            M.dirty = true
        end
    end

    -- Ogrenilen her sey (P / R / K / F) silinir; C kalir (ogrenilmis veri degil, senin cvar degerlerin).
    M.forget = function()
        M.players, M.count = {}, 0
        N.brute.reset_phases()
        N.brute.enemies = {}
        N.rage.t = {}
        N.profile.reset()
        M.dirty = true
        M.save(true, true)
        N.log.line("ogrenilen dusmanlar unutuldu (resolver seviyeleri, anti-brute fazlari, kafa payi, AA profilleri,"
            .. " kariyer; cvar yedekleri duruyor)")
    end
end

-------------------------------------------------------------------------------
-- Dusman takibi: simulasyon zamani (sahte kayit / defensive), LC kirma, kayit gecikmesi, goz yaw deseni,
-- silah. NET_UPDATE'ten (calismadiysa SETUP_COMMAND'dan).
-------------------------------------------------------------------------------
do
    local U, T = N.util, N.track
    T.p, T.updated_tick, T.net_tick = {}, -1, -1000
    -- WAKE_GAP: bu kadar tick guncellenmeyen (ya da sim zamani bu kadar atlayan) dusman "uyandi" sayilir (16 tick'lik
    -- en uzun bogmadan fazla); WAKE_SHOW: vuruldun / olum satirinda "uyandi X.XXs once" bu kadar tick gorunur.
    T.WAKE_GAP, T.WAKE_SHOW = 32, 128

    T.get = function(idx)
        local t = T.p[idx]
        if t == nil then
            t = { idx = idx, last_sim = nil, def_until = -1, lc_until = -1, record_age = 0, yaws = {},
                pattern = "?", amp = nil, we_shot = -1000, shot_us = -1000, dmg_dealt = 0, last_origin = nil,
                fd_until = -1, fd_n = 0, fd_need = 2 }
            T.p[idx] = t
        end
        return t
    end

    -- net: NET_UPDATE'ten geldi (T.fallback sadece NET_UPDATE 1 tick'ten uzun susunca calisir). Bir dusman tick basina
    -- en fazla bir kez orneklenir (t.upd_tick): ayni tick'te SETUP_COMMAND + NET_UPDATE iki ayri kayit uretmez.
    T.update = function(net)
        local tick = U.tick()
        T.updated_tick = tick
        if net then
            T.net_tick = tick
        end
        local lp = N.st.lp
        if lp == nil then
            return
        end
        local ok, players = pcall(entity_list.get_players, true)
        if not ok or type(players) ~= "table" then
            return
        end
        for _, ent in ipairs(players) do
            local idx = U.index(ent)
            if idx ~= nil and U.alive(ent) and not U.dormant(ent) then
                local t = T.get(idx)
                t.ent = ent
                if t.upd_tick ~= tick then
                    T.sample(t, ent, tick)
                    t.upd_tick = tick
                end
            elseif idx ~= nil then
                -- Uykuda (dormant) ya da olu: sonraki ilk guncelleme "uyanma" (T.wake), LC / defensive karsilastirmasi yok.
                local t = T.p[idx]
                if t ~= nil and not t.slept then
                    t.slept, t.sleep_from = true, tick
                end
            end
        end
    end

    -- Uyanma (N1): dormant / olu kaldiktan ya da WAKE_GAP tick'ten uzun guncellenmedikten sonraki ilk kayit. Takip
    -- yeniden tabanlanir (son konum, sim zamani, yaw gecmisi); LC / defensive bayragi KURULMAZ (uyanan dusmanin
    -- konumu 64 birimden fazla "atlamis" gorunur ama bu isinlanma degil; 14 tick'lik gercek kayit beklemesi baslamaz).
    T.wake = function(t, ent, tick, sim)
        local org = U.origin(ent)
        local from = t.sleep_from or t.upd_tick
        t.slept_ticks = (from ~= nil and tick >= from) and tick - from or nil
        t.last_sim = sim
        t.last_origin = org ~= nil and { x = org.x, y = org.y, z = org.z } or nil
        t.yaws = {}
        t.def_until, t.def_start, t.lc_until = -1, nil, -1
        t.wake_tick, t.slept, t.sleep_from, t.wake_new = tick, false, nil, true
        N.diag.wake()
    end

    T.sample = function(t, ent, tick)
        local simt = U.num(ent, "m_flSimulationTime")
        if simt == nil then
            return
        end
        local okt, sim = pcall(client.time_to_ticks, simt)
        if not okt or not U.finite(sim) then
            sim = floor(simt / U.ipt() + 0.5)
        end
        t.record_age = max(0, tick - sim)
        -- V1.0.7 (log 3: "dbg uyandi ... ? sn uyudu" butun dusmanlarda ayni anda, 10 sn'de bir): tick sayaci kendi
        -- tickbase kaymamizla (defensive / teleport) birkac tick GERI gidiyor; bu uyanma degil. Sadece 64 tick'ten
        -- buyuk geri gidis (yeni harita) ya da WAKE_GAP'ten uzun sessizlik bayat sayilir.
        local stale = t.upd_tick ~= nil and (tick - t.upd_tick > T.WAKE_GAP or tick < t.upd_tick - 64)
        if t.slept or stale or (t.last_sim ~= nil and sim - t.last_sim > T.WAKE_GAP) then
            T.wake(t, ent, tick, sim)
            return
        end
        if t.last_sim ~= nil then
            if sim < t.last_sim then
                -- Simulasyon zamani geri gitti: sahte kayit (defensive).
                t.def_back = min(16, t.last_sim - sim)
                t.def_until = tick + t.def_back
                t.def_start = t.def_start or tick
                if tick - t.def_start > 64 then
                    -- 1 sn'den uzun "geride" kalan kayit defensive degil (dogus vb.): sifirla.
                    t.def_until, t.def_start, t.last_sim = -1, nil, sim
                end
            elseif sim > t.last_sim then
                T.fakeduck(t, ent, tick, sim - t.last_sim)
                local org = U.origin(ent)
                if org ~= nil and t.last_origin ~= nil then
                    local dx, dy, dz = org.x - t.last_origin.x, org.y - t.last_origin.y,
                        org.z - t.last_origin.z
                    if dx * dx + dy * dy + dz * dz > 4096 then
                        t.lc_until = tick + 16
                    end
                end
                if org ~= nil then
                    t.last_origin = { x = org.x, y = org.y, z = org.z }
                end
                if tick > t.def_until then
                    t.def_start = nil
                    local yaw = U.prop(ent, "m_angEyeAngles[1]")
                    if U.finite(yaw) then
                        local ys = t.yaws
                        ys[#ys + 1] = yaw
                        if #ys > 8 then
                            tremove(ys, 1)
                        end
                        T.classify(t)
                    end
                end
            end
        end
        if t.last_sim == nil or sim >= t.last_sim or tick > t.def_until then
            t.last_sim = sim
        end
    end

    -- Dusman fake duck'i (GS enemy_watch): yerde, egilme 0.05-0.95 arasi ve iki gercek guncelleme arasinda 7+ tick
    -- (6+ tick bogma) ust uste fd_need guncelleme (hafizada fake duck'ci bilinen dusmanda 1) -> 32 tick FD.
    T.fakeduck = function(t, ent, tick, step)
        local duck = U.num(ent, "m_flDuckAmount")
        if U.flag(ent, "ON_GROUND") ~= false and duck ~= nil and duck > 0.05 and duck < 0.95 and step >= 7 then
            t.fd_n = t.fd_n + 1
            if t.fd_n >= t.fd_need then
                t.fd_until = tick + 32
            end
        else
            t.fd_n = 0
        end
    end

    -- Son 8 gercek kayittaki goz yaw'lari (defensive kaydinin yaw'i hic girmez, NL V1.0): yayilim < 35 derece =
    -- statik; ardisik farklar hep ayni yone ve toplam >= 90 = spin; cember uzerinde 20+ derecelik bosluklarla
    -- ayrilan kumeler: iki sik kume (genislik <= 25, ikiser ornek) = jitter <kume arasi aci>, 3-5 sik kume
    -- (genislik <= 15, en az ikisi tekrarli) = x-way; hicbiri = random.
    T.classify = function(t)
        local ys = t.yaws
        local n = #ys
        t.amp = nil
        if n < 4 then
            t.pattern = "?"
            return
        end
        t.last_yaw = ys[n]
        local spread = 0
        for i = 1, n do
            for j = i + 1, n do
                spread = max(spread, abs(U.norm(ys[i] - ys[j])))
            end
        end
        if spread < 35 then
            t.pattern = "static"
            return
        end
        local pos, neg, sum = 0, 0, 0
        for i = 2, n do
            local d = U.norm(ys[i] - ys[i - 1])
            sum = sum + d
            pos = pos + (d > 3 and 1 or 0)
            neg = neg + (d < -3 and 1 or 0)
        end
        if (pos == n - 1 or neg == n - 1) and abs(sum) >= 90 then
            t.pattern = "spin"
            return
        end
        local rel = {}
        for i = 1, n do
            rel[i] = U.norm(ys[i] - ys[n])
        end
        table.sort(rel)
        local gaps, start = {}, nil
        for i = 1, n do
            gaps[i] = i < n and rel[i + 1] - rel[i] or rel[1] + 360 - rel[n]
            if start == nil and gaps[i] >= 20 then
                start = i
            end
        end
        if start == nil then
            t.pattern = "random"
            return
        end
        -- Bosluktan sonraki ornekten baslayip cemberi bir kez dolas (360 eklenerek acilir).
        local clusters, cur = {}, nil
        for k = 1, n do
            local i = (start + k - 1) % n + 1
            local v = rel[i] + (i <= start and 360 or 0)
            if cur == nil or gaps[(i - 2) % n + 1] >= 20 then
                cur = { lo = v, hi = v, n = 0, sum = 0 }
                clusters[#clusters + 1] = cur
            end
            cur.hi, cur.n, cur.sum = v, cur.n + 1, cur.sum + v
        end
        local nc, tight, multi = #clusters, true, 0
        for _, c in ipairs(clusters) do
            if c.hi - c.lo > (nc == 2 and 25 or 15) then
                tight = false
            end
            multi = multi + (c.n >= 2 and 1 or 0)
        end
        if nc == 2 and tight and multi == 2 then
            t.pattern = "jitter"
            t.amp = abs(U.norm(clusters[2].sum / clusters[2].n - clusters[1].sum / clusters[1].n))
        elseif nc >= 3 and nc <= 5 and tight and multi >= 2 then
            t.pattern = "xway"
        else
            t.pattern = "random"
        end
    end

    -- SETUP_COMMAND: NET_UPDATE 1 tick'ten uzun gelmediyse (callback yok / durdu) takip buradan guncellenir.
    T.fallback = function()
        local tick = U.tick()
        if tick - T.net_tick > 1 or tick < T.net_tick then
            T.update(false)
        end
    end

    -- Sadece defensive (sim zamani geri gitti): gercek kayit beklenebilen tek durum (LC backtrack kaydi degildir).
    T.def = function(idx)
        local t = T.p[idx]
        return t ~= nil and U.tick() <= t.def_until
    end

    -- Sahte kaydin turu (log icin): "defensive" / "LC" / nil.
    T.fake_kind = function(idx)
        local t = T.p[idx]
        if t == nil then
            return nil
        end
        local tick = U.tick()
        return (tick <= t.def_until and "defensive") or (tick <= t.lc_until and "LC") or nil
    end

    -- Dusman son n tick icinde uyandi mi (dormant / olu / guncellenmeyen -> ilk kayit).
    T.woke = function(idx, n)
        local t = T.p[idx]
        if t == nil or t.wake_tick == nil then
            return false
        end
        local tick = U.tick()
        return tick >= t.wake_tick and tick - t.wake_tick <= n
    end

    T.fake = function(idx)
        local t = T.p[idx]
        if t == nil then
            return false
        end
        local tick = U.tick()
        return tick <= t.def_until or tick <= t.lc_until
    end

    -- Dusmanin durumu (loglar ve resolver seviyesi icin).
    T.enemy_state = function(ent)
        if ent == nil then
            return "?"
        end
        if U.flag(ent, "ON_GROUND") == false then
            return "Air"
        end
        local duck = U.num(ent, "m_flDuckAmount") or 0
        local speed = U.speed(ent)
        if duck > 0.7 then
            return speed > 10 and "Crouch move" or "Crouching"
        end
        if speed > 10 then
            return speed < 135 and "Slow walk" or "Moving"
        end
        return "Standing"
    end

    -- Atis satiri profili: "AA <statik|jitter 80|x-way|spin|random|?> dsy? <air|ground>" (GS profile_text).
    T.profile = function(ent)
        local idx = U.index(ent)
        local t = idx ~= nil and T.p[idx] or nil
        local air = ent ~= nil and U.flag(ent, "ON_GROUND") == false
        return fmt("AA %s dsy? %s", N.profile.text(t), air and "air" or "ground")
    end
end

-------------------------------------------------------------------------------
-- Dusman profili (GS enemy_watch / resolver.habit / resolver.observe, V1.0.47-68): gorunen dusmandan saniyede bir
-- ornek (AA deseni, son 1 sn'de defensive, fake duck; 240 ornegi gecince hepsi yariya), kalici aliskanlik (10+ ornek,
-- 8+ bilinen ornegin %60'i ayni desen), hafiza on bilgisi (canli desen yokken bilinen jitter'ciye seviye 1) ve
-- dogrulamasi, "tanindi (hafiza)", AA deseni degisti / kararsiz satirlari (durum degisiminden 1.5 sn sonra sayilir,
-- V1.0.64; sadece log + profil, seviyeye dokunmaz), dusman basina kariyer sayaclari ve "dusman ozeti".
-------------------------------------------------------------------------------
do
    local U, PR = N.util, N.profile
    -- R kaydindaki desen sirasi; MULTI = cok tarafli desenler (sabit bir aci ancak bir kismini tutar).
    PR.PATTERNS = { "static", "jitter", "xway", "spin", "random" }
    PR.NAMES = { static = "statik", jitter = "jitter", xway = "x-way", spin = "spin", random = "random" }
    PR.MULTI = { jitter = true, xway = true, random = true }
    -- K kaydi: karsilasilan harita, onu oldurdun, o seni oldurdu, atis, isabet, kafa isabeti, correction iskasi,
    -- sana mermisi, kafana mermisi.
    PR.CAREER = { "enc", "k", "d", "s", "h", "hh", "c", "b", "bh" }
    PR.SETTLE, PR.FLIP_WINDOW, PR.FLIP_MAX, PR.CHANGE_EVERY, PR.HALVE_AT = 1.5, 20, 4, 10, 240
    -- s[anahtar]: bu haritadaki durum (ornek zamani, karsilasildi mi, tanindi / on bilgi / dogrulama yazildi mi,
    -- oturmus desen ailesi, degisim zamanlari, mac sonu panelinde yazildi mi). ended: mac sonu paneli gecti.
    PR.s, PR.ended = {}, false

    PR.new_prof = function()
        return { n = 0, static = 0, jitter = 0, xway = 0, spin = 0, random = 0, def = 0, fd = 0 }
    end

    PR.name = function(pattern)
        return PR.NAMES[pattern] or "?"
    end

    -- Takip kaydinin deseni: "jitter 80" / "x-way" / "spin" / "statik" / "random" / "?".
    PR.text = function(t)
        local pattern = t ~= nil and t.pattern or "?"
        if pattern == "jitter" and U.finite(t.amp) then
            return fmt("jitter %d", U.R(t.amp))
        end
        return PR.name(pattern)
    end

    PR.family = function(pattern)
        return PR.MULTI[pattern] and "multi" or pattern
    end

    PR.session = function(key)
        local s = PR.s[key]
        if s == nil then
            s = { flips = {} }
            PR.s[key] = s
        end
        return s
    end

    -- Aliskanlik: { pattern (ya da nil), def, fd } ya da 10 ornekten azsa nil.
    PR.habit = function(p)
        local r = p ~= nil and p.prof or nil
        if r == nil or r.n < 10 then
            return nil
        end
        local best, count, known = nil, 0, 0
        for _, name in ipairs(PR.PATTERNS) do
            local c = r[name] or 0
            known = known + c
            if c > count then
                best, count = name, c
            end
        end
        if known < 8 or count < known * 0.6 then
            best = nil
        end
        return { pattern = best, def = r.def / r.n, fd = r.fd / r.n }
    end

    -- En sik bilinen desen (aliskanlik esigi olmadan; dusman ozeti icin).
    PR.dominant = function(r)
        local best, count = nil, 0
        for _, name in ipairs(PR.PATTERNS) do
            if r ~= nil and (r[name] or 0) > count then
                best, count = name, r[name]
            end
        end
        return best
    end

    PR.car = function(p)
        local c = p.car
        if c == nil then
            c = {}
            for _, name in ipairs(PR.CAREER) do
                c[name] = 0
            end
            p.car = c
        end
        return c
    end

    -- Bu haritada ilk karsilasma: kariyerde +1 harita.
    PR.met = function(key, p)
        local s = PR.session(key)
        if not s.met then
            s.met = true
            local c = PR.car(p)
            c.enc = c.enc + 1
            N.mem.dirty = true
        end
        return s
    end

    -- Kariyer sayaci (S.on_shoot / on_hit / on_miss / on_hurt / on_death'ten birer cagri).
    PR.count = function(ent, key, field, field2)
        local p, k = N.mem.entry(ent, key)
        if p == nil then
            return
        end
        PR.met(k, p)
        local c = PR.car(p)
        c[field] = c[field] + 1
        if field2 ~= nil then
            c[field2] = c[field2] + 1
        end
        N.mem.dirty = true
    end

    PR.sample = function(p, t, tick)
        local r = p.prof
        if r == nil then
            r = PR.new_prof()
            p.prof = r
        end
        r.n = r.n + 1
        local pattern = t ~= nil and t.pattern or "?"
        if PR.NAMES[pattern] ~= nil then
            r[pattern] = r[pattern] + 1
        end
        if t ~= nil and t.def_until >= tick - 64 then
            r.def = r.def + 1
        end
        if t ~= nil and t.fd_until >= tick - 64 then
            r.fd = r.fd + 1
        end
        if r.n > PR.HALVE_AT then
            for field, value in pairs(r) do
                r[field] = value / 2
            end
        end
        N.mem.dirty = true
    end

    -- Dosyadan taninan dusman: haritada bir kez, ilk goruste.
    PR.announce = function(ent, p, s)
        if s.announced or not p.mem then
            return
        end
        s.announced = true
        if not N.on("resolver_log") then
            return
        end
        local h = PR.habit(p)
        local parts = {}
        if h ~= nil and h.pattern ~= nil then
            parts[#parts + 1] = "genelde " .. PR.name(h.pattern) .. " (dogrulanacak)"
        end
        if h ~= nil and h.def >= 0.2 then
            parts[#parts + 1] = fmt("defensive %%%d", U.R(h.def * 100))
        end
        if h ~= nil and h.fd >= 0.1 then
            parts[#parts + 1] = fmt("fake duck %%%d", U.R(h.fd * 100))
        end
        local c = p.car
        if c ~= nil and c.s + c.k + c.d + c.b > 0 then
            parts[#parts + 1] = fmt("gecmis %d harita, K/D %d/%d, atis %d/%d (kafa %d), correction %d", U.R(c.enc),
                U.R(c.k), U.R(c.d), U.R(c.h), U.R(c.s), U.R(c.hh), U.R(c.c))
        end
        if #parts > 0 then
            N.log.line(fmt("resolver: %s tanindi (hafiza): %s", U.name(ent), concat(parts, ", ")))
        end
    end

    -- Hafiza on bilgisi (RG.level): o durumda veri yok + canli desen henuz yok + aliskanlik cok tarafli -> seviye 1
    -- (GS resolver_level "remembered"). Satir dusman basina haritada bir kez.
    PR.prior = function(ent, p, key, tr)
        if p == nil or key == nil or (tr ~= nil and tr.pattern ~= "?") then
            return false
        end
        local h = PR.habit(p)
        if h == nil or not PR.MULTI[h.pattern] then
            return false
        end
        local s = PR.session(key)
        if not s.prior_logged then
            s.prior_logged = true
            if N.on("resolver_log") then
                N.log.line(fmt("resolver: %s %s -> safe point Head (veri yok, hafizadan, dogrulanacak)", U.name(ent),
                    PR.name(h.pattern)))
            end
        end
        return true
    end

    -- Canli desenle: hafiza dogrulamasi (haritada bir kez) ve desen degisimi / kararsizlik.
    PR.observe = function(ent, t, key, s, now)
        local pattern = t.pattern
        if PR.NAMES[pattern] == nil then
            return
        end
        local p = N.mem.players[key]
        if s.verified == nil and p ~= nil and p.mem then
            local h = PR.habit(p)
            if h ~= nil and h.pattern ~= nil then
                local same = PR.family(h.pattern) == PR.family(pattern)
                s.verified = same
                if not same then
                    -- Aliskanlik canli davranisa cabuk uysun: eski desen sayilari yariya.
                    for _, name in ipairs(PR.PATTERNS) do
                        p.prof[name] = p.prof[name] / 2
                    end
                    N.mem.dirty = true
                end
                if N.on("resolver_log") then
                    N.log.line(fmt("resolver: %s hafiza %s: genelde %s, simdi %s%s", U.name(ent),
                        same and "dogrulandi" or "tutmadi", PR.name(h.pattern), PR.text(t),
                        same and "" or " (canli desen kullaniliyor, aliskanlik duzeltildi)"))
                end
            else
                s.verified = "yok"
            end
        end
        local state = N.track.enemy_state(ent)
        if state ~= s.state or s.since == nil or now < s.since then
            s.state, s.since = state, now
        end
        if now - s.since < PR.SETTLE then
            return
        end
        local fam = PR.family(pattern)
        if s.fam ~= nil and fam ~= s.fam then
            local flips = {}
            for _, x in ipairs(s.flips) do
                if now >= x and now - x <= PR.FLIP_WINDOW then
                    flips[#flips + 1] = x
                end
            end
            flips[#flips + 1] = now
            s.flips = flips
            local log = N.on("resolver_log")
            if #flips >= PR.FLIP_MAX then
                if log and now >= (s.unstable or -1000) then
                    N.log.line(fmt("resolver: %s AA deseni kararsiz (%d sn'de %d degisim)", U.name(ent), PR.FLIP_WINDOW,
                        #flips))
                end
                s.unstable = now + PR.FLIP_WINDOW
            elseif log and now >= (s.unstable or -1000) and (s.changed == nil or now < s.changed
                or now - s.changed >= PR.CHANGE_EVERY) then
                s.changed = now
                N.log.line(fmt("resolver: %s AA deseni degisti (%s -> %s)", U.name(ent), PR.name(s.pattern),
                    PR.name(pattern)))
            end
        end
        s.fam, s.pattern = fam, pattern
    end

    -- SETUP_COMMAND: gorunen her dusman icin canli desen gozlemi, saniyede bir ornek. Mac sonu panelinden sonra
    -- (PR.ended, ara 10-15 sn) ornek / karsilasma / tanima yok: harita ozeti yazildi, kariyer ikinci kez sayilmaz.
    PR.tick = function()
        if PR.ended then
            return
        end
        local T, M = N.track, N.mem
        local tick, now = U.tick(), U.now()
        for _, ent in ipairs(N.exposure.enemies()) do
            local idx = U.index(ent)
            local t = idx ~= nil and T.p[idx] or nil
            local key = M.cached(ent)
            if key ~= nil then
                local s = PR.session(key)
                if s.sampled == nil or now < s.sampled or now - s.sampled >= 1 then
                    s.sampled = now
                    local p = M.entry(ent, key)
                    if p ~= nil then
                        PR.announce(ent, p, s)
                        PR.met(key, p)
                        PR.sample(p, t, tick)
                        local h = PR.habit(p)
                        if t ~= nil then
                            t.fd_need = (h ~= nil and h.fd >= 0.15) and 1 or 2
                        end
                    end
                end
                if t ~= nil then
                    PR.observe(ent, t, key, s, now)
                end
            end
        end
    end

    -- Harita sonu (harita degisimi, mac sonu paneli, kapanis): bu haritada karsilasilan ve henuz yazilmamis her
    -- dusman icin kariyer satiri (o seni en cok oldurenden). panel = mac sonu paneli: durum silinmez, PR.ended ile
    -- donar (ara surede ayni dusman yeniden "karsilasildi" sayilmasin); game_newmap / kapanis yazilanlari atlar ve
    -- durumu siler. Ayni haritada yeni mac (game_newmap'siz) PR.round_start'ta temiz baslar.
    PR.map_end = function(panel)
        local list = {}
        for key, s in pairs(PR.s) do
            local p = (s.met and not s.reported) and N.mem.players[key] or nil
            if p ~= nil then
                s.reported = true
                list[#list + 1] = { p = p, name = tostring(p.name or "?"), c = PR.car(p) }
            end
        end
        if panel then
            PR.ended = true
        else
            PR.s, PR.ended = {}, false
        end
        if #list == 0 or not (N.on("hit_log") or N.on("shot_log")) then
            return
        end
        table.sort(list, function(a, b)
            if a.c.d ~= b.c.d then
                return a.c.d > b.c.d
            end
            return a.name < b.name
        end)
        for _, x in ipairs(list) do
            local c, r = x.c, x.p.prof
            local tail = ""
            if r ~= nil and r.n > 0 then
                local def, fd = U.R(r.def / r.n * 100), U.R(r.fd / r.n * 100)
                tail = (def >= 1 and fmt(" def %%%d", def) or "") .. (fd >= 1 and fmt(" fd %%%d", fd) or "")
            end
            N.log.line(fmt("dusman ozeti: %s | K/D %d/%d | atis %d, isabet %d (kafa %d), correction %d | sana %d mermi (kafa %d) | desen %s%s",
                x.name, U.R(c.k), U.R(c.d), U.R(c.s), U.R(c.h), U.R(c.hh), U.R(c.c), U.R(c.b), U.R(c.bh),
                PR.name(PR.dominant(r)), tail))
        end
    end

    PR.reset = function()
        PR.s, PR.ended = {}, false
    end

    -- round_start: mac sonu panelinden sonra ayni haritada yeni mac -> yeni harita durumu.
    PR.round_start = function()
        if PR.ended then
            PR.s, PR.ended = {}, false
        end
    end
end

-------------------------------------------------------------------------------
-- Gorus (X1): biri kafami su an / 0.2 sn icinde goruyor mu; tehdit her cagride, digerleri sirayla.
-------------------------------------------------------------------------------
do
    local U, E = N.util, N.exposure
    E.sight, E.now_set, E.soon_set = {}, {}, {}
    E.now, E.soon, E.seen, E.near = false, false, false, false
    E.turn, E.last_tick, E.first_edge = 0, -1000, {}
    -- N2: wake_edge[idx] = islenen son uyanma tick'i (T.wake). Yeni uyanan dusman (dormant'tan cikti) NEAR icindeyse
    -- ilk gorus kenari sayilir (sunucu gorunmeyen dusmani gondermiyor: uyanma = peek) ve 16 tick boyunca her tick
    -- kontrol edilir (sira beklemez).
    E.wake_edge = {}
    -- V1.0.11 duvar hatti: wb[idx] = { dmg = dusmanin duvardan bana verebilecegi hasar (kafa / pelvis izinin buyugu),
    -- tick = son olcum, since = hattin acildigi tick }. Log 4: yenen 9 merminin 9'u duvardan.
    E.wb = {}

    E.enemies = function()
        local st = N.st
        local tick = U.tick()
        if st.enemies_tick == tick then
            return st.enemies
        end
        local list, any = {}, false
        local ok, players = pcall(entity_list.get_players, true)
        if ok and type(players) == "table" then
            for _, ent in ipairs(players) do
                if U.alive(ent) then
                    any = true
                    if not U.dormant(ent) and ent ~= st.lp then
                        list[#list + 1] = ent
                    end
                end
            end
        end
        st.enemies, st.enemies_tick, st.any_enemy_alive = list, tick, any
        return list
    end

    -- Dusmanin gozunden kafama (ve +-4 birim kenarlarina) mermi geciyor mu.
    E.check = function(enemy, lp, head, predict)
        local eye = U.eye(enemy)
        if eye == nil or head == nil then
            return false
        end
        local hx, hy, hz = head.x, head.y, head.z
        local ex, ey, ez = eye.x, eye.y, eye.z
        if predict then
            local my, their = U.vel(lp), U.vel(enemy)
            local idx = U.index(enemy)
            local tr = idx ~= nil and N.track.p[idx] or nil
            local lag = min(0.25, (tr ~= nil and tr.record_age or 0) * U.ipt())
            local ta = N.K.LOOKAHEAD
            hx, hy, hz = hx + my.x * ta, hy + my.y * ta, hz + my.z * ta
            ex, ey, ez = ex + their.x * (ta + lag), ey + their.y * (ta + lag), ez + their.z * (ta + lag)
        end
        local from = vec3_t(ex, ey, ez)
        local yaw = U.yaw_to(from, { x = hx, y = hy }) + 90
        local cx, sy = U.dir(yaw)
        for _, off in ipairs({ 0, 4, -4 }) do
            local p = vec3_t(hx + cx * off, hy + sy * off, hz)
            if U.tdmg(from, p, enemy, lp) > 0 then
                return true
            end
        end
        -- A1 (log 1-2: bize gelen mermilerin %50-81'i "gormedi"): mermi izi 0 dondu ama gozunden kafama duz cizgi
        -- aciksa (lp'ye carpiyor ya da yol %97 acik) goruyor sayilir; trace.bullet'in lp hedefiyle 0 dondugu durumlar
        -- (teshis: G31 sayaclari) artik "gorulmedi" yazilmaz.
        -- Tahminli (birazdan gorecek) kontrolde yedek yok: sadece su anki konumlar icin.
        if predict then
            return false
        end
        local f, hit, okl = U.tline(from, vec3_t(hx, hy, hz), enemy)
        local open = okl == true and (f >= 0.97 or (hit ~= nil and hit == lp))
        N.diag.g31(open)
        return open
    end

    E.update = function()
        local st = N.st
        local lp = st.lp
        local tick = U.tick()
        local list = E.enemies()
        local mine = U.origin(lp)
        local near = false
        local check = {}
        if mine ~= nil then
            for _, enemy in ipairs(list) do
                local o = U.origin(enemy)
                local close = o ~= nil and U.dist(o, mine) <= N.K.NEAR
                if close then
                    near = true
                end
                local idx = U.index(enemy)
                local tr = idx ~= nil and N.track.p[idx] or nil
                if tr ~= nil and tr.wake_tick ~= nil and tick >= tr.wake_tick and tick - tr.wake_tick <= 16 then
                    check[#check + 1] = enemy
                    -- slept_ticks nil: tick geri gitti (yeni harita), gercek bir uyanma degil.
                    if close and tr.slept_ticks ~= nil and E.wake_edge[idx] ~= tr.wake_tick then
                        E.wake_edge[idx] = tr.wake_tick
                        E.first_edge[idx] = tick
                    end
                end
            end
        end
        E.near = near
        local due = tick - E.last_tick >= N.K.EXPOSE_EVERY or tick < E.last_tick
        if due or #check > 0 then
            local head = U.hitbox(lp, "HEAD")
            if due then
                E.last_tick = tick
                local threat = st.threat
                local function add(enemy)
                    for _, e in ipairs(check) do
                        if e == enemy then
                            return
                        end
                    end
                    check[#check + 1] = enemy
                end
                if threat ~= nil then
                    add(threat)
                end
                if #list > 0 then
                    E.turn = E.turn % #list + 1
                    add(list[E.turn])
                end
            end
            for _, enemy in ipairs(check) do
                local idx = U.index(enemy)
                if idx ~= nil then
                    local now_seen = E.check(enemy, lp, head, false)
                    local soon = now_seen or E.check(enemy, lp, head, true)
                    E.now_set[idx] = now_seen and tick or nil
                    E.soon_set[idx] = soon and tick or nil
                    E.wall_lane(enemy, idx, lp, head, now_seen, tick)
                    if now_seen then
                        local s = E.sight[idx]
                        if s == nil or tick - s.last > N.K.SIGHT_GAP or tick < s.last then
                            E.sight[idx] = { first = tick, last = tick }
                            E.first_edge[idx] = tick
                        else
                            s.last = tick
                        end
                    end
                end
            end
        end
        -- Ozet bayraklar (tehdit disindakilerin degeri 12 tick gecerli).
        local any_now, any_soon, any_seen = false, false, false
        for idx, t in pairs(E.now_set) do
            if tick - t <= 12 and tick >= t then
                any_now = true
            else
                E.now_set[idx] = nil
            end
        end
        for idx, t in pairs(E.soon_set) do
            if tick - t <= 12 and tick >= t then
                any_soon = true
            else
                E.soon_set[idx] = nil
            end
        end
        for _, s in pairs(E.sight) do
            if tick >= s.last and tick - s.last <= N.K.SIGHT_RECENT then
                any_seen = true
            end
        end
        E.now, E.soon, E.seen = any_now, any_soon, any_seen
    end

    -- Dusman beni "goruyor" (mermi izi > 0) ama gozunden kafama duz cizgi kapaliysa duvardan vurabiliyor demektir.
    E.wall_lane = function(enemy, idx, lp, head, now_seen, tick)
        if not now_seen or head == nil then
            E.wb[idx] = nil
            return
        end
        local eye = U.eye(enemy)
        if eye == nil then
            E.wb[idx] = nil
            return
        end
        local f, hit, okl = U.tline(eye, head, enemy)
        if okl ~= true or f >= 0.97 or (hit ~= nil and hit == lp) then
            E.wb[idx] = nil
            return
        end
        local d = U.tdmg(eye, head, enemy, lp)
        local pel = U.hitbox(lp, "PELVIS")
        if pel ~= nil then
            d = max(d, U.tdmg(eye, pel, enemy, lp))
        end
        if d <= 0 then
            E.wb[idx] = nil
            return
        end
        local old = E.wb[idx]
        local since = (old ~= nil and tick >= old.tick and tick - old.tick <= 16) and old.since or tick
        E.wb[idx] = { dmg = d, tick = tick, since = since, ent = enemy }
    end

    -- En buyuk taze (12 tick) duvar hatti: hasar, kayit; yoksa 0.
    E.wb_best = function()
        local tick = U.tick()
        local best, rec = 0, nil
        for idx, w in pairs(E.wb) do
            if tick >= w.tick and tick - w.tick <= 12 then
                if w.dmg > best then
                    best, rec = w.dmg, w
                end
            else
                E.wb[idx] = nil
            end
        end
        return best, rec
    end

    E.sees = function(idx)
        local s = E.sight[idx]
        local tick = U.tick()
        return s ~= nil and tick >= s.last and tick - s.last <= N.K.SIGHT_RECENT
    end

    E.sees_now = function(idx)
        local t = E.now_set[idx]
        return t ~= nil and U.tick() - t <= 12
    end

    -- Ilk gorus kenari son n tick icinde mi (anti-peek).
    E.first_sight_within = function(n)
        local tick = U.tick()
        for _, t in pairs(E.first_edge) do
            if tick >= t and tick - t <= n then
                return true
            end
        end
        return false
    end

    E.reset = function()
        E.sight, E.now_set, E.soon_set, E.first_edge, E.wake_edge, E.wb = {}, {}, {}, {}, {}, {}
        E.now, E.soon, E.seen = false, false, false
    end
end

-------------------------------------------------------------------------------
-- Durum (A1): once hareket durumu (Air > Fake duck > Peek > egik > yuru > dur), sonra Manual > Safe head >
-- Freestanding (sadece kafa gizliyken).
-------------------------------------------------------------------------------
do
    local U, S = N.util, N.state
    S.ground_ticks, S.moving, S.ducked, S.cmdn = 64, false, false, nil
    S.peek_until = -1000

    S.speed_hysteresis = function(speed)
        if speed > N.K.MOVE_ENTER then
            S.moving = true
        elseif speed < N.K.MOVE_LEAVE then
            S.moving = false
        end
        return S.moving
    end

    S.detect = function(cmd, unpred)
        local cmdn = cmd ~= nil and cmd.command_number or nil
        if cmdn ~= nil and cmdn == S.cmdn then
            return N.st.state
        end
        S.cmdn = cmdn
        local st, P, E = N.st, N.ref, N.exposure
        local lp = st.lp
        local tick = U.tick()
        local ground = U.flag(lp, "ON_GROUND") ~= false
        if unpred ~= nil then
            local ok, v = pcall(unpred.has_player_flag, unpred, e_player_flags.ON_GROUND)
            if ok and v == false then
                ground = false
            end
        end
        S.ground_ticks = ground and min(S.ground_ticks + 1, 64) or 0
        local jump = false
        if cmd ~= nil then
            local okj, j = pcall(cmd.has_button, cmd, e_cmd_buttons.JUMP)
            jump = okj and j == true
        end
        local air = jump or S.ground_ticks < N.K.LANDING_TICKS
        st.airborne = S.ground_ticks < N.K.LANDING_TICKS
        -- Merdivende ON_GROUND yok ama ucus degil: exploit / air lag / jump scout merdiveni hava saymaz (GS L.policy).
        st.ladder = U.num(lp, "m_MoveType") == 9
        local speed = U.speed(lp)
        st.speed = speed
        local moving = S.speed_hysteresis(speed)
        local duck = U.num(lp, "m_flDuckAmount") or 0
        st.duck = duck
        if duck > N.K.DUCK_ENTER then
            S.ducked = true
        elseif duck < N.K.DUCK_LEAVE then
            S.ducked = false
        end
        local fd = P.fd_on()
        st.fd = fd
        local crouch = S.ducked or fd
        local winfo = U.winfo(lp)
        st.winfo = winfo
        st.weapon = winfo ~= nil and winfo.name or nil
        st.melee = U.melee(winfo)
        st.wgroup = P.wgroup()

        -- Peek: native autopeek tusu + hareket, AI peek yuruyor / bekliyor, AFK, ya da (Auto peek) hareket
        -- ederken gorus alanina girmek.
        local peek = false
        local pk = N.peek
        if (P.on("autopeek") and moving) or pk.mode ~= nil or N.afk.on then
            peek = true
        elseif N.on("auto_peek") and moving then
            if E.soon or E.now then
                S.peek_until = tick + N.K.PEEK_HOLD
            end
            if tick <= S.peek_until and tick >= S.peek_until - N.K.PEEK_HOLD then
                peek = true
            end
        end

        local ms
        if air then
            ms = crouch and "Air crouch" or "Air"
        elseif fd then
            ms = "Fake duck"
        elseif peek then
            ms = "Peek"
        elseif crouch then
            ms = moving and "Crouch move" or "Crouching"
        elseif moving then
            ms = P.on("slowwalk") and "Slow walk" or "Moving"
        else
            ms = "Standing"
        end
        st.move_state = ms
        st.crouch = crouch

        -- Ust katman.
        local manual = U.call(antiaim.get_manual_override)
        manual = U.finite(manual) and manual or 0
        st.manual = manual
        local state = ms
        local fs_allowed = S.fs_allowed(ms)
        st.fs_own = nil
        if manual == 1 or manual == 2 or manual == 3 then
            state = "Manual"
        elseif S.safe_head(ms) then
            state = "Safe head"
        elseif P.on("fs") and fs_allowed and not E.now then
            state = "Freestanding"
        elseif N.on("fs_auto") and (ms == "Standing" or ms == "Crouching") and st.threat ~= nil
            and N.aa.cover ~= nil and N.aa.cover_auto then
            state = "Freestanding"
            st.fs_own = N.aa.cover
        end
        st.state = state
        st.label = (ms == "Peek" and crouch and state == "Peek") and "Peek (egik)" or state
        N.aa.fs_native(ms, fs_allowed)
        return state
    end

    S.fs_allowed = function(ms)
        if (ms == "Air" or ms == "Air crouch") and N.on("fs_air") then
            return false
        end
        if (ms == "Crouching" or ms == "Crouch move") and N.on("fs_crouch") then
            return false
        end
        if ms == "Slow walk" and N.on("fs_slow") then
            return false
        end
        if (ms == "Moving" or ms == "Peek") and N.on("fs_moving") then
            return false
        end
        return true
    end

    S.safe_head = function(ms)
        if not N.on("safe_head") then
            return false
        end
        local st = N.st
        if ms == "Air crouch" then
            if N.on("safe_knife") and st.melee ~= nil then
                return true
            end
            if N.on("safe_air") then
                return true
            end
        end
        if N.on("safe_high") and st.threat ~= nil and (ms == "Standing" or ms == "Moving" or ms == "Slow walk"
            or ms == "Crouching" or ms == "Crouch move" or ms == "Peek") then
            local mine, theirs = U.origin(st.lp), U.origin(st.threat)
            local idx = U.index(st.threat)
            if mine ~= nil and theirs ~= nil and mine.z - 35 > theirs.z and idx ~= nil
                and N.exposure.sees_now(idx) then
                return true
            end
        end
        return false
    end
end

-------------------------------------------------------------------------------
-- Anti-aim: AA hedefi, builder (yaw L&R / X-Way, modifier, body yaw, limitler), jitter cevirme (gonderilen
-- pakette, komut numarasi basina bir kez), anti-brute fazi, gizli acilar, desync isareti olcumu, spin / legit /
-- backstab, kendi freestand'imiz (kapak izleri).
-------------------------------------------------------------------------------
do
    local U, A = N.util, N.aa
    local K = N.K
    A.flip = { side = false, packets = 0, extra = 0, step = 0, mstep = 0, yaw_n = 0, mod_n = 0, limit_n = 0,
        rand_side = false, cmdn = nil }
    A.sign_mul = -1
    A.cal = { n = 0, agree = 0, prev = nil, done = false, nil_n = 0, phase = 1, invert = false }
    A.cover, A.cover_auto, A.cover_tick = nil, false, -1000
    A.spin_angle, A.spin_cmdn, A.hspin = 0, nil, 0
    A.last = { side = false, limit = 60, body = "jit", phase = 0, yaw = 0 }
    A.applied, A.target_tick, A.target_ent, A.facing = 0, -1, nil, nil
    A.fs_item = nil
    A.MANUAL = { [1] = -90, [2] = 0, [3] = 90 }

    A.view_yaw = function(cmd)
        if cmd ~= nil then
            local ok, y = pcall(function()
                return cmd.viewangles.y
            end)
            if ok and U.finite(y) then
                N.st.view_yaw = y
                return y
            end
        end
        local ok, ang = pcall(engine.get_view_angles)
        if ok and ang ~= nil then
            local okv, y = pcall(function()
                return ang.y
            end)
            if okv and U.finite(y) then
                return y
            end
        end
        return N.st.view_yaw or 0
    end

    -- AA hedefi: duello (son 1 sn'de ates ettigin ve seni goren) > son 1 sn'de kafana ates eden > seni goren >
    -- nisangaha en yakin.
    A.target = function()
        local tick = U.tick()
        if A.target_tick == tick then
            return A.target_ent
        end
        A.target_tick = tick
        local st, E, T = N.st, N.exposure, N.track
        local list = E.enemies()
        local now = U.now()
        local best
        for _, e in ipairs(list) do
            local idx = U.index(e)
            local t = idx ~= nil and T.p[idx] or nil
            if t ~= nil and now >= t.we_shot and now - t.we_shot <= 1 and E.sees(idx) then
                best = e
                break
            end
        end
        if best == nil then
            local last = -1000
            for _, e in ipairs(list) do
                local idx = U.index(e)
                local t = idx ~= nil and T.p[idx] or nil
                if t ~= nil and now >= t.shot_us and now - t.shot_us <= 1 and t.shot_us > last then
                    best, last = e, t.shot_us
                end
            end
        end
        if best == nil then
            local last = -1000
            for _, e in ipairs(list) do
                local idx = U.index(e)
                local s = idx ~= nil and E.sight[idx] or nil
                if s ~= nil and E.sees(idx) and s.last > last then
                    best, last = e, s.last
                end
            end
        end
        if best == nil then
            local mine = U.origin(st.lp)
            local view = A.view_yaw(nil)
            local best_d = huge
            if mine ~= nil then
                for _, e in ipairs(list) do
                    local o = U.origin(e)
                    if o ~= nil then
                        local d = abs(U.norm(U.yaw_to(mine, o) - view))
                        if d < best_d then
                            best, best_d = e, d
                        end
                    end
                end
            end
        end
        A.target_ent = best
        return best
    end

    A.base = function(cmd)
        local view = A.view_yaw(cmd)
        if N.v("yaw_base") ~= 1 then
            return view, nil
        end
        local target = A.target()
        local mine, theirs = U.origin(N.st.lp), target ~= nil and U.origin(target) or nil
        if mine == nil or theirs == nil then
            return view, nil
        end
        return U.yaw_to(mine, theirs), target
    end

    -- Durumun gecerli satiri: Override kapali hareket durumlari Global'i kullanir.
    A.row = function(state)
        if state == "Ladder" or state == "Legit" or state == "Spin" then
            return "Global"
        end
        if K.OVERRIDABLE[state] and N.bv(state, "override") == false then
            return "Global"
        end
        if N.ui.b[state] == nil then
            return "Global"
        end
        return state
    end

    -- Kapak izleri (A10 / A13): tehdidin gozunden kafamin +-20 birim yanina duz iz (trace.line; hitbox olmayan
    -- noktaya trace.bullet'in ne dondurdugu belgesiz). Tek taraf kapaliysa o taraf; kazanan yoksa kapak yok.
    A.cover_update = function()
        local tick = U.tick()
        if tick - A.cover_tick < 8 and tick >= A.cover_tick then
            return
        end
        A.cover_tick = tick
        local st = N.st
        local threat = st.threat
        A.cover_auto = false
        if threat == nil then
            return
        end
        local eye, head = U.eye(threat), U.hitbox(st.lp, "HEAD")
        local mine, theirs = U.origin(st.lp), U.origin(threat)
        if eye == nil or head == nil or mine == nil or theirs == nil then
            return
        end
        local base = U.yaw_to(mine, theirs)
        local plus = U.offset(head, base + 90, 20, 0)
        local minus = U.offset(head, base - 90, 20, 0)
        local fp, hp = U.tline(eye, plus, threat)
        local fm, hm = U.tline(eye, minus, threat)
        local op = fp >= 0.97 or (hp ~= nil and hp == st.lp)
        local om = fm >= 0.97 or (hm ~= nil and hm == st.lp)
        if not op and om then
            A.cover, A.cover_auto = 1, true
        elseif not om and op then
            A.cover, A.cover_auto = -1, true
        else
            A.cover = nil
        end
    end

    -- A9: native Auto Direction "States" ogesi, izin verilmeyen durumda gecici kapali.
    A.fs_native = function(ms, allowed)
        local ref = N.ref.items.fs_states
        if ref == nil then
            return
        end
        local item = (ms == "Air" or ms == "Air crouch") and "Air"
            or ((ms == "Standing" or ms == "Crouching" or ms == "Fake duck") and "Stand" or "Move")
        if not allowed then
            if A.fs_item ~= item then
                N.ov.release_prefix("fs_states:")
                A.fs_item = item
            end
            N.ov.set_multi("fs_states", ref, item, false)
        elseif A.fs_item ~= nil then
            N.ov.release_prefix("fs_states:")
            A.fs_item = nil
        end
    end

    A.choked = function()
        local c = U.call(engine.get_choked_commands)
        return U.finite(c) and c or 0
    end

    -- Gonderilen pakette (choked == 0) bir kez; komut numarasi anahtar.
    A.update_flip = function(cmd, row, phase)
        if A.choked() ~= 0 then
            return
        end
        local F = A.flip
        local cmdn = cmd ~= nil and cmd.command_number or nil
        if cmdn ~= nil and cmdn == F.cmdn then
            return
        end
        F.cmdn = cmdn
        F.packets = F.packets + 1
        F.mstep = F.mstep + 1
        local body = N.bv(row, "body_yaw")
        local target = 1
        if body == 1 or body == 3 then
            target = (N.bv(row, "delay") or 1) + F.extra
        end
        local kicked = false
        if phase ~= nil then
            if phase.rnd or (phase.wall and A.cover == nil) then
                target = F.hold or 1
            elseif phase.wall then
                if F.side == (A.cover > 0) then
                    target = target + phase.asym
                end
            elseif phase.asym ~= nil and F.side == (F.step % 8 < 4) then
                target = target + phase.asym
            end
            if phase.kick and F.kick then
                target, kicked = 0, true
            end
        end
        if F.packets < target then
            return
        end
        F.kick = nil
        if body == 3 then
            F.side = random(0, 1) == 1
        else
            F.side = not F.side
        end
        F.packets = 0
        F.step = kicked and random(0, 7) or F.step + 1
        F.hold = random(1, 4)
        local spread = N.bv(row, "delay_random") or 0
        F.extra = spread >= 1 and random(0, floor(spread)) or 0
        F.yaw_n = random() * 2 - 1
        F.mod_n = random() * 2 - 1
        F.limit_n = random()
        F.rand_side = random(0, 1) == 1
    end

    A.modifier = function(mode, amount)
        local F = A.flip
        local m = abs(amount)
        if m < 1 or mode == 1 then
            return 0
        end
        if mode == 2 then
            return F.side and m / 2 or -m / 2
        elseif mode == 3 then
            return F.side and amount or 0
        elseif mode == 4 then
            return F.mod_n * m / 2
        elseif mode == 5 then
            return (U.tick() * 6) % (2 * m) - m
        elseif mode == 6 then
            local ways = { -m, 0, m }
            return ways[F.mstep % 3 + 1]
        elseif mode == 7 then
            local ways = { -m, -m / 2, 0, m / 2, m }
            return ways[F.mstep % 5 + 1]
        end
        return 0
    end

    -- Builder acilari (anti-brute fazi dahil). side: true = sag.
    A.angles = function(row, phase)
        local F = A.flip
        local body = N.bv(row, "body_yaw") or 1
        local yaw_side
        if body == 1 or body == 3 then
            yaw_side = F.side
        else
            yaw_side = N.ref.on("inverter")
        end
        local side = yaw_side
        local left, right = N.bv(row, "left_limit") or 58, N.bv(row, "right_limit") or 58
        local body_fs = N.bv(row, "body_fs") == 2
        if phase ~= nil then
            if phase.invert then
                side = not side
                if body ~= 1 and body ~= 3 then
                    yaw_side = side
                end
            end
            if phase.random then
                side = F.rand_side
            end
            if phase.freestand then
                body, body_fs = 2, true
            end
            left, right = U.R(left * phase.scale), U.R(right * phase.scale)
        end
        if body == 2 and body_fs and A.cover ~= nil then
            side = A.cover > 0
        end
        local cut = U.R(F.limit_n * (N.bv(row, "limit_random") or 0))
        left, right = max(0, left - cut), max(0, right - cut)
        local yaw
        if N.bv(row, "yaw_mode") == 2 then
            local ways = U.clamp(floor(N.bv(row, "ways") or 3), 3, 5)
            yaw = N.bv(row, "way" .. (F.step % ways + 1)) or 0
        elseif yaw_side then
            yaw = N.bv(row, "yaw_right") or 0
        else
            yaw = N.bv(row, "yaw_left") or 0
        end
        yaw = yaw + U.R(F.yaw_n * (N.bv(row, "yaw_random") or 0))
        if phase ~= nil then
            yaw = yaw + phase.shift
        end
        local modifier = N.bv(row, "modifier") or 1
        local amount = (N.bv(row, "mod_offset") or 0) + U.R(F.mod_n * (N.bv(row, "mod_random") or 0))
        yaw = yaw + A.modifier(modifier, amount)
        local mode = (body == 2 and body_fs) and "fs" or (body == 2 and "sta") or (body == 4 and "off") or "jit"
        return { body = body, side = side, left = left, right = right, yaw = yaw, mode = mode }
    end

    -- Bomba / rehine 100 birimde mi (legit AA'da E onlar icin).
    A.use_target_near = function(lp)
        local mine = U.origin(lp)
        if mine == nil then
            return false
        end
        for _, class in ipairs({ "CPlantedC4", "CHostage" }) do
            local ok, list = pcall(entity_list.get_entities_by_name, class)
            if ok and type(list) == "table" then
                for _, ent in ipairs(list) do
                    local o = U.origin(ent)
                    if o ~= nil and U.dist(o, mine) <= 100 then
                        return true
                    end
                end
            end
        end
        return false
    end

    -- 250 birimde, goz goze bicakli dusman.
    A.knife_enemy = function(range)
        local st = N.st
        local mine, eye = U.origin(st.lp), U.eye(st.lp)
        if mine == nil or eye == nil then
            return nil
        end
        local best, best_d = nil, range or 250
        for _, e in ipairs(N.exposure.enemies()) do
            if U.melee(U.winfo(e)) == "knife" then
                local o = U.origin(e)
                local d = o ~= nil and U.dist(o, mine) or huge
                if d <= best_d then
                    local their = U.eye(e) or o
                    local frac, hit = U.tline(eye, their, st.lp)
                    if frac >= 0.97 or hit == e then
                        best, best_d = e, d
                    end
                end
            end
        end
        return best, best_d
    end

    A.spin_active = function()
        if not N.on("spin") then
            return false
        end
        if N.on("spin_warmup") and U.game("m_bWarmupPeriod") == 1 then
            return true
        end
        if N.on("spin_enemies") and not N.st.any_enemy_alive then
            return true
        end
        return false
    end

    A.legit_active = function(cmd, lp)
        if not N.on("legit_use") or cmd == nil then
            return false
        end
        local ok, use = pcall(cmd.has_button, cmd, e_cmd_buttons.USE)
        if not ok or use ~= true then
            return false
        end
        return not A.use_target_near(lp)
    end

    A.desync = function(ctx, side, limit)
        local s = side and 1 or -1
        local value = A.sign_mul * s * U.clamp(limit, 0, 60) / 60
        pcall(ctx.set_desync, ctx, value)
        if A.cal.invert then
            pcall(ctx.set_invert_desync, ctx, not side)
        end
        return value
    end

    -- A12: gonderilen pakette, sadece onceki pakette de ayni isaret gonderildiyse (statik aralik) ornek.
    A.calibrate = function(value, standing)
        local C = A.cal
        if C.done then
            return
        end
        local real, fake = U.call(antiaim.get_real_angle), U.call(antiaim.get_fake_angle)
        if not U.finite(real) or not U.finite(fake) then
            C.nil_n = C.nil_n + 1
            if C.nil_n >= 32 then
                C.done = true
                N.log.line("aa: desync isareti olculemedi (olculemedi), + = sag varsayildi")
            end
            return
        end
        if not standing or value == 0 then
            C.prev = nil
            return
        end
        local sign = value > 0 and 1 or -1
        local stretch = C.prev == sign
        C.prev = sign
        if not stretch then
            return
        end
        local d = U.norm(real - fake)
        if abs(d) < 1 then
            return
        end
        C.n = C.n + 1
        -- V1.0.8 (log 4 ham sayilar: deger + iken fark -78, - iken +47): karsilastirma istenen TARAFLA yapilir
        -- (deger x carpan). Eskiden degerin kendi isaretiyle karsilastiriliyordu: bu iliski carpandan bagimsiz sabit
        -- oldugu icin her yuklemede "ters" cikiyor ve carpan her seferinde (dogruyken de) cevriliyordu.
        if (d > 0) == (sign * A.sign_mul > 0) then
            C.agree = C.agree + 1
        end
        -- V1.0.7 (log 3: isaret +1 iken de -1 iken de "ters" olculdu): ham sayilar. Deger + iken ve - iken
        -- (gercek - sahte) farkinin ortalamasi; ikisi ayni isaretliyse set_desync'in isareti tarafi belirlemiyor.
        if sign > 0 then
            C.pn, C.ps = (C.pn or 0) + 1, (C.ps or 0) + d
        else
            C.nn, C.ns = (C.nn or 0) + 1, (C.ns or 0) + d
        end
        if C.n < 64 then
            return
        end
        N.log.line(fmt("aa: desync olcumu ham: deger + iken fark ort %s (%d ornek), - iken %s (%d ornek), carpan %+d",
            (C.pn or 0) > 0 and fmt("%+.0f", C.ps / C.pn) or "?", C.pn or 0,
            (C.nn or 0) > 0 and fmt("%+.0f", C.ns / C.nn) or "?", C.nn or 0, A.sign_mul))
        C.pn, C.ps, C.nn, C.ns = nil, nil, nil, nil
        local rate = C.agree / C.n
        if rate <= 0.2 then
            A.sign_mul = -A.sign_mul
            C.done = true
            N.log.line(fmt("aa: desync isareti olculdu (+ = %s) [%d/%d ters, cevrildi]", A.sign_mul > 0 and "sag" or "sol",
                C.n - C.agree, C.n))
        elseif rate >= 0.8 then
            C.done = true
            N.log.line(fmt("aa: desync isareti olculdu (+ = %s) [%d/%d uyumlu]", A.sign_mul > 0 and "sag" or "sol",
                C.agree, C.n))
        elseif C.phase == 1 then
            N.log.line(fmt("aa: desync isareti tutarsiz -> set_invert_desync de kullaniliyor [%d/%d uyumlu]", C.agree,
                C.n))
            C.phase, C.invert, C.n, C.agree, C.prev = 2, true, 0, 0, nil
        else
            C.done = true
            N.log.line(fmt("aa: desync isareti ikinci olcumde de tutarsiz (%d/%d), set_invert_desync acik kaldi",
                C.agree, C.n))
        end
    end

    -- Gizli pitch / yaw (sadece kendi defensive tick'lerimizde).
    A.hidden = function(state, base)
        local X = N.ex
        if not X.own_def_active() or X.clean or N.ui.xdef[state] == nil or N.ui.xdef[state].def_mode == nil then
            return nil, nil
        end
        local tick = U.tick()
        local hp = N.xv(state, "hidden_pitch") or 1
        local hy = N.xv(state, "hidden_yaw") or 1
        local pitch, yaw
        if hp == 2 then
            pitch = 89
        elseif hp == 3 then
            pitch = -89
        elseif hp == 4 then
            pitch = 0
        elseif hp == 5 then
            pitch = tick % 2 == 0 and 89 or -89
        elseif hp == 6 then
            pitch = random(-89, 89)
        elseif hp == 7 then
            pitch = N.xv(state, "hidden_pitch_value") or 0
        end
        if hy == 2 then
            yaw = base + (tick % 2 == 0 and 90 or -90)
        elseif hy == 3 then
            A.hspin = (A.hspin + (N.v("hidden_spin") or 10) * 6) % 360
            yaw = base + A.hspin
        elseif hy == 4 then
            yaw = base + random(-180, 180)
        elseif hy == 5 then
            yaw = base
        elseif hy == 6 then
            yaw = base + (N.xv(state, "hidden_yaw_value") or 90)
        end
        if pitch ~= nil or yaw ~= nil then
            X.hidden_tick = tick
        end
        return pitch, yaw
    end

    -- ANTIAIM ana fonksiyonu.
    A.apply = function(ctx, cmd)
        local st = N.st
        local lp = st.lp
        A.applied = 0
        if U.num(lp, "m_MoveType") == 9 then
            st.state, st.label = "Ladder", "Ladder"
            return
        end
        pcall(ctx.set_body_lean, ctx, 0)
        local view = A.view_yaw(cmd)
        local choked = A.choked()

        if A.legit_active(cmd, lp) then
            st.state, st.label = "Legit", "Legit"
            local okp, vx = pcall(function()
                return cmd.viewangles.x
            end)
            if okp and U.finite(vx) then
                pcall(ctx.set_pitch, ctx, vx)
            end
            pcall(ctx.set_yaw, ctx, U.norm(view))
            local side = N.ref.on("inverter")
            A.desync(ctx, side, 60)
            A.last.side, A.last.limit, A.last.body = side, 60, "sta"
            return
        end

        if A.spin_active() then
            st.state, st.label = "Spin", "Spin"
            local cmdn = cmd ~= nil and cmd.command_number or nil
            if cmdn == nil or cmdn ~= A.spin_cmdn then
                A.spin_cmdn = cmdn
                A.spin_angle = (A.spin_angle + (N.v("spin_speed") or 6) * 6) % 360
            end
            if N.v("spin_pitch") == 2 then
                pcall(ctx.set_pitch, ctx, 89)
            end
            pcall(ctx.set_yaw, ctx, U.norm(view + A.spin_angle))
            return
        end

        local state = st.state
        local row = A.row(state)
        local B = N.brute
        local phase_n = 0
        if N.on("anti_brute") and not K.UNLEARNED[state] then
            phase_n = B.stage_for(A.target(), st.move_state)
        end
        A.applied = phase_n
        local phase = phase_n > 0 and K.BRUTE_PHASES[phase_n] or nil
        A.update_flip(cmd, row, phase)
        local a = A.angles(row, phase)

        local base, target = A.base(cmd)
        A.facing = target
        local yaw = nil
        if state == "Manual" then
            yaw = base + 180 + (A.MANUAL[st.manual] or 0) + a.yaw
        else
            local knife, dist = nil, nil
            if N.on("avoid_backstab") then
                knife, dist = A.knife_enemy(250)
            end
            st.backstab = knife
            if knife ~= nil then
                local mine, theirs = U.origin(lp), U.origin(knife)
                if mine ~= nil and theirs ~= nil then
                    yaw = U.yaw_to(mine, theirs)
                    A.facing = knife
                    N.log.every("backstab", 5, fmt("backstab: %s bicakli, %d birimde -> yuz ona", U.name(knife),
                        U.R(dist)))
                end
            elseif state == "Freestanding" and st.fs_own ~= nil then
                yaw = base + 90 * st.fs_own + a.yaw
            elseif state == "Freestanding" then
                yaw = nil
            else
                yaw = base + 180 + a.yaw
            end
        end

        -- Pitch: ayar (Down / Zero / Off), Safe head 89, defensive tick'inde gizli pitch.
        local pitch = nil
        local pm = N.v("pitch") or 1
        if pm == 1 then
            pitch = 89
        elseif pm == 2 then
            pitch = 0
        end
        if state == "Safe head" then
            pitch = 89
        end
        local hp, hy = A.hidden(state, base)
        if hp ~= nil then
            pitch = hp
        end
        if hy ~= nil then
            yaw = hy
        end
        if pitch ~= nil then
            pcall(ctx.set_pitch, ctx, pitch)
        end
        if yaw ~= nil then
            yaw = U.norm(yaw)
            pcall(ctx.set_yaw, ctx, yaw)
            A.last.yaw = yaw
        end

        local value = 0
        if a.body == 4 then
            pcall(ctx.set_desync, ctx, 0)
        else
            local limit = a.side and a.right or a.left
            value = A.desync(ctx, a.side, limit)
            A.last.limit = limit
        end
        A.last.side, A.last.body, A.last.phase = a.side, a.mode, phase_n
        if choked == 0 then
            A.calibrate(value, st.move_state == "Standing")
        end
        -- Fake duck'ta bicakli yakin: script fake duck'i birakamaz, ipucu.
        if st.fd then
            local knife, dist = A.knife_enemy(250)
            if knife ~= nil then
                st.fd_hint_until = U.now() + 2
                N.log.every("fd_knife", 5, fmt("fake duck: %s bicakli, %d birimde -> fake duck'i birak",
                    U.name(knife), U.R(dist)))
            end
        end
    end

    -- A19: egik yururken gorulursen tehdide dogru giden komut "Crouch speed"e kadar kisilir (GS birimi:
    -- egik hareket = komutun 0.34'u).
    A.crouch_keeper = function(cmd)
        local st = N.st
        st.slowed = false
        if not N.on("crouch_cap") or cmd == nil or st.airborne or st.fd or N.peek.mode ~= nil or N.afk.on
            or N.ref.on("autopeek") or U.num(st.lp, "m_MoveType") == 9 then
            return
        end
        if not (N.exposure.now or N.exposure.soon or N.exposure.seen) then
            return
        end
        if U.now() - st.last_shot < 0.6 and U.now() >= st.last_shot then
            return
        end
        local duck = st.duck or 0
        if duck < 0.9 then
            return
        end
        local ok, mx, my = pcall(function()
            return cmd.move.x, cmd.move.y
        end)
        if not ok or not U.finite(mx) or not U.finite(my) then
            return
        end
        local m = sqrt(mx * mx + my * my)
        if m < 1 then
            return
        end
        local threat = st.threat
        local mine, theirs = U.origin(st.lp), threat ~= nil and U.origin(threat) or nil
        if mine == nil or theirs == nil then
            return
        end
        local yaw = A.view_yaw(cmd)
        local cx, sy = U.dir(yaw)
        -- Dunya yonu: ileri (cos, sin), sag (sin, -cos); cmd.move.y pozitif = sag (isaret P2'de olculur).
        local side = my * (N.peek.side_mul or 1)
        local wx = mx * cx + side * sy
        local wy = mx * sy - side * cx
        if wx * (theirs.x - mine.x) + wy * (theirs.y - mine.y) < 0 then
            return
        end
        local lim = (N.v("crouch_speed") or 38) / 0.34
        if m > lim then
            local k = lim / m
            pcall(function()
                cmd.move = vec3_t(mx * k, my * k, 0)
            end)
            st.slowed = true
        end
    end
end

-------------------------------------------------------------------------------
-- Anti-brute: kafamin 40 birim yakinindan gecen dusman mermisi fazi ilerletir; hareket grubu basina faz
-- ogrenmesi (kafa isabeti / mermi), kotu bilinen faz atlanir, dusman basina kalici taban.
-------------------------------------------------------------------------------
do
    local U, B = N.util, N.brute
    local K = N.K
    B.enemies, B.phases, B.default, B.pending, B.hurt = {}, {}, {}, {}, {}
    B.bad_shots, B.bad_rate = 12, 0.55

    -- V1.0.9 faz testi: test[faz] = { n = bana atilan mermi (isabet + iska), h = kafa isabeti, hit = isabet,
    -- rounds = o fazla oynanan round }. Sayaclar yariya inmez, hafizada kalir (T kaydi), oturumlar toplanir.
    B.test, B.round_phase, B.TEST_MIN, B.BEST_SHARE = {}, 0, 40, 0.6

    B.reset_phases = function()
        for _, g in ipairs(K.BRUTE_GROUPS) do
            B.phases[g], B.default[g] = {}, 0
            for phase = 0, #K.BRUTE_PHASES do
                B.phases[g][phase] = { shots = 0, hits = 0 }
            end
        end
        for phase = 0, #K.BRUTE_PHASES do
            B.test[phase] = { n = 0, h = 0, hit = 0, rounds = 0 }
        end
        B.round_phase = 0
    end
    B.reset_phases()

    B.test_on = function()
        return N.on("anti_brute") and N.on("phase_test")
    end

    -- Mermi basina kafa orani (az veride ortalamaya cekilir: 2/6 on bilgi).
    B.test_rate = function(t)
        return (t.h + 2) / (t.n + 6)
    end

    B.test_count = function(phase, head, hit)
        local t = B.test[phase]
        if t == nil then
            return
        end
        t.n = t.n + 1
        if hit then
            t.hit = t.hit + 1
        end
        if head then
            t.h = t.h + 1
        end
        N.mem.dirty = true
    end

    -- "normal 12 mermi kafa %33 iska %50 (4 round) | asym ..."
    B.compare_text = function()
        local parts = {}
        for phase = 0, #K.BRUTE_PHASES do
            local t = B.test[phase]
            parts[#parts + 1] = fmt("%s %d mermi kafa %%%d iska %%%d (%d round)", K.PHASE_NAME[phase], U.R(t.n),
                t.n > 0 and U.R(100 * t.h / t.n) or 0, t.n > 0 and U.R(100 * (t.n - t.hit) / t.n) or 0, U.R(t.rounds))
        end
        return concat(parts, " | ")
    end

    B.compare_line = function()
        local total = 0
        for phase = 0, #K.BRUTE_PHASES do
            total = total + B.test[phase].n
        end
        if total > 0 and N.on("hit_log") then
            N.log.line("faz karsilastirma: " .. B.compare_text())
        end
    end

    -- Yeni round (ya da DM'de yeni can): bu roundun fazi. Her fazda TEST_MIN mermi birikene kadar esit rotasyon (en
    -- az round oynanan faz; esitlikte en az mermi, sonra rastgele); sonra en dusuk kafa oranli faz roundlarin
    -- BEST_SHARE'i, kalan roundlar digerleri arasinda rastgele (rakipler degisirse fark edilsin).
    B.round = function(quiet)
        if not B.test_on() then
            return
        end
        -- Arka arkaya gelen cift round_start tek round sayilir.
        local now = U.now()
        if B.round_at ~= nil and now >= B.round_at and now - B.round_at < 1 then
            return
        end
        B.round_at = now
        local n = #K.BRUTE_PHASES
        local min_n = huge
        for phase = 0, n do
            min_n = min(min_n, B.test[phase].n)
        end
        local pick, mode = 0, "rotasyon"
        if min_n < B.TEST_MIN then
            local cands, best_r, best_n = {}, huge, huge
            for phase = 0, n do
                local t = B.test[phase]
                if t.rounds < best_r or (t.rounds == best_r and t.n < best_n) then
                    cands, best_r, best_n = { phase }, t.rounds, t.n
                elseif t.rounds == best_r and t.n == best_n then
                    cands[#cands + 1] = phase
                end
            end
            pick = cands[random(1, #cands)]
        else
            local best, best_rate = 0, huge
            for phase = 0, n do
                local r = B.test_rate(B.test[phase])
                if r < best_rate - 1e-9 then
                    best, best_rate = phase, r
                end
            end
            if random() < B.BEST_SHARE then
                pick, mode = best, "en iyi"
            else
                pick = random(0, n - 1)
                if pick >= best then
                    pick = pick + 1
                end
                mode = "kontrol"
            end
        end
        B.round_phase = pick
        B.test[pick].rounds = B.test[pick].rounds + 1
        N.aa.flip.kick = nil
        N.mem.dirty = true
        if not quiet and N.on("hit_log") then
            N.log.line(fmt("faz testi: bu round %s (%s) | %s", K.PHASE_NAME[pick], mode, B.compare_text()))
        end
    end

    B.group_for = function(ms)
        return K.GROUP_OF[ms] or "still"
    end

    B.stat_group = function()
        if K.UNLEARNED[N.st.state] then
            return nil
        end
        return B.group_for(N.st.move_state)
    end

    B.phase_rate = function(stat)
        return (stat.hits + 2.4) / (stat.shots + 8)
    end

    B.best_default = function(g)
        local list, current = B.phases[g], B.default[g] or 0
        local best, best_rate = 0, huge
        for phase = 0, #K.BRUTE_PHASES do
            local rate = B.phase_rate(list[phase])
            if rate < best_rate - 1e-9 then
                best, best_rate = phase, rate
            end
        end
        if best ~= current and best_rate < B.phase_rate(list[current]) - 0.1 - 1e-9 then
            return best
        end
        return current
    end

    B.count = function(stat, hit)
        stat.shots = stat.shots + 1
        if hit then
            stat.hits = stat.hits + 1
        end
        if stat.shots > 40 then
            stat.shots, stat.hits = stat.shots / 2, stat.hits / 2
        end
        N.mem.dirty = true
    end

    B.record_phase = function(g, phase, hit)
        local list = g ~= nil and B.phases[g] or nil
        if list == nil or list[phase] == nil then
            return
        end
        B.count(list[phase], hit)
        local previous = B.default[g]
        local best = B.best_default(g)
        if best ~= previous then
            B.default[g] = best
            if N.on("hit_log") then
                local chosen, left = list[best], list[previous]
                N.log.line(fmt("AA (%s): faz %d cok kafa yiyor (%d/%d kafa isabeti) -> verisi olmayan dusmanlara faz %d%s",
                    g, previous, U.R(left.hits), U.R(left.shots), best, chosen.shots < 0.5 and " (denenmemis)" or ""))
            end
        end
    end

    B.known_bad = function(g, phase)
        local list = B.phases[g]
        local stat = list ~= nil and list[phase] or nil
        return stat ~= nil and stat.shots >= B.bad_shots and stat.hits / stat.shots >= B.bad_rate
    end

    -- Siradaki faz: rastgele (su anki haric) ya da +1.
    B.next = function(current, allow_zero)
        local n = #K.BRUTE_PHASES
        if not N.on("brute_random") then
            return allow_zero and (current + 1) % (n + 1) or current % n + 1
        end
        local low = allow_zero and 0 or 1
        local inside = current >= low and current <= n
        local pick = random(low, inside and (n - 1) or n)
        if inside and pick >= current then
            pick = pick + 1
        end
        return pick
    end

    B.skip_bad = function(g, phase)
        for _ = 0, #K.BRUTE_PHASES do
            if not B.known_bad(g, phase) then
                return phase
            end
            phase = (phase + 1) % (#K.BRUTE_PHASES + 1)
        end
        return phase
    end

    B.entry = function(ent)
        local p, key = N.mem.entry(ent)
        if key == nil then
            return nil
        end
        local e = B.enemies[key]
        if e == nil then
            e = { stage = 0, time = -1000, last = -1000, base = p ~= nil and p.base or nil }
            e.learned = e.base ~= nil
            B.enemies[key] = e
        end
        e.mem = p
        return e, key
    end

    B.entry_stage = function(e, g)
        if e == nil then
            return B.default[g] or 0
        end
        local now = U.now()
        local reset = N.v("brute_reset") or 6
        if e.stage > 0 and now >= e.time and now - e.time <= reset then
            return B.skip_bad(g, e.stage)
        end
        if e.learned and e.base ~= nil then
            return B.skip_bad(g, e.base)
        end
        return B.default[g] or 0
    end

    -- AA hedefinin (ya da hedef yoksa grup varsayilaninin) fazi.
    B.stage_for = function(target, ms)
        local g = B.group_for(ms)
        -- V1.0.9: faz testi acikken round boyunca tek faz (hedeften bagimsiz).
        if B.test_on() then
            return B.round_phase
        end
        if target == nil then
            return B.default[g] or 0
        end
        local e = B.entry(target)
        return B.entry_stage(e, g)
    end

    -- bullet_impact: atan dusman, kafama < 40 birim, atan basina 0.1 sn tekrar korumasi.
    B.impact = function(e)
        local st = N.st
        local lp = st.lp
        if lp == nil or not st.alive then
            return
        end
        local okp, shooter = pcall(entity_list.get_player_from_userid, e.userid)
        if not okp or shooter == nil or shooter == lp or not U.is_enemy(shooter) or not U.alive(shooter) then
            return
        end
        local x, y, z = tonumber(e.x), tonumber(e.y), tonumber(e.z)
        if not U.finite(x) or not U.finite(y) or not U.finite(z) then
            return
        end
        local entry, key = B.entry(shooter)
        if entry == nil then
            return
        end
        local now = U.now()
        if now >= entry.last and now - entry.last < K.BRUTE_DEBOUNCE then
            return
        end
        local head, eye = U.hitbox(lp, "HEAD"), U.eye(shooter)
        if head == nil or eye == nil then
            return
        end
        if U.seg_dist(head, eye, { x = x, y = y, z = z }) >= K.BRUTE_RADIUS then
            return
        end
        entry.last = now
        entry.counted = nil
        local idx = U.index(shooter)
        if idx ~= nil then
            N.track.get(idx).shot_us = now
        end
        local g = B.stat_group()
        local testing = B.test_on()
        local shot_stage = N.on("anti_brute") and (testing and B.round_phase
            or B.entry_stage(entry, g or B.group_for(st.move_state))) or 0
        entry.shot_stage, entry.shot_applied, entry.shot_group = shot_stage, N.aa.applied, g
        -- atis-sonrasi fazi: mermi yanimdan gecti -> siradaki pakette taraf cevrilir, ritim karilir.
        local ph = K.BRUTE_PHASES[N.aa.applied]
        if ph ~= nil and ph.kick then
            N.aa.flip.kick = true
        end
        local hurt = B.hurt[e.userid]
        if hurt == nil or now < hurt or now - hurt >= K.MISS_WINDOW then
            B.pending[#B.pending + 1] = {
                userid = e.userid, time = now, state = st.label, stage = shot_stage, applied = N.aa.applied,
                group = g, name = U.name(shooter), aa = N.shots.aa_status(), exploit = N.shots.exploit_status(),
                weapon = U.wlabel(st.weapon), attacker = N.shots.attacker_info(shooter),
                enemy_weapon = (U.winfo(shooter) or { name = "?" }).name,
            }
        end
        if not N.on("anti_brute") or testing then
            return
        end
        entry.stage = B.next(shot_stage, false)
        entry.time = now
        if N.on("brute_log") then
            N.log.line(fmt("anti-brute: %s faz %d", U.name(shooter), entry.stage))
        end
    end

    -- 0.15 sn icinde hasar gelmeyen mermi = iska.
    B.process_pending = function()
        local now = U.now()
        for i = #B.pending, 1, -1 do
            local m = B.pending[i]
            if now < m.time or now - m.time > K.MISS_WINDOW then
                tremove(B.pending, i)
                if now >= m.time then
                    N.stats.enemy_miss(m.state)
                    if m.group ~= nil then
                        B.record_phase(m.group, m.applied, false)
                        B.test_count(m.applied, false, false)
                    end
                    if N.on("hit_log") then
                        N.log.line(fmt("iska: %s | faz %d%s | %s | %s | %s | %s (%s) | silah %s", m.state, m.applied,
                            m.applied ~= m.stage and fmt(" (dusmanin %d)", m.stage) or "", m.aa, m.exploit, m.weapon,
                            m.name, m.attacker, tostring(m.enemy_weapon)))
                    end
                end
            end
        end
    end

    -- Bana isabet: eslesen mermi varsa uygulanan faz ogrenilir; kafa isabeti dusmanin tabanini tasir.
    B.hurt_us = function(e, attacker, hitgroup)
        local now = U.now()
        B.hurt[e.attacker] = now
        for i = #B.pending, 1, -1 do
            if B.pending[i].userid == e.attacker then
                tremove(B.pending, i)
            end
        end
        local entry = B.entry(attacker)
        local phase, g, matched
        if entry ~= nil and entry.shot_applied ~= nil and now >= entry.last and now - entry.last < K.MISS_WINDOW then
            matched = true
            phase, g = entry.shot_applied, entry.shot_group
        else
            phase, g = N.aa.applied, B.stat_group()
        end
        local weapon = tostring(e.weapon or "?")
        local melee = weapon:find("knife", 1, true) ~= nil or weapon == "bayonet" or weapon == "taser"
        if hitgroup == 1 and not melee and N.on("anti_brute") and not B.test_on() and not K.UNLEARNED[N.st.state]
            and entry ~= nil then
            entry.base, entry.learned = B.next(phase or 0, true), true
            if entry.mem ~= nil then
                entry.mem.base = entry.base
                N.mem.dirty = true
            end
        end
        if not melee and g ~= nil and hitgroup ~= 0 then
            B.test_count(phase or 0, hitgroup == 1, true)
        end
        if not melee and g ~= nil then
            if hitgroup == 1 then
                B.record_phase(g, phase or 0, true)
                if matched then
                    entry.counted = true
                end
            elseif matched and not entry.counted and hitgroup ~= 0 then
                entry.counted = true
                B.record_phase(g, phase or 0, false)
            end
        end
        return phase or 0, melee
    end
end

-------------------------------------------------------------------------------
-- Exploitler: defensive karari (Off / On peek / Smart / Always on / Tick based), re-arm cooldown, anti-peek,
-- silah degisimi / bicak, havada air lag, temiz atis, havada teleport + Air LC, teleport sonucu, safe
-- recharge, bozuk atis korumasi, fakelag.
-------------------------------------------------------------------------------
do
    local U, X = N.util, N.ex
    X.has_shift = false
    X.shift_tick, X.own_def_until, X.last_sim, X.def_was, X.def_end = -1, -1, nil, false, -1000
    X.forced, X.forced_tick, X.scan_tick, X.anti_until, X.smart_hold = false, -1000, -1000, -1000, -1000
    X.clean, X.shot_tick, X.after_shot = false, -1000, false
    X.hidden_tick = -1000
    -- A1 (def_edge): zorlanan defensive bir OLAY (tick basina durum degil). shift_last: son basarili zorlamanin
    -- tick'i; want_prev: sebep basina tetik kosulu onceki tick'te dogru muydu (yukselen kenar); scan_start: HITSCAN
    -- tarama dizisinin basladigi tick (16 tick'ten uzun aradan sonra); GAP: sebep basina iki zorlama arasi en az tick
    -- (air: ucus basina bir, tick: max(14, def_ticks)).
    X.shift_last, X.want_prev, X.scan_start = -1000, {}, -1000
    X.GAP = { smart = 64, peek = 48, switch = 64, knife = 32, aipeek = 48, afk = 64, always = 64 }
    X.switch = { name = nil, at = -1000 }
    -- flight_tp: bu ucustaki teleport sayisi (bekci); c0 / cmin: teleport oncesi sarj ve sonraki en dusuk sarj (G26).
    X.air = { was_air = false, used = false, latched = false, takeoff_z = 0, left = 0, calls = 0, maxchoke = 0,
        pending_log = false, map_logged = false, flight_tp = 0, c0 = 0, cmin = 0 }
    -- session_off: force_uncharge sarji 3 kez harcamadi -> bu oturum havada / inis teleportu yok.
    X.tp = { list = {}, map_off = false, session_off = false, n = 0, last = -1000 }
    -- paused[lag] = bitis zamani, plen[lag] = sure (bozuk atis 10 sn, sunucu reddi 300 sn).
    X.broken = { DEF = {}, LC = {}, TP = {}, paused = {}, plen = {} }
    X.safe = { holding = false, since = -1000, want_at = -1000, no_hold = nil, handled_at = -1000 }
    X.dt_warn_round = -1
    X.aim = { target = nil, time = -1000 }

    X.init = function()
        -- API §16.4: sadece uyeye bakilir (namespace userdata da olabilir; fonksiyon ya da cagrilabilir userdata).
        local ok, f = pcall(function()
            return exploits.force_anti_exploit_shift
        end)
        X.has_shift = ok and f ~= nil and f ~= false
    end

    -- NET_UPDATE: kendi simulasyon zamanimiz geri gittiyse defensive acik (MS:1262-1290).
    X.own_update = function()
        local lp = N.st.lp
        local simt = U.num(lp, "m_flSimulationTime")
        if simt == nil then
            return
        end
        local okt, sim = pcall(client.time_to_ticks, simt)
        if not okt or not U.finite(sim) then
            sim = floor(simt / U.ipt() + 0.5)
        end
        local tick = U.tick()
        if X.last_sim ~= nil and sim < X.last_sim then
            X.own_def_until = tick + min(16, X.last_sim - sim)
        end
        X.last_sim = sim
    end

    X.own_def_active = function()
        local tick = U.tick()
        return tick <= X.own_def_until and tick >= X.own_def_until - 20
    end

    X.paused = function(lag)
        local untilt = X.broken.paused[lag]
        local now = U.now()
        return untilt ~= nil and now < untilt and now >= untilt - (X.broken.plen[lag] or 10)
    end

    -- Havada / inis teleportu bu harita (son 3'un 2'si vuruldu) ya da bu oturum (sarj harcanmadi) kapali.
    X.tp_off = function()
        return X.tp.map_off or X.tp.session_off
    end

    -- Tek tetik: tick basina en fazla bir force_anti_exploit_shift (sadece DT dolu iken).
    X.shift = function(why)
        local tick = U.tick()
        if X.shift_tick == tick then
            return true
        end
        if not X.has_shift or X.paused("DEF") then
            return false
        end
        if not N.ref.on("dt") then
            X.dt_warning()
            return false
        end
        -- DT'li ucusta (inis teleportu) defensive zorlanmaz: sarj teleporta kalir (GS V1.0.80 current.air_dt).
        if not N.ref.dt_ready() or X.clean or N.st.fd or X.air.latched or X.land.flight then
            return false
        end
        -- Sarj cagridan ONCE okunur (cagri sarji ayni tick'te harcayabilir; log ve sarj izi icin).
        local c, m = N.ref.charge()
        local ok = pcall(exploits.force_anti_exploit_shift)
        if ok then
            local streak = tick - X.shift_last == 1
            X.shift_tick, X.forced, X.forced_tick, X.forced_why = tick, true, tick, why
            X.shift_last = tick
            N.charge.forced(why)
            N.charge.shifted(why, tick, streak, c, m)
        end
        return ok
    end

    -- def_edge: son basarili zorlamadan beri en az gap tick gecti mi (tick geri gittiyse evet).
    X.gap_ok = function(tick, gap)
        local since = tick - X.shift_last
        return since < 0 or since >= gap
    end

    X.dt_warning = function()
        local round = N.stats.round_no or 0
        if X.dt_warn_round ~= round then
            X.dt_warn_round = round
            N.log.line("UYARI: DT kapali (cfg'de DT her zaman acik olmali)")
        end
    end

    X.mode_for = function(state)
        if N.ui.xdef[state] == nil or N.ui.xdef[state].def_mode == nil then
            return 1
        end
        return N.xv(state, "def_mode") or 1
    end

    -- Silah degisimi: aktif silah adi son 0.5 sn icinde degisti ya da m_flNextAttack ileride.
    X.switching = function()
        local st = N.st
        local now = U.now()
        local name = st.weapon
        if name ~= X.switch.name then
            if X.switch.name ~= nil then
                X.switch.at = now
            end
            X.switch.name = name
        end
        if now >= X.switch.at and now - X.switch.at <= 0.5 then
            return true
        end
        local nxt = U.num(st.lp, "m_flNextAttack")
        return nxt ~= nil and nxt > U.cur() and nxt - U.cur() < 2
    end

    -- SETUP_COMMAND: defensive karari. "Defensive: one shift per event" (def_edge) acikken X.shift sadece yeni bir
    -- olayda ve sebebin GAP'i dolduysa cagrilir (her tick degil): sarj dolar dolmaz yeniden zorlamak "shift, dolum
    -- beklemesi, shift" dongusune giriyordu (duello tick'lerinin %26'si, saniyede 0.8 zorlama, her birinde takilma).
    --   smart : (su an goruluyor ya da goruldu) yukselen kenari; sadece "yakin" artik TETIKLEMEZ.        GAP 64
    --   peek  : yeni dusmanin ilk gorusu (2 tick), tarama dizisinin basi, hizli dusman yukselen kenari.   GAP 48
    --   switch: silah degisiminin yukselen kenari.                                                       GAP 64
    --   knife : bicakli dusman menzildeyken tekrar eder.                                                 GAP 32
    --   air   : ucus basina bir kez (kosulun saglandigi ilk havadaki tick).
    --   aipeek: AI peek yuruyusu basina bir kez.                                                         GAP 48
    --   afk / always: tekrar eder.                                                                       GAP 64
    --   tick  : tekrar eder.                                                              GAP max(14, def_ticks)
    -- Kapaliyken eski davranis aynen (istek surdukce, sarj dolu olan her tick).
    X.defensive = function()
        local st, E = N.st, N.exposure
        local tick = U.tick()
        local now = U.now()
        local P = X.want_prev
        X.forced = X.forced_tick == tick
        -- Kendi defensive bitis zamani (re-arm cooldown icin).
        local def = X.own_def_active()
        if X.def_was and not def then
            X.def_end = now
        end
        X.def_was = def
        if not X.has_shift then
            return
        end
        local state = st.state
        local mode = X.mode_for(state)
        local switching = X.switching()
        local knife = N.on("backstab_def") and N.on("avoid_backstab") and N.aa.knife_enemy(250) ~= nil
        if E.now then
            X.smart_hold = tick + 8
        end
        -- X5: yeni goren dusman (ilk gorus) ya da goren dusman hizli -> 8 tick zorla.
        local fast, first = false, false
        if N.on("anti_peek") then
            for _, enemy in ipairs(E.enemies()) do
                local idx = U.index(enemy)
                if idx ~= nil and E.sees_now(idx) and U.speed(enemy) > 150 then
                    fast = true
                end
            end
            first = E.first_sight_within(2)
            if first or fast then
                X.anti_until = tick + 8
            end
        end
        local anti = tick <= X.anti_until and tick >= X.anti_until - 8
        local onpeek = (tick - X.scan_tick <= 1 and tick >= X.scan_tick) or anti
        local want, why = false, nil
        local every = 14
        if mode == 2 then
            want, why = onpeek, "peek"
        elseif mode == 3 then
            if onpeek then
                want, why = true, "peek"
            elseif N.on("smart_force") and (E.now or E.seen or E.near
                or (tick <= X.smart_hold and tick >= X.smart_hold - 8)) then
                want, why = true, "smart"
                -- X4: defensive bittikten sonra gorulurken 1 sn yeniden zorlama yok (DT dolsun).
                if N.on("def_cooldown") and E.seen and now >= X.def_end and now - X.def_end < 1
                    and not st.airborne and N.peek.mode == nil and not switching and not knife and not N.afk.on then
                    want = false
                end
            end
        elseif mode == 4 then
            want, why = true, "always"
        elseif mode == 5 then
            every = max(2, floor(N.xv(state, "def_ticks") or 14))
            want, why = tick % every == 0, "tick"
        end
        if mode ~= 1 then
            if N.on("switch_def") and switching then
                want, why = true, "switch"
            end
            if knife then
                want, why = true, "knife"
            end
        end
        -- X14 (GS: air_lag sadece Smart penceresini genisletir): havada, gorulmuyorken her tick; gorulurken havayi
        -- Air LC yonetir; DT'li ucusta (inis teleportu) ve merdivende yok.
        local air = mode == 3 and N.on("air_lag") and st.airborne and not st.ladder and not X.land.flight
            and not (E.now or E.soon)
        if air then
            want, why = true, "air"
        end
        local walk = N.on("peek_defensive") and N.peek.mode == "walk"
        if walk then
            want, why = true, "aipeek"
        end
        if N.afk.on then
            want, why = true, "afk"
        end
        -- A1: olay kapisi (def_edge). Kenarlar her tick guncellenir (istek olmasa da, baska sebep oncelikli olsa da).
        local seen = E.now or E.seen
        if want and N.on("def_edge") then
            local fresh, gap = true, X.GAP[why] or 0
            -- V1.0.10 (istek: "def az kullaniyor"; log 3-4: shift sarji harcamiyor, takilma her tick cagirmaktan):
            -- gorulme surerken "def_repeat" tick'te bir yeniden (varsayilan 16 = defensive dongusu basina bir);
            -- 0 = olay basina bir kez.
            local rep_t = floor(N.v("def_repeat") or 0)
            if why == "smart" then
                fresh = seen and not P.smart
                if rep_t > 0 and seen then
                    fresh, gap = true, rep_t
                end
            elseif why == "peek" then
                fresh = first or (fast and not P.fast) or (tick >= X.scan_start and tick - X.scan_start <= 1)
                if rep_t > 0 and seen then
                    fresh, gap = true, min(gap, rep_t)
                end
            elseif why == "switch" then
                fresh = not P.switch
            elseif why == "air" then
                fresh = not P.air
            elseif why == "aipeek" then
                fresh = not P.aipeek
            elseif why == "tick" then
                gap = max(14, every)
            end
            if not fresh or not X.gap_ok(tick, gap) then
                want = false
                -- Istek var ama olay yok: "DT kapali" uyarisi yine round basina bir kez (X.shift'e gidilmedigi icin).
                if not X.paused("DEF") and not N.ref.on("dt") then
                    X.dt_warning()
                end
            end
        end
        P.smart, P.fast, P.switch, P.aipeek = seen, fast, switching, walk
        if not st.airborne then
            P.air = false
        elseif air then
            P.air = true
        end
        if want then
            X.shift(why)
        end
    end

    -- HITSCAN: ragebot bir hedefi tariyor = peek (MS:4374). def_edge acikken sadece tarama dizisinin basinda (16
    -- tick'ten uzun aradan sonraki ilk tarama) ve peek GAP'i dolduysa zorlanir.
    X.onpeek_trigger = function()
        local tick = U.tick()
        if tick - X.scan_tick > 16 or tick < X.scan_tick then
            X.scan_start = tick
        end
        X.scan_tick = tick
        local mode = X.mode_for(N.st.state)
        if mode == 2 or mode == 3 then
            if N.on("def_edge") then
                -- Tarama dizisinin basi (olay) ya da gorulurken def_repeat tick'te bir.
                local rep_t = floor(N.v("def_repeat") or 0)
                local E = N.exposure
                local again = rep_t > 0 and (E.now or E.seen) and X.gap_ok(tick, rep_t)
                if not again and (X.scan_start ~= tick or not X.gap_ok(tick, X.GAP.peek)) then
                    return
                end
            end
            X.shift("peek")
        end
    end

    -- X8: silah hazir ve hedefin kafasina / gogsune / midesine yeterli mermi geciyor = temiz atis (lag yok).
    X.clean_update = function()
        local st = N.st
        local tick = U.tick()
        X.clean = false
        if not N.on("clean_shot") then
            return
        end
        if tick - X.shot_tick <= 6 and tick >= X.shot_tick then
            X.clean, X.clean_src = true, "atis"
            return
        end
        if st.fd or not U.is_gun(st.winfo) then
            return
        end
        local can = U.call(client.can_fire)
        if can ~= true then
            return
        end
        local now = U.now()
        local target = X.aim.target
        if target ~= nil and (now < X.aim.time or now - X.aim.time > N.K.AIM_TARGET_HOLD) then
            X.aim = { target = nil, time = -1000 }
            target = nil
        end
        if target == nil or not U.alive(target) then
            target = st.threat
        end
        if target == nil then
            return
        end
        local eye = U.eye(st.lp)
        local hp = U.hp(target)
        local need = N.ref.md_need(hp, st.wgroup) or hp
        local head = U.hitbox(target, "HEAD")
        if eye == nil or head == nil then
            return
        end
        local yaw = U.yaw_to(eye, head) + 90
        local points = { head, U.offset(head, yaw, 3, 0), U.offset(head, yaw, -3, 0), U.hitbox(target, "CHEST"),
            U.hitbox(target, "PELVIS") }
        for _, p in ipairs(points) do
            if p ~= nil and U.tdmg(eye, p, st.lp, target) >= need then
                X.clean, X.clean_src = true, "iz"
                X.clean_target = target
                return
            end
        end
    end

    -- ANTIAIM: temiz atista / atistan sonraki ilk ANTIAIM'de paket hemen; havada Air LC'de tam choke.
    X.fakelag = function(ctx)
        if X.clean or X.after_shot then
            X.after_shot = false
            pcall(ctx.set_fakelag, ctx, false)
            return
        end
        if X.air.latched and N.st.airborne and not N.st.ladder then
            pcall(ctx.set_fakelag, ctx, true)
        end
    end

    X.time_to_land = function(lp)
        local o = U.origin(lp)
        if o == nil then
            return 0
        end
        local v = U.vel(lp)
        local g = 800
        local okc, c = pcall(function()
            return cvars.sv_gravity
        end)
        if okc and c ~= nil then
            local okg, gv = pcall(c.get_float, c)
            if okg and U.finite(gv) and gv > 0 then
                g = gv
            end
        end
        local h = o.z - X.air.takeoff_z
        local disc = v.z * v.z + 2 * g * h
        if disc < 0 then
            return 0
        end
        return max(0, (v.z + sqrt(disc)) / g)
    end

    -- Ucus basina tek teleport (GS teleport.count bekcisi): ikinci deneme engellenir ve yazilir (hic olmamali).
    X.tp_guard = function()
        local A = X.air
        if A.flight_tp < 1 then
            return true
        end
        A.flight_tp = A.flight_tp + 1
        N.log.line(fmt("teleport: bu ziplamada %d kez (ikinci teleport engellendi)", A.flight_tp))
        return false
    end

    X.do_teleport = function(kind)
        local A = X.air
        if not X.tp_guard() then
            A.used = true
            return false
        end
        A.flight_tp = 1
        A.c0 = N.ref.charge()
        A.cmin = A.c0
        U.call(exploits.force_uncharge)
        A.used, A.left, A.calls, A.pending_log, A.fire_tick = true, 3, 1, true, U.tick()
        -- Inis teleportunda kilit yok: sarj yerde zaten dolacak (GS V1.0.80 recharge.decide).
        if kind ~= "inis" then
            N.rc.block("air")
        end
        local T = X.tp
        T.n, T.last = T.n + 1, U.now()
        T.kind = kind
        T.list[#T.list + 1] = { time = T.last, hit = false, done = false }
        while #T.list > 3 do
            tremove(T.list, 1)
        end
        N.charge.on_teleport()
        X.finish_uncharge(false)
        return true
    end

    -- Sarj 0 olana kadar (en fazla 4 cagri, tick basina bir) force_uncharge; bitince tek satir ve G26 dogrulamasi
    -- (N.charge). Inis teleportu X.land_update'ten X.air_update'in bekleyen blogundan once atilir: atis tick'inde
    -- ikinci cagri yapilmaz (G26 "N cagrida" ve "harcanmadi" penceresi tick sayar).
    X.finish_uncharge = function(continue)
        local A = X.air
        if not A.pending_log or (continue and A.fire_tick == U.tick()) then
            return
        end
        local c, m = N.ref.charge()
        A.cmin = min(A.cmin, c)
        if continue and c > 0 and A.left > 0 then
            U.call(exploits.force_uncharge)
            A.left, A.calls = A.left - 1, A.calls + 1
            return
        end
        if c > 0 and A.left > 0 and not continue then
            return
        end
        A.pending_log = false
        A.left = 0
        if X.tp.kind == "inis" then
            N.log.line(fmt("teleport: inis teleportu bitti (%d. kez, uncharge %d tick)", X.tp.n, A.calls))
        else
            N.log.line(fmt("teleport: havada goruldun, DT ile isinlanildi (%d. kez, uncharge %d tick%s)", X.tp.n,
                A.calls, X.tp.kind == "lc" and ", air lc" or ""))
        end
        N.charge.uncharge_done(A.calls, A.c0, A.cmin, c, m)
    end

    -- V1.0.80 (GS teleport.plan / land_fire): "Teleport in air" + "Air: break LC" acik ve DT acikken havada DT hic
    -- bosaltilmaz, Air LC kilidi yok; sarj inise saklanir ve tek teleport inise 1..(max sarj - 3) tick kala atilir
    -- (yedek: yerde 1. tick), boylece teleport seni dogrudan yere indirir. Teleport tick'inde ve sonraki 2 tick'te
    -- ziplama bastirilir. Ucusta (kalkistan yerde 2. tick'e kadar) defensive zorlanmaz. Biri kapaliyken eski yol (X10/X11).
    -- fired_at / fire_lt: inis teleportunun tick'i ve o anki inis tahmini; res: sonucu (ilk paket, yere degme,
    -- sapma, tekrar ziplama; N.charge.land_flush yazar); pred: bu ucusun inis tahmini (16 tick kala ilk tahmin).
    X.land = { policy = false, flight = false, fired = false, gt = 64, lt = nil, h = nil, seen_at = -1000,
        seen_flight = false, nojump_until = -1000, reason = nil, margin = 3, seen_hold = 24, min_d3 = 64,
        fired_at = -1000, fire_lt = nil, res = nil, pred = nil }
    X.CORNERS = { 0, 0, 15, 15, 15, -15, -15, 15, -15, -15 }

    X.land_reset = function()
        local L = X.land
        L.flight, L.fired, L.gt, L.lt, L.h, L.reason = false, false, 64, nil, nil, nil
        L.seen_at, L.seen_flight, L.nojump_until = -1000, false, -1000
        L.fired_at, L.fire_lt, L.res, L.pred = -1000, nil, nil, nil
        X.air.flight_tp = 0
    end

    X.gravity = function()
        local okc, c = pcall(function()
            return cvars.sv_gravity
        end)
        if okc and c ~= nil then
            local okg, gv = pcall(c.get_float, c)
            if okg and U.finite(gv) and gv > 0 then
                return gv
            end
        end
        return 800
    end

    -- (x, y) altindaki en yuksek zemin: 5 dikey trace.line (orta + 15 birim koseler); hic carpmazsa nil.
    X.floor_at = function(lp, x, y, top, bottom)
        local best, c = nil, X.CORNERS
        for i = 1, #c, 2 do
            local f = U.tline(vec3_t(x + c[i], y + c[i + 1], top), vec3_t(x + c[i], y + c[i + 1], bottom), lp)
            if f > 0 and f < 1 then
                local hz = top - (top - bottom) * f
                if best == nil or hz > best then
                    best = hz
                end
            end
        end
        return best
    end

    X.fall_ticks = function(oz, vz, fz, g, ti)
        local h = max(0, oz - fz - 2)
        local t = (vz + sqrt(max(0, vz * vz + 2 * g * h))) / g
        return max(0, math.ceil(t / ti - 1e-3)), h
    end

    -- Inise kac tick kaldi ve dusulecek yukseklik; 32 tick'ten az kaldiysa inis noktasinin altina da bakilir (orada
    -- zemin yoksa = ucurum, tahmin yok). nil = bilinmiyor.
    X.land_ticks = function(lp)
        local o = U.origin(lp)
        if o == nil then
            return nil
        end
        local v = U.vel(lp)
        local g, ti = X.gravity(), U.ipt()
        local top = o.z + 2 + (v.z > 0 and v.z * v.z / (2 * g) or 0)
        local bottom = o.z - 512
        local fz = X.floor_at(lp, o.x, o.y, top, bottom)
        if fz == nil then
            return nil
        end
        local k, h = X.fall_ticks(o.z, v.z, fz, g, ti)
        if k <= 32 then
            local fz2 = X.floor_at(lp, o.x + v.x * k * ti, o.y + v.y * k * ti, top, bottom)
            if fz2 == nil then
                return nil
            end
            k, h = X.fall_ticks(o.z, v.z, fz2, g, ti)
        end
        return k, h
    end

    -- Tek inis teleportu. Sira: pencere / gorulme / temiz atis / durdurma / sarj / 3D mesafe.
    X.land_fire = function(cmd, lp, lt, h)
        local L, E = X.land, N.exposure
        if L.fired then
            return
        end
        local c, m = N.ref.charge()
        local S = max(1, m)
        local eligible = (L.gt == 0 and lt ~= nil and lt >= 1 and lt <= S - L.margin) or L.gt == 1
        if not eligible then
            if lt == nil and L.gt == 0 then
                L.reason = "tahmin yok"
            end
            return
        end
        local tick = U.tick()
        local since = tick - L.seen_at
        if not (E.now or E.soon or (since >= 0 and since <= L.seen_hold)) then
            L.reason = "gorulmedi"
            return
        end
        if X.clean then
            L.reason = "temiz atis"
            return
        end
        if X.paused("TP") or X.tp_off() then
            L.reason = "durduruldu"
            return
        end
        if not N.ref.on("dt") or c < 1 then
            L.reason = fmt("sarj %d/%d", U.R(c), U.R(m))
            return
        end
        local d2 = U.speed(lp) * (S + 1) * U.ipt()
        local hz = h or 0
        local d3 = sqrt(d2 * d2 + hz * hz)
        if d3 < L.min_d3 then
            L.reason = fmt("yavas 3D %d u", U.R(d3))
            return
        end
        L.fired, L.reason = true, nil
        if not X.tp_guard() then
            return
        end
        L.nojump_until = tick + 2
        if cmd ~= nil then
            pcall(cmd.remove_button, cmd, e_cmd_buttons.JUMP)
        end
        local left = L.gt == 1 and 0 or lt
        L.fired_at, L.fire_lt, L.res = tick, left, { sent = nil, ground_tick = nil, err = nil, rejump = false }
        N.log.line(fmt("teleport: inise %d tick kala (S %d, hiz %d, 2D %d / 3D %d u, h %d)%s", left, S,
            U.R(U.speed(lp)), U.R(d2), U.R(d3), U.R(hz), d3 > 64 and " LC kirilir(3D)" or ""))
        X.do_teleport("inis")
    end

    -- Her SETUP_COMMAND: politika, gorulme, inis tahmini, inis teleportu. Ucusun sonu (yerde 3. tick ya da bhop'ta
    -- yerde 1-2 tick sonra yeniden kalkis) N.charge.land_flush: teleport sonucu ya da atilmama sebebi (GS V1.0.80).
    X.land_update = function(cmd, lp)
        local L, st, E = X.land, N.st, N.exposure
        local tick = U.tick()
        local nj = L.nojump_until - tick
        if cmd ~= nil and nj >= 0 and nj <= 2 then
            pcall(cmd.remove_button, cmd, e_cmd_buttons.JUMP)
        end
        if E.now or E.soon then
            L.seen_at = tick
        end
        L.policy = N.on("air_lc") and N.on("air_teleport") and N.ref.on("dt") and not N.afk.on and not st.fd
            and not st.ladder and not X.tp.session_off
        L.lt, L.h = nil, nil
        local grounded = U.flag(lp, "ON_GROUND") ~= false
        if L.res ~= nil and L.res.ground_tick == nil and grounded and tick > L.fired_at then
            L.res.ground_tick = tick
        end
        if grounded or st.ladder then
            L.gt = min(L.gt + 1, 64)
            if L.gt == 1 then
                N.charge.landed(L, tick)
            end
            if L.flight and L.gt == 1 then
                X.land_fire(cmd, lp, nil, 0)
            end
            if L.gt == 3 then
                N.charge.land_flush(L)
                L.flight = false
            end
            return
        end
        if L.gt > 0 then
            -- Kalkis (bhop'ta da yeni ucus): yerde 1-2 tick kalip yeniden havalanmak onceki ucusu bitirir.
            if L.gt < 3 then
                if L.res ~= nil then
                    L.res.rejump = true
                end
                N.charge.land_flush(L)
            end
            L.fired, L.reason, L.seen_flight, L.pred = false, nil, false, nil
            X.air.flight_tp = 0
        end
        L.gt = 0
        L.flight = L.policy
        if not L.flight then
            return
        end
        if E.now or E.soon then
            L.seen_flight = true
        end
        L.lt, L.h = X.land_ticks(lp)
        if L.pred == nil and L.lt ~= nil and L.lt <= 16 then
            L.pred = { target = tick + L.lt, done = false }
        end
        X.land_fire(cmd, lp, L.lt, L.h)
    end

    -- X10 / X11: havada teleport (atlayis basina bir) ve Air LC kilidi (inise kadar sarj yok + tam fakelag).
    -- DT'li ucusta (X.land.flight) ikisi de yok; merdiven hava sayilmaz.
    X.air_update = function(cmd)
        local st, E, A = N.st, N.exposure, X.air
        local lp = st.lp
        X.land_update(cmd, lp)
        if not st.airborne or st.ladder then
            if A.was_air then
                A.was_air = false
                if A.latched and N.on("debug_log") then
                    N.log.line(fmt("dbg air lc: choke max %d", U.R(A.maxchoke)))
                end
                if A.pending_log then
                    A.left = 0
                    X.finish_uncharge(false)
                end
                A.used, A.latched, A.left = false, false, 0
                N.rc.allow("air")
            elseif A.pending_log then
                -- Yerde 1. tick yedek inis teleportu: tekrar cagrilar yerde de surer.
                X.finish_uncharge(true)
            end
            return
        end
        if not A.was_air then
            A.was_air = true
            local o = U.origin(lp)
            A.takeoff_z = o ~= nil and o.z or 0
            A.used, A.latched, A.maxchoke, A.calls = false, false, 0, 0
        end
        A.maxchoke = max(A.maxchoke, N.aa.choked())
        if A.pending_log then
            X.finish_uncharge(true)
        end
        if X.land.flight then
            if A.latched then
                A.latched = false
                N.rc.allow("air")
            end
            return
        end
        local seen = E.now or E.soon
        local blocked = X.clean or st.fd or st.melee == "knife" or X.tp_off()
        local tp_ok = not A.used and N.ref.on("dt") and N.ref.charge() > 0 and not blocked and not X.paused("TP")
            and X.time_to_land(lp) >= 0.35
        if N.on("air_lc") and not A.latched and seen and not X.clean and not X.paused("LC") then
            if X.tp_off() then
                if not A.map_logged then
                    A.map_logged = true
                    N.log.line(fmt("air lc: bu %s teleport kapali -> air lc yok", X.tp.session_off and "oturum" or "harita"))
                end
            else
                A.latched = true
                if tp_ok then
                    X.do_teleport("lc")
                end
                N.rc.block("air")
            end
        elseif N.on("air_teleport") and seen and tp_ok and N.ref.dt_ready() then
            X.do_teleport("tp")
        end
        if A.latched then
            N.rc.block("air")
        end
    end

    -- X12: teleporttan 0.12-1.5 sn sonra vurulduysan "vuruldu"; haritada son 3'un 2'si -> harita boyunca kapali.
    X.tp_hurt = function(hitgroup)
        local now = U.now()
        local T = X.tp
        for _, item in ipairs(T.list) do
            local dt = now - item.time
            if not item.done and dt >= 0.12 and dt <= 1.5 then
                item.hit, item.done = true, true
                N.log.line(fmt("teleport sonucu: %.2f sn sonra vuruldun (%s)", dt, N.K.HITGROUPS[hitgroup] or "?"))
            end
        end
        X.tp_check()
    end

    X.tp_check = function()
        local now = U.now()
        local T = X.tp
        local hits, done = 0, 0
        for _, item in ipairs(T.list) do
            if not item.done and now - item.time > 1.5 then
                item.done = true
                if N.on("debug_log") then
                    N.log.line("teleport sonucu: 1.5 sn icinde vurulmadin")
                end
            end
            if item.done then
                done = done + 1
                if item.hit then
                    hits = hits + 1
                end
            end
        end
        if not T.map_off and hits >= 2 and done >= 2 then
            T.map_off = true
            N.log.line("teleport: son 3 isinlanmanin 2'sinde hemen vuruldun, bu harita boyunca havada teleport kapali")
        end
    end

    -- Harita / oturum degisimi: tickcount bastan baslar, tick'e bagli her sey silinir.
    X.tp_reset = function()
        X.tp.list, X.tp.map_off = {}, false
        X.air.map_logged = false
        X.shift_tick, X.own_def_until, X.last_sim = -1, -1, nil
        X.forced_tick, X.scan_tick, X.anti_until, X.smart_hold, X.shot_tick = -1000, -1000, -1000, -1000, -1000
        X.shift_last, X.want_prev, X.scan_start = -1000, {}, -1000
        X.def_end, X.def_was = -1000, false
        X.aim = { target = nil, time = -1000 }
        X.land_reset()
    end

    -- X9: atistan sonra gorulurken en fazla 0.5 sn sarj bekletilir (sarj olurken sunucuda donarsin).
    X.safe_reason = function()
        local st, E = N.st, N.exposure
        local ms = st.move_state
        if ms == "Peek" and not st.crouch then
            return "peek"
        end
        if (ms == "Crouch move" or (ms == "Peek" and st.crouch)) and not N.on("crouch_recharge") then
            return "egik"
        end
        if (st.speed or 0) > 100 then
            return "hizli"
        end
        if st.airborne then
            return "havada"
        end
        local mine = U.origin(st.lp)
        if mine == nil then
            return nil
        end
        local tick = U.tick()
        for _, enemy in ipairs(E.enemies()) do
            local o = U.origin(enemy)
            local info = U.winfo(enemy)
            local m = U.melee(info)
            if o ~= nil then
                local d = U.dist(o, mine)
                if m == "knife" and d <= 260 then
                    return "bicak yakin"
                end
                if m == "zeus" and d <= 420 and abs(o.z - mine.z) <= 128 then
                    return "zeus yakin"
                end
            end
            if info ~= nil and (info.name == "scar20" or info.name == "g3sg1") then
                local idx = U.index(enemy)
                local t = idx ~= nil and N.track.p[idx] or nil
                local shot_recent = t ~= nil and U.now() - t.shot_us <= 32 * U.ipt() and U.now() >= t.shot_us
                local s = idx ~= nil and E.sight[idx] or nil
                if (s ~= nil and tick - s.last <= 32 and tick >= s.last) or shot_recent then
                    return "oto goruyor"
                end
            end
        end
        return nil
    end

    X.safe_recharge = function()
        local st, E, S = N.st, N.exposure, X.safe
        local now = U.now()
        if not N.on("safe_recharge") then
            if S.holding then
                S.holding = false
                N.rc.allow("safe")
            end
            return
        end
        if S.holding then
            local why = X.safe_reason()
            if not E.seen or now - S.since > 0.5 or now < S.since or why ~= nil then
                S.holding = false
                S.no_hold = why
                N.rc.allow("safe")
            end
            return
        end
        if S.want_at > S.handled_at and now - S.want_at < 0.3 and now >= S.want_at then
            S.handled_at = S.want_at
            if not E.seen then
                return
            end
            local why = X.safe_reason()
            if why ~= nil then
                S.no_hold, S.no_hold_at = why, now
                if why == "bicak yakin" or why == "zeus yakin" or why == "oto goruyor" then
                    N.log.line("sarj bekleme yok: " .. why)
                end
                return
            end
            if N.rc.block("safe") then
                S.holding, S.since, S.no_hold = true, now, nil
            end
        end
    end

    -- X13: kendi lag'imiz sirasinda 10 sn icinde 2 "server rejection" / "prediction error" -> o lag 10 sn durur.
    X.broken_shot = function(reason, tags)
        if reason ~= "server rejection" and reason ~= "prediction error" then
            return
        end
        local now = U.now()
        for _, lag in ipairs({ "DEF", "LC", "TP" }) do
            if tags ~= nil and tags[lag] then
                local list = X.broken[lag]
                list[#list + 1] = now
                while #list > 0 and now - list[1] > 10 do
                    tremove(list, 1)
                end
                if #list >= 2 and not X.paused(lag) then
                    X.broken.paused[lag], X.broken.plen[lag] = now + 10, 10
                    X.broken[lag] = {}
                    N.log.line(fmt("%s 10 sn durduruldu: %s sirasinda 2 atis bozuk gitti (son: %s)", lag, lag, reason))
                end
            end
        end
    end

    -- Atis anindaki lag etiketleri.
    X.tags = function()
        local tags = {}
        local now = U.now()
        if X.clean then
            tags.temiz = true
        end
        if X.own_def_active() or X.forced then
            tags.DEF = true
        end
        if X.air.latched then
            tags.LC = true
        end
        if now - X.tp.last <= 1 and now >= X.tp.last then
            tags.TP = true
        end
        if N.st.fd then
            tags.FD = true
        end
        return tags
    end

    X.tags_text = function(tags)
        local out = ""
        for _, k in ipairs({ "temiz", "LC", "DEF", "TP", "FD" }) do
            if tags[k] then
                out = out .. " " .. k
            end
        end
        return out
    end

    X.reset_life = function()
        X.air.was_air, X.air.used, X.air.latched, X.air.left, X.air.pending_log = false, false, false, 0, false
        X.safe.holding = false
        X.clean, X.after_shot = false, false
        X.last_sim, X.own_def_until = nil, -1
        X.aim = { target = nil, time = -1000 }
        X.land.flight, X.land.fired, X.land.gt, X.land.res, X.land.pred = false, false, 64, nil, nil
        X.air.flight_tp = 0
    end
end

-------------------------------------------------------------------------------
-- Sarj analizi (GS V1.0.36-48, V1.0.80, sniper.reject): DT yarim sarjken nedeni (sh / dtac / defbitti / sarj:),
-- round basina "dbg sen ozeti", inis teleportunun sonucu ve inis tahmini, force_uncharge dogrulamasi (G26: 3 kez
-- harcanmadi -> bu oturum havada teleport yok), sunucu reddi bekcisi (kendi lag'imizla atilan son 4 atisin 3'u 2
-- dusmanda 120 sn icinde "server rejection" -> DEF / LC / TP 5 dk X.paused ile durur; atisa ve Min. damage'e dokunmaz).
-------------------------------------------------------------------------------
do
    local U, CH, X = N.util, N.charge, N.ex
    -- c / m: son okunan sarj; dt_since: DT'nin acildigi an; held_was: onceki tick sarj kilidi tutuluyordu.
    CH.c, CH.m, CH.dt_was, CH.dt_since, CH.held_was = 0, 0, false, -1000, false
    CH.sent = { x = nil, y = 0, z = 0, choked = 0 }
    CH.land = { n = 0, sum = 0, abs = 0 }
    CH.undrained = 0
    CH.rej = { list = {}, until_t = -1000, active = false }
    -- GS V1.0.19 yogunlugu (sniper.REJECT): arka plan ret orani HS %9 / DT %14; "60 sn'de 2" ve daha gevsek kurallar
    -- 3 saatte 4 kez bos yere tetiklendi, bu kural V1.0.10-1.0.17 loglarinin hicbirinde tetiklenmiyor.
    CH.REJECT = { last = 4, need = 3, window = 120, distinct = 2, pause = 300 }
    -- Zorlanan shift'in sarj izi (A1): at / why / c0 = zorlama tick'i, sebebi, o anki sarj; dropped = 3 tick icinde
    -- sarj dustu; undr = bu haritada yazilan "harcamadi" satiri (en fazla 3).
    CH.sw = { on = false, at = -1000, why = "?", c0 = 0, dropped = false, undr = 0 }

    -- Round sayaclari (dbg sen ozeti). def_end_at: son sayilan defensive bitisi (X.def_end).
    CH.round_new = function()
        CH.r = { ticks = 0, dt = 0, forced = 0, switch = 0, knife = 0, seen = 0, both = 0, tp = 0, tp_hit = 0,
            partial = 0, partial_seen = 0, def_ends = 0, def_end_at = X.def_end, top = 0, refill_n = 0, refill_sum = 0 }
        CH.sw.on = false
    end
    CH.round_new()

    -- Sarji gercekten bosaltan / dolduran en yakin sebep: atis (1.5 sn), teleport (1.5 sn), defensive bitisi
    -- (1.5 sn), DT acilisi (3 sn); hicbiri yoksa "?" (GS V1.0.36: sebepsiz yarim sarj da yazilir).
    CH.cause = function(now)
        local best, at = "?", -huge
        local function take(name, t, window)
            local d = now - t
            if d >= 0 and d < window and t > at then
                best, at = name, t
            end
        end
        take("atis", N.st.last_shot, 1.5)
        take("teleport", X.tp.last, 1.5)
        take("def", X.def_end, 1.5)
        take("dtac", CH.dt_since, 3)
        return best
    end

    -- S.exploit_status icin: DT acik ve dolu degilken "sh c/m", "dtac X.XXs" (< 3 sn), "defbitti X.XXs" (< 1.5 sn),
    -- "sarj: <sebep>". Boylece vuruldun / iska / dbg (olum-detay, atis-detay, duello) satirlarinda gorunur.
    CH.status = function(parts, c, m)
        if m <= 0 or c >= m then
            return
        end
        local now = U.now()
        parts[#parts + 1] = fmt("sh %d/%d", U.R(c), U.R(m))
        local on_for = now - CH.dt_since
        if on_for >= 0 and on_for < 3 then
            parts[#parts + 1] = fmt("dtac %.2fs", on_for)
        end
        local de = now - X.def_end
        if de >= 0 and de < 1.5 then
            parts[#parts + 1] = fmt("defbitti %.2fs", de)
        end
        parts[#parts + 1] = "sarj: " .. CH.cause(now)
    end

    -- Gonderilen paket (choke sayaci dustu): ardisik gonderilen kayitlar arasi 2D / 3D mesafe; inis teleportundan
    -- sonraki ilk paket teleport sonucuna yazilir (GS own.aa.sent).
    CH.packet = function(lp, tick)
        local S = CH.sent
        local ch = N.aa.choked()
        if ch == 0 or ch < S.choked then
            local o = U.origin(lp)
            if o ~= nil then
                local L = X.land
                if S.x ~= nil and L.res ~= nil and L.res.sent == nil and tick > L.fired_at then
                    local dx, dy, dz = o.x - S.x, o.y - S.y, o.z - S.z
                    L.res.sent = { d2 = sqrt(dx * dx + dy * dy), d3 = sqrt(dx * dx + dy * dy + dz * dz),
                        ground = U.flag(lp, "ON_GROUND") ~= false }
                end
                S.x, S.y, S.z = o.x, o.y, o.z
            end
        end
        S.choked = ch
    end

    -- SETUP_COMMAND (canliyken, defensive kararindan sonra): DT acilisi, G5, round sayaclari, paket, bekci suresi.
    CH.tick = function()
        local P, E, r = N.ref, N.exposure, CH.r
        local now, tick = U.now(), U.tick()
        local dt = P.on("dt")
        local c, m = P.charge()
        if dt and not CH.dt_was then
            CH.dt_since = now
        end
        CH.dt_was = dt
        local held = N.rc.held()
        if held and CH.held_was and c > CH.c then
            N.diag.g5(CH.c, c)
        end
        CH.held_was, CH.c, CH.m = held, c, m
        CH.shift_watch(tick, c, m)
        r.ticks = r.ticks + 1
        if dt then
            r.dt = r.dt + 1
            r.top = max(r.top, c)
            if c > 0 and c < m then
                r.partial = r.partial + 1
                if E.now then
                    r.partial_seen = r.partial_seen + 1
                end
            end
        end
        if X.own_def_active() then
            r.seen = r.seen + 1
            if tick >= X.forced_tick and tick - X.forced_tick <= 16 then
                r.both = r.both + 1
            end
        end
        if X.def_end ~= r.def_end_at then
            r.def_end_at, r.def_ends = X.def_end, r.def_ends + 1
        end
        CH.packet(N.st.lp, tick)
        CH.reject_tick(now)
    end

    -- X.shift basarili (tick basina bir): zorlanan defensive, silah degisimi / bicak sebebiyle olanlar ayrica.
    CH.forced = function(why)
        local r = CH.r
        r.forced = r.forced + 1
        if why == "switch" then
            r.switch = r.switch + 1
        elseif why == "knife" then
            r.knife = r.knife + 1
        end
    end

    -- X.shift basarili (c / m: cagridan onceki sarj): "def: shift (<sebep>) | sarj c/m" (Detailed log; ardisik
    -- tick'lerdeki tekrar yazilmaz: def_edge kapaliyken her tick zorlanir) ve sarj izlemesi baslar (suren izleme
    -- varsa o devam eder).
    CH.shifted = function(why, tick, streak, c, m)
        local w = CH.sw
        if N.on("debug_log") and not streak then
            N.log.line(fmt("def: shift (%s) | sarj %d/%d", tostring(why), U.R(c), U.R(m)))
        end
        if not w.on then
            w.on, w.at, w.why, w.c0, w.dropped = true, tick, tostring(why), c, false
        end
    end

    -- CH.tick: zorlamadan sonraki 3 tick icinde sarj dustu mu. Dustuyse yeniden dolunca "def: sarj N tick sonra doldu"
    -- (round ortalamasina girer); hic dusmediyse "def: shift sarj harcamadi" (haritada en fazla 3 kez). Oyunda
    -- force_anti_exploit_shift'in sarji harcayip harcamadigini bu iki satir gosterir. 256 tick'te dolmazsa izleme biter.
    CH.shift_watch = function(tick, c, m)
        local w = CH.sw
        if not w.on then
            return
        end
        local age = tick - w.at
        if age < 0 or age > 256 then
            w.on = false
            return
        end
        if not w.dropped then
            if c < w.c0 then
                w.dropped = true
            elseif age >= 3 then
                w.on = false
                if w.undr < 3 and N.on("debug_log") then
                    w.undr = w.undr + 1
                    N.log.line(fmt("def: shift sarj harcamadi (%s)", w.why))
                end
            end
        end
        if w.on and w.dropped and m > 0 and c >= m then
            w.on = false
            CH.r.refill_n, CH.r.refill_sum = CH.r.refill_n + 1, CH.r.refill_sum + age
            if N.on("debug_log") then
                N.log.line(fmt("def: sarj %d tick sonra doldu (%s)", U.R(age), w.why))
            end
        end
    end

    CH.on_teleport = function()
        CH.r.tp = CH.r.tp + 1
    end

    -- Dusman mermisi isabet etti (S.on_hurt): teleporttan sonraki 1.5 sn icinde mi.
    CH.hurt = function()
        local d = U.now() - X.tp.last
        if d >= 0 and d <= 1.5 then
            CH.r.tp_hit = CH.r.tp_hit + 1
        end
    end

    -- Round basinda (N.dlog.round_begin, Detailed log acikken) onceki round'un ozeti (GS 10637 bicimi; GS'e ozgu
    -- tickbase / sarj pozu / LBY alanlari yok).
    CH.round_line = function()
        local r = CH.r
        if r.ticks <= 0 then
            return
        end
        local extra = ""
        if r.switch > 0 or r.knife > 0 then
            extra = fmt(" (silah degisirken %d, bicakli yakinken %d)", r.switch, r.knife)
        end
        local off = X.tp.session_off and " (teleport bu oturum kapali)" or (X.tp.map_off and " (teleport bu harita kapali)"
            or "")
        N.log.line(fmt("dbg sen ozeti: %d tick canli, DT acik %d | defensive zorlanan %d tick%s, gorulen (sim) %d,"
            .. " zorlanip gorulen %d | teleport %d, sonrasi 1.5 sn icinde vurulma %d%s | yarim sarj %d tick (goruluyorken"
            .. " %d), defensive bitisi %d | sarj tavani %d | shift %d, dolum ort %st", r.ticks, r.dt, r.forced, extra, r.seen,
            r.both, r.tp, r.tp_hit, off, r.partial, r.partial_seen, r.def_ends, U.R(r.top), r.forced,
            r.refill_n > 0 and fmt("%.1f", r.refill_sum / r.refill_n) or "?"))
    end

    -- Yerde 1. tick: bu ucusun inis tahmininin sapmasi (|e| <= 64; daha fazlasi = ucus kesildi) ve 10 inis'te bir
    -- "inis tahmini" (GS V1.0.80); inis teleportu atildiysa sapma = inis - (atis + tahmin).
    CH.landed = function(L, tick)
        local p = L.pred
        local e = p ~= nil and tick - p.target or nil
        if e ~= nil and not p.done and abs(e) <= 64 then
            p.done = true
            local S = CH.land
            S.n, S.sum, S.abs = S.n + 1, S.sum + e, S.abs + abs(e)
            if S.n % 10 == 0 and N.on("hit_log") then
                N.log.line(fmt("inis tahmini: %d ziplama, ort %+.1f, mutlak %.1f tick", S.n, S.sum / S.n, S.abs / S.n))
            end
        end
        local res = L.res
        if res ~= nil and tick >= L.fired_at and tick - L.fired_at <= 40 then
            res.err = tick - (L.fired_at + (L.fire_lt or 0))
        end
    end

    -- Ucusun sonu: inis teleportunun sonucu (Hit log) ya da atilmama sebebi; ucus durumu silinir.
    CH.land_flush = function(L)
        local res = L.res
        if res ~= nil then
            if N.on("hit_log") then
                local s = res.sent
                N.log.line(fmt("teleport sonucu: tahmin %d, sapma %s tick, ilk paket 2D %s / 3D %s u, paket yerde %s,"
                    .. " inis tick %s, tekrar ziplama %s", U.R(L.fire_lt or -1),
                    res.err ~= nil and fmt("%+d", U.R(res.err)) or "?", s ~= nil and fmt("%d", U.R(s.d2)) or "?",
                    s ~= nil and fmt("%d", U.R(s.d3)) or "?", s == nil and "?" or (s.ground and "evet" or "hayir"),
                    res.ground_tick ~= nil and fmt("+%d", U.R(res.ground_tick - L.fired_at)) or "yok",
                    res.rejump and "evet" or "hayir"))
            end
        elseif not L.fired and L.seen_flight and L.reason ~= nil then
            N.log.line("teleport: inise yok (" .. L.reason .. ")")
        end
        L.res, L.pred, L.seen_flight, L.reason = nil, nil, false, nil
    end

    -- G26: teleportun force_uncharge cagrilari bitti. Sarj hic dusmediyse "harcanmadi"; oturumda 3 kez -> havada /
    -- inis teleportu bu oturum kapali (Air LC kilidi de yok, X.tp_off).
    CH.uncharge_done = function(calls, c0, cmin, c, m)
        N.diag.unch(calls, c0, cmin)
        if c0 <= 0 or cmin < c0 then
            return
        end
        CH.undrained = CH.undrained + 1
        N.log.line(fmt("teleport: sarj harcanmadi (force_uncharge %d tick, sarj %d/%d)", calls, U.R(c), U.R(m)))
        if CH.undrained >= 3 and not X.tp.session_off then
            X.tp.session_off = true
            N.log.line("teleport: force_uncharge calismiyor -> bu oturum havada teleport kapali")
        end
    end

    -- Atis sonucu (S.on_hit reason nil, S.on_miss): sadece kendi lag'imizla (DEF / LC / TP etiketi) atilan atislar
    -- sayilir (GS de sadece yargilanan kanalin atislarini besler; temiz atistaki ret lag'imizdan olamaz). Son 4'unun
    -- 3'u 120 sn icinde "server rejection" / "prediction error" ve en az 2 farkli dusmanda -> DEF / LC / TP 5 dk durur
    -- (GS sniper.reject). Bekci acikken gelen sonuclar sayilmaz; bitince liste bos baslar (CH.reject_tick).
    CH.shot_result = function(rec, reason)
        local R, Q = CH.rej, CH.REJECT
        local now = U.now()
        local tags = rec.tags or {}
        if R.active or not (tags.DEF or tags.LC or tags.TP) or (reason ~= nil and reason:find("death", 1, true)) then
            return
        end
        local bad = reason == "server rejection" or reason == "prediction error"
        local list = R.list
        list[#list + 1] = { time = now, bad = bad, who = rec.idx or rec.name or "?" }
        while #list > Q.last do
            tremove(list, 1)
        end
        if not bad then
            return
        end
        local count, distinct, seen = 0, 0, {}
        for _, shot in ipairs(list) do
            if shot.bad and now >= shot.time and now - shot.time <= Q.window then
                count = count + 1
                if not seen[shot.who] then
                    seen[shot.who], distinct = true, distinct + 1
                end
            end
        end
        if count < Q.need or distinct < Q.distinct then
            return
        end
        for _, lag in ipairs({ "DEF", "LC", "TP" }) do
            X.broken.paused[lag], X.broken.plen[lag] = now + Q.pause, Q.pause
        end
        R.active, R.until_t = true, now + Q.pause
        N.log.line(fmt("sunucu atislari reddediyor (son %d atisin %d'i, %d dusmanda, son: %s) -> DEF / LC / TP 5 dk kapali",
            #list, count, distinct, reason))
        R.list = {}
    end

    CH.reject_tick = function(now)
        local R = CH.rej
        if R.active and (now >= R.until_t or now < R.until_t - CH.REJECT.pause) then
            R.active, R.list = false, {}
            N.log.line("sunucu reddi: 5 dk doldu, DEF / LC / TP tekrar acik")
        end
    end

    -- Harita degisimi: tick'e bagli round sayaclari ve paket konumu silinir (oturum sayaclari kalir).
    CH.map_reset = function()
        CH.round_new()
        CH.sw.undr = 0
        CH.sent = { x = nil, y = 0, z = 0, choked = 0 }
        CH.held_was = false
    end
end

-------------------------------------------------------------------------------
-- Teshis (SPEC §8 GUESS maddeleri): oyunda belirsiz kalan API davranislari sayilir. Her biri ilk goruldugunde bir
-- kez "teshis: Gn ..." (oturum basina, her zaman acik); harita degisiminde ve kapanista "dbg teshis:" ozeti
-- (Detailed log). Sayaclar dagiticidan (N.cb), U.tdmg / U.tline'dan, atis / iska / HITSCAN / teleport noktalarindan
-- tek cagriyla gelir; kendisi iz atmaz ve hicbir karari degistirmez.
-------------------------------------------------------------------------------
do
    local U, DG = N.util, N.diag
    DG.reasons_seen = {}

    DG.reset = function()
        DG.c = { ticks = 0, ord_n = 0, ord_setup = 0, aa_calls = 0, aa_cmds = 0, aa_max = 0, ht_n = 0, ht_hs = 0,
            unpred_ok = 0, unpred_n = 0, filter = 0, reasons = {}, shots = 0, held = 0, lv_ticks = { 0, 0 },
            lv_shots = { 0, 0 }, g5 = 0, use_aa = 0, use_setup = 0, unch = { 0, 0, 0, 0 }, undrained = 0,
            tr_sum = 0, tr_ticks = 0, tr_max = 0, wake = 0, wake_hurt = 0, wake_wait = 0, g31_open = 0, g31_n = 0 }
        DG.p1 = { id = nil, first = nil, done = true }
        DG.p2 = { tick = nil, first = nil, done = true }
        DG.aa_id, DG.aa_cur, DG.lvt, DG.tr_tick = nil, 0, {}, nil
        DG.trn = 0
    end
    DG.reset()

    -- G-satiri: oturumda bir kez (N.dlog.settle ile ayni anahtar alani).
    DG.settle = function(key, text)
        N.dlog.settle(key, text)
    end

    -- N4 (uyku / dormancy): uyanma (T.wake), uyanmadan sonraki 1 sn icinde vurulma, uyanmadan sonraki 32 tick
    -- icinde baslamayan gercek kayit beklemesi (N1 oncesi burada 14 tick beklenirdi).
    DG.wake = function()
        DG.c.wake = DG.c.wake + 1
    end
    DG.wake_hurt = function()
        DG.c.wake_hurt = DG.c.wake_hurt + 1
    end
    DG.wake_wait = function()
        DG.c.wake_wait = DG.c.wake_wait + 1
    end
    -- G31: dusman gozunden kafama mermi izi 0 dondugunde duz cizgi acik miydi (acik = trace.bullet guvenilmez).
    DG.g31 = function(open)
        DG.c.g31_n = DG.c.g31_n + 1
        if open then
            DG.c.g31_open = DG.c.g31_open + 1
            if not DG.g31_said then
                DG.g31_said = true
                N.log.line("teshis: G31 dusman->ben mermi izi 0 ama duz cizgi acik: goruyor sayildi (iz yedegi calisiyor)")
            end
        end
    end

    -- DG.cb pcall icinde calisir: komut nesnesi bozuksa o cagrinin sayaci atlanir.
    DG.cmdn = function(cmd)
        local v = cmd ~= nil and cmd.command_number or nil
        return U.finite(v) and v or nil
    end

    DG.open = function(key)
        return N.dlog.probe[key] == nil
    end

    DG.use = function(cmd)
        if cmd == nil then
            return false
        end
        local ok, v = pcall(cmd.has_button, cmd, e_cmd_buttons.USE)
        return ok and v == true
    end

    -- Dagitici (C.on sarmalayicisi): her callback cagrisinda bir kez, islemcilerden once.
    DG.cb = function(key, a, b, c)
        if key == "SETUP_COMMAND" then
            DG.setup(a)
        elseif key == "ANTIAIM" then
            DG.antiaim(b, c)
        elseif key == "HITSCAN" or key == "TARGET_SELECTION" then
            DG.order(key)
        end
    end

    -- Iz sayaci: tick degisince onceki tick'in izleri toplanir (PAINT / olay izleri de o tick'e sayilir).
    DG.tick_end = function(tick)
        if DG.tr_tick == tick then
            return
        end
        local c = DG.c
        if DG.tr_tick ~= nil then
            c.tr_sum, c.tr_ticks, c.tr_max = c.tr_sum + DG.trn, c.tr_ticks + 1, max(c.tr_max, DG.trn)
        end
        DG.trn, DG.tr_tick = 0, tick
    end

    -- G1: ayni komut numarasinda SETUP_COMMAND mi ANTIAIM mi once.
    DG.pair = function(which, id)
        if id == nil then
            return
        end
        local P = DG.p1
        if P.id ~= id then
            P.id, P.first, P.done = id, which, false
        elseif not P.done and P.first ~= which then
            P.done = true
            local c = DG.c
            c.ord_n = c.ord_n + 1
            if P.first == "setup" then
                c.ord_setup = c.ord_setup + 1
            end
            DG.settle("G1", fmt("G1 SETUP_COMMAND ANTIAIM'den %s calisiyor", P.first == "setup" and "once" or "sonra"))
        end
    end

    DG.setup = function(cmd)
        local c = DG.c
        DG.tick_end(U.tick())
        if N.st.had_lp then
            c.ticks = c.ticks + 1
        end
        DG.pair("setup", DG.cmdn(cmd))
        if DG.use(cmd) then
            c.use_setup = c.use_setup + 1
            DG.use_s = (DG.use_s or 0) + 1
            if DG.use_s >= 32 and (DG.use_a or 0) == 0 and DG.open("G12") then
                DG.settle("G12", "G12 USE basiliyken ANTIAIM calismiyor (32 komut)")
            end
        end
        if DG.open("G10") and N.ref.items.dt ~= nil then
            DG.settle("G10", fmt("G10 DT tus modu %s", DG.dt_mode()))
        end
    end

    -- G27 (komut basina ANTIAIM), G12 (USE basiliyken), G23 (unpredicted_data:has_player_flag).
    DG.antiaim = function(cmd, unpred)
        local c = DG.c
        local id = DG.cmdn(cmd)
        DG.pair("aa", id)
        c.aa_calls = c.aa_calls + 1
        if id == nil or id ~= DG.aa_id then
            DG.aa_id, DG.aa_cur, c.aa_cmds = id, 0, c.aa_cmds + 1
        end
        DG.aa_cur = DG.aa_cur + 1
        c.aa_max = max(c.aa_max, DG.aa_cur)
        if DG.aa_cur == 2 then
            DG.settle("G27", "G27 ANTIAIM ayni komutta birden fazla calisiyor (komut numarasiyla korunuyor)")
        elseif c.aa_cmds >= 64 and c.aa_max == 1 and DG.open("G27") then
            DG.settle("G27", "G27 ANTIAIM komut basina bir kez (64 komut)")
        end
        if DG.use(cmd) then
            c.use_aa = c.use_aa + 1
            DG.use_a = (DG.use_a or 0) + 1
            DG.settle("G12", "G12 USE basiliyken ANTIAIM calisiyor")
        end
        c.unpred_n = c.unpred_n + 1
        if unpred == nil then
            DG.settle("G23", "G23 ANTIAIM'e unpredicted_data gelmiyor (nil) -> havada sadece entity bayragi ve JUMP")
            return
        end
        local ok, v = pcall(unpred.has_player_flag, unpred, e_player_flags.ON_GROUND)
        if ok and type(v) == "boolean" then
            c.unpred_ok = c.unpred_ok + 1
            DG.settle("G23", "G23 unpredicted_data:has_player_flag calisiyor")
        else
            DG.settle("G23", fmt("G23 unpredicted_data:has_player_flag calismiyor (%s)", ok and type(v) or "hata"))
        end
    end

    -- HITSCAN / TARGET_SELECTION: ayni tick'te hangisi once.
    DG.order = function(key)
        local P = DG.p2
        local tick = U.tick()
        if P.tick ~= tick then
            P.tick, P.first, P.done = tick, key, false
        elseif not P.done and P.first ~= key then
            P.done = true
            local c = DG.c
            c.ht_n = c.ht_n + 1
            if P.first == "HITSCAN" then
                c.ht_hs = c.ht_hs + 1
            end
            DG.settle("HS", fmt("HITSCAN TARGET_SELECTION'dan %s calisiyor", P.first == "HITSCAN" and "once" or "sonra"))
        end
    end

    -- G24: olay filtresi (callbacks.add 3. arguman) yok sayildi, baska ad geldi (sarmalayici zaten atliyor).
    DG.filter = function(want, got)
        DG.c.filter = DG.c.filter + 1
        DG.settle("G24", fmt("G24 olay filtresi yok sayiliyor (%s icin %s geldi; ad kontrolu atliyor)", tostring(want),
            tostring(got):sub(1, 32)))
    end

    -- G17: iska sebebi histogrami; her yeni sebep oturumda bir kez.
    DG.reason = function(reason)
        local r = tostring(reason or "?"):sub(1, 32):gsub("[^%w _%-%(%)]", "?")
        local c = DG.c
        c.reasons[r] = (c.reasons[r] or 0) + 1
        if not DG.reasons_seen[r] then
            DG.reasons_seen[r] = true
            DG.settle("G17:" .. r, fmt("G17 iska sebebi '%s' (ilk kez)", r))
        end
    end

    -- G8 (bekletilen hedefe atis) ve G6 (seviye 1 / 2'de atis sayisi): AIMBOT_SHOOT.
    DG.shot = function(rec)
        local c = DG.c
        c.shots = c.shots + 1
        local held = rec.idx ~= nil and N.rage.hold[rec.idx] or nil
        if held ~= nil then
            c.held = c.held + 1
            DG.settle("G8", fmt("G8 bekletilen hedefe atis geldi (%s, %s bekleme) -> grup kapatma / ignore_target atisi"
                .. " durdurmadi", tostring(rec.name), tostring(held)))
        end
        local lv = rec.sp
        if lv == 1 or lv == 2 then
            c.lv_shots[lv] = c.lv_shots[lv] + 1
        end
    end

    -- G6: HITSCAN'de seviye 1 / 2 ve vurulabilir hedef, hedef basina tick'te bir.
    DG.level = function(idx, level, head, body)
        if (level ~= 1 and level ~= 2) or (head <= 0 and body <= 0) then
            return
        end
        local tick = U.tick()
        if DG.lvt[idx] == tick then
            return
        end
        DG.lvt[idx] = tick
        DG.c.lv_ticks[level] = DG.c.lv_ticks[level] + 1
    end

    -- G5: block_recharge tutulurken sarj artti (N.charge.tick).
    DG.g5 = function(from, to)
        DG.c.g5 = DG.c.g5 + 1
        DG.settle("G5", fmt("G5 block_recharge tutulurken sarj artti (%d -> %d) -> kilit sarji durdurmuyor", U.R(from),
            U.R(to)))
    end

    -- G26: teleport basina force_uncharge cagri sayisi ve sarjin dusup dusmedigi.
    DG.unch = function(calls, c0, cmin)
        local c = DG.c
        local k = max(1, min(4, calls))
        c.unch[k] = c.unch[k] + 1
        if cmin >= c0 then
            c.undrained = c.undrained + 1
            DG.settle("G26", fmt("G26 force_uncharge sarji bosaltmadi (%d cagri, sarj %d)", calls, U.R(cmin)))
        elseif cmin > 0 then
            DG.settle("G26", fmt("G26 force_uncharge sarji %d cagrida kismen bosaltti (%d -> %d)", calls, U.R(c0), U.R(cmin)))
        else
            DG.settle("G26", fmt("G26 force_uncharge sarji %d cagrida bosaltti", calls))
        end
    end

    -- G10: DT tusunun get_mode() degeri (dbg ayarlar ve teshis satirlari).
    DG.dt_mode = function()
        local dt = N.ref.items.dt
        if dt ~= nil then
            local ok, m = pcall(dt.get_mode, dt)
            if ok and U.finite(m) then
                return fmt("%d", U.R(m))
            end
        end
        return "?"
    end

    DG.rate = function(lv)
        local c = DG.c
        local t = c.lv_ticks[lv] * U.ipt()
        return t > 0 and c.lv_shots[lv] / t or 0
    end

    -- Harita sonu / kapanis: "dbg teshis:" (haritada en fazla bir kez: sayaclar sifirlanir, yerel oyuncusuz tick sayilmaz).
    DG.map_end = function()
        local c = DG.c
        if c.ticks > 0 and N.on("debug_log") then
            local hist = {}
            for r, n in pairs(c.reasons) do
                hist[#hist + 1] = { r, n }
            end
            table.sort(hist, function(a, b)
                if a[2] ~= b[2] then
                    return a[2] > b[2]
                end
                return a[1] < b[1]
            end)
            for i, h in ipairs(hist) do
                hist[i] = fmt("%s %d", h[1], h[2])
            end
            local cur = DG.tr_tick ~= nil and 1 or 0
            local trt = c.tr_ticks + cur
            N.log.line(fmt("dbg teshis: siralama setup>aa %d/%d, aa/komut ort %.2f max %d, hitscan>hedef secimi %d/%d,"
                .. " unpred bayrak %d/%d, olay filtresi ihlal %d, iska sebepleri %s (jitter %s), bekleme ihlali %d/%d,"
                .. " seviye2 %.1f atis/sn (%d tick) seviye1 %.1f atis/sn (%d tick), sarj kilitliyken artis %d tick,"
                .. " USE basiliyken aa %d/%d, uncharge tick 1:%d 2:%d 3:%d 4:%d (harcanmadi %d), DT tus modu %s,"
                .. " iz/tick ort %.1f max %d (%d tick), uyanma %d (1 sn icinde vurulma %d, uyaninca bekleme atlandi %d),"
                .. " G31 mermi izi 0 iken duz cizgi acik %d/%d",
                c.ord_setup, c.ord_n, c.aa_cmds > 0 and c.aa_calls / c.aa_cmds or 0,
                c.aa_max, c.ht_hs, c.ht_n, c.unpred_ok, c.unpred_n, c.filter, #hist > 0 and concat(hist, ", ") or "yok",
                DG.reasons_seen.jitter and "var" or "yok", c.held, c.shots, DG.rate(2), c.lv_ticks[2], DG.rate(1),
                c.lv_ticks[1], c.g5, c.use_aa, c.use_setup, c.unch[1], c.unch[2], c.unch[3], c.unch[4], c.undrained,
                DG.dt_mode(), trt > 0 and (c.tr_sum + cur * DG.trn) / trt or 0, max(c.tr_max, cur * DG.trn), trt,
                c.wake, c.wake_hurt, c.wake_wait, c.g31_open, c.g31_n))
        end
        local tick = DG.tr_tick
        DG.reset()
        DG.tr_tick = tick
    end
end

-------------------------------------------------------------------------------
-- Ragebot (HITSCAN / TARGET_SELECTION, hedef basina): gercek / taze kayit bekleme, Min. damage kurallari
-- (sira: bicak / zeus -> DT cifti -> extended -> kafa saklayan -> can'a yukselt), akilli govde, sahte kayitta
-- govde, havada hit chance, adaptif safe point seviyeleri.
-------------------------------------------------------------------------------
do
    local U, RG = N.util, N.rage
    local K = N.K
    RG.t, RG.hold, RG.wait, RG.fresh, RG.freshw, RG.scan, RG.dmg_cache = {}, {}, {}, {}, {}, {}, {}
    RG.ext, RG.last_md, RG.fresh_tick, RG.sik = {}, nil, -1000, { idx = nil, since = nil, logged = false }
    -- R10: bu oturumda (bu haritada) o durumda resolver iskasi alinan rakipler; yoksa hafiza en fazla seviye 1.
    RG.cfresh = {}
    RG.GROUPS = { "HEAD", "CHEST", "STOMACH", "ARMS", "LEGS", "FEET" }

    RG.get = function(idx)
        local t = RG.t[idx]
        if t == nil then
            t = { level = 0, stall_until = -1000, l2_since = nil, fake_ticks = 0, fake_free = -1000,
                fake_window = nil, last_shot = -1000 }
            RG.t[idx] = t
        end
        return t
    end

    -- Gozumuzden hedefe: kafa ve govde (gogus / pelvis) hasari; tick basina onbellek.
    RG.dmg = function(target)
        local idx = U.index(target)
        local tick = U.tick()
        local c = idx ~= nil and RG.dmg_cache[idx] or nil
        if c ~= nil and c.tick == tick then
            return c.head, c.body
        end
        local lp = N.st.lp
        local eye = U.eye(lp)
        local head = U.tdmg(eye, U.hitbox(target, "HEAD"), lp, target)
        local body = max(U.tdmg(eye, U.hitbox(target, "PELVIS"), lp, target),
            U.tdmg(eye, U.hitbox(target, "CHEST"), lp, target))
        if idx ~= nil then
            local hittable = head > 0 or body > 0
            RG.dmg_cache[idx] = { tick = tick, head = head, body = body, hittable = hittable }
            if hittable then
                RG.fresh[idx] = tick
            end
        end
        return head, body
    end

    RG.group_off = function(ctx, name)
        pcall(ctx.set_hitscan_group_state, ctx, e_hitscan_groups[name], false)
    end

    RG.all_off = function(ctx)
        for _, g in ipairs(RG.GROUPS) do
            RG.group_off(ctx, g)
        end
    end

    RG.end_wait = function(idx, w, reason, ent)
        local tick = U.tick()
        w.active = false
        w.free_until = tick + 32
        w.done_text = fmt("%d tick", w.ticks)
        w.done_at = U.now()
        if w.kind == "real" then
            if N.on("resolver_log") then
                N.log.every("wait:" .. idx, 15, fmt("resolver: %s sahte kayitta (%s): %d tick gercek kayit beklendi, %s",
                    U.name(ent), w.flag or "defensive", w.ticks, reason), true)
            end
        else
            if N.on("resolver_log") then
                N.log.every("fresh:" .. idx, 15, fmt("resolver: %s su anki kaydi vurulamiyordu: %d tick taze kayit beklendi, %s",
                    U.name(ent), w.ticks, reason))
            end
        end
    end

    -- SETUP_COMMAND: bekletme listesi (TARGET_SELECTION + HITSCAN ayni listeyi kullanir).
    RG.prepare = function()
        local st, E, T = N.st, N.exposure, N.track
        local tick, now = U.tick(), U.now()
        local hold = {}
        local list = E.enemies()
        -- Senin Min. damage override tusun basiliyken R2-R7 calismaz (R1 calisir).
        local _, ovr = N.ref.md_eff(st.wgroup)
        local bolt = U.is_bolt(st.weapon) and not ovr
        local do_fresh = N.on("fresh_only") and bolt and (tick - RG.fresh_tick >= 2 or tick < RG.fresh_tick)
        if do_fresh then
            RG.fresh_tick = tick
        end
        for _, ent in ipairs(list) do
            local idx = U.index(ent)
            if idx ~= nil then
                -- R1: gercek kayit bekleme.
                local w = RG.wait[idx]
                if w == nil then
                    w = { active = false, ticks = 0, free_until = -1000, kind = "real" }
                    RG.wait[idx] = w
                end
                local t = T.p[idx]
                -- N1: sadece defensive (sim zamani geri) beklenir; LC backtrack kaydi degildir, beklemek duzeltmez.
                local fake = T.def(idx)
                local sees = E.sees(idx)
                local duel = sees or (t ~= nil and now >= t.we_shot and now - t.we_shot <= 1.5)
                if N.on("wait_real") then
                    local limit = 14
                    if st.move_state == "Peek" and not E.seen and U.flag(ent, "ON_GROUND") == false then
                        limit = 4
                    end
                    if w.active then
                        w.ticks = w.ticks + 1
                        if not fake then
                            w.real_at = w.real_at or tick
                            if tick - w.real_at >= 3 then
                                RG.end_wait(idx, w, "gercek kayit geldi", ent)
                            elseif w.ticks >= limit then
                                -- 3 tick'lik dogrulama da siniri asamaz (log 2: 16-17 tick'lik beklemeler).
                                RG.end_wait(idx, w, "sinir doldu (gercek kayit dogrulanirken)", ent)
                            end
                        elseif w.ticks >= limit then
                            RG.end_wait(idx, w, "sinir doldu, kayit hala sahte", ent)
                        elseif sees then
                            RG.end_wait(idx, w, "serbest birakildi (seni goruyor)", ent)
                        elseif duel then
                            RG.end_wait(idx, w, "serbest birakildi (duello)", ent)
                        end
                    elseif fake then
                        if sees then
                            w.nowait = "seni goruyor"
                        elseif duel then
                            w.nowait = "duello"
                        elseif E.seen then
                            w.nowait = "biri seni goruyor"
                        elseif tick < w.free_until and tick >= w.free_until - 32 then
                            w.nowait = "cooldown"
                        elseif T.woke(idx, T.WAKE_GAP) then
                            -- Yeni uyanan dusman (dormant'tan cikti): ilk 32 tick bekleme baslamaz.
                            if w.nowait ~= "yeni uyandi" then
                                N.diag.wake_wait()
                            end
                            w.nowait = "yeni uyandi"
                        else
                            w.active, w.ticks, w.real_at, w.nowait = true, 0, nil, nil
                            w.flag = T.fake_kind(idx) or "defensive"
                        end
                    else
                        w.nowait = nil
                    end
                    if w.active then
                        hold[idx] = "real"
                    end
                elseif w.active then
                    w.active = false
                end
                -- R2: sniper'da taze kayit. Iz butcesi: sadece son 32 tick'te taranan, beklenen ya da tehdit olan dusman.
                local f = RG.freshw[idx]
                if f == nil then
                    f = { active = false, ticks = 0, kind = "fresh" }
                    RG.freshw[idx] = f
                end
                if do_fresh then
                    local sc = RG.t[idx] ~= nil and RG.t[idx].scan_tick or nil
                    if f.active or ent == st.threat or (sc ~= nil and tick - sc <= 32 and tick >= sc) then
                        RG.dmg(ent)
                    end
                end
                if N.on("fresh_only") and bolt and hold[idx] == nil then
                    local c = RG.dmg_cache[idx]
                    local hittable = c ~= nil and c.hittable == true and tick - c.tick <= 2 and tick >= c.tick
                    local last = RG.fresh[idx]
                    if f.active then
                        f.ticks = f.ticks + 1
                        if hittable then
                            RG.end_wait(idx, f, "kayit taze, ates serbest", ent)
                        elseif last == nil or tick - last > 24 or tick < last then
                            RG.end_wait(idx, f, "eski kayitlar gecti (backtrack yok)", ent)
                        end
                    elseif not hittable and last ~= nil and tick - last <= 24 and tick - last >= 2 then
                        f.active, f.ticks = true, 0
                    end
                    if f.active then
                        hold[idx] = "fresh"
                    end
                elseif f.active then
                    f.active = false
                end
            end
        end
        RG.hold = hold
        RG.sikmadi()
    end

    -- TARGET_SELECTION
    RG.select = function(ctx)
        for idx in pairs(RG.hold) do
            pcall(ctx.ignore_target, ctx, idx)
        end
    end

    RG.set_md = function(ctx, info, value, why)
        value = max(1, floor(value + 0.5))
        pcall(ctx.set_min_dmg, ctx, value)
        info.md, info.md_set, info.why = value, true, why
        RG.last_md = { v = value, tick = U.tick(), why = why }
    end

    -- Bicakli / zeuslu hedef 320 birimde, goz goze, |dz| < 128.
    RG.melee_close = function(target)
        local st = N.st
        local m = U.melee(U.winfo(target))
        if m == nil then
            return nil
        end
        local mine, theirs = U.origin(st.lp), U.origin(target)
        if mine == nil or theirs == nil or U.dist(mine, theirs) > 320 or abs(mine.z - theirs.z) >= 128 then
            return nil
        end
        local eye, their_eye = U.eye(st.lp), U.eye(target)
        local frac, hit = U.tline(eye, their_eye, st.lp)
        if frac >= 0.97 or hit == target then
            return m, U.dist(mine, theirs)
        end
        return nil
    end

    RG.estate = function(target)
        return N.track.enemy_state(target)
    end

    -- R10 / R11: seviye 0 / 1 (safe point kafa) / 2 (Force).
    RG.level = function(target, idx, hp, head, body, sniper)
        local t = RG.get(idx)
        local p, key = N.mem.entry(target)
        local estate = RG.estate(target)
        local results = p ~= nil and p.res[estate] or ""
        local _, c = results:gsub("c", "")
        local level = min(2, c)
        -- GS entry_level: hafizadan gelen eski iskalar en fazla Prefer; Force icin bu oturumda o durumda bir iska.
        local fr = key ~= nil and RG.cfresh[key] or nil
        if level > 1 and not (fr ~= nil and fr[estate]) then
            level = 1
        end
        -- Veri yokken cok tarafli desen (jitter / x-way / random, GS enemy_watch.multi): canli desen ya da canli desen
        -- henuz yokken hafizadaki aliskanlik (N.profile.prior) -> ilk atistan seviye 1.
        local tr = N.track.p[idx]
        if results == "" and ((tr ~= nil and N.profile.MULTI[tr.pattern]) or N.profile.prior(target, p, key, tr)) then
            level = max(level, 1)
        end
        if N.on("low_hp_safe") and hp <= 30 then
            level = 2
        end
        if sniper then
            level = min(level, 1)
        end
        if body <= 0 and head > 0 then
            level = min(level, 1)
        end
        local now = U.now()
        if level == 2 then
            local can = U.call(client.can_fire) == true
            if (head > 0 or body > 0) and can then
                t.l2_since = t.l2_since or now
                if now - t.l2_since >= N.K.FORCE_STALL and now - t.last_shot >= N.K.FORCE_STALL then
                    t.stall_until = now + 2
                    t.l2_since = nil
                    if N.on("resolver_log") then
                        N.log.line(fmt("resolver: %s %s | seviye 2 -> 1 (ates gelmedi, 2 sn)", U.name(target), estate))
                    end
                end
            else
                t.l2_since = nil
            end
            if now < t.stall_until and now >= t.stall_until - 2 then
                level = 1
            end
        else
            t.l2_since = nil
        end
        if level ~= t.level then
            if N.on("resolver_log") and (level > 0 or t.level > 0) then
                N.log.every("lvl:" .. idx .. ":" .. level, 2, fmt("resolver: %s %s | seviye %d -> %d (%s)", U.name(target),
                    estate, t.level, level, level == 2 and "safe point Force" or (level == 1 and "safe point Head"
                    or "safe point yok")))
            end
            t.level = level
        end
        return level
    end

    RG.ext_active = function(target)
        local _, key = N.mem.entry(target)
        local e = key ~= nil and RG.ext[key] or nil
        local now = U.now()
        return e ~= nil and e.until_t ~= nil and now < e.until_t and now >= e.until_t - 180
    end

    RG.hider_active = function(target)
        local p = N.mem.entry(target)
        if p == nil then
            return false, 0, 0
        end
        local hd = p.hider
        if hd.n >= 12 and hd.h / hd.n <= 0.35 then
            return true, hd.h, hd.n
        end
        return false, hd.h, hd.n
    end

    -- HITSCAN (hedef basina).
    RG.hitscan = function(ctx)
        local target = ctx.player
        local idx = U.index(target)
        if target == nil or idx == nil then
            return
        end
        local st, P = N.st, N.ref
        local tick, now = U.tick(), U.now()
        N.ex.onpeek_trigger()
        local info = { md = nil, md_set = false, ba = false, sp = 0, why = nil, tick = tick, hider = false }
        RG.scan[idx] = info
        RG.get(idx).scan_tick = tick
        local hp = U.hp(target)
        info.hp = hp
        if RG.hold[idx] ~= nil then
            RG.all_off(ctx)
            info.held = RG.hold[idx]
            return
        end
        local w = st.wgroup
        local wname = st.weapon
        local sniper = U.is_sniper(wname)
        local head, body = RG.dmg(target)
        info.head, info.body = head, body
        -- R10 / R11
        if N.on("resolver") then
            local level = RG.level(target, idx, hp, head, body, sniper and N.on("head_only"))
            info.sp = level
            N.diag.level(idx, level, head, body)
            if level == 1 then
                pcall(ctx.set_safepoint_state, ctx, true, e_hitscan_groups.HEAD)
            elseif level == 2 then
                pcall(ctx.set_safepoint_state, ctx, true)
            end
        end
        -- R8: tek govde mermisi olduruyor -> govde.
        if N.on("smart_baim") and body >= hp then
            for _, g in ipairs({ "HEAD", "ARMS", "LEGS", "FEET" }) do
                RG.group_off(ctx, g)
            end
            info.ba = true
        end
        -- R9: sniper, hedef sahte kayitta ve govde olduruyor -> kafa gercek kayda (en fazla 12 tick, sonra 0.5 sn).
        local t = RG.get(idx)
        if N.on("fake_body") and U.is_bolt(wname) and N.track.def(idx) and not N.track.woke(idx, N.track.WAKE_GAP)
            and body >= hp and now >= t.fake_free then
            if t.fake_window == nil then
                t.fake_window, t.fake_ticks = tick, 0
                if N.on("resolver_log") then
                    N.log.line(fmt("resolver: %s sahte kayitta (defensive): sniper oldurecek govdeye, kafa gercek kayda",
                        U.name(target)))
                end
            end
            if tick ~= t.fake_last then
                t.fake_last = tick
                t.fake_ticks = t.fake_ticks + 1
            end
            if t.fake_ticks <= 12 then
                RG.group_off(ctx, "HEAD")
                info.ba = true
            else
                t.fake_window, t.fake_free = nil, now + 0.5
            end
        elseif t.fake_window ~= nil and not N.track.def(idx) then
            t.fake_window = nil
        end
        -- Min. damage kurallari. Senin override tusun basiliyken hicbiri (R2-R7) calismaz.
        local md, ovr = P.md_eff(w)
        info.md_eff, info.ovr = md, ovr
        if md == nil or ovr then
            RG.air_hc(ctx, wname, w)
            return
        end
        local need = P.need(hp, md)
        local melee, dist = nil, nil
        if N.on("knife_md") then
            melee, dist = RG.melee_close(target)
        end
        local target_melee = U.melee(U.winfo(target))
        -- R4: bicak -> MD min(30, hp) (oldurmese de vur); zeus -> sadece oldurucu (MD hp).
        if melee == "knife" then
            local v = min(30, hp)
            if v < need then
                RG.set_md(ctx, info, v, "knife")
                N.log.every("r4:" .. idx, 2, fmt("%s bicak ile yakinda: Min. damage gecici %d (oldurmese de vur)",
                    U.name(target), U.R(v)))
            end
        elseif melee == "zeus" then
            if hp < need then
                RG.set_md(ctx, info, hp, "zeus")
                N.log.every("r4:" .. idx, 2, fmt("%s zeus ile yakinda: sadece oldurucu (MD %d)", U.name(target),
                    U.R(hp)))
            end
        end
        -- R7: DT cifti (kapali varsayilan): govde x 2 >= can, govde >= 60, kayit 8+ tick gec.
        if not info.md_set and N.on("dt_pair") and sniper and P.dt_ready() and body * 2 >= hp and body >= 60 then
            local tr = N.track.p[idx]
            if tr ~= nil and tr.record_age >= 8 and body - 1 < need then
                RG.set_md(ctx, info, body - 1, "dtpair")
                N.log.every("r7:" .. idx, 2, fmt("%s: DT cifti olduruyor (govde %d x 2 >= can %d), Min. damage gecici %d",
                    U.name(target), U.R(body), U.R(hp), U.R(body - 1)))
            end
        end
        -- R5 / R6 (GS ext_why): sadece yerdeki hedefe, govde >= 60 ve govde oldurmuyorken; yoksa kafa ve MD
        -- olduklari gibi kalir (sadece kafa gorunen rakip vurulabilir kalir, duvar arkasi govde MD'yi dusurmez).
        local body_force = body >= 60 and hp > body and U.flag(target, "ON_GROUND") ~= false
        -- R5: extended suphesi (kafada ust uste resolver iskasi) -> govde.
        if not info.md_set and body_force and N.on("ext_body") and target_melee == nil and RG.ext_active(target) then
            RG.group_off(ctx, "HEAD")
            info.ba = true
            if body - 1 > 0 and body - 1 < need then
                RG.set_md(ctx, info, body - 1, "ext")
                N.log.every("r5:" .. idx, 5, fmt("%s: extended suphesi (kafada 3 iska ust uste): govde %d, Min. damage gecici %d",
                    U.name(target), U.R(body), U.R(body - 1)))
            end
        end
        -- R6: kafa saklayan (kafa payi <= %35, 12+ atis) -> sniper govde; her 4. atis kafaya serbest.
        if not info.md_set and body_force and N.on("hider_body") and sniper and target_melee == nil then
            local active, h, n = RG.hider_active(target)
            if active then
                info.hider = true
                local p = N.mem.entry(target)
                if p ~= nil and p.hider.b % 4 ~= 3 then
                    RG.group_off(ctx, "HEAD")
                    info.ba = true
                    if body - 1 > 0 and body - 1 < need then
                        RG.set_md(ctx, info, body - 1, "hider")
                    end
                    if N.on("resolver_log") then
                        N.log.every("r6:" .. idx, 30, fmt("resolver: %s kafa payi %d/%d (%d%%): govde zorlaniyor",
                            U.name(target), U.R(h), U.R(n), U.R(h / max(1, n) * 100)))
                    end
                end
            end
        end
        -- R3: sniper, biri seni goruyorken sadece oldurucu atis (MD can; yukseltir, dusurmez).
        if not info.md_set and N.on("head_only") and sniper and need < hp and N.exposure.seen then
            RG.set_md(ctx, info, hp, "head")
        end
        RG.air_hc(ctx, wname, w)
    end

    -- R12: havadayken sniper hit chance (0 = kapali; senin degerin daha yuksekse dokunulmaz).
    RG.air_hc = function(ctx, wname, w)
        local v = N.v("air_hc") or 0
        if v <= 0 or not N.st.airborne or not U.is_bolt(wname) then
            return
        end
        local native = N.ref.get("hc:" .. w)
        if U.finite(native) and v <= native then
            return
        end
        pcall(ctx.set_hitchance, ctx, v)
    end

    -- Atis sonucu ogrenmesi (resolver sonuclari, extended ve kafa saklayan sayaclari).
    RG.learn = function(rec, result, reason, hitgroup)
        local target = rec.ent
        if target == nil then
            return
        end
        local p, key = N.mem.entry(target, rec.key)
        if p == nil then
            return
        end
        -- Pencereye sadece isabet (h) ve resolver iskasi (c) girer; spread / diger iskalar pencereyi sulandirmaz (GS).
        local letter = nil
        if result == "hit" then
            letter = "h"
        elseif reason == "resolver" or reason == "jitter" then
            if not rec.fake then
                letter = "c"
            end
        end
        if letter ~= nil and rec.estate ~= nil then
            local s = (p.res[rec.estate] or "") .. letter
            p.res[rec.estate] = s:sub(-4)
            N.mem.dirty = true
            if letter == "c" then
                RG.cfresh[key] = RG.cfresh[key] or {}
                RG.cfresh[key][rec.estate] = true
            end
        end
        local head_aimed = rec.hitgroup == 1
        -- R5 sayaci: kafaya nisan, hc >= 70, yerdeki hedef, statik (ya da bilinmeyen) desen (cok tarafli / spin
        -- desende kafa iskasi extended kaniti degil).
        local e = RG.ext[key]
        if e == nil then
            e = { misses = 0 }
            RG.ext[key] = e
        end
        local tnow = U.now()
        if result == "hit" and hitgroup == 1 then
            if e.until_t ~= nil and N.on("resolver_log") then
                N.log.line(fmt("resolver: %s kafadan vuruldu -> extended govde kurali kalkti", rec.name))
            end
            e.misses, e.until_t = 0, nil
        elseif result == "hit" then
            -- GS: ardisik seri; her isabet (govde dahil) sayaci sifirlar.
            e.misses = 0
        elseif reason == "resolver" and head_aimed and (rec.hc or 0) >= 70 and rec.grounded and not rec.fake
            and (rec.pattern == "static" or rec.pattern == "?") then
            -- GS: 300 sn iskasiz gecerse seri baslangictan.
            if e.last_miss ~= nil and (tnow < e.last_miss or tnow - e.last_miss > 300) then
                e.misses = 0
            end
            e.last_miss = tnow
            e.misses = e.misses + 1
            local need = (rec.pattern == "static" and rec.sideways) and 2 or 3
            if e.misses >= need and (e.until_t == nil or tnow > e.until_t) then
                local streak = e.misses
                e.until_t, e.misses = tnow + 180, 0
                if N.on("resolver_log") then
                    N.log.line(fmt("%s: extended suphesi (kafada %d iska ust uste): govdeye geciliyor", rec.name,
                        streak))
                end
            end
        end
        -- R6 sayaci (sniper, kafaya nisan, yerdeki hedef, hc >= 70; isabet ya da resolver iskasi).
        if rec.sniper and head_aimed and rec.grounded and (rec.hc or 0) >= 70
            and (result == "hit" or reason == "resolver") then
            local hd = p.hider
            hd.n = hd.n + 1
            if result == "hit" and hitgroup == 1 then
                hd.h = hd.h + 1
            end
            if hd.n > 30 then
                hd.h = hd.h * 30 / hd.n
                hd.n = 30
            end
            N.mem.dirty = true
        end
    end

    -- dbg sikmadi: hedefe 20+ hasar geciyor ama 0.44 sn ates yok -> butun sebepler + silah / konum / kayit / sen.
    RG.sikmadi = function()
        local st = N.st
        local S = RG.sik
        if not N.on("debug_log") then
            return
        end
        local target = st.threat
        local now = U.now()
        if target == nil then
            S.idx, S.since = nil, nil
            return
        end
        local idx = U.index(target)
        local head, body = RG.dmg(target)
        if max(head, body) < 20 then
            S.idx, S.since = nil, nil
            return
        end
        if S.idx ~= idx or S.since == nil or N.shots.last_shoot_at > S.since then
            S.idx, S.since, S.logged = idx, now, false
            return
        end
        if S.logged or now - S.since < 0.44 then
            return
        end
        S.logged = true
        local hp = U.hp(target)
        local md = N.ref.md_eff(st.wgroup)
        local need = md ~= nil and N.ref.need(hp, md) or nil
        local hc = N.ref.get("hc:" .. st.wgroup)
        local best, tick = max(head, body), U.tick()
        -- GS V1.0.17/22/50: uyan butun sebepler (tek sebep "sebep bilinmiyor"u gizliyordu).
        local reasons = {}
        if RG.hold[idx] == "real" then
            reasons[#reasons + 1] = "gercek kayit bekleniyor"
        elseif RG.hold[idx] == "fresh" then
            reasons[#reasons + 1] = "taze kayit bekleniyor"
        end
        if need ~= nil and best < need then
            reasons[#reasons + 1] = md >= 100 and fmt("hasar %d < can+%d", U.R(best), U.R(md - 100))
                or fmt("hasar %d < MD %d", U.R(best), U.R(md))
        end
        if head <= 0 then
            reasons[#reasons + 1] = "kafa kapali"
        end
        local tr = N.track.p[idx]
        if tr ~= nil and tick <= tr.def_until then
            reasons[#reasons + 1] = "onun kaydi sahte (DEF)"
        end
        if tr ~= nil and tick <= tr.lc_until then
            reasons[#reasons + 1] = "onun kaydi LC kiriyor (isinlaniyor)"
        end
        if st.airborne then
            reasons[#reasons + 1] = "sen havadasin"
        elseif st.fd then
            reasons[#reasons + 1] = "fake duck (ates sadece kalkarken)"
        elseif U.speed(st.lp) > 100 then
            reasons[#reasons + 1] = fmt("sen hareketlisin v%d (isabet sansi)", U.R(U.speed(st.lp)))
        end
        if U.call(client.can_fire) ~= true then
            local since = now - st.last_shot
            reasons[#reasons + 1] = (since >= 0 and since < 1.5) and fmt("silah hazir degil (son atis %.2fs once)", since)
                or "silah hazir degil"
        end
        local aim = N.ex.aim
        if aim.target ~= nil and aim.target ~= target and now - aim.time <= 0.44 and now >= aim.time then
            reasons[#reasons + 1] = "aimbot baska hedefe: " .. U.name(aim.target)
        end
        -- HITSCAN bu hedef icin 8 tick'tir gelmiyorsa aimbot onu degerlendirmiyor; baska birini tariyorsa adi.
        local mine = RG.t[idx]
        if mine == nil or mine.scan_tick == nil or tick - mine.scan_tick > 8 or tick < mine.scan_tick then
            local other = nil
            for i, t in pairs(RG.t) do
                if i ~= idx and t.scan_tick ~= nil and tick - t.scan_tick <= 2 and tick >= t.scan_tick then
                    other = i
                end
            end
            local ot = other ~= nil and N.track.p[other] or nil
            reasons[#reasons + 1] = other ~= nil and ("aimbot tehdidi baska: " .. U.name(ot ~= nil and ot.ent or nil))
                or "aimbot bu hedefi taramiyor"
        end
        if mine ~= nil and mine.level == 2 then
            reasons[#reasons + 1] = "safe point Force (guvenli nokta yoksa ates yok)"
        end
        if #reasons == 0 then
            reasons[1] = "sebep bilinmiyor"
        end
        local D = N.dlog
        N.log.line(fmt("dbg sikmadi: %s %.2fs vurulabilir (kafa %d, govde %d hasar), ates yok | %s | MD %s hc %s | %s | %s | %s | %s | %s",
            U.name(target), now - S.since, U.R(head), U.R(body), concat(reasons, ", "), md ~= nil and U.numtext(md) or "?",
            U.finite(hc) and U.numtext(hc) or "?", U.wlabel(st.weapon), D.ready(st.lp), D.where(target, st.lp),
            D.rec(target), D.me(st.lp, target)))
    end

    -- Harita / oturum degisimi: tick'e bagli bekleme ve onbellek tablolari silinir (index'ler yeniden kullanilir).
    RG.map_reset = function()
        RG.t, RG.hold, RG.wait, RG.fresh, RG.freshw, RG.scan, RG.dmg_cache = {}, {}, {}, {}, {}, {}, {}
        RG.fresh_tick, RG.sik = -1000, { idx = nil, since = nil, logged = false }
        RG.cfresh = {}
    end

    RG.reset_life = function()
        RG.hold, RG.scan = {}, {}
        for _, w in pairs(RG.wait) do
            w.active = false
        end
        for _, f in pairs(RG.freshw) do
            f.active = false
        end
    end
end

-------------------------------------------------------------------------------
-- AI peek (native autopeek tusu basili, hareket tusu yok): tehdide dik 18/32/46/60 birim noktalar, kafa (merkez
-- / kenarlar) yeterli ya da govde oldurucu, yurunebilir; iki taramada dogrulanir, 0.5 sn beklenir, atistan /
-- sureden sonra geri. AFK modu (kendi capasi, 3 sn'de bir 24 birim adim) ve otomatik AFK.
-------------------------------------------------------------------------------
do
    local U, PK, AF = N.util, N.peek, N.afk
    PK.mode, PK.side_mul, PK.locked, PK.empty, PK.cand = nil, 1, {}, {}, nil
    PK.cal = { wrong = 0, flips = 0, off = false, logged = false }
    PK.scan_tick, PK.key_was, PK.shot_at, PK.result = -1000, false, nil, nil
    AF.on, AF.auto, AF.armed, AF.idle_since, AF.anchor, AF.side, AF.flip_at = false, false, true, nil, nil, 1, 0
    AF.cam, AF.kind_was = nil, false

    PK.button = function(cmd, name)
        local ok, v = pcall(cmd.has_button, cmd, e_cmd_buttons[name])
        return ok and v == true
    end

    PK.user_moving = function(cmd)
        return PK.button(cmd, "FORWARD") or PK.button(cmd, "BACK") or PK.button(cmd, "MOVELEFT")
            or PK.button(cmd, "MOVERIGHT")
    end

    PK.set_move = function(cmd, fwd, side)
        pcall(function()
            cmd.move = vec3_t(fwd, side, 0)
        end)
    end

    -- G13: cmd.move.y isareti; 4 tick boyunca istenen yanin tersine gidiyorsak cevrilir.
    PK.calibrate = function(want_right, view)
        local C = PK.cal
        if C.off or want_right == 0 then
            return
        end
        local v = U.vel(N.st.lp)
        local cx, sy = U.dir(view)
        local lat = v.x * sy - v.y * cx
        if abs(lat) < 20 then
            return
        end
        if (lat > 0) ~= (want_right > 0) then
            C.wrong = C.wrong + 1
        else
            C.wrong = 0
        end
        if C.wrong >= 4 then
            C.wrong = 0
            C.flips = C.flips + 1
            PK.side_mul = -PK.side_mul
            if C.flips >= 3 then
                C.off = true
                PK.mode = nil
                N.log.line("ai peek: yan hareket isareti olculemedi, ai peek / afk bu oturum kapatildi")
            elseif not C.logged then
                C.logged = true
                N.log.line("ai peek: yan hareket isareti ters olculdu, duzeltildi")
            end
        end
    end

    -- Hedefe yuru; varildiysa true.
    PK.move_to = function(cmd, goal, tolerance)
        local lp = N.st.lp
        local o = U.origin(lp)
        if o == nil or goal == nil then
            return true
        end
        local d = U.dist2d(o, goal)
        if d < (tolerance or 4) then
            PK.set_move(cmd, 0, 0)
            return true
        end
        local view = N.aa.view_yaw(cmd)
        local a = math.rad(U.yaw_to(o, goal) - view)
        local speed = min(450, max(80, d * 12))
        local right = -math.sin(a)
        PK.set_move(cmd, math.cos(a) * speed, right * speed * PK.side_mul)
        if abs(right) > 0.5 then
            PK.calibrate(right, view)
        end
        return false
    end

    PK.walkable = function(a, p, step_only)
        local lp = N.st.lp
        local f1 = U.tline(U.add(a, 0, 0, 18), U.add(p, 0, 0, 18), lp)
        if f1 < 1 then
            return false
        end
        local f2 = U.tline(U.add(p, 0, 0, 18), U.add(p, 0, 0, step_only and -18 or -40), lp)
        return f2 < 1
    end

    -- Kafa (merkez +-3) ya da oldurucu govde bu noktadan geciyor mu.
    PK.point_damage = function(eye, threat, need, hp)
        local lp = N.st.lp
        local head = U.hitbox(threat, "HEAD")
        local best = 0
        if head ~= nil then
            best = U.tdmg(eye, head, lp, threat)
            if best < need then
                local yaw = U.yaw_to(eye, head) + 90
                best = max(best, U.tdmg(eye, U.offset(head, yaw, 3, 0), lp, threat),
                    U.tdmg(eye, U.offset(head, yaw, -3, 0), lp, threat))
            end
        end
        if best >= need then
            return best
        end
        local body = max(U.tdmg(eye, U.hitbox(threat, "CHEST"), lp, threat),
            U.tdmg(eye, U.hitbox(threat, "PELVIS"), lp, threat))
        if body >= hp then
            return body
        end
        return 0
    end

    PK.scan = function(anchor, threat)
        local st = N.st
        local lp = st.lp
        local theirs, eye, org = U.origin(threat), U.eye(lp), U.origin(lp)
        if theirs == nil or eye == nil or org == nil then
            return nil
        end
        local eye_h = eye.z - org.z
        local hp = U.hp(threat)
        local need = N.ref.md_need(hp, st.wgroup) or hp
        local base = U.yaw_to(anchor, theirs)
        local angles = { 90 }
        if theirs.z > anchor.z + 64 then
            angles[2] = 135
        end
        for _, ang in ipairs(angles) do
            for _, s in ipairs({ 18, 32, 46, 60 }) do
                for _, side in ipairs({ 1, -1 }) do
                    local p = U.offset(anchor, base + ang * side, s, 0)
                    if PK.walkable(anchor, p) then
                        local d = PK.point_damage(vec3_t(p.x, p.y, p.z + eye_h), threat, need, hp)
                        if d > 0 then
                            return { p = p, side = side, s = s, dmg = d, back = ang ~= 90 }
                        end
                    end
                end
            end
        end
        return nil
    end

    PK.reset = function()
        PK.mode, PK.cand, PK.point, PK.shot_at, PK.result = nil, nil, nil, nil, nil
    end

    PK.finish = function(why)
        local name = PK.target_name or "?"
        if PK.shot_at == nil then
            N.stats.add("empty")
            local idx = PK.target_idx
            if idx ~= nil then
                PK.empty[idx] = (PK.empty[idx] or 0) + 1
                if PK.empty[idx] >= 2 then
                    PK.locked[idx] = true
                    N.log.line("ai peek: 2 bos peek, bu dusmana autopeek tusuna yeniden basana kadar peek yok")
                end
            end
        else
            if PK.target_idx ~= nil then
                PK.empty[PK.target_idx] = 0
            end
            N.log.line(fmt("ai peek sonucu: %s -> %s (%d birim)", PK.result or "atis", name, U.R(PK.point_s or 0)))
        end
        PK.reset()
    end

    -- SETUP_COMMAND.
    PK.update = function(cmd)
        local st = N.st
        local now = U.now()
        local key = N.ref.on("autopeek")
        if key ~= PK.key_was then
            PK.key_was = key
            if key then
                PK.locked, PK.empty = {}, {}
            end
        end
        AF.update(cmd)
        local anchor = nil
        if AF.on and AF.anchor ~= nil then
            anchor = AF.anchor
        elseif key and N.on("ai_peek") then
            local ok, pos = pcall(ragebot.get_autopeek_pos)
            if ok and U.okvec(pos) then
                anchor = pos
            end
        end
        if anchor == nil or PK.cal.off or (not N.on("ai_peek") and not AF.on) or PK.user_moving(cmd)
            or st.airborne then
            if PK.mode ~= nil then
                PK.reset()
            end
            if AF.on and AF.anchor ~= nil and not PK.user_moving(cmd) and not PK.cal.off then
                AF.strafe(cmd)
            end
            return
        end
        PK.anchor = anchor
        local threat = st.threat
        local tick = U.tick()
        if PK.mode == nil then
            if threat == nil then
                if AF.on then
                    AF.strafe(cmd)
                end
                return
            end
            local tidx = U.index(threat)
            if tidx ~= nil and PK.locked[tidx] then
                if AF.on then
                    AF.strafe(cmd)
                end
                return
            end
            local c, m = N.ref.charge()
            local why = nil
            if N.ref.on("dt") and m > 0 and c < m then
                why = "DT sarj oluyor"
            elseif U.call(client.can_fire) ~= true then
                why = "silah hazir degil"
            end
            if why ~= nil then
                N.log.every("aipeek_no", 3, "ai peek: peek yok, " .. why)
                if AF.on then
                    AF.strafe(cmd)
                end
                return
            end
            if tick - PK.scan_tick < 4 and tick >= PK.scan_tick then
                if AF.on then
                    AF.strafe(cmd)
                end
                return
            end
            PK.scan_tick = tick
            local r = PK.scan(anchor, threat)
            if r == nil then
                PK.cand = nil
                if AF.on then
                    AF.strafe(cmd)
                end
                return
            end
            if PK.cand == nil or PK.cand.side ~= r.side or PK.cand.s ~= r.s then
                PK.cand = r
                return
            end
            PK.mode, PK.point, PK.point_s, PK.started = "walk", r.p, r.s, now
            PK.target_idx, PK.target_name, PK.shot_at, PK.result = tidx, U.name(threat), nil, nil
            PK.extra_used = false
            N.stats.add("peeks")
            N.log.line(fmt("ai peek: %s%s %d birim -> %s (hasar %d)", r.side > 0 and "sol" or "sag",
                r.back and "-geri" or "", r.s, PK.target_name, U.R(r.dmg)))
        end
        if PK.mode == "walk" then
            if PK.shot_at ~= nil then
                PK.mode, PK.back_at = "back", now
            elseif PK.move_to(cmd, PK.point, 6) then
                local wait = st.weapon == "revolver" and 0.75 or 0.5
                PK.mode, PK.wait_until = "wait", now + wait
            elseif now - PK.started > 1.2 then
                N.log.line(fmt("ai peek: atis olmadi, noktaya varilamadi (%d/%d birim gidildi) -> geri",
                    U.R(U.dist2d(U.origin(st.lp), anchor)), U.R(PK.point_s or 0)))
                PK.mode, PK.back_at = "back", now
            end
            return
        end
        if PK.mode == "wait" then
            PK.set_move(cmd, 0, 0)
            if PK.shot_at ~= nil then
                PK.mode, PK.back_at = "back", now
                return
            end
            if now >= PK.wait_until then
                local idx = PK.target_idx
                if not PK.extra_used and idx ~= nil and N.track.def(idx) and not N.track.woke(idx, N.track.WAKE_GAP) then
                    PK.extra_used, PK.wait_until = true, PK.wait_until + 0.2
                    return
                end
                local reason = (idx ~= nil and N.rage.hold[idx] ~= nil) and "kayit bekleniyor"
                    or (U.call(client.can_fire) ~= true and "silah hazir degil") or "aimbot ates etmedi"
                N.log.line(fmt("ai peek: atis olmadi, %s (%d/%d birim gidildi) -> geri", reason,
                    U.R(U.dist2d(U.origin(st.lp), anchor)), U.R(PK.point_s or 0)))
                PK.mode, PK.back_at = "back", now
            end
            return
        end
        if PK.mode == "back" then
            -- Atistan sonra native autopeek geri doner; 0.5 sn icinde donmediyse biz goturuz.
            if PK.shot_at ~= nil and not AF.on and now - PK.back_at < 0.5 then
                local o = U.origin(st.lp)
                if o ~= nil and U.dist2d(o, anchor) < 8 then
                    PK.finish()
                end
                return
            end
            if PK.shot_at ~= nil and not AF.on and not PK.back_logged then
                PK.back_logged = true
                N.log.every("aipeek_back", 5, "ai peek: geri (native donmedi)")
            end
            if PK.move_to(cmd, anchor, 6) or now - PK.back_at > 2 then
                PK.back_logged = false
                PK.finish()
            end
        end
    end

    -- Peek sirasindaki her aimbot atisi (DT ciftinin ikisi de) AI PEEK ATIS'a sayilir (GS ai_peek.fired).
    PK.on_shot = function()
        if PK.mode ~= nil then
            N.stats.add("ai_shots")
            PK.shot_at = PK.shot_at or U.now()
        end
    end

    PK.on_result = function(text)
        if PK.mode ~= nil or PK.shot_at ~= nil then
            PK.result = text
            if text:sub(1, 6) == "isabet" then
                N.stats.add("ai_hits")
            end
        end
    end

    PK.hurt = function(hitgroup, dmg, attacker_name)
        if PK.mode == "walk" or PK.mode == "wait" then
            N.stats.add("hurt")
            N.log.line(fmt("ai peek: peek sirasinda vuruldun (%s -%d, %s)", N.K.HITGROUPS[hitgroup] or "?", U.R(dmg),
                attacker_name))
        end
    end

    -- Otomatik AFK girdisi: hareket / ziplama / egilme / ates / E ve fare (0.5 derece).
    AF.input = function(cmd)
        local why = nil
        if PK.user_moving(cmd) or PK.button(cmd, "JUMP") or PK.button(cmd, "DUCK") then
            why = "tus"
        elseif PK.button(cmd, "ATTACK") or PK.button(cmd, "ATTACK2") then
            why = "ates / durbun"
        elseif PK.button(cmd, "USE") then
            why = "E"
        end
        local ok, ang = pcall(engine.get_view_angles)
        if ok and ang ~= nil then
            local okv, p, y = pcall(function()
                return ang.x, ang.y
            end)
            if okv and U.finite(p) and U.finite(y) then
                local c = AF.cam
                if c ~= nil and (abs(U.norm(y - c.y)) > 0.5 or abs(p - c.x) > 0.5) then
                    why = why or "fare"
                end
                AF.cam = { x = p, y = y }
            end
        end
        return why
    end

    AF.update = function(cmd)
        local st = N.st
        local now = U.now()
        local why = AF.input(cmd)
        local frozen = U.game("m_bFreezePeriod") == 1
        local warm = U.game("m_bWarmupPeriod") == 1
        local okm, menu_open = pcall(menu.is_open)
        local paused = frozen or warm or (okm and menu_open == true)
        if why ~= nil and frozen then
            AF.idle_since = nil
        elseif why ~= nil then
            if AF.auto then
                N.log.line("otomatik afk kapandi: " .. why)
            end
            AF.auto, AF.armed, AF.idle_since = false, false, nil
        elseif paused or not N.on("afk_auto") then
            AF.idle_since = nil
        elseif AF.armed then
            AF.idle_since = AF.idle_since or now
            if not AF.auto and now - AF.idle_since >= 8 then
                AF.auto = true
                N.log.line("otomatik afk: dogduktan sonra 8 sn tusa basmadin")
            end
        end
        if not N.on("afk_auto") then
            AF.auto = false
        end
        local on = (N.on("afk") or AF.auto) and st.alive and not PK.cal.off
        if on ~= AF.on then
            AF.on = on
            AF.anchor = nil
            if on then
                N.log.line("afk modu acik: AI peek burada, 3 sn'de bir sag / sol, DT + defensive tam")
            else
                N.log.line("afk modu kapali: " .. (st.alive and "tusa bastin" or "oldun"))
            end
        end
        if not AF.on then
            return
        end
        local mine = U.origin(st.lp)
        if mine == nil then
            return
        end
        if PK.user_moving(cmd) or st.airborne or U.num(st.lp, "m_MoveType") == 9 then
            AF.anchor = nil
            return
        end
        if AF.anchor == nil then
            AF.anchor, AF.flip_at = U.copy(mine), now + 3
        else
            local dx, dy = mine.x - AF.anchor.x, mine.y - AF.anchor.y
            if dx * dx + dy * dy > 160 * 160 or abs(mine.z - AF.anchor.z) > 18 then
                AF.anchor, AF.flip_at = U.copy(mine), now + 3
            end
        end
    end

    -- AFK adimi: 3 sn'de bir capanin 24 birim sagi / solu (tehdide dik); duvar / bosluk -> capa.
    AF.strafe = function(cmd)
        local st = N.st
        local now = U.now()
        if AF.anchor == nil then
            return
        end
        if now >= AF.flip_at or now < AF.flip_at - 4 then
            AF.side, AF.flip_at = -AF.side, now + 3
        end
        local threat = st.threat
        local theirs = threat ~= nil and U.origin(threat) or nil
        local yaw = theirs ~= nil and U.yaw_to(AF.anchor, theirs) or N.aa.view_yaw(cmd)
        local dest = U.offset(AF.anchor, yaw + 90 * AF.side, 24, 0)
        if not PK.walkable(AF.anchor, dest, true) then
            dest = U.offset(AF.anchor, yaw - 90 * AF.side, 24, 0)
            if not PK.walkable(AF.anchor, dest, true) then
                dest = AF.anchor
            end
        end
        PK.move_to(cmd, dest, 4)
    end

    AF.spawn = function()
        AF.auto, AF.armed, AF.idle_since, AF.anchor = false, true, nil, nil
    end

    AF.death = function()
        if AF.on then
            N.log.line("afk modu kapali: oldun")
        end
        AF.on, AF.auto, AF.armed, AF.idle_since, AF.anchor = false, false, true, nil, nil
        PK.reset()
    end
end

-------------------------------------------------------------------------------
-- Atis kayitlari (AIMBOT_SHOOT -> HIT / MISS, .id ile), dusman mermileri, olumler, round / atis ozetleri,
-- dbg duello / ayarlar. Satir bicimleri GS surumuyle ayni (detay satirlari N.dlog'da).
-------------------------------------------------------------------------------
do
    local U, S, ST = N.util, N.shots, N.stats
    local K = N.K
    S.recs, S.n, S.last_shoot_at = {}, 0, -1000
    S.round, S.shots_round = nil, nil
    S.duels = {}

    S.aa_status = function()
        local l = N.aa.last
        return fmt("%s %d (%s)", l.side and "sag" or "sol", U.R(l.limit), l.body or "?")
    end

    S.exploit_status = function()
        local st, X = N.st, N.ex
        local parts = {}
        local now, tick = U.now(), U.tick()
        if st.fd then
            parts[#parts + 1] = "FD"
        end
        local c, m = N.ref.charge()
        if N.ref.on("dt") then
            if m > 0 and c >= m then
                parts[#parts + 1] = "DT dolu"
            else
                parts[#parts + 1] = fmt("DT %%%d", U.R(m > 0 and c / m * 100 or 0))
                N.charge.status(parts, c, m)
            end
        elseif N.ref.on("hs") then
            parts[#parts + 1] = "HS"
        else
            parts[#parts + 1] = "DT yok"
        end
        local age = tick - X.hidden_tick
        parts[#parts + 1] = (X.own_def_active() and "DEF acik" or "DEF yok") .. (X.forced and " (zorla)" or "")
            .. ((age >= 0 and age <= 16) and fmt(" gizli %dt", U.R(age)) or "") .. (st.slowed and " yavas" or "")
        if N.rc.held("safe") then
            parts[#parts + 1] = "sarj bekle"
        elseif X.safe.no_hold ~= nil and X.safe.no_hold_at ~= nil and now - X.safe.no_hold_at < 1 then
            parts[#parts + 1] = "sarj bekleme yok: " .. X.safe.no_hold
        end
        if now - X.tp.last < 2 and now >= X.tp.last then
            parts[#parts + 1] = "TP"
        end
        if X.air.latched then
            parts[#parts + 1] = "AIR LC"
        end
        if X.clean then
            parts[#parts + 1] = "temiz (" .. tostring(X.clean_src or "iz") .. ")"
        end
        return concat(parts, ", ")
    end

    S.attacker_info = function(ent)
        local E = N.exposure
        local idx = U.index(ent)
        local parts = { N.track.enemy_state(ent) }
        local facing = N.aa.facing
        if facing == nil then
            parts[#parts + 1] = "AA hedefi yok"
        elseif facing == ent then
            parts[#parts + 1] = "AA hedefi"
        else
            parts[#parts + 1] = "AA hedefi degil"
        end
        local wbr = idx ~= nil and E.wb[idx] or nil
        if wbr ~= nil and U.tick() - wbr.tick <= 16 and U.tick() >= wbr.tick then
            parts[#parts + 1] = fmt("duvar hatti %d hasar %.1fs", U.R(wbr.dmg), (wbr.tick - wbr.since) * U.ipt())
        end
        local s = idx ~= nil and E.sight[idx] or nil
        if s ~= nil and E.sees(idx) then
            parts[#parts + 1] = fmt("gordu %.2fs", (s.last - s.first) * U.ipt())
        else
            local lp = N.st.lp
            local eye, head = U.eye(ent), U.hitbox(lp, "HEAD")
            local how = "iz yok"
            if eye ~= nil and head ~= nil then
                if U.tdmg(eye, head, ent, lp) > 0 then
                    local _, hit = U.tline(eye, head, ent)
                    how = (hit ~= nil and hit == lp) and "iz: su an goruyor" or "iz: duvardan goruyor"
                else
                    how = "iz: kapali"
                end
            end
            parts[#parts + 1] = "gormedi (" .. how .. ")"
        end
        -- N4: saldiran su an uykuda (dormant; iz eski konumundan atildi) ya da az once uyandi.
        local tr = idx ~= nil and N.track.p[idx] or nil
        if ent ~= nil and U.dormant(ent) then
            parts[#parts + 1] = "uykuda"
        elseif tr ~= nil and N.track.woke(idx, N.track.WAKE_SHOW) then
            parts[#parts + 1] = fmt("uyandi %.2fs once", (U.tick() - tr.wake_tick) * U.ipt())
        end
        return concat(parts, ", ")
    end

    local function field(obj, name)
        local ok, v = pcall(function()
            return obj[name]
        end)
        if ok then
            return v
        end
        return nil
    end
    S.field = field

    S.on_shoot = function(shot)
        local st, X, T, RG = N.st, N.ex, N.track, N.rage
        local ent = field(shot, "player")
        local id = field(shot, "id")
        local idx = U.index(ent)
        local now, tick = U.now(), U.tick()
        local info = idx ~= nil and RG.scan[idx] or nil
        if info ~= nil and (tick - info.tick > 8 or tick < info.tick) then
            info = nil
        end
        local _, key = N.mem.entry(ent)
        local tr = idx ~= nil and T.p[idx] or nil
        local fake = idx ~= nil and T.fake(idx) or false
        local wait = nil
        local w = idx ~= nil and RG.wait[idx] or nil
        local f = idx ~= nil and RG.freshw[idx] or nil
        if w ~= nil and w.done_at ~= nil and now - w.done_at <= 1 and now >= w.done_at then
            wait = "bekleme: " .. w.done_text .. " gercek kayit"
        elseif f ~= nil and f.done_at ~= nil and now - f.done_at <= 1 and now >= f.done_at then
            wait = "bekleme: " .. f.done_text .. " taze kayit"
        elseif fake and w ~= nil and w.nowait ~= nil then
            wait = "bekleme yok: " .. w.nowait
        end
        local sideways = false
        if tr ~= nil and U.finite(tr.last_yaw) then
            local mine, theirs = U.origin(st.lp), U.origin(ent)
            if mine ~= nil and theirs ~= nil then
                local bak = abs(U.norm(tr.last_yaw - U.yaw_to(theirs, mine)))
                sideways = bak >= 45 and bak <= 135
            end
        end
        local md = info ~= nil and info.md_set and info.md or N.ref.md_eff(st.wgroup)
        local rec = {
            id = id, ent = ent, idx = idx, key = key, name = U.name(ent), hp = U.hp(ent),
            estate = N.track.enemy_state(ent), hitgroup = tonumber(field(shot, "hitgroup")),
            damage = tonumber(field(shot, "damage")) or 0, hc = tonumber(field(shot, "hitchance")),
            bt = tonumber(field(shot, "backtrack_ticks")) or 0, sp = info ~= nil and info.sp or 0,
            ba = info ~= nil and info.ba or false, md = md, weapon = st.weapon, tags = X.tags(),
            profile = T.profile(ent), pattern = tr ~= nil and tr.pattern or "?", fake = fake,
            grounded = U.flag(ent, "ON_GROUND") ~= false, sideways = sideways, sniper = U.is_sniper(st.weapon),
            time = now, wait = wait,
        }
        S.n = S.n + 1
        S.recs[id ~= nil and id or ("n" .. S.n)] = rec
        -- Atis ozeti sayaclari.
        local r = S.shots_round or { shots = 0, hits = 0, clean = 0, clean_hits = 0, lag = 0, lag_hits = 0, misses = {} }
        S.shots_round = r
        r.shots = r.shots + 1
        if rec.tags.temiz then
            r.clean = r.clean + 1
        elseif rec.tags.DEF or rec.tags.LC or rec.tags.TP or rec.tags.FD then
            r.lag = r.lag + 1
        end
        -- Diger moduller.
        X.shot_tick, X.after_shot, X.aim = tick, true, { target = ent, time = now }
        X.safe.want_at = now
        st.last_shot = now
        S.last_shoot_at = now
        if tr ~= nil then
            tr.we_shot = now
            tr.our_shots = (tr.our_shots or 0) + 1
        end
        if idx ~= nil then
            RG.get(idx).last_shot = now
            local d = S.duels[idx]
            if d == nil and N.on("debug_log") then
                d = S.duel_open(ent, idx, now)
            end
            if d ~= nil then
                -- pend: sonucu (HIT / MISS) henuz gelmemis atis; olduren isabet sayimi icin (S.on_death).
                d.our_shots, d.pend, d.last, d.we_at = d.our_shots + 1, d.pend + 1, now, d.we_at or now
            end
        end
        N.dlog.on_shoot(rec, shot)
        N.diag.shot(rec)
        N.profile.count(ent, key, "s")
        if info ~= nil and info.hider then
            local p = N.mem.entry(ent)
            if p ~= nil then
                p.hider.b = p.hider.b + 1
                N.mem.dirty = true
            end
        end
        N.peek.on_shot()
    end

    S.take = function(id, player)
        local rec = id ~= nil and S.recs[id] or nil
        if rec ~= nil then
            S.recs[id] = nil
            return rec
        end
        return { name = player ~= nil and U.name(player) or "?", hp = player ~= nil and U.hp(player) or nil,
            estate = player ~= nil and N.track.enemy_state(player) or "?", damage = 0, bt = 0, sp = 0, ba = false,
            md = N.ref.md_eff(N.st.wgroup), weapon = N.st.weapon, tags = {}, profile = N.track.profile(player),
            ent = player, time = U.now(), stub = true }
    end

    S.line = function(rec, result)
        local sp = rec.sp == 2 and "Force" or (rec.sp == 1 and "Head" or "-")
        local tail = ""
        if rec.wait ~= nil then
            tail = tail .. " | " .. rec.wait
        end
        if rec.fake then
            tail = tail .. " | def (sahte kayit)"
        end
        return fmt("atis: %s | %s | HP %s | hedef %s %d | %s | SP %s | BA %s | MD %s | bt %dt | hc %s | %s%s | %s%s",
            rec.name, rec.estate or "?", rec.hp ~= nil and U.numtext(rec.hp) or "?",
            K.HITGROUPS[rec.hitgroup or -1] or "?", U.R(rec.damage), result, sp, rec.ba and "Force" or "Default",
            rec.md ~= nil and U.numtext(rec.md) or "?", U.R(rec.bt), rec.hc ~= nil and (U.numtext(U.R(rec.hc)) .. "%")
            or "?", U.wlabel(rec.weapon), N.ex.tags_text(rec.tags or {}), rec.profile or "? dsy? ground", tail)
    end

    S.on_hit = function(hit)
        local player = field(hit, "player")
        local rec = S.take(field(hit, "id"), player)
        local hg = tonumber(field(hit, "hitgroup"))
        local dmg = tonumber(field(hit, "damage")) or 0
        local result = fmt("isabet %s -%d", K.HITGROUPS[hg or -1] or "?", U.R(dmg))
        if N.on("shot_log") then
            N.log.line(S.line(rec, result))
        end
        N.dlog.print_shot(rec)
        N.charge.shot_result(rec, nil)
        N.rage.learn(rec, "hit", nil, hg)
        N.profile.count(rec.ent, rec.key, "h", hg == 1 and "hh" or nil)
        local r = S.shots_round
        if r ~= nil then
            r.hits = r.hits + 1
            if rec.tags ~= nil and rec.tags.temiz then
                r.clean_hits = r.clean_hits + 1
            elseif rec.tags ~= nil and (rec.tags.DEF or rec.tags.LC or rec.tags.TP or rec.tags.FD) then
                r.lag_hits = r.lag_hits + 1
            end
        end
        ST.result(rec, nil)
        local idx = U.index(player)
        local d = idx ~= nil and S.duels[idx] or nil
        if d ~= nil then
            d.our_hits, d.pend = d.our_hits + 1, max(0, d.pend - 1)
        end
        local tr = idx ~= nil and N.track.p[idx] or nil
        if tr ~= nil then
            tr.our_hits = (tr.our_hits or 0) + 1
        end
        N.peek.on_result(result)
    end

    S.on_miss = function(miss)
        local player = field(miss, "player")
        local rec = S.take(field(miss, "id"), player)
        local reason = tostring(field(miss, "reason_string") or "?")
        local mapped = reason == "resolver" and "correction" or reason
        local result = "iska " .. mapped:sub(1, 32)
        if N.on("shot_log") then
            N.log.line(S.line(rec, result))
        end
        N.dlog.print_shot(rec)
        local d = rec.idx ~= nil and S.duels[rec.idx] or nil
        if d ~= nil then
            d.pend = max(0, d.pend - 1)
        end
        N.rage.learn(rec, "miss", reason, nil)
        if reason == "resolver" or reason == "jitter" then
            N.profile.count(rec.ent, rec.key, "c")
        end
        N.ex.broken_shot(reason, rec.tags)
        N.charge.shot_result(rec, reason)
        N.diag.reason(reason)
        ST.result(rec, reason)
        local r = S.shots_round or { shots = 0, hits = 0, clean = 0, clean_hits = 0, lag = 0, lag_hits = 0, misses = {} }
        S.shots_round = r
        r.misses[mapped] = (r.misses[mapped] or 0) + 1
        N.peek.on_result(result)
    end

    -- Sonucu 5 sn icinde gelmeyen atis da yazilir ("sonuc yok").
    S.expire = function()
        local now = U.now()
        local drop = {}
        for id, rec in pairs(S.recs) do
            if now - rec.time > K.SHOT_MEMORY or now < rec.time then
                drop[#drop + 1] = id
            end
        end
        for _, id in ipairs(drop) do
            local rec = S.recs[id]
            S.recs[id] = nil
            if N.on("shot_log") then
                N.log.line(S.line(rec, "sonuc yok"))
            end
            N.dlog.print_shot(rec)
        end
    end

    S.player = function(userid)
        if userid == nil then
            return nil
        end
        local ok, p = pcall(entity_list.get_player_from_userid, userid)
        if ok then
            return p
        end
        return nil
    end

    S.on_hurt = function(e)
        local st = N.st
        local lp = st.lp
        if lp == nil then
            return
        end
        local victim, attacker = S.player(e.userid), S.player(e.attacker)
        local dmg = tonumber(e.dmg_health) or 0
        if attacker == lp and victim ~= nil and victim ~= lp then
            local idx = U.index(victim)
            if idx ~= nil then
                N.track.get(idx).dmg_dealt = (N.track.get(idx).dmg_dealt or 0) + dmg
            end
            return
        end
        if victim ~= lp or attacker == nil or attacker == lp or not U.is_enemy(attacker) then
            return
        end
        local weapon = tostring(e.weapon or "?")
        if K.NON_BULLET[weapon] then
            return
        end
        local hitgroup = tonumber(e.hitgroup)
        N.profile.count(attacker, nil, "b", hitgroup == 1 and "bh" or nil)
        local phase, melee = N.brute.hurt_us(e, attacker, hitgroup)
        N.ex.tp_hurt(hitgroup)
        N.charge.hurt()
        local name = U.name(attacker)
        N.peek.hurt(hitgroup, dmg, name)
        if st.fd and (weapon == "ssg08" or weapon == "awp") then
            st.fd_hint_until = U.now() + 2
            N.log.every("fd_sniper", 5, fmt("fake duck: %s %s ile vurdu -> fake duck'i birak", name, weapon))
        end
        local info = S.attacker_info(attacker)
        local aidx = U.index(attacker)
        if aidx ~= nil and N.track.woke(aidx, 64) then
            N.diag.wake_hurt()
        end
        if not melee then
            ST.enemy_hit(st.label, hitgroup == 1)
            S.count(st.label, phase, hitgroup == 1, info:find("gormedi", 1, true) ~= nil)
        end
        local idx = U.index(attacker)
        local d = idx ~= nil and S.duels[idx] or nil
        if d ~= nil then
            d.their_hits, d.their_dmg = d.their_hits + 1, d.their_dmg + dmg
        end
        if N.on("hit_log") then
            N.log.line(fmt("vuruldun: %s -%d %s | %s | faz %d | %s | %s | %s | %s (%s) | v%d duck%d",
                hitgroup ~= nil and (K.HITGROUPS[hitgroup] or "?") or "?", U.R(dmg), weapon, st.label, phase or 0,
                S.aa_status(), S.exploit_status(), U.wlabel(st.weapon), name, info, U.R(U.speed(lp)),
                U.R((st.duck or 0) * 100)))
        end
        N.dlog.hurt(attacker, hitgroup, dmg, weapon)
    end

    S.on_death = function(e)
        local st = N.st
        local lp = entity_list.get_local_player()
        if lp == nil then
            return
        end
        local victim, attacker = S.player(e.userid), S.player(e.attacker)
        local hs = e.headshot == true or e.headshot == 1
        local weapon = tostring(e.weapon or "?")
        if attacker == lp and victim ~= nil and victim ~= lp then
            if U.is_enemy(victim) then
                ST.kd("kills")
            end
            if N.on("hit_log") then
                N.log.line(fmt("oldurdun: %s | %s | %s%s", U.name(victim), st.label, U.wlabel(st.weapon),
                    hs and " | headshot" or ""))
            end
            local vidx = U.index(victim)
            N.dlog.kill(e, victim, lp, weapon)
            if U.is_enemy(victim) then
                N.profile.count(victim, nil, "k")
            end
            -- GS V1.0.60: player_death AIMBOT_HIT'ten once gelir; olduren isabet duello kapanmadan sayilir (sonucu
            -- bekleyen aimbot atisi varken ve mermili silahla).
            local d = vidx ~= nil and S.duels[vidx] or nil
            if d ~= nil and d.pend > 0 and d.our_shots > d.our_hits and N.dlog.gun(weapon) then
                d.our_hits, d.pend = d.our_hits + 1, d.pend - 1
            end
            S.duel_close(vidx, "oldurdun")
            N.misc.trash("kill", hs)
        elseif victim == lp then
            if attacker ~= nil and attacker ~= lp and U.is_enemy(attacker) then
                ST.kd("deaths")
            end
            if N.on("hit_log") then
                N.log.line(fmt("oldun: %s | %s | %s", attacker ~= nil and U.name(attacker) or "?", st.label,
                    U.wlabel(st.weapon)))
            end
            if attacker ~= nil and attacker ~= lp then
                N.dlog.death(e, attacker, lp, weapon)
                if U.is_enemy(attacker) then
                    N.profile.count(attacker, nil, "d")
                end
            end
            if attacker ~= nil then
                S.duel_close(U.index(attacker), "oldun")
            end
            for idx in pairs(S.duels) do
                S.duel_close(idx, "sen oldun")
            end
            N.dlog.vis = {}
            if attacker ~= nil and attacker ~= lp then
                N.misc.trash("death", false)
            end
            N.dead_cleanup()
        elseif victim ~= nil then
            S.duel_close(U.index(victim), "baskasi oldurdu")
        end
    end

    -- Round boyunca sana gelen mermiler.
    S.count = function(state, phase, head, unseen)
        local r = S.round or { hits = 0, head = 0, states = {}, order = {}, phases = {}, exploits = {}, unseen = 0 }
        S.round = r
        r.hits = r.hits + 1
        r.head = r.head + (head and 1 or 0)
        r.unseen = r.unseen + (unseen and 1 or 0)
        local s = r.states[state]
        if s == nil then
            s = { hits = 0, head = 0 }
            r.states[state], r.order[#r.order + 1] = s, state
        end
        s.hits, s.head = s.hits + 1, s.head + (head and 1 or 0)
        if head then
            r.phases[phase or 0] = (r.phases[phase or 0] or 0) + 1
        end
        local kind = N.st.fd and "FD" or ((N.ref.on("dt") or N.rc.held("safe")) and "DT")
            or (N.ref.on("hs") and "HS") or "yok"
        r.exploits[kind] = (r.exploits[kind] or 0) + 1
    end

    S.summary = function()
        local r = S.round
        S.round = nil
        if r ~= nil and N.on("hit_log") then
            local states = {}
            for _, state in ipairs(r.order) do
                local s = r.states[state]
                states[#states + 1] = fmt("%s %d/%d", state, s.head, s.hits)
            end
            local phases = {}
            for phase = 0, #K.BRUTE_PHASES do
                if r.phases[phase] ~= nil then
                    phases[#phases + 1] = fmt("%d:%d", phase, r.phases[phase])
                end
            end
            local ex = {}
            for _, kind in ipairs({ "DT", "HS", "FD", "yok" }) do
                if r.exploits[kind] ~= nil then
                    ex[#ex + 1] = fmt("%s %d", kind, r.exploits[kind])
                end
            end
            N.log.line(fmt("round ozeti: %d mermi, %d kafa | %s | kafa fazlari %s | %s | gormedi %d", r.hits, r.head,
                concat(states, ", "), #phases > 0 and concat(phases, " ") or "-", concat(ex, ", "), r.unseen))
        end
        local q = S.shots_round
        S.shots_round = nil
        if q ~= nil and N.on("shot_log") then
            local reasons = {}
            for reason, n in pairs(q.misses) do
                reasons[#reasons + 1] = { reason = tostring(reason), n = n }
            end
            table.sort(reasons, function(a, b)
                if a.n ~= b.n then
                    return a.n > b.n
                end
                return a.reason < b.reason
            end)
            local parts = {}
            for _, item in ipairs(reasons) do
                parts[#parts + 1] = fmt("%s %d", item.reason, item.n)
            end
            N.log.line(fmt("atis ozeti: %d mermi, %d isabet | temiz %d/%d, lag %d/%d | iska: %s", q.shots, q.hits,
                q.clean_hits, q.clean, q.lag_hits, q.lag, #parts > 0 and concat(parts, ", ") or "yok"))
        end
    end

    -- dbg duello (GS bicimi): ilk goruste (o seni gorur ya da sen onu vurabilirsin) ya da ilk atista acilir;
    -- 3 sn gorus yoksa, olumde ya da round basinda kapanir. Acilistaki konumu, defensive tick payi, havada mi.
    S.duel_open = function(ent, idx, now)
        local d = { name = U.name(ent), where = N.dlog.where(ent, N.st.lp), start = now, last = now, ticks = 0,
            def_n = 0, def_t = 0, def_was = false, speed = 0, air = false, their_shots = 0, their_hits = 0,
            their_dmg = 0, our_shots = 0, our_hits = 0, pend = 0 }
        S.duels[idx] = d
        return d
    end

    S.duel_update = function()
        if not N.on("debug_log") then
            return
        end
        local E, RG, D = N.exposure, N.rage, N.dlog
        local now, tick = U.now(), U.tick()
        for _, ent in ipairs(E.enemies()) do
            local idx = U.index(ent)
            if idx ~= nil then
                local they = E.sees_now(idx)
                local c = RG.dmg_cache[idx]
                local scan = RG.t[idx] ~= nil and RG.t[idx].scan_tick or nil
                local v = D.vis[idx]
                local we = (c ~= nil and c.hittable and tick - c.tick <= 4 and tick >= c.tick)
                    or (scan ~= nil and tick - scan <= 2 and tick >= scan)
                    or (v ~= nil and tick >= v.last and tick - v.last <= D.EVERY * 2)
                local d = S.duels[idx]
                if (they or we) and d == nil then
                    d = S.duel_open(ent, idx, now)
                end
                if d ~= nil then
                    d.ticks = d.ticks + 1
                    if they or we then
                        d.last = now
                    end
                    if they and d.they_at == nil then
                        d.they_at = now
                    end
                    if we and d.we_at == nil then
                        d.we_at = now
                    end
                    local tr = N.track.p[idx]
                    local def = tr ~= nil and tick <= tr.def_until
                    if def then
                        d.def_t = d.def_t + 1
                        if not d.def_was then
                            d.def_n = d.def_n + 1
                        end
                    end
                    d.def_was = def
                    d.speed = max(d.speed, U.speed(ent))
                    d.air = d.air or U.flag(ent, "ON_GROUND") == false
                    if now - d.last > 3 or now < d.last then
                        S.duel_close(idx, "ayrildi")
                    end
                end
            end
        end
    end

    S.duel_close = function(idx, result)
        local d = idx ~= nil and S.duels[idx] or nil
        if d == nil then
            return
        end
        S.duels[idx] = nil
        if not N.on("debug_log") then
            return
        end
        local first
        if d.we_at ~= nil and d.they_at ~= nil then
            local diff = d.they_at - d.we_at
            if abs(diff) < 0.02 then
                first = "ayni anda"
            elseif diff > 0 then
                first = fmt("sen %.2fs once", diff)
            else
                first = fmt("o %.2fs once", -diff)
            end
        elseif d.we_at ~= nil then
            first = "sadece sen gordun"
        elseif d.they_at ~= nil then
            first = "sadece o gordu"
        else
            first = "?"
        end
        N.log.line(fmt("dbg duello: %s %s | %.2fs | ilk goren: %s | def %d kez %dt (%%%d) | hiz max %d%s | o: %d ates %d isabet -%d | sen: %d ates %d isabet | %s",
            d.name, d.where, max(U.ipt(), d.last - d.start), first, d.def_n, d.def_t,
            U.R(100 * d.def_t / max(1, d.ticks)), U.R(d.speed), d.air and ", havada" or "", d.their_shots, d.their_hits,
            U.R(d.their_dmg), d.our_shots, d.our_hits, result))
    end

    S.enemy_fire = function(e)
        local p = S.player(e.userid)
        local lp = N.st.lp
        if p == nil then
            return
        end
        if p == lp then
            N.st.last_shot = U.now()
            N.ex.safe.want_at = U.now()
            return
        end
        local idx = U.index(p)
        local d = idx ~= nil and S.duels[idx] or nil
        if d ~= nil then
            d.their_shots = d.their_shots + 1
        end
        if idx ~= nil and U.is_enemy(p) then
            N.dlog.enemy_fire(idx)
        end
    end

    -- dbg ayarlar: native ayarlarin ozeti (yuklemede ve round basinda).
    S.settings_line = function()
        local P = N.ref
        local function onoff(v)
            return v == true and "acik" or (v == false and "kapali" or "?")
        end
        local mode = N.diag.dt_mode()
        local mds, hcs = {}, {}
        for _, w in ipairs({ "auto", "scout", "awp", "deagle", "revolver" }) do
            local v = P.get("md:" .. w)
            mds[#mds + 1] = U.finite(v) and U.numtext(v) or "?"
            local h = P.get("hc:" .. w)
            hcs[#hcs + 1] = U.finite(h) and U.numtext(h) or "?"
        end
        local fp = P.get("fakeping")
        local ext = P.get("ext_angles")
        N.log.line(fmt("dbg ayarlar: DT %s mod %s | HS %s | fake ping %s | FL %s BLC %s | MD auto/scout/awp/deagle/r8 %s | hc %s | quick stop scout/awp %s/%s | ext angles %s | anti brute (native) %s | autopeek tus %s",
            onoff(P.get("dt")), mode, onoff(P.get("hs")), onoff(fp),
            U.finite(P.get("fl_amount")) and U.numtext(P.get("fl_amount")) or "?", onoff(P.get("fl_blc")),
            concat(mds, "/"), concat(hcs, "/"), onoff(P.multi("qs:scout", "Early")), onoff(P.multi("qs:awp", "Early")),
            onoff(ext), onoff(P.get("anti_brute_native")), onoff(P.get("autopeek"))))
        if fp == true then
            N.log.line("UYARI: fake ping acik (onerilmez)")
        end
    end

    S.settings = function()
        if N.on("debug_log") then
            S.settings_line()
        elseif N.ref.get("fakeping") == true then
            N.log.line("UYARI: fake ping acik (onerilmez)")
        end
    end
end

-------------------------------------------------------------------------------
-- Detayli log (GS "Detayli log" bolumu, V1.0.10-64): oyun loglarindan gelistirmek icin "dbg" satirlari. Hepsi
-- "Detailed log (for analysis)" acikken. Bicimleyiciler:
--   where = @YerAdi(x,y,z) <mesafe>u h<+yukseklik farki> v<yatay hiz>[ havada vz<+n>][ duck<N>][ bak<+n>][ p<n>]
--           hp<n> <silah>[ ping<n>]   (bak = dusmanin yaw'inin sana gore acisi: 0 = sana bakiyor)
--   rec   = DEF geri Nt (sahte kayit) | def Nt once bitti, LC, AA <desen>, seviye <resolver>
--   me    = ben <where> | <durum> | aa yon <+n> dsy <+n> | manual X | FS | peek tusu / afk | <exploit> | bogma N
--   ready = sarjor bos | silah X.XXs sonra hazir | silah hazir[ (durbun kapali)]
-- Satirlar: dbg atis-detay (her atis sonucunun altinda), dbg vurulma-detay, dbg olum-detay / kill-detay,
-- dbg def ozeti (round basinda, dusman basina), round / harita basliklari, dbg round sonu. dbg duello ve
-- dbg sikmadi satirlari N.shots / N.rage'de bu bicimleyicilerle yazilir.
-- Vurulabilirlik: her dusman kendi sirasinda 4 tick'te bir (GS V1.0.54) gozumuzden kafa / gogus / pelvis izi;
-- N.rage.dmg'nin 2 tick'ten taze sonucu varsa iz atilmaz.
-------------------------------------------------------------------------------
do
    local U, D = N.util, N.dlog
    local K = N.K
    D.EVERY, D.VIS_GAP, D.MIN_DMG = 4, 16, 10
    -- vis: dusman basina vurulabilirlik kaydi (tick); nxt: tarama sirasi; def: suren defensive bolumu;
    -- round_def: round boyunca dusman adina bolum ozeti; last_def: son bolumun bittigi tick; shots: dusman atislari.
    D.vis, D.nxt, D.def, D.round_def, D.round_order, D.last_def, D.shots = {}, {}, {}, {}, {}, {}, {}
    D.last_header, D.header_n, D.map_pending, D.map_printed, D.probe = nil, -1, "load", nil, {}
    D.wake_log = {}
    D.MANUAL = { [1] = "sol", [2] = "arka", [3] = "sag" }

    D.on = function()
        return N.on("debug_log")
    end

    -- Belirsiz API (GUESS) bir kez loga: oyundaki ilk sonuc belirsizligi kapatir.
    D.settle = function(key, text)
        if D.probe[key] == nil then
            D.probe[key] = true
            N.log.line("teshis: " .. text)
        end
    end

    -- Haritadaki bolge adi (m_szLastPlaceName metin donmezse "?").
    D.place = function(ent)
        local v = U.prop(ent, "m_szLastPlaceName")
        if type(v) == "string" then
            D.settle("place", "yer adi (m_szLastPlaceName) metin olarak okunuyor")
            v = v:gsub("[^%w_%-]", "")
            return v ~= "" and v or "?"
        end
        D.settle("place", fmt("yer adi (m_szLastPlaceName) okunamadi (%s) -> @?", type(v)))
        return "?"
    end

    -- player_resource m_iPing (oyuncu index'iyle); okunamazsa nil (ping yazilmaz).
    D.ping = function(ent)
        local idx = U.index(ent)
        if idx == nil then
            return nil
        end
        local ok, v = pcall(function()
            return player_resource.get_prop("m_iPing", idx)
        end)
        if ok and U.finite(v) then
            D.settle("ping", "ping (player_resource m_iPing) okunuyor")
            return v
        end
        D.settle("ping", "ping (player_resource m_iPing) okunamadi -> ping yazilmaz")
        return nil
    end

    D.wname = function(ent)
        local w = U.winfo(ent)
        if w == nil then
            return "?"
        end
        return w.name == "revolver" and "r8" or w.name
    end

    -- Konum, mesafe, hareket, bakis, can, silah, ping. lp verilmezse (ya da ent kendisiyse) mesafe / bakis yok.
    D.where = function(ent, lp)
        local o = U.origin(ent)
        if o == nil then
            return "@?"
        end
        local parts = { fmt("@%s(%d,%d,%d)", D.place(ent), U.R(o.x), U.R(o.y), U.R(o.z)) }
        local mine = (lp ~= nil and lp ~= ent) and U.origin(lp) or nil
        if mine ~= nil then
            parts[#parts + 1] = fmt("%du h%+d", U.R(U.dist(o, mine)), U.R(o.z - mine.z))
        end
        local v = U.vel(ent)
        parts[#parts + 1] = fmt("v%d", U.R(sqrt(v.x * v.x + v.y * v.y)))
        -- GS V1.0.64: olen oyuncunun yerde bayragi silinir; olumcul vurulmada "havada" yazilmaz.
        local hp = U.num(ent, "m_iHealth")
        if not (hp ~= nil and hp <= 0) and U.flag(ent, "ON_GROUND") == false then
            parts[#parts + 1] = fmt("havada vz%+d", U.R(v.z))
        end
        local duck = U.num(ent, "m_flDuckAmount")
        if duck ~= nil and duck > 0.05 then
            parts[#parts + 1] = fmt("duck%d", U.R(duck * 100))
        end
        if mine ~= nil then
            local yaw = U.prop(ent, "m_angEyeAngles[1]")
            if U.finite(yaw) then
                parts[#parts + 1] = fmt("bak%+d", U.R(U.norm(yaw - U.yaw_to(o, mine))))
            end
            local pitch = U.prop(ent, "m_angEyeAngles[0]")
            if U.finite(pitch) then
                parts[#parts + 1] = fmt("p%d", U.R(pitch))
            end
        end
        if hp ~= nil then
            parts[#parts + 1] = fmt("hp%d", U.R(hp))
        end
        parts[#parts + 1] = D.wname(ent)
        local ping = D.ping(ent)
        if ping ~= nil then
            parts[#parts + 1] = fmt("ping%d", U.R(ping))
        end
        return concat(parts, " ")
    end

    -- Dusmanin kaydi: sahte kayit (defensive) ve derinligi, biten defensive, LC, AA deseni, resolver seviyesi.
    D.rec = function(ent)
        local idx = U.index(ent)
        local t = idx ~= nil and N.track.p[idx] or nil
        if t == nil then
            return "kayit ?"
        end
        local tick = U.tick()
        local parts = {}
        if tick <= t.def_until then
            parts[#parts + 1] = fmt("DEF geri %dt", U.R(t.def_back or 1))
        else
            local last = D.last_def[idx]
            if last ~= nil and tick >= last and tick - last <= 64 then
                parts[#parts + 1] = fmt("def %dt once bitti", U.R(tick - last))
            end
        end
        if tick <= t.lc_until then
            parts[#parts + 1] = "LC"
        end
        if tick <= t.fd_until then
            parts[#parts + 1] = "FD"
        end
        parts[#parts + 1] = "AA " .. N.profile.text(t)
        local r = N.rage.t[idx]
        if r ~= nil then
            parts[#parts + 1] = fmt("seviye %d", U.R(r.level))
        end
        return concat(parts, " ")
    end

    -- Senin durumun. foe verilirse "yon" = gonderdigin yaw ile ona yon arasi (0 = ona bakiyorsun, 180 = sirtin
    -- donuk); "dsy" = gercek - sahte aci (antiaim getter'lari).
    D.me = function(lp, foe)
        local st = N.st
        local parts = { "ben " .. D.where(lp, nil), tostring(st.label or "?") }
        local aa = {}
        local mine, theirs = U.origin(lp), foe ~= nil and U.origin(foe) or nil
        if mine ~= nil and theirs ~= nil then
            aa[#aa + 1] = fmt("yon %+d", U.R(U.norm(N.aa.last.yaw - U.yaw_to(mine, theirs))))
        end
        local real, fake = U.call(antiaim.get_real_angle), U.call(antiaim.get_fake_angle)
        if U.finite(real) and U.finite(fake) then
            aa[#aa + 1] = fmt("dsy %+d", U.R(U.norm(real - fake)))
        end
        if #aa > 0 then
            parts[#parts + 1] = "aa " .. concat(aa, " ")
        end
        if D.MANUAL[st.manual] ~= nil then
            parts[#parts + 1] = "manual " .. D.MANUAL[st.manual]
        end
        if st.state == "Freestanding" then
            parts[#parts + 1] = "FS"
        end
        if N.ref.on("autopeek") then
            parts[#parts + 1] = "peek tusu"
        elseif N.afk.on then
            parts[#parts + 1] = "afk"
        end
        parts[#parts + 1] = N.shots.exploit_status()
        local choked = U.call(engine.get_choked_commands)
        if U.finite(choked) then
            parts[#parts + 1] = fmt("bogma %d", U.R(choked))
        end
        return concat(parts, " | ")
    end

    -- Silahin hazir mi: bos sarjor, surgu / atis bekleme, durbun.
    D.ready = function(lp)
        local w = U.winfo(lp)
        if w == nil or w.ent == nil then
            return "silah ?"
        end
        local clip = U.num(w.ent, "m_iClip1")
        if clip ~= nil and clip == 0 then
            return "sarjor bos"
        end
        local wait = max(U.num(w.ent, "m_flNextPrimaryAttack") or 0, U.num(lp, "m_flNextAttack") or 0) - U.cur()
        if wait > 0.02 then
            return fmt("silah %.2fs sonra hazir", wait)
        end
        return "silah hazir" .. ((U.is_sniper(w.name) and U.num(lp, "m_bIsScoped") ~= 1) and " (durbun kapali)" or "")
    end

    -- Mermili silah mi (olum olayindaki silah adi; bomba / ates / bicak / zeus degil).
    D.gun = function(weapon)
        local w = tostring(weapon or "")
        return w ~= "" and not K.NON_BULLET[w] and not w:find("knife", 1, true) and w ~= "bayonet" and w ~= "taser"
    end

    -- Gozunden dusmanin kafasina / govdesine mermi geciyor mu: her dusman kendi sirasinda 4 tick'te bir.
    D.scan = function(lp, tick)
        local w = U.winfo(lp)
        if not U.is_gun(w) or U.melee(w) ~= nil then
            return
        end
        local eye = U.eye(lp)
        if eye == nil then
            return
        end
        -- Fake duck'ta aimbot ayakta goz yuksekliginden sikar.
        if N.st.fd then
            local o = U.origin(lp)
            if o ~= nil and eye.z < o.z + 64 then
                eye = vec3_t(eye.x, eye.y, o.z + 64)
            end
        end
        for i, ent in ipairs(N.exposure.enemies()) do
            local idx = U.index(ent)
            if idx ~= nil then
                local due = D.nxt[idx]
                if due == nil then
                    D.nxt[idx] = tick + (i - 1) % D.EVERY
                elseif tick < due - D.EVERY or tick >= due then
                    D.nxt[idx] = tick + D.EVERY
                    D.scan_one(ent, idx, lp, eye, tick)
                end
            end
        end
    end

    D.scan_one = function(ent, idx, lp, eye, tick)
        local dh, db
        local c = N.rage.dmg_cache[idx]
        if c ~= nil and tick >= c.tick and tick - c.tick <= 2 then
            dh, db = c.head, c.body
        else
            dh = U.tdmg(eye, U.hitbox(ent, "HEAD"), lp, ent)
            db = U.tdmg(eye, U.hitbox(ent, "CHEST"), lp, ent)
            if db <= 0 then
                db = U.tdmg(eye, U.hitbox(ent, "PELVIS"), lp, ent)
            end
        end
        local v = D.vis[idx]
        if dh >= D.MIN_DMG or db >= D.MIN_DMG then
            if v == nil or tick < v.last or tick - v.last > D.VIS_GAP then
                v = { first = tick, last = tick, fired = 0, other = 0 }
                D.vis[idx] = v
            end
            v.last, v.dh, v.db = tick, dh, db
            -- Oldurecek hasar ilk ne zaman gorundu (MD 100 ustu can + fark; alti canla sinirli).
            if v.lethal == nil then
                local md, hp = N.ref.md_eff(N.st.wgroup), U.hp(ent)
                if md ~= nil and hp > 0 then
                    local need = md >= 100 and hp + md - 100 or min(md, hp)
                    if max(dh, db) >= need then
                        v.lethal = tick
                    end
                end
            end
        elseif v ~= nil and (tick < v.last or tick - v.last > D.VIS_GAP) then
            D.vis[idx] = nil
        end
    end

    -- Dusmanlarin defensive bolumleri (sahte kayit tick'leri): kayit gercek olunca ya da dusman kaybolunca biter.
    D.track_def = function(tick)
        local present = {}
        for _, ent in ipairs(N.exposure.enemies()) do
            local idx = U.index(ent)
            local t = idx ~= nil and N.track.p[idx] or nil
            if t ~= nil then
                present[idx] = true
                local in_def = tick <= t.def_until
                local ep = D.def[idx]
                if in_def and ep == nil then
                    D.def[idx] = { start = tick, last = tick, speed = U.speed(ent), name = U.name(ent) }
                elseif in_def then
                    ep.last = tick
                elseif ep ~= nil then
                    D.end_def(idx, ep, tick)
                end
            end
        end
        for idx, ep in pairs(D.def) do
            if not present[idx] then
                D.end_def(idx, ep, tick)
            end
        end
    end

    D.end_def = function(idx, ep, tick)
        D.def[idx], D.last_def[idx] = nil, tick
        local r = D.round_def[ep.name]
        if r == nil then
            r = { n = 0, ticks = 0, longest = 0, moving = 0 }
            D.round_def[ep.name] = r
            D.round_order[#D.round_order + 1] = ep.name
        end
        local length = max(1, ep.last - ep.start + 1)
        r.n, r.ticks, r.longest = r.n + 1, r.ticks + length, max(r.longest, length)
        if ep.speed >= 100 then
            r.moving = r.moving + 1
        end
    end

    -- SETUP_COMMAND (canliyken): harita basligi, vurulabilirlik taramasi, defensive bolumleri.
    D.tick = function()
        if not D.on() then
            return
        end
        local tick = U.tick()
        D.map_header()
        D.wakes(N.st.lp, tick)
        D.scan(N.st.lp, tick)
        D.track_def(tick)
    end

    -- N4: az once uyanan (dormant / olu -> ilk kayit, T.wake) dusman NEAR icindeyse "dbg uyandi" (dusman basina 5
    -- sn'de bir). Ilk gorus: uyandigi anda kafami goruyor mu (E.check, tahminsiz).
    D.wakes = function(lp, tick)
        local now = U.now()
        local mine, head = nil, nil
        for idx, t in pairs(N.track.p) do
            if t.wake_new then
                t.wake_new = nil
                local last = D.wake_log[idx]
                if t.wake_tick ~= nil and tick >= t.wake_tick and tick - t.wake_tick <= 2
                    and (last == nil or now < last or now - last >= 5) then
                    mine = mine or U.origin(lp)
                    local o = U.origin(t.ent)
                    local dist = (mine ~= nil and o ~= nil) and U.dist(o, mine) or nil
                    if dist ~= nil and dist <= N.K.NEAR then
                        D.wake_log[idx] = now
                        head = head or U.hitbox(lp, "HEAD")
                        N.log.line(fmt("dbg uyandi: %s %d u, %s sn uyudu, ilk gorus %s", U.name(t.ent), U.R(dist),
                            t.slept_ticks ~= nil and fmt("%.1f", t.slept_ticks * U.ipt()) or "?",
                            N.exposure.check(t.ent, lp, head, false) and "goruyor" or "gormuyor"))
                    end
                end
            end
        end
    end

    -- AIMBOT_SHOOT: vurulabilirlik kayitlarinda atis sayilari, ates anindaki detay satiri (sonuc satirinin altina).
    D.on_shoot = function(rec, shot)
        if not D.on() then
            return
        end
        for idx, v in pairs(D.vis) do
            if idx == rec.idx then
                v.fired = v.fired + 1
            else
                v.other = v.other + 1
            end
        end
        rec.dbg = D.fire_info(rec, shot)
    end

    D.fire_info = function(rec, shot)
        local lp, ent, idx = N.st.lp, rec.ent, rec.idx
        local tick, ti = U.tick(), U.ipt()
        local flags = { fmt("bt %dt", U.R(rec.bt)) }
        if rec.hc ~= nil then
            flags[#flags + 1] = fmt("hc %d%%", U.R(rec.hc))
        end
        local aim, o = N.shots.field(shot, "hitpoint_pos"), U.origin(ent)
        if o ~= nil and U.okvec(aim) then
            flags[#flags + 1] = fmt("nisan z%+d", U.R(aim.z - o.z))
        end
        -- Ilk atis gecikmesi (GS V1.0.54): vurulabilir oldugundan ve oldurecek hasar gorundugunden beri.
        local v = idx ~= nil and D.vis[idx] or nil
        if v ~= nil and tick >= v.last and tick - v.last <= D.VIS_GAP then
            flags[#flags + 1] = fmt("vurulabilir %.2fs", (tick - v.first) * ti)
            if v.fired <= 1 then
                flags[#flags + 1] = v.lethal ~= nil and fmt("ates-hakki %.2fs", (tick - v.lethal) * ti) or "ates-hakki yok"
            else
                flags[#flags + 1] = fmt("%d. atis", U.R(v.fired))
            end
        else
            flags[#flags + 1] = "vurulabilir yok"
        end
        local d = idx ~= nil and N.shots.duels[idx] or nil
        if d ~= nil and d.they_at ~= nil then
            flags[#flags + 1] = fmt("o-gordu %.2fs", max(0, U.now() - d.they_at))
        end
        return fmt("dbg atis-detay: %s %s | %s | aimbot %s | %s", rec.name, D.where(ent, lp), D.rec(ent),
            concat(flags, " "), lp ~= nil and D.me(lp, ent) or "ben ?")
    end

    D.print_shot = function(rec)
        if rec.dbg ~= nil and D.on() then
            N.log.line(rec.dbg)
        end
    end

    -- Dusman atislari (weapon_fire): son iki atisi arasi (DT cifti mi).
    D.enemy_fire = function(idx)
        if not D.on() then
            return
        end
        local last = D.shots[idx]
        D.shots[idx] = { prev = last ~= nil and last.last or nil, last = U.now() }
    end

    -- Bize mermi (player_hurt, mermili silah): iz duvardan mi, onun son iki atisi, biz onu vurabiliyor muyduk.
    D.hurt = function(attacker, hitgroup, dmg, weapon)
        local lp = N.st.lp
        if not D.on() or lp == nil then
            return
        end
        local idx = U.index(attacker)
        -- GS V1.0.50: duvardan kafa olumlerinin payi icin payda (saldiranin gozunden vurulan yere duz iz).
        local wall = ""
        local eye = U.eye(attacker)
        local spot = U.hitbox(lp, hitgroup == 1 and "HEAD" or (hitgroup == 3 and "PELVIS" or "CHEST"))
        if eye ~= nil and spot ~= nil then
            local frac, hit, ok = U.tline(eye, spot, attacker)
            if ok then
                wall = (frac < 0.97 and hit ~= lp) and " | iz duvardan" or " | iz acik"
            end
        end
        local gap = ""
        local s = idx ~= nil and D.shots[idx] or nil
        if s ~= nil and s.prev ~= nil and s.last >= s.prev and s.last - s.prev < 1 then
            local dt = s.last - s.prev
            gap = fmt(" | son iki atisi arasi %.2fs%s", dt, dt < 0.2 and " (DT)" or "")
        end
        local v, tick = idx ~= nil and D.vis[idx] or nil, U.tick()
        local mine = "sen onu vuramiyordun"
        if v ~= nil and tick >= v.last and tick - v.last <= D.VIS_GAP then
            mine = fmt("sen onu %.2fs vurulabilir gordun, %d ates", (v.last - v.first) * U.ipt(), U.R(v.fired))
        end
        N.log.line(fmt("dbg vurulma-detay: %s %s -%d %s%s | %s | %s%s | %s | %s", U.name(attacker),
            K.HITGROUPS[hitgroup or -1] or "?", U.R(dmg), tostring(weapon), wall, D.where(attacker, lp),
            D.rec(attacker), gap, mine, D.me(lp, attacker)))
    end

    -- player_death etiketleri: headshot, duvardan (delinen), noscope, smoke icinden, kor.
    D.tags = function(e)
        local F = N.shots.field
        local function yes(name)
            local v = F(e, name)
            return v == true or v == 1
        end
        local tags = {}
        if yes("headshot") then
            tags[#tags + 1] = "headshot"
        end
        local pen = tonumber(F(e, "penetrated"))
        if U.finite(pen) and pen > 0 then
            tags[#tags + 1] = fmt("duvardan (%d)", U.R(pen))
        end
        if yes("noscope") then
            tags[#tags + 1] = "noscope"
        end
        if yes("thrusmoke") then
            tags[#tags + 1] = "smoke icinden"
        end
        if yes("attackerblind") then
            tags[#tags + 1] = "kor"
        end
        return #tags > 0 and (" " .. concat(tags, ", ")) or ""
    end

    D.death = function(e, attacker, lp, weapon)
        if D.on() then
            N.log.line(fmt("dbg olum-detay: %s %s%s | %s | %s | %s", U.name(attacker), weapon, D.tags(e),
                D.where(attacker, lp), D.rec(attacker), D.me(lp, attacker)))
        end
    end

    D.kill = function(e, victim, lp, weapon)
        if D.on() then
            N.log.line(fmt("dbg kill-detay: %s %s%s | %s", U.name(victim), weapon, D.tags(e), D.where(victim, lp)))
        end
    end

    D.map = function()
        local m = U.call(engine.get_level_name_short)
        return (type(m) == "string" and m ~= "") and m or "?"
    end

    D.header = function()
        local played = U.game("m_totalRoundsPlayed")
        local team = U.num(U.call(entity_list.get_local_player), "m_iTeamNum")
        local lat = U.call(engine.get_latency)
        return fmt("dbg ===== round %s | %s | sen %s | ping %s =====",
            played ~= nil and fmt("%d", U.R(played) + 1) or "?", D.map(), team == 2 and "T" or (team == 3 and "CT" or "?"),
            U.finite(lat) and fmt("%dms", U.R(lat * 1000)) or "?")
    end

    -- Harita basligi: yuklemeden / harita degisiminden sonra ilk round basinda ya da canli tick'te bir kez
    -- (harita degisiminde native ayar ozeti de; yuklemede o zaten yazildi).
    D.map_header = function()
        local why = D.map_pending
        if why == nil or not D.on() then
            return
        end
        local m = D.map()
        if m == "?" then
            return
        end
        D.map_pending = nil
        if why ~= "newmap" and m == D.map_printed then
            return
        end
        D.map_printed = m
        N.log.line(fmt("dbg ===== harita %s =====", m))
        if why ~= "load" then
            N.shots.settings_line()
        end
    end

    -- Round basi (round_start, DM dogusu): acik duellolar kapanir, def ozeti, baslik. GS V1.0.20: round_start arka
    -- arkaya iki kez gelirse ve arada satir yoksa baslik ikinci kez yazilmaz (donus false: round basi satirlari
    -- da tekrar yazilmasin). Cagiran, round basi satirlarindan sonra D.round_done() der.
    D.round_begin = function()
        local fresh = true
        if D.on() then
            D.map_header()
            local S = N.shots
            for idx in pairs(S.duels) do
                S.duel_close(idx, "round bitti")
            end
            local tick = U.tick()
            for idx, ep in pairs(D.def) do
                D.end_def(idx, ep, tick)
            end
            for _, name in ipairs(D.round_order) do
                local r = D.round_def[name]
                N.log.line(fmt("dbg def ozeti: %s %d kez, toplam %dt, ort %.1ft, en uzun %dt, %d tanesi hareketliyken",
                    name, r.n, r.ticks, r.ticks / r.n, r.longest, r.moving))
            end
            N.charge.round_line()
            local header = D.header()
            if header ~= D.last_header or N.log.n ~= D.header_n then
                N.log.line(header)
            else
                fresh = false
            end
            D.last_header = header
        end
        D.reset()
        N.charge.round_new()
        return fresh
    end

    D.round_done = function()
        D.header_n = N.log.n
    end

    D.round_end = function(e)
        if not D.on() then
            return
        end
        local winner = tonumber(N.shots.field(e, "winner"))
        if winner ~= 2 and winner ~= 3 then
            N.log.line("dbg round sonu: kazanan yok (oyun basi / yeniden baslatma)")
            return
        end
        local team = U.num(U.call(entity_list.get_local_player), "m_iTeamNum")
        N.log.line(fmt("dbg round sonu: %s kazandi%s", winner == 2 and "T" or "CT",
            team == winner and " (senin takimin)" or ""))
    end

    D.reset = function()
        D.vis, D.nxt, D.def, D.round_def, D.round_order, D.last_def, D.shots = {}, {}, {}, {}, {}, {}, {}
    end

    -- Harita / oturum degisimi: tick'e bagli her sey silinir, duellolar yazilmadan atilir.
    D.map_reset = function(newmap)
        D.reset()
        N.shots.duels = {}
        D.last_header, D.header_n = nil, -1
        if newmap then
            D.map_pending = "newmap"
        else
            D.map_pending = D.map_pending or "reset"
        end
    end
end

-------------------------------------------------------------------------------
-- Istatistik (GS aim_stats / stats / draw_stats): durum basina dusman isabeti / kafa / iska, DT dolu ve DEF zorlanan
-- tick payi, KD (sadece dusman; durum olay anindaki), atis sonuclari (atis / isabet / correction / spread / diger), lag
-- ve temiz atis, AI peek. Iki sayac kumesi: sets[1] oturum (Stats paneli; sadece "Reset stats" sifirlar), sets[2]
-- harita ("harita ozeti" satiri harita degisiminde, kapanista ve 20 roundda bir; harita degisiminde sifirlanir). Her
-- olay ikisine birden yazilir. Resolver paneli tahmini (cozum / HIT) de burada (dusman basina oturum sayaclari).
-------------------------------------------------------------------------------
do
    local U, ST, K = N.util, N.stats, N.K
    ST.round_no = 1
    -- GS sample_exploit: kendi atisindan sonraki 1 sn (atis sarji bosaltir) ve sarj tutulurken DT / DEF payina girmez.
    ST.GRACE, ST.EVERY = 1, 20
    -- NL V1.0 on bilgileri: spread %2, diger %8 (agirlik 8); cozumde son 4 sonucun correction payi.
    ST.PRIOR_SPREAD, ST.PRIOR_OTHER, ST.PRIOR_W, ST.LAST = 0.02, 0.08, 8, 4
    -- Panel / ozet sirasi: builder durumlari, sonra AA'si olmayanlar (GS STAT_ORDER).
    ST.RANK = {}
    for i, state in ipairs(K.STATES) do
        ST.RANK[state] = i
    end
    for i, state in ipairs({ "Legit", "Spin", "Ladder" }) do
        ST.RANK[state] = #K.STATES + i
    end

    ST.new_set = function()
        return { states = {}, order = {}, kills = 0, deaths = 0, shots = 0, hits = 0, corr = 0, spread = 0, other = 0,
            lag_s = 0, lag_h = 0, clean_s = 0, clean_h = 0, peeks = 0, ai_shots = 0, ai_hits = 0, empty = 0, hurt = 0,
            ticks = 0, rounds = 0, start = nil, last = nil, map = nil, map_try = -1000 }
    end

    -- sets[1] oturum, sets[2] harita; enemy[anahtar]: resolver paneli icin dusman basina atis / spread / diger ve son 4
    -- sonucun correction olup olmadigi.
    ST.reset_all = function()
        ST.sets, ST.enemy = { ST.new_set(), ST.new_set() }, {}
    end
    ST.reset_all()

    ST.get = function(set, state)
        local s = set.states[state]
        if s == nil then
            s = { hits = 0, head = 0, misses = 0, n = 0, dt = 0, full = 0, def = 0, kills = 0, deaths = 0 }
            set.states[state] = s
            set.order[#set.order + 1] = state
        end
        return s
    end

    -- Iki kumeye birden +1: state verilirse o durumun alanina, yoksa kumenin alanina.
    ST.add = function(field, state)
        for _, set in ipairs(ST.sets) do
            local t = state ~= nil and ST.get(set, state) or set
            t[field] = t[field] + 1
        end
    end

    ST.enemy_hit = function(state, head)
        ST.add("hits", state)
        if head then
            ST.add("head", state)
        end
    end

    ST.enemy_miss = function(state)
        ST.add("misses", state)
    end

    -- Olduren / olen dusmansa (S.on_death): durum olay anindaki etiket.
    ST.kd = function(field)
        ST.add(field)
        ST.add(field, N.st.label)
    end

    -- Atis sonucu (S.on_hit reason nil, S.on_miss reason): GS aim_stats. "spread (missed safe)" (safe point'li atis,
    -- API 7.4) da spread sayilir. Lag / temiz sadece kaydi bilinen atista ve
    -- olum sebepli iska haric; lag = atis aninda DEF / LC / TP / FD etiketi (atis ozeti ile ayni), temiz = digerleri.
    ST.result = function(rec, reason)
        local kind = reason == nil and "hits" or (((reason == "resolver" or reason == "jitter") and "corr")
            or (reason:sub(1, 6) == "spread" and "spread") or "other")
        local death = reason ~= nil and reason:find("death", 1, true) ~= nil
        local tags = rec.tags or {}
        local lag = tags.DEF or tags.LC or tags.TP or tags.FD
        local hit = reason == nil and 1 or 0
        for _, set in ipairs(ST.sets) do
            set.shots = set.shots + 1
            set[kind] = set[kind] + 1
            if not rec.stub and not death then
                if lag then
                    set.lag_s, set.lag_h = set.lag_s + 1, set.lag_h + hit
                else
                    set.clean_s, set.clean_h = set.clean_s + 1, set.clean_h + hit
                end
            end
        end
        local key = rec.key or (rec.idx ~= nil and ("i" .. rec.idx)) or nil
        if death or key == nil then
            return
        end
        local e = ST.enemy[key]
        if e == nil then
            e = { shots = 0, spread = 0, other = 0, last = {} }
            ST.enemy[key] = e
        end
        e.shots = e.shots + 1
        if kind == "spread" or kind == "other" then
            e[kind] = e[kind] + 1
        end
        e.last[#e.last + 1] = kind == "corr"
        if #e.last > ST.LAST then
            tremove(e.last, 1)
        end
    end

    -- SETUP_COMMAND (N.charge.tick ve N.ex.defensive'den sonra): harita suresi / adi, durum basina DT dolu ve DEF
    -- zorlanan tick payi (DT ya da HS acikken; atistan sonraki 1 sn ve sarj tutulurken sayilmaz).
    ST.sample = function()
        local st, CH = N.st, N.charge
        local now, tick = U.now(), U.tick()
        local m = ST.sets[2]
        m.ticks, m.start, m.last = m.ticks + 1, m.start or now, now
        if m.map == nil and (tick - m.map_try >= 64 or tick < m.map_try) then
            m.map_try = tick
            local name = N.dlog.map()
            if name ~= "?" then
                m.map = name
            end
        end
        local dt = CH.dt_was == true
        if not dt and not N.ref.on("hs") then
            return
        end
        if (now >= st.last_shot and now - st.last_shot <= ST.GRACE) or N.rc.held() then
            return
        end
        local full = dt and (CH.m or 0) > 0 and (CH.c or 0) >= CH.m
        local forced = N.ex.forced == true
        for _, set in ipairs(ST.sets) do
            local e = ST.get(set, st.label)
            e.n = e.n + 1
            if dt then
                e.dt = e.dt + 1
                e.full = e.full + (full and 1 or 0)
            end
            e.def = e.def + (forced and 1 or 0)
        end
    end

    -- Tamsayi yuzde (GS: asagi yuvarlanir) ya da payda 0 ise nil.
    ST.pct = function(a, b)
        if b <= 0 then
            return nil
        end
        return floor(100 * a / b)
    end

    ST.sorted = function(set)
        local list = {}
        for i, state in ipairs(set.order) do
            list[i] = state
        end
        table.sort(list, function(a, b)
            local ra, rb = ST.RANK[a] or 99, ST.RANK[b] or 99
            if ra ~= rb then
                return ra < rb
            end
            return a < b
        end)
        return list
    end

    -- Resolver paneli tahmini (NL V1.0 modeli; panel tick basina bir kez cagirir): cozum = %80 x0.8 (jitter genligi
    -- >= 120; canli desen yokken hafizadaki aliskanlik jitter) x0.9 (hedef havada) x0.5 (sahte kayit) x(1 - son 4
    -- sonuctaki correction payi / 2). HIT = cozum x (1 - spread) x (1 - diger); dusmanin oranlari %2 / %8 on bilgisine
    -- 8 atis agirligiyla cekilir. Donus: cozum %, HIT % (tamsayi).
    ST.estimate = function(ent, idx, key, p)
        local tr = idx ~= nil and N.track.p[idx] or nil
        local v = 0.8
        local wide
        if tr ~= nil and tr.pattern ~= "?" then
            wide = tr.pattern == "jitter" and U.finite(tr.amp) and tr.amp >= 120
        else
            local h = N.profile.habit(p)
            wide = h ~= nil and h.pattern == "jitter"
        end
        if wide then
            v = v * 0.8
        end
        if U.flag(ent, "ON_GROUND") == false then
            v = v * 0.9
        end
        if idx ~= nil and N.track.fake(idx) then
            v = v * 0.5
        end
        local e = key ~= nil and ST.enemy[key] or nil
        local shots, spread, other = 0, 0, 0
        if e ~= nil then
            local c = 0
            for _, corr in ipairs(e.last) do
                c = c + (corr and 1 or 0)
            end
            if #e.last > 0 then
                v = v * (1 - c / #e.last / 2)
            end
            shots, spread, other = e.shots, e.spread, e.other
        end
        local w = ST.PRIOR_W
        local rs = (spread + ST.PRIOR_SPREAD * w) / (shots + w)
        local ro = (other + ST.PRIOR_OTHER * w) / (shots + w)
        return U.R(v * 100), U.R(v * (1 - rs) * (1 - ro) * 100)
    end

    -- Stats paneli satirlari (GS draw_stats duzeni): { yazi, baslik mi, oncesinde bosluk mu }. Panel tick basina bir kez.
    ST.rows = function()
        local s = ST.sets[1]
        local B = N.brute
        local rows = {}
        local function add(text, head, gap)
            rows[#rows + 1] = { text, head == true, gap == true }
        end
        local function share(a, b)
            local p = ST.pct(a, b)
            return p ~= nil and fmt("%d%%", p) or "-"
        end
        add("AA STATS   HIT / HEAD / MISS / DT / DEF", true)
        local order = ST.sorted(s)
        for _, state in ipairs(order) do
            local e = s.states[state]
            add(fmt("%s   %d / %d / %d / %s / %s", state:upper(), e.hits, e.head, e.misses, share(e.full, e.dt),
                share(e.def, e.n)))
        end
        if s.shots > 0 then
            add("AIM   SHOT / HIT / CORR / SPREAD / OTHER", true, true)
            add(fmt("ALL   %d / %d / %d / %d / %d", s.shots, s.hits, s.corr, s.spread, s.other))
            add(fmt("LAG   %d / %d   TEMIZ   %d / %d", s.lag_h, s.lag_s, s.clean_h, s.clean_s))
        end
        if s.kills + s.deaths > 0 then
            add("KD   OLDURDUN / OLDUN", true, true)
            for _, state in ipairs(order) do
                local e = s.states[state]
                if e.kills + e.deaths > 0 then
                    add(fmt("%s   %d / %d", state:upper(), e.kills, e.deaths))
                end
            end
        end
        if s.peeks > 0 then
            add("AI PEEK   PEEK / ATIS / ISABET / BOS / VURULDUN", true, true)
            add(fmt("AI PEEK   %d / %d / %d / %d / %d", s.peeks, s.ai_shots, s.ai_hits, s.empty, s.hurt))
        end
        -- * = verisi olmayan dusmanlara uygulanan faz; x = kotu bilinen (12+ mermi, %55+ kafa), ilerlemede atlanir.
        add("AA FAZ   KAFA ISABETI / MERMI", true, true)
        for _, g in ipairs(K.BRUTE_GROUPS) do
            local parts = { g:upper() }
            for phase = 0, #K.BRUTE_PHASES do
                local stat = B.phases[g][phase]
                parts[#parts + 1] = fmt("%d%s %d/%d", phase, phase == (B.default[g] or 0) and "*"
                    or (B.known_bad(g, phase) and "x" or ""), U.R(stat.hits), U.R(stat.shots))
            end
            add(concat(parts, "   "))
        end
        return rows
    end

    -- "harita ozeti" satiri: panelin sayilari yuklenen loga (harita kumesi). faz kafa = grubun varsayilan fazi ve kafa
    -- isabeti / mermi (kalici faz ogrenmesi, sifirlanmaz).
    ST.map_text = function(set)
        local kd = {}
        local dt, full, n, def = 0, 0, 0, 0
        for _, state in ipairs(ST.sorted(set)) do
            local e = set.states[state]
            if e.kills + e.deaths > 0 then
                kd[#kd + 1] = fmt("%s %d/%d", state, e.kills, e.deaths)
            end
            dt, full, n, def = dt + e.dt, full + e.full, n + e.n, def + e.def
        end
        local B = N.brute
        local faz = {}
        for _, g in ipairs(K.BRUTE_GROUPS) do
            local d = B.default[g] or 0
            local stat = B.phases[g][d]
            faz[#faz + 1] = fmt("%s %d:%d/%d", g, d, U.R(stat.hits), U.R(stat.shots))
        end
        local pf, pd = ST.pct(full, dt), ST.pct(def, n)
        local mins = (set.start ~= nil and set.last ~= nil) and U.R(max(0, set.last - set.start) / 60) or 0
        return fmt("harita ozeti: %s %d dk, %d round | KD %d/%d%s | atis %d isabet %d correction %d spread %d diger %d"
            .. " | lag %d/%d temiz %d/%d | ai peek %d/%d/%d/%d/%d | DT dolu %s DEF %s | faz kafa %s",
            set.map or N.dlog.map(), mins, set.rounds, set.kills, set.deaths,
            #kd > 0 and (" (" .. concat(kd, ", ") .. ")") or "", set.shots, set.hits, set.corr, set.spread, set.other,
            set.lag_h, set.lag_s, set.clean_h, set.clean_s, set.peeks, set.ai_shots, set.ai_hits, set.empty, set.hurt,
            pf ~= nil and fmt("%%%d", pf) or "-", pd ~= nil and fmt("%%%d", pd) or "-", concat(faz, " "))
    end

    -- Bu haritada 1 sn canli tick ya da atis / KD yoksa yazilmaz: ayni harita degisiminde N.map_reset birkac kez gelir
    -- (game_newmap, yerel oyuncu yok, PAINT'te geri gelis) ve aradaki tek tick'lik kume ozet degildir.
    ST.map_line = function()
        local m = ST.sets[2]
        local active = m.ticks >= 64 or m.shots + m.kills + m.deaths > 0
        if active and (N.on("hit_log") or N.on("shot_log")) then
            N.log.line(ST.map_text(m))
            N.brute.compare_line()
        end
    end

    -- Harita degisimi / kapanis: satir, sonra harita kumesi sifirdan.
    ST.map_end = function()
        ST.map_line()
        ST.sets[2] = ST.new_set()
    end

    -- round_start (cift round_start'ta fresh false): 20 roundda bir ara ozet.
    ST.round = function(fresh)
        local m = ST.sets[2]
        if fresh then
            m.rounds = m.rounds + 1
            if m.rounds % ST.EVERY == 0 then
                ST.map_line()
            end
        end
    end

    ST.reset = function()
        ST.reset_all()
        N.shots.shots_round = nil
        N.shots.round = nil
        N.log.line("istatistikler sifirlandi")
    end

    ST.tick = function()
        N.shots.duel_update()
        ST.sample()
    end
end

-------------------------------------------------------------------------------
-- Misc: cvar'lar (sol el, 4:3, FPS boost, ragdoll, developer), clan tag, trash talk, otomatik bomba alma,
-- jump scout. Okunamayan cvar'a hic yazilmaz; ilk yazimda senin degerin saklanir, kapatinca geri yazilir.
-------------------------------------------------------------------------------
do
    local U, MI = N.util, N.misc
    MI.cv, MI.paint_at, MI.js_active, MI.ground_speed, MI.last_buy = {}, -1000, nil, 0, -1000
    MI.tag = { text = "Nykle.win", shown = nil, frame = 0, next_at = 0, active = false }
    MI.ext_warned = false

    MI.cvar = function(name)
        local ok, c = pcall(function()
            return cvars[name]
        end)
        if ok and c ~= nil then
            return c
        end
        return nil
    end

    MI.read = function(c, float)
        local ok, v
        if float then
            ok, v = pcall(c.get_float, c)
        else
            ok, v = pcall(c.get_int, c)
        end
        if ok and U.finite(v) then
            return v
        end
        return nil
    end

    MI.write = function(c, value, float)
        if float then
            return pcall(c.set_float, c, value)
        end
        return pcall(c.set_int, c, value)
    end

    MI.hold = function(name, value, float)
        local h = MI.cv[name]
        if h ~= nil and h.bad then
            return false
        end
        local c = MI.cvar(name)
        local cur = c ~= nil and MI.read(c, float) or nil
        if cur == nil then
            MI.cv[name] = { bad = true }
            N.log.line("cvar " .. name .. " okunamadi, dokunulmadi")
            return false
        end
        if h == nil or not h.held then
            -- Orijinal: hafizadaki C kaydi (onceki oturumun ilk yaziminden onceki deger; oyun cokunce config.cfg'de
            -- bizim degerimiz kalir, GS V1.0.40), yoksa su anki deger ve C kaydi hemen yazilir.
            local saved = N.mem.cvars[name]
            local orig = cur
            if saved ~= nil then
                orig = saved.v
                if abs(saved.v - cur) > 1e-3 then
                    N.log.line(fmt("cvar %s: oyunda %s kalmis (onceki oturum kapanmadan cikmis), asil deger %s hafizadan",
                        name, fmt("%.4g", cur), fmt("%.4g", saved.v)))
                end
            else
                N.mem.cvar_keep(name, cur, float)
            end
            h = { orig = orig, held = true, float = float }
            MI.cv[name] = h
        end
        if abs(cur - value) > 1e-3 then
            MI.write(c, value, float)
            local back = MI.read(c, float)
            if back == nil or abs(back - value) > 1e-3 then
                h.bad = true
                h.held = false
                MI.write(c, h.orig, float)
                N.mem.cvar_drop(name)
                N.log.line("cvar " .. name .. " yazilamadi")
                return false
            end
        end
        return true
    end

    MI.release = function(name)
        local h = MI.cv[name]
        if h == nil or not h.held then
            -- Tutulmayan cvar'in C kaydi: onceki oturum kapanmadan cikmis ve ozellik artik kapali -> asil deger.
            local saved = h == nil and N.mem.cvars[name] or nil
            if saved ~= nil then
                local c = MI.cvar(name)
                if c ~= nil then
                    MI.write(c, saved.v, saved.float)
                    N.log.line(fmt("cvar %s: onceki oturumdan kalan deger birakildi, asil deger %s geri yazildi", name,
                        fmt("%.4g", saved.v)))
                end
                N.mem.cvar_drop(name)
            end
            return
        end
        h.held = false
        local c = MI.cvar(name)
        if c ~= nil then
            MI.write(c, h.orig, h.float)
        end
        MI.cv[name] = nil
        N.mem.cvar_drop(name)
    end

    MI.release_all = function()
        local names = {}
        for name, h in pairs(MI.cv) do
            if h.held then
                names[#names + 1] = name
            end
        end
        for _, name in ipairs(names) do
            MI.release(name)
        end
    end

    -- Saniyede bir (ve yuklemede): cvar'lar ayarlara gore.
    MI.apply = function(force)
        local now = U.now()
        if not force and now >= MI.paint_at and now - MI.paint_at < 1 then
            return
        end
        MI.paint_at = now
        if N.on("left_hand") then
            MI.hold("cl_righthand", 0, false)
        else
            MI.release("cl_righthand")
        end
        local aspect = N.K.ASPECTS[N.v("aspect") or 1]
        if aspect then
            MI.hold("r_aspectratio", aspect, true)
        else
            MI.release("r_aspectratio")
        end
        local fps = N.on("fps_boost")
        for _, name in ipairs(N.K.FPS_CVARS) do
            if fps then
                MI.hold(name, 0, false)
            else
                MI.release(name)
            end
        end
        if fps and N.on("fps_ragdolls") then
            MI.hold("cl_disable_ragdolls", 1, false)
        else
            MI.release("cl_disable_ragdolls")
        end
        if N.on("log_quiet") then
            MI.hold("developer", 0, false)
        else
            MI.release("developer")
        end
        -- Yeni C kaydi (ilk yazim) hemen dosyaya: oyun bu oturumda cokerse de asil deger kalir.
        if N.mem.cv_new then
            N.mem.cv_new = false
            N.mem.save(false)
        end
        -- Roll yasak: native Extended Angles tusu acik -> uyari (script native tusu birakamaz).
        local ext = N.ref.on("ext_angles")
        if ext and not MI.ext_warned then
            MI.ext_warned = true
            N.log.line("UYARI: Extended Angles acik (roll yasak) -> kapat")
        elseif not ext then
            MI.ext_warned = false
        end
        N.st.roll_warn = ext
    end

    -- Clan tag: "N", "Ny", ... "Nykle.win" (kare 0.35 sn), tam ad 4 kare tutulur. Sadece metin degisince yazilir.
    MI.set_tag = function(text)
        if text == MI.tag.shown then
            return
        end
        if pcall(client.set_clantag, text) then
            MI.tag.shown = text
        end
    end

    MI.clantag = function()
        local T = MI.tag
        if not N.on("clantag") then
            MI.clantag_clear()
            return
        end
        local now = U.now()
        if now < T.next_at and now >= T.next_at - 1 then
            return
        end
        T.next_at = now + 0.35
        T.active = true
        local n = #T.text
        T.frame = T.frame % (n + 4) + 1
        MI.set_tag(T.text:sub(1, min(T.frame, n)))
    end

    MI.clantag_clear = function()
        if MI.tag.active or MI.tag.shown ~= nil then
            MI.tag.active = false
            pcall(client.set_clantag, "")
            MI.tag.shown = nil
        end
    end

    MI.KILL_LINES = {
        { "1", "How smart are you, fuck." }, { "Sleep, fuck you", "sleep, you dickhead." },
        { "Holy fuck", "look at this player." }, { "1-0 loser", "that was easy." },
        { "Where are you going", "you fucking brat?" }, { "Nice anti-aim dickhead", "did you work hard on it?" },
        { "Whoa what was that", "how did I kill you, man?" }, { "NYKLE is superior to all of them, fuck." },
        { "What a brilliant mind", "you idiot." }, { "1-0 loser", "you're miserable without NYKLE." },
        { "Lol", "how hard did I fuck you though." }, { "What Lua are you using, man?" },
        { "Whose CFG are you using, man?" }, { "Nice brain", "dickhead." }, { "Hahahaha", "look how you died." },
        { "Oh man", "holy fuck", "nice fucking CFG." }, { "Oh", "I was AFK tweaking my cheat hahahaha." },
        { "What a cringe nickname you have, man." }, { "Weeb dickhead", "you thought I wouldn't kill you?" },
        { "Fucking loser", "who are you trying to kill?" },
        { "Are you raging because you play bad?", "Hahaha idiot." }, { "Learn while I'm still alive, moron." },
        { "Stupid dude", "turn your monitor on, fuck." }, { "1", "dead again, loser." },
        { "Ez", "oops", "sorry, fuck." }, { "Hahaha how I fucked you." }, { "Big brain", "you straight up threw." },
        { "That was easy, bitch", "what the fuck happened?" }, { "Take this, motherfucker", "fuck off." },
        { "I don't even care", "fuck off, idiot." }, { "Easy, loser", "I'm laughing at you, what a funny guy you are." },
        { "Crushed easily", "weak dog and rat." }, { "Holy fuck, what an easy bot you are." },
        { "1", "am I not replying?", "I don't give a fuck." }, { "I don't even give a fuck about you", "bot." },
        { "Moron", "a plain fucking bot." }, { "N Y K L E > A L L" }, { "Get NYKLE for primordial, you fucking loser." },
    }
    MI.DEATH_LINES = {
        { "Holy fuck what a shitty thing I bought", "wish I had bought NYKLE, fuck." }, { "Ew", "dickhead." },
        { "What are you doing", "you messed-up loser?" }, { "Fuck", "did I even shoot?" },
        { "The cheat shat itself." }, { "HOLY FUCK", "you pissed me off so much." },
        { "Why did you do that", "should've given me a clip", "look at this clown, fuck." },
        { "Ahahaha", "yeah", "the son of a bitch killed me again, stupid dude." }, { "Huh", "I see", "nice cheat." },
        { "Fuck", "which jitter should I turn on, man?" }, { "Ew", "filthy dude", "fuck you." },
        { "Fuck", "where are my teammates", "they piss me off so much." }, { "Fuck", "missed again." },
        { "Fuck", "hello", "am I going to shoot or what?" }, { "Heh", "did you even get how you killed me?" },
        { "Fuck", "that fucking desync thing again." }, { "Fuck", "the client froze", "you're lucky." },
        { "I see", "how do you even play", "you idiot?" }, { "Fuck", "the guy just walked straight", "holy fuck." },
        { "What is this", "where did you kill me from?" }, { "Fucked", "fuck you", "WHAT ARE YOU DOING MAN?" },
        { "What can I say", "dickhead", "you play well." },
        { "Fucking guy", "you pissed me off so much", "what are you doing?" },
        { "Fuck", "I admit it, you beat me." }, { "Fuck bro", "look at my team", "it's a disgrace, man." },
        { "The useless dickheads on my team." }, { "Fuck off, bitch." }, { "Fuck", "shot in the back again." },
        { "You got lucky", "what's next, dickhead?" }, { "My God", "look at this miserable scum." },
        { "Hahaha fuck", "the cheat has a good freestand." }, { "Fuck, I'm sick of you." }, { "Not bad." },
        { "Good tracking", "scumbag." },
    }
    MI.talk_until = -1000

    MI.say = function(line)
        if not N.on("enabled") or not N.on("trash_talk") then
            return
        end
        local cmdname = N.v("tt_chat") == 2 and "say_team" or "say"
        local clean = tostring(line):gsub("[\";\r\n]", "")
        pcall(engine.execute_cmd, fmt('%s "%s"', cmdname, clean))
    end

    MI.trash = function(kind, headshot)
        if not N.on("trash_talk") then
            return
        end
        if kind == "kill" and (not N.on("tt_kill") or (N.on("tt_headshot") and not headshot)) then
            return
        end
        if kind == "death" and not N.on("tt_death") then
            return
        end
        local now = U.now()
        if now < MI.talk_until and now >= MI.talk_until - 30 then
            return
        end
        if random(1, 100) > (N.v("tt_chance") or 100) then
            return
        end
        local lines = kind == "kill" and MI.KILL_LINES or MI.DEATH_LINES
        local per_char = kind == "kill" and 24 or 20
        local base = N.v("tt_delay") or 2.3
        local block = lines[random(1, #lines)]
        local delay = 0
        for _, line in ipairs(block) do
            delay = delay + #line / per_char * base
            local text = line
            pcall(client.delay_call, N.cb.wrap("trash talk", function()
                MI.say(text)
            end), delay)
        end
        MI.talk_until = now + delay + 0.5
    end

    -- M5: native buybot bombalari zaten aliyorsa hicbir sey; yoksa round basinda bir kez (3 sn'de en fazla bir).
    MI.buy = function()
        if not N.on("auto_buy") then
            return
        end
        local now = U.now()
        if now >= MI.last_buy and now - MI.last_buy < 3 then
            return
        end
        local P = N.ref
        if P.get("buybot") == true and P.multi("buybot_nades", "High Explosive") == true
            and P.multi("buybot_nades", "Smoke") == true and P.multi("buybot_nades", "Fire") == true then
            return
        end
        MI.last_buy = now
        pcall(client.delay_call, N.cb.wrap("auto buy", function()
            pcall(engine.execute_cmd, "buy hegrenade; buy smokegrenade; buy molotov; buy incgrenade")
        end), 0.3)
    end

    -- M8: scout ile durarak ziplayinca autostrafer kalkistan inise kadar kapali.
    MI.jump_scout = function()
        local st = N.st
        local ref = N.ref.items.autostrafer
        if ref == nil then
            return
        end
        if MI.js_type == nil then
            local ok, v = pcall(ref.get, ref)
            MI.js_type = (ok and type(v) == "boolean") and "ok" or "bad"
            if MI.js_type == "bad" then
                N.log.line("jump scout: autostrafer onay kutusu degil, kapali")
            end
        end
        if MI.js_type ~= "ok" then
            return
        end
        if not st.airborne or st.ladder then
            if MI.js_active then
                N.ov.release("autostrafer")
            end
            MI.js_active = nil
            MI.ground_speed = st.ladder and 1000 or (st.speed or 0)
            return
        end
        if MI.js_active == nil then
            MI.js_active = N.on("jump_scout") and st.weapon == "ssg08" and MI.ground_speed < 10
        end
        if MI.js_active then
            N.ov.set("autostrafer", ref, false)
        end
    end

    MI.paint = function()
        MI.apply(false)
        MI.clantag()
    end
end

-------------------------------------------------------------------------------
-- Cizim: nisangah gostergeleri, manuel oklar, sol liste, resolver paneli, istatistik paneli.
-------------------------------------------------------------------------------
do
    local U, D = N.util, N.draw
    D.ok = false

    D.init = function()
        local ok1, small = pcall(render.create_font, "Verdana", 12, 700, e_font_flags.DROPSHADOW)
        local ok2, big = pcall(render.create_font, "Verdana", 24, 700, e_font_flags.DROPSHADOW)
        D.small = ok1 and small or nil
        D.big = ok2 and big or nil
        D.ok = D.small ~= nil
    end

    D.color = function(key, r, g, b)
        local c = N.ui.e[key]
        if c ~= nil then
            local ok, v = pcall(c.get, c)
            if ok and v ~= nil then
                return v
            end
        end
        return color_t(r, g, b, 255)
    end

    D.text = function(font, s, x, y, col, center)
        pcall(render.text, font, s, vec2_t(x, y), col, center == true)
    end

    D.crosshair = function(sx, sy)
        if not N.on("indicators") or D.small == nil then
            return
        end
        local st, X = N.st, N.ex
        local col = D.color("accent", 150, 190, 255)
        local white = color_t(230, 230, 230, 255)
        local x, y = sx / 2, sy / 2 + 22
        D.text(D.small, "NYKLE.WIN", x, y, col, true)
        y = y + 13
        D.text(D.small, tostring(st.label or st.state):upper(), x, y, white, true)
        y = y + 13
        local flags = {}
        if N.ref.on("dt") then
            flags[#flags + 1] = "DT"
        end
        if N.ref.on("hs") then
            flags[#flags + 1] = "HS"
        end
        if st.state == "Freestanding" then
            flags[#flags + 1] = "FS"
        end
        if X.own_def_active() or X.forced then
            flags[#flags + 1] = "DEF"
        end
        if #flags > 0 then
            D.text(D.small, concat(flags, " "), x, y, white, true)
            y = y + 13
        end
        local extra = {}
        if (N.aa.applied or 0) > 0 then
            extra[#extra + 1] = "FAZ " .. tostring(N.K.PHASE_NAME[N.aa.applied] or N.aa.applied):upper()
        end
        local target = N.aa.target_ent
        local idx = target ~= nil and U.index(target) or nil
        local t = idx ~= nil and N.rage.t[idx] or nil
        if t ~= nil and t.level > 0 then
            extra[#extra + 1] = "RES " .. t.level
        end
        local info = idx ~= nil and N.rage.scan[idx] or nil
        if info ~= nil and info.ba and U.tick() - info.tick <= 8 then
            extra[#extra + 1] = "BAIM"
        end
        if X.clean then
            extra[#extra + 1] = "CLEAN SHOT"
        end
        if X.air.latched then
            extra[#extra + 1] = "AIR LC"
        end
        local tick = U.tick()
        if tick <= X.anti_until and tick >= X.anti_until - 8 then
            extra[#extra + 1] = "ANTI-PEEK"
        end
        if N.peek.mode ~= nil then
            extra[#extra + 1] = "AI PEEK"
        end
        if N.afk.on then
            extra[#extra + 1] = "AFK"
        end
        for _, s in ipairs(extra) do
            D.text(D.small, s, x, y, col, true)
            y = y + 13
        end
    end

    D.arrows = function(sx, sy)
        if not N.on("arrows") then
            return
        end
        local m = N.st.manual or 0
        if m ~= 1 and m ~= 3 then
            return
        end
        local col = D.color("arrow_color", 150, 190, 255)
        local x = m == 1 and sx / 2 - 55 or sx / 2 + 55
        pcall(render.triangle_filled, vec2_t(x, sy / 2), 12, col, m == 1 and 270 or 90)
    end

    D.left = function(sx, sy)
        if not N.on("left_ind") or D.big == nil then
            return
        end
        local st, X, P = N.st, N.ex, N.ref
        local items = {}
        local function add(text, col)
            items[#items + 1] = { text, col }
        end
        local green, yellow, red, white = color_t(130, 230, 130, 255), color_t(240, 210, 90, 255),
            color_t(240, 90, 90, 255), color_t(230, 230, 230, 255)
        local now, tick = U.now(), U.tick()
        if P.on("dt") then
            local c, m = P.charge()
            add("DT", (m > 0 and c >= m) and green or (c > 0 and yellow or red))
        elseif P.items.dt ~= nil then
            add("DT OFF", red)
        end
        if P.on("hs") then
            add("HS", white)
        end
        if st.fd then
            add("FD", white)
        end
        if X.own_def_active() or X.forced then
            add("DEF", white)
        end
        if N.aa.choked() >= 13 and not X.air.latched then
            add("LC", white)
        end
        if X.air.latched then
            add("AIR LC", yellow)
        end
        -- V1.0.11: duvardan vurulabiliyorsun (tahmini hasar); canina yetiyorsa kirmizi.
        local wbd = N.exposure.wb_best()
        if wbd > 0 then
            local hp = U.num(st.lp, "m_iHealth") or 100
            add("WB " .. U.numtext(U.R(wbd)), wbd >= hp and red or yellow)
        end
        local md = N.rage.last_md
        local ovr_v, ovr = P.md_eff(st.wgroup)
        if md ~= nil and tick - md.tick <= 8 and tick >= md.tick then
            add("MD " .. U.numtext(md.v), yellow)
        elseif ovr and ovr_v ~= nil then
            add("MD " .. U.numtext(ovr_v), white)
        end
        local target = N.aa.target_ent
        local idx = target ~= nil and U.index(target) or nil
        local info = idx ~= nil and N.rage.scan[idx] or nil
        if info ~= nil and tick - info.tick <= 8 then
            if info.ba then
                add("BAIM", white)
            end
            if (info.sp or 0) > 0 then
                add("SAFE", white)
            end
        end
        if st.state == "Freestanding" then
            add("FS", white)
        end
        if st.move_state == "Peek" then
            add("PEEK", white)
        end
        if N.afk.on then
            add("AFK", white)
        end
        if st.roll_warn then
            add("ROLL!", red)
        end
        if st.fd_hint_until ~= nil and now < st.fd_hint_until then
            add("FD!", red)
        end
        if X.paused("DEF") or X.paused("LC") or X.paused("TP") then
            add("PAUSE", red)
        end
        local y = sy * 0.66
        for _, item in ipairs(items) do
            local ok, size = pcall(render.get_text_size, D.big, item[1])
            local w = (ok and size ~= nil) and size.x or 60
            -- V1.0.6: ekran goruntusunde yazi sol kenarda kesikti (x = 10): 28 piksel iceriden.
            pcall(render.rect_fade, vec2_t(0, y - 2), vec2_t(w + 60, 28), color_t(0, 0, 0, 120), color_t(0, 0, 0, 0),
                true)
            D.text(D.big, item[1], 28, y, item[2], false)
            y = y - 30
        end
    end

    -- Resolver paneli. GS V1.0.59 (FPS): hedef, isim, hafiza kaydi, seviye, faz ve cozum / HIT tahmini tick basina bir
    -- kez hesaplanir (isim / anahtar N.mem.cached'ten, 1 sn onbellekli); her karede onbellekten cizilir.
    D.rc = { tick = nil, lines = nil }

    D.res_lines = function(target)
        local B = N.brute
        local idx = U.index(target)
        local p, key = N.mem.entry(target)
        local _, name = N.mem.cached(target)
        name = tostring(name or "?")
        local t = idx ~= nil and N.rage.t[idx] or nil
        local tr = idx ~= nil and N.track.p[idx] or nil
        local skey = key or (idx ~= nil and ("i" .. idx)) or nil
        local cozum, hit = N.stats.estimate(target, idx, skey, p)
        local stage = B.entry_stage(key ~= nil and B.enemies[key] or nil, B.group_for(N.st.move_state))
        return {
            #name > 16 and (name:sub(1, 15) .. ".") or name,
            fmt("RES L%d", t ~= nil and t.level or 0),
            fmt("cozum %%%d", cozum),
            fmt("HIT %%%d", hit),
            fmt("kafa %d/%d", U.R(p ~= nil and p.hider.h or 0), U.R(p ~= nil and p.hider.n or 0)),
            fmt("isabet %d/%d", tr ~= nil and (tr.our_hits or 0) or 0, tr ~= nil and (tr.our_shots or 0) or 0),
            fmt("faz %d", stage),
        }
    end

    D.res_panel = function(sx, sy)
        if not N.on("res_panel") or D.small == nil then
            return
        end
        local c, tick = D.rc, U.tick()
        if c.tick ~= tick then
            c.tick = tick
            local target = N.aa.target_ent
            c.lines = (target ~= nil and U.alive(target)) and D.res_lines(target) or nil
        end
        local lines = c.lines
        if lines == nil then
            return
        end
        local scale = (N.v("panel_size") or 160) / 100
        local x = sx * (N.v("panel_x") or 560) / 1000
        local y = sy * (N.v("panel_y") or 380) / 1000
        local h = 14 * scale
        pcall(render.rect_filled, vec2_t(x - 6, y - 4), vec2_t(110 * scale, h * #lines + 8), color_t(0, 0, 0, 110), 4)
        local col = D.color("accent", 150, 190, 255)
        for i, s in ipairs(lines) do
            D.text(D.small, s, x, y + (i - 1) * h, i == 1 and col or color_t(230, 230, 230, 255), false)
        end
    end

    -- Stats paneli yazisi ekran yuksekligine gore (1080 = 12 px); boyut degisince bir kez yeniden olusturulur.
    D.stats_font = function(sy)
        local size = max(9, floor(12 * sy / 1080 + 0.5))
        if D.sf_size ~= size then
            local ok, f = pcall(render.create_font, "Verdana", size, 700, e_font_flags.DROPSHADOW)
            D.sf_size, D.sf, D.measures, D.measure_n = size, ok and f or nil, {}, 0
        end
        return D.sf, size
    end

    -- Yazi genisligi ezberlenir (GS V1.0.59; en fazla 256 kayit, sonra bastan).
    D.measure = function(font, s)
        local w = D.measures[s]
        if w == nil then
            if D.measure_n >= 256 then
                D.measures, D.measure_n = {}, 0
            end
            local ok, size = pcall(render.get_text_size, font, s)
            w = (ok and size ~= nil and U.finite(size.x)) and size.x or #s * 7
            D.measures[s], D.measure_n = w, D.measure_n + 1
        end
        return w
    end

    -- Stats paneli (GS draw_stats satirlari): sag ustte (GS sol ust 0.45 h; primordial'da sol liste 0.66 h'den yukari
    -- ciktigi icin cakismasin diye sagda, 0.30 h). Satirlar tick basina bir kez kurulur.
    D.sc = { tick = nil, rows = nil, w = 0 }

    D.stats_panel = function(sx, sy)
        if not N.on("stats_panel") then
            return
        end
        local font, size = D.stats_font(sy)
        if font == nil then
            return
        end
        local c, tick = D.sc, U.tick()
        if c.tick ~= tick or c.size ~= size then
            c.tick, c.size, c.rows, c.w = tick, size, N.stats.rows(), 0
            for _, row in ipairs(c.rows) do
                c.w = max(c.w, D.measure(font, row[1]))
            end
        end
        local accent, white = D.color("accent", 150, 190, 255), color_t(230, 230, 230, 255)
        local line, gap = size + 1, floor(size / 2)
        local x, y = sx - c.w - 12, floor(sy * 0.3)
        for i, row in ipairs(c.rows) do
            if i > 1 then
                y = y + line + (row[3] and gap or 0)
            end
            D.text(font, row[1], x, y, row[2] and accent or white, false)
        end
    end

    D.paint = function()
        local st = N.st
        if not st.on or not st.alive then
            return
        end
        local ok, size = pcall(render.get_screen_size)
        if not ok or size == nil then
            return
        end
        local sx, sy = size.x, size.y
        if not U.finite(sx) or not U.finite(sy) then
            return
        end
        D.crosshair(sx, sy)
        D.arrows(sx, sy)
        D.left(sx, sy)
        D.res_panel(sx, sy)
        D.stats_panel(sx, sy)
    end
end

-------------------------------------------------------------------------------
-- Yasam dongusu: ac / kapat, olum temizligi, tick basi.
-------------------------------------------------------------------------------
do
    local U = N.util

    N.enable = function()
        N.ov.hold_neutral(true)
        N.misc.apply(true)
        N.log.line("acildi: native AA tasiyicilari notrde, ayarlar uygulandi")
    end

    -- Kapatinca her sey geri: native ayarlar (anlik kopyalar), sarj, cvar'lar, clan tag.
    N.disable = function()
        N.ov.release_all()
        N.rc.release_all()
        N.misc.release_all()
        N.misc.clantag_clear()
        N.peek.reset()
        N.afk.on, N.afk.auto, N.afk.anchor = false, false, nil
        N.ex.reset_life()
        N.misc.js_active = nil
        N.log.line("kapatildi: native ayarlar, sarj ve cvar'lar geri verildi")
    end

    N.check_enable = function()
        local st = N.st
        local on = N.on("enabled")
        if on ~= st.enabled then
            st.enabled = on
            if on then
                N.enable()
            else
                st.on = false
                N.disable()
            end
        end
        return on
    end

    -- Harita / oturum degisimi (game_newmap, yerel oyuncu gidip geri geldi, tickcount geri gitti): tick'e bagli
    -- butun durum silinir; eski haritanin tick'leri yeni haritada "gelecekte" kalmasin.
    N.map_reset = function()
        local st = N.st
        N.diag.map_end()
        N.profile.map_end()
        N.stats.map_end()
        N.ex.tp_reset()
        N.charge.map_reset()
        N.exposure.reset()
        N.track.p = {}
        N.rage.map_reset()
        N.mem.kc = {}
        N.dlog.map_reset(false)
        N.aa.cover, N.aa.cover_auto, N.aa.cover_tick = nil, false, -1000
        N.state.peek_until = -1000
        N.rc.release_all()
        N.mem.save(false)
        st.map_tick = U.tick()
    end

    -- PAINT: game_newmap gelmese de (baglanirken kacabilir) degisimi yakala.
    N.map_watch = function(lp)
        local st = N.st
        local tick = U.tick()
        if lp == nil then
            st.paint_gone = true
            return
        end
        local back = st.paint_tick ~= nil and tick < st.paint_tick - 64
        if st.paint_gone or back then
            st.paint_gone = false
            if st.paint_tick ~= nil then
                N.map_reset()
            end
        end
        st.paint_tick = tick
    end

    -- Olunce bir kez (SETUP_COMMAND, player_death ya da PAINT'ten; dogunca / round basinda sifirlanir).
    N.dead_cleanup = function()
        local st = N.st
        if st.dead then
            return
        end
        st.dead, st.alive, st.on = true, false, false
        N.afk.death()
        N.rc.release_all()
        N.ex.reset_life()
        N.rage.reset_life()
        N.ov.release_prefix("fs_states:")
        N.aa.fs_item = nil
        if N.misc.js_active then
            N.ov.release("autostrafer")
        end
        N.misc.js_active = nil
        N.log.flush()
    end

    N.tick.begin = function(cmd)
        local st = N.st
        N.check_enable()
        local ok, lp = pcall(entity_list.get_local_player)
        if not ok or lp == nil then
            st.lp, st.on, st.alive = nil, false, false
            if st.had_lp then
                st.had_lp = false
                N.map_reset()
            end
            return false
        end
        st.lp, st.had_lp, st.idx = lp, true, U.index(lp)
        if not U.alive(lp) then
            N.dead_cleanup()
            return false
        end
        if st.dead then
            st.dead = false
            st.spawn_at = U.now()
            N.afk.spawn()
        end
        st.alive = true
        st.on = st.enabled
        st.tick = U.tick()
        st.cmdn = cmd ~= nil and cmd.command_number or nil
        return st.on
    end

    -- SETUP_COMMAND (SPEC §3.3 sirasi).
    N.setup = function(cmd)
        if not N.tick.begin(cmd) then
            return
        end
        local st = N.st
        N.track.fallback()
        N.exposure.enemies()
        st.threat = N.aa.target()
        N.exposure.update()
        N.aa.cover_update()
        N.state.detect(cmd, nil)
        N.ex.clean_update()
        N.peek.update(cmd)
        N.aa.crouch_keeper(cmd)
        N.misc.jump_scout()
        N.ex.air_update(cmd)
        N.ex.safe_recharge()
        N.rc.tick()
        N.rc.watchdog()
        N.ex.defensive()
        N.charge.tick()
        N.rage.prepare()
        N.brute.process_pending()
        N.shots.expire()
        N.dlog.tick()
        N.profile.tick()
        N.stats.tick()
        N.ov.hold_neutral(false)
    end

    N.antiaim = function(ctx, cmd, unpred)
        local st = N.st
        if not st.on or not st.alive or st.lp == nil then
            return
        end
        N.state.detect(cmd, unpred)
        N.aa.apply(ctx, cmd)
        N.ex.fakelag(ctx)
    end

    N.paint = function()
        local st = N.st
        N.ui.visibility()
        N.ui.recommend()
        N.ref.retry()
        local enabled = N.check_enable()
        if enabled then
            local ok, lp = pcall(entity_list.get_local_player)
            if ok then
                N.map_watch(lp)
            end
            if ok and lp ~= nil and not U.alive(lp) then
                N.dead_cleanup()
            elseif ok and lp == nil then
                N.dead_cleanup()
            end
            N.misc.paint()
            N.draw.paint()
            N.ov.hold_neutral(false)
            N.shots.expire()
            N.brute.process_pending()
        end
        N.log.timer()
    end

    N.shutdown = function()
        N.shots.summary()
        N.profile.map_end()
        N.diag.map_end()
        N.stats.map_end()
        N.ov.release_all()
        N.rc.release_all()
        N.misc.release_all()
        N.misc.clantag_clear()
        N.mem.save(true)
        N.log.line("script kaldirildi: native ayarlar, sarj ve cvar'lar geri verildi")
        N.log.flush()
    end
end

-------------------------------------------------------------------------------
-- Callback kaydi: her callback tek sarmalayicidan; her islemci pcall icinde (hata ilk 3 kez yazilir, 50'de
-- kapatilir). EVENT her olay adi icin 3. argumanli filtreyle bir kez; filtre yok sayilirsa ad kontrol edilir.
-------------------------------------------------------------------------------
do
    local U, C = N.util, N.cb

    C.on = function(key, name, fn, event)
        local list_key = event ~= nil and ("EVENT:" .. event) or key
        local list = C.handlers[list_key]
        if list == nil then
            list = {}
            C.handlers[list_key] = list
            local wrapper
            if event ~= nil then
                wrapper = function(ev)
                    if ev ~= nil then
                        local okn, nm = pcall(function()
                            return ev.name
                        end)
                        if okn and nm ~= nil and nm ~= event then
                            pcall(N.diag.filter, event, nm)
                            return
                        end
                    end
                    for _, h in ipairs(list) do
                        C.run(h, ev)
                    end
                end
                local ok = pcall(callbacks.add, e_callbacks.EVENT, wrapper, event)
                if not ok then
                    N.log.line("callback eklenemedi: EVENT " .. event)
                end
            else
                wrapper = function(...)
                    pcall(N.diag.cb, key, ...)
                    for _, h in ipairs(list) do
                        C.run(h, ...)
                    end
                end
                local ok = pcall(callbacks.add, e_callbacks[key], wrapper)
                if not ok then
                    N.log.line("callback eklenemedi: " .. key)
                end
            end
        end
        list[#list + 1] = { name = name, fn = fn, errors = 0, dead = false }
    end

    C.register = function()
        local st = N.st
        C.on("SETUP_COMMAND", "setup_command", function(cmd)
            N.setup(cmd)
        end)
        C.on("ANTIAIM", "antiaim", function(ctx, cmd, unpred)
            N.antiaim(ctx, cmd, unpred)
        end)
        C.on("HITSCAN", "hitscan", function(ctx)
            if st.on and st.alive then
                N.rage.hitscan(ctx)
            end
        end)
        C.on("TARGET_SELECTION", "target_selection", function(ctx)
            if st.on and st.alive then
                N.rage.select(ctx)
            end
        end)
        C.on("AIMBOT_SHOOT", "aimbot_shoot", function(shot)
            if st.enabled then
                N.shots.on_shoot(shot)
            end
        end)
        C.on("AIMBOT_HIT", "aimbot_hit", function(hit)
            if st.enabled then
                N.shots.on_hit(hit)
            end
        end)
        C.on("AIMBOT_MISS", "aimbot_miss", function(miss)
            if st.enabled then
                N.shots.on_miss(miss)
            end
        end)
        C.on("NET_UPDATE", "net_update", function()
            if not st.enabled then
                return
            end
            local ok, lp = pcall(entity_list.get_local_player)
            if not ok or lp == nil then
                return
            end
            st.lp = lp
            N.track.update(true)
            N.ex.own_update()
        end)
        C.on("PAINT", "paint", function()
            N.paint()
        end)
        C.on("SHUTDOWN", "shutdown", function()
            N.shutdown()
        end)
        C.on("EVENT", "round_prestart", function()
            if st.enabled then
                N.rc.release_all()
            end
        end, "round_prestart")
        C.on("EVENT", "round_start", function()
            if not st.enabled then
                return
            end
            N.rc.release_all()
            N.shots.summary()
            N.profile.round_start()
            N.stats.round_no = (N.stats.round_no or 1) + 1
            st.last_round_start = U.now()
            N.brute.round()
            local fresh = N.dlog.round_begin()
            N.stats.round(fresh)
            N.misc.buy()
            if fresh then
                N.shots.settings()
            end
            N.log.flush()
            N.dlog.round_done()
        end, "round_start")
        C.on("EVENT", "round_end", function(e)
            if not st.enabled then
                return
            end
            N.dlog.round_end(e)
            N.mem.save(false)
            N.log.flush()
        end, "round_end")
        C.on("EVENT", "player_death", function(e)
            if st.enabled then
                N.shots.on_death(e)
            end
        end, "player_death")
        C.on("EVENT", "player_hurt", function(e)
            if st.enabled then
                N.shots.on_hurt(e)
            end
        end, "player_hurt")
        C.on("EVENT", "bullet_impact", function(e)
            if st.enabled then
                N.brute.impact(e)
            end
        end, "bullet_impact")
        C.on("EVENT", "player_spawn", function(e)
            if not st.enabled then
                return
            end
            local p = N.shots.player(e.userid)
            local ok, lp = pcall(entity_list.get_local_player)
            if not ok or lp == nil or p ~= lp then
                return
            end
            st.spawn_at = U.now()
            N.afk.spawn()
            -- DM: 60 sn round_start yoksa ozet ve bomba dogusta.
            if U.now() - st.last_round_start > 60 then
                N.brute.round()
                N.shots.summary()
                N.dlog.round_begin()
                N.misc.buy()
                N.dlog.round_done()
            end
        end, "player_spawn")
        C.on("EVENT", "weapon_fire", function(e)
            if st.enabled then
                N.shots.enemy_fire(e)
            end
        end, "weapon_fire")
        -- Mac sonu paneli: harita bitti, dusman ozetleri (game_newmap'te bir daha yazilmaz; ara surede profil donar).
        C.on("EVENT", "cs_win_panel_match", function()
            if st.enabled then
                N.profile.map_end(true)
                N.log.flush()
            end
        end, "cs_win_panel_match")
        C.on("EVENT", "game_newmap", function()
            N.shots.summary()
            N.map_reset()
            N.dlog.map_reset(true)
            N.log.flush()
        end, "game_newmap")
    end
end

-------------------------------------------------------------------------------
-- Yukleme
-------------------------------------------------------------------------------
do
    local U = N.util

    N.step = function(name, fn)
        local ok, err = pcall(fn)
        if not ok then
            N.log.line(fmt("%s hata verdi: %s", name, tostring(err)))
        end
        return ok
    end

    N.load = function()
        pcall(math.randomseed, floor(U.now() * 1000) % 2147483647)
        N.step("dosya sistemi", N.fs.init)
        N.step("menu", N.ui.build)
        N.step("native referanslar", N.ref.resolve)
        N.step("exploit kontrolu", N.ex.init)
        N.step("hafiza", N.mem.load)
        N.step("log dosyasi", N.log.open)
        N.step("cizim", N.draw.init)
        local text = fmt("V%s (%s edition) yuklendi", N.VERSION, N.EDITION)
        if N.fs.ok then
            text = text .. fmt(" (hafiza: %d oyuncu%s)", N.mem.count, N.mem.from_bak and ", yedekten" or "")
        else
            text = text .. fmt(" (hafiza: dosya yok) (log dosyasi yok: %s)", tostring(N.fs.why or "?"))
        end
        if not N.ex.has_shift then
            text = text .. " (defensive yok: eski primordial)"
        end
        local okn, uname = pcall(function()
            return user.name
        end)
        if okn and type(uname) == "string" and uname ~= "" then
            text = text .. " | " .. uname
        end
        N.log.load_entry = N.log.line(text)
        if N.fs.ok then
            N.log.line("log dosyasi: " .. N.log.file .. " (MOD, csgo klasoru)")
        end
        for _, note in ipairs(N.log.notes) do
            N.log.line(note)
        end
        if N.ui.failed > 0 then
            N.log.line(fmt("toplam %d menu ogesi olusturulamadi", N.ui.failed))
        end
        N.log.flush()
        N.cb.register()
        N.st.enabled = N.on("enabled")
        if N.st.enabled then
            N.step("acilis", function()
                N.ov.hold_neutral(true)
                N.misc.apply(true)
            end)
        end
        N.step("ayarlar", N.shots.settings)
        if N.on("debug_log") then
            N.log.line(fmt("detayli log acik: dosya %s (Home > Console > Copy all logs)", N.fs.ok and N.log.file or "yok"))
        end
    end
end

N.load()
