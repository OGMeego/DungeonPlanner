-- QuestLogOpener: "click a quest you have to open it in your quest log", without taint.
-- Opening the quest log (the world map) from addon code runs Blizzard's window manager in
-- tainted mode, and later the spellbook can't cast ("tried to call CastSpellBookItem").
-- So the click itself is done by a secure button: when you hover a quest row that is in
-- your log, this invisible button sits over the row and, on a plain left click, clicks the
-- game's own quest log micro button for you. The quest is selected and super-tracked first,
-- so it is the one highlighted. Other clicks (shift-click to link, right-click) go to the row.
--
-- The button is parented to UIParent and placed by screen position, never anchored to our
-- rows. It is hidden when combat starts and never shown during combat.
local _, ns = ...

local O = {}
ns.QuestLogOpener = O

local button, owner, quest

local function microButton()
    return _G.QuestLogMicroButton
end

function O.Available()
    return microButton() ~= nil and not InCombatLockdown()
end

local function hide()
    if button and button:IsShown() and not InCombatLockdown() then button:Hide() end
    if owner and owner.UnlockHighlight then owner:UnlockHighlight() end
    owner, quest = nil, nil
end
O.Hide = hide

local function selectQuest(qid)
    if not qid then return end
    if C_QuestLog and C_QuestLog.SetSelectedQuest then pcall(C_QuestLog.SetSelectedQuest, qid) end
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID then pcall(C_SuperTrack.SetSuperTrackedQuestID, qid) end
end
O.Select = selectQuest

-- With the quest log already open, turn it to this quest's page.
function O.ShowDetails(qid)
    if not qid or InCombatLockdown() then return end
    if WorldMapFrame and WorldMapFrame:IsShown() and QuestMapFrame_ShowQuestDetails then
        pcall(QuestMapFrame_ShowQuestDetails, qid)
    elseif QuestLogFrame and QuestLogFrame:IsShown() then
        local index = ns.Safe(ns.Call(C_QuestLog and C_QuestLog.GetLogIndexForQuestID, qid))
            or (GetQuestLogIndexByID and ns.Safe(ns.Call(GetQuestLogIndexByID, qid)))
        if index and index > 0 then
            if QuestLog_SetSelection then pcall(QuestLog_SetSelection, index) end
            if QuestLog_Update then pcall(QuestLog_Update) end
        end
    end
end

local function questLogShown()
    return (WorldMapFrame and WorldMapFrame:IsShown()) or (QuestLogFrame and QuestLogFrame:IsShown())
end

local function create()
    -- Same kind of button as the planner's search button: Blizzard's action-button code runs
    -- the click untainted, and the button itself isn't protected.
    local ok, b = pcall(CreateFrame, "Button", "DungeonPlannerQuestLogOpener", UIParent, "InsecureActionButtonTemplate")
    if not (ok and b) then b = CreateFrame("Button", "DungeonPlannerQuestLogOpener", UIParent, "SecureActionButtonTemplate") end
    button = b
    button:RegisterForClicks("AnyUp")
    button:SetAttribute("useOnKeyDown", false)
    button:EnableMouseWheel(false) -- the journal keeps scrolling under it
    button:Hide()
    button:SetScript("PreClick", function(self, mouse)
        if InCombatLockdown() then return end
        -- Already open: don't let the micro button close it again, just select the quest.
        self:SetAttribute("type1", questLogShown() and "" or "click")
        if mouse == "LeftButton" and not IsModifiedClick() then selectQuest(quest) end
    end)
    button:SetScript("PostClick", function(_, mouse)
        local row = owner
        if mouse == "LeftButton" and not IsModifiedClick() then
            local q = quest
            selectQuest(q)
            -- The log is open now: show the quest itself. (Only the page inside the already
            -- open window changes; no window is opened from our code.)
            ns.After(0.15, function() O.ShowDetails(q) end)
            -- If the game didn't open the log, say how to.
            ns.After(0.4, function()
                if not questLogShown() and ns.Quests and ns.Quests.LogHint then ns.Quests.LogHint(q) end
            end)
            return
        end
        local click = row and row:GetScript("OnClick")
        if click then click(row, mouse) end
    end)
    button:SetScript("OnEnter", function()
        local row = owner
        local enter = row and row:GetScript("OnEnter")
        if enter then enter(row) end
    end)
    button:SetScript("OnLeave", function()
        local row = owner
        local leave = row and row:GetScript("OnLeave")
        if leave then leave(row) end
        hide()
    end)
end

-- Put the button over a row whose quest is in your log. Called from the row's OnEnter.
function O.Cover(row, qid)
    if not (qid and row and row:IsVisible()) or InCombatLockdown() then return false end
    local micro = microButton()
    if not micro then return false end
    if not button then create() end
    local left, bottom, width, height = row:GetRect()
    if not left then return false end
    local s = row:GetEffectiveScale() / UIParent:GetEffectiveScale()
    if owner and owner ~= row and owner.UnlockHighlight then owner:UnlockHighlight() end
    owner, quest = row, qid
    if row.LockHighlight then row:LockHighlight() end
    -- Leave the row's own small buttons (map pin, guide arrow, rewards, Guide me there)
    -- uncovered: the overlay spans the row up to the first of them.
    local right = left + width
    for _, child in ipairs({ row:GetChildren() }) do
        if child:IsShown() and child.GetLeft and child:GetLeft() and child:GetLeft() > left + 40 then
            right = math.min(right, child:GetLeft() - 2)
        end
    end
    width = right - left
    button:SetAttribute("type1", "click")
    button:SetAttribute("clickbutton1", micro)
    button:ClearAllPoints()
    button:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left * s, bottom * s)
    button:SetSize(width * s, height * s)
    -- One strata above the row: the journal is a top-level window that raises its own frame
    -- levels when clicked, so a level just above the row could end up underneath it.
    local STRATA = { BACKGROUND = "LOW", LOW = "MEDIUM", MEDIUM = "HIGH", HIGH = "DIALOG", DIALOG = "FULLSCREEN",
        FULLSCREEN = "FULLSCREEN_DIALOG", FULLSCREEN_DIALOG = "FULLSCREEN_DIALOG" }
    button:SetFrameStrata(STRATA[row:GetFrameStrata()] or "HIGH")
    button:Show()
    return true
end

-- Rows call this when they are hidden or reused.
function O.Release(row)
    if owner == row then hide() end
end

ns.On("PLAYER_REGEN_DISABLED", hide)
