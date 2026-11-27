-- Nav: step-by-step travel guide with an arrow.
-- Plans the fastest way to a place using walking, the flight paths YOU know, boats,
-- zeppelins and your Hearthstone, then leads you there one easy step at a time:
-- "Go to the flight master", "Fly to Thunder Bluff", "Take the zeppelin", ...
-- It also tells you to pick up flight paths you pass on the way.
local _, ns = ...
local P = ns.Private("Nav")
local L = ns.L

local Nav = {}
ns.Nav = Nav

local RUN, MOUNT, FLY = 7, 11, 30          -- yards per second
local FLIGHT_OVERHEAD, RIDE_TIME, HEARTH_TIME = 20, 150, 15
local PICKUP_DETOUR = 250                   -- grab flight paths this close to your route
local HEARTHSTONE = 6948
local ZONE, CONTINENT = 3, 2

-- ---------------------------------------------------------------------------
-- Positions: { cont, x, y } in yards (world space), plus the map point for pins.
-- ---------------------------------------------------------------------------

function P.worldPos(uiMapID, x, y)
    if not (uiMapID and x and y and C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return nil end
    local cont, pos = ns.Call(C_Map.GetWorldPosFromMapPos, uiMapID, CreateVector2D(x / 100, y / 100))
    cont = ns.Safe(cont)
    if not (cont and pos and pos.GetXY) then return nil end
    local wx, wy = pos:GetXY()
    wx, wy = ns.Safe(wx), ns.Safe(wy)
    if not (wx and wy) then return nil end
    return { cont = cont, x = wx, y = wy, map = uiMapID, mx = x, my = y }
end
Nav.WorldPos = P.worldPos

function P.areaPos(areaID, x, y)
    local m = ns.Maps.UiMapForArea(areaID)
    return m and P.worldPos(m, x, y)
end

function Nav.PlayerPos()
    local m = ns.Call(C_Map.GetBestMapForUnit, "player")
    m = ns.Safe(m)
    if not m then return nil end
    local p = ns.Call(C_Map.GetPlayerMapPosition, m, "player")
    if not p then return nil end
    local x, y = ns.Call(p.GetXY, p)
    x, y = ns.Safe(x), ns.Safe(y)
    if not (x and y) or (x == 0 and y == 0) then return nil end
    return P.worldPos(m, x * 100, y * 100)
end

function P.dist(a, b)
    if not (a and b) or a.cont ~= b.cont then return math.huge end
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end
Nav.Distance = P.dist

-- Distance from point p to the segment a-b (same continent).
function P.segDist(p, a, b)
    local vx, vy = b.x - a.x, b.y - a.y
    local len2 = vx * vx + vy * vy
    if len2 == 0 then return P.dist(p, a) end
    local t = math.max(0, math.min(1, ((p.x - a.x) * vx + (p.y - a.y) * vy) / len2))
    local cx, cy = a.x + t * vx, a.y + t * vy
    return math.sqrt((p.x - cx) ^ 2 + (p.y - cy) ^ 2)
end

-- The continent map a map belongs to.
function P.continentOf(uiMapID)
    local id = uiMapID
    for _ = 1, 8 do
        local info = ns.Call(C_Map.GetMapInfo, id)
        if type(info) ~= "table" then return nil end
        if ns.Field(info, "mapType") == CONTINENT then return id end
        id = ns.Field(info, "parentMapID")
        if not id or id == 0 then return nil end
    end
end
