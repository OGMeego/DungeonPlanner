-- ExtrasPages.lua
-- Onyxia: your progress through the attunement chain for your faction.
-- Tier Sets: the Tier 0 and Tier 0.5 dungeon sets, where each piece comes from, and which
-- you already have.
local _, ns = ...
local L = ns.L
local J = ns.Journal
local P = ns.Private("Journal")
local Q = ns.Quests

-- ------------------------------------------------------------------ Onyxia
local function mySide() return UnitFactionGroup("player") == "Alliance" and "A" or "H" end

local function onyChain(side)
    return ns.OnyxiaChain and ns.OnyxiaChain[side or mySide()] or {}
end

local function onyProgress(side)
    local done = 0
    for _, q in ipairs(onyChain(side)) do if Q.IsDone(q[1]) then done = done + 1 end end
    return done, #onyChain(side)
end

-- Alliance and Horde do different chains: a tab for each, yours first.
local function onyRows(cur)
    local rows = {}
    local side = cur.side or mySide()
    tinsert(rows, { kind = "tabs", h = 30, tabs = {
        { text = L.SECRET_SIDE_A, selected = side == "A", onClick = function() cur.side = "A"; J.Refresh() end },
        { text = L.SECRET_SIDE_H, selected = side == "H", onClick = function() cur.side = "H"; J.Refresh() end },
    } })
    local done, total = onyProgress(side)
    local level = ns.Data.MyLevel()
    local start = side == "A" and 48 or 55
    tinsert(rows, { kind = "text", h = 40, text = L.ONY_INTRO:format(start) })
    if side == mySide() and level < start then tinsert(rows, { kind = "text", h = 24, text = ORANGE_FONT_COLOR:WrapTextInColorCode(L.ONY_TOO_LOW:format(start)) }) end
    tinsert(rows, { kind = "header", text = L.ONY_STEPS, right = L.ONY_PROGRESS:format(done, total), h = 26 })
    local current
    for i, q in ipairs(onyChain(side)) do
        local id, title = q[1], q[2]
        local isDone, inLog = Q.IsDone(id), Q.InLog(id)
        if not isDone and not current then current = i end
        tinsert(rows, { kind = "line", h = 30, boxed = false,
            atlas = isDone and "common-icon-checkmark" or (inLog and "QuestTurnin" or "QuestNormal"), iconSize = 16,
            text = ("%d. %s"):format(i, title),
            color = isDone and { 0.55, 0.55, 0.55 } or (i == current and { 1, 0.82, 0 } or { 1, 1, 1 }),
            right = inLog and GREEN_FONT_COLOR:WrapTextInColorCode(L.J_TAG_IN_LOG) or "",
            logQuest = inLog and id or nil,
            onClick = function() if inLog then Q.OpenInLog(id) end end })
    end
    if done == total and total > 0 then
        tinsert(rows, { kind = "text", h = 30, text = GREEN_FONT_COLOR:WrapTextInColorCode(L.ONY_DONE) })
    end
    tinsert(rows, { kind = "spacer", h = 8 })
    tinsert(rows, { kind = "line", h = 34, icon = "Interface\\Icons\\INV_Misc_Key_14", iconSize = 22, text = L.ONY_SECRET,
        onClick = function() J.ShowPage("secret", "onyxia"); P.current.side = side; J.Refresh() end })
    return rows
end

J.RegisterPage("onyxia", { nav = L.ONY_TITLE, iconTex = "Interface\\Icons\\INV_Jewelry_Talisman_11", order = 34,
    count = function() local d, t = onyProgress() return (d > 0 and d < t) and (t - d) or nil end,
    title = function() return L.ONY_TITLE end,
    sub = function() local d, t = onyProgress() return L.ONY_PROGRESS:format(d, t) end,
    rows = onyRows })

-- ------------------------------------------------------------------ Tier sets
local function owned(id)
    return (ns.Call(GetItemCount, id, true) or 0) > 0 or (IsEquippedItem and ns.Call(IsEquippedItem, id)) or false
end

local CLASS_ORDER = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }

local function setRows(rows, tierKey, tierName, class)
    local set = ns.TierSets and ns.TierSets[tierKey] and ns.TierSets[tierKey][class]
    if not set then return end
    local have = 0
    for _, it in ipairs(set.items) do if owned(it[1]) then have = have + 1 end end
    tinsert(rows, { kind = "header", text = ("%s: %s"):format(tierName, set.name), right = L.TIER_HAVE:format(have, #set.items), h = 26 })
    for _, it in ipairs(set.items) do
        local src = ns.ItemSources.For(it[1])
        local where
        if src and src[1] then where = ns.ItemSources.Text(src[1])
        elseif it.q then where = L.TIER_FROM_QUEST:format(Q.Title(it.q)) end
        if owned(it[1]) then where = GREEN_FONT_COLOR:WrapTextInColorCode(L.TIER_OWNED) .. (where and ("  " .. where) or "") end
        tinsert(rows, { kind = "item", item = it[1], boss = where, bossName = src and src[1] and src[1].boss,
            dungeon = src and src[1] and src[1].dungeon, h = 32 })
    end
    tinsert(rows, { kind = "spacer", h = 6 })
end

local function tierRows(cur)
    local rows = { { kind = "text", h = 34, text = GRAY_FONT_COLOR:WrapTextInColorCode(L.TIER_HINT) } }
    local classes = cur.arg == "all" and CLASS_ORDER or { ns.Data.MyClass() }
    for _, class in ipairs(classes) do
        if cur.arg == "all" then tinsert(rows, { kind = "header", text = ns.ClassName(class) or class, h = 26 }) end
        setRows(rows, "T0", L.TIER_0, class)
        setRows(rows, "T05", L.TIER_05, class)
    end
    return rows
end

J.RegisterPage("tiers", { nav = L.TIER_TITLE, iconTex = "Interface\\Icons\\INV_Chest_Plate03", order = 12,
    title = function() return L.TIER_TITLE end,
    sub = function(cur) return cur.arg == "all" and L.TIER_SUB_ALL or L.TIER_SUB:format(ns.ClassName(ns.Data.MyClass()) or "") end,
    rows = tierRows,
    button = function(cur)
        return { text = cur.arg == "all" and L.TIER_MINE or L.TIER_ALL,
            onClick = function() J.ShowPage("tiers", cur.arg ~= "all" and "all" or nil) end }
    end })

-- ------------------------------------------------------------------ Tier 0.5 chain
-- The long quest chain that upgrades the Tier 0 dungeon set to Tier 0.5, step by step, with
-- your own class's quests and ticks for the steps you've done.
local function t05Done(step, side, class)
    for _, id in ipairs(ns.Tier05Ids(step, side, class)) do if Q.IsDone(id) then return true, id end end
    return false
end

local function t05InLog(step, side, class)
    for _, id in ipairs(ns.Tier05Ids(step, side, class)) do if Q.InLog(id) then return id end end
end

local function t05Progress(side, class)
    local done = 0
    for _, step in ipairs(ns.Tier05Chain or {}) do if t05Done(step, side, class) then done = done + 1 end end
    return done, #(ns.Tier05Chain or {})
end

local function t05Rows(cur)
    local rows = {}
    local side = cur.side or mySide()
    local class = ns.Data.MyClass()
    tinsert(rows, { kind = "tabs", h = 30, tabs = {
        { text = L.SECRET_SIDE_A, selected = side == "A", onClick = function() cur.side = "A"; J.Refresh() end },
        { text = L.SECRET_SIDE_H, selected = side == "H", onClick = function() cur.side = "H"; J.Refresh() end },
    } })
    tinsert(rows, { kind = "text", h = 54, text = L.T05_INTRO })
    if ns.Data.MyLevel() < 58 then tinsert(rows, { kind = "text", h = 24, text = ORANGE_FONT_COLOR:WrapTextInColorCode(L.T05_TOO_LOW) }) end
    local done, total = t05Progress(side, class)
    tinsert(rows, { kind = "header", text = L.ONY_STEPS, right = L.ONY_PROGRESS:format(done, total), h = 26 })
    local current
    for i, step in ipairs(ns.Tier05Chain or {}) do
        local isDone = t05Done(step, side, class)
        local logID = t05InLog(step, side, class)
        if not isDone and not current then current = i end
        local ids = ns.Tier05Ids(step, side, class)
        local title = (#ids == 1 or type(step[2]) == "table" and step[2].class) and Q.Title(ids[1]) or step[1]
        if title:sub(1, 1) == "#" then title = step[1] end
        tinsert(rows, { kind = "line", h = 44, boxed = false,
            atlas = isDone and "common-icon-checkmark" or (logID and "QuestTurnin" or "QuestNormal"), iconSize = 16,
            text = ("%d. %s"):format(i, title),
            sub = L["T05_" .. step[3]],
            color = isDone and { 0.55, 0.55, 0.55 } or (i == current and { 1, 0.82, 0 } or { 1, 1, 1 }),
            right = logID and GREEN_FONT_COLOR:WrapTextInColorCode(L.J_TAG_IN_LOG) or "",
            logQuest = logID,
            onClick = function() if logID then Q.OpenInLog(logID) end end })
    end
    if done == total and total > 0 then
        tinsert(rows, { kind = "text", h = 30, text = GREEN_FONT_COLOR:WrapTextInColorCode(L.T05_DONE) })
    end
    tinsert(rows, { kind = "spacer", h = 8 })
    tinsert(rows, { kind = "line", h = 34, icon = "Interface\\Icons\\INV_Chest_Plate03", iconSize = 22, text = L.T05_SEE_SETS,
        onClick = function() J.ShowPage("tiers") end })
    return rows
end

J.RegisterPage("tier05", { nav = L.T05_TITLE, iconTex = "Interface\\Icons\\INV_Misc_Bag_10_Black", order = 13,
    count = function()
        local d, t = t05Progress(mySide(), ns.Data.MyClass())
        return (d > 0 and d < t) and (t - d) or nil
    end,
    title = function() return L.T05_TITLE end,
    sub = function() local d, t = t05Progress(mySide(), ns.Data.MyClass()) return L.ONY_PROGRESS:format(d, t) end,
    rows = t05Rows })
