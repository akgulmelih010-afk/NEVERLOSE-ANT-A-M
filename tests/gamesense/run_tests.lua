-- Nykle.win GameSense edition: sahte ortamda senaryo testleri.
package.path = arg[0]:gsub("run_tests.lua$", "") .. "?.lua;" .. package.path
local M = require("mock_gs")
local SCRIPT_PATH = arg[1] or "Nykle_win_gamesense.lua"

local failures = 0
local function check(cond, msg)
    if not cond then
        failures = failures + 1
        io.stderr:write("FAIL: " .. msg .. "\n")
    end
end

local function log_has(pattern)
    for _, line in ipairs(M.logs) do
        if line:find(pattern, 1, true) then
            return true
        end
    end
    return false
end

-- Dunya: biz (1) ve iki dusman (2, 3) + takim arkadasi (4).
M.weapons[101] = { class = "CAK47", m_iClip1 = 30, m_flNextPrimaryAttack = 0, m_iItemDefinitionIndex = 7 }
M.weapons[102] = { class = "CWeaponSSG08", m_iClip1 = 10, m_flNextPrimaryAttack = 0, m_iItemDefinitionIndex = 40 }
M.weapons[103] = { class = "CKnife", m_iClip1 = -1, m_flNextPrimaryAttack = 0 }
M.weapons[104] = { class = "CWeaponAWP", m_iClip1 = 5, m_flNextPrimaryAttack = 0 }
M.weapons[105] = { class = "CDEagle", m_iClip1 = 7, m_flNextPrimaryAttack = 0, m_iItemDefinitionIndex = 64 }
local me = M.player(1, { alive = true, enemy = false, name = "me", steam = "76561198000000001", weapon = 101,
    origin = { 0, 0, 0 }, props = { m_fFlags = 1, m_vecVelocity = { 0, 0, 0 }, m_flDuckAmount = 0, m_nTickBase = 1000,
        m_MoveType = 2, m_iTeamNum = 2, m_iHealth = 100, m_flNextAttack = 0, m_bIsScoped = 0, ["m_vecViewOffset[2]"] = 64,
        m_totalHitsOnServer = 0 } })
local e1 = M.player(2, { alive = true, enemy = true, name = "enemy one", steam = "76561198000000002", weapon = 101,
    origin = { 500, 0, 0 }, props = { m_fFlags = 1, m_vecVelocity = { 0, 0, 0 }, m_flDuckAmount = 0, m_flSimulationTime = 10,
        m_angEyeAngles = { 0, 180, 0 }, m_iHealth = 100, m_ArmorValue = 100, ["m_vecViewOffset[2]"] = 64 } })
local e2 = M.player(3, { alive = true, enemy = true, name = "enemy two", steam = 0, weapon = 103,
    origin = { 0, 600, 0 }, props = { m_fFlags = 1, m_vecVelocity = { 0, 0, 0 }, m_flDuckAmount = 0, m_flSimulationTime = 10,
        m_angEyeAngles = { 0, 90, 0 }, m_iHealth = 100, m_ArmorValue = 0, ["m_vecViewOffset[2]"] = 64 } })
M.player(4, { alive = true, enemy = false, name = "mate", steam = "76561198000000004", weapon = 101, origin = { 50, 50, 0 },
    props = { m_fFlags = 1, m_vecVelocity = { 0, 0, 0 }, m_flSimulationTime = 10 } })
M.userids = { [11] = 1, [12] = 2, [13] = 3, [14] = 4 }
M.threat = 2

-- Native ayarlarin script yuklenmeden onceki degerleri (kapatinca geri gelmeli).
local snapshot = {}
for id, item in ipairs(M.items) do
    if not item.lua and item.name ~= "Weapon type" then
        snapshot[id] = type(item.value) == "table" and { mode = item.value.mode, key = item.value.key } or item.value
    end
end

-- Yukle
local chunk = assert(loadfile(SCRIPT_PATH))
local ok, err = pcall(chunk)
check(ok, "script yuklenemedi: " .. tostring(err))
check(log_has("yuklendi"), "yukleme satiri yok")

-- Menu NYKLE Yaw gibi AA > Anti-aimbot angles'da; lua acikken GameSense'in kendi AA ayarlari gizli.
local native_aa = {}
for _, item in ipairs(M.items) do
    if item.lua then
        check(item.tab == "AA" and item.container == "Anti-aimbot angles", "menu ogesi AA kutusunda degil: " .. item.name)
    elseif item.tab == "AA" and item.container == "Anti-aimbot angles" then
        native_aa[#native_aa + 1] = item
    end
end
check(#native_aa >= 10, "native AA ogeleri bulunamadi")
local function natives_visible(expected)
    for _, item in ipairs(native_aa) do
        if item.visible ~= expected then
            return false
        end
    end
    return true
end
check(natives_visible(false), "lua acikken GameSense AA ayarlari gizlenmedi")
check(M.find_lua("Trash talk").value == true, "trash talk varsayilan acik degil")
check(M.find_lua("Clan tag: Nykle.win (animated)").value == true, "clan tag varsayilan acik degil")

local function advance_sim(ticks)
    for _ = 1, ticks or 1 do
        for i = 2, 3 do
            local p = M.players[i]
            if p ~= nil and p.alive then
                p.props.m_flSimulationTime = p.props.m_flSimulationTime + 1 / 64
                -- AA deseni: varsayilan jitter; M.yaw_mode[i] = "static" / "spin".
                local yaw = p.props.m_angEyeAngles
                local mode = M.yaw_mode and M.yaw_mode[i]
                if mode == "static" then
                    yaw[2] = 140
                elseif mode == "spin" then
                    yaw[2] = (yaw[2] + 40 + 180) % 360 - 180
                elseif mode == "slowspin" then
                    yaw[2] = (yaw[2] + 15 + 180) % 360 - 180
                elseif mode == "xway" then
                    yaw[2] = ({ 140, 170, -160 })[M.tick % 3 + 1]
                elseif mode == "random" then
                    yaw[2] = ({ 0, 70, 125, 30, -45, 60, 150, 40 })[M.tick % 8 + 1]
                else
                    yaw[2] = (M.tick % 2 == 0) and 140 or -140
                end
            end
        end
        -- DT sarji: DT aktifken tickbase sarj kadar (14) geride kalir; atis / kapatma sarji sifirlar.
        local dt_cb, dt_key = ui.reference("RAGE", "Aimbot", "Double tap")
        local dt = ui.get(dt_cb) and ui.get(dt_key)
        local want = dt and 14 or 0
        M.shift = M.shift or 0
        if M.discharge then
            M.shift, M.discharge = 0, false
        elseif M.shift < want then
            M.shift = M.shift + 1
        elseif M.shift > want then
            M.shift = want
        end
        me.props.m_nTickBase = 1000 + M.tick + 2 - M.shift
    end
end

local function step(fields, n)
    for _ = 1, n or 1 do
        advance_sim(1)
        M.step(fields)
    end
end

-- 1) Duruyoruz, dusman gorunmuyor.
step({}, 80)
local yaw_item = M.items[select(1, ui.reference("AA", "Anti-aimbot angles", "Yaw"))]
check(yaw_item.value == "180", "AA yaw 180 yazilmadi: " .. tostring(yaw_item.value))
local body_item = M.items[select(1, ui.reference("AA", "Anti-aimbot angles", "Body yaw"))]
check(body_item.value == "Static", "body yaw Static degil: " .. tostring(body_item.value))
local aa_enabled = M.items[ui.reference("AA", "Anti-aimbot angles", "Enabled")]
check(aa_enabled.value == true, "AA enabled degil")
local dt_cb, dt_key = ui.reference("RAGE", "Aimbot", "Double tap")
check(M.items[dt_cb].value == true and M.items[dt_key].value.mode == 0, "auto exploit DT always on degil")

-- 2) Yururken dusman gorur (Smart defensive zorlamasi), havada, egilerek, slow walk.
M.visible[2] = true
M.can_hit[2] = false
me.props.m_vecVelocity = { 200, 0, 0 }
local forced = 0
for _ = 1, 60 do
    advance_sim(1)
    local cmd = M.step({})
    if cmd.force_defensive then
        forced = forced + 1
    end
end
check(forced > 0, "Smart defensive hic zorlanmadi (gorulurken)")
-- Aimbot ates edince 14 tick temiz atis: DT'nin ikinci mermisi / arkasindaki atis lag'e denk gelmez.
M.fire("aim_fire", { id = 900, target = 2, hit_chance = 85, hitgroup = 1, damage = 120, backtrack = 0 })
local forced_after = 0
for _ = 1, 10 do
    advance_sim(1)
    local cmd = M.step({})
    if cmd.force_defensive then
        forced_after = forced_after + 1
    end
end
check(forced_after == 0, "aimbot ates ettikten sonra defensive zorlandi: " .. forced_after)
M.fire("aim_miss", { id = 900, target = 2, hit_chance = 85, hitgroup = 1, reason = "spread" })
me.props.m_fFlags = 0
me.props.m_vecVelocity = { 250, 0, 280 }
local teleported = false
for _ = 1, 30 do
    advance_sim(1)
    local cmd = M.step({ in_jump = 1 })
    if cmd.discharge_pending == true then
        teleported, M.discharge = true, true
    end
end
check(teleported, "havada gorulunce teleport (discharge_pending) olmadi")
check(log_has("teleport: havada goruldun"), "teleport logu yok")
me.props.m_fFlags = 1
me.props.m_vecVelocity = { 0, 0, 0 }
step({}, 10)
-- Temiz atis: hedef vurulabilir ve silah hazir -> zorlanan defensive yok.
M.can_hit[2] = true
me.props.m_vecVelocity = { 200, 0, 0 }
local forced_clean = 0
for _ = 1, 20 do
    advance_sim(1)
    local cmd = M.step({})
    if cmd.force_defensive then
        forced_clean = forced_clean + 1
    end
end
check(forced_clean == 0, "temiz atista defensive zorlandi: " .. forced_clean)
me.props.m_vecVelocity = { 0, 0, 0 }
M.can_hit[2] = nil
me.props.m_flDuckAmount = 1
step({}, 20)
me.props.m_flDuckAmount = 0
me.props.m_vecVelocity = { 100, 0, 0 }
step({}, 20)

-- 3) Atislar: aim_fire / aim_hit / aim_miss ("?" -> correction, damage rejection, spread).
local id = 1
local function shoot(target, reason, hitgroup, flags)
    local fire = { id = id, target = target, hit_chance = 85, hitgroup = 1, damage = 120, backtrack = 0,
        teleported = false, extrapolated = false, x = 0, y = 0, z = 0 }
    for k, v in pairs(flags or {}) do
        fire[k] = v
    end
    M.fire("aim_fire", fire)
    M.fire("weapon_fire", { userid = 11, weapon = "ak47" })
    M.discharge = true
    step({}, 4)
    if reason == nil then
        M.fire("aim_hit", { id = id, target = target, hit_chance = 85, hitgroup = hitgroup or 1, damage = 100 })
    else
        M.fire("aim_miss", { id = id, target = target, hit_chance = 85, hitgroup = 1, reason = reason })
    end
    id = id + 1
    step({}, 4)
end
local function count_log(pattern)
    local n = 0
    for _, line in ipairs(M.logs) do
        if line:find(pattern, 1, true) then
            n = n + 1
        end
    end
    return n
end
local function safe_point(index)
    return M.plist[index] ~= nil and M.plist[index]["Override safe point"] or nil
end

-- 3a) GameSense'in teleport / extrapolation ile tahmin ettigi kayittaki "?" iskasi resolver'a sayilmaz.
shoot(2, "?", nil, { teleported = true })
check(log_has("resolver'a sayilmadi: teleport"), "teleport kaydindaki iska ayrilmadi")
check(count_log("iska (correction)") == 0, "teleport kaydindaki iska resolver seviyesini degistirdi")
shoot(2, "?", nil, { extrapolated = true })
check(log_has("resolver'a sayilmadi: extrapolation"), "extrapolation kaydindaki iska ayrilmadi")
check(count_log("iska (correction)") == 0, "extrapolation kaydindaki iska resolver seviyesini degistirdi")

-- 3b) Jitter'li dusman: seviye 2'de Force safe point, hipotez yok (sabit aci jitter'in yarisini tutar).
check(log_has("AA jitter"), "jitter deseni tanimadi")
shoot(2, "?")
shoot(2, "?")
shoot(2, "?")
shoot(2, "?")
check(log_has("resolver: enemy one"), "resolver seviye logu yok")
check(safe_point(2) == "On", "seviye 2'de oyuncu listesi Force safe point degil")
check(count_log("denenecek") == 0, "jitter'li dusmana hipotez denendi")

-- 3c) Yeni harita: hafizadaki / onceki iskalar en fazla Prefer; Force icin bu haritada yeni iska gerekir.
M.fire("level_init", {})
step({}, 12)
check(safe_point(2) ~= "On", "yeni haritada eski iskalarla Force safe point acildi")
shoot(2, "?")
check(safe_point(2) == "On", "bu haritadaki iskadan sonra Force safe point acilmadi")

-- 3d) Desen statik olunca hipotezler baslar (Force'ta 3+ resolver iskasi).
M.yaw_mode = { [2] = "static" }
step({}, 12)
check(log_has("denenecek"), "statik dusmanda hipotez baslamadi")
check(M.plist[2] ~= nil and M.plist[2]["Force body yaw"] == true, "hipotez oyuncu listesine yazilmadi")

-- 3e) Aday oyuncu listesinde uygulanmiyorken (Correction kapali) atis adaya yazilmaz; uygulaninca yazilir.
M.plist[2]["Correction active"] = false
step({}, 3)
check(M.plist[2]["Force body yaw"] ~= true, "Correction kapaliyken Force body yaw birakilmadi")
local missed_candidates = count_log("iskaladi")
shoot(2, "?")
check(count_log("iskaladi") == missed_candidates, "uygulanmayan aday iskadan ogrendi")
M.plist[2]["Correction active"] = true
step({}, 3)
shoot(2, "?")
check(count_log("iskaladi") == missed_candidates + 1, "uygulanan adayin iskasi yazilmadi")

-- 3f) Desen degisince (statik -> jitter) o durumdaki hipotezler silinir.
M.yaw_mode = nil
step({}, 12)
check(log_has("AA deseni degisti (static -> jitter)"), "desen degisince hipotezler sifirlanmadi")
check(M.plist[2]["Force body yaw"] ~= true, "jitter'a donunce Force body yaw birakilmadi")

-- 3g) Spin jitter sayilmaz; yavas yurume ayri durum.
M.yaw_mode = { [3] = "spin" }
step({}, 12)
shoot(3, "spread")
check(log_has("AA spin"), "spin deseni tanimadi")
-- Diger AA desenleri: 3-way (x-way), skitter / random jitter, yavas spin.
local function pattern_seen(mode, label)
    local before = count_log(label)
    M.yaw_mode = { [3] = mode }
    step({}, 14)
    shoot(3, "spread")
    return count_log(label) > before
end
check(pattern_seen("xway", "AA x-way"), "3-way deseni x-way degil")
check(pattern_seen("random", "AA random"), "random jitter deseni random degil")
check(pattern_seen("slowspin", "AA spin"), "yavas spin deseni spin degil")
M.yaw_mode = nil
e1.props.m_vecVelocity = { 80, 0, 0 }
step({}, 2)
shoot(2, "spread")
check(log_has("enemy one | Slow walk |"), "yavas yuruyen dusman Slow walk degil")
e1.props.m_vecVelocity = { 220, 0, 0 }
step({}, 2)
shoot(2, "spread")
check(log_has("enemy one | Moving |"), "kosan dusman Moving degil")
e1.props.m_vecVelocity = { 0, 0, 0 }
step({}, 2)
shoot(2, "spread")
me.props.m_totalHitsOnServer = 1
M.fire("aim_fire", { id = id, target = 2, hit_chance = 85, hitgroup = 1, damage = 120, backtrack = 0 })
me.props.m_totalHitsOnServer = 2
M.fire("aim_miss", { id = id, target = 2, hit_chance = 85, hitgroup = 1, reason = "?" })
id = id + 1
check(log_has("iska damage rejection"), "damage rejection ayrilmadi")
shoot(2, nil, 1)
shoot(2, nil, 2)

-- 3h) Sahte kayit (dusman defensive): aimbot gercek kayit gelene kadar o dusmana ates etmez.
local function whitelisted(index)
    return M.plist[index] ~= nil and M.plist[index]["Add to whitelist"] == true
end
-- Bekleme sadece dusman seni gormezken ve sen peek atmiyorken (dururken aciyi tutarken).
local visible_before, velocity_before = M.visible[2], me.props.m_vecVelocity
M.visible[2] = false
me.props.m_vecVelocity = { 0, 0, 0 }
step({}, 8)
check(not whitelisted(2), "gercek kayitta whitelist yapildi")
local fs_item = M.items[select(1, ui.reference("AA", "Anti-aimbot angles", "Freestanding"))]
local fs_before = fs_item.value
e1.props.m_flSimulationTime = e1.props.m_flSimulationTime - 10 / 64
step({}, 2)
check(whitelisted(2), "sahte kayitta (defensive) bekleme yok")
check(fs_item.value == fs_before, "beklerken freestanding degisti (AA'ya dokunulmamali)")
step({}, 12)
check(not whitelisted(2), "gercek kayit gelince whitelist birakilmadi")
check(log_has("gercek kayit beklendi, gercek kayit geldi"), "bekleme logu yok")
-- Surekli defensive: bir pencerede en fazla 14 tick beklenir, sonra 16 tick ates serbest.
local runs, last = {}, nil
-- Sim zamani bir kez geri, sonra sabit (her tick advance_sim'in ekledigi geri alinir): kayit hep sahte.
e1.props.m_flSimulationTime = e1.props.m_flSimulationTime - 10 / 64
for _ = 1, 100 do
    e1.props.m_flSimulationTime = e1.props.m_flSimulationTime - 1 / 64
    step({}, 1)
    local now = whitelisted(2)
    if now ~= last then
        runs[#runs + 1] = { held = now, n = 0 }
        last = now
    end
    runs[#runs].n = runs[#runs].n + 1
end
local first_hold, first_free
for _, r in ipairs(runs) do
    if r.held and first_hold == nil then
        first_hold = r.n
    elseif not r.held and first_hold ~= nil and first_free == nil then
        first_free = r.n
    end
end
check(first_hold ~= nil and first_hold <= 14, "surekli defensive'de bekleme siniri yok: " .. tostring(first_hold))
check(first_free ~= nil and first_free >= 31, "beklemeden sonra 32 tick ates serbest kalmadi: " .. tostring(first_free))
check(log_has("sinir doldu, ates serbest"), "bekleme siniri logu yok")
e1.props.m_flSimulationTime = e1.props.m_flSimulationTime + 2
step({}, 20)
check(not whitelisted(2), "defensive bitince whitelist kaldi")
-- Duelloda beklenmez: dusman kafani goruyorsa ya da Quick peek tusu basiliyken ates serbest.
M.visible[2] = true
e1.props.m_flSimulationTime = e1.props.m_flSimulationTime - 10 / 64
step({}, 3)
check(not whitelisted(2), "dusman kafani gorurken (duello) beklendi")
step({}, 40)
M.visible[2] = false
local qp_cb, qp_key = ui.reference("RAGE", "Other", "Quick peek assist")
M.items[qp_key].value.held = true
e1.props.m_flSimulationTime = e1.props.m_flSimulationTime - 10 / 64
step({}, 3)
check(not whitelisted(2), "Quick peek tusu basiliyken beklendi")
M.items[qp_key].value.held = false
step({}, 40)
check(not whitelisted(2), "duello testlerinden sonra whitelist kaldi")
-- Olunce bekleme whitelist'i geri verilir.
e1.props.m_flSimulationTime = e1.props.m_flSimulationTime - 10 / 64
step({}, 2)
check(whitelisted(2), "olum testi icin bekleme baslamadi")
me.alive = false
step({}, 2)
check(not whitelisted(2), "olunce whitelist geri verilmedi")
me.alive = true
step({}, 14)
-- Senin kendi whitelist'ine dokunulmaz.
M.plist[2]["Add to whitelist"] = true
e1.props.m_flSimulationTime = e1.props.m_flSimulationTime - 10 / 64
step({}, 16)
check(M.plist[2]["Add to whitelist"] == true, "kendi whitelist'in degistirildi")
M.plist[2]["Add to whitelist"] = false
M.visible[2], me.props.m_vecVelocity = visible_before, velocity_before
step({}, 4)

-- 4) Dusman mermisi kafanin yanindan (anti-brute) ve vurulma.
M.fire("bullet_impact", { userid = 12, x = 0, y = 2, z = 64 })
step({}, 20)
check(log_has("iska:"), "kafanin yanindan gecen mermi iska yazilmadi")
M.fire("bullet_impact", { userid = 12, x = 0, y = 1, z = 64 })
M.fire("player_hurt", { userid = 11, attacker = 12, weapon = "ak47", dmg_health = 100, hitgroup = 1, health = 0 })
check(log_has("vuruldun: head"), "vuruldun satiri yok")
step({}, 5)

-- 5) Sniper: Min. damage HP+1 sadece SSG 08 grubunda, silah degisince geri.
local md_id = ui.reference("RAGE", "Aimbot", "Minimum damage")
me.weapon = 102
ui.set(M.weapon_type_id, "SSG 08")
step({}, 10)
check(ui.get(md_id) == 101, "sniper Min. damage 101 degil: " .. tostring(ui.get(md_id)))
me.weapon = 101
ui.set(M.weapon_type_id, "Rifle")
step({}, 5)
ui.set(M.weapon_type_id, "SSG 08")
check(ui.get(md_id) == 20, "SSG 08 Min. damage geri verilmedi: " .. tostring(ui.get(md_id)))
ui.set(M.weapon_type_id, "Rifle")
step({}, 5)

-- 6) Fake duck + bicakli dusman yakin: fake duck birakilir.
local fd_id = ui.reference("RAGE", "Other", "Duck peek assist")
-- Fake duck boyunca DT ve HS kapali (fake duck'la calismazlar; senin bind'in acik olsa da); birakinca doner.
local hs_cb = ui.reference("AA", "Other", "On shot anti-aim")
M.items[dt_cb].value = true
M.items[fd_id].value.held = true
step({}, 3)
check(M.items[dt_cb].value == false and M.items[hs_cb].value == false, "fake duck sirasinda DT / HS kapatilmadi")
check(not log_has("FD, DT %"), "fake duck logunda DT acik gorunuyor")
e2.origin = { 0, 150, 0 }
step({}, 10)
check(not ui.get(fd_id), "bicakli dusman yakinken fake duck birakilmadi")
check(log_has("fake duck birakildi"), "fake duck logu yok")
e2.origin = { 0, 900, 0 }
step({}, 5)
check(ui.get(fd_id), "bicakli uzaklasinca fake duck geri verilmedi")
M.items[fd_id].value.held = false
-- Birakinca DT doner (gorulurken Safe recharge en fazla 1.2 sn bekletir).
step({}, 90)
check(M.items[dt_cb].value == true, "fake duck birakilinca DT geri gelmedi")

-- 7) Manuel yaw tusu ve Legit AA.
local manual_left = M.find_lua("Manual left")
manual_left.value.key = 0x5A
manual_left.value.held = true
step({}, 2)
manual_left.value.held = false
step({}, 5)
step({ in_use = 1 }, 5)
step({}, 5)

-- 8) AI peek: Quick peek tusu basili, hareket yok, dusman yan noktadan vurulabilir.
local qp_cb, qp_key = ui.reference("RAGE", "Other", "Quick peek assist")
me.props.m_vecVelocity = { 0, 0, 0 }
M.items[qp_key].value.held = true
M.visible[2] = false
step({}, 40)
M.items[qp_key].value.held = false
step({}, 5)
check(M.items[qp_cb].value == true, "Quick peek kutusu geri verilmedi")

-- 9) Round / olum / harita / config.
M.fire("player_death", { userid = 12, attacker = 11, headshot = true })
M.fire("round_start", {})
M.fire("player_death", { userid = 11, attacker = 13 })
M.fire("level_init", {})
step({}, 5)
M.menu_open = true
M.mouse = { 25, 360 }
M.mouse_down = true
step({}, 3)
M.mouse = { 60, 400 }
step({}, 3)
M.mouse_down = false
step({}, 3)
M.menu_open = false
local stats_toggle = M.find_lua("Stats panel")
ui.set(stats_toggle.id, true)
step({}, 3)

-- Dayaniklilik: rastgele durumlar, silahlar, gorus, menu degisiklikleri ve olaylar.
math.randomseed(1234)
local weapons = { 101, 102, 103, 104, 105 }
local types = { "Rifle", "SSG 08", "Global", "AWP", "R8 Revolver" }
local toggles = { "Anti-bruteforce", "Smart body aim", "Adaptive resolver", "Clean shot (no lag while shooting)",
    "Auto exploit", "Safe recharge", "Crosshair indicators", "Resolver panel", "Always use recommended settings" }
for t = 1, 1500 do
    local r = math.random()
    if r < 0.05 then me.weapon = weapons[math.random(#weapons)]; ui.set(M.weapon_type_id, types[math.random(#types)]) end
    if math.random() < 0.05 then me.props.m_fFlags = math.random(0, 1) end
    if math.random() < 0.05 then me.props.m_flDuckAmount = math.random() end
    if math.random() < 0.05 then me.props.m_vecVelocity = { math.random(-250, 250), math.random(-250, 250), math.random(-300, 300) } end
    if math.random() < 0.05 then M.visible[2] = math.random() < 0.5; M.visible[3] = math.random() < 0.5 end
    if math.random() < 0.03 then M.can_hit[2] = math.random() < 0.5 end
    if math.random() < 0.02 then M.threat = ({ 2, 3, nil })[math.random(3)] end
    if math.random() < 0.02 then e1.dormant = math.random() < 0.3 end
    if math.random() < 0.01 then e1.alive = math.random() < 0.8 end
    if math.random() < 0.02 then e1.props.m_flSimulationTime = e1.props.m_flSimulationTime - 0.05 end
    if math.random() < 0.02 then e1.origin = { math.random(-800, 800), math.random(-800, 800), math.random(-50, 100) } end
    if math.random() < 0.01 then
        local item = M.find_lua(toggles[math.random(#toggles)])
        ui.set(item.id, not item.value)
    end
    if math.random() < 0.01 then M.items[fd_id].value.held = math.random() < 0.5 end
    if math.random() < 0.01 then M.items[qp_key].value.held = math.random() < 0.5 end
    if math.random() < 0.03 then
        local target = math.random(2, 3)
        M.fire("aim_fire", { id = id, target = target, hit_chance = math.random(40, 100), hitgroup = math.random(0, 7),
            damage = math.random(10, 130), backtrack = math.random(0, 5), teleported = math.random() < 0.1 })
        if math.random() < 0.5 then
            M.fire("aim_hit", { id = id, target = target, hitgroup = math.random(0, 7), damage = math.random(10, 100) })
        else
            M.fire("aim_miss", { id = id, target = target, reason = ({ "?", "spread", "prediction error", "death", "unregistered shot" })[math.random(5)] })
        end
        id = id + 1
    end
    if math.random() < 0.02 then M.fire("bullet_impact", { userid = math.random(12, 13), x = math.random(-30, 30), y = math.random(-30, 30), z = math.random(30, 80) }) end
    if math.random() < 0.01 then M.fire("player_hurt", { userid = 11, attacker = math.random(12, 13), weapon = ({ "ak47", "knife", "inferno", "ssg08" })[math.random(4)], dmg_health = math.random(1, 100), hitgroup = math.random(0, 7) }) end
    if math.random() < 0.003 then M.fire("round_start", {}) end
    if math.random() < 0.002 then M.fire("level_init", {}) end
    if math.random() < 0.003 then M.fire("player_death", { userid = math.random(11, 13), attacker = math.random(11, 13) }) end
    if math.random() < 0.01 then M.menu_open = not M.menu_open end
    step({ in_jump = math.random() < 0.05 and 1 or 0, in_use = math.random() < 0.02 and 1 or 0,
        forwardmove = math.random() < 0.3 and 450 or 0, chokedcommands = math.random(0, 2) })
end
e1.alive, e1.dormant = true, false
M.items[fd_id].value.held = false
M.items[qp_key].value.held = false
M.menu_open = false
ui.set(M.weapon_type_id, "Rifle")
step({}, 5)

-- Config kaydederken native degerler senin degerlerin olmali.
M.fire("pre_config_save", {})
local restored = true
for nid, value in pairs(snapshot) do
    local item = M.items[nid]
    local now = type(item.value) == "table" and { mode = item.value.mode, key = item.value.key } or item.value
    if type(value) == "table" then
        if now.mode ~= value.mode or now.key ~= value.key then
            restored = false
            io.stderr:write("  config save: " .. item.name .. " mode " .. tostring(now.mode) .. "\n")
        end
    elseif now ~= value and not item.scoped then
        restored = false
        io.stderr:write("  config save: " .. item.name .. " = " .. tostring(now) .. " (eski " .. tostring(value) .. ")\n")
    end
end
check(restored, "config kaydederken native ayarlar geri verilmedi")
M.fire("post_config_save", {})
step({}, 5)

-- 9b) Trash talk: kapaliyken yazmaz; acikken oldurunce / olunce, takim chati, sadece headshot.
local tt = M.find_lua("Trash talk")
ui.set(tt.id, false)
M.execs = {}
M.fire("player_death", { userid = 12, attacker = 11, headshot = false })
step({}, 400)
check(#M.execs == 0, "trash talk kapaliyken yazdi")
ui.set(tt.id, true)
M.fire("player_death", { userid = 12, attacker = 11, headshot = false })
step({}, 500)
check(#M.execs > 0 and M.execs[1]:sub(1, 4) == "say ", "oldurunce trash talk yazmadi")
local kills = #M.execs
M.fire("player_death", { userid = 11, attacker = 13 })
step({}, 500)
check(#M.execs > kills, "olunce trash talk yazmadi")
for _, line in ipairs(M.execs) do
    check(not line:find(";", 1, true) and not line:find('"', 1, true), "trash talk satirinda tehlikeli karakter: " .. line)
end
ui.set(M.find_lua("  » Chat").id, "Team chat")
ui.set(M.find_lua("  » Kills: headshots only").id, true)
local before = #M.execs
M.fire("player_death", { userid = 12, attacker = 11, headshot = false })
step({}, 500)
check(#M.execs == before, "headshot-only acikken govde kill'inde yazdi")
M.fire("player_death", { userid = 12, attacker = 11, headshot = true })
step({}, 500)
check(#M.execs > before and M.execs[#M.execs]:sub(1, 9) == "say_team ", "takim chati / headshot kill calismadi")
M.fire("player_death", { userid = 14, attacker = 11, headshot = true })
local mates = #M.execs
step({}, 500)
check(#M.execs == mates, "takim arkadasini oldurunce yazdi")
ui.set(tt.id, false)

-- 9c) Clan tag (NYKLE Yaw): once tam ad, sonra harf harf; GameSense spammer'i kapali; kapatinca geri.
local spammer
for _, item in ipairs(M.items) do
    if item.name == "Clan tag spammer" then
        spammer = item
    end
end
local ct = M.find_lua("Clan tag: Nykle.win (animated)")
ui.set(ct.id, false)
step({}, 4)
check(M.clantag == "" and spammer.value == true, "clan tag kapaliyken geri verilmedi")
M.clantags = {}
ui.set(ct.id, true)
step({}, 64 * 7)
local expected = { "Nykle.win", "N", "Ny", "Nyk", "Nykl", "Nykle", "Nykle.", "Nykle.w", "Nykle.wi", "Nykle.win", "N" }
local sequence_ok = #M.clantags >= #expected
for i = 1, #expected do
    if M.clantags[i] ~= expected[i] then
        sequence_ok = false
    end
end
check(sequence_ok, "clan tag animasyonu yanlis: " .. table.concat(M.clantags, ",", 1, math.min(#M.clantags, 12)))
check(spammer.value == false, "clan tag acikken GameSense spammer'i kapatilmadi")
ui.set(ct.id, false)
step({}, 4)
check(M.clantag == "" and spammer.value == true, "clan tag kapatinca etiket / spammer geri verilmedi")
ui.set(ct.id, true)
step({}, 8)

-- 10) Kapat / ac ve kapanis: hepsi geri.
local enable = M.find_lua("Enable Nykle.win")
ui.set(enable.id, false)
step({}, 2)
check(natives_visible(true), "lua kapaliyken GameSense AA ayarlari gorunmuyor")
check(M.clantag == "", "lua kapaliyken clan tag kaldi")
ui.set(enable.id, true)
step({}, 2)
check(natives_visible(false), "lua acilinca GameSense AA ayarlari gizlenmedi")
M.fire("pre_config_load", {})
M.fire("post_config_load", {})
step({}, 70)
M.fire("shutdown", {})
local all_back = true
for nid, value in pairs(snapshot) do
    local item = M.items[nid]
    local now = type(item.value) == "table" and { mode = item.value.mode, key = item.value.key } or item.value
    if type(value) == "table" then
        if now.mode ~= value.mode or now.key ~= value.key then
            all_back = false
            io.stderr:write("  shutdown: " .. item.name .. " mode " .. tostring(now.mode) .. "\n")
        end
    elseif now ~= value and not item.scoped then
        all_back = false
        io.stderr:write("  shutdown: " .. item.name .. " = " .. tostring(now) .. " (eski " .. tostring(value) .. ")\n")
    end
end
check(all_back, "kapanista native ayarlar geri verilmedi")
check(natives_visible(true), "kapanista GameSense AA ayarlari gorunur yapilmadi")
check(M.clantag == "", "kapanista clan tag geri verilmedi")
for idx, fields in pairs(M.plist) do
    check(fields["Override safe point"] == nil or fields["Override safe point"] == "-", "kapanista plist safe point kaldi " .. idx)
    check(fields["Force body yaw"] == nil or fields["Force body yaw"] == false, "kapanista force body yaw kaldi " .. idx)
    check(fields["Add to whitelist"] == nil or fields["Add to whitelist"] == false, "kapanista whitelist kaldi " .. idx)
end
check(M.db["nykle_win_gs_memory"] ~= nil, "hafiza yazilmadi")
local saved = M.db["nykle_win_gs_memory"] and M.db["nykle_win_gs_memory"].resolver or {}
local one = saved["s:76561198000000002"]
check(one ~= nil and one.profile ~= nil and one.profile.n >= 10, "kisi profili hafizaya yazilmadi")
check(one ~= nil and one.angles ~= nil and next(one.angles) ~= nil, "aci sonuclari hafizaya yazilmadi")
for sid, per_type in pairs(M.scoped) do
    local default = 20
    if M.items[sid].kind == "checkbox" then
        default = false
    end
    for wt, value in pairs(per_type) do
        check(value == default, ("kapanista %s (%s) geri verilmedi: %s"):format(M.items[sid].name, wt, tostring(value)))
    end
end

local errors = M.errors_in_log()
for _, line in ipairs(errors) do
    io.stderr:write("LOG ERROR: " .. line .. "\n")
end
check(#errors == 0, "logda hata var")
check(M.draws > 100, "cizim yapilmadi")

if os.getenv("SHOW_LOG") then
    for _, line in ipairs(M.logs) do
        io.stdout:write(line, "\n")
    end
end
io.stdout:write(("tests done: %d failure(s), %d log lines, teleport=%s, draws=%d\n"):format(failures, #M.logs,
    tostring(teleported), M.draws))
os.exit(failures == 0 and 0 or 1)
