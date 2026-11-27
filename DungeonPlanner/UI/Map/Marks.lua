-- Marks.lua
-- Quest marks and boss pins.
local _, ns = ...
local L = ns.L
local DMap = ns.DMap
local BOSS_SIZE, QUEST_SIZE, START_SIZE = 34, 22, 26
local P = ns.Private("DMap")

-- ---------------------------------------------------------------- quests on the map

local MARK_TEXT = { s = "MAP_Q_START", e = "MAP_Q_END", k = "MAP_Q_KILL", i = "MAP_Q_ITEM", u = "MAP_Q_USE" }

function P.markWanted(mk)
    local Q = ns.Quests
    if not Q then return true end
    if Q.IsDone(mk.quest) then return false end
    if Q.ForMe and not Q.ForMe(mk.quest) then return false end
    return true
end

local function markLine(mk)
    local title = ns.Quests and ns.Quests.Title(mk.quest) or ("#" .. mk.quest)
    return (L[MARK_TEXT[mk.kind] or "MAP_Q_KILL"]):format(mk.what ~= "" and mk.what or title), title
end

function P.addMarkLines(list)
    local byQuest, order = {}, {}
    for _, mk in ipairs(list) do
        local line, title = markLine(mk)
        if not byQuest[title] then byQuest[title] = {}; tinsert(order, title) end
        tinsert(byQuest[title], line)
    end
    for _, title in ipairs(order) do
        GameTooltip:AddLine(title, 1, 0.82, 0)
        for _, line in ipairs(byQuest[title]) do GameTooltip:AddLine("  " .. line, 1, 1, 1, true) end
    end
end

function P.markIcon(tex, kinds)
    if kinds.s then
        if not ns.SetAtlas(tex, "QuestNormal") then tex:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon") end
    elseif kinds.e and not (kinds.k or kinds.i or kinds.u) then
        if not ns.SetAtlas(tex, "QuestTurnin") then tex:SetTexture("Interface\\GossipFrame\\ActiveQuestIcon") end
    else
        if not ns.SetAtlas(tex, "QuestObjective") then tex:SetTexture("Interface\\GossipFrame\\ActiveQuestIcon") end
    end
end

-- ---------------------------------------------------------------- boss pins

local function setBossIcon(pin, b)
    if b.display and b.display > 0 and SetPortraitTextureFromCreatureDisplayID then
        local ok = pcall(SetPortraitTextureFromCreatureDisplayID, pin.icon, b.display)
        if ok then return end
    end
    local icon = DMap.IconFor(b.name, b.alias)
    if icon then pin.icon:SetTexture(icon) return end
    pin.icon:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
end

-- A boss on the map or chart: round portrait, number, tick when killed, tooltip, click for loot.
function P.setupBossPin(pin, b, killed, onClick, size, marks)
    P.pinStyle(pin, true, size)
    setBossIcon(pin, b)
    pin.num:SetText(b.index)
    pin.check:SetShown(killed and true or false)
    pin.icon:SetDesaturated(killed and true or false)
    pin:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(("%d. %s"):format(b.index, b.name), 1, 0.82, 0)
        if b.lvl then GameTooltip:AddLine(LEVEL .. " " .. b.lvl, 1, 1, 1) end
        local secret = ns.SecretsSvc and ns.SecretsSvc.BossText(b.name)
        if secret then
            GameTooltip:AddLine(L.SECRET_BOSS, 0.75, 0.6, 1)
            GameTooltip:AddLine(secret, 0.9, 0.85, 0.7, true)
        elseif b.optional then GameTooltip:AddLine(L.MAP_OPTIONAL, 0.7, 0.7, 0.7) end
        if b.final then GameTooltip:AddLine(L.MAP_FINAL, 1, 0.5, 0.25) end
        if killed then GameTooltip:AddLine(L.MAP_KILLED, 0.5, 1, 0.5) end
        if marks and #marks > 0 then
            GameTooltip:AddLine(" ")
            P.addMarkLines(marks)
        end
        if onClick then GameTooltip:AddLine(L.MAP_CLICK_LOOT, 0.6, 0.6, 0.6) end
        GameTooltip:Show()
    end)
    pin:SetScript("OnClick", onClick)
end

-- The route as a chart: entrance, then every boss in kill order, joined by the route line.
function P.drawChart(spec, kills, onBossClick)
    local chart = P.canvas.chart
    local W, H = chart:GetWidth(), chart:GetHeight()
    if not W or W <= 0 then W, H = 560, 400 end
    local nodes = {}
    local f = spec.forever
    tinsert(nodes, { kind = "start", label = f and f.zone and (L.MAP_ENTRANCE_AT):format(f.zone, f.entrance[1], f.entrance[2]) or L.MAP_START })
    for _, b in ipairs(spec.bosses) do tinsert(nodes, { kind = "boss", boss = b }) end
    local cols = #nodes > 9 and 2 or 1
    local perCol = math.ceil(#nodes / cols)
    local stepY = math.min(46, (H - 20) / math.max(1, perCol - 1))
    local colW = W / cols
    local prev
    for i, n in ipairs(nodes) do
        local col = math.floor((i - 1) / perCol)
        local row = (i - 1) % perCol
        local x = col * colW + 40
        local y = -(10 + row * stepY)
        local pin = P.getPin(P.canvas.chartPins, chart, i)
        pin:SetPoint("CENTER", chart, "TOPLEFT", x, y)
        if n.kind == "start" then
            P.pinStyle(pin, false, START_SIZE)
            pin.icon:SetTexture(P.START_ICON)
            pin.label:SetText(n.label)
            pin.label:SetTextColor(1, 1, 1)
            pin:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L.MAP_START, 1, 1, 1)
                if f and f.note then GameTooltip:AddLine(f.note, 1, 0.82, 0, true) end
                GameTooltip:Show()
            end)
            pin:SetScript("OnClick", nil)
        else
            local b = n.boss
            local killed = P.isKilled(kills, b)
            P.setupBossPin(pin, b, killed, onBossClick and function() onBossClick(b) end or nil, 30)
            local tag = b.optional and ("  " .. GRAY_FONT_COLOR:WrapTextInColorCode(L.MAP_OPTIONAL)) or
                (b.final and ("  " .. ORANGE_FONT_COLOR:WrapTextInColorCode(L.MAP_FINAL)) or "")
            pin.label:SetText(("%d. %s%s"):format(b.index, b.name, tag))
            if killed then pin.label:SetTextColor(0.5, 0.5, 0.5) else pin.label:SetTextColor(1, 0.82, 0) end
        end
        if prev and (col == prev.col) then
            local line = P.getLine(P.canvas.chartLines, chart, i)
            if line then
                line:SetStartPoint("TOPLEFT", chart, prev.x, prev.y - 15)
                line:SetEndPoint("TOPLEFT", chart, x, y + 15)
                local dim = n.kind == "boss" and n.boss.optional
                line:SetColorTexture(1, 0.82, 0, dim and 0.2 or 0.55)
            end
        end
        prev = { x = x, y = y, col = col }
    end
end
