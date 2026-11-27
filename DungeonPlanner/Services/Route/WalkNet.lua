-- WalkNet.lua
-- Walking that knows the ground: between two places on the same continent the arrow follows
-- the walking network (Data/WalkNet.lua: roads, passes, bridges, one-way drops, kept clear
-- of enemy towns) instead of a straight line through mountains. Inside one zone a short
-- straight walk is still taken when nothing stands between.
--
-- P.netSearch(cont, from, targets?, backward) -> search result (costs to every node reached)
-- P.netCost(search, point)  -> weighted yards from the search's start to a point (or nil)
-- P.netPath(search, point)  -> corners { {cont,x,y}, ... } ending at the point
local _, ns = ...
local Nav = ns.Nav
local P = ns.Private("Nav")

local NEAR, FAR = 300, 900     -- yards: how far to look for the network from a point
local OFF = 1.5                -- a yard off the network costs this much (the ground there is unknown)
local CELL = 250               -- node buckets
local MAX_COST = 60000         -- stop searching beyond this (weighted yards)
local JOIN = 3                 -- nearest nodes a point joins the network at

local nets = {}

local function load(cont)
    if nets[cont] ~= nil then return nets[cont] or nil end
    local data = ns.WALKNET and ns.WALKNET[cont]
    if not data then nets[cont] = false return nil end
    local X, Y, n = {}, {}, 0
    for _, chunk in ipairs(data.nodes) do
        for x, y in chunk:gmatch("(-?%d+) (-?%d+) ") do
            n = n + 1
            X[n], Y[n] = tonumber(x), tonumber(y)
        end
    end
    local adj = {}            -- adj[a] = { b, cost, flags(for a->b), ... } flat triples
    local function link(a, b, cost, side, ok)
        if not ok then return end
        local t = adj[a]
        if not t then t = {} adj[a] = t end
        t[#t + 1] = b; t[#t + 1] = cost; t[#t + 1] = side
    end
    for _, chunk in ipairs(data.edges) do
        for a, b, _, cost, f in chunk:gmatch("(%d+) (%d+) (%d+) (%d+) (%d+) ") do
            a, b, cost, f = tonumber(a), tonumber(b), tonumber(cost), tonumber(f)
            if X[a] and X[b] then
                local side = f % 4                       -- 1 Alliance, 2 Horde, 3 both
                link(a, b, cost, side, math.floor(f / 4) % 2 == 1)
                link(b, a, cost, side, math.floor(f / 8) % 2 == 1)
            end
        end
    end
    local buckets = {}
    for i = 1, n do
        local k = math.floor(X[i] / CELL) * 4096 + math.floor(Y[i] / CELL)
        local b = buckets[k]
        if not b then b = {} buckets[k] = b end
        b[#b + 1] = i
    end
    local net = { X = X, Y = Y, n = n, adj = adj, buckets = buckets }
    nets[cont] = net
    data.nodes, data.edges = {}, {}   -- the strings aren't needed again
    return net
end
P.netLoad = load
function P.netReset() nets = {} end

local function mySide()
    local f = UnitFactionGroup and UnitFactionGroup("player")
    return f == "Alliance" and 1 or (f == "Horde" and 2 or 3)
end

-- Nodes a faction can walk from (some way on is open to it). Ways kept for the other
-- faction (round its towns) must not be where you join the network: from there you'd be stuck.
local function usable(net, side)
    net.usable = net.usable or {}
    local u = net.usable[side]
    if u then return u end
    u = {}
    for a, t in pairs(net.adj) do
        for k = 1, #t, 3 do
            local s = t[k + 2]
            if s == 3 or side == 3 or s == side then u[a] = true; u[t[k]] = true end
        end
    end
    net.usable[side] = u
    return u
end
P.netUsable = usable

-- The nearest few nodes to a point, within NEAR (then FAR) yards: { node, yards, ... }
-- With a side, only nodes that faction can walk on count.
local function nearest(net, x, y, side)
    local ok = side and usable(net, side)
    for _, reach in ipairs({ NEAR, FAR }) do
        local found = {}
        local r = math.ceil(reach / CELL)
        local cx, cy = math.floor(x / CELL), math.floor(y / CELL)
        for bx = cx - r, cx + r do
            for by = cy - r, cy + r do
                for _, i in ipairs(net.buckets[bx * 4096 + by] or {}) do
                    local dx, dy = net.X[i] - x, net.Y[i] - y
                    local d = math.sqrt(dx * dx + dy * dy)
                    if d <= reach and (not ok or ok[i]) then found[#found + 1] = { i, d } end
                end
            end
        end
        if #found > 0 then
            table.sort(found, function(a, b) return a[2] < b[2] end)
            local out = {}
            for k = 1, math.min(JOIN, #found) do out[#out + 1] = found[k] end
            return out
        end
    end
end

-- A small binary heap of { cost, node }.
local function push(h, c, v)
    local i = #h + 1
    h[i] = { c, v }
    while i > 1 do
        local p = math.floor(i / 2)
        if h[p][1] <= h[i][1] then break end
        h[p], h[i] = h[i], h[p]
        i = p
    end
end
local function pop(h)
    local top = h[1]
    local last = h[#h]
    h[#h] = nil
    if #h > 0 then
        h[1] = last
        local i = 1
        while true do
            local l, r, s = i * 2, i * 2 + 1, i
            if h[l] and h[l][1] < h[s][1] then s = l end
            if h[r] and h[r][1] < h[s][1] then s = r end
            if s == i then break end
            h[s], h[i] = h[i], h[s]
            i = s
        end
    end
    return top
end

-- How much worse a node's ground is for you (zones far above your level).
local function dangerAt(search, i)
    local f = search.danger[i]
    if f then return f end
    f = 1
    local p = { cont = search.cont, x = search.net.X[i], y = search.net.Y[i] }
    if P.onSafeLane and P.onSafeLane(p) or (P.avoidDanger and not P.avoidDanger()) then
        -- a known safe swim, or you've chosen the shortest way: no danger cost
    elseif P.dangerOf and Nav.ZoneAt and search.contMap then
        local z = Nav.ZoneAt({ cont = search.cont, x = search.net.X[i], y = search.net.Y[i] }, search.contMap)
        f = P.dangerOf(z, search.level)
    end
    search.danger[i] = f
    return f
end

-- Search the network from a point. backward = true searches toward the point (costs are
-- "from node to the point"), for one-way drops. targets: points to stop early once reached.
function P.netSearch(cont, from, targets, backward, contMap)
    local net = load(cont)
    if not net or not from or from.cont ~= cont then return nil end
    local side = mySide()
    local joins = nearest(net, from.x, from.y, side)
    if not joins then return nil end
    local search = { side = side, net = net, cont = cont, cost = {}, prev = {}, from = from, backward = backward,
        danger = {}, contMap = contMap, level = ns.Data.MyLevel() }
    local heap = {}
    for _, j in ipairs(joins) do
        local c = j[2] * OFF
        if not search.cost[j[1]] or c < search.cost[j[1]] then
            search.cost[j[1]] = c
            push(heap, c, j[1])
        end
    end
    -- Stop once every target's nearby nodes are settled.
    local need, left = {}, 0
    for _, t in ipairs(targets or {}) do
        for _, j in ipairs(t.cont == cont and nearest(net, t.x, t.y, side) or {}) do
            if not need[j[1]] then need[j[1]] = true; left = left + 1 end
        end
    end
    local done = {}
    -- Going backward we walk edges the other way: build the reverse lists once.
    local adj = net.adj
    if backward then
        if not net.radj then
            local radj = {}
            for a, t in pairs(net.adj) do
                for k = 1, #t, 3 do
                    local b = t[k]
                    local r = radj[b]
                    if not r then r = {} radj[b] = r end
                    r[#r + 1] = a; r[#r + 1] = t[k + 1]; r[#r + 1] = t[k + 2]
                end
            end
            net.radj = radj
        end
        adj = net.radj
    end
    while #heap > 0 do
        local top = pop(heap)
        local c, u = top[1], top[2]
        if not done[u] then
            done[u] = true
            if need[u] then
                need[u] = nil
                left = left - 1
                if left == 0 and targets then break end
            end
            if c > MAX_COST then break end
            local t = adj[u]
            if t then
                for k = 1, #t, 3 do
                    local v, w, s = t[k], t[k + 1], t[k + 2]
                    if not done[v] and (s == 3 or side == 3 or s == side) then
                        local nc = c + w * dangerAt(search, v)
                        local old = search.cost[v]
                        if not old or nc < old then
                            search.cost[v] = nc
                            search.prev[v] = u
                            push(heap, nc, v)
                        end
                    end
                end
            end
        end
    end
    return search
end

-- Weighted yards between the search's point and another point, through the network
-- (and the best joining node, for the path).
function P.netCost(search, p)
    if not (search and p and p.cont == search.cont) then return nil end
    local best, bestNode
    for _, j in ipairs(nearest(search.net, p.x, p.y, search.side) or {}) do
        local c = search.cost[j[1]]
        if c then
            c = c + j[2] * OFF
            if not best or c < best then best, bestNode = c, j[1] end
        end
    end
    return best, bestNode
end

-- Drop corners that barely change the direction (keeps the arrow calm).
local function simplify(pts)
    if #pts <= 2 then return pts end
    local out = { pts[1] }
    for i = 2, #pts - 1 do
        local a, b, c = out[#out], pts[i], pts[i + 1]
        local abx, aby, bcx, bcy = b.x - a.x, b.y - a.y, c.x - b.x, c.y - b.y
        local la, lb = math.sqrt(abx * abx + aby * aby), math.sqrt(bcx * bcx + bcy * bcy)
        local turn = (la > 0 and lb > 0) and ((abx * bcx + aby * bcy) / (la * lb)) or 1
        if la > 8 and (turn < 0.985 or la > 400) then out[#out + 1] = b end
    end
    out[#out + 1] = pts[#pts]
    return out
end

-- The corners of the way between the search's point and p, in walking order.
function P.netPath(search, p)
    local _, node = P.netCost(search, p)
    if not node then return nil end
    local chain = {}
    local u, guard = node, 0
    while u and guard < 20000 do
        chain[#chain + 1] = u
        u = search.prev[u]
        guard = guard + 1
    end
    local X, Y, cont = search.net.X, search.net.Y, search.cont
    local pts = {}
    if search.backward then
        -- chain runs from p's node toward the search point (the goal)
        for i = 1, #chain do pts[#pts + 1] = { cont = cont, x = X[chain[i]], y = Y[chain[i]] } end
        pts[#pts + 1] = search.from
    else
        for i = #chain, 1, -1 do pts[#pts + 1] = { cont = cont, x = X[chain[i]], y = Y[chain[i]] } end
        pts[#pts + 1] = p
    end
    return simplify(pts)
end

-- Is walking straight from a to b fine? (same zone the whole way, short enough)
function P.straightOK(a, b, contMap)
    if not (Nav.ZoneAt and contMap) then return true end
    local d = P.dist(a, b)
    if d < 120 then return true end
    local za = Nav.ZoneAt(a, contMap)
    local n = math.max(2, math.floor(d / 150))
    for i = 1, n do
        local t = i / n
        local z = Nav.ZoneAt({ cont = a.cont, x = a.x + (b.x - a.x) * t, y = a.y + (b.y - a.y) * t }, contMap)
        if (z and z.name) ~= (za and za.name) then return false end
    end
    return d < 1500
end

function Nav.HasWalkNet(cont) return load(cont) ~= nil end
