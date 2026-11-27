-- Learn: WoW Forever changed loot and quests, so the addon learns them while you play.
--   * Loot: what creatures in dungeons actually drop (when you open their loot window).
--   * Quest givers and turn-ins: who and where (when you talk to them).
--   * Quest -> dungeon: quests that make progress while you are inside one.
-- With sharing on, these facts travel to other Dungeon Planner users over the quiet network.
local _, ns = ...

local Learn = {}
ns.Learn = Learn

local MAX_PER_NPC = 60

local function store()
    local l = ns.db.learn
    if not l then
        l = { loot = {}, kills = {}, mapLoot = {}, npcNames = {}, givers = {}, enders = {}, qmap = {}, titles = {} }
        ns.db.learn = l
    end
    return l
end
Learn.Store = store

local function npcFromGUID(guid)
    guid = ns.Safe(guid)
    if type(guid) ~= "string" then return nil end
    local kind, _, _, _, _, npcID = strsplit("-", guid)
    if kind ~= "Creature" and kind ~= "Vehicle" then return nil end
    return tonumber(npcID)
end
Learn.NpcFromGUID = npcFromGUID

local function itemFromLink(link)
    link = ns.Safe(link)
    return link and tonumber(link:match("item:(%d+)"))
end

local function instanceMap()
    local _, instanceType, _, _, _, _, _, instanceID = ns.Call(GetInstanceInfo)
    if instanceType == "party" or instanceType == "raid" then return ns.Safe(instanceID) end
end

-- Worth remembering: equippable green+ items and quest items.
local function worthKeeping(itemID)
    local _, _, _, equipLoc, _, classID = ns.Call(C_Item and C_Item.GetItemInfoInstant, itemID)
    local quality = ns.Call(C_Item and C_Item.GetItemQualityByID, itemID)
    if classID == 12 then return true end
    return type(equipLoc) == "string" and equipLoc ~= "" and (quality == nil or quality >= 2)
end

-- ---------------------------------------------------------------------------
-- Recording (also used for facts received from other players)
-- ---------------------------------------------------------------------------

local recentKill = {}  -- "npc:guid" -> true, so one corpse counts once

function Learn.AddKillLoot(npcID, mapID, itemIDs, corpseKey)
    if not npcID then return end
    local l = store()
    if corpseKey then
        if recentKill[corpseKey] then return end
        recentKill[corpseKey] = true
    end
    l.kills[npcID] = (l.kills[npcID] or 0) + 1
    local t = l.loot[npcID] or {}
    l.loot[npcID] = t
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    for _, itemID in ipairs(itemIDs) do
        if t[itemID] or n < MAX_PER_NPC then
            if not t[itemID] then n = n + 1 end
            t[itemID] = (t[itemID] or 0) + 1
        end
        if mapID then
            l.mapLoot[mapID] = l.mapLoot[mapID] or {}
            l.mapLoot[mapID][itemID] = npcID
        end
    end
    ns.Fire("LEARNED_CHANGED")
end

function Learn.AddGiver(questID, kind, npcID, name, uiMapID, x, y, fromNetwork)
    if not (questID and npcID) then return end
    local l = store()
    local list = kind == "end" and l.enders or l.givers
    local old = list[questID]
    if old and old.npc == npcID and not fromNetwork then return end
    if old and fromNetwork then return end -- what we saw ourselves wins
    list[questID] = { npc = npcID, name = name, m = uiMapID, x = x, y = y }
    if not fromNetwork and kind ~= "end" and ns.Comm.ShareGiver then ns.Comm.ShareGiver(questID, npcID, name, uiMapID, x, y) end
    ns.Fire("LEARNED_CHANGED")
end

function Learn.AddQuestMap(questID, mapID, title)
    if not (questID and mapID) then return end
    local l = store()
    if l.qmap[questID] == mapID then return end
    l.qmap[questID] = mapID
    if title then l.titles[questID] = title end
    ns.Fire("LEARNED_CHANGED")
end

-- ---------------------------------------------------------------------------
-- Reading (for the journal and gear)
-- ---------------------------------------------------------------------------

-- Observed drops for a creature: list of { item, chance% , seen } (chance from our kills).
function Learn.LootFor(npcID)
    local l = ns.db and ns.db.learn
    local t = l and l.loot[npcID]
    if not t then return {} end
    local kills = math.max(l.kills[npcID] or 1, 1)
    local out = {}
    for itemID, seen in pairs(t) do
        tinsert(out, { item = itemID, chance = floor(math.min(seen / kills, 1) * 1000 + 0.5) / 10, seen = seen })
    end
    table.sort(out, function(a, b) return a.seen > b.seen end)
    return out, kills
end

-- Everything seen dropping in a dungeon (for Forever's new dungeons): itemID -> npcID
function Learn.MapLoot(mapID)
    local l = ns.db and ns.db.learn
    return l and l.mapLoot[mapID] or {}
end

function Learn.Giver(questID) local l = ns.db and ns.db.learn return l and l.givers[questID] end
function Learn.Ender(questID) local l = ns.db and ns.db.learn return l and l.enders[questID] end

-- Quests we learned belong to a dungeon map.
function Learn.QuestsForMap(mapID)
    local out = {}
    local l = ns.db and ns.db.learn
    if not l then return out end
    for qid, m in pairs(l.qmap) do if m == mapID then tinsert(out, qid) end end
    return out
end

function Learn.Title(questID) local l = ns.db and ns.db.learn return l and l.titles[questID] end

-- ---------------------------------------------------------------------------
-- Watching the game
-- ---------------------------------------------------------------------------

local function onLoot()
    local mapID = instanceMap()
    if not mapID then return end
    local bySource = {}      -- guid -> { npc, items }
    local n = ns.Call(GetNumLootItems) or 0
    for slot = 1, n do
        local itemID = itemFromLink(ns.Call(GetLootSlotLink, slot))
        if itemID and worthKeeping(itemID) then
            local guid
            if GetLootSourceInfo then guid = ns.Safe((ns.Call(GetLootSourceInfo, slot))) end
            if not guid and ns.Call(UnitIsDead, "target") then guid = ns.Safe(UnitGUID("target")) end
            local npc = npcFromGUID(guid)
            if npc then
                bySource[guid] = bySource[guid] or { npc = npc, items = {} }
                tinsert(bySource[guid].items, itemID)
            end
        end
    end
    for guid, src in pairs(bySource) do
        if not recentKill[guid] then
            if ns.Safe(UnitGUID("target")) == guid then
                local name = ns.Safe(UnitName("target"))
                if name then store().npcNames[src.npc] = name end
            end
            Learn.AddKillLoot(src.npc, mapID, src.items, guid)
            if ns.Comm.ShareLoot then ns.Comm.ShareLoot(src.npc, mapID, src.items) end
        end
    end
end

-- Where the player stands (outside instances only; inside, the game hides positions).
local function myPosition()
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return nil end
    local uiMapID = ns.Call(C_Map.GetBestMapForUnit, "player")
    if not uiMapID then return nil end
    local pos = ns.Call(C_Map.GetPlayerMapPosition, uiMapID, "player")
    if not pos then return nil end
    local x, y = ns.Call(pos.GetXY, pos)
    x, y = ns.Safe(x), ns.Safe(y)
    if not (x and y) or (x == 0 and y == 0) then return nil end
    return uiMapID, floor(x * 1000 + 0.5) / 10, floor(y * 1000 + 0.5) / 10
end

local function questNPC()
    for _, unit in ipairs({ "questnpc", "npc" }) do
        local guid = ns.Safe(UnitGUID(unit))
        local npc = npcFromGUID(guid)
        if npc then return npc, ns.Safe(UnitName(unit)) end
    end
end

local function onQuestDetail()
    local questID = ns.Call(GetQuestID)
    questID = ns.Safe(questID)
    if not questID or questID == 0 then return end
    local npc, name = questNPC()
    if not npc then return end
    -- Only dungeon quests are worth sharing: known ones, or quests tagged Dungeon.
    local tag = ns.Call(C_QuestLog.GetQuestTagInfo, questID)
    local isDungeon = (ns.DB and ns.DB.quests[questID]) or (type(tag) == "table" and ns.Field(tag, "tagID") == 81)
        or (ns.db.learn and ns.db.learn.qmap[questID])
    if not isDungeon then return end
    local m, x, y = myPosition()
    Learn.AddGiver(questID, "start", npc, name, m, x, y)
end

local function onTurnIn(questID)
    questID = ns.Safe(questID)
    if not questID then return end
    local npc, name = questNPC()
    if not npc then return end
    if not ((ns.DB and ns.DB.quests[questID]) or (ns.db.learn and ns.db.learn.qmap[questID])) then return end
    local m, x, y = myPosition()
    Learn.AddGiver(questID, "end", npc, name, m, x, y)
end

-- A quest objective moved while we are in a dungeon: that quest belongs here.
local lastObjectives = {}
local function onQuestProgress()
    local mapID = instanceMap()
    if not mapID then return end
    for qid in pairs(ns.Data.quests) do
        local objectives = ns.Call(C_QuestLog.GetQuestObjectives, qid)
        if type(objectives) == "table" then
            local sum = 0
            for _, o in ipairs(objectives) do sum = sum + (ns.Field(o, "numFulfilled") or 0) end
            if lastObjectives[qid] and sum > lastObjectives[qid] then
                Learn.AddQuestMap(qid, mapID, ns.Data.quests[qid].title)
            end
            lastObjectives[qid] = sum
        end
    end
end

ns.On("LOOT_READY", function() ns.After(0, onLoot) end)
ns.On("QUEST_DETAIL", onQuestDetail)
ns.On("QUEST_TURNED_IN", onTurnIn)
ns.On("QUEST_LOG_UPDATE", ns.Debounce(0.5, onQuestProgress))
ns.On("PLAYER_ENTERING_WORLD", function() wipe(lastObjectives); ns.After(2, onQuestProgress) end)
