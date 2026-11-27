-- Pages.lua
-- Pages for database dungeons: overview, quests, loot, upgrades.
local _, ns = ...
local L = ns.L
local J = ns.Journal
local Q_TITLE, Q_LVL, Q_MIN, Q_FACTION, Q_CLASS, Q_PRE, Q_START, Q_END, Q_REWARDS, Q_MAP, Q_OBJ = 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
local B_ENC, B_NPC, B_NAME, B_LVL = 1, 2, 3, 4
local I_NAME, I_QUALITY, I_INV, I_REQ = 1, 2, 3, 4
local Q = ns.Quests
local P = ns.Private("Journal")

-- ---------------------------------------------------------------------------
-- Pages
-- ---------------------------------------------------------------------------

local function bossKills(mapID)
    return ns.Tracker and ns.Tracker.Kills(mapID) or {}
end

function P.overviewRows(mapID)
    local d = ns.DB.dungeons[mapID]
    local rows = {}
    local kills = bossKills(mapID)
    tinsert(rows, { kind = "header", text = L.J_BOSSES, h = 26 })
    for i, b in ipairs(d.bosses) do
        local ups = 0
        local lootList = ns.DB.loot[b[B_NPC]]
        if lootList then
            for j = 1, #lootList, 2 do if ns.Gear.IsUpgrade(lootList[j]) then ups = ups + 1 end end
        end
        local display = ns.DMap.DisplayFor(b[B_NAME], nil, b[7])
        if not display and ns.EJ then display = ns.EJ.Display({ d.name }, b[B_NAME]) end
        tinsert(rows, { kind = "boss", index = i, name = b[B_NAME], level = b[B_LVL], npc = b[B_NPC], display = display,
            lootN = lootList and math.floor(#lootList / 2) or 0,
            killed = kills[b[B_ENC]] or kills[b[B_NAME]], upgrades = ups, h = 64 })
    end
    local _, counts = Q.ForDungeon(mapID)
    tinsert(rows, { kind = "spacer", h = 14 })
    tinsert(rows, { kind = "header", text = L.J_READINESS, h = 26 })
    tinsert(rows, { kind = "text", h = 54, text = L.J_READINESS_TEXT:format(counts.log, counts.ready, counts.done, counts.level + counts.locked) })
    return rows
end

local STATUS_ORDER = { log = 1, ready = 2, inside = 3, level = 4, locked = 5, done = 6 }
-- Quest lists are split into sections, the ones you have first.
P.QUEST_GROUP = { log = "J_GROUP_LOG", ready = "J_GROUP_READY", inside = "J_GROUP_INSIDE", level = "J_GROUP_LATER", locked = "J_GROUP_LATER", done = "J_GROUP_DONE" }

function P.questRows(mapID)
    local list = Q.ForDungeon(mapID)
    if ns.opt.hideDoneQuests then
        for i = #list, 1, -1 do if list[i].status == "done" then tremove(list, i) end end
    end
    table.sort(list, function(a, b)
        if STATUS_ORDER[a.status] ~= STATUS_ORDER[b.status] then return STATUS_ORDER[a.status] < STATUS_ORDER[b.status] end
        local qa, qb = Q.Info(a.id), Q.Info(b.id)
        return (qa and qa[Q_LVL] or 0) < (qb and qb[Q_LVL] or 0)
    end)
    local rows = {}
    if #list == 0 then
        tinsert(rows, { kind = "text", h = 40, text = L.J_NO_QUESTS })
    end
    local lastGroup
    for _, e in ipairs(list) do
        local group = P.QUEST_GROUP[e.status]
        if group ~= lastGroup then
            local n = 0
            for _, x in ipairs(list) do if P.QUEST_GROUP[x.status] == group then n = n + 1 end end
            if lastGroup then tinsert(rows, { kind = "spacer", h = 6 }) end
            tinsert(rows, { kind = "header", text = L[group], right = tostring(n), h = 26 })
            lastGroup = group
        end
        local q = Q.Info(e.id)
        local s, en = q and q[Q_START], q and q[Q_END]
        local giver, place, placeName
        if s then
            if s[1] == "U" then giver = ns.DB.npcs[s[2]]
            elseif s[1] == "O" then giver = ns.DB.npcs[-s[2]]
            elseif s[1] == "I" then giver = L.J_STARTS_FROM_ITEM:format(P.itemName(s[2])) end
            if s[3] then
                place = { s[3], s[4], s[5] }
                placeName = giver
            end
        end
        local lg = ns.Learn and ns.Learn.Giver(e.id)
        if lg then
            giver = lg.name or giver
            if lg.m and lg.x then
                place = { lg.x, lg.y, nil, ui = lg.m }
                placeName = giver
            end
        end
        local where = place and (place.ui and ns.Maps.UiPlaceText(place.ui) or ns.Maps.PlaceText(place[3]))
        local fromItem = s and s[1] == "I"
        local sub = giver and ((fromItem and giver or L.J_FROM:format(giver)) .. (where and (" · " .. where) or "") .. (lg and ("  " .. L.J_SEEN_FOREVER) or "")) or ""
        if e.status == "log" then sub = L.J_STATUS_LOG end
        if e.status == "inside" then
            local _, src = Q.StartsInside(e.id)
            sub = "|cffb0a0ff" .. L.J_STARTS_INSIDE:format(P.itemName(s[2]), src and src.boss or "?") .. "|r"
            place, placeName = nil, nil
        end
        local endName = en and (en[1] == "U" and ns.DB.npcs[en[2]] or en[1] == "O" and ns.DB.npcs[-en[2]])
        tinsert(rows, { kind = "quest", id = e.id, q = q, status = e.status, subText = sub, place = place,
            placeName = placeName, endName = endName,
            h = ((q and q[Q_OBJ] and q[Q_OBJ] ~= "") or ns.QuestText.For(e.id) or ns.QuestText.Warning(e.id, Q.Title(e.id)) or (ns.QuestTips and ns.QuestTips[e.id] and ns.QuestTips[e.id].out)) and 66 or 40 })
    end
    return rows
end

local function bossLootRows(b)
    local lootList = ns.Gear.LootList(b[B_NPC])
    local base = ns.DB.loot[b[B_NPC]]
    local inBase = {}
    if base then for i = 1, #base, 2 do inBase[base[i]] = true end end
    local seenHere = {}
    for _, e in ipairs(ns.Learn and ns.Learn.LootFor(b[B_NPC]) or {}) do seenHere[e.item] = true end
    local items = {}
    if lootList then
        for i = 1, #lootList, 2 do
            local itemID = lootList[i]
            local it = ns.Gear.Item(itemID)
            local isRecipe = ns.Gear.IsRecipe(itemID)
            local isEquip = it and it[I_INV] > 0
            if (isRecipe or (isEquip and (not P.usableOnly or ns.Gear.Usable(itemID)))) and ns.LootFilter.Pass(itemID) then
                tinsert(items, { kind = "item", item = itemID, chance = lootList[i + 1], h = 32,
                    forever = not inBase[itemID], seen = seenHere[itemID] })
            end
        end
    end
    return items
end

function P.lootRows(mapID, onlyNpc)
    local d = ns.DB.dungeons[mapID]
    local rows = {}
    if ns.LootFilter.Active() then
        tinsert(rows, { kind = "text", h = 24, text = "|cff60c0ff" .. L.LF_ON .. "|r  " .. GRAY_FONT_COLOR:WrapTextInColorCode(L.LF_ON_HINT) })
    end
    -- Filtered to one boss (clicked on the Overview): say so, and offer the way back.
    if onlyNpc then
        for _, b in ipairs(d.bosses) do
            if b[B_NPC] == onlyNpc then
                local items = bossLootRows(b)
                local display = ns.DMap.DisplayFor(b[B_NAME], nil, b[7])
                if not display and ns.EJ then display = ns.EJ.Display({ d.name }, b[B_NAME]) end
                tinsert(rows, { kind = "bosscard", name = b[B_NAME], level = b[B_LVL], display = display, lootN = #items, h = 92,
                    onAll = function() J.ShowDungeon(P.current.map, 3) end })
                if #items == 0 then
                    tinsert(rows, { kind = "text", h = 40, text = L.J_BOSS_NO_LOOT:format(b[B_NAME]) })
                    onlyNpc = nil -- and show everyone else's loot below
                else
                    for _, r in ipairs(items) do tinsert(rows, r) end
                    return rows
                end
            end
        end
    end
    local any = false
    for _, b in ipairs(d.bosses) do
        local items = bossLootRows(b)
        if #items > 0 then
            any = true
            tinsert(rows, { kind = "header", text = b[B_NAME], h = 26 })
            for _, r in ipairs(items) do tinsert(rows, r) end
        end
    end
    -- Good drops from the dungeon's other creatures.
    local trash = ns.DB.trash and ns.DB.trash[mapID]
    if trash then
        local trows = {}
        for i = 1, #trash, 3 do
            local item, chance, npc = trash[i], trash[i + 1], trash[i + 2]
            if (ns.Gear.IsRecipe(item) or not P.usableOnly or ns.Gear.Usable(item)) and ns.LootFilter.Pass(item) then
                tinsert(trows, { kind = "item", item = item, chance = chance, boss = ns.DB.npcs[npc], h = 32 })
            end
        end
        if #trows > 0 then
            any = true
            tinsert(rows, { kind = "header", text = L.J_TRASH, h = 26 })
            for _, r in ipairs(trows) do tinsert(rows, r) end
        end
    end
    if not any then
        tinsert(rows, { kind = "text", h = 40, text = P.usableOnly and L.J_NO_LOOT or L.J_NO_LOOT_AT_ALL })
    end
    return rows
end

local function upgradeRows()
    local rows = {}
    local list = ns.Gear.Upgrades()
    local perSlot = {}
    for _, u in ipairs(list) do
        perSlot[u.slot] = (perSlot[u.slot] or 0) + 1
        if perSlot[u.slot] <= 3 then
            tinsert(rows, { kind = "item", item = u.item, chance = u.chance,
                boss = u.boss .. ", " .. (ns.DB.dungeons[u.map] and ns.DB.dungeons[u.map].name or ""), h = 32 })
        end
    end
    if #rows == 0 then
        tinsert(rows, { kind = "text", h = 60, text = L.J_NO_UPGRADES })
    else
        tinsert(rows, 1, { kind = "text", h = 34, text = GRAY_FONT_COLOR:WrapTextInColorCode(L.J_UPGRADES_NOTE:format(ns.Data.RoleName(ns.Data.MyMainRole()))) })
    end
    return rows
end

J.RegisterPage("upgrades", { nav = L.J_UPGRADES, icon = "bags-greenarrow", order = 10,
    title = function() return L.J_UPGRADES end,
    sub = function() return L.J_UPGRADES_SUB end,
    rows = upgradeRows })
