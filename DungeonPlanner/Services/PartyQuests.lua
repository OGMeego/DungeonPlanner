-- PartyQuests: which dungeon quests each member of your group has. Dungeon Planner users in
-- your group swap their lists over the group's addon channel (never a whisper), so the
-- Party Quests page can show who still needs what, and who can share it.
local _, ns = ...
local L = ns.L

local PQ = {}
ns.PartyQuests = PQ

local SEP, MAX_BYTES = ";", 240
PQ.members = {}   -- name -> { quests = { [id] = { title, dungeon } }, seen }

local function strip(s) return (tostring(s or ""):gsub("[,:;|]", " ")) end

-- My dungeon quests: { [id] = { title, dungeon } }
function PQ.Mine()
    local out = {}
    for id, q in pairs(ns.Data.quests or {}) do
        local d = q.dungeon
        out[id] = { title = q.title, dungeon = d and ((d.forever and d.forever.name) or d.fullName or d.name) or nil, complete = q.complete }
    end
    return out
end

function PQ.Message()
    local parts = {}
    local len = 2
    for id, q in pairs(PQ.Mine()) do
        local known = ns.DB and ns.DB.quests[id]
        local e = known and tostring(id) or (id .. ":" .. strip(q.title):sub(1, 40) .. ":" .. strip(q.dungeon):sub(1, 30))
        if len + #e + 1 > MAX_BYTES then break end
        tinsert(parts, e)
        len = len + #e + 1
    end
    return "Q" .. SEP .. table.concat(parts, ",")
end

function PQ.Send()
    if ns.Comm and ns.Comm.Group then ns.Comm.Group(PQ.Message()) end
end
local sendSoon = ns.Debounce(3, PQ.Send)

-- Ask the group to send theirs (when the page opens).
function PQ.Ask()
    PQ.askedAt = GetTime()
    if ns.Comm and ns.Comm.Group then ns.Comm.Group("QR"); PQ.Send() end
    ns.After(7, function() ns.Fire("PARTY_QUESTS_CHANGED") end)
end

local function inGroup(name)
    local n = ns.Call(GetNumGroupMembers) or 0
    local prefix = (IsInRaid and IsInRaid()) and "raid" or "party"
    for i = 1, n do
        local u = ns.Safe(ns.Call(UnitName, prefix .. i))
        if u and ns.SameName(u, name) then return true end
    end
    return false
end

local function dungeonOf(id)
    local q = ns.DB and ns.DB.quests[id]
    local d = q and q[10] and ns.DB.dungeons[q[10]]
    return d and d.name
end

-- The group members, by unit: { { unit, name } }
local function groupUnits()
    local out = {}
    local n = ns.Call(GetNumGroupMembers) or 0
    local raid = IsInRaid and IsInRaid()
    local me = ns.Safe(ns.Call(UnitName, "player"))
    for i = 1, raid and n or math.max(0, n - 1) do
        local unit = (raid and "raid" or "party") .. i
        local name = ns.Safe(ns.Call(UnitName, unit))
        if name and not ns.SameName(name, me) then tinsert(out, { unit = unit, name = ns.Short(name) or name }) end
    end
    return out
end
PQ.GroupUnits = groupUnits

-- What the game itself knows: C_QuestLog.IsUnitOnQuest tells us if a group member has a
-- quest, addon or not. We ask about every dungeon quest in the database, the ones in your
-- log and the ones other members told us about.
local function candidates()
    local ids = {}
    for id, q in pairs(ns.DB and ns.DB.quests or {}) do if q[10] then ids[id] = true end end
    for id in pairs(ns.Data.quests or {}) do ids[id] = true end
    for _, m in pairs(PQ.members) do for id in pairs(m.quests or {}) do ids[id] = true end end
    return ids
end

function PQ.SeenByGame(unit)
    local fn = C_QuestLog and C_QuestLog.IsUnitOnQuest
    if not fn then return nil end
    local out = {}
    for id in pairs(candidates()) do
        if ns.Safe(ns.Call(fn, unit, id)) == true then
            local mine = ns.Data.quests and ns.Data.quests[id]
            local d = mine and mine.dungeon
            out[id] = { title = (mine and mine.title) or (ns.Quests and ns.Quests.Title(id)) or ("#" .. id),
                dungeon = (d and ((d.forever and d.forever.name) or d.fullName or d.name)) or dungeonOf(id) }
        end
    end
    return out
end

local function prune()
    for name in pairs(PQ.members) do
        if not inGroup(name) then PQ.members[name] = nil end
    end
end


function PQ.Parse(text)
    local list = {}
    for e in (text or ""):gmatch("[^,]+") do
        local id, title, dungeon = e:match("^(%d+):([^:]*):(.*)$")
        id = tonumber(id or e)
        if id then
            list[id] = { title = (title and title ~= "" and title) or (ns.Quests and ns.Quests.Title(id)) or ("#" .. id),
                dungeon = (dungeon and dungeon ~= "" and dungeon) or dungeonOf(id) }
        end
    end
    return list
end

if ns.Comm and ns.Comm.Handle then
    ns.Comm.Handle("Q", function(parts, sender)
        PQ.members[ns.Short(sender) or ns.Display(sender)] = { quests = PQ.Parse(parts[2]), seen = ns.Now() }
        ns.Fire("PARTY_QUESTS_CHANGED")
    end)
    ns.Comm.Handle("QR", function() sendSoon() end)
end

-- The board: { { dungeon, quests = { { id, title, have = { names }, missing = { names }, mine } } } }
function PQ.Board()
    prune()
    local me = ns.Safe(ns.Call(UnitName, "player")) or "?"
    local all = { [me] = PQ.Mine() }
    for name, m in pairs(PQ.members) do all[name] = m.quests end
    -- Add what the game can see for every member (covers anyone whose messages don't arrive).
    for _, g in ipairs(groupUnits()) do
        local seen = PQ.SeenByGame(g.unit)
        if seen and next(seen) then
            local key
            for name in pairs(all) do if ns.SameName(name, g.name) then key = name end end
            key = key or g.name
            all[key] = all[key] or {}
            for id, q in pairs(seen) do if not all[key][id] then all[key][id] = q end end
        end
    end
    local names = {}
    for name in pairs(all) do tinsert(names, name) end
    table.sort(names, function(a, b) if a == me then return true elseif b == me then return false end return a < b end)
    local byDungeon, out = {}, {}
    for _, name in ipairs(names) do
        for id, q in pairs(all[name]) do
            local dn = q.dungeon or dungeonOf(id) or L.PQ_OTHER
            local g = byDungeon[dn]
            if not g then g = { dungeon = dn, quests = {}, byId = {} }; byDungeon[dn] = g; tinsert(out, g) end
            local e = g.byId[id]
            if not e then e = { id = id, title = q.title, have = {} }; g.byId[id] = e; tinsert(g.quests, e) end
            tinsert(e.have, name)
            if name == me then e.mine = true end
        end
    end
    for _, g in ipairs(out) do
        for _, e in ipairs(g.quests) do
            local has = {}
            for _, n in ipairs(e.have) do has[n] = true end
            e.missing = {}
            for _, n in ipairs(names) do if not has[n] then tinsert(e.missing, n) end end
        end
        table.sort(g.quests, function(a, b) return #a.have > #b.have or (#a.have == #b.have and a.title < b.title) end)
        g.byId = nil
    end
    table.sort(out, function(a, b) return a.dungeon < b.dungeon end)
    return out, names
end

-- Share a quest from your log with the group.
function PQ.Share(id)
    if not (C_QuestLog and C_QuestLog.SetSelectedQuest and QuestLogPushQuest) then return false end
    local old = ns.Call(C_QuestLog.GetSelectedQuest)
    pcall(C_QuestLog.SetSelectedQuest, id)
    local ok = pcall(QuestLogPushQuest)
    if old then pcall(C_QuestLog.SetSelectedQuest, old) end
    return ok
end

ns.On("GROUP_ROSTER_UPDATE", function() prune(); sendSoon(); ns.Fire("PARTY_QUESTS_CHANGED") end)
ns.Listen("QUESTS_CHANGED", function() if IsInGroup and IsInGroup() then sendSoon() end end)
