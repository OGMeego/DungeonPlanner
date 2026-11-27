-- EntrancePins.lua
-- Dungeon entrances on Blizzard's world map: a small pin for every dungeon (classic and
-- Forever's new ones), coloured by how it fits your level. Hover for the name and levels,
-- click to have the arrow take you there.
-- Taint-safe: the pins are our own frames on the map's canvas, placed by reading the map;
-- nothing of Blizzard's is called or changed (no data providers, no hooks on its methods).
local _, ns = ...
local L = ns.L
local E = {}
ns.EntrancePins = E

local PIN_TEX = "Interface\\Minimap\\Dungeon"
local layer, pins = nil, {}
local list -- { name, min, max, cont, x, y, guide = function }

local function enabled() return ns.opt and ns.opt.entrancePins ~= false end

-- Every dungeon's entrance in world yards (built once: positions don't change).
local function build()
    if list then return list end
    list = {}
    for mapID, d in pairs(ns.DB.dungeons or {}) do
        local e = d.entrance
        local m = e and ns.Maps.UiMapForArea(e[3])
        local p = m and ns.Nav.WorldPos and ns.Nav.WorldPos(m, e[1], e[2])
        if p then
            list[#list + 1] = { name = d.name, min = d.min, max = d.max, cont = p.cont, x = p.x, y = p.y,
                guide = function() ns.Nav.GuideToDungeon(mapID) end }
        end
    end
    for _, f in ipairs(ns.ForeverDB or {}) do
        local m = f.zone and f.entrance and ns.Maps.UiMapByName(f.zone)
        local p = m and ns.Nav.WorldPos and ns.Nav.WorldPos(m, f.entrance[1], f.entrance[2])
        if p then
            list[#list + 1] = { name = f.name, min = f.min, max = f.max, cont = p.cont, x = p.x, y = p.y, forever = true,
                guide = function() ns.Nav.GuideToForever(f) end }
        end
    end
    return list
end
E.Build = function() list = nil return build() end

-- Level colour, the way quest levels are coloured.
local function color(d)
    local me = ns.Data.MyLevel()
    if me < (d.min or 0) then return 1, 0.25, 0.25 end
    if me > (d.max or 99) + 2 then return 0.6, 0.6, 0.6 end
    return 1, 0.82, 0
end

local function pin(i)
    local b = pins[i]
    if b then return b end
    b = CreateFrame("Button", nil, layer)
    b:SetSize(18, 18)
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetAllPoints()
    b.tex:SetTexture(PIN_TEX)
    b:SetScript("OnEnter", function(self)
        local d = self.d
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(d.name, color(d))
        if d.min then GameTooltip:AddLine(L.PIN_LEVELS:format(d.min, d.max or d.min), 0.9, 0.9, 0.9) end
        if d.forever then GameTooltip:AddLine(L.J_NEW_IN_FOREVER, 0.4, 0.8, 1) end
        GameTooltip:AddLine(L.PIN_CLICK, 0.4, 1, 0.45)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    b:SetScript("OnClick", function(self) if self.d and self.d.guide then self.d.guide() end end)
    pins[i] = b
    return b
end

local lastMap, lastW, lastScale
function E.Draw(force)
    if not layer then return end
    local mapID = WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
    local w, h = layer:GetSize()
    local scale = (WorldMapFrame.ScrollContainer.GetCanvasScale and WorldMapFrame.ScrollContainer:GetCanvasScale()) or 1
    if not force and mapID == lastMap and w == lastW and scale == lastScale then return end
    lastMap, lastW, lastScale = mapID, w, scale
    local n = 0
    if enabled() and mapID and w and w > 0 and C_Map.GetMapPosFromWorldPos and CreateVector2D then
        -- Not on the dungeon maps themselves (inside an instance the map is the dungeon).
        local info = C_Map.GetMapInfo and ns.Call(C_Map.GetMapInfo, mapID)
        local mt = info and info.mapType
        local isDungeonMap = Enum and Enum.UIMapType and mt == Enum.UIMapType.Dungeon
        if not isDungeonMap then
            local size = 18 / scale
            for _, d in ipairs(build()) do
                local _, mp = ns.Call(C_Map.GetMapPosFromWorldPos, d.cont, CreateVector2D(d.x, d.y), mapID)
                local x, y = mp and mp.GetXY and mp:GetXY()
                x, y = ns.Safe(x), ns.Safe(y)
                if x and y and x > 0 and x < 1 and y > 0 and y < 1 then
                    n = n + 1
                    local b = pin(n)
                    b.d = d
                    b:SetSize(size, size)
                    b.tex:SetVertexColor(color(d))
                    b:ClearAllPoints()
                    b:SetPoint("CENTER", layer, "TOPLEFT", x * w, -y * h)
                    b:Show()
                end
            end
        end
    end
    for i = n + 1, #pins do pins[i]:Hide() end
    return n
end

local function setup()
    if layer or not (WorldMapFrame and WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child) then return end
    local child = WorldMapFrame.ScrollContainer.Child
    layer = CreateFrame("Frame", nil, child)
    layer:SetAllPoints(child)
    layer:SetFrameLevel(child:GetFrameLevel() + 150)
    local elapsed = 0
    layer:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed < 0.2 then return end
        elapsed = 0
        E.Draw()
    end)
end
E.Setup = setup

ns.Listen("LOGIN", setup)
ns.On("ADDON_LOADED", function() setup() end)
ns.On("PLAYER_LEVEL_UP", function() E.Draw(true) end)
