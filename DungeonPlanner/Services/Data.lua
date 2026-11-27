-- Data: what we know about you (role, level, dungeon quests), the dungeons the Group Finder
-- offers, your friends and guild, and the players you have grouped with before.
local _, ns = ...
local L = ns.L

local Data = {}
ns.Data = Data

local DUNGEON_CATEGORY_FALLBACK = 2 -- Blizzard's "Dungeons" category on Forever

-- ---------------------------------------------------------------------------
-- Dungeons (activities in the Group Finder's dungeon category)
-- ---------------------------------------------------------------------------

Data.activities = {}      -- activityID -> { id, name, shortName, minLevel, maxLevel, group }
Data.dungeonList = {}     -- sorted list for the dropdown
Data.byName = {}          -- normalized dungeon name -> activity record (for quest headers)

local function normalize(name)
    if type(name) ~= "string" then return nil end
    name = strlower(name)
    name = name:gsub("^the ", ""):gsub("[%p]", ""):gsub("%s+", " ")
    return strtrim(name)
end
Data.Normalize = normalize

function Data.Activity(id)
    id = ns.Safe(id)
    if not id then return nil end
    local a = Data.activities[id]
    if a ~= nil then return a or nil end
    local info = ns.Call(C_LFGList and C_LFGList.GetActivityInfoTable, id)
    if type(info) ~= "table" then
        Data.activities[id] = false
        return nil
    end
    local full = ns.Field(info, "fullName")
    local short = ns.Field(info, "shortName")
    a = {
        id = id,
        name = (short and short ~= "" and short) or full or "?",
        fullName = full or short or "?",
        minLevel = ns.Field(info, "minLevelSuggestion") or ns.Field(info, "minLevel") or 0,
        maxLevel = ns.Field(info, "maxLevelSuggestion") or ns.Field(info, "maxLevel") or 0,
        categoryID = ns.Field(info, "categoryID"),
        group = ns.Field(info, "groupFinderActivityGroupID"),
        order = ns.Field(info, "orderIndex") or 0,
        mapID = ns.Field(info, "mapID"),
    }
    Data.activities[id] = a
    local n1, n2 = normalize(a.fullName), normalize(a.name)
    if n1 then Data.byName[n1] = a end
    if n2 then Data.byName[n2] = a end
    return a
end

function Data.DungeonCategory()
    local cats = ns.Call(C_LFGList and C_LFGList.GetAvailableCategories)
    if type(cats) == "table" then
        for _, id in ipairs(cats) do
            if id == DUNGEON_CATEGORY_FALLBACK then return id end
        end
    end
    return DUNGEON_CATEGORY_FALLBACK
end

function Data.RefreshActivities()
    wipe(Data.dungeonList)
    local list = ns.Call(C_LFGList and C_LFGList.GetAvailableActivities, Data.DungeonCategory())
    if type(list) ~= "table" then return end
    for _, id in ipairs(list) do
        local a = Data.Activity(id)
        if a then tinsert(Data.dungeonList, a) end
    end
    table.sort(Data.dungeonList, function(x, y)
        if x.minLevel ~= y.minLevel then return x.minLevel < y.minLevel end
        return x.name < y.name
    end)
    ns.Fire("ACTIVITIES_CHANGED")
end

-- Does the activity suit a character of this level? (Same rule as Blizzard's own list.)
function Data.LevelFits(a, level)
    if not (a and level) then return false end
    local lo, hi = a.minLevel or 0, a.maxLevel or 0
    if lo > 0 and level < lo then return false end
    if hi > 0 and level > hi then return false end
    return true
end

-- ---------------------------------------------------------------------------
-- You
-- ---------------------------------------------------------------------------

local ROLE_CLASSES = {
    tank = { WARRIOR = true, PALADIN = true, DRUID = true, SHAMAN = true },
    healer = { PRIEST = true, PALADIN = true, DRUID = true, SHAMAN = true },
}
Data.ROLE_CLASSES = ROLE_CLASSES

function Data.CanClassDo(classFile, role)
    if role == "dps" or not classFile then return true end
    return ROLE_CLASSES[role] and ROLE_CLASSES[role][classFile] or false
end

function Data.MyClass()
    local _, classFile = UnitClass("player")
    return classFile
end

function Data.MyLevel() return UnitLevel("player") or 1 end

function Data.MyName()
    local name, realm = UnitFullName and UnitFullName("player")
    name = name or UnitName("player")
    if realm and realm ~= "" then return name .. "-" .. realm end
    return name
end

function Data.MyZone()
    return ns.Safe(GetRealZoneText and GetRealZoneText()) or ns.Safe(GetZoneText and GetZoneText())
end

-- My roles: what I set in the planner, else what I chose in Blizzard's listing, else a guess.
function Data.MyRoles()
    local r = ns.cdb and ns.cdb.roles
    if type(r) == "table" and (r.tank or r.healer or r.dps) then return r end
    local api = C_LFGListRoles and C_LFGListRoles.GetRoles
    local saved = ns.Call(api) or ns.Call(C_LFGListRoles and C_LFGListRoles.GetSavedRoles)
    if type(saved) == "table" and (ns.Field(saved, "tank") or ns.Field(saved, "healer") or ns.Field(saved, "dps")) then
        return { tank = ns.Field(saved, "tank") and true, healer = ns.Field(saved, "healer") and true,
            dps = ns.Field(saved, "dps") and true }
    end
    return { dps = true }
end

function Data.SetMyRole(role, on)
    local r = ns.cdb.roles or CopyTable(Data.MyRoles())
    r[role] = on and true or false
    if not (r.tank or r.healer or r.dps) then r[role] = true end -- keep at least one
    ns.cdb.roles = r
    ns.Fire("MY_INFO_CHANGED")
end

-- The single role to put in whispers: the scarcest one I offer.
function Data.MyMainRole()
    local r = Data.MyRoles()
    if r.tank then return "tank" end
    if r.healer then return "healer" end
    return "dps"
end

function Data.RoleName(role)
    if role == "tank" then return L.ROLE_TANK end
    if role == "healer" then return L.ROLE_HEALER end
    return L.ROLE_DAMAGER
end

-- ---------------------------------------------------------------------------
-- Dungeon quests in your log
-- ---------------------------------------------------------------------------

Data.quests = {}       -- questID -> { title, dungeon = activity or nil, complete }
Data.questCount = 0

local DUNGEON_TAG = (Enum and Enum.QuestTag and Enum.QuestTag.Dungeon) or 81

-- The Group Finder activity for a database dungeon map.
local function activityForMap(mapID)
    if not mapID then return nil end
    for _, a in ipairs(Data.dungeonList) do
        if a.mapID == mapID then return a end
    end
    local d = ns.DB and ns.DB.dungeons[mapID]
    return d and Data.byName[normalize(d.name)]
end
Data.ActivityForMap = activityForMap

local function isDungeonQuest(info, questID, header)
    local dbq = ns.DB and ns.DB.quests[questID]
    if dbq and dbq[10] > 0 then return true end      -- map 0 = a lead-in quest, not a dungeon quest
    if ns.db and ns.db.learn and ns.db.learn.qmap[questID] then return true end
    local tag = ns.Call(C_QuestLog.GetQuestTagInfo, questID)
    local tagID = type(tag) == "table" and ns.Field(tag, "tagID")
    if tagID == DUNGEON_TAG then return true end
    if header and Data.byName[normalize(header)] then return true end
    if ns.db and ns.db.learned[questID] then return true end
    return false
end

function Data.ScanQuests()
    if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries) then return end
    wipe(Data.quests)
    local count = 0
    local header
    local n = ns.Call(C_QuestLog.GetNumQuestLogEntries) or 0
    for i = 1, n do
        local info = ns.Call(C_QuestLog.GetInfo, i)
        if type(info) == "table" then
            local title = ns.Field(info, "title")
            if ns.Field(info, "isHeader") then
                header = title
            else
                local questID = ns.Field(info, "questID")
                if questID and not ns.Field(info, "isHidden") and isDungeonQuest(info, questID, header) then
                    local dbq = ns.DB and ns.DB.quests[questID]
                    local learnedMap = ns.db.learn and ns.db.learn.qmap[questID]
                    local dungeon = (dbq and dbq[10] > 0 and activityForMap(dbq[10])) or (learnedMap and activityForMap(learnedMap)) or (header and Data.byName[normalize(header)]) or nil
                    if not dungeon and ns.db.learned[questID] then
                        dungeon = Data.byName[normalize(ns.db.learned[questID])]
                    end
                    Data.quests[questID] = {
                        title = title or ("#" .. questID),
                        dungeon = dungeon,
                        complete = ns.Call(C_QuestLog.IsComplete, questID) and true or false,
                    }
                    count = count + 1
                end
            end
        end
    end
    local changed = count ~= Data.questCount
    Data.questCount = count
    ns.Fire("QUESTS_CHANGED", changed)
end

-- Quest IDs as a sorted list (for sharing).
function Data.QuestIDs(limit)
    local ids = {}
    for id in pairs(Data.quests) do tinsert(ids, id) end
    table.sort(ids)
    if limit and #ids > limit then
        for i = #ids, limit + 1, -1 do ids[i] = nil end
    end
    return ids
end

-- Learn quest -> dungeon: progress on a quest while inside a dungeon ties them together.
local function learnFromInstance()
    local name, instanceType = ns.Call(GetInstanceInfo)
    name = ns.Safe(name)
    if instanceType ~= "party" or not name then return end
    for questID, q in pairs(Data.quests) do
        if not q.dungeon and not ns.db.learned[questID] then
            -- Only quests whose objectives moved while we are here.
            local objectives = ns.Call(C_QuestLog.GetQuestObjectives, questID)
            if type(objectives) == "table" then
                for _, o in ipairs(objectives) do
                    if ns.Field(o, "numFulfilled") and ns.Field(o, "numFulfilled") > 0 then
                        ns.db.learned[questID] = name
                        break
                    end
                end
            end
        end
    end
end

local scanSoon = ns.Debounce(1, function()
    Data.ScanQuests()
    if IsInInstance and IsInInstance() then learnFromInstance() end
end)

-- ---------------------------------------------------------------------------
-- Friends and guild
-- ---------------------------------------------------------------------------

Data.friends = {}
Data.guild = {}

local function refreshFriends()
    wipe(Data.friends)
    if not C_FriendList then return end
    local n = ns.Call(C_FriendList.GetNumFriends) or 0
    for i = 1, n do
        local info = ns.Call(C_FriendList.GetFriendInfoByIndex, i)
        local key = ns.Key(ns.Field(info, "name"))
        if key then Data.friends[key] = true end
    end
end

local function refreshGuild()
    wipe(Data.guild)
    if not (IsInGuild and IsInGuild()) then return end
    local n = ns.Call(GetNumGuildMembers) or 0
    for i = 1, n do
        local name = ns.Call(GetGuildRosterInfo, i)
        local key = ns.Key(name)
        if key then Data.guild[key] = true end
    end
end

function Data.IsFriend(key) return key and Data.friends[key] or false end
function Data.IsGuild(key) return key and Data.guild[key] or false end

-- ---------------------------------------------------------------------------
-- Group memory: who you ran dungeons with
-- ---------------------------------------------------------------------------

local snapshot = {} -- key -> { name, class, level } of the current party

local function readParty()
    wipe(snapshot)
    for i = 1, 4 do
        local unit = "party" .. i
        if UnitExists(unit) then
            local name, realm = ns.Call(UnitName, unit)
            name, realm = ns.Safe(name), ns.Safe(realm)
            if name then
                if realm and realm ~= "" then name = name .. "-" .. realm end
                local _, classFile = ns.Call(UnitClass, unit)
                snapshot[ns.Key(name)] = { name = name, class = ns.Safe(classFile), level = ns.Safe(UnitLevel(unit)) }
            end
        end
    end
end

function Data.Memory(key)
    return key and ns.db and ns.db.memory[key] or nil
end

function Data.MemoryFor(name, create)
    local key = ns.Key(name)
    if not key then return nil end
    local m = ns.db.memory[key]
    if not m and create then
        m = { name = name, runs = {} }
        ns.db.memory[key] = m
    end
    return m
end

local committedInstance -- instance ID we already recorded this visit

local function commitRun()
    local name, instanceType, _, _, _, _, _, instanceID = ns.Call(GetInstanceInfo)
    name = ns.Safe(name)
    if instanceType ~= "party" or not name then
        committedInstance = nil
        return
    end
    if committedInstance == instanceID then return end
    if not next(snapshot) then readParty() end
    if not next(snapshot) then return end
    committedInstance = instanceID
    local now = ns.Now()
    for key, p in pairs(snapshot) do
        local m = Data.MemoryFor(p.name, true)
        m.class = p.class or m.class
        m.level = p.level or m.level
        tinsert(m.runs, 1, { dungeon = name, at = now })
        while #m.runs > 10 do tremove(m.runs) end
    end
    ns.Fire("MEMORY_CHANGED")
end

function Data.SetFavorite(name, on)
    local m = Data.MemoryFor(name, true)
    m.fav = on or nil
    if on then m.avoid = nil end
    ns.Fire("MEMORY_CHANGED")
end

function Data.SetAvoid(name, on)
    local m = Data.MemoryFor(name, true)
    m.avoid = on or nil
    if on then m.fav = nil end
    ns.Fire("MEMORY_CHANGED")
end

-- Forget strangers you never favorited after 60 days, keep the file small.
local function prune()
    local cutoff = ns.Now() - 60 * 86400
    for key, m in pairs(ns.db.memory) do
        local last = m.runs and m.runs[1] and m.runs[1].at or 0
        if not m.fav and not m.avoid and last < cutoff then ns.db.memory[key] = nil end
    end
end

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------

ns.Listen("LOGIN", function()
    prune()
    if C_LFGList and C_LFGList.RequestAvailableActivities then pcall(C_LFGList.RequestAvailableActivities) end
    Data.RefreshActivities()
    Data.ScanQuests()
    refreshFriends()
    if IsInGuild() and C_GuildInfo and C_GuildInfo.GuildRoster then pcall(C_GuildInfo.GuildRoster) end
    refreshGuild()
    readParty()
end)

ns.On("LFG_LIST_AVAILABILITY_UPDATE", function() Data.RefreshActivities(); scanSoon() end)
ns.On("PLAYER_LEVEL_UP", function() ns.After(1, Data.RefreshActivities); ns.Fire("MY_INFO_CHANGED") end)
ns.On("QUEST_LOG_UPDATE", scanSoon)
ns.On("QUEST_ACCEPTED", scanSoon)
ns.On("QUEST_REMOVED", scanSoon)
ns.On("FRIENDLIST_UPDATE", refreshFriends)
ns.On("GUILD_ROSTER_UPDATE", refreshGuild)
ns.On("GROUP_ROSTER_UPDATE", function()
    if not (IsInInstance and IsInInstance()) then readParty() end
end)
ns.On("PLAYER_ENTERING_WORLD", function() ns.After(2, commitRun) end)
ns.On("ZONE_CHANGED_NEW_AREA", function() ns.After(2, commitRun); ns.Fire("MY_INFO_CHANGED") end)
