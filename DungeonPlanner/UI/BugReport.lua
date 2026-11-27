-- BugReport.lua
-- /dp bug (or the button in Settings): a window with everything we'd want to know about a
-- problem, selected and ready to copy (Ctrl+C) into a bug report. Lua errors from Dungeon
-- Planner are remembered for this window (only ours, the last few, this session).
local _, ns = ...
local L = ns.L
local B = {}
ns.BugReport = B

B.errors = {}

-- Remember our own errors, then let the game handle them as usual.
local function hookErrors()
    if not (geterrorhandler and seterrorhandler) or B.hooked then return end
    B.hooked = true
    local prev = geterrorhandler()
    seterrorhandler(function(msg, ...)
        if type(msg) == "string" and msg:find("DungeonPlanner", 1, true) then
            if #B.errors >= 5 then table.remove(B.errors, 1) end
            B.errors[#B.errors + 1] = msg
        end
        if prev then return prev(msg, ...) end
    end)
end
ns.Listen("LOGIN", hookErrors)

local function line(t, k, v) t[#t + 1] = k .. ": " .. tostring(v) end

function B.Text()
    local t = {}
    local D = ns.Data
    line(t, "Dungeon Planner", ns.VERSION)
    local ver, build, _, toc = (GetBuildInfo and GetBuildInfo())
    line(t, "Game", ("%s (%s) toc %s"):format(tostring(ver), tostring(build), tostring(toc)))
    line(t, "Language", GetLocale and GetLocale() or "?")
    line(t, "Character", ("%s level %s %s"):format(tostring(UnitFactionGroup and UnitFactionGroup("player")),
        tostring(D.MyLevel()), tostring(D.MyClass())))
    local m = C_Map and C_Map.GetBestMapForUnit and ns.Call(C_Map.GetBestMapForUnit, "player")
    local pos = m and ns.Call(C_Map.GetPlayerMapPosition, m, "player")
    local x, y = pos and pos.GetXY and pos:GetXY()
    line(t, "Where", ("%s map %s at %s, %s"):format(tostring(D.MyZone()), tostring(m),
        x and ("%.1f"):format(x * 100) or "?", y and ("%.1f"):format(y * 100) or "?"))
    local inInst, kind = IsInInstance and IsInInstance()
    line(t, "In instance", tostring(inInst) .. " " .. tostring(kind))
    local o = ns.opt or {}
    line(t, "Settings", ("avoidDanger=%s pathDots=%s partyShare=%s tracker=%s questTooltips=%s"):format(
        tostring(o.avoidDanger ~= false), tostring(o.pathDots ~= false), tostring(o.partyShare),
        tostring(o.tracker), tostring(o.questTooltips ~= false)))
    -- the arrow's trip
    local NavP = ns.Private and ns.Private("Nav")
    local r = NavP and NavP.route
    if r and r.steps then
        local s = {}
        for i, st in ipairs(r.steps) do
            local tg = st.target
            s[#s + 1] = ("%d%s%s %s"):format(i, i == r.index and ">" or ".", tostring(st.kind), tg and (tg.name or tg.label or "") or "")
        end
        line(t, "Guide", (r.goal and r.goal.label or "?") .. " | " .. table.concat(s, " | "))
    else
        line(t, "Guide", "off")
    end
    local me = ns.Nav and ns.Nav.PlayerPos and ns.Nav.PlayerPos()
    local fl = me and ns.cdb and ns.cdb.flights and ns.cdb.flights[me.cont]
    if fl then
        local names = {}
        for k in pairs(fl) do if k:sub(1, 1) ~= "_" then names[#names + 1] = k end end
        table.sort(names)
        line(t, "Flight paths", table.concat(names, ", "))
    end
    if ns.SecretsSvc and ns.SecretsSvc.Guided then
        local g = ns.SecretsSvc.Guided()
        if g then line(t, "Secret", tostring(g)) end
    end
    line(t, "Group channel", tostring(ns.Comm and ns.Comm.GroupChannel and ns.Comm.GroupChannel() or "-"))
    local addons = {}
    local n = (C_AddOns and C_AddOns.GetNumAddOns and C_AddOns.GetNumAddOns()) or (GetNumAddOns and GetNumAddOns()) or 0
    for i = 1, n do
        local name = (C_AddOns and C_AddOns.GetAddOnInfo and C_AddOns.GetAddOnInfo(i)) or (GetAddOnInfo and GetAddOnInfo(i))
        local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(i)) or (IsAddOnLoaded and IsAddOnLoaded(i))
        if name and loaded then addons[#addons + 1] = name end
    end
    line(t, "Other addons", #addons > 0 and table.concat(addons, ", ") or "-")
    if #B.errors > 0 then
        t[#t + 1] = "Errors:"
        for _, e in ipairs(B.errors) do t[#t + 1] = "  " .. e end
    else
        line(t, "Errors", "none this session")
    end
    t[#t + 1] = ""
    t[#t + 1] = "What happened, and what did you expect?"
    t[#t + 1] = ""
    return table.concat(t, "\n")
end

local frame
function B.Show()
    if not frame then
        frame = CreateFrame("Frame", "DungeonPlannerBugReport", UIParent, "BasicFrameTemplateWithInset")
        frame:SetSize(560, 400)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("DIALOG")
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
        tinsert(UISpecialFrames, "DungeonPlannerBugReport")
        local title = frame.TitleText or frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        if not frame.TitleText then title:SetPoint("TOP", 0, -5) end
        title:SetText(L.BUG_TITLE)
        local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        hint:SetPoint("TOPLEFT", 14, -30)
        hint:SetPoint("RIGHT", -14, 0)
        hint:SetJustifyH("LEFT")
        hint:SetText(L.BUG_HINT)
        local ok, scroll = pcall(CreateFrame, "ScrollFrame", nil, frame, "ScrollFrameTemplate")
        if not ok or not scroll then scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate") end
        scroll:SetPoint("TOPLEFT", 14, -52)
        scroll:SetPoint("BOTTOMRIGHT", -32, 12)
        local edit = CreateFrame("EditBox", nil, scroll)
        edit:SetMultiLine(true)
        edit:SetAutoFocus(false)
        edit:SetFontObject(ChatFontNormal)
        edit:SetWidth(500)
        edit:SetScript("OnEscapePressed", function() frame:Hide() end)
        scroll:SetScrollChild(edit)
        frame.edit = edit
    end
    frame.edit:SetText(B.Text())
    frame:Show()
    frame.edit:SetFocus()
    frame.edit:HighlightText()
end
