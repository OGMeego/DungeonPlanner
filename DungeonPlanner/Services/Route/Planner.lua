-- Planner.lua
-- Planning the fastest safe route.
local _, ns = ...
local Nav = ns.Nav
local RUN, MOUNT, FLY = 7, 11, 30          -- yards per second
local FLIGHT_OVERHEAD, RIDE_TIME, HEARTH_TIME = 20, 150, 15
local P = ns.Private("Nav")

-- ---------------------------------------------------------------------------
-- Planning (Dijkstra over: you, the goal, flight masters, docks, Hearthstone)
-- ---------------------------------------------------------------------------

function P.runSpeed()
    return (ns.Data.MyLevel() >= 40) and MOUNT or RUN
end

function Nav.Plan(from, goal)
    local nodes = { from, goal }
    from.kind, goal.kind = "start", "goal"
    local conts = {}
    for _, p in ipairs({ from, goal }) do
        local c = P.continentOf(p.map)
        if c then conts[c] = true end
    end
    -- Docks can take you to another continent: include their continents' flight paths too.
    local docks = P.transportNodes()
    for _, d in ipairs(docks) do
        local c = P.continentOf(d.map)
        if c then conts[c] = true end
    end
    local flights = P.flightNodes(conts)
    for _, n in ipairs(flights) do tinsert(nodes, n) end
    for _, n in ipairs(docks) do tinsert(nodes, n) end
    -- Walkable crossings between zones walled off by mountains (only where there is no
    -- walking network: the network already knows every pass).
    if P.passNodes and not (Nav.HasWalkNet and Nav.HasWalkNet(from.cont)) then
        for _, n in ipairs(P.passNodes(conts)) do tinsert(nodes, n) end
    end
    local hearth = P.hearthNode()
    if hearth then tinsert(nodes, hearth) end
    local speed = P.runSpeed()
    local level = ns.Data.MyLevel()
    P.hostileTowns = P.enemyTowns(conts)
    goal.inTown = P.townAt(goal) ~= nil
    for _, n in ipairs(nodes) do
        n.island = P.onIsland(n)
        n.contMap = P.continentOf(n.map)
    end
    local walkCache = {}
    -- The walking network: one search out from you and one back from the goal give the
    -- real walking cost of every leg that starts with you or ends at the goal.
    local fwd, bwd
    if P.netSearch then
        local same = {}
        for _, n in ipairs(nodes) do if n.cont == from.cont then tinsert(same, n) end end
        fwd = P.netSearch(from.cont, from, same, false, from.contMap)
        local toGoal = {}
        for _, n in ipairs(nodes) do if n.cont == goal.cont then tinsert(toGoal, n) end end
        bwd = P.netSearch(goal.cont, goal, toGoal, true, goal.contMap)
    end
    local function netWalk(u, v)
        local search, other = nil, nil
        if u == from and fwd and v.cont == from.cont then search, other = fwd, v
        elseif v == goal and bwd and u.cont == goal.cont then search, other = bwd, u end
        if not search then return nil end
        if P.straightOK(u, v, u.contMap or v.contMap) then return nil end
        local c = P.netCost(search, other)
        if not c then return nil end
        return c / speed, function() return P.netPath(search, other) end
    end

    local function edges(u)
        local out = {}
        for _, v in ipairs(nodes) do
            if v ~= u and v ~= from then
                local d = P.dist(u, v)
                -- walk (not to the hearth point, not across to an island)
                if d < math.huge and v.kind ~= "hearth" and u.island == v.island then
                    walkCache[u] = walkCache[u] or {}
                    local w = walkCache[u][v]
                    if not w then
                        local nc, pathFn = netWalk(u, v)
                        if nc then
                            w = { nc, nil, pathFn }
                        else
                            local c, zones = P.walkCost(u, v, speed, u.contMap or v.contMap, level)
                            w = { c, zones }
                        end
                        walkCache[u][v] = w
                    end
                    tinsert(out, { v, w[1], "walk", w[2], w[3] })
                end
                -- fly between flight paths you know
                if u.kind == "flight" and v.kind == "flight" and u.known and v.known and d < math.huge then
                    tinsert(out, { v, d / FLY + FLIGHT_OVERHEAD, "fly" })
                end
            end
        end
        if u.kind == "dock" and u.pair then tinsert(out, { u.pair, RIDE_TIME, "ride" }) end
        if u == from and hearth then tinsert(out, { hearth, HEARTH_TIME, "hearth" }) end
        return out
    end

    local cost, prev, how, done, danger, pathOf = {}, {}, {}, {}, {}, {}
    for _, n in ipairs(nodes) do cost[n] = math.huge end
    cost[from] = 0
    while true do
        local u, best = nil, math.huge
        for _, n in ipairs(nodes) do
            if not done[n] and cost[n] < best then u, best = n, cost[n] end
        end
        if not u or u == goal then break end
        done[u] = true
        for _, e in ipairs(edges(u)) do
            local v, c, kind = e[1], e[2], e[3]
            if cost[u] + c < cost[v] then
                cost[v], prev[v], how[v], danger[v], pathOf[v] = cost[u] + c, u, kind, e[4], e[5]
            end
        end
    end
    if cost[goal] == math.huge then return nil end

    local path = {}
    local n = goal
    while n and n ~= from do
        tinsert(path, 1, { from = prev[n], to = n, how = how[n], danger = danger[n], pathFn = pathOf[n] })
        n = prev[n]
    end
    return path, cost[goal], flights
end
