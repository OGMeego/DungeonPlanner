-- WishlistPage.lua
-- Your wishlist in the journal, by dungeon. Right-click an item to take it off.
local _, ns = ...
local L = ns.L
local J = ns.Journal
local P = ns.Private("Journal")

-- Open the dungeon a wished item drops in.
local function openDungeon(name)
    local key = ns.Data.Normalize(name)
    for mapID, d in pairs(ns.DB.dungeons) do
        if ns.Data.Normalize(d.name) == key then return J.ShowDungeon(mapID, 3) end
    end
    for _, a in ipairs(J.ForeverDungeons and J.ForeverDungeons() or {}) do
        local f = a.forever
        if ns.Data.Normalize(a.name) == key or (f and ns.Data.Normalize(f.name) == key) then
            J.ShowActivity(a)
            return J.SelectTab(3)
        end
    end
end

local function wishRows()
    local WL = ns.Wishlist
    local rows = {}
    local groups = WL.Grouped()
    if #groups == 0 then
        tinsert(rows, { kind = "text", h = 60, text = L.WISH_EMPTY })
        return rows
    end
    tinsert(rows, { kind = "text", h = 30, text = GRAY_FONT_COLOR:WrapTextInColorCode(L.WISH_HINT) })
    for _, g in ipairs(groups) do
        tinsert(rows, { kind = "line", h = 40, card = { g.dungeon }, text = g.dungeon, right = L.WISH_OPEN,
            onClick = function() openDungeon(g.dungeon) end })
        for _, itemID in ipairs(g.items) do
            local w = ns.cdb.wishlist[itemID]
            local src = ns.ItemSources.For(itemID)
            local chance = src and src[1] and src[1].chance
            tinsert(rows, { kind = "item", item = itemID, bossName = w.boss, dungeon = w.dungeon,
                boss = w.boss, chance = chance and (chance >= 10 and ("%d"):format(math.floor(chance + 0.5)) or ("%.1f"):format(chance)), h = 32 })
        end
        tinsert(rows, { kind = "spacer", h = 8 })
    end
    return rows
end

J.RegisterPage("wishlist", { nav = L.WISH_TITLE, icon = "PetJournal-FavoritesIcon", order = 30,
    count = function() return ns.Wishlist.Count() end,
    title = function() return L.WISH_TITLE end,
    sub = function() return L.WISH_SUB:format(ns.Wishlist.Count()) end,
    rows = wishRows })

ns.Listen("WISHLIST_CHANGED", function() J.Refresh() end)
