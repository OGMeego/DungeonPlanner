-- Journal: our own dungeon journal. Left: dungeons (by your level) and Gear Upgrades.
-- Right: a dungeon's overview (bosses, readiness), its quests (status, giver, map pin,
-- rewards) and its loot (by boss, with upgrade arrows). Built from Blizzard templates.
local _, ns = ...
local P = ns.Private("Journal")
local L = ns.L

local J = {}
ns.Journal = J

P.frame = nil
P.current = { kind = "upgrades" }   -- { kind = "dungeon", map = id }, { kind = "activity", a = a } or a page id
P.pages = {}                         -- pages that aren't a dungeon: see J.RegisterPage
P.tab = 1                           -- 1 overview, 2 quests, 3 loot
P.filterText = ""
P.usableOnly = true

-- Database field positions
local Q_TITLE, Q_LVL, Q_MIN, Q_FACTION, Q_CLASS, Q_PRE, Q_START, Q_END, Q_REWARDS, Q_MAP, Q_OBJ = 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
local B_ENC, B_NPC, B_NAME, B_LVL = 1, 2, 3, 4
local I_NAME, I_QUALITY, I_INV, I_REQ = 1, 2, 3, 4

-- ---------------------------------------------------------------------------
-- Quests
-- ---------------------------------------------------------------------------

local Q = {}
ns.Quests = Q

function P.myFaction()
    local f = UnitFactionGroup("player")
    return f == "Alliance" and "A" or f == "Horde" and "H" or "AH"
end

local function myClassBit()
    local _, _, classID = UnitClass("player")
    return classID and bit.lshift(1, classID - 1) or 0
end

function Q.Info(qid) return ns.DB and ns.DB.quests[qid] end

function Q.Title(qid)
    local t = ns.Call(C_QuestLog and C_QuestLog.GetTitleForQuestID, qid)
    if type(t) == "string" and t ~= "" then return t end
    local q = Q.Info(qid)
    return (q and q[Q_TITLE]) or (ns.Learn and ns.Learn.Title(qid)) or ("#" .. qid)
end

function Q.IsDone(qid) return ns.Call(C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted, qid) and true or false end
function Q.InLog(qid)
    local i = ns.Safe(ns.Call(C_QuestLog and C_QuestLog.GetLogIndexForQuestID, qid))
    return type(i) == "number" and i > 0
end

-- Is this quest for me at all (faction and class)?
function Q.ForMe(qid)
    local q = Q.Info(qid)
    if not q then return true end
    if not q[Q_FACTION]:find(P.myFaction(), 1, true) then return false end
    if q[Q_CLASS] > 0 and bit.band(q[Q_CLASS], myClassBit()) == 0 then return false end
    return true
end

-- "done", "log", "ready" (can pick up now), "level" (too low), "locked" (needs an earlier quest)
-- Your progress on a quest in your log: "6/10 Serpentbloom", and whether it's ready to turn in.
function Q.Progress(qid)
    if not qid then return nil, false end
    local complete = ns.Call(C_QuestLog and C_QuestLog.IsComplete, qid) and true or false
    local objs = ns.Call(C_QuestLog and C_QuestLog.GetQuestObjectives, qid)
    local parts = {}
    for _, o in ipairs(type(objs) == "table" and objs or {}) do
        local text = ns.Safe(ns.Field(o, "text"))
        if text and text ~= "" and not ns.Field(o, "finished") then tinsert(parts, text) end
    end
    return #parts > 0 and table.concat(parts, ", ") or nil, complete
end

-- Quests that start from an item dropped inside the dungeon (The Glowing Shard from
-- Mutanus): you can't pick them up before going in. Returns the item and where it drops.
function Q.StartsInside(qid)
    local q = Q.Info(qid)
    local s = q and q[Q_START]
    if not (s and s[1] == "I" and s[2]) then return nil end
    for _, src in ipairs(ns.ItemSources and ns.ItemSources.For(s[2]) or {}) do
        if src.map and (q[Q_MAP] == 0 or src.map == q[Q_MAP]) then return s[2], src end
    end
end

-- Select a quest you have in your quest log and highlight it (super-track it).
-- We never open the quest log or the world map from addon code: that runs Blizzard's window
-- manager tainted, and afterwards spells can't be cast from the spellbook. The journal's quest
-- rows open the log with a secure click instead (UI/QuestLogOpener.lua); this is the part that
-- needs no window, plus a hint when the log isn't open. Returns true if the quest was selected.
-- "Press L to open your quest log", on screen (not in chat, which can be turned off).
function Q.LogHint(qid)
    local key = GetBindingKey and GetBindingKey("TOGGLEQUESTLOG")
    local title = Q.Title(qid) or ns.Safe(ns.Call(C_QuestLog and C_QuestLog.GetTitleForQuestID, qid)) or ""
    local msg = L.J_PRESS_QUEST_LOG:format(title, key and GetBindingText and GetBindingText(key) or "L")
    if UIErrorsFrame and UIErrorsFrame.AddMessage then UIErrorsFrame:AddMessage(msg, 1, 0.82, 0) else ns.Say(msg) end
end

function Q.OpenInLog(qid)
    if not (qid and Q.InLog(qid)) then return false end
    local O = ns.QuestLogOpener
    if O then O.Select(qid) end
    local shown = (WorldMapFrame and WorldMapFrame:IsShown()) or (QuestLogFrame and QuestLogFrame:IsShown())
    if shown then
        if O and O.ShowDetails then O.ShowDetails(qid) end
    else
        Q.LogHint(qid)
    end
    return true
end

function Q.Status(qid)
    if Q.IsDone(qid) then return "done" end
    if Q.InLog(qid) then return "log" end
    local q = Q.Info(qid)
    if not q then return "ready" end
    if q[Q_PRE] > 0 and not Q.IsDone(q[Q_PRE]) then return "locked" end
    if ns.Data.MyLevel() < q[Q_MIN] then return "level" end
    if Q.StartsInside(qid) then return "inside" end
    return "ready"
end

-- Quests of a dungeon that concern me, plus counts.
function Q.ForDungeon(mapID)
    local d = (ns.DB and ns.DB.dungeons[mapID]) or { quests = {} }
    local list, counts = {}, { done = 0, log = 0, ready = 0, inside = 0, level = 0, locked = 0 }
    local seen = {}
    local function consider(qid)
        if seen[qid] or not Q.ForMe(qid) then return end
        seen[qid] = true
        local st = Q.Status(qid)
        counts[st] = counts[st] + 1
        tinsert(list, { id = qid, status = st })
    end
    for _, qid in ipairs(d.quests) do consider(qid) end
    if ns.Learn then
        for _, qid in ipairs(ns.Learn.QuestsForMap(mapID)) do consider(qid) end
    end
    return list, counts
end

-- The first quest of the chain you still have to do (the quest itself when nothing is missing).
function Q.FirstOpen(qid)
    local target, guard = qid, 0
    while guard < 25 do
        local q = Q.Info(target)
        if not q or q[Q_PRE] == 0 or Q.IsDone(q[Q_PRE]) or Q.InLog(target) then break end
        target = q[Q_PRE]
        guard = guard + 1
    end
    return target
end

-- The whole chain leading to a quest, oldest first.
function Q.Chain(qid)
    local list, seen, cur = {}, {}, qid
    while cur and cur > 0 and not seen[cur] do
        seen[cur] = true
        tinsert(list, 1, cur)
        local q = Q.Info(cur)
        cur = q and q[Q_PRE] or 0
    end
    return list
end

-- Guide to a quest, starting with whatever the chain needs first. The guide then keeps
-- following the chain: pick up -> turn in -> next quest ... until the quest itself is done.
function Q.Guide(qid)
    local target = Q.FirstOpen(qid)
    local _, complete = Q.Progress(target)
    ns.Nav.follow = { final = qid, last = target, inLog = Q.InLog(target), complete = Q.InLog(target) and complete or false }
    local q = Q.Info(target)
    if target ~= qid then ns.Print(L.NAV_CHAIN:format(Q.Title(target), Q.Title(qid))) end
    if q and ns.Data.MyLevel() < q[Q_MIN] and not Q.InLog(target) then
        ns.Print(L.NAV_TOO_LOW:format(Q.Title(target), q[Q_MIN]))
    end
    local s = q and q[Q_START]
    -- Objectives done: head for whoever takes it (the game's "?" first, the database's spot as backup).
    if ns.Nav.follow.complete and q and q[Q_END] and q[Q_END][1] then s = q[Q_END] end
    local giver = s and ((s[1] == "U" and ns.DB.npcs[s[2]]) or (s[1] == "O" and ns.DB.npcs[-s[2]]))
    local lg = not ns.Nav.follow.complete and ns.Learn and ns.Learn.Giver(target) or nil
    local learned = lg and lg.m and lg.x and { m = lg.m, x = lg.x, y = lg.y } or nil
    ns.Nav.GuideToQuest(target, (lg and lg.name) or giver or Q.Title(target), learned, s and s[5], s and s[3], s and s[4])
end
