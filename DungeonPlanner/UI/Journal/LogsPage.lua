-- LogsPage.lua
-- Character Logs: every run of every character, best times, and one run in detail.
local _, ns = ...
local L = ns.L
local J = ns.Journal
local P = ns.Private("Journal")

local MAX_SHOWN = 60   -- runs per character on the page

local function num(n)
    n = math.floor(n or 0)
    if BreakUpLargeNumbers then local ok, s = pcall(BreakUpLargeNumbers, n) if ok and s then return s end end
    return tostring(n)
end

local function when(t) return date(L.LOG_DATE_FORMAT, t) end

local function classColor(class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    return c and ("|cff%02x%02x%02x"):format(c.r * 255, c.g * 255, c.b * 255) or "|cffffffff"
end

local function result(run)
    if run.done then return GREEN_FONT_COLOR:WrapTextInColorCode(L.LOG_CLEARED) end
    if run.reset then return GRAY_FONT_COLOR:WrapTextInColorCode(L.LOG_RESET) end
    local n = #(run.bosses or {})
    if run.total and run.total > 0 then return ORANGE_FONT_COLOR:WrapTextInColorCode(L.LOG_BOSSES_OF:format(n, run.total)) end
    return ORANGE_FONT_COLOR:WrapTextInColorCode(L.LOG_BOSSES:format(n))
end

local function runSub(run, live)
    local parts = { live and L.LOG_SO_FAR:format(ns.RunLog.Duration(ns.Now() - run.start)) or when(run.start) }
    if not live then tinsert(parts, ns.RunLog.Duration(run.dur)) end
    tinsert(parts, #(run.party or {}) > 0 and L.LOG_GROUP:format(#run.party + 1) or L.LOG_SOLO)
    if (run.deaths or 0) > 0 then tinsert(parts, L.LOG_DEATHS:format(run.deaths)) end
    if (run.xp or 0) > 0 then tinsert(parts, L.LOG_XP:format(num(run.xp))) end
    return table.concat(parts, "  ·  ")
end

StaticPopupDialogs.DUNGEONPLANNER_DELETE_RUN = {
    text = L.LOG_DELETE_CONFIRM, button1 = YES or "Yes", button2 = NO or "No",
    OnAccept = function(_, data)
        if data then ns.RunLog.Delete(data.key, data.run) end
        if J.CurrentPage() == "run" then J.ShowPage("logs") else J.Refresh() end
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}
local function askDelete(key, run)
    if StaticPopup_Show then StaticPopup_Show("DUNGEONPLANNER_DELETE_RUN", run.dungeon, when(run.start), { key = key, run = run }) end
end

local function runRow(key, run)
    return { kind = "line", h = 50, card = { run.dungeon }, text = ns.RunLog.Label(run), sub = runSub(run), right = result(run),
        dim = not run.done,
        onClick = function(button)
            if button == "RightButton" then askDelete(key, run) else J.ShowPage("run", { key = key, run = run }) end
        end,
        tooltip = function(tt)
            tt:SetText(run.dungeon, 1, 0.82, 0)
            tt:AddLine(when(run.start), 1, 1, 1)
            tt:AddLine(L.LOG_CLICK, 0.6, 0.6, 0.6)
        end }
end

local function logsRows()
    local RL = ns.RunLog
    local rows = {}
    local live = RL.Active()
    if live and not live.leftAt then
        tinsert(rows, { kind = "header", text = L.LOG_IN_PROGRESS, h = 26 })
        tinsert(rows, { kind = "line", h = 50, card = { live.dungeon }, text = ns.RunLog.Label(live), sub = runSub(live, true),
            right = result(live) })
        tinsert(rows, { kind = "spacer", h = 8 })
    end
    local chars = RL.Characters()
    if #chars == 0 then
        tinsert(rows, { kind = "text", h = 60, text = L.LOG_EMPTY })
        return rows
    end
    -- Best times for this character, with your group's when they told us.
    local me = chars[1].me and chars[1]
    if me then
        tinsert(rows, { kind = "header", text = L.LOG_BEST_TIMES, h = 26 })
        for _, s in ipairs(RL.Summary(me.key)) do
            local others = {}
            for i, p in ipairs(RL.PartyTimes(s.dungeon)) do
                if i > 3 then break end
                tinsert(others, ("%s %s"):format(p.name, RL.Duration(p.seconds)))
            end
            tinsert(rows, { kind = "line", h = 34, boxed = false, text = s.dungeon,
                sub = #others > 0 and L.LOG_PARTY_BEST:format(table.concat(others, ", ")) or nil,
                right = (s.best and RL.Duration(s.best) or "-") .. "  " .. GRAY_FONT_COLOR:WrapTextInColorCode(L.LOG_RUNS:format(s.runs, s.cleared)) })
        end
        tinsert(rows, { kind = "spacer", h = 8 })
    end
    for _, c in ipairs(chars) do
        local title = classColor(c.class) .. c.name .. "|r" .. (c.realm and c.realm ~= "" and (" - " .. c.realm) or "")
        tinsert(rows, { kind = "header", text = title, right = L.LOG_RUN_COUNT:format(#c.runs), h = 26 })
        for i, run in ipairs(c.runs) do
            if i > MAX_SHOWN then break end
            tinsert(rows, runRow(c.key, run))
        end
        tinsert(rows, { kind = "spacer", h = 8 })
    end
    return rows
end

local function stat(label, value)
    return { kind = "line", h = 24, boxed = false, text = label, right = value, font = "GameFontNormalSmall" }
end

local function runRows(cur)
    local RL = ns.RunLog
    local run = cur.arg and cur.arg.run
    if not run then return { { kind = "text", h = 40, text = L.LOG_EMPTY } } end
    local rows = {}
    tinsert(rows, { kind = "header", text = L.LOG_SUMMARY, h = 26 })
    tinsert(rows, stat(L.LOG_TIME, RL.Duration(run.dur)))
    tinsert(rows, stat(L.LOG_RESULT, result(run)))
    tinsert(rows, stat(L.LOG_WITH, #(run.party or {}) > 0 and table.concat(run.party, ", ") or L.LOG_SOLO))
    tinsert(rows, stat(L.LOG_DEATHS_LABEL, num(run.deaths)))
    tinsert(rows, stat(L.LOG_KILLS_LABEL, num(run.kills)))
    tinsert(rows, stat(L.LOG_XP_LABEL, num(run.xp) .. ((run.questXP or 0) > 0 and ("  " .. GRAY_FONT_COLOR:WrapTextInColorCode(L.LOG_QUEST_XP:format(num(run.questXP)))) or "")))
    tinsert(rows, stat(L.LOG_MONEY_LABEL, RL.Money(run.money)))
    if run.level then tinsert(rows, stat(LEVEL or "Level", tostring(run.level))) end
    tinsert(rows, { kind = "spacer", h = 10 })
    tinsert(rows, { kind = "header", text = L.J_BOSSES, h = 26 })
    if #(run.bosses or {}) == 0 then tinsert(rows, { kind = "text", h = 30, text = L.LOG_NO_BOSSES }) end
    local prev = 0
    for i, b in ipairs(run.bosses or {}) do
        local split = b.t - prev
        prev = b.t
        tinsert(rows, { kind = "line", h = 52, display = ns.DMap.DisplayFor(b.name), portraitIcon = ns.DMap.IconFor(b.name),
            text = ("%d. %s"):format(i, b.name),
            sub = L.LOG_BOSS_SUB:format(RL.Duration(b.t), num(b.xp)),
            right = GRAY_FONT_COLOR:WrapTextInColorCode("+" .. RL.Duration(split)) })
    end
    local times = RL.PartyTimes(RL.Label(run))
    local best = RL.Best(RL.Label(run))
    if #times > 0 or best then
        tinsert(rows, { kind = "spacer", h = 10 })
        tinsert(rows, { kind = "header", text = L.LOG_COMPARE, h = 26 })
        if best then tinsert(rows, stat(L.LOG_YOU, RL.Duration(best))) end
        for _, p in ipairs(times) do tinsert(rows, stat(p.name, RL.Duration(p.seconds))) end
    end
    return rows
end

J.RegisterPage("logs", { nav = L.LOG_TITLE, iconTex = "Interface\\Icons\\INV_Misc_Book_11", order = 20,
    title = function() return L.LOG_TITLE end,
    sub = function()
        local n = 0
        for _, c in ipairs(ns.RunLog.Characters()) do n = n + #c.runs end
        return L.LOG_SUB:format(n)
    end,
    rows = logsRows })

J.RegisterPage("run", {
    title = function(cur) return cur.arg and cur.arg.run and ns.RunLog.Label(cur.arg.run) or L.LOG_TITLE end,
    sub = function(cur)
        local run = cur.arg and cur.arg.run
        if not run then return "" end
        local c = ns.db.runLog and ns.db.runLog.chars[cur.arg.key]
        return when(run.start) .. (c and ("  ·  " .. c.name) or "")
    end,
    rows = runRows,
    button = function(cur)
        return { text = L.LOG_DELETE, onClick = function() if cur.arg then askDelete(cur.arg.key, cur.arg.run) end end }
    end })

ns.Listen("RUNLOG_CHANGED", function() if J.CurrentPage() == "logs" then J.Refresh() end end)
