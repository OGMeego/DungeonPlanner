-- Hub: one way into everything. Minimap button and the game's addon compartment both open
-- the same menu: Group Finder planner, Dungeon Journal, Gear Upgrades, Tracker, Settings.
local _, ns = ...
local L = ns.L

local Hub = {}
ns.Hub = Hub

local ICON = "Interface\\Icons\\INV_Misc_Map_01"

function Hub.Menu(owner)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then
        if ns.Journal then ns.Journal.Toggle() end
        return
    end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(L.ADDON_TITLE)
        root:CreateButton(L.HUB_PLANNER, function() ns.UI.Open() end)
        root:CreateButton(L.HUB_JOURNAL, function() ns.Journal.OpenSmart() end)
        root:CreateButton(L.HUB_UPGRADES, function() ns.Journal.ShowUpgrades() end)
        root:CreateCheckbox(L.HUB_TRACKER, function() return ns.opt.tracker end,
            function() ns.Tracker.SetEnabled(not ns.opt.tracker) end)
        root:CreateDivider()
        root:CreateButton(SETTINGS or L.HUB_SETTINGS, function() ns.OpenOptions() end)
    end)
end

-- Left click: journal. Right click: menu.
local function onClick(owner, button)
    if button == "RightButton" then Hub.Menu(owner) else ns.Journal.OpenSmart() end
end

-- Addon compartment (the game's addon button by the minimap); named in the TOC.
function DungeonPlanner_OnAddonCompartmentClick(_, button)
    onClick(_G.AddonCompartmentFrame or UIParent, button)
end
function DungeonPlanner_OnAddonCompartmentEnter(_, menuButton)
    GameTooltip:SetOwner(menuButton or UIParent, "ANCHOR_LEFT")
    GameTooltip:SetText(L.ADDON_TITLE .. "  |cff8c8c8cv" .. ns.VERSION .. "|r", 1, 1, 1)
    GameTooltip:AddLine(L.HUB_HINT, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, true)
    GameTooltip:Show()
end
function DungeonPlanner_OnAddonCompartmentLeave() GameTooltip:Hide() end

-- ---------------------------------------------------------------------------
-- Minimap button (classic round tracking-button look, drag to move around the edge)
-- ---------------------------------------------------------------------------

local button

local function place()
    local angle = math.rad(ns.cdb.minimapAngle or 205)
    local r = (Minimap:GetWidth() / 2) + 5
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end

local function createButton()
    local b = CreateFrame("Button", "DungeonPlannerMinimapButton", Minimap)
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(20, 20)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetPoint("TOPLEFT", 7, -5)
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetSize(17, 17)
    icon:SetTexture(ICON)
    icon:SetPoint("TOPLEFT", 7, -6)
    b.icon = icon
    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetPoint("TOPLEFT")
    b:SetScript("OnClick", function(self, btn) onClick(self, btn) end)
    b:SetScript("OnMouseDown", function() icon:SetPoint("TOPLEFT", 8, -7) end)
    b:SetScript("OnMouseUp", function() icon:SetPoint("TOPLEFT", 7, -6) end)
    b:SetScript("OnEnter", function(self) DungeonPlanner_OnAddonCompartmentEnter(nil, self) end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    b:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            ns.cdb.minimapAngle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
            place()
        end)
    end)
    b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    return b
end

function Hub.SetMinimapShown(shown)
    ns.opt.minimapButton = shown and true or false
    if shown and not button then button = createButton() end
    if button then
        button:SetShown(ns.opt.minimapButton)
        if ns.opt.minimapButton then place() end
    end
end

ns.Listen("LOGIN", function()
    if ns.opt.minimapButton then Hub.SetMinimapShown(true) end
end)
