-- Nykle.win GameSense edition: kisiye gore hafiza testleri (tanima, dogrulama, duvar / LBY tarafi).
-- Lua yuklenmeden once hafizaya iki bilinen dusman konur.
package.path = arg[0]:gsub("run_memory_tests.lua$", "") .. "?.lua;" .. package.path
local M = require("mock_gs")
local SCRIPT_PATH = arg[1] or "Nykle_win_gamesense.lua"

local failures = 0
local function check(cond, msg)
    if not cond then
        failures = failures + 1
        io.stderr:write("FAIL: " .. msg .. "\n")
    end
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
local function log_has(pattern)
    return count_log(pattern) > 0
end

M.weapons[101] = { class = "CAK47", m_iClip1 = 30, m_flNextPrimaryAttack = 0, m_iItemDefinitionIndex = 7 }
local function enemy(index, name, steam, origin, yaw)
    return M.player(index, { alive = true, enemy = true, name = name, steam = steam, weapon = 101, origin = origin,
        props = { m_fFlags = 1, m_vecVelocity = { 0, 0, 0 }, m_flDuckAmount = 0, m_flSimulationTime = 10,
            m_angEyeAngles = { 89, yaw, 0 }, m_flLowerBodyYawTarget = yaw, m_iHealth = 100, m_ArmorValue = 100,
            ["m_vecViewOffset[2]"] = 64 } })
end
local me = M.player(1, { alive = true, enemy = false, name = "me", steam = "76561198000000001", weapon = 101,
    origin = { 0, 0, 0 }, props = { m_fFlags = 1, m_vecVelocity = { 0, 0, 0 }, m_flDuckAmount = 0, m_nTickBase = 1000,
        m_MoveType = 2, m_iTeamNum = 2, m_iHealth = 100, m_flNextAttack = 0, m_bIsScoped = 0,
        ["m_vecViewOffset[2]"] = 64, m_totalHitsOnServer = 0 } })
local e1 = enemy(2, "enemy one", "76561198000000002", { 500, 0, 0 }, 180)
local e2 = enemy(3, "enemy two", "76561198000000003", { 0, 600, 0 }, -90)
M.userids = { [11] = 1, [12] = 2, [13] = 3 }
M.threat = 2

-- enemy one: genelde statik, defensive %40; duvarli durumda kanonik +58 (aday 1) 3 kez kafadan vurmus.
-- enemy two: hafizada jitter'ci (ama artik statik oynuyor); acik alanda -58 (aday 2) 2 kez kafadan vurmus.
M.db["nykle_win_gs_memory"] = { version = 1, brute = {}, resolver = {
    ["s:76561198000000002"] = { name = "enemy one", results = {}, states = {},
        profile = { n = 50, jitter = 2, static = 40, spin = 0, xway = 0, random = 0, def = 20, fd = 0 },
        angles = { ["Standing|static|side"] = { { 3, 0 }, { 0, 1 }, { 0, 0 }, { 0, 0 }, { 0, 0 } } } },
    ["s:76561198000000003"] = { name = "enemy two", results = {}, states = {},
        profile = { n = 50, jitter = 40, static = 2, spin = 0, xway = 0, random = 0, def = 0, fd = 0 },
        angles = { ["Standing|static|open"] = { { 0, 0 }, { 2, 0 }, { 0, 0 }, { 0, 0 }, { 0, 0 } } } },
} }

local ok, err = pcall(assert(loadfile(SCRIPT_PATH)))
check(ok, "script yuklenemedi: " .. tostring(err))
check(log_has("hafiza: 2 oyuncu"), "hafiza yuklenmedi")

local function step(n)
    for _ = 1, n or 1 do
        for i = 2, 3 do
            local p = M.players[i]
            p.props.m_flSimulationTime = p.props.m_flSimulationTime + 1 / 64
        end
        me.props.m_nTickBase = 1000 + M.tick + 2
        M.step({})
    end
end
local id = 1
local function shoot(target, reason, hitgroup)
    M.fire("aim_fire", { id = id, target = target, hit_chance = 85, hitgroup = 1, damage = 120, backtrack = 0,
        teleported = false, extrapolated = false })
    step(4)
    if reason == nil then
        M.fire("aim_hit", { id = id, target = target, hit_chance = 85, hitgroup = hitgroup or 1, damage = 100 })
    else
        M.fire("aim_miss", { id = id, target = target, hit_chance = 85, hitgroup = 1, reason = reason })
    end
    id = id + 1
    step(4)
end

-- 1) Hafizadaki aliskanlik canli desen olculene kadar kullanilir, sonra dogrulanir / duzeltilir.
step(2)
check(log_has("enemy one tanindi (hafiza)") and log_has("genelde statik (dogrulanacak)"), "tanima logu yok")
check(log_has("defensive %3") and log_has("Standing static duvarli aci 58"), "tanima logunda aliskanlik / aci yok")
check(log_has("enemy two jitter -> safe points Prefer (veri yok, hafizadan, dogrulanacak)"),
    "hafizadaki jitter aliskanligi canli desen yokken kullanilmadi")
step(12)
check(log_has("enemy one hafiza dogrulandi: genelde static, simdi static"), "dogru hafiza dogrulanmadi")
check(log_has("enemy two hafiza tutmadi: genelde jitter, simdi static"), "yanlis hafiza duzeltilmedi")

-- 2) Duvar L: hafizada kafadan vuran aci bu haritadaki iki iskadan sonra hemen denenir (dogrulanacak).
M.block_fn = function(x1, y1, z1, x2, y2, z2)
    if math.abs(x2 - 500) < 60 and y2 > 10 then
        return 0.5
    end
end
step(6)
shoot(2, "?")
shoot(2, "?")
check(log_has("hafizada kafadan vuran aci (3 kafa), dogrulanacak"), "hafizadaki aci ile baslamadi")
check(M.plist[2] ~= nil and M.plist[2]["Force body yaw"] == true and M.plist[2]["Force body yaw value"] == 58,
    "duvar L'de hafizadaki aci (+58) yazilmadi: " .. tostring(M.plist[2] and M.plist[2]["Force body yaw value"]))
-- Dusman siperin obur tarafina gecti (duvar R): aci aynalanir.
M.block_fn = function(x1, y1, z1, x2, y2, z2)
    if math.abs(x2 - 500) < 60 and y2 < -10 then
        return 0.5
    end
end
step(6)
check(M.plist[2]["Force body yaw value"] == -58, "duvar R'de aci aynalanmadi: " .. tostring(M.plist[2]["Force body yaw value"]))
shoot(2, nil, 1)
check(log_has("hafizadaki aci (body yaw -58") and log_has("dogrulandi: kafa isabeti"), "hafizadaki aci dogrulanmadi")

-- 3) enemy two: hafizadaki aci tutmazsa yazilir, siradaki denenir; LBY tarafi bilgisi.
M.block_fn = nil
M.yaw_mode = nil
shoot(3, "?")
shoot(3, "?")
check(count_log("hafizada kafadan vuran aci (2 kafa), dogrulanacak") == 1, "enemy two hafizadaki aci ile baslamadi")
shoot(3, "?")
check(log_has("tutmadi, siradaki denenecek"), "tutmayan hafiza acisi yazilmadi")
e2.props.m_flLowerBodyYawTarget = -90 - 58
step(6)
shoot(3, "?")
check(log_has("(lby "), "LBY tarafi bilgisi kullanilmadi")

-- 4) Kapanis: ogrenilenler hafizaya yazilir (kanonik aday 1 artik 4 kafa).
M.fire("shutdown", {})
local saved = M.db["nykle_win_gs_memory"].resolver["s:76561198000000002"]
local slot = saved and saved.angles and saved.angles["Standing|static|side"]
check(slot ~= nil and slot[1][1] == 4, "duvarli aci sonucu hafizaya yazilmadi: " .. tostring(slot and slot[1][1]))
local two = M.db["nykle_win_gs_memory"].resolver["s:76561198000000003"]
check(two ~= nil and two.profile ~= nil and two.profile.jitter < 40, "yanlis aliskanlik hafizada duzeltilmedi")

for _, line in ipairs(M.errors_in_log()) do
    io.stderr:write("LOG ERROR: " .. line .. "\n")
    failures = failures + 1
end
if os.getenv("SHOW_LOG") then
    for _, line in ipairs(M.logs) do
        io.stdout:write(line, "\n")
    end
end
io.stdout:write(("memory tests done: %d failure(s), %d log lines\n"):format(failures, #M.logs))
os.exit(failures == 0 and 0 or 1)
