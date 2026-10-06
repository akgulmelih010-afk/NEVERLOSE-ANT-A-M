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

-- GameSense readfile / writefile: log dosyasi (V1.0.10). Onceki oturumdan kalan satir korunmali.
M.files = { ["nykle_log.txt"] = "12:00:00 [Nykle.win] eski oturum satiri\n" }
function readfile(name) return M.files[name] end
function writefile(name, data) M.files[name] = data end

-- Eski (V1.0.14 ve oncesi, govde isabeti sayilmayan) sniper verisi HS'yi iyi gosteriyor: V1.0.15'te alinmaz,
-- scout yine DT ile baslar (bkz. 5b).
M.db["nykle_win_gs_memory"] = { version = 1, sniper = { hs = { shots = 10, hits = 0 }, dt = { shots = 10, hits = 10 } } }

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
-- Ayna defensive: hedef sahte kayittayken temiz atis yok, kendi defensive'in zorlanir.
e1.props.m_flSimulationTime = e1.props.m_flSimulationTime - 10 / 64
local forced_fake = 0
for _ = 1, 6 do
    advance_sim(1)
    local cmd = M.step({})
    if cmd.force_defensive then
        forced_fake = forced_fake + 1
    end
end
check(forced_fake > 0, "hedef sahte kayittayken kendi defensive'in zorlanmadi")
step({}, 12)
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

-- 3d) Desen statik olunca hipotezler baslar (Force'ta 3+ resolver iskasi); V1.0.15: yeni desen 1.5 sn
-- oturmadan baslamaz.
M.yaw_mode = { [2] = "static" }
step({}, 12)
check(not log_has("denenecek"), "desen oturmadan (1.5 sn) hipotez basladi")
step({}, 100)
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

-- 3f2) V1.0.15 (oyun logu, Vice Luaaa): desen 20 sn'de 3. kez degisince kararsiz; desen otursa da 20 sn
-- hipotez yok, "degisti / denenecek" spam'i yok.
local tries_before = count_log("denenecek")
M.yaw_mode = { [2] = "static" }
step({}, 12)
check(count_log("AA deseni kararsiz") == 1, "3f2: kararsiz desen yazilmadi")
step({}, 120)
check(count_log("denenecek") == tries_before, "3f2: kararsiz desende hipotez basladi")
M.yaw_mode = nil
step({}, 12)
check(count_log("AA deseni kararsiz") == 1 and count_log("AA deseni degisti") == 1,
    "3f2: kararsizken desen logu tekrarlandi")
-- 3f3) V1.0.17 (oyun logu, Haise jitter 50 <-> x-way 85): ikisi de hipotezsiz (Force safe point), aralarindaki
-- gecis kararsizlik sayilmaz.
step({}, 64 * 21)
local unstable_before = count_log("AA deseni kararsiz")
for _, mode in ipairs({ "xway", false, "xway", false, "xway", false }) do
    M.yaw_mode = mode and { [2] = mode } or nil
    step({}, 20)
end
check(count_log("AA deseni kararsiz") == unstable_before, "3f3: jitter / x-way gecisi kararsiz sayildi")
M.yaw_mode = nil
step({}, 12)

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
-- Sayac artti ama hasar baska oyuncuya gitti: "baska oyuncuya isabet" (damage rejection degil).
M.fire("aim_fire", { id = id, target = 2, hit_chance = 85, hitgroup = 1, damage = 120, backtrack = 0 })
me.props.m_totalHitsOnServer = 3
M.fire("player_hurt", { userid = 13, attacker = 11, weapon = "ak47", dmg_health = 30, hitgroup = 2, health = 70 })
M.fire("aim_miss", { id = id, target = 2, hit_chance = 85, hitgroup = 1, reason = "?" })
id = id + 1
check(log_has("iska baska oyuncuya isabet"), "baska oyuncuya giden isabet damage rejection sanildi")
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
-- V1.0.8: varsayilan kapali; kapaliyken sahte kayitta da beklenmez (aimbot normal sikar).
local wait_item = M.find_lua("Wait for real record (enemy defensive)")
check(wait_item.value == false, "sahte kayit beklemesi varsayilan kapali degil")
e1.props.m_flSimulationTime = e1.props.m_flSimulationTime - 10 / 64
step({}, 3)
check(not whitelisted(2), "bekleme kapaliyken whitelist yapildi")
step({}, 14)
local recommended_item = M.find_lua("Always use recommended settings")
ui.set(recommended_item.id, false)
ui.set(wait_item.id, true)
step({}, 2)
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
ui.set(recommended_item.id, true)
step({}, 4)
check(wait_item.value == false, "onerilen ayarlar beklemeyi kapatmadi")

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

-- 5b) Scout'ta Auto (learn) once DT (GameSense'te HS ile defensive zorlanamiyor).
me.weapon = 102
ui.set(M.weapon_type_id, "SSG 08")
step({}, 10)
local hs_ref = ui.reference("AA", "Other", "On shot anti-aim")
check(M.items[hs_ref].value == false and M.items[dt_cb].value == true, "scout'ta Auto (learn) once DT degil")
-- DT'de 4 kafa: hic denenmemis Hide shots'a on bilgisiyle gecilmez (V1.0.16; oyun logu:
-- "Hide shots 0/0, Double tap 4/4 -> Hide shots").
local function sniper_head()
    M.fire("player_hurt", { userid = 11, attacker = 12, weapon = "ssg08", dmg_health = 1, hitgroup = 1, health = 99 })
    step({}, 2)
end
for _ = 1, 4 do
    sniper_head()
end
step({}, 4)
check(not log_has("kafa isabeti -> Hide shots"), "4 mermide hic denenmemis Hide shots'a gecildi")
check(M.items[hs_ref].value == false and M.items[dt_cb].value == true, "4 mermide scout DT'den cikti")
-- DT'de kafa yemeye devam: 8 mermide %40+ kafa -> kesif, Hide shots denenir.
for _ = 1, 4 do
    sniper_head()
end
check(log_has("kafa isabeti -> Hide shots (deneme"), "DT'de kafa yerken sniper exploit degismedi")
step({}, 4)
check(M.items[hs_ref].value == true, "kesifte scout Hide shots'a gecmedi")
-- Sunucu Hide shots atisini reddediyor (V1.0.19 kurali): lag yokken HS ile atilan son 4 atisin 3'u
-- reddedildiyse ve en az 2 farkli dusmanda -> sniper'da (Auto) Hide shots birakilir. Ayni dusmana arka arkaya
-- iki ret ve araya isabet giren retler yetmez (V1.0.17 logu: eski "60 sn'de 2 ret" kurali 3 saatte 4 kez
-- tetiklendi, ret orani HS'de %9, DT'de %14).
local function rejected_shot(target, rejected)
    local hits = me.props.m_totalHitsOnServer
    M.fire("aim_fire", { id = id, target = target, hit_chance = 85, hitgroup = 1, damage = 120, backtrack = 0 })
    if rejected then
        me.props.m_totalHitsOnServer = hits + 1
        M.fire("aim_miss", { id = id, target = target, hit_chance = 85, hitgroup = 1, reason = "?" })
    else
        M.fire("aim_hit", { id = id, target = target, hit_chance = 85, hitgroup = 1, damage = 100 })
    end
    id = id + 1
    step({}, 2)
end
rejected_shot(2, true)
rejected_shot(2, true)
check(not log_has("ile atilan atislari reddediyor"), "ayni dusmana 2 damage rejection'da exploit degisti")
check(M.items[hs_ref].value == true, "ayni dusmana 2 retten sonra scout Hide shots'tan cikti")
rejected_shot(2, false)
rejected_shot(2, false)
rejected_shot(3, true)
rejected_shot(3, true)
check(not log_has("ile atilan atislari reddediyor"), "araya isabet giren retlerde (son 4'te 2) exploit degisti")
rejected_shot(2, true)
check(log_has("sunucu Hide shots ile atilan atislari reddediyor (son 4 atisin 3'i, 2 dusmanda, son: damage rejection)"),
    "HS reddi ogrenilmedi (son 4 atisin 3'u, 2 dusman)")
step({}, 4)
check(M.items[hs_ref].value == false, "HS reddedilince sniper Hide shots'tan cikmadi")

-- 5c) Scout "sadece kafa" (HP + 1) ile ates etmeden beklerken oldun -> bu haritada ona karsi govde de atilir.
step({}, 100)
check(ui.get(md_id) == 101, "ogrenmeden once sniper Min. damage 101 degil: " .. tostring(ui.get(md_id)))
M.fire("player_death", { userid = 11, attacker = 12, headshot = true })
check(log_has("ogrenildi: enemy one seni sen kafa beklerken"), "kafa beklerken olum ogrenilmedi")
step({}, 4)
check(ui.get(md_id) == 20, "ogrendikten sonra enemy one'a karsi kafa kurali gevsemedi: " .. tostring(ui.get(md_id)))
M.fire("level_init", {})
step({}, 6)
check(ui.get(md_id) == 101, "yeni haritada kafa kurali geri gelmedi: " .. tostring(ui.get(md_id)))
-- V1.0.19: senin Min. damage'in 100 (V1.0.17 logundaki gibi; gevseme eskiden bir sey degistirmiyordu):
-- gevseyince seni gorurken gecici 70, yeni haritada yine 101.
ui.set(md_id, 100)
step({}, 4)
check(ui.get(md_id) == 101, "MD 100 iken kafa kurali 101 yazmadi: " .. tostring(ui.get(md_id)))
M.fire("player_death", { userid = 11, attacker = 12, headshot = true })
check(log_has("(senin Min. damage'in 100: seni gorurken gecici 70)"), "MD 100 iken ogrenme logu gecici 70 demedi")
step({}, 4)
check(ui.get(md_id) == 70, "MD 100 iken gevseyince Min. damage 70 olmadi: " .. tostring(ui.get(md_id)))
check(not log_has("govde yine atilmaz"), "eski 'govde yine atilmaz' notu yazildi")
M.fire("level_init", {})
step({}, 6)
check(ui.get(md_id) == 101, "MD 100 iken yeni haritada kafa kurali geri gelmedi: " .. tostring(ui.get(md_id)))
ui.set(md_id, 20)
step({}, 4)
me.weapon = 101
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
-- Zeus 420 birimde de birakir (bicakta 260).
M.weapons[106] = { class = "CWeaponTaser", m_iClip1 = 1, m_flNextPrimaryAttack = 0 }
local e2_weapon = e2.weapon
e2.weapon = 106
e2.origin = { 0, 400, 0 }
step({}, 6)
check(not ui.get(fd_id), "zeus'lu dusman 400 birimdeyken fake duck birakilmadi")
e2.origin = { 0, 900, 0 }
e2.weapon = e2_weapon
step({}, 6)
check(ui.get(fd_id), "zeus'lu uzaklasinca fake duck geri verilmedi")
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

-- 9d) Detayli log (V1.0.10): "gordu ama sikmadi", atis detayi (konum, aimbot bayraklari), vurulma (son iki
-- atis arasi), duello ozeti, kill; round basinda log dosyasi; dugmeler; kapaliyken dbg satiri yok.
do
    me.alive, me.weapon = true, 101
    e1.alive, e1.dormant = true, false
    e1.props.m_iHealth = 100
    me.props.m_vecVelocity = { 0, 0, 0 }
    me.props.m_fFlags = 1
    M.visible[2], M.can_hit[2] = true, true
    M.fire("round_start", {})
    local before = #M.logs
    local function new_line(pattern)
        for i = before + 1, #M.logs do
            if M.logs[i]:find(pattern, 1, true) then
                return M.logs[i]
            end
        end
        return nil
    end
    -- V1.0.17: LC kiran (her 8 tick'te 100 birim isinlanan) dusman sikmadi sebebinde yazilir.
    local base_y = e1.origin[2]
    for i = 1, 40 do
        if i % 8 == 0 then
            e1.origin[2] = e1.origin[2] == base_y and base_y + 100 or base_y
        end
        step({}, 1)
    end
    e1.origin[2] = base_y
    local no_shot = new_line("dbg sikmadi: enemy one")
    check(no_shot ~= nil and no_shot:find("vurulabilir", 1, true) ~= nil and no_shot:find("@", 1, true) ~= nil
        and no_shot:find("ben @", 1, true) ~= nil, "gorup sikmadi satiri yok: " .. tostring(no_shot))
    check(no_shot ~= nil and no_shot:find("onun kaydi LC kiriyor", 1, true) ~= nil,
        "sikmadi satirinda LC sebebi yok: " .. tostring(no_shot))
    M.fire("aim_fire", { id = 950, target = 2, hit_chance = 85, hitgroup = 1, damage = 120, backtrack = 2,
        extrapolated = true, x = 500, y = 0, z = 64 })
    M.fire("aim_miss", { id = 950, target = 2, reason = "spread" })
    local detail = new_line("dbg atis-detay: enemy one")
    check(detail ~= nil and detail:find("bt 2t", 1, true) ~= nil and detail:find("extrapolated", 1, true) ~= nil
        and detail:find("sonuc spread", 1, true) ~= nil and detail:find("u h+", 1, true) ~= nil,
        "atis detayi (konum / bayrak / sonuc) yok: " .. tostring(detail))
    M.fire("weapon_fire", { userid = 12, weapon = "ak47" })
    step({}, 4)
    M.fire("weapon_fire", { userid = 12, weapon = "ak47" })
    M.fire("player_hurt", { userid = 11, attacker = 12, weapon = "ak47", dmg_health = 27, hitgroup = 2, health = 73 })
    local hurt = new_line("dbg vurulma-detay: enemy one")
    check(hurt ~= nil and hurt:find("(DT)", 1, true) ~= nil and hurt:find("sen onu", 1, true) ~= nil,
        "vurulma detayi (DT / gorus) yok: " .. tostring(hurt))
    M.fire("player_death", { userid = 12, attacker = 11, headshot = true, penetrated = 1, weapon = "ak47" })
    check(new_line("dbg kill-detay: enemy one ak47 headshot, duvardan (1)") ~= nil, "kill detayi yok")
    local duel = new_line("dbg duello: enemy one")
    check(duel ~= nil and duel:find("oldurdun", 1, true) ~= nil and duel:find("sen: 1 ates", 1, true) ~= nil
        and duel:find("o: 2 ates 1 isabet -27", 1, true) ~= nil, "duello ozeti yok / yanlis: " .. tostring(duel))
    M.fire("round_start", {})
    check(new_line("dbg ===== round") ~= nil, "round basligi yok")
    -- V1.0.20: harita basinda round_start arka arkaya iki kez gelince (V1.0.18 logu) baslik bir kez yazilir;
    -- kazanansiz round sonu "? kazandi" yazmaz.
    local function count_lines(pattern)
        local n = 0
        for i = before + 1, #M.logs do
            if M.logs[i]:find(pattern, 1, true) then
                n = n + 1
            end
        end
        return n
    end
    M.fire("round_end", { winner = 1 })
    M.fire("round_start", {})
    M.fire("round_start", {})
    check(count_lines("dbg ===== round") == 2, "ayni round basligi iki kez yazildi: " .. count_lines("dbg ===== round"))
    check(new_line("kazanan yok") ~= nil and new_line("? kazandi") == nil, "kazanansiz round sonu '? kazandi' yazdi")
    local file = M.files["nykle_log.txt"] or ""
    check(file:find("eski oturum satiri", 1, true) ~= nil and file:find("yuklendi", 1, true) ~= nil
        and file:find("dbg atis-detay", 1, true) ~= nil, "log dosyasi eski + yeni satirlari tutmuyor")
    check(file:find("\n%d%d:%d%d:%d%d %[Nykle%.win%] ") ~= nil or file:find("\n[%d%.]+ %[Nykle%.win%] ") ~= nil,
        "log dosyasinda saat yok")

    before = #M.logs
    M.press(M.find_lua("Print all logs to console").id)
    check(new_line("===== tum loglar:") ~= nil and new_line("===== loglarin sonu") ~= nil, "Print all logs calismadi")
    -- V1.0.19: hemen ardindan Copy all logs: sebep yazilir, loglar 10 sn icinde ikinci kez konsola yazilmaz
    -- (V1.0.17 logunda 2 sn'de 13 basis, her biri 4300 satir).
    before = #M.logs
    M.press(M.find_lua("Copy all logs").id)
    local copy_line = new_line("panoya kopyalanamadi")
    check(copy_line ~= nil and copy_line:find("kopyalanamadi (", 1, true) ~= nil
        and copy_line:find("Allow unsafe scripts kapali olabilir", 1, true) == nil,
        "pano yokken sebep yazilmadi: " .. tostring(copy_line))
    check(new_line("===== tum loglar:") == nil and new_line("sn once konsola yazildi") ~= nil,
        "Copy all logs 10 sn icinde loglari ikinci kez konsola yazdi")
    step({}, 704)
    before = #M.logs
    M.press(M.find_lua("Copy all logs").id)
    check(new_line("panoya kopyalanamadi") ~= nil and new_line("===== tum loglar:") ~= nil,
        "pano yokken Copy all logs konsola yazmadi")

    local dbg_item = M.find_lua("Detailed log (for analysis)")
    check(dbg_item.value == true, "detayli log varsayilan acik degil")
    ui.set(dbg_item.id, false)
    e1.alive = true
    before = #M.logs
    M.fire("aim_fire", { id = 951, target = 2, hit_chance = 85, hitgroup = 1, damage = 120, backtrack = 0 })
    M.fire("aim_miss", { id = 951, target = 2, reason = "spread" })
    step({}, 40)
    check(new_line("dbg ") == nil, "detayli log kapaliyken dbg satiri yazildi")
    ui.set(dbg_item.id, true)
    M.press(M.find_lua("Clear saved logs").id)
    check((M.files["nykle_log.txt"] or ""):find("eski oturum satiri", 1, true) == nil, "Clear saved logs silmedi")
    M.visible[2], M.can_hit[2] = nil, nil
    step({}, 8)
end

-- 9e) V1.0.11 (oyun logundan): fake duck'ta sniper mermisi yiyince fake duck birakilir (tufekte degil), o
-- gormeyince geri; nisan alinan yerine arkadaki oyuncuya giden mermi resolver'a sayilmaz; dormant'ta gecen
-- sure defensive sayilmaz; ates / el bombasi hasari detay satiri yazmaz; round sonunda "sen ozeti".
do
    local function new_line(from, pattern)
        for i = from + 1, #M.logs do
            if M.logs[i]:find(pattern, 1, true) then
                return M.logs[i]
            end
        end
        return nil
    end
    local fd_id = ui.reference("RAGE", "Other", "Duck peek assist")
    me.alive, me.weapon = true, 102
    e1.alive, e1.dormant = true, false
    M.visible[2] = true
    M.items[fd_id].value.held = true
    step({}, 3)
    check(ui.get(fd_id), "fake duck basili degil (test kurulumu)")
    M.fire("player_hurt", { userid = 11, attacker = 12, weapon = "ak47", dmg_health = 20, hitgroup = 2, health = 80 })
    step({}, 4)
    check(ui.get(fd_id), "tufekle vurulunca da fake duck birakildi (sadece sniper'da birakilmali)")
    local before = #M.logs
    M.fire("player_hurt", { userid = 11, attacker = 12, weapon = "ssg08", dmg_health = 50, hitgroup = 3, health = 30 })
    step({}, 4)
    check(not ui.get(fd_id) and new_line(before, "sniper ile vurdu") ~= nil, "sniper ile vurulunca fake duck birakilmadi")
    step({}, 64)
    check(not ui.get(fd_id), "sniper seni gorurken fake duck erken geri geldi")
    M.visible[2] = false
    step({}, 80)
    check(ui.get(fd_id), "sniper seni gormeyince fake duck geri verilmedi")
    M.items[fd_id].value.held = false
    step({}, 4)

    before = #M.logs
    M.fire("aim_fire", { id = 960, target = 2, hit_chance = 85, hitgroup = 1, damage = 120, backtrack = 0 })
    M.fire("aim_hit", { id = 960, target = 3, hitgroup = 1, damage = 100 })
    check(new_line(before, "mermi baska oyuncuya gitti (nisan: enemy one)") ~= nil, "baska oyuncuya giden isabet ayrilmadi")
    check(new_line(before, "resolver: enemy two") == nil, "baska oyuncuya giden isabet resolver'a yazildi")

    before = #M.logs
    M.fire("player_hurt", { userid = 11, attacker = 12, weapon = "inferno", dmg_health = 4, hitgroup = 0, health = 26 })
    check(new_line(before, "dbg vurulma-detay") == nil, "ates hasari detay satiri yazdi")

    M.fire("round_start", {})
    step({}, 4)
    e1.props.m_flSimulationTime = e1.props.m_flSimulationTime - 10 / 64
    step({}, 2)
    e1.dormant = true
    step({}, 100)
    e1.dormant = false
    step({}, 4)
    before = #M.logs
    M.fire("round_start", {})
    local def_line = new_line(before, "dbg def ozeti: enemy one")
    local longest = def_line ~= nil and tonumber(def_line:match("en uzun (%d+)t")) or nil
    check(longest ~= nil and longest <= 12, "dormant'ta gecen sure defensive sayildi: " .. tostring(def_line))
    local mine = new_line(before, "dbg sen ozeti:")
    check(mine ~= nil and mine:find("defensive zorlanan", 1, true) ~= nil and mine:find("predict", 1, true) ~= nil,
        "sen ozeti yok: " .. tostring(mine))
    me.weapon = 101
end

-- 9f) V1.0.12: defensive predict_command'da (luasense / hysteria'nin yontemi) gorulur: setup_command'daki
-- tickbase normalken predict sirasinda tickbase 8 geride -> "DEF acik", havada (air lag zorlarken) hidden
-- pitch (Up) yazilir. Defensive yokken hidden aci yok; fake duck'ta "DEF acik" yok.
do
    local function new_line(from, pattern)
        for i = from + 1, #M.logs do
            if M.logs[i]:find(pattern, 1, true) then
                return M.logs[i]
            end
        end
        return nil
    end
    local pitch_id, pitch_value_id = ui.reference("AA", "Anti-aimbot angles", "Pitch")
    local function hidden_up()
        return M.items[pitch_id].value == "Custom" and M.items[pitch_value_id].value == -89
    end
    me.alive, me.weapon = true, 101
    e1.alive, e1.dormant = true, false
    me.props.m_vecVelocity = { 200, 0, 0 }
    me.props.m_fFlags = 1
    M.visible[2], M.can_hit[2] = false, false
    M.items[dt_cb].value = true
    -- 7. bolumdeki manuel yaw (sol) hala acik: ayni tusa tekrar basinca kapanir (Manual'da hidden aci yok).
    local manual_key = M.find_lua("Manual left")
    manual_key.value.held = true
    step({}, 2)
    manual_key.value.held = false
    step({}, 90)
    local early = false
    for _ = 1, 20 do
        step({}, 1)
        early = early or hidden_up()
    end
    check(not early, "defensive yokken hidden pitch yazildi")
    me.props.m_fFlags = 0
    me.props.m_vecVelocity = { 200, 0, 120 }
    step({}, 2)
    M.predict_tickbase = function(tb) return tb - 8 end
    local hidden = false
    for _ = 1, 3 do
        step({}, 1)
        hidden = hidden or hidden_up()
    end
    local before = #M.logs
    M.fire("player_hurt", { userid = 11, attacker = 12, weapon = "ak47", dmg_health = 5, hitgroup = 2, health = 95 })
    check(hidden, "predict_command defensive gorunce havada hidden pitch (Up) yazilmadi")
    me.props.m_fFlags = 1
    me.props.m_vecVelocity = { 0, 0, 0 }
    check(new_line(before, "DEF acik") ~= nil, "predict_command defensive'i logda DEF acik degil")
    M.predict_tickbase = nil
    step({}, 20)
    local fd_id = ui.reference("RAGE", "Other", "Duck peek assist")
    M.items[fd_id].value.held = true
    step({}, 3)
    M.predict_tickbase = function(tb) return tb - 8 end
    step({}, 2)
    before = #M.logs
    M.fire("player_hurt", { userid = 11, attacker = 12, weapon = "ak47", dmg_health = 5, hitgroup = 2, health = 90 })
    check(new_line(before, "DEF acik") == nil, "fake duck'ta DEF acik yazildi")
    M.predict_tickbase = nil
    M.items[fd_id].value.held = false
    me.props.m_vecVelocity = { 0, 0, 0 }
    M.visible[2], M.can_hit[2] = nil, nil
    step({}, 90)
end

-- 9g) V1.0.13: teleport sonucu tutulur; bir haritada son 3 teleportun 2'si 1.5 sn icinde vurulmayla
-- bittiyse o harita boyunca havada teleport kapanir. level_init'te tekrar acilir. Yeni haritada DT sarji
-- sifirdan dolar (sarj olcumu orada sifirlanir).
do
    local function new_map()
        M.fire("level_init", {})
        M.shift = 0
        step({}, 60)
    end
    new_map()
    me.alive, me.weapon = true, 101
    e1.alive, e1.dormant = true, false
    M.visible[2], M.can_hit[2] = true, false
    local function jump(hurt)
        me.props.m_fFlags = 0
        me.props.m_vecVelocity = { 250, 0, 280 }
        local fired = false
        for _ = 1, 30 do
            advance_sim(1)
            local cmd = M.step({ in_jump = 1 })
            if cmd.discharge_pending == true and not fired then
                fired, M.discharge = true, true
                if hurt then
                    M.fire("player_hurt", { userid = 11, attacker = 12, weapon = "ak47", dmg_health = 20, hitgroup = 2,
                        health = 80 })
                end
            end
        end
        me.props.m_fFlags = 1
        me.props.m_vecVelocity = { 0, 0, 0 }
        -- 1.5 sn'den fazla yerde: vurulmayan teleport "vurulmadin" diye yazilir, DT tekrar dolar.
        step({}, 160)
        return fired
    end
    M.items[dt_cb].value = true
    step({}, 60)
    check(jump(true), "9g: 1. teleport olmadi")
    check(log_has("teleport sonucu: 1.5 sn icinde vuruldun (son 1: 1 vurulma)"), "9g: vurulan teleport sonucu yazilmadi")
    check(jump(false), "9g: 2. teleport olmadi")
    check(log_has("teleport sonucu: vurulmadin (son 2: 1 vurulma)"), "9g: vurulmayan teleport sonucu yazilmadi")
    check(not log_has("bu harita boyunca havada teleport kapali"), "9g: 1/2 vurulmada teleport kapandi")
    check(jump(true), "9g: 3. teleport olmadi")
    check(log_has("bu harita boyunca havada teleport kapali"), "9g: son 3'te 2 vurulmada teleport kapanmadi")
    check(not jump(false), "9g: kapandiktan sonra yine teleport yapildi")
    new_map()
    check(jump(false), "9g: yeni haritada teleport tekrar acilmadi")
    M.visible[2], M.can_hit[2] = nil, nil
end

-- 9h) V1.0.14 / V1.0.15 (oyun logundan): havada fake duck tusu DT'yi kapatmaz (GameSense'in fake duck'i sadece
-- yerde), yere inince fake duck'ta DT kapali. Sniper mermisiyle fake duck birakilinca sarj beklenmez (DT
-- hemen acik); tusu kendin birakinca (gorulurken) sarj yine beklenir. Bicakli dusman yakinken scout'ta
-- Min. damage gecici 30 (101 kafa kurali ve senin 100'un yerine), uzaklasinca geri. Oluyken fake duck tusu
-- basiliysa log "FD | DEF yok" der (V1.0.15). AI peek'te ates edilince peek bos sayilmaz (V1.0.15).
do
    local fd_id = ui.reference("RAGE", "Other", "Duck peek assist")
    -- Scout'ta durumun exploit'i (DT): 5b'deki kesif sniper'i Hide shots'ta birakti, burada fake duck test ediliyor.
    local sniper_item = M.find_lua("Snipers (SSG08/AWP/R8)")
    ui.set(sniper_item.id, "Same as state")
    me.alive, me.weapon = true, 102
    e1.alive, e1.dormant = true, false
    M.visible[2], M.can_hit[2] = false, false
    M.items[dt_cb].value = true
    me.props.m_fFlags = 1
    me.props.m_vecVelocity = { 0, 0, 0 }
    step({}, 90)
    me.props.m_fFlags = 0
    me.props.m_vecVelocity = { 200, 0, 120 }
    step({ in_jump = 1 }, 3)
    M.items[fd_id].value.held = true
    local dt_kept = true
    for _ = 1, 20 do
        step({ in_jump = 1 }, 1)
        dt_kept = dt_kept and M.items[dt_cb].value == true
    end
    check(dt_kept, "9h: havada fake duck tusuna basinca DT kapatildi")
    me.props.m_fFlags = 1
    me.props.m_vecVelocity = { 0, 0, 0 }
    step({}, 4)
    check(M.items[dt_cb].value == false, "9h: yere inince fake duck'ta DT kapatilmadi")

    -- Yerde fake duck, gorulurken sniper mermisi: fake duck birakilir, DT sarj beklemeden acilir.
    M.visible[2] = true
    step({}, 10)
    M.fire("player_hurt", { userid = 11, attacker = 12, weapon = "ssg08", dmg_health = 40, hitgroup = 3, health = 60 })
    step({}, 6)
    check(not ui.get(fd_id), "9h: sniper mermisiyle fake duck birakilmadi")
    check(M.items[dt_cb].value == true, "9h: sniper mermisiyle fake duck birakilinca DT sarji bekletildi")
    M.visible[2] = false
    step({}, 120)
    check(ui.get(fd_id), "9h: sniper gormeyince fake duck geri verilmedi")
    -- Tusu kendin birakinca (gorulurken): Safe recharge yine bekletir.
    M.visible[2] = true
    step({}, 4)
    M.items[fd_id].value.held = false
    step({}, 4)
    check(M.items[dt_cb].value == false, "9h: fake duck'i kendin birakinca (gorulurken) sarj beklenmedi")
    M.visible[2] = false
    step({}, 90)

    -- Bicakli dusman yakin: scout'ta Min. damage gecici 30.
    local md_id = ui.reference("RAGE", "Aimbot", "Minimum damage")
    me.weapon = 101
    ui.set(M.weapon_type_id, "SSG 08")
    step({}, 4)
    ui.set(md_id, 100)
    me.weapon = 102
    e2.alive, e2.dormant, e2.weapon = true, false, 103
    e2.origin = { 0, 900, 0 }
    M.visible[2] = true
    step({}, 10)
    check(ui.get(md_id) == 101, "9h: kurulum: sniper Min. damage 101 degil: " .. tostring(ui.get(md_id)))
    local before = #M.logs
    e2.origin = { 0, 150, 0 }
    step({}, 6)
    check(ui.get(md_id) == 30, "9h: bicakli dusman yakinken Min. damage 30 degil: " .. tostring(ui.get(md_id)))
    local knife_line = false
    for i = before + 1, #M.logs do
        knife_line = knife_line or M.logs[i]:find("bicak/zeus ile yakinda: Min. damage gecici 30", 1, true) ~= nil
    end
    check(knife_line, "9h: bicakli dusman yakinken Min. damage logu yok")
    -- Yakinda 6 sn kalinca log tekrarlanmaz (V1.0.15: 5 sn'de bir yaziyordu).
    step({}, 400)
    local knife_lines = 0
    for i = before + 1, #M.logs do
        knife_lines = knife_lines + (M.logs[i]:find("bicak/zeus ile yakinda", 1, true) and 1 or 0)
    end
    check(knife_lines == 1 and ui.get(md_id) == 30, "9h: bicak logu yakinda kalinca tekrarlandi: " .. knife_lines)
    e2.origin = { 0, 900, 0 }
    step({}, 6)
    check(ui.get(md_id) == 101, "9h: bicakli uzaklasinca Min. damage geri gelmedi: " .. tostring(ui.get(md_id)))
    me.weapon = 101
    step({}, 4)
    check(ui.get(md_id) == 100, "9h: silah degisince senin Min. damage'in geri verilmedi: " .. tostring(ui.get(md_id)))
    ui.set(md_id, 20)
    ui.set(M.weapon_type_id, "Rifle")
    M.visible[2], M.can_hit[2] = nil, nil
    step({}, 10)

    -- Fake duck tusu basiliyken oldun (yerde degilsin): log FD der, "DEF acik" demez.
    M.items[fd_id].value.held = true
    step({}, 4)
    before = #M.logs
    me.alive, me.props.m_fFlags = false, 0
    M.fire("player_hurt", { userid = 11, attacker = 12, weapon = "ak47", dmg_health = 100, hitgroup = 1, health = 0 })
    local dead_line
    for i = before + 1, #M.logs do
        dead_line = dead_line or (M.logs[i]:find("vuruldun:", 1, true) and M.logs[i])
    end
    check(dead_line ~= nil and dead_line:find("| FD, ", 1, true) ~= nil and dead_line:find("DEF yok", 1, true) ~= nil,
        "9h: oluyken fake duck tusu basili ama log FD / DEF yok demedi: " .. tostring(dead_line))
    M.items[fd_id].value.held = false
    me.alive, me.props.m_fFlags = true, 1
    step({}, 10)

    -- AI peek: aimbot peek'te ates etti (aim_fire) ama weapon_fire sunucudan gec geliyor. Peek bos sayilmaz,
    -- "2 bos peek" kilidi gelmez (oyun logu 01:20:07 / 01:20:34). Gercekten bos iki peek'te kilit yine gelir.
    local real_bullet = client.trace_bullet
    client.trace_bullet = function(from, x1, y1, z1, x2, y2, z2)
        if from == 1 and math.abs(y1) < 5 then
            return -1, 0
        end
        return real_bullet(from, x1, y1, z1, x2, y2, z2)
    end
    local qp_peek_key = select(2, ui.reference("RAGE", "Other", "Quick peek assist"))
    local e2_alive = e2.alive
    e2.alive = false
    M.visible[2], M.can_hit[2], M.visible[3] = false, true, false
    M.threat = 2
    step({}, 90)
    local function peek_logs(from)
        local starts, empties, blocked, results = 0, 0, 0, 0
        for i = from + 1, #M.logs do
            local line = M.logs[i]
            starts = starts + ((line:find("ai peek: s[oa][lg] %d+ birim") ~= nil) and 1 or 0)
            empties = empties + (line:find("ai peek: atis olmadi", 1, true) and 1 or 0)
            blocked = blocked + (line:find("2 bos peek", 1, true) and 1 or 0)
            results = results + (line:find("ai peek sonucu: isabet", 1, true) and 1 or 0)
        end
        return starts, empties, blocked, results
    end
    before = #M.logs
    M.items[qp_peek_key].value.held = true
    for shot = 1, 2 do
        local waited = 0
        while select(1, peek_logs(before)) < shot and waited < 200 do
            step({}, 1)
            waited = waited + 1
        end
        M.fire("aim_fire", { id = 990 + shot, target = 2, hit_chance = 90, hitgroup = 1, damage = 120, backtrack = 0 })
        M.weapons[101].m_flNextPrimaryAttack = M.realtime + 1
        -- weapon_fire sunucudan peek'in sure dolmasindan (0.4 sn) sonra gelir.
        step({}, 32)
        M.fire("weapon_fire", { userid = 11, weapon = "ak47" })
        M.fire("aim_hit", { id = 990 + shot, target = 2, hitgroup = 1, damage = 40 })
        step({}, 20)
    end
    M.weapons[101].m_flNextPrimaryAttack = 0
    local starts, empties, blocked, results = peek_logs(before)
    check(starts >= 2 and results == 2,
        ("9h: AI peek senaryosu kurulamadi (peek %d, sonuc %d)"):format(starts, results))
    check(empties == 0 and blocked == 0,
        ("9h: ates edilen peek bos sayildi (atis olmadi %d, 2 bos peek %d)"):format(empties, blocked))
    -- Tusu birakip yeniden bas: bu sefer aimbot ates etmez, iki bos peek -> kilit.
    M.items[qp_peek_key].value.held = false
    step({}, 4)
    before = #M.logs
    M.items[qp_peek_key].value.held = true
    step({}, 240)
    starts, empties, blocked = peek_logs(before)
    check(empties >= 2 and blocked == 1,
        ("9h: bos peek kilidi calismadi (peek %d, atis olmadi %d, 2 bos peek %d)"):format(starts, empties, blocked))
    M.items[qp_peek_key].value.held = false
    client.trace_bullet = real_bullet
    e2.alive = e2_alive
    M.visible[2], M.can_hit[2], M.visible[3] = nil, nil, nil
    ui.set(sniper_item.id, "Auto (learn)")
    step({}, 10)
end

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
