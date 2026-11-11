-- Nykle.win GameSense edition icin duman (smoke) testi: GameSense API'sinin sahte hali, Redis'in Lua 5.1
-- EVAL ortaminda calisir (tests/run_gs_smoke.sh). Amac: lua yuklenir mi, tick'ler ve olaylar hata vermeden
-- ("hata verdi" / "YUKLENEMEDI" satiri yok) doner mi, V1.0.22 kurallari (Safe recharge, gercek kayit
-- bekleme, govde 70+ secenegi, "gormedi" izi, sikmadi sebepleri) sahte dunyada beklendigi gibi mi.
-- ARGV[1] = script kaynagi.
local src = ARGV[1]
-- Paylasilan Redis Lua VM'inde baska bir betik string metatable'ini degistirdiyse ("%d"):format bozulur; geri al.
do
    local sm = getmetatable("")
    if sm ~= nil and sm.__index ~= string then sm.__index = string end
end
local out, fails = {}, 0
local function finite_num(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge end
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
-- V1.0.66: ping spike (kutu + tus + ms) ve quick stop (kutu + tus + secenekler).
reference("MISC", "Miscellaneous", "Ping spike", newref("checkbox", "Ping spike", true), newref("hotkey", "Ping spike key", true),
    newref("slider", "Ping spike ms", 100))
reference("RAGE", "Other", "Quick stop", newref("checkbox", "Quick stop", true), newref("hotkey", "Quick stop key", false),
    newref("multiselect", "Quick stop options", { "Slow motion" }))
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
        -- V1.0.90: W.dmg_fn(x1, y1, hedef, kafa) verildiyse hasar atis yapilan noktaya gore (AI peek: yan adimda aci).
        if W.dmg_fn ~= nil then
            local fd = W.dmg_fn(x1, y1, target, head)
            if fd ~= nil then
                return fd > 0 and target or -1, fd
            end
        end
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
    -- V1.0.80: zemin yuksekligi verildiyse kendi dikey izimiz (inis tahmini) zemine carpar.
    -- W.floor_fn(x, y): x / y'ye gore zemin (nil = zemin yok, ucurum).
    if (W.floor_z ~= nil or W.floor_fn ~= nil) and skip == 1 and x1 == x2 and y1 == y2 and z2 < z1 then
        local fz = W.floor_z
        if W.floor_fn ~= nil then fz = W.floor_fn(x1, y1) end
        if fz == nil then return 1, -1 end
        local f = (z1 - fz) / (z1 - z2)
        return (f > 0 and f < 1) and f or 1, -1
    end
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
function entity.is_alive(ent) return (ent == 1 and not W.dead) or ent == 2 or ent == 3 end -- V1.0.80: W.dead
function entity.is_dormant() return false end
function entity.is_enemy(ent) return ent == 2 or ent == 3 end
function entity.get_player_name(ent) return ({ "ben", "dusman2", "dusman3" })[ent] or "?" end
function entity.get_steam64(ent) return "7656119900000000" .. tostring(ent) end
function entity.get_player_resource() return 99 end
function entity.get_game_rules() return 98 end
function entity.get_esp_data() return { flags = W.esp or 0 } end
function entity.get_player_weapon(ent) return 10 + ent end
function entity.get_classname(ent)
    if ent == 11 then return W.weapon_class end
    if ent == 12 or ent == 13 then return "CWeaponSSG08" end
    return nil
end
function entity.get_origin(ent)
    if ent == 1 and W.z ~= nil then return 0, 0, W.z end -- V1.0.80: ucus yuksekligi
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
        if name == "m_nTickBase" then return W.tick - (W.tick_shift or 0) - W.lag end
        if name == "m_fFlags" then return W.flags end
        if name == "m_vecVelocity" then return W.speed, 0, W.vz or 0 end
        if name == "m_flDuckAmount" then return W.duck end
        if name == "m_flNextAttack" then return 0 end
        if name == "m_iTeamNum" then return 2 end
        if name == "m_MoveType" then return 2 end
        if name == "m_bIsScoped" then return true end
        if name == "m_ArmorValue" then return 100 end
        if name == "m_flMaxspeed" then return 230 end
        if name == "m_angEyeAngles" then return 0, 0, 0 end
        if name == "m_totalHitsOnServer" then return W.total_hits or 0 end
        if name == "m_vecViewOffset[2]" then return 64 end
        return nil
    end
    if ent == 2 or ent == 3 then
        if name == "m_iHealth" then return (W.ehp and W.ehp[ent]) or 100 end
        if name == "m_fFlags" then return (W.eair and W.eair[ent]) and 0 or 1 end
        if name == "m_vecVelocity" then return W.evel[ent] or 0, 0, 0 end
        if name == "m_flDuckAmount" then return 0 end
        if name == "m_flSimulationTime" then return (W.tick - W.sim_shift[ent]) * W.interval end
        if name == "m_iTeamNum" then return 3 end
        if name == "m_ArmorValue" then return 100 end
        if name == "m_flMaxspeed" then return 230 end
        if name == "m_angEyeAngles" then return 0, (W.eyaw and W.eyaw[ent]) or 180, 0 end
        if name == "m_angEyeAngles[1]" then return (W.eyaw and W.eyaw[ent]) or 180 end
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
function globals.tickcount() return W.tick - (W.tick_shift or 0) end
function globals.realtime() return now() end
function globals.curtime() return now() end
function globals.frametime() return W.interval end
function globals.tickinterval() return W.interval end
function globals.mapname() return "de_mirage" end
function globals.maxplayers() return 64 end
function globals.chokedcommands() return 0 end

local renderer = {}
-- V1.0.90: cizilen yazilar kaydedilir (duello danismani testi); liste sismesin diye 4000'de bosaltilir.
local texts = {}
function renderer.text(x, y, r, g, b, a, flags, w, str)
    if #texts >= 4000 then
        for k in pairs(texts) do texts[k] = nil end
    end
    texts[#texts + 1] = { x = x, y = y, r = r, g = g, b = b, a = a, flags = flags, str = str }
end
local indicators = {}
function renderer.indicator(r, g, b, a, text) indicators[#indicators + 1] = { r = r, g = g, text = text }; return 0 end
function renderer.measure_text() return 10, 10 end
function renderer.rectangle() end
function renderer.triangle() end
function renderer.line() end
function renderer.circle() end
function renderer.gradient() end
function renderer.circle_outline() end

-- Hafiza: hava grubunda faz 1 kotu bilinsin (20 mermi, 15 kafa) -> V1.0.23 faz atlama testi.
local db = { nykle_win_gs_memory = { version = 1, phase_v = 2, brute = {}, resolver = {}, phase_groups = {
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
local ragdoll = { value = 0 }
local cvar = {
    sv_gravity = { get_float = function() return 800 end }, -- V1.0.80: inis tahmini
    cl_clanid = { get_int = function() return 0 end, set_int = function() end },
    cl_righthand = { get_int = function() return righthand.value end, set_int = function(_, v) righthand.value = v end },
    r_aspectratio = { get_float = function() return aspect.value end, set_raw_float = function(_, v) aspect.value = v end },
    r_3dsky = { get_int = function() return sky.value end, set_raw_int = function(_, v) sky.value = v end },
    con_notifytime = { get_float = function() return notify.value end, set_raw_float = function(_, v) notify.value = v end },
    developer = { get_int = function() return dev.value end, set_int = function(_, v) dev.value = v end },
    cl_disable_ragdolls = { get_int = function() return ragdoll.value end, set_raw_int = function(_, v) ragdoll.value = v end },
}

-------------------------------------------------------------------------------
-- Yukle
-------------------------------------------------------------------------------
local files = { ["nykle_log.txt"] = "10:00:00 [Nykle.win] V1.0.1 (GameSense edition) yuklendi\n10:00:01 [Nykle.win] ESKI OTURUM SATIRI\n" }
-- V1.0.60: tekrarlanabilir rastgele sayi (Redis'in math.random'i calistirmalar arasinda farkli dizi verebiliyor;
-- kendi resolver'in kesif cekimi artik gercekten rastgele oldugu icin test sonucu ona bagli kalmasin).
local test_math = setmetatable({}, { __index = math })
-- V1.0.61: oyunda UCB primi "nan" cikti (math.log); test de ayni sekilde nan dondurur.
test_math.log = function() return 0 / 0 end
do
    local seed = 12345
    test_math.random = function(a, b)
        seed = (seed * 1103515245 + 12345) % 2147483648
        local r = seed / 2147483648
        if a == nil then
            return r
        elseif b == nil then
            return 1 + math.floor(r * a)
        end
        return a + math.floor(r * (b - a + 1))
    end
end
local env = {
    print = print, client = client, ui = ui, entity = entity, globals = globals, renderer = renderer,
    database = database, plist = plist, cvar = cvar, bit = bit,
    math = test_math, string = string, table = table, pairs = pairs, ipairs = ipairs, type = type, tostring = tostring,
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
check(printed("V1.0.90 (GameSense edition) yuklendi") ~= nil, "surum satiri V1.0.90")
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
-- V1.0.81: deney motoru varsayilan acik; eski testler deney kollarindan etkilenmesin diye burada kapatilir, kendi
-- testi en sonda (bkz. "V1.0.81: deney motoru").
do
    local xp_ref = find_ref("Experiments (auto A/B test per life, keeps what wins)")
    check(xp_ref ~= nil and xp_ref.value == true, "V1.0.81: deney motoru varsayilan acik")
    check(printed("deney motoru: yer: peek_narrow, exploit: sniper_hs, def: force_off, hareket: cap_off, koruma: fs_auto_off, hava: air_def2, atis: hc70, atis2: fakebody_off, atis3: qs_late, peek: peek_real | kalici: yok (0 can olculdu)") ~= nil,
        "V1.0.81: yukleme satiri ilk adaylari yazar (V1.0.90: 10 kulvar)")
    if xp_ref ~= nil then xp_ref.value = false end
end

-------------------------------------------------------------------------------
-- Tick surucusu
-------------------------------------------------------------------------------
local cmdno = 1
local last_cmd = nil
local function tick(n)
    for _ = 1, n or 1 do
        W.tick = W.tick + 1
        cmdno = cmdno + 1
        local cmd = { command_number = cmdno, chokedcommands = 0, in_jump = W.jump and 1 or 0, in_duck = 0, in_use = 0,
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
-- V1.0.75: yan duran statik rakipte body yaw zorlanmaz (varsayilan acik); eski kol / seri bolumleri icin kapali.
-- V1.0.77: body yaw hipotezleri / kendi kollar / seri varsayilan kapali; eski bolumler icin acilir.
local hyp_ref = find_ref("  » Body yaw hypotheses (Force body yaw)")
check(hyp_ref ~= nil and hyp_ref.value == false, "V1.0.77: body yaw zorlamasi (hipotez / kol / seri) varsayilan kapali")
hyp_ref.value = true
-- V1.0.78: havada LC kirma (DT / HS kapali) varsayilan acik; eski hava bolumleri icin kapali.
local airlc_ref = find_ref("Air: break LC")
check(airlc_ref ~= nil and airlc_ref.value == true, "V1.0.78: havada LC kirma secenegi var, varsayilan acik")
airlc_ref.value = false
-- V1.0.79: kafa saklayan rakibe govde varsayilan acik; eski bolumler icin kapali.
local hider_ref = find_ref("Body vs head hiders")
check(hider_ref ~= nil and hider_ref.value == true, "V1.0.79: kafa saklayana govde secenegi var, varsayilan acik")
hider_ref.value = false
local side_ref = find_ref("Sideways static enemy: no forced body yaw")
check(side_ref ~= nil and side_ref.value == true, "V1.0.75: yan duran statik rakipte zorlama yok secenegi var, varsayilan acik")
side_ref.value = false
local auto_ref = find_ref("  » Auto AFK (no input 8 s after spawn)")
check(auto_ref ~= nil and auto_ref.value == true, "V1.0.71: otomatik AFK varsayilan acik")
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
rec_ref.value = false; hyp_ref.value = true -- hyp
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
-- V1.0.62: peek atarken (dusman seni gormuyor) sahte kayitta en fazla 4 tick beklenir.
do
    W.sees[2] = false
    local pk = find_ref("Quick peek assist key")
    local pc = find_ref("Quick peek assist")
    pk.value, pc.value = true, true
    W.speed = 120
    tick(10)
    W.sim_shift[2] = 10
    tick(2)
    local g2 = plist.get(2, "Add to whitelist")
    check(g2 == false, "V1.0.62: peek'te yerdeki hedefin sahte kaydinda eskisi gibi beklenmez (" .. tostring(g2) .. ")")
    W.sim_shift[2] = 0
    tick(40)
    W.eair = W.eair or {}
    W.eair[2] = true
    tick(10)
    W.sim_shift[2] = 10
    tick(2)
    local w2 = plist.get(2, "Add to whitelist")
    tick(5)
    local w7 = plist.get(2, "Add to whitelist")
    check(w2 == true and w7 == false, "V1.0.62: peek'te gorulmezken havadaki hedefin sahte kaydinda kisa bekleme (2. tick " .. tostring(w2) .. ", 7. tick " .. tostring(w7) .. ")")
    W.eair[2] = nil
    W.sim_shift[2] = 0
    pk.value, pc.value, W.speed = false, false, 0
    W.sees[2] = true
    tick(40)
end

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
check(pair_ref ~= nil and pair_ref.value == false, "V1.0.59: DT pair secenegi var ve varsayilan kapali")
pair_ref.value = false
W.sees[2], W.head_dmg[2], W.body_dmg[2], W.lag = true, 0, 86, 12
tick(10)
check(md_ref.value == 101, "V1.0.59: DT pair kapaliyken govde 86 x 2 >= 100 olsa da MD 85'e inmez (" .. tostring(md_ref.value) .. ")")
pair_ref.value = true -- eski davranisin kontrolleri (secenek acikken)
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
rec_ref.value = false; hyp_ref.value = true -- hyp -- onerilen ayarlar deneme yuzdesini geri yazmasin
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
do
    local kl = printed("| bizim lby+ (lby L 50")
    check(kl ~= nil and kl:find("nan", 1, true) == nil, "V1.0.61: math.log nan dondurse de UCB primi sayi (" .. tostring(kl) .. ")")
    check(kl ~= nil and kl:find("| r %d%.%d+/0%.00 tercih") ~= nil and kl:find("lby%+ %d%.%d+%+%d%.%d+") ~= nil,
        "V1.0.60: kol karari cekimi, esigi ve skorlari yazar (" .. tostring(kl) .. ")")
    check(printed("dbg random: random() 32x min") ~= nil, "V1.0.60: yuklemede rastgele cekim olcumu yazilir")
end
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
-- V1.0.64: hangi abs kolunun secilecegi onceki (atissiz, suresi dolan) kararlarin deneme sayisina bagli; secilen kol izlenir.
W.absa = plist.get(2, "Force body yaw value") == -58 and "abs-" or "abs+"
check(plist.get(2, "Force body yaw") == true and math.abs(plist.get(2, "Force body yaw value") or 0) == 58
    and printed("| bizim " .. W.absa .. " (statik desync, taraf bilgisi yok) body yaw " .. (W.absa == "abs-" and "-58" or "58"), before) ~= nil,
    "V1.0.33: statik dusmanda taraf bilgisi yokken abs kolu (" .. tostring(plist.get(2, "Force body yaw value")) .. ")")
before = #prints + 1
fire("weapon_fire", { userid = 1, weapon = "weapon_ssg08" })
fire("aim_fire", { id = 8, target = 2, hitgroup = 1, damage = 120, hit_chance = 80, backtrack = 0, x = 500, y = 0, z = 70 })
tick(2)
fire("aim_hit", { id = 8, target = 2, hitgroup = 1, damage = 120 })
line = printed("atis: dusman2", before)
check(line ~= nil and line:find("| res " .. W.absa, 1, true) ~= nil, "V1.0.33: atis satirinda res " .. W.absa .. " (" .. tostring(line) .. ")")
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
check(line ~= nil and line:find("| res " .. W.absa, 1, true) ~= nil and line:find("iska", 1, true) ~= nil,
    "V1.0.34 kurulum: abs kolunda resolver iskasi (" .. tostring(line) .. ")")
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
-- V1.0.51: gevseme DT ciftini kapatmaz (v50: gevsemeden sonra 14 tam canli atisin hepsi kafaya, govde 74 x 2 >= 100).
do
    local lag_was = W.lag
    pair_ref.value = true -- V1.0.59: secenek varsayilan kapali; eski davranis acikken
    W.body_dmg[2], W.lag = 74, 12
    before = #prints + 1
    tick(20)
    check(md_ref.value == 73, "V1.0.51: gevsedikten sonra DT cifti: MD govde-1 = 73 (" .. tostring(md_ref.value) .. ")")
    W.lag = 0
    tick(20)
    check(md_ref.value == 100, "V1.0.51: DT dolu degilken senin MD'n 100, HP+1 yok (" .. tostring(md_ref.value) .. ")")
    W.body_dmg[2], W.lag = 45, lag_was
    pair_ref.value = false
end
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
do
    local rag_ref = find_ref("  » Disable ragdolls (bodies vanish)")
    tick(70)
    check(rag_ref ~= nil and rag_ref.value == false and ragdoll.value == 0, "V1.0.59: ragdoll kapatma secenegi var, varsayilan kapali (cvar " .. tostring(ragdoll.value) .. ")")
    rag_ref.value = true
    tick(70)
    check(ragdoll.value == 1, "V1.0.59: acinca cl_disable_ragdolls 1 (" .. tostring(ragdoll.value) .. ")")
    rag_ref.value = false
    tick(70)
    check(ragdoll.value == 0, "V1.0.59: kapatinca senin degerin geri (" .. tostring(ragdoll.value) .. ")")
end
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
    rec_ref.value = false; hyp_ref.value = true -- hyp
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
    rec_ref.value = false; hyp_ref.value = true -- hyp
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
    -- V1.0.50: aci secili dusmanda (onceki testlerin hipotezi) dusuk can Force yazmaz; burada Correction kapatilarak
    -- aci uygulanmaz, kural tek basina sinanir.
    plist.set(2, "Correction active", false)
    W.ehp = { [2] = 100 }
    W.sees[2], W.speed = false, 0
    tick(10)
    check(plist.get(2, "Override safe point") ~= "On", "V1.0.46 kurulum: tam canli dusmanda Force safe point yok")
    W.body_dmg[2] = 0
    W.ehp[2] = 8
    tick(3)
    check(plist.get(2, "Override safe point") ~= "On", "V1.0.50: sadece kafa acikken dusuk canda Force yok (atis kilitlenmesin)")
    W.body_dmg[2] = 60
    tick(6)
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
    W.body_dmg[2] = 0
    plist.set(2, "Correction active", true)
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
    local psafe = find_ref("Prefer safe point")
    W.weapon_class, W.item_index = "CWeaponSSG08", nil
    md_r8.value = 100
    W.sees[2] = false
    tick(10)
    check(psafe ~= nil and psafe.value == true, "V1.0.47: scout ile Prefer safe point acik (" .. tostring(psafe and psafe.value) .. ")")
end

-------------------------------------------------------------------------------
-- V1.0.47: kayitli config'teki In-air hit chance 40 ilk config yuklemesinde 0 olur, sonra elle 40'a dokunulmaz
-------------------------------------------------------------------------------
do
    local air_ref = find_ref("In-air hit chance (snipers, 0 = off)")
    check(db.nykle_win_gs_airhc47 == nil, "V1.0.47: config yuklenmeden tasima bayragi yazilmaz")
    local cc58 = find_ref("Desync keeper: slow crouch-walk when seen")
    check(db.nykle_win_gs_cc58 == nil, "V1.0.58: config yuklenmeden desync keeper bayragi yazilmaz")
    cc58.value = false -- eski config'te kapali kaydedilmis
    local pair_was = pair_ref.value
    pair_ref.value = true -- eski config'te DT pair acik kaydedilmis
    air_ref.value = 40 -- eski config yuklendi
    fire("post_config_load")
    check(air_ref.value == 0 and db.nykle_win_gs_airhc47 == true, "V1.0.47: eski config'teki 40 bir kez 0 (" .. tostring(air_ref.value) .. ")")
    check(pair_ref.value == false and db.nykle_win_gs_dtpair59 == true, "V1.0.59: eski config'teki acik DT pair bir kez kapatilir")
    check(cc58.value == true and db.nykle_win_gs_cc58 == true, "V1.0.58: eski config'teki kapali desync keeper bir kez acilir (" .. tostring(cc58.value) .. ")")
    air_ref.value = 40 -- sonra elle 40 secildi
    cc58.value = false -- sonra elle kapatildi
    pair_ref.value = true -- sonra elle acildi
    fire("post_config_load")
    check(air_ref.value == 40, "V1.0.47: elle secilen 40'a sonra dokunulmaz")
    check(cc58.value == false, "V1.0.58: elle kapatilan desync keeper'a sonra dokunulmaz")
    check(pair_ref.value == true, "V1.0.59: elle acilan DT pair'e sonra dokunulmaz")
    cc58.value = true
    pair_ref.value = pair_was
    air_ref.value = 0
    tick(4)
end

-------------------------------------------------------------------------------
-- V1.0.48: trash talk varsayilan kapali; kayitli config'te acik kaldiysa ilk yuklemede bir kez kapatilir
-------------------------------------------------------------------------------
do
    local tt = find_ref("Trash talk")
    check(tt ~= nil, "V1.0.48: trash talk secenegi var")
    if tt ~= nil then
        check(db.nykle_win_gs_tt48 == true and tt.value == false, "V1.0.48: trash talk ilk config yuklemesinde kapatildi (" .. tostring(tt.value) .. ")")
        tt.value = true
        fire("post_config_load")
        check(tt.value == true, "V1.0.48: sonra elle acilan trash talk'a dokunulmaz")
        tt.value = false
    end
end

-------------------------------------------------------------------------------
-- V1.0.49: dusman basina resolver iskasi serisi (durumdan bagimsiz): 3 iskadan sonra GS yerine body yaw -58;
-- Correction kapaliyken yazilmaz; GS kafa isabeti seriyi bitirir
-------------------------------------------------------------------------------
do
    rec_ref.value, hyp_ref.value = false, true
    W.sees[2], W.sees[3], W.speed, W.lag = false, false, 0, 12
    W.head_dmg[3] = 100
    tick(10)
    before = #prints + 1
    local vels = { 0, 130, 250 }
    for i = 1, 3 do
        W.evel[3] = vels[i]; tick(40)
        if i > 1 then fire("round_start") end
        fire("aim_fire", { id = 4900 + i, target = 3, hitgroup = 1, damage = 120, hit_chance = 90, backtrack = 0, x = 500, y = 0, z = 70 })
        fire("aim_miss", { id = 4900 + i, target = 3, hitgroup = 1, reason = "?" })
    end
    check(printed("-> GS yerine body yaw", before) ~= nil, "V1.0.49: farkli durumlarda iskalar seriyi acar")
    local zk = printed("zemin kafa iskasi (statik", before)
    check(zk ~= nil and zk:find("2 zemin kafa iskasi (statik, yan duruyor)", 1, true) ~= nil,
        "V1.0.68/75: yan duran statik rakibe 2 zemin kafa correction iskasi -> govde (" .. tostring(zk) .. ")")
    -- V1.0.73: iskalar roundlara dagilsa da sayilir (round basi sayaci sifirlamaz).
    W.evel[3] = 0; tick(10)
    check(plist.get(3, "Force body yaw") == true and math.abs(plist.get(3, "Force body yaw value") or 0) == 58,
        "V1.0.49: seri acikken body yaw +-58 (" .. tostring(plist.get(3, "Force body yaw")) .. ", " .. tostring(plist.get(3, "Force body yaw value")) .. ")")
    fire("aim_fire", { id = 4904, target = 3, hitgroup = 1, damage = 120, hit_chance = 90, backtrack = 0, x = 500, y = 0, z = 70 })
    before = #prints + 1
    fire("aim_miss", { id = 4904, target = 3, hitgroup = 1, reason = "?" })
    local l49 = printed("atis: dusman3", before)
    check(l49 ~= nil and l49:find("| res ", 1, true) ~= nil and l49:find("res gs", 1, true) == nil,
        "V1.0.49: seri acikken atis GS'ye kalmaz (seri ya da kendi kol) (" .. tostring(l49) .. ")")
    plist.set(3, "Correction active", false)
    tick(4)
    check(plist.get(3, "Force body yaw") ~= true, "V1.0.49: Correction kapaliyken seri yazilmaz")
    before = #prints + 1
    fire("aim_fire", { id = 4905, target = 3, hitgroup = 1, damage = 120, hit_chance = 90, backtrack = 0, x = 500, y = 0, z = 70 })
    fire("aim_hit", { id = 4905, target = 3, hitgroup = 1, damage = 120 })
    check(printed("seri: bitti (GS kafadan vurdu)", before) ~= nil, "V1.0.49: GS kafa isabeti seriyi bitirir")
    plist.set(3, "Correction active", true)
    tick(4)
    before = #prints + 1
    fire("aim_fire", { id = 4906, target = 3, hitgroup = 1, damage = 120, hit_chance = 90, backtrack = 0, x = 500, y = 0, z = 70 })
    fire("aim_miss", { id = 4906, target = 3, hitgroup = 1, reason = "?" })
    l49 = printed("atis: dusman3", before)
    check(l49 ~= nil and l49:find("res seri", 1, true) == nil, "V1.0.49: seri bitince atis seri acisiyla gitmez (" .. tostring(l49) .. ")")
    W.head_dmg[3] = 0
    tick(10)
end

-------------------------------------------------------------------------------
-- V1.0.60: seride -58 ve +58 ikisi de iskalarsa body yaw 0, o da iskalarsa -29 / +29, sonra yine tam aci
-------------------------------------------------------------------------------
do
    rec_ref.value, hyp_ref.value = false, true
    local own2 = find_ref("  » Own resolver (LBY")
    local own_was = own2.value
    own2.value = false
    W.sees[2], W.sees[3], W.speed, W.lag = false, false, 0, 12
    W.head_dmg[3] = 100
    tick(10)
    local vels = { 0, 130, 250 }
    for i = 1, 3 do
        W.evel[3] = vels[i]; tick(40)
        fire("aim_fire", { id = 6000 + i, target = 3, hitgroup = 1, damage = 120, hit_chance = 90, backtrack = 0, x = 500, y = 0, z = 70 })
        fire("aim_miss", { id = 6000 + i, target = 3, hitgroup = 1, reason = "?" })
    end
    W.evel[3] = 0
    local seen = {}
    before = #prints + 1
    for i = 1, 10 do
        tick(6)
        seen[#seen + 1] = plist.get(3, "Force body yaw") == true and plist.get(3, "Force body yaw value") or "x"
        fire("aim_fire", { id = 6010 + i, target = 3, hitgroup = 1, damage = 120, hit_chance = 90, backtrack = 0, x = 500, y = 0, z = 70 })
        fire("aim_miss", { id = 6010 + i, target = 3, hitgroup = 1, reason = "?" })
    end
    local got = {}
    for _, v in ipairs(seen) do got[#got + 1] = tostring(v) end
    local seq = table.concat(got, " ")
    check(printed("seri: -58 ve +58 ikisi de iskaladi (fake yaw / kucuk desync) -> body yaw 0", before) ~= nil,
        "V1.0.60: seride iki taraf da iskalayinca body yaw 0 (" .. seq .. ")")
    check(printed("seri: body yaw 0 iskaladi -> body yaw -29", before) ~= nil and printed("seri: -29 iskaladi -> body yaw +29", before) ~= nil,
        "V1.0.60: 0 iskalayinca -29, sonra +29 (" .. seq .. ")")
    check(printed("seri: +29 iskaladi -> butun acilar kafada iskaladi (extended / roll desync)", before) ~= nil, "V1.0.60/67: yarim acilar da iskalayinca yine tam aci, rakip extended suphesi")
    W.body_dmg[3] = 86
    local before67 = #prints + 1
    tick(2)
    local e67 = printed("extended / roll suphesi", before67)
    check(e67 ~= nil and e67:find("Min. damage gecici 85", 1, true) ~= nil and plist.get(3, "Override prefer body aim") == "Force",
        "V1.0.67: butun acilar iskalanan rakibe govde zorlanir, MD govde-1 (" .. tostring(e67) .. ", " .. tostring(plist.get(3, "Override prefer body aim")) .. ")")
    W.body_dmg[3] = 0
    check(seq:find("58 0 %-29 29") ~= nil, "V1.0.60: seri merdiveni plist'e yazilir: +58, 0, -29, +29 (" .. seq .. ")")
    -- Inceleme: tam aciyla kafa eski iskalari siler; tek bir sonraki iska merdiveni (0) baslatmaz.
    local function shoot(id, hit)
        tick(6)
        local v = plist.get(3, "Force body yaw") == true and plist.get(3, "Force body yaw value") or "x"
        fire("aim_fire", { id = id, target = 3, hitgroup = 1, damage = 120, hit_chance = 90, backtrack = 0, x = 500, y = 0, z = 70 })
        if hit then
            fire("aim_hit", { id = id, target = 3, hitgroup = 1, damage = 120 })
        else
            fire("aim_miss", { id = id, target = 3, hitgroup = 1, reason = "?" })
        end
        return v
    end
    local trail = {}
    for i = 1, 6 do
        tick(6)
        local v = plist.get(3, "Force body yaw value")
        if plist.get(3, "Force body yaw") == true and v == 58 then break end
        trail[#trail + 1] = tostring(shoot(6020 + i, false))
    end
    before = #prints + 1
    local hv = shoot(6030, true)
    local mv = shoot(6031, false)
    check(hv == 58 and mv == 58 and printed("ikisi de iskaladi", before) == nil,
        "V1.0.60: +58 kafadan vurduktan sonra tek +58 iskasi body yaw 0'a dusurmez (" .. tostring(hv) .. ", " .. tostring(mv) .. " | " .. table.concat(trail, " ") .. ")")
    own2.value = own_was
    W.head_dmg[3] = 0
    tick(10)
end

-------------------------------------------------------------------------------
-- V1.0.51: scout ile havada GameSense'in "vurulabilir" bayragi hava defensive'ini kesmez; satirlarda hiz / egilme
-------------------------------------------------------------------------------
do
    force_ref.value, cooldown_ref.value, rec_ref.value = true, false, false
    W.flags, W.speed, W.sees[2], W.lag = 1, 0, false, 12
    tick(40)
    W.esp = 2048
    W.flags, W.speed, W.sees[2] = 0, 200, true -- havada, goruluyor, bayrak var
    tick(6)
    check(last_cmd.force_defensive == true, "V1.0.51: havada bayrak varken scout hava defensive'i surer")
    before = #prints + 1
    fire("player_hurt", { userid = 1, attacker = 2, dmg_health = 5, hitgroup = 3, weapon = "ssg08" })
    local l51 = printed("vuruldun:", before)
    check(l51 ~= nil and l51:find("(hava, bayrak)", 1, true) ~= nil and l51:find(" | v%d+ duck%d+") ~= nil,
        "V1.0.51: vuruldun satirinda hava bayragi ve hiz / egilme (" .. tostring(l51) .. ")")
    -- V1.0.52: bomba cekince (defensive erken doner) etiket takili kalmaz.
    W.weapon_class = "CHEGrenade"
    tick(3)
    before = #prints + 1
    fire("player_hurt", { userid = 1, attacker = 2, dmg_health = 5, hitgroup = 3, weapon = "ssg08" })
    l51 = printed("vuruldun:", before)
    check(l51 ~= nil and l51:find("(hava, bayrak)", 1, true) == nil, "V1.0.52: defensive calismayan tick'te '(hava, bayrak)' etiketi kalmaz (" .. tostring(l51) .. ")")
    W.weapon_class = "CWeaponSSG08"
    tick(3)
    W.flags, W.speed = 1, 0
    tick(6)
    check(last_cmd.force_defensive ~= true, "V1.0.51: yerde bayrak temiz atis sayilir, defensive kesilir")

    W.esp, W.sees[2] = 0, false
    tick(40)
end

-------------------------------------------------------------------------------
-- V1.0.53: desync koruyucu hareket (varsayilan kapali) ve "maxdsy" logu
-------------------------------------------------------------------------------
do
    local cc = find_ref("Desync keeper: slow crouch-walk when seen")
    local wc = find_ref("Desync keeper: slow walk when seen (<=115 u/s)")
    local nj = find_ref("Block jump while seen (not jump-scout)")
    check(cc ~= nil and cc.value == true and wc ~= nil and wc.value == false and nj ~= nil and nj.value == false,
        "V1.0.58: egik desync keeper varsayilan acik; yuruyus/ziplama secenekleri kapali")
    cc.value = false
    W.flags, W.speed, W.duck, W.sees[2] = 1, 78, 1, true
    tick(5)
    check(last_cmd.forwardmove == 450, "V1.0.53: kapaliyken egik yuruyuse dokunulmaz (" .. tostring(last_cmd.forwardmove) .. ")")
    cc.value = true
    tick(5)
    check(last_cmd.forwardmove < 120 and last_cmd.forwardmove > 100,
        "V1.0.53: goruluyorken egik hiz 38 u/s'ye (girdi ~112) sinirlanir (" .. tostring(last_cmd.forwardmove) .. ")")
    before = #prints + 1
    fire("player_hurt", { userid = 1, attacker = 2, dmg_health = 5, hitgroup = 3, weapon = "ssg08" })
    local l53 = printed("vuruldun:", before)
    check(l53 ~= nil and l53:find(" yavas", 1, true) ~= nil and l53:find("| maxdsy %d+ wtr %d+%%") ~= nil,
        "V1.0.53: vuruldun satirinda 'yavas' ve 'maxdsy' (" .. tostring(l53) .. ")")
    W.sees[2] = false
    tick(5)
    check(last_cmd.forwardmove == 450, "V1.0.53: gorulmuyorken egik hiza dokunulmaz")
    cc.value = false
    W.duck, W.speed, W.sees[2] = 0, 200, true
    wc.value = true
    tick(5)
    check(math.abs(last_cmd.forwardmove - 115) < 0.5, "V1.0.53: goruluyorken yuruyus 115 ile sinirli (" .. tostring(last_cmd.forwardmove) .. ")")
    wc.value = false
    W.next_attack = 1e9 -- silah hazir degil: jump scout degil
    W.jump = true
    nj.value = true
    tick(3)
    check(last_cmd.in_jump == 0, "V1.0.53: goruluyorken (jump scout degil) ziplama engellenir")
    nj.value = false
    tick(3)
    check(last_cmd.in_jump == 1, "V1.0.53: secenek kapaliyken ziplamaya dokunulmaz")
    W.jump, W.next_attack = nil, 0
    -- Temastan once durma: kosuyorsun, birazdan gorulecek (ileri bakis), henuz gormuyor.
    local cs = find_ref("Stop before contact when decelerating")
    check(cs ~= nil and cs.value == false, "V1.0.53: temastan once durma secenegi var, varsayilan kapali")
    W.sees[2], W.sees_ahead[2], W.speed = false, false, 200
    tick(30)
    cs.value = true
    -- Ileri bakis: dusman 2 yuruyor, kaydi 10 tick geride, ilerisinden kafani gorur (exposure.soon).
    W.evel[2], W.sees_ahead[2], W.sim_shift[2] = 100, true, 10
    tick(3)
    before = #prints + 1
    fire("player_hurt", { userid = 1, attacker = 3, dmg_health = 5, hitgroup = 3, weapon = "ssg08" })
    local l53c = printed("vuruldun:", before)
    check(last_cmd.forwardmove < 0 and l53c ~= nil and l53c:find(" dur", 1, true) ~= nil,
        "V1.0.53: birazdan gorulecekken kosudan durma (ters girdi) (" .. tostring(last_cmd.forwardmove) .. " / " .. tostring(l53c) .. ")")
    cs.value = false
    W.evel[2], W.sees_ahead[2], W.sim_shift[2] = 0, false, 0
    W.speed, W.sees[2] = 0, false
    tick(30)
end

-------------------------------------------------------------------------------
-- V1.0.54: ilk atis gecikmesi logu, ayarlar satiri, alt secenek gorunurlugu, log silme isareti, olum temizligi
-------------------------------------------------------------------------------
do
    W.sees[2], W.speed, W.flags, W.lag = false, 0, 1, 12
    W.head_dmg[2] = 120
    tick(12)
    before = #prints + 1
    fire("aim_fire", { id = 5401, target = 2, hitgroup = 1, damage = 120, hit_chance = 80, backtrack = 0, x = 500, y = 0, z = 70 })
    fire("aim_miss", { id = 5401, target = 2, hitgroup = 1, reason = "spread" })
    local det = printed("dbg atis-detay:", before)
    check(det ~= nil and det:find("vurulabilir %d+%.%d+s") ~= nil and det:find("ates-hakki ", 1, true) ~= nil,
        "V1.0.54: ilk atista vurulabilir / ates-hakki gecikmesi (" .. tostring(det) .. ")")
    W.head_dmg[2] = 0
    tick(10)
    for _, label in ipairs({ "Extended desync (roll)", "Head unless body kills (snipers)", "Desync keeper: slow crouch-walk when seen" }) do
        local r = find_ref(label)
        check(r ~= nil and r.callback ~= nil, "V1.0.54: '" .. label .. "' degisince alt secenekler guncellenir")
    end
    local clear = find_ref("Clear saved logs")
    if clear ~= nil and type(clear.value) == "function" then
        clear.value()
        check(files["nykle_log.txt"] ~= nil and files["nykle_log.txt"]:find("yuklendi (loglar silindi)", 1, true) ~= nil,
            "V1.0.54: log silinince surum isareti yeniden yazilir")
    else
        check(false, "V1.0.54: Clear saved logs butonu bulunamadi")
    end
    before = #prints + 1
    fire("level_init")
    local set = printed("dbg ayarlar:", before)
    check(set ~= nil and set:find("accuracy boost", 1, true) ~= nil and set:find("ping spike", 1, true) ~= nil,
        "V1.0.54: ayarlar satirinda dogruluk ayarlari ve ping spike (" .. tostring(set) .. ")")
    before = #prints + 1
    fire("player_death", { userid = 1, attacker = 2, headshot = false, penetrated = 0, weapon = "ssg08" })
    local errs54 = errors_since(before)
    check(#errs54 == 0, "V1.0.54: olum temizligi hatasiz" .. (#errs54 > 0 and (": " .. errs54[1]) or ""))
    tick(10)
end

-------------------------------------------------------------------------------
-- V1.0.55: DT ciftinin ikinci mermisi resolver iskasi sayilir; Auto AFK tasimasi bir kez; log surumu veritabaninda
-------------------------------------------------------------------------------
do
    W.sees[2], W.lag, W.total_hits = false, 12, 0
    tick(5)
    fire("aim_fire", { id = 5501, target = 2, hitgroup = 1, damage = 120, hit_chance = 90, backtrack = 0, x = 500, y = 0, z = 70 })
    fire("aim_fire", { id = 5502, target = 2, hitgroup = 1, damage = 120, hit_chance = 90, backtrack = 0, x = 500, y = 0, z = 70 })
    fire("player_hurt", { userid = 2, attacker = 1, dmg_health = 92, hitgroup = 3, weapon = "ssg08" })
    W.total_hits = 1
    fire("aim_hit", { id = 5501, target = 2, hitgroup = 3, damage = 92 })
    before = #prints + 1
    fire("aim_miss", { id = 5502, target = 2, hitgroup = 1, reason = "?" })
    local l55 = printed("atis: dusman2", before)
    check(l55 ~= nil and l55:find("iska correction", 1, true) ~= nil,
        "V1.0.55: ilk mermi isabet edince ikinci merminin resolver iskasi 'damage rejection' degil (" .. tostring(l55) .. ")")
    W.total_hits = 0
    local aa = find_ref("  » Auto AFK (no input 8 s after spawn)")
    if aa ~= nil then
        aa.value = true
        fire("post_config_load")
        check(aa.value == true, "V1.0.55: Auto AFK tasimasi bir kez; sonra elle acilan kalir")
        aa.value = false
    else
        check(false, "V1.0.55: Auto AFK secenegi bulunamadi")
    end
    check(db.nykle_win_gs_logver ~= nil and db.nykle_win_gs_logver:find("^1%.0%.") ~= nil, "V1.0.55: log surumu veritabaninda")
    tick(10)
end

-------------------------------------------------------------------------------
-- V1.0.56: Enable kapaliyken developer geri verilir
-------------------------------------------------------------------------------
do
    local en = find_ref("Enable Nykle.win")
    tick(70)
    check(dev.value == 0, "V1.0.56 kurulum: sessiz logda developer 0")
    en.value = false
    tick(70)
    check(dev.value == 1, "V1.0.56: Enable kapaliyken developer senin degerin (" .. tostring(dev.value) .. ")")
    en.value = true
    tick(70)
end

-------------------------------------------------------------------------------
-- V1.0.57: roll acilinca en iyi ayar (45), onerilen ayarlar acikken kapanmaz, kafa yiyince taraf ters
-------------------------------------------------------------------------------
do
    local rm, rv, rr = find_ref("Extended desync (roll)"), find_ref("  » Roll"), find_ref("Roll")
    W.flags, W.speed, W.sees[2] = 1, 0, false
    rec_ref.value = true
    rv.value = 20
    rm.value = true
    tick(70)
    check(rm.value == true, "V1.0.57: onerilen ayarlar acikken roll acik kalir")
    check(rv.value == 45, "V1.0.57: roll acilinca deger 45 (en iyi) olur (" .. tostring(rv.value) .. ")")
    local cc = find_ref("Desync keeper: slow crouch-walk when seen")
    cc.value = true
    tick(70)
    check(cc.value == true, "V1.0.57: onerilen ayarlar acikken desync keeper acilabilir")
    local first = rr.value
    check(first == 45 or first == -45, "V1.0.57 kurulum: roll uygulanir (" .. tostring(first) .. ")")
    W.sees[2] = true
    tick(3)
    before = #prints + 1
    fire("player_hurt", { userid = 1, attacker = 2, dmg_health = 20, hitgroup = 1, weapon = "ssg08" })
    check(printed("roll: kafa yendi", before) ~= nil, "V1.0.57: roll'luyken kafa yenince roll tarafi ters cevrilir")
    W.sees[2] = false
    tick(3)
    rm.value = false
    rec_ref.value = false; hyp_ref.value = true -- hyp
    tick(10)
end

-------------------------------------------------------------------------------
-- V1.0.48: taban kaymasi (v42-v47: roundun ilk atisindan once sebepsiz okumalar 63 dolu / 133 yarim, sh 4-9 duz;
-- atistan sonra 54 dolu / 9 yarim). Sebepsiz (atis / aim / teleport / DT acilisi yok) duz duran shift doludur.
-------------------------------------------------------------------------------
do
    force_ref.value, cooldown_ref.value, rec_ref.value = true, false, false
    W.sees[2], W.speed, W.flags = false, 0, 1
    W.lag = 0; tick(4)
    fire("round_start", {})
    W.head_dmg[2], W.body_dmg[2], W.sim_shift[2], W.sees[3] = 0, 0, 0, false
    W.lag = 12; tick(64)          -- dolu; tutulan shift tavani 10 yapar
    W.lag = 6; tick(64 * 2)       -- sarjsiz fark 6 tick kaydi: dolu sarj sh 6 okunur, sebep yok
    W.sees[2] = true; tick(5)
    before = #prints + 1
    fire("player_hurt", { userid = 1, attacker = 2, dmg_health = 5, hitgroup = 3, weapon = "ssg08" })
    local l48 = printed("vuruldun:", before)
    check(l48 ~= nil and l48:find("DT dolu", 1, true) ~= nil,
        "V1.0.48: sebepsiz duz sh 6 (taban kaymasi) DT dolu okunur (" .. tostring(l48) .. ")")
    check(last_cmd.force_defensive == true, "V1.0.48: kaymis tabanda goruluyorken defensive zorlanir")
    -- Atis penceresinde (1.5 sn) duzluk ogrenilmez: atistan sonraki gercek dusus yarim kalir.
    fire("weapon_fire", { userid = 1, weapon = "weapon_ssg08" })
    W.lag = 1; tick(60)
    before = #prints + 1
    fire("player_hurt", { userid = 1, attacker = 2, dmg_health = 5, hitgroup = 3, weapon = "ssg08" })
    l48 = printed("vuruldun:", before)
    check(l48 ~= nil and l48:find("DT %", 1, true) ~= nil,
        "V1.0.48: atistan sonra 1.5 sn icinde duz dusuk shift yine yarim sarj (" .. tostring(l48) .. ")")
    W.sees[2], W.lag = false, 12; tick(64 * 2)
end

-------------------------------------------------------------------------------
-- V1.0.60: olduren isabet duello satirinda sayilir (player_death aim_hit'ten once gelir)
-------------------------------------------------------------------------------
do
    W.sees[2], W.head_dmg[2] = true, 120
    tick(10)
    fire("aim_fire", { id = 6101, target = 2, hitgroup = 1, damage = 120, hit_chance = 90, backtrack = 0, x = 500, y = 0, z = 70 })
    before = #prints + 1
    fire("player_death", { userid = 2, attacker = 1, headshot = true, penetrated = 0, weapon = "ssg08" })
    fire("aim_hit", { id = 6101, target = 2, hitgroup = 1, damage = 120 })
    local dl = printed("dbg duello: dusman2", before)
    check(dl ~= nil and dl:find("sen: 1 ates 1 isabet | oldurdun", 1, true) ~= nil,
        "V1.0.60: olduren atis duelloda isabet sayilir (" .. tostring(dl) .. ")")
    fire("player_spawn", { userid = 2 })
    tick(10)
    -- Iskadan sonra bombayla olum: isabet sayilmaz.
    fire("aim_fire", { id = 6102, target = 2, hitgroup = 1, damage = 120, hit_chance = 90, backtrack = 0, x = 500, y = 0, z = 70 })
    fire("aim_miss", { id = 6102, target = 2, hitgroup = 1, reason = "spread" })
    before = #prints + 1
    fire("player_death", { userid = 2, attacker = 1, headshot = false, penetrated = 0, weapon = "hegrenade" })
    dl = printed("dbg duello: dusman2", before)
    check(dl ~= nil and dl:find("sen: 1 ates 0 isabet | oldurdun", 1, true) ~= nil,
        "V1.0.60: iskadan sonra bomba olumu isabet sayilmaz (" .. tostring(dl) .. ")")
    fire("player_spawn", { userid = 2 })
    W.head_dmg[2] = 0
    tick(10)
end

-------------------------------------------------------------------------------
-- V1.0.64: DT doluyken kayan sarj tabani 2 sn sebepsiz dusuk okumadan sonra duzelir
-------------------------------------------------------------------------------
do
    W.sees[2], W.sees[3], W.speed, W.flags = false, false, 0, 1
    W.lag = 12
    dt_ref.value = false
    tick(10) -- DT kapaliyken taban = dolu offset (kayma)
    dt_ref.value = true
    tick(20)
    before = #prints + 1
    fire("player_hurt", { userid = 1, attacker = 2, dmg_health = 1, hitgroup = 3, weapon = "ssg08" })
    local l1 = printed("vuruldun:", before)
    tick(200)
    before = #prints + 1
    fire("player_hurt", { userid = 1, attacker = 2, dmg_health = 1, hitgroup = 3, weapon = "ssg08" })
    local l2 = printed("vuruldun:", before)
    check(l1 ~= nil and l1:find("DT %0", 1, true) ~= nil and l2 ~= nil and l2:find("DT dolu", 1, true) ~= nil,
        "V1.0.64: kayan DT tabani duzelir (once " .. tostring(l1 and l1:match("DT [^,]+")) .. ", sonra " .. tostring(l2 and l2:match("DT [^,]+")) .. ")")
    tick(10)
end

-------------------------------------------------------------------------------
-- V1.0.64: DM (round_start yok): dogusta 60 sn'de bir round ozeti / sifirlama; normal haritada dogus tekrarlamaz
-------------------------------------------------------------------------------
do
    fire("round_start")
    tick(20)
    W.tick = W.tick + 64 * 61 -- uzun round (normal harita)
    tick(20)
    before = #prints + 1
    fire("player_spawn", { userid = 1 })
    check(printed("dbg sen ozeti", before) == nil, "V1.0.64: normal haritada (round_start var) dogus round islerini calistirmaz")
    fire("level_init") -- DM haritasi: round_start hic gelmez
    tick(20)
    before = #prints + 1
    fire("player_spawn", { userid = 1 })
    check(printed("dbg ===== round", before) ~= nil, "V1.0.64: DM'de ilk dogusta round isleri calisir")
    tick(20)
    before = #prints + 1
    fire("player_spawn", { userid = 1 })
    check(printed("dbg ===== round", before) == nil, "V1.0.64: DM'de 60 sn dolmadan tekrar calismaz")
    W.tick = W.tick + 64 * 61
    tick(20)
    before = #prints + 1
    fire("player_spawn", { userid = 1 })
    check(printed("dbg sen ozeti", before) ~= nil and printed("dbg ===== round", before) ~= nil,
        "V1.0.64: DM'de 60 sn sonra dogusta round ozeti yazilir")
    tick(10)
end

-------------------------------------------------------------------------------
-- V1.0.64: durum degisince onceki durumun deseni bu durumun "desen degisimi" sayilmaz
-------------------------------------------------------------------------------
do
    W.eyaw = {}
    W.sees[3], W.head_dmg[3] = true, 100
    W.evel[3] = 0
    tick(200) -- Standing: statik
    before = #prints + 1
    for cycle = 1, 4 do
        W.evel[3] = 130 -- Slow walk / Moving: jitter
        for i = 1, 50 do
            W.eyaw[3] = (i % 2 == 0) and 120 or -120
            tick(1)
        end
        W.evel[3], W.eyaw[3] = 0, 180 -- Standing: statik
        tick(50)
    end
    local k = printed("dusman3 Standing AA deseni kararsiz", before)
    check(k == nil, "V1.0.64: durumlar arasi gidip gelen dusmanda Standing 'kararsiz' sayilmaz (" .. tostring(k) .. ")")
    W.eyaw, W.head_dmg[3], W.sees[3] = nil, 0, false
    tick(20)
end

-------------------------------------------------------------------------------
-- V1.0.66: ping spike kapali, scout'ta quick stop Early; ayar satiri ikisini de gosterir
-------------------------------------------------------------------------------
do
    local ps, qs, qso = find_ref("Ping spike"), find_ref("Quick stop"), find_ref("Quick stop options")
    local po, qe = find_ref("Disable ping spike"), find_ref("Quick stop: Early for scout / AWP")
    check(po ~= nil and po.value == true and qe ~= nil and qe.value == true, "V1.0.66: iki secenek var ve varsayilan acik")
    -- Onceki testlerin config yuklemesi ezme kayitlarini unutturdu: config yuklenmis gibi senin degerlerin yazilir.
    ps.value, qso.value = true, { "Slow motion" }
    fire("post_config_load")
    tick(5)
    check(ps.value == false, "V1.0.66: ping spike kapatildi (" .. tostring(ps.value) .. ")")
    local o = qso.value
    check(type(o) == "table" and o[1] == "Early" and o[2] == "Slow motion",
        "V1.0.66: scout'ta quick stop secenekleri Early + senin secimin (" .. (type(o) == "table" and table.concat(o, "+") or tostring(o)) .. ")")
    before = #prints + 1
    fire("level_init")
    local set = printed("dbg ayarlar:", before)
    check(set ~= nil and set:find("quick stop true tus false [Early+Slow motion]", 1, true) ~= nil and set:find("100ms", 1, true) ~= nil,
        "V1.0.66: ayar satiri quick stop secenekleri ve ping spike ms (" .. tostring(set and set:match("quick stop.*")) .. ")")
    po.value, qe.value = false, false
    tick(5)
    o = qso.value
    check(ps.value == true and type(o) == "table" and #o == 1 and o[1] == "Slow motion",
        "V1.0.66: kapatinca senin ping spike ve quick stop ayarin geri (" .. tostring(ps.value) .. ", " .. (type(o) == "table" and table.concat(o, "+") or "?") .. ")")
    po.value, qe.value = true, true
    tick(5)
end

-------------------------------------------------------------------------------
-- V1.0.70: round basinda bomba alimi (HE + sis + molotof)
-------------------------------------------------------------------------------
do
    local ab = find_ref("Auto buy grenades")
    check(ab ~= nil and ab.value == true, "V1.0.70: bomba alimi secenegi var, varsayilan acik")
    local dc = client.delay_call
    client.delay_call = function(_, fn, ...) fn(...) end
    local n0 = #execs
    W.tick = W.tick + 64 * 5
    fire("round_start")
    local got = false
    for i = n0 + 1, #execs do
        if execs[i]:find("buy hegrenade", 1, true) and execs[i]:find("buy smokegrenade", 1, true) and execs[i]:find("buy molotov", 1, true) then got = true end
    end
    check(got, "V1.0.70: round basinda HE + sis + molotof alinir")
    ab.value = false
    n0 = #execs
    W.tick = W.tick + 64 * 5
    fire("round_start")
    local again = false
    for i = n0 + 1, #execs do
        if execs[i]:find("buy hegrenade", 1, true) then again = true end
    end
    check(not again, "V1.0.70: secenek kapaliyken alim yok")
    ab.value = true
    client.delay_call = dc
    tick(10)
end

-------------------------------------------------------------------------------
-- V1.0.71: granat yardimcisi (nisangahtaki dusmana molotof; molotofun icindeyken sis ayaga)
-------------------------------------------------------------------------------
do
    check(find_ref("Grenade helper: throw molly") ~= nil and find_ref("Grenade helper: throw molly").value == false
        and find_ref("Grenade helper: smoke at feet") ~= nil and find_ref("Grenade helper: smoke at feet").value == false,
        "V1.0.74: granat yardimcisi secenekleri var, varsayilan kapali")
    find_ref("Grenade helper: throw molly").value, find_ref("Grenade helper: smoke at feet").value = true, true
    ORIGIN[2], ORIGIN[3] = { 500, 0, 0 }, { 0, 2000, 0 }
    W.cam_yaw, W.next_attack, W.flags, W.speed = 0, 0, 1, 0
    tick(30)
    W.weapon_class = "CMolotovGrenade"
    before = #prints + 1
    tick(1)
    local l = printed("granat: molotof -> dusman2", before)
    local pulled = last_cmd.in_attack == 1
    tick(4)
    local rel_pitch, rel_yaw, rel_attack = last_cmd.pitch, last_cmd.yaw, last_cmd.in_attack
    local aa_on = find_ref("Enabled").value
    check(aa_on == false, "V1.0.72: granat atilirken GameSense AA kapali (" .. tostring(aa_on) .. ")")
    check(l ~= nil and pulled and rel_attack == 0 and finite_num(rel_pitch) and rel_pitch > -10 and rel_pitch < 20 and math.abs(rel_yaw or 99) < 1,
        "V1.0.71: nisangahtaki dusmana molotof (pim, sonra hesapli aci) (" .. tostring(l) .. ", pitch " .. tostring(rel_pitch) .. ", yaw " .. tostring(rel_yaw) .. ")")
    tick(130)
    W.weapon_class = "CSmokeGrenade"
    before = #prints + 1
    fire("player_hurt", { userid = 1, attacker = 2, dmg_health = 4, hitgroup = 0, weapon = "inferno" })
    tick(1)
    tick(4)
    check(printed("granat: molotofun icindesin -> sis ayagina", before) ~= nil and last_cmd.pitch == 89,
        "V1.0.71: molotofun icindeyken sis ayaga (pitch " .. tostring(last_cmd.pitch) .. ")")
    W.weapon_class = "CWeaponSSG08"
    ORIGIN[2], ORIGIN[3] = { 500, 0, 0 }, { 0, 500, 0 }
    tick(130)
    check(find_ref("Enabled").value == true, "V1.0.72: atis bitince AA geri acik")
    find_ref("Grenade helper: throw molly").value, find_ref("Grenade helper: smoke at feet").value = false, false
end

-------------------------------------------------------------------------------
-- V1.0.75: yan duran statik rakipte kol / seri / brute body yaw zorlamaz, kafa GameSense'te
-------------------------------------------------------------------------------
do
    side_ref.value = true
    W.sees[3], W.head_dmg[3], W.evel[3] = true, 100, 0
    W.eyaw = nil
    tick(10)
    before = #prints + 1
    for i = 1, 4 do
        tick(6)
        fire("aim_fire", { id = 7500 + i, target = 3, hitgroup = 1, damage = 120, hit_chance = 90, backtrack = 0, x = 500, y = 0, z = 70 })
        fire("aim_miss", { id = 7500 + i, target = 3, hitgroup = 1, reason = "?" })
    end
    tick(6)
    check(plist.get(3, "Force body yaw") ~= true and printed("yan duruyor (statik): body yaw zorlanmaz", before) ~= nil,
        "V1.0.75: yan duran statik rakibe body yaw zorlanmaz (" .. tostring(plist.get(3, "Force body yaw")) .. ")")
    W.head_dmg[3], W.sees[3] = 0, false
    tick(10)
end

-------------------------------------------------------------------------------
-- V1.0.76: sol gosterge listesi (renderer.indicator): DT yesil (dolu)
-------------------------------------------------------------------------------
do
    local li = find_ref("Left indicators")
    check(li ~= nil and li.value == true, "V1.0.76: sol gosterge secenegi var, varsayilan acik")
    W.lag = 12
    tick(40)
    for k in pairs(indicators) do indicators[k] = nil end
    fire("paint")
    local dt = nil
    for _, x in ipairs(indicators) do if x.text == "DT" then dt = x end end
    check(dt ~= nil and dt.g == 195, "V1.0.76: DT doluyken solda yesil DT (" .. tostring(dt and dt.g) .. ")")
end

-------------------------------------------------------------------------------
-- V1.0.77: varsayilan ayarla (hipotez / kol / seri kapali) hicbir rakibe body yaw zorlanmaz; govde yedegi calisir
-------------------------------------------------------------------------------
do
    hyp_ref.value = false
    W.sees[2], W.speed, W.flags, W.elby[2], W.head_dmg[2], W.body_dmg[2] = true, 0, 1, 130, 120, 86
    tick(20)
    check(plist.get(2, "Force body yaw") ~= true, "V1.0.77: varsayilan ayarla body yaw zorlanmaz (" .. tostring(plist.get(2, "Force body yaw")) .. ")")
    before = #prints + 1
    for i = 1, 3 do
        tick(6)
        fire("aim_fire", { id = 7700 + i, target = 2, hitgroup = 1, damage = 120, hit_chance = 90, backtrack = 0, x = 500, y = 0, z = 70 })
        fire("aim_miss", { id = 7700 + i, target = 2, hitgroup = 1, reason = "?" })
    end
    check(printed("zemin kafa iskasi (statik", before) ~= nil, "V1.0.77: zorlama kapaliyken de GS kafa iskalarindan govde yedegi tetiklenir")
    check(printed("GS yerine body yaw", before) == nil, "V1.0.79: hipotezler kapaliyken 'GS yerine body yaw' yazilmaz")
    W.sees[2], W.elby[2], W.head_dmg[2], W.body_dmg[2] = false, nil, 0, 0
    tick(10)
end

-------------------------------------------------------------------------------
-- V1.0.80: DT durumunda havada DT kapanmaz, sarj inise saklanir; tek discharge batch yerde bitecek sekilde
-- (inise <= S - 3 tick kala). Havada teleport kapaliyken V1.0.78/79 (havada DT / HS kapali) aynen.
-------------------------------------------------------------------------------
do
    local ti = W.interval
    local hs_ref = find_ref("On shot anti-aim")
    -- Bir ucus: kalkis tick'i (yerde, ziplama basili; opts.z verilirse kalkis yok: kenardan dusme), havada
    -- vz -= 400 ti; z += vz ti; vz -= 400 ti; z <= 0 -> yerde. Inisten sonra opts.after (4) yer tick'i.
    -- Donus: kayitlar (i = 0 kalkis), inis indeksi, discharge indeksleri.
    local function fly(opts)
        opts = opts or {}
        local rec, land, fires = {}, nil, {}
        local function record(i, phase)
            local r = { i = i, phase = phase, dt = dt_ref.value, fd = last_cmd.force_defensive,
                dp = last_cmd.discharge_pending, jump = last_cmd.in_jump, z = W.z, hs = hs_ref.value }
            rec[#rec + 1] = r
            if r.dp == true then fires[#fires + 1] = i end
            return r
        end
        W.jump = opts.jump ~= false
        local i = 0
        if opts.z == nil then
            W.z, W.vz, W.flags = 0, 0, 1
            if opts.each then opts.each(i) end
            tick(1)
            record(i, "takeoff")
            W.vz = 301.99
        else
            W.z, W.vz = opts.z, opts.vz or 0
            if opts.jump == nil then W.jump = nil end
        end
        W.flags = 0
        for _ = 1, 200 do
            i = i + 1
            W.vz = W.vz - 400 * ti
            W.z = W.z + W.vz * ti
            W.vz = W.vz - 400 * ti
            if W.z <= 0 then
                W.z, W.vz, W.flags = 0, 0, 1
            end
            if opts.each then opts.each(i) end
            tick(1)
            if W.flags == 1 then
                land = i
                record(i, "ground1")
                break
            end
            record(i, "air")
        end
        for g = 2, opts.after or 4 do
            i = i + 1
            if opts.each then opts.each(i) end
            tick(1)
            record(i, "ground" .. g)
        end
        return rec, land, fires
    end
    local function settle(n)
        W.jump, W.z, W.vz, W.flags = nil, 0, 0, 1
        tick(n or 20)
    end
    local function at(rec, i)
        for _, r in ipairs(rec) do if r.i == i then return r end end
        return nil
    end
    local function inise_n(line)
        local n = line and line:match("inise (%-?%d+) tick kala")
        return n and tonumber(n) or nil
    end

    airlc_ref.value = true
    local tp_ref = find_ref("Teleport in air when seen")
    check(tp_ref ~= nil and tp_ref.value == true, "V1.0.80 kurulum: havada teleport varsayilan acik")
    W.floor_z, W.lag, W.speed = 0, 12, 240
    -- Kafamizi goruyor; bizim ondan gecen mermimiz Min. damage'i gecmiyor (temiz atis yok; (i)'de var).
    W.sees[2], W.sees[3], W.head_dmg[2], W.body_dmg[2] = true, false, 0, 0
    settle(20)
    check(dt_ref.value == true, "V1.0.80 kurulum: yerde DT acik")

    -- (a) + (b): DT durumunda goruluyorken
    local before80 = #prints + 1
    local rec, land, fires = fly({ after = 4 })
    local dt_all, fd_ok, bad = true, true, nil
    for _, r in ipairs(rec) do
        if r.dt ~= true then dt_all, bad = false, bad or (r.phase .. " " .. r.i) end
        if r.phase ~= "ground3" and r.phase ~= "ground4" and r.fd == true then fd_ok, bad = false, bad or ("def " .. r.phase .. " " .. r.i) end
    end
    check(land ~= nil and dt_all, "V1.0.80 (a): DT durumunda goruluyorken kalkis, havada ve yerde 1-3. tick DT hep acik ("
        .. tostring(bad) .. ", inis " .. tostring(land) .. ")")
    check(fd_ok, "V1.0.80 (a): kalkistan yerde 2. tick'e kadar defensive zorlanmaz (" .. tostring(bad) .. ")")
    local f1 = fires[1]
    check(#fires == 1 and land ~= nil and land - f1 >= 1 and land - f1 <= 12,
        "V1.0.80 (b): ziplamada tek discharge, inisten 1-12 tick once (" .. #fires .. " kez, ates " .. tostring(f1)
        .. ", inis " .. tostring(land) .. ")")
    local rf, r1, r2, r3 = f1 and at(rec, f1), f1 and at(rec, f1 + 1), f1 and at(rec, f1 + 2), f1 and at(rec, f1 + 3)
    -- V1.0.84: yerde tutma acikken 3. komutta da (ve tutma boyunca) ziplama engelli; eski "3. komutta yine basili"
    -- davranisi secenek kapaliyken (asagida, V1.0.84 testleri).
    check(rf ~= nil and rf.jump == 0 and r1 ~= nil and r1.jump == 0 and r2 ~= nil and r2.jump == 0 and r3 ~= nil and r3.jump == 0,
        "V1.0.84 (b): ates komutunda ve sonraki komutlarda ziplama bastirilir (yerde tutma) ("
        .. tostring(rf and rf.jump) .. tostring(r1 and r1.jump) .. tostring(r2 and r2.jump) .. tostring(r3 and r3.jump) .. ")")
    local fl = printed("teleport: inise ", before80)
    local n80 = inise_n(fl)
    check(n80 ~= nil and land ~= nil and f1 ~= nil and math.abs(n80 - (land - f1)) <= 1,
        "V1.0.80 (b): 'inise N tick kala' satiri, N olculen inisle +-1 (" .. tostring(fl) .. ")")
    local sl = printed("teleport sonucu: tahmin", before80)
    check(sl ~= nil and sl:find("paket yerde", 1, true) ~= nil, "V1.0.80: yerde 3. tick'te inis teleportunun sonuc satiri (" .. tostring(sl) .. ")")
    check(printed("teleport: havada goruldun", before80) == nil, "V1.0.80: eski 'havada goruldun' teleportu DT durumunda yok")
    -- Inceleme: havada basili tutulan bosluk "tekrar ziplama" degil; yere degip 1-2 tick icinde havalanmak oyle.
    check(sl ~= nil and sl:find("tekrar ziplama hayir", 1, true) ~= nil,
        "V1.0.80 (inceleme): havada basili bosluk 'tekrar ziplama' sayilmaz (" .. tostring(sl) .. ")")
    settle(20)
    local brj = #prints + 1
    local _, _, frj = fly({ after = 1 })
    W.flags, W.z, W.vz = 0, 2, 250
    tick(1)
    local rjl = printed("teleport sonucu: tahmin", brj)
    check(#frj == 1 and rjl ~= nil and rjl:find("tekrar ziplama evet", 1, true) ~= nil,
        "V1.0.80 (inceleme): inis teleportundan sonra yere degip yeniden havalanmak 'tekrar ziplama evet' ("
        .. #frj .. ", " .. tostring(rjl) .. ")")

    -- (c): kimse gormuyor
    W.sees[2] = false
    settle(40)
    before80 = #prints + 1
    rec, land, fires = fly({})
    dt_all = true
    for _, r in ipairs(rec) do if r.dt ~= true then dt_all = false end end
    check(#fires == 0 and printed("inise yok", before80) == nil and dt_all,
        "V1.0.80 (c): kimse gormezken discharge yok, 'inise yok' satiri yok, DT acik (" .. #fires .. ", " .. tostring(dt_all) .. ")")
    W.sees[2] = true

    -- (d): hiz
    local function speed_case(sp)
        W.speed = sp
        settle(20)
        local b = #prints + 1
        local rc, ld, fs = fly({})
        return fs, ld, b, rc
    end
    local fs, ld, b = speed_case(150)
    local yl = printed("yavas 3D", b)
    check(#fs == 0 and yl ~= nil and yl:find("inise yok", 1, true) ~= nil,
        "V1.0.80 (d): 150 u/s'de discharge yok, yerde 3. tick'te 'inise yok (yavas 3D ..)' (" .. tostring(yl) .. ")")
    fs, ld, b = speed_case(200)
    check(#fs == 0 and printed("yavas 3D", b) ~= nil,
        "V1.0.80 (d): 200 u/s'de de 3D < 64, discharge yok, sebep 'yavas 3D' (" .. tostring(printed("inise yok", b)) .. ")")
    fs, ld, b = speed_case(240)
    check(#fs == 1, "V1.0.80 (d): 240 u/s'de atilir (" .. #fs .. ", " .. tostring(printed("teleport: inise", b)) .. ")")

    -- (e): sarj yok
    W.lag = 0
    settle(20)
    b = #prints + 1
    rec, land, fires = fly({})
    local el = printed("inise yok", b)
    check(#fires == 0 and el ~= nil and el:find("sarj", 1, true) ~= nil,
        "V1.0.80 (e): sarj yokken discharge yok, sebep 'sarj' (" .. tostring(el) .. ")")
    W.lag = 12

    -- (f): sniper Hide shots (SSG08) havada goruluyorken: V1.0.79 aynen (havada DT ve HS kapali), discharge yok
    sniper_ref.value = "Hide shots"
    settle(20)
    local hs_ground = hs_ref.value
    rec, land, fires = fly({})
    local dt_air, hs_air, n_air = false, false, 0
    for _, r in ipairs(rec) do
        if r.phase == "air" and r.i >= 3 then
            n_air = n_air + 1
            dt_air = dt_air or r.dt == true
            hs_air = hs_air or r.hs == true
        end
    end
    check(hs_ground == true and n_air > 0 and not dt_air and not hs_air and #fires == 0,
        "V1.0.80 (f): sniper Hide shots: yerde HS, havada (goruluyorken) DT ve HS kapali, discharge yok (V1.0.79) (yerde hs "
        .. tostring(hs_ground) .. ", havada dt " .. tostring(dt_air) .. " hs " .. tostring(hs_air) .. ", " .. #fires .. ")")
    sniper_ref.value = "Same as state"
    settle(20)

    -- (g): havada teleport kapali -> V1.0.78/79 kurallari
    tp_ref.value = false
    W.flags, W.speed, W.lag, W.z, W.vz = 1, 0, 12, nil, nil
    W.sees[2] = false
    tick(20)
    check(dt_ref.value == true, "V1.0.78 kurulum: yerde DT acik")
    W.flags, W.speed = 0, 200
    tick(10)
    check(dt_ref.value == true, "V1.0.79: havada kimse gormuyorsa DT acik kalir (inince yeniden sarj yok) (" .. tostring(dt_ref.value) .. ")")
    W.flags, W.speed = 1, 0
    tick(20)
    W.sees[2], W.head_dmg[2] = true, 120
    tick(10)
    W.flags, W.speed = 0, 200
    tick(10)
    check(dt_ref.value == false, "V1.0.78: havada (gorulurken) DT kapali (fake lag tam, LC kirilir) (" .. tostring(dt_ref.value) .. ")")
    W.sees[2] = false
    tick(4)
    check(dt_ref.value == false, "V1.0.79: havada basladiysa inene kadar kapali kalir")
    W.flags, W.speed = 1, 0
    tick(20)
    check(dt_ref.value == true, "V1.0.78: yere inince DT geri acik")
    tp_ref.value = true
    W.sees[2], W.head_dmg[2], W.speed = true, 0, 240

    -- (h): kenardan dusme (100 birim, vz 0): inis ~32 tick sonra. Sahte dunyada tickbase sabit: havada kapanan DT'nin
    -- sarji ancak 2 sn duz okumadan sonra (charge.low_n) yeniden dolu sayilir.
    settle(150)
    b = #prints + 1
    rec, land, fires = fly({ z = 100, vz = 0 })
    check(land ~= nil and land >= 28 and land <= 36 and #fires == 1 and land - fires[1] >= 1 and land - fires[1] <= 12,
        "V1.0.80 (h): 100 birimden dusus ~32 tick, tek discharge inisten 1-12 tick once (inis " .. tostring(land) .. ", ates "
        .. tostring(fires[1]) .. ")")

    -- (i): temiz atis penceresi. V1.0.84: hizli ucusta (240 u/s) teleportu engellemez, yerinde ziplarken (40 u/s)
    -- engeller (jump scout).
    W.head_dmg[2], W.body_dmg[2], W.next_attack = 150, 150, 0
    settle(20)
    b = #prints + 1
    rec, land, fires = fly({})
    check(#fires == 1 and printed("teleport: inise ", b) ~= nil and printed("inise yok (temiz atis)", b) == nil,
        "V1.0.84 (i): hizli ucusta temiz atis penceresi inis teleportunu engellemez (" .. #fires .. ")")
    settle(60)
    W.speed = 40
    settle(20)
    b = #prints + 1
    rec, land, fires = fly({})
    local il = printed("inise yok", b)
    check(#fires == 0 and il ~= nil and il:find("temiz atis", 1, true) ~= nil,
        "V1.0.84 (i): yerinde ziplarken temiz atis varken discharge yok, sebep 'temiz atis' (" .. tostring(il) .. ")")
    W.speed = 240

    -- (j): dolu DT kapaninca tickbase olcumu
    W.head_dmg[2], W.body_dmg[2], W.speed = 0, 0, 0
    settle(20)
    local ex_ref = find_ref("Exploit\nStanding")
    b = #prints + 1
    ex_ref.value = "Hide shots"
    tick(6)
    local jl = printed("DT kapandi (sarj dolu): tickbase +0", b)
    check(dt_ref.value == false and jl ~= nil, "V1.0.80 (j): dolu DT kapaninca tickbase olculur (" .. tostring(jl) .. ")")
    ex_ref.value = "Double tap"
    settle(20)

    -- Inceleme (1): yerde "Block jump while seen" ziplamayi iptal ederken (bosluk basili, durum Air) DT'li ucus yok:
    -- V1.0.79 gibi Smart / air_lag defensive zorlanir.
    settle(200) -- (j)'de kapanan DT'nin sarji yeniden dolu sayilsin (exploit_active, charge.low_n 128 sakin tick)
    W.speed, W.sees[2], W.next_attack = 240, true, 1e9
    local njr = find_ref("Block jump while seen (not jump-scout)")
    local fv = force_ref.value
    force_ref.value = true
    njr.value = true
    W.jump = true
    tick(10)
    local nj_fd, nj_jump, nj_dt = last_cmd.force_defensive, last_cmd.in_jump, dt_ref.value
    njr.value, force_ref.value = false, fv
    W.next_attack = 0
    settle(20)
    check(nj_jump == 0 and nj_fd == true and nj_dt == true,
        "V1.0.80 (inceleme): yerde ziplama engellenirken (goruluyorken) defensive yine zorlanir, DT acik (ziplama "
        .. tostring(nj_jump) .. ", def " .. tostring(nj_fd) .. ", dt " .. tostring(nj_dt) .. ")")

    -- Inceleme (6): yerde 1. tick yedegi havada yazilan sebebi ezmez. Zemin 512 birim icinde yok (tahmin hic yok,
    -- havada "tahmin yok"); yedek h = 0 ile "yavas 3D 56 u" der ama satir "tahmin yok" kalir.
    settle(60)
    W.floor_fn = function() return nil end
    b = #prints + 1
    rec, land, fires = fly({})
    W.floor_fn = nil
    local gl = printed("inise yok", b)
    check(#fires == 0 and gl ~= nil and gl:find("tahmin yok", 1, true) ~= nil,
        "V1.0.80 (inceleme): yerde 1. tick yedegi havadaki sebebi ezmez (" .. #fires .. ", " .. tostring(gl) .. ")")

    -- Inceleme (4): inis noktasinin altina ikinci iz. Inise ~20 tick kala vurulma satirinda tahmin (lt) var; inis
    -- noktasi ucurumsa (x > 15.5'te zemin yok) tahmin yok.
    local function lt_line(floor_fn)
        W.floor_fn = floor_fn
        settle(120)
        local bh, hl = #prints + 1, nil
        fly({ each = function(i)
            if i == 28 then
                fire("player_hurt", { userid = 1, attacker = 2, dmg_health = 5, hitgroup = 2, weapon = "ssg08" })
                hl = printed("vuruldun:", bh)
            end
        end })
        W.floor_fn = nil
        return hl
    end
    local hl_flat = lt_line(nil)
    local hl_cliff = lt_line(function(x) return x <= 15.5 and 0 or nil end)
    check(hl_flat ~= nil and hl_flat:find(" ucus DT lt %d+") ~= nil and hl_cliff ~= nil
        and hl_cliff:find(" ucus DT", 1, true) ~= nil and hl_cliff:find(" lt %d") == nil,
        "V1.0.80 (inceleme): inis noktasi ucurumsa tahmin yok (duz: " .. tostring(hl_flat and hl_flat:match("ucus DT[^|]*"))
        .. ", ucurum: " .. tostring(hl_cliff and hl_cliff:match("ucus DT[^|]*")) .. ")")

    -- Inceleme (2/5): inis teleportundan sonra havada olunce ucus durumu silinir; dogusta sonuc satiri / sapma yok.
    settle(150)
    local died = false
    rec, land, fires = fly({ each = function()
        if not died and last_cmd.discharge_pending == true then
            died, W.dead = true, true
            fire("player_death", { userid = 1, attacker = 2, headshot = true, penetrated = 0, weapon = "ssg08" })
        end
    end })
    W.dead = nil
    b = #prints + 1
    settle(8)
    check(died and #fires == 1 and printed("teleport sonucu: tahmin", b) == nil and printed("inise yok", b) == nil,
        "V1.0.80 (inceleme): havada olunce dogusta eski ucusun sonuc satiri yok (" .. tostring(died) .. ", "
        .. tostring(printed("teleport sonucu: tahmin", b)) .. ")")

    -- V1.0.84: inis teleportundan sonra yerde tutma (istek: "yere isinlanip sonra tekrar yukari zipliyor ve
    -- oluyorum, oto stop da olmasi lazim"). Bosluk basili, dusman goruyor, temiz atis yok.
    do
        local hold_ref = find_ref("  » After landing teleport: stay on ground (no jump + stop)")
        check(hold_ref ~= nil and hold_ref.value == true, "V1.0.84: yerde tutma secenegi var, varsayilan acik")
        W.dead = nil
        W.floor_z, W.lag, W.speed, W.next_attack = 0, 12, 240, 1e9
        W.sees[2], W.sees[3], W.head_dmg[2], W.body_dmg[2] = true, false, 0, 0
        settle(200)
        local hb = #prints + 1
        -- Inisten sonra 40 yer tick'i izlenir; her tick'te ziplama ve hareket girdisi kaydedilir.
        local ground = {}
        local rec84, land84, fires84 = fly({ after = 40 })
        local jumps, counter, stopped_n, first_free = 0, 0, 0, nil
        for _, r in ipairs(rec84) do
            if r.phase:sub(1, 6) == "ground" then
                ground[#ground + 1] = r
            end
        end
        for k, r in ipairs(ground) do
            if r.jump == 1 and first_free == nil then first_free = k end
            if r.jump == 0 then jumps = jumps + 1 end
        end
        check(#fires84 == 1 and land84 ~= nil, "V1.0.84 kurulum: goruluyorken ucus, tek inis teleportu (" .. #fires84 .. ")")
        check(first_free ~= nil and first_free >= 30 and first_free <= 36,
            "V1.0.84: inisten sonra ziplama ~32 yer tick'i engellenir, sonra serbest (ilk serbest yer tick'i "
            .. tostring(first_free) .. ", engelli " .. jumps .. ")")
        local endl = printed("teleport: yerde tutma bitti (sure)", hb)
        check(endl ~= nil and endl:find("ziplama", 1, true) ~= nil, "V1.0.84: tutma bitince satir yazilir (" .. tostring(endl) .. ")")

        -- Oto stop: tutma sirasinda hizin tersine girdi (hiz +x, bakis 0 -> forwardmove -450); durunca sifir.
        settle(200)
        W.speed = 240
        local fm_moving, fm_still, jump_hold = nil, nil, nil
        fly({ after = 12 })
        fm_moving, jump_hold = last_cmd.forwardmove, last_cmd.in_jump
        W.speed = 0
        tick(1)
        fm_still = last_cmd.forwardmove
        check(fm_moving == -450 and fm_still == 0 and jump_hold == 0,
            "V1.0.84: tutma sirasinda hizin tersine girdi (-450), durunca 0, ziplama engelli (" .. tostring(fm_moving) .. ", "
            .. tostring(fm_still) .. ", " .. tostring(jump_hold) .. ")")
        -- Kimse gormuyorsa (en az 8 yer tick'inden sonra) erken biter.
        W.sees[2] = false
        local eb = #prints + 1
        tick(30)
        check(printed("teleport: yerde tutma bitti (kimse gormuyor)", eb) ~= nil or printed("teleport: yerde tutma bitti", eb) ~= nil,
            "V1.0.84: kimse gormuyorken tutma erken biter (" .. tostring(printed("teleport: yerde tutma bitti", eb)) .. ")")
        check(last_cmd.in_jump == 1, "V1.0.84: tutma bitince basili bosluk yine gecer (" .. tostring(last_cmd.in_jump) .. ")")

        -- Secenek kapaliyken eski davranis: ates komutu + 2 komut, 3. komutta ziplama yine basili.
        hold_ref.value = false
        W.sees[2], W.speed = true, 240
        settle(200)
        local rec_off, land_off, fires_off = fly({ after = 6 })
        local fo = fires_off[1]
        local o3 = fo and at(rec_off, fo + 3)
        check(#fires_off == 1 and o3 ~= nil and o3.jump == 1,
            "V1.0.84: secenek kapaliyken 3. komutta ziplama yine basili (" .. tostring(o3 and o3.jump) .. ")")
        hold_ref.value = true
        W.next_attack = 0

        -- V1.0.85: inis teleportu harita icin kapatilinca (art arda iki isinlanmadan sonra vuruldun) ucusta sarj
        -- saklanmaz, defensive yine zorlanir (V1.0.84 logu: o durumda ucus korumasiz kaliyordu).
        W.sees[2], W.speed, W.next_attack = true, 240, 1e9
        local ob = #prints + 1
        for _ = 1, 3 do
            if printed("bu harita boyunca havada teleport kapali", ob) ~= nil then break end
            settle(200)
            fly({ after = 2 })
            tick(12)
            fire("player_hurt", { userid = 1, attacker = 2, dmg_health = 120, hitgroup = 1, weapon = "ssg08" })
            tick(4)
        end
        check(printed("bu harita boyunca havada teleport kapali", ob) ~= nil, "V1.0.85 kurulum: iki isinlanmadan sonra vurulunca teleport harita icin kapanir")
        settle(200)
        local rec_o, land_o, fires_o = fly({ after = 2 })
        local air_fd = 0
        for _, r in ipairs(rec_o) do
            if r.phase == "air" and r.fd == true then air_fd = air_fd + 1 end
        end
        check(#fires_o == 0 and air_fd >= 5, "V1.0.85: teleport kapaliyken ucusta defensive zorlanir (discharge " .. #fires_o
            .. ", havada zorlanan tick " .. air_fd .. ")")
        fire("level_init")
        W.next_attack = 0
        settle(40)
    end

    -- V1.0.85: hizli sarj. Scout elde, DT acik ama bos (lag 0), silah hazir degil (surgu): aimbot kapatilir; DT
    -- dolunca ya da silah hazirlanirken geri acilir; secenek kapaliyken hic dokunulmaz.
    do
        local fc_ref = find_ref("Fast recharge: aimbot off while the bolt cycles and DT is empty (scout / AWP)")
        local rage_ref = find_ref("Rage enabled")
        check(fc_ref ~= nil and fc_ref.value == false and rage_ref ~= nil and rage_ref.value == true,
            "V1.0.85: hizli sarj secenegi var, varsayilan kapali")
        W.flags, W.z, W.vz, W.jump, W.speed = 1, 0, 0, nil, 0
        W.sees[2], W.lag, W.next_attack = false, 0, 1e9
        tick(6)
        local off_untouched = rage_ref.value
        fc_ref.value = true
        local fb = #prints + 1
        tick(6)
        local during = rage_ref.value
        W.lag = 12
        tick(6)
        local after_full = rage_ref.value
        local fl = printed("dbg hizli sarj:", fb)
        W.lag, W.next_attack = 0, 0
        tick(6)
        local weapon_ready_v = rage_ref.value
        W.next_attack = 1e9
        tick(6)
        local again = rage_ref.value
        fc_ref.value = false
        tick(4)
        check(off_untouched == true and during == false and after_full == true and weapon_ready_v == true and again == false
            and rage_ref.value == true,
            "V1.0.85: hizli sarj: surgu + bos DT'de aimbot kapali, DT dolunca / silah hazirken / secenek kapaliyken acik ("
            .. tostring(off_untouched) .. tostring(during) .. tostring(after_full) .. tostring(weapon_ready_v) .. tostring(again)
            .. tostring(rage_ref.value) .. ")")
        check(fl ~= nil and fl:find("DT doldu", 1, true) ~= nil, "V1.0.85: hizli sarj bitince satir yazilir (" .. tostring(fl) .. ")")
        W.lag, W.next_attack = 12, 0
        tick(4)
    end

    W.z, W.vz, W.floor_z, W.jump = nil, nil, nil, nil
    W.sees[2], W.head_dmg[2], W.body_dmg[2], W.speed = false, 0, 0, 0
    W.flags = 1
    tick(10)
    local errs80 = errors_since(1)
    check(#errs80 == 0, "V1.0.80: inis teleportu bolumunde hata yok" .. (#errs80 > 0 and (": " .. errs80[1]) or ""))
end

-------------------------------------------------------------------------------
-- V1.0.79: kafa payi <= %35 (12+ sniper atisi) olan rakibe govde; her 4. atis kafa denemesi
-------------------------------------------------------------------------------
do
    local ext_ref = find_ref("Body vs extended/roll")
    local ext_was = ext_ref.value
    ext_ref.value, hider_ref.value = false, true
    W.sees[3], W.speed, W.flags, W.evel[3], W.head_dmg[3], W.body_dmg[3] = true, 0, 1, 0, 120, 86
    tick(20)
    before = #prints + 1
    for i = 1, 12 do
        tick(6)
        fire("aim_fire", { id = 7900 + i, target = 3, hitgroup = 1, damage = 120, hit_chance = 90, backtrack = 0, x = 500, y = 0, z = 70 })
        if i % 4 == 0 then
            fire("aim_hit", { id = 7900 + i, target = 3, hitgroup = 1, damage = 120 })
        else
            fire("aim_miss", { id = 7900 + i, target = 3, hitgroup = 1, reason = "?" })
        end
    end
    check(printed("kafa payi 3/12 (25%): kafa saklayan rakip", before) ~= nil, "V1.0.79: 12 atista 3 kafa -> kafa saklayan rakip")
    before = #prints + 1
    tick(2)
    local h79 = printed("kafa saklayan rakip (kafa payi <= %35)", before)
    check(h79 ~= nil and h79:find("Min. damage gecici 85", 1, true) ~= nil and plist.get(3, "Override prefer body aim") == "Force",
        "V1.0.79: kafa saklayana govde zorlanir, MD govde-1 (" .. tostring(h79) .. ", " .. tostring(plist.get(3, "Override prefer body aim")) .. ")")
    for i = 1, 3 do
        tick(6)
        fire("aim_fire", { id = 7920 + i, target = 3, hitgroup = 2, damage = 86, hit_chance = 90, backtrack = 0, x = 500, y = 0, z = 70 })
        fire("aim_miss", { id = 7920 + i, target = 3, hitgroup = 2, reason = "spread" })
    end
    tick(2)
    check(plist.get(3, "Override prefer body aim") ~= "Force", "V1.0.79: her 4. atis kafa denemesi (govde zorlanmaz) ("
        .. tostring(plist.get(3, "Override prefer body aim")) .. ")")
    tick(6)
    fire("aim_fire", { id = 7930, target = 3, hitgroup = 1, damage = 120, hit_chance = 90, backtrack = 0, x = 500, y = 0, z = 70 })
    fire("aim_miss", { id = 7930, target = 3, hitgroup = 1, reason = "spread" })
    tick(2)
    check(plist.get(3, "Override prefer body aim") == "Force", "V1.0.79: deneme atisindan sonra yine govde")
    ext_ref.value, hider_ref.value = ext_was, false
    W.sees[3], W.head_dmg[3], W.body_dmg[3] = false, 0, 0
    tick(10)
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
    and files["nykle_log.txt"]:find("V1.0.90 (GameSense edition) yuklendi", 1, true) ~= nil,
    "V1.0.41: yeni surumde log dosyasi sifirdan (eski surumun oturumu atildi) [" .. tostring(files["nykle_log.txt"]):sub(1, 200) .. "]")
check(aspect.value == 0 and sky.value == 1 and notify.value == 8, "V1.0.35: kapanista aspect ratio, r_3dsky ve con_notifytime senin degerine doner ("
    .. tostring(aspect.value) .. ", " .. tostring(sky.value) .. ", " .. tostring(notify.value) .. ")")
local saved = db.nykle_win_gs_memory
do
    local with_last = 0
    if type(saved) == "table" and type(saved.resolver) == "table" then
        for _, e in pairs(saved.resolver) do
            if type(e) == "table" and e.last == saved.session then with_last = with_last + 1 end
        end
    end
    check(type(saved) == "table" and saved.session == 1 and with_last > 0,
        "V1.0.64: hafiza kaydi oturum ve son gorulme tasir (oturum " .. tostring(type(saved) == "table" and saved.session) .. ", " .. with_last .. " oyuncu)")
end
do
    local hd = nil
    if type(saved) == "table" and type(saved.resolver) == "table" then
        for _, e in pairs(saved.resolver) do
            if type(e) == "table" and type(e.hider) == "table" then hd = e.hider end
        end
    end
    check(hd ~= nil and hd.n == 12 and hd.h == 3 and hd.b == 4, "V1.0.79: kafa payi sayaci hafizaya yazildi ("
        .. (hd ~= nil and (hd.h .. "/" .. hd.n .. " b" .. hd.b) or "yok") .. ")")
end
local arms = type(saved) == "table" and type(saved.own_res) == "table" and saved.own_res.arms or nil
check(arms ~= nil and arms["lby+"] ~= nil and arms["lby+"].shots == 1 and arms["lby+"].hits == 1,
    "kol sayimi hafizaya yazildi (lby+ 1/1)")
local aa_arm = W.absa or "abs+"
check(arms ~= nil and arms[aa_arm] ~= nil and arms[aa_arm].hits == 1,
    "V1.0.34: " .. aa_arm .. " kafa isabeti 1, gogse giden isabet sayilmadi (" .. (arms and arms[aa_arm] and (arms[aa_arm].hits .. "/" .. arms[aa_arm].shots) or "?") .. ")")
-------------------------------------------------------------------------------
-- V1.0.81: deney motoru (can basina A / B, salter ezme, karar, kalici kayit, AFK)
-- V1.0.90: 10 kulvar ayni anda, kollar ikiser canlik karisik bloklarda, when = "dt", AI peek olcusu
-------------------------------------------------------------------------------
do
    local xp_ref = find_ref("Experiments (auto A/B test per life, keeps what wins)")
    local reset_ref = find_ref("Reset experiment results")
    local yl_ref = find_ref("Yaw left\nPeek")
    local afk_ref = find_ref("AFK mode (AI peek here + strafe, full exploits)")
    local auto_afk = find_ref("  » Auto AFK (no input 8 s after spawn)")
    local tp_ref = find_ref("Teleport in air when seen")
    check(reset_ref ~= nil and type(reset_ref.value) == "function", "V1.0.81: sifirlama dugmesi var")
    W.dead, W.jump, W.z, W.vz, W.flags, W.speed, W.lag = nil, nil, 0, 0, 1, 0, 12
    W.sees[2], W.sees[3], W.head_dmg[2], W.body_dmg[2] = false, false, 0, 0
    afk_ref.value, auto_afk.value, airlc_ref.value, tp_ref.value = false, false, true, true
    xp_ref.value = true
    local start, n, shot_id = #prints + 1, 0, 9000
    -- Temiz baslangic: kayitlar silinir, can sayaci sifirlanir (her bolum kendi adayini temiz olcer).
    local function fresh()
        start = #prints + 1
        reset_ref.value()
        n = 0
    end
    fresh()
    check(printed("deney sonuclari silindi", start) ~= nil, "V1.0.81: sifirlama satiri")
    -- "deney: can N | yer peek_narrow B | ..." -> { peek_narrow = "B", ["@yer"] = "peek_narrow", ... }
    local function arms_of(line)
        local arms = {}
        for lane, id, arm in line:gmatch("| (%S+) ([%w_]+) ([AB])") do
            arms[id], arms["@" .. lane] = arm, id
        end
        return arms
    end
    -- Bir can: dogus, 2 tick, fn(kollar) (mermiler / atislar), olum. Donus: "deney: can N" satiri, kollar.
    local function life(fn)
        n = n + 1
        local from = #prints + 1
        fire("player_spawn", { userid = 1 })
        tick(2)
        local line = printed(("deney: can %d |"):format(n), from) or ""
        local arms = arms_of(line)
        if fn then fn(arms) end
        fire("player_death", { userid = 1, attacker = 2, weapon = "ssg08" })
        return line, arms
    end
    local function hurt(group)
        tick(1)
        fire("player_hurt", { userid = 1, attacker = 2, dmg_health = group == 1 and 120 or 60, hitgroup = group, weapon = "ssg08" })
    end
    local function shoot(kill)
        shot_id = shot_id + 1
        tick(1)
        fire("aim_fire", { id = shot_id, target = 2, hitgroup = 1, damage = 120, hit_chance = 80, backtrack = 0, x = 500, y = 0, z = 70 })
        if kill then
            fire("aim_hit", { id = shot_id, target = 2, hitgroup = 1, damage = 120 })
            fire("player_death", { userid = 2, attacker = 1, headshot = true, weapon = "ssg08" })
        else
            fire("aim_miss", { id = shot_id, target = 2, reason = "spread" })
        end
    end

    -- Davranis olcumu (dusman goruyor, kosuyoruz = Peek): 40 tick'te en buyuk |yaw offset| ve o an DT / Hide shots.
    local yaw_off = find_ref("Yaw offset")
    local hs_ref = find_ref("On shot anti-aim")
    local function probe()
        local big = 0
        W.sees[2], W.speed = true, 240
        tick(12)
        for _ = 1, 40 do
            tick(1)
            local v = yaw_off ~= nil and math.abs(yaw_off.value or 0) or 0
            if v > big then big = v end
        end
        local dt_v, hs_v = dt_ref.value, hs_ref ~= nil and hs_ref.value or nil
        -- V1.0.87: kosarken (240) egilme yok; yavasken (0) goruluyorsa egilme.
        local duck_run = last_cmd.in_duck
        W.speed = 0
        tick(6)
        local duck_slow = last_cmd.in_duck
        W.sees[2], W.speed = false, 0
        tick(30)
        return big, dt_v, hs_v, duck_run, duck_slow
    end

    -- V1.0.90 kol tasarimi: 32 bos can (mermi / kill yok, karar cikmaz). Her kulvar 16 A + 16 B, her iki canlik
    -- blokta birer kez; HER kulvar cifti tam 16 canda ayni kolda (dort kol birlesimi sekizer can): kulvarlar
    -- birbirinin olcusune yanlilik katmaz.
    do
        local lanes = {}
        for _ = 1, 32 do
            local _, arms = life()
            for key, id in pairs(arms) do
                if key:sub(1, 1) == "@" then
                    lanes[key] = (lanes[key] or "") .. arms[id]
                end
            end
        end
        local names, halves, blocks, pairs_ok, worst = {}, true, true, true, 16
        for key, text in pairs(lanes) do
            names[#names + 1] = key
            local _, b_count = text:gsub("B", "")
            if #text ~= 32 or b_count ~= 16 then halves = false end
            for k = 1, #text - 1, 2 do
                local pair = text:sub(k, k + 1)
                if pair ~= "AB" and pair ~= "BA" then blocks = false end
            end
        end
        for i = 1, #names do
            for j = i + 1, #names do
                local same = 0
                for k = 1, 32 do
                    if lanes[names[i]]:sub(k, k) == lanes[names[j]]:sub(k, k) then same = same + 1 end
                end
                if same ~= 16 then pairs_ok, worst = false, same end
            end
        end
        check(#names == 10 and halves and blocks, "V1.0.90: 10 kulvarin her biri 32 canda 16 A + 16 B, her blokta birer kez ("
            .. #names .. " kulvar, yer " .. tostring(lanes["@yer"]) .. ")")
        check(pairs_ok, "V1.0.90: her kulvar cifti 32 canda tam 16 kez ayni kolda (kulvarlar birbirine dik; sapan " .. worst .. ")")
        fresh()
    end

    -- 16 can: peek_narrow'un A canlarinda hep kafa (zarar 1), B canlarinda hep govde (0.6). Ilk 6 canda davranis da
    -- olculur (kol o canin satirindan okunur).
    local seq, pr, bullets_dt, line1 = {}, { peek_narrow = {}, sniper_hs = {} }, 0, nil
    for i = 1, 16 do
        local line, arms = life(function(arms)
            if i <= 6 then
                local r = { probe() }
                local pa, sa = arms.peek_narrow or "?", arms.sniper_hs or "?"
                pr.peek_narrow[pa] = pr.peek_narrow[pa] or r
                pr.sniper_hs[sa] = pr.sniper_hs[sa] or r
                if pa == "B" then
                    check(yl_ref ~= nil and yl_ref.value == -20, "V1.0.81: B kolunda menudeki ayar degismez (ezme sadece okurken; Yaw left "
                        .. tostring(yl_ref and yl_ref.value) .. ")")
                end
            end
            for _ = 1, 5 do hurt(arms.peek_narrow == "B" and 3 or 1) end
            if arms.sniper_hs == "A" then bullets_dt = bullets_dt + 5 end
        end)
        line1 = line1 or line
        for id, arm in pairs(arms) do
            if id:sub(1, 1) ~= "@" then seq[id] = (seq[id] or "") .. arm end
        end
    end
    check(line1:find("yer peek_narrow %u | exploit sniper_hs %u | def force_off %u | hareket cap_off %u | koruma fs_auto_off %u | hava air_def2 %u | atis hc70 %u | atis2 fakebody_off %u | atis3 qs_late %u | peek peek_real %u") ~= nil,
        "V1.0.90: 10 kulvar ayni anda, her birinde ilk aday (" .. line1 .. ")")
    -- Denge: her aday 16 canda 8 A + 8 B ve her iki canlik blokta birer kez.
    local balanced, blocks, distinct, count = true, true, {}, 0
    for id, text in pairs(seq) do
        local _, b_count = text:gsub("B", "")
        if #text ~= 16 or b_count ~= 8 then balanced = false end
        for k = 1, #text - 1, 2 do
            local pair = text:sub(k, k + 1)
            if pair ~= "AB" and pair ~= "BA" then blocks = false end
        end
        if distinct[text] == nil then distinct[text] = true; count = count + 1 end
    end
    check(balanced and blocks, "V1.0.90: kollar dengeli (16 canda 8 A + 8 B, her iki canda birer kez): peek_narrow "
        .. tostring(seq.peek_narrow) .. ", sniper_hs " .. tostring(seq.sniper_hs))
    check(count >= 5, "V1.0.90: kulvarlarin kol dizileri birbirinden farkli (" .. count .. " farkli dizi / 10 kulvar)")
    local pn, sh = pr.peek_narrow, pr.sniper_hs
    check(pn.A ~= nil and pn.B ~= nil and pn.A[1] >= 30 and pn.B[1] <= 28 and pn.B[1] >= 8,
        "V1.0.86: peek_narrow B kolunda Peek yaw'i dar (en buyuk |yaw| A " .. tostring(pn.A and pn.A[1]) .. ", B "
        .. tostring(pn.B and pn.B[1]) .. ")")
    check(pn.A ~= nil and pn.B ~= nil and pn.A[5] == 0 and pn.B[5] == 0,
        "V1.0.89: seen_duck listeden cikti, hicbir kolda zorla egilme yok (" .. tostring(pn.A and pn.A[5]) .. tostring(pn.B and pn.B[5]) .. ")")
    check(sh.A ~= nil and sh.B ~= nil and sh.A[2] == true and sh.A[3] ~= true and sh.B[2] == false and sh.B[3] == true,
        "V1.0.86: sniper_hs B kolunda scout'ta DT kapali, Hide shots acik (A DT " .. tostring(sh.A and sh.A[2]) .. " HS "
        .. tostring(sh.A and sh.A[3]) .. ", B DT " .. tostring(sh.B and sh.B[2]) .. " HS " .. tostring(sh.B and sh.B[3]) .. ")")
    local verdict = printed("deney SONUCU: peek_narrow", start)
    check(verdict ~= nil and verdict:find("KABUL, kalici", 1, true) ~= nil and verdict:find("40 mermi zarar 1.00", 1, true) ~= nil
        and verdict:find("40 mermi zarar 0.60", 1, true) ~= nil, "V1.0.81: yer adayi 40 + 40 mermide kabul; V1.0.88: govde isabeti hasar / 100 (60 hasar = 0.60) (" .. tostring(verdict) .. ")")
    local saved_xp = db.nykle_win_gs_xp
    check(type(saved_xp) == "table" and saved_xp.v == 1 and saved_xp.life == 16 and saved_xp.c.peek_narrow.st == "B"
        and saved_xp.c.peek_narrow.a.n == 40 and saved_xp.c.peek_narrow.b.l == 8, "V1.0.81: sonuc database'e yazildi")
    -- Ayni mermiler butun "harm" kulvarlarina yazilir; sniper_hs can basina kill ile olculur (mermi saymaz).
    check(saved_xp.c.sniper_hs.a.n == 0 and saved_xp.c.sniper_hs.b.n == 0 and saved_xp.c.sniper_hs.a.l == 8
        and saved_xp.c.sniper_hs.b.l == 8 and saved_xp.c.sniper_hs.st == nil and printed("deney SONUCU: sniper_hs", start) == nil,
        "V1.0.89: sniper_hs can basina kill ile olculur: mermi saymaz, can sayar, 8 + 8 canda karar vermez")
    local cap, fo = saved_xp.c.cap_off, saved_xp.c.force_off
    check(cap ~= nil and cap.a.n + cap.b.n == 80 and cap.a.l == 8 and cap.b.l == 8,
        "V1.0.90: ayni mermiler oteki zarar kulvarina da yazilir (cap_off " .. tostring(cap and (cap.a.n + cap.b.n)) .. " mermi)")
    check(fo ~= nil and bullets_dt > 0 and bullets_dt < 80 and fo.a.n + fo.b.n == bullets_dt,
        "V1.0.90: when = dt adayi sadece DT'li canlarin mermisini sayar (force_off " .. tostring(fo and (fo.a.n + fo.b.n))
        .. ", DT'li canlarda yenen " .. bullets_dt .. ")")
    check(printed("ayar onerilen degerine donduruldu", start) == nil, "V1.0.81: ezilen salter 'onerilen ayar' duzeltmesini tetiklemez")

    -- AFK cani sayilmaz; kabulden sonra yer kulvarinin siradaki adayi peek_static.
    afk_ref.value = true
    local l17 = life(function() tick(3); for _ = 1, 4 do hurt(1) end end)
    afk_ref.value = false
    tick(2)
    check(l17:find("yer peek_static", 1, true) ~= nil, "V1.0.81: kabulden sonra siradaki aday (" .. l17 .. ")")
    saved_xp = db.nykle_win_gs_xp
    check(saved_xp.c.peek_static == nil or (saved_xp.c.peek_static.a.l + saved_xp.c.peek_static.b.l == 0
        and saved_xp.c.peek_static.a.n + saved_xp.c.peek_static.b.n == 0), "V1.0.81: AFK cani ve mermileri sayilmadi")

    -- AFK cani sayilmadigi icin siradaki can ayni kolda baslar; 5 sn'den kisa olumsuz can (cift dogus) da oyle.
    local from18 = #prints + 1
    fire("player_spawn", { userid = 1 })
    tick(2)
    local first = printed("deney: can", from18) or ""
    fire("player_spawn", { userid = 1 })
    tick(2)
    local second = ""
    for i = #prints, from18, -1 do
        if prints[i]:find("deney: can", 1, true) then second = prints[i]; break end
    end
    n = n + 2
    check(l17:match("yer peek_static (%u)") ~= nil and l17:match("yer peek_static (%u)") == first:match("yer peek_static (%u)")
        and first:match("yer peek_static (%u)") == second:match("yer peek_static (%u)") and first ~= second,
        "V1.0.81: sayilmayan candan sonra kol tekrarlanir (" .. first .. " / " .. second .. ")")
    fire("player_death", { userid = 1, attacker = 2, weapon = "ssg08" })

    -- Hava (temiz baslangic): B canlarinda havada kafa yenir -> aday reddedilir, sirada air_fl2.
    fresh()
    for _ = 1, 80 do
        if printed("deney SONUCU: air_def2", start) ~= nil then break end
        life(function(arms)
            if arms.air_def2 == "B" then
                W.flags, W.z = 0, 60
                tick(3)
                fire("player_hurt", { userid = 1, attacker = 2, dmg_health = 120, hitgroup = 1, weapon = "ssg08" })
                W.flags, W.z = 1, 0
                tick(1)
            end
        end)
    end
    verdict = printed("deney SONUCU: air_def2", start)
    check(verdict ~= nil and verdict:find("RED, eski ayar kalir", 1, true) ~= nil and verdict:find("25 can hava zarari 1.00/can", 1, true) ~= nil,
        "V1.0.81: hava adayi 25 + 25 canda reddedildi (" .. tostring(verdict) .. ")")

    -- air_fl2 (havada teleport kapali sayilir): B canda goruluyorken havada DT kapanir, A canda acik kalir. sniper_hs'in
    -- B canlari (Hide shots, DT zaten kapali) atlanir.
    local seen_b, seen_a = nil, nil
    for _ = 1, 40 do
        if seen_a ~= nil and seen_b ~= nil then break end
        life(function(arms)
            if arms["@hava"] ~= "air_fl2" or arms.sniper_hs ~= "A" then return end
            W.sees[2], W.lag, W.speed = true, 12, 240
            tick(24)
            local ground = dt_ref.value
            W.flags, W.z = 0, 60
            tick(4)
            local air = dt_ref.value
            W.flags, W.z = 1, 0
            tick(4)
            if arms.air_fl2 == "B" then seen_b = { ground, air } else seen_a = { ground, air } end
            W.sees[2], W.speed = false, 0
        end)
    end
    check(seen_a ~= nil and seen_a[1] == true and seen_a[2] == true, "V1.0.81: air_fl A kolu: havada DT acik ("
        .. tostring(seen_a and seen_a[2]) .. ")")
    check(seen_b ~= nil and seen_b[1] == true and seen_b[2] == false, "V1.0.81: air_fl B kolu: havada DT kapali, menudeki salter acik ("
        .. tostring(seen_b and seen_b[2]) .. ", " .. tostring(tp_ref.value) .. ")")
    check(tp_ref.value == true, "V1.0.81: hava salteri menude degismedi")

    -- V1.0.89: can basina kill ile olculen aday (sniper_hs; temiz baslangic). B canlarinda 2 kill, A canlarinda yok:
    -- iki kolda 40 cana ulasinca kabul edilir; karar satiri "can ... kill" bicimindedir (mermi / zarar degil).
    do
        fresh()
        for _ = 1, 100 do
            if printed("deney SONUCU: sniper_hs", start) ~= nil then break end
            life(function(arms) if arms.sniper_hs == "B" then shoot(true); shoot(true) end end)
        end
        local sx = db.nykle_win_gs_xp.c.sniper_hs
        local sl = printed("deney SONUCU: sniper_hs", start)
        check(sx ~= nil and sx.st == "B" and sl ~= nil and sl:find("KABUL, kalici", 1, true) ~= nil
            and sl:match("A 40 can 0 kill | B 40 can 80 kill") ~= nil,
            "V1.0.89: sniper_hs can basina kill ile kabul edilir (" .. tostring(sx and sx.st) .. ", A " .. tostring(sx and sx.a.l)
            .. " can " .. tostring(sx and sx.a.k) .. " kill, B " .. tostring(sx and sx.b.l) .. " can " .. tostring(sx and sx.b.k)
            .. " kill; " .. tostring(sl and sl:sub(1, 120)) .. ")")
        -- Kabulden sonra scout'ta kalici olarak Hide shots (A kolunda da): DT kapali, Hide shots acik.
        fire("player_spawn", { userid = 1 })
        tick(12)
        check(dt_ref.value == false and hs_ref.value == true, "V1.0.89: kabul edilen sniper_hs kalici uygulanir (DT "
            .. tostring(dt_ref.value) .. ", HS " .. tostring(hs_ref.value) .. ")")
        -- V1.0.90: sniper_hs kabul edilince DT'ye bagli adaylar (after = "sniper_hs") atlanir: def kulvari biter,
        -- exploit kulvarinda recharge_free'ye gecilmez.
        local after_line = ""
        for i = #prints, start, -1 do
            if prints[i]:find("deney: can", 1, true) then after_line = prints[i]; break end
        end
        check(after_line ~= "" and after_line:find("force_off", 1, true) == nil and after_line:find("def_always", 1, true) == nil
            and after_line:find("clean_off", 1, true) == nil and after_line:find("recharge_free", 1, true) == nil
            and after_line:find("| def ", 1, true) == nil,
            "V1.0.90: Hide shots kalici olunca DT'ye bagli adaylar olculmez (" .. after_line .. ")")
        fire("player_death", { userid = 1, attacker = 2, weapon = "ssg08" })
        n = n + 1
    end

    -- V1.0.90: AI peek olcusu (peek_real; temiz baslangic). Yan adimda oldurucu aci var (W.dmg_fn), Peek Assist basili:
    -- her canda bir AI peek baslar. A canlarinda peek'ten hemen sonra olursun (-1), B canlarinda oldurur ve 3 sn'den
    -- sonra olursun (+1): 20 + 20 peek'te aday kabul edilir.
    do
        -- Isinma (sayilmayan bir canda): tickbase kaymasi 0 iken 140 tick (lua 128 tick'te sarji "dolu" kabul eder);
        -- sonra canlarda DT sarji oyundaki gibi tickbase'i kaydirir.
        W.lag = 0
        tick(140)
        fresh()
        local pk, pc = find_ref("Quick peek assist key"), find_ref("Quick peek assist")
        pk.value, pc.value = true, true
        W.threat, W.lag, W.next_attack, W.speed = 2, 12, 0, 0
        W.dmg_fn = function(_, y1, target, head)
            if target ~= 2 then return 0 end
            return (math.abs(y1) >= 15 and head) and 120 or 0
        end
        local started, fake_start, held, late = 0, nil, nil, nil
        for i = 1, 80 do
            if printed("deney SONUCU: peek_real", start) ~= nil then break end
            life(function(arms)
                -- Tus birakilip yeniden basilir (onceki peek ve "2 bos peek" kilidi sifirlanir).
                pk.value = false
                -- DT sarji oyundaki gibi: Hide shots canlarinda tickbase kaymaz (0), DT canlarinda 12 tick kayar
                -- (sabit kaymada lua, DT yeni acildiginda sarji "doluyor" okur ve AI peek bekler).
                W.lag = arms.sniper_hs == "B" and 0 or 12
                tick(2)
                pk.value = true
                -- Tek canlarda rakibin kaydi 10 tick sahte (defensive): sim zamani 10 tick geri atlar.
                local fake = i % 2 == 1
                W.sim_shift[2] = fake and 10 or 0
                local from = #prints + 1
                tick(8)
                local line = printed("ai peek: sol", from) or printed("ai peek: sag", from)
                if arms.peek_real == "A" and fake and line ~= nil then
                    fake_start = line
                end
                local waited = line == nil
                -- Gercek kayit 10 tick sonra gelir. Test dunyasinda tickbase kaymasi sabit oldugu icin DT yeni
                -- acildiysa lua sarji en gec 128 tick'te "dolu" kabul eder: o kadar beklenir.
                for _ = 1, 22 do
                    if line ~= nil then break end
                    tick(10)
                    line = printed("ai peek: sol", from) or printed("ai peek: sag", from)
                end
                if arms.peek_real == "B" and fake then
                    -- B kolu: sahte kayitta yola cikmaz (ilk 8 tick), kayit gercek olunca cikar.
                    held = (held == nil or held) and waited
                    late = (late == nil or late) and line ~= nil and line:find("| kayit gercek", 1, true) ~= nil
                end
                if line ~= nil then started = started + 1 end
                -- Ayni canda ikinci peek baslamasin.
                pk.value = false
                if arms.peek_real == "B" and line ~= nil then
                    fire("player_death", { userid = 2, attacker = 1, headshot = true, weapon = "ssg08" })
                    tick(200)
                end
                W.sim_shift[2] = 0
            end)
        end
        pk.value, pc.value, W.dmg_fn, W.lag = false, false, nil, 12
        W.sim_shift[2] = 0
        local pv = printed("deney SONUCU: peek_real", start)
        local px = db.nykle_win_gs_xp.c.peek_real
        check(started >= 40 and pv ~= nil and pv:find("KABUL, kalici", 1, true) ~= nil and pv:find("20 peek puan -1.00", 1, true) ~= nil
            and pv:find("20 peek puan +1.00", 1, true) ~= nil and px ~= nil and px.st == "B",
            "V1.0.90: AI peek adayi peek basina puanla olculur, 20 + 20 peek'te kabul (" .. started .. " peek; " .. tostring(pv) .. ")")
        check(fake_start ~= nil and fake_start:find("| kayit sahte", 1, true) ~= nil,
            "V1.0.90: A kolunda sahte kayitta da peek baslar, satira kayit durumu yazilir (" .. tostring(fake_start) .. ")")
        check(held == true and late == true, "V1.0.90: B kolunda (peek_real) sahte kayitta peek baslamaz, gercek kayitta baslar ("
            .. tostring(held) .. ", " .. tostring(late) .. ")")
        tick(40)
    end

    -- Atis (temiz baslangic): A canlarinda 6 iska, B canlarinda 6 kill; 30 + 30 atista aday kabul edilir.
    fresh()
    local hc_a, hc_b = nil, nil
    for _ = 1, 30 do
        if printed("deney SONUCU: hc70", start) ~= nil then break end
        life(function(arms)
            tick(2)
            if arms.hc70 == "B" then hc_b = hc_ref.value else hc_a = hc_ref.value end
            for _ = 1, 6 do shoot(arms.hc70 == "B") end
        end)
    end
    check(hc_a == 55 and hc_b == 70, "V1.0.81: hc70 A kolunda Minimum hit chance senin degerin (55), B kolunda 70 ("
        .. tostring(hc_a) .. " / " .. tostring(hc_b) .. ")")
    verdict = printed("deney SONUCU: hc70", start)
    check(verdict ~= nil and verdict:find("KABUL, kalici", 1, true) ~= nil and verdict:match("A %d+ can %d+ atis 0 kill") ~= nil
        and verdict:find("30 atis 30 kill", 1, true) ~= nil, "V1.0.81: atis adayi iki kolda 30+ atista kabul (" .. tostring(verdict) .. ")")
    -- Kabul edilen taban siradaki adayin A kolunda da gecerli (kalici).
    local kept = nil
    for _ = 1, 4 do
        life(function(arms)
            tick(2)
            if arms.hc80 == "A" then kept = hc_ref.value end
        end)
    end
    check(kept == 70, "V1.0.90: kabul edilen hc70 siradaki adayin A kolunda da uygulanir (" .. tostring(kept) .. ")")

    -- Kapali: yeni kol yok; sifirlama kayitlari siler.
    xp_ref.value = false
    local off_from = #prints + 1
    fire("player_spawn", { userid = 1 })
    tick(3)
    check(printed("deney: can", off_from) == nil, "V1.0.81: deney kapaliyken can satiri yok")
    reset_ref.value()
    tick(3)
    check(hc_ref.value == 55, "V1.0.81: sifirlamadan sonra kalici taban da kalkar (hit chance " .. tostring(hc_ref.value) .. ")")
    saved_xp = db.nykle_win_gs_xp
    local cleared = type(saved_xp) == "table" and saved_xp.life == 0
    for _, r in pairs(cleared and saved_xp.c or {}) do
        if r.st ~= nil or r.a.l + r.b.l + r.a.n + r.b.n ~= 0 then cleared = false end
    end
    check(cleared, "V1.0.81: sifirlama database'i bosaltir")
    W.sees[2], W.speed, W.flags, W.z = false, 0, 1, 0
end

-------------------------------------------------------------------------------
-- V1.0.87: gorulunce ve yavasken egil (secenek dogrudan; deney kolu yukarida)
-------------------------------------------------------------------------------
do
    local sd_ref = find_ref("Duck when seen and slow (crouched + slow: 22% of hits to the head, standing 46%)")
    check(sd_ref ~= nil and sd_ref.value == false, "V1.0.87: gorulunce egil secenegi var, varsayilan kapali")
    W.dead, W.flags, W.z, W.vz, W.speed, W.jump, W.lag, W.next_attack = nil, 1, 0, 0, 0, nil, 12, 0
    W.weapon_class = "CWeaponSSG08"
    W.sees[2], W.head_dmg[2], W.body_dmg[2] = true, 0, 0
    fire("player_spawn", { userid = 1 })
    tick(10)
    local off = last_cmd.in_duck
    sd_ref.value = true
    tick(8)
    local slow = last_cmd.in_duck
    W.jump = true
    tick(2)
    local jumping = last_cmd.in_duck
    W.jump = nil
    tick(4)
    W.weapon_class = "CKnife"
    tick(4)
    local knife = last_cmd.in_duck
    W.weapon_class = "CWeaponSSG08"
    tick(6)
    local again = last_cmd.in_duck
    W.sees[2] = false
    tick(3)
    local held = last_cmd.in_duck
    tick(80)
    local released = last_cmd.in_duck
    -- Kosarken goruluyorsan egilme baslamaz.
    W.speed, W.sees[2] = 240, true
    tick(12)
    local running = last_cmd.in_duck
    W.speed, W.sees[2] = 0, false
    sd_ref.value = false
    tick(30)
    check(off == 0 and slow == 1 and jumping == 0 and knife == 0 and again == 1 and held == 1 and released == 0 and running == 0,
        "V1.0.87: goruluyorken yavassan egilir; ziplarken / bicakla / kosarken / gorulmezken egilmez, gorus bitince birakir ("
        .. tostring(off) .. tostring(slow) .. tostring(jumping) .. tostring(knife) .. tostring(again) .. tostring(held)
        .. tostring(released) .. tostring(running) .. ")")
end

-------------------------------------------------------------------------------
-- V1.0.90: duello danismani (SALDIR / DENK / SAVUN, kazanma tahmini, sebepler, duello satirinda "oneri")
-------------------------------------------------------------------------------
do
    local adv_ref = find_ref("Duel advisor (SALDIR / SAVUN + win chance)")
    local forget_ref = find_ref("Forget learned enemies")
    check(adv_ref ~= nil and adv_ref.value == true, "V1.0.90: duello danismani secenegi var, varsayilan acik")
    -- Ekrana cizilen oneri: ana yazi (kalin, renkli) ve nisangahin ustundeki sebep satirlari.
    local function shown()
        -- Gosterilen yuzde kare kare yumusatilir: 60 kare cizilip son kareye bakilir.
        for _ = 1, 60 do fire("paint") end
        for k in pairs(texts) do texts[k] = nil end
        fire("paint")
        local main, reasons = nil, {}
        for _, t in ipairs(texts) do
            local s = tostring(t.str)
            if t.flags == "cb" and t.r ~= 0 and (s:find("^SALDIR") or s:find("^SAVUN") or s:find("^DENK")) then
                main = t
            elseif t.flags == "c-" and t.y < 520 then
                reasons[#reasons + 1] = s
            end
        end
        return main, reasons
    end
    -- Temassiz 80 tick: onceki karsilasma kapanir.
    local function calm()
        W.sees[2], W.sees[3], W.head_dmg[2], W.body_dmg[2], W.sim_shift[2] = false, false, 0, 0, 0
        W.evel[2] = 0
        tick(80)
    end
    W.dead, W.flags, W.z, W.vz, W.speed, W.jump, W.lag, W.next_attack = nil, 1, 0, 0, 0, nil, 12, 0
    W.weapon_class, W.threat, W.ehp = "CWeaponSSG08", 2, {}
    fire("player_spawn", { userid = 1 })
    forget_ref.value()
    calm()

    -- Temas yok: rakip 500 birimde, duruyor -> 0.10 - 0.13 + 0.60 = 0.57 -> %64 SALDIR.
    local main, reasons = shown()
    check(main ~= nil and main.str == "SALDIR  64%" and main.g > main.r and reasons[1] == "RAKIP DURUYOR",
        "V1.0.90: temas yokken duran rakibe on tahmin (" .. tostring(main and main.str) .. " | " .. table.concat(reasons, " + ") .. ")")

    -- Rakip seni goruyor, sen onu vuramiyorsun, kosuyor ve defensive'in icinde: 0.10 - 0.28 + 0.09 - 0.87 -> %28 SAVUN.
    local from = #prints + 1
    W.sees[2], W.evel[2] = true, 200
    for _ = 1, 8 do
        W.sim_shift[2] = 10
        tick(10)
        W.sim_shift[2] = 0
        tick(2)
    end
    main, reasons = shown()
    check(main ~= nil and main.str == "SAVUN  28%" and main.r > main.g and reasons[1] == "RAKIP DEFENSIVE'DE"
        and reasons[2] == "SENI GORUYOR, SEN VURAMIYORSUN",
        "V1.0.90: goren + kosan + defensive'li rakibe SAVUN (" .. tostring(main and main.str) .. " | " .. table.concat(reasons, " + ") .. ")")
    -- O karsilasmada olursen duello satirina ilk oneri yazilir.
    fire("player_death", { userid = 1, attacker = 2, weapon = "ssg08" })
    local duel = printed("dbg duello: dusman2", from)
    check(duel ~= nil and duel:find("| oldun", 1, true) ~= nil and duel:find("| oneri SAVUN %4", 1, true) ~= nil,
        "V1.0.90: duello satirina karsilasmadaki ilk oneri yazilir (" .. tostring(duel and duel:sub(-60)) .. ")")
    fire("player_spawn", { userid = 1 })
    -- Ayni rakip seni bir kez oldurdu: sebeplerde skor da yer alir (0.36 * ln(1/2) = -0.25).
    calm()
    W.sees[2], W.evel[2] = true, 200
    tick(20)
    main, reasons = shown()
    check(main ~= nil and main.str:find("^SAVUN") ~= nil and (reasons[1] == "SENI 1 KEZ OLDURDU (0-1)" or reasons[2] == "SENI 1 KEZ OLDURDU (0-1)"),
        "V1.0.90: rakibe karsi skor sebeplerde (" .. tostring(main and main.str) .. " | " .. table.concat(reasons, " + ") .. ")")
    forget_ref.value()

    -- Sen onu vurabiliyorsun (oldurucu), o seni gormuyor, duruyor, cani 60: 0.10 + 0.18 + 0.60 + 0.51 -> %80 SALDIR.
    calm()
    W.ehp[2], W.head_dmg[2] = 60, 120
    tick(20)
    main, reasons = shown()
    check(main ~= nil and main.str == "SALDIR  80%" and reasons[1] == "OLDURECEK ATIS VAR" and reasons[2] == "RAKIP DURUYOR",
        "V1.0.90: oldurucu atis + gormeyen duran rakibe SALDIR (" .. tostring(main and main.str) .. " | " .. table.concat(reasons, " + ") .. ")")

    -- Ikiniz de goruyorsunuz, rakip kosuyor ve 50 birim yukarida: 0.10 + 0.09 - 0.23 -> %49 DENK.
    calm()
    W.ehp, W.z = {}, -50
    W.sees[2], W.evel[2], W.head_dmg[2] = true, 200, 120
    tick(20)
    main, reasons = shown()
    check(main ~= nil and main.str == "DENK  49%" and main.r > 200 and main.g > 150 and reasons[1] == "OLDURECEK ATIS VAR"
        and reasons[2] == "RAKIP YUKARDA",
        "V1.0.90: karsilikli gorus + yukaridaki kosan rakip DENK (" .. tostring(main and main.str) .. " | " .. table.concat(reasons, " + ") .. ")")
    W.z = 0
    calm()
    W.ehp[2], W.head_dmg[2] = 60, 120
    tick(20)

    -- Silah hazir degil (surgu): tahmin ne olursa olsun SAVUN, yuzde yazilmaz.
    W.next_attack = 1e9
    tick(8)
    main, reasons = shown()
    check(main ~= nil and main.str == "SAVUN" and reasons[1] == "SILAH HAZIR DEGIL",
        "V1.0.90: silah hazir degilken SAVUN (" .. tostring(main and main.str) .. " | " .. table.concat(reasons, " + ") .. ")")
    W.next_attack = 0

    -- Kapaliyken cizilmez.
    adv_ref.value = false
    tick(4)
    main = shown()
    check(main == nil, "V1.0.90: gosterge kapaliyken cizilmez")
    adv_ref.value = true
    W.ehp, W.head_dmg[2], W.sees[2], W.evel[2] = {}, 0, false, 0
    tick(80)
end

errs = errors_since(1)
check(#errs == 0, "hic hata satiri yok" .. (#errs > 0 and (": " .. errs[1]) or ""))

log(fails == 0 and "ALL PASSED" or ("FAILED " .. fails))
return out
