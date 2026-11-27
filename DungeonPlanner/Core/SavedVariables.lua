-- SavedVariables.lua
-- Saved variables and their defaults.
local _, ns = ...

-- ---------------------------------------------------------------------------
-- Saved variables
-- ---------------------------------------------------------------------------

local DEFAULTS = {
    showTab = true,
    hideAvoided = true,
    network = true,
    inbox = true,
    inboxSound = true,
    declineReply = false,
    declineText = nil,   -- nil = use the localized default
    joinTemplate = nil,  -- nil = use the localized default
    recruitTemplate = nil,
    sort = "match",
    tracker = true,
    minimapButton = true,
    openSharedMaps = true,   -- a map drawing shared by your group opens right away
    chatMessages = true,
    pathDots = true,
    avoidDanger = true,      -- the arrow goes around zones far above your level         -- the arrow's path as dots on the world map and minimap
    questTooltips = true,    -- the big tooltip when you hover a quest in the journal     -- Dungeon Planner's messages in the chat window
    partyShare = true,       -- tell your group which dungeon quests you have and your best times
    itemSources = true,      -- "Drops from" line on item tooltips
    wishlistAlerts = true,   -- a warning when a boss with a wished item dies
    hideDoneQuests = false,
    foreverOnly = false,     -- journal list: only Forever's new dungeons
    journalScale = 1,
    journalSize = nil,       -- { w, h } after resizing the journal
    showGroups = true,
    showPlayers = true,
}

local CHAR_DEFAULTS = {
    roles = nil,         -- { tank = bool, healer = bool, dps = bool }; nil until first set
    dungeonFilter = 0,   -- 0 = all dungeons for my level
    roleFilter = { tank = true, healer = true, dps = true },
    lastTab = 1,
}

local function applyDefaults(db, defaults)
    for k, v in pairs(defaults) do
        if db[k] == nil then
            if type(v) == "table" then
                db[k] = CopyTable and CopyTable(v) or v
            else
                db[k] = v
            end
        end
    end
end

ns.On("ADDON_LOADED", function(name)
    if name ~= ns.ADDON then return end
    DungeonPlannerDB = DungeonPlannerDB or {}
    DungeonPlannerCharDB = DungeonPlannerCharDB or {}
    ns.db = DungeonPlannerDB
    ns.cdb = DungeonPlannerCharDB
    ns.db.profile = ns.db.profile or {}
    ns.db.memory = ns.db.memory or {}   -- account-wide: players you grouped with
    ns.db.learned = ns.db.learned or {} -- questID -> activity name, learned in dungeons
    applyDefaults(ns.db.profile, DEFAULTS)
    applyDefaults(ns.cdb, CHAR_DEFAULTS)
    ns.opt = ns.db.profile
    ns.Fire("DB_READY")
end)

ns.On("PLAYER_LOGIN", function()
    ns.Fire("LOGIN")
end)
