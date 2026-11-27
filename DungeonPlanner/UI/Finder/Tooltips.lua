-- Tooltips.lua
-- Row badges and tooltips.
local _, ns = ...
local L = ns.L
local P = ns.Private("Finder.UI")

-- ---------------------------------------------------------------------------
-- Row badges and tooltips
-- ---------------------------------------------------------------------------

function P.badgesFor(data)
    local info = data.info
    local parts = {}
    if info.fav then tinsert(parts, P.colorize(L.FAVORITE, GREEN_FONT_COLOR)) end
    if info.avoid then tinsert(parts, P.colorize(L.AVOIDED, RED_FONT_COLOR)) end
    if info.friend then tinsert(parts, P.colorize(L.FRIEND, FRIENDS_WOW_NAME_COLOR or GREEN_FONT_COLOR)) end
    if info.guild then tinsert(parts, P.colorize(L.GUILD, GREEN_FONT_COLOR)) end
    if (info.shared or 0) > 0 then
        tinsert(parts, ns.AtlasMarkup("QuestNormal", 12) .. P.colorize(L.SHARED_QUESTS:format(info.shared), YELLOW_FONT_COLOR))
    elseif (info.myQuestsHere or 0) > 0 then
        tinsert(parts, ns.AtlasMarkup("QuestNormal", 12) .. P.colorize(L.QUESTS_HERE:format(info.myQuestsHere), YELLOW_FONT_COLOR))
    end
    if (info.upgrades or 0) > 0 then
        tinsert(parts, ns.AtlasMarkup("bags-greenarrow", 12) .. P.colorize(L.UPGRADES_BADGE:format(info.upgrades), GREEN_FONT_COLOR))
    end
    if (info.wished or 0) > 0 then
        tinsert(parts, ns.AtlasMarkup("PetJournal-FavoritesIcon", 12) .. P.colorize(L.WISH_BADGE:format(info.wished), YELLOW_FONT_COLOR))
    end
    if info.before and not info.fav then tinsert(parts, P.colorize(L.GROUPED_BEFORE, LIGHTBLUE_FONT_COLOR or HIGHLIGHT_FONT_COLOR)) end
    if info.near then tinsert(parts, P.colorize(L.SAME_ZONE, HIGHLIGHT_FONT_COLOR)) end
    return table.concat(parts, P.colorize(" · ", GRAY_FONT_COLOR))
end

local function addPeopleLines(info)
    if (info.sharedList and #info.sharedList > 0) then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L.TT_SHARED_QUESTS, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
        for _, title in ipairs(info.sharedList) do GameTooltip:AddLine("  " .. title, 1, 1, 1) end
    end
    if info.before then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L.TT_HISTORY, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
        GameTooltip:AddLine("  " .. info.before.dungeon .. " - " .. ns.Ago(ns.Now() - (info.before.at or 0)), 1, 1, 1)
    end
    if info.peer then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(ns.AtlasMarkup("common-icon-checkmark", 12) .. " " .. L.USES_ADDON, GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g, GREEN_FONT_COLOR.b)
    end
end

function P.listingTooltip(row, data)
    local l, info = data.l, data.info
    local color = ns.ClassColor(l.class)
    GameTooltip:SetOwner(row, "ANCHOR_NONE")
    GameTooltip:SetPoint("TOPLEFT", row, "TOPRIGHT", 8, 20)
    GameTooltip:SetText(ns.Display(l.leader), color.r, color.g, color.b)
    if l.level and l.class then
        GameTooltip:AddLine(L.TT_LEVEL_CLASS:format(l.level, ns.ClassName(l.class)), 1, 1, 1)
    end
    local acts = {}
    for _, a in ipairs(l.activities) do tinsert(acts, a.name) end
    if #acts > 0 then GameTooltip:AddLine(table.concat(acts, ", "), NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, true) end
    if l.comment and l.comment ~= "" then
        GameTooltip:AddLine(l.comment, LIGHTGRAY_FONT_COLOR and LIGHTGRAY_FONT_COLOR.r or 0.8, 0.8, 0.8, true)
    end
    if l.area then GameTooltip:AddLine(L.TT_LOCATION:format(l.area), 0.8, 0.8, 0.8) end
    if not l.solo then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L.TT_MEMBERS, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
        for _, m in ipairs(l.members) do
            local c = ns.ClassColor(m.class)
            local role = m.assigned and ns.AtlasMarkup(P.ROLE_MICRO[m.assigned], 12) .. " " or ""
            GameTooltip:AddDoubleLine(role .. ns.Display(m.name), m.level and (LEVEL .. " " .. m.level) or "",
                c.r, c.g, c.b, 0.8, 0.8, 0.8)
        end
    end
    if info.confirmed then
        GameTooltip:AddLine(ns.AtlasMarkup("common-icon-checkmark", 12) .. " " .. L.TT_ROLE_CONFIRMED, GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g, GREEN_FONT_COLOR.b)
    end
    addPeopleLines(info)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L.TT_RIGHT_CLICK, 0.5, 0.5, 0.5)
    GameTooltip:Show()
end

function P.applicantTooltip(row, data)
    local a, info = data.a, data.info
    local color = ns.ClassColor(a.class)
    GameTooltip:SetOwner(row, "ANCHOR_NONE")
    GameTooltip:SetPoint("TOPLEFT", row, "TOPRIGHT", 8, 20)
    GameTooltip:SetText(ns.Display(a.name), color.r, color.g, color.b)
    if a.class then
        local lvl = a.level and (LEVEL .. " " .. a.level .. " ") or ""
        GameTooltip:AddLine(lvl .. ns.ClassName(a.class), 1, 1, 1)
    end
    if a.role then
        local how = a.confirmed and L.TT_ROLE_CONFIRMED or L.TT_ROLE_FROM_TEXT
        GameTooltip:AddLine(ns.AtlasMarkup(P.ROLE_MICRO[a.role], 12) .. " " .. ns.Data.RoleName(a.role) .. "  (" .. how .. ")",
            0.8, 0.8, 0.8, true)
    end
    GameTooltip:AddLine(" ")
    for i = math.max(1, #a.messages - 4), #a.messages do
        GameTooltip:AddLine("\"" .. a.messages[i] .. "\"", 1, 1, 1, true)
    end
    addPeopleLines(info)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L.TT_RIGHT_CLICK, 0.5, 0.5, 0.5)
    GameTooltip:Show()
end
