-- Sahte GameSense ortami (test icin). GameSense'in Lua API'sinin script'in kullandigi kismini taklit eder.
local M = { logs = {}, execs = {}, handlers = {}, delayed = {}, tick = 0, realtime = 0, menu_open = false,
    mouse = { 0, 0 }, mouse_down = false, errors = {} }

local real_print = print
function M.print(...)
    local parts = {}
    for i = 1, select("#", ...) do
        parts[#parts + 1] = tostring(select(i, ...))
    end
    local line = table.concat(parts, " ")
    M.logs[#M.logs + 1] = line
    if M.echo then
        real_print(line)
    end
end
print = M.print

---------------------------------------------------------------------------
-- UI
---------------------------------------------------------------------------
local items, by_path = {}, {}
M.items = items
local WEAPON_TYPES = { "Global", "G3SG1 / SCAR-20", "SSG 08", "AWP", "R8 Revolver", "Desert Eagle", "Pistol",
    "Zeus", "Rifle", "Shotgun", "SMG", "Machine gun" }

local function new_item(kind, tab, container, name, value, extra)
    local id = #items + 1
    local item = { id = id, kind = kind, tab = tab, container = container, name = name, value = value,
        visible = true, callbacks = {}, extra = extra or {} }
    items[id] = item
    return id
end

local function ref(tab, container, name, ...)
    local ids = { ... }
    by_path[(tab .. "|" .. container .. "|" .. name):lower()] = ids
end

-- Hotkey degeri: { mode, key, held }.
local function hotkey(tab, container, name, mode, key)
    return new_item("hotkey", tab, container, name, { mode = mode or 1, key = key or 0, held = false })
end

-- Silah grubuna bagli (scoped) ayarlar: deger secili silah grubuna gore.
local scoped = {}
M.scoped = scoped
local function scoped_item(kind, tab, container, name, default)
    local id = new_item(kind, tab, container, name, nil)
    items[id].scoped = true
    scoped[id] = {}
    for _, wt in ipairs(WEAPON_TYPES) do
        scoped[id][wt] = default
    end
    return id
end

-- Native AA
ref("AA", "Anti-aimbot angles", "Enabled", new_item("checkbox", "AA", "Anti-aimbot angles", "Enabled", false))
ref("AA", "Anti-aimbot angles", "Pitch",
    new_item("combobox", "AA", "Anti-aimbot angles", "Pitch", "Off", { options = { "Off", "Default", "Up", "Down", "Minimal", "Random", "Custom" } }),
    new_item("slider", "AA", "Anti-aimbot angles", "Pitch value", 0, { min = -89, max = 89 }))
ref("AA", "Anti-aimbot angles", "Yaw base",
    new_item("combobox", "AA", "Anti-aimbot angles", "Yaw base", "Local view", { options = { "Local view", "At targets" } }))
ref("AA", "Anti-aimbot angles", "Yaw",
    new_item("combobox", "AA", "Anti-aimbot angles", "Yaw", "Off", { options = { "Off", "180", "Spin", "Static", "180 Z", "Crosshair" } }),
    new_item("slider", "AA", "Anti-aimbot angles", "Yaw value", 0, { min = -180, max = 180 }))
ref("AA", "Anti-aimbot angles", "Yaw jitter",
    new_item("combobox", "AA", "Anti-aimbot angles", "Yaw jitter", "Off", { options = { "Off", "Offset", "Center", "Random", "Skitter" } }),
    new_item("slider", "AA", "Anti-aimbot angles", "Yaw jitter value", 0, { min = -180, max = 180 }))
ref("AA", "Anti-aimbot angles", "Body yaw",
    new_item("combobox", "AA", "Anti-aimbot angles", "Body yaw", "Off", { options = { "Off", "Opposite", "Jitter", "Static" } }),
    new_item("slider", "AA", "Anti-aimbot angles", "Body yaw value", 0, { min = -180, max = 180 }))
ref("AA", "Anti-aimbot angles", "Freestanding body yaw", new_item("checkbox", "AA", "Anti-aimbot angles", "Freestanding body yaw", false))
ref("AA", "Anti-aimbot angles", "Edge yaw", new_item("checkbox", "AA", "Anti-aimbot angles", "Edge yaw", false))
ref("AA", "Anti-aimbot angles", "Freestanding",
    new_item("checkbox", "AA", "Anti-aimbot angles", "Freestanding", false),
    hotkey("AA", "Anti-aimbot angles", "Freestanding key", 1, 0x46))
ref("AA", "Other", "Slow motion", new_item("checkbox", "AA", "Other", "Slow motion", true), hotkey("AA", "Other", "Slow motion key", 1, 0x10))
ref("AA", "Other", "On shot anti-aim", new_item("checkbox", "AA", "Other", "On shot anti-aim", false), hotkey("AA", "Other", "On shot key", 1, 0x58))
ref("RAGE", "Aimbot", "Double tap", new_item("checkbox", "RAGE", "Aimbot", "Double tap", true), hotkey("RAGE", "Aimbot", "Double tap key", 2, 0x43))
ref("RAGE", "Aimbot", "Double tap fake lag limit", new_item("slider", "RAGE", "Aimbot", "Double tap fake lag limit", 1, { min = 1, max = 10 }))
ref("RAGE", "Other", "Duck peek assist", hotkey("RAGE", "Other", "Duck peek assist", 1, 0x11))
ref("RAGE", "Other", "Quick peek assist", new_item("checkbox", "RAGE", "Other", "Quick peek assist", true), hotkey("RAGE", "Other", "Quick peek key", 1, 0x05))
ref("RAGE", "Aimbot", "Prefer safe point", scoped_item("checkbox", "RAGE", "Aimbot", "Prefer safe point", false))
ref("RAGE", "Aimbot", "Force safe point", hotkey("RAGE", "Aimbot", "Force safe point", 1, 0))
ref("RAGE", "Aimbot", "Force body aim", hotkey("RAGE", "Aimbot", "Force body aim", 1, 0))
ref("RAGE", "Aimbot", "Minimum damage", scoped_item("slider", "RAGE", "Aimbot", "Minimum damage", 20))
ref("RAGE", "Aimbot", "Minimum damage override",
    new_item("checkbox", "RAGE", "Aimbot", "Minimum damage override", false),
    hotkey("RAGE", "Aimbot", "Minimum damage override key", 1, 0),
    new_item("slider", "RAGE", "Aimbot", "Minimum damage override value", 5, { min = 0, max = 126 }))
local weapon_type_id = new_item("combobox", "RAGE", "Weapon type", "Weapon type", "Global", { options = WEAPON_TYPES })
ref("RAGE", "Weapon type", "Weapon type", weapon_type_id)
ref("MISC", "Settings", "sv_maxusrcmdprocessticks2", new_item("slider", "MISC", "Settings", "maxshift", 16, { min = 1, max = 18 }))
ref("AA", "Anti-aimbot angles", "Roll", new_item("slider", "AA", "Anti-aimbot angles", "Roll", 0, { min = -50, max = 50 }))
ref("MISC", "Miscellaneous", "Clan tag spammer", new_item("checkbox", "MISC", "Miscellaneous", "Clan tag spammer", true))
M.weapon_type_id = weapon_type_id

local function fire_callbacks(id)
    for _, fn in ipairs(items[id].callbacks) do
        fn(id)
    end
end

local function item_value(item)
    if item.scoped then
        return scoped[item.id][items[weapon_type_id].value]
    end
    return item.value
end

local function hotkey_active(v)
    if v.mode == 0 then
        return true
    elseif v.mode == 1 then
        return v.key ~= 0 and v.held
    elseif v.mode == 2 then
        return v.toggled == true
    end
    return not (v.key ~= 0 and v.held)
end
M.hotkey_active = hotkey_active

ui = {}
function ui.reference(tab, container, name)
    local ids = by_path[(tab .. "|" .. container .. "|" .. name):lower()]
    if ids == nil then
        error("unknown reference " .. tab .. " " .. container .. " " .. name)
    end
    return table.unpack(ids)
end

function ui.get(id)
    local item = items[id]
    if item == nil then
        error("ui.get: bad id " .. tostring(id))
    end
    if item.kind == "hotkey" then
        local v = item.value
        return hotkey_active(v), v.mode, v.key
    elseif item.kind == "color" then
        local c = item.value
        return c[1], c[2], c[3], c[4]
    elseif item.kind == "multiselect" then
        local out = {}
        for i, v in ipairs(item.value) do
            out[i] = v
        end
        return out
    end
    return item_value(item)
end

local MODE_INDEX = { ["Always on"] = 0, ["On hotkey"] = 1, ["Toggle"] = 2, ["Off hotkey"] = 3 }

function ui.set(id, value, ...)
    local item = items[id]
    if item == nil then
        error("ui.set: bad id " .. tostring(id))
    end
    if item.kind == "hotkey" then
        local mode = MODE_INDEX[value]
        if mode == nil then
            error("bad hotkey mode " .. tostring(value))
        end
        item.value.mode = mode
        local key = ...
        if key ~= nil then
            item.value.key = key
        end
    elseif item.kind == "color" then
        local g, b, a = ...
        item.value = { value, g, b, a }
    elseif item.kind == "checkbox" then
        if type(value) ~= "boolean" then
            error("checkbox needs boolean, got " .. type(value))
        end
        if item.scoped then
            scoped[id][items[weapon_type_id].value] = value
        else
            item.value = value
        end
    elseif item.kind == "slider" then
        if type(value) ~= "number" then
            error("slider needs number, got " .. type(value) .. " for " .. item.name)
        end
        local low, high = item.extra.min or -1e9, item.extra.max or 1e9
        value = math.max(low, math.min(high, math.floor(value + 0.5)))
        if item.scoped then
            scoped[id][items[weapon_type_id].value] = value
        else
            item.value = value
        end
    elseif item.kind == "combobox" then
        local ok = false
        for _, opt in ipairs(item.extra.options or {}) do
            if opt == value then
                ok = true
            end
        end
        if not ok then
            error("combobox " .. item.name .. " has no option " .. tostring(value))
        end
        item.value = value
    elseif item.kind == "multiselect" then
        item.value = value
    elseif item.kind == "button" or item.kind == "label" then
        item.value = value
    else
        item.value = value
    end
    fire_callbacks(id)
end

function ui.set_visible(id, visible)
    items[id].visible = visible
end

function ui.set_callback(id, fn)
    local list = items[id].callbacks
    list[#list + 1] = fn
end

local function check_unique(tab, container, name)
    for _, item in ipairs(items) do
        if item.tab == tab and item.container == container and item.name == name and item.lua then
            error("duplicate ui name: " .. name)
        end
    end
end

local function lua_item(kind, tab, container, name, value, extra)
    check_unique(tab, container, name)
    local id = new_item(kind, tab, container, name, value, extra)
    items[id].lua = true
    return id
end

function ui.new_checkbox(tab, container, name)
    return lua_item("checkbox", tab, container, name, false)
end

function ui.new_slider(tab, container, name, low, high, init, show_tooltip, unit, scale, tooltips)
    assert(type(low) == "number" and type(high) == "number", "slider bounds")
    assert(init == nil or (init >= low and init <= high), "slider init out of range: " .. name)
    return lua_item("slider", tab, container, name, init or low, { min = low, max = high })
end

function ui.new_combobox(tab, container, name, ...)
    local options = ...
    if type(options) ~= "table" then
        options = { ... }
    end
    return lua_item("combobox", tab, container, name, options[1], { options = options })
end

function ui.new_hotkey(tab, container, name, inline)
    return lua_item("hotkey", tab, container, name, { mode = 1, key = 0, held = false })
end

function ui.new_button(tab, container, name, fn)
    local id = lua_item("button", tab, container, name, nil)
    items[id].fn = fn
    return id
end

function ui.new_color_picker(tab, container, name, r, g, b, a)
    return lua_item("color", tab, container, name, { r, g, b, a })
end

function ui.new_label(tab, container, name)
    return lua_item("label", tab, container, name, nil)
end

function ui.is_menu_open()
    return M.menu_open
end

function ui.mouse_position()
    return M.mouse[1], M.mouse[2]
end

function M.find_lua(name)
    for _, item in ipairs(items) do
        if item.lua and (item.name == name or item.name:gsub("\n.*$", "") == name) then
            return item
        end
    end
    error("lua item not found: " .. name)
end

function M.press(id)
    local item = items[id]
    item.fn()
end

---------------------------------------------------------------------------
-- Dunya: oyuncular
---------------------------------------------------------------------------
M.players = {}
M.me = 1
local function player(index, data)
    data.index = index
    data.props = data.props or {}
    M.players[index] = data
    return data
end
M.player = player

entity = {}
function entity.get_local_player()
    return M.me_present ~= false and M.me or nil
end

function entity.get_players(enemies_only)
    local out = {}
    for i = 1, 64 do
        local p = M.players[i]
        if p ~= nil and p.alive and not p.dormant and (not enemies_only or p.enemy) and i ~= M.me then
            out[#out + 1] = i
        end
    end
    return out
end

function entity.is_alive(i)
    local p = M.players[i]
    return p ~= nil and p.alive == true
end

function entity.is_enemy(i)
    local p = M.players[i]
    return p ~= nil and p.enemy == true
end

function entity.is_dormant(i)
    local p = M.players[i]
    return p ~= nil and p.dormant == true
end

function entity.get_origin(i)
    local p = M.players[i]
    if p == nil then
        return nil
    end
    return p.origin[1], p.origin[2], p.origin[3]
end

local VECTOR_PROPS = { m_vecVelocity = true, m_vecOrigin = true, m_angEyeAngles = true }
function entity.get_prop(i, name, index)
    if i == "resource" then
        if name == "m_bAlive" then
            local p = M.players[index]
            return p ~= nil and p.alive and 1 or 0
        end
        return nil
    end
    if i == "rules" then
        return M.warmup and 1 or 0
    end
    if type(i) == "number" and i >= 100 then
        local w = M.weapons[i]
        return w ~= nil and w[name] or nil
    end
    local p = M.players[i]
    if p == nil then
        return nil
    end
    if name == "m_vecOrigin" then
        return p.origin[1], p.origin[2], p.origin[3]
    end
    if name == "m_flPoseParameter" then
        return p.pose or 0.5
    end
    local v = p.props[name]
    if type(v) == "table" and VECTOR_PROPS[name] then
        return v[1], v[2], v[3]
    end
    return v
end

function entity.hitbox_position(i, hitbox)
    local p = M.players[i]
    if p == nil then
        return nil
    end
    local o = p.origin
    local h = ({ [0] = 64, [3] = 40, [5] = 50 })[hitbox] or 40
    return o[1], o[2], o[3] + h
end

M.weapons = {}
function entity.get_player_weapon(i)
    local p = M.players[i]
    return p ~= nil and p.weapon or nil
end

function entity.get_classname(i)
    local w = M.weapons[i]
    return w ~= nil and w.class or "CWorld"
end

function entity.get_player_name(i)
    local p = M.players[i]
    return p ~= nil and p.name or "unknown"
end

function entity.get_steam64(i)
    local p = M.players[i]
    return p ~= nil and p.steam or 0
end

function entity.get_player_resource()
    return "resource"
end

function entity.get_game_rules()
    return "rules"
end

function entity.get_all(class)
    return {}
end

---------------------------------------------------------------------------
-- client / globals / renderer / plist / database
---------------------------------------------------------------------------
client = {}
function client.set_event_callback(name, fn)
    local list = M.handlers[name] or {}
    list[#list + 1] = fn
    M.handlers[name] = list
end

function client.unset_event_callback(name, fn) end

-- Gorus: M.visible[from_index] = true ise o oyuncu ile hedef arasinda duvar yok.
M.visible = {}
M.can_hit = {}
function client.trace_bullet(from, x1, y1, z1, x2, y2, z2)
    local target
    for i, p in pairs(M.players) do
        if p.alive and i ~= from then
            local o = p.origin
            if math.abs(o[1] - x2) < 20 and math.abs(o[2] - y2) < 20 then
                target = i
            end
        end
    end
    -- Dusman -> biz: M.visible[dusman]. Biz -> dusman: M.can_hit[dusman] (yoksa M.visible).
    local open = M.visible[from]
    if from == M.me then
        open = M.can_hit[target]
        if open == nil then
            open = M.visible[target]
        end
    end
    if not open or target == nil then
        return -1, 0
    end
    local dz = z2 - (M.players[target].origin[3])
    local damage = dz > 60 and (M.head_damage or 120) or (M.body_damage or 70)
    return target, damage
end

function client.trace_line(skip, x1, y1, z1, x2, y2, z2)
    -- Testler duvar koyabilir: M.block_fn(x1..z2) bir fraction dondururse o kullanilir.
    if M.block_fn ~= nil then
        local fraction = M.block_fn(x1, y1, z1, x2, y2, z2)
        if fraction ~= nil then
            return fraction, -1
        end
    end
    if z2 < z1 - 10 then
        return M.ground_fraction or 0.1, -1
    end
    return M.line_fraction or 1, -1
end

function client.eye_position()
    local p = M.players[M.me]
    return p.origin[1], p.origin[2], p.origin[3] + 64
end

function client.current_threat()
    return M.threat
end

function client.userid_to_entindex(userid)
    return M.userids[userid]
end
M.userids = {}

function client.latency()
    return 0.03
end

function client.camera_angles()
    return 0, M.view_yaw or 0
end

function client.key_state(key)
    return key == 1 and M.mouse_down
end

function client.screen_size()
    return 1920, 1080
end

function client.delay_call(delay, fn, ...)
    M.delayed[#M.delayed + 1] = { at = M.realtime + delay, fn = fn, args = { ... } }
end

function client.exec(cmd)
    M.execs[#M.execs + 1] = cmd
end

function client.log(...) M.print(...) end
M.clantags = {}
function client.set_clan_tag(tag)
    M.clantags[#M.clantags + 1] = tag
    M.clantag = tag
end
cvar = { cl_clanid = { get_int = function() return 0 end } }

globals = {}
function globals.tickcount() return M.tick end
function globals.realtime() return M.realtime end
function globals.curtime() return M.realtime end
function globals.frametime() return 1 / 64 end
function globals.tickinterval() return 1 / 64 end
function globals.maxplayers() return 64 end
function globals.mapname() return "de_mirage" end

M.draws = 0
renderer = {}
function renderer.text(x, y, r, g, b, a, flags, max_width, text)
    assert(type(x) == "number" and type(y) == "number", "text pos")
    assert(type(text) == "string", "text string")
    M.draws = M.draws + 1
end
function renderer.measure_text(flags, text)
    return #text * 6, 12
end
function renderer.rectangle(x, y, w, h, r, g, b, a)
    assert(type(w) == "number" and type(h) == "number", "rect size")
    M.draws = M.draws + 1
end
function renderer.triangle(...) M.draws = M.draws + 1 end
function renderer.line(...) M.draws = M.draws + 1 end

M.plist = {}
local PLIST_DEFAULTS = { ["Override safe point"] = "-", ["Override prefer body aim"] = "-", ["Force body yaw"] = false,
    ["Force body yaw value"] = 0, ["Correction active"] = true, ["Add to whitelist"] = false }
plist = {}
function plist.get(i, field)
    if PLIST_DEFAULTS[field] == nil then
        error("unknown plist field " .. field)
    end
    local t = M.plist[i]
    if t == nil or t[field] == nil then
        return PLIST_DEFAULTS[field]
    end
    return t[field]
end
function plist.set(i, field, value)
    if PLIST_DEFAULTS[field] == nil then
        error("unknown plist field " .. field)
    end
    M.plist[i] = M.plist[i] or {}
    M.plist[i][field] = value
end

M.db = {}
database = {}
function database.read(key) return M.db[key] end
function database.write(key, value) M.db[key] = value end

---------------------------------------------------------------------------
-- Olay surucu
---------------------------------------------------------------------------
function M.fire(name, e)
    for _, fn in ipairs(M.handlers[name] or {}) do
        fn(e)
    end
end

function M.cmd(fields)
    local cmd = { chokedcommands = 0, command_number = M.tick, in_jump = 0, in_use = 0, in_duck = 0, in_attack = 0,
        forwardmove = 0, sidemove = 0, in_forward = 0, in_back = 0, in_moveleft = 0, in_moveright = 0,
        yaw = M.view_yaw or 0, pitch = 0, force_defensive = false, discharge_pending = false }
    for k, v in pairs(fields or {}) do
        cmd[k] = v
    end
    return cmd
end

-- Bir tick: setup_command, paint, paint_ui ve zamanlanmis cagrilar.
function M.step(fields)
    M.tick = M.tick + 1
    M.realtime = M.realtime + 1 / 64
    local cmd = M.cmd(fields)
    M.fire("setup_command", cmd)
    -- GameSense sirasi: komut olusur (setup_command), calistirilir (run_command), tahmin edilir
    -- (predict_command). M.predict_tickbase verilirse tahmin sirasinda tickbase o deger olur (defensive).
    M.fire("run_command", cmd)
    local tb = M.players[M.me] and M.players[M.me].props.m_nTickBase
    if M.predict_tickbase ~= nil and tb ~= nil then
        M.players[M.me].props.m_nTickBase = M.predict_tickbase(tb)
    end
    M.fire("predict_command", cmd)
    if tb ~= nil then
        M.players[M.me].props.m_nTickBase = tb
    end
    M.fire("paint", {})
    M.fire("paint_ui", {})
    for i = #M.delayed, 1, -1 do
        local d = M.delayed[i]
        if M.realtime >= d.at then
            table.remove(M.delayed, i)
            d.fn(table.unpack(d.args))
        end
    end
    return cmd
end

function M.errors_in_log()
    local out = {}
    for _, line in ipairs(M.logs) do
        if line:find("hata verdi", 1, true) or line:find("cizilemedi", 1, true) or line:find("olusturulamadi", 1, true) then
            out[#out + 1] = line
        end
    end
    return out
end

table.unpack = table.unpack or unpack
return M
