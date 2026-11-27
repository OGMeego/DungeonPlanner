-- DungeonList.lua
-- The dungeon list: database dungeons plus Forever's new dungeons.
local _, ns = ...
local L = ns.L
local J = ns.Journal
local P = ns.Private("Journal")

-- ---------------------------------------------------------------------------
-- Dungeon list (database dungeons + Forever dungeons the Group Finder knows)
-- ---------------------------------------------------------------------------

-- Forever's new dungeons: every curated one (with its Group Finder activity when the game
-- has one), plus any other Group Finder dungeon our database doesn't know.
local function foreverDungeons()
    local out, used = {}, {}
    for _, f in ipairs(ns.ForeverDB or {}) do
        local match
        for _, a in ipairs(ns.Data.dungeonList) do
            if not used[a] and ns.ForeverFor(a.fullName or a.name) == f then match = a break end
        end
        if match then
            used[match] = true
            match.forever = f
            tinsert(out, match)
        else
            tinsert(out, { name = f.name, minLevel = f.min, maxLevel = f.max, forever = f })
        end
    end
    for _, a in ipairs(ns.Data.dungeonList) do
        if not used[a] and not (a.mapID and ns.DB.dungeons[a.mapID]) then
            if not a.forever then a.forever = ns.ForeverFor(a.fullName or a.name) end
            tinsert(out, a)
        end
    end
    return out
end
J.ForeverDungeons = foreverDungeons

function P.navData()
    local level = ns.Data.MyLevel()
    local groups = { now = {}, soon = {}, below = {}, raid = {} }
    local search = strlower(P.filterText or "")
    for mapID, d in pairs(ns.DB.dungeons) do
        if not ns.opt.foreverOnly and (search == "" or strlower(d.name):find(search, 1, true)) then
            local bucket
            if d.raid then bucket = "raid"
            elseif level >= d.min and level <= d.max then bucket = "now"
            elseif level < d.min then bucket = "soon"
            else bucket = "below" end
            tinsert(groups[bucket], { kind = "dungeon", map = mapID, d = d, h = 54 })
        end
    end
    for _, a in ipairs(foreverDungeons()) do
        if search == "" or strlower(a.name):find(search, 1, true) then
            local lo = (a.forever and a.forever.min) or a.minLevel or 0
            local hi = (a.forever and a.forever.max) or a.maxLevel or 60
            local bucket
            if level >= lo and level <= hi then bucket = "now"
            elseif level < lo then bucket = "soon"
            else bucket = "below" end
            tinsert(groups[bucket], { kind = "activity", a = a, d = { min = lo, max = hi }, h = 54 })
        end
    end
    for _, g in pairs(groups) do
        table.sort(g, function(a, b) return a.d.min < b.d.min end)
    end
    local out = {}
    local pages = {}
    for _, pg in pairs(P.pages) do if pg.nav and (not pg.shown or pg.shown()) then tinsert(pages, pg) end end
    table.sort(pages, function(a, b) return (a.order or 50) < (b.order or 50) end)
    for _, pg in ipairs(pages) do
        tinsert(out, { kind = "special", page = pg.id, text = pg.nav, icon = pg.icon, iconTex = pg.iconTex, action = pg.action, count = pg.count and pg.count() })
    end
    local function section(title, list)
        if #list == 0 then return end
        tinsert(out, { kind = "header", text = title })
        for _, e in ipairs(list) do tinsert(out, e) end
    end
    section(L.J_FOR_LEVEL, groups.now)
    section(L.J_COMING_UP, groups.soon)
    section(L.J_BELOW, groups.below)
    section(L.J_RAIDS, groups.raid)
    return out
end

-- The Group Finder activity for a database dungeon (for "Find Group").
function P.activityForMap(mapID)
    for _, a in ipairs(ns.Data.dungeonList) do
        if a.mapID == mapID then return a end
    end
    local d = ns.DB.dungeons[mapID]
    return d and ns.Data.byName[ns.Data.Normalize(d.name)]
end
J.ActivityForMap = P.activityForMap
