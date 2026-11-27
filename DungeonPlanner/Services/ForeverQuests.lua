-- ForeverQuests.lua
-- Forever quests (curated, by title).
local _, ns = ...
local L = ns.L
local J = ns.Journal
local Q = ns.Quests
local P = ns.Private("Journal")

-- ---------------------------------------------------------------------------
-- Forever quests (curated, by title: the game gives them IDs we only learn from the log)
-- ---------------------------------------------------------------------------

-- Quest ID for a title, from the quest log (remembered, so "done" works later).
function Q.IDForTitle(title)
    ns.db.titleIDs = ns.db.titleIDs or {}
    local n = ns.Call(C_QuestLog and C_QuestLog.GetNumQuestLogEntries) or 0
    for i = 1, n do
        local info = ns.Call(C_QuestLog.GetInfo, i)
        if type(info) == "table" and not ns.Field(info, "isHeader") then
            local t, id = ns.Safe(ns.Field(info, "title")), ns.Safe(ns.Field(info, "questID"))
            if t and id then ns.db.titleIDs[t] = id end
        end
    end
    return ns.db.titleIDs[title]
end

function Q.ForeverMine(fq)
    local side = P.myFaction()
    return fq.side == "B" or side == "AH" or fq.side == side
end

function Q.ForeverStatus(fq)
    local id = ns.db.titleIDs and ns.db.titleIDs[fq.title] or nil
    if id and Q.IsDone(id) then return "done", id end
    id = Q.IDForTitle(fq.title)
    if id and Q.InLog(id) then return "log", id end
    if id and Q.IsDone(id) then return "done", id end
    if fq.lvl and ns.Data.MyLevel() < fq.lvl - 4 then return "level", id end
    return "ready", id
end

-- Open quests (in log or ready to pick up) for my side.
function J.ForeverOpenQuests(f)
    local n = 0
    for _, fq in ipairs(f.quests or {}) do
        if Q.ForeverMine(fq) then
            local st = Q.ForeverStatus(fq)
            if st == "log" or st == "ready" then n = n + 1 end
        end
    end
    return n
end

-- The curated quest by title (same faction rules).
function Q.ForeverByTitle(title)
    for _, f in ipairs(ns.ForeverDB or {}) do
        for _, fq in ipairs(f.quests or {}) do
            if fq.title == title and Q.ForeverMine(fq) then return fq end
        end
    end
end

-- The first quest of a Forever chain ("after" links) you still have to do.
function Q.ForeverFirstOpen(fq)
    local cur, guard = fq, 0
    while cur.after and guard < 10 do
        local prev = Q.ForeverByTitle(cur.after)
        if not prev or Q.ForeverStatus(prev) == "done" or Q.ForeverStatus(cur) == "log" then break end
        cur = prev
        guard = guard + 1
    end
    return cur
end

-- The next quest after this one in its chain (one whose "after" is this title).
function Q.ForeverNext(title)
    for _, f in ipairs(ns.ForeverDB or {}) do
        for _, fq in ipairs(f.quests or {}) do
            if fq.after == title and Q.ForeverMine(fq) and Q.ForeverStatus(fq) ~= "done" then return fq end
        end
    end
end

-- Guide to a Forever quest, starting at the first quest of its chain, and keep following.
function Q.GuideForeverChain(fq)
    local first = Q.ForeverFirstOpen(fq)
    local st, id = Q.ForeverStatus(first)
    local _, complete = Q.Progress(id)
    if first ~= fq then ns.Print(L.NAV_CHAIN:format(first.title, fq.title)) end
    Q.GuideForever(first)
    ns.Nav.follow = { forever = fq.title, last = first.title, inLog = st == "log", complete = st == "log" and complete or false }
    if ns.cdb then ns.cdb.navFollow = ns.Nav.follow end
end

-- Where to go for a curated quest: the log marker once it's accepted, else the giver.
function Q.GuideForever(fq)
    local st, id = Q.ForeverStatus(fq)
    if st == "log" and id then
        return ns.Nav.GuideToQuest(id, fq.title, nil, nil, nil, nil)
    end
    local m = fq.zone and ns.Maps.UiMapByName(fq.zone)
    if m and fq.x then
        return ns.Nav.GuideTo({ map = m, x = fq.x, y = fq.y, label = fq.giver or fq.title })
    end
    if m then
        ns.Print(L.J_FIND_IN_ZONE:format(fq.giver or fq.title, fq.zone))
        return
    end
    ns.Print(L.J_INSIDE_NOTE:format(fq.title, fq.note or fq.giver or ""))
end

function Q.PinForever(fq)
    local m = fq.zone and ns.Maps.UiMapByName(fq.zone)
    if m and fq.x then ns.Maps.WaypointUi(m, fq.x, fq.y, fq.giver or fq.title) end
end

-- Quest colour by level, the way the game colours quests (red, orange, yellow, green, grey).
function P.questColor(level)
    level = tonumber(level)
    if not level then return NORMAL_FONT_COLOR end
    if GetQuestDifficultyColor then
        local ok, c = pcall(GetQuestDifficultyColor, level)
        if ok and type(c) == "table" and c.r then
            return CreateColor and CreateColor(c.r, c.g, c.b) or c
        end
    end
    local diff = level - ns.Data.MyLevel()
    local r, g, b
    if diff >= 5 then r, g, b = 1, 0.1, 0.1
    elseif diff >= 3 then r, g, b = 1, 0.5, 0.25
    elseif diff >= -2 then r, g, b = 1, 1, 0
    elseif -diff <= ((GetQuestGreenRange and GetQuestGreenRange()) or 8) then r, g, b = 0.25, 0.75, 0.25
    else r, g, b = 0.5, 0.5, 0.5 end
    return CreateColor(r, g, b)
end
Q.Color = P.questColor

P.STATUS_ATLAS = { ready = "QuestNormal", log = "QuestTurnin", done = "common-icon-checkmark", level = "QuestNormal", locked = "QuestNormal", inside = "QuestNormal" }
