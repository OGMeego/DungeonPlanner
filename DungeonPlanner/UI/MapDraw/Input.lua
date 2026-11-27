-- Input.lua
-- Mouse input on the map.
local _, ns = ...
local L = ns.L
local MD = ns.MapDraw
local DRAW_W = 3
local MIN_SEG = 0.008
local P = ns.Private("MapDraw")

-- ---------------------------------------------------------------------------
-- Input
-- ---------------------------------------------------------------------------

local function eraseAt(x, y)
    local d = P.data(false)
    if not (d and x) then return end
    local R2 = 0.02 * 0.02
    for i = #d.strokes, 1, -1 do
        local pts = d.strokes[i].pts
        for j = 1, #pts, 2 do
            if (pts[j] - x) ^ 2 + (pts[j + 1] - y) ^ 2 <= R2 then
                table.remove(d.strokes, i)
                P.render()
                return true
            end
        end
    end
end

function P.finishStroke()
    if P.drawingNow and P.mode == "draw" and P.stroke and #P.stroke >= 4 then
        local d = P.data(true)
        tinsert(d.strokes, { pts = P.simplify(P.stroke, 0.004), color = { P.color[1], P.color[2], P.color[3] }, w = DRAW_W })
    end
    P.drawingNow, P.stroke = false, nil
    P.render()
end
MD.FinishStroke = P.finishStroke

local function askText(x, y)
    StaticPopupDialogs["DUNGEONPLANNER_MAPTEXT"] = StaticPopupDialogs["DUNGEONPLANNER_MAPTEXT"] or {
        text = L.DRAW_TEXT_PROMPT, button1 = OKAY or "OK", button2 = CANCEL or "Cancel",
        hasEditBox = true, maxLetters = 60, timeout = 0, whileDead = true, hideOnEscape = true,
        OnAccept = function(self, pos)
            local eb = self.editBox or self.EditBox
            local txt = eb and strtrim(eb:GetText() or "") or ""
            if txt ~= "" and pos then
                local d = P.data(true)
                tinsert(d.texts, { text = txt:gsub("[\t\n|]", " "), x = pos.x, y = pos.y, size = 14, color = { P.color[1], P.color[2], P.color[3] } })
                P.render()
            end
        end,
        EditBoxOnEnterPressed = function(eb)
            local p = eb:GetParent()
            if p and p.button1 then p.button1:Click() end
        end,
    }
    StaticPopup_Show("DUNGEONPLANNER_MAPTEXT", nil, nil, { x = x, y = y })
end

function P.onMouseDown(_, button)
    if button ~= "LeftButton" or not P.mode then return end
    local x, y = P.cursorNorm()
    if not x then return end
    if P.mode == "draw" then
        P.drawingNow, P.stroke = true, { x, y }
    elseif P.mode == "erase" then
        P.drawingNow = true
        eraseAt(x, y)
    elseif P.mode == "text" then
        askText(x, y)
    elseif type(P.mode) == "number" then
        local d = P.data(true)
        tinsert(d.markers, { i = P.mode, x = x, y = y, size = 26 })
        P.render()
    end
end

function P.onUpdate()
    if not P.drawingNow then return end
    if not IsMouseButtonDown("LeftButton") then return P.finishStroke() end
    local x, y = P.cursorNorm()
    if not x then return end
    if P.mode == "erase" then eraseAt(x, y) return end
    local n = #P.stroke
    if (x - P.stroke[n - 1]) ^ 2 + (y - P.stroke[n]) ^ 2 >= MIN_SEG * MIN_SEG then
        P.stroke[n + 1], P.stroke[n + 2] = x, y
        P.renderStrokes()
    end
end
