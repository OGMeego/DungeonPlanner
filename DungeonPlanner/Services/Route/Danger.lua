-- Danger.lua
-- Danger: zones far above your level and enemy towns.
local _, ns = ...
local Nav = ns.Nav
local P = ns.Private("Nav")

-- ---------------------------------------------------------------------------
-- Danger: zones far above your level. Walking through them costs a lot more, so the plan
-- goes around them when it can, and the steps warn you when it can't.
-- ---------------------------------------------------------------------------

-- Classic level ranges (the game's own numbers are used instead when it gives them).
local ZONE_LEVELS = {
    ["Elwynn Forest"] = { 1, 10 }, ["Dun Morogh"] = { 1, 10 }, ["Teldrassil"] = { 1, 10 }, ["Durotar"] = { 1, 10 },
    ["Mulgore"] = { 1, 10 }, ["Tirisfal Glades"] = { 1, 10 }, ["Westfall"] = { 10, 20 }, ["Loch Modan"] = { 10, 20 },
    ["Darkshore"] = { 10, 20 }, ["The Barrens"] = { 10, 25 }, ["Silverpine Forest"] = { 10, 20 },
    ["Redridge Mountains"] = { 15, 25 }, ["Stonetalon Mountains"] = { 15, 27 }, ["Ashenvale"] = { 18, 30 },
    ["Duskwood"] = { 18, 30 }, ["Wetlands"] = { 20, 30 }, ["Hillsbrad Foothills"] = { 20, 30 },
    ["Thousand Needles"] = { 25, 35 }, ["Alterac Mountains"] = { 30, 40 }, ["Arathi Highlands"] = { 30, 40 },
    ["Desolace"] = { 30, 40 }, ["Stranglethorn Vale"] = { 30, 45 }, ["Dustwallow Marsh"] = { 35, 45 },
    ["Badlands"] = { 35, 45 }, ["Swamp of Sorrows"] = { 35, 45 }, ["Riverglades"] = { 35, 45 },
    ["Feralas"] = { 40, 50 }, ["The Hinterlands"] = { 40, 50 }, ["Tanaris"] = { 40, 50 },
    ["Searing Gorge"] = { 43, 50 }, ["Azshara"] = { 45, 55 }, ["Blasted Lands"] = { 45, 55 },
    ["Un'Goro Crater"] = { 48, 55 }, ["Felwood"] = { 48, 55 }, ["Burning Steppes"] = { 50, 58 },
    ["Western Plaguelands"] = { 51, 58 }, ["Eastern Plaguelands"] = { 53, 60 }, ["Winterspring"] = { 55, 60 },
    ["Deadwind Pass"] = { 55, 60 }, ["Silithus"] = { 55, 60 },
}
Nav.ZONE_LEVELS = ZONE_LEVELS
local DANGER_MARGIN = 4      -- a zone whose lowest level is more than this above you is dangerous
local SAMPLE = 200           -- yards between checks along a walk

local zoneCache = {}
-- The zone a world point is in: { name, min, max } or false.
local function zoneAt(p, contMap)
    if not (contMap and C_Map.GetMapPosFromWorldPos and C_Map.GetMapInfoAtPosition) then return false end
    local k = p.cont .. ":" .. math.floor(p.x / SAMPLE) .. ":" .. math.floor(p.y / SAMPLE)
    if zoneCache[k] ~= nil then return zoneCache[k] end
    local z = false
    local _, mp = ns.Call(C_Map.GetMapPosFromWorldPos, p.cont, CreateVector2D(p.x, p.y), contMap)
    if mp and mp.GetXY then
        local mx, my = mp:GetXY()
        mx, my = ns.Safe(mx), ns.Safe(my)
        local info = mx and my and ns.Call(C_Map.GetMapInfoAtPosition, contMap, mx, my)
        local name = type(info) == "table" and ns.Safe(ns.Field(info, "name"))
        if name then
            local lo, hi = ns.Call(C_Map.GetMapLevels, ns.Field(info, "mapID"))
            lo, hi = ns.Safe(lo), ns.Safe(hi)
            if not (lo and lo > 0) then
                local t = ZONE_LEVELS[name]
                lo, hi = t and t[1], t and t[2]
            end
            z = { name = name, min = lo, max = hi }
        end
    end
    zoneCache[k] = z
    return z
end

-- Known safe swims (Data/SafeLanes.lua): is a world point on one?
local lanes = {}
local function lanesFor(cont)
    if lanes[cont] ~= nil then return lanes[cont] end
    local out = {}
    for _, lane in ipairs(ns.SAFE_LANES and ns.SAFE_LANES[cont] or {}) do
        local pts = {}
        for x, y in lane.points:gmatch("(-?%d+) (-?%d+) ") do tinsert(pts, { x = tonumber(x), y = tonumber(y) }) end
        local r = lane.radius or 150
        local box = { x1 = math.huge, y1 = math.huge, x2 = -math.huge, y2 = -math.huge }
        for _, q in ipairs(pts) do
            box.x1, box.y1 = math.min(box.x1, q.x - r), math.min(box.y1, q.y - r)
            box.x2, box.y2 = math.max(box.x2, q.x + r), math.max(box.y2, q.y + r)
        end
        tinsert(out, { r = r, pts = pts, box = box })
    end
    lanes[cont] = out
    return out
end

function P.onSafeLane(p)
    if not p then return false end
    for _, lane in ipairs(lanesFor(p.cont)) do
        local pts, b = lane.pts, lane.box
        if p.x >= b.x1 and p.x <= b.x2 and p.y >= b.y1 and p.y <= b.y2 then
        for i = 1, #pts - 1 do
            if P.segDist(p, pts[i], pts[i + 1]) <= lane.r then return true end
        end
        end
    end
    return false
end
Nav.OnSafeLane = P.onSafeLane

-- The setting: go around zones far above your level (on), or take the shortest way and
-- only warn about them (off).
function P.avoidDanger() return not (ns.opt and ns.opt.avoidDanger == false) end

-- How much worse than normal walking a zone is for you (1 = fine).
function P.dangerOf(z, level)
    if not (z and z.min) then return 1 end
    local over = z.min - level - DANGER_MARGIN
    if over <= 0 then return 1 end
    return math.min(40, 4 + over * 2)
end

-- Walking time from a to b, made longer through dangerous zones, and the dangerous zones met.
P.hostileTowns = {}
function P.townAt(p)
    for _, t in ipairs(P.hostileTowns) do
        if t.cont == p.cont then
            local dx, dy = t.x - p.x, t.y - p.y
            if dx * dx + dy * dy < t.radius * t.radius then return t end
        end
    end
end

function P.walkCost(a, b, speed, contMap, level)
    local d = P.dist(a, b)
    if d == math.huge then return d end
    if not contMap then return d / speed end
    local n = math.max(1, math.floor(d / SAMPLE))
    local cost, zones = 0, nil
    local prevZone
    for i = 0, n - 1 do
        local t = (i + 0.5) / n
        local sp = { cont = a.cont, x = a.x + (b.x - a.x) * t, y = a.y + (b.y - a.y) * t }
        local z = zoneAt(sp, contMap)
        -- Walking over a zone border away from the known crossings: probably a mountain wall.
        local zn = z and z.name
        if prevZone and zn and zn ~= prevZone and P.crossingOK and not P.crossingOK(prevZone, zn, sp) then
            cost = cost + P.BORDER_PENALTY
        end
        prevZone = zn or prevZone
        local f = P.onSafeLane(sp) and 1 or P.dangerOf(z, level)
        if f > 1 then
            zones = zones or {}
            zones[z.name] = z
            -- "Avoid zones far above my level" off: still warn, but take the shortest way.
            if not P.avoidDanger() then f = 1 end
        end
        -- The other faction's towns: guards. Avoid them unless you're going there.
        local town = P.townAt(sp)
        if town and not b.inTown then
            f = math.max(f, 25)
            zones = zones or {}
            zones[town.name] = { name = town.name, enemy = true }
        end
        cost = cost + (d / n) / speed * f
    end
    return cost, zones
end
Nav.ZoneAt = zoneAt
function Nav._ResetZonesForTest() zoneCache = {} end

-- Teldrassil is an island: you can't walk between it and the mainland.
local islandBoxes
function P.onIsland(p)
    if not islandBoxes then
        islandBoxes = {}
        for _, name in ipairs({ "teldrassil" }) do
            local m = ns.Maps.UiMapByName and ns.Maps.UiMapByName(name)
            local a, b = m and P.worldPos(m, 0, 0), m and P.worldPos(m, 100, 100)
            if a and b then
                tinsert(islandBoxes, { cont = a.cont, x1 = math.min(a.x, b.x), x2 = math.max(a.x, b.x), y1 = math.min(a.y, b.y), y2 = math.max(a.y, b.y) })
            end
        end
    end
    for i, box in ipairs(islandBoxes) do
        if p.cont == box.cont and p.x >= box.x1 and p.x <= box.x2 and p.y >= box.y1 and p.y <= box.y2 then return i end
    end
    return 0
end
