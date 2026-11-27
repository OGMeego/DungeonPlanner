-- Tracker.lua
-- The tracker frame beside the quest tracker, and what updates it.
local _, ns = ...
local L = ns.L
local T = ns.Tracker
local MAX_LINES = 22
local P = ns.Private("Tracker")

-- ---------------------------------------------------------------------------
-- Frame (plain text in the quest tracker's style: gold header, white lines)
-- ---------------------------------------------------------------------------

local function create()
    local f = CreateFrame("Frame", "DungeonPlannerTracker", UIParent)
    f:SetSize(230, 40)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:SetFrameStrata("LOW")
    local pos = ns.cdb.trackerPos
    if pos then
        f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    else
        f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -90, -260)
    end

    f.header = CreateFrame("Button", nil, f)
    f.header:SetPoint("TOPLEFT")
    f.header:SetPoint("TOPRIGHT")
    f.header:SetHeight(24)
    f.header:RegisterForDrag("LeftButton")
    f.header:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    f.header.bg = f.header:CreateTexture(nil, "BACKGROUND")
    f.header.bg:SetAllPoints()
    if not ns.SetAtlas(f.header.bg, "Objective-Header") then f.header.bg:SetColorTexture(0, 0, 0, 0.35) end
    f.header.text = f.header:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    f.header.text:SetPoint("LEFT", 10, 0)
    f.header.text:SetPoint("RIGHT", -24, 0)
    f.header.text:SetJustifyH("LEFT")
    f.header.toggle = f.header:CreateTexture(nil, "ARTWORK")
    f.header.toggle:SetSize(14, 14)
    f.header.toggle:SetPoint("RIGHT", -6, 0)
    f.header:SetScript("OnDragStart", function() if not InCombatLockdown() then f:StartMoving() end end)
    f.header:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        local p, _, rp, x, y = f:GetPoint(1)
        ns.cdb.trackerPos = { p, rp, x, y }
    end)
    f.header:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            if ns.Journal then ns.Journal.OpenSmart() end
            return
        end
        ns.cdb.trackerCollapsed = not ns.cdb.trackerCollapsed
        T.Update()
    end)
    f.header:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(L.ADDON_TITLE, 1, 1, 1)
        GameTooltip:AddLine(L.T_HINT, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, true)
        GameTooltip:Show()
    end)
    f.header:SetScript("OnLeave", GameTooltip_Hide)

    f.lines = {}
    for i = 1, MAX_LINES do
        local fs = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)
        fs:SetWidth(220)
        if i == 1 then fs:SetPoint("TOPLEFT", f.header, "BOTTOMLEFT", 12, -4)
        else fs:SetPoint("TOPLEFT", f.lines[i - 1], "BOTTOMLEFT", 0, -3) end
        f.lines[i] = fs
    end
    return f
end

local function questLines(mapID, activity, out)
    local function add(qid, title)
        local idx = ns.Call(C_QuestLog.GetLogIndexForQuestID, qid)
        if not idx then return end
        local done = ns.Call(C_QuestLog.IsComplete, qid)
        tinsert(out, { text = (done and ns.AtlasMarkup("QuestTurnin", 12) or ns.AtlasMarkup("QuestNormal", 12)) .. " " .. title,
            color = done and GREEN_FONT_COLOR or NORMAL_FONT_COLOR })
        if not done then
            local objectives = ns.Call(C_QuestLog.GetQuestObjectives, qid)
            if type(objectives) == "table" then
                for _, o in ipairs(objectives) do
                    local text = ns.Field(o, "text")
                    if text and not ns.Field(o, "finished") then tinsert(out, { text = "   - " .. text, color = HIGHLIGHT_FONT_COLOR }) end
                end
            end
        end
    end
    local d = mapID and ns.DB.dungeons[mapID]
    local seen = {}
    if d then
        for _, qid in ipairs(d.quests) do
            seen[qid] = true
            add(qid, ns.Quests.Title(qid))
        end
    end
    for qid, q in pairs(ns.Data.quests) do
        if not seen[qid] and activity and q.dungeon == activity then add(qid, q.title) end
    end
end

function T.Update()
    local inDungeon = P.here.map ~= nil
    if not (ns.opt and ns.opt.tracker) or not inDungeon then
        if P.frame then P.frame:Hide() end
        return
    end
    if not P.frame then P.frame = create() end
    P.frame:Show()
    P.frame.header.text:SetText(P.here.name or "")
    T.UpdateTimer()
    ns.SetAtlas(P.frame.header.toggle, ns.cdb.trackerCollapsed and "UI-QuestTrackerButton-Expand-All" or "UI-QuestTrackerButton-Collapse-All")

    local lines = {}
    if not ns.cdb.trackerCollapsed then
        local done = P.kills[P.here.map] or {}
        local d = ns.DB.dungeons[P.here.map]
        local bosses = {}
        if d then
            for _, b in ipairs(d.bosses) do tinsert(bosses, { enc = b[1], name = b[3] }) end
        else
            for _, name in ipairs(T.BossesForName(P.here.name)) do tinsert(bosses, { name = name }) end
        end
        local nextShown = false
        for i, b in ipairs(bosses) do
            local killed = (b.enc and done[b.enc]) or done[b.name]
            local mark
            if killed then
                mark = ns.AtlasMarkup("common-icon-checkmark", 12)
            elseif not nextShown then
                mark = "|cffffd100>|r"
                nextShown = true
            else
                mark = "  "
            end
            tinsert(lines, { text = ("%s %d. %s"):format(mark, i, b.name),
                color = killed and GRAY_FONT_COLOR or (mark == "|cffffd100>|r" and NORMAL_FONT_COLOR or HIGHLIGHT_FONT_COLOR) })
        end
        if #bosses == 0 then tinsert(lines, { text = L.T_LEARNING, color = GRAY_FONT_COLOR }) end
        local activity = ns.Data.byName[ns.Data.Normalize(P.here.name)] or (ns.Data.ActivityForMap and ns.Data.ActivityForMap(P.here.map))
        local qlines = {}
        questLines(P.here.map, activity, qlines)
        if #qlines > 0 then
            tinsert(lines, { text = " ", color = HIGHLIGHT_FONT_COLOR })
            for _, l in ipairs(qlines) do tinsert(lines, l) end
        end
    end
    for i = 1, MAX_LINES do
        local fs, l = P.frame.lines[i], lines[i]
        if l then
            fs:SetText(l.text)
            fs:SetTextColor(l.color.r, l.color.g, l.color.b)
            fs:Show()
        else
            fs:Hide()
        end
    end
    P.frame:SetHeight(28 + math.min(#lines, MAX_LINES) * 14)
end
local updateSoon = ns.Debounce(0.3, function() T.Update() end)

-- ---------------------------------------------------------------------------
-- Where am I, and who died
-- ---------------------------------------------------------------------------

local function whereAmI()
    local name, instanceType, _, _, _, _, _, instanceID = ns.Call(GetInstanceInfo)
    name, instanceID = ns.Safe(name), ns.Safe(instanceID)
    if (instanceType == "party" or instanceType == "raid") and instanceID then
        if P.here.map ~= instanceID then
            -- A new visit: start a fresh kill list unless we just stepped out and back in.
            if not (P.here.lastMap == instanceID and P.here.leftAt and ns.Now() - P.here.leftAt < 1800) then
                P.kills[instanceID] = {}
            end
        end
        P.here.map, P.here.name = instanceID, name
        if ns.DMap and name then ns.DMap.LearnFloor(name, (P.myFloor())) end
    else
        if P.here.map then P.here.lastMap, P.here.lastName, P.here.leftAt = P.here.map, P.here.name, ns.Now() end
        P.here.map, P.here.name = nil, nil
    end
    updateSoon()
    ns.Fire("TRACKER_CHANGED")
end

local function onKill(encounterID, encounterName)
    if not P.here.map then return end
    encounterID, encounterName = ns.Safe(encounterID), ns.Safe(encounterName)
    P.kills[P.here.map] = P.kills[P.here.map] or {}
    if encounterID then P.kills[P.here.map][encounterID] = true end
    if encounterName then P.kills[P.here.map][encounterName] = true end
    -- Forever renamed some bosses: count the kill under our name too.
    local f = encounterName and P.here.name and ns.ForeverFor and ns.ForeverFor(P.here.name)
    local ourName = encounterName
    for _, b in ipairs(f and f.bosses or {}) do
        if b.alias and ns.Data.Normalize(b.alias) == ns.Data.Normalize(encounterName) then
            P.kills[P.here.map][b.name] = true
            ourName = b.name
        end
    end
    -- Character Logs, the wishlist and anyone else who cares.
    ns.Fire("BOSS_KILLED", ourName, encounterName, P.here.name, P.here.map)
    -- Remember where the boss died, so the map can place it even when the game can't.
    if ns.DMap and encounterName and P.here.name then
        local m, x, y = P.myFloor()
        if m then
            ns.DMap.LearnFloor(P.here.name, m)
            if x then ns.DMap.LearnPin(P.here.name, encounterName, m, x, y) end
        end
    end
    -- Learn boss order for dungeons our database doesn't know (Forever's new ones).
    if not ns.DB.dungeons[P.here.map] and encounterName and P.here.name then
        ns.db.learnedBosses = ns.db.learnedBosses or {}
        local key = ns.Data.Normalize(P.here.name)
        local list = ns.db.learnedBosses[key] or {}
        local known = false
        for _, n in ipairs(list) do if n == encounterName then known = true end end
        if not known then tinsert(list, encounterName) end
        ns.db.learnedBosses[key] = list
    end
    updateSoon()
    ns.Fire("TRACKER_CHANGED")
end

ns.On("PLAYER_ENTERING_WORLD", function() ns.After(1, whereAmI) end)
ns.On("ZONE_CHANGED_NEW_AREA", function() ns.After(1, whereAmI) end)
-- Walking between floors inside a dungeon.
local function floorChanged()
    if P.here.map and P.here.name and ns.DMap then ns.DMap.LearnFloor(P.here.name, (P.myFloor())) end
end
ns.On("ZONE_CHANGED_INDOORS", floorChanged)
ns.On("ZONE_CHANGED", floorChanged)
ns.On("ENCOUNTER_END", function(encounterID, encounterName, _, _, success)
    if ns.Safe(success) == 1 then onKill(encounterID, encounterName) end
end)
ns.On("BOSS_KILL", onKill)
ns.On("QUEST_LOG_UPDATE", updateSoon)
ns.Listen("QUESTS_CHANGED", updateSoon)

function T.SetEnabled(on)
    ns.opt.tracker = on and true or false
    T.Update()
end

-- The run timer at the right of the header: how long this run has taken, and your best.
function T.UpdateTimer()
    if not (P.frame and P.frame:IsShown()) then return end
    local h = P.frame.header
    if not h.timer then
        h.timer = h:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        h.timer:SetPoint("RIGHT", h.toggle, "LEFT", -6, 0)
        h.text:SetPoint("RIGHT", h.timer, "LEFT", -6, 0)
    end
    local RL = ns.RunLog
    local run = RL and RL.Active()
    if not (run and not run.leftAt) then h.timer:SetText("") return end
    local t = (run.doneAt or ns.Now()) - run.start
    local best = RL.Best(RL.Label(run))
    local color = run.done and "|cff40ff40" or (best and t > best and "|cffff8040" or "|cffffffff")
    h.timer:SetText(color .. RL.Duration(t) .. "|r" .. (best and ("  " .. GRAY_FONT_COLOR:WrapTextInColorCode(L.RUN_BEST:format(RL.Duration(best)))) or ""))
end
if C_Timer and C_Timer.NewTicker then
    ns.Listen("LOGIN", function() C_Timer.NewTicker(1, function() T.UpdateTimer() end) end)
end
ns.Listen("RUNLOG_CHANGED", function() T.UpdateTimer() end)

