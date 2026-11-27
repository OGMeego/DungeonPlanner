-- Panel.lua
-- Building the panel.
local _, ns = ...
local L = ns.L
local UI = ns.UI
local ROW_H = 58
local REFRESH_MACRO = "/click LFGBrowseFrameRefreshButton"
local TAB_ICON = "Interface\\Icons\\INV_Misc_Map_01"
local P = ns.Private("Finder.UI")

-- ---------------------------------------------------------------------------
-- Panel construction
-- ---------------------------------------------------------------------------

local function dungeonDropdown(parent)
    local dd = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    dd:SetWidth(150)
    dd:SetDefaultText(L.ALL_DUNGEONS)
    dd:SetupMenu(function(_, root)
        local function isSel(v) return (ns.cdb.dungeonFilter or 0) == v end
        local function set(v)
            ns.cdb.dungeonFilter = v
            P.selectedKey = nil
            ns.Fire("MY_INFO_CHANGED")
            UI.Refresh()
        end
        root:CreateRadio(L.ALL_DUNGEONS, isSel, set, 0)
        root:CreateDivider()
        local level = ns.Data.MyLevel()
        for _, a in ipairs(ns.Data.dungeonList) do
            local label = a.name
            if a.minLevel > 0 then label = ("%s |cff808080(%d-%d)|r"):format(a.name, a.minLevel, a.maxLevel) end
            -- Out-of-range dungeons stay selectable, shown grey like Blizzard's own list.
            if not ns.Data.LevelFits(a, level) then label = "|cff808080" .. a.name .. "|r" end
            root:CreateRadio(label, isSel, set, a.id)
        end
    end)
    return dd
end

local SORT_NAMES = { match = "SORT_MATCH", newest = "SORT_NEWEST", level = "SORT_LEVEL", name = "SORT_NAME" }

local function filterDropdown(parent)
    local dd = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    dd:SetWidth(165)
    dd:SetSelectionTranslator(function()
        return L.SORT_LABEL:format(L[SORT_NAMES[ns.opt.sort] or "SORT_MATCH"])
    end)
    dd:SetupMenu(function(_, root)
        local function isSort(v) return ns.opt.sort == v end
        local function setSort(v) ns.opt.sort = v; UI.Refresh() end
        for _, key in ipairs({ "match", "newest", "level", "name" }) do
            root:CreateRadio(L[SORT_NAMES[key]], isSort, setSort, key)
        end
        root:CreateDivider()
        root:CreateCheckbox(L.SHOW_GROUPS, function() return ns.opt.showGroups end,
            function() ns.opt.showGroups = not ns.opt.showGroups; UI.Refresh() end)
        root:CreateCheckbox(L.SHOW_PLAYERS, function() return ns.opt.showPlayers end,
            function() ns.opt.showPlayers = not ns.opt.showPlayers; UI.Refresh() end)
        root:CreateDivider()
        root:CreateTitle(L.ROLE_FILTER)
        for _, r in ipairs(P.ROLE_ORDER) do
            root:CreateCheckbox(ns.AtlasMarkup(P.ROLE_MICRO[r], 14) .. " " .. ns.Data.RoleName(r),
                function() return ns.cdb.roleFilter[r] end,
                function() ns.cdb.roleFilter[r] = not ns.cdb.roleFilter[r]; UI.Refresh() end)
        end
    end)
    return dd
end

-- Blizzard's square refresh button look, with a secure overlay that clicks Blizzard's own
-- refresh button (the only way an addon may start a Group Finder search on Forever).
local function refreshButton(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(32, 32)
    b:SetNormalTexture("Interface\\Buttons\\UI-SquareButton-Up")
    b:SetPushedTexture("Interface\\Buttons\\UI-SquareButton-Down")
    b:SetDisabledTexture("Interface\\Buttons\\UI-SquareButton-Disabled")
    b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    b.Icon = b:CreateTexture(nil, "ARTWORK", nil, 5)
    b.Icon:SetTexture("Interface\\Buttons\\UI-RefreshButton")
    b.Icon:SetSize(16, 16)
    b.Icon:SetPoint("CENTER", -1, 0)
    local function showTip(owner)
        if ns.Finder.CanRefresh() then
            P.Tooltip(owner, LFG_LIST_SEARCH_AGAIN or L.REFRESH)
        else
            P.Tooltip(owner, L.REFRESH_FIRST, { { L.REFRESH_FIRST_DESC, 1, 1, 1 } })
        end
    end
    b:SetScript("OnEnter", showTip)
    b:SetScript("OnLeave", GameTooltip_Hide)
    b:SetScript("OnMouseDown", function(self) self.Icon:SetPoint("CENTER", -2, -1) end)
    b:SetScript("OnMouseUp", function(self) self.Icon:SetPoint("CENTER", -1, 0) end)
    -- Without a Blizzard search to repeat, show Blizzard's window so the player can search once.
    b:SetScript("OnClick", function()
        if InCombatLockdown() then ns.Print(L.REFRESH_COMBAT) return end
        UI.HidePanel(true)
        ns.Print(L.REFRESH_FIRST_DESC)
    end)

    local ok, secure = pcall(CreateFrame, "Button", nil, b, "InsecureActionButtonTemplate")
    if ok and secure then
        secure:SetAllPoints(b)
        secure:SetFrameLevel(b:GetFrameLevel() + 5)
        secure:RegisterForClicks("AnyUp")
        secure:SetAttribute("useOnKeyDown", false)
        secure:SetAttribute("type", "macro")
        secure:SetAttribute("macrotext", REFRESH_MACRO)
        secure:SetScript("OnEnter", function() showTip(b) end)
        secure:SetScript("OnLeave", GameTooltip_Hide)
        secure:SetScript("OnMouseDown", function() b.Icon:SetPoint("CENTER", -2, -1) end)
        secure:SetScript("OnMouseUp", function() b.Icon:SetPoint("CENTER", -1, 0) end)
        secure:HookScript("OnClick", function()
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            ns.Finder.searching = true
            ns.Comm.Ask()
            ns.After(0.1, P.updateRefresh)
            if P.panel.spinner then P.panel.spinner:Show() end
        end)
        secure:Hide()
        parent.refreshSecure = secure
    end
    return b
end

local function roleToggle(parent, role)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(22, 22)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    ns.SetAtlas(b.icon, P.ROLE_ATLAS[role])
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b:SetScript("OnClick", function()
        local r = ns.Data.MyRoles()
        if not ns.Data.CanClassDo(ns.Data.MyClass(), role) and not r[role] then return end
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        ns.Data.SetMyRole(role, not r[role])
        UI.Refresh()
    end)
    b:SetScript("OnEnter", function(self)
        local lines = {}
        if not ns.Data.CanClassDo(ns.Data.MyClass(), role) then
            lines[1] = { (YOUR_CLASS_MAY_NOT_PERFORM_ROLE or ""), 1, 0.2, 0.2 }
        end
        P.Tooltip(self, ns.Data.RoleName(role), lines)
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    return b
end

local function questTooltip(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(L.MY_QUESTS_TOOLTIP, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
    if ns.Data.questCount == 0 then
        GameTooltip:AddLine(L.MY_QUESTS_NONE, 0.8, 0.8, 0.8, true)
    else
        local byDungeon, order = {}, {}
        for _, q in pairs(ns.Data.quests) do
            local d = q.dungeon and q.dungeon.name or L.UNKNOWN_DUNGEON
            if not byDungeon[d] then byDungeon[d] = {}; tinsert(order, d) end
            tinsert(byDungeon[d], q)
        end
        table.sort(order)
        for _, d in ipairs(order) do
            GameTooltip:AddLine(d, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
            for _, q in ipairs(byDungeon[d]) do
                local mark = q.complete and (" " .. ns.AtlasMarkup("common-icon-checkmark", 12)) or ""
                GameTooltip:AddLine("  " .. q.title .. mark, 1, 1, 1)
            end
        end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L.MY_QUESTS_HINT, 0.5, 0.5, 0.5, true)
    GameTooltip:Show()
end

function P.createPanel(parent)
    local p = CreateFrame("Frame", "DungeonPlannerFrame", parent, "PortraitFrameTemplate")
    p:SetAllPoints(parent)
    p:SetFrameLevel(parent:GetFrameLevel() + 30)
    p:EnableMouse(true)
    p:Hide()
    if p.SetTitle then p:SetTitle(L.ADDON_TITLE)
    elseif p.TitleContainer then p.TitleContainer.TitleText:SetText(L.ADDON_TITLE) end
    if p.SetPortraitToAsset then pcall(p.SetPortraitToAsset, p, TAB_ICON) end
    -- Closing: the Group Finder's own close button, raised above the planner, so Blizzard's
    -- code closes its window. Hiding it from our code would taint the game's window manager.
    if p.CloseButton then p.CloseButton:Hide() end
    if parent.CloseButton then
        local function raise() parent.CloseButton:SetFrameLevel(p:GetFrameLevel() + 20) end
        raise()
        p:HookScript("OnShow", raise)
    end

    -- Stone header and dark list area, like Browse Groups.
    p.headerBg = p:CreateTexture(nil, "BACKGROUND", nil, -5)
    p.headerBg:SetPoint("TOPLEFT", 2, -21)
    p.headerBg:SetPoint("TOPRIGHT", -2, -21)
    p.headerBg:SetHeight(80)
    ns.SetAtlas(p.headerBg, "groupfinder-Stat-StoneBG")

    p.inset = CreateFrame("Frame", nil, p)
    p.inset:SetPoint("TOPLEFT", 4, -100)
    p.inset:SetPoint("BOTTOMRIGHT", -4, 74)
    p.inset.bg = p.inset:CreateTexture(nil, "BACKGROUND")
    p.inset.bg:SetPoint("TOPLEFT", 3, -3)
    p.inset.bg:SetPoint("BOTTOMRIGHT", -3, 3)
    if not ns.SetAtlas(p.inset.bg, "groupfinder-background") then p.inset.bg:SetColorTexture(0, 0, 0, 0.5) end
    p.inset.border = p.inset:CreateTexture(nil, "BORDER")
    p.inset.border:SetPoint("TOPLEFT", 0, 2)
    p.inset.border:SetPoint("BOTTOMRIGHT", 0, 0)
    ns.SetAtlas(p.inset.border, "common-insideframe")

    -- Header controls
    p.dungeonDD = dungeonDropdown(p)
    p.dungeonDD:SetPoint("TOPLEFT", 66, -36)
    p.filterDD = filterDropdown(p)
    p.filterDD:SetPoint("LEFT", p.dungeonDD, "RIGHT", 8, 0)
    p.refreshBtn = refreshButton(p)
    p.refreshBtn:SetPoint("LEFT", p.filterDD, "RIGHT", 6, 0)

    -- Tabs on top of the list
    local t1 = CreateFrame("Button", nil, p, "PanelTopTabButtonTemplate")
    t1:SetID(1)
    t1:SetText(L.TAB_GROUPS)
    t1:SetPoint("BOTTOMLEFT", p.inset, "TOPLEFT", 8, -2)
    t1:SetScript("OnClick", function() UI.SelectTab(1) end)
    local t2 = CreateFrame("Button", nil, p, "PanelTopTabButtonTemplate")
    t2:SetID(2)
    t2:SetText(L.TAB_APPLICANTS)
    t2:SetScript("OnClick", function() UI.SelectTab(2) end)
    p.Tabs = p.Tabs or { t1, t2 }
    PanelTemplates_SetNumTabs(p, 2)
    PanelTemplates_TabResize(t1, 0)
    PanelTemplates_TabResize(t2, 0)

    -- Strip above the list: my roles and my dungeon quests
    p.iAm = P.Text(p.inset, "GameFontNormalSmall")
    p.iAm:SetPoint("TOPLEFT", 12, -12)
    p.iAm:SetText(L.I_AM)
    p.myRoleButtons = {}
    local prev = p.iAm
    for _, r in ipairs(P.ROLE_ORDER) do
        local b = roleToggle(p.inset, r)
        b:SetPoint("LEFT", prev, "RIGHT", prev == p.iAm and 6 or 2, 0)
        p.myRoleButtons[r] = b
        prev = b
    end

    p.questBtn = CreateFrame("Button", nil, p.inset)
    p.questBtn:SetHeight(20)
    p.questBtn:SetPoint("TOPRIGHT", -12, -9)
    p.questBtn.text = P.Text(p.questBtn, "GameFontNormalSmall")
    p.questBtn.text:SetPoint("RIGHT")
    p.questBtn:SetScript("OnEnter", questTooltip)
    p.questBtn:SetScript("OnLeave", GameTooltip_Hide)

    p.line = p.inset:CreateTexture(nil, "OVERLAY")
    p.line:SetPoint("LEFT", 0, 0)
    p.line:SetPoint("RIGHT", 0, 0)
    p.line:SetPoint("TOP", 0, -36)
    if not ns.SetAtlas(p.line, "groupfinder-ScrollLine", true) then p.line:SetColorTexture(1, 1, 1, 0.1) end
    p.line:SetHeight(4)

    -- The list
    p.scrollBox = CreateFrame("Frame", nil, p.inset, "WowScrollBoxList")
    p.scrollBox:SetPoint("TOPLEFT", 4, -40)
    p.scrollBox:SetPoint("BOTTOMRIGHT", -22, 4)
    p.scrollBar = CreateFrame("EventFrame", nil, p.inset, "MinimalScrollBar")
    p.scrollBar:SetPoint("TOPLEFT", p.scrollBox, "TOPRIGHT", 4, -4)
    p.scrollBar:SetPoint("BOTTOMLEFT", p.scrollBox, "BOTTOMRIGHT", 4, 2)
    local view = CreateScrollBoxListLinearView()
    view:SetElementInitializer("Button", P.initRow)
    view:SetElementExtent(ROW_H)
    ScrollUtil.InitScrollBoxListWithScrollBar(p.scrollBox, p.scrollBar, view)

    p.listBtn = CreateFrame("Button", nil, p.inset, "UIPanelButtonTemplate")
    p.listBtn:SetSize(140, 24)
    p.listBtn:SetText(L.LIST_YOURSELF)
    p.listBtn:SetScript("OnClick", function() UI.OpenListing() end)
    p.listBtn:Hide()

    p.empty = p.inset:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    p.empty:SetPoint("TOP", 0, -80)
    p.empty:SetWidth(300)
    p.empty:SetWordWrap(true)
    p.empty:SetJustifyH("CENTER")

    local okSpin, spinner = pcall(CreateFrame, "Frame", nil, p.inset, "LoadingSpinnerTemplate")
    if okSpin and spinner then
        spinner:SetPoint("CENTER", 0, 10)
        spinner.label = spinner:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        spinner.label:SetPoint("BOTTOM", spinner, "TOP", 0, 0)
        spinner.label:SetText(SEARCHING or L.SEARCHING)
        spinner:Hide()
        p.spinner = spinner
    end

    -- Message box and actions
    p.messageLabel = P.Text(p, "GameFontNormalSmall")
    p.messageLabel:SetPoint("BOTTOMLEFT", 20, 50)
    p.messageLabel:SetText(L.MESSAGE)
    p.message = CreateFrame("EditBox", nil, p, "InputBoxTemplate")
    p.message:SetAutoFocus(false)
    p.message:SetMaxLetters(255)
    p.message:SetHeight(20)
    p.message:SetPoint("LEFT", p.messageLabel, "RIGHT", 10, 0)
    p.message:SetPoint("RIGHT", p, "RIGHT", -20, 0)
    -- Enter only leaves the box. Sending is always an explicit click on Whisper.
    p.message:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    p.message:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    p.whisperBtn = P.Button(p, L.WHISPER, 111, 22, P.whisperSelected)
    p.whisperBtn:SetPoint("BOTTOMLEFT", 16, 14)
    p.inviteBtn = P.Button(p, L.INVITE, 120, 22, function() P.inviteData(P.selectedData()) end)
    p.inviteBtn:SetPoint("BOTTOMRIGHT", -16, 14)
    p.clearBtn = P.Button(p, L.CLEAR_ALL, 90, 22, function() ns.Inbox.Clear() end)
    p.clearBtn:SetPoint("BOTTOM", 0, 14)

    p:SetScript("OnShow", function()
        P.selectedKey = nil
        if ns.Inbox.unread > 0 then P.activeTab = 2 end
        ns.Data.ScanQuests()
        ns.Comm.Ask()
        UI.Refresh()
    end)
    return p
end
