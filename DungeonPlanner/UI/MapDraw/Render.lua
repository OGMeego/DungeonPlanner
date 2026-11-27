-- Render.lua
-- Drawing strokes, markers and text on the map.
local _, ns = ...
local L = ns.L
local MD = ns.MapDraw
local DRAW_W = 3
local MARKER_TEX = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_"
local P = ns.Private("MapDraw")

-- ---------------------------------------------------------------------------
-- Rendering
-- ---------------------------------------------------------------------------

function P.cursorNorm()
    if not (P.art and P.art:GetLeft()) then return nil end
    local sc = P.art:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    cx, cy = cx / sc, cy / sc
    local w, h = P.art:GetWidth(), P.art:GetHeight()
    if not (w and w > 0) then return nil end
    return P.clamp01((cx - P.art:GetLeft()) / w), P.clamp01((P.art:GetTop() - cy) / h)
end
MD.CursorNorm = P.cursorNorm

local function getLine(i)
    local ln = P.lines[i]
    if not ln then
        ln = P.ink:CreateLine(nil, "OVERLAY")
        P.lines[i] = ln
    end
    return ln
end

function P.renderStrokes()
    local d = P.data(false)
    local w, h = P.art:GetWidth(), P.art:GetHeight()
    local n = 0
    local function draw(pts, c, thick)
        for j = 1, #pts - 3, 2 do
            n = n + 1
            local ln = getLine(n)
            ln:SetThickness(thick or DRAW_W)
            ln:SetColorTexture(c[1], c[2], c[3], 1)
            ln:SetStartPoint("TOPLEFT", P.art, pts[j] * w, -pts[j + 1] * h)
            ln:SetEndPoint("TOPLEFT", P.art, pts[j + 2] * w, -pts[j + 3] * h)
            ln:Show()
        end
    end
    for _, s in ipairs(d and d.strokes or {}) do draw(s.pts, s.color or P.COLORS[1], s.w) end
    if P.drawingNow and P.stroke and #P.stroke >= 4 then draw(P.stroke, P.color, DRAW_W) end
    for i = n + 1, #P.lines do P.lines[i]:Hide() end
end

local function relativeCenter(f)
    local cx, cy = f:GetCenter()
    local w, h = P.art:GetWidth(), P.art:GetHeight()
    if not (cx and w and w > 0) then return 0.5, 0.5 end
    return P.clamp01((cx - P.art:GetLeft()) / w), P.clamp01((P.art:GetTop() - cy) / h)
end

P.render = nil
local function newMovable(pool, i, isText)
    local f = pool[i]
    if f then return f end
    f = CreateFrame("Button", nil, P.ink)
    f:SetMovable(true)
    f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    f:EnableMouseWheel(true)
    if isText then
        f.fs = f:CreateFontString(nil, "OVERLAY")
        f.fs:SetPoint("CENTER")
    else
        f.icon = f:CreateTexture(nil, "ARTWORK")
        f.icon:SetAllPoints()
    end
    f:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            P.mode = nil
            self:StartMoving()
            self.moving = true
        end
    end)
    f:SetScript("OnMouseUp", function(self, button)
        local d = P.data(true)
        local list = isText and d.texts or d.markers
        local item = list[self.index]
        if self.moving then
            self:StopMovingOrSizing()
            self.moving = false
            if item then item.x, item.y = relativeCenter(self) end
        elseif button == "RightButton" and item then
            table.remove(list, self.index)
        end
        P.render()
    end)
    f:SetScript("OnMouseWheel", function(self, delta)
        local d = P.data(true)
        local item = (isText and d.texts or d.markers)[self.index]
        if not item then return end
        if isText then item.size = math.max(10, math.min(30, (item.size or 14) + delta * 2))
        else item.size = math.max(14, math.min(64, (item.size or 26) + delta * 4)) end
        P.render()
    end)
    f:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.DRAW_ITEM_TIP, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", GameTooltip_Hide)
    pool[i] = f
    return f
end

local function renderMarkers()
    local d = P.data(false)
    local w, h = P.art:GetWidth(), P.art:GetHeight()
    local list = d and d.markers or {}
    for i, m in ipairs(list) do
        local f = newMovable(P.markerFrames, i, false)
        f.index = i
        f:SetSize(m.size or 26, m.size or 26)
        f.icon:SetTexture(MARKER_TEX .. m.i)
        f:ClearAllPoints()
        f:SetPoint("CENTER", P.art, "TOPLEFT", m.x * w, -m.y * h)
        f:SetFrameLevel(P.ink:GetFrameLevel() + 2 + i)
        f:Show()
    end
    for i = #list + 1, #P.markerFrames do P.markerFrames[i]:Hide() end
end

local function renderTexts()
    local d = P.data(false)
    local w, h = P.art:GetWidth(), P.art:GetHeight()
    local list = d and d.texts or {}
    for i, t in ipairs(list) do
        local f = newMovable(P.textFrames, i, true)
        f.index = i
        f.fs:SetFont(STANDARD_TEXT_FONT, t.size or 14, "OUTLINE")
        f.fs:SetText(t.text or "")
        local c = t.color or { 1, 0.95, 0.6 }
        f.fs:SetTextColor(c[1], c[2], c[3])
        f:SetSize(math.max(14, (f.fs:GetStringWidth() or 0) + 8), math.max(12, (f.fs:GetStringHeight() or 0) + 4))
        f:ClearAllPoints()
        f:SetPoint("CENTER", P.art, "TOPLEFT", t.x * w, -t.y * h)
        f:SetFrameLevel(P.ink:GetFrameLevel() + 60 + i)
        f:Show()
    end
    for i = #list + 1, #P.textFrames do P.textFrames[i]:Hide() end
end

local function updateBar()
    if not P.bar then return end
    P.bar.draw:SetText(P.mode == "draw" and ("|cff40ff40" .. L.DRAW_DRAW .. "|r") or L.DRAW_DRAW)
    P.bar.erase:SetText(P.mode == "erase" and ("|cffff6060" .. L.DRAW_ERASE .. "|r") or L.DRAW_ERASE)
    P.bar.text:SetText(P.mode == "text" and ("|cff40ff40" .. L.DRAW_TEXT .. "|r") or L.DRAW_TEXT)
    for i, b in ipairs(P.bar.markers) do b.sel:SetShown(P.mode == i) end
    for _, s in ipairs(P.bar.swatches) do s.sel:SetShown(s.col == P.color) end
    P.ink:EnableMouse(P.mode ~= nil)
end

P.render = function()
    if not (P.art and P.ink and P.ink:IsShown()) then return end
    P.renderStrokes()
    renderMarkers()
    renderTexts()
    updateBar()
end
MD.Render = P.render
