-- Actions.lua
-- Whisper, invite and the right-click menu.
local _, ns = ...
local L = ns.L
local UI = ns.UI
local P = ns.Private("Finder.UI")

-- ---------------------------------------------------------------------------
-- Actions
-- ---------------------------------------------------------------------------

function P.selectedData()
    for _, d in ipairs(P.rowsData) do
        if d.key == P.selectedKey then return d end
    end
end

local function nameOf(d)
    if not d then return nil end
    return d.kind == "listing" and d.l.leader or d.a.name
end

-- The whisper we'd send for this row.
function P.messageFor(d)
    if not d then return "" end
    if d.kind == "listing" then
        local act = d.info.activity
        if d.l.solo then
            -- Recruiting a single player: {role} is the role we want from them.
            local want = d.info.fitRole
            if not want then
                local offers = (d.info.peer and d.info.peer.roles) or d.l.roles or {}
                for _, r in ipairs(P.ROLE_ORDER) do if offers[r] then want = r break end end
            end
            return ns.RenderTemplate(ns.opt.recruitTemplate or L.DEFAULT_RECRUIT, {
                dungeon = act and act.name, role = want or "dps", name = d.l.leader,
            })
        end
        return ns.RenderTemplate(ns.opt.joinTemplate or L.DEFAULT_JOIN, {
            dungeon = act and act.name, quests = d.info.myQuestsHere, role = d.info.fitRole, name = d.l.leader,
        })
    end
    return ""
end

function P.whisperSelected()
    local d = P.selectedData()
    local name = nameOf(d)
    if not name then return end
    local text = strtrim(P.panel.message:GetText() or "")
    if text == "" then
        if ChatFrameUtil and ChatFrameUtil.SendTell then ChatFrameUtil.SendTell(name) end
        return
    end
    if ns.SendWhisper(name, text) then
        ns.Print(L.WHISPER_SENT:format(ns.Display(name)))
        P.panel.message:ClearFocus()
    end
end

function P.inviteData(d)
    if not d then return end
    if d.kind == "applicant" then
        ns.Invite(d.a.name)
        d.a.unread = false
        ns.Inbox.CountUnread()
        UI.Refresh()
    elseif d.l.solo then
        ns.Invite(d.l.leader)
    else
        -- Never fall back to a whisper: only the Whisper button sends messages.
        if not ns.RequestInvite(d.l.leader) then ns.Print(L.REQUEST_UNAVAILABLE) end
    end
end

function P.contextMenu(row, d)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    local name = nameOf(d)
    local mem = ns.Data.Memory(d.key)
    MenuUtil.CreateContextMenu(row, function(_, root)
        root:CreateTitle(ns.Display(name))
        root:CreateButton(L.MENU_WHISPER, function()
            if ChatFrameUtil and ChatFrameUtil.SendTell then ChatFrameUtil.SendTell(name) end
        end)
        if d.kind == "applicant" or d.l.solo then
            root:CreateButton(L.MENU_INVITE, function() P.inviteData(d) end)
        else
            root:CreateButton(L.MENU_REQUEST, function() P.inviteData(d) end)
        end
        root:CreateDivider()
        if mem and mem.fav then
            root:CreateButton(L.MENU_UNFAVORITE, function() ns.Data.SetFavorite(name, false) end)
        else
            root:CreateButton(L.MENU_FAVORITE, function() ns.Data.SetFavorite(name, true) end)
        end
        if mem and mem.avoid then
            root:CreateButton(L.MENU_UNAVOID, function() ns.Data.SetAvoid(name, false) end)
        else
            root:CreateButton(L.MENU_AVOID, function() ns.Data.SetAvoid(name, true) end)
        end
        local act = d.kind == "listing" and d.info.activity
        if act and act.mapID and ns.DB and ns.DB.dungeons[act.mapID] then
            root:CreateButton(L.MENU_JOURNAL, function() ns.Journal.ShowDungeon(act.mapID, 2) end)
        elseif act then
            root:CreateButton(L.MENU_JOURNAL, function() ns.Journal.ShowActivity(act) end)
        end
        if C_FriendList and C_FriendList.AddFriend and not ns.Data.IsFriend(d.key) then
            root:CreateButton(L.MENU_ADD_FRIEND, function() pcall(C_FriendList.AddFriend, name) end)
        end
        if d.kind == "applicant" then
            root:CreateDivider()
            root:CreateButton(L.MENU_DISMISS, function() ns.Inbox.Remove(d.key) end)
        end
    end)
end
