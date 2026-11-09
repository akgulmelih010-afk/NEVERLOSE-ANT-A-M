--[[
    Nykle.win lua V1.0.0  |  primordial edition  |  primordial (CS:GO) icin HvH anti-aim, exploit ve resolver lua'si

    GameSense surumunun (Nykle.win.gamesense.lua V1.0.79) loglarla kanitlanan ozelliklerinin ve Neverlose
    surumunun (Nykle.win.lua V1.1.x) kurallarinin primordial API'sine tasinmis hali.
    Kurar kurmaz calisir: butun varsayilanlar en iyi bilinen degerlerle gelir ("Always use recommended
    settings" acik kaldikca bu degerler korunur). Menu: Scripts sekmesi > "Nykle.win | ..." gruplari
    (Home > Tab ile sekme secilir).

    Dosya adi "Nykle.win.lua" kalmali: primordial config'te script ayarlari dosya adiyla ("Nykle.win") ve
    grup / oge adlariyla saklanir; adlar degisirse kayitli ayarlar okunmaz.

    GameSense surumunden farklar (primordial API'sinin izin verdigi kadar, bkz. primordial/README.md):
      - AA her tick ANTIAIM callback'inin ctx:set_yaw / set_desync / set_pitch ile verilir; native AA
        ayarlari (jitter, rotate, body lean, desync tarafi, anti bruteforce, on shot, yaw add) notrde tutulur
        ve kapatinca / script kaldirilinca senin degerlerine geri doner.
      - Roll / extended angles YOK (sunucunda yasak): her tick ctx:set_body_lean(0).
      - Freestanding: native Auto Direction tusu okunur (MOUSE5); tus basiliyken kafa acikta degilse
        script yaw yazmaz, native freestanding kafayi saklar.
      - Defensive: exploits.force_anti_exploit_shift() (sadece DT dolu iken). Teleport: force_uncharge.
        Safe recharge: block_recharge / allow_recharge (tek sahip, 3 sn bekci).
      - Resolver: primordial'da dusmana aci zorlama yok; dusman basina safe point seviyesi, gercek / taze
        kayit bekleme ve Min. damage kurallari HITSCAN / TARGET_SELECTION ile hedef basina verilir.
      - Min. damage sadece belgelenmis kurallarla duser: yakinda bicak / zeus, DT cifti (kapali),
        extended / kafa saklayan dusmana govde. Senin Min. damage override tusun basiliyken hicbiri calismaz.
      - Hafiza ve log dosyasi: ffi ile CS:GO dosya sistemi (nykle_memory.txt, nykle_log.txt; csgo klasoru).
      - DT / HS / fake duck / autopeek tuslarini script degistiremez: config'te DT her zaman acik gelir.

    Surum gecmisi:
      V1.0.0 (primordial edition): ilk surum. GameSense V1.0.79 varsayilanlari (builder, exploit satirlari,
        anti-brute fazlari 0-8 ve ogrenme, Smart defensive + re-arm cooldown + anti-peek, temiz atis,
        safe recharge, havada teleport + Air LC, gercek / taze kayit bekleme, bicak / zeus Min. damage,
        extended ve kafa saklayana govde, adaptif safe point resolver'i, AI peek, AFK + otomatik AFK,
        sol el, 4:3, FPS boost, clan tag, otomatik bomba alma, gostergeler ve GS ile ayni log satirlari).
]]

local N = {
    SCRIPT = "Nykle.win", VERSION = "1.0.0", EDITION = "primordial",
    util = {}, log = {}, fs = {}, ref = {}, ui = {}, ov = {}, rc = {}, mem = {}, track = {}, exposure = {},
    state = {}, aa = {}, brute = {}, ex = {}, rage = {}, peek = {}, afk = {}, shots = {}, stats = {}, misc = {},
    draw = {}, cb = {}, tick = {}, K = {},
    st = { on = false, enabled = true, tick = 0, cmdn = -1, lp = nil, alive = false, dead = true, idx = nil,
        enemies = {}, enemies_tick = -1, any_enemy_alive = true, state = "Standing", move_state = "Standing",
        label = "Standing", threat = nil, weapon = nil, wgroup = "auto", round_start_at = -1000,
        last_round_start = -1000, last_shot = -1000, spawn_at = -1000, map = nil },
}
local floor, abs, sqrt, min, max = math.floor, math.abs, math.sqrt, math.min, math.max
local random, huge = math.random, math.huge
local pcall, type, tostring, tonumber, pairs, ipairs = pcall, type, tostring, tonumber, pairs, ipairs
local fmt, concat, tremove = string.format, table.concat, table.remove

-------------------------------------------------------------------------------
-- Sabitler
-------------------------------------------------------------------------------
do
    local K = N.K
    K.STATES = { "Global", "Standing", "Moving", "Slow walk", "Crouching", "Crouch move", "Peek", "Air",
        "Air crouch", "Fake duck", "Manual", "Freestanding", "Safe head" }
    -- Override kutusu olan hareket durumlari (Global'in AA'sini paylasabilenler).
    K.OVERRIDABLE = { Standing = true, Moving = true, ["Slow walk"] = true, Crouching = true,
        ["Crouch move"] = true, Peek = true, Air = true, ["Air crouch"] = true }
    K.MOVEMENT = { Global = true, Standing = true, Moving = true, ["Slow walk"] = true, Crouching = true,
        ["Crouch move"] = true, Peek = true, Air = true, ["Air crouch"] = true }
    -- { yaw sol, yaw sag, jitter gecikmesi, sol limit, sag limit } (GS DEFAULTS, loglarla dogrulanmis)
    K.DEFAULTS = {
        Global = { -20, 40, 1, 60, 60 }, Standing = { -23, 51, 1, 60, 60 }, Moving = { -20, 50, 1, 58, 58 },
        ["Slow walk"] = { -23, 51, 2, 58, 58 }, Crouching = { -20, 30, 1, 58, 58 },
        ["Crouch move"] = { -20, 30, 1, 58, 58 }, Peek = { -20, 45, 1, 58, 58 }, Air = { -13, 34, 1, 58, 58 },
        ["Air crouch"] = { -15, 44, 1, 58, 58 }, ["Fake duck"] = { 0, 0, 1, 58, 58 },
        Manual = { 0, 0, 1, 60, 60 }, Freestanding = { 0, 0, 1, 60, 60 }, ["Safe head"] = { 0, 0, 1, 30, 30 },
    }
    -- { defensive, hidden pitch, hidden yaw } (GS EXPLOIT_DEFAULTS; "Exploit" sutunu primordial'da yok)
    K.EXPLOIT_DEFAULTS = {
        Standing = { "Smart", "Off", "Off" }, Moving = { "Smart", "Up", "Random" },
        ["Slow walk"] = { "Smart", "Up", "Random" }, Crouching = { "Smart", "Off", "Off" },
        ["Crouch move"] = { "Smart", "Up", "Random" }, Peek = { "Smart", "Off", "Off" },
        Air = { "Smart", "Up", "Spin" }, ["Air crouch"] = { "Smart", "Up", "Random" },
        Manual = { "Smart", "Off", "Off" }, Freestanding = { "Smart", "Off", "Off" },
        ["Safe head"] = { "On peek", "Off", "Off" },
    }
    K.WAY_DEFAULTS = { -30, 0, 30, -15, 15 }
    K.YAW_MODES = { "L&R", "X-Way" }
    K.MODIFIERS = { "Off", "Center", "Offset", "Random", "Spin", "3-Way", "5-Way" }
    K.BODY_YAWS = { "Jitter", "Static", "Random", "Off" }
    K.ON_OFF = { "Off", "On" }
    K.DEF_MODES = { "Off", "On peek", "Smart", "Always on", "Tick based" }
    K.HIDDEN_PITCHES = { "Off", "Down", "Up", "Zero", "Switch", "Random", "Custom" }
    K.HIDDEN_YAWS = { "Off", "Sideways", "Spin", "Random", "Forward", "Custom" }
    K.TABS = { "Home", "Anti-Aim", "Builder", "Exploits", "Ragebot", "Visuals", "Misc" }
    K.WGROUPS = { "auto", "scout", "awp", "deagle", "revolver", "pistols", "other" }
    K.HITGROUPS = { [0] = "generic", [1] = "head", [2] = "chest", [3] = "stomach", [4] = "left arm",
        [5] = "right arm", [6] = "left leg", [7] = "right leg", [8] = "neck", [10] = "gear" }
    K.GRENADES = { hegrenade = true, flashbang = true, smokegrenade = true, molotov = true, incgrenade = true,
        decoy = true, c4 = true, tagrenade = true, healthshot = true }
    K.NON_BULLET = { inferno = true, molotov = true, incgrenade = true, hegrenade = true, decoy = true,
        flashbang = true, smokegrenade = true }
    -- Anti-brute fazlari 1-8 (faz 0 = yok). GS BRUTE_PHASES.
    K.BRUTE_PHASES = {
        { invert = true, scale = 1.0, shift = 0 },
        { invert = false, scale = 1.0, shift = 15 },
        { invert = true, scale = 0.85, shift = -15 },
        { invert = false, scale = 1.0, shift = 0, random = true },
        { invert = false, scale = 1.0, shift = 0, freestand = true },
        { invert = false, scale = 0.55, shift = 0 },
        { invert = true, scale = 0.7, shift = 10 },
        { invert = false, scale = 1.0, shift = 0, asym = 2 },
    }
    K.BRUTE_GROUPS = { "still", "move", "peek", "air" }
    K.GROUP_OF = { Moving = "move", ["Slow walk"] = "move", ["Crouch move"] = "move", Peek = "peek",
        Air = "air", ["Air crouch"] = "air" }
    -- Faz uygulanmayan / ogrenilmeyen durumlar (kendi AA'si olanlar).
    K.UNLEARNED = { ["Safe head"] = true, Manual = true, ["Fake duck"] = true, Ladder = true, Legit = true,
        Spin = true }
    K.LANDING_TICKS = 3
    K.MOVE_ENTER, K.MOVE_LEAVE = 10, 5
    K.DUCK_ENTER, K.DUCK_LEAVE = 0.7, 0.5
    K.PEEK_HOLD = 8
    K.EXPOSE_EVERY = 2
    K.SIGHT_RECENT = 32
    K.SIGHT_GAP = 24
    K.NEAR = 1800
    K.LOOKAHEAD = 0.2
    K.BRUTE_RADIUS = 40
    K.BRUTE_DEBOUNCE = 0.1
    K.MISS_WINDOW = 0.15
    K.SHOT_MEMORY = 5
    K.AIM_TARGET_HOLD = 1.5
    K.FORCE_STALL = 0.5
    K.MEMORY_LIMIT = 64
    K.FPS_CVARS = { "r_3dsky", "r_shadows", "cl_csm_shadows", "cl_csm_rope_shadows", "cl_csm_sprite_shadows",
        "cl_csm_static_prop_shadows", "cl_csm_viewmodel_shadows", "cl_csm_world_shadows",
        "cl_foot_contact_shadows", "mat_postprocess_enable", "func_break_max_pieces", "muzzleflash_light",
        "r_dynamic" }
    K.ASPECTS = { 1.3333, false, 1.25, 1.6 }
end

-------------------------------------------------------------------------------
-- Yardimcilar (vektor islemleri elle: vec3_t * sayi kullanilmaz)
-------------------------------------------------------------------------------
do
    local U = N.util
    local deg, rad, cos, sin = math.deg, math.rad, math.cos, math.sin
    local atan2 = math.atan2 or math.atan

    U.finite = function(x)
        return type(x) == "number" and x == x and x > -huge and x < huge
    end

    U.R = function(x)
        if not U.finite(x) then
            return 0
        end
        return floor(x + 0.5)
    end

    U.clamp = function(x, a, b)
        if x < a then
            return a
        end
        if x > b then
            return b
        end
        return x
    end

    U.norm = function(y)
        if not U.finite(y) then
            return 0
        end
        y = (y + 180) % 360 - 180
        if y == -180 then
            y = 180
        end
        return y
    end

    U.call = function(fn, ...)
        if type(fn) ~= "function" then
            return nil
        end
        local ok, a, b, c, d = pcall(fn, ...)
        if ok then
            return a, b, c, d
        end
        return nil
    end

    U.now = function()
        local ok, t = pcall(global_vars.real_time)
        return (ok and U.finite(t)) and t or 0
    end

    U.tick = function()
        local ok, t = pcall(global_vars.tick_count)
        return (ok and U.finite(t)) and t or 0
    end

    U.cur = function()
        local ok, t = pcall(global_vars.cur_time)
        return (ok and U.finite(t)) and t or 0
    end

    U.ipt = function()
        local ok, t = pcall(global_vars.interval_per_tick)
        return (ok and U.finite(t) and t > 0) and t or (1 / 64)
    end

    U.vec = function(x, y, z)
        return vec3_t(x, y, z)
    end

    U.okvec = function(v)
        local t = type(v)
        if t ~= "table" and t ~= "userdata" then
            return false
        end
        local ok, x, y, z = pcall(function()
            return v.x, v.y, v.z
        end)
        return ok and U.finite(x) and U.finite(y) and U.finite(z)
    end

    U.copy = function(v)
        return vec3_t(v.x, v.y, v.z)
    end

    U.add = function(v, x, y, z)
        return vec3_t(v.x + x, v.y + y, v.z + z)
    end

    U.dist = function(a, b)
        local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
        return sqrt(dx * dx + dy * dy + dz * dz)
    end

    U.dist2d = function(a, b)
        local dx, dy = a.x - b.x, a.y - b.y
        return sqrt(dx * dx + dy * dy)
    end

    U.yaw_to = function(a, b)
        return deg(atan2(b.y - a.y, b.x - a.x))
    end

    U.dir = function(yaw)
        local r = rad(yaw)
        return cos(r), sin(r)
    end

    -- p'yi yaw yonunde dist kadar (ve z'de dz) kaydir.
    U.offset = function(p, yaw, dist, dz)
        local cx, sy = U.dir(yaw)
        return vec3_t(p.x + cx * dist, p.y + sy * dist, p.z + (dz or 0))
    end

    -- p noktasinin a -> b dogru parcasina en kisa uzakligi.
    U.seg_dist = function(p, a, b)
        local abx, aby, abz = b.x - a.x, b.y - a.y, b.z - a.z
        local len_sq = abx * abx + aby * aby + abz * abz
        if len_sq <= 0 then
            return U.dist(p, a)
        end
        local t = ((p.x - a.x) * abx + (p.y - a.y) * aby + (p.z - a.z) * abz) / len_sq
        t = max(0, min(1, t))
        local dx, dy, dz = a.x + abx * t - p.x, a.y + aby * t - p.y, a.z + abz * t - p.z
        return sqrt(dx * dx + dy * dy + dz * dz)
    end

    U.prop = function(ent, name, i)
        if ent == nil then
            return nil
        end
        local ok, v
        if i ~= nil then
            ok, v = pcall(ent.get_prop, ent, name, i)
        else
            ok, v = pcall(ent.get_prop, ent, name)
        end
        if ok then
            return v
        end
        return nil
    end

    U.num = function(ent, name)
        local v = U.prop(ent, name)
        if U.finite(v) then
            return v
        end
        return nil
    end

    U.eye = function(ent)
        if ent == nil then
            return nil
        end
        local ok, v = pcall(ent.get_eye_position, ent)
        if ok and U.okvec(v) then
            return v
        end
        return nil
    end

    -- name: "HEAD", "PELVIS" ya da "CHEST" (e_hitboxes'ta STOMACH yok).
    U.hitbox = function(ent, name)
        if ent == nil then
            return nil
        end
        local id = e_hitboxes[name]
        local ok, v = pcall(ent.get_hitbox_pos, ent, id)
        if ok and U.okvec(v) then
            return v
        end
        return nil
    end

    U.origin = function(ent)
        local v = U.prop(ent, "m_vecOrigin")
        if U.okvec(v) then
            return v
        end
        local e = U.eye(ent)
        if e ~= nil then
            return vec3_t(e.x, e.y, e.z - 64)
        end
        return nil
    end

    U.vel = function(ent)
        local v = U.prop(ent, "m_vecVelocity")
        if U.okvec(v) then
            return v
        end
        return { x = 0, y = 0, z = 0 }
    end

    U.speed = function(ent)
        local v = U.vel(ent)
        return sqrt(v.x * v.x + v.y * v.y)
    end

    U.alive = function(ent)
        if ent == nil then
            return false
        end
        local ok, v = pcall(ent.is_alive, ent)
        return ok and v == true
    end

    U.dormant = function(ent)
        local ok, v = pcall(ent.is_dormant, ent)
        return ok and v == true
    end

    U.is_enemy = function(ent)
        local ok, v = pcall(ent.is_enemy, ent)
        return ok and v == true
    end

    U.index = function(ent)
        if ent == nil then
            return nil
        end
        local ok, v = pcall(ent.get_index, ent)
        if ok and U.finite(v) then
            return v
        end
        return nil
    end

    U.name = function(ent)
        if ent == nil then
            return "?"
        end
        local ok, v = pcall(ent.get_name, ent)
        if ok and v ~= nil then
            return (tostring(v):gsub("[\t\r\n]", " "))
        end
        return "?"
    end

    U.flag = function(ent, flag)
        if ent == nil then
            return nil
        end
        local ok, v = pcall(ent.has_player_flag, ent, e_player_flags[flag])
        if ok and type(v) == "boolean" then
            return v
        end
        return nil
    end

    U.hp = function(ent)
        local v = U.num(ent, "m_iHealth")
        return v or 100
    end

    -- Aktif silah: { name = "ssg08", class = "CWeaponSSG08" }. Tick basina oyuncu basina onbellek.
    U.wcache = { tick = -1, list = {} }
    U.winfo = function(ent)
        if ent == nil then
            return nil
        end
        local idx = U.index(ent) or 0
        local t = U.tick()
        local c = U.wcache
        if c.tick ~= t then
            c.tick, c.list = t, {}
        end
        local cached = c.list[idx]
        if cached ~= nil then
            return cached or nil
        end
        local info = false
        local ok, w = pcall(ent.get_active_weapon, ent)
        if ok and w ~= nil then
            local okn, name = pcall(w.get_name, w)
            local okc, class = pcall(w.get_class_name, w)
            name = (okn and type(name) == "string") and name:lower() or nil
            if name == nil then
                local okd, data = pcall(w.get_weapon_data, w)
                local cn = okd and data ~= nil and U.call(function()
                    return data.console_name
                end) or nil
                if type(cn) == "string" then
                    name = cn:lower():gsub("^weapon_", "")
                end
            end
            info = { ent = w, name = name or "?", class = (okc and type(class) == "string") and class or "" }
        end
        c.list[idx] = info
        return info or nil
    end

    -- "knife", "zeus" ya da nil. GS'de get_name "bayonet" de donebiliyor; sinif CKnife.
    U.melee = function(info)
        if info == nil then
            return nil
        end
        local n, c = info.name or "", info.class or ""
        if c == "CKnife" or c == "CKnifeGG" or n == "knife" or n == "bayonet" or n:find("knife", 1, true) then
            return "knife"
        end
        if n == "taser" or c == "CWeaponTaser" then
            return "zeus"
        end
        return nil
    end

    U.is_sniper = function(name)
        return name == "ssg08" or name == "awp"
    end

    U.is_bolt = function(name)
        return name == "ssg08" or name == "awp" or name == "revolver"
    end

    U.is_gun = function(info)
        if info == nil then
            return false
        end
        if U.melee(info) == "knife" or N.K.GRENADES[info.name] then
            return false
        end
        return info.name ~= "?"
    end

    U.wlabel = function(name)
        if name == nil or name == "?" then
            return "sen ?"
        end
        if name == "revolver" then
            return "sen r8"
        end
        return "sen " .. name
    end

    -- Hasar izi: trace.bullet(from, to, skip, target).damage; gecersizse 0.
    U.tdmg = function(from, to, skip, target)
        if from == nil or to == nil then
            return 0
        end
        local ok, r
        if target ~= nil then
            ok, r = pcall(trace.bullet, from, to, skip, target)
        else
            ok, r = pcall(trace.bullet, from, to, skip)
        end
        if not ok or r == nil then
            return 0
        end
        local okv, valid, dmg = pcall(function()
            return r.valid, r.damage
        end)
        if not okv or valid == false or not U.finite(dmg) then
            return 0
        end
        return max(0, dmg)
    end

    -- Duz iz: fraction (0..1) ve entity (ya da nil).
    U.tline = function(from, to, skip)
        if from == nil or to == nil then
            return 1, nil
        end
        local ok, r
        if skip ~= nil then
            ok, r = pcall(trace.line, from, to, skip)
        else
            ok, r = pcall(trace.line, from, to)
        end
        if not ok or r == nil then
            return 1, nil
        end
        local okv, f, e = pcall(function()
            return r.fraction, r.entity
        end)
        if not okv or not U.finite(f) then
            return 1, nil
        end
        return f, e
    end

    -- Sayi metni: tam sayiysa %d, degilse bir ondalik.
    U.numtext = function(v)
        if type(v) == "boolean" then
            return v and "acik" or "kapali"
        end
        if not U.finite(v) then
            return tostring(v)
        end
        if abs(v - floor(v + 0.5)) < 1e-6 then
            return fmt("%d", U.R(v))
        end
        return fmt("%.1f", v)
    end

    U.game = function(name)
        local ok, v = pcall(game_rules.get_prop, name)
        if ok and U.finite(v) then
            return v
        end
        return nil
    end

    U.in_game = function()
        local ok, v = pcall(engine.is_in_game)
        return ok and v == true
    end
end

-------------------------------------------------------------------------------
-- Korunan cagrilar: her callback / dugme pcall icinde; hata ilk 3 kez yazilir, 50 hatada kapatilir.
-------------------------------------------------------------------------------
do
    local C = N.cb
    C.handlers, C.added = {}, {}

    C.run = function(h, ...)
        if h.dead then
            return
        end
        local ok, err = pcall(h.fn, ...)
        if not ok then
            h.errors = h.errors + 1
            if h.errors <= 3 then
                N.log.line(fmt("%s hata verdi: %s", h.name, tostring(err)))
            end
            if h.errors == 50 then
                h.dead = true
                N.log.line(h.name .. " 50 hata, kapatildi")
            end
        end
    end

    -- Dugmeler ve gecikmeli cagrilar icin tek korunan fonksiyon.
    C.wrap = function(name, fn)
        local h = { name = name, fn = fn, errors = 0, dead = false }
        return function(...)
            C.run(h, ...)
        end
    end
end

-------------------------------------------------------------------------------
-- Log: halka tampon (12 000 satir), konsol (client.log), dosya (nykle_log.txt, toplu yazma)
-------------------------------------------------------------------------------
do
    local U, L = N.util, N.log
    L.lines, L.cap, L.trim = {}, 12000, 1000
    L.pending, L.file = {}, "nykle_log.txt"
    L.bytes, L.cap_bytes, L.capped = 0, 2 * 1024 * 1024, false
    L.saved_at, L.dumped_at = -1000, -1000
    L.load_entry, L.notes = nil, {}
    L.marker = "] V" .. N.VERSION .. " (" .. N.EDITION .. " edition) yuklendi"

    L.stamp = function()
        local ok, h, m, s = pcall(client.get_local_time)
        if ok and U.finite(h) and U.finite(m) and U.finite(s) then
            return fmt("%02d:%02d:%02d", U.R(h), U.R(m), U.R(s))
        end
        return fmt("%.1f", U.now())
    end

    L.console = function(line)
        if pcall(client.log, color_t(210, 210, 210), line) then
            return
        end
        pcall(print, line)
    end

    L.push = function(line)
        local entry = L.stamp() .. " " .. line
        local lines = L.lines
        lines[#lines + 1] = entry
        if #lines > L.cap + L.trim then
            local keep = {}
            for i = #lines - L.cap + 1, #lines do
                keep[#keep + 1] = lines[i]
            end
            L.lines = keep
        end
        if N.fs.ok and not L.capped then
            L.pending[#L.pending + 1] = entry
        end
        return entry
    end

    -- Tek giris noktasi: "[Nykle.win] " oneki, halka + dosya kuyrugu + konsol.
    L.line = function(text)
        local line = "[" .. N.SCRIPT .. "] " .. tostring(text)
        local entry = L.push(line)
        L.console(line)
        return entry
    end

    -- Bir log anahtari icin en fazla "every" saniyede bir satir.
    L.limits = {}
    L.every = function(key, every, text)
        local now = U.now()
        local last = L.limits[key]
        if last ~= nil and now >= last and now - last < every then
            return false
        end
        L.limits[key] = now
        L.line(text)
        return true
    end

    L.flush = function()
        if #L.pending == 0 then
            return true
        end
        local F = N.fs
        if not F.ok or L.capped then
            L.pending = {}
            return false
        end
        local text = concat(L.pending, "\n") .. "\n"
        L.pending = {}
        if L.bytes + #text > L.cap_bytes then
            L.capped = true
            L.line("log dosyasi bu oturumda 2 MB'yi gecti, sadece hafizada")
            L.pending = {}
            return false
        end
        if F.put(L.file, text, "a") then
            L.bytes = L.bytes + #text
            return true
        end
        return false
    end

    -- PAINT'ten: hayattayken 300 sn'de, olu / donma / oyun disi 60 sn'de bir dosyaya.
    L.timer = function()
        local now = U.now()
        local st = N.st
        local frozen = U.game("m_bFreezePeriod") == 1
        local every = (st.alive and not frozen and U.in_game()) and 300 or 60
        if now < L.saved_at or now - L.saved_at >= every then
            L.saved_at = now
            L.flush()
        end
    end

    -- Yuklemede: yeni surum = yeni dosya; 2 MB ustu son 1 MB'ye kirpilir; 4 MB ustu sifirlanir.
    L.open = function()
        local F = N.fs
        if not F.ok then
            return
        end
        local size = F.size(L.file)
        if size == nil then
            return
        end
        if size > 4 * 1024 * 1024 then
            F.put(L.file, "", "w")
            L.notes[#L.notes + 1] = "onceki log 4 MB'yi gecmisti, sifirlandi"
            return
        end
        local text = F.read(L.file)
        if text == nil or text == "" then
            return
        end
        if not text:find(L.marker, 1, true) then
            F.put(L.file, "", "w")
            L.notes[#L.notes + 1] = "log dosyasi yeni surum icin sifirlandi"
            return
        end
        if #text > 2 * 1024 * 1024 then
            local tail = text:sub(#text - 1024 * 1024 + 1)
            tail = tail:gsub("^[^\n]*\n", "", 1)
            F.put(L.file, tail, "w")
            L.notes[#L.notes + 1] = "log dosyasi 2 MB'yi gecmisti, son 1 MB tutuldu"
        end
    end

    L.dump = function()
        local now = U.now()
        if now >= L.dumped_at and now - L.dumped_at < 10 then
            L.console(fmt("[%s] loglar %d sn once konsola yazildi (yukari kaydir); tekrar yazmak icin 10 sn bekle",
                N.SCRIPT, U.R(now - L.dumped_at)))
            return false
        end
        L.dumped_at = now
        L.console(fmt("[%s] ===== tum loglar: %d satir (bu oturum) =====", N.SCRIPT, #L.lines))
        for _, line in ipairs(L.lines) do
            L.console(line)
        end
        L.console(fmt("[%s] ===== loglarin sonu =====", N.SCRIPT))
        return true
    end

    -- Pano: VGUI_System010 sanal tablo 9 (SetClipboardText), memory.get_vfunc ile.
    L.clipboard = function(text)
        local ok, res = pcall(function()
            local f = N.fs.ffi
            if f == nil then
                return "ffi yok"
            end
            local mem = memory
            if mem == nil or mem.create_interface == nil or mem.get_vfunc == nil then
                return "memory yok"
            end
            local iface = mem.create_interface("vgui2.dll", "VGUI_System010")
            if iface == nil then
                return "VGUI_System010 bulunamadi"
            end
            local fnp = mem.get_vfunc(iface, 9)
            if fnp == nil then
                return "vfunc 9 yok"
            end
            local set_text = f.cast("void(__thiscall*)(void*, const char*, int)", fnp)
            set_text(f.cast("void***", iface), text, #text)
            return true
        end)
        if ok and res == true then
            return true
        end
        return false, tostring(res)
    end

    L.copy = function()
        L.flush()
        local ok, why = L.clipboard(concat(L.lines, "\n"))
        if ok then
            L.line(fmt("loglar panoya kopyalandi (%d satir)", #L.lines))
            return true
        end
        L.line(fmt("panoya kopyalanamadi (%s): loglar asagida konsolda", tostring(why)))
        L.dumped_at = -1000
        L.dump()
        return false
    end

    L.clear = function()
        L.lines, L.pending = {}, {}
        if N.fs.ok then
            N.fs.put(L.file, (L.load_entry or L.stamp() .. " [" .. N.SCRIPT .. "] V" .. N.VERSION .. " ("
                .. N.EDITION .. " edition) yuklendi") .. "\n", "w")
        end
        if L.load_entry ~= nil then
            L.lines[1] = L.load_entry
        end
        L.line("kayitli loglar temizlendi")
    end
end

-------------------------------------------------------------------------------
-- Dosya sistemi: ffi + VBaseFileSystem011 (include/File System.lua deseni), yol kimligi "MOD"
-------------------------------------------------------------------------------
do
    local U, F = N.util, N.fs
    F.ok, F.why, F.fails = false, "baslatilmadi", 0
    F.MAX_READ = 4 * 1024 * 1024

    F.init = function()
        local ok, err = pcall(function()
            local f = ffi
            if f == nil then
                local okr, r = pcall(require, "ffi")
                if okr then
                    f = r
                end
            end
            if f == nil then
                error("ffi yok", 0)
            end
            F.ffi = f
            local mem = memory
            if mem == nil or mem.create_interface == nil then
                error("memory yok", 0)
            end
            local iface = mem.create_interface("filesystem_stdio.dll", "VBaseFileSystem011")
            if iface == nil then
                error("VBaseFileSystem011 bulunamadi", 0)
            end
            local cls = f.cast("void***", iface)
            local vt = cls[0]
            F.cls = cls
            F.c_read = f.cast("int (__thiscall*)(void*, void*, int, void*)", vt[0])
            F.c_write = f.cast("int (__thiscall*)(void*, void const*, int, void*)", vt[1])
            F.c_open = f.cast("void* (__thiscall*)(void*, const char*, const char*, const char*)", vt[2])
            F.c_close = f.cast("void (__thiscall*)(void*, void*)", vt[3])
            F.c_size = f.cast("unsigned int (__thiscall*)(void*, void*)", vt[7])
            F.c_exists = f.cast("bool (__thiscall*)(void*, const char*, const char*)", vt[10])
        end)
        F.ok = ok
        if not ok then
            F.why = tostring(err)
        else
            F.why = nil
        end
        return ok
    end

    F.fail = function(reason)
        F.fails = F.fails + 1
        if F.fails >= 3 and F.ok then
            F.ok, F.why = false, tostring(reason)
            N.log.line(fmt("log dosyasi yazilamadi: %s (loglar hafizada; Console > Print all logs)", F.why))
        end
    end

    -- mode "a" (ekle) ya da "w" (bastan yaz).
    F.put = function(name, text, mode)
        if not F.ok then
            return false
        end
        local ok, res = pcall(function()
            local h = F.c_open(F.cls, name, mode, "MOD")
            if h == nil then
                return "dosya acilamadi"
            end
            if #text > 0 then
                F.c_write(F.cls, text, #text, h)
            end
            F.c_close(F.cls, h)
            return true
        end)
        if ok and res == true then
            F.fails = 0
            return true
        end
        F.fail(ok and res or ("hata: " .. tostring(res)))
        return false
    end

    F.exists = function(name)
        if not F.ok then
            return false
        end
        local ok, v = pcall(F.c_exists, F.cls, name, "MOD")
        return ok and v == true
    end

    -- Boyut (bayt) ya da nil (dosya yok / okunamadi).
    F.size = function(name)
        if not F.exists(name) then
            return nil
        end
        local ok, n = pcall(function()
            local h = F.c_open(F.cls, name, "r", "MOD")
            if h == nil then
                return nil
            end
            local s = F.c_size(F.cls, h)
            F.c_close(F.cls, h)
            return tonumber(s)
        end)
        if ok then
            return n
        end
        return nil
    end

    -- Metin ya da nil. 4 MB ustu okunmaz.
    F.read = function(name)
        if not F.exists(name) then
            return nil
        end
        local ok, text = pcall(function()
            local h = F.c_open(F.cls, name, "r", "MOD")
            if h == nil then
                return nil
            end
            local n = tonumber(F.c_size(F.cls, h)) or 0
            if n <= 0 or n > F.MAX_READ then
                F.c_close(F.cls, h)
                return nil
            end
            local buf = F.ffi.new("char[?]", n + 1)
            F.c_read(F.cls, buf, n, h)
            F.c_close(F.cls, h)
            return F.ffi.string(buf, n)
        end)
        if ok and type(text) == "string" then
            return text
        end
        return nil
    end
end

-------------------------------------------------------------------------------
-- Native menu referanslari (yuklemede bulunur, eksikse 10 sn'de bir yeniden denenir)
-------------------------------------------------------------------------------
do
    local U, P = N.util, N.ref
    P.items, P.missing, P.noted = {}, {}, {}
    P.retry_at = 0

    -- { anahtar, tus mu ([2]), yollar (YENI once, ESKI yedek) }
    P.defs = {
        { "dt", true, { { "aimbot", "general", "exploits", "doubletap", "enable" } } },
        { "hs", true, { { "aimbot", "general", "exploits", "hideshots", "enable" } } },
        { "fakeping", true, { { "aimbot", "general", "fake ping", "enable" } } },
        { "autopeek", true, { { "aimbot", "general", "misc", "autopeek" },
            { "aimbot", "general", "misc", "autopeek", "enable" } } },
        { "fakeduck", true, { { "antiaim", "main", "general", "fakeduck" },
            { "antiaim", "main", "general", "fake duck" } } },
        { "slowwalk", true, { { "misc", "main", "movement", "slow walk" },
            { "misc", "main", "movement", "slow walk", "enable" } } },
        { "fs", true, { { "antiaim", "main", "auto direction", "enable" } } },
        { "fs_states", false, { { "antiaim", "main", "auto direction", "states" } } },
        { "inverter", true, { { "antiaim", "main", "manual", "invert desync" } } },
        { "ext_angles", true, { { "antiaim", "main", "extended angles", "enable" } } },
        { "jitter_mode", false, { { "antiaim", "main", "angles", "jitter mode" } } },
        { "rotate", false, { { "antiaim", "main", "angles", "rotate" } } },
        { "body_lean", false, { { "antiaim", "main", "angles", "body lean" } } },
        { "moving_body_lean", false, { { "antiaim", "main", "angles", "moving body lean" } } },
        { "yaw_add", false, { { "antiaim", "main", "angles", "yaw add" } } },
        { "ext_moving", false, { { "antiaim", "main", "extended angles", "enable while moving" } } },
        { "override_move", false, { { "antiaim", "main", "desync", "override stand#move" } } },
        { "override_slow", false, { { "antiaim", "main", "desync", "override stand#slow walk" } } },
        { "anti_brute_native", false, { { "antiaim", "main", "desync", "anti bruteforce" } } },
        { "on_shot", false, { { "antiaim", "main", "desync", "on shot" } } },
        { "side_stand", false, { { "antiaim", "main", "desync", "side#stand" } } },
        { "left_amount_stand", false, { { "antiaim", "main", "desync", "left amount#stand" } } },
        { "right_amount_stand", false, { { "antiaim", "main", "desync", "right amount#stand" } } },
        { "fl_amount", false, { { "antiaim", "main", "fakelag", "amount" } } },
        { "fl_blc", false, { { "antiaim", "main", "fakelag", "break lag compensation" } } },
        { "buybot", false, { { "misc", "utility", "buybot", "enable" } } },
        { "buybot_nades", false, { { "misc", "utility", "buybot", "grenades" } } },
        { "autostrafer", false, { { "misc", "main", "movement", "autostrafer" } } },
    }
    for _, w in ipairs(N.K.WGROUPS) do
        local old = (w == "deagle" or w == "revolver") and "heavy pistols" or w
        P.defs[#P.defs + 1] = { "md:" .. w, false, { { "aimbot", w, "targeting", "min. damage" },
            { "aimbot", old, "targeting", "min. damage" } } }
        P.defs[#P.defs + 1] = { "mdo:" .. w, "pair", { { "aimbot", w, "target overrides", "min. damage" },
            { "aimbot", old, "target overrides", "force min. damage" } } }
        P.defs[#P.defs + 1] = { "hc:" .. w, false, { { "aimbot", w, "targeting", "hitchance" },
            { "aimbot", old, "targeting", "hitchance" } } }
    end
    P.defs[#P.defs + 1] = { "qs:scout", false, { { "aimbot", "scout", "accuracy", "options" } } }
    P.defs[#P.defs + 1] = { "qs:awp", false, { { "aimbot", "awp", "accuracy", "options" } } }

    P.find = function(path)
        local ok, r
        if #path == 5 then
            ok, r = pcall(menu.find, path[1], path[2], path[3], path[4], path[5])
        else
            ok, r = pcall(menu.find, path[1], path[2], path[3], path[4])
        end
        if not ok then
            return nil
        end
        local t = type(r)
        if t ~= "table" and t ~= "userdata" then
            return nil
        end
        return r
    end

    P.sub = function(r, i)
        local ok, v = pcall(function()
            return r[i]
        end)
        if ok and type(v) ~= "nil" then
            return v
        end
        return nil
    end

    -- :get() ilk denemede hata veren yer tutucu yok sayilir.
    P.probe = function(obj, name)
        if obj == nil then
            return false
        end
        local ok
        if name ~= nil then
            ok = pcall(obj.get, obj, name)
        else
            ok = pcall(obj.get, obj)
        end
        return ok
    end

    P.note = function(key, path)
        if P.noted[key] then
            return
        end
        P.noted[key] = true
        N.log.line("menude bulunamadi: " .. concat(path or { key }, " > "))
    end

    P.resolve_one = function(def)
        local key, kind, paths = def[1], def[2], def[3]
        for _, path in ipairs(paths) do
            local r = P.find(path)
            if r ~= nil then
                if kind == "pair" then
                    local slider, keyobj = P.sub(r, 1), P.sub(r, 2)
                    if P.probe(slider) and P.probe(keyobj) then
                        local w = key:sub(5)
                        P.items["mdo:" .. w], P.items["mdk:" .. w] = slider, keyobj
                        P.missing[key] = nil
                        return true
                    end
                elseif kind == true then
                    local k = P.sub(r, 2)
                    if P.probe(k) then
                        P.items[key], P.missing[key] = k, nil
                        return true
                    end
                else
                    if key == "fs_states" or key == "qs:scout" or key == "qs:awp" or key == "buybot_nades" then
                        P.items[key], P.missing[key] = r, nil
                        return true
                    end
                    if P.probe(r) then
                        P.items[key], P.missing[key] = r, nil
                        return true
                    end
                end
            end
        end
        P.missing[key] = true
        P.note(key, paths[1])
        return false
    end

    P.resolve = function()
        for _, def in ipairs(P.defs) do
            local key = def[1]
            local have
            if def[2] == "pair" then
                -- Cift: slider ve tus ikisi de olmali (biri hata verip silindiyse ikisi yeniden aranir).
                have = P.items["mdo:" .. key:sub(5)] ~= nil and P.items["mdk:" .. key:sub(5)] ~= nil
            else
                have = P.items[key] ~= nil
            end
            if not have then
                P.resolve_one(def)
            end
        end
        P.retry_at = U.now() + 10
    end

    -- PAINT: eksik varsa 10 sn'de bir sessizce yeniden dene.
    P.retry = function()
        local now = U.now()
        if now < P.retry_at and now >= P.retry_at - 20 then
            return
        end
        if next(P.missing) ~= nil then
            P.resolve()
        else
            P.retry_at = now + 10
        end
    end

    P.get = function(key)
        local obj = P.items[key]
        if obj == nil then
            return nil
        end
        local ok, v = pcall(obj.get, obj)
        if not ok then
            P.items[key] = nil
            -- mdk: / mdo: P.defs'te "mdo:<grup>" cifti olarak durur; P.retry onu yeniden cozer.
            local pre = key:sub(1, 4)
            local def_key = (pre == "mdk:" or pre == "mdo:") and ("mdo:" .. key:sub(5)) or key
            P.missing[def_key] = true
            P.note(key)
            return nil
        end
        return v
    end

    P.on = function(key)
        return P.get(key) == true
    end

    P.wgroup = function()
        local ok, v = pcall(ragebot.get_active_cfg)
        if ok and U.finite(v) then
            return N.K.WGROUPS[floor(v) + 1] or "other"
        end
        return "other"
    end

    -- Etkin Min. damage: override tusu basiliyken override degeri, yoksa normal deger. (deger, override_mi)
    P.md_eff = function(w)
        w = w or N.st.wgroup
        if P.on("mdk:" .. w) then
            local v = P.get("mdo:" .. w)
            if U.finite(v) then
                return v, true
            end
        end
        local v = P.get("md:" .. w)
        if U.finite(v) then
            return v, false
        end
        return nil, false
    end

    P.need = function(hp, md)
        if md >= 100 then
            return hp + (md - 100)
        end
        return md
    end

    -- Bu hedeften native ayarin gercekten istedigi hasar (100 = can).
    P.md_need = function(hp, w)
        local md = P.md_eff(w)
        if md == nil or not U.finite(hp) then
            return nil
        end
        return P.need(hp, md)
    end

    P.charge = function()
        local c = U.call(exploits.get_charge)
        local m = U.call(exploits.get_max_charge)
        return U.finite(c) and c or 0, U.finite(m) and m or 0
    end

    P.dt_ready = function()
        if not P.on("dt") then
            return false
        end
        local c, m = P.charge()
        return m > 0 and c >= m
    end

    P.fd_on = function()
        local v = U.call(antiaim.is_fakeducking)
        return v == true or P.on("fakeduck")
    end

    P.multi = function(key, item)
        local obj = P.items[key]
        if obj == nil then
            return nil
        end
        local ok, v = pcall(obj.get, obj, item)
        if ok and type(v) == "boolean" then
            return v
        end
        return nil
    end
end

-------------------------------------------------------------------------------
-- Menu (gruplar ve oge adlari config anahtari: DONDURULMUS, bkz. SPEC §2)
-------------------------------------------------------------------------------
do
    local U, UI = N.util, N.ui
    local K = N.K
    UI.e, UI.def, UI.b, UI.bdef, UI.x, UI.xdef = {}, {}, {}, {}, {}, {}
    UI.tracked, UI.vis, UI.failed = {}, {}, 0
    UI.G = {
        home = "Nykle.win | Home", console = "Nykle.win | Console", aa = "Nykle.win | Anti-Aim",
        protect = "Nykle.win | Protection", builder = "Nykle.win | Builder",
        bexploit = "Nykle.win | Builder exploit", exploits = "Nykle.win | Exploits", peek = "Nykle.win | Peek",
        rage = "Nykle.win | Ragebot", visuals = "Nykle.win | Visuals", misc = "Nykle.win | Misc",
    }
    UI.GROUP_ORDER = {
        { "home", 1, 0 }, { "console", 2, 1 }, { "aa", 1, 2 }, { "protect", 2, 2 }, { "builder", 1, 3 },
        { "bexploit", 2, 3 }, { "exploits", 1, 4 }, { "peek", 2, 4 }, { "rage", 1, 5 }, { "visuals", 1, 6 },
        { "misc", 1, 7 },
    }

    UI.val = function(el, def)
        if el == nil then
            return def
        end
        local ok, v = pcall(el.get, el)
        if ok and v ~= nil then
            return v
        end
        return def
    end

    UI.make = function(kind, group, name, a, b, c, d, e)
        local ok, el
        if kind == "cb" then
            ok, el = pcall(menu.add_checkbox, group, name, a)
        elseif kind == "sl" then
            ok, el = pcall(menu.add_slider, group, name, a, b, c, d, e)
        elseif kind == "sel" then
            ok, el = pcall(menu.add_selection, group, name, a)
        elseif kind == "txt" then
            ok, el = pcall(menu.add_text, group, name)
        elseif kind == "btn" then
            ok, el = pcall(menu.add_button, group, name, a)
        end
        if not ok or el == nil then
            UI.failed = UI.failed + 1
            return nil
        end
        return el
    end

    UI.track = function(el, def, label, items)
        if el ~= nil then
            UI.tracked[#UI.tracked + 1] = { el = el, def = def, label = label, items = items }
        end
    end

    UI.set = function(el, v)
        if el ~= nil then
            pcall(el.set, el, v)
        end
    end

    -- Genel ogeler: anahtar, grup, ad, tur, varsayilan, (slider: min, max, adim, hassasiyet, birim; sel: liste),
    -- izlenen mi (R).
    UI.cb = function(key, g, name, def, tracked)
        local el = UI.make("cb", UI.G[g], name, def)
        UI.e[key], UI.def[key] = el, def
        if tracked then
            UI.track(el, def, name)
        end
        return el
    end

    UI.sl = function(key, g, name, lo, hi, def, tracked, suffix, step, prec)
        local el = UI.make("sl", UI.G[g], name, lo, hi, step or 1, prec or 0, suffix or "")
        UI.set(el, def)
        UI.e[key], UI.def[key] = el, def
        if tracked then
            UI.track(el, def, name)
        end
        return el
    end

    UI.sel = function(key, g, name, items, def, tracked)
        local el = UI.make("sel", UI.G[g], name, items)
        UI.set(el, def)
        UI.e[key], UI.def[key] = el, def
        if tracked then
            UI.track(el, def, name, items)
        end
        return el
    end

    UI.txt = function(key, g, text)
        UI.e[key] = UI.make("txt", UI.G[g], text)
        return UI.e[key]
    end

    UI.btn = function(key, g, name, fn)
        UI.e[key] = UI.make("btn", UI.G[g], name, N.cb.wrap("button: " .. name, fn))
        return UI.e[key]
    end

    UI.color = function(key, host, name, col)
        local el = UI.e[host]
        if el == nil then
            return nil
        end
        local ok, c = pcall(el.add_color_picker, el, name, col)
        if ok and c ~= nil then
            UI.e[key] = c
            return c
        end
        UI.failed = UI.failed + 1
        return nil
    end

    -- Kisa okuyucular.
    N.v = function(key)
        return UI.val(UI.e[key], UI.def[key])
    end
    N.on = function(key)
        return UI.val(UI.e[key], UI.def[key]) == true
    end
    -- Builder: durumun kendi satiri (Override kapaliysa Global).
    N.bv = function(state, key)
        local row = UI.b[state]
        local defs = UI.bdef[state]
        if row == nil or defs == nil then
            return nil
        end
        return UI.val(row[key], defs[key])
    end
    N.xv = function(state, key)
        local row = UI.x[state]
        local defs = UI.xdef[state]
        if row == nil or defs == nil then
            return nil
        end
        return UI.val(row[key], defs[key])
    end

    local function index_of(list, name)
        for i, v in ipairs(list) do
            if v == name then
                return i
            end
        end
        return 1
    end
    UI.index_of = index_of

    UI.build_builder = function()
        local g = UI.G.builder
        UI.e.state = UI.make("sel", g, "State", K.STATES)
        UI.set(UI.e.state, 1)
        UI.def.state = 1
        for _, s in ipairs(K.STATES) do
            local row, defs = {}, {}
            UI.b[s], UI.bdef[s] = row, defs
            local d = K.DEFAULTS[s]
            local function add(key, kind, name, def, a, b, c, items)
                local label = "[" .. s .. "] " .. name
                local el
                if kind == "cb" then
                    el = UI.make("cb", g, label, def)
                elseif kind == "sl" then
                    el = UI.make("sl", g, label, a, b, 1, 0, c or "")
                    UI.set(el, def)
                else
                    el = UI.make("sel", g, label, items)
                    UI.set(el, def)
                end
                row[key], defs[key] = el, def
                UI.track(el, def, label, items)
            end
            local movement = K.MOVEMENT[s]
            local fd = s == "Fake duck"
            if K.OVERRIDABLE[s] then
                add("override", "cb", "Override", true)
            end
            add("yaw_mode", "sel", "Yaw mode", 1, nil, nil, nil, K.YAW_MODES)
            add("yaw_left", "sl", "Yaw left", d[1], -180, 180)
            add("yaw_right", "sl", "Yaw right", d[2], -180, 180)
            add("ways", "sl", "Ways", 3, 3, 5)
            for i = 1, 5 do
                add("way" .. i, "sl", "Way " .. i, K.WAY_DEFAULTS[i], -180, 180)
            end
            add("yaw_random", "sl", "Yaw randomize", fd and 20 or 0, 0, 30)
            add("modifier", "sel", "Yaw modifier", 1, nil, nil, nil, K.MODIFIERS)
            add("mod_random", "sl", "Modifier randomize", 0, 0, 60)
            add("mod_offset", "sl", "Modifier offset", 0, -180, 180)
            local body = movement and 1 or ((s == "Manual" or s == "Freestanding") and 2 or 3)
            add("body_yaw", "sel", "Body yaw", body, nil, nil, nil, K.BODY_YAWS)
            add("body_fs", "sel", "Body freestanding", fd and 2 or 1, nil, nil, nil, K.ON_OFF)
            add("delay_random", "sl", "Delay randomize", movement and 1 or 0, 0, 5, "t")
            add("limit_random", "sl", "Limit randomize", fd and 10 or 0, 0, 30)
            add("delay", "sl", "Jitter delay", d[3], 1, 10, "t")
            add("left_limit", "sl", "Left limit", d[4], 0, 60)
            add("right_limit", "sl", "Right limit", d[5], 0, 60)
        end
        local gx = UI.G.bexploit
        for _, s in ipairs(K.STATES) do
            if s == "Global" or s == "Fake duck" then
                UI.x[s] = { text = UI.make("txt", gx,
                    "[" .. s .. "] No exploit settings (Global shares AA only, fake duck has no DT)") }
                UI.xdef[s] = {}
            else
                local row, defs = {}, {}
                UI.x[s], UI.xdef[s] = row, defs
                local d = K.EXPLOIT_DEFAULTS[s]
                local function add(key, kind, name, def, a, b, items, suffix)
                    local label = "[" .. s .. "] " .. name
                    local el
                    if kind == "sl" then
                        el = UI.make("sl", gx, label, a, b, 1, 0, suffix or "")
                    else
                        el = UI.make("sel", gx, label, items)
                    end
                    UI.set(el, def)
                    row[key], defs[key] = el, def
                    UI.track(el, def, label, items)
                end
                add("def_mode", "sel", "Defensive", index_of(K.DEF_MODES, d[1]), nil, nil, K.DEF_MODES)
                add("def_ticks", "sl", "Defensive every", 14, 2, 22, nil, "t")
                add("hidden_pitch", "sel", "Hidden pitch", index_of(K.HIDDEN_PITCHES, d[2]), nil, nil,
                    K.HIDDEN_PITCHES)
                add("hidden_pitch_value", "sl", "Pitch value", 0, -89, 89)
                add("hidden_yaw", "sel", "Hidden yaw", index_of(K.HIDDEN_YAWS, d[3]), nil, nil, K.HIDDEN_YAWS)
                add("hidden_yaw_value", "sl", "Yaw value", 90, -180, 180)
            end
        end
    end

    UI.build = function()
        local B = UI
        -- Home
        B.cb("enabled", "home", "Enable Nykle.win", true, false)
        B.sel("tab", "home", "Tab", K.TABS, 1, false)
        B.cb("recommended", "home", "Always use recommended settings", true, false)
        B.txt("info1", "home", "No need to change any setting.")
        B.txt("info2", "home", "Bind: native manual / auto direction / autopeek")
        -- Console
        B.cb("resolver_log", "console", "Resolver log", true, false)
        B.cb("shot_log", "console", "Shot log", true, false)
        B.cb("hit_log", "console", "Hit log", true, false)
        B.cb("brute_log", "console", "Anti-brute log", false, false)
        B.cb("debug_log", "console", "Detailed log (for analysis)", true, false)
        B.cb("log_quiet", "console", "Logs only in console + file (not on screen)", true, false)
        B.btn("log_copy", "console", "Copy all logs", function()
            N.log.copy()
        end)
        B.btn("log_print", "console", "Print all logs to console", function()
            N.log.dump()
        end)
        B.btn("log_save", "console", "Save logs to file now", function()
            if N.log.flush() and N.fs.ok then
                N.log.line("loglar dosyaya yazildi: " .. N.log.file)
            else
                N.log.line("loglar dosyaya yazilamadi (" .. tostring(N.fs.why or "dosya yok") .. ")")
            end
        end)
        B.btn("log_clear", "console", "Clear saved logs", function()
            N.log.clear()
        end)
        B.btn("forget", "console", "Forget learned enemies", function()
            N.mem.forget()
        end)
        B.btn("stats_reset", "console", "Reset stats", function()
            N.stats.reset()
        end)
        -- Anti-Aim
        B.sel("pitch", "aa", "Pitch", { "Down", "Zero", "Off" }, 1, true)
        B.sel("yaw_base", "aa", "Yaw base", { "At target", "Local view" }, 1, true)
        B.cb("avoid_backstab", "aa", "Avoid backstab", true, true)
        B.cb("backstab_def", "aa", "Defensive while knife is close", true, true)
        B.cb("legit_use", "aa", "Legit AA on use", true, true)
        B.cb("spin", "aa", "Spin when idle", true, true)
        B.cb("spin_warmup", "aa", "Spin in warmup", false, true)
        B.cb("spin_enemies", "aa", "Spin: no enemies alive", true, true)
        B.sel("spin_pitch", "aa", "Spin pitch", { "Off", "Down" }, 1, true)
        B.sl("spin_speed", "aa", "Spin speed", 1, 20, 6, true)
        -- Protection
        B.cb("fs_air", "protect", "FS: disable in air", true, true)
        B.cb("fs_crouch", "protect", "FS: disable while crouching", false, true)
        B.cb("fs_slow", "protect", "FS: disable while slow walking", false, true)
        B.cb("fs_moving", "protect", "FS: disable while moving", false, true)
        B.cb("fs_auto", "protect", "FS: auto when standing still", true, true)
        B.cb("safe_head", "protect", "Safe head", true, true)
        B.cb("safe_knife", "protect", "Safe head: knife/zeus in air crouch", true, true)
        B.cb("safe_air", "protect", "Safe head: any air crouch", false, true)
        B.cb("safe_high", "protect", "Safe head: high ground", false, true)
        B.cb("anti_brute", "protect", "Anti-bruteforce", true, true)
        B.sl("brute_reset", "protect", "Anti-brute reset after", 1, 15, 6, true, "s")
        B.cb("brute_random", "protect", "Random anti-brute order", true, true)
        B.cb("knife_md", "protect", "Lower Min. damage vs close knife/zeus", true, true)
        B.cb("crouch_cap", "protect", "Desync keeper: slow crouch-walk when seen", true, false)
        B.sl("crouch_speed", "protect", "Crouch speed", 20, 78, 38, false, "u/s")
        -- Builder
        UI.build_builder()
        -- Exploits
        B.cb("safe_recharge", "exploits", "Safe recharge", true, true)
        B.cb("crouch_recharge", "exploits", "Also while crouched (peek / crouch move)", false, true)
        B.sl("hidden_spin", "exploits", "Hidden spin speed", 1, 30, 10, true)
        B.cb("smart_force", "exploits", "Force defensive when seen / near (Smart)", true, true)
        B.cb("def_cooldown", "exploits", "Re-arm cooldown (let DT refill after defensive)", true, true)
        B.cb("anti_peek", "exploits", "Defensive vs enemy peeks", true, true)
        B.cb("switch_def", "exploits", "Defensive while switching weapons", true, true)
        B.cb("clean_shot", "exploits", "Clean shot (no lag while shooting)", true, true)
        B.cb("air_teleport", "exploits", "Teleport in air when seen", true, true)
        B.cb("air_lc", "exploits", "Air: break LC (uncharge + full fake lag when seen)", true, false)
        B.cb("air_lag", "exploits", "Air lag (defensive every tick)", true, true)
        B.sl("air_hc", "exploits", "In-air hit chance (snipers, 0 = off)", 0, 100, 0, true, "%")
        -- Peek
        B.cb("auto_peek", "peek", "Auto peek state (moving into view)", true, true)
        B.cb("ai_peek", "peek", "AI peek (hold autopeek key)", true, true)
        B.cb("peek_defensive", "peek", "Defensive during AI peek", true, true)
        B.cb("afk", "peek", "AFK mode (AI peek here + strafe, full exploits)", false, false)
        B.cb("afk_auto", "peek", "Auto AFK (no input 8 s after spawn)", true, false)
        -- Ragebot
        B.cb("resolver", "rage", "Adaptive resolver", true, true)
        B.cb("low_hp_safe", "rage", "Finish low HP (<=30) with safe point", true, true)
        B.cb("smart_baim", "rage", "Smart body aim", true, true)
        B.cb("head_only", "rage", "Head unless body kills (snipers)", true, true)
        B.cb("dt_pair", "rage", "DT pair counts as lethal (body x2 >= HP)", false, true)
        B.cb("fake_body", "rage", "Snipers: lethal body on fake records", true, true)
        B.cb("wait_real", "rage", "Wait for real record (enemy defensive)", true, true)
        B.cb("fresh_only", "rage", "Snipers: fresh record only", true, true)
        B.cb("ext_body", "rage", "Body vs extended (repeated head misses)", true, false)
        B.cb("hider_body", "rage", "Body vs head hiders (head share <= 35 pct over 12+ shots)", true, false)
        -- Visuals
        B.cb("indicators", "visuals", "Crosshair indicators", true, false)
        B.color("accent", "indicators", "Indicator color", color_t(150, 190, 255, 255))
        B.cb("arrows", "visuals", "Manual arrows", true, false)
        B.color("arrow_color", "arrows", "Arrow color", color_t(150, 190, 255, 255))
        B.cb("left_ind", "visuals", "Left indicators (DT / HS / FD / DEF / MD ...)", true, false)
        B.cb("stats_panel", "visuals", "Stats panel", false, false)
        B.cb("res_panel", "visuals", "Resolver panel", true, false)
        B.sl("panel_size", "visuals", "Panel size", 70, 200, 160, false, "%")
        B.sl("panel_x", "visuals", "Panel position X", 0, 1000, 560, false)
        B.sl("panel_y", "visuals", "Panel position Y", 0, 1000, 380, false)
        -- Misc
        B.cb("clantag", "misc", "Clan tag: Nykle.win (animated)", true, false)
        B.cb("trash_talk", "misc", "Trash talk", false, false)
        B.cb("tt_kill", "misc", "On kill", true, false)
        B.cb("tt_headshot", "misc", "Kills: headshots only", false, false)
        B.cb("tt_death", "misc", "On death", true, false)
        B.sl("tt_chance", "misc", "Chance", 1, 100, 100, false, "%")
        B.sel("tt_chat", "misc", "Chat", { "All chat", "Team chat" }, 1, false)
        B.sl("tt_delay", "misc", "Message delay", 0.5, 5, 2.3, false, "s", 0.1, 1)
        B.cb("jump_scout", "misc", "Jump scout (no air strafe on standing jump)", true, false)
        B.cb("auto_buy", "misc", "Auto buy grenades (HE + smoke + molotov)", true, false)
        B.cb("left_hand", "misc", "Left hand (cl_righthand 0, permanent)", true, false)
        B.sel("aspect", "misc", "Aspect ratio", { "4:3", "Off", "5:4", "16:10" }, 1, false)
        B.cb("fps_boost", "misc", "FPS boost (shadows / 3D sky / post-process off)", true, false)
        B.cb("fps_ragdolls", "misc", "Disable ragdolls (bodies vanish)", false, false)

        for _, g in ipairs(UI.GROUP_ORDER) do
            pcall(menu.set_group_column, UI.G[g[1]], g[2])
        end
        UI.build_vis()
    end

    -- Gorunurluk kurallari: { oge, kosul }.
    UI.build_vis = function()
        local list = {}
        local function rule(key, fn)
            if UI.e[key] ~= nil then
                list[#list + 1] = { el = UI.e[key], fn = fn }
            end
        end
        rule("backstab_def", function() return N.on("avoid_backstab") end)
        for _, k in ipairs({ "spin_warmup", "spin_enemies", "spin_pitch", "spin_speed" }) do
            rule(k, function() return N.on("spin") end)
        end
        for _, k in ipairs({ "safe_knife", "safe_air", "safe_high" }) do
            rule(k, function() return N.on("safe_head") end)
        end
        rule("brute_reset", function() return N.on("anti_brute") end)
        rule("brute_random", function() return N.on("anti_brute") end)
        rule("crouch_speed", function() return N.on("crouch_cap") end)
        rule("crouch_recharge", function() return N.on("safe_recharge") end)
        rule("def_cooldown", function() return N.on("smart_force") end)
        rule("peek_defensive", function() return N.on("ai_peek") end)
        rule("low_hp_safe", function() return N.on("resolver") end)
        rule("dt_pair", function() return N.on("head_only") end)
        for _, k in ipairs({ "panel_size", "panel_x", "panel_y" }) do
            rule(k, function() return N.on("res_panel") end)
        end
        for _, k in ipairs({ "tt_kill", "tt_death", "tt_chance", "tt_chat", "tt_delay" }) do
            rule(k, function() return N.on("trash_talk") end)
        end
        rule("tt_headshot", function() return N.on("trash_talk") and N.on("tt_kill") end)
        rule("fps_ragdolls", function() return N.on("fps_boost") end)
        -- Builder: secili durumun ogeleri; Override kapaliysa sadece Override kutusu.
        for _, s in ipairs(K.STATES) do
            local row = UI.b[s]
            for key, el in pairs(row) do
                local fn
                local function base()
                    if UI.cur_state ~= s then
                        return false
                    end
                    if key ~= "override" and row.override ~= nil and UI.val(row.override, true) ~= true then
                        return false
                    end
                    return true
                end
                if key == "yaw_left" or key == "yaw_right" then
                    fn = function() return base() and N.bv(s, "yaw_mode") == 1 end
                elseif key == "ways" then
                    fn = function() return base() and N.bv(s, "yaw_mode") == 2 end
                elseif key:sub(1, 3) == "way" then
                    local n = tonumber(key:sub(4)) or 1
                    fn = function()
                        return base() and N.bv(s, "yaw_mode") == 2 and n <= (N.bv(s, "ways") or 3)
                    end
                elseif key == "mod_random" or key == "mod_offset" then
                    fn = function() return base() and N.bv(s, "modifier") ~= 1 end
                elseif key == "body_fs" then
                    fn = function() return base() and N.bv(s, "body_yaw") == 2 end
                elseif key == "delay_random" or key == "delay" then
                    fn = function() return base() and N.bv(s, "body_yaw") == 1 end
                else
                    fn = base
                end
                list[#list + 1] = { el = el, fn = fn }
            end
            local xrow = UI.x[s]
            for key, el in pairs(xrow) do
                local fn
                if key == "def_ticks" then
                    fn = function() return UI.cur_state == s and N.xv(s, "def_mode") == 5 end
                elseif key == "hidden_pitch_value" then
                    fn = function() return UI.cur_state == s and N.xv(s, "hidden_pitch") == 7 end
                elseif key == "hidden_yaw_value" then
                    fn = function() return UI.cur_state == s and N.xv(s, "hidden_yaw") == 6 end
                else
                    fn = function() return UI.cur_state == s end
                end
                list[#list + 1] = { el = el, fn = fn }
            end
        end
        UI.vis = list
    end

    UI.signature = function()
        local s = UI.cur_state or ""
        local parts = { tostring(N.v("tab")), s }
        for _, k in ipairs({ "avoid_backstab", "spin", "safe_head", "anti_brute", "crouch_cap", "safe_recharge",
            "smart_force", "ai_peek", "resolver", "head_only", "res_panel", "trash_talk", "tt_kill", "fps_boost" }) do
            parts[#parts + 1] = tostring(N.v(k))
        end
        if UI.b[s] ~= nil then
            for _, k in ipairs({ "override", "yaw_mode", "ways", "modifier", "body_yaw" }) do
                parts[#parts + 1] = tostring(N.bv(s, k))
            end
        end
        if UI.xdef[s] ~= nil and UI.xdef[s].def_mode ~= nil then
            for _, k in ipairs({ "def_mode", "hidden_pitch", "hidden_yaw" }) do
                parts[#parts + 1] = tostring(N.xv(s, k))
            end
        end
        return concat(parts, "|")
    end

    UI.sig, UI.open_at, UI.was_open = nil, nil, false
    UI.visibility = function()
        local ok_open, open = pcall(menu.is_open)
        open = ok_open and open == true
        local now = U.now()
        if not open then
            UI.was_open = false
            return
        end
        if not UI.was_open then
            UI.was_open, UI.open_at = true, now
        end
        UI.cur_state = K.STATES[N.v("state")] or "Global"
        local sig = UI.signature()
        local late = UI.open_at ~= nil and now - UI.open_at >= 0.5
        if sig == UI.sig and not late then
            return
        end
        if late then
            UI.open_at = nil
        end
        UI.sig = sig
        local tab = N.v("tab") or 1
        for _, g in ipairs(UI.GROUP_ORDER) do
            local show = g[3] == 0 or g[3] == tab
            pcall(menu.set_group_visibility, UI.G[g[1]], show)
        end
        for _, item in ipairs(UI.vis) do
            local ok, show = pcall(item.fn)
            pcall(item.el.set_visible, item.el, ok and show == true)
        end
    end

    UI.text_of = function(t, v)
        if t.items ~= nil and U.finite(v) and t.items[floor(v)] ~= nil then
            return t.items[floor(v)]
        end
        return U.numtext(v)
    end

    UI.differs = function(v, def)
        if type(def) == "number" then
            return not U.finite(v) or abs(v - def) > 1e-4
        end
        return v ~= def
    end

    -- Saniyede bir (menu kapaliyken): izlenen ogeler varsayilanina doner.
    UI.rec_at, UI.rec_reported = -1000, false
    UI.recommend = function()
        local now = U.now()
        if now >= UI.rec_at and now - UI.rec_at < 1 then
            return
        end
        UI.rec_at = now
        local ok_open, open = pcall(menu.is_open)
        if ok_open and open == true then
            return
        end
        local on = N.on("recommended")
        if not on and UI.rec_reported then
            return
        end
        local n, example = 0, nil
        for _, t in ipairs(UI.tracked) do
            local okg, v = pcall(t.el.get, t.el)
            if okg and UI.differs(v, t.def) then
                n = n + 1
                if example == nil then
                    example = fmt("%s %s -> %s", t.label, UI.text_of(t, v), UI.text_of(t, t.def))
                end
                if on then
                    UI.set(t.el, t.def)
                end
            end
        end
        if on then
            UI.rec_reported = false
            if n > 0 then
                N.log.line(fmt("%d ayar onerilen degerine donduruldu (orn. %s)", n, example))
            end
        else
            UI.rec_reported = true
            if n > 0 then
                N.log.line(fmt("Always use recommended settings kapali: %d ayar onerilenden farkli (orn. %s)", n,
                    example))
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Override nesnesi: native menuye TEK yazma yolu (anlik kopya, geri okuma, birakinca geri yazma)
-------------------------------------------------------------------------------
do
    local U, O = N.util, N.ov
    O.items, O.warned, O.multi_off = {}, {}, false
    O.neutral_at = -1000
    -- A23: native AA tasiyicilari notrde (Lua degerleri 1 tabanli; cfg'de index - 1).
    O.NEUTRAL = {
        { "jitter_mode", 1 }, { "rotate", false }, { "yaw_add", 0 }, { "body_lean", 1 },
        { "moving_body_lean", false }, { "ext_moving", false }, { "override_move", false },
        { "override_slow", false }, { "anti_brute_native", false }, { "on_shot", 1 }, { "side_stand", 2 },
        { "left_amount_stand", 100 }, { "right_amount_stand", 100 },
    }

    local function same(a, b)
        if type(a) == "number" and type(b) == "number" then
            return abs(a - b) < 1e-4
        end
        return a == b
    end
    O.same = same

    O.set = function(key, ref, value)
        if ref == nil then
            return false
        end
        local now = U.now()
        local it = O.items[key]
        if it ~= nil and it.failed_until ~= nil and now < it.failed_until and now >= it.failed_until - 10 then
            return false
        end
        local okc, cur = pcall(ref.get, ref)
        if not okc then
            return false
        end
        if it == nil then
            it = { ref = ref, snap = cur }
            O.items[key] = it
        elseif it.written ~= nil and not same(cur, it.written) then
            -- Tutarken kullanici degistirdi: birakinca onun degeri geri gelsin.
            it.snap = cur
        end
        if same(cur, value) then
            it.written, it.failed_until = value, nil
            return true
        end
        pcall(ref.set, ref, value)
        local okb, back = pcall(ref.get, ref)
        if not okb or not same(back, value) then
            it.failed_until = now + 5
            if not O.warned[key] then
                O.warned[key] = true
                N.log.line(fmt("%s = %s ayarlanamadi", key, tostring(value)))
            end
            return false
        end
        it.written, it.failed_until = value, nil
        return true
    end

    -- Native multi'de tek oge (ada gore; geri okuma yanlissa :get_items() sirasiyla index).
    O.set_multi = function(key, ref, item, value)
        if ref == nil or O.multi_off then
            return false
        end
        local full = key .. ":" .. item
        local now = U.now()
        local it = O.items[full]
        if it ~= nil and it.failed_until ~= nil and now < it.failed_until and now >= it.failed_until - 10 then
            return false
        end
        if it == nil then
            local okn, v = pcall(ref.get, ref, item)
            local sel = item
            if not okn or type(v) ~= "boolean" then
                sel = nil
                local oki, items = pcall(ref.get_items, ref)
                if oki and type(items) == "table" then
                    for i, name in ipairs(items) do
                        if tostring(name):lower() == item:lower() then
                            sel = i
                        end
                    end
                end
                if sel ~= nil then
                    okn, v = pcall(ref.get, ref, sel)
                end
            end
            if sel == nil or not okn or type(v) ~= "boolean" then
                O.multi_off = true
                N.log.line(fmt("%s = %s ayarlanamadi (oge okunamadi; durum basina FS kapatma kapali)", full,
                    tostring(value)))
                return false
            end
            it = { ref = ref, snap = v, sel = sel, multi = true }
            O.items[full] = it
        end
        local okc, cur = pcall(ref.get, ref, it.sel)
        if okc and cur == value then
            it.written = value
            return true
        end
        pcall(ref.set, ref, it.sel, value)
        local okb, back = pcall(ref.get, ref, it.sel)
        if okb and back == value then
            it.written = value
            return true
        end
        -- Ada gore yazilamadi: :get_items() sirasiyla bir kez daha.
        if type(it.sel) == "string" then
            local oki, items = pcall(ref.get_items, ref)
            if oki and type(items) == "table" then
                for i, name in ipairs(items) do
                    if tostring(name):lower() == item:lower() then
                        it.sel = i
                    end
                end
            end
            if type(it.sel) == "number" then
                pcall(ref.set, ref, it.sel, value)
                okb, back = pcall(ref.get, ref, it.sel)
                if okb and back == value then
                    it.written = value
                    return true
                end
            end
        end
        it.failed_until = now + 5
        if not O.warned[full] then
            O.warned[full] = true
            N.log.line(fmt("%s = %s ayarlanamadi", full, tostring(value)))
        end
        return false
    end

    O.release = function(key)
        local it = O.items[key]
        if it == nil then
            return
        end
        O.items[key] = nil
        if it.written == nil then
            return
        end
        if it.multi then
            local okc, cur = pcall(it.ref.get, it.ref, it.sel)
            if okc and cur == it.written and cur ~= it.snap then
                pcall(it.ref.set, it.ref, it.sel, it.snap)
            end
            return
        end
        local okc, cur = pcall(it.ref.get, it.ref)
        if okc and same(cur, it.written) and not same(cur, it.snap) then
            pcall(it.ref.set, it.ref, it.snap)
        end
    end

    O.release_prefix = function(prefix)
        local keys = {}
        for key in pairs(O.items) do
            if key:sub(1, #prefix) == prefix then
                keys[#keys + 1] = key
            end
        end
        for _, key in ipairs(keys) do
            O.release(key)
        end
    end

    O.release_all = function()
        local keys = {}
        for key in pairs(O.items) do
            keys[#keys + 1] = key
        end
        for _, key in ipairs(keys) do
            O.release(key)
        end
    end

    O.held = function(key)
        return O.items[key] ~= nil
    end

    -- A23: Enable acikken native tasiyicilar notrde (64 tick'te bir kontrol).
    O.hold_neutral = function(force)
        local t = U.tick()
        if not force and t >= O.neutral_at and t - O.neutral_at < 64 then
            return
        end
        O.neutral_at = t
        for _, item in ipairs(O.NEUTRAL) do
            local ref = N.ref.items[item[1]]
            if ref ~= nil then
                O.set(item[1], ref, item[2])
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Sarj sahibi: block_recharge / allow_recharge tek yerden (sebep listesi + 3 sn bekci)
-------------------------------------------------------------------------------
do
    local U, RC = N.util, N.rc
    RC.reasons, RC.banned = {}, {}

    RC.block = function(reason)
        if RC.banned[reason] then
            return false
        end
        RC.reasons[reason] = RC.reasons[reason] or U.now()
        U.call(exploits.block_recharge)
        return true
    end

    RC.allow = function(reason)
        RC.banned[reason] = nil
        if RC.reasons[reason] == nil then
            return
        end
        RC.reasons[reason] = nil
        if next(RC.reasons) == nil then
            U.call(exploits.allow_recharge)
        end
    end

    -- Her SETUP_COMMAND: tutulurken block her tick yeniden (yapiskan oldugu kesin degil).
    RC.tick = function()
        if next(RC.reasons) ~= nil then
            U.call(exploits.block_recharge)
        end
    end

    RC.release_all = function()
        local had = next(RC.reasons) ~= nil
        RC.reasons, RC.banned = {}, {}
        U.call(exploits.allow_recharge)
        return had
    end

    RC.watchdog = function()
        local now = U.now()
        for reason, since in pairs(RC.reasons) do
            if now < since or now - since > 3 then
                RC.reasons[reason] = nil
                RC.banned[reason] = true
                if next(RC.reasons) == nil then
                    U.call(exploits.allow_recharge)
                end
                N.log.line(fmt("sarj kilidi 3 sn'yi gecti, birakildi (%s)", reason))
                return
            end
        end
    end

    RC.held = function(reason)
        if reason ~= nil then
            return RC.reasons[reason] ~= nil
        end
        return next(RC.reasons) ~= nil
    end
end

-------------------------------------------------------------------------------
-- Kalici hafiza (nykle_memory.txt, Steam ID ile): resolver sonuclari, anti-brute tabani, faz istatistikleri,
-- kafa saklayan sayaclari.
-------------------------------------------------------------------------------
do
    local U, M = N.util, N.mem
    M.file, M.players, M.count, M.session, M.dirty, M.loaded = "nykle_memory.txt", {}, 0, 1, false, false
    M.seq, M.kc = 0, {}

    M.key_of = function(ent, name)
        if ent == nil then
            return nil
        end
        local ok, _, sid64 = pcall(ent.get_steamids, ent)
        local key = ok and sid64 ~= nil and tostring(sid64):gsub("U?LL$", "") or nil
        if key == nil or key == "" or key == "0" or key == "nil" then
            key = "n:" .. (name or U.name(ent))
        end
        return key
    end

    -- Anahtar ve ad entity index'ine gore 1 sn onbellekte (tick basina birkac kez steamid / ad okunmasin).
    M.cached = function(ent)
        local idx = U.index(ent)
        local now = U.now()
        local c = idx ~= nil and M.kc[idx] or nil
        if c ~= nil and now >= c.at and now - c.at < 1 then
            return c.key, c.name
        end
        local name = U.name(ent)
        local key = M.key_of(ent, name)
        if idx ~= nil then
            M.kc[idx] = { key = key, name = name, at = now }
        end
        return key, name
    end

    M.entry = function(ent, key)
        local ck, name = nil, nil
        if ent ~= nil then
            ck, name = M.cached(ent)
        end
        key = key or ck
        if key == nil then
            return nil, nil
        end
        M.seq = M.seq + 1
        local p = M.players[key]
        if p == nil then
            p = { name = name or "?", last = M.session, base = nil, res = {},
                hider = { n = 0, h = 0, b = 0 }, gmiss = 0 }
            M.players[key] = p
            M.count = M.count + 1
            M.dirty = true
            if M.count > N.K.MEMORY_LIMIT then
                p.seen = M.seq
                M.trim(key)
            end
        end
        p.seen = M.seq
        if p.last ~= M.session then
            p.last = M.session
            M.dirty = true
        end
        if name ~= nil and p.name ~= name then
            p.name = name
        end
        return p, key
    end

    -- En uzun suredir gorulmeyenler atilir (64 oyuncu siniri): once oturum, esitse son erisim; yeni eklenen
    -- (keep) hic atilmaz.
    M.trim = function(keep)
        local list = {}
        for key, p in pairs(M.players) do
            if key ~= keep then
                list[#list + 1] = { key = key, last = p.last or 0, seen = p.seen or 0 }
            end
        end
        table.sort(list, function(a, b)
            if a.last ~= b.last then
                return a.last > b.last
            end
            return a.seen > b.seen
        end)
        local room = N.K.MEMORY_LIMIT - (keep ~= nil and M.players[keep] ~= nil and 1 or 0)
        for i = room + 1, #list do
            M.players[list[i].key] = nil
        end
        M.count = min(#list, room) + (N.K.MEMORY_LIMIT - room)
    end

    local function split(line)
        local out = {}
        for field in (line .. "\t"):gmatch("([^\t]*)\t") do
            out[#out + 1] = field
        end
        return out
    end

    M.load = function()
        M.loaded = true
        local text = N.fs.ok and N.fs.read(M.file) or nil
        if text == nil then
            return
        end
        local first = true
        for line in text:gmatch("[^\n]+") do
            local f = split(line:gsub("\r$", ""))
            if first then
                first = false
                if f[1] ~= "NYKLEMEM" or f[2] ~= "1" then
                    return
                end
                M.session = (tonumber(f[3]) or 0) + 1
            elseif f[1] == "P" and #f >= 8 and f[2] ~= "" then
                local res = {}
                for state, results in f[6]:gmatch("([^=;]+)=([cho]*)") do
                    -- Eski surumlerin 'o' (diger iska) harfleri pencereyi sulandirmasin.
                    res[state] = results:gsub("o", ""):sub(-4)
                end
                local n, h, b = f[7]:match("^([%d%.]+),([%d%.]+),(%d+)$")
                M.players[f[2]] = { name = f[3], last = tonumber(f[4]) or 0, base = tonumber(f[5]), res = res,
                    hider = { n = tonumber(n) or 0, h = tonumber(h) or 0, b = tonumber(b) or 0 },
                    gmiss = tonumber(f[8]) or 0 }
                M.count = M.count + 1
            elseif f[1] == "F" and #f >= 5 then
                local B = N.brute
                local list = B.phases[f[2]]
                local phase = tonumber(f[3])
                if list ~= nil and phase ~= nil and list[phase] ~= nil then
                    list[phase].shots = tonumber(f[4]) or 0
                    list[phase].hits = tonumber(f[5]) or 0
                end
            end
        end
        if M.count > N.K.MEMORY_LIMIT then
            M.trim()
        end
        for _, g in ipairs(N.K.BRUTE_GROUPS) do
            N.brute.default[g] = N.brute.best_default(g)
        end
    end

    local function num(v)
        if not U.finite(v) then
            return "0"
        end
        if abs(v - floor(v)) < 1e-9 then
            return fmt("%d", floor(v))
        end
        return fmt("%.2f", v)
    end

    M.text = function()
        local out = { "NYKLEMEM\t1\t" .. fmt("%d", floor(M.session)) }
        for key, p in pairs(M.players) do
            local res = {}
            for state, results in pairs(p.res) do
                if results ~= "" then
                    res[#res + 1] = state .. "=" .. results
                end
            end
            table.sort(res)
            local hd = p.hider or { n = 0, h = 0, b = 0 }
            out[#out + 1] = concat({ "P", key, (tostring(p.name or "?"):gsub("[\t\r\n]", " ")),
                num(p.last or 0), p.base ~= nil and num(p.base) or "", concat(res, ";"),
                num(hd.n) .. "," .. num(hd.h) .. "," .. num(floor(hd.b)), num(p.gmiss or 0) }, "\t")
        end
        for _, g in ipairs(N.K.BRUTE_GROUPS) do
            local list = N.brute.phases[g]
            for phase = 0, #N.K.BRUTE_PHASES do
                local s = list[phase]
                if s ~= nil and s.shots > 0 then
                    out[#out + 1] = concat({ "F", g, fmt("%d", phase), num(s.shots), num(s.hits) }, "\t")
                end
            end
        end
        return concat(out, "\n") .. "\n"
    end

    M.save = function(force)
        if not M.dirty and not force then
            return false
        end
        if not N.fs.ok then
            return false
        end
        if N.fs.put(M.file, M.text(), "w") then
            M.dirty = false
            return true
        end
        return false
    end

    M.forget = function()
        M.players, M.count = {}, 0
        N.brute.reset_phases()
        N.brute.enemies = {}
        N.rage.t = {}
        M.dirty = true
        M.save(true)
        N.log.line("ogrenilen dusmanlar unutuldu (resolver seviyeleri, anti-brute fazlari, kafa payi)")
    end
end

-------------------------------------------------------------------------------
-- Dusman takibi: simulasyon zamani (sahte kayit / defensive), LC kirma, kayit gecikmesi, goz yaw deseni,
-- silah. NET_UPDATE'ten (calismadiysa SETUP_COMMAND'dan).
-------------------------------------------------------------------------------
do
    local U, T = N.util, N.track
    T.p, T.updated_tick = {}, -1

    T.get = function(idx)
        local t = T.p[idx]
        if t == nil then
            t = { idx = idx, last_sim = nil, def_until = -1, lc_until = -1, record_age = 0, yaws = {},
                pattern = "?", we_shot = -1000, shot_us = -1000, dmg_dealt = 0, last_origin = nil }
            T.p[idx] = t
        end
        return t
    end

    T.update = function()
        local tick = U.tick()
        T.updated_tick = tick
        local lp = N.st.lp
        if lp == nil then
            return
        end
        local ok, players = pcall(entity_list.get_players, true)
        if not ok or type(players) ~= "table" then
            return
        end
        for _, ent in ipairs(players) do
            local idx = U.index(ent)
            if idx ~= nil and U.alive(ent) and not U.dormant(ent) then
                local t = T.get(idx)
                t.ent = ent
                local simt = U.num(ent, "m_flSimulationTime")
                if simt ~= nil then
                    local okt, sim = pcall(client.time_to_ticks, simt)
                    if not okt or not U.finite(sim) then
                        sim = floor(simt / U.ipt() + 0.5)
                    end
                    t.record_age = max(0, tick - sim)
                    if t.last_sim ~= nil then
                        if sim < t.last_sim then
                            -- Simulasyon zamani geri gitti: sahte kayit (defensive).
                            t.def_until = tick + min(16, t.last_sim - sim)
                            t.def_start = t.def_start or tick
                            if tick - t.def_start > 64 then
                                -- 1 sn'den uzun "geride" kalan kayit defensive degil (dogus vb.): sifirla.
                                t.def_until, t.def_start, t.last_sim = -1, nil, sim
                            end
                        elseif sim > t.last_sim then
                            local org = U.origin(ent)
                            if org ~= nil and t.last_origin ~= nil then
                                local dx, dy, dz = org.x - t.last_origin.x, org.y - t.last_origin.y,
                                    org.z - t.last_origin.z
                                if dx * dx + dy * dy + dz * dz > 4096 then
                                    t.lc_until = tick + 16
                                end
                            end
                            if org ~= nil then
                                t.last_origin = { x = org.x, y = org.y, z = org.z }
                            end
                            if tick > t.def_until then
                                t.def_start = nil
                                local yaw = U.prop(ent, "m_angEyeAngles[1]")
                                if U.finite(yaw) then
                                    local ys = t.yaws
                                    ys[#ys + 1] = yaw
                                    if #ys > 8 then
                                        tremove(ys, 1)
                                    end
                                    T.classify(t)
                                end
                            end
                        end
                    end
                    if t.last_sim == nil or sim >= t.last_sim or tick > t.def_until then
                        t.last_sim = sim
                    end
                end
            end
        end
    end

    -- Son 8 gercek kayittaki goz yaw'larinin yayilimi < 35 derece = statik.
    T.classify = function(t)
        local ys = t.yaws
        if #ys < 4 then
            t.pattern = "?"
            return
        end
        local spread = 0
        for i = 1, #ys do
            for j = i + 1, #ys do
                spread = max(spread, abs(U.norm(ys[i] - ys[j])))
            end
        end
        t.pattern = spread < 35 and "static" or "jitter"
        t.last_yaw = ys[#ys]
    end

    T.fallback = function()
        if T.updated_tick ~= U.tick() then
            T.update()
        end
    end

    T.fake = function(idx)
        local t = T.p[idx]
        if t == nil then
            return false
        end
        local tick = U.tick()
        return tick <= t.def_until or tick <= t.lc_until
    end

    -- Dusmanin durumu (loglar ve resolver seviyesi icin).
    T.enemy_state = function(ent)
        if ent == nil then
            return "?"
        end
        if U.flag(ent, "ON_GROUND") == false then
            return "Air"
        end
        local duck = U.num(ent, "m_flDuckAmount") or 0
        local speed = U.speed(ent)
        if duck > 0.7 then
            return speed > 10 and "Crouch move" or "Crouching"
        end
        if speed > 10 then
            return speed < 135 and "Slow walk" or "Moving"
        end
        return "Standing"
    end

    -- Atis satiri profili: "<static|jitter|?> dsy? <air|ground>".
    T.profile = function(ent)
        local idx = U.index(ent)
        local t = idx ~= nil and T.p[idx] or nil
        local pattern = t ~= nil and t.pattern or "?"
        local air = ent ~= nil and U.flag(ent, "ON_GROUND") == false
        return fmt("%s dsy? %s", pattern, air and "air" or "ground")
    end
end

-------------------------------------------------------------------------------
-- Gorus (X1): biri kafami su an / 0.2 sn icinde goruyor mu; tehdit her cagride, digerleri sirayla.
-------------------------------------------------------------------------------
do
    local U, E = N.util, N.exposure
    E.sight, E.now_set, E.soon_set = {}, {}, {}
    E.now, E.soon, E.seen, E.near = false, false, false, false
    E.turn, E.last_tick, E.first_edge = 0, -1000, {}

    E.enemies = function()
        local st = N.st
        local tick = U.tick()
        if st.enemies_tick == tick then
            return st.enemies
        end
        local list, any = {}, false
        local ok, players = pcall(entity_list.get_players, true)
        if ok and type(players) == "table" then
            for _, ent in ipairs(players) do
                if U.alive(ent) then
                    any = true
                    if not U.dormant(ent) and ent ~= st.lp then
                        list[#list + 1] = ent
                    end
                end
            end
        end
        st.enemies, st.enemies_tick, st.any_enemy_alive = list, tick, any
        return list
    end

    -- Dusmanin gozunden kafama (ve +-4 birim kenarlarina) mermi geciyor mu.
    E.check = function(enemy, lp, head, predict)
        local eye = U.eye(enemy)
        if eye == nil or head == nil then
            return false
        end
        local hx, hy, hz = head.x, head.y, head.z
        local ex, ey, ez = eye.x, eye.y, eye.z
        if predict then
            local my, their = U.vel(lp), U.vel(enemy)
            local idx = U.index(enemy)
            local tr = idx ~= nil and N.track.p[idx] or nil
            local lag = min(0.25, (tr ~= nil and tr.record_age or 0) * U.ipt())
            local ta = N.K.LOOKAHEAD
            hx, hy, hz = hx + my.x * ta, hy + my.y * ta, hz + my.z * ta
            ex, ey, ez = ex + their.x * (ta + lag), ey + their.y * (ta + lag), ez + their.z * (ta + lag)
        end
        local from = vec3_t(ex, ey, ez)
        local yaw = U.yaw_to(from, { x = hx, y = hy }) + 90
        local cx, sy = U.dir(yaw)
        for _, off in ipairs({ 0, 4, -4 }) do
            local p = vec3_t(hx + cx * off, hy + sy * off, hz)
            if U.tdmg(from, p, enemy, lp) > 0 then
                return true
            end
        end
        return false
    end

    E.update = function()
        local st = N.st
        local lp = st.lp
        local tick = U.tick()
        local list = E.enemies()
        local mine = U.origin(lp)
        local near = false
        if mine ~= nil then
            for _, enemy in ipairs(list) do
                local o = U.origin(enemy)
                if o ~= nil and U.dist(o, mine) <= N.K.NEAR then
                    near = true
                end
            end
        end
        E.near = near
        if tick - E.last_tick >= N.K.EXPOSE_EVERY or tick < E.last_tick then
            E.last_tick = tick
            local head = U.hitbox(lp, "HEAD")
            local threat = st.threat
            local check = {}
            if threat ~= nil then
                check[#check + 1] = threat
            end
            if #list > 0 then
                E.turn = E.turn % #list + 1
                local other = list[E.turn]
                if other ~= threat then
                    check[#check + 1] = other
                end
            end
            for _, enemy in ipairs(check) do
                local idx = U.index(enemy)
                if idx ~= nil then
                    local now_seen = E.check(enemy, lp, head, false)
                    local soon = now_seen or E.check(enemy, lp, head, true)
                    E.now_set[idx] = now_seen and tick or nil
                    E.soon_set[idx] = soon and tick or nil
                    if now_seen then
                        local s = E.sight[idx]
                        if s == nil or tick - s.last > N.K.SIGHT_GAP or tick < s.last then
                            E.sight[idx] = { first = tick, last = tick }
                            E.first_edge[idx] = tick
                        else
                            s.last = tick
                        end
                    end
                end
            end
        end
        -- Ozet bayraklar (tehdit disindakilerin degeri 12 tick gecerli).
        local any_now, any_soon, any_seen = false, false, false
        for idx, t in pairs(E.now_set) do
            if tick - t <= 12 and tick >= t then
                any_now = true
            else
                E.now_set[idx] = nil
            end
        end
        for idx, t in pairs(E.soon_set) do
            if tick - t <= 12 and tick >= t then
                any_soon = true
            else
                E.soon_set[idx] = nil
            end
        end
        for _, s in pairs(E.sight) do
            if tick >= s.last and tick - s.last <= N.K.SIGHT_RECENT then
                any_seen = true
            end
        end
        E.now, E.soon, E.seen = any_now, any_soon, any_seen
    end

    E.sees = function(idx)
        local s = E.sight[idx]
        local tick = U.tick()
        return s ~= nil and tick >= s.last and tick - s.last <= N.K.SIGHT_RECENT
    end

    E.sees_now = function(idx)
        local t = E.now_set[idx]
        return t ~= nil and U.tick() - t <= 12
    end

    -- Ilk gorus kenari son n tick icinde mi (anti-peek).
    E.first_sight_within = function(n)
        local tick = U.tick()
        for _, t in pairs(E.first_edge) do
            if tick >= t and tick - t <= n then
                return true
            end
        end
        return false
    end

    E.reset = function()
        E.sight, E.now_set, E.soon_set, E.first_edge = {}, {}, {}, {}
        E.now, E.soon, E.seen = false, false, false
    end
end

-------------------------------------------------------------------------------
-- Durum (A1): once hareket durumu (Air > Fake duck > Peek > egik > yuru > dur), sonra Manual > Safe head >
-- Freestanding (sadece kafa gizliyken).
-------------------------------------------------------------------------------
do
    local U, S = N.util, N.state
    S.ground_ticks, S.moving, S.ducked, S.cmdn = 64, false, false, nil
    S.peek_until = -1000

    S.speed_hysteresis = function(speed)
        if speed > N.K.MOVE_ENTER then
            S.moving = true
        elseif speed < N.K.MOVE_LEAVE then
            S.moving = false
        end
        return S.moving
    end

    S.detect = function(cmd, unpred)
        local cmdn = cmd ~= nil and cmd.command_number or nil
        if cmdn ~= nil and cmdn == S.cmdn then
            return N.st.state
        end
        S.cmdn = cmdn
        local st, P, E = N.st, N.ref, N.exposure
        local lp = st.lp
        local tick = U.tick()
        local ground = U.flag(lp, "ON_GROUND") ~= false
        if unpred ~= nil then
            local ok, v = pcall(unpred.has_player_flag, unpred, e_player_flags.ON_GROUND)
            if ok and v == false then
                ground = false
            end
        end
        S.ground_ticks = ground and min(S.ground_ticks + 1, 64) or 0
        local jump = false
        if cmd ~= nil then
            local okj, j = pcall(cmd.has_button, cmd, e_cmd_buttons.JUMP)
            jump = okj and j == true
        end
        local air = jump or S.ground_ticks < N.K.LANDING_TICKS
        st.airborne = S.ground_ticks < N.K.LANDING_TICKS
        -- Merdivende ON_GROUND yok ama ucus degil: exploit / air lag / jump scout merdiveni hava saymaz (GS L.policy).
        st.ladder = U.num(lp, "m_MoveType") == 9
        local speed = U.speed(lp)
        st.speed = speed
        local moving = S.speed_hysteresis(speed)
        local duck = U.num(lp, "m_flDuckAmount") or 0
        st.duck = duck
        if duck > N.K.DUCK_ENTER then
            S.ducked = true
        elseif duck < N.K.DUCK_LEAVE then
            S.ducked = false
        end
        local fd = P.fd_on()
        st.fd = fd
        local crouch = S.ducked or fd
        local winfo = U.winfo(lp)
        st.winfo = winfo
        st.weapon = winfo ~= nil and winfo.name or nil
        st.melee = U.melee(winfo)
        st.wgroup = P.wgroup()

        -- Peek: native autopeek tusu + hareket, AI peek yuruyor / bekliyor, AFK, ya da (Auto peek) hareket
        -- ederken gorus alanina girmek.
        local peek = false
        local pk = N.peek
        if (P.on("autopeek") and moving) or pk.mode ~= nil or N.afk.on then
            peek = true
        elseif N.on("auto_peek") and moving then
            if E.soon or E.now then
                S.peek_until = tick + N.K.PEEK_HOLD
            end
            if tick <= S.peek_until and tick >= S.peek_until - N.K.PEEK_HOLD then
                peek = true
            end
        end

        local ms
        if air then
            ms = crouch and "Air crouch" or "Air"
        elseif fd then
            ms = "Fake duck"
        elseif peek then
            ms = "Peek"
        elseif crouch then
            ms = moving and "Crouch move" or "Crouching"
        elseif moving then
            ms = P.on("slowwalk") and "Slow walk" or "Moving"
        else
            ms = "Standing"
        end
        st.move_state = ms
        st.crouch = crouch

        -- Ust katman.
        local manual = U.call(antiaim.get_manual_override)
        manual = U.finite(manual) and manual or 0
        st.manual = manual
        local state = ms
        local fs_allowed = S.fs_allowed(ms)
        st.fs_own = nil
        if manual == 1 or manual == 2 or manual == 3 then
            state = "Manual"
        elseif S.safe_head(ms) then
            state = "Safe head"
        elseif P.on("fs") and fs_allowed and not E.now then
            state = "Freestanding"
        elseif N.on("fs_auto") and (ms == "Standing" or ms == "Crouching") and st.threat ~= nil
            and N.aa.cover ~= nil and N.aa.cover_auto then
            state = "Freestanding"
            st.fs_own = N.aa.cover
        end
        st.state = state
        st.label = (ms == "Peek" and crouch and state == "Peek") and "Peek (egik)" or state
        N.aa.fs_native(ms, fs_allowed)
        return state
    end

    S.fs_allowed = function(ms)
        if (ms == "Air" or ms == "Air crouch") and N.on("fs_air") then
            return false
        end
        if (ms == "Crouching" or ms == "Crouch move") and N.on("fs_crouch") then
            return false
        end
        if ms == "Slow walk" and N.on("fs_slow") then
            return false
        end
        if (ms == "Moving" or ms == "Peek") and N.on("fs_moving") then
            return false
        end
        return true
    end

    S.safe_head = function(ms)
        if not N.on("safe_head") then
            return false
        end
        local st = N.st
        if ms == "Air crouch" then
            if N.on("safe_knife") and st.melee ~= nil then
                return true
            end
            if N.on("safe_air") then
                return true
            end
        end
        if N.on("safe_high") and st.threat ~= nil and (ms == "Standing" or ms == "Moving" or ms == "Slow walk"
            or ms == "Crouching" or ms == "Crouch move" or ms == "Peek") then
            local mine, theirs = U.origin(st.lp), U.origin(st.threat)
            local idx = U.index(st.threat)
            if mine ~= nil and theirs ~= nil and mine.z - 35 > theirs.z and idx ~= nil
                and N.exposure.sees_now(idx) then
                return true
            end
        end
        return false
    end
end

-------------------------------------------------------------------------------
-- Anti-aim: AA hedefi, builder (yaw L&R / X-Way, modifier, body yaw, limitler), jitter cevirme (gonderilen
-- pakette, komut numarasi basina bir kez), anti-brute fazi, gizli acilar, desync isareti olcumu, spin / legit /
-- backstab, kendi freestand'imiz (kapak izleri).
-------------------------------------------------------------------------------
do
    local U, A = N.util, N.aa
    local K = N.K
    A.flip = { side = false, packets = 0, extra = 0, step = 0, mstep = 0, yaw_n = 0, mod_n = 0, limit_n = 0,
        rand_side = false, cmdn = nil }
    A.sign_mul = 1
    A.cal = { n = 0, agree = 0, prev = nil, done = false, nil_n = 0, phase = 1, invert = false }
    A.cover, A.cover_auto, A.cover_tick = nil, false, -1000
    A.spin_angle, A.spin_cmdn, A.hspin = 0, nil, 0
    A.last = { side = false, limit = 60, body = "jit", phase = 0, yaw = 0 }
    A.applied, A.target_tick, A.target_ent, A.facing = 0, -1, nil, nil
    A.fs_item = nil
    A.MANUAL = { [1] = -90, [2] = 0, [3] = 90 }

    A.view_yaw = function(cmd)
        if cmd ~= nil then
            local ok, y = pcall(function()
                return cmd.viewangles.y
            end)
            if ok and U.finite(y) then
                N.st.view_yaw = y
                return y
            end
        end
        local ok, ang = pcall(engine.get_view_angles)
        if ok and ang ~= nil then
            local okv, y = pcall(function()
                return ang.y
            end)
            if okv and U.finite(y) then
                return y
            end
        end
        return N.st.view_yaw or 0
    end

    -- AA hedefi: duello (son 1 sn'de ates ettigin ve seni goren) > son 1 sn'de kafana ates eden > seni goren >
    -- nisangaha en yakin.
    A.target = function()
        local tick = U.tick()
        if A.target_tick == tick then
            return A.target_ent
        end
        A.target_tick = tick
        local st, E, T = N.st, N.exposure, N.track
        local list = E.enemies()
        local now = U.now()
        local best
        for _, e in ipairs(list) do
            local idx = U.index(e)
            local t = idx ~= nil and T.p[idx] or nil
            if t ~= nil and now >= t.we_shot and now - t.we_shot <= 1 and E.sees(idx) then
                best = e
                break
            end
        end
        if best == nil then
            local last = -1000
            for _, e in ipairs(list) do
                local idx = U.index(e)
                local t = idx ~= nil and T.p[idx] or nil
                if t ~= nil and now >= t.shot_us and now - t.shot_us <= 1 and t.shot_us > last then
                    best, last = e, t.shot_us
                end
            end
        end
        if best == nil then
            local last = -1000
            for _, e in ipairs(list) do
                local idx = U.index(e)
                local s = idx ~= nil and E.sight[idx] or nil
                if s ~= nil and E.sees(idx) and s.last > last then
                    best, last = e, s.last
                end
            end
        end
        if best == nil then
            local mine = U.origin(st.lp)
            local view = A.view_yaw(nil)
            local best_d = huge
            if mine ~= nil then
                for _, e in ipairs(list) do
                    local o = U.origin(e)
                    if o ~= nil then
                        local d = abs(U.norm(U.yaw_to(mine, o) - view))
                        if d < best_d then
                            best, best_d = e, d
                        end
                    end
                end
            end
        end
        A.target_ent = best
        return best
    end

    A.base = function(cmd)
        local view = A.view_yaw(cmd)
        if N.v("yaw_base") ~= 1 then
            return view, nil
        end
        local target = A.target()
        local mine, theirs = U.origin(N.st.lp), target ~= nil and U.origin(target) or nil
        if mine == nil or theirs == nil then
            return view, nil
        end
        return U.yaw_to(mine, theirs), target
    end

    -- Durumun gecerli satiri: Override kapali hareket durumlari Global'i kullanir.
    A.row = function(state)
        if state == "Ladder" or state == "Legit" or state == "Spin" then
            return "Global"
        end
        if K.OVERRIDABLE[state] and N.bv(state, "override") == false then
            return "Global"
        end
        if N.ui.b[state] == nil then
            return "Global"
        end
        return state
    end

    -- Kapak izleri (A10 / A13): tehdidin gozunden kafamin +-20 birim yanina duz iz (trace.line; hitbox olmayan
    -- noktaya trace.bullet'in ne dondurdugu belgesiz). Tek taraf kapaliysa o taraf; kazanan yoksa kapak yok.
    A.cover_update = function()
        local tick = U.tick()
        if tick - A.cover_tick < 8 and tick >= A.cover_tick then
            return
        end
        A.cover_tick = tick
        local st = N.st
        local threat = st.threat
        A.cover_auto = false
        if threat == nil then
            return
        end
        local eye, head = U.eye(threat), U.hitbox(st.lp, "HEAD")
        local mine, theirs = U.origin(st.lp), U.origin(threat)
        if eye == nil or head == nil or mine == nil or theirs == nil then
            return
        end
        local base = U.yaw_to(mine, theirs)
        local plus = U.offset(head, base + 90, 20, 0)
        local minus = U.offset(head, base - 90, 20, 0)
        local fp, hp = U.tline(eye, plus, threat)
        local fm, hm = U.tline(eye, minus, threat)
        local op = fp >= 0.97 or (hp ~= nil and hp == st.lp)
        local om = fm >= 0.97 or (hm ~= nil and hm == st.lp)
        if not op and om then
            A.cover, A.cover_auto = 1, true
        elseif not om and op then
            A.cover, A.cover_auto = -1, true
        else
            A.cover = nil
        end
    end

    -- A9: native Auto Direction "States" ogesi, izin verilmeyen durumda gecici kapali.
    A.fs_native = function(ms, allowed)
        local ref = N.ref.items.fs_states
        if ref == nil then
            return
        end
        local item = (ms == "Air" or ms == "Air crouch") and "Air"
            or ((ms == "Standing" or ms == "Crouching" or ms == "Fake duck") and "Stand" or "Move")
        if not allowed then
            if A.fs_item ~= item then
                N.ov.release_prefix("fs_states:")
                A.fs_item = item
            end
            N.ov.set_multi("fs_states", ref, item, false)
        elseif A.fs_item ~= nil then
            N.ov.release_prefix("fs_states:")
            A.fs_item = nil
        end
    end

    A.choked = function()
        local c = U.call(engine.get_choked_commands)
        return U.finite(c) and c or 0
    end

    -- Gonderilen pakette (choked == 0) bir kez; komut numarasi anahtar.
    A.update_flip = function(cmd, row, phase)
        if A.choked() ~= 0 then
            return
        end
        local F = A.flip
        local cmdn = cmd ~= nil and cmd.command_number or nil
        if cmdn ~= nil and cmdn == F.cmdn then
            return
        end
        F.cmdn = cmdn
        F.packets = F.packets + 1
        F.mstep = F.mstep + 1
        local body = N.bv(row, "body_yaw")
        local target = 1
        if body == 1 or body == 3 then
            target = (N.bv(row, "delay") or 1) + F.extra
        end
        if phase ~= nil and phase.asym ~= nil and F.side == (F.step % 8 < 4) then
            target = target + phase.asym
        end
        if F.packets < target then
            return
        end
        if body == 3 then
            F.side = random(0, 1) == 1
        else
            F.side = not F.side
        end
        F.packets = 0
        F.step = F.step + 1
        local spread = N.bv(row, "delay_random") or 0
        F.extra = spread >= 1 and random(0, floor(spread)) or 0
        F.yaw_n = random() * 2 - 1
        F.mod_n = random() * 2 - 1
        F.limit_n = random()
        F.rand_side = random(0, 1) == 1
    end

    A.modifier = function(mode, amount)
        local F = A.flip
        local m = abs(amount)
        if m < 1 or mode == 1 then
            return 0
        end
        if mode == 2 then
            return F.side and m / 2 or -m / 2
        elseif mode == 3 then
            return F.side and amount or 0
        elseif mode == 4 then
            return F.mod_n * m / 2
        elseif mode == 5 then
            return (U.tick() * 6) % (2 * m) - m
        elseif mode == 6 then
            local ways = { -m, 0, m }
            return ways[F.mstep % 3 + 1]
        elseif mode == 7 then
            local ways = { -m, -m / 2, 0, m / 2, m }
            return ways[F.mstep % 5 + 1]
        end
        return 0
    end

    -- Builder acilari (anti-brute fazi dahil). side: true = sag.
    A.angles = function(row, phase)
        local F = A.flip
        local body = N.bv(row, "body_yaw") or 1
        local yaw_side
        if body == 1 or body == 3 then
            yaw_side = F.side
        else
            yaw_side = N.ref.on("inverter")
        end
        local side = yaw_side
        local left, right = N.bv(row, "left_limit") or 58, N.bv(row, "right_limit") or 58
        local body_fs = N.bv(row, "body_fs") == 2
        if phase ~= nil then
            if phase.invert then
                side = not side
                if body ~= 1 and body ~= 3 then
                    yaw_side = side
                end
            end
            if phase.random then
                side = F.rand_side
            end
            if phase.freestand then
                body, body_fs = 2, true
            end
            left, right = U.R(left * phase.scale), U.R(right * phase.scale)
        end
        if body == 2 and body_fs and A.cover ~= nil then
            side = A.cover > 0
        end
        local cut = U.R(F.limit_n * (N.bv(row, "limit_random") or 0))
        left, right = max(0, left - cut), max(0, right - cut)
        local yaw
        if N.bv(row, "yaw_mode") == 2 then
            local ways = U.clamp(floor(N.bv(row, "ways") or 3), 3, 5)
            yaw = N.bv(row, "way" .. (F.step % ways + 1)) or 0
        elseif yaw_side then
            yaw = N.bv(row, "yaw_right") or 0
        else
            yaw = N.bv(row, "yaw_left") or 0
        end
        yaw = yaw + U.R(F.yaw_n * (N.bv(row, "yaw_random") or 0))
        if phase ~= nil then
            yaw = yaw + phase.shift
        end
        local modifier = N.bv(row, "modifier") or 1
        local amount = (N.bv(row, "mod_offset") or 0) + U.R(F.mod_n * (N.bv(row, "mod_random") or 0))
        yaw = yaw + A.modifier(modifier, amount)
        local mode = (body == 2 and body_fs) and "fs" or (body == 2 and "sta") or (body == 4 and "off") or "jit"
        return { body = body, side = side, left = left, right = right, yaw = yaw, mode = mode }
    end

    -- Bomba / rehine 100 birimde mi (legit AA'da E onlar icin).
    A.use_target_near = function(lp)
        local mine = U.origin(lp)
        if mine == nil then
            return false
        end
        for _, class in ipairs({ "CPlantedC4", "CHostage" }) do
            local ok, list = pcall(entity_list.get_entities_by_name, class)
            if ok and type(list) == "table" then
                for _, ent in ipairs(list) do
                    local o = U.origin(ent)
                    if o ~= nil and U.dist(o, mine) <= 100 then
                        return true
                    end
                end
            end
        end
        return false
    end

    -- 250 birimde, goz goze bicakli dusman.
    A.knife_enemy = function(range)
        local st = N.st
        local mine, eye = U.origin(st.lp), U.eye(st.lp)
        if mine == nil or eye == nil then
            return nil
        end
        local best, best_d = nil, range or 250
        for _, e in ipairs(N.exposure.enemies()) do
            if U.melee(U.winfo(e)) == "knife" then
                local o = U.origin(e)
                local d = o ~= nil and U.dist(o, mine) or huge
                if d <= best_d then
                    local their = U.eye(e) or o
                    local frac, hit = U.tline(eye, their, st.lp)
                    if frac >= 0.97 or hit == e then
                        best, best_d = e, d
                    end
                end
            end
        end
        return best, best_d
    end

    A.spin_active = function()
        if not N.on("spin") then
            return false
        end
        if N.on("spin_warmup") and U.game("m_bWarmupPeriod") == 1 then
            return true
        end
        if N.on("spin_enemies") and not N.st.any_enemy_alive then
            return true
        end
        return false
    end

    A.legit_active = function(cmd, lp)
        if not N.on("legit_use") or cmd == nil then
            return false
        end
        local ok, use = pcall(cmd.has_button, cmd, e_cmd_buttons.USE)
        if not ok or use ~= true then
            return false
        end
        return not A.use_target_near(lp)
    end

    A.desync = function(ctx, side, limit)
        local s = side and 1 or -1
        local value = A.sign_mul * s * U.clamp(limit, 0, 60) / 60
        pcall(ctx.set_desync, ctx, value)
        if A.cal.invert then
            pcall(ctx.set_invert_desync, ctx, not side)
        end
        return value
    end

    -- A12: gonderilen pakette, sadece onceki pakette de ayni isaret gonderildiyse (statik aralik) ornek.
    A.calibrate = function(value, standing)
        local C = A.cal
        if C.done then
            return
        end
        local real, fake = U.call(antiaim.get_real_angle), U.call(antiaim.get_fake_angle)
        if not U.finite(real) or not U.finite(fake) then
            C.nil_n = C.nil_n + 1
            if C.nil_n >= 32 then
                C.done = true
                N.log.line("aa: desync isareti olculemedi (olculemedi), + = sag varsayildi")
            end
            return
        end
        if not standing or value == 0 then
            C.prev = nil
            return
        end
        local sign = value > 0 and 1 or -1
        local stretch = C.prev == sign
        C.prev = sign
        if not stretch then
            return
        end
        local d = U.norm(real - fake)
        if abs(d) < 1 then
            return
        end
        C.n = C.n + 1
        if (d > 0) == (sign > 0) then
            C.agree = C.agree + 1
        end
        if C.n < 64 then
            return
        end
        local rate = C.agree / C.n
        if rate <= 0.2 then
            A.sign_mul = -A.sign_mul
            C.done = true
            N.log.line(fmt("aa: desync isareti olculdu (+ = %s) [%d/%d ters, cevrildi]", A.sign_mul > 0 and "sag" or "sol",
                C.n - C.agree, C.n))
        elseif rate >= 0.8 then
            C.done = true
            N.log.line(fmt("aa: desync isareti olculdu (+ = %s) [%d/%d uyumlu]", A.sign_mul > 0 and "sag" or "sol",
                C.agree, C.n))
        elseif C.phase == 1 then
            N.log.line(fmt("aa: desync isareti tutarsiz -> set_invert_desync de kullaniliyor [%d/%d uyumlu]", C.agree,
                C.n))
            C.phase, C.invert, C.n, C.agree, C.prev = 2, true, 0, 0, nil
        else
            C.done = true
            N.log.line(fmt("aa: desync isareti ikinci olcumde de tutarsiz (%d/%d), set_invert_desync acik kaldi",
                C.agree, C.n))
        end
    end

    -- Gizli pitch / yaw (sadece kendi defensive tick'lerimizde).
    A.hidden = function(state, base)
        local X = N.ex
        if not X.own_def_active() or X.clean or N.ui.xdef[state] == nil or N.ui.xdef[state].def_mode == nil then
            return nil, nil
        end
        local tick = U.tick()
        local hp = N.xv(state, "hidden_pitch") or 1
        local hy = N.xv(state, "hidden_yaw") or 1
        local pitch, yaw
        if hp == 2 then
            pitch = 89
        elseif hp == 3 then
            pitch = -89
        elseif hp == 4 then
            pitch = 0
        elseif hp == 5 then
            pitch = tick % 2 == 0 and 89 or -89
        elseif hp == 6 then
            pitch = random(-89, 89)
        elseif hp == 7 then
            pitch = N.xv(state, "hidden_pitch_value") or 0
        end
        if hy == 2 then
            yaw = base + (tick % 2 == 0 and 90 or -90)
        elseif hy == 3 then
            A.hspin = (A.hspin + (N.v("hidden_spin") or 10) * 6) % 360
            yaw = base + A.hspin
        elseif hy == 4 then
            yaw = base + random(-180, 180)
        elseif hy == 5 then
            yaw = base
        elseif hy == 6 then
            yaw = base + (N.xv(state, "hidden_yaw_value") or 90)
        end
        if pitch ~= nil or yaw ~= nil then
            X.hidden_tick = tick
        end
        return pitch, yaw
    end

    -- ANTIAIM ana fonksiyonu.
    A.apply = function(ctx, cmd)
        local st = N.st
        local lp = st.lp
        A.applied = 0
        if U.num(lp, "m_MoveType") == 9 then
            st.state, st.label = "Ladder", "Ladder"
            return
        end
        pcall(ctx.set_body_lean, ctx, 0)
        local view = A.view_yaw(cmd)
        local choked = A.choked()

        if A.legit_active(cmd, lp) then
            st.state, st.label = "Legit", "Legit"
            local okp, vx = pcall(function()
                return cmd.viewangles.x
            end)
            if okp and U.finite(vx) then
                pcall(ctx.set_pitch, ctx, vx)
            end
            pcall(ctx.set_yaw, ctx, U.norm(view))
            local side = N.ref.on("inverter")
            A.desync(ctx, side, 60)
            A.last.side, A.last.limit, A.last.body = side, 60, "sta"
            return
        end

        if A.spin_active() then
            st.state, st.label = "Spin", "Spin"
            local cmdn = cmd ~= nil and cmd.command_number or nil
            if cmdn == nil or cmdn ~= A.spin_cmdn then
                A.spin_cmdn = cmdn
                A.spin_angle = (A.spin_angle + (N.v("spin_speed") or 6) * 6) % 360
            end
            if N.v("spin_pitch") == 2 then
                pcall(ctx.set_pitch, ctx, 89)
            end
            pcall(ctx.set_yaw, ctx, U.norm(view + A.spin_angle))
            return
        end

        local state = st.state
        local row = A.row(state)
        local B = N.brute
        local phase_n = 0
        if N.on("anti_brute") and not K.UNLEARNED[state] then
            phase_n = B.stage_for(A.target(), st.move_state)
        end
        A.applied = phase_n
        local phase = phase_n > 0 and K.BRUTE_PHASES[phase_n] or nil
        A.update_flip(cmd, row, phase)
        local a = A.angles(row, phase)

        local base, target = A.base(cmd)
        A.facing = target
        local yaw = nil
        if state == "Manual" then
            yaw = base + 180 + (A.MANUAL[st.manual] or 0) + a.yaw
        else
            local knife, dist = nil, nil
            if N.on("avoid_backstab") then
                knife, dist = A.knife_enemy(250)
            end
            st.backstab = knife
            if knife ~= nil then
                local mine, theirs = U.origin(lp), U.origin(knife)
                if mine ~= nil and theirs ~= nil then
                    yaw = U.yaw_to(mine, theirs)
                    A.facing = knife
                    N.log.every("backstab", 5, fmt("backstab: %s bicakli, %d birimde -> yuz ona", U.name(knife),
                        U.R(dist)))
                end
            elseif state == "Freestanding" and st.fs_own ~= nil then
                yaw = base + 90 * st.fs_own + a.yaw
            elseif state == "Freestanding" then
                yaw = nil
            else
                yaw = base + 180 + a.yaw
            end
        end

        -- Pitch: ayar (Down / Zero / Off), Safe head 89, defensive tick'inde gizli pitch.
        local pitch = nil
        local pm = N.v("pitch") or 1
        if pm == 1 then
            pitch = 89
        elseif pm == 2 then
            pitch = 0
        end
        if state == "Safe head" then
            pitch = 89
        end
        local hp, hy = A.hidden(state, base)
        if hp ~= nil then
            pitch = hp
        end
        if hy ~= nil then
            yaw = hy
        end
        if pitch ~= nil then
            pcall(ctx.set_pitch, ctx, pitch)
        end
        if yaw ~= nil then
            yaw = U.norm(yaw)
            pcall(ctx.set_yaw, ctx, yaw)
            A.last.yaw = yaw
        end

        local value = 0
        if a.body == 4 then
            pcall(ctx.set_desync, ctx, 0)
        else
            local limit = a.side and a.right or a.left
            value = A.desync(ctx, a.side, limit)
            A.last.limit = limit
        end
        A.last.side, A.last.body, A.last.phase = a.side, a.mode, phase_n
        if choked == 0 then
            A.calibrate(value, st.move_state == "Standing")
        end
        -- Fake duck'ta bicakli yakin: script fake duck'i birakamaz, ipucu.
        if st.fd then
            local knife, dist = A.knife_enemy(250)
            if knife ~= nil then
                st.fd_hint_until = U.now() + 2
                N.log.every("fd_knife", 5, fmt("fake duck: %s bicakli, %d birimde -> fake duck'i birak",
                    U.name(knife), U.R(dist)))
            end
        end
    end

    -- A19: egik yururken gorulursen tehdide dogru giden komut "Crouch speed"e kadar kisilir (GS birimi:
    -- egik hareket = komutun 0.34'u).
    A.crouch_keeper = function(cmd)
        local st = N.st
        st.slowed = false
        if not N.on("crouch_cap") or cmd == nil or st.airborne or st.fd or N.peek.mode ~= nil or N.afk.on
            or N.ref.on("autopeek") or U.num(st.lp, "m_MoveType") == 9 then
            return
        end
        if not (N.exposure.now or N.exposure.soon or N.exposure.seen) then
            return
        end
        if U.now() - st.last_shot < 0.6 and U.now() >= st.last_shot then
            return
        end
        local duck = st.duck or 0
        if duck < 0.9 then
            return
        end
        local ok, mx, my = pcall(function()
            return cmd.move.x, cmd.move.y
        end)
        if not ok or not U.finite(mx) or not U.finite(my) then
            return
        end
        local m = sqrt(mx * mx + my * my)
        if m < 1 then
            return
        end
        local threat = st.threat
        local mine, theirs = U.origin(st.lp), threat ~= nil and U.origin(threat) or nil
        if mine == nil or theirs == nil then
            return
        end
        local yaw = A.view_yaw(cmd)
        local cx, sy = U.dir(yaw)
        -- Dunya yonu: ileri (cos, sin), sag (sin, -cos); cmd.move.y pozitif = sag (isaret P2'de olculur).
        local side = my * (N.peek.side_mul or 1)
        local wx = mx * cx + side * sy
        local wy = mx * sy - side * cx
        if wx * (theirs.x - mine.x) + wy * (theirs.y - mine.y) < 0 then
            return
        end
        local lim = (N.v("crouch_speed") or 38) / 0.34
        if m > lim then
            local k = lim / m
            pcall(function()
                cmd.move = vec3_t(mx * k, my * k, 0)
            end)
            st.slowed = true
        end
    end
end

-------------------------------------------------------------------------------
-- Anti-brute: kafamin 40 birim yakinindan gecen dusman mermisi fazi ilerletir; hareket grubu basina faz
-- ogrenmesi (kafa isabeti / mermi), kotu bilinen faz atlanir, dusman basina kalici taban.
-------------------------------------------------------------------------------
do
    local U, B = N.util, N.brute
    local K = N.K
    B.enemies, B.phases, B.default, B.pending, B.hurt = {}, {}, {}, {}, {}
    B.bad_shots, B.bad_rate = 12, 0.55

    B.reset_phases = function()
        for _, g in ipairs(K.BRUTE_GROUPS) do
            B.phases[g], B.default[g] = {}, 0
            for phase = 0, #K.BRUTE_PHASES do
                B.phases[g][phase] = { shots = 0, hits = 0 }
            end
        end
    end
    B.reset_phases()

    B.group_for = function(ms)
        return K.GROUP_OF[ms] or "still"
    end

    B.stat_group = function()
        if K.UNLEARNED[N.st.state] then
            return nil
        end
        return B.group_for(N.st.move_state)
    end

    B.phase_rate = function(stat)
        return (stat.hits + 2.4) / (stat.shots + 8)
    end

    B.best_default = function(g)
        local list, current = B.phases[g], B.default[g] or 0
        local best, best_rate = 0, huge
        for phase = 0, #K.BRUTE_PHASES do
            local rate = B.phase_rate(list[phase])
            if rate < best_rate - 1e-9 then
                best, best_rate = phase, rate
            end
        end
        if best ~= current and best_rate < B.phase_rate(list[current]) - 0.1 - 1e-9 then
            return best
        end
        return current
    end

    B.count = function(stat, hit)
        stat.shots = stat.shots + 1
        if hit then
            stat.hits = stat.hits + 1
        end
        if stat.shots > 40 then
            stat.shots, stat.hits = stat.shots / 2, stat.hits / 2
        end
        N.mem.dirty = true
    end

    B.record_phase = function(g, phase, hit)
        local list = g ~= nil and B.phases[g] or nil
        if list == nil or list[phase] == nil then
            return
        end
        B.count(list[phase], hit)
        local previous = B.default[g]
        local best = B.best_default(g)
        if best ~= previous then
            B.default[g] = best
            if N.on("hit_log") then
                local chosen, left = list[best], list[previous]
                N.log.line(fmt("AA (%s): faz %d cok kafa yiyor (%d/%d kafa isabeti) -> verisi olmayan dusmanlara faz %d%s",
                    g, previous, U.R(left.hits), U.R(left.shots), best, chosen.shots < 0.5 and " (denenmemis)" or ""))
            end
        end
    end

    B.known_bad = function(g, phase)
        local list = B.phases[g]
        local stat = list ~= nil and list[phase] or nil
        return stat ~= nil and stat.shots >= B.bad_shots and stat.hits / stat.shots >= B.bad_rate
    end

    -- Siradaki faz: rastgele (su anki haric) ya da +1.
    B.next = function(current, allow_zero)
        local n = #K.BRUTE_PHASES
        if not N.on("brute_random") then
            return allow_zero and (current + 1) % (n + 1) or current % n + 1
        end
        local low = allow_zero and 0 or 1
        local inside = current >= low and current <= n
        local pick = random(low, inside and (n - 1) or n)
        if inside and pick >= current then
            pick = pick + 1
        end
        return pick
    end

    B.skip_bad = function(g, phase)
        for _ = 0, #K.BRUTE_PHASES do
            if not B.known_bad(g, phase) then
                return phase
            end
            phase = (phase + 1) % (#K.BRUTE_PHASES + 1)
        end
        return phase
    end

    B.entry = function(ent)
        local p, key = N.mem.entry(ent)
        if key == nil then
            return nil
        end
        local e = B.enemies[key]
        if e == nil then
            e = { stage = 0, time = -1000, last = -1000, base = p ~= nil and p.base or nil }
            e.learned = e.base ~= nil
            B.enemies[key] = e
        end
        e.mem = p
        return e, key
    end

    B.entry_stage = function(e, g)
        if e == nil then
            return B.default[g] or 0
        end
        local now = U.now()
        local reset = N.v("brute_reset") or 6
        if e.stage > 0 and now >= e.time and now - e.time <= reset then
            return B.skip_bad(g, e.stage)
        end
        if e.learned and e.base ~= nil then
            return B.skip_bad(g, e.base)
        end
        return B.default[g] or 0
    end

    -- AA hedefinin (ya da hedef yoksa grup varsayilaninin) fazi.
    B.stage_for = function(target, ms)
        local g = B.group_for(ms)
        if target == nil then
            return B.default[g] or 0
        end
        local e = B.entry(target)
        return B.entry_stage(e, g)
    end

    -- bullet_impact: atan dusman, kafama < 40 birim, atan basina 0.1 sn tekrar korumasi.
    B.impact = function(e)
        local st = N.st
        local lp = st.lp
        if lp == nil or not st.alive then
            return
        end
        local okp, shooter = pcall(entity_list.get_player_from_userid, e.userid)
        if not okp or shooter == nil or shooter == lp or not U.is_enemy(shooter) or not U.alive(shooter) then
            return
        end
        local x, y, z = tonumber(e.x), tonumber(e.y), tonumber(e.z)
        if not U.finite(x) or not U.finite(y) or not U.finite(z) then
            return
        end
        local entry, key = B.entry(shooter)
        if entry == nil then
            return
        end
        local now = U.now()
        if now >= entry.last and now - entry.last < K.BRUTE_DEBOUNCE then
            return
        end
        local head, eye = U.hitbox(lp, "HEAD"), U.eye(shooter)
        if head == nil or eye == nil then
            return
        end
        if U.seg_dist(head, eye, { x = x, y = y, z = z }) >= K.BRUTE_RADIUS then
            return
        end
        entry.last = now
        entry.counted = nil
        local idx = U.index(shooter)
        if idx ~= nil then
            N.track.get(idx).shot_us = now
        end
        local g = B.stat_group()
        local shot_stage = N.on("anti_brute") and B.entry_stage(entry, g or B.group_for(st.move_state)) or 0
        entry.shot_stage, entry.shot_applied, entry.shot_group = shot_stage, N.aa.applied, g
        local hurt = B.hurt[e.userid]
        if hurt == nil or now < hurt or now - hurt >= K.MISS_WINDOW then
            B.pending[#B.pending + 1] = {
                userid = e.userid, time = now, state = st.label, stage = shot_stage, applied = N.aa.applied,
                group = g, name = U.name(shooter), aa = N.shots.aa_status(), exploit = N.shots.exploit_status(),
                weapon = U.wlabel(st.weapon), attacker = N.shots.attacker_info(shooter),
                enemy_weapon = (U.winfo(shooter) or { name = "?" }).name,
            }
        end
        if not N.on("anti_brute") then
            return
        end
        entry.stage = B.next(shot_stage, false)
        entry.time = now
        if N.on("brute_log") then
            N.log.line(fmt("anti-brute: %s faz %d", U.name(shooter), entry.stage))
        end
    end

    -- 0.15 sn icinde hasar gelmeyen mermi = iska.
    B.process_pending = function()
        local now = U.now()
        for i = #B.pending, 1, -1 do
            local m = B.pending[i]
            if now < m.time or now - m.time > K.MISS_WINDOW then
                tremove(B.pending, i)
                if now >= m.time then
                    N.stats.enemy_miss(m.state)
                    if m.group ~= nil then
                        B.record_phase(m.group, m.applied, false)
                    end
                    if N.on("hit_log") then
                        N.log.line(fmt("iska: %s | faz %d%s | %s | %s | %s | %s (%s) | silah %s", m.state, m.applied,
                            m.applied ~= m.stage and fmt(" (dusmanin %d)", m.stage) or "", m.aa, m.exploit, m.weapon,
                            m.name, m.attacker, tostring(m.enemy_weapon)))
                    end
                end
            end
        end
    end

    -- Bana isabet: eslesen mermi varsa uygulanan faz ogrenilir; kafa isabeti dusmanin tabanini tasir.
    B.hurt_us = function(e, attacker, hitgroup)
        local now = U.now()
        B.hurt[e.attacker] = now
        for i = #B.pending, 1, -1 do
            if B.pending[i].userid == e.attacker then
                tremove(B.pending, i)
            end
        end
        local entry = B.entry(attacker)
        local phase, g, matched
        if entry ~= nil and entry.shot_applied ~= nil and now >= entry.last and now - entry.last < K.MISS_WINDOW then
            matched = true
            phase, g = entry.shot_applied, entry.shot_group
        else
            phase, g = N.aa.applied, B.stat_group()
        end
        local weapon = tostring(e.weapon or "?")
        local melee = weapon:find("knife", 1, true) ~= nil or weapon == "bayonet" or weapon == "taser"
        if hitgroup == 1 and not melee and N.on("anti_brute") and not K.UNLEARNED[N.st.state] and entry ~= nil then
            entry.base, entry.learned = B.next(phase or 0, true), true
            if entry.mem ~= nil then
                entry.mem.base = entry.base
                N.mem.dirty = true
            end
        end
        if not melee and g ~= nil then
            if hitgroup == 1 then
                B.record_phase(g, phase or 0, true)
                if matched then
                    entry.counted = true
                end
            elseif matched and not entry.counted and hitgroup ~= 0 then
                entry.counted = true
                B.record_phase(g, phase or 0, false)
            end
        end
        return phase or 0, melee
    end
end

-------------------------------------------------------------------------------
-- Exploitler: defensive karari (Off / On peek / Smart / Always on / Tick based), re-arm cooldown, anti-peek,
-- silah degisimi / bicak, havada air lag, temiz atis, havada teleport + Air LC, teleport sonucu, safe
-- recharge, bozuk atis korumasi, fakelag.
-------------------------------------------------------------------------------
do
    local U, X = N.util, N.ex
    X.has_shift = false
    X.shift_tick, X.own_def_until, X.last_sim, X.def_was, X.def_end = -1, -1, nil, false, -1000
    X.forced, X.forced_tick, X.scan_tick, X.anti_until, X.smart_hold = false, -1000, -1000, -1000, -1000
    X.clean, X.shot_tick, X.after_shot = false, -1000, false
    X.hidden_tick = -1000
    X.switch = { name = nil, at = -1000 }
    X.air = { was_air = false, used = false, latched = false, takeoff_z = 0, left = 0, calls = 0, maxchoke = 0,
        pending_log = false, map_logged = false }
    X.tp = { list = {}, map_off = false, n = 0, last = -1000 }
    X.broken = { DEF = {}, LC = {}, TP = {}, paused = {} }
    X.safe = { holding = false, since = -1000, want_at = -1000, no_hold = nil, handled_at = -1000 }
    X.dt_warn_round = -1
    X.aim = { target = nil, time = -1000 }

    X.init = function()
        -- API §16.4: sadece uyeye bakilir (namespace userdata da olabilir; fonksiyon ya da cagrilabilir userdata).
        local ok, f = pcall(function()
            return exploits.force_anti_exploit_shift
        end)
        X.has_shift = ok and f ~= nil and f ~= false
    end

    -- NET_UPDATE: kendi simulasyon zamanimiz geri gittiyse defensive acik (MS:1262-1290).
    X.own_update = function()
        local lp = N.st.lp
        local simt = U.num(lp, "m_flSimulationTime")
        if simt == nil then
            return
        end
        local okt, sim = pcall(client.time_to_ticks, simt)
        if not okt or not U.finite(sim) then
            sim = floor(simt / U.ipt() + 0.5)
        end
        local tick = U.tick()
        if X.last_sim ~= nil and sim < X.last_sim then
            X.own_def_until = tick + min(16, X.last_sim - sim)
        end
        X.last_sim = sim
    end

    X.own_def_active = function()
        local tick = U.tick()
        return tick <= X.own_def_until and tick >= X.own_def_until - 20
    end

    X.paused = function(lag)
        local untilt = X.broken.paused[lag]
        local now = U.now()
        return untilt ~= nil and now < untilt and now >= untilt - 10
    end

    -- Tek tetik: tick basina en fazla bir force_anti_exploit_shift (sadece DT dolu iken).
    X.shift = function(why)
        local tick = U.tick()
        if X.shift_tick == tick then
            return true
        end
        if not X.has_shift or X.paused("DEF") then
            return false
        end
        if not N.ref.on("dt") then
            X.dt_warning()
            return false
        end
        -- DT'li ucusta (inis teleportu) defensive zorlanmaz: sarj teleporta kalir (GS V1.0.80 current.air_dt).
        if not N.ref.dt_ready() or X.clean or N.st.fd or X.air.latched or X.land.flight then
            return false
        end
        local ok = pcall(exploits.force_anti_exploit_shift)
        if ok then
            X.shift_tick, X.forced, X.forced_tick, X.forced_why = tick, true, tick, why
        end
        return ok
    end

    X.dt_warning = function()
        local round = N.stats.round_no or 0
        if X.dt_warn_round ~= round then
            X.dt_warn_round = round
            N.log.line("UYARI: DT kapali (cfg'de DT her zaman acik olmali)")
        end
    end

    X.mode_for = function(state)
        if N.ui.xdef[state] == nil or N.ui.xdef[state].def_mode == nil then
            return 1
        end
        return N.xv(state, "def_mode") or 1
    end

    -- Silah degisimi: aktif silah adi son 0.5 sn icinde degisti ya da m_flNextAttack ileride.
    X.switching = function()
        local st = N.st
        local now = U.now()
        local name = st.weapon
        if name ~= X.switch.name then
            if X.switch.name ~= nil then
                X.switch.at = now
            end
            X.switch.name = name
        end
        if now >= X.switch.at and now - X.switch.at <= 0.5 then
            return true
        end
        local nxt = U.num(st.lp, "m_flNextAttack")
        return nxt ~= nil and nxt > U.cur() and nxt - U.cur() < 2
    end

    -- SETUP_COMMAND: defensive karari.
    X.defensive = function()
        local st, E = N.st, N.exposure
        local tick = U.tick()
        local now = U.now()
        X.forced = X.forced_tick == tick
        -- Kendi defensive bitis zamani (re-arm cooldown icin).
        local def = X.own_def_active()
        if X.def_was and not def then
            X.def_end = now
        end
        X.def_was = def
        if not X.has_shift then
            return
        end
        local state = st.state
        local mode = X.mode_for(state)
        local switching = X.switching()
        local knife = N.on("backstab_def") and N.on("avoid_backstab") and N.aa.knife_enemy(250) ~= nil
        if E.now then
            X.smart_hold = tick + 8
        end
        -- X5: yeni goren dusman (ilk gorus) ya da goren dusman hizli -> 8 tick zorla.
        if N.on("anti_peek") then
            local fast = false
            for _, enemy in ipairs(E.enemies()) do
                local idx = U.index(enemy)
                if idx ~= nil and E.sees_now(idx) and U.speed(enemy) > 150 then
                    fast = true
                end
            end
            if E.first_sight_within(2) or fast then
                X.anti_until = tick + 8
            end
        end
        local anti = tick <= X.anti_until and tick >= X.anti_until - 8
        local onpeek = (tick - X.scan_tick <= 1 and tick >= X.scan_tick) or anti
        local want, why = false, nil
        if mode == 2 then
            want, why = onpeek, "peek"
        elseif mode == 3 then
            if onpeek then
                want, why = true, "peek"
            elseif N.on("smart_force") and (E.now or E.seen or E.near
                or (tick <= X.smart_hold and tick >= X.smart_hold - 8)) then
                want, why = true, "smart"
                -- X4: defensive bittikten sonra gorulurken 1 sn yeniden zorlama yok (DT dolsun).
                if N.on("def_cooldown") and E.seen and now >= X.def_end and now - X.def_end < 1
                    and not st.airborne and N.peek.mode == nil and not switching and not knife and not N.afk.on then
                    want = false
                end
            end
        elseif mode == 4 then
            want, why = true, "always"
        elseif mode == 5 then
            local every = max(2, floor(N.xv(state, "def_ticks") or 14))
            want, why = tick % every == 0, "tick"
        end
        if mode ~= 1 then
            if N.on("switch_def") and switching then
                want, why = true, "switch"
            end
            if knife then
                want, why = true, "knife"
            end
        end
        -- X14 (GS: air_lag sadece Smart penceresini genisletir): havada, gorulmuyorken her tick; gorulurken havayi
        -- Air LC yonetir; DT'li ucusta (inis teleportu) ve merdivende yok.
        if mode == 3 and N.on("air_lag") and st.airborne and not st.ladder and not X.land.flight
            and not (E.now or E.soon) then
            want, why = true, "air"
        end
        if N.on("peek_defensive") and N.peek.mode == "walk" then
            want, why = true, "aipeek"
        end
        if N.afk.on then
            want, why = true, "afk"
        end
        if want then
            X.shift(why)
        end
    end

    -- HITSCAN: ragebot bir hedefi tariyor = peek (MS:4374).
    X.onpeek_trigger = function()
        local tick = U.tick()
        X.scan_tick = tick
        local mode = X.mode_for(N.st.state)
        if mode == 2 or mode == 3 then
            X.shift("peek")
        end
    end

    -- X8: silah hazir ve hedefin kafasina / gogsune / midesine yeterli mermi geciyor = temiz atis (lag yok).
    X.clean_update = function()
        local st = N.st
        local tick = U.tick()
        X.clean = false
        if not N.on("clean_shot") then
            return
        end
        if tick - X.shot_tick <= 6 and tick >= X.shot_tick then
            X.clean, X.clean_src = true, "atis"
            return
        end
        if st.fd or not U.is_gun(st.winfo) then
            return
        end
        local can = U.call(client.can_fire)
        if can ~= true then
            return
        end
        local now = U.now()
        local target = X.aim.target
        if target ~= nil and (now < X.aim.time or now - X.aim.time > N.K.AIM_TARGET_HOLD) then
            X.aim = { target = nil, time = -1000 }
            target = nil
        end
        if target == nil or not U.alive(target) then
            target = st.threat
        end
        if target == nil then
            return
        end
        local eye = U.eye(st.lp)
        local hp = U.hp(target)
        local need = N.ref.md_need(hp, st.wgroup) or hp
        local head = U.hitbox(target, "HEAD")
        if eye == nil or head == nil then
            return
        end
        local yaw = U.yaw_to(eye, head) + 90
        local points = { head, U.offset(head, yaw, 3, 0), U.offset(head, yaw, -3, 0), U.hitbox(target, "CHEST"),
            U.hitbox(target, "PELVIS") }
        for _, p in ipairs(points) do
            if p ~= nil and U.tdmg(eye, p, st.lp, target) >= need then
                X.clean, X.clean_src = true, "iz"
                X.clean_target = target
                return
            end
        end
    end

    -- ANTIAIM: temiz atista / atistan sonraki ilk ANTIAIM'de paket hemen; havada Air LC'de tam choke.
    X.fakelag = function(ctx)
        if X.clean or X.after_shot then
            X.after_shot = false
            pcall(ctx.set_fakelag, ctx, false)
            return
        end
        if X.air.latched and N.st.airborne and not N.st.ladder then
            pcall(ctx.set_fakelag, ctx, true)
        end
    end

    X.time_to_land = function(lp)
        local o = U.origin(lp)
        if o == nil then
            return 0
        end
        local v = U.vel(lp)
        local g = 800
        local okc, c = pcall(function()
            return cvars.sv_gravity
        end)
        if okc and c ~= nil then
            local okg, gv = pcall(c.get_float, c)
            if okg and U.finite(gv) and gv > 0 then
                g = gv
            end
        end
        local h = o.z - X.air.takeoff_z
        local disc = v.z * v.z + 2 * g * h
        if disc < 0 then
            return 0
        end
        return max(0, (v.z + sqrt(disc)) / g)
    end

    X.do_teleport = function(kind)
        local A = X.air
        U.call(exploits.force_uncharge)
        A.used, A.left, A.calls, A.pending_log = true, 3, 1, true
        -- Inis teleportunda kilit yok: sarj yerde zaten dolacak (GS V1.0.80 recharge.decide).
        if kind ~= "inis" then
            N.rc.block("air")
        end
        local T = X.tp
        T.n, T.last = T.n + 1, U.now()
        T.kind = kind
        T.list[#T.list + 1] = { time = T.last, hit = false, done = false }
        while #T.list > 3 do
            tremove(T.list, 1)
        end
        X.finish_uncharge(false)
    end

    -- Sarj 0 olana kadar (en fazla 4 cagri) force_uncharge; bitince tek satir.
    X.finish_uncharge = function(continue)
        local A = X.air
        if not A.pending_log then
            return
        end
        local c = N.ref.charge()
        if continue and c > 0 and A.left > 0 then
            U.call(exploits.force_uncharge)
            A.left, A.calls = A.left - 1, A.calls + 1
            return
        end
        if c > 0 and A.left > 0 and not continue then
            return
        end
        A.pending_log = false
        A.left = 0
        if X.tp.kind == "inis" then
            N.log.line(fmt("teleport: inis teleportu bitti (%d. kez, uncharge %d tick)", X.tp.n, A.calls))
            return
        end
        N.log.line(fmt("teleport: havada goruldun, DT ile isinlanildi (%d. kez, uncharge %d tick%s)", X.tp.n, A.calls,
            X.tp.kind == "lc" and ", air lc" or ""))
    end

    -- V1.0.80 (GS teleport.plan / land_fire): "Teleport in air" + "Air: break LC" acik ve DT acikken havada DT hic
    -- bosaltilmaz, Air LC kilidi yok; sarj inise saklanir ve tek teleport inise 1..(max sarj - 3) tick kala atilir
    -- (yedek: yerde 1. tick), boylece teleport seni dogrudan yere indirir. Teleport tick'inde ve sonraki 2 tick'te
    -- ziplama bastirilir. Ucusta (kalkistan yerde 2. tick'e kadar) defensive zorlanmaz. Biri kapaliyken eski yol (X10/X11).
    X.land = { policy = false, flight = false, fired = false, gt = 64, lt = nil, h = nil, seen_at = -1000,
        seen_flight = false, nojump_until = -1000, reason = nil, margin = 3, seen_hold = 24, min_d3 = 64 }
    X.CORNERS = { 0, 0, 15, 15, 15, -15, -15, 15, -15, -15 }

    X.land_reset = function()
        local L = X.land
        L.flight, L.fired, L.gt, L.lt, L.h, L.reason = false, false, 64, nil, nil, nil
        L.seen_at, L.seen_flight, L.nojump_until = -1000, false, -1000
    end

    X.gravity = function()
        local okc, c = pcall(function()
            return cvars.sv_gravity
        end)
        if okc and c ~= nil then
            local okg, gv = pcall(c.get_float, c)
            if okg and U.finite(gv) and gv > 0 then
                return gv
            end
        end
        return 800
    end

    -- (x, y) altindaki en yuksek zemin: 5 dikey trace.line (orta + 15 birim koseler); hic carpmazsa nil.
    X.floor_at = function(lp, x, y, top, bottom)
        local best, c = nil, X.CORNERS
        for i = 1, #c, 2 do
            local f = U.tline(vec3_t(x + c[i], y + c[i + 1], top), vec3_t(x + c[i], y + c[i + 1], bottom), lp)
            if f > 0 and f < 1 then
                local hz = top - (top - bottom) * f
                if best == nil or hz > best then
                    best = hz
                end
            end
        end
        return best
    end

    X.fall_ticks = function(oz, vz, fz, g, ti)
        local h = max(0, oz - fz - 2)
        local t = (vz + sqrt(max(0, vz * vz + 2 * g * h))) / g
        return max(0, math.ceil(t / ti - 1e-3)), h
    end

    -- Inise kac tick kaldi ve dusulecek yukseklik; 32 tick'ten az kaldiysa inis noktasinin altina da bakilir (orada
    -- zemin yoksa = ucurum, tahmin yok). nil = bilinmiyor.
    X.land_ticks = function(lp)
        local o = U.origin(lp)
        if o == nil then
            return nil
        end
        local v = U.vel(lp)
        local g, ti = X.gravity(), U.ipt()
        local top = o.z + 2 + (v.z > 0 and v.z * v.z / (2 * g) or 0)
        local bottom = o.z - 512
        local fz = X.floor_at(lp, o.x, o.y, top, bottom)
        if fz == nil then
            return nil
        end
        local k, h = X.fall_ticks(o.z, v.z, fz, g, ti)
        if k <= 32 then
            local fz2 = X.floor_at(lp, o.x + v.x * k * ti, o.y + v.y * k * ti, top, bottom)
            if fz2 == nil then
                return nil
            end
            k, h = X.fall_ticks(o.z, v.z, fz2, g, ti)
        end
        return k, h
    end

    -- Tek inis teleportu. Sira: pencere / gorulme / temiz atis / durdurma / sarj / 3D mesafe.
    X.land_fire = function(cmd, lp, lt, h)
        local L, E = X.land, N.exposure
        if L.fired then
            return
        end
        local c, m = N.ref.charge()
        local S = max(1, m)
        local eligible = (L.gt == 0 and lt ~= nil and lt >= 1 and lt <= S - L.margin) or L.gt == 1
        if not eligible then
            if lt == nil and L.gt == 0 then
                L.reason = "tahmin yok"
            end
            return
        end
        local tick = U.tick()
        local since = tick - L.seen_at
        if not (E.now or E.soon or (since >= 0 and since <= L.seen_hold)) then
            L.reason = "gorulmedi"
            return
        end
        if X.clean then
            L.reason = "temiz atis"
            return
        end
        if X.paused("TP") or X.tp.map_off then
            L.reason = "durduruldu"
            return
        end
        if not N.ref.on("dt") or c < 1 then
            L.reason = fmt("sarj %d/%d", U.R(c), U.R(m))
            return
        end
        local d2 = U.speed(lp) * (S + 1) * U.ipt()
        local hz = h or 0
        local d3 = sqrt(d2 * d2 + hz * hz)
        if d3 < L.min_d3 then
            L.reason = fmt("yavas 3D %d u", U.R(d3))
            return
        end
        L.fired, L.reason = true, nil
        L.nojump_until = tick + 2
        if cmd ~= nil then
            pcall(cmd.remove_button, cmd, e_cmd_buttons.JUMP)
        end
        local left = L.gt == 1 and 0 or lt
        N.log.line(fmt("teleport: inise %d tick kala (S %d, hiz %d, 2D %d / 3D %d u, h %d)%s", left, S,
            U.R(U.speed(lp)), U.R(d2), U.R(d3), U.R(hz), d3 > 64 and " LC kirilir(3D)" or ""))
        X.do_teleport("inis")
    end

    -- Her SETUP_COMMAND: politika, gorulme, inis tahmini, inis teleportu.
    X.land_update = function(cmd, lp)
        local L, st, E = X.land, N.st, N.exposure
        local tick = U.tick()
        local nj = L.nojump_until - tick
        if cmd ~= nil and nj >= 0 and nj <= 2 then
            pcall(cmd.remove_button, cmd, e_cmd_buttons.JUMP)
        end
        if E.now or E.soon then
            L.seen_at = tick
        end
        L.policy = N.on("air_lc") and N.on("air_teleport") and N.ref.on("dt") and not N.afk.on and not st.fd
            and not st.ladder
        L.lt, L.h = nil, nil
        if U.flag(lp, "ON_GROUND") ~= false or st.ladder then
            L.gt = min(L.gt + 1, 64)
            if L.flight and L.gt == 1 then
                X.land_fire(cmd, lp, nil, 0)
            end
            if L.flight and L.gt >= 3 then
                if not L.fired and L.seen_flight and L.reason ~= nil then
                    N.log.line("teleport: inise yok (" .. L.reason .. ")")
                end
                L.flight = false
            end
            return
        end
        if L.gt > 0 then
            -- Kalkis (bhop'ta da yeni ucus).
            L.fired, L.reason, L.seen_flight = false, nil, false
        end
        L.gt = 0
        L.flight = L.policy
        if not L.flight then
            return
        end
        if E.now or E.soon then
            L.seen_flight = true
        end
        L.lt, L.h = X.land_ticks(lp)
        X.land_fire(cmd, lp, L.lt, L.h)
    end

    -- X10 / X11: havada teleport (atlayis basina bir) ve Air LC kilidi (inise kadar sarj yok + tam fakelag).
    -- DT'li ucusta (X.land.flight) ikisi de yok; merdiven hava sayilmaz.
    X.air_update = function(cmd)
        local st, E, A = N.st, N.exposure, X.air
        local lp = st.lp
        X.land_update(cmd, lp)
        if not st.airborne or st.ladder then
            if A.was_air then
                A.was_air = false
                if A.latched and N.on("debug_log") then
                    N.log.line(fmt("dbg air lc: choke max %d", U.R(A.maxchoke)))
                end
                if A.pending_log then
                    A.left = 0
                    X.finish_uncharge(false)
                end
                A.used, A.latched, A.left = false, false, 0
                N.rc.allow("air")
            elseif A.pending_log then
                -- Yerde 1. tick yedek inis teleportu: tekrar cagrilar yerde de surer.
                X.finish_uncharge(true)
            end
            return
        end
        if not A.was_air then
            A.was_air = true
            local o = U.origin(lp)
            A.takeoff_z = o ~= nil and o.z or 0
            A.used, A.latched, A.maxchoke, A.calls = false, false, 0, 0
        end
        A.maxchoke = max(A.maxchoke, N.aa.choked())
        if A.pending_log then
            X.finish_uncharge(true)
        end
        if X.land.flight then
            if A.latched then
                A.latched = false
                N.rc.allow("air")
            end
            return
        end
        local seen = E.now or E.soon
        local blocked = X.clean or st.fd or st.melee == "knife" or X.tp.map_off
        local tp_ok = not A.used and N.ref.on("dt") and N.ref.charge() > 0 and not blocked and not X.paused("TP")
            and X.time_to_land(lp) >= 0.35
        if N.on("air_lc") and not A.latched and seen and not X.clean and not X.paused("LC") then
            if X.tp.map_off then
                if not A.map_logged then
                    A.map_logged = true
                    N.log.line("air lc: bu harita teleport kapali -> air lc yok")
                end
            else
                A.latched = true
                if tp_ok then
                    X.do_teleport("lc")
                end
                N.rc.block("air")
            end
        elseif N.on("air_teleport") and seen and tp_ok and N.ref.dt_ready() then
            X.do_teleport("tp")
        end
        if A.latched then
            N.rc.block("air")
        end
    end

    -- X12: teleporttan 0.12-1.5 sn sonra vurulduysan "vuruldu"; haritada son 3'un 2'si -> harita boyunca kapali.
    X.tp_hurt = function(hitgroup)
        local now = U.now()
        local T = X.tp
        for _, item in ipairs(T.list) do
            local dt = now - item.time
            if not item.done and dt >= 0.12 and dt <= 1.5 then
                item.hit, item.done = true, true
                N.log.line(fmt("teleport sonucu: %.2f sn sonra vuruldun (%s)", dt, N.K.HITGROUPS[hitgroup] or "?"))
            end
        end
        X.tp_check()
    end

    X.tp_check = function()
        local now = U.now()
        local T = X.tp
        local hits, done = 0, 0
        for _, item in ipairs(T.list) do
            if not item.done and now - item.time > 1.5 then
                item.done = true
                if N.on("debug_log") then
                    N.log.line("teleport sonucu: 1.5 sn icinde vurulmadin")
                end
            end
            if item.done then
                done = done + 1
                if item.hit then
                    hits = hits + 1
                end
            end
        end
        if not T.map_off and hits >= 2 and done >= 2 then
            T.map_off = true
            N.log.line("teleport: son 3 isinlanmanin 2'sinde hemen vuruldun, bu harita boyunca havada teleport kapali")
        end
    end

    -- Harita / oturum degisimi: tickcount bastan baslar, tick'e bagli her sey silinir.
    X.tp_reset = function()
        X.tp.list, X.tp.map_off = {}, false
        X.air.map_logged = false
        X.shift_tick, X.own_def_until, X.last_sim = -1, -1, nil
        X.forced_tick, X.scan_tick, X.anti_until, X.smart_hold, X.shot_tick = -1000, -1000, -1000, -1000, -1000
        X.def_end, X.def_was = -1000, false
        X.aim = { target = nil, time = -1000 }
        X.land_reset()
    end

    -- X9: atistan sonra gorulurken en fazla 0.5 sn sarj bekletilir (sarj olurken sunucuda donarsin).
    X.safe_reason = function()
        local st, E = N.st, N.exposure
        local ms = st.move_state
        if ms == "Peek" and not st.crouch then
            return "peek"
        end
        if (ms == "Crouch move" or (ms == "Peek" and st.crouch)) and not N.on("crouch_recharge") then
            return "egik"
        end
        if (st.speed or 0) > 100 then
            return "hizli"
        end
        if st.airborne then
            return "havada"
        end
        local mine = U.origin(st.lp)
        if mine == nil then
            return nil
        end
        local tick = U.tick()
        for _, enemy in ipairs(E.enemies()) do
            local o = U.origin(enemy)
            local info = U.winfo(enemy)
            local m = U.melee(info)
            if o ~= nil then
                local d = U.dist(o, mine)
                if m == "knife" and d <= 260 then
                    return "bicak yakin"
                end
                if m == "zeus" and d <= 420 and abs(o.z - mine.z) <= 128 then
                    return "zeus yakin"
                end
            end
            if info ~= nil and (info.name == "scar20" or info.name == "g3sg1") then
                local idx = U.index(enemy)
                local t = idx ~= nil and N.track.p[idx] or nil
                local shot_recent = t ~= nil and U.now() - t.shot_us <= 32 * U.ipt() and U.now() >= t.shot_us
                local s = idx ~= nil and E.sight[idx] or nil
                if (s ~= nil and tick - s.last <= 32 and tick >= s.last) or shot_recent then
                    return "oto goruyor"
                end
            end
        end
        return nil
    end

    X.safe_recharge = function()
        local st, E, S = N.st, N.exposure, X.safe
        local now = U.now()
        if not N.on("safe_recharge") then
            if S.holding then
                S.holding = false
                N.rc.allow("safe")
            end
            return
        end
        if S.holding then
            local why = X.safe_reason()
            if not E.seen or now - S.since > 0.5 or now < S.since or why ~= nil then
                S.holding = false
                S.no_hold = why
                N.rc.allow("safe")
            end
            return
        end
        if S.want_at > S.handled_at and now - S.want_at < 0.3 and now >= S.want_at then
            S.handled_at = S.want_at
            if not E.seen then
                return
            end
            local why = X.safe_reason()
            if why ~= nil then
                S.no_hold, S.no_hold_at = why, now
                if why == "bicak yakin" or why == "zeus yakin" or why == "oto goruyor" then
                    N.log.line("sarj bekleme yok: " .. why)
                end
                return
            end
            if N.rc.block("safe") then
                S.holding, S.since, S.no_hold = true, now, nil
            end
        end
    end

    -- X13: kendi lag'imiz sirasinda 10 sn icinde 2 "server rejection" / "prediction error" -> o lag 10 sn durur.
    X.broken_shot = function(reason, tags)
        if reason ~= "server rejection" and reason ~= "prediction error" then
            return
        end
        local now = U.now()
        for _, lag in ipairs({ "DEF", "LC", "TP" }) do
            if tags ~= nil and tags[lag] then
                local list = X.broken[lag]
                list[#list + 1] = now
                while #list > 0 and now - list[1] > 10 do
                    tremove(list, 1)
                end
                if #list >= 2 and not X.paused(lag) then
                    X.broken.paused[lag] = now + 10
                    X.broken[lag] = {}
                    N.log.line(fmt("%s 10 sn durduruldu: %s sirasinda 2 atis bozuk gitti (son: %s)", lag, lag, reason))
                end
            end
        end
    end

    -- Atis anindaki lag etiketleri.
    X.tags = function()
        local tags = {}
        local now = U.now()
        if X.clean then
            tags.temiz = true
        end
        if X.own_def_active() or X.forced then
            tags.DEF = true
        end
        if X.air.latched then
            tags.LC = true
        end
        if now - X.tp.last <= 1 and now >= X.tp.last then
            tags.TP = true
        end
        if N.st.fd then
            tags.FD = true
        end
        return tags
    end

    X.tags_text = function(tags)
        local out = ""
        for _, k in ipairs({ "temiz", "LC", "DEF", "TP", "FD" }) do
            if tags[k] then
                out = out .. " " .. k
            end
        end
        return out
    end

    X.reset_life = function()
        X.air.was_air, X.air.used, X.air.latched, X.air.left, X.air.pending_log = false, false, false, 0, false
        X.safe.holding = false
        X.clean, X.after_shot = false, false
        X.last_sim, X.own_def_until = nil, -1
        X.aim = { target = nil, time = -1000 }
        X.land.flight, X.land.fired, X.land.gt = false, false, 64
    end
end

-------------------------------------------------------------------------------
-- Ragebot (HITSCAN / TARGET_SELECTION, hedef basina): gercek / taze kayit bekleme, Min. damage kurallari
-- (sira: bicak / zeus -> DT cifti -> extended -> kafa saklayan -> can'a yukselt), akilli govde, sahte kayitta
-- govde, havada hit chance, adaptif safe point seviyeleri.
-------------------------------------------------------------------------------
do
    local U, RG = N.util, N.rage
    local K = N.K
    RG.t, RG.hold, RG.wait, RG.fresh, RG.freshw, RG.scan, RG.dmg_cache = {}, {}, {}, {}, {}, {}, {}
    RG.ext, RG.last_md, RG.fresh_tick, RG.sik = {}, nil, -1000, { idx = nil, since = nil, logged = false }
    -- R10: bu oturumda (bu haritada) o durumda resolver iskasi alinan rakipler; yoksa hafiza en fazla seviye 1.
    RG.cfresh = {}
    RG.GROUPS = { "HEAD", "CHEST", "STOMACH", "ARMS", "LEGS", "FEET" }

    RG.get = function(idx)
        local t = RG.t[idx]
        if t == nil then
            t = { level = 0, stall_until = -1000, l2_since = nil, fake_ticks = 0, fake_free = -1000,
                fake_window = nil, last_shot = -1000 }
            RG.t[idx] = t
        end
        return t
    end

    -- Gozumuzden hedefe: kafa ve govde (gogus / pelvis) hasari; tick basina onbellek.
    RG.dmg = function(target)
        local idx = U.index(target)
        local tick = U.tick()
        local c = idx ~= nil and RG.dmg_cache[idx] or nil
        if c ~= nil and c.tick == tick then
            return c.head, c.body
        end
        local lp = N.st.lp
        local eye = U.eye(lp)
        local head = U.tdmg(eye, U.hitbox(target, "HEAD"), lp, target)
        local body = max(U.tdmg(eye, U.hitbox(target, "PELVIS"), lp, target),
            U.tdmg(eye, U.hitbox(target, "CHEST"), lp, target))
        if idx ~= nil then
            local hittable = head > 0 or body > 0
            RG.dmg_cache[idx] = { tick = tick, head = head, body = body, hittable = hittable }
            if hittable then
                RG.fresh[idx] = tick
            end
        end
        return head, body
    end

    RG.group_off = function(ctx, name)
        pcall(ctx.set_hitscan_group_state, ctx, e_hitscan_groups[name], false)
    end

    RG.all_off = function(ctx)
        for _, g in ipairs(RG.GROUPS) do
            RG.group_off(ctx, g)
        end
    end

    RG.end_wait = function(idx, w, reason, ent)
        local tick = U.tick()
        w.active = false
        w.free_until = tick + 32
        w.done_text = fmt("%d tick", w.ticks)
        w.done_at = U.now()
        if w.kind == "real" then
            if N.on("resolver_log") then
                N.log.every("wait:" .. idx, 15, fmt("resolver: %s sahte kayitta (defensive): %d tick gercek kayit beklendi, %s",
                    U.name(ent), w.ticks, reason))
            end
        else
            if N.on("resolver_log") then
                N.log.every("fresh:" .. idx, 15, fmt("resolver: %s su anki kaydi vurulamiyordu: %d tick taze kayit beklendi, %s",
                    U.name(ent), w.ticks, reason))
            end
        end
    end

    -- SETUP_COMMAND: bekletme listesi (TARGET_SELECTION + HITSCAN ayni listeyi kullanir).
    RG.prepare = function()
        local st, E, T = N.st, N.exposure, N.track
        local tick, now = U.tick(), U.now()
        local hold = {}
        local list = E.enemies()
        -- Senin Min. damage override tusun basiliyken R2-R7 calismaz (R1 calisir).
        local _, ovr = N.ref.md_eff(st.wgroup)
        local bolt = U.is_bolt(st.weapon) and not ovr
        local do_fresh = N.on("fresh_only") and bolt and (tick - RG.fresh_tick >= 2 or tick < RG.fresh_tick)
        if do_fresh then
            RG.fresh_tick = tick
        end
        for _, ent in ipairs(list) do
            local idx = U.index(ent)
            if idx ~= nil then
                -- R1: gercek kayit bekleme.
                local w = RG.wait[idx]
                if w == nil then
                    w = { active = false, ticks = 0, free_until = -1000, kind = "real" }
                    RG.wait[idx] = w
                end
                local t = T.p[idx]
                local fake = T.fake(idx)
                local sees = E.sees(idx)
                local duel = sees or (t ~= nil and now >= t.we_shot and now - t.we_shot <= 1.5)
                if N.on("wait_real") then
                    local limit = 14
                    if st.move_state == "Peek" and not E.seen and U.flag(ent, "ON_GROUND") == false then
                        limit = 4
                    end
                    if w.active then
                        w.ticks = w.ticks + 1
                        if not fake then
                            w.real_at = w.real_at or tick
                            if tick - w.real_at >= 3 then
                                RG.end_wait(idx, w, "gercek kayit geldi", ent)
                            end
                        elseif w.ticks >= limit then
                            RG.end_wait(idx, w, "sinir doldu, kayit hala sahte", ent)
                        elseif sees then
                            RG.end_wait(idx, w, "serbest birakildi (seni goruyor)", ent)
                        elseif duel then
                            RG.end_wait(idx, w, "serbest birakildi (duello)", ent)
                        end
                    elseif fake then
                        if sees then
                            w.nowait = "seni goruyor"
                        elseif duel then
                            w.nowait = "duello"
                        elseif E.seen then
                            w.nowait = "biri seni goruyor"
                        elseif tick < w.free_until and tick >= w.free_until - 32 then
                            w.nowait = "cooldown"
                        else
                            w.active, w.ticks, w.real_at, w.nowait = true, 0, nil, nil
                        end
                    else
                        w.nowait = nil
                    end
                    if w.active then
                        hold[idx] = "real"
                    end
                elseif w.active then
                    w.active = false
                end
                -- R2: sniper'da taze kayit. Iz butcesi: sadece son 32 tick'te taranan, beklenen ya da tehdit olan dusman.
                local f = RG.freshw[idx]
                if f == nil then
                    f = { active = false, ticks = 0, kind = "fresh" }
                    RG.freshw[idx] = f
                end
                if do_fresh then
                    local sc = RG.t[idx] ~= nil and RG.t[idx].scan_tick or nil
                    if f.active or ent == st.threat or (sc ~= nil and tick - sc <= 32 and tick >= sc) then
                        RG.dmg(ent)
                    end
                end
                if N.on("fresh_only") and bolt and hold[idx] == nil then
                    local c = RG.dmg_cache[idx]
                    local hittable = c ~= nil and c.hittable == true and tick - c.tick <= 2 and tick >= c.tick
                    local last = RG.fresh[idx]
                    if f.active then
                        f.ticks = f.ticks + 1
                        if hittable then
                            RG.end_wait(idx, f, "kayit taze, ates serbest", ent)
                        elseif last == nil or tick - last > 24 or tick < last then
                            RG.end_wait(idx, f, "eski kayitlar gecti (backtrack yok)", ent)
                        end
                    elseif not hittable and last ~= nil and tick - last <= 24 and tick - last >= 2 then
                        f.active, f.ticks = true, 0
                    end
                    if f.active then
                        hold[idx] = "fresh"
                    end
                elseif f.active then
                    f.active = false
                end
            end
        end
        RG.hold = hold
        RG.sikmadi()
    end

    -- TARGET_SELECTION
    RG.select = function(ctx)
        for idx in pairs(RG.hold) do
            pcall(ctx.ignore_target, ctx, idx)
        end
    end

    RG.set_md = function(ctx, info, value, why)
        value = max(1, floor(value + 0.5))
        pcall(ctx.set_min_dmg, ctx, value)
        info.md, info.md_set, info.why = value, true, why
        RG.last_md = { v = value, tick = U.tick(), why = why }
    end

    -- Bicakli / zeuslu hedef 320 birimde, goz goze, |dz| < 128.
    RG.melee_close = function(target)
        local st = N.st
        local m = U.melee(U.winfo(target))
        if m == nil then
            return nil
        end
        local mine, theirs = U.origin(st.lp), U.origin(target)
        if mine == nil or theirs == nil or U.dist(mine, theirs) > 320 or abs(mine.z - theirs.z) >= 128 then
            return nil
        end
        local eye, their_eye = U.eye(st.lp), U.eye(target)
        local frac, hit = U.tline(eye, their_eye, st.lp)
        if frac >= 0.97 or hit == target then
            return m, U.dist(mine, theirs)
        end
        return nil
    end

    RG.estate = function(target)
        return N.track.enemy_state(target)
    end

    -- R10 / R11: seviye 0 / 1 (safe point kafa) / 2 (Force).
    RG.level = function(target, idx, hp, head, body, sniper)
        local t = RG.get(idx)
        local p, key = N.mem.entry(target)
        local estate = RG.estate(target)
        local results = p ~= nil and p.res[estate] or ""
        local _, c = results:gsub("c", "")
        local level = min(2, c)
        -- GS entry_level: hafizadan gelen eski iskalar en fazla Prefer; Force icin bu oturumda o durumda bir iska.
        local fr = key ~= nil and RG.cfresh[key] or nil
        if level > 1 and not (fr ~= nil and fr[estate]) then
            level = 1
        end
        local tr = N.track.p[idx]
        if results == "" and tr ~= nil and tr.pattern == "jitter" then
            level = max(level, 1)
        end
        if N.on("low_hp_safe") and hp <= 30 then
            level = 2
        end
        if sniper then
            level = min(level, 1)
        end
        if body <= 0 and head > 0 then
            level = min(level, 1)
        end
        local now = U.now()
        if level == 2 then
            local can = U.call(client.can_fire) == true
            if (head > 0 or body > 0) and can then
                t.l2_since = t.l2_since or now
                if now - t.l2_since >= N.K.FORCE_STALL and now - t.last_shot >= N.K.FORCE_STALL then
                    t.stall_until = now + 2
                    t.l2_since = nil
                    if N.on("resolver_log") then
                        N.log.line(fmt("resolver: %s %s | seviye 2 -> 1 (ates gelmedi, 2 sn)", U.name(target), estate))
                    end
                end
            else
                t.l2_since = nil
            end
            if now < t.stall_until and now >= t.stall_until - 2 then
                level = 1
            end
        else
            t.l2_since = nil
        end
        if level ~= t.level then
            if N.on("resolver_log") and (level > 0 or t.level > 0) then
                N.log.every("lvl:" .. idx .. ":" .. level, 2, fmt("resolver: %s %s | seviye %d -> %d (%s)", U.name(target),
                    estate, t.level, level, level == 2 and "safe point Force" or (level == 1 and "safe point Head"
                    or "safe point yok")))
            end
            t.level = level
        end
        return level
    end

    RG.ext_active = function(target)
        local _, key = N.mem.entry(target)
        local e = key ~= nil and RG.ext[key] or nil
        local now = U.now()
        return e ~= nil and e.until_t ~= nil and now < e.until_t and now >= e.until_t - 180
    end

    RG.hider_active = function(target)
        local p = N.mem.entry(target)
        if p == nil then
            return false, 0, 0
        end
        local hd = p.hider
        if hd.n >= 12 and hd.h / hd.n <= 0.35 then
            return true, hd.h, hd.n
        end
        return false, hd.h, hd.n
    end

    -- HITSCAN (hedef basina).
    RG.hitscan = function(ctx)
        local target = ctx.player
        local idx = U.index(target)
        if target == nil or idx == nil then
            return
        end
        local st, P = N.st, N.ref
        local tick, now = U.tick(), U.now()
        N.ex.onpeek_trigger()
        local info = { md = nil, md_set = false, ba = false, sp = 0, why = nil, tick = tick, hider = false }
        RG.scan[idx] = info
        RG.get(idx).scan_tick = tick
        local hp = U.hp(target)
        info.hp = hp
        if RG.hold[idx] ~= nil then
            RG.all_off(ctx)
            info.held = RG.hold[idx]
            return
        end
        local w = st.wgroup
        local wname = st.weapon
        local sniper = U.is_sniper(wname)
        local head, body = RG.dmg(target)
        info.head, info.body = head, body
        -- R10 / R11
        if N.on("resolver") then
            local level = RG.level(target, idx, hp, head, body, sniper and N.on("head_only"))
            info.sp = level
            if level == 1 then
                pcall(ctx.set_safepoint_state, ctx, true, e_hitscan_groups.HEAD)
            elseif level == 2 then
                pcall(ctx.set_safepoint_state, ctx, true)
            end
        end
        -- R8: tek govde mermisi olduruyor -> govde.
        if N.on("smart_baim") and body >= hp then
            for _, g in ipairs({ "HEAD", "ARMS", "LEGS", "FEET" }) do
                RG.group_off(ctx, g)
            end
            info.ba = true
        end
        -- R9: sniper, hedef sahte kayitta ve govde olduruyor -> kafa gercek kayda (en fazla 12 tick, sonra 0.5 sn).
        local t = RG.get(idx)
        if N.on("fake_body") and U.is_bolt(wname) and N.track.fake(idx) and body >= hp and now >= t.fake_free then
            if t.fake_window == nil then
                t.fake_window, t.fake_ticks = tick, 0
                if N.on("resolver_log") then
                    N.log.line(fmt("resolver: %s sahte kayitta (defensive): sniper oldurecek govdeye, kafa gercek kayda",
                        U.name(target)))
                end
            end
            if tick ~= t.fake_last then
                t.fake_last = tick
                t.fake_ticks = t.fake_ticks + 1
            end
            if t.fake_ticks <= 12 then
                RG.group_off(ctx, "HEAD")
                info.ba = true
            else
                t.fake_window, t.fake_free = nil, now + 0.5
            end
        elseif t.fake_window ~= nil and not N.track.fake(idx) then
            t.fake_window = nil
        end
        -- Min. damage kurallari. Senin override tusun basiliyken hicbiri (R2-R7) calismaz.
        local md, ovr = P.md_eff(w)
        info.md_eff, info.ovr = md, ovr
        if md == nil or ovr then
            RG.air_hc(ctx, wname, w)
            return
        end
        local need = P.need(hp, md)
        local melee, dist = nil, nil
        if N.on("knife_md") then
            melee, dist = RG.melee_close(target)
        end
        local target_melee = U.melee(U.winfo(target))
        -- R4: bicak -> MD min(30, hp) (oldurmese de vur); zeus -> sadece oldurucu (MD hp).
        if melee == "knife" then
            local v = min(30, hp)
            if v < need then
                RG.set_md(ctx, info, v, "knife")
                N.log.every("r4:" .. idx, 2, fmt("%s bicak ile yakinda: Min. damage gecici %d (oldurmese de vur)",
                    U.name(target), U.R(v)))
            end
        elseif melee == "zeus" then
            if hp < need then
                RG.set_md(ctx, info, hp, "zeus")
                N.log.every("r4:" .. idx, 2, fmt("%s zeus ile yakinda: sadece oldurucu (MD %d)", U.name(target),
                    U.R(hp)))
            end
        end
        -- R7: DT cifti (kapali varsayilan): govde x 2 >= can, govde >= 60, kayit 8+ tick gec.
        if not info.md_set and N.on("dt_pair") and sniper and P.dt_ready() and body * 2 >= hp and body >= 60 then
            local tr = N.track.p[idx]
            if tr ~= nil and tr.record_age >= 8 and body - 1 < need then
                RG.set_md(ctx, info, body - 1, "dtpair")
                N.log.every("r7:" .. idx, 2, fmt("%s: DT cifti olduruyor (govde %d x 2 >= can %d), Min. damage gecici %d",
                    U.name(target), U.R(body), U.R(hp), U.R(body - 1)))
            end
        end
        -- R5 / R6 (GS ext_why): sadece yerdeki hedefe, govde >= 60 ve govde oldurmuyorken; yoksa kafa ve MD
        -- olduklari gibi kalir (sadece kafa gorunen rakip vurulabilir kalir, duvar arkasi govde MD'yi dusurmez).
        local body_force = body >= 60 and hp > body and U.flag(target, "ON_GROUND") ~= false
        -- R5: extended suphesi (kafada ust uste resolver iskasi) -> govde.
        if not info.md_set and body_force and N.on("ext_body") and target_melee == nil and RG.ext_active(target) then
            RG.group_off(ctx, "HEAD")
            info.ba = true
            if body - 1 > 0 and body - 1 < need then
                RG.set_md(ctx, info, body - 1, "ext")
                N.log.every("r5:" .. idx, 5, fmt("%s: extended suphesi (kafada 3 iska ust uste): govde %d, Min. damage gecici %d",
                    U.name(target), U.R(body), U.R(body - 1)))
            end
        end
        -- R6: kafa saklayan (kafa payi <= %35, 12+ atis) -> sniper govde; her 4. atis kafaya serbest.
        if not info.md_set and body_force and N.on("hider_body") and sniper and target_melee == nil then
            local active, h, n = RG.hider_active(target)
            if active then
                info.hider = true
                local p = N.mem.entry(target)
                if p ~= nil and p.hider.b % 4 ~= 3 then
                    RG.group_off(ctx, "HEAD")
                    info.ba = true
                    if body - 1 > 0 and body - 1 < need then
                        RG.set_md(ctx, info, body - 1, "hider")
                    end
                    if N.on("resolver_log") then
                        N.log.every("r6:" .. idx, 30, fmt("resolver: %s kafa payi %d/%d (%d%%): govde zorlaniyor",
                            U.name(target), U.R(h), U.R(n), U.R(h / max(1, n) * 100)))
                    end
                end
            end
        end
        -- R3: sniper, biri seni goruyorken sadece oldurucu atis (MD can; yukseltir, dusurmez).
        if not info.md_set and N.on("head_only") and sniper and need < hp and N.exposure.seen then
            RG.set_md(ctx, info, hp, "head")
        end
        RG.air_hc(ctx, wname, w)
    end

    -- R12: havadayken sniper hit chance (0 = kapali; senin degerin daha yuksekse dokunulmaz).
    RG.air_hc = function(ctx, wname, w)
        local v = N.v("air_hc") or 0
        if v <= 0 or not N.st.airborne or not U.is_bolt(wname) then
            return
        end
        local native = N.ref.get("hc:" .. w)
        if U.finite(native) and v <= native then
            return
        end
        pcall(ctx.set_hitchance, ctx, v)
    end

    -- Atis sonucu ogrenmesi (resolver sonuclari, extended ve kafa saklayan sayaclari).
    RG.learn = function(rec, result, reason, hitgroup)
        local target = rec.ent
        if target == nil then
            return
        end
        local p, key = N.mem.entry(target, rec.key)
        if p == nil then
            return
        end
        -- Pencereye sadece isabet (h) ve resolver iskasi (c) girer; spread / diger iskalar pencereyi sulandirmaz (GS).
        local letter = nil
        if result == "hit" then
            letter = "h"
        elseif reason == "resolver" or reason == "jitter" then
            if not rec.fake then
                letter = "c"
            end
        end
        if letter ~= nil and rec.estate ~= nil then
            local s = (p.res[rec.estate] or "") .. letter
            p.res[rec.estate] = s:sub(-4)
            N.mem.dirty = true
            if letter == "c" then
                RG.cfresh[key] = RG.cfresh[key] or {}
                RG.cfresh[key][rec.estate] = true
            end
        end
        local head_aimed = rec.hitgroup == 1
        -- R5 sayaci: kafaya nisan, hc >= 70, yerdeki hedef, statik (ya da bilinmeyen) desen.
        local e = RG.ext[key]
        if e == nil then
            e = { misses = 0 }
            RG.ext[key] = e
        end
        local tnow = U.now()
        if result == "hit" and hitgroup == 1 then
            if e.until_t ~= nil and N.on("resolver_log") then
                N.log.line(fmt("resolver: %s kafadan vuruldu -> extended govde kurali kalkti", rec.name))
            end
            e.misses, e.until_t = 0, nil
        elseif result == "hit" then
            -- GS: ardisik seri; her isabet (govde dahil) sayaci sifirlar.
            e.misses = 0
        elseif reason == "resolver" and head_aimed and (rec.hc or 0) >= 70 and rec.grounded and not rec.fake
            and rec.pattern ~= "jitter" then
            -- GS: 300 sn iskasiz gecerse seri baslangictan.
            if e.last_miss ~= nil and (tnow < e.last_miss or tnow - e.last_miss > 300) then
                e.misses = 0
            end
            e.last_miss = tnow
            e.misses = e.misses + 1
            local need = (rec.pattern == "static" and rec.sideways) and 2 or 3
            if e.misses >= need and (e.until_t == nil or tnow > e.until_t) then
                local streak = e.misses
                e.until_t, e.misses = tnow + 180, 0
                if N.on("resolver_log") then
                    N.log.line(fmt("%s: extended suphesi (kafada %d iska ust uste): govdeye geciliyor", rec.name,
                        streak))
                end
            end
        end
        -- R6 sayaci (sniper, kafaya nisan, yerdeki hedef, hc >= 70; isabet ya da resolver iskasi).
        if rec.sniper and head_aimed and rec.grounded and (rec.hc or 0) >= 70
            and (result == "hit" or reason == "resolver") then
            local hd = p.hider
            hd.n = hd.n + 1
            if result == "hit" and hitgroup == 1 then
                hd.h = hd.h + 1
            end
            if hd.n > 30 then
                hd.h = hd.h * 30 / hd.n
                hd.n = 30
            end
            N.mem.dirty = true
        end
    end

    -- dbg sikmadi: hedefe 20+ hasar geciyor ama 0.44 sn ates yok -> sebep.
    RG.sikmadi = function()
        local st = N.st
        local S = RG.sik
        if not N.on("debug_log") then
            return
        end
        local target = st.threat
        local now = U.now()
        if target == nil then
            S.idx, S.since = nil, nil
            return
        end
        local idx = U.index(target)
        local head, body = RG.dmg(target)
        if max(head, body) < 20 then
            S.idx, S.since = nil, nil
            return
        end
        if S.idx ~= idx or S.since == nil or N.shots.last_shoot_at > S.since then
            S.idx, S.since, S.logged = idx, now, false
            return
        end
        if S.logged or now - S.since < 0.44 then
            return
        end
        S.logged = true
        local hp = U.hp(target)
        local md = N.ref.md_eff(st.wgroup)
        local need = md ~= nil and N.ref.need(hp, md) or nil
        local hc = N.ref.get("hc:" .. st.wgroup)
        local reason
        if RG.hold[idx] == "real" then
            reason = "gercek kayit bekleniyor"
        elseif RG.hold[idx] == "fresh" then
            reason = "taze kayit bekleniyor"
        elseif U.call(client.can_fire) ~= true then
            reason = "silah hazir degil"
        elseif need ~= nil and max(head, body) < need then
            reason = md >= 100 and fmt("hasar %d < can+%d", U.R(max(head, body)), U.R(md - 100))
                or fmt("hasar %d < MD %d", U.R(max(head, body)), U.R(md))
        elseif st.airborne and U.is_bolt(st.weapon) then
            reason = "havada hit chance"
        elseif N.ex.aim.target ~= nil and N.ex.aim.target ~= target and now - N.ex.aim.time <= 0.44 then
            reason = "aimbot baska hedefe"
        else
            reason = "sebep bilinmiyor"
        end
        N.log.line(fmt("dbg sikmadi: %s %.2fs vurulabilir (kafa %d, govde %d hasar), ates yok | %s | MD %s hc %s | %s",
            U.name(target), now - S.since, U.R(head), U.R(body), reason, md ~= nil and U.numtext(md) or "?",
            U.finite(hc) and U.numtext(hc) or "?", U.wlabel(st.weapon)))
    end

    -- Harita / oturum degisimi: tick'e bagli bekleme ve onbellek tablolari silinir (index'ler yeniden kullanilir).
    RG.map_reset = function()
        RG.t, RG.hold, RG.wait, RG.fresh, RG.freshw, RG.scan, RG.dmg_cache = {}, {}, {}, {}, {}, {}, {}
        RG.fresh_tick, RG.sik = -1000, { idx = nil, since = nil, logged = false }
        RG.cfresh = {}
    end

    RG.reset_life = function()
        RG.hold, RG.scan = {}, {}
        for _, w in pairs(RG.wait) do
            w.active = false
        end
        for _, f in pairs(RG.freshw) do
            f.active = false
        end
    end
end

-------------------------------------------------------------------------------
-- AI peek (native autopeek tusu basili, hareket tusu yok): tehdide dik 18/32/46/60 birim noktalar, kafa (merkez
-- / kenarlar) yeterli ya da govde oldurucu, yurunebilir; iki taramada dogrulanir, 0.5 sn beklenir, atistan /
-- sureden sonra geri. AFK modu (kendi capasi, 3 sn'de bir 24 birim adim) ve otomatik AFK.
-------------------------------------------------------------------------------
do
    local U, PK, AF = N.util, N.peek, N.afk
    PK.mode, PK.side_mul, PK.locked, PK.empty, PK.cand = nil, 1, {}, {}, nil
    PK.cal = { wrong = 0, flips = 0, off = false, logged = false }
    PK.scan_tick, PK.key_was, PK.shot_at, PK.result = -1000, false, nil, nil
    AF.on, AF.auto, AF.armed, AF.idle_since, AF.anchor, AF.side, AF.flip_at = false, false, true, nil, nil, 1, 0
    AF.cam, AF.kind_was = nil, false

    PK.button = function(cmd, name)
        local ok, v = pcall(cmd.has_button, cmd, e_cmd_buttons[name])
        return ok and v == true
    end

    PK.user_moving = function(cmd)
        return PK.button(cmd, "FORWARD") or PK.button(cmd, "BACK") or PK.button(cmd, "MOVELEFT")
            or PK.button(cmd, "MOVERIGHT")
    end

    PK.set_move = function(cmd, fwd, side)
        pcall(function()
            cmd.move = vec3_t(fwd, side, 0)
        end)
    end

    -- G13: cmd.move.y isareti; 4 tick boyunca istenen yanin tersine gidiyorsak cevrilir.
    PK.calibrate = function(want_right, view)
        local C = PK.cal
        if C.off or want_right == 0 then
            return
        end
        local v = U.vel(N.st.lp)
        local cx, sy = U.dir(view)
        local lat = v.x * sy - v.y * cx
        if abs(lat) < 20 then
            return
        end
        if (lat > 0) ~= (want_right > 0) then
            C.wrong = C.wrong + 1
        else
            C.wrong = 0
        end
        if C.wrong >= 4 then
            C.wrong = 0
            C.flips = C.flips + 1
            PK.side_mul = -PK.side_mul
            if C.flips >= 3 then
                C.off = true
                PK.mode = nil
                N.log.line("ai peek: yan hareket isareti olculemedi, ai peek / afk bu oturum kapatildi")
            elseif not C.logged then
                C.logged = true
                N.log.line("ai peek: yan hareket isareti ters olculdu, duzeltildi")
            end
        end
    end

    -- Hedefe yuru; varildiysa true.
    PK.move_to = function(cmd, goal, tolerance)
        local lp = N.st.lp
        local o = U.origin(lp)
        if o == nil or goal == nil then
            return true
        end
        local d = U.dist2d(o, goal)
        if d < (tolerance or 4) then
            PK.set_move(cmd, 0, 0)
            return true
        end
        local view = N.aa.view_yaw(cmd)
        local a = math.rad(U.yaw_to(o, goal) - view)
        local speed = min(450, max(80, d * 12))
        local right = -math.sin(a)
        PK.set_move(cmd, math.cos(a) * speed, right * speed * PK.side_mul)
        if abs(right) > 0.5 then
            PK.calibrate(right, view)
        end
        return false
    end

    PK.walkable = function(a, p, step_only)
        local lp = N.st.lp
        local f1 = U.tline(U.add(a, 0, 0, 18), U.add(p, 0, 0, 18), lp)
        if f1 < 1 then
            return false
        end
        local f2 = U.tline(U.add(p, 0, 0, 18), U.add(p, 0, 0, step_only and -18 or -40), lp)
        return f2 < 1
    end

    -- Kafa (merkez +-3) ya da oldurucu govde bu noktadan geciyor mu.
    PK.point_damage = function(eye, threat, need, hp)
        local lp = N.st.lp
        local head = U.hitbox(threat, "HEAD")
        local best = 0
        if head ~= nil then
            best = U.tdmg(eye, head, lp, threat)
            if best < need then
                local yaw = U.yaw_to(eye, head) + 90
                best = max(best, U.tdmg(eye, U.offset(head, yaw, 3, 0), lp, threat),
                    U.tdmg(eye, U.offset(head, yaw, -3, 0), lp, threat))
            end
        end
        if best >= need then
            return best
        end
        local body = max(U.tdmg(eye, U.hitbox(threat, "CHEST"), lp, threat),
            U.tdmg(eye, U.hitbox(threat, "PELVIS"), lp, threat))
        if body >= hp then
            return body
        end
        return 0
    end

    PK.scan = function(anchor, threat)
        local st = N.st
        local lp = st.lp
        local theirs, eye, org = U.origin(threat), U.eye(lp), U.origin(lp)
        if theirs == nil or eye == nil or org == nil then
            return nil
        end
        local eye_h = eye.z - org.z
        local hp = U.hp(threat)
        local need = N.ref.md_need(hp, st.wgroup) or hp
        local base = U.yaw_to(anchor, theirs)
        local angles = { 90 }
        if theirs.z > anchor.z + 64 then
            angles[2] = 135
        end
        for _, ang in ipairs(angles) do
            for _, s in ipairs({ 18, 32, 46, 60 }) do
                for _, side in ipairs({ 1, -1 }) do
                    local p = U.offset(anchor, base + ang * side, s, 0)
                    if PK.walkable(anchor, p) then
                        local d = PK.point_damage(vec3_t(p.x, p.y, p.z + eye_h), threat, need, hp)
                        if d > 0 then
                            return { p = p, side = side, s = s, dmg = d, back = ang ~= 90 }
                        end
                    end
                end
            end
        end
        return nil
    end

    PK.reset = function()
        PK.mode, PK.cand, PK.point, PK.shot_at, PK.result = nil, nil, nil, nil, nil
    end

    PK.finish = function(why)
        local name = PK.target_name or "?"
        if PK.shot_at == nil then
            local idx = PK.target_idx
            if idx ~= nil then
                PK.empty[idx] = (PK.empty[idx] or 0) + 1
                if PK.empty[idx] >= 2 then
                    PK.locked[idx] = true
                    N.log.line("ai peek: 2 bos peek, bu dusmana autopeek tusuna yeniden basana kadar peek yok")
                end
            end
        else
            if PK.target_idx ~= nil then
                PK.empty[PK.target_idx] = 0
            end
            N.log.line(fmt("ai peek sonucu: %s -> %s (%d birim)", PK.result or "atis", name, U.R(PK.point_s or 0)))
        end
        PK.reset()
    end

    -- SETUP_COMMAND.
    PK.update = function(cmd)
        local st = N.st
        local now = U.now()
        local key = N.ref.on("autopeek")
        if key ~= PK.key_was then
            PK.key_was = key
            if key then
                PK.locked, PK.empty = {}, {}
            end
        end
        AF.update(cmd)
        local anchor = nil
        if AF.on and AF.anchor ~= nil then
            anchor = AF.anchor
        elseif key and N.on("ai_peek") then
            local ok, pos = pcall(ragebot.get_autopeek_pos)
            if ok and U.okvec(pos) then
                anchor = pos
            end
        end
        if anchor == nil or PK.cal.off or (not N.on("ai_peek") and not AF.on) or PK.user_moving(cmd)
            or st.airborne then
            if PK.mode ~= nil then
                PK.reset()
            end
            if AF.on and AF.anchor ~= nil and not PK.user_moving(cmd) and not PK.cal.off then
                AF.strafe(cmd)
            end
            return
        end
        PK.anchor = anchor
        local threat = st.threat
        local tick = U.tick()
        if PK.mode == nil then
            if threat == nil then
                if AF.on then
                    AF.strafe(cmd)
                end
                return
            end
            local tidx = U.index(threat)
            if tidx ~= nil and PK.locked[tidx] then
                if AF.on then
                    AF.strafe(cmd)
                end
                return
            end
            local c, m = N.ref.charge()
            local why = nil
            if N.ref.on("dt") and m > 0 and c < m then
                why = "DT sarj oluyor"
            elseif U.call(client.can_fire) ~= true then
                why = "silah hazir degil"
            end
            if why ~= nil then
                N.log.every("aipeek_no", 3, "ai peek: peek yok, " .. why)
                if AF.on then
                    AF.strafe(cmd)
                end
                return
            end
            if tick - PK.scan_tick < 4 and tick >= PK.scan_tick then
                if AF.on then
                    AF.strafe(cmd)
                end
                return
            end
            PK.scan_tick = tick
            local r = PK.scan(anchor, threat)
            if r == nil then
                PK.cand = nil
                if AF.on then
                    AF.strafe(cmd)
                end
                return
            end
            if PK.cand == nil or PK.cand.side ~= r.side or PK.cand.s ~= r.s then
                PK.cand = r
                return
            end
            PK.mode, PK.point, PK.point_s, PK.started = "walk", r.p, r.s, now
            PK.target_idx, PK.target_name, PK.shot_at, PK.result = tidx, U.name(threat), nil, nil
            PK.extra_used = false
            N.log.line(fmt("ai peek: %s%s %d birim -> %s (hasar %d)", r.side > 0 and "sol" or "sag",
                r.back and "-geri" or "", r.s, PK.target_name, U.R(r.dmg)))
        end
        if PK.mode == "walk" then
            if PK.shot_at ~= nil then
                PK.mode, PK.back_at = "back", now
            elseif PK.move_to(cmd, PK.point, 6) then
                local wait = st.weapon == "revolver" and 0.75 or 0.5
                PK.mode, PK.wait_until = "wait", now + wait
            elseif now - PK.started > 1.2 then
                N.log.line(fmt("ai peek: atis olmadi, noktaya varilamadi (%d/%d birim gidildi) -> geri",
                    U.R(U.dist2d(U.origin(st.lp), anchor)), U.R(PK.point_s or 0)))
                PK.mode, PK.back_at = "back", now
            end
            return
        end
        if PK.mode == "wait" then
            PK.set_move(cmd, 0, 0)
            if PK.shot_at ~= nil then
                PK.mode, PK.back_at = "back", now
                return
            end
            if now >= PK.wait_until then
                local idx = PK.target_idx
                if not PK.extra_used and idx ~= nil and N.track.fake(idx) then
                    PK.extra_used, PK.wait_until = true, PK.wait_until + 0.2
                    return
                end
                local reason = (idx ~= nil and N.rage.hold[idx] ~= nil) and "kayit bekleniyor"
                    or (U.call(client.can_fire) ~= true and "silah hazir degil") or "aimbot ates etmedi"
                N.log.line(fmt("ai peek: atis olmadi, %s (%d/%d birim gidildi) -> geri", reason,
                    U.R(U.dist2d(U.origin(st.lp), anchor)), U.R(PK.point_s or 0)))
                PK.mode, PK.back_at = "back", now
            end
            return
        end
        if PK.mode == "back" then
            -- Atistan sonra native autopeek geri doner; 0.5 sn icinde donmediyse biz goturuz.
            if PK.shot_at ~= nil and not AF.on and now - PK.back_at < 0.5 then
                local o = U.origin(st.lp)
                if o ~= nil and U.dist2d(o, anchor) < 8 then
                    PK.finish()
                end
                return
            end
            if PK.shot_at ~= nil and not AF.on and not PK.back_logged then
                PK.back_logged = true
                N.log.every("aipeek_back", 5, "ai peek: geri (native donmedi)")
            end
            if PK.move_to(cmd, anchor, 6) or now - PK.back_at > 2 then
                PK.back_logged = false
                PK.finish()
            end
        end
    end

    PK.on_shot = function()
        if PK.mode ~= nil and PK.shot_at == nil then
            PK.shot_at = U.now()
        end
    end

    PK.on_result = function(text)
        if PK.mode ~= nil or PK.shot_at ~= nil then
            PK.result = text
        end
    end

    PK.hurt = function(hitgroup, dmg, attacker_name)
        if PK.mode == "walk" or PK.mode == "wait" then
            N.log.line(fmt("ai peek: peek sirasinda vuruldun (%s -%d, %s)", N.K.HITGROUPS[hitgroup] or "?", U.R(dmg),
                attacker_name))
        end
    end

    -- Otomatik AFK girdisi: hareket / ziplama / egilme / ates / E ve fare (0.5 derece).
    AF.input = function(cmd)
        local why = nil
        if PK.user_moving(cmd) or PK.button(cmd, "JUMP") or PK.button(cmd, "DUCK") then
            why = "tus"
        elseif PK.button(cmd, "ATTACK") or PK.button(cmd, "ATTACK2") then
            why = "ates / durbun"
        elseif PK.button(cmd, "USE") then
            why = "E"
        end
        local ok, ang = pcall(engine.get_view_angles)
        if ok and ang ~= nil then
            local okv, p, y = pcall(function()
                return ang.x, ang.y
            end)
            if okv and U.finite(p) and U.finite(y) then
                local c = AF.cam
                if c ~= nil and (abs(U.norm(y - c.y)) > 0.5 or abs(p - c.x) > 0.5) then
                    why = why or "fare"
                end
                AF.cam = { x = p, y = y }
            end
        end
        return why
    end

    AF.update = function(cmd)
        local st = N.st
        local now = U.now()
        local why = AF.input(cmd)
        local frozen = U.game("m_bFreezePeriod") == 1
        local warm = U.game("m_bWarmupPeriod") == 1
        local okm, menu_open = pcall(menu.is_open)
        local paused = frozen or warm or (okm and menu_open == true)
        if why ~= nil and frozen then
            AF.idle_since = nil
        elseif why ~= nil then
            if AF.auto then
                N.log.line("otomatik afk kapandi: " .. why)
            end
            AF.auto, AF.armed, AF.idle_since = false, false, nil
        elseif paused or not N.on("afk_auto") then
            AF.idle_since = nil
        elseif AF.armed then
            AF.idle_since = AF.idle_since or now
            if not AF.auto and now - AF.idle_since >= 8 then
                AF.auto = true
                N.log.line("otomatik afk: dogduktan sonra 8 sn tusa basmadin")
            end
        end
        if not N.on("afk_auto") then
            AF.auto = false
        end
        local on = (N.on("afk") or AF.auto) and st.alive and not PK.cal.off
        if on ~= AF.on then
            AF.on = on
            AF.anchor = nil
            if on then
                N.log.line("afk modu acik: AI peek burada, 3 sn'de bir sag / sol, DT + defensive tam")
            else
                N.log.line("afk modu kapali: " .. (st.alive and "tusa bastin" or "oldun"))
            end
        end
        if not AF.on then
            return
        end
        local mine = U.origin(st.lp)
        if mine == nil then
            return
        end
        if PK.user_moving(cmd) or st.airborne or U.num(st.lp, "m_MoveType") == 9 then
            AF.anchor = nil
            return
        end
        if AF.anchor == nil then
            AF.anchor, AF.flip_at = U.copy(mine), now + 3
        else
            local dx, dy = mine.x - AF.anchor.x, mine.y - AF.anchor.y
            if dx * dx + dy * dy > 160 * 160 or abs(mine.z - AF.anchor.z) > 18 then
                AF.anchor, AF.flip_at = U.copy(mine), now + 3
            end
        end
    end

    -- AFK adimi: 3 sn'de bir capanin 24 birim sagi / solu (tehdide dik); duvar / bosluk -> capa.
    AF.strafe = function(cmd)
        local st = N.st
        local now = U.now()
        if AF.anchor == nil then
            return
        end
        if now >= AF.flip_at or now < AF.flip_at - 4 then
            AF.side, AF.flip_at = -AF.side, now + 3
        end
        local threat = st.threat
        local theirs = threat ~= nil and U.origin(threat) or nil
        local yaw = theirs ~= nil and U.yaw_to(AF.anchor, theirs) or N.aa.view_yaw(cmd)
        local dest = U.offset(AF.anchor, yaw + 90 * AF.side, 24, 0)
        if not PK.walkable(AF.anchor, dest, true) then
            dest = U.offset(AF.anchor, yaw - 90 * AF.side, 24, 0)
            if not PK.walkable(AF.anchor, dest, true) then
                dest = AF.anchor
            end
        end
        PK.move_to(cmd, dest, 4)
    end

    AF.spawn = function()
        AF.auto, AF.armed, AF.idle_since, AF.anchor = false, true, nil, nil
    end

    AF.death = function()
        if AF.on then
            N.log.line("afk modu kapali: oldun")
        end
        AF.on, AF.auto, AF.armed, AF.idle_since, AF.anchor = false, false, true, nil, nil
        PK.reset()
    end
end

-------------------------------------------------------------------------------
-- Atis kayitlari (AIMBOT_SHOOT -> HIT / MISS, .id ile), dusman mermileri, olumler, round / atis ozetleri,
-- dbg duello / ayarlar. Satir bicimleri GS surumuyle ayni.
-------------------------------------------------------------------------------
do
    local U, S, ST = N.util, N.shots, N.stats
    local K = N.K
    S.recs, S.n, S.last_shoot_at = {}, 0, -1000
    S.round, S.shots_round = nil, nil
    S.duels = {}

    S.aa_status = function()
        local l = N.aa.last
        return fmt("%s %d (%s)", l.side and "sag" or "sol", U.R(l.limit), l.body or "?")
    end

    S.exploit_status = function()
        local st, X = N.st, N.ex
        local parts = {}
        local now, tick = U.now(), U.tick()
        if st.fd then
            parts[#parts + 1] = "FD"
        end
        local c, m = N.ref.charge()
        if N.ref.on("dt") then
            if m > 0 and c >= m then
                parts[#parts + 1] = "DT dolu"
            else
                parts[#parts + 1] = fmt("DT %%%d", U.R(m > 0 and c / m * 100 or 0))
            end
        elseif N.ref.on("hs") then
            parts[#parts + 1] = "HS"
        else
            parts[#parts + 1] = "DT yok"
        end
        local age = tick - X.hidden_tick
        parts[#parts + 1] = (X.own_def_active() and "DEF acik" or "DEF yok") .. (X.forced and " (zorla)" or "")
            .. ((age >= 0 and age <= 16) and fmt(" gizli %dt", U.R(age)) or "") .. (st.slowed and " yavas" or "")
        if N.rc.held("safe") then
            parts[#parts + 1] = "sarj bekle"
        elseif X.safe.no_hold ~= nil and X.safe.no_hold_at ~= nil and now - X.safe.no_hold_at < 1 then
            parts[#parts + 1] = "sarj bekleme yok: " .. X.safe.no_hold
        end
        if now - X.tp.last < 2 and now >= X.tp.last then
            parts[#parts + 1] = "TP"
        end
        if X.air.latched then
            parts[#parts + 1] = "AIR LC"
        end
        if X.clean then
            parts[#parts + 1] = "temiz (" .. tostring(X.clean_src or "iz") .. ")"
        end
        return concat(parts, ", ")
    end

    S.attacker_info = function(ent)
        local E = N.exposure
        local idx = U.index(ent)
        local parts = { N.track.enemy_state(ent) }
        local facing = N.aa.facing
        if facing == nil then
            parts[#parts + 1] = "AA hedefi yok"
        elseif facing == ent then
            parts[#parts + 1] = "AA hedefi"
        else
            parts[#parts + 1] = "AA hedefi degil"
        end
        local s = idx ~= nil and E.sight[idx] or nil
        if s ~= nil and E.sees(idx) then
            parts[#parts + 1] = fmt("gordu %.2fs", (s.last - s.first) * U.ipt())
        else
            local lp = N.st.lp
            local eye, head = U.eye(ent), U.hitbox(lp, "HEAD")
            local how = "iz yok"
            if eye ~= nil and head ~= nil then
                if U.tdmg(eye, head, ent, lp) > 0 then
                    local _, hit = U.tline(eye, head, ent)
                    how = (hit ~= nil and hit == lp) and "iz: su an goruyor" or "iz: duvardan goruyor"
                else
                    how = "iz: kapali"
                end
            end
            parts[#parts + 1] = "gormedi (" .. how .. ")"
        end
        return concat(parts, ", ")
    end

    local function field(obj, name)
        local ok, v = pcall(function()
            return obj[name]
        end)
        if ok then
            return v
        end
        return nil
    end
    S.field = field

    S.on_shoot = function(shot)
        local st, X, T, RG = N.st, N.ex, N.track, N.rage
        local ent = field(shot, "player")
        local id = field(shot, "id")
        local idx = U.index(ent)
        local now, tick = U.now(), U.tick()
        local info = idx ~= nil and RG.scan[idx] or nil
        if info ~= nil and (tick - info.tick > 8 or tick < info.tick) then
            info = nil
        end
        local _, key = N.mem.entry(ent)
        local tr = idx ~= nil and T.p[idx] or nil
        local fake = idx ~= nil and T.fake(idx) or false
        local wait = nil
        local w = idx ~= nil and RG.wait[idx] or nil
        local f = idx ~= nil and RG.freshw[idx] or nil
        if w ~= nil and w.done_at ~= nil and now - w.done_at <= 1 and now >= w.done_at then
            wait = "bekleme: " .. w.done_text .. " gercek kayit"
        elseif f ~= nil and f.done_at ~= nil and now - f.done_at <= 1 and now >= f.done_at then
            wait = "bekleme: " .. f.done_text .. " taze kayit"
        elseif fake and w ~= nil and w.nowait ~= nil then
            wait = "bekleme yok: " .. w.nowait
        end
        local sideways = false
        if tr ~= nil and U.finite(tr.last_yaw) then
            local mine, theirs = U.origin(st.lp), U.origin(ent)
            if mine ~= nil and theirs ~= nil then
                local bak = abs(U.norm(tr.last_yaw - U.yaw_to(theirs, mine)))
                sideways = bak >= 45 and bak <= 135
            end
        end
        local md = info ~= nil and info.md_set and info.md or N.ref.md_eff(st.wgroup)
        local rec = {
            id = id, ent = ent, idx = idx, key = key, name = U.name(ent), hp = U.hp(ent),
            estate = N.track.enemy_state(ent), hitgroup = tonumber(field(shot, "hitgroup")),
            damage = tonumber(field(shot, "damage")) or 0, hc = tonumber(field(shot, "hitchance")),
            bt = tonumber(field(shot, "backtrack_ticks")) or 0, sp = info ~= nil and info.sp or 0,
            ba = info ~= nil and info.ba or false, md = md, weapon = st.weapon, tags = X.tags(),
            profile = T.profile(ent), pattern = tr ~= nil and tr.pattern or "?", fake = fake,
            grounded = U.flag(ent, "ON_GROUND") ~= false, sideways = sideways, sniper = U.is_sniper(st.weapon),
            time = now, wait = wait,
        }
        S.n = S.n + 1
        S.recs[id ~= nil and id or ("n" .. S.n)] = rec
        -- Atis ozeti sayaclari.
        local r = S.shots_round or { shots = 0, hits = 0, clean = 0, clean_hits = 0, lag = 0, lag_hits = 0, misses = {} }
        S.shots_round = r
        r.shots = r.shots + 1
        if rec.tags.temiz then
            r.clean = r.clean + 1
        elseif rec.tags.DEF or rec.tags.LC or rec.tags.TP or rec.tags.FD then
            r.lag = r.lag + 1
        end
        ST.our_shots = (ST.our_shots or 0) + 1
        -- Diger moduller.
        X.shot_tick, X.after_shot, X.aim = tick, true, { target = ent, time = now }
        X.safe.want_at = now
        st.last_shot = now
        S.last_shoot_at = now
        if tr ~= nil then
            tr.we_shot = now
            tr.our_shots = (tr.our_shots or 0) + 1
        end
        if idx ~= nil then
            RG.get(idx).last_shot = now
            local d = S.duels[idx]
            if d ~= nil then
                d.our_shots = d.our_shots + 1
            end
        end
        if info ~= nil and info.hider then
            local p = N.mem.entry(ent)
            if p ~= nil then
                p.hider.b = p.hider.b + 1
                N.mem.dirty = true
            end
        end
        N.peek.on_shot()
    end

    S.take = function(id, player)
        local rec = id ~= nil and S.recs[id] or nil
        if rec ~= nil then
            S.recs[id] = nil
            return rec
        end
        return { name = player ~= nil and U.name(player) or "?", hp = player ~= nil and U.hp(player) or nil,
            estate = player ~= nil and N.track.enemy_state(player) or "?", damage = 0, bt = 0, sp = 0, ba = false,
            md = N.ref.md_eff(N.st.wgroup), weapon = N.st.weapon, tags = {}, profile = N.track.profile(player),
            ent = player, time = U.now() }
    end

    S.line = function(rec, result)
        local sp = rec.sp == 2 and "Force" or (rec.sp == 1 and "Head" or "-")
        local tail = ""
        if rec.wait ~= nil then
            tail = tail .. " | " .. rec.wait
        end
        if rec.fake then
            tail = tail .. " | def (sahte kayit)"
        end
        return fmt("atis: %s | %s | HP %s | hedef %s %d | %s | SP %s | BA %s | MD %s | bt %dt | hc %s | %s%s | %s%s",
            rec.name, rec.estate or "?", rec.hp ~= nil and U.numtext(rec.hp) or "?",
            K.HITGROUPS[rec.hitgroup or -1] or "?", U.R(rec.damage), result, sp, rec.ba and "Force" or "Default",
            rec.md ~= nil and U.numtext(rec.md) or "?", U.R(rec.bt), rec.hc ~= nil and (U.numtext(U.R(rec.hc)) .. "%")
            or "?", U.wlabel(rec.weapon), N.ex.tags_text(rec.tags or {}), rec.profile or "? dsy? ground", tail)
    end

    S.on_hit = function(hit)
        local player = field(hit, "player")
        local rec = S.take(field(hit, "id"), player)
        local hg = tonumber(field(hit, "hitgroup"))
        local dmg = tonumber(field(hit, "damage")) or 0
        local result = fmt("isabet %s -%d", K.HITGROUPS[hg or -1] or "?", U.R(dmg))
        if N.on("shot_log") then
            N.log.line(S.line(rec, result))
        end
        N.rage.learn(rec, "hit", nil, hg)
        local r = S.shots_round
        if r ~= nil then
            r.hits = r.hits + 1
            if rec.tags ~= nil and rec.tags.temiz then
                r.clean_hits = r.clean_hits + 1
            elseif rec.tags ~= nil and (rec.tags.DEF or rec.tags.LC or rec.tags.TP or rec.tags.FD) then
                r.lag_hits = r.lag_hits + 1
            end
        end
        ST.our_hits = (ST.our_hits or 0) + 1
        local idx = U.index(player)
        local d = idx ~= nil and S.duels[idx] or nil
        if d ~= nil then
            d.our_hits = d.our_hits + 1
        end
        local tr = idx ~= nil and N.track.p[idx] or nil
        if tr ~= nil then
            tr.our_hits = (tr.our_hits or 0) + 1
        end
        N.peek.on_result(result)
    end

    S.on_miss = function(miss)
        local player = field(miss, "player")
        local rec = S.take(field(miss, "id"), player)
        local reason = tostring(field(miss, "reason_string") or "?")
        local mapped = reason == "resolver" and "correction" or reason
        local result = "iska " .. mapped:sub(1, 32)
        if N.on("shot_log") then
            N.log.line(S.line(rec, result))
        end
        N.rage.learn(rec, "miss", reason, nil)
        N.ex.broken_shot(reason, rec.tags)
        local r = S.shots_round or { shots = 0, hits = 0, clean = 0, clean_hits = 0, lag = 0, lag_hits = 0, misses = {} }
        S.shots_round = r
        r.misses[mapped] = (r.misses[mapped] or 0) + 1
        N.peek.on_result(result)
    end

    -- Sonucu 5 sn icinde gelmeyen atis da yazilir ("sonuc yok").
    S.expire = function()
        local now = U.now()
        local drop = {}
        for id, rec in pairs(S.recs) do
            if now - rec.time > K.SHOT_MEMORY or now < rec.time then
                drop[#drop + 1] = id
            end
        end
        for _, id in ipairs(drop) do
            local rec = S.recs[id]
            S.recs[id] = nil
            if N.on("shot_log") then
                N.log.line(S.line(rec, "sonuc yok"))
            end
        end
    end

    S.player = function(userid)
        if userid == nil then
            return nil
        end
        local ok, p = pcall(entity_list.get_player_from_userid, userid)
        if ok then
            return p
        end
        return nil
    end

    S.on_hurt = function(e)
        local st = N.st
        local lp = st.lp
        if lp == nil then
            return
        end
        local victim, attacker = S.player(e.userid), S.player(e.attacker)
        local dmg = tonumber(e.dmg_health) or 0
        if attacker == lp and victim ~= nil and victim ~= lp then
            local idx = U.index(victim)
            if idx ~= nil then
                N.track.get(idx).dmg_dealt = (N.track.get(idx).dmg_dealt or 0) + dmg
            end
            return
        end
        if victim ~= lp or attacker == nil or attacker == lp or not U.is_enemy(attacker) then
            return
        end
        local weapon = tostring(e.weapon or "?")
        if K.NON_BULLET[weapon] then
            return
        end
        local hitgroup = tonumber(e.hitgroup)
        local phase, melee = N.brute.hurt_us(e, attacker, hitgroup)
        N.ex.tp_hurt(hitgroup)
        local name = U.name(attacker)
        N.peek.hurt(hitgroup, dmg, name)
        if st.fd and (weapon == "ssg08" or weapon == "awp") then
            st.fd_hint_until = U.now() + 2
            N.log.every("fd_sniper", 5, fmt("fake duck: %s %s ile vurdu -> fake duck'i birak", name, weapon))
        end
        local info = S.attacker_info(attacker)
        if not melee then
            ST.enemy_hit(st.label, hitgroup == 1)
            S.count(st.label, phase, hitgroup == 1, info:find("gormedi", 1, true) ~= nil)
        end
        local idx = U.index(attacker)
        local d = idx ~= nil and S.duels[idx] or nil
        if d ~= nil then
            d.their_hits, d.their_dmg = d.their_hits + 1, d.their_dmg + dmg
        end
        if N.on("hit_log") then
            N.log.line(fmt("vuruldun: %s -%d %s | %s | faz %d | %s | %s | %s | %s (%s) | v%d duck%d",
                hitgroup ~= nil and (K.HITGROUPS[hitgroup] or "?") or "?", U.R(dmg), weapon, st.label, phase or 0,
                S.aa_status(), S.exploit_status(), U.wlabel(st.weapon), name, info, U.R(U.speed(lp)),
                U.R((st.duck or 0) * 100)))
        end
    end

    S.where = function(a, b)
        local oa, ob = U.origin(a), U.origin(b)
        if oa == nil or ob == nil then
            return "?"
        end
        return fmt("%d birim, dz %d", U.R(U.dist(oa, ob)), U.R(oa.z - ob.z))
    end

    S.on_death = function(e)
        local st = N.st
        local lp = entity_list.get_local_player()
        if lp == nil then
            return
        end
        local victim, attacker = S.player(e.userid), S.player(e.attacker)
        local hs = e.headshot == true or e.headshot == 1
        local weapon = tostring(e.weapon or "?")
        if attacker == lp and victim ~= nil and victim ~= lp then
            ST.kills = (ST.kills or 0) + 1
            if N.on("hit_log") then
                N.log.line(fmt("oldurdun: %s | %s | %s%s", U.name(victim), st.label, U.wlabel(st.weapon),
                    hs and " | headshot" or ""))
            end
            if N.on("debug_log") then
                N.log.line(fmt("dbg kill-detay: %s %s%s | %s", U.name(victim), weapon, hs and " headshot" or "",
                    S.where(victim, lp)))
            end
            S.duel_close(U.index(victim), "oldurdun")
            N.misc.trash("kill", hs)
        elseif victim == lp then
            ST.deaths = (ST.deaths or 0) + 1
            if N.on("hit_log") then
                N.log.line(fmt("oldun: %s | %s | %s", attacker ~= nil and U.name(attacker) or "?", st.label,
                    U.wlabel(st.weapon)))
            end
            if N.on("debug_log") and attacker ~= nil and attacker ~= lp then
                N.log.line(fmt("dbg olum-detay: %s %s%s | %s | %s", U.name(attacker), weapon, hs and " headshot" or "",
                    S.where(attacker, lp), S.exploit_status()))
            end
            if attacker ~= nil then
                S.duel_close(U.index(attacker), "oldun")
            end
            if attacker ~= nil and attacker ~= lp then
                N.misc.trash("death", false)
            end
            N.dead_cleanup()
        elseif victim ~= nil then
            S.duel_close(U.index(victim), "baskasi oldurdu")
        end
    end

    -- Round boyunca sana gelen mermiler.
    S.count = function(state, phase, head, unseen)
        local r = S.round or { hits = 0, head = 0, states = {}, order = {}, phases = {}, exploits = {}, unseen = 0 }
        S.round = r
        r.hits = r.hits + 1
        r.head = r.head + (head and 1 or 0)
        r.unseen = r.unseen + (unseen and 1 or 0)
        local s = r.states[state]
        if s == nil then
            s = { hits = 0, head = 0 }
            r.states[state], r.order[#r.order + 1] = s, state
        end
        s.hits, s.head = s.hits + 1, s.head + (head and 1 or 0)
        if head then
            r.phases[phase or 0] = (r.phases[phase or 0] or 0) + 1
        end
        local kind = N.st.fd and "FD" or ((N.ref.on("dt") or N.rc.held("safe")) and "DT")
            or (N.ref.on("hs") and "HS") or "yok"
        r.exploits[kind] = (r.exploits[kind] or 0) + 1
    end

    S.summary = function()
        local r = S.round
        S.round = nil
        if r ~= nil and N.on("hit_log") then
            local states = {}
            for _, state in ipairs(r.order) do
                local s = r.states[state]
                states[#states + 1] = fmt("%s %d/%d", state, s.head, s.hits)
            end
            local phases = {}
            for phase = 0, #K.BRUTE_PHASES do
                if r.phases[phase] ~= nil then
                    phases[#phases + 1] = fmt("%d:%d", phase, r.phases[phase])
                end
            end
            local ex = {}
            for _, kind in ipairs({ "DT", "HS", "FD", "yok" }) do
                if r.exploits[kind] ~= nil then
                    ex[#ex + 1] = fmt("%s %d", kind, r.exploits[kind])
                end
            end
            N.log.line(fmt("round ozeti: %d mermi, %d kafa | %s | kafa fazlari %s | %s | gormedi %d", r.hits, r.head,
                concat(states, ", "), #phases > 0 and concat(phases, " ") or "-", concat(ex, ", "), r.unseen))
        end
        local q = S.shots_round
        S.shots_round = nil
        if q ~= nil and N.on("shot_log") then
            local reasons = {}
            for reason, n in pairs(q.misses) do
                reasons[#reasons + 1] = { reason = tostring(reason), n = n }
            end
            table.sort(reasons, function(a, b)
                if a.n ~= b.n then
                    return a.n > b.n
                end
                return a.reason < b.reason
            end)
            local parts = {}
            for _, item in ipairs(reasons) do
                parts[#parts + 1] = fmt("%s %d", item.reason, item.n)
            end
            N.log.line(fmt("atis ozeti: %d mermi, %d isabet | temiz %d/%d, lag %d/%d | iska: %s", q.shots, q.hits,
                q.clean_hits, q.clean, q.lag_hits, q.lag, #parts > 0 and concat(parts, ", ") or "yok"))
        end
    end

    -- dbg duello: ilk goruste acilir, 3 sn gorus yoksa ya da olumde kapanir.
    S.duel_update = function()
        if not N.on("debug_log") then
            return
        end
        local E, RG = N.exposure, N.rage
        local now, tick = U.now(), U.tick()
        for _, ent in ipairs(E.enemies()) do
            local idx = U.index(ent)
            if idx ~= nil then
                local they = E.sees_now(idx)
                local c = RG.dmg_cache[idx]
                local scan = RG.t[idx] ~= nil and RG.t[idx].scan_tick or nil
                local we = (c ~= nil and c.hittable and tick - c.tick <= 4 and tick >= c.tick)
                    or (scan ~= nil and tick - scan <= 2 and tick >= scan)
                local d = S.duels[idx]
                if (they or we) and d == nil then
                    d = { name = U.name(ent), start = now, last = now, def_n = 0, def_t = 0, def_was = false,
                        speed = 0, their_shots = 0, their_hits = 0, their_dmg = 0, our_shots = 0, our_hits = 0 }
                    S.duels[idx] = d
                end
                if d ~= nil then
                    if they or we then
                        d.last = now
                    end
                    if they and d.they_at == nil then
                        d.they_at = now
                    end
                    if we and d.we_at == nil then
                        d.we_at = now
                    end
                    local fake = N.track.fake(idx)
                    if fake then
                        d.def_t = d.def_t + 1
                        if not d.def_was then
                            d.def_n = d.def_n + 1
                        end
                    end
                    d.def_was = fake
                    d.speed = max(d.speed, U.speed(ent))
                    if now - d.last > 3 then
                        S.duel_close(idx, "ayrildi")
                    end
                end
            end
        end
    end

    S.duel_close = function(idx, result)
        local d = idx ~= nil and S.duels[idx] or nil
        if d == nil then
            return
        end
        S.duels[idx] = nil
        if not N.on("debug_log") then
            return
        end
        local first
        if d.we_at ~= nil and d.they_at ~= nil then
            local diff = d.they_at - d.we_at
            if abs(diff) < 0.02 then
                first = "ayni anda"
            elseif diff > 0 then
                first = fmt("sen %.2fs once", diff)
            else
                first = fmt("o %.2fs once", -diff)
            end
        elseif d.we_at ~= nil then
            first = "sadece sen gordun"
        else
            first = "sadece o gordu"
        end
        N.log.line(fmt("dbg duello: %s | %.2fs | ilk goren: %s | def %d kez %dt | hiz max %d | o: %d ates %d isabet -%d | sen: %d ates %d isabet | %s",
            d.name, U.now() - d.start, first, d.def_n, d.def_t, U.R(d.speed), d.their_shots, d.their_hits,
            U.R(d.their_dmg), d.our_shots, d.our_hits, result))
    end

    S.enemy_fire = function(e)
        local p = S.player(e.userid)
        local lp = N.st.lp
        if p == nil then
            return
        end
        if p == lp then
            N.st.last_shot = U.now()
            N.ex.safe.want_at = U.now()
            return
        end
        local idx = U.index(p)
        local d = idx ~= nil and S.duels[idx] or nil
        if d ~= nil then
            d.their_shots = d.their_shots + 1
        end
    end

    -- dbg ayarlar: native ayarlarin ozeti (yuklemede ve round basinda).
    S.settings_line = function()
        local P = N.ref
        local function onoff(v)
            return v == true and "acik" or (v == false and "kapali" or "?")
        end
        local mode = "?"
        local dt = P.items.dt
        if dt ~= nil then
            local ok, m = pcall(dt.get_mode, dt)
            if ok and U.finite(m) then
                mode = fmt("%d", U.R(m))
            end
        end
        local mds, hcs = {}, {}
        for _, w in ipairs({ "auto", "scout", "awp", "deagle", "revolver" }) do
            local v = P.get("md:" .. w)
            mds[#mds + 1] = U.finite(v) and U.numtext(v) or "?"
            local h = P.get("hc:" .. w)
            hcs[#hcs + 1] = U.finite(h) and U.numtext(h) or "?"
        end
        local fp = P.get("fakeping")
        local ext = P.get("ext_angles")
        N.log.line(fmt("dbg ayarlar: DT %s mod %s | HS %s | fake ping %s | FL %s BLC %s | MD auto/scout/awp/deagle/r8 %s | hc %s | quick stop scout/awp %s/%s | ext angles %s | anti brute (native) %s | autopeek tus %s",
            onoff(P.get("dt")), mode, onoff(P.get("hs")), onoff(fp),
            U.finite(P.get("fl_amount")) and U.numtext(P.get("fl_amount")) or "?", onoff(P.get("fl_blc")),
            concat(mds, "/"), concat(hcs, "/"), onoff(P.multi("qs:scout", "Early")), onoff(P.multi("qs:awp", "Early")),
            onoff(ext), onoff(P.get("anti_brute_native")), onoff(P.get("autopeek"))))
        if fp == true then
            N.log.line("UYARI: fake ping acik (onerilmez)")
        end
    end

    S.settings = function()
        if N.on("debug_log") then
            S.settings_line()
        elseif N.ref.get("fakeping") == true then
            N.log.line("UYARI: fake ping acik (onerilmez)")
        end
    end
end

-------------------------------------------------------------------------------
-- Istatistik (Stats paneli, KD).
-------------------------------------------------------------------------------
do
    local ST = N.stats
    ST.states, ST.order, ST.round_no = {}, {}, 1
    ST.kills, ST.deaths, ST.our_shots, ST.our_hits = 0, 0, 0, 0

    ST.get = function(state)
        local s = ST.states[state]
        if s == nil then
            s = { hits = 0, head = 0, misses = 0 }
            ST.states[state] = s
            ST.order[#ST.order + 1] = state
        end
        return s
    end

    ST.enemy_hit = function(state, head)
        local s = ST.get(state)
        s.hits = s.hits + 1
        if head then
            s.head = s.head + 1
        end
    end

    ST.enemy_miss = function(state)
        local s = ST.get(state)
        s.misses = s.misses + 1
    end

    ST.reset = function()
        ST.states, ST.order = {}, {}
        ST.kills, ST.deaths, ST.our_shots, ST.our_hits = 0, 0, 0, 0
        N.shots.shots_round = nil
        N.shots.round = nil
        N.log.line("istatistikler sifirlandi")
    end

    ST.tick = function()
        N.shots.duel_update()
    end
end

-------------------------------------------------------------------------------
-- Misc: cvar'lar (sol el, 4:3, FPS boost, ragdoll, developer), clan tag, trash talk, otomatik bomba alma,
-- jump scout. Okunamayan cvar'a hic yazilmaz; ilk yazimda senin degerin saklanir, kapatinca geri yazilir.
-------------------------------------------------------------------------------
do
    local U, MI = N.util, N.misc
    MI.cv, MI.paint_at, MI.js_active, MI.ground_speed, MI.last_buy = {}, -1000, nil, 0, -1000
    MI.tag = { text = "Nykle.win", shown = nil, frame = 0, next_at = 0, active = false }
    MI.ext_warned = false

    MI.cvar = function(name)
        local ok, c = pcall(function()
            return cvars[name]
        end)
        if ok and c ~= nil then
            return c
        end
        return nil
    end

    MI.read = function(c, float)
        local ok, v
        if float then
            ok, v = pcall(c.get_float, c)
        else
            ok, v = pcall(c.get_int, c)
        end
        if ok and U.finite(v) then
            return v
        end
        return nil
    end

    MI.write = function(c, value, float)
        if float then
            return pcall(c.set_float, c, value)
        end
        return pcall(c.set_int, c, value)
    end

    MI.hold = function(name, value, float)
        local h = MI.cv[name]
        if h ~= nil and h.bad then
            return false
        end
        local c = MI.cvar(name)
        local cur = c ~= nil and MI.read(c, float) or nil
        if cur == nil then
            MI.cv[name] = { bad = true }
            N.log.line("cvar " .. name .. " okunamadi, dokunulmadi")
            return false
        end
        if h == nil or not h.held then
            h = { orig = cur, held = true, float = float }
            MI.cv[name] = h
        end
        if abs(cur - value) > 1e-3 then
            MI.write(c, value, float)
            local back = MI.read(c, float)
            if back == nil or abs(back - value) > 1e-3 then
                h.bad = true
                h.held = false
                MI.write(c, h.orig, float)
                N.log.line("cvar " .. name .. " yazilamadi")
                return false
            end
        end
        return true
    end

    MI.release = function(name)
        local h = MI.cv[name]
        if h == nil or not h.held then
            return
        end
        h.held = false
        local c = MI.cvar(name)
        if c ~= nil then
            MI.write(c, h.orig, h.float)
        end
        MI.cv[name] = nil
    end

    MI.release_all = function()
        local names = {}
        for name, h in pairs(MI.cv) do
            if h.held then
                names[#names + 1] = name
            end
        end
        for _, name in ipairs(names) do
            MI.release(name)
        end
    end

    -- Saniyede bir (ve yuklemede): cvar'lar ayarlara gore.
    MI.apply = function(force)
        local now = U.now()
        if not force and now >= MI.paint_at and now - MI.paint_at < 1 then
            return
        end
        MI.paint_at = now
        if N.on("left_hand") then
            MI.hold("cl_righthand", 0, false)
        else
            MI.release("cl_righthand")
        end
        local aspect = N.K.ASPECTS[N.v("aspect") or 1]
        if aspect then
            MI.hold("r_aspectratio", aspect, true)
        else
            MI.release("r_aspectratio")
        end
        local fps = N.on("fps_boost")
        for _, name in ipairs(N.K.FPS_CVARS) do
            if fps then
                MI.hold(name, 0, false)
            else
                MI.release(name)
            end
        end
        if fps and N.on("fps_ragdolls") then
            MI.hold("cl_disable_ragdolls", 1, false)
        else
            MI.release("cl_disable_ragdolls")
        end
        if N.on("log_quiet") then
            MI.hold("developer", 0, false)
        else
            MI.release("developer")
        end
        -- Roll yasak: native Extended Angles tusu acik -> uyari (script native tusu birakamaz).
        local ext = N.ref.on("ext_angles")
        if ext and not MI.ext_warned then
            MI.ext_warned = true
            N.log.line("UYARI: Extended Angles acik (roll yasak) -> kapat")
        elseif not ext then
            MI.ext_warned = false
        end
        N.st.roll_warn = ext
    end

    -- Clan tag: "N", "Ny", ... "Nykle.win" (kare 0.35 sn), tam ad 4 kare tutulur. Sadece metin degisince yazilir.
    MI.set_tag = function(text)
        if text == MI.tag.shown then
            return
        end
        if pcall(client.set_clantag, text) then
            MI.tag.shown = text
        end
    end

    MI.clantag = function()
        local T = MI.tag
        if not N.on("clantag") then
            MI.clantag_clear()
            return
        end
        local now = U.now()
        if now < T.next_at and now >= T.next_at - 1 then
            return
        end
        T.next_at = now + 0.35
        T.active = true
        local n = #T.text
        T.frame = T.frame % (n + 4) + 1
        MI.set_tag(T.text:sub(1, min(T.frame, n)))
    end

    MI.clantag_clear = function()
        if MI.tag.active or MI.tag.shown ~= nil then
            MI.tag.active = false
            pcall(client.set_clantag, "")
            MI.tag.shown = nil
        end
    end

    MI.KILL_LINES = {
        { "1", "How smart are you, fuck." }, { "Sleep, fuck you", "sleep, you dickhead." },
        { "Holy fuck", "look at this player." }, { "1-0 loser", "that was easy." },
        { "Where are you going", "you fucking brat?" }, { "Nice anti-aim dickhead", "did you work hard on it?" },
        { "Whoa what was that", "how did I kill you, man?" }, { "NYKLE is superior to all of them, fuck." },
        { "What a brilliant mind", "you idiot." }, { "1-0 loser", "you're miserable without NYKLE." },
        { "Lol", "how hard did I fuck you though." }, { "What Lua are you using, man?" },
        { "Whose CFG are you using, man?" }, { "Nice brain", "dickhead." }, { "Hahahaha", "look how you died." },
        { "Oh man", "holy fuck", "nice fucking CFG." }, { "Oh", "I was AFK tweaking my cheat hahahaha." },
        { "What a cringe nickname you have, man." }, { "Weeb dickhead", "you thought I wouldn't kill you?" },
        { "Fucking loser", "who are you trying to kill?" },
        { "Are you raging because you play bad?", "Hahaha idiot." }, { "Learn while I'm still alive, moron." },
        { "Stupid dude", "turn your monitor on, fuck." }, { "1", "dead again, loser." },
        { "Ez", "oops", "sorry, fuck." }, { "Hahaha how I fucked you." }, { "Big brain", "you straight up threw." },
        { "That was easy, bitch", "what the fuck happened?" }, { "Take this, motherfucker", "fuck off." },
        { "I don't even care", "fuck off, idiot." }, { "Easy, loser", "I'm laughing at you, what a funny guy you are." },
        { "Crushed easily", "weak dog and rat." }, { "Holy fuck, what an easy bot you are." },
        { "1", "am I not replying?", "I don't give a fuck." }, { "I don't even give a fuck about you", "bot." },
        { "Moron", "a plain fucking bot." }, { "N Y K L E > A L L" }, { "Get NYKLE for primordial, you fucking loser." },
    }
    MI.DEATH_LINES = {
        { "Holy fuck what a shitty thing I bought", "wish I had bought NYKLE, fuck." }, { "Ew", "dickhead." },
        { "What are you doing", "you messed-up loser?" }, { "Fuck", "did I even shoot?" },
        { "The cheat shat itself." }, { "HOLY FUCK", "you pissed me off so much." },
        { "Why did you do that", "should've given me a clip", "look at this clown, fuck." },
        { "Ahahaha", "yeah", "the son of a bitch killed me again, stupid dude." }, { "Huh", "I see", "nice cheat." },
        { "Fuck", "which jitter should I turn on, man?" }, { "Ew", "filthy dude", "fuck you." },
        { "Fuck", "where are my teammates", "they piss me off so much." }, { "Fuck", "missed again." },
        { "Fuck", "hello", "am I going to shoot or what?" }, { "Heh", "did you even get how you killed me?" },
        { "Fuck", "that fucking desync thing again." }, { "Fuck", "the client froze", "you're lucky." },
        { "I see", "how do you even play", "you idiot?" }, { "Fuck", "the guy just walked straight", "holy fuck." },
        { "What is this", "where did you kill me from?" }, { "Fucked", "fuck you", "WHAT ARE YOU DOING MAN?" },
        { "What can I say", "dickhead", "you play well." },
        { "Fucking guy", "you pissed me off so much", "what are you doing?" },
        { "Fuck", "I admit it, you beat me." }, { "Fuck bro", "look at my team", "it's a disgrace, man." },
        { "The useless dickheads on my team." }, { "Fuck off, bitch." }, { "Fuck", "shot in the back again." },
        { "You got lucky", "what's next, dickhead?" }, { "My God", "look at this miserable scum." },
        { "Hahaha fuck", "the cheat has a good freestand." }, { "Fuck, I'm sick of you." }, { "Not bad." },
        { "Good tracking", "scumbag." },
    }
    MI.talk_until = -1000

    MI.say = function(line)
        if not N.on("enabled") or not N.on("trash_talk") then
            return
        end
        local cmdname = N.v("tt_chat") == 2 and "say_team" or "say"
        local clean = tostring(line):gsub("[\";\r\n]", "")
        pcall(engine.execute_cmd, fmt('%s "%s"', cmdname, clean))
    end

    MI.trash = function(kind, headshot)
        if not N.on("trash_talk") then
            return
        end
        if kind == "kill" and (not N.on("tt_kill") or (N.on("tt_headshot") and not headshot)) then
            return
        end
        if kind == "death" and not N.on("tt_death") then
            return
        end
        local now = U.now()
        if now < MI.talk_until and now >= MI.talk_until - 30 then
            return
        end
        if random(1, 100) > (N.v("tt_chance") or 100) then
            return
        end
        local lines = kind == "kill" and MI.KILL_LINES or MI.DEATH_LINES
        local per_char = kind == "kill" and 24 or 20
        local base = N.v("tt_delay") or 2.3
        local block = lines[random(1, #lines)]
        local delay = 0
        for _, line in ipairs(block) do
            delay = delay + #line / per_char * base
            local text = line
            pcall(client.delay_call, N.cb.wrap("trash talk", function()
                MI.say(text)
            end), delay)
        end
        MI.talk_until = now + delay + 0.5
    end

    -- M5: native buybot bombalari zaten aliyorsa hicbir sey; yoksa round basinda bir kez (3 sn'de en fazla bir).
    MI.buy = function()
        if not N.on("auto_buy") then
            return
        end
        local now = U.now()
        if now >= MI.last_buy and now - MI.last_buy < 3 then
            return
        end
        local P = N.ref
        if P.get("buybot") == true and P.multi("buybot_nades", "High Explosive") == true
            and P.multi("buybot_nades", "Smoke") == true and P.multi("buybot_nades", "Fire") == true then
            return
        end
        MI.last_buy = now
        pcall(client.delay_call, N.cb.wrap("auto buy", function()
            pcall(engine.execute_cmd, "buy hegrenade; buy smokegrenade; buy molotov; buy incgrenade")
        end), 0.3)
    end

    -- M8: scout ile durarak ziplayinca autostrafer kalkistan inise kadar kapali.
    MI.jump_scout = function()
        local st = N.st
        local ref = N.ref.items.autostrafer
        if ref == nil then
            return
        end
        if MI.js_type == nil then
            local ok, v = pcall(ref.get, ref)
            MI.js_type = (ok and type(v) == "boolean") and "ok" or "bad"
            if MI.js_type == "bad" then
                N.log.line("jump scout: autostrafer onay kutusu degil, kapali")
            end
        end
        if MI.js_type ~= "ok" then
            return
        end
        if not st.airborne or st.ladder then
            if MI.js_active then
                N.ov.release("autostrafer")
            end
            MI.js_active = nil
            MI.ground_speed = st.ladder and 1000 or (st.speed or 0)
            return
        end
        if MI.js_active == nil then
            MI.js_active = N.on("jump_scout") and st.weapon == "ssg08" and MI.ground_speed < 10
        end
        if MI.js_active then
            N.ov.set("autostrafer", ref, false)
        end
    end

    MI.paint = function()
        MI.apply(false)
        MI.clantag()
    end
end

-------------------------------------------------------------------------------
-- Cizim: nisangah gostergeleri, manuel oklar, sol liste, resolver paneli, istatistik paneli.
-------------------------------------------------------------------------------
do
    local U, D = N.util, N.draw
    D.ok = false

    D.init = function()
        local ok1, small = pcall(render.create_font, "Verdana", 12, 700, e_font_flags.DROPSHADOW)
        local ok2, big = pcall(render.create_font, "Verdana", 24, 700, e_font_flags.DROPSHADOW)
        D.small = ok1 and small or nil
        D.big = ok2 and big or nil
        D.ok = D.small ~= nil
    end

    D.color = function(key, r, g, b)
        local c = N.ui.e[key]
        if c ~= nil then
            local ok, v = pcall(c.get, c)
            if ok and v ~= nil then
                return v
            end
        end
        return color_t(r, g, b, 255)
    end

    D.text = function(font, s, x, y, col, center)
        pcall(render.text, font, s, vec2_t(x, y), col, center == true)
    end

    D.crosshair = function(sx, sy)
        if not N.on("indicators") or D.small == nil then
            return
        end
        local st, X = N.st, N.ex
        local col = D.color("accent", 150, 190, 255)
        local white = color_t(230, 230, 230, 255)
        local x, y = sx / 2, sy / 2 + 22
        D.text(D.small, "NYKLE.WIN", x, y, col, true)
        y = y + 13
        D.text(D.small, tostring(st.label or st.state):upper(), x, y, white, true)
        y = y + 13
        local flags = {}
        if N.ref.on("dt") then
            flags[#flags + 1] = "DT"
        end
        if N.ref.on("hs") then
            flags[#flags + 1] = "HS"
        end
        if st.state == "Freestanding" then
            flags[#flags + 1] = "FS"
        end
        if X.own_def_active() or X.forced then
            flags[#flags + 1] = "DEF"
        end
        if #flags > 0 then
            D.text(D.small, concat(flags, " "), x, y, white, true)
            y = y + 13
        end
        local extra = {}
        if (N.aa.applied or 0) > 0 then
            extra[#extra + 1] = "BRUTE " .. N.aa.applied
        end
        local target = N.aa.target_ent
        local idx = target ~= nil and U.index(target) or nil
        local t = idx ~= nil and N.rage.t[idx] or nil
        if t ~= nil and t.level > 0 then
            extra[#extra + 1] = "RES " .. t.level
        end
        local info = idx ~= nil and N.rage.scan[idx] or nil
        if info ~= nil and info.ba and U.tick() - info.tick <= 8 then
            extra[#extra + 1] = "BAIM"
        end
        if X.clean then
            extra[#extra + 1] = "CLEAN SHOT"
        end
        if X.air.latched then
            extra[#extra + 1] = "AIR LC"
        end
        local tick = U.tick()
        if tick <= X.anti_until and tick >= X.anti_until - 8 then
            extra[#extra + 1] = "ANTI-PEEK"
        end
        if N.peek.mode ~= nil then
            extra[#extra + 1] = "AI PEEK"
        end
        if N.afk.on then
            extra[#extra + 1] = "AFK"
        end
        for _, s in ipairs(extra) do
            D.text(D.small, s, x, y, col, true)
            y = y + 13
        end
    end

    D.arrows = function(sx, sy)
        if not N.on("arrows") then
            return
        end
        local m = N.st.manual or 0
        if m ~= 1 and m ~= 3 then
            return
        end
        local col = D.color("arrow_color", 150, 190, 255)
        local x = m == 1 and sx / 2 - 55 or sx / 2 + 55
        pcall(render.triangle_filled, vec2_t(x, sy / 2), 12, col, m == 1 and 270 or 90)
    end

    D.left = function(sx, sy)
        if not N.on("left_ind") or D.big == nil then
            return
        end
        local st, X, P = N.st, N.ex, N.ref
        local items = {}
        local function add(text, col)
            items[#items + 1] = { text, col }
        end
        local green, yellow, red, white = color_t(130, 230, 130, 255), color_t(240, 210, 90, 255),
            color_t(240, 90, 90, 255), color_t(230, 230, 230, 255)
        local now, tick = U.now(), U.tick()
        if P.on("dt") then
            local c, m = P.charge()
            add("DT", (m > 0 and c >= m) and green or (c > 0 and yellow or red))
        elseif P.items.dt ~= nil then
            add("DT OFF", red)
        end
        if P.on("hs") then
            add("HS", white)
        end
        if st.fd then
            add("FD", white)
        end
        if X.own_def_active() or X.forced then
            add("DEF", white)
        end
        if N.aa.choked() >= 13 and not X.air.latched then
            add("LC", white)
        end
        if X.air.latched then
            add("AIR LC", yellow)
        end
        local md = N.rage.last_md
        local ovr_v, ovr = P.md_eff(st.wgroup)
        if md ~= nil and tick - md.tick <= 8 and tick >= md.tick then
            add("MD " .. U.numtext(md.v), yellow)
        elseif ovr and ovr_v ~= nil then
            add("MD " .. U.numtext(ovr_v), white)
        end
        local target = N.aa.target_ent
        local idx = target ~= nil and U.index(target) or nil
        local info = idx ~= nil and N.rage.scan[idx] or nil
        if info ~= nil and tick - info.tick <= 8 then
            if info.ba then
                add("BAIM", white)
            end
            if (info.sp or 0) > 0 then
                add("SAFE", white)
            end
        end
        if st.state == "Freestanding" then
            add("FS", white)
        end
        if st.move_state == "Peek" then
            add("PEEK", white)
        end
        if N.afk.on then
            add("AFK", white)
        end
        if st.roll_warn then
            add("ROLL!", red)
        end
        if st.fd_hint_until ~= nil and now < st.fd_hint_until then
            add("FD!", red)
        end
        local y = sy * 0.66
        for _, item in ipairs(items) do
            local ok, size = pcall(render.get_text_size, D.big, item[1])
            local w = (ok and size ~= nil) and size.x or 60
            pcall(render.rect_fade, vec2_t(4, y - 2), vec2_t(w + 24, 28), color_t(0, 0, 0, 120), color_t(0, 0, 0, 0),
                true)
            D.text(D.big, item[1], 10, y, item[2], false)
            y = y - 30
        end
    end

    D.res_panel = function(sx, sy)
        if not N.on("res_panel") or D.small == nil then
            return
        end
        local target = N.aa.target_ent
        if target == nil then
            return
        end
        local idx = U.index(target)
        local p = N.mem.entry(target)
        local t = idx ~= nil and N.rage.t[idx] or nil
        local tr = idx ~= nil and N.track.p[idx] or nil
        local scale = (N.v("panel_size") or 160) / 100
        local x = sx * (N.v("panel_x") or 560) / 1000
        local y = sy * (N.v("panel_y") or 380) / 1000
        local lines = {
            U.name(target),
            fmt("RES L%d", t ~= nil and t.level or 0),
            fmt("kafa %d/%d", U.R(p ~= nil and p.hider.h or 0), U.R(p ~= nil and p.hider.n or 0)),
            fmt("isabet %d/%d", tr ~= nil and (tr.our_hits or 0) or 0, tr ~= nil and (tr.our_shots or 0) or 0),
            fmt("faz %d", N.brute.stage_for(target, N.st.move_state)),
        }
        local h = 14 * scale
        pcall(render.rect_filled, vec2_t(x - 6, y - 4), vec2_t(110 * scale, h * #lines + 8), color_t(0, 0, 0, 110), 4)
        local col = D.color("accent", 150, 190, 255)
        for i, s in ipairs(lines) do
            D.text(D.small, s, x, y + (i - 1) * h, i == 1 and col or color_t(230, 230, 230, 255), false)
        end
    end

    D.stats_panel = function(sx, sy)
        if not N.on("stats_panel") or D.small == nil then
            return
        end
        local ST = N.stats
        local x, y = sx - 230, sy * 0.3
        D.text(D.small, fmt("KD %d/%d | atis %d/%d", ST.kills or 0, ST.deaths or 0, ST.our_hits or 0, ST.our_shots or 0),
            x, y, color_t(230, 230, 230, 255), false)
        for _, state in ipairs(ST.order) do
            local s = ST.states[state]
            y = y + 13
            D.text(D.small, fmt("%s: kafa %d/%d, iska %d", state, s.head, s.hits, s.misses), x, y,
                color_t(200, 200, 200, 255), false)
        end
    end

    D.paint = function()
        local st = N.st
        if not st.on or not st.alive then
            return
        end
        local ok, size = pcall(render.get_screen_size)
        if not ok or size == nil then
            return
        end
        local sx, sy = size.x, size.y
        if not U.finite(sx) or not U.finite(sy) then
            return
        end
        D.crosshair(sx, sy)
        D.arrows(sx, sy)
        D.left(sx, sy)
        D.res_panel(sx, sy)
        D.stats_panel(sx, sy)
    end
end

-------------------------------------------------------------------------------
-- Yasam dongusu: ac / kapat, olum temizligi, tick basi.
-------------------------------------------------------------------------------
do
    local U = N.util

    N.enable = function()
        N.ov.hold_neutral(true)
        N.misc.apply(true)
        N.log.line("acildi: native AA tasiyicilari notrde, ayarlar uygulandi")
    end

    -- Kapatinca her sey geri: native ayarlar (anlik kopyalar), sarj, cvar'lar, clan tag.
    N.disable = function()
        N.ov.release_all()
        N.rc.release_all()
        N.misc.release_all()
        N.misc.clantag_clear()
        N.peek.reset()
        N.afk.on, N.afk.auto, N.afk.anchor = false, false, nil
        N.ex.reset_life()
        N.misc.js_active = nil
        N.log.line("kapatildi: native ayarlar, sarj ve cvar'lar geri verildi")
    end

    N.check_enable = function()
        local st = N.st
        local on = N.on("enabled")
        if on ~= st.enabled then
            st.enabled = on
            if on then
                N.enable()
            else
                st.on = false
                N.disable()
            end
        end
        return on
    end

    -- Harita / oturum degisimi (game_newmap, yerel oyuncu gidip geri geldi, tickcount geri gitti): tick'e bagli
    -- butun durum silinir; eski haritanin tick'leri yeni haritada "gelecekte" kalmasin.
    N.map_reset = function()
        local st = N.st
        N.ex.tp_reset()
        N.exposure.reset()
        N.track.p = {}
        N.rage.map_reset()
        N.mem.kc = {}
        N.aa.cover, N.aa.cover_auto, N.aa.cover_tick = nil, false, -1000
        N.state.peek_until = -1000
        N.rc.release_all()
        N.mem.save(false)
        st.map_tick = U.tick()
    end

    -- PAINT: game_newmap gelmese de (baglanirken kacabilir) degisimi yakala.
    N.map_watch = function(lp)
        local st = N.st
        local tick = U.tick()
        if lp == nil then
            st.paint_gone = true
            return
        end
        local back = st.paint_tick ~= nil and tick < st.paint_tick - 64
        if st.paint_gone or back then
            st.paint_gone = false
            if st.paint_tick ~= nil then
                N.map_reset()
            end
        end
        st.paint_tick = tick
    end

    -- Olunce bir kez (SETUP_COMMAND, player_death ya da PAINT'ten; dogunca / round basinda sifirlanir).
    N.dead_cleanup = function()
        local st = N.st
        if st.dead then
            return
        end
        st.dead, st.alive, st.on = true, false, false
        N.afk.death()
        N.rc.release_all()
        N.ex.reset_life()
        N.rage.reset_life()
        N.ov.release_prefix("fs_states:")
        N.aa.fs_item = nil
        if N.misc.js_active then
            N.ov.release("autostrafer")
        end
        N.misc.js_active = nil
        N.log.flush()
    end

    N.tick.begin = function(cmd)
        local st = N.st
        N.check_enable()
        local ok, lp = pcall(entity_list.get_local_player)
        if not ok or lp == nil then
            st.lp, st.on, st.alive = nil, false, false
            if st.had_lp then
                st.had_lp = false
                N.map_reset()
            end
            return false
        end
        st.lp, st.had_lp, st.idx = lp, true, U.index(lp)
        if not U.alive(lp) then
            N.dead_cleanup()
            return false
        end
        if st.dead then
            st.dead = false
            st.spawn_at = U.now()
            N.afk.spawn()
        end
        st.alive = true
        st.on = st.enabled
        st.tick = U.tick()
        st.cmdn = cmd ~= nil and cmd.command_number or nil
        return st.on
    end

    -- SETUP_COMMAND (SPEC §3.3 sirasi).
    N.setup = function(cmd)
        if not N.tick.begin(cmd) then
            return
        end
        local st = N.st
        N.track.fallback()
        N.exposure.enemies()
        st.threat = N.aa.target()
        N.exposure.update()
        N.aa.cover_update()
        N.state.detect(cmd, nil)
        N.ex.clean_update()
        N.peek.update(cmd)
        N.aa.crouch_keeper(cmd)
        N.misc.jump_scout()
        N.ex.air_update(cmd)
        N.ex.safe_recharge()
        N.rc.tick()
        N.rc.watchdog()
        N.ex.defensive()
        N.rage.prepare()
        N.brute.process_pending()
        N.shots.expire()
        N.stats.tick()
        N.ov.hold_neutral(false)
    end

    N.antiaim = function(ctx, cmd, unpred)
        local st = N.st
        if not st.on or not st.alive or st.lp == nil then
            return
        end
        N.state.detect(cmd, unpred)
        N.aa.apply(ctx, cmd)
        N.ex.fakelag(ctx)
    end

    N.paint = function()
        local st = N.st
        N.ui.visibility()
        N.ui.recommend()
        N.ref.retry()
        local enabled = N.check_enable()
        if enabled then
            local ok, lp = pcall(entity_list.get_local_player)
            if ok then
                N.map_watch(lp)
            end
            if ok and lp ~= nil and not U.alive(lp) then
                N.dead_cleanup()
            elseif ok and lp == nil then
                N.dead_cleanup()
            end
            N.misc.paint()
            N.draw.paint()
            N.ov.hold_neutral(false)
            N.shots.expire()
            N.brute.process_pending()
        end
        N.log.timer()
    end

    N.shutdown = function()
        N.shots.summary()
        N.ov.release_all()
        N.rc.release_all()
        N.misc.release_all()
        N.misc.clantag_clear()
        N.mem.save(true)
        N.log.line("script kaldirildi: native ayarlar, sarj ve cvar'lar geri verildi")
        N.log.flush()
    end
end

-------------------------------------------------------------------------------
-- Callback kaydi: her callback tek sarmalayicidan; her islemci pcall icinde (hata ilk 3 kez yazilir, 50'de
-- kapatilir). EVENT her olay adi icin 3. argumanli filtreyle bir kez; filtre yok sayilirsa ad kontrol edilir.
-------------------------------------------------------------------------------
do
    local U, C = N.util, N.cb

    C.on = function(key, name, fn, event)
        local list_key = event ~= nil and ("EVENT:" .. event) or key
        local list = C.handlers[list_key]
        if list == nil then
            list = {}
            C.handlers[list_key] = list
            local wrapper
            if event ~= nil then
                wrapper = function(ev)
                    if ev ~= nil then
                        local okn, nm = pcall(function()
                            return ev.name
                        end)
                        if okn and nm ~= nil and nm ~= event then
                            return
                        end
                    end
                    for _, h in ipairs(list) do
                        C.run(h, ev)
                    end
                end
                local ok = pcall(callbacks.add, e_callbacks.EVENT, wrapper, event)
                if not ok then
                    N.log.line("callback eklenemedi: EVENT " .. event)
                end
            else
                wrapper = function(...)
                    for _, h in ipairs(list) do
                        C.run(h, ...)
                    end
                end
                local ok = pcall(callbacks.add, e_callbacks[key], wrapper)
                if not ok then
                    N.log.line("callback eklenemedi: " .. key)
                end
            end
        end
        list[#list + 1] = { name = name, fn = fn, errors = 0, dead = false }
    end

    C.register = function()
        local st = N.st
        C.on("SETUP_COMMAND", "setup_command", function(cmd)
            N.setup(cmd)
        end)
        C.on("ANTIAIM", "antiaim", function(ctx, cmd, unpred)
            N.antiaim(ctx, cmd, unpred)
        end)
        C.on("HITSCAN", "hitscan", function(ctx)
            if st.on and st.alive then
                N.rage.hitscan(ctx)
            end
        end)
        C.on("TARGET_SELECTION", "target_selection", function(ctx)
            if st.on and st.alive then
                N.rage.select(ctx)
            end
        end)
        C.on("AIMBOT_SHOOT", "aimbot_shoot", function(shot)
            if st.enabled then
                N.shots.on_shoot(shot)
            end
        end)
        C.on("AIMBOT_HIT", "aimbot_hit", function(hit)
            if st.enabled then
                N.shots.on_hit(hit)
            end
        end)
        C.on("AIMBOT_MISS", "aimbot_miss", function(miss)
            if st.enabled then
                N.shots.on_miss(miss)
            end
        end)
        C.on("NET_UPDATE", "net_update", function()
            if not st.enabled then
                return
            end
            local ok, lp = pcall(entity_list.get_local_player)
            if not ok or lp == nil then
                return
            end
            st.lp = lp
            N.track.update()
            N.ex.own_update()
        end)
        C.on("PAINT", "paint", function()
            N.paint()
        end)
        C.on("SHUTDOWN", "shutdown", function()
            N.shutdown()
        end)
        C.on("EVENT", "round_prestart", function()
            if st.enabled then
                N.rc.release_all()
            end
        end, "round_prestart")
        C.on("EVENT", "round_start", function()
            if not st.enabled then
                return
            end
            N.rc.release_all()
            N.shots.summary()
            N.stats.round_no = (N.stats.round_no or 1) + 1
            st.last_round_start = U.now()
            N.misc.buy()
            N.shots.settings()
            N.log.flush()
        end, "round_start")
        C.on("EVENT", "round_end", function()
            if not st.enabled then
                return
            end
            N.mem.save(false)
            N.log.flush()
        end, "round_end")
        C.on("EVENT", "player_death", function(e)
            if st.enabled then
                N.shots.on_death(e)
            end
        end, "player_death")
        C.on("EVENT", "player_hurt", function(e)
            if st.enabled then
                N.shots.on_hurt(e)
            end
        end, "player_hurt")
        C.on("EVENT", "bullet_impact", function(e)
            if st.enabled then
                N.brute.impact(e)
            end
        end, "bullet_impact")
        C.on("EVENT", "player_spawn", function(e)
            if not st.enabled then
                return
            end
            local p = N.shots.player(e.userid)
            local ok, lp = pcall(entity_list.get_local_player)
            if not ok or lp == nil or p ~= lp then
                return
            end
            st.spawn_at = U.now()
            N.afk.spawn()
            -- DM: 60 sn round_start yoksa ozet ve bomba dogusta.
            if U.now() - st.last_round_start > 60 then
                N.shots.summary()
                N.misc.buy()
            end
        end, "player_spawn")
        C.on("EVENT", "weapon_fire", function(e)
            if st.enabled then
                N.shots.enemy_fire(e)
            end
        end, "weapon_fire")
        C.on("EVENT", "game_newmap", function()
            N.shots.summary()
            N.map_reset()
            N.log.flush()
        end, "game_newmap")
    end
end

-------------------------------------------------------------------------------
-- Yukleme
-------------------------------------------------------------------------------
do
    local U = N.util

    N.step = function(name, fn)
        local ok, err = pcall(fn)
        if not ok then
            N.log.line(fmt("%s hata verdi: %s", name, tostring(err)))
        end
        return ok
    end

    N.load = function()
        pcall(math.randomseed, floor(U.now() * 1000) % 2147483647)
        N.step("dosya sistemi", N.fs.init)
        N.step("menu", N.ui.build)
        N.step("native referanslar", N.ref.resolve)
        N.step("exploit kontrolu", N.ex.init)
        N.step("hafiza", N.mem.load)
        N.step("log dosyasi", N.log.open)
        N.step("cizim", N.draw.init)
        local text = fmt("V%s (%s edition) yuklendi", N.VERSION, N.EDITION)
        if N.fs.ok then
            text = text .. fmt(" (hafiza: %d oyuncu)", N.mem.count)
        else
            text = text .. fmt(" (hafiza: dosya yok) (log dosyasi yok: %s)", tostring(N.fs.why or "?"))
        end
        if not N.ex.has_shift then
            text = text .. " (defensive yok: eski primordial)"
        end
        local okn, uname = pcall(function()
            return user.name
        end)
        if okn and type(uname) == "string" and uname ~= "" then
            text = text .. " | " .. uname
        end
        N.log.load_entry = N.log.line(text)
        if N.fs.ok then
            N.log.line("log dosyasi: " .. N.log.file .. " (MOD, csgo klasoru)")
        end
        for _, note in ipairs(N.log.notes) do
            N.log.line(note)
        end
        if N.ui.failed > 0 then
            N.log.line(fmt("toplam %d menu ogesi olusturulamadi", N.ui.failed))
        end
        N.log.flush()
        N.cb.register()
        N.st.enabled = N.on("enabled")
        if N.st.enabled then
            N.step("acilis", function()
                N.ov.hold_neutral(true)
                N.misc.apply(true)
            end)
        end
        N.step("ayarlar", N.shots.settings)
    end
end

N.load()
