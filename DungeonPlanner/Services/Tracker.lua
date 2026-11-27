-- Tracker: inside a dungeon, a small list beside the quest tracker with the bosses in
-- order (ticked off as they die) and your quests for this dungeon with their progress.
-- For Forever's new dungeons it learns the boss order from your kills and shares nothing.
local _, ns = ...
local P = ns.Private("Tracker")
local L = ns.L

local T = {}
ns.Tracker = T

P.frame = nil
P.here = {}          -- { map, name } of the dungeon we are in
P.kills = {}         -- map -> { [encounterID or name] = true } for this visit
local MAX_LINES = 22

-- ---------------------------------------------------------------------------
-- Boss lists
-- ---------------------------------------------------------------------------

local ejCache = {}

-- Boss names from the game's encounter journal data, when the client has it.
local function ejBosses(instanceName)
    if not (EJ_GetNumTiers and EJ_SelectTier and EJ_GetInstanceByIndex and EJ_SelectInstance and EJ_GetEncounterInfoByIndex) then
        return nil
    end
    local want = ns.Data.Normalize(instanceName)
    if not want then return nil end
    if ejCache[want] ~= nil then return ejCache[want] or nil end
    local found = false
    for tier = 1, (ns.Call(EJ_GetNumTiers) or 0) do
        pcall(EJ_SelectTier, tier)
        for _, raid in ipairs({ false, true }) do
            for i = 1, 200 do
                local id, name = ns.Call(EJ_GetInstanceByIndex, i, raid)
                if not id then break end
                if ns.Data.Normalize(ns.Safe(name)) == want then
                    pcall(EJ_SelectInstance, id)
                    local list = {}
                    for j = 1, 40 do
                        local bossName = ns.Call(EJ_GetEncounterInfoByIndex, j, id)
                        bossName = ns.Safe(bossName)
                        if not bossName then break end
                        tinsert(list, bossName)
                    end
                    found = #list > 0 and list
                    break
                end
            end
            if found then break end
        end
        if found then break end
    end
    ejCache[want] = found or false
    return found or nil
end

-- Bosses in order for a dungeon by name: database, then game data, then what we learned.
function T.BossesForName(name)
    local key = ns.Data.Normalize(name)
    for _, d in pairs(ns.DB.dungeons) do
        if ns.Data.Normalize(d.name) == key then
            local out = {}
            for _, b in ipairs(d.bosses) do tinsert(out, b[3]) end
            return out
        end
    end
    local f = ns.ForeverFor and ns.ForeverFor(name)
    if f then
        local out = {}
        for _, b in ipairs(f.bosses) do if not b.optional then tinsert(out, b.name) end end
        return out
    end
    local ej = ejBosses(name)
    if ej then return ej end
    local learned = ns.db and ns.db.learnedBosses and ns.db.learnedBosses[key]
    return learned and CopyTable(learned) or {}
end

function T.Kills(mapID) return P.kills[mapID] or {} end

-- Kills this visit for a dungeon by name (Forever dungeons the database has no ID for).
function T.KillsByName(name)
    local k = ns.Data.Normalize(name)
    if P.here.name and ns.Data.Normalize(P.here.name) == k and P.here.map then return P.kills[P.here.map] or {} end
    if P.here.lastName and ns.Data.Normalize(P.here.lastName) == k and P.here.lastMap then return P.kills[P.here.lastMap] or {} end
    local f = ns.ForeverFor and ns.ForeverFor(name)
    if f and P.here.name and ns.ForeverFor(P.here.name) == f and P.here.map then return P.kills[P.here.map] or {} end
    return {}
end

-- The floor you're standing on, and where (inside dungeons the game may hide the spot).
function P.myFloor()
    if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
    local m = ns.Safe(ns.Call(C_Map.GetBestMapForUnit, "player"))
    if not m then return nil end
    local pos = C_Map.GetPlayerMapPosition and ns.Call(C_Map.GetPlayerMapPosition, m, "player")
    local x, y
    if pos and pos.GetXY then x, y = pos:GetXY() x, y = ns.Safe(x), ns.Safe(y) end
    if x and y and x == 0 and y == 0 then x, y = nil, nil end
    return m, x, y
end
