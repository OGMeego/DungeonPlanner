-- Canvas.lua
-- The map canvas: pictures, tiles, sketches and pin pools.
local _, ns = ...
local DMap = ns.DMap
local P = ns.Private("DMap")

-- ---------------------------------------------------------------------------
-- Drawing
-- ---------------------------------------------------------------------------

P.canvas = nil
P.floorIndex = 1
P.currentKey = nil
P.drawArgs = nil
P.pendingFloor = nil   -- { key, floor }: open this floor next time this dungeon's map is drawn
-- Open a dungeon's map on a given floor (for drawings shared by the group). key = dungeon key.
function DMap.OpenOn(key, floor)
    for id, d in pairs(ns.DB.dungeons) do
        if ns.Data.Normalize(d.name) == key then
            P.pendingFloor = { key = key, floor = floor }
            ns.Journal.ShowDungeon(id, 4)
            return true
        end
    end
    for _, a in ipairs(ns.Journal.ForeverDungeons and ns.Journal.ForeverDungeons() or {}) do
        local f = a.forever
        if f and ns.Data.Normalize(f.name) == key then
            P.pendingFloor = { key = key, floor = floor }
            ns.Journal.ShowActivity(a)
            ns.Journal.SelectTab(4)
            return true
        end
    end
end

local BOSS_SIZE, QUEST_SIZE, START_SIZE = 34, 22, 26

function P.iconScale() return 0.5 end
function P.questsHidden() return false end

function P.redraw() if P.drawArgs then DMap.Draw(unpack(P.drawArgs)) end end

local function newPin(parent)
    local pin = CreateFrame("Button", nil, parent)
    pin:SetSize(26, 26)
    pin.icon = pin:CreateTexture(nil, "ARTWORK")
    pin.icon:SetAllPoints()
    -- Round portrait: a circular mask over the icon and a gold ring around it.
    if pin.CreateMaskTexture then
        pin.mask = pin:CreateMaskTexture()
        pin.mask:SetAllPoints(pin.icon)
        pin.mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    end
    pin.ring = pin:CreateTexture(nil, "OVERLAY", nil, 1)
    pin.ring:SetPoint("TOPLEFT", -4, 4)
    pin.ring:SetPoint("BOTTOMRIGHT", 4, -4)
    pin.ring:SetTexture("Interface\\Common\\GoldRing")
    pin.num = pin:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    pin.num:SetPoint("BOTTOMRIGHT", 5, -3)
    pin.check = pin:CreateTexture(nil, "OVERLAY", nil, 2)
    pin.check:SetSize(16, 16)
    pin.check:SetPoint("TOPRIGHT", 5, 5)
    ns.SetAtlas(pin.check, "common-icon-checkmark")
    pin.label = pin:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pin.label:SetJustifyH("LEFT")
    pin:SetScript("OnLeave", GameTooltip_Hide)
    return pin
end

-- Make a pin plain (quest marker / entrance) or a round portrait (boss).
-- Our own start marker (Media/Start.tga): a green flag on a gold-rimmed badge.
P.START_ICON = "Interface\\AddOns\\DungeonPlanner\\Media\\Start"

function P.pinStyle(pin, round, size)
    pin:SetSize(size, size)
    if pin.mask then
        if round then pin.icon:AddMaskTexture(pin.mask) else pin.icon:RemoveMaskTexture(pin.mask) end
    end
    pin.ring:SetShown(round)
    pin.icon:SetTexCoord(0, 1, 0, 1)
    pin.icon:SetDesaturated(false)
    pin.icon:SetVertexColor(1, 1, 1)
    pin.num:SetText("")
    pin.check:Hide()
    pin.label:SetText("")
    pin.label:ClearAllPoints()
    pin.label:SetPoint("LEFT", pin, "RIGHT", 6, 0)
end

function P.create(parent)
    local c = CreateFrame("Frame", nil, parent)
    c:SetAllPoints()
    c.art = CreateFrame("Frame", nil, c)
    c.art:SetPoint("CENTER", 0, 12)
    c.chart = CreateFrame("Frame", nil, c)
    c.chart:SetPoint("TOPLEFT", 20, -44)
    c.chart:SetPoint("BOTTOMRIGHT", -20, 40)
    c.tiles, c.pins, c.lines, c.chartPins, c.chartLines = {}, {}, {}, {}, {}
    c.sketchTex, c.sketchText, c.patches = {}, {}, {}
    c.title = c:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    c.title:SetPoint("TOP", 0, -14)
    c.empty = c:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    c.empty:SetPoint("CENTER")
    c.empty:SetWidth(360)
    c.empty:SetWordWrap(true)
    c.floor = CreateFrame("DropdownButton", nil, c, "WowStyle1DropdownTemplate")
    c.floor:SetPoint("TOPLEFT", 8, -6)
    c.floor:SetWidth(200)
    c.floor:SetFrameLevel(c:GetFrameLevel() + 20)

    c.legend = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    c.legend:SetPoint("BOTTOMLEFT", 10, 34)
    c.legend:SetPoint("RIGHT", -10, 0)
    c.legend:SetJustifyH("LEFT")
    c.legend:SetWordWrap(true)
    c:SetFrameLevel(parent:GetFrameLevel() + 5)
    return c
end

function P.hideAll()
    -- pairs, not ipairs: the route-line pools can start at 2, and ipairs would stop at a gap.
    for _, t in pairs(P.canvas.tiles) do t:Hide() end
    for _, t in pairs(P.canvas.patches or {}) do t:Hide() end
    for _, t in pairs(P.canvas.sketchTex or {}) do t:Hide() end
    for _, f in pairs(P.canvas.sketchText or {}) do f:Hide() end
    for _, p in pairs(P.canvas.pins) do p:Hide() end
    for _, l in pairs(P.canvas.lines) do l:Hide() end
    for _, p in pairs(P.canvas.chartPins) do p:Hide() end
    for _, l in pairs(P.canvas.chartLines) do l:Hide() end
    P.canvas.title:SetText("")
    P.canvas.legend:SetText("")
    P.canvas.empty:Hide()
    P.canvas.floor:Hide()
    if ns.MapDraw then ns.MapDraw.Hide() end
end

-- A floor picture from its 12 files (4 across, 3 down, 256 px each; the picture is 1002 x 668).
-- One of our own map pictures: 1024x512 file, the map in its left 768x512.
function P.drawImage(path, maxW, maxH, right, bottom)
    local W, H = 1002, 668
    local scale = math.min(maxW / W, maxH / H)
    P.canvas.art:SetSize(W * scale, H * scale)
    local t = P.canvas.tiles[1]
    if not t then
        t = P.canvas.art:CreateTexture(nil, "BACKGROUND")
        P.canvas.tiles[1] = t
    end
    t:SetTexture(path)
    t:SetTexCoord(0, right or 0.75, 0, bottom or 1)
    t:ClearAllPoints()
    t:SetAllPoints(P.canvas.art)
    t:Show()
    return W * scale, H * scale
end

function P.drawTiles(tiles, maxW, maxH, prefix)
    local W, H, T = 1002, 668, 256
    local scale = math.min(maxW / W, maxH / H)
    P.canvas.art:SetSize(W * scale, H * scale)
    for i = 1, 12 do
        local r, c = math.floor((i - 1) / 4), (i - 1) % 4
        local t = P.canvas.tiles[i]
        if not t then
            t = P.canvas.art:CreateTexture(nil, "BACKGROUND")
            P.canvas.tiles[i] = t
        end
        local fw = math.min(T, W - c * T)
        local fh = math.min(T, H - r * T)
        t:SetTexture(prefix and (prefix .. i) or tiles[i])
        t:ClearAllPoints()
        t:SetTexCoord(0, fw / T, 0, fh / T)
        t:SetSize(fw * scale, fh * scale)
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", c * T * scale, -r * T * scale)
        t:Show()
    end
    return W * scale, H * scale
end

-- Our own drawing of a dungeon's layout on parchment: rooms and halls, labels, a title.
local SK_W, SK_H = 1002, 668
local function sketchTex(i, layer, sub)
    P.canvas.sketchTex = P.canvas.sketchTex or {}
    local t = P.canvas.sketchTex[i]
    if not t then
        t = P.canvas.art:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0)
        P.canvas.sketchTex[i] = t
    end
    t:ClearAllPoints()
    t:Show()
    return t
end
local function sketchText(i)
    P.canvas.sketchText = P.canvas.sketchText or {}
    local f = P.canvas.sketchText[i]
    if not f then
        f = P.canvas.art:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        P.canvas.sketchText[i] = f
    end
    f:ClearAllPoints()
    f:Show()
    return f
end

function P.drawSketch(sk, title, maxW, maxH)
    local scale = math.min(maxW / SK_W, maxH / SK_H)
    local w, h = SK_W * scale, SK_H * scale
    P.canvas.art:SetSize(w, h)
    local n = 0
    local function rect(l, t, r, b, red, green, blue, alpha, pad, layer, sub)
        n = n + 1
        local tex = sketchTex(n, layer, sub)
        tex:SetColorTexture(red, green, blue, alpha)
        tex:SetPoint("TOPLEFT", P.canvas.art, "TOPLEFT", l * w - pad, -(t * h - pad))
        tex:SetPoint("BOTTOMRIGHT", P.canvas.art, "TOPLEFT", r * w + pad, -(b * h + pad))
    end
    -- Parchment and its darker edge.
    rect(0, 0, 1, 1, 0.42, 0.31, 0.16, 1, 0, "BACKGROUND", -8)
    rect(0.012, 0.018, 0.988, 0.982, 0.78, 0.66, 0.43, 1, 0, "BACKGROUND", -7)
    rect(0.05, 0.08, 0.95, 0.95, 0.74, 0.61, 0.38, 0.6, 0, "BACKGROUND", -6)
    -- Walls first (a dark border around every room), then the floors on top.
    for _, a in ipairs(sk.areas) do rect(a[1], a[2], a[3], a[4], 0.33, 0.22, 0.10, 1, 4 * scale + 2, "BACKGROUND", -4) end
    for _, a in ipairs(sk.areas) do rect(a[1], a[2], a[3], a[4], 0.90, 0.80, 0.58, 1, 0, "BACKGROUND", -3) end
    local m = 0
    for _, lb in ipairs(sk.labels or {}) do
        m = m + 1
        local f = sketchText(m)
        f:SetFontObject("GameFontNormalSmall")
        f:SetText(strupper(lb[1]))
        f:SetTextColor(0.30, 0.18, 0.06)
        f:SetPoint("CENTER", P.canvas.art, "TOPLEFT", lb[2] * w, -lb[3] * h)
    end
    m = m + 1
    local tf = sketchText(m)
    tf:SetFontObject("GameFontNormalLarge")
    tf:SetText(strupper(title or ""))
    tf:SetTextColor(0.45, 0.12, 0.04)
    tf:SetPoint("TOP", P.canvas.art, "TOP", 0, -12 * scale - 6)
    return w, h
end

function P.drawArt(uiMapID, maxW, maxH)
    local layers = ns.Call(C_Map.GetMapArtLayers, uiMapID)
    local layer = type(layers) == "table" and layers[1]
    local textures = ns.Call(C_Map.GetMapArtLayerTextures, uiMapID, 1)
    if not (layer and type(textures) == "table" and #textures > 0) then return nil end
    local W, H = ns.Field(layer, "layerWidth"), ns.Field(layer, "layerHeight")
    local tw, th = ns.Field(layer, "tileWidth"), ns.Field(layer, "tileHeight")
    if not (W and H and tw and th) then return nil end
    local scale = math.min(maxW / W, maxH / H)
    P.canvas.art:SetSize(W * scale, H * scale)
    local cols = math.ceil(W / tw)
    local rows = math.ceil(H / th)
    local i = 0
    for r = 1, rows do
        for c = 1, cols do
            i = i + 1
            local file = textures[i]
            if file then
                local t = P.canvas.tiles[i]
                if not t then
                    t = P.canvas.art:CreateTexture(nil, "BACKGROUND")
                    P.canvas.tiles[i] = t
                end
                local fw = math.min(tw, W - (c - 1) * tw)
                local fh = math.min(th, H - (r - 1) * th)
                t:SetTexture(file)
                t:SetTexCoord(0, fw / tw, 0, fh / th)
                t:SetSize(fw * scale, fh * scale)
                t:ClearAllPoints()
                t:SetPoint("TOPLEFT", (c - 1) * tw * scale, -(r - 1) * th * scale)
                t:Show()
            end
        end
    end
    return W * scale, H * scale
end

function P.getPin(pool, parent, index)
    local pin = pool[index]
    if not pin then
        pin = newPin(parent)
        pool[index] = pin
    end
    pin:ClearAllPoints()
    pin:Show()
    return pin
end

function P.getLine(pool, parent, index)
    if not parent.CreateLine then return nil end
    local line = pool[index]
    if not line then
        line = parent:CreateLine(nil, "ARTWORK")
        line:SetThickness(3)
        line:SetColorTexture(1, 0.82, 0, 0.55)
        pool[index] = line
    end
    line:Show()
    return line
end

function P.isKilled(kills, b)
    return (b.enc and kills[b.enc]) or kills[b.name] or (b.alias and kills[b.alias]) or false
end
