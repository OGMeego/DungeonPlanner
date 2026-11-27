-- SecretsPage.lua
-- Secrets: Forever's solved hidden quests, riddles, secret bosses and curios, by category.
-- Click one for its steps; click a step to be guided there.
local _, ns = ...
local L = ns.L
local J = ns.Journal
local P = ns.Private("Journal")

local SIDE = { A = "SECRET_SIDE_A", H = "SECRET_SIDE_H", B = "SECRET_SIDE_B" }

local function textRow(text, color)
    local lines = math.ceil(#text / 92)
    return { kind = "text", h = 10 + lines * 15, text = color and color:WrapTextInColorCode(text) or text }
end

local function facts(s)
    local parts = { L[SIDE[s.side]], L.SECRET_LEVEL:format(s.lvl or 1) }
    if s.class then tinsert(parts, ns.ClassName(s.class) or s.class) end
    if s.dungeon then tinsert(parts, s.dungeon) end
    return table.concat(parts, "  ·  ")
end

local function listRows()
    local S = ns.SecretsSvc
    local rows = { textRow(L.SECRET_HINT, GRAY_FONT_COLOR) }
    for _, cat in ipairs(ns.SecretCategories) do
        local first = true
        for _, s in ipairs(ns.Secrets) do
            if s.cat == cat.id then
                if first then
                    tinsert(rows, { kind = "header", text = L[cat.name], h = 26 })
                    first = false
                end
                local mine = S.ForMe(s)
                local step, done = S.Progress(s.id)
                local right = done and GREEN_FONT_COLOR:WrapTextInColorCode(L.SECRET_DONE)
                    or (step > 1 and L.SECRET_STEP_OF:format(math.min(step, #s.steps), #s.steps) or "")
                tinsert(rows, { kind = "line", h = 44, icon = s.icon, iconSize = 28, text = s.name, sub = facts(s), right = right,
                    dim = done or not mine,
                    onClick = function(button)
                        if button == "RightButton" then S.SetDone(s.id, not done) else J.ShowPage("secret", s.id) end
                    end,
                    tooltip = function(tt)
                        tt:SetText(s.name, 1, 0.82, 0)
                        tt:AddLine(s.summary, 1, 1, 1, true)
                        tt:AddLine(L.SECRET_REWARD:format(s.reward), 0.4, 1, 0.4, true)
                        if not mine then tt:AddLine(L.SECRET_NOT_FOR_YOU, 1, 0.4, 0.3, true) end
                        tt:AddLine(L.SECRET_CLICK, 0.6, 0.6, 0.6)
                    end })
            end
        end
        if not first then tinsert(rows, { kind = "spacer", h = 6 }) end
    end
    return rows
end

local function openDungeon(name)
    for _, a in ipairs(J.ForeverDungeons()) do
        local f = a.forever
        if (f and f.name == name) or a.name == name then J.ShowActivity(a) return end
    end
    for mapID, d in pairs(ns.DB.dungeons) do
        if d.name == name or d.name == "The " .. name then J.ShowDungeon(mapID, 1) return end
    end
end

local function stepSide(text) return ns.SecretsSvc.StepSide(text) end

local function stripSide(text) return ns.SecretsSvc.StripSide(text) end

-- "[40] Stepping Stones" in the quest's difficulty colour (grey once done), like quest rows.
local function questLabel(q, passed)
    local label = ("[%d] %s"):format(q[2], q[1])
    if passed then return "|cff999999" .. label .. "|r" end
    local c = P.questColor and P.questColor(q[2])
    if not (c and c.r) then return label end
    return ("|cff%02x%02x%02x%s|r"):format(math.floor(c.r * 255), math.floor(c.g * 255), math.floor(c.b * 255), label)
end

-- The quest ID of the quest with this title in your quest log, or nil.
local function questInLog(title)
    if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo) then return nil end
    local n = ns.Safe(ns.Call(C_QuestLog.GetNumQuestLogEntries)) or 0
    for i = 1, n do
        local info = ns.Call(C_QuestLog.GetInfo, i)
        local t = type(info) == "table" and ns.Safe(ns.Field(info, "title"))
        if t and strlower(t) == strlower(title) then return ns.Safe(ns.Field(info, "questID")) or true end
    end
    return nil
end

local function spotText(st)
    return st[2] and st[3] and ("%s (%.1f, %.1f)"):format(st[2], st[3], st[4]) or nil
end

local function detailRows(cur)
    local S = ns.SecretsSvc
    local s = S.Get(cur.arg)
    if not s then return {} end
    local step, done = S.Progress(s.id)
    local rows = { textRow(s.summary) }
    tinsert(rows, textRow(L.SECRET_REWARD:format(s.reward), GREEN_FONT_COLOR))
    local mine, why = S.ForMe(s)
    if not mine then tinsert(rows, textRow(why == "class" and L.SECRET_WRONG_CLASS or L.SECRET_NOT_FOR_YOU, ORANGE_FONT_COLOR)) end
    if s.dungeon then
        tinsert(rows, { kind = "line", h = 40, card = { s.dungeon }, text = L.SECRET_OPEN_DUNGEON:format(s.dungeon),
            onClick = function() openDungeon(s.dungeon) end })
    end
    tinsert(rows, { kind = "spacer", h = 6 })
    -- Steps for one faction only start with "Alliance" or "Horde". When a secret has both,
    -- each faction gets its own tab (yours first) and the shared steps show on both.
    local sides = {}
    for _, st in ipairs(s.steps) do local f = stepSide(st[1]); if f then sides[f] = true end end
    local tabbed = sides.A and sides.H
    local view
    if tabbed then
        view = cur.side or ((UnitFactionGroup("player") == "Alliance") and "A" or "H")
        tinsert(rows, { kind = "tabs", h = 30, tabs = {
            { text = L.SECRET_SIDE_A, selected = view == "A", onClick = function() cur.side = "A"; J.Refresh() end },
            { text = L.SECRET_SIDE_H, selected = view == "H", onClick = function() cur.side = "H"; J.Refresh() end },
        } })
    end
    -- One "Guide me there" for the whole secret: it picks up at the next step not done yet.
    if not done then
        local mine = view or ((UnitFactionGroup("player") == "Alliance") and "A" or "H")
        for i = step, #s.steps do
            local st = s.steps[i]
            local side = stepSide(st[1])
            if not side or side == mine then
                local text = view and stripSide(st[1]) or st[1]
                local hasSpot = st[2] and st[3]
                local where = spotText(st)
                tinsert(rows, { kind = "line", h = 40, atlas = "Navigation-Tracked-Arrow", iconSize = 20,
                    text = L.NAV_CHAIN_NEXT:format(st.quest and questLabel(st.quest) or text),
                    sub = st.quest and (where and (text .. "  ·  " .. where) or text) or where,
                    color = { 1, 0.82, 0 },
                    action = hasSpot and { text = L.J_GUIDE_ME, onClick = function() S.GuideStep(s, i) end } or nil,
                    onClick = function() if hasSpot then S.GuideStep(s, i) end end })
                if st.tip then tinsert(rows, textRow(st.tip, GREEN_FONT_COLOR)) end
                break
            end
        end
    end
    tinsert(rows, { kind = "header", text = L.SECRET_STEPS, h = 26 })
    local shown, current = 0, nil
    for i, st in ipairs(s.steps) do
        local side = stepSide(st[1])
        if not (view and side and side ~= view) then
            shown = shown + 1
            local hasSpot = st[2] and st[3]
            local passed = done or i < step
            if not passed and not current then current = i end
            local text = view and stripSide(st[1]) or st[1]
            local guide = function() S.GuideStep(s, i) end
            local q = st.quest
            local where = spotText(st)
            local inLog = q and not passed and questInLog(q[1])
            local icon, atlas
            if passed then atlas = "common-icon-checkmark"
            elseif q and (inLog or i == current) then atlas = inLog and "QuestTurnin" or "QuestNormal"
            else icon = "Interface\\Common\\Indicator-Gray" end
            tinsert(rows, { kind = "line", h = (hasSpot or q) and 42 or 34,
                atlas = atlas, icon = icon, iconSize = 16,
                -- A quest step looks like a quest: "[40] Stepping Stones", what to do underneath.
                text = q and ("%d. %s"):format(shown, questLabel(q, passed)) or ("%d. %s"):format(shown, text),
                sub = q and (where and (text .. "  ·  " .. where) or text) or where,
                right = inLog and GREEN_FONT_COLOR:WrapTextInColorCode(L.J_TAG_IN_LOG) or nil,
                -- In your log: a click opens it there, like any quest row.
                logQuest = type(inLog) == "number" and inLog or nil,
                color = passed and { 0.6, 0.6, 0.6 } or (i == current and { 1, 0.82, 0 } or { 1, 1, 1 }),
                onClick = function(button)
                    if button == "RightButton" then S.SetStep(s.id, i + 1)
                    elseif type(inLog) == "number" then ns.Quests.OpenInLog(inLog)
                    elseif hasSpot then guide()
                    else S.SetStep(s.id, i) end
                end,
                tooltip = function(tt)
                    if q then
                        tt:SetText(questLabel(q, passed), 1, 1, 1, 1, true)
                        tt:AddLine(L.J_QUEST_LEVELS:format(q[2], q[3]), 0.8, 0.8, 0.8)
                        tt:AddLine(text, 1, 1, 1, true)
                    else
                        tt:SetText(text, 1, 1, 1, 1, true)
                    end
                    if where then tt:AddLine(where, 0.75, 0.75, 0.75) end
                    if type(inLog) == "number" then tt:AddLine(L.J_CLICK_OPEN_LOG, 0.4, 1, 0.45) end
                    if st.tip then tt:AddLine(st.tip, 0.4, 1, 0.4, true) end
                    if hasSpot then tt:AddLine(L.SECRET_STEP_GUIDE, 0.6, 0.6, 0.6) end
                    tt:AddLine(L.SECRET_STEP_DONE_HINT, 0.6, 0.6, 0.6)
                end })
        end
    end
    tinsert(rows, { kind = "spacer", h = 8 })
    return rows
end

J.RegisterPage("secrets", { nav = L.SECRETS_TITLE, iconTex = "Interface\\Icons\\INV_Misc_Key_14", order = 50,
    count = function() return ns.SecretsSvc.CountOpen() end,
    title = function() return L.SECRETS_TITLE end,
    sub = function() return L.SECRETS_SUB:format(#ns.Secrets) end,
    rows = listRows })

J.RegisterPage("secret", {
    title = function(cur) local s = ns.SecretsSvc.Get(cur.arg) return s and s.name or L.SECRETS_TITLE end,
    sub = function(cur) local s = ns.SecretsSvc.Get(cur.arg) return s and facts(s) or "" end,
    rows = detailRows,
    button = function(cur)
        local _, done = ns.SecretsSvc.Progress(cur.arg)
        return { text = done and L.SECRET_MARK_UNDONE or L.SECRET_MARK_DONE,
            onClick = function() ns.SecretsSvc.SetDone(cur.arg, not done) end }
    end })

ns.Listen("SECRETS_CHANGED", function() J.Refresh() end)
