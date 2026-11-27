-- Refresh.lua
-- Repainting the panel.
local _, ns = ...
local L = ns.L
local UI = ns.UI
local REFRESH_MACRO = "/click LFGBrowseFrameRefreshButton"
local P = ns.Private("Finder.UI")

-- ---------------------------------------------------------------------------
-- Refresh
-- ---------------------------------------------------------------------------

local function updateTabs()
    local n = ns.Inbox.CountUnread()
    P.panel.Tabs[2]:SetText(n > 0 and L.TAB_APPLICANTS_COUNT:format(n) or L.TAB_APPLICANTS)
    PanelTemplates_TabResize(P.panel.Tabs[2], 0)
    PanelTemplates_SetTab(P.panel, P.activeTab)
    if P.sideTab and P.sideTab.TabGlowAnimation then
        if n > 0 and not P.panel:IsShown() then
            P.sideTab.TabGlowAnimation:Play()
        else
            P.sideTab.TabGlowAnimation:Stop()
            if P.sideTab.TabGlow then P.sideTab.TabGlow:SetAlpha(0) end
        end
    end
end

local function updateButtons()
    local d = P.selectedData()
    P.panel.whisperBtn:SetEnabled(d ~= nil)
    P.panel.inviteBtn:SetEnabled(d ~= nil)
    if d and d.kind == "listing" and not d.l.solo then
        P.panel.inviteBtn:SetText(L.REQUEST_INVITE)
    else
        P.panel.inviteBtn:SetText(L.INVITE)
    end
    P.panel.clearBtn:SetShown(P.activeTab == 2 and #ns.Inbox.list > 0)
end

function P.updateRefresh()
    local canRefresh = ns.Finder.CanRefresh()
    local searching = ns.Finder.IsSearching()
    if P.panel.spinner then P.panel.spinner:SetShown(searching and P.activeTab == 1) end
    if not InCombatLockdown() and P.panel.refreshSecure then
        if canRefresh and not searching then
            P.panel.refreshSecure:SetAttribute("macrotext", REFRESH_MACRO)
            P.panel.refreshSecure:Show()
        else
            P.panel.refreshSecure:Hide()
        end
    end
    P.panel.refreshBtn.Icon:SetDesaturated(not canRefresh)
end

local function updateQuests()
    local n = ns.Data.questCount
    P.panel.questBtn.text:SetText(ns.AtlasMarkup("QuestNormal", 14) .. " " .. L.MY_QUESTS:format(n))
    P.panel.questBtn:SetWidth(P.panel.questBtn.text:GetStringWidth() + 6)
end

local function updateMyRoles()
    local r = ns.Data.MyRoles()
    for role, b in pairs(P.panel.myRoleButtons) do
        b.icon:SetDesaturated(not r[role])
        b.icon:SetAlpha(r[role] and 1 or 0.35)
    end
end

function UI.Refresh()
    if not (P.panel and P.panel:IsShown()) then
        if P.panel then updateTabs() end
        return
    end
    P.rowsData = P.activeTab == 1 and P.buildListings() or P.buildApplicants()
    local dp = CreateDataProvider(P.rowsData)
    P.panel.scrollBox:SetDataProvider(dp, ScrollBoxConstants.RetainScrollPosition)

    if P.selectedKey and not P.selectedData() then P.selectedKey = nil end

    local empty = #P.rowsData == 0
    P.panel.empty:SetShown(empty and not (P.activeTab == 1 and ns.Finder.IsSearching()))
    local listed = ns.Call(C_LFGList and C_LFGList.HasActiveEntryInfo)
    P.panel.listBtn:SetShown(empty and not listed and P.panel.empty:IsShown())
    P.panel.listBtn:ClearAllPoints()
    P.panel.listBtn:SetPoint("TOP", P.panel.empty, "BOTTOM", 0, -16)
    if P.activeTab == 1 then
        P.panel.empty:SetText((ns.Finder.updated and #ns.Finder.listings > 0) and L.NO_RESULTS or L.NO_RESULTS_YET)
    else
        P.panel.empty:SetText(L.NO_APPLICANTS)
    end
    updateTabs()
    updateButtons()
    P.updateRefresh()
    updateQuests()
    updateMyRoles()
end

P.refreshSoon = ns.Debounce(0.2, function() UI.Refresh() end)

function UI.Select(key)
    P.selectedKey = key
    P.panel.scrollBox:ForEachFrame(function(row)
        if row.data then row.selected:SetShown(row.data.key == P.selectedKey) end
    end)
    local d = P.selectedData()
    if d and d.kind == "applicant" and d.a.unread then
        d.a.unread = false
        ns.Inbox.CountUnread()
        P.refreshSoon()
    end
    if d and d.kind == "listing" then
        P.panel.message:SetText(P.messageFor(d))
    elseif d then
        P.panel.message:SetText("")
    end
    P.panel.message:SetCursorPosition(0)
    updateButtons()
end

function UI.SelectTab(i)
    P.activeTab = i
    ns.cdb.lastTab = i
    P.selectedKey = nil
    P.panel.message:SetText("")
    PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
    UI.Refresh()
end
