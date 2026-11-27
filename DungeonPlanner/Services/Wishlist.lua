-- Wishlist: items you want. Right-click any item in the journal to add or remove it.
-- The journal lists them by dungeon, the Group Finder marks groups going where they drop,
-- and when a boss that can drop one dies you get a warning to check the loot.
-- Per character: ns.cdb.wishlist[itemID] = { boss, dungeon, added }
local _, ns = ...
local L = ns.L

local WL = {}
ns.Wishlist = WL

local function list() return ns.cdb and ns.cdb.wishlist or {} end

function WL.Has(itemID) return itemID and list()[itemID] ~= nil or false end

function WL.Count()
    local n = 0
    for _ in pairs(list()) do n = n + 1 end
    return n
end

-- Where it drops: the best source we know, else what the caller saw.
local function sourceOf(itemID, boss, dungeon)
    local src = ns.ItemSources and ns.ItemSources.For(itemID)
    if src and src[1] then return src[1].boss, src[1].dungeon end
    return boss, dungeon
end

function WL.Add(itemID, boss, dungeon)
    if not (itemID and ns.cdb) then return end
    ns.cdb.wishlist = ns.cdb.wishlist or {}
    local b, d = sourceOf(itemID, boss, dungeon)
    ns.cdb.wishlist[itemID] = { boss = b, dungeon = d, added = ns.Now() }
    ns.Fire("WISHLIST_CHANGED")
end

function WL.Remove(itemID)
    if not (itemID and ns.cdb and ns.cdb.wishlist) then return end
    ns.cdb.wishlist[itemID] = nil
    ns.Fire("WISHLIST_CHANGED")
end

function WL.Toggle(itemID, boss, dungeon)
    if WL.Has(itemID) then
        WL.Remove(itemID)
        ns.Print(L.WISH_REMOVED:format(WL.Link(itemID)))
    else
        WL.Add(itemID, boss, dungeon)
        ns.Print(L.WISH_ADDED:format(WL.Link(itemID)))
    end
end

function WL.Link(itemID)
    local _, link = ns.Call(C_Item and C_Item.GetItemInfo, itemID)
    if link then return link end
    local name = ns.Call(C_Item and C_Item.GetItemNameByID, itemID)
    return name or ("item:" .. itemID)
end

-- Every wished item that drops in a dungeon (by any of its names).
function WL.ForDungeon(...)
    local out = {}
    local names = {}
    for i = 1, select("#", ...) do
        local n = select(i, ...)
        if n then names[ns.Data.Normalize(n)] = true end
    end
    for itemID, w in pairs(list()) do
        local hit = w.dungeon and names[ns.Data.Normalize(w.dungeon)]
        if not hit then
            for _, src in ipairs(ns.ItemSources and ns.ItemSources.For(itemID) or {}) do
                if names[ns.Data.Normalize(src.dungeon)] then hit = true break end
            end
        end
        if hit then tinsert(out, itemID) end
    end
    table.sort(out)
    return out
end

-- Wished items a boss can drop (boss names compare loosely: Forever renamed some).
function WL.ForBoss(bossName)
    local out = {}
    if not bossName then return out end
    local key = ns.Data.Normalize(bossName)
    for itemID, w in pairs(list()) do
        local hit = w.boss and ns.Data.Normalize(w.boss) == key
        if not hit then
            for _, src in ipairs(ns.ItemSources and ns.ItemSources.For(itemID) or {}) do
                if not src.trash and ns.Data.Normalize(src.boss) == key then hit = true break end
            end
        end
        if hit then tinsert(out, itemID) end
    end
    return out
end

-- Grouped for the journal page: { { dungeon, items = { itemID... } }, ... } by dungeon name.
function WL.Grouped()
    local byDungeon, order = {}, {}
    for itemID, w in pairs(list()) do
        local d = w.dungeon or L.WISH_UNKNOWN_SOURCE
        if not byDungeon[d] then byDungeon[d] = { dungeon = d, items = {} }; tinsert(order, byDungeon[d]) end
        tinsert(byDungeon[d].items, itemID)
    end
    table.sort(order, function(a, b) return a.dungeon < b.dungeon end)
    for _, g in ipairs(order) do table.sort(g.items) end
    return order
end

-- A boss died: if it can drop something you want, say so loudly.
ns.Listen("BOSS_KILLED", function(bossName, alias)
    if not (ns.opt and ns.opt.wishlistAlerts) then return end
    local items = WL.ForBoss(bossName)
    if #items == 0 and alias then items = WL.ForBoss(alias) end
    if #items == 0 then return end
    local links = {}
    for _, id in ipairs(items) do tinsert(links, WL.Link(id)) end
    local text = L.WISH_ALERT:format(bossName, table.concat(links, ", "))
    ns.Print(text)
    if RaidNotice_AddMessage and RaidWarningFrame then
        pcall(RaidNotice_AddMessage, RaidWarningFrame, L.WISH_ALERT_SHORT:format(bossName), ChatTypeInfo and ChatTypeInfo.RAID_WARNING or { r = 1, g = 0.82, b = 0 })
    end
    if PlaySound and SOUNDKIT then pcall(PlaySound, SOUNDKIT.RAID_WARNING or 8959) end
end)
