-- Mock Neverlose CS:GO API and test antiaim.lua inside Redis' Lua 5.1.
-- ARGV[1] = "none" (full suite), "norage" (no rage API, smoke), "notrace" (no utils.trace_bullet, smoke),
--           "badvalues" (NL rejects a combo value, smoke)
--           or a ui.find path to drop (smoke)
-- ARGV[2] = script source
local mode, src = ARGV[1], ARGV[2]
local full = mode == "none"
local out, fails = {}, 0
local bad_attempts = 0
local function log(s) out[#out + 1] = tostring(s) end
local function check(cond, msg)
    if cond then log("PASS " .. msg) else fails = fails + 1; log("FAIL " .. msg) end
end

local vec_mt = {}
vec_mt.__index = vec_mt
function vec_mt:length2d() return math.sqrt(self.x * self.x + self.y * self.y) end
local function vector(x, y, z) return setmetatable({ x = x or 0, y = y or 0, z = z or 0 }, vec_mt) end
local function color(r, g, b, a) return { r = r, g = g, b = b, a = a or 255 } end

local function contains(list, v)
    for _, x in ipairs(list) do if x == v then return true end end
    return false
end

-- Neverlose menu references -------------------------------------------------
local A, RB = "Aimbot>Anti Aim>Angles>", "Aimbot>Ragebot>Main>"
local SPEC = {
    [A .. "Enabled"]                       = { kind = "switch", value = false },
    [A .. "Pitch"]                         = { kind = "combo", value = "Disabled", items = { "Disabled", "Down", "Fake Down", "Fake Up" } },
    [A .. "Yaw"]                           = { kind = "combo", value = "Disabled", items = { "Disabled", "Backward", "Static" } },
    [A .. "Yaw>Base"]                      = { kind = "combo", value = "Local View", items = { "Local View", "At Target" } },
    [A .. "Yaw>Offset"]                    = { kind = "slider", value = 0, min = -180, max = 180 },
    [A .. "Yaw>Hidden"]                    = { kind = "switch", value = false },
    [A .. "Yaw>Avoid Backstab"]            = { kind = "switch", value = false },
    [A .. "Yaw Modifier"]                  = { kind = "combo", value = "Disabled", items = { "Disabled", "Center", "Offset", "Random", "Spin", "3-Way", "5-Way" } },
    [A .. "Yaw Modifier>Offset"]           = { kind = "slider", value = 0, min = -180, max = 180 },
    [A .. "Body Yaw"]                      = { kind = "switch", value = false },
    [A .. "Body Yaw>Inverter"]             = { kind = "switch", value = false },
    [A .. "Body Yaw>Left Limit"]           = { kind = "slider", value = 60, min = 0, max = 60 },
    [A .. "Body Yaw>Right Limit"]          = { kind = "slider", value = 60, min = 0, max = 60 },
    [A .. "Body Yaw>Options"]              = { kind = "selectable", value = { "Jitter" }, items = { "Avoid Overlap", "Jitter", "Randomize Jitter", "Anti Bruteforce" } },
    [A .. "Body Yaw>Freestanding"]         = { kind = "combo", value = "Off", items = { "Off", "Peek Fake", "Peek Real" } },
    [A .. "Freestanding"]                  = { kind = "switch", value = false },
    [A .. "Freestanding>Disable Yaw Modifiers"] = { kind = "switch", value = true },
    [A .. "Freestanding>Body Freestanding"]     = { kind = "switch", value = true },
    ["Aimbot>Anti Aim>Misc>Slow Walk"]     = { kind = "switch", value = false },
    ["Aimbot>Anti Aim>Misc>Fake Duck"]     = { kind = "switch", value = false },
    [RB .. "Double Tap"]                   = { kind = "switch", value = false },
    [RB .. "Double Tap>Lag Options"]       = { kind = "combo", value = "On Peek", items = { "On Peek", "Always On" } },
    [RB .. "Hide Shots"]                   = { kind = "switch", value = false },
    [RB .. "Hide Shots>Options"]           = { kind = "combo", value = "Favor Fire Rate",
                                             items = mode == "badvalues" and { "Default", "Break LC" } or { "Favor Fire Rate", "Break LC" } },
    [RB .. "Peek Assist"]                  = { kind = "switch", value = false },
    ["Aimbot>Ragebot>Safety>Safe Points"]  = { kind = "combo", value = "Default", items = { "Default", "Prefer", "Force" } },
    ["Aimbot>Ragebot>Safety>Body Aim"]     = { kind = "combo", value = "Default", items = { "Default", "Prefer", "Force" } },
    ["Aimbot>Ragebot>Selection>Min. Damage"] = { kind = "slider", value = 30, min = 0, max = 130 },
    ["Aimbot>Ragebot>Selection>Hitboxes"] = { kind = "selectable", value = { "Head", "Chest", "Stomach" },
                                             items = { "Head", "Chest", "Stomach", "Arms", "Legs", "Feet" } },
}
local SHORT = {
    enabled = A .. "Enabled", pitch = A .. "Pitch", yaw = A .. "Yaw", base = A .. "Yaw>Base",
    offset = A .. "Yaw>Offset", hidden = A .. "Yaw>Hidden", backstab = A .. "Yaw>Avoid Backstab",
    modifier = A .. "Yaw Modifier", mod_offset = A .. "Yaw Modifier>Offset", body = A .. "Body Yaw",
    inverter = A .. "Body Yaw>Inverter", left = A .. "Body Yaw>Left Limit", right = A .. "Body Yaw>Right Limit",
    options = A .. "Body Yaw>Options", body_fs = A .. "Body Yaw>Freestanding", fs = A .. "Freestanding",
    fs_mod = A .. "Freestanding>Disable Yaw Modifiers", fs_body = A .. "Freestanding>Body Freestanding",
    slowwalk = "Aimbot>Anti Aim>Misc>Slow Walk", fakeduck = "Aimbot>Anti Aim>Misc>Fake Duck",
    dt = RB .. "Double Tap", lag = RB .. "Double Tap>Lag Options", hs = RB .. "Hide Shots",
    hs_opt = RB .. "Hide Shots>Options", peek = RB .. "Peek Assist", safe = "Aimbot>Ragebot>Safety>Safe Points",
    body_aim = "Aimbot>Ragebot>Safety>Body Aim", min_damage = "Aimbot>Ragebot>Selection>Min. Damage",
    hitboxes = "Aimbot>Ragebot>Selection>Hitboxes",
}

local function valid(spec, v)
    if spec.kind == "switch" then return type(v) == "boolean" end
    if spec.kind == "combo" then return contains(spec.items, v) end
    if spec.kind == "slider" then return type(v) == "number" and v == math.floor(v) and v >= spec.min and v <= spec.max end
    if spec.kind == "selectable" then
        if type(v) ~= "table" then return false end
        for _, x in ipairs(v) do if not contains(spec.items, x) then return false end end
        return true
    end
end

local ref_mt = {}
ref_mt.__index = ref_mt
local reject_values = {}
function ref_mt:override(v)
    if v ~= nil and reject_values[self.path] ~= nil and reject_values[self.path][v] then
        error("locked")
    end
    if v ~= nil and not valid(self.spec, v) then
    if mode == "badvalues" then bad_attempts = bad_attempts + 1; error("invalid value " .. tostring(v)) end
        fails = fails + 1
        log("FAIL invalid override for " .. self.path .. ": " .. tostring(v))
    end
    self.ov = v
end
function ref_mt:get() if self.ov ~= nil then return self.ov end return self.spec.value end

local refs = {}
local ui = {}
local sidebar = {}
-- Mouse and menu: alpha > 0 = the Neverlose menu is open; down = left button held.
local mouse_state = { alpha = 0, pos = nil, down = false }
function ui.get_alpha() return mouse_state.alpha end
function ui.get_mouse_position() return mouse_state.pos end
-- Hotkeys: Peek Assist's key state is the menu value, whatever is overridden ("nobinds": no API).
if mode ~= "nobinds" then
    function ui.get_binds()
        local r = refs[SHORT.peek]
        local list = { { name = "Peek Assist", mode = 1, active = r ~= nil and r.spec.value == true, reference = r } }
        -- A held key on Body Aim (baim key): spec.bind = the value it sets.
        for short, name in pairs({ body_aim = "Body Aim", safe = "Safe Points" }) do
            local b = refs[SHORT[short]]
            if b ~= nil and b.spec.bind ~= nil then
                list[#list + 1] = { name = name, mode = 1, active = true, value = b.spec.bind, reference = b }
            end
        end
        return list
    end
end
function ui.find(...)
    local key = table.concat({ ... }, ">")
    if key == mode then error("element not found") end
    local spec = SPEC[key]
    if spec == nil then error("unknown path " .. key) end
    local r = setmetatable({ path = key, spec = spec }, ref_mt)
    refs[key] = r
    return r
end
function ui.sidebar(name, icon) sidebar.name, sidebar.icon = name, icon end

-- Lua menu elements ----------------------------------------------------------
local elements, element_count = {}, 0
local el_mt, group_mt = {}, {}
el_mt.__index = el_mt
group_mt.__index = group_mt

-- Neverlose text escapes in names (\a colors, \v accent, \r reset, \f<icon>) are stripped:
-- tests use plain names.
local function plain_name(text)
    local out = tostring(text):gsub("\a%x%x%x%x%x%x%x%x", ""):gsub("\a{[^}]*}", ""):gsub("\aDEFAULT", "")
    out = out:gsub("\f<[^>]*>", ""):gsub("[\v\r]", ""):gsub("^%s+", ""):gsub("%s+$", "")
    return out
end
local function new_el(kind, name, value, items)
    name = plain_name(name)
    local key = kind .. ":" .. name
    elements[key] = elements[key] or {}
    local e = setmetatable({ kind = kind, name = name, value = value, items = items, visible = true }, el_mt)
    table.insert(elements[key], e)
    element_count = element_count + 1
    return e
end
function el_mt:get() return self.value end
function el_mt:set(v)
    if self.items and self.kind == "combo" and not contains(self.items, v) then
        fails = fails + 1; log("FAIL test set invalid combo value " .. tostring(v) .. " for " .. self.name)
    end
    self.value = v
    if self.cb then self.cb(self) end
end
function el_mt:visibility(v) self.visible = v end
function el_mt:set_callback(fn) self.cb = fn end
function el_mt:tooltip() return self end
function el_mt:create() return setmetatable({ name = self.name .. " gear" }, group_mt) end
function el_mt:color_picker(def) return new_el("color", self.name, def) end

local function in_group(g, e) e.group = g.name; return e end
function group_mt:switch(name, def) return in_group(self, new_el("switch", name, def or false)) end
function group_mt:combo(name, items)
    if type(items) ~= "table" or #items == 0 then fails = fails + 1; log("FAIL combo without items " .. name) end
    return in_group(self, new_el("combo", name, items[1], items))
end
function group_mt:selectable(name, items) return in_group(self, new_el("selectable", name, {}, items)) end
function group_mt:slider(name, mn, mx, def)
    if def < mn or def > mx then fails = fails + 1; log("FAIL slider default out of range " .. name) end
    return in_group(self, new_el("slider", name, def))
end
function group_mt:label(text) return in_group(self, new_el("label", text, nil)) end
function group_mt:button(name, cb)
    local e = in_group(self, new_el("button", name, nil))
    e.click = function() cb() end
    return e
end
function group_mt:color_picker(name, def) return in_group(self, new_el("color", name, def)) end
function ui.create(tab, name) return setmetatable({ name = plain_name(tab) .. "/" .. plain_name(name) }, group_mt) end

-- Events ----------------------------------------------------------------------
local handlers = {}
local events = setmetatable({}, { __index = function(t, k)
    local ev = { set = function(_, fn) handlers[k] = fn end }
    rawset(t, k, ev)
    return ev
end })

-- World -------------------------------------------------------------------------
local lp = { m_fFlags = 1, m_flDuckAmount = 0, m_vecVelocity = vector(0, 0, 0), alive = true, m_iTeamNum = 2,
             m_bIsScoped = false, weapon_class = "CAK47", head = vector(0, 0, 64), origin = vector(0, 0, 0),
             m_MoveType = 2, m_nTickBase = 0, tb_shift = 0 }
function lp:is_alive() return self.alive end
function lp:get_player_weapon()
    local c = self.weapon_class
    return { get_classname = function() return c end, m_iItemDefinitionIndex = self.weapon_index,
        m_flNextPrimaryAttack = self.next_attack, m_iClip1 = self.clip }
end
function lp:get_hitbox_position() return self.head end
function lp:get_origin() return self.origin end
local function new_player(enemy, alive, origin)
    local p = { enemy = enemy, alive = alive, eye = vector(500, 0, 64), origin = origin or vector(500, 0, 0) }
    function p:is_enemy() return self.enemy end
    function p:is_alive() return self.alive end
    function p:get_eye_position() return self.eye end
    function p:get_origin() return self.origin end
    function p:is_dormant() return self.dormant == true end
    function p:get_index() return self.index end
    function p:get_name() return self.name or "player" end
    function p:get_xuid() return self.xuid end
    function p:get_player_weapon()
        local c = self.weapon_class
        if c == nil then return nil end
        return { get_classname = function() return c end }
    end
    return p
end
local enemy, mate, enemy2 = new_player(true, true), new_player(false, true), new_player(true, true)
enemy.index, enemy.name, mate.index, enemy2.index, enemy2.name = 5, "enemy5", 6, 7, "enemy7"
enemy2.eye = vector(0, 500, 64)
local players = { [5] = enemy, [6] = mate, [7] = enemy2, [1] = lp }
local NO_TRACE = function() return 0 end
-- line: ground under every point (0.5), hull: no walls (1).
local GROUND = function(from, to) if to.z < from.z then return 0.5 end return 1 end
local OPEN = function() return 1 end
local world = { threat = nil, rules = { m_bWarmupPeriod = false }, enemies = { enemy }, c4 = nil, hostages = {}, trace = NO_TRACE,
    line = GROUND, hull = OPEN }
local entity = {
    get_local_player = function() return lp end,
    get = function(id, is_userid) return players[id] end,
    get_threat = function() world.threat_calls = (world.threat_calls or 0) + 1; return world.threat end,
    get_game_rules = function() return world.rules end,
    get_players = function(enemies_only, dormant) return world.enemies end,
    get_entities = function(cls)
        if cls == "CPlantedC4" and world.c4 then return { world.c4 } end
        if cls == "CHostage" then return world.hostages end
        return {}
    end,
}

local aa = { inverter = false, target = 45, charge = 1, allow = nil, allow_calls = 0, teleports = 0 }
local rage = {
    antiaim = {
        inverter = function(_, v) if v ~= nil then aa.inverter = v end return aa.inverter end,
        get_target = function() return aa.target end,
        override_hidden_pitch = function(_, v) aa.hidden_pitch = v end,
        override_hidden_yaw_offset = function(_, v) aa.hidden_yaw = v end,
    },
    exploit = {
        get = function() return aa.charge end,
        allow_charge = function(_, v) aa.allow = v; aa.allow_calls = aa.allow_calls + 1 end,
        force_teleport = function() aa.teleports = aa.teleports + 1; if aa.consume then aa.charge = 0 end end,
    },
}

local globals = { tickcount = 0, realtime = 100, choked_commands = 0, frametime = 0.015 }
local texts, colors, polys, text_pos = {}, {}, 0, {}
local render = {
    screen_size = function() return vector(1920, 1080) end,
    text = function(font, pos, col, flags, txt) texts[#texts + 1] = txt; colors[txt] = col; text_pos[txt] = pos end,
    rect = function() end,
    poly = function() polys = polys + 1 end,
    measure_text = function(font, flags, txt) return vector(#txt * 5, 8) end,
}
local printed = {}
local expect_handler_error = false
-- Neverlose db: the full suite starts with a saved memory (one valid player, two invalid entries).
local SAVED_ID = "s:76561198000000099"
-- The mock keeps references (whether Neverlose serializes on write is unknown), so the
-- script must write copies of tables it keeps changing.
local db_store = mode == "none" and { ant_a_m_memory = { version = 1,
    brute = { [SAVED_ID] = { base = 2, name = "saved" }, ["n:bot"] = { base = 1 }, ["s:76561198000000098"] = { base = 9 } },
    resolver = { [SAVED_ID] = { name = "saved", results = { "h", "c", "c" },
        states = { Standing = { "x", "c", "c" }, Fly = { "c" }, Fakeduck = { "c", "h" } }, hits = 7, misses = -1 } },
    phases = { { shots = 10, hits = 1 }, { shots = 4, hits = 4 }, { shots = 2, hits = 5 }, "x" },
    sniper = { hs = { shots = 5, hits = 9 }, dt = { shots = 3, hits = 3 } } } }
    -- v4.6 kept peek in "move": a v4.6 save without a peek group gives peek the move data.
    or mode == "v46" and { ant_a_m_memory = { version = 1,
        phase_groups = { move = { { shots = 6, hits = 1 }, { shots = 2, hits = 2 } } } } } or nil
local db = db_store
local env = {
    ui = ui, events = events, entity = entity, globals = globals, render = render,
    rage = mode ~= "norage" and rage or nil, db = db,
    utils = mode ~= "notrace" and { trace_bullet = function(from, eye, to) return world.trace(to, from, eye) end,
        trace_line = function(from, to) return { fraction = world.line(from, to) } end,
        trace_hull = mode ~= "nohull" and function(from, to) return { fraction = world.hull(from, to) } end or nil } or nil,
    common = { is_button_down = function(key) return key == 1 and mouse_state.down end },
    vector = vector, color = color, bit = bit, math = math, table = table, string = string,
    pairs = pairs, ipairs = ipairs, pcall = pcall, type = type, tostring = tostring, tonumber = tonumber,
    setmetatable = setmetatable, error = error, select = select, unpack = unpack,
    print = function(...)
        local line = table.concat({ ... }, " ")
        printed[#printed + 1] = line
        -- A protected handler swallows its error and prints it once; that is a failure.
        if line:find("hata verdi", 1, true) and not expect_handler_error then fails = fails + 1; out[#out + 1] = "FAIL handler error: " .. line end
    end,
}

local fn, err = loadstring(src, "Nykle.win.lua")
if not fn then return { "FAIL syntax: " .. tostring(err) } end
setfenv(fn, env)
local ok, load_err = pcall(fn)
check(ok, "script loads " .. tostring(load_err or ""))
if not ok then return out end
check(handlers.createmove and handlers.render and handlers.bullet_impact and handlers.round_start
      and handlers.player_death and handlers.shutdown, "all event handlers registered")
log("INFO menu elements: " .. element_count)
for _, p in ipairs(printed) do log("INFO print: " .. p) end
check(printed[#printed] ~= nil and printed[#printed]:match("^%[Nykle%.win%] V%d+%.%d+ yuklendi") ~= nil,
      "version printed on load")
check(not full or printed[#printed]:match("yuklendi %(hafiza: 1 oyuncu%)$") ~= nil, "saved memory loaded: one valid player")
if full then check(#printed == 1, "every ui.find path resolved") end
local printed_at_load = #printed

-- Helpers -----------------------------------------------------------------------
local STATES = { "Global", "Standing", "Moving", "Slow walk", "Crouching", "Crouch move", "Peek", "Air", "Air crouch",
                 "Fake duck", "Manual", "Freestanding", "Safe head" }
-- Exploit controls exist for every state except Global and Fake duck.
local EXPLOIT_IDX = {}
do
    local n = 0
    for _, st in ipairs(STATES) do
        if st ~= "Global" and st ~= "Fake duck" then n = n + 1; EXPLOIT_IDX[st] = n end
    end
end
local IDX = {}
for i, s in ipairs(STATES) do IDX[s] = i end
local EXPLOIT_KEYS = { ["combo:Exploit"] = true, ["combo:Defensive"] = true, ["slider:Defensive every"] = true,
    ["combo:Hidden pitch"] = true, ["slider:Pitch value"] = true, ["combo:Hidden yaw"] = true,
    ["slider:Yaw value"] = true, ["label:Exploit"] = true }

local function E(kind, name, n)
    local list = elements[kind .. ":" .. name]
    local e = list and list[n or 1]
    if not e then fails = fails + 1; log("FAIL no element " .. kind .. ":" .. name .. " #" .. tostring(n or 1)) end
    return e or setmetatable({ value = nil }, el_mt)
end
-- Builder element of a state: Override and exploit settings do not exist for Global.
local function B(state, kind, name)
    local n = IDX[state]
    if name == "Override" then
        n = n - 1
    elseif EXPLOIT_KEYS[kind .. ":" .. name] then
        n = EXPLOIT_IDX[state]
    end
    return E(kind, name, n)
end
local function M(kind, name) return E(kind, name, 1) end
local function forget() E("button", "Forget learned enemies"):click() end

local function ov(short) local r = refs[SHORT[short]]; return r and r.ov end
local function side()
    if env.rage then return aa.inverter end
    return ov("inverter") == true
end
local function yaw_for(l, r) if side() then return r end return l end

local last_cmd
local function tick(choked, opts)
    globals.tickcount = globals.tickcount + 1
    globals.realtime = globals.realtime + 1 / 64
    globals.choked_commands = choked or 0
    aa.hidden_pitch, aa.hidden_yaw = nil, nil
    lp.m_nTickBase = globals.tickcount + lp.tb_shift
    local cmd = { command_number = globals.tickcount, in_jump = false, in_use = false }
    for k, v in pairs(opts or {}) do cmd[k] = v end
    last_cmd = cmd
    local okc, e = pcall(handlers.createmove, cmd)
    if not okc then fails = fails + 1; log("FAIL createmove error: " .. tostring(e)) end
    return cmd
end
local function advance(n) for _ = 1, n do tick(0) end end
local function same_color(a, r, g, b) return a ~= nil and a.r == r and a.g == g and a.b == b end
local function draw()
    texts, colors, polys, text_pos = {}, {}, 0, {}
    local okr, e = pcall(handlers.render)
    if not okr then fails = fails + 1; log("FAIL render error: " .. tostring(e)) end
end
local function reset_world()
    lp.m_fFlags, lp.m_flDuckAmount, lp.m_vecVelocity = 1, 0, vector(0, 0, 0)
    lp.weapon_class, lp.weapon_index, lp.m_iTeamNum, lp.m_MoveType, lp.tb_shift = "CAK47", 7, 2, 2, 0
    world.threat, world.c4, world.hostages, world.trace, world.line, world.hull = nil, nil, {}, NO_TRACE, GROUND, OPEN
    for _, short in ipairs({ "slowwalk", "peek", "fakeduck" }) do
        if refs[SHORT[short]] then refs[SHORT[short]].spec.value = false end
    end
    for _ = 1, 4 do tick(0) end
end

-- Smoke run for degraded environments --------------------------------------------
if not full then
    lp.m_vecVelocity = vector(250, 0, 0); tick(0); tick(0)
    -- After the first tick: it applies the recommended settings. Enforcement off so test values stay.
    M("switch", "Always use recommended settings"):set(false)
    M("switch", "Auto when standing still"):set(false)
    M("switch", "High ground"):set(true)
    M("switch", "Air lag (defensive every tick)"):set(false); M("switch", "Snipers use DT in the air"):set(false)
    M("switch", "Resolver panel"):set(false)
    B("Standing", "slider", "Delay randomize"):set(0)
    lp.m_fFlags = 0; tick(0); lp.m_flDuckAmount = 1; lp.weapon_class = "CKnife"; tick(0)
    reset_world()
    M("combo", "Manual yaw"):set("Left"); tick(0); M("combo", "Manual yaw"):set("Off")
    M("switch", "Freestanding"):set(true); tick(0); M("switch", "Freestanding"):set(false)
    tick(0, { in_use = true }); tick(0, { in_use = true }); tick(0, { in_use = true })
    world.rules.m_bWarmupPeriod = true; tick(0); world.rules.m_bWarmupPeriod = false
    local s0 = side(); tick(0); check(side() ~= s0, "jitter still flips")
    if mode == "notrace" then
    reset_world()
    world.threat = new_player(true, true, vector(500, 0, -50)); tick(0); tick(0)
    check(ov("offset") == 0, "without traces high ground safe head falls back to height only")
    world.threat = new_player(true, true, vector(500, 0, 0))
    lp.m_vecVelocity = vector(250, 0, 0); advance(3)
    check(ov("offset") == yaw_for(-20, 50) and ov("lag") == "On Peek", "without traces auto peek stays out of the way")
    reset_world()
end
    if mode == "nohull" then
        -- Hide shots teleport where Neverlose does spend the charge: it keeps working.
        reset_world()
        world.threat = enemy; lp.weapon_class = "CWeaponSSG08"; world.trace = function() return 30 end
        aa.consume = true; aa.charge = 1; advance(4); lp.m_fFlags = 0; lp.m_vecVelocity = vector(250, 0, 0)
        local t0 = aa.teleports
        advance(3)
        check(aa.teleports == t0 + 1 and aa.charge == 0, "hide shots teleport spends the charge")
        aa.charge = 1; lp.m_fFlags = 1; advance(8); lp.m_fFlags = 0; advance(3)
        check(aa.teleports == t0 + 2, "so hide shots keeps teleporting (next jump)")
        aa.consume = false; lp.m_fFlags = 1; lp.m_vecVelocity = vector(0, 0, 0); aa.charge = 1
        reset_world()
        world.threat = enemy; lp.weapon_class = "CWeaponSSG08"; lp.origin = vector(0, 0, 0)
        world.trace = function(_, from, eye) if from == lp and eye ~= nil and eye.y >= 20 then return 150 end return 0 end
        refs[SHORT.peek].spec.value = true
        tick(0, { view_angles = vector(0, 0, 0) }); tick(0, { view_angles = vector(0, 0, 0) })
        local c = tick(0, { view_angles = vector(0, 0, 0) })
        check(c.sidemove ~= nil and c.sidemove < -449, "AI peek without trace_hull: two line traces check the path")
        refs[SHORT.peek].spec.value = false; advance(5); refs[SHORT.peek].spec.value = true
        world.line = function(from, to) if to.z < from.z then return 0.5 end if to.y > 20 and from.z > 50 then return 0.5 end return 1 end
        tick(0, { view_angles = vector(0, 0, 0) }); tick(0, { view_angles = vector(0, 0, 0) })
        c = tick(0, { view_angles = vector(0, 0, 0) })
        check(c.sidemove == nil, "a wall at head height (the upper line) blocks the path")
        refs[SHORT.peek].spec.value = false
        reset_world()
    end
    if mode == "nobinds" then
        reset_world()
        world.threat = enemy; lp.weapon_class = "CWeaponSSG08"; lp.origin = vector(0, 0, 0)
        world.trace = function(_, from, eye) if from == lp and eye ~= nil and eye.y >= 20 then return 150 end return 0 end
        local c = tick(0, { view_angles = vector(0, 0, 0) }); c = tick(0, { view_angles = vector(0, 0, 0) })
        check(c.sidemove == nil and ov("peek") == nil, "without ui.get_binds: no AI peek while the key is not held")
        refs[SHORT.peek].spec.value = true
        for _ = 1, 4 do c = tick(0, { view_angles = vector(0, 0, 0) }) end
        check(c.sidemove ~= nil and c.sidemove < -449 and ov("peek") == false,
              "without ui.get_binds: the walk goes on while Peek Assist is overridden")
        refs[SHORT.peek].spec.value = false; advance(90); c = tick(0, { view_angles = vector(0, 0, 0) })
        check(c.sidemove == nil and ov("peek") == nil, "and ends by itself after the key is released")
        reset_world()
    end
    if mode == "v46" then
        M("switch", "Stats panel"):set(true); draw(); M("switch", "Stats panel"):set(false)
        check(contains(texts, "PEEK   0* 1/6   1 2/2   2 0/0   3 0/0   4 0/0   5 0/0")
              and contains(texts, "HAREKET   0* 1/6   1 2/2   2 0/0   3 0/0   4 0/0   5 0/0")
              and contains(texts, "HAVA   0* 0/0   1 0/0   2 0/0   3 0/0   4 0/0   5 0/0"),
              "a v4.6 save: peek starts from the movement statistics, missing groups stay empty")
    end
    if mode == "badvalues" then
        local reports = 0
        for i = printed_at_load + 1, #printed do
            if printed[i]:find("ayarlanamadi", 1, true) then reports = reports + 1 end
        end
        check(reports == 1, "rejected value reported exactly once (" .. reports .. ")")
        local attempts = bad_attempts
        advance(10)
        check(bad_attempts == attempts, "rejected value is not retried every tick")
        advance(330)
        check(bad_attempts > attempts, "rejected value is retried after a while")
        local reports_after = 0
        for i = printed_at_load + 1, #printed do
            if printed[i]:find("ayarlanamadi", 1, true) then reports_after = reports_after + 1 end
        end
        check(reports_after == 1, "retries do not spam the console")
        check(ov("lag") ~= nil, "other overrides keep working after a rejected value")
    end
    draw()
    check(contains(texts, "Nykle.win"), "indicators render")
    check(mode ~= "notrace" or not contains(texts, "VIS"), "no VIS indicator without traces")
    handlers.shutdown()
    log(fails == 0 and "ALL PASSED" or ("FAILURES: " .. fails))
    return out
end

-- Auto freestanding is on by default; the suite exercises the standing AA and turns it
-- off here, its own section tests it.
check(M("switch", "Auto when standing still"):get() == true, "auto freestanding when standing still is on by default")
M("switch", "Always use recommended settings"):set(false)
M("switch", "Auto when standing still"):set(false)
-- High ground safe head is off by default (v4.8 logs); its own tests turn it on.
check(M("switch", "High ground"):get() == false, "high ground safe head is off by default")
M("switch", "High ground"):set(true)
-- Air lag and sniper DT in the air are on by default; the suite tests the plain air AA and
-- turns them off here, their own section tests them.
check(M("switch", "Air lag (defensive every tick)"):get() == true and M("switch", "Snipers use DT in the air"):get() == false,
      "air lag on, sniper DT in the air off by default (V1.0: landing restarted the hide shots charge)")
M("switch", "Air lag (defensive every tick)"):set(false); M("switch", "Snipers use DT in the air"):set(false)
check(M("switch", "Resolver panel"):get() == true, "resolver panel on by default")
M("switch", "Resolver panel"):set(false)

-- Saved memory --------------------------------------------------------------------
do
    local xuid_enemy = new_player(true, true); xuid_enemy.index, xuid_enemy.name, xuid_enemy.xuid = 11, "renamed", "76561198000000099"
    players[11] = xuid_enemy; world.threat = xuid_enemy; tick(0); tick(0)
    check(ov("offset") == yaw_for(-23, 51) + 15 and ov("safe") == "Force" and ov("body_aim") == "Prefer",
          "a player remembered from an earlier game: learned phase, resolver level and body aim from the first tick")
    handlers.aim_ack({ target = 11, hitgroup = 1, damage = 100 }); handlers.level_init()
    local m = db.ant_a_m_memory
    local r = m.resolver[SAVED_ID]
    check(m.brute[SAVED_ID].base == 2 and m.brute["n:bot"] == nil and m.brute["s:76561198000000098"] == nil
          and #r.results == 4 and r.states.Fly == nil and #r.states.Standing == 3 and r.states.Standing[1] == "c"
          and r.states.Standing[3] == "h", "invalid saved entries, states and results are dropped on load")
    check(r.hits == 8 and r.misses == nil, "saved resolver totals: a valid count is kept and counted on, an invalid one dropped")
    check(r.states.Fakeduck ~= nil and #r.states.Fakeduck == 2, "the fake duck state is saved and loaded too")
    players[11] = nil; world.threat = nil; tick(0)
    M("switch", "Stats panel"):set(true); draw(); M("switch", "Stats panel"):set(false)
    check(contains(texts, "YERDE   0* 1/10   1 4/4   2 0/0   3 0/0   4 0/0   5 0/0") and contains(texts, "HAVA   0* 1/10   1 4/4   2 0/0   3 0/0   4 0/0   5 0/0")
          and #m.phase_groups.move == 6 and m.phase_groups.move[1].shots == 10,
          "v4.5 phase statistics loaded into every movement group (invalid ones dropped) and written back per group")
    check(contains(texts, "SNIPER   HS* 0/0   DT 3/3"), "saved sniper statistics loaded, invalid ones dropped")
end

-- Defaults: standing ------------------------------------------------------------
tick(0)
check(ov("enabled") == true and ov("pitch") == "Down" and ov("yaw") == "Backward" and ov("base") == "At Target",
      "base overrides applied")
check(ov("backstab") == true and ov("fs_mod") == false and ov("fs_body") == false, "backstab on, NL freestanding extras off")
check(ov("body") == true and #ov("options") == 0, "body yaw on, NL jitter option stripped")
check(ov("offset") == yaw_for(-23, 51) and ov("left") == 60, "standing defaults used out of the box")
check(ov("dt") == true and ov("hs") == false, "auto exploit forces double tap")
check(ov("lag") == "On Peek" and ov("hs_opt") == "Favor Fire Rate", "standing defensive is NL on-peek")
-- V1.0: no hidden angles while standing still (they only moved the head out of cover; standing
-- still breaks no lag compensation).
check(ov("hidden") == false and aa.hidden_pitch == nil and aa.hidden_yaw == nil
      and B("Standing", "combo", "Hidden pitch"):get() == "Off" and B("Standing", "combo", "Hidden yaw"):get() == "Off"
      and B("Crouching", "combo", "Hidden yaw"):get() == "Off" and B("Peek", "combo", "Hidden yaw"):get() == "Off",
      "standing, crouching and peek: no hidden angles")
do
    -- Moving keeps them: pitch up, random yaw that does not follow the desync side (Sideways gave +-90 by side).
    lp.m_vecVelocity = vector(250, 0, 0); tick(0); tick(0)
    check(ov("hidden") == true and aa.hidden_pitch == -89 and B("Moving", "combo", "Hidden yaw"):get() == "Random",
          "moving: hidden pitch up / yaw random")
    local values, by_side = {}, 0
    for _ = 1, 30 do
        tick(0)
        if aa.hidden_yaw ~= nil then
            values[aa.hidden_yaw] = true
            if math.abs(aa.hidden_yaw) == 90 and (aa.hidden_yaw > 0) == side() then by_side = by_side + 1 end
        end
    end
    local n = 0
    for _ in pairs(values) do n = n + 1 end
    check(n >= 10 and by_side < 10, "the hidden yaw is random, it does not give away the desync side")
    lp.m_vecVelocity = vector(0, 0, 0); tick(0); tick(0)
end

check(B("Standing", "slider", "Delay randomize"):get() == 1 and B("Peek", "slider", "Delay randomize"):get() == 1
      and B("Air", "slider", "Delay randomize"):get() == 1, "jitter states randomize the flip delay by default")
check(B("Fake duck", "slider", "Delay randomize"):get() == 0 and B("Manual", "slider", "Delay randomize"):get() == 0
      and B("Safe head", "slider", "Delay randomize"):get() == 0, "static states keep a fixed delay")
-- The suite changes settings to exercise code paths; enforcement is tested in its own section.
M("switch", "Always use recommended settings"):set(false)
do
    -- With randomize 1 the side is held for 1 or 2 packet cycles, never longer.
    local holds, run, last = {}, 0, side()
    for _ = 1, 60 do
        tick(0)
        if side() == last then run = run + 1 else holds[#holds + 1] = run + 1; run = 0; last = side() end
    end
    local ones, twos, longer = 0, 0, 0
    for _, h in ipairs(holds) do if h == 1 then ones = ones + 1 elseif h == 2 then twos = twos + 1 else longer = longer + 1 end end
    check(ones > 0 and twos > 0 and longer == 0, "randomized jitter holds a side for 1 or 2 cycles")
end
B("Standing", "slider", "Delay randomize"):set(0); advance(3)
local s0 = side()
tick(0)
check(side() == not s0 and ov("offset") == yaw_for(-23, 51), "jitter flips and stays synced")
local cur = side()
for c = 1, 13 do tick(c) end
check(side() == cur, "no flip while choking")
tick(0)
check(side() == not cur, "flip on new choke cycle")

B("Standing", "slider", "Jitter delay"):set(3)
cur = side()
local seq = {}
for i = 1, 6 do tick(0); seq[i] = side() end
check(seq[1] == cur and seq[2] == cur and seq[3] == not cur and seq[4] == not cur and seq[5] == not cur and seq[6] == cur,
      "jitter delay 3 with exploit flips every third cycle")
aa.charge = 0.4
cur = side(); tick(0); local a1 = side(); tick(0); local a2 = side()
check(a1 == not cur and a2 == cur, "delay ignored while DT is recharging")
aa.charge = 1
B("Standing", "slider", "Jitter delay"):set(1)

-- Hide shots recharge is left alone until the charge value is seen to follow HS ---------------
world.threat = enemy; world.trace = function() return 30 end
lp.weapon_class, aa.charge = "CWeaponSSG08", 0; tick(0)
handlers.weapon_fire({ userid = 1 }); tick(0); tick(0)
check(ov("hs") == true and aa.allow ~= false, "hide shots: no hold while the charge value is not known to follow HS")
handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 2, dmg_health = 20, weapon = "ssg08" })
check(printed[#printed]:find("| HS LC, DEF ", 1, true) ~= nil,
      "hide shots: no percent while the charge value is unknown; LC = our Break LC is on (seen)")
aa.charge = 1; reset_world()

-- No state forces always-on defensive by default -------------------------------------
local ALWAYS_ON_BEFORE = { "Crouch move", "Peek", "Air", "Air crouch" }
for _, st in ipairs({ "Moving", "Slow walk", "Crouch move", "Peek", "Air", "Air crouch" }) do
    check(B(st, "combo", "Defensive"):get() == "Smart", st .. " defaults to smart defensive")
end
for _, st in ipairs({ "Standing", "Crouching", "Manual", "Freestanding", "Safe head" }) do
    check(B(st, "combo", "Defensive"):get() == "On peek", st .. " defaults to NL on-peek defensive")
end
check(M("switch", "Safe recharge"):get() == true, "safe recharge on by default")
do
    local changes = 0
    local last = ov("lag")
    local function watch() if ov("lag") ~= last then changes = changes + 1; last = ov("lag") end end
    lp.m_fFlags = 0; tick(0); watch()
    lp.m_flDuckAmount = 1; tick(0); watch()
    lp.m_fFlags = 1; advance(4); watch()
    lp.m_vecVelocity = vector(150, 0, 0); advance(2); watch()
    refs[SHORT.peek].spec.value = true; advance(2); watch()
    check(changes == 0 and ov("lag") == "On Peek", "defaults never switch the defensive mode between states")
    refs[SHORT.peek].spec.value = false
end
reset_world()
-- The rest of the suite exercises the always-on code path explicitly.
for _, st in ipairs(ALWAYS_ON_BEFORE) do
    B(st, "combo", "Defensive"):set("Always on")
end
reset_world()

-- Movement states and their own exploits --------------------------------------------
lp.m_vecVelocity = vector(250, 0, 0); tick(0)
check(ov("offset") == yaw_for(-20, 50) and ov("left") == 58 and ov("lag") == "On Peek", "moving defaults")
lp.m_vecVelocity = vector(7, 0, 0); tick(0)
check(ov("offset") == yaw_for(-20, 50), "speed hysteresis keeps moving")
lp.m_vecVelocity = vector(4, 0, 0); tick(0)
check(ov("offset") == yaw_for(-23, 51), "slow speed returns to standing")

refs[SHORT.slowwalk].spec.value = true
lp.m_vecVelocity = vector(80, 0, 0); tick(0)
check(ov("offset") == yaw_for(-23, 51) and ov("left") == 58, "slow walk defaults")
refs[SHORT.slowwalk].spec.value = false
lp.m_vecVelocity = vector(0, 0, 0); tick(0)

lp.m_flDuckAmount = 1; tick(0)
check(ov("offset") == yaw_for(-20, 30) and ov("lag") == "On Peek", "crouching defaults")
lp.m_flDuckAmount = 0.6; tick(0)
check(ov("offset") == yaw_for(-20, 30), "duck hysteresis keeps crouching")
lp.m_vecVelocity = vector(100, 0, 0); lp.m_flDuckAmount = 1; tick(0)
do
    -- Over several flips: "Switch" would give 89 on one desync side.
    local up = aa.hidden_pitch == -89
    for _ = 1, 12 do tick(0); up = up and aa.hidden_pitch == -89 end
    check(ov("lag") == "Always On" and up, "crouch move: defensive always on, pitch up (switch gave the side away)")
end
lp.m_flDuckAmount = 0.4; lp.m_vecVelocity = vector(0, 0, 0); tick(0)
check(ov("offset") == yaw_for(-23, 51), "un-duck returns to standing")

refs[SHORT.peek].spec.value = true; tick(0)
check(ov("offset") == yaw_for(-23, 51) and ov("hidden") == false,
      "Peek Assist held while standing still: the standing AA stays (V1.0: it switched to Peek at once)")
lp.m_vecVelocity = vector(100, 0, 0); tick(0)
check(ov("offset") == yaw_for(-20, 45) and ov("lag") == "Always On" and aa.hidden_pitch == nil and ov("hidden") == false,
      "peek state (moving with the key): defensive always on, no hidden angles (V1.0)")
lp.m_vecVelocity = vector(0, 0, 0); tick(0)
refs[SHORT.peek].spec.value = false

lp.m_fFlags = 0; tick(0)
check(ov("offset") == yaw_for(-13, 34) and ov("lag") == "Always On", "air: defensive always on")
check(aa.hidden_pitch == -89 and aa.hidden_yaw ~= nil and aa.hidden_yaw >= -180 and aa.hidden_yaw <= 180, "air hidden pitch up + spin")
local spin1 = aa.hidden_yaw; tick(0)
check(aa.hidden_yaw ~= spin1, "air hidden yaw spins")
lp.m_fFlags = 1; tick(0)
check(ov("offset") == yaw_for(-13, 34), "first ground tick still air")
tick(0)
check(ov("offset") == yaw_for(-13, 34), "second ground tick still air")
tick(0)
check(ov("offset") == yaw_for(-23, 51), "standing after landing grace")
tick(0, { in_jump = true })
check(ov("offset") == yaw_for(-13, 34), "jump key counts as air")
lp.m_fFlags = 0; lp.m_flDuckAmount = 1; tick(0)
check(ov("offset") == yaw_for(-15, 44) and ov("lag") == "Always On" and aa.hidden_yaw ~= nil, "air crouch: own exploit")
reset_world()

-- Override off inherits Global AA but keeps the state's exploit ------------------------
B("Standing", "switch", "Override"):set(false); tick(0)
check(ov("offset") == yaw_for(-20, 40) and ov("lag") == "On Peek", "override off uses Global AA, keeps standing exploit")
B("Standing", "switch", "Override"):set(true)

-- Safe head ------------------------------------------------------------------------------
lp.m_fFlags = 0; lp.m_flDuckAmount = 1; lp.weapon_class = "CKnife"; tick(0); tick(0)
check(ov("offset") == 0 and ov("left") == 30 and ov("body") == true and ov("body_fs") == "Off"
      and B("Safe head", "combo", "Body yaw"):get() == "Random", "safe head with knife: yaw 0, random desync side")
check(ov("lag") == "On Peek" and ov("hs_opt") == "Favor Fire Rate" and ov("hidden") == false, "safe head turns defensive off")
lp.weapon_class = "CWeaponTaser"; tick(0)
check(ov("offset") == 0, "safe head with zeus")
M("switch", "Knife/Zeus in air crouch"):set(false); tick(0)
check(ov("offset") == yaw_for(-15, 44), "knife safe head can be disabled")
M("switch", "Knife/Zeus in air crouch"):set(true)
reset_world()
world.threat = new_player(true, true, vector(500, 0, -50)); tick(0); tick(0)
check(ov("offset") == yaw_for(-23, 51), "high ground but out of sight: no safe head")
world.trace = function() return 30 end; M("switch", "High ground"):set(false); tick(0); tick(0)
check(ov("offset") == yaw_for(-23, 51) and ov("left") == 60, "high ground safe head off (default): the standing AA stays")
M("switch", "High ground"):set(true); tick(0); tick(0)
check(ov("offset") == 0 and ov("left") == 30, "high ground safe head when visible")
lp.m_vecVelocity = vector(250, 0, 0); tick(0)
check(ov("offset") == 0, "high ground safe head also while moving in sight")
lp.m_vecVelocity = vector(0, 0, 0)
world.threat = new_player(true, true, vector(500, 0, 0)); tick(0); tick(0)
check(ov("offset") == yaw_for(-23, 51), "same height is not safe head")
reset_world()

-- Manual ------------------------------------------------------------------------------
M("combo", "Manual yaw"):set("Left"); tick(0); tick(0)
check(ov("base") == "Local View" and ov("offset") == -90 and ov("modifier") == "Disabled" and ov("fs") == false, "manual left")
check(side() == false and ov("lag") == "On Peek" and ov("hidden") == false, "manual is static, no hidden AA")
M("switch", "Static inverter"):set(true); tick(0)
check(side() == true, "static inverter respected")
M("switch", "Static inverter"):set(false)
M("combo", "Manual yaw"):set("Right"); tick(0)
check(ov("offset") == 90, "manual right")
M("combo", "Manual yaw"):set("Forward"); tick(0)
check(ov("offset") == 180, "manual forward")
M("combo", "Manual yaw"):set("Off")

-- Freestanding -------------------------------------------------------------------------
M("switch", "Freestanding"):set(true); tick(0)
check(ov("fs") == true and ov("offset") == 0 and ov("base") == "At Target", "freestanding state with target")
aa.target = nil; tick(0)
check(ov("fs") == true and ov("offset") == yaw_for(-23, 51), "no target: movement state, freestanding stays armed")
aa.target = 45
lp.m_fFlags = 0; tick(0)
check(ov("fs") == false and ov("offset") == yaw_for(-13, 34), "freestanding disabled in air by default")
M("switch", "Disable in air"):set(false); tick(0)
check(ov("fs") == true and ov("offset") == 0, "air disabler can be turned off")
M("switch", "Disable in air"):set(true)
reset_world()
M("switch", "Freestanding"):set(true)
world.threat = new_player(true, true, vector(500, 0, 0)); world.trace = function() return 30 end; tick(0); tick(0)
check(ov("fs") == true and ov("offset") == yaw_for(-23, 51), "head still exposed: freestanding failed, back to jitter")
M("switch", "Freestanding"):set(false)
reset_world()

-- Auto peek ---------------------------------------------------------------------------------
world.threat = new_player(true, true, vector(500, 0, 0))
world.trace = function() return 30 end
lp.m_vecVelocity = vector(250, 0, 0); tick(0); tick(0)
check(ov("offset") == yaw_for(-20, 45) and ov("lag") == "Always On", "moving in sight of the threat is a peek")
world.trace = NO_TRACE; advance(4)
check(ov("offset") == yaw_for(-20, 45) and ov("lag") == "Always On", "peek holds briefly after sight is lost")
advance(10)
check(ov("offset") == yaw_for(-20, 50) and ov("lag") == "On Peek", "back to moving after the hold")
world.trace = function(to) return to.x > 10 and 30 or 0 end; advance(2)
check(ov("offset") == yaw_for(-20, 45) and ov("lag") == "Always On", "about to come into sight counts as a peek")
world.trace = function() return 30 end; lp.m_vecVelocity = vector(0, 0, 0); advance(2)
check(ov("offset") == yaw_for(-23, 51), "stopping in sight is holding an angle, not a peek")
M("switch", "Auto peek"):set(false); lp.m_vecVelocity = vector(250, 0, 0); advance(2)
check(ov("offset") == yaw_for(-20, 50) and ov("lag") == "On Peek", "auto peek can be disabled")
M("switch", "Auto peek"):set(true)
world.enemies = { world.threat }; world.threat.dormant = true; advance(12)
check(ov("offset") == yaw_for(-20, 50) and ov("lag") == "On Peek", "dormant threat is ignored")
world.enemies = { enemy }
reset_world()

-- X-Way -------------------------------------------------------------------------------------
B("Standing", "combo", "Yaw mode"):set("X-Way")
local seen, sides = {}, {}
for i = 1, 6 do tick(0); seen[i] = ov("offset"); sides[i] = side() end
check(contains(seen, -30) and contains(seen, 0) and contains(seen, 30) and seen[1] == seen[4] and seen[2] == seen[5],
      "3-way cycles through its angles")
check(sides[1] ~= sides[2] and sides[2] ~= sides[3], "desync keeps alternating in X-Way")
B("Standing", "slider", "Ways"):set(5)
seen = {}
for i = 1, 10 do tick(0); seen[i] = ov("offset") end
check(contains(seen, -15) and contains(seen, 15) and seen[1] == seen[6] and seen[3] == seen[8], "5-way cycles through five angles")
B("Standing", "slider", "Ways"):set(3)
B("Standing", "combo", "Yaw mode"):set("L&R"); tick(0)
check(ov("offset") == yaw_for(-23, 51), "back to L&R")

-- Exploit choices ------------------------------------------------------------------------
B("Standing", "combo", "Exploit"):set("Hide shots"); tick(0)
check(ov("dt") == false and ov("hs") == true and ov("lag") == "On Peek" and ov("hs_opt") == "Favor Fire Rate", "hide shots on peek")
B("Standing", "combo", "Defensive"):set("Always on"); tick(0)
check(ov("lag") == "Always On" and ov("hs_opt") == "Break LC", "hide shots always on breaks LC")
B("Standing", "combo", "Exploit"):set("Binds"); tick(0)
check(ov("dt") == nil and ov("hs") == nil, "binds mode leaves DT/HS alone")
check(ov("lag") == "On Peek" and ov("hidden") == false, "no exploit bound: defensive off")
B("Standing", "combo", "Exploit"):set("Double tap")
B("Standing", "combo", "Defensive"):set("Tick based")
local hits, misses = 0, 0
for _ = 1, 28 do
    local c = tick(0)
    if c.force_defensive == true then hits = hits + 1 elseif c.force_defensive == false then misses = misses + 1 end
end
check(hits == 2 and misses == 26 and ov("lag") == "On Peek", "tick based defensive every 14 commands")
B("Standing", "combo", "Defensive"):set("On peek")
M("switch", "Auto exploit"):set(false); tick(0)
check(ov("dt") == nil and ov("hs") == nil, "auto exploit can be disabled")
M("switch", "Auto exploit"):set(true)
refs[SHORT.fakeduck].spec.value = true; refs[SHORT.dt].spec.value = true; tick(0)
check(ov("dt") == nil and ov("hs") == nil, "fake duck leaves DT/HS alone")
check(ov("lag") == "On Peek" and ov("hidden") == false, "fake duck turns defensive off even with DT bound")
refs[SHORT.fakeduck].spec.value = false; refs[SHORT.dt].spec.value = false
lp.weapon_class = "CHEGrenade"; tick(0)
check(ov("dt") == true and ov("lag") == "On Peek" and ov("hidden") == false, "grenade turns defensive off")
reset_world()

-- Anti-bruteforce ----------------------------------------------------------------------
B("Standing", "combo", "Body yaw"):set("Static"); tick(0)
local near = { userid = 5, x = -500, y = 6, z = 64 }
handlers.bullet_impact({ userid = 5, x = -500, y = 400, z = 64 }); tick(0)
check(side() == false and ov("left") == 60, "far bullet ignored")
handlers.bullet_impact({ userid = 6, x = -500, y = 0, z = 64 }); tick(0)
check(side() == false, "teammate bullet ignored")
handlers.bullet_impact(near); handlers.bullet_impact(near); tick(0)
check(side() == true and ov("left") == 60, "brute phase 1 inverts (dedup same tick)")
tick(0); handlers.bullet_impact(near); tick(0)
check(side() == true and ov("left") == 60, "second shot of an enemy DT burst counts once")
check(ov("offset") == 51, "brute phase 1 turns the static head with the desync")
advance(8); handlers.bullet_impact(near); tick(0)
check(side() == false and ov("left") == 60 and ov("offset") == -23 + 15, "brute phase 2 keeps full desync and shifts head")
advance(8); handlers.bullet_impact(near); tick(0)
check(side() == true and ov("left") == 51 and ov("offset") == 51 - 15, "brute phase 3")
advance(8); handlers.bullet_impact(near); tick(0); draw()
check(ov("left") == 60 and ov("offset") == -23 and contains(texts, "BRUTE 4"), "brute phase 4: full desync, yaw unchanged")
do
    local drawn = {}
    for _ = 1, 30 do tick(0); drawn[side()] = true end
    check(drawn[true] and drawn[false], "phase 4 draws the desync side at random, independent of the yaw")
end
advance(8); handlers.bullet_impact(near); tick(0); draw()
check(ov("body_fs") == "Peek Fake" and contains(texts, "BRUTE 5") and ov("left") == 60,
      "brute phase 5: static desync, Neverlose's body freestanding (Peek Fake) picks the side")
check(ov("offset") == -23, "phase 5: the yaw stays the state's own")
do
    -- V1.0 log: a headshot in fake duck at phase 5. States with their own AA (fake duck, safe head,
    -- manual) do not take phase 5: Static + Peek Fake overrode the fake duck's random side.
    refs[SHORT.fakeduck].spec.value = true
    local drawn = {}
    for _ = 1, 30 do tick(0); drawn[side()] = true end
    check(ov("body_fs") == "Off" and drawn[true] and drawn[false],
          "phase 5 in fake duck: the fake duck's random side stays (no Peek Fake)")
    refs[SHORT.fakeduck].spec.value = false
    M("combo", "Manual yaw"):set("Left"); tick(0)
    check(ov("body_fs") == "Off", "phase 5 with manual yaw: the manual AA stays")
    M("combo", "Manual yaw"):set("Off"); tick(0)
    check(ov("body_fs") == "Peek Fake", "back to a movement state: phase 5 again")
end
advance(8); handlers.bullet_impact(near); tick(0)
check(side() == true and ov("left") == 60 and ov("body_fs") == "Off", "brute wraps to phase 1")
draw()
check(contains(texts, "BRUTE 1"), "brute indicator shown")
globals.realtime = globals.realtime + 7; tick(0)
check(side() == false and ov("left") == 60, "brute resets after timeout")
advance(8); handlers.bullet_impact(near); tick(0)
handlers.round_start({}); tick(0)
check(side() == false, "brute resets on round start")
advance(8); handlers.bullet_impact(near); tick(0)
handlers.player_death({ userid = 1 }); tick(0)
check(side() == false, "brute resets on own death")
B("Standing", "combo", "Body yaw"):set("Jitter")
advance(8); handlers.bullet_impact(near); tick(0)
local decoupled = ov("offset") == (side() and -23 or 51)
tick(0)
check(decoupled and ov("offset") == (side() and -23 or 51), "jitter brute shifts desync against the yaw order")
handlers.round_start({}); tick(0)
check(ov("offset") == yaw_for(-23, 51), "jitter mapping restored after reset")

-- Legit AA on use ------------------------------------------------------------------------
local c1 = tick(0, { in_use = true })
local c2 = tick(0, { in_use = true })
local c3 = tick(0, { in_use = true })
check(c1.in_use == true and c2.in_use == true and c3.in_use == false, "use passes for 2 ticks, then AA keeps running")
check(ov("pitch") == "Disabled" and ov("offset") == 180 and ov("base") == "Local View", "legit AA angles")
check(ov("dt") == true and ov("lag") == "On Peek" and ov("hidden") == false, "legit AA keeps DT (no recharge), no defensive")
lp.m_iTeamNum = 3; world.c4 = new_player(false, true, vector(10, 0, 0))
local c4 = tick(0, { in_use = true })
check(c4.in_use == true and ov("pitch") == "Down", "CT defusing is never touched")
reset_world()

-- Spin when idle -------------------------------------------------------------------------
world.rules.m_bWarmupPeriod = true; tick(0)
check(ov("body") == true, "warmup spin is off by default")
M("switch", "Warmup"):set(true); tick(0)
check(ov("body") == false and ov("pitch") == "Disabled" and ov("base") == "Local View" and ov("dt") == true, "warmup spin keeps DT")
local y1 = ov("offset"); tick(0)
check(ov("offset") ~= y1, "warmup spin rotates")
world.rules.m_bWarmupPeriod = false
enemy.alive = false
for _ = 1, 17 do tick(0) end
check(ov("body") == false, "spin when no enemies alive")
enemy.alive = true
for _ = 1, 17 do tick(0) end
check(ov("body") == true and ov("pitch") == "Down", "back to AA when an enemy is alive")

-- DT telemetry ---------------------------------------------------------------------------------
reset_world()
aa.charge = 0.5; handlers.weapon_fire({ userid = 1 }); tick(0)
handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 2, dmg_health = 20, weapon = "ssg08" })
check(printed[#printed]:find("DT %50, DEF yok, atis 0.02s", 1, true) ~= nil, "hit log shows DT percent and time since own shot")
aa.charge = 1
lp.m_fFlags = 0; tick(0)
handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 2, dmg_health = 20, weapon = "ssg08" })
check(printed[#printed]:find(", mod 0.00s |", 1, true) ~= nil, "hit log shows a just-changed defensive mode")
reset_world(); advance(330)
handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 2, dmg_health = 20, weapon = "ssg08" })
check(printed[#printed]:find("atis yok |", 1, true) ~= nil, "old shots and mode changes drop out of the log")
E("button", "Reset stats"):click()
M("switch", "Stats panel"):set(true)
aa.charge = 0.3; handlers.weapon_fire({ userid = 1 }); advance(60); draw()
local standing_line = false
for _, t in ipairs(texts) do if t:find("STANDING   ", 1, true) == 1 then standing_line = true end end
check(contains(texts, "AA STATS   HIT / HEAD / MISS / DT / DEF") and not standing_line, "DT is not sampled right after your own shot")
aa.charge = 1; advance(70); draw()
check(contains(texts, "STANDING   0 / 0 / 0 / 100% / 0%"), "DT sampled again once the shot grace is over")
aa.charge = 0.3; advance(66); draw()
check(contains(texts, "STANDING   0 / 0 / 0 / 50% / 0%"), "an empty DT without shooting shows up in the stats")
handlers.weapon_fire({ userid = 5 }); advance(66); draw()
check(contains(texts, "STANDING   0 / 0 / 0 / 33% / 0%"), "enemy shots do not count as your own")
aa.charge = 1
E("button", "Reset stats"):click()
M("switch", "Stats panel"):set(false)
handlers.level_init(); forget()
reset_world()

-- Defensive uptime and sniper exploit ----------------------------------------------------------
reset_world()
E("button", "Reset stats"):click()
M("switch", "Stats panel"):set(true)
lp.m_fFlags = 0; tick(0); tick(0)
lp.tb_shift = -5; advance(4)
lp.tb_shift = 0; advance(4); draw()
check(contains(texts, "AIR   0 / 0 / 0 / 100% / 50%"), "DEF uptime counts shifted ticks and the catch-up jump")
lp.tb_shift = -5; tick(0)
handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 2, dmg_health = 20, weapon = "ssg08" })
check(printed[#printed]:find("DEF acik", 1, true) ~= nil, "hit log reports an active defensive window")
lp.tb_shift = 0; advance(2)
aa.charge = 0.5; tick(0); lp.tb_shift = 20; tick(0)
check(not same_color((function() draw() return colors["DEF"] end)(), 150, 190, 255),
      "tickbase jumps while DT is recharging are not defensive")
aa.charge = 1; lp.tb_shift = 0
E("button", "Reset stats"):click()
M("switch", "Stats panel"):set(false)
reset_world()
lp.weapon_class = "CWeaponSSG08"; tick(0)
check(ov("dt") == false and ov("hs") == true and ov("lag") == "On Peek" and ov("hs_opt") == "Favor Fire Rate",
      "scout uses hide shots")
lp.m_fFlags = 0; tick(0)
check(ov("hs") == true and ov("lag") == "Always On" and ov("hs_opt") == "Break LC", "scout in air: hide shots breaks LC")
lp.weapon_class = "CWeaponAWP"; tick(0)
check(ov("hs") == true and ov("dt") == false, "AWP uses hide shots")
lp.weapon_class = "CAK47"; tick(0)
check(ov("dt") == true and ov("hs") == false, "rifles keep double tap")
lp.weapon_class = "CWeaponSSG08"
M("combo", "Snipers (SSG08/AWP/R8)"):set("Same as state"); tick(0)
check(ov("dt") == true and ov("hs") == false, "sniper override can be turned off")
M("combo", "Snipers (SSG08/AWP/R8)"):set("Hide shots")
lp.weapon_class, lp.weapon_index = "CDEagle", 64; tick(0)
check(ov("hs") == true and ov("dt") == false, "R8 revolver uses hide shots")
lp.weapon_index = 1; tick(0)
check(ov("dt") == true and ov("hs") == false, "desert eagle keeps double tap")
lp.weapon_class, lp.weapon_index = "CWeaponSSG08", 40; tick(0)
lp.weapon_class = "CKnife"; tick(0)
check(ov("hs") == true and ov("dt") == false, "switching scout -> knife keeps hide shots (no recharge)")
lp.weapon_class = "CWeaponTaser"; tick(0)
check(ov("hs") == true, "zeus keeps the last gun's exploit")
lp.weapon_class = "CHEGrenade"; tick(0)
check(ov("hs") == true, "grenades keep the last gun's exploit")
lp.weapon_class = "CAK47"; tick(0)
lp.weapon_class = "CKnife"; tick(0)
check(ov("dt") == true and ov("hs") == false, "switching rifle -> knife keeps double tap")
lp.weapon_class = "CWeaponSSG08"
B("Air", "combo", "Exploit"):set("Binds"); tick(0)
check(ov("dt") == nil and ov("hs") == nil, "binds still leave DT/HS alone with a sniper")
B("Air", "combo", "Exploit"):set("Double tap")
M("switch", "Auto exploit"):set(false)
check(not M("combo", "Snipers (SSG08/AWP/R8)").visible, "sniper option hidden without auto exploit")
M("switch", "Auto exploit"):set(true)
check(M("combo", "Snipers (SSG08/AWP/R8)").visible, "sniper option visible with auto exploit")
reset_world()

-- Exploit source marker -----------------------------------------------------------------------
reset_world()
handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 2, dmg_health = 20, weapon = "ssg08" })
check(printed[#printed]:find("DT dolu, DEF", 1, true) ~= nil and printed[#printed]:find("(bind)", 1, true) == nil,
      "no bind marker while the script sets the exploit")
M("switch", "Auto exploit"):set(false); refs[SHORT.dt].spec.value = true; tick(0)
handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 2, dmg_health = 20, weapon = "ssg08" })
check(printed[#printed]:find("DT dolu (bind), DEF", 1, true) ~= nil, "bind marker when your own binds decide the exploit")
M("switch", "Auto exploit"):set(true); refs[SHORT.dt].spec.value = false
reset_world()
check(ov("dt") == true, "rifle: script forces double tap")
reject_values[SHORT.dt] = { [false] = true }
lp.weapon_class = "CWeaponSSG08"; tick(0)
check(ov("dt") == nil and ov("hs") == true, "a rejected DT-off releases the old DT override instead of leaving it stuck")
handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 2, dmg_health = 20, weapon = "ssg08" })
check(printed[#printed]:find("HS, DEF", 1, true) ~= nil, "scout still reports hide shots")
refs[SHORT.dt].spec.value = true
handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 2, dmg_health = 20, weapon = "ssg08" })
check(printed[#printed]:find("DT dolu (bind), DEF", 1, true) ~= nil,
      "your own DT bind winning over the script is marked as bind")
refs[SHORT.dt].spec.value = false
reject_values[SHORT.dt] = nil; advance(330)
check(ov("dt") == false and ov("hs") == true, "retried and applied once Neverlose accepts it again")
lp.weapon_class = "CAK47"
reset_world()

-- Grenade damage, choked packets, hide shots on peek, own weapon -------------------------------
reset_world()
E("button", "Reset stats"):click()
local lines_before = #printed
for _ = 1, 5 do handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 0, dmg_health = 8, weapon = "inferno" }) end
handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 0, dmg_health = 40, weapon = "hegrenade" })
M("switch", "Stats panel"):set(true); draw(); M("switch", "Stats panel"):set(false)
local standing_hits = false
for _, t in ipairs(texts) do if t:find("STANDING   ", 1, true) == 1 and not t:find("STANDING   0 / ", 1, true) then standing_hits = true end end
check(#printed == lines_before and not standing_hits, "fire and grenade damage stay out of the log and stats")
advance(12); handlers.bullet_impact({ userid = 5, x = -500, y = 6, z = 64 }); tick(0)
handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 0, dmg_health = 8, weapon = "inferno" }); advance(12)
check(printed[#printed]:find("iska:", 1, true) ~= nil, "fire damage does not turn a near miss into a hit")
reset_world()
lp.weapon_class = "CWeaponSSG08"; tick(0)
tick(1); tick(1); tick(0)
handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 2, dmg_health = 30, weapon = "ssg08" })
check(printed[#printed]:find("HS LC, DEF yok", 1, true) ~= nil, "choked packets are not mistaken for a defensive window")
check(printed[#printed]:find("| sen ssg08 | enemy5", 1, true) ~= nil, "log shows your own weapon")
lp.weapon_class, lp.weapon_index = "CDEagle", 64; tick(0)
handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 2, dmg_health = 30, weapon = "ssg08" })
check(printed[#printed]:find("| sen r8 |", 1, true) ~= nil, "log names the revolver")
lp.weapon_class, lp.weapon_index = "CWeaponSSG08", 40
B("Peek", "combo", "Defensive"):set("On peek")
refs[SHORT.peek].spec.value = true; tick(0)
check(ov("hs") == true and ov("lag") == "On Peek" and ov("hs_opt") == "Break LC", "hide shots breaks LC while peeking")
draw()
check(same_color(colors["DEF"], 255, 255, 255) and colors["DEF"].a == 255, "DEF shown as forced while hide shots peeks")
refs[SHORT.peek].spec.value = false; advance(16)
check(ov("hs_opt") == "Break LC", "hide shots keeps Break LC briefly after the peek")
advance(18)
check(ov("hs_opt") == "Break LC", "moving with hide shots keeps breaking LC (no backtrack on old records)")
lp.m_vecVelocity = vector(0, 0, 0); advance(40)
check(ov("hs_opt") == "Favor Fire Rate", "standing still and unseen: hide shots back to fire rate")
lp.m_vecVelocity = vector(250, 0, 0)
B("Air", "combo", "Defensive"):set("On peek")
lp.m_fFlags = 0; world.threat = enemy; world.trace = function() return 30 end; advance(2)
check(ov("hs") == true and ov("hs_opt") == "Break LC", "hide shots breaks LC in the air when the threat sees the head")
world.trace = NO_TRACE; advance(40)
check(ov("hs_opt") == "Break LC", "in the air hide shots keeps breaking LC even when nobody is seen")
lp.m_fFlags = 1; lp.m_vecVelocity = vector(0, 0, 0); advance(40)
check(ov("hs_opt") == "Favor Fire Rate", "hide shots stops breaking LC once landed, still and hidden")
lp.m_fFlags = 0
world.trace = function(to) return to.x > 10 and 30 or 0 end; lp.m_vecVelocity = vector(250, 0, 0); advance(2)
check(ov("hs_opt") == "Break LC", "hide shots breaks LC just before coming into sight")
B("Air", "combo", "Defensive"):set("Always on")
world.threat, world.trace = nil, NO_TRACE
lp.m_fFlags, lp.m_vecVelocity = 1, vector(0, 0, 0); advance(40)
lp.weapon_class = "CAK47"; refs[SHORT.peek].spec.value = true; tick(0)
check(ov("dt") == true and ov("lag") == "On Peek" and ov("hs_opt") == "Favor Fire Rate", "double tap keeps NL's own on-peek")
refs[SHORT.peek].spec.value = false
B("Peek", "combo", "Defensive"):set("Always on")
handlers.level_init(); forget()
reset_world()

-- Fake duck state --------------------------------------------------------------------------------
reset_world()
lp.weapon_class = "CWeaponSSG08"
refs[SHORT.fakeduck].spec.value = true; tick(0); tick(0)
check(ov("dt") == nil and ov("hs") == nil and ov("lag") == "On Peek" and ov("hidden") == false,
      "fake duck: exploits left alone, no defensive")
check(math.abs(ov("offset")) <= 20 and ov("left") >= 48 and ov("left") <= 58 and ov("body") == true and ov("body_fs") == "Off"
      and B("Fake duck", "combo", "Body yaw"):get() == "Random" and B("Fake duck", "slider", "Yaw randomize"):get() == 20
      and B("Fake duck", "slider", "Limit randomize"):get() == 10,
      "fake duck defaults: random desync side, random yaw (20) and desync amount (10) per packet, no body freestanding")
do
    local offsets, limits = {}, {}
    for _ = 1, 40 do
        tick(0); for c = 1, 13 do tick(c) end
        offsets[ov("offset")] = true; limits[ov("left")] = true
    end
    local n_off, n_lim = 0, 0
    for _ in pairs(offsets) do n_off = n_off + 1 end
    for _ in pairs(limits) do n_lim = n_lim + 1 end
    check(n_off >= 5 and n_lim >= 4, "fake duck: the yaw and the desync amount change from packet to packet")
end
check(B("Standing", "slider", "Yaw randomize"):get() == 0 and B("Standing", "slider", "Limit randomize"):get() == 0,
      "other states keep yaw and desync amount fixed")
-- The head bobs while fake ducking; enemies see it at standing height too: the sight check uses that.
world.threat = enemy; lp.head = vector(0, 0, 46)
world.trace = function(to, from) if from == enemy and to.z > 60 then return 30 end return 0 end
advance(6)
handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 1, dmg_health = 20, weapon = "ssg08" })
check(printed[#printed]:find("gordu", 1, true) ~= nil, "fake duck: the head is checked at standing height (seen)")
refs[SHORT.fakeduck].spec.value = false; advance(40)
handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 1, dmg_health = 20, weapon = "ssg08" })
check(printed[#printed]:find("gormedi", 1, true) ~= nil, "without fake duck the low head stays hidden")
refs[SHORT.fakeduck].spec.value = true; lp.head = vector(0, 0, 64); world.trace = NO_TRACE; world.threat = nil; advance(4)
draw()
check(contains(texts, "FAKE DUCK"), "fake duck shown in the indicator")
do
    -- Every packet cycle draws a side: both sides appear, and not as a strict alternation.
    local sides, repeats, last = {}, 0, nil
    for _ = 1, 60 do
        tick(0); for c = 1, 13 do tick(c) end
        local now_side = side()
        sides[now_side] = true
        if now_side == last then repeats = repeats + 1 end
        last = now_side
    end
    check(sides[true] and sides[false] and repeats > 5 and repeats < 55, "fake duck side is random per packet cycle")
end
B("Fake duck", "combo", "Body yaw"):set("Static")
local inv_before = aa.inverter
aa.inverter = true; tick(0)
check(aa.inverter == true and side() == true, "static + body freestanding: Neverlose picks the side, the script does not force it")
aa.inverter = false; tick(0)
check(side() == false, "indicator follows Neverlose's side")
aa.inverter = inv_before
refs[SHORT.peek].spec.value = true; tick(0)
check(ov("body_fs") == "Peek Fake", "fake duck takes priority over peek")
refs[SHORT.peek].spec.value = false
B("Fake duck", "combo", "Body yaw"):set("Random")
handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 1, dmg_health = 124, weapon = "ssg08" })
check(printed[#printed]:find("| Fake duck | faz %d | s[oa][lg] %d+ | FD, DT yok %(bind%), DEF yok, atis ") ~= nil,
      "hit log marks fake duck and keeps the DEF part")
-- (Anti-brute off: enemy5, the nearest enemy, hit your head three times and the AA uses its phase.)
M("switch", "Anti-bruteforce"):set(false)
B("Fake duck", "switch", "Override"):set(false); tick(0)
check(ov("offset") == yaw_for(-20, 40) and ov("body_fs") == "Off", "fake duck override off falls back to Global")
B("Fake duck", "switch", "Override"):set(true); M("switch", "Anti-bruteforce"):set(true)
M("switch", "Freestanding"):set(true); M("switch", "Disable while crouching"):set(true); tick(0)
check(ov("fs") == false, "crouch freestanding disabler covers fake duck")
M("switch", "Disable while crouching"):set(false); tick(0)
check(ov("fs") == true, "freestanding allowed in fake duck by default")
M("switch", "Freestanding"):set(false)
refs[SHORT.fakeduck].spec.value = false
handlers.level_init(); forget()
reset_world()
B("Standing", "combo", "Body yaw"):set("Static"); B("Standing", "combo", "Freestanding"):set("Off")
M("switch", "Static inverter"):set(true); tick(0)
check(aa.inverter == true, "static without body freestanding still forces the inverter")
M("switch", "Static inverter"):set(false); B("Standing", "combo", "Body yaw"):set("Jitter")
reset_world()

-- Random body yaw in a jitter state ----------------------------------------------------------------
reset_world()
B("Standing", "combo", "Body yaw"):set("Random"); B("Standing", "slider", "Delay randomize"):set(0)
M("combo", "State"):set("Standing")
check(B("Standing", "slider", "Jitter delay").visible and B("Standing", "slider", "Delay randomize").visible,
      "random shows the delay settings")
local synced = true
for _ = 1, 20 do tick(0); if ov("offset") ~= yaw_for(-23, 51) then synced = false end end
check(synced, "random: yaw left/right follows the drawn desync side")
world.threat = enemy; tick(0)
handlers.bullet_impact({ userid = 5, x = -500, y = 6, z = 64 }); tick(0)
local inverted = true
for _ = 1, 20 do tick(0); if ov("offset") ~= (side() and -23 or 51) then inverted = false end end
check(inverted, "random with anti-brute phase 1: desync inverted against the yaw, like jitter")
B("Standing", "combo", "Body yaw"):set("Jitter"); B("Standing", "slider", "Delay randomize"):set(1)
handlers.round_start({}); handlers.level_init(); forget()
reset_world()

-- Ladder / hostage / safe head freestanding -------------------------------------------------
lp.m_MoveType = 9; lp.m_fFlags = 0; tick(0)
check(ov("lag") == "On Peek" and ov("hidden") == false and ov("dt") == true, "ladder: no defensive, DT kept")
draw()
check(contains(texts, "LADDER"), "ladder shown in indicator")
reset_world()
lp.m_iTeamNum = 3; world.hostages = { new_player(false, true, vector(40, 0, 0)) }
local ch = tick(0, { in_use = true }); ch = tick(0, { in_use = true }); ch = tick(0, { in_use = true })
check(ch.in_use == true and ov("pitch") == "Down", "carrying a hostage is never touched")
reset_world()
M("switch", "Freestanding"):set(true)
world.threat = new_player(true, true, vector(500, 0, -50)); world.trace = function() return 30 end; tick(0); tick(0)
check(ov("offset") == 0 and ov("left") == 30 and ov("fs") == false, "safe head disables freestanding")
M("switch", "Freestanding"):set(false)
reset_world()

-- Indicator details ------------------------------------------------------------------------
-- (The safe head test above had an enemy appear: its anti-peek reaction holds a few ticks.)
advance(40); draw()
check(same_color(colors["DT"], 255, 255, 255) and same_color(colors["DEF"], 255, 255, 255, 90) and colors["DEF"].a == 90,
      "charged DT white, on-peek DEF dim")
aa.charge = 0.5; draw(); aa.charge = 1
check(same_color(colors["DT"], 255, 200, 80), "recharging DT shown orange")
tick(0); lp.tb_shift = -10; tick(0); draw(); lp.tb_shift = 0
check(same_color(colors["DEF"], 150, 190, 255), "active defensive window highlighted")
lp.m_fFlags = 0; tick(0); tick(0); draw()
check(colors["DEF"] ~= nil and colors["DEF"].a == 255 and same_color(colors["DEF"], 255, 255, 255), "always-on defensive shown white")
reset_world()

-- Per-enemy anti-brute -----------------------------------------------------------------------
reset_world()
B("Standing", "combo", "Body yaw"):set("Static")
local near5, near7 = { userid = 5, x = -500, y = 6, z = 64 }, { userid = 7, x = 0, y = -500, z = 64 }
world.threat = enemy; advance(12)
handlers.bullet_impact(near5); tick(0)
check(side() == true, "threat's own phase applied")
world.threat = enemy2; tick(0)
check(side() == true, "for a second after its shot the shooter's phase stays, even with another threat")
advance(66)
check(side() == false and ov("left") == 60, "an enemy that never shot sees the base AA")
handlers.bullet_impact(near7); tick(0)
check(side() == true, "second enemy gets its own phase 1")
advance(8); handlers.bullet_impact(near7); tick(0)
check(side() == false and ov("left") == 60 and ov("offset") == -8, "second enemy advances independently")
world.threat = enemy; advance(66)
check(side() == true and ov("left") == 60, "first enemy still on its own phase")
world.threat = nil; tick(0)
check(side() == true and ov("offset") == 51,
      "without a threat the AA turns to the nearest enemy and uses its phase (V1.0; not the last shooter's)")
M("switch", "Anti-bruteforce"):set(false); tick(0)
check(side() == false and ov("left") == 60 and ov("offset") == -23, "disabling anti-brute drops the phase immediately")
M("switch", "Anti-bruteforce"):set(true)
M("switch", "Anti-brute log"):set(true)
advance(8); handlers.bullet_impact(near7)
check(printed[#printed]:find("anti-brute: enemy7 faz 3", 1, true) ~= nil, "anti-brute log names the shooter")
M("switch", "Anti-brute log"):set(false)
handlers.round_start({}); tick(0)
check(side() == false and ov("left") == 60, "round start clears active phases")
B("Standing", "combo", "Body yaw"):set("Jitter")
reset_world()

-- Hit log and stats ----------------------------------------------------------------------------
local function iska_count()
    local n = 0
    for _, line in ipairs(printed) do if line:find("iska:", 1, true) then n = n + 1 end end
    return n
end
E("button", "Reset stats"):click()
handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 1, dmg_health = 40, weapon = "ssg08" })
check(printed[#printed]:match("vuruldun: head %-40 ssg08 | Standing | faz 0 | s[oa][lg] %d+ | DT dolu, DEF yok, atis yok[^|]*| sen ak47 | enemy5 %(Standing, AA hedefi yok, gormedi%)$") ~= nil,
      "hit logged with weapon, AA side, exploit state and the attacker")
local misses0 = iska_count()
advance(12); handlers.bullet_impact(near5); advance(12)
check(iska_count() == misses0 + 1
      and printed[#printed]:match("iska: Standing | faz %d | s[oa][lg] %d+ | DT dolu, DEF yok, atis yok[^|]*| sen ak47 | enemy5 %(Standing, AA hedefi yok, gormedi%)$") ~= nil,
      "near miss logged with AA side, exploit state and the attacker")
advance(12); handlers.bullet_impact(near5); tick(0)
handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 2, dmg_health = 25 }); advance(12)
check(iska_count() == misses0 + 1 and printed[#printed]:find("vuruldun: chest -25", 1, true) ~= nil,
      "impact followed by damage is a hit, not a miss")
advance(12)
handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 1, dmg_health = 90 }); handlers.bullet_impact(near5); advance(12)
check(iska_count() == misses0 + 1, "damage followed by impact is a hit, not a miss")
local lines = #printed
handlers.player_hurt({ userid = 1, attacker = 0, hitgroup = 0, dmg_health = 12 })
handlers.player_hurt({ userid = 1, attacker = 6, hitgroup = 2, dmg_health = 12 })
check(#printed == lines, "fall damage and team damage are ignored")
M("switch", "Stats panel"):set(true); draw()
check(contains(texts, "AA STATS   HIT / HEAD / MISS / DT / DEF") and contains(texts, "STANDING   3 / 2 / 1 / 100% / 0%"), "stats panel counts per state")
lp.alive = false; draw(); lp.alive = true
check(contains(texts, "STANDING   3 / 2 / 1 / 100% / 0%"), "stats panel stays visible while dead")
E("button", "Reset stats"):click(); draw()
check(contains(texts, "AA STATS   HIT / HEAD / MISS / DT / DEF") and not contains(texts, "STANDING   3 / 2 / 1 / 100% / 0%"), "stats can be reset")
M("switch", "Stats panel"):set(false)
M("switch", "Hit log"):set(false)
lines = #printed
handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 1, dmg_health = 40 })
check(#printed == lines, "hit log can be turned off")
M("switch", "Hit log"):set(true)
handlers.level_init(); forget()
reset_world()

-- Anti-brute memory across rounds ---------------------------------------------------------------
B("Standing", "combo", "Body yaw"):set("Static")
world.threat = enemy; tick(0)
check(side() == false and ov("offset") == -23, "fresh enemy sees the base AA")
handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 1, dmg_health = 203, weapon = "ssg08" })
handlers.player_death({ userid = 1 }); handlers.round_start({}); tick(0)
check(side() == true and ov("offset") == 51, "headshot at phase 0: next round starts at phase 1 against that enemy")
world.threat = enemy2; tick(0)
check(side() == false and ov("offset") == -23, "other enemies are unaffected")
world.threat = enemy; globals.realtime = globals.realtime + 20; tick(0)
check(side() == true, "learned phase does not time out")
draw()
check(contains(texts, "BRUTE 1"), "learned phase shown in the indicator")
handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 2, dmg_health = 30, weapon = "ssg08" })
handlers.round_start({}); tick(0)
check(side() == true and ov("offset") == 51, "body hits do not change the learned phase")
advance(8); handlers.bullet_impact(near5); tick(0)
handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 1, dmg_health = 165, weapon = "ssg08" })
check(printed[#printed]:find("vuruldun: head -165 ssg08 | Standing | faz 1 |", 1, true) ~= nil,
      "hit log reports the phase the bullet was fired at")
handlers.round_start({}); tick(0)
check(side() == false and ov("offset") == -23 + 15, "head at phase 1: next round starts at phase 2")
enemy.name = "renamed"; tick(0)
check(side() == false and ov("offset") == -23, "a different player on the same index starts fresh")
enemy.name = "enemy5"; tick(0)
check(ov("offset") == -23 + 15, "learned phase kept for the original player")
M("switch", "Anti-bruteforce"):set(false); tick(0)
check(ov("offset") == -23, "learned phase not applied while anti-brute is off")
handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 1, dmg_health = 50, weapon = "ssg08" })
M("switch", "Anti-bruteforce"):set(true); tick(0)
check(ov("offset") == -23 + 15, "no learning while anti-brute is off")
handlers.level_init(); tick(0)
check(ov("offset") == -23 + 15, "map change keeps the learned phase")
forget(); tick(0)
check(side() == false and ov("offset") == -23, "forget button clears every learned enemy")
enemy.xuid = "76561198000000005"
handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 1, dmg_health = 150, weapon = "ssg08" })
handlers.round_start({}); tick(0)
check(ov("offset") == 51, "a steam id player learns a phase")
enemy.name, enemy.index = "new name", 8; tick(0)
check(ov("offset") == 51, "the phase follows the steam id through a rename and a new slot")
handlers.level_init(); tick(0)
check(ov("offset") == 51, "and through a map change")
enemy.xuid = "0"; tick(0)
check(ov("offset") == -23, "an empty steam id falls back to the name")
handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 1, dmg_health = 150, weapon = "ssg08" })
handlers.round_start({}); tick(0)
check(ov("offset") == 51, "a player without a steam id learns under the name")
handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 1, dmg_health = 150, weapon = "ssg08" })
handlers.round_start({}); tick(0)
check(ov("offset") == -23 + 15, "a second headshot moves the name-based phase on")
enemy.xuid = "BOT_7"; tick(0)
check(ov("offset") == -23 + 15, "bots keep their name-based memory")
enemy.name, enemy.index, enemy.xuid = "enemy5", 5, nil
forget()
-- Memory cap: the enemy you keep facing stays, the longest-unseen one goes.
world.threat = enemy
handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 1, dmg_health = 150, weapon = "ssg08" })
local crowd = {}
for i = 1, 64 do
    local p = new_player(true, true); p.index, p.name = 0, "crowd" .. i
    players[100 + i], crowd[i] = p, p
    tick(0)
    handlers.player_hurt({ userid = 1, attacker = 100 + i, hitgroup = i == 1 and 1 or 2, dmg_health = 10, weapon = "ssg08" })
end
handlers.round_start({}); tick(0)
check(ov("offset") == 51, "memory cap keeps the enemy you keep facing")
world.threat = crowd[1]; tick(0)
check(ov("offset") == -23, "memory cap forgets the longest-unseen enemy")
for i = 1, 64 do players[100 + i] = nil end
world.threat = nil
forget()
B("Standing", "combo", "Body yaw"):set("Jitter")
reset_world()

-- VIS indicator -------------------------------------------------------------------------------
world.threat = enemy; world.trace = function() return 30 end; advance(2); draw()
check(same_color(colors["VIS"], 150, 190, 255), "VIS highlighted while the threat sees the head")
world.trace = function(to) return to.x > 10 and 30 or 0 end; lp.m_vecVelocity = vector(250, 0, 0); advance(2); draw()
check(same_color(colors["VIS"], 255, 255, 255) and colors["VIS"].a == 255, "VIS white when about to be seen")
world.trace = NO_TRACE; advance(2); draw()
check(colors["VIS"] ~= nil and colors["VIS"].a == 90, "VIS dim when hidden")
reset_world()

-- Render ----------------------------------------------------------------------------------
draw()
check(contains(texts, "Nykle.win") and contains(texts, "STANDING") and contains(texts, "DT") and contains(texts, "DEF"),
      "indicators render")
check(polys >= 2, "manual arrows render")
lp.m_bIsScoped = true; draw(); lp.m_bIsScoped = false
M("switch", "Crosshair indicators"):set(false); M("switch", "Manual arrows"):set(false)
draw()
check(#texts == 0 and polys == 0, "indicators can be hidden")

-- Menu visibility -------------------------------------------------------------------------
M("combo", "State"):set("Global")
check(M("label", "Used by states whose Override is off.").visible, "global explains when it is used")
check(B("Global", "slider", "Yaw left").visible and not B("Standing", "slider", "Yaw left").visible
      and not B("Standing", "combo", "Exploit").visible, "only selected state shown")
M("combo", "State"):set("Air")
check(B("Air", "combo", "Exploit").visible and B("Air", "combo", "Defensive").visible
      and not B("Air", "slider", "Defensive every").visible and B("Air", "combo", "Hidden pitch").visible,
      "air exploit settings visible")
B("Air", "combo", "Defensive"):set("Tick based")
check(B("Air", "slider", "Defensive every").visible, "tick setting shown for tick based")
B("Air", "combo", "Defensive"):set("Off")
check(not B("Air", "combo", "Hidden pitch").visible, "hidden settings hidden when defensive off")
B("Air", "combo", "Defensive"):set("Always on")
B("Air", "switch", "Override"):set(false)
check(not B("Air", "slider", "Yaw left").visible and B("Air", "combo", "Exploit").visible,
      "override off hides AA, keeps exploit")
B("Air", "switch", "Override"):set(true)
M("switch", "Auto exploit"):set(false)
check(not B("Air", "combo", "Exploit").visible, "exploit choice hidden without auto exploit")
M("switch", "Auto exploit"):set(true)
M("combo", "State"):set("Standing")
B("Standing", "combo", "Yaw mode"):set("X-Way")
check(not B("Standing", "slider", "Yaw left").visible and B("Standing", "slider", "Ways").visible
      and B("Standing", "slider", "Way 3").visible and not B("Standing", "slider", "Way 4").visible,
      "X-Way shows only the ways in use")
B("Standing", "slider", "Ways"):set(4)
check(B("Standing", "slider", "Way 4").visible and not B("Standing", "slider", "Way 5").visible, "way count controls sliders")
B("Standing", "combo", "Yaw mode"):set("L&R")
check(B("Standing", "slider", "Yaw left").visible and not B("Standing", "slider", "Ways").visible, "L&R hides ways")
M("combo", "State"):set("Safe head")
check(M("label", "Used while a safe head condition matches.").visible and B("Safe head", "slider", "Yaw left").visible,
      "special state shows its info")
-- V1.0 menu: six tabs, logs in Home > Console, the builder's exploit column on the right.
do
    local function group_of(kind, name) return M(kind, name).group or "?" end
    check(sidebar.name == "Nykle.win" and sidebar.icon == "crown", "sidebar: Nykle.win")
    check(group_of("label", "Nykle.win  V1.0") == "Home/Nykle.win" and group_of("switch", "Enable") == "Home/Nykle.win"
          and group_of("switch", "Always use recommended settings") == "Home/Nykle.win", "Home: header, enable, recommended")
    check(group_of("switch", "Resolver log") == "Home/Console" and group_of("switch", "Shot log") == "Home/Console"
          and group_of("switch", "Hit log") == "Home/Console" and group_of("switch", "Anti-brute log") == "Home/Console",
          "every console log in Home > Console")
    check(group_of("button", "Forget learned enemies") == "Home/Memory" and group_of("button", "Reset stats") == "Home/Memory",
          "memory buttons in Home > Memory")
    check(group_of("combo", "Pitch") == "Anti-Aim/Main" and group_of("switch", "Anti-bruteforce") == "Anti-Aim/Protection"
          and group_of("switch", "Auto exploit") == "Exploits/Exploits" and group_of("switch", "AI peek (hold Peek Assist)") == "Exploits/Peek"
          and group_of("switch", "Air lag (defensive every tick)") == "Exploits/Defensive"
          and group_of("switch", "Adaptive resolver") == "Ragebot/Resolver" and group_of("switch", "Resolver panel") == "Visuals/Resolver panel",
          "tabs: Anti-Aim, Exploits, Ragebot, Visuals")
    check(group_of("combo", "State") == "Builder/Angles" and B("Standing", "slider", "Yaw left").group == "Builder/Angles"
          and B("Standing", "combo", "Exploit").group == "Builder/State exploit", "builder: angles left, the state's exploit right")
    M("combo", "State"):set("Standing")
    local no_exploit = M("label", "This state has no exploit settings (Global shares AA only, fake duck turns DT/HS off).")
    check(not no_exploit.visible and M("label", "Standing").visible and not M("label", "Air").visible,
          "a state with exploit settings: its name heads the exploit column")
    M("combo", "State"):set("Fake duck")
    check(no_exploit.visible, "fake duck: the exploit column says why it is empty")
    M("combo", "State"):set("Global")
    check(no_exploit.visible, "global too")
    M("switch", "AI peek (hold Peek Assist)"):set(false)
    check(not M("switch", "Defensive during AI peek").visible, "AI peek off: its defensive option hidden")
    M("switch", "AI peek (hold Peek Assist)"):set(true)
    check(M("switch", "Defensive during AI peek").visible, "AI peek on: shown")
    M("combo", "State"):set("Safe head")
end
M("switch", "Enable"):set(false)
check(not M("combo", "Pitch").visible and not M("combo", "State").visible and not B("Safe head", "slider", "Yaw left").visible,
      "disable hides menu")
check(M("label", "Nykle.win  V1.0").visible and M("switch", "Enable").visible, "the header and Enable stay visible")

-- Recommended settings ---------------------------------------------------------------------------
reset_world()
local lines_rec = #printed
M("switch", "Anti-brute log"):set(true)
M("switch", "Always use recommended settings"):set(true)
check(M("switch", "Anti-brute log"):get() == true, "console logs are preferences: recommended settings leave them alone")
M("switch", "Anti-brute log"):set(false)
check(B("Air", "combo", "Defensive"):get() == "Smart" and printed[#printed] ~= nil and #printed > lines_rec
      and printed[#printed]:match("^%[Nykle%.win%] %d+ ayar onerilen degerine donduruldu %(orn%. .+, onerilen .+%)$") ~= nil,
      "turning it on applies the recommended settings and reports how many changed")
B("Standing", "slider", "Yaw left"):set(-77)
B("Air", "combo", "Exploit"):set("Hide shots")
M("switch", "Auto peek"):set(false)
M("combo", "Snipers (SSG08/AWP/R8)"):set("Same as state")
M("switch", "Stats panel"):set(true)
M("switch", "Adaptive resolver"):set(false)
M("switch", "Smart body aim"):set(false)
M("combo", "Manual yaw"):set("Left")
M("switch", "Freestanding"):set(true)
M("combo", "State"):set("Air")
lines_rec = #printed
handlers.config_state("pre_load"); handlers.config_state("post_load"); tick(0)
check(B("Air", "combo", "Defensive"):get() == "Smart" and B("Standing", "slider", "Yaw left"):get() == -23
      and B("Air", "combo", "Exploit"):get() == "Double tap" and M("switch", "Auto peek"):get() == true
      and M("combo", "Snipers (SSG08/AWP/R8)"):get() == "Auto (learn)" and M("switch", "Adaptive resolver"):get() == true
      and M("switch", "Smart body aim"):get() == true,
      "loading a config brings back the recommended AA, exploit and builder settings")
check(#printed == lines_rec, "the report is not repeated within 30 s")
check(M("switch", "Stats panel"):get() == true and M("combo", "Manual yaw"):get() == "Left"
      and M("switch", "Freestanding"):get() == true and M("combo", "State"):get() == "Air",
      "binds, visuals and the state selector are left alone")
-- A config applied after the load event (stale Fake duck values in the game logs) is undone during play.
globals.realtime = globals.realtime + 31
B("Fake duck", "slider", "Left limit"):set(60); advance(3)
check(B("Fake duck", "slider", "Left limit"):get() == 60, "not checked every tick")
advance(64)
check(B("Fake duck", "slider", "Left limit"):get() == 58
      and printed[#printed] == "[Nykle.win] 1 ayar onerilen degerine donduruldu (orn. Fake duck Left limit 60, onerilen 58)",
      "values that drift from the recommended ones are put back within a second and named")
M("switch", "Always use recommended settings"):set(false)
B("Standing", "slider", "Yaw left"):set(-77)
lines_rec = #printed
handlers.config_state("post_load"); tick(0)
check(B("Standing", "slider", "Yaw left"):get() == -77
      and printed[#printed] == "[Nykle.win] Always use recommended settings kapali: 1 ayar onerilenden farkli (orn. Standing Yaw left -77, onerilen -23)",
      "turning it off keeps your config values and says how they differ")
advance(130)
check(B("Standing", "slider", "Yaw left"):get() == -77 and #printed == lines_rec + 1, "while off: no changes and a single report")
M("switch", "Always use recommended settings"):set(true)
check(B("Standing", "slider", "Yaw left"):get() == -23, "turning it back on applies the recommended settings")
-- The rest of the suite changes settings again.
M("switch", "Always use recommended settings"):set(false)
M("switch", "Auto when standing still"):set(false); M("switch", "High ground"):set(true)
M("switch", "Air lag (defensive every tick)"):set(false); M("switch", "Snipers use DT in the air"):set(false)
M("combo", "Manual yaw"):set("Off"); M("switch", "Freestanding"):set(false); M("switch", "Stats panel"):set(false)
reset_world()

-- Smart defensive -------------------------------------------------------------------------------
M("switch", "Enable"):set(true)
M("switch", "Crosshair indicators"):set(true)
reset_world()
M("switch", "Auto peek"):set(false)
lp.m_vecVelocity = vector(250, 0, 0); advance(2)
check(last_cmd.force_defensive == nil and ov("lag") == "On Peek", "smart: nothing forced while nobody sees you")
world.threat = enemy; world.trace = function() return 30 end; advance(2)
check(last_cmd.force_defensive == true and ov("lag") == "On Peek", "smart: defensive forced when the threat sees the head")
draw()
check(same_color(colors["DEF"], 255, 255, 255) and colors["DEF"].a == 255, "smart: DEF shown as forced")
handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 2, dmg_health = 20, weapon = "ssg08" })
check(printed[#printed]:find("| Moving | faz 0 | s[oa][lg] %d+ | DT dolu, DEF yok %(zorla%), atis yok") ~= nil,
      "hit log marks a forced defensive")
aa.charge = 0.5; tick(0)
check(last_cmd.force_defensive == nil, "smart: not forced without DT charge")
aa.charge = 1; tick(0)
world.trace = NO_TRACE; advance(3)
check(last_cmd.force_defensive == true, "smart: held briefly after sight is lost")
advance(10)
check(last_cmd.force_defensive == nil, "smart: stops once hidden")
world.trace = function() return 30 end; advance(2)
check(last_cmd.force_defensive == true, "smart: re-armed on the next exposure")
advance(100)
check(last_cmd.force_defensive == true, "smart: a long exposure while moving keeps forcing (no one-second cap)")
world.trace = NO_TRACE; advance(12)
world.trace = function(to) return to.x > 10 and 30 or 0 end; advance(2)
check(last_cmd.force_defensive == true, "smart: re-armed after a break, just before coming into sight")
lp.weapon_class = "CWeaponSSG08"; advance(2)
check(ov("hs") == true and ov("hs_opt") == "Break LC" and last_cmd.force_defensive == nil,
      "smart with hide shots breaks LC instead of forcing")
lp.weapon_class = "CAK47"; world.trace = function() return 30 end
lp.m_vecVelocity = vector(0, 0, 0); advance(12)
check(ov("offset") == yaw_for(-23, 51) and last_cmd.force_defensive == nil, "standing still in sight (on peek) is never forced")
M("switch", "Auto peek"):set(true)
lp.m_vecVelocity = vector(250, 0, 0); advance(2)
check(ov("offset") == yaw_for(-20, 45) and last_cmd.force_defensive == true, "peek state forces defensive by default")
lp.m_fFlags = 0; advance(2)
check(ov("offset") == yaw_for(-13, 34) and last_cmd.force_defensive == true and ov("lag") == "On Peek",
      "air forces defensive by default without switching NL's mode")
reset_world()

-- Flanking enemy -------------------------------------------------------------------------------
world.enemies = { enemy, enemy2 }; world.threat = enemy
world.trace = function(to, from) return from == enemy2 and 30 or 0 end
lp.m_vecVelocity = vector(250, 0, 0); advance(4)
check(ov("offset") == yaw_for(-20, 45) and last_cmd.force_defensive == true,
      "an enemy other than the threat seeing you triggers peek and smart defensive")
draw()
check(same_color(colors["VIS"], 150, 190, 255), "VIS shows a flanking enemy")
lp.weapon_class = "CWeaponSSG08"; advance(2)
check(ov("hs") == true and ov("hs_opt") == "Break LC", "hide shots breaks LC for a flanking enemy")
lp.m_vecVelocity = vector(0, 0, 0); advance(40)
check(ov("offset") == yaw_for(-23, 51) and ov("hs_opt") == "Break LC",
      "standing still, hide shots still breaks LC while a flanking enemy sees you")
lp.m_vecVelocity = vector(250, 0, 0); lp.weapon_class = "CAK47"; advance(2)
handlers.weapon_fire({ userid = 1 }); aa.charge = 0.2; advance(2)
check(aa.allow == false, "safe recharge holds while a flanking enemy sees you")
aa.charge = 1; advance(2)
world.trace = NO_TRACE; advance(16)
check(last_cmd.force_defensive == nil and ov("offset") == yaw_for(-20, 50), "flank sight expires once hidden")
world.trace = function(to, from) return from == enemy2 and 30 or 0 end
enemy2.dormant = true; advance(6)
check(last_cmd.force_defensive == nil, "a dormant flanker is ignored")
enemy2.dormant = nil; enemy2.alive = false; advance(6)
check(last_cmd.force_defensive == nil, "a dead flanker is ignored")
enemy2.alive = true; world.threat = enemy2; advance(6)
check(ov("offset") == yaw_for(-20, 45), "the threat itself still counts through the threat check")
world.enemies = { enemy }
local flanker = new_player(true, true); flanker.index, flanker.name, flanker.eye = 9, "enemy9", vector(0, -500, 64)
reset_world(); world.enemies = { enemy, enemy2, flanker }; world.threat = enemy
world.trace = function(to, from) return from == flanker and 30 or 0 end
lp.m_vecVelocity = vector(250, 0, 0); advance(6)
check(last_cmd.force_defensive == true, "rotation finds a flanker that is not first in the list")
local extra1, extra2 = new_player(true, true), new_player(true, true)
extra1.index, extra2.index = 15, 16
world.enemies = { enemy, enemy2, extra1, extra2, flanker }; advance(8)
local steady = true
for _ = 1, 8 do tick(0); draw(); if not same_color(colors["VIS"], 150, 190, 255) then steady = false end end
check(steady, "a flanker's sight holds while the rotation checks other enemies")
world.enemies = { enemy }
reset_world()

-- Jump peek lookahead ---------------------------------------------------------------------------
world.threat = enemy
world.trace = function(to) return to.z > 100 and 30 or 0 end
advance(2); draw()
check(colors["VIS"] ~= nil and colors["VIS"].a == 90, "head behind cover on the ground is hidden")
tick(0, { in_jump = true }); tick(0, { in_jump = true }); draw()
check(same_color(colors["VIS"], 255, 255, 255) and colors["VIS"].a == 255 and last_cmd.force_defensive == true,
      "pressing jump predicts the head rising above cover and forces defensive")
lp.m_fFlags = 0; lp.m_vecVelocity = vector(0, 0, 300); advance(2); draw()
check(same_color(colors["VIS"], 255, 255, 255) and colors["VIS"].a == 255, "rising in the air: head about to clear cover")
lp.m_vecVelocity = vector(0, 0, -300); advance(2); draw()
check(colors["VIS"].a == 90, "falling back behind cover is hidden")
world.trace = function(to) return to.z > 70 and 30 or 0 end
lp.m_vecVelocity = vector(0, 0, 50); advance(2); draw()
check(colors["VIS"].a == 90, "near the apex gravity brings the head back down")
reset_world()

-- Safe recharge -----------------------------------------------------------------------------------
world.threat = enemy; world.trace = function() return 30 end; advance(2)
check(aa.allow ~= false, "safe recharge: charge allowed while DT is full")
handlers.weapon_fire({ userid = 1 }); aa.charge = 0.2; tick(0)
check(aa.allow == false, "safe recharge: recharge held while the threat sees you after a shot")
handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 2, dmg_health = 20, weapon = "ssg08" })
check(printed[#printed]:find("DT %20, DEF yok, sarj bekle, atis 0.0", 1, true) ~= nil, "hit log shows the held recharge")
local allow_calls = aa.allow_calls; advance(5)
check(aa.allow_calls == allow_calls and aa.allow == false, "safe recharge: no per-tick calls while held")
world.trace = NO_TRACE; advance(2)
check(aa.allow == true, "safe recharge: charges once hidden")
handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 2, dmg_health = 20, weapon = "ssg08" })
check(printed[#printed]:find("sarj bekle", 1, true) == nil, "no hold marker once charging")
world.trace = function() return 30 end; advance(2)
check(aa.allow == false, "safe recharge: held again when seen before the charge is full")
advance(70)
check(aa.allow == true, "safe recharge: gives up after 1.2 s so DT is never left empty")
handlers.weapon_fire({ userid = 1 }); tick(0)
check(aa.allow == false, "held after another shot")
M("switch", "Safe recharge"):set(false); tick(0)
check(aa.allow == true, "safe recharge can be turned off")
M("switch", "Safe recharge"):set(true); tick(0)
check(aa.allow == false, "turning it back on holds again")
handlers.player_death({ userid = 1 })
check(aa.allow == true, "released on death")
tick(0); handlers.round_start({})
check(aa.allow == true, "released on round start")
tick(0); M("switch", "Enable"):set(false); tick(0)
check(aa.allow == true, "released when the script is disabled")
M("switch", "Enable"):set(true); tick(0)
check(aa.allow == false, "held again after re-enable")
aa.charge = 1; tick(0)
check(aa.allow == true, "released once DT is full")
lp.weapon_class = "CWeaponSSG08"; tick(0)
handlers.weapon_fire({ userid = 1 }); aa.charge = 0.3; tick(0)
check(aa.allow == false, "hide shots held once its charge value is known to follow HS")
handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 2, dmg_health = 20, weapon = "ssg08" })
check(printed[#printed]:find("| HS %30 LC, DEF yok, sarj bekle, atis 0.0", 1, true) ~= nil, "hit log shows the HS charge")
draw()
check(same_color(colors["HS"], 255, 200, 80), "charging hide shots shown orange")
lp.weapon_class = "CAK47"; tick(0)
check(aa.allow == false, "double tap held")
handlers.shutdown()
check(aa.allow == true, "released on shutdown")
aa.charge = 1; reset_world()
world.threat = enemy; world.trace = function() return 30 end
refs[SHORT.fakeduck].spec.value = true; refs[SHORT.dt].spec.value = true; aa.charge = 0; advance(200)
handlers.weapon_fire({ userid = 1 }); advance(2)
check(aa.allow ~= false, "no hold while fake ducking, even with your own DT bind on")
refs[SHORT.fakeduck].spec.value = false; refs[SHORT.dt].spec.value = false; advance(80); tick(0)
refs[SHORT.fakeduck].spec.value = true; advance(100)
refs[SHORT.fakeduck].spec.value = false; tick(0)
check(ov("dt") == true and aa.allow == false, "standing up from fake duck in sight holds the recharge")
world.trace = NO_TRACE; advance(2)
check(aa.allow == true, "fake duck recharge happens behind cover")
world.trace = function() return 30 end; advance(2)
check(aa.allow == false, "held again in sight before the charge is full")
advance(80)
check(aa.allow == true, "fake duck hold also gives up after 1.2 s")
aa.charge = 1; reset_world()
E("button", "Reset stats"):click()
M("switch", "Stats panel"):set(true)
world.threat = enemy; world.trace = function() return 30 end
handlers.weapon_fire({ userid = 1 }); aa.charge = 0.2; advance(72); draw()
check(aa.allow == false and contains(texts, "STANDING   0 / 0 / 0 / - / -"), "a held recharge is not counted as an empty DT")
aa.charge = 1
E("button", "Reset stats"):click()
M("switch", "Stats panel"):set(false)
reset_world()

-- Adaptive resolver ---------------------------------------------------------------------------------
local function ack(target, state, hitgroup, damage)
    handlers.aim_ack({ target = target, state = state, hitgroup = hitgroup or 1, damage = damage or 100 })
    tick(0)
end
world.threat = enemy; tick(0)
check(ov("safe") == nil, "resolver: safe points untouched without misses")
ack(5, "correction")
check(ov("safe") == "Prefer", "one resolver miss: safe points prefer against that enemy")
check(printed[#printed] == "[Nykle.win] resolver: enemy5 Standing iska (correction) | seviye 1 -> safe points Prefer",
      "resolver miss logged")
draw()
check(contains(texts, "RES 1 STAND"), "resolver level and the enemy state shown in the indicator")
ack(5, "spread"); ack(5, "prediction error"); ack(5, "backtrack failure"); ack(5, "unregistered shot")
check(ov("safe") == "Prefer", "misses that are not the resolver's fault are ignored")
ack(enemy, "correction")
check(ov("safe") == "Force", "second resolver miss: safe points force (entity target works too)")
draw()
check(contains(texts, "RES 2 STAND"), "level 2 shown in the indicator")
local lines_before = #printed
ack(5, nil, 2, 80); ack(5, nil, 1, 120)
check(ov("safe") == "Force" and #printed == lines_before + 2 and printed[#printed]:find("[Nykle.win] atis:", 1, true) == 1
      and printed[#printed - 1]:find("[Nykle.win] atis:", 1, true) == 1,
      "hits keep force while two misses are in the window, only shot lines logged")
ack(5, nil, 1, 100)
check(ov("safe") == "Prefer" and printed[#printed] == "[Nykle.win] resolver: enemy5 Standing isabet head -100 | seviye 1 -> safe points Prefer",
      "hits push old misses out and lower the level")
ack(5, nil, 3, 70)
check(ov("safe") == nil and printed[#printed] == "[Nykle.win] resolver: enemy5 Standing isabet stomach -70 | seviye 0 -> safe points Default",
      "back to your own safe points after enough hits")
ack(5, "correction"); ack(5, "correction")
world.threat = enemy2; tick(0)
check(ov("safe") == nil, "another threat without history: safe points released")
handlers.aim_fire({ target = 5 }); tick(0)
check(ov("safe") == "Force", "aimbot just shot at enemy5: its level applies")
advance(100)
check(ov("safe") == nil, "back to the threat's level after a while")
handlers.aim_fire({ target = enemy }); enemy.alive = false; tick(0)
check(ov("safe") == nil, "a dead aim target is not used")
enemy.alive = true; advance(100)
refs[SHORT.safe].spec.value = "Force"; tick(0)
world.threat = enemy; tick(0)
check(ov("safe") == nil, "your own Force safe points are never lowered")
world.threat = enemy2; refs[SHORT.safe].spec.value = "Prefer"; tick(0)
world.threat = enemy; tick(0)
check(ov("safe") == "Force", "your own Prefer is raised to Force at level 2")
world.threat = enemy2; refs[SHORT.safe].spec.value = "Default"; tick(0)
world.threat = enemy; tick(0)
M("switch", "Adaptive resolver"):set(false); tick(0); draw()
check(ov("safe") == nil and not contains(texts, "RES 2 STAND"), "resolver can be turned off")
ack(7, "correction")
M("switch", "Adaptive resolver"):set(true); world.threat = enemy2; tick(0)
check(ov("safe") == nil, "nothing is learned while it is off")
lines_before = #printed
M("switch", "Resolver log"):set(false); ack(7, "correction")
check(ov("safe") == "Prefer" and #printed == lines_before + 1 and printed[#printed]:find("atis: enemy7", 1, true) ~= nil,
      "resolver log can be turned off")
M("switch", "Resolver log"):set(true)
world.threat = enemy; enemy.name = "renamed"; tick(0)
check(ov("safe") == nil, "a different player on the same index starts fresh")
enemy.name = "enemy5"; tick(0)
check(ov("safe") == "Force", "level kept for the original player")
handlers.round_start({}); tick(0)
check(ov("safe") == "Force", "level kept across rounds")
handlers.level_init(); tick(0)
check(ov("safe") == "Force", "map change keeps resolver levels")
forget(); tick(0)
check(ov("safe") == nil, "forget button clears resolver levels")
-- Per-state learning
handlers.level_init(); forget(); world.threat = enemy
enemy.m_fFlags = 0; ack(5, "correction")
check(ov("safe") == "Prefer" and printed[#printed]:find("resolver: enemy5 Air iska", 1, true) ~= nil,
      "resolver miss in the air is learned for the air state")
ack(5, "correction")
check(ov("safe") == "Force", "two air misses: force while the enemy is in the air")
enemy.m_fFlags = 1; tick(0)
check(ov("safe") == "Prefer", "on the ground without own data: other states are only a prefer prior")
ack(5, nil, 1, 100)
check(ov("safe") == nil, "a ground hit clears the ground state")
enemy.m_fFlags = 0; tick(0)
check(ov("safe") == "Force", "air level kept separately")
handlers.aim_fire({ id = 77, target = 5 }); enemy.m_fFlags = 1
handlers.aim_ack({ id = 78, target = 5, state = "spread" })
handlers.aim_ack({ id = 77, target = 5, state = "correction" }); tick(0)
check(ov("safe") == nil and printed[#printed]:find("atis: enemy5 | Air | HP ? | hedef ? | iska correction", 1, true) ~= nil,
      "a result is learned for the state at fire time, not after landing")
enemy.m_fFlags = 1; ack(5, nil, 1, 100); ack(5, nil, 1, 100)
handlers.aim_fire({ id = 79, target = 5 }); enemy.m_fFlags = 0
handlers.aim_ack({ id = 79, target = 5, state = "correction" }); enemy.m_fFlags = 1; tick(0)
check(ov("safe") == "Prefer" and printed[#printed]:find("resolver: enemy5 Standing iska", 1, true) ~= nil,
      "a ground shot that misses after the enemy jumps counts for the ground")
enemy.m_vecVelocity = vector(250, 0, 0); ack(5, "correction")
check(printed[#printed]:find("atis: enemy5 | Moving |", 1, true) ~= nil, "moving enemy state")
enemy.m_vecVelocity = vector(0, 0, 0); enemy.m_flDuckAmount = 1; ack(5, "correction")
check(printed[#printed]:find("atis: enemy5 | Crouch |", 1, true) ~= nil, "crouching enemy state")
enemy.m_flDuckAmount, enemy.m_fFlags, enemy.m_vecVelocity = nil, nil, nil
forget(); tick(0)
check(ov("safe") == nil, "forget button clears per-state levels")
-- Force must not block every shot
world.threat = enemy; ack(5, "correction"); ack(5, "correction")
check(ov("safe") == "Force", "stall guard: force active")
world.trace = function() return 30 end; advance(70)
check(ov("safe") == "Prefer" and printed[#printed]:find("enemy5 Standing safe point bulunamadi", 1, true) ~= nil,
      "force relaxes to prefer when it blocks every shot while the enemy sees you")
draw()
check(contains(texts, "RES 1 STAND"), "indicator shows the relaxed level")
local stall_lines = #printed; advance(30)
check(#printed == stall_lines and ov("safe") == "Prefer", "stall logged once and stays relaxed")
ack(5, "correction")
check(ov("safe") == "Force", "a new resolver miss re-arms force")
for id = 90, 92 do handlers.aim_fire({ id = id, target = 5 }); advance(30) end
check(ov("safe") == "Force", "shots being fired keep force")
world.trace = NO_TRACE; advance(200)
check(ov("safe") == "Force", "no relaxation while the enemy cannot see you")
handlers.level_init(); forget(); world.threat = nil; tick(0)
-- Shot log
enemy.m_iHealth = 100; refs[SHORT.body_aim].spec.value = "Force"
handlers.aim_fire({ id = 200, target = 5, hitgroup = 1, damage = 98, hitchance = 81, backtrack = 2 })
enemy.m_iHealth = 95; lp.weapon_class = "CWeaponSSG08"; refs[SHORT.body_aim].spec.value = "Default"; tick(0)
handlers.aim_ack({ id = 200, target = 5, hitgroup = 1, damage = 98 })
check(printed[#printed] == "[Nykle.win] atis: enemy5 | Standing | HP 100 | hedef head 98 | isabet head -98 | SP Default | BA Force | MD 30 | bt 2t | hc 81% | sen ak47 | AA ?",
      "shot log uses the fire-time target, health, body aim, weapon, hitchance and backtrack")
enemy.m_iHealth = nil; lp.weapon_class = "CAK47"; tick(0)
handlers.aim_ack({ id = 201, target = 5, state = "spread", wanted_hitgroup = 2, wanted_damage = 40.4, backtrack = 0, hitchance = 55 })
check(printed[#printed] == "[Nykle.win] atis: enemy5 | Standing | HP ? | hedef chest 40 | iska spread | SP Default | BA Default | MD 30 | bt 0t | hc 55% | sen ak47 | AA ?",
      "shot log uses the result's own fields when present")
handlers.aim_ack({ id = 202, target = 5, state = "prediction error" })
check(printed[#printed] == "[Nykle.win] atis: enemy5 | Standing | HP ? | hedef ? | iska prediction error | SP Default | BA Default | MD 30 | bt ? | hc ? | sen ak47 | AA ?",
      "shot log marks missing fields")
-- Fake duck: the shot log marks it; safe points stay the resolver's own level (V1.0: the forced
-- Prefer of v5.4 is gone).
refs[SHORT.fakeduck].spec.value = true; tick(0)
check(ov("safe") == nil, "fake ducking: safe points are not forced (resolver level only)")
check(elements["switch:Safe points while fake ducking"] == nil, "no fake duck safe point option any more")
handlers.aim_fire({ id = 203, target = 5 }); handlers.aim_ack({ id = 203, target = 5, state = "spread" })
check(printed[#printed]:find("| SP Default |", 1, true) ~= nil and printed[#printed]:find("| sen ak47 FD |", 1, true) ~= nil,
      "the shot log marks shots fired while fake ducking")
refs[SHORT.fakeduck].spec.value = false; tick(0)
check(ov("safe") == nil, "fake duck released: still the resolver's own level")
world.threat = enemy; ack(5, "correction"); ack(5, "correction")
handlers.aim_fire({ id = 203, target = 5, hitgroup = 1, damage = 120, hitchance = 70, backtrack = 0 })
M("switch", "Adaptive resolver"):set(false); tick(0)
check(ov("safe") == nil, "override released before the result arrives")
handlers.aim_ack({ id = 203, target = 5, state = "correction" })
check(printed[#printed]:find("| SP Force |", 1, true) ~= nil,
      "shot log records the safe points in effect when the shot was fired")
M("switch", "Adaptive resolver"):set(true)
handlers.aim_fire({ id = 205, target = 5, hitgroup = 1, damage = 98 })
handlers.aim_ack({ id = 205, target = 5, state = "spread", wanted_hitgroup = 2, wanted_damage = 50 })
check(printed[#printed]:find("| hedef chest 50 |", 1, true) ~= nil, "the result's own target fields win over fire-time ones")
local shot_lines = #printed
M("switch", "Shot log"):set(false); handlers.aim_ack({ id = 204, target = 5, hitgroup = 1, damage = 50 })
check(#printed == shot_lines, "shot log can be turned off")
M("switch", "Shot log"):set(true)
handlers.level_init(); forget(); world.threat = nil; tick(0)

E("button", "Reset stats"):click()
M("switch", "Stats panel"):set(true)
ack(5, "correction"); ack(5, nil, 1, 100); ack(5, "spread"); ack(5, "misprediction"); draw()
check(contains(texts, "AIM   SHOT / HIT / CORR / SPREAD / OTHER") and contains(texts, "ALL   4 / 1 / 1 / 1 / 1"),
      "aim stats count hits and miss reasons")
E("button", "Reset stats"):click(); draw()
check(not contains(texts, "AIM   SHOT / HIT / CORR / SPREAD / OTHER"), "reset clears the aim stats")
M("switch", "Stats panel"):set(false)
M("switch", "Enable"):set(false); handlers.aim_ack({ target = 5, state = "correction" }); M("switch", "Enable"):set(true)
M("switch", "Stats panel"):set(true); draw(); M("switch", "Stats panel"):set(false)
check(not contains(texts, "AIM   SHOT / HIT / CORR / SPREAD / OTHER"), "shots are not counted while the script is disabled")
handlers.level_init(); forget()
reset_world()
M("switch", "Enable"):set(false)

-- Fake duck guard ----------------------------------------------------------------------------------
M("switch", "Enable"):set(true)
reset_world()
world.enemies = { enemy }; enemy.origin = vector(200, 0, 0); enemy.weapon_class = "CKnife"
refs[SHORT.fakeduck].spec.value = true; tick(0); draw()
check(ov("fakeduck") == false and ov("dt") == true and contains(texts, "STANDING")
      and printed[#printed] == "[Nykle.win] fake duck birakildi: enemy5 bicak/zeus ile 200 birim yakinda",
      "fake duck released when an enemy with a knife is close; the state's exploit comes back")
local fd_lines = #printed
enemy.origin = vector(320, 0, 0); advance(5)
check(ov("fakeduck") == false and #printed == fd_lines, "stays released inside the outer radius, logged once")
enemy.origin = vector(400, 0, 0); tick(0); draw()
check(ov("fakeduck") == nil and contains(texts, "FAKE DUCK"), "handed back to your bind once the knife is far")
enemy.origin = vector(320, 0, 0); advance(3)
check(ov("fakeduck") == nil, "an approaching knife only counts inside the inner radius")
enemy.origin = vector(150, 0, 0); tick(0)
check(ov("fakeduck") == false, "released again when it comes close")
enemy.weapon_class = "CAK47"; tick(0)
check(ov("fakeduck") == nil, "handed back when the enemy switches to a gun")
enemy.weapon_class = "CWeaponTaser"; tick(0)
check(ov("fakeduck") == false, "a zeus counts too")
enemy.weapon_class = "CKnife"; enemy.dormant = true; advance(2)
check(ov("fakeduck") == nil, "a dormant enemy's knife is not trusted")
enemy.dormant = nil; enemy.alive = false; advance(2)
check(ov("fakeduck") == nil, "a dead enemy's knife is ignored")
enemy.alive = true; tick(0)
M("switch", "Release fake duck near knife"):set(false)
local guard_off = true
for _ = 1, 6 do tick(0); if ov("fakeduck") ~= nil and _ > 1 then guard_off = false end end
check(guard_off and ov("fakeduck") == nil, "the guard can be turned off (stays off)")
M("switch", "Release fake duck near knife"):set(true); tick(0)
check(ov("fakeduck") == false, "and back on")
lp.alive = false; tick(0)
check(ov("fakeduck") == nil, "released when you die")
lp.alive = true
refs[SHORT.fakeduck].spec.value = false; advance(2)
check(ov("fakeduck") == nil, "no guard without fake duck")
-- Fake duck only when standing still (V1.0: off by default; fake duck is used on purpose for bunny hop
-- and instant peeks, the guard broke them). When on: in the air and while moving fake duck is released.
check(M("switch", "Fake duck only when standing still"):get() == false, "fake duck only when standing still: off by default")
enemy.weapon_class = "CAK47"; enemy.origin = vector(500, 0, 0)
refs[SHORT.fakeduck].spec.value = true; lp.m_vecVelocity = vector(250, 0, 0); advance(14)
check(ov("fakeduck") == nil, "off: fake duck held while running stays yours")
lp.m_fFlags = 0; advance(6)
check(ov("fakeduck") == nil, "off: fake duck held in the air (bunny hop) stays yours")
lp.m_fFlags = 1; lp.m_vecVelocity = vector(0, 0, 0); advance(4)
M("switch", "Fake duck only when standing still"):set(true); advance(3); draw()
check(ov("fakeduck") == nil and contains(texts, "FAKE DUCK"), "standing still: your fake duck works")
local fd_move_lines = #printed
lp.m_vecVelocity = vector(85, 0, 0); advance(6)
check(ov("fakeduck") == nil, "a short move (under 0.15 s, adjusting the angle) keeps fake duck")
lp.m_vecVelocity = vector(0, 0, 0); advance(1); lp.m_vecVelocity = vector(85, 0, 0); advance(6)
check(ov("fakeduck") == nil and #printed == fd_move_lines, "stopping in between starts the count over")
advance(6); draw()
check(ov("fakeduck") == false and ov("dt") == true and not contains(texts, "FAKE DUCK")
      and printed[fd_move_lines + 1] == "[Nykle.win] fake duck birakildi: hareket ediyorsun (fake duck DT/HS'yi kapatir; yerinde dururken calisir)",
      "moving: fake duck released, the exploit comes back (logged)")
lp.m_vecVelocity = vector(25, 0, 0); advance(2)
check(ov("fakeduck") == false, "slowing down (25 u/s) keeps it released")
lp.m_vecVelocity = vector(5, 0, 0); advance(2)
check(ov("fakeduck") == nil, "stopped: fake duck is yours again")
lp.m_vecVelocity = vector(30, 0, 0); advance(14)
check(ov("fakeduck") == nil, "a slow drift (30 u/s) does not release it")
lp.m_vecVelocity = vector(85, 0, 0); advance(12)
check(ov("fakeduck") == false and #printed == fd_move_lines + 1, "released again, not logged twice within 10 s")
lp.m_vecVelocity = vector(0, 0, 0); advance(2); lp.m_fFlags = 0; advance(2)
check(ov("fakeduck") == false, "in the air: released")
lp.m_fFlags = 1; advance(6)
check(ov("fakeduck") == nil, "landed and still: yours again")
M("switch", "Fake duck only when standing still"):set(false); lp.m_vecVelocity = vector(85, 0, 0); advance(2)
check(ov("fakeduck") == nil, "can be turned off")
M("switch", "Fake duck only when standing still"):set(true); advance(12)
check(ov("fakeduck") == false, "and back on")
refs[SHORT.fakeduck].spec.value = false; lp.m_vecVelocity = vector(0, 0, 0); advance(4)
check(ov("fakeduck") == nil, "key released: nothing overridden")
M("switch", "Fake duck only when standing still"):set(false)
enemy.weapon_class = nil
-- Knife and zeus damage is logged but kept out of the AA stats and anti-brute.
advance(17) -- the enemy came back to life above; let the alive cache refresh (no idle spin)
E("button", "Reset stats"):click(); M("switch", "Stats panel"):set(true)
B("Standing", "combo", "Body yaw"):set("Static"); world.threat = enemy; tick(0)
handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 1, dmg_health = 55, weapon = "knife_t" })
check(printed[#printed]:find("vuruldun: head -55 knife_t |", 1, true) ~= nil, "knife hit logged")
handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 2, dmg_health = 30, weapon = "taser" })
handlers.round_start({}); tick(0); draw()
check(not contains(texts, "STANDING   1 / 1 / 0 / 100% / -") and not contains(texts, "STANDING   2 / 1 / 0 / 100% / -")
      and side() == false, "knife and zeus hits are not AA stats and do not move the anti-brute phase")
handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 2, dmg_health = 30, weapon = "ssg08" }); draw()
check(contains(texts, "STANDING   1 / 0 / 0 / 100% / 0%"), "a bullet hit is still counted")
E("button", "Reset stats"):click(); M("switch", "Stats panel"):set(false)
B("Standing", "combo", "Body yaw"):set("Jitter")
enemy.weapon_class, enemy.origin = nil, vector(500, 0, 0)
world.enemies = { enemy }
handlers.level_init(); forget()
reset_world()

-- Smart body aim: snipers ----------------------------------------------------------------------------------
-- The target-based logic below is what runs with "Head unless body kills" off (its own section).
M("switch", "Head unless body kills (snipers)"):set(false)
reset_world()
world.threat = enemy; enemy.m_iHealth, enemy.m_ArmorValue = 100, 100
lp.weapon_class = "CWeaponSSG08"; tick(0)
check(ov("body_aim") == nil, "scout vs full HP with your Default body aim: untouched (head stays open)")
refs[SHORT.body_aim].spec.value = "Prefer"; tick(0)
check(ov("body_aim") == "Default", "scout body shot cannot kill: your Prefer is lifted so the head is not passed over")
enemy.m_iHealth = 70; tick(0); draw()
check(ov("body_aim") == "Force" and contains(texts, "BAIM"), "a chest shot kills (~73 at 500u): body aim forced")
-- While the script overrides Body Aim your own value is not readable; a tick without an
-- override (another weapon) reads it again.
refs[SHORT.body_aim].spec.value = "Default"; lp.weapon_class = "CAK47"; tick(0); lp.weapon_class = "CWeaponSSG08"; tick(0)
check(ov("body_aim") == "Force", "lethal body shot with your Default: forced")
enemy.origin = vector(3000, 0, 0); tick(0)
check(ov("body_aim") == nil, "range falloff makes the same shot non-lethal far away")
-- V1.0 log: "BA Force" at 45 HP, chest shots of 26-27 through a wall (the table said ~58). The
-- lethal check traces the real chest damage (walls, range, armor) when it can.
do
    lp.get_eye_position = function() return vector(0, 0, 64) end
    enemy.get_hitbox_position = function(_, n) return vector(500, 0, n == 5 and 50 or 64) end
    enemy.origin, enemy.m_iHealth = vector(500, 0, 0), 70
    world.trace = function(to) if to.z == 50 then return 30 end return 0 end
    tick(0)
    check(ov("body_aim") == nil, "a wall between: the traced chest damage (30) does not kill 70 HP, no forced body")
    world.trace = function(to) if to.z == 50 then return 80 end return 0 end
    tick(0)
    check(ov("body_aim") == "Force", "the traced chest damage (80) kills 70 HP: body forced")
    enemy.origin = vector(3000, 0, 0); tick(0)
    check(ov("body_aim") == "Force", "traced damage wins over the range table")
    lp.get_eye_position, enemy.get_hitbox_position, world.trace = nil, nil, NO_TRACE
    enemy.m_iHealth = 70; tick(0)
end
enemy.origin = vector(500, 0, 0); enemy.m_iHealth, enemy.m_ArmorValue = 85, 0; tick(0)
check(ov("body_aim") == "Force", "no armor: 86 chest damage kills 85 HP")
enemy.m_iHealth = 90; tick(0); draw()
check(ov("body_aim") == nil and not contains(texts, "BAIM"), "but not 90 HP")
enemy.m_ArmorValue = 100; enemy.m_iHealth = 100
refs[SHORT.body_aim].spec.value = "Force"; tick(0)
check(ov("body_aim") == nil, "your own Force (baim key) is never changed")
refs[SHORT.body_aim].spec.value = "Default"
lp.weapon_class = "CWeaponAWP"; tick(0)
check(ov("body_aim") == "Force", "AWP chest kills a full HP armored enemy")
lp.weapon_class = "CDEagle"; lp.weapon_index = 64; enemy.m_iHealth = 80; tick(0)
check(ov("body_aim") == nil, "revolver chest (~75) does not kill 80 HP")
enemy.m_iHealth = 70; tick(0)
check(ov("body_aim") == "Force", "but kills 70 HP")
lp.weapon_class, lp.weapon_index = "CAK47", 7; tick(0); draw()
check(ov("body_aim") == nil and not contains(texts, "BAIM"), "other weapons are left alone")
lp.weapon_class = "CWeaponSSG08"; enemy.m_iHealth = nil; tick(0)
check(ov("body_aim") == nil, "unknown health: left alone")
enemy.m_iHealth = 0; tick(0)
check(ov("body_aim") == nil, "zero health (dead / not updated): left alone")
enemy.m_iHealth = 100; enemy2.m_iHealth, enemy2.m_ArmorValue = 40, 100
handlers.aim_fire({ id = 300, target = 7 }); tick(0)
check(ov("body_aim") == "Force", "the enemy the aimbot just shot at decides")
advance(100)
check(ov("body_aim") == nil, "back to the threat after a while")
-- Force must not block every shot: only the head visible means no shot at all.
enemy.m_iHealth = 50; world.trace = function() return 30 end; advance(25)
check(ov("body_aim") == "Force", "forced while under half a second in sight without a shot")
advance(10); draw()
check(ov("body_aim") == "Prefer" and contains(texts, "BAIM"), "no shot for half a second in sight: relaxed to prefer")
handlers.aim_fire({ id = 301, target = 5 }); tick(0)
check(ov("body_aim") == "Force", "a shot at the target tries force again")
advance(40)
check(ov("body_aim") == "Prefer", "and relaxes again if it blocks")
enemy.m_iHealth = 100; tick(0); enemy.m_iHealth = 50; tick(0)
check(ov("body_aim") == "Force", "no longer lethal for a moment: the guard starts over")
world.trace = NO_TRACE; advance(80)
check(ov("body_aim") == "Force", "no relaxing while nobody sees you")
M("switch", "Smart body aim"):set(false); tick(0); draw()
check(ov("body_aim") == nil and not contains(texts, "BAIM"), "can be turned off")
M("switch", "Smart body aim"):set(true)
enemy.m_iHealth, enemy.m_ArmorValue, enemy2.m_iHealth, enemy2.m_ArmorValue = nil, nil, nil, nil
handlers.level_init(); forget()
reset_world()

-- Smart body aim beyond snipers --------------------------------------------------------------------
reset_world()
world.threat = enemy; enemy.m_iHealth, enemy.m_ArmorValue = 100, 100
lp.weapon_class = "CWeaponSCAR20"; tick(0); draw()
check(ov("dt") == true and ov("body_aim") == "Prefer" and contains(texts, "BAIM"),
      "auto with a charged DT: two chest hits (~65 each) kill, body preferred")
aa.charge = 0.5; tick(0)
check(ov("body_aim") == nil, "auto while DT recharges: one chest hit does not kill, left alone")
aa.charge = 1; lp.weapon_class = "CDEagle"; lp.weapon_index = 1; tick(0)
check(ov("body_aim") == nil, "deagle DT: two chest hits (~95) do not kill 100 HP")
enemy.m_iHealth = 90; tick(0)
check(ov("body_aim") == "Prefer", "but kill 90 HP")
enemy.m_iHealth = 100; lp.weapon_class, lp.weapon_index = "CAK47", 7; tick(0)
check(ov("body_aim") == nil, "rifle without resolver misses: left alone")
local function ack_on(target, state, extra)
    local e = { target = target, state = state, hitgroup = 1, damage = 100 }
    for k, v in pairs(extra or {}) do e[k] = v end
    handlers.aim_ack(e); tick(0)
end
ack_on(5, "correction"); draw()
check(ov("body_aim") == nil and not contains(texts, "BAIM"), "one resolver miss: safe points only")
ack_on(5, "correction")
check(ov("safe") == "Force" and ov("body_aim") == "Prefer", "two resolver misses: body aim preferred against that enemy")
world.trace = function() return 30 end; advance(70)
check(ov("safe") == "Prefer" and ov("body_aim") == "Prefer", "force relaxed by the stall guard, body aim stays")
world.trace = NO_TRACE
lp.weapon_class = "CWeaponSSG08"; tick(0)
check(ov("body_aim") == nil, "scout after resolver misses: a non-lethal body hit is not preferred")
refs[SHORT.body_aim].spec.value = "Prefer"; tick(0)
check(ov("body_aim") == "Default", "scout keeps lifting your Prefer when the body does not kill")
refs[SHORT.body_aim].spec.value = "Default"
lp.weapon_class = "CC4"; tick(0)
check(ov("body_aim") == nil, "C4: nothing to aim")
lp.weapon_class = "CKnife"; tick(0)
check(ov("body_aim") == nil, "knife: nothing to aim")
lp.weapon_class = "CWeaponSSG08"; enemy.m_iHealth = nil; tick(0)
check(ov("body_aim") == nil, "scout with unknown health after resolver misses: body not preferred")
enemy.m_iHealth = 100; lp.weapon_class = "CAK47"
M("switch", "Head unless body kills (snipers)"):set(true)
-- Head-aimed shots that land elsewhere are not resolver successes.
ack_on(5, nil); ack_on(5, nil)
check(ov("safe") == "Force", "window c c h h: still level 2")
ack_on(5, nil, { wanted_hitgroup = 1, hitgroup = 2, damage = 28 })
check(ov("safe") == "Force", "aimed at the head, hit the chest: not counted as a resolver hit")
handlers.aim_fire({ id = 400, target = 5, hitgroup = 1, damage = 110 })
ack_on(5, nil, { id = 400, hitgroup = 5, damage = 20 })
check(ov("safe") == "Force", "the fire-time target hitgroup is used when the result has none")
ack_on(5, nil, { wanted_hitgroup = 8, hitgroup = 1 })
check(ov("safe") == "Prefer", "aimed at the neck, hit the head: counted")
ack_on(5, nil, { wanted_hitgroup = 2, hitgroup = 5 })
check(ov("safe") == nil, "aimed at the body, hit an arm: counted")
forget(); ack_on(5, "correction"); ack_on(5, "correction"); ack_on(5, nil); ack_on(5, nil)
ack_on(5, nil, { wanted_hitgroup = 8, hitgroup = 2 })
check(ov("safe") == "Force", "aimed at the neck, hit the chest: not counted")
ack_on(5, nil, { wanted_hitgroup = 1, hitgroup = 8 })
check(ov("safe") == "Prefer", "aimed at the head, hit the neck: counted")
-- The enemy that can see you is the likely aimbot target.
forget(); world.enemies = { enemy, enemy2 }
ack_on(7, "correction"); ack_on(7, "correction")
world.threat = enemy; tick(0)
check(ov("safe") == nil, "threat without history")
world.trace = function(to, from) return from == enemy2 and 30 or 0 end; advance(6)
check(ov("safe") == "Force", "a flanker in sight with two resolver misses: its level applies")
world.trace = NO_TRACE; advance(16)
check(ov("safe") == nil, "out of sight: back to the threat")
world.enemies = { enemy }
enemy.m_iHealth, enemy.m_ArmorValue = nil, nil
handlers.level_init(); forget()
reset_world()

-- Enemy tracker: jitter prior, defensive and LC ----------------------------------------------------
reset_world(); forget()
world.threat = enemy; world.enemies = { enemy }
local sim = 50
local function feed(yaw, n, step)
    for _ = 1, n or 1 do
        sim = sim + (step or 1 / 64)
        enemy.m_flSimulationTime = sim
        if yaw ~= nil then
            enemy.m_angEyeAngles = vector(0, type(yaw) == "function" and yaw() or yaw, 0)
        end
        tick(0)
    end
end
local flip_yaw = 30
local function jitter_yaw() flip_yaw = -flip_yaw; return flip_yaw end
feed(jitter_yaw, 4)
check(ov("safe") == nil, "fewer than 4 updates: no jitter verdict yet")
local lines_jit = #printed
feed(jitter_yaw, 2); draw()
check(ov("safe") == "Prefer" and contains(texts, "RES 1 JIT")
      and printed[#printed] == "[Nykle.win] resolver: enemy5 jitter 60\194\176 -> safe points Prefer (veri yok, on bilgi)",
      "a jitter AA enemy without results: safe points prefer from the first shot")
feed(jitter_yaw, 10)
check(#printed == lines_jit + 1 and ov("safe") == "Prefer", "the prior is logged once per enemy")
handlers.level_init(); feed(jitter_yaw, 7)
check(#printed == lines_jit + 2, "and again after a map change")
handlers.aim_fire({ id = 500, target = 5, hitgroup = 1, damage = 100 })
handlers.aim_ack({ id = 500, target = 5, hitgroup = 1, damage = 100 }); tick(0)
check(ov("safe") == nil and printed[#printed]:find("| sen ak47 | AA jit 60$") ~= nil,
      "a head hit gives the state real data: the prior gives way; the shot log shows the enemy's jitter")
enemy.m_flDuckAmount = 1; tick(0); draw()
check(ov("safe") == "Prefer" and contains(texts, "RES 1 JIT"), "another state without data: prior again")
enemy.m_flDuckAmount = nil
M("switch", "Adaptive resolver"):set(false); tick(0)
check(ov("safe") == nil, "no prior while the resolver is off")
M("switch", "Adaptive resolver"):set(true)
-- The verdict is remembered: an average that dips below the threshold keeps the prior.
enemy.m_flDuckAmount = 1; feed(30, 7)
check(ov("safe") == "Prefer", "jitter average dropping (fluctuating AA) keeps the prior for a while")
globals.realtime = globals.realtime + 61; tick(0)
check(ov("safe") == nil, "after a minute without jitter the prior ends")
enemy.m_flDuckAmount = nil
forget(); feed(jitter_yaw, 7)
check(ov("safe") == "Prefer", "jitter remembered")
handlers.level_init(); feed(30, 7)
check(ov("safe") == nil, "a map change clears the jitter memory")
feed(jitter_yaw, 7); feed(30, 7)
check(ov("safe") == "Prefer", "jitter remembered again")
forget(); tick(0)
check(ov("safe") == nil, "forget clears the jitter memory")
forget()
local turn = 0
local function mouse_yaw() turn = turn + 10; return turn end
feed(mouse_yaw, 7)
check(ov("safe") == nil, "an enemy turning with the mouse (10 degrees per update) gets no prior")
local edge = 175
local function edge_yaw() edge = -edge; return edge end
feed(edge_yaw, 7)
check(ov("safe") == nil, "small changes across the 180 degree seam are small, not 350 degree jitter")
feed(30, 7)
check(ov("safe") == nil, "a static AA enemy gets no prior")
handlers.aim_fire({ id = 501, target = 5 }); handlers.aim_ack({ id = 501, target = 5, state = "spread" })
check(printed[#printed]:find("| AA statik$") ~= nil, "static AA in the shot log")
-- Defensive: the simulation time falls behind the highest seen (a fake record, hidden angles).
-- V1.0: a correction miss at such a record is not learned (safe points cannot fix it); a miss at
-- a real record right after (still "def" in the last 16 ticks) is.
feed(30, 1, -0.1)
handlers.aim_fire({ id = 502, target = 5 }); handlers.aim_ack({ id = 502, target = 5, state = "correction" }); tick(0)
check(ov("safe") == nil and printed[#printed]:sub(-30) == "| AA statik, def (sahte kayit)",
      "a correction miss at a defensive (fake) record is not learned, the shot log says so")
E("button", "Reset stats"):click(); M("switch", "Stats panel"):set(true)
handlers.aim_fire({ id = 503, target = 5 }); handlers.aim_ack({ id = 503, target = 5, state = "correction" }); draw()
check(contains(texts, "ALL   1 / 0 / 0 / 0 / 1"), "counted as OTHER, not CORR")
feed(30, 6)
handlers.aim_fire({ id = 504, target = 5 }); handlers.aim_ack({ id = 504, target = 5, state = "correction" }); tick(0)
check(ov("safe") == nil, "six updates later the record is still behind the newest (still fake)")
feed(30, 1)
handlers.aim_fire({ id = 505, target = 5 }); handlers.aim_ack({ id = 505, target = 5, state = "correction" }); tick(0)
check(ov("safe") == "Prefer" and printed[#printed - 1]:find("| AA statik, def$") ~= nil,
      "a real record again (defensive in the last 16 ticks): the miss is learned")
E("button", "Reset stats"):click(); M("switch", "Stats panel"):set(false)
feed(30, 30)
-- Jitter is measured on real records only (V1.0): hidden yaw (spin / random) in the defensive
-- records is not the enemy's AA. Static real yaw with spinning defensive records: no prior.
do
    forget(); feed(30, 10)
    local spin = 30
    for _ = 1, 8 do
        spin = spin + 97
        feed(spin, 1, -0.05); feed(30, 1, 0.06)
    end
    handlers.aim_fire({ id = 510, target = 5 }); handlers.aim_ack({ id = 510, target = 5, state = "spread" })
    check(ov("safe") == nil and printed[#printed]:find("| AA statik", 1, true) ~= nil,
          "spinning defensive records, static real ones: static AA, no jitter prior")
    local real = 30
    for _ = 1, 8 do
        real = -real
        feed(spin, 1, -0.05); feed(real, 1, 0.06)
    end
    check(ov("safe") == "Prefer", "real records jittering (defensive ones in between): the jitter prior")
    forget(); feed(30, 30)
end
-- V1.0: the aimbot is never held back while the enemy is in defensive (v5.5's wait is gone).
do
    feed(30, 1, -0.5); draw()
    check(ov("hitboxes") == nil and not contains(texts, "WAIT DEF") and elements["switch:Wait out enemy defensive"] == nil,
          "enemy in defensive: hitboxes untouched, no wait option")
    feed(30, 40)
end
-- Body aim: a DT gun at an enemy in defensive (spin moves the head around the body) prefers the body.
forget(); feed(30, 20)
check(ov("body_aim") == nil, "no resolver misses, enemy not in defensive: body aim untouched")
feed(30, 1, -0.5); advance(15)
check(ov("body_aim") == "Prefer", "DT gun, enemy in defensive: body aim prefer")
feed(30, 40)
check(ov("body_aim") == nil, "enemy out of defensive: body aim back")
feed(30, 30)
-- An enemy fake ducking (on the ground, half ducked, choked packets twice in a row): its own state.
handlers.level_init(); forget(); enemy.m_fFlags = 1; enemy.m_flDuckAmount = 0.5
feed(30, 2); feed(30, 1, 14 / 64)
handlers.aim_fire({ id = 520, target = 5 }); handlers.aim_ack({ id = 520, target = 5, state = "spread" })
check(printed[#printed]:find("atis: enemy5 | Standing |", 1, true) ~= nil, "one choked half-ducked update is not enough")
local lines_fd = #printed
feed(30, 1, 14 / 64); draw()
check(ov("safe") == nil and not contains(texts, "RES 1 FD") and #printed == lines_fd,
      "a fake ducking enemy: its own state, but no safe point prior without data (V1.0)")
handlers.aim_fire({ id = 521, target = 5 }); handlers.aim_ack({ id = 521, target = 5, state = "spread" })
check(printed[#printed]:find("atis: enemy5 | Fakeduck |", 1, true) ~= nil, "the shot log shows the fake duck state")
advance(12)
handlers.aim_fire({ id = 526, target = 5 }); handlers.aim_ack({ id = 526, target = 5, state = "spread" })
check(printed[#printed]:find("atis: enemy5 | Fakeduck |", 1, true) ~= nil, "still a fake duck between its packets")
check(ov("body_aim") == "Prefer", "a fake ducking enemy (head height jumps between records): DT gun prefers the body")
handlers.aim_fire({ id = 522, target = 5, hitgroup = 1 }); handlers.aim_ack({ id = 522, target = 5, hitgroup = 1, damage = 100 })
feed(30, 1, 14 / 64)
check(ov("safe") == nil, "a hit in the fake duck state: still default")
handlers.aim_fire({ id = 527, target = 5 }); handlers.aim_ack({ id = 527, target = 5, state = "correction" }); tick(0); draw()
check(contains(texts, "RES 1 FD"), "a resolver miss in the fake duck state: the indicator names the state")
enemy.m_flDuckAmount = 1; feed(30, 40)
handlers.aim_fire({ id = 523, target = 5 }); handlers.aim_ack({ id = 523, target = 5, state = "spread" })
check(printed[#printed]:find("atis: enemy5 | Crouch |", 1, true) ~= nil, "fully crouched for a while: Crouch again")
feed(30, 1, 14 / 64); feed(30, 1, 14 / 64)
handlers.aim_fire({ id = 528, target = 5 }); handlers.aim_ack({ id = 528, target = 5, state = "spread" })
check(printed[#printed]:find("atis: enemy5 | Crouch |", 1, true) ~= nil, "fully crouched with choked packets: Crouch (not a fake duck)")
enemy.m_flDuckAmount = 0; feed(30, 1, 14 / 64); feed(30, 1, 14 / 64)
handlers.aim_fire({ id = 529, target = 5 }); handlers.aim_ack({ id = 529, target = 5, state = "spread" })
check(printed[#printed]:find("atis: enemy5 | Standing |", 1, true) ~= nil, "standing with choked packets (fake lag): Standing")
enemy.m_flDuckAmount = 0.5; feed(30, 1, 14 / 64); feed(30, 1); feed(30, 1, 14 / 64)
handlers.aim_fire({ id = 524, target = 5 }); handlers.aim_ack({ id = 524, target = 5, state = "spread" })
check(printed[#printed]:find("atis: enemy5 | Standing |", 1, true) ~= nil, "not choked twice in a row: not a fake duck")
enemy.m_fFlags = 0; feed(30, 1, 14 / 64); feed(30, 1, 14 / 64)
handlers.aim_fire({ id = 525, target = 5 }); handlers.aim_ack({ id = 525, target = 5, state = "spread" })
check(printed[#printed]:find("atis: enemy5 | Air |", 1, true) ~= nil, "in the air: Air")
enemy.m_fFlags, enemy.m_flDuckAmount = nil, nil; feed(30, 40)
-- LC break: more than 64 units between two updates.
forget(); enemy.origin = vector(600, 0, 0); feed(30, 1)
handlers.aim_fire({ id = 505, target = 5 }); handlers.aim_ack({ id = 505, target = 5, state = "correction" }); tick(0)
check(ov("safe") == nil and printed[#printed]:find("| AA statik, LC$") ~= nil, "a correction miss right after an LC break is not learned")
E("button", "Reset stats"):click(); M("switch", "Stats panel"):set(true)
enemy.origin = vector(500, 0, 0); feed(30, 1)
handlers.aim_fire({ id = 508, target = 5 }); feed(30, 30)
handlers.aim_ack({ id = 508, target = 5, state = "correction" }); draw()
check(ov("safe") == nil and printed[#printed]:find("| AA statik, LC$") ~= nil and contains(texts, "ALL   1 / 0 / 0 / 0 / 1"),
      "the enemy's state when the shot was fired decides; an excused miss counts as OTHER")
E("button", "Reset stats"):click(); M("switch", "Stats panel"):set(false)
forget(); enemy.origin = vector(600, 0, 0); feed(30, 1); feed(30, 5)
handlers.aim_fire({ id = 510, target = 5 }); handlers.aim_ack({ id = 510, target = 5, state = "correction" }); tick(0)
check(ov("safe") == nil and printed[#printed]:find("| AA statik, LC$") ~= nil, "an LC break still counts a few ticks later")
feed(30, 20); enemy.origin = vector(560, 0, 0); feed(30, 1)
handlers.aim_fire({ id = 506, target = 5 }); handlers.aim_ack({ id = 506, target = 5, state = "correction" }); tick(0)
check(ov("safe") == "Prefer", "a 40 unit move is not an LC break")
enemy.origin = vector(500, 0, 0)
-- A long gap (dormant / respawn) starts over; dormant and dead enemies are dropped.
forget(); feed(jitter_yaw, 6)
check(ov("safe") == "Prefer", "jitter history built")
feed(jitter_yaw, 1, 5); feed(jitter_yaw, 2)
handlers.aim_fire({ id = 509, target = 5 }); handlers.aim_ack({ id = 509, target = 5, state = "spread" })
check(printed[#printed]:sub(-7) == " | AA ?", "after a long gap the jitter history starts over")
feed(jitter_yaw, 6)
enemy.dormant = true; tick(0)
handlers.aim_fire({ id = 507, target = 5 }); handlers.aim_ack({ id = 507, target = 5, state = "spread" })
check(printed[#printed]:sub(-7) == " | AA ?", "a dormant enemy has no profile")
enemy.dormant = nil
enemy.m_flSimulationTime, enemy.m_angEyeAngles = nil, nil
-- V1.0: far enemies get no special treatment (v5.6 gave prefer without data and force after one
-- miss; force without a safe point stopped the shots).
do
    handlers.level_init(); forget(); world.threat = enemy; enemy.origin = vector(2000, 0, 0); tick(0); draw()
    check(ov("safe") == nil and not contains(texts, "RES 1 FAR"), "a far enemy without data: default safe points")
    ack(5, "correction"); draw()
    check(ov("safe") == "Prefer" and contains(texts, "RES 1 STAND"), "far: one resolver miss is prefer, like near")
    ack(5, "correction"); draw()
    check(ov("safe") == "Force" and contains(texts, "RES 2 STAND"), "two misses: force")
    enemy.origin = vector(500, 0, 0); handlers.level_init(); forget(); tick(0)
end
-- Faster stall guard: half a second without a shot in mutual sight.
forget(); world.trace = function() return 30 end; tick(0)
ack(5, "correction"); ack(5, "correction"); advance(25)
check(ov("safe") == "Force", "force kept for under half a second")
advance(10)
check(ov("safe") == "Prefer", "relaxed after half a second without a shot")
world.trace = NO_TRACE; advance(70)
-- V1.0: scout / AWP / R8 with the lethal-only rule: at most prefer (force leaves no safe point on the
-- head, the only lethal spot on a full HP enemy, so the scout never fired).
do
    forget(); lp.weapon_class = "CAK47"; tick(0)
    ack(5, "correction"); ack(5, "correction"); draw()
    check(ov("safe") == "Force" and contains(texts, "RES 2 STAND"), "rifle: two resolver misses, force")
    -- V1.0: only the head visible (an enemy crouching a little above you): no force either.
    lp.get_eye_position = function() return vector(0, 0, 64) end
    enemy.get_hitbox_position = function(_, n) return vector(500, 0, n == 0 and 64 or 40) end
    world.trace = function(to, from) if from == lp and to.z == 64 then return 100 end return 0 end
    tick(0); draw()
    check(ov("safe") == "Prefer" and contains(texts, "RES 1 STAND"),
          "rifle, only the head visible: prefer (force would leave nothing to shoot)")
    world.trace = function(_, from) if from == lp then return 30 end return 0 end
    tick(0)
    check(ov("safe") == "Force", "the body visible again: force")
    enemy.get_hitbox_position = nil; tick(0)
    check(ov("safe") == "Force", "the enemy's hitboxes unreadable: force stays")
    lp.get_eye_position, enemy.get_hitbox_position, world.trace = nil, nil, NO_TRACE
    tick(0)
    lp.weapon_class = "CWeaponSSG08"; tick(0); draw()
    check(ov("safe") == "Prefer" and contains(texts, "RES 1 STAND"), "scout (lethal only): prefer, not force")
    lp.weapon_class = "CWeaponAWP"; tick(0)
    check(ov("safe") == "Prefer", "AWP too")
    M("switch", "Head unless body kills (snipers)"):set(false); tick(0)
    check(ov("safe") == "Force", "without the lethal-only rule: force again")
    M("switch", "Head unless body kills (snipers)"):set(true); lp.weapon_class = "CAK47"
end
handlers.level_init(); forget()
reset_world()

-- Phase 5 with the default jitter: the desync side is Neverlose's (body freestanding), the yaw keeps jittering.
reset_world(); forget(); world.threat = enemy; world.enemies = { enemy }; tick(0)
for _ = 1, 5 do advance(8); handlers.bullet_impact({ userid = 5, x = -500, y = 6, z = 64 }); tick(0) end
do
    local offsets = {}
    for _ = 1, 8 do tick(0); tick(1); offsets[ov("offset")] = true end
    check(ov("body_fs") == "Peek Fake" and ov("body") == true and offsets[-23] and offsets[51],
          "phase 5 with jitter: body freestanding picks the desync side, the yaw keeps jittering")
end
handlers.round_start({}); forget()
do
-- Round summary: where the bullets hit you this round, one line when the next round starts.
reset_world(); world.threat = enemy; world.enemies = { enemy }; lp.weapon_class = "CWeaponSSG08"; tick(0); tick(0)
local lines_sum = #printed
handlers.round_start({})
check(#printed == lines_sum, "no bullets this round: no summary")
handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 1, dmg_health = 100, weapon = "ssg08" })
lp.m_vecVelocity = vector(250, 0, 0); advance(3)
handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 2, dmg_health = 30, weapon = "ssg08" })
handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 1, dmg_health = 50, weapon = "knife_t" })
lp.m_vecVelocity = vector(0, 0, 0); advance(8)
lines_sum = #printed
handlers.round_start({})
check(printed[lines_sum + 1] == "[Nykle.win] round ozeti: 2 mermi, 1 kafa | Standing 1/1, Moving 0/1 | kafa fazlari 0:1 | HS 2 | gormedi 2",
      "round summary: bullets, headshots, per state, the phases of the headshots, exploit, unseen (knife not counted)")
lines_sum = #printed
handlers.round_start({})
check(#printed == lines_sum, "the summary starts over each round")
M("switch", "Hit log"):set(false)
handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 1, dmg_health = 100, weapon = "ssg08" })
handlers.round_start({})
check(#printed == lines_sum, "no summary with the hit log off")
M("switch", "Hit log"):set(true)
lp.weapon_class = "CAK47"; aa.charge = 1; tick(0)
handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 1, dmg_health = 100, weapon = "ssg08" })
handlers.round_start({})
check(printed[#printed]:find("| DT 1 |", 1, true) ~= nil and printed[#printed]:find("round ozeti: 1 mermi", 1, true) ~= nil,
      "the hit log turned off and on again: only this round's bullet; the exploit is DT with a rifle")
M("switch", "Auto exploit"):set(false); refs[SHORT.dt].spec.value = true; refs[SHORT.hs].spec.value = true; tick(0)
handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 1, dmg_health = 100, weapon = "ssg08" })
handlers.round_start({})
check(printed[#printed]:find("| DT 1 |", 1, true) ~= nil, "both bound: DT counts (it comes first in Neverlose)")
M("switch", "Auto exploit"):set(true); refs[SHORT.dt].spec.value = false; refs[SHORT.hs].spec.value = false
end
forget(); reset_world()

-- Adaptive AA: the least-hit phase for enemies without their own -------------------------------------
reset_world(); forget()
B("Standing", "combo", "Body yaw"):set("Static")
world.threat = enemy; world.enemies = { enemy, enemy2 }; tick(0)
M("switch", "Stats panel"):set(true); draw()
check(contains(texts, "YERDE   0* 0/0   1 0/0   2 0/0   3 0/0   4 0/0   5 0/0") and side() == false, "no data: phase 0, the base AA")
handlers.player_hurt({ userid = 1, attacker = 7, hitgroup = 1, dmg_health = 100, weapon = "ssg08" }); tick(0)
check(side() == false, "one headshot does not change the default")
local lines_aa = #printed
handlers.player_hurt({ userid = 1, attacker = 7, hitgroup = 1, dmg_health = 100, weapon = "ssg08" }); tick(0); draw()
check(side() == true and ov("offset") == 51 and contains(texts, "BRUTE 1") and contains(texts, "YERDE   0 2/2   1* 0/0   2 0/0   3 0/0   4 0/0   5 0/0")
      and contains(texts, "HAREKET   0* 0/0   1 0/0   2 0/0   3 0/0   4 0/0   5 0/0")
      and printed[lines_aa + 1] == "[Nykle.win] AA (yerde): en az vurulan faz 1 (0/0 kafa isabeti) -> verisi olmayan dusmanlara faz 1",
      "two headshots at phase 0 while standing: enemies without their own phase start at phase 1 on the ground")
lp.m_vecVelocity = vector(250, 0, 0); advance(2)
draw()
check(not contains(texts, "BRUTE 1") and ov("offset") == yaw_for(-20, 50), "moving uses its own statistics: still phase 0")
lp.m_vecVelocity = vector(0, 0, 0); advance(2)
world.threat = enemy2; tick(0)
check(side() == true and ov("offset") == 51,
      "the enemy that hit you twice while the AA showed phase 0 learns phase 1 (V1.0; not 2, it never saw phase 1)")
world.threat = enemy
for _ = 1, 3 do
    advance(12); handlers.bullet_impact({ userid = 5, x = -500, y = 6, z = 64 }); advance(12)
end
draw()
check(contains(texts, "YERDE   0 2/2   1* 0/1   2 0/1   3 0/1   4 0/0   5 0/0"), "each near miss is counted for the phase in use (anti-brute moves on)")
handlers.round_start({}); tick(0)
handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 2, dmg_health = 30, weapon = "ssg08" })
handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 1, dmg_health = 50, weapon = "knife_t" }); draw()
check(contains(texts, "YERDE   0 2/2   1* 0/1   2 0/1   3 0/1   4 0/0   5 0/0"), "body hits and knife hits are not counted")
handlers.level_init()
check(db.ant_a_m_memory.phase_groups.still[1].hits == 2 and db.ant_a_m_memory.phase_groups.still[2].shots == 1
      and db.ant_a_m_memory.phase_groups.air[1].shots == 0, "phase statistics are saved per group")
M("switch", "Anti-bruteforce"):set(false)
for _ = 1, 45 do
    advance(12); handlers.bullet_impact({ userid = 5, x = -500, y = 6, z = 64 }); advance(12)
end
M("switch", "Anti-bruteforce"):set(true); draw()
local zero_shots
for _, t in ipairs(texts) do local n = t:match("^YERDE   0%*? %d+/(%d+)") if n then zero_shots = tonumber(n) end end
check(zero_shots ~= nil and zero_shots > 0 and zero_shots <= 40, "counts are halved past 40 so recent games weigh more (" .. tostring(zero_shots) .. ")")
check(contains(texts, "BRUTE 1") == false and side() == false, "many misses at phase 0 make it the least-hit phase again")
forget(); draw()
check(contains(texts, "YERDE   0* 0/0   1 0/0   2 0/0   3 0/0   4 0/0   5 0/0") and side() == false, "forget clears the phase statistics")
-- V1.0: a phase hit on about half the head bullets is left for phases not tried yet (log: "AA (peek):
-- en az vurulan faz 1 (16/33 kafa isabeti)" while the other phases were never tried).
do
    M("switch", "Anti-bruteforce"):set(false)
    local function yerde()
        draw()
        for _, t in ipairs(texts) do
            if t:find("^YERDE") then
                local h, n = t:match("^YERDE   0%*? ([%d%.]+)/([%d%.]+)")
                return tonumber(t:match("(%d)%*")), tonumber(h), tonumber(n)
            end
        end
    end
    local moved
    for _ = 1, 30 do
        handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 1, dmg_health = 1, weapon = "ssg08" }); advance(12)
        local star, h, n = yerde()
        if star ~= 0 then moved = { star = star, h = h, n = n }; break end
        handlers.bullet_impact({ userid = 5, x = -500, y = 6, z = 64 }); advance(12)
        star, h, n = yerde()
        if star ~= 0 then moved = { star = star, h = h, n = n }; break end
    end
    -- 2/3 is exactly 0.1 worse than an untried phase (0.4 vs 0.3): no switch; 3/5 (0.415) switches.
    check(moved ~= nil and moved.star == 1 and moved.h == 3 and moved.n == 5,
          "phase 0 hit on half the head bullets: an untried phase is used from the 3rd head hit in 5 bullets (" ..
          (moved and (moved.h .. "/" .. moved.n) or "never") .. ")")
    M("switch", "Anti-bruteforce"):set(true)
    forget()
end
-- Safe head, Manual and Fake duck have their own AA: their hits do not teach the movement groups.
M("combo", "Manual yaw"):set("Left"); tick(0)
handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 1, dmg_health = 100, weapon = "ssg08" })
advance(12); handlers.bullet_impact({ userid = 5, x = -500, y = 6, z = 64 }); advance(12)
handlers.bullet_impact({ userid = 5, x = -500, y = 6, z = 64 })
handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 1, dmg_health = 100, weapon = "ssg08" }); advance(12)
M("combo", "Manual yaw"):set("Off")
lp.m_fFlags, lp.m_flDuckAmount, lp.weapon_class = 0, 1, "CKnife"; tick(0); tick(0)
handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 1, dmg_health = 100, weapon = "ssg08" })
lp.m_fFlags, lp.m_flDuckAmount, lp.weapon_class = 1, 0, "CAK47"; advance(4); draw()
check(contains(texts, "YERDE   0* 0/0   1 0/0   2 0/0   3 0/0   4 0/0   5 0/0") and contains(texts, "HAVA   0* 0/0   1 0/0   2 0/0   3 0/0   4 0/0   5 0/0"),
      "hits and near misses in Manual and Safe head are not counted (their own AA)")
handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 1, dmg_health = 100, weapon = "ssg08" }); draw()
local still_hits, still_shots = 0, 0
for _, t in ipairs(texts) do
    if t:find("^YERDE") then
        for h, n in t:gmatch("(%d+)/(%d+)") do still_hits, still_shots = still_hits + tonumber(h), still_shots + tonumber(n) end
    end
end
check(still_hits == 1 and still_shots == 1, "back in the standing AA: counted again (at the enemy's learned phase)")
forget(); draw()
lp.m_vecVelocity = vector(250, 0, 0); advance(2)
handlers.bullet_impact({ userid = 5, x = -500, y = 6, z = 64 })
lp.m_vecVelocity = vector(0, 0, 0); advance(2)
handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 1, dmg_health = 100, weapon = "ssg08" }); draw()
check(contains(texts, "PEEK   0* 1/1   1 0/0   2 0/0   3 0/0   4 0/0   5 0/0") and contains(texts, "YERDE   0* 0/0   1 0/0   2 0/0   3 0/0   4 0/0   5 0/0")
      and contains(texts, "HAREKET   0* 0/0   1 0/0   2 0/0   3 0/0   4 0/0   5 0/0"),
      "a headshot is counted in the group you were in when the bullet came (peek: its own group), not after stopping")
forget(); draw()
M("switch", "Stats panel"):set(false)
B("Standing", "combo", "Body yaw"):set("Jitter")
world.enemies = { enemy }
handlers.level_init(); forget()
reset_world()

-- Head unless body kills (snipers) -----------------------------------------------------------------
-- Target-independent: Min. Damage 101 (Neverlose: above 100 = HP + extra, so HP + 1) and Body Aim
-- Prefer. Whichever enemy the aimbot picks, only a killing shot (full HP: head; low HP: body).
reset_world()
world.threat = enemy; enemy.m_iHealth, enemy.m_ArmorValue = 100, 100; world.trace = function() return 30 end
lp.weapon_class = "CWeaponSSG08"; advance(3); draw()
check(ov("min_damage") == 101 and ov("body_aim") == "Prefer" and contains(texts, "HEAD") and not contains(texts, "BAIM"),
      "scout: minimum damage HP+1 and body preferred (only killing shots); full HP threat: HEAD")
enemy.m_iHealth = 70; tick(0); draw()
check(ov("min_damage") == 101 and ov("body_aim") == "Prefer" and contains(texts, "BAIM") and not contains(texts, "HEAD"),
      "the threat's chest kills: same settings (they do not depend on the target), indicator BAIM")
enemy.m_iHealth = nil; tick(0)
check(ov("min_damage") == 101 and ov("body_aim") == "Prefer", "unknown health: same (no guess about the target needed)")
world.threat = nil; tick(0)
check(ov("min_damage") == 101, "no threat at all: still only killing shots")
world.threat = enemy; enemy.m_iHealth = 100
advance(30); tick(0)
check(ov("body_aim") == "Prefer", "never forced: a forced body would block the head of another enemy")
-- V1.0 log: a chest hit (100 -> 27), then on Prefer the scout went for the head and missed; the enemy
-- killed us during the bolt. The enemy the aimbot just shot at: body forced when its chest kills.
enemy.m_iHealth = 27
handlers.aim_fire({ id = 640, target = 5 }); tick(0); draw()
check(ov("body_aim") == "Force" and ov("min_damage") == 101 and contains(texts, "BAIM"),
      "scout, the enemy you just shot at, its chest kills (27 HP): body forced")
advance(100)
check(ov("body_aim") == "Prefer", "1.5 s later (not engaged any more): prefer again")
enemy.m_iHealth = 100; handlers.aim_fire({ id = 641, target = 5 }); tick(0)
check(ov("body_aim") == "Prefer", "engaged but the chest does not kill a full HP enemy: prefer")
advance(100)
-- V1.0: the target's record is fake (defensive): snipers take the body instead of the head, but only when
-- the body kills. Logs: head-aimed shots at fake records hit the chest / stomach and the enemy lived; with
-- a full HP enemy the body list blocked every shot ("he crouches in front of me, it does not shoot").
do
    enemy.m_iHealth = 100; world.trace = function() return 30 end
    enemy.m_flSimulationTime = 70; tick(0); enemy.m_flSimulationTime = 70 + 1 / 64; tick(0)
    check(ov("hitboxes") == nil, "a real record: hitboxes untouched")
    enemy.m_flSimulationTime = 69.9; tick(0); draw()
    check(ov("hitboxes") == nil and not contains(texts, "DEF BODY"),
          "a fake record but the body cannot kill (100 HP): no body rule, the head is shot (it used to block every shot)")
    enemy.m_flSimulationTime = 70.1; tick(0)
    enemy.m_iHealth = 60
    local lines_fake = #printed
    enemy.m_flSimulationTime = 69.9; tick(0); draw()
    local hb, logged = ov("hitboxes"), false
    for i = lines_fake + 1, #printed do
        if printed[i] == "[Nykle.win] resolver: enemy5 sahte kayitta (defensive): sniper oldurecek govdeye, kafa gercek kayda" then logged = true end
    end
    check(type(hb) == "table" and #hb == 2 and hb[1] == "Chest" and hb[2] == "Stomach" and contains(texts, "DEF BODY") and logged,
          "scout, the target's record is fake and the body kills (60 HP): chest and stomach (the head waits for a real record), logged")
    enemy.m_flSimulationTime = 70.2; tick(0)
    check(ov("hitboxes") == nil, "a real record again: hitboxes back")
    enemy.m_flSimulationTime = 70.0
    local held = 0
    for _ = 1, 12 do tick(0); if type(ov("hitboxes")) == "table" then held = held + 1 end end
    check(held == 12, "waits up to 12 ticks")
    tick(0)
    check(ov("hitboxes") == nil, "then free (an enemy always in defensive still gets head shots)")
    advance(25)
    check(ov("hitboxes") == nil, "for half a second")
    advance(10)
    check(type(ov("hitboxes")) == "table", "then the body rule again while the record is still fake")
    M("switch", "Snipers: lethal body on fake records"):set(false); tick(0)
    check(ov("hitboxes") == nil, "can be turned off")
    M("switch", "Snipers: lethal body on fake records"):set(true); tick(0)
    lp.weapon_class = "CAK47"; tick(0)
    check(ov("hitboxes") == nil, "rifles are left alone")
    lp.weapon_class = "CWeaponSSG08"; world.trace = NO_TRACE; advance(3)
    check(ov("hitboxes") == nil, "nobody sees you (no lethal-only rule): left alone")
    world.trace = function() return 30 end; enemy.m_flSimulationTime = nil; enemy.m_iHealth = 100; tick(0)
end
lp.weapon_class = "CAK47"; tick(0)
check(ov("min_damage") == nil, "rifles are left alone")
lp.weapon_class = "CWeaponSCAR20"; tick(0)
check(ov("min_damage") == nil, "autos keep body shots (two of them kill with DT)")
refs[SHORT.min_damage].spec.value = 110; tick(0); lp.weapon_class = "CWeaponSSG08"; tick(0)
check(ov("min_damage") == nil and ov("body_aim") == "Prefer", "your own higher minimum damage is never lowered")
refs[SHORT.min_damage].spec.value = 30; lp.weapon_class = "CAK47"; tick(0); lp.weapon_class = "CWeaponAWP"; tick(0)
check(ov("min_damage") == 101 and ov("body_aim") == "Prefer", "AWP: the same")
lp.weapon_class, lp.weapon_index = "CDEagle", 64; tick(0)
check(ov("min_damage") == 101, "R8: the same")
lp.weapon_class, lp.weapon_index = "CWeaponSSG08", 40
refs[SHORT.body_aim].spec.bind = "Force"; tick(0)
check(ov("body_aim") == nil, "your baim key (Force) pressed while body aim is overridden: noticed, left to you")
refs[SHORT.body_aim].spec.bind = nil; tick(0); tick(0)
check(ov("body_aim") == "Prefer", "key released: back to Prefer")
refs[SHORT.safe].spec.bind = "Force"
local ba_kept = true
for _ = 1, 4 do tick(0); if ov("body_aim") ~= "Prefer" then ba_kept = false end end
check(ba_kept, "a key on another setting (safe points Force) is not taken for your body aim")
refs[SHORT.safe].spec.bind = nil
handlers.aim_fire({ id = 610, target = 5, hitgroup = 1, damage = 300 })
world.trace = NO_TRACE; advance(3)
handlers.aim_ack({ id = 610, target = 5, hitgroup = 1, damage = 300 })
check(ov("min_damage") == nil and printed[#printed]:find("| MD 101 |", 1, true) ~= nil,
      "the shot log keeps the minimum damage of the moment it fired")
world.trace = function() return 30 end; advance(3)
world.trace = NO_TRACE; advance(3); draw()
check(ov("min_damage") == nil and not contains(texts, "HEAD"),
      "nobody can hit your head: no lethal-only rule (a body shot through a thin gap far away is free damage)")
world.trace = function() return 30 end; advance(3)
check(ov("min_damage") == 101, "seen again: lethal only")
M("switch", "Smart body aim"):set(false); tick(0)
check(ov("body_aim") == nil and ov("min_damage") == 101, "smart body aim off: only the minimum damage")
M("switch", "Smart body aim"):set(true)
M("switch", "Head unless body kills (snipers)"):set(false); tick(0); draw()
check(ov("min_damage") == nil and not contains(texts, "HEAD"), "can be turned off")
M("switch", "Head unless body kills (snipers)"):set(true); tick(0)
handlers.aim_fire({ id = 600, target = 5, hitgroup = 1, damage = 300 }); handlers.aim_ack({ id = 600, target = 5, hitgroup = 1, damage = 300 })
check(printed[#printed]:find("| MD 101 |", 1, true) ~= nil, "the shot log shows the minimum damage in use")
enemy.m_iHealth, enemy.m_ArmorValue = nil, nil
handlers.level_init(); forget()
reset_world()

-- Sniper exploit learning ------------------------------------------------------------------------
reset_world(); forget()
check(M("combo", "Snipers (SSG08/AWP/R8)"):get() == "Auto (learn)", "snipers: learn hide shots vs double tap by default")
M("combo", "Snipers (SSG08/AWP/R8)"):set("Auto (learn)")
world.threat = enemy; lp.weapon_class = "CWeaponSSG08"; tick(0)
M("switch", "Stats panel"):set(true); draw()
check(ov("hs") == true and contains(texts, "SNIPER   HS* 0/0   DT 0/0"), "auto: scouts start with hide shots")
local lines_sn = #printed
local function sniper_hit() handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 1, dmg_health = 300, weapon = "ssg08" }); tick(0) end
local function near_misses(n)
    for _ = 1, n do advance(12); handlers.bullet_impact({ userid = 5, x = -500, y = 6, z = 64 }); advance(12) end
end
near_misses(2); sniper_hit(); draw()
check(ov("hs") == true and contains(texts, "SNIPER   HS* 1/3   DT 0/0"), "one headshot does not switch")
sniper_hit(); sniper_hit(); draw()
check(ov("hs") == true and contains(texts, "SNIPER   HS* 3/5   DT 0/0"), "three of five: not clearly worse than an untried double tap (0.1 margin)")
local switch_line
sniper_hit(); sniper_hit(); draw()
for i = lines_sn + 1, #printed do if printed[i]:find("sniper exploit:", 1, true) then switch_line = printed[i] end end
check(ov("dt") == true and ov("hs") == false and contains(texts, "SNIPER   HS 5/7   DT* 0/0")
      and switch_line == "[Nykle.win] sniper exploit: Hide shots 5/7, Double tap 0/0 kafa isabeti -> Double tap",
      "five of seven with hide shots: double tap is tried")
near_misses(4); draw()
check(ov("dt") == true and contains(texts, "SNIPER   HS 5/7   DT* 0/4"), "near misses with double tap keep it")
lp.weapon_class = "CAK47"; tick(0); handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 1, dmg_health = 100, weapon = "ssg08" })
tick(0); draw()
check(contains(texts, "SNIPER   HS 5/7   DT* 0/4"), "hits while not holding a sniper are not counted")
lp.weapon_class = "CWeaponSSG08"
M("combo", "Snipers (SSG08/AWP/R8)"):set("Hide shots"); tick(0)
check(ov("hs") == true, "the hide shots setting forces it")
M("combo", "Snipers (SSG08/AWP/R8)"):set("Same as state"); tick(0)
check(ov("dt") == true, "same as state uses the state's double tap")
M("combo", "Snipers (SSG08/AWP/R8)"):set("Auto (learn)")
handlers.level_init()
check(db.ant_a_m_memory.sniper.hs.hits == 5 and db.ant_a_m_memory.sniper.dt.shots == 4, "sniper statistics are saved")
forget(); tick(0); draw()
check(ov("hs") == true and contains(texts, "SNIPER   HS* 0/0   DT 0/0"), "forget resets the sniper choice")
for _ = 1, 3 do sniper_hit() end
check(ov("hs") == true, "three headshots out of three: under four bullets the choice stays")
sniper_hit()
check(ov("dt") == true, "double tap tried again")
M("combo", "Snipers (SSG08/AWP/R8)"):set("Hide shots"); tick(0)
check(ov("hs") == true and ov("dt") == false, "the default hide shots ignores what the learning picked")
M("combo", "Snipers (SSG08/AWP/R8)"):set("Auto (learn)"); tick(0)
for _ = 1, 9 do sniper_hit() end
check(ov("dt") == true, "nine headshots with double tap: not yet clearly worse than 4/4 with hide shots")
sniper_hit()
check(ov("hs") == true, "double tap clearly worse: back to hide shots")
M("combo", "Snipers (SSG08/AWP/R8)"):set("Hide shots")
forget(); tick(0)
M("switch", "Stats panel"):set(false)
handlers.level_init(); forget()
reset_world()

-- Auto freestanding and shooter awareness -----------------------------------------------------------
reset_world()
M("switch", "Auto when standing still"):set(true); world.threat = enemy; tick(0); draw()
check(ov("fs") == true and contains(texts, "FREESTANDING"), "auto freestanding while standing still")
lp.m_flDuckAmount = 1; advance(2); draw()
check(ov("fs") == true and contains(texts, "FREESTANDING"), "and while crouching still")
lp.m_flDuckAmount = 0; lp.m_vecVelocity = vector(250, 0, 0); advance(2); draw()
check(ov("fs") == false and not contains(texts, "FREESTANDING"), "not while moving")
lp.m_vecVelocity = vector(0, 0, 0); world.trace = function() return 30 end; advance(2); draw()
check(not contains(texts, "FREESTANDING"), "head still visible: back to the normal AA")
world.trace = NO_TRACE
M("switch", "Auto when standing still"):set(false); advance(2); draw()
check(ov("fs") == false, "auto freestanding can be turned off")
reset_world()
world.enemies = { enemy, enemy2 }; enemy2.origin = vector(0, 500, 0); world.threat = enemy2
lp.m_vecVelocity = vector(250, 0, 0); advance(4)
check(last_cmd.force_defensive == nil, "nobody seen: no forced defensive")
handlers.bullet_impact({ userid = 5, x = -500, y = 6, z = 64 }); tick(0, { view_angles = vector(0, 90, 0) })
check(ov("base") == "Local View" and last_cmd.force_defensive == true,
      "an unseen enemy that shot at your head counts as seeing you and the AA turns to it")
handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 2, dmg_health = 20, weapon = "ssg08" })
check(printed[#printed]:find("enemy5 (Moving, AA hedefi, ", 1, true) ~= nil or printed[#printed]:find("(Standing, AA hedefi, ", 1, true) ~= nil,
      "the log shows the AA faced the shooter")
advance(40)
check(last_cmd.force_defensive == nil, "after half a second the shot no longer counts as a sighting")
enemy.dormant = true; tick(0, { view_angles = vector(0, 90, 0) })
check(ov("base") == "At Target", "a dormant shooter's old position is not faced")
enemy.dormant = nil
advance(30); tick(0, { view_angles = vector(0, 90, 0) })
check(ov("base") == "At Target", "after a second the AA goes back to the threat")
handlers.bullet_impact({ userid = 5, x = -500, y = 6, z = 64 }); handlers.round_start({}); tick(0, { view_angles = vector(0, 90, 0) })
check(ov("base") == "At Target", "a new round forgets the shot")
advance(70); handlers.bullet_impact({ userid = 5, x = -500, y = 6, z = 64 }); handlers.level_init(); tick(0, { view_angles = vector(0, 90, 0) })
check(ov("base") == "At Target", "a map change forgets the shot")
advance(70); world.trace = function() return 30 end; advance(4)
handlers.bullet_impact({ userid = 5, x = -500, y = 6, z = 64 }); tick(0, { view_angles = vector(0, 90, 0) })
check(ov("base") == "At Target", "the threat sees you: the AA keeps facing the threat, not the shooter")
world.trace = NO_TRACE; advance(70)
lp.m_vecVelocity = vector(0, 0, 0); B("Standing", "slider", "Delay randomize"):set(0)
handlers.round_start({}); M("switch", "Anti-bruteforce"):set(false)
enemy2.origin = vector(0, 300, 0); world.threat = nil; advance(4); tick(0, { view_angles = vector(0, 90, 0) })
check(ov("base") == "Local View" and ov("offset") == yaw_for(-23, 51), "no threat: the nearest enemy (enemy2 on +y)")
handlers.bullet_impact({ userid = 5, x = -500, y = 6, z = 64 }); tick(0, { view_angles = vector(0, 90, 0) })
check(ov("base") == "Local View" and ov("offset") == (yaw_for(-23, 51) - 90 + 180) % 360 - 180,
      "no threat: the enemy that just shot at your head (on +x) is faced, not the nearest")
B("Standing", "slider", "Delay randomize"):set(1); M("switch", "Anti-bruteforce"):set(true)
world.enemies = { enemy }; enemy2.origin = vector(500, 0, 0)
handlers.level_init(); forget()
reset_world()

-- Enemy peek prediction, defensive vs enemy peeks, air teleport -------------------------------------
reset_world()
check(M("switch", "Defensive vs enemy peeks"):get() == true and M("switch", "Teleport in air when seen"):get() == true,
      "defensive vs enemy peeks and air teleport on by default")
world.threat = enemy; world.enemies = { enemy }; lp.weapon_class = "CAK47"
-- The enemy (500 ahead) sees the head only from y >= 40.
local from_side = function(_, from, eye) if from == enemy and eye ~= nil and eye.y >= 40 then return 30 end return 0 end
world.trace = from_side; advance(4)
check(last_cmd.force_defensive == nil and ov("lag") == "On Peek", "standing, enemy still: nothing forced")
enemy.m_vecVelocity = vector(0, 250, 0); advance(2)
check(last_cmd.force_defensive == true and ov("lag") == "On Peek",
      "standing: the enemy is peeking toward you (0.2 s ahead it sees your head): defensive forced before it appears")
enemy.m_vecVelocity = vector(0, 0, 0); advance(12)
check(last_cmd.force_defensive == true, "held a little after the prediction ends (its first bullet)")
advance(8)
check(last_cmd.force_defensive == nil, "then released")
enemy.m_vecVelocity = vector(0, 250, 0); advance(2)
check(last_cmd.force_defensive == true, "re-armed on the next peek")
-- V1.0: once it sees you, the reaction goes on only while your gun cannot fire (bolt, reload): with
-- a gun ready the shot comes first ("hard to hit moving enemies coming at me" while it forced).
enemy.m_vecVelocity = vector(0, 0, 0); advance(40)
check(last_cmd.force_defensive == nil, "the prediction ended: released")
enemy.eye = vector(500, 50, 64); advance(2)
check(last_cmd.force_defensive == nil, "the enemy appears, your gun is ready: nothing forced, your shot comes first")
enemy.eye = vector(500, 0, 64); advance(40)
globals.curtime, lp.next_attack = 50, 51
enemy.eye = vector(500, 50, 64); advance(2); draw()
check(last_cmd.force_defensive == true and contains(texts, "ANTI-PEEK"),
      "the enemy appears (sees your head): defensive forced at once, ANTI-PEEK shown")
advance(26)
check(last_cmd.force_defensive == true, "held while it has just appeared")
advance(10)
check(last_cmd.force_defensive == nil, "the enemy in sight for a while, standing still: released")
enemy.m_vecVelocity = vector(0, 250, 0); advance(2)
check(last_cmd.force_defensive == true, "it sees you and moves fast (jiggle / wide peek): forced again")
advance(30)
check(last_cmd.force_defensive == true, "the whole time it keeps peeking")
enemy.m_vecVelocity = vector(0, 60, 0); advance(20)
check(last_cmd.force_defensive == nil, "slow walking in sight (holding the angle) is not a peek")
enemy.eye = vector(500, 0, 64); enemy.m_vecVelocity = vector(0, 250, 0); advance(40)
enemy.eye = vector(500, 50, 64); enemy.m_vecVelocity = vector(0, 0, 0); advance(40)
check(last_cmd.force_defensive == nil, "a predicted peek that ends in sight, then standing still: released (the prediction is cleared)")
globals.curtime, lp.next_attack = nil, nil
enemy.m_vecVelocity = vector(0, 250, 0)
enemy.eye = vector(500, 0, 64); advance(20)
M("switch", "Defensive vs enemy peeks"):set(false); advance(2)
check(last_cmd.force_defensive == nil, "can be turned off")
M("switch", "Defensive vs enemy peeks"):set(true); aa.charge = 0.5; advance(2)
check(last_cmd.force_defensive == nil, "not without DT charge")
aa.charge = 1; lp.weapon_class = "CWeaponSSG08"; advance(2)
check(ov("hs") == true and ov("hs_opt") == "Break LC", "hide shots: a peeking enemy turns Break LC on while standing")
lp.weapon_class = "CAK47"; enemy.m_vecVelocity = vector(0, 0, 0); advance(40)
-- Another enemy (not the threat) peeking: counts as about to see you, but not as a sighting in the hit log.
world.enemies = { enemy, enemy2 }; enemy2.eye = vector(0, 500, 64)
world.trace = function(_, from, eye) if from == enemy2 and eye ~= nil and eye.x >= 40 then return 30 end return 0 end
advance(4)
check(last_cmd.force_defensive == nil, "the other enemy still: nothing")
enemy2.m_vecVelocity = vector(250, 0, 0); advance(4)
check(last_cmd.force_defensive == true, "another enemy peeking toward you: defensive forced")
handlers.player_hurt({ userid = 1, attacker = 7, hitgroup = 2, dmg_health = 20, weapon = "ssg08" })
check(printed[#printed]:find("gormedi)", 1, true) ~= nil, "a predicted peek is not logged as a sighting")
enemy2.m_vecVelocity = vector(0, 0, 0); advance(40)
-- V1.0: another enemy that already sees your head and moves fast (peeking you): forced too.
world.trace = function(_, from) if from == enemy2 then return 30 end return 0 end
globals.curtime, lp.next_attack = 50, 51
advance(40)
check(last_cmd.force_defensive == nil, "another enemy in sight for a while, standing still: nothing forced")
enemy2.m_vecVelocity = vector(250, 0, 0); advance(8)
check(last_cmd.force_defensive == true, "another enemy in sight moving fast (peeking you), gun not ready: defensive forced")
globals.curtime, lp.next_attack = nil, nil
enemy2.m_vecVelocity, enemy.m_vecVelocity = nil, nil; world.enemies = { enemy }; enemy2.eye = vector(0, 500, 64)
reset_world()
-- Air teleport: once per jump (V1.0: each teleport spends the charge and leaves the air without
-- defensive until it is back; v5.4-v5.6 did up to five).
world.threat = enemy; lp.weapon_class = "CAK47"; aa.charge = 1; world.trace = function() return 30 end
local tp0 = aa.teleports
advance(4)
check(aa.teleports == tp0, "no teleport on the ground")
lp.m_fFlags = 0; lp.m_vecVelocity = vector(250, 0, 0); advance(3)
check(aa.teleports == tp0 + 1 and printed[#printed] == "[Nykle.win] teleport: havada goruldun, DT ile isinlanildi (1. kez)",
      "in the air and seen with DT charged: teleport (logged)")
aa.charge = 0; advance(20)
check(aa.teleports == tp0 + 1, "DT spent: waits for the charge")
handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 2, dmg_health = 20, weapon = "ssg08" })
check(printed[#printed]:find(", tp 0%.%d%ds") ~= nil, "the hit log shows the time since the teleport")
aa.charge = 1; advance(60)
check(aa.teleports == tp0 + 1, "charged again in the same jump: no second teleport (the air lag goes on instead)")
local lines_land = #printed
lp.m_fFlags = 1; advance(4)
local function printed_from(n, text)
    for i = n + 1, #printed do if printed[i] == text then return true end end
    return false
end
check(printed_from(lines_land, "[Nykle.win] teleport: bu ziplamada 1 kez"), "landing: summary of the jump's teleports")
-- About to land (falling from 40 units, 0.32 s): no teleport, the charge (~0.26 s) is back before the landing.
world.line = function(from, to) if to.z < from.z then return 0.1 end return 1 end
lp.m_fFlags = 0; advance(3)
check(aa.teleports == tp0 + 1, "less than 0.35 s before landing: no teleport (DT stays charged for the landing)")
lp.m_vecVelocity = vector(250, 0, 200); advance(2)
check(aa.teleports == tp0 + 2, "rising (just jumped) near the ground: teleports")
lp.m_fFlags = 1; advance(8)
world.line = function() return 1 end; lp.m_fFlags = 0; lp.m_vecVelocity = vector(250, 0, -300); advance(12)
check(aa.teleports == tp0 + 3, "nothing below within 400 units (a long drop): teleports")
lp.m_vecVelocity = vector(250, 0, 0); world.line = GROUND
lp.m_fFlags = 1; advance(8)
aa.consume = true; lp.m_fFlags = 0; advance(3)
check(aa.teleports == tp0 + 4, "the next jump can teleport again")
advance(5); lines_land = #printed; lp.m_fFlags = 1; advance(4); aa.consume = false
check(printed_from(lines_land, "[Nykle.win] teleport: bu ziplamada 1 kez (sarj havada tekrar dolmadi)"),
      "one teleport and the charge never came back in the air: the summary says so")
aa.charge = 1; lp.m_fFlags = 0; advance(3)
local function jump(setup)
    lp.m_fFlags = 1; world.trace = function() return 30 end; lp.m_vecVelocity = vector(250, 0, 0); aa.charge = 1
    lp.weapon_class = "CAK47"; setup(); advance(20); lp.m_fFlags = 0; advance(5)
    return aa.teleports
end
local tp1 = aa.teleports
check(jump(function() world.trace = NO_TRACE end) == tp1, "not seen: no teleport")
check(jump(function() lp.m_vecVelocity = vector(100, 0, 0) end) == tp1, "too slow (a teleport would not move you): no teleport")
check(jump(function() aa.charge = 0.5 end) == tp1, "not charged: no teleport")
M("switch", "Fake duck only when standing still"):set(false)
check(jump(function() refs[SHORT.fakeduck].spec.value = true; refs[SHORT.dt].spec.value = true end) == tp1,
      "fake duck (DT does not work there, even with your DT bind on): no teleport")
refs[SHORT.fakeduck].spec.value = false; refs[SHORT.dt].spec.value = false
check(jump(function() M("switch", "Teleport in air when seen"):set(false) end) == tp1, "can be turned off")
lp.m_fFlags = 1; advance(8); M("switch", "Teleport in air when seen"):set(true)
check(jump(function() end) == tp1 + 1, "back on: teleports again")
-- Shots right after a teleport (V1.0 log: an unregistered scout shot after three teleports): marked TP;
-- two of them thrown away within 10 s pause the teleport for 10 s.
do
    handlers.aim_fire({ id = 690, target = 5 }); handlers.aim_ack({ id = 690, target = 5, state = "unregistered shot" })
    check(printed[#printed]:find("| sen ak47 TP |", 1, true) ~= nil, "a shot right after a teleport is marked TP")
    local lines_tp = #printed
    handlers.aim_fire({ id = 691, target = 5 }); handlers.aim_ack({ id = 691, target = 5, state = "unregistered shot" })
    check(printed[lines_tp + 2] == "[Nykle.win] teleport 10 sn durduruldu: teleport sonrasi sirasinda 2 atis bozuk gitti (son: unregistered shot)",
          "two unregistered shots after teleports: teleport paused (logged)")
    advance(20)
    handlers.aim_fire({ id = 692, target = 5 }); handlers.aim_ack({ id = 692, target = 5, state = "spread" })
    check(printed[#printed]:find(" TP |", 1, true) == nil, "0.3 s after the teleport: no longer marked TP")
    check(jump(function() end) == tp1 + 1, "paused: no teleport in the next jump")
    lp.m_fFlags = 1; advance(640)
    check(jump(function() end) == tp1 + 2, "teleports again after 10 s")
    tp1 = aa.teleports - 1
end
-- Hide shots (scout): tried once; the charge was not spent, so Neverlose does not teleport with HS.
lp.m_fFlags = 1; advance(8); handlers.level_init()
local hs_lines = #printed
check(jump(function() lp.weapon_class = "CWeaponSSG08" end) == tp1 + 2
      and printed[hs_lines + 1] == "[Nykle.win] teleport: havada goruldun, HS ile isinlanildi (1. kez)"
      and printed[hs_lines + 2] == "[Nykle.win] teleport: Hide shots ile calismiyor (sarj harcanmadi); sadece DT'li silahlarda",
      "hide shots: tried once, the unspent charge shows it does not work (logged)")
lp.m_fFlags = 1; advance(8)
check(jump(function() lp.weapon_class = "CWeaponSSG08" end) == tp1 + 2, "hide shots: not tried again")
M("switch", "Teleport in air when seen"):set(true)
lp.m_fFlags = 1; lp.m_vecVelocity = vector(0, 0, 0)
reset_world()

-- Air lag and sniper DT in the air ------------------------------------------------------------------
reset_world()
M("switch", "Air lag (defensive every tick)"):set(true); M("switch", "Snipers use DT in the air"):set(true)
world.threat = enemy; world.trace = NO_TRACE; lp.weapon_class = "CAK47"; aa.charge = 1; advance(4)
check(last_cmd.force_defensive == nil, "on the ground and unseen: nothing forced")
M("switch", "Auto peek"):set(false); lp.m_vecVelocity = vector(250, 0, 0); advance(3)
check(last_cmd.force_defensive == nil, "moving on the ground (Smart) and unseen: nothing forced; the lag is for the air")
M("switch", "Auto peek"):set(true)
lp.m_fFlags = 0; lp.m_vecVelocity = vector(250, 0, 0); advance(3)
check(last_cmd.force_defensive == true and ov("lag") == "On Peek" and ov("hidden") == true,
      "in the air: defensive forced every tick even unseen (air lag with hidden angles), NL's mode untouched")
advance(20)
check(last_cmd.force_defensive == true, "the whole time in the air")
aa.charge = 0.5; tick(0)
check(last_cmd.force_defensive == nil, "not without DT charge")
aa.charge = 1; lp.m_flDuckAmount = 1; advance(2)
check(last_cmd.force_defensive == true, "air crouch too")
lp.m_flDuckAmount = 0
M("switch", "Air lag (defensive every tick)"):set(false); advance(2)
check(last_cmd.force_defensive == nil, "air lag can be turned off (Smart: only when seen)")
M("switch", "Air lag (defensive every tick)"):set(true)
-- Shots fired during our forced defensive that the server did not register: pause the forcing.
tick(0)
handlers.aim_fire({ id = 720, target = 5 }); handlers.aim_ack({ id = 720, target = 5, state = "unregistered shot" }); tick(0)
check(last_cmd.force_defensive == true and printed[#printed]:find("| sen ak47 DEF |", 1, true) ~= nil,
      "one unregistered shot: still forced; the shot log marks shots fired during our forced defensive")
local lines_unreg = #printed
handlers.aim_fire({ id = 721, target = 5 }); handlers.aim_ack({ id = 721, target = 5, state = "damage rejection" }); tick(0)
check(last_cmd.force_defensive == nil
      and printed[lines_unreg + 2] == "[Nykle.win] defensive 10 sn durduruldu: zorlanan defensive sirasinda 2 atis bozuk gitti (son: damage rejection)",
      "two within 10 s: forced defensive paused (logged)")
advance(600)
check(last_cmd.force_defensive == nil, "still paused after 9 s")
advance(50)
check(last_cmd.force_defensive == true, "forcing again after 10 s")
M("switch", "Air lag (defensive every tick)"):set(false); advance(2)
handlers.aim_fire({ id = 722, target = 5 }); handlers.aim_ack({ id = 722, target = 5, state = "unregistered shot" })
handlers.aim_fire({ id = 723, target = 5 }); handlers.aim_ack({ id = 723, target = 5, state = "unregistered shot" })
M("switch", "Air lag (defensive every tick)"):set(true); tick(0)
check(last_cmd.force_defensive == true, "unregistered shots while nothing was forced do not pause it")
handlers.aim_fire({ id = 724, target = 5 }); handlers.aim_ack({ id = 724, target = 5, state = "unregistered shot" })
advance(700)
handlers.aim_fire({ id = 725, target = 5 }); handlers.aim_ack({ id = 725, target = 5, state = "unregistered shot" }); tick(0)
check(last_cmd.force_defensive == true, "two more than 10 s apart: no pause")
lp.m_fFlags = 1; lp.m_vecVelocity = vector(0, 0, 0); advance(8)
lp.weapon_class = "CWeaponSSG08"; advance(2)
check(ov("hs") == true and ov("dt") == false, "scout on the ground: hide shots")
lp.m_fFlags = 0; lp.m_vecVelocity = vector(250, 0, 0); advance(3)
check(ov("dt") == true and ov("hs") == false and last_cmd.force_defensive == true,
      "scout in the air: double tap, so the air lag (and teleport) works")
lp.m_flDuckAmount = 1; advance(2)
check(ov("dt") == true and ov("hs") == false, "scout in air crouch: double tap too")
lp.m_flDuckAmount = 0
lp.m_fFlags = 1; lp.m_vecVelocity = vector(0, 0, 0); advance(8)
check(ov("hs") == true and ov("dt") == false, "landed: hide shots again")
-- Hide shots Break LC: shots the server throws away during it pause it too.
lp.m_vecVelocity = vector(100, 0, 0); advance(3)
check(ov("hs_opt") == "Break LC", "scout moving: Break LC")
handlers.aim_fire({ id = 726, target = 5 }); handlers.aim_ack({ id = 726, target = 5, state = "damage rejection" })
check(printed[#printed]:find("| sen ssg08 LC |", 1, true) ~= nil, "the shot log marks shots fired during Break LC")
local lines_lc = #printed
handlers.aim_fire({ id = 727, target = 5 }); handlers.aim_ack({ id = 727, target = 5, state = "unregistered shot" }); tick(0)
check(ov("hs_opt") == "Favor Fire Rate"
      and printed[lines_lc + 2] == "[Nykle.win] Break LC 10 sn durduruldu: Hide shots Break LC sirasinda 2 atis bozuk gitti (son: unregistered shot)",
      "two thrown-away shots during Break LC: Break LC paused for 10 s (logged)")
handlers.aim_fire({ id = 728, target = 5 }); handlers.aim_ack({ id = 728, target = 5, state = "spread" })
check(printed[#printed]:find("| sen ssg08 |", 1, true) ~= nil, "while paused the shot is not marked LC")
advance(600)
check(ov("hs_opt") == "Favor Fire Rate", "still paused after 9 s")
advance(60)
check(ov("hs_opt") == "Break LC", "Break LC back after 10 s")
M("switch", "Defensive vs enemy peeks"):set(true)
lp.m_vecVelocity = vector(0, 0, 0); advance(4)
M("switch", "Snipers use DT in the air"):set(false); lp.m_fFlags = 0; lp.m_vecVelocity = vector(250, 0, 0); advance(3)
check(ov("hs") == true and ov("dt") == false, "can be turned off: hide shots in the air too")
M("switch", "Snipers use DT in the air"):set(true); advance(2)
check(ov("dt") == true, "back on")
M("switch", "Air lag (defensive every tick)"):set(false); M("switch", "Snipers use DT in the air"):set(false)
lp.m_fFlags = 1; lp.m_vecVelocity = vector(0, 0, 0)
reset_world()

-- Learned phase = the phase the AA really showed (V1.0) ---------------------------------------------
-- The AA faces enemy5 (the threat, learned phase 2) when enemy7 shoots: enemy7 resolved phase 2, so it
-- learns 3 (it used to learn its own stage + 1 = 1). The round summary lists the phases the AA showed.
do
    reset_world(); handlers.level_init(); forget(); handlers.round_start({})
    B("Standing", "combo", "Body yaw"):set("Static")
    world.threat = enemy; world.enemies = { enemy, enemy2 }; enemy2.eye = vector(0, 500, 64); tick(0)
    handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 1, dmg_health = 1, weapon = "ssg08" }); tick(0)
    handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 1, dmg_health = 1, weapon = "ssg08" }); tick(0)
    check(ov("offset") == -23 + 15, "enemy5 hit you at phases 0 and 1: its phase is 2")
    handlers.bullet_impact({ userid = 7, x = 0, y = -500, z = 64 })
    handlers.player_hurt({ userid = 1, attacker = 7, hitgroup = 1, dmg_health = 1, weapon = "ssg08" })
    check(printed[#printed]:find("| faz 2 |", 1, true) ~= nil, "the hit log shows the phase the AA showed (enemy5's 2)")
    handlers.round_start({})
    check(printed[#printed]:find("kafa fazlari 0:1 1:1 2:1", 1, true) ~= nil, "the round summary lists the phases the AA showed")
    globals.realtime = globals.realtime + 7; world.threat = enemy2; advance(4)
    check(ov("left") == 51 and ov("offset") == 51 - 15,
          "enemy7 hit you while the AA showed phase 2: it learns phase 3 (not its own stage + 1)")
    B("Standing", "combo", "Body yaw"):set("Jitter")
    world.threat = nil; world.enemies = { enemy }
    handlers.level_init(); forget()
    reset_world()
end

-- Kills / deaths per state and the round shot summary (V1.0) ----------------------------------------
do
    reset_world(); handlers.level_init(); forget(); E("button", "Reset stats"):click(); handlers.round_start({})
    world.threat = enemy; tick(0)
    handlers.player_death({ userid = 5, attacker = 1 })
    refs[SHORT.fakeduck].spec.value = true; advance(2)
    handlers.player_death({ userid = 7, attacker = 1 })
    handlers.player_death({ userid = 1, attacker = 5 })
    refs[SHORT.fakeduck].spec.value = false; advance(2)
    handlers.player_death({ userid = 6, attacker = 1 })
    handlers.player_death({ userid = 1, attacker = 1 })
    handlers.player_death({ userid = 1, attacker = 6 })
    M("switch", "Stats panel"):set(true); draw()
    check(contains(texts, "KD   OLDURDUN / OLDUN") and contains(texts, "STANDING   1 / 0") and contains(texts, "FAKE DUCK   1 / 1"),
          "stats panel: kills / deaths per state (a teammate kill, a suicide and a teammate's kill are not counted)")
    E("button", "Reset stats"):click(); draw()
    check(not contains(texts, "KD   OLDURDUN / OLDUN"), "reset stats clears the kill / death rows")
    M("switch", "Stats panel"):set(false)
    handlers.aim_fire({ id = 1400, target = 5 }); handlers.aim_ack({ id = 1400, target = 5, hitgroup = 1, damage = 100 })
    handlers.aim_fire({ id = 1401, target = 5 }); handlers.aim_ack({ id = 1401, target = 5, state = "correction" })
    handlers.aim_fire({ id = 1402, target = 5 }); handlers.aim_ack({ id = 1402, target = 5, state = "spread" })
    handlers.aim_fire({ id = 1403, target = 5 }); handlers.aim_ack({ id = 1403, target = 5, state = "correction" })
    handlers.aim_fire({ id = 1404, target = 5 }); handlers.aim_ack({ id = 1404, target = 5, state = "death" })
    handlers.round_start({})
    check(printed[#printed] == "[Nykle.win] atis ozeti: 4 mermi, 1 isabet | temiz 1/4, lag 0/0 | iska: correction 2, spread 1",
          "round shot summary: bullets, hits, clean / lag hits and miss reasons (most first; deaths not counted)")
    local lines_round = #printed
    handlers.round_start({})
    check(#printed == lines_round, "no shots this round: no summary")
    M("switch", "Shot log"):set(false)
    handlers.aim_fire({ id = 1405, target = 5 }); handlers.aim_ack({ id = 1405, target = 5, state = "spread" })
    handlers.round_start({})
    check(#printed == lines_round, "shot log off: no summary")
    M("switch", "Shot log"):set(true)
    reset_world()
end

-- Clean shot (V1.0): gun ready and the target shootable -> no own lag -------------------------------
do
    reset_world()
    handlers.level_init(); forget(); E("button", "Reset stats"):click()
    check(M("switch", "Clean shot (no lag while shooting)"):get() == true, "clean shot on by default")
    world.threat = enemy; world.enemies = { enemy }; enemy.m_iHealth = 100
    lp.get_eye_position = function() return vector(0, 0, 64) end
    enemy.get_hitbox_position = function(_, n) return vector(500, 0, n == 0 and 64 or (n == 5 and 50 or 40)) end
    -- Our bullet: head 290, chest 90, stomach 110 when open; the enemy sees our head (30) the whole time.
    local open = true
    local function bullets(head, chest, stomach)
        return function(to, from)
            if from == enemy then return 30 end
            if from ~= lp or not open then return 0 end
            if to.z == 64 then return head end
            if to.z == 50 then return chest end
            return stomach
        end
    end
    world.trace = bullets(290, 90, 110)
    lp.weapon_class = "CWeaponSSG08"; lp.m_vecVelocity = vector(100, 0, 0); advance(4); draw()
    check(ov("hs") == true and ov("hs_opt") == "Favor Fire Rate" and contains(texts, "CLEAN SHOT"),
          "scout moving, ready, the target shootable: no Break LC (clean shot), CLEAN SHOT shown")
    handlers.aim_fire({ id = 1300, target = 5 }); handlers.aim_ack({ id = 1300, target = 5, hitgroup = 1, damage = 290 })
    check(printed[#printed]:find("| sen ssg08 temiz |", 1, true) ~= nil, "the shot log marks a clean shot")
    -- The bolt (gun not ready): the lag is back at once.
    globals.curtime, lp.next_attack = 50, 51; advance(1); draw()
    check(ov("hs_opt") == "Break LC" and not contains(texts, "CLEAN SHOT"), "after the shot (bolt): Break LC back at once")
    handlers.aim_fire({ id = 1301, target = 5 }); handlers.aim_ack({ id = 1301, target = 5, state = "spread" })
    globals.curtime, lp.next_attack = nil, nil; advance(2)
    check(ov("hs_opt") == "Favor Fire Rate", "ready again: clean again")
    -- Hold: once open it stays clean a few ticks (the trace changes every 2 ticks; no flicker).
    open = false; advance(4)
    check(ov("hs_opt") == "Favor Fire Rate", "the target goes behind cover: still clean for a few ticks")
    advance(4)
    check(ov("hs_opt") == "Break LC", "then Break LC back")
    -- Min. Damage: only the body open and it cannot kill (sniper rule HP + 1): the aimbot will not fire, lag stays.
    open = true; world.trace = bullets(0, 90, 95); advance(10)
    check(ov("min_damage") == 101 and ov("hs_opt") == "Break LC", "only a non-lethal body open (MD = HP + 1): no clean shot, Break LC stays")
    enemy.m_iHealth = 60; advance(4)
    check(ov("hs_opt") == "Favor Fire Rate", "the body kills now (60 HP): clean shot")
    enemy.m_iHealth = 100; world.trace = bullets(290, 90, 110)
    -- A fake record and the body cannot kill: no body rule (V1.0), the head is shot, the shot is clean.
    world.trace = bullets(290, 90, 95)
    enemy.m_flSimulationTime = 70; tick(0); enemy.m_flSimulationTime = 70 + 1 / 64; tick(0)
    enemy.m_flSimulationTime = 69.9; advance(10); draw()
    check(not contains(texts, "DEF BODY") and ov("hs_opt") == "Favor Fire Rate",
          "a fake record and the body cannot kill: no body rule, the head counts, clean shot")
    -- Only the edge of the head is open (its center behind cover): clean too (V1.0).
    enemy.m_flSimulationTime = nil
    world.trace = function(to, from)
        if from == enemy then return 30 end
        if from == lp and to.z == 64 and math.abs(to.y) > 1 then return 290 end
        return 0
    end
    advance(10)
    check(ov("hs_opt") == "Favor Fire Rate", "only the edge of the head is open: clean shot (the edges are traced too)")
    world.trace = bullets(290, 90, 110)
    -- A dormant target: its hitboxes are old, nothing is cleaned.
    enemy.dormant = true; advance(10)
    check(ov("hs_opt") == "Break LC", "a dormant target: no clean shot")
    enemy.dormant = nil
    -- Knife: no shot to clean (hide shots stays from the scout).
    lp.weapon_class = "CKnife"; advance(10)
    check(ov("hs") == true and ov("hs_opt") == "Break LC", "knife: nothing to shoot, Break LC stays")
    lp.weapon_class = "CWeaponSSG08"; advance(4)
    M("switch", "Clean shot (no lag while shooting)"):set(false); advance(2)
    check(ov("hs_opt") == "Break LC", "can be turned off")
    M("switch", "Clean shot (no lag while shooting)"):set(true); advance(2)
    check(ov("hs_opt") == "Favor Fire Rate", "back on: clean")
    -- The aimbot switches to another target (its hitboxes unreadable): the old target's hold does not carry over.
    handlers.aim_fire({ id = 1310, target = 7 }); tick(0)
    check(ov("hs_opt") == "Break LC", "another target that is not shootable: Break LC at once")
    advance(100)
    check(ov("hs_opt") == "Favor Fire Rate", "back on the first target: clean")
    -- On a ladder nothing is clean (no shot there): the indicator goes away.
    lp.m_MoveType = 9; advance(1); draw()
    check(not contains(texts, "CLEAN SHOT"), "on a ladder: no CLEAN SHOT")
    lp.m_MoveType = 2; advance(2)
    -- Fake duck is your key and lag itself: no clean shot then (the shot is marked FD).
    draw(); check(contains(texts, "CLEAN SHOT"), "clean again before fake duck")
    refs[SHORT.fakeduck].spec.value = true; advance(1); draw()
    check(not contains(texts, "CLEAN SHOT"), "fake duck held: no CLEAN SHOT")
    handlers.aim_fire({ id = 1311, target = 5 }); handlers.aim_ack({ id = 1311, target = 5, hitgroup = 1, damage = 290 })
    check(printed[#printed]:find("| sen ssg08 FD |", 1, true) ~= nil, "a fake duck shot is marked FD")
    refs[SHORT.fakeduck].spec.value = false; advance(2)
    -- DT (Smart): the forced defensive stops while the shot is clean.
    lp.weapon_class = "CAK47"; advance(4)
    check(last_cmd.force_defensive == nil and ov("hidden") == false, "AK moving and seen (Smart): no forced defensive, no hidden angles while clean")
    handlers.aim_fire({ id = 1302, target = 5 }); handlers.aim_ack({ id = 1302, target = 5, state = "prediction error" })
    check(printed[#printed]:find("| sen ak47 temiz |", 1, true) ~= nil, "a DT shot without our lag is clean")
    globals.curtime, lp.next_attack = 50, 51; advance(1)
    check(last_cmd.force_defensive == true, "gun not ready: Smart forces defensive again")
    handlers.aim_fire({ id = 1303, target = 5 }); handlers.aim_ack({ id = 1303, target = 5, hitgroup = 2, damage = 30 })
    check(printed[#printed]:find("| sen ak47 DEF |", 1, true) ~= nil, "a shot during the forced defensive is marked DEF")
    globals.curtime, lp.next_attack = nil, nil; advance(2)
    -- Prediction errors during our own lag pause that lag (V1.0) like unregistered shots.
    globals.curtime, lp.next_attack = 50, 51; advance(1)
    handlers.aim_fire({ id = 1304, target = 5 }); handlers.aim_ack({ id = 1304, target = 5, state = "prediction error" })
    local lines_pe = #printed
    handlers.aim_fire({ id = 1305, target = 5 }); handlers.aim_ack({ id = 1305, target = 5, state = "prediction error" }); tick(0)
    check(last_cmd.force_defensive == nil
          and printed[lines_pe + 2] == "[Nykle.win] defensive 10 sn durduruldu: zorlanan defensive sirasinda 2 atis bozuk gitti (son: prediction error)",
          "two prediction errors during the forced defensive: paused (logged)")
    globals.curtime, lp.next_attack = nil, nil; advance(700)
    -- Stats: hit rate with our lag and clean (death shots do not count).
    handlers.aim_fire({ id = 1306, target = 5 }); handlers.aim_ack({ id = 1306, target = 5, state = "death" })
    M("switch", "Stats panel"):set(true); draw()
    check(contains(texts, "LAG   2 / 5   TEMIZ   1 / 2"), "stats panel: hits / shots with our lag (LC, FD, DEF) and clean")
    M("switch", "Stats panel"):set(false)
    -- Air: no teleport while the shot is clean (it spends the charge, the next bullet may not register).
    local tp0 = aa.teleports
    lp.m_fFlags = 0; lp.m_vecVelocity = vector(250, 0, 0); advance(5)
    check(aa.teleports == tp0 and last_cmd.force_defensive == nil and ov("hidden") == false,
          "in the air, seen, gun ready and the target shootable: no teleport, no forced defensive, no hidden angles; shoot instead")
    globals.curtime, lp.next_attack = 50, 51; advance(3)
    check(aa.teleports == tp0 + 1 and last_cmd.force_defensive == true and ov("hidden") == true,
          "gun not ready: teleports, defensive with hidden angles again")
    globals.curtime, lp.next_attack = nil, nil
    -- Without readable hitboxes nothing changes (the old behaviour).
    lp.m_fFlags = 1; advance(8)
    enemy.get_hitbox_position = nil; lp.weapon_class = "CWeaponSSG08"; advance(10)
    check(ov("hs_opt") == "Break LC", "hitboxes unreadable: never clean, Break LC as before")
    lp.m_vecVelocity = vector(0, 0, 0); enemy.m_iHealth = nil; lp.get_eye_position = nil
    reset_world()
end

-- AI peek ------------------------------------------------------------------------------------------
reset_world()
check(M("switch", "AI peek (hold Peek Assist)"):get() == true, "AI peek on by default")
local v0 = { view_angles = vector(0, 0, 0) }
world.threat = enemy; enemy.m_iHealth, enemy.m_ArmorValue = 100, 100; lp.weapon_class = "CWeaponSSG08"; lp.origin = vector(0, 0, 0)
-- The enemy (500 units ahead on +x) can be hit for 150 only from 20+ units to the left (+y).
local function hits_from(test, damage)
    return function(_, from, eye) if from == lp and eye ~= nil and test(eye.y) then return damage or 150 end return 0 end
end
local left_only = hits_from(function(y) return y >= 20 end)
world.trace = left_only; advance(70)
local c = tick(0, v0)
check(c.sidemove == nil and c.forwardmove == nil, "no AI peek without the Peek Assist key")
-- Key off for a few ticks (no scans), then held: the next tick scans.
local function fresh() refs[SHORT.peek].spec.value = false; advance(5); refs[SHORT.peek].spec.value = true end
-- A spot found by one scan is confirmed by a second one 2 ticks later before the walk starts.
local function go() tick(0, v0); tick(0, v0); return tick(0, v0) end
fresh()
local lines_ai = #printed
c = tick(0, v0)
check(c.sidemove == nil and #printed == lines_ai, "the first scan finds the spot but does not walk yet")
c = tick(0, v0)
check(c.sidemove == nil, "waiting for the confirming scan")
c = tick(0, v0); draw()
check(c.sidemove ~= nil and c.sidemove < -449 and math.abs(c.forwardmove) < 1 and contains(texts, "AI PEEK")
      and printed[lines_ai + 1] == "[Nykle.win] ai peek: sol 32 birim -> enemy5 (hasar 150)",
      "Peek Assist held: walks left (32 units, the nearest spot that kills) and logs it")
lp.origin = vector(0, 16, 0); c = tick(0, v0)
check(c.sidemove < -449, "keeps walking")
world.trace = hits_from(function(y) return y >= 29 end)
lp.origin = vector(0, 26, 0); c = tick(0, v0)
check(c.sidemove < 0 and c.sidemove > -449, "slows down in the last 12 units")
lp.origin = vector(0, 30, 0); c = tick(0, v0); draw()
check(c.sidemove == 0 and c.forwardmove == 0 and c.in_moveleft == false and contains(texts, "AI PEEK"), "arrived: stands still for the aimbot")
world.trace = left_only
c = tick(0, v0)
check(c.sidemove == 0, "the angle is open: keeps standing")
local function printed_since(n, text)
    for i = n + 1, #printed do if printed[i] == text then return true end end
    return false
end
local lines_shot = #printed
handlers.aim_fire({ id = 700, target = 5, hitgroup = 1, damage = 150 }); handlers.weapon_fire({ userid = 1 })
handlers.aim_ack({ id = 700, target = 5, hitgroup = 1, damage = 150 })
check(printed_since(lines_shot, "[Nykle.win] ai peek sonucu: isabet head -150 -> enemy5 (30 birim)"), "the AI peek's shot result is logged (hit)")
check(ov("peek") == false, "while AI peek walks / waits, Neverlose's Peek Assist is off (it held you in place)")
c = tick(0, v0); draw()
check(c.sidemove ~= nil and c.sidemove > 449 and not contains(texts, "AI PEEK") and ov("peek") == false,
      "after the shot the script walks you back itself")
lp.origin = vector(0, 0, 0); c = tick(0, v0); c = tick(0, v0)
check(c.sidemove == nil and ov("peek") == nil, "back home: Peek Assist is yours again")
lp.origin = vector(0, 0, 0); advance(40); c = tick(0, v0)
check(c.sidemove == nil, "no new peek right after a shot")
advance(15); c = tick(0, v0)
check(c.sidemove ~= nil and c.sidemove < -449, "peeks again 0.8 s after the shot")
lp.origin = vector(0, 24, 0); advance(4); c = tick(0, v0)
check(c.sidemove == 0, "the angle opens before the spot (24 of 32 units): stops there")
lines_shot = #printed
handlers.aim_fire({ id = 701, target = 5, hitgroup = 1, damage = 150 }); handlers.aim_ack({ id = 701, target = 5, state = "correction" })
check(printed_since(lines_shot, "[Nykle.win] ai peek sonucu: iska (correction) -> enemy5 (24 birim)"), "the AI peek's shot result is logged (miss)")
handlers.aim_fire({ id = 702, target = 5 }); handlers.aim_ack({ id = 702, target = 5, state = "spread" })
lp.origin = vector(0, 0, 0)
c = tick(0, { view_angles = vector(0, 0, 0), sidemove = 450 })
check(c.sidemove == 450 and printed[#printed] == "[Nykle.win] ai peek: iptal, hareket tusu", "pressing a movement key gives control back at once (logged)")
advance(4); c = tick(0, v0)
check(c.sidemove ~= nil and c.sidemove < -449, "peeking again")
c = tick(0, { view_angles = vector(0, 0, 0), in_moveleft = true })
check(c.sidemove == nil and printed[#printed] == "[Nykle.win] ai peek: iptal, hareket tusu", "a held movement key counts too")
advance(4); c = tick(0, { view_angles = vector(0, 90, 0) })
check(c.forwardmove ~= nil and c.forwardmove > 449 and math.abs(c.sidemove) < 1, "the walk follows your view (looking at +y: forward)")
handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 1, dmg_health = 100, weapon = "ssg08" })
check(printed[#printed - 1] == "[Nykle.win] ai peek: peek sirasinda vuruldun (head -100, enemy5)", "getting hit during the peek is logged")
-- No shot: back home after the walk times out; twice in a row pauses for 1.5 s.
local function until_back()
    for _ = 1, 80 do c = tick(0, v0); if c.sidemove == 0 then return true end end
    return false
end
check(until_back(), "no shot: the walk times out and you go back")
check(printed[#printed] == "[Nykle.win] ai peek: atis olmadi, sure doldu (0/32 birim gidildi) -> geri", "an empty peek says why and how far you got")
advance(22); c = tick(0, v0)
check(c.sidemove ~= nil and c.sidemove < -449, "peeks again 0.3 s later")
lp.origin = vector(0, 12, 0); tick(0, v0); lp.origin = vector(0, 0, 0)
check(until_back(), "second peek without a shot")
check(printed[#printed - 1] == "[Nykle.win] ai peek: atis olmadi, sure doldu (12/32 birim gidildi) -> geri"
      and printed[#printed] == "[Nykle.win] ai peek: 2 bos peek, bu dusmana Peek Assist tusuna yeniden basana kadar peek yok",
      "the furthest point reached is logged; two empty peeks are reported")
advance(100); c = tick(0, v0)
check(c.sidemove == nil, "two empty peeks at the same enemy: no more until the key is pressed again")
world.threat = enemy2; advance(4); c = tick(0, v0)
check(c.sidemove ~= nil and c.sidemove < -449, "another enemy: tries again")
check(until_back(), "an empty peek at the other enemy")
advance(22); c = tick(0, v0)
check(c.sidemove ~= nil and c.sidemove < -449, "the count is per enemy: the other enemy gets its second try")
world.threat = enemy; fresh(); c = go()
check(c.sidemove ~= nil and c.sidemove < -449 and c.in_moveleft == true and c.in_moveright == false,
      "the key pressed again: peeks again (movement keys shown pressed along)")
check(until_back(), "one empty peek")
advance(22); c = tick(0, v0)
check(c.sidemove ~= nil and c.sidemove < -449, "second try at the same enemy")
handlers.weapon_fire({ userid = 1 }); advance(60); c = tick(0, v0)
check(c.sidemove ~= nil and c.sidemove < -449, "peek after the shot")
check(until_back(), "one peek without a shot after a shot")
advance(22); c = tick(0, v0)
check(c.sidemove ~= nil and c.sidemove < -449, "a shot clears the count: the next try comes 0.3 s later")
-- R8: longer wait at the spot (cocking, accuracy).
local function hold_then(weapon, index)
    lp.weapon_class, lp.weapon_index = weapon, index; fresh(); go()
    lp.origin = vector(0, 30, 0); tick(0, v0); advance(37); c = tick(0, v0)
    lp.origin = vector(0, 0, 0)
    return c.sidemove
end
check(hold_then("CWeaponSSG08", 40) > 0, "scout: after half a second at the spot without a shot it goes back")
check(hold_then("CDEagle", 64) == 0, "R8: still waiting at the spot after 0.6 s")
lp.weapon_class, lp.weapon_index = "CWeaponSSG08", 40
fresh(); c = go(); refs[SHORT.peek].spec.value = false; tick(0, v0)
check(printed[#printed] == "[Nykle.win] ai peek: iptal, Peek Assist birakildi", "releasing the key cancels the peek (logged)")
local short_of = hits_from(function(y) return y >= 20 end, 60)
fresh(); c = go(); world.trace = short_of; advance(1); c = tick(0, v0)
check(c.sidemove ~= nil and c.sidemove < -449, "one scan without the angle does not turn you back (enemy jitter)")
world.trace = left_only; advance(1); c = tick(0, v0); world.trace = short_of; advance(3); c = tick(0, v0)
check(c.sidemove ~= nil and c.sidemove < -449, "a good scan starts the count over")
local lines_closed = #printed
advance(2)
check(printed_since(lines_closed, "[Nykle.win] ai peek: atis olmadi, aci kapandi, hasar 60/101 (0/32 birim gidildi) -> geri"),
      "three scans in a row without the angle: back (logged with the best damage, here or at the spot)")
-- The next peek (same key hold) starts its own count: its very first rescan may miss too.
world.trace = left_only
local started_next = false
for _ = 1, 40 do
    local before = #printed
    c = tick(0, v0)
    if #printed > before and printed[#printed]:find("ai peek: sol 32 birim", 1, true) then started_next = true; break end
end
world.trace = NO_TRACE; tick(0, v0); c = tick(0, v0)
check(started_next and c.sidemove ~= nil and c.sidemove < -449, "the next peek is not given up on its first bad scan")
-- The enemy goes into defensive while you walk out (its record is fake): those scans do not count.
local psim = 80
enemy.m_flSimulationTime = psim; world.trace = left_only; lp.origin = vector(0, 0, 0)
fresh(); c = go()
enemy.m_flSimulationTime = psim - 0.1; world.trace = NO_TRACE; advance(21); c = tick(0, v0)
check(c.sidemove ~= nil and c.sidemove < -449, "the enemy in defensive: a closed angle is not counted, the walk goes on")
local lines_faked = #printed
enemy.m_flSimulationTime = psim + 0.5; advance(8)
check(printed_since(lines_faked, "[Nykle.win] ai peek: atis olmadi, aci kapandi, hasar 0/101, dusman defensive kullandi (0/32 birim gidildi) -> geri"),
      "after the defensive the angle is still closed: back (says the enemy used defensive)")
enemy.m_flSimulationTime = nil; world.trace = left_only; advance(25)
-- The same while the enemy breaks LC (teleports more than 64 units).
enemy.m_flSimulationTime = 90; fresh(); c = go()
enemy.origin = vector(600, 0, 0); enemy.m_flSimulationTime = 90 + 1 / 64; world.trace = NO_TRACE; advance(9); c = tick(0, v0)
check(c.sidemove ~= nil and c.sidemove < -449, "the enemy broke LC: a closed angle is not counted either")
enemy.origin = vector(500, 0, 0); enemy.m_flSimulationTime = nil; world.trace = left_only; lp.origin = vector(0, 0, 0); advance(40)
-- A scan that finds the angle open where you stand also starts the count over.
world.trace = left_only; fresh(); c = go()
world.trace = NO_TRACE; advance(1); c = tick(0, v0)
lp.origin = vector(0, 24, 0); world.trace = left_only; advance(1); c = tick(0, v0)
check(c.sidemove == 0, "the angle opened on the way: stops there")
local lines_here = #printed
world.trace = NO_TRACE; advance(4); c = tick(0, v0)
check(#printed == lines_here, "two bad scans after a good one: still waiting")
advance(2)
check(printed_since(lines_here, "[Nykle.win] ai peek: atis olmadi, aci kapandi, hasar 0/101 (24/32 birim gidildi) -> geri"),
      "the third: back")
lp.origin = vector(0, 0, 0); world.trace = left_only
-- A narrow window (30-34 units): from halfway the 18 / 32 steps miss it, the spot itself still kills.
fresh(); world.trace = hits_from(function(y) return y >= 30 and y <= 34 end); c = go()
check(c.sidemove ~= nil and c.sidemove < -449, "narrow window: walks to 32")
local lines_nw = #printed
lp.origin = vector(0, 10, 0); advance(8); c = tick(0, v0)
check(c.sidemove ~= nil and c.sidemove < -449 and #printed == lines_nw, "halfway the spot is re-checked, not given up")
lp.origin = vector(0, 0, 0)
-- The threat switches to an enemy that cannot be hit: the walk keeps its own enemy.
fresh(); world.enemies = { enemy, enemy2 }
world.trace = function(to, from, eye) if from == lp and eye ~= nil and eye.y >= 20 and to.x > 100 then return 150 end return 0 end
c = go()
check(c.sidemove ~= nil and c.sidemove < -449, "walking toward enemy5")
check(ov("base") == "At Target", "peeking the threat itself: the AA keeps Neverlose's At Target")
enemy2.origin = vector(0, 500, 0); world.threat = enemy2; advance(8); c = tick(0, v0)
check(c.sidemove ~= nil and c.sidemove < -449, "the threat became enemy2: the peek at enemy5 goes on")
check(ov("base") == "Local View" and math.abs(ov("offset")) <= 60,
      "the AA faces the enemy you are peeking (ahead), not the new threat (to the side)")
world.threat, world.enemies, enemy2.origin = enemy, { enemy }, vector(500, 0, 0)
-- Peeking the threat while another enemy sees your head: the AA stays on the enemy you peek.
fresh(); world.enemies = { enemy, enemy2 }; enemy2.eye = vector(0, 500, 64)
world.trace = function(to, from, eye)
    if from == lp and eye ~= nil and eye.y >= 20 then return 150 elseif from == enemy2 and to.y < 10 then return 30 end
    return 0
end
c = go(); advance(1); c = tick(0, v0)
check(c.sidemove ~= nil and c.sidemove < -449 and ov("base") == "At Target",
      "peeking the threat while a flanker sees you: the AA stays on the threat")
-- Another enemy would see your head at the spot: no peek there (it is not just the target that shoots).
local seen_lines = #printed
fresh(); world.trace = function(to, from, eye)
    if from == lp and eye ~= nil and eye.y >= 20 then return 150 elseif from == enemy2 and to.y > 10 then return 30 end
    return 0
end
c = go(); advance(70)
check(c.sidemove == nil and printed_since(seen_lines, "[Nykle.win] ai peek: peek yok, enemy5 icin nokta var ama enemy7 de kafani gorurdu"),
      "a spot where another enemy sees your head is skipped (logged)")
fresh(); world.trace = function(to, from, eye)
    if from == lp and eye ~= nil and eye.y >= 20 then return 150 elseif from == enemy then return 30 end
    return 0
end
c = go()
check(c.sidemove ~= nil and c.sidemove < -449, "the enemy you peek seeing you there is the point of the peek: walks")
world.enemies = { enemy }
world.trace = left_only
-- The nearest spot wins; while walking the side is kept.
fresh(); world.trace = hits_from(function(y) return y >= 16 or y <= -30 end)
c = go()
check(c.sidemove ~= nil and c.sidemove < -449 and printed[#printed]:find("ai peek: sol 18 birim", 1, true) ~= nil,
      "both sides open: the nearer one (left 18, right 32)")
fresh(); world.trace = hits_from(function(y) return y >= 44 or y <= -30 end)
c = go()
check(c.sidemove ~= nil and c.sidemove > 449 and printed[#printed]:find("ai peek: sag 32 birim", 1, true) ~= nil,
      "both sides open: the nearer one (right 32, left 46)")
world.trace = hits_from(function(y) return y >= 16 or y <= -30 end); advance(4); c = tick(0, v0)
check(c.sidemove ~= nil and c.sidemove > 449, "the other side getting closer does not turn the walk around")
local lines_turn = #printed
lp.origin = vector(0, -10, 0); world.trace = hits_from(function(y) return y >= 16 end); advance(3); c = tick(0, v0)
check(#printed == lines_turn and c.sidemove ~= nil and c.sidemove > 449, "only the other side kills: not given up on the first scan")
advance(1)
check(printed_since(lines_turn, "[Nykle.win] ai peek: atis olmadi, aci sadece diger tarafta (10/32 birim gidildi) -> geri"),
      "this side closed and only the other side kills: back (no turning around mid-walk)")
lp.origin = vector(0, 0, 0)
-- Confirmation: a spot seen by one scan only (enemy jitter) is not walked to.
fresh(); world.trace = left_only; c = tick(0, v0)
world.trace = NO_TRACE; tick(0, v0); c = tick(0, v0)
check(c.sidemove == nil, "the spot is gone on the second scan: no walk")
world.trace = left_only; advance(3); c = tick(0, v0)
check(c.sidemove == nil, "found again: a new first scan")
tick(0, v0); c = tick(0, v0)
check(c.sidemove ~= nil and c.sidemove < -449, "confirmed: walks")
fresh(); world.trace = hits_from(function(y) return y >= 20 end); c = tick(0, v0)
world.trace = hits_from(function(y) return y <= -20 end); tick(0, v0); c = tick(0, v0)
check(c.sidemove == nil, "the second scan finds the other side: not confirmed")
tick(0, v0); c = tick(0, v0)
check(c.sidemove ~= nil and c.sidemove > 449, "the other side confirmed: walks right")
-- At the spot the angle slides further (the enemy walked): followed on the same side, up to 74 units.
fresh(); world.trace = hits_from(function(y) return y >= 29 end); c = go()
check(printed[#printed]:find("ai peek: sol 32 birim", 1, true) ~= nil, "walks to 32")
lp.origin = vector(0, 32, 0); c = tick(0, v0)
check(c.sidemove == 0, "at the spot")
world.trace = hits_from(function(y) return y >= 44 end); c = tick(0, v0)
check(c.sidemove ~= nil and c.sidemove < -449, "the angle slid further: follows it on the same side")
lp.origin = vector(0, 50, 0); c = tick(0, v0)
check(c.sidemove == 0, "at the new spot")
local lines_far = #printed
world.trace = hits_from(function(y) return y >= 80 end); advance(5)
check(printed_since(lines_far, "[Nykle.win] ai peek: atis olmadi, aci 74 birimden uzakta (50/50 birim gidildi) -> geri"),
      "not further than 74 units from where you started: back (logged)")
lp.origin = vector(0, 0, 0)
-- Following late in the wait still gets time to walk.
fresh(); world.trace = hits_from(function(y) return y >= 29 end); c = go()
lp.origin = vector(0, 32, 0); advance(28)
world.trace = hits_from(function(y) return y >= 44 end); advance(1); c = tick(0, v0)
check(c.sidemove ~= nil and c.sidemove < -449, "the angle slid at the end of the wait: follows it")
advance(5); c = tick(0, v0)
check(c.sidemove ~= nil and c.sidemove < -449, "the follow walk gets its own time (not cut off by the end of the wait)")
lp.origin = vector(0, 0, 0)
-- The confirming scan has to be about the same enemy.
fresh(); world.enemies = { enemy, enemy2 }; world.trace = left_only; c = tick(0, v0)
world.threat = enemy2; tick(0, v0); c = tick(0, v0)
check(c.sidemove == nil, "the threat changed between the scans: not confirmed")
tick(0, v0); c = tick(0, v0)
check(c.sidemove ~= nil and c.sidemove < -449, "confirmed for the new enemy: walks")
world.threat, world.enemies = enemy, { enemy }
-- A first scan from long ago does not count (the scans paused while DT charged).
lp.weapon_class = "CAK47"; fresh(); c = tick(0, v0)
aa.charge = 0.5; advance(10); aa.charge = 1; c = tick(0, v0)
check(c.sidemove == nil, "the first scan was long ago: scanned again before walking")
tick(0, v0); c = tick(0, v0)
check(c.sidemove ~= nil and c.sidemove < -449, "then confirmed: walks")
lp.weapon_class = "CWeaponSSG08"
-- The stomach counts too: a low-HP enemy whose head and chest are covered.
enemy.m_iHealth = 60
world.trace = function(to, from, eye) if from == lp and eye ~= nil and eye.y >= 20 and to.z < 45 then return 90 end return 0 end
fresh(); c = go()
check(c.sidemove ~= nil and c.sidemove < -449, "only the stomach is open and it kills (60 HP): peek")
enemy.m_iHealth = 100; world.trace = left_only
-- Defensive peek: with DT the defensive starts while walking out, before anyone sees you.
lp.weapon_class = "CAK47"; aa.charge = 1; world.trace = left_only
fresh(); tick(0, v0); tick(0, v0)
check(last_cmd.force_defensive == nil, "not seen and not peeking yet: nothing forced")
c = tick(0, v0)
check(c.sidemove ~= nil and c.sidemove < -449 and c.force_defensive == true,
      "AI peek walking out with DT: defensive forced before the enemy sees you")
lp.origin = vector(0, 30, 0); c = tick(0, v0)
check(c.sidemove == 0 and c.force_defensive == true, "waiting at the spot: still forced")
handlers.weapon_fire({ userid = 1 }); c = tick(0, v0)
check(c.sidemove ~= nil and c.sidemove > 449 and c.force_defensive == nil, "after the shot, walking back: not forced by the peek")
lp.origin = vector(0, 0, 0); advance(70)
M("switch", "Defensive during AI peek"):set(false); fresh(); c = go()
check(c.sidemove ~= nil and c.sidemove < -449 and c.force_defensive == nil, "defensive during AI peek can be turned off")
M("switch", "Defensive during AI peek"):set(true); fresh(); c = go()
check(c.force_defensive == true, "back on")
c = tick(0, v0)
check(ov("offset") == -20 or ov("offset") == 45, "walking AI peek (key held, no movement keys): the Peek state's AA")
lp.weapon_class = "CWeaponSSG08"; fresh(); c = go()
check(c.sidemove ~= nil and c.force_defensive == nil and ov("hs_opt") == "Break LC",
      "scout (hide shots): Break LC, nothing forced (forcing needs DT)")
fresh(); world.trace = left_only; enemy.dormant = true; c = go()
check(c.sidemove == nil, "a dormant enemy (old position) is not peeked")
enemy.dormant = nil
-- Holding the key without a peek: the reason, once per press.
local function times_printed(text)
    local n = 0
    for _, line in ipairs(printed) do if line == text then n = n + 1 end end
    return n
end
local NO_SPOT = "[Nykle.win] ai peek: peek yok, enemy5 icin 60 birime kadar oldurecek atis yok"
local no_spot_before = times_printed(NO_SPOT)
fresh(); world.trace = NO_TRACE; advance(50)
check(times_printed(NO_SPOT) == no_spot_before, "no reason logged in the first second")
advance(80)
check(times_printed(NO_SPOT) == no_spot_before + 1, "holding the key without a spot: the reason is logged once")
fresh(); advance(70)
check(times_printed(NO_SPOT) == no_spot_before + 2, "again after the key is pressed again")
fresh(); world.trace = hits_from(function(y) return y < 1 end); advance(70)
check(times_printed("[Nykle.win] ai peek: peek yok, enemy5 buradan vurulabiliyor, aimbot ates etmeli") == 1,
      "already hittable: says the aimbot should be shooting")
world.threat, world.enemies = nil, {}; fresh(); advance(70)
check(times_printed("[Nykle.win] ai peek: peek yok, hedef yok") == 1, "no enemy: says so")
world.threat, world.enemies, world.trace = enemy, { enemy }, left_only
fresh(); c = go(); advance(80)
check(times_printed(NO_SPOT) == no_spot_before + 2, "a peek happened: no idle reason")
-- Walls, ledges, damage, exploit and settings.
fresh(); world.hull = function(_, to) if to.y > 20 then return 0.5 end return 1 end; c = go()
check(c.sidemove == nil, "a wall on the left: no peek there")
world.trace = hits_from(function(y) return y <= -30 end); advance(4); c = tick(0, v0)
check(c.sidemove ~= nil and c.sidemove > 449, "the right side is open: walks right")
fresh(); world.hull, world.trace = OPEN, left_only
world.line = function(from) if from.y > 20 then return 1 end return 0.5 end; c = go()
check(c.sidemove == nil, "no ground there (a drop): no peek")
world.line = GROUND
fresh(); world.trace = hits_from(function(y) return y >= 20 end, 60); c = go()
check(c.sidemove == nil, "the scout would not kill (60 < 100 HP): no peek")
enemy.m_iHealth = 50; advance(4); c = tick(0, v0)
check(c.sidemove ~= nil and c.sidemove < -449, "it would kill a 50 HP enemy: peek")
enemy.m_iHealth = 100
fresh(); world.trace = hits_from(function(y) return y >= 20 or y < 1 end); c = go()
check(c.sidemove == nil, "already hittable from where you stand: the aimbot shoots, no walk")
world.trace = hits_from(function(y) return y >= 20 end, 60)
lp.weapon_class = "CAK47"; aa.charge = 0.5; fresh(); c = go()
check(c.sidemove == nil, "double tap charging: no peek")
advance(70)
check(times_printed("[Nykle.win] ai peek: peek yok, DT sarj oluyor") == 1, "double tap charging: says so")
aa.charge = 1; advance(4); c = tick(0, v0)
check(c.sidemove ~= nil, "double tap charged: peek (rifle: 60 is above your minimum damage 30)")
fresh(); refs[SHORT.min_damage].spec.value = 110; world.trace = hits_from(function(y) return y >= 20 end, 105); c = go()
check(c.sidemove == nil, "your minimum damage 110 = HP + 10: 105 is not enough")
refs[SHORT.min_damage].spec.value = 30; world.trace = left_only
-- V1.0: no peek while the gun cannot fire (bolt cycling, empty clip) or while hide shots charges.
do
    local NOT_READY = "[Nykle.win] ai peek: peek yok, silah hazir degil (surgu / sarjor)"
    lp.weapon_class = "CWeaponSSG08"; aa.charge = 1; advance(4)
    globals.curtime, lp.next_attack = 50, 51
    local before = times_printed(NOT_READY)
    fresh(); c = go()
    check(c.sidemove == nil, "the scout's bolt is still cycling (1 s left): no peek")
    advance(70)
    check(times_printed(NOT_READY) == before + 1, "the reason is logged")
    lp.next_attack = 50.1; advance(4); c = tick(0, v0)
    check(c.sidemove ~= nil and c.sidemove < -449, "ready within 0.15 s: peek")
    fresh(); lp.clip = 0; c = go()
    check(c.sidemove == nil, "empty clip (reloading): no peek")
    lp.clip, lp.next_attack, globals.curtime = nil, nil, nil
    fresh(); aa.charge = 0.5; c = go()
    check(ov("hs") == true and c.sidemove == nil, "hide shots charging: no peek")
    advance(70)
    check(times_printed("[Nykle.win] ai peek: peek yok, HS sarj oluyor") >= 1, "hide shots charging: says so")
    aa.charge = 1; advance(4); c = tick(0, v0)
    check(c.sidemove ~= nil, "hide shots charged: peek")
end
-- V1.0: an enemy above (32+ units higher): the angle often opens only by stepping back, so the
-- back-diagonal spots are tried too.
do
    local back_left = function(_, from, eye) if from == lp and eye ~= nil and eye.x < -10 and eye.y > 10 then return 150 end return 0 end
    world.trace = back_left
    fresh(); c = go()
    check(c.sidemove == nil, "an enemy on the same level: no back-diagonal spots")
    enemy.origin = vector(500, 0, 100)
    local lines_up = #printed
    fresh(); c = go()
    check(c.forwardmove ~= nil and c.forwardmove < -300 and c.sidemove < -300
          and printed_since(lines_up, "[Nykle.win] ai peek: sol-geri 18 birim -> enemy5 (hasar 150)"),
          "an enemy above: walks back-left (the angle opens when stepping back), logged")
    enemy.origin = vector(500, 0, 0); world.trace = left_only
end
fresh(); lp.weapon_class = "CKnife"; c = go()
check(c.sidemove == nil, "not with a knife")
fresh(); lp.weapon_class = "CWeaponSSG08"; lp.m_fFlags = 0; c = go()
check(c.sidemove == nil, "not in the air")
lp.m_fFlags = 1; M("switch", "AI peek (hold Peek Assist)"):set(false); fresh(); c = go()
check(c.sidemove == nil, "can be turned off")
-- V1.0: a body spot counts only if it kills (with DT: two bullets). "AI peek sometimes shoots the body":
-- with a low Min. Damage on an AK the script walked to an angle where only a non-lethal body was open.
do
    M("switch", "AI peek (hold Peek Assist)"):set(true)
    lp.weapon_class = "CAK47"; aa.charge = 1; refs[SHORT.dt].spec.value = true
    -- From 20+ units left: only the body (z below 60) for 40; the head stays hidden.
    local body_only = function(to, from, eye)
        if from == lp and eye ~= nil and eye.y >= 20 and to.z < 60 then return 40 end
        return 0
    end
    world.trace = body_only
    fresh(); c = go()
    check(c.sidemove == nil, "AK, only a 40 body open (two bullets 80 < 100 HP): no peek")
    enemy.m_iHealth = 70; fresh(); c = go()
    check(c.sidemove ~= nil and c.sidemove < -449, "70 HP: two body bullets kill (80): peek")
    enemy.m_iHealth = 100
    local head_too = function(to, from, eye)
        if from == lp and eye ~= nil and eye.y >= 20 then return to.z < 60 and 40 or 120 end
        return 0
    end
    world.trace = head_too; fresh(); c = go()
    check(c.sidemove ~= nil and c.sidemove < -449, "the head is open too: peek")
    -- At the spot: a real record keeps the normal 0.5 s wait; a fake record (defensive) adds 0.2 s,
    -- once per peek.
    local function hold_ticks(fake)
        lp.origin = vector(0, 32, 0); tick(0, v0); tick(0, v0)
        local sim = 80
        enemy.m_flSimulationTime = sim; tick(0, v0)
        sim = sim + 1 / 64; enemy.m_flSimulationTime = sim; tick(0, v0)
        if fake then enemy.m_flSimulationTime = sim - 0.1 end
        local held = 0
        for _ = 1, 60 do
            if not fake then sim = sim + 1 / 64; enemy.m_flSimulationTime = sim end
            c = tick(0, v0)
            if c.sidemove == 0 then held = held + 1 else break end
        end
        enemy.m_flSimulationTime = nil
        lp.origin = vector(0, 0, 0); advance(40)
        return held
    end
    local normal = hold_ticks(false)
    check(normal >= 26 and normal <= 32, "a real record at the spot: the normal 0.5 s wait (" .. normal .. " ticks)")
    fresh(); c = go()
    local first = hold_ticks(true)
    fresh(); c = go()
    local second = hold_ticks(true)
    check(first >= 40 and first <= 48 and second >= 40 and second <= 48,
          "the enemy on a fake record while you wait: about 0.7 s instead of 0.5, on every peek (" .. first .. ", " .. second .. " ticks)")
    -- Only the edge of the enemy's head can be hit (its center is behind cover): still a peek (V1.0).
    lp.weapon_class = "CWeaponSSG08"; refs[SHORT.dt].spec.value = false
    world.trace = function(to, from, eye)
        if from == lp and eye ~= nil and eye.y >= 20 and to.z == 64 and math.abs(to.y) > 1 then return 300 end
        return 0
    end
    fresh(); c = go()
    check(c.sidemove ~= nil and c.sidemove < -449, "scout, only the edge of the head is open from the side: peek (the edges count)")
    lp.origin = vector(0, 0, 0); fresh()
    world.trace = left_only; lp.weapon_class = "CWeaponSSG08"; refs[SHORT.dt].spec.value = false
end
M("switch", "AI peek (hold Peek Assist)"):set(true); fresh(); c = go(); draw()
check(c.sidemove ~= nil and contains(texts, "AI PEEK"), "back on")
check(ov("peek") == false, "Peek Assist overridden during the peek")
handlers.round_start({}); draw()
check(not contains(texts, "AI PEEK") and ov("peek") == nil, "a new round starts over (Peek Assist handed back at once)")
M("switch", "Stats panel"):set(true); draw()
local ai_row
for _, t in ipairs(texts) do
    local a, b2, h, e2, v = t:match("^AI PEEK   (%d+) / (%d+) / (%d+) / (%d+) / (%d+)$")
    if a then ai_row = { tonumber(a), tonumber(b2), tonumber(h), tonumber(e2), tonumber(v) } end
end
check(contains(texts, "AI PEEK   PEEK / ATIS / ISABET / BOS / VURULDUN") and ai_row ~= nil and ai_row[1] > 5
      and ai_row[2] == 3 and ai_row[3] == 1 and ai_row[4] > 2 and ai_row[5] == 1,
      "stats panel: AI peek peeks / shots / hits / empty / hurt")
E("button", "Reset stats"):click(); draw()
check(not contains(texts, "AI PEEK   PEEK / ATIS / ISABET / BOS / VURULDUN"), "reset stats clears the AI peek row")
M("switch", "Stats panel"):set(false)
refs[SHORT.peek].spec.value = false; lp.origin = vector(0, 0, 0)
enemy.m_iHealth, enemy.m_ArmorValue = nil, nil
handlers.level_init(); forget()
reset_world()

-- Head edges: only the side of your head is visible (its center is behind cover) ------------------
reset_world()
world.threat = enemy; world.enemies = { enemy }; lp.weapon_class = "CAK47"; aa.charge = 1
lp.m_vecVelocity = vector(100, 0, 0)
world.trace = function(to, from) if from == enemy and to.y > 1 then return 30 end return 0 end
advance(4)
check(last_cmd.force_defensive == true, "the threat sees only the edge of your head: counts as seen (smart defensive)")
world.trace = NO_TRACE; advance(12)
check(last_cmd.force_defensive == nil, "nothing visible: released")
world.enemies = { enemy, enemy2 }; enemy2.eye = vector(0, 500, 64)
world.trace = function(to, from) if from == enemy2 and to.x > 1 then return 30 end return 0 end
advance(6)
check(last_cmd.force_defensive == true, "another enemy sees only the edge of your head: counts too")
world.enemies = { enemy }; lp.m_vecVelocity = vector(0, 0, 0)
reset_world()

-- Resolver panel (text only) --------------------------------------------------------------------
do
    reset_world()
    handlers.level_init(); forget(); E("button", "Reset stats"):click()
    M("switch", "Resolver panel"):set(true); world.threat = enemy; world.enemies = { enemy, enemy2 }; tick(0)
    local function settle(n) for _ = 1, n or 80 do draw() end end
    settle(1)
    check(contains(texts, "80%") and contains(texts, "enemy5") and contains(texts, "COZUM   HIT 72%   0/0") and polys == 0,
          "text only: the target's live resolve estimate (no data: 80%, V1.0), its name, the live hit chance (80% x 0.98 spread x 0.92 other prior = 72%); no box")
    handlers.aim_fire({ id = 900, target = 5, hitgroup = 1, hitchance = 80 }); handlers.aim_ack({ id = 900, target = 5, hitgroup = 1, damage = 100 })
    handlers.aim_fire({ id = 901, target = 5, hitgroup = 1, hitchance = 80 }); handlers.aim_ack({ id = 901, target = 5, hitgroup = 1, damage = 100 })
    handlers.aim_fire({ id = 902, target = 5, hitgroup = 1, hitchance = 80 }); handlers.aim_ack({ id = 902, target = 5, state = "correction" })
    handlers.aim_fire({ id = 903, target = 5, hitchance = 80 }); handlers.aim_ack({ id = 903, target = 5, state = "spread" })
    tick(0); draw()
    local moving = texts[1] ~= "78%"
    settle()
    check(moving and contains(texts, "78%") and contains(texts, "COZUM   HIT 67%   2/3"),
          "the number slides to the new estimate (2 of 3 with the 0.8 prior + safe point prefer = 78%); hit from real spread / other rates = 67%")
    local c = colors["78%"]
    check(c ~= nil and c.g > c.r and c.r > 100, "78%: between yellow and green")
    local copies = 0
    for _, t in ipairs(texts) do if t == "78%" then copies = copies + 1 end end
    check(copies == 2, "every text has a shadow under it (readable without a box)")
    handlers.aim_fire({ id = 906, target = 5, hitgroup = 1, hitchance = 80 }); handlers.aim_ack({ id = 906, target = 5, state = "damage rejection" })
    handlers.aim_fire({ id = 907, target = 5, hitchance = 10 }); handlers.aim_ack({ id = 907, target = 5, state = "death" })
    handlers.aim_fire({ id = 908, target = 5, hitchance = 10 }); handlers.aim_ack({ id = 908, target = 5, state = "player death" })
    tick(0); settle()
    check(contains(texts, "78%") and contains(texts, "COZUM   HIT 59%   2/3"),
          "a rejected shot lowers the hit chance (67% -> 59%), not the resolve estimate; deaths do not count")
    -- Live: the enemy goes into defensive (its record is fake): the number drops at once and comes back.
    enemy.m_flSimulationTime = 60; tick(0); enemy.m_flSimulationTime = 60 + 1 / 64; tick(0)
    enemy.m_flSimulationTime = 59.9; tick(0); settle()
    check(contains(texts, "39%") and colors["39%"].r > 200 and colors["39%"].g < 185, "the enemy in defensive: the estimate drops live (x 0.5), orange")
    enemy.m_flSimulationTime = 60.5; tick(0); settle()
    check(contains(texts, "78%"), "a real record again: back up")
    enemy.origin = vector(600, 0, 0); enemy.m_flSimulationTime = 60.5 + 1 / 64; tick(0); settle()
    check(contains(texts, "47%"), "the enemy broke LC (teleported): x 0.6")
    enemy.origin = vector(500, 0, 0); enemy.m_flSimulationTime = 60.5 + 2 / 64; tick(0)
    advance(20); settle()
    local sim, yaw = 61, 30
    for _ = 1, 6 do sim = sim + 1 / 64; yaw = -yaw; enemy.m_flSimulationTime = sim; enemy.m_angEyeAngles = vector(0, yaw, 0); tick(0) end
    settle()
    check(contains(texts, "70%"), "a jittering enemy (60 degrees on average): lower (x 0.9)")
    enemy.m_flSimulationTime, enemy.m_angEyeAngles = nil, nil; tick(0)
    enemy.m_fFlags = 0; tick(0); settle()
    check(contains(texts, "70%"), "an enemy in the air: lower (x 0.9)")
    enemy.m_fFlags = nil
    enemy.origin = vector(2000, 0, 0); tick(0); settle()
    check(contains(texts, "72%"), "far (2000 units): lower (x 0.92)")
    enemy.origin = vector(2600, 0, 0); tick(0); settle()
    check(contains(texts, "66%"), "farther (2600 units): x 0.85")
    enemy.origin = vector(500, 0, 0); tick(0); settle()
    globals.realtime = globals.realtime + 2; world.threat = enemy2; tick(0); draw()
    check(contains(texts, "80%") and contains(texts, "enemy7"), "another target: its own number at once (no slide from the last one)")
    world.threat = enemy; tick(0); settle()
    enemy.name = "averyveryverylongname"; draw()
    check(contains(texts, "averyveryverylo."), "long names are shortened")
    enemy.name = "enemy5"; settle(2)
    -- Moving with the mouse (menu open): press on the text, drag, release; saved to the sliders.
    local p0 = text_pos["78%"]
    mouse_state.alpha, mouse_state.pos, mouse_state.down = 1, vector(p0.x + 5, p0.y + 5), true; draw()
    check(handlers.mouse_input() == false and polys == 1, "menu open: a frame and the resize grip show; the click does not reach the menu")
    mouse_state.pos = vector(p0.x + 105, p0.y + 55); draw()
    check(text_pos["78%"].x == p0.x + 100 and text_pos["78%"].y == p0.y + 50, "the text follows the mouse")
    mouse_state.down = false; draw(); draw()
    check(handlers.mouse_input() == nil and M("slider", "Position X"):get() ~= 12 and M("slider", "Position Y"):get() ~= 330
          and math.abs(text_pos["78%"].x - (p0.x + 100)) <= 2 and math.abs(text_pos["78%"].y - (p0.y + 50)) <= 2,
          "released: the position is saved (config) and kept")
    -- Resizing with the bottom-right grip (text 105 x 39 px + frame = 109 x 42).
    local p1 = text_pos["78%"]
    local corner = vector(p1.x + 109 - 2, p1.y + 42 - 2)
    mouse_state.pos, mouse_state.down = corner, true; draw()
    mouse_state.pos = vector(corner.x + 55, corner.y); draw()
    mouse_state.down = false; draw()
    check(M("slider", "Size"):get() == 150 and math.abs(text_pos["78%"].x - p1.x) <= 2,
          "dragging the bottom-right corner resizes (150%), the text stays put")
    M("slider", "Size"):set(100); draw()
    -- Menu closed: no dragging.
    local p2 = text_pos["78%"]
    mouse_state.alpha, mouse_state.pos, mouse_state.down = 0, vector(p2.x + 5, p2.y + 5), true; draw()
    mouse_state.pos = vector(p2.x + 300, p2.y + 300); draw()
    check(text_pos["78%"].x == p2.x and text_pos["78%"].y == p2.y and polys == 0, "menu closed: no frame, it does not move")
    mouse_state.down, mouse_state.pos = false, nil; draw()
    local p3 = text_pos["78%"]
    mouse_state.alpha, mouse_state.pos, mouse_state.down = 1, vector(p3.x + 5, p3.y + 5), true; draw()
    mouse_state.pos = vector(p3.x + 5000, p3.y + 5000); draw()
    check(text_pos["78%"].x <= 1920 - 109 and text_pos["78%"].y <= 1080 - 42, "the text stays on the screen")
    mouse_state.pos = vector(-5000, -5000); draw()
    check(text_pos["78%"].x >= 0 and text_pos["78%"].y >= 0, "on every side")
    mouse_state.down = false; draw(); mouse_state.alpha, mouse_state.pos = 0, nil
    world.threat = nil; world.enemies = {}; handlers.level_init(); tick(0); draw()
    check(contains(texts, "--") and contains(texts, "COZUM   hedef yok"), "no target: says so")
    M("switch", "Resolver panel"):set(false); draw()
    check(not contains(texts, "COZUM   hedef yok"), "the panel can be turned off")
    M("slider", "Position X"):set(12); M("slider", "Position Y"):set(330)
    world.enemies = { enemy }; world.threat = nil; handlers.level_init(); forget(); E("button", "Reset stats"):click()
    reset_world()
end

-- Smart AA target ----------------------------------------------------------------------------------
reset_world()
local function norm(y) y = (y + 180) % 360 - 180; if y == -180 then y = 180 end; return y end
local view = function(yaw) return { view_angles = vector(0, yaw, 0) } end
B("Standing", "slider", "Delay randomize"):set(0)
-- (The "alive enemies" check for spin is cached for 16 ticks: let it see the living enemy first.)
world.enemies = { enemy }; world.threat = nil; advance(16)
tick(0, view(90))
check(ov("base") == "Local View" and ov("offset") == norm(yaw_for(-23, 51) - 90),
      "no threat: the AA turns its back to the nearest enemy (enemy straight ahead on +x, looking at 90)")
handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 2, dmg_health = 20, weapon = "ssg08" })
check(printed[#printed]:find("enemy5 (Standing, AA hedefi, ", 1, true) ~= nil, "the log knows which enemy the AA faced")
tick(0, view(-170))
check(ov("offset") == norm(yaw_for(-23, 51) + 170), "follows your view")
enemy.dormant = true; tick(0, view(90))
check(ov("base") == "At Target", "a dormant enemy's old position is not used")
enemy.dormant = nil
local near = new_player(true, true, vector(0, -200, 0)); near.index, near.name = 12, "near"
players[12] = near; world.enemies = { near, enemy }; tick(0, view(0))
check(ov("offset") == norm(yaw_for(-23, 51) - 90), "the nearest of several enemies")
players[12] = nil; world.enemies = { enemy }
world.threat = enemy; tick(0, view(90))
check(ov("base") == "At Target" and ov("offset") == yaw_for(-23, 51), "with a threat Neverlose's at target is kept")
enemy2.origin = vector(0, 500, 0); world.enemies = { enemy, enemy2 }
world.trace = function(to, from) return from == enemy2 and 30 or 0 end; advance(4); tick(0, view(0))
check(ov("base") == "Local View" and ov("offset") == norm(yaw_for(-23, 51) + 90),
      "the threat cannot see you but a flanker can: the AA turns to the flanker")
handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 2, dmg_health = 20, weapon = "ssg08" })
check(printed[#printed]:find("enemy5 (Standing, AA hedefi degil, ", 1, true) ~= nil, "a hit from the threat while facing the flanker")
world.trace = function() return 30 end; advance(2); tick(0, view(0))
check(ov("base") == "At Target", "the threat sees you too: back to Neverlose's at target")
-- V1.0: without a threat too (the nearest enemy does not see you, a flanker does): the flanker.
world.threat = nil; world.trace = function(to, from) return from == enemy2 and 30 or 0 end; advance(4); tick(0, view(0))
check(ov("base") == "Local View" and ov("offset") == norm(yaw_for(-23, 51) + 90),
      "no threat, the nearest enemy cannot see you but a flanker can: the AA turns to the flanker")
world.threat = enemy; world.trace = function() return 30 end; advance(2); tick(0, view(0))
-- V1.0 log: a chest hit on 0x41, the AA faced another enemy and 0x41 shot back at the head 0.35 s
-- later. The enemy you just shot at, still seeing you, is faced for a second.
handlers.aim_fire({ id = 950, target = 7 }); tick(0, view(0))
check(ov("base") == "Local View" and ov("offset") == norm(yaw_for(-23, 51) + 90),
      "you shot at enemy7 and it sees you (the threat sees you too): the AA turns to it")
handlers.bullet_impact({ userid = 7, x = 0, y = -500, z = 64 }); handlers.aim_fire({ id = 953, target = 7 }); tick(0, view(0)); draw()
check(contains(texts, "BRUTE 1"), "anti-brute uses the phase of the enemy you are dueling")
handlers.player_hurt({ userid = 1, attacker = 7, hitgroup = 2, dmg_health = 20, weapon = "ssg08" })
check(printed[#printed]:find("enemy7 (Standing, AA hedefi, ", 1, true) ~= nil, "its shot back lands while the AA faces it")
advance(70); tick(0, view(0))
check(ov("base") == "At Target", "a second later: back to Neverlose's at target")
handlers.aim_fire({ id = 951, target = 5 }); tick(0, view(0))
check(ov("base") == "At Target", "the enemy you shot at is the threat: at target already faces it")
world.trace = function(to, from) return from == enemy and 30 or 0 end; advance(4)
handlers.aim_fire({ id = 952, target = 7 }); tick(0, view(0))
check(ov("base") == "At Target", "the enemy you shot at does not see you: no turn")
advance(70); globals.realtime = globals.realtime + 7; tick(0)
world.trace = function(to, from) return from == enemy2 and 30 or 0 end; advance(4)
M("combo", "Yaw base"):set("Local View"); tick(0, view(0))
check(ov("base") == "Local View" and ov("offset") == yaw_for(-23, 51), "your own Local View yaw base is left alone")
M("combo", "Yaw base"):set("At Target")
M("switch", "Freestanding"):set(true); tick(0, view(0))
check(ov("fs") == true and ov("base") == "At Target", "freestanding keeps Neverlose's target")
M("switch", "Freestanding"):set(false)
M("combo", "Manual yaw"):set("Left"); tick(0, view(0))
check(ov("base") == "Local View" and ov("offset") == -90, "manual yaw unchanged")
M("combo", "Manual yaw"):set("Off")
-- Exposure uses the nearest enemy when Neverlose has no threat; two other enemies per update.
world.threat = nil; world.enemies = { enemy }
world.trace = function(to, from) return from == enemy and 30 or 0 end; advance(2); draw()
check(same_color(colors["VIS"], 150, 190, 255), "no threat: the nearest enemy's sight is checked")
local traced = {}
local e3 = new_player(true, true, vector(-500, 0, 0)); e3.index, e3.name = 13, "e3"
players[13] = e3; world.threat = enemy; world.enemies = { enemy, enemy2, e3 }
world.trace = function(to, from) traced[from] = true; return 0 end
advance(2)
check(traced[enemy] and traced[enemy2] and traced[e3], "the threat and two other enemies traced in one update")
players[13] = nil; world.enemies = { enemy }; enemy2.origin = vector(500, 0, 0)
local low = new_player(true, true, vector(500, 0, -50)); low.index, low.name = 14, "low"
players[14] = low; world.threat = nil; world.enemies = { low }; world.trace = function() return 30 end
advance(4); tick(0, view(0))
check(ov("offset") == 0, "no threat: high ground safe head against the nearest enemy")
players[14] = nil; world.enemies = { enemy }
B("Standing", "slider", "Delay randomize"):set(1)
world.trace = NO_TRACE; advance(70)
handlers.level_init(); forget()
reset_world()

-- Saved memory is written back -------------------------------------------------------------------
reset_world()
check(db.ant_a_m_memory == nil, "the forget button also clears the saved memory")
enemy.xuid = "76561198000000005"; world.threat = enemy
globals.realtime = globals.realtime + 61
ack(5, "correction")
handlers.round_start({})
local saved = db.ant_a_m_memory
check(saved ~= nil and saved.version == 1 and saved.resolver["s:76561198000000005"] ~= nil
      and #saved.resolver["s:76561198000000005"].results == 1 and saved.resolver["s:76561198000000005"].name == "enemy5"
      and saved.resolver["s:76561198000000005"].misses == 1 and saved.resolver["s:76561198000000005"].hits == nil,
      "round start writes what was learned about steam id players (with the totals)")
ack(5, "correction"); handlers.round_start({})
check(#db.ant_a_m_memory.resolver["s:76561198000000005"].results == 1, "at most once a minute on round start")
handlers.level_init()
check(#db.ant_a_m_memory.resolver["s:76561198000000005"].results == 2
      and db.ant_a_m_memory.resolver["s:76561198000000005"].states.Standing[2] == "c", "a map change writes immediately")
handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 1, dmg_health = 100, weapon = "ssg08" })
enemy2.name = "enemy7"; ack(7, "correction")
handlers.shutdown()
check(db.ant_a_m_memory.brute["s:76561198000000005"].base == 1 and db.ant_a_m_memory.brute["n:enemy7"] == nil
      and db.ant_a_m_memory.resolver["n:enemy7"] == nil, "shutdown writes; players without a steam id are not saved")
local writes = db.ant_a_m_memory
handlers.shutdown()
check(db.ant_a_m_memory == writes, "nothing new: no write")
handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 1, dmg_health = 100, weapon = "ssg08" })
handlers.shutdown()
check(db.ant_a_m_memory ~= writes and db.ant_a_m_memory.brute["s:76561198000000005"].base == 2,
      "a new learned anti-brute phase alone is written")
enemy.xuid = nil; world.threat = nil
handlers.level_init(); forget()
check(db.ant_a_m_memory == nil, "forget clears it again")
reset_world()

-- Attacker details in the hit log -------------------------------------------------------------------
reset_world()
world.enemies = { enemy, enemy2 }; world.threat = enemy
world.trace = function(to, from) return from == enemy and 30 or 0 end
advance(20)
handlers.player_hurt({ userid = 1, attacker = 5, hitgroup = 1, dmg_health = 100, weapon = "ssg08" })
local sight_time = tonumber(printed[#printed]:match("| enemy5 %(Standing, AA hedefi, gordu (%d%.%d%d)s%)$"))
check(sight_time ~= nil and sight_time >= 0.2 and sight_time <= 0.32,
      "the threat that saw you: AA target and how long it saw you (" .. tostring(sight_time) .. ")")
enemy2.m_fFlags = 0
handlers.player_hurt({ userid = 1, attacker = 7, hitgroup = 1, dmg_health = 100, weapon = "ssg08" })
check(printed[#printed]:match("| enemy7 %(Air, AA hedefi degil, gormedi%)$") ~= nil, "another enemy our traces did not see")
world.trace = function(to, from) return from == enemy2 and 30 or 0 end; advance(12)
handlers.bullet_impact({ userid = 7, x = 0, y = -500, z = 64 }); advance(12)
check(printed[#printed]:match("iska: .+| enemy7 %(Air, AA hedefi degil, gordu 0%.%d%ds%)$") ~= nil, "a flanker that saw you, in the miss log")
world.trace = NO_TRACE; advance(40)
handlers.player_hurt({ userid = 1, attacker = 7, hitgroup = 1, dmg_health = 100, weapon = "ssg08" })
check(printed[#printed]:match("| enemy7 %(Air, AA hedefi degil, gormedi%)$") ~= nil, "an old sight is not reported")
enemy2.m_fFlags = nil
handlers.level_init(); forget()
-- The anti-brute phase follows the enemy that can see you.
B("Standing", "combo", "Body yaw"):set("Static"); tick(0)
handlers.player_hurt({ userid = 1, attacker = 7, hitgroup = 1, dmg_health = 100, weapon = "ssg08" })
handlers.round_start({}); tick(0)
check(side() == false, "the threat has no learned phase")
world.trace = function(to, from) return from == enemy2 and 30 or 0 end; advance(6)
check(side() == true, "a flanker that sees you: its learned phase is applied")
world.trace = function() return 30 end; advance(4)
check(side() == false, "the threat sees you too: the threat's phase")
world.trace = NO_TRACE; advance(16)
check(side() == false, "nobody sees you: the threat's phase")
B("Standing", "combo", "Body yaw"):set("Jitter")
world.enemies = { enemy }
handlers.level_init(); forget()
reset_world()

-- Protected handlers ----------------------------------------------------------------------
M("switch", "Enable"):set(true); reset_world()
expect_handler_error = true
local broken = new_player(true, true); broken.index, broken.name = 9, "broken"
function broken:get_eye_position() error("eye unavailable") end
players[9] = broken
local before_errors = #printed
handlers.bullet_impact({ userid = 9, x = -500, y = 6, z = 64 })
handlers.bullet_impact({ userid = 9, x = -500, y = 6, z = 64 })
local error_lines = 0
for i = before_errors + 1, #printed do if printed[i]:find("bullet_impact hata verdi", 1, true) then error_lines = error_lines + 1 end end
check(error_lines == 1, "a failing handler reports its error once")
expect_handler_error = false
handlers.bullet_impact({ userid = 5, x = -500, y = 6, z = 64 }); tick(0)
check(ov("enabled") == true, "the script keeps running after a handler error")
players[9] = nil
reset_world()
world.threat = new_player(true, true, vector(500, 0, -50)); world.trace = function() return 30 end
M("switch", "Freestanding"):set(true); tick(0)
world.threat_calls = 0; tick(0); tick(0); tick(0)
check(world.threat_calls == 3, "the threat is read once per tick (" .. tostring(world.threat_calls) .. ")")
M("switch", "Freestanding"):set(false)
reset_world()
M("switch", "Enable"):set(false)

-- Disable / shutdown ---------------------------------------------------------------------
tick(0)
local any = false
for _, r in pairs(refs) do if r.ov ~= nil then any = true end end
check(not any, "disable resets every override (DT/HS included)")
M("switch", "Enable"):set(true); tick(0)
check(ov("enabled") == true and ov("dt") == true, "re-enable applies again")
handlers.shutdown()
any = false
for _, r in pairs(refs) do if r.ov ~= nil then any = true end end
check(not any, "shutdown resets every override")

lp.alive = false
tick(0); draw()
check(true, "dead player handled")

log(fails == 0 and "ALL PASSED" or ("FAILURES: " .. fails))
return out
