-- QuestData.lua
-- Helping fill in WoW Forever's real quest numbers. Only with the player's yes (asked once,
-- changeable in Settings), the addon notes what the game itself shows: the XP and money a
-- quest pays, its reward items, and who gives it and where. Nothing leaves the computer on its
-- own: a small "Share quest data" pill shows up in an inn or city once there's enough to send
-- (or /dp data, or the button in Settings) and opens a window with the text to copy, and the
-- player pastes it into the "Send quest data" form on the addon's GitHub page.
-- No character, account or guild names are ever recorded.
local _, ns = ...
local L = ns.L
local D = {}
ns.QuestData = D

D.FORM_URL = "https://github.com/OGMeego/DungeonPlanner/issues/new?template=quest-data.yml"
D.FORMAT = 1
D.MAX_LINES = 600      -- oldest notes go first past this
D.MAX_CHARS = 55000    -- one form submission holds about 65,000 characters
D.REMIND_AT = 15       -- remind at an inn once this many notes wait

local function store()
    ns.db.qdata = ns.db.qdata or { list = {}, keys = {} }
    local s = ns.db.qdata
    s.list = s.list or {}
    s.keys = s.keys or {}
    return s
end

function D.Consent() return store().consent end

function D.SetConsent(yes)
    store().consent = yes and true or false
    if D.frame then D.frame:Hide() end
end

-- "Creature-0-1-2-3-<npcID>-..." / "GameObject-..." -> "N1234" / "O1234"
local function who(unit)
    local guid = UnitGUID and ns.Call(UnitGUID, unit)
    if type(guid) ~= "string" then return nil end
    local kind, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)")
    if kind == "Creature" then return "N" .. id end
    if kind == "GameObject" then return "O" .. id end
    return nil
end

local function where()
    local m = C_Map and C_Map.GetBestMapForUnit and ns.Call(C_Map.GetBestMapForUnit, "player")
    local pos = m and C_Map.GetPlayerMapPosition and ns.Call(C_Map.GetPlayerMapPosition, m, "player")
    local x, y
    if pos and pos.GetXY then x, y = pos:GetXY() end
    if not (m and x and y) then return nil end
    return ("@%d:%.1f,%.1f"):format(m, x * 100, y * 100)
end

local function items(kind, count)
    local t = {}
    for i = 1, (count and ns.Call(count) or 0) do
        local link = GetQuestItemLink and ns.Call(GetQuestItemLink, kind, i)
        local id = link and link:match("item:(%d+)")
        if id then
            local n = GetQuestItemInfo and select(3, ns.Call(GetQuestItemInfo, kind, i))
            t[#t + 1] = (n and n > 1) and (id .. "x" .. n) or id
        end
    end
    return #t > 0 and table.concat(t, ",") or nil
end

-- Add one line; the same thing seen again at the same level is only kept once.
function D.Note(line, key)
    if D.Consent() ~= true then return end
    local s = store()
    if key then
        if s.keys[key] then return end
        s.keys[key] = true
    end
    s.list[#s.list + 1] = line
    while #s.list > D.MAX_LINES do table.remove(s.list, 1) end
end

-- The quest window: A = offered (accept screen), C = hand-in screen.
function D.NoteWindow(kind)
    local qid = GetQuestID and ns.Call(GetQuestID)
    if not qid or qid == 0 then return end
    local lvl = ns.Data.MyLevel()
    local parts = { kind, qid, "L" .. lvl }
    local xp = GetRewardXP and ns.Call(GetRewardXP)
    if xp and xp > 0 then parts[#parts + 1] = "X" .. xp end
    local money = GetRewardMoney and ns.Call(GetRewardMoney)
    if money and money > 0 then parts[#parts + 1] = "M" .. money end
    local npc = who("npc")
    if npc then parts[#parts + 1] = npc end
    local at = where()
    if at then parts[#parts + 1] = at end
    local c = items("choice", GetNumQuestChoices)
    if c then parts[#parts + 1] = "c:" .. c end
    local r = items("reward", GetNumQuestRewards)
    if r then parts[#parts + 1] = "r:" .. r end
    D.Note(table.concat(parts, " "), kind .. qid .. ":" .. lvl)
end

-- What the hand-in actually paid.
function D.NoteTurnIn(qid, xp, money)
    qid = tonumber(qid)
    if not qid then return end
    local lvl = ns.Data.MyLevel()
    D.Note(("T %d L%d X%d M%d"):format(qid, lvl, tonumber(xp) or 0, tonumber(money) or 0), "T" .. qid .. ":" .. lvl)
end

ns.On("QUEST_DETAIL", function() ns.After(0.1, function() D.NoteWindow("A") end) end)
ns.On("QUEST_COMPLETE", function() ns.After(0.1, function() D.NoteWindow("C") end) end)
ns.On("QUEST_TURNED_IN", function(qid, xp, money) D.NoteTurnIn(ns.Safe(qid), ns.Safe(xp), ns.Safe(money)) end)

function D.Count() return #store().list end

-- The text to paste, at most MAX_CHARS long; returns text and how many notes it holds.
function D.ExportText()
    local s = store()
    local ver, build = (GetBuildInfo and GetBuildInfo())
    local head = ("DPQD %d | DP %s | %s.%s | %s | %s"):format(D.FORMAT, tostring(ns.VERSION), tostring(ver), tostring(build),
        tostring(GetLocale and GetLocale() or "?"), (UnitFactionGroup and UnitFactionGroup("player") == "Horde") and "H" or "A")
    local out, size, n = { head }, #head, 0
    for _, line in ipairs(s.list) do
        if size + #line + 1 > D.MAX_CHARS then break end
        out[#out + 1] = line
        size = size + #line + 1
        n = n + 1
    end
    return table.concat(out, "\n"), n
end

-- After the player has sent them: drop the first n notes (keep the "seen" keys, so the
-- same thing isn't noted again).
function D.MarkSent(n)
    local s = store()
    for _ = 1, math.min(n or 0, #s.list) do table.remove(s.list, 1) end
end

-- ---------------------------------------------------------------------------
-- Asking once
-- ---------------------------------------------------------------------------

local function button(parent, text, w)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w or 110, 22)
    b:SetText(text)
    return b
end

local function window(name, w, h, title)
    local f = CreateFrame("Frame", name, UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(w, h)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    tinsert(UISpecialFrames, name)
    local t = f.TitleText or f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    if not f.TitleText then t:SetPoint("TOP", 0, -5) end
    t:SetText(title)
    return f
end

function D.Ask()
    if not D.frame then
        local f = window("DungeonPlannerQuestDataAsk", 440, 170, L.QD_TITLE)
        local text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        text:SetPoint("TOPLEFT", 16, -34)
        text:SetPoint("RIGHT", -16, 0)
        text:SetJustifyH("LEFT")
        text:SetText(L.QD_ASK)
        local yes = button(f, YES or "Yes")
        yes:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -6, 14)
        yes:SetScript("OnClick", function() D.SetConsent(true); ns.Say(L.QD_YES2) end)
        local no = button(f, NO or "No")
        no:SetPoint("BOTTOMLEFT", f, "BOTTOM", 6, 14)
        no:SetScript("OnClick", function() D.SetConsent(false); ns.Say(L.QD_NO) end)
        f:SetScript("OnHide", function() end)
        D.frame = f
    end
    D.frame:Show()
end

ns.Listen("LOGIN", function()
    if D.Consent() == nil then ns.After(20, function()
        if D.Consent() == nil and not (InCombatLockdown and InCombatLockdown()) then D.Ask() end
    end) end
end)

-- ---------------------------------------------------------------------------
-- The reminder at an inn and the export window
-- ---------------------------------------------------------------------------

-- The pill: a small button that shows up in an inn or city once enough notes wait. Click it to
-- open the window; right-click hides it until the next login. Drag it anywhere.
local pill, pillHidden
local function makePill()
    local b = CreateFrame("Button", "DungeonPlannerQuestDataPill", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    b:SetSize(190, 26)
    b:SetFrameStrata("MEDIUM")
    b:SetClampedToScreen(true)
    if b.SetBackdrop then
        b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        b:SetBackdropColor(0.10, 0.07, 0.03, 0.92)
        b:SetBackdropBorderColor(1, 0.82, 0.2, 1)
    end
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetSize(16, 16)
    icon:SetPoint("LEFT", 8, 0)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    text:SetPoint("RIGHT", -8, 0)
    text:SetJustifyH("LEFT")
    b.text = text
    local o = ns.opt or {}
    local pos = o.qdPill
    if pos then b:SetPoint(pos[1], UIParent, pos[1], pos[2], pos[3]) else b:SetPoint("TOP", UIParent, "TOP", 0, -110) end
    b:SetMovable(true)
    b:RegisterForDrag("LeftButton")
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnDragStart", b.StartMoving)
    b:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, _, x, y = self:GetPoint(1)
        if ns.opt then ns.opt.qdPill = { p, x, y } end
    end)
    b:SetScript("OnClick", function(self, which)
        if which == "RightButton" then pillHidden = true; self:Hide() return end
        self:Hide()
        D.Show()
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(L.QD_TITLE)
        GameTooltip:AddLine(L.QD_PILL_TIP, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:Hide()
    return b
end

function D.UpdatePill()
    local want = not pillHidden and D.Consent() == true and D.Count() >= D.REMIND_AT
        and IsResting and IsResting() and not (InCombatLockdown and InCombatLockdown())
        and not (D.export and D.export:IsShown())
    if want then
        pill = pill or makePill()
        pill.text:SetText(L.QD_PILL:format(D.Count()))
        pill:Show()
    elseif pill then
        pill:Hide()
    end
end

ns.On("PLAYER_UPDATE_RESTING", function() D.UpdatePill() end)
ns.On("PLAYER_REGEN_ENABLED", function() D.UpdatePill() end)
ns.On("PLAYER_REGEN_DISABLED", function() if pill then pill:Hide() end end)
ns.Listen("LOGIN", function() ns.After(25, D.UpdatePill) end)
ns.On("QUEST_TURNED_IN", function() ns.After(1, D.UpdatePill) end)

function D.Show()
    if D.Consent() ~= true and D.Count() == 0 then ns.Say(L.QD_OFF); return end
    local f = D.export
    if not f then
        f = window("DungeonPlannerQuestData", 580, 440, L.QD_TITLE)
        local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        hint:SetPoint("TOPLEFT", 14, -30)
        hint:SetPoint("RIGHT", -14, 0)
        hint:SetJustifyH("LEFT")
        hint:SetText(L.QD_HINT)
        local url = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
        url:SetSize(540, 20)
        url:SetPoint("TOPLEFT", 20, -76)
        url:SetAutoFocus(false)
        url:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
        url:SetScript("OnTextChanged", function(self, user) if user then self:SetText(D.FORM_URL) end end)
        url:SetScript("OnEscapePressed", function() f:Hide() end)
        f.url = url
        local ok, scroll = pcall(CreateFrame, "ScrollFrame", nil, f, "ScrollFrameTemplate")
        if not ok or not scroll then scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate") end
        scroll:SetPoint("TOPLEFT", 14, -104)
        scroll:SetPoint("BOTTOMRIGHT", -32, 46)
        local edit = CreateFrame("EditBox", nil, scroll)
        edit:SetMultiLine(true)
        edit:SetAutoFocus(false)
        edit:SetFontObject(ChatFontNormal)
        edit:SetWidth(520)
        edit:SetScript("OnEscapePressed", function() f:Hide() end)
        edit:SetScript("OnTextChanged", function(self, user) if user and f.text then self:SetText(f.text); self:HighlightText() end end)
        scroll:SetScrollChild(edit)
        f.edit = edit
        local sent = button(f, L.QD_SENT, 200)
        sent:SetPoint("BOTTOMLEFT", 14, 14)
        sent:SetScript("OnClick", function()
            D.MarkSent(f.n)
            ns.Say(L.QD_THANKS)
            if D.Count() > 0 then D.Show() else f:Hide() end
            D.UpdatePill()
        end)
        f.sent = sent
        local note = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        note:SetPoint("LEFT", sent, "RIGHT", 10, 0)
        note:SetPoint("RIGHT", -14, 0)
        note:SetJustifyH("LEFT")
        f.note = note
        D.export = f
    end
    f.text, f.n = D.ExportText()
    f.url:SetText(D.FORM_URL)
    f.url:SetCursorPosition(0)
    f.edit:SetText(f.n > 0 and f.text or L.QD_EMPTY)
    if f.n > 0 then f.sent:Enable() else f.sent:Disable() end
    local left = D.Count() - f.n
    f.note:SetText(left > 0 and L.QD_MORE:format(left) or L.QD_SENT_DESC)
    f:Show()
    if f.n > 0 then f.edit:SetFocus(); f.edit:HighlightText() end
end
