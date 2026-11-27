-- NavRow.lua
-- Filling a row of the dungeon list on the left.
local _, ns = ...
local L = ns.L
local J = ns.Journal
local Q = ns.Quests
local P = ns.Private("Journal")

function P.initNavRow(row, data)
    if not row.built then P.buildRow(row) end
    P.resetRow(row)
    row.data = data
    local selected = (data.kind == "dungeon" and P.current.kind == "dungeon" and P.current.map == data.map)
        or (data.kind == "special" and P.current.kind == data.page)
        or (data.kind == "activity" and P.current.kind == "activity" and P.current.a.name == data.a.name)
    if selected then row.bg:SetColorTexture(1, 0.82, 0, 0.18) end
    if data.kind == "header" then
        row.text:SetFontObject("GameFontHighlightSmall")
        row.text:SetPoint("LEFT", 8, -4)
        row.text:SetText(data.text)
        row.text:SetTextColor(0.6, 0.6, 0.6)
        return
    end
    if data.kind == "special" then
        row.text:SetPoint("LEFT", 12, 0)
        local mark = data.iconTex and ("|T" .. data.iconTex .. ":16:16|t") or ns.AtlasMarkup(data.icon or "bags-greenarrow", 14)
        row.text:SetText(mark .. " " .. data.text)
        row.right:SetText(data.count and data.count > 0 and GRAY_FONT_COLOR:WrapTextInColorCode(data.count) or "")
        row:SetScript("OnClick", function()
            if data.action then data.action() else J.ShowPage(data.page) end
        end)
        return
    end
    -- A dungeon card: the journal's art, a dark fade for the text, name, levels, quests and tags.
    local name, names, tag, open
    local mine = UnitFactionGroup("player") == "Alliance" and "A" or "H"
    if data.kind == "dungeon" then
        name = data.d.name
        names = { name, (name:gsub("^The ", "")) }
        local _, counts = Q.ForDungeon(data.map)
        open = counts.ready + counts.log
        local cd = ns.Nav and ns.Nav.CITY_DUNGEONS and ns.Nav.CITY_DUNGEONS[data.map]
        tag = (cd and cd.side ~= mine)
            and L.J_ENEMY_TAG:format(cd.side == "A" and (FACTION_ALLIANCE or "Alliance") or (FACTION_HORDE or "Horde")) or ""
        row:SetScript("OnClick", function() J.ShowDungeon(data.map) end)
    else
        local f = data.a.forever
        name = f and f.name or data.a.name
        names = { name, data.a.name }
        for _, al in ipairs(f and f.aliases or {}) do tinsert(names, al) end
        open = f and J.ForeverOpenQuests(f) or 0
        tag = (f and f.side and f.side ~= mine)
            and L.J_ENEMY_TAG:format(f.side == "A" and (FACTION_ALLIANCE or "Alliance") or (FACTION_HORDE or "Horde"))
            or ("|cff40c040" .. L.J_NEW_TAG .. "|r")
        row:SetScript("OnClick", function() J.ShowActivity(data.a) end)
    end
    local art = P.dungeonArt(unpack(names))
    if art and art.button then
        row.art:SetTexture(art.button)
        row.art:SetTexCoord(0, 0.684, 0.20, 0.54)
        row.art:Show()
    end
    row.shade:SetColorTexture(1, 1, 1, 1)
    local dark = selected and 0.35 or 0.6
    if not pcall(row.shade.SetGradient, row.shade, "HORIZONTAL", CreateColor(0, 0, 0, dark + 0.3), CreateColor(0, 0, 0, dark - 0.25)) then
        row.shade:SetColorTexture(0, 0, 0, dark)
    end
    if not (art and art.button) then row.bg:SetColorTexture(0.18, 0.13, 0.08, 1) end
    row.shade:Show()
    if selected then P.setEdges(row, 1, 0.82, 0, 0.9, 2) else P.setEdges(row, 0.30, 0.24, 0.14, 0.9, 2) end
    row.art:ClearAllPoints(); row.art:SetPoint("TOPLEFT", 1, -3); row.art:SetPoint("BOTTOMRIGHT", -1, 3)
    row.text:SetFontObject(_G.GameFontNormalMed3 and "GameFontNormalMed3" or "GameFontNormal")
    row.text:SetPoint("TOPLEFT", 10, -9)
    row.text:SetPoint("RIGHT", -8, 0)
    row.text:SetText(name)
    row.sub:SetFontObject("GameFontHighlightSmall")
    row.sub:SetPoint("BOTTOMLEFT", 10, 9)
    row.sub:SetText(LEVEL_ABBR and (LEVEL_ABBR .. " " .. data.d.min .. "-" .. data.d.max) or (data.d.min .. "-" .. data.d.max))
    row.right:ClearAllPoints()
    row.right:SetPoint("BOTTOMRIGHT", -8, 9)
    row.right:SetText((open and open > 0 and (ns.AtlasMarkup("QuestNormal", 12) .. open .. "  ") or "") .. (tag or ""))
end
