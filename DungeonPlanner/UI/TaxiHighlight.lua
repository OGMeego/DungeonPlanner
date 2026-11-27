-- TaxiHighlight.lua
-- When the arrow's next step is a flight, the flight map marks the flight point to click:
-- a pulsing gold ring on it and a "Fly here" label. Works with the classic flight map
-- (TaxiFrame) and the modern one (FlightMapFrame). Our own frame, laid on top; nothing of
-- Blizzard's is changed.
local _, ns = ...
local L = ns.L
local Nav = ns.Nav
local P = ns.Private("Nav")

local glow

-- The flight point the route wants: the fly step now, or the one right after the walk to
-- the flight master you're standing at.
function Nav.FlightTarget()
    local r = P.route
    if not r then return nil end
    local s = r.steps[r.index]
    if s and s.kind == "fly" then return s.target end
    local nxt = r.steps[r.index + 1]
    if s and s.target and s.target.kind == "flight" and nxt and nxt.kind == "fly" then return nxt.target end
end

local function create()
    glow = CreateFrame("Frame", "DungeonPlannerTaxiGlow", UIParent)
    glow:SetSize(44, 44)
    glow:SetFrameStrata("TOOLTIP")
    glow:EnableMouse(false)
    glow.ring = glow:CreateTexture(nil, "OVERLAY")
    glow.ring:SetAllPoints()
    glow.ring:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    glow.ring:SetBlendMode("ADD")
    glow.ring:SetVertexColor(1, 0.85, 0.1, 1)
    glow.label = glow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    glow.label:SetPoint("BOTTOM", glow, "TOP", 0, -6)
    glow.label:SetTextColor(1, 0.9, 0.2)
    glow.label:SetShadowOffset(1, -1)
    local ag = glow.CreateAnimationGroup and glow:CreateAnimationGroup()
    local a = ag and ag:CreateAnimation("Alpha")
    if a then
        ag:SetLooping("BOUNCE")
        a:SetFromAlpha(1)
        a:SetToAlpha(0.35)
        a:SetDuration(0.6)
        glow.pulse = ag
    end
    glow:Hide()
end

local function same(nodeName, nodeID, target)
    if target.id and nodeID and target.id == nodeID then return true end
    nodeName = ns.Safe(nodeName)
    return nodeName and target.name and ns.Data.Normalize(nodeName) == ns.Data.Normalize(target.name) or false
end

local function show(anchor, size)
    if not glow then create() end
    glow:ClearAllPoints()
    glow:SetPoint("CENTER", anchor, "CENTER", 0, 0)
    glow:SetSize(size, size)
    glow.label:SetText(L.NAV_FLY_HERE)
    glow:Show()
    if glow.pulse then glow.pulse:Play() end
    return true
end

-- Find the button or pin for the target node and put the ring on it.
function Nav.HighlightFlight()
    if glow then glow:Hide() end
    local target = Nav.FlightTarget()
    if not target then return false end
    -- Classic flight map: TaxiButton1..n, one per node.
    if TaxiFrame and TaxiFrame:IsShown() and NumTaxiNodes and TaxiNodeName then
        for i = 1, (ns.Call(NumTaxiNodes) or 0) do
            local b = _G["TaxiButton" .. i]
            if b and b:IsShown() and same(ns.Call(TaxiNodeName, i), nil, target) then return show(b, 44) end
        end
    end
    -- Modern flight map: pins carry taxiNodeData.
    if FlightMapFrame and FlightMapFrame:IsShown() and FlightMapFrame.EnumeratePinsByTemplate then
        local ok, iter = pcall(FlightMapFrame.EnumeratePinsByTemplate, FlightMapFrame, "FlightMap_FlightPointPinTemplate")
        if ok and iter then
            for pin in iter do
                local d = pin.taxiNodeData
                if d and same(d.name, d.nodeID, target) then return show(pin, 52) end
            end
        end
    end
    return false
end

ns.On("TAXIMAP_OPENED", function()
    Nav.HighlightFlight()
    ns.After(0.3, Nav.HighlightFlight)   -- the modern map places its pins a moment later
end)
ns.On("TAXIMAP_CLOSED", function() if glow then glow:Hide() end end)
