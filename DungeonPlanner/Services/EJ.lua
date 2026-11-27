-- EJ: what the game's own Encounter Journal knows about a dungeon: its bosses (with their
-- portraits) and each boss's loot, with real item IDs. Forever's client carries this for its
-- new dungeons too, so their loot shows before anyone has run them.
local _, ns = ...

local EJ = {}
ns.EJ = EJ

local instanceCache = {}   -- normalized name -> EJ instance ID or false
local bossCache = {}       -- EJ instance ID -> { { name, encounterID, display } }
local lootCache = {}       -- encounterID -> { itemID, ... } or false

local function key(name) return ns.Data.Normalize(name) end

-- EJ instance ID for a dungeon name (any of the names given).
function EJ.Instance(...)
    if not (EJ_GetNumTiers and EJ_SelectTier and EJ_GetInstanceByIndex) then return nil end
    local want = {}
    for i = 1, select("#", ...) do
        local n = select(i, ...)
        if n then want[key(n)] = true end
    end
    for k in pairs(want) do
        if instanceCache[k] ~= nil then return instanceCache[k] or nil end
    end
    local found
    for tier = 1, (ns.Call(EJ_GetNumTiers) or 0) do
        pcall(EJ_SelectTier, tier)
        for _, raid in ipairs({ false, true }) do
            for i = 1, 300 do
                local id, name = ns.Call(EJ_GetInstanceByIndex, i, raid)
                id, name = ns.Safe(id), ns.Safe(name)
                if not id then break end
                if want[key(name)] then found = id break end
            end
            if found then break end
        end
        if found then break end
    end
    for k in pairs(want) do instanceCache[k] = found or false end
    return found
end

-- Instance art from the journal: { button = small card art, lore = large background }.
local artCache = {}
function EJ.Art(...)
    local inst = EJ.Instance(...)
    if not inst then
        -- Wings (e.g. "Scarlet Monastery: Cathedral"): any journal instance starting with the name.
        local first = select(1, ...)
        if first and EJ_GetInstanceByIndex then
            local want = key(first)
            for tier = 1, (ns.Call(EJ_GetNumTiers) or 0) do
                pcall(EJ_SelectTier, tier)
                for i = 1, 300 do
                    local id, name = ns.Call(EJ_GetInstanceByIndex, i, false)
                    id, name = ns.Safe(id), ns.Safe(name)
                    if not id then break end
                    local k = key(name)
                    if k and want and k:sub(1, #want) == want then inst = id break end
                end
                if inst then break end
            end
        end
    end
    if not inst then return nil end
    if artCache[inst] then return artCache[inst] end
    local _, _, bg, button, lore = ns.Call(EJ_GetInstanceInfo, inst)
    local art = { button = ns.Safe(button), lore = ns.Safe(lore), bg = ns.Safe(bg) }
    artCache[inst] = art
    return art
end

-- Bosses in the journal's order, with portraits.
function EJ.Bosses(instanceID)
    if not instanceID then return {} end
    if bossCache[instanceID] then return bossCache[instanceID] end
    local list = {}
    pcall(EJ_SelectInstance, instanceID)
    for j = 1, 40 do
        local name, _, encounterID = ns.Call(EJ_GetEncounterInfoByIndex, j, instanceID)
        name, encounterID = ns.Safe(name), ns.Safe(encounterID)
        if not name then break end
        local display
        if EJ_GetCreatureInfo then
            local _, _, _, disp = ns.Call(EJ_GetCreatureInfo, 1, encounterID)
            display = ns.Safe(disp)
        end
        tinsert(list, { name = name, encounterID = encounterID, display = display })
    end
    bossCache[instanceID] = list
    return list
end

-- A boss's loot: item IDs from the journal (every class, every slot).
function EJ.Loot(instanceID, encounterID)
    if not (instanceID and encounterID) then return {} end
    if lootCache[encounterID] ~= nil then return lootCache[encounterID] or {} end
    local items = {}
    local getNum = (C_EncounterJournal and C_EncounterJournal.GetNumLoot) or EJ_GetNumLoot
    local getInfo = (C_EncounterJournal and C_EncounterJournal.GetLootInfoByIndex) or EJ_GetLootInfoByIndex
    if getNum and getInfo then
        pcall(EJ_SelectInstance, instanceID)
        pcall(EJ_SelectEncounter, encounterID)
        if EJ_ResetLootFilter then pcall(EJ_ResetLootFilter) end
        if C_EncounterJournal and C_EncounterJournal.ResetSlotFilter then pcall(C_EncounterJournal.ResetSlotFilter) end
        for i = 1, (ns.Call(getNum) or 0) do
            local info = ns.Call(getInfo, i)
            local itemID
            if type(info) == "table" then itemID = ns.Safe(ns.Field(info, "itemID")) else itemID = ns.Safe(info) end
            if itemID then
                tinsert(items, itemID)
                if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, itemID) end
            end
        end
    end
    lootCache[encounterID] = #items > 0 and items or false
    return items
end

-- Loot for a boss by name in a dungeon by name: item IDs, or nil if the journal hasn't got it.
function EJ.LootForBoss(dungeonNames, bossName)
    local inst = EJ.Instance(unpack(dungeonNames))
    if not inst then return nil end
    local want = key(bossName)
    for _, b in ipairs(EJ.Bosses(inst)) do
        if key(b.name) == want then
            local items = EJ.Loot(inst, b.encounterID)
            return #items > 0 and items or nil, b
        end
    end
end

-- A boss's portrait model from the journal.
function EJ.Display(dungeonNames, bossName)
    local inst = EJ.Instance(unpack(dungeonNames))
    if not inst then return nil end
    local want = key(bossName)
    for _, b in ipairs(EJ.Bosses(inst)) do
        if key(b.name) == want then return b.display end
    end
end
