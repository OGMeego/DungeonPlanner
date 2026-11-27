-- Network.lua
-- The travel network: flight masters, boats, Hearthstone.
local _, ns = ...
local Nav = ns.Nav
local HEARTHSTONE = 6948
local P = ns.Private("Nav")

-- ---------------------------------------------------------------------------
-- The travel network
-- ---------------------------------------------------------------------------

local function myFactionLetter()
    local f = UnitFactionGroup("player")
    return f == "Alliance" and "A" or "H"
end

local function myTaxiFaction()
    return UnitFactionGroup("player") == "Alliance" and 2 or 1
end

-- The other faction's flight masters mark their towns: walking near them means guards.
function P.enemyTowns(contMaps)
    local out = {}
    local mine = myTaxiFaction()
    for contMap in pairs(contMaps) do
        local list = ns.Call(C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap, contMap)
        if type(list) == "table" then
            for _, n in ipairs(list) do
                local fac = ns.Field(n, "faction") or 0
                local pos = ns.Field(n, "position")
                if fac ~= 0 and fac ~= mine and pos and pos.GetXY then
                    local px, py = pos:GetXY()
                    local wp = P.worldPos(contMap, px * 100, py * 100)
                    if wp then
                        local name = ns.Field(n, "name") or "?"
                        local city = name:find("Stormwind") or name:find("Ironforge") or name:find("Darnassus")
                            or name:find("Orgrimmar") or name:find("Undercity") or name:find("Thunder Bluff")
                        wp.name, wp.radius = name:match("^([^,]+)") or name, city and 550 or 220
                        tinsert(out, wp)
                    end
                end
            end
        end
    end
    return out
end
Nav.EnemyTowns = P.enemyTowns

-- ---------------------------------------------------------------------------
-- Which flight paths this character really has. The game's map list can't be trusted for
-- that on WoW Forever, so every time you open a flight master's map we note which of its
-- flight points you can fly to (per character, per continent). Once a continent's map has
-- been seen, only those count as known there; before that we go by the game's list.
-- ns.cdb.flights = { [cont] = { [name] = true } }
-- ---------------------------------------------------------------------------
-- Names are compared by the part before the comma, ignoring case and spaces: the taxi
-- window and the world map don't always spell a flight point the same way.
local function flightName(name)
    if not name then return nil end
    name = name:match("^([^,]+)") or name
    return (name:gsub("%s+", " "):match("^%s*(.-)%s*$")):lower()
end
P.flightName = flightName

-- Saved lists from 5.2.39 counted flight points you don't have (DISTANT ones) and kept
-- them: those lists are thrown away and read again the next time a flight map opens.
local function upgradeSeen(seen)
    if seen._v3 then return seen end
    return nil
end

local function isKnown(cont, name, gameSaysUndiscovered)
    local seen = ns.cdb and ns.cdb.flights and ns.cdb.flights[cont]
    if seen and not seen._v3 then seen = upgradeSeen(seen); ns.cdb.flights[cont] = seen end
    if seen then return seen[flightName(name)] == true end
    return not gameSaysUndiscovered
end
P.flightKnown = isKnown

-- Read the flight master's map: CURRENT and REACHABLE are the flight paths you have
-- (DISTANT and NONE are ones you don't). Kept per character, per continent, and added to:
-- a flight master that lists fewer must not make you forget the others.
function P.noteFlights()
    if not (NumTaxiNodes and TaxiNodeName and TaxiNodeGetType) then return end
    local me = Nav.PlayerPos and Nav.PlayerPos()
    local n = ns.Safe(ns.Call(NumTaxiNodes)) or 0
    if not me or n == 0 then return end
    ns.cdb.flights = ns.cdb.flights or {}
    local known, any = { _v3 = true }, false
    for i = 1, n do
        local kind = ns.Safe(ns.Call(TaxiNodeGetType, i))
        local name = flightName(ns.Safe(ns.Call(TaxiNodeName, i)))
        if name and (kind == "CURRENT" or kind == "REACHABLE") then known[name] = true; any = true end
    end
    if not any then return end
    local old = ns.cdb.flights[me.cont]
    old = old and upgradeSeen(old) or {}
    local gained = false
    for name in pairs(known) do if not old[name] then gained = true end end
    for name in pairs(old) do known[name] = true end
    ns.cdb.flights[me.cont] = known
    local r = P.route
    -- Flight paths the trip didn't know about: plan again, it may well fly you closer.
    if gained and r and r.goal then return Nav.Replan() end
    -- The trip flies somewhere you can't fly yet: plan it again with the paths you have.
    if r and r.goal then
        for i = r.index, #r.steps do
            local st = r.steps[i]
            local t = st.kind == "fly" and st.target
            if t and t.cont == me.cont and t.name and not known[flightName(t.name)] then
                return Nav.Replan()
            end
        end
    end
end
ns.On("TAXIMAP_OPENED", function() ns.After(0.2, P.noteFlights) end)


function P.flightNodes(contMaps)
    local out = {}
    local mine = myTaxiFaction()
    for contMap in pairs(contMaps) do
        local list = ns.Call(C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap, contMap)
        if type(list) == "table" then
            for _, n in ipairs(list) do
                local fac = ns.Field(n, "faction") or 0
                local pos = ns.Field(n, "position")
                if (fac == 0 or fac == mine) and pos and pos.GetXY then
                    local px, py = pos:GetXY()
                    local wp = P.worldPos(contMap, px * 100, py * 100)
                    if wp then
                        wp.kind = "flight"
                        wp.name = ns.Field(n, "name") or "?"
                        wp.known = isKnown(wp.cont, wp.name, ns.Field(n, "isUndiscovered"))
                        wp.id = ns.Field(n, "nodeID")
                        tinsert(out, wp)
                    end
                end
            end
        end
    end
    return out
end

function P.transportNodes()
    local out = {}
    local mine = myFactionLetter()
    for i, t in ipairs(ns.DB.transports or {}) do
        if t[2]:find(mine, 1, true) then
            local a = P.areaPos(t[3][3], t[3][1], t[3][2])
            local b = P.areaPos(t[4][3], t[4][1], t[4][2])
            if a and b then
                a.kind, b.kind = "dock", "dock"
                a.label, b.label = t[3][4], t[4][4]
                a.vehicle, b.vehicle = t[1], t[1]
                a.pair, b.pair = b, a
                tinsert(out, a)
                tinsert(out, b)
            end
        end
    end
    return out
end

-- Hearthstone: usable now, and where does it take you?
function P.hearthNode()
    if (ns.Call(C_Item and C_Item.GetItemCount, HEARTHSTONE) or (GetItemCount and ns.Call(GetItemCount, HEARTHSTONE)) or 0) == 0 then return nil end
    local start, duration = ns.Call(C_Container and C_Container.GetItemCooldown, HEARTHSTONE)
    if not start then start, duration = ns.Call(GetItemCooldown, HEARTHSTONE) end
    if start and start > 0 and duration and duration > 2 then return nil end
    local bind = ns.Call(GetBindLocation)
    if not bind then return nil end
    local learned = ns.db.learn and ns.db.learn.hearth and ns.db.learn.hearth[bind]
    local p
    if learned then
        p = P.worldPos(learned.m, learned.x, learned.y)
    else
        for _, inn in ipairs(ns.DB.innkeepers or {}) do
            if ns.Maps.AreaName(inn[5]) == bind then p = P.areaPos(inn[5], inn[3], inn[4]) break end
        end
    end
    if p then p.kind, p.label = "hearth", bind end
    return p
end

-- Remember where the Hearthstone really lands (and where you set it).
local hearthCasting
ns.On("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
    if unit == "player" and spellID == 8690 then hearthCasting = ns.Call(GetBindLocation) end
end)
local function recordHearth()
    local bind = hearthCasting
    hearthCasting = nil
    if not bind then return end
    ns.After(2, function()
        local m = ns.Call(C_Map.GetBestMapForUnit, "player")
        local p = m and ns.Call(C_Map.GetPlayerMapPosition, m, "player")
        if not p then return end
        local x, y = p:GetXY()
        ns.db.learn = ns.db.learn or {}
        ns.db.learn.hearth = ns.db.learn.hearth or {}
        ns.db.learn.hearth[bind] = { m = m, x = x * 100, y = y * 100 }
    end)
end
ns.On("PLAYER_ENTERING_WORLD", recordHearth)
ns.On("ZONE_CHANGED_NEW_AREA", recordHearth)

-- /dp flights: which flight paths the planner thinks you have, and the trip it planned.
function Nav.FlightsReport()
    local me = Nav.PlayerPos and Nav.PlayerPos()
    local say = ns.Say or print
    if not me then say("can't tell where you are right now.") return end
    local seen = ns.cdb and ns.cdb.flights and ns.cdb.flights[me.cont]
    local names = {}
    for k in pairs(seen or {}) do if k ~= "_v3" then names[#names + 1] = k end end
    table.sort(names)
    if #names == 0 then
        say("no flight list saved for this continent yet. Open any flight master's map once.")
    else
        say("flight paths you have here (" .. #names .. "): " .. table.concat(names, ", "))
    end
    local r = P.route
    if r and r.steps then
        for i, st in ipairs(r.steps) do
            local t = st.target
            say(("  %d%s %s %s"):format(i, i == r.index and ">" or ".", st.kind or "?", t and (t.name or t.label) or ""))
        end
    end
end
