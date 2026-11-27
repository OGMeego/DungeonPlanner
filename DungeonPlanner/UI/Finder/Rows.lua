-- Rows.lua
-- One row of the Group Finder list.
local _, ns = ...
local L = ns.L
local UI = ns.UI
local P = ns.Private("Finder.UI")

-- ---------------------------------------------------------------------------
-- Rows
-- ---------------------------------------------------------------------------

local function buildRow(row)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetPoint("TOPLEFT", 3, -2)
    row.bg:SetPoint("BOTTOMRIGHT", -3, 0)
    if not ns.SetAtlas(row.bg, "groupfinder-highlightbar") then row.bg:SetColorTexture(1, 1, 1, 0.04) end

    row.selected = row:CreateTexture(nil, "OVERLAY")
    row.selected:SetPoint("TOPLEFT", 3, -3)
    row.selected:SetPoint("BOTTOMRIGHT", -3, -1)
    row.selected:SetBlendMode("ADD")
    if not ns.SetAtlas(row.selected, "groupfinder-highlightbar-yellow") then row.selected:SetColorTexture(1, 0.82, 0, 0.15) end
    row.selected:Hide()

    row.hl = row:CreateTexture(nil, "HIGHLIGHT")
    row.hl:SetPoint("TOPLEFT", 3, -3)
    row.hl:SetPoint("BOTTOMRIGHT", -3, -1)
    row.hl:SetBlendMode("ADD")
    if not ns.SetAtlas(row.hl, "groupfinder-highlightbar-blue") then row.hl:SetColorTexture(0.3, 0.6, 1, 0.12) end

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(24, 24)
    row.icon:SetPoint("TOPLEFT", 10, -9)

    row.name = P.Text(row, "GameFontNormalLarge")
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 6, -1)

    row.level = P.Text(row, "GameFontDisableLeft")
    row.level:SetPoint("BOTTOMLEFT", row.name, "BOTTOMRIGHT", 4, 0)

    row.activity = P.Text(row, "GameFontDisableLeft")
    row.activity:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -3)

    row.badges = P.Text(row, "GameFontNormalSmall")
    row.badges:SetPoint("TOPLEFT", row.activity, "BOTTOMLEFT", 0, -3)

    row.match = P.Text(row, "GameFontNormalSmall")
    row.match:SetJustifyH("RIGHT")
    row.match:SetPoint("TOPRIGHT", -12, -8)

    -- Role icons, right to left (5 group slots, or a solo player's roles).
    row.roles = {}
    for i = 1, 5 do
        local t = row:CreateTexture(nil, "ARTWORK")
        t:SetSize(18, 18)
        if i == 1 then
            t:SetPoint("BOTTOMRIGHT", -12, 9)
        else
            t:SetPoint("RIGHT", row.roles[i - 1], "LEFT", -1, 0)
        end
        row.roles[i] = t
    end
    row.check = row:CreateTexture(nil, "OVERLAY")
    row.check:SetSize(12, 12)
    row.check:SetPoint("BOTTOMRIGHT", row.roles[1], "BOTTOMRIGHT", 4, -3)
    ns.SetAtlas(row.check, "common-icon-checkmark")
    row.check:Hide()

    -- Applicant buttons
    row.invite = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.invite:SetSize(64, 20)
    row.invite:SetText(L.INVITE)
    row.invite:SetPoint("BOTTOMRIGHT", -36, 8)
    row.invite:SetScript("OnClick", function() P.inviteData(row.data) end)

    row.decline = CreateFrame("Button", nil, row, "UIMenuButtonStretchTemplate")
    row.decline:SetSize(22, 20)
    row.decline:SetPoint("LEFT", row.invite, "RIGHT", 2, 0)
    row.decline.icon = row.decline:CreateTexture(nil, "ARTWORK")
    row.decline.icon:SetPoint("CENTER")
    if not ns.SetAtlas(row.decline.icon, "groupfinder-icon-redx", true) then
        row.decline.icon:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
        row.decline.icon:SetSize(16, 16)
    end
    row.decline:SetScript("OnClick", function() ns.Inbox.Decline(row.data.a) end)
    row.decline:SetScript("OnEnter", function(self) P.Tooltip(self, L.DECLINE) end)
    row.decline:SetScript("OnLeave", GameTooltip_Hide)

    row.unread = row:CreateTexture(nil, "OVERLAY")
    row.unread:SetSize(10, 10)
    row.unread:SetPoint("TOPLEFT", 4, -5)
    if not ns.SetAtlas(row.unread, "groupfinder-waitdot") then row.unread:SetColorTexture(1, 0.82, 0, 1) end

    row:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            P.contextMenu(self, self.data)
            return
        end
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        UI.Select(self.data.key)
    end)
    row:SetScript("OnDoubleClick", function(self)
        UI.Select(self.data.key) -- selecting only; whispers are sent with the Whisper button
    end)
    row:SetScript("OnEnter", function(self)
        if self.data.kind == "listing" then P.listingTooltip(self, self.data) else P.applicantTooltip(self, self.data) end
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)
    row.built = true
end

local function setRoleIcons(row, roles, useMicro, max)
    local i = 1
    for _, r in ipairs(P.ROLE_ORDER) do
        if roles[r] and i <= (max or 3) then
            ns.SetAtlas(row.roles[i], (useMicro and P.ROLE_MICRO or P.ROLE_ATLAS)[r])
            row.roles[i]:SetDesaturated(false)
            row.roles[i]:SetAlpha(1)
            row.roles[i]:Show()
            i = i + 1
        end
    end
    for j = i, 5 do row.roles[j]:Hide() end
end

-- Group slots: filled roles, then empty slots (like Blizzard's enumerate display).
local function setGroupSlots(row, l, info)
    local c = l.counts or { tank = 0, healer = 0, dps = 0 }
    local filled = {}
    for _ = 1, c.dps or 0 do tinsert(filled, "dps") end
    for _ = 1, c.healer or 0 do tinsert(filled, "healer") end
    for _ = 1, c.tank or 0 do tinsert(filled, "tank") end
    for i = 1, 5 do
        local t = row.roles[i]
        local role = filled[i]
        if role then
            ns.SetAtlas(t, P.ROLE_ATLAS[role])
            t:SetAlpha(0.7)
        elseif not ns.SetAtlas(t, "groupfinder-icon-emptyslot") then
            t:SetColorTexture(0, 0, 0, 0.3)
        end
        t:SetDesaturated(false)
        t:Show()
    end
end

function P.initRow(row, data)
    if not row.built then buildRow(row) end
    row.data = data
    local info = data.info
    row.selected:SetShown(data.key == P.selectedKey)

    if data.kind == "listing" then
        local l = data.l
        local color = ns.ClassColor(l.class)
        if l.solo then
            if not (l.class and ns.SetAtlas(row.icon, "groupfinder-icon-class-" .. strlower(l.class))) then
                ns.SetAtlas(row.icon, "groupfinder-icon-leader", true)
            end
        else
            ns.SetAtlas(row.icon, "groupfinder-icon-leader")
        end
        row.name:SetText(ns.Display(l.leader))
        row.name:SetTextColor(color.r, color.g, color.b)
        row.level:SetText(l.level and (LEVEL_ABBR .. " " .. l.level) or "")
        local actText = info.activity and info.activity.name or ""
        if #l.activities > 1 then actText = actText .. " +" .. (#l.activities - 1) end
        if l.playstyle and GetGeneralPlaystyleString then
            local ok, ps = pcall(GetGeneralPlaystyleString, l.playstyle)
            if ok and ps and ps ~= "" then actText = actText .. P.colorize(" · " .. ps, GRAY_FONT_COLOR) end
        end
        row.activity:SetText(actText)
        if l.solo then
            local offers = (info.peer and info.peer.roles) or l.roles or {}
            setRoleIcons(row, offers, false, 3)
        else
            setGroupSlots(row, l, info)
        end
        row.check:SetShown(info.confirmed and true or false)
        row.invite:Hide()
        row.decline:Hide()
        row.unread:Hide()
    else
        local a = data.a
        local color = ns.ClassColor(a.class)
        if not (a.class and ns.SetAtlas(row.icon, "groupfinder-icon-class-" .. strlower(a.class))) then
            ns.SetAtlas(row.icon, "groupfinder-icon-leader", true)
        end
        row.name:SetText(ns.Display(a.name))
        row.name:SetTextColor(color.r, color.g, color.b)
        row.level:SetText((a.level and (LEVEL_ABBR .. " " .. a.level) or "") .. "  " .. ns.Ago(ns.Now() - (a.at or 0)))
        row.activity:SetText(P.colorize("\"" .. (a.lastText or "") .. "\"", HIGHLIGHT_FONT_COLOR))
        if a.role then
            setRoleIcons(row, { [a.role] = true }, false, 1)
            row.roles[1]:ClearAllPoints()
            row.roles[1]:SetPoint("TOPRIGHT", -12, -7)
        else
            setRoleIcons(row, {}, false, 0)
        end
        row.check:SetShown(a.confirmed and true or false)
        row.invite:Show()
        row.decline:Show()
        row.unread:SetShown(a.unread and true or false)
    end
    if data.kind == "listing" then
        row.roles[1]:ClearAllPoints()
        row.roles[1]:SetPoint("BOTTOMRIGHT", -12, 9)
    end

    row.badges:SetText(P.badgesFor(data))
    local label, lcolor = ns.Score.Label(info)
    if data.kind == "applicant" then label = nil end
    row.match:SetText(label and P.colorize(label, lcolor) or "")

    -- Keep text clear of the right-hand icons.
    local w = P.panel.scrollBox:GetWidth()
    if w and w > 0 then
        local right = data.kind == "applicant" and 112 or 110
        row.activity:SetWidth(math.max(60, w - 50 - right))
        row.badges:SetWidth(math.max(60, w - 50 - right))
        row.name:SetWidth(0)
        local maxName = math.max(60, w - 50 - 80 - (row.match:GetStringWidth() or 0) - (row.level:GetStringWidth() or 0))
        if row.name:GetStringWidth() > maxName then row.name:SetWidth(maxName) end
    end
end
