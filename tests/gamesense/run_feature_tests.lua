-- Nykle.win GameSense edition: V1.0.18'de yOndery paketi ve XYESOSENSE'ten alinanlar.
--  * silah degistirirken defensive (enderphobia "Weapon switch" tetigi, luasense weaponselect)
--  * tahminli avoid backstab + bicakli yakinken defensive (wraith / XYESOSENSE)
--  * jump scout (jumpscout.lua: scout'la yerinde ziplarken Air strafe kapali)
package.path = arg[0]:gsub("run_feature_tests.lua$", "") .. "?.lua;" .. package.path
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
local function count_log(pattern)
    local n = 0
    for _, line in ipairs(M.logs) do
        if line:find(pattern, 1, true) then
            n = n + 1
        end
    end
    return n
end

M.weapons[101] = { class = "CAK47", m_iClip1 = 30, m_flNextPrimaryAttack = 0, m_iItemDefinitionIndex = 7 }
M.weapons[102] = { class = "CWeaponSSG08", m_iClip1 = 10, m_flNextPrimaryAttack = 0, m_iItemDefinitionIndex = 40 }
M.weapons[103] = { class = "CKnife", m_iClip1 = -1, m_flNextPrimaryAttack = 0 }
local me = M.player(1, { alive = true, enemy = false, name = "me", steam = "76561198000000001", weapon = 101,
    origin = { 0, 0, 0 }, props = { m_fFlags = 1, m_vecVelocity = { 0, 0, 0 }, m_flDuckAmount = 0, m_nTickBase = 1000,
        m_MoveType = 2, m_iTeamNum = 2, m_iHealth = 100, m_flNextAttack = 0, m_bIsScoped = 0,
        ["m_vecViewOffset[2]"] = 64, m_totalHitsOnServer = 0 } })
local e1 = M.player(2, { alive = true, enemy = true, name = "enemy one", steam = "76561198000000002", weapon = 101,
    origin = { 900, 0, 0 }, props = { m_fFlags = 1, m_vecVelocity = { 0, 0, 0 }, m_flDuckAmount = 0,
        m_flSimulationTime = 10, m_angEyeAngles = { 89, 180, 0 }, m_flLowerBodyYawTarget = 180, m_iHealth = 100,
        m_ArmorValue = 100, ["m_vecViewOffset[2]"] = 64 } })
M.userids = { [11] = 1, [12] = 2 }
M.threat = 2

local dt_cb, dt_key = ui.reference("RAGE", "Aimbot", "Double tap")
local strafe = M.items[ui.reference("MISC", "Movement", "Air strafe")]
local yaw_base = M.items[ui.reference("AA", "Anti-aimbot angles", "Yaw base")]

-- DT sarji (run_tests ile ayni): DT aktifken tickbase 14 tick geride.
local shift = 0
local function step(fields, n)
    local forced = 0
    local last
    for _ = 1, n or 1 do
        e1.props.m_flSimulationTime = e1.props.m_flSimulationTime + 1 / 64
        local dt = ui.get(dt_cb) and ui.get(dt_key)
        shift = dt and math.min(14, shift + 1) or 0
        me.props.m_nTickBase = 1000 + M.tick + 2 - shift
        last = M.step(fields)
        if last.force_defensive then
            forced = forced + 1
        end
    end
    return forced, last
end

local ok, err = pcall(assert(loadfile(SCRIPT_PATH)))
check(ok, "script yuklenemedi: " .. tostring(err))
step({}, 80)

-- 1) Silah degistirirken defensive. Dusman var ama gormuyor, sen duruyorsun: zorlama yok.
check(step({}, 30) == 0, "1: dusman gormezken duran oyuncuda defensive zorlandi")
-- Silah cekiliyor (m_flNextAttack 0.8 sn ileride): ilk ~0.65 sn zorlanir, silah hazir olmadan 0.15 sn once
-- birakilir.
me.props.m_flNextAttack = M.realtime + 0.8
local during = step({}, 36)
local tail = step({}, 24)
check(during == 36, "1: silah cekilirken defensive zorlanmadi (" .. during .. "/36)")
check(tail <= 8, "1: silah hazir olunca defensive birakilmadi (" .. tail .. "/24)")
check(step({}, 10) == 0, "1: silah hazirken defensive zorlandi")
-- weaponselect'li tick (silah secildigi an, m_flNextAttack henuz kurulmamis).
local forced_select = step({ weaponselect = 3 }, 1)
check(forced_select == 1, "1: weaponselect tick'inde defensive zorlanmadi")
-- Kapaliyken yok ("Always use recommended settings" acikken kapatilan ayar geri acilir, o yuzden once o).
local switch_item = M.find_lua("Defensive while switching weapons")
check(switch_item.value == true, "1: Defensive while switching weapons varsayilan acik degil")
local recommended = M.find_lua("Always use recommended settings")
ui.set(recommended.id, false)
ui.set(switch_item.id, false)
me.props.m_flNextAttack = M.realtime + 0.8
check(step({}, 20) == 0, "1: ayar kapaliyken silah cekilirken defensive zorlandi")
me.props.m_flNextAttack = 0
ui.set(switch_item.id, true)
step({}, 40)
-- Canli dusman yokken yok.
e1.alive = false
me.props.m_flNextAttack = M.realtime + 0.8
check(step({}, 20) == 0, "1: dusman yokken silah cekilirken defensive zorlandi")
me.props.m_flNextAttack = 0
e1.alive = true
step({}, 60)
-- Round sonu ozeti zorlananin ne kadarinin silah degisirken oldugunu yazar.
M.fire("round_start", {})
local switch_total = during + tail + forced_select
check(log_has(("(silah degisirken %d, bicakli yakinken 0)"):format(switch_total)),
    "1: dbg sen ozeti silah degisirken sayacini yazmadi (" .. switch_total .. " bekleniyordu)")

-- 2) Tahminli avoid backstab. Bicakli dusman 290 birimde duruyor: tepki yok (eskisi gibi 250 siniri).
e1.weapon = 103
e1.origin = { 290, 0, 0 }
local idle_forced = step({}, 20)
check(idle_forced == 0, "2: duran bicakli 290 birimdeyken defensive zorlandi")
check(not log_has("backstab:"), "2: duran bicakli 290 birimdeyken backstab sayildi")
check(yaw_base.value == "At targets", "2: duran bicakliya yuz donuldu: " .. tostring(yaw_base.value))
-- Ayni yerde ama sana 250 hizla kosuyor: 0.19 sn sonra 243 birimde -> simdiden yuzun ona, defensive.
e1.props.m_vecVelocity = { -250, 0, 0 }
local run_forced = step({}, 8)
check(log_has("backstab: enemy one bicakli, 290 birimde (0.19 sn sonra 243) -> yuz ona, defensive"),
    "2: kosarak gelen bicakli tahminle yakalanmadi")
check(yaw_base.value == "Local view", "2: bicakliya yuz donulmedi: " .. tostring(yaw_base.value))
check(run_forced >= 6, "2: bicakli yaklasirken defensive zorlanmadi (" .. run_forced .. "/8)")
check(count_log("backstab:") == 1, "2: ayni yaklasmada backstab logu tekrarlandi")
-- Defensive alt ayari kapaliyken yuz yine doner, defensive yok.
local knife_def = M.find_lua("  » Defensive while knife is close")
check(knife_def.value == true, "2: Defensive while knife is close varsayilan acik degil")
ui.set(knife_def.id, false)
check(step({}, 8) == 0, "2: alt ayar kapaliyken bicakliya karsi defensive zorlandi")
check(yaw_base.value == "Local view", "2: alt ayar kapaliyken bicakliya yuz donulmedi")
ui.set(knife_def.id, true)
ui.set(recommended.id, true)
-- Uzaklasan bicakli: tepki biter.
e1.props.m_vecVelocity = { 250, 0, 0 }
e1.origin = { 400, 0, 0 }
step({}, 4)
check(yaw_base.value == "At targets", "2: uzaklasan bicakliya hala yuz donuk")
check(step({}, 8) == 0, "2: uzaklasan bicakliya karsi defensive zorlandi")
M.fire("round_start", {})
check(log_has("bicakli yakinken"), "2: dbg sen ozeti bicakli sayacini yazmadi")
e1.weapon = 101
e1.origin = { 900, 0, 0 }
e1.props.m_vecVelocity = { 0, 0, 0 }
step({}, 20)

-- 3) Jump scout: scout'la yerinde ziplarken Air strafe kapali, inince geri.
check(M.find_lua("Jump scout (no air strafe on standing jump)").value == true, "3: jump scout varsayilan acik degil")
check(strafe.value == true, "3: Air strafe baslangicta acik degil")
me.weapon = 102
step({}, 10)
check(strafe.value == true, "3: yerde dururken Air strafe kapandi")
step({ in_jump = 1 }, 1)
check(strafe.value == false, "3: scout'la yerinde ziplarken Air strafe kapanmadi")
me.props.m_fFlags = 0
me.props.m_vecVelocity = { 0, 0, 250 }
step({}, 20)
check(strafe.value == false, "3: havadayken Air strafe geri acildi")
me.props.m_fFlags = 1
me.props.m_vecVelocity = { 0, 0, 0 }
step({}, 2)
check(strafe.value == true, "3: inince Air strafe geri gelmedi")
-- Kosarak ziplama: dokunulmaz.
me.props.m_vecVelocity = { 250, 0, 0 }
step({ in_jump = 1 }, 1)
check(strafe.value == true, "3: kosarak ziplarken Air strafe kapandi")
me.props.m_vecVelocity = { 0, 0, 0 }
-- Tufekle yerinde ziplama: dokunulmaz.
me.weapon = 101
step({ in_jump = 1 }, 1)
check(strafe.value == true, "3: tufekle ziplarken Air strafe kapandi")
step({}, 2)
-- Air strafe'i sen kapattiysan dokunulmaz, inince de kapali kalir.
me.weapon = 102
ui.set(strafe.id, false)
step({ in_jump = 1 }, 1)
me.props.m_fFlags = 0
step({}, 5)
me.props.m_fFlags = 1
step({}, 2)
check(strafe.value == false, "3: senin kapattigin Air strafe acildi")
ui.set(strafe.id, true)
step({}, 2)
-- Havadayken lua kapatilirsa senin ayarin geri gelir.
step({ in_jump = 1 }, 1)
check(strafe.value == false, "3: ikinci ziplamada Air strafe kapanmadi")
local enabled = M.find_lua("Enable Nykle.win")
ui.set(enabled.id, false)
step({}, 2)
check(strafe.value == true, "3: lua kapatilinca Air strafe geri verilmedi")
ui.set(enabled.id, true)
step({}, 4)

-- 4) V1.0.20 (V1.0.17 logu: "AA (peek): en az vurulan faz 1 (0/0 kafa isabeti)"): yerde faz 0 iki kafa
-- yiyince verisi olmayan dusmanlara hic denenmemis faz 1 verilir; satir bunu "en az vurulan" ve "0/0" diye
-- degil, kafa yiyen fazla ve "denenmemis" diye yazar. Iki ayri dusman: ikisi de henuz faz 0'da.
local e2 = M.player(3, { alive = true, enemy = true, name = "enemy two", steam = "76561198000000003", weapon = 102,
    origin = { 0, 900, 0 }, props = { m_fFlags = 1, m_vecVelocity = { 0, 0, 0 }, m_flDuckAmount = 0,
        m_flSimulationTime = 10, m_angEyeAngles = { 89, -90, 0 }, m_flLowerBodyYawTarget = -90, m_iHealth = 100,
        m_ArmorValue = 100, ["m_vecViewOffset[2]"] = 64 } })
M.userids[13] = 3
me.weapon = 101
step({}, 4)
M.fire("player_hurt", { userid = 11, attacker = 12, weapon = "ssg08", dmg_health = 1, hitgroup = 1, health = 99 })
step({}, 4)
check(not log_has("AA (yerde)"), "4: tek kafada faz degisti")
M.threat = 3
step({}, 4)
M.fire("player_hurt", { userid = 11, attacker = 13, weapon = "ssg08", dmg_health = 1, hitgroup = 1, health = 98 })
step({}, 4)
check(not log_has("(0/0 kafa isabeti)"), "4: denenmemis faz '0/0 kafa isabeti' diye yazildi")
check(log_has("AA (yerde): faz 0 cok kafa yiyor (2/2 kafa isabeti) -> verisi olmayan dusmanlara denenmemis faz 1"),
    "4: denenmemis faza gecis yazilmadi")
M.threat = 2
e2.alive = false
step({}, 4)

for _, line in ipairs(M.errors_in_log()) do
    io.stderr:write("LOG ERROR: " .. line .. "\n")
    failures = failures + 1
end
if os.getenv("SHOW_LOG") then
    for _, line in ipairs(M.logs) do
        io.stdout:write(line, "\n")
    end
end
io.stdout:write(("feature tests done: %d failure(s), %d log lines\n"):format(failures, #M.logs))
os.exit(failures == 0 and 0 or 1)
