-- Events.lua
-- What makes the panel repaint.
local _, ns = ...
local L = ns.L
local UI = ns.UI
local GROUP_FINDER_ADDON = "Blizzard_GroupFinder_VanillaStyle"
local P = ns.Private("Finder.UI")

-- ---------------------------------------------------------------------------
-- Wiring
-- ---------------------------------------------------------------------------

ns.On("ADDON_LOADED", function(name)
    if name == GROUP_FINDER_ADDON then UI.Attach() end
end)
ns.Listen("LOGIN", function()
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(GROUP_FINDER_ADDON)
    if loaded or _G.LFGParentFrame then UI.Attach() end
end)

for _, msg in ipairs({ "LISTINGS_CHANGED", "INBOX_CHANGED", "PEERS_CHANGED", "MEMORY_CHANGED",
    "QUESTS_CHANGED", "MY_INFO_CHANGED", "ACTIVITIES_CHANGED" }) do
    ns.Listen(msg, P.refreshSoon)
end

ns.Listen("INBOX_CHANGED", function(a, isNew)
    if isNew and a and not UI.IsShown() then
        ns.Print(L.NEW_APPLICANT:format(ns.Display(a.name)))
    end
end)

ns.On("PLAYER_REGEN_ENABLED", function() if P.panel and P.panel:IsShown() then P.updateRefresh() end end)
ns.On("PLAYER_REGEN_DISABLED", function()
    if P.panel and P.panel.refreshSecure then P.panel.refreshSecure:Hide() end
end)
ns.On("GROUP_ROSTER_UPDATE", P.refreshSoon)
ns.On("LFG_LIST_ACTIVE_ENTRY_UPDATE", P.refreshSoon)

function ns.DebugReport()
    ns.Say("group finder attached:", tostring(UI.attached), "| can refresh:", tostring(ns.Finder.CanRefresh()),
        "| listings:", #ns.Finder.listings, "| network:", ns.Comm.status,
        "| peers:", (function() local n = 0 for _ in pairs(ns.Comm.peers) do n = n + 1 end return n end)(),
        "| dungeon quests:", ns.Data.questCount, "| dungeons:", #ns.Data.dungeonList)
end
