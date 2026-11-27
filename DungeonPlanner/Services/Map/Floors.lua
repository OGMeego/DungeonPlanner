-- Floors.lua
-- Finding a dungeon's floors.
local _, ns = ...
local DUNGEON_TYPE = 4
local P = ns.Private("DMap")

-- ---------------------------------------------------------------------------
-- Finding floors
-- ---------------------------------------------------------------------------

function P.mapInfo(id)
    local info = ns.Call(C_Map.GetMapInfo, id)
    return type(info) == "table" and info or nil
end

P.artCache = {}
function P.hasArt(id)
    if P.artCache[id] ~= nil then return P.artCache[id] end
    local layers = ns.Call(C_Map.GetMapArtLayers, id)
    local ok = type(layers) == "table" and layers[1] ~= nil
    if ok then
        local tex = ns.Call(C_Map.GetMapArtLayerTextures, id, 1)
        ok = type(tex) == "table" and #tex > 0
    end
    P.artCache[id] = ok
    return ok
end

-- Every map the client knows, with its name. Forever's map numbers and map types don't
-- always match other clients, so dungeons are matched by name, not by type or number.
P.allMapList = nil -- { { id, key, type } }
local function allMaps()
    if P.allMapList then return P.allMapList end
    P.allMapList = {}
    for _, range in ipairs(P.SCAN_RANGES) do
        for id = range[1], range[2] do
            local info = P.mapInfo(id)
            if info then
                local t = ns.Safe(ns.Field(info, "mapType"))
                -- Skip the world and continents; everything else may be a dungeon floor.
                if t == nil or t >= 3 then
                    tinsert(P.allMapList, { id = id, key = P.key(ns.Safe(ns.Field(info, "name"))), type = t })
                end
            end
        end
    end
    return P.allMapList
end
-- Corners of a floor in world coordinates (and which instance it belongs to).
P.cornerCache = {}
function P.corners(m)
    local c = P.cornerCache[m]
    if c ~= nil then return c or nil end
    c = false
    if C_Map.GetWorldPosFromMapPos and CreateVector2D then
        local inst, p0 = ns.Call(C_Map.GetWorldPosFromMapPos, m, CreateVector2D(0, 0))
        local _, p1 = ns.Call(C_Map.GetWorldPosFromMapPos, m, CreateVector2D(1, 1))
        if p0 and p1 and p0.GetXY and p1.GetXY then
            local ax, ay = p0:GetXY()
            local bx, by = p1:GetXY()
            ax, ay, bx, by = ns.Safe(ax), ns.Safe(ay), ns.Safe(bx), ns.Safe(by)
            if ax and ay and bx and by and ax ~= bx and ay ~= by then
                c = { inst = ns.Safe(inst), ax = ax, ay = ay, bx = bx, by = by }
            end
        end
    end
    P.cornerCache[m] = c
    return c or nil
end

function P.groupOf(m)
    local group = ns.Call(C_Map.GetMapGroupID, m)
    local members = group and ns.Call(C_Map.GetMapGroupMembersInfo, group)
    return type(members) == "table" and members or nil
end

function P.candidateFloors(spec)
    local list, seen = {}, {}
    local function add(m)
        if m and not seen[m] and P.mapInfo(m) and P.hasArt(m) then
            seen[m] = true
            tinsert(list, m)
        end
    end
    -- 1. Floors you've stood on in this dungeon.
    local learned = ns.db and ns.db.mapFloors and ns.db.mapFloors[spec.key]
    for _, m in ipairs(learned or {}) do add(m) end
    -- 2. Maps named like the dungeon (dungeon-type maps first).
    if #list == 0 then
        local keys = { [spec.key] = true }
        for _, a in ipairs(spec.forever and spec.forever.aliases or {}) do keys[P.key(a)] = true end
        for pass = 1, 2 do
            for _, m in ipairs(allMaps()) do
                if m.key and keys[m.key] and ((pass == 1) == (m.type == DUNGEON_TYPE)) then add(m.id) end
            end
            if #list > 0 then break end
        end
    end
    -- 3. The usual map numbers for classic dungeons, if they really belong to this dungeon.
    if #list == 0 then
        for _, m in ipairs(spec.instanceID and P.FLOORS[spec.instanceID] or {}) do
            local info = P.mapInfo(m)
            local c = P.corners(m)
            local k = info and P.key(ns.Safe(ns.Field(info, "name")))
            if (c and c.inst == spec.instanceID) or (k and k == spec.key) then add(m) end
        end
    end
    -- 4. Any map whose corners lie in this instance.
    if #list == 0 and spec.instanceID then
        for _, m in ipairs(allMaps()) do
            if m.type ~= 3 then
                local c = P.corners(m.id)
                if c and c.inst == spec.instanceID then add(m.id) end
            end
        end
    end
    -- Add the rest of a floor's group (other floors of the same dungeon).
    for i = 1, #list do
        for _, mem in ipairs(P.groupOf(list[i]) or {}) do add(ns.Field(mem, "mapID")) end
    end
    return list
end
