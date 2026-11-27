-- Placing.lua
-- Placing bosses, the entrance and quest marks on floors.
local _, ns = ...
local L = ns.L
local DMap = ns.DMap
local P = ns.Private("DMap")

-- ---------------------------------------------------------------------------
-- Placing points
-- ---------------------------------------------------------------------------

local function inRange(x, y)
    return x and y and x >= -0.01 and x <= 1.01 and y >= -0.01 and y <= 1.01
end

P.METHODS = {
    -- The game's own conversion, both axis orders.
    function(spec, m, wx, wy)
        if not (spec.instanceID and C_Map.GetMapPosFromWorldPos and CreateVector2D) then return end
        local _, pos = ns.Call(C_Map.GetMapPosFromWorldPos, spec.instanceID, CreateVector2D(wx, wy), m)
        if pos and pos.GetXY then local x, y = pos:GetXY() return ns.Safe(x), ns.Safe(y) end
    end,
    function(spec, m, wx, wy)
        if not (spec.instanceID and C_Map.GetMapPosFromWorldPos and CreateVector2D) then return end
        local _, pos = ns.Call(C_Map.GetMapPosFromWorldPos, spec.instanceID, CreateVector2D(wy, wx), m)
        if pos and pos.GetXY then local x, y = pos:GetXY() return ns.Safe(x), ns.Safe(y) end
    end,
    -- Our own math from the floor's corners: map x runs along world Y, map y along world X.
    function(spec, m, wx, wy)
        local c = P.corners(m)
        if not c or (c.inst and spec.instanceID and c.inst ~= spec.instanceID) then return end
        return (wy - c.ay) / (c.by - c.ay), (wx - c.ax) / (c.bx - c.ax)
    end,
    function(spec, m, wx, wy)
        local c = P.corners(m)
        if not c or (c.inst and spec.instanceID and c.inst ~= spec.instanceID) then return end
        return (wx - c.ax) / (c.bx - c.ax), (wy - c.ay) / (c.by - c.ay)
    end,
}

function P.worldPoints(spec)
    local pts = {}
    if spec.start then tinsert(pts, { kind = "start", wx = spec.start[1], wy = spec.start[2] }) end
    for _, b in ipairs(spec.bosses) do
        if b.wx then tinsert(pts, { kind = "boss", boss = b, wx = b.wx, wy = b.wy }) end
    end
    for _, mk in ipairs(spec.marks or {}) do
        tinsert(pts, { kind = "quest", mark = mk, wx = mk.wx, wy = mk.wy })
    end
    return pts
end

-- Place every point with one method; returns placements { [point] = { map, x, y } } and a count.
function P.placeWith(method, spec, floors, pts)
    local placed, count = {}, 0
    for _, p in ipairs(pts) do
        for _, m in ipairs(floors) do
            local x, y = method(spec, m, p.wx, p.wy)
            if inRange(x, y) then
                placed[p] = { map = m, x = x, y = y }
                count = count + 1
                break
            end
        end
    end
    return placed, count
end

-- Floors from our own data (Data/Floors.lua): the picture files and the world boundaries,
-- so the map works even when the game's map system has nothing for the dungeon.
function P.staticFloors(spec)
    local list = {}
    -- The reference maps first (Data/MapRef.lua): the right game pictures, with checked boss spots.
    local ref = ns.MapRef and spec.instanceID and ns.MapRef[spec.instanceID]
    if ref then
        for i, f in ipairs(ref.floors) do
            local fd = f[2] and ns.FloorData and ns.FloorData[f[2]]
            tinsert(list, { map = f[2] or -i, name = fd and fd[1] or (L.MAP_FLOOR):format(i), tilePath = f[1],
                minX = fd and fd[2], minY = fd and fd[3], maxX = fd and fd[4], maxY = fd and fd[5], points = {}, ref = ref })
        end
        return list
    end
    for _, m in ipairs(spec.instanceID and P.FLOORS[spec.instanceID] or {}) do
        local f = ns.FloorData and ns.FloorData[m]
        if f then
            tinsert(list, { map = m, name = f[1], minX = f[2], minY = f[3], maxX = f[4], maxY = f[5], tiles = f[6], points = {} })
        end
    end
    return list
end

-- World X/Y -> 0..1 on a floor picture (map x runs east = world Y falling, map y south = world X falling).
local function onStatic(fl, wx, wy)
    if not fl.minX then return nil end
    return (fl.maxY - wy) / (fl.maxY - fl.minY), (fl.maxX - wx) / (fl.maxX - fl.minX)
end
DMap.OnStatic = onStatic

function P.staticResult(spec, floors)
    local result = { floors = floors, unplaced = {}, candidates = {}, method = "data", static = true }
    for _, fl in ipairs(floors) do tinsert(result.candidates, fl.map) end
    local pins = ns.db and ns.db.mapPins and ns.db.mapPins[spec.key] or {}
    local byMap = {}
    for _, fl in ipairs(floors) do byMap[fl.map] = fl end
    -- Reference spots: entrance and bosses by name.
    local ref = floors[1] and floors[1].ref
    local refBoss = {}
    if ref then
        result.method = "reference"
        if ref.entrance and floors[ref.entrance[1]] then
            tinsert(floors[ref.entrance[1]].points, { kind = "start", x = ref.entrance[2], y = ref.entrance[3] })
        end
        for _, rb in ipairs(ref.bosses) do refBoss[P.key(rb[1])] = rb end
        for _, b in ipairs(spec.bosses) do
            local rb = refBoss[P.key(b.name)]
            if rb and floors[rb[2]] then
                tinsert(floors[rb[2]].points, { kind = "boss", boss = b, x = rb[3], y = rb[4] })
                b.refPlaced = true
            end
        end
    end
    for _, p in ipairs(P.worldPoints(spec)) do
      if not (ref and (p.kind == "start" or (p.kind == "boss" and p.boss.refPlaced))) then
        -- Floors overlap where a dungeon has several levels: take the most zoomed-in one.
        local best, bx, by, barea
        for _, fl in ipairs(floors) do
            local x, y = onStatic(fl, p.wx, p.wy)
            if x and inRange(x, y) then
                local area = (fl.maxX - fl.minX) * (fl.maxY - fl.minY)
                if not barea or area < barea - 1 then best, bx, by, barea = fl, x, y, area end
            end
        end
        local placed = best ~= nil
        if best then tinsert(best.points, { kind = p.kind, boss = p.boss, mark = p.mark, x = bx, y = by }) end
        if not placed and p.kind == "boss" then
            local pin = pins[P.key(p.boss.name)]
            if pin and byMap[pin.m] then
                tinsert(byMap[pin.m].points, { kind = "boss", boss = p.boss, x = pin.x, y = pin.y, learned = true })
            else
                tinsert(result.unplaced, p.boss)
            end
        end
      end
    end
    -- Bosses with no position at all.
    for _, b in ipairs(spec.bosses) do
        if not b.wx and not b.refPlaced then tinsert(result.unplaced, b) end
    end
    return result
end

-- Forever's new dungeons: our drawn maps (Data/ForeverMaps.lua), or the game's own picture when
-- Forever's files have it. Bosses go where the reference puts them.
local MEDIA = "Interface\\AddOns\\DungeonPlanner\\Media\\Maps\\"
local function gameHas(prefix)
    if not GetFileIDFromPath then return false end
    local id = ns.Call(GetFileIDFromPath, prefix .. "1")
    return id ~= nil and id ~= 0
end
DMap.GameHas = gameHas

function P.foreverMapResult(spec, fm)
    local result = { floors = {}, unplaced = {}, candidates = {}, method = "drawn", static = true }
    for i, f in ipairs(fm.floors) do
        local fl = { map = -i, name = f[2], points = {} }
        for _, g in ipairs(f.game or {}) do
            if gameHas(g) then fl.tilePath = g break end
        end
        if not fl.tilePath then fl.image = MEDIA .. f[1] end
        tinsert(result.floors, fl)
    end
    if fm.entrance and result.floors[fm.entrance[1]] then
        tinsert(result.floors[fm.entrance[1]].points, { kind = "start", x = fm.entrance[2], y = fm.entrance[3] })
    end
    local spot = {}
    for _, rb in ipairs(fm.bosses) do spot[P.key(rb[1])] = rb end
    for _, b in ipairs(spec.bosses) do
        local rb = spot[P.key(b.name)] or (b.alias and spot[P.key(b.alias)])
        if rb and result.floors[rb[2]] then
            tinsert(result.floors[rb[2]].points, { kind = "boss", boss = b, x = rb[3], y = rb[4] })
        else
            tinsert(result.unplaced, b)
        end
    end
    return result
end

-- The Dungeon Journal maps (Data/DJMaps.lua): pictures, patches and boss spots for every dungeon.
function P.djFor(spec)
    local dj = ns.DJMaps
    if not dj then return nil end
    return (spec.instanceID and dj[spec.instanceID]) or (spec.forever and dj[spec.forever.name]) or dj[spec.name]
end
DMap.DJFor = P.djFor

function P.djResult(spec, dj)
    local result = { floors = {}, unplaced = {}, candidates = {}, method = "dj", static = true }
    for i, f in ipairs(dj.floors) do
        local fd = f.uiMapID and ns.FloorData and ns.FloorData[f.uiMapID]
        local fl = { map = f.uiMapID or -i, name = f.label or (fd and fd[1]) or spec.name, points = {},
            image = f.tex, right = f.right or 1, bottom = f.bottom or 1, patches = f.patches }
        if not f.tex and f.tiles then
            fl.tilePath = f.tiles
            -- the game's own picture: its world bounds fit, so quest markers can be placed too
            if fd then fl.minX, fl.minY, fl.maxX, fl.maxY = fd[2], fd[3], fd[4], fd[5] end
        end
        tinsert(result.floors, fl)
    end
    if dj.entrance and result.floors[dj.entrance[1]] then
        tinsert(result.floors[dj.entrance[1]].points, { kind = "start", x = dj.entrance[2], y = dj.entrance[3] })
    end
    local spot = {}
    for _, rb in ipairs(dj.bosses) do
        spot[P.key(rb[1])] = rb
        for part in rb[1]:gmatch("[^/]+") do spot[P.key(strtrim(part))] = spot[P.key(strtrim(part))] or rb end
    end
    for _, b in ipairs(spec.bosses) do
        local rb = spot[P.key(b.name)] or (b.alias and spot[P.key(b.alias)])
        if rb and result.floors[rb[2]] then
            tinsert(result.floors[rb[2]].points, { kind = "boss", boss = b, x = rb[3], y = rb[4] })
            b.djPlaced = true
        end
    end
    -- Anything else with a world position (bosses not on the reference, quest markers): on the
    -- game's own pictures, by their bounds; the most zoomed-in floor wins.
    for _, p in ipairs(P.worldPoints(spec)) do
        if p.kind ~= "start" and not (p.kind == "boss" and p.boss.djPlaced) then
            local best, bx, by, barea
            for _, fl in ipairs(result.floors) do
                if fl.minX then
                    local x, y = (fl.maxY - p.wy) / (fl.maxY - fl.minY), (fl.maxX - p.wx) / (fl.maxX - fl.minX)
                    if inRange(x, y) then
                        local area = (fl.maxX - fl.minX) * (fl.maxY - fl.minY)
                        if not barea or area < barea - 1 then best, bx, by, barea = fl, x, y, area end
                    end
                end
            end
            if best then
                tinsert(best.points, { kind = p.kind, boss = p.boss, mark = p.mark, x = bx, y = by })
            elseif p.kind == "boss" then
                tinsert(result.unplaced, p.boss)
            end
        end
    end
    -- Bosses the reference maps don't cover (e.g. Lower Blackrock Spire): add the game's own
    -- floors for them and place them by their world position.
    if #result.unplaced > 0 and spec.instanceID then
        local have = {}
        for _, fl in ipairs(result.floors) do have[fl.map] = true end
        local extra = {}
        for _, fl in ipairs(P.staticFloors({ instanceID = spec.instanceID })) do
            if not have[fl.map] and fl.minX and not fl.ref then tinsert(extra, fl) end
        end
        local still, used = {}, {}
        for _, b in ipairs(result.unplaced) do
            local best, bx, by, barea
            if b.wx then
                for _, fl in ipairs(extra) do
                    local x, y = onStatic(fl, b.wx, b.wy)
                    if x and inRange(x, y) then
                        local area = (fl.maxX - fl.minX) * (fl.maxY - fl.minY)
                        if not barea or area < barea - 1 then best, bx, by, barea = fl, x, y, area end
                    end
                end
            end
            if best then
                tinsert(best.points, { kind = "boss", boss = b, x = bx, y = by })
                if not used[best] then used[best] = true; tinsert(result.floors, best) end
            else
                tinsert(still, b)
            end
        end
        result.unplaced = still
    end
    for _, b in ipairs(spec.bosses) do
        if not b.wx and not b.djPlaced then tinsert(result.unplaced, b) end
    end
    return result
end
