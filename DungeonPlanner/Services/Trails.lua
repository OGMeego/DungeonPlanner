-- Trails: record the way you actually went, then let anyone follow it like a breadcrumb trail.
--   /dp record <name>    start recording your path (walking, swimming, riding)
--   /dp record stop      save it
--   /dp trails           list saved trails
--   /dp trail <name>     follow a trail with the arrow, bend by bend
--   /dp trail delete <name>
-- Flights, boats and zeppelins aren't recorded (too fast to be a path you can walk), and a
-- Hearthstone or a portal starts a new piece. Saved in DungeonPlannerDB.trails, so a trail can
-- be sent in and added to the addon for everyone (Data/Trails.lua).
local _, ns = ...
local L = ns.L

local T = {}
ns.Trails = T

local SAMPLE = 1        -- seconds between position checks
local STEP = 12         -- yards between breadcrumbs
local MAX_SPEED = 16    -- yards a second; faster means a flight, boat or zeppelin
local JUMP = 250        -- yards in one check: a Hearthstone, portal or loading screen

local rec, ticker

local function store()
    DungeonPlannerDB.trails = DungeonPlannerDB.trails or {}
    return DungeonPlannerDB.trails
end

-- Every trail: the ones that ship with the addon, then your own (yours win on a name clash).
function T.All()
    local out = {}
    for name, t in pairs(ns.TRAILS or {}) do out[name] = t end
    for name, t in pairs(store()) do out[name] = t end
    return out
end

local function onTaxi() return UnitOnTaxi and UnitOnTaxi("player") end

local function sample()
    if not rec then return end
    local me = ns.Nav.PlayerPos and ns.Nav.PlayerPos()
    if not me or onTaxi() then rec.last = nil return end
    local last = rec.last
    if last and last.cont == me.cont then
        local d = ns.Nav.Distance(last, me)
        local dt = GetTime() - last.t
        if d > JUMP or (dt > 0 and d / dt > MAX_SPEED) then
            rec.seg = nil      -- teleported or riding a boat: start a new piece when it slows down
            rec.last = { cont = me.cont, x = me.x, y = me.y, t = GetTime() }
            return
        end
        if d < STEP then return end
    end
    if not rec.seg or rec.seg.cont ~= me.cont or not last then
        rec.seg = { cont = me.cont, pts = {} }
        tinsert(rec.segs, rec.seg)
    end
    tinsert(rec.seg.pts, math.floor(me.x + 0.5) .. " " .. math.floor(me.y + 0.5))
    rec.count = rec.count + 1
    rec.last = { cont = me.cont, x = me.x, y = me.y, t = GetTime() }
end

function T.Recording() return rec and rec.name or nil end

function T.Start(name)
    if rec then T.Stop() end
    name = (name and name ~= "") and name or date("%m-%d %H:%M")
    rec = { name = name, segs = {}, count = 0 }
    if not ticker and C_Timer and C_Timer.NewTicker then ticker = C_Timer.NewTicker(SAMPLE, sample) end
    sample()
    ns.Say(L.TRAIL_REC_START:format(name))
end

function T.Stop()
    if not rec then return end
    local r = rec
    rec = nil
    local segs = {}
    for _, s in ipairs(r.segs) do
        if #s.pts >= 2 then tinsert(segs, { cont = s.cont, pts = table.concat(s.pts, " ") .. " " }) end
    end
    if #segs == 0 then ns.Say(L.TRAIL_TOO_SHORT) return end
    store()[r.name] = { segs = segs, made = date("%Y-%m-%d"), by = ns.Data.MyName and ns.Data.MyName() or nil }
    ns.Say(L.TRAIL_REC_STOP:format(r.name, r.count, r.name))
end

function T.List()
    local names = {}
    for name in pairs(T.All()) do tinsert(names, name) end
    table.sort(names)
    if #names == 0 then ns.Say(L.TRAIL_EMPTY) return end
    ns.Say(L.TRAIL_LIST)
    for _, n in ipairs(names) do
        local t, pts = T.All()[n], 0
        for _, s in ipairs(t.segs) do for _ in s.pts:gmatch("(-?%d+) (-?%d+) ") do pts = pts + 1 end end
        ns.Say(("  %s (%d)"):format(n, pts))
    end
end

function T.Delete(name)
    if store()[name] then store()[name] = nil; ns.Say(L.TRAIL_DELETED:format(name))
    else ns.Say(L.TRAIL_NONE:format(name)) end
end

-- The trail's points on a continent, as world positions.
function T.Points(name, cont)
    local t = T.All()[name]
    if not t then return nil end
    local best
    for _, s in ipairs(t.segs) do
        if cont == nil or s.cont == cont then
            local pts = {}
            for x, y in s.pts:gmatch("(-?%d+) (-?%d+) ") do tinsert(pts, { cont = s.cont, x = tonumber(x), y = tonumber(y) }) end
            if not best or #pts > #best then best = pts end
        end
    end
    return best
end

function T.Follow(name)
    if not T.All()[name] then ns.Say(L.TRAIL_NONE:format(name)) return false end
    return ns.Nav.FollowTrail(name)
end

-- /dp record ..., /dp trails, /dp trail ...
function T.Slash(cmd, rest)
    rest = strtrim(rest or "")
    if cmd == "record" then
        if strlower(rest) == "stop" then T.Stop() else T.Start(rest) end
    elseif cmd == "trails" then
        T.List()
    elseif cmd == "trail" then
        local del = rest:match("^[Dd]elete%s+(.+)$")
        if del then T.Delete(del) elseif rest == "" then T.List() else T.Follow(rest) end
    end
end
