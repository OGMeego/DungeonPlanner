-- Draw.lua
-- Drawing one dungeon's map.
local _, ns = ...
local L = ns.L
local DMap = ns.DMap
local B_ENC, B_NPC, B_NAME, B_LVL, B_WX, B_WY, B_DISPLAY = 1, 2, 3, 4, 5, 6, 7
local BOSS_SIZE, QUEST_SIZE, START_SIZE = 34, 22, 26
local P = ns.Private("DMap")

-- parent: the content inset. spec: from SpecForDungeon / SpecForActivity.
-- onBossClick(boss): optional, e.g. open that boss's loot.
function DMap.Draw(parent, spec, onBossClick)
    if not P.canvas then P.canvas = P.create(parent) end
    P.canvas:Show()
    P.drawArgs = { parent, spec, onBossClick }
    if P.currentKey ~= spec.key then P.floorIndex = 1; P.currentKey = spec.key end
    if P.pendingFloor and P.pendingFloor.key == spec.key then P.floorIndex = P.pendingFloor.floor end
    P.pendingFloor = nil
    P.hideAll()
    local kills = {}
    if ns.Tracker then
        for k, v in pairs(spec.instanceID and ns.Tracker.Kills(spec.instanceID) or {}) do kills[k] = v end
        for k, v in pairs(ns.Tracker.KillsByName and ns.Tracker.KillsByName(spec.name) or {}) do kills[k] = v end
    end
    if #spec.bosses == 0 then
        P.canvas.empty:SetText(L.MAP_NONE)
        P.canvas.empty:Show()
        return
    end
    local data = DMap.Floors(spec)
    local floors = data.floors
    local w, h
    if #floors > 0 then
        P.floorIndex = math.min(P.floorIndex, #floors)
        local fl = floors[P.floorIndex]
        if fl.image then
            w, h = P.drawImage(fl.image, parent:GetWidth() - 12, parent:GetHeight() - 46, fl.right, fl.bottom)
        elseif fl.tilePath then
            w, h = P.drawTiles(nil, parent:GetWidth() - 12, parent:GetHeight() - 46, fl.tilePath)
        elseif fl.tiles then
            w, h = P.drawTiles(fl.tiles, parent:GetWidth() - 12, parent:GetHeight() - 46)
        elseif fl.sketch then
            w, h = P.drawSketch(fl.sketch, fl.name, parent:GetWidth() - 12, parent:GetHeight() - 46)
        else
            w, h = P.drawArt(fl.map, parent:GetWidth() - 12, parent:GetHeight() - 46)
        end
    end
    -- Patches laid over the picture (cover the skulls printed on the game's own maps).
    if w and floors[P.floorIndex] and floors[P.floorIndex].patches then
        for i, pt in ipairs(floors[P.floorIndex].patches) do
            local t = P.canvas.patches[i]
            if not t then
                t = P.canvas.art:CreateTexture(nil, "BACKGROUND", nil, 3)
                P.canvas.patches[i] = t
            end
            t:SetTexture(pt[1])
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", P.canvas.art, "TOPLEFT", pt[2] * w, -pt[3] * h)
            t:SetSize((pt[4] - pt[2]) * w, (pt[5] - pt[3]) * h)
            t:SetAlpha(pt[6] or 1)
            t:Show()
        end
    end
    if not w then
        P.canvas.title:SetText(L.MAP_ROUTE_TITLE)
        P.drawChart(spec, kills, onBossClick)
        P.canvas.legend:SetPoint("BOTTOMLEFT", 10, 34)
        P.canvas.legend:SetText(L.MAP_ROUTE_NOTE)
        return
    end
    P.canvas.legend:ClearAllPoints()
    P.canvas.legend:SetPoint("BOTTOMLEFT", 10, 34)
    P.canvas.legend:SetPoint("RIGHT", -10, 0)
    P.canvas.floor:SetShown(#floors > 1)
    P.canvas.floor:SetupMenu(function(_, root)
        for i, fl in ipairs(floors) do
            local count = 0
            for _, p in ipairs(fl.points) do if p.kind == "boss" then count = count + 1 end end
            local label = (fl.name ~= "" and fl.name or (L.MAP_FLOOR):format(i)) .. (count > 0 and (" (" .. count .. ")") or "")
            root:CreateRadio(label, function() return P.floorIndex == i end,
                function() P.floorIndex = i; DMap.Draw(parent, spec, onBossClick) end, i)
        end
    end)

    local fl = floors[P.floorIndex]
    local scale = P.iconScale()
    local route, quests = {}, {}
    for _, p in ipairs(fl.points) do
        if p.kind == "quest" then
            if not P.questsHidden() and P.markWanted(p.mark) then tinsert(quests, p) end
        else
            tinsert(route, p)
        end
    end
    table.sort(route, function(a, b) return (a.boss and a.boss.index or 0) < (b.boss and b.boss.index or 0) end)

    -- Quest markers standing on a boss go into that boss's tooltip; the rest group by spot.
    local bossMarks, groups = {}, {}
    for _, q in ipairs(quests) do
        local onBoss
        for _, p in ipairs(route) do
            if p.kind == "boss" and math.abs(p.x - q.x) < 0.015 and math.abs(p.y - q.y) < 0.015 then onBoss = p break end
        end
        if onBoss then
            bossMarks[onBoss] = bossMarks[onBoss] or {}
            tinsert(bossMarks[onBoss], q.mark)
        else
            local g
            for _, grp in ipairs(groups) do
                if math.abs(grp.x - q.x) < 0.015 and math.abs(grp.y - q.y) < 0.015 then g = grp break end
            end
            if not g then g = { x = q.x, y = q.y, marks = {}, kinds = {} }; tinsert(groups, g) end
            tinsert(g.marks, q.mark)
            g.kinds[q.mark.kind] = true
        end
    end

    -- No route lines on the maps: the numbered portraits show the order.
    local n = 0
    for _, g in ipairs(groups) do
        n = n + 1
        local pin = P.getPin(P.canvas.pins, P.canvas.art, n)
        P.pinStyle(pin, false, QUEST_SIZE * math.sqrt(scale))
        pin:SetPoint("CENTER", P.canvas.art, "TOPLEFT", g.x * w, -g.y * h)
        P.markIcon(pin.icon, g.kinds)
        pin:SetFrameLevel(P.canvas.art:GetFrameLevel() + 2)
        pin:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            P.addMarkLines(g.marks)
            GameTooltip:Show()
        end)
        pin:SetScript("OnClick", nil)
    end
    for _, p in ipairs(route) do
        n = n + 1
        local pin = P.getPin(P.canvas.pins, P.canvas.art, n)
        pin:SetPoint("CENTER", P.canvas.art, "TOPLEFT", p.x * w, -p.y * h)
        pin:SetFrameLevel(P.canvas.art:GetFrameLevel() + 4)
        if p.kind == "start" then
            P.pinStyle(pin, false, START_SIZE * math.sqrt(scale))
            pin.icon:SetTexture(P.START_ICON)
            pin.label:ClearAllPoints()
            pin.label:SetPoint("RIGHT", pin, "LEFT", -4, 0)
            pin.label:SetFontObject("GameFontNormalLarge")
            pin.label:SetText(L.MAP_ENTRANCE)
            pin.label:SetTextColor(1, 0.82, 0)
            pin:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L.MAP_START, 1, 1, 1)
                GameTooltip:Show()
            end)
            pin:SetScript("OnClick", nil)
        else
            local b = p.boss
            P.setupBossPin(pin, b, P.isKilled(kills, b), onBossClick and function() onBossClick(b) end or nil,
                BOSS_SIZE * scale, bossMarks[p])
            pin.label:SetFontObject("GameFontNormal")
        end
    end

    -- Bosses on other floors, and bosses not placed yet, so the order is never lost.
    local parts = {}
    local others = {}
    for i, other in ipairs(floors) do
        if i ~= P.floorIndex then
            for _, p in ipairs(other.points) do
                if p.kind == "boss" then tinsert(others, ("%d. %s (%s)"):format(p.boss.index, p.boss.name, other.name)) end
            end
        end
    end
    if #others > 0 then tinsert(parts, L.MAP_OTHER_FLOORS .. " " .. table.concat(others, ", ")) end
    if #data.unplaced > 0 then
        local names = {}
        for _, b in ipairs(data.unplaced) do tinsert(names, ("%d. %s"):format(b.index, b.name)) end
        tinsert(parts, L.MAP_UNPLACED .. " " .. table.concat(names, ", "))
    end
    P.canvas.legend:SetText(table.concat(parts, "\n"))
    -- Drawing on the map (and sharing it): one drawing per dungeon floor.
    if ns.MapDraw then ns.MapDraw.Attach(P.canvas, P.canvas.art, spec.key .. "#" .. P.floorIndex) end
end

function DMap.Canvas() return P.canvas end -- for tests

-- Forever's new dungeons: the reference order, and the extra bosses it knows (rares) as optional.
function DMap.ApplyForeverOrder()
    for _, f in ipairs(ns.ForeverDB or {}) do
        local fm = (ns.DJMaps and ns.DJMaps[f.name]) or (ns.ForeverMaps and ns.ForeverMaps[f.name])
        if fm then
            local byKey, used, list = {}, {}, {}
            for _, b in ipairs(f.bosses) do
                byKey[P.key(b.name)] = b
                if b.alias then byKey[P.key(b.alias)] = b end
            end
            for _, rb in ipairs(fm.bosses) do
                local b = byKey[P.key(rb[1])]
                if b and not used[b] then
                    used[b] = true
                    tinsert(list, b)
                elseif not b then
                    tinsert(list, { name = rb[1], optional = true })
                end
            end
            for _, b in ipairs(f.bosses) do if not used[b] then tinsert(list, b) end end
            f.bosses = list
        end
    end
end

-- Kill order from the reference maps: put each dungeon's bosses in that order everywhere
-- (overview, tracker, map numbers). Bosses the reference doesn't list keep their place at the end.
function DMap.ApplyKillOrder()
    for inst, ref in pairs(ns.DJMaps or ns.MapRef or {}) do
        local d = type(inst) == "number" and ns.DB and ns.DB.dungeons[inst]
        if d then
            local rank = {}
            for i, rb in ipairs(ref.bosses) do rank[P.key(rb[1])] = rank[P.key(rb[1])] or i end
            local orig = {}
            for i, b in ipairs(d.bosses) do orig[b] = i end
            table.sort(d.bosses, function(a, b)
                local ra, rb2 = rank[P.key(a[B_NAME])] or (100 + orig[a]), rank[P.key(b[B_NAME])] or (100 + orig[b])
                return ra < rb2
            end)
        end
    end
end

function DMap.Hide()
    if ns.MapDraw then ns.MapDraw.Hide() end
    if P.canvas then P.canvas:Hide() end
end

-- /dp map: what the map tab found for a dungeon (to report problems).
function DMap.Debug(spec)
    if not spec then return ns.Say(L.MAP_DEBUG_NONE) end
    DMap.Reset()
    local data = DMap.Floors(spec)
    ns.Say(("Map check: %s (instance %s), %d bosses"):format(spec.name, tostring(spec.instanceID), #spec.bosses))
    ns.Say(("  floors: %s"):format(#data.candidates > 0 and table.concat(data.candidates, ", ") or "none"))
    for _, fl in ipairs(data.floors) do
        local count = 0
        for _, p in ipairs(fl.points) do if p.kind == "boss" then count = count + 1 end end
        local c = P.corners(fl.map)
        if fl.tiles then
            ns.Say(("  %d %s: picture and bounds from our data, bosses %d"):format(fl.map, fl.name, count))
        else
            ns.Say(("  %d %s: art %s, corners %s, bosses %d"):format(fl.map, fl.name, P.hasArt(fl.map) and "yes" or "no",
                c and ("inst " .. tostring(c.inst)) or "no", count))
        end
    end
    ns.Say(("  placement method: %s, not placed: %d"):format(tostring(data.method), #data.unplaced))
end

ns.Listen("TRACKER_CHANGED", function()
    if P.canvas and P.canvas:IsShown() then P.redraw() end
end)
ns.Listen("QUESTS_CHANGED", function()
    if P.canvas and P.canvas:IsShown() then P.redraw() end
end)

DMap.ApplyKillOrder()
DMap.ApplyForeverOrder()
