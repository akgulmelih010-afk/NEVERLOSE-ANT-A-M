-- Nykle.win primordial: menu dokumu (tools/build_prim_cfg.py kullanir).
-- Kullanim: luajit tools/prim_menu_dump.lua primordial/Nykle.win.lua
-- Script'i sahte (her seyi kabul eden) bir primordial API ile yukler, sadece menu.add_* / set /
-- add_color_picker / set_group_column cagrilarini kaydeder ve satir satir yazar:
--   G <tab> grup <tab> kolon(1-based veya -)
--   E <tab> grup <tab> ad <tab> tur <tab> deger [<tab> liste uzunlugu]
--   C <tab> grup <tab> sahip ad <tab> renk adi <tab> r,g,b,a
-- Oyun / dosya / ffi cagrilari bos doner; script'in kendi pcall'lari hatalari yutar.
local path = arg[1]
local any
local function any_fn() return any end
any = setmetatable({}, {
    __index = function() return any end,
    __call = function() return any end,
    __add = function() return 0 end, __sub = function() return 0 end, __mul = function() return 0 end,
    __div = function() return 0 end, __mod = function() return 0 end, __unm = function() return 0 end,
    __concat = function() return "" end, __len = function() return 0 end,
    __eq = function() return false end, __lt = function() return false end, __le = function() return false end,
})

local groups, gorder, elems, colors = {}, {}, {}, {}
local function group(g)
    if groups[g] == nil then
        groups[g] = { col = "-" }
        gorder[#gorder + 1] = g
    end
end

local function element(kind, g, name, value, extra)
    group(g)
    local e = { kind = kind, g = g, name = name, value = value, extra = extra }
    elems[#elems + 1] = e
    local obj = {}
    obj.get = function() return e.value end
    obj.set = function(_, v) e.value = v end
    obj.add_color_picker = function(_, cname, col)
        colors[#colors + 1] = { g = g, host = name, name = cname, col = col }
        return setmetatable({ get = function() return col end, set = function() end }, { __index = any_fn })
    end
    return setmetatable(obj, { __index = function() return any_fn end })
end

local menu = {
    add_checkbox = function(g, name, def) return element("cb", g, name, def == true) end,
    add_slider = function(g, name, lo, hi, step, prec) return element("sl", g, name, lo, { lo, hi, step, prec }) end,
    add_selection = function(g, name, items) return element("sel", g, name, 1, { #items }) end,
    add_text = function(g, name) group(g); return setmetatable({}, { __index = function() return any_fn end }) end,
    add_button = function(g, name) group(g); return setmetatable({}, { __index = function() return any_fn end }) end,
    set_group_column = function(g, c) group(g); groups[g].col = c end,
}
setmetatable(menu, { __index = function() return any_fn end })

local function color_t(r, g, b, a) return { r = r or 255, g = g or 255, b = b or 255, a = a or 255 } end

local env = setmetatable({
    menu = menu, color_t = color_t,
    require = function(m) error("no module " .. tostring(m)) end,
    print = function() end,
}, { __index = function(_, k)
    local v = _G[k]
    if v ~= nil and k ~= "io" and k ~= "os" and k ~= "ffi" and k ~= "jit" and k ~= "load" and k ~= "loadstring"
        and k ~= "dofile" and k ~= "loadfile" and k ~= "require" and k ~= "package" then
        return v
    end
    return any
end })

local chunk = assert(loadfile(path))
setfenv(chunk, env)
local ok, err = pcall(chunk)
if not ok then
    io.stderr:write("script load error (ignored after menu build): " .. tostring(err) .. "\n")
end

local function out(...) io.write(table.concat({ ... }, "\t"), "\n") end
for _, g in ipairs(gorder) do out("G", g, tostring(groups[g].col)) end
for _, e in ipairs(elems) do
    local v = e.value
    if type(v) == "boolean" then v = v and "true" or "false" end
    if e.kind == "sel" then
        out("E", e.g, e.name, e.kind, string.format("%d", v), tostring(e.extra[1]))
    else
        out("E", e.g, e.name, e.kind, tostring(v))
    end
end
for _, c in ipairs(colors) do
    local col = c.col or {}
    out("C", c.g, c.host, c.name, string.format("%d,%d,%d,%d", col.r or 255, col.g or 255, col.b or 255, col.a or 255))
end
