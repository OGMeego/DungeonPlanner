-- Score: how good a match a listing (or applicant) is for you, and why.
-- Every point comes with a reason the UI can show, so the order never feels arbitrary.
local _, ns = ...

local Score = {}
ns.Score = Score

local EXPECTED = { tank = 1, healer = 1, dps = 3 }
local ROLE_ORDER = { "tank", "healer", "dps" }
Score.ROLE_ORDER = ROLE_ORDER

Score.GREAT = 70
Score.GOOD = 40

-- Best guess at a party member's role.
local function memberRole(unit)
    local name = ns.Safe(UnitName(unit))
    local peer = ns.Comm.Peer(ns.Key(name))
    if peer and peer.roles then
        for _, r in ipairs(ROLE_ORDER) do if peer.roles[r] then return r end end
    end
    local assigned = ns.Safe(UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit))
    if assigned == "TANK" then return "tank" end
    if assigned == "HEALER" then return "healer" end
    return "dps"
end

-- Roles your current party still needs (you count as your main role).
function Score.GroupNeeds()
    local needs = CopyTable(EXPECTED)
    local mine = ns.Data.MyMainRole()
    needs[mine] = needs[mine] - 1
    if IsInGroup() and not IsInRaid() then
        for i = 1, 4 do
            local unit = "party" .. i
            if UnitExists(unit) then
                local r = memberRole(unit)
                needs[r] = needs[r] - 1
            end
        end
    end
    return needs
end

-- Am I putting a group together (rather than looking to join one)?
function Score.IsLeading()
    if ns.Call(C_LFGList and C_LFGList.HasActiveEntryInfo) then return true end
    return IsInGroup() and UnitIsGroupLeader("player") and true or false
end

-- Open slots in a listed group, by role.
local function openSlots(l)
    local c = l.counts
    if not c then
        c = { tank = 0, healer = 0, dps = 0 }
        for _, m in ipairs(l.members) do
            local r = m.assigned or "dps"
            c[r] = (c[r] or 0) + 1
        end
    end
    return {
        tank = EXPECTED.tank - (c.tank or 0),
        healer = EXPECTED.healer - (c.healer or 0),
        dps = EXPECTED.dps - (c.dps or 0),
    }
end
Score.OpenSlots = openSlots

-- The listing's dungeon that matters to me: the filtered one, else one my level fits.
function Score.BestActivity(l, level)
    local filter = ns.cdb and ns.cdb.dungeonFilter or 0
    for _, a in ipairs(l.activities) do
        if filter > 0 and a.id == filter then return a end
    end
    if filter > 0 then return nil end
    for _, a in ipairs(l.activities) do
        if ns.Data.LevelFits(a, level) then return a end
    end
    return l.activities[1]
end

-- My quests for a dungeon (from quest-log headers and learned quests).
function Score.MyQuestsFor(activity)
    if not activity then return 0 end
    local n = 0
    for _, q in pairs(ns.Data.quests) do
        if q.dungeon and (q.dungeon == activity or q.dungeon.fullName == activity.fullName) then n = n + 1 end
    end
    return n
end

local function social(key, info)
    local D = ns.Data
    local m = D.Memory(key)
    info.friend = D.IsFriend(key)
    info.guild = D.IsGuild(key)
    if m then
        info.fav = m.fav
        info.avoid = m.avoid
        info.before = m.runs and m.runs[1]
    end
    local s = 0
    if info.friend then s = s + 25 end
    if info.guild then s = s + 20 end
    if info.fav then s = s + 30 end
    if info.before then s = s + 8 end
    return s
end

local function peerBits(key, info)
    local peer = ns.Comm.Peer(key)
    if not peer then return 0 end
    info.peer = peer
    local shared, list = ns.Comm.SharedQuests(key)
    info.shared, info.sharedList = shared, list
    return 3 + math.min(shared * 8, 40)
end

-- Score one listing. Returns the score and an info table with the reasons.
function Score.Listing(l)
    local D = ns.Data
    local level = D.MyLevel()
    local myRoles = D.MyRoles()
    local info = {}
    local s = 0

    -- Dungeon and level
    local act = Score.BestActivity(l, level)
    info.activity = act
    if act and D.LevelFits(act, level) then s = s + 15 else s = s - 10 end
    if l.level then
        local diff = math.abs(l.level - level)
        if diff <= 3 then s = s + 10 elseif diff <= 6 then s = s + 5 elseif diff > 10 then s = s - 10 end
    end

    -- Roles
    if l.solo then
        local needs = Score.GroupNeeds()
        local offers = l.roles or {}
        local peer = ns.Comm.Peer(l.key)
        if peer and peer.roles then offers = peer.roles; info.confirmed = true end
        for _, r in ipairs(ROLE_ORDER) do
            if offers[r] and needs[r] > 0 then
                info.fit = true
                info.fitRole = info.fitRole or r
            end
        end
        if info.fit then
            s = s + 40
            if info.fitRole ~= "dps" then s = s + 10 end -- tanks and healers are scarce
        else
            s = s - 10
        end
    else
        local open = openSlots(l)
        info.open = open
        for _, r in ipairs(ROLE_ORDER) do
            if myRoles[r] and open[r] > 0 then
                info.fit = true
                info.fitRole = info.fitRole or r
            end
        end
        if info.fit then
            s = s + 40
        else
            s = s - 40
            info.full = true
        end
    end

    -- Quests: my quests for this dungeon, and quests we share (Dungeon Planner users)
    info.myQuestsHere = Score.MyQuestsFor(act)
    s = s + math.min(info.myQuestsHere * 4, 16)
    s = s + peerBits(l.key, info)
    for _, m in ipairs(l.members) do
        local k = ns.Key(m.name)
        if k and k ~= l.key then
            local shared = ns.Comm.SharedQuests(k)
            if shared > (info.shared or 0) then info.shared = shared end
        end
    end

    -- Gear: upgrades for me in this dungeon
    if act and act.mapID and ns.Gear then
        info.upgrades = ns.Gear.CountForDungeon(act.mapID)
        s = s + math.min(info.upgrades * 2, 10)
    end
    -- Wishlist: items you want drop here
    if act and ns.Wishlist then
        local d = act.mapID and ns.DB.dungeons[act.mapID]
        local f = ns.ForeverFor and ns.ForeverFor(act.fullName or act.name)
        info.wished = #ns.Wishlist.ForDungeon(act.name, act.fullName, d and d.name, f and f.name)
        s = s + math.min(info.wished * 6, 18)
    end

    -- People
    s = s + social(l.key, info)
    if not info.friend and l.numFriends > 0 then info.friend = true; s = s + 20 end
    if not info.guild and l.numGuild > 0 then info.guild = true; s = s + 15 end

    -- Place and time
    local zone = D.MyZone()
    if zone and l.area and l.area == zone then info.near = true; s = s + 6 end
    if l.age < 120 then s = s + 6; info.new = true elseif l.age < 600 then s = s + 3 elseif l.age > 1800 then s = s - 5 end

    info.score = s
    return s, info
end

-- Score an applicant (someone who whispered you about your group).
function Score.Applicant(a)
    local info = {}
    local s = 0
    local needs = Score.GroupNeeds()
    if a.role and needs[a.role] and needs[a.role] > 0 then
        s = s + 40
        info.fit = true
        if a.role ~= "dps" then s = s + 10 end
    elseif a.role then
        s = s - 20
        info.full = true
    end
    if a.level then
        local diff = math.abs(a.level - ns.Data.MyLevel())
        if diff <= 3 then s = s + 10 elseif diff > 8 then s = s - 10 end
    end
    s = s + peerBits(a.key, info)
    s = s + social(a.key, info)
    info.score = s
    return s, info
end

function Score.Label(info)
    if info.full then return ns.L.FULL_FOR_ROLE, GRAY_FONT_COLOR end
    if not info.fit then return nil end
    if info.score >= Score.GREAT then return ns.L.GREAT_MATCH, GREEN_FONT_COLOR end
    if info.score >= Score.GOOD then return ns.L.GOOD_MATCH, NORMAL_FONT_COLOR end
    return nil
end
