--[[
    ANT-A-M v2  |  Neverlose (CS:GO) icin HvH anti-aim lua'si

    Kurar kurmaz calisir: butun varsayilanlar ayarlanmis halde gelir.

    Neler var
      - 12 durumlu builder: Global, Standing, Moving, Slow walk, Crouching,
        Crouch move, Peek, Air, Air crouch + ozel durumlar Manual,
        Freestanding, Safe head. Her durum kendi ayarlariyla gelir
        ("Override" kapatilirsa o durum Global'in AA ayarlarini kullanir).
      - Duruma ozel exploit: her durumda DT / HS secimi, defensive modu
        (Off / On peek / Always on / Tick based) ve hidden pitch / yaw.
        Havada, egilerek yururken ve peek atarken defensive kendiliginden
        hep acik; yerde Neverlose'un "On Peek" defensive'i peek'te devreye girer.
      - L/R yaw, rage.antiaim:inverter ile desync tarafina senkron jitter yapar.
        Taraf her paket dongusunde cevrilir; gecikme sadece DT/HS aktifken
        uygulanir (fakelag'da her paket zaten cok tick surer).
      - Yaw / modifier / limit rastgeleligi; rastgele deger her flip'te bir kez
        secilir, boylece bir paket icinde aci sabit kalir.
      - Durum gecislerinde histerezis ve inis toleransi (titreme yok).
      - Mermi izine gore anti-bruteforce, safe head (bicak/zeus, yuksek zemin),
        freestanding (hedef varsa) + devre disi kosullari, manuel yaw,
        avoid backstab, use'a basinca legit AA, warmup / dusman yokken spin.
      - Kapatinca ya da kaldirinca butun Neverlose ayarlarini geri verir.
        Bulunamayan menu yolu ya da API olursa cokmez, o ozelligi atlar.

    Kurulum ve ayar tavsiyeleri icin README.md'ye bak.
]]

local SCRIPT = "ANT-A-M"
local DEG = "\194\176"

local floor, max, min, sqrt, huge, random = math.floor, math.max, math.min, math.sqrt, math.huge, math.random

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

local api = {
    inverter     = rage_method("antiaim", "inverter"),
    get_target   = rage_method("antiaim", "get_target"),
    hidden_pitch = rage_method("antiaim", "override_hidden_pitch"),
    hidden_yaw   = rage_method("antiaim", "override_hidden_yaw_offset"),
    charge       = rage_method("exploit", "get"),
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
}

-- Ezdigimiz ayarlar ve verdigimiz degerler. Kapatinca hepsini geri veririz.
local overridden = {}

-- value nil ise o ayar kullanicinin kendi Neverlose degerine birakilir.
local function override(name, value)
    local ref = refs[name]
    if ref == nil then
        return
    end
    if value == nil then
        if overridden[name] ~= nil then
            ref:override()
            overridden[name] = nil
        end
        return
    end
    ref:override(value)
    overridden[name] = value
end

local function reset_overrides()
    for name in pairs(overridden) do
        refs[name]:override()
    end
    overridden = {}
end

local function get(name)
    local ref = refs[name]
    return ref ~= nil and ref:get() or false
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

-------------------------------------------------------------------------------
-- Menu
-------------------------------------------------------------------------------

pcall(ui.sidebar, SCRIPT, "shield")

local g_main      = ui.create("Anti-Aim", "Main", 1)
local g_defensive = ui.create("Anti-Aim", "Exploits", 1)
local g_builder   = ui.create("Anti-Aim", "Builder", 2)
local g_visuals   = ui.create("Visuals", "Indicators", 1)

local STATES = {
    "Global", "Standing", "Moving", "Slow walk", "Crouching", "Crouch move", "Peek", "Air", "Air crouch",
    "Manual", "Freestanding", "Safe head",
}
local MOVEMENT_STATES = 9

local SPECIAL_INFO = {
    ["Manual"]       = "Used while manual yaw is active.",
    ["Freestanding"] = "Used while freestanding has a target.",
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
    ["Manual"]       = { 0, 0, 1, 60, 60 },
    ["Freestanding"] = { 0, 0, 1, 60, 60 },
    ["Safe head"]    = { 0, 0, 1, 30, 30 },
}

-- Exploit varsayilanlari: { exploit, defensive, hidden pitch, hidden yaw }
local EXPLOIT_DEFAULTS = {
    ["Standing"]     = { "Double tap", "On peek",   "Up",     "Sideways" },
    ["Moving"]       = { "Double tap", "On peek",   "Up",     "Sideways" },
    ["Slow walk"]    = { "Double tap", "On peek",   "Up",     "Sideways" },
    ["Crouching"]    = { "Double tap", "On peek",   "Up",     "Sideways" },
    ["Crouch move"]  = { "Double tap", "Always on", "Switch", "Sideways" },
    ["Peek"]         = { "Double tap", "Always on", "Up",     "Sideways" },
    ["Air"]          = { "Double tap", "Always on", "Up",     "Spin" },
    ["Air crouch"]   = { "Double tap", "Always on", "Up",     "Random" },
    ["Manual"]       = { "Double tap", "On peek",   "Off",    "Off" },
    ["Freestanding"] = { "Double tap", "On peek",   "Off",    "Off" },
    ["Safe head"]    = { "Double tap", "Off",       "Off",    "Off" },
}

local MODIFIERS = { "Disabled", "Center", "Offset", "Random", "Spin", "3-Way", "5-Way" }
local EXPLOITS = { "Double tap", "Hide shots", "Binds" }
local DEF_MODES = { "Off", "On peek", "Always on", "Tick based" }
local HIDDEN_PITCHES = { "Off", "Down", "Up", "Zero", "Switch", "Random", "Custom" }
local HIDDEN_YAWS = { "Off", "Sideways", "Spin", "Random", "Forward", "Custom" }

local menu = {}
menu.enabled        = g_main:switch("Enable", true)
menu.pitch          = g_main:combo("Pitch", { "Down", "Disabled", "Fake Down", "Fake Up" })
menu.yaw_base       = g_main:combo("Yaw base", { "At Target", "Local View" })
menu.manual         = g_main:combo("Manual yaw", { "Off", "Left", "Right", "Forward" })
menu.freestanding   = g_main:switch("Freestanding", false)
local fs_gear       = menu.freestanding:create()
menu.fs_air         = fs_gear:switch("Disable in air", true)
menu.fs_crouch      = fs_gear:switch("Disable while crouching", false)
menu.fs_slow        = fs_gear:switch("Disable while slow walking", false)
menu.fs_moving      = fs_gear:switch("Disable while moving", false)
menu.inverter       = g_main:switch("Static inverter", false)
menu.safe_head      = g_main:switch("Safe head", true)
local safe_gear     = menu.safe_head:create()
menu.safe_knife     = safe_gear:switch("Knife/Zeus in air crouch", true)
menu.safe_air       = safe_gear:switch("Any air crouch", false)
menu.safe_high      = safe_gear:switch("High ground", true)
menu.anti_brute     = g_main:switch("Anti-bruteforce", true)
local brute_gear    = menu.anti_brute:create()
menu.brute_reset    = brute_gear:slider("Reset after", 1, 15, 6, nil, "s")
menu.brute_log      = brute_gear:switch("Console log", false)
menu.avoid_backstab = g_main:switch("Avoid backstab", true)
menu.legit_use      = g_main:switch("Legit AA on use", true)
menu.spin           = g_main:switch("Spin when idle", true)
local spin_gear     = menu.spin:create()
menu.spin_warmup    = spin_gear:switch("Warmup", true)
menu.spin_enemies   = spin_gear:switch("No enemies alive", true)
menu.spin_pitch     = spin_gear:combo("Pitch", { "Disabled", "Down" })
menu.spin_speed     = spin_gear:slider("Speed", 1, 20, 6)

menu.auto_exploit = g_defensive:switch("Auto exploit", true)
menu.exploit_info = g_defensive:label("Per-state exploit settings are in the Builder.")
menu.hidden_spin  = g_defensive:slider("Hidden spin speed", 1, 30, 10)

menu.state = g_builder:combo("State", STATES)

local AA_KEYS = {
    yaw_left = true, yaw_right = true, yaw_random = true, modifier = true, mod_random = true, mod_offset = true,
    body_yaw = true, avoid_overlap = true, body_fs = true, delay_random = true, limit_random = true,
    delay = true, left_limit = true, right_limit = true,
}

local builder = {}
for i, state in ipairs(STATES) do
    local d = DEFAULTS[state]
    local special = i > MOVEMENT_STATES
    local s = {}
    if special then
        s.info = g_builder:label(SPECIAL_INFO[state])
    elseif i > 1 then
        s.override = g_builder:switch("Override", true)
    end
    s.yaw_left      = g_builder:slider("Yaw left", -180, 180, d[1], nil, DEG)
    s.yaw_right     = g_builder:slider("Yaw right", -180, 180, d[2], nil, DEG)
    s.yaw_random    = g_builder:slider("Yaw randomize", 0, 30, 0, nil, DEG)
    s.modifier      = g_builder:combo("Yaw modifier", MODIFIERS)
    s.mod_random    = s.modifier:create():slider("Randomize", 0, 60, 0, nil, DEG)
    s.mod_offset    = g_builder:slider("Modifier offset", -180, 180, 0, nil, DEG)
    -- Combo varsayilani ilk eleman oldugu icin ozel durumlarda Static basta.
    s.body_yaw      = g_builder:combo("Body yaw", special and { "Static", "Jitter", "Off" } or { "Jitter", "Static", "Off" })
    local body_gear = s.body_yaw:create()
    s.avoid_overlap = body_gear:switch("Avoid overlap", false)
    s.body_fs       = body_gear:combo("Freestanding", { "Off", "Peek Fake", "Peek Real" })
    s.delay_random  = body_gear:slider("Delay randomize", 0, 5, 0, nil, "t")
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

menu.indicators  = g_visuals:switch("Crosshair indicators", true)
menu.accent      = menu.indicators:color_picker(color(150, 190, 255, 255))
menu.arrows      = g_visuals:switch("Manual arrows", true)
menu.arrow_color = menu.arrows:color_picker(color(150, 190, 255, 255))

local function update_visibility()
    local on = menu.enabled:get()
    for key, element in pairs(menu) do
        if key ~= "enabled" then
            element:visibility(on)
        end
    end
    menu.accent:visibility(on and menu.indicators:get())
    menu.arrow_color:visibility(on and menu.arrows:get())

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
            local body = s.body_yaw:get()
            local modded = s.modifier:get() ~= "Disabled"
            local desync = body ~= "Off"
            s.mod_offset:visibility(modded)
            s.mod_random:visibility(modded)
            s.delay:visibility(body == "Jitter")
            s.delay_random:visibility(body == "Jitter")
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
    for _, key in ipairs({ "override", "modifier", "body_yaw", "def_mode", "hidden_pitch", "hidden_yaw" }) do
        if s[key] ~= nil then
            s[key]:set_callback(update_visibility)
        end
    end
end
update_visibility()

-------------------------------------------------------------------------------
-- Durum tespiti
-------------------------------------------------------------------------------

-- Histerezis: girme ve cikma esikleri farkli, boylece sinirda durum titremez.
local MOVE_ENTER, MOVE_LEAVE = 10, 5
local DUCK_ENTER, DUCK_LEAVE = 0.7, 0.5
-- Yere indikten sonra bu kadar tick daha "havada" sayilir.
local LANDING_TICKS = 3

-- Yerdeyken yuklenince ilk tick'lerde "havada" sayilmasin diye dolu baslar.
local motion = { ground_ticks = 64, moving = false, ducked = false }

local function detect_movement(lp, cmd)
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

    local crouching = motion.ducked or get("fakeduck")
    if cmd.in_jump == true or motion.ground_ticks < LANDING_TICKS then
        return crouching and "Air crouch" or "Air"
    end
    if get("peek_assist") then
        return "Peek"
    end
    if crouching then
        return motion.moving and "Crouch move" or "Crouching"
    end
    if motion.moving then
        return get("slowwalk") and "Slow walk" or "Moving"
    end
    return "Standing"
end

local function settings_for(state)
    local s = builder[state]
    if s.override ~= nil and not s.override:get() then
        return builder["Global"]
    end
    return s
end

local MELEE = { CKnife = true, CKnifeGG = true, CWeaponTaser = true }

local function weapon_class(lp)
    local weapon = lp:get_player_weapon()
    if weapon == nil then
        return nil
    end
    local ok, class = pcall(weapon.get_classname, weapon)
    if ok and type(class) == "string" then
        return class
    end
    return nil
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
local function on_high_ground(lp)
    local ok, threat = pcall(entity.get_threat)
    if not ok or threat == nil then
        return false
    end
    local mine, theirs = origin_of(lp), origin_of(threat)
    return mine ~= nil and theirs ~= nil and mine.z - 35 > theirs.z
end

local HIGH_GROUND_STATES = { ["Standing"] = true, ["Crouching"] = true, ["Crouch move"] = true, ["Slow walk"] = true }

local function safe_head_active(lp, move_state, class)
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
    return HIGH_GROUND_STATES[move_state] == true and menu.safe_high:get() and on_high_ground(lp)
end

local function freestanding_allowed(move_state)
    if not menu.freestanding:get() then
        return false
    end
    if (move_state == "Air" or move_state == "Air crouch") and menu.fs_air:get() then
        return false
    end
    if (move_state == "Crouching" or move_state == "Crouch move") and menu.fs_crouch:get() then
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

-- Neverlose freestanding bir aci bulmadiysa normal hareket durumu kullanilir.
local function freestanding_has_target()
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

local function spin_active()
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

local function near_planted_bomb(lp)
    if lp.m_iTeamNum ~= 3 then
        return false
    end
    local ok, list = pcall(entity.get_entities, "CPlantedC4")
    if not ok or type(list) ~= "table" or list[1] == nil then
        return false
    end
    local a, b = origin_of(lp), origin_of(list[1])
    if a == nil or b == nil then
        return false
    end
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return dx * dx + dy * dy + dz * dz < 75 * 75
end

local use = { start = nil }

-- E'ye basili tutarken AA calismaya devam etsin. Ilk tick'ler oyuna gecer ki
-- kapi acma / silah alma bozulmasin; CT olarak bomba basindaysan hic karisilmaz.
local function legit_use_active(lp, cmd)
    if not menu.legit_use:get() or cmd.in_use ~= true or near_planted_bomb(lp) then
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

-------------------------------------------------------------------------------
-- Anti-aim
-------------------------------------------------------------------------------

local MANUAL_YAW = { Left = -90, Right = 90, Forward = 180 }
local OPTIONS_OVERLAP, OPTIONS_NONE = { "Avoid Overlap" }, {}

-- Anti-brute fazlari: her isabet / yakin kacan mermide bir sonrakine gecer.
local BRUTE_PHASES = {
    { invert = true,  scale = 1.0 },
    { invert = false, scale = 0.6 },
    { invert = true,  scale = 0.8 },
}
local BRUTE_RADIUS = 40

local brute = { stage = 0, time = 0, tick = -1 }

-- Rastgele degerler -1..1 (limit icin 0..1) olarak tutulur ve o anki durumun
-- araligiyla carpilir; boylece randomize 0 ise etkisi de hemen 0 olur.
local flip = { side = false, packets = 0, extra = 0, yaw_n = 0, mod_n = 0, limit_n = 0 }

local current = { state = "Global", side = false, limit = 60, freestand = false, defensive = false }

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
    flip.side = not flip.side
    flip.packets = 0
    local spread = s.delay_random:get()
    flip.extra = spread > 0 and random(0, spread) or 0
    flip.yaw_n = random() * 2 - 1
    flip.mod_n = random() * 2 - 1
    flip.limit_n = random()
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
    set_inverter(v.side)
    override("left_limit", v.left)
    override("right_limit", v.right)
    -- Neverlose'un kendi "Jitter" secenegini bilerek vermiyoruz; jitter'i lua
    -- yonetiyor ki yaw ile desync ayni tarafta kalsin.
    override("body_options", v.avoid_overlap and OPTIONS_OVERLAP or OPTIONS_NONE)
    override("body_fs", v.body == "Static" and v.body_fs or "Off")
    override("freestanding", v.freestand)

    current.side = v.side
    current.freestand = v.freestand
    if v.body == "Off" then
        current.limit = 0
    elseif v.side then
        current.limit = v.right
    else
        current.limit = v.left
    end
end

-- Durumun exploit secimi; fake duck ile DT/HS birlikte calismaz, o zaman karisilmaz.
local function apply_exploit(s)
    local choice = s ~= nil and s.exploit ~= nil and s.exploit:get() or "Binds"
    if not menu.auto_exploit:get() or get("fakeduck") then
        choice = "Binds"
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

local function release_defensive()
    override("lag_options", nil)
    override("hs_options", nil)
    override("hidden", false)
end

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

local function apply_defensive(cmd, s, class)
    local dt, hs = effective("doubletap"), effective("hideshots")
    local mode = s.def_mode ~= nil and s.def_mode:get() or "Off"
    if not (dt or hs) or mode == "Off" or is_grenade(class) then
        release_defensive()
        return
    end
    current.defensive = mode ~= "On peek"

    if mode == "On peek" then
        -- Neverlose peek attigini kendisi algilar ve o an defensive'e gecer.
        override("lag_options", "On Peek")
        override("hs_options", nil)
    elseif mode == "Always on" then
        override("lag_options", "Always On")
        override("hs_options", hs and "Break LC" or nil)
    else
        override("lag_options", "On Peek")
        override("hs_options", hs and "Break LC" or nil)
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

events.createmove:set(function(cmd)
    current.defensive = false
    if not menu.enabled:get() then
        reset_overrides()
        return
    end

    local lp = entity.get_local_player()
    if lp == nil or not lp:is_alive() then
        return
    end

    local move_state = detect_movement(lp, cmd)
    local class = weapon_class(lp)
    local choked = cmd.choked_commands or globals.choked_commands or 0

    if brute.stage > 0 and globals.realtime - brute.time > menu.brute_reset:get() then
        brute.stage = 0
    end

    override("aa_enabled", true)
    override("yaw", "Backward")
    override("avoid_backstab", menu.avoid_backstab:get())
    -- Freestanding sirasinda ayarlari Freestanding durumu belirler.
    override("fs_modifiers", false)
    override("fs_body", false)

    if legit_use_active(lp, cmd) then
        current.state = "Legit"
        apply_exploit(nil)
        release_defensive()
        apply({
            pitch = "Disabled", yaw_base = "Local View", yaw_offset = 180, modifier = "Disabled", mod_offset = 0,
            body = "Static", side = menu.inverter:get(), left = 60, right = 60,
            avoid_overlap = false, body_fs = "Off", freestand = false,
        })
        return
    end

    if spin_active() then
        current.state = "Spin"
        apply_exploit(nil)
        release_defensive()
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
    elseif freestand and freestanding_has_target() then
        state = "Freestanding"
    else
        state = move_state
    end
    current.state = state

    -- Exploit ve defensive her zaman o anki durumun kendisinden gelir.
    apply_exploit(builder[state])
    local exploit = exploit_active()

    local s = settings_for(state)
    update_flip(s, exploit, choked)

    local body = s.body_yaw:get()
    local side
    if body == "Jitter" then
        side = flip.side
    else
        side = menu.inverter:get()
    end

    local left, right = s.left_limit:get(), s.right_limit:get()
    local phase = BRUTE_PHASES[brute.stage]
    if phase ~= nil then
        if phase.invert then
            side = not side
        end
        left = round(left * phase.scale)
        right = round(right * phase.scale)
    end
    local limit_cut = round(flip.limit_n * s.limit_random:get())
    left = max(0, left - limit_cut)
    right = max(0, right - limit_cut)

    local yaw_offset
    if side then
        yaw_offset = s.yaw_right:get()
    else
        yaw_offset = s.yaw_left:get()
    end
    yaw_offset = yaw_offset + round(flip.yaw_n * s.yaw_random:get())

    local yaw_base = menu.yaw_base:get()
    if state == "Manual" then
        yaw_base = "Local View"
        yaw_offset = yaw_offset + MANUAL_YAW[manual]
        freestand = false
    end

    apply({
        pitch = menu.pitch:get(), yaw_base = yaw_base, yaw_offset = yaw_offset,
        modifier = s.modifier:get(), mod_offset = s.mod_offset:get() + round(flip.mod_n * s.mod_random:get()),
        body = body, side = side, left = left, right = right,
        avoid_overlap = s.avoid_overlap:get(), body_fs = s.body_fs:get(), freestand = freestand,
    })
    apply_defensive(cmd, builder[state], class)
end)

-------------------------------------------------------------------------------
-- Anti-bruteforce
-------------------------------------------------------------------------------

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

events.bullet_impact:set(function(e)
    if not menu.enabled:get() or not menu.anti_brute:get() then
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

    -- Wallbang'de ayni mermi birden fazla impact uretir, tick basina bir kez say.
    if brute.tick == globals.tickcount then
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

    brute.tick = globals.tickcount
    brute.time = globals.realtime
    brute.stage = brute.stage % #BRUTE_PHASES + 1
    if menu.brute_log:get() then
        print(("[%s] anti-brute: faz %d"):format(SCRIPT, brute.stage))
    end
end)

events.round_start:set(function()
    brute.stage = 0
end)

events.player_death:set(function(e)
    local lp = entity.get_local_player()
    if lp ~= nil and entity.get(e.userid, true) == lp then
        brute.stage = 0
    end
end)

-------------------------------------------------------------------------------
-- Indikatorler
-------------------------------------------------------------------------------

local WHITE = color(255, 255, 255, 255)
local DIM = color(255, 255, 255, 90)
local SHADOW = color(0, 0, 0, 150)
local FONT = 2

local anim = { scope = 0 }
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
    local items = {
        { "DT", effective("doubletap") },
        { "HS", effective("hideshots") },
        { "FS", current.freestand },
        { "DEF", current.defensive },
    }
    local gap, total = 5, -5
    for _, item in ipairs(items) do
        item.w = text_width(item[1])
        total = total + item.w + gap
    end
    local px = x - total / 2
    for _, item in ipairs(items) do
        render.text(FONT, vector(px + item.w / 2, y), item[2] and WHITE or DIM, "c", item[1])
        px = px + item.w + gap
    end

    if brute.stage > 0 then
        render.text(FONT, vector(x, y + 9), accent, "c", ("BRUTE %d"):format(brute.stage))
    end
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

events.render:set(function()
    if not menu.enabled:get() then
        return
    end

    local lp = entity.get_local_player()
    if lp == nil or not lp:is_alive() then
        return
    end

    local screen = render.screen_size()
    local cx, cy = floor(screen.x / 2), floor(screen.y / 2)
    if menu.indicators:get() then
        safe_draw("indicators", draw_indicators, lp, cx, cy)
    end
    if menu.arrows:get() then
        safe_draw("arrows", draw_arrows, cx, cy)
    end
end)

events.shutdown:set(reset_overrides)
