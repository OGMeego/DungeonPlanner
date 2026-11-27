-- QuestRewards.lua
-- A quest's full rewards for the journal: which items are a choice and which you always get,
-- the money and the reputation, and the XP once the game has shown it.
-- Two sources: the classic database (Data/QuestExtra.lua, CMaNGOS classic-db) and what the
-- game itself showed when you (or anyone in this account) opened the quest. WoW Forever
-- changed many rewards, so what the game showed always wins.
local _, ns = ...
local L = ns.L
local R = {}
ns.QuestRewards = R

local Q_REWARDS, Q_LVL = 9, 2

-- English names for the reputations quests give, used when the game can't name one.
local FACTION = {
    [21] = "Booty Bay", [47] = "Ironforge", [54] = "Gnomeregan Exiles", [59] = "Thorium Brotherhood",
    [68] = "Undercity", [69] = "Darnassus", [72] = "Stormwind", [76] = "Orgrimmar", [81] = "Thunder Bluff",
    [87] = "Bloodsail Buccaneers", [92] = "Gelkis Clan Centaur", [93] = "Magram Clan Centaur",
    [270] = "Zandalar Tribe", [349] = "Ravenholdt", [369] = "Gadgetzan", [470] = "Ratchet",
    [471] = "Wildhammer Clan", [509] = "The League of Arathor", [510] = "The Defilers",
    [529] = "Argent Dawn", [530] = "Darkspear Trolls", [576] = "Timbermaw Hold", [577] = "Everlook",
    [589] = "Wintersaber Trainers", [609] = "Cenarion Circle", [729] = "Frostwolf Clan",
    [730] = "Stormpike Guard", [749] = "Hydraxian Waterlords", [809] = "Shen'dralar",
    [889] = "Warsong Outriders", [890] = "Silverwing Sentinels", [910] = "Brood of Nozdormu",
}

function R.FactionName(id)
    local name = GetFactionInfoByID and ns.Call(GetFactionInfoByID, id)
    if type(name) == "string" and name ~= "" then return name end
    return FACTION[id] or ("#" .. id)
end

-- XP a quest gives you: full up to 5 levels over it, then less (the classic rule).
function R.XPFor(fullXP, questLevel, myLevel)
    if not fullXP or fullXP <= 0 then return 0 end
    local over = (myLevel or 1) - (questLevel or 0)
    local f = over <= 5 and 1 or over == 6 and 0.8 or over == 7 and 0.6 or over == 8 and 0.4 or over == 9 and 0.2 or 0.1
    return math.ceil(fullXP * f)
end

local function store()
    ns.db.learn = ns.db.learn or {}
    ns.db.learn.qrew = ns.db.learn.qrew or {}
    ns.db.learn.qrewTitle = ns.db.learn.qrewTitle or {}
    return ns.db.learn.qrew, ns.db.learn.qrewTitle
end

local function itemIDOf(kind, i)
    local link = GetQuestItemLink and ns.Call(GetQuestItemLink, kind, i)
    local id = link and tonumber(link:match("item:(%d+)"))
    return id
end

-- Read the quest window the game is showing (accepting or handing in).
function R.Learn()
    local qid = GetQuestID and ns.Call(GetQuestID)
    if not qid or qid == 0 then return end
    local e = { c = {}, r = {} }
    for i = 1, (GetNumQuestChoices and ns.Call(GetNumQuestChoices) or 0) do
        local id = itemIDOf("choice", i)
        if id then e.c[#e.c + 1] = id end
    end
    for i = 1, (GetNumQuestRewards and ns.Call(GetNumQuestRewards) or 0) do
        local id = itemIDOf("reward", i)
        if id then e.r[#e.r + 1] = id end
    end
    e.xp = GetRewardXP and ns.Call(GetRewardXP) or nil
    e.money = GetRewardMoney and ns.Call(GetRewardMoney) or nil
    e.lvl = ns.Data.MyLevel()
    local byID, byTitle = store()
    byID[qid] = e
    local title = GetTitleText and ns.Call(GetTitleText)
    if type(title) == "string" and title ~= "" then byTitle[title] = qid end
end
ns.On("QUEST_DETAIL", function() ns.After(0.1, R.Learn) end)
ns.On("QUEST_COMPLETE", function() ns.After(0.1, R.Learn) end)

-- Everything known about a quest's rewards:
-- { choices = {itemID...}, always = {itemID...}, xp = number|nil, money = number|nil,
--   rep = { {name, value}... }, seen = true when the game showed it }
function R.For(qid, title)
    local byID, byTitle = store()
    if not qid and title then qid = byTitle[title] end
    local seen = qid and byID[qid]
    local out = { choices = {}, always = {}, rep = {} }
    local q = qid and ns.DB.quests[qid]
    local x = qid and ns.QuestExtra and ns.QuestExtra[qid]
    if seen then
        out.choices, out.always, out.seen = seen.c or {}, seen.r or {}, true
        out.money = seen.money
        -- the XP shown was for the level you had then: keep it only if that's still you
        if seen.xp and seen.lvl == ns.Data.MyLevel() then out.xp = seen.xp end
    elseif q then
        local list = q[Q_REWARDS] or {}
        local nc = x and x[1] or 0
        for i, id in ipairs(list) do
            if i <= nc then out.choices[#out.choices + 1] = id else out.always[#out.always + 1] = id end
        end
        if x and x[3] > 0 then out.money = x[3] end
    end
    -- No XP from the classic database: WoW Forever pays differently (a dungeon-quest bonus on
    -- top), so only the XP the game itself showed is trustworthy.
    if x and x[4] then
        for i = 1, #x[4], 2 do out.rep[#out.rep + 1] = { R.FactionName(x[4][i]), x[4][i + 1] } end
    end
    return out
end

local function itemText(id)
    local name = (C_Item and C_Item.GetItemNameByID and ns.Call(C_Item.GetItemNameByID, id))
        or (ns.DB.items[id] and ns.DB.items[id][1]) or ("item:" .. id)
    local it = ns.Gear and ns.Gear.Item(id)
    local q = it and it[2] or 1
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    return c and c.hex and (c.hex .. name .. "|r") or name
end

local function money(m)
    if GetCoinTextureString then return GetCoinTextureString(m) end
    local g, s, c = math.floor(m / 10000), math.floor(m / 100) % 100, m % 100
    return (g > 0 and (g .. "g ") or "") .. (s > 0 and (s .. "s ") or "") .. (c > 0 and (c .. "c") or "")
end

-- Add the rewards to the tooltip that's being built. Returns true if anything was added.
function R.AddToTooltip(tt, qid, title)
    local r = R.For(qid, title)
    if #r.choices == 0 and #r.always == 0 and not r.xp and not r.money and #r.rep == 0 then return false end
    tt:AddLine(" ")
    tt:AddLine(r.seen and L.J_REW_SEEN or L.J_REW_TITLE, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
    if #r.choices > 0 then
        tt:AddLine(L.J_REW_CHOOSE, 0.8, 0.8, 0.8)
        for _, id in ipairs(r.choices) do tt:AddLine("  " .. itemText(id) .. (ns.Gear.IsUpgrade(id) and "  |cff40ff40\226\150\178|r" or "")) end
    end
    if #r.always > 0 then
        tt:AddLine(#r.choices > 0 and L.J_REW_ALSO or L.J_REW_GET, 0.8, 0.8, 0.8)
        for _, id in ipairs(r.always) do tt:AddLine("  " .. itemText(id)) end
    end
    if r.xp then tt:AddLine(L.J_REW_XP:format(r.xp), 0.6, 0.6, 1) end
    if r.money then tt:AddLine(money(r.money), 1, 1, 1) end
    for _, rp in ipairs(r.rep) do tt:AddLine(L.J_REW_REP:format(rp[1], rp[2]), 0.4, 0.9, 0.4) end
    return true
end
