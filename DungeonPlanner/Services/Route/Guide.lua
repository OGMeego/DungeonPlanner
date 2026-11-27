-- Guide.lua
-- Starting, resuming and replacing a guide.
local _, ns = ...
local L = ns.L
local Nav = ns.Nav
local P = ns.Private("Nav")

local ticker
local function startTicker()
    if ticker or not (C_Timer and C_Timer.NewTicker) then return end
    ticker = C_Timer.NewTicker(0.1, function()
        if P.route then Nav.Update(false) end
    end)
end

-- Guide to a map point. goal = { map = uiMapID, x = percent, y = percent, label = "Rahauro" }
-- A new trip replaces the one on the arrow straight away (even if the new one can't be
-- planned yet, the old one must not stay up pointing somewhere else).
local function dropRoute()
    if ns.cdb then ns.cdb.navDungeon = nil end
    P.route = nil
    if P.arrow then P.arrow:Hide() end
    if P.list then P.list:Hide() end
end

-- resuming: picking the route back up after a reload or login (quiet when it can't yet).
function Nav.GuideTo(goal, resuming)
    dropRoute()
    -- Remember the trip, so a reload or relog picks it back up.
    if ns.cdb then
        ns.cdb.navGoal = { map = goal.map, x = goal.x, y = goal.y, label = goal.label, quest = goal.quest, turnIn = goal.turnIn, secret = goal.secret }
        ns.cdb.navFollow = Nav.follow
    end
    local target = P.worldPos(goal.map, goal.x, goal.y)
    if not target then ns.Print(L.NAV_NO_ROUTE:format(goal.label or "")) return end
    target.turnIn = goal.turnIn
    local me = Nav.PlayerPos()
    if not me then
        if not resuming then ns.Print(L.NAV_NO_POSITION) end
        return
    end
    if resuming then ns.Print(L.NAV_RESUMED:format(goal.label or "")) end
    local path, total, flights = Nav.Plan(me, target)
    if not path then ns.Print(L.NAV_NO_ROUTE:format(goal.label or "")) return end
    P.route = { steps = P.buildSteps(path, goal.label or "", flights), index = 1, label = goal.label or "", goal = goal }
    if #P.route.steps == 0 then return Nav.Arrived() end
    if not P.arrow then P.arrow = P.createArrow() end
    P.arrow:Show()
    ns.Print(L.NAV_STARTED:format(goal.label or "", #P.route.steps, P.timeText(total)))
    for i, s in ipairs(P.route.steps) do ns.Print(("  %d. %s"):format(i, s.text)) end
    startTicker()
    Nav.Update(true)
end

-- Guide along a fixed route (a list of waypoints { zone, x, y, r, text, hint }): plan the way
-- to the first one you haven't passed, then walk you through the rest one by one.
function Nav.GuideAlong(waypoints, label, saveAs, resuming)
    dropRoute()
    local me = Nav.PlayerPos()
    if not me then
        if not resuming then ns.Print(L.NAV_NO_POSITION) end
        return
    end
    local pts = {}
    for i, w in ipairs(waypoints) do
        local m = ns.Maps.UiMapByName(w.zone)
        local p = m and P.worldPos(m, w.x, w.y)
        if p then p.wp = w; p.index = i; tinsert(pts, p) end
    end
    if #pts == 0 then return ns.Print(L.NAV_NO_ROUTE:format(label or "")) end
    -- Start at the waypoint you're nearest to (you may be part-way there already).
    local startAt, best = 1, math.huge
    for i, p in ipairs(pts) do
        local d = P.dist(me, p)
        if d < best then startAt, best = i, d end
    end
    -- Already past it? (closer to the next one than that one is to it)
    if pts[startAt + 1] and P.dist(me, pts[startAt + 1]) < P.dist(pts[startAt], pts[startAt + 1]) then startAt = startAt + 1 end
    if ns.cdb then
        ns.cdb.navGoal = { along = saveAs, label = label }
        ns.cdb.navFollow = Nav.follow
    end
    local steps = {}
    local first = pts[startAt]
    local path, total, flights = Nav.Plan(me, first)
    if path then
        for _, st in ipairs(P.buildSteps(path, first.wp.text, flights)) do tinsert(steps, st) end
        if steps[#steps] then steps[#steps].hint = steps[#steps].hint or first.wp.hint end
    end
    for i = startAt + 1, #pts do
        local p = pts[i]
        tinsert(steps, { kind = "walk", target = p, radius = p.wp.r or 50, text = L.NAV_GO_TO:format(p.wp.text), hint = p.wp.hint })
        total = (total or 0) + P.dist(pts[i - 1], p) / P.runSpeed()
    end
    P.route = { steps = steps, index = 1, label = label or "", goal = nil }
    if #steps == 0 then return Nav.Arrived() end
    if not P.arrow then P.arrow = P.createArrow() end
    P.arrow:Show()
    ns.Print((resuming and L.NAV_RESUMED or L.NAV_STARTED):format(label or "", #steps, P.timeText(total or 0)))
    for i, st in ipairs(steps) do ns.Print(("  %d. %s"):format(i, st.text)) end
    startTicker()
    Nav.Update(true)
end

-- Follow a recorded trail (Services/Trails.lua) like breadcrumbs: get to its nearest point
-- first if you're not on it, then the arrow follows it bend by bend to its end.
-- goal (optional): { map, x, y, label } where you're really going; after the trail ends the
-- arrow takes you the last bit there.
-- back = true: walk the trail end to start (the same way back).
-- andThen (optional): a second trail to follow after the first (e.g. swim back to Grom'gol,
-- then the Crossroads path to Stonetalon).
local CONT_MAP = { [0] = 1415, [1] = 1414 }   -- Eastern Kingdoms, Kalimdor
local SIMPLIFY = 18                           -- yards a breadcrumb may stray from the line

-- Fewer breadcrumbs: keep only the bends (a trail of 12-yard steps becomes one point every
-- turn), so the arrow points along the way instead of flicking from crumb to crumb.
local function simplify(pts)
    if #pts < 3 then return pts end
    local keep = { [1] = true, [#pts] = true }
    local function dp(i, j)
        local best, bestD = nil, SIMPLIFY
        for k = i + 1, j - 1 do
            local d = P.segDist(pts[k], pts[i], pts[j])
            if d > bestD then best, bestD = k, d end
        end
        if best then keep[best] = true; dp(i, best); dp(best, j) end
    end
    dp(1, #pts)
    local out = {}
    for i = 1, #pts do if keep[i] then tinsert(out, pts[i]) end end
    return out
end
P.simplifyTrail = simplify

local function trailPoints(name, cont, back)
    local pts = ns.Trails and ((cont and ns.Trails.Points(name, cont)) or ns.Trails.Points(name))
    if not pts or #pts < 2 then return nil end
    if back then
        local r = {}
        for i = #pts, 1, -1 do tinsert(r, pts[i]) end
        pts = r
    end
    return pts
end

local function asStart(p) return { cont = p.cont, x = p.x, y = p.y, map = CONT_MAP[p.cont] } end

-- Steps to get from `from` to `to`: a short walk, or a planned trip when it's far.
local function stepsTo(steps, from, to, label)
    local d = P.dist(from, to)
    if d <= 60 then return 0 end
    if d < 1500 then
        tinsert(steps, { kind = "walk", target = to, radius = 25, text = L.NAV_GO_TO:format(label) })
        return d / P.runSpeed()
    end
    local path, t, flights = Nav.Plan(from.map and from or asStart(from), to)
    if not path then return 0 end
    for _, st in ipairs(P.buildSteps(path, label, flights)) do tinsert(steps, st) end
    return t or 0
end

function Nav.FollowTrail(name, resuming, goal, back, andThen)
    dropRoute()
    local me = Nav.PlayerPos()
    if not me then
        if not resuming then ns.Print(L.NAV_NO_POSITION) end
        return false
    end
    -- The trail's piece on your continent, else its longest piece (you get there first).
    local pts = trailPoints(name, me.cont, back) or trailPoints(name, nil, back)
    if not pts then ns.Print(L.TRAIL_NOT_HERE) return false end
    local startAt, best = 1, math.huge
    for i, p in ipairs(pts) do
        local d = P.dist(me, p)
        if d < best then startAt, best = i, d end
    end
    local goalPos = goal and P.worldPos(goal.map, goal.x, goal.y)
    -- Already past the end of the trail (nearer the goal than the trail's end is): skip it.
    if goalPos and not andThen and P.dist(me, goalPos) < P.dist(pts[#pts], goalPos) and best < 300 then
        return Nav.GuideTo(goal, resuming)
    end
    if startAt >= #pts then startAt = #pts - 1 end
    local steps, total = {}, 0
    if best > 60 then total = total + stepsTo(steps, me, pts[startAt], L.TRAIL_START:format(name)) end
    local function addTrail(trailName, list, from)
        local crumbs = {}
        for i = from, #list do tinsert(crumbs, list[i]) end
        crumbs = simplify(crumbs)
        for i = 2, #crumbs do total = total + P.dist(crumbs[i - 1], crumbs[i]) / P.runSpeed() end
        tinsert(steps, { kind = "walk", trail = true, target = crumbs[#crumbs], radius = 40, path = crumbs, pi = 1,
            text = L.TRAIL_FOLLOW:format(trailName) })
        return crumbs[#crumbs]
    end
    local last = addTrail(name, pts, startAt)
    local second = andThen and trailPoints(andThen)
    if second then
        total = total + stepsTo(steps, last, second[1], L.TRAIL_START:format(andThen))
        last = addTrail(andThen, second, 1)
    end
    local label = goal and goal.label or name
    if goalPos then total = total + stepsTo(steps, last, goalPos, label) end
    if ns.cdb then ns.cdb.navGoal = { trail = name, label = label, goal = goal, back = back, andThen = andThen } end
    P.route = { steps = steps, index = 1, label = label, goal = goal }
    if not P.arrow then P.arrow = P.createArrow() end
    P.arrow:Show()
    ns.Print((resuming and L.NAV_RESUMED or L.NAV_STARTED):format(label, #steps, P.timeText(total)))
    for i, st in ipairs(steps) do ns.Print(("  %d. %s"):format(i, st.text)) end
    startTicker()
    Nav.Update(true)
    return true
end

function Nav.Replan()
    if P.route and P.route.goal then
        local secret = ns.cdb and ns.cdb.navGoal and ns.cdb.navGoal.secret
        Nav.GuideTo(P.route.goal)
        if secret and ns.cdb.navGoal then ns.cdb.navGoal.secret = secret end
    end
end

-- Guide to a quest (its giver, or the game's marker when it's in your log).
function Nav.GuideToQuest(questID, label, learned, areaID, x, y, resuming)
    if not resuming then dropRoute() end
    ns.Maps.ResolveQuest(questID, learned, areaID, x, y, function(m, qx, qy, approx, label2)
        if not m then
            -- After a reload the quest marker may not be ready yet: use the spot we saved.
            local saved = ns.cdb and ns.cdb.navGoal
            if resuming and saved and saved.map then return Nav.GuideTo(saved, true) end
            return ns.Print(L.WAYPOINT_NONE:format(label or ""))
        end
        if approx and not resuming then ns.Print(L.NAV_APPROX) end
        -- Objectives done: the step reads "Turn in to ..." instead of "Go to ...".
        local _, complete = ns.Quests.Progress(questID)
        local turnIn = ns.Quests.InLog(questID) and complete or nil
        local title = ns.Quests.Title(questID)
        if turnIn then
            -- Who takes it, when we know; otherwise the quest's name.
            local name = (label and label ~= title) and label or title
            turnIn = name == title and "quest" or "npc"
            label2 = name
        end
        Nav.GuideTo({ map = m, x = qx, y = qy, label = label2 or label, quest = questID, turnIn = turnIn }, resuming)
    end)
end

-- Guide to the entrance of one of Forever's new dungeons (curated zone + x/y).
function Nav.GuideToForever(f, resuming)
    if not resuming then Nav.follow = nil; if ns.cdb then ns.cdb.navFollow = nil end end
    local mine = UnitFactionGroup("player") == "Alliance" and "A" or "H"
    -- A checked route for your faction (e.g. Horde to Hall of Thanes): warn first, then follow it.
    if f and f.routes and f.routes[mine] then
        if not resuming and not Nav.EnemyCheck(f, f.name, f.side, f.zone, f.counterpart) then return end
        Nav.GuideAlong(f.routes[mine], L.NAV_ENTRANCE:format(f.name), f.name, resuming)
        if ns.cdb then ns.cdb.navDungeon = { forever = f.name } end
        return
    end
    if f and not resuming and not Nav.EnemyCheck(f, f.name, f.side, f.zone, f.counterpart) then return end
    local m = f and f.zone and ns.Maps.UiMapByName(f.zone)
    if not m then return ns.Print(L.NAV_NO_ROUTE:format(f and f.name or "")) end
    Nav.GuideTo({ map = m, x = f.entrance[1], y = f.entrance[2], label = L.NAV_ENTRANCE:format(f.name) })
    if f.note then ns.Print(f.note) end
    if ns.cdb and f then ns.cdb.navDungeon = { forever = f.name } end
end

-- Guide to a dungeon's entrance.
-- Classic dungeons inside a capital city.
local CITY_DUNGEONS = {
    [389] = { side = "H", zone = "Orgrimmar", counterpart = "Hall of Thanes" },      -- Ragefire Chasm
    [34] = { side = "A", zone = "Stormwind City", counterpart = "Blackfathom Deeps" }, -- The Stockade
}
Nav.CITY_DUNGEONS = CITY_DUNGEONS

-- A dungeon in the other faction's city: warn first, guide on a second click within 20 seconds.
local confirmEnemy
local function enemyCheck(key, name, side, zone, counterpart)
    local mine = UnitFactionGroup("player") == "Alliance" and "A" or "H"
    if not side or side == mine then return true end
    local now = GetTime and GetTime() or 0
    if confirmEnemy and confirmEnemy.k == key and now - confirmEnemy.t < 20 then
        confirmEnemy = nil
        return true
    end
    confirmEnemy = { k = key, t = now }
    local theirs = side == "A" and (FACTION_ALLIANCE or "Alliance") or (FACTION_HORDE or "Horde")
    local yours = mine == "A" and (FACTION_ALLIANCE or "Alliance") or (FACTION_HORDE or "Horde")
    ns.Print(L.NAV_ENEMY_DUNGEON:format(name, theirs, zone, yours, counterpart or "?"))
    return false
end
Nav.EnemyCheck = enemyCheck

function Nav.GuideToDungeon(mapID)
    Nav.follow = nil
    if ns.cdb then ns.cdb.navFollow = nil end
    local d = ns.DB.dungeons[mapID]
    local cd = CITY_DUNGEONS[mapID]
    if d and cd and not enemyCheck(mapID, d.name, cd.side, cd.zone, cd.counterpart) then return end
    local e = d and d.entrance
    if not e then return ns.Print(L.NAV_NO_ENTRANCE) end
    local m = ns.Maps.UiMapForArea(e[3])
    if not m then return ns.Print(L.NAV_NO_ROUTE:format(d.name)) end
    Nav.GuideTo({ map = m, x = e[1], y = e[2], label = L.NAV_ENTRANCE:format(d.name) })
    if ns.cdb then ns.cdb.navDungeon = { map = mapID } end
end

-- After a reload, login or loading screen: carry on with the trip you were on.
local function resume()
    if not ns.cdb then return end
    if ns.cdb.navFollow and not Nav.follow then Nav.follow = ns.cdb.navFollow end
    if P.route or not ns.cdb.navGoal then return end
    local g = ns.cdb.navGoal
    if g.trail then
        local secret = g.secret
        local ok = Nav.FollowTrail(g.trail, true, g.goal, g.back, g.andThen)
        if ns.cdb.navGoal then ns.cdb.navGoal.secret = secret end
        return ok
    end
    if g.along then
        local f = ns.ForeverFor and ns.ForeverFor(g.along)
        if f then return Nav.GuideToForever(f, true) end
        ns.cdb.navGoal = nil
        return
    end
    if g.quest then
        local done = ns.Call(C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted, g.quest)
        if done and not (Nav.follow and Nav.follow.final ~= g.quest) then
            ns.cdb.navGoal = nil
            return
        end
        -- Ask the game again: the quest marker moves to the turn-in once objectives are done.
        return Nav.GuideToQuest(g.quest, g.label, nil, nil, nil, nil, true)
    end
    Nav.GuideTo(g, true)
end
Nav.Resume = resume
-- Tests: lose the route the way a /reload does (saved trip kept).
function Nav._ForgetForTest() P.route = nil if P.arrow then P.arrow:Hide() end end
ns.On("PLAYER_ENTERING_WORLD", function() ns.After(2, resume) end)
ns.On("ZONE_CHANGED_NEW_AREA", function() ns.After(2, resume) end)

-- The dungeon the arrow is working toward: the followed quest's dungeon, or the entrance
-- you asked for. { map = mapID } or { forever = name }, plus quest = true for quests.
function Nav.GuidedDungeon()
    local f = Nav.follow
    if f and f.final then
        local q = ns.Quests.Info(f.final)
        local map = q and q[10]
        if map and map > 0 and ns.DB.dungeons[map] then return { map = map, quest = true } end
        for mapID, d in pairs(ns.DB.dungeons) do
            for _, qid in ipairs(d.quests or {}) do
                if qid == f.final then return { map = mapID, quest = true } end
            end
        end
        local learned = ns.db and ns.db.learn and ns.db.learn.qmap and ns.db.learn.qmap[f.final]
        if learned and ns.DB.dungeons[learned] then return { map = learned, quest = true } end
    elseif f and f.forever then
        for _, d in ipairs(ns.ForeverDB or {}) do
            for _, fq in ipairs(d.quests or {}) do
                if fq.title == f.forever then return { forever = d.name, quest = true } end
            end
        end
    end
    if Nav.IsActive() and ns.cdb and ns.cdb.navDungeon then return ns.cdb.navDungeon end
end
