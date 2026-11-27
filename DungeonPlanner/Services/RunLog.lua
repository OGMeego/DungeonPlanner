-- RunLog: Character Logs. Every dungeon run of every character you play: when, how long,
-- cleared or not, who was with you, deaths, kills, experience, money and when each boss
-- died. With your group, best times are swapped so you can compare.
-- Saved account-wide: ns.db.runLog = { chars = { [key] = { name, realm, class } },
--   runs = { [key] = { run, ... } (newest first) }, party = { [dungeon] = { [name] = seconds } } }
-- The run in progress lives in ns.cdb.activeRun, so a /reload or a disconnect keeps it.
local _, ns = ...
local L = ns.L

local RL = {}
ns.RunLog = RL

local STALE = 30 * 60     -- left the dungeon this long ago: the run is over
local MAX_RUNS = 200      -- per character
local SEP = ";"

local xpState, lastMoney

local function db()
    ns.db.runLog = ns.db.runLog or {}
    local r = ns.db.runLog
    r.chars, r.runs, r.party = r.chars or {}, r.runs or {}, r.party or {}
    return r
end

function RL.CharKey()
    local name = ns.Safe(ns.Call(UnitName, "player")) or "?"
    local realm = ns.Safe(ns.Call(GetNormalizedRealmName)) or ns.Safe(ns.Call(GetRealmName)) or ""
    return realm ~= "" and (name .. "-" .. realm) or name, name, realm
end

local function active() return ns.cdb and ns.cdb.activeRun end
local function inside(run) return run and not run.leftAt end

-- "32:10", "1:02:03"
-- "Scarlet Monastery: Library"
function RL.Label(run)
    if run.wing then return ns.L.RUN_WING:format(run.dungeon, ns.L[run.wing] or run.wing) end
    return run.dungeon
end

function RL.Duration(sec)
    sec = math.max(0, math.floor(sec or 0))
    local h, m, s = math.floor(sec / 3600), math.floor(sec / 60) % 60, sec % 60
    if h > 0 then return ("%d:%02d:%02d"):format(h, m, s) end
    return ("%d:%02d"):format(m, s)
end

function RL.Money(copper)
    copper = copper or 0
    if GetCoinTextureString then
        local ok, s = pcall(GetCoinTextureString, copper)
        if ok and s then return s end
    end
    return ("%dg %ds %dc"):format(math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100)
end

local function partyNames()
    local out = {}
    local n = ns.Call(GetNumGroupMembers) or 0
    if n <= 1 then return out end
    local prefix = (IsInRaid and IsInRaid()) and "raid" or "party"
    for i = 1, (prefix == "raid" and n or n - 1) do
        local name = ns.Safe(ns.Call(UnitName, prefix .. i))
        if name and name ~= ns.Safe(ns.Call(UnitName, "player")) then tinsert(out, name) end
    end
    return out
end

local function notePartyMembers(run)
    run.party = run.party or {}
    local seen = {}
    for _, n in ipairs(run.party) do seen[n] = true end
    for _, n in ipairs(partyNames()) do
        if not seen[n] then tinsert(run.party, n); seen[n] = true end
    end
end

-- ---------------------------------------------------------------------------
-- Start and finish
-- ---------------------------------------------------------------------------

function RL.Best(dungeon)
    local key = RL.CharKey()
    local best
    for _, r in ipairs(db().runs[key] or {}) do
        if r.done and (r.dungeon == dungeon or RL.Label(r) == dungeon) and (not best or r.dur < best) then best = r.dur end
    end
    return best
end

local function shareBest(dungeon, seconds)
    if not (dungeon and seconds and ns.Comm and ns.Comm.Group) then return end
    ns.Comm.Group(table.concat({ "T", ns.Comm.Clean(dungeon):sub(1, 60), math.floor(seconds) }, SEP))
end

local function finish(run)
    run.ended = run.doneAt or run.leftAt or ns.Now()
    run.dur = math.max(0, run.ended - run.start)
    run.leftAt, run.lastBossXP = nil, nil
    local key, name, realm = RL.CharKey()
    local d = db()
    d.chars[key] = { name = name, realm = realm, class = ns.Data.MyClass(), level = ns.Data.MyLevel() }
    d.runs[key] = d.runs[key] or {}
    tinsert(d.runs[key], 1, run)
    while #d.runs[key] > MAX_RUNS do tremove(d.runs[key]) end
    ns.cdb.activeRun = nil
    if run.done and #(run.party or {}) > 0 then shareBest(RL.Label(run), run.dur) end
    ns.Fire("RUNLOG_CHANGED")
end
RL._Finish = finish

local function start(name, mapID)
    local run = {
        dungeon = name, map = mapID, start = ns.Now(), level = ns.Data.MyLevel(),
        deaths = 0, kills = 0, xp = 0, questXP = 0, money = 0, bosses = {}, party = {},
    }
    notePartyMembers(run)
    ns.cdb.activeRun = run
    -- Tell the group your best time here, so everyone can compare.
    local best = RL.Best(name)
    if best and #run.party > 0 then shareBest(name, best) end
    ns.Fire("RUNLOG_CHANGED")
    return run
end

local function where()
    local name, instanceType, _, _, _, _, _, instanceID = ns.Call(GetInstanceInfo)
    return ns.Safe(name), instanceType, ns.Safe(instanceID)
end

function RL.Check()
    if not ns.cdb then return end
    local run = active()
    local name, instanceType, mapID = where()
    local now = ns.Now()
    if instanceType == "party" and name then
        if run and run.map == mapID and run.dungeon == name and (not run.leftAt or now - run.leftAt < STALE) then
            run.leftAt = nil                 -- back in after a corpse run or a /reload
            notePartyMembers(run)
        else
            if run then finish(run) end
            start(name, mapID)
        end
    elseif run then
        if not run.leftAt then run.leftAt = now end
        if run.done or now - run.leftAt >= STALE then finish(run) end
    end
end

-- The run in progress (for the tracker and the logs page).
function RL.Active() return active() end

-- ---------------------------------------------------------------------------
-- Counting
-- ---------------------------------------------------------------------------

local function readXP()
    return { xp = ns.Safe(ns.Call(UnitXP, "player")) or 0, max = ns.Safe(ns.Call(UnitXPMax, "player")) or 0, level = ns.Data.MyLevel() }
end

local function onXP()
    local now = readXP()
    local before = xpState
    xpState = now
    if not before then return end
    local gain
    if now.level > before.level then gain = (before.max - before.xp) + now.xp else gain = now.xp - before.xp end
    local run = active()
    if gain > 0 and inside(run) then run.xp = run.xp + gain end
end

local function onMoney()
    local m = ns.Safe(ns.Call(GetMoney))
    if not m then return end
    local before = lastMoney
    lastMoney = m
    local run = active()
    if before and m > before and inside(run) then run.money = run.money + (m - before) end
end

local function onBoss(name, raw, dungeonName)
    local run = active()
    if not (inside(run) and (name or raw)) then return end
    name = name or raw
    for _, b in ipairs(run.bosses) do if b.name == name then return end end
    local now = ns.Now()
    tinsert(run.bosses, { name = name, t = now - run.start, xp = run.xp - (run.lastBossXP or 0) })
    run.lastBossXP = run.xp
    -- Dungeons with wings (Scarlet Monastery, Dire Maul, Blackrock Spire): the run is a wing.
    local wing = ns.WingOf and ns.WingOf(run.dungeon, name)
    if wing and not run.wing then run.wing = wing.name end
    if run.wing then
        local w
        for _, x in ipairs(ns.Wings[run.dungeon:gsub("^The ", "")] or {}) do if x.name == run.wing then w = x end end
        if w then
            run.total = #w.bosses
            if ns.Data.Normalize(w.last) == ns.Data.Normalize(name) then run.done, run.doneAt = true, now end
            ns.Fire("RUNLOG_CHANGED")
            return
        end
    end
    -- Cleared: the last boss is down, or all of them are.
    local list = ns.Tracker and ns.Tracker.BossesForName(run.dungeon) or {}
    if #list > 0 then
        local killed = {}
        for _, b in ipairs(run.bosses) do killed[ns.Data.Normalize(b.name)] = true end
        local all = true
        for _, b in ipairs(list) do if not killed[ns.Data.Normalize(b)] then all = false end end
        if all or ns.Data.Normalize(list[#list]) == ns.Data.Normalize(name) then
            run.done, run.doneAt = true, now
        end
    end
    run.total = #list
    ns.Fire("RUNLOG_CHANGED")
end

ns.On("PLAYER_ENTERING_WORLD", function() xpState = readXP(); lastMoney = ns.Safe(ns.Call(GetMoney)); ns.After(1.5, RL.Check) end)
ns.On("ZONE_CHANGED_NEW_AREA", function() ns.After(1.5, RL.Check) end)
ns.On("PLAYER_XP_UPDATE", onXP)
ns.On("PLAYER_LEVEL_UP", function() ns.After(0.5, onXP) end)
ns.On("PLAYER_MONEY", onMoney)
ns.On("PLAYER_DEAD", function() local run = active() if inside(run) then run.deaths = run.deaths + 1 end end)
ns.On("CHAT_MSG_COMBAT_XP_GAIN", function() local run = active() if inside(run) then run.kills = run.kills + 1 end end)
ns.On("QUEST_TURNED_IN", function(_, xp) local run = active() xp = ns.Safe(xp) if inside(run) and xp then run.questXP = run.questXP + xp end end)
ns.On("GROUP_ROSTER_UPDATE", function() local run = active() if inside(run) then notePartyMembers(run) end end)
ns.Listen("BOSS_KILLED", onBoss)

-- "Ragefire Chasm has been reset.": the run is over, the next time in is a new run.
local resetPattern
ns.On("CHAT_MSG_SYSTEM", function(msg)
    msg = ns.Safe(msg)
    local run = active()
    if not (msg and run and INSTANCE_RESET_SUCCESS) then return end
    resetPattern = resetPattern or ("^" .. INSTANCE_RESET_SUCCESS:gsub("([%(%)%.%-%+%[%]%^%$%?%*])", "%%%1"):gsub("%%s", "(.+)") .. "$")
    local which = msg:match(resetPattern)
    if which and (which == run.dungeon or not run.leftAt) then
        run.reset = true
        if not run.leftAt then run.leftAt = ns.Now() end
        finish(run)
        ns.Print(ns.L.RUN_RESET:format(which))
    end
end)

-- Start a new run now (/dp newrun), e.g. after resetting by hand.
function RL.NewRun()
    local run = active()
    if run then
        if not run.leftAt then run.leftAt = ns.Now() end
        finish(run)
    end
    RL.Check()
end

-- ---------------------------------------------------------------------------
-- Reading the logs
-- ---------------------------------------------------------------------------

-- Characters with runs, yours first: { { key, name, realm, class, runs } }
function RL.Characters()
    local d = db()
    local me = RL.CharKey()
    local out = {}
    for key, runs in pairs(d.runs) do
        if #runs > 0 then
            local c = d.chars[key] or {}
            tinsert(out, { key = key, name = c.name or key, realm = c.realm, class = c.class, level = c.level, runs = runs, me = key == me })
        end
    end
    table.sort(out, function(a, b)
        if a.me ~= b.me then return a.me end
        return (a.runs[1].start or 0) > (b.runs[1].start or 0)
    end)
    return out
end

function RL.Delete(charKey, run)
    local list = db().runs[charKey]
    for i, r in ipairs(list or {}) do
        if r == run then tremove(list, i) break end
    end
    ns.Fire("RUNLOG_CHANGED")
end

-- Best time per dungeon for one character: { { dungeon, best, runs, cleared } } by name.
function RL.Summary(charKey)
    local by, out = {}, {}
    for _, r in ipairs(db().runs[charKey] or {}) do
        local label = RL.Label(r)
        local s = by[label]
        if not s then s = { dungeon = label, runs = 0, cleared = 0 }; by[label] = s; tinsert(out, s) end
        s.runs = s.runs + 1
        if r.done then
            s.cleared = s.cleared + 1
            if not s.best or r.dur < s.best then s.best = r.dur end
        end
    end
    table.sort(out, function(a, b) return a.dungeon < b.dungeon end)
    return out
end

-- Your group's best times for a dungeon: { { name, seconds } } fastest first.
function RL.PartyTimes(dungeon)
    local out = {}
    for name, sec in pairs(db().party[dungeon] or {}) do tinsert(out, { name = name, seconds = sec }) end
    table.sort(out, function(a, b) return a.seconds < b.seconds end)
    return out
end

if ns.Comm and ns.Comm.Handle then
    ns.Comm.Handle("T", function(parts, sender)
        local dungeon, sec = parts[2], tonumber(parts[3])
        if not (dungeon and dungeon ~= "" and sec and sec > 30 and sec < 6 * 3600) then return end
        local name = ns.Short(sender) or ns.Display(sender)
        local d = db()
        d.party[dungeon] = d.party[dungeon] or {}
        local old = d.party[dungeon][name]
        if not old or sec < old then d.party[dungeon][name] = sec end
        ns.Fire("RUNLOG_CHANGED")
    end)
end
