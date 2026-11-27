-- Attach.lua
-- The side tab, attaching to Blizzard's Group Finder and getting listed first.
local _, ns = ...
local L = ns.L
local UI = ns.UI
local GROUP_FINDER_ADDON = "Blizzard_GroupFinder_VanillaStyle"
local TAB_ICON = "Interface\\Icons\\INV_Misc_Map_01"
local P = ns.Private("Finder.UI")

-- ---------------------------------------------------------------------------
-- Side tab and attaching to Blizzard's Group Finder
-- ---------------------------------------------------------------------------

local blizzardTabs = { "ListingTab", "BrowsingTab", "WhoListingTab" }

local function setBlizzardTabsChecked(checked)
    local parent = _G.LFGParentFrame
    for _, key in ipairs(blizzardTabs) do
        local t = parent and parent[key]
        if t and t.SelectedTexture and not checked then t.SelectedTexture:Hide() end
    end
end

-- Blizzard's Browse window has controls (search box, search button, dropdown arrows) on high
-- frame levels or a higher strata. Lift the planner above everything Blizzard shows in the
-- Group Finder, except its eye portrait, which should stay on top as it does in Blizzard's tabs.
local STRATA = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }
local STRATA_NAME = {}
for name, i in pairs(STRATA) do STRATA_NAME[i] = name end

local function scanBlizzard(frame, skip, best)
    local children = { frame:GetChildren() }
    for _, child in ipairs(children) do
        if child ~= skip and child ~= P.sideTab and child ~= _G.LFGParentFramePortrait and child:IsShown() then
            local s = STRATA[child:GetFrameStrata()] or 0
            local lvl = child:GetFrameLevel() or 0
            if s > best.strata then
                best.strata, best.level = s, lvl
            elseif s == best.strata and lvl > best.level then
                best.level = lvl
            end
            scanBlizzard(child, skip, best)
        end
    end
    return best
end

local function shiftLevels(frame, delta)
    frame:SetFrameLevel(math.min(frame:GetFrameLevel() + delta, 9999))
    for _, child in ipairs({ frame:GetChildren() }) do shiftLevels(child, delta) end
end

local function liftPanel()
    local parent = _G.LFGParentFrame
    if not (P.panel and parent) then return end
    local myStrata = STRATA[P.panel:GetFrameStrata()] or STRATA.MEDIUM
    local best = scanBlizzard(parent, P.panel, { strata = myStrata, level = parent:GetFrameLevel() })
    if best.strata > myStrata then
        P.panel:SetFrameStrata(STRATA_NAME[best.strata]) -- children follow the panel's strata
    end
    local target = best.level + 5
    local delta = target - P.panel:GetFrameLevel()
    if delta > 0 then shiftLevels(P.panel, delta) end
end

function UI.ShowPanel()
    if not P.panel then return end
    P.panel:Show()
    pcall(liftPanel)
    ns.cdb.panelOpen = true
    if P.sideTab then
        P.sideTab:SetChecked(true)
        if P.sideTab.TabGlowAnimation then P.sideTab.TabGlowAnimation:Stop() end
        if P.sideTab.TabGlow then P.sideTab.TabGlow:SetAlpha(0) end
    end
    setBlizzardTabsChecked(false)
end

-- byUser: the player left the planner (not just closed the window), so don't restore it.
function UI.HidePanel(byUser)
    if not P.panel then return end
    P.panel:Hide()
    if byUser then
        ns.cdb.panelOpen = false
        local parent = _G.LFGParentFrame
        -- Restore the highlight on whichever Blizzard tab is showing underneath.
        local shown = { ListingTab = _G.LFGListingFrame, BrowsingTab = _G.LFGBrowseFrame, WhoListingTab = _G.LFGWhoListFrame }
        for key, frame in pairs(shown) do
            local t = parent and parent[key]
            if t and t.SelectedTexture then t.SelectedTexture:SetShown(frame and frame:IsShown() or false) end
        end
    end
    if P.sideTab then P.sideTab:SetChecked(false) end
end

function UI.IsShown() return P.panel and P.panel:IsShown() or false end

local function placeSideTab(parent)
    P.sideTab:ClearAllPoints()
    local anchor = parent.WhoListingTab or parent.BrowsingTab or parent.ListingTab
    if anchor then
        P.sideTab:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    else
        P.sideTab:SetPoint("TOPLEFT", parent, "TOPRIGHT", 0, -240)
    end
end

local function createSideTab(parent)
    local ok, t = pcall(CreateFrame, "Frame", nil, parent, "LargeSideTabButtonTemplate")
    if not ok or not t then return nil end
    t.tooltipText = L.TAB_TOOLTIP
    t.Icon:SetTexture(TAB_ICON)
    t.Icon:SetSize(30, 30)
    t.Icon:SetTexCoord(0.03125, 0.96875, 0.03125, 0.96875)
    if t.SetCustomOnMouseUpHandler then
        t:SetCustomOnMouseUpHandler(function(_, button, upInside)
            if button == "LeftButton" and upInside then UI.ShowPanel() end
        end)
    else
        t:SetScript("OnMouseUp", function(_, button) if button == "LeftButton" then UI.ShowPanel() end end)
    end
    -- Tooltip with a description line, like Blizzard's side tabs.
    t:SetScript("OnEnter", function(self)
        P.Tooltip(self, L.TAB_TOOLTIP, { { L.TAB_TOOLTIP_DESC, 1, 1, 1 } })
    end)
    t:SetScript("OnLeave", GameTooltip_Hide)
    t:SetChecked(false)
    return t
end

function UI.Attach()
    local parent = _G.LFGParentFrame
    if UI.attached or not parent or not ns.cdb then return end
    UI.attached = true

    P.panel = P.createPanel(parent)
    P.sideTab = createSideTab(parent)
    if P.sideTab then
        placeSideTab(parent)
        P.sideTab:SetShown(ns.opt.showTab)
    end

    -- Blizzard's tabs take over again when clicked.
    for _, key in ipairs(blizzardTabs) do
        local t = parent[key]
        if t then
            t:HookScript("OnMouseUp", function(_, button, upInside)
                if button == "LeftButton" and upInside ~= false then UI.HidePanel(true) end
            end)
        end
    end
    parent:HookScript("OnHide", function() UI.HidePanel(false) end)
    parent:HookScript("OnShow", function()
        if ns.cdb.panelOpen and ns.opt.showTab then
            ns.After(0, function() if parent:IsShown() then UI.ShowPanel() end end)
        end
    end)
    if parent:IsShown() and ns.cdb.panelOpen and ns.opt.showTab then UI.ShowPanel() end
    P.activeTab = ns.cdb.lastTab or 1
end

-- ---------------------------------------------------------------------------
-- Getting listed first: show Blizzard's Listing tab, with a tip naming the dungeon.
-- We can't tick the dungeon in Blizzard's form (that would block its List button),
-- so the player picks it; once listed, the planner opens with the results.
-- ---------------------------------------------------------------------------

local callout
local openAfterListing = false

local function showCallout(parent, activity)
    if not callout then
        local ok, f = pcall(CreateFrame, "Frame", nil, parent, "GlowBoxTemplate")
        if not ok or not f then
            f = CreateFrame("Frame", nil, parent)
            f.bg = f:CreateTexture(nil, "BACKGROUND")
            f.bg:SetAllPoints()
            f.bg:SetColorTexture(0, 0, 0, 0.85)
        end
        f:SetSize(230, 70)
        f:SetFrameStrata("HIGH")
        f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLeft")
        f.text:SetPoint("TOPLEFT", 12, -12)
        f.text:SetPoint("BOTTOMRIGHT", -12, 12)
        f.text:SetJustifyV("TOP")
        f.text:SetWordWrap(true)
        f.close = CreateFrame("Button", nil, f, "UIPanelCloseButtonNoScripts")
        f.close:SetSize(20, 20)
        f.close:SetPoint("TOPRIGHT", 4, 4)
        f.close:SetScript("OnClick", function() f:Hide() end)
        callout = f
    end
    callout:SetParent(parent)
    callout:ClearAllPoints()
    callout:SetPoint("TOPLEFT", parent, "TOPRIGHT", 56, -20)
    local name = activity and activity.name
    callout.text:SetText(name and L.LISTING_TIP:format(name) or L.LISTING_TIP_ANY)
    callout:Show()
end

-- Open the Group Finder window from our code (the /dp command, the minimap button) without
-- going through Blizzard's window manager: ShowUIPanel from an addon taints it, and then
-- spells can't be cast from the spellbook. Escape still closes it.
local escAdded
function P.showParent(parent)
    if InCombatLockdown() then return end
    parent:Show()
    local name = parent:GetName()
    if name and not escAdded then
        escAdded = true
        local known
        for _, n in ipairs(UISpecialFrames) do if n == name then known = true end end
        if not known then tinsert(UISpecialFrames, name) end
    end
end

function UI.OpenListing(activity)
    if InCombatLockdown() then ns.Print(L.REFRESH_COMBAT) return end
    if ns.Call(C_LFGList and C_LFGList.HasActiveEntryInfo) then return UI.Open() end
    if not _G.LFGParentFrame then
        local load = (C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
        if load then pcall(load, GROUP_FINDER_ADDON) end
        UI.Attach()
    end
    local parent = _G.LFGParentFrame
    if not parent then return end
    if not parent:IsShown() then P.showParent(parent) end
    UI.HidePanel(true)
    local tab = parent.ListingTab
    if tab and tab.customMouseUpHandler then pcall(tab.customMouseUpHandler, tab, "LeftButton", true) end
    showCallout(parent, activity)
    openAfterListing = true
end

ns.On("LFG_LIST_ACTIVE_ENTRY_UPDATE", function()
    local listed = ns.Call(C_LFGList and C_LFGList.HasActiveEntryInfo)
    if not listed then return end
    if callout then callout:Hide() end
    if openAfterListing and _G.LFGParentFrame and _G.LFGParentFrame:IsShown() then
        openAfterListing = false
        -- Blizzard runs a search for your new listing; show it ranked in the planner.
        ns.After(0.5, function()
            if _G.LFGParentFrame:IsShown() then
                UI.ShowPanel()
                UI.SelectTab(1)
            end
        end)
    end
end)

function UI.SetTabShown(shown)
    ns.opt.showTab = shown and true or false
    if P.sideTab then P.sideTab:SetShown(ns.opt.showTab) end
    if not shown then UI.HidePanel(true) end
end

-- /dp: open the Group Finder on the planner.
function UI.Open()
    if InCombatLockdown() then ns.Print(L.REFRESH_COMBAT) return end
    if not _G.LFGParentFrame then
        local load = (C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
        if load then pcall(load, GROUP_FINDER_ADDON) end
        UI.Attach()
    end
    local parent = _G.LFGParentFrame
    if not parent then return end
    if not parent:IsShown() then P.showParent(parent) end
    UI.ShowPanel()
end
