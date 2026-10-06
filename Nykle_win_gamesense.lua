--[[
    Nykle.win lua V1.0  |  GameSense edition  |  GameSense (CS:GO) icin HvH anti-aim, exploit ve resolver lua'si

    Neverlose surumunun (Nykle.win.lua V1.0) butun ozelliklerinin GameSense API'sine tasinmis hali.
    Kurar kurmaz calisir: butun varsayilanlar ayarlanmis halde gelir ("Always use recommended
    settings" acik kaldikca en iyi bilinen degerler korunur). Menu: AA sekmesi > Anti-aimbot angles.

    Neverlose surumunden farklar (GameSense API'sinin izin verdigi kadar, bkz. README_GAMESENSE.md):
      - GameSense'te AA'nin "hidden" (defensive) acilari icin API yok: defensive penceresi tickbase'den
        anlasilir ve o tick'lerde pitch / yaw menu ayarlari degistirilir (topluluk lua'larinin yontemi).
      - Teleport: cmd.discharge_pending (Neverlose'da rage.exploit:force_teleport).
      - DT sarji icin API yok: tickbase ile tick sayisi arasindaki farktan tahmin edilir.
      - Safe recharge: GameSense'te sarji bekletme API'si yok; DT kisa sure kapatilarak sarj ertelenir.
      - Resolver: safe point ve body aim kararlari oyuncu listesinden (plist) DUSMAN BASINA verilir
        (Neverlose'da hepsi tek ayardi). GameSense'e ozel ek: NYKLE Resolver 2.5'in "body yaw
        hipotezleri" (Force body yaw): Force safe point'in de cozemedigi dusmanda sirayla +58 / -58 /
        0 / +29 / -29 denenir, kafa isabeti alan aci tutulur.
      - Rage ayarlari GameSense'te silah grubuna gore ayri ("Weapon type"): sniper'da Min. damage
        sadece o silahin grubu seciliyken degistirilir, silah degisince eski grubun degeri geri yazilir.
      - Kapatinca / config kaydederken GameSense ayarlarinin hepsi senin degerlerine geri doner.
      - Ek: Misc sekmesinde NYKLE Yaw'daki animasyonlu "Nykle.win" clan tag'i ve trash talk (NYKLE Yaw'daki
        cumlelerin Ingilizcesi; oldurunce / olunce / sadece headshot, olasilik, tum chat / takim chati,
        gecikme ayarlanir). Ikisi de varsayilan acik.

    Kurulum, ayarlar ve degisiklikler icin README_GAMESENSE.md'ye bak.
    Dosya adi Nykle_win_gamesense.lua kalmali: GameSense script adindaki fazladan noktalari dosya yolu
    gibi okuyabiliyor (lua acilmaz), o yuzden ad alt cizgili.
]]

-- Log kaydi (V1.0.10): konsola yazilan her satir saatiyle hafizada da tutulur. Home > Console'daki
-- dugmeler hepsini panoya kopyalar ya da konsola yeniden yazar. Ayrica nykle_log.txt'ye (CS:GO klasoru)
-- round basinda, harita degisince, her 5 dakikada ve kapanista yazilir; onceki oturumlarin loglari
-- dosyada kalir ("Clear saved logs" ile silinir). Sadece bu lua'nin satirlari tutulur.
local nlog = { raw = print, lines = {}, cap = 12000, trim = 1000, file = "nykle_log.txt", old = "",
    old_cap = 2000000, dirty = false, saved = -1000, save_every = 300 }

nlog.stamp = function()
    local ok, h, m, s = pcall(client.system_time)
    if ok and type(h) == "number" and type(m) == "number" and type(s) == "number" then
        return ("%02d:%02d:%02d"):format(h, m, s)
    end
    local ok_rt, t = pcall(globals.realtime)
    return (ok_rt and type(t) == "number") and ("%.1f"):format(t) or "--"
end

nlog.push = function(line)
    local lines = nlog.lines
    lines[#lines + 1] = nlog.stamp() .. " " .. line
    if #lines > nlog.cap + nlog.trim then
        local keep = {}
        for i = #lines - nlog.cap + 1, #lines do
            keep[#keep + 1] = lines[i]
        end
        nlog.lines = keep
    end
    nlog.dirty = true
end

-- all: onceki oturumlarin (dosyadaki) loglari da.
nlog.text = function(all)
    local body = table.concat(nlog.lines, "\n")
    if all and nlog.old ~= "" then
        return nlog.old .. "\n" .. body
    end
    return body
end

-- GameSense readfile / writefile (CS:GO klasorune gore yol). Yoksa ya da hata verirse dosya yazilmaz.
nlog.load_old = function()
    local _, read = pcall(function() return readfile end)
    if type(read) ~= "function" then
        return
    end
    local ok, text = pcall(read, nlog.file)
    if not ok or type(text) ~= "string" or text == "" then
        return
    end
    if #text > nlog.old_cap then
        text = text:sub(#text - nlog.old_cap + 1)
        text = text:gsub("^[^\n]*\n", "", 1)
    end
    nlog.old = text:gsub("\n+$", "")
end

nlog.save = function()
    local _, write = pcall(function() return writefile end)
    local ok_rt, now = pcall(globals.realtime)
    if ok_rt and type(now) == "number" then
        nlog.saved = now
    end
    if type(write) ~= "function" then
        return false
    end
    local ok = pcall(write, nlog.file, nlog.text(true) .. "\n")
    if ok then
        nlog.dirty = false
    end
    return ok
end

-- Panoya kopyalama: CS:GO'nun VGUI_System010 arayuzu (SetClipboardText, sanal tablo 9; GameSense'in
-- clipboard kutuphanesiyle ayni). FFI ya da arayuz yoksa false.
nlog.clipboard = function(text)
    local _, create = pcall(function() return client.create_interface end)
    if type(create) ~= "function" then
        return false
    end
    local ok_ffi, ffi = pcall(require, "ffi")
    if not ok_ffi or type(ffi) ~= "table" then
        return false
    end
    local ok, done = pcall(function()
        local iface = create("vgui2.dll", "VGUI_System010")
        if iface == nil then
            return false
        end
        local vt = ffi.cast("void***", iface)
        local set_text = ffi.cast("void(__thiscall*)(void*, const char*, int)", vt[0][9])
        set_text(vt, text, #text)
        return true
    end)
    return ok and done == true
end

-- Bu oturumun butun satirlari konsola (dogrudan; tekrar kayda girmez).
nlog.dump = function()
    local lines = nlog.lines
    nlog.raw(("[Nykle.win] ===== tum loglar: %d satir (bu oturum) ====="):format(#lines))
    for _, line in ipairs(lines) do
        nlog.raw(line)
    end
    nlog.raw("[Nykle.win] ===== loglarin sonu =====")
end

nlog.load_old()

-- Lua'nin butun print'leri buradan gecer: konsola yazilir ve kayda girer.
local function print(...)
    local parts = {}
    for i = 1, select("#", ...) do
        parts[i] = tostring((select(i, ...)))
    end
    pcall(nlog.push, table.concat(parts, " "))
    return nlog.raw(...)
end

-- Butun script tek fonksiyonda calisir: yuklenirken hata olursa en alttaki xpcall hatayi satir numarasi
-- ile konsola yazar (girinti yok; govde dosyanin sonuna kadar surer).
local function nykle_main()

local SCRIPT = "Nykle.win"
-- Her guncellemede artar; yuklenince konsola yazilir ki hangi surumun calistigi belli olsun.
local VERSION = "1.0.16"
local EDITION = "GameSense"
local DEG = "\194\176"

local floor, max, min, sqrt, huge, random, abs = math.floor, math.max, math.min, math.sqrt, math.huge, math.random, math.abs
local atan2 = math.atan2 or math.atan

-------------------------------------------------------------------------------
-- Guvenli API erisimi
-------------------------------------------------------------------------------

local function finite(v)
    return type(v) == "number" and v == v and v > -huge and v < huge
end

-- pcall'li cagri: hata verirse nil doner (en fazla 4 deger).
local function try(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then
        return a, b, c, d
    end
    return nil
end

-- Sabitler (LuaJIT'te ana govdede en fazla 200 yerel degisken olabildigi icin tek tabloda).
local K = {
    EXPOSE_EVERY = 2,        -- tick; iz cizmek ucuz degil, her tick gerekmez
    LOOKAHEAD = 0.2,         -- saniye; bu kadar sonra nerede olacagina da bakilir
    PEEK_HOLD = 8,           -- tick; gorus kesilince Peek'te bu kadar daha kalinir
    GRAVITY = 800,           -- sv_gravity
    JUMP_SPEED = 301.99,     -- ziplama hizi
    OTHER_HOLD = 12,         -- tick; tehdit disindaki bir dusmanin gorusu bu kadar gecerli
    BRUTE_RADIUS = 40,       -- birim; kafanin bu kadar yakinindan gecen mermi anti-brute'u ilerletir
    BRUTE_DEBOUNCE = 0.1,    -- sn; ayni dusmanin bu kadar icindeki ikinci mermisi ayni atis sayilir
    MISS_WINDOW = 0.15,      -- sn; kafanin yanindan gecen mermiden sonra hasar gelmezse iska
    MEMORY_LIMIT = 64,       -- hatirlanan en fazla oyuncu
    RESOLVER_WINDOW = 4,     -- son kac resolver sonucu seviyeyi belirler
    AIM_TARGET_HOLD = 1.5,   -- sn; aimbot'un son hedefi bu kadar resolver hedefi sayilir
    SHOT_MEMORY = 5,         -- sn; sonucu gelmeyen atis kaydi
    FORCE_STALL = 0.5,       -- sn; Force safe point / body aim ates engelliyorsa Prefer'e inilir
    RECHARGE_HOLD_MAX = 1.2, -- sn; Safe recharge en fazla bu kadar bekletir
    DT_SHOT_GRACE = 1.0,     -- sn; atistan sonra DT istatistigi sayilmaz
    MOVETYPE_LADDER = 9,
}

-- Bir olay fonksiyonu hata verirse script sessizce durmasin ve konsol dolmasin: hata bir kez
-- yazilir, sonraki olaylarda yine calisir.
local protect
do
    local handler_errors = {}
    protect = function(name, fn)
        return function(...)
            local ok, err = pcall(fn, ...)
            if not ok and not handler_errors[name] then
                handler_errors[name] = true
                print(("[%s] %s hata verdi: %s"):format(SCRIPT, name, tostring(err)))
            end
            if ok then
                return err
            end
        end
    end
end

-- Olay kaydi: bir olay kaydedilemezse script yuklenmeyi birakmaz, konsola hangisi oldugu yazilir.
local function listen(name, fn)
    local ok, err = pcall(client.set_event_callback, name, fn)
    if not ok then
        print(("[%s] %s olayi kaydedilemedi: %s"):format(SCRIPT, name, tostring(err)))
    end
    return ok
end

-- GameSense'te globals fonksiyondur (Neverlose'da alan).
local function tickcount()
    local v = try(globals.tickcount)
    return finite(v) and v or 0
end

local function realtime()
    local v = try(globals.realtime)
    return finite(v) and v or 0
end

local function curtime()
    local v = try(globals.curtime)
    return finite(v) and v or 0
end

local function frametime()
    local v = try(globals.frametime)
    return finite(v) and v or 0.016
end

local function tick_interval()
    local v = try(globals.tickinterval)
    return finite(v) and v > 0 and v or 1 / 64
end

local function vector(x, y, z)
    return { x = x or 0, y = y or 0, z = z or 0 }
end

local function prop(ent, name, index)
    if ent == nil then
        return nil
    end
    local ok, a, b, c = pcall(entity.get_prop, ent, name, index)
    if ok then
        return a, b, c
    end
    return nil
end

local function local_player()
    local me = try(entity.get_local_player)
    if finite(me) and me > 0 then
        return me
    end
    return nil
end

local function alive(ent)
    return ent ~= nil and try(entity.is_alive, ent) == true
end

local function dormant(ent)
    return ent ~= nil and try(entity.is_dormant, ent) == true
end

local function is_enemy(ent)
    return ent ~= nil and try(entity.is_enemy, ent) == true
end

local function player_name(ent)
    local name = ent ~= nil and try(entity.get_player_name, ent) or nil
    if type(name) == "string" and name ~= "" then
        return name
    end
    return "?"
end

local function origin_of(ent)
    if ent == nil then
        return nil
    end
    local x, y, z = try(entity.get_origin, ent)
    if finite(x) and finite(y) and finite(z) then
        return vector(x, y, z)
    end
    x, y, z = prop(ent, "m_vecOrigin")
    if finite(x) and finite(y) and finite(z) then
        return vector(x, y, z)
    end
    return nil
end

local function hitbox_of(ent, hitbox)
    if ent == nil then
        return nil
    end
    local x, y, z = try(entity.hitbox_position, ent, hitbox)
    if finite(x) and finite(y) and finite(z) and (x ~= 0 or y ~= 0 or z ~= 0) then
        return vector(x, y, z)
    end
    return nil
end

local function velocity_of(ent)
    local x, y, z = prop(ent, "m_vecVelocity")
    return vector(finite(x) and x or 0, finite(y) and y or 0, finite(z) and z or 0)
end

local function speed2d(ent)
    local v = velocity_of(ent)
    return sqrt(v.x * v.x + v.y * v.y)
end

local function on_ground(ent)
    local flags = prop(ent, "m_fFlags")
    return bit.band(finite(flags) and flags or 0, 1) ~= 0
end

-- Goz konumu: kendi icin client.eye_position, dusman icin origin + m_vecViewOffset[2].
local function eye_of(ent)
    if ent == nil then
        return nil
    end
    if ent == local_player() then
        local x, y, z = try(client.eye_position)
        if finite(x) and finite(y) and finite(z) then
            return vector(x, y, z)
        end
    end
    local base = origin_of(ent)
    if base == nil then
        return nil
    end
    local offset = prop(ent, "m_vecViewOffset[2]")
    if not finite(offset) or offset <= 0 then
        offset = 64
    end
    return vector(base.x, base.y, base.z + offset)
end

local function weapon_of(ent)
    local weapon = ent ~= nil and try(entity.get_player_weapon, ent) or nil
    if finite(weapon) and weapon > 0 then
        return weapon
    end
    return nil
end

-- Mermi izi (client.trace_bullet): from_ent'in silahiyla from -> to. Hasar (yoksa nil). target
-- verilirse yol uzerinde baska bir oyuncuya carpan iz sayilmaz.
local trace_available = type(client.trace_bullet) == "function"
local function bullet_damage(from_ent, from, to, target)
    if not trace_available or from_ent == nil or from == nil or to == nil then
        return nil
    end
    local ok, hit, damage = pcall(client.trace_bullet, from_ent, from.x, from.y, from.z, to.x, to.y, to.z)
    if not ok or not finite(damage) then
        return nil
    end
    if target ~= nil and finite(hit) and hit > 0 and hit ~= target then
        return 0
    end
    return damage
end

-- Duz cizgi izi (client.trace_line): fraction (0-1), carpilan entity.
local function trace_line(skip, from, to)
    local ok, fraction, hit = pcall(client.trace_line, skip or -1, from.x, from.y, from.z, to.x, to.y, to.z)
    if ok and finite(fraction) then
        return fraction, hit
    end
    return nil
end

-------------------------------------------------------------------------------
-- GameSense menu referanslari
-------------------------------------------------------------------------------

local refs = {}
do
    -- Bulunamayan bir menu yolu script'i cokertmesin, sadece konsola yazilsin. Birden fazla yol verilirse
    -- sirayla denenir (GameSense surumune gore bazi ayarlar RAGE > Aimbot / Other'da).
    local function find(paths, quiet)
        for _, path in ipairs(paths) do
            local ok, a, b, c = pcall(ui.reference, path[1], path[2], path[3])
            if ok and a ~= nil then
                return a, b, c
            end
        end
        if not quiet then
            print(("[%s] menude bulunamadi: %s"):format(SCRIPT, table.concat(paths[1], " > ")))
        end
        return nil
    end

    refs.aa_enabled = find({ { "AA", "Anti-aimbot angles", "Enabled" } })
    refs.pitch, refs.pitch_value = find({ { "AA", "Anti-aimbot angles", "Pitch" } })
    refs.yaw_base = find({ { "AA", "Anti-aimbot angles", "Yaw base" } })
    refs.yaw, refs.yaw_offset = find({ { "AA", "Anti-aimbot angles", "Yaw" } })
    refs.yaw_jitter, refs.jitter_offset = find({ { "AA", "Anti-aimbot angles", "Yaw jitter" } })
    refs.body_yaw, refs.body_value = find({ { "AA", "Anti-aimbot angles", "Body yaw" } })
    refs.body_fs = find({ { "AA", "Anti-aimbot angles", "Freestanding body yaw" } })
    refs.edge_yaw = find({ { "AA", "Anti-aimbot angles", "Edge yaw" } }, true)
    refs.freestanding, refs.freestanding_key = find({ { "AA", "Anti-aimbot angles", "Freestanding" } })
    refs.slowwalk, refs.slowwalk_key = find({ { "AA", "Other", "Slow motion" } })
    refs.hideshots, refs.hideshots_key = find({ { "AA", "Other", "On shot anti-aim" } })
    refs.doubletap, refs.doubletap_key = find({ { "RAGE", "Aimbot", "Double tap" }, { "RAGE", "Other", "Double tap" } })
    refs.dt_fakelag = find({ { "RAGE", "Aimbot", "Double tap fake lag limit" }, { "RAGE", "Other", "Double tap fake lag limit" } }, true)
    refs.fakeduck = find({ { "RAGE", "Other", "Duck peek assist" } })
    refs.peek_assist, refs.peek_assist_key = find({ { "RAGE", "Other", "Quick peek assist" } })
    refs.prefer_safe = find({ { "RAGE", "Aimbot", "Prefer safe point" } })
    refs.force_safe = find({ { "RAGE", "Aimbot", "Force safe point" } }, true)
    refs.force_body = find({ { "RAGE", "Aimbot", "Force body aim" } }, true)
    refs.min_damage = find({ { "RAGE", "Aimbot", "Minimum damage" } })
    refs.md_override, refs.md_override_key, refs.md_override_value = find({ { "RAGE", "Aimbot", "Minimum damage override" } }, true)
    refs.weapon_type = find({ { "RAGE", "Weapon type", "Weapon type" } }, true)
    refs.maxshift = find({ { "MISC", "Settings", "sv_maxusrcmdprocessticks2" } }, true)
    refs.roll = find({ { "AA", "Anti-aimbot angles", "Roll" } }, true)
    refs.clantag_spammer = find({ { "MISC", "Miscellaneous", "Clan tag spammer" } }, true)
end

-- Hotkey referanslari: ui.get -> aktif mi, mod (0-3), tus. Ezerken { mode, key } verilir.
local HOTKEYS = {
    freestanding_key = true, slowwalk_key = true, hideshots_key = true, doubletap_key = true,
    fakeduck = true, peek_assist_key = true, force_safe = true, force_body = true, md_override_key = true,
}
local ALWAYS_ON = { mode = 0 }
-- Tus 0 = tus yok: "On hotkey" + tus yok asla aktif olmaz. Fake duck'i birakmanin tek yolu (GameSense'te
-- fake duck sadece hotkey'dir, kapatma kutusu yok).
local NEVER = { mode = 1, key = 0 }

local function same(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then
        return a == b
    end
    for k, v in pairs(a) do
        if not same(v, b[k]) then
            return false
        end
    end
    for k, v in pairs(b) do
        if a[k] == nil and v ~= nil then
            return false
        end
    end
    return true
end

-- get: ayarin su anki hali (hotkey'de aktif mi). GameSense'te ui.set gercek degeri degistirdigi icin
-- ezdigimiz deger de buradan okunur (Neverlose'daki "effective" ile ayni).
local function get(name)
    local ref = refs[name]
    if ref == nil then
        return false
    end
    if HOTKEYS[name] then
        local ok, active = pcall(ui.get, ref)
        return ok and active == true
    end
    local ok, value = pcall(ui.get, ref)
    if ok and value ~= nil then
        return value
    end
    return false
end

-- Ezme sistemi. overridden[anahtar] = { name, scope, original, last }. Anahtar ayar adi; silah grubuna
-- bagli rage ayarlarinda "ad@grup". original = senin degerin (kapatinca geri yazilir), last = bizim son
-- yazdigimiz. Ayar biz yazmadan degistiyse (sen, config yuklemesi, silah grubu degisimi) yeni deger senin
-- degerin sayilir. GameSense'in kabul etmedigi degerler bir kez yazilir, 5 sn sonra tekrar denenir.
local override, is_overridden, user_value, reset_overrides, forget_overrides
do
    local MODE_NAMES = { [0] = "Always on", "On hotkey", "Toggle", "Off hotkey" }
    -- Silah grubuna gore ayri tutulan rage ayarlari (GameSense "Weapon type").
    local RAGE_SCOPED = { min_damage = true, prefer_safe = true }
    local REJECT_RETRY = 5
    local overridden, rejected, reported = {}, {}, {}

    local function copy_value(v)
        if type(v) ~= "table" then
            return v
        end
        local out = {}
        for k, x in pairs(v) do
            out[k] = x
        end
        return out
    end

    -- Menudeki gercek deger. Hotkey'de { mode, key }.
    local function read_ref(name)
        local ref = refs[name]
        if ref == nil then
            return nil
        end
        if HOTKEYS[name] then
            local ok, _, mode, key = pcall(ui.get, ref)
            if not ok then
                return nil
            end
            return { mode = finite(mode) and mode or 1, key = finite(key) and key or 0 }
        end
        local ok, a, b, c, d = pcall(ui.get, ref)
        if not ok then
            return nil
        end
        if b ~= nil and type(a) ~= "table" then
            return { a, b, c, d }
        end
        return a
    end

    local function write_ref(name, value)
        local ref = refs[name]
        if HOTKEYS[name] then
            local mode = MODE_NAMES[value.mode] or "On hotkey"
            if value.key ~= nil then
                ui.set(ref, mode, value.key)
            else
                ui.set(ref, mode)
            end
            return
        end
        ui.set(ref, value)
    end

    -- Silah grubu seciciyi gecici olarak scope'a cevirip fn'i calistirir (o grubun ayarina yazmak icin),
    -- sonra geri alir. Angelwings'in yontemi: GameSense secici degisince o grubun degerlerini yukler.
    local function with_scope(scope, fn)
        if scope == nil or scope == "all" or refs.weapon_type == nil then
            return pcall(fn)
        end
        local ok_cur, current = pcall(ui.get, refs.weapon_type)
        if not ok_cur or current == scope then
            return pcall(fn)
        end
        if not pcall(ui.set, refs.weapon_type, scope) then
            return false
        end
        local ok, err = pcall(fn)
        pcall(ui.set, refs.weapon_type, current)
        return ok, err
    end

    local function release_key(key)
        local rec = overridden[key]
        if rec == nil then
            return
        end
        overridden[key] = nil
        with_scope(rec.scope, function()
            local current = read_ref(rec.name)
            -- Biz yazdiktan sonra degistiyse (sen degistirdin) dokunulmaz.
            if same(current, rec.last) and not same(current, rec.original) then
                write_ref(rec.name, rec.original)
            end
        end)
    end

    -- value nil ise o ayar senin kendi GameSense degerine birakilir. scope: silah grubu (RAGE_SCOPED
    -- ayarlarinda zorunlu; nil verilirse yazilmaz, birakilir).
    override = function(name, value, scope)
        if refs[name] == nil then
            return
        end
        if RAGE_SCOPED[name] then
            -- Baska bir gruba yazdigimiz deger varsa once o geri verilir (her zaman en fazla bir grup).
            for key, rec in pairs(overridden) do
                if rec.name == name and rec.scope ~= scope then
                    release_key(key)
                end
            end
            if scope == nil then
                return
            end
        end
        local key = RAGE_SCOPED[name] and (name .. "@" .. scope) or name
        if value == nil then
            release_key(key)
            return
        end
        local now = realtime()
        local reject_key = name .. "=" .. tostring(type(value) == "table" and (value.mode or "t") or value)
        local failed_at = rejected[reject_key]
        if failed_at ~= nil and now >= failed_at and now - failed_at < REJECT_RETRY then
            return
        end
        local current = read_ref(name)
        if current == nil then
            return
        end
        if HOTKEYS[name] and value.key == nil then
            value = { mode = value.mode, key = current.key }
        end
        local rec = overridden[key]
        if rec == nil then
            rec = { name = name, scope = scope, original = copy_value(current), last = copy_value(current) }
            overridden[key] = rec
        elseif not same(current, rec.last) then
            rec.original = copy_value(current)
        end
        if same(current, value) then
            rec.last = copy_value(current)
            rejected[reject_key] = nil
            return
        end
        local ok, err = pcall(write_ref, name, value)
        local after = read_ref(name)
        if not ok or not same(after, value) then
            rejected[reject_key] = now
            -- Onceki degerimiz takili kalmasin: ezmeyi birak, ayar senin degerine donsun.
            release_key(key)
            if not reported[reject_key] then
                reported[reject_key] = true
                print(("[%s] %s = %s ayarlanamadi: %s"):format(SCRIPT, name,
                    tostring(type(value) == "table" and (MODE_NAMES[value.mode] or "?") or value),
                    tostring(ok and "deger kabul edilmedi" or err)))
            end
            return
        end
        rejected[reject_key] = nil
        rec.last = copy_value(after)
    end

    is_overridden = function(name)
        for _, rec in pairs(overridden) do
            if rec.name == name then
                return true
            end
        end
        return false
    end

    -- Senin degerin (ezmeden onceki). Ezmiyorsak menudeki deger (hotkey'de { mode, key }).
    user_value = function(name)
        for _, rec in pairs(overridden) do
            if rec.name == name then
                return rec.original
            end
        end
        if HOTKEYS[name] then
            return read_ref(name)
        end
        return get(name)
    end

    reset_overrides = function()
        for key in pairs(overridden) do
            release_key(key)
        end
        overridden = {}
    end

    -- Config yuklendikten sonra: eski ezmeler unutulur (degerler artik config'in).
    forget_overrides = function()
        overridden = {}
    end
end

-- Exploit / fake duck durumlari (GameSense'te kutu + tus birlikte).
local function dt_on()
    return get("doubletap") == true and (refs.doubletap_key == nil or get("doubletap_key"))
end

local function hs_on()
    return get("hideshots") == true and (refs.hideshots_key == nil or get("hideshots_key"))
end

-- Fake duck: tus basili ve yerdesin. GameSense'in fake duck'i sadece yerde calisir; havada tus basili olsa
-- da DT / HS, air lag, defensive ve teleport kapatilmaz, inince fake duck her zamanki gibi (V1.0.14: logda
-- ziplayip havada fake duck'a basilinca DT kapaniyordu, "Air crouch | FD, DT yok").
-- Oluyken / oyuncu yokken tus durumu (V1.0.15: oldugunde etiket "DEF acik" gosteriyordu).
local function fd_on()
    if get("fakeduck") ~= true then
        return false
    end
    local lp = local_player()
    return not alive(lp) or on_ground(lp)
end

local function slowwalk_on()
    return get("slowwalk") == true and (refs.slowwalk_key == nil or get("slowwalk_key"))
end

-- Peek Assist tusu basili mi. AI peek yururken Peek Assist'in kutusunu kapatiriz (hareketi ezmesin);
-- tusun kendisi (basili / toggle) okunmaya devam eder, kutunun senin degeri ezmeden onceki degerdir.
local function peek_key_held()
    if refs.peek_assist_key == nil then
        return false
    end
    return user_value("peek_assist") == true and get("peek_assist_key")
end

-------------------------------------------------------------------------------
-- Oyuncu listesi (plist): dusman basina ayarlar
-------------------------------------------------------------------------------

-- Neverlose'da safe point / body aim tek ayardi; GameSense'in oyuncu listesinde dusman basina ezilir:
-- "Override safe point" (-, Off, On), "Override prefer body aim" (-, Off, On, Force), "Force body yaw"
-- + "Force body yaw value" (NYKLE Resolver 2.5). Senin kendi oyuncu ayarin hic dusurulmez; slot baska
-- bir oyuncuya gecince (ayni index) eski degerimiz yeni oyuncuya kalmaz.
local PL = { SAFE = "Override safe point", BODY = "Override prefer body aim", FORCE = "Force body yaw",
    VALUE = "Force body yaw value", CORRECTION = "Correction active", WHITELIST = "Add to whitelist" }

local player_id
local plist_get, plist_available, plist_override, plist_user, plist_reset, plist_release_missing
do
    local DEFAULT = { [PL.SAFE] = "-", [PL.BODY] = "-", [PL.FORCE] = false, [PL.VALUE] = 0, [PL.WHITELIST] = false }
    local recs, bad = {}, {}

    plist_get = function(ent, field)
        if type(plist) ~= "table" or bad[field] then
            return nil
        end
        local ok, value = pcall(plist.get, ent, field)
        if ok then
            return value
        end
        bad[field] = true
        print(("[%s] oyuncu listesinde bulunamadi: %s (bu ozellik kapali)"):format(SCRIPT, field))
        return nil
    end

    local function plist_set(ent, field, value)
        if type(plist) ~= "table" or bad[field] then
            return false
        end
        local ok = pcall(plist.set, ent, field, value)
        return ok and plist_get(ent, field) == value
    end

    plist_available = function(field)
        return type(plist) == "table" and not bad[field]
    end

    local function release(key)
        local rec = recs[key]
        if rec == nil then
            return
        end
        recs[key] = nil
        local current = plist_get(rec.ent, rec.field)
        if current ~= nil and current == rec.last and current ~= rec.original then
            -- Slot baska bir oyuncuya gectiyse onun ayari degil, varsayilan yazilir.
            local restore = rec.original
            if player_id(rec.ent) ~= rec.id then
                restore = DEFAULT[rec.field]
            end
            plist_set(rec.ent, rec.field, restore)
        end
    end

    -- value nil: senin oyuncu ayarina birak. Basarili ezmede true.
    plist_override = function(ent, field, value)
        local key = tostring(ent) .. ":" .. field
        local rec = recs[key]
        if rec ~= nil and rec.id ~= player_id(ent) then
            release(key)
            rec = nil
        end
        if value == nil then
            release(key)
            return false
        end
        local current = plist_get(ent, field)
        if current == nil then
            return false
        end
        if rec == nil then
            rec = { ent = ent, field = field, original = current, last = current, id = player_id(ent) }
            recs[key] = rec
        elseif current ~= rec.last then
            rec.original = current
        end
        if current ~= value then
            plist_set(ent, field, value)
            rec.last = plist_get(ent, field)
            return rec.last == value
        end
        rec.last = current
        return true
    end

    -- Ezmeden onceki (senin) oyuncu ayarin.
    plist_user = function(ent, field)
        local rec = recs[tostring(ent) .. ":" .. field]
        if rec ~= nil then
            return rec.original
        end
        return plist_get(ent, field)
    end

    -- forget: yazmadan unut (harita degisti, liste sifirlandi).
    plist_reset = function(forget)
        for key in pairs(recs) do
            if forget then
                recs[key] = nil
            else
                release(key)
            end
        end
    end

    -- Listeden cikan / olen / dormant dusmanlardaki ezmeleri birakir.
    plist_release_missing = function(present)
        for key, rec in pairs(recs) do
            if not present[rec.ent] then
                release(key)
            end
        end
    end
end


-- Hangi durumda vuruldugunu gormek icin istatistikler. Menudeki sifirlama dugmesi de kullandigi icin
-- menuden once tanimli.
local stats, pending_misses = {}, {}

-- Ogrenilen dusman bellegini siler; bellek menuden sonra tanimlandigi icin sonradan atanir.
local forget_enemies

-- Senin aimbot atislarinin sonuclari (GameSense aim_hit / aim_miss nedenleri).
local function new_aim_stats()
    return { shots = 0, hits = 0, correction = 0, spread = 0, other = 0,
        ai_peeks = 0, ai_shots = 0, ai_hits = 0, ai_empty = 0, ai_hurt = 0,
        lag_shots = 0, lag_hits = 0, clean_shots = 0, clean_hits = 0,
        rated = 0, rated_spread = 0, rated_other = 0,
        kd = {} }
end
local aim_stats = new_aim_stats()

-------------------------------------------------------------------------------
-- Menu (AA sekmesi > Anti-aimbot angles, NYKLE Yaw gibi)
-------------------------------------------------------------------------------

-- Menu ogeleri ve gorunurluk (LuaJIT'in 200 yerel degisken siniri icin menu kurulumu tek blokta).
local menu, builder = {}, {}
local STATES
local on, update_visibility, apply_recommended, recommended_state, set_native_visible
do
-- NYKLE Yaw, luasense ve angelwings gibi menu AA sekmesinde, GameSense'in AA ayarlarinin yerinde
-- (lua acikken GameSense'in kendi AA ayarlari gizlenir; lua bunlari zaten kendisi yaziyor).
local MENU_TAB, MENU_CONTAINER = "AA", "Anti-aimbot angles"

local function default_first(items, first)
    local list = { first }
    for _, item in ipairs(items) do
        if item ~= first then
            list[#list + 1] = item
        end
    end
    return list
end
local ACCENT_HEX = "\a96BEFFFF"
local DIM_HEX = "\aB4B4B4FF"

local style = {}
style.title = function(text)
    return ACCENT_HEX .. text
end
-- Loglar ve onerilen ayar raporlari icin bicimsiz ad.
style.plain = function(text)
    local out = tostring(text):gsub("\a%x%x%x%x%x%x%x%x", ""):gsub("\n.*$", "")
    out = out:gsub("^[%s»]+", ""):gsub("%s+$", "")
    return out
end

-- Element: GameSense referansinin uzerine kucuk bir sarmalayici (Neverlose'daki :get / :set / :visibility).
local Element = {}
Element.__index = Element

function Element:get()
    local ok, a, b, c, d = pcall(ui.get, self.ref)
    if not ok then
        return nil
    end
    if self.kind == "color" then
        return { r = a or 255, g = b or 255, b = c or 255, a = d or 255 }
    end
    return a
end

function Element:set(value)
    if self.kind == "color" then
        return pcall(ui.set, self.ref, value.r, value.g, value.b, value.a)
    end
    return pcall(ui.set, self.ref, value)
end

function Element:visibility(visible)
    if self.shown ~= visible then
        self.shown = visible
        pcall(ui.set_visible, self.ref, visible)
    end
end

function Element:set_callback(fn)
    pcall(ui.set_callback, self.ref, fn)
end

-- GameSense ayni kutuda ayni adi iki kez kabul etmez (config anahtari) ve AA kutusu GameSense'in kendi
-- ayarlari ve baska lua'larla paylasilir: her ada gorunmeyen bir ek ("\n" sonrasi gorunmez) eklenir ki
-- GameSense'in "Pitch"i ya da baska bir lua'nin ayari ile carpismasin; ayni ad tekrar gelirse sayi eklenir.
local used_names = {}
local function unique(name)
    local base = name:find("\n", 1, true) and (name .. "_nw") or (name .. "\nnw")
    local out, n = base, 1
    while used_names[out] do
        n = n + 1
        out = base .. n
    end
    used_names[out] = true
    return out
end

local all_elements = {}
local menu_failures = 0

-- column ("A" / "B") Neverlose'daki iki sutunun izi: GameSense'te hepsi tek kutuda, olusturulma sirasiyla
-- alt alta.
local function create(column, kind, name, ...)
    local label = unique(name)
    local tab, box = MENU_TAB, MENU_CONTAINER
    local ok, ref
    if kind == "checkbox" then
        ok, ref = pcall(ui.new_checkbox, tab, box, label)
    elseif kind == "slider" then
        local low, high, def, unit, tooltips, scale = ...
        ok, ref = pcall(ui.new_slider, tab, box, label, low, high, def, true, unit, scale or 1, tooltips)
    elseif kind == "combo" then
        local items = ...
        ok, ref = pcall(ui.new_combobox, tab, box, label, items)
    elseif kind == "hotkey" then
        ok, ref = pcall(ui.new_hotkey, tab, box, label, false)
    elseif kind == "button" then
        local fn = ...
        ok, ref = pcall(ui.new_button, tab, box, label, fn)
    elseif kind == "color" then
        local c = ...
        ok, ref = pcall(ui.new_color_picker, tab, box, label, c.r, c.g, c.b, c.a)
    else
        ok, ref = pcall(ui.new_label, tab, box, label)
    end
    if not ok or ref == nil then
        -- Konsol dolmasin: ilk uc hata nedeniyle yazilir, toplam menu kurulunca.
        menu_failures = menu_failures + 1
        if menu_failures <= 3 then
            print(("[%s] menu ogesi olusturulamadi: %s (%s)"):format(SCRIPT, style.plain(name), tostring(ref)))
        end
        return nil
    end
    local element = setmetatable({ ref = ref, kind = kind, name = style.plain(name), shown = true }, Element)
    all_elements[#all_elements + 1] = element
    return element
end

-- "Always use recommended settings": GameSense lua ayarlarini config'e kaydeder; eski bir config eski
-- degerleri geri getirir. AA, exploit, builder ve resolver ayarlarinin varsayilanlari kaydedilir ve acik
-- oldugu surece bu degerlerde tutulur. Bind'ler (manual, freestanding, inverter), builder'daki durum
-- secici, loglar ve gorsel tercihler bu listeye girmez.
local recommended = {}
local label_prefix = ""

local function remember(element, value)
    if element ~= nil then
        recommended[#recommended + 1] = { element = element, value = value, label = label_prefix .. element.name }
    end
    return element
end

-- Grup: bir sekmenin bir sutunu. vis: elemanin ek gorunurluk kosulu (fonksiyon). tracked gruplarda
-- varsayilanlar onerilen ayar listesine girer. Olusturulan her elemana varsayilan degeri hemen yazilir
-- (GameSense'te checkbox'in varsayilan parametresi yok).
local TAB_NAMES = { "Home", "Anti-Aim", "Exploits", "Builder", "Ragebot", "Visuals", "Misc" }

local function group(tab, column, title, is_tracked)
    local g = { tab = tab, column = column }
    local function register(element, vis)
        if element ~= nil then
            element.tab, element.vis = tab, vis
        end
        return element
    end
    -- Baslik ilk eleman eklenirken olusturulur: GameSense ogeleri olusturulma sirasiyla gosterir.
    local raw_create = create
    local function create(col, kind, name, ...)
        if title ~= nil and g.header == nil then
            g.header = register(raw_create(col, "label", style.title(title)))
        end
        return raw_create(col, kind, name, ...)
    end
    function g:switch(name, def, vis)
        local e = register(create(column, "checkbox", name), vis)
        if e ~= nil then
            e:set(def == true)
            if is_tracked then
                remember(e, def == true)
            end
        end
        return e
    end
    function g:combo(name, items, vis)
        local e = register(create(column, "combo", name, items), vis)
        if e ~= nil then
            e:set(items[1])
            if is_tracked then
                remember(e, items[1])
            end
        end
        return e
    end
    function g:slider(name, low, high, def, unit, vis, tooltips, scale)
        local e = register(create(column, "slider", name, low, high, def, unit, tooltips, scale), vis)
        if e ~= nil then
            e:set(def)
            if is_tracked then
                remember(e, def)
            end
        end
        return e
    end
    function g:hotkey(name, vis)
        return register(create(column, "hotkey", name), vis)
    end
    function g:label(text, vis)
        return register(create(column, "label", text), vis)
    end
    function g:button(name, fn, vis)
        return register(create(column, "button", name, fn), vis)
    end
    function g:color(name, c, vis)
        return register(create(column, "color", name, c), vis)
    end
    return g
end

-- Ust kisim (Enable kapaliyken de gorunur).
menu.header  = create("A", "label", style.title(("%s  V%s  " .. DIM_HEX .. "| %s edition"):format(SCRIPT, VERSION, EDITION)))
menu.enabled = create("A", "checkbox", "Enable Nykle.win")
if menu.enabled ~= nil then
    menu.enabled:set(true)
end
menu.tab     = create("A", "combo", "Nykle.win tab", TAB_NAMES)

local grp = {}
grp.info      = group("Home", "A", nil, true)
grp.data      = group("Home", "B", "Memory", false)
grp.console   = group("Home", "B", "Console", false)
grp.aa        = group("Anti-Aim", "A", "Main", true)
grp.aa_raw    = group("Anti-Aim", "A", nil, false)
-- Baslik tek kutuda Freestanding tusunun ustunde kalsin diye protect_raw'da (ilk o olusturuluyor).
grp.protect_raw = group("Anti-Aim", "B", "Protection", false)
grp.protect   = group("Anti-Aim", "B", nil, true)
grp.exploits  = group("Exploits", "A", "Exploits", true)
grp.peek      = group("Exploits", "A", "Peek", true)
grp.defensive = group("Exploits", "B", "Defensive", true)
grp.angles_raw = group("Builder", "A", "Angles", false)
grp.angles    = group("Builder", "A", nil, true)
-- Exploit basligi durum basina (asagida "<durum> exploit"): tek kutuda ortak baslik yanlis yerde kalirdi.
grp.bexploit_raw = group("Builder", "B", nil, false)
grp.bexploit  = group("Builder", "B", nil, true)
grp.resolver  = group("Ragebot", "A", "Resolver", true)
grp.indicators = group("Visuals", "A", "Indicators", false)
grp.panel     = group("Visuals", "B", "Resolver panel", false)
grp.clantag   = group("Misc", "A", "Clan tag", false)
grp.trash     = group("Misc", "A", "Trash talk", false)

STATES = {
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

-- AA varsayilanlari: { yaw sol, yaw sag, jitter gecikmesi, sol limit, sag limit } (Neverlose V1.0 ile ayni;
-- topluluk jitter preset'lerinden, loglarla dogrulanmis).
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
    ["Fake duck"]    = { 0, 0, 1, 58, 58 },
    ["Manual"]       = { 0, 0, 1, 60, 60 },
    ["Freestanding"] = { 0, 0, 1, 60, 60 },
    ["Safe head"]    = { 0, 0, 1, 30, 30 },
}

-- Exploit varsayilanlari: { exploit, defensive, hidden pitch, hidden yaw } (Neverlose V1.0 ile ayni).
-- Dururken / egilip dururken ve Peek'te hidden aci yok (V1.0): kafayi siperin / freestanding'in
-- arkasindan cikariyordu. Yururken ve havada kalir (havada spin).
local EXPLOIT_DEFAULTS = {
    ["Standing"]     = { "Double tap", "On peek",   "Off",    "Off" },
    ["Moving"]       = { "Double tap", "Smart",     "Up",     "Random" },
    ["Slow walk"]    = { "Double tap", "Smart",     "Up",     "Random" },
    ["Crouching"]    = { "Double tap", "On peek",   "Off",    "Off" },
    ["Crouch move"]  = { "Double tap", "Smart",     "Up",     "Random" },
    ["Peek"]         = { "Double tap", "Smart",     "Off",    "Off" },
    ["Air"]          = { "Double tap", "Smart",     "Up",     "Spin" },
    ["Air crouch"]   = { "Double tap", "Smart",     "Up",     "Random" },
    ["Manual"]       = { "Double tap", "On peek",   "Off",    "Off" },
    ["Freestanding"] = { "Double tap", "On peek",   "Off",    "Off" },
    ["Safe head"]    = { "Double tap", "On peek",   "Off",    "Off" },
}

local WAY_DEFAULTS = { -30, 0, 30, -15, 15 }

-- Yaw modifier: Off / Center / Offset / Random / Skitter GameSense'in kendi "Yaw jitter"i; Spin, 3-Way,
-- 5-Way GameSense'te yok, lua her gonderilen pakette yaw'a ekler (Neverlose'daki modifier'larin aynisi).
local MODIFIERS = { "Off", "Center", "Offset", "Random", "Skitter", "Spin", "3-Way", "5-Way" }
local EXPLOITS = { "Double tap", "Hide shots", "Binds" }
local DEF_MODES = { "Off", "On peek", "Smart", "Always on", "Tick based" }
local HIDDEN_PITCHES = { "Off", "Down", "Up", "Zero", "Switch", "Random", "Custom" }
local HIDDEN_YAWS = { "Off", "Sideways", "Spin", "Random", "Forward", "Custom" }

on = function(element)
    return element ~= nil and element:get() == true
end

-- Home
menu.recommended = grp.info:switch("Always use recommended settings", true)
menu.home_info   = grp.info:label(DIM_HEX .. "Ayarlara dokunmana gerek yok. Bind'ler: Anti-Aim sekmesi")
menu.home_info2  = grp.info:label(DIM_HEX .. "(manual yaw, freestanding, static inverter).")
menu.forget      = grp.data:button("Forget learned enemies", function()
    if forget_enemies ~= nil then
        forget_enemies()
        print(("[%s] ogrenilen dusmanlar silindi (hafiza dahil)"):format(SCRIPT))
    end
end)
menu.stats_reset = grp.data:button("Reset stats", function()
    stats, pending_misses, aim_stats = {}, {}, new_aim_stats()
end)
menu.resolver_log = grp.console:switch("Resolver log", true)
menu.shot_log     = grp.console:switch("Shot log", true)
menu.hit_log      = grp.console:switch("Hit log", true)
menu.brute_log    = grp.console:switch("Anti-brute log", false)
-- V1.0.10: oyun loglarindan gelistirmek icin detayli log (konum, mesafe, hiz, defensive, duello ozeti,
-- "gordu ama sikmadi" sebebi). Varsayilan acik; satirlar "dbg" ile baslar.
menu.debug_log    = grp.console:switch("Detailed log (for analysis)", true)
menu.log_copy     = grp.console:button("Copy all logs", function()
    local text = nlog.text(true)
    local count = select(2, text:gsub("\n", "\n")) + (text ~= "" and 1 or 0)
    local file = nlog.save() and ("; dosya: %s (CS:GO klasoru)"):format(nlog.file) or ""
    if nlog.clipboard(text) then
        print(("[%s] %d satir log panoya kopyalandi (Ctrl+V ile yapistir)%s"):format(SCRIPT, count, file))
    else
        print(("[%s] panoya kopyalanamadi (GameSense'te Allow unsafe scripts kapali olabilir): loglar asagida konsolda%s"):format(
            SCRIPT, file))
        nlog.dump()
    end
end)
menu.log_print    = grp.console:button("Print all logs to console", function()
    nlog.dump()
end)
menu.log_clear    = grp.console:button("Clear saved logs", function()
    nlog.lines, nlog.old = {}, ""
    nlog.save()
    print(("[%s] kayitli loglar silindi (%s)"):format(SCRIPT, nlog.file))
end)

-- Anti-Aim
menu.pitch          = grp.aa:combo("Pitch", { "Down", "Minimal", "Off" })
menu.yaw_base       = grp.aa:combo("Yaw base", { "At Target", "Local View" })
menu.manual_left    = grp.aa_raw:hotkey("Manual left")
menu.manual_right   = grp.aa_raw:hotkey("Manual right")
menu.manual_forward = grp.aa_raw:hotkey("Manual forward")
menu.inverter       = grp.aa_raw:hotkey("Static inverter")
menu.avoid_backstab = grp.aa:switch("Avoid backstab", true)
menu.legit_use      = grp.aa:switch("Legit AA on use", true)
menu.spin           = grp.aa:switch("Spin when idle", true)
-- HvH sunucularinda warmup'ta da savasiliyor, o yuzden varsayilan kapali.
menu.spin_warmup    = grp.aa:switch("  » Spin in warmup", false, function() return on(menu.spin) end)
menu.spin_enemies   = grp.aa:switch("  » Spin: no enemies alive", true, function() return on(menu.spin) end)
menu.spin_pitch     = grp.aa:combo("  » Spin pitch", { "Off", "Down" }, function() return on(menu.spin) end)
menu.spin_speed     = grp.aa:slider("  » Spin speed", 1, 20, 6, nil, function() return on(menu.spin) end)

menu.freestanding   = grp.protect_raw:hotkey("Freestanding")
menu.fs_air         = grp.protect:switch("  » FS: disable in air", true)
menu.fs_crouch      = grp.protect:switch("  » FS: disable while crouching", false)
menu.fs_slow        = grp.protect:switch("  » FS: disable while slow walking", false)
menu.fs_moving      = grp.protect:switch("  » FS: disable while moving", false)
-- Freestanding tusun kapaliyken de ayakta / egilip dururken (aci tutarken) acilir.
menu.fs_auto        = grp.protect:switch("  » FS: auto when standing still", true)
menu.safe_head      = grp.protect:switch("Safe head", true)
menu.safe_knife     = grp.protect:switch("  » Safe head: knife/zeus in air crouch", true, function() return on(menu.safe_head) end)
menu.safe_air       = grp.protect:switch("  » Safe head: any air crouch", false, function() return on(menu.safe_head) end)
-- Yuksekte sabit kafa varsayilan kapali (v4.8 loglari: alttaki dusman kafani gorurken 5 kafa mermisinin 4'u).
menu.safe_high      = grp.protect:switch("  » Safe head: high ground", false, function() return on(menu.safe_head) end)
menu.anti_brute     = grp.protect:switch("Anti-bruteforce", true)
menu.brute_reset    = grp.protect:slider("  » Anti-brute reset after", 1, 15, 6, "s", function() return on(menu.anti_brute) end)
menu.fd_guard       = grp.protect:switch("Release fake duck near knife", true)
-- V1.0.10 oyun logu: 22 olumun 10'u fake duck'ta; 3'unde ilk sniper mermisinden sonra fake duck'ta kalinip
-- ikinci mermiyle olundu. Sniper (scout / AWP) ile vurulunca o seni gordukce (en az 1.25, en fazla 3 sn)
-- fake duck birakilir: hiz, DT ve defensive geri gelir; sniper'in ikinci mermisi en erken 1.25 sn sonra.
menu.fd_hit         = grp.protect:switch("Release fake duck when hit by sniper", true)
-- V1.0.14 oyun logu: zipla-bicakla gelen dusman 37-78 birimdeyken 1 sn vurulabilir goruldu ama ates yok
-- ("hasar 87 < MD 100"), uc bicakla olum. Bicak / zeus tutan dusman yakinken Min. damage gecici dusurulur.
menu.knife_md       = grp.protect:switch("Lower Min. damage vs close knife/zeus", true)
-- V1.0'da varsayilan kapali: fake duck'i bilerek bunny hop + ani peek icin kullaniyorsun.
menu.fd_still       = grp.protect:switch("Fake duck only when standing still", false)

-- Exploits
menu.auto_exploit   = grp.exploits:switch("Auto exploit", true)
menu.sniper_exploit = grp.exploits:combo("Snipers (SSG08/AWP/R8)", { "Auto (learn)", "Hide shots", "Same as state" },
    function() return on(menu.auto_exploit) end)
menu.safe_recharge  = grp.exploits:switch("Safe recharge", true)
menu.hidden_spin    = grp.exploits:slider("Hidden spin speed", 1, 30, 10)
menu.exploit_info   = grp.exploits:label(DIM_HEX .. "Per-state exploit settings are in the Builder.")
menu.auto_peek      = grp.peek:switch("Auto peek", true)
menu.ai_peek        = grp.peek:switch("AI peek (hold Quick peek assist)", true)
menu.peek_defensive = grp.peek:switch("  » Defensive during AI peek", true, function() return on(menu.ai_peek) end)
menu.anti_peek      = grp.defensive:switch("Defensive vs enemy peeks", true)
menu.air_teleport   = grp.defensive:switch("Teleport in air when seen", true)
menu.air_lag        = grp.defensive:switch("Air lag (defensive every tick)", true)
menu.clean_shot     = grp.defensive:switch("Clean shot (no lag while shooting)", true)
menu.sniper_air_dt  = grp.defensive:switch("Snipers use DT in the air", false)

-- Ragebot. GameSense'in kendi resolver'i acilari cozmeye devam eder; bu katman bir dusmana resolver
-- yuzunden ("?" iskasi) iska gectikce sadece o dusmana karsi safe point'i yukseltir.
menu.resolver       = grp.resolver:switch("Adaptive resolver", true)
-- GameSense'e ozel (NYKLE Resolver 2.5): Force safe point'in de cozemedigi dusmanda Force body yaw ile
-- aci hipotezleri denenir.
menu.hypotheses     = grp.resolver:switch("  » Body yaw hypotheses (Force body yaw)", true, function() return on(menu.resolver) end)
menu.hyp_angle      = grp.resolver:slider("  » Hypothesis yaw limit", 10, 60, 58, DEG,
    function() return on(menu.resolver) and on(menu.hypotheses) end)
menu.hyp_chance     = grp.resolver:slider("  » Hypothesis min hit chance", 50, 100, 70, "%",
    function() return on(menu.resolver) and on(menu.hypotheses) end)
menu.smart_baim     = grp.resolver:switch("Smart body aim", true)
menu.head_only      = grp.resolver:switch("Head unless body kills (snipers)", true)
menu.fake_body      = grp.resolver:switch("Snipers: lethal body on fake records", true)
-- Dusman defensive'deyken (sahte kayit) aimbot gercek kayit gelene kadar (en fazla 14 tick) o dusmana ates
-- etmez. V1.0.8'den beri varsayilan KAPALI: oyun loglarinda surekli defensive acan dusmanlara karsi
-- "sikamiyor" sikayeti; faydasi oyunda kanitlanmadi. Acarsan duelloda / peek'te yine beklemez.
menu.wait_real      = grp.resolver:switch("Wait for real record (enemy defensive)", false)
menu.resolver_info  = grp.resolver:label(DIM_HEX .. "Per-enemy safe point / body aim from the player list.")

-- Builder
menu.state = grp.angles_raw:combo("State", STATES)

local AA_KEYS = {
    yaw_mode = true, yaw_left = true, yaw_right = true, ways = true,
    way1 = true, way2 = true, way3 = true, way4 = true, way5 = true,
    yaw_random = true, modifier = true, mod_random = true, mod_offset = true,
    body_yaw = true, body_fs = true, delay_random = true, limit_random = true,
    delay = true, left_limit = true, right_limit = true,
}

-- Builder ogeleri gorunurlugu kendisi yonetir (bkz. update_visibility); vis = false.
local function hidden_vis() return false end

for i, state in ipairs(STATES) do
    label_prefix = state .. " "
    local d = DEFAULTS[state]
    local special = i > MOVEMENT_STATES
    local id = "\n" .. state
    local s = {}
    if SPECIAL_INFO[state] ~= nil then
        s.info = grp.angles_raw:label(DIM_HEX .. SPECIAL_INFO[state] .. id, hidden_vis)
    end
    if i > 1 and not special then
        s.override = grp.angles:switch("Override" .. id, true, hidden_vis)
    end
    s.yaw_mode      = grp.angles:combo("Yaw mode" .. id, { "L&R", "X-Way" }, hidden_vis)
    s.yaw_left      = grp.angles:slider("Yaw left" .. id, -180, 180, d[1], DEG, hidden_vis)
    s.yaw_right     = grp.angles:slider("Yaw right" .. id, -180, 180, d[2], DEG, hidden_vis)
    s.ways          = grp.angles:slider("Ways" .. id, 3, 5, 3, nil, hidden_vis)
    for n = 1, 5 do
        s["way" .. n] = grp.angles:slider("Way " .. n .. id, -180, 180, WAY_DEFAULTS[n], DEG, hidden_vis)
    end
    -- Fake duck: paket ~14 tick bogulu, her pakette rastgele yaw (20) ve desync miktari (10) + rastgele taraf.
    local fd_state = state == "Fake duck"
    s.yaw_random    = grp.angles:slider("Yaw randomize" .. id, 0, 30, fd_state and 20 or 0, DEG, hidden_vis)
    s.modifier      = grp.angles:combo("Yaw modifier" .. id, MODIFIERS, hidden_vis)
    s.mod_random    = grp.angles:slider("Modifier randomize" .. id, 0, 60, 0, DEG, hidden_vis)
    s.mod_offset    = grp.angles:slider("Modifier offset" .. id, -180, 180, 0, DEG, hidden_vis)
    local static_default = special or fd_state
    local body_items
    if fd_state or state == "Safe head" then
        body_items = { "Random", "Static", "Jitter", "Off" }
    elseif static_default then
        body_items = { "Static", "Jitter", "Random", "Off" }
    else
        body_items = { "Jitter", "Static", "Random", "Off" }
    end
    s.body_yaw      = grp.angles:combo("Body yaw" .. id, body_items, hidden_vis)
    -- GameSense'in tek body freestanding modu var ("Freestanding body yaw"); sadece Static'te.
    s.body_fs       = grp.angles:combo("Body freestanding" .. id, fd_state and { "On", "Off" } or { "Off", "On" }, hidden_vis)
    -- Tam sirayla donen jitter'i resolver'lar yakalar; her donuste 0-1 paket rastgele bekleme bozar.
    s.delay_random  = grp.angles:slider("Delay randomize" .. id, 0, 5, static_default and 0 or 1, "t", hidden_vis)
    s.limit_random  = grp.angles:slider("Limit randomize" .. id, 0, 30, fd_state and 10 or 0, DEG, hidden_vis)
    s.delay         = grp.angles:slider("Jitter delay" .. id, 1, 10, d[3], "t", hidden_vis)
    s.left_limit    = grp.angles:slider("Left limit" .. id, 0, 60, d[4], DEG, hidden_vis)
    s.right_limit   = grp.angles:slider("Right limit" .. id, 0, 60, d[5], DEG, hidden_vis)

    local e = EXPLOIT_DEFAULTS[state]
    if e ~= nil then
        s.exploit_label      = grp.bexploit_raw:label(style.title(state .. " exploit") .. id, hidden_vis)
        s.exploit            = grp.bexploit:combo("Exploit" .. id, default_first(EXPLOITS, e[1]), hidden_vis)
        s.def_mode           = grp.bexploit:combo("Defensive" .. id, default_first(DEF_MODES, e[2]), hidden_vis)
        s.def_ticks          = grp.bexploit:slider("Defensive every" .. id, 2, 22, 14, "t", hidden_vis)
        s.hidden_pitch       = grp.bexploit:combo("Hidden pitch" .. id, default_first(HIDDEN_PITCHES, e[3]), hidden_vis)
        s.hidden_pitch_value = grp.bexploit:slider("Pitch value" .. id, -89, 89, 0, DEG, hidden_vis)
        s.hidden_yaw         = grp.bexploit:combo("Hidden yaw" .. id, default_first(HIDDEN_YAWS, e[4]), hidden_vis)
        s.hidden_yaw_value   = grp.bexploit:slider("Yaw value" .. id, -180, 180, 90, DEG, hidden_vis)
    end
    builder[state] = s
end
label_prefix = ""
-- Global ve Fake duck'in exploit ayari yok (Global AA'yi paylasir, fake duck'ta DT/HS calismaz).
menu.no_exploit  = grp.bexploit_raw:label(DIM_HEX .. "This state has no exploit settings.", hidden_vis)
menu.no_exploit2 = grp.bexploit_raw:label(DIM_HEX .. "(Global shares AA only, fake duck turns DT/HS off.)", hidden_vis)

-- Visuals (tercih; onerilen ayarlara girmez).
menu.indicators  = grp.indicators:switch("Crosshair indicators", true)
menu.accent      = grp.indicators:color("Indicator color", { r = 150, g = 190, b = 255, a = 255 })
menu.arrows      = grp.indicators:switch("Manual arrows", true)
menu.arrow_color = grp.indicators:color("Arrow color", { r = 150, g = 190, b = 255, a = 255 })
menu.stats_panel = grp.indicators:switch("Stats panel", false)
menu.res_panel   = grp.panel:switch("Resolver panel", true)
menu.panel_size  = grp.panel:slider("  » Panel size", 70, 200, 100, "%", function() return on(menu.res_panel) end)
menu.panel_x     = grp.panel:slider("  » Panel position X", 0, 1000, 12, nil, function() return on(menu.res_panel) end)
menu.panel_y     = grp.panel:slider("  » Panel position Y", 0, 1000, 330, nil, function() return on(menu.res_panel) end)

-- Misc: clan tag (NYKLE Yaw'daki animasyonlu "Nykle.win") ve trash talk (NYKLE Yaw'daki cumlelerin
-- Ingilizcesi). Tercih: onerilen ayarlara girmez (kapatirsan kapali kalir); ikisi de varsayilan acik.
menu.clantag     = grp.clantag:switch("Clan tag: Nykle.win (animated)", true)
local function tt_on() return on(menu.trash_talk) end
menu.trash_talk  = grp.trash:switch("Trash talk", true)
menu.tt_kill     = grp.trash:switch("  » On kill", true, tt_on)
menu.tt_headshot = grp.trash:switch("  » Kills: headshots only", false, function() return tt_on() and on(menu.tt_kill) end)
menu.tt_death    = grp.trash:switch("  » On death", true, tt_on)
menu.tt_chance   = grp.trash:slider("  » Chance", 1, 100, 100, "%", tt_on)
menu.tt_chat     = grp.trash:combo("  » Chat", { "All chat", "Team chat" }, tt_on)
-- Satirlar arasi bekleme: cumle uzunluguna gore (NYKLE Yaw: 2.3 sn, uzunluk / 24 (kill), / 20 (olum)).
menu.tt_delay    = grp.trash:slider("  » Message delay", 5, 50, 23, "s", tt_on, nil, 0.1)
menu.tt_info     = grp.trash:label(DIM_HEX .. "English lines; one message set at a time.", tt_on)

-- GameSense'in kendi AA ayarlari: lua acikken gizli (lua bunlari kendisi yaziyor, menusu de ayni kutuda),
-- kapaliyken ve unload'da geri gorunur (angelwings'in yontemi).
local NATIVE_AA = {
    "aa_enabled", "pitch", "pitch_value", "yaw_base", "yaw", "yaw_offset", "yaw_jitter", "jitter_offset",
    "body_yaw", "body_value", "body_fs", "edge_yaw", "freestanding", "freestanding_key", "roll",
}
local native_shown = nil
set_native_visible = function(visible)
    if native_shown == visible then
        return
    end
    native_shown = visible
    for _, name in ipairs(NATIVE_AA) do
        if refs[name] ~= nil then
            pcall(ui.set_visible, refs[name], visible)
        end
    end
end

update_visibility = function()
    local enabled = on(menu.enabled)
    set_native_visible(not enabled)
    local tab = menu.tab ~= nil and menu.tab:get() or "Home"
    if menu.tab ~= nil then
        menu.tab:visibility(enabled)
    end
    for _, element in ipairs(all_elements) do
        if element.tab ~= nil and element.vis ~= hidden_vis then
            local shown = enabled and element.tab == tab and (element.vis == nil or element.vis())
            element:visibility(shown)
        end
    end
    if menu.accent ~= nil then
        menu.accent:visibility(enabled and tab == "Visuals" and on(menu.indicators))
    end
    if menu.arrow_color ~= nil then
        menu.arrow_color:visibility(enabled and tab == "Visuals" and on(menu.arrows))
    end

    local in_builder = enabled and tab == "Builder"
    local selected = menu.state ~= nil and menu.state:get() or "Global"
    local no_exploit = in_builder and builder[selected] ~= nil and builder[selected].def_mode == nil
    if menu.no_exploit ~= nil then
        menu.no_exploit:visibility(no_exploit)
        menu.no_exploit2:visibility(no_exploit)
    end
    for _, state in ipairs(STATES) do
        local s = builder[state]
        local shown = in_builder and state == selected
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
                s["way" .. n]:visibility(xway and n <= (s.ways:get() or 3))
            end
            local body = s.body_yaw:get()
            local modded = s.modifier:get() ~= "Off"
            local desync = body ~= "Off"
            s.mod_offset:visibility(modded)
            s.mod_random:visibility(modded)
            s.delay:visibility(body == "Jitter" or body == "Random")
            s.delay_random:visibility(body == "Jitter" or body == "Random")
            s.left_limit:visibility(desync)
            s.right_limit:visibility(desync)
            s.limit_random:visibility(desync)
            s.body_fs:visibility(body == "Static")
        end
        if shown and s.def_mode ~= nil then
            local mode = s.def_mode:get()
            local hidden = mode ~= "Off"
            s.exploit:visibility(on(menu.auto_exploit))
            s.def_ticks:visibility(mode == "Tick based")
            s.hidden_pitch:visibility(hidden)
            s.hidden_pitch_value:visibility(hidden and s.hidden_pitch:get() == "Custom")
            s.hidden_yaw:visibility(hidden)
            s.hidden_yaw_value:visibility(hidden and s.hidden_yaw:get() == "Custom")
        end
    end
end

for _, element in ipairs({ menu.enabled, menu.tab, menu.auto_exploit, menu.ai_peek, menu.indicators, menu.arrows,
    menu.state, menu.spin, menu.safe_head, menu.anti_brute, menu.resolver, menu.hypotheses, menu.res_panel,
    menu.trash_talk, menu.tt_kill }) do
    if element ~= nil then
        element:set_callback(function() pcall(update_visibility) end)
    end
end
for _, s in pairs(builder) do
    for _, key in ipairs({ "override", "yaw_mode", "ways", "modifier", "body_yaw", "def_mode", "hidden_pitch", "hidden_yaw" }) do
        if s[key] ~= nil then
            s[key]:set_callback(function() pcall(update_visibility) end)
        end
    end
end
update_visibility()

-- Kaydedilmis varsayilanlara don. Script yuklenince, her config yuklemesinden sonra ve acik oldugu surece
-- 64 tick'te bir: onerilen degerden farkli olan ayar geri alinir. Kapaliyken hicbir sey degistirilmez;
-- yuklemede kac ayarin farkli oldugu yazilir.
recommended_state = { every = 64, report = 30, pending = true, tick = -1000, reported = -huge, report_off = false }

apply_recommended = function()
    local rec = recommended_state
    rec.pending, rec.tick = false, tickcount()
    local enabled = on(menu.recommended)
    if not enabled and not rec.report_off then
        return
    end
    rec.report_off = false
    local count, example = 0, nil
    for _, item in ipairs(recommended) do
        local value = item.element:get()
        if value ~= nil and not same(value, item.value) then
            count = count + 1
            example = example or ("%s %s, onerilen %s"):format(item.label, tostring(value), tostring(item.value))
            if enabled then
                item.element:set(item.value)
            end
        end
    end
    if count == 0 then
        return
    end
    if not enabled then
        print(("[%s] Always use recommended settings kapali: %d ayar onerilenden farkli (orn. %s)"):format(
            SCRIPT, count, example))
        return
    end
    pcall(update_visibility)
    local now = realtime()
    if now < rec.reported or now - rec.reported >= rec.report then
        rec.reported = now
        print(("[%s] %d ayar onerilen degerine donduruldu (orn. %s)"):format(SCRIPT, count, example))
    end
end

if menu.recommended ~= nil then
    menu.recommended:set_callback(function()
        if on(menu.recommended) then
            pcall(apply_recommended)
        end
    end)
end
apply_recommended()
recommended_state.pending, recommended_state.report_off = true, true
if menu_failures > 0 then
    print(("[%s] toplam %d menu ogesi olusturulamadi"):format(SCRIPT, menu_failures))
end
end

-- Config yuklenince onerilen ayarlar yeniden kontrol edilir (asagida, olaylar bolumunde).

-------------------------------------------------------------------------------
-- Durum tespiti
-------------------------------------------------------------------------------

-- GameSense'te komut tuslari sayidir (0 / 1).
local function pressed(value)
    return value == true or value == 1
end

local function index_of(ent)
    if finite(ent) and ent > 0 then
        return ent
    end
    return nil
end

-- Canli, dormant olmayan dusmanlar (GameSense entity.get_players(true) olu ve dormant oyunculari vermez).
local function enemy_list()
    local list = try(entity.get_players, true)
    local out = {}
    if type(list) == "table" then
        for _, ent in ipairs(list) do
            if finite(ent) and alive(ent) and not dormant(ent) then
                out[#out + 1] = ent
            end
        end
    end
    return out
end

-- Diger dusmanlar: her guncellemede tehdit disindaki iki dusman sirayla kontrol edilir; bir dusmanin
-- gorusu K.OTHER_HOLD tick gecerli sayilir. Log icin: sight[index] = { first, last } = bir dusmanin kafani
-- kesintisiz gordugu ilk ve son tick (gap tick'ten uzun kesilen gorus yeni gorus, keep tick sonra unutulur).
K.SIGHT = { gap = 24, keep = 64, recent = 32 }

-- others[index] = dusmanin kafani en son gordugu tick; any = kisa sure icinde biri gordu; peeked = bir
-- dusman hareket ederek kafani gorecegi yere geliyor; edge = kafa kenari (birim); peeking = AI peek'in
-- su an peek attigi dusman; enemy_peek = kafani goren dusman sana peek atiyor; duel = aimbot'un en son
-- ates ettigi dusman.
local exposure = { available = trace_available, tick = -1000, now = false, soon = false,
    any = false, peeked = false, others = {}, turn = 0, sight = {}, facing = nil, edge = 3.5, peeking = nil,
    enemy_peek = false, fresh = 16, peek_speed = 120, duel = nil, duel_hold = 1.0 }
-- AA'nin baktigi tehdit (GameSense client.current_threat); tick basina bir kez okunur.
local current_threat, aa_threat
do
local threat_cache = { tick = nil, value = nil }
current_threat = function()
    local tick = tickcount()
    if threat_cache.tick ~= tick then
        local threat = try(client.current_threat)
        threat_cache.tick = tick
        threat_cache.value = (finite(threat) and threat > 0 and alive(threat)) and threat or nil
    end
    return threat_cache.value
end

-- GameSense'in tehdidi yoksa en yakin canli, dormant olmayan dusman (oyun loglarinda "tehdit yok" iken
-- havada kafadan vuruldun: AA hicbir dusmana gore donmuyordu).
aa_threat = function()
    local threat = current_threat()
    if threat ~= nil and not dormant(threat) then
        return threat
    end
    local tick = tickcount()
    if threat_cache.near_tick ~= tick then
        threat_cache.near_tick, threat_cache.near = tick, nil
        local mine = origin_of(local_player())
        if mine ~= nil then
            local best = huge
            for _, enemy in ipairs(enemy_list()) do
                local pos = origin_of(enemy)
                if pos ~= nil then
                    local dx, dy, dz = pos.x - mine.x, pos.y - mine.y, pos.z - mine.z
                    local distance = dx * dx + dy * dy + dz * dz
                    if distance < best then
                        best, threat_cache.near = distance, enemy
                    end
                end
            end
        end
    end
    return threat_cache.near or threat
end
end

-- Bir noktanin iki yani: from'dan bakis cizgisine dik, yatayda edge birim (kafanin kenarlari).
local function side_points(point, from, edge)
    local sx, sy = point.x - from.x, point.y - from.y
    local length = sqrt(sx * sx + sy * sy)
    if length < 1 then
        return {}
    end
    local ex, ey = -sy / length * edge, sx / length * edge
    return { vector(point.x + ex, point.y + ey, point.z), vector(point.x - ex, point.y - ey, point.z) }
end

-- Dusman kafana mermi gecirebiliyor mu. Merkez gorunmuyorsa kafanin iki yan kenarina da (exposure.edge
-- birim) iz atilir: dusmanin aimbot'u kafanin kenarina da ates eder.
local function head_visible_to(threat, eye, head, dx, dy, dz)
    local me = local_player()
    local point = vector(head.x + dx, head.y + dy, head.z + dz)
    local function hits(p)
        local damage = bullet_damage(threat, eye, p, me)
        return damage ~= nil and damage > 0
    end
    if hits(point) then
        return true
    end
    for _, p in ipairs(side_points(point, eye, exposure.edge)) do
        if hits(p) then
            return true
        end
    end
    return false
end

local update_exposure
do
-- K.LOOKAHEAD sonra kafa ne kadar yukari / asagi gidecek.
local function vertical_lookahead(lp, cmd)
    local vz
    if not on_ground(lp) then
        vz = velocity_of(lp).z
    elseif pressed(cmd.in_jump) then
        vz = K.JUMP_SPEED
    else
        return 0
    end
    local t = K.LOOKAHEAD
    return vz * t - 0.5 * K.GRAVITY * t * t
end

-- Dusmanin K.LOOKAHEAD sn sonraki goz konumu (yatay hiziyla); durgunsa nil.
local function enemy_eye_ahead(enemy, eye)
    local v = velocity_of(enemy)
    if v.x * v.x + v.y * v.y < 400 then
        return nil
    end
    return vector(eye.x + v.x * K.LOOKAHEAD, eye.y + v.y * K.LOOKAHEAD, eye.z)
end

    local function mark_sight(index, now)
        local s = exposure.sight[index]
        if s == nil or now < s.last or now - s.last > K.SIGHT.gap then
            exposure.sight[index] = { first = now, last = now }
        else
            s.last = now
        end
    end

    -- Bize peek atan dusman: kafani goruyor ve ya yeni gorundu ya da hizla hareket ediyor.
    local function peeking_us(enemy, index, now)
        local s = exposure.sight[index]
        if s ~= nil and now >= s.first and now - s.first <= exposure.fresh then
            return true
        end
        return speed2d(enemy) >= exposure.peek_speed
    end

    update_exposure = function(lp, cmd)
        if not exposure.available then
            return
        end
        local now = tickcount()
        if now >= exposure.tick and now - exposure.tick < K.EXPOSE_EVERY then
            return
        end
        exposure.tick = now
        exposure.now, exposure.soon, exposure.peeked, exposure.enemy_peek = false, false, false, false
        local head = hitbox_of(lp, 0)
        if head == nil then
            exposure.any, exposure.others = false, {}
            return
        end
        -- Fake duck'ta kafa egilip kalkar; dusman kafayi ayakta yuksekliginde de gorur.
        local base = fd_on() and origin_of(lp) or nil
        if base ~= nil and head.z < base.z + 64 then
            head = vector(head.x, head.y, base.z + 64)
        end

        local threat = aa_threat()
        local threat_index = index_of(threat)
        if threat ~= nil and not dormant(threat) then
            local eye = eye_of(threat)
            if eye ~= nil then
                exposure.now = head_visible_to(threat, eye, head, 0, 0, 0)
                if exposure.now and threat_index ~= nil then
                    mark_sight(threat_index, now)
                    exposure.enemy_peek = peeking_us(threat, threat_index, now)
                end
                if not exposure.now then
                    local velocity = velocity_of(lp)
                    exposure.soon = head_visible_to(threat, eye, head, velocity.x * K.LOOKAHEAD,
                        velocity.y * K.LOOKAHEAD, vertical_lookahead(lp, cmd))
                end
                if not exposure.now and not exposure.soon then
                    local ahead = enemy_eye_ahead(threat, eye)
                    exposure.peeked = ahead ~= nil and head_visible_to(threat, ahead, head, 0, 0, 0)
                    exposure.soon = exposure.peeked
                end
            end
        end

        local present, candidates = {}, {}
        for _, enemy in ipairs(enemy_list()) do
            if enemy ~= threat_index then
                present[enemy] = true
                candidates[#candidates + 1] = enemy
            end
        end
        for _ = 1, min(2, #candidates) do
            exposure.turn = exposure.turn % #candidates + 1
            local pick = candidates[exposure.turn]
            local eye = eye_of(pick)
            if eye ~= nil and head_visible_to(pick, eye, head, 0, 0, 0) then
                exposure.others[pick] = now
                mark_sight(pick, now)
                exposure.enemy_peek = exposure.enemy_peek or peeking_us(pick, pick, now)
            else
                local ahead = eye ~= nil and enemy_eye_ahead(pick, eye) or nil
                if ahead ~= nil and head_visible_to(pick, ahead, head, 0, 0, 0) then
                    exposure.others[pick] = now
                    exposure.peeked = true
                else
                    exposure.others[pick] = nil
                end
            end
        end
        exposure.any = false
        for index, seen in pairs(exposure.others) do
            if not present[index] or now < seen or now - seen > K.OTHER_HOLD then
                exposure.others[index] = nil
            else
                exposure.any = true
            end
        end
        for index, s in pairs(exposure.sight) do
            if now < s.last or now - s.last > K.SIGHT.keep then
                exposure.sight[index] = nil
            end
        end
    end
end

-- Herhangi bir dusman kafani goruyor ya da tehdit birazdan gorecek. Kafanin yanindan mermi atan dusman
-- (bkz. bullet_impact) izler onu gormese bile seni goruyor demektir.
local seen_by_enemy, recent_shooter, duel_target
do
    local function shot_recently(hold)
        local now = tickcount()
        return exposure.shot ~= nil and now >= exposure.shot.tick and now - exposure.shot.tick <= hold
    end

    seen_by_enemy = function()
        return exposure.now or exposure.soon or exposure.any or shot_recently(32)
    end

    -- Tehdit seni gormuyorken son 1 sn icinde kafana ates eden dusman; yoksa nil.
    recent_shooter = function()
        if exposure.now or exposure.soon or not shot_recently(64) then
            return nil
        end
        local ent = exposure.shot.index
        if alive(ent) and not dormant(ent) then
            return ent
        end
        return nil
    end

    -- Aimbot'un son duel_hold sn icinde ates ettigi dusman, hayattaysa ve kafani goruyorsa; yoksa nil.
    duel_target = function()
        local d = exposure.duel
        local now = realtime()
        if d == nil or now < d.time or now - d.time > exposure.duel_hold then
            return nil
        end
        local ent = d.index
        if not alive(ent) or dormant(ent) then
            return nil
        end
        local tick, seen = tickcount(), exposure.others[ent]
        local sees = seen ~= nil and tick >= seen and tick - seen <= K.OTHER_HOLD
        local threat = aa_threat()
        if threat ~= nil and threat == ent then
            sees = exposure.now or exposure.soon
        end
        return sees and ent or nil
    end
end

-- Tehdit seni gormuyor ama baska bir dusman goruyorsa, en son goren o dusman; yoksa nil.
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
    if best ~= nil and alive(best) then
        return best
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

    local motion = { ground_ticks = 64, moving = false, ducked = false }
    local peek = { until_tick = -1000 }

    detect_movement = function(lp, cmd)
        motion.ground_ticks = on_ground(lp) and min(motion.ground_ticks + 1, 64) or 0

        local speed = speed2d(lp)
        if speed > MOVE_ENTER then
            motion.moving = true
        elseif speed < MOVE_LEAVE then
            motion.moving = false
        end

        local duck = prop(lp, "m_flDuckAmount")
        duck = finite(duck) and duck or 0
        if duck > DUCK_ENTER then
            motion.ducked = true
        elseif duck < DUCK_LEAVE then
            motion.ducked = false
        end

        local crouching = motion.ducked or fd_on()
        if pressed(cmd.in_jump) or motion.ground_ticks < LANDING_TICKS then
            return crouching and "Air crouch" or "Air"
        end
        -- Fake duck peek'ten de once gelir: exploit calismadigi icin AA tek basina korur.
        if fd_on() then
            return "Fake duck"
        end
        -- Peek Assist tusu basili: sadece gercekten peek atarken (hareket ediyorsun ya da AI peek yuruyor /
        -- noktada bekliyor) Peek. Dururken tus basili olsa da durusun AA'si kalir (V1.0).
        if peek_key_held() and (motion.moving or exposure.peeking ~= nil) then
            return "Peek"
        end
        -- Hareket ederken tehdidin gorus alanina girmek = peek.
        if on(menu.auto_peek) and motion.moving then
            if seen_by_enemy() then
                peek.until_tick = tickcount() + K.PEEK_HOLD
            end
            local now = tickcount()
            if now >= peek.until_tick - K.PEEK_HOLD and now <= peek.until_tick then
                return "Peek"
            end
        end
        if crouching then
            return motion.moving and "Crouch move" or "Crouching"
        end
        if motion.moving then
            return slowwalk_on() and "Slow walk" or "Moving"
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

-- Silahin sinif adi. R8, Desert Eagle ile ayni sinifi (CDEagle) kullandigi icin item index'ine (64)
-- bakilip "Revolver" olarak ayrilir.
local function weapon_class(ent)
    local weapon = weapon_of(ent)
    if weapon == nil then
        return nil
    end
    local class = try(entity.get_classname, weapon)
    if type(class) ~= "string" then
        return nil
    end
    if class == "CDEagle" then
        local index = prop(weapon, "m_iItemDefinitionIndex")
        if finite(index) and bit.band(index, 0xFFFF) == 64 then
            return "Revolver"
        end
    end
    return class
end

local function is_grenade(class)
    return class ~= nil and (class:find("Grenade", 1, true) ~= nil or class:find("Flashbang", 1, true) ~= nil
        or class:find("Molotov", 1, true) ~= nil or class:find("Decoy", 1, true) ~= nil
        or class:find("Incendiary", 1, true) ~= nil)
end

-- Silah lead sn icinde ates edebilecek mi: surgu, R8, sarjor degisimi ya da yeni alinmis silah. Okunamazsa
-- evet (hicbir sey engellenmez).
local function weapon_ready(lp, lead)
    local weapon = weapon_of(lp)
    if weapon == nil then
        return true
    end
    local clip = prop(weapon, "m_iClip1")
    if finite(clip) and clip == 0 then
        return false
    end
    local next_attack, player_next = prop(weapon, "m_flNextPrimaryAttack"), prop(lp, "m_flNextAttack")
    local at = max(finite(next_attack) and next_attack or 0, finite(player_next) and player_next or 0)
    return at - curtime() <= lead
end

-- Silah grubu (GameSense "Weapon type" adlari): rage ayarlarini sadece elindeki silahin grubu seciliyken
-- degistirmek icin.
local rage_scope
do
local WEAPON_TYPES = {
    CWeaponSSG08 = "SSG 08", CWeaponAWP = "AWP", Revolver = "R8 Revolver", CDEagle = "Desert Eagle",
    CWeaponSCAR20 = "G3SG1 / SCAR-20", CWeaponG3SG1 = "G3SG1 / SCAR-20", CWeaponTaser = "Zeus",
    CWeaponGlock = "Pistol", CWeaponHKP2000 = "Pistol", CWeaponP250 = "Pistol", CWeaponElite = "Pistol",
    CWeaponFiveSeven = "Pistol", CWeaponTec9 = "Pistol", CWeaponUSP = "Pistol", CWeaponCZ75a = "Pistol",
    CAK47 = "Rifle", CWeaponM4A1 = "Rifle", CWeaponAug = "Rifle", CWeaponSG556 = "Rifle", CWeaponFamas = "Rifle",
    CWeaponGalilAR = "Rifle", CWeaponNOVA = "Shotgun", CWeaponXM1014 = "Shotgun", CWeaponSawedoff = "Shotgun",
    CWeaponMag7 = "Shotgun", CWeaponMAC10 = "SMG", CWeaponMP7 = "SMG", CWeaponMP9 = "SMG", CWeaponP90 = "SMG",
    CWeaponBizon = "SMG", CWeaponUMP45 = "SMG", CWeaponM249 = "Machine gun", CWeaponNegev = "Machine gun",
}

-- Elindeki silahin grubu menude seciliyse onun adi ("all": GameSense surumunde silah grubu yok); degilse
-- nil (o tick rage ayarina yazilmaz: menude baska bir grubu inceliyor olabilirsin).
rage_scope = function(class)
    if refs.weapon_type == nil then
        return "all"
    end
    local expected = class ~= nil and WEAPON_TYPES[class] or nil
    local selected = try(ui.get, refs.weapon_type)
    if expected ~= nil and selected == expected then
        return selected
    end
    return nil
end
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
        if not on(menu.safe_head) then
            return false
        end
        if move_state == "Air crouch" then
            if on(menu.safe_air) then
                return true
            end
            if on(menu.safe_knife) and MELEE[class] then
                return true
            end
        end
        return HIGH_GROUND_STATES[move_state] == true and on(menu.safe_high) and on_high_ground(lp)
            and (not exposure.available or exposure.now)
    end
end

local function freestanding_allowed(move_state)
    local auto = on(menu.fs_auto) and (move_state == "Standing" or move_state == "Crouching")
    if not on(menu.freestanding) and not auto then
        return false
    end
    if (move_state == "Air" or move_state == "Air crouch") and on(menu.fs_air) then
        return false
    end
    if (move_state == "Crouching" or move_state == "Crouch move" or move_state == "Fake duck") and on(menu.fs_crouch) then
        return false
    end
    if move_state == "Slow walk" and on(menu.fs_slow) then
        return false
    end
    if (move_state == "Moving" or move_state == "Peek") and on(menu.fs_moving) then
        return false
    end
    return true
end

-- Freestanding kafayi saklayamadiysa (kafa yine de aciktaysa) normal hareket durumunun jitter'i kullanilir.
-- GameSense freestanding'in bir duvar bulup bulmadigini lua'ya vermez; gorus izi karar verir.
local function freestanding_has_target()
    return not (exposure.available and exposure.now)
end

-- DT sarji (GameSense'te API yok). Sarjliyken tickbase tick sayisinin sarj kadar gerisinde kalir: sarjsiz
-- (DT kapali ya da atistan hemen sonra) fark en yuksek; sarj doldukca fark azalir. base = sarjsiz fark
-- (en yuksek gorulen; DT kapaliyken tam olarak olculur), shift = base - simdiki fark. Beklenen sarj:
-- sv_maxusrcmdprocessticks - DT fake lag limit - 1 (varsayilan 14). value 0-1.
local charge = { base = nil, shift = 0, value = 0, expected = 14, offset = 0 }

charge.update = function(lp)
    local tb = prop(lp, "m_nTickBase")
    if not finite(tb) then
        return
    end
    local offset = tb - tickcount()
    charge.offset = offset
    local latency = try(client.latency)
    local guess = floor((finite(latency) and latency or 0) / tick_interval() + 0.5) + 1
    if charge.base == nil or abs(offset - charge.base) > 64 then
        charge.base = max(offset, guess)
    end
    local maxshift = refs.maxshift ~= nil and get("maxshift") or 16
    local fakelag = refs.dt_fakelag ~= nil and get("dt_fakelag") or 1
    maxshift = finite(maxshift) and maxshift or 16
    fakelag = finite(fakelag) and fakelag or 1
    charge.expected = max(6, min(16, maxshift - fakelag - 1))
    if not dt_on() or offset > charge.base then
        charge.base = offset
    end
    local shift = charge.base - offset
    -- Ping dustuyse base eskidi: sarj beklenenden fazla gorunmesin.
    if shift > charge.expected + 3 then
        charge.base = offset + charge.expected
        shift = charge.expected
    end
    charge.shift = max(0, shift)
    charge.value = dt_on() and max(0, min(1, charge.shift / max(1, min(10, charge.expected - 2)))) or 0
end

-- Neverlose'daki rage.exploit:get() karsiligi: DT acikken 0-1 sarj, kapaliyken nil.
local function dt_charge()
    if not dt_on() then
        return nil
    end
    return charge.value
end

local function exploit_active()
    if hs_on() then
        return true
    end
    if not dt_on() then
        return false
    end
    return charge.value >= 1
end

local spin_active
do
    local enemies = { tick = -1000, alive = true }

    -- Dormant dusmanlar da sayilir; gorunmuyorlar diye spin'e gecmek tehlikeli.
    local function enemies_alive()
        local now = tickcount()
        if now >= enemies.tick and now - enemies.tick < 16 then
            return enemies.alive
        end
        enemies.tick = now
        local resource = try(entity.get_player_resource)
        local count = try(globals.maxplayers) or 64
        if resource == nil then
            enemies.alive = true
            return true
        end
        enemies.alive = false
        for i = 1, count do
            local state = prop(resource, "m_bAlive", i)
            if (state == 1 or state == true) and is_enemy(i) then
                enemies.alive = true
                break
            end
        end
        return enemies.alive
    end

    spin_active = function()
        if not on(menu.spin) then
            return false
        end
        if on(menu.spin_warmup) then
            local rules = try(entity.get_game_rules)
            local warmup = rules ~= nil and prop(rules, "m_bWarmupPeriod") or nil
            if warmup == 1 or warmup == true then
                return true
            end
        end
        return on(menu.spin_enemies) and not enemies_alive()
    end
end

local legit_use_active
do
    local OBJECTIVE_RANGE = 100

    -- CT olarak kurulu bombanin ya da bir rehinenin yanindaysak E'ye basili tutmak gercekten gerekli.
    local function near_objective(lp)
        if prop(lp, "m_iTeamNum") ~= 3 then
            return false
        end
        local mine = origin_of(lp)
        if mine == nil then
            return false
        end
        for _, class in ipairs({ "CPlantedC4", "CHostage" }) do
            local list = try(entity.get_all, class)
            if type(list) == "table" then
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

    -- E'ye basili tutarken AA calismaya devam etsin (GameSense +use'ta AA'yi kapatir). Ilk tick'ler oyuna
    -- gecer ki kapi acma / silah alma bozulmasin; defuse ve rehine tasimaya hic karisilmaz.
    legit_use_active = function(lp, cmd)
        if not on(menu.legit_use) or not pressed(cmd.in_use) or near_objective(lp) then
            use.start = nil
            return false
        end
        local now = tickcount()
        if use.start == nil or use.start > now then
            use.start = now
        end
        if now - use.start >= 2 then
            pcall(function() cmd.in_use = 0 end)
        end
        return true
    end
end

-------------------------------------------------------------------------------
-- Anti-aim: anti-bruteforce
-------------------------------------------------------------------------------

local MANUAL_YAW = { Left = -90, Right = 90, Forward = 180 }

-- Anti-brute fazlari (Neverlose V1.0 ile ayni): her isabet / yakin kacan mermide bir sonrakine gecer.
-- Faz 1: Static'te tarafi cevirir, jitter'da desync'i yaw sirasinin tersine kaydirir. 2-3: kafa +-15
-- derece kayar. 4: desync tarafi her flip'te rastgele. 5: sabit desync, tarafi GameSense'in "Freestanding
-- body yaw"i secer (gercek kafa duvar tarafinda). Desync hicbir fazda dusurulmez.
local BRUTE_PHASES = {
    { invert = true,  scale = 1.0,  shift = 0 },
    { invert = false, scale = 1.0,  shift = 15 },
    { invert = true,  scale = 0.85, shift = -15 },
    { invert = false, scale = 1.0,  shift = 0, random = true },
    { invert = false, scale = 1.0,  shift = 0, freestand = true },
}

-- enemies[key] = { stage, time, base, learned, last, shot_stage, name, seen }; anahtar Steam ID.
-- phases[grup][faz] = { shots, hits }; default[grup] = verisi olmayan dusmanlara uygulanan faz.
local brute = { enemies = {}, recent = nil, hurt = {}, phases = {}, default = {},
    groups = { "still", "move", "peek", "air" },
    group_of = { Moving = "move", ["Slow walk"] = "move", ["Crouch move"] = "move", Peek = "peek",
        Air = "air", ["Air crouch"] = "air" },
    group_label = { still = "yerde", move = "hareket", peek = "peek", air = "hava" },
    migrate = { peek = "move" } }

brute.reset_phases = function()
    for _, grp_name in ipairs(brute.groups) do
        brute.phases[grp_name], brute.default[grp_name] = {}, 0
        for phase = 0, #BRUTE_PHASES do
            brute.phases[grp_name][phase] = { shots = 0, hits = 0 }
        end
    end
end
brute.reset_phases()

brute.group_for = function(state)
    return brute.group_of[state] or "still"
end
-- Ogrenilenler GameSense'in database deposuna yazilir (Neverlose surumunden ayri anahtar).
local persist = { key = "nykle_win_gs_memory", every = 60, dirty = false, saved = -huge }

-- Oran (isabet + 2) / (mermi + 4) (sniper exploit icin).
brute.rate = function(stat)
    return (stat.hits + 2) / (stat.shots + 4)
end

-- Fazlar icin (V1.0): on bilgi 0.3, agirlik 8; ~%40'in ustunde vurulan faz yerine denenmemis olan denenir.
brute.phase_rate = function(stat)
    return (stat.hits + 2.4) / (stat.shots + 8)
end

local function brute_default(grp_name)
    local list, current_default = brute.phases[grp_name], brute.default[grp_name]
    local best, best_rate = 0, huge
    for phase = 0, #BRUTE_PHASES do
        local rate = brute.phase_rate(list[phase])
        if rate < best_rate - 1e-9 then
            best, best_rate = phase, rate
        end
    end
    if best ~= current_default and best_rate < brute.phase_rate(list[current_default]) - 0.1 - 1e-9 then
        return best
    end
    return current_default
end

-- Sayilar 40'i gecince yarilanir: son karsilasmalar agir basar.
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

local function record_phase(grp_name, phase, hit)
    local list = brute.phases[grp_name]
    if list == nil or list[phase] == nil then
        return
    end
    brute.count(list[phase], hit)
    local best = brute_default(grp_name)
    if best ~= brute.default[grp_name] then
        brute.default[grp_name] = best
        if on(menu.hit_log) then
            local chosen = list[best]
            print(("[%s] AA (%s): en az vurulan faz %d (%d/%d kafa isabeti) -> verisi olmayan dusmanlara faz %d"):format(
                SCRIPT, brute.group_label[grp_name], best, floor(chosen.hits + 0.5), floor(chosen.shots + 0.5), best))
        end
    end
end

local function brute_entry_stage(entry, grp_name)
    if entry == nil then
        return brute.default[grp_name]
    end
    local now = realtime()
    local reset_after = menu.brute_reset ~= nil and menu.brute_reset:get() or 6
    if entry.stage > 0 and now >= entry.time and now - entry.time <= reset_after then
        return entry.stage
    end
    if entry.learned then
        return entry.base
    end
    return brute.default[grp_name]
end

-- Scout / AWP / R8 (tek atisli silahlar).
local SNIPERS = { CWeaponSSG08 = true, CWeaponAWP = true, Revolver = true }

-- Sniper'da hangi exploit daha az kafadan vurduruyor (Auto learn): en az 4 mermi gormeden degismez,
-- digerinin orani 0.1 daha iyiyse ona gecer.
-- V1.0.9: GameSense'te once DT. HS ile defensive zorlanamiyor (DT sarji yok; oyun logu: scout'ta HS iken
-- olumlerin hepsinde "HS LC, DEF yok"): scout'ta peek'e karsi defensive, havada air lag ve teleport hic
-- calismiyordu; DT ile calisir. Kesif: kullanilan exploit'te 8+ mermide kafa orani %40+ ve oteki hic
-- denenmemisse (4 mermiden az) oteki denenir (eskiden denenmemisin 0.5 on bilgisi yuzunden takili kaliyordu).
-- V1.0.15: "mermi" = dusmanin sana attigi her mermi: iska, govde ya da kafa (eskiden govde sayilmiyordu).
-- V1.0.16: kendi 4 mermisi olmayan exploit'e oran karsilastirmasiyla gecilmez, sadece kesifle (oyun logu:
-- "Hide shots 0/0, Double tap 4/4 -> Hide shots"; denenmemisin 0.5 on bilgisi 4 mermide DT'yi kapatiyordu).
local sniper = { stats = { hs = { shots = 0, hits = 0 }, dt = { shots = 0, hits = 0 } }, choice = "dt", min_shots = 4,
    explore_shots = 8, explore_rate = 0.4 }

sniper.mode = function(class)
    if not SNIPERS[class] or fd_on() then
        return nil
    end
    if dt_on() then
        return "dt"
    end
    if hs_on() then
        return "hs"
    end
    return nil
end

sniper.decide = function()
    local mine = sniper.stats[sniper.choice]
    if mine.shots < sniper.min_shots then
        return sniper.choice, false
    end
    local other = sniper.choice == "hs" and "dt" or "hs"
    if sniper.stats[other].shots < sniper.min_shots then
        if mine.shots >= sniper.explore_shots and mine.hits / mine.shots >= sniper.explore_rate then
            return other, true
        end
        return sniper.choice, false
    end
    local hs, dt = brute.rate(sniper.stats.hs), brute.rate(sniper.stats.dt)
    if sniper.choice == "hs" and dt < hs - 0.1 then
        return "dt"
    elseif sniper.choice == "dt" and hs < dt - 0.1 then
        return "hs"
    end
    return sniper.choice
end

-- Sunucu exploit'li atisi reddediyor mu (V1.0.8, oyun logu: Hide shots acikken arka arkaya "damage
-- rejection"): lua'nin kendi lag'i yokken ayni exploit'le (HS / DT) 60 sn icinde 2 damage rejection /
-- unregistered shot -> sniper'larda (Auto) o exploit 5 dk kullanilmaz, oteki secilir. Tek olay kanit sayilmaz.
sniper.rejects, sniper.avoid = { hs = {}, dt = {} }, { hs = -1000, dt = -1000 }

sniper.avoided = function(mode)
    local until_time, now = sniper.avoid[mode], realtime()
    return until_time ~= nil and now < until_time and now >= until_time - 300
end

sniper.reject = function(mode, reason)
    local list = sniper.rejects[mode]
    if list == nil then
        return
    end
    local now, kept = realtime(), {}
    for _, t in ipairs(list) do
        if now >= t and now - t <= 60 then
            kept[#kept + 1] = t
        end
    end
    kept[#kept + 1] = now
    sniper.rejects[mode] = kept
    if #kept >= 2 and not sniper.avoided(mode) then
        sniper.avoid[mode], sniper.rejects[mode] = now + 300, {}
        if on(menu.shot_log) then
            print(("[%s] sunucu %s ile atilan atislari reddediyor (60 sn'de 2 kez, son: %s) -> sniper'da 5 dk %s"):format(
                SCRIPT, mode == "hs" and "Hide shots" or "Double tap", reason, mode == "hs" and "Double tap" or "Hide shots"))
        end
    end
end

sniper.record = function(mode, hit)
    local stat = mode ~= nil and sniper.stats[mode] or nil
    if stat == nil then
        return
    end
    brute.count(stat, hit)
    local choice, exploring = sniper.decide()
    if choice ~= sniper.choice then
        sniper.choice = choice
        if on(menu.hit_log) then
            local hs, dt = sniper.stats.hs, sniper.stats.dt
            print(("[%s] sniper exploit: Hide shots %d/%d, Double tap %d/%d kafa isabeti -> %s%s"):format(SCRIPT,
                floor(hs.hits + 0.5), floor(hs.shots + 0.5), floor(dt.hits + 0.5), floor(dt.shots + 0.5),
                choice == "hs" and "Hide shots" or "Double tap", exploring and " (deneme: oteki hic denenmedi)" or ""))
        end
    end
end

-- Kalici oyuncu kimligi: Steam ID (entity.get_steam64). Bot ya da okunamayan Steam ID'de isim, o da
-- yoksa slot.
player_id = function(ent)
    if ent == nil then
        return nil
    end
    local steam = try(entity.get_steam64, ent)
    if steam ~= nil then
        local text = type(steam) == "number" and ("%.0f"):format(steam) or tostring(steam)
        if #text > 4 and text ~= "0" and not text:find("BOT", 1, true) then
            return "s:" .. text
        end
    end
    local name = player_name(ent)
    if name ~= "?" then
        return "n:" .. name
    end
    return "i:" .. tostring(ent)
end

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
        if count >= K.MEMORY_LIMIT and oldest_id ~= nil then
            map[oldest_id] = nil
        end
        entry = make()
        map[id] = entry
    end
    entry.name, entry.seen = player_name(ent), realtime()
    return entry
end

local function brute_entry(ent, fallback_key)
    local key = player_id(ent) or fallback_key
    return key, memory_entry(brute.enemies, key, ent, function()
        return { stage = 0, time = 0, base = 0, learned = false, last = nil, shot_stage = nil }
    end)
end

-- Faz, kafani goren dusmana gore secilir (bkz. face_target: AA de ona doner).
local function brute_target()
    return duel_target() or recent_shooter() or seeing_flanker() or aa_threat()
end

local function threat_stage(grp_name)
    local threat = brute_target()
    local key = threat ~= nil and player_id(threat) or nil
    if key == nil then
        return brute_entry_stage(brute.recent ~= nil and brute.enemies[brute.recent] or nil, grp_name)
    end
    local entry = brute.enemies[key]
    if entry ~= nil then
        entry.seen = realtime()
    end
    return brute_entry_stage(entry, grp_name)
end

-------------------------------------------------------------------------------
-- Adaptive resolver
-------------------------------------------------------------------------------

-- Acilari GameSense'in kendi resolver'i cozer. Bu katman aim_hit / aim_miss sonuclarina bakar: "?" iskasi
-- (GameSense'te nedeni bilinmeyen iska = resolver; Neverlose'da "correction") sayilir. Bir dusmana karsi,
-- ATES ANINDAKI hareket durumunda son K.RESOLVER_WINDOW sonuctaki resolver iskasi sayisi seviyedir:
--   1 -> "Prefer safe point" (silahin rage ayari, tek ayar: Neverlose'daki gibi hedefin seviyesine gore)
--   2 -> oyuncu listesinde SADECE o dusmana "Override safe point: On" (Force)
--   3 -> (GameSense'e ozel, NYKLE Resolver 2.5) Force'ta da 3+ iska ya da Force ates engelliyorsa: o
--        dusmana Force body yaw hipotezleri (+limit / -limit / 0 / +limit/2 / -limit/2); kafa isabeti alan
--        aci tutulur, iskalayan aci birakilir, hepsi denenince GameSense'in resolver'ina donulur.
local SAFE_POINT_LEVELS = { [0] = "Default", "Prefer", "Force", "Hypothesis" }

local resolver = { players = {}, shots = {}, aim_target = nil, aim_time = -1000, stalls = {}, prior_logged = {},
    jittery = {}, body_stalls = {}, open_cache = {},
    -- Kendi lag'imiz sirasinda (DEF / LC / TP) sunucuda gecmeyen atislar: ayni turden ikisi 10 sn icinde
    -- olursa o lag 10 sn durur.
    unreg = { DEF = {}, LC = {}, TP = {} }, unreg_window = 10, unreg_pause = 10, tp_window = 0.3,
    pause = { DEF = -1000, LC = -1000, TP = -1000 },
    lag_names = { DEF = { "defensive", "zorlanan defensive" }, LC = { "Break LC", "Hide shots Break LC" },
        TP = { "teleport", "teleport sonrasi" } } }

resolver.paused = function(kind)
    local stop, real = resolver.pause[kind], realtime()
    return stop ~= nil and real >= stop - resolver.unreg_pause and real < stop
end

-- Dusman takibi: simulasyon zamani, konum ve bakis yonu her tick izlenir (Neverlose V1.0 ile ayni):
--  defensive: simulasyon zamani gordugumuz en yuksek degerin gerisine dustu (sahte kayit).
--  lc: iki guncelleme arasinda 64 birimden fazla yer degistirdi.
--  jitter: son gercek guncellemeler arasindaki ortalama yaw degisimi (sadece gercek kayitlardan).
--  pattern: yaw degisimlerinin YONUNE gore AA deseni (NYKLE Resolver 2.5'teki gibi isaretli farklar):
--    "jitter" 25+ derecelik degisimler sirayla saga-sola (gecikmeli jitter'daki aradaki kucuk farklar
--    sayilmaz), "spin" hep ayni yone (yavas spin: toplam 60+), "xway" son 8 acida 3-5 ayri aci kumesi
--    (3-way / 5-way, 30+ derece aralik), "random" buyuk degisimler duzensiz (skitter / random jitter),
--    "static" hic buyuk degisim yok; ayni sonuc iki guncelleme ust uste cikinca desen degisir. Jitter, xway
--    ve random cok tarafli desenlerdir (MULTI): sabit bir body yaw onlarin ancak bir kismini tutar.
--  fakeduck: yerde, egilme yarim ve paketler bogulu iki guncelleme ust uste.
local enemy_watch = { list = {}, hold = 16, samples = 6, jitter_memory = 60, pattern_big = 25,
    yaw_samples = 8, group_gap = 12, fd_low = 0.05, fd_high = 0.95, fd_choke = 6, fd_hold = 32,
    multi = { jitter = true, xway = true, random = true },
    patterns = { "jitter", "static", "spin", "xway", "random" } }
do
    local function eye_yaw(ent)
        local _, yaw = prop(ent, "m_angEyeAngles")
        if finite(yaw) then
            return yaw
        end
        yaw = prop(ent, "m_angEyeAngles[1]")
        if finite(yaw) then
            return yaw
        end
        return nil
    end

    -- Hafizada fake duck yaptigi bilinen dusman tek guncellemede isaretlenir (digerleri iki guncelleme ust uste).
    local function fresh(sim, enemy)
        local key = player_id(enemy)
        local habit = key ~= nil and resolver.habit(resolver.players[key]) or nil
        return { sim = sim, max_sim = sim, origin = origin_of(enemy), yaw = eye_yaw(enemy), deltas = {},
            def_tick = -1000, lc_tick = -1000, fd_tick = -1000, fd_count = 0,
            fd_need = (habit ~= nil and habit.fd >= 0.15) and 1 or 2,
            yaws = {}, pattern = nil, proposal = nil, proposal_n = 0 }
    end

    -- Son acilarin kac ayri kumede toplandigi (aralarinda group_gap'ten buyuk bosluk) ve araligi.
    local function yaw_groups(yaws)
        if #yaws < 6 then
            return nil
        end
        local base, rel = yaws[#yaws], {}
        for i, y in ipairs(yaws) do
            rel[i] = (y - base + 180) % 360 - 180
        end
        table.sort(rel)
        local groups, last = 0, nil
        for _, v in ipairs(rel) do
            if last == nil or v - last > enemy_watch.group_gap then
                groups = groups + 1
            end
            last = v
        end
        return groups, rel[#rel] - rel[1]
    end

    local function classify(t)
        local deltas = t.deltas
        if #deltas < 4 then
            return nil
        end
        local big, flips, same, prev, pos, neg, total = 0, 0, 0, nil, 0, 0, 0
        for _, d in ipairs(deltas) do
            total = total + abs(d)
            if d > 0 then
                pos = pos + 1
            elseif d < 0 then
                neg = neg + 1
            end
            if abs(d) >= enemy_watch.pattern_big then
                big = big + 1
                local sign = d > 0
                if prev ~= nil then
                    if sign ~= prev then
                        flips = flips + 1
                    else
                        same = same + 1
                    end
                end
                prev = sign
            end
        end
        if big >= 3 and (flips >= big - 1 or (big >= 5 and flips >= big - 2)) then
            return "jitter"
        end
        if big >= 3 and same >= big - 1 then
            return "spin"
        end
        if (pos == #deltas or neg == #deltas) and total >= 60 then
            return "spin"
        end
        local groups, span = yaw_groups(t.yaws)
        if groups ~= nil and groups >= 3 and groups <= 5 and span >= 30 then
            return "xway"
        end
        if big >= 3 then
            return "random"
        end
        if big == 0 then
            return "static"
        end
        return nil
    end

    -- Karar verilemeyen guncelleme (tek bir donus gibi) deseni degistirmez.
    local function observe(t)
        local proposal = classify(t)
        if proposal == nil then
            return
        end
        if proposal == t.proposal then
            t.proposal_n = t.proposal_n + 1
        else
            t.proposal, t.proposal_n = proposal, 1
        end
        if t.proposal_n >= 2 then
            t.pattern = proposal
        end
    end

    local function ducking_fake(enemy, choked)
        local flags, duck = prop(enemy, "m_fFlags"), prop(enemy, "m_flDuckAmount")
        return finite(flags) and bit.band(flags, 1) ~= 0 and finite(duck)
            and duck > enemy_watch.fd_low and duck < enemy_watch.fd_high and choked >= enemy_watch.fd_choke
    end

    enemy_watch.update = function()
        local now = tickcount()
        local present = {}
        for _, enemy in ipairs(enemy_list()) do
            local sim = prop(enemy, "m_flSimulationTime")
            if finite(sim) then
                present[enemy] = true
                local t = enemy_watch.list[enemy]
                if t == nil or abs(sim - t.max_sim) > 1 then
                    enemy_watch.list[enemy] = fresh(sim, enemy)
                elseif sim ~= t.sim then
                    -- Log icin: iki guncelleme arasi tick (1 = bogma yok, 4 = 3 tick bogma, eksi = geri / defensive).
                    t.step = floor((sim - t.sim) / tick_interval() + 0.5)
                    local fake = sim < t.max_sim
                    if fake then
                        t.def_tick = now
                    else
                        t.max_sim = sim
                    end
                    if ducking_fake(enemy, (sim - t.sim) / tick_interval() - 0.5) then
                        t.fd_count = t.fd_count + 1
                        if t.fd_count >= t.fd_need then
                            t.fd_tick = now
                        end
                    else
                        t.fd_count = 0
                    end
                    local origin = origin_of(enemy)
                    if origin ~= nil and t.origin ~= nil then
                        local dx, dy, dz = origin.x - t.origin.x, origin.y - t.origin.y, origin.z - t.origin.z
                        if dx * dx + dy * dy + dz * dz > 64 * 64 then
                            t.lc_tick = now
                        end
                    end
                    local yaw = eye_yaw(enemy)
                    if not fake then
                        if yaw ~= nil and t.yaw ~= nil then
                            t.deltas[#t.deltas + 1] = (yaw - t.yaw + 180) % 360 - 180
                            if #t.deltas > enemy_watch.samples then
                                table.remove(t.deltas, 1)
                            end
                            t.yaws[#t.yaws + 1] = yaw
                            if #t.yaws > enemy_watch.yaw_samples then
                                table.remove(t.yaws, 1)
                            end
                            observe(t)
                        end
                        t.yaw = yaw
                    end
                    t.sim, t.origin = sim, origin
                end
            end
        end
        for index in pairs(enemy_watch.list) do
            if not present[index] then
                enemy_watch.list[index] = nil
            end
        end
    end

    -- { defensive, defensive_now, lc, fakeduck, jitter, pattern } ya da hic veri yoksa nil.
    enemy_watch.profile = function(ent)
        local t = ent ~= nil and enemy_watch.list[ent] or nil
        if t == nil then
            return nil
        end
        local now = tickcount()
        local jitter = nil
        if #t.deltas >= 4 then
            local sum = 0
            for _, d in ipairs(t.deltas) do
                sum = sum + abs(d)
            end
            jitter = sum / #t.deltas
        end
        return {
            defensive = now >= t.def_tick and now - t.def_tick <= enemy_watch.hold,
            defensive_now = t.sim < t.max_sim,
            lc = now >= t.lc_tick and now - t.lc_tick <= enemy_watch.hold,
            fakeduck = now >= t.fd_tick and now - t.fd_tick <= enemy_watch.fd_hold,
            jitter = jitter,
            pattern = t.pattern,
        }
    end
end

-- Okunamayan alanlar "Standing" sayilir. Fake duck yapan dusman ayri durum ("Fakeduck").
local function enemy_state(ent)
    local flags = prop(ent, "m_fFlags")
    if finite(flags) and bit.band(flags, 1) == 0 then
        return "Air"
    end
    local profile = enemy_watch.profile(ent)
    if profile ~= nil and profile.fakeduck then
        return "Fakeduck"
    end
    local duck = prop(ent, "m_flDuckAmount")
    if finite(duck) and duck > 0.6 then
        return "Crouch"
    end
    local speed = speed2d(ent)
    if speed > 6 then
        -- Yavas yurume (silahin en yuksek hizinin %52'si, yurume hizi alti) ayri durum: desync orada tam,
        -- kosarken azaliyor; resolver hatalari farkli oldugu icin ayri ogrenilir.
        local top = prop(ent, "m_flMaxspeed")
        local walk = (finite(top) and top > 100 and top <= 320) and top * 0.52 or 120
        return speed < walk and "Slow walk" or "Moving"
    end
    return "Standing"
end

-- Bu dusman su an kafani goruyor mu (izlere gore).
local function sees_me(enemy)
    local threat = aa_threat()
    if threat ~= nil and enemy == threat then
        return exposure.now or exposure.soon
    end
    local seen, tick = exposure.others[enemy], tickcount()
    return seen ~= nil and tick >= seen and tick - seen <= K.OTHER_HOLD
end

-- Log icin saldiran: hareket durumu, AA'nin baktigi dusman mi ve izlere gore kafani ne kadar suredir goruyordu.
local function attacker_info(ent)
    local parts = { enemy_state(ent) }
    if exposure.facing == nil then
        parts[#parts + 1] = "AA hedefi yok"
    elseif exposure.facing == ent then
        parts[#parts + 1] = "AA hedefi"
    else
        parts[#parts + 1] = "AA hedefi degil"
    end
    if exposure.available then
        local s = exposure.sight[ent]
        local now = tickcount()
        if s ~= nil and now >= s.last and now - s.last <= K.SIGHT.recent then
            parts[#parts + 1] = ("gordu %.2fs"):format((s.last - s.first) * tick_interval())
        else
            parts[#parts + 1] = "gormedi"
        end
    end
    return table.concat(parts, ", ")
end

local function resolver_entry(ent)
    local key = player_id(ent)
    if key == nil then
        return nil
    end
    return memory_entry(resolver.players, key, ent, function() return { results = {}, states = {} } end)
end

-- Kisi profili (kalici, Steam ID ile): dusman gorundukce saniyede bir ornek: AA deseni (jitter / statik /
-- spin / xway / random), son 1 sn'de defensive, fake duck. 240 ornekte hepsi yariya iner (eski aliskanlik
-- silinir). Aliskanlik: 10+ ornek; desen 8+ bilinen ornegin %60'i ayniysa. Aliskanlik sadece canli desen
-- henuz olculmemisken kullanilir; canli desen gelince dogrulanir ya da duzeltilir (bkz. resolver.observe).
resolver.habit = function(entry)
    local p = entry ~= nil and entry.profile or nil
    if p == nil or p.n < 10 then
        return nil
    end
    local pattern, best, known = nil, 0, 0
    for _, name in ipairs(enemy_watch.patterns) do
        local count = p[name] or 0
        known = known + count
        if count > best then
            pattern, best = name, count
        end
    end
    if known < 8 or best < known * 0.6 then
        pattern = nil
    end
    return { pattern = pattern, def = p.def / p.n, fd = p.fd / p.n }
end

local function window_push(list, result)
    list[#list + 1] = result
    if #list > K.RESOLVER_WINDOW then
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

-- Force (seviye 2) icin bu oturumda (bu haritada) o durumda en az bir resolver iskasi gerekir: hafizadan
-- gelen eski iskalar en fazla Prefer'e cikarir (dusman AA'sini degistirmis olabilir; ilk peek'te Force
-- safe point atisi geciktirmesin).
local function entry_level(entry, state)
    local list = entry.states[state]
    if list ~= nil and #list > 0 then
        local cap = (entry.fresh ~= nil and entry.fresh[state]) and 2 or 1
        return min(window_misses(list), cap)
    end
    return min(window_misses(entry.results), 1)
end

-- Aimbot'un hedefi: az once ates ettigi dusman, yoksa kafani goren dusman, yoksa tehdit.
local function resolver_target()
    local target = resolver.aim_target
    local since = realtime() - resolver.aim_time
    if target ~= nil and since >= 0 and since <= K.AIM_TARGET_HOLD and alive(target) then
        return target
    end
    return brute_target()
end

resolver.distance = function(target)
    local mine, theirs = origin_of(local_player()), origin_of(target)
    if mine == nil or theirs == nil then
        return nil
    end
    local dx, dy, dz = theirs.x - mine.x, theirs.y - mine.y, theirs.z - mine.z
    return sqrt(dx * dx + dy * dy + dz * dz)
end

-- Seviye, anahtar, durum, kayit, jitter on bilgisi mi ve o durumdaki resolver iskasi sayisi. Dusmanin o
-- durumda hic sonucu yoksa ve AA deseni jitter'se (bkz. enemy_watch) ilk atistan "Prefer".
local function resolver_level(target)
    if target == nil then
        return 0
    end
    local key = player_id(target)
    local entry = key ~= nil and resolver.players[key] or nil
    local state = enemy_state(target)
    local level, data, misses = 0, false, 0
    if entry ~= nil then
        entry.seen = realtime()
        level = entry_level(entry, state)
        local list = entry.states[state]
        data = list ~= nil and #list > 0
        misses = data and window_misses(list) or 0
    end
    local prior = false
    local profile = enemy_watch.profile(target)
    local now = realtime()
    if key ~= nil and profile ~= nil and enemy_watch.multi[profile.pattern] then
        resolver.jittery[key] = now
    end
    local seen = key ~= nil and resolver.jittery[key] or nil
    local jittery = seen ~= nil and now >= seen and now - seen <= enemy_watch.jitter_memory
    -- Canli desen henuz yoksa hafizadaki aliskanlik: bilinen jitter'ciye ilk atistan Prefer.
    local habit = resolver.habit(entry)
    local remembered = not jittery and (profile == nil or profile.pattern == nil)
        and habit ~= nil and enemy_watch.multi[habit.pattern] == true
    if not data and level < 1 and (jittery or remembered) then
        level, prior = 1, true
        if key ~= nil and not resolver.prior_logged[key] and on(menu.resolver_log) then
            resolver.prior_logged[key] = true
            local amount = (profile ~= nil and profile.jitter ~= nil) and (" %d%s"):format(floor(profile.jitter + 0.5), DEG) or ""
            local name = remembered and habit.pattern or (profile ~= nil and profile.pattern) or "jitter"
            print(("[%s] resolver: %s %s%s -> safe points Prefer (veri yok, %s)"):format(
                SCRIPT, player_name(target), name, amount, remembered and "hafizadan, dogrulanacak" or "on bilgi"))
        end
    end
    return level, key, state, entry, prior, misses
end

-- Force'un ates engelleyip engellemedigini izler (dusman basina); takildiysa 1 dondurur.
local function stall_level(enemy, level, key, state, entry)
    local stall = resolver.stalls[enemy]
    if level < 2 then
        resolver.stalls[enemy] = nil
        return level, false
    end
    if stall == nil or stall.key ~= key or stall.state ~= state then
        stall = { key = key, state = state, visible = 0, last = nil, relaxed = false }
        resolver.stalls[enemy] = stall
    end
    local now = realtime()
    if stall.last ~= nil and sees_me(enemy) and not stall.relaxed then
        stall.visible = stall.visible + max(0, min(0.1, now - stall.last))
        if stall.visible >= K.FORCE_STALL then
            stall.relaxed = true
            if on(menu.resolver_log) and entry ~= nil then
                print(("[%s] resolver: %s %s safe point bulunamadi, ates yok -> safe points Prefer"):format(
                    SCRIPT, entry.name, state))
            end
        end
    end
    stall.last = now
    return stall.relaxed and 1 or level, stall.relaxed
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

local function process_pending_misses()
    local now = realtime()
    for i = #pending_misses, 1, -1 do
        local miss = pending_misses[i]
        if now < miss.time or now - miss.time > K.MISS_WINDOW then
            table.remove(pending_misses, i)
            if now >= miss.time then
                local entry = stat_for(miss.state)
                entry.misses = entry.misses + 1
                record_phase(miss.group, miss.applied, false)
                sniper.record(miss.sniper, false)
                if on(menu.hit_log) then
                    print(("[%s] iska: %s | faz %d | %s | %s | %s | %s (%s)"):format(
                        SCRIPT, miss.state, miss.stage, miss.aa, miss.exploit, miss.weapon, miss.name, miss.attacker))
                end
            end
        end
    end
end

-- Rastgele degerler -1..1 (limit icin 0..1) olarak tutulur ve o anki durumun araligiyla carpilir.
local flip = { side = false, packets = 0, extra = 0, step = 0, yaw_n = 0, mod_n = 0, limit_n = 0, rand_side = false }

local current = { state = "Global", side = false, limit = 60, freestand = false, defensive = false, forced = false, lc = false,
    brute = 0, phase_group = "still", resolver = 0, res_state = nil, res_prior = false, weapon = nil, lethal = false,
    head_only = false, clean = false, hyp = nil, anti = false, fake_body = false }

-- Istatistigin yazilacagi grup; AA'si hareket durumundan farkli olan ozel durumlarda nil.
brute.unlearned = { ["Safe head"] = true, Manual = true, ["Fake duck"] = true }
brute.stat_group = function()
    if brute.unlearned[current.state] then
        return nil
    end
    return current.phase_group
end

-- Sahte kayit (defensive) icin sniper govde kurali (bkz. apply_body_aim).
resolver.fake = { ticks = 0, max = 12, cooldown = 0.5, free_until = -1000, logged = -1000, index = nil }

-- Hedefin govdesine (gogus ya da mide) gozumuzden mermi gecer mi. Iz ya da hitbox okunamazsa evet.
-- Dusman basina 4 tick onbellek.
resolver.body_open = function(target)
    if not trace_available or target == nil then
        return true
    end
    local tick = tickcount()
    local cached = resolver.open_cache[target]
    if cached ~= nil and tick >= cached.tick and tick - cached.tick < 4 then
        return cached.value
    end
    local lp = local_player()
    local eye = eye_of(lp)
    local value = true
    if eye ~= nil then
        local readable = false
        value = false
        for _, hitbox in ipairs({ 5, 3 }) do
            local point = hitbox_of(target, hitbox)
            if point ~= nil then
                readable = true
                local damage = bullet_damage(lp, eye, point, target)
                if damage ~= nil and damage > 0 then
                    value = true
                    break
                end
            end
        end
        if not readable then
            value = true
        end
    end
    resolver.open_cache[target] = { tick = tick, value = value }
    return value
end

-- "Force" sadece govdenin guvenli noktalarina ates edilebiliyorsa; yoksa en fazla "Prefer" (sniper sadece
-- oldurecek atis yaparken ya da sadece kafa gorunuyorken Force atisi tamamen keserdi).
resolver.cap = function(level, target)
    if level > 1 and ((on(menu.head_only) and SNIPERS[current.weapon]) or not resolver.body_open(target)) then
        return 1
    end
    return level
end

-- Body yaw hipotezleri (NYKLE Resolver 2.5'ten, GameSense'e ozel): store[anahtar][durum] = { candidate,
-- visited, outcomes, attempts, cooldown, feedback }. Aday 0 = GameSense'in kendi resolver'i.
-- V1.0.15: desen 20 sn'de 3 kez degisirse kararsiz sayilir (oyun logu: Vice Luaaa static / jitter / xway /
-- spin arasinda saniyede bir; her degisimde "hipotezler sifirlandi", hemen ardindan yine "3 resolver iskasi
-- -> body yaw 58"). Kararsizken hipotez yok (Force safe point kalir); yeni desen 1.5 sn oturmadan baslamaz.
local hypothesis = { store = {}, candidates = 5, attempts = 5, cooldown = 4, memory = 30,
    settle = 1.5, flip_window = 20, flip_max = 3 }

hypothesis.yaw = function(candidate)
    local limit = menu.hyp_angle ~= nil and menu.hyp_angle:get() or 58
    if candidate == 1 then return limit end
    if candidate == 2 then return -limit end
    if candidate == 3 then return 0 end
    local half = floor(limit / 2 + 0.5)
    return candidate == 4 and half or -half
end

hypothesis.get = function(key, state, make)
    if key == nil or state == nil then
        return nil
    end
    local by_state = hypothesis.store[key]
    if by_state == nil then
        if not make then
            return nil
        end
        by_state = {}
        hypothesis.store[key] = by_state
    end
    local h = by_state[state]
    if h == nil and make then
        h = { candidate = 0, visited = {}, outcomes = {}, attempts = 0, cooldown = -1000, feedback = realtime() }
        by_state[state] = h
    end
    return h
end

-- Taraf bilgisi (dusman basina 4 tick onbellek), donus: taraf ("L" / "R" / "open") ve tur:
--  "side": duvar (anti-freestand): bizim gozumuzden dusmanin kafasinin iki yanina (gorus cizgisine dik
--          24 birim) iz; tek taraf kapaliysa freestanding AA gercek kafayi o tarafa saklar.
--  "lby":  acik alanda duran dusmanda goz yaw ile LBY (alt govde yaw'i, sunucudan gelir) arasindaki fark
--          35+ ise tarafi o belirler (statik desync / LBY breaker).
--  "open": bilgi yok.
-- Adaylar "kanonik" tutulur: kapali taraf L sayilir, R'de aday aynalanir (+aci <-> -aci). Boylece duvarin
-- bir tarafinda kafadan vuran aci, dusman siperin obur tarafina gecince aynalanmis haliyle kullanilir.
hypothesis.wall = { cache = {}, radius = 24, every = 4, mirror = { 2, 1, 3, 5, 4 } }

hypothesis.wall_side = function(enemy)
    local wall, tick = hypothesis.wall, tickcount()
    local cached = wall.cache[enemy]
    if cached ~= nil and tick >= cached.tick and tick - cached.tick < wall.every then
        return cached.side, cached.kind
    end
    local side, kind = "open", "open"
    local lp = local_player()
    local eye, head = eye_of(lp), hitbox_of(enemy, 0)
    if eye ~= nil and head ~= nil then
        local dx, dy = head.x - eye.x, head.y - eye.y
        local len = sqrt(dx * dx + dy * dy)
        if len > 1 then
            local px, py = -dy / len * wall.radius, dx / len * wall.radius
            local lf, lhit = trace_line(lp, eye, vector(head.x + px, head.y + py, head.z))
            local rf, rhit = trace_line(lp, eye, vector(head.x - px, head.y - py, head.z))
            local left = lf ~= nil and lf < 0.97 and lhit ~= enemy
            local right = rf ~= nil and rf < 0.97 and rhit ~= enemy
            if left and not right then
                side, kind = "L", "side"
            elseif right and not left then
                side, kind = "R", "side"
            end
        end
    end
    if kind == "open" and on_ground(enemy) and speed2d(enemy) < 5 then
        local _, eye_yaw = prop(enemy, "m_angEyeAngles")
        local lby = prop(enemy, "m_flLowerBodyYawTarget")
        if finite(eye_yaw) and finite(lby) then
            local delta = (eye_yaw - lby + 180) % 360 - 180
            if abs(delta) >= 35 then
                side, kind = delta > 0 and "L" or "R", "lby"
            end
        end
    end
    wall.cache[enemy] = { tick = tick, side = side, kind = kind }
    return side, kind
end

-- Kanonik aday -> o anki duvar tarafindaki gercek aday.
hypothesis.actual = function(candidate, side)
    if side == "R" and candidate > 0 then
        return hypothesis.wall.mirror[candidate]
    end
    return candidate
end

-- Kalici aci sonuclari: entry.angles["Durum|desen|taraf turu"] = { {kafa, iska} x 5 } (kanonik aday
-- sirasiyla; tur "side" / "lby" / "open"). Hipotez o durum, desen ve taraf turu icin bunlarla baslar: daha
-- once kafadan vuran aci once denenir.
hypothesis.slot = function(state, key)
    return tostring(state) .. "|" .. (key or "unknown|open")
end

hypothesis.seed = function(h, entry, state, slot_key)
    local stored = entry ~= nil and entry.angles ~= nil and entry.angles[hypothesis.slot(state, slot_key)] or nil
    h.outcomes = {}
    if stored ~= nil then
        for c = 1, hypothesis.candidates do
            local o = stored[c]
            if o ~= nil and (o[1] > 0 or o[2] > 0) then
                h.outcomes[c] = { heads = o[1], misses = o[2] }
            end
        end
    end
    h.seeded = slot_key or "unknown|open"
end

-- Bilinen iyi aci: en az 2 kafa isabeti ve skoru artida olan en iyi aday.
hypothesis.known_good = function(outcomes)
    local best, best_score = nil, 0
    for c, o in pairs(outcomes) do
        local score = o.heads * 3 - o.misses
        if o.heads >= 2 and score > best_score then
            best, best_score = c, score
        end
    end
    return best
end

-- Denenmemis adaylardan en iyi skorlu (kafa * 3 - iska); yoksa nil.
hypothesis.choose = function(h)
    local best, best_score = nil, nil
    for candidate = 1, hypothesis.candidates do
        if not h.visited[candidate] then
            local o = h.outcomes[candidate] or { heads = 0, misses = 0 }
            local score = o.heads * 3 - o.misses
            if best == nil or score > best_score then
                best, best_score = candidate, score
            end
        end
    end
    return best
end

hypothesis.advance = function(h, why, name, state)
    local now = realtime()
    local nxt = h.attempts < hypothesis.attempts and hypothesis.choose(h) or nil
    if nxt == nil then
        h.candidate, h.visited, h.attempts, h.cooldown = 0, {}, 0, now + hypothesis.cooldown
    else
        h.candidate, h.visited[nxt], h.attempts = nxt, true, h.attempts + 1
    end
    h.feedback = now
    if on(menu.resolver_log) then
        local what = h.candidate == 0 and "GameSense resolver'ina donuldu (hepsi denendi)"
            or ("body yaw %d%s denenecek%s"):format(hypothesis.yaw(hypothesis.actual(h.candidate, h.side)), DEG,
                (h.kind == "side" and " (duvar " .. h.side .. ")") or (h.kind == "lby" and " (lby " .. h.side .. ")") or "")
        print(("[%s] resolver: %s %s %s -> %s"):format(SCRIPT, name or "?", state or "?", why, what))
    end
end

-- Bu dusmana su an uygulanacak hipotez yaw'i (yoksa nil). raw: takilma korumasindan onceki seviye.
-- Jitter'li dusmana hipotez yok: Force body yaw sabit bir aci yazar, her pakette taraf degistiren jitter'a
-- karsi ancak yarisini tutar; orada Force safe point (her iki taraftaki ortak noktalar) daha iyi. Dusmanin
-- deseni degisince (statik -> jitter gibi) o dusmanin o durumdaki hipotez sonuclari silinir (NYKLE
-- Resolver 2.5: "oruntu degisince sifirla").
hypothesis.update = function(enemy, key, state, raw, misses, stalled, entry)
    if not on(menu.resolver) or not on(menu.hypotheses) or not plist_available(PL.FORCE) then
        return nil
    end
    local h = hypothesis.get(key, state, raw >= 2)
    if h == nil then
        return nil
    end
    local now = realtime()
    if h.candidate > 0 and now - h.feedback > hypothesis.memory then
        h.candidate, h.visited, h.attempts = 0, {}, 0
    end
    local profile = enemy_watch.profile(enemy)
    local pattern = profile ~= nil and profile.pattern or nil
    if pattern ~= nil then
        local changed = h.pattern ~= nil and pattern ~= h.pattern
        if changed then
            h.pattern_since = now
            local flips = {}
            for _, t in ipairs(h.flips or {}) do
                if now >= t and now - t <= hypothesis.flip_window then
                    flips[#flips + 1] = t
                end
            end
            flips[#flips + 1] = now
            h.flips = flips
            if #flips >= hypothesis.flip_max then
                if now >= (h.unstable or -1000) and on(menu.resolver_log) then
                    print(("[%s] resolver: %s %s AA deseni kararsiz (%d sn'de %d degisim): hipotez yok, Force safe point"):format(
                        SCRIPT, entry ~= nil and entry.name or player_name(enemy), state, hypothesis.flip_window, #flips))
                end
                h.unstable = now + hypothesis.flip_window
            end
        end
        if changed and (h.candidate > 0 or next(h.outcomes) ~= nil) then
            if on(menu.resolver_log) and now >= (h.unstable or -1000) then
                print(("[%s] resolver: %s %s AA deseni degisti (%s -> %s): hipotezler sifirlandi"):format(SCRIPT,
                    entry ~= nil and entry.name or player_name(enemy), state, h.pattern, pattern))
            end
            h.candidate, h.visited, h.outcomes, h.attempts, h.seeded = 0, {}, {}, 0, nil
        elseif (enemy_watch.multi[pattern] or now < (h.unstable or -1000)) and h.candidate > 0 then
            h.candidate, h.visited, h.attempts = 0, {}, 0
        end
        h.pattern = pattern
    end
    -- Canli desen yoksa hafizadaki aliskanlik; o desen ve duvar durumunun kalici aci sonuclari yuklenir.
    local habit = resolver.habit(entry)
    local guess = pattern or (habit ~= nil and habit.pattern) or nil
    h.side, h.kind = hypothesis.wall_side(enemy)
    local slot_key = (guess or "unknown") .. "|" .. h.kind
    if h.candidate == 0 and h.seeded ~= slot_key then
        hypothesis.seed(h, entry, state, slot_key)
    end
    -- Baslama: Force'ta da 3+ resolver iskasi ya da Force ates engelliyor, ya da bu kiside bu durum ve desende
    -- daha once kafadan vuran bir aci var (hemen o aciyla). Jitter'li dusmanda degil.
    local known = hypothesis.known_good(h.outcomes)
    if h.candidate == 0 and raw >= 2 and (misses >= 3 or stalled or known ~= nil) and now >= h.cooldown
        and not enemy_watch.multi[guess] and now >= (h.unstable or -1000)
        and now - (h.pattern_since or -1000) >= hypothesis.settle then
        local why = stalled and "Force ates engelliyor" or (misses >= 3 and ("%d resolver iskasi"):format(misses))
            or ("hafizada kafadan vuran aci (%d kafa), dogrulanacak"):format(h.outcomes[known].heads)
        hypothesis.advance(h, why, entry ~= nil and entry.name or player_name(enemy), state)
        -- Hafizadaki aci ilk uygun atisla sinanir (dogrulandi / tutmadi).
        h.from_memory = h.candidate > 0 and not (misses >= 3 or stalled) or nil
    end
    if h.candidate > 0 then
        return hypothesis.yaw(hypothesis.actual(h.candidate, h.side)), h
    end
    return nil, h
end

-- Atis sonucunu hipoteze yazar (sadece uygun atislar: kafaya nisan, backtrack yok, teleport /
-- extrapolation / interpolation / oncelikli (ates eden) kayit yok, isabet sansi yeterli; ates aninda ayni
-- aday oyuncu listesinde gercekten uygulaniyordu, bkz. aim_fire).
hypothesis.result = function(shot, target, hit_head, miss)
    if shot == nil or shot.hyp_key == nil or shot.hyp_candidate == nil or shot.hyp_candidate == 0 then
        return
    end
    local h = hypothesis.get(shot.hyp_key, shot.state, false)
    if h == nil or h.candidate ~= shot.hyp_candidate then
        return
    end
    local eligible = shot.hitgroup == 1 and (shot.backtrack or 0) == 0 and not shot.teleported and not shot.extrapolated
        and not shot.interpolated and not shot.high_priority
        and (shot.hitchance or 0) >= (menu.hyp_chance ~= nil and menu.hyp_chance:get() or 70)
    if not eligible then
        return
    end
    local o = h.outcomes[h.candidate] or { heads = 0, misses = 0 }
    h.outcomes[h.candidate] = o
    h.feedback = realtime()
    if h.from_memory and (hit_head or miss) then
        h.from_memory = nil
        if on(menu.resolver_log) then
            print(("[%s] resolver: %s %s hafizadaki aci (body yaw %d%s) %s"):format(SCRIPT, player_name(target),
                shot.state, shot.hyp_yaw or 0, DEG, hit_head and "dogrulandi: kafa isabeti" or "tutmadi, siradaki denenecek"))
        end
    end
    -- Kalici sonuc: kisi + durum + (atis anindaki) desen ve duvar, kanonik aday.
    local entry = resolver.players[shot.hyp_key]
    local stored
    if entry ~= nil and (hit_head or miss) then
        entry.angles = entry.angles or {}
        local slot = hypothesis.slot(shot.state, shot.hyp_slot or h.seeded)
        stored = entry.angles[slot]
        if stored == nil then
            stored = {}
            for c = 1, hypothesis.candidates do
                stored[c] = { 0, 0 }
            end
            entry.angles[slot] = stored
        end
        persist.dirty = true
    end
    if hit_head then
        o.heads = min(20, o.heads + 1)
        if stored ~= nil then
            stored[h.candidate][1] = min(20, stored[h.candidate][1] + 1)
        end
    elseif miss then
        o.misses = min(40, o.misses + 1)
        if stored ~= nil then
            stored[h.candidate][2] = min(40, stored[h.candidate][2] + 1)
        end
        hypothesis.advance(h, ("body yaw %d%s iskaladi"):format(shot.hyp_yaw or 0, DEG),
            player_name(target), shot.state)
    end
end

-- Force body yaw'i oyuncu listesine yazar (yaw nil: birak). Senin kendi Force body yaw'in varsa ya da
-- "Correction active" kapaliysa dokunulmaz (NYKLE Resolver 2.5'teki sahiplik kurali).
hypothesis.apply = function(enemy, yaw)
    if yaw ~= nil then
        local user_force = plist_user(enemy, PL.FORCE)
        if plist_get(enemy, PL.CORRECTION) == false or user_force == true then
            yaw = nil
        end
    end
    if yaw == nil then
        plist_override(enemy, PL.FORCE, nil)
        plist_override(enemy, PL.VALUE, nil)
        return false
    end
    -- Once aci, sonra kutu: arada eski aci uygulanmasin.
    if not plist_override(enemy, PL.VALUE, yaw) then
        return false
    end
    return plist_override(enemy, PL.FORCE, true)
end

-- Kisi profili ornegi (saniyede bir) ve hafizadan taninan dusman icin haritada bir kez log.
resolver.observe = function(enemy)
    local key = player_id(enemy)
    if key == nil then
        return
    end
    local entry = resolver.players[key]
    local profile = enemy_watch.profile(enemy)
    -- Hafiza canli desenle dogrulanir (canli desen olculur olculmez): ayni (ya da ayni cok tarafli aile) ->
    -- dogrulandi; farkli -> tutmadi, eski desen sayilari yariya iner ki aliskanlik canli davranisa cabuk
    -- uysun. Haritada bir kez yazilir.
    if entry ~= nil and entry.remembered and entry.verified == nil and profile ~= nil and profile.pattern ~= nil then
        local habit = resolver.habit(entry)
        if habit ~= nil and habit.pattern ~= nil then
            local multi = enemy_watch.multi
            local same = habit.pattern == profile.pattern or (multi[habit.pattern] and multi[profile.pattern]) or false
            entry.verified = same
            if not same then
                for _, name in ipairs(enemy_watch.patterns) do
                    entry.profile[name] = (entry.profile[name] or 0) / 2
                end
            end
            if on(menu.resolver_log) then
                print(("[%s] resolver: %s hafiza %s: genelde %s, simdi %s%s"):format(SCRIPT,
                    entry.name or player_name(enemy), same and "dogrulandi" or "tutmadi", habit.pattern,
                    profile.pattern, same and "" or " (canli desen kullaniliyor, aliskanlik duzeltildi)"))
            end
        end
    end
    local now = realtime()
    if entry ~= nil and entry.sampled ~= nil and now >= entry.sampled and now - entry.sampled < 1 then
        return
    end
    if profile == nil then
        return
    end
    entry = entry or resolver_entry(enemy)
    if entry == nil then
        return
    end
    entry.sampled = now
    local p = entry.profile
    if p == nil then
        p = { n = 0, jitter = 0, static = 0, spin = 0, xway = 0, random = 0, def = 0, fd = 0 }
        entry.profile = p
    end
    p.n = p.n + 1
    if profile.pattern ~= nil then
        p[profile.pattern] = (p[profile.pattern] or 0) + 1
    end
    if profile.defensive then
        p.def = p.def + 1
    end
    if profile.fakeduck then
        p.fd = p.fd + 1
    end
    if p.n > 240 then
        for field, value in pairs(p) do
            p[field] = value / 2
        end
    end
    persist.dirty = true
    if entry.remembered and not entry.announced then
        entry.announced = true
        local habit = resolver.habit(entry)
        local parts = {}
        if habit ~= nil and habit.pattern ~= nil then
            parts[#parts + 1] = "genelde " .. (habit.pattern == "static" and "statik" or habit.pattern)
                .. " (dogrulanacak)"
        end
        if habit ~= nil and habit.def >= 0.2 then
            parts[#parts + 1] = ("defensive %%%d"):format(floor(habit.def * 100 + 0.5))
        end
        if habit ~= nil and habit.fd >= 0.1 then
            parts[#parts + 1] = ("fake duck %%%d"):format(floor(habit.fd * 100 + 0.5))
        end
        for slot, list in pairs(entry.angles or {}) do
            local outcomes = {}
            for c, o in ipairs(list) do
                outcomes[c] = { heads = o[1], misses = o[2] }
            end
            local best = hypothesis.known_good(outcomes)
            if best ~= nil then
                local state, pattern, wall = slot:match("^([^|]+)|(%a+)|(%a+)$")
                parts[#parts + 1] = ("%s %s%s aci %d%s"):format(state or slot, pattern or "?",
                    (wall == "side" and " duvarli") or (wall == "lby" and " lby") or "", hypothesis.yaw(best), DEG)
            end
        end
        if #parts > 0 and on(menu.resolver_log) then
            print(("[%s] resolver: %s tanindi (hafiza): %s"):format(SCRIPT, entry.name or player_name(enemy),
                table.concat(parts, ", ")))
        end
    end
end

-- Her tick butun gorunen dusmanlar icin: seviye, Force safe point (oyuncu listesi), hipotez. Hedefin
-- seviyesi "Prefer safe point" (silahin rage ayari) ve gostergeler icin dondurulur. Senin kendi safe point
-- ayarin hic dusurulmez.
local function apply_resolver(class, present)
    local target = resolver_target()
    local target_level, target_raw = 0, 0
    current.resolver, current.res_state, current.res_prior, current.hyp = 0, nil, false, nil
    for _, enemy in ipairs(enemy_list()) do
        present[enemy] = true
        local level, raw, state, prior, key, entry, misses, stalled = 0, 0, nil, false, nil, nil, 0, false
        if on(menu.resolver) then
            resolver.observe(enemy)
            raw, key, state, entry, prior, misses = resolver_level(enemy)
            level, stalled = stall_level(enemy, resolver.cap(raw, enemy), key, state, entry)
        end
        local yaw = hypothesis.update(enemy, key, state, raw, misses, stalled, entry)
        if not hypothesis.apply(enemy, yaw) then
            yaw = nil
        end
        if yaw ~= nil then
            -- Aci secildi: Force safe point o aciyi gereksiz kilar, Prefer yeter.
            level = 1
        end
        local user_sp = plist_user(enemy, PL.SAFE)
        if level >= 2 and user_sp ~= "On" then
            plist_override(enemy, PL.SAFE, "On")
        else
            plist_override(enemy, PL.SAFE, nil)
        end
        if enemy == target then
            target_level, target_raw = level, raw
            current.resolver = yaw ~= nil and 3 or level
            current.res_state, current.res_prior, current.hyp = state, prior == true, yaw
        end
    end
    -- Prefer safe point: hedefin seviyesi 1+ ise (Neverlose'daki gibi tek ayar, silahin grubunda).
    local scope = rage_scope(class)
    if target_level >= 1 and on(menu.resolver) and user_value("prefer_safe") ~= true then
        override("prefer_safe", true, scope)
    else
        override("prefer_safe", nil, scope)
    end
    return target, target_raw
end

-- Sahte kayit beklemesi: dusman defensive acinca simulasyon zamani geri gider (gordugumuz en yuksegin
-- gerisine); sunucu o zamani dusmanin ESKI konumuyla eslestirir, o kayda giden mermi (DT'nin iki mermisi
-- dahil) bosa gider. Kayit sahteyken o dusman oyuncu listesinde kisa sure "Add to whitelist" yapilir:
-- aimbot gercek kayit gelene kadar ona ates etmez, DT sarji gercek kayda kalir. Bir pencerede en fazla
-- max tick (GameSense'in defensive kaymasi kadar). Senin kendi whitelist'in hic degistirilmez.
-- V1.0.7 (oyun logu: surekli defensive acan dusmana neredeyse hic ates edilmedi, AI peek bos dondu):
--  - Duelloda beklenmez: dusman kafani goruyorsa ya da sen peek atiyorsan (Peek durumu, Quick peek tusu)
--    ates serbest, kayit secimi GameSense'in. Beklemek sadece aciyi sen tutarken (dusman seni gormezken)
--    bedava.
--  - Her beklemeden sonra (gercek kayit gelse de sinir dolsa da) cooldown tick ates serbest: surekli
--    defensive acan dusmana da duzenli sikilir.
resolver.wait = { max = 14, cooldown = 32, enemies = {}, log_every = 5 }

resolver.wait_apply = function(class, present)
    local gun = class ~= nil and not MELEE[class] and class ~= "CC4" and not is_grenade(class)
    local enabled = on(menu.resolver) and on(menu.wait_real) and gun and plist_available(PL.WHITELIST)
    local wait, now = resolver.wait, tickcount()
    local duel = current.state == "Peek" or peek_key_held()
    current.waiting = nil
    for _, enemy in ipairs(enemy_list()) do
        present[enemy] = true
        local w = wait.enemies[enemy]
        if w == nil then
            w = { ticks = 0, free_until = -1000, logged = {} }
            wait.enemies[enemy] = w
        end
        local profile = enabled and enemy_watch.profile(enemy) or nil
        local cooling = now >= w.free_until - wait.cooldown and now < w.free_until
        local hold = profile ~= nil and profile.defensive_now and not cooling and not duel
            and not sees_me(enemy) and plist_user(enemy, PL.WHITELIST) ~= true
        if hold then
            w.ticks = w.ticks + 1
            if w.ticks > wait.max then
                hold = false
            end
        end
        if hold and plist_override(enemy, PL.WHITELIST, true) then
            current.waiting = current.waiting or enemy
        else
            if w.ticks > 0 then
                w.free_until = now + wait.cooldown
            end
            if w.ticks > 0 and on(menu.resolver_log) then
                -- Iki tur ayri hiz sinirli (surekli defensive'de konsol dolmasin).
                local capped, real = w.ticks > wait.max, realtime()
                local kind = capped and "cap" or "real"
                local last = w.logged[kind] or -1000
                if real < last or real - last >= wait.log_every then
                    w.logged[kind] = real
                    print(("[%s] resolver: %s sahte kayitta (defensive): %d tick gercek kayit beklendi, %s"):format(
                        SCRIPT, player_name(enemy), min(w.ticks, wait.max),
                        capped and "sinir doldu, ates serbest" or "gercek kayit geldi"))
                end
            end
            w.ticks = 0
            plist_override(enemy, PL.WHITELIST, nil)
        end
    end
    for index in pairs(wait.enemies) do
        if not present[index] then
            wait.enemies[index] = nil
        end
    end
end

-- Sadece kafa kurali ogrenmesi (V1.0.8, oyun logu: scout gövdeyi 72 ile gorup kafa beklerken ates etmeden
-- olum): dusman seni gorurken scout "HP + 1" ile sadece oldurecek yere ates eder. Bir dusman seni sen bu
-- kuralla ates etmeden beklerken oldurduyse bu haritada ona karsi kural gevser (aimbot senin Min. damage'inle
-- govdeye de sikar); haritada 2 boyle olumde herkese karsi gevser. Yeni haritada sifirlanir.
resolver.held = { total = 0, enemies = {} }

resolver.head_relaxed = function(target)
    local held = resolver.held
    if held.total >= 2 then
        return true
    end
    local key = target ~= nil and player_id(target) or nil
    return key ~= nil and held.enemies[key] ~= nil
end

resolver.held_death = function(attacker)
    local key = player_id(attacker)
    if key == nil then
        return
    end
    local held = resolver.held
    held.enemies[key] = (held.enemies[key] or 0) + 1
    held.total = held.total + 1
    if on(menu.resolver_log) then
        -- Senin Min. damage'in zaten 100+ ise gevseme bir sey degistirmez (aimbot yine sadece oldurecek yere).
        local user_md = user_value("min_damage")
        local note = (finite(user_md) and user_md >= 100)
            and (" (ama senin Min. damage'in %d: govde yine atilmaz)"):format(user_md) or ""
        print(("[%s] ogrenildi: %s seni sen kafa beklerken (sniper, ates etmeden) oldurdu -> bu haritada %s govde de atilacak%s"):format(
            SCRIPT, player_name(attacker), held.total >= 2 and "herkese karsi" or "ona karsi", note))
    end
end

-- HvH silahlari: { hasar, zirh orani, menzil carpani, tek atis } (CS:GO silah dosyalari).
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
        return dt_on() and charge.value >= 1
    end

    -- Once gercek hasar: gozumuzden hedefin gogsune mermi izi (duvar, mesafe, zirh dahil). Iz atilamazsa
    -- silah degerleri ve mesafeyle hesaplanir. Dusman basina 4 tick onbellek (hedef 2 tick).
    local chest_cache = {}
    local function chest_damage(lp, target, info, is_target)
        local tick = tickcount()
        local cached = chest_cache[target]
        if cached ~= nil and cached.info == info and tick >= cached.tick and tick - cached.tick < (is_target and 2 or 4) then
            return cached.value
        end
        local value
        local eye, chest = eye_of(lp), hitbox_of(target, 5)
        if eye ~= nil and chest ~= nil then
            value = bullet_damage(lp, eye, chest, target)
        end
        if value == nil then
            value = info[1]
            local mine, theirs = origin_of(lp), origin_of(target)
            if mine ~= nil and theirs ~= nil then
                local dx, dy, dz = theirs.x - mine.x, theirs.y - mine.y, theirs.z - mine.z
                value = value * info[3] ^ (sqrt(dx * dx + dy * dy + dz * dz) / 500)
            end
            local armor = prop(target, "m_ArmorValue")
            if not finite(armor) or armor > 0 then
                value = value * info[2] / 2
            end
        end
        chest_cache[target] = { tick = tick, value = value, info = info }
        return value
    end

    -- "Force" govde ates engelleyebilir: dusman seni goruyorken K.FORCE_STALL sn o hedefe ates edilmediyse
    -- "Prefer"e inilir; o hedefe bir atis gelince yeniden "Force" denenir.
    local function body_stall(target)
        local stall = resolver.body_stalls[target]
        local key = player_id(target)
        if stall == nil or stall.key ~= key then
            stall = { key = key, visible = 0, last = nil, relaxed = false }
            resolver.body_stalls[target] = stall
        end
        local now = realtime()
        if stall.last ~= nil and (exposure.now or exposure.any) and not stall.relaxed then
            stall.visible = stall.visible + max(0, min(0.1, now - stall.last))
            if stall.visible >= K.FORCE_STALL then
                stall.relaxed = true
            end
        end
        stall.last = now
        return stall.relaxed and "Prefer" or "Force"
    end

    -- Bir dusman icin Body Aim karari (Neverlose V1.0 kurallari). Donus: istenen ("Prefer" / "Force" /
    -- "Default" / nil), oldurucu mu, takilma izleniyor mu.
    local function decide(lp, class, enemy, level, is_target, sniper_rule)
        local wanted, lethal, stalled = nil, false, false
        local info = WEAPONS[class]
        local health = prop(enemy, "m_iHealth")
        if sniper_rule then
            wanted = "Prefer"
            lethal = finite(health) and health > 0 and health <= chest_damage(lp, enemy, info, is_target)
            local since = realtime() - resolver.aim_time
            if lethal and enemy == resolver.aim_target and since >= 0 and since <= K.AIM_TARGET_HOLD then
                wanted, stalled = body_stall(enemy), true
            end
            return wanted, lethal, stalled
        end
        if info ~= nil and finite(health) and health > 0 then
            local chest = chest_damage(lp, enemy, info, is_target)
            if health <= chest then
                wanted, lethal, stalled = body_stall(enemy), true, true
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
        local profile = enemy_watch.profile(enemy)
        -- Sahte kayit, fake duck ya da LC kirma (GameSense yerini tahmin eder): genis govde hatayi tolere eder.
        if wanted == nil and gun and not (info ~= nil and info[4]) and profile ~= nil
            and (profile.defensive_now or profile.fakeduck or profile.lc) then
            wanted = "Prefer"
        end
        return wanted, lethal, stalled
    end

    local PLIST_BODY_VALUE = { Prefer = "On", Force = "Force", Default = "Off" }
    local HP_PLUS_ONE = 101
    -- Bicak / zeus tutan dusman bu kadar yakinken (V1.0.14): oldurmese de vurulur, Min. damage en fazla 30.
    -- Oyun logunda ilk atis (bacak -37 / mide -51) ikinci govde atisini (75+) oldurucu yapti; yuksek tutmak
    -- ilk atisi geciktirir. Log yaklasma basina bir kez (V1.0.15: yakinda durdukca 5 sn'de bir yaziyordu).
    local KNIFE_MD = { dist = 320, value = 30, who = nil, seen = -1000 }

    apply_body_aim = function(lp, class, target, level, present)
        local exposed = not exposure.available or exposure.now or exposure.soon or exposure.any
        local info = WEAPONS[class]
        local sniper_rule = on(menu.head_only) and info ~= nil and info[4] and exposed
            and not resolver.head_relaxed(target)
        -- Senin baim tusun (Force body aim) basiliyken oyuncu ayarlarina dokunulmaz.
        local user_force = get("force_body") == true
        local target_lethal, target_wanted = false, nil

        -- Sahte kayda kafa atisi yok (sniper): hedefin kaydi defensive'de ve govde olduruyorsa o hedefe
        -- "Force" body aim (Neverlose'da gogus + mide hitbox'lari). En fazla 12 tick, sonra 0.5 sn serbest.
        local f = resolver.fake
        local now = realtime()
        if target ~= f.index then
            f.index, f.ticks = target, 0
        end
        local fake_body = false
        local mine = on(menu.knife_md) and origin_of(lp) or nil
        local melee_near = nil

        for _, enemy in ipairs(enemy_list()) do
            present[enemy] = true
            if mine ~= nil and melee_near == nil and MELEE[weapon_class(enemy)] then
                local pos = origin_of(enemy)
                if pos ~= nil then
                    local dx, dy, dz = pos.x - mine.x, pos.y - mine.y, pos.z - mine.z
                    if dx * dx + dy * dy + dz * dz < KNIFE_MD.dist * KNIFE_MD.dist then
                        melee_near = enemy
                    end
                end
            end
            local wanted, lethal, stalled = nil, false, false
            if on(menu.smart_baim) then
                -- Seviye 2 kurali her dusmanin kendi seviyesiyle (oyuncu basina karar).
                local enemy_level = enemy == target and level or 0
                if enemy ~= target and on(menu.resolver) then
                    local key = player_id(enemy)
                    local entry = key ~= nil and resolver.players[key] or nil
                    enemy_level = entry ~= nil and entry_level(entry, enemy_state(enemy)) or 0
                end
                wanted, lethal, stalled = decide(lp, class, enemy, enemy_level, enemy == target, sniper_rule)
            end
            if not stalled then
                resolver.body_stalls[enemy] = nil
            end
            if enemy == target then
                target_lethal, target_wanted = lethal, wanted
                local profile = enemy_watch.profile(enemy)
                local cooling = now >= f.free_until - f.cooldown and now < f.free_until
                local body_only = sniper_rule and profile ~= nil and profile.defensive_now and lethal
                    and on(menu.fake_body) and not cooling
                if body_only then
                    f.ticks = f.ticks + 1
                    if f.ticks > f.max then
                        f.free_until, body_only = now + f.cooldown, false
                    end
                end
                if not body_only then
                    f.ticks = 0
                end
                if body_only then
                    fake_body, wanted = true, "Force"
                    if on(menu.resolver_log) and (now < f.logged or now - f.logged > 5) then
                        f.logged = now
                        print(("[%s] resolver: %s sahte kayitta (defensive): sniper oldurecek govdeye, kafa gercek kayda"):format(
                            SCRIPT, player_name(enemy)))
                    end
                end
            end
            local user_plist = plist_user(enemy, PL.BODY)
            local value = wanted ~= nil and PLIST_BODY_VALUE[wanted] or nil
            if user_force or (user_plist ~= nil and user_plist ~= "-") or value == nil then
                plist_override(enemy, PL.BODY, nil)
            else
                plist_override(enemy, PL.BODY, value)
            end
        end
        current.fake_body = fake_body
        if sniper_rule then
            current.lethal = target_lethal
        else
            current.lethal = target_wanted == "Prefer" or target_wanted == "Force"
        end

        -- Kafa ya da oldurucu atis: tek atisli silahta Min. damage "HP + 1" (GameSense'te 101), aimbot sadece
        -- oldurecek yere ates eder. Senin daha yuksek minimum hasarin ve Minimum damage override tusun
        -- dusurulmez (tek istisna asagida: yakindaki bicak / zeus). Sadece elindeki silahin grubu seciliyken
        -- yazilir.
        local scope = rage_scope(class)
        local min_damage = nil
        local user_md = user_value("min_damage")
        local md_override = get("md_override") == true and get("md_override_key") == true
        if sniper_rule then
            min_damage = HP_PLUS_ONE
            if (finite(user_md) and user_md >= min_damage) or md_override then
                min_damage = nil
            end
        end
        -- Bicak / zeus tutan dusman yakin: senin yuksek Min. damage'in da gecici en fazla 30'a iner (override
        -- tusun basiliysa onun degeri kalir). Bicakla gelen 1 sn icinde olduruyor; 30 + govde 75 = olu.
        local knife_md = melee_near ~= nil and class ~= nil and not MELEE[class] and class ~= "CC4" and not is_grenade(class)
            and not md_override
        if knife_md then
            min_damage = (finite(user_md) and user_md > KNIFE_MD.value) and KNIFE_MD.value or nil
            local fresh = KNIFE_MD.who ~= melee_near or now < KNIFE_MD.seen or now - KNIFE_MD.seen > 2
            KNIFE_MD.who, KNIFE_MD.seen = melee_near, now
            if min_damage ~= nil and on(menu.hit_log) and fresh then
                print(("[%s] %s bicak/zeus ile yakinda: Min. damage gecici %d (oldurmese de vur)"):format(
                    SCRIPT, player_name(melee_near), KNIFE_MD.value))
            end
        end
        current.head_only = min_damage ~= nil and scope ~= nil and not knife_md
        override("min_damage", min_damage, scope)
    end
end

local function update_flip(s, exploit, choked)
    -- Bir onceki paket gonderildiyse yeni bir choke dongusu basliyor demektir.
    if choked ~= 0 then
        return
    end
    flip.packets = flip.packets + 1
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
    local spread = s.delay_random:get() or 0
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

local function clamp(x, low, high)
    return max(low, min(high, x))
end

local PITCHES = { Down = "Down", Minimal = "Minimal", Off = "Off" }
local NATIVE_MODIFIERS = { Center = true, Offset = true, Random = true, Skitter = true }

-- GameSense'te desync miktari ayri bir ayar degil: Body yaw "Static" degeri ~2 x desync (luasense
-- formulu: 60 derece desync = 120+), en buyuk 180. Tam desync (58+) icin 180 yazilir.
local function body_amount(limit)
    if limit >= 58 then
        return 180
    end
    return clamp(round(limit * 2), 0, 180)
end

-- Kendi body yaw pose parametremizden gercek taraf (body freestanding'de tarafi GameSense secer).
local function pose_side(lp)
    local pose = prop(lp, "m_flPoseParameter", 11)
    if finite(pose) then
        return pose * 120 - 60 > 0
    end
    return nil
end

-- AA'yi GameSense ayarlarina yazar. side true = sag (GameSense'te negatif body yaw; luasense'in
-- eslesmesi: negatif body yaw <-> sag yaw). hidden_pitch / hidden_yaw: defensive penceresinde gonderilen
-- sahte acilar (nil: yok).
local function apply(v, lp)
    override("aa_enabled", true)
    if v.hidden_pitch ~= nil and refs.pitch_value ~= nil then
        override("pitch", "Custom")
        override("pitch_value", clamp(round(v.hidden_pitch), -89, 89))
    else
        override("pitch", PITCHES[v.pitch] or "Down")
        override("pitch_value", nil)
    end
    override("yaw_base", v.yaw_base == "Local View" and "Local view" or "At targets")
    override("yaw", "180")
    local yaw = v.yaw_offset
    if v.hidden_yaw ~= nil then
        yaw = yaw + v.hidden_yaw
    end
    override("yaw_offset", normalize_yaw(round(yaw)))
    if NATIVE_MODIFIERS[v.modifier] then
        override("yaw_jitter", v.modifier)
        override("jitter_offset", clamp(round(v.mod_offset), -180, 180))
    else
        override("yaw_jitter", "Off")
    end
    local side = v.side
    if v.body == "Off" then
        override("body_yaw", "Off")
    else
        local limit = side and v.right or v.left
        override("body_yaw", "Static")
        override("body_value", side and -body_amount(limit) or body_amount(limit))
    end
    local body_fs = v.body == "Static" and v.body_fs == "On"
    override("body_fs", body_fs)
    if body_fs and lp ~= nil then
        local actual = pose_side(lp)
        if actual ~= nil then
            side = actual
        end
    end
    override("freestanding", v.freestand == true)
    if v.freestand then
        override("freestanding_key", ALWAYS_ON)
    else
        override("freestanding_key", nil)
    end
    override("edge_yaw", false)

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

-- Bicak / zeus / bomba ile exploit degismez, son silahinki korunur.
local NON_GUNS = { CKnife = true, CKnifeGG = true, CWeaponTaser = true, CC4 = true }
local exploit_memory = { choice = nil }

-- Safe recharge (GameSense'te sarji bekletme API'si yok): DT sarj olurken oyuncu sunucuda ~14 tick yerinde
-- donar. Biri kafani goruyorken (ya da birazdan gorecekken) ve atistan / fake duck'tan sonra en fazla
-- K.RECHARGE_HOLD_MAX sn, DT kisa sure kapatilir: sarj baslamaz; siperin arkasina gecince DT acilir ve
-- dolar. Sadece DT'de (GameSense'te HS sarji olculemiyor).
local own = { last_shot = -1000, round = nil }
local recharge = { held = false, fakeduck = false, released = -1000 }

-- Sniper mermisiyle fake duck birakildi (V1.0.14): o sniper'in ikinci mermisi en erken 1.25 sn sonra.
-- Sarj beklemeden hemen dolarsa DT ve defensive o mermiden once geri gelir (V1.0.12 logu: birakildiktan
-- 1 sn sonra DT %10 iken ikinci mermiyle olum).
recharge.after_hit = function(now)
    local h = own.fd_hit
    return h ~= nil and on(menu.fd_hit) and now >= h.time and now - h.time <= 3
end

recharge.decide = function(wants_dt)
    local fakeduck = fd_on()
    if recharge.fakeduck and not fakeduck then
        recharge.released = realtime()
    end
    recharge.fakeduck = fakeduck
    local hold = false
    if wants_dt and on(menu.safe_recharge) and exposure.available and not fakeduck
        and not recharge.after_hit(realtime()) then
        local since = realtime() - max(own.last_shot, recharge.released)
        -- Tutulurken DT kapali, tahmini sarj 0: sinir yine 1.2 sn.
        hold = charge.value < 1 and since >= 0 and since <= K.RECHARGE_HOLD_MAX and seen_by_enemy()
    end
    recharge.held = hold
    return hold
end

-- Durumun exploit secimi.
-- Fake duck: DT ve HS fake duck'la birlikte calismaz. DT acikken GameSense fake lag'i "Double tap fake lag
-- limit"e ceker, fake duck'in 14 tick choke'u bozulur; DT fake duck sirasinda sarj olmaya calisir ve atis
-- sunucuyla farkli egilme / isabet hesabiyla gider ("spread" iskasi, kafa acikta). Auto exploit acikken
-- fake duck boyunca ikisi de kapatilir (eskiden senin bind'lerine birakiliyordu); birakinca durumun
-- exploit'i doner.
local function apply_exploit(s, class)
    if fd_on() and on(menu.auto_exploit) then
        recharge.decide(false)
        override("doubletap", false)
        override("doubletap_key", nil)
        override("hideshots", false)
        override("hideshots_key", nil)
        return
    end
    local choice = s ~= nil and s.exploit ~= nil and s.exploit:get() or "Binds"
    if not on(menu.auto_exploit) then
        choice = "Binds"
    end
    if choice ~= "Binds" then
        local holding_gun = class ~= nil and not NON_GUNS[class] and not is_grenade(class)
        local sniper_setting = menu.sniper_exploit:get()
        local sniper_hs = SNIPERS[class] and (sniper_setting == "Hide shots" or (sniper_setting == "Auto (learn)" and sniper.choice == "hs"))
        -- Auto: sunucunun reddettigi exploit birakilir (bkz. sniper.reject).
        if SNIPERS[class] and sniper_setting == "Auto (learn)" then
            if sniper.avoided("hs") and not sniper.avoided("dt") then
                sniper_hs = false
            elseif sniper.avoided("dt") and not sniper.avoided("hs") then
                sniper_hs = true
            end
        end
        if sniper_hs and on(menu.sniper_air_dt) and (current.state == "Air" or current.state == "Air crouch") then
            sniper_hs = false
        end
        if sniper_hs then
            choice = "Hide shots"
        elseif not holding_gun and exploit_memory.choice ~= nil then
            choice = exploit_memory.choice
        end
        if holding_gun then
            exploit_memory.choice = choice
        end
    end
    local user_dt = choice == "Binds" and user_value("doubletap") == true and get("doubletap_key")
    local hold = recharge.decide(choice == "Double tap" or user_dt)
    if choice == "Double tap" then
        override("doubletap", not hold)
        override("doubletap_key", ALWAYS_ON)
        override("hideshots", false)
        override("hideshots_key", nil)
    elseif choice == "Hide shots" then
        override("doubletap", false)
        override("doubletap_key", nil)
        override("hideshots", true)
        override("hideshots_key", ALWAYS_ON)
    else
        if hold then
            override("doubletap", false)
        else
            override("doubletap", nil)
        end
        override("doubletap_key", nil)
        override("hideshots", nil)
        override("hideshots_key", nil)
    end
end

-- Temiz atis (V1.0): silah ates edebiliyorken ve hedefe gozumuzden Min. damage'i gecen mermi gidiyorsa
-- kendi lag'imiz durur (Break LC, zorlanan defensive, hidden acilar, havada teleport). Acilinca 6 tick acik
-- kalir; aimbot ates edince 14 tick (DT'nin ikinci mermisi ve hemen arkasindaki atis lag'e denk gelmesin).
-- Ani peek icin: biri seni goruyorken (ya da birazdan gorecekken) iz her tick atilir (yoksa 2 tick'te bir),
-- kafa / gogus / mide / ust gogus / kalca / uyluklara bakilir ve hareket ediyorsan 0.1 sn sonraki gozden de
-- (kafa, gogus, mide): defensive atistan once kesilir, atis anina denk gelmez.
local clean_shot = { every = 2, hold = 6, fire_hold = 14, checked = -1000, index = nil, until_tick = -1000,
    from_tick = -1000, boxes = { 0, 5, 3, 6, 2, 7, 8 }, ahead = 0.1, ahead_boxes = 3, ahead_speed = 50 }

-- Aimbot'un su an kullandigi Min. damage (override tusu basiliysa override degeri).
local function active_min_damage()
    if get("md_override") == true and get("md_override_key") == true and refs.md_override_value ~= nil then
        local v = get("md_override_value")
        if finite(v) then
            return v
        end
    end
    local md = get("min_damage")
    return finite(md) and md or 0
end

-- Aimbot'un ates etmesi icin gereken hasar: Min. damage; 100 ustu can + fark (101 = can + 1).
clean_shot.need = function(target)
    local md = active_min_damage()
    if md > 100 then
        local hp = prop(target, "m_iHealth")
        return (finite(hp) and hp or 100) + md - 100
    end
    return max(1, md)
end

clean_shot.shootable = function(lp, target)
    if not trace_available or dormant(target) then
        return false
    end
    local eye = eye_of(lp)
    if eye == nil then
        return false
    end
    local need = clean_shot.need(target)
    local eyes = { eye }
    local vel = velocity_of(lp)
    if vel.x * vel.x + vel.y * vel.y > clean_shot.ahead_speed * clean_shot.ahead_speed then
        eyes[2] = vector(eye.x + vel.x * clean_shot.ahead, eye.y + vel.y * clean_shot.ahead, eye.z)
    end
    for n, from in ipairs(eyes) do
        for b, hitbox in ipairs(clean_shot.boxes) do
            local point = (n == 1 or b <= clean_shot.ahead_boxes) and hitbox_of(target, hitbox) or nil
            if point ~= nil then
                local points = { point }
                if hitbox == 0 then
                    for _, side in ipairs(side_points(point, from, exposure.edge)) do
                        points[#points + 1] = side
                    end
                end
                for _, p in ipairs(points) do
                    local damage = bullet_damage(lp, from, p, target)
                    if damage ~= nil and damage >= need then
                        return true
                    end
                end
            end
        end
    end
    return false
end

-- Aimbot ates etti (aim_fire): o hedefe fire_hold tick temiz atis.
clean_shot.fired = function(target)
    local tick = tickcount()
    clean_shot.index, clean_shot.checked = target, tick
    clean_shot.from_tick, clean_shot.until_tick = tick, max(clean_shot.until_tick, tick + clean_shot.fire_hold)
end

clean_shot.update = function(lp, target, armed)
    local tick = tickcount()
    if not on(menu.clean_shot) or not armed or target == nil then
        clean_shot.until_tick = -1000
        return false
    end
    -- Ayna defensive (V1.0.9): hedef sahte kayittayken (defensive) atis buyuk ihtimalle gecmez (oyun logu:
    -- sahte kayda giden 3 atistan 2'si iska). O sirada temiz atis yok: kendi defensive'in acik kalir, onun
    -- mermisi de senin sahte kaydina gider. Gercek kaydi gelince temiz atis doner.
    local profile = enemy_watch.profile(target)
    if profile ~= nil and profile.defensive_now then
        clean_shot.until_tick = -1000
        return false
    end
    local index = target
    local every = (exposure.now or exposure.soon or exposure.any) and 1 or clean_shot.every
    if index ~= clean_shot.index or tick < clean_shot.checked or tick - clean_shot.checked >= every then
        if index ~= clean_shot.index then
            clean_shot.until_tick = -1000
        end
        clean_shot.index, clean_shot.checked = index, tick
        if clean_shot.shootable(lp, target) then
            if not (tick <= clean_shot.until_tick and tick >= clean_shot.from_tick) then
                clean_shot.from_tick = tick
            end
            clean_shot.until_tick = max(clean_shot.until_tick, tick + clean_shot.hold)
        end
    end
    return tick <= clean_shot.until_tick and tick >= clean_shot.from_tick
end

-- cmd / pmax / pdiff / ptick: predict_command olcumu (asagida).
local tickbase = { max = 0, left = 0, sent = nil, since_sent = 0, jump = false, cmd = nil, pmax = 0, pdiff = 0,
    ptick = -1000 }

-- Defensive penceresi iki yoldan anlasilir: tickbase gordugumuz en yuksek degerin gerisine kaydirildiysa;
-- ya da DT doluyken iki paket arasinda tickbase geri gittiyse veya aradaki komut sayisindan fazla ileri
-- sicradiysa.
local function update_tickbase(lp, choked)
    local tb = prop(lp, "m_nTickBase")
    if not finite(tb) then
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
        tickbase.left = min(14, max(0, tickbase.max - tb))
    end
    tickbase.since_sent = tickbase.since_sent + 1
    local c = dt_charge()
    if c ~= nil and c < 1 then
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

-- V1.0.12: GameSense'te defensive'i gosteren olcum (luasense ve hysteria'nin yontemi): run_command'in komutu
-- tahmin edilince (predict_command; eski komutlarin yeniden tahmini sayilmaz) tickbase gordugumuz en yuksek
-- degerin 3-14 tick gerisindeyse defensive acik. setup_command'daki olcum gercek oyunda defensive'i hic
-- gormedi (V1.0.10-1.0.11 loglarinda hic "DEF acik" yok); hidden pitch / yaw o yuzden hic uygulanmiyordu.
listen("run_command", protect("tickbase", function(cmd)
    tickbase.cmd = cmd.command_number
end))

listen("predict_command", protect("tickbase", function(cmd)
    if cmd.command_number == nil or cmd.command_number ~= tickbase.cmd then
        return
    end
    local tb = prop(local_player(), "m_nTickBase")
    if not finite(tb) then
        return
    end
    if abs(tb - tickbase.pmax) > 64 then
        tickbase.pmax = tb
    end
    tickbase.pdiff = tickbase.pmax - tb
    tickbase.pmax = max(tickbase.pmax, tb)
    tickbase.ptick = tickcount()
end))

-- predict_command son 2 tick icinde defensive gorduyse.
tickbase.predicted = function()
    local tick = tickcount()
    return tick >= tickbase.ptick and tick - tickbase.ptick <= 2 and tickbase.pdiff >= 3 and tickbase.pdiff <= 14
end

-- Fake duck'ta DT / HS kapali: defensive olamaz (V1.0.10 logunda fake duck'ta bir kez yanlis "DEF acik").
local function defensive_active()
    if fd_on() then
        return false
    end
    return tickbase.left > 0 or tickbase.jump or tickbase.predicted()
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
        if mode == "Spin" then return normalize_yaw(tickcount() * menu.hidden_spin:get() * 3) end
        if mode == "Random" then return random(-180, 180) end
        if mode == "Forward" then return 180 end
        if mode == "Custom" then return s.hidden_yaw_value:get() end
        return nil
    end

    -- HS icin "On peek" emulasyonu: Break LC acildiktan sonra bu kadar tick acik kalir.
    local HS_LC_HOLD = 32
    local hs_lc = { until_tick = -1000 }

    -- "Smart" + DT: biri kafani gordugu (ya da 0.2 sn icinde gorecegi) surece ve gorus kesildikten sonra
    -- SMART_HOLD tick daha defensive zorlanir.
    local SMART_HOLD = 8
    local smart = { last = -1000 }

    local function smart_window(now)
        if seen_by_enemy() then
            smart.last = now
        end
        return now >= smart.last and now - smart.last <= SMART_HOLD
    end

    -- "Defensive vs enemy peeks": "On peek" durumlarinda bir dusman sana dogru peek atarken DT defensive'i
    -- zorlanir ve ANTI_HOLD tick daha surer. Kafani gorurken peek atiyorsa sadece silahin ates edemiyorken.
    local ANTI_HOLD = 16
    local anti = { last = -1000 }

    local function anti_window(now, armed)
        if exposure.peeked or (exposure.enemy_peek and not armed) then
            anti.last = now
        end
        return now >= anti.last and now - anti.last <= ANTI_HOLD
    end

    -- GameSense: defensive cmd.force_defensive ile zorlanir (Neverlose'daki Lag Options / HS "Break LC" yerine).
    -- "On peek": GameSense'in kendi davranisi (zorlama yok) + Smart / anti-peek / AI peek zorlamalari.
    -- Hidden acilar: defensive penceresi tickbase'den gorulurken pitch / yaw menu ayarina yazilir.
    -- Donus: hidden pitch, hidden yaw (o tick yoksa nil).
    apply_defensive = function(cmd, s, class, state, moving, armed, clean)
        local dt, hs = dt_on(), hs_on()
        local mode = s ~= nil and s.def_mode ~= nil and s.def_mode:get() or "Off"
        if not (dt or hs) or mode == "Off" or is_grenade(class) or fd_on() then
            return nil, nil
        end
        local now = tickcount()
        local paused = resolver.paused
        local lc_ok = not paused("LC")
        local on_peek = mode == "On peek" or mode == "Smart"
        if on_peek and hs and (state == "Peek" or moving or seen_by_enemy() or exposure.peeking ~= nil) then
            hs_lc.until_tick = now + HS_LC_HOLD
        end
        local hs_peek = on_peek and hs and lc_ok and not clean and now <= hs_lc.until_tick
            and now >= hs_lc.until_tick - HS_LC_HOLD
        local airborne = state == "Air" or state == "Air crouch"
        local window = mode == "Smart" and (smart_window(now) or (airborne and on(menu.air_lag)))
        local guard = mode == "On peek" and on(menu.anti_peek) and anti_window(now, armed ~= false)
        local peeking = on_peek and exposure.peeking ~= nil and on(menu.peek_defensive)
        local forced = (window or guard or peeking) and dt and exploit_active() and not paused("DEF") and not clean
        current.defensive = (not on_peek and not clean) or hs_peek or forced
        current.forced = forced
        current.anti = forced and guard

        -- Break LC sadece DT kapaliyken gecerli (DT, HS'den once gelir).
        local break_lc = on_peek and hs_peek or (not on_peek and hs and lc_ok and not clean)
        current.lc = break_lc and not dt
        local force
        if on_peek then
            force = forced or current.lc
        elseif mode == "Always on" then
            force = not clean and (dt or current.lc)
        else
            local ticks = s.def_ticks:get() or 14
            local number = cmd.command_number or now
            force = not clean and number % ticks == 0
        end
        if force then
            pcall(function() cmd.force_defensive = true end)
        end

        if clean or not current.defensive or not defensive_active() then
            return nil, nil
        end
        return hidden_pitch_value(s), hidden_yaw_value(s)
    end
end

-- Sen ates etmezken (atistan sonraki 1 sn haric) durum basina DT dolu orani ve defensive penceresi orani.
local function sample_exploit(state)
    local dt, hs = dt_on(), hs_on()
    if not (dt or hs) then
        return
    end
    local since = realtime() - own.last_shot
    if since >= 0 and since <= K.DT_SHOT_GRACE then
        return
    end
    local entry = stat_for(state)
    if recharge.held then
        return
    end
    if dt then
        entry.dt_ticks = entry.dt_ticks + 1
        if charge.value < 1 then
            return
        end
        entry.dt_full = entry.dt_full + 1
    end
    entry.def_ticks = entry.def_ticks + 1
    if defensive_active() then
        entry.def_on = entry.def_on + 1
    end
end

-- Fake duck korumasi: bicak ya da zeus tutan canli bir dusman KNIFE_NEAR birimden yakinsa fake duck
-- birakilir (GameSense'te fake duck sadece tus: tus gecici olarak bosaltilir); KNIFE_FAR'dan uzaklasinca
-- ya da silah degistirince tusun yine senin.
local update_fd_guard
do
    local KNIFE_NEAR, KNIFE_FAR = 260, 360
    -- Zeus ~180 birimden oldurur ve tutan kosarak gelir: daha erken (V1.0.8, oyun logu: 178 birimde
    -- birakildi, hemen zeus'landin).
    local ZEUS_NEAR, ZEUS_FAR = 420, 520
    local FD_MOVE, FD_STOP, FD_GRACE = 40, 10, 10
    -- Sniper mermisinden sonra: en az FD_HIT_MIN sn, saldiran seni gordukce en fazla FD_HIT_MAX sn.
    local FD_HIT_MIN, FD_HIT_MAX, FD_HIT_SIGHT = 1.25, 3, 32
    local fd = { why = nil, logged = -1000, moving = 0 }

    -- own.fd_hit (player_hurt'te yazilir) hala gecerli mi.
    local function hit_release()
        local h = own.fd_hit
        if h == nil or not on(menu.fd_hit) then
            return false
        end
        local now = realtime()
        if now < h.time or now - h.time > FD_HIT_MAX then
            own.fd_hit = nil
            return false
        end
        if now - h.time < FD_HIT_MIN then
            return true
        end
        local s, tick = exposure.sight[h.attacker], tickcount()
        if alive(h.attacker) and s ~= nil and tick >= s.last and tick - s.last <= FD_HIT_SIGHT then
            return true
        end
        own.fd_hit = nil
        return false
    end

    local function fd_pointless(lp)
        if not on(menu.fd_still) then
            return false
        end
        if not on_ground(lp) then
            return true
        end
        local speed = speed2d(lp)
        if fd.why == "move" then
            return speed > FD_STOP
        end
        fd.moving = speed > FD_MOVE and fd.moving + 1 or 0
        return fd.moving >= FD_GRACE
    end

    local function knife_enemy(lp, radius)
        local mine = origin_of(lp)
        if mine == nil then
            return nil
        end
        local best, best_dist = nil, huge
        for _, enemy in ipairs(enemy_list()) do
            local class = weapon_class(enemy)
            if MELEE[class] then
                local pos = origin_of(enemy)
                if pos ~= nil then
                    local dx, dy, dz = pos.x - mine.x, pos.y - mine.y, pos.z - mine.z
                    local dist = sqrt(dx * dx + dy * dy + dz * dz)
                    local limit = class == "CWeaponTaser" and (radius == KNIFE_NEAR and ZEUS_NEAR or ZEUS_FAR) or radius
                    if dist < limit and dist < best_dist then
                        best, best_dist = enemy, dist
                    end
                end
            end
        end
        return best, best ~= nil and best_dist or nil
    end

    update_fd_guard = function(lp)
        local pointless = fd_pointless(lp)
        if is_overridden("fakeduck") then
            if fd.why == "move" then
                if not pointless then
                    override("fakeduck", nil)
                    fd.why = nil
                end
            elseif fd.why == "hit" then
                if not hit_release() then
                    override("fakeduck", nil)
                    fd.why = nil
                end
            elseif not on(menu.fd_guard) or knife_enemy(lp, KNIFE_FAR) == nil then
                override("fakeduck", nil)
                fd.why = nil
            end
            return
        end
        fd.why = nil
        if not get("fakeduck") then
            return
        end
        if pointless then
            override("fakeduck", NEVER)
            if is_overridden("fakeduck") then
                fd.why = "move"
                local now = realtime()
                if on(menu.hit_log) and (now < fd.logged or now - fd.logged > 10) then
                    fd.logged = now
                    print(("[%s] fake duck birakildi: %s (fake duck DT/HS'yi kapatir; yerinde dururken calisir)"):format(
                        SCRIPT, on_ground(lp) and "hareket ediyorsun" or "havadasin"))
                end
            end
            return
        end
        if hit_release() then
            override("fakeduck", NEVER)
            if is_overridden("fakeduck") then
                fd.why = "hit"
                if on(menu.hit_log) then
                    print(("[%s] fake duck birakildi: %s sniper ile vurdu (fake duck'ta DT / defensive yok; o seni gordukce en fazla %d sn)"):format(
                        SCRIPT, own.fd_hit.name or "?", FD_HIT_MAX))
                end
            end
            return
        end
        if not on(menu.fd_guard) then
            return
        end
        local enemy, dist = knife_enemy(lp, KNIFE_NEAR)
        if enemy ~= nil then
            override("fakeduck", NEVER)
            if is_overridden("fakeduck") then
                fd.why = "knife"
                if on(menu.hit_log) then
                    print(("[%s] fake duck birakildi: %s bicak/zeus ile %d birim yakinda"):format(
                        SCRIPT, player_name(enemy), round(dist)))
                end
            end
        end
    end
end

-- Komutun bakis yonu (GameSense setup_command'da cmd.yaw, AA'dan once).
local function view_yaw(cmd)
    local ok, view = pcall(function() return cmd.yaw end)
    if ok and finite(view) then
        return view
    end
    local _, yaw = try(client.camera_angles)
    return finite(yaw) and yaw or nil
end

local function yaw_to(from, to)
    return math.deg(atan2(to.y - from.y, to.x - from.x))
end

-- AA hedefi. GameSense'in "At targets"i tehdide bakar. Tehdit yoksa en yakin dusmana, tehdit seni
-- gormuyor ama yandan biri goruyorsa ona gore donulur: "Local view" + o dusmanin yonu.
local function face_target(cmd, lp, yaw_base, yaw_offset, freestand)
    local threat = current_threat()
    exposure.facing = threat
    if yaw_base ~= "At Target" or freestand then
        return yaw_base, yaw_offset
    end
    local target
    local peeking = exposure.peeking ~= nil and alive(exposure.peeking) and exposure.peeking or nil
    if peeking ~= nil and peeking ~= threat then
        target = peeking
    elseif peeking ~= nil and threat ~= nil and peeking == threat then
        return yaw_base, yaw_offset
    else
        local duel = duel_target()
        if duel ~= nil and threat ~= nil and duel == threat then
            duel = nil
        end
        target = duel or recent_shooter() or seeing_flanker() or (threat == nil and aa_threat() or nil)
    end
    local mine, theirs = origin_of(lp), target ~= nil and origin_of(target) or nil
    local view = view_yaw(cmd)
    if mine == nil or theirs == nil or view == nil then
        return yaw_base, yaw_offset
    end
    exposure.facing = target
    return "Local View", yaw_offset + yaw_to(mine, theirs) - view
end

-- Avoid backstab (GameSense'in AA'sinda yok; NYKLE Yaw'daki gibi): bicakli dusman 250 birimden yakin ve
-- goz goze ise yuzun ona doner.
local function backstab_target(lp)
    if not on(menu.avoid_backstab) then
        return nil
    end
    local mine, eye = origin_of(lp), eye_of(lp)
    if mine == nil or eye == nil then
        return nil
    end
    for _, enemy in ipairs(enemy_list()) do
        local class = weapon_class(enemy)
        if class == "CKnife" or class == "CKnifeGG" then
            local pos = origin_of(enemy)
            if pos ~= nil then
                local dx, dy, dz = pos.x - mine.x, pos.y - mine.y, pos.z - mine.z
                if dx * dx + dy * dy + dz * dz <= 250 * 250 then
                    local their_eye = eye_of(enemy)
                    local fraction, hit = trace_line(lp, eye, their_eye or pos)
                    if fraction ~= nil and (fraction >= 0.97 or hit == enemy) then
                        return enemy
                    end
                end
            end
        end
    end
    return nil
end


-- Havada teleport (GameSense: cmd.discharge_pending): havadayken bir dusman kafani gorurken (ya da birazdan
-- gorecekken) DT doluysa biriken tick'ler bir anda oynanir. Ziplama basina 1 kez (V1.0), inise 0.35 sn'den
-- az kaldiysa yok, yatay hiz en az 150. GameSense'te sadece DT ile (HS sarji olculemiyor).
-- V1.0.13: her teleportun sonucu tutulur (1.5 sn icinde mermi yedin mi). Bir haritada son 3 teleportun
-- 2'si vurulmayla bittiyse o harita boyunca havada teleport kapanir: sarj havada air lag'e, inince DT'ye
-- kalir (loglarda teleportlarin yarisi hemen vurulma ve %0 DT ile bitiyordu).
local teleport = { last = -1000, count = 0, min_speed = 150, max_jump = 1, land_guard = 0.35, refilled = false,
    pending = nil, watch = nil, window = 1.5, results = {}, keep = 3, limit = 2, off = false }

-- Teleportun sonucunu yazar; son 3'te 2 vurulma olunca bu harita icin kapatir.
teleport.judge = function(hit)
    teleport.watch = nil
    local results = teleport.results
    results[#results + 1] = hit
    while #results > teleport.keep do
        table.remove(results, 1)
    end
    local hits = 0
    for _, value in ipairs(results) do
        hits = hits + (value and 1 or 0)
    end
    if on(menu.hit_log) then
        print(("[%s] teleport sonucu: %s (son %d: %d vurulma)"):format(SCRIPT,
            hit and "1.5 sn icinde vuruldun" or "vurulmadin", #results, hits))
    end
    if hits >= teleport.limit and not teleport.off then
        teleport.off = true
        print(("[%s] teleport: son %d isinlanmanin %d'sinde hemen vuruldun, bu harita boyunca havada teleport kapali (sarj air lag / DT icin kalir)"):format(
            SCRIPT, #results, hits))
    end
end

-- player_hurt (dusman mermisi): teleporttan sonraki 1.5 sn icindeyse vurulma sayilir.
teleport.hurt = function(now)
    if teleport.watch ~= nil and now >= teleport.watch and now - teleport.watch <= teleport.window then
        teleport.judge(true)
    end
end

teleport.reset = function()
    teleport.watch, teleport.results, teleport.off = nil, {}, false
end

teleport.land_time = function(lp)
    local origin = origin_of(lp)
    if origin == nil then
        return huge
    end
    local vz = velocity_of(lp).z
    local fraction = trace_line(lp, origin, vector(origin.x, origin.y, origin.z - 400))
    if fraction == nil or fraction >= 1 then
        return huge
    end
    return (vz + sqrt(max(0, vz * vz + 2 * K.GRAVITY * 400 * fraction))) / K.GRAVITY
end

teleport.update = function(cmd, lp, move_state)
    local now = realtime()
    if teleport.watch ~= nil and (now < teleport.watch or now - teleport.watch > teleport.window) then
        teleport.judge(false)
    end
    -- Bir onceki tick'te tetiklendiyse sarj harcandi mi (GameSense'te dogrulama icin).
    local pending = teleport.pending
    if pending ~= nil and tickcount() > pending.tick + 1 then
        teleport.pending = nil
        if charge.value >= 0.99 and on(menu.hit_log) and not teleport.warned then
            teleport.warned = true
            print(("[%s] teleport: sarj harcanmadi (bu GameSense surumunde discharge calismiyor olabilir)"):format(SCRIPT))
        end
    end
    if move_state ~= "Air" and move_state ~= "Air crouch" then
        if teleport.count > 0 and on(menu.hit_log) then
            print(("[%s] teleport: bu ziplamada %d kez%s"):format(SCRIPT, teleport.count,
                teleport.refilled and "" or " (sarj havada tekrar dolmadi)"))
        end
        teleport.count, teleport.refilled = 0, false
        return
    end
    if teleport.count > 0 and charge.value >= 1 then
        teleport.refilled = true
    end
    if teleport.count >= teleport.max_jump or teleport.off or not on(menu.air_teleport) or resolver.paused("TP")
        or current.clean then
        return
    end
    if not (exposure.now or exposure.soon or exposure.any) or fd_on() then
        return
    end
    if not dt_on() or charge.value < 1 then
        return
    end
    if speed2d(lp) < teleport.min_speed or teleport.land_time(lp) < teleport.land_guard then
        return
    end
    pcall(function() cmd.discharge_pending = true end)
    teleport.count, teleport.last, teleport.watch = teleport.count + 1, now, now
    teleport.pending = { tick = tickcount() }
    if on(menu.hit_log) then
        print(("[%s] teleport: havada goruldun, DT ile isinlanildi (%d. kez)"):format(SCRIPT, teleport.count))
    end
end

-------------------------------------------------------------------------------
-- AI peek
-------------------------------------------------------------------------------

-- Quick peek assist tusunu basili tutup hareket tuslarina basmiyorsan script yanlari tarar: tehdide dik,
-- sola ve saga 18 / 32 / 46 / 60 birim. Bir noktaya yurunebiliyorsa (yolda duvar yok, altinda zemin var)
-- ve o noktadan dusmanin kafasina ya da gogsune ates etsen aimbot'un minimum hasari geciyorsa (scout'ta
-- canini, yani oldurecek atis), en yakin boyle noktaya script yurur ve ates edilince (ya da edilmezse
-- bekleyip) baslangic noktana geri yurur. Yururken GameSense'in Quick peek assist'i gecici olarak kapatilir
-- (kutusu; tusun okunmaya devam eder). Neverlose V1.0'daki butun kurallar (teyit, takip, baska dusmanin
-- gormesi, sahte kayit, iki bos peek, yukaridaki dusmana geri-capraz) aynen.
local ai_peek = { mode = nil, home = nil, target = nil, side = nil, until_time = -1000, scan_tick = -1000,
    rest = -1000, fails = 0, blocked = nil, reached = 0, step = 0, enemy = nil, name = nil, shots = {},
    held_since = nil, reported = false, why = nil, quiet = 1.0, candidate = nil, lost = 0, started = -1000,
    steps = { 18, 32, 46, 60 }, every = 4, confirm_every = 2, walk_every = 2, lost_max = 3, reach = 74, high = 32,
    lead = 0.15, def_wait = 0.2, extended = false,
    hold = 0.5, hold_r8 = 0.75, after_shot = 0.8, back_time = 0.6 }
local update_ai_peek
do
    ai_peek.available = trace_available and type(client.trace_line) == "function"

    -- Oraya yurunebilir misin: diz ve goz hizasinda, govdenin iki yaninda cizgiler (GameSense'te hull izi
    -- yok) ve noktanin altinda zemin (ucurumdan dusmezsin). Iz atilamazsa hayir.
    local function walkable(lp, from, to)
        local dx, dy = to.x - from.x, to.y - from.y
        local length = sqrt(dx * dx + dy * dy)
        if length < 1 then
            return true
        end
        local px, py = -dy / length * 14, dx / length * 14
        for _, height in ipairs({ 24, 60 }) do
            for _, off in ipairs({ 0, 1, -1 }) do
                local a = vector(from.x + px * off, from.y + py * off, from.z + height)
                local b = vector(to.x + px * off, to.y + py * off, to.z + height)
                local fraction = trace_line(lp, a, b)
                if fraction == nil or fraction < 1 then
                    return false
                end
            end
        end
        local ground = trace_line(lp, vector(to.x, to.y, to.z + 18), vector(to.x, to.y, to.z - 40))
        return ground ~= nil and ground < 1
    end

    -- Dusmanin kafasi, gogsu ve midesi (hitbox okunamazsa goz, govde ortasi ve bel) ve kafanin iki kenari.
    local function aim_points(enemy, from)
        local health = prop(enemy, "m_iHealth")
        local points = { health = finite(health) and health > 0 and health or 100 }
        local head = hitbox_of(enemy, 0) or eye_of(enemy)
        if head ~= nil then
            points[#points + 1] = { pos = head, head = true }
        end
        local edges = head ~= nil and from ~= nil and side_points(head, from, exposure.edge) or {}
        for _, body in ipairs({ { 5, 50 }, { 3, 40 } }) do
            local point = hitbox_of(enemy, body[1])
            if point == nil then
                local base = origin_of(enemy)
                point = base ~= nil and vector(base.x, base.y, base.z + body[2]) or nil
            end
            if point ~= nil then
                points[#points + 1] = { pos = point, head = false }
            end
        end
        for _, edge in ipairs(edges) do
            points[#points + 1] = { pos = edge, head = true }
        end
        return points
    end

    -- Bu goz noktasindan sayilan en iyi hasar. Govde noktasi sadece olduruyorsa sayilir (DT'li silahta iki
    -- mermiyle).
    local function best_damage(lp, eye, points, need, enemy)
        local shots = (dt_on() and not SNIPERS[current.weapon]) and 2 or 1
        local best = 0
        for _, point in ipairs(points) do
            local damage = bullet_damage(lp, eye, point.pos, enemy)
            if damage ~= nil then
                if not point.head and damage * shots < points.health then
                    damage = 0
                end
                if damage > best then
                    best = damage
                    if need ~= nil and best >= need then
                        return best
                    end
                end
            end
        end
        return best
    end

    -- Aimbot'un ates edecegi en dusuk hasar: Min. damage (100 ustu = can + fazlasi), en fazla dusmanin cani.
    local function required_damage(enemy)
        local health = prop(enemy, "m_iHealth")
        if not finite(health) or health <= 0 then
            health = 100
        end
        if on(menu.head_only) and SNIPERS[current.weapon] then
            return health + 1
        end
        local md = active_min_damage()
        if md > 100 then
            return health + md - 100
        end
        return max(1, min(md, health))
    end

    local function eye_height(lp, mine)
        local eye = eye_of(lp)
        if eye ~= nil and eye.z > mine.z then
            return eye.z - mine.z
        end
        return 64
    end

    -- O noktada kafani peek atilan dusman disinda goren canli dusman; yoksa nil.
    local function seen_by_other(spot, height, enemy)
        local head = vector(spot.x, spot.y, spot.z + height)
        for _, other in ipairs(enemy_list()) do
            if other ~= enemy then
                local eye = eye_of(other)
                if eye ~= nil and head_visible_to(other, eye, head, 0, 0, 0) then
                    return other
                end
            end
        end
        return nil
    end

    -- "here": buradan zaten vurulabiliyor; nil: yan noktalarin hicbiri olmuyor (ikinci deger: oldurecek nokta
    -- vardi ama baska bir dusman da kafani gorurdu); yoksa en yakin nokta.
    local function scan(lp, mine, enemy)
        local theirs = origin_of(enemy)
        if theirs == nil then
            return nil
        end
        local dx, dy = theirs.x - mine.x, theirs.y - mine.y
        local length = sqrt(dx * dx + dy * dy)
        if length < 1 then
            return nil
        end
        dx, dy = dx / length, dy / length
        local height, need, points = eye_height(lp, mine), required_damage(enemy), aim_points(enemy, mine)
        if #points == 0 then
            return nil
        end
        if best_damage(lp, vector(mine.x, mine.y, mine.z + height), points, need, enemy) >= need then
            return "here"
        end
        local found, watcher
        local dirs = { { -dy, dx, "sol" }, { dy, -dx, "sag" } }
        if theirs.z - mine.z >= ai_peek.high then
            local r = 0.7071
            dirs[3] = { (-dy - dx) * r, (dx - dy) * r, "sol", true }
            dirs[4] = { (dy - dx) * r, (-dx - dy) * r, "sag", true }
        end
        for _, side in ipairs(dirs) do
            for _, step in ipairs(ai_peek.steps) do
                if found ~= nil and step >= found.step then
                    break
                end
                local spot = vector(mine.x + side[1] * step, mine.y + side[2] * step, mine.z)
                if not walkable(lp, mine, spot) then
                    break
                end
                local damage = best_damage(lp, vector(spot.x, spot.y, spot.z + height), points, need, enemy)
                if damage >= need then
                    local other = seen_by_other(spot, height, enemy)
                    if other == nil then
                        found = { spot = spot, step = step, side = side[3], damage = damage, back = side[4] }
                        break
                    end
                    watcher = watcher or other
                end
            end
        end
        if found == nil then
            return nil, watcher
        end
        return found
    end

    local function spot_damage(lp, mine, spot, enemy)
        local points, need = aim_points(enemy, spot), required_damage(enemy)
        if #points == 0 then
            return 0, need
        end
        return best_damage(lp, vector(spot.x, spot.y, spot.z + eye_height(lp, mine)), points, need, enemy), need
    end

    -- Hedefe dogru tam hizla (son 12 birimde yavaslayarak) yurur; uzakligi dondurur.
    local function move_to(cmd, mine, dest)
        local dx, dy = dest.x - mine.x, dest.y - mine.y
        local distance = sqrt(dx * dx + dy * dy)
        local view = view_yaw(cmd)
        if view == nil or distance < 1 then
            return distance
        end
        local angle = math.rad(math.deg(atan2(dy, dx)) - view)
        local speed = distance > 12 and 450 or distance * 30
        local forward, side = math.cos(angle) * speed, -math.sin(angle) * speed
        pcall(function()
            cmd.forwardmove, cmd.sidemove = forward, side
            cmd.in_forward, cmd.in_back = forward > 1 and 1 or 0, forward < -1 and 1 or 0
            cmd.in_moveright, cmd.in_moveleft = side > 1 and 1 or 0, side < -1 and 1 or 0
        end)
        return distance
    end

    local function stand(cmd)
        pcall(function()
            cmd.forwardmove, cmd.sidemove = 0, 0
            cmd.in_forward, cmd.in_back, cmd.in_moveright, cmd.in_moveleft = 0, 0, 0, 0
        end)
    end

    local function user_moving(cmd)
        local ok, moving = pcall(function()
            return (tonumber(cmd.forwardmove) or 0) ~= 0 or (tonumber(cmd.sidemove) or 0) ~= 0
                or pressed(cmd.in_forward) or pressed(cmd.in_back) or pressed(cmd.in_moveleft) or pressed(cmd.in_moveright)
        end)
        return not ok or moving
    end

    local function allowed(lp, cmd, class)
        if not ai_peek.available or not on(menu.ai_peek) or not peek_key_held() then
            return false
        end
        if not on_ground(lp) or pressed(cmd.in_jump) or pressed(cmd.in_use)
            or prop(lp, "m_MoveType") == K.MOVETYPE_LADDER or fd_on() then
            return false
        end
        return class ~= nil and not MELEE[class] and class ~= "CC4" and not is_grenade(class)
    end

    local function usable(enemy)
        if enemy == nil or dormant(enemy) or not alive(enemy) then
            return nil
        end
        return enemy
    end

    local function enemy_target()
        return usable(aa_threat())
    end

    local function peek_enemy()
        return usable(ai_peek.enemy)
    end

    ai_peek.reset = function()
        ai_peek.mode, ai_peek.home, ai_peek.target, ai_peek.fails, ai_peek.blocked = nil, nil, nil, 0, nil
        ai_peek.held_since, ai_peek.reported, ai_peek.why, ai_peek.shot = nil, false, nil, false
        ai_peek.candidate, ai_peek.lost = nil, 0
        override("peek_assist", nil)
    end

    local function report_idle(now)
        if ai_peek.reported or ai_peek.held_since == nil or now - ai_peek.held_since < ai_peek.quiet
            or ai_peek.why == nil then
            return
        end
        ai_peek.reported = true
        if on(menu.shot_log) then
            print(("[%s] ai peek: peek yok, %s"):format(SCRIPT, ai_peek.why))
        end
    end

    -- Bos peek sayaci geri donus bitince artar (V1.0.15): donerken atis olursa peek bos sayilmaz.
    local function give_up(cmd, mine, now, reason)
        ai_peek.mode, ai_peek.until_time = "back", now + ai_peek.back_time
        move_to(cmd, mine, ai_peek.home or mine)
        if on(menu.shot_log) then
            print(("[%s] ai peek: atis olmadi, %s (%d/%d birim gidildi) -> geri"):format(SCRIPT, reason,
                floor(ai_peek.reached + 0.5), ai_peek.step))
        end
    end

    local function cancelled(cmd)
        if ai_peek.mode ~= "go" and ai_peek.mode ~= "hold" then
            return
        end
        if on(menu.shot_log) then
            local why = user_moving(cmd) and "hareket tusu" or (not peek_key_held() and "Peek Assist birakildi")
                or "kosul degisti"
            print(("[%s] ai peek: iptal, %s"):format(SCRIPT, why))
        end
    end

    -- aim_fire istemcide hemen gelir; weapon_fire (own.last_shot) sunucudan gec gelir (V1.0.15: arada peek
    -- "atis olmadi" deyip bos sayiliyordu, isabetli peek'ten sonra "2 bos peek" kilidi). Donerken atis da sayilir.
    ai_peek.fired = function(id, target)
        if ai_peek.mode == nil or id == nil then
            return
        end
        ai_peek.shot = true
        aim_stats.ai_shots = aim_stats.ai_shots + 1
        ai_peek.shots[id] = { name = player_name(target), reached = floor(ai_peek.reached + 0.5) }
    end

    -- reason nil = isabet.
    ai_peek.result = function(id, reason, hitgroup, damage, target_name)
        local shot = id ~= nil and ai_peek.shots[id] or nil
        if shot == nil then
            return
        end
        ai_peek.shots[id] = nil
        local what
        if reason == nil then
            aim_stats.ai_hits = aim_stats.ai_hits + 1
            what = ("isabet %s -%d"):format(HITGROUPS[hitgroup] or "?", tonumber(damage) or 0)
        else
            what = ("iska (%s)"):format(tostring(reason))
        end
        if on(menu.shot_log) then
            print(("[%s] ai peek sonucu: %s -> %s (%d birim)"):format(SCRIPT, what, target_name or shot.name,
                shot.reached))
        end
    end

    ai_peek.hurt = function(hitgroup, damage, attacker_name)
        if ai_peek.mode == nil then
            return
        end
        aim_stats.ai_hurt = aim_stats.ai_hurt + 1
        if on(menu.shot_log) then
            print(("[%s] ai peek: peek sirasinda vuruldun (%s -%d, %s)"):format(SCRIPT, HITGROUPS[hitgroup] or "?",
                tonumber(damage) or 0, attacker_name))
        end
    end

    local step

    update_ai_peek = function(lp, cmd, class)
        step(lp, cmd, class)
        if ai_peek.mode ~= nil then
            override("peek_assist", false)
        else
            override("peek_assist", nil)
        end
        exposure.peeking = (ai_peek.mode == "go" or ai_peek.mode == "hold") and ai_peek.enemy or nil
    end

    step = function(lp, cmd, class)
        local mine = origin_of(lp)
        if mine == nil or not allowed(lp, cmd, class) or user_moving(cmd) then
            cancelled(cmd)
            ai_peek.reset()
            return
        end
        local now, tick = realtime(), tickcount()
        if ai_peek.held_since == nil then
            ai_peek.held_since = now
        end
        if (ai_peek.mode == "go" or ai_peek.mode == "hold") and (ai_peek.shot or own.last_shot >= ai_peek.started) then
            ai_peek.mode, ai_peek.target, ai_peek.fails, ai_peek.blocked = "back", nil, 0, nil
            ai_peek.until_time, ai_peek.shot = now + ai_peek.back_time, true
        end
        if (ai_peek.mode == "go" or ai_peek.mode == "hold") and ai_peek.home ~= nil then
            local rx, ry = mine.x - ai_peek.home.x, mine.y - ai_peek.home.y
            ai_peek.reached = max(ai_peek.reached, sqrt(rx * rx + ry * ry))
        end

        if ai_peek.mode == "back" then
            if ai_peek.home == nil or move_to(cmd, mine, ai_peek.home) < 6 or now > ai_peek.until_time then
                stand(cmd)
                ai_peek.mode, ai_peek.rest = nil, now + 0.3
                if ai_peek.shot or own.last_shot >= ai_peek.started then
                    ai_peek.shot, ai_peek.fails, ai_peek.blocked = false, 0, nil
                    return
                end
                aim_stats.ai_empty = aim_stats.ai_empty + 1
                ai_peek.fails = ai_peek.fails + 1
                if ai_peek.fails >= 2 then
                    ai_peek.blocked = ai_peek.enemy
                    if on(menu.shot_log) then
                        print(("[%s] ai peek: 2 bos peek, bu dusmana Peek Assist tusuna yeniden basana kadar peek yok"):format(SCRIPT))
                    end
                end
            end
            return
        end

        local walking = ai_peek.mode == "go" or ai_peek.mode == "hold"
        local gap = walking and ai_peek.walk_every or (ai_peek.candidate ~= nil and ai_peek.confirm_every) or ai_peek.every
        local due = tick < ai_peek.scan_tick or tick - ai_peek.scan_tick >= gap
        local hold = class == "Revolver" and ai_peek.hold_r8 or ai_peek.hold
        if walking then
            local enemy = peek_enemy()
            if enemy ~= nil and ai_peek.mode == "hold" and not ai_peek.extended then
                local profile = enemy_watch.profile(enemy)
                if profile ~= nil and profile.defensive_now then
                    ai_peek.until_time, ai_peek.extended = ai_peek.until_time + ai_peek.def_wait, true
                end
            end
            if enemy == nil or now > ai_peek.until_time then
                give_up(cmd, mine, now, enemy == nil and "hedef yok" or "sure doldu")
                return
            end
            if due then
                ai_peek.scan_tick = tick
                local result
                local damage, need = spot_damage(lp, mine, mine, enemy)
                if damage >= need then
                    result = "here"
                else
                    if ai_peek.mode == "go" and ai_peek.target ~= nil then
                        local at_spot = spot_damage(lp, mine, ai_peek.target, enemy)
                        damage = max(damage, at_spot)
                        if at_spot >= need then
                            result = { spot = ai_peek.target, side = ai_peek.side }
                        end
                    end
                    result = result or scan(lp, mine, enemy)
                end
                local why, far = nil, 0
                if type(result) == "table" and result.side ~= ai_peek.side then
                    why, result = "aci sadece diger tarafta", nil
                elseif type(result) == "table" and ai_peek.home ~= nil then
                    local fx, fy = result.spot.x - ai_peek.home.x, result.spot.y - ai_peek.home.y
                    far = sqrt(fx * fx + fy * fy)
                    if far > ai_peek.reach then
                        why, result = ("aci %d birimden uzakta"):format(ai_peek.reach), nil
                    end
                end
                local profile = enemy_watch.profile(enemy)
                local faked = profile ~= nil and (profile.defensive_now or profile.defensive or profile.lc)
                if result == nil and faked then
                    ai_peek.faked = true
                elseif result == nil then
                    ai_peek.lost = ai_peek.lost + 1
                    if ai_peek.lost >= ai_peek.lost_max then
                        give_up(cmd, mine, now, (why or ("aci kapandi, hasar %d/%d"):format(floor(damage + 0.5), need))
                            .. (ai_peek.faked and ", dusman defensive kullandi" or ""))
                        return
                    end
                elseif result == "here" then
                    ai_peek.lost = 0
                    if ai_peek.mode == "go" then
                        ai_peek.mode, ai_peek.until_time = "hold", now + hold
                    end
                else
                    if ai_peek.mode == "hold" then
                        ai_peek.mode, ai_peek.until_time = "go", max(ai_peek.until_time, now + 0.25)
                    end
                    ai_peek.lost, ai_peek.target, ai_peek.step = 0, result.spot, max(ai_peek.step, floor(far + 0.5))
                end
            end
            if ai_peek.mode == "hold" then
                stand(cmd)
            elseif move_to(cmd, mine, ai_peek.target) < 4 then
                stand(cmd)
                ai_peek.mode, ai_peek.until_time = "hold", now + hold
            end
            return
        end

        local enemy = enemy_target()
        if ai_peek.home == nil then
            ai_peek.home = mine
        end
        local hx, hy = mine.x - ai_peek.home.x, mine.y - ai_peek.home.y
        if hx * hx + hy * hy > 64 then
            ai_peek.home = mine
        end
        -- Exploit sarjli olmadan peek yok (DT'de). GameSense'te HS sarji olculemiyor.
        local charging_dt = dt_on() and charge.value < 1
        local armed = weapon_ready(lp, ai_peek.lead)
        if enemy == nil then
            ai_peek.why = "hedef yok"
        elseif charging_dt then
            ai_peek.why = "DT sarj oluyor"
        elseif not armed then
            ai_peek.why = "silah hazir degil (surgu / sarjor)"
        end
        report_idle(now)
        if enemy == nil or charging_dt or not armed or now < ai_peek.rest or now - own.last_shot < ai_peek.after_shot or not due then
            return
        end
        if ai_peek.blocked ~= nil and enemy == ai_peek.blocked then
            return
        end
        ai_peek.scan_tick = tick
        local result, watcher = scan(lp, mine, enemy)
        if type(result) ~= "table" then
            ai_peek.candidate = nil
            if result == "here" then
                ai_peek.why = ("%s buradan vurulabiliyor, aimbot ates etmeli"):format(player_name(enemy))
            elseif watcher ~= nil then
                ai_peek.why = ("%s icin nokta var ama %s de kafani gorurdu"):format(player_name(enemy), player_name(watcher))
            else
                ai_peek.why = ("%s icin 60 birime kadar oldurecek atis yok"):format(player_name(enemy))
            end
            return
        end
        local candidate = ai_peek.candidate
        if candidate == nil or candidate.enemy ~= enemy or candidate.side ~= result.side
            or tick - candidate.tick > 3 * ai_peek.confirm_every then
            ai_peek.candidate = { enemy = enemy, side = result.side, tick = tick }
            return
        end
        ai_peek.candidate = nil
        ai_peek.reported = true
        if enemy ~= ai_peek.enemy then
            ai_peek.fails = 0
        end
        ai_peek.mode, ai_peek.target, ai_peek.side, ai_peek.started = "go", result.spot, result.side, now
        ai_peek.extended, ai_peek.shot = false, false
        ai_peek.enemy, ai_peek.reached, ai_peek.step, ai_peek.lost, ai_peek.faked = enemy, 0, result.step, 0, false
        aim_stats.ai_peeks = aim_stats.ai_peeks + 1
        ai_peek.until_time = now + 0.25 + result.step / 120
        move_to(cmd, mine, result.spot)
        if on(menu.shot_log) then
            print(("[%s] ai peek: %s %d birim -> %s (hasar %d)"):format(SCRIPT, result.side .. (result.back and "-geri" or ""), result.step,
                player_name(enemy), floor(result.damage + 0.5)))
        end
    end
end

-- Manuel yaw: uc tus (GameSense'te bind'lenebilen combo yok). Tusa basinca o yon, ayni tusa tekrar basinca
-- kapanir. Tuslar "On hotkey" modunda tutulur (basma anini yakalamak icin).
local manual = { dir = "Off", last = {} }
local update_manual
do
    local MANUAL_KEYS = { { "manual_left", "Left" }, { "manual_right", "Right" }, { "manual_forward", "Forward" } }

    update_manual = function()
        for _, item in ipairs(MANUAL_KEYS) do
            local element = menu[item[1]]
            if element ~= nil then
                local ok, active, mode, key = pcall(ui.get, element.ref)
                if ok and finite(mode) and mode ~= 1 then
                    pcall(ui.set, element.ref, "On hotkey", key)
                end
                local down = ok and active == true
                if down and not manual.last[item[1]] then
                    manual.dir = manual.dir == item[2] and "Off" or item[2]
                end
                manual.last[item[1]] = down
            end
        end
    end
end

-- Lua-tarafli yaw modifier'lari (GameSense'te olmayan Spin / 3-Way / 5-Way): her gonderilen pakette adim.
local emulated_modifier
do
    local modstep = { n = 0 }
    emulated_modifier = function(mode, amount, choked)
        if choked == 0 then
            modstep.n = modstep.n + 1
        end
        local m = abs(amount)
        if m < 1 then
            return 0
        end
        if mode == "Spin" then
            local span = 2 * m
            return (tickcount() * 6) % span - m
        elseif mode == "3-Way" then
            local ways = { -m, 0, m }
            return ways[modstep.n % 3 + 1]
        elseif mode == "5-Way" then
            local ways = { -m, -m / 2, 0, m / 2, m }
            return ways[modstep.n % 5 + 1]
        end
        return 0
    end
end

-- Tick akisi uc adimda (LuaJIT'te bir fonksiyon en fazla 60 dis degiskene dokunabilir):
--  tick_prepare: oyuncu, gorus, durum, resolver, body aim, AI peek. Oyun disi / kapaliysa nil.
--  tick_special: merdiven, legit AA, spin (kendi AA'lari olan durumlar); uyguladiysa true.
--  tick_aa: normal durum secimi, builder AA'si, anti-brute fazi, defensive, teleport.
local function tick_prepare(cmd)
    current.defensive, current.forced, current.lc, current.anti, current.clean = false, false, false, false, false
    local rec, tick = recommended_state, tickcount()
    if rec.pending or tick < rec.tick or tick - rec.tick >= rec.every then
        apply_recommended()
    end
    if not on(menu.enabled) then
        reset_overrides()
        plist_reset(false)
        return nil
    end
    local lp = local_player()
    if lp == nil or not alive(lp) then
        override("fakeduck", nil)
        recharge.held = false
        -- Olunce oyuncu listesi ezmeleri (safe point, body aim, hipotez, sahte kayit bekleme whitelist'i)
        -- geri verilir; dogunca yeniden kurulur.
        plist_reset(false)
        return nil
    end
    local choked = finite(cmd.chokedcommands) and cmd.chokedcommands or 0
    exposure.facing = nil
    charge.update(lp)
    update_tickbase(lp, choked)
    update_fd_guard(lp)
    enemy_watch.update()
    update_exposure(lp, cmd)
    update_manual()
    local move_state = detect_movement(lp, cmd)
    local class = weapon_class(lp)
    current.weapon = class

    process_pending_misses()
    current.phase_group = brute.group_for(move_state)
    current.brute = on(menu.anti_brute) and threat_stage(current.phase_group) or 0
    local present = {}
    local aim_target, resolver_raw = apply_resolver(class, present)
    apply_body_aim(lp, class, aim_target, resolver_raw, present)
    resolver.wait_apply(class, present)
    plist_release_missing(present)
    update_ai_peek(lp, cmd, class)
    return lp, choked, move_state, class, aim_target
end

local function tick_special(cmd, lp, move_state, class)
    -- Merdivende yerde degiliz ama "havada" da sayilmamaliyiz; acilara GameSense kendisi karisir.
    if prop(lp, "m_MoveType") == K.MOVETYPE_LADDER then
        current.state = "Ladder"
        apply_exploit(builder["Standing"], class)
        sample_exploit(current.state)
        return true
    end
    -- Legit AA ve spin'de de hareket durumunun exploit'i korunur; DT'yi kapatip acmak yeniden sarj demek.
    if legit_use_active(lp, cmd) then
        current.state = "Legit"
        apply_exploit(builder[move_state], class)
        sample_exploit(current.state)
        apply({
            pitch = "Off", yaw_base = "Local View", yaw_offset = 180, modifier = "Off", mod_offset = 0,
            body = "Static", side = on(menu.inverter), left = 60, right = 60, body_fs = "Off", freestand = false,
        }, lp)
        return true
    end
    if spin_active() then
        current.state = "Spin"
        apply_exploit(builder[move_state], class)
        sample_exploit(current.state)
        apply({
            pitch = menu.spin_pitch:get() == "Down" and "Down" or "Off", yaw_base = "Local View",
            yaw_offset = tickcount() * menu.spin_speed:get() * 3, modifier = "Off", mod_offset = 0,
            body = "Off", side = false, left = 60, right = 60, body_fs = "Off", freestand = false,
        }, lp)
        return true
    end
    return false
end

-- Durumun builder ayarlarindan (anti-brute fazi dahil) yaw ve desync.
local function builder_angles(s, choked)
    local body = s.body_yaw:get()
    local yaw_side
    if body == "Jitter" or body == "Random" then
        yaw_side = flip.side
    else
        yaw_side = on(menu.inverter)
    end
    local side = yaw_side

    local left, right = s.left_limit:get(), s.right_limit:get()
    local phase = BRUTE_PHASES[current.brute]
    if phase ~= nil then
        if phase.invert then
            side = not side
            -- Static'te kafa desync ile birlikte doner; jitter'da sadece desync kayar, cozulen desen bozulur.
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
    local modifier = s.modifier:get()
    local mod_offset = s.mod_offset:get() + round(flip.mod_n * s.mod_random:get())
    if not NATIVE_MODIFIERS[modifier] and modifier ~= "Off" then
        yaw_offset = yaw_offset + emulated_modifier(modifier, mod_offset, choked)
    end
    return { body = body, side = side, left = left, right = right, yaw_offset = yaw_offset,
        modifier = modifier, mod_offset = mod_offset, phase = phase }
end

local function tick_aa(cmd, lp, choked, move_state, class, aim_target)
    local manual_dir = manual.dir
    local freestand = freestanding_allowed(move_state)
    local state
    if manual_dir ~= "Off" then
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
    local s = settings_for(state)
    update_flip(s, exploit_active(), choked)
    local a = builder_angles(s, choked)

    local yaw_base, yaw_offset = menu.yaw_base:get(), a.yaw_offset
    if state == "Manual" then
        yaw_base = "Local View"
        yaw_offset = yaw_offset + MANUAL_YAW[manual_dir]
        freestand = false
        exposure.facing = nil
    else
        local knife = backstab_target(lp)
        local view = knife ~= nil and view_yaw(cmd) or nil
        local mine, theirs = origin_of(lp), knife ~= nil and origin_of(knife) or nil
        if view ~= nil and mine ~= nil and theirs ~= nil then
            -- Yuzun bicakliya donuk (yaw "180" + offset = view + 180 + offset).
            yaw_base, yaw_offset, freestand = "Local View", yaw_to(mine, theirs) - view - 180, false
            exposure.facing = knife
        else
            yaw_base, yaw_offset = face_target(cmd, lp, yaw_base, yaw_offset, freestand)
        end
    end

    -- Faz 5: desync sabit, tarafi GameSense'in body freestanding'i secer. Kendi AA'si olan ozel durumlarda
    -- (Fake duck, Safe head, Manual) uygulanmaz.
    local body, body_fs = a.body, s.body_fs:get()
    if a.phase ~= nil and a.phase.freestand and not brute.unlearned[state] then
        body, body_fs = "Static", "On"
    end
    local armed = weapon_ready(lp, 0.15)
    -- Fake duck senin tusun ve kendisi lag'dir: temiz atis o sirada yok.
    current.clean = clean_shot.update(lp, aim_target, armed and class ~= nil and not NON_GUNS[class]
        and not is_grenade(class) and not fd_on())
    local hidden_pitch, hidden_yaw = apply_defensive(cmd, builder[state], class, state,
        move_state ~= "Standing" and move_state ~= "Crouching" and move_state ~= "Fake duck", armed, current.clean)
    apply({
        pitch = menu.pitch:get(), yaw_base = yaw_base, yaw_offset = yaw_offset,
        modifier = a.modifier, mod_offset = a.mod_offset,
        body = body, side = a.side, left = a.left, right = a.right, body_fs = body_fs, freestand = freestand,
        hidden_pitch = hidden_pitch, hidden_yaw = hidden_yaw,
    }, lp)
    teleport.update(cmd, lp, move_state)
    sample_exploit(state)
end

listen("setup_command", protect("setup_command", function(cmd)
    local lp, choked, move_state, class, aim_target = tick_prepare(cmd)
    if lp == nil or tick_special(cmd, lp, move_state, class) then
        return
    end
    tick_aa(cmd, lp, choked, move_state, class, aim_target)
end))

-------------------------------------------------------------------------------
-- Loglar ve olaylar
-------------------------------------------------------------------------------

-- Log icin: o anki exploit durumu. DEF acik = defensive penceresi gercekten aktif; (zorla) = script o tick
-- defensive istedi. sarj bekle = Safe recharge DT'yi bekletiyor.
local function exploit_status()
    local c = dt_charge()
    local kind, exploit
    if dt_on() then
        kind = "DT"
        exploit = (c ~= nil and c < 1) and ("DT %%%d"):format(round(max(0, c) * 100)) or "DT dolu"
    elseif hs_on() then
        kind = "HS"
        exploit = "HS" .. (current.lc and " LC" or "")
    else
        kind = "none"
        exploit = recharge.held and "DT %0" or "DT yok"
    end
    local by_bind
    if kind == "HS" then
        by_bind = not is_overridden("hideshots")
    elseif kind == "none" then
        by_bind = not is_overridden("doubletap") and not is_overridden("hideshots")
    else
        by_bind = not is_overridden("doubletap")
    end
    if by_bind then
        exploit = exploit .. " (bind)"
    end
    local parts = {}
    if fd_on() then
        parts[#parts + 1] = "FD"
    end
    parts[#parts + 1] = exploit
    parts[#parts + 1] = (defensive_active() and "DEF acik" or "DEF yok") .. (current.forced and " (zorla)" or "")
    if recharge.held then
        parts[#parts + 1] = "sarj bekle"
    end
    local now = realtime()
    local shot = now - own.last_shot
    parts[#parts + 1] = (shot >= 0 and shot < 5) and ("atis %.2fs"):format(shot) or "atis yok"
    local since_tp = now - teleport.last
    if since_tp >= 0 and since_tp < 2 then
        parts[#parts + 1] = ("tp %.2fs"):format(since_tp)
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

local function userid_index(userid)
    local ent = try(client.userid_to_entindex, userid)
    if finite(ent) and ent > 0 then
        return ent
    end
    return nil
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

    listen("bullet_impact", protect("bullet_impact", function(e)
        if not on(menu.enabled) then
            return
        end
        local lp = local_player()
        if lp == nil or not alive(lp) then
            return
        end
        local shooter = userid_index(e.userid)
        if shooter == nil or shooter == lp or not is_enemy(shooter) then
            return
        end
        local key, entry = brute_entry(shooter, "u" .. tostring(e.userid))
        local now = realtime()
        if entry.last ~= nil and now >= entry.last and now - entry.last < K.BRUTE_DEBOUNCE then
            return
        end
        local head = hitbox_of(lp, 0)
        local eye = eye_of(shooter)
        if head == nil or eye == nil or not finite(e.x) then
            return
        end
        if distance_to_segment(head, eye, vector(e.x, e.y, e.z)) > K.BRUTE_RADIUS then
            return
        end
        entry.last = now
        exposure.shot = { index = shooter, tick = tickcount() }
        local shot_stage = on(menu.anti_brute) and brute_entry_stage(entry, current.phase_group) or 0
        entry.shot_stage = shot_stage
        entry.shot_applied, entry.shot_group, entry.shot_sniper = current.brute, brute.stat_group(),
            sniper.mode(current.weapon)

        local hurt = brute.hurt[e.userid]
        if hurt == nil or now < hurt or now - hurt >= K.MISS_WINDOW then
            pending_misses[#pending_misses + 1] = {
                userid = e.userid, time = now, state = current.state, stage = shot_stage, name = player_name(shooter),
                aa = aa_status(), exploit = exploit_status(), weapon = weapon_label(), attacker = attacker_info(shooter),
                applied = current.brute, group = brute.stat_group(), sniper = sniper.mode(current.weapon),
            }
        end

        if not on(menu.anti_brute) then
            return
        end
        entry.stage = shot_stage % #BRUTE_PHASES + 1
        entry.time = now
        brute.recent = key
        if on(menu.brute_log) then
            print(("[%s] anti-brute: %s faz %d"):format(SCRIPT, player_name(shooter), entry.stage))
        end
    end))
end

-- Round ozeti: round boyunca sana gelen mermiler durum, faz, exploit ve gorus basina sayilir.
own.count = function(state, stage, head, unseen)
    local r = own.round or { hits = 0, head = 0, states = {}, order = {}, phases = {}, exploits = {}, unseen = 0 }
    own.round = r
    r.hits = r.hits + 1
    r.head = r.head + (head and 1 or 0)
    r.unseen = r.unseen + (unseen and 1 or 0)
    local st = r.states[state]
    if st == nil then
        st = { hits = 0, head = 0 }
        r.states[state], r.order[#r.order + 1] = st, state
    end
    st.hits, st.head = st.hits + 1, st.head + (head and 1 or 0)
    if head then
        r.phases[stage] = (r.phases[stage] or 0) + 1
    end
    -- Safe recharge DT'yi gecici kapattiysa o an yine DT sayilir.
    local kind = fd_on() and "FD" or ((dt_on() or recharge.held) and "DT") or (hs_on() and "HS") or "yok"
    r.exploits[kind] = (r.exploits[kind] or 0) + 1
end

own.summary = function()
    local r = own.round
    own.round = nil
    if r == nil or not on(menu.hit_log) then
        return
    end
    local states = {}
    for _, state in ipairs(r.order) do
        local st = r.states[state]
        states[#states + 1] = ("%s %d/%d"):format(state, st.head, st.hits)
    end
    local phases = {}
    for phase = 0, #BRUTE_PHASES do
        if r.phases[phase] ~= nil then
            phases[#phases + 1] = ("%d:%d"):format(phase, r.phases[phase])
        end
    end
    local exploits = {}
    for _, kind in ipairs({ "DT", "HS", "FD", "yok" }) do
        if r.exploits[kind] ~= nil then
            exploits[#exploits + 1] = ("%s %d"):format(kind, r.exploits[kind])
        end
    end
    print(("[%s] round ozeti: %d mermi, %d kafa | %s | kafa fazlari %s | %s | gormedi %d"):format(SCRIPT, r.hits, r.head,
        table.concat(states, ", "), #phases > 0 and table.concat(phases, " ") or "-", table.concat(exploits, ", "), r.unseen))
end

-- Round sonu senin atislarin: mermi, isabet, temiz / lag'li atislarin isabeti ve iska sebepleri.
own.shot_summary = function()
    local r = own.shots_round
    own.shots_round = nil
    if r == nil or not on(menu.shot_log) then
        return
    end
    local reasons = {}
    for reason, n in pairs(r.misses) do
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
        parts[#parts + 1] = ("%s %d"):format(item.reason, item.n)
    end
    print(("[%s] atis ozeti: %d mermi, %d isabet | temiz %d/%d, lag %d/%d | iska: %s"):format(SCRIPT, r.shots, r.hits,
        r.clean_hits, r.clean, r.lag_hits, r.lag, #parts > 0 and table.concat(parts, ", ") or "yok"))
end

listen("player_hurt", protect("player_hurt", function(e)
    if not on(menu.enabled) then
        return
    end
    local lp = local_player()
    local hurt_index = userid_index(e.userid)
    -- Senin verdigin hasar: "?" iskasinda sunucudaki isabet sayaci arttiysa hasar baska oyuncuya mi gitti.
    if lp ~= nil and hurt_index ~= nil and hurt_index ~= lp and userid_index(e.attacker) == lp then
        own.dealt = { time = realtime(), victim = hurt_index }
    end
    if lp == nil or hurt_index ~= lp then
        return
    end
    local attacker = userid_index(e.attacker)
    if attacker == nil or attacker == lp or not is_enemy(attacker) then
        return
    end
    if NON_BULLET_DAMAGE[tostring(e.weapon)] then
        return
    end

    local now = realtime()
    brute.hurt[e.attacker] = now
    teleport.hurt(now)
    -- Fake duck'tayken sniper mermisi: fake duck korumasi bir sure birakir (bkz. update_fd_guard).
    if fd_on() and (e.weapon == "ssg08" or e.weapon == "awp") then
        own.fd_hit = { attacker = attacker, time = now, name = player_name(attacker) }
    end
    ai_peek.hurt(e.hitgroup, e.dmg_health, player_name(attacker))
    for i = #pending_misses, 1, -1 do
        if pending_misses[i].userid == e.attacker then
            table.remove(pending_misses, i)
        end
    end

    -- Vuruldugumuz faz: mermi geldiginde gercekten uygulanan faz (AA'nin dondugu dusmaninki).
    local _, enemy = brute_entry(attacker, "u" .. tostring(e.attacker))
    local phase, grp_name, shot_sniper = nil, nil, sniper.mode(current.weapon)
    if enemy.shot_stage ~= nil and enemy.last ~= nil and now >= enemy.last and now - enemy.last < K.MISS_WINDOW then
        phase, grp_name, shot_sniper = enemy.shot_applied, enemy.shot_group, enemy.shot_sniper
    else
        phase = on(menu.anti_brute) and threat_stage(current.phase_group) or 0
        grp_name = brute.stat_group()
    end
    local weapon = tostring(e.weapon or "?")
    local melee = weapon:find("knife", 1, true) ~= nil or weapon == "bayonet" or weapon == "taser"
    if e.hitgroup == 1 and not melee and on(menu.anti_brute) then
        enemy.base, enemy.learned = (phase + 1) % (#BRUTE_PHASES + 1), true
    end
    if e.hitgroup == 1 and not melee then
        record_phase(grp_name, phase, true)
    end
    -- Sniper exploit: govde isabeti de mermi sayilir, kafa degil (V1.0.15; oyun logu: DT'de yenen 33 isabetin
    -- 17'si govde, HS'de 21'in hepsi kafa; govde sayilmayinca HS daha iyi gorunup 30 dk DT / defensive kapali kaldi).
    if not melee then
        sniper.record(shot_sniper, e.hitgroup == 1)
    end

    local info = attacker_info(attacker)
    if not melee then
        local entry = stat_for(current.state)
        entry.hits = entry.hits + 1
        if e.hitgroup == 1 then
            entry.head = entry.head + 1
        end
        own.count(current.state, phase, e.hitgroup == 1, info:find("gormedi", 1, true) ~= nil)
    end
    if on(menu.hit_log) then
        print(("[%s] vuruldun: %s -%d %s | %s | faz %d | %s | %s | %s | %s (%s)"):format(
            SCRIPT, HITGROUPS[e.hitgroup] or "?", tonumber(e.dmg_health) or 0, weapon,
            current.state, phase, aa_status(), exploit_status(), weapon_label(), player_name(attacker), info))
    end
end))

listen("weapon_fire", protect("weapon_fire", function(e)
    local lp = local_player()
    if lp ~= nil and userid_index(e.userid) == lp then
        own.last_shot = realtime()
    end
end))

-- Atis loglari ve sonuclari (aim_fire / aim_hit / aim_miss).
do
local function event_number(e, name)
    local ok, value = pcall(function() return e[name] end)
    if ok and finite(value) then
        return value
    end
    return nil
end

-- Dusmanin ates anindaki AA deseni: "AA jitter 80", "AA spin", "AA statik" ya da "AA ?"; defensive ve LC
-- kirma varsa eklenir.
local function profile_text(profile)
    if profile == nil then
        return "AA ?"
    end
    local pattern = profile.pattern
    local parts = { (pattern == "jitter" and ("AA jitter %d"):format(round(profile.jitter or 0)))
        or (pattern == "xway" and "AA x-way") or (pattern == "random" and "AA random")
        or (pattern == "spin" and "AA spin") or (pattern == "static" and "AA statik") or "AA ?" }
    if profile.defensive_now then
        parts[#parts + 1] = "def (sahte kayit)"
    elseif profile.defensive then
        parts[#parts + 1] = "def"
    end
    if profile.lc then
        parts[#parts + 1] = "LC"
    end
    return table.concat(parts, ", ")
end

-- Ates anindaki safe point / body aim (oyuncu listesi + rage ayari), log icin.
local function safe_label(target)
    if get("force_safe") == true or (target ~= nil and plist_get(target, PL.SAFE) == "On") then
        return "Force"
    end
    if get("prefer_safe") == true then
        return "Prefer"
    end
    return "Default"
end

local function body_label(target)
    if get("force_body") == true then
        return "Force"
    end
    local value = target ~= nil and plist_get(target, PL.BODY) or nil
    if value == "Force" then
        return "Force"
    elseif value == "On" then
        return "Prefer"
    elseif value == "Off" then
        return "Off"
    end
    return "Default"
end

local function shot_line(e, shot, target, reason)
    local name = target ~= nil and player_name(target) or "?"
    local state = shot ~= nil and shot.state or (target ~= nil and enemy_state(target)) or "?"
    local health = shot ~= nil and shot.health or nil
    local wanted = shot ~= nil and shot.hitgroup or nil
    local wanted_damage = shot ~= nil and shot.damage or 0
    local aimed = wanted ~= nil and ("hedef %s %d"):format(HITGROUPS[wanted] or "?", round(wanted_damage)) or "hedef ?"
    local result
    if reason == nil then
        result = ("isabet %s -%d"):format(HITGROUPS[event_number(e, "hitgroup") or -1] or "?",
            round(event_number(e, "damage") or 0))
    else
        result = "iska " .. tostring(reason):sub(1, 32)
    end
    local safe = shot ~= nil and shot.safe or safe_label(target)
    local body = shot ~= nil and shot.body or body_label(target)
    local min_damage = shot ~= nil and shot.md or active_min_damage()
    local backtrack = shot ~= nil and shot.backtrack or nil
    local hitchance = shot ~= nil and shot.hitchance or event_number(e, "hit_chance")
    local profile = shot ~= nil and shot.profile or enemy_watch.profile(target)
    local hyp = (shot ~= nil and shot.hyp_candidate ~= nil and shot.hyp_candidate > 0)
        and (" | BY %d%s"):format(shot.hyp_yaw or 0, DEG) or ""
    return ("[%s] atis: %s | %s | HP %s | %s | %s | SP %s | BA %s | MD %s | bt %s | hc %s | %s | %s%s"):format(SCRIPT, name,
        state, finite(health) and tostring(round(health)) or "?", aimed, result, tostring(safe), tostring(body),
        finite(min_damage) and tostring(round(min_damage)) or "?",
        backtrack ~= nil and ("%dt"):format(round(backtrack)) or "?",
        hitchance ~= nil and ("%d%%"):format(round(hitchance)) or "?",
        shot ~= nil and shot.weapon or weapon_label(), profile_text(profile), hyp)
end

listen("aim_fire", protect("aim_fire", function(e)
    local target = finite(e.target) and e.target or nil
    if target == nil then
        return
    end
    local now = realtime()
    resolver.aim_target, resolver.aim_time = target, now
    exposure.duel = { index = target, time = now }
    for id, shot in pairs(resolver.shots) do
        if now < shot.time or now - shot.time > K.SHOT_MEMORY then
            resolver.shots[id] = nil
        end
    end
    local state = enemy_state(target)
    ai_peek.fired(e.id, target)
    clean_shot.fired(target)
    -- Atis anindaki kendi lag'imiz: TP / DEF / LC / FD.
    local since_tp = now - teleport.last
    local lag = (since_tp >= 0 and since_tp <= resolver.tp_window and "TP") or (current.forced and "DEF")
        or (current.lc and "LC") or (fd_on() and "FD") or nil
    if e.id ~= nil then
        local key = player_id(target)
        local h = hypothesis.get(key, state, false)
        -- Aday ancak ates aninda oyuncu listesinde gercekten yaziliysa o atis adaya sayilir (Correction
        -- kapali ya da senin Force body yaw'in varken aday uygulanmaz; NYKLE Resolver 2.5'teki kontrol).
        local hyp_yaw = h ~= nil and h.candidate > 0 and hypothesis.yaw(hypothesis.actual(h.candidate, h.side)) or nil
        if hyp_yaw ~= nil and not (plist_get(target, PL.FORCE) == true and plist_get(target, PL.VALUE) == hyp_yaw) then
            hyp_yaw = nil
        end
        local lp = local_player()
        resolver.shots[e.id] = { target = target, state = state, time = now, safe = safe_label(target), body = body_label(target),
            md = active_min_damage(), health = prop(target, "m_iHealth"),
            weapon = weapon_label() .. (lag ~= nil and " " .. lag or (current.clean and " temiz" or "")), lag = lag,
            profile = enemy_watch.profile(target), hitgroup = event_number(e, "hitgroup"),
            damage = event_number(e, "damage"), hitchance = event_number(e, "hit_chance"),
            backtrack = event_number(e, "backtrack"), teleported = e.teleported == true,
            extrapolated = e.extrapolated == true, interpolated = e.interpolated == true,
            high_priority = e.high_priority == true,
            total_hits = lp ~= nil and prop(lp, "m_totalHitsOnServer") or nil,
            exploit = not fd_on() and ((dt_on() and "dt") or (hs_on() and "hs")) or nil,
            hyp_key = key, hyp_candidate = hyp_yaw ~= nil and h.candidate or 0, hyp_yaw = hyp_yaw,
            hyp_slot = h ~= nil and h.seeded or nil }
    end
    local stall = resolver.stalls[target]
    if stall ~= nil then
        stall.visible = 0
    end
    local body = resolver.body_stalls[target]
    if body ~= nil then
        body.visible, body.relaxed = 0, false
    end
end))

-- Atis sonucu (GameSense aim_hit / aim_miss). reason nil = isabet; "?" -> "correction" (resolver) ya da
-- sunucudaki isabet sayisi degistiyse "damage rejection" (angelwings'in yontemi).
local function aim_result(e, reason)
    if not on(menu.enabled) then
        return
    end
    local shot = e.id ~= nil and resolver.shots[e.id] or nil
    if shot ~= nil then
        resolver.shots[e.id] = nil
    end
    -- V1.0.10: hedef asagidaki "baska oyuncuya isabet" karsilastirmasindan once okunur (V1.0.8-1.0.9'da
    -- sonra tanimliydi; karsilastirma bos degere yapiliyordu ve hedefin kendi hasari da "baska oyuncu" sayiliyordu).
    local target = finite(e.target) and e.target or nil
    if reason == "?" then
        reason = "correction"
        local lp = local_player()
        local total = lp ~= nil and prop(lp, "m_totalHitsOnServer") or nil
        if shot ~= nil and finite(shot.total_hits) and finite(total) and total ~= shot.total_hits then
            -- Sayac artti: mermi sunucuda birine isabet etti. O sirada baska bir oyuncu senden hasar aldiysa
            -- isabet ona gitti; almadiysa sunucu hasari reddetti.
            local dealt = own.dealt
            if dealt ~= nil and dealt.time >= shot.time and dealt.victim ~= target then
                reason = "baska oyuncuya isabet"
            else
                reason = "damage rejection"
            end
        end
    end
    local result, excluded
    aim_stats.shots = aim_stats.shots + 1
    -- V1.0.10 logu: nisan alinan oyuncu iskalandi, mermi arkadaki baska bir dusmana isabet etti (GameSense
    -- aim_hit'te vurulan oyuncuyu verir). Kimsenin resolver'ina / hipotezine sayilmaz.
    local stray = reason == nil and shot ~= nil and shot.target ~= nil and target ~= nil and shot.target ~= target
    if reason == nil then
        aim_stats.hits = aim_stats.hits + 1
        -- Kafaya nisan alinip baska yere isabet: resolver'a isabet sayilmaz, seviyeyi dusurmez.
        local wanted = shot ~= nil and shot.hitgroup or nil
        local hit = event_number(e, "hitgroup")
        if stray then
            result, excluded = nil, ("mermi baska oyuncuya gitti (nisan: %s)"):format(player_name(shot.target))
        elseif (wanted == 1 or wanted == 8) and hit ~= nil and hit ~= 1 and hit ~= 8 then
            result = nil
        else
            result = "h"
        end
    elseif reason == "correction" then
        -- Bu iska resolver'in hatasi degil, ogrenilmez: ates aninda dusman LC kiriyordu ya da kayit defensive
        -- (sahte) kaydiydi (bizim takibimiz), ya da GameSense kaydin yerini tahmin etmisti (aim_fire'daki
        -- teleport / extrapolation bayraklari; NYKLE Resolver 2.5 de bunlari saymaz).
        local profile = shot ~= nil and shot.profile or nil
        excluded = (profile ~= nil and profile.lc and "LC") or (profile ~= nil and profile.defensive_now and "sahte kayit")
            or (shot ~= nil and shot.teleported and "teleport") or (shot ~= nil and shot.extrapolated and "extrapolation")
            or nil
        if excluded ~= nil then
            aim_stats.other = aim_stats.other + 1
        else
            aim_stats.correction = aim_stats.correction + 1
            result = "c"
        end
    elseif reason == "spread" then
        aim_stats.spread = aim_stats.spread + 1
    else
        aim_stats.other = aim_stats.other + 1
    end
    if on(menu.shot_log) then
        print(shot_line(e, shot, target, reason) .. (excluded ~= nil and (" | resolver'a sayilmadi: " .. excluded) or ""))
    end
    -- Detayli log: ates anindaki konum / kayit / aimbot bayraklari (bkz. nlog.fire_info).
    if shot ~= nil and shot.dbg ~= nil then
        print(shot.dbg .. " | sonuc " .. (reason == nil and ("isabet %s"):format(HITGROUPS[event_number(e, "hitgroup") or -1] or "?")
            or tostring(reason)))
    end
    ai_peek.result(e.id, reason, event_number(e, "hitgroup"), event_number(e, "damage"),
        target ~= nil and player_name(target) or nil)
    -- Hipotez: kafa isabeti adayi tutar, resolver iskasi sonrakine gecirir.
    if not stray then
        hypothesis.result(shot, target, reason == nil and event_number(e, "hitgroup") == 1, result == "c")
    end
    -- Kendi lag'imiz sirasinda sunucuda gecmeyen / kayan atislar: ayni turden ikincisinde o lag 10 sn durur.
    local lag = shot ~= nil and shot.lag or nil
    -- Lag yokken exploit'li (HS / DT) atis reddedildiyse exploit'e yazilir (bkz. sniper.reject).
    if (reason == "damage rejection" or reason == "unregistered shot") and lag == nil and shot ~= nil
        and shot.exploit ~= nil then
        sniper.reject(shot.exploit, reason)
    end
    if (reason == "unregistered shot" or reason == "damage rejection" or reason == "prediction error")
        and lag ~= nil and resolver.unreg[lag] ~= nil then
        local now = realtime()
        local list = {}
        for _, t in ipairs(resolver.unreg[lag]) do
            if now >= t and now - t <= resolver.unreg_window then
                list[#list + 1] = t
            end
        end
        list[#list + 1] = now
        resolver.unreg[lag] = list
        if #list >= 2 then
            resolver.unreg[lag], resolver.pause[lag] = {}, now + resolver.unreg_pause
            if on(menu.shot_log) then
                local names = resolver.lag_names[lag]
                print(("[%s] %s %d sn durduruldu: %s sirasinda %d atis bozuk gitti (son: %s)"):format(SCRIPT,
                    names[1], resolver.unreg_pause, names[2], #list, reason))
            end
        end
    end
    local counted = reason ~= "death" and reason ~= "player death"
    if counted and shot ~= nil then
        local hit = reason == nil and 1 or 0
        if lag ~= nil then
            aim_stats.lag_shots, aim_stats.lag_hits = aim_stats.lag_shots + 1, aim_stats.lag_hits + hit
        else
            aim_stats.clean_shots, aim_stats.clean_hits = aim_stats.clean_shots + 1, aim_stats.clean_hits + hit
        end
    end
    if counted then
        local r = own.shots_round or { shots = 0, hits = 0, clean = 0, clean_hits = 0, lag = 0, lag_hits = 0,
            misses = {} }
        own.shots_round = r
        r.shots = r.shots + 1
        if reason == nil then
            r.hits = r.hits + 1
        else
            r.misses[reason] = (r.misses[reason] or 0) + 1
        end
        if shot ~= nil then
            local hit = reason == nil and 1 or 0
            if lag ~= nil then
                r.lag, r.lag_hits = r.lag + 1, r.lag_hits + hit
            else
                r.clean, r.clean_hits = r.clean + 1, r.clean_hits + hit
            end
        end
        aim_stats.rated = aim_stats.rated + 1
        if reason == "spread" then
            aim_stats.rated_spread = aim_stats.rated_spread + 1
        elseif reason ~= nil and result == nil then
            aim_stats.rated_other = aim_stats.rated_other + 1
        end
    end
    local entry = target ~= nil and resolver_entry(target) or nil
    if entry ~= nil and counted then
        entry.shots = (entry.shots or 0) + 1
        if reason == "spread" then
            entry.spread = (entry.spread or 0) + 1
        elseif reason ~= nil and result == nil then
            entry.other = (entry.other or 0) + 1
        end
    end
    if result == nil or entry == nil or not on(menu.resolver) then
        return
    end
    local enemy = shot ~= nil and shot.state or enemy_state(target)
    local before = entry_level(entry, enemy)
    if result == "h" then
        entry.hits = (entry.hits or 0) + 1
    else
        entry.misses = (entry.misses or 0) + 1
    end
    window_push(entry.results, result)
    entry.states[enemy] = entry.states[enemy] or {}
    window_push(entry.states[enemy], result)
    -- Bu oturumdaki iska: o durumda Force'a (seviye 2) izin verir (bkz. entry_level).
    if result == "c" then
        entry.fresh = entry.fresh or {}
        entry.fresh[enemy] = true
    end
    persist.dirty = true
    local level = entry_level(entry, enemy)
    local stall = resolver.stalls[target]
    if stall ~= nil and stall.state == enemy then
        resolver.stalls[target] = nil
    end
    if on(menu.resolver_log) and level ~= before then
        local what = result == "c" and "iska (correction)"
            or ("isabet %s -%d"):format(HITGROUPS[event_number(e, "hitgroup")] or "?", tonumber(event_number(e, "damage")) or 0)
        print(("[%s] resolver: %s %s %s | seviye %d -> safe points %s"):format(
            SCRIPT, entry.name, enemy, what, level, SAFE_POINT_LEVELS[level]))
    end
end

listen("aim_hit", protect("aim_hit", function(e)
    aim_result(e, nil)
end))

listen("aim_miss", protect("aim_miss", function(e)
    aim_result(e, tostring(e.reason or "?"))
end))

end

-- Round / olum sonrasi aktif fazlar biter, ogrenilen kalici fazlar kalir.
local function reset_brute()
    for _, entry in pairs(brute.enemies) do
        entry.stage, entry.time, entry.last, entry.shot_stage = 0, 0, nil, nil
    end
    brute.recent, brute.hurt = nil, {}
end

-- Kalici hafiza (GameSense database): Steam ID'si olan oyuncularin kalici anti-brute fazi ve resolver
-- sonuclari, faz istatistikleri ve sniper verisi. Script yuklenirken bir kez okunur; round basinda en
-- fazla dakikada bir, harita degisirken ve script kapanirken yazilir. Body yaw hipotezleri oturumluk.
local function steam_key(key)
    return type(key) == "string" and key:sub(1, 2) == "s:"
end

persist.save = function(force)
    local now = realtime()
    if not persist.dirty or (not force and now >= persist.saved and now - persist.saved < persist.every) then
        return
    end
    local data = { version = 1, brute = {}, resolver = {}, phase_groups = {},
        sniper = { v = 2, hs = { shots = sniper.stats.hs.shots, hits = sniper.stats.hs.hits },
            dt = { shots = sniper.stats.dt.shots, hits = sniper.stats.dt.hits } } }
    for key, entry in pairs(brute.enemies) do
        if steam_key(key) and entry.learned then
            data.brute[key] = { base = entry.base, name = entry.name }
        end
    end
    for _, grp_name in ipairs(brute.groups) do
        local list = {}
        for phase = 0, #BRUTE_PHASES do
            local stat = brute.phases[grp_name][phase]
            list[phase + 1] = { shots = stat.shots, hits = stat.hits }
        end
        data.phase_groups[grp_name] = list
    end
    local function copy(list)
        local out = {}
        for i, v in ipairs(list) do
            out[i] = v
        end
        return out
    end
    for key, entry in pairs(resolver.players) do
        local p = entry.profile
        local has_profile = p ~= nil and p.n >= 1
        if steam_key(key) and (#entry.results > 0 or has_profile or entry.angles ~= nil) then
            local states = {}
            for state, list in pairs(entry.states) do
                states[state] = copy(list)
            end
            local angles
            if entry.angles ~= nil then
                angles = {}
                for slot, list in pairs(entry.angles) do
                    angles[slot] = {}
                    for c, o in ipairs(list) do
                        angles[slot][c] = { o[1], o[2] }
                    end
                end
            end
            data.resolver[key] = { name = entry.name, results = copy(entry.results), states = states,
                hits = entry.hits, misses = entry.misses, angles = angles,
                profile = has_profile and { n = p.n, jitter = p.jitter, static = p.static, spin = p.spin,
                    xway = p.xway or 0, random = p.random or 0, def = p.def, fd = p.fd } or nil }
        end
    end
    persist.saved = now
    if type(database) == "table" and pcall(database.write, persist.key, data) then
        persist.dirty = false
    end
end

-- Kalici kisi profili ve aci sonuclari (bozuk / eski veri atlanir).
persist.stored_profile = function(p)
    if type(p) ~= "table" then
        return nil
    end
    local out = {}
    for _, field in ipairs({ "n", "jitter", "static", "spin", "xway", "random", "def", "fd" }) do
        local v = p[field]
        if v == nil and (field == "xway" or field == "random") then
            v = 0
        end
        if not finite(v) or v < 0 or v > 1000 then
            return nil
        end
        out[field] = v
    end
    return out.n >= 1 and out or nil
end

persist.states = { "Standing", "Moving", "Slow walk", "Crouch", "Air", "Fakeduck" }

persist.stored_angles = function(a)
    if type(a) ~= "table" then
        return nil
    end
    local states = {}
    for _, state in ipairs(persist.states) do
        states[state] = true
    end
    local patterns = { jitter = true, static = true, spin = true, xway = true, random = true, unknown = true }
    local walls = { side = true, lby = true, open = true }
    local out, any = {}, false
    for slot, list in pairs(a) do
        local state, pattern, wall = tostring(slot):match("^([^|]+)|(%a+)|(%a+)$")
        if state ~= nil and states[state] and patterns[pattern] and walls[wall] and type(list) == "table" then
            local clean = {}
            for c = 1, hypothesis.candidates do
                local o = list[c]
                local heads, misses = type(o) == "table" and o[1] or nil, type(o) == "table" and o[2] or nil
                if finite(heads) and finite(misses) and heads >= 0 and heads <= 20 and misses >= 0 and misses <= 40 then
                    clean[c] = { floor(heads), floor(misses) }
                else
                    clean[c] = { 0, 0 }
                end
            end
            out[slot], any = clean, true
        end
    end
    return any and out or nil
end

local function stored_window(list)
    local out = {}
    if type(list) == "table" then
        for i = max(1, #list - K.RESOLVER_WINDOW + 1), #list do
            if list[i] == "c" or list[i] == "h" then
                out[#out + 1] = list[i]
            end
        end
    end
    return out
end

persist.load = function()
    if type(database) ~= "table" then
        return 0
    end
    local ok, data = pcall(database.read, persist.key)
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
            if count < K.MEMORY_LIMIT and steam_key(key) and type(e) == "table" and finite(e.base)
                and e.base >= 0 and e.base <= #BRUTE_PHASES and e.base == floor(e.base) then
                brute.enemies[key] = { stage = 0, time = 0, base = e.base, learned = true, name = tostring(e.name or "?"),
                    seen = 0 }
                add(key)
            end
        end
    end
    -- v2 (V1.0.15): govde isabetleri de sayiliyor; eski (govdesiz, HS'yi iyi gosteren) sayilar alinmaz.
    if type(data.sniper) == "table" and data.sniper.v == 2 then
        for _, mode in ipairs({ "hs", "dt" }) do
            local e = data.sniper[mode]
            if type(e) == "table" and finite(e.shots) and finite(e.hits)
                and e.hits >= 0 and e.hits <= e.shots and e.shots <= 1000 then
                sniper.stats[mode] = { shots = e.shots, hits = e.hits }
            end
        end
        sniper.choice = "dt"
        sniper.choice = sniper.decide()
    end
    for _, grp_name in ipairs(brute.groups) do
        local groups = type(data.phase_groups) == "table" and data.phase_groups or nil
        local list = groups ~= nil and (groups[grp_name] or groups[brute.migrate[grp_name]]) or data.phases
        if type(list) == "table" then
            for phase = 0, #BRUTE_PHASES do
                local e = list[phase + 1]
                if type(e) == "table" and finite(e.shots) and finite(e.hits)
                    and e.hits >= 0 and e.hits <= e.shots and e.shots <= 1000 then
                    brute.phases[grp_name][phase] = { shots = e.shots, hits = e.hits }
                end
            end
            brute.default[grp_name] = 0
            brute.default[grp_name] = brute_default(grp_name)
        end
    end
    if type(data.resolver) == "table" then
        for key, e in pairs(data.resolver) do
            if (players[key] or count < K.MEMORY_LIMIT) and steam_key(key) and type(e) == "table" then
                local entry = { results = stored_window(e.results), states = {}, name = tostring(e.name or "?"), seen = 0 }
                for _, field in ipairs({ "hits", "misses" }) do
                    local n = e[field]
                    if finite(n) and n >= 0 and n <= 100000 then
                        entry[field] = floor(n)
                    end
                end
                if type(e.states) == "table" then
                    for _, state in ipairs(persist.states) do
                        local list = stored_window(e.states[state])
                        if #list > 0 then
                            entry.states[state] = list
                        end
                    end
                end
                entry.profile, entry.angles = persist.stored_profile(e.profile), persist.stored_angles(e.angles)
                if #entry.results > 0 or entry.profile ~= nil or entry.angles ~= nil then
                    entry.remembered = true
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
    sniper.choice = "dt"
    resolver.players, resolver.shots, resolver.aim_target, resolver.prior_logged = {}, {}, nil, {}
    resolver.jittery, resolver.stalls = {}, {}
    hypothesis.store = {}
    pending_misses = {}
    if type(database) == "table" then
        pcall(database.write, persist.key, nil)
    end
    persist.dirty = false
end

listen("round_start", protect("round_start", function()
    own.summary()
    own.shot_summary()
    reset_brute()
    exposure.shot = nil
    ai_peek.reset()
    pending_misses = {}
    recharge.held = false
    persist.save(false)
end))

-- Harita degisince slot numaralari degisir; Steam ID ile ogrenilenler korunur. Oyuncu listesi ezmeleri
-- geri verilir (HvH sunucularinda oyuncular haritalar arasi kalir; slotu degisen oyuncuya varsayilan yazilir).
listen("level_init", protect("level_init", function()
    reset_brute()
    pending_misses = {}
    -- Yeni harita yeni oturum: Force icin yine bu haritada bir resolver iskasi gerekir; hafizadan taninan
    -- dusmanlar yeni haritada yine bir kez yazilir.
    for _, entry in pairs(resolver.players) do
        entry.fresh, entry.announced, entry.verified = nil, nil, nil
    end
    resolver.held = { total = 0, enemies = {} }
    hypothesis.wall.cache = {}
    resolver.shots, resolver.aim_target, resolver.prior_logged, resolver.jittery = {}, nil, {}, {}
    resolver.stalls, resolver.body_stalls, resolver.open_cache = {}, {}, {}
    exposure.shot, exposure.duel = nil, nil
    ai_peek.reset()
    teleport.reset()
    enemy_watch.list = {}
    plist_reset(false)
    charge.base = nil
    persist.save(true)
end))

local function count_kd(field)
    local entry = aim_stats.kd[current.state]
    if entry == nil then
        entry = { kills = 0, deaths = 0 }
        aim_stats.kd[current.state] = entry
    end
    entry[field] = entry[field] + 1
end

listen("player_death", protect("player_death", function(e)
    local lp = local_player()
    if lp == nil then
        return
    end
    local victim, attacker = userid_index(e.userid), userid_index(e.attacker)
    if victim == lp then
        if on(menu.enabled) and attacker ~= nil and attacker ~= lp and is_enemy(attacker) then
            count_kd("deaths")
            -- Sniper "sadece kafa" kuraliyla ates etmeden beklerken olduysen ogrenilir (bkz. resolver.held).
            local since_shot = realtime() - own.last_shot
            if current.head_only and (since_shot < 0 or since_shot > 1.5) then
                resolver.held_death(attacker)
            end
        end
        reset_brute()
        recharge.held = false
        ai_peek.reset()
    elseif attacker == lp and victim ~= nil and on(menu.enabled) and is_enemy(victim) then
        count_kd("kills")
    end
end))

-- Trash talk (NYKLE Yaw'daki killsay / deathsay cumlelerinin birebir Ingilizcesi). Oldurunce ve / veya olunce
-- rastgele bir cumle seti yazilir; her satir uzunluguna gore gecikmeli gider (NYKLE Yaw'daki gibi). Ayarlar:
-- Misc -> Trash talk (oldurunce, olunce, sadece headshot kill, olasilik, tum chat / takim chati, gecikme).
-- Bir set bitmeden yenisi baslamaz (chat dolmasin).
do
    local KILL_LINES = {
        { "1", "How smart are you, fuck." },
        { "Sleep, fuck you", "sleep, you dickhead." },
        { "Holy fuck", "look at this player." },
        { "1-0 loser", "that was easy." },
        { "Where are you going", "you fucking brat?" },
        { "Nice anti-aim dickhead", "did you work hard on it?" },
        { "Whoa what was that", "how did I kill you, man?" },
        { "NYKLE is superior to all of them, fuck." },
        { "What a brilliant mind", "you idiot." },
        { "1-0 loser", "you're miserable without NYKLE." },
        { "Lol", "how hard did I fuck you though." },
        { "What Lua are you using, man?" },
        { "Whose CFG are you using, man?" },
        { "Nice brain", "dickhead." },
        { "Hahahaha", "look how you died." },
        { "Oh man", "holy fuck", "nice fucking CFG." },
        { "Oh", "I was AFK tweaking my cheat hahahaha." },
        { "What a cringe nickname you have, man." },
        { "Weeb dickhead", "you thought I wouldn't kill you?" },
        { "Fucking loser", "who are you trying to kill?" },
        { "Are you raging because you play bad?", "Hahaha idiot." },
        { "Learn while I'm still alive, moron." },
        { "Stupid dude", "turn your monitor on, fuck." },
        { "1", "dead again, loser." },
        { "Ez", "oops", "sorry, fuck." },
        { "Hahaha how I fucked you." },
        { "Big brain", "you straight up threw." },
        { "That was easy, bitch", "what the fuck happened?" },
        { "Take this, motherfucker", "fuck off." },
        { "I don't even care", "fuck off, idiot." },
        { "Easy, loser", "I'm laughing at you, what a funny guy you are." },
        { "Crushed easily", "weak dog and rat." },
        { "Holy fuck, what an easy bot you are." },
        { "1", "am I not replying?", "I don't give a fuck." },
        { "I don't even give a fuck about you", "bot." },
        { "Moron", "a plain fucking bot." },
        { "\226\153\149 N Y K L E > A L L \226\153\149" },
        { "Get NYKLE for skeet, you fucking loser." },
    }

    local DEATH_LINES = {
        { "Holy fuck what a shitty thing I bought", "wish I had bought NYKLE, fuck." },
        { "Ew", "dickhead." },
        { "What are you doing", "you messed-up loser?" },
        { "Fuck", "did I even shoot?" },
        { "The cheat shat itself." },
        { "HOLY FUCK", "you pissed me off so much." },
        { "Why did you do that", "should've given me a clip", "look at this clown, fuck." },
        { "Ahahaha", "yeah", "the son of a bitch killed me again, stupid dude." },
        { "Huh", "I see", "nice cheat." },
        { "Fuck", "which jitter should I turn on, man?" },
        { "Ew", "filthy dude", "fuck you." },
        { "Fuck", "where are my teammates", "they piss me off so much." },
        { "Fuck", "missed again." },
        { "Fuck", "hello", "am I going to shoot or what?" },
        { "Heh", "did you even get how you killed me?" },
        { "Fuck", "that fucking desync thing again." },
        { "Fuck", "the client froze", "you're lucky." },
        { "I see", "how do you even play", "you idiot?" },
        { "Fuck", "the guy just walked straight", "holy fuck." },
        { "What is this", "where did you kill me from?" },
        { "Fucked", "fuck you", "WHAT ARE YOU DOING MAN?" },
        { "What can I say", "dickhead", "you play well." },
        { "Fucking guy", "you pissed me off so much", "what are you doing?" },
        { "You're shit without skeet", "how are you killing me with that pasted cheat?" },
        { "Beer-drinking fucker", "how did you beat me?" },
        { "Fuck", "I admit it, you beat me." },
        { "How are you killing me", "fucking owosh?" },
        { "Defectus what are you doing man", "holy fuck." },
        { "Weeb dickhead", "how are you killing me", "holy fuck." },
        { "Fuck bro", "look at my team", "it's a disgrace, man." },
        { "The useless dickheads on my team." },
        { "Fuck off, bitch." },
        { "Fucking scumbag", "why do you piss me off so much?" },
        { "Fuck", "shot in the back again." },
        { "Is this all you're good at, man", "motherfucker?" },
        { "Why do you keep talking shit to me", "bitch?" },
        { "You got lucky", "what's next, dickhead?" },
        { "Fucking scumbag", "ruined everything." },
        { "My God", "look at this miserable scum." },
        { "Hahaha fuck", "the cheat has a good freestand." },
        { "Fuck, I'm sick of you." },
        { "Not bad." },
        { "Good tracking", "scumbag." },
        { "What happened", "hide shots on fake duck doesn't work anymore?" },
    }

    local talk = { busy_until = -1000 }

    -- Konsol komutunu bozabilecek karakterler cikarilir.
    local function clean(line)
        return (tostring(line):gsub("[\";\r\n]", ""))
    end

    local function send(line)
        if not on(menu.enabled) or not on(menu.trash_talk) or local_player() == nil then
            return
        end
        local command = menu.tt_chat ~= nil and menu.tt_chat:get() == "Team chat" and "say_team " or "say "
        pcall(client.exec, command .. clean(line))
    end

    -- per_char: NYKLE Yaw'daki bolen (oldurunce 24, olunce 20).
    local function speak(lines, per_char)
        local now = realtime()
        if now >= talk.busy_until - 30 and now < talk.busy_until then
            return
        end
        local chance = menu.tt_chance ~= nil and menu.tt_chance:get() or 100
        if random(1, 100) > chance then
            return
        end
        local base = (menu.tt_delay ~= nil and menu.tt_delay:get() or 23) / 10
        local block = lines[random(1, #lines)]
        local delay = 0
        for _, line in ipairs(block) do
            delay = delay + #line / per_char * base
            pcall(client.delay_call, delay, send, line)
        end
        talk.busy_until = now + delay + 0.5
    end

    listen("player_death", protect("trash_talk", function(e)
        if not on(menu.enabled) or not on(menu.trash_talk) then
            return
        end
        local lp = local_player()
        if lp == nil then
            return
        end
        local victim, attacker = userid_index(e.userid), userid_index(e.attacker)
        if attacker == lp and victim ~= nil and victim ~= lp and is_enemy(victim) then
            if on(menu.tt_kill) and (not on(menu.tt_headshot) or e.headshot == true or e.headshot == 1) then
                speak(KILL_LINES, 24)
            end
        elseif victim == lp and attacker ~= nil and attacker ~= lp then
            if on(menu.tt_death) then
                speak(DEATH_LINES, 20)
            end
        end
    end))
end

-- Clan tag (NYKLE Yaw'dan): "Nykle.win" harf harf yazilir (N, Ny, ... Nykle.win), her kare 0.45 sn, tam ad
-- 1.2 sn tutulur. Acikken GameSense'in kendi "Clan tag spammer"i kapatilir; kapatinca / unload'da eski
-- etiket geri yazilir (Steam grubunun etiketi gamesense/steamworks varsa okunur, yoksa etiket bosaltilir).
do
    local clantag = {}
    local TEXT, FRAME_TIME, HOLD_TIME = "Nykle.win", 0.45, 1.2
    local FRAMES = {}
    for i = 1, #TEXT do
        FRAMES[i] = TEXT:sub(1, i)
    end
    local state = { active = false, frame = #FRAMES, next_at = 0, shown = nil, original = "" }

    local function original_tag()
        local ok, steamworks = pcall(require, "gamesense/steamworks")
        local friends = ok and type(steamworks) == "table" and steamworks.ISteamFriends or nil
        local clan_id = try(function()
            return cvar.cl_clanid:get_int()
        end)
        if friends == nil or not finite(clan_id) or clan_id == 0 then
            return ""
        end
        local count = try(friends.GetClanCount)
        for i = 0, (finite(count) and count or 0) - 1 do
            local group_id = try(friends.GetClanByIndex, i)
            if group_id ~= nil and group_id == clan_id then
                local tag = try(friends.GetClanTag, group_id)
                return type(tag) == "string" and tag or ""
            end
        end
        return ""
    end

    local function set_tag(text)
        if text == state.shown then
            return true
        end
        if not pcall(client.set_clan_tag, text) then
            return false
        end
        state.shown = text
        return true
    end

    clantag.restore = function()
        if state.active then
            state.active = false
            pcall(client.set_clan_tag, state.original or "")
            state.shown = nil
        end
        override("clantag_spammer", nil)
    end

    clantag.step = function()
        if not on(menu.enabled) or not on(menu.clantag) then
            clantag.restore()
            return
        end
        override("clantag_spammer", false)
        if not state.active then
            state.active = true
            state.original = original_tag()
            state.frame, state.next_at, state.shown = #FRAMES, 0, nil
        end
        local now = realtime()
        -- Once tam ad gosterilir ve harflerden daha uzun tutulur; realtime geri giderse (harita) hemen yazilir.
        if now >= state.next_at or state.next_at - now > HOLD_TIME + 1 then
            if not set_tag(FRAMES[state.frame]) then
                return
            end
            state.next_at = now + (state.frame == #FRAMES and HOLD_TIME or FRAME_TIME)
            state.frame = state.frame % #FRAMES + 1
        end
    end

    -- Sunucuya baglaninca animasyon bastan (tam ad) baslar.
    clantag.reset = function()
        state.shown, state.next_at, state.frame = nil, 0, #FRAMES
    end

    -- NYKLE Yaw gibi: paket gonderilen tick'te (chokedcommands 0) ve iki tick'te bir paint'te.
    listen("run_command", protect("clan tag", function(e)
        if local_player() ~= nil and e ~= nil and e.chokedcommands == 0 then
            clantag.step()
        end
    end))
    listen("paint", protect("clan tag", function()
        if local_player() ~= nil and tickcount() % 2 == 0 then
            clantag.step()
        elseif state.active and not (on(menu.enabled) and on(menu.clantag)) then
            clantag.restore()
        end
    end))
    listen("player_connect_full", protect("clan tag", function(e)
        if e ~= nil and userid_index(e.userid) == local_player() then
            clantag.reset()
        end
    end))
    listen("shutdown", protect("clan tag", clantag.restore))
end

-- Config kaydedilirken GameSense ayarlarinin senin degerleri kaydedilir (ezmeler geri verilir, sonraki tick
-- yeniden uygulanir). Config yuklenince ezmeler unutulur ve onerilen ayarlar yeniden kontrol edilir.
listen("pre_config_save", protect("pre_config_save", function()
    reset_overrides()
end))
listen("pre_config_load", protect("pre_config_load", function()
    reset_overrides()
end))
listen("post_config_load", protect("post_config_load", function()
    forget_overrides()
    recommended_state.pending, recommended_state.report_off = true, true
    pcall(update_visibility)
end))

-------------------------------------------------------------------------------
-- Detayli log (V1.0.10; Home > Console > "Detailed log (for analysis)", varsayilan acik)
-------------------------------------------------------------------------------
-- Oyun loglarindan gelistirmek icin "dbg" satirlari. Konum: @YerAdi(x,y,z) (haritadaki bolge adi ve
-- koordinat), mesafe birim (1 m ~ 52 birim), h = yukseklik farki (+ = dusman ustte), v = yatay hiz,
-- bak = dusmanin yaw'inin sana gore acisi (0 = sana bakiyor, 180 = arkasi donuk), lby = LBY ile yaw farki,
-- p = pitch. Kayit: DEF geri Nt = sahte (defensive) kayit, bogma N = paket bogma, AA deseni, resolver seviyesi.
--  dbg atis-detay:    her atis sonucunun altinda: hedefin konumu, kaydi, plist, aimbot bayraklari, sen.
--  dbg sikmadi:       dusmana mermi gecerken 0.4 sn ates yoksa bir kez: tahmini hasar, MD, silah, sebep.
--  dbg duello:        bir dusmanla karsilasma bitince: kim once gordu, defensive suresi, hiz, atislar.
--  dbg vurulma-detay / olum-detay / kill-detay: konumlar, mesafe, duvardan mi, son iki atisi arasi (DT).
--  dbg def ozeti:     round sonunda dusman basina defensive sayisi ve suresi.
--  dbg sen ozeti:     round sonunda senin tarafin: zorlanan defensive tick'i, defensive'i goren olcumler
--                     (setup_command / predict_command / net_update tickbase; zorlanip gorulen), teleportlar
--                     ve sonrasi vurulma.
--  dbg round / harita / ayarlar: baslik satirlari.
do
-- min_damage: bundan az hasar (cok duvar arkasi, 1-4 hasar) "vurulabilir" sayilmaz.
local D = { vis = {}, duel = {}, def = {}, round_def = {}, last_def = {}, shots = {}, scan_tick = -1000,
    every = 4, see_after = 0.4, vis_gap = 16, duel_gap = 48, sight_hold = 12, refs = {}, min_damage = 10,
    my = nil, tb = { net_max = 0, net = false } }

D.on = function()
    return on(menu.enabled) and on(menu.debug_log)
end

D.short = function(class)
    if type(class) ~= "string" then
        return "?"
    end
    if class == "Revolver" then
        return "r8"
    end
    return (class:gsub("^CWeapon", ""):gsub("^C", ""):lower())
end

D.norm = function(yaw)
    return (yaw + 180) % 360 - 180
end

-- GameSense menu ayari (yol bulunamazsa "?").
D.setting = function(tab, box, name)
    local key = tab .. ">" .. box .. ">" .. name
    local ref = D.refs[key]
    if ref == nil then
        local ok, found = pcall(ui.reference, tab, box, name)
        ref = (ok and found ~= nil) and found or false
        D.refs[key] = ref
    end
    if ref == false then
        return "?"
    end
    local ok, value = pcall(ui.get, ref)
    if not ok or value == nil then
        return "?"
    end
    return tostring(value)
end

D.ping = function(ent)
    local res = try(entity.get_player_resource)
    local ping = res ~= nil and prop(res, "m_iPing", ent) or nil
    return finite(ping) and ping or nil
end

-- Konum, mesafe, hareket, bakis, can, silah, ping. lp verilmezse mesafe / bakis yazilmaz.
D.where = function(ent, lp)
    local o = origin_of(ent)
    if o == nil then
        return "@?"
    end
    local place = prop(ent, "m_szLastPlaceName")
    local parts = { ("@%s(%d,%d,%d)"):format((type(place) == "string" and place ~= "") and place or "?",
        round(o.x), round(o.y), round(o.z)) }
    local mine = (lp ~= nil and lp ~= ent) and origin_of(lp) or nil
    if mine ~= nil then
        local dx, dy, dz = o.x - mine.x, o.y - mine.y, o.z - mine.z
        parts[#parts + 1] = ("%du h%+d"):format(round(sqrt(dx * dx + dy * dy + dz * dz)), round(dz))
    end
    local v = velocity_of(ent)
    parts[#parts + 1] = ("v%d"):format(round(sqrt(v.x * v.x + v.y * v.y)))
    if not on_ground(ent) then
        parts[#parts + 1] = ("havada vz%+d"):format(round(v.z))
    end
    local duck = prop(ent, "m_flDuckAmount")
    if finite(duck) and duck > 0.05 then
        parts[#parts + 1] = ("duck%d"):format(round(duck * 100))
    end
    if mine ~= nil then
        local pitch, yaw = prop(ent, "m_angEyeAngles")
        if finite(yaw) then
            local to_me = math.deg(atan2(mine.y - o.y, mine.x - o.x))
            parts[#parts + 1] = ("bak%+d"):format(round(D.norm(yaw - to_me)))
            local lby = prop(ent, "m_flLowerBodyYawTarget")
            if finite(lby) then
                parts[#parts + 1] = ("lby%+d"):format(round(D.norm(lby - yaw)))
            end
        end
        if finite(pitch) then
            parts[#parts + 1] = ("p%d"):format(round(pitch))
        end
    end
    local hp = prop(ent, "m_iHealth")
    if finite(hp) then
        parts[#parts + 1] = ("hp%d"):format(round(hp))
    end
    parts[#parts + 1] = D.short(weapon_class(ent))
    local ping = D.ping(ent)
    if ping ~= nil then
        parts[#parts + 1] = ("ping%d"):format(round(ping))
    end
    return table.concat(parts, " ")
end

-- Dusmanin kaydi: sahte kayit (defensive), bogma, LC, fake duck, AA deseni, resolver seviyesi.
D.rec = function(ent)
    local t = enemy_watch.list[ent]
    if t == nil then
        return "kayit ?"
    end
    local parts = {}
    if t.sim < t.max_sim then
        parts[#parts + 1] = ("DEF geri %dt"):format(round((t.max_sim - t.sim) / tick_interval()))
    else
        local last, now = D.last_def[ent], tickcount()
        if last ~= nil and now >= last and now - last <= 64 then
            parts[#parts + 1] = ("def %dt once bitti"):format(now - last)
        end
    end
    if finite(t.step) then
        parts[#parts + 1] = t.step > 0 and ("bogma %d"):format(t.step - 1) or ("adim %d"):format(t.step)
    end
    local profile = enemy_watch.profile(ent)
    if profile ~= nil then
        if profile.lc then
            parts[#parts + 1] = "LC"
        end
        if profile.fakeduck then
            parts[#parts + 1] = "FD"
        end
        parts[#parts + 1] = ("AA %s%s"):format(profile.pattern or "?",
            profile.jitter ~= nil and ("/%d"):format(round(profile.jitter)) or "")
    end
    local key = player_id(ent)
    local entry = key ~= nil and resolver.players[key] or nil
    if entry ~= nil then
        parts[#parts + 1] = ("seviye %d"):format(entry_level(entry, enemy_state(ent)))
    end
    return #parts > 0 and table.concat(parts, " ") or "kayit normal"
end

D.plist = function(ent)
    local parts = {}
    local sp, ba = plist_get(ent, PL.SAFE), plist_get(ent, PL.BODY)
    if sp ~= nil and sp ~= "-" then
        parts[#parts + 1] = "SP " .. tostring(sp)
    end
    if ba ~= nil and ba ~= "-" then
        parts[#parts + 1] = "BA " .. tostring(ba)
    end
    if plist_get(ent, PL.FORCE) == true then
        parts[#parts + 1] = "BY " .. tostring(plist_get(ent, PL.VALUE))
    end
    if plist_get(ent, PL.WHITELIST) == true then
        parts[#parts + 1] = "WHITELIST"
    end
    return #parts > 0 and ("plist " .. table.concat(parts, " ")) or "plist -"
end

-- Senin durumun: konum, AA durumu, manual / FS / peek tusu, exploit.
D.me = function(lp)
    local parts = { "ben " .. D.where(lp, nil), current.state }
    if manual.dir ~= "Off" then
        parts[#parts + 1] = "manual " .. manual.dir
    end
    if current.freestand then
        parts[#parts + 1] = "FS"
    end
    if peek_key_held() then
        parts[#parts + 1] = "peek tusu"
    end
    parts[#parts + 1] = exploit_status()
    return table.concat(parts, " | ")
end

D.ready = function(lp)
    local weapon = weapon_of(lp)
    if weapon == nil then
        return "silah ?"
    end
    local clip = prop(weapon, "m_iClip1")
    if finite(clip) and clip == 0 then
        return "sarjor bos"
    end
    local next_attack, player_next = prop(weapon, "m_flNextPrimaryAttack"), prop(lp, "m_flNextAttack")
    local wait = max(finite(next_attack) and next_attack or 0, finite(player_next) and player_next or 0) - curtime()
    if wait > 0.02 then
        return ("silah %.2fs sonra hazir"):format(wait)
    end
    local scoped = prop(lp, "m_bIsScoped")
    return "silah hazir" .. ((SNIPERS[current.weapon] and (scoped == 0 or scoped == false)) and " (durbun kapali)" or "")
end

-- Ates aninda (aim_fire): sonuc satirinin altina yazilir.
D.fire_info = function(e, target)
    local lp = local_player()
    local function num(name)
        local ok, v = pcall(function() return e[name] end)
        return (ok and finite(v)) and v or nil
    end
    local flags = {}
    local bt, hc, z = num("backtrack"), num("hit_chance"), num("z")
    if bt ~= nil then
        flags[#flags + 1] = ("bt %dt"):format(round(bt))
    end
    if hc ~= nil then
        flags[#flags + 1] = ("hc %d%%"):format(round(hc))
    end
    for _, name in ipairs({ "teleported", "extrapolated", "interpolated", "high_priority" }) do
        if e[name] == true then
            flags[#flags + 1] = name
        end
    end
    local o = origin_of(target)
    if z ~= nil and o ~= nil then
        flags[#flags + 1] = ("nisan z%+d"):format(round(z - o.z))
    end
    return ("[%s] dbg atis-detay: %s %s | %s | %s | aimbot %s | %s"):format(SCRIPT, player_name(target),
        D.where(target, lp), D.rec(target), D.plist(target), #flags > 0 and table.concat(flags, " ") or "-",
        lp ~= nil and D.me(lp) or "ben ?")
end

D.no_shot = function(enemy, v, lp, now)
    local reasons = {}
    local md = active_min_damage()
    local best = max(v.dh or 0, v.db or 0)
    if D.setting("RAGE", "Aimbot", "Enabled") == "false" then
        reasons[#reasons + 1] = "rage kapali"
    end
    if current.head_only then
        reasons[#reasons + 1] = "sniper kurali: sadece oldurecek atis"
    end
    if finite(md) and best < md then
        reasons[#reasons + 1] = ("hasar %d < MD %d"):format(round(best), round(md))
    end
    if (v.dh or 0) <= 0 then
        reasons[#reasons + 1] = "kafa kapali"
    end
    if v.other > 0 then
        reasons[#reasons + 1] = ("aimbot baska hedefe %d ates"):format(v.other)
    end
    local t = enemy_watch.list[enemy]
    if t ~= nil and t.sim < t.max_sim then
        reasons[#reasons + 1] = "onun kaydi sahte (DEF)"
    end
    if not on_ground(lp) then
        reasons[#reasons + 1] = "sen havadasin"
    elseif fd_on() then
        reasons[#reasons + 1] = "fake duck (ates sadece kalkarken)"
    elseif speed2d(lp) > 100 then
        reasons[#reasons + 1] = ("sen hareketlisin v%d (isabet sansi)"):format(round(speed2d(lp)))
    end
    if not weapon_ready(lp, 0) then
        reasons[#reasons + 1] = "silah hazir degil"
    end
    return ("[%s] dbg sikmadi: %s %.2fs vurulabilir (kafa %d, govde %d hasar), ates yok | %s | MD %s hc %s | %s | %s | %s | %s | %s"):format(
        SCRIPT, player_name(enemy), (now - v.first) * tick_interval(), round(v.dh or 0), round(v.db or 0),
        #reasons > 0 and table.concat(reasons, ", ") or "sebep bilinmiyor", finite(md) and tostring(round(md)) or "?",
        D.setting("RAGE", "Aimbot", "Minimum hit chance"), D.ready(lp), D.where(enemy, lp), D.rec(enemy),
        D.plist(enemy), D.me(lp))
end

-- Gozunden dusmanin kafasina / govdesine mermi geciyor mu (her every tick'te bir).
D.scan = function(lp, now)
    local eye, class = eye_of(lp), current.weapon
    if eye == nil or class == nil or MELEE[class] or class == "CC4" or is_grenade(class) then
        return
    end
    -- Fake duck'ta aimbot ayakta goz yuksekliginden sikar (egik gozden iz atmak yanlis "vuramiyordun" verir).
    local base = fd_on() and origin_of(lp) or nil
    if base ~= nil and eye.z < base.z + 64 then
        eye = vector(eye.x, eye.y, base.z + 64)
    end
    for _, enemy in ipairs(enemy_list()) do
        local head = hitbox_of(enemy, 0)
        local dh = head ~= nil and bullet_damage(lp, eye, head, enemy) or nil
        local db = nil
        for _, hitbox in ipairs({ 5, 3 }) do
            local point = hitbox_of(enemy, hitbox)
            local d = point ~= nil and bullet_damage(lp, eye, point, enemy) or nil
            if d ~= nil and (db == nil or d > db) then
                db = d
            end
            if db ~= nil and db > 0 then
                break
            end
        end
        local v = D.vis[enemy]
        if (dh or 0) >= D.min_damage or (db or 0) >= D.min_damage then
            if v == nil or now < v.last or now - v.last > D.vis_gap then
                v = { first = now, last = now, fired = 0, other = 0, logged = false }
                D.vis[enemy] = v
            end
            v.last, v.dh, v.db = now, dh or 0, db or 0
            if not v.logged and v.fired == 0 and (now - v.first) * tick_interval() >= D.see_after then
                v.logged = true
                print(D.no_shot(enemy, v, lp, now))
            end
        elseif v ~= nil and (now < v.last or now - v.last > D.vis_gap) then
            D.vis[enemy] = nil
        end
    end
end

D.open = function(enemy, lp, now)
    local E = D.duel[enemy]
    if E == nil then
        E = { start = now, last = now, ticks = 0, name = player_name(enemy), where = D.where(enemy, lp), def_ticks = 0,
            def_n = 0, in_def = false, top = 0, air = false, his_shots = 0, his_hits = 0, his_dmg = 0, our_shots = 0,
            our_hits = 0 }
        D.duel[enemy] = E
    end
    return E
end

D.close = function(enemy, result)
    local E = D.duel[enemy]
    if E == nil then
        return
    end
    D.duel[enemy] = nil
    local ti = tick_interval()
    local first
    if E.he ~= nil and E.we ~= nil then
        local diff = (E.we - E.he) * ti
        first = abs(diff) < 0.02 and "ayni anda" or (diff > 0 and ("o %.2fs once"):format(diff) or ("sen %.2fs once"):format(-diff))
    elseif E.he ~= nil then
        first = "sadece o gordu"
    elseif E.we ~= nil then
        first = "sadece sen gordun"
    else
        first = "?"
    end
    print(("[%s] dbg duello: %s %s | %.2fs | ilk goren: %s | def %d kez %dt (%%%d) | hiz max %d%s | o: %d ates %d isabet -%d | sen: %d ates %d isabet | %s"):format(
        SCRIPT, E.name, E.where, max(1, E.last - E.start) * ti, first, E.def_n, E.def_ticks,
        round(100 * E.def_ticks / max(1, E.ticks)), round(E.top), E.air and ", havada" or "", E.his_shots, E.his_hits,
        round(E.his_dmg), E.our_shots, E.our_hits, result))
end

D.close_all = function(result)
    for enemy in pairs(D.duel) do
        D.close(enemy, result)
    end
end

-- Her tick: dusmanlarin defensive bolumleri ve duellolar.
-- Defensive bolumu biter: sure bolumun son goruldugu tick'e kadar (dormant'ta gecen sure sayilmaz).
D.end_def = function(enemy, ep, now)
    D.def[enemy], D.last_def[enemy] = nil, now
    local r = D.round_def[ep.name] or { n = 0, ticks = 0, longest = 0, moving = 0 }
    D.round_def[ep.name] = r
    local length = max(1, ep.last - ep.start + 1)
    r.n, r.ticks, r.longest = r.n + 1, r.ticks + length, max(r.longest, length)
    if ep.speed >= 100 then
        r.moving = r.moving + 1
    end
end

-- Senin tarafin (round boyunca): zorlanan defensive ve uc ayri olcumle gorulen defensive tick'leri,
-- teleportlar ve teleporttan sonraki 1.5 sn icinde vurulma.
D.mine = function()
    local m = D.my
    if m == nil then
        m = { ticks = 0, forced = 0, setup = 0, pred = 0, both = 0, net = 0, dt = 0, tp = 0, tp_hit = 0,
            tp_last = teleport.last }
        D.my = m
    end
    return m
end

D.track = function(lp, now)
    local m = D.mine()
    m.ticks = m.ticks + 1
    m.forced = m.forced + (current.forced and 1 or 0)
    local pred = tickbase.predicted()
    m.setup = m.setup + ((tickbase.left > 0 or tickbase.jump) and 1 or 0)
    m.pred = m.pred + (pred and 1 or 0)
    m.both = m.both + ((pred and current.forced) and 1 or 0)
    m.net = m.net + (D.tb.net and 1 or 0)
    m.dt = m.dt + (dt_on() and 1 or 0)
    if teleport.last ~= m.tp_last then
        m.tp_last, m.tp = teleport.last, m.tp + 1
    end
    local present = {}
    for _, enemy in ipairs(enemy_list()) do
        local t = enemy_watch.list[enemy]
        local in_def = t ~= nil and t.sim < t.max_sim
        present[enemy] = true
        local ep = D.def[enemy]
        if in_def and ep == nil then
            D.def[enemy] = { start = now, last = now, speed = speed2d(enemy), name = player_name(enemy) }
        elseif in_def then
            ep.last = now
        elseif ep ~= nil then
            D.end_def(enemy, ep, now)
        end
        local s = exposure.sight[enemy]
        local sees = s ~= nil and now >= s.last and now - s.last <= D.sight_hold
        local v = D.vis[enemy]
        local we = v ~= nil and now >= v.last and now - v.last <= D.every * 2
        local E = D.duel[enemy]
        if E == nil and (sees or we) then
            E = D.open(enemy, lp, now)
        end
        if E ~= nil then
            E.ticks = E.ticks + 1
            if sees or we then
                E.last = now
            end
            if sees and E.he == nil then
                E.he = now
            end
            if we and E.we == nil then
                E.we = now
            end
            if in_def then
                E.def_ticks = E.def_ticks + 1
                if not E.in_def then
                    E.def_n = E.def_n + 1
                end
            end
            E.in_def = in_def
            E.top = max(E.top, speed2d(enemy))
            E.air = E.air or not on_ground(enemy)
        end
    end
    for enemy, ep in pairs(D.def) do
        if not present[enemy] then
            D.end_def(enemy, ep, now)
        end
    end
    for enemy, E in pairs(D.duel) do
        if now < E.last or now - E.last > D.duel_gap then
            D.close(enemy, "ayrildi")
        end
    end
end

-- net_update_end'de tickbase en yuksek degerinin 2+ tick gerisinde mi (NYKLE Yaw'in yeri; karsilastirma icin).
D.tb_check = function(field)
    local lp = local_player()
    local tb = lp ~= nil and prop(lp, "m_nTickBase") or nil
    if not finite(tb) then
        return
    end
    local key = field .. "_max"
    if abs(tb - D.tb[key]) > 64 then
        D.tb[key] = tb
    end
    D.tb[field] = D.tb[key] - tb >= 2
    D.tb[key] = max(D.tb[key], tb)
end

D.header = function()
    local rules = try(entity.get_game_rules)
    local played = rules ~= nil and prop(rules, "m_totalRoundsPlayed") or nil
    local lp = local_player()
    local team = lp ~= nil and prop(lp, "m_iTeamNum") or nil
    local latency = try(client.latency)
    return ("[%s] dbg ===== round %s | %s | sen %s | ping %s ====="):format(SCRIPT,
        finite(played) and tostring(round(played) + 1) or "?", tostring(try(globals.mapname) or "?"),
        team == 2 and "T" or (team == 3 and "CT" or "?"), finite(latency) and ("%dms"):format(round(latency * 1000)) or "?")
end

D.settings = function()
    return ("[%s] dbg ayarlar: tick %d | rage %s, hc %s, MD %s (%s) | DT %s, HS %s, DT fake lag %s | fake lag %s / %s | maxshift %s | lua: onerilen %s, sniper %s, auto exploit %s, gercek kayit bekle %s"):format(
        SCRIPT, round(1 / tick_interval()), D.setting("RAGE", "Aimbot", "Enabled"),
        D.setting("RAGE", "Aimbot", "Minimum hit chance"), tostring(get("min_damage")), tostring(get("weapon_type")),
        tostring(get("doubletap")), tostring(get("hideshots")), tostring(get("dt_fakelag")),
        D.setting("AA", "Fake lag", "Amount"), D.setting("AA", "Fake lag", "Limit"), tostring(get("maxshift")),
        tostring(on(menu.recommended)), tostring(menu.sniper_exploit ~= nil and menu.sniper_exploit:get() or "?"),
        tostring(on(menu.auto_exploit)), tostring(on(menu.wait_real)))
end

D.reset = function()
    D.vis, D.duel, D.def, D.round_def, D.last_def, D.shots, D.my = {}, {}, {}, {}, {}, {}, nil
end

listen("setup_command", protect("detailed log", function()
    if not D.on() then
        return
    end
    local lp = local_player()
    if lp == nil or not alive(lp) then
        return
    end
    local now = tickcount()
    if now < D.scan_tick or now - D.scan_tick >= D.every then
        D.scan_tick = now
        D.scan(lp, now)
    end
    D.track(lp, now)
end))

listen("net_update_end", protect("detailed log net_update_end", function()
    if D.on() then
        D.tb_check("net")
    end
end))

listen("aim_fire", protect("detailed log aim_fire", function(e)
    if not D.on() then
        return
    end
    local target = finite(e.target) and e.target or nil
    if target == nil then
        return
    end
    for enemy, v in pairs(D.vis) do
        if enemy == target then
            v.fired = v.fired + 1
        else
            v.other = v.other + 1
        end
    end
    local lp = local_player()
    if lp ~= nil then
        local now = tickcount()
        local E = D.open(target, lp, now)
        E.our_shots, E.last, E.we = E.our_shots + 1, now, E.we or now
    end
    local shot = e.id ~= nil and resolver.shots[e.id] or nil
    if shot ~= nil then
        shot.dbg = D.fire_info(e, target)
    end
end))

listen("aim_hit", protect("detailed log aim_hit", function(e)
    local E = finite(e.target) and D.duel[e.target] or nil
    if E ~= nil then
        E.our_hits = E.our_hits + 1
    end
end))

listen("weapon_fire", protect("detailed log weapon_fire", function(e)
    if not D.on() then
        return
    end
    local shooter = userid_index(e.userid)
    if shooter == nil or shooter == local_player() or not is_enemy(shooter) then
        return
    end
    local last = D.shots[shooter]
    D.shots[shooter] = { prev = last ~= nil and last.last or nil, last = realtime() }
    local E = D.duel[shooter]
    if E ~= nil then
        E.his_shots = E.his_shots + 1
    end
end))

listen("player_hurt", protect("detailed log player_hurt", function(e)
    if not D.on() then
        return
    end
    local lp = local_player()
    if lp == nil or userid_index(e.userid) ~= lp then
        return
    end
    local attacker = userid_index(e.attacker)
    if attacker == nil or attacker == lp or not is_enemy(attacker) or NON_BULLET_DAMAGE[tostring(e.weapon)] then
        return
    end
    local damage = tonumber(e.dmg_health) or 0
    local m = D.mine()
    local since_tp = realtime() - teleport.last
    if since_tp >= 0 and since_tp <= 1.5 then
        m.tp_hit = m.tp_hit + 1
    end
    local E = D.duel[attacker]
    if E ~= nil then
        E.his_hits, E.his_dmg = E.his_hits + 1, E.his_dmg + damage
    end
    local gap = ""
    local shots = D.shots[attacker]
    if shots ~= nil and shots.prev ~= nil and shots.last >= shots.prev and shots.last - shots.prev < 1 then
        local d = shots.last - shots.prev
        gap = (" | son iki atisi arasi %.2fs%s"):format(d, d < 0.2 and " (DT)" or "")
    end
    local v, now = D.vis[attacker], tickcount()
    local mine = "sen onu vuramiyordun"
    if v ~= nil and now >= v.last and now - v.last <= D.vis_gap then
        mine = ("sen onu %.2fs vurulabilir gordun, %d ates"):format((v.last - v.first) * tick_interval(), v.fired)
    end
    print(("[%s] dbg vurulma-detay: %s %s -%d %s | %s | %s%s | %s | %s"):format(SCRIPT, player_name(attacker),
        HITGROUPS[e.hitgroup] or "?", round(damage), tostring(e.weapon or "?"), D.where(attacker, lp), D.rec(attacker), gap,
        mine, D.me(lp)))
end))

listen("player_death", protect("detailed log player_death", function(e)
    if not D.on() then
        return
    end
    local lp = local_player()
    if lp == nil then
        return
    end
    local victim, attacker = userid_index(e.userid), userid_index(e.attacker)
    local function yes(v)
        return v == true or v == 1
    end
    local tags = {}
    if yes(e.headshot) then
        tags[#tags + 1] = "headshot"
    end
    if finite(e.penetrated) and e.penetrated > 0 then
        tags[#tags + 1] = ("duvardan (%d)"):format(e.penetrated)
    end
    if yes(e.noscope) then
        tags[#tags + 1] = "noscope"
    end
    if yes(e.thrusmoke) then
        tags[#tags + 1] = "smoke icinden"
    end
    if yes(e.attackerblind) then
        tags[#tags + 1] = "kor"
    end
    local tag = #tags > 0 and (" " .. table.concat(tags, ", ")) or ""
    if victim == lp then
        if attacker ~= nil and attacker ~= lp then
            print(("[%s] dbg olum-detay: %s %s%s | %s | %s | %s"):format(SCRIPT, player_name(attacker),
                tostring(e.weapon or "?"), tag, D.where(attacker, lp), D.rec(attacker), D.me(lp)))
            D.close(attacker, "oldun")
        end
        D.close_all("sen oldun")
        D.vis = {}
    elseif attacker == lp and victim ~= nil then
        print(("[%s] dbg kill-detay: %s %s%s | %s"):format(SCRIPT, player_name(victim), tostring(e.weapon or "?"), tag,
            D.where(victim, lp)))
        D.close(victim, "oldurdun")
    elseif victim ~= nil then
        D.close(victim, "baskasi oldurdu")
    end
end))

listen("round_end", protect("detailed log round_end", function(e)
    if not D.on() then
        return
    end
    local lp = local_player()
    local team = lp ~= nil and prop(lp, "m_iTeamNum") or nil
    local winner = tonumber(e.winner)
    print(("[%s] dbg round sonu: %s kazandi%s"):format(SCRIPT, winner == 2 and "T" or (winner == 3 and "CT" or "?"),
        (finite(team) and winner == team) and " (senin takimin)" or ""))
end))

listen("round_start", protect("detailed log round_start", function()
    if D.on() then
        D.close_all("round bitti")
        for enemy, ep in pairs(D.def) do
            D.end_def(enemy, ep, tickcount())
        end
        for name, r in pairs(D.round_def) do
            print(("[%s] dbg def ozeti: %s %d kez, toplam %dt, ort %.1ft, en uzun %dt, %d tanesi hareketliyken"):format(
                SCRIPT, name, r.n, r.ticks, r.ticks / r.n, r.longest, r.moving))
        end
        local m = D.my
        if m ~= nil and m.ticks > 0 then
            print(("[%s] dbg sen ozeti: %d tick canli, DT acik %d | defensive zorlanan %d tick, gorulen: setup %d / predict %d / net_update %d, zorlanip gorulen %d | teleport %d, sonrasi 1.5 sn icinde vurulma %d%s"):format(
                SCRIPT, m.ticks, m.dt, m.forced, m.setup, m.pred, m.net, m.both, m.tp, m.tp_hit,
                teleport.off and " (teleport bu harita kapali)" or ""))
        end
        print(D.header())
    end
    D.reset()
    nlog.save()
end))

listen("level_init", protect("detailed log level_init", function()
    D.reset()
    if D.on() then
        print(("[%s] dbg ===== harita %s ====="):format(SCRIPT, tostring(try(globals.mapname) or "?")))
        print(D.settings())
    end
    nlog.save()
end))

-- Dosya: degisiklik varsa en gec save_every sn'de bir (menu kapaliyken de), kapanista hemen.
listen("paint_ui", protect("log save", function()
    local now = realtime()
    if nlog.dirty and (now < nlog.saved or now - nlog.saved >= nlog.save_every) then
        nlog.save()
    end
end))

listen("shutdown", protect("log save", function()
    nlog.save()
end))

if D.on() then
    print(("[%s] detayli log acik: hepsini almak icin Home > Console > Copy all logs (panoya) ya da Print all logs (konsola); dosya: %s (CS:GO klasoru)"):format(
        SCRIPT, nlog.file))
    print(D.settings())
end
end

-------------------------------------------------------------------------------
-- Indikatorler (GameSense renderer)
-------------------------------------------------------------------------------

do
-- Renkler tek tabloda (LuaJIT'in 200 yerel degisken siniri).
local COLOR = {
    WHITE = { r = 255, g = 255, b = 255, a = 255 },
    DIM = { r = 255, g = 255, b = 255, a = 90 },
    CHARGING = { r = 255, g = 200, b = 80, a = 255 },
    SHADOW = { r = 0, g = 0, b = 0, a = 150 },
}
-- "-": GameSense'in kucuk piksel fontu (buyuk harf), indikatorlerin klasik gorunumu.
local FONT = "-"

local anim = { scope = 0, failed = {},
    labels = { Standing = "STAND", Moving = "MOVE", Crouch = "DUCK", Air = "AIR", Fakeduck = "FD" } }

local function text(x, y, col, flags, str)
    renderer.text(x, y, col.r, col.g, col.b, col.a, flags or "", 0, str)
end

local function text_width(flags, str)
    local w = try(renderer.measure_text, flags, str)
    if finite(w) then
        return w
    end
    return #str * 5
end

local function rect(x, y, w, h, col)
    renderer.rectangle(floor(x), floor(y), floor(w), floor(h), col.r, col.g, col.b, col.a)
end

local function color_of(element, fallback)
    local c = element ~= nil and element:get() or nil
    if type(c) == "table" and finite(c.r) then
        return c
    end
    return fallback
end

local function draw_indicators(lp, cx, cy)
    local accent = color_of(menu.accent, COLOR.WHITE)
    local scoped = prop(lp, "m_bIsScoped")
    local target = (scoped == 1 or scoped == true) and 1 or 0
    anim.scope = anim.scope + (target - anim.scope) * min(1, frametime() * 12)

    local x = cx + round(anim.scope * 34)
    local y = cy + 22
    local flags = "c" .. FONT
    text(x, y, accent, flags, SCRIPT:upper())

    y = y + 9
    local width = 36
    local fill = round(width * current.limit / 60)
    rect(x - width / 2 - 1, y - 1, width + 2, 4, COLOR.SHADOW)
    if fill > 0 then
        rect(x - width / 2, y, fill, 2, accent)
    end

    y = y + 7
    text(x, y, COLOR.WHITE, flags, current.state:upper())

    y = y + 9
    local dt_color = COLOR.DIM
    if dt_on() then
        dt_color = charge.value >= 1 and COLOR.WHITE or COLOR.CHARGING
    elseif recharge.held then
        dt_color = COLOR.CHARGING
    end
    local hs_color = hs_on() and COLOR.WHITE or COLOR.DIM
    local def_color = COLOR.DIM
    if defensive_active() then
        def_color = accent
    elseif current.defensive then
        def_color = COLOR.WHITE
    end
    local items = {
        { "DT", dt_color },
        { "HS", hs_color },
        { "FS", current.freestand and COLOR.WHITE or COLOR.DIM },
        { "DEF", def_color },
    }
    if exposure.available then
        local vis_color = COLOR.DIM
        if exposure.now or exposure.any then
            vis_color = accent
        elseif exposure.soon then
            vis_color = COLOR.WHITE
        end
        items[#items + 1] = { "VIS", vis_color }
    end
    local gap, total = 5, -5
    for _, item in ipairs(items) do
        item.w = text_width(FONT, item[1])
        total = total + item.w + gap
    end
    local px = x - total / 2
    for _, item in ipairs(items) do
        text(px + item.w / 2, y, item[2], flags, item[1])
        px = px + item.w + gap
    end

    local function line(str, col)
        y = y + 9
        text(x, y, col or accent, flags, str)
    end
    if current.brute > 0 then
        line(("BRUTE %d"):format(current.brute))
    end
    -- Hedefe karsi resolver seviyesi (1 = Prefer, 2 = Force, 3 = body yaw hipotezi) ve neden.
    if current.resolver > 0 then
        local why = current.res_prior and "JIT" or (anim.labels[current.res_state] or "")
        if current.resolver >= 3 and current.hyp ~= nil then
            why = ("BY %d"):format(current.hyp)
        end
        line(("RES %d %s"):format(current.resolver, why))
    end
    if current.lethal then
        line("BAIM")
    elseif current.head_only then
        line("HEAD")
    end
    if current.fake_body then
        line("DEF BODY", COLOR.CHARGING)
    end
    if current.clean then
        line("CLEAN SHOT")
    end
    if current.waiting ~= nil then
        line("WAIT REAL", COLOR.CHARGING)
    end
    if current.anti then
        line("ANTI-PEEK")
    end
    if ai_peek.mode == "go" or ai_peek.mode == "hold" then
        line("AI PEEK")
    end
end

local STAT_ORDER = {}
for _, state in ipairs(STATES) do
    STAT_ORDER[#STAT_ORDER + 1] = state
end
for _, state in ipairs({ "Legit", "Spin", "Ladder" }) do
    STAT_ORDER[#STAT_ORDER + 1] = state
end

local function draw_stats(sw, sh)
    local accent = color_of(menu.accent, COLOR.WHITE)
    local x, y = 12, floor(sh * 0.45)
    text(x, y, accent, FONT, "AA STATS   HIT / HEAD / MISS / DT / DEF")
    for _, state in ipairs(STAT_ORDER) do
        local entry = stats[state]
        if entry ~= nil then
            y = y + 10
            local dt = entry.dt_ticks > 0 and ("%d%%"):format(floor(100 * entry.dt_full / entry.dt_ticks)) or "-"
            local def = entry.def_ticks > 0 and ("%d%%"):format(floor(100 * entry.def_on / entry.def_ticks)) or "-"
            text(x, y, COLOR.WHITE, FONT, ("%s   %d / %d / %d / %s / %s"):format(state:upper(), entry.hits, entry.head,
                entry.misses, dt, def))
        end
    end
    if aim_stats.shots > 0 then
        y = y + 16
        text(x, y, accent, FONT, "AIM   SHOT / HIT / CORR / SPREAD / OTHER")
        y = y + 10
        text(x, y, COLOR.WHITE, FONT, ("ALL   %d / %d / %d / %d / %d"):format(
            aim_stats.shots, aim_stats.hits, aim_stats.correction, aim_stats.spread, aim_stats.other))
        y = y + 10
        text(x, y, COLOR.WHITE, FONT, ("LAG   %d / %d   TEMIZ   %d / %d"):format(
            aim_stats.lag_hits, aim_stats.lag_shots, aim_stats.clean_hits, aim_stats.clean_shots))
    end
    local any_kd = next(aim_stats.kd) ~= nil
    if any_kd then
        y = y + 16
        text(x, y, accent, FONT, "KD   OLDURDUN / OLDUN")
        for _, state in ipairs(STAT_ORDER) do
            local entry = aim_stats.kd[state]
            if entry ~= nil then
                y = y + 10
                text(x, y, COLOR.WHITE, FONT, ("%s   %d / %d"):format(state:upper(), entry.kills, entry.deaths))
            end
        end
    end
    if aim_stats.ai_peeks > 0 then
        y = y + 16
        text(x, y, accent, FONT, "AI PEEK   PEEK / ATIS / ISABET / BOS / VURULDUN")
        y = y + 10
        text(x, y, COLOR.WHITE, FONT, ("AI PEEK   %d / %d / %d / %d / %d"):format(aim_stats.ai_peeks,
            aim_stats.ai_shots, aim_stats.ai_hits, aim_stats.ai_empty, aim_stats.ai_hurt))
    end
    y = y + 16
    text(x, y, accent, FONT, "AA FAZ   KAFA ISABETI / MERMI")
    for _, grp_name in ipairs(brute.groups) do
        local parts = { brute.group_label[grp_name]:upper() }
        for phase = 0, #BRUTE_PHASES do
            local stat = brute.phases[grp_name][phase]
            parts[#parts + 1] = ("%d%s %d/%d"):format(phase, phase == brute.default[grp_name] and "*" or "",
                floor(stat.hits + 0.5), floor(stat.shots + 0.5))
        end
        y = y + 10
        text(x, y, COLOR.WHITE, FONT, table.concat(parts, "   "))
    end
    local hs, dt = sniper.stats.hs, sniper.stats.dt
    y = y + 10
    text(x, y, COLOR.WHITE, FONT, ("SNIPER   HS%s %d/%d   DT%s %d/%d"):format(
        sniper.choice == "hs" and "*" or "", floor(hs.hits + 0.5), floor(hs.shots + 0.5),
        sniper.choice == "dt" and "*" or "", floor(dt.hits + 0.5), floor(dt.shots + 0.5)))
end

local function draw_arrows(cx, cy)
    local col = color_of(menu.arrow_color, COLOR.WHITE)
    local off = { r = col.r, g = col.g, b = col.b, a = 60 }
    local dir = manual.dir
    local function tri(c, x0, y0, x1, y1, x2, y2)
        renderer.triangle(x0, y0, x1, y1, x2, y2, c.r, c.g, c.b, c.a)
    end
    tri(dir == "Left" and col or off, cx - 55, cy, cx - 42, cy - 9, cx - 42, cy + 9)
    tri(dir == "Right" and col or off, cx + 55, cy, cx + 42, cy - 9, cx + 42, cy + 9)
    if dir == "Forward" then
        tri(col, cx, cy - 55, cx - 9, cy - 42, cx + 9, cy - 42)
    end
    -- Desync tarafi
    rect(cx - 40, cy - 9, 2, 18, current.side and col or off)
    rect(cx + 38, cy - 9, 2, 18, current.side and off or col)
end

-- Resolver paneli: sadece yazi (golgeli); hedefin canli cozum yuzdesi ve isabet sansi. Menu acikken fareyle
-- tutup tasinir, sag alt kosedeki ucgenden surukleyerek buyutulur (GameSense fontlari sabit boyutlu: boyut
-- uc kademede font secer). GameSense'te tiklamayi menuden saklayan olay yok; menunun ustune tasima.
anim.panel = { drag = nil, was_down = false, x = 0, y = 0, w = 0, h = 0, size = 100, shown = 0, shown_index = nil,
    SHADOW = { r = 0, g = 0, b = 0, a = 170 }, INFO = { r = 225, g = 225, b = 230, a = 200 },
    LOW = { r = 235, g = 80, b = 80, a = 255 }, MID = { r = 245, g = 200, b = 85, a = 255 },
    HIGH = { r = 110, g = 225, b = 130, a = 255 } }
do
    local res_panel = anim.panel

    res_panel.tint = function(pct)
        local t = max(0, min(1, pct / 100))
        local a, b = res_panel.MID, res_panel.HIGH
        if t < 0.5 then
            a, b, t = res_panel.LOW, res_panel.MID, t * 2
        else
            t = (t - 0.5) * 2
        end
        return { r = floor(a.r + (b.r - a.r) * t), g = floor(a.g + (b.g - a.g) * t), b = floor(a.b + (b.b - a.b) * t), a = 255 }
    end

    -- Siradaki atisin tahmini isabet sansi (%): cozum x spread'le iskalamama x resolver disi iskalarin
    -- olmama orani (on bilgi spread %2, diger %8).
    res_panel.hit_chance = function(entry, resolve)
        local g = aim_stats
        local spread_all = (g.rated_spread + 0.5) / (g.rated + 25)
        local other_all = (g.rated_other + 1) / (g.rated + 12)
        local shots = entry ~= nil and entry.shots or 0
        local spread = ((entry ~= nil and entry.spread or 0) + spread_all * 10) / (shots + 10)
        local other = ((entry ~= nil and entry.other or 0) + other_all * 6) / (shots + 6)
        return floor(resolve * (1 - spread) * (1 - other) * 100 + 0.5)
    end

    -- Canli cozum tahmini (%): gecmis resolver sonuclari (on bilgi 0.8) x su anki durum (Neverlose V1.0 ile ayni).
    res_panel.live = function(target)
        local key = player_id(target)
        local entry = key ~= nil and resolver.players[key] or nil
        local hits, misses = entry ~= nil and entry.hits or 0, entry ~= nil and entry.misses or 0
        local value = (hits + 3.2) / (hits + misses + 4)
        local profile = enemy_watch.profile(target)
        if profile ~= nil then
            if profile.defensive_now then
                value = value * 0.5
            end
            if profile.lc then
                value = value * 0.6
            end
            if profile.jitter ~= nil then
                value = value * (1 - min(profile.jitter, 120) / 600)
            end
        end
        local state = enemy_state(target)
        if state == "Air" or state == "Fakeduck" then
            value = value * 0.9
        end
        local far = resolver.distance(target)
        if far ~= nil and far >= 2500 then
            value = value * 0.85
        elseif far ~= nil and far >= 1500 then
            value = value * 0.92
        end
        local level = entry ~= nil and entry_level(entry, state) or 0
        value = value * (1 + 0.05 * level)
        return max(0, min(100, value * 100)), entry
    end

    -- Boyuta gore font kademesi: buyuk yazi ve kucuk yazi bayraklari.
    res_panel.fonts = function(size)
        if size < 85 then
            return "b", "-"
        elseif size < 140 then
            return "+", ""
        end
        return "+", "b"
    end

    res_panel.input = function(sw, sh)
        local open = try(ui.is_menu_open) == true
        local down = try(client.key_state, 0x01) == true
        local mx, my = try(ui.mouse_position)
        if not open or not finite(mx) or not finite(my) then
            if res_panel.drag ~= nil then
                res_panel.save(sw, sh)
            end
            res_panel.drag, res_panel.was_down = nil, down
            return open
        end
        local x, y, w, h = res_panel.x, res_panel.y, res_panel.w, res_panel.h
        local grip = 12 * res_panel.size / 100
        if down and not res_panel.was_down then
            if mx >= x + w - grip and mx <= x + w and my >= y + h - grip and my <= y + h then
                res_panel.drag = { mode = "size", mx = mx, size = res_panel.size, w = max(1, w) }
            elseif mx >= x and mx <= x + w and my >= y and my <= y + h then
                res_panel.drag = { mode = "move", dx = mx - x, dy = my - y }
            end
        elseif not down and res_panel.drag ~= nil then
            res_panel.save(sw, sh)
            res_panel.drag = nil
        end
        local d = res_panel.drag
        if down and d ~= nil and d.mode == "move" then
            res_panel.x = max(0, min(sw - w, mx - d.dx))
            res_panel.y = max(0, min(sh - h, my - d.dy))
        elseif down and d ~= nil then
            res_panel.size = max(70, min(200, round(d.size * (d.w + mx - d.mx) / d.w)))
        end
        res_panel.was_down = down
        return open
    end

    res_panel.save = function(sw, sh)
        pcall(function()
            menu.panel_x:set(round(res_panel.x / max(1, sw) * 1000))
            menu.panel_y:set(round(res_panel.y / max(1, sh) * 1000))
            menu.panel_size:set(res_panel.size)
        end)
    end

    res_panel.shadow_text = function(flags, x, y, col, str)
        local s = res_panel.SHADOW
        renderer.text(x + 1, y + 1, s.r, s.g, s.b, s.a, flags, 0, str)
        renderer.text(x, y, col.r, col.g, col.b, col.a, flags, 0, str)
    end

    res_panel.draw = function(sw, sh)
        if res_panel.drag == nil then
            res_panel.size = menu.panel_size:get() or 100
            res_panel.x = floor((menu.panel_x:get() or 12) / 1000 * sw)
            res_panel.y = floor((menu.panel_y:get() or 330) / 1000 * sh)
        end
        local big, small = res_panel.fonts(res_panel.size)
        local target = resolver_target()
        if target ~= nil and not alive(target) then
            target = nil
        end

        local main, name, info, col
        if target ~= nil then
            local live, entry = res_panel.live(target)
            if res_panel.shown_index ~= target then
                res_panel.shown_index, res_panel.shown = target, live
            end
            local dt = max(0, min(1, frametime() * 8))
            res_panel.shown = res_panel.shown + (live - res_panel.shown) * dt
            local hit = res_panel.hit_chance(entry, res_panel.shown / 100)
            local hits, misses = entry ~= nil and entry.hits or 0, entry ~= nil and entry.misses or 0
            main = ("%d%%"):format(floor(res_panel.shown + 0.5))
            col = res_panel.tint(res_panel.shown)
            name = player_name(target)
            name = #name > 16 and name:sub(1, 15) .. "." or name
            info = ("COZUM   HIT %d%%   %d/%d"):format(hit, hits, hits + misses)
            if current.hyp ~= nil and target == resolver_target() then
                info = info .. ("   BY %d%s"):format(current.hyp, DEG)
            end
        else
            res_panel.shown_index = nil
            main, name, info, col = "--", "", "COZUM   hedef yok", COLOR.DIM
        end

        local big_w = text_width(big, main)
        local _, big_h = try(renderer.measure_text, big, main)
        big_h = finite(big_h) and big_h or 20
        local gap = floor(8 * res_panel.size / 100)
        local w = max(big_w + gap + text_width(big, name), text_width(small, info))
        local h = big_h + 14
        res_panel.w, res_panel.h = w + 4, h + 3
        local open = res_panel.input(sw, sh)
        local x, y = res_panel.x, res_panel.y

        res_panel.shadow_text(big, x, y, col, main)
        if name ~= "" then
            res_panel.shadow_text(big, x + big_w + gap, y, COLOR.WHITE, name)
        end
        res_panel.shadow_text(small, x, y + big_h, res_panel.INFO, info)

        if open then
            local accent = color_of(menu.accent, COLOR.WHITE)
            local frame = { r = accent.r, g = accent.g, b = accent.b, a = 90 }
            rect(x - 4, y - 3, w + 8, 1, frame)
            rect(x - 4, y + h + 2, w + 8, 1, frame)
            rect(x - 4, y - 3, 1, h + 6, frame)
            rect(x + w + 3, y - 3, 1, h + 6, frame)
            local g = floor(10 * res_panel.size / 100)
            renderer.triangle(x + w + 4, y + h + 3 - g, x + w + 4, y + h + 3, x + w + 4 - g, y + h + 3,
                accent.r, accent.g, accent.b, 160)
        end
    end
end

local function safe_draw(name, fn, ...)
    if anim.failed[name] then
        return
    end
    local ok, err = pcall(fn, ...)
    if not ok then
        anim.failed[name] = true
        print(("[%s] %s cizilemedi: %s"):format(SCRIPT, name, tostring(err)))
    end
end

listen("paint", protect("paint", function()
    if not on(menu.enabled) then
        return
    end
    local sw, sh = try(client.screen_size)
    if not finite(sw) or not finite(sh) then
        return
    end
    -- Istatistikler olunce de gorunsun.
    if on(menu.stats_panel) then
        safe_draw("stats", draw_stats, sw, sh)
    end
    if on(menu.res_panel) then
        safe_draw("resolver panel", anim.panel.draw, sw, sh)
    end
    local lp = local_player()
    if lp == nil or not alive(lp) then
        return
    end
    local cx, cy = floor(sw / 2), floor(sh / 2)
    if on(menu.indicators) then
        safe_draw("indicators", draw_indicators, lp, cx, cy)
    end
    if on(menu.arrows) then
        safe_draw("arrows", draw_arrows, cx, cy)
    end
end))

-- Menu acikken gorunurlukler (config yuklenince ya da sekme degisince) guncel kalsin.
listen("paint_ui", protect("paint_ui", function()
    if try(ui.is_menu_open) == true then
        local tab = menu.tab ~= nil and menu.tab:get() or nil
        local enabled = on(menu.enabled)
        if tab ~= anim.menu_tab or enabled ~= anim.menu_enabled then
            anim.menu_tab, anim.menu_enabled = tab, enabled
            update_visibility()
        end
    end
end))

listen("shutdown", protect("shutdown", function()
    set_native_visible(true)
    reset_overrides()
    plist_reset(false)
    persist.save(true)
end))

end

-- Kalici hafiza yuklenir; kac oyuncu hatirlandigi surum satirina eklenir.
do
    local loaded = persist.load()
    print(("[%s] V%s (%s edition) yuklendi%s"):format(SCRIPT, VERSION, EDITION,
        loaded > 0 and (" (hafiza: %d oyuncu)"):format(loaded) or ""))
end

end

do
    local ok, err = xpcall(nykle_main, function(e)
        local traceback = type(debug) == "table" and debug.traceback
        return traceback and traceback(tostring(e), 2) or tostring(e)
    end)
    if not ok then
        print("[Nykle.win] YUKLENEMEDI (bu hatayi gonder): " .. tostring(err))
        error(err, 0)
    end
end
