-- ItemSources: where an item drops, for any item tooltip in the game.
-- "Drops from Mr. Smite, The Deadmines (20%)". Built once from the dungeon database (bosses
-- and trash) and Forever's own loot lists, plus loot you saw drop yourself.
local _, ns = ...
local L = ns.L

local IS = {}
ns.ItemSources = IS

local B_NPC, B_NAME = 2, 3
local index   -- itemID -> { { boss, dungeon, chance, map?, trash? }, ... }

local function add(item, src)
    if not item then return end
    index[item] = index[item] or {}
    tinsert(index[item], src)
end

function IS.Build()
    index = {}
    for mapID, d in pairs(ns.DB and ns.DB.dungeons or {}) do
        for _, b in ipairs(d.bosses or {}) do
            local loot = ns.DB.loot[b[B_NPC]]
            for i = 1, #(loot or {}), 2 do
                add(loot[i], { boss = b[B_NAME], dungeon = d.name, chance = loot[i + 1], map = mapID })
            end
        end
        local trash = ns.DB.trash and ns.DB.trash[mapID]
        for i = 1, #(trash or {}), 3 do
            add(trash[i], { boss = L.J_TRASH, dungeon = d.name, chance = trash[i + 1], map = mapID, trash = true })
        end
    end
    for _, f in ipairs(ns.ForeverDB or {}) do
        for _, b in ipairs(f.bosses or {}) do
            for _, l in ipairs(b.loot or {}) do
                if l.id then add(l.id, { boss = b.name, dungeon = f.name, chance = l[3], forever = f.name }) end
            end
        end
    end
    -- Sort: likeliest first.
    for _, list in pairs(index) do
        table.sort(list, function(a, b) return (a.chance or 0) > (b.chance or 0) end)
    end
    return index
end

function IS.For(itemID)
    if not index then IS.Build() end
    return itemID and index[itemID]
end

function IS.Text(src)
    local where = src.trash and L.SRC_TRASH:format(src.dungeon) or L.SRC_BOSS:format(src.boss, src.dungeon)
    if src.chance and src.chance > 0 then
        return where .. (" (%s%%)"):format(src.chance >= 10 and ("%d"):format(math.floor(src.chance + 0.5)) or ("%.1f"):format(src.chance))
    end
    return where
end

-- Tooltip lines.
local MAX_LINES = 3
local function addLines(tt, itemID)
    if not (ns.opt and ns.opt.itemSources) then return end
    itemID = ns.Safe(itemID)
    local list = itemID and IS.For(itemID)
    local wished = ns.Wishlist and ns.Wishlist.Has(itemID)
    if not list and not wished then return end
    if list then
        for i = 1, math.min(MAX_LINES, #list) do
            tt:AddLine((i == 1 and (L.SRC_PREFIX .. " ") or "     ") .. IS.Text(list[i]), 0.55, 0.78, 1)
        end
        if #list > MAX_LINES then tt:AddLine("     " .. L.SRC_MORE:format(#list - MAX_LINES), 0.5, 0.5, 0.5) end
    end
    if wished then tt:AddLine(ns.AtlasMarkup("PetJournal-FavoritesIcon", 12) .. " " .. L.WISH_ON_LIST, 1, 0.82, 0) end
end
IS.AddLines = addLines

local hooked = false
function IS.Hook()
    if hooked then return end
    hooked = true
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data)
            if tt ~= GameTooltip and tt ~= ItemRefTooltip then return end
            local id = data and ns.Safe(ns.Field(data, "id"))
            if id then pcall(addLines, tt, id) end
        end)
    elseif GameTooltip and GameTooltip.HookScript then
        local function onItem(tt)
            local _, link = tt:GetItem()
            local id = link and tonumber(link:match("item:(%d+)"))
            if id then pcall(addLines, tt, id) end
        end
        pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipSetItem", onItem)
        if ItemRefTooltip then pcall(ItemRefTooltip.HookScript, ItemRefTooltip, "OnTooltipSetItem", onItem) end
    end
end

ns.Listen("DB_READY", IS.Hook)
ns.Listen("LEARNED_CHANGED", function() index = nil end)
