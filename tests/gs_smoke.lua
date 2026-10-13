-- Nykle.win GameSense edition icin duman (smoke) testi: GameSense API'sinin sahte hali, Redis'in Lua 5.1
-- EVAL ortaminda calisir (tests/run_gs_smoke.sh). Amac: lua yuklenir mi, tick'ler ve olaylar hata vermeden
-- ("hata verdi" / "YUKLENEMEDI" satiri yok) doner mi, V1.0.22 kurallari (Safe recharge, gercek kayit
-- bekleme, govde 70+ secenegi, "gormedi" izi, sikmadi sebepleri) sahte dunyada beklendigi gibi mi.
-- ARGV[1] = script kaynagi.
local src = ARGV[1]
local out, fails = {}, 0
local function log(s) out[#out + 1] = tostring(s) end
local function check(cond, msg)
    if cond then log("PASS " .. msg) else fails = fails + 1; log("FAIL " .. msg) end
end

-------------------------------------------------------------------------------
-- Sahte dunya
-------------------------------------------------------------------------------
local W = {
    tick = 1000, interval = 1 / 64,
    lag = 0,                 -- lp m_nTickBase = tick - lag (lag 12 = DT sarji dolu)
    enemies = { 2, 3 },
    threat = 2,
    sees = { [2] = false, [3] = false }, -- dusmanin gozunden kafamiza mermi geciyor mu
    head_dmg = { [2] = 0, [3] = 0 },     -- bizim gozumuzden dusmanin kafasina
    body_dmg = { [2] = 0, [3] = 0 },     -- bizim gozumuzden dusmanin govdesine
    sim_shift = { [2] = 0, [3] = 0 },    -- dusmanin simulasyon zamani kac tick geride (sahte kayit)
    evel = { [2] = 0, [3] = 0 },         -- dusmanin x hizi
    elby = { [2] = 180, [3] = 180 },     -- dusmanin LBY'si (goz yaw 180)
    sees_ahead = { [2] = false, [3] = false }, -- 30+ birim ilerisinden (ileri bakis) kafamizi goruyor mu
    speed = 0, flags = 1, duck = 0,
    weapon_class = "CWeaponSSG08", next_attack = 0, clip = 5,
    printed = {},
}
local function now() return W.tick * W.interval end

local prints = {}
local function print(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
    prints[#prints + 1] = table.concat(parts, " ")
end
local function printed(pattern, since)
    for i = since or 1, #prints do
        if prints[i]:find(pattern, 1, true) then return prints[i], i end
    end
    return nil
end

-- Oyuncu konumlari: ben (0,0,0), dusman 2 (500,0,0), dusman 3 (0,500,0). Kafa z+70, gogus z+50, mide z+40.
local ORIGIN = { [1] = { 0, 0, 0 }, [2] = { 500, 0, 0 }, [3] = { 0, 500, 0 } }
local HITBOX_Z = { [0] = 70, [1] = 66, [2] = 40, [3] = 45, [4] = 48, [5] = 50, [6] = 52, [7] = 30, [8] = 30 }
local function who_at(x, y)
    local best, best_d = nil, 1e9
    for ent, o in pairs(ORIGIN) do
        local d = (o[1] - x) ^ 2 + (o[2] - y) ^ 2
        if d < best_d then best, best_d = ent, d end
    end
    return best_d < 200 * 200 and best or nil
end

-------------------------------------------------------------------------------
-- ui
-------------------------------------------------------------------------------
local refs_by_label = {}
local function newref(kind, label, value, items)
    local r = { kind = kind, label = label, value = value, items = items, visible = true }
    refs_by_label[#refs_by_label + 1] = r
    return r
end
local function find_ref(prefix)
    for _, r in ipairs(refs_by_label) do
        if r.label:sub(1, #prefix) == prefix then return r end
    end
    return nil
end

local ui = {}
local REFERENCE = {} -- "tab>box>name" -> { ref1, ref2, ... }
local function reference(tab, box, name, ...)
    local key = tab .. ">" .. box .. ">" .. name
    if REFERENCE[key] == nil then
        REFERENCE[key] = { ... }
    end
    return unpack(REFERENCE[key])
end
reference("AA", "Anti-aimbot angles", "Enabled", newref("checkbox", "Enabled", true))
reference("AA", "Anti-aimbot angles", "Pitch", newref("combo", "Pitch", "Off"), newref("slider", "Pitch value", 0))
reference("AA", "Anti-aimbot angles", "Yaw base", newref("combo", "Yaw base", "At targets"))
reference("AA", "Anti-aimbot angles", "Yaw", newref("combo", "Yaw", "180"), newref("slider", "Yaw offset", 0))
reference("AA", "Anti-aimbot angles", "Yaw jitter", newref("combo", "Yaw jitter", "Off"), newref("slider", "Yaw jitter offset", 0))
reference("AA", "Anti-aimbot angles", "Body yaw", newref("combo", "Body yaw", "Static"), newref("slider", "Body yaw value", 0))
reference("AA", "Anti-aimbot angles", "Freestanding body yaw", newref("checkbox", "Freestanding body yaw", false))
reference("AA", "Anti-aimbot angles", "Edge yaw", newref("checkbox", "Edge yaw", false))
reference("AA", "Anti-aimbot angles", "Freestanding", newref("checkbox", "Freestanding", false), newref("hotkey", "Freestanding key", false))
reference("AA", "Anti-aimbot angles", "Roll", newref("slider", "Roll", 0))
reference("AA", "Other", "Slow motion", newref("checkbox", "Slow motion", false), newref("hotkey", "Slow motion key", false))
reference("AA", "Other", "On shot anti-aim", newref("checkbox", "On shot anti-aim", false), newref("hotkey", "On shot anti-aim key", false))
reference("RAGE", "Aimbot", "Double tap", newref("checkbox", "Double tap", true), newref("hotkey", "Double tap key", true))
reference("RAGE", "Aimbot", "Double tap fake lag limit", newref("slider", "Double tap fake lag limit", 1))
reference("RAGE", "Other", "Duck peek assist", newref("hotkey", "Duck peek assist", false))
reference("RAGE", "Other", "Quick peek assist", newref("checkbox", "Quick peek assist", false), newref("hotkey", "Quick peek assist key", false))
reference("RAGE", "Aimbot", "Prefer safe point", newref("checkbox", "Prefer safe point", false))
reference("RAGE", "Aimbot", "Force safe point", newref("hotkey", "Force safe point", false))
reference("RAGE", "Aimbot", "Force body aim", newref("hotkey", "Force body aim", false))
reference("RAGE", "Aimbot", "Minimum damage", newref("slider", "Minimum damage", 100))
reference("RAGE", "Aimbot", "Minimum damage override", newref("checkbox", "Minimum damage override", false),
    newref("hotkey", "Minimum damage override key", false), newref("slider", "Minimum damage override value", 0))
reference("RAGE", "Aimbot", "Enabled", newref("checkbox", "Rage enabled", true))
reference("RAGE", "Aimbot", "Minimum hit chance", newref("slider", "Minimum hit chance", 55))
reference("MISC", "Settings", "sv_maxusrcmdprocessticks2", newref("slider", "maxshift", 16))
reference("MISC", "Miscellaneous", "Clan tag spammer", newref("checkbox", "Clan tag spammer", false))
reference("MISC", "Movement", "Air strafe", newref("checkbox", "Air strafe", true))
reference("AA", "Fake lag", "Enabled", newref("checkbox", "Fake lag", true))
reference("AA", "Fake lag", "Limit", newref("slider", "Fake lag limit", 14))
reference("AA", "Fake lag", "Amount", newref("combo", "Fake lag amount", "Dynamic"))

function ui.reference(tab, box, name)
    local key = tab .. ">" .. box .. ">" .. name
    if REFERENCE[key] == nil then
        error("menude yok: " .. key)
    end
    return unpack(REFERENCE[key])
end
function ui.new_checkbox(tab, box, label) return newref("checkbox", label, false) end
function ui.new_slider(tab, box, label, low, high, def) return newref("slider", label, def or low) end
function ui.new_combobox(tab, box, label, items)
    if type(items) ~= "table" then items = { items } end
    return newref("combo", label, items[1], items)
end
function ui.new_hotkey(tab, box, label) return newref("hotkey", label, false) end
function ui.new_button(tab, box, label, fn) return newref("button", label, fn) end
function ui.new_label(tab, box, label) return newref("label", label, label) end
function ui.new_color_picker(tab, box, label, r, g, b, a) return newref("color", label, { r, g, b, a }) end
function ui.get(ref)
    if type(ref) ~= "table" then error("gecersiz ref") end
    if ref.kind == "hotkey" then return ref.value == true, ref.mode or 1, ref.key or 0 end
    if ref.kind == "color" then return unpack(ref.value) end
    return ref.value
end
function ui.set(ref, a, b, c, d)
    if type(ref) ~= "table" then error("gecersiz ref") end
    if ref.kind == "hotkey" then
        -- "Always on" / "On hotkey" / "Toggle" / "Off hotkey", tus
        ref.mode = ({ ["Always on"] = 0, ["On hotkey"] = 1, ["Toggle"] = 2, ["Off hotkey"] = 3 })[a] or 1
        if b ~= nil then ref.key = b end
        ref.value = ref.mode == 0 or (ref.mode == 1 and ref.key ~= 0 and ref.held == true)
        return
    end
    if ref.kind == "color" then ref.value = { a, b, c, d } return end
    if ref.kind == "combo" and ref.items ~= nil then
        local ok = false
        for _, it in ipairs(ref.items) do if it == a then ok = true end end
        if not ok then error("combo degeri yok: " .. tostring(a)) end
    end
    if ref.kind == "slider" and type(a) ~= "number" then error("slider sayi degil") end
    if ref.kind == "checkbox" and type(a) ~= "boolean" then error("checkbox boolean degil") end
    ref.value = a
end
function ui.set_visible(ref, v) ref.visible = v end
function ui.set_callback(ref, fn) ref.callback = fn end
function ui.is_menu_open() return false end
function ui.mouse_position() return 0, 0 end

-------------------------------------------------------------------------------
-- client / entity / globals / renderer / database / plist / cvar
-------------------------------------------------------------------------------
local callbacks = {}
local client = {}
function client.set_event_callback(name, fn)
    callbacks[name] = callbacks[name] or {}
    table.insert(callbacks[name], fn)
end
local function fire(name, ...)
    for _, fn in ipairs(callbacks[name] or {}) do fn(...) end
end
function client.trace_bullet(from_ent, x1, y1, z1, x2, y2, z2)
    local target = who_at(x2, y2)
    if target == nil then return -1, 0 end
    local head = z2 >= 60
    if from_ent == 1 then
        if target == 1 then return -1, 0 end
        local d = head and W.head_dmg[target] or W.body_dmg[target]
        return (d or 0) > 0 and target or -1, d or 0
    end
    if target == 1 then
        local o = ORIGIN[from_ent]
        local moved = o ~= nil and ((x1 - o[1]) ^ 2 + (y1 - o[2]) ^ 2) >= 30 * 30
        local sees = moved and W.sees_ahead[from_ent] or W.sees[from_ent]
        return sees and 1 or -1, sees and 90 or 0
    end
    return -1, 0
end
function client.trace_line(skip, x1, y1, z1, x2, y2, z2)
    if z2 < z1 - 200 then return 0.02, -1 end -- zemin hemen altta
    local target = who_at(x2, y2)
    if target == 1 and skip ~= 1 then
        return W.sees[skip] and 1 or 0.5, W.sees[skip] and 1 or -1
    end
    return 1, -1
end
function client.current_threat() return W.threat end
function client.eye_position() return 0, 0, 64 end
function client.latency() return 0.03 end
function client.screen_size() return 1920, 1080 end
function client.userid_to_entindex(userid) return userid end
function client.system_time() return 12, 0, 0 end
function client.key_state() return false end
function client.exec() end
function client.delay_call() end
function client.set_clan_tag() end
function client.camera_angles() return 0, 0 end
function client.create_interface() return nil end

local entity = {}
function entity.get_local_player() return 1 end
function entity.get_players(enemies_only) return { 2, 3 } end
function entity.get_all() return {} end
function entity.is_alive(ent) return ent == 1 or ent == 2 or ent == 3 end
function entity.is_dormant() return false end
function entity.is_enemy(ent) return ent == 2 or ent == 3 end
function entity.get_player_name(ent) return ({ "ben", "dusman2", "dusman3" })[ent] or "?" end
function entity.get_steam64(ent) return "7656119900000000" .. tostring(ent) end
function entity.get_player_resource() return 99 end
function entity.get_game_rules() return 98 end
function entity.get_esp_data() return { flags = 0 } end
function entity.get_player_weapon(ent) return 10 + ent end
function entity.get_classname(ent)
    if ent == 11 then return W.weapon_class end
    if ent == 12 or ent == 13 then return "CWeaponSSG08" end
    return nil
end
function entity.get_origin(ent)
    local o = ORIGIN[ent]
    if o == nil then return nil end
    return o[1], o[2], o[3]
end
function entity.hitbox_position(ent, hb)
    local o = ORIGIN[ent]
    if o == nil then return nil end
    return o[1], o[2], o[3] + (HITBOX_Z[hb] or 40)
end
function entity.get_prop(ent, name, idx)
    if ent == 1 then
        if name == "m_iHealth" then return 100 end
        if name == "m_nTickBase" then return W.tick - W.lag end
        if name == "m_fFlags" then return W.flags end
        if name == "m_vecVelocity" then return W.speed, 0, 0 end
        if name == "m_flDuckAmount" then return W.duck end
        if name == "m_flNextAttack" then return 0 end
        if name == "m_iTeamNum" then return 2 end
        if name == "m_MoveType" then return 2 end
        if name == "m_bIsScoped" then return true end
        if name == "m_ArmorValue" then return 100 end
        if name == "m_flMaxspeed" then return 230 end
        if name == "m_angEyeAngles" then return 0, 0, 0 end
        if name == "m_totalHitsOnServer" then return 0 end
        if name == "m_vecViewOffset[2]" then return 64 end
        return nil
    end
    if ent == 2 or ent == 3 then
        if name == "m_iHealth" then return 100 end
        if name == "m_fFlags" then return 1 end
        if name == "m_vecVelocity" then return W.evel[ent] or 0, 0, 0 end
        if name == "m_flDuckAmount" then return 0 end
        if name == "m_flSimulationTime" then return (W.tick - W.sim_shift[ent]) * W.interval end
        if name == "m_iTeamNum" then return 3 end
        if name == "m_ArmorValue" then return 100 end
        if name == "m_flMaxspeed" then return 230 end
        if name == "m_angEyeAngles" then return 0, 180, 0 end
        if name == "m_angEyeAngles[1]" then return 180 end
        if name == "m_flLowerBodyYawTarget" then return W.elby[ent] or 180 end
        if name == "m_vecViewOffset[2]" then return 64 end
        if name == "m_flPoseParameter" then return 0.5 end
        return nil
    end
    if ent == 11 or ent == 12 or ent == 13 then
        if name == "m_iClip1" then return W.clip end
        if name == "m_flNextPrimaryAttack" then return W.next_attack end
        if name == "m_iItemDefinitionIndex" then return 40 end
        return nil
    end
    if ent == 99 then
        if name == "m_iPing" then return 20 end
        if name == "m_bAlive" then return true end
        if name == "m_szLastPlaceName" then return "BombsiteA" end
        return nil
    end
    if ent == 98 then
        if name == "m_bWarmupPeriod" then return false end
        if name == "m_totalRoundsPlayed" then return 3 end
        return nil
    end
    return nil
end

local globals = {}
function globals.tickcount() return W.tick end
function globals.realtime() return now() end
function globals.curtime() return now() end
function globals.frametime() return W.interval end
function globals.tickinterval() return W.interval end
function globals.mapname() return "de_mirage" end
function globals.maxplayers() return 64 end
function globals.chokedcommands() return 0 end

local renderer = {}
function renderer.text() end
function renderer.measure_text() return 10, 10 end
function renderer.rectangle() end
function renderer.triangle() end
function renderer.line() end
function renderer.circle() end
function renderer.gradient() end
function renderer.circle_outline() end

-- Hafiza: hava grubunda faz 1 kotu bilinsin (20 mermi, 15 kafa) -> V1.0.23 faz atlama testi.
local db = { nykle_win_gs_memory = { version = 1, brute = {}, resolver = {}, phase_groups = {
    air = { { shots = 0, hits = 0 }, { shots = 20, hits = 15 } } } } }
local database = {}
function database.read(key) return db[key] end
function database.write(key, v) db[key] = v end

local plist_store = {}
local PL_DEFAULT = { ["Override safe point"] = "-", ["Override prefer body aim"] = "-", ["Force body yaw"] = false,
    ["Force body yaw value"] = 0, ["Correction active"] = true, ["Add to whitelist"] = false }
local plist = {}
function plist.get(ent, field)
    if PL_DEFAULT[field] == nil then error("plist alani yok: " .. tostring(field)) end
    local t = plist_store[ent]
    if t == nil or t[field] == nil then return PL_DEFAULT[field] end
    return t[field]
end
function plist.set(ent, field, value)
    if PL_DEFAULT[field] == nil then error("plist alani yok: " .. tostring(field)) end
    plist_store[ent] = plist_store[ent] or {}
    plist_store[ent][field] = value
end

local righthand = { value = 1 }
local cvar = {
    cl_clanid = { get_int = function() return 0 end, set_int = function() end },
    cl_righthand = { get_int = function() return righthand.value end, set_int = function(_, v) righthand.value = v end },
}

-------------------------------------------------------------------------------
-- Yukle
-------------------------------------------------------------------------------
local env = {
    print = print, client = client, ui = ui, entity = entity, globals = globals, renderer = renderer,
    database = database, plist = plist, cvar = cvar, bit = bit,
    math = math, string = string, table = table, pairs = pairs, ipairs = ipairs, type = type, tostring = tostring,
    tonumber = tonumber, select = select, setmetatable = setmetatable, getmetatable = getmetatable, pcall = pcall,
    xpcall = xpcall, error = error, unpack = unpack, next = next, rawget = rawget, rawset = rawset, assert = assert,
    os = { clock = function() return now() end },
}
env._G = env
local fn, err = loadstring(src, "=Nykle.win.gamesense.lua")
if fn == nil then
    log("FAIL derlenemedi: " .. tostring(err))
    log("fails=1")
    return out
end
setfenv(fn, env)
local ok, run_err = pcall(fn)
check(ok, "yuklendi: " .. tostring(run_err))
check(printed("V1.0.31 (GameSense edition) yuklendi") ~= nil, "surum satiri V1.0.31")

local function errors_since(i)
    local found = {}
    for j = i, #prints do
        local p = prints[j]
        if p:find("hata verdi", 1, true) or p:find("YUKLENEMEDI", 1, true) or p:find("cizilemedi", 1, true)
            or p:find("olusturulamadi", 1, true) or p:find("kaydedilemedi", 1, true) or p:find("menude bulunamadi", 1, true) then
            found[#found + 1] = p
        end
    end
    return found
end
local errs = errors_since(1)
check(#errs == 0, "yuklenirken hata yok" .. (#errs > 0 and (": " .. errs[1]) or ""))

-------------------------------------------------------------------------------
-- Tick surucusu
-------------------------------------------------------------------------------
local cmdno = 1
local last_cmd = nil
local function tick(n)
    for _ = 1, n or 1 do
        W.tick = W.tick + 1
        cmdno = cmdno + 1
        local cmd = { command_number = cmdno, chokedcommands = 0, in_jump = 0, in_duck = 0, in_use = 0,
            in_forward = W.speed > 0 and 1 or 0, in_back = 0, in_moveleft = 0, in_moveright = 0,
            forwardmove = W.speed > 0 and 450 or 0, sidemove = 0, yaw = 0, pitch = 0, weaponselect = 0 }
        last_cmd = cmd
        fire("run_command", cmd)
        fire("predict_command", cmd)
        fire("setup_command", cmd)
        fire("net_update_end")
        if W.tick % 16 == 0 then
            fire("paint")
            fire("paint_ui")
        end
    end
end

local before = #prints + 1
fire("level_init")
fire("round_start")
tick(200)
errs = errors_since(before)
check(#errs == 0, "200 tick hatasiz" .. (#errs > 0 and (": " .. errs[1]) or ""))

-- V1.0.28: kalici sol el: ilk paint'te cl_righthand 0; oyun geri cevirse de 0'a doner; secenek kapaninca eski deger.
check(righthand.value == 0, "kalici sol el: cl_righthand 0 (" .. tostring(righthand.value) .. ")")
righthand.value = 1
tick(16)
check(righthand.value == 0, "cl_righthand geri cevrilse de 0'a doner")
local lh_ref = find_ref("Left hand (cl_righthand 0, permanent)")
check(lh_ref ~= nil and lh_ref.value == true, "Left hand secenegi var ve varsayilan acik")
lh_ref.value = false
tick(16)
check(righthand.value == 1, "secenek kapaninca senin degerin (1) geri gelir (" .. tostring(righthand.value) .. ")")
lh_ref.value = true
tick(16)
check(righthand.value == 0, "secenek acilinca yine 0")

-- Olaylar (sahte veriyle; hata vermeden donmeleri yeter).
before = #prints + 1
fire("weapon_fire", { userid = 1, weapon = "weapon_ssg08" })
fire("aim_fire", { id = 1, target = 2, hitgroup = 1, damage = 120, hit_chance = 60, backtrack = 0, x = 500, y = 0, z = 70 })
tick(2)
fire("aim_hit", { id = 1, target = 2, hitgroup = 1, damage = 120 })
fire("weapon_fire", { userid = 1, weapon = "weapon_ssg08" })
fire("aim_fire", { id = 2, target = 2, hitgroup = 1, damage = 120, hit_chance = 60, backtrack = 0, x = 500, y = 0, z = 70 })
tick(2)
fire("aim_miss", { id = 2, target = 2, hitgroup = 1, reason = "?" })
fire("bullet_impact", { userid = 2, x = 10, y = 10, z = 70 })
fire("player_hurt", { userid = 1, attacker = 2, dmg_health = 30, hitgroup = 3, weapon = "ssg08" })
fire("player_hurt", { userid = 2, attacker = 1, dmg_health = 90, hitgroup = 1, weapon = "ssg08" })
fire("player_death", { userid = 2, attacker = 1, headshot = true, penetrated = 1, weapon = "ssg08" })
fire("round_end", { winner = 2 })
fire("round_start")
tick(10)
errs = errors_since(before)
check(#errs == 0, "olaylar hatasiz" .. (#errs > 0 and (": " .. errs[1]) or ""))

-------------------------------------------------------------------------------
-- V1.0.22: gormedi izi (saldiran takip edilmiyordu; su an goruyor)
-------------------------------------------------------------------------------
before = #prints + 1
W.sees[3] = true
fire("player_hurt", { userid = 1, attacker = 3, dmg_health = 120, hitgroup = 1, weapon = "ssg08" })
local line = printed("vuruldun:", before)
check(line ~= nil and line:find("dusman3", 1, true) ~= nil, "vuruldun satiri yazildi")
check(line ~= nil and line:find("gormedi (iz: su an goruyor)", 1, true) ~= nil, "gormedi: iz su an goruyor (" .. tostring(line) .. ")")
W.sees[3] = false
before = #prints + 1
fire("player_hurt", { userid = 1, attacker = 3, dmg_health = 120, hitgroup = 1, weapon = "ssg08" })
line = printed("vuruldun:", before)
check(line ~= nil and line:find("gormedi (iz: kapali)", 1, true) ~= nil, "gormedi: iz kapali")

-------------------------------------------------------------------------------
-- V1.0.22: gercek kayit bekleme varsayilan acik; sahte kayitta whitelist, gercek kayittan sonra 3 tick daha
-------------------------------------------------------------------------------
local wait_ref = find_ref("Wait for real record")
check(wait_ref ~= nil and wait_ref.value == true, "Wait for real record varsayilan acik")
W.sees[2], W.sees[3], W.speed = false, false, 0
tick(40) -- kayit normal
check(plist.get(2, "Add to whitelist") == false, "normal kayitta whitelist yok")
W.sim_shift[2] = 10 -- defensive: simulasyon zamani 10 tick geri
tick(3)
check(plist.get(2, "Add to whitelist") == true, "sahte kayitta whitelist")
W.sim_shift[2] = 0 -- gercek kayit geldi
tick(1)
check(plist.get(2, "Add to whitelist") == true, "gercek kayittan 1 tick sonra hala whitelist")
tick(1)
check(plist.get(2, "Add to whitelist") == true, "gercek kayittan 2 tick sonra hala whitelist")
tick(2)
check(plist.get(2, "Add to whitelist") == false, "gercek kayittan 4 tick sonra whitelist kalkti")
-- Goruluyorken beklenmez.
tick(40)
W.sees[2] = true
tick(4)
W.sim_shift[2] = 10
tick(3)
check(plist.get(2, "Add to whitelist") == false, "kafani gorurken sahte kayitta beklenmez")
W.sim_shift[2] = 0
tick(40)

-------------------------------------------------------------------------------
-- V1.0.22: Safe recharge Peek'te / yururken beklemez, en fazla 0.5 sn
-------------------------------------------------------------------------------
local dt_ref = find_ref("Double tap")
check(dt_ref ~= nil, "Double tap referansi var")
W.sees[2], W.speed, W.lag = true, 0, 12 -- goruluyor, duruyor, DT sarji dolu
tick(20)
check(dt_ref.value == true, "sarj doluyken DT acik")
fire("weapon_fire", { userid = 1, weapon = "weapon_ssg08" })
W.lag = 0 -- atis: sarj bosaldi
tick(3)
check(dt_ref.value == false, "dururken goruluyorken atistan sonra Safe recharge DT'yi bekletir")
tick(36) -- toplam ~0.6 sn > 0.5
check(dt_ref.value == true, "0.5 sn sonra bekleme biter (eski sinir 1.2 sn)")
W.lag = 12
tick(20)
W.speed = 150 -- yuruyor
fire("weapon_fire", { userid = 1, weapon = "weapon_ssg08" })
W.lag = 0
tick(3)
check(dt_ref.value == true, "yururken Safe recharge beklemez")
W.speed, W.lag = 0, 12
tick(40)

-------------------------------------------------------------------------------
-- V1.0.23: dusman seni yeni gordu (peek), silahin hazir, temiz atis yok -> dururken de defensive zorlanir
-------------------------------------------------------------------------------
-- V1.0.25: dururken "Smart": 1800 birim icinde dusman varken gorunmese de zorlanir. Dusman 2 ve 3 uzaga alinir.
W.sees[2], W.sees[3], W.head_dmg[2], W.body_dmg[2], W.speed, W.lag = false, false, 0, 0, 0, 12
ORIGIN[2], ORIGIN[3] = { 2500, 0, 0 }, { 0, 2500, 0 }
tick(80) -- gorus yok, dusman uzak
check(last_cmd.force_defensive ~= true, "dusman uzakta (2500) ve gorulmuyor: dururken defensive zorlanmaz")
W.sees[2] = true
tick(2)
check(last_cmd.force_defensive == true, "uzaktaki dusman seni gordu, silah hazir: defensive zorlanir")
W.sees[2] = false
tick(40)
check(last_cmd.force_defensive ~= true, "gorus bitince zorlama biter")
W.head_dmg[2] = 300 -- temiz atis var: zorlama yok
W.sees[2] = true
tick(2)
check(last_cmd.force_defensive ~= true, "temiz atis varken defensive zorlanmaz")
W.head_dmg[2], W.sees[2] = 0, false
tick(40)
ORIGIN[2] = { 500, 0, 0 } -- yakin ama gorunmuyor
tick(3)
check(last_cmd.force_defensive == true, "V1.0.25: 500 birimde gorunmeyen dusman varken dururken defensive zorlanir")
ORIGIN[2] = { 2500, 0, 0 }
tick(40)

-------------------------------------------------------------------------------
-- V1.0.24: sniper varsayilani "Same as state" (DT); defensive'li dusmana ileri bakis kaydinin gerisi kadar
-------------------------------------------------------------------------------
local sniper_ref = find_ref("Snipers (SSG08/AWP/R8)")
check(sniper_ref ~= nil and sniper_ref.value == "Same as state", "sniper exploit varsayilani Same as state")
-- Dusman 2 100 birim/sn ile yuruyor, su anki yerinden kafamizi gormuyor, 30+ birim ilerisinden gorur.
-- Kaydi normalken ileri bakis 0.2 sn = 20 birim: gormez. Kaydi 10 tick (0.16 sn) geride: 0.36 sn = 36 birim: gorur.
-- (dusman 2 hala 2500 birimde: Smart'in yakinlik kurali devrede degil, sadece ileri bakis test edilir.)
W.evel[2], W.sees[2], W.sees_ahead[2], W.sim_shift[2] = 100, false, true, 0
tick(80)
check(last_cmd.force_defensive ~= true, "kaydi normal, 20 birim ileriden gormuyor: zorlama yok")
W.sim_shift[2] = 10
tick(3)
check(last_cmd.force_defensive == true, "kaydi 10 tick geride: ileri bakis onu kafani gorecek yere koyar, defensive zorlanir")
W.evel[2], W.sees_ahead[2], W.sim_shift[2] = 0, false, 0
tick(60)
ORIGIN[2], ORIGIN[3] = { 500, 0, 0 }, { 0, 500, 0 }
tick(10)

-------------------------------------------------------------------------------
-- V1.0.22: govde 70+ secenegi (varsayilan kapali; acilinca MD gecici 70)
-------------------------------------------------------------------------------
local md_ref = find_ref("Minimum damage")
local body_ref = find_ref("  » Body 70+ while an enemy sees you")
local pair_ref = find_ref("  » DT pair counts as lethal")
check(body_ref ~= nil and body_ref.value == false, "Body 70+ secenegi var ve varsayilan kapali")
check(pair_ref ~= nil and pair_ref.value == true, "DT pair secenegi var ve varsayilan acik")
-- "Always use recommended settings" 64 tick'te bir secenekleri varsayilana dondurur: test icin kapatilir.
local rec_ref = find_ref("Always use recommended settings")
check(rec_ref ~= nil and rec_ref.value == true, "onerilen ayarlar varsayilan acik")
rec_ref.value = false
-- V1.0.26: DT dolu, govde 86 x 2 >= 100: cift oldurucu, MD gecici 85.
W.sees[2], W.head_dmg[2], W.body_dmg[2], W.lag = true, 0, 86, 12
tick(10)
check(md_ref.value == 85, "DT cifti olduruyor (86 x 2 >= 100): MD 85 (" .. tostring(md_ref.value) .. ")")
check(printed("DT cifti olduruyor (govde 86 x 2 >= can 100), Min. damage gecici 85") ~= nil, "DT cifti satiri yazildi")
W.body_dmg[2] = 45 -- 45 x 2 < 100 ve 60'in altinda: kafa kurali
tick(10)
check(md_ref.value == 101, "govde 45: DT cifti olduremez, MD 101 (" .. tostring(md_ref.value) .. ")")
W.body_dmg[2], W.lag = 86, 0 -- DT bos: cift yok
tick(10)
check(md_ref.value == 101, "DT bosken cift sayilmaz, MD 101 (" .. tostring(md_ref.value) .. ")")
W.lag = 12
pair_ref.value = false
tick(10)
check(md_ref.value == 101, "secenek kapali: sniper kurali MD 101 (" .. tostring(md_ref.value) .. ")")
body_ref.value = true
tick(10)
check(md_ref.value == 70, "secenek acik, kafa kapali, govde 86: MD 70 (" .. tostring(md_ref.value) .. ")")
check(printed("kafa olduremiyor: govde 86 icin Min. damage gecici 70") ~= nil, "govde 70 satiri yazildi")
W.body_dmg[2] = 50
tick(10)
check(md_ref.value == 101, "govde 50: yine 101 (" .. tostring(md_ref.value) .. ")")
W.sees[2] = false
W.body_dmg[2] = 86
tick(10)
check(md_ref.value == 100, "gorulmuyorken sniper kurali yok, MD senin 100 (" .. tostring(md_ref.value) .. ")")
body_ref.value = false
pair_ref.value = true
rec_ref.value = true

-------------------------------------------------------------------------------
-- V1.0.22: sikmadi sebebi "aimbot tehdidi baska"
-------------------------------------------------------------------------------
before = #prints + 1
W.threat = 2
W.head_dmg[3], W.body_dmg[3] = 90, 70
tick(40)
line = printed("dbg sikmadi: dusman3", before)
check(line ~= nil, "dusman3 icin sikmadi satiri")
check(line ~= nil and line:find("aimbot tehdidi baska: dusman2", 1, true) ~= nil, "sebep: aimbot tehdidi baska")
W.head_dmg[3], W.body_dmg[3] = 0, 0

-------------------------------------------------------------------------------
-- V1.0.29: kendi resolver: duran dusmanda goz yaw - LBY = 50 -> ilk atistan Force body yaw +58 (lby+ kolu)
-------------------------------------------------------------------------------
local own_ref, explore_ref = find_ref("  » Own resolver (LBY"), find_ref("  » Own resolver exploration")
check(own_ref ~= nil and own_ref.value == true, "Own resolver secenegi var ve varsayilan acik")
check(explore_ref ~= nil and explore_ref.value == 15, "deneme yuzdesi varsayilan 15")
rec_ref.value = false -- onerilen ayarlar deneme yuzdesini geri yazmasin
explore_ref.value = 0
own_ref.value = false
W.sees[2], W.speed, W.flags, W.elby[2] = true, 0, 1, 130 -- goz 180, LBY 130: fark 50, taraf L
tick(20)
check(plist.get(2, "Force body yaw") == false, "kendi resolver kapali: ilk atista Force body yaw yok")
own_ref.value = true
tick(10)
check(plist.get(2, "Force body yaw") == true and plist.get(2, "Force body yaw value") == 58,
    "kendi resolver acik: lby+ kolu, Force body yaw 58 (" .. tostring(plist.get(2, "Force body yaw")) .. " / "
    .. tostring(plist.get(2, "Force body yaw value")) .. ")")
check(printed("| bizim lby+ (lby L 50") ~= nil, "kol secimi loga yazildi")
before = #prints + 1
fire("weapon_fire", { userid = 1, weapon = "weapon_ssg08" })
fire("aim_fire", { id = 7, target = 2, hitgroup = 1, damage = 120, hit_chance = 80, backtrack = 0, x = 500, y = 0, z = 70 })
tick(2)
fire("aim_hit", { id = 7, target = 2, hitgroup = 1, damage = 120 })
line = printed("atis: dusman2", before)
check(line ~= nil and line:find("| res lby+", 1, true) ~= nil, "atis satirinda kol: res lby+ (" .. tostring(line) .. ")")
before = #prints + 1
W.elby[2] = 180
tick(10)
check(plist.get(2, "Force body yaw") == true, "V1.0.31: LBY farki anlik kaybolunca kol tutulur (0.16 sn)")
W.elby[2] = 130
tick(10)
W.elby[2] = 180
tick(60)
check(plist.get(2, "Force body yaw") == true, "V1.0.31: fark arada geri geldiyse kol hala tutulur")
tick(10)
check(plist.get(2, "Force body yaw") == false, "V1.0.30: LBY farki 1 sn kesintisiz kalkinca Force body yaw birakilir")
check(printed("sn'dir yok (lby -> open): lby+ kolu birakildi", before) ~= nil, "kol birakma loga yazildi")
-- V1.0.31: sag taraf (dusman 3, LBY 230: fark -50 -> R, aci aynalanir: body yaw -58); anlik kayipta secilen taraf korunur.
W.sees[3], W.elby[3] = true, 230
tick(20)
check(plist.get(3, "Force body yaw") == true and plist.get(3, "Force body yaw value") == -58,
    "V1.0.31: sag tarafta lby+ body yaw -58 (" .. tostring(plist.get(3, "Force body yaw value")) .. ")")
W.elby[3] = 180
tick(10)
check(plist.get(3, "Force body yaw") == true and plist.get(3, "Force body yaw value") == -58,
    "V1.0.31: anlik kayipta secilen taraf (R) korunur (" .. tostring(plist.get(3, "Force body yaw value")) .. ")")
W.sees[3], W.elby[3] = false, 180
tick(80)
-- V1.0.30: hareket eden dusmanda da LBY kolu (dusman 2 100 birim/sn ile yuruyor, fark 50).
W.evel[2], W.elby[2] = 100, 130
tick(10)
check(plist.get(2, "Force body yaw") == true and plist.get(2, "Force body yaw value") == 58,
    "V1.0.30: hareketli dusmanda da lby+ (" .. tostring(plist.get(2, "Force body yaw")) .. ")")
W.evel[2], W.elby[2] = 0, 180
tick(10)

-------------------------------------------------------------------------------
-- V1.0.23: havada kotu bilinen faz 1 (hafiza: 15/20) dusman basina ilerlemede atlanir
-------------------------------------------------------------------------------
local hc_ref = find_ref("Minimum hit chance")
check(hc_ref ~= nil and hc_ref.value == 55, "yerde hit chance senin 55")
W.flags, W.speed, W.sees[2] = 0, 200, true -- havada
tick(10)
check(hc_ref.value == 40, "V1.0.27: havada sniper hit chance 40 (" .. tostring(hc_ref.value) .. ")")
before = #prints + 1
fire("player_hurt", { userid = 1, attacker = 2, dmg_health = 100, hitgroup = 1, weapon = "ssg08" })
line = printed("vuruldun:", before)
check(line ~= nil and line:find("| Air |", 1, true) ~= nil and line:find("faz 0", 1, true) ~= nil,
    "havada ilk kafa mermisi faz 0'da (" .. tostring(line) .. ")")
tick(4)
before = #prints + 1
fire("player_hurt", { userid = 1, attacker = 2, dmg_health = 100, hitgroup = 1, weapon = "ssg08" })
line = printed("vuruldun:", before)
check(line ~= nil and line:find("faz 2", 1, true) ~= nil, "ogrenilen faz 1 kotu bilindigi icin faz 2 (" .. tostring(line) .. ")")
W.flags, W.speed, W.sees[2] = 1, 0, false
tick(10)
check(hc_ref.value == 55, "yere inince hit chance geri 55 (" .. tostring(hc_ref.value) .. ")")

-------------------------------------------------------------------------------
-- Kapanis
-------------------------------------------------------------------------------
before = #prints + 1
fire("pre_config_save")
fire("shutdown")
errs = errors_since(before)
check(#errs == 0, "kapanis hatasiz" .. (#errs > 0 and (": " .. errs[1]) or ""))
check(righthand.value == 1, "kapanista cl_righthand senin degerine doner (" .. tostring(righthand.value) .. ")")
local saved = db.nykle_win_gs_memory
local arms = type(saved) == "table" and type(saved.own_res) == "table" and saved.own_res.arms or nil
check(arms ~= nil and arms["lby+"] ~= nil and arms["lby+"].shots == 1 and arms["lby+"].hits == 1,
    "kol sayimi hafizaya yazildi (lby+ 1/1)")
errs = errors_since(1)
check(#errs == 0, "hic hata satiri yok" .. (#errs > 0 and (": " .. errs[1]) or ""))

log(fails == 0 and "ALL PASSED" or ("FAILED " .. fails))
return out
