-- Comm: a quiet background network between Dungeon Planner users. It shares only what the
-- Group Finder can't: your confirmed role and the dungeon quests in your log. No servers,
-- no websites: addon messages over a hidden channel, plus a direct message to anyone you
-- whisper through the planner.
local _, ns = ...

local Comm = {}
ns.Comm = Comm

local CHANNEL = "DungeonPlannerNet"
local SEP = ";"
local MAX_QUESTS = 24
local MAX_ACTS = 6
local BROADCAST_MIN = 30      -- seconds between our broadcasts
local HEARTBEAT = 120         -- re-announce while you are looking for a group
local PEER_TTL = 20 * 60      -- forget peers we have not heard from

Comm.groupUsers = {}          -- lower-case name -> true: group members we've heard from
Comm.peers = {}               -- key -> { name, class, level, roles, zone, acts, quests, listed, seen }
Comm.status = "off"

local lastBroadcast = 0
local lastAnswer = 0
local channelId

-- ---------------------------------------------------------------------------
-- Encoding
-- ---------------------------------------------------------------------------

local function clean(s)
    s = tostring(s or "")
    return (s:gsub("[;|\n\r]", " "))
end

local function rolesString(r)
    return (r.tank and "T" or "") .. (r.healer and "H" or "") .. (r.dps and "D" or "")
end

local function parseRoles(s)
    s = s or ""
    return { tank = s:find("T") ~= nil, healer = s:find("H") ~= nil, dps = s:find("D") ~= nil }
end

local function splitNumbers(s)
    local out = {}
    for n in (s or ""):gmatch("%d+") do tinsert(out, tonumber(n)) end
    return out
end

local function activeActivities()
    local entry = ns.Call(C_LFGList and C_LFGList.GetActiveEntryInfo)
    local ids = type(entry) == "table" and ns.Field(entry, "activityIDs")
    local out = {}
    if type(ids) == "table" then
        for i = 1, math.min(#ids, MAX_ACTS) do
            local id = ns.Safe(ids[i])
            if id then tinsert(out, id) end
        end
    end
    if #out == 0 and ns.cdb and ns.cdb.dungeonFilter and ns.cdb.dungeonFilter > 0 then
        out[1] = ns.cdb.dungeonFilter
    end
    return out, type(entry) == "table"
end

function Comm.Payload()
    local D = ns.Data
    local acts, listed = activeActivities()
    return table.concat({
        "H", ns.PROTOCOL, D.MyClass() or "", D.MyLevel(), rolesString(D.MyRoles()),
        clean(D.MyZone()), table.concat(acts, ","), table.concat(D.QuestIDs(MAX_QUESTS), ","),
        listed and "1" or "0", ns.VERSION or "",
    }, SEP)
end

-- ---------------------------------------------------------------------------
-- Sending
-- ---------------------------------------------------------------------------

-- The last few messages in and out, for /dp comm.
Comm.log = {}
local function note(line)
    tinsert(Comm.log, ("%s %s"):format(date("%H:%M:%S"), line))
    if #Comm.log > 30 then tremove(Comm.log, 1) end
end
Comm.Note = note

local function send(text, chatType, target)
    if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then note("out: no SendAddonMessage") return false end
    local ok, result = pcall(C_ChatInfo.SendAddonMessage, ns.PREFIX, text, chatType, target)
    local kind = tostring(text):match("^[^;]*")
    if chatType ~= "CHANNEL" then note(("out %s to %s: %s"):format(kind, chatType, ok and tostring(result) or ("error " .. tostring(result)))) end
    if not ok then return false end
    return result == nil or result == 0 or result == true, result
end

local function canSend()
    if not (ns.opt and ns.opt.network) then return false end
    if InCombatLockdown() then return false end
    local inInstance = IsInInstance and IsInInstance()
    return not inInstance
end

local function channelReady()
    if not channelId then return false end
    local id = GetChannelName(CHANNEL)
    channelId = (id and id > 0) and id or nil
    return channelId ~= nil
end

function Comm.Broadcast(force)
    if not canSend() or not channelReady() then return end
    local now = GetTime()
    if not force and now - lastBroadcast < BROADCAST_MIN then return end
    lastBroadcast = now
    send(Comm.Payload(), "CHANNEL", tostring(channelId))
end

-- Ask everyone listening to announce themselves (when you open the planner).
function Comm.Ask()
    if not canSend() or not channelReady() then return end
    send("R" .. SEP .. ns.PROTOCOL, "CHANNEL", tostring(channelId))
    Comm.Broadcast(true)
end

-- Tell one player about you (sent with planner whispers, so their inbox knows you).
function Comm.Tell(name)
    if not canSend() or not name then return end
    send(Comm.Payload(), "WHISPER", name)
end

-- Learned facts (loot, quest givers) go out one message at a time, slowly.
local outbox = {}
local sending = false
local function pump()
    if #outbox == 0 then sending = false return end
    sending = true
    if not (canSend() and channelReady()) then
        ns.After(15, pump) -- inside a dungeon or in combat: hold the messages until later
        return
    end
    send(tremove(outbox, 1), "CHANNEL", tostring(channelId))
    ns.After(2, pump)
end
local function queue(msg)
    if not (ns.opt and ns.opt.network) or #outbox > 30 then return end
    tinsert(outbox, msg)
    if not sending then pump() end
end

function Comm.ShareLoot(npcID, mapID, items)
    local list = {}
    for i = 1, math.min(#items, 12) do list[i] = items[i] end
    queue(table.concat({ "L", npcID, mapID or 0, table.concat(list, ",") }, SEP))
end

function Comm.ShareGiver(questID, npcID, name, uiMapID, x, y)
    queue(table.concat({ "G", questID, npcID, uiMapID or 0, x or 0, y or 0, clean(name):sub(1, 40) }, SEP))
end

-- ---------------------------------------------------------------------------
-- Receiving
-- ---------------------------------------------------------------------------

-- Other modules handle their own message kinds: Comm.Handle("Q", function(parts, sender, key, channel) end)
local handlers = {}
function Comm.Handle(kind, fn) handlers[kind] = fn end
handlers.P = function(parts, sender) Comm.Group("PO" .. SEP .. ns.VERSION) end
handlers.PO = function(parts, sender)
    if ns.VersionCheck and parts[2] then ns.VersionCheck.Saw(parts[2], sender) end
    ns.Say(("%s has Dungeon Planner v%s and can hear you."):format(ns.Display(sender), tostring(parts[2]))) end

local function receive(text, sender, channel)
    local key = ns.Key(sender)
    if not key or key == ns.Key(ns.Data.MyName()) then return end
    local parts = { strsplit(SEP, text) }
    local kind = parts[1]
    if kind == "H" then
        local quests = {}
        for _, id in ipairs(splitNumbers(parts[8])) do quests[id] = true end
        Comm.peers[key] = {
            name = sender,
            class = parts[3] ~= "" and parts[3] or nil,
            level = tonumber(parts[4]),
            roles = parseRoles(parts[5]),
            zone = parts[6] ~= "" and parts[6] or nil,
            acts = splitNumbers(parts[7]),
            quests = quests,
            listed = parts[9] == "1",
            version = parts[10] ~= "" and parts[10] or nil,
            seen = ns.Now(),
        }
        if parts[10] and ns.VersionCheck then ns.VersionCheck.Saw(parts[10], sender) end
        ns.Fire("PEERS_CHANGED", key)
    elseif kind == "L" and ns.Learn then
        local npc, map = tonumber(parts[2]), tonumber(parts[3])
        local items = splitNumbers(parts[4])
        if npc and #items > 0 and #items <= 12 then
            ns.Learn.AddKillLoot(npc, map ~= 0 and map or nil, items)
        end
    elseif kind == "G" and ns.Learn then
        local qid, npc, m = tonumber(parts[2]), tonumber(parts[3]), tonumber(parts[4])
        local x, y = tonumber(parts[5]), tonumber(parts[6])
        if qid and npc then
            ns.Learn.AddGiver(qid, "start", npc, parts[7] ~= "" and parts[7] or nil,
                m ~= 0 and m or nil, x ~= 0 and x or nil, y ~= 0 and y or nil, true)
        end
    elseif kind == "R" then
        -- Answer later and at random, so a request doesn't make everyone reply at once.
        local now = GetTime()
        if now - lastAnswer > 60 then
            lastAnswer = now
            ns.After(1 + math.random() * 5, function() Comm.Broadcast(true) end)
        end
    elseif handlers[kind] then
        handlers[kind](parts, sender, key, channel)
    end
end

function Comm.Peer(key)
    local p = key and Comm.peers[key]
    if p and ns.Now() - p.seen > PEER_TTL then
        Comm.peers[key] = nil
        return nil
    end
    return p
end

-- Quest IDs both of us have.
function Comm.SharedQuests(key)
    local p = Comm.Peer(key)
    if not (p and p.quests) then return 0, nil end
    local n, list = 0, {}
    for id in pairs(p.quests) do
        local mine = ns.Data.quests[id]
        if mine then
            n = n + 1
            tinsert(list, mine.title)
        end
    end
    return n, list
end

ns.On("CHAT_MSG_ADDON", function(prefix, text, channel, sender)
    if ns.Safe(prefix) ~= ns.PREFIX then return end
    text, sender = ns.Safe(text), ns.Safe(sender)
    if not (text and sender) then note("in: unreadable message (hidden by the game)") return end
    if channel ~= "CHANNEL" then
        note(("in %s from %s (%s)"):format(text:match("^[^;]*"), sender, tostring(channel)))
        local short = ns.Short(sender)
        if short then Comm.groupUsers[strlower(short)] = true end
    end
    receive(text, sender, ns.Safe(channel))
end)

-- Your group only (party, raid or instance group). Never a whisper, never in combat.
function Comm.GroupChannel()
    if IsInGroup and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
    if IsInRaid and IsInRaid() then return "RAID" end
    if IsInGroup and IsInGroup() then return "PARTY" end
end
function Comm.Group(text, tries)
    if not (ns.opt and ns.opt.partyShare) then note("out: party sharing is off") return false end
    if InCombatLockdown() then
        ns.After(5, function() Comm.Group(text, tries) end)
        return false
    end
    local ch = Comm.GroupChannel()
    if not ch then return false end
    local ok = send(text, ch)
    -- Throttled or refused: try again a little later (twice at most).
    if not ok and (tries or 0) < 2 then ns.After(3, function() Comm.Group(text, (tries or 0) + 1) end) end
    return ok
end

-- /dp comm: is the group link working? Shows the state and pings the group;
-- every Dungeon Planner user in it answers with their version.
function Comm.Check()
    local reg = C_ChatInfo and C_ChatInfo.IsAddonMessagePrefixRegistered and C_ChatInfo.IsAddonMessagePrefixRegistered(ns.PREFIX)
    ns.Say(("Dungeon Planner v%s | group: %s | party sharing: %s | prefix registered: %s"):format(
        ns.VERSION, tostring(Comm.GroupChannel() or "not grouped"), tostring(ns.opt and ns.opt.partyShare), tostring(reg)))
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix and not reg then pcall(C_ChatInfo.RegisterAddonMessagePrefix, ns.PREFIX) end
    if Comm.GroupChannel() then Comm.Group("P" .. SEP .. ns.VERSION) end
    ns.After(4, function()
        ns.Say("last messages:")
        for i = math.max(1, #Comm.log - 12), #Comm.log do ns.Say("  " .. Comm.log[i]) end
    end)
end
-- Learned facts for everyone on the network (sent slowly, never from inside a dungeon).
function Comm.Queue(msg) queue(msg) end
Comm.SEP = SEP
Comm.Clean = clean

-- ---------------------------------------------------------------------------
-- Channel
-- ---------------------------------------------------------------------------

-- Hide our channel's join/leave notices from the chat window.
local function noticeFilter(_, _, _, _, _, _, _, _, _, _, channelName)
    if type(channelName) == "string" and ns.Safe(channelName) and channelName:find(CHANNEL, 1, true) then
        return true
    end
end

local function addFilter(event, fn)
    local add = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
    if add then pcall(add, event, fn) end
end

function Comm.Join()
    if not (ns.opt and ns.opt.network) then Comm.status = "off" return end
    local id = GetChannelName(CHANNEL)
    if id and id > 0 then
        channelId = id
        Comm.status = "on"
        return
    end
    local join = JoinTemporaryChannel or JoinChannelByName
    if join and pcall(join, CHANNEL) then
        ns.After(2, function()
            local newId = GetChannelName(CHANNEL)
            channelId = (newId and newId > 0) and newId or nil
            Comm.status = channelId and "on" or "unavailable"
            if channelId then Comm.Broadcast(true) end
        end)
    else
        Comm.status = "unavailable"
    end
end

function Comm.Leave()
    if GetChannelName(CHANNEL) > 0 and LeaveChannelByName then pcall(LeaveChannelByName, CHANNEL) end
    channelId = nil
    Comm.status = "off"
end

function Comm.SetEnabled(on)
    ns.opt.network = on and true or false
    if on then Comm.Join() else Comm.Leave() end
end

ns.Listen("LOGIN", function()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        pcall(C_ChatInfo.RegisterAddonMessagePrefix, ns.PREFIX)
    end
    addFilter("CHAT_MSG_CHANNEL_NOTICE", noticeFilter)
    addFilter("CHAT_MSG_CHANNEL_NOTICE_USER", noticeFilter)
    -- Join after the world channels, so we never take General or Trade's channel number.
    ns.After(10, Comm.Join)
    if C_Timer and C_Timer.NewTicker then
        C_Timer.NewTicker(HEARTBEAT, function()
            local listed = ns.Call(C_LFGList and C_LFGList.HasActiveEntryInfo)
            local open = ns.UI and ns.UI.IsShown and ns.UI.IsShown()
            if listed or open then Comm.Broadcast() end
        end)
    end
end)

local announceSoon = ns.Debounce(5, function() Comm.Broadcast() end)
ns.Listen("QUESTS_CHANGED", function(changed) if changed then announceSoon() end end)
ns.Listen("MY_INFO_CHANGED", announceSoon)
ns.On("LFG_LIST_ACTIVE_ENTRY_UPDATE", function() announceSoon() end)
