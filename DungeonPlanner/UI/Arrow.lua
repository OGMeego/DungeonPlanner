-- Arrow.lua
-- The arrow and the list of steps.
local _, ns = ...
local L = ns.L
local Nav = ns.Nav
local P = ns.Private("Nav")

-- ---------------------------------------------------------------------------
-- The arrow (and the list of steps)
-- ---------------------------------------------------------------------------

P.route = nil         -- { steps, index, label, goal }
P.arrow, P.list = nil
local calib = {}    -- uiMapID -> { ex, ey, nx, ny } unit vectors for east and north in world space

local function axes(uiMapID)
    local c = calib[uiMapID]
    if c then return c end
    local o, e, n = P.worldPos(uiMapID, 50, 50), P.worldPos(uiMapID, 60, 50), P.worldPos(uiMapID, 50, 40)
    if not (o and e and n) then return nil end
    local ex, ey = e.x - o.x, e.y - o.y
    local nx, ny = n.x - o.x, n.y - o.y
    local el, nl = math.sqrt(ex * ex + ey * ey), math.sqrt(nx * nx + ny * ny)
    if el == 0 or nl == 0 then return nil end
    c = { ex = ex / el, ey = ey / el, nx = nx / nl, ny = ny / nl }
    calib[uiMapID] = c
    return c
end

-- Angle of the target relative to where you face (radians, counterclockwise), or nil.
local function relativeAngle(me, target)
    local a = axes(me.map)
    if not a then return nil end
    local dx, dy = target.x - me.x, target.y - me.y
    local east = dx * a.ex + dy * a.ey
    local north = dx * a.nx + dy * a.ny
    local bearing = math.atan2(-east, north)   -- counterclockwise from north, like GetPlayerFacing
    local facing = ns.Safe(ns.Call(GetPlayerFacing))
    if not facing then return nil, bearing end
    return bearing - facing, bearing
end

local COMPASS = { "N", "NW", "W", "SW", "S", "SE", "E", "NE" }
local function compassText(bearing)
    local i = floor(((bearing % (2 * math.pi)) / (2 * math.pi)) * 8 + 0.5) % 8 + 1
    return L["NAV_DIR_" .. COMPASS[i]] or COMPASS[i]
end

function P.timeText(seconds)
    if seconds < 60 then return L.NAV_UNDER_MINUTE end
    return L.NAV_MINUTES:format(floor(seconds / 60 + 0.5))
end

local function showList()
    if not P.list then
        P.list = CreateFrame("Frame", nil, P.arrow, "TooltipBackdropTemplate")
        P.list:SetPoint("TOP", P.arrow, "BOTTOM", 0, -4)
        P.list:SetWidth(280)
        P.list.lines = {}
    end
    for _, l in ipairs(P.list.lines) do l:Hide() end
    local y = -10
    for i, s in ipairs(P.route.steps) do
        local fs = P.list.lines[i]
        if not fs then
            fs = P.list:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            fs:SetJustifyH("LEFT")
            fs:SetWidth(256)
            fs:SetWordWrap(true)
            P.list.lines[i] = fs
        end
        local mark = i < P.route.index and ns.AtlasMarkup("common-icon-checkmark", 12) or (i == P.route.index and "|cffffd100>|r" or "  ")
        fs:SetText(("%s %d. %s"):format(mark, i, s.text))
        if i < P.route.index then fs:SetTextColor(0.5, 0.5, 0.5) elseif i == P.route.index then fs:SetTextColor(1, 0.82, 0) else fs:SetTextColor(1, 1, 1) end
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", 12, y)
        fs:Show()
        y = y - fs:GetStringHeight() - 4
    end
    P.list:SetHeight(-y + 8)
    P.list:Show()
end

local function menu(owner)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(P.route and P.route.label or L.ADDON_TITLE)
        root:CreateButton(L.NAV_SHOW_STEPS, function() if P.list and P.list:IsShown() then P.list:Hide() else showList() end end)
        root:CreateButton(L.NAV_SKIP, function() Nav.Advance() end)
        root:CreateButton(L.NAV_BACK, function() if P.route and P.route.index > 1 then P.route.index = P.route.index - 1 Nav.Update(true) end end)
        root:CreateButton(L.NAV_REPLAN, function() Nav.Replan() end)
        root:CreateDivider()
        root:CreateButton(L.NAV_STOP, function() Nav.Stop(true) end)
    end)
end

function P.createArrow()
    local f = CreateFrame("Button", "DungeonPlannerArrow", UIParent)
    f:SetSize(240, 128)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint(1)
        ns.cdb.arrowPos = { p, rp, x, y }
    end)
    local pos = ns.cdb.arrowPos
    if pos then f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else f:SetPoint("TOP", UIParent, "TOP", 0, -140) end

    f.arrow = f:CreateTexture(nil, "ARTWORK")
    f.arrow:SetSize(56, 56)
    f.arrow:SetPoint("TOP", 0, -2)
    if not ns.SetAtlas(f.arrow, "Navigation-Tracked-Arrow") then
        f.arrow:SetTexture("Interface\\Minimap\\MinimapArrow")
    end
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(40, 40)
    f.icon:SetPoint("CENTER", f.arrow, "CENTER")
    f.icon:Hide()

    -- Only the step and the distance show under the arrow; the step number and the longer
    -- hint are in the tooltip, so the arrow stays clean.
    f.step = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.step:Hide()
    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.text:SetPoint("TOP", f.arrow, "BOTTOM", 0, -2)
    f.text:SetWidth(236)
    f.text:SetWordWrap(true)
    f.dist = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.dist:SetPoint("TOP", f.text, "BOTTOM", 0, -2)
    f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.hint:SetPoint("TOP", f.dist, "BOTTOM", 0, -2)
    f.hint:SetWidth(236)
    f.hint:SetWordWrap(true)
    f.hint:Hide()

    f.close = CreateFrame("Button", nil, f, "UIPanelCloseButtonNoScripts")
    f.close:SetSize(20, 20)
    f.close:SetPoint("TOPRIGHT", 0, 0)
    f.close:SetScript("OnClick", function() Nav.Stop(true) end)

    f:SetScript("OnClick", function(self, button)
        if button == "RightButton" then menu(self) return end
        if P.list and P.list:IsShown() then P.list:Hide() else showList() end
    end)
    f:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(P.route and P.route.label or "", 1, 1, 1)
        local s = P.route and P.route.steps[P.route.index]
        if s then
            GameTooltip:AddLine(L.NAV_STEP:format(P.route.index, #P.route.steps), 0.8, 0.8, 0.8)
            if s.hint and s.hint ~= "" then GameTooltip:AddLine(s.hint, 1, 1, 1, true) end
        end
        GameTooltip:AddLine(L.NAV_TOOLTIP, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, true)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", GameTooltip_Hide)
    f:Hide()
    return f
end

local STEP_ICONS = { fly = "Interface\\Icons\\Ability_Mount_Wyvern_01", ride = "Interface\\Icons\\INV_Misc_Spyglass_02",
    hearth = "Interface\\Icons\\INV_Misc_Rune_01" }

local function pinStep(s)
    if s.target and s.target.map and C_Map and C_Map.SetUserWaypoint and UiMapPoint then
        pcall(C_Map.SetUserWaypoint, UiMapPoint.CreateFromCoordinates(s.target.map, s.target.mx / 100, s.target.my / 100))
    end
end

function Nav.Update(stepChanged)
    if not (P.route and P.arrow) then return end
    local s = P.route.steps[P.route.index]
    if not s then return Nav.Arrived() end
    if stepChanged then pinStep(s) end
    P.arrow.step:SetText(L.NAV_STEP:format(P.route.index, #P.route.steps))
    P.arrow.text:SetText(s.text)
    P.arrow.hint:SetText(s.hint or "")

    local me = Nav.PlayerPos()
    local onTaxi = ns.Call(UnitOnTaxi, "player")
    if onTaxi or not me then
        P.arrow.arrow:Hide()
        P.arrow.icon:SetTexture(onTaxi and STEP_ICONS.fly or "Interface\\Icons\\INV_Misc_QuestionMark")
        P.arrow.icon:Show()
        P.arrow.dist:SetText(onTaxi and L.NAV_IN_FLIGHT or L.NAV_NO_POSITION)
        if not me then return end
    end
    local d = P.dist(me, s.target)
    if d <= (s.radius or 25) then return Nav.Advance() end
    -- Already at a later step's spot (you took a shortcut): carry on from there.
    for i = P.route.index + 1, math.min(#P.route.steps, P.route.index + 3) do
        local t = P.route.steps[i]
        if t.kind == "walk" and t.target and P.dist(me, t.target) <= (t.radius or 25) then
            P.route.index = i
            return Nav.Advance()
        end
    end
    -- Boat/zeppelin/flight steps finish when you arrive near the far end.
    if onTaxi then return end
    if d == math.huge and s.kind == "walk" then
        -- A walking step on another continent: you crossed some other way (your own boat or
        -- zeppelin). Jump to the first later step on this continent, or plan again from here.
        for i = P.route.index + 1, #P.route.steps do
            local t = P.route.steps[i].target
            if t and t.cont == me.cont then
                P.route.index = i
                return Nav.Update(true)
            end
        end
        local now = GetTime()
        if P.route.goal and now - (P.lastCrossReplan or 0) > 5 then
            P.lastCrossReplan = now
            return Nav.Replan()
        end
    end
    if d == math.huge then
        P.arrow.arrow:Hide()
        P.arrow.icon:SetTexture(STEP_ICONS[s.kind] or "Interface\\Icons\\INV_Misc_QuestionMark")
        P.arrow.icon:Show()
        P.arrow.dist:SetText(L.NAV_OTHER_CONTINENT)
        return
    end
    P.arrow.icon:Hide()
    -- Along the walking network: aim at the next corner of the way, not straight at the end.
    local aim = s.target
    if s.path and #s.path > 1 then
        local pi = s.pi or 1
        -- Jump ahead to the closest of the next few corners (you may have cut a corner).
        local best, bestD = pi, P.dist(me, s.path[pi])
        for j = pi + 1, math.min(#s.path, pi + 6) do
            local dj = P.dist(me, s.path[j])
            if dj < bestD then best, bestD = j, dj end
        end
        pi = best
        if bestD < (s.trail and 30 or 15) and pi < #s.path then pi = pi + 1 end
        s.pi = pi
        aim = s.path[pi]
        local rest = P.dist(me, aim)
        for j = pi, #s.path - 1 do rest = rest + P.dist(s.path[j], s.path[j + 1]) end
        if rest < math.huge then d = rest end
    end
    local rel, bearing = relativeAngle(me, aim)
    if rel then
        P.arrow.arrow:SetRotation(rel)
        P.arrow.arrow:Show()
        -- Green when you're facing the right way.
        local off = math.abs(((rel + math.pi) % (2 * math.pi)) - math.pi)
        -- On a trail you can wander a little off the line and it stays green.
        local ok = s.trail and 0.8 or 0.35
        if off < ok then P.arrow.arrow:SetVertexColor(0.3, 1, 0.3) else P.arrow.arrow:SetVertexColor(1, 0.82, 0) end
    else
        P.arrow.arrow:Hide()
    end
    local dirText = (not rel and bearing) and ("  " .. compassText(bearing)) or ""
    P.arrow.dist:SetText(L.NAV_DISTANCE:format(floor(d + 0.5), P.timeText(d / P.runSpeed())) .. dirText)
end

function Nav.Advance()
    if not P.route then return end
    P.route.index = P.route.index + 1
    if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) end
    if P.route.index > #P.route.steps then return Nav.Arrived() end
    if P.list and P.list:IsShown() then showList() end
    Nav.Update(true)
end

function Nav.Arrived()
    if not P.route then return end
    ns.Print(L.NAV_ARRIVED:format(P.route.label))
    if Nav.follow then ns.Print(L.NAV_TALK) end
    if SOUNDKIT and SOUNDKIT.READY_CHECK then PlaySound(SOUNDKIT.READY_CHECK) end
    Nav.Stop()
end

-- byUser: the player closed the guide, so stop following a quest chain too.
function Nav.Stop(byUser)
    if byUser then
        Nav.follow = nil
        if ns.cdb then ns.cdb.navFollow = nil end
    end
    if ns.cdb then ns.cdb.navGoal = nil end
    if byUser and ns.cdb then ns.cdb.navDungeon = nil end
    P.route = nil
    if P.arrow then P.arrow:Hide() end
    if P.list then P.list:Hide() end
end

function Nav.IsActive() return P.route ~= nil end
