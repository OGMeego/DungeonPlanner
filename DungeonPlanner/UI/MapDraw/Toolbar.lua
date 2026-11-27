-- Toolbar.lua
-- The drawing toolbar.
local _, ns = ...
local L = ns.L
local MD = ns.MapDraw
local MARKER_TEX = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_"
local P = ns.Private("MapDraw")

-- ---------------------------------------------------------------------------
-- Toolbar
-- ---------------------------------------------------------------------------

local function button(parent, text, w)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, 20)
    b:SetText(text)
    return b
end

local function setMode(m)
    if P.mode == m then P.mode = nil else P.mode = m end
    P.drawingNow, P.stroke = false, nil
    P.render()
end

local function buildBar(parent)
    P.bar = CreateFrame("Frame", nil, parent)
    P.bar:SetHeight(22)
    local x = 0
    local function place(f, w) f:SetPoint("LEFT", P.bar, "LEFT", x, 0); x = x + w + 4 end
    P.bar.draw = button(P.bar, L.DRAW_DRAW, 44); place(P.bar.draw, 44)
    P.bar.draw:SetScript("OnClick", function() setMode("draw") end)
    P.bar.erase = button(P.bar, L.DRAW_ERASE, 46); place(P.bar.erase, 46)
    P.bar.erase:SetScript("OnClick", function() setMode("erase") end)
    P.bar.text = button(P.bar, L.DRAW_TEXT, 40); place(P.bar.text, 40)
    P.bar.text:SetScript("OnClick", function() setMode("text") end)
    x = x + 2
    P.bar.swatches = {}
    for _, c in ipairs(P.COLORS) do
        local s = CreateFrame("Button", nil, P.bar)
        s:SetSize(14, 14)
        local t = s:CreateTexture(nil, "ARTWORK"); t:SetAllPoints(); t:SetColorTexture(c[1], c[2], c[3], 1)
        s.sel = s:CreateTexture(nil, "BACKGROUND"); s.sel:SetPoint("TOPLEFT", -2, 2); s.sel:SetPoint("BOTTOMRIGHT", 2, -2)
        s.sel:SetColorTexture(1, 1, 1, 0.9)
        s.col = c
        s:SetScript("OnClick", function() P.color = c; if P.mode ~= "text" then P.mode = "draw" end; P.render() end)
        place(s, 14)
        tinsert(P.bar.swatches, s)
    end
    x = x + 4
    P.bar.markers = {}
    for i = 1, 8 do
        local m = CreateFrame("Button", nil, P.bar)
        m:SetSize(16, 16)
        local t = m:CreateTexture(nil, "ARTWORK"); t:SetAllPoints(); t:SetTexture(MARKER_TEX .. i)
        m.sel = m:CreateTexture(nil, "BACKGROUND"); m.sel:SetPoint("TOPLEFT", -2, 2); m.sel:SetPoint("BOTTOMRIGHT", 2, -2)
        m.sel:SetColorTexture(1, 0.82, 0, 0.8)
        m:SetScript("OnClick", function() setMode(i) end)
        m:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(L.DRAW_MARKER_TIP, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        m:SetScript("OnLeave", GameTooltip_Hide)
        place(m, 16)
        tinsert(P.bar.markers, m)
    end
    x = x + 4
    P.bar.undo = button(P.bar, L.DRAW_UNDO, 44); place(P.bar.undo, 44)
    P.bar.undo:SetScript("OnClick", function()
        local d = P.data(false)
        if d and #d.strokes > 0 then table.remove(d.strokes) end
        P.render()
    end)
    P.bar.clear = button(P.bar, L.DRAW_CLEAR, 44); place(P.bar.clear, 44)
    P.bar.clear:SetScript("OnClick", function()
        if ns.db.mapDraw then ns.db.mapDraw[P.key] = nil end
        P.render()
    end)
    P.bar.share = button(P.bar, L.DRAW_SHARE, 52); place(P.bar.share, 52)
    P.bar.share:SetScript("OnClick", function() MD.Share() end)
    P.bar:SetWidth(x)
    -- Pull plans: top right of the map.
    P.bar.plans = button(parent, L.PLAN_BUTTON, 70)
    P.bar.plans:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, -8)
    P.bar.plans:SetScript("OnClick", function(self) MD.PlansMenu(self) end)
    P.bar.plans:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(L.PLAN_TITLE, 1, 1, 1)
        GameTooltip:AddLine(L.PLAN_TIP, 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    P.bar.plans:SetScript("OnLeave", GameTooltip_Hide)
    return P.bar
end

-- Called by the map after drawing a floor: the picture frame and which drawing to show.
function MD.Attach(canvasFrame, artFrame, drawKey)
    P.art, P.key = artFrame, drawKey
    if not P.ink then
        P.ink = CreateFrame("Frame", nil, canvasFrame)
        P.ink:SetScript("OnMouseDown", P.onMouseDown)
        P.ink:SetScript("OnMouseUp", function() if P.drawingNow then P.finishStroke() end end)
        P.ink:SetScript("OnUpdate", P.onUpdate)
        buildBar(canvasFrame)
        P.bar:SetPoint("BOTTOM", canvasFrame, "BOTTOM", 0, 8)
    end
    P.ink:SetParent(canvasFrame)
    P.ink:ClearAllPoints()
    P.ink:SetAllPoints(P.art)
    P.ink:SetFrameLevel(P.art:GetFrameLevel() + 30)
    P.bar:SetFrameLevel(canvasFrame:GetFrameLevel() + 40)
    P.ink:Show()
    P.bar:Show()
    P.bar.plans:SetFrameLevel(canvasFrame:GetFrameLevel() + 40)
    P.bar.plans:Show()
    P.render()
end

function MD.Hide()
    if P.ink then P.ink:Hide() end
    if P.bar then P.bar:Hide(); P.bar.plans:Hide() end
    for _, f in ipairs(P.markerFrames) do f:Hide() end
    for _, f in ipairs(P.textFrames) do f:Hide() end
    P.mode, P.drawingNow, P.stroke = nil, false, nil
end

function MD.Key() return P.key end
function MD.SetMode(m) P.mode = m; if P.ink then P.render() end end
function MD.Data() return P.data(false) end
