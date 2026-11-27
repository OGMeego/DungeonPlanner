-- Secrets: progress on Forever's solved secrets (Data/Secrets.lua), per character, and
-- guiding you to each step. ns.cdb.secrets[id] = { step = next step, done = true }
local _, ns = ...
local L = ns.L

local S = {}
ns.SecretsSvc = S

-- Translated summary and reward lines (Locales/Notes). Steps stay in English.
do
    local tr = ns.LocaleNotes and ns.LocaleNotes.secrets
    if tr then
        for _, s in ipairs(ns.Secrets or {}) do
            local t = tr[s.id]
            if t then
                s.summary = t.s or s.summary
                s.reward = t.r or s.reward
            end
        end
    end
end

local function store()
    ns.cdb.secrets = ns.cdb.secrets or {}
    return ns.cdb.secrets
end

function S.Get(id)
    for _, s in ipairs(ns.Secrets or {}) do if s.id == id then return s end end
end

-- Can this character do it? (faction and class)
function S.ForMe(s)
    local mine = UnitFactionGroup("player") == "Alliance" and "A" or "H"
    if s.side ~= "B" and s.side ~= mine then return false, "side" end
    if s.class and ns.Data.MyClass() ~= s.class then return false, "class" end
    return true
end

function S.Progress(id)
    local p = store()[id] or {}
    return p.step or 1, p.done or false
end

function S.SetStep(id, step)
    local p = store()[id] or {}
    p.step = step
    store()[id] = p
    ns.Fire("SECRETS_CHANGED")
end

function S.SetDone(id, done)
    local p = store()[id] or {}
    p.done = done and true or nil
    store()[id] = p
    ns.Fire("SECRETS_CHANGED")
end

function S.CountOpen()
    local n = 0
    for _, s in ipairs(ns.Secrets or {}) do
        local _, done = S.Progress(s.id)
        if S.ForMe(s) and not done then n = n + 1 end
    end
    return n
end

-- The secret about a dungeon boss (for the dungeon pages).
function S.ForBoss(bossName)
    for _, s in ipairs(ns.Secrets or {}) do
        if s.boss and bossName and ns.Data.Normalize(s.boss) == ns.Data.Normalize(bossName) then return s end
    end
end

-- The step's text without its faction: "Horde: now the second..." -> "Now the second...",
-- "Horde turn-in: Owen Thadd" -> "Turn in: Owen Thadd".
function S.StripSide(text)
    local rest = text:match("^%a+ turn%-in: *(.*)$")
    if rest and (text:find("^Alliance") or text:find("^Horde")) then return L.J_TURN_IN:format(rest) end
    rest = (text:find("^Alliance") or text:find("^Horde")) and text:match("^%a+: *(.*)$")
    if rest and rest ~= "" then return rest:sub(1, 1):upper() .. rest:sub(2) end
    return text
end

-- "Alliance: ..." / "Horde turn-in: ..." -> "A" / "H"; steps for both -> nil.
function S.StepSide(text)
    if text:find("^Alliance") then return "A" end
    if text:find("^Horde") then return "H" end
end

local function mySide() return UnitFactionGroup("player") == "Alliance" and "A" or "H" end

-- The step you're on: the first one from your progress that's for your faction.
function S.CurrentStep(s)
    local step, done = S.Progress(s.id)
    if done then return nil end
    for i = step, #s.steps do
        local side = S.StepSide(s.steps[i][1])
        if not side or side == mySide() then return i end
    end
end

-- Guide to step i (a spot in a zone). Remembers it as the step you're on.
function S.GuideStep(s, i)
    local st = s.steps[i]
    if not (st and st[2] and st[3]) then return false end
    local m = ns.Maps.UiMapByName and ns.Maps.UiMapByName(st[2])
    if not m then
        ns.Print(L.SECRET_NO_MAP:format(st[2]))
        return false
    end
    S.SetStep(s.id, i)
    ns.cdb.secretGuide = s.id
    local goal = { map = m, x = st[3], y = st[4], label = S.StripSide(st[1]) }
    local ok = true
    -- The way back: if you're on that trail (e.g. still in Westfall), go back the same way.
    local back = st.trailBack and ns.Trails and ns.Trails.All()[st.trailBack]
    local me = back and ns.Nav.PlayerPos and ns.Nav.PlayerPos()
    local onIt = false
    if me then
        for _, p in ipairs(ns.Trails.Points(st.trailBack, me.cont) or {}) do
            if ns.Nav.Distance(me, p) < 500 then onIt = true break end
        end
    end
    if onIt then
        local fwd = st.trail and ns.Trails.All()[st.trail] and st.trail or nil
        ok = ns.Nav.FollowTrail(st.trailBack, nil, goal, true, fwd)
    elseif st.trail and ns.Nav.FollowTrail and ns.Trails and ns.Trails.All()[st.trail] then
        if st.tip then ns.Print(st.tip) end
        ok = ns.Nav.FollowTrail(st.trail, nil, goal)
    else
        ns.Nav.GuideTo(goal)
    end
    -- Tag the trip, so the planner opens on this secret while the arrow is on it.
    if ns.cdb.navGoal then ns.cdb.navGoal.secret = s.id end
    return ok
end

-- ---------------------------------------------------------------------------
-- Moving on by itself. A step is done when, standing at its spot, you loot or click
-- something, get an item, or take or hand in a quest; or anywhere, when you take or hand
-- in the quest the step names in brackets ("... (Stepping Stones)"). Then the step is
-- ticked off, the next step for your faction becomes current, and if you were being guided
-- the arrow goes on to it.
-- ---------------------------------------------------------------------------
local NEAR = 45        -- yards from a step's spot
local quietUntil = 0   -- one click fires several events: count it once

local function spotOf(st)
    local m = st[2] and st[3] and ns.Maps.UiMapByName and ns.Maps.UiMapByName(st[2])
    return m and ns.Nav.WorldPos and ns.Nav.WorldPos(m, st[3], st[4])
end

local function questNames(text)
    local out = {}
    for name in text:gmatch("%(([^%)]+)%)") do out[strlower(name)] = true end
    return out
end

local function advance(s, i)
    quietUntil = GetTime() + 3
    local guided = ns.cdb.secretGuide == s.id
    S.SetStep(s.id, i + 1)
    local nextI = S.CurrentStep(s)
    if not nextI then
        S.SetDone(s.id, true)
        if guided then ns.cdb.secretGuide = nil end
        ns.Print(L.SECRET_AUTO_DONE:format(s.name))
        return
    end
    if nextI ~= i + 1 then S.SetStep(s.id, nextI) end
    local nxt = s.steps[nextI]
    ns.Print(L.SECRET_AUTO_NEXT:format(S.StripSide(s.steps[i][1]), S.StripSide(nxt[1])))
    if guided and nxt[2] and nxt[3] then S.GuideStep(s, nextI) end
end

-- The secrets you're working on: the one you're guided on, and any you've started.
local function active()
    local out = {}
    for _, s in ipairs(ns.Secrets or {}) do
        local step, done = S.Progress(s.id)
        if not done and S.ForMe(s) and (ns.cdb.secretGuide == s.id or step > 1) then tinsert(out, s) end
    end
    return out
end

-- The secret the arrow is guiding you on right now (nil when it's off or on something else).
function S.Guided()
    local g = ns.cdb and ns.cdb.navGoal
    if not (g and g.secret and ns.Nav.IsActive and ns.Nav.IsActive()) then return nil end
    local s = S.Get(g.secret)
    local _, done = s and S.Progress(s.id)
    if s and not done then return s end
end

-- kind: "loot" (looted or got an item), "accept" or "turnin" (a quest). A step that is a quest
-- only counts handing that quest in at its spot (or taking it, for accept steps): any other
-- click nearby, like taking the next quest, doesn't tick it. That also works in other
-- languages, where the quest's title isn't the English one.
function S.CheckSpot(kind)
    if GetTime() < quietUntil then return end
    local me = ns.Nav.PlayerPos and ns.Nav.PlayerPos()
    if not me then return end
    for _, s in ipairs(active()) do
        local i = S.CurrentStep(s)
        local st = i and s.steps[i]
        local counts = st and (not st.quest or kind == (st.accept and "accept" or "turnin"))
        local spot = counts and spotOf(st)
        local near = spot and ns.Nav.Distance(me, spot) <= NEAR
        -- A recorded trail ends where the thing really is: that counts as the spot too.
        if counts and not near and st.trail and ns.Trails then
            local pts = ns.Trails.Points(st.trail, me.cont)
            if pts and ns.Nav.Distance(me, pts[#pts]) <= NEAR then near = true end
        end
        if near then advance(s, i) return end
    end
end

-- A step that is a quest is done when you hand it in (or take it, for accept = true steps);
-- a quest named in brackets in a step's text counts either way.
function S.CheckQuest(title, handedIn)
    if not title or GetTime() < quietUntil then return end
    title = strlower(title)
    local mine = mySide()
    for _, s in ipairs(active()) do
        local cur = S.CurrentStep(s)
        if cur then
            local hit
            for i = cur, #s.steps do
                local st = s.steps[i]
                local side = S.StepSide(st[1])
                local isIt = (st.quest and strlower(st.quest[1]) == title and (handedIn and true or false) == not st.accept)
                    or questNames(st[1])[title]
                if isIt and (not side or side == mine) then hit = i break end
            end
            if hit then advance(s, hit) return end
        end
    end
end

-- Remember the titles of quests in your log: once a quest is handed in, the game may no
-- longer tell us its title from its ID.
local logTitles = {}
local function rememberLog()
    if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo) then return end
    local n = ns.Safe(ns.Call(C_QuestLog.GetNumQuestLogEntries)) or 0
    for i = 1, n do
        local info = ns.Call(C_QuestLog.GetInfo, i)
        local id = type(info) == "table" and ns.Safe(ns.Field(info, "questID"))
        local t = type(info) == "table" and ns.Safe(ns.Field(info, "title"))
        if id and t then logTitles[id] = t end
    end
end
ns.On("QUEST_LOG_UPDATE", ns.Debounce(0.5, rememberLog))

local function questTitle(id)
    if not id then return nil end
    local t = logTitles[id]
    local saved = ns.db and ns.db.questText and ns.db.questText[id]
    t = t or (saved and saved.title)
    if not t and ns.db and ns.db.titleIDs then
        for title, qid in pairs(ns.db.titleIDs) do if qid == id then t = title break end end
    end
    t = t or (ns.Quests and ns.Quests.Title(id))
    if not t and C_QuestLog and C_QuestLog.GetTitleForQuestID then t = ns.Safe(ns.Call(C_QuestLog.GetTitleForQuestID, id)) end
    return t
end

local function onQuest(id, handedIn)
    local title = questTitle(id)
    S.CheckQuest(title, handedIn)
    S.CheckSpot(handedIn and "turnin" or "accept")
end

local function onLoot() ns.After(0.2, function() S.CheckSpot("loot") end) end
ns.On("LOOT_CLOSED", onLoot)
ns.On("ITEM_PUSH", onLoot)
ns.On("QUEST_ACCEPTED", function(a, b) ns.After(0.5, function() onQuest(ns.Safe(b) or ns.Safe(a)) end) end)
ns.On("QUEST_TURNED_IN", function(id) ns.After(0.5, function() onQuest(ns.Safe(id), true) end) end)

-- How to summon a secret dungeon boss (from the Forever data), or nil.
function S.BossText(bossName)
    if not bossName then return nil end
    local key = ns.Data.Normalize(bossName)
    for _, f in ipairs(ns.ForeverDB or {}) do
        for _, b in ipairs(f.bosses or {}) do
            if b.secret and ns.Data.Normalize(b.name) == key then return b.secret end
        end
    end
end
