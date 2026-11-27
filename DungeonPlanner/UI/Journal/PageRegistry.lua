-- PageRegistry.lua
-- Journal pages that aren't a dungeon: Gear Upgrades, Character Logs, Wishlist, Party Quests.
-- Each registers itself; the list on the left and the header pick them up.
local _, ns = ...
local J = ns.Journal
local P = ns.Private("Journal")

-- Pages that aren't a dungeon (Gear Upgrades, Character Logs, Wishlist, Party Quests).
-- def = { nav = text, icon = atlas, order = n, title = fn(cur), sub = fn(cur), rows = fn(cur), button = fn(cur) }
function J.RegisterPage(id, def)
    def.id = id
    P.pages[id] = def
end
function J.ShowPage(id, arg)
    if not P.pages[id] then return end
    P.current = { kind = id, arg = arg }
    J.Open()
    J.Refresh()
end
function J.CurrentPage() return P.current.kind, P.current.arg end
