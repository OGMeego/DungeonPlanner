-- LineRow.lua
-- One general-purpose row for the journal's own pages (Character Logs, Wishlist, Party Quests):
-- an optional portrait, icon or dungeon card, a title, a sub line, a right-hand text, a
-- tooltip and left/right click actions. Everything is optional.
local _, ns = ...
local P = ns.Private("Journal")

-- data = { kind = "line", h, text, sub, right, color = { r, g, b }, display = creature display ID,
--   portraitIcon = texture, icon = texture, atlas = atlas, card = { names... } (dungeon art),
--   star = bool, dim = bool, onClick = fn(button), tooltip = fn(GameTooltip) }
function P.initLineRow(row, data)
    local left = 10
    if data.display or data.portraitIcon then
        local size = math.min(42, (data.h or 40) - 12)
        P.setPortrait(row, data.display, size, data.dim, 16, data.portraitIcon)
        left = 16 + size + 14
    elseif data.icon or data.atlas then
        row.icon:ClearAllPoints()
        row.icon:SetPoint("LEFT", 10, 0)
        row.icon:SetSize(data.iconSize or 24, data.iconSize or 24)
        if data.atlas then ns.SetAtlas(row.icon, data.atlas) else row.icon:SetTexture(data.icon) end
        row.icon:SetDesaturated(data.dim and true or false)
        row.icon:Show()
        left = 10 + (data.iconSize or 24) + 10
    end
    if data.card then
        local art = P.dungeonArt(unpack(data.card))
        if art and art.button then
            row.art:SetTexture(art.button)
            row.art:SetTexCoord(0, 0.684, 0.20, 0.54)
            row.art:ClearAllPoints(); row.art:SetPoint("TOPLEFT", 1, -3); row.art:SetPoint("BOTTOMRIGHT", -1, 3)
            row.art:SetDesaturated(data.dim and true or false)
            row.art:Show()
            row.shade:SetColorTexture(0, 0, 0, 1)
            if not pcall(row.shade.SetGradient, row.shade, "HORIZONTAL", CreateColor(0, 0, 0, 0.85), CreateColor(0, 0, 0, 0.35)) then
                row.shade:SetColorTexture(0, 0, 0, 0.6)
            end
            row.shade:Show()
        end
        P.setEdges(row, 0.30, 0.24, 0.14, 0.9, 3)
    elseif data.boxed ~= false then
        row.bg:SetColorTexture(1, 1, 1, 0.035)
        P.setEdges(row, 0.35, 0.28, 0.16, 0.5, 2)
    end
    local hasSub = data.sub and data.sub ~= ""
    row.text:SetFontObject(data.font or "GameFontNormal")
    if hasSub then
        row.text:SetPoint("BOTTOMLEFT", row, "LEFT", left, 1)
        row.sub:SetPoint("TOPLEFT", row, "LEFT", left, -3)
        row.sub:SetPoint("RIGHT", -150, 0)
        row.sub:SetFontObject("GameFontHighlightSmall")
        row.sub:SetText(data.sub)
        row.sub:SetTextColor(0.75, 0.75, 0.75)
    else
        row.text:SetPoint("LEFT", left, 0)
    end
    row.text:SetPoint("RIGHT", -150, 0)
    row.text:SetText(data.text or "")
    local c = data.color
    if c then row.text:SetTextColor(c.r or c[1], c.g or c[2], c.b or c[3])
    elseif data.dim then row.text:SetTextColor(0.6, 0.6, 0.6) end
    row.right:ClearAllPoints()
    row.right:SetPoint("RIGHT", -14, 0)
    row.right:SetText(data.right or "")
    -- A real button on the right (e.g. "Guide me there"), so it looks clickable.
    if data.action then
        if not rawget(row, "actionBtn") then
            row.actionBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            row.actionBtn:SetHeight(22)
        end
        local b = row.actionBtn
        b:SetText(data.action.text)
        b:SetWidth(math.max(90, (b:GetFontString() and b:GetFontString():GetStringWidth() or 80) + 26))
        b:ClearAllPoints()
        b:SetPoint("RIGHT", -10, 0)
        b:SetScript("OnClick", function() data.action.onClick() end)
        b:Show()
    end
    if data.star then row.star:Show() end
    if data.tooltip then
        row:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            data.tooltip(GameTooltip)
            GameTooltip:Show()
        end)
    end
    if data.onClick then
        row:SetScript("OnClick", function(_, button) data.onClick(button) end)
    end
end
