-- LootFilter: which loot the journal lists, per character: armor type, weapon types and
-- stats. Works on top of "Usable only". Saved in ns.cdb.lootFilter:
--   armor = "any" | "best" | 1 cloth | 2 leather | 3 mail | 4 plate
--   weapons = { [subclass] = true } or nil (all)     stats = { STR = true, ... } or nil (any)
local _, ns = ...
local L = ns.L

local LF = {}
ns.LootFilter = LF

LF.STATS = {
    { key = "STR", label = "ITEM_MOD_STRENGTH_SHORT", game = "ITEM_MOD_STRENGTH_SHORT" },
    { key = "AGI", label = "ITEM_MOD_AGILITY_SHORT", game = "ITEM_MOD_AGILITY_SHORT" },
    { key = "STA", label = "ITEM_MOD_STAMINA_SHORT", game = "ITEM_MOD_STAMINA_SHORT" },
    { key = "INT", label = "ITEM_MOD_INTELLECT_SHORT", game = "ITEM_MOD_INTELLECT_SHORT" },
    { key = "SPI", label = "ITEM_MOD_SPIRIT_SHORT", game = "ITEM_MOD_SPIRIT_SHORT" },
}

function LF.Settings()
    if not ns.cdb then return { armor = "any" } end
    ns.cdb.lootFilter = ns.cdb.lootFilter or { armor = "any" }
    return ns.cdb.lootFilter
end

function LF.Active()
    local s = LF.Settings()
    return s.armor ~= "any" or s.weapons ~= nil or (s.stats ~= nil and next(s.stats) ~= nil)
end

local function bestArmor()
    local a = ns.Gear.ARMOR[ns.Data.MyClass()]
    if not a then return 1 end
    return (a.upgradeAt and ns.Data.MyLevel() >= a.upgradeAt) and a.upgradeTo or a.best
end

local function statsOf(itemID)
    local _, link = ns.Call(C_Item and C_Item.GetItemInfo, itemID)
    if not link then return nil end
    local stats = ns.Call(C_Item and C_Item.GetItemStats, link) or (GetItemStats and ns.Call(GetItemStats, link))
    return type(stats) == "table" and stats or nil
end

function LF.Pass(itemID)
    if not itemID then return true end
    local s = LF.Settings()
    local it = ns.Gear.Item(itemID)
    if not it then return true end
    local cls, sub, inv = it[6], it[7], it[3]
    -- Armor type (cloaks, rings, necks, trinkets and shields are left alone)
    if cls == 4 and sub >= 1 and sub <= 4 and inv ~= 16 and s.armor ~= "any" then
        local want = s.armor == "best" and bestArmor() or s.armor
        if sub ~= want then return false end
    end
    -- Weapon types
    if cls == 2 and s.weapons and not s.weapons[sub] then return false end
    -- Stats: at least one of the chosen ones (items the game hasn't loaded yet stay)
    if s.stats and next(s.stats) then
        local stats = statsOf(itemID)
        if stats then
            local hit = false
            for _, st in ipairs(LF.STATS) do
                if s.stats[st.key] and (stats[st.game] or 0) > 0 then hit = true break end
            end
            if not hit then return false end
        end
    end
    return true
end

-- The game's own name for an item subclass (C_Item on this client), else ours.
local function subclassName(class, sub)
    local fn = (C_Item and C_Item.GetItemSubClassInfo) or GetItemSubClassInfo
    local name = fn and ns.Safe(ns.Call(fn, class, sub))
    if type(name) == "string" and name ~= "" then return name end
end

local function weaponName(sub)
    return subclassName(2, sub) or L["LF_WEAPON_" .. sub] or ("#" .. sub)
end

-- The Loot filter submenu (added to the journal's Filter menu).
function LF.BuildMenu(root, refresh)
    local s = LF.Settings()
    local menu = root:CreateButton(L.LF_TITLE)
    if not (menu and menu.CreateRadio) then return end
    menu:CreateTitle(L.LF_ARMOR)
    local function armorRadio(text, value)
        menu:CreateRadio(text, function() return s.armor == value end, function() s.armor = value; refresh() end)
    end
    armorRadio(L.LF_ARMOR_ANY, "any")
    armorRadio(L.LF_ARMOR_BEST, "best")
    for v = 1, 4 do
        armorRadio(subclassName(4, v) or L["LF_ARMOR_" .. v], v)
    end
    menu:CreateTitle(L.LF_WEAPONS)
    local mine = ns.Gear.WEAPONS[ns.Data.MyClass()] or {}
    menu:CreateCheckbox(L.LF_WEAPONS_ALL, function() return s.weapons == nil end,
        function() s.weapons = nil; refresh() end)
    local subs = {}
    for sub in pairs(mine) do tinsert(subs, sub) end
    table.sort(subs)
    for _, sub in ipairs(subs) do
        menu:CreateCheckbox(weaponName(sub), function() return s.weapons == nil or s.weapons[sub] or false end,
            function()
                if not s.weapons then
                    -- From "all": keep every type but this one.
                    s.weapons = {}
                    for w in pairs(mine) do s.weapons[w] = true end
                end
                s.weapons[sub] = not s.weapons[sub] or nil
                refresh()
            end)
    end
    menu:CreateTitle(L.LF_STATS)
    for _, st in ipairs(LF.STATS) do
        menu:CreateCheckbox(_G[st.label] or st.key, function() return s.stats and s.stats[st.key] or false end,
            function()
                s.stats = s.stats or {}
                s.stats[st.key] = not s.stats[st.key] or nil
                refresh()
            end)
    end
    menu:CreateButton(L.LF_RESET, function() ns.cdb.lootFilter = { armor = "any" }; refresh() end)
end
