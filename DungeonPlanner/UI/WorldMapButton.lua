-- WorldMapButton.lua
-- Inside a dungeon the game's map often shows little. A button on the world map opens
-- Dungeon Planner's map of the dungeon you're in. It is our own frame, only anchored to
-- the world map (nothing of Blizzard's is changed).
local _, ns = ...
local L = ns.L

local button

local function inDungeon()
    local _, instanceType = ns.Call(GetInstanceInfo)
    return instanceType == "party"
end

local function create()
    button = CreateFrame("Button", "DungeonPlannerWorldMapButton", UIParent, "UIPanelButtonTemplate")
    button:SetSize(170, 24)
    button:SetText(L.MAP_OPEN_HERE)
    button:SetFrameStrata("HIGH")
    button:SetScript("OnClick", function()
        -- Never hide the world map from addon code (that taints the game's window manager);
        -- the journal opens in front of it instead.
        ns.Journal.OpenHere(4)
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(L.MAP_OPEN_HERE, 1, 1, 1)
        GameTooltip:AddLine(L.MAP_OPEN_HERE_TIP, 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
    button:Hide()
end

local function update()
    if not (WorldMapFrame and WorldMapFrame:IsShown() and inDungeon()) then
        if button then button:Hide() end
        return
    end
    if not button then create() end
    button:ClearAllPoints()
    button:SetPoint("TOPRIGHT", WorldMapFrame, "TOPRIGHT", -60, -32)
    button:SetFrameLevel((WorldMapFrame:GetFrameLevel() or 1) + 20)
    button:Show()
end

ns.Listen("LOGIN", function()
    if WorldMapFrame and WorldMapFrame.HookScript then
        WorldMapFrame:HookScript("OnShow", update)
        WorldMapFrame:HookScript("OnHide", update)
    end
end)
ns.On("ZONE_CHANGED_NEW_AREA", update)
