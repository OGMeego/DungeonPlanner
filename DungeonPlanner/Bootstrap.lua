-- Bootstrap.lua
-- Loaded last. Connects pieces that already exist: slash commands, key bindings and the
-- debug report. No feature logic lives here.
local _, ns = ...
local L = ns.L

-- ---------------------------------------------------------------------------
-- Slash commands
-- ---------------------------------------------------------------------------

SLASH_DUNGEONPLANNER1 = "/dp"
SLASH_DUNGEONPLANNER2 = "/dungeonplanner"
SlashCmdList.DUNGEONPLANNER = function(msg)
    -- Trail commands keep the name as typed.
    local cmd, rest = strtrim(msg or ""):match("^(%S+)%s*(.*)$")
    cmd = cmd and strlower(cmd)
    if cmd == "record" or cmd == "trails" or cmd == "trail" then return ns.Trails.Slash(cmd, rest) end
    msg = strlower(strtrim(msg or ""))
    if msg == "options" or msg == "config" or msg == "settings" then
        if ns.OpenOptions then ns.OpenOptions() end
    elseif msg == "reset" then
        wipe(DungeonPlannerDB.memory)
        wipe(DungeonPlannerDB.learned)
        ns.Say(L.LOADED_RESET)
    elseif msg == "help" or msg == "?" then
        ns.Say(L.ADDON_TITLE .. " v" .. ns.VERSION)
        ns.Say(L.SLASH_HELP)
    elseif msg == "version" or msg == "ver" or msg == "v" then
        ns.Say(L.ADDON_TITLE .. " v" .. ns.VERSION)
    elseif msg == "journal" or msg == "j" then
        ns.Journal.OpenSmart()
    elseif msg == "gear" or msg == "upgrades" then
        ns.Journal.ShowUpgrades()
    elseif msg == "tracker" then
        ns.Tracker.SetEnabled(not ns.opt.tracker)
    elseif msg:match("^quest %d+") then
        ns.Maps.Debug(tonumber(msg:match("%d+")))
    elseif msg == "map" then
        if not ns.Journal.OpenHere(4) then ns.Say(L.MAP_NOT_INSIDE) end
    elseif msg == "mapdebug" then
        if ns.Journal and ns.Journal.MapDebug then ns.Journal.MapDebug() end
    elseif msg == "newrun" then
        ns.RunLog.NewRun()
        ns.Say(L.RUN_NEW)
    elseif msg == "logs" then
        ns.Journal.ShowPage("logs")
    elseif msg == "wishlist" or msg == "wish" then
        ns.Journal.ShowPage("wishlist")
    elseif msg == "party" then
        ns.Journal.ShowPage("party")
    elseif msg == "taint" then
        ns.TaintCheck.Run()
    elseif msg == "bug" or msg == "report" then
        ns.BugReport.Show()
    elseif msg == "data" then
        ns.QuestData.Show()
    elseif msg == "flights" then
        if ns.Nav and ns.Nav.FlightsReport then ns.Nav.FlightsReport() end
    elseif msg == "comm" then
        ns.Comm.Check()
    elseif msg == "debug" then
        if ns.DebugReport then ns.DebugReport() end
    else
        if ns.UI and ns.UI.Open then ns.UI.Open() end
    end
end

-- ---------------------------------------------------------------------------
-- Key bindings (Bindings.xml)
-- ---------------------------------------------------------------------------

function DungeonPlanner_Binding(what)
    if what == "journal" then ns.Journal.Toggle()
    elseif what == "planner" then ns.UI.Open()
    elseif what == "logs" then ns.Journal.ShowPage("logs")
    elseif what == "map" then
        if not ns.Journal.OpenHere(4) then ns.Journal.OpenSmart() end
    end
end
