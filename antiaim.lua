--[[
    ANT-A-M  |  Neverlose (CS:GO) icin HvH anti-aim lua'si

    Ozellikler
      - 8 durumlu builder: Global, Standing, Moving, Slow walk, Crouching,
        Crouch move, Air, Air crouch. Her durum "Override global" ile
        Global ayarlarini ezebilir.
      - Body yaw tarafina senkron L/R yaw (sol / sag yaw add) + gecikmeli jitter.
        Jitter'i lua kendisi yonetir, boylece yaw ile desync her zaman ayni
        tarafa bakar.
      - Neverlose'un kendi yaw modifier'lari (Center, Offset, Random, Spin, 3-Way, 5-Way)
      - Manuel yaw (sol / sag / ileri) ve freestanding
      - Anti-bruteforce: dusman mermisi kafanin yakinindan gecince (ya da
        vurunca) tarafi ve limitleri degistirir, bir sure sonra sifirlar
      - Safe head: havada egilip bicak / zeus tutarken jitter'i kapatir
      - Nisangah altinda indikatorler ve manuel ok isaretleri

    Kurulum ve ayar tavsiyeleri icin README.md'ye bak.
]]

local SCRIPT = "ANT-A-M"

local floor, max, min, sqrt, huge = math.floor, math.max, math.min, math.sqrt, math.huge

-------------------------------------------------------------------------------
-- Neverlose menu referanslari
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

local refs = {
    aa_enabled      = find("Aimbot", "Anti Aim", "Angles", "Enabled"),
    pitch           = find("Aimbot", "Anti Aim", "Angles", "Pitch"),
    yaw             = find("Aimbot", "Anti Aim", "Angles", "Yaw"),
    yaw_base        = find("Aimbot", "Anti Aim", "Angles", "Yaw", "Base"),
    yaw_offset      = find("Aimbot", "Anti Aim", "Angles", "Yaw", "Offset"),
    yaw_modifier    = find("Aimbot", "Anti Aim", "Angles", "Yaw Modifier"),
    modifier_offset = find("Aimbot", "Anti Aim", "Angles", "Yaw Modifier", "Offset"),
    body_yaw        = find("Aimbot", "Anti Aim", "Angles", "Body Yaw"),
    inverter        = find("Aimbot", "Anti Aim", "Angles", "Body Yaw", "Inverter"),
    left_limit      = find("Aimbot", "Anti Aim", "Angles", "Body Yaw", "Left Limit"),
    right_limit     = find("Aimbot", "Anti Aim", "Angles", "Body Yaw", "Right Limit"),
    body_options    = find("Aimbot", "Anti Aim", "Angles", "Body Yaw", "Options"),
    body_fs         = find("Aimbot", "Anti Aim", "Angles", "Body Yaw", "Freestanding"),
    freestanding    = find("Aimbot", "Anti Aim", "Angles", "Freestanding"),
    slowwalk        = find("Aimbot", "Anti Aim", "Misc", "Slow Walk"),
    fakeduck        = find("Aimbot", "Anti Aim", "Misc", "Fake Duck"),
    doubletap       = find("Aimbot", "Ragebot", "Main", "Double Tap"),
    hideshots       = find("Aimbot", "Ragebot", "Main", "Hide Shots"),
}

-- Hangi ayarlari ezdigimizi tutuyoruz ki kapatinca hepsini geri verebilelim.
local overridden = {}

local function override(name, value)
    local ref = refs[name]
    if ref == nil then
        return
    end
    ref:override(value)
    overridden[name] = true
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

-------------------------------------------------------------------------------
-- Menu
-------------------------------------------------------------------------------

pcall(ui.sidebar, SCRIPT, "shield")

local group_main    = ui.create("Main")
local group_builder = ui.create("Builder")
local group_visuals = ui.create("Visuals")

local STATES = { "Global", "Standing", "Moving", "Slow walk", "Crouching", "Crouch move", "Air", "Air crouch" }

-- Slider varsayilanlari: { yaw sol, yaw sag, sol limit, sag limit, jitter gecikmesi }
local DEFAULTS = {
    ["Global"]      = { -20, 35, 60, 60, 1 },
    ["Standing"]    = { -18, 32, 60, 60, 1 },
    ["Moving"]      = { -24, 38, 60, 60, 1 },
    ["Slow walk"]   = { -15, 28, 55, 55, 2 },
    ["Crouching"]   = { -16, 30, 60, 60, 1 },
    ["Crouch move"] = { -20, 34, 60, 60, 1 },
    ["Air"]         = { -28, 42, 60, 60, 1 },
    ["Air crouch"]  = { -22, 36, 58, 58, 1 },
}

local MODIFIERS = { "Disabled", "Center", "Offset", "Random", "Spin", "3-Way", "5-Way" }

local menu = {}
menu.enabled      = group_main:switch("Enable", true)
menu.pitch        = group_main:combo("Pitch", { "Down", "Disabled", "Fake Down", "Fake Up" })
menu.yaw_base     = group_main:combo("Yaw base", { "At Target", "Local View" })
menu.manual       = group_main:combo("Manual yaw", { "Off", "Left", "Right", "Forward" })
menu.freestanding = group_main:switch("Freestanding", false)
menu.inverter     = group_main:switch("Static inverter", false)
menu.body_fs      = group_main:combo("Static body freestanding", { "Off", "Peek Fake", "Peek Real" })
menu.anti_brute   = group_main:switch("Anti-bruteforce", true)
menu.brute_reset  = group_main:slider("Anti-brute reset (sec)", 1, 15, 6)
menu.brute_log    = group_main:switch("Anti-brute console log", false)
menu.safe_head    = group_main:switch("Safe head (knife / zeus in air)", true)

menu.state = group_builder:combo("State", STATES)

local builder = {}
for i, state in ipairs(STATES) do
    local d = DEFAULTS[state]
    local p = ("[%s] "):format(state)
    local s = {}
    if i > 1 then
        s.override = group_builder:switch(p .. "Override global", false)
    end
    s.yaw_left      = group_builder:slider(p .. "Yaw add left", -180, 180, d[1])
    s.yaw_right     = group_builder:slider(p .. "Yaw add right", -180, 180, d[2])
    s.modifier      = group_builder:combo(p .. "Yaw modifier", MODIFIERS)
    s.mod_offset    = group_builder:slider(p .. "Modifier offset", -180, 180, 0)
    s.body_yaw      = group_builder:combo(p .. "Body yaw", { "Jitter", "Static", "Off" })
    s.delay         = group_builder:slider(p .. "Jitter delay", 1, 8, d[5])
    s.left_limit    = group_builder:slider(p .. "Left limit", 0, 60, d[3])
    s.right_limit   = group_builder:slider(p .. "Right limit", 0, 60, d[4])
    s.avoid_overlap = group_builder:switch(p .. "Avoid overlap", false)
    builder[state] = s
end

menu.indicators = group_visuals:switch("Crosshair indicators", true)
menu.arrows     = group_visuals:switch("Manual arrows", true)
local picker_ok, picker = pcall(function()
    return group_visuals:color_picker("Accent color", color(150, 190, 255, 255))
end)
menu.accent = picker_ok and picker or nil

local function update_visibility()
    local enabled = menu.enabled:get()
    for _, element in pairs(menu) do
        if element ~= menu.enabled then
            element:visibility(enabled)
        end
    end

    local brute_on = enabled and menu.anti_brute:get()
    menu.brute_reset:visibility(brute_on)
    menu.brute_log:visibility(brute_on)
    if menu.accent ~= nil then
        menu.accent:visibility(enabled and (menu.indicators:get() or menu.arrows:get()))
    end

    local selected = menu.state:get()
    for _, state in ipairs(STATES) do
        local s = builder[state]
        local shown = enabled and state == selected
        local active = shown and (s.override == nil or s.override:get())
        for key, element in pairs(s) do
            if key == "override" then
                element:visibility(shown)
            else
                element:visibility(active)
            end
        end
        if active then
            local body = s.body_yaw:get()
            s.mod_offset:visibility(s.modifier:get() ~= "Disabled")
            s.delay:visibility(body == "Jitter")
            s.left_limit:visibility(body ~= "Off")
            s.right_limit:visibility(body ~= "Off")
            s.avoid_overlap:visibility(body ~= "Off")
        end
    end
end

for _, element in ipairs({ menu.enabled, menu.anti_brute, menu.indicators, menu.arrows, menu.state }) do
    element:set_callback(update_visibility)
end
for _, s in pairs(builder) do
    if s.override ~= nil then
        s.override:set_callback(update_visibility)
    end
    s.modifier:set_callback(update_visibility)
    s.body_yaw:set_callback(update_visibility)
end
update_visibility()

-------------------------------------------------------------------------------
-- Durum tespiti
-------------------------------------------------------------------------------

local ground_ticks = 0
local current_state = "Global"

local function detect_state(lp)
    local on_ground = bit.band(lp.m_fFlags, 1) ~= 0
    ground_ticks = on_ground and min(ground_ticks + 1, 64) or 0

    local crouching = lp.m_flDuckAmount > 0.7 or get("fakeduck")
    local moving = lp.m_vecVelocity:length2d() > 5

    -- Ziplama tusuna basildigi tick hala yerdeyiz, bu yuzden 2 tick bekliyoruz.
    if ground_ticks < 2 then
        return crouching and "Air crouch" or "Air"
    end
    if crouching then
        return moving and "Crouch move" or "Crouching"
    end
    if moving then
        return get("slowwalk") and "Slow walk" or "Moving"
    end
    return "Standing"
end

local function settings_for(state)
    local s = builder[state]
    if s.override ~= nil and s.override:get() then
        return s
    end
    return builder["Global"]
end

local MELEE = { CKnife = true, CKnifeGG = true, CWeaponTaser = true }

local function holding_melee(lp)
    local weapon = lp:get_player_weapon()
    if weapon == nil then
        return false
    end
    local ok, class = pcall(weapon.get_classname, weapon)
    return ok and MELEE[class] == true
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

local jitter = { side = false, cycles = 0 }
local brute = { stage = 0, time = 0, tick = -1 }

events.createmove:set(function(cmd)
    if not menu.enabled:get() then
        reset_overrides()
        return
    end

    local lp = entity.get_local_player()
    if lp == nil or not lp:is_alive() then
        return
    end

    current_state = detect_state(lp)
    local s = settings_for(current_state)

    -- Bir onceki paket gonderildiyse yeni choke dongusu basliyor demektir.
    -- Tarafi tick'e gore degil donguye gore cevirmek fakelag'da da jitter'i korur.
    local choked = cmd.choked_commands or globals.choked_commands or 0
    if choked == 0 then
        jitter.cycles = jitter.cycles + 1
        if jitter.cycles >= s.delay:get() then
            jitter.side = not jitter.side
            jitter.cycles = 0
        end
    end

    if brute.stage > 0 and globals.realtime - brute.time > menu.brute_reset:get() then
        brute.stage = 0
    end
    local phase = BRUTE_PHASES[brute.stage]

    local manual = menu.manual:get()
    local yaw_base = menu.yaw_base:get()
    local modifier = s.modifier:get()
    local freestand = menu.freestanding:get()
    local body = s.body_yaw:get()
    local left = s.left_limit:get()
    local right = s.right_limit:get()

    -- Manuelde kafa duvarin arkasinda sabit kalsin diye jitter'i kapatiyoruz.
    if manual ~= "Off" and body == "Jitter" then
        body = "Static"
    end

    local side
    if body == "Jitter" then
        side = jitter.side
    else
        side = menu.inverter:get()
    end
    if phase ~= nil then
        if phase.invert then
            side = not side
        end
        left = floor(left * phase.scale + 0.5)
        right = floor(right * phase.scale + 0.5)
    end

    local yaw_add
    if side then
        yaw_add = s.yaw_right:get()
    else
        yaw_add = s.yaw_left:get()
    end

    if manual ~= "Off" then
        yaw_base, yaw_add, modifier, freestand = "Local View", MANUAL_YAW[manual], "Disabled", false
    elseif freestand then
        yaw_add, modifier = 0, "Disabled"
    end

    if menu.safe_head:get() and current_state == "Air crouch" and holding_melee(lp) then
        yaw_add, modifier, body = 0, "Disabled", "Off"
    end

    override("aa_enabled", true)
    override("pitch", menu.pitch:get())
    override("yaw", "Backward")
    override("yaw_base", yaw_base)
    override("yaw_offset", yaw_add)
    override("yaw_modifier", modifier)
    override("modifier_offset", s.mod_offset:get())
    override("body_yaw", body ~= "Off")
    override("inverter", side)
    override("left_limit", left)
    override("right_limit", right)
    -- Neverlose'un kendi "Jitter" secenegini bilerek vermiyoruz, jitter'i lua yonetiyor.
    override("body_options", s.avoid_overlap:get() and OPTIONS_OVERLAP or OPTIONS_NONE)
    override("body_fs", body == "Static" and menu.body_fs:get() or "Off")
    override("freestanding", freestand)
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

-------------------------------------------------------------------------------
-- Indikatorler
-------------------------------------------------------------------------------

local WHITE = color(255, 255, 255, 255)
local DIM = color(255, 255, 255, 80)
local DEFAULT_ACCENT = color(150, 190, 255, 255)

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
    local accent = menu.accent ~= nil and menu.accent:get() or DEFAULT_ACCENT

    if menu.indicators:get() then
        local y = cy + 24
        render.text(1, vector(cx, y), accent, "c", SCRIPT)
        y = y + 12
        render.text(1, vector(cx, y), WHITE, "c", current_state:upper())
        y = y + 12
        render.text(1, vector(cx - 18, y), get("doubletap") and WHITE or DIM, "c", "DT")
        render.text(1, vector(cx, y), get("hideshots") and WHITE or DIM, "c", "HS")
        render.text(1, vector(cx + 18, y), menu.freestanding:get() and WHITE or DIM, "c", "FS")
        if brute.stage > 0 then
            y = y + 12
            render.text(1, vector(cx, y), accent, "c", ("BRUTE %d"):format(brute.stage))
        end
    end

    if menu.arrows:get() then
        local manual = menu.manual:get()
        render.text(1, vector(cx - 50, cy), manual == "Left" and accent or DIM, "c", "<")
        render.text(1, vector(cx + 50, cy), manual == "Right" and accent or DIM, "c", ">")
        render.text(1, vector(cx, cy - 50), manual == "Forward" and accent or DIM, "c", "^")
    end
end)

events.shutdown:set(reset_overrides)
