-- Options: a page in the game's own Settings window (Esc > Options > AddOns).
local _, ns = ...
local L = ns.L

local category

local function checkbox(parent, label, get, set, anchor, y, desc)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, y or -6)
    local text = cb.Text or cb.text
    if not text then
        text = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        text:SetPoint("LEFT", cb, "RIGHT", 2, 1)
    end
    text:SetFontObject("GameFontHighlight")
    text:SetText(label)
    cb:SetScript("OnShow", function(self) self:SetChecked(get()) end)
    cb:SetScript("OnClick", function(self)
        PlaySound(self:GetChecked() and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        set(self:GetChecked())
    end)
    if desc then
        cb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(label, 1, 1, 1)
            GameTooltip:AddLine(desc, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, true)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", GameTooltip_Hide)
    end
    return cb
end

local function editBox(parent, label, get, set, anchor, y)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    fs:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, y or -14)
    fs:SetText(label)
    local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    eb:SetAutoFocus(false)
    eb:SetMaxLetters(255)
    eb:SetSize(560, 22)
    eb:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 6, -4)
    eb:SetScript("OnShow", function(self) self:SetText(get()); self:SetCursorPosition(0) end)
    eb:SetScript("OnEditFocusLost", function(self) set(self:GetText()) end)
    eb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    eb:SetScript("OnEscapePressed", function(self) self:SetText(get()); self:ClearFocus() end)
    return eb, fs
end

-- A section title with a thin gold line under it.
local function section(parent, text, anchor, y, x)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    if anchor then fs:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x or 0, y or -22) else fs:SetPoint("TOPLEFT", 0, 0) end
    fs:SetText(text)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 0.82, 0, 0.25)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -4)
    line:SetPoint("RIGHT", parent, "RIGHT", -10, 0)
    return fs
end

local CONTENT_W = 600

local function build(parent)
    local f = CreateFrame("Frame", nil, parent)
    f.name = L.ADDON_TITLE

    local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(L.ADDON_TITLE .. "  |cff8c8c8cv" .. ns.VERSION .. "|r")
    local bug = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    bug:SetSize(150, 22)
    bug:SetPoint("TOPRIGHT", -16, -14)
    bug:SetText(L.BUG_BUTTON)
    bug:SetScript("OnClick", function() if ns.BugReport then ns.BugReport.Show() end end)
    local share = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    share:SetSize(150, 22)
    share:SetPoint("RIGHT", bug, "LEFT", -8, 0)
    share:SetText(L.QD_BUTTON)
    share:SetScript("OnClick", function() if ns.QuestData then ns.QuestData.Show() end end)
    local sub = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    sub:SetText(L.TAB_TOOLTIP_DESC)

    -- Everything else scrolls, one column, in sections: nothing can overlap.
    local ok, scroll = pcall(CreateFrame, "ScrollFrame", nil, f, "ScrollFrameTemplate")
    if not ok or not scroll then scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate") end
    scroll:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -14)
    scroll:SetPoint("BOTTOMRIGHT", -30, 10)
    local c = CreateFrame("Frame", nil, scroll)
    c:SetSize(CONTENT_W, 900)
    scroll:SetScrollChild(c)
    scroll:SetScript("OnSizeChanged", function(self, w) if w and w > 100 then c:SetWidth(w - 10) end end)

    local o = ns.opt
    local function cb(label, get, set, anchor, desc)
        local b = checkbox(c, label, get, set, anchor, -2, desc)
        local t = b.Text or b.text
        if t then t:SetWidth(CONTENT_W - 40); t:SetJustifyH("LEFT"); t:SetWordWrap(false) end
        return b
    end

    -- General
    local s1 = section(c, L.OPT_SEC_GENERAL)
    local g1 = cb(L.OPT_SHOW_TAB, function() return o.showTab end, function(v) ns.UI.SetTabShown(v) end, s1)
    g1:ClearAllPoints(); g1:SetPoint("TOPLEFT", s1, "BOTTOMLEFT", 0, -10)
    local g2 = cb(L.OPT_TRACKER, function() return o.tracker end, function(v) ns.Tracker.SetEnabled(v) end, g1)
    local g3a = cb(L.OPT_MINIMAP, function() return o.minimapButton end, function(v) ns.Hub.SetMinimapShown(v) end, g2)
    local g3 = cb(L.OPT_CHAT, function() return o.chatMessages ~= false end, function(v) o.chatMessages = v and true or false end, g3a, L.OPT_CHAT_DESC)

    local g4 = cb(L.OPT_QUEST_DATA, function() return ns.QuestData and ns.QuestData.Consent() == true end,
        function(v) if ns.QuestData then ns.QuestData.SetConsent(v) end end, g3, L.OPT_QUEST_DATA_DESC)

    -- Journal and maps
    local s2 = section(c, L.OPT_SEC_JOURNAL, g4)
    local j1 = cb(L.OPT_HIDE_DONE, function() return o.hideDoneQuests end,
        function(v) o.hideDoneQuests = v; if ns.Journal.Refresh then ns.Journal.Refresh() end end, s2)
    j1:ClearAllPoints(); j1:SetPoint("TOPLEFT", s2, "BOTTOMLEFT", 0, -10)
    local j2 = cb(L.OPT_FOREVER_ONLY, function() return o.foreverOnly end,
        function(v) o.foreverOnly = v; if ns.Journal.Refresh then ns.Journal.Refresh() end end, j1)
    local j2b = cb(L.OPT_QUEST_TOOLTIPS, function() return o.questTooltips ~= false end,
        function(v) o.questTooltips = v and true or false end, j2, L.OPT_QUEST_TOOLTIPS_DESC)
    local j2c = cb(L.OPT_PATH_DOTS, function() return o.pathDots ~= false end,
        function(v) o.pathDots = v and true or false; if ns.PathDots then ns.PathDots.Refresh() end end, j2b, L.OPT_PATH_DOTS_DESC)
    local j2d = cb(L.OPT_AVOID_DANGER, function() return o.avoidDanger ~= false end,
        function(v) o.avoidDanger = v and true or false; if ns.Nav and ns.Nav.Replan then ns.Nav.Replan() end end, j2c, L.OPT_AVOID_DANGER_DESC)
    local j2e = cb(L.OPT_ENTRANCE_PINS, function() return o.entrancePins ~= false end,
        function(v) o.entrancePins = v and true or false; if ns.EntrancePins then ns.EntrancePins.Draw(true) end end, j2d, L.OPT_ENTRANCE_PINS_DESC)
    local j3 = cb(L.OPT_ITEM_SOURCES, function() return o.itemSources end, function(v) o.itemSources = v end, j2e, L.OPT_ITEM_SOURCES_DESC)
    local j4 = cb(L.OPT_WISH_ALERTS, function() return o.wishlistAlerts end, function(v) o.wishlistAlerts = v end, j3)
    local scaleLabel = c:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    scaleLabel:SetPoint("TOPLEFT", j4, "BOTTOMLEFT", 6, -10)
    local function showScale() scaleLabel:SetText(L.OPT_SCALE:format(math.floor((o.journalScale or 1) * 100 + 0.5))) end
    showScale()
    local last
    for i, step in ipairs({ -0.05, 0.05 }) do
        local b = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
        b:SetSize(26, 20)
        b:SetText(step < 0 and "-" or "+")
        b:SetPoint("LEFT", last or scaleLabel, "RIGHT", 8, 0)
        b:SetScript("OnClick", function()
            ns.Journal.SetScale((o.journalScale or 1) + step)
            showScale()
        end)
        last = b
    end

    -- Your group
    local s3 = section(c, L.OPT_SEC_GROUP, scaleLabel, -24, -6)
    local p1 = cb(L.OPT_PARTY_SHARE, function() return o.partyShare end, function(v) o.partyShare = v end, s3, L.OPT_PARTY_SHARE_DESC)
    p1:ClearAllPoints(); p1:SetPoint("TOPLEFT", s3, "BOTTOMLEFT", 0, -10)
    local p2 = cb(L.OPT_OPEN_SHARED, function() return o.openSharedMaps end, function(v) o.openSharedMaps = v end, p1)

    -- Group Finder
    local s4 = section(c, L.OPT_SEC_FINDER, p2)
    local f1 = cb(L.OPT_HIDE_AVOIDED, function() return o.hideAvoided end,
        function(v) o.hideAvoided = v; if ns.UI.Refresh then ns.UI.Refresh() end end, s4)
    f1:ClearAllPoints(); f1:SetPoint("TOPLEFT", s4, "BOTTOMLEFT", 0, -10)
    local f2 = cb(L.OPT_NETWORK, function() return o.network end,
        function(v) ns.Comm.SetEnabled(v) end, f1, L.OPT_NETWORK_DESC)
    local f3 = cb(L.OPT_INBOX, function() return o.inbox end, function(v) o.inbox = v end, f2)
    local f4 = cb(L.OPT_INBOX_SOUND, function() return o.inboxSound end, function(v) o.inboxSound = v end, f3)
    local f5 = cb(L.OPT_DECLINE_REPLY, function() return o.declineReply end, function(v) o.declineReply = v end, f4)

    local declineBox = editBox(c, "", function() return o.declineText or L.OPT_DECLINE_TEXT end,
        function(v) o.declineText = (v ~= "" and v ~= L.OPT_DECLINE_TEXT) and v or nil end, f5, -2)
    declineBox:ClearAllPoints()
    declineBox:SetPoint("TOPLEFT", f5, "BOTTOMLEFT", 32, -2)
    declineBox:SetWidth(CONTENT_W - 60)

    -- Messages
    local s5 = section(c, L.OPT_SEC_MESSAGES, declineBox, -24, -32)
    local join, joinLabel = editBox(c, L.OPT_JOIN_TEMPLATE, function() return o.joinTemplate or L.DEFAULT_JOIN end,
        function(v) o.joinTemplate = (v ~= "" and v ~= L.DEFAULT_JOIN) and v or nil end, s5, -14)
    join:SetWidth(CONTENT_W - 30)
    local recruit, recruitLabel = editBox(c, L.OPT_RECRUIT_TEMPLATE, function() return o.recruitTemplate or L.DEFAULT_RECRUIT end,
        function(v) o.recruitTemplate = (v ~= "" and v ~= L.DEFAULT_RECRUIT) and v or nil end, join, -14)
    recruit:SetWidth(CONTENT_W - 30)
    recruitLabel:ClearAllPoints()
    recruitLabel:SetPoint("TOPLEFT", join, "BOTTOMLEFT", -6, -14)
    local tokens = c:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    tokens:SetPoint("TOPLEFT", recruit, "BOTTOMLEFT", -6, -8)
    tokens:SetText(L.OPT_TOKENS)

    local reset = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
    reset:SetSize(160, 22)
    reset:SetText(L.OPT_RESET_TEMPLATES)
    reset:SetPoint("TOPLEFT", tokens, "BOTTOMLEFT", 0, -12)
    reset:SetScript("OnClick", function()
        o.joinTemplate, o.recruitTemplate, o.declineText = nil, nil, nil
        join:SetText(L.DEFAULT_JOIN)
        recruit:SetText(L.DEFAULT_RECRUIT)
        declineBox:SetText(L.OPT_DECLINE_TEXT)
    end)
    -- Tall enough to scroll to the bottom.
    c:SetScript("OnShow", function()
        local top, bottom = c:GetTop(), reset:GetBottom()
        if top and bottom then c:SetHeight(top - bottom + 20) end
    end)
    return f
end

ns.Listen("LOGIN", function()
    local frame = build()
    if Settings and Settings.RegisterCanvasLayoutCategory then
        category = Settings.RegisterCanvasLayoutCategory(frame, L.ADDON_TITLE)
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(frame)
    end
end)

-- The same settings inside the journal's Settings page (a second copy: the game's Settings
-- window owns the first one while it's open). Checkboxes read the saved values when shown.
local inJournal
function ns.OptionsPanelIn(parent)
    if not inJournal then
        inJournal = build(parent)
        inJournal:SetAllPoints(parent)
    end
    return inJournal
end

function ns.OpenOptions()
    if InCombatLockdown() then return end
    -- Opening Blizzard's Settings window from addon code taints the game's window manager
    -- (spells then fail to cast from the spellbook), so /dp options opens our own page.
    if ns.Journal and ns.Journal.ShowPage then ns.Journal.ShowPage("settings") end
end
