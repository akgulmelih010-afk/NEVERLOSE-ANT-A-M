-- Nykle.win primordial edition: sahte primordial API testi (mock harness).
-- Redis'in Lua 5.1 EVAL ortaminda calisir: tests/run_prim_tests.sh
--   ARGV[1] = mod (full | noffi | missing | nofeature), ARGV[2] = script KAYNAK METNI (redis-cli -x, stdin).
-- Mock, scratchpad/primwork/PRIMORDIAL_API.md anlamini izler (callbacks + e_callbacks, menu.add_* elemanlari
-- 1-tabanli :get/:set, menu.find -> eleman ya da {eleman, tus}, ANTIAIM / HITSCAN / TARGET_SELECTION ctx kaydi,
-- SETUP_COMMAND cmd, AIMBOT_SHOOT / HIT / MISS shot nesneleri, entity_list, exploits.* sarj modeli, cvars,
-- render kaydi, global_vars ilerlemesi, sahte ffi dosya sistemi + pano). SPEC.md §7 test plani: her kontrol,
-- ozelligi kaldirilmis bir yapida FAIL verecek sekilde kuruldu (her senaryo once ozelligin tetikleyicisini
-- kurar, sonra yalnizca o ozelligin uretebilecegi bir izi arar; "hicbir sey yapilmadi" sonucu PASS etmez).
--
-- MUTATIONS (hangi kontrol hangi spec satirini korur):
--   T-LOAD-1 yukleme satiri §0 / §6.1          T-LOAD-3 §2 menu tablosu (ad, tip, varsayilan, aralik, kolon)
--   T-LOAD-4 §3.1 ana bolum local sayisi       T-LOAD-5 §3.6 N.find + "menude bulunamadi" bir kez
--   T-LOAD-6 §8 G18 / A12 (olculemedi)         T-LOAD-7 §3.3 dagitici (3 satir, 50'de kapat)
--   T-MENU-1 §1.1 H2 recommended               T-MENU-2/3 §2.4 gorunurluk
--   T-OV-1..5 §3.4 Override + A23 degerleri     T-RC-1..3 §3.5 sarj sahibi + watchdog
--   T-AA-1..18 §1.2 A1-A23                      T-BR-1..5 §1.3 B1-B5
--   T-EX-1..16 §1.4 X1-X14 (+ V1.0.80 inis teleportu, merdiven, harita degisimi, cagrilabilir tetik)
--   T-EX-17..19 V1.0.5 A1: zorlanan defensive olay basina bir (def_edge), sebep GAP'leri, "def: shift" satirlari.
--     T-EX-1..16'da siklik olcen kontroller iki yolda da kosar: def_edge kapali (eski her-tick) + varsayilan (olay).
--   T-RAGE-1..22 §1.5 R1-R11 + U3 (+ R5 / R6 tabani, ardisik seri, R10 tazelik, R1 harita)
--   T-RAGE-27..29 V1.0.5 N1: uyanma LC degil, LC beklenmez, bekleme siniri, "(N kez)", takip tick basina bir ornek
--   T-MEM-1 hafiza 64 siniri                     T-OVR-1 override tusu yeniden cozulur
--   T-PEEK-1..4 §1.6                             T-LOG-1..10 §4 / §5 / §6
--   T-MISC-1..7 §1.8                             T-DRAW-1..2 §1.7
--   T-DLOG-1..12 R1-B1 detayli log (N.dlog; her modda)   T-DLOG-13 V1.0.5 N4 uyku (uyandi / uykuda / dbg uyandi)
--   T-PROF-1..12 R1-B2 dusman profili + hafiza v2 (N.profile; desen full, dosya ffi'li modlar, T-PROF-11 noffi)
--   X-API-1..5 §3.1 / §3.2 (yasak API, liste disi API, kati enum, %d, kacan hata)
local MODE, SRC = ARGV[1], ARGV[2]
if SRC == nil then SRC = MODE; MODE = "full" end
if MODE == nil or MODE == "" then MODE = "full" end
local H = { out = {}, fails = 0, passes = 0, mode = MODE, live = {} }
-- Script surumu (yukleme satiri ve log dosyasi isareti): her surumde burada degisir.
H.VER = "V1.0.13"
H.G = { hata = {}, md_bad = {}, native_bad = {}, sp_false = {}, enum_bad = {}, offlist = {}, unknown_global = {},
    global_write = {}, forbidden = {}, fmt_bad = {}, raw_err = {}, rc_left = {}, nonascii = {}, insts = 0 }

function H.log(s)
    local t = tostring(s):gsub("[\r\n]", " ")
    H.out[#H.out + 1] = t
end
function H.check(id, cond, msg)
    if cond then
        H.passes = H.passes + 1
        H.log("PASS " .. id .. " " .. tostring(msg or ""))
    else
        H.fails = H.fails + 1
        H.log("FAIL " .. id .. " " .. tostring(msg or ""))
    end
    return cond
end
-- Senaryo: hata (eksik eleman, yuklenemeyen script) FAIL olur; olusturulan ornekler sonunda kapatilir.
function H.run(id, fn)
    local ok, err = pcall(fn)
    if not ok then H.check(id, false, "senaryo hatasi: " .. tostring(err)) end
    local live = H.live
    H.live = {}
    for _, T in ipairs(live) do pcall(T.finish) end
end

-------------------------------------------------------------------------------
-- Kucuk yardimcilar
-------------------------------------------------------------------------------
function H.norm(a)
    a = (a + 180) % 360
    if a < 0 then a = a + 360 end
    return a - 180
end
function H.adiff(a, b) return math.abs(H.norm(a - b)) end
function H.f1(x)
    if type(x) ~= "number" then return tostring(x) end
    return string.format("%.1f", x)
end
function H.sgn(x)
    if x == nil then return 0 end
    if x > 0 then return 1 elseif x < 0 then return -1 end
    return 0
end
function H.keys(t, n)
    local r = {}
    for k in pairs(t) do r[#r + 1] = tostring(k) end
    table.sort(r)
    if n and #r > n then
        local c = {}
        for i = 1, n do c[i] = r[i] end
        c[#c + 1] = "..."
        return c
    end
    return r
end
function H.list(t, n)
    local r = {}
    for i = 1, math.min(#t, n or #t) do r[i] = tostring(t[i]) end
    if n and #t > n then r[#r + 1] = "..." end
    return table.concat(r, "; ")
end
function H.count_main_locals(src)
    -- tests/count_locals.py ile ayni kural: sutun 0'daki do ... end bloklari disindaki "local " satirlari.
    local depth, count = 0, 0
    for line in (src .. "\n"):gmatch("([^\n]*)\n") do
        line = line:gsub("\r$", "")
        local stripped = line:match("^%s*(.-)%s*$")
        if line:sub(1, 2) == "do" and stripped == "do" then
            depth = depth + 1
        elseif depth > 0 and stripped == "end" and line:sub(1, 1) ~= " " then
            depth = depth - 1
        elseif depth == 0 and line:sub(1, 6) == "local " then
            if line:match("^local function [%w_]+") then
                count = count + 1
            else
                local names = line:sub(7):match("^([^=]*)") or ""
                for n in names:gmatch("[^,]+") do
                    if n:match("%S") then count = count + 1 end
                end
            end
        end
    end
    return count
end

-------------------------------------------------------------------------------
-- %d denetimi: LuaJIT 2.1 kesirli sayiyla %d'de hata verir, Lua 5.1 sessizce keser (§3.1 [review]).
-------------------------------------------------------------------------------
H.real_format = string.format
function H.fmt_check(fmt, ...)
    if type(fmt) == "string" and fmt:find("%", 1, true) then
        local n = 0
        local args = { ... }
        for _, conv in fmt:gmatch("%%([%-%+ #0]*%d*%.?%d*)([%a%%])") do
            if conv ~= "%" then
                n = n + 1
                if conv == "d" or conv == "i" or conv == "x" or conv == "X" or conv == "o" or conv == "c" then
                    local v = args[n]
                    if type(v) == "number" and v ~= math.floor(v) then
                        H.G.fmt_bad[fmt] = tostring(v)
                    end
                end
            end
        end
    end
    return H.real_format(fmt, ...)
end
H.smt = getmetatable("")
H.sidx_old = H.smt.__index
H.sproxy = setmetatable({ format = H.fmt_check }, { __index = string })

-------------------------------------------------------------------------------
-- Deger tipleri: vec2_t, vec3_t, angle_t, color_t (vec * sayi bilerek YOK, API §11)
-------------------------------------------------------------------------------
local V = {}
H.V = V
V.ok3 = { length = true, length2d = true }
V.m3 = {}
V.mt3 = {
    __index = function(o, k)
        local f = V.m3[k]
        if type(k) == "string" then
            if f == nil then H.G.offlist["vec3_t:" .. k .. " (yok)"] = true
            elseif not V.ok3[k] then H.G.offlist["vec3_t:" .. k] = true end
        end
        return f
    end,
    __add = function(a, b) return V.v3(a.x + b.x, a.y + b.y, a.z + b.z) end,
    __sub = function(a, b) return V.v3(a.x - b.x, a.y - b.y, a.z - b.z) end,
    __unm = function(a) return V.v3(-a.x, -a.y, -a.z) end,
    __tostring = function(a) return "vec3(" .. a.x .. ", " .. a.y .. ", " .. a.z .. ")" end,
}
function V.v3(x, y, z) return setmetatable({ x = x or 0, y = y or 0, z = z or 0 }, V.mt3) end
V.m3.length = function(o) return math.sqrt(o.x * o.x + o.y * o.y + o.z * o.z) end
V.m3.length2d = function(o) return math.sqrt(o.x * o.x + o.y * o.y) end
V.m3.dist = function(o, b) return math.sqrt((o.x - b.x) ^ 2 + (o.y - b.y) ^ 2 + (o.z - b.z) ^ 2) end
V.m3.scaled = function(o, s) return V.v3(o.x * s, o.y * s, o.z * s) end
V.m3.to_angle = function(o)
    return V.ang(-math.deg(math.atan2(o.z, math.sqrt(o.x * o.x + o.y * o.y))), math.deg(math.atan2(o.y, o.x)), 0)
end
V.m2 = {}
V.ok2 = { length = true }
V.mt2 = {
    __index = function(o, k)
        local f = V.m2[k]
        if type(k) == "string" then
            if f == nil then H.G.offlist["vec2_t:" .. k .. " (yok)"] = true
            elseif not V.ok2[k] then H.G.offlist["vec2_t:" .. k] = true end
        end
        return f
    end,
    __add = function(a, b) return V.v2(a.x + b.x, a.y + b.y) end,
    __sub = function(a, b) return V.v2(a.x - b.x, a.y - b.y) end,
}
function V.v2(x, y) return setmetatable({ x = x or 0, y = y or 0 }, V.mt2) end
V.m2.length = function(o) return math.sqrt(o.x * o.x + o.y * o.y) end
V.mta = {
    __index = function(o, k)
        if k == "to_vector" then
            H.G.offlist["angle_t:to_vector"] = true
            return function(a)
                local y = math.rad(a.y)
                return V.v3(math.cos(y), math.sin(y), 0), V.v3(math.sin(y), -math.cos(y), 0), V.v3(0, 0, 1)
            end
        end
        if type(k) == "string" then H.G.offlist["angle_t:" .. k .. " (yok)"] = true end
        return nil
    end,
}
function V.ang(x, y, z) return setmetatable({ x = x or 0, y = y or 0, z = z or 0 }, V.mta) end
V.mtc = {
    __index = function(o, k)
        if k == "fade" then
            H.G.offlist["color_t:fade"] = true
            return function(a) return a end
        end
        if type(k) == "string" then H.G.offlist["color_t:" .. k .. " (yok)"] = true end
        return nil
    end,
}
function V.col(r, g, b, a) return setmetatable({ r = r or 255, g = g or 255, b = b or 255, a = a or 255 }, V.mtc) end
function V.ctor(fn, name, extra)
    local t = { new = fn }
    for k, v in pairs(extra or {}) do t[k] = v end
    return setmetatable(t, {
        __call = function(_, ...) return fn(...) end,
        __index = function(_, k) H.G.offlist[name .. "." .. tostring(k) .. " (yok)"] = true end,
    })
end
H.vec2_t = V.ctor(V.v2, "vec2_t")
H.vec3_t = V.ctor(V.v3, "vec3_t")
H.angle_t = V.ctor(V.ang, "angle_t")
H.color_t = V.ctor(V.col, "color_t", { from_hsb = function(h, s, b)
    H.G.offlist["color_t.from_hsb"] = true
    return V.col(255, 255, 255, 255)
end })

-------------------------------------------------------------------------------
-- Kati enumlar (API §14): bilinmeyen uye hata verir ve kaydedilir (e_hitboxes.STOMACH, e_cmd_buttons.RELOAD,
-- e_weapon_types.SNIPER nil donmez, patlar).
-------------------------------------------------------------------------------
H.E = {}
H.ENAME = {}
function H.mkenum(name, list, values, loose)
    local t, rev = {}, {}
    for i, m in ipairs(list) do
        local v = values and values[i] or (i - 1)
        t[m] = v
        rev[v] = m
    end
    H.E[name] = t
    H.ENAME[name] = rev
    return setmetatable({}, {
        __index = function(_, k)
            local v = t[k]
            if v == nil then
                if loose then return 900 end
                H.G.enum_bad[name .. "." .. tostring(k)] = true
                error(name .. "." .. tostring(k) .. " native uye degil", 2)
            end
            return v
        end,
        __newindex = function(_, k) H.G.forbidden["enum yazma " .. name .. "." .. tostring(k)] = true end,
    })
end
H.CB_LIST = { "PAINT", "SETUP_COMMAND", "RUN_COMMAND", "FINISH_COMMAND", "ANTIAIM", "HITSCAN", "TARGET_SELECTION",
    "AIMBOT_SHOOT", "AIMBOT_HIT", "AIMBOT_MISS", "EVENT", "NET_UPDATE", "PLAYER_ESP", "DRAW_MODEL", "DRAW_WATERMARK",
    "WORLD_HITMARKER", "SCREEN_HITMARKER", "SUPPORTIVE_RECTANGLE", "SHUTDOWN" }
H.CB_ALLOWED = { PAINT = true, SETUP_COMMAND = true, ANTIAIM = true, HITSCAN = true, TARGET_SELECTION = true,
    AIMBOT_SHOOT = true, AIMBOT_HIT = true, AIMBOT_MISS = true, EVENT = true, NET_UPDATE = true, SHUTDOWN = true }
H.ENUMS = {
    e_callbacks = H.mkenum("e_callbacks", H.CB_LIST, nil),
    e_hitboxes = H.mkenum("e_hitboxes", { "HEAD", "NECK", "PELVIS", "BODY", "THORAX", "CHEST", "UPPER_CHEST",
        "LEFT_THIGH", "RIGHT_THIGH", "LEFT_CALF", "RIGHT_CALF", "LEFT_FOOT", "RIGHT_FOOT", "LEFT_HAND", "RIGHT_HAND",
        "LEFT_UPPER_ARM", "LEFT_FOREARM", "RIGHT_UPPER_ARM", "RIGHT_FOREARM" }),
    e_hitgroups = H.mkenum("e_hitgroups", { "GENERIC", "HEAD", "CHEST", "STOMACH", "LEFT_ARM", "RIGHT_ARM", "LEFT_LEG",
        "RIGHT_LEG", "NECK", "GEAR" }, { 0, 1, 2, 3, 4, 5, 6, 7, 8, 10 }),
    e_hitscan_groups = H.mkenum("e_hitscan_groups", { "HEAD", "CHEST", "STOMACH", "ARMS", "LEGS", "FEET" }),
    e_player_flags = H.mkenum("e_player_flags", { "ON_GROUND", "DUCKING", "FAKE_CLIENT", "FROZEN" }, { 1, 2, 256, 32 }),
    e_cmd_buttons = H.mkenum("e_cmd_buttons", { "ATTACK", "JUMP", "DUCK", "FORWARD", "BACK", "USE", "MOVELEFT",
        "MOVERIGHT", "ATTACK2", "SPEED", "BULLRUSH" }, { 1, 2, 4, 8, 16, 32, 512, 1024, 2048, 131072, 4194304 }),
    e_font_flags = H.mkenum("e_font_flags", { "ANTIALIAS", "DROPSHADOW", "OUTLINE", "BOLD", "ITALIC", "ADDITIVE",
        "GAUSSIANBLUR" }, { 16, 128, 512, 1, 2, 256, 64 }),
    e_latency_flows = H.mkenum("e_latency_flows", { "OUTGOING", "INCOMING" }),
    e_weapon_types = H.mkenum("e_weapon_types", { "KNIFE", "PISTOL", "SMG", "RIFLE", "SHOTGUN", "MACHINE_GUN",
        "GRENADE" }, { 0, 1, 2, 3, 4, 6, 9 }),
    e_poses = H.mkenum("e_poses", { "JUMP_FALL", "BODY_PITCH", "RUN", "MOVE_YAW", "MOVE_BLEND_WALK", "STRAFE_DIR",
        "MOVE_BLEND_RUN", "STAND", "SPEED", "MOVE_BLEND_CROUCH_WALK", "AIM_BLEND_CROUCH_IDLE" }),
    e_animlayers = H.mkenum("e_animlayers", { "LEAN", "MOVEMENT_MOVE", "MOVEMENT_JUMP_OR_FALL",
        "MOVEMENT_STRAFECHANGE", "MOVEMENT_LAND_OR_CLIMB", "AIMMATRIX", "WEAPON_ACTION", "WHOLE_BODY", "FLASHED",
        "FLINCH", "ALIVELOOP", "WEAPON_ACTION_RECROUCH", "ADJUST" }),
    e_material_flags = H.mkenum("e_material_flags", { "NO_DRAW", "WIREFRAME", "IGNOREZ" }),
    e_keys = H.mkenum("e_keys", { "KEY_NONE", "MOUSE_LEFT", "MOUSE_RIGHT", "KEY_SPACE" }, nil, true),
    e_items = H.mkenum("e_items", { "WEAPON_NONE" }, nil, true),
}
H.CB = H.E.e_callbacks
H.CBN = H.ENAME.e_callbacks
H.HSG = H.E.e_hitscan_groups
H.HSGN = H.ENAME.e_hitscan_groups
H.BTNN = H.ENAME.e_cmd_buttons
H.HBN = H.ENAME.e_hitboxes
H.HBZ = { HEAD = 64, NECK = 60, PELVIS = 40, BODY = 44, THORAX = 48, CHEST = 50, UPPER_CHEST = 54 }

-------------------------------------------------------------------------------
-- Silahlar
-------------------------------------------------------------------------------
H.WEAPONS = {
    ssg08 = { "CWeaponSSG08", "weapon_ssg08", 5, 40 }, awp = { "CWeaponAWP", "weapon_awp", 5, 9 },
    scar20 = { "CWeaponSCAR20", "weapon_scar20", 5, 38 }, g3sg1 = { "CWeaponG3SG1", "weapon_g3sg1", 5, 11 },
    deagle = { "CDEagle", "weapon_deagle", 1, 1 }, revolver = { "CDEagle", "weapon_revolver", 1, 64 },
    glock = { "CWeaponGlock", "weapon_glock", 1, 4 }, ak47 = { "CAK47", "weapon_ak47", 3, 7 },
    knife = { "CKnife", "weapon_knife", 0, 42 }, bayonet = { "CKnife", "weapon_bayonet", 0, 500 },
    taser = { "CWeaponTaser", "weapon_taser", 0, 31 }, hegrenade = { "CHEGrenade", "weapon_hegrenade", 9, 44 },
}
H.CFG_OF = { scar20 = 0, g3sg1 = 0, ssg08 = 1, awp = 2, deagle = 3, revolver = 4, glock = 5, hkp2000 = 5,
    usp_silencer = 5, p250 = 5, fiveseven = 5, tec9 = 5, cz75a = 5, elite = 5 }
H.WGROUPS = { "auto", "scout", "awp", "deagle", "revolver", "pistols", "other" }
function H.weapon(name, class)
    local w = H.WEAPONS[name] or { "CWeapon", "weapon_" .. name, 3, 0 }
    return { name = name, class = class or w[1], console = w[2], wtype = w[3], def = w[4] }
end
function H.melee(w)
    if w == nil then return nil end
    if w.class == "CKnife" or w.name == "knife" or w.name == "bayonet" then return "knife" end
    if w.name == "taser" or w.class == "CWeaponTaser" then return "zeus" end
    return nil
end
function H.mkplayer(idx, name, x, y, z, enemy, wname)
    return { idx = idx, name = name, origin = V.v3(x, y, z), health = 100, ground = true, duck = 0, ducking = false,
        vel = V.v3(0, 0, 0), eye_yaw = (idx == 2) and 180 or ((idx == 3) and -90 or 0), sim_shift = 0,
        weapon = H.weapon(wname), alive = true, dormant = false, enemy = enemy, team = enemy and 2 or 3,
        steam64 = "7656119800000000" .. idx, movetype = 2, next_attack = 0 }
end

-------------------------------------------------------------------------------
-- Donmus menu (SPEC §2): T-LOAD-3 ve eleman bulma bu tablodan.
-------------------------------------------------------------------------------
H.GROUPS = {
    home = { "Nykle.win | Home", 1 }, console = { "Nykle.win | Console", 2 }, aa = { "Nykle.win | Anti-Aim", 1 },
    protect = { "Nykle.win | Protection", 2 }, builder = { "Nykle.win | Builder", 1 },
    bexploit = { "Nykle.win | Builder exploit", 2 }, exploits = { "Nykle.win | Exploits", 1 },
    peek = { "Nykle.win | Peek", 2 }, rage = { "Nykle.win | Ragebot", 1 }, visuals = { "Nykle.win | Visuals", 1 },
    misc = { "Nykle.win | Misc", 1 },
}
H.GROUP_ORDER = { "home", "console", "aa", "protect", "builder", "bexploit", "exploits", "peek", "rage", "visuals", "misc" }
H.TAB_OF = { home = 1, console = 1, aa = 2, protect = 2, builder = 3, bexploit = 3, exploits = 4, peek = 4, rage = 5,
    visuals = 6, misc = 7 }
-- { anahtar, grup, ad, tip, varsayilan, p1 (min / ogeler / sahip), p2 (max) }
H.EL = {
    { "enabled", "home", "Enable Nykle.win", "cb", true },
    { "tab", "home", "Tab", "sel", 1, { "Home", "Anti-Aim", "Builder", "Exploits", "Ragebot", "Visuals", "Misc" } },
    { "recommended", "home", "Always use recommended settings", "cb", true },
    { "info1", "home", "No need to change any setting.", "txt" },
    { "info2", "home", "Bind: native manual / auto direction / autopeek", "txt" },
    { "resolver_log", "console", "Resolver log", "cb", true },
    { "shot_log", "console", "Shot log", "cb", true },
    { "hit_log", "console", "Hit log", "cb", true },
    { "brute_log", "console", "Anti-brute log", "cb", false },
    { "debug_log", "console", "Detailed log (for analysis)", "cb", true },
    { "log_quiet", "console", "Logs only in console + file (not on screen)", "cb", true },
    { "log_copy", "console", "Copy all logs", "btn" },
    { "log_print", "console", "Print all logs to console", "btn" },
    { "log_save", "console", "Save logs to file now", "btn" },
    { "log_clear", "console", "Clear saved logs", "btn" },
    { "forget", "console", "Forget learned enemies", "btn" },
    { "stats_reset", "console", "Reset stats", "btn" },
    { "pitch", "aa", "Pitch", "sel", 1, { "Down", "Zero", "Off" } },
    { "yaw_base", "aa", "Yaw base", "sel", 1, { "At target", "Local view" } },
    { "avoid_backstab", "aa", "Avoid backstab", "cb", true },
    { "backstab_def", "aa", "Defensive while knife is close", "cb", true },
    { "legit_use", "aa", "Legit AA on use", "cb", true },
    { "spin", "aa", "Spin when idle", "cb", true },
    { "spin_warmup", "aa", "Spin in warmup", "cb", false },
    { "spin_enemies", "aa", "Spin: no enemies alive", "cb", true },
    { "spin_pitch", "aa", "Spin pitch", "sel", 1, { "Off", "Down" } },
    { "spin_speed", "aa", "Spin speed", "sl", 6, 1, 20 },
    { "fs_air", "protect", "FS: disable in air", "cb", true },
    { "fs_crouch", "protect", "FS: disable while crouching", "cb", false },
    { "fs_slow", "protect", "FS: disable while slow walking", "cb", false },
    { "fs_moving", "protect", "FS: disable while moving", "cb", false },
    { "fs_auto", "protect", "FS: auto when standing still", "cb", true },
    { "safe_head", "protect", "Safe head", "cb", true },
    { "safe_knife", "protect", "Safe head: knife/zeus in air crouch", "cb", true },
    { "safe_air", "protect", "Safe head: any air crouch", "cb", false },
    { "safe_high", "protect", "Safe head: high ground", "cb", false },
    { "anti_brute", "protect", "Anti-bruteforce", "cb", true },
    { "brute_reset", "protect", "Anti-brute reset after", "sl", 6, 1, 15 },
    { "brute_random", "protect", "Random anti-brute order", "cb", true },
    { "phase_test", "protect", "Phase test (one phase per round, fair comparison)", "cb", true },
    { "knife_md", "protect", "Lower Min. damage vs close knife/zeus", "cb", true },
    { "crouch_cap", "protect", "Desync keeper: slow crouch-walk when seen", "cb", true },
    { "crouch_speed", "protect", "Crouch speed", "sl", 38, 20, 78 },
    { "safe_recharge", "exploits", "Safe recharge", "cb", true },
    { "crouch_recharge", "exploits", "Also while crouched (peek / crouch move)", "cb", false },
    { "hidden_spin", "exploits", "Hidden spin speed", "sl", 10, 1, 30 },
    { "smart_force", "exploits", "Force defensive when seen / near (Smart)", "cb", true },
    { "def_cooldown", "exploits", "Re-arm cooldown (let DT refill after defensive)", "cb", true },
    { "def_edge", "exploits", "Defensive: one shift per event (no repeat while seen)", "cb", true },
    { "def_repeat", "exploits", "Defensive: repeat while seen (ticks, 0 = once)", "sl", 16, 0, 64 },
    { "ideal_tick", "exploits", "Ideal tick: teleport back after an autopeek sniper shot", "cb", true },
    { "anti_peek", "exploits", "Defensive vs enemy peeks", "cb", true },
    { "switch_def", "exploits", "Defensive while switching weapons", "cb", true },
    { "clean_shot", "exploits", "Clean shot (no lag while shooting)", "cb", true },
    { "air_teleport", "exploits", "Teleport in air when seen", "cb", true },
    { "air_lc", "exploits", "Air: break LC (uncharge + full fake lag when seen)", "cb", true },
    { "air_lag", "exploits", "Air lag (defensive every tick)", "cb", true },
    { "air_hc", "exploits", "In-air hit chance (snipers, 0 = off)", "sl", 0, 0, 100 },
    { "auto_peek", "peek", "Auto peek state (moving into view)", "cb", true },
    { "ai_peek", "peek", "AI peek (hold autopeek key)", "cb", true },
    { "peek_defensive", "peek", "Defensive during AI peek", "cb", true },
    { "afk", "peek", "AFK mode (AI peek here + strafe, full exploits)", "cb", false },
    { "afk_auto", "peek", "Auto AFK (no input 8 s after spawn)", "cb", true },
    { "resolver", "rage", "Adaptive resolver", "cb", true },
    { "low_hp_safe", "rage", "Finish low HP (<=30) with safe point", "cb", true },
    { "smart_baim", "rage", "Smart body aim", "cb", true },
    { "head_only", "rage", "Head unless body kills (snipers)", "cb", true },
    { "dt_pair", "rage", "DT pair counts as lethal (body x2 >= HP)", "cb", false },
    { "fake_body", "rage", "Snipers: lethal body on fake records", "cb", true },
    { "wait_real", "rage", "Wait for real record (enemy defensive)", "cb", true },
    { "fresh_only", "rage", "Snipers: fresh record only", "cb", true },
    { "counter_window", "rage", "Counter window: no waits + priority vs an enemy who just fired", "cb", true },
    { "ext_body", "rage", "Body vs extended (repeated head misses)", "cb", true },
    { "hider_body", "rage", "Body vs head hiders (head share <= 35 pct over 12+ shots)", "cb", true },
    { "indicators", "visuals", "Crosshair indicators", "cb", true },
    { "accent", "visuals", "Indicator color", "col", { 150, 190, 255, 255 }, "indicators" },
    { "arrows", "visuals", "Manual arrows", "cb", true },
    { "arrow_color", "visuals", "Arrow color", "col", { 150, 190, 255, 255 }, "arrows" },
    { "left_ind", "visuals", "Left indicators (DT / HS / FD / DEF / MD ...)", "cb", true },
    { "stats_panel", "visuals", "Stats panel", "cb", false },
    { "res_panel", "visuals", "Resolver panel", "cb", true },
    { "panel_size", "visuals", "Panel size", "sl", 160, 70, 200 },
    { "panel_x", "visuals", "Panel position X", "sl", 560, 0, 1000 },
    { "panel_y", "visuals", "Panel position Y", "sl", 380, 0, 1000 },
    { "clantag", "misc", "Clan tag: Nykle.win (animated)", "cb", true },
    { "trash_talk", "misc", "Trash talk", "cb", false },
    { "tt_kill", "misc", "On kill", "cb", true },
    { "tt_headshot", "misc", "Kills: headshots only", "cb", false },
    { "tt_death", "misc", "On death", "cb", true },
    { "tt_chance", "misc", "Chance", "sl", 100, 1, 100 },
    { "tt_chat", "misc", "Chat", "sel", 1, { "All chat", "Team chat" } },
    { "tt_delay", "misc", "Message delay", "sl", 2.3, 0.5, 5.0 },
    { "jump_scout", "misc", "Jump scout (no air strafe on standing jump)", "cb", true },
    { "auto_buy", "misc", "Auto buy grenades (HE + smoke + molotov)", "cb", true },
    { "left_hand", "misc", "Left hand (cl_righthand 0, permanent)", "cb", true },
    { "aspect", "misc", "Aspect ratio", "sel", 1, { "4:3", "Off", "5:4", "16:10" } },
    { "fps_boost", "misc", "FPS boost (shadows / 3D sky / post-process off)", "cb", true },
    { "fps_ragdolls", "misc", "Disable ragdolls (bodies vanish)", "cb", false },
}
H.STATES = { "Global", "Standing", "Moving", "Slow walk", "Crouching", "Crouch move", "Peek", "Air", "Air crouch",
    "Fake duck", "Manual", "Freestanding", "Safe head" }
H.BDEF = {
    Global = { -20, 40, 1, 60, 60 }, Standing = { -23, 51, 1, 60, 60 }, Moving = { -20, 50, 1, 58, 58 },
    ["Slow walk"] = { -23, 51, 2, 58, 58 }, Crouching = { -20, 30, 1, 58, 58 }, ["Crouch move"] = { -20, 30, 1, 58, 58 },
    Peek = { -20, 45, 1, 58, 58 }, Air = { -13, 34, 1, 58, 58 }, ["Air crouch"] = { -15, 44, 1, 58, 58 },
    ["Fake duck"] = { 0, 0, 1, 58, 58 }, Manual = { 0, 0, 1, 60, 60 }, Freestanding = { 0, 0, 1, 60, 60 },
    ["Safe head"] = { 0, 0, 1, 30, 30 },
}
H.OVR_STATES = { Standing = true, Moving = true, ["Slow walk"] = true, Crouching = true, ["Crouch move"] = true,
    Peek = true, Air = true, ["Air crouch"] = true }
H.SPECIAL = { Manual = true, Freestanding = true, ["Safe head"] = true }
H.XDEF = { -- { Defensive, Hidden pitch, Hidden yaw } (1-tabanli)
    Standing = { 3, 1, 1 }, Moving = { 3, 3, 4 }, ["Slow walk"] = { 3, 3, 4 }, Crouching = { 3, 1, 1 },
    ["Crouch move"] = { 3, 3, 4 }, Peek = { 3, 1, 1 }, Air = { 3, 3, 3 }, ["Air crouch"] = { 3, 3, 4 },
    Manual = { 3, 1, 1 }, Freestanding = { 3, 1, 1 }, ["Safe head"] = { 2, 1, 1 },
}
do
    local B = H.EL
    B[#B + 1] = { "state", "builder", "State", "sel", 1, H.STATES }
    for _, S in ipairs(H.STATES) do
        local d = H.BDEF[S]
        local p = "[" .. S .. "] "
        local fd = S == "Fake duck"
        if H.OVR_STATES[S] then B[#B + 1] = { "b:" .. S .. ":Override", "builder", p .. "Override", "cb", true } end
        B[#B + 1] = { "b:" .. S .. ":Yaw mode", "builder", p .. "Yaw mode", "sel", 1, { "L&R", "X-Way" } }
        B[#B + 1] = { "b:" .. S .. ":Yaw left", "builder", p .. "Yaw left", "sl", d[1], -180, 180 }
        B[#B + 1] = { "b:" .. S .. ":Yaw right", "builder", p .. "Yaw right", "sl", d[2], -180, 180 }
        B[#B + 1] = { "b:" .. S .. ":Ways", "builder", p .. "Ways", "sl", 3, 3, 5 }
        local wd = { -30, 0, 30, -15, 15 }
        for n = 1, 5 do
            B[#B + 1] = { "b:" .. S .. ":Way " .. n, "builder", p .. "Way " .. n, "sl", wd[n], -180, 180 }
        end
        B[#B + 1] = { "b:" .. S .. ":Yaw randomize", "builder", p .. "Yaw randomize", "sl", fd and 20 or 0, 0, 30 }
        B[#B + 1] = { "b:" .. S .. ":Yaw modifier", "builder", p .. "Yaw modifier", "sel", 1,
            { "Off", "Center", "Offset", "Random", "Spin", "3-Way", "5-Way" } }
        B[#B + 1] = { "b:" .. S .. ":Modifier randomize", "builder", p .. "Modifier randomize", "sl", 0, 0, 60 }
        B[#B + 1] = { "b:" .. S .. ":Modifier offset", "builder", p .. "Modifier offset", "sl", 0, -180, 180 }
        local by = 1
        if S == "Manual" or S == "Freestanding" then by = 2 elseif fd or S == "Safe head" then by = 3 end
        B[#B + 1] = { "b:" .. S .. ":Body yaw", "builder", p .. "Body yaw", "sel", by, { "Jitter", "Static", "Random", "Off" } }
        B[#B + 1] = { "b:" .. S .. ":Body freestanding", "builder", p .. "Body freestanding", "sel", fd and 2 or 1, { "Off", "On" } }
        B[#B + 1] = { "b:" .. S .. ":Delay randomize", "builder", p .. "Delay randomize", "sl",
            (fd or H.SPECIAL[S]) and 0 or 1, 0, 5 }
        B[#B + 1] = { "b:" .. S .. ":Limit randomize", "builder", p .. "Limit randomize", "sl", fd and 10 or 0, 0, 30 }
        B[#B + 1] = { "b:" .. S .. ":Jitter delay", "builder", p .. "Jitter delay", "sl", d[3], 1, 10 }
        B[#B + 1] = { "b:" .. S .. ":Left limit", "builder", p .. "Left limit", "sl", d[4], 0, 60 }
        B[#B + 1] = { "b:" .. S .. ":Right limit", "builder", p .. "Right limit", "sl", d[5], 0, 60 }
    end
    for _, S in ipairs(H.STATES) do
        local p = "[" .. S .. "] "
        local x = H.XDEF[S]
        if x == nil then
            B[#B + 1] = { "x:" .. S .. ":text", "bexploit", p .. "No exploit settings (Global shares AA only, fake duck has no DT)", "txt" }
        else
            B[#B + 1] = { "x:" .. S .. ":Defensive", "bexploit", p .. "Defensive", "sel", x[1],
                { "Off", "On peek", "Smart", "Always on", "Tick based" } }
            B[#B + 1] = { "x:" .. S .. ":Defensive every", "bexploit", p .. "Defensive every", "sl", 14, 2, 22 }
            B[#B + 1] = { "x:" .. S .. ":Hidden pitch", "bexploit", p .. "Hidden pitch", "sel", x[2],
                { "Off", "Down", "Up", "Zero", "Switch", "Random", "Custom" } }
            B[#B + 1] = { "x:" .. S .. ":Pitch value", "bexploit", p .. "Pitch value", "sl", 0, -89, 89 }
            B[#B + 1] = { "x:" .. S .. ":Hidden yaw", "bexploit", p .. "Hidden yaw", "sel", x[3],
                { "Off", "Sideways", "Spin", "Random", "Forward", "Custom" } }
            B[#B + 1] = { "x:" .. S .. ":Yaw value", "bexploit", p .. "Yaw value", "sl", 90, -180, 180 }
        end
    end
    H.EL_BY = {}
    for _, r in ipairs(B) do H.EL_BY[r[1]] = r end
end

-------------------------------------------------------------------------------
-- Native agac (SPEC §3.6 + native_dump). ov = bu yola yazmaya izinli Override anahtari (§3.4).
-------------------------------------------------------------------------------
function H.native_defs(neutral)
    local D = {}
    local function add(path, t) t.path = path; D[#D + 1] = t end
    add("aimbot/general/exploits/doubletap/enable", { t = "cb", v = true, key = "dt" })
    add("aimbot/general/exploits/hideshots/enable", { t = "cb", v = true, key = "hs" })
    add("aimbot/general/fake ping/enable", { t = "cb", v = true, key = "fakeping" })
    add("aimbot/general/misc/autopeek", { t = "cb", v = true, key = "autopeek" })
    add("antiaim/main/general/fakeduck", { t = "cb", v = true, key = "fd" })
    add("misc/main/movement/slow walk", { t = "cb", v = true, key = "slowwalk" })
    add("antiaim/main/auto direction/enable", { t = "cb", v = true, key = "fs" })
    add("antiaim/main/auto direction/states", { t = "multi", items = { "Air", "Move", "Stand" }, v = { true, true, true }, ov = "fs_states" })
    add("antiaim/main/manual/invert desync", { t = "text", key = "inverter" })
    add("antiaim/main/extended angles/enable", { t = "cb", v = true, key = "ext" })
    add("antiaim/main/extended angles/enable while moving", { t = "cb", v = not neutral, ov = "ext_moving", neutral = false })
    add("antiaim/main/angles/jitter mode", { t = "sel", items = { "None", "Static", "Random" }, v = neutral and 1 or 2, ov = "jitter_mode", neutral = 1 })
    add("antiaim/main/angles/rotate", { t = "cb", v = not neutral, ov = "rotate", neutral = false })
    add("antiaim/main/angles/yaw add", { t = "sl", v = neutral and 0 or 6, min = -180, max = 180, ov = "yaw_add", neutral = 0 })
    add("antiaim/main/angles/body lean", { t = "sel", items = { "None", "Static", "Static jitter", "Random jitter", "Sway" }, v = neutral and 1 or 2, ov = "body_lean", neutral = 1 })
    add("antiaim/main/angles/moving body lean", { t = "cb", v = not neutral, ov = "moving_body_lean", neutral = false })
    add("antiaim/main/desync/override stand#move", { t = "cb", v = not neutral, ov = "override_move", neutral = false })
    add("antiaim/main/desync/override stand#slow walk", { t = "cb", v = not neutral, ov = "override_slow", neutral = false })
    add("antiaim/main/desync/anti bruteforce", { t = "cb", v = not neutral, ov = "anti_brute_native", neutral = false })
    add("antiaim/main/desync/on shot", { t = "sel", items = { "Off", "Opposite", "Same side", "Random" }, v = neutral and 1 or 2, ov = "on_shot", neutral = 1 })
    add("antiaim/main/desync/side#stand", { t = "sel", items = { "None", "Left", "Right", "Jitter", "Peek fake", "Peek real", "Body sway" }, v = neutral and 2 or 4, ov = "side_stand", neutral = 2 })
    add("antiaim/main/desync/left amount#stand", { t = "sl", v = neutral and 100 or 50, min = 0, max = 100, ov = "left_amount_stand", neutral = 100 })
    add("antiaim/main/desync/right amount#stand", { t = "sl", v = neutral and 100 or 50, min = 0, max = 100, ov = "right_amount_stand", neutral = 100 })
    add("antiaim/main/fakelag/amount", { t = "sl", v = 14, min = 0, max = 15 })
    add("antiaim/main/fakelag/break lag compensation", { t = "cb", v = true })
    add("antiaim/main/angles/pitch", { t = "sel", items = { "None", "Down", "Up", "Zero", "Jitter" }, v = 2 })
    add("antiaim/main/angles/yaw base", { t = "sel", items = { "None", "Viewangle", "At target (crosshair)", "At target (distance)", "Velocity" }, v = 3 })
    add("antiaim/main/general/enable", { t = "cb", v = true, key = "aa" })
    add("antiaim/main/general/anti knife", { t = "cb", v = true })
    add("aimbot/general/aimbot/autofire", { t = "cb", v = true })
    add("misc/utility/buybot/enable", { t = "cb", v = false })
    add("misc/utility/buybot/grenades", { t = "multi", items = { "Fire", "Flash", "High Explosive", "Smoke" }, v = { false, false, false, false } })
    add("misc/main/movement/autostrafer", { t = "cb", v = true, ov = "autostrafer" })
    for _, w in ipairs(H.WGROUPS) do
        add("aimbot/" .. w .. "/targeting/min. damage", { t = "sl", v = 100, min = 0, max = 130 })
        add("aimbot/" .. w .. "/target overrides/min. damage", { t = "sl", v = 10, min = 0, max = 130, key = "md_ovr" })
        add("aimbot/" .. w .. "/targeting/hitchance", { t = "sl", v = 70, min = 0, max = 100 })
        local early = (w == "scout" or w == "awp")
        add("aimbot/" .. w .. "/accuracy/options", { t = "multi", items = { "Crouch", "Delay Shot Until Fully Accurate",
            "Dont Stop In Fire", "Early", "Full Stop", "In-Air", "Stop Between Shots" }, v = { false, false, false, early, true, false, false } })
    end
    return D
end
H.OV_KEYS = { jitter_mode = true, rotate = true, body_lean = true, moving_body_lean = true, override_move = true,
    override_slow = true, anti_brute_native = true, on_shot = true, side_stand = true, left_amount_stand = true,
    right_amount_stand = true, yaw_add = true, ext_moving = true, fs_states = true, autostrafer = true }
H.FPS_CVARS = { "r_3dsky", "r_shadows", "cl_csm_shadows", "cl_csm_rope_shadows", "cl_csm_sprite_shadows",
    "cl_csm_static_prop_shadows", "cl_csm_viewmodel_shadows", "cl_csm_world_shadows", "cl_foot_contact_shadows",
    "mat_postprocess_enable", "func_break_max_pieces", "muzzleflash_light", "r_dynamic" }
H.CVAR_DEF = { cl_righthand = 1, r_aspectratio = 0, developer = 1, cl_disable_ragdolls = 0, sv_gravity = 800,
    cl_csm_enabled = 1, func_break_max_pieces = 15, con_notifytime = 8 }
for _, c in ipairs(H.FPS_CVARS) do if H.CVAR_DEF[c] == nil then H.CVAR_DEF[c] = 1 end end

-------------------------------------------------------------------------------
-- Ad alani vekili: izinli listede olmayan erisimler (§3.2 "script baska bir sey cagirmaz") kaydedilir.
-------------------------------------------------------------------------------
function H.ns(name, impl, allowed)
    return setmetatable({}, {
        __index = function(_, k)
            local v = impl[k]
            if v == nil then
                -- izinli ama bu yapida olmayan uye (ozellik denetimi, G18): kayit yok
                if allowed ~= true and not allowed[k] then H.G.offlist[name .. "." .. tostring(k) .. " (yok)"] = true end
                return nil
            end
            if allowed ~= true and not allowed[k] then H.G.offlist[name .. "." .. tostring(k)] = true end
            return v
        end,
        __newindex = function(_, k, v)
            H.G.forbidden["native tabloya yazma " .. name .. "." .. tostring(k)] = true
            rawset(impl, k, v)
        end,
    })
end
function H.set_of(list)
    local s = {}
    for _, k in ipairs(list) do s[k] = true end
    return s
end
function H.objmt(kind, methods, allowed)
    return {
        __index = function(o, k)
            local f = methods[k]
            if f == nil then
                if type(k) == "string" then H.G.offlist[kind .. ":" .. k .. " (yok)"] = true end
                return nil
            end
            if not allowed[k] then H.G.offlist[kind .. ":" .. k] = true end
            return f
        end,
    }
end
function H.num_ok(v, what)
    if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then
        H.G.forbidden["sayi olmayan / sonsuz deger: " .. what .. " = " .. tostring(v)] = true
        return false
    end
    return true
end

-------------------------------------------------------------------------------
-- Bir script ornegi + sahte dunya. opts:
--   mode, files (paylasilan sahte dosyalar), pre(T) (yuklemeden once dunya kurulumu), raw (yuklemeden sonra
--   hicbir menu degisikligi yapma), keep_afk (Auto AFK acik kalsin), rec_off (recommended kapat), neutral
--   (native'ler zaten notr), name, expect_errors.
-------------------------------------------------------------------------------
function H.make(opts)
    opts = opts or {}
    H.G.insts = H.G.insts + 1
    local mode = opts.mode or H.mode
    local T = { opts = opts, mode = mode, name = opts.name or "?", prints = {}, aa = {}, hs = {}, ts = {}, moves = {},
        cmds = {}, natw = {}, cvw = {}, shift = {}, simreads = {}, unch = {}, rmjump = {}, blk = {}, alw = {}, ftexts = {}, delays = {}, cbs = {},
        in_cb = 0, in_paint = false, fed = { ext = {}, extw = {}, hider = {}, shots = {} }, dsy = {}, ign_n = 0, cmdno = 100,
        group_col = {}, group_vis = {}, els = {}, el_list = {}, groups = {}, refcache = {}, find_unknown = {},
        props_unknown = {}, clantags = {}, shot_id = 0, tb = {}, wrote = {}, raw_err = {}, ents = {}, fs = { h = {}, n = 0,
        written = 0, pathids = {} }, fonts = 0, badnames = {}, sel_range = {}, el_set_bad = {}, ntr = {}, pread = {} }
    H.live[#H.live + 1] = T
    local W = { tick = opts.tick or 10000, interval = 1 / 64, choke_cycle = 4, choked = 0, charge = 14, max_charge = 14,
        auto_recharge = true, rc_blocked = false, keys = { dt = true, aa = true }, manual = 0, menu_open = false,
        freeze = false, warmup = false, buttons = {}, view = { x = 0, y = 0 }, move = { x = 0, y = 0 },
        can_fire = false, map = "de_mirage", sign_conv = 1, getter_lag = 0, side_conv = 1,
        sees = { [2] = 0, [3] = 0 }, see_fn = {}, head_dmg = { [2] = 0, [3] = 0 }, body_dmg = { [2] = 0, [3] = 0 },
        scan = {}, wall = {}, ents_by_name = {}, stuck = {}, files = opts.files or {}, cvar_unreadable = {},
        gravity = 800, floor_z = 0, real_off = 0, cv = {}, next_primary = 0 }
    T.W = W
    W.p = { [1] = H.mkplayer(1, "tester", 0, 0, 0, false, "ssg08"), [2] = H.mkplayer(2, "Alpha", 500, 0, 0, true, "ak47"),
        [3] = H.mkplayer(3, "Bravo", 0, 500, 0, true, "ak47") }
    local P = W.p
    for k, v in pairs(H.CVAR_DEF) do W.cv[k] = v end
    T.nat = {}
    T.nat_list = H.native_defs(opts.neutral)
    for _, d in ipairs(T.nat_list) do
        d.value = d.v
        if d.t == "multi" then
            local c = {}
            for i, b in ipairs(d.v) do c[i] = b end
            d.value = c
        end
        d.snap0 = d.value
        T.nat[d.path] = d
    end

    function T.now() return W.tick * W.interval end
    function T.rt() return W.tick * W.interval + W.real_off end
    function T.call(fn, ...)
        T.in_cb = T.in_cb + 1
        local ok, err = pcall(fn, ...)
        T.in_cb = T.in_cb - 1
        if not ok then
            T.raw_err[#T.raw_err + 1] = tostring(err)
            H.G.raw_err[#H.G.raw_err + 1] = T.name .. ": " .. tostring(err)
        end
        return ok
    end
    function T.fire(cbname, ...)
        local list = T.cbs[H.CB[cbname]]
        if list == nil then return end
        for _, h in ipairs(list) do T.call(h.fn, ...) end
    end
    function T.say(s) T.prints[#T.prints + 1] = s end

    -- entity nesneleri ------------------------------------------------------------------------------
    local ENT, WPN = {}, {}
    local ENT_OK = H.set_of({ "get_prop", "get_index", "is_alive", "is_dormant", "is_enemy", "get_name", "get_steamids",
        "get_eye_position", "get_hitbox_pos", "has_player_flag", "get_active_weapon", "get_class_name" })
    local WPN_OK = H.set_of({ "get_name", "get_class_name", "get_weapon_data", "get_prop" })
    local ENT_MT = H.objmt("entity", ENT, ENT_OK)
    local WPN_MT = H.objmt("weapon", WPN, WPN_OK)
    function T.ent(i)
        local e = T.ents[i]
        if e == nil then
            e = setmetatable({ _i = i }, ENT_MT)
            T.ents[i] = e
        end
        return e
    end
    function T.thing(class, x, y, z)
        return setmetatable({ _i = 60 + #W.ents_by_name, _class = class, _origin = V.v3(x, y, z) }, ENT_MT)
    end
    local function pl(o) return P[rawget(o, "_i")] end
    ENT.get_index = function(o) return rawget(o, "_i") end
    ENT.is_alive = function(o) local p = pl(o); return p ~= nil and p.alive and p.health > 0 end
    ENT.is_dormant = function(o) local p = pl(o); return p ~= nil and p.dormant == true end
    ENT.is_enemy = function(o) local p = pl(o); return p ~= nil and p.enemy == true end
    -- T.pread[tick]: PAINT icindeki isim / Steam ID / iz / dusman varlik okumalari (T-STAT-7, FPS kurali).
    local function paint_read(kind)
        if T.in_paint then
            local r = T.pread[W.tick] or { name = 0, sid = 0, trace = 0, ent = 0 }
            T.pread[W.tick] = r
            r[kind] = r[kind] + 1
        end
    end
    -- Dusman varliginin her metot okumasi (get_index haric) PAINT'te sayilir.
    local ent_index = ENT_MT.__index
    ENT_MT.__index = function(o, k)
        if T.in_paint and k ~= "get_index" then
            local p = P[rawget(o, "_i")]
            if p ~= nil and p.enemy then paint_read("ent") end
        end
        return ent_index(o, k)
    end
    ENT.get_name = function(o) paint_read("name"); local p = pl(o); return p and p.name or "" end
    ENT.get_steamids = function(o) paint_read("sid"); local p = pl(o); return "[U:1:" .. p.idx .. "]", p.steam64 end
    ENT.get_class_name = function(o) return rawget(o, "_class") or "CCSPlayer" end
    ENT.is_player = function(o) return pl(o) ~= nil end
    ENT.is_valid = function() return true end
    ENT.get_render_origin = function(o) local p = pl(o); return V.v3(p.origin.x, p.origin.y, p.origin.z) end
    ENT.get_eye_position = function(o)
        local p = pl(o)
        return V.v3(p.origin.x, p.origin.y, p.origin.z + 64)
    end
    ENT.get_hitbox_pos = function(o, hb)
        if type(hb) ~= "number" then error("get_hitbox_pos: gecersiz hitbox " .. tostring(hb), 2) end
        local p = pl(o)
        local dz = H.HBZ[H.HBN[hb] or ""] or 30
        return V.v3(p.origin.x, p.origin.y, p.origin.z + dz)
    end
    ENT.has_player_flag = function(o, f)
        if type(f) ~= "number" then error("has_player_flag: gecersiz bayrak " .. tostring(f), 2) end
        local p = pl(o)
        local name = H.ENAME.e_player_flags[f]
        if name == "ON_GROUND" then return p.ground == true end
        if name == "DUCKING" then return p.ducking == true or p.duck >= 0.9 end
        return false
    end
    ENT.get_active_weapon = function(o)
        local p = pl(o)
        if p == nil or p.weapon == nil or not p.alive then return nil end
        if p._wsrc ~= p.weapon then
            p._wsrc = p.weapon
            p._wobj = setmetatable({ _w = p.weapon, _i = p.idx }, WPN_MT)
        end
        return p._wobj
    end
    ENT.get_prop = function(o, name, i)
        local orig = rawget(o, "_origin")
        if orig ~= nil then
            if name == "m_vecOrigin" then return V.v3(orig.x, orig.y, orig.z) end
            return 0
        end
        local p = pl(o)
        if name == "m_iHealth" then return p.alive and p.health or 0
        elseif name == "m_fFlags" then return (p.ground and 1 or 0) + ((p.ducking or p.duck >= 0.9) and 2 or 0)
        elseif name == "m_vecVelocity" then return V.v3(p.vel.x, p.vel.y, p.vel.z)
        elseif name == "m_vecOrigin" then return V.v3(p.origin.x, p.origin.y, p.origin.z)
        elseif name == "m_flDuckAmount" then return p.duck
        elseif name == "m_MoveType" then return p.movetype
        elseif name == "m_flNextAttack" then return p.next_attack or 0
        elseif name == "m_flSimulationTime" or name == "m_flOldSimulationTime" then
            -- simreads[idx][tick]: dusmanin sim zamanini sadece takip (T.sample) okur -> tick basina ornek sayisi.
            if name == "m_flSimulationTime" and p.idx ~= 1 then
                T.simreads[p.idx] = T.simreads[p.idx] or {}
                T.simreads[p.idx][W.tick] = (T.simreads[p.idx][W.tick] or 0) + 1
            end
            -- sim_every: dusman paketleri bogar (fake duck), simulasyon zamani sim_every tick'te bir ilerler.
            local st = W.tick - p.sim_shift - (name == "m_flOldSimulationTime" and (p.sim_every or 1) or 0)
            if p.sim_every then st = st - st % p.sim_every end
            return st * W.interval
        elseif name == "m_angEyeAngles" or name == "m_angEyeAngles[1]" or name == "m_angEyeAngles[0]" then
            if T.mode == "nofeature" then return nil end
            if name == "m_angEyeAngles[1]" or i == 1 then return p.eye_yaw end
            if name == "m_angEyeAngles[0]" or i == 0 then return 89 end
            return V.ang(89, p.eye_yaw, 0)
        elseif name == "m_iTeamNum" then return p.team
        elseif name == "m_lifeState" then return p.alive and 0 or 2
        elseif name == "m_nTickBase" then return W.tick
        elseif name == "m_bIsScoped" then return 0
        elseif name == "m_flLowerBodyYawTarget" then return p.eye_yaw
        elseif name == "m_ArmorValue" then return 100
        elseif name == "m_bHasHelmet" then return 1
        elseif name == "m_flVelocityModifier" then return 1
        elseif name == "m_vecViewOffset[2]" then return 64
        elseif name == "m_bDucking" then return p.ducking and 1 or 0
        elseif name == "m_flMaxspeed" then return 250
        elseif name == "m_szLastPlaceName" then return p.place or ""
        end
        T.props_unknown[tostring(name)] = true
        return 0
    end
    WPN.get_name = function(o) return rawget(o, "_w").name end
    WPN.get_class_name = function(o) return rawget(o, "_w").class end
    WPN.get_index = function(o) return rawget(o, "_i") * 10 end
    WPN.get_weapon_data = function(o)
        local w = rawget(o, "_w")
        return { console_name = w.console, type = w.wtype, max_clip = 10, damage = 80, range = 8192, max_speed = 230,
            name = w.console }
    end
    WPN.get_weapon_inaccuracy = function() return 0 end
    WPN.get_prop = function(o, name)
        local w = rawget(o, "_w")
        if name == "m_flNextPrimaryAttack" then return W.next_primary or 0
        elseif name == "m_fLastShotTime" then return P[rawget(o, "_i")].last_shot or 0
        elseif name == "m_iClip1" then return 5
        elseif name == "m_iItemDefinitionIndex" then return w.def
        end
        T.props_unknown["weapon:" .. tostring(name)] = true
        return 0
    end

    -- cmd ------------------------------------------------------------------------------------------
    local CMD = {}
    local CMD_MT = H.objmt("cmd", CMD, H.set_of({ "has_button", "remove_button" }))
    CMD.has_button = function(c, b)
        if type(b) ~= "number" then error("has_button: gecersiz tus " .. tostring(b), 2) end
        return W.buttons[H.BTNN[b] or ""] == true
    end
    CMD.add_button = function() end
    CMD.remove_button = function(c, b)
        if type(b) ~= "number" then error("remove_button: gecersiz tus " .. tostring(b), 2) end
        local name = H.BTNN[b] or "?"
        if name ~= "JUMP" then H.G.forbidden["cmd:remove_button(" .. name .. ") (spec §3.2: sadece JUMP)"] = true end
        T.rmjump[W.tick] = (T.rmjump[W.tick] or 0) + 1
    end
    function T.newcmd()
        T.cmdno = T.cmdno + 1
        if W.raise_cmd then
            return setmetatable({}, { __index = function() error("enjekte test hatasi (cmd)") end })
        end
        return setmetatable({ command_number = T.cmdno, tick_count = W.tick, viewangles = V.ang(W.view.x, W.view.y, 0),
            move = V.v3(W.move.x, W.move.y, 0) }, CMD_MT)
    end

    -- ctx nesneleri --------------------------------------------------------------------------------------
    local AAC, HSC, TSC = {}, {}, {}
    local AAC_MT = H.objmt("antiaim_ctx", AAC, H.set_of({ "set_yaw", "set_pitch", "set_desync", "set_body_lean",
        "set_fakelag", "set_invert_desync" }))
    local HSC_MT = H.objmt("hitscan_ctx", HSC, H.set_of({ "set_min_dmg", "set_hitchance", "set_safepoint_state",
        "set_hitscan_group_state" }))
    local TSC_MT = H.objmt("target_ctx", TSC, H.set_of({ "ignore_target", "prioritize_target" }))
    local function rec(c) return rawget(c, "_r") end
    AAC.set_yaw = function(c, v) H.num_ok(v, "set_yaw"); local r = rec(c); r.yaw = v; r.n = r.n + 1 end
    AAC.set_pitch = function(c, v) H.num_ok(v, "set_pitch"); local r = rec(c); r.pitch = v; r.n = r.n + 1 end
    AAC.set_desync = function(c, v)
        H.num_ok(v, "set_desync")
        if type(v) == "number" and math.abs(v) > 1.0001 then H.G.forbidden["set_desync |v| > 1: " .. v] = true end
        local r = rec(c); r.desync = v; r.n = r.n + 1
    end
    AAC.set_body_lean = function(c, v)
        if W.raise_lean then error("enjekte test hatasi") end
        H.num_ok(v, "set_body_lean")
        local r = rec(c); r.lean = v; r.n = r.n + 1
    end
    AAC.set_fakelag = function(c, b) local r = rec(c); r.fakelag = b; r.n = r.n + 1 end
    AAC.set_invert_desync = function(c, b) local r = rec(c); r.invert = b; r.n = r.n + 1 end
    AAC.set_render_pose = function() end
    AAC.set_render_animlayer = function() end
    HSC.set_min_dmg = function(c, v)
        H.num_ok(v, "set_min_dmg")
        local r = rec(c)
        r.md = v
        r.mds[#r.mds + 1] = v
        T.md_check(r.idx, v)
    end
    HSC.set_hitchance = function(c, v) H.num_ok(v, "set_hitchance"); rec(c).hc = v end
    HSC.set_safepoint_state = function(c, b, g)
        local r = rec(c)
        if b ~= true then H.G.sp_false[#H.G.sp_false + 1] = T.name .. " tick " .. W.tick .. " (" .. tostring(b) .. ")" end
        if g ~= nil and H.HSGN[g] == nil then error("set_safepoint_state: gecersiz grup " .. tostring(g), 2) end
        r.sp[#r.sp + 1] = { b = b, g = g and H.HSGN[g] or nil }
    end
    HSC.set_hitscan_group_state = function(c, g, b)
        if H.HSGN[g] == nil then error("set_hitscan_group_state: gecersiz grup " .. tostring(g), 2) end
        rec(c).groups[H.HSGN[g]] = b
    end
    HSC.set_damage_accuracy = function() end
    TSC.ignore_target = function(c, i)
        if type(i) ~= "number" then error("ignore_target: index sayi degil (" .. type(i) .. ")", 2) end
        T.ts[#T.ts + 1] = { tick = W.tick, idx = i }
    end
    TSC.prioritize_target = function(c, i)
        if type(i) ~= "number" then error("prioritize_target: index sayi degil (" .. type(i) .. ")", 2) end
        T.prio = T.prio or {}
        T.prio[#T.prio + 1] = { tick = W.tick, idx = i }
    end

    -- U3 korumasi (T-RAGE-12): MD gercek gereksinimin altina sadece R4-R7 on kosullariyla inebilir.
    function T.md_need(idx)
        local hp = P[idx].health
        local w = P[1].weapon and P[1].weapon.name or "other"
        local grp = H.WGROUPS[(H.CFG_OF[w] or 6) + 1]
        local base = T.nat["aimbot/" .. grp .. "/targeting/min. damage"].value
        local ovr = T.nat["aimbot/" .. grp .. "/target overrides/min. damage"].value
        local md = W.keys.md_ovr and ovr or base
        return (md >= 100) and (hp + (md - 100)) or md, md, hp
    end
    function T.body_of(idx)
        if W.ldmg ~= nil then
            local lp = P[1]
            local from = V.v3(lp.origin.x, lp.origin.y, lp.origin.z + 64)
            local o = P[idx].origin
            return math.max(W.ldmg(from, idx, V.v3(o.x, o.y, o.z + 40), false) or 0, W.body_dmg[idx] or 0)
        end
        return W.body_dmg[idx] or 0
    end
    function T.md_check(idx, v)
        if type(v) ~= "number" or idx == nil or P[idx] == nil then return end
        local need, _, hp = T.md_need(idx)
        if v >= need - 1e-6 then return end
        local p, lp = P[idx], P[1]
        local mel = H.melee(p.weapon)
        local dx, dy, dz = p.origin.x - lp.origin.x, p.origin.y - lp.origin.y, p.origin.z - lp.origin.z
        local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
        local el = function(k) local e = T.el(k); return e == nil or e.value end
        local body = T.body_of(idx)
        local why = nil
        if mel and el("knife_md") and dist <= 330 and math.abs(dz) < 128 and not W.wall[idx]
            and ((mel == "knife" and math.abs(v - math.min(30, hp)) < 0.5) or (mel == "zeus" and math.abs(v - hp) < 0.5)) then
            why = "R4"
        end
        local f = T.fed
        local bodyv = math.abs(v - math.max(1, body - 1)) <= 1.01
        -- R5 / R6 (GS ext_why): yerdeki hedef, govde >= 60, govde oldurmuyor.
        local floor_ok = p.ground == true and body >= 60 and hp > body
        if why == nil and not mel and bodyv and floor_ok and el("ext_body") then
            local yaw_to_us = math.deg(math.atan2(-dy, -dx))
            local bak = H.adiff(p.eye_yaw, yaw_to_us)
            local need_m = (bak >= 45 and bak <= 135) and 2 or 3
            -- Seri (her isabet sifirlar) ya da acilmis 180 sn penceresi (sadece kafa isabeti kapatir).
            if (f.ext[idx] or 0) >= need_m or f.extw[idx] then why = "R5"; f.extw[idx] = true end
        end
        local hd = f.hider[idx]
        if why == nil and not mel and bodyv and floor_ok and el("hider_body") and hd ~= nil and hd.n >= 12
            and hd.h / hd.n <= 0.35 then
            why = "R6"
        end
        if why == nil and bodyv and el("dt_pair") == true and T.el("dt_pair") ~= nil and p.sim_shift >= 8
            and body >= 60 and body * 2 >= hp then
            why = "R7"
        end
        if why == nil then
            H.G.md_bad[#H.G.md_bad + 1] = T.name .. ": set_min_dmg(" .. H.f1(v) .. ") hedef " .. p.name .. " hp " .. hp
                .. " md_need " .. H.f1(need) .. " silah " .. tostring(p.weapon and p.weapon.name) .. " govde " .. body
        end
    end

    -- dunya izleri -------------------------------------------------------------------------------------
    local function near(a, b, r) return (a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2 <= r * r end
    local function owner_of(v, r)
        local best, bd = nil, r * r
        for i = 1, #P do
            local o = P[i].origin
            local d = (o.x - v.x) ^ 2 + (o.y - v.y) ^ 2
            if d <= bd and v.z >= o.z - 20 and v.z <= o.z + 90 then best, bd = i, d end
        end
        return best
    end
    local TR = {}
    -- T.ntr[tick]: script'in bu tick'te attigi iz sayisi (T-DIAG-6 iz sayacini dogrular).
    local function count_trace()
        T.ntr[W.tick] = (T.ntr[W.tick] or 0) + 1
        if T.in_paint then
            local r = T.pread[W.tick] or { name = 0, sid = 0, trace = 0, ent = 0 }
            T.pread[W.tick] = r
            r.trace = r.trace + 1
        end
    end
    TR.bullet = function(from, to, skip, target)
        count_trace()
        if type(from) ~= "table" or type(to) ~= "table" then error("trace.bullet: vec3 bekleniyor", 2) end
        local s = skip ~= nil and rawget(skip, "_i") or owner_of(from, 60)
        local t = target ~= nil and rawget(target, "_i") or owner_of(to, 40)
        local res = { valid = false, damage = 0, pen_count = 0, hitgroup = 0, hit_player = nil }
        if s == nil or t == nil or s == t or P[s] == nil or P[t] == nil then return res end
        -- Kati: hedef verildiyse bitis noktasi o hedefin hitbox kolonunda olmali (yatay <= 6 u, ayak..kafa+8);
        -- bos havaya autowall'in ne dondurdugu belgesiz (API §10), burada gecersiz / 0.
        if target ~= nil then
            local o = P[t].origin
            local hz = (to.x - o.x) ^ 2 + (to.y - o.y) ^ 2
            if hz > 36 or to.z < o.z - 2 or to.z > o.z + 72 then
                T.air_bullets = (T.air_bullets or 0) + 1
                return res
            end
        end
        local d = 0
        if s == 1 and P[t].enemy then
            local seen = T.tb[W.tick] or {}
            T.tb[W.tick] = seen
            seen[t] = true
            local o = P[t].origin
            local head = (to.z - o.z) >= 58
            if W.ldmg ~= nil then
                d = W.ldmg(from, t, to, head) or 0
            else
                d = head and (W.head_dmg[t] or 0) or (W.body_dmg[t] or 0)
            end
            res.hitgroup = head and 1 or 2
        elseif t == 1 and P[s].enemy then
            local fn = W.see_fn[s]
            if fn ~= nil then d = fn(to, from) or 0 else d = W.sees[s] or 0 end
            res.hitgroup = 1
        end
        res.valid = true
        res.damage = d
        if d > 0 then res.hit_player = T.ent(t) end
        return res
    end
    TR.line = function(a, b, skip, mask)
        count_trace()
        if type(a) ~= "table" or type(b) ~= "table" then error("trace.line: vec3 bekleniyor", 2) end
        local horiz = (a.x - b.x) ^ 2 + (a.y - b.y) ^ 2
        if horiz < 4 and b.z < a.z then
            -- trace_dz: izin gordugu zemin fizik zemininden yuksek (inis tahmini sapmasi, T-CHG-4).
            local fz = W.no_floor and -10000 or (W.floor_z + (W.trace_dz or 0))
            if fz <= a.z and fz >= b.z then return { fraction = (a.z - fz) / (a.z - b.z), entity = nil } end
            return { fraction = 1, entity = nil }
        end
        local oa, ob = owner_of(a, 80), owner_of(b, 80)
        if oa ~= nil and ob ~= nil and oa ~= ob and (W.wall[oa] or W.wall[ob]) and (oa == 1 or ob == 1) then
            return { fraction = 0.5, entity = nil }
        end
        -- A1: dusman gozu -> benim kafam cizgisi mock'ta mermi iziyle ayni dunyayi anlatir: dusman beni gormuyorsa
        -- (W.sees 0, see_fn yok) arada duvar var sayilir. W.open_line[i] = true: mermi izi 0 ama cizgi acik (G31).
        if oa ~= nil and ob == 1 and oa ~= 1 and P[oa] ~= nil and P[oa].enemy and skip ~= nil and rawget(skip, "_i") == oa
            and b.z - P[1].origin.z >= 58 and (b.x - P[1].origin.x) ^ 2 + (b.y - P[1].origin.y) ^ 2 <= 36
            and not (W.open_line and W.open_line[oa]) then
            local fn = W.see_fn[oa]
            local d = 0
            if fn ~= nil then d = fn(b, a) or 0 else d = W.sees[oa] or 0 end
            if d <= 0 then return { fraction = 0.5, entity = nil } end
        end
        if W.block_line ~= nil then
            local f = W.block_line(a, b)
            if f ~= nil then return { fraction = f, entity = nil } end
        end
        local e = nil
        local ob2 = owner_of(b, 30)
        if ob2 ~= nil and (skip == nil or rawget(skip, "_i") ~= ob2) then e = T.ent(ob2) end
        return { fraction = 1, entity = e }
    end
    TR.hull = function() return { fraction = 1 } end

    -- menu ---------------------------------------------------------------------------------------------
    local EL = {}
    local EL_OK = H.set_of({ "get", "set", "set_visible", "add_color_picker", "get_items" })
    local EL_MT = H.objmt("menu_element", EL, EL_OK)
    local function new_el(kind, g, name, extra)
        if type(g) ~= "string" or type(name) ~= "string" then error("menu.add_*: grup / ad metin olmali", 3) end
        local grp = T.groups[g]
        if grp == nil then
            grp = { order = #T.el_list + 1, byname = {} }
            T.groups[g] = grp
            T.group_order = T.group_order or {}
            T.group_order[#T.group_order + 1] = g
        end
        if grp.byname[name] then error("ayni grupta ayni ad iki kez: " .. g .. " / " .. name, 3) end
        if name:find("#", 1, true) or name:find("[\128-\255]") then T.badnames[#T.badnames + 1] = name end
        local e = setmetatable({ kind = kind, group = g, name = name, visible = true }, EL_MT)
        for k, v in pairs(extra or {}) do e[k] = v end
        grp.byname[name] = e
        T.els[g .. "\0" .. name] = e
        T.el_list[#T.el_list + 1] = e
        return e
    end
    EL.get = function(e, i)
        if e.kind == "multi" then
            if i == nil then return e.value end
            if type(i) == "string" then
                for k, n in ipairs(e.items) do if n == i then return e.value[k] == true end end
                return false
            end
            return e.value[i] == true
        end
        if e.kind == "txt" or e.kind == "btn" then return nil end
        return e.value
    end
    EL.set = function(e, v, b)
        local k = e.kind
        if k == "cb" then
            if type(v) ~= "boolean" then T.el_set_bad[#T.el_set_bad + 1] = e.name .. " <- " .. tostring(v) end
            e.value = v == true
        elseif k == "sl" then
            if type(v) ~= "number" then error("slider:set sayi olmali", 2) end
            if v < e.min then v = e.min end
            if v > e.max then v = e.max end
            e.value = v
        elseif k == "sel" then
            if type(v) ~= "number" or v < 1 or v > #e.items or v ~= math.floor(v) then
                T.sel_range[#T.sel_range + 1] = e.name .. " <- " .. tostring(v)
                return
            end
            e.value = v
        elseif k == "multi" then
            if type(v) == "string" then
                for n, it in ipairs(e.items) do if it == v then e.value[n] = b == true end end
            else
                e.value[v] = b == true
            end
        elseif k == "col" then
            e.value = v
        elseif k == "txt" then
            e.label = v
        end
    end
    EL.set_visible = function(e, b) e.visible = b == true end
    EL.get_items = function(e)
        local c = {}
        for i, n in ipairs(rawget(e, "items") or {}) do c[i] = n end
        return c
    end
    EL.set_items = function(e, t) e.items = t end
    EL.get_item_name = function(e, i) return (rawget(e, "items") or {})[i] end
    EL.get_name = function(e) return e.name end
    EL.add_color_picker = function(e, name, col)
        local c = setmetatable({ kind = "col", group = e.group, name = name, host = e, visible = true,
            value = col or V.col(255, 255, 255, 255) }, EL_MT)
        local pk = rawget(e, "pickers") or {}
        rawset(e, "pickers", pk)
        pk[name] = c
        T.els[e.group .. "\0" .. e.name .. "\0" .. name] = c
        return c
    end
    EL.add_keybind = function(e, name)
        return setmetatable({ kind = "key", group = e.group, name = name, visible = true, value = false }, EL_MT)
    end
    local MENU = {}
    MENU.add_checkbox = function(g, n, d) return new_el("cb", g, n, { value = d == true }) end
    MENU.add_slider = function(g, n, mn, mx, step, prec, suffix)
        if type(mn) ~= "number" or type(mx) ~= "number" then error("add_slider: min / max sayi olmali", 2) end
        return new_el("sl", g, n, { value = mn, min = mn, max = mx, step = step, prec = prec, suffix = suffix })
    end
    MENU.add_selection = function(g, n, items)
        if type(items) ~= "table" then error("add_selection: oge listesi yok", 2) end
        local c = {}
        for i, it in ipairs(items) do c[i] = it end
        return new_el("sel", g, n, { value = 1, items = c })
    end
    MENU.add_multi_selection = function(g, n, items)
        H.G.forbidden["menu.add_multi_selection (spec §3.2: kullanilmaz)"] = true
        local v = {}
        for i = 1, #items do v[i] = false end
        return new_el("multi", g, n, { value = v, items = items })
    end
    MENU.add_text = function(g, text) return new_el("txt", g, text, {}) end
    MENU.add_button = function(g, n, fn)
        if type(fn) ~= "function" then error("add_button: fonksiyon yok", 2) end
        return new_el("btn", g, n, { fn = fn })
    end
    MENU.add_separator = function(g) return new_el("txt", g, "sep" .. #T.el_list, {}) end
    MENU.add_list = function(g, n, items) return new_el("sel", g, n, { value = 1, items = items or {} }) end
    MENU.add_text_input = function(g, n) return new_el("txt", g, n, {}) end
    MENU.set_group_column = function(g, c) T.group_col[g] = c end
    MENU.set_group_visibility = function(g, b) T.group_vis[g] = b end
    MENU.is_open = function() return W.menu_open == true end
    MENU.get_pos = function() return V.v2(100, 100) end
    MENU.get_size = function() return V.v2(600, 400) end

    -- native referanslar ----------------------------------------------------------------------------------
    local NAT, KEY = {}, {}
    local NAT_MT = H.objmt("native_ref", NAT, H.set_of({ "get", "set", "get_items" }))
    local KEY_MT = H.objmt("keybind", KEY, H.set_of({ "get", "get_key", "get_mode" }))
    local function nat_write(d, what)
        T.natw[#T.natw + 1] = { path = d.path, ov = d.ov, v = what, tick = W.tick, harness = T.hw == true }
        if not T.hw and d.ov == nil then
            H.G.native_bad[#H.G.native_bad + 1] = T.name .. ": " .. d.path .. " <- " .. tostring(what)
        end
    end
    NAT.get = function(r, i)
        local d = rawget(r, "_d")
        if d.t == "multi" then
            if i == nil then return d.value end
            if type(i) == "string" then
                for k, n in ipairs(d.items) do if n == i then return d.value[k] == true end end
                return false
            end
            return d.value[i] == true
        end
        if d.t == "text" then return nil end
        return d.value
    end
    NAT.set = function(r, v, b)
        local d = rawget(r, "_d")
        nat_write(d, d.t == "multi" and (tostring(v) .. "=" .. tostring(b)) or v)
        if W.stuck[d.path] and not T.hw then return end
        if d.t == "multi" then
            local idx = v
            if type(v) == "string" then
                idx = nil
                for k, n in ipairs(d.items) do if n == v then idx = k end end
            end
            if idx ~= nil and d.items[idx] ~= nil then
                local c = {}
                for k, x in ipairs(d.value) do c[k] = x end
                c[idx] = b == true
                d.value = c
            end
        elseif d.t == "sel" then
            if type(v) ~= "number" or v < 1 or v > #d.items or v ~= math.floor(v) then
                T.sel_range[#T.sel_range + 1] = d.path .. " <- " .. tostring(v)
                return
            end
            d.value = v
        elseif d.t == "sl" then
            if type(v) == "number" then d.value = math.max(d.min or -1e9, math.min(d.max or 1e9, v)) end
        elseif d.t == "cb" then
            d.value = v == true
        end
    end
    NAT.get_items = function(r)
        local c = {}
        for i, n in ipairs(rawget(r, "_d").items or {}) do c[i] = n end
        return c
    end
    NAT.set_visible = function(r, b)
        if not T.hw then H.G.native_bad[#H.G.native_bad + 1] = T.name .. ": set_visible " .. rawget(r, "_d").path end
    end
    NAT.get_name = function(r) return rawget(r, "_d").path end
    KEY.get = function(k)
        local kk = rawget(k, "_k")
        local r = W.key_raise ~= nil and W.key_raise[kk] or nil
        if r ~= nil and r > 0 then
            W.key_raise[kk] = r - 1
            error("enjekte test hatasi (keybind)")
        end
        return W.keys[kk] == true
    end
    KEY.get_key = function(k) return 5 end
    KEY.get_mode = function(k) return W.dt_mode or 1 end
    KEY.set = function(k, v)
        H.G.native_bad[#H.G.native_bad + 1] = T.name .. ": keybind :set " .. rawget(k, "_k") .. " <- " .. tostring(v)
    end
    KEY.set_visible = function(k)
        H.G.native_bad[#H.G.native_bad + 1] = T.name .. ": keybind set_visible " .. rawget(k, "_k")
    end
    local PH_MT = { __index = function(_, k)
        if type(k) == "number" then return nil end
        return function() error("placeholder: " .. tostring(k)) end
    end }
    T.missing_paths = {}
    do
        local paths = {}
        for _, d in ipairs(T.nat_list) do paths[#paths + 1] = d.path end
        table.sort(paths)
        for i, p in ipairs(paths) do T.missing_paths[p] = (i % 2 == 1) and "nil" or "ph" end
    end
    MENU.find = function(...)
        local n = select("#", ...)
        local parts = {}
        for i = 1, n do
            local a = select(i, ...)
            if type(a) ~= "string" then
                H.G.offlist["menu.find: metin olmayan arguman (" .. tostring(a) .. ")"] = true
            else
                parts[#parts + 1] = a:lower()
            end
        end
        local path = table.concat(parts, "/")
        local d = T.nat[path]
        if d == nil then
            T.find_unknown[path] = true
            return nil
        end
        if T.mode == "missing" then
            if T.missing_paths[path] == "nil" then return nil end
            return setmetatable({}, PH_MT)
        end
        local c = T.refcache[path]
        if c ~= nil then return c end
        local r = setmetatable({ _d = d }, NAT_MT)
        if d.key then
            c = { r, setmetatable({ _k = d.key }, KEY_MT) }
        else
            c = r
        end
        T.refcache[path] = c
        return c
    end

    -- callbacks -------------------------------------------------------------------------------------------
    local CBS = {}
    CBS.add = function(id, fn, filter)
        if type(fn) ~= "function" then error("callbacks.add: fonksiyon yok", 2) end
        if H.CBN[id] == nil then error("callbacks.add: gecersiz callback " .. tostring(id), 2) end
        if T.in_cb > 0 then H.G.forbidden["callback icinde callbacks.add (" .. H.CBN[id] .. ")"] = true end
        local nm = H.CBN[id]
        if nm == "DRAW_WATERMARK" then H.G.forbidden["DRAW_WATERMARK kaydi (spec §3.3)"] = true end
        if not H.CB_ALLOWED[nm] then H.G.offlist["callback " .. nm] = true end
        T.cbs[id] = T.cbs[id] or {}
        local l = T.cbs[id]
        l[#l + 1] = { fn = fn, filter = filter }
    end

    -- engine / global_vars / client / antiaim / exploits / ragebot ---------------------------------------
    local ENG = {}
    ENG.get_choked_commands = function()
        if W.raise_choked then error("enjekte test hatasi") end
        return W.choked
    end
    ENG.get_latency = function() return W.latency or 0.05 end
    ENG.is_in_game = function() return not W.no_local end
    ENG.is_connected = function() return not W.no_local end
    ENG.execute_cmd = function(s) T.cmds[#T.cmds + 1] = { tick = W.tick, s = tostring(s) } end
    ENG.get_view_angles = function() return V.ang(W.view.x, W.view.y, 0) end
    ENG.get_level_name_short = function() return W.map end
    ENG.get_level_name = function() return "maps/" .. W.map end
    ENG.get_local_player_index = function() return 1 end
    ENG.get_player_index_from_user_id = function(u) return (tonumber(u) or 0) - 100 end
    ENG.set_view_angles = function() end
    ENG.play_sound = function() end
    local GV = {}
    GV.tick_count = function() return W.tick end
    GV.cur_time = function() return W.tick * W.interval end
    GV.real_time = function() return T.rt() end
    GV.interval_per_tick = function() return W.interval end
    GV.frame_time = function() return W.interval end
    GV.absolute_frame_time = function() return W.interval end
    GV.max_clients = function() return 64 end
    local CL = {}
    CL.log = function(...)
        local parts = {}
        for i = 1, select("#", ...) do
            local a = select(i, ...)
            if type(a) == "string" or type(a) == "number" then parts[#parts + 1] = tostring(a) end
        end
        T.say(table.concat(parts, ""))
    end
    CL.log_screen = function(...)
        H.G.forbidden["client.log_screen (spec M4: asla)"] = true
        CL.log(...)
    end
    CL.set_clantag = function(s)
        W.clantag = s
        T.clantags[#T.clantags + 1] = s
    end
    CL.get_local_time = function()
        local s = math.floor(T.rt())
        return 10 + math.floor(s / 3600) % 14, math.floor(s / 60) % 60, s % 60
    end
    CL.time_to_ticks = function(t) return math.floor(t / W.interval + 0.5) end
    CL.ticks_to_time = function(n) return n * W.interval end
    CL.can_fire = function() return W.can_fire == true end
    CL.delay_call = function(fn, s)
        if type(fn) ~= "function" then error("delay_call: fonksiyon yok", 2) end
        T.delays[#T.delays + 1] = { due = T.rt() + (tonumber(s) or 0), fn = fn }
    end
    CL.random_int = function(a, b) return a end
    CL.random_float = function(a, b) return a end
    CL.get_hitgroup_name = function(i) return tostring(i) end
    CL.get_unix_time = function() return 1700000000 + math.floor(T.rt()) end
    local AA = {}
    AA.get_manual_override = function() return W.manual end
    AA.is_fakeducking = function() return W.keys.fd == true end
    local function dsy_get(which)
        if T.mode == "nofeature" or W.getters_nil then return nil end
        local h = T.dsy
        local k = #h - W.getter_lag
        if k < 1 then return W.view.y end
        return h[k][which]
    end
    AA.get_real_angle = function() return dsy_get("real") end
    AA.get_fake_angle = function() return dsy_get("fake") end
    AA.is_inverting_desync = function() return W.keys.inverter == true end
    AA.get_desync_side = function() return 1 end
    AA.get_max_desync_range = function() return 58 end
    AA.get_body_lean = function() return 0 end
    local EX = {}
    T.EX = EX
    EX.get_charge = function() return W.charge end
    EX.get_max_charge = function() return (W.keys.dt or W.keys.hs) and W.max_charge or 0 end
    EX.force_uncharge = function()
        T.unch[#T.unch + 1] = W.tick
        if W.uncharge_partial then W.charge = math.max(0, W.charge - W.uncharge_partial) else W.charge = 0 end
    end
    EX.block_recharge = function()
        W.rc_blocked = true
        T.blk[W.tick] = (T.blk[W.tick] or 0) + 1
    end
    EX.allow_recharge = function()
        W.rc_blocked = false
        T.alw[W.tick] = (T.alw[W.tick] or 0) + 1
    end
    EX.force_recharge = function() H.G.forbidden["exploits.force_recharge (spec §3.5: asla)"] = true end
    if mode ~= "nofeature" then
        EX.force_anti_exploit_shift = function() T.shift[W.tick] = (T.shift[W.tick] or 0) + 1 end
    end
    local RB = {}
    RB.get_active_cfg = function()
        local w = P[1].weapon
        return w and (H.CFG_OF[w.name] or 6) or 6
    end
    RB.get_autopeek_pos = function()
        local a = W.autopeek_pos
        if a == nil or not W.keys.autopeek then return nil end
        return V.v3(a.x, a.y, a.z)
    end

    -- render ------------------------------------------------------------------------------------------------
    local RN = {}
    local function in_paint(what)
        if not T.in_paint then H.G.forbidden["render." .. what .. " PAINT disinda"] = true end
    end
    RN.create_font = function(name, size, weight, ...)
        T.fonts = T.fonts + 1
        return { font = name, size = size, id = T.fonts }
    end
    RN.text = function(font, s, pos, col, cx, cy)
        in_paint("text")
        if type(pos) ~= "table" then error("render.text: konum vec2 olmali", 2) end
        T.frame[#T.frame + 1] = { s = tostring(s), x = pos.x, y = pos.y, cx = cx,
            fs = type(font) == "table" and font.size or nil, col = col }
    end
    RN.get_text_size = function(font, s) return V.v2(#tostring(s) * 7, 12) end
    -- W.screen_h: ekran yuksekligi (T-STAT-9, DPI'li stats paneli yazisi).
    RN.get_screen_size = function() return V.v2(W.screen_w or 1920, W.screen_h or 1080) end
    RN.rect_filled = function() in_paint("rect_filled") end
    RN.rect_fade = function() in_paint("rect_fade") end
    RN.triangle_filled = function(pos)
        in_paint("triangle_filled")
        T.frame[#T.frame + 1] = { s = "<tri>", x = pos and pos.x or 0, y = pos and pos.y or 0 }
    end
    RN.rect = function() in_paint("rect") end
    RN.line = function() in_paint("line") end
    RN.circle = function() in_paint("circle") end
    RN.circle_filled = function() in_paint("circle_filled") end
    RN.get_default_font = function() return { font = "default" } end
    RN.world_to_screen = function() H.G.forbidden["render.world_to_screen (spec §3.2)"] = true; return nil end
    RN.push_clip = function() end
    RN.pop_clip = function() end

    -- cvars -------------------------------------------------------------------------------------------------
    local CVO = {}
    local CVO_MT = H.objmt("cvar", CVO, H.set_of({ "get_int", "set_int", "get_float", "set_float" }))
    local function cv_get(o)
        local n = rawget(o, "_n")
        if W.cvar_unreadable[n] then error("cvar okunamadi: " .. n) end
        local v = W.cv[n]
        if v == nil then v = 0 end
        return v
    end
    local function cv_set(o, v)
        local n = rawget(o, "_n")
        T.cvw[#T.cvw + 1] = { n = n, v = v, tick = W.tick }
        if type(v) == "number" then W.cv[n] = v end
    end
    CVO.get_int = function(o) return math.floor(cv_get(o)) end
    CVO.get_float = function(o) return cv_get(o) end
    CVO.get_string = function(o) return tostring(cv_get(o)) end
    CVO.set_int = cv_set
    CVO.set_float = cv_set
    CVO.set_string = function(o, s) cv_set(o, tonumber(s)) end
    T.cvobj = {}
    local CVARS = setmetatable({}, { __index = function(_, k)
        if type(k) ~= "string" then return nil end
        local o = T.cvobj[k]
        if o == nil then
            o = setmetatable({ _n = k }, CVO_MT)
            T.cvobj[k] = o
        end
        return o
    end, __newindex = function(_, k) H.G.forbidden["cvars tablosuna yazma " .. tostring(k)] = true end })

    local GR = {}
    GR.get_prop = function(n)
        if n == "m_bFreezePeriod" then return W.freeze and 1 or 0 end
        if n == "m_bWarmupPeriod" then return W.warmup and 1 or 0 end
        if n == "m_gamePhase" then return 2 end
        if n == "m_totalRoundsPlayed" then return W.rounds or 3 end
        return 0
    end

    -- sahte ffi + memory (VBaseFileSystem011, VGUI_System010) ----------------------------------------------------
    local FFI, MEM = {}, {}
    local function slot_fn(slot)
        local iface, i = slot.iface, slot.i
        local fs = T.fs
        if iface == "VBaseFileSystem011" then
            if i == 0 then
                return function(this, buf, size, h)
                    local f = type(h) == "table" and fs.h[h.fh]
                    if not f then return 0 end
                    local data = (W.files[f.name] or ""):sub(1, size)
                    if type(buf) == "table" then buf.data = data end
                    return #data
                end
            elseif i == 1 then
                return function(this, text, len, h)
                    local f = type(h) == "table" and fs.h[h.fh]
                    if not f or f.closed then return 0 end
                    local s = type(text) == "table" and (text.data or "") or tostring(text)
                    s = s:sub(1, len)
                    W.files[f.name] = (W.files[f.name] or "") .. s
                    fs.written = fs.written + #s
                    return #s
                end
            elseif i == 2 then
                return function(this, name, mode_, pathid)
                    fs.pathids[tostring(pathid)] = true
                    if W.fs_fail then return nil end
                    name = tostring(name)
                    if mode_ == "w" or mode_ == "wb" or mode_ == "w+" then W.files[name] = ""
                    elseif mode_ == "a" or mode_ == "ab" or mode_ == "a+" then W.files[name] = W.files[name] or ""
                    elseif W.files[name] == nil then return nil end
                    fs.n = fs.n + 1
                    fs.h[fs.n] = { name = name, mode = mode_ }
                    return { fh = fs.n }
                end
            elseif i == 3 then
                return function(this, h)
                    local f = type(h) == "table" and fs.h[h.fh]
                    if f then f.closed = true end
                end
            elseif i == 7 then
                return function(this, h)
                    local f = type(h) == "table" and fs.h[h.fh]
                    if not f then return 0 end
                    return #(W.files[f.name] or "")
                end
            elseif i == 10 then
                return function(this, name) return W.files[tostring(name)] ~= nil end
            end
        elseif iface == "VGUI_System010" then
            if i == 9 then
                return function(this, text, len)
                    local s = type(text) == "table" and (text.data or "") or tostring(text)
                    W.clipboard = s:sub(1, len or #s)
                end
            elseif i == 7 then
                return function() return W.clipboard and (#W.clipboard + 1) or 0 end
            elseif i == 11 then
                return function(this, n, buf, len)
                    if type(buf) == "table" then buf.data = W.clipboard or "" end
                    return len
                end
            end
        end
        return function() return 0 end
    end
    local function mkbuf(n) return { data = "", n = tonumber(n) or 0, _buf = true } end
    local function vtable(tok)
        return { [0] = setmetatable({}, { __index = function(_, i) return { iface = tok.iface, i = i, _slot = true } end }) }
    end
    FFI.cast = function(sig, x)
        if type(sig) == "table" then sig = sig.ctype end
        if type(x) == "table" and x._iface then return vtable(x) end
        if type(x) == "table" and x._slot then return slot_fn(x) end
        return x
    end
    FFI.typeof = function(sig)
        return setmetatable({ ctype = sig }, { __call = function(_, n) return mkbuf(n) end })
    end
    FFI.new = function(sig, n) return mkbuf(n) end
    FFI.string = function(buf, n)
        local s = type(buf) == "table" and (buf.data or "") or tostring(buf or "")
        if n ~= nil then s = s:sub(1, n) end
        return s
    end
    FFI.cdef = function() end
    FFI.sizeof = function() return 4 end
    MEM.create_interface = function(dll, name)
        if name == "VBaseFileSystem011" or name == "VGUI_System010" or name == "VFileSystem017"
            or name == "VEngineClient014" then
            return { _iface = true, iface = name, dll = dll }
        end
        return nil
    end
    MEM.get_vfunc = function(iface, i)
        if type(iface) ~= "table" then return nil end
        return { iface = iface.iface, i = i, _slot = true }
    end
    MEM.find_pattern = function() return nil end

    -- ortam --------------------------------------------------------------------------------------------------
    local A = {
        callbacks = H.ns("callbacks", CBS, H.set_of({ "add" })),
        menu = H.ns("menu", MENU, H.set_of({ "add_checkbox", "add_slider", "add_selection", "add_text", "add_button",
            "find", "set_group_column", "set_group_visibility", "is_open" })),
        entity_list = H.ns("entity_list", {
            get_local_player = function() if W.no_local then return nil end return T.ent(1) end,
            get_players = function(enemies_only)
                local r = {}
                for i = 1, #P do if not enemies_only or P[i].enemy then r[#r + 1] = T.ent(i) end end
                return r
            end,
            get_player_from_userid = function(u)
                local i = (tonumber(u) or 0) - 100
                if P[i] then return T.ent(i) end
                return nil
            end,
            get_entities_by_name = function(n) return W.ents_by_name[n] or {} end,
            get_entity = function(i) if P[i] then return T.ent(i) end return nil end,
            get_local_player_or_spectating = function() return T.ent(1) end,
        }, H.set_of({ "get_local_player", "get_players", "get_player_from_userid", "get_entities_by_name" })),
        engine = H.ns("engine", ENG, H.set_of({ "get_choked_commands", "get_latency", "is_in_game", "is_connected",
            "execute_cmd", "get_view_angles", "get_level_name_short" })),
        global_vars = H.ns("global_vars", GV, H.set_of({ "tick_count", "cur_time", "real_time", "interval_per_tick",
            "frame_time" })),
        client = H.ns("client", CL, H.set_of({ "log", "set_clantag", "get_local_time", "time_to_ticks", "can_fire",
            "delay_call" })),
        antiaim = H.ns("antiaim", AA, H.set_of({ "get_manual_override", "is_fakeducking", "get_real_angle",
            "get_fake_angle" })),
        exploits = H.ns("exploits", EX, H.set_of({ "get_charge", "get_max_charge", "force_uncharge", "block_recharge",
            "allow_recharge", "force_anti_exploit_shift" })),
        ragebot = H.ns("ragebot", RB, H.set_of({ "get_active_cfg", "get_autopeek_pos" })),
        trace = H.ns("trace", TR, H.set_of({ "line", "bullet" })),
        render = H.ns("render", RN, H.set_of({ "create_font", "text", "get_text_size", "get_screen_size",
            "rect_filled", "rect_fade", "triangle_filled" })),
        cvars = CVARS,
        game_rules = H.ns("game_rules", GR, H.set_of({ "get_prop" })),
        user = H.ns("user", { name = "tester", uid = 1 }, H.set_of({ "name" })),
        input = H.ns("input", { is_key_held = function() return false end, is_key_pressed = function() return false end,
            get_mouse_pos = function() return V.v2(0, 0) end }, {}),
        debug_overlay = H.ns("debug_overlay", {}, {}),
        materials = H.ns("materials", {}, {}),
        -- missing modunda hic yok (ping yazilmaz, hata yok); index ile oyuncunun ping'i.
        player_resource = mode ~= "missing" and H.ns("player_resource", { get_prop = function(n, i)
            if type(n) ~= "string" then error("player_resource.get_prop: ad metin olmali", 2) end
            local p = P[tonumber(i) or -1]
            if n == "m_iPing" and p ~= nil then return p.ping or 0 end
            return 0
        end }, H.set_of({ "get_prop" })) or nil,
        vec2_t = H.vec2_t, vec3_t = H.vec3_t, angle_t = H.angle_t, color_t = H.color_t,
    }
    for k, v in pairs(H.ENUMS) do A[k] = v end
    if mode ~= "noffi" then
        A.ffi = H.ns("ffi", FFI, H.set_of({ "cast", "typeof", "new", "string" }))
        A.memory = H.ns("memory", MEM, H.set_of({ "create_interface", "get_vfunc" }))
    end
    local seed = 12345
    local tmath = setmetatable({}, { __index = math })
    tmath.random = function(a, b)
        seed = (seed * 1103515245 + 12345) % 2147483648
        local r = seed / 2147483648
        if a == nil then return r elseif b == nil then return 1 + math.floor(r * a) end
        return a + math.floor(r * (b - a + 1))
    end
    tmath.randomseed = function() end
    local base = {
        print = function(...)
            local parts = {}
            for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
            T.say(table.concat(parts, " "))
        end,
        math = tmath, string = H.sproxy, table = table, pairs = pairs, ipairs = ipairs, type = type,
        tostring = tostring, tonumber = tonumber, select = select, setmetatable = setmetatable,
        getmetatable = getmetatable, pcall = pcall, xpcall = xpcall, error = error, unpack = unpack, next = next,
        rawget = rawget, rawset = rawset, rawequal = rawequal, assert = assert, coroutine = coroutine,
        collectgarbage = function() return 0 end, bit = bit, _VERSION = "Lua 5.1",
        os = { clock = function() return T.rt() end, time = function() return 1700000000 + math.floor(T.rt()) end,
            date = function() return "01/01/24 10:00:00" end },
    }
    for k, v in pairs(A) do base[k] = v end
    local OPTIONAL = { ffi = true, memory = true, require = true, print = true, player_resource = mode == "missing" }
    local env = setmetatable({}, {
        __index = function(_, k)
            local w = T.wrote[k]
            if w ~= nil then return w end
            local v = base[k]
            if v == nil and not OPTIONAL[k] then H.G.unknown_global[tostring(k)] = true end
            return v
        end,
        __newindex = function(_, k, v)
            H.G.global_write[tostring(k)] = true
            T.wrote[k] = v
        end,
    })
    base._G = env
    T.env = env

    -- harness yardimcilari ----------------------------------------------------------------------------------------
    function T.el(key)
        local r = H.EL_BY[key]
        if r == nil then error("harness: bilinmeyen eleman anahtari " .. tostring(key)) end
        local g = H.GROUPS[r[2]][1]
        if r[4] == "col" then
            local hr = H.EL_BY[r[6]]
            return T.els[g .. "\0" .. hr[3] .. "\0" .. r[3]]
        end
        return T.els[g .. "\0" .. r[3]]
    end
    function T.need_el(key)
        local e = T.el(key)
        if e == nil then error("menu ogesi yok: " .. tostring(key)) end
        return e
    end
    function T.set(key, v) T.need_el(key):set(v) end
    function T.get(key) return T.need_el(key).value end
    function T.bset(state, suffix, v) T.set("b:" .. state .. ":" .. suffix, v) end
    function T.xset(state, suffix, v) T.set("x:" .. state .. ":" .. suffix, v) end
    function T.press(key)
        local e = T.need_el(key)
        T.call(e.fn)
    end
    function T.natv(path) return T.nat[path].value end
    function T.hset(path, v)
        local d = T.nat[path]
        d.value = v
        T.natw[#T.natw + 1] = { path = path, v = v, tick = W.tick, harness = true }
    end
    function T.script_writes(path, from)
        local n = 0
        for _, w in ipairs(T.natw) do
            if w.path == path and not w.harness and w.tick >= (from or 0) then n = n + 1 end
        end
        return n
    end
    function T.printed(pat, since)
        for i = since or 1, #T.prints do
            if T.prints[i]:find(pat, 1, true) then return T.prints[i], i end
        end
        return nil
    end
    function T.count(pat, since)
        local n = 0
        for i = since or 1, #T.prints do if T.prints[i]:find(pat, 1, true) then n = n + 1 end end
        return n
    end
    function T.mark() return #T.prints + 1 end
    function T.recs(t0, t1)
        local r = {}
        for _, e in ipairs(T.aa) do if e.tick >= t0 and e.tick <= t1 then r[#r + 1] = e end end
        return r
    end
    function T.hsr(idx, t0, t1)
        local r = {}
        for _, e in ipairs(T.hs) do if e.idx == idx and e.tick >= t0 and e.tick <= (t1 or 1e12) then r[#r + 1] = e end end
        return r
    end
    function T.ignored(idx, t0, t1)
        local n = 0
        for _, e in ipairs(T.ts) do if e.idx == idx and e.tick >= t0 and e.tick <= (t1 or 1e12) then n = n + 1 end end
        return n
    end
    function T.shifts(t0, t1)
        local n, ticks = 0, 0
        for t, c in pairs(T.shift) do
            if t >= t0 and t <= t1 then n = n + c; ticks = ticks + 1 end
        end
        return ticks, n
    end
    function T.unch_between(t0, t1)
        local n = 0
        for _, t in ipairs(T.unch) do if t >= t0 and t <= t1 then n = n + 1 end end
        return n
    end
    function T.calls_in(tbl, t0, t1)
        local n = 0
        for t, c in pairs(tbl) do if t >= t0 and t <= t1 then n = n + c end end
        return n
    end
    function T.texts(t0, t1, pred)
        local r = {}
        for t = t0, t1 do
            for _, x in ipairs(T.ftexts[t] or {}) do if pred == nil or pred(x) then r[#r + 1] = x end end
        end
        return r
    end
    function T.has_text(t0, t1, s, pred)
        for _, x in ipairs(T.texts(t0, t1, pred)) do
            if x.s:lower():find(s:lower(), 1, true) then return true end
        end
        return false
    end
    function T.file(name) return W.files[name or "nykle_log.txt"] end

    -- olaylar / atislar -----------------------------------------------------------------------------------------------
    function T.event(name, fields)
        local ev = { name = name }
        for k, v in pairs(fields or {}) do ev[k] = v end
        local list = T.cbs[H.CB.EVENT] or {}
        for _, h in ipairs(list) do
            -- ignore_filter: oyun 3. argumani yok sayiyormus gibi her olay her islemciye (G24, T-DIAG-1).
            if h.filter == nil or h.filter == name or W.ignore_filter then T.call(h.fn, ev) end
        end
    end
    function T.uid(i) return 100 + i end
    function T.hurt_me(att, hg, dmg, weapon)
        T.event("player_hurt", { userid = 101, attacker = T.uid(att), weapon = weapon or "ssg08", hitgroup = hg or 1,
            dmg_health = dmg or 50, health = math.max(1, P[1].health - (dmg or 50)), dmg_armor = 0, armor = 100 })
    end
    -- Bize ates: dusmanin gozunden, kafamizdan 'off' birim yana gecen bir merminin isabet noktasi.
    function T.impact(att, off)
        local o = P[att].origin
        local lp = P[1].origin
        local ex, ey = o.x, o.y
        local dx, dy = lp.x - ex, lp.y - ey
        local len = math.sqrt(dx * dx + dy * dy)
        local ux, uy = dx / len, dy / len
        local px, py = -uy, ux
        local hx, hy = lp.x + px * off, lp.y + py * off
        T.event("bullet_impact", { userid = T.uid(att), x = hx + ux * 100, y = hy + uy * 100, z = lp.z + 64 })
    end
    function T.shoot(idx, o)
        o = o or {}
        T.shot_id = T.shot_id + 1
        local id = T.shot_id
        local tgt = P[idx]
        local w = P[1].weapon and P[1].weapon.name
        T.fed.shots[id] = { idx = idx, hg = o.hg or 1, hc = o.hc or 80, sniper = (w == "ssg08" or w == "awp") }
        T.fire("AIMBOT_SHOOT", { id = id, player = T.ent(idx), hitchance = o.hc or 80, damage = o.dmg or 100,
            backtrack_ticks = o.bt or 0, hitgroup = o.hg or 1, safepoint = false,
            hitpoint_pos = V.v3(tgt.origin.x, tgt.origin.y, tgt.origin.z + 64) })
        P[1].last_shot = T.now()
        if not o.no_event then
            T.event("weapon_fire", { userid = 101, weapon = P[1].weapon and P[1].weapon.console or "weapon_ssg08", silenced = false })
        end
        return id
    end
    local function feed(id, kind, hg, reason)
        local s = T.fed.shots[id]
        if s == nil then return end
        local idx = s.idx
        if s.hg == 1 and s.hc >= 70 then
            if kind == "miss" and (reason == "resolver" or reason == "jitter") then
                T.fed.ext[idx] = (T.fed.ext[idx] or 0) + 1
            end
        end
        if kind == "hit" then
            T.fed.ext[idx] = 0
            if hg == 1 then T.fed.extw[idx] = nil end
        end
        if s.hg == 1 and s.hc >= 70 then
            if s.sniper and (kind == "hit" or reason == "resolver" or reason == "jitter") then
                local h = T.fed.hider[idx] or { n = 0, h = 0 }
                h.n = h.n + 1
                if kind == "hit" and hg == 1 then h.h = h.h + 1 end
                T.fed.hider[idx] = h
            end
        end
    end
    function T.hit(id, o)
        o = o or {}
        local s = T.fed.shots[id] or { idx = 2, hg = 1 }
        feed(id, "hit", o.hg or 1)
        T.fire("AIMBOT_HIT", { id = id, player = T.ent(s.idx), damage = o.dmg or 100, hitgroup = o.hg or 1,
            backtrack_ticks = o.bt or 0, safepoint = false, aim_damage = o.dmg or 100, aim_hitgroup = s.hg,
            aim_hitchance = s.hc, aim_safepoint = false })
        if not o.no_event then
            T.event("player_hurt", { userid = T.uid(s.idx), attacker = 101, weapon = P[1].weapon and P[1].weapon.name or "ssg08",
                hitgroup = o.hg or 1, dmg_health = o.dmg or 100, health = math.max(0, P[s.idx].health - (o.dmg or 100)),
                dmg_armor = 0, armor = 100 })
        end
    end
    function T.miss(id, reason, o)
        o = o or {}
        local s = T.fed.shots[id] or { idx = 2, hg = 1, hc = 80 }
        feed(id, "miss", nil, reason)
        T.fire("AIMBOT_MISS", { id = id, player = (not o.noplayer) and T.ent(s.idx) or nil, reason_string = reason,
            aim_hitgroup = s.hg, aim_damage = 100, aim_hitchance = s.hc, aim_safepoint = false, aim_hitbox = 0,
            backtrack_ticks = 0 })
    end
    function T.jump(vz)
        local p = P[1]
        p.ground = false
        p.air_phys = true
        p.vel = V.v3(p.vel.x, p.vel.y, vz or 300)
    end
    function T.shutdown()
        if T.shut then return end
        T.shut = true
        T.fire("SHUTDOWN")
    end
    -- Durum yoklamasi: vuruldun satirindaki <state> alani (§6.3).
    function T.probe_state()
        local m = T.mark()
        T.hurt_me(2, 2, 1, "ak47")
        local line = T.printed("vuruldun:", m)
        if line == nil then return nil end
        local st = line:match("vuruldun:[^|]*|%s*([^|]-)%s*|")
        return st
    end

    -- tick dongusu ----------------------------------------------------------------------------------------------------
    function T.tick(n, hook)
        for _ = 1, n or 1 do
            W.tick = W.tick + 1
            local lp = P[1]
            if lp.air_phys then
                lp.vel = V.v3(lp.vel.x, lp.vel.y, lp.vel.z - W.gravity * W.interval)
                lp.origin = V.v3(lp.origin.x, lp.origin.y, lp.origin.z + lp.vel.z * W.interval)
                if lp.origin.z <= W.floor_z and lp.vel.z < 0 then
                    lp.origin = V.v3(lp.origin.x, lp.origin.y, W.floor_z)
                    lp.vel = V.v3(lp.vel.x, lp.vel.y, 0)
                    lp.ground = true
                    lp.air_phys = false
                    T.landed = W.tick
                end
            end
            if W.choke_fixed ~= nil then W.choked = W.choke_fixed else W.choked = W.tick % W.choke_cycle end
            -- rc_leak: block_recharge sarji durdurmuyor (G5, T-DIAG-7).
            if W.auto_recharge and W.keys.dt and (not W.rc_blocked or W.rc_leak) and W.charge < W.max_charge then
                W.charge = W.charge + 1
            end
            -- drain_at: force_uncharge sarji cagridan bir tick sonra bosaltir (H.lag_drain, G26 / T-CHG-9).
            if W.drain_at ~= nil and W.tick >= W.drain_at then W.charge, W.drain_at = 0, nil end
            if #T.delays > 0 then
                local keep = {}
                local due = {}
                for _, d in ipairs(T.delays) do
                    if d.due <= T.rt() + 1e-9 then due[#due + 1] = d else keep[#keep + 1] = d end
                end
                T.delays = keep
                for _, d in ipairs(due) do T.call(d.fn) end
            end
            if hook then hook(T, W) end
            local cmd = T.newcmd()
            T.last_cmd = cmd
            local aar = { tick = W.tick, choked = W.choked, n = 0 }
            local actx = setmetatable({ _r = aar }, AAC_MT)
            -- aa_first: ANTIAIM SETUP_COMMAND'dan once; aa_twice: ANTIAIM ayni komutta iki kez (G1 / G27).
            if W.aa_first then
                T.fire("ANTIAIM", actx, cmd, nil)
                if W.aa_twice then T.fire("ANTIAIM", actx, cmd, nil) end
                T.fire("SETUP_COMMAND", cmd)
            else
                T.fire("SETUP_COMMAND", cmd)
                T.fire("ANTIAIM", actx, cmd, nil)
                if W.aa_twice then T.fire("ANTIAIM", actx, cmd, nil) end
            end
            local mv = (not W.raise_cmd) and cmd.move or nil
            if type(mv) == "table" then T.moves[W.tick] = { x = mv.x or 0, y = mv.y or 0 } end
            T.aa[#T.aa + 1] = aar
            if W.choked == 0 and aar.desync ~= nil then
                local s
                if W.sign_ignore then
                    if aar.invert ~= nil then
                        s = aar.invert and -1 or 1
                    else
                        T.ign_n = T.ign_n + 1
                        s = (math.floor(T.ign_n / 2) % 2 == 0) and 1 or -1
                    end
                else
                    s = (aar.desync >= 0 and 1 or -1) * W.sign_conv
                end
                local real = aar.yaw or W.view.y
                T.dsy[#T.dsy + 1] = { real = real, fake = real - s * 58 }
            end
            local tctx = setmetatable({}, TSC_MT)
            local function scan()
                if not lp.alive or W.no_local then return end
                for i = 2, #P do
                    local p = P[i]
                    if p.alive and not p.dormant and (W.scan[i] or (W.head_dmg[i] or 0) > 0 or (W.body_dmg[i] or 0) > 0) then
                        local r = { tick = W.tick, idx = i, sp = {}, groups = {}, mds = {} }
                        T.hs[#T.hs + 1] = r
                        T.fire("HITSCAN", setmetatable({ _r = r, player = T.ent(i) }, HSC_MT), cmd, nil)
                    end
                end
            end
            -- hs_first: HITSCAN TARGET_SELECTION'dan once (sira sayaci, T-DIAG-1).
            if W.hs_first then scan() end
            T.fire("TARGET_SELECTION", tctx, cmd, nil)
            if not W.hs_first then scan() end
            -- no_net: NET_UPDATE hic gelmiyor (takip SETUP_COMMAND'dan guncellenmeli, T-RAGE-29).
            if not W.no_net then T.fire("NET_UPDATE") end
            T.frame = {}
            T.in_paint = true
            T.fire("PAINT")
            T.in_paint = false
            T.ftexts[W.tick] = T.frame
            T.ftexts[W.tick - 400] = nil
            if W.physics and lp.ground and lp.alive then
                local m = T.moves[W.tick] or { x = 0, y = 0 }
                local y = math.rad(W.view.y)
                local fx, fy = math.cos(y), math.sin(y)
                local rx, ry = math.sin(y), -math.cos(y)
                local wx = fx * m.x + rx * m.y * W.side_conv
                local wy = fy * m.x + ry * m.y * W.side_conv
                local mag = math.sqrt(m.x * m.x + m.y * m.y)
                local len = math.sqrt(wx * wx + wy * wy)
                if mag > 0.5 and len > 0 then
                    local sp = math.min(250, mag * 250 / 450)
                    lp.vel = V.v3(wx / len * sp, wy / len * sp, lp.vel.z)
                else
                    lp.vel = V.v3(0, 0, lp.vel.z)
                end
                lp.origin = V.v3(lp.origin.x + lp.vel.x * W.interval, lp.origin.y + lp.vel.y * W.interval, lp.origin.z)
                T.ymax = math.max(T.ymax or -1e9, lp.origin.y)
                T.ymin = math.min(T.ymin or 1e9, lp.origin.y)
            end
        end
    end
    function T.finish()
        if T.finished then return end
        T.finished = true
        if T.ok then T.shutdown() end
        if not opts.expect_errors then
            for _, l in ipairs(T.prints) do
                if l:find("hata verdi", 1, true) or l:find("kapatildi", 1, true) and l:find("hata", 1, true) then
                    H.G.hata[#H.G.hata + 1] = T.name .. ": " .. l
                end
            end
        end
        if T.ok and W.rc_blocked then H.G.rc_left[#H.G.rc_left + 1] = T.name end
        for _, l in ipairs(H.nonascii(T)) do H.G.nonascii[#H.G.nonascii + 1] = T.name .. ": " .. l end
        for _, x in ipairs(T.sel_range) do H.G.forbidden["secim araligi disinda :set (" .. x .. ")"] = true end
        for _, x in ipairs(T.el_set_bad) do H.G.forbidden["checkbox'a bool olmayan :set (" .. x .. ")"] = true end
    end

    -- yukle -------------------------------------------------------------------------------------------------------------
    if opts.pre then opts.pre(T, W) end
    local fn, err = loadstring(SRC, "=Nykle.win")
    if fn == nil then
        T.ok = false
        T.load_err = "derlenemedi: " .. tostring(err)
        return T
    end
    setfenv(fn, env)
    T.in_cb = 0
    local ok, e = pcall(fn)
    T.ok = ok
    T.load_err = e
    if not ok then return T end
    if not opts.raw then
        local a = T.el("afk_auto")
        if a and not opts.keep_afk then a:set(false) end
        local r = T.el("recommended")
        if r and opts.rec_off then r:set(false) end
        -- V1.0.10: eski "olay basina bir" senaryolari def_repeat 0 ile kosar; varsayilani (16) sinayan testler
        -- opts.def_repeat = true verir.
        if not opts.def_repeat and T.el("def_repeat") ~= nil then T.set("def_repeat", 0) end
        if opts.setup then opts.setup(T, W) end
        T.tick(opts.warm or 2)
    end
    return T
end
function H.boot(opts)
    local T = H.make(opts)
    if not T.ok then error("script yuklenemedi: " .. tostring(T.load_err)) end
    return T
end

-------------------------------------------------------------------------------
-- Kontrol yardimcilari
-------------------------------------------------------------------------------
H.C = {}
local C = H.C
function H.yawlist(recs, n)
    local r = {}
    for _, e in ipairs(recs) do
        if #r >= (n or 8) then break end
        r[#r + 1] = e.yaw and H.f1(H.norm(e.yaw)) or "nil"
    end
    return table.concat(r, ",")
end
function H.yaws_ok(recs, allowed, need_all, tol)
    tol = tol or 0.6
    local seen, bad, n = {}, nil, 0
    for _, r in ipairs(recs) do
        if r.yaw ~= nil then
            n = n + 1
            local hit = nil
            for i, a in ipairs(allowed) do if H.adiff(r.yaw, a) < tol then hit = i end end
            if hit then seen[hit] = true elseif bad == nil then bad = r.yaw end
        end
    end
    local all = true
    if need_all then for i = 1, #allowed do if not seen[i] then all = false end end end
    local why = (n == 0 and "set_yaw yok") or (bad ~= nil and ("beklenmeyen yaw " .. H.f1(H.norm(bad))))
        or ((not all) and "iki deger de gorulmedi") or "ok"
    return n > 0 and bad == nil and all, why .. " [" .. H.yawlist(recs, 10) .. "]"
end
function H.frac(recs, pred)
    local n, k = 0, 0
    for _, r in ipairs(recs) do
        n = n + 1
        if pred(r) then k = k + 1 end
    end
    return n > 0 and k / n or 0, k, n
end
function H.lines_with(T, pat, since)
    local r = {}
    for i = since or 1, #T.prints do if T.prints[i]:find(pat, 1, true) then r[#r + 1] = T.prints[i] end end
    return r
end
function H.mem_lines(T, kind)
    local f = T.W.files["nykle_memory.txt"]
    local r = {}
    if f == nil then return r, false end
    for line in (f .. "\n"):gmatch("([^\n]*)\n") do
        if line:sub(1, #kind + 1) == kind .. "\t" then
            local fields = {}
            for x in (line .. "\t"):gmatch("([^\t]*)\t") do fields[#fields + 1] = x end
            r[#r + 1] = fields
        end
    end
    return r, true
end
function H.seen_by(W, idx, d) W.sees[idx] = d or 60 end
-- "Defensive: one shift per event" kapali (eski yol: istek surdukce her tick). Izlenen oge: rec_off ile birlikte.
function H.edge_off(T) T.set("def_edge", false) end
-- V1.0.4'te (def_edge yokken) T-EX-17'nin "300 tick goruluyor" sahnesindeki force_anti_exploit_shift sayisi.
H.OLD_SEEN_300 = 302
-- Butun ornek boyunca force_anti_exploit_shift cagri sayisi ve cagri tick'leri (sirali).
function H.shift_all(T)
    local ticks, n = {}, 0
    for t, c in pairs(T.shift) do ticks[#ticks + 1] = t; n = n + c end
    table.sort(ticks)
    return n, ticks
end
function H.knife_enemy(W, idx, dist, wname, class)
    local p = W.p[idx]
    p.weapon = H.weapon(wname or "knife", class)
    if idx == 2 then p.origin = V.v3(dist, 0, 0) else p.origin = V.v3(0, dist, 0) end
end

-------------------------------------------------------------------------------
-- Yukleme / guvenlik
-------------------------------------------------------------------------------
function C.load_full()
    H.run("T-LOAD-1", function()
        local T = H.make({ name = "load", raw = true })
        H.check("T-LOAD-1", T.ok and T.printed(H.VER .. " (primordial edition) yuklendi") ~= nil,
            "derlenir, yuklenir ve '[Nykle.win] " .. H.VER .. " (primordial edition) yuklendi' basilir"
            .. (T.ok and "" or (": " .. tostring(T.load_err))))
        if not T.ok then error("yuklenemedi") end
        -- T-LOAD-3: tablo §2'nin kopyasi
        local bad = {}
        for _, r in ipairs(H.EL) do
            local e = T.el(r[1])
            local nm = H.GROUPS[r[2]][1] .. " / " .. r[3]
            if e == nil then
                bad[#bad + 1] = "yok: " .. nm
            else
                local kind = r[4]
                if e.kind ~= kind then
                    bad[#bad + 1] = "tip " .. nm .. " = " .. e.kind .. " (beklenen " .. kind .. ")"
                elseif kind == "cb" and e.value ~= r[5] then
                    bad[#bad + 1] = "varsayilan " .. nm .. " = " .. tostring(e.value)
                elseif kind == "sl" then
                    if math.abs((e.value or -999) - r[5]) > 1e-3 then bad[#bad + 1] = "varsayilan " .. nm .. " = " .. tostring(e.value) end
                    if e.min ~= r[6] or e.max ~= r[7] then
                        bad[#bad + 1] = "aralik " .. nm .. " = " .. tostring(e.min) .. ".." .. tostring(e.max)
                    end
                elseif kind == "sel" then
                    if e.value ~= r[5] then bad[#bad + 1] = "varsayilan " .. nm .. " = " .. tostring(e.value) end
                    if table.concat(e.items or {}, "|") ~= table.concat(r[6], "|") then
                        bad[#bad + 1] = "ogeler " .. nm .. " = " .. table.concat(e.items or {}, ",")
                    end
                elseif kind == "col" then
                    local c, d = e.value or {}, r[5]
                    if c.r ~= d[1] or c.g ~= d[2] or c.b ~= d[3] or (c.a or 255) ~= d[4] then
                        bad[#bad + 1] = "renk " .. nm
                    end
                elseif kind == "btn" and type(e.fn) ~= "function" then
                    bad[#bad + 1] = "buton fonksiyonu yok: " .. nm
                end
            end
        end
        for _, g in ipairs(H.GROUP_ORDER) do
            local gn, col = H.GROUPS[g][1], H.GROUPS[g][2]
            if T.group_col[gn] ~= col then bad[#bad + 1] = "kolon " .. gn .. " = " .. tostring(T.group_col[gn]) end
        end
        local order_ok = true
        local ord = T.group_order or {}
        local k = 1
        for _, g in ipairs(ord) do
            if g:sub(1, 10) == "Nykle.win " then
                if H.GROUPS[H.GROUP_ORDER[k]] == nil or H.GROUPS[H.GROUP_ORDER[k]][1] ~= g then order_ok = false end
                k = k + 1
            end
        end
        if not order_ok then bad[#bad + 1] = "grup olusturma sirasi farkli: " .. table.concat(ord, ", ") end
        for _, n in ipairs(T.badnames) do bad[#bad + 1] = "ad '#' ya da ASCII disi karakter iceriyor: " .. n end
        H.check("T-LOAD-3", #bad == 0, "§2 menusu birebir (" .. #H.EL .. " oge; ad, tip, varsayilan, aralik, kolon, sira)"
            .. (#bad > 0 and (": " .. #bad .. " fark: " .. H.list(bad, 6)) or ""))
        local n = H.count_main_locals(SRC)
        H.check("T-LOAD-4", n <= 24, "ana bolumde " .. n .. " local (hedef <= 24; derleme basarisi 200 local / 60 upvalue"
            .. " sinirini zaten kanitlar)")
    end)
end

-- Her modda: genis tarama (T-LOAD-5 / T-LOAD-8 / T-OV-5 verisi).
function H.sweep(T)
    local W, P = T.W, T.W.p
    T.tick(20)
    W.sees[2] = 60; W.head_dmg[2] = 50; W.body_dmg[2] = 40; W.can_fire = true
    T.tick(30)
    local id = T.shoot(2); T.tick(2); T.hit(id, { hg = 1, dmg = 50 }); T.tick(5)
    id = T.shoot(2); T.tick(2); T.miss(id, "resolver"); T.tick(5)
    id = T.shoot(2); T.tick(2); T.miss(id, "spread", { noplayer = true }); T.tick(5)
    T.impact(2, 20); T.tick(2); T.hurt_me(2, 1, 40); T.tick(20)
    P[1].vel = V.v3(120, 0, 0); W.buttons.FORWARD = true; W.move = { x = 450, y = 0 }; T.tick(30)
    P[1].vel = V.v3(0, 0, 0); W.buttons.FORWARD = nil; W.move = { x = 0, y = 0 }
    T.jump(300); T.tick(60)
    W.keys.fd = true; P[1].duck = 0.8; T.tick(20); W.keys.fd = false; P[1].duck = 0
    W.manual = 1; T.tick(10); W.manual = 3; T.tick(10); W.manual = 0
    W.keys.fs = true; T.tick(10); W.keys.fs = false
    W.keys.ext = true; T.tick(5); W.keys.ext = false
    H.knife_enemy(W, 3, 200); W.sees[3] = 30; T.tick(20)
    W.keys.autopeek = true; W.autopeek_pos = V.v3(0, 0, 0); W.physics = true; T.tick(60)
    W.keys.autopeek = false; W.autopeek_pos = nil; W.physics = false
    P[1].ground = true; P[1].air_phys = false; P[1].origin = V.v3(0, 0, 0); P[1].vel = V.v3(0, 0, 0)
    P[1].movetype = 9; T.tick(5); P[1].movetype = 2
    W.buttons.USE = true; T.tick(5); W.buttons.USE = nil
    W.menu_open = true
    local tab = T.el("tab")
    if tab then for t = 1, 7 do tab:set(t); T.tick(3) end end
    W.menu_open = false
    for _, b in ipairs({ "log_copy", "log_print", "log_save", "log_clear", "forget", "stats_reset" }) do
        if T.el(b) then T.press(b) end
    end
    T.event("round_end", { winner = 2, reason = 1 })
    T.event("round_prestart", {})
    T.event("round_start", { timelimit = 115 })
    W.freeze = true; T.tick(10); W.freeze = false
    T.event("player_spawn", { userid = 101 })
    T.event("weapon_fire", { userid = 102, weapon = "weapon_ak47" })
    T.tick(10)
    T.event("player_death", { userid = 102, attacker = 101, weapon = "ssg08", headshot = true })
    P[2].alive = false; T.tick(10)
    T.event("player_death", { userid = 101, attacker = 103, weapon = "knife", headshot = false })
    P[1].alive = false; T.tick(10)
    P[1].alive = true; P[2].alive = true
    T.event("player_spawn", { userid = 101 })
    T.event("game_newmap", { mapname = "de_inferno" })
    W.map = "de_inferno"
    T.tick(40)
    local en = T.el("enabled")
    if en then en:set(false); T.tick(5); en:set(true); T.tick(5) end
    W.no_local = true; T.tick(5); W.no_local = false; T.tick(5)
end
function C.sweep_mode()
    H.run("T-LOAD-5/6/8 tarama", function()
        local T = H.boot({ name = "tarama-" .. H.mode, keep_afk = true })
        H.sweep(T)
        if H.mode == "missing" then
            T.tick(700)
            local lines = H.lines_with(T, "menude bulunamadi")
            local dup, seen = nil, {}
            for _, l in ipairs(lines) do
                if seen[l] then dup = l end
                seen[l] = true
            end
            H.check("T-LOAD-5", #lines >= 1 and dup == nil and #T.raw_err == 0,
                "eksik native yollar: " .. #lines .. " 'menude bulunamadi' satiri, her yol bir kez (11 sn icinde tekrar yok)"
                .. (dup and (": tekrar: " .. dup) or ""))
        end
        if H.mode == "nofeature" then
            H.check("T-LOAD-6", T.printed("defensive yok") ~= nil and T.calls_in(T.shift, 0, 1e12) == 0,
                "force_anti_exploit_shift yok: yukleme satirinda '(defensive yok' ve hic cagri yok")
        end
        T.shutdown()
    end)
    if H.mode == "nofeature" then
        H.run("T-LOAD-6", function()
            local T = H.boot({ name = "olculemedi", rec_off = true })
            T.W.choke_fixed = 0
            T.bset("Standing", "Body yaw", 2)
            T.tick(700)
            H.check("T-LOAD-6", T.printed("olculemedi") ~= nil,
                "get_real_angle nil: desync isaret olcumu '(olculemedi)' yazar, esleme +1 kalir")
        end)
    end
end

function C.load_errors()
    H.run("T-LOAD-7", function()
        local T = H.boot({ name = "hata-enjekte", expect_errors = true })
        local m = T.mark()
        T.W.raise_cmd = true
        T.tick(60)
        T.W.raise_cmd = false
        T.tick(10)
        local lines = H.lines_with(T, "hata verdi", m)
        local per = {}
        local maxn = 0
        for _, l in ipairs(lines) do
            local nm = l:match("%] (.-) hata verdi") or l:match("(%S+) hata verdi") or "?"
            per[nm] = (per[nm] or 0) + 1
            if per[nm] > maxn then maxn = per[nm] end
        end
        local dead = T.count("50 hata, kapatildi", m)
        local names = 0
        for _ in pairs(per) do names = names + 1 end
        H.check("T-LOAD-7", #lines >= 1 and maxn <= 3 and dead >= 1 and dead == names,
            "cmd nesnesi 60 tick hata verdi: " .. #lines .. " satir (isleyici basina en fazla 3, en cok " .. maxn
            .. "), '50 hata, kapatildi' " .. dead .. " kez (" .. names .. " isleyici); script calismaya devam eder")
        local before = #T.raw_err
        T.tick(20)
        H.check("T-LOAD-7", #T.raw_err == before and before == 0, "hatalar dagiticida yakalanir, primordial'a kacmaz ("
            .. before .. " kacan)")
    end)
end

-------------------------------------------------------------------------------
-- Menu
-------------------------------------------------------------------------------
function C.menu()
    H.run("T-MENU-1", function()
        local T = H.boot({ name = "recommended" })
        T.bset("Standing", "Yaw left", 5)
        T.set("crouch_speed", 50)
        local m = T.mark()
        T.tick(150)
        local y = T.get("b:Standing:Yaw left")
        H.check("T-MENU-1", y == -23 and T.printed("donduruldu", m) ~= nil,
            "menu kapaliyken izlenen '[Standing] Yaw left' 5 -> " .. tostring(y) .. " (beklenen -23) ve 'donduruldu' satiri")
        H.check("T-MENU-1", T.get("crouch_speed") == 50 and T.get("afk_auto") == false,
            "izlenmeyen 'Crouch speed' (50) ve 'Auto AFK' (kapali) dokunulmaz")
        T.W.menu_open = true
        T.bset("Standing", "Yaw left", 7)
        T.tick(150)
        H.check("T-MENU-1", T.get("b:Standing:Yaw left") == 7, "menu acikken kullanicinin degeri geri cevrilmez")
    end)
    H.run("T-MENU-2", function()
        local T = H.boot({ name = "gorunurluk" })
        T.W.menu_open = true
        T.set("tab", 3)
        T.set("state", 8)
        T.tick(40)
        local a, s = T.el("b:Air:Yaw left"), T.el("b:Standing:Yaw left")
        H.check("T-MENU-2", a and a.visible == true and s and s.visible == false,
            "Tab Builder + State Air: [Air] gorunur (" .. tostring(a and a.visible) .. "), [Standing] gizli ("
            .. tostring(s and s.visible) .. ")")
        T.bset("Air", "Yaw mode", 2)
        T.tick(40)
        local l, r = T.el("b:Air:Yaw left"), T.el("b:Air:Yaw right")
        local w1, w3, w4 = T.el("b:Air:Way 1"), T.el("b:Air:Way 3"), T.el("b:Air:Way 4")
        H.check("T-MENU-2", l.visible == false and r.visible == false and w1.visible and w3.visible and w4.visible == false,
            "X-Way: Yaw left/right gizli, Way 1..3 gorunur, Way 4 gizli (Ways = 3)")
    end)
    H.run("T-MENU-3", function()
        local T = H.boot({ name = "sekmeler" })
        T.W.menu_open = true
        T.set("tab", 3)
        T.tick(40)
        local gv = T.group_vis
        local ok1 = gv["Nykle.win | Builder"] == true and gv["Nykle.win | Builder exploit"] == true
            and gv["Nykle.win | Anti-Aim"] == false and gv["Nykle.win | Misc"] == false and gv["Nykle.win | Home"] ~= false
        T.set("tab", 7)
        T.tick(40)
        local ok2 = gv["Nykle.win | Misc"] == true and gv["Nykle.win | Builder"] == false and gv["Nykle.win | Home"] ~= false
        H.check("T-MENU-3", ok1 and ok2, "set_group_visibility sekmeye gore (Builder -> Builder + Builder exploit; Misc"
            .. " -> Misc; Home hep acik)")
    end)
    H.run("T-MENU-4", function()
        local T = H.boot({ name = "butonlar" })
        local W = T.W
        W.head_dmg[2] = 50
        W.p[1].weapon = H.weapon("deagle")
        T.tick(10)
        local id = T.shoot(2); T.tick(2); T.miss(id, "resolver"); T.tick(3)
        id = T.shoot(2); T.tick(2); T.hit(id, { hg = 1, dmg = 50 }); T.tick(3)
        T.event("round_end", { winner = 2 })
        T.tick(2)
        T.press("forget")
        T.tick(2)
        local P_, has = H.mem_lines(T, "P")
        local F_ = H.mem_lines(T, "F2")
        H.check("T-MENU-4", has and #P_ == 0 and #F_ == 0 and (T.file("nykle_memory.txt") or ""):find("NYKLEMEM", 1, true) ~= nil,
            "'Forget learned enemies' hafiza dosyasini P / F satirsiz yeniden yazar (P " .. #P_ .. ", F " .. #F_ .. ")")
        id = T.shoot(2); T.tick(2); T.hit(id, { hg = 1, dmg = 50 }); T.tick(3)
        T.press("stats_reset")
        id = T.shoot(2); T.tick(2); T.hit(id, { hg = 1, dmg = 50 }); T.tick(3)
        local m = T.mark()
        T.event("round_start", {})
        T.tick(3)
        local l = T.printed("atis ozeti:", m) or ""
        H.check("T-MENU-4", l:find("atis ozeti: 1 mermi, 1 isabet", 1, true) ~= nil,
            "'Reset stats' sayaclari sifirlar (2 atis + reset + 1 atis -> 1 mermi): " .. l)
    end)
end

-------------------------------------------------------------------------------
-- Override / recharge / shutdown
-------------------------------------------------------------------------------
H.OV_PATHS = {
    { "antiaim/main/angles/jitter mode", 1 }, { "antiaim/main/angles/rotate", false }, { "antiaim/main/angles/yaw add", 0 },
    { "antiaim/main/angles/body lean", 1 }, { "antiaim/main/angles/moving body lean", false },
    { "antiaim/main/extended angles/enable while moving", false }, { "antiaim/main/desync/override stand#move", false },
    { "antiaim/main/desync/override stand#slow walk", false }, { "antiaim/main/desync/anti bruteforce", false },
    { "antiaim/main/desync/on shot", 1 }, { "antiaim/main/desync/side#stand", 2 },
    { "antiaim/main/desync/left amount#stand", 100 }, { "antiaim/main/desync/right amount#stand", 100 },
}
function C.override()
    H.run("T-OV-1", function()
        local T = H.boot({ name = "ov-1" })
        T.tick(70)
        local bad = {}
        for _, p in ipairs(H.OV_PATHS) do
            local v = T.natv(p[1])
            local n = T.script_writes(p[1])
            if v ~= p[2] or n ~= 1 then bad[#bad + 1] = p[1] .. " = " .. tostring(v) .. " (" .. n .. " yazma)" end
        end
        H.check("T-OV-1", #bad == 0, "A23 tasiyicilari tam Lua degerleriyle bir kez yazilir (jitter mode 1, side#stand 2, on"
            .. " shot 1, body lean 1, yaw add 0, ext moving false ...)" .. (#bad > 0 and (": " .. H.list(bad, 5)) or ""))
        T.shutdown()
        bad = {}
        for _, p in ipairs(H.OV_PATHS) do
            local d = T.nat[p[1]]
            if d.value ~= d.snap0 then bad[#bad + 1] = p[1] .. " = " .. tostring(d.value) end
        end
        H.check("T-OV-1", #bad == 0, "SHUTDOWN anlik goruntuleri geri yazar" .. (#bad > 0 and (": " .. H.list(bad, 5)) or ""))
    end)
    H.run("T-OV-1", function()
        local T = H.boot({ name = "ov-notr", neutral = true })
        T.tick(140)
        local n = 0
        for _, w in ipairs(T.natw) do if not w.harness then n = n + 1 end end
        H.check("T-OV-1", n == 0, "native'ler zaten notrse (cfg'mizle) hic ov yazmasi olmaz (§2.5): " .. n .. " yazma")
    end)
    H.run("T-OV-2", function()
        local T = H.boot({ name = "ov-2" })
        T.tick(70)
        T.hset("antiaim/main/angles/jitter mode", 3)
        T.set("enabled", false)
        T.tick(2)
        H.check("T-OV-2", T.natv("antiaim/main/angles/jitter mode") == 3 and T.natv("antiaim/main/angles/rotate") == true,
            "tutulurken kullanicinin degistirdigi jitter mode (3) birakmada korunur, digerleri anlik goruntuye doner")
    end)
    H.run("T-OV-3", function()
        local T = H.boot({ name = "ov-3", pre = function(T, W) W.stuck["antiaim/main/angles/rotate"] = true end })
        T.tick(64 * 12)
        local n = T.script_writes("antiaim/main/angles/rotate")
        local lines = T.count("ayarlanamadi")
        H.check("T-OV-3", n >= 2 and n <= 13 and lines == 1, "geri okumasi tutmayan yazma 5 sn sonra tekrar denenir ("
            .. n .. " deneme / 12 sn) ve 'ayarlanamadi' bir kez (" .. lines .. ")")
    end)
    H.run("T-OV-4", function()
        local T = H.boot({ name = "ov-4" })
        local W = T.W
        W.head_dmg[2] = 50
        T.tick(70)
        W.sees[2] = 60
        local id = T.shoot(2)
        T.tick(2)
        local t0 = W.tick
        T.set("enabled", false)
        T.tick(3)
        local bad = {}
        for _, p in ipairs(H.OV_PATHS) do
            local d = T.nat[p[1]]
            if d.value ~= d.snap0 then bad[#bad + 1] = p[1] end
        end
        local cv_ok = W.cv.cl_righthand == 1 and math.abs(W.cv.r_aspectratio - 0) < 1e-6
        H.check("T-OV-4", #bad == 0 and not W.rc_blocked and T.calls_in(T.alw, t0, W.tick) >= 1 and cv_ok and W.clantag == "",
            "Enable kapali: native'ler geri, allow_recharge, cvar'lar geri (cl_righthand " .. tostring(W.cv.cl_righthand)
            .. "), clantag '" .. tostring(W.clantag) .. "'" .. (#bad > 0 and (": geri donmeyen " .. H.list(bad, 4)) or ""))
        local t1 = W.tick
        T.tick(30)
        local calls = 0
        for _, r in ipairs(T.aa) do if r.tick > t1 and r.n > 0 then calls = calls + 1 end end
        for _, r in ipairs(T.hs) do
            if r.tick > t1 and (r.md or r.hc or #r.sp > 0 or next(r.groups)) then calls = calls + 1 end
        end
        calls = calls + T.ignored(2, t1 + 1)
        H.check("T-OV-4", calls == 0, "kapaliyken ANTIAIM / HITSCAN / TARGET_SELECTION ctx cagrisi yok (" .. calls .. ")")
        T.set("enabled", true)
        T.tick(70)
        bad = {}
        for _, p in ipairs(H.OV_PATHS) do if T.natv(p[1]) ~= p[2] then bad[#bad + 1] = p[1] end end
        H.check("T-OV-4", #bad == 0, "Enable tekrar acik: tasiyicilar yeniden tutulur" .. (#bad > 0 and (": " .. H.list(bad, 4)) or ""))
        local _ = id
    end)
end

-- Ortak: goruldugu bir ziplama, isinlanma tick'ini ve inis tick'ini dondurur.
function H.seen_jump(T, vz, extra, keep_charge)
    local W = T.W
    W.sees[2] = 60
    if not keep_charge then W.charge = W.max_charge end
    local u0 = #T.unch
    local t0 = W.tick
    T.jump(vz or 300)
    local tp = nil
    for _ = 1, 200 do
        T.tick(1, extra)
        if tp == nil and #T.unch > u0 then tp = W.tick end
        if W.p[1].ground then break end
    end
    return tp, W.tick, t0
end
function C.recharge()
    H.run("T-RC-1", function()
        local T = H.boot({ name = "rc-1", setup = function(T) T.set("air_lc", false) end })
        local W = T.W
        T.tick(40)
        local tp, land = H.seen_jump(T, 300)
        T.tick(3)
        local ok1 = tp ~= nil and not W.rc_blocked and T.calls_in(T.alw, land, W.tick) >= 1
        W.sees[2] = 60
        T.tick(10)
        W.charge = 14
        T.jump(300)
        T.tick(6)
        local blocked = W.rc_blocked
        T.event("player_death", { userid = 101, attacker = 102, weapon = "ssg08" })
        W.p[1].alive = false
        T.tick(2)
        local ok2 = blocked and not W.rc_blocked
        W.p[1].alive = true; W.p[1].ground = true; W.p[1].air_phys = false; W.p[1].origin = V.v3(0, 0, 0)
        W.p[1].vel = V.v3(0, 0, 0)
        T.event("player_spawn", { userid = 101 })
        W.charge = 14
        T.tick(10)
        T.jump(300)
        T.tick(6)
        local blocked2 = W.rc_blocked
        T.event("round_start", {})
        T.tick(1)
        local ok3 = blocked2 and not W.rc_blocked
        H.check("T-RC-1", ok1 and ok2 and ok3, "block_recharge her zaman allow ile kapanir: inis " .. tostring(ok1)
            .. ", olum " .. tostring(ok2) .. ", round_start " .. tostring(ok3))
    end)
    H.run("T-RC-2", function()
        local T = H.boot({ name = "rc-2", setup = function(T) T.set("air_lc", false) end })
        local W = T.W
        W.head_dmg[2] = 50
        T.tick(40)
        W.sees[2] = 60
        local u0 = #T.unch
        T.jump(300)
        local tp, allows, blocked_all = nil, 0, true
        for _ = 1, 200 do
            T.tick(1)
            if tp == nil and #T.unch > u0 then
                tp = W.tick
                local id = T.shoot(2)
                T.tick(1)
                T.miss(id, "spread")
            elseif tp ~= nil and not W.p[1].ground then
                allows = allows + (T.alw[W.tick] or 0)
                if not W.rc_blocked then blocked_all = false end
            end
            if W.p[1].ground then break end
        end
        H.check("T-RC-2", tp ~= nil and allows == 0 and blocked_all,
            "havadaki kilit ('air') surerken atisin 'safe' sebebi birakilsa da allow_recharge cagrilmaz (" .. allows
            .. "), kilit kesintisiz")
    end)
    H.run("T-RC-3", function()
        -- Eski yol (biri kapali): Air LC kilidi inise kadar; V1.0.80 inis teleportu kilit tutmaz (T-EX-13).
        local T = H.boot({ name = "rc-3", rec_off = true, setup = function(T) T.set("air_teleport", false) end })
        local W = T.W
        T.tick(40)
        W.sees[2] = 60
        local u0 = #T.unch
        W.p[1].ground = false
        W.p[1].vel = V.v3(0, 0, 250)
        local tp
        local m = T.mark()
        for _ = 1, 64 * 4 do
            T.tick(1, function(T, W) W.p[1].ground = false; W.p[1].vel = V.v3(0, 0, 250) end)
            if tp == nil and #T.unch > u0 then tp = W.tick end
        end
        local line, li = T.printed("sarj kilidi 3 sn'yi gecti", m)
        local every = tp ~= nil
        local per_tick_allow = 0
        if tp then
            for t = tp + 1, tp + 150 do
                if (T.blk[t] or 0) < 1 then every = false end
                if (T.alw[t] or 0) > 0 then per_tick_allow = per_tick_allow + 1 end
            end
        end
        H.check("T-RC-3", every and per_tick_allow == 0,
            "tutulurken block_recharge her tick yeniden cagrilir, allow_recharge tick basina cagrilmaz (teleport "
            .. tostring(tp) .. ", allow " .. per_tick_allow .. ")")
        local wd_allow = tp and T.calls_in(T.alw, tp + 150, tp + 64 * 3 + 40) or 0
        H.check("T-RC-3", line ~= nil and wd_allow >= 1,
            "inis hic gelmezse 3 sn watchdog birakir ve 'sarj kilidi 3 sn'yi gecti' yazar (her tick yeniden kilitlense de)")
        local _ = li
    end)
    H.run("T-SD-1", function()
        local T = H.boot({ name = "shutdown" })
        local W = T.W
        W.head_dmg[2] = 50
        T.tick(70)
        local id = T.shoot(2); T.tick(2); T.hit(id, { hg = 1, dmg = 50 })
        T.tick(3)
        local mid = { r = W.cv.cl_righthand, a = W.cv.r_aspectratio, d = W.cv.developer, s = W.cv.r_shadows }
        local t0 = W.tick
        T.shutdown()
        local cv_ok = W.cv.cl_righthand == 1 and math.abs(W.cv.r_aspectratio) < 1e-6 and W.cv.developer == 1
        for _, c in ipairs(H.FPS_CVARS) do if W.cv[c] ~= H.CVAR_DEF[c] then cv_ok = false end end
        local f = T.file() or ""
        local mem = T.file("nykle_memory.txt") or ""
        H.check("T-SD-1", (T.alw[t0] or 0) >= 1 and W.clantag == "" and cv_ok and mid.r == 0 and mid.d == 0 and mid.s == 0,
            "SHUTDOWN: allow_recharge, clantag '', cl_righthand / r_aspectratio / developer / FPS cvar'lari geri")
        H.check("T-SD-1", f:find("atis:", 1, true) ~= nil and mem:find("NYKLEMEM", 1, true) ~= nil,
            "SHUTDOWN: log dosyaya yazilir (atis satiri dosyada) ve hafiza dosyasi yazilir")
    end)
end

-------------------------------------------------------------------------------
-- Anti-aim
-------------------------------------------------------------------------------
function C.aa()
    H.run("T-AA-1", function()
        local T = H.boot({ name = "aa-1" })
        T.tick(100)
        local W = T.W
        local recs = T.recs(W.tick - 80, W.tick)
        local ok, why = H.yaws_ok(recs, { 157, -129 }, true)
        H.check("T-AA-1", ok, "Standing: set_yaw = hedef yaw + 180 + (-23 | +51): " .. why)
        local bad_change, run, maxrun, prev = 0, 0, 0, nil
        for _, r in ipairs(recs) do
            if r.yaw then
                local side = H.adiff(r.yaw, 157) < 1 and "L" or "R"
                if prev ~= nil and side ~= prev and r.choked ~= 0 then bad_change = bad_change + 1 end
                if r.choked == 0 then
                    if side == prev then run = run + 1 else run = 1 end
                    if run > maxrun then maxrun = run end
                end
                prev = side
            end
        end
        H.check("T-AA-1", bad_change == 0 and maxrun <= 3, "taraf yalnizca choked == 0 tick'lerinde degisir (" .. bad_change
            .. " ihlal), ayni taraf en fazla " .. maxrun .. " gonderilen paket")
        W.view.y = 25
        local t1 = W.tick
        T.tick(40)
        local ok2, why2 = H.yaws_ok(T.recs(t1 + 5, W.tick), { 157, -129 }, true)
        H.check("T-AA-1", ok2, "At target: bakis 25 derece kaysa da taban dusmana yaw (0): " .. why2)
        local U = H.boot({ name = "aa-1-sira", pre = function(T, W) W.aa_first = true end })
        U.tick(80)
        local ok3, why3 = H.yaws_ok(U.recs(U.W.tick - 60, U.W.tick), { 157, -129 }, true)
        H.check("T-AA-1", ok3, "ANTIAIM, SETUP_COMMAND'dan once calissa da ayni sonuc (G1): " .. why3)
    end)
    H.run("T-AA-2", function()
        local T = H.boot({ name = "aa-2" })
        local W = T.W
        W.p[1].ground = false
        T.tick(60)
        local ok, why = H.yaws_ok(T.recs(W.tick - 40, W.tick), { 167, -146 }, true)
        H.check("T-AA-2", ok, "Air: -13 / +34: " .. why)
        local U = H.boot({ name = "aa-2b", rec_off = true })
        U.bset("Air", "Override", false)
        U.W.p[1].ground = false
        U.tick(60)
        local ok2, why2 = H.yaws_ok(U.recs(U.W.tick - 40, U.W.tick), { 160, -140 }, true)
        H.check("T-AA-2", ok2, "[Air] Override kapali: Global -20 / +40: " .. why2)
    end)
    H.run("T-AA-3", function()
        local T = H.boot({ name = "aa-3" })
        local W = T.W
        W.p[1].vel = V.v3(100, 0, 0)
        T.tick(60)
        local recs = T.recs(W.tick - 40, W.tick)
        local okm, whym = H.yaws_ok(recs, { 160, -130 }, true)
        local magbad, map, conflict = 0, {}, false
        for _, r in ipairs(recs) do
            if r.desync == nil or math.abs(math.abs(r.desync) - 58 / 60) > 0.006 then magbad = magbad + 1 end
            if r.yaw and r.desync then
                local side = H.adiff(r.yaw, 160) < 1 and "L" or "R"
                local s = H.sgn(r.desync)
                if map[side] ~= nil and map[side] ~= s then conflict = true end
                map[side] = s
            end
        end
        H.check("T-AA-3", okm and magbad == 0 and not conflict and map.L ~= nil and map.R ~= nil and map.L == -map.R,
            "Moving: |set_desync| = 58/60 (" .. magbad .. " sapma), isaret tarafla birlikte doner (L " .. tostring(map.L)
            .. ", R " .. tostring(map.R) .. "); " .. whym)
        local U = H.boot({ name = "aa-3b" })
        U.tick(40)
        local f = H.frac(U.recs(U.W.tick - 30, U.W.tick), function(r) return r.desync and math.abs(math.abs(r.desync) - 1) < 0.006 end)
        H.check("T-AA-3", f == 1, "Standing: |set_desync| = 60/60 = 1 (" .. H.f1(f * 100) .. "%)")
    end)
    H.run("T-AA-4", function()
        local T = H.boot({ name = "aa-4" })
        local W = T.W
        T.tick(30)
        W.p[1].vel = V.v3(120, 0, 0); T.tick(30)
        W.p[1].ground = false; T.tick(30)
        local f = H.frac(T.recs(W.tick - 85, W.tick), function(r) return r.lean == 0 end)
        H.check("T-AA-4", f == 1, "her ANTIAIM tick'inde set_body_lean(0) (roll yasak): " .. H.f1(f * 100) .. "%")
    end)
    H.run("T-AA-5", function()
        local T = H.boot({ name = "aa-5" })
        local W = T.W
        W.manual = 1
        T.tick(30)
        local ok1, w1 = H.yaws_ok(T.recs(W.tick - 20, W.tick), { 90 }, true)
        W.manual = 3
        T.tick(30)
        local ok2, w2 = H.yaws_ok(T.recs(W.tick - 20, W.tick), { -90 }, true)
        H.check("T-AA-5", ok1 and ok2, "manual sol -> taban+180-90 = 90, sag -> -90, jitter yok: " .. w1 .. " / " .. w2)
    end)
    H.run("T-AA-6", function()
        local T = H.boot({ name = "aa-6" })
        local W = T.W
        W.keys.fs = true
        T.tick(30)
        local recs = T.recs(W.tick - 20, W.tick)
        local f = H.frac(recs, function(r) return r.yaw == nil and r.desync ~= nil end)
        H.check("T-AA-6", f == 1, "Standing + native Auto Direction (kafa gizli): set_yaw yok, desync var ("
            .. H.f1(f * 100) .. "%)")
        W.p[1].ground = false
        local air_false = false
        for _ = 1, 20 do
            T.tick(1)
            if T.nat["antiaim/main/auto direction/states"].value[1] == false then air_false = true end
        end
        W.p[1].ground = true
        T.tick(15)
        local back = T.nat["antiaim/main/auto direction/states"].value[1] == true
        H.check("T-AA-6", air_false and back, "havada 'FS: disable in air': native States 'Air' false yazilir ("
            .. tostring(air_false) .. "), inisten sonra geri birakilir (" .. tostring(back) .. ")")
    end)
    H.run("T-AA-7", function()
        local T = H.boot({ name = "aa-7" })
        local W = T.W
        local p = W.p[1]
        p.weapon = H.weapon("knife"); p.ground = false; p.duck = 1.0; p.ducking = true
        W.buttons.DUCK = true
        T.tick(40)
        local recs = T.recs(W.tick - 25, W.tick)
        local okY, why = H.yaws_ok(recs, { 180 }, true)
        local f = H.frac(recs, function(r) return r.desync and math.abs(math.abs(r.desync) - 0.5) < 0.02 and r.pitch == 89 end)
        H.check("T-AA-7", okY and f >= 0.9, "Safe head (bicak + hava + egik): yaw 0 (=180), limit 30 (|desync| 0.5), pitch 89 ("
            .. H.f1(f * 100) .. "%); " .. why)
    end)
    H.run("T-AA-8", function()
        local T = H.boot({ name = "aa-8" })
        local W = T.W
        W.keys.fd = true
        W.p[1].duck = 0.7
        T.tick(80)
        local recs = T.recs(W.tick - 60, W.tick)
        local inrange, sidebad, prev, flips = true, 0, nil, 0
        for _, r in ipairs(recs) do
            if r.yaw == nil or H.adiff(r.yaw, 180) > 20.5 then inrange = false end
            local s = H.sgn(r.desync)
            if prev ~= nil and s ~= prev then
                flips = flips + 1
                if r.choked ~= 0 then sidebad = sidebad + 1 end
            end
            if r.desync and (math.abs(r.desync) < 47.5 / 60 or math.abs(r.desync) > 58.5 / 60) then inrange = false end
            prev = s
        end
        H.check("T-AA-8", inrange and sidebad == 0 and flips >= 1,
            "Fake duck: yaw 180 +-20, |desync| 48..58/60, rastgele taraf yalnizca gonderilen paketlerde (" .. flips
            .. " degisim, " .. sidebad .. " ihlal) [" .. H.yawlist(recs, 8) .. "]")
    end)
    H.run("T-AA-9", function()
        local T = H.boot({ name = "aa-9" })
        T.W.p[1].movetype = 9
        T.tick(30)
        local calls = 0
        for _, r in ipairs(T.recs(T.W.tick - 25, T.W.tick)) do calls = calls + r.n end
        H.check("T-AA-9", calls == 0, "merdiven (m_MoveType 9): ANTIAIM ctx cagrisi yok (" .. calls .. ")")
    end)
    H.run("T-AA-10", function()
        local T = H.boot({ name = "aa-10" })
        local W = T.W
        W.p[2].alive = false; W.p[3].alive = false
        T.tick(40)
        local recs = T.recs(W.tick - 30, W.tick)
        local good, n = 0, 0
        for i = 2, #recs do
            if recs[i].yaw and recs[i - 1].yaw then
                n = n + 1
                if math.abs(H.adiff(recs[i].yaw, recs[i - 1].yaw) - 36) < 0.6 then good = good + 1 end
            end
        end
        H.check("T-AA-10", n > 0 and good / n >= 0.9, "canli dusman yok: spin her tick 6 x 6 = 36 derece ilerler ("
            .. good .. "/" .. n .. ") [" .. H.yawlist(recs, 6) .. "]")
    end)
    H.run("T-AA-11", function()
        local function inst(conv, name)
            local T = H.boot({ name = name, rec_off = true, pre = function(T, W) W.sign_conv = conv; W.choke_fixed = 0 end })
            T.bset("Standing", "Body yaw", 2)
            T.tick(400)
            return T
        end
        local A = inst(1, "kalib-dogru")
        local B = inst(-1, "kalib-ters")
        local function last_sign(T)
            local r = T.recs(T.W.tick - 10, T.W.tick)
            return H.sgn(r[#r] and r[#r].desync)
        end
        local sa, sb = last_sign(A), last_sign(B)
        -- V1.0.8: oyundaki kural (deger + iken gercek-sahte farki eksi = sign_conv -1) varsayilan carpanla "uyumlu"
        -- olculur ve CEVRILMEZ; ters dunyada tam bir kez cevrilir. Eski olcum iki dunyada da "ters" diyordu.
        H.check("T-AA-11", B.count("uyumlu]") == 1 and B.count("ters, cevrildi]") == 0 and A.count("ters, cevrildi]") == 1
            and A.count("uyumlu]") == 0, "oyun kurali (sign_conv -1): 'uyumlu' " .. B.count("uyumlu]") .. " (1), cevrilme "
            .. B.count("ters, cevrildi]") .. " (0); ters kural: cevrilme " .. A.count("ters, cevrildi]") .. " (1)")
        H.check("T-AA-11", B.printed("desync isareti olculdu") ~= nil and sa ~= 0 and sb == -sa,
            "isaret kurali ters: 64 Standing ornegi sonra 'desync isareti olculdu' ve gonderilen isaret dogru kurala gore ters ("
            .. sa .. " / " .. sb .. "), boylece simule edilen gercek taraf ayni")
    end)
    H.run("T-AA-12", function()
        local T = H.boot({ name = "aa-12" })
        local W = T.W
        H.knife_enemy(W, 3, 200)
        T.tick(30)
        local f = H.frac(T.recs(W.tick - 20, W.tick), function(r) return r.yaw and H.adiff(r.yaw, 90) < 1 end)
        H.check("T-AA-12", f >= 0.5 and T.printed("backstab:") ~= nil, "200 birimde bicakli dusman: yaw = ona yaw (90) ("
            .. H.f1(f * 100) .. "%) ve 'backstab:' satiri")
    end)
    H.run("T-AA-13", function()
        local function inst(seen, mx, name)
            local T = H.boot({ name = name })
            local W, p = T.W, T.W.p[1]
            p.duck = 1.0; p.ducking = true; p.vel = V.v3(mx > 0 and 30 or -30, 0, 0)
            W.buttons.DUCK = true
            W.buttons[mx > 0 and "FORWARD" or "BACK"] = true
            W.move = { x = mx, y = 0 }
            if seen then W.sees[2] = 60 end
            T.tick(40)
            local m = T.moves[W.tick] or { x = 0, y = 0 }
            return math.sqrt(m.x * m.x + m.y * m.y)
        end
        local a = inst(true, 450, "keeper-gor")
        local b = inst(false, 450, "keeper-gorme")
        local c = inst(true, -450, "keeper-geri")
        H.check("T-AA-13", math.abs(a - 38 / 0.34) < 1.5 and math.abs(b - 450) < 0.5 and math.abs(c - 450) < 0.5,
            "egik + goruluyor + tehdide dogru 450: move " .. H.f1(a) .. " (beklenen 111.8 = 38/0.34); gorulmuyor "
            .. H.f1(b) .. " (450); geri giderken " .. H.f1(c) .. " (450)")
    end)
    H.run("T-AA-14", function()
        local T = H.boot({ name = "aa-14" })
        local W = T.W
        W.keys.ext = true
        T.tick(200)
        local n = T.count("UYARI: Extended Angles acik (roll yasak) -> kapat")
        local roll = T.has_text(W.tick - 5, W.tick, "ROLL!", function(x) return x.x < 300 end)
        H.check("T-AA-14", n == 1 and roll and T.natv("antiaim/main/extended angles/enable while moving") == false,
            "native Extended Angles tusu acik: uyari bir kez (" .. n .. "), sol listede 'ROLL!' (" .. tostring(roll)
            .. "), 'Enable While Moving' false tutulur")
    end)
    H.run("T-AA-15", function()
        local function peek_inst(exposed, name)
            local T = H.boot({ name = name })
            local W = T.W
            W.keys.fs = true; W.keys.autopeek = true; W.autopeek_pos = V.v3(0, 0, 0)
            W.p[1].vel = V.v3(100, 0, 0); W.buttons.FORWARD = true; W.move = { x = 450, y = 0 }
            if exposed then W.sees[2] = 60 end
            T.tick(40)
            return T, T.recs(W.tick - 20, W.tick), T.probe_state()
        end
        local A, ra, sa = peek_inst(true, "oncelik-peek")
        local okA, whyA = H.yaws_ok(ra, { 160, -135 }, true)
        H.check("T-AA-15", okA and sa == "Peek", "FS tusu + autopeek + hareket + kafa acik -> Peek (-20/+45), set_yaw var;"
            .. " durum '" .. tostring(sa) .. "'; " .. whyA)
        local B, rb, sb = peek_inst(false, "oncelik-fs")
        local f = H.frac(rb, function(r) return r.yaw == nil end)
        H.check("T-AA-15", f == 1 and sb == "Freestanding", "ayni, kafa gizli -> Freestanding, set_yaw yok (" .. H.f1(f * 100)
            .. "%), durum '" .. tostring(sb) .. "'")
        local Cn = H.boot({ name = "oncelik-manual" })
        local p = Cn.W.p[1]
        Cn.W.manual = 1; p.weapon = H.weapon("knife"); p.ground = false; p.duck = 1; p.ducking = true
        Cn.tick(30)
        local okC, whyC = H.yaws_ok(Cn.recs(Cn.W.tick - 15, Cn.W.tick), { 90 }, true)
        H.check("T-AA-15", okC, "Manual, Safe head'den once gelir: " .. whyC)
        local D = H.boot({ name = "oncelik-hava-fd" })
        D.W.p[1].ground = false; D.W.keys.fd = true
        D.tick(40)
        local rD = D.recs(D.W.tick - 25, D.W.tick)
        local okD, whyD = H.yaws_ok(rD, { 167, -146, 165, -136 }, false)
        local airR = H.any(rD, function(r) return r.yaw and (H.adiff(r.yaw, -146) < 0.6 or H.adiff(r.yaw, -136) < 0.6) end)
        H.check("T-AA-15", okD and airR, "Air (fake duck egik sayilir: Air crouch), Fake duck'tan once gelir: " .. whyD)
        local E = H.boot({ name = "oncelik-esik" })
        E.W.p[1].vel = V.v3(7, 0, 0)
        E.tick(40)
        local okE1, whyE1 = H.yaws_ok(E.recs(E.W.tick - 25, E.W.tick), { 157, -129 }, true)
        E.W.p[1].vel = V.v3(100, 0, 0)
        E.tick(20)
        E.W.p[1].vel = V.v3(7, 0, 0)
        E.tick(40)
        local okE2, whyE2 = H.yaws_ok(E.recs(E.W.tick - 25, E.W.tick), { 160, -130 }, true)
        H.check("T-AA-15", okE1 and okE2, "hiz 7: Standing'den gelince Standing (giris 10), Moving'den gelince Moving"
            .. " (cikis 5): " .. whyE1 .. " / " .. whyE2)
    end)
    H.run("T-AA-16", function()
        local function inst(name, pre)
            local T = H.boot({ name = name, rec_off = true, pre = pre })
            T.bset("Standing", "Delay randomize", 0)
            T.bset("Standing", "Jitter delay", 1)
            T.tick(300)
            return T
        end
        local A = inst("jitter-gecikmeli", function(T, W) W.choke_fixed = 0; W.getter_lag = 1 end)
        local B = inst("jitter-getter-yok", function(T, W) W.choke_fixed = 0; W.getters_nil = true end)
        local function mapping(T)
            local m = {}
            for _, r in ipairs(T.recs(T.W.tick - 40, T.W.tick)) do
                if r.yaw and r.desync then m[H.adiff(r.yaw, 157) < 1 and "L" or "R"] = H.sgn(r.desync) end
            end
            return m
        end
        local ma, mb = mapping(A), mapping(B)
        H.check("T-AA-16", ma.L ~= nil and ma.L == mb.L and ma.R == mb.R and A.printed("desync isareti olculdu") == nil,
            "Jitter delay 1 + getter 1 paket geride: degisen taraf ornek sayilmaz, esleme degismez (L " .. tostring(ma.L)
            .. "/" .. tostring(mb.L) .. ")")
        local Cn = H.boot({ name = "isaret-takip-etmiyor", rec_off = true,
            pre = function(T, W) W.choke_fixed = 0; W.sign_ignore = true end })
        Cn.bset("Standing", "Body yaw", 2)
        Cn.tick(700)
        local _, li = Cn.printed("desync isareti tutarsiz")
        local inv = false
        for _, r in ipairs(Cn.aa) do if r.invert ~= nil then inv = true end end
        H.check("T-AA-16", li ~= nil and inv, "getter isareti izlemiyor (%20-80 uyum): 'desync isareti tutarsiz' ve"
            .. " ctx:set_invert_desync ikinci kanal olarak cagrilir")
    end)
    H.run("T-AA-17", function()
        -- Kapak duz izle (trace.line) olculur: tehdidin gozunden kafamin +-20 yanina; kati sahte trace.bullet bos
        -- havaya 0 dondurur, eski bullet yolu burada hicbir tarafi bulamazdi.
        local function blocker(side)
            return function(a, b)
                if a.x < 400 or math.abs(b.x) > 30 or b.z < 50 or math.abs(b.y) < 10 then return nil end
                if side == 0 then return 0.4 end
                if side > 0 and b.y < -10 then return 0.4 end
                if side < 0 and b.y > 10 then return 0.4 end
                return nil
            end
        end
        local function inst(side, name)
            local T = H.boot({ name = name })
            if side ~= nil then T.W.block_line = blocker(side) end
            T.tick(60)
            return T, T.recs(T.W.tick - 20, T.W.tick)
        end
        local A, ra = inst(1, "fsauto-arti")
        local okA, whyA = H.yaws_ok(ra, { -90 }, true)
        local B, rb = inst(-1, "fsauto-eksi")
        local okB, whyB = H.yaws_ok(rb, { 90 }, true)
        local Cn, rc = inst(0, "fsauto-iki-kapali")
        local okC, whyC = H.yaws_ok(rc, { 157, -129 }, true)
        local O, ro = inst(nil, "fsauto-iki-acik")
        local okO, whyO = H.yaws_ok(ro, { 157, -129 }, true)
        H.check("T-AA-17", okA and okB and okC and okO, "FS auto: kafa yalnizca +20 tarafindan gorunuyor -> kafa kapali"
            .. " tarafa (-90): " .. whyA .. "; ayna (+90): " .. whyB .. "; iki taraf kapali -> degisiklik yok: " .. whyC
            .. "; iki taraf acik -> degisiklik yok: " .. whyO)
        -- Bayat taraf: kapak kalkinca (kazanan yok) eski taraf kullanilmaz.
        local S = H.boot({ name = "fsauto-bayat" })
        S.W.block_line = blocker(1)
        S.tick(60)
        S.W.block_line = nil
        S.tick(40)
        local okS, whyS = H.yaws_ok(S.recs(S.W.tick - 20, S.W.tick), { 157, -129 }, true)
        H.check("T-AA-17", okS, "kapak kalkinca (iki taraf acik) A.cover silinir, eski -90 tarafi kalmaz: " .. whyS)
        local _ = { A, B, Cn, O }
    end)
    H.run("T-AA-18", function()
        local T = H.boot({ name = "aa-18" })
        local W = T.W
        W.buttons.USE = true
        W.view = { x = 10, y = 30 }
        T.tick(20)
        local f = H.frac(T.recs(W.tick - 10, W.tick), function(r)
            return r.pitch and math.abs(r.pitch - 10) < 0.5 and r.yaw and H.adiff(r.yaw, 30) < 0.5
        end)
        local U = H.boot({ name = "aa-18-c4" })
        U.W.buttons.USE = true
        U.W.view = { x = 10, y = 30 }
        U.W.ents_by_name.CPlantedC4 = { U.thing("CPlantedC4", 50, 0, 0) }
        U.tick(20)
        local g = H.frac(U.recs(U.W.tick - 10, U.W.tick), function(r) return r.pitch == 89 and r.yaw and H.adiff(r.yaw, 30) > 5 end)
        H.check("T-AA-18", f >= 0.9 and g >= 0.9, "USE basili: set_pitch(10), set_yaw(30) (" .. H.f1(f * 100)
            .. "%); 100 birimde CPlantedC4 -> legit AA yok (" .. H.f1(g * 100) .. "%)")
    end)
end

-------------------------------------------------------------------------------
-- Anti-brute
-------------------------------------------------------------------------------
function H.phases(T, since)
    local r = {}
    for i = since or 1, #T.prints do
        local n = T.prints[i]:match("anti%-brute: Alpha faz (%d+)")
        if n then r[#r + 1] = tonumber(n) end
    end
    return r
end
-- Uygulanan faz: her darbede 'iska: <durum> | faz <uygulanan>' (onceki darbenin sectigi faz).
function H.applied_phases(T, since)
    local r = {}
    for i = since or 1, #T.prints do
        local n = T.prints[i]:match("iska: [^|]*| faz (%d+)")
        if n then r[#r + 1] = tonumber(n) end
    end
    return r
end
function C.brute()
    H.run("T-BR-1", function()
        local T = H.boot({ name = "br-1" })
        T.set("phase_test", false)
        T.set("brute_log", true)
        T.tick(10)
        local m = T.mark(); T.impact(2, 30); T.tick(20)
        local a = T.count("anti-brute: Alpha", m)
        m = T.mark(); T.impact(2, 60); T.tick(20)
        local b = T.count("anti-brute: Alpha", m)
        m = T.mark(); T.impact(2, 30); T.impact(2, 25); T.tick(20)
        local c = T.count("anti-brute: Alpha", m)
        H.check("T-BR-1", a == 1 and b == 0 and c == 1, "kafadan 30 birim gecen mermi fazi ilerletir (" .. a
            .. "), 60 birim ilerletmez (" .. b .. "), ayni atici 0.1 sn icinde bir kez sayilir (" .. c .. ")")
    end)
    H.run("T-BR-2", function()
        local function inst(hg, name)
            local T = H.boot({ name = name })
            T.set("phase_test", false)
            T.tick(10)
            T.impact(2, 20)
            T.tick(1)
            T.hurt_me(2, hg, 60)
            T.tick(30)
            T.shutdown()
            return T
        end
        local A = inst(1, "br-2-kafa")
        local F = H.mem_lines(A, "F2")
        local head_ok = false
        for _, f in ipairs(F) do if tonumber(f[4]) == 1 and tonumber(f[5]) == 1 then head_ok = true end end
        local base_ok = false
        for _, p in ipairs(H.mem_lines(A, "P")) do
            if p[2] == "76561198000000002" and p[5] ~= nil and p[5] ~= "0" and p[5] ~= "" then base_ok = true end
        end
        H.check("T-BR-2", head_ok and base_ok, "darbe + kafa isabeti: uygulanan fazin istatistigi 1/1 (F satiri) ve dusmanin"
            .. " taban fazi ogrenildi (P alan 5 != 0) [" .. (A.file("nykle_memory.txt") or "dosya yok"):gsub("\n", " / "):sub(1, 160) .. "]")
        local B = inst(2, "br-2-govde")
        local F2 = H.mem_lines(B, "F2")
        local shots, hits = 0, 0
        for _, f in ipairs(F2) do shots = shots + (tonumber(f[4]) or 0); hits = hits + (tonumber(f[5]) or 0) end
        H.check("T-BR-2", shots >= 1 and hits == 0, "govde isabeti: sadece atis + 1 (" .. shots .. " atis, " .. hits .. " kafa)")
    end)
    H.run("T-BR-3", function()
        local T = H.boot({ name = "br-3" })
        T.tick(10)
        local m = T.mark()
        T.impact(2, 20)
        T.tick(15)
        local l = T.printed("iska:", m)
        H.check("T-BR-3", l ~= nil and l:find("faz", 1, true) ~= nil, "0.15 sn hasar gelmeyen darbe 'iska:' satiri (faz ile): "
            .. tostring(l))
    end)
    H.run("T-BR-4", function()
        local seed = "NYKLEMEM\t1\t5\nV\tphases\t2\n"
        for _, g in ipairs({ "still", "move", "peek", "air" }) do seed = seed .. "F2\t" .. g .. "\t1\t12\t7\n" end
        local function inst(random, name)
            local T = H.boot({ name = name, rec_off = true, files = { ["nykle_memory.txt"] = seed } })
            T.set("phase_test", false)
            T.set("brute_log", true)
            T.set("brute_random", random)
            T.tick(10)
            local m = T.mark()
            for _ = 1, 10 do T.impact(2, 20); T.tick(15) end
            return H.applied_phases(T, m), H.phases(T, m)
        end
        local a, la = inst(true, "br-4-rastgele")
        local b, lb = inst(false, "br-4-sirali")
        local bad = false
        for _, x in ipairs(a) do if x == 1 then bad = true end end
        for _, x in ipairs(b) do if x == 1 then bad = true end end
        H.check("T-BR-4", not bad and #a >= 8 and #b >= 8 and b[2] == 2,
            "bilinen kotu faz (12 atis 7 kafa) iki sirada da uygulanmaz (iska satirindaki uygulanan faz): rastgele ["
            .. table.concat(a, ",") .. "], sirali [" .. table.concat(b, ",") .. "] (0'dan sonra 2 olmali); log fazlari ["
            .. table.concat(la, ",") .. "] / [" .. table.concat(lb, ",") .. "]")
    end)
    -- V1.0.9 faz testi yardimcilari: hedef faz disindaki fazlara 5 round yazilan tohum (rotasyon en az round oynanan
    -- fazi secer), tick basina gonderim (choke 0) ile taraf dizisinin ayni tarafta kalma uzunluklari.
    local function phase_seed(target)
        local lines = { "V\tphases\t2" }
        for ph = 0, 4 do
            if ph ~= target then lines[#lines + 1] = "T\t" .. ph .. "\t1\t0\t0\t5" end
        end
        return H.mem2(lines)
    end
    local function phase_inst(target, name, setup)
        local T = H.boot({ name = name, rec_off = true, files = { ["nykle_memory.txt"] = phase_seed(target) },
            pre = function(T, W) W.choke_fixed = 0 end })
        if setup then setup(T, T.W) end
        T.tick(10)
        T.event("round_start", {})
        T.tick(10)
        return T
    end
    local function runs(T, t0, t1)
        local r, out, prev, len = T.recs(t0, t1), {}, nil, 0
        for _, x in ipairs(r) do
            local sg = H.sgn(x.desync)
            if sg ~= 0 then
                if sg == prev then len = len + 1 else
                    if prev ~= nil then out[#out + 1] = len end
                    prev, len = sg, 1
                end
            end
        end
        return out
    end
    H.run("T-BR-6", function()
        -- Esit rotasyon: 10 round -> her faz 2 round; round icinde faz sabit (mermiler fazi ilerletmez).
        local T = H.boot({ name = "br-6-rotasyon" })
        T.tick(10)
        local seen = {}
        for i = 1, 10 do
            local m = T.mark()
            T.event("round_start", {})
            T.tick(70)
            local l = T.printed("faz testi: bu round ", m) or ""
            local nm = l:match("bu round ([%w%+%-]+) %(")
            seen[nm or "?"] = (seen[nm or "?"] or 0) + 1
            local m2 = T.mark()
            T.impact(2, 20); T.tick(15); T.impact(2, 20); T.tick(15)
            local ph = H.applied_phases(T, m2)
            if #ph == 2 and ph[1] ~= ph[2] then seen.changed = true end
        end
        local even = true
        for _, nm in ipairs({ "normal", "asym", "rnd-asym", "asym+duvar", "atis-sonrasi" }) do
            if seen[nm] ~= 2 then even = false end
        end
        H.check("T-BR-6", even and not seen.changed, "10 round: her faz 2 round (normal " .. tostring(seen.normal) .. ", asym "
            .. tostring(seen.asym) .. ", rnd-asym " .. tostring(seen["rnd-asym"]) .. ", asym+duvar " .. tostring(seen["asym+duvar"])
            .. ", atis-sonrasi " .. tostring(seen["atis-sonrasi"]) .. "), round icinde faz degismez (" .. tostring(not seen.changed) .. ")")
    end)
    H.run("T-BR-7", function()
        -- Sayim ve hafiza: faz 2 roundunda 2 iska + 1 kafa + 1 govde -> T kaydi 2: n 4+1 (tohum yok), h 1, isabet 2.
        local T = phase_inst(2, "br-7-sayim")
        T.impact(2, 20); T.tick(15)
        T.impact(2, 20); T.tick(15)
        T.impact(2, 20); T.tick(1); T.hurt_me(2, 2, 30); T.tick(15)
        T.impact(2, 20); T.tick(1); T.hurt_me(2, 1, 30); T.tick(15)
        local m = T.mark()
        T.shutdown()
        local rec = nil
        for _, f in ipairs(H.mem_lines(T, "T")) do if f[2] == "2" then rec = f end end
        local line = T.printed("faz karsilastirma: ", m) or ""
        H.check("T-BR-7", rec ~= nil and rec[3] == "4" and rec[4] == "1" and rec[5] == "2" and rec[6] == "1"
            and line:find("rnd-asym 4 mermi kafa %25 iska %50 (1 round)", 1, true) ~= nil, "faz 2 roundu: 2 iska + govde + kafa -> T kaydi "
            .. (rec and table.concat(rec, ",") or "yok") .. " (T,2,4,1,2,1); kapanista: " .. line:sub(1, 200))
    end)
    H.run("T-BR-8", function()
        -- Taraf sureleri (Standing, Jitter, gecikme 1, her tick gonderim).
        local plain = function(T) T.bset("Standing", "Jitter delay", 1); T.bset("Standing", "Delay randomize", 0) end
        local A = phase_inst(1, "br-8-asym", plain)
        local t0 = A.W.tick; A.tick(200)
        local ra = runs(A, t0, A.W.tick)
        -- Tek tuk sapma (sayim penceresinin kenari) haric: en fazla 2 aykiri sure.
        local a_bad, a3 = 0, 0
        for _, n in ipairs(ra) do if n ~= 1 and n ~= 3 then a_bad = a_bad + 1 end; if n == 3 then a3 = a3 + 1 end end
        local a_ok = #ra > 20 and a_bad <= 2
        local B = phase_inst(2, "br-8-rnd", plain)
        t0 = B.W.tick; B.tick(300)
        local rb = runs(B, t0, B.W.tick)
        local b_bad, kinds = 0, {}
        for _, n in ipairs(rb) do if n < 1 or n > 4 then b_bad = b_bad + 1 else kinds[n] = true end end
        local b_ok = #rb > 20 and b_bad <= 2
        local nk = 0
        for _ in pairs(kinds) do nk = nk + 1 end
        local N0 = phase_inst(0, "br-8-normal", plain)
        t0 = N0.W.tick; N0.tick(100)
        local rn = runs(N0, t0, N0.W.tick)
        local n_ok = #rn > 20
        for _, n in ipairs(rn) do if n ~= 1 then n_ok = false end end
        H.check("T-BR-8", a_ok and a3 >= 5 and b_ok and nk >= 3 and n_ok, "asym: sureler 1 ya da 3 paket (" .. tostring(a_ok) .. ", 3'luk "
            .. a3 .. "); rnd-asym: 1-4 arasi, en az 3 farkli sure (" .. tostring(b_ok) .. ", " .. nk .. "); normal: hep 1 ("
            .. tostring(n_ok) .. ") [" .. table.concat(ra, ",", 1, math.min(#ra, 12)) .. " | " .. table.concat(rb, ",", 1, math.min(#rb, 12)) .. "]")
    end)
    H.run("T-BR-9", function()
        -- atis-sonrasi: gecikme 8 paket (taraf uzun tutulur); mermi yanimdan gecince 2 tick icinde taraf cevrilir.
        local function flips(target, name)
            local T = phase_inst(target, name, function(T) T.bset("Standing", "Jitter delay", 8) end)
            local n = 0
            for _ = 1, 8 do
                T.tick(23)
                local r0 = T.recs(T.W.tick - 1, T.W.tick)
                local s0 = H.sgn(r0[#r0] and r0[#r0].desync)
                T.impact(2, 20)
                T.tick(2)
                local r1 = T.recs(T.W.tick, T.W.tick)
                if H.sgn(r1[#r1] and r1[#r1].desync) == -s0 and s0 ~= 0 then n = n + 1 end
            end
            return n
        end
        local k, a = flips(4, "br-9-atis"), flips(1, "br-9-asym")
        H.check("T-BR-9", k >= 7 and a <= 4, "atis-sonrasi: 8 mermiden " .. k .. " tanesinde 2 tick icinde taraf cevrildi (>= 7); asym"
            .. " (kontrol): " .. a .. " (<= 4)")
    end)
    H.run("T-BR-5", function()
        local function inst(name, setup)
            local T = H.boot({ name = name, rec_off = true })
            T.set("phase_test", false)
            T.set("brute_random", false)
            setup(T, T.W)
            T.tick(30)
            local before = T.recs(T.W.tick - 10, T.W.tick)
            local t0 = T.W.tick
            T.impact(2, 20)
            T.tick(10)
            T.impact(2, 20)
            T.tick(25)
            -- faz 1 (ters) [t0+2, t0+9]; faz 2 (+15 kaydirma) [t0+13, son]
            return before, T.recs(t0 + 2, t0 + 9), T.recs(t0 + 13, T.W.tick), T
        end
        local b1, a1, c1 = inst("br-5-manual", function(T, W) W.manual = 1 end)
        local sgn0 = H.sgn(b1[#b1] and b1[#b1].desync)
        local okM = H.yaws_ok(a1, { 90 }, true) and H.yaws_ok(c1, { 90 }, true)
            and H.frac(a1, function(r) return H.sgn(r.desync) == sgn0 end) == 1 and sgn0 ~= 0
        local b2, a2, c2 = inst("br-5-kontrol", function(T, W) T.bset("Standing", "Body yaw", 2) end)
        local s0 = H.sgn(b2[#b2] and b2[#b2].desync)
        local flipped = H.frac(a2, function(r) return H.sgn(r.desync) == -s0 end) >= 0.75
        local _, _, a3 = inst("br-5-safehead", function(T, W)
            local p = W.p[1]
            p.weapon = H.weapon("knife"); p.ground = false; p.duck = 1; p.ducking = true
        end)
        local okS = H.yaws_ok(a3, { 180 }, true)
        -- V1.0.9: yeni faz seti taraf suresiyle oynar (Static'te isareti cevirmez); eski "faz 1 ters" kontrolu kalkti.
        H.check("T-BR-5", okM and okS and flipped ~= nil, "Manual / Safe head'de faz uygulanmaz (Manual yaw 90 ve desync isareti ayni: "
            .. tostring(okM) .. "; Safe head yaw 180: " .. tostring(okS) .. ")")
    end)
end

-------------------------------------------------------------------------------
-- Exploit / defensive
-------------------------------------------------------------------------------
function H.max_per_tick(T, t0, t1)
    local m = 0
    for t = t0, t1 do if (T.shift[t] or 0) > m then m = T.shift[t] end end
    return m
end
function H.jump_hit(T, delay, extra)
    local W = T.W
    W.sees[2] = 60
    W.charge = W.max_charge
    local u0 = #T.unch
    T.jump(300)
    local tp = nil
    for _ = 1, 200 do
        T.tick(1)
        if tp == nil and #T.unch > u0 then tp = W.tick end
        if tp and extra then extra(T, W, W.tick - tp) end
        if tp and delay and W.tick == tp + delay then T.hurt_me(2, 2, 30) end
        if W.p[1].ground then break end
    end
    T.tick(30)
    return tp
end
function C.exploits()
    H.run("T-EX-1", function()
        -- Eski yol (def_edge kapali): goruluyorken sarj dolu olan her tick.
        local T = H.boot({ name = "ex-1", rec_off = true, setup = H.edge_off })
        local W = T.W
        W.sees[2] = 60
        T.tick(70)
        local ticks = T.shifts(W.tick - 59, W.tick)
        local mx = H.max_per_tick(T, W.tick - 59, W.tick)
        H.check("T-EX-1", ticks >= 45 and mx == 1, "def_edge kapali: Smart + goruluyor + DT dolu: force_anti_exploit_shift "
            .. ticks .. "/60 tick, tick basina en fazla 1 (" .. mx .. ")")
        -- Varsayilan (V1.0.5, def_edge acik): ayni sahne -> tek zorlama, gorusten sonraki ilk 4 tick icinde.
        local E = H.boot({ name = "ex-1-olay" })
        local e0 = E.W.tick
        E.W.sees[2] = 60
        E.tick(70)
        local en = H.shift_all(E)
        local _, early = E.shifts(e0 + 1, e0 + 4)
        H.check("T-EX-1", en == 1 and early == 1, "varsayilan (olay basina bir): Smart + goruluyor + DT dolu, 70 tick -> "
            .. en .. " zorlama (1), ilk 4 tick'te " .. early)
        for _, edge in ipairs({ true, false }) do
            local U = H.boot({ name = "ex-1-dolmamis-" .. tostring(edge), rec_off = true,
                setup = function(T) if not edge then H.edge_off(T) end end })
            U.W.sees[2] = 60; U.W.auto_recharge = false; U.W.charge = 5
            U.tick(40)
            local t2 = edge and H.shift_all(U) or U.shifts(U.W.tick - 30, U.W.tick)
            H.check("T-EX-1", t2 == 0, "DT dolu degil (def_edge " .. tostring(edge) .. "): hic tetik yok (" .. t2 .. ")")
        end
    end)
    H.run("T-EX-2", function()
        local T = H.boot({ name = "ex-2", rec_off = true, setup = H.edge_off })
        local W = T.W
        W.sees[2] = 60; W.can_fire = true; W.head_dmg[2] = 120
        T.tick(40)
        local sh = T.shifts(W.tick - 30, W.tick)
        local fl = H.frac(T.recs(W.tick - 30, W.tick), function(r) return r.fakelag == false end)
        H.check("T-EX-2", sh == 0 and fl >= 0.5, "def_edge kapali: temiz atis (ates edebilir, kafa 120 >= gereken 100): tetik"
            .. " yok (" .. sh .. "), set_fakelag(false) (" .. H.f1(fl * 100) .. "%)")
        -- Varsayilan (def_edge acik): ilk gorus olayi temiz atisa denk gelir -> hic zorlama yok (temiz degilken 1: T-EX-1).
        local Tn = H.boot({ name = "ex-2-olay" })
        Tn.W.sees[2] = 60; Tn.W.can_fire = true; Tn.W.head_dmg[2] = 120
        Tn.tick(40)
        local tn = H.shift_all(Tn)
        local fn = H.frac(Tn.recs(Tn.W.tick - 30, Tn.W.tick), function(r) return r.fakelag == false end)
        H.check("T-EX-2", tn == 0 and fn >= 0.5, "varsayilan: temiz atista ilk gorus olayi da zorlamaz (" .. tn
            .. "), set_fakelag(false) (" .. H.f1(fn * 100) .. "%)")
        local U = H.boot({ name = "ex-2-sonra", rec_off = true, setup = H.edge_off })
        local W2 = U.W
        W2.sees[2] = 60; W2.head_dmg[2] = 50
        U.tick(70)
        local t = W2.tick
        local id = U.shoot(2)
        U.tick(40)
        local hold = U.shifts(t + 1, t + 6)
        local after = U.shifts(t + 12, t + 40)
        H.check("T-EX-2", hold == 0 and after >= 5, "def_edge kapali: atistan sonra 6 tick temiz tutulur (" .. hold
            .. " tetik), sonra Smart devam eder (" .. after .. ")")
        -- Varsayilan: atistan once tek zorlama (ilk gorus); atistan sonra gorulme surerken yeni olay yok -> 0.
        local Un = H.boot({ name = "ex-2-sonra-olay" })
        Un.W.sees[2] = 60; Un.W.head_dmg[2] = 50
        Un.tick(70)
        local tu = Un.W.tick
        local before = H.shift_all(Un)
        Un.shoot(2)
        Un.tick(40)
        local _, late = Un.shifts(tu + 1, tu + 40)
        H.check("T-EX-2", before == 1 and late == 0, "varsayilan: atistan once " .. before .. " zorlama (1), atistan sonraki 40"
            .. " tick'te gorulme surerken tekrar yok (" .. late .. ")")
        local function hid(clean, name)
            local X = H.boot({ name = name })
            local W3 = X.W
            W3.p[1].vel = V.v3(100, 0, 0)
            if clean then W3.can_fire = true; W3.head_dmg[2] = 120 end
            X.tick(40)
            local t0 = W3.tick
            W3.p[1].sim_shift = 12
            X.tick(14)
            return H.frac(X.recs(t0 + 2, t0 + 9), function(r) return r.pitch == -89 end)
        end
        local fc = hid(true, "ex-2-gizli-temiz")
        local fu = hid(false, "ex-2-gizli-kontrol")
        H.check("T-EX-2", fc == 0 and fu >= 0.75, "temiz atista gizli aci yok (Moving gizli pitch Up: temiz " .. H.f1(fc * 100)
            .. "%, kontrol " .. H.f1(fu * 100) .. "%)")
        local _ = id
    end)
    H.run("T-EX-3", function()
        local function inst(name, first_sight, edge)
            local T = H.boot({ name = name, rec_off = true, setup = function(T) if not edge then H.edge_off(T) end end })
            local W = T.W
            W.sees[2] = 60
            T.tick(70)
            local t0 = W.tick
            W.p[1].sim_shift = 10
            for i = 1, 140 do
                T.tick(1)
                if first_sight and W.tick == t0 + 20 then W.sees[3] = 60 end
            end
            return T, t0
        end
        local T, t0 = inst("ex-3")
        local quiet = T.shifts(t0 + 14, t0 + 60)
        local back = T.shifts(t0 + 85, t0 + 130)
        H.check("T-EX-3", quiet == 0 and back >= 5, "def_edge kapali: kendi defensive'imiz goruluyorken bitti: 1 sn yeniden"
            .. " tetik yok (" .. quiet .. "), sonra devam (" .. back .. ")")
        local U, u0 = inst("ex-3-ilk-gorus", true)
        local fs = U.shifts(u0 + 20, u0 + 28)
        H.check("T-EX-3", fs >= 1, "def_edge kapali: bekleme sirasinda yeni dusmanin ilk gorusu bekleme suresini deler (" .. fs
            .. " tetik)")
        -- Varsayilan (def_edge acik): gorulme surerken yeni olay yok -> bekleme bitse de tekrar yok; bekleme sirasinda
        -- yeni dusmanin ilk gorusu yeni olaydir (peek, GAP 48 dolmus) -> tam 1.
        local Tn, n0 = inst("ex-3-olay", false, true)
        local _, nq = Tn.shifts(n0 + 1, n0 + 140)
        local Un, m0 = inst("ex-3-ilk-gorus-olay", true, true)
        local _, nf = Un.shifts(m0 + 20, m0 + 28)
        local _, nrest = Un.shifts(m0 + 29, m0 + 140)
        H.check("T-EX-3", nq == 0 and nf == 1 and nrest == 0, "varsayilan: kendi defensive'imiz bittikten sonra 140 tick"
            .. " gorulme surer -> " .. nq .. " zorlama (0); yeni dusmanin ilk gorusu -> " .. nf .. " (1), sonrasi " .. nrest)
    end)
    H.run("T-EX-4", function()
        local function inst(name, edge)
            local T = H.boot({ name = name, rec_off = true, setup = function(T) if not edge then H.edge_off(T) end end })
            local W = T.W
            T.xset("Standing", "Defensive", 2)
            T.tick(70)
            local base = T.shifts(W.tick - 50, W.tick)
            local t0 = W.tick
            W.sees[2] = 60
            T.tick(50)
            local a = T.shifts(t0, t0 + 12)
            local b = T.shifts(t0 + 16, t0 + 50)
            -- kisa bosluk (10 tick) yeni ilk gorus sayilmaz; uzun bosluk (60 tick, > 24) sayilir
            W.sees[2] = 0
            T.tick(10)
            local t1 = W.tick
            W.sees[2] = 60
            T.tick(20)
            local short = T.shifts(t1, t1 + 20)
            W.sees[2] = 0
            T.tick(60)
            local t2 = W.tick
            W.sees[2] = 60
            T.tick(20)
            local long = T.shifts(t2, t2 + 12)
            return base, a, b, short, long
        end
        local base, a, b, short, long = inst("ex-4", false)
        H.check("T-EX-4", base == 0 and a >= 4 and b == 0, "def_edge kapali: On peek: ilk gorus (bosluk > 24 tick) 8 tick"
            .. " tetikler (" .. a .. "), oncesi " .. base .. ", sonrasi " .. b)
        H.check("T-EX-4", short == 0 and long >= 4, "def_edge kapali: gorus 10 tick kesilip donunce tetik yok (" .. short
            .. "), 60 tick (> 24) kesilip donunce yine 8 tick (" .. long .. ")")
        -- Varsayilan (def_edge acik): ilk gorus bir olaydir -> 8 tick degil tek zorlama.
        local nb, na, nb2, ns, nl = inst("ex-4-olay", true)
        H.check("T-EX-4", nb == 0 and na == 1 and nb2 == 0 and ns == 0 and nl == 1, "varsayilan: On peek ilk gorus tek"
            .. " zorlama (" .. na .. "), oncesi " .. nb .. ", sonrasi " .. nb2 .. "; 10 tick kesilip donunce " .. ns
            .. " (0), 60 tick kesilip donunce " .. nl .. " (1)")
    end)
    H.run("T-EX-5", function()
        local T = H.boot({ name = "ex-5" })
        local W = T.W
        W.p[1].ground = false
        T.tick(30)
        local t0 = W.tick
        W.p[1].sim_shift = 12
        T.tick(25)
        local win = T.recs(t0 + 2, t0 + 9)
        local fp = H.frac(win, function(r) return r.pitch == -89 end)
        local distinct, prev, changes = {}, nil, 0
        for _, r in ipairs(win) do
            if r.yaw then
                if prev ~= nil and H.adiff(r.yaw, prev) > 0.5 then changes = changes + 1 end
                prev = r.yaw
            end
        end
        local outside = H.frac(T.recs(t0 + 16, t0 + 25), function(r) return r.pitch == 89 end)
        local before = H.frac(T.recs(t0 - 10, t0), function(r) return r.pitch == 89 end)
        H.check("T-EX-5", fp == 1 and changes >= 5 and outside == 1 and before == 1,
            "Air: kendi sim zamanimiz geri gidince gizli pitch -89 (Up) " .. H.f1(fp * 100) .. "% ve Spin yaw (" .. changes
            .. " degisim); disarida pitch 89 (" .. H.f1(outside * 100) .. "% / " .. H.f1(before * 100) .. "%)")
    end)
    H.run("T-EX-6", function()
        local function inst(name, setup)
            local T = H.boot({ name = name })
            local W = T.W
            W.sees[2] = 60; W.head_dmg[2] = 50
            if setup then setup(T, W) end
            T.tick(70)
            local t = W.tick
            T.shoot(2)
            T.tick(3)
            local b3 = W.rc_blocked
            local blk = T.calls_in(T.blk, t, t + 3)
            T.tick(40)
            return T, b3, blk, W.rc_blocked
        end
        local A, b3, _, b40 = inst("ex-6")
        H.check("T-EX-6", b3 == true and b40 == false, "goruluyorken Standing atis: block_recharge (" .. tostring(b3)
            .. "), 0.5 sn sonra birakilir (" .. tostring(not b40) .. ")")
        local _, _, pb = inst("ex-6-peek", function(T, W)
            W.keys.autopeek = true; W.autopeek_pos = V.v3(0, 0, 0); W.p[1].vel = V.v3(100, 0, 0)
            W.buttons.FORWARD = true; W.move = { x = 450, y = 0 }
        end)
        local _, _, fb = inst("ex-6-hizli", function(T, W)
            W.p[1].vel = V.v3(150, 0, 0); W.buttons.FORWARD = true; W.move = { x = 450, y = 0 }
        end)
        local Z, _, zb = inst("ex-6-zeus", function(T, W)
            W.p[3].weapon = H.weapon("taser"); W.p[3].origin = V.v3(0, 400, 0)
        end)
        H.check("T-EX-6", pb == 0 and fb == 0 and zb == 0 and Z.printed("sarj bekleme yok: zeus yakin") ~= nil,
            "Peek'te (" .. pb .. "), 150 u/s'de (" .. fb .. ") ve 400 birimde zeus varken (" .. zb
            .. ") kilit yok; 'sarj bekleme yok: zeus yakin' satiri")
        local _ = A
    end)
    H.run("T-EX-7", function()
        local function inst(name, setup)
            local T = H.boot({ name = name, setup = function(T) T.set("air_lc", false) end })
            if setup then setup(T, T.W) end
            T.tick(40)
            return T
        end
        local T = inst("ex-7")
        local W = T.W
        local m = T.mark()
        local u0 = #T.unch
        local tp, land = H.seen_jump(T, 300)
        T.tick(3)
        local n = #T.unch - u0
        local blk_ok = tp ~= nil and T.calls_in(T.blk, tp, land - 1) >= (land - tp - 2)
        local allow_ok = tp ~= nil and not W.rc_blocked and T.calls_in(T.alw, land, land + 3) >= 1
        H.check("T-EX-7", n == 1 and T.count("teleport: havada goruldun", m) == 1 and blk_ok and allow_ok,
            "goruldu + DT dolu + inise 0.75 sn: force_uncharge " .. n .. " kez, 'teleport: havada goruldun' 1, inise kadar"
            .. " kilit (" .. tostring(blk_ok) .. "), iniste allow (" .. tostring(allow_ok) .. ")")
        local L = inst("ex-7-gec")
        local Lw = L.W
        local lu0 = #L.unch
        L.jump(300)
        local t0 = Lw.tick
        for _ = 1, 200 do
            L.tick(1, function(T, W) if W.tick >= t0 + 30 then W.sees[2] = 60 end end)
            if Lw.p[1].ground then break end
        end
        local ln = #L.unch - lu0
        local Cn = inst("ex-7-temiz", function(T, W) W.can_fire = true; W.head_dmg[2] = 120 end)
        local cu0 = #Cn.unch
        H.seen_jump(Cn, 300)
        local cn = #Cn.unch - cu0
        H.check("T-EX-7", ln == 0 and cn == 0, "inise < 0.35 sn kala gorulme -> teleport yok (" .. ln .. "); temiz atis ->"
            .. " teleport yok (" .. cn .. ")")
        local Pp = inst("ex-7-kismi", function(T, W) W.uncharge_partial = 5 end)
        local pm = Pp.mark()
        local pu0 = #Pp.unch
        H.seen_jump(Pp, 300)
        local calls = {}
        for i = pu0 + 1, #Pp.unch do calls[#calls + 1] = Pp.unch[i] end
        local consecutive = true
        for i = 2, #calls do if calls[i] ~= calls[i - 1] + 1 then consecutive = false end end
        H.check("T-EX-7", #calls >= 2 and #calls <= 4 and consecutive and Pp.count("teleport: havada goruldun", pm) == 1,
            "tek cagri sarji bosaltmazsa ardisik tick'lerde tekrar (" .. #calls .. " cagri, <= 4), tek teleport satiri")
    end)
    H.run("T-EX-8", function()
        -- Eski yol (Teleport in air kapali, Air LC acik): V1.0.79 aynen. Ikisi aciksa T-EX-13.
        local T = H.boot({ name = "ex-8", rec_off = true, setup = function(T) T.set("air_teleport", false) end })
        local W = T.W
        T.tick(40)
        local u0 = #T.unch
        local tp, land = H.seen_jump(T, 300)
        T.tick(3)
        local n = #T.unch - u0
        local fl, blk = 0, true
        if tp then
            fl = H.frac(T.recs(tp + 1, land - 1), function(r) return r.fakelag == true end)
            for t = tp + 1, land - 1 do if (T.blk[t] or 0) < 1 then blk = false end end
        end
        H.check("T-EX-8", tp ~= nil and n == 1 and fl >= 0.9 and blk and not W.rc_blocked,
            "havada goruldu: uncharge " .. n .. " kez, inise kadar her tick kilit (" .. tostring(blk) .. ") ve set_fakelag(true) ("
            .. H.f1(fl * 100) .. "%), iniste birakilir")
        local function unseen(name, edge)
            local U = H.boot({ name = name, rec_off = true, setup = function(T)
                T.set("air_teleport", false)
                if not edge then H.edge_off(T) end
            end })
            U.tick(40)
            local uu0 = #U.unch
            local ta = U.W.tick
            local g0 = H.shift_all(U)
            U.jump(300)
            for _ = 1, 200 do
                U.tick(1)
                if U.W.p[1].ground then break end
            end
            local sh, calls = U.shifts(ta + 2, U.W.tick - 1)
            local _, first = U.shifts(ta + 1, ta + 2)
            return #U.unch - uu0, U.W.tick - ta - 1, sh, calls, first, g0
        end
        local un, air_ticks, sh = unseen("ex-8-gorulmedi", false)
        H.check("T-EX-8", un == 0 and sh >= air_ticks * 0.5, "def_edge kapali: havada gorulmedi: uncharge yok (" .. un
            .. "), bunun yerine air lag defensive (" .. sh .. "/" .. air_ticks .. " tick)")
        -- Varsayilan (def_edge acik): air lag ucus basina bir kez, havadaki ilk tick'lerde; yerde "yakin" tetiklemez.
        local en, eair, _, _, efirst, eg0 = unseen("ex-8-gorulmedi-olay", true)
        local E2 = H.boot({ name = "ex-8-iki-ucus", rec_off = true, setup = function(T) T.set("air_teleport", false) end })
        E2.tick(40)
        for _ = 1, 2 do
            E2.jump(300)
            for _ = 1, 200 do
                E2.tick(1)
                if E2.W.p[1].ground then break end
            end
            E2.tick(10)
        end
        local two = H.shift_all(E2)
        H.check("T-EX-8", en == 0 and eg0 == 0 and efirst == 1 and two == 2, "varsayilan: havada gorulmedi: uncharge yok ("
            .. en .. "), yerde (yakin, gorulmuyor) " .. eg0 .. " zorlama (0), ucusta (" .. eair .. " tick) air lag tek zorlama,"
            .. " ilk 2 tick'te (" .. efirst .. "); iki ucus -> " .. two .. " (2)")
    end)
    H.run("T-EX-9", function()
        local T = H.boot({ name = "ex-9", setup = function(T) T.set("air_lc", false) end })
        T.tick(40)
        local m = T.mark()
        local a = H.jump_hit(T, 20)
        local b = H.jump_hit(T, 20)
        local off = T.printed("bu harita boyunca havada teleport kapali", m) ~= nil
        local c = H.jump_hit(T, nil)
        T.event("game_newmap", { mapname = "de_nuke" })
        T.W.map = "de_nuke"
        T.tick(10)
        local d = H.jump_hit(T, nil)
        H.check("T-EX-9", a and b and off and c == nil and d ~= nil, "3 teleportun 2'si 0.12-1.5 sn icinde vuruldu: harita"
            .. " boyunca kapali (satir " .. tostring(off) .. ", 3. ziplama " .. tostring(c) .. "), game_newmap ile acilir ("
            .. tostring(d) .. ")")
        local U = H.boot({ name = "ex-9-erken", setup = function(T) T.set("air_lc", false) end })
        U.tick(40)
        -- ziplamalar arasi > 1.5 sn: erken isabet onceki teleportun penceresine de dusmesin
        local x1 = H.jump_hit(U, 3); U.tick(70)
        local x2 = H.jump_hit(U, 3); U.tick(70)
        local x3 = H.jump_hit(U, 3); U.tick(70)
        local x4 = H.jump_hit(U, nil)
        H.check("T-EX-9", x1 and x2 and x3 and x4, "0.05 sn'de gelen isabet sayilmaz (4 ziplamanin hepsinde teleport)")
    end)
    H.run("T-EX-10", function()
        local T = H.boot({ name = "ex-10", setup = function(T) T.set("air_lc", false) end })
        local W = T.W
        W.head_dmg[2] = 50
        T.tick(40)
        local m = T.mark()
        local ids = {}
        local function shooter(T, W, dt)
            if dt == 1 then ids[#ids + 1] = T.shoot(2) end
            if dt == 3 then T.miss(ids[#ids], "server rejection") end
        end
        local a = H.jump_hit(T, nil, shooter)
        local b = H.jump_hit(T, nil, shooter)
        local line = T.printed("10 sn durduruldu", m)
        local c = H.jump_hit(T, nil)
        H.check("T-EX-10", a and b and line ~= nil and c == nil, "TP sirasinda 2 'server rejection' (10 sn icinde): teleport 10 sn"
            .. " durur (" .. tostring(line) .. "; 3. ziplama " .. tostring(c) .. ")")
    end)
    H.run("T-EX-11", function()
        local T = H.boot({ name = "ex-11", rec_off = true })
        local W = T.W
        T.xset("Standing", "Defensive", 2)
        W.sees[2] = 60
        T.tick(70)
        local base = T.shifts(W.tick - 40, W.tick)
        local t1 = W.tick
        W.p[1].weapon = H.weapon("deagle")
        W.p[1].next_attack = T.now() + 0.5
        T.tick(40)
        local a = T.shifts(t1, t1 + 32)
        T.tick(60)
        local q = T.shifts(W.tick - 20, W.tick)
        local t2 = W.tick
        H.knife_enemy(W, 3, 200)
        T.tick(15)
        local b = T.shifts(t2, t2 + 15)
        H.check("T-EX-11", base == 0 and a >= 1 and q == 0 and b >= 1, "On peek: silah degisimi 0.5 sn icinde tetikler (" .. a
            .. "; oncesi " .. base .. "), 250 birimde CKnife tutan dusman tetikler (" .. b .. "; oncesi " .. q .. ")")
    end)
    H.run("T-EX-12", function()
        local T = H.boot({ name = "ex-12", rec_off = true, setup = function(T) T.set("air_teleport", false) end })
        T.tick(40)
        local a = H.jump_hit(T, 20)
        local b = H.jump_hit(T, 20)
        local m = T.mark()
        local u0 = #T.unch
        local t3 = T.W.tick
        local c = H.jump_hit(T, nil)
        local blk3 = T.calls_in(T.blk, t3, T.W.tick)
        local d = H.jump_hit(T, nil)
        local lines = T.count("air lc: bu harita teleport kapali", m)
        H.check("T-EX-12", a and b and c == nil and d == nil and #T.unch == u0 and blk3 == 0 and lines == 1,
            "teleport haritada kapaliyken Air LC de yok: uncharge " .. (#T.unch - u0) .. ", kilit " .. blk3
            .. ", 'air lc: bu harita teleport kapali' " .. lines .. " kez")
        local U = H.boot({ name = "ex-12-dt-kapali" })
        local W = U.W
        W.keys.dt = false
        W.sees[2] = 60
        local u1 = W.tick + 1
        U.tick(100)
        local s1 = U.shifts(u1, 1e9)
        local n1 = U.count("UYARI: DT kapali")
        U.event("round_start", {})
        U.tick(50)
        local n2 = U.count("UYARI: DT kapali")
        H.check("T-EX-12", s1 == 0 and n1 == 1 and n2 == 2, "DT tusu kapali: hic tetik yok (" .. s1 .. "), 'UYARI: DT kapali'"
            .. " raund basina bir (" .. n1 .. ", " .. n2 .. ")")
    end)
end

-------------------------------------------------------------------------------
-- Ragebot
-------------------------------------------------------------------------------
function H.any(recs, pred)
    for _, r in ipairs(recs) do if pred(r) then return true end end
    return false
end
function H.has_md(recs, v) return H.any(recs, function(r) for _, x in ipairs(r.mds) do if math.abs(x - v) < 0.5 then return true end end return false end) end
function H.any_md(recs) return H.any(recs, function(r) return #r.mds > 0 end) end
function H.all_off(r) return r.groups.HEAD == false and r.groups.CHEST == false and r.groups.STOMACH == false
    and r.groups.ARMS == false and r.groups.LEGS == false and r.groups.FEET == false end
function H.head_off(r) return r.groups.HEAD == false end
function H.sp_head(r) for _, s in ipairs(r.sp) do if s.b == true and s.g == "HEAD" then return true end end return false end
function H.sp_force(r) for _, s in ipairs(r.sp) do if s.b == true and s.g == nil then return true end end return false end
function H.ext_misses(T, idx, n)
    for _ = 1, n do
        local id = T.shoot(idx, { hg = 1, hc = 75 })
        T.tick(2)
        T.miss(id, "resolver")
        T.tick(3)
    end
end
function C.rage()
    H.run("T-RAGE-CW", function()
        -- V1.0.13 karsi atak penceresi: sahte kayitta bekletilen dusman scout ile ates edince bekleme kalkar
        -- (ignore_target yok) ve prioritize_target gelir; ayar kapaliyken bekleme surer.
        local function inst(name, on)
            local T = H.boot({ name = name, rec_off = true })
            local W = T.W
            T.set("counter_window", on)
            W.head_dmg[2] = 50
            T.tick(30)
            W.p[2].sim_shift = 6
            T.tick(3)
            local t0 = W.tick
            T.event("weapon_fire", { userid = 102, weapon = "weapon_ssg08" })
            T.tick(6)
            local prio = 0
            for _, x in ipairs(T.prio or {}) do if x.idx == 2 and x.tick > t0 then prio = prio + 1 end end
            return T.ignored(2, t0 + 1, t0 + 6), prio, T.ignored(2, t0 - 2, t0)
        end
        local a_ign, a_prio, a_before = inst("rage-cw-acik", true)
        local b_ign, b_prio = inst("rage-cw-kapali", false)
        H.check("T-RAGE-CW", a_before >= 1 and a_ign == 0 and a_prio >= 3 and b_ign >= 3 and b_prio == 0, "atis oncesi bekletme "
            .. a_before .. " (>= 1); ates edince: ignore_target " .. a_ign .. " (0), prioritize_target " .. a_prio
            .. " (>= 3); ayar kapali: ignore " .. b_ign .. " (>= 3), prioritize " .. b_prio .. " (0)")
    end)
    H.run("T-RAGE-1", function()
        local function inst(name, shift, seen)
            local T = H.boot({ name = name })
            local W = T.W
            W.head_dmg[2] = 50
            if seen then W.sees[2] = 60 end
            T.tick(30)
            local t0 = W.tick
            W.p[2].sim_shift = shift
            T.tick(40)
            return T, t0
        end
        local A, a0 = inst("rage-1", 6)
        local held = A.ignored(2, a0 + 1, a0 + 10)
        local groups = H.any(A.hsr(2, a0 + 1, a0 + 10), H.all_off)
        local free = A.ignored(2, a0 + 13, a0 + 40)
        H.check("T-RAGE-1", held >= 3 and groups and free == 0, "sahte kayit + kimse gormuyor: ignore_target(2) " .. held
            .. " tick + 6 grup kapali (" .. tostring(groups) .. "); gercek kayittan 3 tick sonra serbest (" .. free .. ")")
        local B, b0 = inst("rage-1-uzun", 30)
        local bh = B.ignored(2, b0 + 1, b0 + 14)
        local bf = B.ignored(2, b0 + 17, b0 + 40)
        H.check("T-RAGE-1", bh >= 3 and bf == 0, "kayit 30 tick sahte kalsa da bekleme en fazla 14 tick (" .. bh .. " / sonra "
            .. bf .. ")")
        local Cn, c0 = inst("rage-1-goruyor", 6, true)
        local ch = Cn.ignored(2, c0, c0 + 40)
        H.check("T-RAGE-1", ch == 0, "hedef bizi goruyorsa (duello) bekleme yok (" .. ch .. ")")
    end)
    H.run("T-RAGE-2", function()
        local function inst(name, back_at)
            local T = H.boot({ name = name })
            local W = T.W
            W.scan[2] = true; W.scan[3] = true
            W.head_dmg[2] = 50
            T.tick(30)
            local t = W.tick
            W.head_dmg[2] = 0
            for _ = 1, 45 do
                T.tick(1)
                if back_at and W.tick == t + back_at then W.head_dmg[2] = 50 end
            end
            return T, t
        end
        local A, t = inst("rage-2")
        local held = A.ignored(2, t + 3, t + 20)
        local after = A.ignored(2, t + 29, t + 45)
        local never = A.ignored(3, 0, 1e12)
        H.check("T-RAGE-2", held >= 3 and after == 0 and never == 0, "scout: su anki kayit vurulamiyor ama 24 tick icinde"
            .. " vurulabiliyordu -> bekle (" .. held .. "), 24 tick sonra birak (" .. after .. "); hic vurulamamis hedef"
            .. " beklenmez (" .. never .. ")")
        local B, tb = inst("rage-2-geri", 10)
        local bafter = B.ignored(2, tb + 15, tb + 45)
        H.check("T-RAGE-2", bafter == 0, "tekrar vurulabilir olunca bekleme biter (" .. bafter .. ")")
    end)
    H.run("T-RAGE-3", function()
        local function inst(name, setup)
            local T = H.boot({ name = name, pre = function(T, W) H.knife_enemy(W, 2, 250) end })
            setup(T, T.W)
            T.tick(20)
            return T
        end
        local A = inst("rage-3", function(T, W) W.head_dmg[2] = 50 end)
        local B = inst("rage-3-duvar", function(T, W) W.head_dmg[2] = 50; W.wall[2] = true end)
        local Cn = inst("rage-3-baska", function(T, W) W.head_dmg[3] = 50 end)
        local a = H.has_md(A.hsr(2, 0), 30)
        local b = H.has_md(B.hsr(2, 0), 30)
        local c = H.any(Cn.hsr(3, 0), function(r) for _, x in ipairs(r.mds) do if x < 100 then return true end end return false end)
        H.check("T-RAGE-3", a and not b and not c, "250 birimde bicakli hedef gorus hattinda: set_min_dmg(30) (" .. tostring(a)
            .. "); duvar arkasinda yok (" .. tostring(b) .. "); hedef baska dusmansa yok (" .. tostring(c) .. ")")
    end)
    H.run("T-RAGE-4", function()
        local function inst(name, hp)
            local T = H.boot({ name = name, pre = function(T, W) H.knife_enemy(W, 2, 250, "taser") end })
            local W = T.W
            W.p[1].weapon = H.weapon("deagle")
            T.hset("aimbot/deagle/targeting/min. damage", 90)
            W.p[2].health = hp
            W.head_dmg[2] = 50
            T.tick(20)
            return T
        end
        local A = inst("rage-4", 80)
        local B = inst("rage-4-yuksek", 100)
        local a = H.has_md(A.hsr(2, 0), 80)
        local b = H.any_md(B.hsr(2, 0))
        H.check("T-RAGE-4", a and not b, "zeus tutan hedef (hp 80, MD 90): set_min_dmg(hp = 80) (" .. tostring(a)
            .. "); hp 100 >= md_need 90 -> cagri yok (" .. tostring(b) .. ")")
    end)
    H.run("T-RAGE-5", function()
        local T = H.boot({ name = "rage-5" })
        local W = T.W
        W.head_dmg[2] = 50; W.body_dmg[2] = 60
        T.tick(10)
        H.ext_misses(T, 2, 3)
        T.tick(5)
        local recs = T.hsr(2, W.tick - 4)
        local a = H.any(recs, H.head_off) and H.has_md(recs, 59)
        local id = T.shoot(2, { hg = 1, hc = 75 })
        T.tick(2)
        T.hit(id, { hg = 1, dmg = 60 })
        T.tick(2)
        local t1 = W.tick
        T.tick(6)
        local r2 = T.hsr(2, t1 + 1)
        local cleared = not H.any(r2, H.head_off) and not H.has_md(r2, 59)
        H.check("T-RAGE-5", a and cleared, "3 kafa-hedefli resolver iskasi (hc 75, yerde, statik): HEAD kapali + set_min_dmg(govde"
            .. " 60 - 1 = 59) (" .. tostring(a) .. "); kafa isabeti temizler (" .. tostring(cleared) .. ")")
    end)
    H.run("T-RAGE-6", function()
        local T = H.boot({ name = "rage-6" })
        local W = T.W
        W.head_dmg[2] = 50; W.body_dmg[2] = 60
        T.tick(10)
        for _, k in ipairs({ "H", "B", "M", "M", "H", "B", "M", "M", "H", "B", "M", "B" }) do
            local id = T.shoot(2, { hg = 1, hc = 75 })
            T.tick(2)
            if k == "H" then T.hit(id, { hg = 1, dmg = 50 })
            elseif k == "B" then T.hit(id, { hg = 2, dmg = 30 })
            else T.miss(id, "resolver") end
            T.tick(3)
        end
        T.tick(4)
        local recs = T.hsr(2, W.tick - 3)
        local forced = H.any(recs, H.head_off) and H.has_md(recs, 59)
        T.event("round_end", { winner = 2 })
        T.tick(2)
        local pl = nil
        for _, p in ipairs(H.mem_lines(T, "P")) do
            if p[2] == "76561198000000002" then pl = table.concat(p, "\t") end
        end
        local mem_ok = pl ~= nil and pl:find("\t12,3,", 1, true) ~= nil
        H.check("T-RAGE-6", forced and mem_ok, "12 sayilan atista 3 kafa (%25 <= %35): govde zorlanir (" .. tostring(forced)
            .. "); sayaclar hafizada 'P ... 12,3,b' (" .. tostring(pl and pl:sub(1, 120)) .. ")")
        local wins = {}
        for k = 1, 5 do
            T.tick(3)
            wins[k] = H.any(T.hsr(2, W.tick - 2), H.head_off)
            if k < 5 then
                local id = T.shoot(2, { hg = 2, hc = 75 })
                T.tick(2)
                T.hit(id, { hg = 2, dmg = 30 })
            end
        end
        local free, forcedn = 0, 0
        for _, f in ipairs(wins) do if f then forcedn = forcedn + 1 else free = free + 1 end end
        H.check("T-RAGE-6", free >= 1 and forcedn >= 3, "her 4. atis kafaya serbest: 5 pencerede " .. free .. " serbest, "
            .. forcedn .. " zorlanmis")
    end)
    H.run("T-RAGE-7", function()
        local A = H.boot({ name = "rage-7" })
        A.W.body_dmg[2] = 60
        A.tick(30)
        local a = H.any(A.hsr(2, 0), function(r) for _, x in ipairs(r.mds) do if x < 100 then return true end end return false end)
        local B = H.boot({ name = "rage-7-acik", rec_off = true, pre = function(T, W) W.p[2].sim_shift = 10 end })
        B.set("dt_pair", true)
        B.W.body_dmg[2] = 60
        B.tick(30)
        local b = H.has_md(B.hsr(2, 0), 59)
        H.check("T-RAGE-7", not a and b, "DT cifti varsayilan kapali (govde 60 x 2 >= 100'de MD degismez: " .. tostring(not a)
            .. "); acik + kayit >= 8 tick gec -> set_min_dmg(59) (" .. tostring(b) .. ")")
    end)
    H.run("T-RAGE-8", function()
        local function inst(name, body)
            local T = H.boot({ name = name })
            T.W.p[1].weapon = H.weapon("deagle")
            T.W.p[2].health = 50
            T.W.body_dmg[2] = body
            T.tick(20)
            return T
        end
        local A = inst("rage-8", 60)
        local B = inst("rage-8-kontrol", 40)
        local a = H.any(A.hsr(2, 0), function(r)
            return r.groups.HEAD == false and r.groups.ARMS == false and r.groups.LEGS == false and r.groups.FEET == false
        end)
        local b = H.any(B.hsr(2, 0), H.head_off)
        H.check("T-RAGE-8", a and not b, "govde (60) >= hp (50): HEAD, ARMS, LEGS, FEET kapali (" .. tostring(a)
            .. "); govde 40 -> yok (" .. tostring(b) .. ")")
    end)
    H.run("T-RAGE-9", function()
        local T = H.boot({ name = "rage-9", rec_off = true })
        local W = T.W
        T.set("smart_baim", false)
        T.set("wait_real", false)
        W.p[2].health = 50; W.body_dmg[2] = 60; W.head_dmg[2] = 50
        T.tick(20)
        local base = H.any(T.hsr(2, W.tick - 10), H.head_off)
        local t0 = W.tick
        W.p[2].sim_shift = 30
        T.tick(30)
        local n = 0
        for _, r in ipairs(T.hsr(2, t0 + 1, t0 + 12)) do if H.head_off(r) then n = n + 1 end end
        local late = H.any(T.hsr(2, t0 + 15, t0 + 30), H.head_off)
        H.check("T-RAGE-9", not base and n >= 3 and not late, "sniper + sahte kayit + oldurucu govde: HEAD kapali (" .. n
            .. " tick), en fazla 12 tick (sonra " .. tostring(late) .. "), oncesi " .. tostring(base))
    end)
    H.run("T-RAGE-10", function()
        local A = H.boot({ name = "rage-10" })
        local W = A.W
        W.p[1].weapon = H.weapon("deagle")
        W.head_dmg[2] = 50; W.body_dmg[2] = 30
        A.tick(20)
        local base = H.any(A.hsr(2, 0), function(r) return #r.sp > 0 end)
        local id = A.shoot(2); A.tick(2); A.miss(id, "resolver"); A.tick(5)
        local l1 = H.any(A.hsr(2, W.tick - 3), H.sp_head)
        id = A.shoot(2); A.tick(2); A.miss(id, "resolver"); A.tick(5)
        local l2 = H.any(A.hsr(2, W.tick - 3), H.sp_force)
        H.check("T-RAGE-10", not base and l1 and l2, "resolver iskasi 1 -> set_safepoint_state(true, HEAD) (" .. tostring(l1)
            .. "), 2 -> set_safepoint_state(true) (" .. tostring(l2) .. "); oncesi " .. tostring(base))
        local B = H.boot({ name = "rage-10-sniper" })
        B.W.head_dmg[2] = 50; B.W.body_dmg[2] = 30
        B.tick(10)
        for _ = 1, 2 do local i = B.shoot(2); B.tick(2); B.miss(i, "resolver"); B.tick(3) end
        B.tick(5)
        local bh = H.any(B.hsr(2, B.W.tick - 4), H.sp_head)
        local bf = H.any(B.hsr(2, 0), H.sp_force)
        H.check("T-RAGE-10", bh and not bf, "sniper seviye 1'de sinirli (Head " .. tostring(bh) .. ", Force " .. tostring(bf) .. ")")
        local Cn = H.boot({ name = "rage-10-sahte" })
        local Wc = Cn.W
        Wc.p[1].weapon = H.weapon("deagle")
        Wc.head_dmg[2] = 50
        Cn.tick(20)
        local t0 = Wc.tick
        Wc.p[2].sim_shift = 20
        Cn.tick(2)
        local m = Cn.mark()
        local i = Cn.shoot(2); Cn.tick(1); Cn.miss(i, "resolver")
        Cn.tick(35)
        local line = Cn.printed("atis:", m) or ""
        local sp = H.any(Cn.hsr(2, t0 + 25), function(r) return #r.sp > 0 end)
        H.check("T-RAGE-10", line:find("def (sahte kayit)", 1, true) ~= nil and not sp, "sahte kayittaki iska ogrenilmez (safe"
            .. " point yok: " .. tostring(not sp) .. ") ve atis satirinda 'def (sahte kayit)': " .. line:sub(1, 160))
    end)
    H.run("T-RAGE-11", function()
        local A = H.boot({ name = "rage-11-bicak", pre = function(T, W) H.knife_enemy(W, 2, 250) end })
        A.W.keys.md_ovr = true
        A.W.head_dmg[2] = 50; A.W.body_dmg[2] = 40
        A.tick(20)
        local B = H.boot({ name = "rage-11-ext" })
        B.W.keys.md_ovr = true
        B.W.head_dmg[2] = 50; B.W.body_dmg[2] = 60
        B.tick(10)
        H.ext_misses(B, 2, 3)
        B.tick(10)
        local function rule_off(r) return H.head_off(r) and not H.all_off(r) end
        local a = H.any_md(A.hsr(2, 0)) or H.any(A.hsr(2, 0), rule_off)
        local b = H.any_md(B.hsr(2, 0)) or H.any(B.hsr(2, 0), rule_off)
        H.check("T-RAGE-11", not a and not b, "kullanicinin force min. damage tusu basili: R4 / R5 MD yazmaz, grup kapatmaz"
            .. " (bicak " .. tostring(a) .. ", extended " .. tostring(b) .. ")")
    end)
    H.run("T-RAGE-13", function()
        local A = H.boot({ name = "rage-13", rec_off = true })
        A.set("air_hc", 60)
        A.hset("aimbot/scout/targeting/hitchance", 55)
        A.W.p[1].ground = false
        A.W.head_dmg[2] = 50
        A.tick(20)
        local a = H.any(A.hsr(2, 0), function(r) return r.hc == 60 end)
        local B = H.boot({ name = "rage-13-varsayilan" })
        B.W.p[1].ground = false
        B.W.head_dmg[2] = 50
        B.tick(20)
        local b = H.any(B.hsr(2, 0), function(r) return r.hc ~= nil end)
        H.check("T-RAGE-13", a and not b, "havada scout, slider 60 > native 55: set_hitchance(60) (" .. tostring(a)
            .. "); varsayilan 0 -> hic (" .. tostring(b) .. ")")
    end)
    H.run("T-RAGE-15", function()
        local function inst(name, md, seen)
            local T = H.boot({ name = name })
            T.hset("aimbot/scout/targeting/min. damage", md)
            if seen then T.W.sees[2] = 60 end
            T.W.head_dmg[2] = 50
            T.tick(20)
            return T
        end
        local a = H.has_md(inst("rage-15", 60, true).hsr(2, 0), 100)
        local b = H.any_md(inst("rage-15-gorulmuyor", 60, false).hsr(2, 0))
        local c = H.any_md(inst("rage-15-md100", 100, true).hsr(2, 0))
        H.check("T-RAGE-15", a and not b and not c, "scout, MD 60, hp 100, goruluyor: set_min_dmg(100) (" .. tostring(a)
            .. "); gorulmuyor -> yok (" .. tostring(b) .. "); MD 100 -> yok (" .. tostring(c) .. ")")
    end)
    H.run("T-RAGE-16", function()
        local function inst(name, setup, pre)
            local T = H.boot({ name = name, pre = pre })
            T.hset("aimbot/scout/targeting/min. damage", 60)
            T.W.sees[2] = 60
            T.W.head_dmg[2] = 50
            setup(T, T.W)
            T.tick(20)
            return T
        end
        local A = inst("rage-16-bicak", function() end, function(T, W) H.knife_enemy(W, 2, 200) end)
        local recs = A.hsr(2, A.W.tick - 15)
        local only30 = #recs > 0
        for _, r in ipairs(recs) do if not (#r.mds == 1 and r.mds[1] == 30) then only30 = false end end
        local B = inst("rage-16-zeus", function(T, W)
            W.body_dmg[2] = 60
            T.tick(5)
            H.ext_misses(T, 2, 3)
        end, function(T, W) H.knife_enemy(W, 2, 200, "taser") end)
        local low = H.any(B.hsr(2, 0), function(r) for _, x in ipairs(r.mds) do if x < 60 then return true end end return false end)
        local Cn = inst("rage-16-hp20", function(T, W) W.p[2].health = 20 end, function(T, W) H.knife_enemy(W, 2, 200) end)
        local c = H.has_md(Cn.hsr(2, 0), 20)
        H.check("T-RAGE-16", only30 and not low and c, "kural sirasi: bicak (R4) R3'ten once, tek MD 30 (" .. tostring(only30)
            .. "); zeus + 3 extended iska -> 60'in altinda MD yok (" .. tostring(not low) .. "); bicak hp 20 -> min(30, hp) = 20 ("
            .. tostring(c) .. ")")
    end)
    H.run("T-RAGE-17", function()
        local T = H.boot({ name = "rage-17" })
        local W = T.W
        W.p[1].weapon = H.weapon("deagle")
        W.p[2].health = 25
        W.head_dmg[2] = 50; W.body_dmg[2] = 20
        T.tick(10)
        local l2 = H.any(T.hsr(2, 0), H.sp_force)
        W.can_fire = true
        local t0 = W.tick
        local m = T.mark()
        T.tick(60)
        local l1 = H.any(T.hsr(2, t0 + 34), H.sp_head) and not H.any(T.hsr(2, t0 + 40), H.sp_force)
        H.check("T-RAGE-17", l2 and l1 and T.printed("seviye 2 -> 1", m) ~= nil, "hp 25: seviye 2 (Force) (" .. tostring(l2)
            .. "); gorunur + ates edebilir + 0.5 sn atis yok -> Head (" .. tostring(l1) .. ") ve 'seviye 2 -> 1'")
    end)
    H.run("T-RAGE-18", function()
        local T = H.boot({ name = "rage-18", pre = function(T, W) H.knife_enemy(W, 2, 250, "bayonet", "CKnife") end })
        T.W.head_dmg[2] = 50
        T.tick(20)
        H.check("T-RAGE-18", H.has_md(T.hsr(2, 0), 30), "get_name() 'bayonet' (CKnife) da bicak sayilir: set_min_dmg(30)")
    end)
end

-------------------------------------------------------------------------------
-- Peek / AFK
-------------------------------------------------------------------------------
function H.peek_world(T, W)
    W.physics = true
    W.keys.autopeek = true
    W.autopeek_pos = V.v3(0, 0, 0)
    W.can_fire = true
    W.ldmg = function(from, t, to, head)
        if head and from.y > 25 then return 120 end
        return 0
    end
end
function C.peek()
    H.run("T-PEEK-1", function()
        local T = H.boot({ name = "peek-1" })
        H.peek_world(T, T.W)
        local m = T.mark()
        T.tick(200)
        local walked = (T.ymax or 0) > 15
        local line = T.printed("ai peek:", m)
        H.check("T-PEEK-1", walked and line ~= nil, "autopeek tusu + konum, hareket tusu yok, +y tarafinda kafa 120 >= 100:"
            .. " cmd.move oraya yurur (en buyuk y " .. H.f1(T.ymax) .. ") ve 'ai peek:' satiri")
        local _, li = nil, nil
        for _ = 1, 15 do
            T.tick(100)
            _, li = T.printed("2 bos peek", m)
            if li then break end
        end
        local locked = false
        if li then
            T.tick(10)
            T.ymax = T.W.p[1].origin.y
            T.tick(200)
            locked = T.ymax < 10
        end
        H.check("T-PEEK-1", li ~= nil and locked, "2 bos peek -> 'ai peek: 2 bos peek' ve tus yeniden basilana kadar kilitli"
            .. " (sonraki en buyuk y " .. H.f1(T.ymax) .. ")")
    end)
    H.run("T-PEEK-2", function()
        local T = H.boot({ name = "peek-2" })
        H.peek_world(T, T.W)
        T.W.side_conv = -1
        T.tick(300)
        local n = T.count("ters olculdu")
        H.check("T-PEEK-2", n == 1 and (T.ymax or 0) > 15, "yan hareket isareti ters: bir kez 'ters olculdu' (" .. n
            .. ") ve duzeltilmis yonde yurur (en buyuk y " .. H.f1(T.ymax) .. ")")
    end)
    H.run("T-PEEK-3", function()
        local T = H.boot({ name = "peek-3" })
        local W = T.W
        W.physics = true
        local m = T.mark()
        T.set("afk", true)
        T.tick(64 * 4)
        local stepped = (T.ymax or 0) > 15 or (T.ymin or 0) < -15
        H.check("T-PEEK-3", T.printed("afk modu acik", m) ~= nil and stepped, "AFK acik: capa kurulur, 3 sn bosta 24 birimlik"
            .. " adim (y " .. H.f1(T.ymin) .. " .. " .. H.f1(T.ymax) .. ")")
        W.buttons.FORWARD = true
        W.move = { x = 450, y = 0 }
        T.tick(5)
        local mv = T.moves[W.tick] or {}
        W.buttons.FORWARD = nil
        W.move = { x = 0, y = 0 }
        H.check("T-PEEK-3", mv.x == 450 and mv.y == 0, "hareket tusu adimi durdurur, cmd.move'a dokunulmaz (" .. tostring(mv.x)
            .. ", " .. tostring(mv.y) .. ")")
        T.event("player_death", { userid = 101, attacker = 102, weapon = "ssg08" })
        W.p[1].alive = false
        T.tick(3)
        H.check("T-PEEK-3", T.printed("afk modu kapali: oldun") ~= nil, "olum -> 'afk modu kapali: oldun'")
    end)
    H.run("T-PEEK-4", function()
        local function inst(name, setup)
            local T = H.boot({ name = name, keep_afk = true })
            T.event("player_spawn", { userid = 101 })
            if setup then setup(T, T.W) end
            T.tick(64 * 9)
            return T
        end
        local A = inst("afk-oto")
        local on = A.printed("otomatik afk:") ~= nil
        A.W.view.y = 5
        A.tick(3)
        local off = A.printed("otomatik afk kapandi") or ""
        local B = inst("afk-oto-menu", function(T, W) W.menu_open = true end)
        local Cn = inst("afk-oto-freeze", function(T, W) W.freeze = true end)
        H.check("T-PEEK-4", on and off:find("fare", 1, true) ~= nil and B.printed("otomatik afk:") == nil
            and Cn.printed("otomatik afk:") == nil, "dogduktan sonra 8 sn girdi yok -> 'otomatik afk:' (" .. tostring(on)
            .. "); fare -> '" .. off .. "'; menu acik / freeze sayilmaz")
    end)
end

-------------------------------------------------------------------------------
-- Loglar / dosyalar
-------------------------------------------------------------------------------
function C.logs()
    H.run("T-LOG-1", function()
        local T = H.boot({ name = "log-1" })
        T.tick(10)
        local m = T.mark()
        local id = T.shoot(2, { hg = 1, dmg = 120, hc = 80, bt = 0 })
        T.tick(2)
        T.hit(id, { hg = 1, dmg = 120 })
        T.tick(2)
        local want = "atis: Alpha | Standing | HP 100 | hedef head 120 | isabet head -120 | SP - | BA Default | MD 100 | bt 0t | hc 80% | sen ssg08"
        H.check("T-LOG-1", T.printed(want, m) ~= nil, "atis satiri bicimi: '" .. want .. "' <- " .. tostring(T.printed("atis:", m)))
    end)
    H.run("T-LOG-2", function()
        local T = H.boot({ name = "log-2" })
        T.tick(10)
        local id = T.shoot(2)
        T.tick(2)
        T.miss(id, "resolver")
        T.tick(2)
        local l = T.printed("atis:") or ""
        local m = T.mark()
        T.event("round_start", {})
        T.tick(2)
        local o = T.printed("atis ozeti:", m) or ""
        H.check("T-LOG-2", l:find("iska correction", 1, true) ~= nil and o:find("correction", 1, true) ~= nil,
            "resolver iskasi 'iska correction' yazilir ve atis ozeti onu 'correction' altinda sayar: " .. o)
    end)
    H.run("T-LOG-3", function()
        local T = H.boot({ name = "log-3" })
        T.tick(10)
        local sid = T.shoot(2); T.tick(2); T.hit(sid, { hg = 2, dmg = 30 }); T.tick(2)
        local m = T.mark()
        T.event("player_hurt", { userid = 101, attacker = 102, weapon = "ssg08", hitgroup = 1, dmg_health = 50, health = 50 })
        T.tick(2)
        local v = T.printed("vuruldun: head -50 ssg08 | Standing | faz", m)
        T.event("player_death", { userid = 102, attacker = 101, weapon = "ssg08", headshot = true })
        T.tick(2)
        local k = T.printed("oldurdun: Alpha | Standing | sen ssg08 | headshot", m)
        T.event("player_death", { userid = 101, attacker = 103, weapon = "ak47", headshot = false })
        T.W.p[1].alive = false
        T.tick(2)
        local d = T.printed("oldun: Bravo |", m)
        T.event("round_start", {})
        T.tick(2)
        local r = T.printed("round ozeti: 1 mermi, 1 kafa", m)
        local a = T.printed("atis ozeti:", m)
        H.check("T-LOG-3", v and k and d and r and a, "vuruldun / oldurdun / oldun / round ozeti / atis ozeti §6 alanlariyla ("
            .. tostring(v ~= nil) .. "," .. tostring(k ~= nil) .. "," .. tostring(d ~= nil) .. "," .. tostring(r ~= nil) .. ","
            .. tostring(a ~= nil) .. ")")
    end)
    H.run("T-LOG-4", function()
        local files = { ["nykle_log.txt"] = "10:00:00 [Nykle.win] ESKI SURUM SATIRI\n" }
        local T = H.boot({ name = "log-4", files = files })
        T.tick(5)
        local reset = not (files["nykle_log.txt"] or ""):find("ESKI SURUM SATIRI", 1, true)
        T.hurt_me(2, 2, 30)
        T.event("round_start", {})
        T.tick(2)
        local f = files["nykle_log.txt"] or ""
        local has = f:find("vuruldun:", 1, true) ~= nil and f:find("] " .. H.VER .. " (primordial edition) yuklendi", 1, true) ~= nil
        T.press("log_clear")
        T.tick(2)
        local g = files["nykle_log.txt"] or ""
        local cleared = g:find("vuruldun:", 1, true) == nil and g:find("] " .. H.VER .. " (primordial edition) yuklendi", 1, true) ~= nil
        H.check("T-LOG-4", reset and has and cleared, "eski surum dosyasi yuklemede sifirlanir (" .. tostring(reset)
            .. "), round_start'ta satirlar dosyada (" .. tostring(has) .. "), Clear saved logs isareti birakir ("
            .. tostring(cleared) .. ")")
        local keep = { ["nykle_log.txt"] = "10:00:00 [Nykle.win] " .. H.VER .. " (primordial edition) yuklendi (hafiza: 0 oyuncu)\n10:00:01 [Nykle.win] TUT BENI\n" }
        local U = H.boot({ name = "log-4-ayni", files = keep })
        U.event("round_start", {})
        U.tick(2)
        H.check("T-LOG-4", (keep["nykle_log.txt"] or ""):find("TUT BENI", 1, true) ~= nil, "ayni surumun dosyasi korunur")
    end)
    H.run("T-LOG-6", function()
        local files = {}
        local function setup(T, W)
            W.p[1].weapon = H.weapon("deagle")
            W.head_dmg[2] = 50
        end
        local A = H.boot({ name = "hafiza-1", files = files })
        setup(A, A.W)
        A.tick(10)
        local id = A.shoot(2); A.tick(2); A.miss(id, "resolver"); A.tick(5)
        A.impact(2, 20); A.tick(1); A.hurt_me(2, 1, 50); A.tick(20)
        A.shutdown()
        local function fset(T)
            local r = {}
            for _, f in ipairs(H.mem_lines(T, "F2")) do r[#r + 1] = table.concat(f, ",") end
            table.sort(r)
            return table.concat(r, ";")
        end
        local fa = fset(A)
        local B = H.boot({ name = "hafiza-2", files = files })
        local line = B.printed("yuklendi") or ""
        local n = tonumber(line:match("hafiza: (%d+) oyuncu") or "0")
        setup(B, B.W)
        B.tick(10)
        local lvl = H.any(B.hsr(2, 0), H.sp_head)
        B.shutdown()
        local fb = fset(B)
        H.check("T-LOG-6", n >= 1 and lvl and fa ~= "" and fa == fb, "hafiza dosyasi gidis-donus: yeni ornek 'hafiza: " .. n
            .. " oyuncu', resolver seviyesi geri geldi (" .. tostring(lvl) .. "), faz istatistikleri ayni (" .. fa .. ")")
    end)
    H.run("T-LOG-7", function()
        local T = H.boot({ name = "log-7" })
        T.W.can_fire = true
        T.W.body_dmg[2] = 40
        T.tick(70)
        local l = T.printed("dbg sikmadi:") or ""
        H.check("T-LOG-7", l:find("hasar 40 <", 1, true) ~= nil, "0.44 sn vurulabilir, atis yok, govde < MD: " .. l)
    end)
    H.run("T-LOG-8", function()
        local T = H.boot({ name = "log-8" })
        T.tick(10)
        local m = T.mark()
        T.shoot(2)
        T.tick(64 * 5 + 30)
        local l = T.printed("sonuc yok", m) or ""
        local m2 = T.mark()
        local id = T.shoot(2)
        T.tick(2)
        T.miss(id, "spread", { noplayer = true })
        T.tick(2)
        local l2 = T.printed("atis:", m2) or ""
        H.check("T-LOG-8", l:find("atis:", 1, true) ~= nil and (l2:find("Alpha", 1, true) or l2:find("?", 1, true))
            and l2:find("iska spread", 1, true) ~= nil and #T.raw_err == 0,
            "sonucsuz atis 5 sn sonra 'sonuc yok' ile yazilir (" .. l:sub(1, 80) .. "); player'siz MISS da yazilir ("
            .. l2:sub(1, 80) .. ")")
    end)
    H.run("T-LOG-9", function()
        local T = H.boot({ name = "log-9" })
        local l = T.printed("dbg ayarlar:") or ""
        local fields = l:find("DT", 1, true) and l:find("fake ping", 1, true) and l:find("FL", 1, true) and l:find("MD", 1, true)
        T.event("round_start", {})
        T.tick(2)
        local n = T.count("dbg ayarlar:")
        local U = H.boot({ name = "log-9-ping", pre = function(T, W) W.keys.fakeping = true end })
        U.tick(5)
        H.check("T-LOG-9", fields and n == 2 and U.printed("UYARI: fake ping acik") ~= nil, "'dbg ayarlar:' yuklemede ve"
            .. " round_start'ta (" .. n .. ") DT / fake ping / FL / MD alanlariyla; fake ping acik -> uyari: " .. l:sub(1, 120))
    end)
    H.run("T-LOG-10", function()
        local big = "10:00:00 [Nykle.win] " .. H.VER .. " (primordial edition) yuklendi (hafiza: 0 oyuncu)\n" .. string.rep("x", 4200000) .. "\n"
        local files = { ["nykle_log.txt"] = big }
        local T = H.boot({ name = "log-10-buyuk", files = files })
        T.event("round_start", {})
        T.tick(2)
        local f = files["nykle_log.txt"] or ""
        local said = T.printed("onceki log 4 MB'yi gecmisti") ~= nil or f:find("onceki log 4 MB'yi gecmisti", 1, true) ~= nil
        H.check("T-LOG-10", #f < 100000 and said and f:find("] " .. H.VER .. " (primordial edition) yuklendi", 1, true) ~= nil,
            "4 MB ustu log yuklemede yukleme satiri + 'onceki log 4 MB'yi gecmisti' ile yeniden yazilir (" .. #f .. " bayt)")
        -- Oturumda 2 MB: siniri gecen toplu yazmanin sigan kismi + not dosyaya; sonra sadece ozet satirlari (harita /
        -- dusman ozeti, teshis, kapanis) 128 KB yedek payla.
        local files2 = {}
        local U = H.boot({ name = "log-10-oturum", files = files2 })
        U.tick(2)
        local cap = 2 * 1024 * 1024
        local note = "log dosyasi bu oturumda 2 MB'yi gecti"
        local size_at, k = nil, 0
        for i = 1, 40 do
            for _ = 1, 1000 do U.hurt_me(2, 2, 1) end
            U.event("round_end", { winner = 2 })
            if U.printed(note) and size_at == nil then size_at = #(files2["nykle_log.txt"] or "") end
            if size_at ~= nil then
                k = k + 1
                if k >= 2 then break end
            end
        end
        local mid = #(files2["nykle_log.txt"] or "")
        U.tick(70)
        U.event("game_newmap", { mapname = "de_nuke" })
        U.W.map = "de_nuke"
        U.tick(5)
        U.shutdown()
        local f = files2["nykle_log.txt"] or ""
        local _, notes = f:gsub("log dosyasi bu oturumda 2 MB'yi gecti", "")
        local tail = f:sub(size_at and size_at + 1 or 1)
        local _, vur = tail:gsub("vuruldun:", "")
        H.check("T-LOG-10", size_at ~= nil and size_at > cap - 400 and size_at <= cap + 400 and U.count(note) == 1
            and notes == 1 and mid == size_at and vur == 0 and H.has(tail, "harita ozeti: ")
            and f:find("script kaldirildi[^\n]*\n$") ~= nil and #f <= cap + 128 * 1024,
            "2 MB'de dosya " .. tostring(size_at) .. " bayt (sigan kisim yazildi), not dosyada " .. notes .. " / konsolda "
            .. U.count(note) .. ", sonra normal satir yok (" .. tostring(mid) .. ", vuruldun " .. vur .. "); harita ozeti ve"
            .. " kapanis yine dosyada (" .. #f .. " bayt)")
    end)
end
function C.log_noffi()
    H.run("T-LOG-5", function()
        local T = H.boot({ name = "noffi-log" })
        local l = T.printed("yuklendi") or ""
        local m = T.mark()
        T.press("log_print")
        T.tick(2)
        local again = T.printed("yuklendi", m) ~= nil
        H.check("T-LOG-5", l:find("log dosyasi yok", 1, true) ~= nil and again and #T.raw_err == 0,
            "ffi yok: hata yok, yukleme satiri '(log dosyasi yok' der, Print all logs halkayi basar: " .. l:sub(1, 120))
    end)
end

-------------------------------------------------------------------------------
-- Detayli log (R1-B1, N.dlog): T-DLOG-1..12, her modda.
-------------------------------------------------------------------------------
-- Satirin "[Nykle.win] " onekini at.
function H.bare(l) return l and (l:gsub("^%[Nykle%.win%] ", "")) or nil end
-- s icinde parcalar bu sirayla geciyor mu (duz metin).
function H.in_order(s, parts)
    if s == nil then return false end
    local at = 1
    for _, p in ipairs(parts) do
        local i = s:find(p, at, true)
        if i == nil then return false end
        at = i + #p
    end
    return true
end
function H.nonascii(T)
    local bad = {}
    for _, l in ipairs(T.prints) do
        if (l:find("dbg ", 1, true) or l:find("teshis:", 1, true)) and l:find("[\128-\255]") then bad[#bad + 1] = l end
    end
    return bad
end
-- Dusmana tek tick'lik sahte kayit: simulasyon zamani k tick geri (track'te k tick defensive: SETUP'ta k-1 geri,
-- def_until = tick + k - 1).
function H.def_episode(T, idx, k)
    T.W.p[idx].sim_shift = k
    T.tick(1)
    T.W.p[idx].sim_shift = 0
    T.tick(k + 4)
end
function C.dlog()
    local missing = H.mode == "missing"
    H.run("T-DLOG-1", function()
        local T = H.boot({ name = "dlog-1" })
        local W = T.W
        W.head_dmg[2] = 60; W.body_dmg[2] = 40; W.can_fire = true; W.sees[2] = 60
        T.tick(12)
        local res = {}
        for _, kind in ipairs({ "hit", "miss", "expire" }) do
            local m = T.mark()
            local id = T.shoot(2, { hc = 80, bt = 2 })
            T.tick(2)
            if kind == "hit" then T.hit(id, { hg = 1, dmg = 50 }) elseif kind == "miss" then T.miss(id, "spread") else T.tick(64 * 5 + 30) end
            T.tick(2)
            local a, ai = T.printed("atis: Alpha", m)
            local d, di = T.printed("dbg atis-detay: Alpha @", m)
            local ok = a ~= nil and d ~= nil and di == ai + 1 and H.in_order(d, { "aimbot bt 2t hc 80%", "vurulabilir" })
                and d:find("| ben @", 1, true) ~= nil and d:find("nisan z+64", 1, true) ~= nil
            res[#res + 1] = kind .. "=" .. tostring(ok)
            if not ok then res[#res + 1] = tostring(d) end
        end
        H.check("T-DLOG-1", table.concat(res, " "):find("false", 1, true) == nil, "her atis sonucunun (isabet / iska / sonuc yok)"
            .. " hemen altinda 'dbg atis-detay: <isim> @...' bt / hc / nisan z / vurulabilir / ben @ ile: " .. table.concat(res, " "))
        -- Detailed log kapali: hicbir dbg / teshis satiri yok, atis satiri yine var.
        T.set("debug_log", false)
        local m = T.mark()
        local id = T.shoot(2); T.tick(2); T.hit(id, { hg = 1, dmg = 50 }); T.tick(2)
        W.wall[2] = true; T.hurt_me(2, 1, 20); W.wall[2] = nil
        T.event("weapon_fire", { userid = 102, weapon = "weapon_ak47" }); T.event("weapon_fire", { userid = 102, weapon = "weapon_ak47" })
        T.hurt_me(2, 2, 10); T.tick(70)
        T.event("player_death", { userid = 103, attacker = 101, weapon = "ssg08", headshot = 1 })
        T.event("round_end", { winner = 3 }); T.event("round_start", {}); T.event("round_start", {})
        T.event("game_newmap", { mapname = "de_dust2" }); T.tick(10)
        T.event("player_death", { userid = 101, attacker = 102, weapon = "ak47", penetrated = 1 })
        T.tick(2)
        local n = T.count("dbg ", m) + T.count("teshis: yer adi", m) + T.count("teshis: ping", m)
        H.check("T-DLOG-1", n == 0 and T.printed("atis: Alpha", m) ~= nil, "Detailed log kapali: yeni dbg satiri yok ("
            .. n .. ": " .. tostring(T.printed("dbg ", m)) .. "), atis satiri var")
    end)
    H.run("T-DLOG-2", function()
        local T = H.boot({ name = "dlog-2" })
        local P = T.W.p
        local a = P[2]
        a.place = "BombsiteA"; a.origin = V.v3(500, 0, 40); a.ground = false; a.vel = V.v3(30, 40, -120); a.duck = 0.8
        a.ping = 35
        T.tick(4)
        local m = T.mark()
        T.hurt_me(2, 1, 30, "ak47")
        T.tick(1)
        local l = T.printed("dbg vurulma-detay: Alpha", m)
        local where = H.in_order(l, { "| @BombsiteA(500,0,40) 502u h+40 v50 havada vz-120 duck80", " hp100 ak47" })
        local ping
        if missing then
            ping = l ~= nil and l:find("ping", 1, true) == nil
        else
            ping = H.in_order(l, { "ak47 ping35 |" })
        end
        H.check("T-DLOG-2", where and ping and #T.raw_err == 0 and T.printed("hata verdi") == nil, "konum bicimi"
            .. " '@YerAdi(x,y,z) <mesafe>u h+dz v havada vz duck .. hp silah" .. (missing and "' (player_resource yok: ping yazilmaz, hata yok)"
            or " ping35'") .. ": " .. tostring(l))
        local own = H.in_order(l, { "| ben @", "(0,0,0) v0 hp100 ssg08" })
        H.check("T-DLOG-2", own and l:find("| ben @%S+%(0,0,0%) %d+u") == nil, "ben: kendi konumun mesafesiz / bakissiz: " .. tostring(l))
    end)
    H.run("T-DLOG-3", function()
        local T = H.boot({ name = "dlog-3" })
        local W = T.W
        T.tick(4)
        local m = T.mark()
        W.wall[2] = true
        T.hurt_me(2, 1, 30)
        local wall = T.printed("dbg vurulma-detay:", m)
        W.wall[2] = nil
        local m2 = T.mark()
        T.event("weapon_fire", { userid = 102, weapon = "weapon_ssg08" })
        W.real_off = W.real_off + 0.15
        T.event("weapon_fire", { userid = 102, weapon = "weapon_ssg08" })
        T.hurt_me(2, 2, 30)
        local open = T.printed("dbg vurulma-detay:", m2)
        H.check("T-DLOG-3", H.in_order(wall, { "dbg vurulma-detay: Alpha head -30 ssg08 | iz duvardan | @" })
            and H.in_order(open, { "dbg vurulma-detay: Alpha chest -30 ssg08 | iz acik | @", "| son iki atisi arasi 0.15s (DT) ",
            "| sen onu vuramiyordun | ben @" }), "vurulma-detay: duvar -> 'iz duvardan', acik -> 'iz acik', 0.15 sn arayla iki atis"
            .. " -> 'son iki atisi arasi 0.15s (DT)': " .. tostring(wall) .. " / " .. tostring(open))
    end)
    H.run("T-DLOG-4", function()
        local T = H.boot({ name = "dlog-4" })
        T.tick(4)
        local m = T.mark()
        T.event("player_death", { userid = 103, attacker = 101, weapon = "ssg08", thrusmoke = true, attackerblind = 1 })
        T.W.p[3].alive = false
        T.tick(1)
        T.event("player_death", { userid = 101, attacker = 102, weapon = "ssg08", headshot = 1, penetrated = 1, noscope = 1 })
        T.W.p[1].alive = false
        T.tick(1)
        local d = T.printed("dbg olum-detay:", m)
        local k = T.printed("dbg kill-detay:", m)
        H.check("T-DLOG-4", H.in_order(d, { "dbg olum-detay: Alpha ssg08 headshot, duvardan (1), noscope | @", "| AA ", "| ben @" })
            and H.in_order(k, { "dbg kill-detay: Bravo ssg08 smoke icinden, kor | @" }), "olum / kill etiketleri: " .. tostring(d)
            .. " / " .. tostring(k))
    end)
    H.run("T-DLOG-5", function()
        local T = H.boot({ name = "dlog-5" })
        local W = T.W
        W.sees[2] = 60; W.sees[3] = 60
        T.tick(10)
        local m = T.mark()
        local id = T.shoot(2)
        T.tick(1)
        T.event("player_death", { userid = 102, attacker = 101, weapon = "ssg08", headshot = true })
        T.hit(id, { hg = 1, dmg = 120, no_event = true })
        W.p[2].alive = false
        T.tick(2)
        local l = H.bare(T.printed("dbg duello: Alpha", m))
        -- Bomba ile olum: bekleyen atis olsa da isabet sayilmaz.
        local id2 = T.shoot(3)
        T.tick(1)
        T.event("player_death", { userid = 103, attacker = 101, weapon = "hegrenade" })
        T.miss(id2, "spread")
        T.tick(2)
        local g = H.bare(T.printed("dbg duello: Bravo", m))
        H.check("T-DLOG-5", l ~= nil and l:find("| sen: 1 ates 1 isabet | oldurdun", 1, true) ~= nil
            and g ~= nil and g:find("| sen: 1 ates 0 isabet | oldurdun", 1, true) ~= nil, "player_death AIMBOT_HIT'ten once:"
            .. " olduren isabet sayilir (" .. tostring(l) .. "), bomba ile olumde sayilmaz (" .. tostring(g) .. ")")
    end)
    H.run("T-DLOG-6", function()
        local T = H.boot({ name = "dlog-6" })
        T.tick(4)
        H.def_episode(T, 2, 4)
        H.def_episode(T, 2, 6)
        local m0 = T.mark()
        T.W.p[2].sim_shift = 2
        T.tick(1)
        local during = T.printed("dbg ", m0)
        T.W.p[2].sim_shift = 0
        T.tick(7)
        local m = T.mark()
        T.event("round_start", {})
        local l = H.bare(T.printed("dbg def ozeti: Alpha", m))
        -- V1.0.5: takip tick basina bir kez ve NET_UPDATE'ten (T.fallback sadece NET_UPDATE susunca); bu harnes'te
        -- NET_UPDATE SETUP_COMMAND'dan sonra geldigi icin bolum SETUP'ta bir tick gec gorulur: 4 / 6 / 2 -> 3 / 5 / 1.
        H.check("T-DLOG-6", l == "dbg def ozeti: Alpha 3 kez, toplam 9t, ort 3.0t, en uzun 5t, 0 tanesi hareketliyken"
            and T.printed("dbg def ozeti: Bravo", m) == nil, "4 / 6 / 2 tick'lik uc sahte kayit bolumu -> " .. tostring(l))
    end)
    H.run("T-DLOG-7", function()
        local T = H.boot({ name = "dlog-7" })
        T.tick(4)
        local m = T.mark()
        T.event("round_start", {})
        T.event("round_start", {})
        local n1, a1 = T.count("dbg ===== round", m), T.count("dbg ayarlar:", m)
        T.hurt_me(3, 2, 10)
        T.event("round_start", {})
        local n2 = T.count("dbg ===== round", m)
        local h = H.bare(T.printed("dbg ===== round", m))
        H.check("T-DLOG-7", n1 == 1 and a1 == 1 and n2 == 2 and h == "dbg ===== round 4 | de_mirage | sen CT | ping 50ms =====",
            "arka arkaya iki round_start: baslik " .. n1 .. " / ayarlar " .. a1 .. " kez; araya satir girince yine (" .. n2
            .. "): " .. tostring(h))
        local hm = T.count("dbg ===== harita de_mirage =====")
        local m2 = T.mark()
        T.event("game_newmap", { mapname = "de_nuke" })
        T.W.map = "de_nuke"
        T.tick(3)
        H.check("T-DLOG-7", hm == 1 and T.printed("dbg ===== harita de_nuke =====", m2) ~= nil
            and T.printed("dbg ayarlar:", m2) ~= nil, "harita basligi yuklemeden sonra bir kez (" .. hm .. "), harita degisince"
            .. " yeni basik + dbg ayarlar")
    end)
    H.run("T-DLOG-8", function()
        local T = H.boot({ name = "dlog-8" })
        T.tick(2)
        local m = T.mark()
        T.event("round_end", { winner = 3, reason = 8 })
        T.event("round_end", { winner = 2, reason = 9 })
        T.event("round_end", { winner = 1, reason = 16 })
        local a, b, c = T.printed("dbg round sonu:", m)
        local lines = H.lines_with(T, "dbg round sonu:", m)
        local want = { "dbg round sonu: CT kazandi (senin takimin)", "dbg round sonu: T kazandi",
            "dbg round sonu: kazanan yok (oyun basi / yeniden baslatma)" }
        local ok = #lines == 3
        for i = 1, 3 do ok = ok and H.bare(lines[i]) == want[i] end
        H.check("T-DLOG-8", ok, "round_end kazanan 3 / 2 / 1, takimin CT: " .. H.list(lines, 3))
    end)
    H.run("T-DLOG-9", function()
        local T = H.boot({ name = "dlog-9" })
        local W, P = T.W, T.W.p
        W.can_fire = true; W.body_dmg[2] = 40
        P[1].ground = false
        T.tick(70, function(T, W) W.p[2].sim_shift = W.p[2].sim_shift + 2 end)
        local l = T.printed("dbg sikmadi: Alpha") or ""
        local need = { "onun kaydi sahte (DEF)", "sen havadasin", "kafa kapali" }
        if not missing then need[#need + 1] = "hasar 40 < " end
        local miss = {}
        for _, x in ipairs(need) do if not l:find(x, 1, true) then miss[#miss + 1] = x end end
        H.check("T-DLOG-9", #miss == 0 and l:find("sebep bilinmiyor", 1, true) == nil
            and H.in_order(l, { "ates yok | ", " | MD ", " | sen ssg08 | silah ", " | @", " | DEF geri ", " AA ", " | ben @" }),
            "sikmadi butun sebepler + silah / konum / kayit / sen kuyrugu (eksik: " .. H.list(miss, 4) .. "): " .. l)
    end)
    H.run("T-DLOG-10", function()
        local T = H.boot({ name = "dlog-10" })
        local W = T.W
        W.sees[3] = 60
        T.tick(6)
        H.def_episode(T, 3, 4)
        W.sees[3] = 0
        local m = T.mark()
        T.tick(64 * 3 + 20)
        local l = H.bare(T.printed("dbg duello: Bravo", m))
        local re = "^dbg duello: %S.* @.*| %d+%.%d%ds | ilk goren: .* | def %d+ kez %d+t %(%%%d+%)"
        H.check("T-DLOG-10", l ~= nil and l:find(re) ~= nil and l:find("ilk goren: sadece o gordu | def 1 kez 3t (%", 1, true) ~= nil
            and l:find("| ayrildi", 1, true) ~= nil, "duello satiri GS duzenine uyar: " .. tostring(l))
    end)
    H.run("T-DLOG-13", function()
        -- N4: uyku (dormancy) loglarda. Saldiran 2 sn dormant, uyanir, 13 tick (0.20 sn) sonra vurur.
        local T = H.boot({ name = "dlog-13" })
        local W = T.W
        T.tick(20)
        local base = H.hurt_line(T, 2)
        W.p[2].dormant = true
        T.tick(128)
        W.p[2].dormant = false
        local m = T.mark()
        T.tick(14)
        local woke = H.hurt_line(T, 2)
        local dbg = H.bare(T.printed("dbg uyandi:", m))
        -- 5 sn dolmadan ikinci uyanma: satir yok; saldiran uykudayken gelen isabet: "uykuda".
        W.p[2].dormant = true
        T.tick(20)
        local asleep = H.hurt_line(T, 2)
        W.p[2].dormant = false
        T.tick(5)
        local n5 = T.count("dbg uyandi:", m)
        W.real_off = W.real_off + 6
        W.p[3].dormant = true
        T.tick(64)
        W.sees[3] = 60
        W.p[3].dormant = false
        T.tick(5)
        local dbg3 = H.bare(T.printed("dbg uyandi: Bravo", m))
        T.tick(140)
        local late = H.hurt_line(T, 3)
        T.shutdown()
        local _, tl = H.teshis(T)
        H.check("T-DLOG-13", base ~= nil and not H.has(base, "uyandi") and not H.has(base, "uykuda")
            and woke ~= nil and woke:find("uyandi 0%.2%ds once") ~= nil and H.has(asleep, ", uykuda)")
            and late ~= nil and not H.has(late, "uyandi"), "vuruldun satiri: uyanmadan 0.2 sn sonra 'uyandi 0.2Xs once' ("
            .. tostring(woke and woke:match("uyandi [%d%.]+s once")) .. "), dormant saldiran 'uykuda' ("
            .. tostring(H.has(asleep, ", uykuda)")) .. "), hic uyumayan / 2 sn'den eski uyanma etiketsiz")
        H.check("T-DLOG-13", dbg == "dbg uyandi: Alpha 500 u, 2.0 sn uyudu, ilk gorus gormuyor" and n5 == 1
            and dbg3 == "dbg uyandi: Bravo 500 u, 1.0 sn uyudu, ilk gorus goruyor", "dbg uyandi: " .. tostring(dbg)
            .. "; 5 sn icinde ikinci uyanma satirsiz (" .. n5 .. "); goren dusman: " .. tostring(dbg3))
        H.check("T-DLOG-13", tl ~= nil and H.has(tl, "uyanma 3 (1 sn icinde vurulma 2, uyaninca bekleme atlandi 0)"),
            "dbg teshis uyanma sayaclari: " .. tostring(tl and tl:match("uyanma.*$")))
    end)
    H.run("T-DLOG-11", function()
        local T = H.boot({ name = "dlog-11", pre = function(T, W)
            W.p[4] = H.mkplayer(4, "Charlie", -500, 0, 0, true, "ak47")
            W.p[5] = H.mkplayer(5, "Delta", 0, -500, 0, true, "ak47")
            W.p[6] = H.mkplayer(6, "Echo", 400, 400, 0, true, "ak47")
        end })
        T.tick(10)
        local t0 = T.W.tick + 1
        T.tick(40)
        local sum, mx, per = 0, 0, {}
        for t = t0, t0 + 39 do
            local n = 0
            for i in pairs(T.tb[t] or {}) do n = n + 1; per[i] = (per[i] or 0) + 1 end
            sum = sum + n
            if n > mx then mx = n end
        end
        local all = true
        for i = 2, 6 do if (per[i] or 0) < 8 then all = false end end
        local avg = sum / 40
        H.check("T-DLOG-11", avg <= 2.0 + 1e-9 and mx <= 3 and all, "5 dusman: tick basina ortalama " .. H.f1(avg)
            .. " (<= 2), en fazla " .. mx .. " (<= 3) dusmana iz; her dusman 4 tick'te bir taranir (" .. tostring(all) .. ")")
    end)
    H.run("T-DLOG-12", function()
        local T = H.boot({ name = "dlog-12", keep_afk = true })
        H.sweep(T)
        local kinds = {}
        for _, k in ipairs({ "dbg atis-detay:", "dbg vurulma-detay:", "dbg olum-detay:", "dbg kill-detay:", "dbg duello:",
            "dbg round sonu:", "dbg ===== round", "dbg ===== harita" }) do
            if T.printed(k) == nil then kinds[#kinds + 1] = k end
        end
        H.check("T-DLOG-12", #kinds == 0, "genis taramada her dbg satir turu var (eksik: " .. H.list(kinds, 8) .. ")")
    end)
end

-------------------------------------------------------------------------------
-- Misc / cizim
-------------------------------------------------------------------------------
function H.cv_writes(T, name)
    local n = 0
    for _, w in ipairs(T.cvw) do if w.n == name then n = n + 1 end end
    return n
end
function C.misc()
    H.run("T-MISC-1", function()
        local T = H.boot({ name = "misc-1" })
        local W = T.W
        T.tick(10)
        local a = W.cv.cl_righthand
        W.cv.cl_righthand = 1
        T.tick(130)
        local b = W.cv.cl_righthand
        T.shutdown()
        local c = W.cv.cl_righthand
        local U = H.boot({ name = "misc-1-okunmaz", pre = function(T, W) W.cvar_unreadable.cl_righthand = true end })
        U.tick(100)
        U.shutdown()
        local n = H.cv_writes(U, "cl_righthand")
        H.check("T-MISC-1", a == 0 and b == 0 and c == 1 and n == 0, "cl_righthand 1 -> 0 (" .. tostring(a) .. "), geri 1 olunca"
            .. " tekrar 0 (" .. tostring(b) .. "), SHUTDOWN'da 1 (" .. tostring(c) .. "); okunamayan cvar'a yazma yok (" .. n .. ")")
    end)
    H.run("T-MISC-2", function()
        local T = H.boot({ name = "misc-2" })
        T.tick(10)
        local a = T.W.cv.r_aspectratio
        T.set("aspect", 2)
        T.tick(70)
        local b = T.W.cv.r_aspectratio
        H.check("T-MISC-2", math.abs(a - 1.3333) < 0.001 and math.abs(b) < 1e-6, "4:3 -> r_aspectratio " .. H.f1(a)
            .. " (1.3333), Off -> asil deger 0 (" .. tostring(b) .. ")")
    end)
    H.run("T-MISC-3", function()
        local function buys(T)
            local n = 0
            for _, c in ipairs(T.cmds) do if c.s:find("buy hegrenade", 1, true) then n = n + 1 end end
            return n
        end
        local T = H.boot({ name = "misc-3" })
        T.tick(5)
        T.event("round_start", {})
        T.tick(40)
        local a = buys(T)
        T.event("round_start", {})
        T.tick(40)
        local b = buys(T)
        local U = H.boot({ name = "misc-3-native", pre = function(T, W)
            T.nat["misc/utility/buybot/enable"].value = true
            T.nat["misc/utility/buybot/grenades"].value = { true, false, true, true }
        end })
        U.tick(5)
        U.event("round_start", {})
        U.tick(40)
        local c = buys(U)
        H.check("T-MISC-3", a == 1 and b == 1 and c == 0, "round_start -> gecikmeyle bir 'buy hegrenade; ...' (" .. a
            .. "), 3 sn icinde ikinci round_start -> yine bir (" .. b .. "); native buybot HE+Smoke+Fire -> yok (" .. c .. ")")
    end)
    H.run("T-MISC-4", function()
        local T = H.boot({ name = "misc-4" })
        T.tick(64)
        local a = T.W.clantag
        T.set("clantag", false)
        T.tick(10)
        H.check("T-MISC-4", type(a) == "string" and a ~= "" and T.W.clantag == "", "clantag acikken '" .. tostring(a)
            .. "', kapaninca ''")
    end)
    H.run("T-MISC-5", function()
        local T = H.boot({ name = "misc-5" })
        local W = T.W
        T.tick(70)
        local bad = {}
        for _, c in ipairs(H.FPS_CVARS) do if W.cv[c] ~= 0 then bad[#bad + 1] = c end end
        local extra = H.cv_writes(T, "cl_csm_enabled") + H.cv_writes(T, "cl_disable_ragdolls")
        T.set("fps_ragdolls", true)
        T.tick(70)
        local rag = W.cv.cl_disable_ragdolls
        T.shutdown()
        local rest = {}
        for _, c in ipairs(H.FPS_CVARS) do if W.cv[c] ~= H.CVAR_DEF[c] then rest[#rest + 1] = c end end
        if W.cv.cl_disable_ragdolls ~= 0 then rest[#rest + 1] = "cl_disable_ragdolls" end
        H.check("T-MISC-5", #bad == 0 and extra == 0 and rag == 1 and #rest == 0, "FPS boost tam olarak GS'nin 13 cvar'i (0"
            .. " olmayan: " .. H.list(bad, 4) .. "), cl_csm_enabled / ragdoll yazilmaz (" .. extra .. "), ragdoll kutusu acik -> 1 ("
            .. tostring(rag) .. "), SHUTDOWN'da hepsi geri (" .. H.list(rest, 4) .. ")")
    end)
    H.run("T-MISC-6", function()
        local function inst(name, w)
            local T = H.boot({ name = name })
            local W = T.W
            W.p[1].weapon = H.weapon(w)
            T.tick(10)
            T.jump(300)
            T.tick(3)
            local held = T.natv("misc/main/movement/autostrafer")
            for _ = 1, 100 do
                T.tick(1)
                if W.p[1].ground then break end
            end
            T.tick(3)
            return T, held, T.natv("misc/main/movement/autostrafer")
        end
        local A, h1, r1 = inst("misc-6", "ssg08")
        local B, h2, r2 = inst("misc-6-awp", "awp")
        local n2 = B.script_writes("misc/main/movement/autostrafer")
        H.check("T-MISC-6", h1 == false and r1 == true and h2 == true and r2 == true and n2 == 0,
            "scout + duran ziplama: autostrafer kalkista false tutulur (" .. tostring(h1) .. "), iniste geri (" .. tostring(r1)
            .. "); AWP -> dokunulmaz (" .. n2 .. " yazma)")
        local _ = A
    end)
    H.run("T-MISC-7", function()
        local function says(T)
            local n = 0
            for _, c in ipairs(T.cmds) do if c.s:find("^say") then n = n + 1 end end
            return n
        end
        local T = H.boot({ name = "misc-7" })
        T.tick(5)
        T.event("player_death", { userid = 102, attacker = 101, weapon = "ssg08", headshot = true })
        T.tick(200)
        local U = H.boot({ name = "misc-7-acik" })
        U.set("trash_talk", true)
        U.tick(5)
        U.event("player_death", { userid = 102, attacker = 101, weapon = "ssg08", headshot = true })
        U.tick(200)
        H.check("T-MISC-7", says(T) == 0 and says(U) >= 1 and says(U) <= 3, "trash talk varsayilan kapali (" .. says(T) .. "), acik + sans 100 ->"
            .. " gecikmeyle bir blok 'say \"...\"' (" .. says(U) .. " satir)")
    end)
end
function C.draw()
    H.run("T-DRAW-WB", function()
        -- V1.0.11 duvar hatti: mermi izi 60, duz cizgi duvarla kapali -> sol listede "WB 60"; can 50 iken kirmizi;
        -- duvar yokken (acik gorus) WB yok; vuruldun satirinda "duvar hatti 60 hasar".
        local left = function(x) return x.x < 300 end
        local T = H.boot({ name = "draw-wb" })
        T.W.sees[2] = 60
        T.W.wall[2] = true
        T.tick(20)
        local wb = T.has_text(T.W.tick - 2, T.W.tick, "WB 60", left)
        local m = T.mark()
        T.hurt_me(2, 2, 30)
        T.tick(2)
        local line = T.printed("vuruldun:", m) or ""
        local col_y, col_r = nil, nil
        for _, x in ipairs(T.texts(T.W.tick - 1, T.W.tick, left)) do if x.s == "WB 60" then col_y = x.col end end
        T.W.p[1].health = 50
        T.tick(6)
        for _, x in ipairs(T.texts(T.W.tick - 1, T.W.tick, left)) do if x.s == "WB 60" then col_r = x.col end end
        local O = H.boot({ name = "draw-wb-acik" })
        O.W.sees[2] = 60
        O.tick(20)
        local none = true
        for _, x in ipairs(O.texts(O.W.tick - 3, O.W.tick, left)) do if x.s:find("^WB") then none = false end end
        local red = col_r ~= nil and col_y ~= nil and (col_r.r ~= col_y.r or col_r.g ~= col_y.g)
        H.check("T-DRAW-WB", wb and none and line:find("duvar hatti 60 hasar", 1, true) ~= nil and red, "duvar arkasindan 60 hasar: 'WB 60' ("
            .. tostring(wb) .. "), acik goruste WB yok (" .. tostring(none) .. "), can 50 iken renk degisir (" .. tostring(red)
            .. "), vuruldun: " .. line:sub(1, 200))
    end)
    H.run("T-DRAW-1", function()
        local left = function(x) return x.x < 300 end
        local T = H.boot({ name = "draw-1" })
        T.tick(5)
        local dt = false
        for _, x in ipairs(T.texts(T.W.tick - 3, T.W.tick, left)) do if x.s == "DT" or x.s:find("^DT[%s%d%%]") then dt = true end end
        local K = H.boot({ name = "draw-1-md", pre = function(T, W) H.knife_enemy(W, 2, 250) end })
        K.W.head_dmg[2] = 50
        K.tick(10)
        local md = K.has_text(K.W.tick - 3, K.W.tick, "MD 30", left)
        local A = H.boot({ name = "draw-1-airlc", rec_off = true, setup = function(T) T.set("air_teleport", false) end })
        A.tick(10)
        local airlc = false
        A.W.sees[2] = 60
        A.W.charge = 14
        A.jump(300)
        for _ = 1, 40 do
            A.tick(1)
            if A.has_text(A.W.tick, A.W.tick, "AIR LC", left) then airlc = true end
            if A.W.p[1].ground then break end
        end
        local O = H.boot({ name = "draw-1-kapali" })
        O.set("left_ind", false)
        O.tick(5)
        local none = #O.texts(O.W.tick - 2, O.W.tick, left) == 0
        H.check("T-DRAW-1", dt and md and airlc and none, "sol liste: DT (" .. tostring(dt) .. "), bicak kurali bu tick 'MD 30' ("
            .. tostring(md) .. "), havada kilitliyken 'AIR LC' (" .. tostring(airlc) .. "), kapaliyken hic yazi yok ("
            .. tostring(none) .. ")")
    end)
    H.run("T-DRAW-2", function()
        local T = H.boot({ name = "draw-2" })
        T.tick(10)
        local c = T.has_text(T.W.tick - 3, T.W.tick, "standing", function(x) return math.abs(x.x - 960) < 250 end)
        H.check("T-DRAW-2", c, "nisangah gostergeleri durum adini cizer (Standing)")
    end)
end

-------------------------------------------------------------------------------
-- Inceleme duzeltmeleri (V1.0.80 inis teleportu, merdiven, harita degisimi, R5 / R6 tabani, R10 tazelik, hafiza,
-- override tusu, defensive tetik kontrolu)
-------------------------------------------------------------------------------
function H.flight(T, vx, seen)
    local W = T.W
    W.sees[2] = seen and 60 or 0
    W.charge = W.max_charge
    W.p[1].vel = V.v3(vx, 0, 0)
    local u0 = #T.unch
    local t0 = W.tick
    T.jump(300)
    local tp = nil
    for _ = 1, 200 do
        T.tick(1)
        if tp == nil and #T.unch > u0 then tp = W.tick end
        if W.p[1].ground then break end
    end
    local land = W.tick
    T.tick(4)
    return { t0 = t0, tp = tp, land = land, n = #T.unch - u0 }
end
function C.review()
    H.run("T-EX-13", function()
        -- Varsayilan (Teleport in air + Air LC acik, DT): sarj inise saklanir, tek teleport inise 1..11 tick kala.
        local T = H.boot({ name = "ex-13-inis" })
        T.tick(40)
        local m = T.mark()
        local r = H.flight(T, 250, true)
        local left = r.tp and (r.land - r.tp) or -1
        local blk = T.calls_in(T.blk, r.t0, r.land)
        local sh = T.shifts(r.t0 + 1, r.land)
        local nj = r.tp ~= nil and (T.rmjump[r.tp] or 0) >= 1 and (T.rmjump[r.tp + 1] or 0) >= 1
            and (T.rmjump[r.tp + 2] or 0) >= 1
        local line = T.printed("teleport: inise ", m)
        H.check("T-EX-13", r.n == 1 and left >= 1 and left <= 12 and blk == 0 and sh == 0 and nj and line ~= nil
            and T.printed("havada goruldun", m) == nil,
            "goruldu + 250 u/s ziplama: tek uncharge (" .. r.n .. "), inise " .. left .. " tick kala (1..12), havada sarj kilidi"
            .. " yok (" .. blk .. "), ucusta defensive yok (" .. sh .. "), atis tick'i + 2 tick JUMP kaldirilir ("
            .. tostring(nj) .. "): " .. tostring(line))
        local S = H.boot({ name = "ex-13-yavas" })
        S.tick(40)
        local sm = S.mark()
        local rs = H.flight(S, 0, true)
        H.check("T-EX-13", rs.n == 0 and S.calls_in(S.blk, rs.t0, rs.land) == 0
            and S.printed("teleport: inise yok (yavas 3D", sm) ~= nil,
            "goruldu + yerinde ziplama (3D < 64 u): teleport yok (" .. rs.n .. "), DT havada dolu kalir, 'inise yok (yavas 3D'")
        local U = H.boot({ name = "ex-13-gorulmedi" })
        U.tick(40)
        local ru = H.flight(U, 250, false)
        local ush = U.shifts(ru.t0 + 1, ru.land)
        H.check("T-EX-13", ru.n == 0 and ush == 0, "gorulmeyen DT'li ucus: teleport yok (" .. ru.n .. "), air lag / Smart"
            .. " defensive yok, sarj teleporta kalir (" .. ush .. ")")
        -- X14 sadece Smart'ta (GS): eski yolda (Teleport in air kapali) Air durumu Off iken air lag zorlamaz.
        local function airlag(name, edge)
            local O = H.boot({ name = name .. "-off", rec_off = true, setup = function(T)
                T.set("air_teleport", false); T.xset("Air", "Defensive", 1); T.xset("Air crouch", "Defensive", 1)
                if not edge then H.edge_off(T) end
            end })
            O.tick(40)
            local ro = H.flight(O, 0, false)
            local Sm = H.boot({ name = name .. "-smart", rec_off = true, setup = function(T)
                T.set("air_teleport", false)
                if not edge then H.edge_off(T) end
            end })
            Sm.W.p[2].origin = V.v3(5000, 0, 0); Sm.W.p[3].origin = V.v3(0, 5000, 0)
            Sm.tick(40)
            local rm = H.flight(Sm, 0, false)
            local _, oall = O.shifts(ro.t0 + 1, ro.land)
            local _, mall = Sm.shifts(rm.t0 + 1, rm.land)
            return O.shifts(ro.t0 + 2, ro.land - 1), Sm.shifts(rm.t0 + 2, rm.land - 1), oall, mall
        end
        local osh, msh = airlag("ex-13", false)
        H.check("T-EX-13", osh == 0 and msh >= 10, "def_edge kapali: air lag sadece Smart'ta: Air durumu Off -> " .. osh
            .. " tetik; Smart (kimse yakin degil) -> " .. msh .. " tetik")
        -- Varsayilan (def_edge acik): Off -> ucusun tamaminda 0; Smart -> ucus basina tam 1.
        local _, _, eo, em = airlag("ex-13-olay", true)
        H.check("T-EX-13", eo == 0 and em == 1, "varsayilan: air lag sadece Smart'ta: Air durumu Off -> " .. eo
            .. " zorlama (0); Smart (kimse yakin degil) -> ucusta " .. em .. " (1)")
    end)
    H.run("T-EX-14", function()
        -- Merdiven hava sayilmaz: Air LC / teleport / air lag / tam choke / jump scout yok.
        local function ladder(T, W)
            W.p[1].ground = false; W.p[1].air_phys = false; W.p[1].movetype = 9; W.p[1].vel = V.v3(0, 0, 150)
        end
        local A = H.boot({ name = "ex-14-gorulen" })
        A.tick(30)
        A.W.sees[2] = 60
        local t0 = A.W.tick
        local u0 = #A.unch
        A.tick(60, ladder)
        local an, ab = #A.unch - u0, A.calls_in(A.blk, t0, A.W.tick)
        local fl = H.frac(A.recs(t0 + 2, A.W.tick), function(r) return r.fakelag == true end)
        local sw = A.script_writes("misc/main/movement/autostrafer")
        -- def_edge kapali (her tick) ve acik (ucus basina bir, ilk tick dahil): merdivende air lag yok.
        local bs = 0
        for _, edge in ipairs({ false, true }) do
            local B = H.boot({ name = "ex-14-uzak-" .. tostring(edge), rec_off = true,
                setup = function(T) if not edge then H.edge_off(T) end end })
            B.W.p[2].origin = V.v3(5000, 0, 0); B.W.p[3].origin = V.v3(0, 5000, 0)
            B.tick(30)
            local b0 = B.W.tick
            B.tick(60, ladder)
            local _, n = B.shifts(b0 + (edge and 1 or 2), B.W.tick)
            bs = bs + n
        end
        H.check("T-EX-14", an == 0 and ab == 0 and fl < 0.5 and sw == 0 and bs == 0, "merdivende (m_MoveType 9, yerde degil):"
            .. " goruluyorken uncharge " .. an .. ", sarj kilidi " .. ab .. ", tam choke %" .. H.f1(fl * 100) .. ", autostrafer"
            .. " yazimi " .. sw .. "; kimse yakin degilken air lag tetigi (def_edge kapali + acik) " .. bs)
    end)
    H.run("T-EX-15", function()
        -- Harita degisimi: tickcount bastan baslar; eski Smart tutma / anti-peek tick'leri yeni haritada surmez.
        -- Eski yolda (def_edge kapali) bakilir: orada Smart tutma / anti-peek penceresi her tick zorlar.
        local T = H.boot({ name = "ex-15", tick = 150000, rec_off = true, setup = H.edge_off })
        local W = T.W
        W.sees[2] = 60
        T.tick(40)
        W.sees[2] = 0
        W.p[2].origin = V.v3(5000, 0, 0); W.p[3].origin = V.v3(0, 5000, 0)
        T.tick(20)
        local back = W.tick - 10000
        W.real_off = W.real_off + back * W.interval
        W.tick = 10000
        T.event("game_newmap", { mapname = "de_nuke" })
        T.tick(40)
        local a = T.shifts(10001, 10040)
        -- game_newmap gelmese de: yerel oyuncu bir kare yok, sonra tick geri.
        local U = H.boot({ name = "ex-15-olaysiz", tick = 150000, rec_off = true, setup = H.edge_off })
        local Wu = U.W
        Wu.sees[2] = 60
        U.tick(40)
        Wu.sees[2] = 0
        Wu.p[2].origin = V.v3(5000, 0, 0); Wu.p[3].origin = V.v3(0, 5000, 0)
        U.tick(5)
        Wu.real_off = Wu.real_off + (Wu.tick - 10000) * Wu.interval
        Wu.tick = 10000
        U.tick(40)
        local b = U.shifts(10001, 10040)
        H.check("T-EX-15", a == 0 and b == 0, "yeni haritada (tick 150000 -> 10000) kimse gormuyor / yakin degil: Smart tetigi"
            .. " game_newmap ile " .. a .. ", olaysiz (tick geri) " .. b)
        -- Varsayilan (def_edge acik): eski haritanin son zorlama tick'i (X.shift_last) yeni haritada GAP'i kilitlemez;
        -- yeni haritadaki ilk gorus yine tek zorlama (game_newmap ile ve olaysiz).
        local function fresh(name, event)
            local F = H.boot({ name = name, tick = 150000 })
            local Wf = F.W
            Wf.sees[2] = 60
            F.tick(40)
            local old = H.shift_all(F)
            Wf.sees[2] = 0
            F.tick(5)
            Wf.real_off = Wf.real_off + (Wf.tick - 10000) * Wf.interval
            Wf.tick = 10000
            if event then F.event("game_newmap", { mapname = "de_nuke" }) end
            F.tick(10)
            Wf.sees[2] = 60
            F.tick(100)
            local _, new = F.shifts(10001, 10200)
            return old, new
        end
        local o1, n1 = fresh("ex-15-olay", true)
        local o2, n2 = fresh("ex-15-olay-olaysiz", false)
        H.check("T-EX-15", o1 == 1 and n1 == 1 and o2 == 1 and n2 == 1, "varsayilan: eski haritada " .. o1 .. " / " .. o2
            .. " zorlama (1), yeni haritada (tick geri) ilk gorus yine " .. n1 .. " (game_newmap) / " .. n2 .. " (olaysiz)")
    end)
    H.run("T-EX-16", function()
        -- force_anti_exploit_shift cagrilabilir ama 'function' olmayan bir nesne olsa da defensive acik kalir.
        local function callable(name, edge)
            local T = H.boot({ name = name, rec_off = true, pre = function(T, W)
                T.EX.force_anti_exploit_shift = setmetatable({}, { __call = function() T.shift[W.tick] = (T.shift[W.tick] or 0) + 1 end })
            end, setup = function(T) if not edge then H.edge_off(T) end end })
            T.W.sees[2] = 60
            T.tick(40)
            return T, T.shifts(T.W.tick - 30, T.W.tick), H.shift_all(T)
        end
        local T, n = callable("ex-16", false)
        H.check("T-EX-16", n >= 20 and T.printed("defensive yok", 1) == nil, "def_edge kapali: cagrilabilir tablo olarak"
            .. " defensive tetigi: Smart + goruluyor -> " .. n .. "/31 tick, '(defensive yok' yazilmaz")
        local Te, _, all = callable("ex-16-olay", true)
        H.check("T-EX-16", all == 1 and Te.printed("defensive yok", 1) == nil, "varsayilan: cagrilabilir tablo olarak"
            .. " defensive tetigi: Smart + goruluyor 40 tick -> " .. all .. " zorlama (1)")
    end)
    H.run("T-TRK-1", function()
        -- V1.0.7: tick sayaci 14 tick geri gidince (kendi tickbase kaymamiz) dusmanlar "uyandi" sayilmaz.
        local A = H.boot({ name = "trk-1-geri" })
        A.W.sees[2] = 60
        A.tick(100)
        A.W.tick = A.W.tick - 14
        A.tick(40)
        H.check("T-TRK-1", A.count("dbg uyandi") == 0, "tick 14 geri gitti: 'dbg uyandi' " .. A.count("dbg uyandi") .. " (0)")
        local B = H.boot({ name = "trk-1-ham" })
        B.W.sees[2] = 60
        B.tick(400)
        H.check("T-TRK-1", B.count("aa: desync olcumu ham:") >= 1 or B.count("aa: desync isareti") == 0,
            "desync olcumu bittiginde ham sayi satiri yazilir (" .. B.count("aa: desync olcumu ham:") .. ")")
    end)

    H.run("T-EX-22", function()
        -- V1.0.12 vur-kac: autopeek basili + scout atisi -> 1-12 tick icinde tek force_uncharge + log; autopeek yokken,
        -- ayar kapaliyken yok; sarj 0 ise uyari (bir kez), uncharge yok.
        local function inst(name, setup)
            local T = H.boot({ name = name, rec_off = true })
            local W = T.W
            W.charge = 14
            if setup then setup(T, W) end
            T.tick(10)
            if W.auto_recharge == false then W.charge = 0 end
            local u0 = #T.unch
            local t0 = W.tick
            T.shoot(2)
            T.tick(16)
            return T, #T.unch - u0, (T.unch[#T.unch] or t0) - t0
        end
        local A, a, at = inst("ex-22-peek", function(T, W) W.keys.autopeek = true; W.autopeek_pos = H.V.v3(0, 0, 0) end)
        local _, b = inst("ex-22-tussuz")
        local _, c = inst("ex-22-kapali", function(T, W)
            W.keys.autopeek = true; W.autopeek_pos = H.V.v3(0, 0, 0); T.set("ideal_tick", false)
        end)
        local D, d = inst("ex-22-sarjsiz", function(T, W)
            W.keys.autopeek = true; W.autopeek_pos = H.V.v3(0, 0, 0); W.auto_recharge = false; W.charge = 0
        end)
        H.check("T-EX-22", a == 1 and at >= 1 and at <= 12 and A.count("ideal tick: atistan") == 1 and b == 0 and c == 0,
            "autopeek + scout atisi: " .. a .. " uncharge (1), atistan " .. at .. " tick sonra (1-12), log "
            .. A.count("ideal tick: atistan") .. "; autopeek yok: " .. b .. " (0); ayar kapali: " .. c .. " (0)")
        H.check("T-EX-22", d == 0 and D.count("ideal tick: atistan sonra sarj yok") == 1, "sarj 0: uncharge " .. d
            .. " (0), uyari " .. D.count("ideal tick: atistan sonra sarj yok") .. " (1)")
    end)

    H.run("T-EX-21", function()
        -- V1.0.10: varsayilan def_repeat 16: gorulme surerken 16 tick'te bir zorlama; sadece yakin -> 0; 0 -> tek.
        local A = H.boot({ name = "ex-21-tekrar", def_repeat = true })
        A.W.sees[2] = 60
        A.tick(300)
        local a, at = H.shift_all(A)
        local gaps = #at >= 2
        for i = 2, #at do if at[i] - at[i - 1] < 16 then gaps = false end end
        local B = H.boot({ name = "ex-21-yakin", def_repeat = true })
        B.tick(300)
        local b = H.shift_all(B)
        H.check("T-EX-21", a >= 17 and a <= 20 and gaps and b == 0, "300 tick goruluyor, varsayilan tekrar 16: " .. a
            .. " zorlama (17-20), aralar >= 16 tick (" .. tostring(gaps) .. "); sadece yakin: " .. b .. " (0)")
    end)

    H.run("T-EX-20", function()
        -- V1.0.6 A1: mermi izi 0 ama dusman gozunden kafama duz cizgi acik -> goruyor sayilir (tek olay) + teshis G31.
        local A = H.boot({ name = "ex-20-cizgi" })
        A.W.open_line = { [2] = true }
        A.tick(300)
        local a = H.shift_all(A)
        H.check("T-EX-20", a == 1 and A.count("teshis: G31") == 1, "mermi izi 0, duz cizgi acik (300 tick): " .. a
            .. " zorlama (1), 'teshis: G31' " .. A.count("teshis: G31") .. " (1)")
        -- N2: yakinda (500 u) uyanan dusman (2 sn dormant) gormese de ilk gorus kenari: uyaninca tek zorlama.
        local B = H.boot({ name = "ex-20-uyanma" })
        B.tick(20)
        B.W.p[2].dormant = true
        B.tick(128)
        local b0 = H.shift_all(B)
        B.W.p[2].dormant = false
        B.tick(60)
        local b1 = H.shift_all(B)
        H.check("T-EX-20", b0 == 0 and b1 == 1, "dormant iken " .. b0 .. " zorlama (0); 500 u'da uyaninca " .. b1 .. " (1)")
        -- Uzakta (2500 u > NEAR) uyanan dusman kenar saymaz.
        local Cn = H.boot({ name = "ex-20-uzak" })
        Cn.W.p[2].origin.x, Cn.W.p[3].origin.x = 2500, 2600
        Cn.tick(20)
        Cn.W.p[2].dormant = true
        Cn.tick(128)
        Cn.W.p[2].dormant = false
        Cn.tick(60)
        local c = H.shift_all(Cn)
        H.check("T-EX-20", c == 0, "2500 u'da uyanan dusman: " .. c .. " zorlama (0)")
    end)

    H.run("T-EX-17", function()
        -- A1: zorlanan defensive bir OLAY. Smart (Standing, varsayilan), DT dolu, sahte shift sarji harcamaz.
        local A = H.boot({ name = "ex-17-surekli" })
        A.W.sees[2] = 60
        A.tick(300)
        local a, at = H.shift_all(A)
        H.check("T-EX-17", a == 1, "dusman 300 tick kesintisiz goruyor (Smart): force_anti_exploit_shift " .. a
            .. " kez (1; tick " .. table.concat(at, ",", 1, math.min(#at, 6)) .. ")")
        local B = H.boot({ name = "ex-17-yakin" })
        B.tick(300)
        local b = H.shift_all(B)
        H.check("T-EX-17", b == 0, "dusman 300 tick sadece yakin (500 u, gormuyor): " .. b .. " zorlama (0)")
        local Cn = H.boot({ name = "ex-17-kayip" })
        Cn.W.sees[2] = 60
        Cn.tick(100)
        local c1 = H.shift_all(Cn)
        Cn.W.sees[2] = 0
        Cn.tick(100)
        local c2 = H.shift_all(Cn)
        Cn.W.sees[2] = 60
        Cn.tick(100)
        local c3 = H.shift_all(Cn)
        H.check("T-EX-17", c1 == 1 and c2 == 1 and c3 == 2, "goruldu (100 tick) -> " .. c1 .. " (1), 100 tick kayip -> " .. c2
            .. " (1), yeniden goruldu (100 tick) -> " .. c3 .. " (2)")
        -- anti-peek kapali: ayni olay "smart" sebebiyle (yukselen kenar), yine tek.
        local S = H.boot({ name = "ex-17-smart", rec_off = true, setup = function(T) T.set("anti_peek", false) end })
        S.W.sees[2] = 60
        S.tick(300)
        local sn = H.shift_all(S)
        H.check("T-EX-17", sn == 1 and S.count("def: shift (smart) | sarj 14/14") == 1, "anti-peek kapali: 300 tick goruluyor -> "
            .. sn .. " zorlama (1), 'def: shift (smart) | sarj 14/14' " .. S.count("def: shift (smart)"))
        -- Bicakli dusman menzilde: tekrar eder, GAP 32.
        local K = H.boot({ name = "ex-17-bicak" })
        K.tick(20)
        local k0 = K.W.tick
        H.knife_enemy(K.W, 3, 200)
        K.tick(128)
        local kn, kt = H.shift_all(K)
        local even = #kt == 4
        for i = 2, #kt do if kt[i] - kt[i - 1] ~= 32 then even = false end end
        H.check("T-EX-17", kn == 4 and even and kt[1] ~= nil and kt[1] - k0 <= 2, "bicakli dusman 128 tick 200 birimde: " .. kn
            .. " zorlama (4), araliklar 32 tick (" .. tostring(even) .. "; tick " .. table.concat(kt, ",") .. ", baslangic "
            .. k0 .. ")")
        -- def_edge kapali: eski her-tick sayisi (V1.0.4 ile ayni sahnede 302: 2 isinma + 300 tick, her biri).
        local O = H.boot({ name = "ex-17-kapali", rec_off = true, setup = H.edge_off })
        O.W.sees[2] = 60
        O.tick(300)
        local on = H.shift_all(O)
        H.check("T-EX-17", on == H.OLD_SEEN_300, "def_edge kapali: 300 tick goruluyor -> " .. on .. " zorlama (eski davranis: "
            .. H.OLD_SEEN_300 .. ")")
    end)
    H.run("T-EX-18", function()
        -- A1 log: zorlama satiri, sarj harcanmadi (sahte shift sarja dokunmaz; haritada en fazla 3), sarj dolum suresi.
        local T = H.boot({ name = "ex-18-harcamadi" })
        local W = T.W
        T.tick(10)
        local m = T.mark()
        H.knife_enemy(W, 3, 200)
        T.tick(170)
        local sh = H.shift_all(T)
        local l1 = T.count("def: shift (knife) | sarj 14/14", m)
        local l2 = T.count("def: shift sarj harcamadi (knife)", m)
        local l3 = T.count("tick sonra doldu", m)
        T.event("game_newmap", { mapname = "de_nuke" })
        W.map = "de_nuke"
        local m2 = T.mark()
        T.tick(40)
        local again = T.count("def: shift sarj harcamadi (knife)", m2)
        H.check("T-EX-18", sh == 6 and l1 == 6 and l2 == 3 and l3 == 0 and again >= 1, "sarji harcamayan shift: " .. sh
            .. " zorlama (6), 'def: shift (knife) | sarj 14/14' " .. l1 .. " (6), 'def: shift sarj harcamadi (knife)' " .. l2
            .. " (haritada en fazla 3), 'doldu' " .. l3 .. "; yeni haritada yine yazilir (" .. again .. ")")
        -- Sarji harcayan shift: cagri sarji sifirlar, tick basina 1 dolar -> 14 tick sonra dolu.
        local D = H.boot({ name = "ex-18-doldu", pre = function(T, W)
            T.EX.force_anti_exploit_shift = function()
                T.shift[W.tick] = (T.shift[W.tick] or 0) + 1
                W.charge = 0
            end
        end })
        local Wd = D.W
        D.tick(10)
        D.event("round_start", {})
        local dm = D.mark()
        Wd.sees[2] = 60
        D.tick(60)
        local dn = H.shift_all(D)
        local a = D.count("def: shift (peek) | sarj 14/14", dm)
        local b = D.count("def: sarj 14 tick sonra doldu (peek)", dm)
        local c = D.count("harcamadi", dm)
        D.event("round_start", {})
        local line = D.printed("dbg sen ozeti:", dm)
        H.check("T-EX-18", dn == 1 and a == 1 and b == 1 and c == 0 and H.has(line, " | shift 1, dolum ort 14.0t"),
            "sarji harcayan shift: " .. dn .. " zorlama (1), 'def: shift (peek) | sarj 14/14' " .. a
            .. ", 'def: sarj 14 tick sonra doldu (peek)' " .. b .. ", 'harcamadi' " .. c .. "; sen ozeti: " .. tostring(line))
        -- Detailed log kapali: uc satir da yazilmaz (zorlama yine olur).
        local Q = H.boot({ name = "ex-18-sessiz", setup = function(T) T.set("debug_log", false) end })
        Q.W.sees[2] = 60
        Q.tick(40)
        H.check("T-EX-18", H.shift_all(Q) == 1 and Q.count("def: shift") == 0, "Detailed log kapali: zorlama " .. H.shift_all(Q)
            .. " (1), 'def: shift' satiri " .. Q.count("def: shift") .. " (0)")
    end)
    H.run("T-EX-19", function()
        -- A1: diger sebepler. Silah degisimi (yukselen kenar, GAP 64).
        local Sw = H.boot({ name = "ex-19-silah" })
        local W = Sw.W
        Sw.tick(20)
        W.p[1].weapon = H.weapon("deagle")
        Sw.tick(100)
        local s1 = H.shift_all(Sw)
        W.p[1].weapon = H.weapon("ssg08")
        Sw.tick(100)
        local s2 = H.shift_all(Sw)
        H.check("T-EX-19", s1 == 1 and s2 == 2 and Sw.count("def: shift (switch)") == 2, "silah degisimi (0.5 sn suren istek):"
            .. " degisim basina tek zorlama (" .. s1 .. " / " .. s2 .. "; beklenen 1 / 2)")
        -- Always on: tekrar eder, GAP 64.
        local Al = H.boot({ name = "ex-19-always", rec_off = true, setup = function(T) T.xset("Standing", "Defensive", 4) end })
        Al.tick(260)
        local an, at = H.shift_all(Al)
        local a64 = #at >= 4
        for i = 2, #at do if at[i] - at[i - 1] ~= 64 then a64 = false end end
        H.check("T-EX-19", a64 and an == #at, "Always on 262 tick: " .. an .. " zorlama, hepsi 64 tick arayla (" .. tostring(a64)
            .. "; tick " .. table.concat(at, ",") .. ")")
        -- Tick based 4: tick % 4 == 0 ve en az 14 tick ara -> 16 tick'te bir.
        local Tk = H.boot({ name = "ex-19-tick", rec_off = true, setup = function(T)
            T.xset("Standing", "Defensive", 5); T.xset("Standing", "Defensive every", 4)
        end })
        Tk.tick(160)
        local tn, tt = H.shift_all(Tk)
        local t16 = #tt >= 9
        for i = 2, #tt do if tt[i] - tt[i - 1] ~= 16 then t16 = false end end
        H.check("T-EX-19", t16 and tn == #tt, "Tick based 4, 162 tick: " .. tn .. " zorlama, hepsi 16 tick arayla (max(14, 4) ve"
            .. " tick % 4; " .. tostring(t16) .. "; tick " .. table.concat(tt, ",", 1, math.min(#tt, 5)) .. ")")
        -- On peek: tarama dizisi (HITSCAN her tick) -> dizinin basinda tek; 10 tick ara yeni dizi degil, 20 tick ara yeni dizi.
        local Sc = H.boot({ name = "ex-19-tarama", rec_off = true, setup = function(T) T.xset("Standing", "Defensive", 2) end })
        local Ws = Sc.W
        Sc.tick(20)
        Ws.scan[2] = true
        Sc.tick(100)
        local c1 = H.shift_all(Sc)
        Ws.scan[2] = false; Sc.tick(10); Ws.scan[2] = true; Sc.tick(60)
        local c2 = H.shift_all(Sc)
        Ws.scan[2] = false; Sc.tick(20); Ws.scan[2] = true; Sc.tick(60)
        local c3 = H.shift_all(Sc)
        H.check("T-EX-19", c1 == 1 and c2 == 1 and c3 == 2, "On peek + 100 tick tarama: " .. c1 .. " zorlama (1); 10 tick aradan"
            .. " sonra " .. c2 .. " (1); 20 tick (> 16) aradan sonra " .. c3 .. " (2)")
        -- Hizli dusman (goruyor, > 150 u/s) yukselen kenari: gorulme surerken yeni olay.
        local F = H.boot({ name = "ex-19-hizli" })
        local Wf = F.W
        Wf.sees[2] = 60
        F.tick(80)
        local f1 = H.shift_all(F)
        Wf.p[2].vel = V.v3(0, 200, 0)
        F.tick(80)
        local f2 = H.shift_all(F)
        H.check("T-EX-19", f1 == 1 and f2 == 2, "goruluyor (80 tick) -> " .. f1 .. " (1); goren dusman 200 u/s'ye cikti, 80 tick"
            .. " hizli kaldi -> " .. f2 .. " (2)")
        -- AFK: tekrar eder, GAP 64.
        local Af = H.boot({ name = "ex-19-afk", setup = function(T) T.set("afk", true) end })
        Af.tick(260)
        local fn, ft = H.shift_all(Af)
        local f64 = #ft >= 3
        for i = 2, #ft do if ft[i] - ft[i - 1] < 64 then f64 = false end end
        H.check("T-EX-19", f64 and fn == #ft and Af.count("def: shift (afk)") >= 3, "AFK 262 tick: " .. fn .. " zorlama, aralar"
            .. " >= 64 tick (" .. tostring(f64) .. "; tick " .. table.concat(ft, ",") .. "), 'def: shift (afk)' "
            .. Af.count("def: shift (afk)"))
        -- AI peek: yuruyus basina bir (GAP 48); eski yolda yuruyus boyunca her tick.
        local Pk = H.boot({ name = "ex-19-aipeek" })
        H.peek_world(Pk, Pk.W)
        Pk.tick(400)
        local pn, pt = H.shift_all(Pk)
        local p48 = #pt >= 1
        for i = 2, #pt do if pt[i] - pt[i - 1] < 48 then p48 = false end end
        H.check("T-EX-19", p48 and pn == #pt and Pk.count("def: shift (aipeek)") >= 1, "AI peek 400 tick: " .. pn
            .. " zorlama, aralar >= 48 tick (" .. tostring(p48) .. "; tick " .. table.concat(pt, ",") .. "), 'def: shift (aipeek)' "
            .. Pk.count("def: shift (aipeek)"))
    end)
    H.run("T-RAGE-27", function()
        -- N1: uyanma LC degil. Dusman 2 sn dormant, 300 birim otede yeniden gorunur: bekleme / ignore_target yok.
        local T = H.boot({ name = "rage-27" })
        local W = T.W
        W.head_dmg[2] = 50
        T.tick(30)
        W.p[2].dormant = true
        T.tick(128)
        W.p[2].origin = V.v3(500, 300, 0)
        W.p[2].dormant = false
        local t0 = W.tick
        local m = T.mark()
        T.tick(40)
        local ign = T.ignored(2, t0 + 1, t0 + 40)
        local off = H.any(T.hsr(2, t0 + 1, t0 + 40), H.all_off)
        local id = T.shoot(2)
        T.tick(1)
        T.hit(id, { hg = 2, dmg = 20, no_event = true })
        T.tick(2)
        local det = T.printed("dbg atis-detay:", m)
        H.check("T-RAGE-27", ign == 0 and not off and det ~= nil and det:find("LC", 1, true) == nil
            and T.count("gercek kayit beklendi", m) == 0, "2 sn dormant + 300 u otede uyanma: ignore_target " .. ign
            .. " (0), grup kapatma " .. tostring(off) .. ", kayitta LC yok: " .. tostring(det))
        -- Uyanmadan sonraki 32 tick icinde defensive: bekleme baslamaz (teshis sayaci); 32 tick'ten sonra baslar.
        local U = H.boot({ name = "rage-27-def" })
        local Wu = U.W
        Wu.head_dmg[2] = 50
        U.tick(30)
        Wu.p[2].dormant = true
        U.tick(128)
        Wu.p[2].dormant = false
        U.tick(5)
        local u0 = Wu.tick
        Wu.p[2].sim_shift = 6
        U.tick(1)
        Wu.p[2].sim_shift = 0
        U.tick(40)
        local early = U.ignored(2, u0 + 1, u0 + 30)
        local u1 = Wu.tick
        Wu.p[2].sim_shift = 6
        U.tick(1)
        Wu.p[2].sim_shift = 0
        U.tick(30)
        local late = U.ignored(2, u1 + 1, u1 + 12)
        U.shutdown()
        local _, tl = H.teshis(U)
        H.check("T-RAGE-27", early == 0 and late >= 3 and H.has(tl, "uyanma 1 (1 sn icinde vurulma 0, uyaninca bekleme atlandi 1)"),
            "uyanmadan 5 tick sonra sahte kayit: bekleme yok (" .. early .. "); 46 tick sonra: bekleme var (" .. late
            .. "); teshis: " .. tostring(tl and tl:match("uyanma.*$")))
    end)
    H.run("T-RAGE-28", function()
        -- N1: LC (64 birimden uzun atlama, sim zamani ileri) gercek kayit beklemesi baslatmaz; defensive baslatir.
        local T = H.boot({ name = "rage-28-lc" })
        local W = T.W
        W.head_dmg[2] = 50
        T.tick(30)
        local t0 = W.tick
        local m = T.mark()
        W.p[2].origin = V.v3(500, 200, 0)
        T.tick(30)
        local lc = T.ignored(2, t0 + 1, t0 + 30)
        local id = T.shoot(2)
        T.tick(1)
        T.hit(id, { hg = 2, dmg = 20, no_event = true })
        T.tick(2)
        W.p[2].origin = V.v3(500, 400, 0)
        T.tick(2)
        local id2 = T.shoot(2)
        T.tick(1)
        T.hit(id2, { hg = 2, dmg = 20, no_event = true })
        T.tick(2)
        local seen_lc = false
        for _, l in ipairs(H.lines_with(T, "dbg atis-detay:", m)) do if l:find("LC", 1, true) then seen_lc = true end end
        -- Iki atistan sonra 1.5 sn "duello" (bekleme yok) gecsin.
        local t1 = W.tick + 120
        T.tick(120)
        W.p[2].sim_shift = 6
        T.tick(1)
        W.p[2].sim_shift = 0
        T.tick(30)
        local def = T.ignored(2, t1 + 1, t1 + 12)
        H.check("T-RAGE-28", lc == 0 and seen_lc and def >= 3, "LC (200 u atlama, sim ileri; kayitta LC " .. tostring(seen_lc)
            .. "): bekleme yok (" .. lc .. "); sim zamani geri gidince bekleme var (" .. def .. ")")
        -- Dogrulama (gercek kayittan sonraki 3 tick) siniri asamaz: 13 tick sahte + dogrulama -> 14'te biter.
        local L = H.boot({ name = "rage-28-sinir" })
        local Wl = L.W
        Wl.head_dmg[2] = 50
        L.tick(30)
        local lm = L.mark()
        local l0 = Wl.tick
        Wl.p[2].sim_shift = 14
        L.tick(1)
        Wl.p[2].sim_shift = 0
        L.tick(40)
        local line = H.bare(L.printed("gercek kayit beklendi", lm))
        local span = L.ignored(2, l0 + 1, l0 + 40)
        H.check("T-RAGE-28", line == "resolver: Alpha sahte kayitta (defensive): 14 tick gercek kayit beklendi, sinir doldu"
            .. " (gercek kayit dogrulanirken)" and span <= 15, "13 tick sahte kayit + dogrulama: " .. tostring(line)
            .. " (ignore_target " .. span .. " tick)")
        -- 15 sn'lik satir siniri: yazilmayan beklemeler sonraki satira "(N kez)" olarak eklenir.
        local function episode(T, W)
            W.p[2].sim_shift = 6
            T.tick(1)
            W.p[2].sim_shift = 0
            T.tick(60)
        end
        local R = H.boot({ name = "rage-28-kez" })
        R.W.head_dmg[2] = 50
        R.tick(30)
        local rm = R.mark()
        episode(R, R.W); episode(R, R.W)
        local first = R.count("gercek kayit beklendi", rm)
        R.W.real_off = R.W.real_off + 16
        episode(R, R.W)
        local lines = H.lines_with(R, "gercek kayit beklendi", rm)
        H.check("T-RAGE-28", first == 1 and #lines == 2 and lines[1]:find(" kez)", 1, true) == nil
            and lines[2]:sub(-8) == " (2 kez)", "15 sn icinde 2 bekleme -> " .. first .. " satir; 16 sn sonra 3. bekleme: "
            .. tostring(lines[2]))
    end)
    H.run("T-RAGE-29", function()
        -- Takip tick basina dusman basina bir kez (SETUP_COMMAND yedegi + NET_UPDATE ayni tick'te iki ornek almaz).
        local T = H.boot({ name = "rage-29" })
        local W = T.W
        local t0 = W.tick
        T.tick(50)
        local mx, mn = 0, 99
        for t = t0 + 1, W.tick do
            local n = (T.simreads[2] or {})[t] or 0
            mx, mn = math.max(mx, n), math.min(mn, n)
        end
        H.check("T-RAGE-29", mx == 1 and mn == 1, "NET_UPDATE calisirken dusman 2'nin sim zamani tick basina " .. mn .. ".."
            .. mx .. " kez okunur (1)")
        -- NET_UPDATE hic gelmezse yedek her tick calisir (iki tick'te bir degil) ve defensive yine yakalanir.
        local F = H.boot({ name = "rage-29-yedek", pre = function(T, W) W.no_net = true end })
        local Wf = F.W
        Wf.head_dmg[2] = 50
        local f0 = Wf.tick
        F.tick(50)
        local fx, fn = 0, 99
        for t = f0 + 1, Wf.tick do
            local n = (F.simreads[2] or {})[t] or 0
            fx, fn = math.max(fx, n), math.min(fn, n)
        end
        local f1 = Wf.tick
        Wf.p[2].sim_shift = 6
        F.tick(1)
        Wf.p[2].sim_shift = 0
        F.tick(20)
        local held = F.ignored(2, f1 + 1, f1 + 10)
        H.check("T-RAGE-29", fx == 1 and fn == 1 and held >= 3, "NET_UPDATE yokken yedek: tick basina " .. fn .. ".." .. fx
            .. " ornek (1), sahte kayit beklemesi " .. held .. " tick")
    end)
    H.run("T-RAGE-19", function()
        -- R5 / R6 tabani (GS ext_why): yerde, govde >= 60, govde oldurmuyor; yoksa kafa acik, MD dokunulmaz.
        local A = H.boot({ name = "rage-19-duvar" })
        A.W.head_dmg[2] = 50; A.W.body_dmg[2] = 25
        A.tick(10)
        H.ext_misses(A, 2, 3)
        A.tick(10)
        local a1, a2 = H.any(A.hsr(2, 0), function(r) return H.head_off(r) and not H.all_off(r) end), H.has_md(A.hsr(2, 0), 24)
        local B = H.boot({ name = "rage-19-havada" })
        B.W.head_dmg[2] = 50; B.W.body_dmg[2] = 60
        B.tick(10)
        H.ext_misses(B, 2, 3)
        B.W.p[2].ground = false
        local b0 = B.W.tick
        B.tick(10, function(T, W) W.p[2].ground = false end)
        local b1 = H.any(B.hsr(2, b0 + 1), function(r) return H.head_off(r) and not H.all_off(r) end)
        local b2 = H.has_md(B.hsr(2, b0 + 1), 59)
        B.W.p[2].ground = true
        B.tick(6)
        local b3 = H.any(B.hsr(2, B.W.tick - 3), H.head_off) and H.has_md(B.hsr(2, B.W.tick - 3), 59)
        local Cn = H.boot({ name = "rage-19-saklayan" })
        Cn.W.head_dmg[2] = 50; Cn.W.body_dmg[2] = 60
        Cn.tick(10)
        for _, k in ipairs({ "H", "B", "M", "B", "H", "B", "M", "B", "H", "B", "M", "B" }) do
            local id = Cn.shoot(2, { hg = 1, hc = 75 })
            Cn.tick(2)
            if k == "H" then Cn.hit(id, { hg = 1, dmg = 50 })
            elseif k == "B" then Cn.hit(id, { hg = 2, dmg = 30 })
            else Cn.miss(id, "resolver") end
            Cn.tick(3)
        end
        Cn.W.body_dmg[2] = 0
        local c0 = Cn.W.tick
        Cn.tick(10)
        local c1 = H.any(Cn.hsr(2, c0 + 2), H.head_off)
        H.check("T-RAGE-19", not a1 and not a2 and not b1 and not b2 and b3 and not c1, "extended + govde 25 (duvar): kafa"
            .. " kapanmaz (" .. tostring(not a1) .. "), MD 24 yazilmaz (" .. tostring(not a2) .. "); havadaki hedefe yok ("
            .. tostring(not (b1 or b2)) .. "), yere inince var (" .. tostring(b3) .. "); kafa saklayan ama sadece kafa"
            .. " gorunuyor -> HEAD acik (" .. tostring(not c1) .. ")")
    end)
    H.run("T-RAGE-20", function()
        -- R5 serisi ardisik: govde isabeti sifirlar; 180 sn bittikten sonra tek iska yeniden baslatmaz.
        local A = H.boot({ name = "rage-20-govde" })
        A.W.head_dmg[2] = 50; A.W.body_dmg[2] = 60
        A.tick(10)
        for _, k in ipairs({ "M", "B", "M", "B", "M" }) do
            local id = A.shoot(2, { hg = 1, hc = 75 })
            A.tick(2)
            if k == "B" then A.hit(id, { hg = 2, dmg = 30 }) else A.miss(id, "resolver") end
            A.tick(3)
        end
        A.tick(5)
        local a = H.has_md(A.hsr(2, 0), 59)
        local B = H.boot({ name = "rage-20-sure" })
        local W = B.W
        W.head_dmg[2] = 50; W.body_dmg[2] = 60
        B.tick(10)
        H.ext_misses(B, 2, 3)
        B.tick(5)
        local on1 = H.has_md(B.hsr(2, W.tick - 3), 59)
        W.real_off = W.real_off + 200
        B.tick(5)
        local off = not H.has_md(B.hsr(2, W.tick - 3), 59)
        H.ext_misses(B, 2, 1)
        B.tick(5)
        local again = H.has_md(B.hsr(2, W.tick - 3), 59)
        H.check("T-RAGE-20", not a and on1 and off and not again, "M B M B M (govde isabetleri seriyi bozar): R5 yok ("
            .. tostring(not a) .. "); 3 iska -> R5 (" .. tostring(on1) .. "), 180 sn sonra biter (" .. tostring(off)
            .. "), sonra tek iska yeniden baslatmaz (" .. tostring(not again) .. ")")
    end)
    H.run("T-RAGE-21", function()
        -- R10: hafizadaki 'cc' bu oturumda en fazla seviye 1; spread iskalari pencereye girmez; R8'de sniper siniri yok.
        local seed = "NYKLEMEM\t1\t5\nP\t76561198000000002\tAlpha\t5\t\tStanding=cc\t0,0,0\t0\n"
        local A = H.boot({ name = "rage-21-hafiza", files = { ["nykle_memory.txt"] = seed } })
        A.W.p[1].weapon = H.weapon("deagle")
        A.W.head_dmg[2] = 50; A.W.body_dmg[2] = 30
        A.tick(20)
        local a_head = H.any(A.hsr(2, 0), H.sp_head)
        local a_force = H.any(A.hsr(2, 0), H.sp_force)
        local id = A.shoot(2); A.tick(2); A.miss(id, "resolver"); A.tick(5)
        local a_after = H.any(A.hsr(2, A.W.tick - 3), H.sp_force)
        local B = H.boot({ name = "rage-21-spread" })
        B.W.p[1].weapon = H.weapon("deagle")
        B.W.head_dmg[2] = 50; B.W.body_dmg[2] = 30
        B.tick(10)
        for _, why in ipairs({ "resolver", "resolver", "spread", "spread" }) do
            local i = B.shoot(2); B.tick(2); B.miss(i, why); B.tick(3)
        end
        B.tick(5)
        local b_force = H.any(B.hsr(2, B.W.tick - 3), H.sp_force)
        local R = H.boot({ name = "rage-21-r8" })
        R.W.p[1].weapon = H.weapon("revolver")
        R.W.head_dmg[2] = 50; R.W.body_dmg[2] = 30
        R.tick(10)
        for _ = 1, 2 do local i = R.shoot(2); R.tick(2); R.miss(i, "resolver"); R.tick(3) end
        R.tick(5)
        local r_force = H.any(R.hsr(2, R.W.tick - 3), H.sp_force)
        H.check("T-RAGE-21", a_head and not a_force and a_after and b_force and r_force, "hafizada 'cc': ilk peek'te Prefer"
            .. " (head " .. tostring(a_head) .. ", Force " .. tostring(a_force) .. "), bu oturumda 1 iska -> Force ("
            .. tostring(a_after) .. "); c c + 2 spread iskasi seviye 2'de kalir (" .. tostring(b_force) .. "); R8 2 iska ->"
            .. " Force (" .. tostring(r_force) .. ")")
    end)
    H.run("T-RAGE-22", function()
        -- R1 bekleme cooldown'u harita degisiminde silinir (index'ler yeniden kullanilir).
        local T = H.boot({ name = "rage-22", tick = 150000 })
        local W = T.W
        W.head_dmg[2] = 50
        T.tick(30)
        W.p[2].sim_shift = 6
        T.tick(40)
        W.p[2].sim_shift = 0
        T.tick(5)
        local first = T.ignored(2, 150000, W.tick)
        W.real_off = W.real_off + (W.tick - 10000) * W.interval
        W.tick = 10000
        T.event("game_newmap", { mapname = "de_nuke" })
        T.tick(30)
        W.p[2].sim_shift = 6
        T.tick(12)
        local second = T.ignored(2, 10031, 10042)
        H.check("T-RAGE-22", first >= 3 and second >= 3, "yeni haritada (tick geri) sahte kayit yine beklenir: ilk harita "
            .. first .. ", yeni harita " .. second .. " tick (eski cooldown kalmaz)")
    end)
    H.run("T-MEM-1", function()
        -- 64 oyuncu dolu (hepsi en az bu oturum kadar yeni; esitlikte siralama keyfi): yeni eklenen rakip hic atilmaz,
        -- ogrenme kaydedilir (eski kod onu hemen atip her cagrida yeniden yaratiyordu).
        local seed = "NYKLEMEM\t1\t5\n"
        for i = 1, 64 do seed = seed .. string.format("P\t765611990000%05d\tseed%d\t7\t\t\t0,0,0\t0\n", i, i) end
        local T = H.boot({ name = "mem-1", files = { ["nykle_memory.txt"] = seed } })
        local W = T.W
        W.p[1].weapon = H.weapon("deagle")
        W.head_dmg[2] = 50
        T.tick(20)
        local id = T.shoot(2); T.tick(2); T.miss(id, "resolver")
        -- 2 sn: profil ornegi her iki dusmanin hafiza kaydina saniyede bir dokunur (R1-B2); dosyadaki oturumu bu
        -- oturumdan buyuk kayitlar yine de yeni rakibi atmaz.
        T.tick(130)
        T.event("round_end", { winner = 2 })
        T.tick(2)
        local found, n = nil, 0
        for _, p in ipairs(H.mem_lines(T, "P")) do
            n = n + 1
            if p[2] == "76561198000000002" then found = p[6] end
        end
        H.check("T-MEM-1", found ~= nil and found:find("c", 1, true) ~= nil and n <= 64, "64 dolu hafizada yeni rakip"
            .. " tutulur ve iskasi yazilir (" .. tostring(found) .. "), toplam " .. n .. " <= 64")
    end)
    H.run("T-OVR-1", function()
        -- Override tusu bir kez hata verirse 10 sn icinde yeniden cozulur; basiliyken R5 calismaz.
        local T = H.boot({ name = "ovr-1" })
        local W = T.W
        W.keys.md_ovr = true
        W.head_dmg[2] = 50; W.body_dmg[2] = 60
        T.tick(10)
        W.key_raise = { md_ovr = 1 }
        T.tick(64 * 12)
        local t0 = W.tick
        H.ext_misses(T, 2, 3)
        T.tick(10)
        local function rule_off(r) return H.head_off(r) and not H.all_off(r) end
        local bad = H.any_md(T.hsr(2, t0)) or H.any(T.hsr(2, t0), rule_off)
        H.check("T-OVR-1", (W.key_raise.md_ovr or 0) == 0 and not bad, "tus bir kez hata verdi, yeniden cozuldu: override"
            .. " basiliyken R5 MD / grup yok (" .. tostring(not bad) .. ")")
    end)
end

-------------------------------------------------------------------------------
-- Dusman profili ve hafiza v2 (R1-B2, N.profile): T-PROF-1..12. Desen / profil kontrolleri full modda (nofeature'da
-- goz yaw'i yok), dosya kontrolleri ffi'li modlarda, oturumluk hafiza noffi'de.
-------------------------------------------------------------------------------
H.SID2, H.SID3 = "76561198000000002", "76561198000000003"
-- Surum 2 hafiza metni: baslik + kayitlar + END <kayit sayisi>.
function H.mem2(lines, session)
    return "NYKLEMEM\t2\t" .. tostring(session or 5) .. "\n" .. (#lines > 0 and (table.concat(lines, "\n") .. "\n") or "")
        .. "END\t" .. #lines .. "\n"
end
function H.pline(sid, name) return "P\t" .. sid .. "\t" .. name .. "\t5\t\t\t0,0,0\t0" end
-- R: n static jitter xway spin random def fd
function H.rline(sid, n, st, ji, xw, sp, ra, def, fd)
    return table.concat({ "R", sid, n, st or 0, ji or 0, xw or 0, sp or 0, ra or 0, def or 0, fd or 0 }, "\t")
end
-- Hafiza dosyasinda bir kaydin alanlari (ilk eslesen), yoksa nil.
function H.mem_rec(T, kind, key)
    for _, f in ipairs((H.mem_lines(T, kind))) do
        if key == nil or f[2] == key then return f end
    end
    return nil
end
-- Dusmanin goz yaw'ini her tick seq'ten (tick'e gore dongu) ver.
function H.yaw_hook(idx, seq)
    return function(T, W) W.p[idx].eye_yaw = seq[W.tick % #seq + 1] end
end
-- Atis + isabet: atis satirindaki desen ("AA ... dsy?").
function H.shot_pattern(T, idx)
    local m = T.mark()
    local id = T.shoot(idx)
    T.hit(id, { hg = 2, dmg = 1, no_event = true })
    local l = T.printed("atis: ", m) or ""
    return l:match("| (AA [^|]-) dsy%?") or ("? [" .. l:sub(1, 60) .. "]")
end
-- Dusmanlar gorunmez (dormant): hafiza dosyasi hic dokunulmadan yeniden yazilir (gidis-donus).
function H.no_enemies(T, W) W.p[2].dormant = true; W.p[3].dormant = true end

function C.prof()
    local mode = H.mode
    local files_ok = mode ~= "noffi"
    if mode == "full" then
        H.run("T-PROF-1", function()
            local function cls(name, seq, def)
                local T = H.boot({ name = "prof-1-" .. name })
                local P = T.W.p
                local hook = H.yaw_hook(2, seq)
                T.tick(20, hook)
                if def then
                    -- Defensive penceresi (sahte kayit + gercek kayda donus sonrasi def_until) boyunca uc yaw 90.
                    P[2].sim_shift = 6
                    T.tick(3, function(T2, W) W.p[2].eye_yaw = 90 end)
                    P[2].sim_shift = 0
                    T.tick(2, function(T2, W) W.p[2].eye_yaw = 90 end)
                    T.tick(4, hook)
                end
                return H.shot_pattern(T, 2)
            end
            local spin = {}
            for i = 1, 9 do spin[i] = 180 + 40 * i end
            local got = {
                cls("static", { 170, 190 }), cls("jitter", { 140, 220 }), cls("xway", { 120, 180, 240 }),
                cls("spin", spin), cls("random", { 180, 255, 200, 330, 275, 120, 213, 60 }),
                cls("jitter-def", { 140, 220 }, true),
            }
            local want = { "AA statik", "AA jitter 80", "AA x-way", "AA spin", "AA random", "AA jitter 80" }
            local ok = true
            for i = 1, #want do if got[i] ~= want[i] then ok = false end end
            H.check("T-PROF-1", ok, "desen sinifi (statik +-10, jitter +-40, -60/0/60, +40/tick, random, jitter + defensive"
                .. " penceresinde yaw 90): " .. table.concat(got, " / "))
        end)
        H.run("T-PROF-2", function()
            -- (a) 240'i gecince butun sayilar yariya.
            local A = H.boot({ name = "prof-2-yari", files = { ["nykle_memory.txt"] = H.mem2({ H.pline(H.SID2, "Alpha"),
                H.rline(H.SID2, 240, 240) }) } })
            A.tick(80)
            A.event("round_end", { winner = 2 }); A.tick(2)
            local r = H.mem_rec(A, "R", H.SID2) or {}
            local n, st = tonumber(r[3]) or 0, tonumber(r[4]) or 0
            local halved = n >= 120 and n < 125 and st >= 120 and st < 123
            -- (b) aliskanlik esikleri: ilk taramada (canli desen yok) safe point Head sadece gecerli aliskanlikta.
            local function first_sp(name, rl)
                local T = H.boot({ name = "prof-2-" .. name, files = { ["nykle_memory.txt"] = H.mem2({ H.pline(H.SID2, "Alpha"), rl }) } })
                T.W.head_dmg[2] = 50
                T.tick(1)
                local recs = T.hsr(2, 0)
                return #recs > 0 and H.sp_head(recs[1])
            end
            local h60 = first_sp("60", H.rline(H.SID2, 10, 4, 6))
            -- Yuklemede bir ornek daha alinir (desen henuz "?"): 8 + 1 = 9 ornek.
            local n9 = first_sp("n9", H.rline(H.SID2, 8, 0, 8))
            local p50 = first_sp("50", H.rline(H.SID2, 10, 4, 5, 0, 0, 1))
            local k7 = first_sp("k7", H.rline(H.SID2, 12, 0, 7))
            -- (c) fake duck: yerde egilme 0.5, 8 tick'te bir guncelleme -> kayitta FD, profilde fd.
            local F = H.boot({ name = "prof-2-fd" })
            F.W.p[2].duck = 0.5; F.W.p[2].sim_every = 8
            F.W.head_dmg[2] = 50; F.W.body_dmg[2] = 30
            F.tick(70)
            local m = F.mark()
            local id = F.shoot(2); F.tick(1); F.hit(id, { hg = 2, dmg = 1, no_event = true })
            local det = F.printed("dbg atis-detay: Alpha", m) or ""
            F.event("round_end", { winner = 2 }); F.tick(2)
            local fr = H.mem_rec(F, "R", H.SID2) or {}
            local fd_ok = det:find(" FD AA ", 1, true) ~= nil and (tonumber(fr[10]) or 0) >= 1
            H.check("T-PROF-2", halved and h60 and not n9 and not p50 and not k7 and fd_ok, "240 ustu yariya (R n "
                .. tostring(r[3]) .. ", statik " .. tostring(r[4]) .. "); aliskanlik: 10 ornek %60 jitter -> Head ("
                .. tostring(h60) .. "), 9 ornek yok (" .. tostring(not n9) .. "), %50 yok (" .. tostring(not p50)
                .. "), 7 bilinen yok (" .. tostring(not k7) .. "); fake duck kayitta FD + profil fd " .. tostring(fr[10])
                .. " (" .. det:sub(1, 90) .. ")")
        end)
    end
    if mode == "full" or mode == "nofeature" then
        H.run("T-PROF-3", function()
            local seed = H.mem2({ H.pline(H.SID2, "Alpha"), H.rline(H.SID2, 20, 2, 18) })
            local T = H.boot({ name = "prof-3-hafiza", files = { ["nykle_memory.txt"] = seed } })
            T.W.head_dmg[2] = 50
            T.tick(1)
            local first = T.hsr(2, 0)[1]
            local on = first ~= nil and H.sp_head(first)
            T.tick(100)
            local n = T.count("resolver: Alpha jitter -> safe point Head (veri yok, hafizadan, dogrulanacak)")
            local still = H.any(T.hsr(2, T.W.tick - 2), H.sp_head)
            local B = H.boot({ name = "prof-3-yeni" })
            B.W.head_dmg[2] = 50
            B.tick(1)
            local bfirst = B.hsr(2, 0)[1]
            local boff = bfirst ~= nil and not H.sp_head(bfirst) and #bfirst.sp == 0
            -- nofeature: canli desen hic gelmez -> on bilgi surer; full: canli desen statik -> on bilgi biter.
            local want_still = mode == "nofeature"
            H.check("T-PROF-3", on and n == 1 and still == want_still and boff, "hafizada jitter aliskanligi + canli desen"
                .. " yok: ilk taramada set_safepoint_state(true, HEAD) (" .. tostring(on) .. "), 'hafizadan, dogrulanacak'"
                .. " satiri " .. n .. " kez, 100 tick sonra on bilgi " .. tostring(still) .. " (beklenen " .. tostring(want_still)
                .. "); hafizasiz rakip ilk taramada safe point yok (" .. tostring(boff) .. ")")
        end)
    end
    if mode == "full" then
        H.run("T-PROF-4", function()
            local seed = H.mem2({ H.pline(H.SID2, "Alpha"), H.rline(H.SID2, 20, 2, 18) })
            local A = H.boot({ name = "prof-4-tutmadi", files = { ["nykle_memory.txt"] = seed } })
            A.W.head_dmg[2] = 50
            A.tick(30)
            local miss = A.printed("resolver: Alpha hafiza tutmadi: genelde jitter, simdi statik (canli desen kullaniliyor, aliskanlik duzeltildi)")
            local prior_off = not H.any(A.hsr(2, A.W.tick - 10), H.sp_head)
            A.event("round_end", { winner = 2 }); A.tick(2)
            local r = H.mem_rec(A, "R", H.SID2) or {}
            local B = H.boot({ name = "prof-4-dogrulandi", files = { ["nykle_memory.txt"] = seed } })
            B.W.head_dmg[2] = 50
            B.tick(30, H.yaw_hook(2, { 140, 220 }))
            local hit = B.printed("resolver: Alpha hafiza dogrulandi: genelde jitter, simdi ")
            B.event("round_end", { winner = 2 }); B.tick(2)
            local rb = H.mem_rec(B, "R", H.SID2) or {}
            H.check("T-PROF-4", miss ~= nil and r[5] == "9" and prior_off and A.count("hafiza tutmadi") == 1 and hit ~= nil
                and (tonumber(rb[5]) or 0) >= 18, "canli statik vs aliskanlik jitter -> tutmadi (" .. tostring(miss ~= nil)
                .. "), jitter sayisi 18 -> " .. tostring(r[5]) .. ", on bilgi kalkti (" .. tostring(prior_off) .. ");"
                .. " canli jitter -> dogrulandi (" .. tostring(hit ~= nil) .. "), sayilar yarilanmaz (" .. tostring(rb[5]) .. ")")
        end)
        H.run("T-PROF-5", function()
            local seed = H.mem2({ H.pline(H.SID2, "Alpha"), H.rline(H.SID2, 20, 20),
                table.concat({ "K", H.SID2, 3, 1, 2, 10, 4, 2, 3, 5, 2 }, "\t") })
            local T = H.boot({ name = "prof-5", files = { ["nykle_memory.txt"] = seed } })
            T.tick(130)
            -- Yeni rakibin de bu oturumda verisi olsun (kariyer): yine de taninmaz (dosyadan gelmedi).
            local id = T.shoot(3); T.tick(2); T.hit(id, { hg = 1, dmg = 50 }); T.tick(2)
            local want = "resolver: Alpha tanindi (hafiza): genelde statik (dogrulanacak), gecmis 3 harita, K/D 1/2,"
                .. " atis 4/10 (kafa 2), correction 3"
            local first = T.printed("tanindi (hafiza)")
            local n1 = T.count("Alpha tanindi (hafiza)")
            T.event("game_newmap", { mapname = "de_nuke" })
            T.tick(130)
            local n2, bravo = T.count("Alpha tanindi (hafiza)"), T.count("Bravo tanindi")
            local second = H.lines_with(T, "Alpha tanindi (hafiza)")[2] or ""
            H.check("T-PROF-5", first ~= nil and H.bare(first) == want and n1 == 1 and bravo == 0 and n2 == 2
                and second:find("gecmis 4 harita", 1, true) ~= nil, "hafizadaki rakip haritada bir kez taninir ("
                .. n1 .. " / yeni haritada toplam " .. n2 .. "), yeni rakip hic (" .. bravo .. "): " .. tostring(H.bare(first)))
        end)
        H.run("T-PROF-6", function()
            local T = H.boot({ name = "prof-6" })
            local P = T.W.p
            local jit, stat = H.yaw_hook(2, { 140, 220 }), H.yaw_hook(2, { 180 })
            T.tick(200)
            -- Durum degisimi (egildi) + 0.6 sn jitter + statik: 1.5 sn oturma icinde, sayilmaz.
            local m0 = T.mark()
            P[2].duck = 1
            T.tick(40, jit)
            T.tick(200, stat)
            local quiet = T.count("AA deseni", m0)
            -- Kalici degisim (durum ayni): yazilir; 2 sn arayla 3 degisim daha: 10 sn sinirinda yazilmaz, 4. degisimde
            -- kararsiz.
            local m1 = T.mark()
            T.tick(128, jit)
            T.tick(128, stat)
            T.tick(128, jit)
            T.tick(128, stat)
            local changed = H.lines_with(T, "AA deseni degisti", m1)
            local unstable = H.lines_with(T, "AA deseni kararsiz", m1)
            H.check("T-PROF-6", quiet == 0 and #changed == 1 and changed[1]:find("Alpha AA deseni degisti (statik -> ", 1, true)
                ~= nil and #unstable == 1 and unstable[1]:find("(20 sn'de 4 degisim)", 1, true) ~= nil, "durum degisiminden"
                .. " sonraki 1.5 sn'deki gecici desen sayilmaz (" .. quiet .. " satir); kalici degisim 1 kez yazilir ("
                .. #changed .. ": " .. tostring(H.bare(changed[1])) .. "), 10 sn siniri, 4 degisimde kararsiz (" .. #unstable
                .. ": " .. tostring(H.bare(unstable[1])) .. ")")
        end)
        H.run("T-PROF-7", function()
            local files = {}
            local A = H.boot({ name = "prof-7-a", files = files })
            A.tick(10)
            local id = A.shoot(2); A.tick(2); A.hit(id, { hg = 1, dmg = 50 }); A.tick(2)
            id = A.shoot(2); A.tick(2); A.hit(id, { hg = 2, dmg = 30 }); A.tick(2)
            id = A.shoot(2); A.tick(2); A.miss(id, "resolver"); A.tick(2)
            A.hurt_me(2, 1, 20); A.tick(2); A.hurt_me(2, 2, 10); A.tick(2)
            A.event("player_death", { userid = 102, attacker = 101, weapon = "ssg08", headshot = 1 })
            A.tick(2)
            A.event("player_death", { userid = 101, attacker = 102, weapon = "ak47" })
            A.tick(70)
            A.shutdown()
            local want = "dusman ozeti: Alpha | K/D 1/1 | atis 3, isabet 2 (kafa 1), correction 1 | sana 2 mermi (kafa 1) | desen statik"
            local la = H.bare(A.printed("dusman ozeti: Alpha"))
            local order = H.lines_with(A, "dusman ozeti: ")
            local B = H.boot({ name = "prof-7-b", files = files })
            B.tick(70)
            local tan = H.bare(B.printed("Alpha tanindi (hafiza)")) or ""
            B.shutdown()
            local lb = H.bare(B.printed("dusman ozeti: Alpha"))
            H.check("T-PROF-7", la == want and lb == want and #order == 2 and order[1]:find("Alpha", 1, true) ~= nil
                and tan:find("gecmis 1 harita, K/D 1/1, atis 2/3 (kafa 1), correction 1", 1, true) ~= nil, "kariyer: "
                .. tostring(la) .. " | yeniden yuklemeden sonra ayni (" .. tostring(lb == want) .. "), olumune gore sirali ("
                .. #order .. "), tanindi: " .. tan)
        end)
    end
    if files_ok then
        H.run("T-PROF-8", function()
            -- (a) v1 dosyasi: P / F aynen okunur, v2 olarak yazilir, v1 metni .bak'a gider.
            local pl = "P\t76561198000000077\tOld\t4\t3\tAir=c;Standing=chc\t12,4.50,7\t2"
            local fl = "F\tstill\t1\t10\t3"
            local v1 = "NYKLEMEM\t1\t5\n" .. pl .. "\n" .. fl .. "\n"
            local V = H.boot({ name = "prof-8-v1", files = { ["nykle_memory.txt"] = v1 }, pre = H.no_enemies })
            local load = V.printed("yuklendi") or ""
            local bak1 = V.file("nykle_memory.bak")
            V.shutdown()
            local out = V.file("nykle_memory.txt") or ""
            -- V1.0.9: eski faz setinin F kaydi ve dusman taban fazi (alan 5) yeni sete tasinmaz; "V phases 2" yazilir.
            local pl2 = "P\t76561198000000077\tOld\t4\t\tAir=c;Standing=chc\t12,4.50,7\t2"
            local v1_ok = load:find("(hafiza: 1 oyuncu)", 1, true) ~= nil and out:find("\n" .. pl2 .. "\n", 1, true) ~= nil
                and out:find("\nF", 1, true) == nil and out:find("\nV\tphases\t2\n", 1, true) ~= nil
                and out:sub(1, 13) == "NYKLEMEM\t2\t6\n" and out:find("\nEND\t2\n$") ~= nil and bak1 == v1
            -- (b) v2 gidis-donus: yaz, yukle, yaz -> sadece baslik oturumu degisir.
            local files = { ["nykle_memory.txt"] = H.mem2({ H.pline(H.SID2, "Alpha"), H.rline(H.SID2, 240, 240, 0, 0, 0, 0, 3, 1) }) }
            local A = H.boot({ name = "prof-8-a", files = files })
            A.tick(10)
            local id = A.shoot(2); A.tick(2); A.hit(id, { hg = 1, dmg = 50 }); A.tick(2)
            id = A.shoot(2); A.tick(2); A.miss(id, "resolver"); A.tick(70)
            A.shutdown()
            local f1 = files["nykle_memory.txt"]
            local B = H.boot({ name = "prof-8-b", files = files, pre = H.no_enemies })
            B.tick(5)
            B.shutdown()
            local f2 = files["nykle_memory.txt"]
            local C2 = H.boot({ name = "prof-8-c", files = files, pre = H.no_enemies })
            C2.tick(5)
            C2.shutdown()
            local f3 = files["nykle_memory.txt"]
            local s1 = tonumber(f1:match("^NYKLEMEM\t2\t(%d+)\n")) or -1
            local function body(f) return (f:gsub("^[^\n]*\n", "")) end
            local rt = body(f1) == body(f2) and body(f2) == body(f3) and f2:match("^[^\n]*")
                == "NYKLEMEM\t2\t" .. (s1 + 1) and f1:find("\nR\t" .. H.SID2 .. "\t", 1, true) ~= nil
                and f1:find("\nK\t" .. H.SID2 .. "\t", 1, true) ~= nil and f1:find("%.50\t") ~= nil
            H.check("T-PROF-8", v1_ok and rt, "v1 dosyasi aynen okunur ve v2 yazilir (" .. tostring(v1_ok) .. ": "
                .. load:match("%(hafiza[^)]*%)") .. "); v2 yaz -> yukle -> yaz bayt bayt ayni, sadece oturum +1 ("
                .. tostring(rt) .. ": " .. f1:gsub("\n", " / "):sub(1, 140) .. ")")
        end)
        H.run("T-PROF-9", function()
            local good = H.mem2({ H.pline(H.SID2, "Alpha"), H.rline(H.SID2, 20, 20) })
            -- (a) ana dosya yarida kesik (END yok), .bak saglam.
            local cut = good:sub(1, #good - 30)
            local A = H.boot({ name = "prof-9-yedek", files = { ["nykle_memory.txt"] = cut, ["nykle_memory.bak"] = good },
                pre = H.no_enemies })
            local la = A.printed("yuklendi") or ""
            local note = A.printed("hafiza dosyasi bozuk (END yok) -> yedek kullanildi (nykle_memory.bak)")
            local main = A.file("nykle_memory.txt") or ""
            local a_ok = la:find("(hafiza: 1 oyuncu, yedekten)", 1, true) ~= nil and note ~= nil
                and main:find("\nEND\t%d+\n$") ~= nil and A.file("nykle_memory.bak") == good
            -- (b) ikisi de bozuk: bos hafiza, hata yok.
            local bad = "NYKLEMEM\t2\t5\n" .. H.pline(H.SID2, "Alpha") .. "\n"
            local B = H.boot({ name = "prof-9-bos", files = { ["nykle_memory.txt"] = bad, ["nykle_memory.bak"] = "cop" } })
            local lb = B.printed("yuklendi") or ""
            local nb = B.printed("hafiza dosyasi bozuk (END yok) -> bos hafiza (yedek de bozuk)")
            -- (b2) V1.0.7: kayit sayisi tutmuyor (oyundaki log 3: "30 != 33") + \r ve NUL artigi: gecerli kayitlar yuklenir.
            local off = "NYKLEMEM\t2\t5\r\n" .. H.pline(H.SID2, "Alpha") .. "\r\nEND\t5\r\n\0"
            local B2 = H.boot({ name = "prof-9-sayi", files = { ["nykle_memory.txt"] = off }, pre = H.no_enemies })
            local lb2 = B2.printed("yuklendi") or ""
            local nb2 = B2.printed("hafiza dosyasinda kayit sayisi 5 != 1: gecerli kayitlar yuklendi")
            H.check("T-PROF-9", lb2:find("(hafiza: 1 oyuncu)", 1, true) ~= nil and nb2 ~= nil, "kayit sayisi tutmayan (+ \\r / NUL) dosya:"
                .. " gecerli kayitlar yuklenir (" .. tostring(lb2:match("%(hafiza[^)]*%)")) .. "), not " .. tostring(nb2 ~= nil))
            -- (c) normal yazim: once onceki gecerli metin .bak'a.
            local C2 = H.boot({ name = "prof-9-yaz", files = { ["nykle_memory.txt"] = good } })
            local m1 = C2.file("nykle_memory.txt")
            local c_ok = C2.file("nykle_memory.bak") == good and m1 ~= good
            C2.tick(70)
            C2.event("round_end", { winner = 2 }); C2.tick(2)
            c_ok = c_ok and C2.file("nykle_memory.bak") == m1 and C2.file("nykle_memory.txt") ~= m1
            -- (d) daha yeni surumun dosyasi (eski surume donuldu): okunmaz, hic yazilmaz.
            local v3 = "NYKLEMEM\t3\t9\nX\tyeni\nEND\t1\n"
            local D = H.boot({ name = "prof-9-v3", files = { ["nykle_memory.txt"] = v3 } })
            D.tick(70)
            D.event("round_end", { winner = 2 }); D.tick(2)
            D.shutdown()
            local d_ok = D.file("nykle_memory.txt") == v3 and D.printed("hafiza dosyasi daha yeni bir surumden (surum 3)") ~= nil
            H.check("T-PROF-9", a_ok and lb:find("(hafiza: 0 oyuncu)", 1, true) ~= nil and nb ~= nil and B.ok
                and #B.raw_err == 0 and c_ok and d_ok, "kesik ana dosya -> .bak (" .. tostring(a_ok) .. ": " .. tostring(la:match("%(hafiza[^)]*%)"))
                .. "); ikisi de bozuk -> bos hafiza, hata yok (" .. tostring(nb ~= nil) .. "); yazimda once eski metin .bak'a ("
                .. tostring(c_ok) .. "); yeni surumun dosyasina dokunulmaz (" .. tostring(d_ok) .. ")")
        end)
        H.run("T-PROF-10", function()
            -- Oyun cokmus: config'te 4:3 (1.3333) kalmis, asil deger 1.7778 hafizada.
            local seed = H.mem2({ "C\tr_aspectratio\t1.7778\t1", "C\tcl_disable_ragdolls\t0\t0" })
            local function crashed(T, W) W.cv.r_aspectratio = 1.3333; W.cv.cl_disable_ragdolls = 1 end
            local A = H.boot({ name = "prof-10-kapanis", files = { ["nykle_memory.txt"] = seed }, pre = crashed })
            local rag = A.W.cv.cl_disable_ragdolls
            A.shutdown()
            local a = A.W.cv.r_aspectratio
            local mem = A.file("nykle_memory.txt") or ""
            local B = H.boot({ name = "prof-10-kapat", files = { ["nykle_memory.txt"] = seed }, pre = crashed })
            B.set("enabled", false)
            B.tick(3)
            local b = B.W.cv.r_aspectratio
            -- Uctan uca: senin degerin 1.7778, script 4:3 yazar, oyun coker (kapanis yok); sonraki oturum config'teki
            -- 1.3333'u degil 1.7778'i geri yazar. Temiz kapanista C kaydi silinir.
            local D = H.boot({ name = "prof-10-yeni", pre = function(T, W) W.cv.r_aspectratio = 1.7778 end })
            local first = H.mem_rec(D, "C", "r_aspectratio")
            local crash = { ["nykle_memory.txt"] = D.file("nykle_memory.txt") }
            D.shutdown()
            local gone = H.mem_rec(D, "C", "r_aspectratio") == nil
            local E = H.boot({ name = "prof-10-cokme", files = crash, pre = function(T, W) W.cv.r_aspectratio = 1.3333 end })
            E.shutdown()
            local e = E.W.cv.r_aspectratio
            H.check("T-PROF-10", math.abs(a - 1.7778) < 1e-4 and math.abs(b - 1.7778) < 1e-4 and rag == 0
                and not mem:find("\nC\tr_aspectratio", 1, true) and first ~= nil and first[3] == "1.7778" and gone
                and math.abs(e - 1.7778) < 1e-6,
                "cokmeden kalan 1.3333 yerine asil deger hafizadan: kapanis " .. H.f1(a) .. " (" .. tostring(a) .. "), kapatma "
                .. tostring(b) .. "; tutulmayan cvar (ragdoll) yuklemede geri (" .. tostring(rag) .. "); C kaydi ilk yazimda"
                .. " var (" .. tostring(first and first[3]) .. "), temiz birakista silinir (" .. tostring(gone) .. "); cokme sonrasi"
                .. " oturum " .. tostring(e))
        end)
        H.run("T-PROF-12", function()
            local seed = H.mem2({ H.pline(H.SID2, "Alpha"), H.rline(H.SID2, 20, 20),
                table.concat({ "K", H.SID2, 3, 1, 2, 10, 4, 2, 3, 5, 2 }, "\t"), "V\tphases\t2", "F2\tstill\t1\t10\t3",
                "T\t1\t10\t3\t6\t2",
                "C\tr_aspectratio\t1.7778\t1" })
            local T = H.boot({ name = "prof-12", files = { ["nykle_memory.txt"] = seed } })
            T.tick(5)
            local before = T.file("nykle_memory.txt")
            T.press("stats_reset")
            T.tick(2)
            local same = T.file("nykle_memory.txt") == before
            local m = T.mark()
            T.press("forget")
            T.tick(2)
            local f = T.file("nykle_memory.txt") or ""
            local learned = #H.mem_lines(T, "P") + #H.mem_lines(T, "R") + #H.mem_lines(T, "K") + #H.mem_lines(T, "F2")
                + #H.mem_lines(T, "T")
            local c = H.mem_rec(T, "C", "r_aspectratio")
            local bak = T.file("nykle_memory.bak") or ""
            H.check("T-PROF-12", same and learned == 0 and c ~= nil and c[3] == "1.7778" and f:find("\nEND\t%d+\n$") ~= nil
                and bak == f and T.count("ogrenilen dusmanlar unutuldu", m) == 1, "Reset stats hafizaya dokunmaz ("
                .. tostring(same) .. "); Forget: P / R / K / F silinir (" .. learned .. " kaldi), C kalir (" .. tostring(c and c[3])
                .. "), .bak da yeni metin (" .. tostring(bak == f) .. "), bir satir")
        end)
    else
        H.run("T-PROF-11", function()
            local T = H.boot({ name = "prof-11-noffi" })
            T.tick(10)
            local id = T.shoot(2); T.tick(2); T.hit(id, { hg = 1, dmg = 50 }); T.tick(2)
            T.hurt_me(2, 2, 10)
            T.tick(70)
            local shot = H.lines_with(T, "atis: Alpha")[1] or ""
            T.shutdown()
            local load = T.printed("yuklendi") or ""
            local want = "dusman ozeti: Alpha | K/D 0/0 | atis 1, isabet 1 (kafa 1), correction 0 | sana 1 mermi (kafa 0) | desen statik"
            H.check("T-PROF-11", load:find("(hafiza: dosya yok)", 1, true) ~= nil and T.printed("hafiza dosyasi") == nil
                and H.bare(T.printed("dusman ozeti: Alpha")) == want and shot:find("| AA statik dsy? ground", 1, true) ~= nil
                and #T.raw_err == 0, "ffi yok: profil ve kariyer oturumluk, dosya satiri yok, hata yok: "
                .. tostring(H.bare(T.printed("dusman ozeti: Alpha"))))
        end)
    end
    H.run("T-PROF-13", function()
        -- Mac sonu paneli: ozet bir kez; ara surede (canli, dusman gorunur) yeniden karsilasma / ozet yok; game_newmap
        -- ve kapanis yazilani tekrar yazmaz. Ayni haritada yeni mac (round_start) yeni harita sayilir.
        local files = {}
        local T = H.boot({ name = "prof-13", files = files_ok and files or nil })
        T.tick(10)
        local id = T.shoot(2); T.tick(2); T.hit(id, { hg = 1, dmg = 50 }); T.tick(70)
        T.event("cs_win_panel_match", {})
        T.tick(200)
        local m = T.mark()
        -- Yeni haritada dusman gorulmez: kapanista yeni harita ozeti olmasin (sadece eski haritanin tekrari aranir).
        H.no_enemies(T, T.W)
        T.event("game_newmap", { mapname = "de_nuke" })
        T.W.map = "de_nuke"
        T.tick(70)
        local a = T.count("dusman ozeti: Alpha", 1)
        local after = T.count("dusman ozeti: Alpha", m)
        T.shutdown()
        local enc = files_ok and H.mem_rec(T, "K", H.SID2) or nil
        local b = T.count("dusman ozeti: Alpha", 1)
        -- game_newmap'siz yeni mac: panel, round_start, yeni karsilasma -> ikinci ozet kapanista.
        local U = H.boot({ name = "prof-13-ayni-harita", files = files_ok and {} or nil })
        U.tick(10)
        id = U.shoot(2); U.tick(2); U.hit(id, { hg = 1, dmg = 50 }); U.tick(70)
        U.event("cs_win_panel_match", {})
        U.tick(100)
        U.event("round_start", {})
        U.tick(70)
        U.shutdown()
        local u = U.count("dusman ozeti: Alpha", 1)
        local uenc = files_ok and H.mem_rec(U, "K", H.SID2) or nil
        H.check("T-PROF-13", a == 1 and after == 0 and b == 1 and u == 2 and (not files_ok or (enc ~= nil and enc[3] == "1"
            and uenc ~= nil and uenc[3] == "2")), "panel + 200 tick + game_newmap + kapanis: 'dusman ozeti' " .. b .. " kez"
            .. " (newmap'te " .. after .. "), kariyer harita " .. tostring(enc and enc[3]) .. "; ayni haritada yeni mac: ozet "
            .. u .. ", harita " .. tostring(uenc and uenc[3]))
    end)
end

-------------------------------------------------------------------------------
-- R1-B3: sarj analizi (N.charge) ve teshis (N.diag)
-------------------------------------------------------------------------------
-- Son "vuruldun:" satiri (hurt_me ile).
function H.hurt_line(T, att, hg)
    local m = T.mark()
    T.hurt_me(att or 2, hg or 2, 20, "ak47")
    return T.printed("vuruldun:", m), m
end
-- "dbg teshis:" satirlarinin sayisi ve sonuncusu.
function H.teshis(T, since)
    local n, last = 0, nil
    for i = since or 1, #T.prints do
        if T.prints[i]:find("dbg teshis:", 1, true) then n, last = n + 1, T.prints[i] end
    end
    return n, last
end
function H.has(s, part) return s ~= nil and s:find(part, 1, true) ~= nil end
-- force_uncharge sarji hic dusurmez (G26, T-CHG-5).
function H.no_drain(T, W) T.EX.force_uncharge = function() T.unch[#T.unch + 1] = W.tick end end
-- force_uncharge sarji bir tick sonra bosaltir (G26 belirsizligi, T-CHG-9).
function H.lag_drain(T, W)
    T.EX.force_uncharge = function()
        T.unch[#T.unch + 1] = W.tick
        if W.drain_at == nil then W.drain_at = W.tick + 1 end
    end
end
-- Ayni tick'te birden fazla force_uncharge cagrisi (i0'dan sonraki cagrilar).
function H.unch_dup(T, i0)
    local seen, dup = {}, 0
    for i = i0 + 1, #T.unch do
        if seen[T.unch[i]] then dup = dup + 1 end
        seen[T.unch[i]] = true
    end
    return dup
end
-- Basit LCG (tekrarlanabilir arka plan reddi, T-CHG-8).
function H.lcg(seed)
    local x = seed
    return function()
        x = (x * 1103515245 + 12345) % 2147483648
        return x / 2147483648
    end
end

function C.chg()
    H.run("T-CHG-1", function()
        local T = H.boot({ name = "chg-1" })
        local W = T.W
        T.tick(250)
        W.keys.dt = false
        T.tick(10)
        W.keys.dt = true
        T.tick(78)
        W.auto_recharge = false
        W.charge = 5
        local a, ai = H.hurt_line(T)
        local d = T.printed("dbg vurulma-detay:", ai)
        W.charge = 14
        local b = H.hurt_line(T)
        H.check("T-CHG-1", H.in_order(a, { "DT %36", "sh 5/14", "dtac 1.20s", "sarj: dtac" }) and not H.has(a, "defbitti")
            and H.has(d, "sh 5/14") and b ~= nil and H.has(b, "DT dolu") and not H.has(b, "sh ") and not H.has(b, "dtac")
            and not H.has(b, "defbitti") and not H.has(b, "sarj:"), "DT 5/14, DT 1.20 sn once acildi: vuruldun / dbg satirinda"
            .. " 'sh 5/14, dtac 1.20s, sarj: dtac' (" .. tostring(a) .. "); dolu sarjda hicbiri (" .. tostring(b) .. ")")
    end)
    H.run("T-CHG-2", function()
        local T = H.boot({ name = "chg-2" })
        local W = T.W
        T.tick(250)
        W.p[1].sim_shift = 10
        local t0 = W.tick
        T.tick(10)
        T.tick(20)
        W.auto_recharge = false
        W.charge = 7
        local a = H.hurt_line(T)
        local U = H.boot({ name = "chg-2-gec" })
        U.tick(250)
        U.W.p[1].sim_shift = 10
        U.tick(10 + 120)
        U.W.auto_recharge = false
        U.W.charge = 7
        local b = H.hurt_line(U)
        H.check("T-CHG-2", H.in_order(a, { "sh 7/14", "defbitti 0.30s", "sarj: def" }) and not H.has(a, "dtac")
            and H.has(b, "sh 7/14") and not H.has(b, "defbitti") and H.has(b, "sarj: ?"), "kendi defensive'imiz bitti, 0.30 sn"
            .. " sonra yarim sarjda vuruldun -> 'defbitti 0.30s, sarj: def' (" .. tostring(a) .. "); 1.5 sn'den sonra"
            .. " defbitti yok, sebep '?' (" .. tostring(b) .. ")")
    end)
    H.run("T-CHG-3", function()
        -- def_edge kapali: Always on dolu oldugu her tick zorlar (sayaclar tick tick dogrulanir).
        local T = H.boot({ name = "chg-3", rec_off = true, setup = function(T)
            T.xset("Standing", "Defensive", 4); H.edge_off(T)
        end })
        local W = T.W
        T.tick(40)
        W.auto_recharge = false
        T.event("round_start", {})
        local t0 = W.tick
        local m = T.mark()
        T.tick(40, function(T, W)
            local k = W.tick - t0
            -- 1-10 dolu (Always on -> 10 zorlama), 31-35 yarim gorulmeden, 36-37 bos goruluyor, 38-39 yarim goruluyor.
            W.charge = (k <= 10) and 14 or (((k >= 31 and k <= 35) or k == 38 or k == 39) and 7 or 0)
            local s = (k >= 36 and k <= 39) and 60 or 0
            W.sees[2], W.sees[3] = s, s
        end)
        T.event("round_start", {})
        local line = T.printed("dbg sen ozeti:", m)
        local want = "dbg sen ozeti: 40 tick canli, DT acik 40 | defensive zorlanan 10 tick, gorulen (sim) 0, zorlanip gorulen 0"
            .. " | teleport 0, sonrasi 1.5 sn icinde vurulma 0 | yarim sarj 7 tick (goruluyorken 2), defensive bitisi 0"
            .. " | sarj tavani 14 | shift 10, dolum ort ?t"
        -- Ikinci round: inis teleportu + 1.5 sn icinde vurulma + kendi defensive bitisi.
        W.auto_recharge = true
        W.sees[2], W.sees[3] = 0, 0
        T.tick(30)
        local m2 = T.mark()
        local r = H.flight(T, 250, true)
        T.hurt_me(2, 2, 10, "ak47")
        W.sees[2] = 0
        W.p[1].sim_shift = 8
        T.tick(40)
        T.event("round_start", {})
        local l2 = T.printed("dbg sen ozeti:", m2)
        H.check("T-CHG-3", H.bare(line) == want and r.tp ~= nil and H.in_order(l2, { "teleport 1, sonrasi 1.5 sn icinde"
            .. " vurulma 1", "defensive bitisi 1" }) and l2:find("gorulen %(sim%) [1-9]") ~= nil, "round basinda tam sayaclar: "
            .. tostring(line) .. " | teleport + vurulma + kendi defensive: " .. tostring(l2))
    end)
    H.run("T-CHG-4", function()
        local T = H.boot({ name = "chg-4" })
        local W = T.W
        W.max_charge = 9
        W.trace_dz = 6
        T.tick(40)
        local m = T.mark()
        -- S 9 -> inise 9 - 3 = 6 tick kala; izin zemini 6 u yukarida -> tahmin erken, gercek inis 1 tick sonra.
        local r = H.flight(T, 420, true)
        local tp = T.printed("teleport: inise ", m)
        local res = T.printed("teleport sonucu: tahmin", m)
        local gap = r.tp and (r.land - r.tp) or -1
        for _ = 1, 9 do H.flight(T, 420, false) end
        local n = T.count("inis tahmini:", m)
        local est = T.printed("inis tahmini:", m)
        H.check("T-CHG-4", H.has(tp, "inise 6 tick kala") and gap == 7 and H.in_order(res, { "tahmin 6, sapma +1 tick",
            "ilk paket 2D ", "paket yerde ", "inis tick +", "tekrar ziplama hayir" }) and n == 1
            and H.has(est, "inis tahmini: 10 ziplama, ort +"), "S 9: inise 6 tick kala atildi, " .. gap .. " tick sonra"
            .. " indi -> " .. tostring(res) .. "; 10 iniste bir kez (" .. n .. "): " .. tostring(est))
    end)
    H.run("T-CHG-5", function()
        local T = H.boot({ name = "chg-5", pre = H.no_drain })
        local W = T.W
        T.tick(40)
        local m = T.mark()
        local flights = {}
        for i = 1, 5 do
            local u0 = #T.unch
            H.flight(T, 250, true)
            flights[i] = #T.unch - u0
            T.tick(20)
        end
        local nd = T.count("teleport: sarj harcanmadi (force_uncharge 4 tick, sarj 14/14)", m)
        local off = T.count("teleport: force_uncharge calismiyor -> bu oturum havada teleport kapali", m)
        local g26 = T.count("teshis: G26 force_uncharge sarji bosaltmadi", 1)
        -- Oturum kapaliyken DT inise saklanmaz (politika kapali, eski yol da teleportsuz): "inise yok" yazilmaz.
        local _, offi = T.printed("bu oturum havada teleport kapali", m)
        local idle = offi and T.count("teleport: inise yok", offi) or -1
        -- Kismen bosaltan force_uncharge (uncharge_partial) harcandi sayilir.
        local P = H.boot({ name = "chg-5-kismi" })
        P.W.uncharge_partial = 3
        P.tick(40)
        local pm = P.mark()
        for _ = 1, 3 do H.flight(P, 250, true); P.tick(20) end
        local pn = P.count("sarj harcanmadi", pm)
        H.check("T-CHG-5", flights[1] == 4 and flights[2] == 4 and flights[3] == 4 and flights[4] == 0 and flights[5] == 0
            and nd == 3 and off == 1 and g26 == 1 and pn == 0 and idle == 0 and T.count("bu ziplamada", 1) == 0, "sarji dusurmeyen"
            .. " force_uncharge: ucus basina cagri " .. table.concat(flights, "/") .. " (4/4/4/0/0), 'harcanmadi' " .. nd
            .. ", oturum kapali satiri " .. off .. " (sonra 'inise yok' " .. idle .. "), teshis G26 " .. g26 .. "; kismen bosaltan -> harcanmadi " .. pn)
        -- Ucus basina tek teleport bekcisi: eski yolda (Air LC kapali) teleport, ucusta Air LC acilip sarj dolsa da
        -- inis teleportu ikinci kez atilmaz.
        local G = H.boot({ name = "chg-5-bekci", rec_off = true, setup = function(T) T.set("air_lc", false) end })
        G.tick(40)
        local gm = G.mark()
        local u0 = #G.unch
        local first = nil
        G.W.sees[2] = 60
        G.W.p[1].vel = V.v3(250, 0, 0)
        G.W.charge = G.W.max_charge
        G.jump(300)
        for _ = 1, 200 do
            G.tick(1, function(T, W)
                if first ~= nil then W.charge = W.max_charge end
            end)
            if first == nil and #G.unch > u0 then
                first = G.W.tick
                G.set("air_lc", true)
            end
            if G.W.p[1].ground then break end
        end
        G.tick(5)
        H.check("T-CHG-5", first ~= nil and #G.unch - u0 == 1 and G.count("teleport: bu ziplamada 2 kez", gm) == 1,
            "ayni ucusta ikinci teleport engellenir: uncharge " .. (#G.unch - u0) .. ", bekci satiri "
            .. G.count("teleport: bu ziplamada", gm))
    end)
    H.run("T-CHG-6", function()
        local function inst(name, order)
            -- def_edge kapali: bekci DEF etiketli atis ister (goruluyorken her tick zorlanan defensive).
            local T = H.boot({ name = name, rec_off = true, setup = H.edge_off })
            local W = T.W
            W.sees[2], W.sees[3] = 60, 60
            T.tick(40)
            local m = T.mark()
            -- Bekci sadece kendi lag'imizla (DEF) atilan atislari sayar; atislar arasi 11 sn: X13 (10 sn'de 2) devreye
            -- girmez, her atis yeniden DEF'li gider.
            for i, idx in ipairs(order) do
                local id = T.shoot(idx)
                T.tick(2)
                T.miss(id, "server rejection")
                T.tick(2)
                if i < #order then W.real_off = W.real_off + 11; T.tick(62) end
            end
            return T, m
        end
        local A, am = inst("chg-6", { 2, 3, 2 })
        local W = A.W
        local line = A.printed("sunucu atislari reddediyor", am)
        local t1 = W.tick
        A.tick(60)
        local s1 = A.shifts(t1 + 1, W.tick)
        W.real_off = W.real_off + 280
        local t2 = W.tick
        A.tick(30)
        local s2 = A.shifts(t2 + 1, W.tick)
        local paint = A.has_text(t2 + 1, W.tick, "PAUSE")
        W.real_off = W.real_off + 25
        local t3 = W.tick
        local rm = A.mark()
        A.tick(30)
        local s3 = A.shifts(t3 + 1, W.tick)
        local back = A.printed("sunucu reddi: 5 dk doldu, DEF / LC / TP tekrar acik", rm)
        local B, bm = inst("chg-6-tek", { 2, 2, 2 })
        local Wb = B.W
        Wb.real_off = Wb.real_off + 11
        local b0 = Wb.tick
        B.tick(30)
        local bs = B.shifts(b0 + 1, Wb.tick)
        H.check("T-CHG-6", H.bare(line) == "sunucu atislari reddediyor (son 3 atisin 3'i, 2 dusmanda, son: server rejection)"
            .. " -> DEF / LC / TP 5 dk kapali" and s1 == 0 and s2 == 0 and paint and s3 >= 10 and back ~= nil
            and B.printed("sunucu atislari reddediyor", bm) == nil and bs >= 10, "3 ret 2 dusmanda: " .. tostring(line)
            .. "; defensive 0-1 sn " .. s1 .. ", 280 sn " .. s2 .. " (PAUSE " .. tostring(paint) .. "), 305 sn sonra " .. s3
            .. " (" .. tostring(back ~= nil) .. "); 3 ret 1 dusmanda: bekci yok, 11 sn sonra defensive " .. bs)
    end)
    H.run("T-CHG-7", function()
        local T = H.boot({ name = "chg-7", rec_off = true, setup = H.edge_off })
        local W = T.W
        W.sees[2], W.sees[3] = 60, 60
        W.head_dmg[2] = 50; W.body_dmg[2] = 40
        T.tick(40)
        local m = T.mark()
        for i, idx in ipairs({ 3, 2, 3 }) do
            local id = T.shoot(idx)
            T.tick(2)
            T.miss(id, "server rejection")
            T.tick(2)
            if i < 3 then W.real_off = W.real_off + 11; T.tick(62) end
        end
        local paused = T.printed("sunucu atislari reddediyor", m) ~= nil
        local t0 = W.tick
        T.tick(60)
        local recs = T.hsr(2, t0 + 1, W.tick)
        local ign = T.ignored(2, t0 + 1, W.tick)
        local off = H.any(recs, H.all_off) or H.any(recs, H.head_off)
        H.check("T-CHG-7", paused and #recs >= 50 and ign == 0 and not off and not H.any_md(recs), "bekci acikken (" ..
            tostring(paused) .. ") hedef her tick taranir (" .. #recs .. "), ignore_target " .. ign .. ", grup kapatma "
            .. tostring(off) .. ", set_min_dmg " .. tostring(H.any_md(recs)))
    end)
    H.run("T-CHG-8", function()
        -- (a) Lag'siz atislardaki ret lag'imizdan olamaz: DT kapali (defensive / teleport yok), 3 ret 2 dusmanda -> bekci yok.
        local A = H.boot({ name = "chg-8-temiz", setup = function(T) H.def_off(T) end })
        local W = A.W
        W.sees[2], W.sees[3] = 60, 60
        W.keys.dt = false
        A.tick(40)
        local am = A.mark()
        for i, idx in ipairs({ 2, 3, 2 }) do
            local id = A.shoot(idx)
            A.tick(2)
            A.miss(id, "server rejection")
            A.tick(2)
            if i < 3 then W.real_off = W.real_off + 11; A.tick(62) end
        end
        local clean = A.count("sunucu atislari reddediyor", am)
        local untagged = A.count("sen ssg08 temiz", am) + A.count("sen ssg08 |", am)
        -- (b) GS V1.0.19 arka plan ret orani (%12, tekrarlanabilir): 300 atis, 2 dusman, varsayilan ayarlar -> hic tetik yok.
        local B = H.boot({ name = "chg-8-arka-plan", rec_off = true, setup = H.edge_off })
        local Wb = B.W
        Wb.sees[2], Wb.sees[3] = 60, 60
        B.tick(40)
        local bm = B.mark()
        local rnd = H.lcg(20261109)
        local rej, lagged = 0, 0
        for _ = 1, 300 do
            local idx = rnd() < 0.5 and 2 or 3
            local id = B.shoot(idx, { hg = 2 })
            B.tick(1)
            if rnd() < 0.12 then
                rej = rej + 1
                B.miss(id, "server rejection")
            else
                B.hit(id, { hg = 2, dmg = 1, no_event = true })
            end
            Wb.real_off = Wb.real_off + 1 + rnd() * 3
            B.tick(4 + math.floor(rnd() * 12))
        end
        lagged = B.count(" DEF | AA", bm)
        local trig = B.count("sunucu atislari reddediyor", bm)
        H.check("T-CHG-8", clean == 0 and untagged == 3 and trig == 0 and rej >= 25 and lagged >= 50, "temiz atislarda 3 ret"
            .. " 2 dusmanda: bekci " .. clean .. " (atislar etiketsiz " .. untagged .. "/3); %12 arka plan reddi: 300 atista "
            .. rej .. " ret (" .. lagged .. " DEF'li atis) -> bekci " .. trig .. " kez")
    end)
    H.run("T-CHG-9", function()
        -- force_uncharge sarji bir tick sonra bosaltir: inis teleportunda tick basina tek cagri, tek cagrida bitti.
        local T = H.boot({ name = "chg-9", pre = H.lag_drain })
        T.tick(40)
        local m = T.mark()
        local u0 = #T.unch
        local r = H.flight(T, 250, true)
        local n, dup = #T.unch - u0, H.unch_dup(T, u0)
        local done = H.bare(T.printed("teleport: inis teleportu bitti", m))
        local g26 = T.count("teshis: G26 force_uncharge sarji 1 cagrida bosaltti", 1)
        -- Hic bosaltmayan force_uncharge: 4 cagri, 4 ayri tick.
        local Z = H.boot({ name = "chg-9-bosaltmaz", pre = H.no_drain })
        Z.tick(40)
        local z0 = #Z.unch
        H.flight(Z, 250, true)
        local zn, zdup = #Z.unch - z0, H.unch_dup(Z, z0)
        H.check("T-CHG-9", r.tp ~= nil and n == 1 and dup == 0 and done == "teleport: inis teleportu bitti (1. kez,"
            .. " uncharge 1 tick)" and g26 == 1 and zn == 4 and zdup == 0 and T.count("sarj harcanmadi", m) == 0,
            "bir tick gec bosalan sarj: " .. n .. " cagri (ayni tick'te " .. dup .. "), " .. tostring(done) .. ", G26 '1 cagrida' "
            .. g26 .. "; bosaltmayan: " .. zn .. " cagri, ayni tick'te " .. zdup)
    end)
end

function C.diag()
    local full = H.mode == "full"
    H.run("T-DIAG-5", function()
        local T = H.boot({ name = "diag-5" })
        local W = T.W
        T.tick(50)
        local m = T.mark()
        W.no_local = true
        T.tick(5)
        W.no_local = false
        T.event("game_newmap", { mapname = "de_nuke" })
        T.tick(50)
        local n1 = H.teshis(T, m)
        T.event("game_newmap", { mapname = "de_nuke" })
        local n2 = H.teshis(T, m)
        T.tick(20)
        T.shutdown()
        local n3 = H.teshis(T, m)
        local Q = H.boot({ name = "diag-5-kapali" })
        Q.set("debug_log", false)
        Q.tick(50)
        Q.event("game_newmap", { mapname = "de_nuke" })
        Q.shutdown()
        local q = H.teshis(Q, 1)
        local g = Q.count("teshis: G1 SETUP_COMMAND ANTIAIM'den once calisiyor", 1)
        H.check("T-DIAG-5", n1 == 1 and n2 == 2 and n3 == 3 and q == 0 and g == 1, "dbg teshis: yerel oyuncu gidip"
            .. " gelince + game_newmap -> 1 (" .. n1 .. "), yeni haritada 50 tick sonra game_newmap -> 2 (" .. n2
            .. "), SHUTDOWN -> 3 (" .. n3 .. "); Detailed log kapali -> 0 (" .. q .. "), 'teshis: G1' yine bir kez (" .. g .. ")")
    end)
    if not full then return end
    H.run("T-DIAG-1", function()
        local function inst(name, set)
            local T = H.boot({ name = name, setup = function(T, W) set(W) end })
            T.W.head_dmg[2] = 50
            T.tick(60)
            T.event("game_newmap", { mapname = "de_inferno" })
            local _, l = H.teshis(T, 1)
            return T, l
        end
        local A, la = inst("diag-1", function() end)
        local B, lb = inst("diag-1-aa", function(W) W.aa_first = true end)
        local Cn, lc = inst("diag-1-hs", function(W) W.hs_first = true end)
        local D, ld = inst("diag-1-olay", function(W) W.ignore_filter = true end)
        local na = la and tonumber(la:match("siralama setup>aa (%d+)/")) or -1
        local da = la and tonumber(la:match("siralama setup>aa %d+/(%d+)")) or -1
        H.check("T-DIAG-1", na == da and da >= 60 and H.has(lb, "siralama setup>aa 0/" .. da)
            and A.count("teshis: G1 SETUP_COMMAND ANTIAIM'den once calisiyor", 1) == 1
            and B.count("teshis: G1 SETUP_COMMAND ANTIAIM'den sonra calisiyor", 1) == 1
            and H.has(la, "hitscan>hedef secimi 0/") and lc ~= nil and lc:match("hitscan>hedef secimi (%d+)/(%d+)") ~= nil
            and lc:match("hitscan>hedef secimi (%d+)/") == lc:match("hitscan>hedef secimi %d+/(%d+)")
            and tonumber(lc:match("hitscan>hedef secimi (%d+)/")) >= 50 and H.has(la, "olay filtresi ihlal 0")
            and (tonumber(ld and ld:match("olay filtresi ihlal (%d+)") or 0) or 0) >= 1
            and D.count("teshis: G24 olay filtresi yok sayiliyor", 1) == 1, "siralama: varsayilan " .. tostring(la)
            .. " | aa once: " .. tostring(lb) .. " | hitscan once: " .. tostring(lc) .. " | filtre yok: " .. tostring(ld))
    end)
    H.run("T-DIAG-2", function()
        local A = H.boot({ name = "diag-2" })
        A.tick(80)
        A.event("game_newmap", { mapname = "de_inferno" })
        local _, la = H.teshis(A, 1)
        local B = H.boot({ name = "diag-2-iki", setup = function(T, W) W.aa_twice = true end })
        B.tick(80)
        B.event("game_newmap", { mapname = "de_inferno" })
        local _, lb = H.teshis(B, 1)
        H.check("T-DIAG-2", H.has(la, "aa/komut ort 1.00 max 1") and H.has(lb, "aa/komut ort 2.00 max 2")
            and A.count("teshis: G27 ANTIAIM komut basina bir kez", 1) == 1
            and B.count("teshis: G27 ANTIAIM ayni komutta birden fazla", 1) == 1 and H.has(la, "unpred bayrak 0/")
            and A.count("teshis: G23 ANTIAIM'e unpredicted_data gelmiyor", 1) == 1, "ANTIAIM komut basina: tek "
            .. tostring(la and la:match("aa/komut [^,]*")) .. ", iki kez " .. tostring(lb and lb:match("aa/komut [^,]*")))
    end)
    H.run("T-DIAG-3", function()
        local T = H.boot({ name = "diag-3" })
        T.W.head_dmg[2] = 50
        T.tick(20)
        for _, r in ipairs({ "spread", "resolver", "spread", "server rejection" }) do
            local id = T.shoot(2)
            T.tick(2)
            T.miss(id, r)
            T.tick(2)
        end
        T.event("game_newmap", { mapname = "de_inferno" })
        local _, l1 = H.teshis(T, 1)
        T.tick(20)
        local id = T.shoot(2); T.tick(2); T.miss(id, "jitter"); T.tick(2)
        id = T.shoot(2); T.tick(2); T.miss(id, "jitter"); T.tick(2)
        T.shutdown()
        local _, l2 = H.teshis(T, 1)
        H.check("T-DIAG-3", H.has(l1, "iska sebepleri spread 2, resolver 1, server rejection 1 (jitter yok)")
            and H.has(l2, "iska sebepleri jitter 2 (jitter var)") and T.count("teshis: G17 iska sebebi 'spread' (ilk kez)", 1) == 1
            and T.count("teshis: G17 iska sebebi 'jitter' (ilk kez)", 1) == 1, "iska sebebi histogrami: "
            .. tostring(l1 and l1:match("iska sebepleri [^)]*%)")) .. " | " .. tostring(l2 and l2:match("iska sebepleri [^)]*%)")))
    end)
    H.run("T-DIAG-4", function()
        local T = H.boot({ name = "diag-4" })
        local W = T.W
        W.head_dmg[2] = 50
        T.tick(30)
        W.p[2].sim_shift = 6
        T.tick(2)
        local held = T.ignored(2, W.tick, W.tick)
        local m = T.mark()
        local id = T.shoot(2); T.tick(1); T.hit(id, { hg = 1, dmg = 50 })
        local g1 = T.count("teshis: G8 bekletilen hedefe atis geldi (Alpha, real bekleme)", m)
        T.event("game_newmap", { mapname = "de_inferno" })
        local _, l1 = H.teshis(T, 1)
        W.p[2].sim_shift = 0
        W.p[2].health = 100
        T.tick(40)
        W.p[2].sim_shift = 6
        T.tick(2)
        id = T.shoot(2); T.tick(1); T.miss(id, "spread")
        T.shutdown()
        local _, l2 = H.teshis(T, 1)
        H.check("T-DIAG-4", held == 1 and g1 == 1 and H.has(l1, "bekleme ihlali 1/1") and H.has(l2, "bekleme ihlali 1/1")
            and T.count("teshis: G8", 1) == 1, "bekletilen hedefe (ignore_target " .. held .. ") atis: " ..
            tostring(l1 and l1:match("bekleme ihlali [%d/]+")) .. ", teshis G8 bir kez (" .. T.count("teshis: G8", 1)
            .. "); yeni haritada " .. tostring(l2 and l2:match("bekleme ihlali [%d/]+")))
    end)
    H.run("T-DIAG-7", function()
        -- G6: seviye 2 (dusuk can, tufek) vurulabilir hedefte 64 tick, 2 atis -> 2.0 atis/sn; G12 USE basili; G10 tus modu.
        local T = H.boot({ name = "diag-7", setup = function(T, W) W.dt_mode = 2 end })
        local W = T.W
        W.p[1].weapon = H.weapon("ak47")
        W.p[2].health = 25
        W.head_dmg[2] = 50; W.body_dmg[2] = 20
        T.tick(32)
        local id = T.shoot(2); T.tick(2); T.miss(id, "spread")
        T.tick(16)
        id = T.shoot(2); T.tick(2); T.miss(id, "spread")
        T.tick(10)
        W.buttons.USE = true
        T.tick(6)
        W.buttons.USE = nil
        T.event("game_newmap", { mapname = "de_inferno" })
        local _, l = H.teshis(T, 1)
        local lv2, lt2 = nil, nil
        if l then lv2, lt2 = l:match("seviye2 ([%d%.]+) atis/sn %((%d+) tick%)") end
        local rate = lt2 and tonumber(lt2) > 0 and 2 / (tonumber(lt2) / 64) or -1
        -- G5: block_recharge sizdiriyor -> eski yolda (Air LC + havada teleport) kilit tutulurken sarj artar.
        local G = H.boot({ name = "diag-7-sizinti", rec_off = true, setup = function(T, W)
            T.set("air_teleport", false); W.rc_leak = true
        end })
        G.tick(30)
        H.seen_jump(G, 300)
        G.tick(5)
        G.event("game_newmap", { mapname = "de_inferno" })
        local _, lg = H.teshis(G, 1)
        local Q = H.boot({ name = "diag-7-kilit", rec_off = true, setup = function(T) T.set("air_teleport", false) end })
        Q.tick(30)
        H.seen_jump(Q, 300)
        Q.tick(5)
        Q.event("game_newmap", { mapname = "de_inferno" })
        local _, lq = H.teshis(Q, 1)
        local g5 = tonumber(lg and lg:match("sarj kilitliyken artis (%d+) tick") or -1)
        H.check("T-DIAG-7", lv2 ~= nil and tonumber(lt2) >= 40 and math.abs(tonumber(lv2) - rate) <= 0.051
            and H.has(l, "USE basiliyken aa 6/6") and T.count("teshis: G12 USE basiliyken ANTIAIM calisiyor", 1) == 1
            and H.has(l, "DT tus modu 2") and T.count("teshis: G10 DT tus modu 2", 1) == 1 and g5 >= 5
            and G.count("teshis: G5 block_recharge tutulurken sarj artti", 1) == 1 and H.has(lq, "sarj kilitliyken artis 0 tick"),
            "seviye 2: " .. tostring(lv2) .. " atis/sn (" .. tostring(lt2) .. " tick, beklenen " .. H.f1(rate) .. "), USE: "
            .. tostring(l and l:match("USE basiliyken aa [%d/]+")) .. ", " .. tostring(l and l:match("DT tus modu %d")) ..
            "; sizan kilit " .. tostring(g5) .. " tick, tutan kilit " .. tostring(lq and lq:match("sarj kilitliyken artis %d+")))
    end)
    H.run("T-DIAG-6", function()
        local T = H.boot({ name = "diag-6" })
        local W = T.W
        local start = 10001
        W.head_dmg[2] = 50; W.body_dmg[2] = 40; W.sees[2] = 60
        T.tick(60)
        W.sees[2] = 0; W.head_dmg[2] = 0; W.body_dmg[2] = 0
        T.tick(40)
        local sum, mx, n = 0, 0, 0
        for t = start, W.tick do
            local c = T.ntr[t] or 0
            sum, mx, n = sum + c, math.max(mx, c), n + 1
        end
        local before = T.ntr[W.tick] or 0
        T.event("game_newmap", { mapname = "de_inferno" })
        local after = T.ntr[W.tick] or 0
        local _, l = H.teshis(T, 1)
        local avg, lmax, lt = nil, nil, nil
        if l then avg, lmax, lt = l:match("iz/tick ort ([%d%.]+) max (%d+) %((%d+) tick%)") end
        H.check("T-DIAG-6", avg ~= nil and avg:match("^%d+%.%d$") ~= nil and math.abs(tonumber(avg) - sum / n) <= 0.051
            and tonumber(lmax) == mx and tonumber(lt) == n and after == before and sum > 0, "iz / tick: satir "
            .. tostring(avg) .. " max " .. tostring(lmax) .. " (" .. tostring(lt) .. " tick), mock " .. H.f1(sum / n) .. " max "
            .. mx .. " (" .. n .. " tick); satiri yazmak iz atmaz (" .. before .. " -> " .. after .. ")")
    end)
end

-------------------------------------------------------------------------------
-- Toplu kontroller (her modda, tum ornekler uzerinde)
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Stats paneli (GS draw_stats), resolver paneli cozum / HIT, harita ozeti (R1-B4)
-------------------------------------------------------------------------------
-- Ayni tick'te n kare daha (oyunda PAINT tick'ten sik gelir; FPS kurali T-STAT-7).
function H.paint(T, n)
    for _ = 1, n do
        T.in_paint = true
        T.fire("PAINT")
        T.in_paint = false
    end
end
-- Bu tick'te cizilen ve s'yi iceren ilk yazi.
function H.text_at(T, s)
    for _, x in ipairs(T.texts(T.W.tick, T.W.tick)) do
        if x.s:find(s, 1, true) then return x end
    end
    return nil
end
-- Stats paneli satirlari (sag ust, resolver panelinin sagi: x > 1100) bu tick'te, " ; " ile.
function H.stat_rows(T)
    local r = {}
    for _, x in ipairs(T.texts(T.W.tick, T.W.tick, function(x) return x.x > 1100 and x.y < 1000 and x.y >= 300 end)) do
        r[#r + 1] = x.s
    end
    return table.concat(r, " ; ")
end
-- Butun durumlarda defensive Off (DEF payi sadece betigin zorladigi tick'ler).
function H.def_off(T)
    for _, st in ipairs({ "Standing", "Moving", "Slow walk", "Crouching", "Crouch move", "Peek", "Air", "Air crouch",
        "Manual", "Freestanding", "Safe head" }) do
        if T.el("x:" .. st .. ":Defensive") then T.xset(st, "Defensive", 1) end
    end
end

function C.stat_full()
    H.run("T-STAT-1", function()
        local T = H.boot({ name = "stat-1", rec_off = true, setup = function(T)
            T.xset("Standing", "Defensive", 4)
            T.set("stats_panel", true)
            H.edge_off(T)
        end })
        local W = T.W
        T.tick(40)
        W.auto_recharge = false
        T.press("stats_reset")
        local t0 = W.tick
        local shift = T.EX.force_anti_exploit_shift
        -- Always on: 1-6 dolu; 4-6'da force_anti_exploit_shift hata (zorlanamadi) -> 3 zorlama; 7-10 yarim sarj.
        T.EX.force_anti_exploit_shift = function()
            local k = W.tick - t0
            if k >= 4 and k <= 6 then error("red") end
            return shift()
        end
        T.tick(10, function(T, W) W.charge = (W.tick - t0 <= 6) and 14 or 7 end)
        local rows = H.stat_rows(T)
        H.check("T-STAT-1", rows:find("STANDING   0 / 0 / 0 / 60% / 30%", 1, true) ~= nil
            and rows:find("AA STATS   HIT / HEAD / MISS / DT / DEF", 1, true) ~= nil,
            "10 tick Standing, DT dolu 6, DEF zorlanan 3 -> 'STANDING   0 / 0 / 0 / 60% / 30%': " .. rows)
    end)
    H.run("T-STAT-2", function()
        local T = H.boot({ name = "stat-2", setup = function(T) T.set("stats_panel", true) end })
        T.tick(20)
        local function shot(res, reason)
            local id = T.shoot(2)
            T.tick(1)
            if res == "hit" then T.hit(id, { hg = 2, dmg = 20, no_event = true }) else T.miss(id, reason) end
            T.tick(2)
        end
        shot("hit"); shot("hit"); shot("miss", "resolver"); shot("miss", "spread"); shot("miss", "prediction error")
        T.tick(1)
        local rows = H.stat_rows(T)
        local lh, ls, ch, cs = rows:match("LAG   (%d+) / (%d+)   TEMIZ   (%d+) / (%d+)")
        local split = lh ~= nil and tonumber(lh) + tonumber(ch) == 2 and tonumber(ls) + tonumber(cs) == 5
        -- Kaydi bilinmeyen atisin sonucu (id yok): ALL'a girer, LAG / TEMIZ'e girmez.
        T.miss(999, "spread")
        T.tick(1)
        local rows2 = H.stat_rows(T)
        local ls2, cs2 = rows2:match("LAG   %d+ / (%d+)   TEMIZ   %d+ / (%d+)")
        H.check("T-STAT-2", rows:find("AIM   SHOT / HIT / CORR / SPREAD / OTHER ; ALL   5 / 2 / 1 / 1 / 1", 1, true) ~= nil
            and split and rows2:find("ALL   6 / 2 / 1 / 2 / 1", 1, true) ~= nil and ls2 ~= nil
            and tonumber(ls2) + tonumber(cs2) == 5, "5 atis (2 isabet, resolver, spread, prediction error) -> 'ALL   5 / 2 /"
            .. " 1 / 1 / 1', lag + temiz = 2/5; kaydi olmayan sonuc lag / temize girmez: " .. rows2)
    end)
    H.run("T-STAT-3", function()
        local T = H.boot({ name = "stat-3", setup = function(T) T.set("stats_panel", true) end })
        local W = T.W
        local function respawn()
            W.p[1].alive = true; W.p[1].ground = true; W.p[1].air_phys = false; W.p[1].health = 100
            W.p[1].origin = V.v3(0, 0, 0); W.p[1].vel = V.v3(0, 0, 0)
            T.event("player_spawn", { userid = 101 })
            T.tick(20)
        end
        T.tick(20)
        local st1 = T.probe_state()
        T.event("player_death", { userid = 102, attacker = 101, weapon = "ssg08", headshot = true })
        T.jump(300)
        T.tick(6)
        local st2 = T.probe_state()
        T.event("player_death", { userid = 101, attacker = 103, weapon = "ak47" })
        W.p[1].alive = false
        T.tick(2)
        respawn()
        -- Intihar ve dunya (saldiran yok): sayilmaz.
        T.event("player_death", { userid = 101, attacker = 101, weapon = "hegrenade" })
        W.p[1].alive = false
        T.tick(2)
        respawn()
        T.event("player_death", { userid = 101, attacker = 0, weapon = "world" })
        W.p[1].alive = false
        T.tick(2)
        respawn()
        local rows = H.stat_rows(T)
        local m = T.mark()
        T.event("game_newmap", { mapname = "de_nuke" })
        local line = T.printed("harita ozeti:", m)
        H.check("T-STAT-3", st1 == "Standing" and st2 == "Air" and rows:find("KD   OLDURDUN / OLDUN ; STANDING   1 / 0 ;"
            .. " AIR   0 / 1 ;", 1, true) ~= nil and H.has(line, "| KD 1/1 (Standing 1/0, Air 0/1) |"), "Standing'de kill,"
            .. " Air'de dusmana olum, intihar / dunya sayilmaz (" .. tostring(st1) .. ", " .. tostring(st2) .. "): " .. rows
            .. " | " .. tostring(line))
    end)
    H.run("T-STAT-4", function()
        local T = H.boot({ name = "stat-4", setup = function(T) T.set("stats_panel", true) end })
        local W = T.W
        H.peek_world(T, W)
        local m = T.mark()
        local started = nil
        for _ = 1, 300 do
            T.tick(1)
            if T.printed("ai peek: sol", m) or T.printed("ai peek: sag", m) then started = W.tick; break end
        end
        T.tick(3)
        T.hurt_me(2, 2, 10, "ak47")
        local id = T.shoot(2)
        T.tick(1)
        T.hit(id, { hg = 1, dmg = 30, no_event = true })
        local res = nil
        for _ = 1, 200 do
            T.tick(1)
            res = T.printed("ai peek sonucu:", m)
            if res then break end
        end
        local row = nil
        for _ = 1, 400 do
            T.tick(1)
            local x = H.text_at(T, "AI PEEK   2 / 1 / 1 / 1 / 1")
            if x then row = x.s; break end
        end
        local m2 = T.mark()
        T.event("game_newmap", { mapname = "de_nuke" })
        local line = T.printed("harita ozeti:", m2)
        H.check("T-STAT-4", started ~= nil and res ~= nil and row ~= nil and H.has(line, "| ai peek 2/1/1/1/1 |")
            and T.printed("atis olmadi", m) ~= nil, "peek -> vurulma -> atis -> isabet -> donus, sonra bos peek: 'AI PEEK"
            .. "   2 / 1 / 1 / 1 / 1' (" .. tostring(row) .. "), ozet: " .. tostring(line))
    end)
    H.run("T-STAT-5", function()
        local mem = H.mem2({ "V\tphases\t2", "F2\tstill\t0\t14\t10", "F2\tmove\t3\t5\t1" })
        local T = H.boot({ name = "stat-5", files = { ["nykle_memory.txt"] = mem },
            setup = function(T) T.set("stats_panel", true) end })
        T.tick(5)
        local rows = H.stat_rows(T)
        H.check("T-STAT-5", rows:find("AA FAZ   KAFA ISABETI / MERMI ; STILL   0x 10/14   1* 0/0   2 0/0", 1, true) ~= nil
            and rows:find("MOVE   0* 0/0   1 0/0   2 0/0   3 1/5   4 0/0", 1, true) ~= nil
            and rows:find("AIR   0* 0/0", 1, true) ~= nil, "faz 0 14 mermide 10 kafa (kotu bilinen) -> '0x', varsayilan faz"
            .. " 1 -> '1*'; 5 mermili faz kotu degil: " .. rows)
    end)
    H.run("T-STAT-6", function()
        local A = H.boot({ name = "stat-6-bos" })
        A.tick(20)
        local a1, a2 = H.text_at(A, "cozum %"), H.text_at(A, "HIT %")
        local B = H.boot({ name = "stat-6-jit" })
        local W = B.W
        B.tick(30, H.yaw_hook(2, { 120, 240 }))
        W.p[2].ground = false
        W.p[2].sim_shift = 10
        B.tick(1, H.yaw_hook(2, { 120, 240 }))
        local b1, b2 = H.text_at(B, "cozum %"), H.text_at(B, "HIT %")
        local Cc = H.boot({ name = "stat-6-corr" })
        Cc.tick(20)
        for _, r in ipairs({ "hit", "resolver", "hit", "resolver" }) do
            local id = Cc.shoot(2)
            Cc.tick(1)
            if r == "hit" then Cc.hit(id, { hg = 2, dmg = 1, no_event = true }) else Cc.miss(id, r) end
            Cc.tick(2)
        end
        Cc.tick(70)
        local c1, c2 = H.text_at(Cc, "cozum %"), H.text_at(Cc, "HIT %")
        local function s(x) return x and x.s or "yok" end
        H.check("T-STAT-6", s(a1) == "cozum %80" and s(a2) == "HIT %72" and s(b1) == "cozum %29" and s(b2) == "HIT %26"
            and s(c1) == "cozum %60" and s(c2) == "HIT %56", "veri yok: " .. s(a1) .. " " .. s(a2) .. " (80 / 72); jitter 120 +"
            .. " havada + sahte kayit: " .. s(b1) .. " " .. s(b2) .. " (29 / 26); son 4 sonucun 2'si correction: " .. s(c1) .. " "
            .. s(c2) .. " (60 / 56)")
    end)
    H.run("T-STAT-7", function()
        local T = H.boot({ name = "stat-7", setup = function(T) T.set("stats_panel", true) end })
        local W = T.W
        W.sees[2] = 60
        local function worst(t0, t1)
            local w = { name = 0, sid = 0, trace = 0, ent = 0 }
            for t = t0, t1 do
                for k, v in pairs(T.pread[t] or {}) do if v > w[k] then w[k] = v end end
            end
            return w
        end
        T.tick(10)
        local b0 = W.tick + 1
        T.tick(70)
        local one = worst(b0, W.tick)
        local t0 = W.tick + 1
        for _ = 1, 130 do
            T.tick(1)
            H.paint(T, 2)
        end
        local w = worst(t0, W.tick)
        local drawn = H.text_at(T, "cozum %") ~= nil and H.text_at(T, "AA STATS") ~= nil
        H.check("T-STAT-7", drawn and w.name <= 1 and w.sid <= 1 and w.trace == 0 and one.ent > 0 and w.ent <= one.ent,
            "tick basina 3 kare, paneller acik: PAINT'te tick basina en fazla 1 isim / 1 Steam ID okumasi, hic iz, dusman"
            .. " okumasi tek karelik tick kadar (isim " .. w.name .. ", sid " .. w.sid .. ", iz " .. w.trace .. ", dusman "
            .. w.ent .. " / tek kare " .. one.ent .. ", cizildi " .. tostring(drawn) .. ")")
    end)
    H.run("T-STAT-8", function()
        local T = H.boot({ name = "stat-8", rec_off = true, setup = function(T) H.def_off(T) end })
        local W = T.W
        T.tick(40)
        T.press("stats_reset")
        T.tick(20)
        T.event("round_start", {})
        T.tick(5)
        local id = T.shoot(2)
        T.tick(1)
        T.hit(id, { hg = 2, dmg = 20, no_event = true })
        T.tick(2)
        id = T.shoot(2)
        T.tick(1)
        T.miss(id, "spread")
        T.tick(2)
        T.event("player_death", { userid = 102, attacker = 101, weapon = "ssg08" })
        T.tick(70)
        T.event("round_start", {})
        T.tick(5)
        W.real_off = W.real_off + 120
        T.tick(5)
        local m = T.mark()
        T.event("game_newmap", { mapname = "de_nuke" })
        -- Ayni harita degisiminde yerel oyuncu yok / geri gelir: N.map_reset iki kez daha, satir yine tek.
        W.map = "de_nuke"
        W.no_local = true; T.tick(3); W.no_local = false; T.tick(3)
        local line = H.bare(T.printed("harita ozeti:", m))
        local again = T.count("harita ozeti:", m)
        local want = "harita ozeti: de_mirage 2 dk, 2 round | KD 1/0 (Standing 1/0) | atis 2 isabet 1 correction 0"
            .. " spread 1 diger 0 | lag 0/0 temiz 1/2 | ai peek 0/0/0/0/0 | DT dolu %100 DEF %0 | faz kafa still 0:0/0"
            .. " move 0:0/0 peek 0:0/0 air 0:0/0"
        -- Yeni harita: sayac sifirdan (sadece bu haritanin olaylari); Reset stats harita kumesini de sifirlar
        -- (kapanis satiri sifirli).
        T.tick(10)
        id = T.shoot(2)
        T.tick(1)
        T.hit(id, { hg = 2, dmg = 20, no_event = true })
        T.event("player_death", { userid = 103, attacker = 101, weapon = "ssg08" })
        T.tick(5)
        local m1 = T.mark()
        T.event("game_newmap", { mapname = "de_inferno" })
        local nuke = H.bare(T.printed("harita ozeti:", m1))
        W.map = "de_inferno"
        T.tick(10)
        id = T.shoot(2)
        T.tick(1)
        T.miss(id, "spread")
        T.tick(5)
        T.press("stats_reset")
        T.tick(70)
        local m2 = T.mark()
        T.shutdown()
        local z = H.bare(T.printed("harita ozeti:", m2))
        -- Iki log da kapali: satir yok. 20 roundda bir ara ozet.
        local Q = H.boot({ name = "stat-8-kapali" })
        Q.set("hit_log", false)
        Q.set("shot_log", false)
        Q.tick(80)
        local qm = Q.mark()
        Q.event("game_newmap", { mapname = "de_nuke" })
        Q.shutdown()
        local R = H.boot({ name = "stat-8-20" })
        R.set("debug_log", false)
        R.tick(10)
        local rm = R.mark()
        for _ = 1, 41 do
            R.event("round_start", {})
            R.tick(4)
        end
        local n20 = R.count("harita ozeti:", rm)
        local l20 = H.bare(R.printed("harita ozeti:", rm))
        H.check("T-STAT-8", line == want and again == 1 and H.has(nuke, "harita ozeti: de_nuke 0 dk, 0 round | KD 1/0"
            .. " (Standing 1/0) | atis 1 isabet 1 correction 0 spread 0 diger 0 | lag 0/0 temiz 1/1 |")
            and H.has(z, "harita ozeti: de_inferno 0 dk, 0 round | KD 0/0 | atis 0"
            .. " isabet 0 correction 0 spread 0 diger 0 | lag 0/0 temiz 0/0 | ai peek 0/0/0/0/0 |")
            and Q.count("harita ozeti:", qm) == 0 and n20 == 2 and H.has(l20, " 20 round |"), "harita degisiminde tam satir ("
            .. tostring(line) .. ", " .. again .. " kez); sonraki harita sadece kendi olaylari: " .. tostring(nuke)
            .. "; Reset stats sonrasi kapanis: " .. tostring(z) .. "; loglar kapali: "
            .. Q.count("harita ozeti:", qm) .. "; 41 roundda " .. n20 .. " ara ozet (" .. tostring(l20) .. ")")
    end)
    H.run("T-STAT-10", function()
        -- API 7.4: safe point'li atisin spread iskasi "spread (missed safe)" -> SPREAD (diger degil), teshis aynen.
        local T = H.boot({ name = "stat-10", rec_off = true, setup = function(T) T.set("stats_panel", true) end })
        T.tick(20)
        T.press("stats_reset")
        T.tick(2)
        local id = T.shoot(2)
        T.tick(1)
        T.miss(id, "spread (missed safe)")
        T.tick(2)
        id = T.shoot(2)
        T.tick(1)
        T.miss(id, "occlusion")
        T.tick(2)
        local rows = H.stat_rows(T)
        local g17 = H.bare(T.printed("teshis: G17 iska sebebi 'spread"))
        local m = T.mark()
        T.event("game_newmap", { mapname = "de_nuke" })
        local line = H.bare(T.printed("harita ozeti:", m)) or ""
        H.check("T-STAT-10", rows:find("ALL   2 / 0 / 0 / 1 / 1", 1, true) ~= nil and g17 == "teshis: G17 iska sebebi"
            .. " 'spread (missed safe)' (ilk kez)" and H.has(line, "atis 2 isabet 0 correction 0 spread 1 diger 1 |"),
            "'spread (missed safe)' + occlusion -> ALL 2/0/0/1/1 (" .. rows:sub(1, 160) .. "); " .. tostring(g17) .. "; "
            .. line:sub(1, 120))
    end)
end
function C.stat()
    H.run("T-STAT-9", function()
        local T = H.boot({ name = "stat-9" })
        T.tick(10)
        local off = H.text_at(T, "AA STATS") == nil
        T.set("stats_panel", true)
        T.tick(2)
        local x = H.text_at(T, "AA STATS   HIT / HEAD / MISS / DT / DEF")
        local ok1 = x ~= nil and x.x > 960 and x.fs == 12
        local K = H.boot({ name = "stat-9-4k", setup = function(T) T.set("stats_panel", true) end })
        K.W.screen_w, K.W.screen_h = 3840, 2160
        K.tick(3)
        local y = H.text_at(K, "AA STATS")
        local y2 = H.text_at(K, "AA FAZ")
        local ok2 = y ~= nil and y.fs == 24 and y.x > 1920 and y2 ~= nil and y2.fs == 24
        H.check("T-STAT-9", off and ok1 and ok2, "Stats panel kapali: yazi yok (" .. tostring(off) .. "); acik: sagda, 1080p'de"
            .. " 12 px (" .. tostring(x and x.fs) .. "), 2160p'de 24 px (" .. tostring(y and y.fs) .. "); PAINT disi render"
            .. " X-API-1'de")
    end)
end

function C.aggregate()
    local G = H.G
    H.check("T-LOAD-2", next(G.global_write) == nil and next(G.unknown_global) == nil,
        "global yazma yok (" .. H.list(H.keys(G.global_write), 6) .. "), bilinmeyen global okuma yok ("
        .. H.list(H.keys(G.unknown_global), 6) .. ")")
    H.check("T-LOAD-8", #G.hata == 0, "hicbir senaryoda 'hata verdi' yok (" .. #G.hata .. ")" .. (#G.hata > 0 and (": " .. H.list(G.hata, 3)) or ""))
    H.check("T-OV-5", #G.native_bad == 0, "native yazmalar sadece §3.4 anahtarlarina, keybind :set yok (" .. #G.native_bad .. ")"
        .. (#G.native_bad > 0 and (": " .. H.list(G.native_bad, 4)) or ""))
    H.check("T-RAGE-12", #G.md_bad == 0, "U3: md_need altindaki her set_min_dmg R4-R7 on kosuluyla (" .. #G.md_bad .. " ihlal)"
        .. (#G.md_bad > 0 and (": " .. H.list(G.md_bad, 3)) or ""))
    H.check("T-RAGE-14", #G.sp_false == 0, "set_safepoint_state(false, ...) hic yok (" .. #G.sp_false .. ")")
    H.check("T-RC-1", #G.rc_left == 0, "her ornek SHUTDOWN'dan sonra sarj kilidi acik (" .. H.list(G.rc_left, 4) .. ")")
    H.check("X-API-1", next(G.forbidden) == nil, "yasak API / disiplin (log_screen, force_recharge, multi_selection,"
        .. " DRAW_WATERMARK, PAINT disi render, callback icinde callbacks.add, aralik disi secim): " .. H.list(H.keys(G.forbidden), 6))
    H.check("X-API-2", next(G.offlist) == nil, "§3.2 listesi disinda API yok: " .. H.list(H.keys(G.offlist), 8))
    H.check("X-API-3", next(G.enum_bad) == nil, "kati enumlar: native olmayan uye yok (STOMACH / RELOAD / SNIPER): "
        .. H.list(H.keys(G.enum_bad), 6))
    H.check("T-DLOG-12", #G.nonascii == 0, "her ornekte dbg / teshis satirlari ASCII (" .. #G.nonascii .. ": "
        .. H.list(G.nonascii, 2) .. ")")
    H.check("X-API-4", next(G.fmt_bad) == nil, "%d / %x yalnizca tam sayiyla (LuaJIT): " .. H.list(H.keys(G.fmt_bad), 4))
    H.check("X-API-5", #G.raw_err == 0, "hicbir hata dagiticidan disari kacmaz (" .. #G.raw_err .. ")"
        .. (#G.raw_err > 0 and (": " .. H.list(G.raw_err, 3)) or ""))
end

-------------------------------------------------------------------------------
-- Ana akis
-------------------------------------------------------------------------------
function H.main()
    if SRC == nil or #SRC < 100 then
        H.check("T-LOAD-1", false, "script kaynagi gelmedi (ARGV[2])")
        return
    end
    if MODE == "full" then
        C.load_full()
        C.menu()
        C.override()
        C.recharge()
        C.aa()
        C.brute()
        C.exploits()
        C.rage()
        C.peek()
        C.logs()
        C.misc()
        C.draw()
        C.review()
        C.load_errors()
    else
        H.run("T-LOAD-1", function()
            local T = H.make({ name = "yukle-" .. MODE })
            H.check("T-LOAD-1", T.ok and T.printed(H.VER .. " (primordial edition) yuklendi") ~= nil,
                "mod " .. MODE .. ": yuklenir ve yukleme satiri basilir" .. (T.ok and "" or (": " .. tostring(T.load_err))))
        end)
        if MODE == "noffi" then C.log_noffi() end
    end
    C.dlog()
    C.prof()
    if MODE == "full" then C.chg() end
    C.diag()
    if MODE == "full" then C.stat_full() end
    C.stat()
    C.sweep_mode()
    C.aggregate()
end
H.smt.__index = H.sproxy
local ok, err = pcall(H.main)
H.smt.__index = H.sidx_old
if not ok then H.check("HARNESS", false, "harness hatasi: " .. tostring(err)) end
H.log("mod " .. MODE .. ": " .. H.passes .. " PASS, " .. H.fails .. " FAIL, " .. H.G.insts .. " script ornegi")
H.log(H.fails == 0 and "ALL PASSED" or ("FAILED " .. H.fails))
return H.out
