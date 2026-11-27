-- ChainFollow: once you ask to be guided to a quest, the guide keeps going by itself:
-- to the giver, then (accepted) to the objectives, then (objectives done) to the turn-in,
-- then to the next quest of the chain, until the chain is finished. Works for database
-- quests (pre-quest links) and Forever's curated quests ("after" links).
local _, ns = ...
local L = ns.L
local Q = ns.Quests

local CF = {}
ns.ChainFollow = CF

local Q_PRE = 6

-- The next quest for me whose pre-quest is this one (the chain going on past it).
local nextIndex
function Q.NextInChain(qid)
    if not nextIndex then
        nextIndex = {}
        for id, q in pairs(ns.DB and ns.DB.quests or {}) do
            if q[Q_PRE] and q[Q_PRE] > 0 then
                nextIndex[q[Q_PRE]] = nextIndex[q[Q_PRE]] or {}
                tinsert(nextIndex[q[Q_PRE]], id)
            end
        end
    end
    for _, id in ipairs(nextIndex[qid] or {}) do
        if Q.ForMe(id) and not Q.IsDone(id) then return id end
    end
end

local function stop(final)
    ns.Nav.follow = nil
    if ns.cdb then ns.cdb.navFollow = nil end
    ns.Print(L.NAV_CHAIN_DONE:format(final))
end

local function followDB(f)
    if Q.IsDone(f.final) then
        -- The quest is done: carry on with the chain if it goes further.
        local nxt = Q.NextInChain(f.final)
        if nxt then
            ns.Print(L.NAV_CHAIN_NEXT:format(Q.Title(nxt)))
            return Q.Guide(nxt)
        end
        return stop(Q.Title(f.final))
    end
    local cur = Q.FirstOpen(f.final)
    local inLog = Q.InLog(cur)
    local _, complete = Q.Progress(cur)
    complete = inLog and complete or false
    if cur ~= f.last or inLog ~= f.inLog or complete ~= f.complete then
        if complete and not f.complete then ns.Print(L.NAV_CHAIN_TURN_IN:format(Q.Title(cur)))
        elseif cur ~= f.last then ns.Print(L.NAV_CHAIN_NEXT:format(Q.Title(cur))) end
        Q.Guide(f.final)
    end
end

local function followForever(f)
    local final = Q.ForeverByTitle(f.forever)
    if not final then return stop(f.forever) end
    if Q.ForeverStatus(final) == "done" then
        local nxt = Q.ForeverNext(final.title)
        if nxt then
            ns.Print(L.NAV_CHAIN_NEXT:format(nxt.title))
            return Q.GuideForeverChain(nxt)
        end
        return stop(final.title)
    end
    local cur = Q.ForeverFirstOpen(final)
    local st, id = Q.ForeverStatus(cur)
    local inLog = st == "log"
    local _, complete = Q.Progress(id)
    complete = inLog and complete or false
    if cur.title ~= f.last or inLog ~= f.inLog or complete ~= f.complete then
        if complete and not f.complete then ns.Print(L.NAV_CHAIN_TURN_IN:format(cur.title))
        elseif cur.title ~= f.last then ns.Print(L.NAV_CHAIN_NEXT:format(cur.title)) end
        Q.GuideForeverChain(final)
    end
end

function CF.Check()
    local f = ns.Nav.follow
    if not f then return end
    if f.forever then followForever(f) elseif f.final then followDB(f) end
end

local checkSoon = ns.Debounce(1, CF.Check)
ns.On("QUEST_ACCEPTED", function() ns.After(1, CF.Check) end)
ns.On("QUEST_TURNED_IN", function() ns.After(1.5, CF.Check) end)
-- Objectives finished: the quest log changes, and the guide switches to the turn-in.
ns.On("QUEST_LOG_UPDATE", function() if ns.Nav.follow then checkSoon() end end)
