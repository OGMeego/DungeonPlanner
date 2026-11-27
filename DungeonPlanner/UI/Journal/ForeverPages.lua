-- ForeverPages.lua
-- Pages for Forever's new dungeons.
local _, ns = ...
local L = ns.L
local J = ns.Journal
local I_NAME, I_QUALITY, I_INV, I_REQ = 1, 2, 3, 4
local Q = ns.Quests
local P = ns.Private("Journal")

function P.foreverOf(a) return a.forever or ns.ForeverFor(a.fullName or a.name) end

local function activityKills(a)
    return ns.Tracker and ns.Tracker.KillsByName and ns.Tracker.KillsByName(P.foreverOf(a) and P.foreverOf(a).name or a.name) or {}
end

-- Overview: bosses in order, how to get in.
function P.activityOverview(a)
    local rows = {}
    local f = P.foreverOf(a)
    local kills = activityKills(a)
    tinsert(rows, { kind = "header", text = L.J_BOSSES, h = 26 })
    if f then
        for i, b in ipairs(f.bosses) do
            local tag = b.secret and ("|cffc099ff" .. L.SECRET_BOSS .. "|r") or b.optional and GRAY_FONT_COLOR:WrapTextInColorCode(L.MAP_OPTIONAL) or
                (b.final and ORANGE_FONT_COLOR:WrapTextInColorCode(L.MAP_FINAL) or nil)
            local names = { f.name, a.name }
            for _, al in ipairs(f.aliases or {}) do tinsert(names, al) end
            local display = ns.EJ and (ns.EJ.Display(names, b.name) or (b.alias and ns.EJ.Display(names, b.alias)))
            local n = 0
            for _, l in ipairs(b.loot or {}) do if l[2] ~= "Quest" and l[2] ~= "Key" then n = n + 1 end end
            tinsert(rows, { kind = "boss", index = i, name = b.name, killed = kills[b.name] or (b.alias and kills[b.alias]), tag = tag,
                display = ns.DMap.DisplayFor(b.name, b.alias, display), level = ns.DMap.LevelFor(f.name, b.name, b.alias) or tostring(f.max),
                lootN = n, h = 64 })
        end
    else
        local bosses = ns.Tracker and ns.Tracker.BossesForName(a.fullName or a.name) or {}
        if #bosses == 0 then tinsert(rows, { kind = "text", h = 40, text = L.J_FOREVER_BOSSES }) end
        for i, name in ipairs(bosses) do tinsert(rows, { kind = "boss", index = i, name = name, killed = kills[name], h = 64 }) end
    end
    if f then
        tinsert(rows, { kind = "spacer", h = 14 })
        tinsert(rows, { kind = "header", text = L.J_GETTING_THERE, h = 26 })
        tinsert(rows, { kind = "text", h = 50, text = L.J_ENTRANCE_TEXT:format(f.zone, f.entrance[1], f.entrance[2], f.note or "") })
    end
    return rows
end

-- Quests: curated ones for my side, then anything the game showed us in the log or learned.
function P.activityQuests(a)
    local rows = {}
    local f = P.foreverOf(a)
    local list = {}
    for i, fq in ipairs(f and f.quests or {}) do
        if Q.ForeverMine(fq) then
            local st = Q.ForeverStatus(fq)
            if not (ns.opt.hideDoneQuests and st == "done") then tinsert(list, { fq = fq, status = st, i = i }) end
        end
    end
    local ORDER = { log = 1, ready = 2, level = 3, done = 4 }
    table.sort(list, function(x, y)
        if ORDER[x.status] ~= ORDER[y.status] then return ORDER[x.status] < ORDER[y.status] end
        return x.i < y.i
    end)
    local known = {}
    local lastGroup
    for _, e in ipairs(list) do
        known[e.fq.title] = true
        local group = P.QUEST_GROUP[e.status]
        if group ~= lastGroup then
            local n = 0
            for _, x in ipairs(list) do if P.QUEST_GROUP[x.status] == group then n = n + 1 end end
            if lastGroup then tinsert(rows, { kind = "spacer", h = 6 }) end
            tinsert(rows, { kind = "header", text = L[group], right = tostring(n), h = 26 })
            lastGroup = group
        end
        tinsert(rows, { kind = "fquest", fq = e.fq, status = e.status, h = (e.fq.obj or (e.fq.zone and e.fq.note) or ns.QuestText.ForTitle(e.fq.title) or ns.QuestText.Warning(nil, e.fq.title)) and 64 or 40 })
    end
    local extra = {}
    for qid, q in pairs(ns.Data.quests) do
        if q.dungeon == a and not known[Q.Title(qid)] then
            tinsert(extra, { kind = "quest", id = qid, status = Q.InLog(qid) and "log" or "ready", subText = L.J_STATUS_LOG, h = 64 })
        end
    end
    if a.mapID and ns.Learn then
        for _, qid in ipairs(ns.Learn.QuestsForMap(a.mapID)) do
            if not known[Q.Title(qid)] then
                local lg = ns.Learn.Giver(qid)
                local place = lg and lg.m and lg.x and { lg.x, lg.y, nil, ui = lg.m }
                tinsert(extra, { kind = "quest", id = qid, status = Q.Status(qid), h = 64, place = place,
                    placeName = lg and lg.name,
                    subText = lg and L.J_FROM:format(lg.name or "?") .. "  " .. L.J_SEEN_FOREVER or L.J_SEEN_FOREVER })
            end
        end
    end
    if #extra > 0 then
        tinsert(rows, { kind = "header", text = L.J_QUESTS_SEEN, h = 26 })
        for _, r in ipairs(extra) do tinsert(rows, r) end
    end
    if #rows == 0 then tinsert(rows, { kind = "text", h = 40, text = L.J_FOREVER_QUESTS }) end
    return rows
end

-- Item ID for a name once the game has seen the item (then it gets real colours and tooltips).
local function itemIDForName(name)
    local link = select(2, ns.Call(C_Item and C_Item.GetItemInfo or GetItemInfo, name))
    local id = link and tonumber(link:match("item:(%d+)"))
    return id
end

-- Loot: curated by boss, then what we've seen drop there.
function P.activityLoot(a, onlyBoss)
    local rows = {}
    if ns.LootFilter.Active() then
        tinsert(rows, { kind = "text", h = 24, text = "|cff60c0ff" .. L.LF_ON .. "|r  " .. GRAY_FONT_COLOR:WrapTextInColorCode(L.LF_ON_HINT) })
    end
    local f = P.foreverOf(a)
    if onlyBoss then
        local fb
        for _, b in ipairs(f and f.bosses or {}) do if b.name == onlyBoss then fb = b end end
        local names = { f and f.name or a.name, a.name }
        local n = 0
        for _, l in ipairs(fb and fb.loot or {}) do if l[2] ~= "Quest" and l[2] ~= "Key" then n = n + 1 end end
        local ejd = ns.EJ and (ns.EJ.Display(names, onlyBoss) or (fb and fb.alias and ns.EJ.Display(names, fb.alias)))
        tinsert(rows, { kind = "bosscard", name = onlyBoss, lootN = n, h = 92,
            level = f and (ns.DMap.LevelFor(f.name, onlyBoss, fb and fb.alias) or tostring(f.max)),
            display = ns.DMap.DisplayFor(onlyBoss, fb and fb.alias, ejd),
            onAll = function() P.current.boss = nil; J.Refresh() end })
    end
    local any = false
    local names = { f and f.name or a.name, a.fullName, a.name }
    for _, al in ipairs(f and f.aliases or {}) do tinsert(names, al) end
    for _, b in ipairs(f and f.bosses or {}) do
        if not onlyBoss or onlyBoss == b.name then
            -- The game's own journal first (real items), then the researched list.
            local ejItems = ns.EJ and ns.EJ.LootForBoss(names, b.name)
            if not ejItems and b.alias and ns.EJ then ejItems = ns.EJ.LootForBoss(names, b.alias) end
            local brows = {}
            if ejItems then
                for _, itemID in ipairs(ejItems) do
                    if (not P.usableOnly or ns.Gear.Usable(itemID) ~= false) and (not itemID or ns.LootFilter.Pass(itemID)) then
                        tinsert(brows, { kind = "item", item = itemID, boss = b.name, forever = true, h = 32 })
                    end
                end
            else
                for _, l in ipairs(b.loot or {}) do
                    if l[2] ~= "Key" then
                        tinsert(brows, { kind = "fitem", name = l[1], slot = l[2] or "", chance = l[3], boss = b.name, itemID = l.id or itemIDForName(l[1]), h = 32 })
                        if l.id and C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, l.id) end
                    end
                end
            end
            if #brows > 0 then
                any = true
                tinsert(rows, { kind = "header", text = b.name, h = 26 })
                for _, r in ipairs(brows) do tinsert(rows, r) end
            end
        end
    end
    if a.mapID and ns.Learn then
        local byNpc, names = {}, ns.db.learn and ns.db.learn.npcNames or {}
        for itemID, npc in pairs(ns.Learn.MapLoot(a.mapID)) do
            local it = ns.Gear.Item(itemID)
            if it and it[I_INV] > 0 and (not P.usableOnly or ns.Gear.Usable(itemID)) and ns.LootFilter.Pass(itemID) then
                if not onlyBoss or names[npc] == onlyBoss then
                    byNpc[npc] = byNpc[npc] or {}
                    tinsert(byNpc[npc], itemID)
                end
            end
        end
        if next(byNpc) then
            tinsert(rows, { kind = "header", text = L.J_LOOT_SEEN, h = 26 })
            for npc, list in pairs(byNpc) do
                local entries = ns.Learn.LootFor(npc)
                local chance = {}
                for _, e in ipairs(entries) do chance[e.item] = e.chance end
                for _, itemID in ipairs(list) do
                    any = true
                    tinsert(rows, { kind = "item", item = itemID, chance = chance[itemID], boss = names[npc], forever = true, h = 32 })
                end
            end
        end
    end
    if not any then tinsert(rows, { kind = "text", h = 40, text = onlyBoss and L.J_NO_LOOT_BOSS or L.J_FOREVER_LOOT }) end
    return rows
end
