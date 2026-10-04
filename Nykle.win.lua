--[[
    Nykle.win lua V1.0  |  Neverlose (CS:GO) icin HvH anti-aim, exploit ve resolver lua'si

    Kurar kurmaz calisir: butun varsayilanlar ayarlanmis halde gelir ("Always use recommended
    settings" acik kaldikca her surumde en iyi bilinen degerler korunur).

    V1.0 (eski adi ANT-A-M, v5.6'nin uzerine):
      - Resolver v5.2'nin sade ve kararli mantigina donduruldu (v5.3'un sniper duzeltmesiyle).
        Kaldirilanlar: dusman defensive'deyken atisi bekletme (ilk atisi geciktiriyordu), uzak
        mesafede tek iskada Force safe point (atis kesiyordu), fake duck / uzak icin veri olmadan
        Prefer, kendi fake duck'inda zorla Prefer.
      - Resolver bizim numaralarimiza kanmaz: dusmanin defensive kaydina (sahte kayit) giden
        correction iskasi ogrenilmez (safe point onu duzeltemez); jitter sadece gercek kayitlardan
        olculur (hidden spin / random yaw jitter on bilgisini bozmaz).
      - Menu bastan duzenlendi: Home / Anti-Aim / Exploits / Builder / Ragebot / Visuals sekmeleri,
        ikonlar, aciklamalar; butun konsol loglari tek yerde.

    Neler var
      - 13 durumlu builder (Global, Standing, Moving, Slow walk, Crouching, Crouch move, Peek, Air,
        Air crouch, Fake duck + Manual, Freestanding, Safe head); her durumun kendi AA'si ve
        exploit'i (DT / HS, defensive modu, hidden pitch / yaw).
      - Smart defensive (biri kafani gorunce / birazdan gorecekken), dusman peek'ine karsi defensive,
        havada lag ve teleport, Hide shots'ta hareket ederken Break LC, safe recharge.
      - AI peek: Peek Assist tusunu basili tut, script oldurecek atisin oldugu en yakin noktaya
        yurur, atistan sonra geri doner.
      - Adaptive resolver: Neverlose'un resolver'i bir dusmanda yanildikca sadece o dusmana ve o
        hareket durumuna karsi safe point yukselir, isabetlerle iner. Smart body aim, sniper'da
        sadece oldurecek atis.
      - Kendi kendine ogrenen anti-bruteforce (5 faz), safe head, freestanding, manuel yaw, avoid
        backstab, legit AA on use, fake duck korumalari.
      - Resolver paneli (canli cozum yuzdesi ve isabet sansi), indikatorler, istatistikler, round
        ozeti ve atis loglari.
      - Ogrenilenler Steam ID ile Neverlose db'de kalir (harita / oyun degisince de).
      - Kapatinca butun Neverlose ayarlarini geri verir; bulunamayan menu yolu ya da API olursa
        cokmez, o ozelligi atlar.

    Kurulum, ayarlar ve degisiklikler icin README.md'ye bak.
]]

local SCRIPT = "Nykle.win"
-- Her guncellemede artar; yuklenince konsola yazilir ki hangi surumun calistigi belli olsun.
local VERSION = "1.0"
local DEG = "\194\176"

local floor, max, min, sqrt, huge, random, abs = math.floor, math.max, math.min, math.sqrt, math.huge, math.random, math.abs

-------------------------------------------------------------------------------
-- Guvenli API erisimi
-------------------------------------------------------------------------------

-- Bulunamayan bir menu yolu script'i cokertmesin, sadece konsola yazilsin.
local function find(...)
    local path = { ... }
    local ok, ref = pcall(ui.find, ...)
    if ok and ref ~= nil then
        return ref
    end
    print(("[%s] menude bulunamadi: %s"):format(SCRIPT, table.concat(path, " > ")))
    return nil
end

-- rage.antiaim / rage.exploit metodlari Neverlose surumune gore degisebilir.
-- Yoksa nil doner ve o ozellik sessizce atlanir.
local function rage_method(object_name, method)
    if rage == nil then
        return nil
    end
    local ok, object = pcall(function() return rage[object_name] end)
    if not ok or object == nil then
        return nil
    end
    local ok_fn, fn = pcall(function() return object[method] end)
    if not ok_fn or type(fn) ~= "function" then
        return nil
    end
    return function(...)
        local ok_call, result = pcall(fn, object, ...)
        if ok_call then
            return result
        end
        return nil
    end
end

-- Bir olay fonksiyonu hata verirse (beklenmedik bir API degeri vb.) script sessizce
-- durmasin ve konsol dolmasin: hata bir kez yazilir, sonraki olaylarda yine calisir.
local handler_errors = {}
local function protect(name, fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok and not handler_errors[name] then
            handler_errors[name] = true
            print(("[%s] %s hata verdi: %s"):format(SCRIPT, name, tostring(err)))
        end
    end
end

local api = {
    inverter     = rage_method("antiaim", "inverter"),
    get_target   = rage_method("antiaim", "get_target"),
    hidden_pitch = rage_method("antiaim", "override_hidden_pitch"),
    hidden_yaw   = rage_method("antiaim", "override_hidden_yaw_offset"),
    charge       = rage_method("exploit", "get"),
    allow_charge = rage_method("exploit", "allow_charge"),
    teleport     = rage_method("exploit", "force_teleport"),
}

local refs = {
    aa_enabled      = find("Aimbot", "Anti Aim", "Angles", "Enabled"),
    pitch           = find("Aimbot", "Anti Aim", "Angles", "Pitch"),
    yaw             = find("Aimbot", "Anti Aim", "Angles", "Yaw"),
    yaw_base        = find("Aimbot", "Anti Aim", "Angles", "Yaw", "Base"),
    yaw_offset      = find("Aimbot", "Anti Aim", "Angles", "Yaw", "Offset"),
    hidden          = find("Aimbot", "Anti Aim", "Angles", "Yaw", "Hidden"),
    avoid_backstab  = find("Aimbot", "Anti Aim", "Angles", "Yaw", "Avoid Backstab"),
    yaw_modifier    = find("Aimbot", "Anti Aim", "Angles", "Yaw Modifier"),
    modifier_offset = find("Aimbot", "Anti Aim", "Angles", "Yaw Modifier", "Offset"),
    body_yaw        = find("Aimbot", "Anti Aim", "Angles", "Body Yaw"),
    inverter        = find("Aimbot", "Anti Aim", "Angles", "Body Yaw", "Inverter"),
    left_limit      = find("Aimbot", "Anti Aim", "Angles", "Body Yaw", "Left Limit"),
    right_limit     = find("Aimbot", "Anti Aim", "Angles", "Body Yaw", "Right Limit"),
    body_options    = find("Aimbot", "Anti Aim", "Angles", "Body Yaw", "Options"),
    body_fs         = find("Aimbot", "Anti Aim", "Angles", "Body Yaw", "Freestanding"),
    freestanding    = find("Aimbot", "Anti Aim", "Angles", "Freestanding"),
    fs_modifiers    = find("Aimbot", "Anti Aim", "Angles", "Freestanding", "Disable Yaw Modifiers"),
    fs_body         = find("Aimbot", "Anti Aim", "Angles", "Freestanding", "Body Freestanding"),
    slowwalk        = find("Aimbot", "Anti Aim", "Misc", "Slow Walk"),
    fakeduck        = find("Aimbot", "Anti Aim", "Misc", "Fake Duck"),
    doubletap       = find("Aimbot", "Ragebot", "Main", "Double Tap"),
    lag_options     = find("Aimbot", "Ragebot", "Main", "Double Tap", "Lag Options"),
    hideshots       = find("Aimbot", "Ragebot", "Main", "Hide Shots"),
    hs_options      = find("Aimbot", "Ragebot", "Main", "Hide Shots", "Options"),
    peek_assist     = find("Aimbot", "Ragebot", "Main", "Peek Assist"),
    safe_points     = find("Aimbot", "Ragebot", "Safety", "Safe Points"),
    min_damage      = find("Aimbot", "Ragebot", "Selection", "Min. Damage"),
    body_aim        = find("Aimbot", "Ragebot", "Safety", "Body Aim"),
}

-- Ezdigimiz ayarlar ve verdigimiz degerler. Kapatinca hepsini geri veririz.
local overridden = {}
-- Bir ayarin degerini en son ne zaman degistirdigimiz (log icin; ornegin defensive
-- modunu degistirmek DT'yi yeniden sarj ettiriyor mu gorebilmek icin).
local changed_at = {}
-- Neverlose'un kabul etmedigi degerler (surume gore secenek adi farkli olabilir ya da
-- ayar o an kilitli olabilir). Hata her tick butun AA'yi durdurmasin diye bir kez
-- yazilir; deger 5 sn sonra tekrar denenir, anlik bir hata kalici olmaz.
local REJECT_RETRY = 5
local rejected, reported = {}, {}

-- value nil ise o ayar kullanicinin kendi Neverlose degerine birakilir.
local function override(name, value)
    local ref = refs[name]
    if ref == nil then
        return
    end
    if value == nil then
        if overridden[name] ~= nil then
            pcall(ref.override, ref)
            overridden[name] = nil
        end
        return
    end
    local key = name .. "=" .. tostring(value)
    local now = globals.realtime
    local failed_at = rejected[key]
    if failed_at ~= nil and now >= failed_at and now - failed_at < REJECT_RETRY then
        return
    end
    local ok, err = pcall(ref.override, ref, value)
    if not ok then
        rejected[key] = now
        -- Onceki degerimiz takili kalmasin (orn. scout'ta DT acik kalmasin): ezmeyi
        -- birak, ayar senin kendi degerine donsun.
        if overridden[name] ~= nil then
            pcall(ref.override, ref)
            overridden[name] = nil
        end
        if not reported[key] then
            reported[key] = true
            print(("[%s] %s = %s ayarlanamadi: %s"):format(SCRIPT, name, tostring(value), tostring(err)))
        end
        return
    end
    rejected[key] = nil
    if overridden[name] ~= value then
        changed_at[name] = globals.realtime
    end
    overridden[name] = value
end

local function reset_overrides()
    for name in pairs(overridden) do
        pcall(refs[name].override, refs[name])
    end
    overridden = {}
end

local function get(name)
    local ref = refs[name]
    if ref == nil then
        return false
    end
    local ok, value = pcall(ref.get, ref)
    return ok and value or false
end

-- Ezdiysek bizim verdigimiz degeri, ezmediysek menudeki degeri dondurur.
local function effective(name)
    local value = overridden[name]
    if value ~= nil then
        return value
    end
    return get(name)
end

-- Peek Assist tusu basili mi. AI peek yururken Peek Assist'i ezdigimizde (false) :get()'in
-- ezilen degeri dondurdugu bir surumde tus okunamaz; o zaman tusun durumu ui.get_binds()'tan
-- alinir. O da okunamazsa basili sayilir (peek kendiliginden ~1 sn'de biter, hareket tusu keser).
local function peek_key_held()
    if overridden.peek_assist == nil then
        return get("peek_assist")
    end
    local ok, binds = pcall(function() return ui.get_binds() end)
    if ok and type(binds) == "table" then
        for _, bind in ipairs(binds) do
            local ok_bind, name, ref, active = pcall(function() return bind.name, bind.reference, bind.active end)
            if ok_bind and (name == "Peek Assist" or (ref ~= nil and ref == refs.peek_assist)) then
                return active == true
            end
        end
    end
    return true
end

local function default_first(items, first)
    local list = { first }
    for _, item in ipairs(items) do
        if item ~= first then
            list[#list + 1] = item
        end
    end
    return list
end

-- Hangi durumda vuruldugunu gormek icin istatistikler. Menudeki sifirlama dugmesi
-- de kullandigi icin menuden once tanimli.
local stats, pending_misses = {}, {}

-- Ogrenilen dusman bellegini siler; bellek menuden sonra tanimlandigi icin sonradan atanir.
local forget_enemies

-- Senin aimbot atislarinin sonuclari (Neverlose'un aim_ack nedenleri).
-- ai_*: AI peek sayaclari (peek, atis, isabet, atissiz biten, peek sirasinda vurulma).
local function new_aim_stats()
    return { shots = 0, hits = 0, correction = 0, spread = 0, other = 0,
        ai_peeks = 0, ai_shots = 0, ai_hits = 0, ai_empty = 0, ai_hurt = 0 }
end
local aim_stats = new_aim_stats()

-------------------------------------------------------------------------------
-- Menu
-------------------------------------------------------------------------------

-- Basliklar: \f<ikon> Neverlose'un ikon fontu, \v tema rengi, \r normal renk. plain: loglar
-- ve onerilen ayar raporlari icin bicimsiz ad. tip: aciklama (fareyle uzerine gelince).
local style = {}
style.title = function(icon, text)
    return "\v\f<" .. icon .. ">\r  " .. text
end
style.plain = function(text)
    local out = tostring(text):gsub("\a%x%x%x%x%x%x%x%x", ""):gsub("\a{[^}]*}", ""):gsub("\aDEFAULT", "")
    out = out:gsub("\f<[^>]*>", ""):gsub("[\v\r]", ""):gsub("^%s+", ""):gsub("%s+$", "")
    return out
end
style.tip = function(element, text)
    if element ~= nil then
        pcall(element.tooltip, element, text)
    end
    return element
end

pcall(ui.sidebar, SCRIPT, "crown")

-- "Always use recommended settings": Neverlose lua ayarlarini config'e kaydeder; eski
-- bir surumle kaydedilmis config eski varsayilanlari geri getirir. Bu yuzden AA,
-- exploit ve builder ayarlarinin varsayilanlari kaydedilir ve acik oldugu surece bu
-- degerlerde tutulur (ayar degistirmek icin kapat). Bind'lenen ayarlar (manual, freestanding, inverter),
-- builder'daki durum secici, loglar ve gorsel tercihler bu listeye girmez.
local recommended = {}
-- Log icin ayarin adinin onune eklenir (builder'da durum adi: "Fake duck Left limit").
local label_prefix = ""

local function remember(element, value, name)
    if element ~= nil then
        recommended[#recommended + 1] = { element = element, value = value, label = label_prefix .. style.plain(name) }
    end
    return element
end

local function tracked(group)
    return {
        switch = function(_, name, def, ...) return remember(group:switch(name, def, ...), def == true, name) end,
        combo = function(_, name, items, ...) return remember(group:combo(name, items, ...), items[1], name) end,
        slider = function(_, name, low, high, def, ...) return remember(group:slider(name, low, high, def, ...), def, name) end,
        label = function(_, ...) return group:label(...) end,
        button = function(_, ...) return group:button(...) end,
        color_picker = function(_, ...) return group:color_picker(...) end,
    }
end

-- Sekmeler: Home (script, hafiza, loglar), Anti-Aim, Exploits, Builder (durum basina AA ve
-- exploit), Ragebot (resolver), Visuals. *_raw: onerilen ayarlara girmeyen (bind / tercih) gruplar.
local grp = {}
do
    local TAB = { home = "\f<house>  Home", aa = "\f<shield-halved>  Anti-Aim", exploits = "\f<bolt>  Exploits",
        builder = "\f<sliders>  Builder", rage = "\f<crosshairs>  Ragebot", visuals = "\f<eye>  Visuals" }
    local function group(tab, icon, name, column)
        return ui.create(tab, style.title(icon, name), column)
    end
    grp.info        = group(TAB.home, "crown", SCRIPT, 1)
    grp.data        = group(TAB.home, "database", "Memory", 2)
    grp.console     = group(TAB.home, "terminal", "Console", 2)
    grp.aa_raw      = group(TAB.aa, "shield-halved", "Main", 1)
    grp.aa          = tracked(grp.aa_raw)
    grp.protect_raw = group(TAB.aa, "user-shield", "Protection", 2)
    grp.protect     = tracked(grp.protect_raw)
    grp.exploits    = tracked(group(TAB.exploits, "bolt", "Exploits", 1))
    grp.peek        = tracked(group(TAB.exploits, "person-running", "Peek", 1))
    grp.defensive   = tracked(group(TAB.exploits, "shield", "Defensive", 2))
    grp.angles_raw  = group(TAB.builder, "sliders", "Angles", 1)
    grp.angles      = tracked(grp.angles_raw)
    grp.bexploit_raw = group(TAB.builder, "bolt", "State exploit", 2)
    grp.bexploit    = tracked(grp.bexploit_raw)
    grp.resolver    = tracked(group(TAB.rage, "crosshairs", "Resolver", 1))
    grp.indicators  = group(TAB.visuals, "eye", "Indicators", 1)
    grp.panel       = group(TAB.visuals, "chart-simple", "Resolver panel", 2)
end

local STATES = {
    "Global", "Standing", "Moving", "Slow walk", "Crouching", "Crouch move", "Peek", "Air", "Air crouch",
    "Fake duck", "Manual", "Freestanding", "Safe head",
}
local MOVEMENT_STATES = 10

local SPECIAL_INFO = {
    ["Global"]       = "Used by states whose Override is off.",
    ["Fake duck"]    = "Used while fake ducking. DT/HS do not work here.",
    ["Manual"]       = "Used while manual yaw is active.",
    ["Freestanding"] = "Used while freestanding hides your head.",
    ["Safe head"]    = "Used while a safe head condition matches.",
}

-- AA varsayilanlari: { yaw sol, yaw sag, jitter gecikmesi, sol limit, sag limit }
-- Hareket durumlari topluluk tarafindan denenmis jitter presetlerinden alindi.
local DEFAULTS = {
    ["Global"]       = { -20, 40, 1, 60, 60 },
    ["Standing"]     = { -23, 51, 1, 60, 60 },
    ["Moving"]       = { -20, 50, 1, 58, 58 },
    ["Slow walk"]    = { -23, 51, 2, 58, 58 },
    ["Crouching"]    = { -20, 30, 1, 58, 58 },
    ["Crouch move"]  = { -20, 30, 1, 58, 58 },
    ["Peek"]         = { -20, 45, 1, 58, 58 },
    ["Air"]          = { -13, 34, 1, 58, 58 },
    ["Air crouch"]   = { -15, 44, 1, 58, 58 },
    -- Fake duck'ta exploit calismaz ve paketler ~14 tick bogulur; sirayla donen jitter
    -- ~0.2 sn'de bir donup tahmin edilebilir olur. Body yaw "Random": taraf her pakette
    -- rastgele (bkz. builder). Eskiden static + "Peek Fake" freestanding'di: tarafi
    -- Neverlose sectigi icin anti-brute tarafi degistiremiyordu (loglarda faz 1 ve 2'de
    -- hep "sol 58" ile kafadan vuruldun).
    ["Fake duck"]    = { 0, 0, 1, 58, 58 },
    ["Manual"]       = { 0, 0, 1, 60, 60 },
    ["Freestanding"] = { 0, 0, 1, 60, 60 },
    ["Safe head"]    = { 0, 0, 1, 30, 30 },
}

-- Exploit varsayilanlari: { exploit, defensive, hidden pitch, hidden yaw }
-- Hicbir durum varsayilan olarak "Always on" kullanmaz: oyun loglarinda zipladiktan,
-- egilip yurumeye ya da peek'e gectikten ~0.4 sn sonra (defensive modu "Always on"a
-- donunce) DT %0'a dusuyor ve vurulma tam o sirada geliyordu. "On peek" ve "Smart"ta
-- Neverlose'un modu hep "On Peek" kalir, durumlar arasinda degismez.
-- Hareket ederken ve havada "Smart": loglarda "Air | DT dolu, DEF yok" ve "Peek | DT
-- dolu, DEF yok" isabetleri vardi, yani Neverlose'un peek tespiti o anlari kacirdi.
-- Dururken / egilip beklerken aci tutan sensin; orada ilk atis hizi daha onemli.
-- Hidden yaw "Random" (v5.6): "Sideways" desync tarafina gore +-90 veriyordu, "Switch" pitch'i
-- de; defensive tick'lerinde acilari okuyan resolver kafanin hangi tarafta oldugunu oradan
-- gorebiliyordu. Rastgele aci tarafi ele vermez.
local EXPLOIT_DEFAULTS = {
    ["Standing"]     = { "Double tap", "On peek",   "Up",     "Random" },
    ["Moving"]       = { "Double tap", "Smart",     "Up",     "Random" },
    ["Slow walk"]    = { "Double tap", "Smart",     "Up",     "Random" },
    ["Crouching"]    = { "Double tap", "On peek",   "Up",     "Random" },
    ["Crouch move"]  = { "Double tap", "Smart",     "Up",     "Random" },
    ["Peek"]         = { "Double tap", "Smart",     "Up",     "Random" },
    ["Air"]          = { "Double tap", "Smart",     "Up",     "Spin" },
    ["Air crouch"]   = { "Double tap", "Smart",     "Up",     "Random" },
    ["Manual"]       = { "Double tap", "On peek",   "Off",    "Off" },
    ["Freestanding"] = { "Double tap", "On peek",   "Off",    "Off" },
    ["Safe head"]    = { "Double tap", "On peek",   "Off",    "Off" },
}

-- X-Way varsayilan acilari (Way 1..5)
local WAY_DEFAULTS = { -30, 0, 30, -15, 15 }

local MODIFIERS = { "Disabled", "Center", "Offset", "Random", "Spin", "3-Way", "5-Way" }
local EXPLOITS = { "Double tap", "Hide shots", "Binds" }
local DEF_MODES = { "Off", "On peek", "Smart", "Always on", "Tick based" }
local HIDDEN_PITCHES = { "Off", "Down", "Up", "Zero", "Switch", "Random", "Custom" }
local HIDDEN_YAWS = { "Off", "Sideways", "Spin", "Random", "Forward", "Custom" }

local menu = {}
-- Home: script, hafiza ve loglar. Baslik satirlari menu tablosunda degil (Enable kapaliyken de
-- gorunsun).
style.header = grp.info:label(style.title("crown", ("%s  V%s"):format(SCRIPT, VERSION)))
do
    local ok, name = pcall(function() return common.get_username() end)
    if ok and type(name) == "string" and name ~= "" then
        style.user = grp.info:label(style.title("user", name))
    end
end
menu.enabled        = style.tip(grp.info:switch(style.title("power-off", "Enable"), true),
    "Kapatinca butun Neverlose ayarlarin geri verilir.")
menu.recommended    = style.tip(grp.info:switch(style.title("wand-magic-sparkles", "Always use recommended settings"), true),
    "Acikken AA, exploit, builder ve resolver ayarlari her surumde en iyi bilinen degerlerde tutulur. " ..
    "Kendi ayarini denemek icin kapat.")
menu.home_info      = grp.info:label("Ayarlara dokunmana gerek yok; binds: manual yaw, freestanding, inverter.")
-- Ogrenilen anti-brute fazlari ve resolver seviyeleri Steam ID ile harita degisince de
-- kalir; bu dugme hepsini siler. Dugme API'si yoksa script'i dusurmesin.
pcall(function()
    menu.forget = style.tip(grp.data:button(style.title("trash-can", "Forget learned enemies"), function()
        if forget_enemies ~= nil then
            forget_enemies()
        end
    end, true), "Ogrenilen fazlari, resolver seviyelerini ve sniper verisini siler (db dahil).")
end)
pcall(function()
    menu.stats_reset = grp.data:button(style.title("rotate-left", "Reset stats"), function()
        stats, pending_misses, aim_stats = {}, {}, new_aim_stats()
    end, true)
end)
-- Konsol loglari tek yerde (tercih; onerilen ayarlara girmez). Resolver ve AA'yi verilerle
-- ayarlamak icin: resolver seviyesi, her aimbot atisi, vuruldun / iska ve round ozeti, anti-brute fazi.
menu.resolver_log   = style.tip(grp.console:switch(style.title("crosshairs", "Resolver log"), true),
    "Resolver seviyesi degisince ve jitter on bilgisinde tek satir.")
menu.shot_log       = style.tip(grp.console:switch(style.title("gun", "Shot log"), true),
    "Her aimbot atisi: hedef, sonuc, safe point, body aim, backtrack, hit chance, dusmanin AA'si. AI peek loglari da.")
menu.hit_log        = style.tip(grp.console:switch(style.title("heart-crack", "Hit log"), true),
    "Vuruldun / iska satirlari, round ozeti, teleport ve fake duck notlari.")
menu.brute_log      = grp.console:switch(style.title("arrows-rotate", "Anti-brute log"), false)

-- Anti-Aim
menu.pitch          = grp.aa:combo(style.title("arrows-up-down", "Pitch"), { "Down", "Disabled", "Fake Down", "Fake Up" })
menu.yaw_base       = grp.aa:combo(style.title("compass", "Yaw base"), { "At Target", "Local View" })
menu.manual         = grp.aa_raw:combo(style.title("arrows-left-right", "Manual yaw"), { "Off", "Left", "Right", "Forward" })
menu.inverter       = grp.aa_raw:switch(style.title("repeat", "Static inverter"), false)
menu.avoid_backstab = grp.aa:switch(style.title("person-falling", "Avoid backstab"), true)
menu.legit_use      = style.tip(grp.aa:switch(style.title("hand-pointer", "Legit AA on use"), true),
    "E'ye basili tutarken AA devam eder (bomba / rehine yaninda karisilmaz).")
menu.spin           = style.tip(grp.aa:switch(style.title("rotate", "Spin when idle"), true),
    "Canli dusman yokken (istersen warmup'ta) spin.")
do
    local gear = tracked(menu.spin:create())
    -- HvH sunucularinda warmup'ta da savasiliyor, o yuzden varsayilan kapali.
    menu.spin_warmup  = gear:switch("Warmup", false)
    menu.spin_enemies = gear:switch("No enemies alive", true)
    menu.spin_pitch   = gear:combo("Pitch", { "Disabled", "Down" })
    menu.spin_speed   = gear:slider("Speed", 1, 20, 6)
end
menu.freestanding   = grp.protect_raw:switch(style.title("arrows-turn-to-dots", "Freestanding"), false)
do
    local gear = tracked(menu.freestanding:create())
    menu.fs_air     = gear:switch("Disable in air", true)
    menu.fs_crouch  = gear:switch("Disable while crouching", false)
    menu.fs_slow    = gear:switch("Disable while slow walking", false)
    menu.fs_moving  = gear:switch("Disable while moving", false)
    -- Freestanding tusun kapaliyken de ayakta / egilip dururken (aci tutarken) acilir: kafa
    -- duvara donuk saklanir. Kafa yine de gorunuyorsa normal jitter'a donulur.
    menu.fs_auto    = gear:switch("Auto when standing still", true)
end
menu.safe_head      = style.tip(grp.protect:switch(style.title("helmet-safety", "Safe head"), true),
    "Bicak / zeus ile havada egilirken (istersen yuksekte) kafa sabit ve az desync.")
do
    local gear = tracked(menu.safe_head:create())
    menu.safe_knife = gear:switch("Knife/Zeus in air crouch", true)
    menu.safe_air   = gear:switch("Any air crouch", false)
    -- Yuksekte sabit kafa (yaw 0, desync 30) varsayilan kapali: v4.8 loglarinda alttaki dusman
    -- kafani gorurken Safe head'de 5 kafa mermisinin 4'u isabet etti (gordu 0.00-0.03 sn).
    -- Dusuk desync tam gorulurken kafayi ortaya getiriyordu; hareket durumunun AA'si kalir.
    menu.safe_high  = gear:switch("High ground", false)
end
menu.anti_brute     = style.tip(grp.protect:switch(style.title("shuffle", "Anti-bruteforce"), true),
    "Kafana gelen her mermide faz degisir; en az vuruldugun faz ogrenilir ve dusman basina hatirlanir.")
do
    local gear = tracked(menu.anti_brute:create())
    menu.brute_reset = gear:slider("Reset after", 1, 15, 6, nil, "s")
end
-- Fake duck'ta egik ve yavassin, DT/HS calismaz. Bicak / zeus tutan bir dusman
-- yaklasinca fake duck birakilir; uzaklasinca senin tusun yine gecerli olur.
menu.fd_guard       = grp.protect:switch(style.title("user-ninja", "Release fake duck near knife"), true)
-- Havadayken ve hareket ederken fake duck'in faydasi yok, sadece DT/HS'yi kapatir: v4.9-v5.0
-- loglarinda kafa olumlerinin cogu "Fake duck | FD, DT %0 (bind)" idi (havada FD de vardi;
-- fake duck egilme tusuna bagli olabilir). Yerinde dururken fake duck aynen calisir.
menu.fd_still       = grp.protect:switch(style.title("person", "Fake duck only when standing still"), true)

-- Exploits
menu.auto_exploit   = style.tip(grp.exploits:switch(style.title("bolt", "Auto exploit"), true),
    "Her durumun DT / HS secimi Builder'dan; kapaliyken senin bind'lerin.")
-- Scout / AWP / R8'de exploit. "Auto (learn)" (varsayilan, v5.6): kafana gelen mermilere gore
-- HS / DT secer, once HS, en az 4 mermi gormeden degistirmez (bkz. sniper). v4.7-v5.5'te HS
-- sabitti: v4.6'da DT'ye gecince atistan hemen sonra vuruluyordun, v5.3-v5.5 loglarinda HS
-- ile de peek'te ve atistan 0.06-0.14 sn sonra kafadan vurulmalar surdu; hangisi daha iyi,
-- senin maclarindaki veri karar verir. "Hide shots": hep HS. "Same as state": durumun exploit'i.
menu.sniper_exploit = style.tip(grp.exploits:combo(style.title("bullseye", "Snipers (SSG08/AWP/R8)"),
    { "Auto (learn)", "Hide shots", "Same as state" }),
    "Auto: kafana daha az mermi yedigin exploit (once HS, en az 4 mermiden sonra karar).")
-- DT / HS atistan ya da fake duck'tan sonra yeniden sarj olurken oyuncu sunucuda yerinde
-- donar. Tehdit kafani goruyorken sarj bekletilir, siperin arkasina gecince dolar.
menu.safe_recharge  = style.tip(grp.exploits:switch(style.title("battery-half", "Safe recharge"), true),
    "Biri kafani goruyorken DT sarji bekletilir (sarj olurken yerinde donarsin), siperde dolar.")
menu.hidden_spin    = grp.exploits:slider(style.title("rotate", "Hidden spin speed"), 1, 30, 10)
menu.exploit_info   = grp.exploits:label("Per-state exploit settings are in the Builder.")
-- Hareket ederken tehdidin gorus alanina giriyorsan (ya da birazdan gireceksen)
-- peek assist tusu olmadan da Peek durumuna gecilir.
menu.auto_peek      = style.tip(grp.peek:switch(style.title("eye", "Auto peek"), true),
    "Hareket ederken gorus alanina girince Peek durumu (tus gerekmez).")
-- Peek Assist tusu basiliyken (hareket tuslarina basmadan) script yanlari tarar, oradan
-- dusmani vurabilecegin en yakin noktaya kendisi yurur (bkz. ai_peek).
menu.ai_peek        = style.tip(grp.peek:switch(style.title("robot", "AI peek (hold Peek Assist)"), true),
    "Peek Assist tusunu basili tut, hareket tuslarina basma: oldurecek atisin oldugu en yakin noktaya yurur.")
-- AI peek yururken / beklerken DT defensive'i zorlanir: dusman seni gormeden lag baslar.
menu.peek_defensive = grp.peek:switch(style.title("shield-halved", "Defensive during AI peek"), true)
-- Dururken / egilip beklerken ("On peek") bir dusman sana dogru peek atiyorsa (hizindan
-- tahmin) DT defensive'i o gorunmeden zorlanir; ilk mermisi gelirken LC kirik olur.
menu.anti_peek      = style.tip(grp.defensive:switch(style.title("shield", "Defensive vs enemy peeks"), true),
    "Aci tutarken sana peek atan dusman gorunmeden defensive baslar.")
-- Havadayken bir dusman kafani gorunce DT ile isinlanilir (sarj dolunca tekrar).
menu.air_teleport   = grp.defensive:switch(style.title("person-running", "Teleport in air when seen"), true)
-- Havada DT doluyken defensive her tick zorlanir (gorulmeyi beklemeden): havada surekli lag,
-- hidden acilar (spin). "Havada lag olmuyor": Smart sadece biri seni gorunce zorluyordu.
menu.air_lag        = grp.defensive:switch(style.title("cloud", "Air lag (defensive every tick)"), true)
-- Scout / AWP / R8 havadayken DT kullanir (inince yine Hide shots): Neverlose'un lua'dan
-- defensive zorlamasi ve teleport'u DT ister; HS ile havada lag olmuyordu.
menu.sniper_air_dt  = grp.defensive:switch(style.title("crosshairs", "Snipers use DT in the air"), true)

-- Ragebot. Neverlose'un kendi resolver'i acilari cozmeye devam eder. Bu katman, bir dusmana
-- resolver yuzunden ("correction") iska gectikce sadece o dusmana karsi safe point'i
-- yukseltir; isabetler geldikce geri indirir.
menu.resolver       = style.tip(grp.resolver:switch(style.title("brain", "Adaptive resolver"), true),
    "Correction iskasinda sadece o dusmana ve o hareket durumuna karsi safe point: 1 iska Prefer, 2 iska Force.")
-- Body Aim'i hedefe gore secer: govde olduruyorsa (tek mermi ya da DT ile iki) govde,
-- scout / AWP / R8'de govde oldurmuyorsa kafa, resolver iki kez yanildiysa govde.
menu.smart_baim     = style.tip(grp.resolver:switch(style.title("person-rays", "Smart body aim"), true),
    "Govde olduruyorsa govde (tek mermi ya da DT ile iki); resolver iki kez yanildiysa govde.")
-- Scout / AWP / R8'de minimum hasar hedefin canina cekilir: aimbot sadece oldurecek yere
-- ates eder. Tam canli dusmanda bu kafa demek; govde ancak olduruyorsa vurulur.
menu.head_only      = style.tip(grp.resolver:switch(style.title("skull", "Head unless body kills (snipers)"), true),
    "Biri seni gorebiliyorken scout / AWP / R8 sadece oldurecek atisa ates eder (Min. Damage can + 1).")
menu.resolver_info  = grp.resolver:label("Raises safe points per enemy after resolver misses.")

menu.state = grp.angles_raw:combo(style.title("list", "State"), STATES)

local AA_KEYS = {
    yaw_mode = true, yaw_left = true, yaw_right = true, ways = true,
    way1 = true, way2 = true, way3 = true, way4 = true, way5 = true,
    yaw_random = true, modifier = true, mod_random = true, mod_offset = true,
    body_yaw = true, avoid_overlap = true, body_fs = true, delay_random = true, limit_random = true,
    delay = true, left_limit = true, right_limit = true,
}

local builder = {}
for i, state in ipairs(STATES) do
    label_prefix = state .. " "
    local d = DEFAULTS[state]
    local special = i > MOVEMENT_STATES
    local s = {}
    if SPECIAL_INFO[state] ~= nil then
        s.info = grp.angles:label(SPECIAL_INFO[state])
    end
    if i > 1 and not special then
        s.override = grp.angles:switch("Override", true)
    end
    -- L&R: desync tarafina gore iki aci. X-Way: her flip'te siradaki aciya gecer;
    -- desync her flip'te taraf degistirdigi icin aci/taraf eslesmesi surekli kayar.
    s.yaw_mode      = grp.angles:combo("Yaw mode", { "L&R", "X-Way" })
    s.yaw_left      = grp.angles:slider("Yaw left", -180, 180, d[1], nil, DEG)
    s.yaw_right     = grp.angles:slider("Yaw right", -180, 180, d[2], nil, DEG)
    s.ways          = grp.angles:slider("Ways", 3, 5, 3)
    for n = 1, 5 do
        s["way" .. n] = grp.angles:slider("Way " .. n, -180, 180, WAY_DEFAULTS[n], nil, DEG)
    end
    -- Fake duck: paket ~14 tick bogulu, dusman her pakette tek kayit gorur. Her pakette rastgele
    -- yaw (20) ve desync miktari (10) + rastgele taraf: v5.3-v5.4 loglarinda fake duck'ta kafadan
    -- vurulmalar surdu; sabit yaw'da tek bilinmeyen desync tarafiydi.
    local fd_state = state == "Fake duck"
    s.yaw_random    = grp.angles:slider("Yaw randomize", 0, 30, fd_state and 20 or 0, nil, DEG)
    s.modifier      = grp.angles:combo("Yaw modifier", MODIFIERS)
    s.mod_random    = tracked(s.modifier:create()):slider("Randomize", 0, 60, 0, nil, DEG)
    s.mod_offset    = grp.angles:slider("Modifier offset", -180, 180, 0, nil, DEG)
    -- Combo varsayilani ilk eleman oldugu icin ozel durumlarda Static basta.
    -- Random: desync tarafi her paket dongusunde (Jitter delay kadar) rastgele secilir; Jitter
    -- gibi sirayla donmez, tahmin edilecek bir desen yoktur. Fake duck ve Safe head'de
    -- varsayilan: ikisinde de eskiden sabit taraf vardi ve loglarda kafadan vuruldun.
    local static_default = special or state == "Fake duck"
    local body_items
    if state == "Fake duck" or state == "Safe head" then
        body_items = { "Random", "Static", "Jitter", "Off" }
    elseif static_default then
        body_items = { "Static", "Jitter", "Random", "Off" }
    else
        body_items = { "Jitter", "Static", "Random", "Off" }
    end
    s.body_yaw      = grp.angles:combo("Body yaw", body_items)
    local body_gear = tracked(s.body_yaw:create())
    s.avoid_overlap = body_gear:switch("Avoid overlap", false)
    s.body_fs       = body_gear:combo("Freestanding",
        state == "Fake duck" and { "Peek Fake", "Off", "Peek Real" } or { "Off", "Peek Fake", "Peek Real" })
    -- Jitter her pakette tam sirayla donerse resolver'lar bunu yakalar (ornek resolver son
    -- 4 aci degisiminin 3'u yon degistiriyorsa "jitter" deyip tarafi esliyordu). Her
    -- donuste 0-1 paket rastgele bekleme bu kati sirayi bozar. Sadece DT/HS aktifken.
    s.delay_random  = body_gear:slider("Delay randomize", 0, 5, static_default and 0 or 1, nil, "t")
    s.limit_random  = body_gear:slider("Limit randomize", 0, 30, fd_state and 10 or 0, nil, DEG)
    s.delay         = grp.angles:slider("Jitter delay", 1, 10, d[3], nil, "t")
    s.left_limit    = grp.angles:slider("Left limit", 0, 60, d[4], nil, DEG)
    s.right_limit   = grp.angles:slider("Right limit", 0, 60, d[5], nil, DEG)

    local e = EXPLOIT_DEFAULTS[state]
    if e ~= nil then
        s.exploit_label      = grp.bexploit:label(style.title("bolt", state))
        s.exploit            = grp.bexploit:combo("Exploit", default_first(EXPLOITS, e[1]))
        s.def_mode           = grp.bexploit:combo("Defensive", default_first(DEF_MODES, e[2]))
        s.def_ticks          = grp.bexploit:slider("Defensive every", 2, 22, 14, nil, "t")
        s.hidden_pitch       = grp.bexploit:combo("Hidden pitch", default_first(HIDDEN_PITCHES, e[3]))
        s.hidden_pitch_value = grp.bexploit:slider("Pitch value", -89, 89, 0, nil, DEG)
        s.hidden_yaw         = grp.bexploit:combo("Hidden yaw", default_first(HIDDEN_YAWS, e[4]))
        s.hidden_yaw_value   = grp.bexploit:slider("Yaw value", -180, 180, 90, nil, DEG)
    end
    builder[state] = s
end
label_prefix = ""
-- Global ve Fake duck'in exploit ayari yok (Global AA'yi paylasir, fake duck'ta DT/HS calismaz).
menu.no_exploit = grp.bexploit_raw:label("This state has no exploit settings (Global shares AA only, " ..
    "fake duck turns DT/HS off).")

-- Visuals (tercih; onerilen ayarlara girmez).
menu.indicators  = grp.indicators:switch(style.title("crosshairs", "Crosshair indicators"), true)
menu.accent      = menu.indicators:color_picker(color(150, 190, 255, 255))
menu.arrows      = grp.indicators:switch(style.title("arrows-left-right", "Manual arrows"), true)
menu.arrow_color = menu.arrows:color_picker(color(150, 190, 255, 255))
menu.stats_panel = style.tip(grp.indicators:switch(style.title("table-list", "Stats panel"), false),
    "Durum basina vurulma / kafa / iska, DT ve defensive orani, AI peek ve faz istatistikleri.")
-- Resolver paneli: her dusman icin resolver'in onu ne kadar cozdugu (resolver'a bagli isabet /
-- (isabet + correction iskasi)). Menu acikken fareyle tutup tasinir, sag alt kosesinden cekilerek
-- buyutulur; yeri (ekranin binde biri) ve boyutu config'e kaydedilir.
menu.res_panel   = style.tip(grp.panel:switch(style.title("chart-simple", "Resolver panel"), true),
    "Hedefin canli cozum yuzdesi ve isabet sansi. Menu acikken fareyle tasi, sag alt kosesinden buyut.")
do
    local gear = menu.res_panel:create()
    menu.panel_size = gear:slider("Size", 70, 200, 100, nil, "%")
    menu.panel_x    = gear:slider("Position X", 0, 1000, 12)
    menu.panel_y    = gear:slider("Position Y", 0, 1000, 330)
end

local function update_visibility()
    local on = menu.enabled:get()
    for key, element in pairs(menu) do
        if key ~= "enabled" then
            element:visibility(on)
        end
    end
    menu.accent:visibility(on and menu.indicators:get())
    menu.arrow_color:visibility(on and menu.arrows:get())
    menu.sniper_exploit:visibility(on and menu.auto_exploit:get())
    menu.peek_defensive:visibility(on and menu.ai_peek:get())

    local selected = menu.state:get()
    menu.no_exploit:visibility(on and builder[selected] ~= nil and builder[selected].def_mode == nil)
    for _, state in ipairs(STATES) do
        local s = builder[state]
        local shown = on and state == selected
        local active = shown and (s.override == nil or s.override:get())
        for key, element in pairs(s) do
            if AA_KEYS[key] then
                element:visibility(active)
            else
                element:visibility(shown)
            end
        end
        if active then
            local xway = s.yaw_mode:get() == "X-Way"
            s.yaw_left:visibility(not xway)
            s.yaw_right:visibility(not xway)
            s.ways:visibility(xway)
            for n = 1, 5 do
                s["way" .. n]:visibility(xway and n <= s.ways:get())
            end
            local body = s.body_yaw:get()
            local modded = s.modifier:get() ~= "Disabled"
            local desync = body ~= "Off"
            s.mod_offset:visibility(modded)
            s.mod_random:visibility(modded)
            s.delay:visibility(body == "Jitter" or body == "Random")
            s.delay_random:visibility(body == "Jitter" or body == "Random")
            s.left_limit:visibility(desync)
            s.right_limit:visibility(desync)
            s.limit_random:visibility(desync)
            s.avoid_overlap:visibility(desync)
            s.body_fs:visibility(body == "Static")
        end
        if shown and s.def_mode ~= nil then
            local mode = s.def_mode:get()
            local hidden = mode ~= "Off"
            s.exploit:visibility(menu.auto_exploit:get())
            s.def_ticks:visibility(mode == "Tick based")
            s.hidden_pitch:visibility(hidden)
            s.hidden_pitch_value:visibility(hidden and s.hidden_pitch:get() == "Custom")
            s.hidden_yaw:visibility(hidden)
            s.hidden_yaw_value:visibility(hidden and s.hidden_yaw:get() == "Custom")
        end
    end
end

for _, element in ipairs({ menu.enabled, menu.auto_exploit, menu.ai_peek, menu.indicators, menu.arrows, menu.state }) do
    element:set_callback(update_visibility)
end
for _, s in pairs(builder) do
    for _, key in ipairs({ "override", "yaw_mode", "ways", "modifier", "body_yaw", "def_mode", "hidden_pitch", "hidden_yaw" }) do
        if s[key] ~= nil then
            s[key]:set_callback(update_visibility)
        end
    end
end
update_visibility()

-- Kaydedilmis varsayilanlara don. Script yuklenince, ilk oyun tick'inde, her config
-- yuklemesinden sonra ve acik oldugu surece 64 tick'te bir: onerilen
-- degerden farkli olan ayar geri alinir. Sadece yukleme aninda donmek yetmiyordu: oyun
-- loglarinda Fake duck'ta limit 58 yerine 60 ve hep ayni taraf goruldu, yani Fake duck
-- eski bir config'in (Fake duck durumu eklenmeden onceki Manual'in) degerleriyle
-- calisiyordu. Neverlose config degerlerini lua ayarlarina sonradan da uygulayabiliyor.
-- Kapaliyken hicbir sey degistirilmez; yuklemede kac ayarin farkli oldugu yazilir.
-- every: kontrol araligi (tick). report: ayni uyari en fazla bu kadar saniyede bir yazilir.
-- report_off: kapaliyken farklari bir kez yaz (ilk oyun tick'inde ve config yuklenince).
local recommended_state = { every = 64, report = 30, pending = true, tick = -1000, reported = -huge, report_off = false }

local function apply_recommended()
    local rec = recommended_state
    rec.pending, rec.tick = false, globals.tickcount
    local on = menu.recommended:get()
    -- Kapaliyken sadece bir kez (report_off) farklar sayilip yazilir.
    if not on and not rec.report_off then
        return
    end
    rec.report_off = false
    local count, example = 0, nil
    for _, item in ipairs(recommended) do
        local ok, value = pcall(item.element.get, item.element)
        if ok and value ~= item.value then
            count = count + 1
            example = example or ("%s %s, onerilen %s"):format(item.label, tostring(value), tostring(item.value))
            if on then
                pcall(item.element.set, item.element, item.value)
            end
        end
    end
    if count == 0 then
        return
    end
    if not on then
        print(("[%s] Always use recommended settings kapali: %d ayar onerilenden farkli (orn. %s)"):format(
            SCRIPT, count, example))
        return
    end
    update_visibility()
    local now = globals.realtime
    if now < rec.reported or now - rec.reported >= rec.report then
        rec.reported = now
        print(("[%s] %d ayar onerilen degerine donduruldu (orn. %s)"):format(SCRIPT, count, example))
    end
end

menu.recommended:set_callback(function()
    if menu.recommended:get() then
        apply_recommended()
    end
end)
apply_recommended()
recommended_state.pending, recommended_state.report_off = true, true

pcall(function()
    events.config_state:set(protect("config_state", function(state)
        if state == "post_load" then
            recommended_state.pending, recommended_state.report_off = true, true
        end
    end))
end)

-------------------------------------------------------------------------------
-- Durum tespiti
-------------------------------------------------------------------------------

-- Gorus tespiti: tehdit kafana mermi gecirebiliyor mu (simdi ve kisa sure sonra)?
-- utils.trace_bullet yoksa "available" false olur ve buna bagli ozellikler eski
-- davranisa doner.
local trace_bullet = nil
do
    local ok, fn = pcall(function() return utils.trace_bullet end)
    if ok and type(fn) == "function" then
        trace_bullet = fn
    end
end

local EXPOSE_EVERY = 2         -- tick; iz cizmek ucuz degil, her tick gerekmez
local EXPOSE_LOOKAHEAD = 0.2   -- saniye; bu kadar sonra nerede olacagina da bakilir
local PEEK_HOLD = 8            -- tick; gorus kesilince Peek'te bu kadar daha kalinir

-- Havadayken kafanin yuksekligi de degisir: kutu ustunden zipladiginda kafa siperin
-- ustune cikar. Dikey konum da tahmin edilir (sv_gravity 800, ziplama hizi ~302).
local GRAVITY, JUMP_SPEED = 800, 301.99

-- Diger dusmanlar: her guncellemede tehdit disindaki bir dusman sirayla kontrol edilir
-- (tek ek iz). Yandan bakan bir dusman da Smart defensive, Break LC, Safe recharge ve
-- auto peek'i tetikler. Bir dusmanin gorusu OTHER_HOLD tick gecerli sayilir; tur bitmeden
-- tekrar kontrol edilemeyebilir.
local OTHER_HOLD = 12

-- Log icin: sight[index] = { first, last } = bir dusmanin kafani kesintisiz gordugu ilk ve
-- son tick. gap tick'ten uzun kesilen gorus yeni gorus sayilir (diger dusmanlar sirayla
-- kontrol edildigi icin araliklar uzun olabilir); keep tick sonra unutulur. Hasar olayi
-- ping kadar gec geldigi icin log son recent tick'teki gorusu sayar.
local SIGHT = { gap = 24, keep = 64, recent = 32 }

-- others[index] = dusmanin kafani en son gordugu tick; any = kisa sure icinde biri gordu
-- peeked = bir dusman hareket ederek kafani gorecegi yere geliyor (bkz. enemy_eye_ahead).
-- edge: kafa merkezinin yanindaki iki noktaya da bakilir (bkz. head_visible_to).
-- peeking: AI peek'in su an peek attigi dusman (yururken / beklerken), yoksa nil.
local exposure = { available = trace_bullet ~= nil, tick = -1000, now = false, soon = false,
    any = false, peeked = false, others = {}, turn = 0, sight = {}, facing = nil, edge = 3.5, peeking = nil }
local peek = { until_tick = -1000 }

-- AA'nin baktigi tehdit. Ayni tick'te gorus, yukseklik, anti-brute ve resolver ayri ayri
-- soruyordu; tick basina bir kez okunur.
local threat_cache = { tick = nil, value = nil }
local function current_threat()
    local tick = globals.tickcount
    if threat_cache.tick ~= tick then
        local ok, threat = pcall(entity.get_threat)
        threat_cache.tick, threat_cache.value = tick, ok and threat or nil
    end
    return threat_cache.value
end

local function index_of(ent)
    local ok, index = pcall(function() return ent:get_index() end)
    if ok and type(index) == "number" then
        return index
    end
    return nil
end

local function dormant(ent)
    local ok, value = pcall(function() return ent:is_dormant() end)
    return ok and value == true
end

-- Neverlose'un tehdidi yoksa en yakin canli, dormant olmayan dusman. Oyun loglarinda
-- "tehdit yok" iken havada kafadan vuruldun: AA hicbir dusmana gore donmuyordu ve gorus
-- kontrolu de tehdide bakamiyordu. Tick basina bir kez hesaplanir.
local function aa_threat()
    local threat = current_threat()
    if threat ~= nil then
        return threat
    end
    local tick = globals.tickcount
    if threat_cache.near_tick ~= tick then
        threat_cache.near_tick, threat_cache.near = tick, nil
        local ok_lp, lp = pcall(entity.get_local_player)
        local ok_mine, mine = pcall(function() return lp:get_origin() end)
        local ok, list = pcall(entity.get_players, true)
        if ok_lp and ok_mine and mine ~= nil and ok and type(list) == "table" then
            local best = huge
            for _, enemy in ipairs(list) do
                local ok_alive, alive = pcall(function() return enemy:is_alive() end)
                local ok_pos, pos = pcall(function() return enemy:get_origin() end)
                if ok_alive and alive and not dormant(enemy) and ok_pos and pos ~= nil then
                    local dx, dy, dz = pos.x - mine.x, pos.y - mine.y, pos.z - mine.z
                    local distance = dx * dx + dy * dy + dz * dz
                    if distance < best then
                        best, threat_cache.near = distance, enemy
                    end
                end
            end
        end
    end
    return threat_cache.near
end

-- Merkez gorunmuyorsa kafanin iki yan kenarina da (gorus cizgisine dik, exposure.edge birim)
-- iz atilir. Dusmanin aimbot'u kafanin kenarina da (multipoint) ates eder: loglarda "gormedi"
-- iken kafadan vurulmalar vardi, merkez siperin arkasinda kalinca gorus kaciyordu.
local function head_visible_to(threat, eye, head, dx, dy, dz)
    local x, y, z = head.x + dx, head.y + dy, head.z + dz
    local function hits(px, py)
        local ok, damage = pcall(trace_bullet, threat, eye, vector(px, py, z))
        return ok and type(damage) == "number" and damage > 0
    end
    if hits(x, y) then
        return true
    end
    local sx, sy = x - eye.x, y - eye.y
    local length = sqrt(sx * sx + sy * sy)
    if length < 1 then
        return false
    end
    local ex, ey = -sy / length * exposure.edge, sx / length * exposure.edge
    return hits(x + ex, y + ey) or hits(x - ex, y - ey)
end

-- EXPOSE_LOOKAHEAD sonra kafa ne kadar yukari / asagi gidecek. Yerdeyken 0; ziplama
-- tusuna yeni basildiysa ziplama hizi kullanilir (hiz o tick'te daha 0).
local function vertical_lookahead(lp, cmd)
    local vz
    if bit.band(lp.m_fFlags, 1) == 0 then
        vz = lp.m_vecVelocity.z
    elseif cmd.in_jump == true then
        vz = JUMP_SPEED
    else
        return 0
    end
    local t = EXPOSE_LOOKAHEAD
    return vz * t - 0.5 * GRAVITY * t * t
end

-- Dusmanin EXPOSE_LOOKAHEAD sn sonraki goz konumu (yatay hiziyla); durgunsa nil. Sana
-- dogru peek atan dusman kafani gormeden once yakalanir: v4.8 loglarinda olumlerin
-- cogunda dusman seni 0.00-0.03 sn'de vurdu, defensive ancak o gorunce aciliyordu.
local function enemy_eye_ahead(enemy, eye)
    local ok, vx, vy = pcall(function()
        local v = enemy.m_vecVelocity
        return v.x, v.y
    end)
    if not ok or type(vx) ~= "number" or type(vy) ~= "number" or vx * vx + vy * vy < 400 then
        return nil
    end
    return vector(eye.x + vx * EXPOSE_LOOKAHEAD, eye.y + vy * EXPOSE_LOOKAHEAD, eye.z)
end

local update_exposure
do
    local function mark_sight(index, now)
        local s = exposure.sight[index]
        if s == nil or now < s.last or now - s.last > SIGHT.gap then
            exposure.sight[index] = { first = now, last = now }
        else
            s.last = now
        end
    end

    update_exposure = function(lp, cmd)
        if not exposure.available then
            return
        end
        local now = globals.tickcount
        if now >= exposure.tick and now - exposure.tick < EXPOSE_EVERY then
            return
        end
        exposure.tick = now
        exposure.now, exposure.soon, exposure.peeked = false, false, false
        local head = lp:get_hitbox_position(0)
        if head == nil then
            exposure.any, exposure.others = false, {}
            return
        end
        -- Fake duck'ta kafa egilip kalkar; dusman kafayi ayakta yuksekliginde de gorur (v5.4
        -- loglarinda fake duck'ta "gormedi" iken kafadan vuruldun). Kafa ayakta yuksekligine alinir.
        local ok_base, base = pcall(function() return effective("fakeduck") and lp:get_origin() or nil end)
        if ok_base and base ~= nil and head.z < base.z + 64 then
            head = vector(head.x, head.y, base.z + 64)
        end

        local threat = aa_threat()
        local threat_index = threat ~= nil and index_of(threat) or nil
        -- Dormant tehdidin konumu eski; ona gore karar verilmez.
        if threat ~= nil and not dormant(threat) then
            local ok_eye, eye = pcall(threat.get_eye_position, threat)
            if ok_eye and eye ~= nil then
                exposure.now = head_visible_to(threat, eye, head, 0, 0, 0)
                if exposure.now and threat_index ~= nil then
                    mark_sight(threat_index, now)
                end
                if not exposure.now then
                    local velocity = lp.m_vecVelocity
                    exposure.soon = head_visible_to(threat, eye, head, velocity.x * EXPOSE_LOOKAHEAD,
                        velocity.y * EXPOSE_LOOKAHEAD, vertical_lookahead(lp, cmd))
                end
                if not exposure.now and not exposure.soon then
                    local ahead = enemy_eye_ahead(threat, eye)
                    exposure.peeked = ahead ~= nil and head_visible_to(threat, ahead, head, 0, 0, 0)
                    exposure.soon = exposure.peeked
                end
            end
        end

        -- Tehdit olmayan, canli, dormant olmayan dusmanlar; siradaki ikisine iz atilir (yandan
        -- cikip hemen vuran daha erken yakalansin). Listede olmayan / olen / dormant olan
        -- dusmanin eski gorusu hemen silinir.
        local present, candidates = {}, {}
        local ok, list = pcall(entity.get_players, true)
        if ok and type(list) == "table" then
            for _, enemy in ipairs(list) do
                local index = index_of(enemy)
                local ok_alive, alive = pcall(function() return enemy:is_alive() end)
                if index ~= nil and index ~= threat_index and ok_alive and alive and not dormant(enemy) then
                    present[index] = true
                    candidates[#candidates + 1] = { enemy = enemy, index = index }
                end
            end
        end
        for _ = 1, min(2, #candidates) do
            exposure.turn = exposure.turn % #candidates + 1
            local pick = candidates[exposure.turn]
            local ok_eye, eye = pcall(pick.enemy.get_eye_position, pick.enemy)
            if ok_eye and eye ~= nil and head_visible_to(pick.enemy, eye, head, 0, 0, 0) then
                exposure.others[pick.index] = now
                mark_sight(pick.index, now)
            else
                -- Birazdan gorecek (sana dogru peek atiyor): gorus sayilir, log'a "gordu" yazilmaz.
                local ahead = ok_eye and eye ~= nil and enemy_eye_ahead(pick.enemy, eye) or nil
                if ahead ~= nil and head_visible_to(pick.enemy, ahead, head, 0, 0, 0) then
                    exposure.others[pick.index] = now
                    exposure.peeked = true
                else
                    exposure.others[pick.index] = nil
                end
            end
        end
        exposure.any = false
        for index, seen in pairs(exposure.others) do
            if not present[index] or now < seen or now - seen > OTHER_HOLD then
                exposure.others[index] = nil
            else
                exposure.any = true
            end
        end
        for index, s in pairs(exposure.sight) do
            if now < s.last or now - s.last > SIGHT.keep then
                exposure.sight[index] = nil
            end
        end
    end
end

-- Herhangi bir dusman kafani goruyor ya da tehdit birazdan gorecek.
-- Kafanin yanindan mermi atan dusman (bkz. bullet_impact): izler onu gormese bile
-- (duvardan, dormant iken) seni goruyor demektir. shot = { index, tick }; 32 tick "goruyor"
-- sayilir, tehdit seni gormuyorsa AA 64 tick ona doner.
local seen_by_enemy, recent_shooter
do
    local function shot_recently(hold)
        local now = globals.tickcount
        return exposure.shot ~= nil and now >= exposure.shot.tick and now - exposure.shot.tick <= hold
    end

    seen_by_enemy = function()
        return exposure.now or exposure.soon or exposure.any or shot_recently(32)
    end

    -- Tehdit seni gormuyorken son 1 sn icinde kafana ates eden dusman; yoksa nil. Loglarda bir
    -- dusman uc kez "AA hedefi degil, gormedi" iken ates etti: AA hep baskasina donuktu.
    recent_shooter = function()
        if exposure.now or exposure.soon or not shot_recently(64) then
            return nil
        end
        local ok, ent = pcall(entity.get, exposure.shot.index)
        local ok_alive, alive = pcall(function() return ent:is_alive() end)
        -- Dormant dusmanin konumu eski; ona donulmez.
        if ok and ok_alive and alive and not dormant(ent) then
            return ent
        end
        return nil
    end
end

-- Tehdit seni gormuyor (ve birazdan da gormeyecek) ama baska bir dusman goruyorsa, en son
-- goren o dusman; yoksa nil.
local function seeing_flanker()
    if exposure.now or exposure.soon or not exposure.any then
        return nil
    end
    local best, best_tick = nil, nil
    for index, seen in pairs(exposure.others) do
        if best_tick == nil or seen > best_tick then
            best, best_tick = index, seen
        end
    end
    local ok, ent = pcall(entity.get, best)
    if ok then
        return ent
    end
    return nil
end

local detect_movement
do
    -- Histerezis: girme ve cikma esikleri farkli, boylece sinirda durum titremez.
    local MOVE_ENTER, MOVE_LEAVE = 10, 5
    local DUCK_ENTER, DUCK_LEAVE = 0.7, 0.5
    -- Yere indikten sonra bu kadar tick daha "havada" sayilir.
    local LANDING_TICKS = 3

    -- Yerdeyken yuklenince ilk tick'lerde "havada" sayilmasin diye dolu baslar.
    local motion = { ground_ticks = 64, moving = false, ducked = false }

    detect_movement = function(lp, cmd)
        local on_ground = bit.band(lp.m_fFlags, 1) ~= 0
        motion.ground_ticks = on_ground and min(motion.ground_ticks + 1, 64) or 0

        local speed = lp.m_vecVelocity:length2d()
        if speed > MOVE_ENTER then
            motion.moving = true
        elseif speed < MOVE_LEAVE then
            motion.moving = false
        end

        local duck = lp.m_flDuckAmount
        if duck > DUCK_ENTER then
            motion.ducked = true
        elseif duck < DUCK_LEAVE then
            motion.ducked = false
        end

        local crouching = motion.ducked or effective("fakeduck")
        if cmd.in_jump == true or motion.ground_ticks < LANDING_TICKS then
            return crouching and "Air crouch" or "Air"
        end
        -- Fake duck peek'ten de once gelir: exploit calismadigi icin Peek'in exploit
        -- ayarlari burada ise yaramaz, AA tek basina korur.
        if effective("fakeduck") then
            return "Fake duck"
        end
        if peek_key_held() then
            return "Peek"
        end
        -- Hareket ederken tehdidin gorus alanina girmek = peek. Durunca acini
        -- tutuyorsundur, o zaman normal duruma donulur.
        if menu.auto_peek:get() and motion.moving then
            if seen_by_enemy() then
                peek.until_tick = globals.tickcount + PEEK_HOLD
            end
            if globals.tickcount >= peek.until_tick - PEEK_HOLD and globals.tickcount <= peek.until_tick then
                return "Peek"
            end
        end
        if crouching then
            return motion.moving and "Crouch move" or "Crouching"
        end
        if motion.moving then
            return get("slowwalk") and "Slow walk" or "Moving"
        end
        return "Standing"
    end
end

local function settings_for(state)
    local s = builder[state]
    if s.override ~= nil and not s.override:get() then
        return builder["Global"]
    end
    return s
end

local MELEE = { CKnife = true, CKnifeGG = true, CWeaponTaser = true }

-- Silahin sinif adi. R8, Desert Eagle ile ayni sinifi (CDEagle) kullandigi icin
-- item index'ine (64) bakilip "Revolver" olarak ayrilir.
local function weapon_class(lp)
    local weapon = lp:get_player_weapon()
    if weapon == nil then
        return nil
    end
    local ok, class = pcall(weapon.get_classname, weapon)
    if not ok or type(class) ~= "string" then
        return nil
    end
    if class == "CDEagle" then
        local ok_index, index = pcall(function() return weapon.m_iItemDefinitionIndex end)
        if ok_index and index == 64 then
            return "Revolver"
        end
    end
    return class
end

local function is_grenade(class)
    return class ~= nil and (class:find("Grenade", 1, true) ~= nil or class:find("Flashbang", 1, true) ~= nil)
end

local function origin_of(ent)
    local ok, pos = pcall(ent.get_origin, ent)
    if ok then
        return pos
    end
    return nil
end

-- Hedeften en az 35 birim yukaridaysak kafa onun icin acikta kalir.
local safe_head_active
do
    local function on_high_ground(lp)
        local threat = aa_threat()
        if threat == nil then
            return false
        end
        local mine, theirs = origin_of(lp), origin_of(threat)
        return mine ~= nil and theirs ~= nil and mine.z - 35 > theirs.z
    end

    local HIGH_GROUND_STATES = {
        ["Standing"] = true, ["Moving"] = true, ["Slow walk"] = true,
        ["Crouching"] = true, ["Crouch move"] = true, ["Peek"] = true,
    }

    safe_head_active = function(lp, move_state, class)
        if not menu.safe_head:get() then
            return false
        end
        if move_state == "Air crouch" then
            if menu.safe_air:get() then
                return true
            end
            if menu.safe_knife:get() and MELEE[class] then
                return true
            end
        end
        -- Yuksekteyken ama duvar arkasindaysan kafayi sabitlemeye gerek yok; sadece
        -- tehdit kafani gercekten gorebiliyorsa (iz yoksa sadece yukseklige bakilir).
        return HIGH_GROUND_STATES[move_state] == true and menu.safe_high:get() and on_high_ground(lp)
            and (not exposure.available or exposure.now)
    end
end

local function freestanding_allowed(move_state)
    local auto = menu.fs_auto:get() and (move_state == "Standing" or move_state == "Crouching")
    if not menu.freestanding:get() and not auto then
        return false
    end
    if (move_state == "Air" or move_state == "Air crouch") and menu.fs_air:get() then
        return false
    end
    if (move_state == "Crouching" or move_state == "Crouch move" or move_state == "Fake duck") and menu.fs_crouch:get() then
        return false
    end
    if move_state == "Slow walk" and menu.fs_slow:get() then
        return false
    end
    if (move_state == "Moving" or move_state == "Peek") and menu.fs_moving:get() then
        return false
    end
    return true
end

-- Neverlose freestanding bir aci bulmadiysa ya da kafa yine de aciktaysa (yani
-- freestanding saklayamamis) normal hareket durumunun jitter'i kullanilir.
local function freestanding_has_target()
    if exposure.available and exposure.now then
        return false
    end
    if api.get_target == nil then
        return true
    end
    return api.get_target(true) ~= nil
end

local function exploit_active()
    if effective("hideshots") then
        return true
    end
    if not effective("doubletap") then
        return false
    end
    local charge = api.charge ~= nil and api.charge() or nil
    return type(charge) ~= "number" or charge >= 1
end

local spin_active
do
    local enemies = { tick = -1000, alive = true }

    -- Dormant dusmanlar da sayilir; gorunmuyorlar diye spin'e gecmek tehlikeli.
    local function enemies_alive()
        local now = globals.tickcount
        if now >= enemies.tick and now - enemies.tick < 16 then
            return enemies.alive
        end
        enemies.tick = now
        local ok, list = pcall(entity.get_players, true, true)
        if not ok or type(list) ~= "table" then
            enemies.alive = true
            return true
        end
        enemies.alive = false
        for _, player in ipairs(list) do
            if player:is_alive() then
                enemies.alive = true
                break
            end
        end
        return enemies.alive
    end

    spin_active = function()
        if not menu.spin:get() then
            return false
        end
        if menu.spin_warmup:get() then
            local ok, rules = pcall(entity.get_game_rules)
            if ok and rules ~= nil and rules.m_bWarmupPeriod == true then
                return true
            end
        end
        return menu.spin_enemies:get() and not enemies_alive()
    end
end

local legit_use_active
do
    local OBJECTIVE_RANGE = 100

    -- CT olarak kurulu bombanin ya da bir rehinenin yanindaysak E'ye basili tutmak
    -- gercekten gerekli (defuse / rehine tasima), o zaman use'a karisilmaz.
    local function near_objective(lp)
        if lp.m_iTeamNum ~= 3 then
            return false
        end
        local mine = origin_of(lp)
        if mine == nil then
            return false
        end
        for _, class in ipairs({ "CPlantedC4", "CHostage" }) do
            local ok, list = pcall(entity.get_entities, class)
            if ok and type(list) == "table" then
                for _, ent in ipairs(list) do
                    local pos = origin_of(ent)
                    if pos ~= nil then
                        local dx, dy, dz = mine.x - pos.x, mine.y - pos.y, mine.z - pos.z
                        if dx * dx + dy * dy + dz * dz < OBJECTIVE_RANGE * OBJECTIVE_RANGE then
                            return true
                        end
                    end
                end
            end
        end
        return false
    end

    local use = { start = nil }

    -- E'ye basili tutarken AA calismaya devam etsin. Ilk tick'ler oyuna gecer ki
    -- kapi acma / silah alma bozulmasin; defuse ve rehine tasimaya hic karisilmaz.
    legit_use_active = function(lp, cmd)
        if not menu.legit_use:get() or cmd.in_use ~= true or near_objective(lp) then
            use.start = nil
            return false
        end
        if use.start == nil or use.start > globals.tickcount then
            use.start = globals.tickcount
        end
        if globals.tickcount - use.start >= 2 then
            pcall(function() cmd.in_use = false end)
        end
        return true
    end
end

-------------------------------------------------------------------------------
-- Anti-aim
-------------------------------------------------------------------------------

local MANUAL_YAW = { Left = -90, Right = 90, Forward = 180 }
local OPTIONS_OVERLAP, OPTIONS_NONE = { "Avoid Overlap" }, {}

-- Anti-brute fazlari: her isabet / yakin kacan mermide bir sonrakine gecer.
-- shift kafayi birkac derece kaydirir; ogrenilmis aciya atilan mermi iska gecer.
-- Desync dusurulmez: resolver'lar iskadan sonra karsi tarafi, sonra "dusuk desync"i
-- dener. Eskiden faz 2 desync'i %60'a indiriyordu ve oyun loglarinda bu fazda
-- kafa isabeti tekrar tekrar geldi.
-- Faz 4: desync tarafi her flip'te rastgele, yaw'dan bagimsiz. Jitter'da yaw sirayla
-- donmeye devam eder ama kafanin hangi tarafta oldugunu artik ele vermez.
-- Faz 5 (v5.6): sabit desync, tarafi Neverlose'un body freestanding'i ("Peek Fake") secer:
-- gercek kafa duvar tarafinda kalir, dusmana once sahte taraf gorunur. Yaw jitter'i devam
-- eder (desync'ten bagimsiz). Hangi fazin en az vuruldugunu sistem senin maclarinda olcer
-- ve verisi olmayan dusmanlara onu uygular (bkz. brute_default).
local BRUTE_PHASES = {
    { invert = true,  scale = 1.0,  shift = 0 },
    { invert = false, scale = 1.0,  shift = 15 },
    { invert = true,  scale = 0.85, shift = -15 },
    { invert = false, scale = 1.0,  shift = 0, random = true },
    { invert = false, scale = 1.0,  shift = 0, freestand = true },
}
local BRUTE_RADIUS = 40
-- Ayni dusmanin bu kadar saniye icindeki ikinci mermisi (DT cift atisi, pompali
-- sacmalari, wallbang) ayni atis sayilir; AA'yi o atislar arasinda degistiremeyiz.
local BRUTE_DEBOUNCE = 0.1
-- Kafanin yanindan gecen mermiden sonra bu kadar icinde hasar gelmezse iska sayilir.
local MISS_WINDOW = 0.15

-- Her dusmanin resolver'i ayri ogrenir, o yuzden faz dusman basina tutulur ve
-- AA'nin baktigi tehdidin fazi uygulanir. Tehdit yoksa en son ates edeninki.
--
-- enemies[key] = {
--   stage, time  : iskalarla ilerleyen aktif faz; reset suresi dolunca biter
--   base         : kalici faz. Dusman kafani hangi fazda vurduysa bir sonrakine
--                  gecer ve round / olum sonrasi da kalir. Neverlose resolver'i bir
--                  oyuncuyu round'lar boyunca hatirlar; her round ayni AA'yi
--                  gostermek ona cozdugu aciyi yeniden vermek olur.
--   last, shot_stage : son mermi zamani ve o mermi geldiginde uygulanan faz
--   name, seen   : son gorulen isim ve zaman (log ve bellek siniri icin)
-- }
-- Anahtar oyuncunun Steam ID'sidir (player_id). HvH sunucularinda oyuncular harita
-- degisince kalir ama slot numaralari degisir; ogrenilen faz harita degisince de korunur.
-- hurt[userid] = son hasar zamani
-- phases[grup][faz] = { shots, hits }: butun dusmanlarin o faz uygulanirken kafana attigi
-- mermiler (kafadan isabet + kafanin yanindan iska) ve kafadan isabetler. Verisi olmayan
-- dusmanlar en az vurulan fazla baslar (bkz. brute_default). default[grup] = secilen faz.
-- Grup senin hareketin: yerde durma, hareket, peek ve hava farkli AA ayarlariyla oynanir;
-- birinde en iyi faz digerinde en iyi olmayabilir. Peek ayri: v4.6 loglarinda kafa
-- isabetlerinin hepsi Peek'teydi, yurumeyle ayni istatistigi paylasmasin.
-- migrate[grup] = eski kayitta o grup yoksa verisinin alinacagi grup (v4.6'da peek "move").
local brute = { enemies = {}, recent = nil, hurt = {}, phases = {}, default = {},
    groups = { "still", "move", "peek", "air" },
    group_of = { Moving = "move", ["Slow walk"] = "move", ["Crouch move"] = "move", Peek = "peek",
        Air = "air", ["Air crouch"] = "air" },
    group_label = { still = "yerde", move = "hareket", peek = "peek", air = "hava" },
    migrate = { peek = "move" } }

brute.reset_phases = function()
    for _, group in ipairs(brute.groups) do
        brute.phases[group], brute.default[group] = {}, 0
        for phase = 0, #BRUTE_PHASES do
            brute.phases[group][phase] = { shots = 0, hits = 0 }
        end
    end
end
brute.reset_phases()

-- Hareket durumunun faz grubu; bilinmeyen durumlar (Standing, Crouching, Fake duck...) "still".
brute.group_for = function(state)
    return brute.group_of[state] or "still"
end
-- Hatirlanan en fazla oyuncu; dolunca en uzun suredir gorulmeyen unutulur.
local MEMORY_LIMIT = 64
-- Ogrenilenler oyun kapaninca da kalsin diye Neverlose'un db deposuna yazilir (asagida
-- persist.save / persist.load). dirty = son yazmadan beri yeni bir sey ogrenildi.
-- Anahtar eski adla (ANT-A-M) kaldi: v5.x'te ogrenilenler V1.0'a aynen gecer.
local persist = { key = "ant_a_m_memory", every = 60, dirty = false, saved = -huge }

local function entity_key(ent)
    local ok, index = pcall(ent.get_index, ent)
    if ok and type(index) == "number" then
        return index
    end
    return nil
end

local function player_name(ent)
    local ok, name = pcall(ent.get_name, ent)
    if ok and type(name) == "string" then
        return name
    end
    return "?"
end

-- Kendi kendine ogrenen AA: kafana gelen mermilerde en az isabet alan faz. Oran
-- (isabet + 2) / (mermi + 4): hic denenmemis faz 0.5 sayilir, yani cok vurulan bir faz
-- denenmemis olana yer birakir. Tek bir isabet secimi degistirmesin diye yeni faz ancak
-- simdiki varsayilandan 0.1 daha iyiyse secilir; esitlikte kucuk faz kazanir.
brute.rate = function(stat)
    return (stat.hits + 2) / (stat.shots + 4)
end

local function brute_default(group)
    local stats, current_default = brute.phases[group], brute.default[group]
    local best, best_rate = 0, huge
    for phase = 0, #BRUTE_PHASES do
        local rate = brute.rate(stats[phase])
        if rate < best_rate - 1e-9 then
            best, best_rate = phase, rate
        end
    end
    if best ~= current_default and best_rate < brute.rate(stats[current_default]) - 0.1 then
        return best
    end
    return current_default
end

-- Sayilar 40'i gecince yarilanir: eski oyunlar degil son karsilasmalar agir basar.
brute.count = function(stat, hit)
    stat.shots = stat.shots + 1
    if hit then
        stat.hits = stat.hits + 1
    end
    if stat.shots > 40 then
        stat.shots, stat.hits = stat.shots / 2, stat.hits / 2
    end
    persist.dirty = true
end

-- Kafana gelen bir mermiyi, mermi geldiginde uygulanan faza ve hareket grubuna yazar.
local function record_phase(group, phase, hit)
    local stats = brute.phases[group]
    if stats == nil or stats[phase] == nil then
        return
    end
    brute.count(stats[phase], hit)
    local best = brute_default(group)
    if best ~= brute.default[group] then
        brute.default[group] = best
        if menu.hit_log:get() then
            local chosen = stats[best]
            print(("[%s] AA (%s): en az vurulan faz %d (%d/%d kafa isabeti) -> verisi olmayan dusmanlara faz %d"):format(
                SCRIPT, brute.group_label[group], best, floor(chosen.hits + 0.5), floor(chosen.shots + 0.5), best))
        end
    end
end

local function brute_entry_stage(entry, group)
    if entry == nil then
        return brute.default[group]
    end
    local now = globals.realtime
    if entry.stage > 0 and now >= entry.time and now - entry.time <= menu.brute_reset:get() then
        return entry.stage
    end
    -- Seni kafadan vurmus dusmanin kendi fazi var; yoksa en az vurulan faz.
    if entry.learned then
        return entry.base
    end
    return brute.default[group]
end

-- Scout / AWP / R8 (tek atisli silahlar).
local SNIPERS = { CWeaponSSG08 = true, CWeaponAWP = true, Revolver = true }

-- Sniper'da hangi exploit daha az kafadan vurduruyor? Hide shots atis anindaki aciyi gizler
-- (eski loglarda DT ile atistan hemen sonra vuruluyordun); Double tap'te Smart defensive,
-- Neverlose'un On Peek'i ve hidden acilar var (yeni loglarda HS ile peek'te ve havada
-- kafadan vuruldun). Sniper elindeyken kafana gelen mermiler (kafadan isabet ya da kafanin
-- yanindan iska) o an acik olan exploit'e yazilir; fazlarla ayni oran ve 0.1 esik. Once HS.
-- Secili exploit en az min_shots mermi gormeden degismez: loglarda iki HS isabetinden sonra
-- DT'ye gecildi ve scout'la atistan 0.15 sn sonra "DT %0, sarj bekle" iken kafadan vuruldun
-- (bolt-action'da DT her atistan sonra bosalir; eski loglardaki sorun).
local sniper = { stats = { hs = { shots = 0, hits = 0 }, dt = { shots = 0, hits = 0 } }, choice = "hs", min_shots = 4 }

-- Sniper elindeyken acik olan exploit: "hs", "dt" ya da nil (sniper yok, fake duck...).
sniper.mode = function(class)
    if not SNIPERS[class] or effective("fakeduck") then
        return nil
    end
    if effective("doubletap") then
        return "dt"
    end
    if effective("hideshots") then
        return "hs"
    end
    return nil
end

sniper.decide = function()
    if sniper.stats[sniper.choice].shots < sniper.min_shots then
        return sniper.choice
    end
    local hs, dt = brute.rate(sniper.stats.hs), brute.rate(sniper.stats.dt)
    if sniper.choice == "hs" and dt < hs - 0.1 then
        return "dt"
    elseif sniper.choice == "dt" and hs < dt - 0.1 then
        return "hs"
    end
    return sniper.choice
end

sniper.record = function(mode, hit)
    local stat = mode ~= nil and sniper.stats[mode] or nil
    if stat == nil then
        return
    end
    brute.count(stat, hit)
    local choice = sniper.decide()
    if choice ~= sniper.choice then
        sniper.choice = choice
        if menu.hit_log:get() then
            local hs, dt = sniper.stats.hs, sniper.stats.dt
            print(("[%s] sniper exploit: Hide shots %d/%d, Double tap %d/%d kafa isabeti -> %s"):format(SCRIPT,
                floor(hs.hits + 0.5), floor(hs.shots + 0.5), floor(dt.hits + 0.5), floor(dt.shots + 0.5),
                choice == "hs" and "Hide shots" or "Double tap"))
        end
    end
end

-- Kalici oyuncu kimligi: Steam ID. Bot ya da okunamayan Steam ID'de isim, o da yoksa slot.
local function player_id(ent)
    local ok, xuid = pcall(function() return ent:get_xuid() end)
    if ok and type(xuid) == "string" and #xuid > 4 and xuid ~= "0" and not xuid:find("BOT", 1, true) then
        return "s:" .. xuid
    end
    local name = player_name(ent)
    if name ~= "?" then
        return "n:" .. name
    end
    local index = entity_key(ent)
    return index ~= nil and ("i:" .. index) or nil
end

-- map[id] kaydini getirir ya da olusturur; bellek dolunca en eski kaydi siler.
local function memory_entry(map, id, ent, make)
    local entry = map[id]
    if entry == nil then
        local count, oldest_id, oldest = 0, nil, huge
        for key, value in pairs(map) do
            count = count + 1
            if value.seen < oldest then
                oldest_id, oldest = key, value.seen
            end
        end
        if count >= MEMORY_LIMIT and oldest_id ~= nil then
            map[oldest_id] = nil
        end
        entry = make()
        map[id] = entry
    end
    entry.name, entry.seen = player_name(ent), globals.realtime
    return entry
end

local function brute_entry(ent, fallback_key)
    local key = player_id(ent) or fallback_key
    return key, memory_entry(brute.enemies, key, ent, function()
        return { stage = 0, time = 0, base = 0, learned = false, last = nil, shot_stage = nil }
    end)
end

-- Faz, kafani goren dusmana gore secilir: tehdit gormuyor (ve birazdan da gormeyecek)
-- ama baska bir dusman goruyorsa desync'ini o cozmeye calisiyor, onun fazi uygulanir.
-- Kimse gormuyorsa tehdidinki.
local function brute_target()
    return recent_shooter() or seeing_flanker() or current_threat()
end

local function threat_stage(group)
    local threat = brute_target()
    local key = threat ~= nil and player_id(threat) or nil
    if key == nil then
        return brute_entry_stage(brute.recent ~= nil and brute.enemies[brute.recent] or nil, group)
    end
    local entry = brute.enemies[key]
    if entry ~= nil then
        entry.seen = globals.realtime
    end
    return brute_entry_stage(entry, group)
end

-------------------------------------------------------------------------------
-- Adaptive resolver
-------------------------------------------------------------------------------

-- Dusmanin acisi Neverlose'un yerine konmaz. Acik Lua API'si sadece govde donus
-- parametresini (m_flPoseParameter[11]) yazabilir; modelin ayak yonu Neverlose'un kendi
-- cozumunden gelir ve ikisi tutmayinca hitbox'lar yeni bir yanlis aciya kayar. Ayak
-- yonunu yazmak icin FFI ile oyun belleginde sabit ofsetlere yazmak gerekir: bu tek bir
-- client.dll surumunde gecerlidir ve Neverlose'un atis kayitlarina etkisi Lua'dan
-- dogrulanamaz. Bu yuzden acilari Neverlose cozer; bu katman sonuclara bakar.
--
-- aim_ack her atisin sonucunu verir. "correction" = mermi isabet edecekti ama resolver
-- acida yanildi. Bir dusmana karsi, ATES ANINDAKI hareket durumunda (Standing / Moving /
-- Crouch / Air) son RESOLVER_WINDOW sonuctaki correction iskasi sayisi seviyedir:
--   1 -> Safe points "Prefer": guvenli nokta varsa ona ates eder
--   2 -> Safe points "Force": sadece desync hangi taraftaysa da isabet eden noktalara
-- AA lua'lari her durumda farkli ayar kullanir; havada cozulemeyen bir dusman yerde
-- cozulebilir. Dusmanin o anki durumunda hic sonuc yoksa, butun durumlardaki son
-- sonuclar on bilgi olur ama en fazla "Prefer".
-- Isabetler pencereye girip eski iskalari itince seviye kendiliginden duser. Spread,
-- tahmin hatasi gibi resolver disi iskalar sayilmaz; kafaya nisan alinip baska yere
-- gelen isabet de isabet sayilmaz. Seviye round'lar, haritalar ve oyun oturumlari
-- arasi kalir (Steam ID, db). Seviye 2'de DT'li silahlarda govde de tercih edilir
-- (Smart body aim).
local RESOLVER_WINDOW = 4
local SAFE_POINT_LEVELS = { [0] = "Default", "Prefer", "Force" }
local SAFE_POINT_RANK = { Default = 0, Prefer = 1, Force = 2 }
-- Aimbot az once birine ates ettiyse siradaki atislar da buyuk ihtimalle ona; bu kadar
-- saniye o hedefin seviyesi kullanilir, sonra AA'nin baktigi tehdide donulur.
local AIM_TARGET_HOLD = 1.5
-- Ates edilip sonucu gelmeyen atislarin kaydi bu kadar saniye tutulur.
local SHOT_MEMORY = 5
-- Force safe point'te guvenli nokta yoksa aimbot hic ates etmez ve seviye de hic
-- dusmez (sonuc gelmez). Dusman seni goruyorken (karsilikli gorus) FORCE_STALL sn
-- boyunca ona ates edilmediyse "Prefer"e inilir; o durumun bir sonraki atis sonucu
-- seviyeyi yeniden belirler. Karsilikli gorusteyken yarim saniye ates etmemek bile cok.
local FORCE_STALL = 0.5

-- players[id] = { name, seen, results = { "c" | "h", ... }, states = { [durum] = { ... } } }
-- id = Steam ID (player_id); harita degisince de korunur.
-- shots[id] = { state, time }: ates anindaki dusman durumu
-- prior_logged[id] = jitter on bilgisi bu dusman icin konsola yazildi
-- jittery[id] = dusmanin AA'sinin en son jitter'li goruldugu zaman (sn)
local resolver = { players = {}, shots = {}, aim_target = nil, aim_time = -1000, user_safe = nil, user_body = nil,
    stall = { key = nil, state = nil, visible = 0, last = nil, relaxed = false }, prior_logged = {}, jittery = {},
    body_stall = { key = nil, visible = 0, last = nil, relaxed = false },
    -- Kendi lag'imiz sirasinda (DEF = zorlanan DT defensive'i, LC = Hide shots'in Break LC'si,
    -- TP = havada teleport'tan sonraki tp_window sn) atilip sunucuda gecmeyen ("unregistered shot",
    -- "damage rejection") atislarin zamanlari; ayni turden ikisi unreg_window sn icinde olursa o lag
    -- unreg_pause sn durur (pause). TP (V1.0): loglarda 3 teleport'tan hemen sonraki scout atisi
    -- "unregistered shot" oldu.
    unreg = { DEF = {}, LC = {}, TP = {} }, unreg_window = 10, unreg_pause = 10, tp_window = 0.3,
    pause = { DEF = -1000, LC = -1000, TP = -1000 },
    lag_names = { DEF = { "defensive", "zorlanan defensive" }, LC = { "Break LC", "Hide shots Break LC" },
        TP = { "teleport", "teleport sonrasi" } } }

-- Bu lag su an durdurulmus mu (bkz. aim_ack).
resolver.paused = function(kind)
    local stop, real = resolver.pause[kind], globals.realtime
    return stop ~= nil and real >= stop - resolver.unreg_pause and real < stop
end

local function prop(ent, name)
    local ok, value = pcall(function() return ent[name] end)
    if ok then
        return value
    end
    return nil
end

-- Dusman takibi: her tick canli, dormant olmayan dusmanlarin simulasyon zamani, konumu ve
-- sunucudan gelen bakis yonu izlenir:
--  defensive: simulasyon zamani gordugumuz en yuksek degerin gerisine dustu (tickbase
--             kaydirma: defensive / hidden AA). O anki kayit dusmanin gercek acisi degil.
--  lc: iki guncelleme arasinda 64 birimden fazla yer degistirdi (lag compensation kirildi,
--      eski kayitlara backtrack gecersiz).
--  jitter: son `samples` gercek (defensive olmayan) guncelleme arasindaki ortalama yaw degisimi
--          (derece); jitter ya da spin AA. En az 4 guncellemeden sonra hesaplanir.
-- Bayraklar `hold` tick gecerli kalir: atis sonucu ~0.05-0.3 sn sonra gelir.
-- jitter_prior: bu kadar jitter'li ve o durumda hic sonucu olmayan dusmana ilk atistan
-- "Prefer" (iska beklenmez). Karar jitter_memory sn hatirlanir: loglarda ayni dusmanin
-- ortalamasi 21 ile 48 arasinda gidip geliyordu ve on bilgi acilip kapaniyordu.
--  fakeduck: yerde, egilme miktari yarim (fd_low..fd_high) ve paketler bogulu (en az fd_choke
--            tick) iki guncelleme ust uste: fake duck (bizim de kullandigimiz numara). Kafa
--            yuksekligi kayittan kayda degisir; resolver ayri durum olarak ogrenir, fd_hold tick.
--  defensive_now: su anki kayit gordugumuz en yeni kayittan eski (defensive suruyor).
local enemy_watch = { list = {}, hold = 16, samples = 6, jitter_prior = 35, jitter_memory = 60,
    fd_low = 0.05, fd_high = 0.95, fd_choke = 6, fd_hold = 32 }
do
    local function eye_yaw(ent)
        local angles = prop(ent, "m_angEyeAngles")
        if angles == nil then
            return nil
        end
        local ok, yaw = pcall(function() return angles.y end)
        if ok and type(yaw) == "number" then
            return yaw
        end
        ok, yaw = pcall(function() return angles[1] end)
        if ok and type(yaw) == "number" then
            return yaw
        end
        return nil
    end

    local function fresh(sim, enemy)
        return { sim = sim, max_sim = sim, origin = origin_of(enemy), yaw = eye_yaw(enemy), deltas = {},
            def_tick = -1000, lc_tick = -1000, fd_tick = -1000, fd_count = 0 }
    end

    local function tick_interval()
        local ok, value = pcall(function() return globals.tickinterval end)
        return ok and type(value) == "number" and value > 0 and value or 1 / 64
    end

    -- Bu guncelleme fake duck gibi mi: yerde, egilme yarim, paketler bogulu.
    local function ducking_fake(enemy, choked)
        local flags, duck = prop(enemy, "m_fFlags"), prop(enemy, "m_flDuckAmount")
        return type(flags) == "number" and bit.band(flags, 1) ~= 0 and type(duck) == "number"
            and duck > enemy_watch.fd_low and duck < enemy_watch.fd_high and choked >= enemy_watch.fd_choke
    end

    enemy_watch.update = function()
        local now = globals.tickcount
        local present = {}
        local ok, list = pcall(entity.get_players, true)
        if ok and type(list) == "table" then
            for _, enemy in ipairs(list) do
                local index = index_of(enemy)
                local ok_alive, alive = pcall(function() return enemy:is_alive() end)
                local sim = prop(enemy, "m_flSimulationTime")
                if index ~= nil and ok_alive and alive and not dormant(enemy) and type(sim) == "number" then
                    present[index] = true
                    local t = enemy_watch.list[index]
                    -- Ilk gorus, dormant'tan donus ya da yeniden dogus: yeni kayit.
                    if t == nil or abs(sim - t.max_sim) > 1 then
                        enemy_watch.list[index] = fresh(sim, enemy)
                    elseif sim ~= t.sim then
                        local fake = sim < t.max_sim
                        if fake then
                            t.def_tick = now
                        else
                            t.max_sim = sim
                        end
                        if ducking_fake(enemy, (sim - t.sim) / tick_interval() - 0.5) then
                            t.fd_count = t.fd_count + 1
                            if t.fd_count >= 2 then
                                t.fd_tick = now
                            end
                        else
                            t.fd_count = 0
                        end
                        local origin = origin_of(enemy)
                        if origin ~= nil and t.origin ~= nil then
                            local dx, dy, dz = origin.x - t.origin.x, origin.y - t.origin.y, origin.z - t.origin.z
                            if dx * dx + dy * dy + dz * dz > 64 * 64 then
                                t.lc_tick = now
                            end
                        end
                        -- Jitter sadece gercek kayitlardan: defensive kaydindaki aci hidden yaw'dir
                        -- (spin / random; bizim de kullandigimiz numara) ve jitter on bilgisini
                        -- bozuyordu. Gercek kayit son gercek kayitla karsilastirilir.
                        local yaw = eye_yaw(enemy)
                        if not fake then
                            if yaw ~= nil and t.yaw ~= nil then
                                t.deltas[#t.deltas + 1] = abs((yaw - t.yaw + 180) % 360 - 180)
                                if #t.deltas > enemy_watch.samples then
                                    table.remove(t.deltas, 1)
                                end
                            end
                            t.yaw = yaw
                        end
                        t.sim, t.origin = sim, origin
                    end
                end
            end
        end
        for index in pairs(enemy_watch.list) do
            if not present[index] then
                enemy_watch.list[index] = nil
            end
        end
    end

    -- { defensive, lc, jitter } ya da hic veri yoksa nil.
    enemy_watch.profile = function(ent)
        local index = ent ~= nil and index_of(ent) or nil
        local t = index ~= nil and enemy_watch.list[index] or nil
        if t == nil then
            return nil
        end
        local now = globals.tickcount
        local jitter = nil
        if #t.deltas >= 4 then
            local sum = 0
            for _, d in ipairs(t.deltas) do
                sum = sum + d
            end
            jitter = sum / #t.deltas
        end
        return {
            defensive = now >= t.def_tick and now - t.def_tick <= enemy_watch.hold,
            defensive_now = t.sim < t.max_sim,
            lc = now >= t.lc_tick and now - t.lc_tick <= enemy_watch.hold,
            fakeduck = now >= t.fd_tick and now - t.fd_tick <= enemy_watch.fd_hold,
            jitter = jitter,
        }
    end
end

-- Okunamayan alanlar "Standing" sayilir (en sik durum, en az varsayim). Fake duck yapan dusman
-- ayri durum ("Fakeduck"): egilme miktari surekli degistigi icin Crouch / Standing arasinda
-- gidip gelip iki durumun verisini de bozuyordu.
local function enemy_state(ent)
    local flags = prop(ent, "m_fFlags")
    if type(flags) == "number" and bit.band(flags, 1) == 0 then
        return "Air"
    end
    local profile = enemy_watch.profile(ent)
    if profile ~= nil and profile.fakeduck then
        return "Fakeduck"
    end
    local duck = prop(ent, "m_flDuckAmount")
    if type(duck) == "number" and duck > 0.6 then
        return "Crouch"
    end
    local velocity = prop(ent, "m_vecVelocity")
    local ok, speed = pcall(function() return velocity:length2d() end)
    if ok and type(speed) == "number" and speed > 6 then
        return "Moving"
    end
    return "Standing"
end

-- Log icin saldiran: hareket durumu, AA'nin baktigi tehdit mi ve bizim izlerimize gore
-- kafani ne kadar suredir goruyordu. "gormedi" = izler gormedi (duvarin arkasindan, ya
-- da diger dusmanlar sirayla kontrol edilirken sira ona gelmeden vurdu).
local attacker_info
do
    local function tick_interval()
        local ok, value = pcall(function() return globals.tickinterval end)
        if ok and type(value) == "number" and value > 0 then
            return value
        end
        return 1 / 64
    end

    attacker_info = function(ent)
        local parts = { enemy_state(ent) }
        -- AA'nin o an dondugu dusman (face_target): Neverlose'un tehdidi ya da script'in sectigi.
        local index = index_of(ent)
        if exposure.facing == nil then
            parts[#parts + 1] = "AA hedefi yok"
        elseif index ~= nil and exposure.facing == index then
            parts[#parts + 1] = "AA hedefi"
        else
            parts[#parts + 1] = "AA hedefi degil"
        end
        if exposure.available then
            local s = index ~= nil and exposure.sight[index] or nil
            local now = globals.tickcount
            if s ~= nil and now >= s.last and now - s.last <= SIGHT.recent then
                parts[#parts + 1] = ("gordu %.2fs"):format((s.last - s.first) * tick_interval())
            else
                parts[#parts + 1] = "gormedi"
            end
        end
        return table.concat(parts, ", ")
    end
end

local function resolver_entry(ent)
    local key = player_id(ent)
    if key == nil then
        return nil
    end
    return memory_entry(resolver.players, key, ent, function() return { results = {}, states = {} } end)
end

local function window_push(list, result)
    list[#list + 1] = result
    if #list > RESOLVER_WINDOW then
        table.remove(list, 1)
    end
end

local function window_misses(list)
    local misses = 0
    for _, r in ipairs(list) do
        if r == "c" then
            misses = misses + 1
        end
    end
    return misses
end

local function entry_level(entry, state)
    local list = entry.states[state]
    if list ~= nil and #list > 0 then
        return min(window_misses(list), #SAFE_POINT_LEVELS)
    end
    return min(window_misses(entry.results), 1)
end

-- Aimbot'un hedefi: az once ates ettigi dusman, yoksa kafani goren dusman (ayni gorus
-- hattindan sen de onu vurabilirsin; anti-brute ile ayni secim), yoksa tehdit.
local function resolver_target()
    local target = resolver.aim_target
    local since = globals.realtime - resolver.aim_time
    if target ~= nil and since >= 0 and since <= AIM_TARGET_HOLD then
        local ok, alive = pcall(target.is_alive, target)
        if ok and alive then
            return target
        end
    end
    return brute_target()
end

-- Bizden hedefe uzaklik (birim); okunamazsa nil. Sadece resolver paneli icin.
resolver.distance = function(target)
    local lp = entity.get_local_player()
    local mine, theirs = lp ~= nil and origin_of(lp) or nil, origin_of(target)
    if mine == nil or theirs == nil then
        return nil
    end
    local dx, dy, dz = theirs.x - mine.x, theirs.y - mine.y, theirs.z - mine.z
    return sqrt(dx * dx + dy * dy + dz * dz)
end

-- Seviye, anahtar, durum, kayit ve seviyenin jitter on bilgisinden gelip gelmedigi.
-- Dusmanin o durumda hic sonucu yoksa ve AA'si jitter'liyse (ortalama yaw degisimi
-- jitter_prior derece ve ustu) ilk atistan "Prefer": Neverlose'un resolver'i jitter'da en
-- cok yanilir ve iska beklemek bir atis kaybettirir. O durumda ilk sonuc gelince veri gecer.
-- V1.0: v5.2'nin kurali. v5.5-v5.6'da fake duck ve uzak (1500+) dusmana da veri olmadan
-- "Prefer", uzakta tek iskada "Force" veriliyordu: Force safe point bulunamayinca atis hic
-- gelmiyordu ve resolver her surumde daha kotu hissettirdi; kaldirildi.
local function resolver_level(target)
    if target == nil then
        return 0
    end
    local key = player_id(target)
    local entry = key ~= nil and resolver.players[key] or nil
    local state = enemy_state(target)
    local level, data = 0, false
    if entry ~= nil then
        entry.seen = globals.realtime
        level = entry_level(entry, state)
        local list = entry.states[state]
        data = list ~= nil and #list > 0
    end
    local prior = false
    local profile = enemy_watch.profile(target)
    local now = globals.realtime
    if key ~= nil and profile ~= nil and profile.jitter ~= nil and profile.jitter >= enemy_watch.jitter_prior then
        resolver.jittery[key] = now
    end
    local seen = key ~= nil and resolver.jittery[key] or nil
    local jittery = seen ~= nil and now >= seen and now - seen <= enemy_watch.jitter_memory
    if not data and level < 1 and jittery then
        level, prior = 1, true
        if key ~= nil and not resolver.prior_logged[key] and menu.resolver_log:get() then
            resolver.prior_logged[key] = true
            local amount = (profile ~= nil and profile.jitter ~= nil) and (" %d%s"):format(floor(profile.jitter + 0.5), DEG) or ""
            print(("[%s] resolver: %s jitter%s -> safe points Prefer (veri yok, on bilgi)"):format(
                SCRIPT, player_name(target), amount))
        end
    end
    return level, key, state, entry, prior
end

local function reset_stall(key, state)
    local stall = resolver.stall
    stall.key, stall.state, stall.visible, stall.last, stall.relaxed = key, state, 0, nil, false
end

-- Force'un ates engelleyip engellemedigini izler; takildiysa 1 dondurur.
local function stall_level(level, key, state, entry)
    local stall = resolver.stall
    if level < 2 then
        if stall.key ~= nil then
            reset_stall(nil, nil)
        end
        return level
    end
    if stall.key ~= key or stall.state ~= state then
        reset_stall(key, state)
    end
    local now = globals.realtime
    if stall.last ~= nil and exposure.now and not stall.relaxed then
        stall.visible = stall.visible + max(0, min(0.1, now - stall.last))
        if stall.visible >= FORCE_STALL then
            stall.relaxed = true
            if menu.resolver_log:get() then
                print(("[%s] resolver: %s %s safe point bulunamadi, ates yok -> safe points Prefer"):format(
                    SCRIPT, entry.name, state))
            end
        end
    end
    stall.last = now
    return stall.relaxed and 1 or level
end

local NON_BULLET_DAMAGE = {
    inferno = true, molotov = true, incgrenade = true, hegrenade = true,
    decoy = true, flashbang = true, smokegrenade = true,
}

local HITGROUPS = {
    [0] = "generic", [1] = "head", [2] = "chest", [3] = "stomach", [4] = "left arm",
    [5] = "right arm", [6] = "left leg", [7] = "right leg", [8] = "neck", [10] = "gear",
}

local function stat_for(state)
    local entry = stats[state]
    if entry == nil then
        entry = { hits = 0, head = 0, misses = 0, dt_ticks = 0, dt_full = 0, def_ticks = 0, def_on = 0 }
        stats[state] = entry
    end
    return entry
end

-- Suresi dolan "kafanin yanindan gecti" kayitlari hasar gelmediyse iska sayilir.
local function process_pending_misses()
    local now = globals.realtime
    for i = #pending_misses, 1, -1 do
        local miss = pending_misses[i]
        if now < miss.time or now - miss.time > MISS_WINDOW then
            table.remove(pending_misses, i)
            if now >= miss.time then
                local entry = stat_for(miss.state)
                entry.misses = entry.misses + 1
                record_phase(miss.group, miss.applied, false)
                sniper.record(miss.sniper, false)
                if menu.hit_log:get() then
                    print(("[%s] iska: %s | faz %d | %s | %s | %s | %s (%s)"):format(
                        SCRIPT, miss.state, miss.stage, miss.aa, miss.exploit, miss.weapon, miss.name, miss.attacker))
                end
            end
        end
    end
end

-- Rastgele degerler -1..1 (limit icin 0..1) olarak tutulur ve o anki durumun
-- araligiyla carpilir; boylece randomize 0 ise etkisi de hemen 0 olur.
local flip = { side = false, packets = 0, extra = 0, step = 0, yaw_n = 0, mod_n = 0, limit_n = 0, rand_side = false }

local current = { state = "Global", side = false, limit = 60, freestand = false, defensive = false, forced = false, lc = false,
    brute = 0, phase_group = "still", resolver = 0, res_state = nil, res_prior = false, weapon = nil, lethal = false,
    head_only = false }

-- Istatistigin yazilacagi grup; AA'si hareket durumundan farkli olan ozel durumlarda nil
-- (yazilmaz). v4.8 loglarinda Safe head'deki (yaw 0, desync 30) kafa isabetleri "yerde"
-- grubuna yazildi ve normal durusun varsayilan fazini degistirdi.
brute.unlearned = { ["Safe head"] = true, Manual = true, ["Fake duck"] = true }
brute.stat_group = function()
    if brute.unlearned[current.state] then
        return nil
    end
    return current.phase_group
end

-- Senin kendi safe point ayarin hic dusurulmez: zaten "Force" ise dokunulmaz.
-- Hedefi ve takilma korumasindan onceki seviyeyi dondurur (body aim icin).
local function apply_resolver()
    if overridden.safe_points == nil then
        resolver.user_safe = get("safe_points")
    end
    local target = resolver_target()
    local level, raw, state, prior = 0, 0, nil, false
    if menu.resolver:get() then
        local key, entry
        raw, key, state, entry, prior = resolver_level(target)
        level = stall_level(raw, key, state, entry)
    end
    current.resolver, current.res_state, current.res_prior = level, state, prior == true
    -- V1.0: kendi fake duck'inda zorla "Prefer" (v5.4) kaldirildi; seviye sadece dusmana gore.
    if level > (SAFE_POINT_RANK[resolver.user_safe] or 0) then
        override("safe_points", SAFE_POINT_LEVELS[level])
    else
        override("safe_points", nil)
    end
    return target, raw
end

-- V1.0: v5.5'teki "dusman defensive'deyken atisi beklet" (hitbox listesini bosaltma) kaldirildi.
-- Defensive'i surekli acik dusmanlarda her temasta ilk atisi ~0.2 sn geciktiriyordu (once ates
-- eden kazanir). Yerine: defensive kaydina giden iska resolver'a sayilmaz (bkz. aim_ack) ve
-- dusmanin jitter'i sadece gercek kayitlardan olculur (bkz. enemy_watch).

-- HvH silahlari: { hasar, zirh orani, menzil carpani, tek atis } (CS:GO silah dosyalari).
-- Zirhli govdeye can hasari = hasar * zirh orani / 2 (scout gogus 88 * 0.85 = 74.8, mide
-- x1.25 = 93.5: loglardaki 74 ve 92-93). Hasar her 500 birimde menzil carpaniyla azalir.
-- Gogus olcu alinir: mide de oldururse gogus oldurmeyebilir. Tek atis = DT ile ikinci
-- mermi yok (bolt-action, R8).
local apply_body_aim
do
    local WEAPONS = {
        CWeaponSSG08  = { 88, 1.7, 0.98, true },
        CWeaponAWP    = { 115, 1.95, 0.99, true },
        Revolver      = { 86, 1.864, 0.94, true },
        CWeaponSCAR20 = { 80, 1.65, 0.98, false },
        CWeaponG3SG1  = { 80, 1.65, 0.98, false },
        CDEagle       = { 63, 1.864, 0.81, false },
    }

    local function dt_ready()
        if not effective("doubletap") then
            return false
        end
        local charge = api.charge ~= nil and api.charge() or nil
        return type(charge) ~= "number" or charge >= 1
    end

    local function chest_damage(lp, target, info)
        local damage = info[1]
        local mine, theirs = origin_of(lp), origin_of(target)
        if mine ~= nil and theirs ~= nil then
            local dx, dy, dz = theirs.x - mine.x, theirs.y - mine.y, theirs.z - mine.z
            damage = damage * info[3] ^ (sqrt(dx * dx + dy * dy + dz * dz) / 500)
        end
        local armor = prop(target, "m_ArmorValue")
        if type(armor) ~= "number" or armor > 0 then
            damage = damage * info[2] / 2
        end
        return damage
    end

    -- "Force" govde ates engelleyebilir (sadece kafa gorunuyorsa hic ates edilmez). Dusman
    -- seni goruyorken FORCE_STALL sn boyunca o hedefe ates edilmediyse "Prefer"e inilir;
    -- o hedefe bir atis gelince yeniden "Force" denenir.
    local function body_stall(target)
        local stall = resolver.body_stall
        local key = player_id(target)
        if stall.key ~= key then
            stall.key, stall.visible, stall.last, stall.relaxed = key, 0, nil, false
        end
        local now = globals.realtime
        if stall.last ~= nil and (exposure.now or exposure.any) and not stall.relaxed then
            stall.visible = stall.visible + max(0, min(0.1, now - stall.last))
            if stall.visible >= FORCE_STALL then
                stall.relaxed = true
            end
        end
        stall.last = now
        return stall.relaxed and "Prefer" or "Force"
    end

    -- Body Aim karari, aimbot'un hedefine gore:
    --  1. Tek govde mermisi olduruyor -> "Force": dusmanin cani 31 iken "Prefer" ile
    --     Neverlose yine kafaya nisan alip resolver yuzunden iskaladi (loglar). Oldurecek
    --     bir govde atisi varken kafa daha kucuk ve resolver'a bagli.
    --  2. DT dolu ve iki govde mermisi olduruyor (oto, deagle) -> "Prefer".
    --  3. Tek atisli silah (scout / AWP / R8) ve govde oldurmuyor -> "Default": kafa acik
    --     kalir (oyun loglarinda 87-93 govde vuruslarindan sonra dusman hayatta kaldi).
    --  4. Resolver bu dusmana bu durumda iki kez yanildi (seviye 2) -> "Prefer": govde
    --     hitbox'lari desync'le kafa kadar kaymaz. Tek atisli silahlarda degil.
    -- Senin kendi "Force"un (baim tusu) hic degistirilmez.
    -- Scout / AWP / R8 ve "Head unless body kills": Min. Damage 101 (Neverlose'da 100 ustu "can +
    -- fazlasi", yani can + 1) ve Body Aim "Prefer". Ikisi de hedeften bagimsiz: aimbot hangi
    -- dusmana ates ederse etsin sadece oldurecek atis (tam canliya kafa, cani azsa govde).
    -- Eskiden tahmin edilen tek hedefe gore ayarlaniyordu; loglarda aimbot baska dusmana ates
    -- edince tam canli dusmana "BA Force | MD 31" ile 40'lik govde atisi yapildi.
    -- Kural sadece bir dusman kafani gorebiliyorken (ya da birazdan gorecekken) gecerli: seni
    -- geri vuramayacaksa uzaktan ince bir bosluktan gorunen kol / govdeye atis bedava hasardir
    -- ("uzakta ince yerlerden sikamiyor"). Iz yoksa her zaman gecerli.
    local HP_PLUS_ONE = 101

    -- Ezdigimiz bir ayarin senin tarafindaki degeri: o ayara bagli aktif bind (baim tusu gibi).
    -- Neverlose'un :get()'i ezilen degeri dondurebilir; bind listesi tusun kendisini verir.
    local function bind_value(name, fallback)
        local ok, binds = pcall(function() return ui.get_binds() end)
        if ok and type(binds) == "table" then
            for _, bind in ipairs(binds) do
                local ok_bind, ref, active, value = pcall(function() return bind.reference, bind.active, bind.value end)
                if ok_bind and ref ~= nil and ref == refs[name] and active == true and value ~= nil then
                    return value
                end
            end
        end
        return fallback
    end

    apply_body_aim = function(lp, class, target, level)
        if overridden.body_aim == nil then
            resolver.user_body = get("body_aim")
        else
            -- Biz ezerken baim tusuna basarsan (Force) fark edilir ve ezme birakilir.
            resolver.user_body = bind_value("body_aim", resolver.user_body)
        end
        local wanted, lethal = nil, false
        local exposed = not exposure.available or exposure.now or exposure.soon or exposure.any
        local sniper = menu.head_only:get() and WEAPONS[class] ~= nil and WEAPONS[class][4] and exposed
        if sniper and menu.smart_baim:get() then
            wanted = "Prefer"
            -- Gosterge icin: tahmin edilen hedefte govde olduruyor mu (BAIM / HEAD).
            local health = target ~= nil and prop(target, "m_iHealth") or nil
            lethal = type(health) == "number" and health > 0 and health <= chest_damage(lp, target, WEAPONS[class])
        elseif target ~= nil and menu.smart_baim:get() then
            local info = WEAPONS[class]
            local health = prop(target, "m_iHealth")
            if info ~= nil and type(health) == "number" and health > 0 then
                local chest = chest_damage(lp, target, info)
                if health <= chest then
                    wanted, lethal = body_stall(target), true
                elseif not info[4] and dt_ready() and health <= 2 * chest then
                    wanted = "Prefer"
                elseif info[4] then
                    wanted = "Default"
                end
            end
            local gun = class ~= nil and not MELEE[class] and class ~= "CC4" and not is_grenade(class)
            if wanted == nil and level >= 2 and gun and not (info ~= nil and info[4]) then
                wanted = "Prefer"
            end
            -- Hedef defensive'de (acilari gizli / spin: spin kafayi govdenin etrafinda dondurur, govde
            -- yerinde kalir; bekleme sinirina takilip yine de ates edilirse) ya da fake duck yapiyor
            -- (kafa yuksekligi kayittan kayda degisir; "fake duck'taki adamlari vuramiyorum"): DT'li
            -- silahta govde.
            local profile = enemy_watch.profile(target)
            if wanted == nil and gun and not (info ~= nil and info[4]) and profile ~= nil
                and (profile.defensive_now or profile.fakeduck) then
                wanted = "Prefer"
            end
        end
        if not lethal or sniper then
            local stall = resolver.body_stall
            stall.key, stall.visible, stall.last, stall.relaxed = nil, 0, nil, false
        end
        if sniper then
            current.lethal = lethal
        else
            current.lethal = wanted == "Prefer" or wanted == "Force"
        end
        if wanted == nil or resolver.user_body == "Force" or resolver.user_body == wanted then
            override("body_aim", nil)
        else
            override("body_aim", wanted)
        end

        -- Kafa ya da oldurucu atis: tek atisli silahta minimum hasar hedefin canina cekilir (en
        -- fazla 100), aimbot sadece oldurecek yere ates eder. Tam canli dusmanda bu kafa demek;
        -- govde ancak olduruyorsa. Neverlose'un Body Aim'inde "hic govde" secenegi yok: loglarda
        -- Body Aim "Default" iken de tam canli dusmanlara 67-93'luk govde vuruslari vardi.
        -- Senin daha yuksek minimum hasarin dusurulmez.
        if overridden.min_damage == nil then
            resolver.user_md = get("min_damage")
        end
        local min_damage = nil
        if sniper then
            min_damage = HP_PLUS_ONE
            if type(resolver.user_md) == "number" and resolver.user_md >= min_damage then
                min_damage = nil
            end
        end
        current.head_only = min_damage ~= nil
        override("min_damage", min_damage)
    end
end

local function update_flip(s, exploit, choked)
    -- Bir onceki paket gonderildiyse yeni bir choke dongusu basliyor demektir.
    if choked ~= 0 then
        return
    end
    flip.packets = flip.packets + 1
    -- Hedef her seferinde yeniden hesaplanir ki DT sarji bitince ya da durum
    -- degisince gecikme bir sonraki flip'i beklemeden uyum saglasin.
    local target = exploit and s.delay:get() + flip.extra or 1
    if flip.packets < target then
        return
    end
    if s.body_yaw:get() == "Random" then
        flip.side = random(0, 1) == 1
    else
        flip.side = not flip.side
    end
    flip.packets = 0
    flip.step = flip.step + 1
    local spread = s.delay_random:get()
    flip.extra = spread > 0 and random(0, spread) or 0
    flip.yaw_n = random() * 2 - 1
    flip.mod_n = random() * 2 - 1
    flip.limit_n = random()
    flip.rand_side = random(0, 1) == 1
end

local function round(x)
    return floor(x + 0.5)
end

local function normalize_yaw(yaw)
    yaw = (yaw + 180) % 360 - 180
    if yaw == -180 then
        yaw = 180
    end
    return yaw
end

local function set_inverter(side)
    if api.inverter ~= nil then
        api.inverter(side)
    else
        override("inverter", side)
    end
end

local function apply(v)
    override("pitch", v.pitch)
    override("yaw_base", v.yaw_base)
    override("yaw_offset", normalize_yaw(v.yaw_offset))
    override("yaw_modifier", v.modifier)
    override("modifier_offset", max(-180, min(180, v.mod_offset)))
    override("body_yaw", v.body ~= "Off")
    -- Body freestanding acikken tarafi Neverlose secer; her tick inverter'i zorlamak
    -- onun kararini bozar. O zaman sadece gosterge icin gercek taraf okunur.
    local side = v.side
    if v.body == "Static" and v.body_fs ~= "Off" then
        if api.inverter ~= nil then
            local actual = api.inverter()
            if type(actual) == "boolean" then
                side = actual
            end
        else
            override("inverter", nil)
        end
    else
        set_inverter(v.side)
    end
    override("left_limit", v.left)
    override("right_limit", v.right)
    -- Neverlose'un kendi "Jitter" secenegini bilerek vermiyoruz; jitter'i lua
    -- yonetiyor ki yaw ile desync ayni tarafta kalsin.
    override("body_options", v.avoid_overlap and OPTIONS_OVERLAP or OPTIONS_NONE)
    override("body_fs", v.body == "Static" and v.body_fs or "Off")
    override("freestanding", v.freestand)

    current.side = side
    current.freestand = v.freestand
    if v.body == "Off" then
        current.limit = 0
    elseif side then
        current.limit = v.right
    else
        current.limit = v.left
    end
end

-- Durumun exploit secimi; fake duck ile DT/HS birlikte calismaz, o zaman karisilmaz.
local NON_GUNS = { CKnife = true, CKnifeGG = true, CWeaponTaser = true, CC4 = true }

-- Bicak / zeus / bomba ile exploit degismez, son silahinki korunur. Scout -> bicak ->
-- scout gecisinde HS ile DT arasinda gidip gelmek her seferinde DT'yi bosaltir.
local exploit_memory = { choice = nil }

local function apply_exploit(s, class)
    local choice = s ~= nil and s.exploit ~= nil and s.exploit:get() or "Binds"
    if not menu.auto_exploit:get() or effective("fakeduck") then
        choice = "Binds"
    end
    if choice ~= "Binds" then
        local holding_gun = class ~= nil and not NON_GUNS[class] and not is_grenade(class)
        local sniper_setting = menu.sniper_exploit:get()
        local sniper_hs = SNIPERS[class] and (sniper_setting == "Hide shots" or (sniper_setting == "Auto (learn)" and sniper.choice == "hs"))
        -- Havada sniper DT (air lag ve teleport icin); inince yine Hide shots.
        if sniper_hs and menu.sniper_air_dt:get() and (current.state == "Air" or current.state == "Air crouch") then
            sniper_hs = false
        end
        if sniper_hs then
            choice = "Hide shots"
        elseif not holding_gun and exploit_memory.choice ~= nil then
            choice = exploit_memory.choice
        end
        if holding_gun then
            exploit_memory.choice = choice
        end
    end
    if choice == "Double tap" then
        override("doubletap", true)
        override("hideshots", false)
    elseif choice == "Hide shots" then
        override("doubletap", false)
        override("hideshots", true)
    else
        override("doubletap", nil)
        override("hideshots", nil)
    end
end

-- Defensive'i zorlamayi birakir. Kullanicinin kendi ayari "Always On" olsa bile
-- en sakin moda ceker; Neverlose'da "On Peek"ten daha kapali bir secenek yok.
local function defensive_off()
    override("lag_options", "On Peek")
    override("hs_options", "Favor Fire Rate")
    override("hidden", false)
end

local apply_defensive
do
    local function hidden_pitch_value(s)
        local mode = s.hidden_pitch:get()
        if mode == "Down" then return 89 end
        if mode == "Up" then return -89 end
        if mode == "Zero" then return 0 end
        if mode == "Switch" then return flip.side and 89 or -89 end
        if mode == "Random" then return random(-89, 89) end
        if mode == "Custom" then return s.hidden_pitch_value:get() end
        return nil
    end

    local function hidden_yaw_value(s)
        local mode = s.hidden_yaw:get()
        if mode == "Sideways" then return flip.side and 90 or -90 end
        if mode == "Spin" then return normalize_yaw(globals.tickcount * menu.hidden_spin:get() * 3) end
        if mode == "Random" then return random(-180, 180) end
        if mode == "Forward" then return 180 end
        if mode == "Custom" then return s.hidden_yaw_value:get() end
        return nil
    end

    -- HS icin "On peek" emulasyonu: Break LC acildiktan sonra bu kadar tick acik kalir,
    -- gorus her 2 tick'te degisebildigi icin acilip kapanip titremesin.
    local HS_LC_HOLD = 32
    local hs_lc = { until_tick = -1000 }

    -- "Smart" + DT: biri kafani gordugu (ya da 0.2 sn icinde gorecegi) surece ve gorus
    -- kesildikten sonra SMART_HOLD tick daha defensive zorlanir. Eskiden ayni gorus 1 sn'den
    -- uzun surunce birakiliyordu; loglarda Peek'te 1.47 sn goruldukten sonra "DT dolu, DEF
    -- yok" iken kafadan vuruldun. Neverlose'un modu "On Peek" kaldigi icin DT bosalmaz.
    local SMART_HOLD = 8
    local smart = { last = -1000 }

    local function smart_window(now)
        if seen_by_enemy() then
            smart.last = now
        end
        return now >= smart.last and now - smart.last <= SMART_HOLD
    end

    -- "Defensive vs enemy peeks": "On peek" durumlarinda (durma, egilip bekleme) bir dusman
    -- sana dogru peek atarken (exposure.peeked) DT defensive'i zorlanir ve ANTI_HOLD tick
    -- daha surer: ilk mermisi geldiginde LC kirik ve acilar gizli olur. Dusman goruste
    -- kalirsa birakilir; aci tutarken kendi atisini geciktirmesin.
    local ANTI_HOLD = 16
    local anti = { last = -1000 }

    local function anti_window(now)
        if exposure.peeked then
            anti.last = now
        end
        return now >= anti.last and now - anti.last <= ANTI_HOLD
    end

    apply_defensive = function(cmd, s, class, state, moving)
        local dt, hs = effective("doubletap"), effective("hideshots")
        local mode = s.def_mode ~= nil and s.def_mode:get() or "Off"
        -- Fake duck DT/HS ile birlikte calismaz; elde bomba varken de LC kirmak atisi bozar.
        if not (dt or hs) or mode == "Off" or is_grenade(class) or effective("fakeduck") then
            defensive_off()
            return
        end
        -- Hide shots'in Neverlose'da "On Peek" secenegi yok, sadece Break LC var. Peek
        -- durumundayken, hareket ederken (havada dahil) ya da biri kafani goruyor / birazdan
        -- gorecek / az once kafana ates ettiyse Break LC acilir. Hareket ederken gorus
        -- beklenmez: LC kirmak eski kayitlarina backtrack'i bozar ve loglarda HS ile "DEF
        -- yok" iken izlerin gormedigi dusmanlardan kafadan vuruldun.
        local now = globals.tickcount
        -- Atislarin sunucuda gecmedigi goruldukten sonra o lag bir sure durur (bkz. aim_ack).
        local paused = resolver.paused
        local lc_ok = not paused("LC")
        local on_peek = mode == "On peek" or mode == "Smart"
        if on_peek and hs and (state == "Peek" or moving or seen_by_enemy()) then
            hs_lc.until_tick = now + HS_LC_HOLD
        end
        local hs_peek = on_peek and hs and lc_ok and now <= hs_lc.until_tick and now >= hs_lc.until_tick - HS_LC_HOLD
        -- Neverlose'da DT, HS'den once gelir; ikisi de aciksa DT gecerlidir. Sarj yokken
        -- defensive olmaz, o zaman zorlanmaz.
        local airborne = state == "Air" or state == "Air crouch"
        local window = mode == "Smart" and (smart_window(now) or (airborne and menu.air_lag:get()))
        local guard = mode == "On peek" and menu.anti_peek:get() and anti_window(now)
        -- AI peek yururken / beklerken: defensive dusman seni gormeden baslar, ilk gordugu
        -- kayit eski ve acilar gizli olur (defensive peek).
        local peeking = on_peek and exposure.peeking ~= nil and menu.peek_defensive:get()
        local forced = (window or guard or peeking) and dt and exploit_active() and not paused("DEF")
        current.defensive = not on_peek or hs_peek or forced
        current.forced = forced

        -- Break LC sadece DT kapaliyken gecerli (Neverlose'da DT, HS'den once gelir).
        local break_lc = on_peek and hs_peek or (not on_peek and hs and lc_ok)
        current.lc = break_lc and not dt
        if on_peek then
            -- Neverlose peek attigini kendisi algilar ve o an defensive'e gecer.
            override("lag_options", "On Peek")
            override("hs_options", break_lc and "Break LC" or "Favor Fire Rate")
            if forced then
                pcall(function() cmd.force_defensive = true end)
            end
        elseif mode == "Always on" then
            override("lag_options", "Always On")
            override("hs_options", break_lc and "Break LC" or "Favor Fire Rate")
        else
            override("lag_options", "On Peek")
            override("hs_options", break_lc and "Break LC" or "Favor Fire Rate")
            local ticks = s.def_ticks:get()
            local number = cmd.command_number or globals.tickcount
            pcall(function() cmd.force_defensive = number % ticks == 0 end)
        end

        local pitch, yaw = hidden_pitch_value(s), hidden_yaw_value(s)
        if pitch == nil and yaw == nil then
            override("hidden", false)
            return
        end
        -- Hidden acilar sadece defensive tick'lerinde kullanilir.
        override("hidden", true)
        if pitch ~= nil and api.hidden_pitch ~= nil then
            api.hidden_pitch(pitch)
        end
        if yaw ~= nil and api.hidden_yaw ~= nil then
            api.hidden_yaw(yaw)
        end
    end
end

local tickbase = { max = 0, left = 0, sent = nil, since_sent = 0, jump = false }
-- Kendi son atisimiz: DT atistan sonra yeniden sarj olur; bu sure log'da ve DT
-- istatistiginde ayrilir.
-- round: bu round'da kafana / govdene gelen mermiler (round ozeti icin, bkz. own.summary).
local own = { last_shot = -1000, round = nil }
local DT_SHOT_GRACE = 1.0

-- Defensive penceresi iki yoldan anlasilir:
--  1) tickbase gordugumuz en yuksek degerin gerisine kaydirildiysa sunucu o
--     tick'leri yeniden isliyor;
--  2) DT doluyken arka arkaya gonderilen iki paket arasinda tickbase geri gittiyse
--     ya da aradaki komut sayisindan fazla ileri sicradiysa (topluluk lua'larinin
--     yontemi; onlar 1'den fazlasina bakiyor, ama HS'de fakelag surdugu icin paket
--     basina birden fazla komut normal ve yanlis "defensive" gosteriyordu).
local function update_tickbase(lp, choked)
    local tb = lp.m_nTickBase
    if type(tb) ~= "number" then
        tickbase.left, tickbase.jump, tickbase.sent, tickbase.since_sent = 0, false, nil, 0
        return
    end
    if abs(tb - tickbase.max) > 64 then
        tickbase.max = 0
    end
    if tb > tickbase.max then
        tickbase.max = tb
        tickbase.left = 0
    else
        -- tb < max: zaten simule edilmis bir tick yeniden isleniyor. (tb == max
        -- sayilmaz; DT sarj olurken tickbase durabilir.)
        tickbase.left = min(14, max(0, tickbase.max - tb))
    end

    tickbase.since_sent = tickbase.since_sent + 1
    local charge = api.charge ~= nil and api.charge() or nil
    if type(charge) == "number" and charge < 1 then
        tickbase.jump = false
    elseif choked == 0 and tickbase.sent ~= nil then
        local diff = tb - tickbase.sent
        tickbase.jump = diff < 0 or diff > tickbase.since_sent
    end
    if choked == 0 then
        tickbase.sent = tb
        tickbase.since_sent = 0
    end
end

local function defensive_active()
    return tickbase.left > 0 or tickbase.jump
end

-- Safe recharge: DT sarj olurken oyuncunun komutlari sunucuda islenmez, ~14 tick
-- yerinde donarsin. Oyun loglarinda peek'te ates ettikten 0.05-0.36 sn sonra "DT %0"
-- iken kafadan vuruldun; tam bu donma. Tehdit kafani goruyorken (ya da birazdan
-- gorecekken) sarj bekletilir; siperin arkasina gecince dolar. Hep goruluyorsan
-- RECHARGE_HOLD_MAX sn sonra yine de sarj olur, DT'siz kalinmaz.
--
-- Sarj iki yerde sifirdan baslar: kendi atisindan sonra ve fake duck'i biraktiginda
-- (fake duck'ta exploit calismaz; fake duck peek'ten kalkinca hala gorus alanindasin).
-- Hide shots da ayni sekilde bekletilir, ama sadece Neverlose'un sarj degerinin HS'de
-- de dolup bosaldigi goruldukten sonra (hs_charges). Deger sadece DT'ye aitse HS'ye
-- hic karisilmaz.
local RECHARGE_HOLD_MAX = 1.2
local recharge = { held = false, fakeduck = false, released = -1000, hs_charges = false }

local function set_charge(allowed)
    if api.allow_charge == nil or recharge.held == not allowed then
        return
    end
    api.allow_charge(allowed)
    recharge.held = not allowed
end

local function update_recharge()
    local fakeduck = effective("fakeduck")
    if recharge.fakeduck and not fakeduck then
        recharge.released = globals.realtime
    end
    recharge.fakeduck = fakeduck

    local dt, hs = effective("doubletap"), effective("hideshots")
    local hold = false
    if menu.safe_recharge:get() and exposure.available and api.charge ~= nil and (dt or hs) and not fakeduck then
        local charge = api.charge()
        if type(charge) == "number" then
            -- Neverlose'da DT, HS'den once gelir; ikisi de aciksa deger DT'nindir.
            if hs and not dt and charge >= 1 then
                recharge.hs_charges = true
            end
            local since = globals.realtime - max(own.last_shot, recharge.released)
            hold = (dt or recharge.hs_charges) and charge < 1 and since >= 0 and since <= RECHARGE_HOLD_MAX
                and seen_by_enemy()
        end
    end
    set_charge(not hold)
end

-- Sen ates etmezken (atistan sonraki 1 sn haric) durum basina:
--  DT  = DT'nin dolu oldugu tick orani. Dusukse o durumun ayarlari DT'yi bosaltiyor.
--  DEF = exploit hazirken defensive penceresinin acik oldugu tick orani. "Always on"
--        bir durumda dusukse defensive gercekten calismiyor demektir.
local function sample_exploit(state)
    local dt, hs = effective("doubletap"), effective("hideshots")
    if not (dt or hs) then
        return
    end
    local since = globals.realtime - own.last_shot
    if since >= 0 and since <= DT_SHOT_GRACE then
        return
    end
    local entry = stat_for(state)
    -- Bilerek bekletilen sarj "DT bosaltiyor" sayilmaz.
    if dt and recharge.held then
        return
    end
    if dt and api.charge ~= nil then
        local charge = api.charge()
        if type(charge) == "number" then
            entry.dt_ticks = entry.dt_ticks + 1
            if charge < 1 then
                return
            end
            entry.dt_full = entry.dt_full + 1
        end
    end
    entry.def_ticks = entry.def_ticks + 1
    if defensive_active() then
        entry.def_on = entry.def_on + 1
    end
end

-- Fake duck korumasi: oyun loglarinda fake duck'tayken bicakla uc kez arka arkaya
-- vurulup olundu. Fake duck'ta egik ve yavas kalirsin, DT/HS de calismaz. Bicak ya da
-- zeus tutan canli bir dusman KNIFE_NEAR birimden yakinsa fake duck kapatilir (bind'in
-- basili olsa da); KNIFE_FAR'dan uzaklasinca ya da silah degistirince birakilir.
local update_fd_guard
do
    local KNIFE_NEAR, KNIFE_FAR = 260, 360
    -- Hareket: FD_MOVE birim/sn ustunde FD_GRACE tick kalinca birakilir, FD_STOP altina inince
    -- geri verilir. Kisa kipirdama (sag-sol aci ayari) birakmaz: fake duck'i birakip geri vermek
    -- gozunu kaldirip indirir, aimbot'un o anki atisi yanlis goz yuksekliginden iskalar.
    -- why = "move" / "knife": neden biz biraktik; logged = son "hareket" logunun zamani;
    -- moving = hizin kac tick'tir FD_MOVE ustunde oldugu.
    local FD_MOVE, FD_STOP, FD_GRACE = 40, 10, 10
    local fd = { why = nil, logged = -1000, moving = 0 }

    local function fd_pointless(lp)
        if not menu.fd_still:get() then
            return false
        end
        if bit.band(lp.m_fFlags, 1) == 0 then
            return true
        end
        local ok, speed = pcall(function()
            local v = lp.m_vecVelocity
            return sqrt(v.x * v.x + v.y * v.y)
        end)
        if not ok or type(speed) ~= "number" then
            return false
        end
        if fd.why == "move" then
            return speed > FD_STOP
        end
        fd.moving = speed > FD_MOVE and fd.moving + 1 or 0
        return fd.moving >= FD_GRACE
    end

    local function knife_enemy(lp, radius)
        local mine = origin_of(lp)
        if mine == nil then
            return nil
        end
        local ok, list = pcall(entity.get_players, true)
        if not ok or type(list) ~= "table" then
            return nil
        end
        local best, best_dist = nil, radius
        for _, enemy in ipairs(list) do
            local ok_alive, alive = pcall(function() return enemy:is_alive() end)
            local ok_class, class = pcall(weapon_class, enemy)
            if ok_alive and alive and not dormant(enemy) and ok_class and MELEE[class] then
                local pos = origin_of(enemy)
                if pos ~= nil then
                    local dx, dy, dz = pos.x - mine.x, pos.y - mine.y, pos.z - mine.z
                    local dist = sqrt(dx * dx + dy * dy + dz * dz)
                    if dist < best_dist then
                        best, best_dist = enemy, dist
                    end
                end
            end
        end
        return best, best_dist
    end

    update_fd_guard = function(lp)
        local pointless = fd_pointless(lp)
        if overridden.fakeduck ~= nil then
            -- Biz biraktik: neden bitince (durdun / indin, bicak uzaklasti) tus yine senin.
            if fd.why == "move" then
                if not pointless then
                    override("fakeduck", nil)
                    fd.why = nil
                end
            elseif not menu.fd_guard:get() or knife_enemy(lp, KNIFE_FAR) == nil then
                override("fakeduck", nil)
                fd.why = nil
            end
            return
        end
        fd.why = nil
        if not get("fakeduck") then
            return
        end
        if pointless then
            override("fakeduck", false)
            if overridden.fakeduck ~= nil then
                fd.why = "move"
                local now = globals.realtime
                if menu.hit_log:get() and (now < fd.logged or now - fd.logged > 10) then
                    fd.logged = now
                    print(("[%s] fake duck birakildi: %s (fake duck DT/HS'yi kapatir; yerinde dururken calisir)"):format(
                        SCRIPT, bit.band(lp.m_fFlags, 1) == 0 and "havadasin" or "hareket ediyorsun"))
                end
            end
            return
        end
        if not menu.fd_guard:get() then
            return
        end
        local enemy, dist = knife_enemy(lp, KNIFE_NEAR)
        if enemy ~= nil then
            override("fakeduck", false)
            if overridden.fakeduck ~= nil then
                fd.why = "knife"
                if menu.hit_log:get() then
                    print(("[%s] fake duck birakildi: %s bicak/zeus ile %d birim yakinda"):format(
                        SCRIPT, player_name(enemy), round(dist)))
                end
            end
        end
    end
end

-- AA hedefi. Neverlose'un "At Target"i tehdide bakar. Tehdit yoksa en yakin dusmana, tehdit
-- seni gormuyor ama yandan biri goruyorsa ona gore donulur: "Local View" + o dusmanin yonu,
-- "At Target" + Backward ile ayni sonuc (sirtin ona doner, jitter ve desync ona gore).
-- Desync kafayi yana kaydirir; bu ancak bakan dusmana gore dogru yondeyse kafayi saklar.
-- Freestanding'de ve sen "Local View" sectiysen dokunulmaz.
local function face_target(cmd, lp, yaw_base, yaw_offset, freestand)
    local threat = current_threat()
    exposure.facing = threat ~= nil and index_of(threat) or nil
    if yaw_base ~= "At Target" or freestand then
        return yaw_base, yaw_offset
    end
    -- AI peek'te peek atilan dusmana donulur: kendini bilerek ona gosteriyorsun.
    local target
    local ok_peek, peeking = pcall(entity.get, exposure.peeking)
    peeking = exposure.peeking ~= nil and ok_peek and peeking or nil
    if peeking ~= nil and index_of(peeking) ~= index_of(threat) then
        target = peeking
    elseif peeking ~= nil and threat ~= nil and index_of(peeking) == index_of(threat) then
        return yaw_base, yaw_offset
    elseif threat == nil then
        target = recent_shooter() or aa_threat()
    else
        target = recent_shooter() or seeing_flanker()
    end
    local mine, theirs = origin_of(lp), target ~= nil and origin_of(target) or nil
    local ok, view = pcall(function() return cmd.view_angles.y end)
    if mine == nil or theirs == nil or not ok or type(view) ~= "number" then
        return yaw_base, yaw_offset
    end
    local yaw = math.deg((math.atan2 or math.atan)(theirs.y - mine.y, theirs.x - mine.x))
    exposure.facing = index_of(target)
    return "Local View", yaw_offset + yaw - view
end

local MOVETYPE_LADDER = 9

-- Havada teleport: havadayken bir dusman kafani gorurken (ya da birazdan gorecekken) exploit
-- doluysa Neverlose'un teleport'u tetiklenir; biriken tick'ler bir anda oynanir, ziplama
-- yonunde ileri sicrarsin ve dusmanin elindeki kayit gecersizlesir. Sarj dolunca tekrar:
-- ziplama basina en fazla max_jump kez, en az gap sn arayla (teleport, sarj, teleport: havada
-- "ucma"). Yatay hiz en az min_speed. Fake duck'ta yok (exploit calismaz). Hide shots'ta
-- (scout / AWP / R8) da denenir: sarj harcanmadiysa Neverlose HS ile teleport yapmiyor
-- demektir, bir kez yazilir ve o haritada HS ile bir daha denenmez.
-- refilled: bu ziplamada teleport'tan sonra sarj havada yeniden doldu mu (inince ozet yazilir:
-- tek teleport ve dolmadiysa ikincisi sarj yuzunden gelmedi demektir).
-- v5.3 loglarinda her ziplamada 3 teleport (sinir) vardi ve sarj her seferinde doldu: sinir 5,
-- ara 0.15 sn; asil sinir sarjin dolmasi. Inise land_guard sn'den az kaldiysa teleport yok:
-- sarj (~0.22 sn) inene kadar dolmaz, yere DT'siz inip sarj olurken yerinde donardin.
local teleport = { last = -1000, count = 0, min_speed = 150, gap = 0.15, max_jump = 5, land_guard = 0.2,
    pending = nil, hs_ok = nil, refilled = false }

-- Yere kac sn kaldi (dikey hiz ve yer cekimiyle); 400 birim icinde yer yoksa ya da iz
-- atilamazsa huge.
teleport.land_time = function(lp)
    local ok, t = pcall(function()
        local origin, vz = lp:get_origin(), lp.m_vecVelocity.z
        local result = utils.trace_line(origin, vector(origin.x, origin.y, origin.z - 400), lp, 0x201400B)
        if result.fraction >= 1 then
            return huge
        end
        return (vz + sqrt(vz * vz + 2 * GRAVITY * 400 * result.fraction)) / GRAVITY
    end)
    return ok and type(t) == "number" and t or huge
end

teleport.update = function(lp, move_state)
    local now = globals.realtime
    -- Bir onceki tick'te HS ile denendiyse sarj harcandi mi?
    local pending = teleport.pending
    if pending ~= nil and globals.tickcount > pending.tick then
        teleport.pending = nil
        local charge = api.charge ~= nil and api.charge() or nil
        if type(charge) == "number" then
            teleport.hs_ok = charge < 0.99
            if not teleport.hs_ok and menu.hit_log:get() then
                print(("[%s] teleport: Hide shots ile calismiyor (sarj harcanmadi); sadece DT'li silahlarda"):format(SCRIPT))
            end
        end
    end
    if move_state ~= "Air" and move_state ~= "Air crouch" then
        if teleport.count > 0 and menu.hit_log:get() then
            print(("[%s] teleport: bu ziplamada %d kez%s"):format(SCRIPT, teleport.count,
                teleport.refilled and "" or " (sarj havada tekrar dolmadi)"))
        end
        teleport.count, teleport.refilled = 0, false
        return
    end
    if teleport.count > 0 and api.charge ~= nil then
        local charge = api.charge()
        if type(charge) == "number" and charge >= 1 then
            teleport.refilled = true
        end
    end
    if teleport.count >= teleport.max_jump or (now >= teleport.last and now - teleport.last < teleport.gap)
        or not menu.air_teleport:get() or api.teleport == nil or resolver.paused("TP") then
        return
    end
    -- Fake duck'ta exploit calismaz (bind'in "acik" gorunse de): v5.0 loglarinda FD'de teleport tetiklendi.
    if not (exposure.now or exposure.soon or exposure.any) or effective("fakeduck") then
        return
    end
    local dt, hs = effective("doubletap"), effective("hideshots")
    if not dt and not (hs and teleport.hs_ok ~= false) then
        return
    end
    local charge = api.charge ~= nil and api.charge() or nil
    if type(charge) == "number" and charge < 1 then
        return
    end
    local ok, speed = pcall(function()
        local v = lp.m_vecVelocity
        return sqrt(v.x * v.x + v.y * v.y)
    end)
    if not ok or type(speed) ~= "number" or speed < teleport.min_speed or teleport.land_time(lp) < teleport.land_guard then
        return
    end
    api.teleport()
    teleport.count, teleport.last = teleport.count + 1, now
    if not dt and teleport.hs_ok == nil then
        teleport.pending = { tick = globals.tickcount }
    end
    if menu.hit_log:get() then
        print(("[%s] teleport: havada goruldun, %s ile isinlanildi (%d. kez)"):format(SCRIPT, dt and "DT" or "HS",
            teleport.count))
    end
end

-------------------------------------------------------------------------------
-- AI peek
-------------------------------------------------------------------------------

-- Peek Assist tusunu basili tutup hareket tuslarina basmiyorsan script yanlari tarar:
-- tehdide dik, sola ve saga 18 / 32 / 46 / 60 birim. Bir noktaya yurunebiliyorsa (yolda
-- duvar yok, altinda zemin var) ve o noktadan dusmanin kafasina ya da gogsune ates etsen
-- aimbot'un minimum hasari geciyorsa (scout'ta canini, yani oldurecek atis), en yakin boyle
-- noktaya script yurur ve ates edilince (ya da edilmezse bekleyip) baslangic noktana kendisi
-- geri yurur. AI peek yururken Neverlose'un Peek Assist'i gecici olarak kapatilir: v4.9'da
-- nokta bulunuyor ("ai peek: sag 18 birim") ama karakter yurumuyordu; tus basili ve hareket
-- tusu yokken Peek Assist seni baslangicta tutup hareketi eziyordu. Hareket tusuna basinca
-- kontrol hemen sende (Peek Assist de geri gelir). DT sarj olurken ve atistan hemen sonra
-- peek atilmaz.
-- Ayni dusmana iki peek ust uste atissiz biterse (aimbot ates etmedi) o dusmana tusa yeniden
-- basana kadar peek atilmaz: v4.7 loglarinda ayni dusmana 7 kez bos peek atildi, her
-- seferinde kendini gosterdin. Her bos peek'te ne kadar yuruyebildigin konsola yazilir.
-- R8'de bekleme daha uzun: horoz cekilir ve isabeti toparlanir.
-- v5.3 loglarinda 4 peek'in 3'u 3-8 birim yurunup "aci kapandi" ile bitti: nokta tek bir
-- taramada gorunmus, hemen sonraki taramada kaybolmustu (dusmanin jitter'i / hareketi). Artik:
--  - nokta confirm_every tick sonra ikinci taramada da ayni tarafta bulunmazsa yurunmez;
--  - yururken tek kotu tarama geri dondurmez, lost_max tarama ust uste olmazsa donulur;
--  - beklerken aci kayarsa (dusman yurudu) ayni tarafta biraz ileri gidilir (reach birime kadar);
--  - kafa ve gogsun yaninda mide de denenir (cani azsa scout'la mide de oldurur).
-- Vazgecince nedeni hasariyla yazilir ("hasar 0/101": aci tamamen kapandi; "95/101": sinirda).
local ai_peek = { mode = nil, home = nil, target = nil, side = nil, until_time = -1000, scan_tick = -1000,
    rest = -1000, fails = 0, blocked = nil, reached = 0, step = 0, enemy = nil, name = nil, shots = {},
    held_since = nil, reported = false, why = nil, quiet = 1.0, candidate = nil, lost = 0, started = -1000,
    steps = { 18, 32, 46, 60 }, every = 4, confirm_every = 2, walk_every = 2, lost_max = 3, reach = 74,
    hold = 0.5, hold_r8 = 0.75, after_shot = 0.8, back_time = 0.6 }
local update_ai_peek
do
    local MASK_PLAYERSOLID = 0x201400B
    local trace_line, trace_hull
    pcall(function()
        trace_line = type(utils.trace_line) == "function" and utils.trace_line or nil
        trace_hull = type(utils.trace_hull) == "function" and utils.trace_hull or nil
    end)
    ai_peek.available = trace_bullet ~= nil and trace_line ~= nil
    local atan2 = math.atan2 or math.atan

    local function fraction(result)
        local ok, value = pcall(function() return result.fraction end)
        return ok and type(value) == "number" and value or 0
    end

    -- Oraya yurunebilir misin: govde boyunca engel yok (hull; yoksa diz ve goz hizasinda iki
    -- cizgi) ve noktanin altinda zemin var (ucurumdan dusmezsin). Iz atilamazsa hayir.
    local function walkable(lp, from, to)
        local ok, clear = pcall(function()
            if trace_hull ~= nil then
                return fraction(trace_hull(vector(from.x, from.y, from.z + 18), vector(to.x, to.y, to.z + 18),
                    vector(-15, -15, 0), vector(15, 15, 54), lp, MASK_PLAYERSOLID)) >= 1
            end
            for _, height in ipairs({ 24, 60 }) do
                if fraction(trace_line(vector(from.x, from.y, from.z + height), vector(to.x, to.y, to.z + height),
                    lp, MASK_PLAYERSOLID)) < 1 then
                    return false
                end
            end
            return true
        end)
        if not ok or not clear then
            return false
        end
        local ok_ground, ground = pcall(function()
            return fraction(trace_line(vector(to.x, to.y, to.z + 18), vector(to.x, to.y, to.z - 40), lp,
                MASK_PLAYERSOLID)) < 1
        end)
        return ok_ground and ground
    end

    -- Dusmanin kafasi, gogsu ve midesi (hitbox okunamazsa goz, govde ortasi ve bel).
    local function aim_points(enemy)
        local points = {}
        local ok_head, head = pcall(function() return enemy:get_hitbox_position(0) end)
        if not ok_head or head == nil then
            ok_head, head = pcall(function() return enemy:get_eye_position() end)
        end
        if ok_head and head ~= nil then
            points[#points + 1] = head
        end
        for _, body in ipairs({ { 5, 50 }, { 3, 40 } }) do
            local ok_body, point = pcall(function() return enemy:get_hitbox_position(body[1]) end)
            if not ok_body or point == nil then
                local base = origin_of(enemy)
                ok_body, point = base ~= nil, base ~= nil and vector(base.x, base.y, base.z + body[2]) or nil
            end
            if ok_body and point ~= nil then
                points[#points + 1] = point
            end
        end
        return points
    end

    local function best_damage(lp, eye, points)
        local best = 0
        for _, point in ipairs(points) do
            local ok, damage = pcall(trace_bullet, lp, eye, point)
            if ok and type(damage) == "number" and damage > best then
                best = damage
            end
        end
        return best
    end

    -- Aimbot'un ates edecegi en dusuk hasar: Min. Damage (100 ustu = can + fazlasi), en fazla
    -- dusmanin cani. Okunamazsa can (sadece oldurecek atis).
    local function required_damage(enemy)
        local health = prop(enemy, "m_iHealth")
        if type(health) ~= "number" or health <= 0 then
            health = 100
        end
        -- Peek atinca dusman seni gorecek: scout / AWP / R8'de (Head unless body kills) su an
        -- kimse gormese de sadece oldurecek atis icin peek atilir.
        if menu.head_only:get() and SNIPERS[current.weapon] then
            return health + 1
        end
        local md = effective("min_damage")
        if type(md) ~= "number" then
            return health
        end
        if md > 100 then
            return health + md - 100
        end
        return max(1, min(md, health))
    end

    local function eye_height(lp, mine)
        local ok, eye = pcall(function() return lp:get_eye_position() end)
        if ok and eye ~= nil and eye.z > mine.z then
            return eye.z - mine.z
        end
        return 64
    end

    -- O noktada kafani (merkez ya da kenar) peek atilan dusman disinda goren canli dusman; yoksa
    -- nil. v5.3 loglarinda peek sirasinda baska bir dusman (Tapper) kafadan vurdu: nokta sadece
    -- hedefe gore seciliyordu.
    local function seen_by_other(spot, height, enemy)
        local index = index_of(enemy)
        local ok, list = pcall(entity.get_players, true)
        if not ok or type(list) ~= "table" then
            return nil
        end
        local head = vector(spot.x, spot.y, spot.z + height)
        for _, other in ipairs(list) do
            local ok_alive, alive = pcall(function() return other:is_alive() end)
            if index_of(other) ~= index and ok_alive and alive and not dormant(other) then
                local ok_eye, eye = pcall(function() return other:get_eye_position() end)
                if ok_eye and eye ~= nil and head_visible_to(other, eye, head, 0, 0, 0) then
                    return other
                end
            end
        end
        return nil
    end

    -- "here": buradan zaten vurulabiliyor (aimbot ates eder); nil: yan noktalarin hicbiri
    -- olmuyor (ikinci deger: oldurecek nokta vardi ama baska bir dusman da kafani gorurdu);
    -- yoksa en yakin nokta.
    local function scan(lp, mine, enemy)
        local theirs = origin_of(enemy)
        if theirs == nil then
            return nil
        end
        local dx, dy = theirs.x - mine.x, theirs.y - mine.y
        local length = sqrt(dx * dx + dy * dy)
        if length < 1 then
            return nil
        end
        dx, dy = dx / length, dy / length
        local height, need, points = eye_height(lp, mine), required_damage(enemy), aim_points(enemy)
        if #points == 0 then
            return nil
        end
        if best_damage(lp, vector(mine.x, mine.y, mine.z + height), points) >= need then
            return "here"
        end
        local found, watcher
        for _, side in ipairs({ { -dy, dx, "sol" }, { dy, -dx, "sag" } }) do
            for _, step in ipairs(ai_peek.steps) do
                if found ~= nil and step >= found.step then
                    break
                end
                local spot = vector(mine.x + side[1] * step, mine.y + side[2] * step, mine.z)
                if not walkable(lp, mine, spot) then
                    break
                end
                local damage = best_damage(lp, vector(spot.x, spot.y, spot.z + height), points)
                if damage >= need then
                    local other = seen_by_other(spot, height, enemy)
                    if other == nil then
                        found = { spot = spot, step = step, side = side[3], damage = damage }
                        break
                    end
                    watcher = watcher or other
                end
            end
        end
        if found == nil then
            return nil, watcher
        end
        return found
    end

    -- Bu noktadan (goz yuksekliginde) dusmana en iyi hasar ve gereken hasar.
    local function spot_damage(lp, mine, spot, enemy)
        local points, need = aim_points(enemy), required_damage(enemy)
        if #points == 0 then
            return 0, need
        end
        return best_damage(lp, vector(spot.x, spot.y, spot.z + eye_height(lp, mine)), points), need
    end

    -- Hedefe dogru tam hizla (son 12 birimde yavaslayarak) yurur; uzakligi dondurur.
    local function move_to(cmd, mine, dest)
        local dx, dy = dest.x - mine.x, dest.y - mine.y
        local distance = sqrt(dx * dx + dy * dy)
        local ok, view = pcall(function() return cmd.view_angles.y end)
        if not ok or type(view) ~= "number" or distance < 1 then
            return distance
        end
        local angle = math.rad(math.deg(atan2(dy, dx)) - view)
        local speed = distance > 12 and 450 or distance * 30
        local forward, side = math.cos(angle) * speed, -math.sin(angle) * speed
        -- Tuslar da hareketle uyumlu basili gorunur (oyun ve Neverlose tuslara da bakar).
        pcall(function()
            cmd.forwardmove, cmd.sidemove = forward, side
            cmd.in_forward, cmd.in_back = forward > 1, forward < -1
            cmd.in_moveright, cmd.in_moveleft = side > 1, side < -1
        end)
        return distance
    end

    local function stand(cmd)
        pcall(function()
            cmd.forwardmove, cmd.sidemove = 0, 0
            cmd.in_forward, cmd.in_back, cmd.in_moveright, cmd.in_moveleft = false, false, false, false
        end)
    end

    local function user_moving(cmd)
        local ok, moving = pcall(function()
            return (tonumber(cmd.forwardmove) or 0) ~= 0 or (tonumber(cmd.sidemove) or 0) ~= 0
                or cmd.in_forward == true or cmd.in_back == true or cmd.in_moveleft == true or cmd.in_moveright == true
        end)
        return not ok or moving
    end

    local function allowed(lp, cmd, class)
        if not ai_peek.available or not menu.ai_peek:get() or not peek_key_held() then
            return false
        end
        if bit.band(lp.m_fFlags, 1) == 0 or cmd.in_jump == true or cmd.in_use == true
            or lp.m_MoveType == MOVETYPE_LADDER or effective("fakeduck") then
            return false
        end
        return class ~= nil and not MELEE[class] and class ~= "CC4" and not is_grenade(class)
    end

    local function usable(enemy)
        if enemy == nil or dormant(enemy) then
            return nil
        end
        local ok, alive = pcall(function() return enemy:is_alive() end)
        return ok and alive and enemy or nil
    end

    local function enemy_target()
        return usable(aa_threat())
    end

    -- Peek atilan dusman: yururken tehdit degisse de ayni dusman (yeni tehdide gore tarama
    -- yarida vazgecirmesin).
    local function peek_enemy()
        local ok, enemy = pcall(entity.get, ai_peek.enemy)
        return usable(ok and enemy or nil)
    end

    ai_peek.reset = function()
        ai_peek.mode, ai_peek.home, ai_peek.target, ai_peek.fails, ai_peek.blocked = nil, nil, nil, 0, nil
        ai_peek.held_since, ai_peek.reported, ai_peek.why, ai_peek.shot = nil, false, nil, false
        ai_peek.candidate, ai_peek.lost = nil, 0
        override("peek_assist", nil)
    end

    -- Tus quiet sn basili ve hic peek yoksa nedeni bir kez yazilir (her basista bir kez).
    local function report_idle(now)
        if ai_peek.reported or ai_peek.held_since == nil or now - ai_peek.held_since < ai_peek.quiet
            or ai_peek.why == nil then
            return
        end
        ai_peek.reported = true
        if menu.shot_log:get() then
            print(("[%s] ai peek: peek yok, %s"):format(SCRIPT, ai_peek.why))
        end
    end

    -- Atissiz biten peek: geri don ve ne kadar yuruyebildigini yaz (0'a yakinsa hareketini
    -- baska bir sey, ornegin Peek Assist'in geri cekmesi, eziyor demektir).
    local function give_up(cmd, mine, now, reason)
        ai_peek.mode, ai_peek.until_time = "back", now + ai_peek.back_time
        move_to(cmd, mine, ai_peek.home or mine)
        aim_stats.ai_empty = aim_stats.ai_empty + 1
        if menu.shot_log:get() then
            print(("[%s] ai peek: atis olmadi, %s (%d/%d birim gidildi) -> geri"):format(SCRIPT, reason,
                floor(ai_peek.reached + 0.5), ai_peek.step))
        end
    end

    -- Peek oyuncunun elinden alindi (tus, hava, silah...): ne zaman ve neden yazilir.
    local function cancelled(cmd, lp)
        if ai_peek.mode ~= "go" and ai_peek.mode ~= "hold" then
            return
        end
        if menu.shot_log:get() then
            local why = user_moving(cmd) and "hareket tusu" or (not peek_key_held() and "Peek Assist birakildi")
                or "kosul degisti"
            print(("[%s] ai peek: iptal, %s"):format(SCRIPT, why))
        end
    end

    -- Aimbot peek sirasinda ates etti: sonucu aim_ack'te yazilir (bkz. ai_peek.result).
    ai_peek.fired = function(id, target)
        if (ai_peek.mode ~= "go" and ai_peek.mode ~= "hold") or id == nil then
            return
        end
        aim_stats.ai_shots = aim_stats.ai_shots + 1
        ai_peek.shots[id] = { name = player_name(target), reached = floor(ai_peek.reached + 0.5) }
    end

    ai_peek.result = function(e, target_name)
        local shot = e.id ~= nil and ai_peek.shots[e.id] or nil
        if shot == nil then
            return
        end
        ai_peek.shots[e.id] = nil
        local what
        if e.state == nil then
            aim_stats.ai_hits = aim_stats.ai_hits + 1
            what = ("isabet %s -%d"):format(HITGROUPS[e.hitgroup] or "?", tonumber(e.damage) or 0)
        else
            what = ("iska (%s)"):format(tostring(e.state))
        end
        if menu.shot_log:get() then
            print(("[%s] ai peek sonucu: %s -> %s (%d birim)"):format(SCRIPT, what, target_name or shot.name,
                shot.reached))
        end
    end

    -- Peek sirasinda (ya da donerken) vuruldun.
    ai_peek.hurt = function(hitgroup, damage, attacker_name)
        if ai_peek.mode == nil then
            return
        end
        aim_stats.ai_hurt = aim_stats.ai_hurt + 1
        if menu.shot_log:get() then
            print(("[%s] ai peek: peek sirasinda vuruldun (%s -%d, %s)"):format(SCRIPT, HITGROUPS[hitgroup] or "?",
                tonumber(damage) or 0, attacker_name))
        end
    end

    local step

    update_ai_peek = function(lp, cmd, class)
        step(lp, cmd, class)
        -- Yururken / beklerken / donerken Peek Assist kapali (hareketi ezmesin); bosta senin.
        if ai_peek.mode ~= nil then
            override("peek_assist", false)
        else
            override("peek_assist", nil)
        end
        -- Defensive ve AA hedefi icin: su an kime kendini gosteriyorsun.
        exposure.peeking = (ai_peek.mode == "go" or ai_peek.mode == "hold") and ai_peek.enemy or nil
    end

    step = function(lp, cmd, class)
        local mine = origin_of(lp)
        if mine == nil or not allowed(lp, cmd, class) or user_moving(cmd) then
            cancelled(cmd, lp)
            ai_peek.reset()
            return
        end
        local now, tick = globals.realtime, globals.tickcount
        if ai_peek.held_since == nil then
            ai_peek.held_since = now
        end
        -- Aimbot ates etti: baslangic noktasina geri yurunur; after_shot sn yeni peek yok.
        if (ai_peek.mode == "go" or ai_peek.mode == "hold") and own.last_shot >= ai_peek.started then
            ai_peek.mode, ai_peek.target, ai_peek.fails, ai_peek.blocked = "back", nil, 0, nil
            ai_peek.until_time, ai_peek.shot = now + ai_peek.back_time, true
        end
        if (ai_peek.mode == "go" or ai_peek.mode == "hold") and ai_peek.home ~= nil then
            local rx, ry = mine.x - ai_peek.home.x, mine.y - ai_peek.home.y
            ai_peek.reached = max(ai_peek.reached, sqrt(rx * rx + ry * ry))
        end

        if ai_peek.mode == "back" then
            if ai_peek.home == nil or move_to(cmd, mine, ai_peek.home) < 6 or now > ai_peek.until_time then
                stand(cmd)
                ai_peek.mode, ai_peek.rest = nil, now + 0.3
                if ai_peek.shot then
                    -- Atisla biten peek bos sayilmaz.
                    ai_peek.shot = false
                    return
                end
                ai_peek.fails = ai_peek.fails + 1
                if ai_peek.fails >= 2 then
                    ai_peek.blocked = ai_peek.enemy
                    if menu.shot_log:get() then
                        print(("[%s] ai peek: 2 bos peek, bu dusmana Peek Assist tusuna yeniden basana kadar peek yok"):format(SCRIPT))
                    end
                end
            end
            return
        end

        local walking = ai_peek.mode == "go" or ai_peek.mode == "hold"
        local gap = walking and ai_peek.walk_every or (ai_peek.candidate ~= nil and ai_peek.confirm_every) or ai_peek.every
        local due = tick < ai_peek.scan_tick or tick - ai_peek.scan_tick >= gap
        local hold = class == "Revolver" and ai_peek.hold_r8 or ai_peek.hold
        if walking then
            local enemy = peek_enemy()
            if enemy == nil or now > ai_peek.until_time then
                give_up(cmd, mine, now, enemy == nil and "hedef yok" or "sure doldu")
                return
            end
            if due then
                ai_peek.scan_tick = tick
                -- Once buradan / hedef noktadan hala oluyor mu; olmuyorsa yeniden taranir.
                local result
                local damage, need = spot_damage(lp, mine, mine, enemy)
                if damage >= need then
                    result = "here"
                else
                    if ai_peek.mode == "go" and ai_peek.target ~= nil then
                        local at_spot = spot_damage(lp, mine, ai_peek.target, enemy)
                        damage = max(damage, at_spot)
                        if at_spot >= need then
                            result = { spot = ai_peek.target, side = ai_peek.side }
                        end
                    end
                    result = result or scan(lp, mine, enemy)
                end
                -- Tarama simdiki yerden yapilir; ayni taraftaki nokta kalan mesafedir. Diger
                -- taraf sayilmaz (yon degistirip gidip gelme olmasin), baslangictan reach
                -- birimden uzak nokta da.
                local why, far = nil, 0
                if type(result) == "table" and result.side ~= ai_peek.side then
                    why, result = "aci sadece diger tarafta", nil
                elseif type(result) == "table" and ai_peek.home ~= nil then
                    local fx, fy = result.spot.x - ai_peek.home.x, result.spot.y - ai_peek.home.y
                    far = sqrt(fx * fx + fy * fy)
                    if far > ai_peek.reach then
                        why, result = ("aci %d birimden uzakta"):format(ai_peek.reach), nil
                    end
                end
                -- Dusman defensive'deyken kaydi sahte (v5.4 loglarinda defensive kullanan dusmanlara
                -- peek'ler "hasar 0/101" ile bitti): o taramalar sayilmaz, kayit gercege donunce bakilir.
                local profile = enemy_watch.profile(enemy)
                local faked = profile ~= nil and (profile.defensive_now or profile.defensive or profile.lc)
                if result == nil and faked then
                    ai_peek.faked = true
                elseif result == nil then
                    -- Tek kotu tarama (dusmanin jitter'i) geri dondurmez; ust uste lost_max kez.
                    ai_peek.lost = ai_peek.lost + 1
                    if ai_peek.lost >= ai_peek.lost_max then
                        give_up(cmd, mine, now, (why or ("aci kapandi, hasar %d/%d"):format(floor(damage + 0.5), need))
                            .. (ai_peek.faked and ", dusman defensive kullandi" or ""))
                        return
                    end
                elseif result == "here" then
                    -- Aci acildi: dur, aimbot ates etsin.
                    ai_peek.lost = 0
                    if ai_peek.mode == "go" then
                        ai_peek.mode, ai_peek.until_time = "hold", now + hold
                    end
                else
                    -- Beklerken aci kaydiysa (dusman yurudu) ayni tarafta ileri gidilir.
                    if ai_peek.mode == "hold" then
                        ai_peek.mode, ai_peek.until_time = "go", max(ai_peek.until_time, now + 0.25)
                    end
                    -- step: logda "gidildi / hedef" icin baslangictan hedefe uzaklik.
                    ai_peek.lost, ai_peek.target, ai_peek.step = 0, result.spot, max(ai_peek.step, floor(far + 0.5))
                end
            end
            if ai_peek.mode == "hold" then
                stand(cmd)
            elseif move_to(cmd, mine, ai_peek.target) < 4 then
                stand(cmd)
                ai_peek.mode, ai_peek.until_time = "hold", now + hold
            end
            return
        end

        -- Bekleme: baslangic noktasi tus basiliyken durdugun yer.
        local enemy = enemy_target()
        if ai_peek.home == nil then
            ai_peek.home = mine
        end
        local hx, hy = mine.x - ai_peek.home.x, mine.y - ai_peek.home.y
        if hx * hx + hy * hy > 64 then
            ai_peek.home = mine
        end
        local ready = not effective("doubletap") or exploit_active()
        if enemy == nil then
            ai_peek.why = "hedef yok"
        elseif not ready then
            ai_peek.why = "DT sarj oluyor"
        end
        report_idle(now)
        if enemy == nil or not ready or now < ai_peek.rest or now - own.last_shot < ai_peek.after_shot or not due then
            return
        end
        local index = index_of(enemy)
        if ai_peek.blocked ~= nil and index == ai_peek.blocked then
            return
        end
        ai_peek.scan_tick = tick
        local result, watcher = scan(lp, mine, enemy)
        if type(result) ~= "table" then
            ai_peek.candidate = nil
            if result == "here" then
                ai_peek.why = ("%s buradan vurulabiliyor, aimbot ates etmeli"):format(player_name(enemy))
            elseif watcher ~= nil then
                ai_peek.why = ("%s icin nokta var ama %s de kafani gorurdu"):format(player_name(enemy), player_name(watcher))
            else
                ai_peek.why = ("%s icin 60 birime kadar oldurecek atis yok"):format(player_name(enemy))
            end
            return
        end
        -- Ilk taramada bulunan nokta teyit edilir: confirm_every tick sonra ayni dusmana ayni
        -- tarafta yine bulunursa yurunur (tek taramalik gorus jitter / hareket olabilir).
        local candidate = ai_peek.candidate
        if candidate == nil or candidate.enemy ~= index or candidate.side ~= result.side
            or tick - candidate.tick > 3 * ai_peek.confirm_every then
            ai_peek.candidate = { enemy = index, side = result.side, tick = tick }
            return
        end
        ai_peek.candidate = nil
        ai_peek.reported = true
        -- Baska bir dusmana gecildiyse bos peek sayisi o dusman icin bastan baslar.
        if index ~= ai_peek.enemy then
            ai_peek.fails = 0
        end
        ai_peek.mode, ai_peek.target, ai_peek.side, ai_peek.started = "go", result.spot, result.side, now
        ai_peek.enemy, ai_peek.reached, ai_peek.step, ai_peek.lost, ai_peek.faked = index, 0, result.step, 0, false
        aim_stats.ai_peeks = aim_stats.ai_peeks + 1
        ai_peek.until_time = now + 0.25 + result.step / 120
        move_to(cmd, mine, result.spot)
        if menu.shot_log:get() then
            print(("[%s] ai peek: %s %d birim -> %s (hasar %d)"):format(SCRIPT, result.side, result.step,
                player_name(enemy), floor(result.damage + 0.5)))
        end
    end
end

events.createmove:set(protect("createmove", function(cmd)
    current.defensive, current.forced, current.lc = false, false, false
    local rec, tick = recommended_state, globals.tickcount
    if rec.pending or tick < rec.tick or tick - rec.tick >= rec.every then
        apply_recommended()
    end
    if not menu.enabled:get() then
        reset_overrides()
        set_charge(true)
        return
    end

    local lp = entity.get_local_player()
    if lp == nil or not lp:is_alive() then
        set_charge(true)
        override("fakeduck", nil)
        return
    end

    local choked = cmd.choked_commands or globals.choked_commands or 0
    exposure.facing = nil
    update_tickbase(lp, choked)
    update_fd_guard(lp)
    enemy_watch.update()
    update_exposure(lp, cmd)
    local move_state = detect_movement(lp, cmd)
    local class = weapon_class(lp)
    current.weapon = class

    process_pending_misses()
    -- Anti-brute kapatilinca o anki faz da hemen birakilir.
    current.phase_group = brute.group_for(move_state)
    current.brute = menu.anti_brute:get() and threat_stage(current.phase_group) or 0
    local aim_target, resolver_raw = apply_resolver()
    apply_body_aim(lp, class, aim_target, resolver_raw)
    update_ai_peek(lp, cmd, class)

    override("aa_enabled", true)
    override("yaw", "Backward")
    override("avoid_backstab", menu.avoid_backstab:get())
    -- Freestanding sirasinda ayarlari Freestanding durumu belirler.
    override("fs_modifiers", false)
    override("fs_body", false)

    -- Merdivende yerde degiliz ama "havada" da sayilmamaliyiz; LC kirmak
    -- tirmanirken isinlanma yaptirir. Acilara Neverlose kendisi karisir.
    if lp.m_MoveType == MOVETYPE_LADDER then
        current.state = "Ladder"
        -- Merdivende hareket durumu hep "Air" cikar; yer exploit'i kullanilir.
        apply_exploit(builder["Standing"], class)
        defensive_off()
        update_recharge()
        sample_exploit(current.state)
        return
    end

    -- Legit AA ve spin'de de hareket durumunun exploit'i korunur; DT'yi kapatip
    -- acmak her seferinde yeniden sarj demek ve o arada savunmasiz kalirsin.
    if legit_use_active(lp, cmd) then
        current.state = "Legit"
        apply_exploit(builder[move_state], class)
        defensive_off()
        update_recharge()
        sample_exploit(current.state)
        apply({
            pitch = "Disabled", yaw_base = "Local View", yaw_offset = 180, modifier = "Disabled", mod_offset = 0,
            body = "Static", side = menu.inverter:get(), left = 60, right = 60,
            avoid_overlap = false, body_fs = "Off", freestand = false,
        })
        return
    end

    if spin_active() then
        current.state = "Spin"
        apply_exploit(builder[move_state], class)
        defensive_off()
        update_recharge()
        sample_exploit(current.state)
        apply({
            pitch = menu.spin_pitch:get(), yaw_base = "Local View",
            yaw_offset = globals.tickcount * menu.spin_speed:get() * 3, modifier = "Disabled", mod_offset = 0,
            body = "Off", side = false, left = 60, right = 60,
            avoid_overlap = false, body_fs = "Off", freestand = false,
        })
        return
    end

    local manual = menu.manual:get()
    local freestand = freestanding_allowed(move_state)
    local state
    if manual ~= "Off" then
        state = "Manual"
    elseif safe_head_active(lp, move_state, class) then
        state = "Safe head"
        -- Freestanding kafayi duvara cevirir; safe head ise dusmana gore sabit tutmali.
        freestand = false
    elseif freestand and freestanding_has_target() then
        state = "Freestanding"
    else
        state = move_state
    end
    current.state = state

    -- Exploit ve defensive her zaman o anki durumun kendisinden gelir.
    apply_exploit(builder[state], class)
    local exploit = exploit_active()

    local s = settings_for(state)
    update_flip(s, exploit, choked)

    local body = s.body_yaw:get()
    -- yaw_side yaw left/right secimini, side desync tarafini belirler.
    local yaw_side
    if body == "Jitter" or body == "Random" then
        yaw_side = flip.side
    else
        yaw_side = menu.inverter:get()
    end
    local side = yaw_side

    local left, right = s.left_limit:get(), s.right_limit:get()
    local phase = BRUTE_PHASES[current.brute]
    if phase ~= nil then
        if phase.invert then
            side = not side
            -- Static'te kafa desync ile birlikte doner. Jitter'da taraf zaten her
            -- pakette dondugu icin ikisini birden cevirmek hicbir sey degistirmez;
            -- sadece desync kayar, yaw eski sirasinda kalir ve cozulen desen bozulur.
            if body ~= "Jitter" and body ~= "Random" then
                yaw_side = side
            end
        end
        if phase.random then
            side = flip.rand_side
        end
        left = round(left * phase.scale)
        right = round(right * phase.scale)
    end
    local limit_cut = round(flip.limit_n * s.limit_random:get())
    left = max(0, left - limit_cut)
    right = max(0, right - limit_cut)

    local yaw_offset
    if s.yaw_mode:get() == "X-Way" then
        yaw_offset = s["way" .. (flip.step % s.ways:get() + 1)]:get()
    elseif yaw_side then
        yaw_offset = s.yaw_right:get()
    else
        yaw_offset = s.yaw_left:get()
    end
    yaw_offset = yaw_offset + round(flip.yaw_n * s.yaw_random:get())
    if phase ~= nil then
        yaw_offset = yaw_offset + phase.shift
    end

    local yaw_base = menu.yaw_base:get()
    if state == "Manual" then
        yaw_base = "Local View"
        yaw_offset = yaw_offset + MANUAL_YAW[manual]
        freestand = false
    else
        yaw_base, yaw_offset = face_target(cmd, lp, yaw_base, yaw_offset, freestand)
    end

    -- Faz 5: desync sabit, tarafi Neverlose'un body freestanding'i secer (kafa duvar tarafinda).
    -- Kendi AA'si olan ozel durumlarda (Fake duck, Safe head, Manual) uygulanmaz: V1.0 loglarinda
    -- fake duck'ta faz 5 ile kafadan vuruldun; Static + Peek Fake fake duck'in her pakette rastgele
    -- tarafini eziyordu (eski "fake duck'ta hep ayni taraf" sorunu).
    local body_fs = s.body_fs:get()
    if phase ~= nil and phase.freestand and not brute.unlearned[state] then
        body, body_fs = "Static", "Peek Fake"
    end
    apply({
        pitch = menu.pitch:get(), yaw_base = yaw_base, yaw_offset = yaw_offset,
        modifier = s.modifier:get(), mod_offset = s.mod_offset:get() + round(flip.mod_n * s.mod_random:get()),
        body = body, side = side, left = left, right = right,
        avoid_overlap = s.avoid_overlap:get(), body_fs = body_fs, freestand = freestand,
    })
    apply_defensive(cmd, builder[state], class, state,
        move_state ~= "Standing" and move_state ~= "Crouching" and move_state ~= "Fake duck")
    teleport.update(lp, move_state)
    update_recharge()
    sample_exploit(state)
end))

-------------------------------------------------------------------------------
-- Anti-bruteforce
-------------------------------------------------------------------------------

-- Log icin: o anki exploit durumu. DEF acik = defensive penceresi gercekten aktif;
-- (zorla) = Smart o tick defensive istedi. sarj bekle = Safe recharge DT sarjini
-- bekletiyor. atis = kendi son atisindan bu yana; mod = defensive modunu en son
-- degistirdigimizden bu yana (sadece yakin zamanda degistiyse yazilir).
local function exploit_status()
    local charge = api.charge ~= nil and api.charge() or nil
    local charging = type(charge) == "number" and charge < 1
    local kind, exploit
    if effective("doubletap") then
        kind = "DT"
        exploit = charging and ("DT %%%d"):format(round(max(0, charge) * 100)) or "DT dolu"
    elseif effective("hideshots") then
        kind = "HS"
        -- Sarj degeri HS'de de anlamliysa (bkz. Safe recharge) yuzde yazilir.
        exploit = (charging and recharge.hs_charges) and ("HS %%%d"):format(round(max(0, charge) * 100)) or "HS"
        -- Break LC script tarafindan acik (DEF tespiti HS'de her zaman gorunmeyebilir).
        if current.lc then
            exploit = exploit .. " LC"
        end
    else
        kind = "none"
        exploit = "DT yok"
    end
    -- Gorunen exploit'i script degil senin bind'in belirliyorsa (Auto exploit kapali,
    -- durumun exploit'i Binds, fake duck ya da Neverlose ayari reddetti). Neverlose'da
    -- DT, HS'den once gelir; DT'yi kapatamadiysak HS acik olsa da DT gorunur.
    local by_bind
    if kind == "HS" then
        by_bind = overridden.hideshots == nil
    elseif kind == "none" then
        by_bind = overridden.doubletap == nil and overridden.hideshots == nil
    else
        by_bind = overridden.doubletap == nil
    end
    if by_bind then
        exploit = exploit .. " (bind)"
    end

    local parts = {}
    -- Fake duck'ta DT/HS calismaz; "DT %0" gorunurse sebebi budur.
    if effective("fakeduck") then
        parts[#parts + 1] = "FD"
    end
    parts[#parts + 1] = exploit
    parts[#parts + 1] = (defensive_active() and "DEF acik" or "DEF yok") .. (current.forced and " (zorla)" or "")
    if recharge.held then
        parts[#parts + 1] = "sarj bekle"
    end
    local now = globals.realtime
    local shot = now - own.last_shot
    parts[#parts + 1] = (shot >= 0 and shot < 5) and ("atis %.2fs"):format(shot) or "atis yok"
    -- Havada teleport'tan bu yana (son 2 sn).
    local since_tp = now - teleport.last
    if since_tp >= 0 and since_tp < 2 then
        parts[#parts + 1] = ("tp %.2fs"):format(since_tp)
    end
    local mode = changed_at.lag_options ~= nil and now - changed_at.lag_options or nil
    if mode ~= nil and mode >= 0 and mode < 2 then
        parts[#parts + 1] = ("mod %.2fs"):format(mode)
    end
    return table.concat(parts, ", ")
end

local function aa_status()
    return ("%s %d"):format(current.side and "sag" or "sol", current.limit)
end

-- Log icin kendi silahin: "CWeaponSSG08" -> "ssg08", "CAK47" -> "ak47".
local function weapon_label()
    local class = current.weapon
    if class == nil then
        return "sen ?"
    end
    if class == "Revolver" then
        return "sen r8"
    end
    return "sen " .. class:gsub("^CWeapon", ""):gsub("^C", ""):lower()
end

do
    -- p noktasinin a -> b dogru parcasina en kisa uzakligi
    local function distance_to_segment(p, a, b)
        local abx, aby, abz = b.x - a.x, b.y - a.y, b.z - a.z
        local len_sq = abx * abx + aby * aby + abz * abz
        if len_sq == 0 then
            return huge
        end
        local t = ((p.x - a.x) * abx + (p.y - a.y) * aby + (p.z - a.z) * abz) / len_sq
        t = max(0, min(1, t))
        local dx = a.x + abx * t - p.x
        local dy = a.y + aby * t - p.y
        local dz = a.z + abz * t - p.z
        return sqrt(dx * dx + dy * dy + dz * dz)
    end

    events.bullet_impact:set(protect("bullet_impact", function(e)
        if not menu.enabled:get() then
            return
        end

        local lp = entity.get_local_player()
        if lp == nil or not lp:is_alive() then
            return
        end

        local shooter = entity.get(e.userid, true)
        if shooter == nil or not shooter:is_enemy() then
            return
        end

        local key, entry = brute_entry(shooter, "u" .. tostring(e.userid))
        local now = globals.realtime
        if entry.last ~= nil and now >= entry.last and now - entry.last < BRUTE_DEBOUNCE then
            return
        end

        local head = lp:get_hitbox_position(0)
        local eye = shooter:get_eye_position()
        if head == nil or eye == nil then
            return
        end
        if distance_to_segment(head, eye, vector(e.x, e.y, e.z)) > BRUTE_RADIUS then
            return
        end
        entry.last = now
        exposure.shot = { index = index_of(shooter), tick = globals.tickcount }
        -- Hasar olayi mermiden sonra gelirse hangi fazda vuruldugumuzu buradan biliriz.
        local shot_stage = menu.anti_brute:get() and brute_entry_stage(entry, current.phase_group) or 0
        entry.shot_stage = shot_stage
        -- O an gercekten uygulanan faz (AA'nin dondugu dusmaninki) ve hareket grubun; fazlarin
        -- istatistigi icin.
        entry.shot_applied, entry.shot_group, entry.shot_sniper = current.brute, brute.stat_group(),
            sniper.mode(current.weapon)

        -- Hasar bu mermiden once geldiyse zaten isabettir, iska adayi degildir.
        local hurt = brute.hurt[e.userid]
        if hurt == nil or now < hurt or now - hurt >= MISS_WINDOW then
            pending_misses[#pending_misses + 1] = {
                userid = e.userid, time = now, state = current.state, stage = shot_stage, name = player_name(shooter),
                aa = aa_status(), exploit = exploit_status(), weapon = weapon_label(), attacker = attacker_info(shooter),
                applied = current.brute, group = brute.stat_group(), sniper = sniper.mode(current.weapon),
            }
        end

        if not menu.anti_brute:get() then
            return
        end
        entry.stage = shot_stage % #BRUTE_PHASES + 1
        entry.time = now
        brute.recent = key
        if menu.brute_log:get() then
            print(("[%s] anti-brute: %s faz %d"):format(SCRIPT, player_name(shooter), entry.stage))
        end
    end))
end

-- Round ozeti: round boyunca sana gelen mermiler durum, faz, exploit ve gorus basina sayilir;
-- yeni round baslarken tek satir yazilir. AA'yi tahminle degil bu verilerle ayarlamak icin.
own.count = function(state, stage, head, unseen)
    local r = own.round or { hits = 0, head = 0, states = {}, order = {}, phases = {}, exploits = {}, unseen = 0 }
    own.round = r
    r.hits = r.hits + 1
    r.head = r.head + (head and 1 or 0)
    r.unseen = r.unseen + (unseen and 1 or 0)
    local st = r.states[state]
    if st == nil then
        st = { hits = 0, head = 0 }
        r.states[state], r.order[#r.order + 1] = st, state
    end
    st.hits, st.head = st.hits + 1, st.head + (head and 1 or 0)
    if head then
        r.phases[stage] = (r.phases[stage] or 0) + 1
    end
    local kind = effective("fakeduck") and "FD" or (effective("doubletap") and "DT") or (effective("hideshots") and "HS") or "yok"
    r.exploits[kind] = (r.exploits[kind] or 0) + 1
end

own.summary = function()
    local r = own.round
    own.round = nil
    if r == nil or not menu.hit_log:get() then
        return
    end
    local states = {}
    for _, state in ipairs(r.order) do
        local st = r.states[state]
        states[#states + 1] = ("%s %d/%d"):format(state, st.head, st.hits)
    end
    local phases = {}
    for phase = 0, #BRUTE_PHASES do
        if r.phases[phase] ~= nil then
            phases[#phases + 1] = ("%d:%d"):format(phase, r.phases[phase])
        end
    end
    local exploits = {}
    for _, kind in ipairs({ "DT", "HS", "FD", "yok" }) do
        if r.exploits[kind] ~= nil then
            exploits[#exploits + 1] = ("%s %d"):format(kind, r.exploits[kind])
        end
    end
    print(("[%s] round ozeti: %d mermi, %d kafa | %s | kafa fazlari %s | %s | gormedi %d"):format(SCRIPT, r.hits, r.head,
        table.concat(states, ", "), #phases > 0 and table.concat(phases, " ") or "-", table.concat(exploits, ", "), r.unseen))
end

events.player_hurt:set(protect("player_hurt", function(e)
    if not menu.enabled:get() then
        return
    end
    local lp = entity.get_local_player()
    if lp == nil or entity.get(e.userid, true) ~= lp then
        return
    end
    -- Dusme hasarinda saldiran yok; takim arkadasi hasari da sayilmaz.
    local attacker = entity.get(e.attacker, true)
    if attacker == nil or attacker == lp or not attacker:is_enemy() then
        return
    end
    -- Yangin ve bomba hasari AA ile ilgili degil; molotofun her tick'i log'u ve
    -- istatistikleri dolduruyordu. Bekleyen iskalari da iptal etmemeli.
    if NON_BULLET_DAMAGE[tostring(e.weapon)] then
        return
    end

    local now = globals.realtime
    brute.hurt[e.attacker] = now
    ai_peek.hurt(e.hitgroup, e.dmg_health, player_name(attacker))
    for i = #pending_misses, 1, -1 do
        if pending_misses[i].userid == e.attacker then
            table.remove(pending_misses, i)
        end
    end

    -- Vuruldugumuz faz: mermi olayi az once geldiyse onun kaydettigi faz (mermi
    -- AA'yi zaten ilerletti), gelmediyse su an uygulanan faz.
    local _, enemy = brute_entry(attacker, "u" .. tostring(e.attacker))
    local hit_stage, applied, group, shot_sniper = nil, nil, nil, sniper.mode(current.weapon)
    if enemy.shot_stage ~= nil and enemy.last ~= nil and now >= enemy.last and now - enemy.last < MISS_WINDOW then
        hit_stage, applied, group, shot_sniper = enemy.shot_stage, enemy.shot_applied, enemy.shot_group, enemy.shot_sniper
    else
        hit_stage = menu.anti_brute:get() and brute_entry_stage(enemy, current.phase_group) or 0
        group = brute.stat_group()
    end
    -- Bicak ve zeus yakin mesafe silahi; AA'nin saklayabilecegi bir sey degil. Log'a
    -- yazilir ama durum istatistigine ve anti-brute'a sayilmaz.
    local weapon = tostring(e.weapon or "?")
    local melee = weapon:find("knife", 1, true) ~= nil or weapon == "bayonet" or weapon == "taser"
    -- Sadece kafa isabeti resolver'in aciyi cozdugunu gosterir; govde ve bacak
    -- isabetleri baim / safe point'tir, desync onlari saklayamaz.
    if e.hitgroup == 1 and not melee and menu.anti_brute:get() then
        enemy.base, enemy.learned = (hit_stage + 1) % (#BRUTE_PHASES + 1), true
    end
    -- Fazin istatistigi de yazilir (kalici hafizayi da kirli isaretler).
    if e.hitgroup == 1 and not melee then
        record_phase(group, applied or current.brute, true)
        sniper.record(shot_sniper, true)
    end

    local info = attacker_info(attacker)
    if not melee then
        local entry = stat_for(current.state)
        entry.hits = entry.hits + 1
        if e.hitgroup == 1 then
            entry.head = entry.head + 1
        end
        own.count(current.state, hit_stage, e.hitgroup == 1, info:find("gormedi", 1, true) ~= nil)
    end
    if menu.hit_log:get() then
        print(("[%s] vuruldun: %s -%d %s | %s | faz %d | %s | %s | %s | %s (%s)"):format(
            SCRIPT, HITGROUPS[e.hitgroup] or "?", tonumber(e.dmg_health) or 0, weapon,
            current.state, hit_stage, aa_status(), exploit_status(), weapon_label(), player_name(attacker), info))
    end
end))

pcall(function()
    events.weapon_fire:set(protect("weapon_fire", function(e)
        local lp = entity.get_local_player()
        if lp ~= nil and entity.get(e.userid, true) == lp then
            own.last_shot = globals.realtime
        end
    end))
end)

local function event_number(e, name)
    local ok, value = pcall(function() return e[name] end)
    if ok and type(value) == "number" and value == value and abs(value) < huge then
        return value
    end
    return nil
end

-- Dusmanin ates anindaki AA'si: "AA jit 62" (ortalama yaw degisimi), "AA statik" ya da
-- yeterli veri yoksa "AA ?"; defensive ve LC kirma varsa eklenir.
local function profile_text(profile)
    if profile == nil then
        return "AA ?"
    end
    local parts = { profile.jitter == nil and "AA ?"
        or (profile.jitter >= 15 and ("AA jit %d"):format(round(profile.jitter)) or "AA statik") }
    if profile.defensive_now then
        parts[#parts + 1] = "def (sahte kayit)"
    elseif profile.defensive then
        parts[#parts + 1] = "def"
    end
    if profile.lc then
        parts[#parts + 1] = "LC"
    end
    return table.concat(parts, ", ")
end

-- Atis kaydi: dusman, ates anindaki durumu ve cani, aimbot'un hedefledigi bolge ve hasar,
-- sonuc, ates anindaki safe points ve body aim, backtrack, isabet sansi, senin silahin ve
-- dusmanin AA'si. ack'teki degerler varsa onlar, yoksa ates anindakiler kullanilir.
local function shot_line(e, shot, target)
    local name = target ~= nil and player_name(target) or "?"
    local state = shot ~= nil and shot.state or (target ~= nil and enemy_state(target)) or "?"
    local health = shot ~= nil and shot.health or nil
    local wanted = event_number(e, "wanted_hitgroup") or (shot and shot.hitgroup)
    local wanted_damage = event_number(e, "wanted_damage") or (shot and shot.damage) or 0
    local aimed = wanted ~= nil and ("hedef %s %d"):format(HITGROUPS[wanted] or "?", round(wanted_damage)) or "hedef ?"
    local result
    local reason = e.state
    if reason == nil then
        result = ("isabet %s -%d"):format(HITGROUPS[event_number(e, "hitgroup") or -1] or "?",
            round(event_number(e, "damage") or 0))
    else
        result = "iska " .. tostring(reason):sub(1, 32)
    end
    local safe = shot ~= nil and shot.safe or effective("safe_points")
    local body = shot ~= nil and shot.body or effective("body_aim")
    local min_damage
    if shot ~= nil then
        min_damage = shot.md
    else
        min_damage = effective("min_damage")
    end
    local backtrack = event_number(e, "backtrack") or (shot and shot.backtrack)
    local hitchance = event_number(e, "hitchance") or (shot and shot.hitchance)
    local profile
    if shot ~= nil then
        profile = shot.profile
    else
        profile = enemy_watch.profile(target)
    end
    return ("[%s] atis: %s | %s | HP %s | %s | %s | SP %s | BA %s | MD %s | bt %s | hc %s | %s | %s"):format(SCRIPT, name,
        state, type(health) == "number" and tostring(round(health)) or "?", aimed, result,
        type(safe) == "string" and safe or "?",
        type(body) == "string" and body or "?",
        type(min_damage) == "number" and tostring(round(min_damage)) or "?",
        backtrack ~= nil and ("%dt"):format(round(backtrack)) or "?",
        hitchance ~= nil and ("%d%%"):format(round(hitchance)) or "?",
        shot ~= nil and shot.weapon or weapon_label(), profile_text(profile))
end

-- aim_ack'teki hedef dokumanda entity index'i; bazi surumlerde entity'nin kendisi.
local function aim_target_entity(target)
    if type(target) == "number" then
        local ok, ent = pcall(entity.get, target)
        return ok and ent or nil
    end
    return target
end

pcall(function()
    events.aim_fire:set(protect("aim_fire", function(e)
        local target = aim_target_entity(e.target)
        if target == nil then
            return
        end
        local now = globals.realtime
        resolver.aim_target, resolver.aim_time = target, now
        -- Sonuc ~0.05-0.3 sn sonra gelir; dusman o arada inmis / egilmis olabilir.
        for id, shot in pairs(resolver.shots) do
            if now < shot.time or now - shot.time > SHOT_MEMORY then
                resolver.shots[id] = nil
            end
        end
        local state = enemy_state(target)
        ai_peek.fired(e.id, target)
        -- Atis anindaki kendi lag'imiz: TP = havada teleport'tan hemen sonra (tickbase kaydi), DEF =
        -- zorlanan DT defensive'i, LC = Hide shots Break LC, FD = fake duck. Atis satirinda silahin
        -- yanina yazilir.
        local since_tp = now - teleport.last
        local lag = (since_tp >= 0 and since_tp <= resolver.tp_window and "TP") or (current.forced and "DEF")
            or (current.lc and "LC") or (effective("fakeduck") and "FD") or nil
        if e.id ~= nil then
            resolver.shots[e.id] = { state = state, time = now, safe = effective("safe_points"),
                body = effective("body_aim"), md = effective("min_damage"), health = prop(target, "m_iHealth"),
                weapon = weapon_label() .. (lag ~= nil and " " .. lag or ""), lag = lag,
                profile = enemy_watch.profile(target),
                hitgroup = event_number(e, "hitgroup"), damage = event_number(e, "damage"),
                hitchance = event_number(e, "hitchance"), backtrack = event_number(e, "backtrack") }
        end
        local stall = resolver.stall
        if stall.key ~= nil and stall.key == player_id(target) then
            stall.visible = 0
        end
        local body = resolver.body_stall
        if body.key ~= nil and body.key == player_id(target) then
            body.visible, body.relaxed = 0, false
        end
    end))
end)

pcall(function()
    events.aim_ack:set(protect("aim_ack", function(e)
        if not menu.enabled:get() then
            return
        end
        local shot = e.id ~= nil and resolver.shots[e.id] or nil
        if shot ~= nil then
            resolver.shots[e.id] = nil
        end
        local state = e.state
        local result
        aim_stats.shots = aim_stats.shots + 1
        if state == nil then
            aim_stats.hits = aim_stats.hits + 1
            -- Kafaya nisan alinip baska yere isabet (loglarda "hedef head 110 | isabet chest
            -- -28"): mermi resolver'in kafa sandigi yerden gecip govdeye girdi, yani kafanin
            -- yeri tutmamis olabilir. Resolver'a isabet sayilmaz, seviyeyi dusurmez.
            local wanted = event_number(e, "wanted_hitgroup") or (shot and shot.hitgroup)
            local hit = event_number(e, "hitgroup")
            if (wanted == 1 or wanted == 8) and hit ~= nil and hit ~= 1 and hit ~= 8 then
                result = nil
            else
                result = "h"
            end
        elseif state == "correction" then
            -- Dusman ates aninda LC kiriyorduysa (64+ birim sicrama) eski kayit gecersizdi: bu
            -- iska resolver'in hatasi degil, safe point de duzeltmez. Ogrenilmez. Ates edilen kayit
            -- defensive kaydiysa (sahte: gordugumuz en yeni kayittan eski, acilar hidden) da ayni:
            -- v5.5 loglarinda bu iskalar Force'ta bile surdu, seviyeyi bosuna yukseltip sonraki gercek
            -- kayitlarda kafa atisini kesiyordu. Sadece o an defensive olan kayit sayilmaz (son 16
            -- tick'te defensive "def" degil: loglarda neredeyse her atista vardi).
            local profile = shot ~= nil and shot.profile or nil
            if profile ~= nil and (profile.lc or profile.defensive_now) then
                aim_stats.other = aim_stats.other + 1
            else
                aim_stats.correction = aim_stats.correction + 1
                result = "c"
            end
        elseif state == "spread" then
            aim_stats.spread = aim_stats.spread + 1
        else
            aim_stats.other = aim_stats.other + 1
        end
        local target = aim_target_entity(e.target)
        if menu.shot_log:get() then
            print(shot_line(e, shot, target))
        end
        ai_peek.result(e, target ~= nil and player_name(target) or nil)
        -- Kendi lag'imiz sirasinda (zorlanan defensive / Break LC / teleport sonrasi) atilan mermi
        -- sunucuda gecmediyse ("iska unregistered shot", "iska damage rejection"), ayni turden ikincisinde
        -- o lag unreg_pause sn durdurulur. Loglarda DEF / LC / FD / TP anlarinda boyle iskalar vardi.
        local lag = shot ~= nil and shot.lag or nil
        if (state == "unregistered shot" or state == "damage rejection") and resolver.unreg[lag] ~= nil then
            local now = globals.realtime
            local list = {}
            for _, t in ipairs(resolver.unreg[lag]) do
                if now >= t and now - t <= resolver.unreg_window then
                    list[#list + 1] = t
                end
            end
            list[#list + 1] = now
            resolver.unreg[lag] = list
            if #list >= 2 then
                resolver.unreg[lag], resolver.pause[lag] = {}, now + resolver.unreg_pause
                if menu.shot_log:get() then
                    local names = resolver.lag_names[lag]
                    print(("[%s] %s %d sn durduruldu: %s sirasinda %d atis sunucuda gecmedi (son: %s)"):format(SCRIPT,
                        names[1], resolver.unreg_pause, names[2], #list, state))
                end
            end
        end
        -- Panel icin dusman basina: aimbot'un hit chance'i, spread ve resolver disi iskalar (sunucu
        -- reddi, tahmin hatasi, LC...). "death" / "player death" atisin sucu degil, sayilmaz.
        local entry = target ~= nil and resolver_entry(target) or nil
        if entry ~= nil and state ~= "death" and state ~= "player death" then
            local hc = event_number(e, "hitchance") or (shot ~= nil and shot.hitchance) or nil
            if hc ~= nil then
                entry.hc_sum, entry.hc_n = (entry.hc_sum or 0) + hc, (entry.hc_n or 0) + 1
            end
            entry.shots = (entry.shots or 0) + 1
            if state == "spread" then
                entry.spread = (entry.spread or 0) + 1
            elseif state ~= nil and result == nil then
                entry.other = (entry.other or 0) + 1
            end
        end
        if result == nil or entry == nil or not menu.resolver:get() then
            return
        end
        local enemy = shot ~= nil and shot.state or enemy_state(target)
        local before = entry_level(entry, enemy)
        -- Panel icin toplam: resolver'a bagli isabet / correction iskasi.
        if result == "h" then
            entry.hits = (entry.hits or 0) + 1
        else
            entry.misses = (entry.misses or 0) + 1
        end
        window_push(entry.results, result)
        entry.states[enemy] = entry.states[enemy] or {}
        window_push(entry.states[enemy], result)
        persist.dirty = true
        local level = entry_level(entry, enemy)
        local stall = resolver.stall
        if stall.key == player_id(target) and stall.state == enemy then
            reset_stall(stall.key, stall.state)
        end
        if menu.resolver_log:get() and level ~= before then
            local what = result == "c" and "iska (correction)"
                or ("isabet %s -%d"):format(HITGROUPS[e.hitgroup] or "?", tonumber(e.damage) or 0)
            print(("[%s] resolver: %s %s %s | seviye %d -> safe points %s"):format(
                SCRIPT, entry.name, enemy, what, level, SAFE_POINT_LEVELS[level]))
        end
    end))
end)

-- Round / olum sonrasi aktif fazlar biter, ogrenilen kalici fazlar kalir.
local function reset_brute()
    for _, entry in pairs(brute.enemies) do
        entry.stage, entry.time, entry.last, entry.shot_stage = 0, 0, nil, nil
    end
    brute.recent, brute.hurt = nil, {}
end

-- Kalici hafiza: HvH sunucularinda ayni oyuncularla tekrar tekrar karsilasilir. Steam ID'si
-- olan oyuncularin kalici anti-brute fazi ve resolver sonuclari db'ye yazilir (isimle
-- tutulan botlar ve Steam ID'siz oyuncular yazilmaz; isim degisebilir). db okumak ve yazmak
-- agir: script yuklenirken bir kez okunur; round basinda en fazla dakikada bir, harita
-- degisirken ve script kapanirken yazilir.
local function steam_key(key)
    return type(key) == "string" and key:sub(1, 2) == "s:"
end

persist.save = function(force)
    local now = globals.realtime
    if not persist.dirty or (not force and now >= persist.saved and now - persist.saved < persist.every) then
        return
    end
    local data = { version = 1, brute = {}, resolver = {}, phase_groups = {},
        sniper = { hs = { shots = sniper.stats.hs.shots, hits = sniper.stats.hs.hits },
            dt = { shots = sniper.stats.dt.shots, hits = sniper.stats.dt.hits } } }
    for key, entry in pairs(brute.enemies) do
        if steam_key(key) and entry.learned then
            data.brute[key] = { base = entry.base, name = entry.name }
        end
    end
    -- Fazlarin istatistigi grup basina 1'den baslayan liste olarak (faz 0 -> 1. eleman).
    for _, group in ipairs(brute.groups) do
        local list = {}
        for phase = 0, #BRUTE_PHASES do
            local stat = brute.phases[group][phase]
            list[phase + 1] = { shots = stat.shots, hits = stat.hits }
        end
        data.phase_groups[group] = list
    end
    -- Kopya yazilir: listeler sonradan degistiginde kayit da degismesin.
    local function copy(list)
        local out = {}
        for i, v in ipairs(list) do
            out[i] = v
        end
        return out
    end
    for key, entry in pairs(resolver.players) do
        if steam_key(key) and #entry.results > 0 then
            local states = {}
            for state, list in pairs(entry.states) do
                states[state] = copy(list)
            end
            data.resolver[key] = { name = entry.name, results = copy(entry.results), states = states,
                hits = entry.hits, misses = entry.misses }
        end
    end
    persist.saved = now
    if pcall(function() db[persist.key] = data end) then
        persist.dirty = false
    end
end

-- Kayitli sonuc listesinden son RESOLVER_WINDOW gecerli sonuc.
local function stored_window(list)
    local out = {}
    if type(list) == "table" then
        for i = max(1, #list - RESOLVER_WINDOW + 1), #list do
            if list[i] == "c" or list[i] == "h" then
                out[#out + 1] = list[i]
            end
        end
    end
    return out
end

-- Kac oyuncu yuklendigini dondurur. Bozuk ya da eski bicimli kayitlar atlanir. Yuklenenler
-- bu oturumda hic gorulmemis sayilir (seen = 0): bellek dolarsa ilk onlar unutulur.
persist.load = function()
    local ok, data = pcall(function() return db[persist.key] end)
    if not ok or type(data) ~= "table" or data.version ~= 1 then
        return 0
    end
    local players, count = {}, 0
    local function add(key)
        if not players[key] then
            players[key], count = true, count + 1
        end
    end
    if type(data.brute) == "table" then
        for key, e in pairs(data.brute) do
            if count < MEMORY_LIMIT and steam_key(key) and type(e) == "table" and type(e.base) == "number"
                and e.base >= 0 and e.base <= #BRUTE_PHASES and e.base == floor(e.base) then
                brute.enemies[key] = { stage = 0, time = 0, base = e.base, learned = true, name = tostring(e.name or "?"),
                    seen = 0 }
                add(key)
            end
        end
    end
    if type(data.sniper) == "table" then
        for _, mode in ipairs({ "hs", "dt" }) do
            local e = data.sniper[mode]
            if type(e) == "table" and type(e.shots) == "number" and type(e.hits) == "number"
                and e.hits >= 0 and e.hits <= e.shots and e.shots <= 1000 then
                sniper.stats[mode] = { shots = e.shots, hits = e.hits }
            end
        end
        sniper.choice = "hs"
        sniper.choice = sniper.decide()
    end
    -- v4.5 butun gruplar icin tek liste yaziyordu ("phases"); o liste her gruba uygulanir.
    for _, group in ipairs(brute.groups) do
        local groups = type(data.phase_groups) == "table" and data.phase_groups or nil
        local list = groups ~= nil and (groups[group] or groups[brute.migrate[group]]) or data.phases
        if type(list) == "table" then
            for phase = 0, #BRUTE_PHASES do
                local e = list[phase + 1]
                if type(e) == "table" and type(e.shots) == "number" and type(e.hits) == "number"
                    and e.hits >= 0 and e.hits <= e.shots and e.shots <= 1000 then
                    brute.phases[group][phase] = { shots = e.shots, hits = e.hits }
                end
            end
            brute.default[group] = 0
            brute.default[group] = brute_default(group)
        end
    end
    if type(data.resolver) == "table" then
        for key, e in pairs(data.resolver) do
            if (players[key] or count < MEMORY_LIMIT) and steam_key(key) and type(e) == "table" then
                local entry = { results = stored_window(e.results), states = {}, name = tostring(e.name or "?"), seen = 0 }
                -- Panel icin toplamlar (v5.5); gecersizse sayilmaz.
                for _, field in ipairs({ "hits", "misses" }) do
                    local n = e[field]
                    if type(n) == "number" and n >= 0 and n <= 100000 then
                        entry[field] = floor(n)
                    end
                end
                if type(e.states) == "table" then
                    for _, state in ipairs({ "Standing", "Moving", "Crouch", "Air", "Fakeduck" }) do
                        local list = stored_window(e.states[state])
                        if #list > 0 then
                            entry.states[state] = list
                        end
                    end
                end
                if #entry.results > 0 then
                    resolver.players[key] = entry
                    add(key)
                end
            end
        end
    end
    return count
end

forget_enemies = function()
    brute.enemies, brute.recent, brute.hurt = {}, nil, {}
    brute.reset_phases()
    sniper.stats = { hs = { shots = 0, hits = 0 }, dt = { shots = 0, hits = 0 } }
    sniper.choice = "hs"
    resolver.players, resolver.shots, resolver.aim_target, resolver.prior_logged = {}, {}, nil, {}
    resolver.jittery = {}
    reset_stall(nil, nil)
    pending_misses = {}
    pcall(function() db[persist.key] = nil end)
    persist.dirty = false
end

events.round_start:set(protect("round_start", function()
    own.summary()
    reset_brute()
    exposure.shot = nil
    ai_peek.reset()
    pending_misses = {}
    set_charge(true)
    persist.save(false)
end))

-- Harita degisince slot numaralari degisir, oyuncular cogunlukla kalir. Aktif fazlar,
-- bekleyen atislar ve hedef sifirlanir; Steam ID ile ogrenilenler (anti-brute fazi,
-- resolver seviyeleri) korunur.
pcall(function()
    events.level_init:set(protect("level_init", function()
        reset_brute()
        pending_misses = {}
        resolver.shots, resolver.aim_target, resolver.prior_logged, resolver.jittery = {}, nil, {}, {}
        reset_stall(nil, nil)
        exposure.shot = nil
        ai_peek.reset()
        -- HS ile teleport'un calisip calismadigi her haritada bir kez yeniden denenir.
        teleport.hs_ok, teleport.pending = nil, nil
        enemy_watch.list = {}
        persist.save(true)
    end))
end)

events.player_death:set(protect("player_death", function(e)
    local lp = entity.get_local_player()
    if lp ~= nil and entity.get(e.userid, true) == lp then
        reset_brute()
        set_charge(true)
        ai_peek.reset()
    end
end))

-------------------------------------------------------------------------------
-- Indikatorler
-------------------------------------------------------------------------------

local WHITE = color(255, 255, 255, 255)
local DIM = color(255, 255, 255, 90)
local CHARGING = color(255, 200, 80, 255)
local SHADOW = color(0, 0, 0, 150)
local FONT = 2

-- scope: durbun animasyonu; labels: resolver durumu kisaltmalari; failed: cizimi hata veren parcalar;
-- panel: resolver paneli (bkz. menu.res_panel).
local anim = { scope = 0, failed = {},
    labels = { Standing = "STAND", Moving = "MOVE", Crouch = "DUCK", Air = "AIR", Fakeduck = "FD" } }

local function text_width(text)
    local ok, size = pcall(render.measure_text, FONT, nil, text)
    if ok and size ~= nil then
        return size.x
    end
    return #text * 5
end

local function draw_indicators(lp, cx, cy)
    local accent = menu.accent:get()
    local target = lp.m_bIsScoped and 1 or 0
    anim.scope = anim.scope + (target - anim.scope) * min(1, (globals.frametime or 0.016) * 12)

    local x = cx + round(anim.scope * 34)
    local y = cy + 22
    render.text(FONT, vector(x, y), accent, "c", SCRIPT)

    y = y + 8
    local width = 36
    local fill = round(width * current.limit / 60)
    render.rect(vector(x - width / 2 - 1, y - 1), vector(x + width / 2 + 1, y + 3), SHADOW)
    if fill > 0 then
        render.rect(vector(x - width / 2, y), vector(x - width / 2 + fill, y + 2), accent)
    end

    y = y + 9
    render.text(FONT, vector(x, y), WHITE, "c", current.state:upper())

    y = y + 9
    -- DT / HS: beyaz = sarjli, turuncu = sarj oluyor (ya da Safe recharge bekletiyor).
    -- DEF: renkli = pencere su an acik, beyaz = defensive zorlaniyor / surekli acik,
    -- soluk = Neverlose'un peek tespitine birakildi.
    local dt_color = DIM
    if effective("doubletap") then
        local charge = api.charge ~= nil and api.charge() or nil
        dt_color = (type(charge) ~= "number" or charge >= 1) and WHITE or CHARGING
    end
    local hs_color = DIM
    if effective("hideshots") then
        local charge = api.charge ~= nil and api.charge() or nil
        hs_color = (recharge.hs_charges and type(charge) == "number" and charge < 1) and CHARGING or WHITE
    end
    local def_color = DIM
    if defensive_active() then
        def_color = accent
    elseif current.defensive then
        def_color = WHITE
    end
    local items = {
        { "DT", dt_color },
        { "HS", hs_color },
        { "FS", current.freestand and WHITE or DIM },
        { "DEF", def_color },
    }
    -- VIS: renkli = tehdit ya da baska bir dusman kafani su an goruyor, beyaz = tehdit
    -- birazdan gorecek.
    if exposure.available then
        local vis_color = DIM
        if exposure.now or exposure.any then
            vis_color = accent
        elseif exposure.soon then
            vis_color = WHITE
        end
        items[#items + 1] = { "VIS", vis_color }
    end
    local gap, total = 5, -5
    for _, item in ipairs(items) do
        item.w = text_width(item[1])
        total = total + item.w + gap
    end
    local px = x - total / 2
    for _, item in ipairs(items) do
        render.text(FONT, vector(px + item.w / 2, y), item[2], "c", item[1])
        px = px + item.w + gap
    end

    if current.brute > 0 then
        y = y + 9
        render.text(FONT, vector(x, y), accent, "c", ("BRUTE %d"):format(current.brute))
    end
    -- Hedefe karsi resolver seviyesi (1 = safe points Prefer, 2 = Force) ve neden: dusmanin
    -- hangi durumunda yanildigi ya da JIT = jitter'li AA icin on bilgi.
    if current.resolver > 0 then
        y = y + 9
        local why = current.res_prior and "JIT" or (anim.labels[current.res_state] or "")
        render.text(FONT, vector(x, y), accent, "c", ("RES %d %s"):format(current.resolver, why))
    end
    -- BAIM: hedefin cani govde vurusuna yetiyor (Body Aim Prefer / Force). HEAD: sadece
    -- oldurecek atis (tam canli dusmanda kafa), govde vurusu yok.
    if current.lethal then
        y = y + 9
        render.text(FONT, vector(x, y), accent, "c", "BAIM")
    elseif current.head_only then
        y = y + 9
        render.text(FONT, vector(x, y), accent, "c", "HEAD")
    end
    -- AI PEEK: script bir peek noktasina yuruyor ya da orada aimbot'u bekliyor.
    if ai_peek.mode == "go" or ai_peek.mode == "hold" then
        y = y + 9
        render.text(FONT, vector(x, y), accent, "c", "AI PEEK")
    end
end

local STAT_ORDER = {}
for _, state in ipairs(STATES) do
    STAT_ORDER[#STAT_ORDER + 1] = state
end
for _, state in ipairs({ "Legit", "Spin", "Ladder" }) do
    STAT_ORDER[#STAT_ORDER + 1] = state
end

-- Sol tarafta: her durumda kac kez vuruldun, kaci kafa, kac mermi kafanin yanindan
-- gecti ve sen ates etmezken DT'nin yuzde kac dolu oldugu.
local function draw_stats(screen)
    local x, y = 12, floor(screen.y * 0.45)
    render.text(FONT, vector(x, y), menu.accent:get(), nil, "AA STATS   HIT / HEAD / MISS / DT / DEF")
    for _, state in ipairs(STAT_ORDER) do
        local entry = stats[state]
        if entry ~= nil then
            y = y + 10
            local dt = entry.dt_ticks > 0 and ("%d%%"):format(floor(100 * entry.dt_full / entry.dt_ticks)) or "-"
            local def = entry.def_ticks > 0 and ("%d%%"):format(floor(100 * entry.def_on / entry.def_ticks)) or "-"
            render.text(FONT, vector(x, y), WHITE, nil,
                ("%s   %d / %d / %d / %s / %s"):format(state:upper(), entry.hits, entry.head, entry.misses, dt, def))
        end
    end
    -- Senin aimbot atislarin: CORR = resolver iskasi, SPREAD = isabet sansi / sekme,
    -- OTHER = tahmin hatasi, backtrack, kayitsiz atis vb.
    if aim_stats.shots > 0 then
        y = y + 16
        render.text(FONT, vector(x, y), menu.accent:get(), nil, "AIM   SHOT / HIT / CORR / SPREAD / OTHER")
        y = y + 10
        render.text(FONT, vector(x, y), WHITE, nil, ("ALL   %d / %d / %d / %d / %d"):format(
            aim_stats.shots, aim_stats.hits, aim_stats.correction, aim_stats.spread, aim_stats.other))
    end
    -- AI peek: kac peek, kacinda atis, kac isabet, kac atissiz bitti, kacinda vuruldun.
    if aim_stats.ai_peeks > 0 then
        y = y + 16
        render.text(FONT, vector(x, y), menu.accent:get(), nil, "AI PEEK   PEEK / ATIS / ISABET / BOS / VURULDUN")
        y = y + 10
        render.text(FONT, vector(x, y), WHITE, nil, ("AI PEEK   %d / %d / %d / %d / %d"):format(aim_stats.ai_peeks,
            aim_stats.ai_shots, aim_stats.ai_hits, aim_stats.ai_empty, aim_stats.ai_hurt))
    end
    -- Anti-brute fazlari, hareket grubu basina: kafana gelen mermilerden kac tanesi kafadan
    -- isabet etti (isabet / mermi); * = verisi olmayan dusmanlara uygulanan, en az vurulan faz.
    y = y + 16
    render.text(FONT, vector(x, y), menu.accent:get(), nil, "AA FAZ   KAFA ISABETI / MERMI")
    for _, group in ipairs(brute.groups) do
        local parts = { brute.group_label[group]:upper() }
        for phase = 0, #BRUTE_PHASES do
            local stat = brute.phases[group][phase]
            parts[#parts + 1] = ("%d%s %d/%d"):format(phase, phase == brute.default[group] and "*" or "",
                floor(stat.hits + 0.5), floor(stat.shots + 0.5))
        end
        y = y + 10
        render.text(FONT, vector(x, y), WHITE, nil, table.concat(parts, "   "))
    end
    -- Sniper exploit'i: kafana gelen mermilerden kafadan isabet / mermi; * = secilen.
    local hs, dt = sniper.stats.hs, sniper.stats.dt
    y = y + 10
    render.text(FONT, vector(x, y), WHITE, nil, ("SNIPER   HS%s %d/%d   DT%s %d/%d"):format(
        sniper.choice == "hs" and "*" or "", floor(hs.hits + 0.5), floor(hs.shots + 0.5),
        sniper.choice == "dt" and "*" or "", floor(dt.hits + 0.5), floor(dt.shots + 0.5)))
end

local function draw_arrows(cx, cy)
    local col = menu.arrow_color:get()
    local off = color(col.r, col.g, col.b, 60)
    local manual = menu.manual:get()
    render.poly(manual == "Left" and col or off, vector(cx - 55, cy), vector(cx - 42, cy - 9), vector(cx - 42, cy + 9))
    render.poly(manual == "Right" and col or off, vector(cx + 55, cy), vector(cx + 42, cy - 9), vector(cx + 42, cy + 9))
    if manual == "Forward" then
        render.poly(col, vector(cx, cy - 55), vector(cx - 9, cy - 42), vector(cx + 9, cy - 42))
    end
    -- Desync tarafi
    render.rect(vector(cx - 40, cy - 9), vector(cx - 38, cy + 9), current.side and col or off)
    render.rect(vector(cx + 38, cy - 9), vector(cx + 40, cy + 9), current.side and off or col)
end

-- Bir cizim fonksiyonu hata verirse her karede konsolu doldurmasin diye kapatilir.
-- Resolver paneli (bkz. menu.res_panel). drag: { mode = "move" | "size", ... } fareyle tutulurken.
anim.panel = { drag = nil, was_down = false, x = 0, y = 0, w = 0, h = 0, size = 100, shown = 0, shown_index = nil,
    SHADOW = color(0, 0, 0, 170), INFO = color(225, 225, 230, 200),
    LOW = color(235, 80, 80, 255), MID = color(245, 200, 85, 255), HIGH = color(110, 225, 130, 255) }
do
    local res_panel = anim.panel

    -- Yuzdeye gore renk: kirmizi (0) -> sari (50) -> yesil (100).
    res_panel.tint = function(pct)
        local t = max(0, min(1, pct / 100))
        local a, b = res_panel.MID, res_panel.HIGH
        if t < 0.5 then
            a, b, t = res_panel.LOW, res_panel.MID, t * 2
        else
            t = (t - 0.5) * 2
        end
        return color(floor(a.r + (b.r - a.r) * t), floor(a.g + (b.g - a.g) * t), floor(a.b + (b.b - a.b) * t), 255)
    end

    -- Siradaki atisin tahmini isabet sansi (%): aimbot'un bu dusmana ortalama hit chance'i
    -- (spread'le iskalamama; veri yoksa 1) x cozum (0-1) x resolver disi iskalarin (sunucu reddi,
    -- tahmin hatasi) olmama orani.
    res_panel.hit_chance = function(entry, resolve)
        local hc = entry ~= nil and (entry.hc_n or 0) > 0 and entry.hc_sum / entry.hc_n / 100 or 1
        local shots = entry ~= nil and entry.shots or 0
        local clean = shots > 0 and 1 - (entry.other or 0) / shots or 1
        return floor(max(0, min(1, hc)) * resolve * max(0, clean) * 100 + 0.5)
    end

    -- Canli cozum tahmini (%): bu dusmana gecmis resolver sonuclari (veri yoksa 0.6 on bilgi,
    -- Laplace) x su anki durumu. Kaydi sahte (defensive) x0.25, LC kiriyor x0.5, jitter
    -- (ortalama yaw degisimi) arttikca dusuk (120 derecede x0.6), havada / fake duck x0.8, uzakta
    -- (1500+ / 2500+) x0.85 / x0.75; safe point "Prefer" / "Force" kesinligi biraz arttirir.
    -- Neverlose'un kendi resolver'inin icini gostermez (Lua'ya acik degil); bizim gorduklerimizden
    -- tahmin. Her tick degisir.
    res_panel.live = function(target)
        local key = player_id(target)
        local entry = key ~= nil and resolver.players[key] or nil
        local hits, misses = entry ~= nil and entry.hits or 0, entry ~= nil and entry.misses or 0
        local value = (hits + 1.2) / (hits + misses + 2)
        local profile = enemy_watch.profile(target)
        if profile ~= nil then
            if profile.defensive_now then
                value = value * 0.25
            end
            if profile.lc then
                value = value * 0.5
            end
            if profile.jitter ~= nil then
                value = value * (1 - min(profile.jitter, 120) / 300)
            end
        end
        local state = enemy_state(target)
        if state == "Air" or state == "Fakeduck" then
            value = value * 0.8
        end
        local far = resolver.distance(target)
        if far ~= nil and far >= 2500 then
            value = value * 0.75
        elseif far ~= nil and far >= 1500 then
            value = value * 0.85
        end
        local level = entry ~= nil and entry_level(entry, state) or 0
        value = value * (1 + 0.05 * level)
        return max(0, min(100, value * 100)), entry
    end

    res_panel.width_of = function(font, text)
        local ok, size = pcall(render.measure_text, font, nil, text)
        return ok and size ~= nil and size.x or #text * 6
    end

    -- Fare: menu acikken panelin icine basip surukle (tasir), sag alt kosedeki tutamaci surukle
    -- (boyut). Birakinca slider'lara yazilir. Menu acik mi dondurur.
    res_panel.input = function(screen)
        local ok_alpha, alpha = pcall(ui.get_alpha)
        local open = ok_alpha and type(alpha) == "number" and alpha > 0
        local ok_down, down = pcall(common.is_button_down, 0x01)
        down = ok_down and down == true
        local ok_mouse, mouse = pcall(ui.get_mouse_position)
        if not open or not ok_mouse or mouse == nil then
            if res_panel.drag ~= nil then
                res_panel.save(screen)
            end
            res_panel.drag, res_panel.was_down = nil, down
            return open
        end
        local x, y, w, h = res_panel.x, res_panel.y, res_panel.w, res_panel.h
        local grip = 12 * res_panel.size / 100
        if down and not res_panel.was_down then
            if mouse.x >= x + w - grip and mouse.x <= x + w and mouse.y >= y + h - grip and mouse.y <= y + h then
                res_panel.drag = { mode = "size", mx = mouse.x, size = res_panel.size, w = max(1, w) }
            elseif mouse.x >= x and mouse.x <= x + w and mouse.y >= y and mouse.y <= y + h then
                res_panel.drag = { mode = "move", dx = mouse.x - x, dy = mouse.y - y }
            end
        elseif not down and res_panel.drag ~= nil then
            res_panel.save(screen)
            res_panel.drag = nil
        end
        local d = res_panel.drag
        if down and d ~= nil and d.mode == "move" then
            res_panel.x = max(0, min(screen.x - w, mouse.x - d.dx))
            res_panel.y = max(0, min(screen.y - h, mouse.y - d.dy))
        elseif down and d ~= nil then
            res_panel.size = max(70, min(200, round(d.size * (d.w + mouse.x - d.mx) / d.w)))
        end
        res_panel.was_down = down
        return open
    end

    res_panel.save = function(screen)
        pcall(function()
            menu.panel_x:set(round(res_panel.x / max(1, screen.x) * 1000))
            menu.panel_y:set(round(res_panel.y / max(1, screen.y) * 1000))
            menu.panel_size:set(res_panel.size)
        end)
    end

    -- Font: Verdana, kenarlari yumusak (yuklenemezse Neverlose'un yerlesik fontu). Boyuta gore
    -- bir kez yuklenir.
    res_panel.fonts = {}
    res_panel.font_of = function(size)
        local font = res_panel.fonts[size]
        if font == nil then
            local ok, loaded = pcall(render.load_font, "Verdana", size, "a")
            font = ok and loaded ~= nil and loaded or 1
            res_panel.fonts[size] = font
        end
        return font
    end

    -- Golgeli yazi (arka plan yok, her zeminde okunur).
    res_panel.shadow_text = function(font, x, y, col, text)
        render.text(font, vector(x + 1, y + 1), res_panel.SHADOW, nil, text)
        render.text(font, vector(x, y), col, nil, text)
    end

    -- Sadece yazi: hedefin canli cozum yuzdesi (buyuk, renkli) ve adi; altinda kucuk: canli
    -- isabet sansi ve resolver'a bagli isabet / atis. Sayi hedefe dogru yumusakca kayar.
    res_panel.draw = function(screen)
        -- Surukleme yokken yer ve boyut slider'lardan (menuden de ayarlanabilir).
        if res_panel.drag == nil then
            res_panel.size = menu.panel_size:get()
            res_panel.x = floor(menu.panel_x:get() / 1000 * screen.x)
            res_panel.y = floor(menu.panel_y:get() / 1000 * screen.y)
        end
        local k = res_panel.size / 100
        local big, small = res_panel.font_of(floor(22 * k + 0.5)), res_panel.font_of(floor(12 * k + 0.5))
        local target = resolver_target()
        local ok_alive, alive = pcall(function() return target ~= nil and target:is_alive() end)
        target = ok_alive and alive and target or nil

        local main, name, info, col
        if target ~= nil then
            local live, entry = res_panel.live(target)
            local index = index_of(target)
            if res_panel.shown_index ~= index then
                res_panel.shown_index, res_panel.shown = index, live
            end
            local dt = max(0, min(1, (globals.frametime or 0.016) * 8))
            res_panel.shown = res_panel.shown + (live - res_panel.shown) * dt
            local hit = res_panel.hit_chance(entry, res_panel.shown / 100)
            local hits, misses = entry ~= nil and entry.hits or 0, entry ~= nil and entry.misses or 0
            main = ("%d%%"):format(floor(res_panel.shown + 0.5))
            col = res_panel.tint(res_panel.shown)
            name = player_name(target)
            name = #name > 16 and name:sub(1, 15) .. "." or name
            info = ("COZUM   HIT %d%%   %d/%d"):format(hit, hits, hits + misses)
        else
            res_panel.shown_index = nil
            main, name, info, col = "--", "", "COZUM   hedef yok", DIM
        end

        local big_w = res_panel.width_of(big, main)
        local gap = floor(8 * k)
        local line1_h = floor(24 * k)
        local w = max(big_w + gap + res_panel.width_of(big, name), res_panel.width_of(small, info))
        local h = line1_h + floor(15 * k)
        -- Tutma alani yazinin cevresindeki cerceveyle ayni; tutamac sag alt kosesinde.
        res_panel.w, res_panel.h = w + 4, h + 3
        local open = res_panel.input(screen)
        local x, y = res_panel.x, res_panel.y

        res_panel.shadow_text(big, x, y, col, main)
        if name ~= "" then
            res_panel.shadow_text(big, x + big_w + gap, y, WHITE, name)
        end
        res_panel.shadow_text(small, x, y + line1_h, res_panel.INFO, info)

        -- Menu acikken: tasinabilir oldugu belli olsun, sag altta boyut tutamaci.
        if open then
            local accent = menu.accent:get()
            if not pcall(render.rect_outline, vector(x - 4, y - 3), vector(x + w + 4, y + h + 3),
                color(accent.r, accent.g, accent.b, 90), 1, 4) then
                render.rect(vector(x - 4, y + h + 2), vector(x + w + 4, y + h + 3), accent)
            end
            local g = floor(10 * k)
            render.poly(color(accent.r, accent.g, accent.b, 160), vector(x + w + 4, y + h + 3 - g),
                vector(x + w + 4, y + h + 3), vector(x + w + 4 - g, y + h + 3))
        end
    end
end

local function safe_draw(name, fn, ...)
    if anim.failed[name] then
        return
    end
    local ok, err = pcall(fn, ...)
    if not ok then
        anim.failed[name] = true
        print(("[%s] %s cizilemedi: %s"):format(SCRIPT, name, tostring(err)))
    end
end

events.render:set(protect("render", function()
    if not menu.enabled:get() then
        return
    end

    local screen = render.screen_size()
    -- Istatistikler olunce de gorunsun; olmek tam da bakmak istedigin an.
    if menu.stats_panel:get() then
        safe_draw("stats", draw_stats, screen)
    end
    if menu.res_panel:get() then
        safe_draw("resolver panel", anim.panel.draw, screen)
    end

    local lp = entity.get_local_player()
    if lp == nil or not lp:is_alive() then
        return
    end

    local cx, cy = floor(screen.x / 2), floor(screen.y / 2)
    if menu.indicators:get() then
        safe_draw("indicators", draw_indicators, lp, cx, cy)
    end
    if menu.arrows:get() then
        safe_draw("arrows", draw_arrows, cx, cy)
    end
end))

-- Panel surukleniyorken fare tiklamasi menuye / oyuna gecmesin.
pcall(function()
    events.mouse_input:set(function()
        if anim.panel.drag ~= nil then
            return false
        end
    end)
end)

events.shutdown:set(protect("shutdown", function()
    reset_overrides()
    set_charge(true)
    persist.save(true)
end))

-- Kalici hafiza yuklenir; kac oyuncu hatirlandigi surum satirina eklenir.
do
    local loaded = persist.load()
    print(("[%s] V%s yuklendi%s"):format(SCRIPT, VERSION,
        loaded > 0 and (" (hafiza: %d oyuncu)"):format(loaded) or ""))
end
