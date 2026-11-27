-- Maps: turn database places (area ID + x/y in percent) into the game's map waypoints.
local _, ns = ...
local L = ns.L

local Maps = {}
ns.Maps = Maps

local zoneIndex       -- lowercase localized zone name -> uiMapID
local areaCache = {}

local ZONE_TYPE = (Enum and Enum.UIMapType and Enum.UIMapType.Zone) or 3

local function buildIndex()
    zoneIndex = {}
    if not (C_Map and C_Map.GetMapInfo) then return end
    for id = 1, 4000 do
        local info = ns.Call(C_Map.GetMapInfo, id)
        if type(info) == "table" and ns.Field(info, "mapType") == ZONE_TYPE then
            local name = ns.Field(info, "name")
            if type(name) == "string" and not zoneIndex[strlower(name)] then
                zoneIndex[strlower(name)] = id
            end
        end
    end
end

-- Forget cached map lookups (after the game's map data changes).
function Maps.Reset()
    zoneIndex = nil
    wipe(areaCache)
end

function Maps.UiMapByName(name)
    if not zoneIndex then buildIndex() end
    if not name then return nil end
    local m = zoneIndex[strlower(name)]
    if m then return m end
    -- Loose match ("Stranglethorn" vs "Stranglethorn Vale", "The Riverglades" vs "Riverglades").
    local want = ns.Data.Normalize(name)
    for zname, id in pairs(zoneIndex) do
        local k = ns.Data.Normalize(zname)
        if k == want or (#want >= 6 and (k:find(want, 1, true) or want:find(k, 1, true))) then return id end
    end
end

-- Localized zone name for an area ID (falls back to the database's English name).
function Maps.AreaName(areaID)
    if not areaID then return nil end
    local name = ns.Call(C_Map and C_Map.GetAreaInfo, areaID)
    if type(name) == "string" and name ~= "" then return name end
    return ns.DB and ns.DB.zones[areaID]
end

function Maps.UiMapForArea(areaID)
    if not areaID then return nil end
    if areaCache[areaID] ~= nil then return areaCache[areaID] or nil end
    if not zoneIndex then buildIndex() end
    local id
    for _, name in ipairs({ Maps.AreaName(areaID), ns.DB and ns.DB.zones[areaID] }) do
        if type(name) == "string" then
            id = zoneIndex[strlower(name)]
            if id then break end
        end
    end
    areaCache[areaID] = id or false
    return id
end

-- Put the game's own map pin on a place. Returns true when set.
function Maps.Waypoint(areaID, x, y, label, approximate)
    if not (areaID and x and y) then return false end
    local uiMapID = Maps.UiMapForArea(areaID)
    local zone = Maps.AreaName(areaID) or "?"
    if not (uiMapID and C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates) then
        ns.Print(L.WAYPOINT_TEXT:format(label or "", zone, x, y))
        return false
    end
    if C_Map.CanSetUserWaypointOnMap and not ns.Call(C_Map.CanSetUserWaypointOnMap, uiMapID) then
        ns.Print(L.WAYPOINT_TEXT:format(label or "", zone, x, y))
        return false
    end
    local point = UiMapPoint.CreateFromCoordinates(uiMapID, x / 100, y / 100)
    local ok = pcall(C_Map.SetUserWaypoint, point)
    local fmt = ok and (approximate and L.WAYPOINT_APPROX or L.WAYPOINT_SET) or L.WAYPOINT_TEXT
    ns.Print(fmt:format(label or "", zone, x, y))
    return ok
end

-- Map pin from a game map ID (positions we learned ourselves).
function Maps.WaypointUi(uiMapID, x, y, label)
    if not (uiMapID and x and y and C_Map and C_Map.SetUserWaypoint and UiMapPoint) then return false end
    local info = ns.Call(C_Map.GetMapInfo, uiMapID)
    local zone = type(info) == "table" and ns.Field(info, "name") or "?"
    local ok = pcall(C_Map.SetUserWaypoint, UiMapPoint.CreateFromCoordinates(uiMapID, x / 100, y / 100))
    ns.Print((ok and L.WAYPOINT_SET or L.WAYPOINT_TEXT):format(label or "", zone, x, y))
    return ok
end

function Maps.UiPlaceText(uiMapID, x, y)
    local info = ns.Call(C_Map and C_Map.GetMapInfo, uiMapID)
    local zone = type(info) == "table" and ns.Field(info, "name")
    if not zone then return nil end
    if x and y then return ("%s (%d, %d)"):format(zone, floor(x + 0.5), floor(y + 0.5)) end
    return zone
end

-- ---------------------------------------------------------------------------
-- Exact quest positions from the game. Forever's world map shows "!" for quests you can
-- pick up (C_QuestLine); those positions are current, unlike Classic database ones.
-- ---------------------------------------------------------------------------

local function candidateMaps(areaID)
    local out, seen = {}, {}
    local function add(id)
        id = ns.Safe(id)
        if id and not seen[id] then seen[id] = true; tinsert(out, id) end
    end
    local function addWithChildren(id)
        if not id then return end
        add(id)
        local kids = ns.Call(C_Map.GetMapChildrenInfo, id, nil, true)
        if type(kids) == "table" then
            for _, k in ipairs(kids) do add(ns.Field(k, "mapID")) end
        end
        -- Cities sit next to their zone (Thunder Bluff by Mulgore): include siblings too.
        local info = ns.Call(C_Map.GetMapInfo, id)
        local parent = type(info) == "table" and ns.Field(info, "parentMapID")
        if parent then
            local sibs = ns.Call(C_Map.GetMapChildrenInfo, parent)
            if type(sibs) == "table" then
                for _, k in ipairs(sibs) do
                    local t = ns.Field(k, "mapType")
                    if t == ZONE_TYPE or t == 4 then add(ns.Field(k, "mapID")) end -- zones and cities
                end
            end
        end
    end
    addWithChildren(Maps.UiMapForArea(areaID))
    addWithChildren(ns.Call(C_Map.GetBestMapForUnit, "player"))
    return out
end

local function offerOn(questID, uiMapID)
    if not C_QuestLine then return nil end
    local info = ns.Call(C_QuestLine.GetQuestLineInfo, questID, uiMapID)
    local x, y = ns.Field(info, "x"), ns.Field(info, "y")
    if x and y and (x > 0 or y > 0) then return x, y end
    local lines = ns.Call(C_QuestLine.GetAvailableQuestLines, uiMapID)
    if type(lines) == "table" then
        for _, l in ipairs(lines) do
            if ns.Field(l, "questID") == questID then
                x, y = ns.Field(l, "x"), ns.Field(l, "y")
                if x and y and (x > 0 or y > 0) then return x, y end
            end
        end
    end
end

-- Where the game shows this quest's "!" right now: uiMapID, x, y (percent) or nil.
function Maps.QuestPosition(questID, areaID)
    for _, m in ipairs(candidateMaps(areaID)) do
        local x, y = offerOn(questID, m)
        if x then return m, x * 100, y * 100 end
    end
end

-- For a quest in your log: where the game's own map marker ("?" or objective) is.
function Maps.LogQuestPosition(questID, areaID)
    if not C_QuestLog then return nil end
    for _, m in ipairs(candidateMaps(areaID)) do
        local list = ns.Call(C_QuestLog.GetQuestsOnMap, m)
        if type(list) == "table" then
            for _, q in ipairs(list) do
                if ns.Field(q, "questID") == questID then
                    local x, y = ns.Field(q, "x"), ns.Field(q, "y")
                    if x and y and (x > 0 or y > 0) then return m, x * 100, y * 100 end
                end
            end
        end
    end
    -- Where the game would send you next for this quest (may be another zone).
    local m, x, y = ns.Call(C_QuestLog.GetNextWaypoint, questID)
    m, x, y = ns.Safe(m), ns.Safe(x), ns.Safe(y)
    if m and x and y and (x > 0 or y > 0) then return m, x * 100, y * 100 end
end

-- Ask the game to load quest markers for the maps around a place.
function Maps.RequestQuestData(areaID)
    if not (C_QuestLine and C_QuestLine.RequestQuestLinesForMap) then return end
    for _, m in ipairs(candidateMaps(areaID)) do pcall(C_QuestLine.RequestQuestLinesForMap, m) end
end

-- Where to go for a quest: callback(uiMapID, x, y, approximate, labelOverride) or callback(nil).
-- Order: the game's marker for quests in your log, what we learned in game, the game's "!"
-- marker, and finally the Classic database position (approximate).
function Maps.ResolveQuest(questID, learned, areaID, x, y, callback)
    if ns.Call(C_QuestLog and C_QuestLog.GetLogIndexForQuestID, questID) then
        local m, qx, qy = Maps.LogQuestPosition(questID, areaID)
        if m then return callback(m, qx, qy, false, ns.Quests and ns.Quests.Title(questID)) end
    end
    if learned and learned.m and learned.x then return callback(learned.m, learned.x, learned.y, false) end
    local m, qx, qy = Maps.QuestPosition(questID, areaID)
    if m then return callback(m, qx, qy, false) end
    Maps.RequestQuestData(areaID)
    ns.After(1, function()
        local m2, x2, y2 = Maps.QuestPosition(questID, areaID)
        if m2 then return callback(m2, x2, y2, false) end
        local um = areaID and x and Maps.UiMapForArea(areaID)
        if um then return callback(um, x, y, true) end
        callback(nil)
    end)
end

function Maps.PinQuest(questID, label, learned, areaID, x, y)
    Maps.ResolveQuest(questID, learned, areaID, x, y, function(m, qx, qy, approx, label2)
        if not m then return ns.Print(L.WAYPOINT_NONE:format(label or "")) end
        if approx then
            return Maps.Waypoint(areaID, x, y, label, true)
        end
        Maps.WaypointUi(m, qx, qy, label2 or label)
    end)
end

-- Text like "Westfall (56, 47)".
function Maps.PlaceText(areaID, x, y)
    local zone = Maps.AreaName(areaID)
    if not zone then return nil end
    if x and y then return ("%s (%d, %d)"):format(zone, floor(x + 0.5), floor(y + 0.5)) end
    return zone
end

-- /dp quest <id>: what every source says about a quest's position (for bug reports).
function Maps.Debug(questID)
    local q = ns.DB and ns.DB.quests[questID]
    local area = q and q[7] and q[7][5]
    ns.Say(("quest %d: in log=%s"):format(questID, tostring(ns.Call(C_QuestLog.GetLogIndexForQuestID, questID) ~= nil)))
    local maps = candidateMaps(area)
    ns.Say("maps checked: " .. table.concat(maps, ", "))
    for _, m in ipairs(maps) do
        local ox, oy = offerOn(questID, m)
        if ox then ns.Say(("  offer on %d: %.1f, %.1f"):format(m, ox * 100, oy * 100)) end
        local list = ns.Call(C_QuestLog.GetQuestsOnMap, m)
        if type(list) == "table" then
            for _, e in ipairs(list) do
                if ns.Field(e, "questID") == questID then
                    ns.Say(("  log marker on %d: %.1f, %.1f"):format(m, (ns.Field(e, "x") or 0) * 100, (ns.Field(e, "y") or 0) * 100))
                end
            end
        end
    end
    local wm, wx, wy = ns.Call(C_QuestLog.GetNextWaypoint, questID)
    ns.Say(("  next waypoint: %s %s %s"):format(tostring(ns.Safe(wm)), tostring(ns.Safe(wx)), tostring(ns.Safe(wy))))
    local lg = ns.Learn and ns.Learn.Giver(questID)
    if lg then ns.Say(("  learned giver: %s on %s at %s, %s"):format(tostring(lg.name), tostring(lg.m), tostring(lg.x), tostring(lg.y))) end
    if q and q[7] then ns.Say(("  classic data: area %s at %s, %s"):format(tostring(area), tostring(q[7][3]), tostring(q[7][4]))) end
end
