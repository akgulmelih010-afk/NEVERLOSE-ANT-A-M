-- Nykle.win GameSense edition: hafizadaki sniper exploit istatistigiyle yukleme (V1.0.17).
-- Oyun logu: V1.0.15'in erken Hide shots gecisinden sonra hafizada DT 4/4, HS 27 mermide 10 kafa kaldi;
-- V1.0.16 yuklenince scout dogrudan Hide shots'ta basladi (DT'nin 4 mermisi hic artmiyordu).
package.path = arg[0]:gsub("run_sniper_tests.lua$", "") .. "?.lua;" .. package.path
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

M.weapons[101] = { class = "CAK47", m_iClip1 = 30, m_flNextPrimaryAttack = 0, m_iItemDefinitionIndex = 7 }
M.weapons[102] = { class = "CWeaponSSG08", m_iClip1 = 10, m_flNextPrimaryAttack = 0, m_iItemDefinitionIndex = 40 }
local me = M.player(1, { alive = true, enemy = false, name = "me", steam = "76561198000000001", weapon = 101,
    origin = { 0, 0, 0 }, props = { m_fFlags = 1, m_vecVelocity = { 0, 0, 0 }, m_flDuckAmount = 0, m_nTickBase = 1000,
        m_MoveType = 2, m_iTeamNum = 2, m_iHealth = 100, m_flNextAttack = 0, m_bIsScoped = 0,
        ["m_vecViewOffset[2]"] = 64, m_totalHitsOnServer = 0 } })
local e1 = M.player(2, { alive = true, enemy = true, name = "enemy one", steam = "76561198000000002", weapon = 102,
    origin = { 500, 0, 0 }, props = { m_fFlags = 1, m_vecVelocity = { 0, 0, 0 }, m_flDuckAmount = 0,
        m_flSimulationTime = 10, m_angEyeAngles = { 89, 180, 0 }, m_flLowerBodyYawTarget = 180, m_iHealth = 100,
        m_ArmorValue = 100, ["m_vecViewOffset[2]"] = 64 } })
M.userids = { [11] = 1, [12] = 2 }
M.threat = 2

M.db["nykle_win_gs_memory"] = { version = 1, brute = {}, resolver = {},
    sniper = { v = 2, hs = { shots = 27, hits = 10 }, dt = { shots = 4, hits = 4 } } }

local function step(n)
    for _ = 1, n or 1 do
        e1.props.m_flSimulationTime = e1.props.m_flSimulationTime + 1 / 64
        me.props.m_nTickBase = 1000 + M.tick + 2
        M.step({})
    end
end
local function sniper_head()
    M.fire("player_hurt", { userid = 11, attacker = 12, weapon = "ssg08", dmg_health = 1, hitgroup = 1, health = 99 })
    step(2)
end

local ok, err = pcall(assert(loadfile(SCRIPT_PATH)))
check(ok, "script yuklenemedi: " .. tostring(err))

local dt_cb = ui.reference("RAGE", "Aimbot", "Double tap")
local hs_cb = ui.reference("AA", "Other", "On shot anti-aim")
check(log_has("sniper exploit (hafiza): Hide shots 10/27, Double tap 4/4 kafa isabeti -> Double tap"),
    "yuklemede hafizadaki sniper durumu yazilmadi / DT secilmedi")
me.weapon = 102
step(10)
check(M.items[dt_cb].value == true and M.items[hs_cb].value == false,
    "hafizada DT 4 mermideyken scout DT ile baslamadi")
-- DT kendi 8 mermisini gorene kadar birakilmaz.
for _ = 1, 3 do
    sniper_head()
end
step(4)
check(not log_has("kafa isabeti -> Hide shots"), "DT 7 mermideyken Hide shots'a gecildi")
check(M.items[dt_cb].value == true, "DT 7 mermideyken scout DT'den cikti")
-- 8. mermi: iki tarafin da yeterli verisi var, oranlar karsilastirilir (DT 8/8, HS 10/27 -> HS).
sniper_head()
step(4)
check(log_has("sniper exploit: Hide shots 10/27, Double tap 8/8 kafa isabeti -> Hide shots"),
    "DT 8 mermide oran karsilastirmasi yapilmadi")
check(M.items[hs_cb].value == true, "karsilastirmada daha kotu DT'den cikilmadi")

for _, line in ipairs(M.errors_in_log()) do
    io.stderr:write("LOG ERROR: " .. line .. "\n")
    failures = failures + 1
end
if os.getenv("SHOW_LOG") then
    for _, line in ipairs(M.logs) do
        io.stdout:write(line, "\n")
    end
end
io.stdout:write(("sniper tests done: %d failure(s), %d log lines\n"):format(failures, #M.logs))
os.exit(failures == 0 and 0 or 1)
