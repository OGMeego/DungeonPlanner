-- PartyPage.lua
-- Party Quests: every dungeon quest anyone in your group has, who has it and who's missing it.
-- Click a quest you have to share it, or one you're missing to be guided to it.
local _, ns = ...
local L = ns.L
local J = ns.Journal
local P = ns.Private("Journal")

local function names(list, color)
    local out = {}
    for _, n in ipairs(list) do tinsert(out, color and color:WrapTextInColorCode(n) or n) end
    return table.concat(out, ", ")
end

local function partyRows()
    local PQ = ns.PartyQuests
    local rows = {}
    if not (IsInGroup and IsInGroup()) then
        tinsert(rows, { kind = "text", h = 50, text = L.PQ_NOT_GROUPED })
        return rows
    end
    local board, members = PQ.Board()
    -- Only mention members we know nothing about: no Dungeon Planner message from them and
    -- no quests the game can see. Give them a few seconds to answer first.
    local unknown = 0
    if PQ.askedAt and GetTime() - PQ.askedAt > 6 then
        local heard = ns.Comm and ns.Comm.groupUsers or {}
        for _, g in ipairs(PQ.GroupUnits()) do
            local known = heard[strlower(g.name)]
            for _, n in ipairs(members or {}) do if ns.SameName(n, g.name) then known = true end end
            if not known then unknown = unknown + 1 end
        end
    end
    if unknown > 0 then
        tinsert(rows, { kind = "text", h = 34, text = GRAY_FONT_COLOR:WrapTextInColorCode(L.PQ_NO_ADDON:format(unknown)) })
    end
    if #board == 0 then
        tinsert(rows, { kind = "text", h = 40, text = L.PQ_EMPTY })
        return rows
    end
    for _, g in ipairs(board) do
        tinsert(rows, { kind = "header", text = g.dungeon, h = 26 })
        for _, e in ipairs(g.quests) do
            local info = ns.Quests.Info(e.id)
            local color = info and P.questColor(info[2]) or NORMAL_FONT_COLOR
            local sub = L.PQ_HAVE:format(names(e.have, GREEN_FONT_COLOR))
            if #e.missing > 0 then sub = sub .. "   " .. L.PQ_MISSING:format(names(e.missing, ORANGE_FONT_COLOR)) end
            local action = e.mine and (#e.missing > 0 and L.PQ_SHARE or "") or L.J_GUIDE_ME
            tinsert(rows, { kind = "line", h = 42, atlas = e.mine and "QuestTurnin" or "QuestNormal", iconSize = 18,
                text = color:WrapTextInColorCode((info and ("[" .. info[2] .. "] ") or "") .. e.title), sub = sub,
                right = GRAY_FONT_COLOR:WrapTextInColorCode(action),
                onClick = function()
                    if e.mine then
                        if #e.missing > 0 then PQ.Share(e.id) end
                    elseif ns.Quests.Info(e.id) then
                        ns.Quests.Guide(e.id)
                    end
                end,
                tooltip = function(tt)
                    tt:SetText(e.title, 1, 1, 1)
                    tt:AddLine(L.PQ_HAVE:format(names(e.have)), 0.4, 1, 0.4, true)
                    if #e.missing > 0 then tt:AddLine(L.PQ_MISSING:format(names(e.missing)), 1, 0.5, 0.25, true) end
                    if action ~= "" then tt:AddLine(L.PQ_CLICK:format(action), 0.6, 0.6, 0.6) end
                end })
        end
        tinsert(rows, { kind = "spacer", h = 8 })
    end
    return rows
end

J.RegisterPage("party", { nav = L.PQ_TITLE, iconTex = "Interface\\Icons\\INV_Misc_GroupNeedMore", order = 40,
    shown = function() return IsInGroup and IsInGroup() end,
    title = function() return L.PQ_TITLE end,
    sub = function() return L.PQ_SUB end,
    rows = function(cur) if not cur.asked then cur.asked = true; ns.PartyQuests.Ask() end return partyRows() end })

ns.Listen("PARTY_QUESTS_CHANGED", function() J.Refresh() end)
