-- Gear: is this item an upgrade for me, and by how much?
-- Usability comes from the database (armor/weapon type, class restrictions); stats come
-- live from the game (C_Item.GetItemStats), so Forever's changed items are scored correctly.
local _, ns = ...

local Gear = {}
ns.Gear = Gear

-- Database item fields: { name, quality, inventoryType, requiredLevel, itemLevel, class, subclass, allowableClass }
local F_NAME, F_QUALITY, F_INV, F_REQ, F_ILVL, F_CLASS, F_SUB, F_ALLOW = 1, 2, 3, 4, 5, 6, 7, 8

local CLASS_BIT = { WARRIOR = 1, PALADIN = 2, HUNTER = 4, ROGUE = 8, PRIEST = 16, SHAMAN = 64, MAGE = 128, WARLOCK = 256, DRUID = 1024 }

-- Weapon subclasses each class can use (item class 2).
local WEAPONS = {
    WARRIOR = { [0] = 1, 1, 2, 3, 4, 5, 6, 7, 8, [10] = 1, [13] = 1, [15] = 1, [16] = 1, [18] = 1 },
    PALADIN = { [0] = 1, [1] = 1, [4] = 1, [5] = 1, [6] = 1, [7] = 1, [8] = 1 },
    HUNTER = { [0] = 1, [1] = 1, [2] = 1, [3] = 1, [6] = 1, [7] = 1, [8] = 1, [10] = 1, [13] = 1, [15] = 1, [16] = 1, [18] = 1 },
    ROGUE = { [2] = 1, [3] = 1, [4] = 1, [7] = 1, [13] = 1, [15] = 1, [16] = 1, [18] = 1 },
    PRIEST = { [4] = 1, [10] = 1, [15] = 1, [19] = 1 },
    SHAMAN = { [0] = 1, [1] = 1, [4] = 1, [5] = 1, [10] = 1, [13] = 1, [15] = 1 },
    MAGE = { [7] = 1, [10] = 1, [15] = 1, [19] = 1 },
    WARLOCK = { [7] = 1, [10] = 1, [15] = 1, [19] = 1 },
    DRUID = { [4] = 1, [5] = 1, [10] = 1, [13] = 1, [15] = 1 },
}
-- Best armor type per class (item class 4: 1 cloth, 2 leather, 3 mail, 4 plate) and from what level.
local ARMOR = {
    WARRIOR = { best = 3, upgradeAt = 40, upgradeTo = 4 }, PALADIN = { best = 3, upgradeAt = 40, upgradeTo = 4 },
    HUNTER = { best = 2, upgradeAt = 40, upgradeTo = 3 }, SHAMAN = { best = 2, upgradeAt = 40, upgradeTo = 3 },
    ROGUE = { best = 2 }, DRUID = { best = 2 }, PRIEST = { best = 1 }, MAGE = { best = 1 }, WARLOCK = { best = 1 },
}
local SHIELD_CLASSES = { WARRIOR = true, PALADIN = true, SHAMAN = true }
Gear.WEAPONS, Gear.ARMOR = WEAPONS, ARMOR
local RELIC = { PALADIN = 7, DRUID = 8, SHAMAN = 9 }

-- Stat weights by class and role (rough, sensible defaults for levelling and dungeons).
local W = {
    tank = { STA = 1.0, ARMOR = 0.04, AGI = 0.6, STR = 0.6, DEF = 1.0, DPS = 0.5 },
    WARRIOR = { STR = 1.0, AGI = 0.7, STA = 0.4, AP = 0.45, CRIT = 8, HIT = 8, DPS = 2.5 },
    PALADIN = { STR = 1.0, INT = 0.4, STA = 0.4, AGI = 0.4, AP = 0.45, CRIT = 6, DPS = 2.2 },
    HUNTER = { AGI = 1.0, AP = 0.45, STA = 0.35, INT = 0.25, CRIT = 8, HIT = 8, DPS = 2.0 },
    ROGUE = { AGI = 1.0, STR = 0.5, AP = 0.45, STA = 0.35, CRIT = 8, HIT = 8, DPS = 2.5 },
    SHAMAN = { STR = 0.7, AGI = 0.6, INT = 0.5, STA = 0.35, AP = 0.35, SP = 0.6, DPS = 2.0 },
    DRUID = { AGI = 0.8, STR = 0.7, INT = 0.5, STA = 0.4, SP = 0.6, AP = 0.35 },
    PRIEST = { INT = 0.8, SP = 1.0, SPI = 0.5, STA = 0.4 },
    MAGE = { INT = 0.8, SP = 1.0, STA = 0.4, SPI = 0.3, CRIT = 8, HIT = 8 },
    WARLOCK = { SP = 1.0, STA = 0.6, INT = 0.6, SPI = 0.3, HIT = 8 },
    healer = { INT = 0.9, SPI = 0.6, HEAL = 1.0, SP = 0.5, MP5 = 2.0, STA = 0.35 },
}

local STAT_KEYS = {
    ITEM_MOD_STRENGTH_SHORT = "STR", ITEM_MOD_AGILITY_SHORT = "AGI", ITEM_MOD_STAMINA_SHORT = "STA",
    ITEM_MOD_INTELLECT_SHORT = "INT", ITEM_MOD_SPIRIT_SHORT = "SPI", ITEM_MOD_ATTACK_POWER_SHORT = "AP",
    ITEM_MOD_RANGED_ATTACK_POWER_SHORT = "AP", ITEM_MOD_SPELL_POWER_SHORT = "SP",
    ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = "SP", ITEM_MOD_SPELL_HEALING_DONE_SHORT = "HEAL",
    RESISTANCE0_NAME = "ARMOR", ITEM_MOD_DAMAGE_PER_SECOND_SHORT = "DPS", ITEM_MOD_CRIT_RATING_SHORT = "CRIT",
    ITEM_MOD_CRIT_MELEE_RATING_SHORT = "CRIT", ITEM_MOD_CRIT_SPELL_RATING_SHORT = "CRIT",
    ITEM_MOD_HIT_RATING_SHORT = "HIT", ITEM_MOD_HIT_MELEE_RATING_SHORT = "HIT", ITEM_MOD_HIT_SPELL_RATING_SHORT = "HIT",
    ITEM_MOD_MANA_REGENERATION_SHORT = "MP5", ITEM_MOD_POWER_REGEN0_SHORT = "MP5",
    ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = "DEF",
}

-- Inventory type -> equipment slots it competes with.
local SLOTS = {
    [1] = { 1 }, [2] = { 2 }, [3] = { 3 }, [5] = { 5 }, [20] = { 5 }, [6] = { 6 }, [7] = { 7 }, [8] = { 8 },
    [9] = { 9 }, [10] = { 10 }, [11] = { 11, 12 }, [12] = { 13, 14 }, [16] = { 15 }, [13] = { 16, 17 },
    [21] = { 16 }, [17] = { 16 }, [14] = { 17 }, [22] = { 17 }, [23] = { 17 }, [15] = { 18 }, [25] = { 18 },
    [26] = { 18 }, [28] = { 18 },
}
Gear.SLOT_NAMES = {
    [1] = INVTYPE_HEAD, [2] = INVTYPE_NECK, [3] = INVTYPE_SHOULDER, [5] = INVTYPE_CHEST, [6] = INVTYPE_WAIST,
    [7] = INVTYPE_LEGS, [8] = INVTYPE_FEET, [9] = INVTYPE_WRIST, [10] = INVTYPE_HAND, [11] = INVTYPE_FINGER,
    [12] = INVTYPE_TRINKET, [13] = INVTYPE_WEAPON, [14] = INVTYPE_SHIELD, [15] = INVTYPE_RANGED, [16] = INVTYPE_CLOAK,
    [17] = INVTYPE_2HWEAPON, [20] = INVTYPE_ROBE, [21] = INVTYPE_WEAPONMAINHAND, [22] = INVTYPE_WEAPONOFFHAND,
    [23] = INVTYPE_HOLDABLE, [25] = INVTYPE_THROWN, [26] = INVTYPE_RANGEDRIGHT, [28] = INVTYPE_RELIC,
}

local cache = {}

-- Equip location names -> inventory type numbers (for items the database doesn't know).
local EQUIP_LOC = {
    INVTYPE_HEAD = 1, INVTYPE_NECK = 2, INVTYPE_SHOULDER = 3, INVTYPE_CHEST = 5, INVTYPE_ROBE = 20,
    INVTYPE_WAIST = 6, INVTYPE_LEGS = 7, INVTYPE_FEET = 8, INVTYPE_WRIST = 9, INVTYPE_HAND = 10,
    INVTYPE_FINGER = 11, INVTYPE_TRINKET = 12, INVTYPE_CLOAK = 16, INVTYPE_WEAPON = 13, INVTYPE_SHIELD = 14,
    INVTYPE_2HWEAPON = 17, INVTYPE_WEAPONMAINHAND = 21, INVTYPE_WEAPONOFFHAND = 22, INVTYPE_HOLDABLE = 23,
    INVTYPE_RANGED = 15, INVTYPE_THROWN = 25, INVTYPE_RANGEDRIGHT = 26, INVTYPE_RELIC = 28,
}
local liveItems = {}

-- An item record with what the game says now. WoW Forever changed many items (boss drops
-- became rare, levels moved), so live quality, required level and slot beat the database.
-- Records are only cached once the game has the item's data; until then the database
-- record is returned and the item is requested.
function Gear.Item(itemID)
    if liveItems[itemID] then return liveItems[itemID] end
    local base = ns.DB and ns.DB.items[itemID]
    local quality = ns.Call(C_Item and C_Item.GetItemQualityByID, itemID)
    local _, _, _, equipLoc, _, classID, subclassID = ns.Call(C_Item and C_Item.GetItemInfoInstant, itemID)
    if quality == nil then
        if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, itemID) end
        if base then return base end
        if not classID then return nil end
        return { "item:" .. itemID, 2, EQUIP_LOC[equipLoc] or 0, 0, 0, classID, subclassID or 0, -1 }
    end
    local name, _, _, itemLevel, reqLevel = ns.Call(C_Item.GetItemInfo, itemID)
    local it = {
        name or (base and base[F_NAME]) or ("item:" .. itemID),
        quality,
        (equipLoc and EQUIP_LOC[equipLoc]) or (base and base[F_INV]) or 0,
        reqLevel or (base and base[F_REQ]) or 0,
        itemLevel or (base and base[F_ILVL]) or 0,
        classID or (base and base[F_CLASS]) or 0,
        subclassID or (base and base[F_SUB]) or 0,
        base and base[F_ALLOW] or -1,
    }
    liveItems[itemID] = it
    return it
end

-- Is this a recipe, pattern, plans, formula, schematic or blueprint? These aren't gear, so
-- they're listed for everyone and the "Usable only" filter leaves them alone.
local RECIPE_PREFIX = { "Pattern:", "Plans:", "Recipe:", "Formula:", "Schematic:", "Blueprint:", "Design:", "Manual:" }
function Gear.IsRecipe(itemID)
    local _, _, _, _, _, classID = ns.Call(C_Item and C_Item.GetItemInfoInstant, itemID)
    if classID then return classID == 9 end
    local base = ns.DB and ns.DB.items[itemID]
    if not base then return false end
    if base[F_CLASS] == 9 then return true end
    local name = base[F_NAME] or ""
    for _, pre in ipairs(RECIPE_PREFIX) do
        if name:sub(1, #pre) == pre then return true end
    end
    return false
end

-- Quality to color an item with (live from the game when it knows the item).
function Gear.Quality(itemID)
    local it = Gear.Item(itemID)
    return it and it[F_QUALITY] or 1
end

-- Can my class use (and want) this item at all?
function Gear.Usable(itemID, classFile, level)
    local it = Gear.Item(itemID)
    if not it then return true end
    classFile = classFile or ns.Data.MyClass()
    level = level or ns.Data.MyLevel()
    local allow = it[F_ALLOW]
    if allow and allow > 0 and allow ~= 32767 and CLASS_BIT[classFile] and bit.band(allow, CLASS_BIT[classFile]) == 0 then
        return false
    end
    local cls, sub, inv = it[F_CLASS], it[F_SUB], it[F_INV]
    if cls == 2 then
        return (WEAPONS[classFile] or {})[sub] ~= nil
    elseif cls == 4 then
        if sub == 6 then return SHIELD_CLASSES[classFile] or false end
        if sub == 7 or sub == 8 or sub == 9 then return RELIC[classFile] == sub end
        if sub >= 1 and sub <= 4 and inv ~= 16 then
            local a = ARMOR[classFile]
            local max = a and ((a.upgradeAt and level >= a.upgradeAt) and a.upgradeTo or a.best) or 1
            return sub <= max
        end
        return true
    end
    return inv and inv > 0
end

local function weightsFor(classFile, role)
    if role == "tank" then return W.tank end
    if role == "healer" then return W.healer end
    return W[classFile] or W.WARRIOR
end

local function statScore(link, weights)
    local stats = ns.Call(C_Item and C_Item.GetItemStats, link) or (GetItemStats and ns.Call(GetItemStats, link))
    if type(stats) ~= "table" then return nil end
    local s = 0
    for key, value in pairs(stats) do
        local short = STAT_KEYS[key]
        if short and weights[short] then s = s + weights[short] * (ns.Safe(value) or 0) end
    end
    return s
end

local function equippedScore(slot, weights)
    local link = GetInventoryItemLink("player", slot)
    if not link then return 0 end
    return statScore(link, weights) or 0
end

-- Evaluate an item for me. Returns { usable, gain (fraction, nil when unknown), slot } .
function Gear.Evaluate(itemID)
    local c = cache[itemID]
    if c then return c end
    local it = Gear.Item(itemID)
    local classFile, level = ns.Data.MyClass(), ns.Data.MyLevel()
    local res = { usable = Gear.Usable(itemID, classFile, level) }
    local inv = it and it[F_INV]
    if not res.usable or not inv or not SLOTS[inv] or (it and it[F_QUALITY] < 2) then
        cache[itemID] = res
        return res
    end
    local weights = weightsFor(classFile, ns.Data.MyMainRole())
    local score = statScore("item:" .. itemID, weights)
    if not score then
        if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, itemID) end
        return res -- not cached; try again when the item data arrives
    end
    local slots = SLOTS[inv]
    local current
    if inv == 17 then
        current = equippedScore(16, weights) + equippedScore(17, weights)
    else
        for _, slot in ipairs(slots) do
            local v = equippedScore(slot, weights)
            if not current or v < current then current = v end -- replace the weaker ring/trinket
        end
    end
    res.slot = inv
    res.score = score
    if score > 0 then
        res.gain = (score - (current or 0)) / math.max(current or 0, 1)
    end
    res.levelOK = not it or it[F_REQ] <= level
    cache[itemID] = res
    return res
end

function Gear.IsUpgrade(itemID)
    local r = Gear.Evaluate(itemID)
    return r.usable and r.gain and r.gain > 0.02 or false, r
end

-- Upgrade text like "+12%".
function Gear.GainText(r)
    if not (r and r.gain and r.gain > 0.02) then return nil end
    if r.gain > 9.99 then return "+999%" end
    return ("+%d%%"):format(floor(r.gain * 100 + 0.5))
end

-- A boss's loot as { itemID, chance, ... }: the database plus drops seen in Forever.
function Gear.LootList(npcID)
    local base = ns.DB and ns.DB.loot[npcID]
    local learned = ns.Learn and ns.Learn.LootFor(npcID) or {}
    if #learned == 0 then return base end
    local out, have = {}, {}
    if base then
        for i = 1, #base, 2 do out[#out + 1] = base[i]; out[#out + 1] = base[i + 1]; have[base[i]] = true end
    end
    for _, e in ipairs(learned) do
        if not have[e.item] then out[#out + 1] = e.item; out[#out + 1] = e.chance end
    end
    return out
end

-- Best upgrades from dungeons that suit my level: list of { item, gain, npc, map, chance }.
function Gear.Upgrades(levelSlack)
    local out = {}
    local DB = ns.DB
    if not DB then return out end
    local level = ns.Data.MyLevel()
    levelSlack = levelSlack or 3
    for mapID, d in pairs(DB.dungeons) do
        if not d.raid and d.min <= level + levelSlack and d.max >= level - 4 then
            for _, b in ipairs(d.bosses) do
                local lootList = Gear.LootList(b[2])
                if lootList then
                    for i = 1, #lootList, 2 do
                        local itemID, chance = lootList[i], lootList[i + 1]
                        local it = Gear.Item(itemID)
                        if it and it[F_REQ] <= level + levelSlack then
                            local up, r = Gear.IsUpgrade(itemID)
                            if up then
                                tinsert(out, { item = itemID, gain = r.gain, slot = r.slot, npc = b[2], boss = b[3], map = mapID, chance = chance })
                            end
                        end
                    end
                end
            end
        end
    end
    table.sort(out, function(a, b) return a.gain > b.gain end)
    return out
end

-- How many upgrades a dungeon holds for me (for badges).
function Gear.CountForDungeon(mapID)
    local d = ns.DB and ns.DB.dungeons[mapID]
    if not d then return 0 end
    local n = 0
    for _, b in ipairs(d.bosses) do
        local lootList = Gear.LootList(b[2])
        if lootList then
            for i = 1, #lootList, 2 do
                if Gear.IsUpgrade(lootList[i]) then n = n + 1 end
            end
        end
    end
    return n
end

local function reset() wipe(cache); ns.Fire("GEAR_CHANGED") end
local resetSoon = ns.Debounce(0.5, reset)
ns.On("PLAYER_EQUIPMENT_CHANGED", resetSoon)
ns.On("PLAYER_LEVEL_UP", resetSoon)
ns.Listen("MY_INFO_CHANGED", resetSoon)
ns.On("ITEM_DATA_LOAD_RESULT", resetSoon)
ns.On("GET_ITEM_INFO_RECEIVED", resetSoon)
ns.Listen("LEARNED_CHANGED", resetSoon)
