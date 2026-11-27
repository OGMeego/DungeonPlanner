-- Inbox: whispers about your group become applicant rows with class, level and role,
-- instead of chat lines that scroll away.
local _, ns = ...
local L = ns.L

local Inbox = {}
ns.Inbox = Inbox

Inbox.list = {}     -- array of applicants, newest first
Inbox.unread = 0

local EXPIRE = 30 * 60
local MAX = 40

-- Words that mark a whisper as being about a group. Role words also give us the role.
local ROLE_WORDS = {
    tank = { "tank", "tanking", "prot", "bear", "feral tank" },
    healer = { "heal", "healer", "healz", "heals", "resto", "holy", "disc" },
    dps = { "dps", "damage", " dd", "dd ", "deeps" },
}
local INTENT_WORDS = { "inv", "invite", "group", "grp", "join", "spot", "room", "lfg", "lfm", "need", "space", "slot", "run" }

local function hasWord(text, word)
    return (" " .. text .. " "):find(word, 1, true) ~= nil
end

-- The role a message asks for, checked against what the class can play.
function Inbox.ParseRole(text, classFile)
    text = strlower(text or "")
    local found
    for _, role in ipairs({ "tank", "healer", "dps" }) do
        for _, w in ipairs(ROLE_WORDS[role]) do
            if hasWord(text, w) and ns.Data.CanClassDo(classFile, role) then
                found = role
                break
            end
        end
        if found then break end
    end
    if not found and classFile and not ns.Data.CanClassDo(classFile, "tank") and not ns.Data.CanClassDo(classFile, "healer") then
        found = "dps" -- mages, rogues, hunters and warlocks can only be damage
    end
    return found
end

local function looksLikeGroupRequest(text)
    text = strlower(text or "")
    for _, w in ipairs(INTENT_WORDS) do if hasWord(text, w) then return true end end
    for _, words in pairs(ROLE_WORDS) do
        for _, w in ipairs(words) do if hasWord(text, w) then return true end end
    end
    for _, a in ipairs(ns.Data.dungeonList) do
        if hasWord(text, strlower(a.name)) then return true end
    end
    return false
end

-- Am I collecting applicants right now?
local function collecting()
    if not (ns.opt and ns.opt.inbox) then return false end
    if ns.Call(C_LFGList and C_LFGList.HasActiveEntryInfo) then return true, true end
    -- Also while forming a group yourself (leader of a party with room).
    if IsInGroup() and not IsInRaid() and UnitIsGroupLeader("player") and GetNumGroupMembers() < 5 then
        return true, false
    end
    return false
end

local function isInMyGroup(key)
    if not IsInGroup() then return false end
    for i = 1, 4 do
        local unit = "party" .. i
        local name, realm = ns.Call(UnitName, unit)
        name = ns.Safe(name)
        if name then
            realm = ns.Safe(realm)
            if realm and realm ~= "" then name = name .. "-" .. realm end
            if ns.Key(name) == key then return true end
        end
    end
    return false
end

-- Fill in class/level/role from everything we know.
local function enrich(a)
    local peer = ns.Comm.Peer(a.key)
    if peer then
        a.class = a.class or peer.class
        a.level = peer.level or a.level
        if peer.roles and (peer.roles.tank or peer.roles.healer or peer.roles.dps) then
            -- Keep the role they asked for if they really play it; else their first role.
            local said = Inbox.ParseRole(a.lastText, a.class)
            if said and peer.roles[said] then
                a.role = said
            else
                for _, r in ipairs({ "tank", "healer", "dps" }) do
                    if peer.roles[r] then a.role = r break end
                end
            end
            a.roleGuessed = false
            a.confirmed = true
        end
    end
    local member, listing = ns.Finder.FindPlayer(a.key)
    if member then
        a.class = a.class or member.class
        a.level = a.level or member.level
        a.area = a.area or member.area
        if not a.role and member.roles then
            for _, r in ipairs({ "tank", "healer", "dps" }) do
                if member.roles[r] then a.role = r; a.roleGuessed = true break end
            end
        end
    end
    local m = ns.Data.Memory(a.key)
    if m then
        a.class = a.class or m.class
        a.level = a.level or m.level
    end
    if not a.role then
        a.role = Inbox.ParseRole(a.lastText, a.class)
        a.roleGuessed = a.role ~= nil
    end
end

function Inbox.Find(key)
    for i, a in ipairs(Inbox.list) do
        if a.key == key then return a, i end
    end
end

local function add(sender, text, guid)
    local key = ns.Key(sender)
    if not key then return end
    local a = Inbox.Find(key)
    local isNew = not a
    if not a then
        a = { key = key, name = sender, messages = {} }
        tinsert(Inbox.list, 1, a)
        while #Inbox.list > MAX do tremove(Inbox.list) end
    end
    a.lastText = text
    a.at = ns.Now()
    a.unread = true
    tinsert(a.messages, text)
    if guid and not a.class and GetPlayerInfoByGUID then
        local _, classFile = ns.Call(GetPlayerInfoByGUID, guid)
        a.class = ns.Safe(classFile)
    end
    if not a.confirmed then a.role = nil end -- re-read the role from the newest message
    enrich(a)
    Inbox.CountUnread()
    ns.Fire("INBOX_CHANGED", a, isNew)
    if isNew and ns.opt.inboxSound and SOUNDKIT and SOUNDKIT.TELL_MESSAGE then
        PlaySound(SOUNDKIT.TELL_MESSAGE)
    end
end

function Inbox.CountUnread()
    local n = 0
    for _, a in ipairs(Inbox.list) do if a.unread then n = n + 1 end end
    Inbox.unread = n
    return n
end

function Inbox.MarkAllRead()
    for _, a in ipairs(Inbox.list) do a.unread = false end
    Inbox.unread = 0
    ns.Fire("INBOX_CHANGED")
end

function Inbox.Remove(key)
    local _, i = Inbox.Find(key)
    if i then tremove(Inbox.list, i) end
    Inbox.CountUnread()
    ns.Fire("INBOX_CHANGED")
end

function Inbox.Clear()
    wipe(Inbox.list)
    Inbox.unread = 0
    ns.Fire("INBOX_CHANGED")
end

function Inbox.Decline(a)
    if ns.opt.declineReply and a and a.name then
        ns.SendWhisper(a.name, ns.opt.declineText or L.OPT_DECLINE_TEXT)
    end
    Inbox.Remove(a.key)
end

-- Remove applicants who joined the group, and old ones.
local function tidy()
    local now = ns.Now()
    for i = #Inbox.list, 1, -1 do
        local a = Inbox.list[i]
        if now - (a.at or 0) > EXPIRE or isInMyGroup(a.key) then tremove(Inbox.list, i) end
    end
    Inbox.CountUnread()
    ns.Fire("INBOX_CHANGED")
end

ns.On("CHAT_MSG_WHISPER", function(text, sender, _, _, _, _, _, _, _, _, _, guid)
    text, sender, guid = ns.Safe(text), ns.Safe(sender), ns.Safe(guid)
    if not (text and sender) then return end
    local on, listed = collecting()
    if not on then return end
    local key = ns.Key(sender)
    if isInMyGroup(key) then return end
    -- With a listing up, every whisper counts; otherwise only ones that sound like requests.
    if listed or Inbox.Find(key) or looksLikeGroupRequest(text) then
        add(sender, text, guid)
    end
end)

-- A Dungeon Planner user told us about themselves: upgrade their row.
ns.Listen("PEERS_CHANGED", function(key)
    local a = Inbox.Find(key)
    if a then
        enrich(a)
        ns.Fire("INBOX_CHANGED")
    end
end)

ns.On("GROUP_ROSTER_UPDATE", tidy)
ns.Listen("LOGIN", function()
    if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(60, tidy) end
end)

-- ---------------------------------------------------------------------------
-- Whispers and invites (shared with the browse list)
-- ---------------------------------------------------------------------------

local function sendChat(text, chatType, target)
    if C_ChatInfo and C_ChatInfo.SendChatMessage then
        return pcall(C_ChatInfo.SendChatMessage, text, chatType, nil, target)
    elseif SendChatMessage then
        return pcall(SendChatMessage, text, chatType, nil, target)
    end
    return false
end

function ns.SendWhisper(name, text)
    if not (name and text and text ~= "") then return false end
    local ok = sendChat(text:sub(1, 255), "WHISPER", name)
    if ok then ns.Comm.Tell(name) end
    return ok
end

function ns.Invite(name)
    if not name then return end
    if C_PartyInfo and C_PartyInfo.InviteUnit then
        pcall(C_PartyInfo.InviteUnit, name)
    elseif InviteUnit then
        pcall(InviteUnit, name)
    end
    ns.Comm.Tell(name)
    ns.Print(L.INVITED:format(ns.Display(name)))
end

function ns.RequestInvite(name)
    if not name then return end
    if C_PartyInfo and C_PartyInfo.RequestInviteFromUnit then
        pcall(C_PartyInfo.RequestInviteFromUnit, name)
        ns.Comm.Tell(name)
        ns.Print(L.REQUESTED:format(ns.Display(name)))
        return true
    end
    return false
end

-- Fill a whisper template.
function ns.RenderTemplate(template, ctx)
    ctx = ctx or {}
    local D = ns.Data
    local role = ctx.role or D.MyMainRole()
    local questsPhrase = ""
    if (ctx.quests or 0) > 0 then
        questsPhrase = L.QUESTS_PHRASE:gsub("{n}", tostring(ctx.quests))
        -- Resolve the |4singular:plural; grammar escape ourselves (chat does not).
        questsPhrase = questsPhrase:gsub("|4([^:]*):([^;]*);", function(one, many)
            return ctx.quests == 1 and one or many
        end)
    end
    local values = {
        level = tostring(D.MyLevel()),
        class = ns.ClassName(D.MyClass()),
        role = role == "dps" and L.ROLE_DAMAGER_CHAT or D.RoleName(role),
        dungeon = ctx.dungeon or L.UNKNOWN_DUNGEON,
        quests = questsPhrase,
        name = ctx.name and (strsplit(" -", ctx.name)) or "",
    }
    local text = template:gsub("{(%a+)}", function(token) return values[strlower(token)] end)
    text = text:gsub("  +", " "):gsub(" ([,.!?])", "%1")
    return strtrim(text)
end
