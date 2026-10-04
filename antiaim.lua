--[[
    ANT-A-M v4  |  Neverlose (CS:GO) icin HvH anti-aim, exploit ve resolver lua'si

    Kurar kurmaz calisir: butun varsayilanlar ayarlanmis halde gelir.

    Neler var
      - 13 durumlu builder: Global, Standing, Moving, Slow walk, Crouching,
        Crouch move, Peek, Air, Air crouch, Fake duck + ozel durumlar Manual,
        Freestanding, Safe head. Her durum kendi ayarlariyla gelir
        ("Override" kapatilirsa o durum Global'in AA ayarlarini kullanir).
      - Duruma ozel exploit: her durumda DT / HS secimi, defensive modu
        (Off / On peek / Smart / Always on / Tick based) ve hidden pitch / yaw.
        Hareket ederken ve havadayken "Smart": Neverlose'un "On Peek"ine ek olarak
        tehdit kafani gormeye baslayinca (ya da 0.2 sn icinde gorecekse) defensive
        zorlanir. Hide shots acikken hareket ettigin surece Break LC (anti-backtrack:
        dusman eski kaydini vuramaz). Scout / AWP / R8'de "Auto (learn)": Hide shots
        ile Double tap arasindan kafana daha az mermi yedigin secilir.
      - Safe recharge: exploit atistan ya da fake duck'tan sonra sarj olurken yerinde
        donarsin; tehdit seni goruyorken sarj bekletilir, siperin arkasinda dolar.
      - Adaptive resolver: Neverlose'un resolver'i bir dusmanda acida yanildikca
        ("correction" iskasi) sadece o dusmana ve o dusmanin hareket durumuna
        (yerde / yururken / egilirken / havada) karsi safe point'i yukseltir.
        Her aimbot atisi konsola tek satir yazilir. Dusmanlarin defensive / LC kirma ve
        jitter'i izlenir: defensive'deki iskalar resolver'a sayilmaz, jitter'li AA'ya
        ilk atistan safe point "Prefer".
      - Smart body aim: govde olduruyorsa (tek mermi ya da DT ile iki) govde; scout /
        AWP / R8'de govde oldurmuyorsa sadece kafa (Min. Damage = dusmanin cani, en
        fazla 100: govdeye atis acilmaz); resolver bir dusmanda iki kez yanildiysa
        (DT'li silahlarda) govde.
      - Bicak / zeus tutan dusman yaklasinca fake duck birakilir.
      - Onerilen ayarlar oyun sirasinda da korunur (eski config degerleri geri alinir).
      - Ogrenilen anti-brute fazlari ve resolver seviyeleri Steam ID ile tutulur;
        harita degisince ve oyun yeniden acilinca da kalir (Neverlose db, en fazla
        64 oyuncu).
      - L/R yaw, rage.antiaim:inverter ile desync tarafina senkron jitter yapar.
        Taraf her paket dongusunde cevrilir; gecikme sadece DT/HS aktifken
        uygulanir (fakelag'da her paket zaten cok tick surer). Istersen L&R
        yerine 3-5 aci arasinda donen X-Way yaw.
      - Gorus tespiti (utils.trace_bullet): tehdit kafana mermi gecirebiliyor mu,
        simdi ve 0.2 sn sonra; ayrica diger dusmanlar sirayla (ikiser) kontrol edilir.
      - Akilli AA hedefi: az once kafana ates eden dusmana (1 sn), Neverlose'un tehdidi
        yoksa en yakin dusmana, tehdit gormuyor ama yandan biri goruyorsa ona gore
        donulur. Yerinde dururken otomatik freestanding.
        Hareket ederken gorus alanina girince otomatik
        Peek durumu; safe head sadece kafa gercekten gorunurken; freestanding
        kafayi saklayamadiysa normal jitter'a donus.
      - Yaw / modifier / limit rastgeleligi; rastgele deger her flip'te bir kez
        secilir, boylece bir paket icinde aci sabit kalir. Body yaw "Random": desync
        tarafi her pakette rastgele (fake duck ve safe head'de varsayilan).
      - Durum gecislerinde histerezis ve inis toleransi (titreme yok).
      - Vuruldum / iska kaydi (konsol) ve durum basina istatistik paneli: hangi
        durumda vuruldugunu gorup o durumu ayarlarsin.
      - Kendi kendine ogrenen AA: her anti-brute fazinda kafana gelen mermiler yerde /
        hareket / havada ayri sayilir, verisi olmayan dusmanlar o grupta en az vurulan
        fazla baslar (faz 4: yaw'dan bagimsiz rastgele desync tarafi).
      - Mermi izine gore, dusman basina anti-bruteforce, safe head (bicak/zeus, yuksek zemin),
        freestanding (hedef varsa) + devre disi kosullari, manuel yaw,
        avoid backstab, use'a basinca legit AA, warmup / dusman yokken spin.
      - Kapatinca ya da kaldirinca butun Neverlose ayarlarini geri verir.
        Bulunamayan menu yolu ya da API olursa cokmez, o ozelligi atlar. Bir olay
        fonksiyonu hata verirse hata bir kez konsola yazilir, script calismaya devam eder.

    Kurulum ve ayar tavsiyeleri icin README.md'ye bak.
]]

local SCRIPT = "ANT-A-M"
-- Her guncellemede artar; yuklenince konsola yazilir ki hangi surumun calistigi belli olsun.
local VERSION = "4.6"
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
local function new_aim_stats()
    return { shots = 0, hits = 0, correction = 0, spread = 0, other = 0 }
end
local aim_stats = new_aim_stats()

-------------------------------------------------------------------------------
-- Menu
-------------------------------------------------------------------------------

pcall(ui.sidebar, SCRIPT, "shield")

-- "Always use recommended settings": Neverlose lua ayarlarini config'e kaydeder; eski
-- bir surumle kaydedilmis config eski varsayilanlari geri getirir. Bu yuzden AA,
-- exploit ve builder ayarlarinin varsayilanlari kaydedilir ve acik oldugu surece bu
-- degerlerde tutulur (ayar degistirmek icin kapat). Bind'lenen ayarlar (manual, freestanding, inverter),
-- builder'daki durum secici ve gorsel tercihler bu listeye girmez.
local recommended = {}
-- Log icin ayarin adinin onune eklenir (builder'da durum adi: "Fake duck Left limit").
local label_prefix = ""

local function remember(element, value, name)
    if element ~= nil then
        recommended[#recommended + 1] = { element = element, value = value, label = label_prefix .. tostring(name) }
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

local g_main_raw    = ui.create("Anti-Aim", "Main", 1)
local g_main        = tracked(g_main_raw)
local g_defensive   = tracked(ui.create("Anti-Aim", "Exploits", 1))
local g_builder_raw = ui.create("Anti-Aim", "Builder", 2)
local g_builder     = tracked(g_builder_raw)
local g_resolver    = tracked(ui.create("Resolver", "Resolver", 1))
local g_visuals     = ui.create("Visuals", "Indicators", 1)

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
local EXPLOIT_DEFAULTS = {
    ["Standing"]     = { "Double tap", "On peek",   "Up",     "Sideways" },
    ["Moving"]       = { "Double tap", "Smart",     "Up",     "Sideways" },
    ["Slow walk"]    = { "Double tap", "Smart",     "Up",     "Sideways" },
    ["Crouching"]    = { "Double tap", "On peek",   "Up",     "Sideways" },
    ["Crouch move"]  = { "Double tap", "Smart",     "Switch", "Sideways" },
    ["Peek"]         = { "Double tap", "Smart",     "Up",     "Sideways" },
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
menu.enabled        = g_main_raw:switch("Enable", true)
menu.recommended    = g_main_raw:switch("Always use recommended settings", true)
menu.pitch          = g_main:combo("Pitch", { "Down", "Disabled", "Fake Down", "Fake Up" })
menu.yaw_base       = g_main:combo("Yaw base", { "At Target", "Local View" })
menu.manual         = g_main_raw:combo("Manual yaw", { "Off", "Left", "Right", "Forward" })
menu.freestanding   = g_main_raw:switch("Freestanding", false)
local fs_gear       = tracked(menu.freestanding:create())
menu.fs_air         = fs_gear:switch("Disable in air", true)
menu.fs_crouch      = fs_gear:switch("Disable while crouching", false)
menu.fs_slow        = fs_gear:switch("Disable while slow walking", false)
menu.fs_moving      = fs_gear:switch("Disable while moving", false)
-- Freestanding tusun kapaliyken de ayakta / egilip dururken (aci tutarken) acilir: kafa
-- duvara donuk saklanir. Kafa yine de gorunuyorsa normal jitter'a donulur.
menu.fs_auto        = fs_gear:switch("Auto when standing still", true)
menu.inverter       = g_main_raw:switch("Static inverter", false)
menu.safe_head      = g_main:switch("Safe head", true)
local safe_gear     = tracked(menu.safe_head:create())
menu.safe_knife     = safe_gear:switch("Knife/Zeus in air crouch", true)
menu.safe_air       = safe_gear:switch("Any air crouch", false)
menu.safe_high      = safe_gear:switch("High ground", true)
menu.anti_brute     = g_main:switch("Anti-bruteforce", true)
local brute_gear    = tracked(menu.anti_brute:create())
menu.brute_reset    = brute_gear:slider("Reset after", 1, 15, 6, nil, "s")
menu.brute_log      = brute_gear:switch("Console log", false)
menu.avoid_backstab = g_main:switch("Avoid backstab", true)
-- Fake duck'ta egik ve yavassin, DT/HS calismaz. Bicak / zeus tutan bir dusman
-- yaklasinca fake duck birakilir; uzaklasinca senin tusun yine gecerli olur.
menu.fd_guard       = g_main:switch("Release fake duck near knife", true)
menu.legit_use      = g_main:switch("Legit AA on use", true)
menu.spin           = g_main:switch("Spin when idle", true)
local spin_gear     = tracked(menu.spin:create())
-- HvH sunucularinda warmup'ta da savasiliyor, o yuzden varsayilan kapali.
menu.spin_warmup    = spin_gear:switch("Warmup", false)
menu.spin_enemies   = spin_gear:switch("No enemies alive", true)
menu.spin_pitch     = spin_gear:combo("Pitch", { "Disabled", "Down" })
menu.spin_speed     = spin_gear:slider("Speed", 1, 20, 6)

menu.auto_exploit = g_defensive:switch("Auto exploit", true)
-- Hareket ederken tehdidin gorus alanina giriyorsan (ya da birazdan gireceksen)
-- peek assist tusu olmadan da Peek durumuna gecilir.
menu.auto_peek    = g_defensive:switch("Auto peek", true)
-- Scout / AWP / R8'de exploit. "Auto (learn)": Hide shots ile baslar, kafana gelen
-- mermilere gore Double tap daha az vurduruyorsa ona gecer (bkz. sniper). "Hide shots"
-- her zaman HS, "Same as state" durumun kendi exploit'i (varsayilan DT).
menu.sniper_exploit = g_defensive:combo("Snipers (SSG08/AWP/R8)", { "Auto (learn)", "Hide shots", "Same as state" })
-- DT / HS atistan ya da fake duck'tan sonra yeniden sarj olurken oyuncu sunucuda yerinde
-- donar. Tehdit kafani goruyorken sarj bekletilir, siperin arkasina gecince dolar.
menu.safe_recharge  = g_defensive:switch("Safe recharge", true)
menu.exploit_info = g_defensive:label("Per-state exploit settings are in the Builder.")
menu.hidden_spin  = g_defensive:slider("Hidden spin speed", 1, 30, 10)

-- Neverlose'un kendi resolver'i acilari cozmeye devam eder. Bu katman, bir dusmana
-- resolver yuzunden ("correction") iska gectikce sadece o dusmana karsi safe point'i
-- yukseltir; isabetler geldikce geri indirir.
menu.resolver      = g_resolver:switch("Adaptive resolver", true)
menu.resolver_log  = g_resolver:switch("Console log", true)
-- Body Aim'i hedefe gore secer: govde olduruyorsa (tek mermi ya da DT ile iki) govde,
-- scout / AWP / R8'de govde oldurmuyorsa kafa, resolver iki kez yanildiysa govde.
menu.smart_baim    = g_resolver:switch("Smart body aim", true)
-- Scout / AWP / R8'de minimum hasar hedefin canina cekilir: aimbot sadece oldurecek yere
-- ates eder. Tam canli dusmanda bu kafa demek; govde ancak olduruyorsa vurulur.
menu.head_only     = g_resolver:switch("Head unless body kills (snipers)", true)
-- Her aimbot atisinin sonucu tek satir: resolver'i verilerle ayarlamak icin.
menu.shot_log      = g_resolver:switch("Shot log (console)", true)
menu.resolver_info = g_resolver:label("Raises safe points per enemy after resolver misses.")
-- Ogrenilen anti-brute fazlari ve resolver seviyeleri Steam ID ile harita degisince de
-- kalir; bu dugme hepsini siler.
pcall(function()
    menu.forget = g_resolver:button("Forget learned enemies", function()
        if forget_enemies ~= nil then
            forget_enemies()
        end
    end, true)
end)

menu.state = g_builder_raw:combo("State", STATES)

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
        s.info = g_builder:label(SPECIAL_INFO[state])
    end
    if i > 1 and not special then
        s.override = g_builder:switch("Override", true)
    end
    -- L&R: desync tarafina gore iki aci. X-Way: her flip'te siradaki aciya gecer;
    -- desync her flip'te taraf degistirdigi icin aci/taraf eslesmesi surekli kayar.
    s.yaw_mode      = g_builder:combo("Yaw mode", { "L&R", "X-Way" })
    s.yaw_left      = g_builder:slider("Yaw left", -180, 180, d[1], nil, DEG)
    s.yaw_right     = g_builder:slider("Yaw right", -180, 180, d[2], nil, DEG)
    s.ways          = g_builder:slider("Ways", 3, 5, 3)
    for n = 1, 5 do
        s["way" .. n] = g_builder:slider("Way " .. n, -180, 180, WAY_DEFAULTS[n], nil, DEG)
    end
    s.yaw_random    = g_builder:slider("Yaw randomize", 0, 30, 0, nil, DEG)
    s.modifier      = g_builder:combo("Yaw modifier", MODIFIERS)
    s.mod_random    = tracked(s.modifier:create()):slider("Randomize", 0, 60, 0, nil, DEG)
    s.mod_offset    = g_builder:slider("Modifier offset", -180, 180, 0, nil, DEG)
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
    s.body_yaw      = g_builder:combo("Body yaw", body_items)
    local body_gear = tracked(s.body_yaw:create())
    s.avoid_overlap = body_gear:switch("Avoid overlap", false)
    s.body_fs       = body_gear:combo("Freestanding",
        state == "Fake duck" and { "Peek Fake", "Off", "Peek Real" } or { "Off", "Peek Fake", "Peek Real" })
    -- Jitter her pakette tam sirayla donerse resolver'lar bunu yakalar (ornek resolver son
    -- 4 aci degisiminin 3'u yon degistiriyorsa "jitter" deyip tarafi esliyordu). Her
    -- donuste 0-1 paket rastgele bekleme bu kati sirayi bozar. Sadece DT/HS aktifken.
    s.delay_random  = body_gear:slider("Delay randomize", 0, 5, static_default and 0 or 1, nil, "t")
    s.limit_random  = body_gear:slider("Limit randomize", 0, 30, 0, nil, DEG)
    s.delay         = g_builder:slider("Jitter delay", 1, 10, d[3], nil, "t")
    s.left_limit    = g_builder:slider("Left limit", 0, 60, d[4], nil, DEG)
    s.right_limit   = g_builder:slider("Right limit", 0, 60, d[5], nil, DEG)

    local e = EXPLOIT_DEFAULTS[state]
    if e ~= nil then
        s.exploit_label      = g_builder:label("Exploit")
        s.exploit            = g_builder:combo("Exploit", default_first(EXPLOITS, e[1]))
        s.def_mode           = g_builder:combo("Defensive", default_first(DEF_MODES, e[2]))
        s.def_ticks          = g_builder:slider("Defensive every", 2, 22, 14, nil, "t")
        s.hidden_pitch       = g_builder:combo("Hidden pitch", default_first(HIDDEN_PITCHES, e[3]))
        s.hidden_pitch_value = g_builder:slider("Pitch value", -89, 89, 0, nil, DEG)
        s.hidden_yaw         = g_builder:combo("Hidden yaw", default_first(HIDDEN_YAWS, e[4]))
        s.hidden_yaw_value   = g_builder:slider("Yaw value", -180, 180, 90, nil, DEG)
    end
    builder[state] = s
end
label_prefix = ""

menu.indicators  = g_visuals:switch("Crosshair indicators", true)
menu.accent      = menu.indicators:color_picker(color(150, 190, 255, 255))
menu.arrows      = g_visuals:switch("Manual arrows", true)
menu.arrow_color = menu.arrows:color_picker(color(150, 190, 255, 255))
menu.hit_log     = g_visuals:switch("Hit log (console)", true)
menu.stats_panel = g_visuals:switch("Stats panel", false)
-- Dugme API'si yoksa script'i dusurmesin; sadece sifirlama dugmesi olmaz.
pcall(function()
    menu.stats_reset = g_visuals:button("Reset stats", function()
        stats, pending_misses, aim_stats = {}, {}, new_aim_stats()
    end, true)
end)

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

    local selected = menu.state:get()
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

for _, element in ipairs({ menu.enabled, menu.auto_exploit, menu.indicators, menu.arrows, menu.state }) do
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
local exposure = { available = trace_bullet ~= nil, tick = -1000, now = false, soon = false,
    any = false, others = {}, turn = 0, sight = {}, facing = nil }
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

local function head_visible_to(threat, eye, head, dx, dy, dz)
    local target = vector(head.x + dx, head.y + dy, head.z + dz)
    local ok, damage = pcall(trace_bullet, threat, eye, target)
    return ok and type(damage) == "number" and damage > 0
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
        exposure.now, exposure.soon = false, false
        local head = lp:get_hitbox_position(0)
        if head == nil then
            exposure.any, exposure.others = false, {}
            return
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
                exposure.others[pick.index] = nil
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
        if get("peek_assist") then
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
local BRUTE_PHASES = {
    { invert = true,  scale = 1.0,  shift = 0 },
    { invert = false, scale = 1.0,  shift = 15 },
    { invert = true,  scale = 0.85, shift = -15 },
    { invert = false, scale = 1.0,  shift = 0, random = true },
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
-- Grup senin hareketin: yerde durma, hareket ve hava farkli AA ayarlariyla oynanir; birinde
-- en iyi faz digerinde en iyi olmayabilir.
local brute = { enemies = {}, recent = nil, hurt = {}, phases = {}, default = {},
    groups = { "still", "move", "air" },
    group_of = { Moving = "move", ["Slow walk"] = "move", ["Crouch move"] = "move", Peek = "move",
        Air = "air", ["Air crouch"] = "air" },
    group_label = { still = "yerde", move = "hareket", air = "hava" } }

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
local sniper = { stats = { hs = { shots = 0, hits = 0 }, dt = { shots = 0, hits = 0 } }, choice = "hs" }

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
    body_stall = { key = nil, visible = 0, last = nil, relaxed = false } }

local function prop(ent, name)
    local ok, value = pcall(function() return ent[name] end)
    if ok then
        return value
    end
    return nil
end

-- Okunamayan alanlar "Standing" sayilir (en sik durum, en az varsayim).
local function enemy_state(ent)
    local flags = prop(ent, "m_fFlags")
    if type(flags) == "number" and bit.band(flags, 1) == 0 then
        return "Air"
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

-- Dusman takibi: her tick canli, dormant olmayan dusmanlarin simulasyon zamani, konumu ve
-- sunucudan gelen bakis yonu izlenir:
--  defensive: simulasyon zamani gordugumuz en yuksek degerin gerisine dustu (tickbase
--             kaydirma: defensive / hidden AA). O anki kayit dusmanin gercek acisi degil.
--  lc: iki guncelleme arasinda 64 birimden fazla yer degistirdi (lag compensation kirildi,
--      eski kayitlara backtrack gecersiz).
--  jitter: son `samples` guncelleme arasindaki ortalama yaw degisimi (derece); jitter ya
--          da spin AA. En az 4 guncellemeden sonra hesaplanir.
-- Bayraklar `hold` tick gecerli kalir: atis sonucu ~0.05-0.3 sn sonra gelir.
-- jitter_prior: bu kadar jitter'li ve o durumda hic sonucu olmayan dusmana ilk atistan
-- "Prefer" (iska beklenmez). Karar jitter_memory sn hatirlanir: loglarda ayni dusmanin
-- ortalamasi 21 ile 48 arasinda gidip geliyordu ve on bilgi acilip kapaniyordu.
local enemy_watch = { list = {}, hold = 16, samples = 6, jitter_prior = 35, jitter_memory = 60 }
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
            def_tick = -1000, lc_tick = -1000 }
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
                        if sim < t.max_sim then
                            t.def_tick = now
                        else
                            t.max_sim = sim
                        end
                        local origin = origin_of(enemy)
                        if origin ~= nil and t.origin ~= nil then
                            local dx, dy, dz = origin.x - t.origin.x, origin.y - t.origin.y, origin.z - t.origin.z
                            if dx * dx + dy * dy + dz * dz > 64 * 64 then
                                t.lc_tick = now
                            end
                        end
                        local yaw = eye_yaw(enemy)
                        if yaw ~= nil and t.yaw ~= nil then
                            t.deltas[#t.deltas + 1] = abs((yaw - t.yaw + 180) % 360 - 180)
                            if #t.deltas > enemy_watch.samples then
                                table.remove(t.deltas, 1)
                            end
                        end
                        t.sim, t.origin, t.yaw = sim, origin, yaw
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
            lc = now >= t.lc_tick and now - t.lc_tick <= enemy_watch.hold,
            jitter = jitter,
        }
    end
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

-- Seviye, anahtar, durum, kayit ve seviyenin jitter on bilgisinden gelip gelmedigi.
-- Dusmanin o durumda hic sonucu yoksa ve AA'si jitter'liyse (ortalama yaw degisimi
-- jitter_prior derece ve ustu) ilk atistan "Prefer": Neverlose'un resolver'i jitter'da en
-- cok yanilir ve iska beklemek bir atis kaybettirir. O durumda ilk sonuc gelince veri gecer.
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
        if not resolver.prior_logged[key] and menu.resolver_log:get() then
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

local current = { state = "Global", side = false, limit = 60, freestand = false, defensive = false, forced = false,
    brute = 0, phase_group = "still", resolver = 0, res_state = nil, res_prior = false, weapon = nil, lethal = false,
    head_only = false }

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
    if level > (SAFE_POINT_RANK[resolver.user_safe] or 0) then
        override("safe_points", SAFE_POINT_LEVELS[level])
    else
        override("safe_points", nil)
    end
    return target, raw
end

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
    apply_body_aim = function(lp, class, target, level)
        if overridden.body_aim == nil then
            resolver.user_body = get("body_aim")
        end
        local wanted, lethal = nil, false
        if target ~= nil and menu.smart_baim:get() then
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
        end
        if not lethal then
            local stall = resolver.body_stall
            stall.key, stall.visible, stall.last, stall.relaxed = nil, 0, nil, false
        end
        current.lethal = wanted == "Prefer" or wanted == "Force"
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
        local info = WEAPONS[class]
        local health = target ~= nil and prop(target, "m_iHealth") or nil
        local min_damage = nil
        if menu.head_only:get() and info ~= nil and info[4] and type(health) == "number" and health > 0 then
            min_damage = min(100, health)
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
        if SNIPERS[class] and (sniper_setting == "Hide shots" or (sniper_setting == "Auto (learn)" and sniper.choice == "hs")) then
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

    -- "Smart" + DT: tehdit kafani gordugu (ya da 0.2 sn icinde gorecegi) surece ve gorus
    -- kesildikten sonra SMART_HOLD tick daha defensive zorlanir. Ayni gorus SMART_MAX
    -- tick'ten uzun surerse durulur: peek ani gecti, artik "Always on" gibi davranmaya
    -- gerek yok. Gorus SMART_HOLD tick'ten uzun kesilince yeniden kurulur.
    local SMART_HOLD = 8
    local SMART_MAX = 64
    local smart = { start = -1000, last = -1000 }

    local function smart_window(now)
        if seen_by_enemy() then
            if now < smart.last or now - smart.last > SMART_HOLD then
                smart.start = now
            end
            smart.last = now
        end
        return now >= smart.last and now - smart.last <= SMART_HOLD and now - smart.start < SMART_MAX
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
        -- durumundayken, havadayken ya da tehdit kafani goruyor / birazdan gorecekken Break
        -- LC acilir; yoksa scout'la peek atarken hic defensive olmuyordu. Havada gorus
        -- beklenmez: loglarda havada HS ile "DEF yok" iken kafadan vuruldun, birinde
        -- saldirani izler gormemisti.
        local now = globals.tickcount
        local on_peek = mode == "On peek" or mode == "Smart"
        if on_peek and hs and (state == "Peek" or moving or seen_by_enemy()) then
            hs_lc.until_tick = now + HS_LC_HOLD
        end
        local hs_peek = on_peek and hs and now <= hs_lc.until_tick and now >= hs_lc.until_tick - HS_LC_HOLD
        -- Neverlose'da DT, HS'den once gelir; ikisi de aciksa DT gecerlidir. Sarj yokken
        -- defensive olmaz, o zaman zorlanmaz.
        local window = mode == "Smart" and smart_window(now)
        local forced = window and dt and exploit_active()
        current.defensive = not on_peek or hs_peek or forced
        current.forced = forced

        if on_peek then
            -- Neverlose peek attigini kendisi algilar ve o an defensive'e gecer.
            override("lag_options", "On Peek")
            override("hs_options", hs_peek and "Break LC" or "Favor Fire Rate")
            if forced then
                pcall(function() cmd.force_defensive = true end)
            end
        elseif mode == "Always on" then
            override("lag_options", "Always On")
            override("hs_options", hs and "Break LC" or "Favor Fire Rate")
        else
            override("lag_options", "On Peek")
            override("hs_options", hs and "Break LC" or "Favor Fire Rate")
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
local own = { last_shot = -1000 }
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
        local active = overridden.fakeduck ~= nil
        if not menu.fd_guard:get() then
            if active then
                override("fakeduck", nil)
            end
            return
        end
        if active then
            if knife_enemy(lp, KNIFE_FAR) == nil then
                override("fakeduck", nil)
            end
            return
        end
        if not get("fakeduck") then
            return
        end
        local enemy, dist = knife_enemy(lp, KNIFE_NEAR)
        if enemy ~= nil then
            override("fakeduck", false)
            if overridden.fakeduck ~= nil and menu.hit_log:get() then
                print(("[%s] fake duck birakildi: %s bicak/zeus ile %d birim yakinda"):format(
                    SCRIPT, player_name(enemy), round(dist)))
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
    local target
    if threat == nil then
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

events.createmove:set(protect("createmove", function(cmd)
    current.defensive, current.forced = false, false
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

    apply({
        pitch = menu.pitch:get(), yaw_base = yaw_base, yaw_offset = yaw_offset,
        modifier = s.modifier:get(), mod_offset = s.mod_offset:get() + round(flip.mod_n * s.mod_random:get()),
        body = body, side = side, left = left, right = right,
        avoid_overlap = s.avoid_overlap:get(), body_fs = s.body_fs:get(), freestand = freestand,
    })
    apply_defensive(cmd, builder[state], class, state,
        move_state ~= "Standing" and move_state ~= "Crouching" and move_state ~= "Fake duck")
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
        entry.shot_applied, entry.shot_group, entry.shot_sniper = current.brute, current.phase_group,
            sniper.mode(current.weapon)

        -- Hasar bu mermiden once geldiyse zaten isabettir, iska adayi degildir.
        local hurt = brute.hurt[e.userid]
        if hurt == nil or now < hurt or now - hurt >= MISS_WINDOW then
            pending_misses[#pending_misses + 1] = {
                userid = e.userid, time = now, state = current.state, stage = shot_stage, name = player_name(shooter),
                aa = aa_status(), exploit = exploit_status(), weapon = weapon_label(), attacker = attacker_info(shooter),
                applied = current.brute, group = current.phase_group, sniper = sniper.mode(current.weapon),
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
        record_phase(group or current.phase_group, applied or current.brute, true)
        sniper.record(shot_sniper, true)
    end

    if not melee then
        local entry = stat_for(current.state)
        entry.hits = entry.hits + 1
        if e.hitgroup == 1 then
            entry.head = entry.head + 1
        end
    end
    if menu.hit_log:get() then
        print(("[%s] vuruldun: %s -%d %s | %s | faz %d | %s | %s | %s | %s (%s)"):format(
            SCRIPT, HITGROUPS[e.hitgroup] or "?", tonumber(e.dmg_health) or 0, weapon,
            current.state, hit_stage, aa_status(), exploit_status(), weapon_label(), player_name(attacker),
            attacker_info(attacker)))
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
    if profile.defensive then
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
        if e.id ~= nil then
            resolver.shots[e.id] = { state = state, time = now, safe = effective("safe_points"),
                body = effective("body_aim"), md = effective("min_damage"), health = prop(target, "m_iHealth"),
                weapon = weapon_label(),
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
            -- iska resolver'in hatasi degil, safe point de duzeltmez. Ogrenilmez. Defensive
            -- sayilmaz: oyun loglarinda neredeyse her atista dusman defensive'deydi ve
            -- kafadan isabetler de geldi; sayilmasaydi resolver hic ogrenmezdi.
            local profile = shot ~= nil and shot.profile or nil
            if profile ~= nil and profile.lc then
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
        if result == nil or target == nil or not menu.resolver:get() then
            return
        end
        local entry = resolver_entry(target)
        if entry == nil then
            return
        end
        local enemy = shot ~= nil and shot.state or enemy_state(target)
        local before = entry_level(entry, enemy)
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
            data.resolver[key] = { name = entry.name, results = copy(entry.results), states = states }
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
        local list = type(data.phase_groups) == "table" and data.phase_groups[group] or data.phases
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
                if type(e.states) == "table" then
                    for _, state in ipairs({ "Standing", "Moving", "Crouch", "Air" }) do
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
    reset_brute()
    exposure.shot = nil
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
        enemy_watch.list = {}
        persist.save(true)
    end))
end)

events.player_death:set(protect("player_death", function(e)
    local lp = entity.get_local_player()
    if lp ~= nil and entity.get(e.userid, true) == lp then
        reset_brute()
        set_charge(true)
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

local anim = { scope = 0 }
local RES_STATE_LABEL = { Standing = "STAND", Moving = "MOVE", Crouch = "DUCK", Air = "AIR" }
local render_failed = {}

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
        local why = current.res_prior and "JIT" or (RES_STATE_LABEL[current.res_state] or "")
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
local function safe_draw(name, fn, ...)
    if render_failed[name] then
        return
    end
    local ok, err = pcall(fn, ...)
    if not ok then
        render_failed[name] = true
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

events.shutdown:set(protect("shutdown", function()
    reset_overrides()
    set_charge(true)
    persist.save(true)
end))

-- Kalici hafiza yuklenir; kac oyuncu hatirlandigi surum satirina eklenir.
do
    local loaded = persist.load()
    print(("[%s] v%s yuklendi%s"):format(SCRIPT, VERSION,
        loaded > 0 and (" (hafiza: %d oyuncu)"):format(loaded) or ""))
end
