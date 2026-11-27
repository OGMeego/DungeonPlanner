-- Lists.lua
-- Building the list data for the Group Finder panel.
local _, ns = ...
local P = ns.Private("Finder.UI")

-- ---------------------------------------------------------------------------
-- Building the list data
-- ---------------------------------------------------------------------------

local function listingVisible(l, info)
    local c = ns.cdb
    local filter = c.dungeonFilter or 0
    if filter > 0 then
        local found = false
        for _, a in ipairs(l.activities) do if a.id == filter then found = true break end end
        if not found then return false end
    elseif filter == 0 then
        local fits = false
        for _, a in ipairs(l.activities) do
            if ns.Data.LevelFits(a, ns.Data.MyLevel()) then fits = true break end
        end
        if not fits and #l.activities > 0 then return false end
    end
    if l.solo and not ns.opt.showPlayers then return false end
    if not l.solo and not ns.opt.showGroups then return false end
    if info.avoid and ns.opt.hideAvoided then return false end
    local rf = c.roleFilter
    if rf and not (rf.tank and rf.healer and rf.dps) then
        local ok = false
        for _, r in ipairs(P.ROLE_ORDER) do
            if rf[r] then
                if l.solo then
                    local offers = (info.peer and info.peer.roles) or l.roles or {}
                    if offers[r] then ok = true end
                elseif info.open and info.open[r] > 0 then
                    ok = true
                end
            end
        end
        if not ok then return false end
    end
    return true
end

local SORTS = {
    match = function(a, b)
        if a.info.score ~= b.info.score then return a.info.score > b.info.score end
        return (a.l.age or 0) < (b.l.age or 0)
    end,
    newest = function(a, b) return (a.l.age or 0) < (b.l.age or 0) end,
    level = function(a, b)
        local me = ns.Data.MyLevel()
        local da, db = math.abs((a.l.level or 0) - me), math.abs((b.l.level or 0) - me)
        if da ~= db then return da < db end
        return a.info.score > b.info.score
    end,
    name = function(a, b) return (a.l.leader or "") < (b.l.leader or "") end,
}

function P.buildListings()
    local out = {}
    for _, l in ipairs(ns.Finder.listings) do
        local _, info = ns.Score.Listing(l)
        if listingVisible(l, info) then
            tinsert(out, { kind = "listing", key = l.key, l = l, info = info })
        end
    end
    table.sort(out, SORTS[ns.opt.sort] or SORTS.match)
    return out
end

function P.buildApplicants()
    local out = {}
    for _, a in ipairs(ns.Inbox.list) do
        local _, info = ns.Score.Applicant(a)
        if not (info.avoid and ns.opt.hideAvoided) then
            tinsert(out, { kind = "applicant", key = a.key, a = a, info = info })
        end
    end
    table.sort(out, function(x, y)
        if x.a.unread ~= y.a.unread then return x.a.unread end
        if x.info.score ~= y.info.score then return x.info.score > y.info.score end
        return (x.a.at or 0) > (y.a.at or 0)
    end)
    return out
end
