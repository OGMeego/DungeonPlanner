-- PathDots: the way the arrow is leading you, drawn as a line of dots on the world map and the
-- minimap (a recorded trail, or the bends of a walking route). Only the step you're on is
-- drawn, from where you are to its end. Our own frames, laid over the map's canvas and the
-- minimap: nothing of Blizzard's is changed or hooked.
-- Setting: ns.opt.pathDots (on by default).
local _, ns = ...
local Nav = ns.Nav
local P = ns.Private("Nav")

local D = {}
ns.PathDots = D

local DOT_TEX = "Interface\\COMMON\\Indicator-Yellow"
local MAP_GAP = 14         -- pixels between dots on the world map (fewer dots when zoomed out)
local MINI_GAP = 14        -- pixels between dots on the minimap
-- Minimap diameter in yards for each zoom level (outdoors / indoors).
local MINI_YARDS = {
    outdoor = { [0] = 466.667, 400, 333.333, 266.667, 200, 133.333 },
    indoor = { [0] = 300, 240, 180, 120, 80, 50 },
}

local function enabled() return not (ns.opt and ns.opt.pathDots == false) end

-- The points still ahead on the step you're on (nil when there's no path to draw).
function D.Remaining()
    local r = P.route
    local s = r and r.steps and r.steps[r.index]
    if not (s and s.path and #s.path > 1) then return nil end
    -- The path keeps only its bends; fill in points along each stretch for the dots.
    local out = {}
    local from = math.max(1, (s.pi or 1) - 1)
    for i = from, #s.path do
        local a, b = s.path[i - 1], s.path[i]
        if i > from and a and a.cont == b.cont then
            local d = P.dist(a, b)
            local n = math.floor(d / 10)
            for k = 1, n - 1 do
                local t = k / n
                tinsert(out, { cont = b.cont, x = a.x + (b.x - a.x) * t, y = a.y + (b.y - a.y) * t })
            end
        end
        tinsert(out, b)
    end
    return out
end

local function pool(parent, list, i, size)
    local t = list[i]
    if not t then
        t = parent:CreateTexture(nil, "OVERLAY")
        t:SetTexture(DOT_TEX)
        list[i] = t
    end
    t:SetSize(size, size)
    t:Show()
    return t
end

local function hideFrom(list, n)
    for i = n, #list do list[i]:Hide() end
end

-- ---------------------------------------------------------------------- world map
local mapFrame, mapDots = nil, {}
local mapCache = { path = nil, mapID = nil, pts = nil }

local function mapPoints(path, mapID)
    if mapCache.path == path and mapCache.mapID == mapID and mapCache.n == #path then return mapCache.pts end
    local pts = {}
    if C_Map.GetMapPosFromWorldPos and CreateVector2D then
        for _, p in ipairs(path) do
            local _, mp = ns.Call(C_Map.GetMapPosFromWorldPos, p.cont, CreateVector2D(p.x, p.y), mapID)
            if mp and mp.GetXY then
                local x, y = mp:GetXY()
                x, y = ns.Safe(x), ns.Safe(y)
                if x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1 then tinsert(pts, { x, y }) end
            end
        end
    end
    mapCache.path, mapCache.mapID, mapCache.n, mapCache.pts = path, mapID, #path, pts
    return pts
end

local function drawMap()
    if not mapFrame then return end
    local path = enabled() and D.Remaining()
    local mapID = WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
    if not (path and mapID) then hideFrom(mapDots, 1) return end
    local w, h = mapFrame:GetSize()
    if not (w and w > 0) then return end
    local scale = (WorldMapFrame.ScrollContainer.GetCanvasScale and WorldMapFrame.ScrollContainer:GetCanvasScale()) or 1
    local size, gap = 9 / scale, MAP_GAP / scale
    local n, lastX, lastY = 0, nil, nil
    for _, q in ipairs(mapPoints(path, mapID)) do
        local px, py = q[1] * w, q[2] * h
        if not lastX or (px - lastX) ^ 2 + (py - lastY) ^ 2 >= gap * gap then
            n = n + 1
            local t = pool(mapFrame, mapDots, n, size)
            t:ClearAllPoints()
            t:SetPoint("CENTER", mapFrame, "TOPLEFT", px, -py)
            lastX, lastY = px, py
        end
    end
    hideFrom(mapDots, n + 1)
end

local function setupMap()
    if mapFrame or not (WorldMapFrame and WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child) then return end
    local child = WorldMapFrame.ScrollContainer.Child
    mapFrame = CreateFrame("Frame", nil, child)
    mapFrame:SetAllPoints(child)
    mapFrame:SetFrameLevel(child:GetFrameLevel() + 200)
    local elapsed = 0
    mapFrame:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed < 0.25 then return end
        elapsed = 0
        drawMap()
    end)
end

-- ---------------------------------------------------------------------- minimap
local miniFrame, miniDots = nil, {}

local function drawMini()
    local path = enabled() and D.Remaining()
    local me = path and Nav.PlayerPos and Nav.PlayerPos()
    if not (path and me and Minimap and Minimap:IsVisible()) then hideFrom(miniDots, 1) return end
    local zoom = Minimap:GetZoom() or 0
    local indoors = IsIndoors and IsIndoors()
    local yards = (indoors and MINI_YARDS.indoor or MINI_YARDS.outdoor)[zoom] or 466.667
    local radius = Minimap:GetWidth() / 2
    local perYard = radius / (yards / 2)
    local rotate = GetCVar and GetCVar("rotateMinimap") == "1"
    local facing = rotate and ns.Safe(ns.Call(GetPlayerFacing)) or 0
    local cf, sf = math.cos(facing), math.sin(facing)
    local n, lastX, lastY = 0, nil, nil
    for _, p in ipairs(path) do
        if p.cont == me.cont then
            -- World x points north, y points west.
            local sx, sy = -(p.y - me.y) * perYard, (p.x - me.x) * perYard
            if rotate then sx, sy = sx * cf + sy * sf, -sx * sf + sy * cf end
            if sx * sx + sy * sy <= (radius - 4) ^ 2
                and (not lastX or (sx - lastX) ^ 2 + (sy - lastY) ^ 2 >= MINI_GAP * MINI_GAP) then
                n = n + 1
                local t = pool(miniFrame, miniDots, n, 7)
                t:ClearAllPoints()
                t:SetPoint("CENTER", miniFrame, "CENTER", sx, sy)
                lastX, lastY = sx, sy
            end
        end
    end
    hideFrom(miniDots, n + 1)
end

local function setupMini()
    if miniFrame or not Minimap then return end
    miniFrame = CreateFrame("Frame", nil, Minimap)
    miniFrame:SetAllPoints(Minimap)
    miniFrame:SetFrameLevel(Minimap:GetFrameLevel() + 5)
    local elapsed = 0
    miniFrame:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed < 0.1 then return end
        elapsed = 0
        drawMini()
    end)
end

function D.Refresh()
    drawMap()
    drawMini()
end

ns.Listen("LOGIN", function()
    setupMap()
    setupMini()
end)
ns.On("ADDON_LOADED", function() setupMap() end)
