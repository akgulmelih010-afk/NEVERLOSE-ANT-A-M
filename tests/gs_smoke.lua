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
reference("RAGE", "Aimbot", "Automatic fire", newref("checkbox", "Automatic fire", false))
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
function ui.is_menu_open() return W.menu_open == true end
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
    if x1 == x2 and y1 == y2 and z2 < z1 then return 0.3, -1 end -- V1.0.35: kisa dikey iz (yurunebilir mi): zemin var
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
local execs = {}
function client.exec(cmd) execs[#execs + 1] = cmd end
-- V1.0.35: sadece konsola yazan client.color_log; satirlar ayni listeye, ayrica sayilir.
local color_logged = 0
function client.color_log(_, _, _, msg)
    color_logged = color_logged + 1
    prints[#prints + 1] = msg
end
function client.delay_call() end
function client.set_clan_tag() end
function client.camera_angles() return 0, W.cam_yaw or 0 end
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
    if ent == 98 then -- gamerules (V1.0.40: donma suresi)
        if name == "m_bFreezePeriod" then return W.freeze and 1 or 0 end
        return nil
    end
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
        if name == "m_iHealth" then return (W.ehp and W.ehp[ent]) or 100 end
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
        if name == "m_iItemDefinitionIndex" then return W.item_index or 40 end
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
    air = { { shots = 0, hits = 0 }, { shots = 20, hits = 15 } } },
    -- V1.0.32: GS kolu hafizada 40/45 (%89): salt on bilgiyle lby+ (0.62) one gecemez, UCB primi gecirir.
    own_res = { v = 1, arms = { gs = { shots = 45, hits = 40 } } } } }
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
-- V1.0.35: aspect ratio (float, set_raw_float) ve FPS boost'tan biri (int, set_raw_int).
local aspect, sky, notify, dev = { value = 0 }, { value = 1 }, { value = 8 }, { value = 1 }
local cvar = {
    cl_clanid = { get_int = function() return 0 end, set_int = function() end },
    cl_righthand = { get_int = function() return righthand.value end, set_int = function(_, v) righthand.value = v end },
    r_aspectratio = { get_float = function() return aspect.value end, set_raw_float = function(_, v) aspect.value = v end },
    r_3dsky = { get_int = function() return sky.value end, set_raw_int = function(_, v) sky.value = v end },
    con_notifytime = { get_float = function() return notify.value end, set_raw_float = function(_, v) notify.value = v end },
    developer = { get_int = function() return dev.value end, set_int = function(_, v) dev.value = v end },
}

-------------------------------------------------------------------------------
-- Yukle
-------------------------------------------------------------------------------
local files = { ["nykle_log.txt"] = "10:00:00 [Nykle.win] V1.0.1 (GameSense edition) yuklendi\n10:00:01 [Nykle.win] ESKI OTURUM SATIRI\n" }
local env = {
    print = print, client = client, ui = ui, entity = entity, globals = globals, renderer = renderer,
    database = database, plist = plist, cvar = cvar, bit = bit,
    math = math, string = string, table = table, pairs = pairs, ipairs = ipairs, type = type, tostring = tostring,
    tonumber = tonumber, select = select, setmetatable = setmetatable, getmetatable = getmetatable, pcall = pcall,
    xpcall = xpcall, error = error, unpack = unpack, next = next, rawget = rawget, rawset = rawset, assert = assert,
    os = { clock = function() return now() end },
    -- V1.0.41: log dosyasi. Onceki surumun oturumu dosyada: yeni surumde atilmali.
    readfile = function(path) return files[path] end,
    writefile = function(path, text) files[path] = text end,
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
check(printed("V1.0.47 (GameSense edition) yuklendi") ~= nil, "surum satiri V1.0.47")
do
    local px, py, ps = find_ref("  » Panel position X"), find_ref("  » Panel position Y"), find_ref("  » Panel size")
    check(px ~= nil and px.value == 560 and py.value == 380 and ps.value == 160,
        "V1.0.39: resolver paneli varsayilan buyuk (%160), ortanin sag ustunde (560 / 380)")
end

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
-- V1.0.37: otomatik AFK eski bolumleri bozmasin (8 sn tusa basilmiyor); kendi bolumunde acilir.
local auto_ref = find_ref("  » Auto AFK (no input 8 s after spawn)")
if auto_ref ~= nil then auto_ref.value = false end
-- V1.0.42: defensive A/B testi eski bolumleri round sayisina bagli yapmasin; kendi bolumunde acilir.
local ab_ref = find_ref("Defensive A/B test (even rounds: no forced defensive)")
check(ab_ref ~= nil and ab_ref.value == false, "V1.0.43: A/B testi varsayilan kapali")
-- V1.0.43: gorulunce zorlanan defensive varsayilan kapali (A/B sonucu); eski Smart bolumleri icin acilir.
local force_ref = find_ref("Force defensive when seen / near (Smart)")
check(force_ref ~= nil and force_ref.value == true, "V1.0.45: gorulunce defensive zorlama yine varsayilan acik (V1.0.33 gibi)")
-- "Always use recommended settings" (64 tick'te bir varsayilana dondurur) eski bolumlerde kapali.
local rec_ref = find_ref("Always use recommended settings")
check(rec_ref ~= nil and rec_ref.value == true, "onerilen ayarlar varsayilan acik")
rec_ref.value = false
if force_ref ~= nil then force_ref.value = true end
-- V1.0.45: rastgele anti-brute sirasi ve defensive bekleme suresi eski (deterministik) bolumleri bozmasin; kendi
-- bolumlerinde test edilir.
local random_ref, cooldown_ref = find_ref("  » Random anti-brute order"), find_ref("  » Re-arm cooldown (let DT refill after defensive)")
check(random_ref ~= nil and random_ref.value == true and cooldown_ref ~= nil and cooldown_ref.value == true,
    "V1.0.45: rastgele anti-brute sirasi ve defensive bekleme suresi varsayilan acik")
random_ref.value, cooldown_ref.value = false, false
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
-- V1.0.35: egik yururken (ve egik Peek'te) goruluyorsan atistan sonra sarj bekletilir: egikken DT yarim sarjda
-- gelen mermilerin %55'i kafaydi, dolu / 0'da %17. V1.0.45: secenek varsayilan kapali; burada acilarak test edilir.
local crouch_ref = find_ref("  » Also while crouched (peek / crouch move)")
check(crouch_ref ~= nil and crouch_ref.value == false, "V1.0.45: egik sarj bekleme secenegi var, varsayilan kapali")
crouch_ref.value = true
W.speed, W.duck = 150, 1
tick(10)
fire("weapon_fire", { userid = 1, weapon = "weapon_ssg08" })
W.lag = 0
tick(3)
check(dt_ref.value == false, "V1.0.35: egik yururken goruluyorken atistan sonra sarj bekletilir")
tick(36)
check(dt_ref.value == true, "V1.0.35: egikken de en fazla 0.5 sn")
W.lag = 12
tick(10)
crouch_ref.value = false
fire("weapon_fire", { userid = 1, weapon = "weapon_ssg08" })
W.lag = 0
tick(3)
check(dt_ref.value == true, "V1.0.35: secenek kapaliyken egik yururken beklemez (V1.0.22)")
crouch_ref.value = true
W.lag = 12
tick(10)
-- Havada egikken (Air crouch) bekleme yok: havada teleport / air lag icin sarj gerekir.
W.flags, W.speed = 0, 200
tick(5)
fire("weapon_fire", { userid = 1, weapon = "weapon_ssg08" })
W.lag = 0
tick(3)
check(dt_ref.value == true, "V1.0.35: havada egikken sarj bekletilmez")
W.flags, W.speed, W.duck, W.lag = 1, 0, 0, 12
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
-- V1.0.37: Clean shot yine varsayilan acik (V1.0.36'da kapaliyken defensive bitislerinde DT yeniden sarj oldu).
check(last_cmd.force_defensive ~= true, "temiz atis varken defensive zorlanmaz")
local clean_ref = find_ref("Clean shot (no lag while shooting)")
check(clean_ref ~= nil and clean_ref.value == true, "V1.0.37: Clean shot varsayilan acik")
clean_ref.value = false
tick(2)
check(last_cmd.force_defensive == true, "Clean shot kapaliyken temiz atis varken de defensive zorlanir")
clean_ref.value = true
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
check(pair_ref ~= nil and pair_ref.value == true, "V1.0.45: DT pair secenegi yine var ve varsayilan acik")
-- V1.0.45 (V1.0.33 gibi): DT dolu, govde 86 x 2 >= 100: cift oldurucu, MD gecici 85.
W.sees[2], W.head_dmg[2], W.body_dmg[2], W.lag = true, 0, 86, 12
tick(10)
check(md_ref.value == 85, "V1.0.45: DT cifti olduruyor (86 x 2 >= 100): MD 85 (" .. tostring(md_ref.value) .. ")")
check(printed("DT cifti olduruyor (govde 86 x 2 >= can 100), Min. damage gecici 85") ~= nil, "V1.0.45: DT cifti satiri yazildi")
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
-- V1.0.32: karar dusman basina: dusman yurumeye gecince (Moving hipotezi) kol yeni karar verilmeden tasinir.
before = #prints + 1
W.evel[2] = 100
tick(10)
check(plist.get(2, "Force body yaw") == true and plist.get(2, "Force body yaw value") == 58
    and printed("| bizim lby+", before) == nil,
    "V1.0.32: kol durum degisince (Standing -> Moving) yeni karar olmadan tasinir (" .. tostring(plist.get(2, "Force body yaw")) .. ")")
W.evel[2] = 0
tick(10)
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
check(printed("sn'dir yok (lby -> open): lby+ kolu birakildi", before) ~= nil, "V1.0.30: LBY farki 1 sn kesintisiz kalkinca lby+ kolu birakilir (loga yazildi)")
-- V1.0.33: taraf bilgisi yok ama desen statik -> abs+ kolu (dogrudan +58), atis "res abs+" ile etiketlenir.
check(plist.get(2, "Force body yaw") == true and plist.get(2, "Force body yaw value") == 58
    and printed("| bizim abs+ (statik desync, taraf bilgisi yok) body yaw 58", before) ~= nil,
    "V1.0.33: statik dusmanda taraf bilgisi yokken abs+ kolu (" .. tostring(plist.get(2, "Force body yaw value")) .. ")")
before = #prints + 1
fire("weapon_fire", { userid = 1, weapon = "weapon_ssg08" })
fire("aim_fire", { id = 8, target = 2, hitgroup = 1, damage = 120, hit_chance = 80, backtrack = 0, x = 500, y = 0, z = 70 })
tick(2)
fire("aim_hit", { id = 8, target = 2, hitgroup = 1, damage = 120 })
line = printed("atis: dusman2", before)
check(line ~= nil and line:find("| res abs+", 1, true) ~= nil, "V1.0.33: atis satirinda res abs+ (" .. tostring(line) .. ")")
-- V1.0.34: kafaya nisan alinip gogse giden isabet kolun basarisi sayilmaz (hafizada abs+ 1/1 kalmali, bkz. kapanis).
fire("weapon_fire", { userid = 1, weapon = "weapon_ssg08" })
fire("aim_fire", { id = 9, target = 2, hitgroup = 1, damage = 120, hit_chance = 80, backtrack = 0, x = 500, y = 0, z = 70 })
tick(2)
fire("aim_hit", { id = 9, target = 2, hitgroup = 3, damage = 72 })
line = printed("atis: dusman2", before)
tick(2)
-- V1.0.34: kendi kolumuz resolver iskasi alirsa brute dongusu baslamaz (eskiden tek iskada "body yaw .. denenecek").
before = #prints + 1
fire("weapon_fire", { userid = 1, weapon = "weapon_ssg08" })
fire("aim_fire", { id = 10, target = 2, hitgroup = 1, damage = 120, hit_chance = 80, backtrack = 0, x = 500, y = 0, z = 70 })
tick(2)
fire("aim_miss", { id = 10, target = 2, hitgroup = 1, reason = "?" })
line = printed("atis: dusman2", before)
check(line ~= nil and line:find("| res abs+", 1, true) ~= nil and line:find("iska", 1, true) ~= nil,
    "V1.0.34 kurulum: abs+ kolunda resolver iskasi (" .. tostring(line) .. ")")
check(printed("denenecek", before) == nil, "V1.0.34: kol iskasi brute dongusunu baslatmaz (" .. tostring(printed("denenecek", before)) .. ")")
-- V1.0.31: sag taraf (dusman 3, LBY 230: fark -50 -> R, aci aynalanir: body yaw -58); anlik kayipta secilen taraf korunur.
W.sees[3], W.elby[3] = true, 230
tick(80) -- dusman 3 daha once statik + acikta gorulmustu (abs+ karari olabilir): 1 sn'de birakilir, lby+ secilir
check(plist.get(3, "Force body yaw") == true and plist.get(3, "Force body yaw value") == -58,
    "V1.0.31: sag tarafta lby+ body yaw -58 (" .. tostring(plist.get(3, "Force body yaw value")) .. ")")
W.elby[3] = 180
tick(10)
check(plist.get(3, "Force body yaw") == true and plist.get(3, "Force body yaw value") == -58,
    "V1.0.31: anlik kayipta secilen taraf (R) korunur (" .. tostring(plist.get(3, "Force body yaw value")) .. ")")
W.sees[3], W.elby[3] = false, 180
tick(80)
-- V1.0.30: hareket eden dusmanda da LBY kolu (dusman 2 100 birim/sn ile yuruyor, fark 50).
before = #prints + 1
W.evel[2], W.elby[2] = 100, 130
tick(80) -- abs+ kolu (open) 1 sn sonra birakilir, LBY bilgisiyle lby+ secilir
check(plist.get(2, "Force body yaw") == true and plist.get(2, "Force body yaw value") == 58
    and printed("| bizim lby+ (lby L 50", before) ~= nil,
    "V1.0.30: hareketli dusmanda da lby+ (" .. tostring(plist.get(2, "Force body yaw")) .. ")")
W.evel[2], W.elby[2] = 0, 180
tick(10)

-------------------------------------------------------------------------------
-- V1.0.23: havada kotu bilinen faz 1 (hafiza: 15/20) dusman basina ilerlemede atlanir
-------------------------------------------------------------------------------
local hc_ref = find_ref("Minimum hit chance")
check(hc_ref ~= nil and hc_ref.value == 55, "yerde hit chance senin 55")
-- V1.0.45: bu bolum deterministik faz sirasini test eder: onerilen ayarlar kapali, rastgele sira kapali.
rec_ref.value, random_ref.value = false, false
W.flags, W.speed, W.sees[2] = 0, 200, true -- havada
tick(10)
check(hc_ref.value == 55, "V1.0.47: havada sniper hit chance varsayilan dokunulmaz, senin 55 (" .. tostring(hc_ref.value) .. ")")
do
    local air_ref = find_ref("In-air hit chance (snipers, 0 = off)")
    check(air_ref ~= nil and air_ref.value == 0, "V1.0.47: In-air hit chance varsayilan 0")
    air_ref.value = 40; tick(2)
    check(hc_ref.value == 40, "V1.0.27: elle 40 secilince havada 40 (" .. tostring(hc_ref.value) .. ")")
    air_ref.value = 0; tick(2)
    check(hc_ref.value == 55, "0'a geri alininca havada 55 (" .. tostring(hc_ref.value) .. ")")
end
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
rec_ref.value = true

-------------------------------------------------------------------------------
-- V1.0.45 (V1.0.33 gibi): kafa beklerken olum ogrenilir, o dusmana karsi sniper kurali gevser (senin MD'n yazilir).
-------------------------------------------------------------------------------
W.sees[2], W.head_dmg[2], W.body_dmg[2] = true, 0, 45
tick(10)
check(md_ref.value == 101, "V1.0.45 kurulum: sniper kurali, MD 101 (" .. tostring(md_ref.value) .. ")")
before = #prints + 1
fire("player_death", { userid = 1, attacker = 2, headshot = true, penetrated = 0, weapon = "ssg08" })
tick(10)
check(printed("ogrenildi:", before) ~= nil, "V1.0.45: kafa beklerken olum ogrenilir (V1.0.33 gibi)")
check(md_ref.value == 100, "V1.0.45: o dusmana karsi sniper kurali gevser, senin MD'n 100 (" .. tostring(md_ref.value) .. ")")
W.sees[2] = false
tick(10)

-------------------------------------------------------------------------------
-- V1.0.35: kimse seni gormezken scout'ta Body Aim Prefer (senin Min. damage'in 90+ iken); daha dusukse Default
-------------------------------------------------------------------------------
check(md_ref.value == 100 and plist.get(2, "Override prefer body aim") == "On",
    "V1.0.35: gorulmuyorken scout, MD 100: prefer body On (" .. tostring(plist.get(2, "Override prefer body aim")) .. ")")
md_ref.value = 50
tick(10)
check(plist.get(2, "Override prefer body aim") == "Off",
    "V1.0.35: senin MD 50: eski davranis Off (" .. tostring(plist.get(2, "Override prefer body aim")) .. ")")
md_ref.value = 100
tick(10)

-------------------------------------------------------------------------------
-- V1.0.35: aspect ratio 4:3 ve FPS boost varsayilan acik; kapatinca geri
-------------------------------------------------------------------------------
check(math.abs(aspect.value - 4 / 3) < 0.001 and sky.value == 0,
    "V1.0.35: aspect ratio 4:3 ve r_3dsky 0 (" .. tostring(aspect.value) .. ", " .. tostring(sky.value) .. ")")
local aspect_ref, boost_ref = find_ref("Aspect ratio"), find_ref("FPS boost (shadows / 3D sky / post-process off)")
check(aspect_ref ~= nil and boost_ref ~= nil, "V1.0.35: Aspect ratio ve FPS boost menude")
check(type(db.nykle_win_gs_cvars) == "table" and db.nykle_win_gs_cvars.r_aspectratio == 0,
    "V1.0.40: orijinal cvar degerleri veritabaninda (cokmede geri yazilabilsin)")
aspect_ref.value, boost_ref.value = "Off", false
tick(70)
check(aspect.value == 0 and sky.value == 1, "V1.0.35: kapatinca senin degerlerin geri (" .. tostring(aspect.value) .. ", " .. tostring(sky.value) .. ")")
aspect_ref.value, boost_ref.value = "4:3", true
tick(70)
check(math.abs(aspect.value - 4 / 3) < 0.001 and sky.value == 0, "V1.0.35: yeniden acilinca 4:3 ve r_3dsky 0")
-- V1.0.35: loglar sadece konsola (color_log), ekranin sol ust bildirimi kapali; kapatinca print ve eski deger.
check(color_logged > 50 and notify.value == 0, "V1.0.35: satirlar color_log ile (" .. color_logged .. "), con_notifytime 0 (" .. tostring(notify.value) .. ")")
check(dev.value == 0, "V1.0.38: sessiz logda developer 0 (sol ust bildirim alani cizilmez) (" .. tostring(dev.value) .. ")")
local quiet_ref = find_ref("Logs only in console + file (not on screen)")
check(quiet_ref ~= nil and quiet_ref.value == true, "V1.0.35: sessiz log secenegi var, varsayilan acik")
quiet_ref.value = false
tick(70)
local before_color = color_logged
fire("weapon_fire", { userid = 1, weapon = "weapon_ssg08" })
fire("aim_fire", { id = 30, target = 2, hitgroup = 1, damage = 120, hit_chance = 80, backtrack = 0, x = 500, y = 0, z = 70 })
tick(2)
fire("aim_hit", { id = 30, target = 2, hitgroup = 1, damage = 120 })
check(color_logged == before_color and notify.value == 8, "V1.0.35: kapatinca print ile yazilir, con_notifytime senin degerin (" .. tostring(notify.value) .. ")")
check(dev.value == 1, "V1.0.38: kapatinca developer senin degerin (" .. tostring(dev.value) .. ")")
-- Oyundaki durum: con_notifytime Lua'dan okunamiyor (gelistirici cvar'i): konsol komutuyla 0, kapatinca 8.
local notify_cvar = cvar.con_notifytime
cvar.con_notifytime = nil
local function exec_seen(text) for _, c in ipairs(execs) do if c == text then return true end end return false end
quiet_ref.value = true
tick(70)
check(exec_seen("con_notifytime 0"), "V1.0.38: okunamayan con_notifytime konsol komutuyla 0")
quiet_ref.value = false
tick(70)
check(exec_seen("con_notifytime 8"), "V1.0.38: kapatinca con_notifytime 8 (varsayilan)")
cvar.con_notifytime = notify_cvar
quiet_ref.value = true
tick(70)

-------------------------------------------------------------------------------
-- V1.0.35: AFK modu: AI peek burada, 3 sn'de bir sag / sol adim, DT + otomatik ates
-------------------------------------------------------------------------------
local afk_ref, fire_ref = find_ref("AFK mode (AI peek here + strafe, full exploits)"), find_ref("Automatic fire")
check(afk_ref ~= nil and afk_ref.value == false, "V1.0.35: AFK modu var, varsayilan kapali")
W.sees[2], W.sees[3], W.speed, W.lag = false, false, 0, 12
before = #prints + 1
afk_ref.value = true
tick(10)
check(printed("afk modu acik", before) ~= nil, "V1.0.35: AFK acilinca loga yazilir")
check(fire_ref.value == true and dt_ref.value == true, "V1.0.35: AFK'da otomatik ates ve DT acik ("
    .. tostring(fire_ref.value) .. ", " .. tostring(dt_ref.value) .. ")")
-- Dusmanlar uzakta ve gormuyor (Smart'in "yakinda dusman" penceresi yok): AFK yine de defensive zorlar.
ORIGIN[2], ORIGIN[3] = { 5000, 0, 0 }, { 0, 5000, 0 }
tick(10)
check(last_cmd.force_defensive == true, "V1.0.35: AFK'da DT doluyken defensive her tick zorlanir (dusman uzakta olsa da)")
ORIGIN[2], ORIGIN[3] = { 500, 0, 0 }, { 0, 500, 0 }
tick(40)
-- AFK'da kimse gormuyorken sahte kayit beklemesi yine calisir (Peek tusu "basili" sayilmaz).
W.sim_shift[2] = 10
tick(3)
check(plist.get(2, "Add to whitelist") == true, "V1.0.35: AFK'da sahte kayitta bekleme (whitelist) calisir")
W.sim_shift[2] = 0
tick(40)
ORIGIN[2], ORIGIN[3] = { 5000, 0, 0 }, { 0, 5000, 0 }
tick(10)
afk_ref.value = false
tick(10)
check(last_cmd.force_defensive ~= true, "V1.0.35 kurulum: AFK kapaliyken uzak dusmanda defensive zorlanmaz")
afk_ref.value = true
tick(10)
ORIGIN[2], ORIGIN[3] = { 500, 0, 0 }, { 0, 500, 0 }
tick(5)
local side1 = last_cmd.sidemove
tick(200) -- 3 sn'den fazla
local side2 = last_cmd.sidemove
check(side1 ~= 0 and side2 ~= 0 and (side1 > 0) ~= (side2 > 0),
    "V1.0.35: AFK'da dusmana dik sag / sol adim, 3 sn sonra yon degisir (" .. tostring(side1) .. " -> " .. tostring(side2) .. ")")
W.speed = 150 -- sen tusa basinca AFK adimi durur
tick(5)
check(last_cmd.sidemove == 0, "V1.0.35: sen hareket edince AFK adimi karismaz (" .. tostring(last_cmd.sidemove) .. ")")
W.speed = 0
before = #prints + 1
afk_ref.value = false
tick(10)
check(printed("afk modu kapali", before) ~= nil and fire_ref.value == false, "V1.0.35: AFK kapatinca otomatik ates senin degerine doner")

-------------------------------------------------------------------------------
-- V1.0.36: sarj pozu (atistan sonra DT yarim sarjda statik + freestanding body), loglar, faz ogrenmesi
-------------------------------------------------------------------------------
do
    local fs_ref, pose_ref = find_ref("Freestanding body yaw"), find_ref("Recharge pose (static + freestanding body while DT charges)")
    check(pose_ref ~= nil and pose_ref.value == false, "V1.0.41: sarj pozu secenegi var, varsayilan kapali (donukken statik desync %56 kafa)")
    rec_ref.value, random_ref.value, cooldown_ref.value = false, false, false -- onerilen ayarlar pozu geri kapatmasin
    pose_ref.value = true
    W.sees[2], W.lag, W.speed = true, 12, 150 -- yururken (Safe recharge beklemez, DT hemen dolmaya baslar)
    tick(200)
    check(fs_ref.value == false, "V1.0.36 kurulum: DT dolu, freestanding body kapali")
    fire("weapon_fire", { userid = 1, weapon = "weapon_ssg08" })
    W.lag = 5
    tick(3)
    check(fs_ref.value == true, "V1.0.36: atistan sonra DT yarim sarjda statik + freestanding body (sarj pozu)")
    local line
    before = #prints + 1
    fire("bullet_impact", { userid = 2, x = 0, y = 0, z = 64 })
    tick(70)
    line = printed("iska:", before)
    check(line ~= nil and line:find("sarj pozu", 1, true) ~= nil and line:find("| silah ", 1, true) ~= nil
        and line:find("sh ", 1, true) ~= nil,
        "V1.0.36: iska satirinda sarj pozu, sarj tick'i ve dusmanin silahi (" .. tostring(line) .. ")")
    W.lag = 12
    tick(10)
    check(fs_ref.value == false, "V1.0.36: DT dolunca poz biter")
    pose_ref.value = false
    fire("weapon_fire", { userid = 1, weapon = "weapon_ssg08" })
    W.lag = 5
    tick(3)
    check(fs_ref.value == false, "V1.0.36: secenek kapaliyken poz yok")
    W.lag = 12
    tick(100)
    -- Yarim sarjda yenen kafa faz ogrenmesine sayilmaz: round basindaki faz (dusmanin ogrenilmis tabani) degismez.
    local function round_phase()
        fire("round_start")
        tick(10)
        local b = #prints + 1
        fire("player_hurt", { userid = 1, attacker = 2, dmg_health = 1, hitgroup = 3, weapon = "ssg08" })
        local l = printed("vuruldun:", b)
        return l ~= nil and l:match("| faz (%d+) |") or nil
    end
    local base_before = round_phase()
    tick(100)
    W.lag = 5
    fire("weapon_fire", { userid = 1, weapon = "weapon_ssg08" })
    tick(3)
    fire("player_hurt", { userid = 1, attacker = 2, dmg_health = 1, hitgroup = 1, weapon = "ssg08" })
    W.lag = 12
    tick(100)
    local base_after = round_phase()
    check(base_before ~= nil and base_after ~= nil and base_before ~= base_after,
        "V1.0.45: kafa (yarim sarjda da) dusmanin faz tabanini tasir, V1.0.33 gibi (" .. tostring(base_before) .. " -> " .. tostring(base_after) .. ")")
    W.sees[2], W.speed = false, 0
    tick(10)
end

-------------------------------------------------------------------------------
-- V1.0.37: otomatik AFK (dogduktan / round basindan sonra 8 sn tusa basmazsan)
-------------------------------------------------------------------------------
do
    local afk_ref = find_ref("AFK mode (AI peek here + strafe, full exploits)")
    local fire_ref = find_ref("Automatic fire")
    check(auto_ref ~= nil, "V1.0.37: otomatik AFK secenegi var")
    auto_ref.value = true
    afk_ref.value = false
    W.sees[2], W.sees[3], W.speed = false, false, 0
    before = #prints + 1
    fire("round_start")
    tick(64 * 7)
    check(fire_ref.value ~= true, "V1.0.37: 7 sn hareketsiz: henuz AFK degil")
    tick(64 * 2)
    check(printed("otomatik afk: dogduktan sonra 8 sn", before) ~= nil and fire_ref.value == true,
        "V1.0.37: 8 sn hareketsiz: AFK kendiliginden acildi (otomatik ates " .. tostring(fire_ref.value) .. ")")
    W.speed = 150 -- tusa bastin
    tick(3)
    W.speed = 0
    tick(64 * 10)
    check(printed("otomatik afk kapandi: tus", before) ~= nil and fire_ref.value ~= true,
        "V1.0.37: tusa basinca kapanir ve bu dogusta yeniden acilmaz")
    fire("round_start")
    tick(64 * 9)
    check(fire_ref.value == true, "V1.0.37: yeni roundda yine 8 sn hareketsiz: AFK acik")
    auto_ref.value = false
    tick(10)
    check(fire_ref.value ~= true, "V1.0.37: secenek kapatilinca otomatik AFK kapanir")
    -- V1.0.40: fare (kamera) hareketi otomatik AFK'yi kapatir.
    auto_ref.value = true
    fire("round_start")
    tick(64 * 9)
    check(fire_ref.value == true, "V1.0.40 kurulum: otomatik AFK acik")
    before = #prints + 1
    W.cam_yaw = 30
    tick(3)
    check(printed("otomatik afk kapandi: fare", before) ~= nil and fire_ref.value ~= true, "V1.0.40: fareyi oynatinca otomatik AFK kapanir")
    W.cam_yaw = 0
    tick(3)
    -- Donma suresindeki tus AFK'yi bozmaz: sadece sayac sifirlanir, donma bitince 8 sn sonra acilir.
    fire("round_start")
    W.freeze = true
    tick(10)
    W.speed = 150
    tick(3)
    W.speed = 0
    tick(64)
    W.freeze = false
    tick(64 * 9)
    check(fire_ref.value == true, "V1.0.40: donma suresinde tusa basmak otomatik AFK'yi bozmaz")
    -- Menu acikken sayac ilerlemez.
    fire("round_start")
    W.menu_open = true
    tick(64 * 10)
    check(fire_ref.value ~= true, "V1.0.40: menu acikken otomatik AFK acilmaz")
    W.menu_open = false
    tick(64 * 9)
    check(fire_ref.value == true, "V1.0.40: menu kapaninca 8 sn sonra acilir")
    -- Onerilen ayarlar acikken elle acilan AFK kapanmaz (eskiden 1 sn icinde kapaniyordu).
    auto_ref.value = false
    afk_ref.value = true
    rec_ref.value = true
    tick(200)
    check(afk_ref.value == true, "V1.0.40: 'Always use recommended settings' acikken AFK acik kalir")
    rec_ref.value = false
    random_ref.value, cooldown_ref.value, force_ref.value = false, false, true -- onerilen ayarlar varsayilana dondurdu
    afk_ref.value = false
    tick(10)
end

-------------------------------------------------------------------------------
-- V1.0.39: ayrintili log: saldirana gore AA yonu, hayat ozetinde yarim sarj sureleri
-------------------------------------------------------------------------------
do
    W.sees[2], W.speed, W.lag = true, 150, 12
    tick(20)
    before = #prints + 1
    fire("player_hurt", { userid = 1, attacker = 2, dmg_health = 20, hitgroup = 3, weapon = "ssg08" })
    local line = printed("vurulma-detay:", before)
    check(line ~= nil and line:find("| aa yon ", 1, true) ~= nil,
        "V1.0.39: vurulma-detay satirinda saldirana gore AA yonu (" .. tostring(line) .. ")")
    fire("weapon_fire", { userid = 1, weapon = "weapon_ssg08" })
    W.lag = 5
    tick(20)
    W.lag = 12
    tick(10)
    before = #prints + 1
    fire("round_start")
    line = printed("sen ozeti:", before)
    check(line ~= nil and line:match("yarim sarj (%d+) tick") ~= nil and tonumber(line:match("yarim sarj (%d+) tick")) > 0,
        "V1.0.39: hayat ozetinde yarim sarj tick'leri (" .. tostring(line) .. ")")
    W.sees[2], W.speed = false, 0
    tick(10)
end

-------------------------------------------------------------------------------
-- V1.0.42: defensive A/B testi (tek round A: normal, cift round B: zorlanan defensive yok)
-------------------------------------------------------------------------------
do
    check(ab_ref ~= nil, "V1.0.42: defensive A/B testi secenegi var")
    ab_ref.value = true
    W.sees[2], W.speed, W.lag = true, 0, 12
    local function round_arm()
        local b = #prints + 1
        fire("round_start")
        tick(20)
        local l = printed("defensive testi:", b)
        return l ~= nil and (l:find("bu round B", 1, true) and "B" or "A") or nil
    end
    local arm1 = round_arm()
    local forced1 = last_cmd.force_defensive == true
    local arm2 = round_arm()
    local forced2 = last_cmd.force_defensive == true
    check(arm1 ~= nil and arm2 ~= nil and arm1 ~= arm2, "V1.0.42: kollar round round degisir (" .. tostring(arm1) .. ", " .. tostring(arm2) .. ")")
    check((arm1 == "A") == forced1 and (arm2 == "A") == forced2,
        "V1.0.42: A'da gorulurken defensive zorlanir, B'de zorlanmaz (" .. tostring(forced1) .. ", " .. tostring(forced2) .. ")")
    before = #prints + 1
    fire("player_hurt", { userid = 1, attacker = 2, dmg_health = 5, hitgroup = 3, weapon = "ssg08" })
    local line = printed("vuruldun:", before)
    check(line ~= nil and line:find("test " .. arm2, 1, true) ~= nil, "V1.0.42: vuruldun satirinda test kolu (" .. tostring(line) .. ")")
    ab_ref.value = false
    W.sees[2] = false
    tick(10)
end

-------------------------------------------------------------------------------
-- V1.0.43: varsayilan (zorlama yok) ve sunucu sarj tavani
-------------------------------------------------------------------------------
do
    force_ref.value = false
    W.sees[2], W.speed, W.lag = true, 0, 12
    tick(40)
    check(last_cmd.force_defensive ~= true, "V1.0.43: varsayilan: gorulunce defensive zorlanmaz")
    force_ref.value = true
    tick(5)
    check(last_cmd.force_defensive == true, "V1.0.43: secenek acikken eski Smart zorlamasi")
    force_ref.value = false
    -- Sunucu tavani 6 tick: bir sure sonra "DT dolu" sayilir (eskiden hep "DT %60").
    W.sees[2], W.lag = false, 6
    tick(64 * 32)
    before = #prints + 1
    fire("player_hurt", { userid = 1, attacker = 2, dmg_health = 5, hitgroup = 3, weapon = "ssg08" })
    local line = printed("vuruldun:", before)
    check(line ~= nil and line:find("DT dolu", 1, true) ~= nil, "V1.0.43: tavani 6 olan sunucuda sarj dolu sayilir (" .. tostring(line) .. ")")
    W.lag = 3
    tick(2)
    before = #prints + 1
    fire("player_hurt", { userid = 1, attacker = 2, dmg_health = 5, hitgroup = 3, weapon = "ssg08" })
    line = printed("vuruldun:", before)
    check(line ~= nil and line:find("DT %50", 1, true) ~= nil, "V1.0.43: tavanin yarisi DT %50 (" .. tostring(line) .. ")")
    W.lag = 12
    tick(20)
end

-------------------------------------------------------------------------------
-- V1.0.44: havada gorulunce egil
-------------------------------------------------------------------------------
do
    local duck_ref = find_ref("Air duck when seen")
    check(duck_ref ~= nil and duck_ref.value == false, "V1.0.45: havada egilme secenegi var, varsayilan kapali")
    duck_ref.value = true
    W.flags, W.speed, W.sees[2] = 0, 200, true
    tick(5)
    check(last_cmd.in_duck == 1, "V1.0.44: havada biri goruyorken egilinir")
    W.sees[2] = false
    tick(40)
    check(last_cmd.in_duck ~= 1, "V1.0.44: havada kimse gormuyorsa egilme yok")
    W.flags, W.sees[2] = 1, true
    tick(5)
    check(last_cmd.in_duck ~= 1, "V1.0.44: yerde egilme zorlanmaz")
    W.flags, W.sees[2] = 0, true
    duck_ref.value = false
    tick(5)
    check(last_cmd.in_duck ~= 1, "V1.0.44: secenek kapaliyken havada egilme yok")
    W.flags, W.speed, W.sees[2] = 1, 0, false
    tick(20)
end

-------------------------------------------------------------------------------
-- V1.0.45: rastgele anti-brute sirasi ve defensive bekleme suresi
-------------------------------------------------------------------------------
do
    rec_ref.value = false
    random_ref.value, cooldown_ref.value, force_ref.value = true, true, true
    -- Rastgele sira: art arda kafa vuruslarinda faz hep +1 ilerlemez.
    W.flags, W.speed, W.sees[2], W.lag = 1, 150, true, 12
    tick(20)
    local phases, plus_one, prev = {}, 0, nil
    for _ = 1, 12 do
        local b = #prints + 1
        fire("player_hurt", { userid = 1, attacker = 2, dmg_health = 1, hitgroup = 1, weapon = "ssg08" })
        local l = printed("vuruldun:", b)
        local f = l ~= nil and tonumber(l:match("| faz (%d+) |")) or nil
        if f ~= nil and prev ~= nil and f == prev % 9 + 1 then
            plus_one = plus_one + 1
        end
        phases[#phases + 1] = f
        prev = f
        tick(20)
    end
    check(#phases == 12 and plus_one < 10, "V1.0.45: rastgele sirada faz hep +1 ilerlemez (" .. plus_one .. "/11 +1)")
    -- Bekleme suresi: defensive bittikten sonraki 1 sn'de (gorulmeye devam ederken) yeniden zorlanmaz.
    W.speed = 0
    tick(64)
    local forced, gaps = 0, 0
    for _ = 1, 128 do
        tick(1)
        forced = forced + (last_cmd.force_defensive == true and 1 or 0)
    end
    check(forced > 0, "V1.0.45 kurulum: gorulurken Smart defensive zorlaniyor (" .. forced .. "/128)")
    W.sees[2], W.speed = false, 0
    tick(40)
end

-------------------------------------------------------------------------------
-- V1.0.46: cani 30 ve altindaki dusmana Force safe point; takilirsa 0.5 sn sonra birakilir
-------------------------------------------------------------------------------
do
    local low_ref = find_ref("  » Finish low HP (<=30) with safe point")
    check(low_ref ~= nil and low_ref.value == true, "V1.0.46: dusuk can safe point secenegi var, varsayilan acik")
    W.ehp = { [2] = 100 }
    W.sees[2], W.speed = false, 0
    tick(10)
    check(plist.get(2, "Override safe point") ~= "On", "V1.0.46 kurulum: tam canli dusmanda Force safe point yok")
    W.ehp[2] = 8
    tick(3)
    check(plist.get(2, "Override safe point") == "On", "V1.0.46: 8 canli dusmana Force safe point")
    W.sees[2] = true
    tick(64)
    check(plist.get(2, "Override safe point") ~= "On", "V1.0.46: goruluyorken 0.5 sn ates yoksa birakilir")
    W.sees[2] = false
    low_ref.value = false
    W.ehp[2] = 7
    tick(3)
    check(plist.get(2, "Override safe point") ~= "On", "V1.0.46: secenek kapaliyken yok")
    low_ref.value = true
    W.ehp = nil
    tick(10)
end

-------------------------------------------------------------------------------
-- V1.0.47: sarj tavani tutulan shift'ten ogrenilir (kisa defensive dususleri tavani sisirmez)
-------------------------------------------------------------------------------
do
    force_ref.value, cooldown_ref.value, rec_ref.value = true, false, false
    W.sees[2], W.speed, W.flags = false, 0, 1
    W.lag = 0; tick(4)
    fire("round_start", {})
    W.lag = 7; tick(64)
    for _ = 1, 6 do W.lag = 17; tick(10); W.lag = 7; tick(150) end
    W.sees[2] = true; tick(5)
    before = #prints + 1
    fire("player_hurt", { userid = 1, attacker = 2, dmg_health = 5, hitgroup = 3, weapon = "ssg08" })
    local line47 = printed("vuruldun:", before)
    check(line47 ~= nil and line47:find("DT dolu", 1, true) ~= nil,
        "V1.0.47: duz sh 7 + kisa dususler DT dolu okunur (" .. tostring(line47) .. ")")
    check(last_cmd.force_defensive == true, "V1.0.47: duz shift'te goruluyorken defensive zorlanir")
    W.lag = 2; tick(2)
    before = #prints + 1
    fire("player_hurt", { userid = 1, attacker = 2, dmg_health = 5, hitgroup = 3, weapon = "ssg08" })
    line47 = printed("vuruldun:", before)
    check(line47 ~= nil and line47:find("DT %", 1, true) ~= nil, "V1.0.47: tavanin altina gercek dusus hala yarim sarj (" .. tostring(line47) .. ")")
    W.sees[2], W.lag = false, 12; tick(40)
end

-------------------------------------------------------------------------------
-- V1.0.47: extended desync (roll): yerde yavasken +-45, kosarken 0, kapaliyken senin degerin
-------------------------------------------------------------------------------
do
    local roll_ref = find_ref("Roll")
    local roll_menu = find_ref("Extended desync (roll)")
    check(roll_menu ~= nil and roll_menu.value == false, "V1.0.47: Extended desync (roll) secenegi var, varsayilan kapali (sunucuda roll yasak)")
    W.flags, W.speed, W.sees[2] = 1, 0, false
    tick(4)
    check(roll_ref ~= nil and roll_ref.value == 0, "V1.0.47: roll kapaliyken Roll'a dokunulmaz (" .. tostring(roll_ref and roll_ref.value) .. ")")
    roll_menu = roll_menu or { value = true }
    roll_menu.value = true
    tick(4)
    check(roll_ref ~= nil and (roll_ref.value == 45 or roll_ref.value == -45), "V1.0.47: dururken roll 45 (" .. tostring(roll_ref and roll_ref.value) .. ")")
    W.sees[2] = true; tick(2)
    before = #prints + 1
    fire("player_hurt", { userid = 1, attacker = 2, dmg_health = 5, hitgroup = 3, weapon = "ssg08" })
    local line = printed("vurulma-detay:", before)
    check(line ~= nil and line:find("roll [%+%-]45") ~= nil, "V1.0.47: vurulma satirinda roll yazar (" .. tostring(line) .. ")")
    W.sees[2] = false
    W.speed = 250; tick(4)
    check(roll_ref.value == 0, "V1.0.47: kosarken roll 0 (" .. tostring(roll_ref.value) .. ")")
    W.flags = 0; W.speed = 0; tick(4)
    check(roll_ref.value == 0, "V1.0.47: havada roll 0 (" .. tostring(roll_ref.value) .. ")")
    W.flags = 1
    W.speed = 0; tick(4)
    roll_menu.value = false; tick(4)
    check(roll_ref.value == 0, "V1.0.47: kapatinca senin Roll degerin (0) geri gelir (" .. tostring(roll_ref.value) .. ")")
end

-------------------------------------------------------------------------------
-- V1.0.47: sahte kayitta bekleme birakilinca sebebi yazilir; atis satirinda "bekleme yok: <sebep>"
-------------------------------------------------------------------------------
do
    W.sees[2], W.sees[3], W.speed, W.lag = false, false, 0, 12
    tick(80)
    before = #prints + 1
    W.sim_shift[2] = 10; tick(2)
    check(plist.get(2, "Add to whitelist") == true, "V1.0.47 kurulum: sahte kayitta whitelist")
    W.sees[2] = true; tick(2)
    check(printed("gercek kayit geldi", before) == nil and printed("serbest birakildi (seni goruyor), kayit hala sahte", before) ~= nil,
        "V1.0.47: gorulunce birakilan bekleme 'gercek kayit geldi' sayilmaz")
    before = #prints + 1
    fire("aim_fire", { id = 47, target = 2, hitgroup = 1, damage = 120, hit_chance = 70, backtrack = 0, x = 500, y = 0, z = 70 })
    fire("aim_miss", { id = 47, target = 2, hitgroup = 1, reason = "?" })
    local line = printed("atis:", before)
    check(line ~= nil and line:find("bekleme yok: seni goruyor", 1, true) ~= nil, "V1.0.47: sahte kayda atista bekleme yok sebebi (" .. tostring(line) .. ")")
    W.sim_shift[2], W.sees[2] = 0, false
    tick(80)
end

-------------------------------------------------------------------------------
-- V1.0.47: R8 sniper kuralina girmez (senin R8 Min. damage'in); R8 olumu scout kuralini ogretmez
-------------------------------------------------------------------------------
do
    fire("level_init") -- onceki testlerin "kafa beklerken olum" gevsemesi silinsin
    local md_r8 = find_ref("Minimum damage")
    W.weapon_class, W.item_index = "CDEagle", 64
    md_r8.value = 11
    W.sees[2], W.head_dmg[2], W.body_dmg[2], W.lag = true, 0, 82, 0
    tick(10)
    check(md_r8.value == 11, "V1.0.47: R8 goruluyorken sniper kurali yok, MD senin 11 (" .. tostring(md_r8.value) .. ")")
    before = #prints + 1
    fire("player_death", { userid = 1, attacker = 2, headshot = false, penetrated = 0, weapon = "deagle" })
    tick(10)
    check(printed("ogrenildi:", before) == nil, "V1.0.47: R8 ile olum kafa-bekleme olarak ogrenilmez")
    W.weapon_class, W.item_index = "CWeaponSSG08", nil
    md_r8.value = 100
    W.sees[2] = false
    tick(10)
end

-------------------------------------------------------------------------------
-- V1.0.47: kayitli config'teki In-air hit chance 40 ilk config yuklemesinde 0 olur, sonra elle 40'a dokunulmaz
-------------------------------------------------------------------------------
do
    local air_ref = find_ref("In-air hit chance (snipers, 0 = off)")
    check(db.nykle_win_gs_airhc47 == nil, "V1.0.47: config yuklenmeden tasima bayragi yazilmaz")
    air_ref.value = 40 -- eski config yuklendi
    fire("post_config_load")
    check(air_ref.value == 0 and db.nykle_win_gs_airhc47 == true, "V1.0.47: eski config'teki 40 bir kez 0 (" .. tostring(air_ref.value) .. ")")
    air_ref.value = 40 -- sonra elle 40 secildi
    fire("post_config_load")
    check(air_ref.value == 40, "V1.0.47: elle secilen 40'a sonra dokunulmaz")
    air_ref.value = 0
    tick(4)
end

-------------------------------------------------------------------------------
-- Kapanis
-------------------------------------------------------------------------------
before = #prints + 1
fire("pre_config_save")
fire("shutdown")
errs = errors_since(before)
check(#errs == 0, "kapanis hatasiz" .. (#errs > 0 and (": " .. errs[1]) or ""))
check(righthand.value == 1, "kapanista cl_righthand senin degerine doner (" .. tostring(righthand.value) .. ")")
check(files["nykle_log.txt"] ~= nil and files["nykle_log.txt"]:find("ESKI OTURUM", 1, true) == nil
    and files["nykle_log.txt"]:find("V1.0.47 (GameSense edition) yuklendi", 1, true) ~= nil,
    "V1.0.41: yeni surumde log dosyasi sifirdan (eski surumun oturumu atildi) [" .. tostring(files["nykle_log.txt"]):sub(1, 200) .. "]")
check(aspect.value == 0 and sky.value == 1 and notify.value == 8, "V1.0.35: kapanista aspect ratio, r_3dsky ve con_notifytime senin degerine doner ("
    .. tostring(aspect.value) .. ", " .. tostring(sky.value) .. ", " .. tostring(notify.value) .. ")")
local saved = db.nykle_win_gs_memory
local arms = type(saved) == "table" and type(saved.own_res) == "table" and saved.own_res.arms or nil
check(arms ~= nil and arms["lby+"] ~= nil and arms["lby+"].shots == 1 and arms["lby+"].hits == 1,
    "kol sayimi hafizaya yazildi (lby+ 1/1)")
check(arms ~= nil and arms["abs+"] ~= nil and arms["abs+"].hits == 1,
    "V1.0.34: abs+ kafa isabeti 1, gogse giden isabet sayilmadi (" .. (arms and arms["abs+"] and (arms["abs+"].hits .. "/" .. arms["abs+"].shots) or "?") .. ")")
errs = errors_since(1)
check(#errs == 0, "hic hata satiri yok" .. (#errs > 0 and (": " .. errs[1]) or ""))

log(fails == 0 and "ALL PASSED" or ("FAILED " .. fails))
return out
