-- Resolve.lua
-- Picking the best floors for a dungeon, and learning floors as you play.
local _, ns = ...
local DMap = ns.DMap
local P = ns.Private("DMap")

local floorCache = {}
function DMap.Reset() floorCache = {}; P.cornerCache = {}; P.artCache = {}; P.allMapList = nil end

-- The floors of a dungeon, each with the points that stand on it, plus bosses we couldn't place.
-- result = { floors = { { map, name, points = { { kind, boss?, x, y, learned? } } } }, unplaced = { boss, ... }, method }
function DMap.Floors(spec)
    local cacheKey = spec.key .. ":" .. (spec.instanceID or "")
    if floorCache[cacheKey] then return floorCache[cacheKey] end
    local dj = P.djFor(spec)
    if dj then
        local r = P.djResult(spec, dj)
        floorCache[cacheKey] = r
        return r
    end
    local fm = spec.forever and ns.ForeverMaps and ns.ForeverMaps[spec.forever.name]
    if fm then
        local r = P.foreverMapResult(spec, fm)
        floorCache[cacheKey] = r
        return r
    end
    local static = P.staticFloors(spec)
    if #static > 0 then
        local r = P.staticResult(spec, static)
        floorCache[cacheKey] = r
        return r
    end
    local floorIDs = P.candidateFloors(spec)
    local result = { floors = {}, unplaced = {}, candidates = floorIDs }
    -- No map from the game: our own drawing of the layout, where we have one.
    local sk = #floorIDs == 0 and spec.forever and spec.forever.sketch
    if sk then
        local fl = { map = 0, name = spec.name, sketch = sk, points = {} }
        local fp = spec.forever.mapPins or {}
        if fp.entrance then tinsert(fl.points, { kind = "start", x = fp.entrance[1], y = fp.entrance[2] }) end
        for _, b in ipairs(spec.bosses) do
            local at = fp[b.name]
            if at then tinsert(fl.points, { kind = "boss", boss = b, x = at[1], y = at[2] })
            else tinsert(result.unplaced, b) end
        end
        result.floors = { fl }
        result.method = "sketch"
        floorCache[cacheKey] = result
        return result
    end
    if #floorIDs == 0 then
        for _, b in ipairs(spec.bosses) do tinsert(result.unplaced, b) end
        return result
    end
    -- Best method: the one that puts the most points on these floors.
    local pts = P.worldPoints(spec)
    local best, bestCount, bestIndex = {}, 0, nil
    for i, method in ipairs(P.METHODS) do
        local placed, count = P.placeWith(method, spec, floorIDs, pts)
        if count > bestCount then best, bestCount, bestIndex = placed, count, i end
    end
    result.method = bestIndex
    local byMap = {}
    for _, m in ipairs(floorIDs) do
        local info = P.mapInfo(m)
        local fl = { map = m, name = info and ns.Field(info, "name") or "", points = {} }
        byMap[m] = fl
        tinsert(result.floors, fl)
    end
    local pins = ns.db and ns.db.mapPins and ns.db.mapPins[spec.key] or {}
    for _, p in ipairs(pts) do
        local at = best[p]
        if at then tinsert(byMap[at.map].points, { kind = p.kind, boss = p.boss, mark = p.mark, x = at.x, y = at.y }) end
    end
    -- Forever's new dungeons: spots measured on their map picture (Data/ForeverDB.lua).
    local fp = spec.forever and spec.forever.mapPins
    local first = result.floors[1]
    if fp and first and fp.entrance then
        tinsert(first.points, { kind = "start", x = fp.entrance[1], y = fp.entrance[2] })
    end
    for _, b in ipairs(spec.bosses) do
        local placedAlready = false
        for p, at in pairs(best) do if p.boss == b then placedAlready = true end end
        if not placedAlready then
            local pin = pins[P.key(b.name)]
            local measured = fp and fp[b.name]
            if pin and byMap[pin.m] then
                tinsert(byMap[pin.m].points, { kind = "boss", boss = b, x = pin.x, y = pin.y, learned = true })
            elseif measured and first then
                tinsert(first.points, { kind = "boss", boss = b, x = measured[1], y = measured[2] })
            else
                tinsert(result.unplaced, b)
            end
        end
    end
    -- Floors in the game's own order, with the game's floor names.
    local members = P.groupOf(floorIDs[1])
    if members then
        local order = {}
        for i, mem in ipairs(members) do
            local id = ns.Field(mem, "mapID")
            if id then
                order[id] = i
                if byMap[id] and ns.Field(mem, "name") then byMap[id].name = ns.Field(mem, "name") end
            end
        end
        table.sort(result.floors, function(a, b) return (order[a.map] or 99) < (order[b.map] or 99) end)
    end
    floorCache[cacheKey] = result
    return result
end

-- Learning, called by the tracker while you're inside.
function DMap.LearnFloor(name, uiMapID)
    if not (name and uiMapID) then return end
    local info = P.mapInfo(uiMapID)
    local t = info and ns.Safe(ns.Field(info, "mapType"))
    if not info or (t and t <= 3) or not P.hasArt(uiMapID) then return end
    ns.db.mapFloors = ns.db.mapFloors or {}
    local k = P.key(name)
    local list = ns.db.mapFloors[k] or {}
    for _, m in ipairs(list) do if m == uiMapID then return end end
    tinsert(list, uiMapID)
    ns.db.mapFloors[k] = list
    DMap.Reset()
end

function DMap.LearnPin(name, bossName, uiMapID, x, y)
    if not (name and bossName and uiMapID and x and y) then return end
    ns.db.mapPins = ns.db.mapPins or {}
    local k = P.key(name)
    ns.db.mapPins[k] = ns.db.mapPins[k] or {}
    ns.db.mapPins[k][P.key(bossName)] = { m = uiMapID, x = x, y = y }
    DMap.Reset()
end
