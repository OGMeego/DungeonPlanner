-- Crossings.lua
-- Where you can actually walk from one zone into the next. Mountains wall off many zone
-- borders (Wetlands, Loch Modan, Dun Morogh, Arathi...), and a straight line through them
-- is no route. The planner walks through a known crossing instead, and pays a lot for
-- crossing a border anywhere else. Crossings come from:
--   * a few seeds (the passes everyone uses),
--   * learning: each time you walk from one zone into another, that spot is remembered,
--   * sharing: learned crossings travel to other Dungeon Planner users.
-- Saved: ns.db.crossings = { { a = zone, b = zone, m = uiMap, x, y, n = times seen } }
local _, ns = ...
local L = ns.L
local Nav = ns.Nav
local P = ns.Private("Nav")

local NEAR = 350           -- yards: a border crossing this close to a known one is fine
local PENALTY = 900        -- seconds added for walking over a border somewhere else
local MAX_LEARNED = 400
local WALKED = 90          -- a zone change counts only if you moved less than this (no teleports)

-- The passes on the road from the Horde side into Ironforge, as Dungeon Journal walks it.
local SEEDS = {
    { a = "Arathi Highlands", b = "Wetlands", zone = "Wetlands", x = 49.9, y = 18.2, name = "Thandol Span" },
    { a = "Wetlands", b = "Loch Modan", zone = "Wetlands", x = 52.6, y = 83.0, name = "Dun Algaz" },
    { a = "Loch Modan", b = "Dun Morogh", zone = "Dun Morogh", x = 86.3, y = 48.8, name = "South Gate Outpost" },
    { a = "Hillsbrad Foothills", b = "Arathi Highlands", zone = "Arathi Highlands", x = 20.0, y = 49.0, name = "Thoradin's Wall" },
}

local function pairKey(a, b) if a > b then a, b = b, a end return a .. "|" .. b end

local cache   -- world-positioned crossings: { { cont, x, y, key, name, a, b } }
function P.resetCrossings() cache = nil end

local function learnedList()
    ns.db.crossings = ns.db.crossings or {}
    return ns.db.crossings
end

function P.crossings()
    if cache then return cache end
    cache, P.crossPairs = {}, {}
    local function addOne(c, m, x, y)
        local p = m and P.worldPos(m, x, y)
        if not p then return end
        p.key, p.name, p.a, p.b = pairKey(c.a, c.b), c.name, c.a, c.b
        p.kind = "pass"
        tinsert(cache, p)
        P.crossPairs[p.key] = true
    end
    for _, c in ipairs(SEEDS) do
        addOne(c, ns.Maps.UiMapByName and ns.Maps.UiMapByName(c.zone), c.x, c.y)
    end
    for _, c in ipairs(ns.db and learnedList() or {}) do addOne(c, c.m, c.x, c.y) end
    return cache
end

-- Is this border crossing at point sp fine (near a known crossing, or a border we know
-- nothing about)? Returns true or false.
function P.crossingOK(za, zb, sp)
    if not (za and zb) or za == zb then return true end
    local list = P.crossings()
    local key = pairKey(za, zb)
    if not P.crossPairs[key] then return true end
    for _, c in ipairs(list) do
        if c.key == key and c.cont == sp.cont then
            local dx, dy = c.x - sp.x, c.y - sp.y
            if dx * dx + dy * dy < NEAR * NEAR then return true end
        end
    end
    return false
end
P.BORDER_PENALTY = PENALTY

-- Crossing points as planner nodes for the continents in play.
function P.passNodes(conts)
    local out = {}
    for _, c in ipairs(P.crossings()) do
        local cm = P.continentOf(c.map)
        if cm and conts[cm] then
            tinsert(out, { kind = "pass", cont = c.cont, x = c.x, y = c.y, map = c.map, mx = c.mx, my = c.my,
                name = c.name or L.NAV_PASS_BETWEEN:format(c.a, c.b) })
        end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- Learning
-- ---------------------------------------------------------------------------

function Nav.AddCrossing(a, b, m, x, y, shared)
    if not (a and b and m and x and y) or a == b then return false end
    local list = learnedList()
    local key = pairKey(a, b)
    local here = P.worldPos(m, x, y)
    for _, c in ipairs(list) do
        if pairKey(c.a, c.b) == key then
            local p = P.worldPos(c.m, c.x, c.y)
            if p and here and P.dist(p, here) < NEAR / 2 then
                c.n = (c.n or 1) + 1
                return false
            end
        end
    end
    if #list >= MAX_LEARNED then tremove(list, 1) end
    tinsert(list, { a = a, b = b, m = m, x = math.floor(x * 10) / 10, y = math.floor(y * 10) / 10, n = 1, shared = shared or nil })
    cache = nil
    if not shared and ns.Comm and ns.Comm.Queue then
        ns.Comm.Queue(table.concat({ "X", ns.Comm.Clean(a), ns.Comm.Clean(b), m, ("%.1f"):format(x), ("%.1f"):format(y) }, ns.Comm.SEP))
    end
    return true
end

local last        -- { zone, pos, at }
local function zoneName()
    local z = ns.Safe(ns.Call(GetZoneText))
    return z ~= "" and z or nil
end

local function sample()
    if (IsInInstance and IsInInstance()) or (UnitOnTaxi and UnitOnTaxi("player")) or (IsFlying and IsFlying()) then
        last = nil
        return
    end
    local pos = Nav.PlayerPos()
    if pos then last = { zone = zoneName(), pos = pos, at = GetTime() } end
end

local function zoneChanged()
    local before = last
    sample()
    local now = last
    if not (before and now and before.zone and now.zone and before.zone ~= now.zone) then return end
    if now.at - before.at > 15 or P.dist(before.pos, now.pos) > WALKED then return end
    -- The crossing: halfway between the last spot in the old zone and the first in the new.
    local mx, my = (before.pos.x + now.pos.x) / 2, (before.pos.y + now.pos.y) / 2
    local p = { cont = now.pos.cont, x = mx, y = my }
    local m = now.pos.map
    local mp = m and C_Map.GetMapPosFromWorldPos and select(2, ns.Call(C_Map.GetMapPosFromWorldPos, p.cont, CreateVector2D(mx, my), m))
    local x, y
    if mp and mp.GetXY then x, y = mp:GetXY() x, y = ns.Safe(x), ns.Safe(y) end
    if x and y then Nav.AddCrossing(before.zone, now.zone, m, x * 100, y * 100) end
end

ns.On("ZONE_CHANGED_NEW_AREA", zoneChanged)
ns.Listen("LOGIN", function()
    if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(2, sample) end
end)

if ns.Comm and ns.Comm.Handle then
    ns.Comm.Handle("X", function(parts)
        local m, x, y = tonumber(parts[4]), tonumber(parts[5]), tonumber(parts[6])
        if parts[2] and parts[3] and m and x and y and x >= 0 and x <= 100 and y >= 0 and y <= 100 then
            Nav.AddCrossing(parts[2], parts[3], m, x, y, true)
        end
    end)
end
