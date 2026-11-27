-- ContentRow.lua
-- Filling a content row: bosses, quests, loot, headers.
local _, ns = ...
local L = ns.L
local J = ns.Journal
local Q_TITLE, Q_LVL, Q_MIN, Q_FACTION, Q_CLASS, Q_PRE, Q_START, Q_END, Q_REWARDS, Q_MAP, Q_OBJ = 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
local I_NAME, I_QUALITY, I_INV, I_REQ = 1, 2, 3, 4
local Q = ns.Quests
local P = ns.Private("Journal")

local init

-- Quest rows whose quest is in your log open it with a secure click (UI/QuestLogOpener).
function P.initContentRow(row, data)
    local O = ns.QuestLogOpener
    if O then O.Release(row) end
    row.logQuest = nil
    init(row, data)
    row.logQuest = row.logQuest or data.logQuest
    if row.logQuest and O then
        local enter = row:GetScript("OnEnter")
        row:SetScript("OnEnter", function(self)
            if self.logQuest then O.Cover(self, self.logQuest) end
            if enter then enter(self) end
        end)
    end
end

function init(row, data)
    if not row.built then P.buildRow(row) end
    P.resetRow(row)
    row.data = data
    local k = data.kind
    if k == "spacer" then
        row:EnableMouse(false)
        return
    end
    row:EnableMouse(true)
    if k == "line" then return P.initLineRow(row, data) end
    if k == "tabs" then
        -- data.tabs = { { text, selected, onClick } }: tabs like the dungeon page's, inside a page.
        row.tabBtns = rawget(row, "tabBtns") or {}
        local prev
        for i, t in ipairs(data.tabs) do
            local b = row.tabBtns[i]
            if not b then
                local ok, nb = pcall(CreateFrame, "Button", nil, row, "PanelTopTabButtonTemplate")
                b = ok and nb or CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                row.tabBtns[i] = b
            end
            b:SetText(t.text)
            if PanelTemplates_TabResize then pcall(PanelTemplates_TabResize, b, 0) else b:SetSize(110, 24) end
            b:ClearAllPoints()
            if prev then b:SetPoint("LEFT", prev, "RIGHT", 2, 0) else b:SetPoint("BOTTOMLEFT", 10, 0) end
            local sel = t.selected and PanelTemplates_SelectTab or PanelTemplates_DeselectTab
            if sel then pcall(sel, b) end
            b:SetScript("OnClick", function()
                if SOUNDKIT and PlaySound then PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB) end
                t.onClick()
            end)
            b:Show()
            prev = b
        end
        return
    end
    if k == "header" then
        row.bg:SetColorTexture(1, 0.82, 0, 0.08)
        row.text:SetFontObject("GameFontNormal")
        row.text:SetPoint("LEFT", 10, 0)
        row.text:SetText(data.text)
        row.right:SetText(data.right or "")
        if data.showAll then
            row:SetScript("OnClick", function() J.ShowDungeon(P.current.map, 3) end)
        elseif data.showAllForever then
            row:SetScript("OnClick", function() P.current.boss = nil; J.Refresh() end)
        end
    elseif k == "text" then
        row.text:SetFontObject("GameFontHighlightSmall")
        row.text:SetWordWrap(true)
        row.text:SetPoint("TOPLEFT", 12, -4)
        row.text:SetPoint("RIGHT", -12, 0)
        row.text:SetText(data.text)
    elseif k == "boss" then
        P.setPortrait(row, data.display, 42, data.killed, 18, ns.DMap.IconFor(data.name, data.alias))
        if data.level then
            row.badge.text:SetText(data.level)
            row.badge:Show()
        end
        row.check:SetShown(data.killed and true or false)
        row.bg:SetColorTexture(1, 1, 1, 0.035)
        P.setEdges(row, 0.35, 0.28, 0.16, 0.6, 3)
        row.text:SetFontObject(_G.GameFontNormalMed2 and "GameFontNormalMed2" or "GameFontNormal")
        local hasSub = data.killed or (data.lootN and data.lootN > 0) or data.tag
        if hasSub then
            row.text:SetPoint("BOTTOMLEFT", row.portrait, "RIGHT", 18, 2)
        else
            row.text:SetPoint("LEFT", row.portrait, "RIGHT", 18, 0)
        end
        row.text:SetPoint("RIGHT", -70, 0)
        row.text:SetText(("%d. %s"):format(data.index, data.name))
        if data.killed then row.text:SetTextColor(0.6, 0.6, 0.6) else row.text:SetTextColor(1, 0.82, 0) end
        row.sub:SetPoint("TOPLEFT", row.text, "BOTTOMLEFT", 0, -5)
        local parts = {}
        if data.killed then tinsert(parts, GREEN_FONT_COLOR:WrapTextInColorCode(L.MAP_KILLED)) end
        if data.lootN and data.lootN > 0 then tinsert(parts, L.J_CAN_DROP:format(data.lootN)) end
        if data.tag then tinsert(parts, data.tag) end
        row.sub:SetText(table.concat(parts, "  ·  "))
        row.right:ClearAllPoints()
        row.right:SetPoint("RIGHT", -16, 0)
        row.right:SetText(data.upgrades and data.upgrades > 0 and (ns.AtlasMarkup("bags-greenarrow", 14) .. " " .. data.upgrades) or "")
        row:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(data.name, 1, 0.82, 0)
            if data.level then GameTooltip:AddLine(LEVEL .. " " .. data.level, 1, 1, 1) end
            if data.upgrades and data.upgrades > 0 then GameTooltip:AddLine(L.J_BOSS_UPGRADES:format(data.upgrades), 0.4, 1, 0.4) end
            local secret = ns.SecretsSvc and ns.SecretsSvc.BossText(data.name)
            if secret then
                GameTooltip:AddLine(L.SECRET_BOSS, 0.75, 0.6, 1)
                GameTooltip:AddLine(secret, 0.9, 0.85, 0.7, true)
                GameTooltip:AddLine(L.SECRET_BOSS_HINT, 0.6, 0.6, 0.6)
            end
            GameTooltip:AddLine(L.MAP_CLICK_LOOT, 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
        row:SetScript("OnClick", function(_, button)
            local s = button == "RightButton" and ns.SecretsSvc and ns.SecretsSvc.ForBoss(data.name)
            if s then return J.ShowPage("secret", s.id) end
            if data.npc then J.ShowDungeon(P.current.map, 3, data.npc)
            elseif P.current.kind == "activity" then P.current.boss = data.name; P.tab = 3; J.Refresh() end
        end)
    elseif k == "bosscard" then
        P.setPortrait(row, data.display, 60, false, 22, ns.DMap.IconFor(data.name, data.alias))
        if data.level then row.badge.text:SetText(data.level); row.badge:Show() end
        row.bg:SetColorTexture(0, 0, 0, 0.35)
        P.setEdges(row, 0.6, 0.48, 0.2, 0.8, 4)
        row.text:SetFontObject("GameFontHighlightLarge")
        row.text:SetPoint("BOTTOMLEFT", row.portrait, "RIGHT", 22, 3)
        row.text:SetText(data.name)
        row.text:SetTextColor(1, 1, 1)
        row.sub:SetFontObject("GameFontNormal")
        row.sub:SetPoint("TOPLEFT", row.text, "BOTTOMLEFT", 0, -6)
        row.sub:SetText(data.lootN and data.lootN > 0 and ("|cffff5a3c" .. L.J_CAN_DROP:format(data.lootN) .. "|r") or "")
        row.right:SetText(GRAY_FONT_COLOR:WrapTextInColorCode(L.J_SHOW_ALL))
        row:SetScript("OnClick", data.onAll)
    elseif k == "quest" then
        local q = data.q
        local st = data.status
        ns.SetAtlas(row.icon, P.STATUS_ATLAS[st])
        row.icon:SetDesaturated(st == "level" or st == "locked" or st == "inside")
        row.icon:Show()
        row.text:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 6, 4)
        row.text:SetPoint("RIGHT", -172, 0)
        local color = (st == "done" and GRAY_FONT_COLOR) or P.questColor(q and q[Q_LVL])
        row.text:SetText(color:WrapTextInColorCode((q and ("[" .. q[Q_LVL] .. "] ") or "") .. Q.Title(data.id)))
        row.sub:SetPoint("TOPLEFT", row.text, "BOTTOMLEFT", 0, -3)
        row.sub:SetPoint("RIGHT", -172, 0)
        row.sub:SetText(data.subText or "")
        -- Needs an earlier quest: say which one to do first, right on the row.
        local firstOpen, step, steps
        if st == "locked" then
            local chain = Q.Chain(data.id)
            firstOpen = Q.FirstOpen(data.id)
            for i, cq in ipairs(chain) do if cq == firstOpen then step = i end end
            steps = #chain
            if firstOpen and firstOpen ~= data.id then
                -- Say plainly whose quest is in the log: the earlier one, never this one.
                local t = Q.Title(firstOpen)
                local text
                local _, firstDone = Q.Progress(firstOpen)
                if Q.InLog(firstOpen) and firstDone then
                    text = (step and steps > 1) and L.J_TURN_IN_FIRST_STEP:format(t, step, steps) or L.J_TURN_IN_FIRST:format(t)
                elseif Q.InLog(firstOpen) then
                    text = (step and steps > 1) and L.J_FINISH_FIRST_STEP:format(t, step, steps) or L.J_FINISH_FIRST:format(t)
                else
                    text = (step and steps > 1) and L.J_DO_FIRST_STEP:format(t, step, steps) or L.J_DO_FIRST:format(t)
                end
                row.sub:SetText(ORANGE_FONT_COLOR:WrapTextInColorCode(text))
            end
        end
        if st == "log" then
            local progress, complete = Q.Progress(data.id)
            P.markInLog(row, complete)
            row.sub:SetText(complete and GREEN_FONT_COLOR:WrapTextInColorCode(data.endName and L.J_TURN_IN_TO:format(data.endName) or L.J_OBJECTIVES_DONE)
                or ("|cff60e060" .. (progress and L.J_PROGRESS:format(progress) or L.J_STATUS_LOG) .. "|r"))
        end
        local captured = ns.QuestText and ns.QuestText.For(data.id)
        local obj = (q and q[Q_OBJ] ~= "" and q[Q_OBJ]) or (captured and captured.obj)
        local warn = ns.QuestText and ns.QuestText.Warning(data.id, Q.Title(data.id))
        local tips = ns.QuestText and ns.QuestText.Tips(data.id) or {}
        if not warn and tips[1] and tips[1].kind == "out" then warn = tips[1].text end
        if warn then obj = "|cffff8040" .. warn .. "|r" .. (obj and ("  " .. obj) or "") end
        if obj and obj ~= "" then
            row.icon:ClearAllPoints(); row.icon:SetPoint("TOPLEFT", 6, -8)
            row.desc:SetPoint("TOPLEFT", row.sub, "BOTTOMLEFT", 0, -3)
            row.desc:SetPoint("RIGHT", -172, 0)
            row.desc:SetHeight(26)
            row.desc:SetText(obj)
            row.desc:Show()
        end
        if data.place then
            row.pin:Show()
            row.pin:ClearAllPoints()
            row.pin:SetPoint("RIGHT", -118, 0)
            row.pin:SetScript("OnClick", function()
                local p = data.place
                local learned = p.ui and { m = p.ui, x = p[1], y = p[2] } or nil
                ns.Maps.PinQuest(data.id, data.placeName, learned, p[3], p[1], p[2])
            end)
            row.pin:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L.J_SET_WAYPOINT, 1, 1, 1)
                local p = data.place
                local where = p.ui and ns.Maps.UiPlaceText(p.ui, p[1], p[2]) or ns.Maps.PlaceText(p[3], p[1], p[2])
                GameTooltip:AddLine(data.placeName or "", NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
                if where then GameTooltip:AddLine(where, 1, 1, 1) end
                GameTooltip:Show()
            end)
            row.pin:SetScript("OnLeave", GameTooltip_Hide)
        end
        if st ~= "done" then
            row.guide:Show()
            row.guide:ClearAllPoints()
            row.guide:SetPoint("RIGHT", -146, 0)
            row.guide:SetScript("OnClick", function()
                -- Starts from a drop inside: the way there is the dungeon's entrance.
                if st == "inside" and P.current.kind == "dungeon" then return ns.Nav.GuideToDungeon(P.current.map) end
                Q.Guide(data.id)
            end)
            row.guide:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(st == "inside" and L.J_GUIDE_ENTRANCE or L.J_GUIDE_ME, 1, 1, 1)
                local first = Q.FirstOpen(data.id)
                if first ~= data.id then
                    GameTooltip:AddLine(L.NAV_CHAIN_SHORT:format(Q.Title(first)), 1, 0.5, 0.25, true)
                elseif data.placeName then
                    GameTooltip:AddLine(data.placeName, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
                end
                GameTooltip:Show()
            end)
            row.guide:SetScript("OnLeave", GameTooltip_Hide)
        end
        local rewards = q and q[Q_REWARDS] or {}
        for i = 1, math.min(4, #rewards) do
            local b = row.rewards[i]
            b.itemID = rewards[i]
            b.tex:SetTexture(ns.Call(C_Item and C_Item.GetItemIconByID, rewards[i]) or 134400)
            b.up:SetShown(ns.Gear.IsUpgrade(rewards[i]))
            b:ClearAllPoints()
            if i == 1 then b:SetPoint("RIGHT", -8, 0) else b:SetPoint("RIGHT", row.rewards[i - 1], "LEFT", -2, 0) end
            b:Show()
        end
        row:SetScript("OnEnter", function(self)
            if ns.opt.questTooltips == false then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(Q.Title(data.id), 1, 1, 1)
            if q and q[Q_OBJ] and q[Q_OBJ] ~= "" then GameTooltip:AddLine(q[Q_OBJ], 0.9, 0.85, 0.7, true)
            elseif captured and captured.obj then GameTooltip:AddLine(captured.obj, 0.9, 0.85, 0.7, true) end
            if warn then GameTooltip:AddLine(warn, 1, 0.5, 0.25, true) end
            for _, tip in ipairs(tips) do
                if tip.text ~= warn then GameTooltip:AddLine(tip.text, 0.55, 0.78, 1, true) end
            end
            if captured and captured.text then GameTooltip:AddLine(" "); GameTooltip:AddLine(captured.text, 0.7, 0.7, 0.7, true) end
            if q then
                GameTooltip:AddLine(L.J_QUEST_LEVELS:format(q[Q_LVL], q[Q_MIN]), 0.8, 0.8, 0.8)
                if q[Q_PRE] > 0 then
                    local done = Q.IsDone(q[Q_PRE])
                    GameTooltip:AddLine(L.J_REQUIRES:format(Q.Title(q[Q_PRE])), done and 0.5 or 1, done and 0.5 or 0.3, done and 0.5 or 0.3, true)
                end
                if data.endName then GameTooltip:AddLine(L.J_TURN_IN:format(data.endName), 0.8, 0.8, 0.8, true) end
                local chain = Q.Chain(data.id)
                if #chain > 1 then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine(L.J_CHAIN, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
                    for i, cq in ipairs(chain) do
                        local done = Q.IsDone(cq)
                        local mark = done and ns.AtlasMarkup("common-icon-checkmark", 12) or (Q.InLog(cq) and ns.AtlasMarkup("QuestTurnin", 12) or "  ")
                        GameTooltip:AddLine(("%s %d. %s"):format(mark, i, Q.Title(cq)), done and 0.5 or 1, done and 0.5 or 1, done and 0.5 or 1)
                    end
                end
            end
            if ns.QuestRewards then ns.QuestRewards.AddToTooltip(GameTooltip, data.id) end
            if st == "log" then GameTooltip:AddLine(L.J_CLICK_OPEN_LOG, 0.4, 1, 0.45) end
            if firstOpen and firstOpen ~= data.id and Q.InLog(firstOpen) then
                GameTooltip:AddLine(L.J_CLICK_OPEN_FIRST:format(Q.Title(firstOpen)), 0.4, 1, 0.45, true)
            end
            if firstOpen and firstOpen ~= data.id then
                GameTooltip:AddLine(L.J_DO_FIRST:format(Q.Title(firstOpen)), 1, 0.5, 0.25, true)
                GameTooltip:AddLine(L.J_GUIDE_FIRST_HINT, 0.6, 0.6, 0.6, true)
            else
                GameTooltip:AddLine(L["J_STATUS_" .. strupper(data.status)], NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
            end
            GameTooltip:Show()
        end)
        if st == "log" then row.logQuest = data.id
        elseif firstOpen and firstOpen ~= data.id and Q.InLog(firstOpen) then row.logQuest = firstOpen end
        row:SetScript("OnClick", function()
            if IsModifiedClick("CHATLINK") and GetQuestLink then
                local link = ns.Call(GetQuestLink, data.id)
                if link and HandleModifiedItemClick then HandleModifiedItemClick(link) end
            elseif st == "log" then
                Q.OpenInLog(data.id)
            elseif firstOpen and firstOpen ~= data.id and Q.InLog(firstOpen) then
                -- Later in a chain: open the quest of the chain you have now.
                Q.OpenInLog(firstOpen)
            end
        end)
    elseif k == "fquest" then
        local fq, st = data.fq, data.status
        ns.SetAtlas(row.icon, P.STATUS_ATLAS[st])
        row.icon:SetDesaturated(st == "level")
        row.icon:Show()
        row.text:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 6, 4)
        row.text:SetPoint("RIGHT", -60, 0)
        local color = (st == "done" and GRAY_FONT_COLOR) or P.questColor(fq.lvl)
        local side = fq.side == "A" and (" " .. ns.AtlasMarkup("groupfinder-icon-friend", 12)) or ""
        row.text:SetText(color:WrapTextInColorCode((fq.lvl and ("[" .. fq.lvl .. "] ") or "") .. fq.title))
        row.sub:SetPoint("TOPLEFT", row.text, "BOTTOMLEFT", 0, -3)
        row.sub:SetPoint("RIGHT", -60, 0)
        local where = fq.zone and (fq.x and ("%s (%.1f, %.1f)"):format(fq.zone, fq.x, fq.y) or fq.zone) or (fq.note or "")
        row.sub:SetText((fq.giver and (fq.giver .. " · ") or "") .. where)
        if fq.after and st ~= "done" and st ~= "log" and Q.ForeverStatus({ title = fq.after }) ~= "done" then
            row.sub:SetText(ORANGE_FONT_COLOR:WrapTextInColorCode(L.J_DO_FIRST:format(fq.after)))
        end
        if st == "log" then
            local _, id = Q.ForeverStatus(fq)
            local progress, complete = Q.Progress(id)
            P.markInLog(row, complete)
            row.sub:SetText(complete and GREEN_FONT_COLOR:WrapTextInColorCode(L.J_OBJECTIVES_DONE)
                or ("|cff60e060" .. (progress and L.J_PROGRESS:format(progress) or L.J_STATUS_LOG) .. "|r"))
        end
        local capturedF = ns.QuestText and ns.QuestText.ForTitle(fq.title)
        local obj = fq.obj or (capturedF and capturedF.obj) or (fq.zone and fq.note)
        local fwarn = ns.QuestText and ns.QuestText.Warning(nil, fq.title)
        if fwarn then obj = "|cffff8040" .. fwarn .. "|r" .. (obj and ("  " .. obj) or "") end
        if obj then
            row.icon:ClearAllPoints(); row.icon:SetPoint("TOPLEFT", 6, -8)
            row.desc:SetPoint("TOPLEFT", row.sub, "BOTTOMLEFT", 0, -3)
            row.desc:SetPoint("RIGHT", -60, 0)
            row.desc:SetHeight(26)
            row.desc:SetText(obj)
            row.desc:Show()
        end
        if fq.zone and fq.x then
            row.pin:Show()
            row.pin:ClearAllPoints()
            row.pin:SetPoint("RIGHT", -8, 0)
            row.pin:SetScript("OnClick", function() Q.PinForever(fq) end)
            row.pin:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L.J_SET_WAYPOINT, 1, 1, 1)
                GameTooltip:Show()
            end)
            row.pin:SetScript("OnLeave", GameTooltip_Hide)
        end
        if st ~= "done" then
            row.guide:Show()
            row.guide:ClearAllPoints()
            row.guide:SetPoint("RIGHT", -34, 0)
            row.guide:SetScript("OnClick", function() Q.GuideForeverChain(fq) end)
            row.guide:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L.J_GUIDE_ME, 1, 1, 1)
                if fq.giver then GameTooltip:AddLine(fq.giver, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b) end
                GameTooltip:Show()
            end)
            row.guide:SetScript("OnLeave", GameTooltip_Hide)
        end
        row:SetScript("OnEnter", function(self)
            if ns.opt.questTooltips == false then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(fq.title, 1, 1, 1)
            if fq.obj or (capturedF and capturedF.obj) then GameTooltip:AddLine(fq.obj or capturedF.obj, 0.9, 0.85, 0.7, true) end
            if fwarn then GameTooltip:AddLine(fwarn, 1, 0.5, 0.25, true) end
            if capturedF and capturedF.text then GameTooltip:AddLine(" "); GameTooltip:AddLine(capturedF.text, 0.7, 0.7, 0.7, true) end
            if fq.lvl then GameTooltip:AddLine(LEVEL .. " " .. fq.lvl, 0.8, 0.8, 0.8) end
            if fq.giver then GameTooltip:AddLine(L.J_FROM:format(fq.giver), 1, 1, 1) end
            if fq.zone then GameTooltip:AddLine(fq.x and ("%s %.1f, %.1f"):format(fq.zone, fq.x, fq.y) or fq.zone, 0.8, 0.8, 0.8) end
            if fq.after then
                local done = Q.ForeverStatus({ title = fq.after }) == "done"
                GameTooltip:AddLine(L.J_REQUIRES:format(fq.after), done and 0.5 or 1, done and 0.5 or 0.6, done and 0.5 or 0.3, true)
            end
            if fq.note then GameTooltip:AddLine(fq.note, 1, 0.82, 0, true) end
            -- What the game showed for this quest beats our notes; otherwise the reward names we have.
            local shown = ns.QuestRewards and ns.QuestRewards.AddToTooltip(GameTooltip, nil, fq.title)
            if not shown and fq.rewards then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(L.J_REWARDS, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
                for _, r in ipairs(fq.rewards) do GameTooltip:AddLine("  " .. r, 0.4, 0.6, 1) end
            end
            GameTooltip:AddLine(L["J_STATUS_" .. strupper(st)], NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
            if st == "log" then GameTooltip:AddLine(L.J_CLICK_OPEN_LOG, 0.4, 1, 0.45) end
            GameTooltip:Show()
        end)
        do
            local _, lid = Q.ForeverStatus(fq)
            if st == "log" then row.logQuest = lid
            else
                local first = Q.ForeverFirstOpen(fq)
                local fst, fid = Q.ForeverStatus(first)
                if first ~= fq and fst == "log" then row.logQuest = fid end
            end
        end
        row:SetScript("OnClick", function()
            if st == "log" then
                local _, id = Q.ForeverStatus(fq)
                Q.OpenInLog(id)
            else
                local first = Q.ForeverFirstOpen(fq)
                local fst, fid = Q.ForeverStatus(first)
                if first ~= fq and fst == "log" then Q.OpenInLog(fid) end
            end
        end)
    elseif k == "fitem" then
        row.icon:SetTexture(data.itemID and ns.Call(C_Item and C_Item.GetItemIconByID, data.itemID) or 134400)
        row.icon:Show()
        row.text:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 6, 2)
        row.text:SetPoint("RIGHT", -60, 0)
        local it = data.itemID and ns.Gear.Item(data.itemID)
        local quality = it and it[I_QUALITY] or 2
        row.text:SetText(P.itemColor(quality):WrapTextInColorCode(data.name))
        row.sub:SetPoint("TOPLEFT", row.text, "BOTTOMLEFT", 0, -2)
        row.sub:SetText((data.slot ~= "" and (data.slot .. " · ") or "") .. data.boss .. "  " .. L.J_NEW_IN_FOREVER)
        if data.chance then row.right:SetText(GRAY_FONT_COLOR:WrapTextInColorCode(data.chance .. "%")) end
        if data.itemID then
            local up, r = ns.Gear.IsUpgrade(data.itemID)
            row.right:SetText(up and P.colorizeGreen(ns.Gear.GainText(r)) or "")
            row:SetScript("OnEnter", function(self) P.showItemTooltip(self, data.itemID) end)
            row:SetScript("OnClick", function(_, button) P.itemClick(data.itemID, button, data.boss, data.dungeon) end)
            row.star:SetShown(ns.Wishlist and ns.Wishlist.Has(data.itemID) or false)
        else
            row:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(data.name, 1, 1, 1)
                GameTooltip:AddLine(data.slot, 1, 1, 1)
                GameTooltip:AddLine(L.J_FROM:format(data.boss), 0.8, 0.8, 0.8)
                GameTooltip:AddLine(L.J_ITEM_UNSEEN, 0.6, 0.6, 0.6, true)
                GameTooltip:Show()
            end)
        end
    elseif k == "item" then
        local it = ns.Gear.Item(data.item)
        row.icon:SetTexture(ns.Call(C_Item and C_Item.GetItemIconByID, data.item) or 134400)
        row.icon:Show()
        row.text:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 6, 2)
        row.text:SetPoint("RIGHT", -120, 0)
        local quality = (it and it[I_QUALITY]) or 1
        row.text:SetText(P.itemColor(quality):WrapTextInColorCode(P.itemName(data.item)))
        row.sub:SetPoint("TOPLEFT", row.text, "BOTTOMLEFT", 0, -2)
        local slot = it and ns.Gear.SLOT_NAMES[it[I_INV]] or ""
        local _, _, subType, _, _, classID = ns.Call(C_Item and C_Item.GetItemInfoInstant, data.item)
        if classID == 4 and subType and subType ~= "" and subType ~= MISCELLANEOUS then slot = slot ~= "" and (slot .. ", " .. subType) or subType
        elseif classID == 2 and subType then slot = subType
        elseif classID == 9 and subType then slot = subType end
        local req = it and (it[I_REQ] or 0) > 0 and (" · " .. LEVEL .. " " .. it[I_REQ]) or ""
        local mark = data.forever and ("  " .. L.J_NEW_IN_FOREVER) or (data.seen and ("  " .. L.J_SEEN_FOREVER) or "")
        row.sub:SetText(slot .. req .. (data.boss and (" · " .. data.boss) or "") .. mark)
        local up, r = ns.Gear.IsUpgrade(data.item)
        local gain = up and P.colorizeGreen(ns.Gear.GainText(r)) or ""
        row.right:SetText(gain .. "  " .. GRAY_FONT_COLOR:WrapTextInColorCode(data.chance and (data.chance .. "%") or ""))
        row:SetScript("OnEnter", function(self) P.showItemTooltip(self, data.item) end)
        row:SetScript("OnClick", function(_, button) P.itemClick(data.item, button, data.bossName or data.boss, data.dungeon) end)
        row.star:SetShown(ns.Wishlist and ns.Wishlist.Has(data.item) or false)
    end
end
