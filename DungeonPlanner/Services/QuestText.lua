-- QuestText: the quest's own words. When you read a quest at its giver, or have it in your
-- log, its objective and description are kept, so the journal can show what every quest
-- actually asks, plus a warning line for the tricky ones (Data/QuestWarnings.lua).
-- Saved: ns.db.questText[questID] = { obj, text, title }
local _, ns = ...

local QT = {}
ns.QuestText = QT

local MAX_TEXT = 600

local function store(id, title, obj, text)
    id = ns.Safe(id)
    if not (id and id > 0 and ns.db) then return end
    obj, text, title = ns.Safe(obj), ns.Safe(text), ns.Safe(title)
    if not (obj and obj ~= "") and not (text and text ~= "") then return end
    ns.db.questText = ns.db.questText or {}
    local old = ns.db.questText[id] or {}
    ns.db.questText[id] = { obj = (obj ~= "" and obj) or old.obj, text = text and text:sub(1, MAX_TEXT) or old.text, title = title or old.title }
    if title then
        ns.db.titleIDs = ns.db.titleIDs or {}
        ns.db.titleIDs[title] = ns.db.titleIDs[title] or id
    end
end
QT.Store = store

function QT.For(id)
    return id and ns.db and ns.db.questText and ns.db.questText[id]
end

function QT.ForTitle(title)
    local id = title and ns.db and ns.db.titleIDs and ns.db.titleIDs[title]
    return QT.For(id)
end

function QT.Warning(id, title)
    local W = ns.QuestWarnings
    if not W then return nil end
    local tr = ns.LocaleNotes and ns.LocaleNotes.warn
    local t = tr and ((id and tr[id]) or (title and tr[title]))
    if t then return t end
    return (id and W.byID[id]) or (title and W.byTitle[title]) or nil
end

-- At the quest giver.
ns.On("QUEST_DETAIL", function()
    local id = ns.Call(GetQuestID)
    store(id, ns.Call(GetTitleText), ns.Call(GetObjectiveText), ns.Call(GetQuestText))
end)

-- From your quest log: read the text of dungeon quests we don't have words for yet.
local function scanLog()
    if InCombatLockdown() or not (C_QuestLog and C_QuestLog.SetSelectedQuest and GetQuestLogQuestText) then return end
    local old = ns.Call(C_QuestLog.GetSelectedQuest)
    local changed = false
    for id, q in pairs(ns.Data.quests or {}) do
        if not QT.For(id) then
            pcall(C_QuestLog.SetSelectedQuest, id)
            local text, obj = ns.Call(GetQuestLogQuestText)
            store(id, q.title, obj, text)
            changed = true
        end
    end
    if changed and old then pcall(C_QuestLog.SetSelectedQuest, old) end
end
ns.Listen("QUESTS_CHANGED", function() ns.After(2, scanLog) end)

-- Tips worked out from the quest data (Data/QuestTips.lua): where its items drop, whether
-- part of it is outside the dungeon, which quests need the same boss. A list of lines.
function QT.Tips(id)
    local t = id and ns.QuestTips and ns.QuestTips[id]
    if not t then return {} end
    local L = ns.L
    local out = {}
    if t.out then tinsert(out, { kind = "out", text = L.TIP_OUTSIDE }) end
    for _, d in ipairs(t.drops or {}) do
        local name = d[3] and ns.Safe(ns.Call(C_Item and C_Item.GetItemNameByID, d[3]))
        tinsert(out, { kind = "drop", text = L.TIP_DROPS:format(name or d[1], d[2]) })
    end
    if t.with then
        local names = {}
        for _, q in ipairs(t.with) do tinsert(names, ns.Quests.Title(q)) end
        tinsert(out, { kind = "with", text = L.TIP_WITH:format(table.concat(names, ", ")) })
    end
    return out
end
