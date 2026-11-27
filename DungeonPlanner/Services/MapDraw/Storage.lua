-- MapDraw: draw on the dungeon maps and share the drawing with your group (same idea as the
-- Raid Assignment Manager's map page). Tools: Draw (freehand, 5 colours), Erase (removes a
-- whole stroke), Text (a label you type), and the 8 raid markers. Markers and labels can be
-- dragged, resized with the mouse wheel, and removed with a right-click. Every dungeon floor
-- keeps its own drawing (saved), and Share sends it to your party or raid; anyone with
-- Dungeon Planner gets it on the same map.
local _, ns = ...
local P = ns.Private("MapDraw")
local L = ns.L

local MD = {}
ns.MapDraw = MD

local PREFIX = "DPMap"
local CHUNK = 230
local PACE = 0.06
local DRAW_W = 3
local MIN_SEG = 0.008
P.COLORS = {
    { 1.00, 0.85, 0.20 }, { 0.95, 0.25, 0.25 }, { 0.35, 0.85, 0.45 }, { 0.35, 0.62, 1.00 }, { 1, 1, 1 },
}
local MARKER_TEX = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_"

P.mode = nil            -- nil | "draw" | "erase" | "text" | marker index 1-8
P.color = P.COLORS[1]
P.art, P.key = nil        -- the map picture frame and the drawing's key (dungeon + floor)
P.ink, P.bar = nil        -- input overlay, toolbar
P.lines, P.markerFrames, P.textFrames = {}, {}, {}
P.stroke, P.drawingNow = nil

-- ---------------------------------------------------------------------------
-- Storage: ns.db.mapDraw[key] = { strokes = { { pts, color, w } }, markers = { { i, x, y, size } },
--                                 texts = { { text, x, y, size, color } } }
-- ---------------------------------------------------------------------------

function P.data(create)
    if not P.key then return nil end
    ns.db.mapDraw = ns.db.mapDraw or {}
    local d = ns.db.mapDraw[P.key]
    if not d and create then
        d = { strokes = {}, markers = {}, texts = {} }
        ns.db.mapDraw[P.key] = d
    end
    return d
end

function P.clamp01(v) return math.max(0, math.min(1, v)) end

-- Thin a freehand stroke to the points that matter (Ramer-Douglas-Peucker).
function P.simplify(pts, eps)
    local n = #pts / 2
    if n < 3 then return pts end
    local eps2 = eps * eps
    local keep = { [1] = true, [n] = true }
    local stack = { { 1, n } }
    while #stack > 0 do
        local seg = table.remove(stack)
        local i0, i1 = seg[1], seg[2]
        local ax, ay, bx, by = pts[i0 * 2 - 1], pts[i0 * 2], pts[i1 * 2 - 1], pts[i1 * 2]
        local dx, dy = bx - ax, by - ay
        local len2 = dx * dx + dy * dy
        local maxd, maxi = -1, nil
        for i = i0 + 1, i1 - 1 do
            local px, py = pts[i * 2 - 1], pts[i * 2]
            local d
            if len2 == 0 then
                d = (px - ax) ^ 2 + (py - ay) ^ 2
            else
                local t = ((px - ax) * dx + (py - ay) * dy) / len2
                d = (px - (ax + t * dx)) ^ 2 + (py - (ay + t * dy)) ^ 2
            end
            if d > maxd then maxd, maxi = d, i end
        end
        if maxi and maxd > eps2 then
            keep[maxi] = true
            stack[#stack + 1] = { i0, maxi }
            stack[#stack + 1] = { maxi, i1 }
        end
    end
    local out = {}
    for i = 1, n do
        if keep[i] then out[#out + 1] = pts[i * 2 - 1]; out[#out + 1] = pts[i * 2] end
    end
    return out
end
MD.Simplify = P.simplify
