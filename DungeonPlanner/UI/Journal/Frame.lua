-- Frame.lua
-- The journal window.
local _, ns = ...
local L = ns.L
local J = ns.Journal
local Q = ns.Quests
local P = ns.Private("Journal")

-- ---------------------------------------------------------------------------
-- Frame
-- ---------------------------------------------------------------------------

local function setProvider(box, rows)
    box:SetDataProvider(CreateDataProvider(rows), ScrollBoxConstants.RetainScrollPosition)
end

local function updateArt()
    local art
    if P.current.kind == "dungeon" then
        local d = ns.DB.dungeons[P.current.map]
        art = P.dungeonArt(d.name, (d.name:gsub("^The ", "")))
    elseif P.current.kind == "activity" then
        local f = P.current.a.forever
        art = P.dungeonArt(f and f.name or P.current.a.name, P.current.a.name, unpack(f and f.aliases or {}))
    end
    local tex = art and (art.lore or art.bg)
    if tex then
        P.frame.contentArt:SetTexture(tex)
        P.frame.contentArt:SetTexCoord(0, 0.7109375, 0, 0.66796875)
        P.frame.contentArt:Show()
    else
        P.frame.contentArt:Hide()
    end
end

local function fitTitle(h)
    h.title:SetFontObject("GameFontNormalHuge")
    local w = h.title:GetWidth()
    if w and w > 0 and h.title:GetStringWidth() > w then h.title:SetFontObject("GameFontNormalLarge") end
end

local function updateHeader()
    updateArt()
    local h = P.frame.header
    local page = P.pages[P.current.kind]
    for _, t in ipairs(P.frame.Tabs) do t:SetShown(not page) end
    P.frame.findBtn:SetShown(not page)
    local f = P.current.kind == "activity" and P.foreverOf(P.current.a)
    P.frame.guideBtn:SetShown((P.current.kind == "dungeon" and ns.DB.dungeons[P.current.map].entrance ~= nil) or (f and f.entrance) and true or false)
    P.frame.usable:SetShown(not page and P.tab == 3)
    P.frame.hideDone:SetShown(not page and P.tab == 2)
    local btn = page and page.button and page.button(P.current)
    P.frame.pageBtn:SetShown(btn and true or false)
    if btn then
        P.frame.pageBtn:SetText(btn.text)
        P.frame.pageBtn:SetScript("OnClick", btn.onClick)
    end
    if page then
        h.title:SetText(page.title(P.current))
        fitTitle(h)
        h.sub:SetText(page.sub and page.sub(P.current) or "")
    elseif P.current.kind == "dungeon" then
        local d = ns.DB.dungeons[P.current.map]
        h.title:SetText(d.name)
        fitTitle(h)
        local zone = d.area and ns.Maps.AreaName(d.area)
        h.sub:SetText(L.J_DUNGEON_SUB:format(d.min, d.max, #d.bosses) .. (d.raid and (" · " .. RAID) or ""))
        PanelTemplates_SetTab(P.frame, P.tab)
    else
        h.title:SetText(f and f.name or P.current.a.name)
        fitTitle(h)
        local sub = L.J_FOREVER_SUB:format(f and f.min or P.current.a.minLevel or 0, f and f.max or P.current.a.maxLevel or 0)
        if f then sub = sub .. " · " .. L.J_BOSS_COUNT:format(#f.bosses) .. " · " .. f.zone end
        h.sub:SetText(sub)
        PanelTemplates_SetTab(P.frame, P.tab)
    end
end

function J.Refresh()
    if not (P.frame and P.frame:IsShown()) then return end
    setProvider(P.frame.nav, P.navData())
    local rows
    local page = P.pages[P.current.kind]
    if page then rows = page.rows(P.current)
    elseif P.current.kind == "activity" then
        if P.tab == 1 then rows = P.activityOverview(P.current.a)
        elseif P.tab == 2 then rows = P.activityQuests(P.current.a)
        elseif P.tab == 3 then rows = P.activityLoot(P.current.a, P.current.boss)
        else rows = {} end
    elseif P.tab == 1 then rows = P.overviewRows(P.current.map)
    elseif P.tab == 2 then rows = P.questRows(P.current.map)
    elseif P.tab == 3 then rows = P.lootRows(P.current.map, P.current.npc)
    else rows = {} end
    local showMap = not page and P.tab == 4
    P.frame.content:SetShown(not showMap)
    P.frame.topEdge:SetShown(not showMap)
    P.frame.contentBar:SetShown(not showMap)
    if showMap then
        if P.current.kind == "dungeon" then
            local mapID = P.current.map
            ns.DMap.Draw(P.frame.contentInset, ns.DMap.SpecForDungeon(mapID), function(b) J.ShowDungeon(mapID, 3, b.npc) end)
        else
            ns.DMap.Draw(P.frame.contentInset, ns.DMap.SpecForActivity(P.current.a), function(b)
                P.current.boss = b.name; P.tab = 3; J.Refresh()
            end)
        end
    else
        ns.DMap.Hide()
        setProvider(P.frame.content, rows)
    end
    if J.SyncSettingsPanel then J.SyncSettingsPanel() end
    updateHeader()
end
local refreshSoon = ns.Debounce(0.3, function() J.Refresh() end)

local function makeScroll(parent, initializer)
    local box = CreateFrame("Frame", nil, parent, "WowScrollBoxList")
    local bar = CreateFrame("EventFrame", nil, parent, "MinimalScrollBar")
    local view = CreateScrollBoxListLinearView()
    view:SetElementInitializer("Button", initializer)
    view:SetElementExtentCalculator(function(_, data) return data.h or 24 end)
    ScrollUtil.InitScrollBoxListWithScrollBar(box, bar, view)
    return box, bar
end

local function inset(parent)
    local f = CreateFrame("Frame", nil, parent)
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetPoint("TOPLEFT", 3, -3)
    f.bg:SetPoint("BOTTOMRIGHT", -3, 3)
    if not ns.SetAtlas(f.bg, "groupfinder-background") then f.bg:SetColorTexture(0, 0, 0, 0.5) end
    f.border = f:CreateTexture(nil, "BORDER")
    f.border:SetPoint("TOPLEFT", 0, 2)
    f.border:SetPoint("BOTTOMRIGHT")
    ns.SetAtlas(f.border, "common-insideframe")
    return f
end

local function create()
    local f = CreateFrame("Frame", "DungeonPlannerJournal", UIParent, "PortraitFrameTemplate")
    local size = ns.opt.journalSize
    f:SetSize(size and size[1] or 880, size and size[2] or 580)
    f:SetScale(ns.opt.journalScale or 1)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:SetToplevel(true)
    f:Hide()
    tinsert(UISpecialFrames, "DungeonPlannerJournal")
    f:HookScript("OnHide", function() if ns.QuestLogOpener then ns.QuestLogOpener.Hide() end end)
    if f.SetTitle then f:SetTitle(L.J_TITLE .. "  |cff8c8c8cv" .. ns.VERSION .. "|r") end
    if f.SetPortraitToAsset then pcall(f.SetPortraitToAsset, f, "Interface\\Icons\\INV_Misc_Book_09") end
    local drag = f.TitleContainer or f
    drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function() f:StartMoving() end)
    drag:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)

    f.headerBg = f:CreateTexture(nil, "BACKGROUND", nil, -5)
    f.headerBg:SetPoint("TOPLEFT", 2, -21)
    f.headerBg:SetPoint("TOPRIGHT", -2, -21)
    f.headerBg:SetHeight(84)
    ns.SetAtlas(f.headerBg, "groupfinder-Stat-StoneBG")

    -- Search
    f.search = CreateFrame("EditBox", nil, f, "SearchBoxTemplate")
    f.search:SetSize(140, 20)
    f.search:SetPoint("TOPLEFT", 64, -34)

    -- Filter menu: Forever dungeons only, hide completed quests, usable loot only.
    f.filter = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.filter:SetSize(52, 22)
    f.filter:SetText(L.J_FILTER)
    f.filter:SetPoint("LEFT", f.search, "RIGHT", 4, 0)
    f.filter:SetScript("OnClick", function(self)
        if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
        MenuUtil.CreateContextMenu(self, function(_, root)
            root:CreateCheckbox(L.J_FILTER_FOREVER, function() return ns.opt.foreverOnly end,
                function() ns.opt.foreverOnly = not ns.opt.foreverOnly; J.Refresh() end)
            root:CreateCheckbox(L.J_FILTER_HIDE_DONE, function() return ns.opt.hideDoneQuests end,
                function() ns.opt.hideDoneQuests = not ns.opt.hideDoneQuests; f.hideDone:SetChecked(ns.opt.hideDoneQuests); J.Refresh() end)
            root:CreateCheckbox(L.J_FILTER_USABLE, function() return P.usableOnly end,
                function() P.usableOnly = not P.usableOnly; f.usable:SetChecked(P.usableOnly); J.Refresh() end)
            ns.LootFilter.BuildMenu(root, function() J.Refresh() end)
        end)
    end)
    f.search:HookScript("OnTextChanged", function(self)
        P.filterText = strtrim(self:GetText() or "")
        refreshSoon()
    end)

    -- Left list
    f.navInset = inset(f)
    f.navInset:SetPoint("TOPLEFT", 6, -64)
    f.navInset:SetPoint("BOTTOMLEFT", 6, 6)
    f.navInset:SetWidth(250)
    f.nav, f.navBar = makeScroll(f.navInset, P.initNavRow)
    f.nav:SetPoint("TOPLEFT", 4, -4)
    f.nav:SetPoint("BOTTOMRIGHT", -18, 4)
    f.navBar:SetPoint("TOPLEFT", f.nav, "TOPRIGHT", 2, 0)
    f.navBar:SetPoint("BOTTOMLEFT", f.nav, "BOTTOMRIGHT", 2, 0)

    -- Right header
    f.header = CreateFrame("Frame", nil, f)
    f.header:SetPoint("TOPLEFT", f.navInset, "TOPRIGHT", 12, 36)
    f.header:SetPoint("RIGHT", -12, 0)
    f.header:SetHeight(50)
    f.header.title = f.header:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    f.header.title:SetPoint("TOPLEFT", 0, -2)
    f.header.sub = f.header:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    f.header.sub:SetPoint("TOPLEFT", f.header.title, "BOTTOMLEFT", 0, -4)
    f.header.sub:SetWordWrap(false)
    f.header.title:SetWordWrap(false)

    f.findBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.findBtn:SetSize(120, 22)
    f.findBtn:SetText(L.J_FIND_GROUP)
    f.findBtn:SetPoint("TOPRIGHT", -14, -34)
    f.findBtn:SetScript("OnClick", function()
        local a = P.current.kind == "activity" and P.current.a or P.activityForMap(P.current.map)
        if a then ns.cdb.dungeonFilter = a.id else ns.cdb.dungeonFilter = 0 end
        -- Listed already: straight to the planner. Not yet: Blizzard's listing first.
        if ns.Call(C_LFGList and C_LFGList.HasActiveEntryInfo) then
            ns.UI.Open()
        else
            ns.UI.OpenListing(a)
        end
    end)

    f.guideBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.guideBtn:SetSize(140, 22)
    f.guideBtn:SetText(L.J_GUIDE_ENTRANCE)
    f.guideBtn:SetPoint("RIGHT", f.findBtn, "LEFT", -6, 0)
    -- Keep the title and its line clear of the buttons.
    f.header.title:SetPoint("RIGHT", f.guideBtn, "LEFT", -18, 0)
    f.header.sub:SetPoint("RIGHT", f.guideBtn, "LEFT", -18, 0)
    f.header.title:SetJustifyH("LEFT")
    f.header.sub:SetJustifyH("LEFT")
    f.guideBtn:SetScript("OnClick", function()
        if P.current.kind == "dungeon" then ns.Nav.GuideToDungeon(P.current.map)
        elseif P.current.kind == "activity" then
            local f = P.foreverOf(P.current.a)
            if f then ns.Nav.GuideToForever(f) end
        end
    end)

    f.usable = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    f.usable:SetSize(22, 22)
    f.usable:SetPoint("TOPRIGHT", f.findBtn, "BOTTOMRIGHT", -110, -16)
    local ut = f.usable.Text or f.usable:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    ut:SetFontObject("GameFontHighlightSmall")
    ut:ClearAllPoints()
    ut:SetPoint("LEFT", f.usable, "RIGHT", 2, 0)
    ut:SetText(L.J_USABLE_ONLY)
    f.usable:SetChecked(P.usableOnly)
    f.usable:SetScript("OnClick", function(self) P.usableOnly = self:GetChecked() and true or false; J.Refresh() end)

    -- Quests tab: hide the ones you've done.
    f.hideDone = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    f.hideDone:SetSize(22, 22)
    f.hideDone:SetPoint("TOPRIGHT", f.findBtn, "BOTTOMRIGHT", -110, -16)
    local ht = f.hideDone.Text or f.hideDone:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    ht:SetFontObject("GameFontHighlightSmall")
    ht:ClearAllPoints()
    ht:SetPoint("LEFT", f.hideDone, "RIGHT", 2, 0)
    ht:SetText(L.J_HIDE_DONE)
    f.hideDone:SetChecked(ns.opt.hideDoneQuests)
    f.hideDone:SetScript("OnClick", function(self) ns.opt.hideDoneQuests = self:GetChecked() and true or false; J.Refresh() end)

    -- A page's own action (Delete run, Clear wishlist...).
    f.pageBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.pageBtn:SetSize(130, 22)
    f.pageBtn:SetPoint("TOPRIGHT", -14, -34)
    f.pageBtn:Hide()

    -- Content
    f.contentInset = inset(f)
    f.contentInset:SetPoint("TOPLEFT", f.navInset, "TOPRIGHT", 8, -26)
    f.contentInset:SetPoint("BOTTOMRIGHT", -6, 6)
    -- The dungeon's own journal art, faded, behind its pages.
    f.contentArt = f.contentInset:CreateTexture(nil, "BACKGROUND", nil, 2)
    f.contentArt:SetPoint("TOPLEFT", 4, -4)
    f.contentArt:SetPoint("BOTTOMRIGHT", -4, 4)
    f.contentArt:SetAlpha(0.22)
    f.contentArt:Hide()
    f.content, f.contentBar = makeScroll(f.contentInset, P.initContentRow)
    f.content:SetPoint("TOPLEFT", 4, -14)
    -- A clear edge under the tabs: a gold rule, and rows fade out as they scroll beneath it.
    f.topEdge = CreateFrame("Frame", nil, f.contentInset)
    f.topEdge:SetPoint("TOPLEFT", 3, -3)
    f.topEdge:SetPoint("TOPRIGHT", -3, -3)
    f.topEdge:SetHeight(24)
    f.topEdge:SetFrameLevel(f.content:GetFrameLevel() + 10)
    f.topEdge:EnableMouse(false)
    f.topEdge.bg = f.topEdge:CreateTexture(nil, "BACKGROUND")
    f.topEdge.bg:SetPoint("TOPLEFT")
    f.topEdge.bg:SetPoint("TOPRIGHT")
    f.topEdge.bg:SetHeight(11)
    f.topEdge.bg:SetColorTexture(0.05, 0.04, 0.03, 1)
    f.topEdge.line = f.topEdge:CreateTexture(nil, "ARTWORK")
    f.topEdge.line:SetPoint("TOPLEFT", f.topEdge.bg, "BOTTOMLEFT", 6, 0)
    f.topEdge.line:SetPoint("TOPRIGHT", f.topEdge.bg, "BOTTOMRIGHT", -6, 0)
    f.topEdge.line:SetHeight(1)
    f.topEdge.line:SetColorTexture(1, 0.82, 0, 0.45)
    f.topEdge.fade = f.topEdge:CreateTexture(nil, "BACKGROUND", nil, 1)
    f.topEdge.fade:SetPoint("TOPLEFT", f.topEdge.bg, "BOTTOMLEFT")
    f.topEdge.fade:SetPoint("TOPRIGHT", f.topEdge.bg, "BOTTOMRIGHT")
    f.topEdge.fade:SetHeight(12)
    f.topEdge.fade:SetColorTexture(1, 1, 1, 1)
    if not pcall(f.topEdge.fade.SetGradient, f.topEdge.fade, "VERTICAL", CreateColor(0.05, 0.04, 0.03, 0), CreateColor(0.05, 0.04, 0.03, 0.9)) then
        f.topEdge.fade:SetColorTexture(0.05, 0.04, 0.03, 0.5)
    end
    f.content:SetPoint("BOTTOMRIGHT", -18, 4)
    f.contentBar:SetPoint("TOPLEFT", f.content, "TOPRIGHT", 2, 0)
    f.contentBar:SetPoint("BOTTOMLEFT", f.content, "BOTTOMRIGHT", 2, 0)

    for i, label in ipairs({ L.J_OVERVIEW, L.J_QUESTS, L.J_LOOT, L.J_MAP }) do
        local t = CreateFrame("Button", nil, f, "PanelTopTabButtonTemplate")
        t:SetID(i)
        t:SetText(label)
        t:SetScript("OnClick", function()
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
            P.tab = i
            P.current.npc = nil
            P.current.boss = nil
            J.Refresh()
        end)
        if i == 1 then t:SetPoint("BOTTOMLEFT", f.contentInset, "TOPLEFT", 8, -2) end
    end
    PanelTemplates_SetNumTabs(f, 4)
    for _, t in ipairs(f.Tabs) do PanelTemplates_TabResize(t, 0) end

    f:SetScript("OnShow", function()
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
        ns.Data.ScanQuests()
        J.Refresh()
    end)
    f:SetScript("OnHide", function() PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE) end)

    -- Resize from the bottom right corner (the size is remembered).
    f:SetResizable(true)
    if f.SetResizeBounds then f:SetResizeBounds(820, 520, 1600, 1100) end
    f.grip = CreateFrame("Button", nil, f)
    f.grip:SetSize(16, 16)
    f.grip:SetPoint("BOTTOMRIGHT", -3, 3)
    f.grip:SetFrameLevel(f:GetFrameLevel() + 20)
    f.grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    f.grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    f.grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    f.grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
    f.grip:SetScript("OnMouseUp", function()
        f:StopMovingOrSizing()
        ns.opt.journalSize = { math.floor(f:GetWidth()), math.floor(f:GetHeight()) }
        J.Refresh()
    end)
    f.grip:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.J_RESIZE, 1, 1, 1)
        GameTooltip:Show()
    end)
    f.grip:SetScript("OnLeave", GameTooltip_Hide)
    return f
end

function J.Toggle()
    if P.frame and P.frame:IsShown() then return P.frame:Hide() end
    J.OpenSmart()
end

function J.Open()
    if not P.frame then P.frame = create() end
    P.frame:Show()
end

function J.ShowDungeon(mapID, whichTab, npc)
    if not (ns.DB and ns.DB.dungeons[mapID]) then return end
    P.current = { kind = "dungeon", map = mapID, npc = npc }
    P.tab = whichTab or P.tab or 1
    J.Open()
    J.Refresh()
end

function J.ShowActivity(a)
    if a and a.mapID and ns.DB.dungeons[a.mapID] then return J.ShowDungeon(a.mapID) end
    P.current = { kind = "activity", a = a }
    P.tab = 1
    J.Open()
    J.Refresh()
end

-- /dp map: what the map tab found for the page that's open.
function J.MapDebug()
    if P.current.kind == "dungeon" then ns.DMap.Debug(ns.DMap.SpecForDungeon(P.current.map))
    elseif P.current.kind == "activity" then ns.DMap.Debug(ns.DMap.SpecForActivity(P.current.a))
    else ns.DMap.Debug(nil) end
end

function J.SetScale(scale)
    scale = math.max(0.6, math.min(1.5, scale or 1))
    ns.opt.journalScale = scale
    if P.frame then P.frame:SetScale(scale) end
end

-- Open the dungeon you're standing in, on one tab (4 = map). False if you aren't in one.
function J.OpenHere(whichTab)
    local name, instanceType, _, _, _, _, _, instanceID = ns.Call(GetInstanceInfo)
    name, instanceID = ns.Safe(name), ns.Safe(instanceID)
    if not (instanceType == "party" and name) then return false end
    if instanceID and ns.DB.dungeons[instanceID] then J.ShowDungeon(instanceID, whichTab or 1) return true end
    local key = ns.Data.Normalize(name)
    for mapID, d in pairs(ns.DB.dungeons) do
        if ns.Data.Normalize(d.name) == key then J.ShowDungeon(mapID, whichTab or 1) return true end
    end
    local f = ns.ForeverFor and ns.ForeverFor(name)
    for _, a in ipairs(J.ForeverDungeons()) do
        if (f and a.forever == f) or ns.Data.Normalize(a.name) == key then
            J.ShowActivity(a)
            J.SelectTab(whichTab or 1)
            return true
        end
    end
    return false
end

function J.SelectTab(i)
    P.tab = i
    J.Refresh()
end

function J.ShowUpgrades() J.ShowPage("upgrades") end


-- Open the journal on the dungeon you are in, else the one that suits your level best.
function J.OpenSmart()
    local _, instanceType, _, _, _, _, _, instanceID = ns.Call(GetInstanceInfo)
    instanceID = ns.Safe(instanceID)
    if (instanceType == "party" or instanceType == "raid") and instanceID and ns.DB.dungeons[instanceID] then
        return J.ShowDungeon(instanceID, 1)
    end
    -- The arrow is guiding you through a secret: open on it (the Next step is at the top).
    local secret = ns.SecretsSvc and ns.SecretsSvc.Guided and ns.SecretsSvc.Guided()
    if secret then return J.ShowPage("secret", secret.id) end
    -- On your way somewhere with the arrow: open the dungeon you're working on.
    local g = ns.Nav.GuidedDungeon and ns.Nav.GuidedDungeon()
    if g and g.map then return J.ShowDungeon(g.map, g.quest and 2 or 1) end
    if g and g.forever then
        local f = ns.ForeverFor(g.forever)
        for _, a in ipairs(J.ForeverDungeons()) do
            if a.forever == f then
                J.ShowActivity(a)
                return J.SelectTab(g.quest and 2 or 1)
            end
        end
    end
    if P.pages[P.current.kind] or not P.frame then
        -- The dungeon in your range with the most quests waiting (in your log counts most).
        local level, best, bestScore = ns.Data.MyLevel(), nil, -1
        for mapID, d in pairs(ns.DB.dungeons) do
            if not d.raid and level >= d.min and level <= d.max then
                local _, c = Q.ForDungeon(mapID)
                local score = (c.log * 3 + c.ready) * 100 + d.min
                if score > bestScore then best, bestScore = mapID, score end
            end
        end
        if best then return J.ShowDungeon(best, 1) end
    end
    J.Open()
end

for _, msg in ipairs({ "QUESTS_CHANGED", "GEAR_CHANGED", "TRACKER_CHANGED", "ACTIVITIES_CHANGED", "LEARNED_CHANGED" }) do
    ns.Listen(msg, refreshSoon)
end
ns.On("QUEST_TURNED_IN", refreshSoon)

-- Item data arriving from the server changes names, colors and levels: redraw.
ns.On("GET_ITEM_INFO_RECEIVED", refreshSoon)
ns.On("ITEM_DATA_LOAD_RESULT", refreshSoon)
