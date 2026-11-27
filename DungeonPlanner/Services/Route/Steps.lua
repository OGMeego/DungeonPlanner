-- Steps.lua
-- Turning a plan into steps a person can follow.
local _, ns = ...
local L = ns.L
local Nav = ns.Nav
local PICKUP_DETOUR = 250                   -- grab flight paths this close to your route
local P = ns.Private("Nav")

-- ---------------------------------------------------------------------------
-- Turning a plan into steps a person can follow
-- ---------------------------------------------------------------------------

local function placeName(p)
    local info = p.map and ns.Call(C_Map.GetMapInfo, p.map)
    return type(info) == "table" and ns.Field(info, "name") or ""
end

local function walkText(to, goalLabel)
    if to.kind == "flight" then return L.NAV_TO_FLIGHT:format(to.name) end
    if to.kind == "pass" then return L.NAV_TO_PASS:format(to.name) end
    if to.kind == "dock" then return L.NAV_TO_DOCK:format(to.label) end
    if to.kind == "goal" then
        local f = (to.turnIn == "npc" and L.NAV_TURN_IN_TO) or (to.turnIn == "quest" and L.NAV_TURN_IN_QUEST) or L.NAV_TO_GOAL
        return f:format(goalLabel)
    end
    return L.NAV_TO_PLACE:format(placeName(to))
end

-- "Orgrimmar zeppelin tower (Undercity side)" -> "Orgrimmar"
local function shortPlace(label)
    if not label then return "" end
    for _, cut in ipairs({ " zeppelin", " dock", ",", " pier" }) do
        local i = label:find(cut, 1, true)
        if i then return label:sub(1, i - 1) end
    end
    return label
end

function P.buildSteps(path, goalLabel, flights)
    local steps = {}
    local level = ns.Data.MyLevel()
    local pendingDanger
    local function addDanger(zones)
        for name, z in pairs(zones or {}) do
            pendingDanger = pendingDanger or {}
            pendingDanger[name] = z
        end
    end
    local function dangerText()
        if not pendingDanger then return nil end
        local parts = {}
        local enemy = {}
        for name, z in pairs(pendingDanger) do
            if z.enemy then tinsert(enemy, name)
            else tinsert(parts, z.max and ("%s (%d-%d)"):format(name, z.min, z.max) or name) end
        end
        table.sort(enemy)
        if #enemy > 0 then
            local e = L.NAV_ENEMY_TOWN:format(table.concat(enemy, ", "))
            pendingDanger = nil
            if #parts == 0 then return e end
            table.sort(parts)
            return L.NAV_DANGER:format(table.concat(parts, ", ")) .. " " .. e
        end
        table.sort(parts)
        pendingDanger = nil
        return L.NAV_DANGER:format(table.concat(parts, ", "))
    end
    for i, leg in ipairs(path) do
        local to, from = leg.to, leg.from
        local nextLeg = path[i + 1]
        if leg.how == "walk" then addDanger(leg.danger) end
        -- Walking through a point on the way: only worth a step if it's a flight path to learn.
        if leg.how == "walk" and nextLeg and nextLeg.how == "walk" then
            if to.kind == "pass" then
                local warn = dangerText()
                tinsert(steps, { kind = "walk", target = to, radius = 60,
                    text = L.NAV_TO_PASS:format(to.name) .. (warn and ("  " .. warn) or ""), danger = warn, hint = L.NAV_PASS_HINT })
            elseif to.kind == "flight" and not to.known then
                tinsert(steps, { kind = "pickup", target = to, radius = 25,
                    text = L.NAV_PICKUP:format(to.name), hint = L.NAV_PICKUP_HINT })
            end
            -- otherwise merged into the next walking step
        elseif leg.how == "walk" then
            -- Flight paths you don't have yet, close to this stretch: pick them up on the way.
            local pickup, best
            for _, f in ipairs(flights) do
                local fz = Nav.ZoneAt(f, f.contMap or P.continentOf(f.map))
                if not f.known and f.cont == from.cont and P.dangerOf(fz, level) == 1 then
                    local off = P.segDist(f, from, to)
                    if off < PICKUP_DETOUR and P.dist(f, to) > 60 and P.dist(f, from) > 60 and (not best or off < best) then
                        pickup, best = f, off
                    end
                end
            end
            if pickup then
                tinsert(steps, { kind = "pickup", target = pickup, radius = 25,
                    text = L.NAV_PICKUP:format(pickup.name), hint = L.NAV_PICKUP_HINT })
            end
            local warn = dangerText()
            local corners = leg.pathFn and leg.pathFn() or nil
            tinsert(steps, { kind = "walk", target = to, path = corners, pi = 1, radius = to.kind == "goal" and 12 or 25,
                text = walkText(to, goalLabel) .. (warn and ("  " .. warn) or ""), danger = warn,
                hint = to.kind == "flight" and L.NAV_FLIGHT_HINT or to.kind == "dock" and L.NAV_DOCK_HINT:format(to.vehicle == "zeppelin" and L.NAV_ZEPPELIN or L.NAV_BOAT) or nil })
        elseif leg.how == "fly" then
            tinsert(steps, { kind = "fly", target = to, radius = 90, text = L.NAV_FLY:format(to.name),
                hint = L.NAV_FLY_HINT:format(to.name) })
        elseif leg.how == "ride" then
            local vehicle = from.vehicle == "zeppelin" and L.NAV_ZEPPELIN or L.NAV_BOAT
            tinsert(steps, { kind = "ride", target = to, radius = 150, text = L.NAV_RIDE:format(vehicle, shortPlace(to.label)),
                hint = L.NAV_RIDE_HINT })
        elseif leg.how == "hearth" then
            tinsert(steps, { kind = "hearth", target = to, radius = 300, text = L.NAV_HEARTH:format(to.label),
                hint = L.NAV_HEARTH_HINT })
        end
    end
    return steps
end
