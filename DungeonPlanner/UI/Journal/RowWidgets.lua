-- RowWidgets.lua
-- Item helpers and the recycled row button.
local _, ns = ...
local L = ns.L
local J = ns.Journal
local I_NAME, I_QUALITY, I_INV, I_REQ = 1, 2, 3, 4
local P = ns.Private("Journal")

-- ---------------------------------------------------------------------------
-- Rows (one recycled Button type for every kind of row)
-- ---------------------------------------------------------------------------

function P.itemColor(quality)
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality or 1]
    return c and c.color or HIGHLIGHT_FONT_COLOR
end

function P.itemName(itemID)
    local name = ns.Call(C_Item and C_Item.GetItemNameByID, itemID)
    if type(name) == "string" and name ~= "" then return name end
    local it = ns.Gear.Item(itemID)
    return it and it[I_NAME] or ("item:" .. itemID)
end

function P.showItemTooltip(owner, itemID)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(itemID)
    local up, r = ns.Gear.IsUpgrade(itemID)
    GameTooltip:AddLine((ns.Wishlist and ns.Wishlist.Has(itemID)) and L.WISH_REMOVE_HINT or L.WISH_ADD_HINT, 0.5, 0.5, 0.5)
    if up then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(ns.AtlasMarkup("bags-greenarrow", 14) .. " " .. L.J_UPGRADE_LINE:format(ns.Gear.GainText(r)),
            GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g, GREEN_FONT_COLOR.b)
    end
    GameTooltip:Show()
end

function P.linkItem(itemID)
    local _, link = ns.Call(C_Item and C_Item.GetItemInfo, itemID)
    if link and HandleModifiedItemClick then HandleModifiedItemClick(link) end
end

-- Left click links the item (shift-click into chat), right click adds or removes it from
-- your wishlist.
function P.itemClick(itemID, button, boss, dungeon)
    if button == "RightButton" and ns.Wishlist then
        ns.Wishlist.Toggle(itemID, boss, dungeon)
        J.Refresh()
        return
    end
    P.linkItem(itemID)
end

function P.colorizeGreen(text)
    if not text then return "" end
    return ns.AtlasMarkup("bags-greenarrow", 12) .. GREEN_FONT_COLOR:WrapTextInColorCode(text)
end

function P.buildRow(row)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.hl = row:CreateTexture(nil, "HIGHLIGHT")
    row.hl:SetAllPoints()
    if not ns.SetAtlas(row.hl, "groupfinder-highlightbar-blue") then row.hl:SetColorTexture(1, 1, 1, 0.06) end
    row.hl:SetBlendMode("ADD")
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(22, 22)
    row.icon:SetPoint("LEFT", 6, 0)
    row.text = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)
    row.sub = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    row.sub:SetJustifyH("LEFT")
    row.sub:SetWordWrap(false)
    row.desc = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.desc:SetJustifyH("LEFT")
    row.desc:SetJustifyV("TOP")
    row.desc:SetWordWrap(true)
    row.desc:SetTextColor(0.82, 0.78, 0.68)
    row.right = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.right:SetJustifyH("RIGHT")
    row.right:SetPoint("RIGHT", -8, 0)
    row.pin = CreateFrame("Button", nil, row)
    row.pin:SetSize(20, 20)
    row.pin.tex = row.pin:CreateTexture(nil, "ARTWORK")
    row.pin.tex:SetAllPoints()
    if not ns.SetAtlas(row.pin.tex, "Waypoint-MapPin-Untracked") then row.pin.tex:SetTexture("Interface\\Minimap\\Tracking\\None") end
    row.pin:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    row.guide = CreateFrame("Button", nil, row)
    row.guide:SetSize(20, 20)
    row.guide.tex = row.guide:CreateTexture(nil, "ARTWORK")
    row.guide.tex:SetAllPoints()
    if not ns.SetAtlas(row.guide.tex, "Navigation-Tracked-Arrow") then row.guide.tex:SetTexture("Interface\\Minimap\\MinimapArrow") end
    row.guide:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    row.rewards = {}
    for i = 1, 4 do
        local b = CreateFrame("Button", nil, row)
        b:SetSize(22, 22)
        b.tex = b:CreateTexture(nil, "ARTWORK")
        b.tex:SetAllPoints()
        b.up = b:CreateTexture(nil, "OVERLAY")
        b.up:SetSize(12, 12)
        b.up:SetPoint("TOPLEFT", -3, 3)
        ns.SetAtlas(b.up, "bags-greenarrow")
        b:SetScript("OnEnter", function(self) P.showItemTooltip(self, self.itemID) end)
        b:SetScript("OnLeave", GameTooltip_Hide)
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b:SetScript("OnClick", function(self, button) P.itemClick(self.itemID, button) end)
        row.rewards[i] = b
    end
    -- Cards and portraits
    row.art = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    row.art:SetPoint("TOPLEFT", 1, -1)
    row.art:SetPoint("BOTTOMRIGHT", -1, 1)
    row.shade = row:CreateTexture(nil, "BACKGROUND", nil, 2)
    row.shade:SetAllPoints(row.art)
    row.edges = {}
    for i = 1, 4 do row.edges[i] = row:CreateTexture(nil, "BORDER") end
    row.edges[1]:SetPoint("TOPLEFT"); row.edges[1]:SetPoint("TOPRIGHT"); row.edges[1]:SetHeight(1)
    row.edges[2]:SetPoint("BOTTOMLEFT"); row.edges[2]:SetPoint("BOTTOMRIGHT"); row.edges[2]:SetHeight(1)
    row.edges[3]:SetPoint("TOPLEFT"); row.edges[3]:SetPoint("BOTTOMLEFT"); row.edges[3]:SetWidth(1)
    row.edges[4]:SetPoint("TOPRIGHT"); row.edges[4]:SetPoint("BOTTOMRIGHT"); row.edges[4]:SetWidth(1)
    row.portrait = row:CreateTexture(nil, "ARTWORK", nil, 1)
    if row.CreateMaskTexture then
        row.mask = row:CreateMaskTexture()
        row.mask:SetAllPoints(row.portrait)
        row.mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        row.portrait:AddMaskTexture(row.mask)
    end
    row.ring = row:CreateTexture(nil, "OVERLAY", nil, 1)
    row.ring:SetTexture("Interface\\Common\\GoldRing")
    row.ring:SetPoint("TOPLEFT", row.portrait, "TOPLEFT", -4, 4)
    row.ring:SetPoint("BOTTOMRIGHT", row.portrait, "BOTTOMRIGHT", 4, -4)
    row.badge = CreateFrame("Frame", nil, row)
    row.badge:SetSize(19, 19)
    row.badge:SetPoint("CENTER", row.portrait, "BOTTOMLEFT", 5, 5)
    row.badge:SetFrameLevel(row:GetFrameLevel() + 3)
    row.badge.bg = row.badge:CreateTexture(nil, "ARTWORK")
    row.badge.bg:SetAllPoints()
    row.badge.bg:SetColorTexture(0.08, 0.06, 0.04, 1)
    if row.badge.CreateMaskTexture then
        local m = row.badge:CreateMaskTexture()
        m:SetAllPoints(row.badge.bg)
        m:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        row.badge.bg:AddMaskTexture(m)
    end
    row.badge.ring = row.badge:CreateTexture(nil, "OVERLAY")
    row.badge.ring:SetTexture("Interface\\Common\\GoldRing")
    row.badge.ring:SetPoint("TOPLEFT", -2, 2)
    row.badge.ring:SetPoint("BOTTOMRIGHT", 2, -2)
    row.badge.text = row.badge:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.badge.text:SetPoint("CENTER", 0, 0)
    -- Quests in your log: a green bar down the left edge and a tag after the title.
    row.accent = row:CreateTexture(nil, "ARTWORK", nil, 2)
    row.accent:SetPoint("TOPLEFT", 0, -2)
    row.accent:SetPoint("BOTTOMLEFT", 0, 2)
    row.accent:SetWidth(4)
    row.accent:Hide()
    row.tag = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    local font = row.tag:GetFont()
    if font then row.tag:SetFont(font, 9, "") end
    row.tag:Hide()
    row.tagBg = row:CreateTexture(nil, "ARTWORK", nil, 1)
    row.tagBg:SetPoint("TOPLEFT", row.tag, "TOPLEFT", -4, 2)
    row.tagBg:SetPoint("BOTTOMRIGHT", row.tag, "BOTTOMRIGHT", 4, -2)
    row.tagBg:Hide()
    row.star = row:CreateTexture(nil, "OVERLAY", nil, 3)
    row.star:SetSize(14, 14)
    row.star:SetPoint("TOPLEFT", row.icon, "TOPLEFT", -5, 5)
    if not ns.SetAtlas(row.star, "PetJournal-FavoritesIcon") then row.star:SetTexture("Interface\\Common\\ReputationStar") end
    row.star:Hide()
    row.check = row:CreateTexture(nil, "OVERLAY", nil, 2)
    row.check:SetSize(18, 18)
    row.check:SetPoint("TOPRIGHT", row.portrait, "TOPRIGHT", 4, 4)
    ns.SetAtlas(row.check, "common-icon-checkmark")
    row:SetScript("OnLeave", GameTooltip_Hide)
    row.built = true
end

-- A round boss portrait from its model (or a skull when there's none).
function P.setPortrait(row, display, size, desaturate, left, icon)
    row.portrait:ClearAllPoints()
    row.portrait:SetSize(size, size)
    row.portrait:SetPoint("LEFT", left or 16, 0)
    local ok = false
    if display and display > 0 and SetPortraitTextureFromCreatureDisplayID then
        ok = pcall(SetPortraitTextureFromCreatureDisplayID, row.portrait, display)
    end
    if not ok and icon then row.portrait:SetTexture(icon); ok = true end
    if not ok then row.portrait:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull") end
    row.portrait:SetDesaturated(desaturate and true or false)
    row.portrait:Show()
    row.ring:Show()
end

-- Make a quest you have picked up stand out: tinted row, green edge bar and a tag
-- ("In your log", or "Ready to turn in" once the objectives are done).
function P.markInLog(row, complete)
    local r, g, b = 0.25, 0.85, 0.3
    if complete then r, g, b = 1, 0.82, 0 end
    row.bg:SetColorTexture(r, g, b, 0.10)
    row.accent:SetColorTexture(r, g, b, 0.95)
    row.accent:Show()
    row.tag:ClearAllPoints()
    row.tag:SetPoint("LEFT", row.text, "LEFT", math.min(row.text:GetStringWidth() or 0, (row.text:GetWidth() or 300) - 10) + 10, 0)
    row.tag:SetText(complete and L.J_TAG_TURN_IN or L.J_TAG_IN_LOG)
    -- A quiet pill: tinted text on a faint background of the same colour.
    row.tag:SetTextColor(math.min(1, r + 0.15), math.min(1, g + 0.1), math.min(1, b + 0.15))
    row.tagBg:SetColorTexture(r, g, b, 0.18)
    row.tag:Show(); row.tagBg:Show()
end

function P.setEdges(row, r, g, b, a, gap)
    gap = gap or 0
    local e = row.edges
    e[1]:ClearAllPoints(); e[1]:SetPoint("TOPLEFT", 0, -gap); e[1]:SetPoint("TOPRIGHT", 0, -gap)
    e[2]:ClearAllPoints(); e[2]:SetPoint("BOTTOMLEFT", 0, gap); e[2]:SetPoint("BOTTOMRIGHT", 0, gap)
    e[3]:ClearAllPoints(); e[3]:SetPoint("TOPLEFT", 0, -gap); e[3]:SetPoint("BOTTOMLEFT", 0, gap)
    e[4]:ClearAllPoints(); e[4]:SetPoint("TOPRIGHT", 0, -gap); e[4]:SetPoint("BOTTOMRIGHT", 0, gap)
    for _, t in ipairs(e) do t:SetColorTexture(r, g, b, a); t:Show() end
    row.bg:ClearAllPoints()
    row.bg:SetPoint("TOPLEFT", 0, -gap)
    row.bg:SetPoint("BOTTOMRIGHT", 0, gap)
end

-- Journal art for a dungeon (cards and backdrops), by any of its names.
function P.dungeonArt(...)
    return ns.EJ and ns.EJ.Art(...) or nil
end
J.DungeonArt = P.dungeonArt

function P.resetRow(row)
    row.accent:Hide(); row.tag:Hide(); row.tagBg:Hide()
    row.art:Hide(); row.art:SetDesaturated(false); row.shade:Hide(); row.star:Hide(); row.icon:SetSize(22, 22); row.portrait:Hide(); row.ring:Hide(); row.badge:Hide(); row.check:Hide()
    for _, e in ipairs(row.edges) do e:Hide() end
    row.icon:Hide(); row.icon:SetDesaturated(false); row.icon:SetTexCoord(0, 1, 0, 1)
    row.text:ClearAllPoints(); row.sub:ClearAllPoints()
    row.text:SetText(""); row.sub:SetText(""); row.right:SetText(""); row.desc:SetText(""); row.desc:ClearAllPoints(); row.desc:Hide()
    row.icon:ClearAllPoints(); row.icon:SetPoint("LEFT", 6, 0)
    row.text:SetFontObject("GameFontNormal")
    row.sub:SetFontObject("GameFontDisableSmall")
    row.right:ClearAllPoints()
    row.right:SetPoint("RIGHT", -8, 0)
    row.text:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
    row.text:SetWordWrap(false)
    row.bg:SetColorTexture(0, 0, 0, 0)
    row.bg:ClearAllPoints(); row.bg:SetAllPoints()
    row.pin:Hide()
    row.guide:Hide()
    local action, tabs = rawget(row, "actionBtn"), rawget(row, "tabBtns")
    if action then action:Hide() end
    if tabs then for _, t in ipairs(tabs) do t:Hide() end end
    for _, b in ipairs(row.rewards) do b:Hide() end
    row:SetScript("OnClick", nil)
    row:SetScript("OnEnter", nil)
end
