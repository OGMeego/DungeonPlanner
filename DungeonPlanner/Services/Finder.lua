-- Finder: reads the Group Finder's search results into simple listing records.
-- On WoW Forever only Blizzard's own window may start a search (C_LFGList.Search is
-- protected), so we read whatever it last found and refresh by clicking its button
-- securely (see UI.lua).
local _, ns = ...

local Finder = {}
ns.Finder = Finder

Finder.listings = {}      -- current records, unsorted
Finder.updated = nil      -- ns.Now() of the last results
Finder.searching = false

local C = C_LFGList

local function roleSet(t)
    local set = {}
    if type(t) ~= "table" then return set end
    set.tank = ns.Field(t, "tank") and true or nil
    set.healer = ns.Field(t, "healer") and true or nil
    set.dps = ns.Field(t, "dps") and true or nil
    if not (set.tank or set.healer or set.dps) then
        -- Older shapes: a list of role tokens.
        pcall(function()
            for k, v in pairs(t) do
                local token = strlower(tostring(v == true and k or v))
                if token:find("tank") then set.tank = true end
                if token:find("heal") then set.healer = true end
                if token:find("dam") or token:find("dps") then set.dps = true end
            end
        end)
    end
    return set
end

local ASSIGNED = { TANK = "tank", HEALER = "healer", DAMAGER = "dps" }

local function readMember(id, index)
    local p = ns.Call(C.GetSearchResultPlayerInfo, id, index)
    if type(p) ~= "table" then return nil end
    return {
        name = ns.Field(p, "name"),
        class = ns.Field(p, "classFilename"),
        level = ns.Field(p, "level"),
        area = ns.Field(p, "areaName"),
        assigned = ASSIGNED[ns.Field(p, "assignedRole") or ""],
        roles = roleSet(ns.Field(p, "lfgRoles")),
        leader = ns.Field(p, "isLeader"),
    }
end

local function readCounts(id)
    local c = ns.Call(C.GetSearchResultMemberCounts, id)
    if type(c) ~= "table" then return nil end
    return {
        tank = ns.Field(c, "TANK") or 0,
        healer = ns.Field(c, "HEALER") or 0,
        dps = ns.Field(c, "DAMAGER") or 0,
        none = ns.Field(c, "NOROLE") or 0,
    }
end

function Finder.Read(id)
    id = ns.Safe(id)
    if not id then return nil end
    local info = ns.Call(C.GetSearchResultInfo, id)
    if type(info) ~= "table" then return nil end
    if ns.Field(info, "isDelisted") or ns.Field(info, "hasSelf") then return nil end

    local l = {
        id = id,
        leader = ns.Field(info, "leaderName"),
        comment = ns.Field(info, "comment"),
        numMembers = ns.Field(info, "numMembers") or 1,
        age = ns.Field(info, "age") or 0,
        playstyle = ns.Field(info, "generalPlaystyle"),
        newPlayerFriendly = ns.Field(info, "newPlayerFriendly"),
        numFriends = (ns.Field(info, "numBNetFriends") or 0) + (ns.Field(info, "numCharFriends") or 0),
        numGuild = ns.Field(info, "numGuildMates") or 0,
        activities = {},
        members = {},
    }
    l.key = ns.Key(l.leader)
    if not l.key then return nil end

    local ids = ns.Field(info, "activityIDs")
    if type(ids) == "table" then
        for _, aid in ipairs(ids) do
            local a = ns.Data.Activity(aid)
            if a then tinsert(l.activities, a) end
        end
    end

    for i = 1, math.min(l.numMembers, 5) do
        local m = readMember(id, i)
        if m then tinsert(l.members, m) end
    end
    l.solo = l.numMembers <= 1
    local lead = l.members[1]
    for _, m in ipairs(l.members) do
        if m.leader then lead = m break end
    end
    if lead then
        l.class, l.level, l.area = lead.class, lead.level, lead.area
        l.roles = lead.roles
    end
    l.counts = readCounts(id)
    return l
end

function Finder.ReadAll()
    local total, results = ns.Call(C and C.GetFilteredSearchResults)
    if type(results) ~= "table" then
        total, results = ns.Call(C and C.GetSearchResults)
    end
    wipe(Finder.listings)
    if type(results) == "table" then
        for _, id in ipairs(results) do
            local l = Finder.Read(id)
            if l then tinsert(Finder.listings, l) end
        end
    end
    Finder.updated = ns.Now()
    Finder.searching = false
    ns.Fire("LISTINGS_CHANGED")
end

local function updateOne(id)
    for i, old in ipairs(Finder.listings) do
        if old.id == id then
            local l = Finder.Read(id)
            if l then Finder.listings[i] = l else tremove(Finder.listings, i) end
            ns.Fire("LISTINGS_CHANGED")
            return
        end
    end
end

-- Blizzard's browse window is loaded on demand; read its state without touching it.
function Finder.BrowseFrame() return _G.LFGBrowseFrame end

-- Has Blizzard's window chosen something to search for? Only then does its refresh work.
function Finder.CanRefresh()
    local b = Finder.BrowseFrame()
    if not (b and b.CategoryDropdown and b.RefreshButton) then return false end
    local ok, value = pcall(b.CategoryDropdown.GetValue, b.CategoryDropdown)
    return ok and type(value) == "number" and value > 0
end

function Finder.IsSearching()
    local b = Finder.BrowseFrame()
    return (b and b.searching) and true or false
end

-- Lookup by player key (solo listings and group members), for the applicant inbox.
function Finder.FindPlayer(key)
    for _, l in ipairs(Finder.listings) do
        for _, m in ipairs(l.members) do
            if ns.Key(m.name) == key then return m, l end
        end
        if l.key == key then return l.members[1], l end
    end
end

ns.On("LFG_LIST_SEARCH_RESULTS_RECEIVED", Finder.ReadAll)
ns.On("LFG_LIST_SEARCH_RESULT_UPDATED", updateOne)
ns.On("LFG_LIST_SEARCH_FAILED", function()
    Finder.searching = false
    ns.Fire("LISTINGS_CHANGED")
end)
